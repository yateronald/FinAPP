'use client';

import {
  Bar,
  BarChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency, formatNumber } from '@/lib/utils';
import type { DailyExpenses } from '@/lib/types';

export function DailyExpensesChart({
  data,
  currency,
  periodLabel,
}: {
  data: DailyExpenses;
  currency?: string;
  periodLabel?: string;
}) {
  const t = useTranslations('dashboard');
  const tc = useTranslations('common');

  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between space-y-0">
        <CardTitle>{t('dailyExpenses')}</CardTitle>
        <span className="rounded-md border border-border px-2 py-1 text-xs text-muted-foreground">
          {periodLabel ?? tc('thisMonth')}
        </span>
      </CardHeader>
      <CardContent>
        <div className="h-44 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data.days} margin={{ top: 8, right: 4, left: 0, bottom: 0 }}>
              <XAxis
                dataKey="day"
                axisLine={false}
                tickLine={false}
                interval={4}
                tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
              />
              <YAxis
                axisLine={false}
                tickLine={false}
                tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }}
                tickFormatter={(v) => formatNumber(v)}
                width={44}
              />
              <Tooltip
                cursor={{ fill: 'hsl(var(--muted))' }}
                contentStyle={{
                  borderRadius: 12,
                  border: '1px solid hsl(var(--border))',
                  background: 'hsl(var(--card))',
                  fontSize: 12,
                }}
                formatter={(value: number) => [formatCurrency(value, currency), '']}
                labelFormatter={(day) => `${day}`}
              />
              <Bar dataKey="amount" fill="#ef4444" radius={[3, 3, 0, 0]} maxBarSize={10} />
              {data.dailyObjective !== null && (
                <ReferenceLine
                  y={data.dailyObjective}
                  stroke="hsl(var(--muted-foreground))"
                  strokeDasharray="4 4"
                />
              )}
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="mt-3 flex items-center gap-4 text-[11px] text-muted-foreground">
          <span className="flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-sm bg-red-500" /> {t('expenses')}
          </span>
          {data.dailyObjective !== null && (
            <span className="flex items-center gap-1.5">
              <span className="h-0 w-4 border-t border-dashed border-muted-foreground" />{' '}
              {t('dailyObjective')}
            </span>
          )}
        </div>
        <div className="mt-2 space-y-0.5 text-sm">
          {data.dailyObjective !== null && (
            <p className="text-muted-foreground">
              {t('dailyObjectiveAvg')} :{' '}
              <span className="font-semibold text-foreground">
                {formatCurrency(data.dailyObjective, currency)}
              </span>
            </p>
          )}
          <p className="text-muted-foreground">
            {t('avgSpent')} :{' '}
            <span className="font-semibold text-foreground">
              {formatCurrency(data.averageSpent, currency)}
            </span>
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
