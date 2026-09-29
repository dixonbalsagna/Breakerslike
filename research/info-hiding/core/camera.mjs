// Follow camera for any viewport. Presentation layer: reads positions, never writes sim state. DOM-free.
// Frames one target (fixed width) or two (their span on the short arc plus margins). Positions are wrap-aware: the
// camera keeps a wrapped x and every renderer draws at sdx(cam.x, x), so the seam never shows.
// Simpler than research/engine-spike/shared/camera-ref.mjs (no arc hysteresis): when two targets sit almost exactly
// half a planet apart the framed arc can flip. The testbed's modes mostly frame one target per viewport.
import { wrap, sdx, clamp } from './world.mjs';

export const CAM_DEFAULTS = Object.freeze({
  aspect: 16 / 9,   // view width / view height (set it to the viewport rect's aspect)
  minView: 1400,    // world units across, narrowest (also the width used for a single target)
  maxView: 7200,
  marginX: 700, marginY: 500,
  k: 0.12,          // smoothing per step (1 = snap)
  yOff: 40, yMin: -420, yMax: 2400,
});

export class FollowCam {
  constructor(opts = {}) {
    this.o = { ...CAM_DEFAULTS, ...opts };
    this.x = 0; this.y = 0; this.viewW = this.o.minView; this.ready = false;
  }
  setAspect(a) { this.o.aspect = a; }
  target(ts) {
    const o = this.o;
    if (ts.length === 1 || !ts[1]) {
      const a = ts[0];
      return { x: wrap(a.x), y: clamp(a.y + o.yOff, o.yMin, o.yMax), viewW: o.fixedView ?? o.minView };
    }
    const a = ts[0], b = ts[1], d = sdx(a.x, b.x);
    const spanX = Math.abs(d) + o.marginX, spanY = (Math.abs(a.y - b.y) + o.marginY) * o.aspect;
    return {
      x: wrap(a.x + d / 2),
      y: clamp((a.y + b.y) / 2 + o.yOff, o.yMin, o.yMax),
      viewW: clamp(spanX > spanY ? spanX : spanY, o.minView, o.maxView),
    };
  }
  snap(ts) { const t = this.target(ts); this.x = t.x; this.y = t.y; this.viewW = t.viewW; this.ready = true; return this; }
  step(ts) {
    if (!this.ready) return this.snap(ts);
    const t = this.target(ts), k = this.o.k;
    this.x = wrap(this.x + sdx(this.x, t.x) * k);
    this.y = this.y + (t.y - this.y) * k;
    this.viewW = this.viewW + (t.viewW - this.viewW) * k;
    return this;
  }
  // The world rectangle this camera shows: centre (x, y), size viewW x viewH.
  view() { return { x: this.x, y: this.y, viewW: this.viewW, viewH: this.viewW / this.o.aspect }; }
}

// A static view (no smoothing), e.g. for an inset centred on a point.
export function viewAt(x, y, viewW, aspect = 16 / 9) { return { x: wrap(x), y, viewW, viewH: viewW / aspect }; }
