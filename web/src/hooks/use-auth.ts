'use client';

import { useMutation } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { useAuthStore, type AuthUser } from '@/store/auth';

interface LoginResponse {
  user: AuthUser;
  accessToken: string;
  refreshToken: string;
}

export function useLogin() {
  const router = useRouter();
  const setAuth = useAuthStore((s) => s.setAuth);
  return useMutation({
    mutationFn: (data: { email: string; password: string }) =>
      api.post<LoginResponse>('/auth/login', data),
    onSuccess: (res) => {
      setAuth(res.user, res.accessToken);
      router.push('/dashboard');
    },
  });
}

export function useRegister() {
  return useMutation({
    mutationFn: (data: {
      email: string;
      password: string;
      firstName?: string;
      lastName?: string;
      language?: string;
    }) => api.post<{ email: string; requiresVerification: boolean }>('/auth/register', data),
  });
}

export function useVerifyEmail() {
  const router = useRouter();
  const setAuth = useAuthStore((s) => s.setAuth);
  return useMutation({
    mutationFn: (data: { email: string; code: string }) =>
      api.post<LoginResponse>('/auth/verify-email', data),
    onSuccess: (res) => {
      setAuth(res.user, res.accessToken);
      router.push('/dashboard');
    },
  });
}

export function useResendOtp() {
  return useMutation({
    mutationFn: (email: string) => api.post('/auth/resend-otp', { email }),
  });
}

export function useLogout() {
  const router = useRouter();
  const clear = useAuthStore((s) => s.clear);
  return useMutation({
    mutationFn: () => api.post('/auth/logout'),
    onSettled: () => {
      clear();
      router.push('/login');
    },
  });
}
