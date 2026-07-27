'use client';

import { TrendingUp, TrendingDown, PiggyBank, PlusCircle } from 'lucide-react';
import { useLocale, useTranslations } from 'next-intl';
import { useDashboardData } from '@/hooks/use-dashboard';
import { useAuthStore } from '@/store/auth';
import { resolveCompareRange, usePeriodStore } from '@/store/period';
import { anchorMonth, rangeLabel } from '@/lib/period';
import { ComparePicker } from '@/components/dashboard/compare-picker';
import { StatCard } from '@/components/dashboard/stat-card';
import { DistributionDonut } from '@/components/dashboard/distribution-donut';
import { IncomeExpenseChart } from '@/components/dashboard/income-expense-chart';
import { AlertsGoals } from '@/components/dashboard/alerts-goals';
import { CategorySummary } from '@/components/dashboard/category-summary';
import { AiPanel } from '@/components/dashboard/ai-panel';
import { RecentTransactions } from '@/components/dashboard/recent-transactions';
import { BudgetTable } from '@/components/dashboard/budget-table';
import { DailyExpensesChart } from '@/components/dashboard/daily-expenses';
import { Skeleton } from '@/components/ui/skeleton';

export default function DashboardPage() {
  const t = useTranslations('dashboard');
  const locale = useLocale();
  const range = usePeriodStore((s) => s.range);
  const compareMode = usePeriodStore((s) => s.compareMode);
  const compareRange = usePeriodStore((s) => s.compareRange);
  const { data, isLoading } = useDashboardData();
  const currency = useAuthStore((s) => s.user?.settings?.currency) || 'XOF';

  const anchor = anchorMonth(range);
  const periodLabel = rangeLabel(range, locale);
  const cmpSelection = resolveCompareRange({ range, compareMode, compareRange });
  const vsLabel = cmpSelection ? `${t('vs')} ${rangeLabel(cmpSelection, locale)}` : '';
  const showTrend = !!data?.summary.hasComparison && !!cmpSelection;

  if (isLoading || !data) {
    return (
      <div className="space-y-6">
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-28 rounded-xl" />
          ))}
        </div>
        <div className="grid gap-6 xl:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-80 rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  const {
    summary,
    expenseDistribution,
    incomeDistribution,
    incomeVsExpenses,
    budgets,
    recentTransactions,
    dailyExpenses,
  } = data;

  const incomeSeries = incomeVsExpenses.map((p) => p.income);
  const expenseSeries = incomeVsExpenses.map((p) => p.expenses);
  const savingsSeries = incomeVsExpenses.map((p) => p.income - p.expenses);

  return (
    <div className="space-y-6">
      {/* Comparison basis for the KPI trends */}
      <div className="flex justify-end">
        <ComparePicker />
      </div>

      {/* Row 1 — summary cards */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label={t('totalIncome')}
          amount={summary.totalIncome}
          trend={showTrend ? summary.trends.income : undefined}
          trendLabel={vsLabel}
          icon={TrendingUp}
          accent="green"
          currency={currency}
          series={incomeSeries}
        />
        <StatCard
          label={t('totalExpenses')}
          amount={summary.totalExpenses}
          trend={showTrend ? summary.trends.expenses : undefined}
          trendLabel={vsLabel}
          icon={TrendingDown}
          accent="red"
          currency={currency}
          series={expenseSeries}
        />
        <StatCard
          label={t('netSavings')}
          amount={summary.netSavings}
          trend={showTrend ? summary.trends.savings : undefined}
          trendLabel={vsLabel}
          icon={PiggyBank}
          accent="blue"
          currency={currency}
          series={savingsSeries}
        />
        <StatCard
          label={t('netBalance')}
          amount={summary.netSavings}
          trend={showTrend ? summary.trends.savings : undefined}
          trendLabel={vsLabel}
          icon={PlusCircle}
          accent="violet"
          currency={currency}
        />
      </div>

      {/* Row 2 — donut / line chart / alerts */}
      <div className="grid gap-6 lg:grid-cols-2 xl:grid-cols-[1fr_1.3fr_1fr]">
        <DistributionDonut
          title={t('expenseDistribution')}
          data={expenseDistribution}
          currency={currency}
          periodLabel={periodLabel}
        />
        <IncomeExpenseChart data={incomeVsExpenses} currency={currency} />
        <AlertsGoals budgets={budgets} currency={currency} periodLabel={periodLabel} />
      </div>

      {/* Row 3 — recent transactions / category summary / AI */}
      <div id="ai" className="grid gap-6 lg:grid-cols-2 xl:grid-cols-3">
        <RecentTransactions items={recentTransactions} currency={currency} />
        <CategorySummary
          distribution={expenseDistribution}
          budgets={budgets}
          periodLabel={periodLabel}
        />
        <AiPanel month={anchor.month} year={anchor.year} />
      </div>

      {/* Row 4 — budget table / daily expenses / income distribution */}
      <div className="grid gap-6 lg:grid-cols-2 xl:grid-cols-3">
        <BudgetTable budgets={budgets} />
        <DailyExpensesChart data={dailyExpenses} currency={currency} periodLabel={periodLabel} />
        <DistributionDonut
          title={t('incomeDistribution')}
          data={incomeDistribution}
          currency={currency}
          periodLabel={periodLabel}
        />
      </div>
    </div>
  );
}
