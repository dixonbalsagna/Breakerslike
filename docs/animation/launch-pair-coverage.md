# The launch pair: animation coverage (2026-10-03)

Owner: Animation. The EP's question: does the pair's animation cover everything the next big update will play, so that no move, shot kind or alchemy ending of the Protagonist or the rival falls back to a placeholder pose? Sources: Combat's pools and templates (`docs/combat/pending/recipes.alchemist.json`, `templates.agency.json`, `templates.brawl.json`, `energy.antihero.wave6.json`, `launch-pair.json`), Game Design (`docs/design/agency-pass.md` sections 1 to 3 and 13 to 18, `launch-pair-plan.md`, `spec-wounds.md`), Encounter's alchemy plan (`docs/director/alchemy-plan.md`, A1 to A7) and the sim's own events and cues (`docs/architecture/fx-events.md`, `SimFx.cue`).

The table is data: `docs/animation/launch-pair-coverage.json` (228 rows). `render/anim/tools/coverage.gd --strict` bakes every wave and looks each id up in the real loader; it fails on a missing id or a `gap` row. Today: **228 rows, no gap, every posed row finds all its poses** (live 26, parked 180, no body pose by design 13, later 4, blocked 5).

## What the statuses mean

- **live**: plays in a live match today (`poses.json`, agency 1, step 3, ground 1, intro 1, last stand 1).
- **parked**: posed, in a wave file that loads only with `--waves` (the tools) until its fighter lands and the event is wired: wave 1 and 2 (the rival), protag1 to 6, rival1 to 3, pair1, energy1. Nothing in the live game reads them yet, so **today these still fall back to the placeholder pose in a match: the coverage is of the data, and the wiring is a separate step** (below).
- **design**: no body pose by design (the computed reaction, the wound layers, VFX or Camera carry it).
- **later / blocked**: outside this update (grabs, clashes on the pulse, the kit, heat) or waiting on a ruling and an asset (the tail).

## What I found missing and filled (new parked waves)

The audit found holes in what Animation had posed. All are filled, in parked waves, and each is listed here with the row that needed it:

