// Seam crossing with moving fighters on the port: fighters flown, dashed and launched through x = 0 / x = W, and AI
// matches started astride the seam. Nothing may go NaN, leave [0, W), jump, or take the long way round.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createSim, newMatch, step } from '../sim.js';
import { createCamera, resetCamera, camStep } from '../view/camera.js';
import { createIntent } from '../../input/intent.js';
import { sdx, wrap } from '../wrap.js';
import { W, HALF, DT } from '../constants.js';

const NUM = ['x', 'y', 'vx', 'vy', 'hp', 'ki', 'power', 'rot', 'spin'];
const finite = f => NUM.every(k => Number.isFinite(f[k]));

function fly({ from, other, intent, seconds = 20 }) {
  const S = createSim(), cam = createCamera();
  newMatch(S, 3, { p1: false, p2: false }); resetCamera(cam);
  const [a, b] = S.fighters;
  a.x = from; a.y = 60; b.x = other; b.y = 60;
  const i0 = Object.assign(createIntent(), intent);
  let crossings = 0;
  for (let i = 0; i < seconds * 60; i++) {
    const px = a.x, pcx = cam.x;
    step(S, [i0, null]); camStep(cam, S, S.dt, 1200, 700);
    assert.ok(finite(a) && finite(b) && Number.isFinite(cam.x + cam.y + cam.z), `non-finite at step ${i}`);
    assert.ok(a.x >= 0 && a.x < W && cam.x >= 0 && cam.x < W, `x out of range at step ${i}`);
    assert.ok(Math.abs(sdx(px, a.x) - a.vx * DT) < 1e-6, `step ${i}: moved ${sdx(px, a.x)}, vx*dt ${a.vx * DT}`);
    assert.ok(Math.abs(sdx(pcx, cam.x)) < 0.1 * HALF, `camera jumped at step ${i}`);
    assert.ok(Math.abs(sdx(a.x, b.x)) <= HALF);
    if (Math.abs(a.x - px) > HALF) crossings++;
  }
  assert.ok(crossings >= 1, 'never crossed the seam');
  assert.ok(Math.abs(sdx(cam.x, wrap(a.x + sdx(a.x, b.x) / 2))) < 600, 'camera did not follow the pair the short way');
}

test('fly east across the seam', () => fly({ from: W - 500, other: 100, intent: { mx: 1 } }));
test('fly west across the seam', () => fly({ from: 500, other: W - 100, intent: { mx: -1 } }));
test('dash east across the seam while climbing', () => fly({ from: W - 900, other: 200, intent: { mx: 1, dash: true, my: 1 }, seconds: 10 }));
test('dash west across the seam while diving', () => fly({ from: 900, other: W - 200, intent: { mx: -1, dash: true, my: -1 }, seconds: 10 }));

function launched(x0, vx) {
  const S = createSim(); newMatch(S, 4, { p1: false, p2: false });
  const [a, b] = S.fighters;
  b.x = 5000; b.y = 60;
  Object.assign(a, { x: x0, y: 300, vx, vy: 200, state: 'launched', launchBy: null, stateT: 0 });
  let crossings = 0;
  for (let i = 0; i < 6 * 60; i++) {
    const px = a.x, sp = Math.hypot(a.vx, a.vy);
    step(S, [null, null]);
    assert.ok(finite(a) && a.x >= 0 && a.x < W, `step ${i}`);
    assert.ok(Math.abs(sdx(px, a.x)) <= sp * DT * 1.05 + 1e-6, `step ${i}: moved ${sdx(px, a.x)} at speed ${sp}`);
    if (Math.abs(a.x - px) > HALF) crossings++;
  }
  assert.ok(crossings >= 1, 'launch never reached the seam');
}
test('launched fighter crosses the seam eastward', () => launched(W - 300, 2500));
test('launched fighter crosses the seam westward', () => launched(300, -2500));

test('AI vs AI matches started astride the seam stay finite and continuous', () => {
  const S = createSim();
  let crossings = 0, worst = 0;
  for (let s = 1; s <= 24; s++) {
    newMatch(S, 700 + s, { p1: true, p2: true });
    const fs = S.fighters, flip = s % 2;
    fs[0].x = flip ? 300 : W - 300; fs[1].x = flip ? W - 300 : 300; fs[0].y = fs[1].y = 60;
    const prev = fs.map(f => f.x);
    for (let n = 0; n < 18000 && !(S.game.ko && S.game.koT > 3); n++) {
      step(S); S.out.feed.length = 0;
      fs.forEach((f, i) => {
        assert.ok(finite(f), `seed ${700 + s}: NaN`);
        assert.ok(f.x >= 0 && f.x < W, `seed ${700 + s}: x ${f.x}`);
        if (Math.abs(f.x - prev[i]) > HALF) crossings++;
        worst = Math.max(worst, Math.abs(sdx(prev[i], f.x))); prev[i] = f.x;
      });
    }
  }
  assert.ok(worst < 300, `a fighter moved ${worst} units in one tick`);
  assert.ok(crossings >= 5, `only ${crossings} seam crossings: the scenario is not exercising the seam`);
});
