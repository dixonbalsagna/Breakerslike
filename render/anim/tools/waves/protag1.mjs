// The Protagonist's strikes (docs/combat/launch-pair-movesets.md section 3; docs/design/launch-pair-plan.md; Legal RL-063 to RL-065) as pose sketches. He is the earnest
// martial artist: open hands, rounder arcs, a taller and bouncier stance (his profile, data/anim/fighters.json, shape P). The rival's wave 1 (34 slots) is the base:
//   redo   12 slots whose silhouette must change to read as his (below, with the reason): authored here
//   reuse  the other 22: the rival's three poses with his profile applied (wave_gen.mjs, `profile`), no new sketch
//   own    8 strikes only he has (Combat's list): palm push, ridge hand, rising palm, knife-hand chop, hammer-fist, crescent kick, hook kick, spinning back kick
// Why these twelve (the rival's hand strikes and round kicks read as blades, claws and straight lines; his read as arcs and flat open hands):
//   hook, overhand, haymaker   the three round hand blows: the rival's are tight and sharp-elbowed; his swing wide and long with the free hand up at his cheek
//   palm_heel, spear_hand      the rival's clawed palm and low blade thrust from a crouch; his are a flat open palm and an upright straight-fingered thrust
//   twin_spear, double_palm, cross_arm_ram   the rival's parallel blades, clawed palms and crossed wedge; his are a high-low pair, flat palms with the elbows in, side-by-side forearms
//   snap_round, roundhouse, spinning_heel, sweep   the round kicks: his hands stay up and open (the rival's trail back), the turn is rounder; the sweep is a wide arc from a low crouch
// Not changed by silhouette (they read as his through the profile: open hands, taller stance): jab, cross, backfist (his ridge hand is the same idea, so the slot stays), the
// uppercut and its fist, the hammer, the elbows, the straight kicks, the knees, the drop kick, the shoulder blows, the headbutt, the dropping blows.
// Legal's lines: every hand open or flat (no claw), no clasped fists, hands apart on two-hand blows, no leap, a single turn, kicks at the chest or below.
const OPEN = { hands: { r: 'open', l: 'open' } };

// Combat's rows: the redone slots keep the rival's row (range and ticks) with his look; the own strikes borrow the row of the nearest slot (an estimate until Combat's rows land)
const REDO = ['hook', 'overhand', 'haymaker', 'palm_heel', 'spear_hand', 'twin_spear', 'double_palm', 'cross_arm_ram', 'snap_round', 'roundhouse', 'spinning_heel', 'sweep'];
const OWN = {
  palm_push: { like: 'palm_heel', limb: 'hand', target: 'chest', weight: 'heavy', look: 'One open hand driven from the shoulder into the chest, the other hand open at his own chest.' },
  ridge_hand: { like: 'hook', limb: 'hand', target: 'head', weight: 'light', look: 'The edge of the open hand swung round in an arc to the head.' },
  rising_palm: { like: 'uppercut', limb: 'hand', target: 'jaw', weight: 'heavy', look: 'The heel of an open hand lifted under the jaw, the body rising behind it; no leap, the arm lowers at once.' },
  knife_chop: { like: 'hammer', limb: 'hand', target: 'arm', weight: 'light', look: 'A short downward chop with a flat hand, the elbow bent through the chop.' },
  hammer_fist: { like: 'hammer', limb: 'hand', target: 'head', weight: 'light', look: 'The bottom of one fist brought down: a return blow that sends down.' },
  crescent_kick: { like: 'roundhouse', limb: 'foot', target: 'chest', weight: 'heavy', look: 'A straight leg swept round from the inside out.' },
  hook_kick: { like: 'snap_round', limb: 'foot', target: 'chest', weight: 'light', look: 'The heel hooked back round from beyond the target.' },
  spinning_back_kick: { like: 'spinning_heel', limb: 'foot', target: 'gut', weight: 'heavy', look: 'One turn and a straight kick with the heel.' },
};
export function rows(wave1) {
  const by = Object.fromEntries(wave1.map(r => [r.id.replace('strike.', ''), r]));
  const out = REDO.map(n => ({ ...by[n], look: 'His version (open hands, rounder): ' + by[n].look }));
  for (const [n, o] of Object.entries(OWN)) {
    const b = by[o.like];
    out.push({ ...b, id: 'strike.' + n, limb: o.limb, target: o.target, weight: o.weight, look: o.look, _estimate: 'range and ticks borrowed from strike.' + o.like });
  }
  return out;
}
export const reuse = 'auto';   // every other wave 1 slot, with the profile applied

