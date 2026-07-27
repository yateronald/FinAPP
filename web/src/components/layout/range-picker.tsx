'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { Calendar, ChevronDown, ChevronLeft, ChevronRight } from 'lucide-react';
import { useLocale, useTranslations } from 'next-intl';
import { Button } from '@/components/ui/button';
import { RangeCalendar } from '@/components/ui/range-calendar';
import { rangeLabel, type RangeSelection, type RangeType } from '@/lib/period';
import { cn, monthShort } from '@/lib/utils';

const TYPES: RangeType[] = ['month', 'months', 'quarter', 'year', 'custom'];
const COUNTS = [2, 3, 6, 12];

export function RangePicker({
  value,
  onChange,
  className,
  align = 'end',
}: {
  value: RangeSelection;
  onChange: (range: RangeSelection) => void;
  className?: string;
  align?: 'start' | 'end';
}) {
  const locale = useLocale();
  const t = useTranslations('dashboard');
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // local editing state
  const [type, setType] = useState<RangeType>(value.type);
  const [viewYear, setViewYear] = useState(value.year);
  const [count, setCount] = useState(value.count ?? 3);
  const [from, setFrom] = useState(value.from ?? '');
  const [to, setTo] = useState(value.to ?? '');

  useEffect(() => {
    if (open) {
      setType(value.type);
      setViewYear(value.year);
      setCount(value.count ?? 3);
      setFrom(value.from ?? '');
      setTo(value.to ?? '');
    }
  }, [open, value]);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  const years = useMemo(
    () => Array.from({ length: 9 }, (_, i) => viewYear - 4 + i),
    [viewYear],
  );

  const commit = (r: RangeSelection) => {
    onChange(r);
    setOpen(false);
  };

  const typeLabel = (ty: RangeType) =>
    ({
      month: t('rangeMonth'),
      months: t('rangeMonths'),
      quarter: t('rangeQuarter'),
      year: t('rangeYear'),
      custom: t('rangeCustom'),
    })[ty];

  return (
    <div ref={ref} className={cn('relative', className)}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="flex h-10 w-full items-center gap-2 rounded-lg border border-border bg-card px-3 text-sm font-medium text-foreground transition-colors hover:bg-accent"
      >
        <Calendar className="h-4 w-4 shrink-0 text-muted-foreground" />
        <span className="flex-1 truncate text-left">{rangeLabel(value, locale)}</span>
        <ChevronDown className="h-4 w-4 shrink-0 text-muted-foreground" />
      </button>

      {open && (
        <div
          className={cn(
            'absolute top-12 z-50 w-[340px] max-w-[calc(100vw-2rem)] rounded-xl border border-border bg-popover p-3 shadow-xl',
            align === 'end' ? 'right-0' : 'left-0',
          )}
        >
          {/* Type segmented control */}
          <div className="mb-3 flex gap-0.5 rounded-lg bg-muted p-1">
            {TYPES.map((ty) => (
              <button
                key={ty}
                type="button"
                onClick={() => setType(ty)}
                className={cn(
                  'flex-1 whitespace-nowrap rounded-md px-1.5 py-1.5 text-[11px] font-medium transition-colors',
                  type === ty
                    ? 'bg-card text-foreground shadow-sm'
                    : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {typeLabel(ty)}
              </button>
            ))}
          </div>

          {/* Year stepper (shared by month/months/quarter/year) */}
          {type !== 'custom' && (
            <div className="mb-3 flex items-center justify-between">
              <button
                type="button"
                onClick={() => setViewYear((y) => y - 1)}
                className="rounded-md p-1 text-muted-foreground hover:bg-accent hover:text-foreground"
              >
                <ChevronLeft className="h-4 w-4" />
              </button>
              <span className="text-sm font-semibold text-foreground">{viewYear}</span>
              <button
                type="button"
                onClick={() => setViewYear((y) => y + 1)}
                className="rounded-md p-1 text-muted-foreground hover:bg-accent hover:text-foreground"
              >
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>
          )}

          {/* MONTH */}
          {type === 'month' && (
            <MonthGrid
              locale={locale}
              selectedMonth={value.type === 'month' && value.year === viewYear ? value.month : undefined}
              onPick={(m) => commit({ type: 'month', year: viewYear, month: m })}
            />
          )}

          {/* MULTI-MONTH */}
          {type === 'months' && (
            <div className="space-y-3">
              <div>
                <p className="mb-1.5 text-xs text-muted-foreground">{t('monthCount')}</p>
                <div className="grid grid-cols-4 gap-1">
                  {COUNTS.map((c) => (
                    <button
                      key={c}
                      type="button"
                      onClick={() => setCount(c)}
                      className={cn(
                        'rounded-md py-1.5 text-sm font-medium transition-colors',
                        count === c
                          ? 'bg-primary text-primary-foreground'
                          : 'bg-muted text-foreground hover:bg-accent',
                      )}
                    >
                      {c}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <p className="mb-1.5 text-xs text-muted-foreground">{t('endMonth')}</p>
                <MonthGrid
                  locale={locale}
                  selectedMonth={value.type === 'months' && value.year === viewYear ? value.month : undefined}
                  onPick={(m) => commit({ type: 'months', year: viewYear, month: m, count })}
                />
              </div>
            </div>
          )}

          {/* QUARTER */}
          {type === 'quarter' && (
            <div className="grid grid-cols-2 gap-1.5">
              {[1, 2, 3, 4].map((q) => (
                <button
                  key={q}
                  type="button"
                  onClick={() => commit({ type: 'quarter', year: viewYear, quarter: q })}
                  className={cn(
                    'rounded-lg py-2.5 text-sm font-medium transition-colors',
                    value.type === 'quarter' && value.quarter === q && value.year === viewYear
                      ? 'bg-primary text-primary-foreground'
                      : 'bg-muted text-foreground hover:bg-accent',
                  )}
                >
                  T{q}
                </button>
              ))}
            </div>
          )}

          {/* YEAR */}
          {type === 'year' && (
            <div className="grid grid-cols-3 gap-1.5">
              {years.map((y) => (
                <button
                  key={y}
                  type="button"
                  onClick={() => commit({ type: 'year', year: y })}
                  className={cn(
                    'rounded-lg py-2 text-sm font-medium transition-colors',
                    value.type === 'year' && value.year === y
                      ? 'bg-primary text-primary-foreground'
                      : 'bg-muted text-foreground hover:bg-accent',
                  )}
                >
                  {y}
                </button>
              ))}
            </div>
          )}

          {/* CUSTOM */}
          {type === 'custom' && (
            <div className="space-y-3">
              <RangeCalendar
                from={from}
                to={to}
                onChange={(f, tt) => {
                  setFrom(f);
                  setTo(tt);
                }}
              />
              <div className="flex items-center justify-between rounded-lg bg-muted px-3 py-2 text-xs">
                <span className={cn('font-medium', from ? 'text-foreground' : 'text-muted-foreground')}>
                  {from || t('from')}
                </span>
                <span className="text-muted-foreground">→</span>
                <span className={cn('font-medium', to ? 'text-foreground' : 'text-muted-foreground')}>
                  {to || t('to')}
                </span>
              </div>
              <Button
                className="w-full"
                size="sm"
                disabled={!from || !to || from > to}
                onClick={() =>
                  commit({
                    type: 'custom',
                    year: new Date(`${from}T00:00:00Z`).getUTCFullYear(),
                    from,
                    to,
                  })
                }
              >
                {t('apply')}
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function MonthGrid({
  locale,
  selectedMonth,
  onPick,
}: {
  locale: string;
  selectedMonth?: number;
  onPick: (month: number) => void;
}) {
  return (
    <div className="grid grid-cols-3 gap-1.5">
      {Array.from({ length: 12 }, (_, i) => i + 1).map((m) => (
        <button
          key={m}
          type="button"
          onClick={() => onPick(m)}
          className={cn(
            'rounded-lg py-2 text-sm font-medium transition-colors',
            selectedMonth === m
              ? 'bg-primary text-primary-foreground'
              : 'text-foreground hover:bg-accent',
          )}
        >
          {monthShort(m, locale)}
        </button>
      ))}
    </div>
  );
}
