'use client';

import { Moon, Sun } from 'lucide-react';
import { useTheme } from 'next-themes';
import { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { useAuthStore } from '@/store/auth';

/**
 * Toggles between LIGHT and DARK. Writes to the stored `settings.theme` (the
 * single source of truth) and persists to the backend, so the topbar toggle
 * and the Settings page stay in sync. `ThemeSync` applies it to next-themes.
 */
export function ThemeToggle() {
  const { resolvedTheme } = useTheme();
  const user = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  const stored = user?.settings?.theme;
  const isDark = stored ? stored === 'DARK' : resolvedTheme === 'dark';

  const toggle = () => {
    const next: 'LIGHT' | 'DARK' = isDark ? 'LIGHT' : 'DARK';
    if (user) {
      setUser({
        ...user,
        settings: user.settings
          ? { ...user.settings, theme: next }
          : { language: 'FR', currency: 'XOF', theme: next },
      });
    }
    if (useAuthStore.getState().accessToken) {
      api.patch('/settings', { theme: next }).catch(() => {});
    }
  };

  return (
    <Button variant="outline" size="icon" onClick={toggle} aria-label="Toggle theme">
      {mounted && isDark ? <Sun /> : <Moon />}
    </Button>
  );
}
