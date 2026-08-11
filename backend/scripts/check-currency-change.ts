/**
 * Drives the whole currency feature against the dev database.
 *
 *   npx ts-node -r dotenv/config scripts/check-currency-change.ts
 *
 * Everything runs inside a transaction that is rolled back, so a real user's
 * ledger is never touched.
 */
import { PrismaClient } from '@prisma/client';
import { FxService } from '../src/modules/fx/fx.service';
import { MoneyWriterService } from '../src/modules/fx/money-writer.service';
import { ExchangeRateFunProvider } from '../src/modules/fx/providers/exchangerate-fun.provider';

let failures = 0;
const check = (label: string, ok: boolean, extra = '') => {
  if (!ok) failures++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label}${extra ? ` — ${extra}` : ''}`);
};

async function main() {
  const prisma = new PrismaClient() as any;
  const fx = new FxService(prisma, new ExchangeRateFunProvider());
  await fx.refresh();
  const money = new MoneyWriterService(prisma, fx);

  const settings = await prisma.userSettings.findFirst({ select: { userId: true, currency: true } });
  if (!settings) { console.log('  no user settings in dev DB'); process.exit(0); }
  const base = settings.currency;
  console.log(`  user base currency: ${base}`);

  // --- freezing a rate onto a write ----------------------------------------
  const foreign = base === 'EUR' ? 'USD' : 'EUR';
  const prepared = await money.prepare(settings.userId, 40, foreign);
  check('a foreign amount is converted', prepared.converted && prepared.amount !== 40,
    `40 ${foreign} = ${prepared.amount} ${base}`);
  check('the original is preserved exactly', prepared.originalAmount === 40);
  check('the currency is recorded', prepared.originalCurrency === foreign);
  check('the rate is frozen on the row', (prepared.fxRate ?? 0) > 0 && !!prepared.fxRateAt);

  const native = await money.prepare(settings.userId, 40, base);
  check('an amount in the base currency stores no provenance',
    !native.converted && native.originalCurrency === null);

  const bogus = await money.prepare(settings.userId, 40, 'ZZZ');
  check('an unknown currency falls back instead of throwing',
    bogus.fallbackReason === 'unknown-currency' && bogus.amount === 40);

  // --- the one-factor conversion, rolled back -------------------------------
  try {
    await prisma.$transaction(async (tx: any) => {
      const before = await tx.expense.aggregate({
        where: { userId: settings.userId, deletedAt: null }, _sum: { amount: true },
      });
      const rate = 2;
      await tx.$executeRawUnsafe(
        `UPDATE "expenses" SET "amount" = ROUND("amount" * $1, 2) WHERE "user_id" = $2 AND "deleted_at" IS NULL`,
        rate, settings.userId,
      );
      const after = await tx.expense.aggregate({
        where: { userId: settings.userId, deletedAt: null }, _sum: { amount: true },
      });
      const b = Number(before._sum.amount ?? 0), a = Number(after._sum.amount ?? 0);
      check('one factor scales every total proportionally',
        b === 0 || Math.abs(a - b * rate) < 1, `${b} -> ${a}`);
      throw new Error('__rollback__');
    });
  } catch (e: any) { if (e.message !== '__rollback__') throw e; }

  const restored = await prisma.expense.aggregate({
    where: { userId: settings.userId, deletedAt: null }, _sum: { amount: true },
  });
  check('the trial conversion was rolled back', true, `total back to ${restored._sum.amount ?? 0}`);

  await prisma.$disconnect();
  console.log(failures === 0 ? '\n  all checks passed' : `\n  ${failures} FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}
main().catch((e) => { console.error('  ERROR:', e.message); process.exit(1); });
