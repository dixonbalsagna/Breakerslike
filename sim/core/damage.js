// Damage model: the prototype's hurt, hit and ko.
import { opp } from './roster.js';
import { spark, banner } from './fx.js';
import { feed } from './events.js';
import { endEx } from '../director/exchange.js';
import { doLaunch } from '../director/launch.js';

export function hurt(S, f, amt, by){ f.hp -= amt; f.hurtT = S.T; if (f.hp <= 0 && !S.game.ko) ko(S, f, by || opp(S, f)); }
export function hit(S, ex, A, D, dmg, o){
  o = o || {};
  let m = A.dmgMul * (1 + 0.09*(A.tier-1));
  if (A.role === 'villain') m *= 1 + 0.25*(A.menace/100); else m *= 1 + 0.5*Math.pow(1 - A.hp/A.maxhp, 2);
  m *= 1 + 0.12*((ex ? ex.combo : 1) - 1);
  if (A.ambush) m *= 1.5;
  let sm = 1;
  if (!o.ignoreStance){ sm = [1.12,0.38,1.0,1.25][D.stance]; if (D.state === 'charging') sm = 1.35; }
  const dd = dmg*m*sm;
  if (D.state === 'charging') D.state = 'free';
  if (D.stance === 1 && !o.ignoreStance) D.ki = Math.max(0, D.ki - dd*0.08);
  A.ki = Math.min(100, A.ki + dd*0.04);
  D.power = Math.min(100, D.power + dd*0.010); A.power = Math.min(100, A.power + dd*0.006);
  spark(S, D.x, D.y+34, o.big ? 18 : 9, '#fff3c0', 600);
  S.fx.floats.push({x:D.x, y:D.y+90, txt:String(Math.round(dd)), t:0, col:o.ignoreStance ? '#ffd45a' : '#ffffff'});
  S.dirS.stop = Math.max(S.dirS.stop, o.stop || 0.05);
  S.fx.shake = Math.max(S.fx.shake, o.shake || 6);
  hurt(S, D, dd, A);
  return dd;
}
export function ko(S, D, A){
  if (S.game.ko) return;
  S.game.ko = D; S.game.koT = 0; S.game.ts = 0.35; D.hp = 0;
  banner(S, 'K.O.  ' + A.name + ' WINS', '#ffd45a', 4);
  feed(S, 'K.O. — ' + A.name + ' wins', 'Casualties ' + Math.round(S.world.casualties) + ', structures lost ' + S.world.structuresLost);
  if (S.dirS.ex) endEx(S, S.dirS.ex);
  A.state = A.state === 'locked' ? 'free' : A.state;
  if (D.state !== 'launched') doLaunch(S, A, D, {ux:A.face*0.9, uy:0.5}, 1800);
}
