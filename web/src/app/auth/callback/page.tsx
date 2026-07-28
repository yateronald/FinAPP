'use client';

import { Suspense, useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Loader2 } from 'lucide-react';
import { api } from '@/lib/api';
import { useAuthStore, type AuthUser } from '@/store/auth';

/**
 * Landing point for the Google OAuth redirect.
 *
 * The backend finishes the code exchange server-side and sends the user here
 * with a short-lived access token in the query string. We store it, fetch the
 * profile, and replace the URL so the token never lingers in history.
 */
function CallbackInner() {
  const router = useRouter();
  const params = useSearchParams();
  const setAuth = useAuthStore((s) => s.setAuth);
  const [error, setError] = useState<string | null>(null);
  // React 18 StrictMode mounts effects twice in dev; without this the profile
  // fetch fires twice and the second one races the redirect.
  const handled = useRef(false);

  useEffect(() => {
    if (handled.current) return;
    handled.current = true;

    const token = params.get('token');
    if (!token) {
      router.replace('/login?error=GOOGLE_SIGNIN_FAILED');
      return;
    }

    (async () => {
      try {
        // setAuth first so the api client attaches the bearer token.
        setAuth({ id: '', email: '' } as AuthUser, token);
        const me = await api.get<AuthUser & { mustChangePassword?: boolean }>('/users/me');
        setAuth(me, token);

        if (me.mustChangePassword) {
          router.replace('/change-password');
          return;
        }
        router.replace(me.role === 'ADMIN' ? '/admin' : '/dashboard');
      } catch {
        setError('signin-failed');
      }
    })();
  }, [params, router, setAuth]);

  if (error) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 px-6 text-center">
        <p className="text-sm text-muted-foreground">
          We could not complete your Google sign-in.
        </p>
        <a href="/login" className="text-sm font-medium text-primary hover:underline">
          Back to sign in
        </a>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-3">
      <Loader2 className="h-7 w-7 animate-spin text-primary" />
      <p className="text-sm text-muted-foreground">Signing you in…</p>
    </div>
  );
}

export default function AuthCallbackPage() {
  // useSearchParams requires a Suspense boundary in the app router.
  return (
    <Suspense
      fallback={
        <div className="flex min-h-screen items-center justify-center">
          <Loader2 className="h-7 w-7 animate-spin text-primary" />
        </div>
      }
    >
      <CallbackInner />
    </Suspense>
  );
}
