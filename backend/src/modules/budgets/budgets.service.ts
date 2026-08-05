import { randomUUID } from 'crypto';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { CategoryType } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { BudgetEngineService } from './budget-engine.service';
import { UpsertBudgetDto, UpsertOverallBudgetDto } from './dto/budget.dto';

@Injectable()
export class BudgetsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly engine: BudgetEngineService,
  ) {}

  // ─────────────────────────────────────────────────────── period helpers

  /** Expands a starting month and a repeat count into concrete months. */
  private monthsFrom(month: number, year: number, count: number) {
    const out: { month: number; year: number }[] = [];
    for (let i = 0; i < count; i++) {
      const zeroBased = month - 1 + i;
      out.push({ month: (zeroBased % 12) + 1, year: year + Math.floor(zeroBased / 12) });
    }
    return out;
  }

  private isPast(month: number, year: number) {
    const now = new Date();
    const nowMonth = now.getUTCMonth() + 1;
    const nowYear = now.getUTCFullYear();
    return year < nowYear || (year === nowYear && month < nowMonth);
  }

  /**
   * Which months a repeat should actually write.
   *
   * The month the user explicitly targeted is always written — correcting a
   * past budget is legitimate. Repeats beyond it never touch a month that is
   * already over, because rewriting closed history would silently change what
   * a past month claims it budgeted.
   */
  private writableMonths(month: number, year: number, repeat: number) {
    const all = this.monthsFrom(month, year, repeat);
    return all.filter((m, i) => i === 0 || !this.isPast(m.month, m.year));
  }

  // ──────────────────────────────────────────────────── category budgets

  async upsert(userId: string, dto: UpsertBudgetDto) {
    const category = await this.prisma.category.findFirst({
      where: { id: dto.categoryId, userId, deletedAt: null },
    });
    if (!category) throw new NotFoundException('Category not found');
    if (category.type !== CategoryType.EXPENSE) {
      throw new BadRequestException('Budgets can only be set for expense categories');
    }

    const repeat = dto.repeatMonths ?? 1;
    const months = this.writableMonths(dto.month, dto.year, repeat);
    const seriesId = months.length > 1 ? randomUUID() : null;

    const rows = await this.prisma.$transaction(
      months.map(({ month, year }) =>
        this.prisma.monthlyBudget.upsert({
          where: {
            userId_categoryId_month_year: {
              userId,
              categoryId: dto.categoryId,
              month,
              year,
            },
          },
          create: {
            userId,
            categoryId: dto.categoryId,
            amount: dto.amount,
            month,
            year,
            rollover: dto.rollover ?? false,
            seriesId,
          },
          update: {
            amount: dto.amount,
            rollover: dto.rollover ?? false,
            deletedAt: null,
            seriesId,
          },
        }),
      ),
    );

    return {
      ...rows[0],
      monthsApplied: rows.length,
      skippedPastMonths: repeat - rows.length,
    };
  }

  async remove(userId: string, id: string, withSeries = false) {
    const budget = await this.prisma.monthlyBudget.findFirst({ where: { id, userId } });
    if (!budget) throw new NotFoundException('Budget not found');

    if (withSeries && budget.seriesId) {
      // Only the rest of the run: months already closed keep their record.
      const { count } = await this.prisma.monthlyBudget.updateMany({
        where: {
          userId,
          seriesId: budget.seriesId,
          deletedAt: null,
          OR: [
            { year: { gt: budget.year } },
            { year: budget.year, month: { gte: budget.month } },
          ],
        },
        data: { deletedAt: new Date() },
      });
      return { message: 'Budget series removed', removed: count };
    }

    await this.prisma.monthlyBudget.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
    return { message: 'Budget removed', removed: 1 };
  }

  // ───────────────────────────────────────────────────── overall budget

  async upsertOverall(userId: string, dto: UpsertOverallBudgetDto) {
    const repeat = dto.repeatMonths ?? 1;
    const months = this.writableMonths(dto.month, dto.year, repeat);
    const seriesId = months.length > 1 ? randomUUID() : null;

    const rows = await this.prisma.$transaction(
      months.map(({ month, year }) =>
        this.prisma.overallBudget.upsert({
          where: { userId_month_year: { userId, month, year } },
          create: { userId, amount: dto.amount, month, year, seriesId },
          update: { amount: dto.amount, deletedAt: null, seriesId },
        }),
      ),
    );

    return {
      ...rows[0],
      monthsApplied: rows.length,
      skippedPastMonths: repeat - rows.length,
    };
  }

  async removeOverall(userId: string, id: string, withSeries = false) {
    const budget = await this.prisma.overallBudget.findFirst({ where: { id, userId } });
    if (!budget) throw new NotFoundException('Overall budget not found');

    if (withSeries && budget.seriesId) {
      const { count } = await this.prisma.overallBudget.updateMany({
        where: {
          userId,
          seriesId: budget.seriesId,
          deletedAt: null,
          OR: [
            { year: { gt: budget.year } },
            { year: budget.year, month: { gte: budget.month } },
          ],
        },
        data: { deletedAt: new Date() },
      });
      return { message: 'Overall budget series removed', removed: count };
    }

    await this.prisma.overallBudget.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
    return { message: 'Overall budget removed', removed: 1 };
  }

  // ──────────────────────────────────────────────────────────── reading

  async getStatuses(userId: string, month: number, year: number) {
    return this.engine.getStatuses(userId, month, year);
  }

  /**
   * Everything the budgets screen needs for one month, in one round trip.
   *
   * `overall` and `categories` are deliberately separate figures: the sum of
   * category caps is NOT the month's budget, and conflating the two is what
   * made the old header claim a monthly budget the user had never set.
   */
  async overview(userId: string, month: number, year: number) {
    const [overall, categories, monthSpent] = await Promise.all([
      this.engine.overallStatus(userId, month, year),
      this.engine.getStatuses(userId, month, year),
      this.engine.spentForMonth(userId, month, year),
    ]);

    const budgeted = categories.reduce((sum, c) => sum + c.budget, 0);
    const spentOnBudgeted = categories.reduce((sum, c) => sum + c.spent, 0);

    return {
      month,
      year,
      overall,
      categories,
      totals: {
        /** Sum of the per-category caps — a coverage figure, not a month cap. */
        budgeted,
        /** Spending inside budgeted categories only. */
        spentOnBudgeted,
        /** Every expense of the month, budgeted or not. */
        monthSpent,
        /** Spending that no category budget is watching. */
        unbudgetedSpend: Math.max(0, monthSpent - spentOnBudgeted),
        categoryCount: categories.length,
        onTrack: categories.filter((c) => c.status === 'ok').length,
        atRisk: categories.filter((c) => c.status === 'warning' || c.status === 'danger')
          .length,
        exceeded: categories.filter((c) => c.status === 'exceeded').length,
      },
    };
  }
}
