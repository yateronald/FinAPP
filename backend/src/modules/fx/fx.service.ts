import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../common/prisma/prisma.service';
import { FxValidator } from './fx-validator';
import { ConversionResult, FxProvider, FxQuality, RateSet } from './fx.types';
import { ExchangeRateFunProvider } from './providers/exchangerate-fun.provider';

/**
 * Converts money, and never stops the app from working.
 *
 * The design rule throughout: **FX is an enhancement, not a dependency.** If
 * the provider is down, the rates are stale, or the currency is unknown, every
 * path here degrades to something usable and says so through [FxQuality]. No
 * method throws because rates are missing — callers get a result they can act
 * on, and the user gets told what happened.
 *
 * Rates are read from our own snapshots, never fetched inline on a user
 * request. A user action must not wait on a third party, and a burst of users
 * must not become a burst of outbound calls.
 */
@Injectable()
export class FxService implements OnModuleInit {
  private readonly logger = new Logger(FxService.name);
  private readonly providers: FxProvider[];

  /** Rates older than this are still used, but flagged to the user. */
  private static readonly STALE_AFTER_MINUTES = 6 * 60;

  /** In-process cache of the newest snapshot; refreshed on write. */
  private cached: RateSet | null = null;
  private cachedAt = 0;
  private static readonly CACHE_TTL_MS = 60_000;

  constructor(
    private readonly prisma: PrismaService,
    exchangeRateFun: ExchangeRateFunProvider,
  ) {
    // Ordered by preference. Adding a second source here is all that is needed
    // to survive the first one disappearing.
    this.providers = [exchangeRateFun];
  }

  async onModuleInit() {
    // Detached on purpose: warming rates must never block the API from booting,
    // and a provider outage at deploy time must not turn into a failed deploy.
    void this.warmUp();
  }

  /**
   * Makes sure rates exist as soon as the process is up.
   *
   * The hourly cron alone is not enough. On a fresh deployment the snapshot
   * table is empty, and a restart at :21 would leave the app with no rates at
   * all until :20 the next hour — 59 minutes during which every conversion
   * reports `unavailable`. Nothing breaks, by design, but the feature is simply
   * absent, which looks identical to it being broken.
   *
   * So: read what we have, and fetch immediately if it is missing or already
   * stale. Steady-state restarts find fresh rates and make no outbound call.
   */
  private async warmUp() {
    try {
      const existing = await this.loadLatest();
      if (existing) {
        const { quality } = this.qualityOf(existing.publishedAt);
        if (quality === 'live') {
          this.logger.log('FX rates loaded from the last stored snapshot');
          return;
        }
        this.logger.log('Stored FX rates are stale — refreshing at startup');
      } else {
        this.logger.log('No FX rates stored yet — fetching at startup');
      }
      await this.refresh();
    } catch (e: any) {
      // The hourly cron will try again; conversions report `unavailable` until
      // then and every caller already handles that.
      this.logger.warn(`FX warm-up failed, will retry on schedule: ${e.message}`);
    }
  }

  // ----------------------------------------------------------------- refresh

  /**
   * Hourly, matching the provider's own cadence. Deliberately off the hour:
   * the feed publishes at :00, so asking at :20 avoids racing the publish and
   * avoids joining every other consumer's thundering herd.
   */
  @Cron('20 * * * *')
  async refresh(): Promise<{ accepted: boolean; reason?: string }> {
    const previous = await this.loadLatest();

    for (const provider of this.providers) {
      try {
        const candidate = await provider.fetchLatest();
        const verdict = FxValidator.validate(candidate, previous);

        if (!verdict.ok) {
          // Keeping the older snapshot is strictly better than storing rates we
          // do not believe. Try the next provider, if there is one.
          this.logger.warn(
            `Rates from ${provider.id} rejected: ${verdict.reasons.join('; ')}`,
          );
          continue;
        }

        await this.prisma.fxRateSnapshot.create({
          data: {
            base: candidate.base,
            rates: candidate.rates,
            publishedAt: candidate.publishedAt,
            source: candidate.source,
            rateCount: Object.keys(candidate.rates).length,
          },
        });
        this.cached = candidate;
        this.cachedAt = Date.now();
        this.logger.log(
          `Accepted ${Object.keys(candidate.rates).length} rates from ${provider.id}`,
        );
        return { accepted: true };
      } catch (e: any) {
        this.logger.warn(`${provider.id} unavailable: ${e.message}`);
      }
    }

    // Every provider failed. The last accepted snapshot stays in place and the
    // app keeps converting on it; only its quality label changes.
    return { accepted: false, reason: 'no provider returned usable rates' };
  }

