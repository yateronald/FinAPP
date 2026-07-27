'use client';

import { useMemo, useState } from 'react';
import { ArrowLeftRight } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { PageHeader } from '@/components/page-header';
import { EmptyState } from '@/components/empty-state';
import { Card, CardContent } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { ConfirmDialog } from '@/components/confirm-dialog';
import { FilterBar, type FilterState } from '@/components/transactions/filter-bar';
import { TransactionRow } from '@/components/transactions/transaction-row';
import {
  TransactionFormDialog,
  type TransactionFormValues,
} from '@/components/transactions/transaction-form-dialog';
import { useCategories } from '@/hooks/use-categories';
import {
  useExpenseList,
  useExpenseMutations,
  useIncomeList,
  useIncomeMutations,
} from '@/hooks/use-transactions';
import { useAuthStore } from '@/store/auth';
import { formatDate } from '@/lib/utils';
import type { Transaction } from '@/lib/types';

type Kind = 'INCOME' | 'EXPENSE';
type Row = Transaction & { _kind: Kind };

const emptyFilters: FilterState = { search: '', categoryId: '', from: '', to: '' };

export default function TransactionsPage() {
  const t = useTranslations('transactions');
  const currency = useAuthStore((s) => s.user?.settings?.currency) || 'XOF';

  const [tab, setTab] = useState<'all' | 'INCOME' | 'EXPENSE'>('all');
  const [filters, setFilters] = useState<FilterState>(emptyFilters);
  const [editing, setEditing] = useState<Row | null>(null);
  const [deleting, setDeleting] = useState<Row | null>(null);

  const { data: categories } = useCategories();
  const wantIncome = tab === 'all' || tab === 'INCOME';
  const wantExpense = tab === 'all' || tab === 'EXPENSE';

  const income = useIncomeList({ ...filters, limit: 100, page: 1 });
  const expenses = useExpenseList({ ...filters, limit: 100, page: 1 });
  const incomeMut = useIncomeMutations();
  const expenseMut = useExpenseMutations();

  const rows = useMemo<Row[]>(() => {
    const list: Row[] = [];
    if (wantIncome) (income.data?.items ?? []).forEach((i) => list.push({ ...i, _kind: 'INCOME' }));
    if (wantExpense)
      (expenses.data?.items ?? []).forEach((e) => list.push({ ...e, _kind: 'EXPENSE' }));
    return list.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  }, [income.data, expenses.data, wantIncome, wantExpense]);

  const isLoading = (wantIncome && income.isLoading) || (wantExpense && expenses.isLoading);

  // Group by date for a clean timeline
  const grouped = useMemo(() => {
    const map = new Map<string, Row[]>();
    for (const r of rows) {
      const key = r.date.slice(0, 10);
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(r);
    }
    return Array.from(map.entries());
  }, [rows]);

  const submitEdit = (values: TransactionFormValues) => {
    if (!editing) return;
    const base = {
      id: editing.id,
      title: values.title,
      categoryId: values.categoryId,
      amount: Number(values.amount),
      date: new Date(values.date).toISOString(),
      description: values.description || undefined,
    };
    const done = () => {
      toast.success(t('saved'));
      setEditing(null);
    };
    if (editing._kind === 'INCOME') {
      incomeMut.update.mutate(
        { ...base, isRecurring: values.isRecurring ?? false },
        { onSuccess: done, onError: (e: any) => toast.error(e?.message) },
      );
    } else {
      expenseMut.update.mutate(
        {
          ...base,
          paymentMethod: values.paymentMethod || undefined,
          tags: values.tags
            ? values.tags.split(',').map((s) => s.trim()).filter(Boolean)
            : undefined,
        },
        { onSuccess: done, onError: (e: any) => toast.error(e?.message) },
      );
    }
  };

  const confirmDelete = () => {
    if (!deleting) return;
    const mut = deleting._kind === 'INCOME' ? incomeMut.remove : expenseMut.remove;
    mut.mutate(deleting.id, {
      onSuccess: () => {
        toast.success(t('saved'));
        setDeleting(null);
      },
      onError: (e: any) => toast.error(e?.message),
    });
  };

  return (
    <div className="space-y-6">
      <PageHeader title={t('title')} description={t('subtitle')} />

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <Tabs value={tab} onValueChange={(v) => setTab(v as typeof tab)}>
          <TabsList>
            <TabsTrigger value="all">{t('all')}</TabsTrigger>
            <TabsTrigger value="INCOME">{t('income')}</TabsTrigger>
            <TabsTrigger value="EXPENSE">{t('expenses')}</TabsTrigger>
          </TabsList>
        </Tabs>
      </div>

      <FilterBar filters={filters} onChange={setFilters} categories={categories ?? []} />

      <Card>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="space-y-2 p-4">
              {Array.from({ length: 6 }).map((_, i) => (
                <Skeleton key={i} className="h-14 rounded-lg" />
              ))}
            </div>
          ) : rows.length === 0 ? (
            <EmptyState icon={ArrowLeftRight} title={t('empty')} description={t('emptyDesc')} />
          ) : (
            <div>
              {grouped.map(([date, dayRows]) => (
                <div key={date}>
                  <p className="border-b border-border bg-muted/30 px-4 py-1.5 text-xs font-medium text-muted-foreground">
                    {formatDate(date)}
                  </p>
                  <div className="divide-y divide-border">
                    {dayRows.map((r) => (
                      <TransactionRow
                        key={`${r._kind}-${r.id}`}
                        tx={r}
                        kind={r._kind}
                        currency={currency}
                        onEdit={() => setEditing(r)}
                        onDelete={() => setDeleting(r)}
                      />
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {editing && (
        <TransactionFormDialog
          open={!!editing}
          onOpenChange={(o) => !o && setEditing(null)}
          kind={editing._kind}
          editing={editing}
          onSubmit={submitEdit}
          saving={incomeMut.update.isPending || expenseMut.update.isPending}
        />
      )}
      <ConfirmDialog
        open={!!deleting}
        onOpenChange={(o) => !o && setDeleting(null)}
        title={t('deleteConfirm')}
        description={t('deleteDesc')}
        onConfirm={confirmDelete}
        loading={incomeMut.remove.isPending || expenseMut.remove.isPending}
      />
    </div>
  );
}
