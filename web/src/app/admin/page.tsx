'use client';

import {
  Activity,
  BellRing,
  Brain,
  PiggyBank,
  Receipt,
  ShieldCheck,
  Smartphone,
  UserCheck,
  UserX,
  Users,
} from 'lucide-react';
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { useAdminStats } from '@/hooks/use-admin';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

function Stat({
  label,
  value,
  icon: Icon,
  tone = 'default',
  hint,
}: {
  label: string;
  value: number | string;
  icon: React.ElementType;
  tone?: 'default' | 'good' | 'warn' | 'bad';
  hint?: string;
}) {
  const tones: Record<string, string> = {
    default: 'bg-primary/10 text-primary',
    good: 'bg-emerald-500/10 text-emerald-600',
    warn: 'bg-amber-500/10 text-amber-600',
    bad: 'bg-red-500/10 text-red-600',
  };
  return (
    <Card>
      <CardContent className="flex items-center gap-4 p-5">
        <div className={`flex h-11 w-11 items-center justify-center rounded-xl ${tones[tone]}`}>
          <Icon className="h-5 w-5" />
        </div>
        <div className="min-w-0">
          <p className="text-xs font-semibold text-muted-foreground">{label}</p>
          <p className="text-2xl font-extrabold leading-tight">{value}</p>
          {hint && <p className="text-[11px] text-muted-foreground">{hint}</p>}
        </div>
      </CardContent>
    </Card>
  );
}

export default function AdminOverviewPage() {
  const { data, isLoading } = useAdminStats();

  if (isLoading || !data) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    );
  }

  const { users, usage, signupsByDay } = data;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-extrabold">Vue d’ensemble</h1>
        <p className="text-sm text-muted-foreground">
          Supervision de la plateforme — données agrégées uniquement.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Stat label="Utilisateurs" value={users.total} icon={Users} hint={`${users.newLast30} nouveaux (30 j)`} />
        <Stat label="Actifs" value={users.active} icon={UserCheck} tone="good" hint={`${users.activeLast7} connectés (7 j)`} />
        <Stat label="Désactivés" value={users.disabled} icon={UserX} tone={users.disabled ? 'bad' : 'default'} />
        <Stat label="Administrateurs" value={users.admins} icon={ShieldCheck} tone="warn" />
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Inscriptions (30 derniers jours)</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={signupsByDay} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                <XAxis
                  dataKey="date"
                  tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
                  tickFormatter={(v: string) => v.slice(5)}
                  axisLine={false}
                  tickLine={false}
                  minTickGap={24}
                />
                <YAxis
                  allowDecimals={false}
                  width={32}
                  tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
                  axisLine={false}
                  tickLine={false}
                />
                <Tooltip
                  contentStyle={{
                    borderRadius: 12,
                    border: '1px solid hsl(var(--border))',
                    background: 'hsl(var(--card))',
                    fontSize: 12,
                  }}
                />
                <Area
                  type="monotone"
                  dataKey="count"
                  stroke="hsl(var(--primary))"
                  fill="hsl(var(--primary))"
                  fillOpacity={0.15}
                  strokeWidth={2.5}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </CardContent>
      </Card>

      <div>
        <h2 className="mb-3 text-sm font-bold text-muted-foreground">ACTIVITÉ PLATEFORME</h2>
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <Stat label="Dépenses enregistrées" value={usage.expenses} icon={Receipt} />
          <Stat label="Revenus enregistrés" value={usage.incomes} icon={Activity} tone="good" />
          <Stat label="Budgets définis" value={usage.budgets} icon={PiggyBank} />
          <Stat label="Notifications envoyées" value={usage.notifications} icon={BellRing} />
          <Stat label="Appareils enregistrés" value={usage.registeredDevices} icon={Smartphone} />
          <Stat label="Analyses IA générées" value={usage.aiInsights} icon={Brain} tone="warn" />
        </div>
      </div>
    </div>
  );
}
