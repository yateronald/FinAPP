import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { TokenService } from '../auth/token.service';
import { UpdateProfileDto } from './dto/user.dto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly tokens: TokenService,
  ) {}

  async getProfile(userId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        role: true,
        emailVerified: true,
        createdAt: true,
        lastLoginAt: true,
        settings: true,
        // Which sign-in methods this account has. The hashes and ids
        // themselves never leave the server — only whether they exist, so the
        // client can offer "Set a password" instead of "Change password".
        passwordHash: true,
        googleId: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');

    const { passwordHash, googleId, ...safe } = user;
    return { ...safe, hasPassword: !!passwordHash, hasGoogle: !!googleId };
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: dto,
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        role: true,
      },
    });
    await this.audit.log({ userId, action: 'PROFILE_UPDATED', entity: 'User', entityId: userId });
    return user;
  }

  async deleteAccount(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { deletedAt: new Date(), isActive: false },
    });
    await this.tokens.revokeAllForUser(userId);
    await this.audit.log({ userId, action: 'ACCOUNT_DELETED', entity: 'User', entityId: userId });
    return { message: 'Account scheduled for deletion' };
  }
}
