// Deterministic sin, cos, pow and hypot: the same bits on every platform and in every language (ADR 0001,
// determinism.md). They use only + - * / sqrt floor on float64, and every constant is either a short decimal literal
// or computed by IEEE division, so a port that evaluates the same expressions in the same order gets the same bits.
// sim/core/detmath.gd is the GDScript twin; it builds PIO2_1, PIO2_1T, LN2_HI and LN2_LO from their bit patterns
// (GDScript's literal parser is not correctly rounded for long literals), and the golden vectors check all constants.
// Accuracy is a few ulp over the ranges the sim uses (|x| < 1e5 for sin and cos); determinism is the point.
//
// A sim picks its math with createSim({math}): 'native' (Math.*, the prototype's; parity with the prototype) or 'det'
// (these; parity with the GDScript port).

const PIO2_1 = 1.5707963267341256;        // the first 33 bits of pi/2: n*PIO2_1 is exact for |n| < 2^20
const PIO2_1T = 6.077100506506192e-11;    // pi/2 - PIO2_1
const INVPIO2 = 1 / (PIO2_1 + PIO2_1T);
const LN2_HI = 0.6931471803691238;        // the first 32 bits of ln 2
const LN2_LO = 1.9082149292705877e-10;    // ln 2 - LN2_HI
const INVLN2 = 1 / (LN2_HI + LN2_LO);
const SQRT2 = Math.sqrt(2), SQRT_HALF = SQRT2 / 2;

// Series coefficients, built by exact-order IEEE division so every port reproduces them bit for bit.
const SIN_C = [], COS_C = [], EXP_C = [], LOG_C = [];
{
  let s = 1, c = 1, e = 1;
  for (let k = 1; k <= 11; k++) {
    s = s / ((2 * k) * (2 * k + 1)); SIN_C.push(k % 2 ? -s : s);          // -1/3!, +1/5!, ...
    c = c / ((2 * k - 1) * (2 * k)); COS_C.push(k % 2 ? -c : c);          // -1/2!, +1/4!, ...
  }
  for (let n = 1; n <= 18; n++) { e = e / n; EXP_C.push(e); }            // 1/1!, 1/2!, ... 1/18!
  for (let k = 1; k <= 12; k++) LOG_C.push(1 / (2 * k + 1));            // 1/3, 1/5, ... 1/25
}

// sin and cos on |r| <= pi/4 (Horner, highest term first).
function ksin(r) {
  const z = r * r;
  let p = SIN_C[10];
  for (let k = 9; k >= 0; k--) p = SIN_C[k] + z * p;
  return r + r * z * p;
}
function kcos(r) {
  const z = r * r;
  let p = COS_C[10];
  for (let k = 9; k >= 0; k--) p = COS_C[k] + z * p;
  return 1 + z * p;
}
// x = n*(pi/2) + r with |r| <= about pi/4; returns the quadrant n mod 4 and r.
function reduce(x) {
  const n = Math.floor(x * INVPIO2 + 0.5);
  const r = (x - n * PIO2_1) - n * PIO2_1T;
  return [n - 4 * Math.floor(n / 4), r];
}

export function sin(x) {
  const [q, r] = reduce(x);
  return q === 0 ? ksin(r) : q === 1 ? kcos(r) : q === 2 ? -ksin(r) : -kcos(r);
}
export function cos(x) {
  const [q, r] = reduce(x);
  return q === 0 ? kcos(r) : q === 1 ? -ksin(r) : q === 2 ? -kcos(r) : ksin(r);
}

// e^x for |x| up to about 700.
export function exp(x) {
  const k = Math.floor(x * INVLN2 + 0.5);
  const r = (x - k * LN2_HI) - k * LN2_LO;                  // |r| <= about 0.35
  let p = EXP_C[17];
  for (let i = 16; i >= 0; i--) p = EXP_C[i] + r * p;
  let y = 1 + r * p;
  for (let i = 0; i < k; i++) y = y * 2;                    // scaling by powers of two is exact
  for (let i = 0; i > k; i--) y = y / 2;
  return y;
}

// Natural log for finite x > 0.
export function log(x) {
  let m = x, e = 0;
  while (m >= SQRT2) { m = m / 2; e++; }
  while (m < SQRT_HALF) { m = m * 2; e--; }
  const s = (m - 1) / (m + 1), z = s * s;
  let p = LOG_C[11];
  for (let k = 10; k >= 0; k--) p = LOG_C[k] + z * p;
  const lm = 2 * s + 2 * s * z * p;
  return e * LN2_HI + (e * LN2_LO + lm);
}

// x^y for the sim's uses: a positive base to any power, or any base squared.
export function pow(x, y) {
  if (y === 2) return x * x;
  if (y === 0 || x === 1) return 1;
  if (x === 0) return y > 0 ? 0 : Infinity;
  if (x < 0) return NaN;
  return exp(y * log(x));
}

export function hypot(x, y) { return Math.sqrt(x * x + y * y); }

// The two math tables a sim can use (S.m).
export const DET = { sin, cos, pow, hypot };
export const NATIVE = { sin: Math.sin, cos: Math.cos, pow: Math.pow, hypot: Math.hypot };
export const CONSTANTS = { PIO2_1, PIO2_1T, INVPIO2, LN2_HI, LN2_LO, INVLN2, SQRT2, SQRT_HALF, SIN_C, COS_C, EXP_C, LOG_C };
