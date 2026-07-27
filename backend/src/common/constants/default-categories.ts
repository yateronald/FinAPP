import { CategoryType } from '@prisma/client';

export interface DefaultCategory {
  name: string;
  type: CategoryType;
  icon: string;
  color: string;
}

export const DEFAULT_INCOME_CATEGORIES: DefaultCategory[] = [
  { name: 'Salary', type: CategoryType.INCOME, icon: 'wallet', color: '#22c55e' },
  { name: 'Freelance', type: CategoryType.INCOME, icon: 'laptop', color: '#3b82f6' },
  { name: 'Business', type: CategoryType.INCOME, icon: 'briefcase', color: '#6366f1' },
  { name: 'Bonus', type: CategoryType.INCOME, icon: 'gift', color: '#a855f7' },
  { name: 'Investment', type: CategoryType.INCOME, icon: 'trending-up', color: '#14b8a6' },
  { name: 'Gift', type: CategoryType.INCOME, icon: 'gift', color: '#ec4899' },
  { name: 'Refund', type: CategoryType.INCOME, icon: 'rotate-ccw', color: '#f59e0b' },
  { name: 'Other', type: CategoryType.INCOME, icon: 'circle', color: '#94a3b8' },
];

export const DEFAULT_EXPENSE_CATEGORIES: DefaultCategory[] = [
  { name: 'Housing', type: CategoryType.EXPENSE, icon: 'home', color: '#6366f1' },
  { name: 'Food', type: CategoryType.EXPENSE, icon: 'utensils', color: '#22c55e' },
  { name: 'Transport', type: CategoryType.EXPENSE, icon: 'car', color: '#f59e0b' },
  { name: 'Shopping', type: CategoryType.EXPENSE, icon: 'shopping-bag', color: '#ec4899' },
  { name: 'Internet', type: CategoryType.EXPENSE, icon: 'wifi', color: '#0ea5e9' },
  { name: 'Utilities', type: CategoryType.EXPENSE, icon: 'zap', color: '#eab308' },
  { name: 'Entertainment', type: CategoryType.EXPENSE, icon: 'film', color: '#a855f7' },
  { name: 'Education', type: CategoryType.EXPENSE, icon: 'book-open', color: '#3b82f6' },
  { name: 'Healthcare', type: CategoryType.EXPENSE, icon: 'heart-pulse', color: '#ef4444' },
  { name: 'Travel', type: CategoryType.EXPENSE, icon: 'plane', color: '#14b8a6' },
  { name: 'Family', type: CategoryType.EXPENSE, icon: 'users', color: '#f97316' },
  { name: 'Charity', type: CategoryType.EXPENSE, icon: 'hand-heart', color: '#84cc16' },
  { name: 'Investment', type: CategoryType.EXPENSE, icon: 'trending-up', color: '#10b981' },
  { name: 'Taxes', type: CategoryType.EXPENSE, icon: 'receipt', color: '#64748b' },
  { name: 'Other', type: CategoryType.EXPENSE, icon: 'circle', color: '#94a3b8' },
];

export const ALL_DEFAULT_CATEGORIES = [
  ...DEFAULT_INCOME_CATEGORIES,
  ...DEFAULT_EXPENSE_CATEGORIES,
];
