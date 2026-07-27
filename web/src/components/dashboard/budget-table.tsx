'use client';

import Link from 'next/link';
import { Plus } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { cn, formatNumber } from '@/lib/utils';
import type { BudgetStatus } from '@/lib/types';

export function BudgetTable({ budgets }: { budgets: BudgetStatus[] }) {
  const t = useTranslations('dashboard');
  const tb = useTranslations('budget');
  const tc = useTranslations('common');

  const meta = (s: BudgetStatus['status']) => {
    if (s === 'exceeded') return { badge: 'destructive' as const, label: tb('exceeded'), bar: 'bg-destructive' };
    if (s === 'danger' || s === 'warning')
      return { badge: 'warning' as const, label: tb('warning'), bar: 'bg-amber-500' };
    return { badge: 'success' as const, label: tb('onTrack'), bar: 'bg-emerald-500' };
  };

  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between space-y-0">
        <CardTitle>{t('budgetObjectives')}</CardTitle>
        <Link href="/budgets" className="text-sm font-medium text-primary hover:underline">
          {t('manage')}
        </Link>
      </CardHeader>
      <CardContent>
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs text-muted-foreground">
              <th className="pb-2 font-medium">{tc('category')}</th>
              <th className="pb-2 text-right font-medium">{tb('monthlyColumn')}</th>
              <th className="pb-2 text-right font-medium">{tb('spent')}</th>
              <th className="pb-2 pl-4 font-medium">{tb('progress')}</th>
              <th className="pb-2 pl-2 font-medium">{tb('status')}</th>
            </tr>
          </thead>
          <tbody>
            {budgets.map((b) => {
              const m = meta(b.status);
              return (
                <tr key={b.categoryId} className="border-t border-border/60">
                  <td className="py-2.5 font-medium text-foreground">{b.categoryName}</td>
                  <td className="py-2.5 text-right text-muted-foreground">
                    {formatNumber(b.budget)} {tc('currency')}
                  </td>
                  <td className="py-2.5 text-right text-foreground">
                    {formatNumber(b.spent)} {tc('currency')}
                  </td>
                  <td className="py-2.5 pl-4">
                    <span className="flex items-center gap-2">
                      <span className="h-1.5 w-14 overflow-hidden rounded-full bg-secondary">
                        <span
                          className={cn('block h-full rounded-full', m.bar)}
                          style={{ width: `${Math.min(100, b.progress)}%` }}
                        />
                      </span>
                      <span className="text-xs text-muted-foreground">{Math.round(b.progress)}%</span>
                    </span>
                  </td>
                  <td className="py-2.5 pl-2">
                    <Badge variant={m.badge}>{m.label}</Badge>
                  </td>
                </tr>
              );
            })}
            {budgets.length === 0 && (
              <tr>
                <td colSpan={5} className="py-8 text-center text-muted-foreground">
                  {tb('addObjective')}
                </td>
              </tr>
            )}
          </tbody>
        </table>
        <Link
          href="/budgets"
          className="mt-3 flex items-center justify-center gap-1 text-sm font-medium text-primary hover:underline"
        >
          <Plus className="h-4 w-4" /> {tb('addObjective')}
        </Link>
      </CardContent>
    </Card>
  );
}
