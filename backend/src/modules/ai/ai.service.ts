import { Injectable, Logger } from '@nestjs/common';
import { AiInsightType, AiProvider, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { BudgetEngineService } from '../budgets/budget-engine.service';
import { DashboardService } from '../dashboard/dashboard.service';
import { LlmService } from './llm.service';
import { resolveModel } from './ai-models';

export interface GeneratedInsight {
  type: string;
  title: string;
  content: string;
  severity?: 'info' | 'warning' | 'critical';
}

type InsightScope = 'GLOBAL' | 'BUDGET' | 'EXPENSE' | 'INCOME';

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);

  // Short-lived cache + in-flight dedupe so repeated widget mounts and multiple
  // scopes don't each fire a fresh (slow, sometimes failing) LLM call.
  private readonly insightCache = new Map<string, { at: number; insights: GeneratedInsight[] }>();
  private readonly insightInflight = new Map<string, Promise<GeneratedInsight[]>>();
  private readonly INSIGHT_TTL_MS = 20 * 60 * 1000; // 20 minutes
  private readonly INSIGHT_TIMEOUT_MS = 35_000; // cap latency well under the app's 120s

  constructor(
    private readonly prisma: PrismaService,
    private readonly dashboard: DashboardService,
    private readonly budgetEngine: BudgetEngineService,
    private readonly llm: LlmService,
  ) {}

  private systemPrompt(language: 'FR' | 'EN'): string {
    const langInstruction =
      language === 'FR'
        ? 'LANGUAGE (strict): Write your ENTIRE reply in French, ALWAYS — regardless of the language of the input.'
        : 'LANGUAGE (strict): Write your ENTIRE reply in English, ALWAYS — regardless of the language of the input.';
    return [
      'You are Fynexa AI, a friendly and concise personal finance coach.',
      'You analyse the user financial data and give practical, actionable advice.',
      'Amounts are in the user currency. Be specific, encouraging and realistic.',
      'Never invent numbers that are not supported by the provided data.',
      'Keep answers short (2-5 sentences) unless asked for detail.',
      langInstruction,
    ].join(' ');
  }

  private async buildContext(userId: string, month: number, year: number) {
    const settings = await this.prisma.userSettings.findUnique({ where: { userId } });
    const currency = settings?.currency ?? 'XOF';
    const language = settings?.language ?? 'FR';
    const aiProvider = settings?.aiProvider ?? 'GEMINI';
    const model = resolveModel(
      aiProvider as AiProvider,
      aiProvider === 'GEMINI' ? settings?.geminiModel : settings?.agentRouterModel,
    );
    const [summary, distribution, last6Months, budgetStatuses] = await Promise.all([
      this.dashboard.getSummary(userId, month, year),
      this.dashboard.getExpenseDistribution(userId, month, year),
      this.dashboard.getIncomeVsExpenses(userId, 6, month, year),
      this.budgetEngine.getStatuses(userId, month, year),
    ]);

    return {
      currency,
      language,
      aiProvider,
      model,
      period: `${year}-${String(month).padStart(2, '0')}`,
      summary,
      topExpenseCategories: distribution.slice(0, 6),
      last6Months,
      budgets: budgetStatuses.map((b) => ({
        category: b.categoryName,
        budget: b.budget,
        spent: b.spent,
        progress: b.progress,
        status: b.status,
      })),
    };
  }

  private contextToText(ctx: any): string {
    return `Currency: ${ctx.currency}
Period: ${ctx.period}
Total income: ${ctx.summary.totalIncome}
Total expenses: ${ctx.summary.totalExpenses}
Net savings: ${ctx.summary.netSavings}
Savings rate: ${ctx.summary.savingsRate}%
Financial score: ${ctx.summary.financialScore}/100
Top expense categories: ${ctx.topExpenseCategories
      .map((c: any) => `${c.name}=${c.amount} (${c.percentage}%)`)
      .join(', ')}
Budgets: ${
      ctx.budgets.length
        ? ctx.budgets
            .map((b: any) => `${b.category}: spent ${b.spent}/${b.budget} (${b.progress}%, ${b.status})`)
            .join('; ')
        : 'none set'
    }`;
  }

  async ask(userId: string, question: string, month: number, year: number) {
    const ctx = await this.buildContext(userId, month, year);
    const prompt = `Here is my financial data:\n${this.contextToText(ctx)}\n\nQuestion: ${question}`;
    const { provider } = this.llm.provider(ctx.aiProvider);
    const answer = await provider.generate(prompt, this.systemPrompt(ctx.language), [], {
      model: ctx.model,
    });
    return { question, answer, configured: this.llm.anyConfigured };
  }

  /**
   * Does this scope have anything worth analysing for the selected month?
   *
   * Without this the model is handed a context of all-zeros and dutifully
   * invents advice about spending that never happened. Checking the same data
   * the user sees on screen keeps the empty state honest.
   */
  private async hasDataFor(
    userId: string,
    month: number,
    year: number,
    scope: InsightScope,
  ): Promise<boolean> {
    const start = new Date(Date.UTC(year, month - 1, 1));
    const end = new Date(Date.UTC(year, month, 1));
    const period = { gte: start, lt: end };

    if (scope === 'BUDGET') {
      const budgets = await this.prisma.monthlyBudget.count({ where: { userId, month, year } });
      return budgets > 0;
    }
    if (scope === 'INCOME') {
      const incomes = await this.prisma.income.count({
        where: { userId, deletedAt: null, date: period },
      });
      return incomes > 0;
    }
    if (scope === 'EXPENSE') {
      const expenses = await this.prisma.expense.count({
        where: { userId, deletedAt: null, date: period },
      });
      return expenses > 0;
    }
    // GLOBAL — any movement at all.
    const [expenses, incomes] = await Promise.all([
      this.prisma.expense.count({ where: { userId, deletedAt: null, date: period } }),
      this.prisma.income.count({ where: { userId, deletedAt: null, date: period } }),
    ]);
    return expenses + incomes > 0;
  }

  /** Call-to-action shown instead of invented analysis when there is no data. */
  private noDataInsights(scope: InsightScope, language: string): GeneratedInsight[] {
    const fr = language !== 'EN';
    const copy: Record<InsightScope, { title: string; content: string }> = {
      EXPENSE: {
        title: fr ? 'Aucune dépense ce mois-ci' : 'No expenses this month',
        content: fr
          ? 'Ajoutez vos dépenses pour obtenir une analyse IA personnalisée.'
          : 'Add your expenses to unlock personalised AI insights.',
      },
      INCOME: {
        title: fr ? 'Aucun revenu ce mois-ci' : 'No income this month',
        content: fr
          ? 'Ajoutez vos revenus pour obtenir une analyse IA personnalisée.'
          : 'Add your income to unlock personalised AI insights.',
      },
      BUDGET: {
        title: fr ? 'Aucun budget défini' : 'No budget set',
        content: fr
          ? 'Définissez un budget par catégorie pour recevoir des conseils IA.'
          : 'Set a budget per category to receive AI recommendations.',
      },
      GLOBAL: {
        title: fr ? 'Pas encore de données' : 'No data yet',
        content: fr
          ? 'Ajoutez des revenus ou des dépenses pour débloquer votre analyse IA.'
          : 'Add income or expenses to unlock your AI analysis.',
      },
    };
    const { title, content } = copy[scope] ?? copy.GLOBAL;
    return [{ type: 'ADVICE', title, content, severity: 'info' }];
  }

  async generateInsights(
    userId: string,
    month: number,
    year: number,
    scope: InsightScope = 'GLOBAL',
  ) {
    // No data → never call the model, never persist. The client renders a CTA.
    if (!(await this.hasDataFor(userId, month, year, scope))) {
      const settings = await this.prisma.userSettings.findUnique({ where: { userId } });
      return {
        insights: this.noDataInsights(scope, settings?.language ?? 'FR'),
        configured: this.llm.anyConfigured,
        empty: true,
      };
    }

    const key = `${userId}:${year}-${month}:${scope}`;

    // 1. Fresh cache hit → instant.
    const cached = this.insightCache.get(key);
    if (cached && Date.now() - cached.at < this.INSIGHT_TTL_MS) {
      return { insights: cached.insights, configured: this.llm.anyConfigured, cached: true };
    }

    // 2. Dedupe concurrent requests for the same key (multiple widget mounts).
    const inflight = this.insightInflight.get(key);
    if (inflight) {
      return { insights: await inflight, configured: this.llm.anyConfigured };
    }

    const promise = this.buildInsights(userId, month, year, scope);
    this.insightInflight.set(key, promise);
    try {
      const insights = await promise;
      this.insightCache.set(key, { at: Date.now(), insights });
      return { insights, configured: this.llm.anyConfigured };
    } finally {
      this.insightInflight.delete(key);
    }
  }

  /**
   * Produce insights for a scope. This NEVER throws — on any failure (context
   * build, malformed LLM output, timeout, provider down) it degrades to
   * deterministic heuristic insights so the endpoint always responds quickly.
   */
  private async buildInsights(
    userId: string,
    month: number,
    year: number,
    scope: InsightScope,
  ): Promise<GeneratedInsight[]> {
    let ctx: any;
    try {
      ctx = await this.buildContext(userId, month, year);
    } catch (e) {
      this.logger.error(`Insights context build failed: ${(e as Error).message}`);
      return this.emptyStateInsights(scope);
    }

    // No AI configured → heuristics straight away.
    if (!this.llm.anyConfigured) {
      const h = this.heuristicInsights(ctx, scope);
      this.persistSafe(userId, h, month, year);
      return h;
    }

    let insights: GeneratedInsight[] = [];
    try {
      const prompt = this.buildScopedPrompt(ctx, scope);
      const { provider } = this.llm.provider(ctx.aiProvider);
      const parsed = await this.withTimeout(
        provider.generateJson<GeneratedInsight[]>(prompt, this.systemPrompt(ctx.language), ctx.model),
        this.INSIGHT_TIMEOUT_MS,
      );
      insights = this.sanitizeInsights(parsed);
    } catch (e) {
      this.logger.warn(`Insights LLM failed (${scope}): ${(e as Error).message}`);
    }

    // Fall back to heuristics if the model produced nothing usable.
    if (insights.length === 0) insights = this.heuristicInsights(ctx, scope);

    insights = insights.slice(0, 5);
    this.persistSafe(userId, insights, month, year);
    return insights;
  }

  private buildScopedPrompt(ctx: any, scope: InsightScope): string {
    let scopeInstruction: string;
    let dataContext: string;
    switch (scope) {
      case 'BUDGET':
        scopeInstruction =
          'CRITICAL SCOPE RULE: Focus STRICTLY and ONLY on BUDGET OBJECTIVES and spending caps. Evaluate category budgets, overruns, remaining balances, and budget optimization. Do NOT comment on general income or overall savings.';
        dataContext = `Budgets: ${
          ctx.budgets.length
            ? ctx.budgets
                .map(
                  (b: any) =>
                    `${b.category}: spent ${b.spent}/${b.budget} (${b.progress}%, status: ${b.status})`,
                )
                .join('; ')
            : 'none set'
        }\nTotal Expenses: ${ctx.summary.totalExpenses} ${ctx.currency}`;
        break;
      case 'EXPENSE':
        scopeInstruction =
          'CRITICAL SCOPE RULE: Focus STRICTLY and ONLY on EXPENSES and spending habits. Evaluate top expense categories, cost reduction opportunities, and spending patterns. Do NOT discuss income or overall budget caps.';
        dataContext = `Total Expenses: ${ctx.summary.totalExpenses} ${ctx.currency}\nTop Expense Categories: ${ctx.topExpenseCategories
          .map((c: any) => `${c.name}=${c.amount} (${c.percentage}%)`)
          .join(', ')}`;
        break;
      case 'INCOME':
        scopeInstruction =
          'CRITICAL SCOPE RULE: Focus STRICTLY and ONLY on REVENUE and INCOME streams. Evaluate income totals, trends, regularity, and income growth. Do NOT discuss expense items or budget overruns.';
        dataContext = `Total Income: ${ctx.summary.totalIncome} ${ctx.currency}\nSavings Rate: ${ctx.summary.savingsRate}%\nLast 6 Months Trend: ${JSON.stringify(
          ctx.last6Months.map((m: any) => ({ month: m.label, income: m.income })),
        )}`;
        break;
      case 'GLOBAL':
      default:
        scopeInstruction =
          'Focus on a global financial overview including income, expenses, net savings, budget status, and overall financial health.';
        dataContext = this.contextToText(ctx);
        break;
    }
    const lang = ctx.language === 'FR' ? 'French (français)' : 'English';
    return `Analyse the following financial data for the specified scope.
${scopeInstruction}

Return ONLY a JSON array with 3 to 5 concise items. Each item: {"type": one of ["SPENDING_ANALYSIS","ADVICE","UNUSUAL_SPENDING","BUDGET_SUGGESTION","SAVING_RECOMMENDATION","PREDICTION","ALERT"], "title": string, "content": string, "severity": one of ["info","warning","critical"]}.
IMPORTANT: write every "title" and "content" value in ${lang}.

Data:
${dataContext}`;
  }

  /** Reject if the promise doesn't settle within `ms` (frees the caller fast). */
  private withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
    return Promise.race([
      p,
      new Promise<T>((_, reject) => setTimeout(() => reject(new Error('insight timeout')), ms)),
    ]);
  }

  /** Coerce an arbitrary LLM response into safe, well-formed insight objects. */
  private sanitizeInsights(parsed: any): GeneratedInsight[] {
    if (!Array.isArray(parsed)) return [];
    const validTypes = Object.values(AiInsightType) as string[];
    const out: GeneratedInsight[] = [];
    for (const it of parsed) {
      if (!it || typeof it !== 'object') continue;
      const title = typeof it.title === 'string' ? it.title.trim() : '';
      const content = typeof it.content === 'string' ? it.content.trim() : '';
      if (!title && !content) continue;
      out.push({
        type: typeof it.type === 'string' && validTypes.includes(it.type) ? it.type : 'ADVICE',
        title: (title || content).slice(0, 200),
        content: content || title,
        severity: ['info', 'warning', 'critical'].includes(it.severity) ? it.severity : 'info',
      });
    }
    return out;
  }

  /** Persist without ever blocking or failing the response. */
  private persistSafe(userId: string, insights: GeneratedInsight[], month: number, year: number) {
    this.persistInsights(userId, insights, month, year).catch((e) =>
      this.logger.warn(`persistInsights failed: ${(e as Error).message}`),
    );
  }

  /** Neutral placeholder when even the data context can't be built. */
  private emptyStateInsights(scope: InsightScope): GeneratedInsight[] {
    return [
      {
        type: 'ADVICE',
        title: 'Analyse indisponible',
        content:
          scope === 'INCOME'
            ? 'Ajoutez vos revenus pour obtenir une analyse personnalisée.'
            : scope === 'BUDGET'
              ? 'Définissez des budgets pour suivre vos objectifs.'
              : 'Ajoutez quelques transactions pour débloquer votre analyse IA.',
        severity: 'info',
      },
    ];
  }

  async monthlySummary(userId: string, month: number, year: number) {
    const ctx = await this.buildContext(userId, month, year);
    const prompt = `Write a short, friendly monthly financial summary (3-4 sentences) highlighting savings, biggest spending area and one suggestion.\n\nData:\n${this.contextToText(ctx)}`;
    const { provider } = this.llm.provider(ctx.aiProvider);
    const summary = await provider.generate(prompt, this.systemPrompt(ctx.language), [], {
      model: ctx.model,
    });
    return { summary, period: ctx.period };
  }

  async listInsights(userId: string, take = 20) {
    return this.prisma.aiInsight.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take,
    });
  }

  async markInsightRead(userId: string, id: string) {
    await this.prisma.aiInsight.updateMany({ where: { id, userId }, data: { isRead: true } });
    return { message: 'Marked read' };
  }

  // ------------------------------------------------------------- Heuristics
  private heuristicInsights(
    ctx: any,
    scope: 'GLOBAL' | 'BUDGET' | 'EXPENSE' | 'INCOME' = 'GLOBAL',
  ): GeneratedInsight[] {
    const out: GeneratedInsight[] = [];
    const s = ctx.summary;

    if (scope === 'BUDGET') {
      const budgets = ctx.budgets ?? [];
      if (budgets.length === 0) {
        out.push({
          type: 'BUDGET_SUGGESTION',
          title: 'Aucun budget défini',
          content:
            'Définissez des plafonds par catégorie pour suivre vos objectifs et recevoir des alertes.',
          severity: 'info',
        });
        return out;
      }
      const exceeded = budgets.filter((b: any) => b.status === 'exceeded');
      const near = budgets.filter((b: any) => b.status !== 'exceeded' && Number(b.progress) >= 80);
      if (exceeded.length) {
        out.push({
          type: 'ALERT',
          title: 'Objectifs budgétaires dépassés',
          content: `Vous avez dépassé votre budget pour : ${exceeded.map((b: any) => b.category).join(', ')}. Réévaluez ces plafonds.`,
          severity: 'warning',
        });
      } else {
        out.push({
          type: 'BUDGET_SUGGESTION',
          title: 'Budgets sous contrôle',
          content: `Vos ${budgets.length} budget(s) par catégorie sont respectés pour cette période. 👍`,
          severity: 'info',
        });
      }
      if (near.length) {
        out.push({
          type: 'BUDGET_SUGGESTION',
          title: 'Budgets à surveiller',
          content: `Proche de la limite : ${near
            .map((b: any) => `${b.category} (${b.progress}%)`)
            .join(', ')}.`,
          severity: 'warning',
        });
      }
      out.push({
        type: 'ADVICE',
        title: 'Optimisation',
        content: `Total dépensé ce mois : ${s.totalExpenses} ${ctx.currency}. Réaffectez le budget non utilisé d'une catégorie vers votre épargne.`,
        severity: 'info',
      });
      return out;
    }

    const cur = ctx.currency;

    if (scope === 'EXPENSE') {
      const cats = ctx.topExpenseCategories ?? [];
      const top = cats[0];
      if (top) {
        out.push({
          type: 'SPENDING_ANALYSIS',
          title: `Poste principal : ${top.name}`,
          content: `${top.name} représente ${top.percentage}% de vos dépenses (${top.amount} ${cur}).`,
          severity: top.percentage >= 40 ? 'warning' : 'info',
        });
      }
      if (cats.length >= 2) {
        out.push({
          type: 'SPENDING_ANALYSIS',
          title: 'Répartition des dépenses',
          content: `Vos plus gros postes : ${cats
            .slice(0, 3)
            .map((c: any) => `${c.name} (${c.percentage}%)`)
            .join(', ')}.`,
          severity: 'info',
        });
      }
      out.push({
        type: 'ADVICE',
        title: 'Dépenses totales',
        content: `Vous avez dépensé ${s.totalExpenses} ${cur} ce mois-ci. Repérez une catégorie non essentielle à réduire de 10%.`,
        severity: 'info',
      });
      return out;
    }

    if (scope === 'INCOME') {
      out.push({
        type: 'ADVICE',
        title: 'Revenus du mois',
        content: `Vos revenus s'élèvent à ${s.totalIncome} ${cur}, pour un taux d'épargne de ${s.savingsRate}%.`,
        severity: 'info',
      });
      out.push(
        s.savingsRate >= 20
          ? {
              type: 'SAVING_RECOMMENDATION',
              title: "Bon taux d'épargne",
              content: `Avec ${s.savingsRate}% d'épargne, vous êtes sur une excellente trajectoire — pensez à placer ce surplus.`,
              severity: 'info',
            }
          : {
              type: 'SAVING_RECOMMENDATION',
              title: "Marge d'épargne",
              content: `Votre taux d'épargne est de ${s.savingsRate}%. Visez 20% en automatisant un virement en début de mois.`,
              severity: s.savingsRate < 0 ? 'critical' : 'warning',
            },
      );
      const months = ctx.last6Months ?? [];
      if (months.length >= 2) {
        const prev = Number(months[months.length - 2]?.income ?? 0);
        const now = Number(months[months.length - 1]?.income ?? 0);
        if (prev > 0) {
          const chg = Math.round(((now - prev) / prev) * 100);
          out.push({
            type: 'PREDICTION',
            title: 'Tendance des revenus',
            content:
              chg >= 0
                ? `Vos revenus ont progressé de ${chg}% par rapport au mois précédent.`
                : `Vos revenus ont baissé de ${Math.abs(chg)}% par rapport au mois précédent.`,
            severity: chg < 0 ? 'warning' : 'info',
          });
        }
      }
      return out;
    }

    // Default GLOBAL
    if (s.savingsRate >= 20) {
      out.push({
        type: 'ADVICE',
        title: "Bonne discipline d'épargne",
        content: `Vous avez épargné ${s.savingsRate}% de vos revenus ce mois-ci. Continuez ainsi pour atteindre vos objectifs plus vite.`,
        severity: 'info',
      });
    } else if (s.savingsRate < 0) {
      out.push({
        type: 'ALERT',
        title: 'Dépenses supérieures aux revenus',
        content: `Vos dépenses ont dépassé vos revenus cette période. Passez en revue vos principaux postes de dépense.`,
        severity: 'critical',
      });
    } else {
      out.push({
        type: 'SAVING_RECOMMENDATION',
        title: "Potentiel d'épargne",
        content: `Votre taux d'épargne est de ${s.savingsRate}%. Essayez d'atteindre au moins 20% en réduisant le superflu.`,
        severity: 'warning',
      });
    }

    const gTop = ctx.topExpenseCategories?.[0];
    if (gTop) {
      out.push({
        type: 'SPENDING_ANALYSIS',
        title: `Poste principal : ${gTop.name}`,
        content: `${gTop.name} représente ${gTop.percentage}% de vos dépenses (${gTop.amount} ${cur}).`,
        severity: 'info',
      });
    }

    const gExceeded = ctx.budgets?.filter((b: any) => b.status === 'exceeded') ?? [];
    if (gExceeded.length) {
      out.push({
        type: 'BUDGET_SUGGESTION',
        title: 'Budgets dépassés',
        content: `Vous avez dépassé votre budget pour : ${gExceeded.map((b: any) => b.category).join(', ')}.`,
        severity: 'warning',
      });
    }
    return out;
  }

  private async persistInsights(
    userId: string,
    insights: GeneratedInsight[],
    month: number,
    year: number,
  ) {
    const periodStart = new Date(Date.UTC(year, month - 1, 1));
    const periodEnd = new Date(Date.UTC(year, month, 0));
    const validTypes = Object.values(AiInsightType) as string[];

    await this.prisma.aiInsight.createMany({
      data: insights.map((i) => ({
        userId,
        type: (validTypes.includes(i.type) ? i.type : 'ADVICE') as AiInsightType,
        title: String(i.title ?? '').slice(0, 200) || 'Conseil',
        content: String(i.content ?? i.title ?? ''),
        severity: i.severity ?? 'info',
        periodStart,
        periodEnd,
        metadata: {} as Prisma.InputJsonValue,
      })),
    });
  }
}
