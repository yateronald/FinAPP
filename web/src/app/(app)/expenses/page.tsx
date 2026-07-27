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
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  CreditCard,
  Hash,
  LayoutGrid,
  Lightbulb,
  Lock,
  MoreVertical,
  Pencil,
  Plus,
  Receipt,
  Search,
  Shuffle,
  Sparkles,
  TrendingDown,
  Trash2,
  Wallet,
} from 'lucide-react';
import { useTranslations } from 'next-intl';
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
  useExpenseList,
  useExpenseMutations,
  useExpenseOverview,
} from '@/hooks/use-transactions';
import { useBudgets } from '@/hooks/use-budgets';
import { useAuthStore } from '@/store/auth';
import { useAnchor } from '@/store/period';
import { categoryIcon } from '@/lib/category-icons';
import { cn, formatCurrency, formatDate, formatNumber, formatPercent } from '@/lib/utils';
import type { BudgetStatus, Transaction } from '@/lib/types';

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

const budgetMeta = (s: BudgetStatus['status']) => {
  if (s === 'exceeded')
    return { bar: 'bg-destructive', text: 'text-destructive', label: 'exceeded' as const };
  if (s === 'danger' || s === 'warning')
    return { bar: 'bg-amber-500', text: 'text-amber-500', label: 'warning' as const };
  return { bar: 'bg-emerald-500', text: 'text-emerald-500', label: 'onTrack' as const };
};

