// Per-fighter input step, run once per fighter per tick in random order: the prototype's control().
import { clearIntent, applyIntent } from './intent.js';
import { aiInput } from '../director/ai.js';
import { requestAttack } from '../director/exchange.js';

// intent: the host's intent for a human fighter (intentFromKeys, a replay or the network). AI fighters ignore it; null leaves f neutral.
export function control(S, f, intent){
  const i = f.in;
  clearIntent(i);
  if (S.game.ko) return;
  if (f.ai) aiInput(S, f); else if (intent) applyIntent(i, intent);
  if (i.stance >= 0) f.stance = i.stance;
  if (i.light || i.heavy) f.lastAtkT = S.T;
  if (i.light) requestAttack(S, f, 'light'); else if (i.heavy) requestAttack(S, f, 'heavy'); else if (i.sig) requestAttack(S, f, 'sig');
}
