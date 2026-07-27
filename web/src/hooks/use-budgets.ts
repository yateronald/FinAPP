'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import type { BudgetStatus } from '@/lib/types';

export function useBudgets(month: number, year: number) {
  return useQuery({
    queryKey: ['budgets', month, year],
    queryFn: () => api.get<BudgetStatus[]>(`/budgets?month=${month}&year=${year}`),
  });
}

export interface BudgetInput {
  categoryId: string;
  amount: number;
  month: number;
  year: number;
}

export function useBudgetMutations() {
  const qc = useQueryClient();
  const done = () => {
    qc.invalidateQueries({ queryKey: ['budgets'] });
    qc.invalidateQueries({ queryKey: ['dashboard'] });
  };
  return {
    upsert: useMutation({ mutationFn: (d: BudgetInput) => api.put('/budgets', d), onSuccess: done }),
    remove: useMutation({ mutationFn: (id: string) => api.delete(`/budgets/${id}`), onSuccess: done }),
  };
}
