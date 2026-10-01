// Origin: shared builder for the marked fighter concepts (mask, sigil, Protagonist's raised fringe and wraps, the Empress's low collar), with no side effects.
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-01. Human direction: Orb, via the EP. Used by the face, damage and form generators.

import { FIGHTERS } from '../directions/fighters.mjs';
import { MASK, maskHead, sigilMarks, pWraps, empressBack } from './marks.mjs';

// Returns a concept for the figure kit. Per figure state: st.sigil (a sigil state: neutral, pride, taunt, hurt, brink, rage, triumph, transform).
export function markedConcept(fk) {
  const base = fk === 'E' ? { ...FIGHTERS.E, back: empressBack } : FIGHTERS[fk], mask = MASK[fk], c = { ...base };
  if (fk === 'P') {
    c.armGear = (ctx, sk) => pWraps(ctx, sk);
    c.hair = (ctx, sk) => {
      const H = a => a.map(([x, y]) => sk.Hd(x, y));
      return ctx.poly(H([[5.8, 16.2], [4.4, 18.3], [0.6, 19.8], [-4.4, 18.4], [-8.4, 14.8], [-12.4, 11.6], [-14, 8.4], [-12, 6.4], [-8.4, 8.2], [-5.8, 6.8], [-5.8, 12.6], [-3.4, 15.6], [1, 16.4]]), ctx.pal.hair.mid);
    };
  }
  c.blankHead = (p, st) => {
    const yaw = st.yaw ?? 0, mh = maskHead(fk, base.blankHead(p), p, mask, yaw);
    return { ...mh, marks: [...mh.marks, ...sigilMarks(fk, p, st.sigil ?? 'neutral', mask, yaw)] };
  };
  return c;
}
