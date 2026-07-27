/**
 * Time-series forecasting core for short financial series.
 *
 * Design rationale (M3/M4 competition evidence): on short monthly series the
 * exponential-smoothing (ETS) family outperforms ARIMA, and damped-trend
 * variants avoid unrealistic runaway extrapolation. SARIMA-style yearly
 * seasonality needs >= 2 full cycles, so seasonal models only enter the
 * candidate pool when enough history exists.
 *
 * Model selection is done per-series by rolling-origin backtesting (one-step
 * ahead), choosing the candidate with the lowest MAE. As the user's history
 * grows, richer models (seasonal) automatically become eligible and win when
 * they genuinely predict better — the system improves with data.
 */

export interface ModelFit {
  /** Human-readable model id, e.g. "damped-holt(a=0.4,b=0.1,phi=0.9)" */
  name: string;
  /** Short label for UI display */
  label: string;
  /** h-step-ahead forecasts (h >= 1), non-negative. */
  forecast: (h: number) => number[];
  /** One-step backtest MAE (lower = better). Infinity when not evaluable. */
  mae: number;
}

type Fitter = (series: number[]) => { predict: (h: number) => number[] } | null;

const nonNeg = (v: number) => (Number.isFinite(v) ? Math.max(0, v) : 0);

/* ------------------------------------------------------------------ models */

/** Simple exponential smoothing — level only. */
function ses(alpha: number): Fitter {
  return (y) => {
    if (y.length < 1) return null;
    let level = y[0];
    for (let i = 1; i < y.length; i++) level = alpha * y[i] + (1 - alpha) * level;
    return { predict: (h) => Array.from({ length: h }, () => nonNeg(level)) };
  };
}

/** Holt's linear trend. */
function holt(alpha: number, beta: number): Fitter {
  return (y) => {
    if (y.length < 2) return null;
    let level = y[0];
    let trend = y[1] - y[0];
    for (let i = 1; i < y.length; i++) {
      const prev = level;
      level = alpha * y[i] + (1 - alpha) * (level + trend);
      trend = beta * (level - prev) + (1 - beta) * trend;
    }
    return {
      predict: (h) => Array.from({ length: h }, (_, k) => nonNeg(level + (k + 1) * trend)),
    };
  };
}

/** Damped-trend Holt — the safe default for financial extrapolation. */
function dampedHolt(alpha: number, beta: number, phi: number): Fitter {
  return (y) => {
    if (y.length < 2) return null;
    let level = y[0];
    let trend = y[1] - y[0];
    for (let i = 1; i < y.length; i++) {
      const prev = level;
      level = alpha * y[i] + (1 - alpha) * (level + phi * trend);
      trend = beta * (level - prev) + (1 - beta) * phi * trend;
    }
    return {
      predict: (h) =>
        Array.from({ length: h }, (_, k) => {
          // damped cumulative trend: sum_{i=1..k+1} phi^i
          let damp = 0;
          for (let i = 1; i <= k + 1; i++) damp += Math.pow(phi, i);
          return nonNeg(level + damp * trend);
        }),
    };
  };
}

/** Additive Holt-Winters with season length m (needs >= 2 full cycles). */
function holtWinters(alpha: number, beta: number, gamma: number, m: number): Fitter {
  return (y) => {
    if (y.length < 2 * m) return null;
    // init: level = mean of first cycle; trend = avg diff between cycles.
    let level = y.slice(0, m).reduce((a, b) => a + b, 0) / m;
    let trend = 0;
    for (let i = 0; i < m; i++) trend += (y[m + i] - y[i]) / m;
    trend /= m;
    const season = y.slice(0, m).map((v) => v - level);

    for (let i = m; i < y.length; i++) {
      const sIdx = i % m;
      const prevLevel = level;
      level = alpha * (y[i] - season[sIdx]) + (1 - alpha) * (level + trend);
      trend = beta * (level - prevLevel) + (1 - beta) * trend;
      season[sIdx] = gamma * (y[i] - level) + (1 - gamma) * season[sIdx];
    }
    const n = y.length;
    return {
      predict: (h) =>
        Array.from({ length: h }, (_, k) =>
          nonNeg(level + (k + 1) * trend + season[(n + k) % m]),
        ),
    };
  };
}

/** Seasonal naive: repeat the value from one season ago. */
function seasonalNaive(m: number): Fitter {
  return (y) => {
    if (y.length < m + 1) return null;
    return {
      predict: (h) =>
        Array.from({ length: h }, (_, k) => nonNeg(y[y.length - m + ((k) % m)])),
    };
  };
}

/** Naive: repeat last value. Baseline that any winner must beat. */
function naive(): Fitter {
  return (y) => {
    if (y.length < 1) return null;
    const last = y[y.length - 1];
    return { predict: (h) => Array.from({ length: h }, () => nonNeg(last)) };
  };
}

/* --------------------------------------------------------------- selection */

interface Candidate {
  name: string;
  label: string;
  fit: Fitter;
}

