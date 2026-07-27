'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import type { Category } from '@/lib/types';

export function useCategories(type?: 'INCOME' | 'EXPENSE', includeArchived = false) {
  const params = new URLSearchParams();
  if (type) params.set('type', type);
  if (includeArchived) params.set('includeArchived', 'true');
  const qs = params.toString();
  return useQuery({
    queryKey: ['categories', type ?? 'all', includeArchived],
    queryFn: () => api.get<Category[]>(`/categories${qs ? `?${qs}` : ''}`),
  });
}

interface CategoryInput {
  name: string;
  type: 'INCOME' | 'EXPENSE';
  icon?: string;
  color?: string;
}

export function useCategoryMutations() {
  const qc = useQueryClient();
  const invalidate = () => qc.invalidateQueries({ queryKey: ['categories'] });

  const create = useMutation({
    mutationFn: (data: CategoryInput) => api.post<Category>('/categories', data),
    onSuccess: invalidate,
  });
  const update = useMutation({
    mutationFn: ({ id, ...data }: { id: string } & Partial<CategoryInput>) =>
      api.patch<Category>(`/categories/${id}`, data),
    onSuccess: invalidate,
  });
  const archive = useMutation({
    mutationFn: ({ id, archived }: { id: string; archived: boolean }) =>
      api.patch(`/categories/${id}/${archived ? 'archive' : 'unarchive'}`),
    onSuccess: invalidate,
  });
  const remove = useMutation({
    mutationFn: (id: string) => api.delete(`/categories/${id}`),
    onSuccess: invalidate,
  });

  return { create, update, archive, remove };
}
