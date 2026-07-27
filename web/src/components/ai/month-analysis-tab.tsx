'use client';

import Link from 'next/link';
import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts';
import {
  ArrowRight,
  CalendarClock,
  PiggyBank,
  Receipt,
  Target,
  TrendingDown,
  TrendingUp,
  Wallet,
  type LucideIcon,
} from 'lucide-react';
import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { InsightsList } from '@/components/ai/insights-list';
import { useExpenseOverview, useIncomeOverview } from '@/hooks/use-transactions';
import { useAnchor } from '@/store/period';
import { useAuthStore } from '@/store/auth';
import { cn, formatCurrency, formatPercent } from '@/lib/utils';

function StatCard({
  label,
  value,
  trend,
  vsLabel,
  icon: Icon,
  accent,
  currency,
  positiveWhenDown,
}: {
  label: string;
  value: number;
  trend?: number;
  vsLabel: string;
  icon: LucideIcon;
  accent: 'green' | 'red' | 'blue' | 'violet';
  currency: string;
  positiveWhenDown?: boolean;
}) {
  const chip = {
    green: 'bg-emerald-500/15 text-emerald-500',
    red: 'bg-red-500/15 text-red-500',
    blue: 'bg-sky-500/15 text-sky-500',
    violet: 'bg-violet-500/15 text-violet-500',
  }[accent];
  const zero = (trend ?? 0) === 0;
  const rawUp = (trend ?? 0) > 0;
  const good = positiveWhenDown ? !rawUp : rawUp;
  return (
    <Card>
      <CardContent className="p-5">
        <div className="flex items-center gap-3">
          <span className={cn('flex h-11 w-11 items-center justify-center rounded-xl', chip)}>
            <Icon className="h-5 w-5" />
          </span>
          <div className="min-w-0">
            <p className="truncate text-sm text-muted-foreground">{label}</p>
            <p className="truncate text-xl font-bold text-foreground">
              {formatCurrency(value, currency)}
            </p>
          </div>
        </div>
        {trend !== undefined && (
          <p className="mt-2 text-xs">
            {zero ? (
              <span className="text-muted-foreground">— 0%</span>
            ) : (
              <span className={cn('font-semibold', good ? 'text-success' : 'text-destructive')}>
                {formatPercent(trend)}
              </span>
            )}{' '}
            <span className="text-muted-foreground">{vsLabel}</span>
          </p>
        )}
      </CardContent>
    </Card>
  );
}

