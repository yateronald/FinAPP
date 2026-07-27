'use server';

import { cookies } from 'next/headers';
import { COOKIE_NAME, defaultLocale, locales, type Locale } from './config';

export async function getUserLocale(): Promise<Locale> {
  const store = await cookies();
  const value = store.get(COOKIE_NAME)?.value as Locale | undefined;
  return value && locales.includes(value) ? value : defaultLocale;
}

export async function setUserLocale(locale: Locale) {
  const store = await cookies();
  store.set(COOKIE_NAME, locale, { path: '/', maxAge: 60 * 60 * 24 * 365 });
}
