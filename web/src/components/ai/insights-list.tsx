'use client';

import { useQuery } from '@tanstack/react-query';
import { AlertCircle, Lightbulb, Loader2, RefreshCw, Sparkles, Target, TrendingUp } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import type { AiInsight } from '@/lib/types';

const typeIcon = (type: string) => {
  switch (type) {
    case 'SPENDING_ANALYSIS':
    case 'UNUSUAL_SPENDING':
      return TrendingUp;
    case 'BUDGET_SUGGESTION':
      return Target;
    case 'ALERT':
      return AlertCircle;
    default:
      return Lightbulb;
  }
};

const severityStyle: Record<string, { wrap: string; icon: string }> = {
  info: { wrap: 'bg-sky-500/5', icon: 'bg-sky-500/15 text-sky-600 dark:text-sky-400' },
  warning: { wrap: 'bg-amber-500/5', icon: 'bg-amber-500/15 text-amber-600 dark:text-amber-400' },
  critical: { wrap: 'bg-red-500/5', icon: 'bg-red-500/15 text-red-600 dark:text-red-400' },
};

export function InsightsList({ month, year }: { month: number; year: number }) {
  const t = useTranslations('dashboard');
  const ta = useTranslations('ai');

  const { data, isFetching, refetch } = useQuery({
    queryKey: ['ai-insights-generate', month, year],
    queryFn: () =>
      api.post<{ insights: AiInsight[] }>(`/ai/insights/generate?month=${month}&year=${year}`),
    staleTime: 10 * 60 * 1000,
    refetchOnMount: false,
  });

  const insights = (data?.insights ?? []).slice(0, 5);

  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between space-y-0">
        <CardTitle className="flex items-center gap-2">
          <span className="flex h-6 w-6 items-center justify-center rounded-md bg-primary/10">
            <Sparkles className="h-3.5 w-3.5 text-primary" />
          </span>
          {ta('insightsTitle')}
        </CardTitle>
        <Button
          size="icon"
          variant="ghost"
          className="h-8 w-8 text-muted-foreground"
          onClick={() => refetch()}
          disabled={isFetching}
        >
          <RefreshCw className={cn('h-4 w-4', isFetching && 'animate-spin')} />
        </Button>
      </CardHeader>
      <CardContent className="space-y-2.5">
        {isFetching ? (
          <div className="flex flex-col items-center justify-center gap-2 py-12 text-center">
            <Loader2 className="h-6 w-6 animate-spin text-primary" />
            <p className="text-sm text-muted-foreground">{t('analyzing')}</p>
          </div>
        ) : insights.length === 0 ? (
          <p className="py-6 text-center text-sm text-muted-foreground">—</p>
        ) : (
          <ul className="space-y-2.5">
            {insights.map((insight, i) => {
              const Icon = typeIcon(insight.type);
              const style = severityStyle[insight.severity || 'info'];
              return (
                <li key={i} className={cn('flex items-start gap-3 rounded-xl p-3', style.wrap)}>
                  <span
                    className={cn(
                      'flex h-7 w-7 shrink-0 items-center justify-center rounded-full',
                      style.icon,
                    )}
                  >
                    <Icon className="h-3.5 w-3.5" />
                  </span>
                  <p className="text-sm leading-snug text-foreground">
                    <span className="font-semibold">{insight.title}.</span>{' '}
                    <span className="text-muted-foreground">{insight.content}</span>
                  </p>
                </li>
              );
            })}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}
