import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  Res,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthService } from './auth.service';
import { DeviceContext } from './token.service';
import { GoogleAuthGuard } from './guards/google-auth.guard';
import {
  ChangePasswordDto,
  ForgotPasswordDto,
  LoginDto,
  RefreshTokenDto,
  GoogleTokenDto,
  RegisterDto,
  ResendOtpDto,
  ResetPasswordDto,
  VerifyOtpDto,
} from './dto/auth.dto';

const REFRESH_COOKIE = 'refresh_token';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly config: ConfigService,
  ) {}

  private deviceOf(req: Request): DeviceContext {
    return {
      ipAddress: (req.headers['x-forwarded-for'] as string) || req.ip,
      userAgent: req.headers['user-agent'],
      deviceInfo: (req.headers['x-device-info'] as string) || undefined,
      clientType:
        (req.headers['x-client-type'] as string) === 'mobile' ? 'mobile' : 'web',
    };
  }

  private setRefreshCookie(res: Response, token: string) {
    const isProd = this.config.get('nodeEnv') === 'production';
    res.cookie(REFRESH_COOKIE, token, {
      httpOnly: true,
      secure: isProd,
      sameSite: isProd ? 'none' : 'lax',
      path: '/',
      maxAge: 7 * 24 * 60 * 60 * 1000,
    });
  }

  private clearRefreshCookie(res: Response) {
    res.clearCookie(REFRESH_COOKIE, { path: '/' });
  }

  @Public()
  @Post('register')
  @ApiOperation({ summary: 'Register with email & password' })
  async register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.auth.register(dto, this.deviceOf(req));
  }

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login with email & password' })
  async login(
    @Body() dto: LoginDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.auth.login(dto, this.deviceOf(req));
    this.setRefreshCookie(res, result.refreshToken);
    return result;
  }

  @Public()
  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify email with OTP code' })
  async verifyEmail(
    @Body() dto: VerifyOtpDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.auth.verifyEmail(dto, this.deviceOf(req));
    this.setRefreshCookie(res, result.refreshToken);
    return result;
  }

  @Public()
  @Post('resend-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Resend email verification OTP' })
  async resendOtp(@Body() dto: ResendOtpDto) {
    return this.auth.resendOtp(dto.email);
  }

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request a password reset code' })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto);
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reset password with OTP code' })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto);
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Rotate refresh token and issue new access token' })
  async refresh(
    @Body() dto: RefreshTokenDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const token = req.cookies?.[REFRESH_COOKIE] || dto.refreshToken;
    if (!token) throw new UnauthorizedException('Missing refresh token');
    const pair = await this.auth.refresh(token, this.deviceOf(req));
    this.setRefreshCookie(res, pair.refreshToken);
    return pair;
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Logout current session' })
  async logout(@Req() req: Request, @Res({ passthrough: true }) res: Response) {
    const token = req.cookies?.[REFRESH_COOKIE];
    this.clearRefreshCookie(res);
    return this.auth.logout(token);
  }

  @Post('logout-everywhere')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Logout from all devices' })
  async logoutEverywhere(
    @CurrentUser('userId') userId: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    this.clearRefreshCookie(res);
    return this.auth.logoutEverywhere(userId);
  }

  @Post('change-password')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Change password (authenticated)' })
  async changePassword(
    @CurrentUser('userId') userId: string,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.auth.changePassword(userId, dto.currentPassword ?? '', dto.newPassword);
  }

  @Get('sessions')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List active sessions / devices' })
  async sessions(@CurrentUser('userId') userId: string) {
    return this.auth.getSessions(userId);
  }

  @Delete('sessions/:id')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Revoke a specific session' })
  async revokeSession(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.auth.revokeSession(userId, id);
  }

  // ------------------------------------------------------------ Google OAuth
  @Public()
  @Get('google')
  @UseGuards(GoogleAuthGuard)
  @ApiOperation({
    summary: 'Start Google OAuth flow (web)',
    description: 'Pass ?intent=signup to require a new account, ?intent=signin to require an existing one.',
  })
  async googleAuth() {
    // Guard redirects to Google. `intent` rides along in `state`.
  }

  @Public()
  @Get('google/callback')
  @UseGuards(GoogleAuthGuard)
  @ApiOperation({ summary: 'Google OAuth callback (web)' })
  async googleCallback(@Req() req: Request, @Res() res: Response) {
    const webUrl = this.config.get<string>('webAppUrl') || '';
    const intent = (req.query.state as string) === 'signup' ? 'signup' : 'signin';

    try {
      const profile = req.user as any;
      const user = await this.auth.resolveGoogleAccount(profile, intent);
      const result = await this.auth.loginWithOAuthUser(
        user.id,
        user.email,
        user.role,
        this.deviceOf(req),
      );
      this.setRefreshCookie(res, result.refreshToken);
      return res.redirect(`${webUrl}/auth/callback?token=${result.accessToken}`);
    } catch (e: any) {
      // Redirect back with a machine-readable reason so the sign-in page can
      // say "you don't have an account yet" instead of showing a raw 401.
      const body = e?.response ?? {};
      const code = body.code ?? 'GOOGLE_SIGNIN_FAILED';
      const params = new URLSearchParams({ error: code });
      if (body.email) params.set('email', body.email);
      const target = intent === 'signup' ? 'register' : 'login';
      return res.redirect(`${webUrl}/${target}?${params.toString()}`);
    }
  }

  @Public()
  @Post('google/token')
  @ApiOperation({
    summary: 'Sign in / sign up with a Google ID token (mobile)',
    description:
      'Native apps obtain the ID token on-device via google_sign_in. Returns the same session as password login.',
  })
  async googleToken(@Body() dto: GoogleTokenDto, @Req() req: Request, @Res({ passthrough: true }) res: Response) {
    const result = await this.auth.googleTokenLogin(
      dto.idToken,
      dto.intent ?? 'signin',
      this.deviceOf(req),
    );
    this.setRefreshCookie(res, result.refreshToken);
    return result;
  }
}
