import { Injectable, Logger } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

export type BudgetHealth = 'ok' | 'warning' | 'danger' | 'exceeded';

export interface BudgetStatus {
  id: string;
  categoryId: string;
  categoryName: string;
  icon: string | null;
  color: string | null;
  budget: number;
  spent: number;
  remaining: number;
  progress: number; // percentage 0-100+
  status: BudgetHealth;
  month: number;
  year: number;
}

/// The month's overall cap. `spent` counts every expense in the month, whether
/// or not its category carries a budget of its own.
export interface OverallBudgetStatus {
  id: string;
  budget: number;
  spent: number;
  remaining: number;
  progress: number;
  status: BudgetHealth;
  month: number;
  year: number;
  seriesId: string | null;
  /// Expenses that fall outside every budgeted category — the blind spot a
  /// per-category-only setup would miss entirely.
  uncategorisedSpend: number;
  /// Even pace for the month: what "on track" would look like today.
  expectedProgress: number | null;
  daysLeft: number | null;
  safeDailySpend: number | null;
}

@Injectable()
export class BudgetEngineService {
  private readonly logger = new Logger(BudgetEngineService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  private monthRange(month: number, year: number) {
    const start = new Date(Date.UTC(year, month - 1, 1));
    const end = new Date(Date.UTC(year, month, 1));
    return { start, end };
  }

  private classify(progress: number): BudgetStatus['status'] {
    if (progress >= 100) return 'exceeded';
    if (progress >= 90) return 'danger';
    if (progress >= 80) return 'warning';
    return 'ok';
  }

  async spentForCategory(userId: string, categoryId: string, month: number, year: number) {
    const { start, end } = this.monthRange(month, year);
    const agg = await this.prisma.expense.aggregate({
      where: { userId, categoryId, deletedAt: null, date: { gte: start, lt: end } },
      _sum: { amount: true },
    });
    return Number(agg._sum.amount ?? 0);
  }

  /** Every expense in the month, regardless of category. */
  async spentForMonth(userId: string, month: number, year: number) {
    const { start, end } = this.monthRange(month, year);
    const agg = await this.prisma.expense.aggregate({
      where: { userId, deletedAt: null, date: { gte: start, lt: end } },
      _sum: { amount: true },
    });
    return Number(agg._sum.amount ?? 0);
  }

  /**
   * Pace of the month, used to say "on track" rather than only "under cap".
   * A month that is already over gets a full 100% expectation; a future month
   * expects nothing yet.
   */
  private pacing(month: number, year: number) {
    const now = new Date();
    const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const nowMonth = now.getUTCMonth() + 1;
    const nowYear = now.getUTCFullYear();

    const isPast = year < nowYear || (year === nowYear && month < nowMonth);
    const isFuture = year > nowYear || (year === nowYear && month > nowMonth);

    if (isPast) return { expectedProgress: 100, daysLeft: 0, daysInMonth };
    if (isFuture) return { expectedProgress: 0, daysLeft: daysInMonth, daysInMonth };

    const day = now.getUTCDate();
    return {
      expectedProgress: Math.round((day / daysInMonth) * 1000) / 10,
      daysLeft: daysInMonth - day + 1, // today still counts
      daysInMonth,
    };
  }

  async overallStatus(
    userId: string,
    month: number,
    year: number,
  ): Promise<OverallBudgetStatus | null> {
    const row = await this.prisma.overallBudget.findFirst({
      where: { userId, month, year, deletedAt: null },
    });
    if (!row) return null;

    const budget = Number(row.amount);
    const spent = await this.spentForMonth(userId, month, year);
    const progress = budget > 0 ? (spent / budget) * 100 : 0;
    const remaining = budget - spent;
    const { expectedProgress, daysLeft } = this.pacing(month, year);

    // What is being spent outside every budgeted category this month.
    const budgeted = await this.prisma.monthlyBudget.findMany({
      where: { userId, month, year, deletedAt: null },
      select: { categoryId: true },
    });
    const { start, end } = this.monthRange(month, year);
    const outside = await this.prisma.expense.aggregate({
      where: {
        userId,
        deletedAt: null,
        date: { gte: start, lt: end },
        ...(budgeted.length
          ? { categoryId: { notIn: budgeted.map((b) => b.categoryId) } }
          : {}),
      },
      _sum: { amount: true },
    });

    return {
      id: row.id,
      budget,
      spent,
      remaining,
      progress: Math.round(progress * 10) / 10,
      status: this.classify(progress),
      month,
      year,
      seriesId: row.seriesId,
      uncategorisedSpend: Number(outside._sum.amount ?? 0),
      expectedProgress,
      daysLeft,
      safeDailySpend:
        daysLeft && daysLeft > 0 ? Math.max(0, remaining) / daysLeft : null,
    };
  }

  async getStatuses(userId: string, month: number, year: number): Promise<BudgetStatus[]> {
    const budgets = await this.prisma.monthlyBudget.findMany({
      where: { userId, month, year, deletedAt: null },
      include: { category: true },
    });

    // One grouped aggregate instead of a query per budget.
    const { start, end } = this.monthRange(month, year);
    const sums = await this.prisma.expense.groupBy({
      by: ['categoryId'],
      where: {
        userId,
        deletedAt: null,
        date: { gte: start, lt: end },
        categoryId: { in: budgets.map((b) => b.categoryId) },
      },
      _sum: { amount: true },
    });
    const spentByCategory = new Map(
      sums.map((s) => [s.categoryId, Number(s._sum.amount ?? 0)]),
    );

    const statuses: BudgetStatus[] = [];
    for (const b of budgets) {
      const spent = spentByCategory.get(b.categoryId) ?? 0;
      const budget = Number(b.amount);
      const progress = budget > 0 ? (spent / budget) * 100 : 0;
      statuses.push({
        id: b.id,
        categoryId: b.categoryId,
        categoryName: b.category.name,
        icon: b.category.icon,
        color: b.category.color,
        budget,
        spent,
        remaining: budget - spent,
        progress: Math.round(progress * 10) / 10,
        status: this.classify(progress),
        month,
        year,
      });
    }
    return statuses.sort((a, b) => b.progress - a.progress);
  }

  /**
   * Same threshold ladder as a category budget, but for the month as a whole.
   *
   * A user can be inside every category cap and still overshoot the month, so
   * this runs independently of [evaluateAndNotify]. Each rung fires at most
   * once per month; crossing 70 then 90 gives two messages, not two of the
   * same one.
   */
  async evaluateOverallAndNotify(userId: string, date: Date) {
    const month = date.getUTCMonth() + 1;
    const year = date.getUTCFullYear();

    const status = await this.overallStatus(userId, month, year);
    if (!status || status.budget <= 0) return;

    const settings = await this.prisma.userSettings.findUnique({ where: { userId } });
    if (settings?.notificationsEnabled === false) return;
    const threshold = settings?.budgetAlertThreshold ?? 80;

    const { progress, spent, budget, remaining, daysLeft, safeDailySpend } = status;

    let type: NotificationType | null = null;
    let rung = '';
    let title = '';
    let message = '';
    const left = Math.round(Math.max(0, remaining));

    if (progress >= 100) {
      type = NotificationType.BUDGET_EXCEEDED;
      rung = 'overall-100';
      title = '🚨 Budget du mois dépassé';
      message =
        `Vous avez dépensé ${Math.round(spent)} / ${Math.round(budget)} FCFA ce mois-ci, ` +
        `soit ${Math.round(progress)}% de votre budget global.`;
    } else if (progress >= 90) {
      type = NotificationType.BUDGET_WARNING;
      rung = 'overall-90';
      title = '⚠️ Budget du mois à 90%';
      message =
        `Il ne reste que ${left} FCFA sur votre budget global` +
        (daysLeft && daysLeft > 0
          ? ` pour ${daysLeft} jour${daysLeft > 1 ? 's' : ''}` +
            (safeDailySpend != null ? `, soit ${Math.round(safeDailySpend)} FCFA/jour.` : '.')
          : '.');
    } else if (progress >= Math.min(70, threshold)) {
      type = NotificationType.BUDGET_WARNING;
      rung = 'overall-70';
      title = 'ℹ️ Budget du mois à ' + Math.round(progress) + '%';
      message =
        `Vous avez utilisé ${Math.round(progress)}% de votre budget global ` +
        `(${Math.round(spent)} / ${Math.round(budget)} FCFA). Reste ${left} FCFA.`;
    }

    if (!type) return;

    // One message per rung per month — not one per expense.
    const { start, end } = this.monthRange(month, year);
    const existing = await this.prisma.notification.findFirst({
      where: {
        userId,
        createdAt: { gte: start, lt: end },
        metadata: { path: ['rung'], equals: rung },
      },
      select: { id: true },
    });
    if (existing) return;

    try {
      await this.notifications.create({
        userId,
        type,
        title,
        message,
        metadata: { scope: 'overall', rung, month, year, progress: Math.round(progress) },
      });
    } catch (err) {
      this.logger.error('Failed to emit overall budget notification', err as Error);
    }
  }

  /**
   * Recompute a single category budget after an expense change and emit
   * threshold notifications when a new threshold is crossed.
   */
  async evaluateAndNotify(userId: string, categoryId: string, date: Date) {
    const month = date.getUTCMonth() + 1;
    const year = date.getUTCFullYear();

    const budget = await this.prisma.monthlyBudget.findFirst({
      where: { userId, categoryId, month, year, deletedAt: null },
      include: { category: true },
    });
    if (!budget) return;

    const settings = await this.prisma.userSettings.findUnique({ where: { userId } });
    // Category alerts used to ignore this switch, so turning notifications off
    // silenced everything except budget warnings.
    if (settings?.notificationsEnabled === false) return;
    const threshold = settings?.budgetAlertThreshold ?? 80;

    const spent = await this.spentForCategory(userId, categoryId, month, year);
    const amount = Number(budget.amount);
    if (amount <= 0) return;
    const progress = (spent / amount) * 100;

    let type: NotificationType | null = null;
    let rung = '';
    let title = '';
    let message = '';

    if (progress >= 100) {
      type = NotificationType.BUDGET_EXCEEDED;
      rung = `cat-100:${categoryId}`;
      title = `🚨 Budget Dépassé (${budget.category.name})`;
      message = `Plafond dépassé ! Vous avez dépensé ${Math.round(spent)} / ${Math.round(amount)} FCFA pour ${budget.category.name}.`;
    } else if (progress >= 90) {
      type = NotificationType.BUDGET_WARNING;
      rung = `cat-90:${categoryId}`;
      title = `⚠️ Alerte Budget 90% (${budget.category.name})`;
      message = `Attention ! Vous avez utilisé ${Math.round(progress)}% du budget ${budget.category.name}. Reste: ${Math.round(Math.max(0, amount - spent))} FCFA.`;
    } else if (progress >= Math.min(70, threshold)) {
      type = NotificationType.BUDGET_WARNING;
      rung = `cat-70:${categoryId}`;
      title = `ℹ️ Suivi Budget 70% (${budget.category.name})`;
      message = `Vous avez atteint ${Math.round(progress)}% de votre budget ${budget.category.name} (${Math.round(spent)} / ${Math.round(amount)} FCFA).`;
    }

    if (!type) return;

    // De-duplicate per RUNG, not per type: 70% and 90% are both BUDGET_WARNING,
    // so keying on the type alone silently swallowed the 90% alert once the
    // 70% one had gone out.
    const { start, end } = this.monthRange(month, year);
    const existing = await this.prisma.notification.findFirst({
      where: {
        userId,
        createdAt: { gte: start, lt: end },
        metadata: { path: ['rung'], equals: rung },
      },
      select: { id: true },
    });
    if (existing) return;

    try {
      await this.notifications.create({
        userId,
        type,
        title,
        message,
        metadata: { categoryId, rung, month, year, progress: Math.round(progress) },
      });
    } catch (err) {
      this.logger.error('Failed to emit budget notification', err as Error);
    }
  }
}
