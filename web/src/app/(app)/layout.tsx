'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/store/auth';
import { Sidebar } from '@/components/layout/sidebar';
import { Topbar } from '@/components/layout/topbar';
import { ThemeSync } from '@/components/layout/theme-sync';

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const accessToken = useAuthStore((s) => s.accessToken);

  useEffect(() => {
    // Zustand persist hydrates on mount; give it a tick then guard.
    const { accessToken: token, user } = useAuthStore.getState();
    if (!token) {
      router.replace('/login');
    } else if ((user as { mustChangePassword?: boolean })?.mustChangePassword) {
      router.replace('/change-password');
    } else if (user?.role === 'ADMIN') {
      // Admins belong in the monitoring dashboard, not the finance app.
      router.replace('/admin');
    } else {
      setReady(true);
    }
  }, [router, accessToken]);

  if (!ready) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-background">
      <ThemeSync />
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar />
        <main className="flex-1 p-4 sm:p-6">{children}</main>
      </div>
    </div>
  );
}
