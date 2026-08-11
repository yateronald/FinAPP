import { Logger } from '@nestjs/common';
import { RateSet } from './fx.types';

/**
 * Decides whether a freshly fetched rate set is fit to store.
 *
 * The provider is free, unauthenticated and has no SLA, so its output is
 * treated as a suggestion rather than a fact. A finance ledger is built on
 * these numbers: a single bad snapshot, accepted silently, would misprice every
 * foreign-currency entry made until the next fetch — and those values are
 * frozen onto transactions, so the damage would outlive the bad data.
 *
 * Rejecting is always safe. The caller keeps the last accepted snapshot, which
 * is at worst a few hours stale.
 */

/** Fixed pegs. Breaking one of these means the feed is wrong, not the market. */
const PEGS: { code: string; per: string; value: number; tolerance: number }[] = [
  // The CFA francs are pegged to the euro by treaty, not by market.
  { code: 'XOF', per: 'EUR', value: 655.957, tolerance: 0.001 },
  { code: 'XAF', per: 'EUR', value: 655.957, tolerance: 0.001 },
  // Currency-board and hard USD pegs; wider tolerance for managed bands.
  { code: 'AED', per: 'USD', value: 3.6725, tolerance: 0.01 },
  { code: 'SAR', per: 'USD', value: 3.75, tolerance: 0.02 },
];

/** Currencies that must be present, or the snapshot is not useful to us. */
const REQUIRED = ['USD', 'EUR', 'XOF', 'GBP'];

/** Below this the upstream is clearly broken, whatever it claims. */
const MIN_RATE_COUNT = 100;

/** A snapshot older than this is not worth storing as "latest". */
const MAX_AGE_HOURS = 48;

/**
 * How far a rate may move between two accepted snapshots before we treat it as
 * suspect. Real currencies do move violently — a devaluation can exceed this —
 * so this is a *review* threshold: it rejects the snapshot, and a genuine move
 * is picked up once the previous snapshot ages past [DRIFT_GRACE_HOURS].
 */
const MAX_DRIFT_RATIO = 0.25;
const DRIFT_GRACE_HOURS = 12;

export interface ValidationOutcome {
  ok: boolean;
  /** Populated when ok is false — logged, never shown to users. */
  reasons: string[];
  /** Non-fatal observations worth recording. */
  warnings: string[];
}

export class FxValidator {
  private static readonly logger = new Logger('FxValidator');

  /**
   * [previous] is the last accepted rate set, used for drift detection. Pass
   * null on the very first fetch — there is nothing to compare against, so
   * only the structural and peg checks apply.
   */
  static validate(next: RateSet, previous: RateSet | null): ValidationOutcome {
    const reasons: string[] = [];
    const warnings: string[] = [];
    const rates = next.rates ?? {};
    const codes = Object.keys(rates);

    // --- structure ---------------------------------------------------------
    if (codes.length < MIN_RATE_COUNT) {
      reasons.push(`only ${codes.length} rates (minimum ${MIN_RATE_COUNT})`);
    }
    for (const code of REQUIRED) {
      if (typeof rates[code] !== 'number') reasons.push(`missing required rate ${code}`);
    }
    // The base must be present and be exactly 1, or the whole set is misquoted.
    if (rates[next.base] !== undefined && Math.abs(rates[next.base] - 1) > 1e-6) {
      reasons.push(`base ${next.base} is quoted at ${rates[next.base]}, expected 1`);
    }

    const nonFinite = codes.filter(
      (c) => !Number.isFinite(rates[c]) || rates[c] <= 0,
    );
    if (nonFinite.length > 0) {
      reasons.push(`non-positive or non-finite rates: ${nonFinite.slice(0, 5).join(', ')}`);
    }

    // --- freshness ---------------------------------------------------------
    const ageHours = (Date.now() - next.publishedAt.getTime()) / 3_600_000;
    if (!Number.isFinite(ageHours)) {
      reasons.push('unparseable publication timestamp');
    } else if (ageHours > MAX_AGE_HOURS) {
      reasons.push(`published ${ageHours.toFixed(1)}h ago (max ${MAX_AGE_HOURS}h)`);
    } else if (ageHours < -1) {
      // More than an hour in the future means clocks or data are wrong.
      reasons.push(`published ${(-ageHours).toFixed(1)}h in the future`);
    }

    // --- pegs --------------------------------------------------------------
    // The strongest signal available: these are set by treaty or currency
    // board, so a deviation is a data fault, never a market move.
    for (const peg of PEGS) {
      const numerator = rates[peg.code];
      const denominator = peg.per === next.base ? 1 : rates[peg.per];
      if (typeof numerator !== 'number' || typeof denominator !== 'number') continue;
      const implied = numerator / denominator;
      const drift = Math.abs(implied - peg.value) / peg.value;
      if (drift > peg.tolerance) {
        reasons.push(
          `${peg.code}/${peg.per} is ${implied.toFixed(4)}, pegged at ${peg.value} ` +
            `(${(drift * 100).toFixed(2)}% off)`,
        );
      }
    }

    // --- drift against the last accepted set --------------------------------
    if (previous && previous.base === next.base) {
      const prevAgeHours =
        (next.publishedAt.getTime() - previous.publishedAt.getTime()) / 3_600_000;
      const enforceDrift = prevAgeHours <= DRIFT_GRACE_HOURS;
      const moved: string[] = [];
      for (const code of codes) {
        const before = previous.rates[code];
        if (typeof before !== 'number' || before <= 0) continue;
        const ratio = Math.abs(rates[code] - before) / before;
        if (ratio > MAX_DRIFT_RATIO) {
          moved.push(`${code} ${(ratio * 100).toFixed(1)}%`);
        }
      }
      if (moved.length > 0) {
        const detail = `${moved.length} rate(s) moved sharply: ${moved.slice(0, 5).join(', ')}`;
        // A handful of exotic currencies genuinely do this. A broad move is a
        // broken feed — no real market repricies a third of the world at once.
        const broad = moved.length > Math.max(5, codes.length * 0.1);
        if (enforceDrift && broad) {
          reasons.push(detail);
        } else {
          warnings.push(detail);
        }
      }

      const dropped = Object.keys(previous.rates).filter((c) => rates[c] === undefined);
      if (dropped.length > codes.length * 0.1) {
        reasons.push(`${dropped.length} currencies disappeared since the last snapshot`);
      }
    }

    if (reasons.length > 0) {
      this.logger.warn(
        `Rejected rates from ${next.source}: ${reasons.join('; ')}`,
      );
    }
    for (const w of warnings) {
      this.logger.log(`Accepted rates from ${next.source} with a note: ${w}`);
    }

    return { ok: reasons.length === 0, reasons, warnings };
  }
}
