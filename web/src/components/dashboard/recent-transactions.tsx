'use client';

import Link from 'next/link';
import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { categoryIcon } from '@/lib/category-icons';
import { cn, formatCurrency, formatDate } from '@/lib/utils';
import type { RecentTransaction } from '@/lib/types';

export function RecentTransactions({
  items,
  currency,
}: {
  items: RecentTransaction[];
  currency?: string;
}) {
  const t = useTranslations('dashboard');
  const tc = useTranslations('common');

  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between space-y-0">
        <CardTitle>{t('recentTransactions')}</CardTitle>
        <Link href="/transactions" className="text-sm font-medium text-primary hover:underline">
          {tc('seeAll')}
        </Link>
      </CardHeader>
      <CardContent className="space-y-0.5">
        {items.length === 0 && (
          <p className="py-6 text-center text-sm text-muted-foreground">{tc('noData')}</p>
        )}
        {items.slice(0, 6).map((tx) => {
          const income = tx.type === 'INCOME';
          const Icon = categoryIcon(tx.icon);
          const color = tx.color || (income ? '#22c55e' : '#ef4444');
          return (
            <div
              key={`${tx.type}-${tx.id}`}
              className="flex items-center justify-between rounded-lg px-1.5 py-2 transition-colors hover:bg-muted/50"
            >
              <div className="flex min-w-0 items-center gap-3">
                <span
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
                  style={{ backgroundColor: `${color}1F`, color }}
                >
                  <Icon className="h-4 w-4" />
                </span>
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-foreground">{tx.title}</p>
                  <p className="truncate text-xs text-muted-foreground">{tx.category}</p>
                </div>
              </div>
              <div className="shrink-0 text-right">
                <p
                  className={cn(
                    'text-sm font-semibold',
                    income ? 'text-success' : 'text-destructive',
                  )}
                >
                  {income ? '+' : '-'}
                  {formatCurrency(tx.amount, currency)}
                </p>
                <p className="text-xs text-muted-foreground">{formatDate(tx.date)}</p>
              </div>
            </div>
          );
        })}
      </CardContent>
    </Card>
  );
}
