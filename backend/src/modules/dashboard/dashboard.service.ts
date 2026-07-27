import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { BudgetEngineService } from '../budgets/budget-engine.service';

export interface DashboardRangeParams {
  start: Date;
  end: Date; // exclusive
  compareStart?: Date;
  compareEnd?: Date;
  anchorMonth: number; // month used for monthly widgets (budgets / daily)
  anchorYear: number;
}

@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly budgetEngine: BudgetEngineService,
  ) {}

  private monthRange(month: number, year: number) {
    return {
      start: new Date(Date.UTC(year, month - 1, 1)),
      end: new Date(Date.UTC(year, month, 1)),
    };
  }

  /** List of {month, year} whose start falls within [start, end). */
  private monthsInRange(start: Date, end: Date): { month: number; year: number }[] {
    const out: { month: number; year: number }[] = [];
    const cursor = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), 1));
    while (cursor < end) {
      out.push({ month: cursor.getUTCMonth() + 1, year: cursor.getUTCFullYear() });
      cursor.setUTCMonth(cursor.getUTCMonth() + 1);
    }
    return out;
  }

  // ----------------------------------------------------------------- Summary
  /** Core range aggregation with an optional comparison range for trends. */
  async getSummaryRange(userId: string, start: Date, end: Date, cStart?: Date, cEnd?: Date) {
    const hasCompare = !!cStart && !!cEnd;
    const [income, expense, prevIncome, prevExpense] = await Promise.all([
      this.prisma.income.aggregate({
        where: { userId, deletedAt: null, date: { gte: start, lt: end } },
        _sum: { amount: true },
      }),
      this.prisma.expense.aggregate({
        where: { userId, deletedAt: null, date: { gte: start, lt: end } },
        _sum: { amount: true },
      }),
      hasCompare
        ? this.prisma.income.aggregate({
            where: { userId, deletedAt: null, date: { gte: cStart, lt: cEnd } },
            _sum: { amount: true },
          })
        : Promise.resolve({ _sum: { amount: null } }),
      hasCompare
        ? this.prisma.expense.aggregate({
            where: { userId, deletedAt: null, date: { gte: cStart, lt: cEnd } },
            _sum: { amount: true },
          })
        : Promise.resolve({ _sum: { amount: null } }),
    ]);

    const totalIncome = Number(income._sum.amount ?? 0);
    const totalExpenses = Number(expense._sum.amount ?? 0);
    const netSavings = totalIncome - totalExpenses;
    const savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0;

    const prevIncomeTotal = Number(prevIncome._sum.amount ?? 0);
    const prevExpenseTotal = Number(prevExpense._sum.amount ?? 0);
    const prevSavings = prevIncomeTotal - prevExpenseTotal;

    return {
      totalIncome,
      totalExpenses,
      netSavings,
      savingsRate: Math.round(savingsRate * 10) / 10,
      hasComparison: hasCompare,
      comparison: { income: prevIncomeTotal, expenses: prevExpenseTotal, savings: prevSavings },
      trends: hasCompare
        ? {
            income: this.pctChange(totalIncome, prevIncomeTotal),
            expenses: this.pctChange(totalExpenses, prevExpenseTotal),
            savings: this.pctChange(netSavings, prevSavings),
          }
        : { income: 0, expenses: 0, savings: 0 },
      financialScore: this.computeScore(savingsRate, totalIncome, totalExpenses),
    };
  }

  /**
   * Month-based summary — kept for the AI module. Defaults comparison to the
   * immediately previous month unless a compare month/year is supplied.
   */
  async getSummary(
    userId: string,
    month: number,
    year: number,
    compareMonth?: number,
    compareYear?: number,
  ) {
    const { start, end } = this.monthRange(month, year);
    const prev =
      compareMonth && compareYear
        ? { month: compareMonth, year: compareYear }
        : month === 1
          ? { month: 12, year: year - 1 }
          : { month: month - 1, year };
    const prevRange = this.monthRange(prev.month, prev.year);
    const s = await this.getSummaryRange(userId, start, end, prevRange.start, prevRange.end);
    return { month, year, comparedTo: { month: prev.month, year: prev.year }, ...s };
  }

  private pctChange(current: number, previous: number): number {
    if (previous === 0) return current > 0 ? 100 : 0;
    return Math.round(((current - previous) / Math.abs(previous)) * 1000) / 10;
  }

  private computeScore(savingsRate: number, income: number, expenses: number): number {
    if (income === 0) return 0;
    let score = 50 + savingsRate * 0.5;
    if (expenses > income) score -= 20;
    return Math.max(0, Math.min(100, Math.round(score)));
  }

  // ------------------------------------------------------------ Distribution
  private async distribution(
    userId: string,
    table: 'income' | 'expense',
    start: Date,
    end: Date,
  ) {
    const model: any = table === 'income' ? this.prisma.income : this.prisma.expense;
    const grouped = await model.groupBy({
      by: ['categoryId'],
      where: { userId, deletedAt: null, date: { gte: start, lt: end } },
      _sum: { amount: true },
    });

    const categoryIds = grouped.map((g: any) => g.categoryId);
    const categories = await this.prisma.category.findMany({
      where: { id: { in: categoryIds } },
      select: { id: true, name: true, color: true, icon: true },
    });
    const catMap = new Map(categories.map((c) => [c.id, c]));
    const total = grouped.reduce((sum: number, g: any) => sum + Number(g._sum.amount ?? 0), 0);

    return grouped
      .map((g: any) => {
        const cat = catMap.get(g.categoryId);
        const amount = Number(g._sum.amount ?? 0);
        return {
          categoryId: g.categoryId,
          name: cat?.name ?? 'Unknown',
          color: cat?.color ?? '#94a3b8',
          icon: cat?.icon ?? 'circle',
          amount,
          percentage: total > 0 ? Math.round((amount / total) * 1000) / 10 : 0,
        };
      })
      .sort((a: any, b: any) => b.amount - a.amount);
  }

  async getExpenseDistribution(userId: string, month: number, year: number) {
    const { start, end } = this.monthRange(month, year);
    return this.distribution(userId, 'expense', start, end);
  }

  async getIncomeDistribution(userId: string, month: number, year: number) {
    const { start, end } = this.monthRange(month, year);
    return this.distribution(userId, 'income', start, end);
  }

  // -------------------------------------------------------------- Daily chart
  async getDailyExpenses(userId: string, month: number, year: number) {
    const { start, end } = this.monthRange(month, year);
    const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();

    const [expenses, budgetAgg] = await Promise.all([
      this.prisma.expense.findMany({
        where: { userId, deletedAt: null, date: { gte: start, lt: end } },
        select: { amount: true, date: true },
      }),
      this.prisma.monthlyBudget.aggregate({
        where: { userId, month, year, deletedAt: null },
        _sum: { amount: true },
      }),
    ]);

    const days = Array.from({ length: daysInMonth }, (_, i) => ({ day: i + 1, amount: 0 }));
    let total = 0;
    for (const e of expenses) {
      const d = e.date.getUTCDate();
      days[d - 1].amount += Number(e.amount);
      total += Number(e.amount);
    }

    const totalBudget = Number(budgetAgg._sum.amount ?? 0);
    const now = new Date();
    const isCurrentMonth = now.getUTCFullYear() === year && now.getUTCMonth() + 1 === month;
    const elapsedDays = isCurrentMonth
      ? Math.max(1, Math.min(daysInMonth, now.getUTCDate()))
      : daysInMonth;

    return {
      days,
      dailyObjective: totalBudget > 0 ? Math.round(totalBudget / daysInMonth) : null,
      averageSpent: Math.round(total / elapsedDays),
    };
  }

  // ------------------------------------------------------------------ Trend
  /**
   * One income/expense point per month across [start, end). Uses two grouped
   * SQL queries (not one query per month) so wide ranges stay a couple of
   * round-trips instead of dozens of concurrent queries.
   */
  async getTrendRange(userId: string, start: Date, end: Date) {
    const months = this.monthsInRange(start, end);
    // Cap to keep the chart readable; single-month ranges get a trailing view.
    const list =
      months.length <= 1
        ? this.monthsInRange(
            new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() - 5, 1)),
            end,
          )
        : months.slice(-24);
    if (list.length === 0) return [];

    const rangeStart = this.monthRange(list[0].month, list[0].year).start;
    const last = list[list.length - 1];
    const rangeEnd = this.monthRange(last.month, last.year).end;

    const [incomeRows, expenseRows] = await Promise.all([
      this.monthlyTotals('income', userId, rangeStart, rangeEnd),
      this.monthlyTotals('expenses', userId, rangeStart, rangeEnd),
    ]);

    const key = (y: number, m: number) => y * 100 + m;
    const incMap = new Map(incomeRows.map((r) => [key(r.y, r.mo), r.total]));
    const expMap = new Map(expenseRows.map((r) => [key(r.y, r.mo), r.total]));

    return list.map(({ month, year }) => ({
      month,
      year,
      label: new Date(Date.UTC(year, month - 1, 1)).toLocaleString('en', { month: 'short' }),
      income: incMap.get(key(year, month)) ?? 0,
      expenses: expMap.get(key(year, month)) ?? 0,
    }));
  }

  private async monthlyTotals(
    table: 'income' | 'expenses',
    userId: string,
    start: Date,
    end: Date,
  ): Promise<{ y: number; mo: number; total: number }[]> {
    // Table names are literals we control (not user input), so interpolation is safe.
    const sql = `
      SELECT EXTRACT(YEAR FROM "date")::int AS y,
             EXTRACT(MONTH FROM "date")::int AS mo,
             COALESCE(SUM("amount"), 0)::float8 AS total
      FROM "${table}"
      WHERE "user_id" = $1 AND "deleted_at" IS NULL AND "date" >= $2 AND "date" < $3
      GROUP BY 1, 2`;
    return this.prisma.$queryRawUnsafe<{ y: number; mo: number; total: number }[]>(
      sql,
      userId,
      start,
      end,
    );
  }

  /** Month-based trailing trend — kept for the AI module. */
  async getIncomeVsExpenses(userId: string, months: number, endMonth: number, endYear: number) {
    const start = new Date(Date.UTC(endYear, endMonth - months, 1));
    const end = new Date(Date.UTC(endYear, endMonth, 1));
    return this.getTrendRange(userId, start, end);
  }

  // ---------------------------------------------------------------- Recent
  async getRecentTransactions(userId: string, start: Date, end: Date, limit = 8) {
    const where = { userId, deletedAt: null, date: { gte: start, lt: end } };
    const [incomes, expenses] = await Promise.all([
      this.prisma.income.findMany({
        where,
        include: { category: true },
        orderBy: { date: 'desc' },
        take: limit,
      }),
      this.prisma.expense.findMany({
        where,
        include: { category: true },
        orderBy: { date: 'desc' },
        take: limit,
      }),
    ]);

    const combined = [
      ...incomes.map((i) => ({
        id: i.id,
        type: 'INCOME' as const,
        title: i.title,
        amount: Number(i.amount),
        date: i.date,
        category: i.category.name,
        color: i.category.color,
        icon: i.category.icon,
      })),
      ...expenses.map((e) => ({
        id: e.id,
        type: 'EXPENSE' as const,
        title: e.title,
        amount: Number(e.amount),
        date: e.date,
        category: e.category.name,
        color: e.category.color,
        icon: e.category.icon,
      })),
    ];
    return combined.sort((a, b) => b.date.getTime() - a.date.getTime()).slice(0, limit);
  }

  // --------------------------------------------------------------- Dashboard
  async getDashboard(userId: string, p: DashboardRangeParams) {
    const [summary, expenseDist, incomeDist, trend, budgets, recent, dailyExpenses] =
      await Promise.all([
        this.getSummaryRange(userId, p.start, p.end, p.compareStart, p.compareEnd),
        this.distribution(userId, 'expense', p.start, p.end),
        this.distribution(userId, 'income', p.start, p.end),
        this.getTrendRange(userId, p.start, p.end),
        this.budgetEngine.getStatuses(userId, p.anchorMonth, p.anchorYear),
        this.getRecentTransactions(userId, p.start, p.end, 8),
        this.getDailyExpenses(userId, p.anchorMonth, p.anchorYear),
      ]);

    return {
      summary,
      range: { from: p.start, to: p.end },
      comparedTo: p.compareStart && p.compareEnd ? { from: p.compareStart, to: p.compareEnd } : null,
      expenseDistribution: expenseDist,
      incomeDistribution: incomeDist,
      incomeVsExpenses: trend,
      budgets,
      recentTransactions: recent,
      dailyExpenses,
    };
  }
}
