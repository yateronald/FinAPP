'use client';

import { useState } from 'react';
import Link from 'next/link';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import {
  Download,
  FileBarChart,
  Info,
  Loader2,
  Percent,
  PiggyBank,
  TrendingDown,
  TrendingUp,
  type LucideIcon,
} from 'lucide-react';
import { useLocale, useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { PageHeader } from '@/components/page-header';
import { EmptyState } from '@/components/empty-state';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { categoryIcon } from '@/lib/category-icons';
import {
  downloadReportCsv,
  useReportOverview,
  type ReportParams,
  type ReportPeriod,
} from '@/hooks/use-reports';
import { useAuthStore } from '@/store/auth';
import {
  cn,
  formatCurrency,
  formatNumber,
  formatPercent,
  monthShort,
  monthYearLabel,
} from '@/lib/utils';

const PERIODS: ReportPeriod[] = ['daily', 'weekly', 'monthly', 'yearly', 'custom'];

function Sparkline({ points, color }: { points: number[]; color: string }) {
  if (points.length < 2) return null;
  const min = Math.min(...points);
  const max = Math.max(...points);
  const range = max - min || 1;
  const w = 88;
  const h = 30;
  const step = w / (points.length - 1);
  const path = points
    .map(
      (p, i) =>
        `${i === 0 ? 'M' : 'L'}${(i * step).toFixed(1)},${(h - 3 - ((p - min) / range) * (h - 6)).toFixed(1)}`,
    )
    .join(' ');
  return (
    <svg width={w} height={h} className="overflow-visible">
      <path d={path} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

function StatCard({
  label,
  value,
  isRate,
  trend,
  icon: Icon,
  accent,
  color,
  series,
  currency,
  positiveWhenDown,
  vsLabel,
}: {
  label: string;
  value: number;
  isRate?: boolean;
  trend: number;
  icon: LucideIcon;
  accent: string;
  color: string;
  series: number[];
  currency: string;
  positiveWhenDown?: boolean;
  vsLabel: string;
}) {
  const zero = trend === 0;
  const up = trend > 0;
  const good = positiveWhenDown ? !up : up;
  return (
    <Card>
      <CardContent className="p-5">
        <div className="flex items-start gap-3">
          <span className={cn('flex h-10 w-10 items-center justify-center rounded-xl', accent)}>
            <Icon className="h-5 w-5" />
          </span>
          <p className="pt-1.5 text-sm text-muted-foreground">{label}</p>
        </div>
        <div className="mt-3 flex items-end justify-between gap-2">
          <div className="min-w-0">
            <p className="truncate text-xl font-bold text-foreground">
              {isRate ? `${value}%` : formatCurrency(value, currency)}
            </p>
            <p className="mt-1 flex items-center gap-1 text-xs">
              {zero ? (
                <span className="text-muted-foreground">— 0%</span>
              ) : (
                <span className={cn('font-semibold', good ? 'text-success' : 'text-destructive')}>
                  {good ? '▲' : '▼'} {formatPercent(trend).replace('+', '')}
                </span>
              )}
              <span className="text-muted-foreground">{vsLabel}</span>
            </p>
          </div>
          <Sparkline points={series} color={color} />
        </div>
      </CardContent>
    </Card>
  );
}

export default function ReportsPage() {
  const t = useTranslations('reports');
  const tb = useTranslations('budget');
  const locale = useLocale();
  const currency = useAuthStore((s) => s.user?.settings?.currency) || 'XOF';

  const [params, setParams] = useState<ReportParams>({ period: 'monthly' });
  const [exporting, setExporting] = useState(false);
  const { data, isLoading } = useReportOverview(params);

  const doExport = async () => {
    setExporting(true);
    try {
      await downloadReportCsv(params);
    } catch (e: any) {
      toast.error(e?.message || 'Export failed');
    } finally {
      setExporting(false);
    }
  };

  const fmtMoney = (v: number) => formatCurrency(v, currency);
  // Localized month labels for the bar chart (backend labels are English short).
  const barData = (data?.monthlyEvolution ?? []).map((m) => ({
    label: monthShort(m.month, locale),
    income: m.income,
    expenses: m.expenses,
  }));
  const budgetStatus = (s: string) => {
    if (s === 'exceeded')
      return { badge: 'destructive' as const, bar: 'bg-destructive', label: t('statusExceeded') };
    if (s === 'warning' || s === 'danger')
      return { badge: 'warning' as const, bar: 'bg-amber-500', label: t('statusWarning') };
    return { badge: 'success' as const, bar: 'bg-emerald-500', label: t('statusOnTrack') };
  };

  return (
    <div className="space-y-6">
      <PageHeader title={t('title')} description={t('subtitle2')}>
        <Button variant="outline" onClick={doExport} disabled={exporting || !data}>
          {exporting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
          {t('export')}
        </Button>
      </PageHeader>

      {/* Period tabs + custom range */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-1 rounded-lg bg-muted p-1">
          {PERIODS.map((p) => (
            <button
              key={p}
              onClick={() => setParams((prev) => ({ ...prev, period: p }))}
              className={cn(
                'rounded-md px-3 py-1.5 text-sm font-medium transition-colors',
                params.period === p
                  ? 'bg-primary text-primary-foreground shadow-sm'
                  : 'text-muted-foreground hover:text-foreground',
              )}
            >
              {t(p)}
            </button>
          ))}
        </div>
        {params.period === 'custom' && (
          <div className="flex items-center gap-2">
            <Input
              type="date"
              value={params.from ?? ''}
              onChange={(e) => setParams((prev) => ({ ...prev, from: e.target.value }))}
              className="w-[150px]"
            />
            <span className="text-muted-foreground">→</span>
            <Input
              type="date"
              value={params.to ?? ''}
              onChange={(e) => setParams((prev) => ({ ...prev, to: e.target.value }))}
              className="w-[150px]"
            />
          </div>
        )}
      </div>

      {isLoading || !data ? (
        <div className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="h-32 rounded-xl" />
            ))}
          </div>
          <div className="grid gap-6 lg:grid-cols-2">
            <Skeleton className="h-80 rounded-xl" />
            <Skeleton className="h-80 rounded-xl" />
          </div>
        </div>
      ) : data.summary.income === 0 && data.summary.expenses === 0 ? (
        <Card>
          <CardContent className="p-0">
            <EmptyState icon={FileBarChart} title={t('noData')} />
          </CardContent>
        </Card>
      ) : (
        <>
          {/* Stat cards */}
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <StatCard
              label={t('totalIncome2')}
              value={data.summary.income}
              trend={data.summary.incomeTrend}
              icon={TrendingUp}
              accent="bg-emerald-500/15 text-emerald-500"
              color="#22c55e"
              series={data.summary.incomeSeries}
              currency={currency}
              vsLabel={t('vsPrev')}
            />
            <StatCard
              label={t('totalExpenses2')}
              value={data.summary.expenses}
              trend={data.summary.expenseTrend}
              icon={TrendingDown}
              accent="bg-red-500/15 text-red-500"
              color="#ef4444"
              series={data.summary.expenseSeries}
              currency={currency}
              positiveWhenDown
              vsLabel={t('vsPrev')}
            />
            <StatCard
              label={t('netSavings')}
              value={data.summary.savings}
              trend={data.summary.savingsTrend}
              icon={PiggyBank}
              accent="bg-sky-500/15 text-sky-500"
              color="#0ea5e9"
              series={data.summary.savingsSeries}
              currency={currency}
              vsLabel={t('vsPrev')}
            />
            <StatCard
              label={t('savingsRate')}
              value={data.summary.savingsRate}
              isRate
              trend={data.summary.savingsRateTrend}
              icon={Percent}
              accent="bg-violet-500/15 text-violet-500"
              color="#8b5cf6"
              series={data.summary.rateSeries}
              currency={currency}
              vsLabel={t('vsPrev')}
            />
          </div>

          {/* Charts row */}
          <div className="grid gap-6 lg:grid-cols-2">
            <Card>
              <CardHeader className="flex-row items-center justify-between space-y-0">
                <CardTitle>{t('incomeVsExpensesChart')}</CardTitle>
                <span className="rounded-md border border-border px-2 py-1 text-xs text-muted-foreground">
                  {t('perMonth')}
                </span>
              </CardHeader>
              <CardContent>
                <div className="mb-2 flex items-center gap-4 text-xs">
                  <span className="flex items-center gap-1.5 text-muted-foreground">
                    <span className="h-2 w-2 rounded-full bg-success" /> {t('totalIncome2')}
                  </span>
                  <span className="flex items-center gap-1.5 text-muted-foreground">
                    <span className="h-2 w-2 rounded-full bg-destructive" /> {t('totalExpenses2')}
                  </span>
                </div>
                <div className="h-64 w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={barData} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                      <XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: 'hsl(var(--muted-foreground))' }} />
                      <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} tickFormatter={(v) => formatNumber(v)} width={52} />
                      <Tooltip
                        cursor={{ fill: 'hsl(var(--muted))' }}
                        contentStyle={{ borderRadius: 12, border: '1px solid hsl(var(--border))', background: 'hsl(var(--card))', fontSize: 12 }}
                        formatter={(v: number, n) => [fmtMoney(v), n === 'income' ? t('totalIncome2') : t('totalExpenses2')]}
                      />
                      <Bar dataKey="income" fill="#22c55e" radius={[4, 4, 0, 0]} maxBarSize={18} />
                      <Bar dataKey="expenses" fill="#ef4444" radius={[4, 4, 0, 0]} maxBarSize={18} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>{t('expenseByCategory')}</CardTitle>
              </CardHeader>
              <CardContent>
                {data.expenseByCategory.length === 0 ? (
                  <p className="py-16 text-center text-sm text-muted-foreground">—</p>
                ) : (
                  <div className="flex flex-col items-center gap-5 sm:flex-row">
                    <div className="relative h-48 w-48 shrink-0">
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie data={data.expenseByCategory} dataKey="amount" nameKey="name" innerRadius={56} outerRadius={84} paddingAngle={2} strokeWidth={0}>
                            {data.expenseByCategory.map((s) => (
                              <Cell key={s.categoryId} fill={s.color} />
                            ))}
                          </Pie>
                          <Tooltip
                            contentStyle={{ borderRadius: 12, border: '1px solid hsl(var(--border))', background: 'hsl(var(--card))', fontSize: 12 }}
                            formatter={(v: number, n: string) => [fmtMoney(v), n]}
                          />
                        </PieChart>
                      </ResponsiveContainer>
                      <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                        <span className="text-base font-bold leading-tight text-foreground">
                          {formatNumber(data.summary.expenses)}
                        </span>
                        <span className="text-[10px] text-muted-foreground">{currency === 'XOF' ? 'FCFA' : currency}</span>
                      </div>
                    </div>
                    <ul className="grid flex-1 gap-2.5">
                      {data.expenseByCategory.slice(0, 6).map((s) => (
                        <li key={s.categoryId} className="flex items-center justify-between text-sm">
                          <span className="flex items-center gap-2 text-muted-foreground">
                            <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: s.color }} />
                            {s.name}
                          </span>
                          <span className="flex items-center gap-3">
                            <span className="font-medium text-foreground">{formatNumber(s.amount)}</span>
                            <span className="w-8 text-right text-xs text-muted-foreground">
                              {Math.round(s.percentage)}%
                            </span>
                          </span>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>

          {/* Evolution table + budget analysis */}
          <div className="grid gap-6 lg:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>{t('monthlyEvolution')}</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="text-left text-xs text-muted-foreground">
                        <th className="pb-2 font-medium">{t('month')}</th>
                        <th className="pb-2 text-right font-medium">{t('totalIncome2')}</th>
                        <th className="pb-2 text-right font-medium">{t('totalExpenses2')}</th>
                        <th className="pb-2 text-right font-medium">{t('netSavings')}</th>
                        <th className="pb-2 text-right font-medium">{t('savingsRate')}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {data.monthlyEvolution.map((m, i) => {
                        const isLast = i === data.monthlyEvolution.length - 1;
                        return (
                          <tr
                            key={`${m.year}-${m.month}`}
                            className={cn(
                              'border-t border-border/60',
                              isLast && 'bg-primary/5 font-medium',
                            )}
                          >
                            <td className="py-2.5 text-foreground">
                              {monthYearLabel(m.month, m.year, locale)}
                            </td>
                            <td className="py-2.5 text-right text-foreground">{fmtMoney(m.income)}</td>
                            <td className="py-2.5 text-right text-foreground">{fmtMoney(m.expenses)}</td>
                            <td className="py-2.5 text-right text-foreground">{fmtMoney(m.savings)}</td>
                            <td className="py-2.5 text-right text-foreground">{m.savingsRate}%</td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
                <Button
                  variant="outline"
                  className="mt-4"
                  size="sm"
                  onClick={() => setParams({ period: 'yearly' })}
                >
                  {t('seeAnnualReport')}
                </Button>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex-row items-center justify-between space-y-0">
                <CardTitle>{t('budgetAnalysis')}</CardTitle>
                <Link href="/budgets" className="text-sm font-medium text-primary hover:underline">
                  {t('seeAll')}
                </Link>
              </CardHeader>
              <CardContent>
                <div className="flex flex-col items-center gap-5 sm:flex-row">
                  {/* Respected donut */}
                  <div className="relative h-36 w-36 shrink-0">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={[
                            { name: 'ok', value: data.budgets.respectedPct },
                            { name: 'rest', value: 100 - data.budgets.respectedPct },
                          ]}
                          dataKey="value"
                          innerRadius={46}
                          outerRadius={62}
                          startAngle={90}
                          endAngle={-270}
                          strokeWidth={0}
                        >
                          <Cell fill="#6366f1" />
                          <Cell fill="hsl(var(--secondary))" />
                        </Pie>
                      </PieChart>
                    </ResponsiveContainer>
                    <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center text-center">
                      <span className="text-[10px] text-muted-foreground">{t('budgetsRespected')}</span>
                      <span className="text-lg font-bold text-foreground">
                        {data.budgets.respectedPct}%
                      </span>
                    </div>
                  </div>
                  <div className="min-w-0 flex-1 space-y-2.5">
                    {data.budgets.items.slice(0, 4).map((b) => {
                      const meta = budgetStatus(b.status);
                      const Icon = categoryIcon(b.icon);
                      const color = b.color || '#6366f1';
                      return (
                        <div key={b.category} className="space-y-1">
                          <div className="flex items-center justify-between gap-2 text-sm">
                            <span className="flex min-w-0 items-center gap-2">
                              <span
                                className="flex h-6 w-6 shrink-0 items-center justify-center rounded-md"
                                style={{ backgroundColor: `${color}1F`, color }}
                              >
                                <Icon className="h-3.5 w-3.5" />
                              </span>
                              <span className="truncate font-medium text-foreground">{b.category}</span>
                            </span>
                            <span className="flex shrink-0 items-center gap-2">
                              <span className="text-xs text-muted-foreground">
                                {Math.round(b.progress)}%
                              </span>
                              <Badge variant={meta.badge}>{meta.label}</Badge>
                            </span>
                          </div>
                          <div className="h-1.5 w-full overflow-hidden rounded-full bg-secondary">
                            <div
                              className={cn('h-full rounded-full', meta.bar)}
                              style={{ width: `${Math.min(100, b.progress)}%` }}
                            />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
                <p className="mt-3 text-center text-xs text-muted-foreground">
                  {t('budgetsRatio', {
                    respected: data.budgets.respectedCount,
                    total: data.budgets.totalCount,
                  })}
                </p>
              </CardContent>
            </Card>
          </div>

          {/* AI footer */}
          <div className="flex flex-col gap-2 rounded-xl border border-primary/20 bg-primary/5 p-4 sm:flex-row sm:items-center sm:justify-between">
            <p className="flex items-start gap-2 text-sm text-foreground">
              <Info className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
              <span>
                <span className="font-semibold">{t('aiAnalysisLabel')} :</span> {data.aiSummary}
              </span>
            </p>
            <Link
              href="/ai"
              className="shrink-0 text-sm font-medium text-primary hover:underline"
            >
              {t('seeDetailedAnalysis')} →
            </Link>
          </div>
        </>
      )}
    </div>
  );
}
