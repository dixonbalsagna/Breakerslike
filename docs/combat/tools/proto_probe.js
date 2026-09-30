// Combat feel probe for the prototype (prototype/index.html, unchanged since 7233c96): same frame classes and thresholds as
// feel_probe.gd. From the repo root: node docs/combat/tools/proto_probe.js [matches=40] [baseSeed=100001]
// Strike-type events are read from state: an hp drop of either fighter, a fighter becoming 'launched', or a parry feed line.
const path = require('path');
const ROOT = path.join(__dirname, '..', '..', '..');
const { load } = require(path.join(ROOT, 'prototype', 'tools', 'headless.js'));
const MOVE = 100, HOLD_VIS = 6, CLOSE_X = 400, CLOSE_Y = 300, DT = 1 / 60, MAX_STEPS = 60 * 300, W = 9600, HALF = W / 2;
const sdx = (a, b) => { let d = (b - a) % W; if (d > HALF) d -= W; else if (d < -HALF) d += W; return d; };
const n = +(process.argv[2] || 40), base = +(process.argv[3] || 100001);
const { wf, feedLog } = load({ html: path.join(ROOT, 'prototype', 'index.html') });
const g = { exFrames: 0, exIdle: 0, exFreeze: 0, idleRuns: [], firstStrike: [], strikeGaps: [], strikes: 0, fightSec: 0, exSec: 0, exLen: [], standFrames: 0, standRuns: [], outFrames: 0, breath: [], mF: 0, mI: 0, mRuns: [], mLen: [] };
for (let m = 0; m < n; m++) {
  wf.dirS.lastLaunch = ''; delete wf.dirS.lastLaunch2; feedLog.length = 0;
  wf.newMatch(base + m);
  const fs = wf.fighters();
  let px = fs.map(f => f.x), py = fs.map(f => f.y), php = fs.map(f => f.hp), pst = fs.map(f => f.state);
  let setP = false, exF = 0, exI = 0, vis = 0, inEx = false, exT0 = 0, run = 0, longest = 0, got = false, lastStrikeT = -1, stand = 0, lastRelease = -1, fi = 0;
  for (let s = 0; s < MAX_STEPS && !wf.game.ko; s++) {
    const T0 = wf.T();
    wf.step(DT);
    const T = wf.T(), freeze = T === T0, dt = T - T0;
    let struck = false, moved = false;
    for (let k = 0; k < 2; k++) {
      const f = fs[k];
      if (f.hp < php[k] - 0.5) struck = true;
      if (f.state === 'launched' && pst[k] !== 'launched') struck = true;
      const dx = Math.abs(sdx(px[k], f.x)), dy = Math.abs(f.y - py[k]);
      if (!freeze && Math.hypot(dx, dy) > MOVE * DT) moved = true;
      px[k] = f.x; py[k] = f.y; php[k] = f.hp; pst[k] = f.state;
    }
    while (fi < feedLog.length) { if (/PARRIES$/.test(feedLog[fi][1])) struck = true; fi++; }
    if (struck) { vis = HOLD_VIS; g.strikes++; if (lastStrikeT >= 0 && T > lastStrikeT) g.strikeGaps.push(T - lastStrikeT); lastStrikeT = T; }
    const nowEx = !!wf.dirS.ex;
    if (nowEx && !inEx) { inEx = true; exT0 = T; run = 0; longest = 0; got = false; exF = 0; exI = 0; setP = wf.dirS.ex.kind === 'sig'; if (lastRelease >= 0) g.breath.push(T - lastRelease); if (stand > 0) { g.standRuns.push(stand / 60); stand = 0; } }
    if (!freeze) g.fightSec += dt;
    if (inEx) {
      g.exFrames++;
      if (freeze) g.exFreeze++;
      else { g.exSec += dt; exF++; if (moved || vis > 0) run = 0; else { g.exIdle++; exI++; run++; longest = Math.max(longest, run); } }
      if (struck && !got) { got = true; g.firstStrike.push(T - exT0); }
    } else {
      g.outFrames++;
      const close = Math.abs(sdx(fs[0].x, fs[1].x)) < CLOSE_X && Math.abs(fs[0].y - fs[1].y) < CLOSE_Y;
      const calm = !moved && fs[0].state !== 'launched' && fs[1].state !== 'launched';
      if (close && calm && !freeze) { g.standFrames++; stand++; } else if (stand > 0) { g.standRuns.push(stand / 60); stand = 0; }
    }
    if (inEx && !nowEx) { inEx = false; g.exLen.push(T - exT0); g.idleRuns.push(longest / 60); if (!setP) { g.mF += exF; g.mI += exI; g.mRuns.push(longest / 60); g.mLen.push(T - exT0); } lastRelease = T; }
    if (vis > 0) vis--;
  }
}
const med = v => { if (!v.length) return -1; const s = [...v].sort((a, b) => a - b); return s[Math.floor(s.length / 2)]; };
const pct = (v, p) => { if (!v.length) return -1; const s = [...v].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(s.length * p))]; };
const r = x => Math.round(x * 1000) / 1000;
console.log(JSON.stringify({ label: 'prototype', summary: {
  idle_share_in_exchanges: r(g.exIdle / Math.max(1, g.exFrames - g.exFreeze)),
  freeze_share_in_exchanges: r(g.exFreeze / Math.max(1, g.exFrames)),
  longest_idle_per_exchange_med_s: r(med(g.idleRuns)), longest_idle_per_exchange_p90_s: r(pct(g.idleRuns, 0.9)),
  request_to_first_strike_med_s: r(med(g.firstStrike)),
  gap_between_strikes_med_s: r(med(g.strikeGaps)), gap_between_strikes_p90_s: r(pct(g.strikeGaps, 0.9)),
  strikes_per_min: r(g.strikes / Math.max(1, g.fightSec / 60)),
  exchange_len_med_s: r(med(g.exLen)), share_time_in_exchanges: r(g.exSec / Math.max(1, g.fightSec)),
  standoff_share_outside: r(g.standFrames / Math.max(1, g.outFrames)), standoff_run_med_s: r(med(g.standRuns)), standoff_run_p90_s: r(pct(g.standRuns, 0.9)),
  release_to_next_request_med_s: r(med(g.breath)), melee_idle_share: r(g.mI / Math.max(1, g.mF)), melee_longest_idle_med_s: r(med(g.mRuns)), melee_longest_idle_p90_s: r(pct(g.mRuns, 0.9)), melee_len_med_s: r(med(g.mLen)) } }));
