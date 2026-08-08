import {
  BadRequestException,
  Logger,
  ConflictException,
  Injectable,
  UnauthorizedException,
  ForbiddenException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Language, OtpPurpose, Prisma } from '@prisma/client';
import * as argon2 from 'argon2';
import { randomInt } from 'crypto';
import { OAuth2Client, type TokenPayload } from 'google-auth-library';
import { PrismaService } from '../../common/prisma/prisma.service';
import {
  ALL_DEFAULT_CATEGORIES,
} from '../../common/constants/default-categories';
import { MailService } from '../mail/mail.service';
import { AuditService } from '../audit/audit.service';
import { PRIVACY_VERSION, TERMS_VERSION } from '../../common/constants/legal';
import { EngagementService } from '../notifications/engagement.service';
import { DeviceContext, TokenService } from './token.service';
import {
  ForgotPasswordDto,
  LoginDto,
  RegisterDto,
  ResetPasswordDto,
  VerifyOtpDto,
} from './dto/auth.dto';

/**
 * Verification-code policy.
 *
 * Short-lived and few attempts because the code travels by e-mail and is only
 * ever typed once: a wide window buys an attacker time without helping anyone.
 */
/** Minutes a code stays valid. */
const OTP_TTL_MINUTES = 3;
/** Wrong guesses before the code is burned and a new one must be requested. */
const OTP_MAX_ATTEMPTS = 3;
/** Explicit resends allowed within a rolling hour, per user and purpose. */
const OTP_MAX_RESENDS_PER_HOUR = 3;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    private readonly mail: MailService,
    private readonly audit: AuditService,
    private readonly config: ConfigService,
    private readonly welcome: EngagementService,
  ) {}

  /**
   * Email verification is only enforceable when mail can actually leave the
   * server. With SMTP unconfigured the OTP is written to the log and never
   * reaches the user, so demanding it would make every new account
   * unreachable. An explicit AUTH_REQUIRE_EMAIL_VERIFICATION overrides this.
   */
  private get requireEmailVerification(): boolean {
    const forced = this.config.get<string>('auth.requireEmailVerification');
    if (forced === 'true') return true;
    if (forced === 'false') return false;
    return this.mail.isConfigured;
  }

  // ---------------------------------------------------------------- Register
  async register(dto: RegisterDto, device: DeviceContext) {
    const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existing) {
      throw new ConflictException('An account with this email already exists');
    }

    const passwordHash = await this.tokens.hashPassword(dto.password);
    const needsVerification = this.requireEmailVerification;

    const user = await this.prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          email: dto.email,
          passwordHash,
          firstName: dto.firstName,
          lastName: dto.lastName,
          country: dto.country,
          emailVerified: !needsVerification,
          // Proof of consent, recorded at the moment of acceptance.
          termsAcceptedAt: new Date(),
          termsVersion: TERMS_VERSION,
          privacyVersion: PRIVACY_VERSION,
          settings: {
            create: {
              language: dto.language ?? Language.EN,
              currency:
                dto.currency ?? this.config.get<string>('defaultCurrency') ?? 'XOF',
              // AI is always opt-in. Enabling it requires the dedicated
              // disclosure and consent endpoint after the first welcome.
              aiEnabled: false,
            },
          },
          categories: {
            create: ALL_DEFAULT_CATEGORIES.map((c, index) => ({
              name: c.name,
              type: c.type,
              icon: c.icon,
              color: c.color,
              isDefault: true,
              sortOrder: index,
            })),
          },
        },
      });
      return created;
    });

    await this.audit.log({ userId: user.id, action: 'REGISTER', entity: 'User', entityId: user.id, ...device });

    if (!needsVerification) {
      // No mail to wait for — hand back a session so the app signs straight in.
      return {
        message: 'Registration successful.',
        email: user.email,
        requiresVerification: false,
        ...(await this.completeLogin(user.id, user.email, user.role, device)),
      };
    }

    await this.issueOtp(user.id, user.email, OtpPurpose.EMAIL_VERIFICATION, {
      firstName: user.firstName ?? undefined,
    });
    return {
      message: 'Registration successful. Please verify your email with the code we sent.',
      email: user.email,
      requiresVerification: true,
    };
  }

  // ------------------------------------------------------------------- Login
  async login(dto: LoginDto, device: DeviceContext) {
    const user = await this.prisma.user.findFirst({
      where: { email: dto.email, deletedAt: null },
    });
    // Failed attempts are audited so the admin dashboard can surface them —
    // repeated failures on an account are an early sign of a break-in attempt.
    const auditFailure = (reason: string) =>
      this.audit.log({
        userId: user?.id,
        action: 'LOGIN_FAILED',
        entity: 'User',
        entityId: user?.id,
        metadata: { email: dto.email, reason },
        ...device,
      });

    if (!user || !user.passwordHash) {
      await auditFailure('UNKNOWN_ACCOUNT');
      throw new UnauthorizedException('Invalid credentials');
    }
    if (!user.isActive) {
      await auditFailure('ACCOUNT_DISABLED');
      throw new UnauthorizedException('Account is disabled');
    }

    const valid = await this.tokens.verifyPassword(user.passwordHash, dto.password);
    if (!valid) {
      await auditFailure('BAD_PASSWORD');
      throw new UnauthorizedException('Invalid credentials');
    }

    // Admin accounts are web-only: the mobile app has no admin UI, so signing in
    // there would strand them in an app they cannot use.
    if (user.role === 'ADMIN' && device.clientType === 'mobile') {
      throw new UnauthorizedException(
        'Admin accounts must sign in on the web dashboard.',
      );
    }

    if (!user.emailVerified && this.requireEmailVerification) {
      const grace = user.verificationDeadline;
      const withinGrace = grace != null && grace.getTime() > Date.now();

      if (!withinGrace) {
        // Either a new account (no grace was ever granted) or one whose window
        // has run out. Only send when nothing usable is outstanding: sending on
        // every attempt would spam the mailbox and invalidate a code the user
        // is in the middle of typing.
        const live = await this.activeOtp(user.id, OtpPurpose.EMAIL_VERIFICATION);
        if (!live) {
          await this.issueOtp(user.id, user.email, OtpPurpose.EMAIL_VERIFICATION, {
            firstName: user.firstName ?? undefined,
          });
        }
        await auditFailure('EMAIL_NOT_VERIFIED');
        throw new ForbiddenException({
          message: 'Please confirm your email address to continue.',
          code: 'EMAIL_NOT_VERIFIED',
          email: user.email,
          codeSent: !live,
          graceExpired: grace != null,
        });
      }

      // Accounts that predate the rule keep working for now; the app shows the
      // countdown and the confirm action.
      const session = await this.completeLogin(user.id, user.email, user.role, device);
      return {
        ...session,
        verificationPending: {
          email: user.email,
          deadline: grace.toISOString(),
          daysLeft: Math.max(
            0,
            Math.ceil((grace.getTime() - Date.now()) / (24 * 60 * 60 * 1000)),
          ),
        },
      };
    }

    return this.completeLogin(user.id, user.email, user.role, device);
  }

  // -------------------------------------------------------------- Verify OTP
  async verifyEmail(dto: VerifyOtpDto, device: DeviceContext) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) throw new BadRequestException('Invalid request');

    await this.consumeOtp(user.id, dto.code, OtpPurpose.EMAIL_VERIFICATION);

    await this.prisma.user.update({
      where: { id: user.id },
      // Clearing the deadline stops the countdown reminders as well.
      data: {
        emailVerified: true,
        verificationDeadline: null,
        verificationRemindedAt: null,
      },
    });
    await this.mail.sendWelcome(user.email, user.firstName ?? undefined);
    await this.audit.log({ userId: user.id, action: 'EMAIL_VERIFIED', entity: 'User', entityId: user.id });

    return this.completeLogin(user.id, user.email, user.role, device);
  }

  /**
   * The response never reveals whether the address has an account — an
   * unauthenticated caller must not be able to enumerate users — but a real,
   * unverified account that has run out of resends gets a 429 so the app can
   * show a truthful countdown rather than pretending a code is on its way.
   */
  async resendOtp(email: string) {
    if (!this.requireEmailVerification) {
      return { message: 'Email verification is disabled — you can sign in directly.' };
    }
    const generic = {
      message: 'If the account exists and is unverified, a new code has been sent.',
      expiresInMinutes: this.config.get<number>('otp.expiresMinutes') ?? OTP_TTL_MINUTES,
    };

    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || user.emailVerified) return generic;

    const { remaining, retryAfter } = await this.resendAllowance(
      user.id,
      OtpPurpose.EMAIL_VERIFICATION,
    );
    if (remaining === 0) {
      throw new HttpException(
        {
          message: 'Too many codes requested. Please try again later.',
          code: 'OTP_RESEND_LIMIT',
          retryAfter,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    await this.issueOtp(user.id, user.email, OtpPurpose.EMAIL_VERIFICATION, {
      isResend: true,
      firstName: user.firstName ?? undefined,
    });
    return { ...generic, resendsLeft: remaining - 1 };
  }

  // -------------------------------------------------------- Forgot / Reset PW
  /**
   * Sends a reset code, but only to an address that has been confirmed:
   * resetting to an unverified mailbox would let whoever controls that inbox
   * take over an account they never proved they own.
   *
   * The answer is identical in every case — account missing, unverified, or
   * throttled — so this endpoint cannot be used to discover who has an
   * account. The only visible difference is the 429, which needs a real
   * countdown to be useful, and which reveals nothing on its own because an
   * attacker can trigger it against any address.
   */
  async forgotPassword(dto: ForgotPasswordDto) {
    const neutral = {
      message:
        'If this address has a confirmed account, a reset code is on its way.',
      expiresInMinutes: this.config.get<number>('otp.expiresMinutes') ?? OTP_TTL_MINUTES,
    };

    const user = await this.prisma.user.findFirst({
      where: { email: dto.email, deletedAt: null },
    });
    if (!user || !user.emailVerified || !user.isActive) return neutral;

    const { remaining, retryAfter } = await this.resendAllowance(
      user.id,
      OtpPurpose.PASSWORD_RESET,
    );
    if (remaining === 0) {
      throw new HttpException(
        {
          message: 'Too many codes requested. Please try again later.',
          code: 'OTP_RESEND_LIMIT',
          retryAfter,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const code = await this.issueOtp(user.id, user.email, OtpPurpose.PASSWORD_RESET, {
      sendEmail: false,
      isResend: true,
    });
    const settings = await this.prisma.userSettings.findUnique({
      where: { userId: user.id },
      select: { language: true },
    });
    await this.mail.sendPasswordReset(user.email, code, {
      firstName: user.firstName ?? undefined,
      expiresMinutes: neutral.expiresInMinutes,
      language: settings?.language,
    });
    await this.audit.log({
      userId: user.id,
      action: 'PASSWORD_RESET_REQUESTED',
      entity: 'User',
      entityId: user.id,
    });
    return neutral;
  }

  async resetPassword(dto: ResetPasswordDto) {
    const user = await this.prisma.user.findFirst({
      where: { email: dto.email, deletedAt: null },
    });
    // Same guard as the request step: a code must never be redeemable against
    // an account that was not eligible to receive one.
    if (!user || !user.emailVerified || !user.isActive) {
      throw new BadRequestException({
        message: 'Invalid or expired reset request.',
        code: 'OTP_NONE',
      });
    }

    await this.consumeOtp(user.id, dto.code, OtpPurpose.PASSWORD_RESET);
    const passwordHash = await this.tokens.hashPassword(dto.newPassword);

    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash },
    });
    await this.tokens.revokeAllForUser(user.id);
    await this.audit.log({ userId: user.id, action: 'PASSWORD_RESET', entity: 'User', entityId: user.id });

    return { message: 'Password reset successful. Please log in.' };
  }

  /**
   * Changes the password — or sets the first one.
   *
   * An account created through Google has no passwordHash, so there is no
   * current password to confirm. Requiring one would leave those users unable
   * to ever add a password.
   *
   * Setting a password RETIRES Google sign-in for that account: from then on
   * the password is the only credential. The Google id is kept so the sign-in
   * attempt can be answered with a useful message rather than "no account".
   */
  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new BadRequestException('Invalid request');

    const settingFirstPassword = !user.passwordHash;
    if (!settingFirstPassword) {
      if (!currentPassword) {
        throw new BadRequestException('Current password is required');
      }
      const valid = await this.tokens.verifyPassword(user.passwordHash!, currentPassword);
      if (!valid) throw new BadRequestException('Current password is incorrect');
    }

    const passwordHash = await this.tokens.hashPassword(newPassword);
    await this.prisma.user.update({
      where: { id: userId },
      // Clearing the flag lifts the forced-change gate.
      data: { passwordHash, mustChangePassword: false, passwordChangedAt: new Date() },
    });
    await this.tokens.revokeAllForUser(userId);
    await this.audit.log({
      userId,
      action: settingFirstPassword ? 'PASSWORD_SET' : 'PASSWORD_CHANGED',
      entity: 'User',
      entityId: userId,
    });

    return {
      message: settingFirstPassword
        ? 'Password set. You can now sign in with your email or with Google.'
        : 'Password changed. Please log in again.',
      wasFirstPassword: settingFirstPassword,
    };
  }

  // ------------------------------------------------------------ Google login
  /**
   * Resolves a Google profile to an account, honouring what the user asked for.
   *
   * Silently creating an account on "Sign in" hides a typo'd address behind a
   * brand-new empty account; silently signing in on "Sign up" hides that they
   * already have one. Both cases now report back instead.
   */
  async resolveGoogleAccount(
    profile: {
      googleId: string;
      email: string;
      emailVerified?: boolean;
      firstName?: string;
      lastName?: string;
      avatarUrl?: string;
    },
    intent: 'signin' | 'signup' = 'signin',
  ) {
    // Accounts are matched on email, so an unverified Google address would let
    // anyone claim someone else's account by registering that address with
    // Google. Google sets this true for real mailboxes.
    if (profile.emailVerified === false) {
      throw new BadRequestException({
        message: 'Your Google email address is not verified.',
        code: 'GOOGLE_EMAIL_UNVERIFIED',
      });
    }

    const existing = await this.prisma.user.findFirst({
      where: {
        OR: [{ googleId: profile.googleId }, { email: profile.email }],
        deletedAt: null,
      },
    });

    if (intent === 'signup' && existing) {
      throw new ConflictException({
        message: 'An account already exists for this email. Sign in instead.',
        code: 'ACCOUNT_EXISTS',
        email: existing.email,
        // Tells the client whether "Sign in with Google" will work, or whether
        // they registered with a password and should use that.
        hasGoogle: !!existing.googleId,
      });
    }

    if (intent === 'signin' && !existing) {
      throw new UnauthorizedException({
        message: 'No account found for this Google address. Please sign up first.',
        code: 'ACCOUNT_NOT_FOUND',
        email: profile.email,
      });
    }

    if (!existing) {
      return this.prisma.user.create({
        data: {
          email: profile.email,
          googleId: profile.googleId,
          firstName: profile.firstName,
          lastName: profile.lastName,
          avatarUrl: profile.avatarUrl,
          // Google has proved the mailbox, but every account confirms its
          // address through our own code before a session is issued.
          emailVerified: false,
          // Signing up through Google still requires acceptance — the client
          // shows the same consent step before calling with intent=signup.
          termsAcceptedAt: new Date(),
          termsVersion: TERMS_VERSION,
          privacyVersion: PRIVACY_VERSION,
          settings: {
            create: {
              currency: this.config.get<string>('defaultCurrency') ?? 'XOF',
              aiEnabled: false,
            },
          },
          categories: {
            create: ALL_DEFAULT_CATEGORIES.map((c, index) => ({
              name: c.name,
              type: c.type,
              icon: c.icon,
              color: c.color,
              isDefault: true,
              sortOrder: index,
            })),
          },
        },
      });
    }

    if (!existing.isActive) {
      throw new UnauthorizedException({
        message: 'Account is disabled',
        code: 'ACCOUNT_DISABLED',
      });
    }

    // Google is the way in only while the account has no password of its own.
    // Once the user sets one, that password becomes the single credential:
    // otherwise anyone holding the Google account keeps a second, silent key
    // to an account its owner believes is protected by their password.
    if (existing.passwordHash) {
      throw new UnauthorizedException({
        message:
          'This account has a password. Please sign in with your email and password.',
        code: 'ACCOUNT_HAS_PASSWORD',
        email: existing.email,
      });
    }

    // Existing account signing in: link the Google identity the first time and
    // backfill only fields the user has not set themselves.
    const patch: Record<string, unknown> = {};
    if (!existing.googleId) {
      patch.googleId = profile.googleId;
    }
    if (!existing.firstName && profile.firstName) patch.firstName = profile.firstName;
    if (!existing.lastName && profile.lastName) patch.lastName = profile.lastName;
    if (!existing.avatarUrl && profile.avatarUrl) patch.avatarUrl = profile.avatarUrl;

    if (Object.keys(patch).length === 0) return existing;
    return this.prisma.user.update({ where: { id: existing.id }, data: patch });
  }

  /** @deprecated use resolveGoogleAccount — kept for the web redirect flow. */
  async validateGoogleUser(profile: {
    googleId: string;
    email: string;
    emailVerified?: boolean;
    firstName?: string;
    lastName?: string;
    avatarUrl?: string;
  }) {
    return this.resolveGoogleAccount(profile, 'signin');
  }

  async loginWithOAuthUser(
    userId: string,
    email: string,
    role: any,
    device: DeviceContext,
  ) {
    // Same rule as password login: the mobile app has no admin UI, so an admin
    // signing in there would be stranded.
    if (role === 'ADMIN' && device.clientType === 'mobile') {
      throw new UnauthorizedException(
        'Admin accounts must sign in on the web dashboard.',
      );
    }

    // Google sign-ups go through the same confirmation as everyone else.
    if (this.requireEmailVerification) {
      const account = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { emailVerified: true, firstName: true },
      });
      if (account && !account.emailVerified) {
        const live = await this.activeOtp(userId, OtpPurpose.EMAIL_VERIFICATION);
        if (!live) {
          await this.issueOtp(userId, email, OtpPurpose.EMAIL_VERIFICATION, {
            firstName: account.firstName ?? undefined,
          });
        }
        throw new ForbiddenException({
          message: 'Please confirm your email address to continue.',
          code: 'EMAIL_NOT_VERIFIED',
          email,
          codeSent: !live,
        });
      }
    }

    return this.completeLogin(userId, email, role, device);
  }

  /**
   * Verifies a Google ID token issued to our own client and signs the user in.
   * This is the native-app path: `google_sign_in` obtains the token on-device,
   * so no browser redirect is involved.
   */
  async googleTokenLogin(
    idToken: string,
    intent: 'signin' | 'signup',
    device: DeviceContext,
  ) {
    const clientId = this.config.get<string>('google.clientId');
    if (!clientId) {
      throw new BadRequestException('Google sign-in is not configured on this server.');
    }

    let payload: TokenPayload | undefined;
    try {
      const client = new OAuth2Client(clientId);
      const ticket = await client.verifyIdToken({ idToken, audience: clientId });
      payload = ticket.getPayload();
    } catch (e) {
      throw new UnauthorizedException({
        message: 'Invalid Google token.',
        code: 'GOOGLE_TOKEN_INVALID',
      });
    }

    if (!payload?.sub || !payload.email) {
      throw new UnauthorizedException({
        message: 'Google token is missing the account email.',
        code: 'GOOGLE_TOKEN_INVALID',
      });
    }

    const user = await this.resolveGoogleAccount(
      {
        googleId: payload.sub,
        email: payload.email,
        emailVerified: payload.email_verified,
        firstName: payload.given_name,
        lastName: payload.family_name,
        avatarUrl: payload.picture,
      },
      intent,
    );

    return this.loginWithOAuthUser(user.id, user.email, user.role, device);
  }

  // ------------------------------------------------------------------ Logout
  async logout(refreshToken?: string) {
    if (refreshToken) {
      await this.tokens.revokeRefreshToken(refreshToken);
    }
    return { message: 'Logged out' };
  }

  async logoutEverywhere(userId: string) {
    await this.tokens.revokeAllForUser(userId);
    await this.audit.log({ userId, action: 'LOGOUT_ALL', entity: 'User', entityId: userId });
    return { message: 'Logged out from all devices' };
  }

  async refresh(refreshToken: string, device: DeviceContext) {
    const pair = await this.tokens.rotateRefreshToken(refreshToken, device);
    return pair;
  }

  async getSessions(userId: string) {
    return this.prisma.refreshToken.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      select: {
        id: true,
        deviceInfo: true,
        ipAddress: true,
        userAgent: true,
        createdAt: true,
        expiresAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async revokeSession(userId: string, sessionId: string) {
    await this.prisma.refreshToken.updateMany({
      where: { id: sessionId, userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { message: 'Session revoked' };
  }

  // --------------------------------------------------------------- Internals
  private async completeLogin(userId: string, email: string, role: any, device: DeviceContext) {
    const pair = await this.tokens.generateTokens({ sub: userId, email, role }, device);

    // Read lastLoginAt BEFORE overwriting it — a null value is the only
    // reliable signal that this is the very first sign-in.
    const before = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { lastLoginAt: true, firstName: true },
    });
    const isFirstLogin = before?.lastLoginAt == null;

    await this.prisma.user.update({
      where: { id: userId },
      data: { lastLoginAt: new Date() },
    });
    await this.audit.log({ userId, action: 'LOGIN', entity: 'User', entityId: userId, ...device });

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        role: true,
        emailVerified: true,
        mustChangePassword: true,
        settings: true,
      },
    });

    if (isFirstLogin && role !== 'ADMIN') {
      // Fire-and-forget: a welcome message must never be able to fail a login.
      this.welcome.sendWelcome(userId, before?.firstName ?? null).catch((e) => {
        this.logger.warn(`Welcome notification failed for ${userId}: ${(e as Error).message}`);
      });
    }

    return { user, ...pair, isFirstLogin };
  }

  private async issueOtp(
    userId: string,
    email: string,
    purpose: OtpPurpose,
    opts: { sendEmail?: boolean; isResend?: boolean; firstName?: string } = {},
  ): Promise<string> {
    const { sendEmail = true, isResend = false, firstName } = opts;
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const codeHash = await argon2.hash(code, { type: argon2.argon2id });
    const ttl = this.config.get<number>('otp.expiresMinutes') ?? OTP_TTL_MINUTES;

    // Invalidate previous unconsumed OTPs of the same purpose: only the newest
    // code may ever be used.
    await this.prisma.otpCode.updateMany({
      where: { userId, purpose, consumedAt: null },
      data: { consumedAt: new Date() },
    });

    await this.prisma.otpCode.create({
      data: {
        userId,
        codeHash,
        purpose,
        isResend,
        expiresAt: new Date(Date.now() + ttl * 60 * 1000),
      },
    });

    if (sendEmail) {
      // The code e-mail follows the account's own language, not the language
      // of whichever device happened to trigger it.
      const settings = await this.prisma.userSettings.findUnique({
        where: { userId },
        select: { language: true },
      });
      await this.mail.sendOtp(email, code, purpose, {
        firstName,
        expiresMinutes: ttl,
        language: settings?.language,
      });
    }
    return code;
  }

  /** Live (unconsumed, unexpired) code for this purpose, if any. */
  private activeOtp(userId: string, purpose: OtpPurpose) {
    return this.prisma.otpCode.findFirst({
      where: { userId, purpose, consumedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * How many explicit resends are left in the rolling hour, and when the
   * oldest one falls out of the window.
   */
  private async resendAllowance(userId: string, purpose: OtpPurpose) {
    const since = new Date(Date.now() - 60 * 60 * 1000);
    const sends = await this.prisma.otpCode.findMany({
      where: { userId, purpose, isResend: true, createdAt: { gte: since } },
      orderBy: { createdAt: 'asc' },
      select: { createdAt: true },
    });
    const remaining = Math.max(0, OTP_MAX_RESENDS_PER_HOUR - sends.length);
    const retryAfter =
      remaining > 0 || sends.length === 0
        ? 0
        : Math.max(
            1,
            Math.ceil((sends[0].createdAt.getTime() + 60 * 60 * 1000 - Date.now()) / 1000),
          );
    return { remaining, retryAfter };
  }

  /**
   * Checks a code and burns it on the third wrong guess, so a stolen or
   * brute-forced code cannot be retried indefinitely — the user must ask for a
   * new one. Errors carry a machine-readable `code` and the attempts left so
   * the client can guide the user instead of guessing at the message.
   */
  private async consumeOtp(userId: string, code: string, purpose: OtpPurpose) {
    const otp = await this.prisma.otpCode.findFirst({
      where: { userId, purpose, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      throw new BadRequestException({
        message: 'No active code. Please request a new one.',
        code: 'OTP_NONE',
      });
    }
    if (otp.expiresAt < new Date()) {
      throw new BadRequestException({
        message: 'This code has expired. Please request a new one.',
        code: 'OTP_EXPIRED',
      });
    }

    const valid = await argon2.verify(otp.codeHash, code).catch(() => false);
    if (!valid) {
      const attempts = otp.attempts + 1;
      const exhausted = attempts >= OTP_MAX_ATTEMPTS;
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        // Burning the code on exhaustion is what makes the attempt cap real:
        // leaving it active would let the caller keep guessing forever.
        data: { attempts, ...(exhausted ? { consumedAt: new Date() } : {}) },
      });
      throw new BadRequestException(
        exhausted
          ? {
              message: 'Too many incorrect attempts. This code is no longer valid — request a new one.',
              code: 'OTP_LOCKED',
              attemptsLeft: 0,
            }
          : {
              message: 'Incorrect code.',
              code: 'OTP_INVALID',
              attemptsLeft: OTP_MAX_ATTEMPTS - attempts,
            },
      );
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { consumedAt: new Date() },
    });
  }
}
