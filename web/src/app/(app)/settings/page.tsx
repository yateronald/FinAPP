'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useForm } from 'react-hook-form';
import {
  BadgeCheck,
  Download,
  Globe,
  Loader2,
  Lock,
  LogOut,
  Palette,
  ShieldAlert,
  Trash2,
  User,
} from 'lucide-react';
import { useLocale, useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { PageHeader } from '@/components/page-header';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { ConfirmDialog } from '@/components/confirm-dialog';
import {
  exportUserData,
  useChangePassword,
  useDeleteAccount,
  useProfile,
  useUpdateProfile,
  useAiModels,
  useUpdateSettings,
  useUserSettings,
  type UserSettings,
} from '@/hooks/use-settings';
import { useLogout } from '@/hooks/use-auth';
import { useAuthStore } from '@/store/auth';
import { api } from '@/lib/api';
import { setUserLocale } from '@/i18n/locale';
import { cn } from '@/lib/utils';

const CURRENCIES = ['XOF', 'XAF', 'EUR', 'USD', 'GBP', 'NGN', 'GHS', 'MAD', 'CAD'];

function SectionIcon({ icon: Icon, className }: { icon: typeof User; className?: string }) {
  return (
    <span className={cn('flex h-9 w-9 items-center justify-center rounded-xl', className)}>
      <Icon className="h-5 w-5" />
    </span>
  );
}

/* ------------------------------------------------------------------ Profile */
function ProfileSection() {
  const t = useTranslations('settings');
  const { data: profile, isLoading } = useProfile();
  const update = useUpdateProfile();
  const { register, handleSubmit, reset } = useForm<{ firstName: string; lastName: string }>();

  useEffect(() => {
    if (profile) reset({ firstName: profile.firstName ?? '', lastName: profile.lastName ?? '' });
  }, [profile, reset]);

  const onSubmit = (v: { firstName: string; lastName: string }) =>
    update.mutate(v, {
      onSuccess: () => toast.success(t('profileUpdated')),
      onError: (e: any) => toast.error(e?.message),
    });

  return (
    <Card>
      <CardHeader className="flex-row items-center gap-3 space-y-0">
        <SectionIcon icon={User} className="bg-primary/10 text-primary" />
        <div>
          <CardTitle>{t('profile')}</CardTitle>
          <CardDescription>{t('profileDesc')}</CardDescription>
        </div>
      </CardHeader>
      <CardContent>
        {isLoading || !profile ? (
          <Skeleton className="h-40 rounded-xl" />
        ) : (
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="firstName">{t('firstName')}</Label>
                <Input id="firstName" {...register('firstName')} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="lastName">{t('lastName')}</Label>
                <Input id="lastName" {...register('lastName')} />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="email">{t('email')}</Label>
              <div className="relative">
                <Input
                  id="email"
                  value={profile.email}
                  readOnly
                  disabled
                  className="cursor-not-allowed pr-24 opacity-70"
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2">
                  {profile.emailVerified ? (
                    <Badge variant="success" className="gap-1">
                      <BadgeCheck className="h-3 w-3" /> {t('verified')}
                    </Badge>
                  ) : (
                    <Badge variant="warning">{t('notVerified')}</Badge>
                  )}
                </span>
              </div>
              <p className="text-xs text-muted-foreground">{t('emailReadonly')}</p>
            </div>
            <Button type="submit" disabled={update.isPending}>
              {update.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
              {t('saveProfile')}
            </Button>
          </form>
        )}
      </CardContent>
    </Card>
  );
}

/* ----------------------------------------------------------------- Security */
function strengthOf(pw: string): { score: number; label: 'weak' | 'medium' | 'strong' } {
  let s = 0;
  if (pw.length >= 8) s++;
  if (pw.length >= 12) s++;
  if (/[A-Z]/.test(pw) && /[a-z]/.test(pw)) s++;
  if (/\d/.test(pw)) s++;
  if (/[^A-Za-z0-9]/.test(pw)) s++;
  if (s <= 2) return { score: s, label: 'weak' };
  if (s <= 3) return { score: s, label: 'medium' };
  return { score: s, label: 'strong' };
}

function SecuritySection() {
  const t = useTranslations('settings');
  const change = useChangePassword();
  const logout = useLogout();
  const {
    register,
    handleSubmit,
    watch,
    reset,
    formState: { errors },
  } = useForm<{ currentPassword: string; newPassword: string; confirmPassword: string }>();

  const newPw = watch('newPassword') || '';
  const strength = strengthOf(newPw);

  const onSubmit = (v: {
    currentPassword: string;
    newPassword: string;
    confirmPassword: string;
  }) => {
    if (v.newPassword.length < 8) {
      toast.error(t('passwordTooShort'));
      return;
    }
    if (v.newPassword !== v.confirmPassword) {
      toast.error(t('passwordMismatch'));
      return;
    }
    change.mutate(
      { currentPassword: v.currentPassword, newPassword: v.newPassword },
      {
        onSuccess: () => {
          toast.success(t('passwordChanged'));
          reset();
          // Backend revokes all tokens → log out and back to login.
          setTimeout(() => logout.mutate(), 1200);
        },
        onError: (e: any) => toast.error(e?.message),
      },
    );
  };

  const strengthColor = { weak: 'bg-destructive', medium: 'bg-amber-500', strong: 'bg-emerald-500' }[
    strength.label
  ];

  return (
    <Card>
      <CardHeader className="flex-row items-center gap-3 space-y-0">
        <SectionIcon icon={Lock} className="bg-amber-500/15 text-amber-500" />
        <div>
          <CardTitle>{t('security')}</CardTitle>
          <CardDescription>{t('securityDesc')}</CardDescription>
        </div>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="currentPassword">{t('currentPassword')}</Label>
            <Input
              id="currentPassword"
              type="password"
              autoComplete="current-password"
              {...register('currentPassword', { required: true })}
            />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="newPassword">{t('newPassword')}</Label>
              <Input
                id="newPassword"
                type="password"
                autoComplete="new-password"
                {...register('newPassword', { required: true, minLength: 8 })}
              />
              {newPw && (
                <div className="flex items-center gap-2">
                  <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-secondary">
                    <div
                      className={cn('h-full rounded-full transition-all', strengthColor)}
                      style={{ width: `${(strength.score / 5) * 100}%` }}
                    />
                  </div>
                  <span className="text-[11px] text-muted-foreground">
                    {t(
                      strength.label === 'weak'
                        ? 'strengthWeak'
                        : strength.label === 'medium'
                          ? 'strengthMedium'
                          : 'strengthStrong',
                    )}
                  </span>
                </div>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="confirmPassword">{t('confirmPassword')}</Label>
              <Input
                id="confirmPassword"
                type="password"
                autoComplete="new-password"
                {...register('confirmPassword', { required: true })}
              />
              {errors.confirmPassword && (
                <p className="text-xs text-destructive">{t('passwordMismatch')}</p>
              )}
            </div>
          </div>
          <Button type="submit" disabled={change.isPending}>
            {change.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
            {t('changePassword')}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}

/* -------------------------------------------------------------- Preferences */
function Toggle({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label: string;
}) {
  return (
    <label className="flex cursor-pointer items-center justify-between gap-3 py-1.5">
      <span className="text-sm text-foreground">{label}</span>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() => onChange(!checked)}
        className={cn(
          'relative h-6 w-11 shrink-0 rounded-full transition-colors',
          checked ? 'bg-primary' : 'bg-secondary',
        )}
      >
        <span
          className={cn(
            'absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform',
            checked ? 'left-[22px]' : 'left-0.5',
          )}
        />
      </button>
    </label>
  );
}

function PreferencesSection() {
  const t = useTranslations('settings');
  const locale = useLocale();
  const { data, isLoading } = useUserSettings();
  const { data: aiModels } = useAiModels();
  const update = useUpdateSettings();
  const user = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);
  const [draft, setDraft] = useState<UserSettings | null>(null);
  const storeTheme = useAuthStore((s) => s.user?.settings?.theme);

  // Keep the dropdown in sync when the theme changes elsewhere (topbar toggle).
  useEffect(() => {
    if (storeTheme) setDraft((d) => (d && d.theme !== storeTheme ? { ...d, theme: storeTheme } : d));
  }, [storeTheme]);

  // Live-preview the theme via the store (ThemeSync applies it to next-themes).
  const previewTheme = (theme: UserSettings['theme']) => {
    if (user) {
      setUser({
        ...user,
        settings: user.settings
          ? { ...user.settings, theme }
          : { language: 'FR', currency: 'XOF', theme },
      });
    }
  };

  useEffect(() => {
    if (data) setDraft(data);
  }, [data]);

  const save = () => {
    if (!draft) return;
    update.mutate(draft, {
      onSuccess: async () => {
        toast.success(t('preferencesSaved'));
        // Keep the UI locale in sync with the chosen language.
        const nextLocale = draft.language.toLowerCase() as 'fr' | 'en';
        if (nextLocale !== locale) {
          await setUserLocale(nextLocale);
          window.location.reload();
        }
      },
      onError: (e: any) => toast.error(e?.message),
    });
  };

  return (
    <Card>
      <CardHeader className="flex-row items-center gap-3 space-y-0">
        <SectionIcon icon={Palette} className="bg-violet-500/15 text-violet-500" />
        <div>
          <CardTitle>{t('preferences')}</CardTitle>
          <CardDescription>{t('preferencesDesc')}</CardDescription>
        </div>
      </CardHeader>
      <CardContent>
        {isLoading || !draft ? (
          <Skeleton className="h-56 rounded-xl" />
        ) : (
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-3">
              <div className="space-y-2">
                <Label className="flex items-center gap-1.5">
                  <Globe className="h-3.5 w-3.5 text-muted-foreground" /> {t('language')}
                </Label>
                <Select
                  value={draft.language}
                  onValueChange={(v) => setDraft({ ...draft, language: v as 'FR' | 'EN' })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="FR">Français</SelectItem>
                    <SelectItem value="EN">English</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>{t('currency')}</Label>
                <Select
                  value={draft.currency}
                  onValueChange={(v) => setDraft({ ...draft, currency: v })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {CURRENCIES.map((c) => (
                      <SelectItem key={c} value={c}>
                        {c === 'XOF' ? 'XOF (FCFA)' : c}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>{t('theme')}</Label>
                <Select
                  value={draft.theme}
                  onValueChange={(v) => {
                    const theme = v as UserSettings['theme'];
                    setDraft({ ...draft, theme });
                    previewTheme(theme); // instant live preview
                  }}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="LIGHT">{t('themeLight')}</SelectItem>
                    <SelectItem value="DARK">{t('themeDark')}</SelectItem>
                    <SelectItem value="SYSTEM">{t('themeSystem')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="divide-y divide-border rounded-xl border border-border px-4">
              <Toggle
                label={t('notificationsEnabled')}
                checked={draft.notificationsEnabled}
                onChange={(v) => setDraft({ ...draft, notificationsEnabled: v })}
              />
              <Toggle
                label={t('emailNotifications')}
                checked={draft.emailNotifications}
                onChange={(v) => setDraft({ ...draft, emailNotifications: v })}
              />
              <Toggle
                label={t('aiEnabled')}
                checked={draft.aiEnabled}
                onChange={(v) => setDraft({ ...draft, aiEnabled: v })}
              />
            </div>

            {draft.aiEnabled && (() => {
              const provider = draft.aiProvider ?? 'GEMINI';
              const modelKey = provider === 'AGENTROUTER' ? 'agentRouterModel' : 'geminiModel';
              const currentModel = draft[modelKey];
              const options = aiModels?.[provider] ?? [];
              return (
                <div className="space-y-4">
                  <div className="space-y-2">
                    <Label>{t('aiProvider')}</Label>
                    <Select
                      value={provider}
                      onValueChange={(v) =>
                        setDraft({ ...draft, aiProvider: v as UserSettings['aiProvider'] })
                      }
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="GEMINI">Gemini</SelectItem>
                        <SelectItem value="AGENTROUTER">AgentRouter</SelectItem>
                      </SelectContent>
                    </Select>
                    <p className="text-xs text-muted-foreground">
                      {provider === 'AGENTROUTER'
                        ? t('aiModelAgentRouterHint')
                        : t('aiModelGeminiHint')}
                    </p>
                  </div>
                  <div className="space-y-2">
                    <Label>{t('aiModel')}</Label>
                    <Select
                      value={currentModel}
                      onValueChange={(v) => setDraft({ ...draft, [modelKey]: v })}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {options.map((m) => (
                          <SelectItem key={m.id} value={m.id}>
                            {m.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              );
            })()}

            <Button onClick={save} disabled={update.isPending}>
              {update.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
              {t('savePreferences')}
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

/* --------------------------------------------------------------- Danger zone */
function DangerZone() {
  const t = useTranslations('settings');
  const del = useDeleteAccount();
  const logout = useLogout();
  const clearAuth = useAuthStore((s) => s.clear);
  const [confirming, setConfirming] = useState(false);
  const [exporting, setExporting] = useState(false);

  const doExport = async () => {
    setExporting(true);
    try {
      await exportUserData();
      toast.success(t('exported'));
    } catch (e: any) {
      toast.error(e?.message);
    } finally {
      setExporting(false);
    }
  };

  const doDelete = () =>
    del.mutate(undefined, {
      onSuccess: () => {
        toast.success(t('accountDeleted'));
        clearAuth();
        logout.mutate();
      },
      onError: (e: any) => toast.error(e?.message),
    });

  return (
    <Card className="border-destructive/30">
      <CardHeader className="flex-row items-center gap-3 space-y-0">
        <SectionIcon icon={ShieldAlert} className="bg-destructive/10 text-destructive" />
        <div>
          <CardTitle>{t('dangerZone')}</CardTitle>
          <CardDescription>{t('exportDesc')}</CardDescription>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="flex flex-col gap-2 rounded-xl border border-border p-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-sm font-medium text-foreground">{t('exportData')}</p>
            <p className="text-xs text-muted-foreground">{t('exportDesc')}</p>
          </div>
          <Button variant="outline" onClick={doExport} disabled={exporting}>
            {exporting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
            {t('export')}
          </Button>
        </div>
        <div className="flex flex-col gap-2 rounded-xl border border-destructive/30 bg-destructive/5 p-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-sm font-medium text-foreground">{t('deleteAccount')}</p>
            <p className="text-xs text-muted-foreground">{t('deleteAccountDesc')}</p>
          </div>
          <Button variant="destructive" onClick={() => setConfirming(true)}>
            <Trash2 className="h-4 w-4" /> {t('deleteAccount')}
          </Button>
        </div>
      </CardContent>

      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title={t('deleteConfirm')}
        description={t('deleteConfirmDesc')}
        loading={del.isPending}
        onConfirm={doDelete}
      />
    </Card>
  );
}

export default function SettingsPage() {
  const t = useTranslations('settings');
  const logout = useLogout();
  const clearAuth = useAuthStore((s) => s.clear);
  const router = useRouter();

  const logoutEverywhere = async () => {
    try {
      await api.post('/auth/logout-everywhere');
    } catch {
      /* revoke best-effort */
    }
    clearAuth();
    router.push('/login');
  };

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader title={t('title')} description={t('subtitle')}>
        <Button variant="outline" onClick={logoutEverywhere}>
          <LogOut className="h-4 w-4" /> {t('logoutEverywhere')}
        </Button>
      </PageHeader>

      <ProfileSection />
      <SecuritySection />
      <PreferencesSection />
      <DangerZone />
    </div>
  );
}
