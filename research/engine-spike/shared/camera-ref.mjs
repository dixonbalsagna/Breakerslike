// Engine spike reference camera. Presentation layer: it reads sim state and never writes it.
// Stepped once per sim tick (fixed DT) so it is deterministic and testable headless. Same portability contract as
// sim-ref.mjs: float64, + - * / only, expressions in the written order.
//
// How it avoids pops:
//  1. Floating origin. The camera keeps a wrapped x in [0, W). Renderers draw every object at sdx(cam.x, x), so render
//     space is always centred on the camera and the seam (x = 0 = W) is invisible to the math.
//  2. Continuous arc. `d` is the separation from a to b along the arc the camera is framing. It follows the pair with
//     d += sdx(d, raw), so it never re-chooses the arc on its own, even past half the planet.
//  3. Hysteresis. Only when the framed arc is longer than HALF + HYST does the camera switch to the short arc.
//     That switch moves the target by about half the planet, so the pan speed is capped (PAN_MAX of the view per tick):
//     a fast, continuous pan instead of a cut. Tests count these flips and report the frames spent in them.
import { W, HALF, wrap, sdx, clamp } from './sim-ref.mjs';

export const CAM = {
  MARGIN_X: 700,     // world units added to the horizontal span
  MARGIN_Y: 500,     // world units added to the vertical span
  ASPECT: 16 / 9,    // view width / view height
  MIN_VIEW: 1400,    // narrowest view width, world units
  MAX_VIEW: 7200,    // widest view width, world units (must exceed HALF + HYST + MARGIN_X)
  HYST: 400,         // arc hysteresis, world units
  K: 0.12,           // exponential smoothing per tick for x, y and view width
  PAN_MAX: 0.03,     // cap on horizontal camera motion per tick, as a fraction of the view width
  FLIP_DONE: 0.05,   // a flip pan counts as finished once the remaining offset is under this fraction of the view
  Y_OFF: 40, Y_MIN: -180, Y_MAX: 2400,
  VFOV_DEG: 40,      // renderers: vertical field of view of the perspective camera
  TAN_HALF_HFOV: 0.6470581942510264, // tan(20 deg) * 16/9, precomputed so no libm is needed; D = (viewW/2) / TAN_HALF_HFOV
};

export class Camera {
  constructor() {
    this.x = 0; this.y = 0; this.viewW = CAM.MIN_VIEW; this.d = 0; this.flips = 0; this.flipping = false; this.ready = false;
    this.o = 0;      // signed world-unit offset still to pan (camera -> target), carried across ticks
    this.ax = 0;     // a.x at the previous tick
  }

  target(a, b) {
    const ad = this.d < 0 ? -this.d : this.d;
    const dy = a.y - b.y, ady = dy < 0 ? -dy : dy;
    const spanX = ad + CAM.MARGIN_X, spanY = (ady + CAM.MARGIN_Y) * CAM.ASPECT;
    return {
      x: wrap(a.x + this.d / 2),
      y: clamp((a.y + b.y) / 2 + CAM.Y_OFF, CAM.Y_MIN, CAM.Y_MAX),
      viewW: clamp(spanX > spanY ? spanX : spanY, CAM.MIN_VIEW, CAM.MAX_VIEW),
    };
  }

  // Snap to the pair with no smoothing (scene start).
  reset(a, b) {
    this.d = sdx(a.x, b.x);
    const t = this.target(a, b);
    this.x = t.x; this.y = t.y; this.viewW = t.viewW; this.ready = true; this.flipping = false;
    this.o = 0; this.ax = a.x;
  }

  step(a, b) {
    if (!this.ready) { this.reset(a, b); return; }
    const raw = sdx(a.x, b.x), dPrev = this.d;
    this.d = this.d + sdx(this.d, raw);
    const ad = this.d < 0 ? -this.d : this.d;
    if (ad > HALF + CAM.HYST) { this.d = raw; this.flips++; this.flipping = true; }
    const t = this.target(a, b);
    // The pan offset is carried incrementally: the target midpoint a.x + d/2 moved by a's own motion plus half the
    // change in d (which includes the whole flip jump). That keeps the pan direction of a flip well defined even when
    // the new target sits exactly half a planet away, where sdx() would have to guess. When the offset is small it is
    // re-synced exactly with sdx(), which is unambiguous there, so rounding never accumulates.
    this.o = this.o + sdx(this.ax, a.x) + (this.d - dPrev) / 2;
    this.ax = a.x;
    const oa = this.o < 0 ? -this.o : this.o;
    if (oa < HALF / 2) this.o = sdx(this.x, t.x);
    let mx = this.o * CAM.K;
    const cap = this.viewW * CAM.PAN_MAX;
    if (mx > cap) mx = cap; else if (mx < -cap) mx = -cap;
    this.x = wrap(this.x + mx);
    this.o = this.o - mx;
    if (this.flipping && (this.o < 0 ? -this.o : this.o) < this.viewW * CAM.FLIP_DONE) this.flipping = false;
    this.y = this.y + (t.y - this.y) * CAM.K;
    this.viewW = this.viewW + (t.viewW - this.viewW) * CAM.K;
  }

  viewH() { return this.viewW / CAM.ASPECT; }
  // World position to normalised screen coordinates: (0, 0) top left, (1, 1) bottom right.
  screenX(x) { return 0.5 + sdx(this.x, x) / this.viewW; }
  screenY(y) { return 0.5 - (y - this.y) / this.viewH(); }
  // Perspective renderers: distance from the camera to the z = 0 gameplay plane so that it shows exactly viewW.
  distance() { return (this.viewW / 2) / CAM.TAN_HALF_HFOV; }
}

export function cameraVector(cam) { return Float64Array.of(cam.x, cam.y, cam.viewW, cam.d, cam.o, cam.flips); }
