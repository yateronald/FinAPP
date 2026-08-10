import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/**
 * Amounts are stored as Decimal(14, 2), so the display has to be able to carry
 * two decimals. Rounding here used to hide the cents that had just been saved,
 * which made decimal entry look broken even when it worked.
 *
 * Whole amounts stay clean — 2000 reads "2 000", not "2 000,00". Most amounts
 * in XOF are whole, and padding all of them makes the real decimals harder to
 * spot.
 */
function fractionDigits(amount: number): number {
  return Number.isInteger(amount) ? 0 : 2;
}

export function formatCurrency(amount: number, currency = 'XOF', locale = 'fr-FR'): string {
  const digits = fractionDigits(amount);
  const formatted = new Intl.NumberFormat(locale, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(amount);
  const symbol = currency === 'XOF' ? 'FCFA' : currency;
  return `${formatted} ${symbol}`;
}

export function formatNumber(amount: number, locale = 'fr-FR'): string {
  const digits = fractionDigits(amount);
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(amount);
}

export function formatDate(date: string | Date, locale = 'fr-FR'): string {
  return new Intl.DateTimeFormat(locale, {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(new Date(date));
}

export function formatPercent(value: number): string {
  const sign = value > 0 ? '+' : '';
  return `${sign}${value}%`;
}

export function monthYearLabel(month: number, year: number, locale = 'fr'): string {
  const label = new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-US', {
    month: 'long',
    year: 'numeric',
  }).format(new Date(Date.UTC(year, month - 1, 1)));
  return label.charAt(0).toUpperCase() + label.slice(1);
}

export function monthShort(month: number, locale = 'fr'): string {
  const label = new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-US', {
    month: 'short',
  }).format(new Date(Date.UTC(2020, month - 1, 1)));
  return label.charAt(0).toUpperCase() + label.slice(1);
}
