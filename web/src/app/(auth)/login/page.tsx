'use client';

import Link from 'next/link';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Loader2 } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useLogin } from '@/hooks/use-auth';
import { GoogleAuthButton, GoogleAuthError } from '@/components/auth/google-auth';

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});
type FormValues = z.infer<typeof schema>;

export default function LoginPage() {
  const t = useTranslations('auth');
  const login = useLogin();
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const onSubmit = (values: FormValues) => {
    login.mutate(values, {
      onError: (err: any) => toast.error(err?.message || t('loginError')),
    });
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-foreground">{t('loginTitle')}</h1>
      <p className="mt-1 text-sm text-muted-foreground">{t('loginSubtitle')}</p>

      {/* Explains a bounced Google redirect (e.g. no account yet). */}
      <div className="mt-6">
        <GoogleAuthError />
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="mt-2 space-y-4">
        <div className="space-y-2">
          <Label htmlFor="email">{t('email')}</Label>
          <Input id="email" type="email" placeholder="demo@finapp.local" {...register('email')} />
          {errors.email && <p className="text-xs text-destructive">{errors.email.message}</p>}
        </div>
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="password">{t('password')}</Label>
            <Link href="#" className="text-xs text-primary hover:underline">
              {t('forgotPassword')}
            </Link>
          </div>
          <Input id="password" type="password" placeholder="••••••••" {...register('password')} />
        </div>

        <Button type="submit" className="w-full" disabled={login.isPending}>
          {login.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
          {t('login')}
        </Button>
      </form>

      <div className="my-6 flex items-center gap-3 text-xs text-muted-foreground">
        <span className="h-px flex-1 bg-border" /> {t('or')} <span className="h-px flex-1 bg-border" />
      </div>

      <GoogleAuthButton intent="signin" label={t('continueWithGoogle')} />

      <p className="mt-6 text-center text-sm text-muted-foreground">
        {t('noAccount')}{' '}
        <Link href="/register" className="font-medium text-primary hover:underline">
          {t('signUp')}
        </Link>
      </p>
    </div>
  );
}