  /** Old snapshots are audit history, not working data — keep 90 days. */
  @Cron(CronExpression.EVERY_DAY_AT_4AM)
  async prune() {
    const cutoff = new Date(Date.now() - 90 * 24 * 3_600_000);
    const { count } = await this.prisma.fxRateSnapshot.deleteMany({
      where: { publishedAt: { lt: cutoff } },
    });
    if (count > 0) this.logger.log(`Pruned ${count} FX snapshots older than 90 days`);
  }

  // ------------------------------------------------------------------- reads

  /** Newest accepted snapshot, from memory when warm. */
  private async loadLatest(): Promise<RateSet | null> {
    if (this.cached && Date.now() - this.cachedAt < FxService.CACHE_TTL_MS) {
      return this.cached;
    }
    const row = await this.prisma.fxRateSnapshot.findFirst({
      orderBy: { publishedAt: 'desc' },
    });
    if (!row) return null;

    this.cached = {
      base: row.base,
      rates: row.rates as Record<string, number>,
      publishedAt: row.publishedAt,
      source: row.source,
    };
    this.cachedAt = Date.now();
    return this.cached;
  }

  private qualityOf(publishedAt: Date): { quality: FxQuality; ageMinutes: number } {
    const ageMinutes = Math.max(0, (Date.now() - publishedAt.getTime()) / 60_000);
    return {
      quality: ageMinutes > FxService.STALE_AFTER_MINUTES ? 'stale' : 'live',
      ageMinutes: Math.round(ageMinutes),
    };
  }

  /** What the client needs to decide whether to warn the user. */
  async status() {
    const latest = await this.loadLatest();
    if (!latest) {
      return {
        quality: 'unavailable' as FxQuality,
        publishedAt: null,
        ageMinutes: null,
        currencyCount: 0,
        source: null,
      };
    }
    const { quality, ageMinutes } = this.qualityOf(latest.publishedAt);
    return {
      quality,
      publishedAt: latest.publishedAt.toISOString(),
      ageMinutes,
      currencyCount: Object.keys(latest.rates).length,
      source: latest.source,
    };
  }

  /** Currency codes we can actually convert right now. */
  async supportedCodes(): Promise<string[]> {
    const latest = await this.loadLatest();
    return latest ? Object.keys(latest.rates).sort() : [];
  }

  // -------------------------------------------------------------- conversion

  /**
   * The rate to multiply a [from] amount by to express it in [to].
   *
   * Returns null when it cannot be computed — the caller then treats the amount
   * as already being in the target currency, which is the behaviour that keeps
   * the app usable when FX is down.
   */
  async rate(from: string, to: string): Promise<{ rate: number; at: Date } | null> {
    const a = from?.toUpperCase();
    const b = to?.toUpperCase();
    if (!a || !b) return null;
    if (a === b) return { rate: 1, at: new Date() };

    const latest = await this.loadLatest();
    if (!latest) return null;

    // Everything is quoted against one pivot, so a cross-rate is one division.
    const perBaseFrom = a === latest.base ? 1 : latest.rates[a];
    const perBaseTo = b === latest.base ? 1 : latest.rates[b];
    if (!Number.isFinite(perBaseFrom) || !Number.isFinite(perBaseTo)) return null;
    if (perBaseFrom <= 0 || perBaseTo <= 0) return null;

    return { rate: perBaseTo / perBaseFrom, at: latest.publishedAt };
  }

  /**
   * Converts [amount] from one currency to another.
   *
   * Never throws. When no rate is available the amount is returned untouched
   * with quality `unavailable`, so a transaction can still be saved — recorded
   * in the base currency, which is the honest fallback — and the client can
   * tell the user the conversion did not happen.
   */
  async convert(amount: number, from: string, to: string): Promise<ConversionResult> {
    if (!Number.isFinite(amount)) {
      return { amount: 0, rate: 1, rateAt: null, quality: 'unavailable', ageMinutes: null };
    }
    if (from?.toUpperCase() === to?.toUpperCase()) {
      return { amount, rate: 1, rateAt: null, quality: 'live', ageMinutes: 0 };
    }

    const found = await this.rate(from, to);
    if (!found) {
      return {
        amount,
        rate: 1,
        rateAt: null,
        quality: 'unavailable',
        ageMinutes: null,
      };
    }

    const { quality, ageMinutes } = this.qualityOf(found.at);
    return {
      // Money is stored to 2dp; rounding here keeps the value the client shows
      // identical to the value the database keeps.
      amount: Math.round(amount * found.rate * 100) / 100,
      rate: found.rate,
      rateAt: found.at,
      quality,
      ageMinutes,
    };
  }
}
