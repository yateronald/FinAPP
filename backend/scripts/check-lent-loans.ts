/**
 * End-to-end check of the LENT path against a real database.
 *
 * The unit tests mock Prisma, so they prove the direction rule but not that
 * `list`/`detail` actually read income for a lent loan. This drives the real
 * service against the dev DB and rolls everything back afterwards.
 *
 *   npx ts-node -r dotenv/config scripts/check-lent-loans.ts
 */
import { LoanDirection } from '@prisma/client';
import { PrismaService } from '../src/common/prisma/prisma.service';
import { LoansService } from '../src/modules/loans/loans.service';

const ok = (label: string, pass: boolean, extra = '') =>
  console.log(`  ${pass ? 'PASS' : 'FAIL'}  ${label}${extra ? ` — ${extra}` : ''}`);

async function main() {
  const prisma = new PrismaService();
  await prisma.$connect();
  const loans = new LoansService(prisma);

  const user = await prisma.user.findFirst({ select: { id: true } });
  if (!user) throw new Error('no user in the dev database');
  const incomeCat = await prisma.category.findFirst({
    where: { userId: user.id, type: 'INCOME', deletedAt: null },
    select: { id: true },
  });
  if (!incomeCat) throw new Error('no income category for that user');

  const created: string[] = [];
  let loanId = '';
  let incomeId = '';
  let failures = 0;
  const check = (label: string, pass: boolean, extra = '') => {
    if (!pass) failures++;
    ok(label, pass, extra);
  };

  try {
    const lent = await loans.create(user.id, {
      direction: LoanDirection.LENT,
      name: '[check] Prêt à Jean',
      principalAmount: 100000,
      initialPaidAmount: 20000,
      startDate: new Date().toISOString(),
    });
    loanId = lent.id;
    created.push(loanId);
    check('create returns the direction', lent.direction === LoanDirection.LENT);
    check('initial amount counts as settled', lent.totalPaid === 20000, `got ${lent.totalPaid}`);
    check('remaining is principal minus settled', lent.remaining === 80000, `got ${lent.remaining}`);

    // Settle part of it with an income, the way the app does.
    const income = await prisma.income.create({
      data: {
        userId: user.id,
        categoryId: incomeCat.id,
        title: '[check] remboursement Jean',
        amount: 30000,
        date: new Date(),
        loanId,
      },
      select: { id: true },
    });
    incomeId = income.id;

    const listed = (await loans.list(user.id, { direction: LoanDirection.LENT })).find(
      (l) => l.id === loanId,
    );
    check('list counts the linked income', listed?.totalPaid === 50000, `got ${listed?.totalPaid}`);
    check('list recomputes remaining', listed?.remaining === 50000, `got ${listed?.remaining}`);
    check('list counts the payment', listed?.paymentCount === 1, `got ${listed?.paymentCount}`);

    const borrowedList = await loans.list(user.id, { direction: LoanDirection.BORROWED });
    check(
      'a lent loan never appears under borrowed',
      !borrowedList.some((l) => l.id === loanId),
    );

    const detail = await loans.detail(user.id, loanId);
    check('detail reads the income side', detail.totalPaid === 50000, `got ${detail.totalPaid}`);
    check('detail groups it into a month', detail.months.length === 1);
    check(
      'detail lists the repayment',
      detail.months[0]?.payments[0]?.title === '[check] remboursement Jean',
    );

    const selectableLent = await loans.selectable(user.id, LoanDirection.LENT);
    const selectableBorrowed = await loans.selectable(user.id, LoanDirection.BORROWED);
    check('the income picker offers it', selectableLent.some((l) => l.id === loanId));
    check(
      'the expense picker does not',
      !selectableBorrowed.some((l) => l.id === loanId),
    );

    // The invariant, through the real service.
    let rejected = false;
    try {
      await loans.assertPayable(user.id, loanId, LoanDirection.BORROWED);
    } catch {
      rejected = true;
    }
    check('an expense cannot settle a lent loan', rejected);

    // Removing the loan must unlink the income but keep the row.
    await loans.remove(user.id, loanId);
    const survivor = await prisma.income.findUnique({
      where: { id: incomeId },
      select: { loanId: true, deletedAt: true },
    });
    check('the income survives the loan', survivor !== null && survivor.deletedAt === null);
    check('and is unlinked, not orphaned', survivor?.loanId === null);
  } finally {
    if (incomeId) await prisma.income.delete({ where: { id: incomeId } }).catch(() => {});
    for (const id of created) {
      await prisma.loan.delete({ where: { id } }).catch(() => {});
    }
    await prisma.$disconnect();
  }

  console.log(failures === 0 ? '\n  all checks passed' : `\n  ${failures} check(s) FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error('  ERROR:', e.message);
  process.exit(1);
});
