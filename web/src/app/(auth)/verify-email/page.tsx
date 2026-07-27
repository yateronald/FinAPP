'use client';

import { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { Loader2 } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useVerifyEmail, useResendOtp } from '@/hooks/use-auth';

function VerifyForm() {
  const t = useTranslations('auth');
  const params = useSearchParams();
  const email = params.get('email') || '';
  const verify = useVerifyEmail();
  const resend = useResendOtp();
  const { register, handleSubmit } = useForm<{ code: string }>();

  return (
    <div>
      <h1 className="text-2xl font-bold text-foreground">{t('verifyTitle')}</h1>
      <p className="mt-1 text-sm text-muted-foreground">{t('verifySubtitle')}</p>
      <p className="mt-1 text-sm font-medium text-foreground">{email}</p>

      <form
        onSubmit={handleSubmit(({ code }) =>
          verify.mutate(
            { email, code },
            { onError: (err: any) => toast.error(err?.message || 'Error') },
          ),
        )}
        className="mt-8 space-y-4"
      >
        <div className="space-y-2">
          <Label htmlFor="code">{t('verifyCode')}</Label>
          <Input
            id="code"
            inputMode="numeric"
            maxLength={6}
            placeholder="000000"
            className="text-center text-lg tracking-[0.5em]"
            {...register('code', { required: true })}
          />
        </div>
        <Button type="submit" className="w-full" disabled={verify.isPending}>
          {verify.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
          {t('verify')}
        </Button>
      </form>

      <button
        onClick={() => resend.mutate(email, { onSuccess: () => toast.success(t('resendCode')) })}
        className="mt-6 w-full text-center text-sm text-primary hover:underline"
      >
        {t('resendCode')}
      </button>
    </div>
  );
}

export default function VerifyEmailPage() {
  return (
    <Suspense fallback={null}>
      <VerifyForm />
    </Suspense>
  );
}