export default function ExpensesPage() {
  const t = useTranslations('expenses');
  const tb = useTranslations('budget');
  const tc = useTranslations('common');
  const ti = useTranslations('income');
  const currency = useAuthStore((s) => s.user?.settings?.currency) || 'XOF';
  const anchor = useAnchor();

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

  const { data: categories } = useCategories('EXPENSE');
  const { data: overview, isLoading: loadingOverview } = useExpenseOverview(from, to);
  const { data: budgets } = useBudgets(anchor.month, anchor.year);
  const { data: list, isLoading: loadingList } = useExpenseList({
    search: search || undefined,
    categoryId: categoryId || undefined,
    from,
    to,
    page,
    limit: 10,
  });
  const { create, update, remove } = useExpenseMutations();

  const trendSeries = useMemo(() => (overview?.trend ?? []).map((p) => p.expenses), [overview]);
  const topBudgets = useMemo(
    () => [...(budgets ?? [])].sort((a, b) => b.progress - a.progress).slice(0, 3),
    [budgets],
  );
  const worstBudget = topBudgets.find((b) => b.status === 'exceeded');

  const submit = (values: TransactionFormValues) => {
    const payload = {
      title: values.title,
      categoryId: values.categoryId,
      amount: Number(values.amount),
      date: new Date(values.date).toISOString(),
      description: values.description || undefined,
      paymentMethod: values.paymentMethod || undefined,
      tags: values.tags
        ? values.tags.split(',').map((s) => s.trim()).filter(Boolean)
        : undefined,
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
  const trendDown = (overview?.totalTrend ?? 0) <= 0;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">{t('title')}</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">{t('subtitle2')}</p>
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

      {/* Stat cards — full width, 4 across like the mockup */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {loadingOverview || !overview ? (
          Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-32 rounded-xl" />)
        ) : (
          <>
            <Card>
              <CardContent className="p-5">
                <div className="flex items-center gap-3">
                  <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-red-500/15 text-red-500">
                    <TrendingDown className="h-5 w-5" />
                  </span>
                  <div className="min-w-0">
                    <p className="truncate text-sm text-muted-foreground">{t('totalExpenses')}</p>
                    <p className="truncate text-xl font-bold text-foreground">
                      {formatCurrency(overview.total, currency)}
                    </p>
                  </div>
                </div>
                <div className="mt-3 flex items-center justify-between">
                  <p className="text-xs">
                    <span
                      className={cn('font-semibold', trendDown ? 'text-success' : 'text-destructive')}
                    >
                      {formatPercent(overview.totalTrend)}
                    </span>{' '}
                    <span className="text-muted-foreground">{tc('thisMonth').toLowerCase()}</span>
                  </p>
                  <Sparkline points={trendSeries} color="#ef4444" />
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
                    <p className="truncate text-sm text-muted-foreground">{t('avgPerDay')}</p>
                    <p className="truncate text-xl font-bold text-foreground">
                      {formatCurrency(overview.avgPerDay, currency)}
                    </p>
                  </div>
                </div>
                <div className="mt-3 flex justify-end">
                  <Sparkline points={trendSeries} color="#6366f1" />
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-5">
                <div className="flex items-center gap-3">
                  <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-amber-500/15 text-amber-500">
                    <Lock className="h-5 w-5" />
                  </span>
                  <div className="min-w-0">
                    <p className="truncate text-sm text-muted-foreground">{t('topCategory')}</p>
                    <p className="truncate text-xl font-bold text-foreground">
                      {overview.topCategory?.name ?? '—'}
                    </p>
                  </div>
                </div>
                {overview.topCategory && (
                  <p className="mt-3 truncate text-xs text-muted-foreground">
                    {formatCurrency(overview.topCategory.amount, currency)} (
                    {Math.round(overview.topCategory.percentage)}%)
                  </p>
                )}
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-5">
                <div className="flex items-center gap-3">
                  <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-emerald-500/15 text-emerald-500">
                    <Receipt className="h-5 w-5" />
                  </span>
                  <div className="min-w-0">
                    <p className="truncate text-sm text-muted-foreground">{t('transactions')}</p>
                    <p className="truncate text-xl font-bold text-foreground">{overview.count}</p>
                  </div>
                </div>
                <div className="mt-3 flex items-center justify-between">
                  <p className="text-xs">
                    <span
                      className={cn(
                        'font-semibold',
                        overview.countDiff <= 0 ? 'text-success' : 'text-destructive',
                      )}
                    >
                      {overview.countDiff >= 0 ? `+${overview.countDiff}` : overview.countDiff}
                    </span>{' '}
                    <span className="text-muted-foreground">{tc('thisMonth').toLowerCase()}</span>
                  </p>
                  <Sparkline points={trendSeries} color="#10b981" />
                </div>
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

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_320px]">
        {/* ============================== MAIN COLUMN ============================== */}
        <div className="min-w-0 space-y-6">
          {/* Charts row: donut left, evolution right (mockup order) */}
          <div className="grid gap-6 lg:grid-cols-2">
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
                      {overview!.distribution.slice(0, 6).map((s) => (
                        <li key={s.categoryId} className="flex items-center justify-between text-sm">
                          <span className="flex items-center gap-2 text-muted-foreground">
                            <span
                              className="h-2.5 w-2.5 rounded-full"
                              style={{ backgroundColor: s.color }}
                            />
                            {s.name} <span className="text-xs">({Math.round(s.percentage)}%)</span>
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

            <Card>
              <CardHeader className="flex-row items-center justify-between space-y-0">
                <CardTitle>{t('evolution')}</CardTitle>
                <span className="rounded-md border border-border px-2 py-1 text-xs text-muted-foreground">
                  {ti('last6Months')}
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
                        <linearGradient id="expenseFill" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#ef4444" stopOpacity={0.25} />
                          <stop offset="100%" stopColor="#ef4444" stopOpacity={0} />
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
                        dataKey="expenses"
                        stroke="#ef4444"
                        strokeWidth={2.5}
                        fill="url(#expenseFill)"
                        dot={{ r: 3, fill: '#ef4444' }}
                        activeDot={{ r: 5 }}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Expense table */}
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
                <EmptyState icon={Receipt} title={t('empty')} description={t('emptyDesc')} />
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[760px] text-sm">
                    <thead>
                      <tr className="border-b border-border text-left text-xs text-muted-foreground">
                        <th className="px-5 py-3 font-medium">{t('title')}</th>
                        <th className="px-3 py-3 font-medium">{tc('category')}</th>
                        <th className="px-3 py-3 text-right font-medium">{tc('amount')}</th>
                        <th className="px-3 py-3 font-medium">{tc('date')}</th>
                        <th className="px-3 py-3 font-medium">{t('paymentMode')}</th>
                        <th className="px-3 py-3 font-medium">{t('status')}</th>
                        <th className="px-3 py-3 font-medium">{tc('actions')}</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-border/60">
                      {items.map((tx) => {
                        const Icon = categoryIcon(tx.category.icon);
                        const color = tx.category.color || '#ef4444';
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
                                  {tx.description && (
                                    <p className="max-w-[180px] truncate text-xs text-muted-foreground">
                                      {tx.description}
                                    </p>
                                  )}
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
                            <td className="px-3 py-3 text-right font-semibold tabular-nums text-destructive">
                              -{formatCurrency(tx.amount, currency)}
                            </td>
                            <td className="px-3 py-3 text-muted-foreground">{formatDate(tx.date)}</td>
                            <td className="px-3 py-3">
                              {tx.paymentMethod ? (
                                <span className="flex items-center gap-1.5 text-muted-foreground">
                                  <CreditCard className="h-3.5 w-3.5" /> {tx.paymentMethod}
                                </span>
                              ) : (
                                '—'
                              )}
                            </td>
                            <td className="px-3 py-3">
                              <Badge variant="success">
                                <CheckCircle2 className="mr-1 h-3 w-3" /> {t('paid')}
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
          {/* Résumé des dépenses */}
          <Card>
            <CardHeader>
              <CardTitle>{t('summary')}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {loadingOverview || !overview ? (
                <Skeleton className="h-44 rounded-xl" />
              ) : (
                <>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-red-500/15 text-red-500">
                        <Lock className="h-4 w-4" />
                      </span>
                      <div>
                        <p className="text-sm text-muted-foreground">{t('fixedExpenses')}</p>
                        <p className="font-semibold text-foreground">
                          {formatCurrency(overview.fixed.amount, currency)}
                        </p>
                      </div>
                    </div>
                    <span className="text-sm font-bold text-red-500">
                      {overview.fixed.percentage}%
                    </span>
                  </div>

                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-sky-500/15 text-sky-500">
                        <Shuffle className="h-4 w-4" />
                      </span>
                      <div>
                        <p className="text-sm text-muted-foreground">{t('variableExpenses')}</p>
                        <p className="font-semibold text-foreground">
                          {formatCurrency(overview.variable.amount, currency)}
                        </p>
                      </div>
                    </div>
                    <span className="text-sm font-bold text-sky-500">
                      {overview.variable.percentage}%
                    </span>
                  </div>

                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-muted text-muted-foreground">
                        <LayoutGrid className="h-4 w-4" />
                      </span>
                      <p className="text-sm text-muted-foreground">{t('categoryCount')}</p>
                    </div>
                    <span className="font-semibold text-foreground">{overview.categoryCount}</span>
                  </div>

                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-muted text-muted-foreground">
                        <Hash className="h-4 w-4" />
                      </span>
                      <p className="text-sm text-muted-foreground">{t('expenseCount')}</p>
                    </div>
                    <span className="font-semibold text-foreground">{overview.count}</span>
                  </div>
                </>
              )}
            </CardContent>
          </Card>

          {/* Alertes budgets */}
          <Card>
            <CardHeader className="flex-row items-center justify-between space-y-0">
              <CardTitle>{t('budgetAlerts')}</CardTitle>
              <Link href="/budgets" className="text-xs font-medium text-primary hover:underline">
                {tc('seeAll')}
              </Link>
            </CardHeader>
            <CardContent className="space-y-3">
              {topBudgets.length === 0 && (
                <p className="py-4 text-center text-sm text-muted-foreground">{tb('addObjective')}</p>
              )}
              {topBudgets.map((b) => {
                const m = budgetMeta(b.status);
                return (
                  <div
                    key={b.categoryId}
                    className={cn(
                      'rounded-xl p-3',
                      b.status === 'exceeded'
                        ? 'bg-red-500/5'
                        : b.status === 'ok'
                          ? 'bg-emerald-500/5'
                          : 'bg-amber-500/5',
                    )}
                  >
                    <div className="flex items-center justify-between text-sm">
                      <span className="font-medium text-foreground">{b.categoryName}</span>
                      <span className={cn('font-bold', m.text)}>{Math.round(b.progress)}%</span>
                    </div>
                    <p className="mt-0.5 text-xs text-muted-foreground">
                      {formatNumber(b.spent)} / {formatNumber(b.budget)} {tc('currency')}
                    </p>
                    <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-background/60">
                      <div
                        className={cn('h-full rounded-full', m.bar)}
                        style={{ width: `${Math.min(100, b.progress)}%` }}
                      />
                    </div>
                    <p className={cn('mt-1 text-right text-[11px] font-medium', m.text)}>
                      {tb(m.label)}
                    </p>
                  </div>
                );
              })}
              <Link
                href="/budgets"
                className="flex items-center justify-center gap-1.5 pt-1 text-sm font-medium text-primary hover:underline"
              >
                {t('manageBudgets')} <ArrowRight className="h-4 w-4" />
              </Link>
            </CardContent>
          </Card>

          {/* Insights IA */}
          <Card>
            <CardHeader className="flex-row items-center justify-between space-y-0">
              <CardTitle className="flex items-center gap-2">
                <span className="flex h-6 w-6 items-center justify-center rounded-md bg-primary/10">
                  <Sparkles className="h-3.5 w-3.5 text-primary" />
                </span>
                {t('insights')}
              </CardTitle>
              <Link href="/ai" className="text-xs font-medium text-primary hover:underline">
                {tc('seeAll')}
              </Link>
            </CardHeader>
            <CardContent className="space-y-3">
              {overview && (
                <>
                  <div className="rounded-xl bg-emerald-500/5 p-3.5">
                    <div className="flex items-start gap-3">
                      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-500">
                        <TrendingDown className="h-3.5 w-3.5" />
                      </span>
                      <div>
                        <p className="text-sm text-foreground">
                          {t('insightTrend', {
                            dir: trendDown ? t('insightTrendDown') : t('insightTrendUp'),
                            pct: Math.abs(overview.totalTrend),
                          })}
                        </p>
                        <Link
                          href="/ai"
                          className="mt-0.5 inline-block text-xs font-medium text-primary hover:underline"
                        >
                          {t('insightTrendCta')}
                        </Link>
                      </div>
                    </div>
                  </div>

                  <div className="rounded-xl bg-amber-500/5 p-3.5">
                    <div className="flex items-start gap-3">
                      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-amber-500/15 text-amber-500">
                        <Lightbulb className="h-3.5 w-3.5" />
                      </span>
                      <div>
                        <p className="text-sm text-foreground">
                          {overview.topCategory
                            ? t('insightTop', {
                                cat: overview.topCategory.name,
                                pct: Math.round(overview.topCategory.percentage),
                              })
                            : t('insightBudgetOk')}
                        </p>
                        <Link
                          href="/ai"
                          className="mt-0.5 inline-block text-xs font-medium text-primary hover:underline"
                        >
                          {t('insightTopCta')}
                        </Link>
                      </div>
                    </div>
                  </div>

                  <div className="rounded-xl bg-indigo-500/5 p-3.5">
                    <div className="flex items-start gap-3">
                      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-indigo-500/15 text-indigo-500">
                        <Sparkles className="h-3.5 w-3.5" />
                      </span>
                      <div>
                        <p className="text-sm text-foreground">
                          {worstBudget
                            ? t('insightBudget', {
                                cat: worstBudget.categoryName,
                                pct: Math.round(worstBudget.progress),
                              })
                            : t('insightBudgetOk')}
                        </p>
                        <Link
                          href="/ai"
                          className="mt-0.5 inline-block text-xs font-medium text-primary hover:underline"
                        >
                          {t('insightBudgetCta')}
                        </Link>
                      </div>
                    </div>
                  </div>
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
        kind="EXPENSE"
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
