import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { dayOfMonthProfile, quantile, selectModel } from './forecasting';

/**
 * Cash-flow forecasting engine.
 *
 * Pipeline (per user, fully data-driven — improves as history grows):
 *  1. Build up to 24 months of income/expense series (grouped SQL).
 *  2. Per series, auto-select the best ETS-family model (SES / Holt / damped
 *     Holt / Holt-Winters / seasonal-naive) by rolling-origin backtesting.
 *  3. Project the horizon using the winning models.
 *  4. Convert monthly projections to a daily cash-flow using learned
 *     day-of-month profiles (salary-day / rent-day spikes), with an empirical
 *     confidence band from backtest residuals.
 *  5. Derive per-category forecasts, alerts, suggestions and objectives.
 */
@Injectable()
export class ForecastService {
  constructor(private readonly prisma: PrismaService) {}

  private DAY = 24 * 60 * 60 * 1000;

  private pct(current: number, previous: number): number {
    if (previous === 0) return current > 0 ? 100 : 0;
    return Math.round(((current - previous) / Math.abs(previous)) * 1000) / 10;
  }

  /** Monthly totals via grouped SQL (2 round-trips regardless of range). */
  private async monthlyTotals(
    table: 'income' | 'expenses',
    userId: string,
    start: Date,
  ): Promise<Map<number, number>> {
    const sql = `
      SELECT EXTRACT(YEAR FROM "date")::int AS y,
             EXTRACT(MONTH FROM "date")::int AS mo,
             COALESCE(SUM("amount"), 0)::float8 AS total
      FROM "${table}"
      WHERE "user_id" = $1 AND "deleted_at" IS NULL AND "date" >= $2
      GROUP BY 1, 2`;
    const rows = await this.prisma.$queryRawUnsafe<{ y: number; mo: number; total: number }[]>(
      sql,
      userId,
      start,
    );
    return new Map(rows.map((r) => [r.y * 12 + (r.mo - 1), r.total]));
  }

  /** Per-category monthly expense totals (single grouped query). */
  private async categoryMonthly(
    userId: string,
    start: Date,
  ): Promise<
    Map<string, { name: string; color: string; byMonth: Map<number, number> }>
  > {
    const sql = `
      SELECT e."category_id" AS cid, c."name" AS name, c."color" AS color,
             EXTRACT(YEAR FROM e."date")::int AS y,
             EXTRACT(MONTH FROM e."date")::int AS mo,
             COALESCE(SUM(e."amount"), 0)::float8 AS total
      FROM "expenses" e JOIN "categories" c ON c."id" = e."category_id"
      WHERE e."user_id" = $1 AND e."deleted_at" IS NULL AND e."date" >= $2
      GROUP BY 1, 2, 3, 4, 5`;
    const rows = await this.prisma.$queryRawUnsafe<
      { cid: string; name: string; color: string | null; y: number; mo: number; total: number }[]
    >(sql, userId, start);
    const map = new Map<string, { name: string; color: string; byMonth: Map<number, number> }>();
    for (const r of rows) {
      const entry =
        map.get(r.cid) ?? { name: r.name, color: r.color ?? '#94a3b8', byMonth: new Map() };
      entry.byMonth.set(r.y * 12 + (r.mo - 1), r.total);
      map.set(r.cid, entry);
    }
    return map;
  }

  private seriesFrom(byMonth: Map<number, number>, endKey: number, length: number): number[] {
    const arr: number[] = [];
    for (let k = endKey - length + 1; k <= endKey; k++) arr.push(byMonth.get(k) ?? 0);
    return arr;
  }

  /** Trim leading zero months (before the user's first activity). */
  private trimLeadingZeros(series: number[]): number[] {
    const first = series.findIndex((v) => v > 0);
    return first <= 0 ? series : series.slice(first);
  }

