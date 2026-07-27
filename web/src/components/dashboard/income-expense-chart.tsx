'use client';

import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency, formatNumber } from '@/lib/utils';
import type { TrendPoint } from '@/lib/types';

export function IncomeExpenseChart({
  data,
  currency,
}: {
  data: TrendPoint[];
  currency?: string;
}) {
  const t = useTranslations('dashboard');
  const tc = useTranslations('common');

  return (
    <Card className="flex h-full flex-col">
      <CardHeader className="flex-row items-center justify-between space-y-0">
        <CardTitle>{t('incomeVsExpenses')}</CardTitle>
        <span className="rounded-md border border-border px-2 py-1 text-xs text-muted-foreground">
          {tc('months')}
        </span>
      </CardHeader>
      <CardContent>
        <div className="mb-2 flex items-center gap-4 text-xs">
          <span className="flex items-center gap-1.5 text-muted-foreground">
            <span className="h-2 w-2 rounded-full bg-success" /> {t('income')}
          </span>
          <span className="flex items-center gap-1.5 text-muted-foreground">
            <span className="h-2 w-2 rounded-full bg-destructive" /> {t('expenses')}
          </span>
        </div>
        <div className="h-64 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={data} margin={{ top: 8, right: 8, left: 8, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
              <XAxis
                dataKey="label"
                axisLine={false}
                tickLine={false}
                tick={{ fontSize: 12, fill: 'hsl(var(--muted-foreground))' }}
              />
              <YAxis
                axisLine={false}
                tickLine={false}
                tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
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
                formatter={(value: number) => formatCurrency(value, currency)}
              />
              <Line
                type="monotone"
                dataKey="income"
                stroke="hsl(var(--success))"
                strokeWidth={2.5}
                dot={{ r: 3 }}
                activeDot={{ r: 5 }}
              />
              <Line
                type="monotone"
                dataKey="expenses"
                stroke="hsl(var(--destructive))"
                strokeWidth={2.5}
                dot={{ r: 3 }}
                activeDot={{ r: 5 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </CardContent>
    </Card>
  );
}