| Wave (prefix) | What | Why it was a hole |
| :--- | :--- | :--- |
| `rival3` (`rw`) | the free blast presses: the bolt, the fan of darts, the lob, the charged brace of wave 6 (charge and release), a shot down into a crater, the energy shove, the Regalia release; his four far taunts and his close taunt; the Drop the Act cinematic | the energy press (RB held) fires with no body pose: the sim cues `blast_windup`, `blast_charge`, `blast_full` and `buried_blast` had nothing to play; wave 6's charged brace and the shove were not posed (rival1 had the channel only); his four taunt pieces and the close taunt did not exist; Drop the Act is a 1.5 s cinematic in `spec-wounds.md` |
| `protag5` (`pg`) | the same blast presses with his hands (the palm bolt, the ring hand's fan, the lob, the charged shot released from the brace, a shot down into a crater), the spray with open hands, his own Blow for Blow brace, three far taunts and a close taunt | his hands are never claws and the shared spray's lead hand is one; Blow for Blow's brace was the rival's only (Legal rule 2: each takes the blow his own way); Combat names no gestures for him |
| `protag6` (`ph`) | his body hook (the ribs place of Blow for Blow) | the place had the rival's body hook only |
| `pair1` (`pp`) | the blow checked on the forearm and on the shin, the clash recoil | declared by Combat's brawl templates (`check.forearm`, `check.shin`, `clash.recoil`) and not posed |

Review stills: `art/animation/review/coverage/` (two sheets and two GIFs).

## Still open

- **The wiring.** Everything parked needs the runtime to pick a fighter's wave and to play a pose for the events that have none today. What it needs, in order: (1) a fighter-to-wave lookup (`data/anim/fighters.json` already lists each fighter's waves; its `more` key holds the extra waves) so a strike id resolves to `pr.*`, `ph.*`, `w1.*` or `rb.*` and an entry to `pe.*` or `w2.*`; (2) the energy events read by Animation: `shot_fire` and the cues `blast_windup`, `blast_charge`, `blast_full`, `blast_cancel`, `buried_blast`, `volley_fire` start the fighter's bolt, charged, fan or crater sequence by the shot's kind (the table below says which); the swat on `shot_deflect`, mine laying and the spray on their events; (3) a close-taunt event (the sim has none yet); (4) a loader that bakes a fighter's waves in a live match (`--waves` is tools-only today).
- **The tail** (four rival strikes): Orb's ruling and tail bones in the rig (R1 has none).
- **Combat's picks**: the Protagonist's taunt gestures (Animation's three are a proposal); the cartwheel step's 18 ticks; the estimated ranges and ticks of the new strikes.

## The table

Strikes are summarised: every piece of every pool in Combat's recipes has a key set (chamber, contact, follow) for each fighter, except the four tail strikes; the full list is in the JSON.

### strikes

- **rival**: 40 pieces in the pools, 36 with key sets (rb.*, w1.*); waiting: strike.tail_jab, strike.tail_sweep, strike.tail_whip, strike.tail_spike.
- **protagonist**: 42 pieces in the pools, 42 with key sets (pr.*).

### blur patterns

All six blur patterns can be filled from each fighter's lights (a light of every limb and target the pattern asks for exists): 12 rows, no gap.

### Blow for Blow places

| Move or event | Fighter | Plays | Status | Note |
| :--- | :--- | :--- | :--- | :--- |
| ribs (strike.body_hook) | rival | `rb.body_hook` | parked |  |
| ribs (strike.body_hook) | protagonist | `ph.body_hook` | parked |  |
| flank (strike.roundhouse) | rival | `w1.roundhouse` | parked |  |
| flank (strike.roundhouse) | protagonist | `pr.roundhouse` | parked |  |
| shoulder plate (strike.dropping_elbow, strike.hammer) | rival | `w1.dropping_elbow`, `w1.hammer` | parked |  |
| shoulder plate (strike.dropping_elbow, strike.hammer) | protagonist | `pr.dropping_elbow`, `pr.hammer` | parked |  |
| chest (strike.rib_shot, strike.double_palm) | rival | `rb.rib_shot`, `w1.double_palm` | parked |  |
| chest (strike.rib_shot, strike.double_palm) | protagonist | `pr.double_palm` | parked |  |
| hip (strike.rising_knee, strike.spinning_heel) | rival | `w1.rising_knee`, `w1.spinning_heel` | parked |  |
| hip (strike.rising_knee, strike.spinning_heel) | protagonist | `pr.rising_knee`, `pr.spinning_heel` | parked |  |
| thigh (strike.stomp) | rival | `w1.stomp` | parked |  |
| thigh (strike.stomp) | protagonist | `pr.stomp` | parked |  |

### entries

| Move or event | Fighter | Plays | Status | Note |
| :--- | :--- | :--- | :--- | :--- |
| entry.arc_dive | rival | `w2.arc_dive` | parked |  |
| entry.arc_dive | protagonist | `pe.arc_dive` | parked |  |
| entry.backstep_counter | rival | `w2.backstep_counter` | parked |  |
| entry.backstep_counter | protagonist | `pe.backstep_counter` | parked |  |
| entry.coil_spring | rival | `w2.coil_spring` | parked |  |
| entry.coil_spring | protagonist | `pe.coil_spring` | parked |  |
| entry.dash | rival | `w2.dash` | parked |  |
| entry.dash | protagonist | `pe.dash` | parked |  |
| entry.hop_back | rival | `w2.hop_back` | parked |  |
| entry.hop_back | protagonist | `pe.hop_back` | parked |  |
| entry.pivot | rival | `w2.pivot` | parked |  |
| entry.pivot | protagonist | `pe.pivot` | parked |  |
| entry.rising | rival | `w2.rising` | parked |  |
| entry.rising | protagonist | `pe.rising` | parked |  |
| entry.rooted | rival | `w2.rooted` | parked |  |
| entry.rooted | protagonist | `pe.rooted` | parked |  |
| entry.spiral | rival | `w2.spiral` | parked |  |
| entry.spiral | protagonist | `pe.spiral` | parked |  |
| entry.step_in | rival | `w2.step_in` | parked |  |
| entry.step_in | protagonist | `pe.step_in` | parked |  |
| entry.air_roll (his own) | protagonist | `pe.air_roll` | parked |  |
| entry.cartwheel_step (his own) | protagonist | `pe.cartwheel_step` | parked |  |

### agency

| Move or event | Fighter | Plays | Status | Note |
| :--- | :--- | :--- | :--- | :--- |
| far charge, light | rival | `ag.hold.charge_light` | live |  |
| far charge, heavy | rival | `ag.hold.charge_heavy` | live |  |
| feint stop | rival | `ag.hold.charge_peel` | live |  |
| knock-back slideShort, bump | rival | `ag.hold.kb_short` | live | the bump plays the short slide |
| knock-back slideLong | rival | `ag.hold.kb_long` | live |  |
| knock-back drift | rival | `ag.hold.kb_drift` | live |  |
| buried in a crater (embed, the buried rise) | rival | `ag.embed` | live |  |
| far taunt (the generic shrug, until his own gestures play) | rival | `ag.taunt` | live |  |
| far charge, light | protagonist | `ag.hold.charge_light` | live |  |
| far charge, heavy | protagonist | `ag.hold.charge_heavy` | live |  |
| feint stop | protagonist | `ag.hold.charge_peel` | live |  |
| knock-back slideShort, bump | protagonist | `ag.hold.kb_short` | live | the bump plays the short slide |
| knock-back slideLong | protagonist | `ag.hold.kb_long` | live |  |
| knock-back drift | protagonist | `ag.hold.kb_drift` | live |  |
| buried in a crater (embed, the buried rise) | protagonist | `ag.embed` | live |  |
| far taunt (the generic shrug, until his own gestures play) | protagonist | `ag.taunt` | live |  |

### taunts

| Move or event | Fighter | Plays | Status | Note |
| :--- | :--- | :--- | :--- | :--- |
| far taunt: head tilt | rival | `rw.taunt_head_tilt` | parked |  |
| far taunt: back turned | rival | `rw.taunt_back_turned` | parked |  |
| far taunt: dust the plate | rival | `rw.taunt_dust_plate` | parked |  |
| far taunt: stillness | rival | `rw.taunt_stillness` | parked |  |
| close taunt (1 s, he can be hit) | rival | `rw.taunt_close` | parked | the sim has no close-taunt event yet |
| far taunt: nod | protagonist | `pg.taunt_nod` | parked | Combat has not named his gestures: these three are Animation's proposal |
| far taunt: bounce | protagonist | `pg.taunt_bounce` | parked |  |
| far taunt: fist to palm | protagonist | `pg.taunt_fist_palm` | parked |  |
| close taunt (1 s, he can be hit) | protagonist | `pg.taunt_close` | parked | the sim has no close-taunt event yet |

### endings

| Move or event | Fighter | Plays | Status | Note |
| :--- | :--- | :--- | :--- | :--- |
| knock-back ender (a heavy that does not launch) | rival | `ag.hold.kb_short`, `ag.hold.kb_long`, `ag.hold.kb_drift` | live | the victim; the striker plays the ending heavy of his pool |
| earned launch (held heavy, string ender at flow 3, stick heavy, won clash) | rival | `launch.tuck`, `launch.stream` | live | the victim is the ragdoll; the flight lead (9.23) points him head first once the spin dies |
| showcase ender (flow 5, with the panel) | rival | - | design | the ender is the same heavy of the pool; the panel is the pause set piece (VFX, Camera) |
| level.shove_off (a light that sets the rival back) | rival | `w1.palm_heel`, `w1.shoulder_check` | parked | with the live cue reset (cue.reset) |
| level.hop_back | rival | `w2.hop_back` | parked |  |
| level.break_and_circle | rival | `cue.circle`, `cue.reset` | live |  |
| perfect blur: five lights at 6 ticks closing with a full set-up | rival | `w1.jab` | parked | the pool's lights; the set-up is the wear layers |
| knock-back ender (a heavy that does not launch) | protagonist | `ag.hold.kb_short`, `ag.hold.kb_long`, `ag.hold.kb_drift` | live | the victim; the striker plays the ending heavy of his pool |
| earned launch (held heavy, string ender at flow 3, stick heavy, won clash) | protagonist | `launch.tuck`, `launch.stream` | live | the victim is the ragdoll; the flight lead (9.23) points him head first once the spin dies |
| showcase ender (flow 5, with the panel) | protagonist | - | design | the ender is the same heavy of the pool; the panel is the pause set piece (VFX, Camera) |
| level.shove_off (a light that sets the rival back) | protagonist | `pr.palm_heel`, `pr.shoulder_check` | parked | with the live cue reset (cue.reset) |
| level.hop_back | protagonist | `pe.hop_back` | parked |  |
| level.break_and_circle | protagonist | `cue.circle`, `cue.reset` | live |  |
| perfect blur: five lights at 6 ticks closing with a full set-up | protagonist | `pr.jab` | parked | the pool's lights; the set-up is the wear layers |

### energy

| Move or event | Fighter | Plays | Status | Note |
| :--- | :--- | :--- | :--- | :--- |
| bolt (energy press, light): the wind-up and the shot | rival | `rw.bolt` | parked | the sim's cue blast_windup |
| bolt (energy press, light): the wind-up and the shot | protagonist | `pg.bolt` | parked | the sim's cue blast_windup |
| volley: a fan of darts or arcs from one sweep of the arm | rival | `rw.volley_fan` | parked |  |
| volley: a fan of darts or arcs from one sweep of the arm | protagonist | `pg.volley_arc` | parked |  |
| shard (the rival's kind): the pinch and the kiting turn | rival | `rv.hold.hand_pinch`, `rv.hold.kiting_turn` | parked |  |
| shard | protagonist | - | design | not his kind |
| arc (a crescent thrown off a limb already swinging) | rival | `rv.hold.hand_blade_hand`, `rv.hold.hand_fist_glow` | parked | thrown off the strikes that emit (backfist, uppercut, hammer, roundhouse, axe kick); the strike poses carry the swing |
| arc | protagonist | `pg.volley_arc` | parked | the ring hand's sweep; also off his round kicks |
| burst and the energy shove (the context button at close range) | rival | `rw.hold.energy_shove` | parked |  |
| burst and the energy shove | protagonist | `pn.hold.palm_thrust` | parked |  |
| lob (a slab thrown with one hand) | rival | `rw.lob` | parked |  |
| lob | protagonist | `pg.lob` | parked |  |
| charged shot: the charge (blast_charge), the flash (blast_full) and the release | rival | `rw.charged_brace`, `rv.hold.channel_charge`, `rv.hold.channel_release` | parked | the charged brace is the single-arm charge, the channel the two-arm one |
| charged shot: the charge (blast_charge), the flash (blast_full) and the release | protagonist | `pn.hold.brace_load`, `pn.hold.brace_hold`, `pg.charged` | parked |  |
| rain: the upward throw | rival | `rv.hold.rain_throw` | parked |  |
| rain | protagonist | - | design | not his kind |
| splitting shot: leaves from the charged brace | rival | `rw.charged_brace` | parked |  |
| splitting shot | protagonist | - | design | not his kind |
| curving shot: released from a still flat palm | protagonist | `pn.curve`, `pn.hold.curve_release` | parked |  |
| curving shot | rival | - | design | not his kind |
| ricochet shot | protagonist | - | later | Game Design: later, Legal GO; the palm thrust would carry it |
| the six emitting hands (open palm, pinch, clawed palm, fist glow, blade hand, crossed forearms) | rival | `rv.hold.hand_open_palm`, `rv.hold.hand_pinch`, `rv.hold.hand_clawed_palm`, `rv.hold.hand_fist_glow`, `rv.hold.hand_blade_hand`, `rv.hold.hand_crossed_forearms` | parked |  |
| his two hands: the open palm thrust and the ring hand | protagonist | `pn.hold.palm_thrust`, `pn.hold.ring_hand` | parked |  |
| crown release (the Regalia shards leave on their own) | rival | `rw.hold.crown_release` | parked |  |
| spray: rapid bolts in a cone | rival | `en.spray` | parked |  |
| laying a mine | rival | `en.mine` | parked |  |
| a wild deflect (the swat) and a perfect block's deflect | rival | `en.swat`, `s3.perfect_block.deflect` | parked |  |
| a shot fired down into a crater (buried_blast) | rival | `rw.hold.blast_down` | parked |  |
| a mine set off, a shot meeting him: the hit | rival | - | design | the computed reaction and the knock-back poses; the blast is VFX |
| barrage ender (the fourth landed bolt is a knock-back) | rival | `rw.bolt` | parked | the shooter fires as for any bolt; the victim plays the knock-back |
| blast cancelled (blast_cancel) | rival | - | design | the layer ends and the base pose eases back (no pose of its own) |
| spray: rapid bolts in a cone | protagonist | `pg.spray` | parked | his lead hand is open (the shared spray's is a claw) |
| laying a mine | protagonist | `en.mine` | parked |  |
| a wild deflect (the swat) and a perfect block's deflect | protagonist | `en.swat`, `s3.perfect_block.deflect` | parked |  |
| a shot fired down into a crater (buried_blast) | protagonist | `pg.hold.blast_down` | parked |  |
| a mine set off, a shot meeting him: the hit | protagonist | - | design | the computed reaction and the knock-back poses; the blast is VFX |
| barrage ender (the fourth landed bolt is a knock-back) | protagonist | `pg.bolt` | parked | the shooter fires as for any bolt; the victim plays the knock-back |
| blast cancelled (blast_cancel) | protagonist | - | design | the layer ends and the base pose eases back (no pose of its own) |

### set pieces

| Move or event | Fighter | Plays | Status | Note |
| :--- | :--- | :--- | :--- | :--- |
| On the Chin: plant, lift, done | rival | `rv.on_the_chin` | parked |  |
| On the Chin: a signature absorbed (beam in, beam out, bravado) | rival | `rv.chin_beam` | parked |  |
| Blow for Blow: the brace | rival | `rv.hold.bfb_brace` | parked |  |
| Blow for Blow: the brace | protagonist | `pg.hold.bfb_brace` | parked | his own brace (Legal rule 2) |
| Blow for Blow: the body hook and the rib shot | rival | `rb.body_hook`, `rb.rib_shot` | parked |  |
| Blow for Blow: the body hook (the ribs) | protagonist | `ph.body_hook` | parked | his own, with the open hand (the rival's is rb.body_hook) |
| finisher: the walk in, the stop, the held pose | rival | `rv.hold.fin_walk`, `rv.hold.fin_stop`, `rv.hold.fin_held` | parked |  |
| finisher: the barrage of volleys before it | rival | `rw.charged_brace`, `rw.volley_fan`, `rv.hold.kiting_turn` | parked |  |
| finisher (flight version): arrival, gather, blast, after | protagonist | `pf.finisher` | parked | the flurry's strikes are his own (pr.*) |
| Drop the Act (the 1.5 s cinematic) | rival | `rw.drop_the_act` | parked | spec-wounds.md section 3; names are placeholders |
| forms: the transformation beats at each tier (Regalia, Sovereign, Apex; the Protagonist's three) | rival | `form.gather`, `form.break`, `form.settle` | live | shared beats; each tier's idle is data/anim/personality.json tiers |
| last stand, KO, victory, get-up, ground contact, entrance and staredown | rival | `ls1`, `win`, `gc`, `in` | live | shared sets, in his own shape P or A |
| a Rally (Second Wind, Spite) and the brink | rival | - | design | the wound layers ease the brink's sag; no body beat of its own |
| trades: a blow checked on the forearm or the shin, the clash recoil | rival | `pp.hold.check_forearm`, `pp.hold.check_shin`, `pp.hold.clash_recoil` | parked | A6 (both attack) is outside the first cut |
| forms: the transformation beats at each tier (Regalia, Sovereign, Apex; the Protagonist's three) | protagonist | `form.gather`, `form.break`, `form.settle` | live | shared beats; each tier's idle is data/anim/personality.json tiers |
| last stand, KO, victory, get-up, ground contact, entrance and staredown | protagonist | `ls1`, `win`, `gc`, `in` | live | shared sets, in his own shape P or A |
| a Rally (Second Wind, Spite) and the brink | protagonist | - | design | the wound layers ease the brink's sag; no body beat of its own |
| trades: a blow checked on the forearm or the shin, the clash recoil | protagonist | `pp.hold.check_forearm`, `pp.hold.check_shin`, `pp.hold.clash_recoil` | parked | A6 (both attack) is outside the first cut |
| Humbled's burst (the next decisive exchange) | rival | - | design | the exchange's own blows |

### later

| Move or event | Fighter | Plays | Status | Note |
| :--- | :--- | :--- | :--- | :--- |
| the four tail strikes and the tail pieces | rival | - | blocked | Orb's ruling on the tail, and tail bones in the rig (R1 has none) |
| grabs and throws (wave 4), the grip and drag special | rival | - | later | when the held state is in (Combat's order) |
| beam clashes and answers (wave 5), the ping-pong (wave 3), the first kit (wave 7) | rival | - | later | when the pulse and curved flight are in |
| the Protagonist's heat beats and Open Hand | protagonist | - | later | with the forms system |

