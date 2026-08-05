import { Injectable, NotFoundException } from '@nestjs/common';
import { CategoryType, NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { BudgetEngineService } from '../budgets/budget-engine.service';
import { DashboardService } from '../dashboard/dashboard.service';
import { LoansService } from '../loans/loans.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateExpenseDto, QueryExpenseDto, UpdateExpenseDto } from './dto/expense.dto';

@Injectable()
export class ExpensesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly budgetEngine: BudgetEngineService,
    private readonly dashboard: DashboardService,
    private readonly notifications: NotificationsService,
    private readonly loans: LoansService,
  ) {}

  private pctChange(current: number, previous: number): number {
    if (previous === 0) return current > 0 ? 100 : 0;
    return Math.round(((current - previous) / Math.abs(previous)) * 1000) / 10;
  }

  /**
   * Aggregated overview for the Expenses screen: totals, avg/day, top category,
   * transaction count, fixed-vs-variable split (a category is "fixed" when it
   * also appears in the preceding equal-length window with a similar total —
   * i.e. a recurring charge), distribution and a 6-month trend.
   */
  /// Builds the category clause from a single id and/or a comma-separated list.
  private categoryWhere(categoryId?: string, categoryIds?: string) {
    const ids = [
      ...(categoryId ? [categoryId] : []),
      ...(categoryIds ? categoryIds.split(',').map((s) => s.trim()).filter(Boolean) : []),
    ];
    const unique = [...new Set(ids)];
    if (unique.length === 0) return {};
    return unique.length === 1 ? { categoryId: unique[0] } : { categoryId: { in: unique } };
  }

  async overview(userId: string, from: Date, to: Date, categoryIds?: string) {
    const lenMs = to.getTime() - from.getTime();
    const prevFrom = new Date(from.getTime() - lenMs);
    // Optional category filter — applied to both windows so the trend/comparison
    // stays consistent with what the user is looking at.
    const catWhere = this.categoryWhere(undefined, categoryIds);
    const hasCatFilter = Object.keys(catWhere).length > 0;

    const [items, prevItems] = await Promise.all([
      this.prisma.expense.findMany({
        where: { userId, deletedAt: null, date: { gte: from, lt: to }, ...catWhere },
        include: { category: true },
      }),
      this.prisma.expense.findMany({
        where: { userId, deletedAt: null, date: { gte: prevFrom, lt: from }, ...catWhere },
        select: { categoryId: true, amount: true },
      }),
    ]);

    const total = items.reduce((s, i) => s + Number(i.amount), 0);
    const count = items.length;
    const prevTotal = prevItems.reduce((s, i) => s + Number(i.amount), 0);
    const prevCount = prevItems.length;

    // Average per elapsed day (current window may still be running).
    const now = new Date();
    const endForDays = now < to ? now : to;
    const elapsedDays = Math.max(
      1,
      Math.ceil((endForDays.getTime() - from.getTime()) / (24 * 60 * 60 * 1000)),
    );
    const avgPerDay = Math.round(total / elapsedDays);

    // Category breakdown.
    const byCat = new Map<string, { name: string; color: string | null; amount: number }>();
    for (const i of items) {
      const cur =
        byCat.get(i.categoryId) ?? { name: i.category.name, color: i.category.color, amount: 0 };
      cur.amount += Number(i.amount);
      byCat.set(i.categoryId, cur);
    }
    const distribution = [...byCat.entries()]
      .map(([categoryId, c]) => ({
        categoryId,
        name: c.name,
        color: c.color ?? '#94a3b8',
        amount: c.amount,
        percentage: total > 0 ? Math.round((c.amount / total) * 1000) / 10 : 0,
      }))
      .sort((a, b) => b.amount - a.amount);

    // Fixed vs variable: category totals similar (±25%) across both windows.
    const prevByCat = new Map<string, number>();
    for (const p of prevItems) {
      prevByCat.set(p.categoryId, (prevByCat.get(p.categoryId) ?? 0) + Number(p.amount));
    }
    let fixedAmount = 0;
    for (const [catId, c] of byCat) {
      const prev = prevByCat.get(catId);
      if (prev && prev > 0 && Math.abs(c.amount - prev) / prev <= 0.25) {
        fixedAmount += c.amount;
      }
    }
    const variableAmount = total - fixedAmount;

    // 6-month trailing expense trend. When a category filter is active the
    // trend is computed from that category alone, so the chart matches the
    // figures above it.
    const last = new Date(to.getTime() - 1);
    let trend: { label: string; expenses: number }[];
    if (hasCatFilter) {
      const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
      const start = new Date(Date.UTC(last.getUTCFullYear(), last.getUTCMonth() - 5, 1));
      const endEx = new Date(Date.UTC(last.getUTCFullYear(), last.getUTCMonth() + 1, 1));
      const rows = await this.prisma.expense.findMany({
        where: { userId, deletedAt: null, ...catWhere, date: { gte: start, lt: endEx } },
        select: { date: true, amount: true },
      });
      trend = [];
      for (let i = 0; i < 6; i++) {
        const m = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + i, 1));
        const sum = rows
          .filter(
            (r) =>
              r.date.getUTCFullYear() === m.getUTCFullYear() &&
              r.date.getUTCMonth() === m.getUTCMonth(),
          )
          .reduce((s, r) => s + Number(r.amount), 0);
        trend.push({ label: months[m.getUTCMonth()], expenses: Math.round(sum) });
      }
    } else {
      const trendRaw = await this.dashboard.getIncomeVsExpenses(
        userId,
        6,
        last.getUTCMonth() + 1,
        last.getUTCFullYear(),
      );
      trend = trendRaw.map((p) => ({ label: p.label, expenses: p.expenses }));
    }

    return {
      total,
      count,
      avgPerDay,
      totalTrend: this.pctChange(total, prevTotal),
      countDiff: count - prevCount,
      topCategory: distribution[0] ?? null,
      fixed: {
        amount: fixedAmount,
        percentage: total > 0 ? Math.round((fixedAmount / total) * 100) : 0,
      },
      variable: {
        amount: variableAmount,
        percentage: total > 0 ? Math.round((variableAmount / total) * 100) : 0,
      },
      categoryCount: byCat.size,
      distribution,
      trend,
    };
  }

  private async assertCategory(userId: string, categoryId: string) {
    const category = await this.prisma.category.findFirst({
      where: { id: categoryId, userId, type: CategoryType.EXPENSE, deletedAt: null },
    });
    if (!category) throw new NotFoundException('Expense category not found');
    return category;
  }

  async create(userId: string, dto: CreateExpenseDto) {
    await this.assertCategory(userId, dto.categoryId);
    // Ownership is re-checked server-side: a loanId from the client is never
    // trusted, or one user could credit payments against another's loan.
    if (dto.loanId) await this.loans.assertPayable(userId, dto.loanId);
    const date = new Date(dto.date);
    const expense = await this.prisma.expense.create({
      data: {
        userId,
        categoryId: dto.categoryId,
        title: dto.title,
        amount: dto.amount,
        date,
        description: dto.description,
        paymentMethod: dto.paymentMethod,
        // '' means "no loan"; storing it verbatim would break the foreign key.
        loanId: dto.loanId || null,
        tags: dto.tags ?? [],
        receiptUrl: dto.receiptUrl,
      },
      include: { category: true },
    });

    await this.audit.log({
      userId,
      action: 'EXPENSE_CREATED',
      entity: 'Expense',
      entityId: expense.id,
    });

    // Fire-and-forget side effects (budget alerts + large expense alert).
    void this.budgetEngine.evaluateAndNotify(userId, dto.categoryId, date);
    // The month cap is independent: every category can be inside its own
    // budget while the month as a whole runs over.
    void this.budgetEngine.evaluateOverallAndNotify(userId, date);
    void this.checkLargeExpense(userId, dto.amount, dto.title);

    return expense;
  }

  private async checkLargeExpense(userId: string, amount: number, title: string) {
    const settings = await this.prisma.userSettings.findUnique({ where: { userId } });
    const threshold = Number(settings?.largeExpenseThreshold ?? 100000);
    if (amount >= threshold) {
      await this.notifications.create({
        userId,
        type: NotificationType.LARGE_EXPENSE,
        title: 'Large expense recorded',
        message: `A large expense "${title}" of ${Math.round(amount)} was recorded.`,
        metadata: { amount },
      });
    }
  }

  async list(userId: string, query: QueryExpenseDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where: Prisma.ExpenseWhereInput = {
      userId,
      deletedAt: null,
      ...this.categoryWhere(query.categoryId, query.categoryIds),
      ...(query.tag ? { tags: { has: query.tag } } : {}),
      ...(query.from || query.to
        ? {
            date: {
              ...(query.from ? { gte: new Date(query.from) } : {}),
              ...(query.to ? { lte: new Date(query.to) } : {}),
            },
          }
        : {}),
      ...(query.search
        ? {
            OR: [
              { title: { contains: query.search, mode: 'insensitive' } },
              { description: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total, sum] = await Promise.all([
      this.prisma.expense.findMany({
        where,
        include: { category: true },
        orderBy: { date: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.expense.count({ where }),
      this.prisma.expense.aggregate({ where, _sum: { amount: true } }),
    ]);

    return {
      items,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      totalAmount: Number(sum._sum.amount ?? 0),
    };
  }

  async findOne(userId: string, id: string) {
    const expense = await this.prisma.expense.findFirst({
      where: { id, userId, deletedAt: null },
      include: { category: true },
    });
    if (!expense) throw new NotFoundException('Expense not found');
    return expense;
  }

  async update(userId: string, id: string, dto: UpdateExpenseDto) {
    await this.findOne(userId, id);
    if (dto.categoryId) await this.assertCategory(userId, dto.categoryId);
    if (dto.loanId) await this.loans.assertPayable(userId, dto.loanId);
    const expense = await this.prisma.expense.update({
      where: { id },
      data: {
        ...(dto.title !== undefined ? { title: dto.title } : {}),
        ...(dto.categoryId !== undefined ? { categoryId: dto.categoryId } : {}),
        ...(dto.amount !== undefined ? { amount: dto.amount } : {}),
        ...(dto.date !== undefined ? { date: new Date(dto.date) } : {}),
        ...(dto.description !== undefined ? { description: dto.description } : {}),
        ...(dto.paymentMethod !== undefined ? { paymentMethod: dto.paymentMethod } : {}),
        // An empty string clears the link; undefined leaves it untouched.
        ...(dto.loanId !== undefined ? { loanId: dto.loanId || null } : {}),
        ...(dto.tags !== undefined ? { tags: dto.tags } : {}),
        ...(dto.receiptUrl !== undefined ? { receiptUrl: dto.receiptUrl } : {}),
      },
      include: { category: true },
    });
    await this.audit.log({ userId, action: 'EXPENSE_UPDATED', entity: 'Expense', entityId: id });
    void this.budgetEngine.evaluateAndNotify(userId, expense.categoryId, expense.date);
    void this.budgetEngine.evaluateOverallAndNotify(userId, expense.date);
    return expense;
  }

  async remove(userId: string, id: string) {
    await this.findOne(userId, id);
    await this.prisma.expense.update({ where: { id }, data: { deletedAt: new Date() } });
    await this.audit.log({ userId, action: 'EXPENSE_DELETED', entity: 'Expense', entityId: id });
    return { message: 'Expense deleted' };
  }
}
