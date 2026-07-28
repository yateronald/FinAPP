'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { AlertCircle, KeyRound } from 'lucide-react';
import { api } from '@/lib/api';
import { useAuthStore } from '@/store/auth';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';

/**
 * Shown when an admin has reset the account's password. The backend blocks every
 * other endpoint until this succeeds, so there is no way to skip it.
 */
export default function ChangePasswordPage() {
  const router = useRouter();
  const clear = useAuthStore((s) => s.clear);
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    setError(null);
    if (next.length < 8) return setError('Le nouveau mot de passe doit faire 8 caractères minimum.');
    if (next !== confirm) return setError('Les mots de passe ne correspondent pas.');
    setSaving(true);
    try {
      await api.post('/auth/change-password', { currentPassword: current, newPassword: next });
      // The backend revokes all sessions — sign in again with the new password.
      clear();
      router.replace('/login');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Impossible de changer le mot de passe.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardContent className="space-y-5 p-6">
          <div className="flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-primary">
              <KeyRound className="h-5 w-5 text-primary-foreground" />
            </div>
            <div>
              <h1 className="text-lg font-extrabold">Changement requis</h1>
              <p className="text-xs text-muted-foreground">
                Définissez un nouveau mot de passe pour continuer.
              </p>
            </div>
          </div>

          <div className="space-y-1.5">
            <Label>Mot de passe actuel (provisoire)</Label>
            <Input type="password" value={current} onChange={(e) => setCurrent(e.target.value)} />
          </div>
          <div className="space-y-1.5">
            <Label>Nouveau mot de passe</Label>
            <Input type="password" value={next} onChange={(e) => setNext(e.target.value)} />
          </div>
          <div className="space-y-1.5">
            <Label>Confirmer</Label>
            <Input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} />
          </div>

          {error && (
            <div className="flex items-start gap-2 rounded-xl bg-destructive/10 p-3 text-sm text-destructive">
              <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <Button className="w-full" onClick={submit} disabled={saving || !current || !next}>
            {saving ? 'Enregistrement…' : 'Changer le mot de passe'}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
