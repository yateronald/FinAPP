'use client';

import { useState } from 'react';
import {
  Ban,
  CheckCircle2,
  Copy,
  Crown,
  KeyRound,
  MoreVertical,
  ShieldCheck,
  SlidersHorizontal,
  Users as UsersIcon,
  UserX,
} from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer } from 'recharts';
import {
  useAdminStats,
  useAdminUsers,
  useResetUserPassword,
  useToggleUserActive,
  type AdminUser,
} from '@/hooks/use-admin';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';

const AVATAR_TONES = [
  'bg-violet-100 text-violet-700',
  'bg-sky-100 text-sky-700',
  'bg-emerald-100 text-emerald-700',
  'bg-amber-100 text-amber-700',
  'bg-rose-100 text-rose-700',
  'bg-indigo-100 text-indigo-700',
];

function initials(u: AdminUser) {
  const name = [u.firstName, u.lastName].filter(Boolean).join(' ') || u.email;
  const parts = name.trim().split(/\s+/);
  return (parts[0][0] + (parts[1]?.[0] ?? '')).toUpperCase();
}

function toneFor(id: string) {
  let h = 0;
  for (const c of id) h = (h + c.charCodeAt(0)) % AVATAR_TONES.length;
  return AVATAR_TONES[h];
}

/** Stat card with a real 30-day sparkline. */
function StatCard({
  label,
  value,
  share,
  icon: Icon,
  iconClass,
  stroke,
  series,
}: {
  label: string;
  value: number;
  share: string;
  icon: React.ElementType;
  iconClass: string;
  stroke: string;
  series: number[];
}) {
  const data = series.map((v, i) => ({ i, v }));
  return (
    <Card className="overflow-hidden">
      <CardContent className="p-3.5">
        <div className="flex items-center gap-2.5">
          <div
            className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-xl ${iconClass}`}
          >
            <Icon className="h-4 w-4" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[11px] font-semibold text-muted-foreground">{label}</p>
            <p className="mt-0.5 text-xl font-extrabold leading-none">{value}</p>
          </div>
        </div>
        <div className="mt-2 flex items-end justify-between gap-2">
          <p className="text-[10px] font-medium text-muted-foreground">{share}</p>
          <div className="h-6 w-16">
            {data.length > 1 && (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data} margin={{ top: 2, right: 0, left: 0, bottom: 0 }}>
                  <Area
                    type="monotone"
                    dataKey="v"
                    stroke={stroke}
                    fill={stroke}
                    fillOpacity={0.18}
                    strokeWidth={2}
                    dot={false}
                    isAnimationActive={false}
                  />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function AdminUsersPage() {
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'disabled'>('all');
  const [openMenu, setOpenMenu] = useState<string | null>(null);

  const { data: stats } = useAdminStats();
  const { data, isLoading } = useAdminUsers({
    isActive: statusFilter === 'all' ? undefined : statusFilter === 'active',
    page,
    limit: 10, // 10 rows max per page, then paginate
  });
  const toggle = useToggleUserActive();
  const reset = useResetUserPassword();

  const [confirm, setConfirm] = useState<{ user: AdminUser; reason: string } | null>(null);
  const [tempPassword, setTempPassword] = useState<{ email: string; password: string } | null>(null);

  const s = stats?.users;
  const t = stats?.trends;
  const pct = (n?: number) =>
    s?.total ? `${Math.round(((n ?? 0) / s.total) * 100)}% du total` : '—';

  const from = data ? (data.page - 1) * data.limit + 1 : 0;
  const to = data ? Math.min(data.page * data.limit, data.total) : 0;

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-extrabold leading-tight">Utilisateurs</h1>
        <p className="text-xs text-muted-foreground">
          Gérez les comptes utilisateurs, les rôles et les accès à la plateforme.
        </p>
      </div>

      {/* -------------------------------------------------------- Stat cards */}
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Tous les utilisateurs"
          value={s?.total ?? 0}
          share="100% du total"
          icon={UsersIcon}
          iconClass="bg-violet-100 text-violet-600"
          stroke="#8b5cf6"
          series={t?.total ?? []}
        />
        <StatCard
          label="Utilisateurs actifs"
          value={s?.active ?? 0}
          share={pct(s?.active)}
          icon={CheckCircle2}
          iconClass="bg-emerald-100 text-emerald-600"
          stroke="#10b981"
          series={t?.active ?? []}
        />
        <StatCard
          label="Utilisateurs désactivés"
          value={s?.disabled ?? 0}
          share={pct(s?.disabled)}
          icon={UserX}
          iconClass="bg-amber-100 text-amber-600"
          stroke="#f59e0b"
          series={t?.disabled ?? []}
        />
        <StatCard
          label="Administrateurs"
          value={s?.admins ?? 0}
          share={pct(s?.admins)}
          icon={ShieldCheck}
          iconClass="bg-sky-100 text-sky-600"
          stroke="#0ea5e9"
          series={t?.admins ?? []}
        />
      </div>

      {/* ------------------------------------------------------------ Filters */}
      <div className="flex flex-wrap items-center justify-end gap-2">
        <div className="flex gap-1 rounded-xl border border-border bg-card p-1">
          {(['all', 'active', 'disabled'] as const).map((f) => (
            <button
              key={f}
              onClick={() => {
                setStatusFilter(f);
                setPage(1);
              }}
              className={`rounded-lg px-3 py-1.5 text-xs font-bold transition ${
                statusFilter === f
                  ? 'bg-primary/10 text-primary'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              {f === 'all' ? 'Tous' : f === 'active' ? 'Actifs' : 'Désactivés'}
            </button>
          ))}
        </div>
        <button className="flex h-[34px] w-[34px] items-center justify-center rounded-xl border border-border bg-card text-muted-foreground transition hover:text-foreground">
          <SlidersHorizontal className="h-4 w-4" />
        </button>
      </div>

      {/* -------------------------------------------------------------- Table */}
      <Card className="overflow-hidden">
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex h-40 items-center justify-center">
              <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : !data?.items.length ? (
            <p className="p-8 text-center text-xs text-muted-foreground">Aucun utilisateur.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[780px] text-[13px]">
                <thead className="border-b border-border">
                  <tr className="text-left text-[11px] font-bold text-muted-foreground">
                    <th className="px-4 py-2.5">Utilisateur</th>
                    <th className="px-4 py-2.5">Rôle</th>
                    <th className="px-4 py-2.5">Statut</th>
                    <th className="px-4 py-2.5">Dernière connexion</th>
                    <th className="px-4 py-2.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {data.items.map((u) => (
                    <tr key={u.id} className="transition hover:bg-muted/40">
                      <td className="px-4 py-2.5">
                        <div className="flex items-center gap-2.5">
                          <span
                            className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-[10px] font-extrabold ${toneFor(u.id)}`}
                          >
                            {initials(u)}
                          </span>
                          <div className="min-w-0">
                            <p className="truncate text-[13px] font-bold leading-tight">
                              {[u.firstName, u.lastName].filter(Boolean).join(' ') || '—'}
                            </p>
                            <p className="truncate text-[11px] leading-tight text-muted-foreground">
                              {u.email}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-2.5">
                        {u.role === 'ADMIN' ? (
                          <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-bold text-amber-700">
                            <Crown className="h-2.5 w-2.5" /> Admin
                          </span>
                        ) : (
                          <span className="inline-flex rounded-full bg-sky-100 px-2 py-0.5 text-[10px] font-bold text-sky-700">
                            Utilisateur
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-2.5">
                        {/* status + password flag stay on one line */}
                        <div className="flex flex-wrap items-center gap-1.5">
                          {u.isActive ? (
                            <span className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-bold text-emerald-700">
                              <span className="h-1 w-1 rounded-full bg-emerald-500" /> Actif
                            </span>
                          ) : (
                            <span
                              title={u.disabledReason ?? undefined}
                              className="inline-flex items-center gap-1 rounded-full bg-rose-100 px-2 py-0.5 text-[10px] font-bold text-rose-700"
                            >
                              <span className="h-1 w-1 rounded-full bg-rose-500" /> Désactivé
                            </span>
                          )}
                          {u.mustChangePassword && (
                            <span className="inline-flex rounded-full bg-violet-100 px-2 py-0.5 text-[10px] font-bold text-violet-700">
                              MDP à changer
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-2.5 whitespace-nowrap text-xs">
                        {u.lastLoginAt ? (
                          <>
                            <span className="font-semibold">
                              {new Date(u.lastLoginAt).toLocaleDateString('fr-FR')}
                            </span>{' '}
                            <span className="text-muted-foreground">
                              {new Date(u.lastLoginAt).toLocaleTimeString('fr-FR', {
                                hour: '2-digit',
                                minute: '2-digit',
                              })}
                            </span>
                          </>
                        ) : (
                          <span className="text-muted-foreground">Jamais</span>
                        )}
                      </td>
                      <td className="px-4 py-2.5">
                        <div className="flex items-center justify-end gap-1.5">
                          {u.isActive ? (
                            <>
                              <Button
                                size="sm"
                                variant="outline"
                                className="h-7 rounded-lg px-2.5 text-[11px]"
                                disabled={reset.isPending}
                                onClick={async () => {
                                  const res = await reset.mutateAsync(u.id);
                                  setTempPassword({
                                    email: res.email,
                                    password: res.temporaryPassword,
                                  });
                                }}
                              >
                                <KeyRound className="mr-1 h-3 w-3" />
                                Réinitialiser
                              </Button>
                              <Button
                                size="sm"
                                variant="outline"
                                className="h-7 rounded-lg border-rose-200 px-2.5 text-[11px] text-rose-600 hover:bg-rose-50 hover:text-rose-700"
                                onClick={() => setConfirm({ user: u, reason: '' })}
                              >
                                <Ban className="mr-1 h-3 w-3" />
                                Désactiver
                              </Button>
                            </>
                          ) : (
                            <Button
                              size="sm"
                              variant="outline"
                              className="h-7 rounded-lg border-emerald-200 px-2.5 text-[11px] text-emerald-600 hover:bg-emerald-50 hover:text-emerald-700"
                              onClick={() => toggle.mutate({ id: u.id, active: true })}
                            >
                              <CheckCircle2 className="mr-1 h-3 w-3" />
                              Réactiver
                            </Button>
                          )}
                          <div className="relative">
                            <button
                              onClick={() => setOpenMenu(openMenu === u.id ? null : u.id)}
                              className="rounded-md p-1 text-muted-foreground transition hover:bg-muted hover:text-foreground"
                            >
                              <MoreVertical className="h-3.5 w-3.5" />
                            </button>
                            {openMenu === u.id && (
                              <div className="absolute right-0 top-full z-20 mt-1 w-52 overflow-hidden rounded-xl border border-border bg-card p-3 text-left shadow-lg">
                                <p className="text-[11px] font-bold text-muted-foreground">
                                  INSCRIT LE
                                </p>
                                <p className="text-xs">
                                  {new Date(u.createdAt).toLocaleDateString('fr-FR')}
                                </p>
                                <p className="mt-2 text-[11px] font-bold text-muted-foreground">
                                  EMAIL VÉRIFIÉ
                                </p>
                                <p className="text-xs">{u.emailVerified ? 'Oui' : 'Non'}</p>
                                {u.disabledReason && (
                                  <>
                                    <p className="mt-2 text-[11px] font-bold text-muted-foreground">
                                      MOTIF
                                    </p>
                                    <p className="text-xs italic">{u.disabledReason}</p>
                                  </>
                                )}
                              </div>
                            )}
                          </div>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* ---------------------------------------------------------- Footer */}
          {data && (
            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-border px-4 py-2.5">
              <p className="text-[11px] text-muted-foreground">
                Affichage {from} - {to} sur {data.total} utilisateurs
              </p>
              <div className="flex items-center gap-1">
                <Button
                  size="sm"
                  variant="outline"
                  className="h-7 w-7 rounded-lg p-0 text-xs"
                  disabled={page <= 1}
                  onClick={() => setPage(page - 1)}
                >
                  ‹
                </Button>
                {Array.from({ length: Math.min(data.pages, 5) }, (_, i) => i + 1).map((n) => (
                  <button
                    key={n}
                    onClick={() => setPage(n)}
                    className={`h-7 w-7 rounded-lg text-[11px] font-bold transition ${
                      n === data.page
                        ? 'bg-primary text-primary-foreground'
                        : 'border border-border text-muted-foreground hover:text-foreground'
                    }`}
                  >
                    {n}
                  </button>
                ))}
                <Button
                  size="sm"
                  variant="outline"
                  className="h-7 w-7 rounded-lg p-0 text-xs"
                  disabled={page >= data.pages}
                  onClick={() => setPage(page + 1)}
                >
                  ›
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Disable confirmation */}
      {confirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <Card className="w-full max-w-md">
            <CardContent className="space-y-4 p-6">
              <h2 className="text-lg font-extrabold">Désactiver ce compte ?</h2>
              <p className="text-sm text-muted-foreground">
                <span className="font-semibold text-foreground">{confirm.user.email}</span> ne
                pourra plus se connecter et toutes ses sessions seront fermées immédiatement.
              </p>
              <Input
                autoFocus
                placeholder="Motif (visible dans le journal d’audit)"
                value={confirm.reason}
                onChange={(e) => setConfirm({ ...confirm, reason: e.target.value })}
              />
              <div className="flex justify-end gap-2">
                <Button variant="outline" onClick={() => setConfirm(null)}>
                  Annuler
                </Button>
                <Button
                  variant="destructive"
                  disabled={toggle.isPending}
                  onClick={() => {
                    toggle.mutate({
                      id: confirm.user.id,
                      active: false,
                      reason: confirm.reason || undefined,
                    });
                    setConfirm(null);
                  }}
                >
                  Désactiver
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* One-time temporary password */}
      {tempPassword && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <Card className="w-full max-w-md">
            <CardContent className="space-y-4 p-6">
              <h2 className="text-lg font-extrabold">Mot de passe temporaire</h2>
              <p className="text-sm text-muted-foreground">
                Communiquez-le à{' '}
                <span className="font-semibold text-foreground">{tempPassword.email}</span> de
                manière sécurisée. Il devra le changer à sa prochaine connexion.{' '}
                <span className="font-semibold text-amber-600">
                  Il ne sera plus affiché après fermeture.
                </span>
              </p>
              <div className="flex items-center gap-2 rounded-xl border border-border bg-muted p-3">
                <code className="flex-1 text-lg font-bold tracking-wider">
                  {tempPassword.password}
                </code>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => navigator.clipboard?.writeText(tempPassword.password)}
                >
                  <Copy className="h-3.5 w-3.5" />
                </Button>
              </div>
              <div className="flex justify-end">
                <Button onClick={() => setTempPassword(null)}>J’ai noté</Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
