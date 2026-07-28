import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface AuthUser {
  id: string;
  email: string;
  firstName?: string | null;
  lastName?: string | null;
  avatarUrl?: string | null;
  role: string;
  emailVerified: boolean;
  /** Set after an admin resets the password — forces a change before any use. */
  mustChangePassword?: boolean;
  settings?: {
    language: 'FR' | 'EN';
    currency: string;
    theme: 'LIGHT' | 'DARK' | 'SYSTEM';
  } | null;
}

interface AuthState {
  user: AuthUser | null;
  accessToken: string | null;
  setAuth: (user: AuthUser, accessToken: string) => void;
  setAccessToken: (token: string) => void;
  setUser: (user: AuthUser) => void;
  clear: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      accessToken: null,
      setAuth: (user, accessToken) => set({ user, accessToken }),
      setAccessToken: (accessToken) => set({ accessToken }),
      setUser: (user) => set({ user }),
      clear: () => set({ user: null, accessToken: null }),
    }),
    {
      name: 'fintrack-auth',
      partialize: (state) => ({ user: state.user, accessToken: state.accessToken }),
    },
  ),
);
