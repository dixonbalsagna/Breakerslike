// The agency slice's events as held poses and short sequences (docs/director/agency-slice-3.md, docs/combat/alchemist-recipes.md section 3,
// docs/legal/agency-pass-screen.md section 2), played by AnimFighter.on_agency over the active ragdoll. The events: knockback (kind slideShort, slideLong, drift),
// embed (World: driven into the ground, held down 60 ticks), the cues taunt_start (a far taunt, 45 ticks, while he keeps flying), charge_light, charge_heavy
// and charge_feint. Held poses are mixed for as long as the event says; sequences are played by the entry layer. data/anim/agency.json names which event
// plays which, how strongly and for how long. Legal: the charges follow the dash rule (not both arms trailed straight back, not one fist punched ahead, drawn
// the whole way); a taunt never beckons; no crossed arms, no scream, no aura. Originality: no franchise pose; each pose has an _orig line.
const OPEN = { hands: { r: 'open', l: 'open' } };

export const sequences = {
  // the far taunt: a shrug with the palms turned up and the chin cocked, the body still flying underneath (the data mixes it over the flight at 70%)
  taunt: { dur: 45, legal: ['not_both_arms_back', 'no_fist_punched_ahead'], phases: [
    { id: 'lift', ticks: 10, sketch: { family: 'upright', lean: 4, spine: { lean: -2, twist: 8 }, head: { pitch: -8, yaw: 14, roll: 12 }, hand_r: [8, 38, 26], hand_l: [8, 38, -24],
        foot_r: [-4, 2.5, 8], foot_l: [4, 2.5, -7], ...OPEN },
      orig: 'the shoulders rising, the head cocked to one side, the open hands turning out at his sides' },
    { id: 'shrug', ticks: 22, sketch: { family: 'upright', lean: 0, hips: [0, 0, 0], spine: { lean: -4, twist: 12 }, head: { pitch: -12, yaw: 22, roll: 20 }, hand_r: [16, 46, 34], hand_l: [14, 46, -32],
        foot_r: [-4, 2.5, 8], foot_l: [4, 2.5, -7], ...OPEN },
      orig: 'the shrug held: the shoulders up, the palms open and turned up away from the body, the chin lifted: "is that all"' },
    { id: 'settle', ticks: 13, from: 'stance.aggressive', over: { lean: 6, head: { pitch: -4, yaw: 8 }, ...OPEN },
      orig: 'dropping back to the stance, the head still a little cocked' },
  ] },
  // the embed: driven into the crater and held; a hand stirs, then the hands go to the floor (the get-up pose of the ground contact takes over)
  embed: { dur: 60, phases: [
    { id: 'lie', w: 4, sketch: { family: 'prone', lean: -84, hips: [-2, -30, 0], spine: { lean: -4 }, head: { pitch: 18, roll: -10 }, hand_r: [-24, 6, 18], hand_l: [-16, 8, -14],
        foot_r: [30, 5, 7], foot_l: [34, 4, -6], hands: { r: 'open', l: 'relaxed' } },
      orig: 'driven into the floor of the crater on his back: the limbs slack, the head rolled to one side, the hands open' },
    { id: 'stir', w: 2, sketch: { family: 'prone', lean: -78, hips: [-2, -30, 0], spine: { lean: 4 }, head: { pitch: 10, roll: -4 }, hand_r: [-6, 14, 18], hand_l: [-16, 8, -14],
        foot_r: [28, 6, 7], foot_l: [32, 5, -6], hands: { r: 'open', l: 'relaxed' } },
      orig: 'coming to: one hand bringing itself up from the floor, the head lifting' },
    { id: 'brace', w: 1, from: 'down.getup', over: { lean: 40, hips: [-2, -22, 0], head: { pitch: 16 }, ...OPEN },
      orig: 'the hands to the floor and a knee drawn up: the push that the get-up takes over from' },
  ] },
};

export const holds = {
  // the light charge's flight (Combat: a light opener, he drops a shoulder toward the rival; derives from the dash): one narrow line, the lead shoulder and its forearm guard
  // ahead, the other arm folded to the chest
  charge_light: { sketch: { family: 'airborne_extended', lean: 62, spine: { lean: -8, twist: 18 }, head: { pitch: -18 }, hand_r: [18, 58, 14], pole_hand_r: [10, 2, 10], hand_l: [2, 46, -6],
      foot_r: [-30, 26, 3], foot_l: [-30, 24, -3], ...OPEN },
    orig: 'the light charge: one narrow blade, the lead shoulder and its forearm guard ahead, the other arm folded to the chest, the legs together behind' },
  // the heavy charge's flight (charge.heavy_lead): both forearm plates side by side ahead of him, never crossed, the head tucked behind them, the body one low line
  charge_heavy: { sketch: { family: 'airborne_extended', lean: 72, spine: { lean: 6 }, head: { pitch: 30 }, hand_r: [26, 54, 6], pole_hand_r: [10, 10, 8], hand_l: [26, 54, -6], pole_hand_l: [10, 10, -8],
      foot_r: [-28, 26, 3], foot_l: [-30, 24, -3], hands: { r: 'relaxed', l: 'relaxed' } },
    orig: 'the heavy charge: both forearms side by side ahead of him, parallel and never crossed, the head tucked behind them, the body one low line' },
  // the stop of a feint (charge.peel): side-on to the line, braking, the leading arm swung wide, one knee up
  charge_peel: { sketch: { family: 'airborne_neutral', lean: -14, hip_twist: 40, spine: { lean: -4, twist: -30 }, head: { pitch: -6, yaw: -20 }, hand_r: [14, 54, 34], hand_l: [4, 44, -10],
      foot_r: [14, 34, 8], foot_l: [-8, 12, -6], ...OPEN },
    orig: 'a feint peeling off: side-on to the line and braking, the leading arm swung wide, one knee drawn up' },
  // knocked back on his feet, a short slide: the heels skidding, the chest back, the arms out for balance
  kb_short: { sketch: { family: 'upright', lean: -14, hips: [-4, -4, 0], spine: { lean: -8 }, head: { pitch: -6 }, hand_r: [10, 46, 16], hand_l: [4, 42, -14],
      foot_r: [6, 2.5, 9], foot_l: [-14, 2.5, -7], ...OPEN },
    orig: 'driven back on his heels: the chest back, the arms out for balance, the feet skidding' },
  // a long slide: lower, further back, the feet wide, one arm thrown out
  kb_long: { sketch: { family: 'crouched', lean: -22, hips: [-6, -12, 0], spine: { lean: -10 }, head: { pitch: -10 }, hand_r: [-2, 50, 22], hand_l: [-6, 46, -18],
      foot_r: [16, 2.5, 10], foot_l: [-12, 2.5, -8], ...OPEN },
    orig: 'a long slide: sat back low on the heels, the feet wide, the arms flung out' },
  // a drift: pushed back off the ground, floating, nothing to push against
  kb_drift: { sketch: { family: 'airborne_neutral', lean: -10, hips: [-2, 2, 0], spine: { lean: -6 }, head: { pitch: -4 }, hand_r: [4, 42, 16], hand_l: [0, 40, -14],
      foot_r: [-6, 14, 6], foot_l: [-10, 10, -6], ...OPEN },
    orig: 'pushed back off his feet: floating, the arms loose, the legs trailing a little' },
};

export const cues = {};
