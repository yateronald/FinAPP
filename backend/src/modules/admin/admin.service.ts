import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../common/prisma/prisma.service';
import { TokenService } from '../auth/token.service';
import {
  AuditLogQueryDto,
  CreateAdminDto,
  DisableUserDto,
  ListUsersQueryDto,
} from './dto/admin.dto';

/** Fields safe to expose to admins — deliberately excludes financial content. */
const USER_SELECT = {
  id: true,
  email: true,
  firstName: true,
  lastName: true,
  role: true,
  isActive: true,
  emailVerified: true,
  mustChangePassword: true,
  disabledAt: true,
  disabledReason: true,
  lastLoginAt: true,
  createdAt: true,
  country: true,
} satisfies Prisma.UserSelect;

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
  ) {}

  // ------------------------------------------------------------- Audit
  /** Append-only record of an admin action. Never throws into the caller. */
  async audit(
    actorId: string,
    action: string,
    entity: string,
    entityId?: string,
    metadata?: Record<string, any>,
    ip?: string,
    userAgent?: string,
  ) {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId: actorId,
          action,
          entity,
          entityId,
          metadata: (metadata as Prisma.InputJsonValue) ?? undefined,
          ipAddress: ip,
          userAgent,
        },
      });
    } catch {
      /* auditing must never break the operation */
    }
  }

  // ------------------------------------------------------------- Stats
  /**
   * Platform health/usage. Aggregates only — no transaction titles or amounts
   * belonging to individual users are exposed here.
   */
  async stats() {
    const now = new Date();
    const in30 = new Date(now.getTime() - 30 * 86_400_000);
    const in7 = new Date(now.getTime() - 7 * 86_400_000);

    const [
      totalUsers,
      activeUsers,
      disabledUsers,
      admins,
      unverified,
      newLast30,
      activeLast7,
      expenseCount,
      incomeCount,
      budgetCount,
      notifications,
      devices,
      aiInsights,
    ] = await Promise.all([
      this.prisma.user.count({ where: { deletedAt: null } }),
      this.prisma.user.count({ where: { deletedAt: null, isActive: true } }),
      this.prisma.user.count({ where: { deletedAt: null, isActive: false } }),
      this.prisma.user.count({ where: { deletedAt: null, role: Role.ADMIN } }),
      this.prisma.user.count({ where: { deletedAt: null, emailVerified: false } }),
      this.prisma.user.count({ where: { deletedAt: null, createdAt: { gte: in30 } } }),
      this.prisma.user.count({ where: { deletedAt: null, lastLoginAt: { gte: in7 } } }),
      this.prisma.expense.count({ where: { deletedAt: null } }),
      this.prisma.income.count({ where: { deletedAt: null } }),
      this.prisma.monthlyBudget.count({ where: { deletedAt: null } }),
      this.prisma.notification.count(),
      this.prisma.fcmToken.count(),
      this.prisma.aiInsight.count(),
    ]);

    // Signups per day for the last 30 days (for the dashboard chart).
    const signupRows = await this.prisma.user.findMany({
      where: { deletedAt: null, createdAt: { gte: in30 } },
      select: { createdAt: true },
    });
    const byDay = new Map<string, number>();
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 86_400_000).toISOString().slice(0, 10);
      byDay.set(d, 0);
    }
    for (const r of signupRows) {
      const k = r.createdAt.toISOString().slice(0, 10);
      if (byDay.has(k)) byDay.set(k, (byDay.get(k) ?? 0) + 1);
    }

    // Real 30-day sparkline series for the stat cards — cumulative counts
    // reconstructed from createdAt / disabledAt (no synthetic data).
    const allUsers = await this.prisma.user.findMany({
      where: { deletedAt: null },
      select: { createdAt: true, role: true, isActive: true, disabledAt: true },
    });
    const days: Date[] = [];
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 86_400_000);
      days.push(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 23, 59, 59)));
    }
    const trends = {
      total: [] as number[],
      active: [] as number[],
      disabled: [] as number[],
      admins: [] as number[],
    };
    for (const day of days) {
      const created = allUsers.filter((u) => u.createdAt <= day);
      const disabledOn = created.filter((u) => !u.isActive && u.disabledAt && u.disabledAt <= day);
      trends.total.push(created.length);
      trends.disabled.push(disabledOn.length);
      trends.active.push(created.length - disabledOn.length);
      trends.admins.push(created.filter((u) => u.role === Role.ADMIN).length);
    }

    return {
      users: {
        total: totalUsers,
        active: activeUsers,
        disabled: disabledUsers,
        admins,
        unverified,
        newLast30,
        activeLast7,
      },
      usage: {
        expenses: expenseCount,
        incomes: incomeCount,
        budgets: budgetCount,
        notifications,
        registeredDevices: devices,
        aiInsights,
      },
      signupsByDay: [...byDay.entries()].map(([date, count]) => ({ date, count })),
      trends,
    };
  }

  // ------------------------------------------------------------- Users
  async listUsers(query: ListUsersQueryDto) {
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 25, 100);
    const search = query.search?.trim();

    const where: Prisma.UserWhereInput = {
      deletedAt: null,
      ...(query.role ? { role: query.role } : {}),
      ...(query.isActive !== undefined ? { isActive: query.isActive } : {}),
      ...(search
        ? {
            OR: [
              { email: { contains: search, mode: 'insensitive' } },
              { firstName: { contains: search, mode: 'insensitive' } },
              { lastName: { contains: search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        select: USER_SELECT,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.user.count({ where }),
    ]);

    return { items, total, page, limit, pages: Math.ceil(total / limit) };
  }

  /** Per-user detail: activity counters only, never transaction contents. */
  async userDetail(id: string) {
    const user = await this.prisma.user.findFirst({
      where: { id, deletedAt: null },
      select: USER_SELECT,
    });
    if (!user) throw new NotFoundException('User not found');

    const [expenses, incomes, budgets, devices, sessions, lastActions] = await Promise.all([
      this.prisma.expense.count({ where: { userId: id, deletedAt: null } }),
      this.prisma.income.count({ where: { userId: id, deletedAt: null } }),
      this.prisma.monthlyBudget.count({ where: { userId: id, deletedAt: null } }),
      this.prisma.fcmToken.count({ where: { userId: id } }),
      this.prisma.refreshToken.count({ where: { userId: id, revokedAt: null } }),
      this.prisma.auditLog.findMany({
        where: { entityId: id },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);

    return {
      user,
      activity: { expenses, incomes, budgets, devices, activeSessions: sessions },
      recentAdminActions: lastActions,
    };
  }

  /**
   * Enable/disable an account. Disabling revokes every refresh token so any
   * live session dies immediately instead of surviving until it expires.
   */
  async setActive(actorId: string, targetId: string, active: boolean, dto: DisableUserDto = {}) {
    if (actorId === targetId) {
      throw new ForbiddenException('You cannot disable your own account');
    }
    const target = await this.prisma.user.findFirst({
      where: { id: targetId, deletedAt: null },
      select: { id: true, role: true, isActive: true, email: true },
    });
    if (!target) throw new NotFoundException('User not found');

    if (!active && target.role === Role.ADMIN) {
      await this.assertNotLastAdmin(targetId);
    }

    const user = await this.prisma.user.update({
      where: { id: targetId },
      data: {
        isActive: active,
        disabledAt: active ? null : new Date(),
        disabledReason: active ? null : (dto.reason ?? null),
      },
      select: USER_SELECT,
    });

    if (!active) await this.tokens.revokeAllForUser(targetId);

    await this.audit(
      actorId,
      active ? 'USER_ENABLED' : 'USER_DISABLED',
      'User',
      targetId,
      { email: target.email, reason: dto.reason },
    );
    return user;
  }

  /**
   * Admin-initiated password reset. Generates a single-use temporary password,
   * forces a change at next login and kills all existing sessions.
   * The temp password is returned ONCE and never stored in plain text.
   */
  async resetPassword(actorId: string, targetId: string) {
    const target = await this.prisma.user.findFirst({
      where: { id: targetId, deletedAt: null },
      select: { id: true, email: true },
    });
    if (!target) throw new NotFoundException('User not found');

    const tempPassword = this.generateTempPassword();
    const passwordHash = await this.tokens.hashPassword(tempPassword);

    await this.prisma.user.update({
      where: { id: targetId },
      data: {
        passwordHash,
        mustChangePassword: true,
        passwordChangedAt: new Date(),
      },
    });
    await this.tokens.revokeAllForUser(targetId);

    await this.audit(actorId, 'USER_PASSWORD_RESET', 'User', targetId, {
      email: target.email,
    });

    return {
      email: target.email,
      temporaryPassword: tempPassword,
      message:
        'Share this password securely. The user must change it at their next login.',
    };
  }

  // ------------------------------------------------------------- Admins
  /**
   * Creates an ADMIN account. Because `User.email` is globally unique, an email
   * already used by a finance user cannot be reused — we surface that clearly.
   */
  async createAdmin(actorId: string, dto: CreateAdminDto) {
    const email = dto.email.trim().toLowerCase();
    const existing = await this.prisma.user.findUnique({
      where: { email },
      select: { id: true, role: true, deletedAt: true },
    });
    if (existing) {
      throw new ConflictException(
        existing.role === Role.ADMIN
          ? 'An admin account with this email already exists'
          : 'This email is already used by a finance account and cannot be reused for an admin',
      );
    }

    const passwordHash = await this.tokens.hashPassword(dto.password);
    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        firstName: dto.firstName,
        lastName: dto.lastName,
        role: Role.ADMIN,
        emailVerified: true, // created by a trusted admin
        mustChangePassword: true, // must set their own password on first login
        settings: { create: {} },
      },
      select: USER_SELECT,
    });

    await this.audit(actorId, 'ADMIN_CREATED', 'User', user.id, { email });
    return user;
  }

  async listAdmins() {
    return this.prisma.user.findMany({
      where: { deletedAt: null, role: Role.ADMIN },
      select: USER_SELECT,
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Prevents locking everyone out by removing/disabling the final admin. */
  private async assertNotLastAdmin(excludingId: string) {
    const remaining = await this.prisma.user.count({
      where: {
        deletedAt: null,
        role: Role.ADMIN,
        isActive: true,
        id: { not: excludingId },
      },
    });
    if (remaining === 0) {
      throw new BadRequestException('Cannot disable the last active admin account');
    }
  }

  // ------------------------------------------------------------- Audit log
  /** Actions that change account state or credentials — the ones worth watching. */
  private static readonly SENSITIVE_ACTIONS = [
    'USER_DISABLED',
    'USER_ENABLED',
    'USER_PASSWORD_RESET',
    'PASSWORD_CHANGED',
    'PASSWORD_RESET',
    'ADMIN_CREATED',
    'ACCOUNT_DELETED',
    'LOGOUT_ALL',
  ];

  /** KPI cards + 14-day sparklines for the audit screen, over a date range. */
  async auditStats(from?: string, to?: string) {
    const end = to ? new Date(`${to}T23:59:59.999Z`) : new Date();
    const start = from
      ? new Date(`${from}T00:00:00.000Z`)
      : new Date(end.getTime() - 29 * 86_400_000);

    const rows = await this.prisma.auditLog.findMany({
      where: { createdAt: { gte: start, lte: end } },
      select: { action: true, createdAt: true },
    });

    const isSensitive = (a: string) => AdminService.SENSITIVE_ACTIONS.includes(a);
    const total = rows.length;
    const sensitive = rows.filter((r) => isSensitive(r.action)).length;
    const logins = rows.filter((r) => r.action === 'LOGIN').length;
    const failures = rows.filter((r) => r.action === 'LOGIN_FAILED').length;

    // Daily buckets across the selected window (capped so the sparkline stays readable).
    const dayMs = 86_400_000;
    const spanDays = Math.max(1, Math.min(30, Math.ceil((end.getTime() - start.getTime()) / dayMs)));
    const series = { total: [] as number[], sensitive: [] as number[], logins: [] as number[], failures: [] as number[] };
    for (let i = spanDays - 1; i >= 0; i--) {
      const dayEnd = new Date(end.getTime() - i * dayMs);
      const dayStart = new Date(dayEnd.getTime() - dayMs);
      const inDay = rows.filter((r) => r.createdAt > dayStart && r.createdAt <= dayEnd);
      series.total.push(inDay.length);
      series.sensitive.push(inDay.filter((r) => isSensitive(r.action)).length);
      series.logins.push(inDay.filter((r) => r.action === 'LOGIN').length);
      series.failures.push(inDay.filter((r) => r.action === 'LOGIN_FAILED').length);
    }

    const share = (n: number) => (total ? Math.round((n / total) * 100) : 0);
    return {
      from: start.toISOString().slice(0, 10),
      to: end.toISOString().slice(0, 10),
      total,
      sensitive,
      logins,
      failures,
      shares: { total: 100, sensitive: share(sensitive), logins: share(logins), failures: share(failures) },
      series,
    };
  }

  async auditLogs(query: AuditLogQueryDto) {
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 50, 200);
    const where: Prisma.AuditLogWhereInput = {
      ...(query.action ? { action: query.action } : {}),
      ...(query.entity ? { entity: query.entity } : {}),
      ...(query.userId ? { userId: query.userId } : {}),
      ...(query.from || query.to
        ? {
            createdAt: {
              ...(query.from ? { gte: new Date(`${query.from}T00:00:00.000Z`) } : {}),
              ...(query.to ? { lte: new Date(`${query.to}T23:59:59.999Z`) } : {}),
            },
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          user: { select: { id: true, email: true, firstName: true, lastName: true } },
        },
      }),
      this.prisma.auditLog.count({ where }),
    ]);
    return { items, total, page, limit, pages: Math.ceil(total / limit) };
  }

  /** Readable temp password, e.g. "Fyn-8HK2-QW4T". */
  private generateTempPassword(): string {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no look-alikes
    const block = (n: number) =>
      Array.from(randomBytes(n))
        .map((b) => alphabet[b % alphabet.length])
        .join('');
    return `Fyn-${block(4)}-${block(4)}`;
  }
}
