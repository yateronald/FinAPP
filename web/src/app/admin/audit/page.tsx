'use client';

import { useMemo, useState } from 'react';
import {
  AlertCircle,
  CalendarDays,
  CheckCircle2,
  KeyRound,
  ListChecks,
  LogIn,
  MoreVertical,
  ScrollText,
  ShieldAlert,
  ShieldCheck,
  Trash2,
  UserMinus,
  UserPlus,
} from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer } from 'recharts';
import { useAuditLogs, useAuditStats, type AuditEntry } from '@/hooks/use-admin';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

/** Visual identity per action: icon + pill colours. */
const ACTION_STYLE: Record<
  string,
  { icon: React.ElementType; tile: string; pill: string; label?: string }
> = {
  LOGIN: { icon: LogIn, tile: 'bg-sky-100 text-sky-600', pill: 'bg-sky-100 text-sky-700' },
  LOGIN_FAILED: {
    icon: ShieldAlert,
    tile: 'bg-rose-100 text-rose-600',
    pill: 'bg-rose-100 text-rose-700',
  },
  USER_DISABLED: {
    icon: UserMinus,
    tile: 'bg-rose-100 text-rose-600',
    pill: 'bg-rose-100 text-rose-700',
  },
  USER_ENABLED: {
    icon: UserPlus,
    tile: 'bg-emerald-100 text-emerald-600',
    pill: 'bg-emerald-100 text-emerald-700',
  },
  USER_PASSWORD_RESET: {
    icon: KeyRound,
    tile: 'bg-amber-100 text-amber-600',
    pill: 'bg-amber-100 text-amber-700',
  },
  PASSWORD_CHANGED: {
    icon: KeyRound,
    tile: 'bg-amber-100 text-amber-600',
    pill: 'bg-amber-100 text-amber-700',
  },
  PASSWORD_RESET: {
    icon: KeyRound,
    tile: 'bg-amber-100 text-amber-600',
    pill: 'bg-amber-100 text-amber-700',
  },
  ADMIN_CREATED: {
    icon: ShieldCheck,
    tile: 'bg-violet-100 text-violet-600',
    pill: 'bg-violet-100 text-violet-700',
  },
  ACCOUNT_DELETED: {
    icon: Trash2,
    tile: 'bg-rose-100 text-rose-600',
    pill: 'bg-rose-100 text-rose-700',
  },
  REGISTER: {
    icon: UserPlus,
    tile: 'bg-emerald-100 text-emerald-600',
    pill: 'bg-emerald-100 text-emerald-700',
  },
  EMAIL_VERIFIED: {
    icon: CheckCircle2,
    tile: 'bg-emerald-100 text-emerald-600',
    pill: 'bg-emerald-100 text-emerald-700',
  },
};

const FALLBACK = {
  icon: ListChecks,
  tile: 'bg-slate-100 text-slate-500',
  pill: 'bg-slate-100 text-slate-600',
};

function initials(email?: string | null) {
  if (!email) return '—';
  const name = email.split('@')[0];
  return (name[0] + (name[1] ?? '')).toUpperCase();
}

