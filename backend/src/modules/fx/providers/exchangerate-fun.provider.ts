import { Injectable, Logger } from '@nestjs/common';
import { FxProvider, RateSet } from '../fx.types';

/**
 * api.exchangerate.fun — free, unauthenticated, hourly, ~172 currencies.
 *
 * Chosen after checking the data rather than the marketing: XOF and XAF resolve
 * to 655.9569 against EUR where the treaty peg is 655.957, and majors sit within
 * 0.25% of both ECB and an independent aggregator.
 *
 * What it does *not* offer is a licence, terms of service, a disclosed upstream
 * or an SLA. Everything here is written on the assumption that it can return
 * nonsense, change shape, or vanish:
 *
 *  - a hard timeout, so a hanging provider never occupies a request slot;
 *  - no redirect following, so a hijacked domain cannot walk us elsewhere;
 *  - a response size cap, so a huge body cannot exhaust memory;
 *  - defensive parsing — its own docs disagree with its output about whether
 *    the timestamp field is `date` or `timestamp`, so both are handled.
 *
 * Output is still only a *candidate*: FxValidator decides whether it is stored.
 */
@Injectable()
export class ExchangeRateFunProvider implements FxProvider {
  readonly id = 'exchangerate.fun';

  private readonly logger = new Logger(ExchangeRateFunProvider.name);
  private readonly url = 'https://api.exchangerate.fun/latest?base=USD';
  private readonly timeoutMs = 10_000;
  /** The real payload is ~2.6 KB; a megabyte is already pathological. */
  private readonly maxBytes = 1_000_000;

  async fetchLatest(): Promise<RateSet> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const res = await fetch(this.url, {
        signal: controller.signal,
        // A redirect off this host would mean the domain is no longer ours to
        // trust; fail instead of following it.
        redirect: 'error',
        headers: {
          accept: 'application/json',
          'user-agent': 'Fynexa/1.0 (+https://fynexa.in)',
        },
      });

      if (!res.ok) {
        throw new Error(`${this.id} returned HTTP ${res.status}`);
      }

      const declared = Number(res.headers.get('content-length') ?? 0);
      if (declared > this.maxBytes) {
        throw new Error(`${this.id} response too large (${declared} bytes)`);
      }

      const text = await res.text();
      if (text.length > this.maxBytes) {
        throw new Error(`${this.id} response too large (${text.length} bytes)`);
      }

      return this.parse(text);
    } finally {
      clearTimeout(timer);
    }
  }

  /** Kept separate from the transport so it can be tested on fixtures. */
  parse(text: string): RateSet {
    let body: any;
    try {
      body = JSON.parse(text);
    } catch {
      throw new Error(`${this.id} returned malformed JSON`);
    }

    if (!body || typeof body !== 'object' || typeof body.rates !== 'object') {
      throw new Error(`${this.id} returned no rates object`);
    }

    // Only finite positive numbers survive; anything else would poison a
    // conversion downstream, and the validator's counts should reflect what is
    // actually usable rather than what was sent.
    const rates: Record<string, number> = {};
    for (const [code, value] of Object.entries(body.rates)) {
      const n = typeof value === 'number' ? value : Number(value);
      if (!Number.isFinite(n) || n <= 0) continue;
      // ISO 4217 is three letters; the feed also carries crypto codes, which
      // are allowed through but must still look like codes.
      if (!/^[A-Z]{3,5}$/.test(code)) continue;
      rates[code] = n;
    }

    return {
      base: typeof body.base === 'string' ? body.base : 'USD',
      rates,
      publishedAt: this.readTimestamp(body),
      source: this.id,
    };
  }

  /**
   * The published docs show a `date` string; the live API returns a numeric
   * `timestamp`. Both are handled, and an unusable value becomes an invalid
   * Date so the validator rejects the snapshot rather than dating it "now" —
   * pretending unknown data is fresh is the one thing we must not do.
   */
  private readTimestamp(body: any): Date {
    if (typeof body.timestamp === 'number' && Number.isFinite(body.timestamp)) {
      return new Date(body.timestamp * 1000);
    }
    if (typeof body.date === 'string') {
      const parsed = new Date(body.date);
      if (!Number.isNaN(parsed.getTime())) return parsed;
    }
    this.logger.warn(`${this.id} returned no usable timestamp`);
    return new Date(NaN);
  }
}
