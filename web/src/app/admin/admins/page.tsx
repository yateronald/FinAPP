'use client';

import { useState } from 'react';
import { AlertCircle, Plus, ShieldCheck } from 'lucide-react';
import { useAdmins, useCreateAdmin } from '@/hooks/use-admin';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';

export default function AdminAdminsPage() {
  const { data: admins, isLoading } = useAdmins();
  const create = useCreateAdmin();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ email: '', password: '', firstName: '', lastName: '' });
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    setError(null);
    try {
      await create.mutateAsync({
        email: form.email.trim(),
        password: form.password,
        firstName: form.firstName || undefined,
        lastName: form.lastName || undefined,
      });
      setOpen(false);
      setForm({ email: '', password: '', firstName: '', lastName: '' });
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Création impossible');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-extrabold">Administrateurs</h1>
          <p className="text-sm text-muted-foreground">
            Les comptes admin se connectent uniquement sur le web.
          </p>
        </div>
        <Button onClick={() => setOpen(true)}>
          <Plus className="mr-1 h-4 w-4" />
          Nouvel administrateur
        </Button>
      </div>

      <Card>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex h-40 items-center justify-center">
              <div className="h-7 w-7 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : (
            <div className="divide-y divide-border">
              {admins?.map((a) => (
                <div key={a.id} className="flex items-center gap-4 px-5 py-4">
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-500/10">
                    <ShieldCheck className="h-5 w-5 text-amber-600" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold">
                      {[a.firstName, a.lastName].filter(Boolean).join(' ') || a.email}
                    </p>
                    <p className="text-xs text-muted-foreground">{a.email}</p>
                  </div>
                  <div className="text-right text-xs text-muted-foreground">
                    {a.isActive ? (
                      <span className="font-bold text-emerald-600">Actif</span>
                    ) : (
                      <span className="font-bold text-red-600">Désactivé</span>
                    )}
                    <p>
                      {a.lastLoginAt
                        ? new Date(a.lastLoginAt).toLocaleDateString('fr-FR')
                        : 'Jamais connecté'}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <Card className="w-full max-w-md">
            <CardContent className="space-y-4 p-6">
              <h2 className="text-lg font-extrabold">Nouvel administrateur</h2>
              <p className="text-xs text-muted-foreground">
                Un email déjà utilisé par un compte finance ne peut pas être réutilisé.
                L’administrateur devra définir son mot de passe à la première connexion.
              </p>
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1.5">
                  <Label>Prénom</Label>
                  <Input
                    value={form.firstName}
                    onChange={(e) => setForm({ ...form, firstName: e.target.value })}
                  />
                </div>
                <div className="space-y-1.5">
                  <Label>Nom</Label>
                  <Input
                    value={form.lastName}
                    onChange={(e) => setForm({ ...form, lastName: e.target.value })}
                  />
                </div>
              </div>
              <div className="space-y-1.5">
                <Label>Email</Label>
                <Input
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                />
              </div>
              <div className="space-y-1.5">
                <Label>Mot de passe provisoire</Label>
                <Input
                  type="text"
                  value={form.password}
                  onChange={(e) => setForm({ ...form, password: e.target.value })}
                  placeholder="8 caractères minimum"
                />
              </div>
              {error && (
                <div className="flex items-start gap-2 rounded-xl bg-destructive/10 p-3 text-sm text-destructive">
                  <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
                  <span>{error}</span>
                </div>
              )}
              <div className="flex justify-end gap-2">
                <Button variant="outline" onClick={() => setOpen(false)}>
                  Annuler
                </Button>
                <Button
                  onClick={submit}
                  disabled={create.isPending || !form.email || form.password.length < 8}
                >
                  Créer
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