  async forecast(userId: string, horizonDays = 30) {
    const now = new Date();
    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    const endKey = today.getUTCFullYear() * 12 + today.getUTCMonth();
    const historyMonths = 24;
    const historyStart = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() - historyMonths + 1, 1));

    const profileMonths = 4; // day-of-month profile window
    const profileStart = new Date(
      Date.UTC(today.getUTCFullYear(), today.getUTCMonth() - profileMonths + 1, 1),
    );

    const [incByMonth, expByMonth, catMonthly, recentInc, recentExp, lifeInc, lifeExp] =
      await Promise.all([
        this.monthlyTotals('income', userId, historyStart),
        this.monthlyTotals('expenses', userId, historyStart),
        this.categoryMonthly(userId, historyStart),
        this.prisma.income.findMany({
          where: { userId, deletedAt: null, date: { gte: profileStart } },
          select: { amount: true, date: true },
        }),
        this.prisma.expense.findMany({
          where: { userId, deletedAt: null, date: { gte: profileStart } },
          select: { amount: true, date: true },
        }),
        this.prisma.income.aggregate({ where: { userId, deletedAt: null }, _sum: { amount: true } }),
        this.prisma.expense.aggregate({ where: { userId, deletedAt: null }, _sum: { amount: true } }),
      ]);

    const balanceNow = Number(lifeInc._sum.amount ?? 0) - Number(lifeExp._sum.amount ?? 0);

    // ---- Model selection per series (rolling-origin CV inside selectModel).
    const incSeries = this.trimLeadingZeros(this.seriesFrom(incByMonth, endKey, historyMonths));
    const expSeries = this.trimLeadingZeros(this.seriesFrom(expByMonth, endKey, historyMonths));
    const incModel = selectModel(incSeries, 12);
    const expModel = selectModel(expSeries, 12);

    const horizonMonths = Math.ceil(horizonDays / 30);
    const incMonthly = incModel.forecast(horizonMonths);
    const expMonthly = expModel.forecast(horizonMonths);
    const factor = horizonDays / 30;

    const incNext = incMonthly[0] ?? 0;
    const expNext = expMonthly[0] ?? 0;
    const projectedIncome = Math.round(
      incMonthly.slice(0, Math.floor(factor)).reduce((a, b) => a + b, 0) +
        (factor % 1) * (incMonthly[Math.floor(factor)] ?? incNext),
    );
    const projectedExpenses = Math.round(
      expMonthly.slice(0, Math.floor(factor)).reduce((a, b) => a + b, 0) +
        (factor % 1) * (expMonthly[Math.floor(factor)] ?? expNext),
    );
    const projectedSavings = projectedIncome - projectedExpenses;
    const projectedBalance = Math.round(balanceNow + projectedSavings);

    const curIncome = incSeries[incSeries.length - 1] ?? 0;
    const curExpense = expSeries[expSeries.length - 1] ?? 0;

    // ---- Day-of-month profiles → realistic daily projection.
    const profileWindow = Array.from({ length: profileMonths }, (_, i) => {
      const d = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() - (profileMonths - 1 - i), 1));
      return { month: d.getUTCMonth() + 1, year: d.getUTCFullYear() };
    });
    const incProfile = dayOfMonthProfile(
      recentInc.map((t) => ({ date: t.date, amount: Number(t.amount) })),
      profileWindow,
    );
    const expProfile = dayOfMonthProfile(
      recentExp.map((t) => ({ date: t.date, amount: Number(t.amount) })),
      profileWindow,
    );

    // ---- Empirical residuals for the confidence band (one-step errors of the
    // chosen models, in monthly units → converted to daily scale).
    const monthlyResiduals: number[] = [];
    for (const [series, model] of [
      [incSeries, incModel],
      [expSeries, expModel],
    ] as const) {
      for (let t = Math.max(2, series.length - 7); t < series.length - 1; t++) {
        const sub = selectModel(series.slice(0, t + 1), 12);
        monthlyResiduals.push(Math.abs(sub.forecast(1)[0] - series[t + 1]));
        void model;
      }
    }
    const monthlyErr80 = quantile(monthlyResiduals, 0.8) || Math.max(incNext, expNext) * 0.25;
    const dailyErr = monthlyErr80 / Math.sqrt(30);

    // ---- Cash-flow: 30 days of actual history + horizon projection.
    const actualDays = 30;
    const nets = new Map<string, number>();
    const addNet = (arr: { amount: any; date: Date }[], sign: number) => {
      for (const t of arr) {
        const key = t.date.toISOString().slice(0, 10);
        nets.set(key, (nets.get(key) ?? 0) + sign * Number(t.amount));
      }
    };
    addNet(recentInc, +1);
    addNet(recentExp, -1);

    const cashflow: {
      date: string;
      actual: number | null;
      forecast: number | null;
      lower: number | null;
      upper: number | null;
    }[] = [];

    // Historical segment (running balance ending at balanceNow).
    let histSum = 0;
    for (let i = actualDays - 1; i >= 0; i--) {
      const d = new Date(today.getTime() - i * this.DAY);
      histSum += nets.get(d.toISOString().slice(0, 10)) ?? 0;
    }
    let running = balanceNow - histSum;
    for (let i = actualDays - 1; i >= 0; i--) {
      const d = new Date(today.getTime() - i * this.DAY);
      running += nets.get(d.toISOString().slice(0, 10)) ?? 0;
      const isLast = i === 0;
      cashflow.push({
        date: d.toISOString().slice(0, 10),
        actual: Math.round(running),
        forecast: isLast ? Math.round(running) : null,
        lower: isLast ? Math.round(running) : null,
        upper: isLast ? Math.round(running) : null,
      });
    }

    // Forecast segment using the day-of-month profiles.
    let fRunning = balanceNow;
    for (let d = 1; d <= horizonDays; d++) {
      const date = new Date(today.getTime() + d * this.DAY);
      const dom = date.getUTCDate() - 1; // 0-based day of month
      const monthIdx = Math.min(
        horizonMonths - 1,
        (date.getUTCFullYear() * 12 + date.getUTCMonth()) - (endKey),
      );
      const mInc = incMonthly[Math.max(0, monthIdx)] ?? incNext;
      const mExp = expMonthly[Math.max(0, monthIdx)] ?? expNext;
      fRunning += mInc * incProfile[dom] - mExp * expProfile[dom];
      const band = dailyErr * Math.sqrt(d);
      cashflow.push({
        date: date.toISOString().slice(0, 10),
        actual: null,
        forecast: Math.round(fRunning),
        lower: Math.round(fRunning - band),
        upper: Math.round(fRunning + band),
      });
    }

    // ---- Per-category forecasts with per-series model selection.
    const rawCats = [...catMonthly.entries()].map(([categoryId, c]) => {
      const series = this.trimLeadingZeros(this.seriesFrom(c.byMonth, endKey, historyMonths));
      const model = selectModel(series, 12);
      const projected = Math.round(model.forecast(1)[0] * factor);
      const currentMonth = series[series.length - 1] ?? 0;
      return {
        categoryId,
        name: c.name,
        color: c.color,
        projected,
        evolution: this.pct(model.forecast(1)[0], currentMonth),
      };
    });
    const catTotal = rawCats.reduce((s, c) => s + c.projected, 0);
    const byCategory = rawCats
      .map((c) => ({
        ...c,
        percentage: catTotal > 0 ? Math.round((c.projected / catTotal) * 100) : 0,
      }))
      .sort((a, b) => b.projected - a.projected);

    // ---- Alerts.
    const alerts: { type: 'warning' | 'good'; title: string; detail: string }[] = [];
    const negativePoint = cashflow.find((p) => p.forecast !== null && p.forecast < 0);
    if (negativePoint) {
      alerts.push({
        type: 'warning',
        title: `Vos dépenses pourraient dépasser vos revenus le ${negativePoint.date}.`,
        detail: `Solde prévisionnel négatif estimé : ${negativePoint.forecast} XOF.`,
      });
    }
    const monthlySavings = incNext - expNext;
    if (monthlySavings > 0) {
      alerts.push({
        type: 'good',
        title: 'Votre épargne devrait continuer à progresser.',
        detail: `Épargne mensuelle projetée : +${Math.round(monthlySavings)} XOF.`,
      });
    } else {
      alerts.push({
        type: 'warning',
        title: 'Votre épargne pourrait stagner ce mois-ci.',
        detail: 'Vos dépenses projetées approchent de vos revenus.',
      });
    }

    // ---- Suggestions.
    const suggestions: { text: string; cta: string }[] = [];
    const rising = byCategory
      .filter((c) => c.evolution > 0)
      .sort((a, b) => b.evolution - a.evolution)[0];
    if (rising) {
      suggestions.push({
        text: `Vos dépenses en ${rising.name} devraient augmenter de ${Math.round(rising.evolution)}% le mois prochain.`,
        cta: 'Fixez un budget pour cette catégorie.',
      });
    }
    const biggest = byCategory[0];
    if (biggest) {
      const save = Math.round(biggest.projected * 0.15);
      suggestions.push({
        text: `Vous pourriez économiser ${save} XOF en réduisant vos dépenses de ${biggest.name}.`,
        cta: 'Voir suggestions',
      });
    }
    suggestions.push({
      text:
        monthlySavings > 0
          ? 'Tendance positive : votre épargne augmente régulièrement.'
          : 'Surveillez vos dépenses variables pour préserver votre épargne.',
      cta: 'Continuez ainsi !',
    });

    // ---- Objectives.
    const avgMonthlyExpense = expNext || curExpense || 1;
    const emergencyTarget = Math.round(avgMonthlyExpense * 3);
    const nextMillion = Math.max(
      Math.ceil((balanceNow + 1) / 500000) * 500000,
      balanceNow + 500000,
    );
    const etaMonths = (target: number) =>
      monthlySavings > 0 && target > balanceNow
        ? Math.ceil((target - balanceNow) / monthlySavings)
        : null;
    const etaDate = (months: number | null) => {
      if (months === null) return null;
      const d = new Date(today);
      d.setUTCMonth(d.getUTCMonth() + months);
      return d.toISOString().slice(0, 10);
    };
    const objectives = [
      {
        name: 'Prochain palier d’épargne',
        current: Math.round(balanceNow),
        target: nextMillion,
        percentage: Math.min(100, Math.round((balanceNow / nextMillion) * 100)),
        etaDate: etaDate(etaMonths(nextMillion)),
      },
      {
        name: 'Fonds d’urgence',
        current: Math.round(Math.min(balanceNow, emergencyTarget)),
        target: emergencyTarget,
        percentage: Math.min(100, Math.round((balanceNow / emergencyTarget) * 100)),
        etaDate: etaDate(etaMonths(emergencyTarget)),
      },
    ];

    const horizonEnd = new Date(today.getTime() + horizonDays * this.DAY)
      .toISOString()
      .slice(0, 10);

    return {
      horizonDays,
      generatedAt: now.toISOString(),
      models: {
        income: {
          name: incModel.name,
          label: incModel.label,
          mae: Number.isFinite(incModel.mae) ? Math.round(incModel.mae) : null,
        },
        expenses: {
          name: expModel.name,
          label: expModel.label,
          mae: Number.isFinite(expModel.mae) ? Math.round(expModel.mae) : null,
        },
      },
      overview: {
        projectedIncome,
        incomeTrend: this.pct(incNext, curIncome),
        projectedExpenses,
        expenseTrend: this.pct(expNext, curExpense),
        projectedSavings,
        savingsTrend: this.pct(incNext - expNext, curIncome - curExpense),
        projectedBalance,
        balanceDate: horizonEnd,
      },
      cashflow,
      byCategory,
      totalProjected: catTotal,
      alerts,
      suggestions,
      objectives,
    };
  }
}
