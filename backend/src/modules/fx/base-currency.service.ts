import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { isKnownCurrency } from './currencies';
import { FxService } from './fx.service';

export interface BaseCurrencyPreview {
  from: string;
  to: string;
  rate: number;
  rateAt: string | null;
  quality: string;
  /** How many rows the change would rewrite. */
  affectedRows: number;
  /** A worked example, so the number is concrete before it is committed. */
  sample: { before: number; after: number } | null;
  /** True once the user has changed base before — repeated changes compound. */
  previousChanges: number;
}

/**
 * Changes a user's base currency, converting everything they have recorded.
 *
 * This is the one destructive operation in the currency feature, so it is
 * deliberately explicit:
 *
 *  - every stored amount is multiplied by **one** rate, not re-derived row by
 *    row at today's price. Re-deriving would mix rates from different days and
 *    silently change the relative size of past entries; one factor keeps every
 *    total proportional, which is what "convert everything" means and what
 *    accounting systems do for a presentation-currency change;
 *  - the original amounts are never touched. They are the record of what the
 *    user actually spent, and they are what makes the change explainable;
 *  - it runs in a transaction, so a failure halfway cannot leave a ledger
 *    denominated in two currencies at once;
 *  - it is recorded in `currency_changes`, because otherwise there would be no
 *    way to explain to a user why every number moved.
 *
 * It is not exactly reversible: amounts are rounded to two decimals on each
 * pass, and the rate will differ when converting back. The preview says so.
 */
@Injectable()
export class BaseCurrencyService {
  private readonly logger = new Logger(BaseCurrencyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fx: FxService,
    private readonly audit: AuditService,
  ) {}

  private async current(userId: string): Promise<string> {
    const s = await this.prisma.userSettings.findUnique({
      where: { userId },
      select: { currency: true },
    });
    return s?.currency?.toUpperCase() || 'XOF';
  }

  /** Everything the client needs to show a confirmation the user can trust. */
  async preview(userId: string, target: string): Promise<BaseCurrencyPreview> {
    const to = target?.toUpperCase();
    const from = await this.current(userId);
    if (!isKnownCurrency(to)) throw new BadRequestException('Unknown currency.');

    const conversion = await this.fx.convert(1, from, to);
    if (conversion.quality === 'unavailable' && from !== to) {
      throw new BadRequestException(
        'Exchange rates are unavailable right now, so the conversion cannot be ' +
          'previewed. Please try again later.',
      );
    }

    const [expenses, income, loans, budgets, overall, previousChanges, sample] =
      await this.prisma.$transaction([
        this.prisma.expense.count({ where: { userId, deletedAt: null } }),
        this.prisma.income.count({ where: { userId, deletedAt: null } }),
        this.prisma.loan.count({ where: { userId, deletedAt: null } }),
        this.prisma.monthlyBudget.count({ where: { userId, deletedAt: null } }),
        this.prisma.overallBudget.count({ where: { userId, deletedAt: null } }),
        this.prisma.currencyChange.count({ where: { userId } }),
        this.prisma.expense.findFirst({
          where: { userId, deletedAt: null },
          orderBy: { date: 'desc' },
          select: { amount: true },
        }),
      ]);

    const before = sample ? Number(sample.amount) : null;
    return {
      from,
      to,
      rate: conversion.rate,
      rateAt: conversion.rateAt?.toISOString() ?? null,
      quality: conversion.quality,
      affectedRows: expenses + income + loans + budgets + overall,
      sample:
        before === null
          ? null
          : { before, after: Math.round(before * conversion.rate * 100) / 100 },
      previousChanges,
    };
  }

  /**
   * Applies the change. Returns how many rows moved, for the confirmation.
   *
   * Uses raw multiplication in SQL rather than reading and rewriting rows in
   * the API: a user with years of history could have tens of thousands of rows,
   * and pulling them through Node would be slow enough to time out mid-change.
   */
  async change(userId: string, target: string) {
    const to = target?.toUpperCase();
    const from = await this.current(userId);
    if (!isKnownCurrency(to)) throw new BadRequestException('Unknown currency.');
    if (to === from) return { changed: false, from, to, rate: 1, rowsConverted: 0 };

    const conversion = await this.fx.convert(1, from, to);
    if (conversion.quality === 'unavailable') {
      throw new BadRequestException(
        'Exchange rates are unavailable right now. Your currency has not been ' +
          'changed — nothing was modified.',
      );
    }
    const rate = conversion.rate;
    if (!Number.isFinite(rate) || rate <= 0) {
      throw new BadRequestException('The conversion rate is not usable right now.');
    }

    const r = new Prisma.Decimal(rate);

    const rowsConverted = await this.prisma.$transaction(async (tx) => {
      // Amounts only. `original_amount` is deliberately untouched: it records
      // what the user actually spent, in the currency they spent it in.
      const results = await Promise.all([
        tx.$executeRaw`UPDATE "expenses" SET "amount" = ROUND("amount" * ${r}, 2)
                       WHERE "user_id" = ${userId} AND "deleted_at" IS NULL`,
        tx.$executeRaw`UPDATE "income" SET "amount" = ROUND("amount" * ${r}, 2)
                       WHERE "user_id" = ${userId} AND "deleted_at" IS NULL`,
        tx.$executeRaw`UPDATE "loans"
                       SET "principal_amount" = ROUND("principal_amount" * ${r}, 2),
                           "initial_paid_amount" = ROUND("initial_paid_amount" * ${r}, 2)
                       WHERE "user_id" = ${userId} AND "deleted_at" IS NULL`,
        tx.$executeRaw`UPDATE "monthly_budgets" SET "amount" = ROUND("amount" * ${r}, 2)
                       WHERE "user_id" = ${userId} AND "deleted_at" IS NULL`,
        tx.$executeRaw`UPDATE "overall_budgets" SET "amount" = ROUND("amount" * ${r}, 2)
                       WHERE "user_id" = ${userId} AND "deleted_at" IS NULL`,
        // The large-expense alert threshold is money too; leaving it behind
        // would fire alerts at the wrong level in the new currency.
        tx.$executeRaw`UPDATE "user_settings"
                       SET "large_expense_threshold" = ROUND("large_expense_threshold" * ${r}, 2)
                       WHERE "user_id" = ${userId}`,
      ]);

      await tx.userSettings.update({ where: { userId }, data: { currency: to } });
      await tx.currencyChange.create({
        data: {
          userId,
          fromCurrency: from,
          toCurrency: to,
          rate: r,
          rowsConverted: results.reduce((a, n) => a + n, 0),
        },
      });

      return results.reduce((a, n) => a + n, 0);
    });

    await this.audit.log({
      userId,
      action: 'BASE_CURRENCY_CHANGED',
      entity: 'UserSettings',
      entityId: userId,
      metadata: { from, to, rate, rowsConverted },
    });
    this.logger.log(
      `User ${userId} changed base currency ${from} -> ${to} at ${rate} (${rowsConverted} rows)`,
    );

    return { changed: true, from, to, rate, rowsConverted };
  }

  /** The history behind the warning that repeated changes compound rounding. */
  history(userId: string) {
    return this.prisma.currencyChange.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
  }
}
