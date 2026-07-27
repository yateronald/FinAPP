'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import {
  Area,
  AreaChart,
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
  ArrowRight,
  CalendarClock,
  ChevronLeft,
  ChevronRight,
  Hash,
  Lightbulb,
  MoreVertical,
  Pencil,
  Plus,
  RefreshCcw,
  Search,
  Sparkles,
  Star,
  TrendingUp,
  Trash2,
  Wallet,
  CheckCircle2,
} from 'lucide-react';
import { useLocale, useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ConfirmDialog } from '@/components/confirm-dialog';
import { EmptyState } from '@/components/empty-state';
import {
  TransactionFormDialog,
  type TransactionFormValues,
} from '@/components/transactions/transaction-form-dialog';
import { useCategories } from '@/hooks/use-categories';
import {
  useIncomeList,
  useIncomeMutations,
  useIncomeOverview,
} from '@/hooks/use-transactions';
import { useAuthStore } from '@/store/auth';
import { useAnchor } from '@/store/period';
import { categoryIcon } from '@/lib/category-icons';
import { cn, formatCurrency, formatDate, formatNumber, formatPercent } from '@/lib/utils';
import type { Transaction } from '@/lib/types';

const ALL = '__all__';

function Sparkline({ points, color }: { points: number[]; color: string }) {
  if (points.length < 2) return null;
  const min = Math.min(...points);
  const max = Math.max(...points);
  const range = max - min || 1;
  const w = 72;
  const h = 26;
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

export default function IncomePage() {
  const t = useTranslations('income');
  const tc = useTranslations('common');
  const locale = useLocale();
  const currency = useAuthStore((s) => s.user?.settings?.currency) || 'XOF';
  const anchor = useAnchor();

  // Default window = anchor month.
  const monthStart = `${anchor.year}-${String(anchor.month).padStart(2, '0')}-01`;
  const monthEndDate = new Date(Date.UTC(anchor.year, anchor.month, 0)).getUTCDate();
  const monthEnd = `${anchor.year}-${String(anchor.month).padStart(2, '0')}-${String(monthEndDate).padStart(2, '0')}`;

  const [search, setSearch] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [from, setFrom] = useState(monthStart);
  const [to, setTo] = useState(monthEnd);
  const [page, setPage] = useState(1);
  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<Transaction | null>(null);
  const [deleting, setDeleting] = useState<Transaction | null>(null);

  const { data: categories } = useCategories('INCOME');
  const { data: overview, isLoading: loadingOverview } = useIncomeOverview(from, to);
  const { data: list, isLoading: loadingList } = useIncomeList({
    search: search || undefined,
    categoryId: categoryId || undefined,
    from,
    to,
    page,
    limit: 10,
  });
  const { create, update, remove } = useIncomeMutations();

  const trendSeries = useMemo(() => (overview?.trend ?? []).map((p) => p.income), [overview]);

  const submit = (values: TransactionFormValues) => {
    const payload = {
      title: values.title,
      categoryId: values.categoryId,
      amount: Number(values.amount),
      date: new Date(values.date).toISOString(),
      description: values.description || undefined,
      isRecurring: values.isRecurring ?? false,
    };
    const done = (msg: string) => {
      toast.success(msg);
      setFormOpen(false);
      setEditing(null);
    };
    if (editing) {
      update.mutate(
        { id: editing.id, ...payload },
        { onSuccess: () => done(t('updated')), onError: (e: any) => toast.error(e?.message) },
      );
    } else {
      create.mutate(payload, {
        onSuccess: () => done(t('created')),
        onError: (e: any) => toast.error(e?.message),
      });
    }
  };

  const items = list?.items ?? [];
  const showingFrom = list && list.total > 0 ? (list.page - 1) * list.limit + 1 : 0;
  const showingTo = list ? Math.min(list.page * list.limit, list.total) : 0;

  const topCat = overview?.distribution?.[0];
  const secondCat = overview?.distribution?.[1];
  const growthUp = (overview?.totalTrend ?? 0) >= 0;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">{t('title')}</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">{t('subtitle')}</p>
        </div>
        <Button
          size="lg"
          onClick={() => {
            setEditing(null);
            setFormOpen(true);
          }}
        >
          <Plus className="h-4 w-4" /> {t('add')}
        </Button>
      </div>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_320px]">
        {/* ============================== MAIN COLUMN ============================== */}
        <div className="min-w-0 space-y-6">
          {/* Stat cards */}
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {loadingOverview || !overview ? (
              Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-32 rounded-xl" />)
            ) : (
              <>
                <Card>
                  <CardContent className="p-5">
                    <div className="flex items-center gap-3">
                      <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-emerald-500/15 text-emerald-500">
                        <TrendingUp className="h-5 w-5" />
                      </span>
                      <div className="min-w-0">
                        <p className="truncate text-sm text-muted-foreground">{t('totalIncome')}</p>
                        <p className="truncate text-xl font-bold text-foreground">
                          {formatCurrency(overview.total, currency)}
                        </p>
                      </div>
                    </div>
                    <div className="mt-3 flex items-center justify-between">
                      <p className="text-xs">
                        <span className={cn('font-semibold', growthUp ? 'text-success' : 'text-destructive')}>
                          {formatPercent(overview.totalTrend)}
                        </span>{' '}
                        <span className="text-muted-foreground">{tc('thisMonth').toLowerCase()}</span>
                      </p>
                      <Sparkline points={trendSeries} color="#10b981" />
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardContent className="p-5">
                    <div className="flex items-center gap-3">
                      <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-indigo-500/15 text-indigo-500">
                        <Wallet className="h-5 w-5" />
                      </span>
                      <div className="min-w-0">
                        <p className="truncate text-sm text-muted-foreground">{t('avgPerMonth')}</p>
                        <p className="truncate text-xl font-bold text-foreground">
                          {formatCurrency(overview.average, currency)}
                        </p>
                      </div>
                    </div>
                    <div className="mt-3 flex items-center justify-between">
                      <p className="text-xs">
                        <span
                          className={cn(
                            'font-semibold',
                            overview.averageTrend >= 0 ? 'text-success' : 'text-destructive',
                          )}
                        >
                          {formatPercent(overview.averageTrend)}
                        </span>
                      </p>
                      <Sparkline points={trendSeries} color="#6366f1" />
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardContent className="p-5">
                    <div className="flex items-center gap-3">
                      <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-sky-500/15 text-sky-500">
                        <Star className="h-5 w-5" />
                      </span>
                      <div className="min-w-0">
                        <p className="truncate text-sm text-muted-foreground">{t('biggest')}</p>
                        <p className="truncate text-xl font-bold text-foreground">
                          {overview.max ? formatCurrency(overview.max.amount, currency) : '—'}
                        </p>
                      </div>
                    </div>
                    {overview.max && (
                      <p className="mt-3 truncate text-xs text-muted-foreground">
                        {overview.max.category} · {formatDate(overview.max.date)}
                      </p>
                    )}
                  </CardContent>
                </Card>
              </>
            )}
          </div>

          {/* Filters */}
          <div className="flex flex-wrap items-center gap-2">
            <div className="relative min-w-[200px] flex-1">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value);
                  setPage(1);
                }}
                placeholder={t('searchPlaceholder')}
                className="pl-9"
              />
            </div>
            <Select
              value={categoryId || ALL}
              onValueChange={(v) => {
                setCategoryId(v === ALL ? '' : v);
                setPage(1);
              }}
            >
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder={t('allCategories')} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ALL}>{t('allCategories')}</SelectItem>
                {(categories ?? []).map((c) => (
                  <SelectItem key={c.id} value={c.id}>
                    {c.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Input
              type="date"
              value={from}
              onChange={(e) => {
                setFrom(e.target.value);
                setPage(1);
              }}
              className="w-[150px]"
            />
            <Input
              type="date"
              value={to}
              onChange={(e) => {
                setTo(e.target.value);
                setPage(1);
              }}
              className="w-[150px]"
            />
          </div>

          {/* Charts row */}
          <div className="grid gap-6 lg:grid-cols-2">
            <Card>
              <CardHeader className="flex-row items-center justify-between space-y-0">
                <CardTitle>{t('evolution')}</CardTitle>
                <span className="rounded-md border border-border px-2 py-1 text-xs text-muted-foreground">
                  {t('last6Months')}
                </span>
              </CardHeader>
              <CardContent>
                <div className="h-56 w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart
                      data={overview?.trend ?? []}
                      margin={{ top: 8, right: 8, left: 0, bottom: 0 }}
                    >
                      <defs>
                        <linearGradient id="incomeFill" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#10b981" stopOpacity={0.25} />
                          <stop offset="100%" stopColor="#10b981" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                      <XAxis
                        dataKey="label"
                        axisLine={false}
                        tickLine={false}
                        tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
                      />
                      <YAxis
                        axisLine={false}
                        tickLine={false}
                        tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }}
                        tickFormatter={(v) => formatNumber(v)}
                        width={48}
                      />
                      <Tooltip
                        contentStyle={{
                          borderRadius: 12,
                          border: '1px solid hsl(var(--border))',
                          background: 'hsl(var(--card))',
                          fontSize: 12,
                        }}
                        formatter={(v: number) => [formatCurrency(v, currency), '']}
                      />
                      <Area
                        type="monotone"
                        dataKey="income"
                        stroke="#10b981"
                        strokeWidth={2.5}
                        fill="url(#incomeFill)"
                        dot={{ r: 3, fill: '#10b981' }}
                        activeDot={{ r: 5 }}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex-row items-center justify-between space-y-0">
                <CardTitle>{t('byCategory')}</CardTitle>
                <span className="rounded-md border border-border px-2 py-1 text-xs text-muted-foreground">
                  {tc('thisMonth')}
                </span>
              </CardHeader>
              <CardContent>
                {(overview?.distribution ?? []).length === 0 ? (
                  <p className="py-16 text-center text-sm text-muted-foreground">{tc('noData')}</p>
                ) : (
                  <div className="flex flex-col items-center gap-4 sm:flex-row">
                    <div className="relative h-44 w-44 shrink-0">
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie
                            data={overview!.distribution}
                            dataKey="amount"
                            nameKey="name"
                            innerRadius={54}
                            outerRadius={82}
                            paddingAngle={2}
                            strokeWidth={0}
                          >
                            {overview!.distribution.map((s) => (
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
                        <span className="text-base font-bold text-foreground">
                          {formatCurrency(overview!.total, currency)}
                        </span>
                      </div>
                    </div>
                    <ul className="w-full flex-1 space-y-2">
                      {overview!.distribution.slice(0, 5).map((s) => (
                        <li key={s.categoryId} className="flex items-center justify-between text-sm">
                          <span className="flex items-center gap-2 text-muted-foreground">
                            <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: s.color }} />
                            {s.name} <span className="text-xs">({s.percentage}%)</span>
                          </span>
                          <span className="font-medium text-foreground">
                            {formatCurrency(s.amount, currency)}
                          </span>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>

          {/* Income table */}
          <Card>
            <CardHeader>
              <CardTitle>{t('list')}</CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              {loadingList ? (
                <div className="space-y-2 p-4">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <Skeleton key={i} className="h-14 rounded-lg" />
                  ))}
                </div>
              ) : items.length === 0 ? (
                <EmptyState icon={Wallet} title={t('empty')} description={t('emptyDesc')} />
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[720px] text-sm">
                    <thead>
                      <tr className="border-b border-border text-left text-xs text-muted-foreground">
                        <th className="px-5 py-3 font-medium"> </th>
                        <th className="px-3 py-3 font-medium">{tc('category')}</th>
                        <th className="px-3 py-3 text-right font-medium">{tc('amount')}</th>
                        <th className="px-3 py-3 font-medium">{tc('date')}</th>
                        <th className="px-3 py-3 font-medium">{t('periodicity')}</th>
                        <th className="px-3 py-3 font-medium">{t('source')}</th>
                        <th className="px-3 py-3 font-medium">{t('status')}</th>
                        <th className="px-3 py-3 font-medium">{tc('actions')}</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-border/60">
                      {items.map((tx) => {
                        const Icon = categoryIcon(tx.category.icon);
                        const color = tx.category.color || '#22c55e';
                        return (
                          <tr key={tx.id} className="transition-colors hover:bg-muted/40">
                            <td className="px-5 py-3">
                              <div className="flex min-w-0 items-center gap-3">
                                <span
                                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
                                  style={{ backgroundColor: `${color}1F`, color }}
                                >
                                  <Icon className="h-4 w-4" />
                                </span>
                                <div className="min-w-0">
                                  <p className="truncate font-medium text-foreground">{tx.title}</p>
                                  <p className="truncate text-xs text-muted-foreground">
                                    {tx.category.name}
                                  </p>
                                </div>
                              </div>
                            </td>
                            <td className="px-3 py-3">
                              <span
                                className="rounded-full px-2.5 py-0.5 text-xs font-medium"
                                style={{ backgroundColor: `${color}1F`, color }}
                              >
                                {tx.category.name}
                              </span>
                            </td>
                            <td className="px-3 py-3 text-right font-semibold tabular-nums text-foreground">
                              {formatCurrency(tx.amount, currency)}
                            </td>
                            <td className="px-3 py-3 text-muted-foreground">{formatDate(tx.date)}</td>
                            <td className="px-3 py-3">
                              <Badge variant={tx.isRecurring ? 'default' : 'muted'}>
                                {tx.isRecurring ? t('recurring') : t('oneTime')}
                              </Badge>
                            </td>
                            <td className="max-w-[140px] truncate px-3 py-3 text-muted-foreground">
                              {tx.description || '—'}
                            </td>
                            <td className="px-3 py-3">
                              <Badge variant="success">
                                <CheckCircle2 className="mr-1 h-3 w-3" /> {t('received')}
                              </Badge>
                            </td>
                            <td className="px-3 py-3">
                              <DropdownMenu>
                                <DropdownMenuTrigger className="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground focus:outline-none">
                                  <MoreVertical className="h-4 w-4" />
                                </DropdownMenuTrigger>
                                <DropdownMenuContent align="end">
                                  <DropdownMenuItem
                                    onClick={() => {
                                      setEditing(tx);
                                      setFormOpen(true);
                                    }}
                                  >
                                    <Pencil /> {tc('edit')}
                                  </DropdownMenuItem>
                                  <DropdownMenuItem destructive onClick={() => setDeleting(tx)}>
                                    <Trash2 /> {tc('delete')}
                                  </DropdownMenuItem>
                                </DropdownMenuContent>
                              </DropdownMenu>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}

              {list && list.total > 0 && (
                <div className="flex flex-col items-center justify-between gap-2 border-t border-border px-5 py-3 sm:flex-row">
                  <p className="text-xs text-muted-foreground">
                    {t('showing', { from: showingFrom, to: showingTo, total: list.total })}
                  </p>
                  <div className="flex items-center gap-1">
                    <Button
                      variant="outline"
                      size="icon"
                      className="h-8 w-8"
                      disabled={page <= 1}
                      onClick={() => setPage((p) => p - 1)}
                    >
                      <ChevronLeft className="h-4 w-4" />
                    </Button>
                    <span className="flex h-8 min-w-8 items-center justify-center rounded-md border border-border px-2 text-sm font-medium text-foreground">
                      {page}
                    </span>
                    <Button
                      variant="outline"
                      size="icon"
                      className="h-8 w-8"
                      disabled={page >= (list.totalPages || 1)}
                      onClick={() => setPage((p) => p + 1)}
                    >
                      <ChevronRight className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* ============================== RIGHT SIDEBAR ============================== */}
        <div className="space-y-6">
          {/* Résumé des revenus */}
          <Card>
            <CardHeader>
              <CardTitle>{t('summary')}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {loadingOverview || !overview ? (
                <Skeleton className="h-40 rounded-xl" />
              ) : (
                <>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-emerald-500/15 text-emerald-500">
                        <CalendarClock className="h-4 w-4" />
                      </span>
                      <div>
                        <p className="text-sm text-muted-foreground">{t('oneTimeIncome')}</p>
                        <p className="font-semibold text-foreground">
                          {formatCurrency(overview.oneTime.amount, currency)}
                        </p>
                      </div>
                    </div>
                    <span className="text-sm font-bold text-success">{overview.oneTime.percentage}%</span>
                  </div>

                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-sky-500/15 text-sky-500">
                        <RefreshCcw className="h-4 w-4" />
                      </span>
                      <div>
                        <p className="text-sm text-muted-foreground">{t('recurringIncome')}</p>
                        <p className="font-semibold text-foreground">
                          {formatCurrency(overview.recurring.amount, currency)}
                        </p>
                      </div>
                    </div>
                    <span className="text-sm font-bold text-sky-500">
                      {overview.recurring.percentage}%
                    </span>
                  </div>

                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-muted text-muted-foreground">
                        <Hash className="h-4 w-4" />
                      </span>
                      <div>
                        <p className="text-sm text-muted-foreground">{t('incomeCount')}</p>
                        <p className="font-semibold text-foreground">{overview.count}</p>
                      </div>
                    </div>
                    <span className="text-xs text-muted-foreground">{tc('thisMonth')}</span>
                  </div>
                </>
              )}
            </CardContent>
          </Card>

          {/* Insights IA */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <span className="flex h-6 w-6 items-center justify-center rounded-md bg-primary/10">
                  <Sparkles className="h-3.5 w-3.5 text-primary" />
                </span>
                {t('insights')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {overview && (
                <>
                  <div className="rounded-xl bg-emerald-500/5 p-3.5">
                    <div className="flex items-start gap-3">
                      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-500">
                        <TrendingUp className="h-3.5 w-3.5" />
                      </span>
                      <div>
                        <p className="text-sm text-foreground">
                          {t('insightGrowth', {
                            dir: growthUp ? t('insightGrowthUp') : t('insightGrowthDown'),
                            pct: Math.abs(overview.totalTrend),
                          })}
                        </p>
                        <p className="mt-0.5 text-xs font-medium text-emerald-600 dark:text-emerald-400">
                          {t('insightGrowthCta')}
                        </p>
                      </div>
                    </div>
                  </div>

                  {topCat && (
                    <div className="rounded-xl bg-amber-500/5 p-3.5">
                      <div className="flex items-start gap-3">
                        <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-amber-500/15 text-amber-500">
                          <Lightbulb className="h-3.5 w-3.5" />
                        </span>
                        <div>
                          <p className="text-sm text-foreground">
                            {t('insightTop', { cat: topCat.name, pct: Math.round(topCat.percentage) })}
                          </p>
                          <p className="mt-0.5 text-xs font-medium text-amber-600 dark:text-amber-400">
                            {t('insightTopCta')}
                          </p>
                        </div>
                      </div>
                    </div>
                  )}

                  {secondCat && (
                    <div className="rounded-xl bg-indigo-500/5 p-3.5">
                      <div className="flex items-start gap-3">
                        <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-indigo-500/15 text-indigo-500">
                          <RefreshCcw className="h-3.5 w-3.5" />
                        </span>
                        <div>
                          <p className="text-sm text-foreground">
                            {t('insightSuggestion', { cat: secondCat.name })}
                          </p>
                          <Link
                            href="/ai"
                            className="mt-0.5 inline-block text-xs font-medium text-primary hover:underline"
                          >
                            {t('insightSuggestionCta')}
                          </Link>
                        </div>
                      </div>
                    </div>
                  )}
                </>
              )}

              <Link
                href="/ai"
                className="flex items-center justify-center gap-1.5 border-t border-border pt-3 text-sm font-medium text-primary hover:underline"
              >
                {t('seeAllAi')} <ArrowRight className="h-4 w-4" />
              </Link>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Dialogs */}
      <TransactionFormDialog
        open={formOpen}
        onOpenChange={(o) => {
          setFormOpen(o);
          if (!o) setEditing(null);
        }}
        kind="INCOME"
        editing={editing}
        onSubmit={submit}
        saving={create.isPending || update.isPending}
      />
      <ConfirmDialog
        open={!!deleting}
        onOpenChange={(o) => !o && setDeleting(null)}
        title={t('deleteConfirm')}
        description={t('deleteDesc')}
        loading={remove.isPending}
        onConfirm={() =>
          deleting &&
          remove.mutate(deleting.id, {
            onSuccess: () => {
              toast.success(t('deleted'));
              setDeleting(null);
            },
            onError: (e: any) => toast.error(e?.message),
          })
        }
      />
    </div>
  );
}
