'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useTranslations } from 'next-intl';
import { LayoutDashboard, X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useNavGroups } from './use-nav';

export function MobileNav({ open, onClose }: { open: boolean; onClose: () => void }) {
  const pathname = usePathname();
  const t = useTranslations('nav');
  const groups = useNavGroups();

  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : '';
    return () => {
      document.body.style.overflow = '';
    };
  }, [open]);

  return (
    <div className={cn('fixed inset-0 z-50 lg:hidden', open ? '' : 'pointer-events-none')}>
      {/* Overlay */}
      <div
        className={cn(
          'absolute inset-0 bg-black/50 backdrop-blur-sm transition-opacity',
          open ? 'opacity-100' : 'opacity-0',
        )}
        onClick={onClose}
      />
      {/* Panel */}
      <aside
        className={cn(
          'absolute left-0 top-0 flex h-full w-72 max-w-[85vw] flex-col bg-sidebar px-4 py-6 text-sidebar-foreground shadow-2xl transition-transform duration-300',
          open ? 'translate-x-0' : '-translate-x-full',
        )}
      >
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/logo.png" alt="Fynexa" className="h-9 w-9" />
            <span className="text-lg font-bold text-white">Fynexa</span>
          </div>
          <button
            onClick={onClose}
            className="rounded-md p-1.5 text-sidebar-foreground/70 hover:bg-white/10 hover:text-white"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <Link
          href="/dashboard"
          onClick={onClose}
          className={cn(
            'mb-5 flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold',
            pathname === '/dashboard'
              ? 'bg-sidebar-accent text-white'
              : 'bg-white/5 text-sidebar-foreground hover:bg-white/10 hover:text-white',
          )}
        >
          <LayoutDashboard className="h-[18px] w-[18px]" />
          {t('dashboard')}
        </Link>

        <nav className="flex flex-1 flex-col gap-5 overflow-y-auto">
          {groups.map((group) => (
            <div key={group.label}>
              <p className="mb-1.5 px-3 text-[10px] font-bold tracking-widest text-sidebar-foreground/40">
                {group.label}
              </p>
              <ul className="space-y-0.5">
                {group.items.map((item) => {
                  const active = pathname === item.href;
                  const Icon = item.icon;
                  return (
                    <li key={item.href}>
                      <Link
                        href={item.href}
                        onClick={onClose}
                        className={cn(
                          'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium',
                          active
                            ? 'bg-white/10 text-white'
                            : 'text-sidebar-foreground/80 hover:bg-white/5 hover:text-white',
                        )}
                      >
                        <Icon className={cn('h-[18px] w-[18px]', item.color)} />
                        {item.label}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
        </nav>
      </aside>
    </div>
  );
}
