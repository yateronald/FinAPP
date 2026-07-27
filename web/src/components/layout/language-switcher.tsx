'use client';

import { useTransition } from 'react';
import { useLocale } from 'next-intl';
import { setUserLocale } from '@/i18n/locale';
import { api } from '@/lib/api';
import { useAuthStore } from '@/store/auth';
import { cn } from '@/lib/utils';

export function LanguageSwitcher() {
  const locale = useLocale();
  const [isPending, startTransition] = useTransition();

  const change = (next: 'fr' | 'en') => {
    if (next === locale) return;
    startTransition(async () => {
      await setUserLocale(next);
      // Keep the stored language (used by the AI + persisted preference) in sync
      // with the UI locale, when the user is signed in.
      const user = useAuthStore.getState().user;
      if (useAuthStore.getState().accessToken) {
        try {
          await api.patch('/settings', { language: next.toUpperCase() });
          if (user) {
            useAuthStore.getState().setUser({
              ...user,
              settings: user.settings
                ? { ...user.settings, language: next.toUpperCase() as 'FR' | 'EN' }
                : null,
            });
          }
        } catch {
          /* best-effort — the cookie is still set */
        }
      }
      window.location.reload();
    });
  };

  return (
    <div
      className={cn(
        'flex items-center gap-1 rounded-lg border border-border bg-card p-0.5 text-xs font-semibold',
        isPending && 'opacity-60',
      )}
    >
      {(['fr', 'en'] as const).map((l) => (
        <button
          key={l}
          onClick={() => change(l)}
          className={cn(
            'rounded-md px-2 py-1 uppercase transition-colors',
            locale === l ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground',
          )}
        >
          {l}
        </button>
      ))}
    </div>
  );
}
