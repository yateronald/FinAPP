'use client';

import Link from 'next/link';
import { AlertTriangle, ArrowRight, CheckCircle2, Flame } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { cn, formatCurrency } from '@/lib/utils';
import type { BudgetStatus } from '@/lib/types';

export function AlertsGoals({
  budgets,
  currency,
  periodLabel,
}: {
  budgets: BudgetStatus[];
  currency?: string;
  periodLabel?: string;
}) {
  const t = useTranslations('dashboard');
  const tb = useTranslations('budget');
  const tc = useTranslations('common');

  // Most interesting first: exceeded > danger/warning > ok
  const sorted = [...budgets].sort((a, b) => b.progress - a.progress).slice(0, 3);

  const meta = (s: BudgetStatus['status']) => {
    if (s === 'exceeded')
      return {
        icon: Flame,
        label: tb('goalReached'),
        wrap: 'bg-orange-500/10 border-orange-500/20',
        text: 'text-orange-600 dark:text-orange-400',
        bar: 'bg-orange-500',
      };
    if (s === 'danger' || s === 'warning')
      return {
        icon: AlertTriangle,
        label: tb('warning'),
        wrap: 'bg-amber-500/10 border-amber-500/20',
        text: 'text-amber-600 dark:text-amber-400',
        bar: 'bg-amber-500',
      };
    return {
      icon: CheckCircle2,
      label: tb('onTrack'),
      wrap: 'bg-emerald-500/10 border-emerald-500/20',
      text: 'text-emerald-600 dark:text-emerald-400',
      bar: 'bg-emerald-500',
    };
  };

  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between space-y-0">
        <CardTitle>{t('alertsGoals')}</CardTitle>
        <span className="rounded-md border border-border px-2 py-1 text-xs text-muted-foreground">
          {periodLabel ?? tc('thisMonth')}
        </span>
      </CardHeader>
      <CardContent className="space-y-3">
        {sorted.length === 0 && (
          <p className="py-8 text-center text-sm text-muted-foreground">{tb('addObjective')}</p>
        )}
        {sorted.map((b) => {
          const m = meta(b.status);
          const Icon = m.icon;
          return (
            <div key={b.categoryId} className={cn('rounded-xl border p-3', m.wrap)}>
              <div className="flex items-start gap-2.5">
                <Icon className={cn('mt-0.5 h-4 w-4 shrink-0', m.text)} />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <p className={cn('text-xs font-semibold', m.text)}>{m.label}</p>
                    <p className={cn('text-xs font-bold', m.text)}>{Math.round(b.progress)}%</p>
                  </div>
                  <p className="mt-0.5 text-sm font-semibold text-foreground">{b.categoryName}</p>
                  <p className="text-xs text-muted-foreground">
                    {formatCurrency(b.spent, currency)} / {formatCurrency(b.budget, currency)}
                  </p>
                  <p className="text-[11px] text-muted-foreground">
                    {tb('percentUsed', { percent: Math.round(b.progress) })}
                  </p>
                  <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-background/60">
                    <div
                      className={cn('h-full rounded-full', m.bar)}
                      style={{ width: `${Math.min(100, b.progress)}%` }}
                    />
                  </div>
                </div>
              </div>
            </div>
          );
        })}
        <Link
          href="/budgets"
          className="flex items-center justify-center gap-1.5 pt-1 text-sm font-medium text-primary hover:underline"
        >
          {t('seeAllGoals')} <ArrowRight className="h-4 w-4" />
        </Link>
      </CardContent>
    </Card>
  );
}
