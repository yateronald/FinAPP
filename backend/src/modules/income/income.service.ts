import { Injectable, NotFoundException } from '@nestjs/common';
import { CategoryType, LoanDirection, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { DashboardService } from '../dashboard/dashboard.service';
import { LoansService } from '../loans/loans.service';
import { MoneyWriterService } from '../fx/money-writer.service';
import { CreateIncomeDto, QueryIncomeDto, UpdateIncomeDto } from './dto/income.dto';

@Injectable()
export class IncomeService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly dashboard: DashboardService,
    private readonly loans: LoansService,
    private readonly money: MoneyWriterService,
  ) {}

  private pctChange(current: number, previous: number): number {
    if (previous === 0) return current > 0 ? 100 : 0;
    return Math.round(((current - previous) / Math.abs(previous)) * 1000) / 10;
  }

  private monthsBetween(start: Date, end: Date): number {
    return Math.max(
      1,
      (end.getUTCFullYear() - start.getUTCFullYear()) * 12 +
        (end.getUTCMonth() - start.getUTCMonth()),
    );
  }

  /**
   * Aggregated overview for the Income screen: totals, averages, biggest
   * income, recurring vs one-time split, category breakdown and a 6-month
   * income trend — all for the given date window.
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
    const catWhere = this.categoryWhere(undefined, categoryIds);
    const hasCatFilter = Object.keys(catWhere).length > 0;
    const items = await this.prisma.income.findMany({
      where: {
        userId,
        deletedAt: null,
        date: { gte: from, lt: to },
        ...catWhere,
      },
      include: { category: true },
    });

    const total = items.reduce((s, i) => s + Number(i.amount), 0);
    const count = items.length;
    const recurringAmount = items
      .filter((i) => i.isRecurring)
      .reduce((s, i) => s + Number(i.amount), 0);
    const oneTimeAmount = total - recurringAmount;
    const months = this.monthsBetween(from, to);
    const average = months > 0 ? Math.round(total / months) : total;

    // Biggest single income.
    let max: { amount: number; title: string; category: string; date: Date } | null = null;
    for (const i of items) {
      const amt = Number(i.amount);
      if (!max || amt > max.amount) {
        max = { amount: amt, title: i.title, category: i.category.name, date: i.date };
      }
    }

    // Category breakdown.
    const byCat = new Map<string, { name: string; color: string | null; amount: number }>();
    for (const i of items) {
      const key = i.categoryId;
      const cur = byCat.get(key) ?? { name: i.category.name, color: i.category.color, amount: 0 };
      cur.amount += Number(i.amount);
      byCat.set(key, cur);
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

    // Trend over the previous, equal-length window for the % change.
    const lenMs = to.getTime() - from.getTime();
    const prevAgg = await this.prisma.income.aggregate({
      where: {
        userId,
        deletedAt: null,
        date: { gte: new Date(from.getTime() - lenMs), lt: from },
      },
      _sum: { amount: true },
    });
    const prevTotal = Number(prevAgg._sum.amount ?? 0);

    // 6-month trailing income trend ending at the window end. With a category
    // filter it is computed from that category alone so the chart matches the
    // figures above it.
    const last = new Date(to.getTime() - 1);
    let trend: { label: string; income: number }[];
    if (hasCatFilter) {
      const monthNames = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
      const start = new Date(Date.UTC(last.getUTCFullYear(), last.getUTCMonth() - 5, 1));
      const endEx = new Date(Date.UTC(last.getUTCFullYear(), last.getUTCMonth() + 1, 1));
      const rows = await this.prisma.income.findMany({
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
        trend.push({ label: monthNames[m.getUTCMonth()], income: Math.round(sum) });
      }
    } else {
      const trendRaw = await this.dashboard.getIncomeVsExpenses(
        userId,
        6,
        last.getUTCMonth() + 1,
        last.getUTCFullYear(),
      );
      trend = trendRaw.map((p) => ({ label: p.label, income: p.income }));
    }

    return {
      total,
      count,
      average,
      totalTrend: this.pctChange(total, prevTotal),
      averageTrend: this.pctChange(average, months > 0 ? Math.round(prevTotal / months) : prevTotal),
      recurring: {
        amount: recurringAmount,
        percentage: total > 0 ? Math.round((recurringAmount / total) * 100) : 0,
      },
      oneTime: {
        amount: oneTimeAmount,
        percentage: total > 0 ? Math.round((oneTimeAmount / total) * 100) : 0,
      },
      max,
      distribution,
      trend,
    };
  }

  private async assertCategory(userId: string, categoryId: string) {
    const category = await this.prisma.category.findFirst({
      where: { id: categoryId, userId, type: CategoryType.INCOME, deletedAt: null },
    });
    if (!category) throw new NotFoundException('Income category not found');
    return category;
  }

  async create(userId: string, dto: CreateIncomeDto) {
    await this.assertCategory(userId, dto.categoryId);
    // Ownership AND direction are re-checked server-side: a loanId from the
    // client is never trusted, and an income may only settle money lent out.
    if (dto.loanId) {
      await this.loans.assertPayable(userId, dto.loanId, LoanDirection.LENT);
    }
    // Converts and freezes the rate when entered in another currency; falls
    // back to the amount as typed if rates are unavailable.
    const money = await this.money.prepare(userId, dto.amount, dto.originalCurrency);
    const income = await this.prisma.income.create({
      data: {
        userId,
        categoryId: dto.categoryId,
        title: dto.title,
        ...this.money.toColumns(money),
        date: new Date(dto.date),
        description: dto.description,
        isRecurring: dto.isRecurring ?? false,
        // '' means "no loan"; storing it verbatim would break the foreign key.
        loanId: dto.loanId || null,
      },
      include: { category: true },
    });
    await this.audit.log({ userId, action: 'INCOME_CREATED', entity: 'Income', entityId: income.id });
    return money.fallbackReason
      ? { ...income, fxFallback: money.fallbackReason, baseCurrency: money.baseCurrency }
      : income;
  }

  async list(userId: string, query: QueryIncomeDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where: Prisma.IncomeWhereInput = {
      userId,
      deletedAt: null,
      ...this.categoryWhere(query.categoryId, query.categoryIds),
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
      this.prisma.income.findMany({
        where,
        include: { category: true },
        orderBy: { date: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.income.count({ where }),
      this.prisma.income.aggregate({ where, _sum: { amount: true } }),
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
    const income = await this.prisma.income.findFirst({
      where: { id, userId, deletedAt: null },
      include: { category: true },
    });
    if (!income) throw new NotFoundException('Income not found');
    return income;
  }

  async update(userId: string, id: string, dto: UpdateIncomeDto) {
    // Own the row first, then validate what is being written to it.
    await this.findOne(userId, id);
    if (dto.categoryId) await this.assertCategory(userId, dto.categoryId);
    if (dto.loanId) {
      await this.loans.assertPayable(userId, dto.loanId, LoanDirection.LENT);
    }
    const income = await this.prisma.income.update({
      where: { id },
      data: {
        ...(dto.title !== undefined ? { title: dto.title } : {}),
        ...(dto.categoryId !== undefined ? { categoryId: dto.categoryId } : {}),
        ...(dto.amount !== undefined ? { amount: dto.amount } : {}),
        ...(dto.date !== undefined ? { date: new Date(dto.date) } : {}),
        ...(dto.description !== undefined ? { description: dto.description } : {}),
        ...(dto.isRecurring !== undefined ? { isRecurring: dto.isRecurring } : {}),
        // An empty string clears the link; undefined leaves it untouched.
        ...(dto.loanId !== undefined ? { loanId: dto.loanId || null } : {}),
      },
      include: { category: true },
    });
    await this.audit.log({ userId, action: 'INCOME_UPDATED', entity: 'Income', entityId: id });
    return income;
  }

  async remove(userId: string, id: string) {
    await this.findOne(userId, id);
    await this.prisma.income.update({ where: { id }, data: { deletedAt: new Date() } });
    await this.audit.log({ userId, action: 'INCOME_DELETED', entity: 'Income', entityId: id });
    return { message: 'Income deleted' };
  }
}
