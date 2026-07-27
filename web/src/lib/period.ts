/**
 * Financial period domain model.
 *
 * A `RangeSelection` describes WHAT the user picked (a month, a quarter, N
 * months, a year, or an arbitrary custom window). Pure helpers turn it into a
 * concrete `[start, end)` date window, a human label, and — crucially — the
 * "preceding equivalent period" used as the default comparison basis.
 *
 * All dates are handled in UTC to stay consistent with the backend.
 */

export type RangeType = 'month' | 'months' | 'quarter' | 'year' | 'custom';

export interface RangeSelection {
  type: RangeType;
  year: number;
  month?: number; // 1-12 — anchor/end month for 'month' and 'months'
  count?: number; // for 'months' — how many months (2..24)
  quarter?: number; // 1-4 for 'quarter'
  from?: string; // 'custom' — yyyy-mm-dd (inclusive)
  to?: string; // 'custom' — yyyy-mm-dd (inclusive)
}

export interface DateWindow {
  start: Date; // inclusive
  end: Date; // exclusive
}

const MS_DAY = 24 * 60 * 60 * 1000;

function utc(year: number, month0: number, day = 1): Date {
  return new Date(Date.UTC(year, month0, day));
}

/** Convert a selection into a concrete [start, end) window. */
export function rangeToWindow(r: RangeSelection): DateWindow {
  switch (r.type) {
    case 'year':
      return { start: utc(r.year, 0, 1), end: utc(r.year + 1, 0, 1) };
    case 'quarter': {
      const q = r.quarter ?? 1;
      const startMonth0 = (q - 1) * 3;
      return { start: utc(r.year, startMonth0, 1), end: utc(r.year, startMonth0 + 3, 1) };
    }
    case 'months': {
      const count = Math.max(1, r.count ?? 1);
      const endMonth0 = (r.month ?? 1) - 1;
      // window ends after the anchor month; starts `count` months earlier
      const end = utc(r.year, endMonth0 + 1, 1);
      const start = utc(r.year, endMonth0 + 1 - count, 1);
      return { start, end };
    }
    case 'custom': {
      const start = r.from ? new Date(`${r.from}T00:00:00.000Z`) : utc(r.year, 0, 1);
      const toInclusive = r.to ? new Date(`${r.to}T00:00:00.000Z`) : start;
      const end = new Date(toInclusive.getTime() + MS_DAY); // make exclusive
      return { start, end };
    }
    case 'month':
    default: {
      const m0 = (r.month ?? 1) - 1;
      return { start: utc(r.year, m0, 1), end: utc(r.year, m0 + 1, 1) };
    }
  }
}

/**
 * The immediately preceding period of the same length — the smart default for
 * "compared to". A month compares to the previous month, a year to the previous
 * year, N months to the preceding N months, a custom window to the equal-length
 * window ending right before it.
 */
export function precedingSelection(r: RangeSelection): RangeSelection {
  switch (r.type) {
    case 'year':
      return { type: 'year', year: r.year - 1 };
    case 'quarter': {
      const q = r.quarter ?? 1;
      return q === 1
        ? { type: 'quarter', year: r.year - 1, quarter: 4 }
        : { type: 'quarter', year: r.year, quarter: q - 1 };
    }
    case 'months': {
      const count = Math.max(1, r.count ?? 1);
      const endMonth0 = (r.month ?? 1) - 1;
      // previous block of `count` months
      const prevEnd0 = endMonth0 - count;
      const d = utc(r.year, prevEnd0, 1);
      return {
        type: 'months',
        year: d.getUTCFullYear(),
        month: d.getUTCMonth() + 1,
        count,
      };
    }
    case 'custom': {
      const w = rangeToWindow(r);
      const lenMs = w.end.getTime() - w.start.getTime();
      const prevStart = new Date(w.start.getTime() - lenMs);
      const prevEndInclusive = new Date(w.start.getTime() - MS_DAY);
      return {
        type: 'custom',
        year: prevStart.getUTCFullYear(),
        from: prevStart.toISOString().slice(0, 10),
        to: prevEndInclusive.toISOString().slice(0, 10),
      };
    }
    case 'month':
    default: {
      const m0 = (r.month ?? 1) - 1;
      const d = utc(r.year, m0 - 1, 1);
      return { type: 'month', year: d.getUTCFullYear(), month: d.getUTCMonth() + 1 };
    }
  }
}

/** The month used for month-only widgets (budgets / daily chart) = range end. */
export function anchorMonth(r: RangeSelection): { month: number; year: number } {
  const w = rangeToWindow(r);
  const last = new Date(w.end.getTime() - MS_DAY);
  return { month: last.getUTCMonth() + 1, year: last.getUTCFullYear() };
}

/** ISO yyyy-mm-dd for query params. */
export function toIso(d: Date): string {
  return d.toISOString().slice(0, 10);
}

// --------------------------------------------------------------------- Labels
const monthName = (m: number, locale: string, long = false) =>
  new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-US', {
    month: long ? 'long' : 'short',
  })
    .format(utc(2020, m - 1, 1))
    .replace(/^\w/, (c) => c.toUpperCase());

export function rangeLabel(r: RangeSelection, locale = 'fr'): string {
  switch (r.type) {
    case 'year':
      return String(r.year);
    case 'quarter':
      return `T${r.quarter ?? 1} ${r.year}`;
    case 'months': {
      const w = rangeToWindow(r);
      const first = new Date(w.start);
      const last = new Date(w.end.getTime() - MS_DAY);
      const a = `${monthName(first.getUTCMonth() + 1, locale)} ${first.getUTCFullYear()}`;
      const b = `${monthName(last.getUTCMonth() + 1, locale)} ${last.getUTCFullYear()}`;
      return `${a} – ${b}`;
    }
    case 'custom':
      return `${r.from} → ${r.to}`;
    case 'month':
    default:
      return `${monthName(r.month ?? 1, locale, true)} ${r.year}`;
  }
}
