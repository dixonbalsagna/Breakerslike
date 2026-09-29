// Hiding and the ambush setup: the prototype's updateHidden.
import { sdx } from './wrap.js';
import { opp } from './roster.js';
import { feed } from './events.js';
import { coverAt } from '../world/cover.js';

export function updateHidden(S, f, dt){
  const o = opp(S, f), dist = Math.abs(sdx(f.x, o.x)), c = coverAt(S, f);
  const want = f.stance === 3 && f.state === 'free' && c && dist > 170 && !f.in.charge && !f.in.dash && S.m.hypot(f.vx, f.vy) < 260;
  if (want){
    f.hideT += dt;
    if (f.hideT > 0.9 && !f.hidden){ f.hidden = true; f.hiddenFor = 0; f.lastSeen = {x:f.x, y:f.y}; feed(S, f.name + ' goes to ground', 'Power signature suppressed (' + c + '). Recovering; opponent has no lock-on.'); }
  } else { f.hideT = 0; if (f.hidden){ f.hidden = false; if (dist <= 240) feed(S, f.name + ' found', 'Opponent closed within scouting range.'); else if (f.hiddenFor > 1.8) f.ambushUntil = S.T + 2.5; } }
  if (f.hidden) f.hiddenFor += dt;
}
