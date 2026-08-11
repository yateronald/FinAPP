import { FxValidator } from './fx-validator';
import { RateSet } from './fx.types';

/**
 * The validator is the only thing standing between an unaccountable free API
 * and a ledger. Every foreign-currency amount is frozen at the rate in force
 * when it was written, so a bad snapshot accepted silently would misprice
 * entries permanently — fixing it later means rewriting user history.
 *
 * These cases are built from what the live feed actually returns, checked
 * against the real pegs.
 */
describe('FxValidator', () => {
  const good = (over: Partial<Record<string, number>> = {}): RateSet => {
    const rates: Record<string, number> = {
      USD: 1,
      EUR: 0.866585,
      GBP: 0.740417,
      JPY: 159.2685,
      // 568.442444 / 0.866585 = 655.9569 — the treaty peg.
      XOF: 568.442444,
      XAF: 568.442444,
      AED: 3.6725,
      SAR: 3.7459,
      NGN: 1362.64,
    };
    // Pad to clear the minimum-count check with plausible values.
    for (let i = 0; i < 120; i++) rates[`C${String(i).padStart(2, '0')}A`] = 1 + i / 100;
    Object.assign(rates, over);
    return {
      base: 'USD',
      rates,
      publishedAt: new Date(Date.now() - 30 * 60_000),
      source: 'test',
    };
  };

  it('accepts a healthy snapshot', () => {
    expect(FxValidator.validate(good(), null).ok).toBe(true);
  });

  describe('pegs — a deviation is a data fault, never a market move', () => {
    it('rejects a broken XOF/EUR peg', () => {
      // 5% off the treaty rate: impossible in reality.
      const v = FxValidator.validate(good({ XOF: 568.44 * 1.05 }), null);
      expect(v.ok).toBe(false);
      expect(v.reasons.join(' ')).toMatch(/XOF\/EUR/);
    });

    it('rejects a broken XAF peg', () => {
      expect(FxValidator.validate(good({ XAF: 700 }), null).ok).toBe(false);
    });

    it('rejects a broken AED/USD peg', () => {
      expect(FxValidator.validate(good({ AED: 4.2 }), null).ok).toBe(false);
    });

    it('tolerates the peg to its published precision', () => {
      // 655.9569 vs 655.957 is what the live feed actually returns.
      expect(FxValidator.validate(good({ XOF: 568.442444 }), null).ok).toBe(true);
    });
  });

  describe('structure', () => {
    it('rejects a truncated feed', () => {
      const v = FxValidator.validate(
        { ...good(), rates: { USD: 1, EUR: 0.86, XOF: 568.44, GBP: 0.74 } },
        null,
      );
      expect(v.ok).toBe(false);
      expect(v.reasons.join(' ')).toMatch(/only 4 rates/);
    });

    it('rejects a feed missing a currency we depend on', () => {
      const r = good();
      delete r.rates.XOF;
      expect(FxValidator.validate(r, null).ok).toBe(false);
    });

    it('rejects a base not quoted at 1', () => {
      expect(FxValidator.validate(good({ USD: 1.02 }), null).ok).toBe(false);
    });

    it('rejects negative or zero rates', () => {
      expect(FxValidator.validate(good({ NGN: 0 }), null).ok).toBe(false);
      expect(FxValidator.validate(good({ NGN: -5 }), null).ok).toBe(false);
    });
  });

  describe('freshness', () => {
    it('rejects rates far too old to be "latest"', () => {
      const r = good();
      r.publishedAt = new Date(Date.now() - 72 * 3_600_000);
      expect(FxValidator.validate(r, null).ok).toBe(false);
    });

    it('rejects rates dated in the future', () => {
      const r = good();
      r.publishedAt = new Date(Date.now() + 5 * 3_600_000);
      expect(FxValidator.validate(r, null).ok).toBe(false);
    });

    it('rejects an unparseable timestamp rather than assuming "now"', () => {
      const r = good();
      r.publishedAt = new Date(NaN);
      expect(FxValidator.validate(r, null).ok).toBe(false);
    });
  });

  describe('drift against the last accepted snapshot', () => {
    it('rejects a broad repricing — no real market moves everything at once', () => {
      const previous = good();
      const next = good();
      next.publishedAt = new Date(Date.now() - 20 * 60_000);
      for (const code of Object.keys(next.rates)) {
        if (code === 'USD') continue;
        next.rates[code] = previous.rates[code] * 2;
      }
      const v = FxValidator.validate(next, previous);
      expect(v.ok).toBe(false);
      expect(v.reasons.join(' ')).toMatch(/moved sharply/);
    });

    it('allows a genuine single-currency devaluation, with a note', () => {
      const previous = good();
      const next = good({ NGN: 1362.64 * 1.6 });
      next.publishedAt = new Date(Date.now() - 20 * 60_000);
      const v = FxValidator.validate(next, previous);
      expect(v.ok).toBe(true);
      expect(v.warnings.join(' ')).toMatch(/NGN/);
    });

    it('stops enforcing drift once the previous snapshot is old', () => {
      // After an outage the market really has moved; refusing forever would
      // leave the app permanently stale.
      const previous = good();
      previous.publishedAt = new Date(Date.now() - 30 * 3_600_000);
      const next = good();
      for (const code of Object.keys(next.rates)) {
        if (code === 'USD') continue;
        next.rates[code] = previous.rates[code] * 2;
      }
      // Pegs still have to hold, so restore those.
      next.rates.XOF = 568.442444;
      next.rates.XAF = 568.442444;
      next.rates.EUR = 0.866585;
      next.rates.AED = 3.6725;
      next.rates.SAR = 3.7459;
      expect(FxValidator.validate(next, previous).ok).toBe(true);
    });

    it('rejects a snapshot that lost most of its currencies', () => {
      const previous = good();
      const next = good();
      for (const code of Object.keys(next.rates).slice(0, 60)) delete next.rates[code];
      expect(FxValidator.validate(next, previous).ok).toBe(false);
    });
  });
});
