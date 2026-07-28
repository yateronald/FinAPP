'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Loader2 } from 'lucide-react';
import { useTranslations, useLocale } from 'next-intl';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useRegister } from '@/hooks/use-auth';
import { GoogleAuthButton, GoogleAuthError } from '@/components/auth/google-auth';

const schema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().optional(),
  email: z.string().email(),
  password: z.string().min(8),
});
type FormValues = z.infer<typeof schema>;

export default function RegisterPage() {
  const t = useTranslations('auth');
  const locale = useLocale();
  const router = useRouter();
  const registerMutation = useRegister();
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const onSubmit = (values: FormValues) => {
    registerMutation.mutate(
      { ...values, language: locale.toUpperCase() },
      {
        onSuccess: (res) => {
          // No verification step when the server has no mail configured.
          if (!res.requiresVerification) {
            router.push('/dashboard');
            return;
          }
          toast.success(t('verifySubtitle'));
          router.push(`/verify-email?email=${encodeURIComponent(values.email)}`);
        },
        onError: (err: any) => toast.error(err?.message || 'Error'),
      },
    );
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-foreground">{t('registerTitle')}</h1>
      <p className="mt-1 text-sm text-muted-foreground">{t('registerSubtitle')}</p>

      {/* Explains a bounced Google redirect (e.g. the account already exists). */}
      <div className="mt-6">
        <GoogleAuthError />
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="mt-8 space-y-4">
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-2">
            <Label htmlFor="firstName">{t('firstName')}</Label>
            <Input id="firstName" {...register('firstName')} />
            {errors.firstName && <p className="text-xs text-destructive">{errors.firstName.message}</p>}
          </div>
          <div className="space-y-2">
            <Label htmlFor="lastName">{t('lastName')}</Label>
            <Input id="lastName" {...register('lastName')} />
          </div>
        </div>
        <div className="space-y-2">
          <Label htmlFor="email">{t('email')}</Label>
          <Input id="email" type="email" {...register('email')} />
          {errors.email && <p className="text-xs text-destructive">{errors.email.message}</p>}
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">{t('password')}</Label>
          <Input id="password" type="password" placeholder="••••••••" {...register('password')} />
          {errors.password && <p className="text-xs text-destructive">{errors.password.message}</p>}
        </div>

        <Button type="submit" className="w-full" disabled={registerMutation.isPending}>
          {registerMutation.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
          {t('register')}
        </Button>
      </form>

      <div className="my-6 flex items-center gap-3 text-xs text-muted-foreground">
        <span className="h-px flex-1 bg-border" /> {t('or')} <span className="h-px flex-1 bg-border" />
      </div>

      <GoogleAuthButton intent="signup" label={t('continueWithGoogle')} />

      <p className="mt-6 text-center text-sm text-muted-foreground">
        {t('haveAccount')}{' '}
        <Link href="/login" className="font-medium text-primary hover:underline">
          {t('signIn')}
        </Link>
      </p>
    </div>
  );
}
