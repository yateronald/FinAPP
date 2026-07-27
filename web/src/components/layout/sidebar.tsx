'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useTranslations } from 'next-intl';
import { LayoutDashboard, MoreVertical, PiggyBank, TrendingDown, TrendingUp } from 'lucide-react';
import { cn, formatCurrency } from '@/lib/utils';
import { useAuthStore } from '@/store/auth';
import { useDashboardData } from '@/hooks/use-dashboard';
import { useNavGroups } from './use-nav';

export function Sidebar() {
  const pathname = usePathname();
  const t = useTranslations('nav');
  const tc = useTranslations('common');
  const td = useTranslations('dashboard');
  const user = useAuthStore((s) => s.user);
  const { data } = useDashboardData();
  const currency = user?.settings?.currency || 'XOF';

  const fullName = [user?.firstName, user?.lastName].filter(Boolean).join(' ') || user?.email || '';
  const groups = useNavGroups();

  return (
    <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col bg-sidebar px-4 py-6 text-sidebar-foreground lg:flex">
      {/* Logo */}
      <div className="mb-6 flex items-center gap-2.5 px-2">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.png" alt="Fynexa" className="h-9 w-9" />
        <span className="text-lg font-bold text-white">Fynexa</span>
      </div>

      {/* Dashboard button */}
      <Link
        href="/dashboard"
        className={cn(
          'mb-6 flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold transition-colors',
          pathname === '/dashboard'
            ? 'bg-sidebar-accent text-white shadow-md'
            : 'bg-white/5 text-sidebar-foreground hover:bg-white/10 hover:text-white',
        )}
      >
        <LayoutDashboard className="h-[18px] w-[18px]" />
        {t('dashboard')}
      </Link>

      <nav className="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto">
        {groups.map((group) => (
          <div key={group.label}>
            <p className="mb-1.5 px-3 text-[10px] font-bold tracking-widest text-sidebar-foreground/40">
              {group.label}
            </p>
            <ul className="space-y-0.5">
              {group.items.map((item) => {
                const base = item.href.split('#')[0];
                const active = pathname === base;
                const Icon = item.icon;
                return (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className={cn(
                        'flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors',
                        active
                          ? 'bg-white/10 text-white'
                          : 'text-sidebar-foreground/80 hover:bg-white/5 hover:text-white',
                      )}
                    >
                      <Icon className={cn('h-[17px] w-[17px]', item.color)} />
                      {item.label}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>

      {/* Bottom pinned section */}
      <div className="mt-4 shrink-0 space-y-3">
        {/* Quick view */}
        <div className="rounded-xl bg-white/5 p-3">
          <div className="mb-2 flex items-center justify-between">
            <span className="text-xs font-semibold text-white">{t('quickView')}</span>
            <span className="rounded-md bg-white/10 px-2 py-0.5 text-[10px] text-sidebar-foreground">
              {tc('thisMonth')}
            </span>
          </div>
          <ul className="space-y-1.5 text-xs">
            <li className="flex items-center justify-between">
              <span className="flex items-center gap-1.5 text-sidebar-foreground/80">
                <TrendingUp className="h-3 w-3 text-emerald-400" /> {t('income')}
              </span>
              <span className="font-semibold text-white">
                {formatCurrency(data?.summary.totalIncome ?? 0, currency)}
              </span>
            </li>
            <li className="flex items-center justify-between">
              <span className="flex items-center gap-1.5 text-sidebar-foreground/80">
                <TrendingDown className="h-3 w-3 text-red-400" /> {t('expenses')}
              </span>
              <span className="font-semibold text-white">
                {formatCurrency(data?.summary.totalExpenses ?? 0, currency)}
              </span>
            </li>
            <li className="flex items-center justify-between">
              <span className="flex items-center gap-1.5 text-sidebar-foreground/80">
                <PiggyBank className="h-3 w-3 text-sky-400" /> {td('netSavings')}
              </span>
              <span className="font-semibold text-white">
                {formatCurrency(data?.summary.netSavings ?? 0, currency)}
              </span>
            </li>
          </ul>
        </div>

        {/* Profile card */}
        <Link
          href="/settings"
          className="flex items-center gap-3 rounded-xl bg-white/5 p-3 transition-colors hover:bg-white/10"
        >
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-sidebar-accent text-sm font-bold text-white">
            {fullName.slice(0, 1).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold text-white">{fullName}</p>
            <p className="text-[11px] text-sidebar-foreground/60">{t('viewProfile')}</p>
          </div>
          <MoreVertical className="h-4 w-4 text-sidebar-foreground/50" />
        </Link>
      </div>
    </aside>
  );
}
