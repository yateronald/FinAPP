'use client';

import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  PolarAngleAxis,
  PolarGrid,
  Radar,
  RadarChart,
  RadialBar,
  RadialBarChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { formatNumber } from '@/lib/utils';

interface Series {
  key: string;
  name?: string;
  color?: string;
}
interface ChartSpec {
  type?: string;
  title?: string;
  xKey?: string;
  series?: Series[];
  data?: Record<string, any>[];
  // gauge fields
  value?: number;
  max?: number;
  unit?: string;
  label?: string;
}

const PALETTE = [
  '#6366f1',
  '#22c55e',
  '#f59e0b',
  '#ec4899',
  '#0ea5e9',
  '#a855f7',
  '#ef4444',
  '#14b8a6',
  '#84cc16',
  '#f97316',
];

const tooltipStyle = {
  borderRadius: 12,
  border: '1px solid hsl(var(--border))',
  background: 'hsl(var(--card))',
  fontSize: 12,
  color: 'hsl(var(--foreground))',
};

const axisTick = { fontSize: 11, fill: 'hsl(var(--muted-foreground))' };

export function ChartRenderer({ raw }: { raw: string }) {
  let spec: ChartSpec | null = null;
  try {
    spec = JSON.parse(raw);
  } catch {
    spec = null;
  }

  const rawPre = (
    <pre className="overflow-x-auto rounded-lg bg-muted p-3 text-xs text-muted-foreground">{raw}</pre>
  );
  if (!spec) return rawPre;

  const type = (spec.type || 'bar').toLowerCase().replace(/[\s_-]/g, '');
  const isGauge = ['gauge', 'radial', 'radialbar', 'progress'].includes(type);

  // Gauge is the only type that doesn't require a data array.
  if (!isGauge && (!Array.isArray(spec.data) || spec.data.length === 0)) return rawPre;

  const data = spec.data ?? [];
  const xKey = spec.xKey || 'name';
  const series =
    spec.series && spec.series.length
      ? spec.series
      : [{ key: 'value', name: 'Valeur', color: PALETTE[0] }];

  const Frame = ({ children }: { children: React.ReactNode }) => (
    <figure className="my-2 rounded-xl border border-border bg-card p-3">
      {spec!.title && (
        <figcaption className="mb-2 text-sm font-semibold text-foreground">{spec!.title}</figcaption>
      )}
      <div className="relative h-64 w-full">{children}</div>
    </figure>
  );

  // ------------------------------------------------------------- Gauge
  if (isGauge) {
    const first = (data[0] as any) ?? {};
    const value = Number(spec.value ?? first.value ?? 0);
    const max = Number(spec.max ?? first.max ?? 100) || 100;
    const frac = Math.max(0, Math.min(1, max > 0 ? value / max : 0));
    const center = spec.unit ? `${value}${spec.unit}` : formatNumber(value);
    const gaugeData = [{ name: spec.label || '', value: frac * 100 }];
    return (
      <Frame>
        <ResponsiveContainer width="100%" height="100%">
          <RadialBarChart
            innerRadius="68%"
            outerRadius="100%"
            data={gaugeData}
            startAngle={225}
            endAngle={-45}
          >
            <PolarAngleAxis type="number" domain={[0, 100]} tick={false} />
            <RadialBar background dataKey="value" cornerRadius={12} fill={PALETTE[0]} />
          </RadialBarChart>
        </ResponsiveContainer>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-2xl font-extrabold text-foreground">{center}</span>
          <span className="text-xs font-semibold text-muted-foreground">{Math.round(frac * 100)}%</span>
          {spec.label && <span className="mt-0.5 text-xs text-muted-foreground">{spec.label}</span>}
        </div>
      </Frame>
    );
  }

  // ------------------------------------------------------------- Radar
  if ((type === 'radar' || type === 'spider') && data.length >= 3) {
    return (
      <Frame>
        <ResponsiveContainer width="100%" height="100%">
          <RadarChart data={data}>
            <PolarGrid stroke="hsl(var(--border))" />
            <PolarAngleAxis dataKey={xKey} tick={axisTick} />
            {series.map((s, i) => (
              <Radar
                key={s.key}
                dataKey={s.key}
                name={s.name || s.key}
                stroke={s.color || PALETTE[i % PALETTE.length]}
                fill={s.color || PALETTE[i % PALETTE.length]}
                fillOpacity={0.15}
              />
            ))}
            <Tooltip contentStyle={tooltipStyle} formatter={(v: number) => formatNumber(v)} />
            <Legend wrapperStyle={{ fontSize: 12 }} />
          </RadarChart>
        </ResponsiveContainer>
      </Frame>
    );
  }

  const isPie = ['pie', 'donut', 'doughnut'].includes(type);
  const isHorizontal = ['horizontalbar', 'hbar', 'barh'].includes(type);
  const isStacked = ['stackedbar', 'stacked'].includes(type);

  return (
    <Frame>
      <ResponsiveContainer width="100%" height="100%">
        {isPie ? (
          <PieChart>
            <Pie
              data={data}
              dataKey={series[0].key}
              nameKey={xKey}
              innerRadius={type === 'pie' ? 50 : 55}
              outerRadius={90}
              paddingAngle={2}
              strokeWidth={0}
            >
              {data.map((d, i) => (
                <Cell key={i} fill={(d as any).color || PALETTE[i % PALETTE.length]} />
              ))}
            </Pie>
            <Tooltip contentStyle={tooltipStyle} formatter={(v: number) => formatNumber(v)} />
            <Legend wrapperStyle={{ fontSize: 12 }} />
          </PieChart>
        ) : type === 'line' ? (
          <LineChart data={data} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
            <XAxis dataKey={xKey} axisLine={false} tickLine={false} tick={axisTick} />
            <YAxis axisLine={false} tickLine={false} tick={axisTick} width={48} tickFormatter={(v) => formatNumber(v)} />
            <Tooltip contentStyle={tooltipStyle} formatter={(v: number) => formatNumber(v)} />
            <Legend wrapperStyle={{ fontSize: 12 }} />
            {series.map((s, i) => (
              <Line
                key={s.key}
                type="monotone"
                dataKey={s.key}
                name={s.name || s.key}
                stroke={s.color || PALETTE[i % PALETTE.length]}
                strokeWidth={2.5}
                dot={{ r: 3 }}
              />
            ))}
          </LineChart>
        ) : type === 'area' ? (
          <AreaChart data={data} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
            <XAxis dataKey={xKey} axisLine={false} tickLine={false} tick={axisTick} />
            <YAxis axisLine={false} tickLine={false} tick={axisTick} width={48} tickFormatter={(v) => formatNumber(v)} />
            <Tooltip contentStyle={tooltipStyle} formatter={(v: number) => formatNumber(v)} />
            <Legend wrapperStyle={{ fontSize: 12 }} />
            {series.map((s, i) => (
              <Area
                key={s.key}
                type="monotone"
                dataKey={s.key}
                name={s.name || s.key}
                stroke={s.color || PALETTE[i % PALETTE.length]}
                fill={s.color || PALETTE[i % PALETTE.length]}
                fillOpacity={0.15}
                strokeWidth={2.5}
              />
            ))}
          </AreaChart>
        ) : (
          <BarChart
            data={data}
            layout={isHorizontal ? 'vertical' : 'horizontal'}
            margin={{ top: 8, right: 8, left: 0, bottom: 0 }}
          >
            <CartesianGrid strokeDasharray="3 3" vertical={isHorizontal} horizontal={!isHorizontal} stroke="hsl(var(--border))" />
            {isHorizontal ? (
              <>
                <XAxis type="number" axisLine={false} tickLine={false} tick={axisTick} tickFormatter={(v) => formatNumber(v)} />
                <YAxis type="category" dataKey={xKey} axisLine={false} tickLine={false} tick={axisTick} width={80} />
              </>
            ) : (
              <>
                <XAxis dataKey={xKey} axisLine={false} tickLine={false} tick={axisTick} />
                <YAxis axisLine={false} tickLine={false} tick={axisTick} width={48} tickFormatter={(v) => formatNumber(v)} />
              </>
            )}
            <Tooltip cursor={{ fill: 'hsl(var(--muted))' }} contentStyle={tooltipStyle} formatter={(v: number) => formatNumber(v)} />
            <Legend wrapperStyle={{ fontSize: 12 }} />
            {series.map((s, i) => (
              <Bar
                key={s.key}
                dataKey={s.key}
                name={s.name || s.key}
                stackId={isStacked ? 'a' : undefined}
                radius={isStacked ? [0, 0, 0, 0] : isHorizontal ? [0, 4, 4, 0] : [4, 4, 0, 0]}
                maxBarSize={48}
                fill={s.color || PALETTE[i % PALETTE.length]}
              />
            ))}
          </BarChart>
        )}
      </ResponsiveContainer>
    </Frame>
  );
}
