'use client';

import { useQuery } from '@tanstack/react-query';
import { api, API_URL } from '@/lib/api';
import { useAuthStore } from '@/store/auth';
import type { ReportData, ReportOverview } from '@/lib/types';

export function useReportOverview(params: ReportParams) {
  const enabled = params.period !== 'custom' || (!!params.from && !!params.to);
  return useQuery({
    queryKey: ['report-overview', params],
    queryFn: () => api.get<ReportOverview>(`/reports/overview${toQuery(params)}`),
    enabled,
  });
}

export type ReportPeriod = 'daily' | 'weekly' | 'monthly' | 'yearly' | 'custom';

export interface ReportParams {
  period: ReportPeriod;
  from?: string;
  to?: string;
}

function toQuery(params: ReportParams): string {
  const sp = new URLSearchParams();
  sp.set('period', params.period);
  if (params.period === 'custom') {
    if (params.from) sp.set('from', params.from);
    if (params.to) sp.set('to', params.to);
  }
  return `?${sp.toString()}`;
}

export function useReport(params: ReportParams) {
  const enabled = params.period !== 'custom' || (!!params.from && !!params.to);
  return useQuery({
    queryKey: ['report', params],
    queryFn: () => api.get<ReportData>(`/reports${toQuery(params)}`),
    enabled,
  });
}

export async function downloadReportCsv(params: ReportParams) {
  const token = useAuthStore.getState().accessToken;
  const res = await fetch(`${API_URL}/reports/export/csv${toQuery(params)}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    credentials: 'include',
  });
  if (!res.ok) throw new Error('Export failed');
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `fintrack-report-${params.period}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
