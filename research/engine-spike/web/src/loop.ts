// Fixed-step accumulator: real time in, a whole number of 60 Hz sim ticks out (at most 8 per frame).
// If a frame is so late that 8 ticks do not cover it, the rest of the backlog is dropped (counted in droppedMs) so the
// sim slows down instead of spiralling. Pure, so Node tests can drive it.
export const STEP_MS = 1000 / 60;
export const MAX_STEPS = 8;

export class FixedStepClock {
  acc: number = 0;
  droppedMs: number = 0;
  stepMs: number;
  maxSteps: number;
  constructor(stepMs: number = STEP_MS, maxSteps: number = MAX_STEPS) {
    this.stepMs = stepMs;
    this.maxSteps = maxSteps;
  }
  // Adds dtMs of real time and returns how many ticks to run now.
  advance(dtMs: number): number {
    if (!(dtMs > 0)) return 0;
    this.acc += dtMs;
    let n = 0;
    while (this.acc >= this.stepMs && n < this.maxSteps) { this.acc -= this.stepMs; n++; }
    if (this.acc >= this.stepMs) {
      const keep = this.acc % this.stepMs;
      this.droppedMs += this.acc - keep;
      this.acc = keep;
    }
    return n;
  }
  // Fraction of a tick that has elapsed since the last tick (for optional interpolation; the spike does not use it).
  alpha(): number { return this.acc / this.stepMs; }
}

export interface Stats { avg: number; p50: number; p95: number; p99: number; max: number; n: number }

// SPEC: sort the samples, pN = sorted[ceil(N/100 * n) - 1].
export function stats(samples: ArrayLike<number>): Stats {
  const n = samples.length;
  if (n === 0) return { avg: 0, p50: 0, p95: 0, p99: 0, max: 0, n: 0 };
  const s = Float64Array.from(samples).sort();
  let sum = 0;
  for (let i = 0; i < n; i++) sum += s[i];
  const p = (q: number): number => s[Math.max(0, Math.ceil((q / 100) * n) - 1)];
  return { avg: sum / n, p50: p(50), p95: p(95), p99: p(99), max: s[n - 1], n };
}

export function round(v: number, digits: number = 4): number {
  const k = 10 ** digits;
  return Math.round(v * k) / k;
}
