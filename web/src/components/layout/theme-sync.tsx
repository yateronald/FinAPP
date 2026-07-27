'use client';

import { useEffect } from 'react';
import { useTheme } from 'next-themes';
import { useAuthStore } from '@/store/auth';

/**
 * Single source of truth for the theme: the user's stored `settings.theme`.
 * Whenever it changes (login on a new device, topbar toggle, settings page),
 * apply it to next-themes so the whole app reflects it consistently.
 */
export function ThemeSync() {
  const { setTheme } = useTheme();
  const theme = useAuthStore((s) => s.user?.settings?.theme);

  useEffect(() => {
    if (theme) setTheme(theme.toLowerCase()); // 'DARK' -> 'dark'
  }, [theme, setTheme]);

  return null;
}