function StatCard({
  label,
  value,
  share,
  icon: Icon,
  tile,
  stroke,
  series,
}: {
  label: string;
  value: number;
  share: number;
  icon: React.ElementType;
  tile: string;
  stroke: string;
  series: number[];
}) {
  const data = series.map((v, i) => ({ i, v }));
  return (
    <Card>
      <CardContent className="p-3.5">
        <div className="flex items-start gap-2.5">
          <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-xl ${tile}`}>
            <Icon className="h-4 w-4" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[11px] font-semibold text-muted-foreground">{label}</p>
            <p className="mt-0.5 text-xl font-extrabold leading-none">{value}</p>
            <p className="mt-0.5 text-[10px] font-medium text-muted-foreground">{share}%</p>
          </div>
          <div className="h-7 w-16 shrink-0">
            {data.length > 1 && (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data} margin={{ top: 4, right: 0, left: 0, bottom: 0 }}>
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

/** Human-friendly target: the affected email when we recorded one. */
function targetOf(e: AuditEntry) {
  const meta = e.metadata as { email?: string; reason?: string } | null;
  return { email: meta?.email ?? e.entity, reason: meta?.reason };
}

const iso = (d: Date) => d.toISOString().slice(0, 10);

export default function AdminAuditPage() {
  const today = useMemo(() => new Date(), []);
  const [range, setRange] = useState({
    from: iso(new Date(today.getTime() - 7 * 86_400_000)),
    to: iso(today),
  });
  const [page, setPage] = useState(1);
  const [perPage, setPerPage] = useState(10);
  const [openMenu, setOpenMenu] = useState<string | null>(null);

  const { data: stats } = useAuditStats(range);
  const { data, isLoading } = useAuditLogs({ page, limit: perPage, ...range });

  const from = data ? (data.page - 1) * data.limit + 1 : 0;
  const to = data ? Math.min(data.page * data.limit, data.total) : 0;

  // Compact pagination: 1 2 3 … last
  const pageButtons = useMemo(() => {
    if (!data) return [] as (number | '…')[];
    const last = data.pages;
    if (last <= 5) return Array.from({ length: last }, (_, i) => i + 1);
    const out: (number | '…')[] = [1, 2, 3];
    if (page > 3 && page < last) out.push('…', page);
    out.push('…', last);
    return out.filter((v, i, a) => a.indexOf(v) === i || v === '…');
  }, [data, page]);

  return (
    <div className="space-y-4">
      {/* ------------------------------------------------------------ Header */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-violet-100 text-violet-600">
            <ScrollText className="h-[18px] w-[18px]" />
          </div>
          <div>
            <h1 className="text-xl font-extrabold leading-tight">Journal d’audit</h1>
            <p className="text-xs text-muted-foreground">
              Consultez l’historique de toutes les actions sensibles effectuées sur la plateforme.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-1.5 rounded-xl border border-border bg-card px-3 py-1.5">
          <CalendarDays className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
          <input
            type="date"
            value={range.from}
            max={range.to}
            onChange={(e) => {
              setRange((r) => ({ ...r, from: e.target.value }));
              setPage(1);
            }}
            className="bg-transparent text-[11px] font-semibold outline-none"
          />
          <span className="text-xs text-muted-foreground">–</span>
          <input
            type="date"
            value={range.to}
            min={range.from}
            onChange={(e) => {
              setRange((r) => ({ ...r, to: e.target.value }));
              setPage(1);
            }}
            className="bg-transparent text-[11px] font-semibold outline-none"
          />
        </div>
      </div>

      {/* ------------------------------------------------------- Stat cards */}
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Actions totales"
          value={stats?.total ?? 0}
          share={100}
          icon={ListChecks}
          tile="bg-violet-100 text-violet-600"
          stroke="#8b5cf6"
          series={stats?.series.total ?? []}
        />
        <StatCard
          label="Sensibles"
          value={stats?.sensitive ?? 0}
          share={stats?.shares.sensitive ?? 0}
          icon={ShieldCheck}
          tile="bg-amber-100 text-amber-600"
          stroke="#f59e0b"
          series={stats?.series.sensitive ?? []}
        />
        <StatCard
          label="Connexions"
          value={stats?.logins ?? 0}
          share={stats?.shares.logins ?? 0}
          icon={CheckCircle2}
          tile="bg-emerald-100 text-emerald-600"
          stroke="#10b981"
          series={stats?.series.logins ?? []}
        />
        <StatCard
          label="Échecs"
          value={stats?.failures ?? 0}
          share={stats?.shares.failures ?? 0}
          icon={AlertCircle}
          tile="bg-rose-100 text-rose-600"
          stroke="#f43f5e"
          series={stats?.series.failures ?? []}
        />
      </div>

      {/* ------------------------------------------------------------- Table */}
      <Card className="overflow-hidden">
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex h-40 items-center justify-center">
              <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : !data?.items.length ? (
            <p className="p-8 text-center text-xs text-muted-foreground">
              Aucune action sur cette période.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[820px] text-[13px]">
                <thead className="border-b border-border">
                  <tr className="text-left text-[11px] font-bold text-muted-foreground">
                    <th className="px-4 py-2.5">Action</th>
                    <th className="px-4 py-2.5">Auteur</th>
                    <th className="px-4 py-2.5">Cible</th>
                    <th className="px-4 py-2.5">IP</th>
                    <th className="px-4 py-2.5">Date</th>
                    <th className="px-4 py-2.5" />
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {data.items.map((e) => {
                    const style = ACTION_STYLE[e.action] ?? FALLBACK;
                    const Icon = style.icon;
                    const target = targetOf(e);
                    return (
                      <tr key={e.id} className="transition hover:bg-muted/40">
                        <td className="px-4 py-2">
                          <div className="flex items-center gap-2">
                            <span
                              className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg ${style.tile}`}
                            >
                              <Icon className="h-3.5 w-3.5" />
                            </span>
                            <span
                              className={`inline-flex rounded-md px-2 py-0.5 text-[10px] font-extrabold tracking-wide ${style.pill}`}
                            >
                              {e.action}
                            </span>
                          </div>
                        </td>
                        <td className="px-4 py-2">
                          <div className="flex items-center gap-2">
                            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-violet-100 text-[9px] font-extrabold text-violet-700">
                              {initials(e.user?.email)}
                            </span>
                            <span className="text-xs">{e.user?.email ?? 'système'}</span>
                          </div>
                        </td>
                        <td className="px-4 py-2">
                          <p className="text-xs leading-tight">{target.email}</p>
                          {target.reason && (
                            <p className="text-[10px] leading-tight text-muted-foreground">
                              • {target.reason}
                            </p>
                          )}
                        </td>
                        <td className="px-4 py-2 text-xs text-muted-foreground">
                          {e.ipAddress ?? '—'}
                        </td>
                        <td className="px-4 py-2 whitespace-nowrap text-xs text-muted-foreground">
                          {new Date(e.createdAt).toLocaleString('fr-FR')}
                        </td>
                        <td className="px-4 py-2">
                          <div className="relative flex justify-end">
                            <button
                              onClick={() => setOpenMenu(openMenu === e.id ? null : e.id)}
                              className="rounded-md p-1 text-muted-foreground transition hover:bg-muted hover:text-foreground"
                            >
                              <MoreVertical className="h-3.5 w-3.5" />
                            </button>
                            {openMenu === e.id && (
                              <div className="absolute right-0 top-full z-20 mt-1 w-60 rounded-xl border border-border bg-card p-3 text-left shadow-lg">
                                <p className="text-[11px] font-bold text-muted-foreground">ENTITÉ</p>
                                <p className="text-xs">
                                  {e.entity}
                                  {e.entityId ? ` · ${e.entityId.slice(0, 8)}…` : ''}
                                </p>
                                <p className="mt-2 text-[11px] font-bold text-muted-foreground">
                                  DÉTAILS
                                </p>
                                <pre className="max-h-32 overflow-auto whitespace-pre-wrap break-all text-[11px] text-muted-foreground">
                                  {e.metadata ? JSON.stringify(e.metadata, null, 1) : '—'}
                                </pre>
                              </div>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}

          {/* ---------------------------------------------------------- Footer */}
          {data && (
            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-border px-4 py-2.5">
              <p className="text-[11px] text-muted-foreground">
                Affichage {from} - {to} sur {data.total} actions
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
                {pageButtons.map((n, i) =>
                  n === '…' ? (
                    <span key={`gap-${i}`} className="px-0.5 text-xs text-muted-foreground">
                      …
                    </span>
                  ) : (
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
                  ),
                )}
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
              <select
                value={perPage}
                onChange={(e) => {
                  setPerPage(Number(e.target.value));
                  setPage(1);
                }}
                className="rounded-lg border border-border bg-card px-2 py-1 text-[11px] font-semibold outline-none"
              >
                {[10, 25, 50, 100].map((n) => (
                  <option key={n} value={n}>
                    {n} / page
                  </option>
                ))}
              </select>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