function candidateSet(n: number, seasonLength: number): Candidate[] {
  const c: Candidate[] = [{ name: 'naive', label: 'Naïve', fit: naive() }];
  for (const a of [0.2, 0.4, 0.6, 0.8]) {
    c.push({ name: `ses(a=${a})`, label: 'Lissage exponentiel simple', fit: ses(a) });
  }
  for (const a of [0.3, 0.5, 0.7]) {
    for (const b of [0.1, 0.3]) {
      c.push({ name: `holt(a=${a},b=${b})`, label: 'Holt (tendance)', fit: holt(a, b) });
      for (const phi of [0.85, 0.95]) {
        c.push({
          name: `damped-holt(a=${a},b=${b},phi=${phi})`,
          label: 'Holt à tendance amortie',
          fit: dampedHolt(a, b, phi),
        });
      }
    }
  }
  if (n >= seasonLength + 1) {
    c.push({
      name: `seasonal-naive(m=${seasonLength})`,
      label: 'Naïve saisonnière',
      fit: seasonalNaive(seasonLength),
    });
  }
  if (n >= 2 * seasonLength) {
    for (const a of [0.3, 0.5]) {
      c.push({
        name: `holt-winters(a=${a},m=${seasonLength})`,
        label: 'Holt-Winters (saisonnier)',
        fit: holtWinters(a, 0.1, 0.1, seasonLength),
      });
    }
  }
  return c;
}

/**
 * Rolling-origin one-step backtest: fit on y[0..t], predict y[t+1], for the
 * last `folds` origins. Returns MAE (Infinity when the model can't run).
 */
export function backtestMae(fit: Fitter, y: number[], folds: number): number {
  const n = y.length;
  const usable = Math.min(folds, n - 2);
  if (usable < 1) return Infinity;
  let sum = 0;
  let count = 0;
  for (let t = n - usable - 1; t < n - 1; t++) {
    const model = fit(y.slice(0, t + 1));
    if (!model) continue;
    const pred = model.predict(1)[0];
    sum += Math.abs(pred - y[t + 1]);
    count++;
  }
  return count > 0 ? sum / count : Infinity;
}

/**
 * Select the best forecasting model for a series via rolling-origin CV.
 * Falls back to naive/mean when history is too short to evaluate.
 */
export function selectModel(series: number[], seasonLength = 12): ModelFit {
  const y = series.map((v) => (Number.isFinite(v) ? v : 0));
  const n = y.length;

  if (n === 0) {
    return { name: 'zero', label: 'Aucune donnée', forecast: (h) => new Array(h).fill(0), mae: Infinity };
  }
  if (n < 3) {
    const last = y[n - 1];
    return {
      name: 'naive',
      label: 'Naïve',
      forecast: (h) => new Array(h).fill(nonNeg(last)),
      mae: Infinity,
    };
  }

  // Backtest over enough origins to expose seasonal structure when history
  // allows (a full cycle + margin); otherwise the recent 6 one-step origins.
  const folds =
    n >= 2 * seasonLength ? Math.min(seasonLength + 2, n - 2) : Math.min(6, n - 2);
  let best: { cand: Candidate; mae: number } | null = null;
  for (const cand of candidateSet(n, seasonLength)) {
    const mae = backtestMae(cand.fit, y, folds);
    if (mae === Infinity) continue;
    if (!best || mae < best.mae - 1e-9) best = { cand, mae };
  }

  const chosen = best ?? { cand: { name: 'naive', label: 'Naïve', fit: naive() }, mae: Infinity };
  const fitted = chosen.cand.fit(y)!;
  return {
    name: chosen.cand.name,
    label: chosen.cand.label,
    forecast: (h) => fitted.predict(h),
    mae: chosen.mae,
  };
}

/* ---------------------------------------------------- day-of-month profile */

/**
 * Learn the average share of a month's total that falls on each day-of-month
 * (1..31) from historical months — this captures the true intra-month
 * seasonality of personal finance (salary day, rent day...). Months with no
 * activity are ignored; a uniform profile is returned when nothing is known.
 */
export function dayOfMonthProfile(
  txs: { date: Date; amount: number }[],
  months: { month: number; year: number }[],
): number[] {
  const profiles: number[][] = [];
  for (const { month, year } of months) {
    const days = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const daily = new Array(31).fill(0);
    let total = 0;
    for (const t of txs) {
      if (t.date.getUTCFullYear() === year && t.date.getUTCMonth() + 1 === month) {
        daily[t.date.getUTCDate() - 1] += t.amount;
        total += t.amount;
      }
    }
    if (total > 0) profiles.push(daily.map((v) => v / total));
    void days;
  }
  if (profiles.length === 0) return new Array(31).fill(1 / 30);

  // Weighted average, most recent month weighted highest.
  const out = new Array(31).fill(0);
  let wSum = 0;
  profiles.forEach((p, i) => {
    const w = i + 1; // oldest → 1, newest → k
    wSum += w;
    for (let d = 0; d < 31; d++) out[d] += w * p[d];
  });
  const normalized = out.map((v) => v / wSum);
  const total = normalized.reduce((a, b) => a + b, 0) || 1;
  return normalized.map((v) => v / total);
}

/** Quantile of |errors| for empirical confidence bands. */
export function quantile(values: number[], q: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.floor(q * sorted.length)));
  return sorted[idx];
}
