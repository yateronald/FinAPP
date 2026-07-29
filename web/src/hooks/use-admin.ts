'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';

export interface AdminUser {
  id: string;
  email: string;
  firstName: string | null;
  lastName: string | null;
  role: 'USER' | 'ADMIN';
  isActive: boolean;
  emailVerified: boolean;
  mustChangePassword: boolean;
  disabledAt: string | null;
  disabledReason: string | null;
  lastLoginAt: string | null;
  createdAt: string;
  country: string | null;
}

export interface AdminStats {
  users: {
    total: number;
    active: number;
    disabled: number;
    admins: number;
    unverified: number;
    newLast30: number;
    activeLast7: number;
  };
  usage: {
    expenses: number;
    incomes: number;
    budgets: number;
    notifications: number;
    registeredDevices: number;
    aiInsights: number;
  };
  signupsByDay: { date: string; count: number }[];
  trends: { total: number[]; active: number[]; disabled: number[]; admins: number[] };
  /** Actions the server will actually accept — password reset needs SMTP. */
  capabilities?: { passwordReset: boolean };
}

export interface AuditEntry {
  id: string;
  action: string;
  entity: string;
  entityId: string | null;
  metadata: Record<string, unknown> | null;
  ipAddress: string | null;
  createdAt: string;
  user: { id: string; email: string; firstName: string | null } | null;
}

interface Paged<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  pages: number;
}

export function useAdminStats() {
  return useQuery({
    queryKey: ['admin', 'stats'],
    queryFn: () => api.get<AdminStats>('/admin/stats'),
    refetchInterval: 30_000, // keep the monitoring view fresh
  });
}

export function useAdminUsers(params: {
  search?: string;
  role?: string;
  isActive?: boolean;
  page?: number;
  limit?: number;
}) {
  const qs = new URLSearchParams();
  if (params.search) qs.set('search', params.search);
  if (params.role) qs.set('role', params.role);
  if (params.isActive !== undefined) qs.set('isActive', String(params.isActive));
  qs.set('page', String(params.page ?? 1));
  qs.set('limit', String(params.limit ?? 10));
  return useQuery({
    queryKey: ['admin', 'users', params],
    queryFn: () => api.get<Paged<AdminUser>>(`/admin/users?${qs.toString()}`),
  });
}

export function useAdminUserDetail(id: string | null) {
  return useQuery({
    queryKey: ['admin', 'user', id],
    queryFn: () =>
      api.get<{
        user: AdminUser;
        activity: {
          expenses: number;
          incomes: number;
          budgets: number;
          devices: number;
          activeSessions: number;
        };
        recentAdminActions: AuditEntry[];
      }>(`/admin/users/${id}`),
    enabled: !!id,
  });
}

export function useToggleUserActive() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, active, reason }: { id: string; active: boolean; reason?: string }) =>
      active
        ? api.patch(`/admin/users/${id}/enable`, {})
        : api.patch(`/admin/users/${id}/disable`, { reason }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin'] });
    },
  });
}

export function useResetUserPassword() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      api.post<{ email: string; temporaryPassword: string; message: string }>(
        `/admin/users/${id}/reset-password`,
        {},
      ),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin'] }),
  });
}

export function useAdmins() {
  return useQuery({
    queryKey: ['admin', 'admins'],
    queryFn: () => api.get<AdminUser[]>('/admin/admins'),
  });
}

export function useCreateAdmin() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: {
      email: string;
      password: string;
      firstName?: string;
      lastName?: string;
    }) => api.post<AdminUser>('/admin/admins', data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin'] }),
  });
}

export interface AuditStats {
  from: string;
  to: string;
  total: number;
  sensitive: number;
  logins: number;
  failures: number;
  shares: { total: number; sensitive: number; logins: number; failures: number };
  series: { total: number[]; sensitive: number[]; logins: number[]; failures: number[] };
}

export function useAuditStats(range: { from?: string; to?: string }) {
  const qs = new URLSearchParams();
  if (range.from) qs.set('from', range.from);
  if (range.to) qs.set('to', range.to);
  return useQuery({
    queryKey: ['admin', 'audit-stats', range],
    queryFn: () => api.get<AuditStats>(`/admin/audit-stats?${qs.toString()}`),
  });
}

export function useAuditLogs(params: {
  page?: number;
  limit?: number;
  from?: string;
  to?: string;
  action?: string;
}) {
  const qs = new URLSearchParams();
  qs.set('page', String(params.page ?? 1));
  qs.set('limit', String(params.limit ?? 10));
  if (params.from) qs.set('from', params.from);
  if (params.to) qs.set('to', params.to);
  if (params.action) qs.set('action', params.action);
  return useQuery({
    queryKey: ['admin', 'audit', params],
    queryFn: () => api.get<Paged<AuditEntry>>(`/admin/audit-logs?${qs.toString()}`),
  });
}
