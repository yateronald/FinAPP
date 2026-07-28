'use client';

import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { AlertCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? '';

/**
 * Starts the Google redirect flow, carrying the user's intent.
 *
 * `intent` matters: the backend refuses to create an account from the sign-in
 * screen, or to sign in from the sign-up screen, so a mistyped address surfaces
 * as a clear message instead of a silently-created empty account.
 */
export function GoogleAuthButton({
  intent,
  label,
}: {
  intent: 'signin' | 'signup';
  label: string;
}) {
  return (
    <Button variant="outline" className="w-full gap-2" asChild>
      <a href={`${API_URL}/auth/google?intent=${intent}`}>
        <GoogleGlyph />
        {label}
      </a>
    </Button>
  );
}

/**
 * Renders the reason a Google sign-in bounced back, with a link to the screen
 * that actually resolves it.
 */
export function GoogleAuthError() {
  const params = useSearchParams();
  const code = params.get('error');
  const email = params.get('email');
  if (!code) return null;

  let message: string;
  let action: { href: string; label: string } | null = null;

  switch (code) {
    case 'ACCOUNT_NOT_FOUND':
      message = email
        ? `There is no account for ${email} yet.`
        : 'There is no account for that Google address yet.';
      action = { href: '/register', label: 'Create an account' };
      break;
    case 'ACCOUNT_EXISTS':
      message = email
        ? `An account already exists for ${email}.`
        : 'An account already exists for that address.';
      action = { href: '/login', label: 'Sign in instead' };
      break;
    case 'GOOGLE_EMAIL_UNVERIFIED':
      message = 'Your Google email address is not verified.';
      break;
    case 'ACCOUNT_DISABLED':
      message = 'This account has been disabled. Contact an administrator.';
      break;
    default:
      message = 'We could not complete your Google sign-in. Please try again.';
  }

  return (
    <div className="mb-5 flex items-start gap-3 rounded-xl border border-destructive/30 bg-destructive/5 p-3.5">
      <AlertCircle className="mt-0.5 h-4 w-4 shrink-0 text-destructive" />
      <div className="text-sm">
        <p className="text-foreground">{message}</p>
        {action && (
          <Link
            href={action.href}
            className="mt-1 inline-block font-medium text-primary hover:underline"
          >
            {action.label}
          </Link>
        )}
      </div>
    </div>
  );
}

function GoogleGlyph() {
  return (
    <svg width="17" height="17" viewBox="0 0 48 48" aria-hidden="true">
      <path
        fill="#EA4335"
        d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
      />
      <path
        fill="#4285F4"
        d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
      />
      <path
        fill="#FBBC05"
        d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"
      />
      <path
        fill="#34A853"
        d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
      />
    </svg>
  );
}
