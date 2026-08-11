import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { isKnownCurrency } from './currencies';
import { FxService } from './fx.service';

/** The columns a money-holding row stores, whatever table it lives in. */
export interface MoneyFields {
  /** Always in the user's base currency — what every total and budget sums. */
  amount: number;
  originalAmount: number | null;
  originalCurrency: string | null;
  fxRate: number | null;
  fxRateAt: Date | null;
}

export interface MoneyWriteResult extends MoneyFields {
  /** The user's base currency at the time of the write. */
  baseCurrency: string;
  /** True when the entry was converted rather than entered in the base. */
  converted: boolean;
  /**
   * Set when the user asked for a foreign currency but no rate was available,
   * so the amount was taken as already being in the base currency. The caller
   * surfaces this so the user is told rather than silently misled.
   */
  fallbackReason?: 'rates-unavailable' | 'unknown-currency';
}

/**
 * Turns "the user typed 40 EUR" into the columns a row actually stores.
 *
 * Every money-holding service goes through here so the rule is written once:
 * `amount` is the value in the base currency, and the rate that produced it is
 * frozen alongside. Freezing is the whole point — a receipt entered in January
 * must still be worth what it was worth in January after rates move.
 *
 * It never throws. If rates are missing the amount is kept as-is and a reason
 * is returned, because refusing to save a transaction because a free exchange
 * rate API is down would be a worse failure than an unconverted amount.
 */
@Injectable()
export class MoneyWriterService {
  private readonly logger = new Logger(MoneyWriterService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fx: FxService,
  ) {}

  /** The user's chosen base currency, defaulting to the app's own default. */
  async baseCurrencyOf(userId: string): Promise<string> {
    const settings = await this.prisma.userSettings.findUnique({
      where: { userId },
      select: { currency: true },
    });
    return settings?.currency?.toUpperCase() || 'XOF';
  }

  /**
   * [entered] is what the user typed, in [enteredCurrency]. Passing no
   * currency — or the base currency — means no conversion and no provenance,
   * which is the common case and keeps those columns null.
   */
  async prepare(
    userId: string,
    entered: number,
    enteredCurrency?: string | null,
  ): Promise<MoneyWriteResult> {
    const base = await this.baseCurrencyOf(userId);
    const code = enteredCurrency?.toUpperCase();

    const plain: MoneyWriteResult = {
      amount: this.round(entered),
      originalAmount: null,
      originalCurrency: null,
      fxRate: null,
      fxRateAt: null,
      baseCurrency: base,
      converted: false,
    };

    if (!code || code === base) return plain;

    if (!isKnownCurrency(code)) {
      // A code we do not recognise is a client bug or tampering. Storing the
      // amount unconverted is safe; inventing a rate would not be.
      this.logger.warn(`Unknown currency ${code} from user ${userId}`);
      return { ...plain, fallbackReason: 'unknown-currency' };
    }

    const conversion = await this.fx.convert(entered, code, base);
    if (conversion.quality === 'unavailable') {
      return { ...plain, fallbackReason: 'rates-unavailable' };
    }

    return {
      amount: this.round(conversion.amount),
      // The original keeps more precision than the base amount: it is the
      // record of what was typed, not a rounded presentation of it.
      originalAmount: entered,
      originalCurrency: code,
      fxRate: conversion.rate,
      fxRateAt: conversion.rateAt,
      baseCurrency: base,
      converted: true,
    };
  }

  /** The subset written to a row — `baseCurrency` and flags are for the caller. */
  toColumns(result: MoneyWriteResult): MoneyFields {
    return {
      amount: result.amount,
      originalAmount: result.originalAmount,
      originalCurrency: result.originalCurrency,
      fxRate: result.fxRate,
      fxRateAt: result.fxRateAt,
    };
  }

  /** Money is stored to 2dp; rounding here keeps client and database in step. */
  private round(v: number): number {
    return Number.isFinite(v) ? Math.round(v * 100) / 100 : 0;
  }
}
