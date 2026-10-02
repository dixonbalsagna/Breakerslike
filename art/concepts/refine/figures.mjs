// Origin: procedural silhouette variants for the refinement sheets (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-02. Human direction: Orb, via the EP.
// The Cyborg gets six directions (one is the current figure for the comparison); the Protagonist, Anti-hero and Empress get two small options each on top of today's figure.
// Every variant is a concept for the figure kit (art/concepts/anti-hero/kit.mjs): a build, a pose, a palette, and a few extra shapes.

import { makeCtx, figure, limb, V, add, sub, mul, norm, along, pts, dirDown } from '../anti-hero/kit.mjs';
import { FIGHTERS, PALETTES } from '../directions/fighters.mjs';
import { PAL } from '../shared/marks.mjs';
import { markedConcept } from '../shared/styled.mjs';

const Tm = (sk, a) => a.map(([x, y]) => sk.T(x, y));
const At = (p, a) => a.map(([x, y]) => add(p, V(x, y)));
const raw = (a, fill, extra = '') => `<polygon points="${pts(a)}" fill="${fill}" ${extra}/>`;
const mk = (base, shadow, light) => ({ light, mid: base, shadow });

const C0 = FIGHTERS.C;
// the Cyborg's own cfg helper: the base figure's colours from a palette
const cfgOf = (pal, over = {}) => ({ ...C0.cfg(pal), ...over });
const palOf = (o) => ({ line: '#14070a', skin: mk('#c4aaa4', '#85706c', '#d8c4be'), hair: mk('#3a161c', '#220b10', '#3a161c'), ...o });
const PALE = mk('#f0d6c2', '#a98676', '#f8eadd');

