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
      // A password reset by an admin forces a change before anything else.
      if ((res.user as { mustChangePassword?: boolean })?.mustChangePassword) {
        router.push('/change-password');
        return;
      }
      // Admins run the monitoring dashboard, not the finance app.
      router.push(res.user?.role === 'ADMIN' ? '/admin' : '/dashboard');
    },
  });
}

export function useRegister() {
  const setAuth = useAuthStore((s) => s.setAuth);
  return useMutation({
    mutationFn: (data: {
      email: string;
      password: string;
      firstName?: string;
      lastName?: string;
      language?: string;
    }) =>
      api.post<{ email: string; requiresVerification: boolean } & Partial<LoginResponse>>(
        '/auth/register',
        data,
      ),
    onSuccess: (res) => {
      // With no mail configured the server skips the OTP and returns a session.
      if (!res.requiresVerification && res.user && res.accessToken) {
        setAuth(res.user, res.accessToken);
      }
    },
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
