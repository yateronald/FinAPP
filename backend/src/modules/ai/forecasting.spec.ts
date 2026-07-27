import { backtestMae, dayOfMonthProfile, quantile, selectModel } from './forecasting';

describe('forecasting core', () => {
  it('handles empty and tiny series safely', () => {
    expect(selectModel([]).forecast(3)).toEqual([0, 0, 0]);
    expect(selectModel([500]).forecast(2)).toEqual([500, 500]);
    expect(selectModel([100, 200]).forecast(1)).toEqual([200]); // naive on n<3
  });

  it('never forecasts negative values', () => {
    const declining = [1000, 700, 400, 100, 0, 0];
    const fc = selectModel(declining).forecast(6);
    for (const v of fc) expect(v).toBeGreaterThanOrEqual(0);
  });

  it('tracks a flat series closely', () => {
    const flat = [500, 500, 500, 500, 500, 500];
    const fc = selectModel(flat).forecast(1)[0];
    expect(fc).toBeGreaterThan(450);
    expect(fc).toBeLessThan(550);
  });

  it('captures an upward trend', () => {
    const rising = [100, 200, 300, 400, 500, 600];
    const fc = selectModel(rising).forecast(1)[0];
    expect(fc).toBeGreaterThan(550); // should continue upward, not stay at mean
  });

  it('selects a seasonal model when a strong 12-period cycle exists', () => {
    // Two years of a strong yearly pattern.
    const cycle = [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 1000];
    const y = [...cycle, ...cycle, ...cycle.slice(0, 11)];
    const model = selectModel(y, 12);
    // December spike: next point is the 36th (index 35 → month 12).
    const fc = model.forecast(1)[0];
    expect(fc).toBeGreaterThan(500); // must anticipate the seasonal spike
  });

  it('backtestMae returns Infinity for unusable series', () => {
    expect(backtestMae(() => null, [1, 2, 3, 4], 3)).toBe(Infinity);
  });

  it('day-of-month profile concentrates mass on active days', () => {
    const txs = [
      { date: new Date(Date.UTC(2026, 5, 1)), amount: 900 },
      { date: new Date(Date.UTC(2026, 5, 15)), amount: 100 },
      { date: new Date(Date.UTC(2026, 6, 1)), amount: 800 },
      { date: new Date(Date.UTC(2026, 6, 15)), amount: 200 },
    ];
    const profile = dayOfMonthProfile(txs, [
      { month: 6, year: 2026 },
      { month: 7, year: 2026 },
    ]);
    expect(profile[0]).toBeGreaterThan(0.6); // day 1 dominates
    expect(profile[14]).toBeGreaterThan(0.05); // day 15 present
    const sum = profile.reduce((a, b) => a + b, 0);
    expect(sum).toBeCloseTo(1, 5);
  });

  it('quantile picks the right order statistic', () => {
    expect(quantile([5, 1, 3, 2, 4], 0.8)).toBe(5);
    expect(quantile([], 0.8)).toBe(0);
  });
});