// ============================================================================================================ the Cyborg
export const CYBORG_DIRS = {
  // 0: the figure today, for the comparison
  current: { name: 'Today', concept: () => ({ ...C0 }), pal: () => PALETTES.C, pose: C0.poses.base, build: null },

  // 1: THE STEPPER. The same fighter, refined: light plates over a dark body (the value split the figure lacks), a staircase rising behind him, a stacked pauldron, a stepped crown.
  stepper: {
    name: 'The Stepper',
    pal: () => palOf({ base: mk('#2f2b36', '#1c1922', '#4a4652'), gear: mk('#d8d0c8', '#9c948f', '#f1ece6'), accent: PALE }),
    concept(pal) {
      return {
        ...C0, id: 'C-step', build: { tw: 1.32, tl: 1.0, lw: 1.32, hs: 1.0, leg: 1.0, arm: 1.05 },
        cfg: p => cfgOf(p, { torso: p.gear.mid, torsoShade: p.gear.shadow, bootTrim: p.accent.mid }),
        back(ctx, sk) {   // a staircase rising behind: four blocks, each higher than the last, the highest well above the head
          const stair = [[-6, 2], [-6, 24], [-9.6, 24], [-9.6, 31], [-13.2, 31], [-13.2, 38], [-16.8, 38], [-16.8, 45], [-20.4, 45], [-20.4, 2]];
          let s = ctx.poly(Tm(sk, stair), ctx.pal.gear.mid, { sw: 1.4 });
          if (!ctx.flat) for (let i = 0; i < 4; i++) { const x0 = -6 - i * 3.6, top = 24 + i * 7; s += ctx.line(Tm(sk, [[x0, top], [x0 - 3.6, top]]), ctx.pal.accent.light, 1.6) + ctx.line(Tm(sk, [[x0 - 3.6, top], [x0 - 3.6, 4]]), ctx.pal.gear.shadow, 1.2); }
          return s;
        },
        over(ctx, sk) {   // a stacked pauldron on the near shoulder, three boxes stepping out
          let s = ''; const S = sk.S;
          [[7.4, 4.2, 0], [6.2, 3.6, 4.2], [5, 3.2, 7.8]].forEach(([w, h, y], i) => { s += ctx.poly(At(S, [[-w * 0.45, y - 1.4], [w * 0.7, y - 1.4], [w * 0.7, y + h - 1.4], [-w * 0.45, y + h - 1.4]]), i === 1 ? ctx.pal.gear.shadow : ctx.pal.gear.mid, { sw: 1.2 }); });
          return s;
        },
        front() { return ''; },
        armGear(ctx, sk) { const A = sk.nearArm; return ctx.poly(limb(along(A.E, A.W, 0.1), along(A.E, A.W, 1.0), 7 * sk.b.lw, 6.6 * sk.b.lw, 1.05), ctx.pal.gear.mid, { sw: 1.2 }); },
        blankHead: p => ({ poly: [[-5.8, 0.6], [-5.8, 19.4], [-1.4, 19.4], [-1.4, 17.4], [3, 17.4], [3, 15.6], [6.8, 15.6], [6.8, 0.6]], shade: [[-5.8, 0.6], [-5.8, 19.4], [-3.4, 19.4], [-3.4, 0.6]], fill: p.gear.mid, shadow: p.gear.shadow, neck: p.base.shadow, marks: [{ poly: [[2.2, 8.8], [6.8, 8.8], [6.8, 10.8], [2.2, 10.8]], fill: p.accent.light }] }),
      };
    },
  },

  // 2: THE STACK. The same fighter, bolder: he is built from separate blocks with gaps; the head slides. Steps are how he is built.
  stack: {
    name: 'The Stack',
    pal: () => palOf({ base: mk('#34313d', '#201d27', '#4e4a58'), gear: mk('#9a9097', '#6a6168', '#c9c0c4'), accent: PALE }),
    concept() {
      return {
        ...C0, id: 'C-stack', build: { tw: 1.2, tl: 1.04, lw: 1.18, hs: 1.05, leg: 1.0, arm: 1.0 },
        back() { return ''; },
        over(ctx, sk, st) {
          let s = ''; const bg = st.bg ?? '#e8e5ee', cols = [ctx.pal.base.shadow, ctx.pal.gear.mid, ctx.pal.base.mid, ctx.pal.gear.shadow];
          [[-1, 8.2, 1.6, 7.4], [9.6, 17, -1.4, 7.8], [18.4, 27.4, 2.0, 8.8]].forEach(([y0, y1, dx, hw], i) => { s += ctx.poly(Tm(sk, [[-hw + dx, y0], [hw + dx, y0], [hw + dx, y1], [-hw + dx, y1]]), cols[i], { sw: 1.3 }); });
          if (!ctx.flat) for (const y of [8.8, 17.7]) s += raw(Tm(sk, [[-12, y - 0.6], [12, y - 0.6], [12, y + 0.6], [-12, y + 0.6]]), bg);
          return s;
        },
        front() { return ''; },
        armGear(ctx, sk) { const A = sk.nearArm; return ctx.poly(limb(along(A.E, A.W, 0.55), A.F, 7.4 * sk.b.lw, 6.8 * sk.b.lw, 1.05), ctx.pal.gear.mid, { sw: 1.2 }); },
        blankHead: p => ({
          poly: [[-6.4 + 1.6, 11.2], [7.2 + 1.6, 11.2], [7.2 + 1.6, 17.6], [-6.4 + 1.6, 17.6]],
          fill: p.base.mid, shadow: p.base.shadow, neck: '#00000000',
          marks: [{ poly: [[-5.4, 5.8], [6.2, 5.8], [6.2, 10.4], [-5.4, 10.4]], fill: p.skin.mid }, { poly: [[-4.6 - 1.4, 0.6], [5.6 - 1.4, 0.6], [5.0 - 1.4, 5], [-4.6 - 1.4, 5]], fill: p.gear.mid }, { poly: [[2.4 + 1.6, 14.4], [7.2 + 1.6, 14.4], [7.2 + 1.6, 15.6], [2.4 + 1.6, 15.6]], fill: p.accent.light }],
        }),
      };
    },
  },

  // 3: THE FURNACE. Bolder: a mountain of a fighter, a sunk head, humped shoulders, heat vents in the plates, gauntlets like anvils.
  furnace: {
    name: 'The Furnace',
    pal: () => palOf({ skin: mk('#8a7673', '#5e4f4d', '#a8938f'), base: mk('#26242a', '#171519', '#3c3a40'), gear: mk('#5b5760', '#35323a', '#7d7882'), accent: PALE }),
    concept() {
      return {
        ...C0, id: 'C-furnace', build: { tw: 1.72, tl: 0.96, lw: 1.55, hs: 0.84, leg: 0.88, arm: 1.12 },
        cfg: p => cfgOf(p, { torso: p.gear.mid, torsoShade: p.gear.shadow, sleeve: p.gear.shadow }),
        back(ctx, sk) { return ctx.poly(At(sk.S, [[-12, -4], [-9, 8], [0, 9], [3, 0]]), ctx.pal.gear.shadow, { sw: 1.3 }); },
        over(ctx, sk) {
          let s = ctx.poly(At(sk.S, [[-8, -3], [-6, 7], [3, 8.4], [11, 4], [12, -4]]), ctx.pal.gear.mid, { sw: 1.4 });
          s += ctx.poly(Tm(sk, [[-2, 10], [7.4, 10], [7.4, 20], [-2, 20]]), ctx.pal.base.shadow, { sw: 1.3 });   // the furnace door
          if (!ctx.flat) { s += ctx.line(Tm(sk, [[-1, 11], [6.4, 11], [6.4, 19], [-1, 19], [-1, 11]]), ctx.pal.accent.light, 1.1); for (let i = 0; i < 3; i++) s += ctx.poly(Tm(sk, [[0, 12.4 + i * 2.4], [5.4, 12.4 + i * 2.4], [5.4, 13.6 + i * 2.4], [0, 13.6 + i * 2.4]]), ctx.pal.accent.light, { sw: 0.4, line: false }); }
          return s;
        },
        front() { return ''; },
        armGear(ctx, sk) { const A = sk.nearArm; return ctx.poly(limb(along(A.E, A.W, 0.1), A.F, 9.6 * sk.b.lw, 11.4 * sk.b.lw, 1.04), ctx.pal.gear.mid, { sw: 1.3 }); },
        blankHead: p => ({ poly: [[-4.4, 0.6], [-6.8, 14], [-6.2, 16.2], [7.2, 16.2], [7.8, 14], [5.6, 0.6]], shade: [[-4.4, 0.6], [-6.8, 14], [-6.2, 16.2], [-3.4, 16.2]], fill: p.gear.mid, shadow: p.gear.shadow, neck: p.base.shadow, marks: [{ poly: [[-6.4, 10.2], [7.6, 10.2], [7.6, 12.6], [-6.4, 12.6]], fill: p.base.shadow }, { poly: [[1.0, 8.6], [3.2, 8.6], [3.2, 9.6], [1.0, 9.6]], fill: p.accent.light }, { poly: [[4.6, 8.6], [6.8, 8.6], [6.8, 9.6], [4.6, 9.6]], fill: p.accent.light }] }),
      };
    },
  },

  // 4: THE FRAME. Bolder: a lean open frame with the background showing through the chest, a person's face in a window, a cable for a spine.
  frame: {
    name: 'The Frame',
    pal: () => palOf({ base: mk('#2b2830', '#1b191f', '#44404c'), gear: mk('#d8d0c8', '#8c8187', '#f1ece6'), accent: PALE }),
    concept() {
      return {
        ...C0, id: 'C-frame', build: { tw: 0.96, tl: 1.1, lw: 0.84, hs: 1.06, leg: 1.12, arm: 1.1 },
        back(ctx, sk) {   // the cable spine, with ring joints
          let s = ctx.line(Tm(sk, [[-6.6, 30], [-8, 22], [-6.8, 14], [-8, 6], [-6.6, 0]]), ctx.pal.base.shadow, 3.4);
          for (const y of [26, 18, 10, 3]) s += ctx.poly(Tm(sk, [[-9.4, y + 1.4], [-5.4, y + 1.4], [-5.4, y - 1.4], [-9.4, y - 1.4]]), ctx.pal.gear.mid, { sw: 1 });
          return s;
        },
        over(ctx, sk, st) {   // the chest is an open frame: a ring of plate with the background showing through three slots
          const bg = st.bg ?? '#e8e5ee'; let s = ctx.poly(Tm(sk, [[-8, 5], [8, 5], [8, 30], [-8, 30]]), ctx.pal.gear.mid, { sw: 1.4 });
          [[22.4, 27.4], [15.2, 20.4], [8.2, 13.2]].forEach(([y0, y1]) => { s += raw(Tm(sk, [[-5.4, y0], [5.4, y0], [5.4, y1], [-5.4, y1]]), bg, 'stroke="#14070a" stroke-width="0.5"'); });
          if (!ctx.flat) s += ctx.poly(Tm(sk, [[-1.6, 16.2], [1.8, 16.2], [1.8, 19.4], [-1.6, 19.4]]), ctx.pal.accent.light, { sw: 0.6 });
          for (const l of [sk.nearLeg, sk.farLeg]) s += ctx.poly(At(l.K, [[-2.8, -2.6], [2.8, -2.6], [2.8, 2.6], [-2.8, 2.6]]), ctx.pal.gear.mid, { sw: 1 });
          return s;
        },
        front() { return ''; },
        armGear(ctx, sk) { const A = sk.nearArm; return ctx.poly(limb(along(A.E, A.W, 0.3), A.W, 4.4 * sk.b.lw, 4 * sk.b.lw, 1.0), ctx.pal.gear.mid, { sw: 1.1 }); },
        blankHead: p => ({ poly: [[-6.4, 0.6], [-6.4, 16.4], [7.2, 16.4], [7.2, 0.6]], fill: p.gear.mid, shadow: p.gear.shadow, neck: p.base.shadow, marks: [{ poly: [[-4, 3], [5.2, 3], [5.2, 14], [-4, 14]], fill: p.skin.mid }, { poly: [[0.6, 9], [1.8, 9], [1.8, 10.4], [0.6, 10.4]], fill: '#14070a' }, { poly: [[3.2, 9], [4.4, 9], [4.4, 10.4], [3.2, 10.4]], fill: '#14070a' }] }),
      };
    },
  },

  // 5: THE PROSTHETIC. The same fighter, humane: a working man with one enormous hydraulic arm and a plate leg; the lopsided silhouette is the hook.
  worker: {
    name: 'The Prosthetic',
    pal: () => palOf({ base: mk('#3a2a2e', '#231a1d', '#54404a'), gear: mk('#8c8187', '#5e5459', '#cfc7cb'), accent: PALE, skin: mk('#c4aaa4', '#85706c', '#d8c4be') }),
    concept() {
      return {
        ...C0, id: 'C-worker', machineHead: false, hideNearHand: true, build: { tw: 1.2, tl: 1.0, lw: 1.1, hs: 1.0, leg: 1.0, arm: 1.0 },
        cfg: p => cfgOf(p, { sleeveFar: p.skin.shadow, sleeve: p.skin.mid, sleeveShade: p.skin.shadow, foreSkin: true, torso: p.base.mid }),
        back() { return ''; },
        over(ctx, sk) {   // a vest, and a plate shin on the near leg
          const L = sk.nearLeg; let s = ctx.poly(Tm(sk, [[-5.8, 29], [5.2, 29], [6, 12], [-6, 12]]), ctx.pal.base.shadow, { sw: 1.2 });
          s += ctx.poly(limb(L.K, L.A, 6.8, 5.6, 1.05), ctx.pal.gear.mid, { sw: 1.2 }) + ctx.poly(At(L.K, [[-3.4, -2.4], [3.4, -2.4], [3.4, 2.4], [-3.4, 2.4]]), ctx.pal.gear.shadow, { sw: 1 });
          return s;
        },
        front() { return ''; },
        armGear(ctx, sk) {   // the great arm: a stepped hydraulic gauntlet from the shoulder, with a piston and a fist like a block
          const A = sk.nearArm; let s = ctx.poly(limb(sk.S, A.E, 11.6, 12.4, 1.04), ctx.pal.gear.mid, { sw: 1.3 }) + ctx.poly(limb(A.E, A.W, 12.8, 15.4, 1.04), ctx.pal.gear.shadow, { sw: 1.3 });
          const d = norm(sub(A.F, A.W)), n = V(-d.y, d.x), c = add(A.F, mul(d, 3));
          s += ctx.poly([add(add(c, mul(d, 7)), mul(n, 8.6)), add(add(c, mul(d, 7)), mul(n, -8.6)), add(add(c, mul(d, -6)), mul(n, -9.4)), add(add(c, mul(d, -6)), mul(n, 9.4))], ctx.pal.gear.mid, { sw: 1.4 });
          s += ctx.line([add(sk.S, V(-3, -3)), add(A.E, V(-3, 5))], ctx.pal.gear.light, 2.2);
          return s;
        },
        hair(ctx, sk) { const Hd = (x, y) => sk.Hd(x, y); return ctx.poly([[-5.2, 12.2], [-5.6, 16.8], [0, 17.8], [6.8, 16.4], [7.4, 12.2], [4.4, 13.4], [1, 13.4], [-2, 12]].map(([x, y]) => Hd(x, y)), ctx.pal.hair.mid); },
        blankHead: undefined,
      };
    },
  },

  // 6: THE SPRINTER. Bolder: a lean runner on springs. Reverse-knee legs with blade feet, a low trailing fin, swept hair, a headset slab.
  runner: {
    name: 'The Sprinter',
    pal: () => palOf({ base: mk('#3a3640', '#24212a', '#55505e'), gear: mk('#e9e4e6', '#a79ea4', '#fbf8f9'), accent: PALE }),
    pose: { lean: 16, head: 4, nearArm: [-34, -70], farArm: [30, 60], nearLeg: [-24, 18, 0], farLeg: [6, 34, 0], handNear: 'fist', handFar: 'fist' },
    concept() {
      return {
        ...C0, id: 'C-run', machineHead: false, build: { tw: 0.96, tl: 1.0, lw: 0.86, hs: 0.96, leg: 1.22, arm: 1.0 },
        cfg: p => cfgOf(p, { torso: p.gear.mid, torsoShade: p.gear.shadow, sleeve: p.base.mid, bootTrim: p.accent.mid }),
        back(ctx, sk) { return ctx.poly(Tm(sk, [[-6, 27], [-20, 21], [-19, 18], [-6, 20]]), ctx.pal.gear.shadow, { sw: 1.2 }); },
        over(ctx, sk) {   // a spring behind each shin, and a blade foot
          let s = '';
          for (const l of [sk.farLeg, sk.nearLeg]) {
            const mid = add(along(l.K, l.A, 0.5), V(-5.2, 0)); s += ctx.poly([l.K, mid, l.A, add(l.A, V(0, 1.6)), add(mid, V(2.4, 0)), add(l.K, V(1.4, 0))], ctx.pal.gear.mid, { sw: 1.1 });
            s += ctx.poly([add(l.A, V(-2, -1)), add(l.A, V(11, -2.6)), add(l.A, V(11.4, -4.2)), add(l.A, V(-2.4, -3))], ctx.pal.gear.mid, { sw: 1.1 });
          }
          return s;
        },
        front() { return ''; },
        armGear() { return ''; },
        hair(ctx, sk) { const Hd = (x, y) => sk.Hd(x, y); return ctx.poly([[6.6, 12.4], [5.4, 17.4], [-2, 18.4], [-12, 15.6], [-18.6, 12], [-11, 13], [-6, 9.6], [-5.8, 13.6], [0, 14.6], [4, 13.2]].map(([x, y]) => Hd(x, y)), ctx.pal.hair.mid) + ctx.poly([[-5.4, 7.2], [-1.4, 7.2], [-1.4, 11.4], [-5.4, 11.4]].map(([x, y]) => Hd(x, y)), ctx.pal.base.shadow) + ctx.poly([[-4.6, 8.2], [-2.2, 8.2], [-2.2, 9], [-4.6, 9]].map(([x, y]) => Hd(x, y)), ctx.pal.accent.light, { line: false }); },
        blankHead: undefined,
      };
    },
  },
};

