import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Language, OtpPurpose, Prisma } from '@prisma/client';
import * as argon2 from 'argon2';
import { randomInt } from 'crypto';
import { PrismaService } from '../../common/prisma/prisma.service';
import {
  ALL_DEFAULT_CATEGORIES,
} from '../../common/constants/default-categories';
import { MailService } from '../mail/mail.service';
import { AuditService } from '../audit/audit.service';
import { DeviceContext, TokenService } from './token.service';
import {
  ForgotPasswordDto,
  LoginDto,
  RegisterDto,
  ResetPasswordDto,
  VerifyOtpDto,
} from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    private readonly mail: MailService,
    private readonly audit: AuditService,
    private readonly config: ConfigService,
  ) {}

  // ---------------------------------------------------------------- Register
  async register(dto: RegisterDto, device: DeviceContext) {
    const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existing) {
      throw new ConflictException('An account with this email already exists');
    }

    const passwordHash = await this.tokens.hashPassword(dto.password);

    const user = await this.prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          email: dto.email,
          passwordHash,
          firstName: dto.firstName,
          lastName: dto.lastName,
          country: dto.country,
          settings: {
            create: {
              language: dto.language ?? Language.EN,
              currency:
                dto.currency ?? this.config.get<string>('defaultCurrency') ?? 'XOF',
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

    await this.issueOtp(user.id, user.email, OtpPurpose.EMAIL_VERIFICATION);
    await this.audit.log({ userId: user.id, action: 'REGISTER', entity: 'User', entityId: user.id, ...device });

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
    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }
    if (!user.isActive) {
      throw new UnauthorizedException('Account is disabled');
    }

    const valid = await this.tokens.verifyPassword(user.passwordHash, dto.password);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.emailVerified) {
      await this.issueOtp(user.id, user.email, OtpPurpose.EMAIL_VERIFICATION);
      throw new UnauthorizedException(
        'Email not verified. A new verification code has been sent.',
      );
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
      data: { emailVerified: true },
    });
    await this.mail.sendWelcome(user.email, user.firstName ?? undefined);
    await this.audit.log({ userId: user.id, action: 'EMAIL_VERIFIED', entity: 'User', entityId: user.id });

    return this.completeLogin(user.id, user.email, user.role, device);
  }

  async resendOtp(email: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (user && !user.emailVerified) {
      await this.issueOtp(user.id, user.email, OtpPurpose.EMAIL_VERIFICATION);
    }
    return { message: 'If the account exists and is unverified, a new code has been sent.' };
  }

  // -------------------------------------------------------- Forgot / Reset PW
  async forgotPassword(dto: ForgotPasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (user) {
      const code = await this.issueOtp(user.id, user.email, OtpPurpose.PASSWORD_RESET, false);
      await this.mail.sendPasswordReset(user.email, code);
    }
    return { message: 'If an account exists, a reset code has been sent.' };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) throw new BadRequestException('Invalid request');

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

  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.passwordHash) throw new BadRequestException('Invalid request');

    const valid = await this.tokens.verifyPassword(user.passwordHash, currentPassword);
    if (!valid) throw new BadRequestException('Current password is incorrect');

    const passwordHash = await this.tokens.hashPassword(newPassword);
    await this.prisma.user.update({ where: { id: userId }, data: { passwordHash } });
    await this.tokens.revokeAllForUser(userId);
    await this.audit.log({ userId, action: 'PASSWORD_CHANGED', entity: 'User', entityId: userId });

    return { message: 'Password changed. Please log in again.' };
  }

  // ------------------------------------------------------------ Google login
  async validateGoogleUser(profile: {
    googleId: string;
    email: string;
    firstName?: string;
    lastName?: string;
    avatarUrl?: string;
  }) {
    let user = await this.prisma.user.findFirst({
      where: { OR: [{ googleId: profile.googleId }, { email: profile.email }] },
    });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email: profile.email,
          googleId: profile.googleId,
          firstName: profile.firstName,
          lastName: profile.lastName,
          avatarUrl: profile.avatarUrl,
          emailVerified: true,
          settings: {
            create: { currency: this.config.get<string>('defaultCurrency') ?? 'XOF' },
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
    } else if (!user.googleId) {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { googleId: profile.googleId, emailVerified: true },
      });
    }

    return user;
  }

  async loginWithOAuthUser(userId: string, email: string, role: any, device: DeviceContext) {
    return this.completeLogin(userId, email, role, device);
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
        settings: true,
      },
    });

    return { user, ...pair };
  }

  private async issueOtp(
    userId: string,
    email: string,
    purpose: OtpPurpose,
    sendEmail = true,
  ): Promise<string> {
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const codeHash = await argon2.hash(code, { type: argon2.argon2id });
    const expiresMinutes = this.config.get<number>('otp.expiresMinutes') ?? 10;

    // Invalidate previous unconsumed OTPs of the same purpose.
    await this.prisma.otpCode.updateMany({
      where: { userId, purpose, consumedAt: null },
      data: { consumedAt: new Date() },
    });

    await this.prisma.otpCode.create({
      data: {
        userId,
        codeHash,
        purpose,
        expiresAt: new Date(Date.now() + expiresMinutes * 60 * 1000),
      },
    });

    if (sendEmail) {
      await this.mail.sendOtp(email, code, purpose);
    }
    return code;
  }

  private async consumeOtp(userId: string, code: string, purpose: OtpPurpose) {
    const otp = await this.prisma.otpCode.findFirst({
      where: { userId, purpose, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) throw new BadRequestException('No active code. Please request a new one.');
    if (otp.expiresAt < new Date()) throw new BadRequestException('Code has expired');
    if (otp.attempts >= 5) throw new BadRequestException('Too many attempts. Request a new code.');

    const valid = await argon2.verify(otp.codeHash, code).catch(() => false);
    if (!valid) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Invalid code');
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { consumedAt: new Date() },
    });
  }
}
