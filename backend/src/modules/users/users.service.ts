import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
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

  /** What erasing this account will destroy — shown in the confirmation UI. */
  async deletionImpact(userId: string) {
    const [expenses, incomes, budgets, categories, recurring, insights, notifications] =
      await Promise.all([
        this.prisma.expense.count({ where: { userId } }),
        this.prisma.income.count({ where: { userId } }),
        this.prisma.monthlyBudget.count({ where: { userId } }),
        this.prisma.category.count({ where: { userId } }),
        this.prisma.recurringTransaction.count({ where: { userId } }),
        this.prisma.aiInsight.count({ where: { userId } }),
        this.prisma.notification.count({ where: { userId } }),
      ]);
    return {
      expenses,
      incomes,
      budgets,
      categories,
      recurring,
      insights,
      notifications,
      total: expenses + incomes + budgets + categories + recurring + insights + notifications,
    };
  }

  /**
   * Permanently erases the account and everything belonging to it (GDPR
   * Art. 17). This is irreversible and immediate — there is no recovery.
   *
   * The old implementation only set `deletedAt` while claiming the account was
   * "scheduled for deletion", so every transaction, budget and notification
   * survived indefinitely. Nothing ever purged them.
   *
   * Eleven of the twelve user-owned tables cascade from `user.delete()`.
   * AuditLog is deliberately `onDelete: SetNull` so the security trail
   * survives — but its `metadata` records emails on failed logins, so those
   * are scrubbed first or PII would outlive the erasure.
   */
  async deleteAccount(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, role: true },
    });
    if (!user) throw new NotFoundException('User not found');

    // Refuse to strand the platform without an administrator.
    if (user.role === 'ADMIN') {
      const admins = await this.prisma.user.count({
        where: { role: 'ADMIN', deletedAt: null, isActive: true },
      });
      if (admins <= 1) {
        throw new BadRequestException(
          'This is the last administrator account and cannot be deleted.',
        );
      }
    }

    const impact = await this.deletionImpact(userId);

    // Scrub PII from the audit rows that will outlive the account. Done before
    // the delete so a failure here aborts the whole erasure.
    // Anonymise the audit rows that outlive the account.
    //
    // The security history is kept indefinitely, but only once it can no longer
    // identify anyone: the email is stripped from metadata and the IP address
    // and user agent are cleared. What remains — action, entity, timestamp — is
    // not personal data, so retaining it forever is legitimate and does not
    // conflict with the erasure the user just requested.
    //
    // `user_id` is a text column (Prisma maps String ids to text), so no cast.
    await this.prisma.$executeRaw`
      UPDATE audit_logs
      SET metadata   = CASE WHEN jsonb_exists(metadata, 'email')
                            THEN metadata - 'email' ELSE metadata END,
          ip_address = NULL,
          user_agent = NULL
      WHERE user_id = ${userId}
    `;

    await this.tokens.revokeAllForUser(userId);

    // Cascades to expenses, incomes, budgets, categories, recurring, insights,
    // notifications, FCM tokens, OTP codes, refresh tokens and settings.
    await this.prisma.user.delete({ where: { id: userId } });

    // Keep an anonymous record that an erasure happened — legitimate under
    // Art. 17(3)(b) — carrying no identifier back to the person.
    await this.audit.log({
      action: 'ACCOUNT_DELETED',
      entity: 'User',
      metadata: { erased: impact, at: new Date().toISOString() },
    });

    return {
      message: 'Your account and all associated data have been permanently deleted.',
      deleted: impact,
    };
  }
}
