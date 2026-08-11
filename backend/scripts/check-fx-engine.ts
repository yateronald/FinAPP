/**
 * Exercises the FX engine against the live provider and the dev database.
 *
 *   npx ts-node -r dotenv/config scripts/check-fx-engine.ts
 *
 * The point is not that conversion works when everything is healthy — it is
 * that nothing throws when it is not. Every failure path is driven here.
 */
import { PrismaClient } from '@prisma/client';
import { FxService } from '../src/modules/fx/fx.service';
import { ExchangeRateFunProvider } from '../src/modules/fx/providers/exchangerate-fun.provider';

let failures = 0;
const check = (label: string, ok: boolean, extra = '') => {
  if (!ok) failures++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label}${extra ? ` — ${extra}` : ''}`);
};

async function main() {
  const prisma = new PrismaClient() as any;
  const fx = new FxService(prisma, new ExchangeRateFunProvider());

  // --- live fetch, validate and store ---------------------------------------
  const result = await fx.refresh();
  check('live rates fetched and accepted', result.accepted, result.reason ?? '');

  const status = await fx.status();
  check('status reports usable rates', status.quality !== 'unavailable',
    `${status.quality}, ${status.currencyCount} currencies, ${status.ageMinutes}min old`);

  // --- conversion correctness ------------------------------------------------
  const eurToXof = await fx.convert(100, 'EUR', 'XOF');
  // The treaty peg: €100 is 65 595.70 XOF, give or take rounding.
  const pegOk = Math.abs(eurToXof.amount - 65595.7) < 50;
  check('EUR->XOF matches the treaty peg', pegOk, `100 EUR = ${eurToXof.amount} XOF`);

  const roundTrip = await fx.convert(eurToXof.amount, 'XOF', 'EUR');
  check('round trip returns close to the original', Math.abs(roundTrip.amount - 100) < 0.5,
    `back to ${roundTrip.amount} EUR`);

  const same = await fx.convert(500, 'XOF', 'XOF');
  check('same-currency conversion is identity', same.amount === 500 && same.rate === 1);

  // --- the failure paths, which are the whole point --------------------------
  const unknown = await fx.convert(100, 'XOF', 'NOTACURRENCY');
  check('unknown currency does not throw, returns unavailable',
    unknown.quality === 'unavailable' && unknown.amount === 100,
    `amount kept at ${unknown.amount}`);

  const nan = await fx.convert(Number.NaN, 'EUR', 'XOF');
  check('NaN input does not throw', nan.quality === 'unavailable');

  const noRate = await fx.rate('EUR', 'ZZZ');
  check('rate() returns null rather than throwing for an unknown code', noRate === null);

  // A provider that is completely broken must leave the last good snapshot in
  // place and simply report that nothing was accepted.
  const brokenFx = new FxService(prisma, {
    id: 'broken',
    fetchLatest: async () => {
      throw new Error('simulated outage');
    },
  } as any);
  const afterOutage = await brokenFx.refresh();
  check('a dead provider is reported, not thrown', afterOutage.accepted === false,
    afterOutage.reason ?? '');
  const stillWorks = await brokenFx.convert(100, 'EUR', 'XOF');
  check('conversion still works during an outage, on the stored snapshot',
    stillWorks.amount > 0 && stillWorks.quality !== 'unavailable',
    `100 EUR = ${stillWorks.amount} XOF (${stillWorks.quality})`);

  // A provider returning garbage must be rejected, not stored.
  const before = await prisma.fxRateSnapshot.count();
  const poisonFx = new FxService(prisma, {
    id: 'poison',
    fetchLatest: async () => ({
      base: 'USD',
      // XOF wildly off its peg — the exact thing the validator exists to catch.
      rates: { USD: 1, EUR: 0.86, GBP: 0.74, XOF: 9999 },
      publishedAt: new Date(),
      source: 'poison',
    }),
  } as any);
  const poisoned = await poisonFx.refresh();
  const after = await prisma.fxRateSnapshot.count();
  check('rates that break a peg are rejected', poisoned.accepted === false);
  check('and nothing was written', before === after, `${before} -> ${after}`);

  await prisma.$disconnect();
  console.log(failures === 0 ? '\n  all checks passed' : `\n  ${failures} FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error('  ERROR:', e.message);
  process.exit(1);
});
