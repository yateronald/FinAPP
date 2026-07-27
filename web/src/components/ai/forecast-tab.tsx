'use client';

import { useState } from 'react';
import {
  Area,
  ComposedChart,
  CartesianGrid,
  Line,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import {
  AlertTriangle,
  ArrowDownRight,
  ArrowUpRight,
  BrainCircuit,
  CalendarClock,
  Info,
  Lightbulb,
  Minus,
  Sparkles,
  TrendingDown,
  TrendingUp,
  Wallet,
  type LucideIcon,
} from 'lucide-react';
import { useLocale, useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { categoryIcon } from '@/lib/category-icons';
import { useForecast } from '@/hooks/use-forecast';
import { useAuthStore } from '@/store/auth';
import { cn, formatCurrency, formatNumber, formatPercent } from '@/lib/utils';

function OverviewCard({
  label,
  value,
  trend,
  sub,
  icon: Icon,
  accent,
  currency,
}: {
  label: string;
  value: number;
  trend?: number;
  sub?: string;
  icon: LucideIcon;
  accent: 'green' | 'red' | 'blue' | 'amber';
  currency: string;
}) {
  const chip = {
    green: 'bg-emerald-500/15 text-emerald-500',
    red: 'bg-red-500/15 text-red-500',
    blue: 'bg-sky-500/15 text-sky-500',
    amber: 'bg-amber-500/15 text-amber-500',
  }[accent];
  const isZero = (trend ?? 0) === 0;
  const up = (trend ?? 0) > 0;
  return (
    <Card>
      <CardContent className="p-5">
        <div className="flex items-center gap-3">
          <span className={cn('flex h-10 w-10 items-center justify-center rounded-xl', chip)}>
            <Icon className="h-5 w-5" />
          </span>
          <p className="text-sm text-muted-foreground">{label}</p>
        </div>
        <p className="mt-3 text-xl font-bold text-foreground">{formatCurrency(value, currency)}</p>
        {trend !== undefined ? (
          <p className="mt-1 flex items-center gap-1 text-xs">
            {isZero ? (
              // Neutral when the model predicts no change (e.g. limited history).
              <span className="flex items-center gap-0.5 font-semibold text-muted-foreground">
                <Minus className="h-3 w-3" /> 0%
              </span>
            ) : (
              <span
                className={cn(
                  'flex items-center font-semibold',
                  up ? 'text-success' : 'text-destructive',
                )}
              >
                {up ? <ArrowUpRight className="h-3 w-3" /> : <ArrowDownRight className="h-3 w-3" />}
                {formatPercent(trend)}
              </span>
            )}
            <span className="text-muted-foreground">{sub}</span>
          </p>
        ) : (
          sub && <p className="mt-1 text-xs text-muted-foreground">{sub}</p>
        )}
      </CardContent>
    </Card>
  );
}

/** Map a technical model id (e.g. "damped-holt(a=0.5,...)") to an i18n key. */
function modelKey(name: string): string {
  if (name.startsWith('damped-holt')) return 'modelDampedHolt';
  if (name.startsWith('holt-winters')) return 'modelHoltWinters';
  if (name.startsWith('holt')) return 'modelHolt';
  if (name.startsWith('ses')) return 'modelSes';
  if (name.startsWith('seasonal-naive')) return 'modelSeasonalNaive';
  if (name === 'zero') return 'modelZero';
  return 'modelNaive';
}

export function ForecastTab() {
  const t = useTranslations('ai');
  const tc = useTranslations('common');
  const locale = useLocale();
  const currency = useAuthStore((s) => s.user?.settings?.currency) || 'XOF';
  const [horizon, setHorizon] = useState(60);
  const { data, isLoading } = useForecast(horizon);

  const fmtDay = (d: string) =>
    new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-US', {
      day: 'numeric',
      month: 'short',
    }).format(new Date(`${d}T00:00:00Z`));

  if (isLoading || !data) {
    return (
      <div className="space-y-6">
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-28 rounded-xl" />
          ))}
        </div>
        <Skeleton className="h-80 rounded-xl" />
      </div>
    );
  }

  const { overview, cashflow, byCategory, totalProjected, alerts, suggestions, objectives } = data;

  const chartData = cashflow.map((p) => ({
    date: p.date,
    actual: p.actual,
    forecast: p.forecast,
    band: p.lower !== null && p.upper !== null ? [p.lower, p.upper] : null,
  }));

  return (
    <div className="space-y-6">
      {/* Overview cards */}
      <Card className="bg-muted/30">
        <CardContent className="p-4 sm:p-5">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm font-semibold text-foreground">
              {t('forecastOverview')}{' '}
              <span className="font-normal text-muted-foreground">
                ({t('nextNDays', { n: horizon })})
              </span>
            </p>
            {/* Horizon selector: 1 / 2 / 3 months — drives every widget below */}
            <div className="flex gap-0.5 rounded-lg bg-muted p-1">
              {[
                { days: 30, label: t('month1') },
                { days: 60, label: t('month2') },
                { days: 90, label: t('month3') },
              ].map((o) => (
                <button
                  key={o.days}
                  type="button"
                  onClick={() => setHorizon(o.days)}
                  className={cn(
                    'rounded-md px-3 py-1.5 text-xs font-medium transition-colors',
                    horizon === o.days
                      ? 'bg-card text-foreground shadow-sm'
                      : 'text-muted-foreground hover:text-foreground',
                  )}
                >
                  {o.label}
                </button>
              ))}
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <OverviewCard
              label={t('projectedIncome')}
              value={overview.projectedIncome}
              trend={overview.incomeTrend}
              sub={t('vsCurrentMonth')}
              icon={TrendingUp}
              accent="green"
              currency={currency}
            />
            <OverviewCard
              label={t('projectedExpenses')}
              value={overview.projectedExpenses}
              trend={overview.expenseTrend}
              sub={t('vsCurrentMonth')}
              icon={TrendingDown}
              accent="red"
              currency={currency}
            />
            <OverviewCard
              label={t('projectedSavings')}
              value={overview.projectedSavings}
              trend={overview.savingsTrend}
              sub={t('vsCurrentMonth')}
              icon={Wallet}
              accent="blue"
              currency={currency}
            />
            <OverviewCard
              label={t('projectedBalance')}
              value={overview.projectedBalance}
              sub={t('atDate', { date: fmtDay(overview.balanceDate) })}
              icon={CalendarClock}
              accent="amber"
              currency={currency}
            />
          </div>
        </CardContent>
      </Card>

      {/* Cash-flow chart + category table */}
      <div className="grid gap-6 lg:grid-cols-[1.4fr_1fr]">
        <Card>
          <CardHeader className="flex-row items-center justify-between space-y-0">
            <CardTitle>{t('cashflowTitle')}</CardTitle>
            <Select value={String(horizon)} onValueChange={(v) => setHorizon(Number(v))}>
              <SelectTrigger className="h-9 w-[160px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="30">{t('horizon30')}</SelectItem>
                <SelectItem value="60">{t('horizon60')}</SelectItem>
                <SelectItem value="90">{t('horizon90')}</SelectItem>
              </SelectContent>
            </Select>
          </CardHeader>
          <CardContent>
            <div className="mb-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs">
              <span className="flex items-center gap-1.5 text-muted-foreground">
                <span className="h-2 w-4 rounded bg-emerald-500" /> {t('realBalance')}
              </span>
              <span className="flex items-center gap-1.5 text-muted-foreground">
                <span className="h-0 w-4 border-t-2 border-dashed border-emerald-500" />{' '}
                {t('forecastLabel')}
              </span>
              <span className="flex items-center gap-1.5 text-muted-foreground">
                <span className="h-2.5 w-4 rounded bg-emerald-500/20" /> {t('confidenceBand')}
              </span>
            </div>
            <div className="h-72 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart data={chartData} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                  <XAxis
                    dataKey="date"
                    tickFormatter={fmtDay}
                    axisLine={false}
                    tickLine={false}
                    minTickGap={40}
                    tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
                  />
                  <YAxis
                    axisLine={false}
                    tickLine={false}
                    tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }}
                    tickFormatter={(v) => formatNumber(v)}
                    width={52}
                  />
                  <Tooltip
                    contentStyle={{
                      borderRadius: 12,
                      border: '1px solid hsl(var(--border))',
                      background: 'hsl(var(--card))',
                      fontSize: 12,
                    }}
                    labelFormatter={(d) => fmtDay(String(d))}
                    formatter={(v: any, name) => {
                      if (v == null) return [null, null] as any;
                      if (name === 'band') {
                        if (!Array.isArray(v) || v[0] === v[1]) return [null, null] as any;
                        return [
                          `${formatCurrency(Number(v[0]), currency)} – ${formatCurrency(Number(v[1]), currency)}`,
                          t('intervalLabel'),
                        ];
                      }
                      return [
                        formatCurrency(Number(v), currency),
                        name === 'actual' ? t('realBalance') : t('forecastLabel'),
                      ];
                    }}
                  />
                  <Area
                    dataKey="band"
                    stroke="none"
                    fill="#10b981"
                    fillOpacity={0.12}
                    isAnimationActive={false}
                    connectNulls
                  />
                  <Line
                    type="monotone"
                    dataKey="actual"
                    stroke="#10b981"
                    strokeWidth={2.5}
                    dot={false}
                    connectNulls
                  />
                  <Line
                    type="monotone"
                    dataKey="forecast"
                    stroke="#10b981"
                    strokeWidth={2.5}
                    strokeDasharray="6 5"
                    dot={false}
                    connectNulls
                  />
                </ComposedChart>
              </ResponsiveContainer>
            </div>

            {/* Model transparency: which algorithm was auto-selected + accuracy */}
            <div className="mt-4 rounded-xl border border-border bg-muted/30 p-3">
              <div className="flex items-start gap-2.5">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                  <BrainCircuit className="h-4 w-4" />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-xs font-semibold text-foreground">{t('modelSection')}</p>
                  <div className="mt-1.5 flex flex-wrap gap-1.5">
                    <span className="inline-flex items-center gap-1 rounded-full bg-emerald-500/10 px-2.5 py-1 text-[11px] font-medium text-emerald-600 dark:text-emerald-400">
                      {t('modelIncome')} : {t(modelKey(data.models.income.name))}
                      {data.models.income.mae !== null && (
                        <span className="opacity-70">
                          · {t('avgError', { v: formatNumber(data.models.income.mae) })}
                        </span>
                      )}
                    </span>
                    <span className="inline-flex items-center gap-1 rounded-full bg-red-500/10 px-2.5 py-1 text-[11px] font-medium text-red-600 dark:text-red-400">
                      {t('modelExpenses')} : {t(modelKey(data.models.expenses.name))}
                      {data.models.expenses.mae !== null && (
                        <span className="opacity-70">
                          · {t('avgError', { v: formatNumber(data.models.expenses.mae) })}
                        </span>
                      )}
                    </span>
                  </div>
                  <p className="mt-1.5 text-[11px] leading-snug text-muted-foreground">
                    {t('modelExplain')} ·{' '}
                    {t('updatedAt', { date: fmtDay(data.generatedAt.slice(0, 10)) })}
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>
              {t('categoryForecast')}{' '}
              <span className="text-sm font-normal text-muted-foreground">
                ({t('nextNDays', { n: horizon })})
              </span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-muted-foreground">
                  <th className="pb-2 font-medium">{tc('category')}</th>
                  <th className="pb-2 text-right font-medium">{t('projected')}</th>
                  <th className="pb-2 text-right font-medium">{t('ofTotal')}</th>
                  <th className="pb-2 text-right font-medium">{t('evolution')}</th>
                </tr>
              </thead>
              <tbody>
                {byCategory.slice(0, 7).map((c) => {
                  const Icon = categoryIcon();
                  const up = c.evolution >= 0;
                  return (
                    <tr key={c.categoryId} className="border-t border-border/60">
                      <td className="py-2.5">
                        <span className="flex items-center gap-2">
                          <span
                            className="flex h-6 w-6 items-center justify-center rounded-md"
                            style={{ backgroundColor: `${c.color}1F`, color: c.color }}
                          >
                            <Icon className="h-3.5 w-3.5" />
                          </span>
                          <span className="font-medium text-foreground">{c.name}</span>
                        </span>
                      </td>
                      <td className="py-2.5 text-right text-foreground">
                        {formatNumber(c.projected)}
                      </td>
                      <td className="py-2.5 text-right text-muted-foreground">{c.percentage}%</td>
                      <td className="py-2.5 text-right">
                        {c.evolution === 0 ? (
                          <span className="inline-flex items-center gap-0.5 text-xs font-medium text-muted-foreground">
                            <Minus className="h-3 w-3" /> {t('stableTrend')}
                          </span>
                        ) : (
                          <span
                            className={cn(
                              'inline-flex items-center gap-0.5 text-xs font-medium',
                              up ? 'text-destructive' : 'text-success',
                            )}
                          >
                            {up ? (
                              <ArrowUpRight className="h-3 w-3" />
                            ) : (
                              <ArrowDownRight className="h-3 w-3" />
                            )}
                            {formatPercent(c.evolution)}
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
              <tfoot>
                <tr className="border-t border-border font-semibold text-foreground">
                  <td className="pt-2.5">{t('totalForecast')}</td>
                  <td className="pt-2.5 text-right">{formatNumber(totalProjected)}</td>
                  <td colSpan={2} />
                </tr>
              </tfoot>
            </table>
          </CardContent>
        </Card>
      </div>

      {/* Alerts + predictions + objectives */}
      <div className="grid gap-6 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>{t('forecastAlerts')}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {alerts.map((a, i) => {
              const warn = a.type === 'warning';
              const Icon = warn ? AlertTriangle : Info;
              return (
                <div
                  key={i}
                  className={cn('rounded-xl p-3', warn ? 'bg-amber-500/5' : 'bg-sky-500/5')}
                >
                  <div className="flex items-start gap-2.5">
                    <Icon
                      className={cn(
                        'mt-0.5 h-4 w-4 shrink-0',
                        warn ? 'text-amber-500' : 'text-sky-500',
                      )}
                    />
                    <div>
                      <p className="text-sm font-medium text-foreground">{a.title}</p>
                      <p className="mt-0.5 text-xs text-muted-foreground">{a.detail}</p>
                    </div>
                  </div>
                </div>
              );
            })}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <span className="flex h-6 w-6 items-center justify-center rounded-md bg-primary/10">
                <Sparkles className="h-3.5 w-3.5 text-primary" />
              </span>
              {t('topPredictions')}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {suggestions.map((sug, i) => (
              <div key={i} className="flex items-start gap-3">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                  <Lightbulb className="h-3.5 w-3.5" />
                </span>
                <div>
                  <p className="text-sm text-foreground">{sug.text}</p>
                  <p className="mt-0.5 text-xs font-medium text-primary">{sug.cta}</p>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t('goalsAttainment')}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {objectives.map((o, i) => (
              <div key={i}>
                <div className="flex items-center justify-between text-sm">
                  <span className="font-medium text-foreground">{o.name}</span>
                  <span className="font-bold text-foreground">{o.percentage}%</span>
                </div>
                <div className="mt-1.5 h-2 w-full overflow-hidden rounded-full bg-secondary">
                  <div
                    className={cn('h-full rounded-full', i === 0 ? 'bg-primary' : 'bg-emerald-500')}
                    style={{ width: `${Math.min(100, o.percentage)}%` }}
                  />
                </div>
                <div className="mt-1 flex items-center justify-between text-xs text-muted-foreground">
                  <span>
                    {formatNumber(o.current)} / {formatNumber(o.target)} {currency === 'XOF' ? 'FCFA' : currency}
                  </span>
                  {o.etaDate && <span>{t('expectedBy', { date: fmtDay(o.etaDate) })}</span>}
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      </div>

      {/* Disclaimer */}
      <div className="flex items-start gap-2 rounded-xl border border-border bg-muted/30 p-3 text-xs text-muted-foreground">
        <Info className="mt-0.5 h-4 w-4 shrink-0" />
        <p>{t('forecastDisclaimer')}</p>
      </div>
    </div>
  );
}
