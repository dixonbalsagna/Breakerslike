// Hiding testbed: the simulation. DOM-free, fixed 60 Hz step, seeded RNG. Rendering and bots only read it.
// Rules reproduced from prototype/index.html (updateHidden, stepFighter): see RULES and README.md.
import { DT, TPS, wrap, sdx, clamp, Rng, coverAt } from './world.mjs';

export const RULES = Object.freeze({
  // hiding (prototype updateHidden)
  hideDelay: 0.9,        // s in escape stance, in cover, before the fighter is hidden
  hideMinDist: 170,      // opponent must be further than this (horizontal) to hide or stay hidden
  hideMaxSpeed: 260,     // u/s; moving faster breaks hiding
  foundDist: 240,        // leaving cover with the opponent within this (horizontal) counts as found
  ambushMinHidden: 1.8,  // s hidden before leaving cover grants an ambush
  ambushWindow: 2.5,     // s after leaving cover in which the next landed strike is an ambush
  ambushMul: 1.5,
  hpRegenHidden: 40,     // HP/s while hidden
  kiRegenHidden: 25,     // extra ki/s while hidden (on top of the base rate, as in the prototype)
  kiRegenBase: 5,
  // strike
  strikeRange: 150,      // 2D distance (wrap-aware x)
  strikeDamage: 60,      // +-10 % from the sim RNG
  strikeCooldown: 0.4,
  // flight (prototype stepFighter, stance 0 and stance 3)
  speed: 430, escapeMul: 1.35, dashMul: 2.4, waterMul: 0.55, vertMul: 0.85, accelDecay: 0.0008, ceiling: 2600,
  maxhp: 1000,
});

// Durations as whole ticks, so rules never depend on float accumulation.
const tk = (s) => Math.round(s * TPS);
export const TICKS = Object.freeze({
  hideDelay: tk(RULES.hideDelay),            // 54: hidden on the 55th consecutive qualifying tick (> 0.9 s)
  ambushMinHidden: tk(RULES.ambushMinHidden), // 108: needs > 1.8 s hidden
  ambushWindow: tk(RULES.ambushWindow),       // 150
  strikeCooldown: tk(RULES.strikeCooldown),   // 24
});
const ACCEL_K = 1 - Math.pow(RULES.accelDecay, DT);   // prototype: k = 1 - 0.0008^dt

export const NO_INPUT = Object.freeze({ mx: 0, my: 0, dash: false, strike: false, escape: false });

function makeFighter(id, s = {}) {
  const maxhp = s.maxhp ?? RULES.maxhp;
  return {
    id, x: wrap(s.x ?? 0), y: s.y ?? 200, vx: 0, vy: 0, face: 1, speed: 0,
    hp: s.hp ?? maxhp, maxhp, ki: s.ki ?? 60,
    escape: false,      // stance: false = normal, true = escape (the hide key)
    dashing: false,
    cover: null,        // cover kind at the current position ('submerged' | 'canopy' | 'ridge' | null)
    hidden: false,
    hideTicks: 0,       // consecutive ticks meeting the hiding conditions
    hiddenTicks: 0,     // ticks hidden in the current spell
    lastSeen: null,     // {x, y, tick} where this fighter last went to ground
    ambushUntil: -1,    // last tick of the ambush window (inclusive), -1 when none
    strikeCd: 0,
    busy: false,        // struck or was struck this tick (breaks hiding for the tick)
  };
}

export class Sim {
  // fighters: [{x, y, hp, ki, maxhp}, {...}]. Index 0 and 1 are the two players.
  constructor({ world, seed = 1, fighters = [{}, {}] } = {}) {
    if (!world) throw new Error('Sim needs a world (new World() or sharedWorld())');
    this.world = world;
    this.seed = seed >>> 0;
    this.rng = new Rng(this.seed);
    this.tick = 0;
    this.fighters = [makeFighter(0, fighters[0]), makeFighter(1, fighters[1])];
    this.events = [];       // this tick only
  }
  get t() { return this.tick / TPS; }
  opp(i) { return this.fighters[1 - i]; }

  step(inputs = [NO_INPUT, NO_INPUT]) {
    this.tick++;
    this.events = [];
    const inp = [inputs[0] || NO_INPUT, inputs[1] || NO_INPUT];
    for (const f of this.fighters) { if (f.strikeCd > 0) f.strikeCd--; f.busy = false; }
    for (let i = 0; i < 2; i++) this.move(i, inp[i]);
    for (let i = 0; i < 2; i++) if (inp[i].strike) this.strike(i);
    for (let i = 0; i < 2; i++) this.updateHidden(i);
    for (let i = 0; i < 2; i++) this.regen(i);
    return this.events;
  }

  emit(type, who, extra) {
    const f = this.fighters[who];
    this.events.push({ type, who, tick: this.tick, x: f.x, y: f.y, ...extra });
  }

