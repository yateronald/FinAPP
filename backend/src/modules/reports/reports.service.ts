import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { BudgetEngineService } from '../budgets/budget-engine.service';
import { DashboardService } from '../dashboard/dashboard.service';
import { ReportPeriod, ReportQueryDto } from './dto/report.dto';

@Injectable()
export class ReportsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly dashboard: DashboardService,
    private readonly budgetEngine: BudgetEngineService,
  ) {}

  private pct(current: number, previous: number): number {
    if (previous === 0) return current > 0 ? 100 : 0;
    return Math.round(((current - previous) / Math.abs(previous)) * 1000) / 10;
  }

  /**
   * Rich, range-accurate overview for the Reports screen. Everything (summary,
   * category breakdown, trend, budget adherence, stats) is computed over the
   * exact selected window, and can be filtered to a single category. No AI.
   */
  async overview(userId: string, query: ReportQueryDto) {
    const { from, to } = this.resolveRange(query);
    const categoryId = query.categoryId?.trim() || undefined;
    const catWhere = categoryId ? { categoryId } : {};

    const lenMs = Math.max(1, to.getTime() - from.getTime());
    const prevFrom = new Date(from.getTime() - lenMs);
    const anchor = new Date(to.getTime() - 1);
    const anchorMonth = anchor.getUTCMonth() + 1;
    const anchorYear = anchor.getUTCFullYear();

    const [incomes, expenses, prevInc, prevExp, budgetStatuses, selectedCat, trend6] =
      await Promise.all([
      this.prisma.income.findMany({
        where: { userId, deletedAt: null, date: { gte: from, lt: to }, ...catWhere },
        include: { category: true },
        orderBy: { date: 'asc' },
      }),
      this.prisma.expense.findMany({
        where: { userId, deletedAt: null, date: { gte: from, lt: to }, ...catWhere },
        include: { category: true },
        orderBy: { date: 'asc' },
      }),
      this.prisma.income.aggregate({
        where: { userId, deletedAt: null, date: { gte: prevFrom, lt: from }, ...catWhere },
        _sum: { amount: true },
      }),
      this.prisma.expense.aggregate({
        where: { userId, deletedAt: null, date: { gte: prevFrom, lt: from }, ...catWhere },
        _sum: { amount: true },
      }),
      this.budgetEngine.getStatuses(userId, anchorMonth, anchorYear),
      categoryId
        ? this.prisma.category.findUnique({ where: { id: categoryId }, select: { name: true } })
        : Promise.resolve(null),
        // 6-month evolution — kept for the web report's evolution table.
        this.dashboard.getIncomeVsExpenses(userId, 6, anchorMonth, anchorYear),
      ]);

    const round1 = (n: number) => Math.round(n * 10) / 10;
    const totalIncome = incomes.reduce((s, i) => s + Number(i.amount), 0);
    const totalExpenses = expenses.reduce((s, e) => s + Number(e.amount), 0);
    const savings = totalIncome - totalExpenses;
    const savingsRate = totalIncome > 0 ? round1((savings / totalIncome) * 100) : 0;

    const prevIncome = Number(prevInc._sum.amount ?? 0);
    const prevExpenses = Number(prevExp._sum.amount ?? 0);
    const prevSavings = prevIncome - prevExpenses;
    const prevRate = prevIncome > 0 ? round1((prevSavings / prevIncome) * 100) : 0;

    const expenseByCategory = this.groupByCategory(expenses, totalExpenses);
    const incomeByCategory = this.groupByCategory(incomes, totalIncome);
    const trend = this.buildTrend(from, to, incomes, expenses);

    // Budget adherence over the range: the monthly cap scaled by the number of
    // calendar months the window spans, compared with what was actually spent.
    let monthsInRange = 0;
    for (let c = new Date(Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), 1)); c < to; ) {
      monthsInRange++;
      c.setUTCMonth(c.getUTCMonth() + 1);
    }
    monthsInRange = Math.max(1, monthsInRange);
    const spentByCat = new Map(expenseByCategory.map((c) => [c.category, c.amount]));
    let budgetItems = budgetStatuses.map((b) => {
      const spent = spentByCat.get(b.categoryName) ?? 0;
      const effBudget = Number(b.budget) * monthsInRange;
      const progress = effBudget > 0 ? Math.round((spent / effBudget) * 100) : 0;
      return {
        category: b.categoryName,
        color: b.color,
        icon: b.icon,
        budget: effBudget,
        spent,
        progress,
        status: progress > 100 ? 'exceeded' : progress >= 80 ? 'warning' : 'ok',
      };
    });
    if (selectedCat) budgetItems = budgetItems.filter((b) => b.category === selectedCat.name);
    budgetItems.sort((a, b) => b.progress - a.progress);
    const totalBudgets = budgetItems.length;
    const respected = budgetItems.filter((b) => b.status !== 'exceeded').length;
    const respectedPct = totalBudgets > 0 ? Math.round((respected / totalBudgets) * 100) : 0;

    const days = Math.max(1, Math.round(lenMs / 86_400_000));
    const largest = expenses.reduce<(typeof expenses)[number] | null>(
      (mx, e) => (Number(e.amount) > Number(mx?.amount ?? -1) ? e : mx),
      null,
    );

    // --- Web-report back-compat fields (mobile ignores these) ---
    const rate = (inc: number, sav: number) => (inc > 0 ? round1((sav / inc) * 100) : 0);
    const monthlyEvolution = trend6.map((p) => ({
      month: p.month,
      year: p.year,
      label: p.label,
      income: p.income,
      expenses: p.expenses,
      savings: p.income - p.expenses,
      savingsRate: rate(p.income, p.income - p.expenses),
    }));
    const dir = totalExpenses <= prevExpenses ? 'diminué' : 'augmenté';
    const expDelta = Math.abs(this.pct(totalExpenses, prevExpenses));
    const aiSummary =
      totalIncome === 0 && totalExpenses === 0
        ? 'Aucune donnée pour cette période.'
        : `Vos dépenses ont ${dir} de ${expDelta}% par rapport à la période précédente.` +
          (savingsRate >= 20
            ? ' Vous êtes sur la bonne voie pour votre épargne !'
            : ' Continuez à surveiller vos dépenses.');

    return {
      period: query.period,
      from,
      to,
      filter: { categoryId: categoryId ?? null, categoryName: selectedCat?.name ?? null },
      summary: {
        income: totalIncome,
        incomeTrend: this.pct(totalIncome, prevIncome),
        incomeSeries: trend.map((t) => t.income),
        expenses: totalExpenses,
        expenseTrend: this.pct(totalExpenses, prevExpenses),
        expenseSeries: trend.map((t) => t.expenses),
        savings,
        savingsTrend: this.pct(savings, prevSavings),
        savingsSeries: trend.map((t) => t.savings),
        savingsRate,
        savingsRateTrend: round1(savingsRate - prevRate),
        rateSeries: trend.map((t) => (t.income > 0 ? round1((t.savings / t.income) * 100) : 0)),
      },
      incomeVsExpenses: trend,
      trend,
      expenseByCategory,
      incomeByCategory,
      budgets: {
        respectedPct,
        respectedCount: respected,
        totalCount: totalBudgets,
        monthsInRange,
        items: budgetItems,
      },
      stats: {
        txCount: incomes.length + expenses.length,
        expenseCount: expenses.length,
        incomeCount: incomes.length,
        avgExpense: expenses.length ? Math.round(totalExpenses / expenses.length) : 0,
        dailyAvgExpense: Math.round(totalExpenses / days),
        days,
        topCategory: expenseByCategory[0]?.category ?? null,
        largestExpense: largest
          ? {
              title: largest.title,
              amount: Number(largest.amount),
              category: largest.category?.name ?? null,
              date: largest.date,
            }
          : null,
      },
      // Back-compat for the web report:
      monthlyEvolution,
      aiSummary,
    };
  }

  /** Group transactions by category name with amount, count and share. */
  private groupByCategory(txs: any[], total: number) {
    const map = new Map<string, { category: string; color: any; icon: any; amount: number; count: number }>();
    for (const t of txs) {
      const name = t.category?.name ?? 'Autre';
      const cur =
        map.get(name) ??
        { category: name, color: t.category?.color ?? null, icon: t.category?.icon ?? null, amount: 0, count: 0 };
      cur.amount += Number(t.amount);
      cur.count += 1;
      map.set(name, cur);
    }
    return [...map.values()]
      .map((c) => ({
        ...c,
        name: c.category, // alias kept for the web report
        amount: Math.round(c.amount),
        percentage: total > 0 ? Math.round((c.amount / total) * 100) : 0,
      }))
      .sort((a, b) => b.amount - a.amount);
  }

  /** Bucket income/expenses into a continuous series (daily for short ranges,
   *  monthly otherwise) so the chart is smooth even with sparse data. */
  private buildTrend(from: Date, to: Date, incomes: any[], expenses: any[]) {
    const lenDays = (to.getTime() - from.getTime()) / 86_400_000;
    const daily = lenDays <= 45;
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    const keyLabel = (d: Date) =>
      daily
        ? { key: d.toISOString().slice(0, 10), label: `${d.getUTCDate()}/${d.getUTCMonth() + 1}` }
        : { key: `${d.getUTCFullYear()}-${d.getUTCMonth()}`, label: months[d.getUTCMonth()] };

    const buckets: { label: string; income: number; expenses: number }[] = [];
    const index = new Map<string, number>();
    const cursor = daily
      ? new Date(from)
      : new Date(Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), 1));
    while (cursor < to) {
      const { key, label } = keyLabel(cursor);
      if (!index.has(key)) {
        index.set(key, buckets.length);
        buckets.push({ label, income: 0, expenses: 0 });
      }
      if (daily) cursor.setUTCDate(cursor.getUTCDate() + 1);
      else cursor.setUTCMonth(cursor.getUTCMonth() + 1);
    }
    const add = (t: any, field: 'income' | 'expenses') => {
      const { key } = keyLabel(new Date(t.date));
      const i = index.get(key);
      if (i != null) buckets[i][field] += Number(t.amount);
    };
    incomes.forEach((t) => add(t, 'income'));
    expenses.forEach((t) => add(t, 'expenses'));
    return buckets.map((b) => ({
      label: b.label,
      income: Math.round(b.income),
      expenses: Math.round(b.expenses),
      savings: Math.round(b.income - b.expenses),
    }));
  }

  resolveRange(query: ReportQueryDto): { from: Date; to: Date } {
    const now = new Date();
    if (query.period === ReportPeriod.CUSTOM && query.from && query.to) {
      return { from: new Date(query.from), to: new Date(query.to) };
    }
    switch (query.period) {
      case ReportPeriod.DAILY: {
        const from = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
        const to = new Date(from);
        to.setUTCDate(to.getUTCDate() + 1);
        return { from, to };
      }
      case ReportPeriod.WEEKLY: {
        const day = now.getUTCDay();
        const from = new Date(now);
        from.setUTCDate(now.getUTCDate() - day);
        from.setUTCHours(0, 0, 0, 0);
        const to = new Date(from);
        to.setUTCDate(from.getUTCDate() + 7);
        return { from, to };
      }
      case ReportPeriod.YEARLY: {
        const from = new Date(Date.UTC(now.getUTCFullYear(), 0, 1));
        const to = new Date(Date.UTC(now.getUTCFullYear() + 1, 0, 1));
        return { from, to };
      }
      case ReportPeriod.MONTHLY:
      default: {
        const from = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
        const to = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
        return { from, to };
      }
    }
  }

  async generate(userId: string, query: ReportQueryDto) {
    const { from, to } = this.resolveRange(query);

    const [incomeAgg, expenseAgg, incomeByCat, expenseByCat, incomes, expenses] = await Promise.all(
      [
        this.prisma.income.aggregate({
          where: { userId, deletedAt: null, date: { gte: from, lt: to } },
          _sum: { amount: true },
          _count: true,
        }),
        this.prisma.expense.aggregate({
          where: { userId, deletedAt: null, date: { gte: from, lt: to } },
          _sum: { amount: true },
          _count: true,
        }),
        this.prisma.income.groupBy({
          by: ['categoryId'],
          where: { userId, deletedAt: null, date: { gte: from, lt: to } },
          _sum: { amount: true },
        }),
        this.prisma.expense.groupBy({
          by: ['categoryId'],
          where: { userId, deletedAt: null, date: { gte: from, lt: to } },
          _sum: { amount: true },
        }),
        this.prisma.income.findMany({
          where: { userId, deletedAt: null, date: { gte: from, lt: to } },
          include: { category: true },
          orderBy: { date: 'asc' },
        }),
        this.prisma.expense.findMany({
          where: { userId, deletedAt: null, date: { gte: from, lt: to } },
          include: { category: true },
          orderBy: { date: 'asc' },
        }),
      ],
    );

    const catIds = [
      ...incomeByCat.map((c) => c.categoryId),
      ...expenseByCat.map((c) => c.categoryId),
    ];
    const categories = await this.prisma.category.findMany({
      where: { id: { in: catIds } },
      select: { id: true, name: true, color: true },
    });
    const catMap = new Map(categories.map((c) => [c.id, c]));

    const totalIncome = Number(incomeAgg._sum.amount ?? 0);
    const totalExpenses = Number(expenseAgg._sum.amount ?? 0);

    return {
      period: query.period,
      from,
      to,
      totals: {
        income: totalIncome,
        expenses: totalExpenses,
        net: totalIncome - totalExpenses,
        incomeCount: incomeAgg._count,
        expenseCount: expenseAgg._count,
      },
      incomeByCategory: incomeByCat.map((c) => ({
        category: catMap.get(c.categoryId)?.name ?? 'Unknown',
        color: catMap.get(c.categoryId)?.color,
        amount: Number(c._sum.amount ?? 0),
      })),
      expenseByCategory: expenseByCat.map((c) => ({
        category: catMap.get(c.categoryId)?.name ?? 'Unknown',
        color: catMap.get(c.categoryId)?.color,
        amount: Number(c._sum.amount ?? 0),
      })),
      transactions: {
        income: incomes.map((i) => this.txRow('INCOME', i)),
        expenses: expenses.map((e) => this.txRow('EXPENSE', e)),
      },
    };
  }

  private txRow(type: string, t: any) {
    return {
      type,
      date: t.date,
      title: t.title,
      category: t.category?.name,
      amount: Number(t.amount),
      description: t.description ?? '',
    };
  }

  async toCsv(userId: string, query: ReportQueryDto): Promise<string> {
    const report = await this.generate(userId, query);
    const rows = [...report.transactions.income, ...report.transactions.expenses].sort(
      (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime(),
    );
    const header = ['Type', 'Date', 'Title', 'Category', 'Amount', 'Description'];
    const esc = (v: any) => `"${String(v ?? '').replace(/"/g, '""')}"`;
    const lines = rows.map((r) =>
      [
        r.type,
        new Date(r.date).toISOString().slice(0, 10),
        r.title,
        r.category,
        r.amount,
        r.description,
      ]
        .map(esc)
        .join(','),
    );
    return [header.join(','), ...lines].join('\n');
  }
}
