'use client';

import { useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { useLocale } from 'next-intl';
import { cn, monthYearLabel } from '@/lib/utils';

function ymd(d: Date): string {
  return d.toISOString().slice(0, 10);
}
function parse(s?: string): Date | undefined {
  return s ? new Date(`${s}T00:00:00.000Z`) : undefined;
}

/**
 * Compact single-month calendar for picking a [from, to] day range.
 * First click sets the start (and clears the end); second click sets the end,
 * auto-ordering the two.
 */
export function RangeCalendar({
  from,
  to,
  onChange,
}: {
  from?: string;
  to?: string;
  onChange: (from: string, to: string) => void;
}) {
  const locale = useLocale();
  const anchor = parse(from) ?? new Date();
  const [view, setView] = useState({ y: anchor.getUTCFullYear(), m: anchor.getUTCMonth() });

  const selFrom = parse(from);
  const selTo = parse(to);

  const pick = (day: Date) => {
    const iso = ymd(day);
    if (!from || (from && to)) {
      onChange(iso, '');
    } else if (iso < from) {
      onChange(iso, from);
    } else {
      onChange(from, iso);
    }
  };

  const firstOfMonth = new Date(Date.UTC(view.y, view.m, 1));
  const startWeekday = (firstOfMonth.getUTCDay() + 6) % 7; // Monday = 0
  const daysInMonth = new Date(Date.UTC(view.y, view.m + 1, 0)).getUTCDate();
  const cells: (Date | null)[] = [];
  for (let i = 0; i < startWeekday; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(Date.UTC(view.y, view.m, d)));

  const weekdays =
    locale === 'fr'
      ? ['L', 'M', 'M', 'J', 'V', 'S', 'D']
      : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  const shift = (delta: number) => {
    const d = new Date(Date.UTC(view.y, view.m + delta, 1));
    setView({ y: d.getUTCFullYear(), m: d.getUTCMonth() });
  };

  const isFrom = (d: Date) => from && ymd(d) === from;
  const isTo = (d: Date) => to && ymd(d) === to;
  const inRange = (d: Date) => selFrom && selTo && d > selFrom && d < selTo;

  return (
    <div>
      <div className="mb-2 flex items-center justify-between">
        <button
          type="button"
          onClick={() => shift(-1)}
          className="rounded-md p-1 text-muted-foreground hover:bg-accent hover:text-foreground"
        >
          <ChevronLeft className="h-4 w-4" />
        </button>
        <span className="text-sm font-semibold text-foreground">
          {monthYearLabel(view.m + 1, view.y, locale)}
        </span>
        <button
          type="button"
          onClick={() => shift(1)}
          className="rounded-md p-1 text-muted-foreground hover:bg-accent hover:text-foreground"
        >
          <ChevronRight className="h-4 w-4" />
        </button>
      </div>

      <div className="mb-1 grid grid-cols-7 gap-0.5 text-center text-[10px] font-medium text-muted-foreground">
        {weekdays.map((w, i) => (
          <span key={i}>{w}</span>
        ))}
      </div>

      <div className="grid grid-cols-7 gap-0.5">
        {cells.map((d, i) =>
          d === null ? (
            <span key={i} />
          ) : (
            <button
              key={i}
              type="button"
              onClick={() => pick(d)}
              className={cn(
                'flex h-8 items-center justify-center text-xs transition-colors',
                inRange(d) && 'bg-primary/10',
                isFrom(d) && 'rounded-l-lg',
                isTo(d) && 'rounded-r-lg',
                isFrom(d) || isTo(d)
                  ? 'bg-primary font-semibold text-primary-foreground'
                  : 'rounded-lg text-foreground hover:bg-accent',
              )}
            >
              {d.getUTCDate()}
            </button>
          ),
        )}
      </div>
    </div>
  );
}
