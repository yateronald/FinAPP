'use client';

import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts';
import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency } from '@/lib/utils';
import type { ExpenseSlice } from '@/lib/types';

export function DistributionDonut({
  title,
  data,
  currency,
  periodLabel,
}: {
  title: string;
  data: ExpenseSlice[];
  currency?: string;
  periodLabel?: string;
}) {
  const tc = useTranslations('common');
  const total = data.reduce((sum, d) => sum + d.amount, 0);

  return (
    <Card className="flex h-full flex-col">
      <CardHeader className="flex-row items-center justify-between space-y-0">
        <CardTitle>{title}</CardTitle>
        <span className="rounded-md border border-border px-2 py-1 text-xs text-muted-foreground">
          {periodLabel ?? tc('thisMonth')}
        </span>
      </CardHeader>
      <CardContent className="flex-1">
        {data.length === 0 ? (
          <p className="py-16 text-center text-sm text-muted-foreground">{tc('noData')}</p>
        ) : (
          <div className="flex h-full flex-col items-center gap-4">
            <div className="relative h-44 w-44 shrink-0">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={data}
                    dataKey="amount"
                    nameKey="name"
                    innerRadius={56}
                    outerRadius={82}
                    paddingAngle={2}
                    strokeWidth={0}
                  >
                    {data.map((slice) => (
                      <Cell key={slice.categoryId} fill={slice.color || '#94a3b8'} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      borderRadius: 12,
                      border: '1px solid hsl(var(--border))',
                      background: 'hsl(var(--card))',
                      fontSize: 12,
                    }}
                    formatter={(value: number, name: string) => [
                      formatCurrency(value, currency),
                      name,
                    ]}
                  />
                </PieChart>
              </ResponsiveContainer>
              <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                <span className="text-base font-bold leading-tight text-foreground">
                  {formatCurrency(total, currency)}
                </span>
              </div>
            </div>
            <ul className="grid w-full flex-1 content-start gap-2">
              {data.slice(0, 6).map((slice) => (
                <li key={slice.categoryId} className="flex items-center justify-between text-sm">
                  <span className="flex items-center gap-2 text-muted-foreground">
                    <span
                      className="h-2.5 w-2.5 rounded-full"
                      style={{ backgroundColor: slice.color || '#94a3b8' }}
                    />
                    {slice.name}{' '}
                    <span className="text-xs text-muted-foreground/70">({slice.percentage}%)</span>
                  </span>
                  <span className="font-medium text-foreground">
                    {formatCurrency(slice.amount, currency)}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
