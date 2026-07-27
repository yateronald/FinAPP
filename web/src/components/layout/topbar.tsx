'use client';

import { useState } from 'react';
import { usePathname } from 'next/navigation';
import { Bell, LogOut, Menu } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { useQuery } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { useAuthStore } from '@/store/auth';
import { usePeriodStore } from '@/store/period';
import { useLogout } from '@/hooks/use-auth';
import { RangePicker } from './range-picker';
import { LanguageSwitcher } from './language-switcher';
import { ThemeToggle } from './theme-toggle';
import { MobileNav } from './mobile-nav';

export function Topbar() {
  const t = useTranslations('dashboard');
  const user = useAuthStore((s) => s.user);
  const range = usePeriodStore((s) => s.range);
  const setRange = usePeriodStore((s) => s.setRange);
  const logout = useLogout();
  const pathname = usePathname();
  const showRangePicker = pathname === '/dashboard';
  const [mobileOpen, setMobileOpen] = useState(false);
  const fullName =
    [user?.firstName, user?.lastName].filter(Boolean).join(' ') || user?.email?.split('@')[0] || '';

  const { data: unread } = useQuery({
    queryKey: ['notifications-unread'],
    queryFn: () => api.get<{ count: number }>('/notifications/unread-count'),
    refetchInterval: 60_000,
  });

  return (
    <>
      <MobileNav open={mobileOpen} onClose={() => setMobileOpen(false)} />
      <header className="sticky top-0 z-20 flex items-center gap-3 border-b border-border bg-background/80 px-4 py-3 backdrop-blur sm:px-6 sm:py-4">
        <div className="flex min-w-0 items-center gap-2">
          <button
            onClick={() => setMobileOpen(true)}
            className="rounded-lg border border-border p-2 text-foreground lg:hidden"
            aria-label="Menu"
          >
            <Menu className="h-5 w-5" />
          </button>
          {/* Mobile wordmark */}
          <span className="flex items-center gap-1.5 font-bold text-foreground lg:hidden">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/logo.png" alt="Fynexa" className="h-6 w-6" /> Fynexa
          </span>
          {/* Desktop greeting */}
          <div className="hidden min-w-0 lg:block">
            <h1 className="truncate text-xl font-bold text-foreground">
              {t('greeting', { name: fullName })} <span className="align-middle">👋</span>
            </h1>
            <p className="text-sm text-muted-foreground">{t('subtitle')}</p>
          </div>
        </div>

        <div className="ml-auto flex shrink-0 items-center gap-1.5 sm:gap-2">
          {showRangePicker && (
            <RangePicker value={range} onChange={setRange} className="w-36 sm:w-52" />
          )}
          <Button variant="outline" size="icon" className="relative" aria-label="Notifications">
            <Bell />
            {(unread?.count ?? 0) > 0 && (
              <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-bold text-white">
                {unread!.count}
              </span>
            )}
          </Button>
          <div className="hidden md:block">
            <LanguageSwitcher />
          </div>
          <div className="hidden sm:block">
            <ThemeToggle />
          </div>
          <Button variant="outline" size="icon" onClick={() => logout.mutate()} aria-label="Logout">
            <LogOut className="h-4 w-4" />
          </Button>
        </div>
      </header>
    </>
  );
}
