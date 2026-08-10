import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { LoanDirection, LoanStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { CreateLoanDto, ListLoansQueryDto, UpdateLoanDto } from './dto/loan.dto';

/** A loan plus everything derived from its linked expenses. */
export interface LoanWithProgress {
  id: string;
  name: string;
  /** BORROWED = money the user owes; LENT = money owed to the user. */
  direction: LoanDirection;
  description: string | null;
  lender: string | null;
  principalAmount: number;
  initialPaidAmount: number;
  /** initialPaidAmount + every linked expense. */
  totalPaid: number;
  remaining: number;
  /** 0–100, capped. */
  progress: number;
  startDate: string;
  expectedEndDate: string | null;
  status: LoanStatus;
  paymentCount: number;
  lastPaymentDate: string | null;
  /** Null when there is no end date, or the loan is already settled. */
  monthsRemaining: number | null;
  /** What must be repaid per month to finish on time. Null if not computable. */
  suggestedMonthlyPayment: number | null;
  isOverdue: boolean;
  createdAt: string;
}

@Injectable()
export class LoansService {
  constructor(private readonly prisma: PrismaService) {}

  private num(v: Prisma.Decimal | number | null | undefined): number {
    return v == null ? 0 : Number(v);
  }

  /** Every query is scoped to the owner — a loan id alone is never enough. */
  private async getOwned(userId: string, id: string) {
    const loan = await this.prisma.loan.findFirst({
      where: { id, userId, deletedAt: null },
    });
    if (!loan) throw new NotFoundException('Loan not found');
    return loan;
  }

  private shape(
    loan: {
      id: string;
      name: string;
      direction: LoanDirection;
      description: string | null;
      lender: string | null;
      principalAmount: Prisma.Decimal;
      initialPaidAmount: Prisma.Decimal;
      startDate: Date;
      expectedEndDate: Date | null;
      status: LoanStatus;
      createdAt: Date;
    },
    paidFromExpenses: number,
    paymentCount: number,
    lastPaymentDate: Date | null,
  ): LoanWithProgress {
    const principal = this.num(loan.principalAmount);
    const totalPaid = this.num(loan.initialPaidAmount) + paidFromExpenses;
    // Never report a negative balance: overpaying settles the loan, it does not
    // put the lender in debt to the user.
    const remaining = Math.max(0, principal - totalPaid);
    const progress = principal > 0 ? Math.min(100, (totalPaid / principal) * 100) : 0;

    const now = new Date();
    let monthsRemaining: number | null = null;
    if (loan.expectedEndDate && remaining > 0) {
      const months =
        (loan.expectedEndDate.getUTCFullYear() - now.getUTCFullYear()) * 12 +
        (loan.expectedEndDate.getUTCMonth() - now.getUTCMonth());
      monthsRemaining = Math.max(0, months);
    }

    return {
      id: loan.id,
      name: loan.name,
      direction: loan.direction,
      description: loan.description,
      lender: loan.lender,
      principalAmount: principal,
      initialPaidAmount: this.num(loan.initialPaidAmount),
      totalPaid: Math.round(totalPaid * 100) / 100,
      remaining: Math.round(remaining * 100) / 100,
      progress: Math.round(progress * 10) / 10,
      startDate: loan.startDate.toISOString(),
      expectedEndDate: loan.expectedEndDate?.toISOString() ?? null,
      // A loan repaid in full reads as settled even if the row still says
      // ACTIVE — the transactions are the source of truth, not the flag.
      status: remaining <= 0 && loan.status === LoanStatus.ACTIVE
        ? LoanStatus.PAID_OFF
        : loan.status,
      paymentCount,
      lastPaymentDate: lastPaymentDate?.toISOString() ?? null,
      monthsRemaining,
      suggestedMonthlyPayment:
        monthsRemaining && monthsRemaining > 0
          ? Math.round((remaining / monthsRemaining) * 100) / 100
          : null,
      isOverdue:
        !!loan.expectedEndDate && remaining > 0 && loan.expectedEndDate < now,
      createdAt: loan.createdAt.toISOString(),
    };
  }

  // ------------------------------------------------------------------ List
  async list(userId: string, query: ListLoansQueryDto = {}): Promise<LoanWithProgress[]> {
    const includeClosed = query.includeClosed === 'true';
    const loans = await this.prisma.loan.findMany({
      where: {
        userId,
        deletedAt: null,
        ...(query.direction ? { direction: query.direction } : {}),
        ...(query.status ? { status: query.status } : {}),
        ...(!query.status && !includeClosed ? { status: LoanStatus.ACTIVE } : {}),
      },
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
    });
    if (loans.length === 0) return [];

    // A borrowed loan is settled by expenses, a lent one by income. Both are
    // grouped in a single query each rather than N+1.
    const ids = loans.map((l) => l.id);
    const [expenseSums, incomeSums] = await Promise.all([
      this.prisma.expense.groupBy({
        by: ['loanId'],
        where: { userId, deletedAt: null, loanId: { in: ids } },
        _sum: { amount: true },
        _count: { _all: true },
        _max: { date: true },
      }),
      this.prisma.income.groupBy({
        by: ['loanId'],
        where: { userId, deletedAt: null, loanId: { in: ids } },
        _sum: { amount: true },
        _count: { _all: true },
        _max: { date: true },
      }),
    ]);
    // Merged additively rather than by overwrite: a loan whose direction was
    // corrected after the fact can carry rows on both sides, and dropping one
    // would silently under-report what has been settled.
    const byLoan = new Map<string, { total: number; count: number; last: Date | null }>();
    for (const s of [...expenseSums, ...incomeSums]) {
      if (!s.loanId) continue;
      const cur = byLoan.get(s.loanId) ?? { total: 0, count: 0, last: null };
      cur.total += this.num(s._sum.amount);
      cur.count += s._count._all;
      if (s._max.date && (!cur.last || s._max.date > cur.last)) cur.last = s._max.date;
      byLoan.set(s.loanId, cur);
    }

    return loans.map((l) => {
      const s = byLoan.get(l.id);
      return this.shape(l, s?.total ?? 0, s?.count ?? 0, s?.last ?? null);
    });
  }

  // ---------------------------------------------------------------- Detail
  /** The loan plus its payment history, grouped by month for the timeline. */
  async detail(userId: string, id: string) {
    const loan = await this.getOwned(userId, id);

    // Money owed is settled by expenses; money lent, by income.
    const select = {
      id: true,
      title: true,
      amount: true,
      date: true,
      description: true,
      category: { select: { id: true, name: true, icon: true, color: true } },
    } as const;
    const where = { userId, loanId: id, deletedAt: null };

    const payments =
      loan.direction === LoanDirection.LENT
        ? await this.prisma.income.findMany({ where, select, orderBy: { date: 'desc' } })
        : await this.prisma.expense.findMany({ where, select, orderBy: { date: 'desc' } });

    const totalSettled = payments.reduce((a, p) => a + this.num(p.amount), 0);
    const summary = this.shape(
      loan,
      totalSettled,
      payments.length,
      payments[0]?.date ?? null,
    );

    // Group into months so the client can render a timeline without regrouping.
    const months = new Map<string, { month: string; total: number; payments: any[] }>();
    for (const p of payments) {
      const key = p.date.toISOString().slice(0, 7); // YYYY-MM
      if (!months.has(key)) months.set(key, { month: key, total: 0, payments: [] });
      const bucket = months.get(key)!;
      bucket.total += this.num(p.amount);
      bucket.payments.push({
        id: p.id,
        title: p.title,
        amount: this.num(p.amount),
        date: p.date.toISOString(),
        description: p.description,
        category: p.category,
      });
    }

    return {
      ...summary,
      months: [...months.values()].map((m) => ({
        ...m,
        total: Math.round(m.total * 100) / 100,
      })),
    };
  }

  // ---------------------------------------------------------------- Create
  async create(userId: string, dto: CreateLoanDto): Promise<LoanWithProgress> {
    const direction = dto.direction ?? LoanDirection.BORROWED;
    const initial = dto.initialPaidAmount ?? 0;
    if (initial > dto.principalAmount) {
      throw new BadRequestException(
        direction === LoanDirection.LENT
          ? 'The amount already repaid to you cannot exceed the total lent.'
          : 'The amount already repaid cannot exceed the total borrowed.',
      );
    }
    if (dto.expectedEndDate && new Date(dto.expectedEndDate) < new Date(dto.startDate)) {
      throw new BadRequestException('The end date must be after the start date.');
    }

    const loan = await this.prisma.loan.create({
      data: {
        userId,
        name: dto.name.trim(),
        direction,
        description: dto.description?.trim() || null,
        lender: dto.lender?.trim() || null,
        principalAmount: new Prisma.Decimal(dto.principalAmount),
        initialPaidAmount: new Prisma.Decimal(initial),
        startDate: new Date(dto.startDate),
        expectedEndDate: dto.expectedEndDate ? new Date(dto.expectedEndDate) : null,
      },
    });
    return this.shape(loan, 0, 0, null);
  }

  // ---------------------------------------------------------------- Update
  async update(userId: string, id: string, dto: UpdateLoanDto): Promise<LoanWithProgress> {
    const existing = await this.getOwned(userId, id);

    const principal = dto.principalAmount ?? this.num(existing.principalAmount);
    const initial = dto.initialPaidAmount ?? this.num(existing.initialPaidAmount);
    if (initial > principal) {
      throw new BadRequestException(
        existing.direction === LoanDirection.LENT
          ? 'The amount already repaid to you cannot exceed the total lent.'
          : 'The amount already repaid cannot exceed the total borrowed.',
      );
    }

    const loan = await this.prisma.loan.update({
      where: { id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
        ...(dto.description !== undefined
          ? { description: dto.description?.trim() || null }
          : {}),
        ...(dto.lender !== undefined ? { lender: dto.lender?.trim() || null } : {}),
        ...(dto.principalAmount !== undefined
          ? { principalAmount: new Prisma.Decimal(dto.principalAmount) }
          : {}),
        ...(dto.initialPaidAmount !== undefined
          ? { initialPaidAmount: new Prisma.Decimal(dto.initialPaidAmount) }
          : {}),
        ...(dto.startDate ? { startDate: new Date(dto.startDate) } : {}),
        ...(dto.expectedEndDate !== undefined
          ? { expectedEndDate: dto.expectedEndDate ? new Date(dto.expectedEndDate) : null }
          : {}),
        ...(dto.status ? { status: dto.status } : {}),
      },
    });

    const aggArgs = {
      where: { userId, loanId: id, deletedAt: null },
      _sum: { amount: true },
      _count: { _all: true },
      _max: { date: true },
    } as const;
    const agg =
      existing.direction === LoanDirection.LENT
        ? await this.prisma.income.aggregate(aggArgs)
        : await this.prisma.expense.aggregate(aggArgs);
    return this.shape(
      loan,
      this.num(agg._sum.amount),
      agg._count._all,
      agg._max.date ?? null,
    );
  }

  // ---------------------------------------------------------------- Delete
  /**
   * Soft-deletes the loan and unlinks its transactions.
   *
   * The expenses and income themselves are kept: they are real money that
   * moved, and deleting the loan record must not rewrite the user's history.
   * Both sides are unlinked regardless of direction so no row is left pointing
   * at a deleted loan.
   */
  async remove(userId: string, id: string) {
    const loan = await this.getOwned(userId, id);

    const [unlinkedExpenses, unlinkedIncome] = await this.prisma.$transaction([
      this.prisma.expense.updateMany({
        where: { userId, loanId: id },
        data: { loanId: null },
      }),
      this.prisma.income.updateMany({
        where: { userId, loanId: id },
        data: { loanId: null },
      }),
      this.prisma.loan.update({
        where: { id },
        data: { deletedAt: new Date(), status: LoanStatus.ARCHIVED },
      }),
    ]);

    return {
      message:
        loan.direction === LoanDirection.LENT
          ? 'Loan removed. Its repayments were kept as ordinary income.'
          : 'Loan removed. Its payments were kept as ordinary expenses.',
      unlinkedPayments: unlinkedExpenses.count + unlinkedIncome.count,
    };
  }

  /**
   * Loans a transaction can be attached to: BORROWED for the expense form,
   * LENT for the income form. Filtering here means the picker can never even
   * display a loan the user is not allowed to settle from that screen.
   */
  async selectable(userId: string, direction: LoanDirection = LoanDirection.BORROWED) {
    const loans = await this.list(userId, { direction });
    return loans
      .filter((l) => l.status === LoanStatus.ACTIVE)
      .map((l) => ({
        id: l.id,
        name: l.name,
        direction: l.direction,
        remaining: l.remaining,
        progress: l.progress,
        suggestedMonthlyPayment: l.suggestedMonthlyPayment,
      }));
  }

  /**
   * Ownership and direction check for a transaction claiming to settle a loan.
   *
   * [expected] is the direction the caller is allowed to touch: an expense
   * repays money BORROWED, an income collects money LENT. Enforcing it here
   * matters — a client that sent an income against a borrowed loan would
   * silently inflate its progress, and the loan is derived entirely from these
   * transactions.
   */
  async assertPayable(
    userId: string,
    loanId: string,
    expected: LoanDirection = LoanDirection.BORROWED,
  ) {
    const loan = await this.prisma.loan.findFirst({
      where: { id: loanId, userId, deletedAt: null },
      select: { id: true, status: true, direction: true },
    });
    if (!loan) throw new BadRequestException('That loan does not exist.');
    if (loan.status === LoanStatus.ARCHIVED) {
      throw new BadRequestException('That loan is archived.');
    }
    if (loan.direction !== expected) {
      throw new BadRequestException(
        expected === LoanDirection.BORROWED
          ? 'An expense can only repay a loan you took out.'
          : 'An income can only settle money you lent out.',
      );
    }
    return loan.id;
  }
}
