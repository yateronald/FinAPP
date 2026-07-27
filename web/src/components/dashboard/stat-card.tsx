'use client';

import type { LucideIcon } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { cn, formatCurrency, formatPercent } from '@/lib/utils';

interface StatCardProps {
  label: string;
  amount: number;
  trend?: number;
  trendLabel?: string;
  icon: LucideIcon;
  accent: 'green' | 'red' | 'blue' | 'violet';
  currency?: string;
  series?: number[];
}

const chip: Record<StatCardProps['accent'], string> = {
  green: 'bg-emerald-500',
  red: 'bg-red-500',
  blue: 'bg-sky-500',
  violet: 'bg-indigo-600',
};

function Sparkline({ points, positive }: { points: number[]; positive: boolean }) {
  if (points.length < 2) return null;
  const min = Math.min(...points);
  const max = Math.max(...points);
  const range = max - min || 1;
  const w = 64;
  const h = 24;
  const step = w / (points.length - 1);
  const path = points
    .map((p, i) => `${i === 0 ? 'M' : 'L'}${(i * step).toFixed(1)},${(h - 3 - ((p - min) / range) * (h - 6)).toFixed(1)}`)
    .join(' ');
  return (
    <svg width={w} height={h} className="overflow-visible">
      <path
        d={path}
        fill="none"
        stroke={positive ? '#10b981' : '#ef4444'}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function StatCard({
  label,
  amount,
  trend,
  trendLabel,
  icon: Icon,
  accent,
  currency,
  series,
}: StatCardProps) {
  const positive = (trend ?? 0) >= 0;
  const trendPositiveColor = accent === 'red' ? !positive : positive;

  return (
    <Card>
      <CardContent className="p-5">
        <div className="flex items-center gap-3">
          <div
            className={cn(
              'flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-white shadow-sm',
              chip[accent],
            )}
          >
            <Icon className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm text-muted-foreground">{label}</p>
            <p className="truncate text-xl font-bold tracking-tight text-foreground">
              {formatCurrency(amount, currency)}
            </p>
          </div>
        </div>
        <div className="mt-3 flex items-center justify-between">
          {trend !== undefined ? (
            <p className="text-xs">
              <span
                className={cn(
                  'font-semibold',
                  trendPositiveColor ? 'text-success' : 'text-destructive',
                )}
              >
                {formatPercent(trend)}
              </span>{' '}
              <span className="text-muted-foreground">{trendLabel}</span>
            </p>
          ) : (
            <span />
          )}
          {series && <Sparkline points={series} positive={trendPositiveColor} />}
        </div>
      </CardContent>
    </Card>
  );
}
