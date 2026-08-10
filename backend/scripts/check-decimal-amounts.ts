/**
 * Proves decimal amounts survive the whole round trip: DTO validation →
 * Prisma → Postgres Decimal(14, 2) → JSON back to the client.
 *
 *   npx ts-node -r dotenv/config scripts/check-decimal-amounts.ts
 *
 * Creates rows in a transaction and rolls them back, so nothing is left behind.
 */
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { PrismaClient } from '@prisma/client';
import { CreateExpenseDto } from '../src/modules/expenses/dto/expense.dto';
import { asNumber } from './_shared';

let failures = 0;
const check = (label: string, ok: boolean, extra = '') => {
  if (!ok) failures++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label}${extra ? ` — ${extra}` : ''}`);
};

async function main() {
  const prisma = new PrismaClient();

  // --- 1. The DTO contract --------------------------------------------------
  const dtoFor = (amount: unknown) =>
    plainToInstance(CreateExpenseDto, {
      title: 'probe',
      categoryId: 'c1',
      amount,
      date: new Date().toISOString(),
    });

  const amountErrors = async (amount: unknown) => {
    const errs = await validate(dtoFor(amount));
    return errs.filter((e) => e.property === 'amount');
  };

  check('DTO accepts 2000.21', (await amountErrors(2000.21)).length === 0);
  check('DTO accepts a whole amount', (await amountErrors(2000)).length === 0);
  check('DTO accepts 0.05', (await amountErrors(0.05)).length === 0);
  check(
    'DTO rejects a third decimal instead of letting Postgres round it',
    (await amountErrors(2000.219)).length > 0,
  );

  // --- 2. The database ------------------------------------------------------
  const user = await prisma.user.findFirst({ select: { id: true } });
  const cat = await prisma.category.findFirst({
    where: { type: 'EXPENSE', deletedAt: null },
    select: { id: true, userId: true },
  });
  if (!user || !cat) {
    console.log('  (skipping the database half — dev DB has no user/category)');
  } else {
    try {
      await prisma.$transaction(async (tx) => {
        const created = await tx.expense.create({
          data: {
            userId: cat.userId,
            categoryId: cat.id,
            title: '[probe] decimal',
            amount: 2000.21,
            date: new Date(),
          },
          select: { id: true, amount: true },
        });
        check('Postgres stores 2000.21 exactly', asNumber(created.amount) === 2000.21,
          `got ${created.amount}`);

        const readBack = await tx.expense.findUnique({
          where: { id: created.id },
          select: { amount: true },
        });
        check('reads back unchanged', asNumber(readBack!.amount) === 2000.21,
          `got ${readBack!.amount}`);

        // Aggregates are what the dashboard and budgets are built from.
        const agg = await tx.expense.aggregate({
          where: { id: created.id },
          _sum: { amount: true },
        });
        check('sums keep the cents', asNumber(agg._sum.amount) === 2000.21,
          `got ${agg._sum.amount}`);

        // The API serialises Decimal via JSON — the client must see the cents.
        const json = JSON.parse(JSON.stringify({ amount: created.amount }));
        check('survives JSON serialisation', Number(json.amount) === 2000.21,
          `got ${JSON.stringify(json.amount)}`);

        throw new Error('__rollback__');
      });
    } catch (e: any) {
      if (e.message !== '__rollback__') throw e;
    }
    const leftovers = await prisma.expense.count({
      where: { title: '[probe] decimal' },
    });
    check('probe rows rolled back', leftovers === 0, `${leftovers} left`);
  }

  await prisma.$disconnect();
  console.log(failures === 0 ? '\n  all checks passed' : `\n  ${failures} FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error('  ERROR:', e.message);
  process.exit(1);
});
