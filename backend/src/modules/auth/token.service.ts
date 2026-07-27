import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import * as argon2 from 'argon2';
import { createHash, randomBytes } from 'crypto';
import { PrismaService } from '../../common/prisma/prisma.service';

export interface JwtPayload {
  sub: string;
  email: string;
  role: Role;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export type ClientType = 'web' | 'mobile';

export interface DeviceContext {
  deviceInfo?: string;
  ipAddress?: string;
  userAgent?: string;
  clientType?: ClientType;
}

@Injectable()
export class TokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  private sha256(value: string): string {
    return createHash('sha256').update(value).digest('hex');
  }

  async generateTokens(
    payload: JwtPayload,
    device: DeviceContext = {},
  ): Promise<TokenPair> {
    const accessToken = await this.jwt.signAsync(payload, {
      secret: this.config.get<string>('jwt.accessSecret'),
      expiresIn: this.config.get<string>('jwt.accessExpiresIn'),
    });

    // Per-client refresh lifetime: mobile sessions live much longer (access is
    // protected by the biometric app-lock), web keeps the short default.
    const refreshTtl =
      device.clientType === 'mobile'
        ? this.config.get<string>('jwt.refreshExpiresInMobile') || '180d'
        : this.config.get<string>('jwt.refreshExpiresIn') || '7d';

    // Opaque refresh token stored hashed; JWT wrapper carries the id.
    const refreshId = randomBytes(32).toString('hex');
    const refreshToken = await this.jwt.signAsync(
      { ...payload, jti: refreshId },
      {
        secret: this.config.get<string>('jwt.refreshSecret'),
        expiresIn: refreshTtl,
      },
    );

    const expiresAt = this.computeRefreshExpiry(refreshTtl);
    await this.prisma.refreshToken.create({
      data: {
        userId: payload.sub,
        tokenHash: this.sha256(refreshToken),
        deviceInfo: device.deviceInfo,
        ipAddress: device.ipAddress,
        userAgent: device.userAgent,
        expiresAt,
      },
    });

    return { accessToken, refreshToken };
  }

  /**
   * Verify + rotate a refresh token. Revokes the old one and issues a new pair.
   */
  async rotateRefreshToken(token: string, device: DeviceContext = {}): Promise<TokenPair> {
    let payload: JwtPayload & { jti: string };
    try {
      payload = await this.jwt.verifyAsync(token, {
        secret: this.config.get<string>('jwt.refreshSecret'),
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const tokenHash = this.sha256(token);
    const stored = await this.prisma.refreshToken.findFirst({
      where: { tokenHash, userId: payload.sub },
    });

    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      // Possible token reuse — revoke all sessions for safety.
      await this.revokeAllForUser(payload.sub);
      throw new UnauthorizedException('Refresh token no longer valid');
    }

    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });

    return this.generateTokens(
      { sub: payload.sub, email: payload.email, role: payload.role },
      device,
    );
  }

  async revokeRefreshToken(token: string): Promise<void> {
    const tokenHash = this.sha256(token);
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async revokeAllForUser(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async hashPassword(password: string): Promise<string> {
    return argon2.hash(password, { type: argon2.argon2id });
  }

  async verifyPassword(hash: string, password: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, password);
    } catch {
      return false;
    }
  }

  private computeRefreshExpiry(ttl?: string): Date {
    const raw = ttl || this.config.get<string>('jwt.refreshExpiresIn') || '7d';
    const match = /^(\d+)([smhd])$/.exec(raw);
    const now = Date.now();
    if (!match) return new Date(now + 7 * 24 * 60 * 60 * 1000);
    const value = parseInt(match[1], 10);
    const unit = match[2];
    const multipliers: Record<string, number> = {
      s: 1000,
      m: 60 * 1000,
      h: 60 * 60 * 1000,
      d: 24 * 60 * 60 * 1000,
    };
    return new Date(now + value * multipliers[unit]);
  }
}