export function MonthAnalysisTab() {
  const t = useTranslations('ai');
  const tc = useTranslations('common');
  const currency = useAuthStore((s) => s.user?.settings?.currency) || 'XOF';
  const { month, year } = useAnchor();

  const monthStart = `${year}-${String(month).padStart(2, '0')}-01`;
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const monthEnd = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

  const { data: expense } = useExpenseOverview(monthStart, monthEnd);
  const { data: income } = useIncomeOverview(monthStart, monthEnd);

  const now = new Date();
  const isCurrent = now.getUTCFullYear() === year && now.getUTCMonth() + 1 === month;
  const daysLeft = isCurrent ? Math.max(0, lastDay - now.getUTCDate()) : 0;

  const savings = (income?.total ?? 0) - (expense?.total ?? 0);
  const savingsRate = income && income.total > 0 ? Math.round((savings / income.total) * 100) : 0;

  const loading = !expense || !income;

  return (
    <div className="space-y-6">
      {/* Summary cards */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {loading ? (
          Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-28 rounded-xl" />)
        ) : (
          <>
            <StatCard
              label={t('maIncome')}
              value={income!.total}
              trend={income!.totalTrend}
              vsLabel={t('maVsPrev')}
              icon={TrendingUp}
              accent="green"
              currency={currency}
            />
            <StatCard
              label={t('maExpenses')}
              value={expense!.total}
              trend={expense!.totalTrend}
              vsLabel={t('maVsPrev')}
              icon={TrendingDown}
              accent="red"
              currency={currency}
              positiveWhenDown
            />
            <StatCard
              label={t('maNetSavings')}
              value={savings}
              vsLabel={t('maVsPrev')}
              icon={PiggyBank}
              accent="blue"
              currency={currency}
            />
            <Card>
              <CardContent className="p-5">
                <div className="flex items-center gap-3">
                  <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-violet-500/15 text-violet-500">
                    <Target className="h-5 w-5" />
                  </span>
                  <div className="min-w-0">
                    <p className="truncate text-sm text-muted-foreground">{t('maSavingsRate')}</p>
                    <p className="truncate text-xl font-bold text-foreground">{savingsRate}%</p>
                  </div>
                </div>
                <p className="mt-2 text-xs text-muted-foreground">
                  {daysLeft > 0 ? t('maDaysLeft', { n: daysLeft }) : tc('thisMonth')}
                </p>
              </CardContent>
            </Card>
          </>
        )}
      </div>

      {/* Detail tiles + distribution + insights */}
      <div className="grid gap-6 lg:grid-cols-3">
        {/* Analyse détaillée */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>{t('monthAnalysis')}</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <Skeleton className="h-40 rounded-xl" />
            ) : (
              <div className="grid gap-4 sm:grid-cols-2">
                <Tile
                  icon={Receipt}
                  accent="bg-red-500/15 text-red-500"
                  label={t('maTotalExpenses')}
                  value={formatCurrency(expense!.total, currency)}
                  sub={
                    <span className={cn(expense!.totalTrend <= 0 ? 'text-success' : 'text-destructive')}>
                      {expense!.totalTrend === 0 ? '— 0%' : formatPercent(expense!.totalTrend)}
                    </span>
                  }
                />
                <Tile
                  icon={TrendingDown}
                  accent="bg-indigo-500/15 text-indigo-500"
                  label={t('maTopCategory')}
                  value={expense!.topCategory?.name ?? '—'}
                  sub={
                    expense!.topCategory
                      ? t('maOfTotal', { pct: Math.round(expense!.topCategory.percentage) })
                      : undefined
                  }
                />
                <Tile
                  icon={Wallet}
                  accent="bg-emerald-500/15 text-emerald-500"
                  label={t('maBiggestIncome')}
                  value={income!.max ? formatCurrency(income!.max.amount, currency) : '—'}
                  sub={income!.max?.category}
                />
                <Tile
                  icon={CalendarClock}
                  accent="bg-sky-500/15 text-sky-500"
                  label={t('maAvgDay')}
                  value={formatCurrency(expense!.avgPerDay, currency)}
                />
              </div>
            )}

            {/* Répartition des dépenses */}
            {expense && expense.distribution.length > 0 && (
              <div className="mt-5 border-t border-border pt-5">
                <p className="mb-3 text-sm font-semibold text-foreground">{t('distribution')}</p>
                <div className="flex flex-col items-center gap-4 sm:flex-row">
                  <div className="relative h-40 w-40 shrink-0">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={expense.distribution}
                          dataKey="amount"
                          nameKey="name"
                          innerRadius={52}
                          outerRadius={78}
                          paddingAngle={2}
                          strokeWidth={0}
                        >
                          {expense.distribution.map((s) => (
                            <Cell key={s.categoryId} fill={s.color} />
                          ))}
                        </Pie>
                        <Tooltip
                          contentStyle={{
                            borderRadius: 12,
                            border: '1px solid hsl(var(--border))',
                            background: 'hsl(var(--card))',
                            fontSize: 12,
                          }}
                          formatter={(v: number, n: string) => [formatCurrency(v, currency), n]}
                        />
                      </PieChart>
                    </ResponsiveContainer>
                    <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
                      <span className="text-sm font-bold text-foreground">
                        {formatCurrency(expense.total, currency)}
                      </span>
                    </div>
                  </div>
                  <ul className="grid flex-1 gap-2">
                    {expense.distribution.slice(0, 6).map((s) => (
                      <li key={s.categoryId} className="flex items-center justify-between text-sm">
                        <span className="flex items-center gap-2 text-muted-foreground">
                          <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: s.color }} />
                          {s.name}
                        </span>
                        <span className="font-medium text-foreground">
                          {formatCurrency(s.amount, currency)}{' '}
                          <span className="text-xs text-muted-foreground">
                            ({Math.round(s.percentage)}%)
                          </span>
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
                <Link
                  href="/expenses"
                  className="mt-3 flex items-center justify-center gap-1.5 text-sm font-medium text-primary hover:underline"
                >
                  {t('seeAllCategories')} <ArrowRight className="h-4 w-4" />
                </Link>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Insights IA */}
        <InsightsList month={month} year={year} />
      </div>
    </div>
  );
}

function Tile({
  icon: Icon,
  accent,
  label,
  value,
  sub,
}: {
  icon: LucideIcon;
  accent: string;
  label: string;
  value: string;
  sub?: React.ReactNode;
}) {
  return (
    <div className="flex items-start gap-3 rounded-xl border border-border bg-muted/30 p-3">
      <span className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-lg', accent)}>
        <Icon className="h-4 w-4" />
      </span>
      <div className="min-w-0">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="truncate text-sm font-bold text-foreground">{value}</p>
        {sub && <p className="text-[11px] text-muted-foreground">{sub}</p>}
      </div>
    </div>
  );
}
