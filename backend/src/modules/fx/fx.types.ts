/** A set of rates quoted against one pivot currency. */
export interface RateSet {
  base: string;
  /** Units of each currency per one unit of `base`. */
  rates: Record<string, number>;
  /** When the provider says these were published. */
  publishedAt: Date;
  /** Provider id, recorded on the snapshot for audit. */
  source: string;
}

/**
 * A source of exchange rates.
 *
 * Deliberately an interface with one implementation today: the provider in use
 * is a free, unauthenticated third party with no SLA and no licence, so being
 * able to add or swap one without touching any call site is a requirement, not
 * a nicety.
 */
export interface FxProvider {
  readonly id: string;
  /** Rejects rather than returning partial data; the caller decides what to do. */
  fetchLatest(): Promise<RateSet>;
}

/** Why a conversion produced the number it did — surfaced to the client. */
export type FxQuality =
  /** Rates fresh enough to be quoted without comment. */
  | 'live'
  /** Real rates, but older than we would like; the client should say so. */
  | 'stale'
  /** No usable rates at all. Nothing was converted. */
  | 'unavailable';

export interface ConversionResult {
  amount: number;
  rate: number;
  /** When the applied rates were published upstream. */
  rateAt: Date | null;
  quality: FxQuality;
  /** How old the rates were, for the client's wording. */
  ageMinutes: number | null;
}
