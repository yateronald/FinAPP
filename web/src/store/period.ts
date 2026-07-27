import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { anchorMonth, precedingSelection, type RangeSelection } from '@/lib/period';

export type CompareMode = 'auto' | 'custom' | 'none';

export interface PeriodState {
  range: RangeSelection;
  compareMode: CompareMode;
  compareRange: RangeSelection;
  setRange: (range: RangeSelection) => void;
  setCompareMode: (mode: CompareMode) => void;
  setCompareRange: (range: RangeSelection) => void;
}

const now = new Date();
const defaultRange: RangeSelection = {
  type: 'month',
  year: now.getFullYear(),
  month: now.getMonth() + 1,
};

export const usePeriodStore = create<PeriodState>()(
  persist(
    (set) => ({
      range: defaultRange,
      compareMode: 'auto',
      compareRange: precedingSelection(defaultRange),
      setRange: (range) =>
        set((s) => ({
          range,
          // keep the custom compare range in sync as a sensible starting point
          compareRange: s.compareMode === 'custom' ? s.compareRange : precedingSelection(range),
        })),
      setCompareMode: (compareMode) => set({ compareMode }),
      setCompareRange: (compareRange) => set({ compareRange, compareMode: 'custom' }),
    }),
    { name: 'fintrack-period-v2' },
  ),
);

/** Effective comparison selection given the mode. `null` means no comparison. */
export function resolveCompareRange(s: {
  range: RangeSelection;
  compareMode: CompareMode;
  compareRange: RangeSelection;
}): RangeSelection | null {
  if (s.compareMode === 'none') return null;
  if (s.compareMode === 'custom') return s.compareRange;
  return precedingSelection(s.range);
}

/** Month/year used by month-only consumers (budgets, AI panel). */
export function useAnchor() {
  const range = usePeriodStore((s) => s.range);
  return anchorMonth(range);
}
