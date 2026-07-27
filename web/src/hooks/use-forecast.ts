'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import type { Forecast } from '@/lib/types';

export function useForecast(horizon: number) {
  return useQuery({
    queryKey: ['forecast', horizon],
    queryFn: () => api.get<Forecast>(`/ai/forecast?horizon=${horizon}`),
    staleTime: 5 * 60 * 1000,
  });
}