  move(i, inp) {
    const f = this.fighters[i], R = RULES, world = this.world;
    f.escape = !!inp.escape;
    f.dashing = !!inp.dash;
    const mx = clamp(+inp.mx || 0, -1, 1), my = clamp(+inp.my || 0, -1, 1);
    let sp = R.speed * (f.escape ? R.escapeMul : 1);
    if (f.dashing) sp *= R.dashMul;
    if (f.y < 0 && world.seaAt(f.x)) sp *= R.waterMul;
    f.vx += (mx * sp - f.vx) * ACCEL_K;
    f.vy += (my * sp * R.vertMul - f.vy) * ACCEL_K;
    f.x = wrap(f.x + f.vx * DT);
    f.y += f.vy * DT;
    const g = world.groundY(f.x);
    if (f.y < g) { f.y = g; if (f.vy < 0) f.vy = 0; }
    if (f.y > R.ceiling) { f.y = R.ceiling; f.vy = 0; }
    f.speed = Math.hypot(f.vx, f.vy);
    if (f.vx > 5) f.face = 1; else if (f.vx < -5) f.face = -1;
  }

  // A strike always breaks the striker's cover. It lands when the target is visible and within strikeRange (2D).
  // The ambush bonus applies to the first strike that lands inside the window; a whiff does not use it up.
  strike(i) {
    const f = this.fighters[i], o = this.opp(i), R = RULES;
    if (f.strikeCd > 0) return;
    f.strikeCd = TICKS.strikeCooldown;
    const dx = sdx(f.x, o.x), dist = Math.abs(dx);
    if (f.hidden) this.reveal(i, dist, 'strike');
    f.busy = true;
    const ambush = f.ambushUntil >= 0 && this.tick <= f.ambushUntil;
    const d2 = Math.hypot(dx, o.y - f.y);
    if (!o.hidden && d2 <= R.strikeRange) {
      const base = R.strikeDamage * this.rng.range(0.9, 1.1), mul = ambush ? R.ambushMul : 1, dmg = base * mul;
      o.hp = Math.max(0, o.hp - dmg);
      o.busy = true;
      if (ambush) f.ambushUntil = -1;
      this.emit('strike', i, { target: o.id, dmg, base, mul, ambush, dist: d2 });
      if (ambush) this.emit('ambush', i, { target: o.id, dmg });
      if (o.hp <= 0) this.emit('ko', o.id, { by: i });
    } else {
      this.emit('whiff', i, { dist: d2, armed: ambush });
    }
  }

  // Leaving cover. Within foundDist of the opponent: found. Otherwise, after more than ambushMinHidden hidden, the
  // ambush window opens.
  reveal(i, dist, why) {
    const f = this.fighters[i], hiddenFor = f.hiddenTicks / TPS;
    f.hidden = false;
    if (dist <= RULES.foundDist) this.emit('found', i, { by: 1 - i, dist, hiddenFor, why });
    else if (f.hiddenTicks > TICKS.ambushMinHidden) {
      f.ambushUntil = this.tick + TICKS.ambushWindow;
      this.emit('ambushReady', i, { until: f.ambushUntil, hiddenFor });
    }
    this.emit('unhidden', i, { dist, hiddenFor, why });
  }

  updateHidden(i) {
    const f = this.fighters[i], o = this.opp(i), R = RULES;
    const dist = Math.abs(sdx(f.x, o.x));
    f.cover = coverAt(f, this.world.terrain);
    const want = f.escape && f.cover !== null && dist > R.hideMinDist && !f.dashing && f.speed < R.hideMaxSpeed && !f.busy;
    if (want) {
      f.hideTicks++;
      if (f.hideTicks > TICKS.hideDelay && !f.hidden) {
        f.hidden = true; f.hiddenTicks = 0;
        f.lastSeen = { x: f.x, y: f.y, tick: this.tick };
        this.emit('hidden', i, { cover: f.cover });
      }
    } else {
      f.hideTicks = 0;
      if (f.hidden) this.reveal(i, dist, f.busy ? 'hit' : f.cover === null ? 'left cover' : !f.escape ? 'stance' : dist <= R.hideMinDist ? 'close' : 'moved');
    }
    if (f.hidden) f.hiddenTicks++;
  }

  regen(i) {
    const f = this.fighters[i], R = RULES;
    f.ki = Math.min(100, f.ki + (R.kiRegenBase + (f.hidden ? R.kiRegenHidden : 0)) * DT);
    if (f.hidden) f.hp = Math.min(f.maxhp, f.hp + R.hpRegenHidden * DT);
  }

  // Plain numbers for hashing and determinism checks.
  stateVector() {
    const v = [this.tick, this.rng.state()];
    for (const f of this.fighters) v.push(f.x, f.y, f.vx, f.vy, f.hp, f.ki, f.hidden ? 1 : 0, f.hideTicks, f.hiddenTicks, f.ambushUntil, f.strikeCd);
    return v;
  }
}
