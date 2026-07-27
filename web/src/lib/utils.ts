import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCurrency(amount: number, currency = 'XOF', locale = 'fr-FR'): string {
  // XOF has no decimals; format as integer with thin spaces.
  const formatted = new Intl.NumberFormat(locale, {
    maximumFractionDigits: 0,
  }).format(Math.round(amount));
  const symbol = currency === 'XOF' ? 'FCFA' : currency;
  return `${formatted} ${symbol}`;
}

export function formatNumber(amount: number, locale = 'fr-FR'): string {
  return new Intl.NumberFormat(locale, { maximumFractionDigits: 0 }).format(amount);
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