export const strikes = {
  // ---- the twelve whose silhouette changes
  hook: { kind: 'hand', legal: ['hands_open_or_claw'],
    contact: { family: 'upright_lunge', lean: 18, hips: [16, -4, 0], spine: { lean: 2, twist: 56, bend: -4 }, head: { pitch: 2, yaw: 6 }, hand_r: [56, 68, 20], pole_hand_r: [2, -2, 18], hand_l: [26, 64, -6],
      foot_r: [-4, 2.5, 9], foot_l: [22, 2.5, -7], ...OPEN },
    orig: 'a wide round swing of the open hand at head height, the arm one long curve, the other open hand up at his cheek and the body turning full behind it' },
  overhand: { kind: 'hand', legal: ['hands_open_or_claw'],
    contact: { family: 'upright_lunge', lean: 14, hips: [16, -4, 0], spine: { lean: -2, twist: 38 }, head: { pitch: -2, yaw: 0 }, hand_r: [50, 78, 10], pole_hand_r: [-4, 10, 8], hand_l: [21.5, 62, -8],
      foot_r: [-4, 2.5, 9], foot_l: [22, 2.5, -7], ...OPEN },
    orig: 'the open hand wheeled up and over in a big circle, the arm long, the body rising behind it, the head up and the eyes on the target' },
  haymaker: { kind: 'hand', legal: ['hands_open_or_claw'],
    contact: { family: 'upright_lunge', lean: 12, hips: [14, -4, 0], spine: { lean: 2, twist: 60, bend: -6 }, head: { pitch: 2, yaw: 4 }, hand_r: [48, 60, 26], pole_hand_r: [4, -2, 14], hand_l: [-8, 58, -14],
      foot_r: [-4, 2.5, 9], foot_l: [22, 2.5, -7], ...OPEN },
    orig: 'a wheeling open-handed swing from low behind to the side, the arm nearly straight, the free hand flung back the other way for the turn' },
  palm_heel: { kind: 'hand', legal: ['hands_open_or_claw', 'not_at_hip'],
    contact: { family: 'upright_lunge', lean: 14, hips: [14, -4, 0], spine: { lean: 4, twist: 20 }, head: { pitch: 0, yaw: 4 }, hand_r: [54, 64, 7], hand_l: [22, 60, -6],
      foot_r: [-4, 2.5, 9], foot_l: [22, 2.5, -7], ...OPEN },
    orig: 'a quick flat open palm pushed in at chest height with a step, the fingers together and up, the other hand open at his own chest' },
  spear_hand: { kind: 'hand', legal: ['hands_open_or_claw'],
    contact: { family: 'upright_lunge', lean: 14, hips: [16, -4, 0], spine: { lean: 6, twist: 22 }, head: { pitch: 4, yaw: 2 }, hand_r: [52, 48, 6], hand_l: [14, 58, -6],
      foot_r: [-4, 2.5, 9], foot_l: [24, 2.5, -7], ...OPEN },
    orig: 'a straight flat hand thrust low into the belly from a stand, the knees bent a little, the body upright and leaning in' },
  twin_spear: { kind: 'two_hand', legal: ['wrists_apart', 'hands_open_or_claw'],
    contact: { family: 'upright_lunge', lean: 18, hips: [18, -4, 0], spine: { lean: 4, twist: 0 }, head: { pitch: 4 }, hand_r: [54, 62, 8], hand_l: [48, 44, -8],
      foot_r: [-4, 2.5, 9], foot_l: [24, 2.5, -7], ...OPEN },
    orig: 'both open hands thrust together, one high and one low, a hand and a half apart: a staggered pair, never two parallel lines' },
  double_palm: { kind: 'two_hand', legal: ['wrists_apart', 'hands_open_or_claw', 'not_at_hip'], follow_t: 0.7,
    chamber: { lean: 4, hand_r: [12, 60, 16], pole_hand_r: [-8, 0, 18], hand_l: [12, 60, -16], pole_hand_l: [-8, 0, -18] },
    contact: { family: 'upright_lunge', lean: 16, hips: [16, -4, 0], spine: { lean: 4 }, head: { pitch: 2 }, hand_r: [54, 64, 10], pole_hand_r: [-2, 0, 8], hand_l: [54, 64, -10], pole_hand_l: [-2, 0, -8],
      foot_r: [-4, 2.5, 9], foot_l: [24, 2.5, -7], ...OPEN },
    orig: 'both flat palms shoved in at shoulder width with the elbows in and the fingers up, the body behind them: a blow, with nothing held out after it' },
  cross_arm_ram: { kind: 'two_hand', target: 'chest', legal: ['wrists_apart', 'no_cross_hold'],
    chamber: { lean: 6, hand_r: [14, 60, 12], hand_l: [14, 54, -12] },
    contact: { family: 'upright_lunge', lean: 24, hips: [10, -4, 0], spine: { lean: 8 }, head: { pitch: 10 }, hand_r: [36, 62, 12], pole_hand_r: [4, 2, 14], hand_l: [36, 54, -12], pole_hand_l: [4, -4, -14],
      foot_r: [-4, 2.5, 9], foot_l: [16, 2.5, -7], ...OPEN },
    orig: 'both forearms side by side like a bar, one a little higher, driven in behind the shoulder: a ram, never a wedge of crossed arms' },
  snap_round: { from: 'round', kind: 'foot',
    over: { contact: { family: 'upright_lunge', lean: -2, hips: [14, -3, 0], spine: { lean: -2, twist: 18 }, head: { pitch: -2, yaw: 4 }, hand_r: [14, 64, 14], hand_l: [24, 66, -8], foot_r: [42.7, 49.2, 7.9], foot_l: [12, 2.5, -7], ...OPEN } },
    orig: 'a quick round whip of the leg from the knee, the hands up and open at his face, the standing leg springing' },
  roundhouse: { from: 'round', kind: 'foot',
    over: { contact: { family: 'upright_lunge', lean: -16, hips: [18, -4, 0], spine: { lean: -6, twist: 36 }, head: { pitch: -2, yaw: 4 }, hand_r: [10, 66, 14], hand_l: [-4, 62, -10], foot_r: [44.8, 51.5, 7.9], foot_l: [13, 2.5, -7], ...OPEN } },
    orig: 'the full round swing of a straight leg through the ribs, the turn of the hips round and the hands kept up and open, not thrown back' },
  spinning_heel: { kind: 'foot', legal: ['single_turn'],
    contact: { family: 'upright_lunge', lean: -8, hip_twist: 66, hips: [8, -2, 0], spine: { lean: -4, twist: 56 }, head: { yaw: -38 }, hand_r: [-5, 60, 21], hand_l: [-10, 64, -20], foot_r: [38, 50, 8], foot_l: [6, 2.5, -7], ...OPEN },
    orig: 'one round turn with the arms opened wide to carry it, the heel coming round at the end of a long leg, the head turned to keep the eyes on him' },
  sweep: { kind: 'foot', target: 'shins', step_max: 18,
    contact: { family: 'crouched', lean: 30, hips: [4, -24, 0], spine: { lean: 18 }, head: { pitch: 10 }, hand_l: [30, 6, -12], hand_r: [8, 48, 14], foot_r: [36.5, 6, 10], foot_l: [-2, 3, -8], ...OPEN },
    orig: 'a wide low arc: down on one open hand, the other arm lifted for balance, the leg swept round flat along the ground' },

  // ---- the eight of his own
  palm_push: { kind: 'hand', legal: ['hands_open_or_claw', 'not_at_hip', 'no_cross_hold'],
    contact: { family: 'upright_lunge', lean: 18, hips: [16, -4, 0], spine: { lean: 4, twist: 28 }, head: { pitch: 2, yaw: 4 }, hand_r: [56, 64, 8], pole_hand_r: [-2, 0, 8], hand_l: [14, 58, -8],
      foot_r: [-4, 2.5, 9], foot_l: [24, 2.5, -7], ...OPEN },
    orig: 'one open hand driven from the shoulder into the chest, the other hand open at his own chest, the weight shifting through the palm' },
  ridge_hand: { kind: 'hand', legal: ['hands_open_or_claw'],
    contact: { family: 'upright_lunge', lean: 20, hips: [16, -4, 0], spine: { lean: 2, twist: 48, bend: -4 }, head: { pitch: 2, yaw: 4 }, hand_r: [55.5, 69.5, 21.5], pole_hand_r: [2, -2, 16], hand_l: [23, 59, -9],
      foot_r: [-4, 2.5, 9], foot_l: [24, 2.5, -7], ...OPEN },
    orig: 'the edge of the open hand swung round in an arc to the head, the elbow leading and then opening, the other hand at his chest' },
  rising_palm: { kind: 'hand', legal: ['hands_open_or_claw', 'no_leap', 'no_held_raise'],
    contact: { family: 'upright_lunge', lean: 8, hips: [12, -4, 0], spine: { lean: -6, twist: 16 }, head: { pitch: -10 }, hand_r: [44, 78, 8], pole_hand_r: [-2, 4, 8], hand_l: [18, 56, -8],
      foot_r: [-4, 2.5, 9], foot_l: [20, 2.5, -7], ...OPEN },
    orig: 'the heel of the open hand lifted under the jaw, the body rising behind it on straight legs with the feet staying down, the arm lowering at once' },
  knife_chop: { kind: 'hand', target: 'arm_r', legal: ['hands_open_or_claw'],   // (Combat's row says arm: the socket is arm_r, the shoulder side)
    contact: { family: 'upright_lunge', lean: 14, hips: [12, -4, 0], spine: { lean: 8, twist: 14 }, head: { pitch: 8 }, hand_r: [42, 62, 10], pole_hand_r: [-2, 12, 8], hand_l: [20.5, 55, -7.5],
      foot_r: [-4, 2.5, 9], foot_l: [22, 2.5, -7], ...OPEN },
    orig: 'a short downward chop with a flat hand to the shoulder, the elbow staying bent through it, the other hand open at his chest' },
  hammer_fist: { kind: 'hand', legal: ['no_clasp', 'no_held_raise'],
    contact: { family: 'upright_lunge', lean: 16, hips: [14, -4, 0], spine: { lean: 10, twist: 12 }, head: { pitch: 12 }, hand_r: [40, 70, 10], pole_hand_r: [-4, 14, 8], hand_l: [17, 58, -7.5],
      foot_r: [-4, 2.5, 9], foot_l: [22, 2.5, -7], hands: { r: 'fist', l: 'open' } },
    orig: 'one fist brought down on its heel in a short return blow, the other hand open at his chest; nothing held up after it' },
  crescent_kick: { kind: 'foot',
    contact: { family: 'upright_lunge', lean: -14, hips: [18, -4, 0], spine: { lean: -6, twist: 26 }, head: { pitch: -2, yaw: 4 }, hand_r: [8, 62, 16], hand_l: [14, 64, -10], foot_r: [44, 52.5, 13.5], foot_l: [12, 2.5, -7], ...OPEN },
    orig: 'a straight leg swept round from the inside out in a crescent at chest height, the hands up and open' },
  hook_kick: { kind: 'foot',
    contact: { family: 'upright_lunge', lean: -8, hips: [12, -4, 0], spine: { lean: -4, twist: -16 }, head: { pitch: -2, yaw: 6 }, hand_r: [10, 62, 14], hand_l: [18, 64, -8], foot_r: [38, 50, 4], foot_l: [12, 2.5, -7], ...OPEN },
    orig: 'the leg carried past the target and the heel hooked back round into the chest, the knee folding, the hands up and open' },
  spinning_back_kick: { kind: 'foot', legal: ['single_turn'],
    contact: { family: 'upright_lunge', lean: -12, hip_twist: 70, hips: [8, -2, 0], spine: { lean: -4, twist: 60 }, head: { yaw: -44 }, hand_r: [-11, 58, 17], hand_l: [13.5, 62, -17.5], foot_r: [42, 40, 8], foot_l: [6, 2.5, -7], ...OPEN },
    orig: 'one turn with his back shown and a straight kick with the heel into the belly, the arms open for the turn' },
};
