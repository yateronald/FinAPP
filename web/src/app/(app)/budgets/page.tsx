'use client';

import { useState } from 'react';
import { MoreVertical, Pencil, Plus, Target, Trash2 } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { PageHeader } from '@/components/page-header';
import { EmptyState } from '@/components/empty-state';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ConfirmDialog } from '@/components/confirm-dialog';
import { BudgetFormDialog } from '@/components/budgets/budget-form-dialog';
import { useBudgets, useBudgetMutations } from '@/hooks/use-budgets';
import { useAnchor } from '@/store/period';
import { useAuthStore } from '@/store/auth';
import { categoryIcon } from '@/lib/category-icons';
import { cn, formatCurrency } from '@/lib/utils';
import type { BudgetStatus } from '@/lib/types';

const statusMeta = (s: BudgetStatus['status']) => {
  if (s === 'exceeded') return { badge: 'destructive' as const, bar: 'bg-destructive', key: 'exceeded' };
  if (s === 'danger' || s === 'warning')
    return { badge: 'warning' as const, bar: 'bg-amber-500', key: 'warning' };
  return { badge: 'success' as const, bar: 'bg-emerald-500', key: 'onTrack' };
};

export default function BudgetsPage() {
  const t = useTranslations('budgets');
  const tb = useTranslations('budget');
  const tc = useTranslations('common');
  const { month, year } = useAnchor();
  const currency = useAuthStore((s) => s.user?.settings?.currency) || 'XOF';

  const { data: budgets, isLoading } = useBudgets(month, year);
  const { upsert, remove } = useBudgetMutations();

  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<BudgetStatus | null>(null);
  const [deleting, setDeleting] = useState<BudgetStatus | null>(null);

  const list = budgets ?? [];
  const totalBudget = list.reduce((s, b) => s + b.budget, 0);
  const totalSpent = list.reduce((s, b) => s + b.spent, 0);
  const remaining = totalBudget - totalSpent;

  const submit = (values: { categoryId: string; amount: number }) => {
    upsert.mutate(
      { ...values, month, year },
      {
        onSuccess: () => {
          toast.success(t('created'));
          setFormOpen(false);
          setEditing(null);
        },
        onError: (e: any) => toast.error(e?.message),
      },
    );
  };

  return (
    <div className="space-y-6">
      <PageHeader title={t('title')} description={t('subtitle')}>
        <Button
          onClick={() => {
            setEditing(null);
            setFormOpen(true);
          }}
        >
          <Plus className="h-4 w-4" /> {t('add')}
        </Button>
      </PageHeader>

      {/* Summary */}
      <div className="grid gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="p-5">
            <p className="text-sm text-muted-foreground">{t('totalBudget')}</p>
            <p className="mt-1 text-xl font-bold text-foreground">
              {formatCurrency(totalBudget, currency)}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-5">
            <p className="text-sm text-muted-foreground">{t('totalSpent')}</p>
            <p className="mt-1 text-xl font-bold text-foreground">
              {formatCurrency(totalSpent, currency)}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-5">
            <p className="text-sm text-muted-foreground">{t('remaining')}</p>
            <p
              className={cn(
                'mt-1 text-xl font-bold',
                remaining < 0 ? 'text-destructive' : 'text-success',
              )}
            >
              {formatCurrency(remaining, currency)}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Budget cards */}
      {isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-36 rounded-xl" />
          ))}
        </div>
      ) : list.length === 0 ? (
        <Card>
          <CardContent className="p-0">
            <EmptyState
              icon={Target}
              title={t('noBudgets')}
              description={t('noBudgetsDesc')}
              action={
                <Button
                  variant="outline"
                  onClick={() => {
                    setEditing(null);
                    setFormOpen(true);
                  }}
                >
                  <Plus className="h-4 w-4" /> {t('add')}
                </Button>
              }
            />
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {list.map((b) => {
            const meta = statusMeta(b.status);
            const Icon = categoryIcon(b.icon);
            const color = b.color || '#6366f1';
            return (
              <Card key={b.categoryId}>
                <CardContent className="p-5">
                  <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3">
                      <span
                        className="flex h-10 w-10 items-center justify-center rounded-xl"
                        style={{ backgroundColor: `${color}26`, color }}
                      >
                        <Icon className="h-5 w-5" />
                      </span>
                      <div>
                        <p className="font-medium text-foreground">{b.categoryName}</p>
                        <Badge variant={meta.badge} className="mt-0.5">
                          {tb(meta.key)}
                        </Badge>
                      </div>
                    </div>
                    <DropdownMenu>
                      <DropdownMenuTrigger className="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground focus:outline-none">
                        <MoreVertical className="h-4 w-4" />
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem
                          onClick={() => {
                            setEditing(b);
                            setFormOpen(true);
                          }}
                        >
                          <Pencil /> {tc('edit')}
                        </DropdownMenuItem>
                        <DropdownMenuItem destructive onClick={() => setDeleting(b)}>
                          <Trash2 /> {tc('delete')}
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>

                  <div className="mt-4 space-y-1.5">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">
                        {formatCurrency(b.spent, currency)}
                      </span>
                      <span className="font-medium text-foreground">
                        {formatCurrency(b.budget, currency)}
                      </span>
                    </div>
                    <div className="h-2 w-full overflow-hidden rounded-full bg-secondary">
                      <div
                        className={cn('h-full rounded-full transition-all', meta.bar)}
                        style={{ width: `${Math.min(100, b.progress)}%` }}
                      />
                    </div>
                    <div className="flex items-center justify-between text-xs">
                      <span className="text-muted-foreground">{Math.round(b.progress)}%</span>
                      <span
                        className={cn(
                          'font-medium',
                          b.remaining < 0 ? 'text-destructive' : 'text-muted-foreground',
                        )}
                      >
                        {formatCurrency(b.remaining, currency)}
                      </span>
                    </div>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      <BudgetFormDialog
        open={formOpen}
        onOpenChange={(o) => {
          setFormOpen(o);
          if (!o) setEditing(null);
        }}
        presetCategoryId={editing?.categoryId}
        presetAmount={editing?.budget}
        lockCategory={!!editing}
        onSubmit={submit}
        saving={upsert.isPending}
      />
      <ConfirmDialog
        open={!!deleting}
        onOpenChange={(o) => !o && setDeleting(null)}
        title={t('deleteConfirm')}
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
