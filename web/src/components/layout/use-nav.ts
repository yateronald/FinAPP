'use client';

import {
  FileBarChart,
  LayoutGrid,
  Settings,
  Sparkles,
  TrendingDown,
  TrendingUp,
  PieChart,
  type LucideIcon,
} from 'lucide-react';
import { useTranslations } from 'next-intl';

export interface NavItem {
  href: string;
  label: string;
  icon: LucideIcon;
  color: string;
}
export interface NavGroup {
  label: string;
  items: NavItem[];
}

export function useNavGroups(): NavGroup[] {
  const t = useTranslations('nav');
  return [
    {
      label: t('management'),
      items: [
        { href: '/income', label: t('income'), icon: TrendingUp, color: 'text-emerald-400' },
        { href: '/expenses', label: t('expenses'), icon: TrendingDown, color: 'text-red-400' },
        { href: '/budgets', label: t('budgets'), icon: PieChart, color: 'text-amber-400' },
        { href: '/categories', label: t('categories'), icon: LayoutGrid, color: 'text-violet-400' },
      ],
    },
    {
      label: t('analysis'),
      items: [
        { href: '/reports', label: t('reports'), icon: FileBarChart, color: 'text-sky-400' },
        { href: '/ai', label: t('aiAnalysis'), icon: Sparkles, color: 'text-fuchsia-400' },
      ],
    },
    {
      label: t('settings'),
      items: [
        { href: '/settings', label: t('preferences'), icon: Settings, color: 'text-slate-400' },
      ],
    },
  ];
}
