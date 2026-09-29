// Keyboard bindings and key state to intent, host side: the prototype's KEYS and humanInput (which becomes intentFromKeys).
import { createIntent } from './intent.js';

export const KEYS = {
  p1:{l:'KeyA',r:'KeyD',u:'KeyW',d:'KeyS',dash:'Space',light:'KeyF',heavy:'KeyG',sig:'KeyR',charge:'KeyQ',st:['Digit1','Digit2','Digit3','Digit4']},
  p2:{l:'ArrowLeft',r:'ArrowRight',u:'ArrowUp',d:'ArrowDown',dash:'Enter',light:'Comma',heavy:'Period',sig:'Slash',charge:'Semicolon',st:['Digit7','Digit8','Digit9','Digit0']}
};

// k: KEYS.p1 or KEYS.p2. held: codes currently down (movement, dash, charge). edges: codes pressed, not auto-repeated,
// since the last tick that returned true (attacks, stance keys); the host clears edges only after such a tick.
export function intentFromKeys(k, held, edges){
  const i = createIntent();
  i.mx = (held.has(k.r) ? 1 : 0) - (held.has(k.l) ? 1 : 0);
  i.my = (held.has(k.u) ? 1 : 0) - (held.has(k.d) ? 1 : 0);
  i.dash = held.has(k.dash); i.charge = held.has(k.charge);
  i.light = edges.has(k.light); i.heavy = edges.has(k.heavy); i.sig = edges.has(k.sig);
  for (let s = 0; s < 4; s++) if (edges.has(k.st[s])) i.stance = s;
  return i;
}
