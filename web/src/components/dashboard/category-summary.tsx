'use client';

import { AlertTriangle } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { categoryIcon } from '@/lib/category-icons';
import { cn, formatNumber } from '@/lib/utils';
import type { BudgetStatus, ExpenseSlice } from '@/lib/types';

export function CategorySummary({
  distribution,
  budgets,
  periodLabel,
}: {
  distribution: ExpenseSlice[];
  budgets: BudgetStatus[];
  periodLabel?: string;
}) {
  const t = useTranslations('dashboard');
  const tb = useTranslations('budget');
  const tc = useTranslations('common');

  const budgetMap = new Map(budgets.map((b) => [b.categoryId, b]));
  const rows = distribution.slice(0, 6).map((d) => {
    const b = budgetMap.get(d.categoryId);
    const progress = b ? b.progress : null;
    return { ...d, objective: b?.budget ?? null, progress };
  });

  const totalSpent = rows.reduce((s, r) => s + r.amount, 0);
  const totalObjective = rows.reduce((s, r) => s + (r.objective ?? 0), 0);
  const totalProgress = totalObjective > 0 ? (totalSpent / totalObjective) * 100 : null;

  const barColor = (p: number | null) => {
    if (p === null) return 'bg-muted-foreground/30';
    if (p >= 100) return 'bg-destructive';
    if (p >= 80) return 'bg-amber-500';
    return 'bg-emerald-500';
  };

  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between space-y-0">
        <CardTitle>
          {t('categorySummary2')}{' '}
          <span className="text-sm font-normal text-muted-foreground">{t('expensesSuffix')}</span>
        </CardTitle>
        <span className="rounded-md border border-border px-2 py-1 text-xs text-muted-foreground">
          {periodLabel ?? tc('thisMonth')}
        </span>
      </CardHeader>
      <CardContent>
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs text-muted-foreground">
              <th className="pb-2 font-medium">{tc('category')}</th>
              <th className="pb-2 text-right font-medium">{tb('spent')}</th>
              <th className="pb-2 text-right font-medium">{tb('objective')}</th>
              <th className="pb-2 pl-4 font-medium">{tb('progress')}</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => {
              const Icon = categoryIcon(r.icon);
              return (
                <tr key={r.categoryId} className="border-t border-border/60">
                  <td className="py-2.5">
                    <span className="flex items-center gap-2">
                      <span
                        className="flex h-6 w-6 items-center justify-center rounded-md"
                        style={{ backgroundColor: `${r.color}1F`, color: r.color }}
                      >
                        <Icon className="h-3.5 w-3.5" />
                      </span>
                      <span className="font-medium text-foreground">{r.name}</span>
                    </span>
                  </td>
                  <td className="py-2.5 text-right text-foreground">{formatNumber(r.amount)}</td>
                  <td className="py-2.5 text-right text-muted-foreground">
                    {r.objective !== null ? formatNumber(r.objective) : '—'}
                  </td>
                  <td className="py-2.5 pl-4">
                    <span className="flex items-center gap-2">
                      <span className="h-1.5 w-16 overflow-hidden rounded-full bg-secondary">
                        <span
                          className={cn('block h-full rounded-full', barColor(r.progress))}
                          style={{ width: `${Math.min(100, r.progress ?? 0)}%` }}
                        />
                      </span>
                      <span
                        className={cn(
                          'flex items-center gap-0.5 text-xs font-medium',
                          r.progress !== null && r.progress >= 100
                            ? 'text-destructive'
                            : 'text-muted-foreground',
                        )}
                      >
                        {r.progress !== null ? `${Math.round(r.progress)}%` : '—'}
                        {r.progress !== null && r.progress >= 100 && (
                          <AlertTriangle className="h-3 w-3 text-amber-500" />
                        )}
                      </span>
                    </span>
                  </td>
                </tr>
              );
            })}
          </tbody>
          <tfoot>
            <tr className="border-t border-border font-semibold text-foreground">
              <td className="pt-2.5">{t('total')}</td>
              <td className="pt-2.5 text-right">{formatNumber(totalSpent)}</td>
              <td className="pt-2.5 text-right">
                {totalObjective > 0 ? formatNumber(totalObjective) : '—'}
              </td>
              <td className="pt-2.5 pl-4 text-xs">
                {totalProgress !== null ? `${Math.round(totalProgress)}%` : '—'}
              </td>
            </tr>
          </tfoot>
        </table>
      </CardContent>
    </Card>
  );
}
