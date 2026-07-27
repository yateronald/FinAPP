'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { anchorMonth, rangeToWindow, toIso } from '@/lib/period';
import { resolveCompareRange, usePeriodStore } from '@/store/period';
import type { DashboardData } from '@/lib/types';

/**
 * Reads the selected range + comparison from the global store, converts them to
 * concrete date windows and fetches the range-based dashboard. Sidebar and
 * dashboard share this so they hit the same cache entry.
 */
export function useDashboardData() {
  const range = usePeriodStore((s) => s.range);
  const compareMode = usePeriodStore((s) => s.compareMode);
  const compareRange = usePeriodStore((s) => s.compareRange);

  const win = rangeToWindow(range);
  const cmp = resolveCompareRange({ range, compareMode, compareRange });
  const cmpWin = cmp ? rangeToWindow(cmp) : null;
  const anchor = anchorMonth(range);

  const params = new URLSearchParams();
  params.set('from', toIso(win.start));
  params.set('to', toIso(win.end));
  if (cmpWin) {
    params.set('compareFrom', toIso(cmpWin.start));
    params.set('compareTo', toIso(cmpWin.end));
  }
  params.set('anchorMonth', String(anchor.month));
  params.set('anchorYear', String(anchor.year));
  const qs = params.toString();

  return useQuery({
    queryKey: ['dashboard', qs],
    queryFn: () => api.get<DashboardData>(`/dashboard?${qs}`),
  });
}
