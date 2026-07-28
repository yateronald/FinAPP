'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  Activity,
  Bell,
  ChevronDown,
  LayoutGrid,
  LogOut,
  ScrollText,
  ShieldCheck,
  Users,
} from 'lucide-react';
import { useAuthStore } from '@/store/auth';
import { ThemeSync } from '@/components/layout/theme-sync';
import { cn } from '@/lib/utils';

const NAV = [
  { href: '/admin', label: 'Vue d’ensemble', icon: LayoutGrid, exact: true },
  { href: '/admin/users', label: 'Utilisateurs', icon: Users },
  { href: '/admin/admins', label: 'Administrateurs', icon: ShieldCheck },
  { href: '/admin/audit', label: 'Journal d’audit', icon: ScrollText },
];

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return '?';
  return (parts[0][0] + (parts[1]?.[0] ?? '')).toUpperCase();
}

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const user = useAuthStore((s) => s.user);
  const clear = useAuthStore((s) => s.clear);

  useEffect(() => {
    const { accessToken, user: u } = useAuthStore.getState();
    if (!accessToken) router.replace('/login');
    else if (u?.role !== 'ADMIN') router.replace('/dashboard');
    else setReady(true);
  }, [router]);

  if (!ready) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-muted/40">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    );
  }

  const fullName =
    [user?.firstName, user?.lastName].filter(Boolean).join(' ') || user?.email || 'Admin';

  const logout = () => {
    clear();
    router.replace('/login');
  };

  return (
    /* h-screen + overflow-hidden pins the shell to the viewport so only <main>
       scrolls — the sidebar and topbar stay put. */
    <div className="h-screen overflow-hidden bg-muted/40 p-0 lg:p-4">
      <ThemeSync />
      <div className="flex h-full overflow-hidden bg-background lg:rounded-3xl lg:shadow-xl lg:ring-1 lg:ring-border">
        {/* ---------------------------------------------------------- Sidebar */}
        <aside className="hidden h-full w-[220px] shrink-0 flex-col border-r border-border bg-card md:flex">
          <div className="flex shrink-0 items-center gap-2.5 px-4 py-4">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary shadow-md shadow-primary/30">
              <Activity className="h-[18px] w-[18px] text-primary-foreground" />
            </div>
            <div className="leading-tight">
              <p className="text-[13px] font-extrabold">Fynexa</p>
              <p className="text-[10px] font-medium text-muted-foreground">Administration</p>
            </div>
          </div>

          <nav className="min-h-0 flex-1 space-y-1 overflow-y-auto px-3 pt-2">
            {NAV.map((item) => {
              const active = item.exact ? pathname === item.href : pathname.startsWith(item.href);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    'flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-[13px] font-semibold transition',
                    active
                      ? 'bg-primary text-primary-foreground shadow-md shadow-primary/25'
                      : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                  )}
                >
                  <item.icon className="h-4 w-4 shrink-0" />
                  {item.label}
                </Link>
              );
            })}
          </nav>

          {/* Account card */}
          <div className="relative m-3 shrink-0 border-t border-border pt-3">
            {menuOpen && (
              <div className="absolute bottom-full left-0 mb-2 w-full overflow-hidden rounded-xl border border-border bg-card shadow-lg">
                <button
                  onClick={logout}
                  className="flex w-full items-center gap-2 px-3 py-2.5 text-[13px] font-semibold text-destructive transition hover:bg-destructive/10"
                >
                  <LogOut className="h-3.5 w-3.5" />
                  Se déconnecter
                </button>
              </div>
            )}
            <button
              onClick={() => setMenuOpen((v) => !v)}
              className="flex w-full items-center gap-2.5 rounded-xl px-2 py-1.5 transition hover:bg-muted"
            >
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/15 text-[10px] font-extrabold text-primary">
                {initials(fullName)}
              </span>
              <span className="min-w-0 flex-1 text-left leading-tight">
                <span className="block truncate text-xs font-bold">{fullName}</span>
                <span className="block text-[10px] text-muted-foreground">Super Admin</span>
              </span>
              <ChevronDown className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
            </button>
          </div>
        </aside>

        {/* ------------------------------------------------------------- Main */}
        <div className="flex min-w-0 flex-1 flex-col overflow-hidden">
          <header className="flex shrink-0 items-center justify-end gap-2 px-5 py-3">
            <button className="relative rounded-full p-1.5 text-muted-foreground transition hover:bg-muted hover:text-foreground">
              <Bell className="h-[18px] w-[18px]" />
            </button>
            <span className="flex h-8 w-8 items-center justify-center rounded-full bg-foreground text-[10px] font-extrabold text-background">
              {initials(fullName)}
            </span>
          </header>
          <main className="min-w-0 flex-1 overflow-y-auto overflow-x-hidden px-5 pb-6">
            {children}
          </main>
        </div>
      </div>
    </div>
  );
}
