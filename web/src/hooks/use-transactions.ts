'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import type { ExpenseOverview, IncomeOverview, Paginated, Transaction } from '@/lib/types';

export function useIncomeOverview(from: string, to: string) {
  return useQuery({
    queryKey: ['income-overview', from, to],
    queryFn: () => api.get<IncomeOverview>(`/income/overview?from=${from}&to=${to}`),
  });
}

export function useExpenseOverview(from: string, to: string) {
  return useQuery({
    queryKey: ['expense-overview', from, to],
    queryFn: () => api.get<ExpenseOverview>(`/expenses/overview?from=${from}&to=${to}`),
  });
}

export interface TransactionFilters {
  categoryId?: string;
  from?: string;
  to?: string;
  search?: string;
  tag?: string;
  page?: number;
  limit?: number;
}

function toQuery(filters: TransactionFilters): string {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([k, v]) => {
    if (v !== undefined && v !== '' && v !== null) params.set(k, String(v));
  });
  const qs = params.toString();
  return qs ? `?${qs}` : '';
}

export interface IncomeInput {
  title: string;
  categoryId: string;
  amount: number;
  date: string;
  description?: string;
  isRecurring?: boolean;
}

export interface ExpenseInput {
  title: string;
  categoryId: string;
  amount: number;
  date: string;
  description?: string;
  paymentMethod?: string;
  tags?: string[];
}

function invalidateAll(qc: ReturnType<typeof useQueryClient>) {
  qc.invalidateQueries({ queryKey: ['income'] });
  qc.invalidateQueries({ queryKey: ['expenses'] });
  qc.invalidateQueries({ queryKey: ['dashboard'] });
  qc.invalidateQueries({ queryKey: ['budgets'] });
}

/* ---------------------------------------------------------------- Income */
export function useIncomeList(filters: TransactionFilters) {
  return useQuery({
    queryKey: ['income', filters],
    queryFn: () => api.get<Paginated<Transaction>>(`/income${toQuery(filters)}`),
  });
}

export function useIncomeMutations() {
  const qc = useQueryClient();
  const done = () => invalidateAll(qc);
  return {
    create: useMutation({ mutationFn: (d: IncomeInput) => api.post('/income', d), onSuccess: done }),
    update: useMutation({
      mutationFn: ({ id, ...d }: { id: string } & Partial<IncomeInput>) =>
        api.patch(`/income/${id}`, d),
      onSuccess: done,
    }),
    remove: useMutation({ mutationFn: (id: string) => api.delete(`/income/${id}`), onSuccess: done }),
  };
}

/* -------------------------------------------------------------- Expenses */
export function useExpenseList(filters: TransactionFilters) {
  return useQuery({
    queryKey: ['expenses', filters],
    queryFn: () => api.get<Paginated<Transaction>>(`/expenses${toQuery(filters)}`),
  });
}

export function useExpenseMutations() {
  const qc = useQueryClient();
  const done = () => invalidateAll(qc);
  return {
    create: useMutation({ mutationFn: (d: ExpenseInput) => api.post('/expenses', d), onSuccess: done }),
    update: useMutation({
      mutationFn: ({ id, ...d }: { id: string } & Partial<ExpenseInput>) =>
        api.patch(`/expenses/${id}`, d),
      onSuccess: done,
    }),
    remove: useMutation({
      mutationFn: (id: string) => api.delete(`/expenses/${id}`),
      onSuccess: done,
    }),
  };
}