// ============================================================================================================ the other three: two small options each
// Each option adds to today's figure (a trailing feature and one change of mass); the figure underneath is unchanged.
function withExtra(concept, add_) {
  const prev = concept.after;
  return { ...concept, after: (ctx, sk, st, cfg) => (prev ? prev(ctx, sk, st, cfg) : '') + add_(ctx, sk, st, cfg) };
}
function withBack(concept, add_) {
  const prev = concept.back;
  return { ...concept, back: (ctx, sk, st, cfg) => add_(ctx, sk, st, cfg) + (prev ? prev(ctx, sk, st, cfg) : '') };
}
const headPt = (sk, x, y) => sk.Hd(x, y);
export const OTHER_OPTS = {
  P: {
    base: () => markedConcept('P'),
    options: [
      { name: 'Option 1: the long tuft', note: 'The tuft grows into a long swept ribbon that trails and hooks, and the belt knot gets bigger: a clearer wind line.', make: () => withBack(markedConcept('P'), (ctx, sk) => ctx.poly([[-4, 13], [-14, 15], [-26, 10], [-36, 2], [-40, -6], [-34, -4], [-26, 0], [-16, 3], [-5, 9]].map(([x, y]) => headPt(sk, x, y)), ctx.pal.hair.shadow, { sw: 1.3 }) + ctx.poly(Tm(sk, [[-6, 14], [-14, 18], [-18, 12], [-16, 6], [-8, 8]]), ctx.pal.gear.mid, { sw: 1.2 })) },
      { name: 'Option 2: the big fists', note: 'The wrapped fists and shoulders swell into big round masses (his circles): a heavier, friendlier silhouette from the front.', make: () => withExtra(markedConcept('P'), (ctx, sk) => { let s = ''; const ring = (c, r) => Array.from({ length: 12 }, (_, i) => V(c.x + Math.cos(i / 12 * Math.PI * 2) * r, c.y + Math.sin(i / 12 * Math.PI * 2) * r)); s += ctx.poly(ring(sk.nearArm.F, 6.2), ctx.pal.gear.mid, { sw: 1.3 }) + ctx.poly(ring(sk.farArm.F, 5.4), ctx.pal.gear.shadow, { sw: 1.3 }) + ctx.poly(ring(add(sk.S, V(0.4, -0.4)), 6.4), ctx.pal.base.mid, { sw: 1.3 }); return s; }) },
    ],
  },
  A: {
    base: () => markedConcept('A'),
    options: [
      { name: 'Option 1: the long tail and coat blades', note: 'The tail runs to the knee and three coat strips hang from the waist as blades: a longer, narrower slash.', make: () => withExtra(markedConcept('A'), (ctx, sk) => { let s = ctx.poly([[-3, 15], [-12, 12], [-20, 0], [-26, -18], [-34, -42], [-22, -22], [-13, -4], [-5, 8]].map(([x, y]) => headPt(sk, x, y)), ctx.pal.hair.mid, { sw: 1.3 }); for (let i = 0; i < 3; i++) s += ctx.poly(Tm(sk, [[-6 + i * 3.6, 8], [-1.4 + i * 3.6, 8], [-5.6 + i * 3.6, -22 - i * 3]]), i === 1 ? ctx.pal.accent.mid : ctx.pal.base.mid, { sw: 1.2 }); return s; }) },
      { name: 'Option 2: the swept shoulder blade', note: 'A swept blade of cloth streams back from one shoulder, low and long, not tall: a second line to the silhouette.', make: () => withExtra(markedConcept('A'), (ctx, sk) => ctx.poly(At(sk.S, [[-2, 4], [-12, 5], [-28, -4], [-40, -14], [-26, -8], [-12, -3], [-2, -1]]), ctx.pal.accent.mid, { sw: 1.3 }) + ctx.poly(At(sk.S, [[-2, 1], [-14, 0], [-30, -12], [-14, -5]]), ctx.pal.base.shadow, { sw: 1 })) },
    ],
  },
  E: {
    base: () => markedConcept('E'),
    options: [
      { name: 'Option 1: the wide mantle', note: 'The mantle spreads to a much wider hem of points that reaches the knee: a heavier wedge at the base.', make: () => withExtra(markedConcept('E'), (ctx, sk) => { let s = ''; for (let i = 0; i < 7; i++) { const x0 = -8 - i * 4.2; s += ctx.poly(Tm(sk, [[-6, 22 - i * 1.4], [x0, 22 - i * 1.4], [x0 - 4, -2 - i * 3.4]]), i % 2 ? ctx.pal.base.shadow : ctx.pal.accent.shadow, { sw: 1.2 }); } return s; }) },
      { name: 'Option 2: the crown and train', note: 'A wider, lower topknot and a long train of two blades trailing from the waist along the floor: height at the head, weight behind.', make: () => withExtra(markedConcept('E'), (ctx, sk) => ctx.poly(Tm(sk, [[-5, 8], [-1, 8], [-30, -22], [-36, -24]]), ctx.pal.accent.mid, { sw: 1.2 }) + ctx.poly(Tm(sk, [[-3, 6], [2, 6], [-24, -26], [-34, -27]]), ctx.pal.base.shadow, { sw: 1.2 }) + ctx.poly(Array.from({ length: 14 }, (_, i) => headPt(sk, -1.4 + Math.cos(i / 14 * Math.PI * 2) * 5.2, 21 + Math.sin(i / 14 * Math.PI * 2) * 4.2)), ctx.pal.hair.mid, { sw: 1.2 })) },
    ],
  },
};

// draw one figure: x is the root of the figure on the ground line, s the pixels per body unit
export function drawFigure({ concept, pal, pose, flat = false, bg = '#e8e5ee', x, ground, s, yaw = 0 }) {
  const ctx = makeCtx({ flat, pal, swMul: s > 1.4 ? 1.3 : 1, faceless: false });
  const st = { yaw, state: 'neutral', sigil: 'neutral', sway: concept.sway ?? 4, expression: 'neutral', open: 0, forms: 6, wear: 0, hairLoose: false, bg };
  const { svg } = figure(ctx, concept, pose, st, { yaw });
  return `<g transform="translate(${x.toFixed(2)} ${ground.toFixed(2)}) scale(${s.toFixed(3)} ${(-s).toFixed(3)})">${svg}</g>`;
}
export const POSE0 = k => FIGHTERS[k].poses?.base ?? { lean: 8, head: 0, nearArm: [38, 44], farArm: [-26, -2], nearLeg: [18, 4], farLeg: [-16, -6], handNear: 'fist', handFar: 'fist' };
export { PAL };
