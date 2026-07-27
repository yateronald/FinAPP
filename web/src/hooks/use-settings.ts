'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, API_URL } from '@/lib/api';
import { useAuthStore, type AuthUser } from '@/store/auth';

export interface UserSettings {
  language: 'FR' | 'EN';
  currency: string;
  theme: 'LIGHT' | 'DARK' | 'SYSTEM';
  notificationsEnabled: boolean;
  emailNotifications: boolean;
  aiEnabled: boolean;
  aiProvider: 'GEMINI' | 'AGENTROUTER';
  geminiModel: string;
  agentRouterModel: string;
  budgetAlertThreshold: number;
  largeExpenseThreshold: number;
}

export interface AiModelOption {
  id: string;
  label: string;
}

export function useAiModels() {
  return useQuery({
    queryKey: ['ai-models'],
    queryFn: () =>
      api.get<Record<'GEMINI' | 'AGENTROUTER', AiModelOption[]>>('/ai/models'),
    staleTime: 1000 * 60 * 60,
  });
}

export function useProfile() {
  return useQuery({
    queryKey: ['profile'],
    queryFn: () => api.get<AuthUser>('/users/me'),
  });
}

export function useUpdateProfile() {
  const qc = useQueryClient();
  const setUser = useAuthStore((s) => s.setUser);
  const user = useAuthStore((s) => s.user);
  return useMutation({
    mutationFn: (data: { firstName?: string; lastName?: string }) =>
      api.patch<AuthUser>('/users/me', data),
    onSuccess: (updated) => {
      if (user) setUser({ ...user, ...updated });
      qc.invalidateQueries({ queryKey: ['profile'] });
    },
  });
}

export function useChangePassword() {
  return useMutation({
    mutationFn: (data: { currentPassword: string; newPassword: string }) =>
      api.post('/auth/change-password', data),
  });
}

export function useUserSettings() {
  return useQuery({
    queryKey: ['user-settings'],
    queryFn: () => api.get<UserSettings>('/settings'),
  });
}

// Only these fields are accepted by the backend UpdateSettingsDto.
const SETTINGS_KEYS: (keyof UserSettings)[] = [
  'language',
  'currency',
  'theme',
  'notificationsEnabled',
  'emailNotifications',
  'aiEnabled',
  'aiProvider',
  'geminiModel',
  'agentRouterModel',
  'budgetAlertThreshold',
  'largeExpenseThreshold',
];

export function useUpdateSettings() {
  const qc = useQueryClient();
  const user = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);
  return useMutation({
    mutationFn: (data: Partial<UserSettings>) => {
      // Strip server-managed fields (id, userId, timestamps) — the DTO rejects them.
      const payload: Partial<UserSettings> = {};
      for (const k of SETTINGS_KEYS) {
        if (data[k] !== undefined) (payload as any)[k] = data[k];
      }
      return api.patch<UserSettings>('/settings', payload);
    },
    onSuccess: (updated) => {
      if (user) {
        setUser({
          ...user,
          settings: {
            language: updated.language,
            currency: updated.currency,
            theme: updated.theme,
          },
        });
      }
      qc.invalidateQueries({ queryKey: ['user-settings'] });
      // Currency change affects money formatting everywhere.
      qc.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

export function useDeleteAccount() {
  return useMutation({ mutationFn: () => api.delete('/users/me') });
}

export async function exportUserData() {
  const token = useAuthStore.getState().accessToken;
  const res = await fetch(`${API_URL}/settings/export`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    credentials: 'include',
  });
  if (!res.ok) throw new Error('Export failed');
  const json = await res.json();
  const data = json?.data ?? json;
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `fintrack-data-${new Date().toISOString().slice(0, 10)}.json`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
