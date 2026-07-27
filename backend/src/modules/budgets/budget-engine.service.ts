import { Injectable, Logger } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

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
  status: 'ok' | 'warning' | 'danger' | 'exceeded';
  month: number;
  year: number;
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

  async getStatuses(userId: string, month: number, year: number): Promise<BudgetStatus[]> {
    const budgets = await this.prisma.monthlyBudget.findMany({
      where: { userId, month, year, deletedAt: null },
      include: { category: true },
    });

    const statuses: BudgetStatus[] = [];
    for (const b of budgets) {
      const spent = await this.spentForCategory(userId, b.categoryId, month, year);
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
    const threshold = settings?.budgetAlertThreshold ?? 80;

    const spent = await this.spentForCategory(userId, categoryId, month, year);
    const amount = Number(budget.amount);
    if (amount <= 0) return;
    const progress = (spent / amount) * 100;

    let type: NotificationType | null = null;
    let title = '';
    let message = '';

    if (progress >= 100) {
      type = NotificationType.BUDGET_EXCEEDED;
      title = `🚨 Budget Dépassé (${budget.category.name})`;
      message = `Plafond dépassé ! Vous avez dépensé ${Math.round(spent)} / ${Math.round(amount)} FCFA pour ${budget.category.name}.`;
    } else if (progress >= 90) {
      type = NotificationType.BUDGET_WARNING;
      title = `⚠️ Alerte Budget 90% (${budget.category.name})`;
      message = `Attention ! Vous avez utilisé ${Math.round(progress)}% du budget ${budget.category.name}. Reste: ${Math.round(Math.max(0, amount - spent))} FCFA.`;
    } else if (progress >= 70 || progress >= threshold) {
      type = NotificationType.BUDGET_WARNING;
      title = `ℹ️ Suivi Budget 70% (${budget.category.name})`;
      message = `Vous avez atteint ${Math.round(progress)}% de votre budget ${budget.category.name} (${Math.round(spent)} / ${Math.round(amount)} FCFA).`;
    }

    if (!type) return;

    // De-duplicate: avoid repeating the same notification for this budget/month.
    const { start, end } = this.monthRange(month, year);
    const existing = await this.prisma.notification.findFirst({
      where: {
        userId,
        type,
        createdAt: { gte: start, lt: end },
        metadata: { path: ['categoryId'], equals: categoryId },
      },
    });
    if (existing) return;

    try {
      await this.notifications.create({
        userId,
        type,
        title,
        message,
        metadata: { categoryId, month, year, progress: Math.round(progress) },
      });
    } catch (err) {
      this.logger.error('Failed to emit budget notification', err as Error);
    }
  }
}
