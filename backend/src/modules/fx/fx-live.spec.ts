import * as fs from 'fs';
import * as path from 'path';
import { ExchangeRateFunProvider } from './providers/exchangerate-fun.provider';
import { FxValidator } from './fx-validator';

/**
 * The validator is worthless if it is so strict that it rejects the real feed.
 * This runs the provider's parser and the validator over an actual captured
 * response, so a tolerance tightened by mistake fails here rather than
 * silently freezing rates in production.
 */
describe('the real feed passes validation', () => {
  const raw = fs.readFileSync(
    path.join(__dirname, 'live-sample.fixture.json'),
    'utf8',
  );

  it('parses into a usable rate set', () => {
    const set = new ExchangeRateFunProvider().parse(raw);
    expect(set.base).toBe('USD');
    expect(Object.keys(set.rates).length).toBeGreaterThan(150);
    expect(set.rates.XOF).toBeGreaterThan(0);
    expect(Number.isNaN(set.publishedAt.getTime())).toBe(false);
  });

  it('is accepted by the validator', () => {
    const set = new ExchangeRateFunProvider().parse(raw);
    // The capture ages as the repo does; re-date it so the freshness rule is
    // not what is under test here.
    set.publishedAt = new Date(Date.now() - 60 * 60_000);
    const verdict = FxValidator.validate(set, null);
    expect(verdict.reasons).toEqual([]);
    expect(verdict.ok).toBe(true);
  });

  it('carries the currencies the app needs', () => {
    const { rates } = new ExchangeRateFunProvider().parse(raw);
    for (const code of ['XOF', 'XAF', 'EUR', 'USD', 'GBP', 'NGN', 'GHS', 'CAD']) {
      expect(rates[code]).toBeGreaterThan(0);
    }
  });
});
