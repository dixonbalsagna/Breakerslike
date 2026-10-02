# Energy blasts on screen

Owner: VFX Director. 2026-10-03. Encounter's slice 5 fires shots (`S.shots`, Simulation's `docs/architecture/shots.md`) and nothing in render drew them. This draws them. Presentation only: it reads `S.shots`, the four shot events, the cues and the fighters, and writes nothing, no `S.rng`; the gameplay hash is unchanged (`hash_check.gd`). Code: `render/vfx/shots.gd` (`VfxShots`, `hub.shots`: the state behind the events) and `render/vfx/shots_view.gd` (`VfxShotsView`: the drawing). Flag: `VfxHub.shots_enabled`, default **on** (`VfxLook.SHOTS_DEFAULT`). Numbers: `DEFAULTS` in `shots.gd` (an optional `data/vfx/shots.json` can override them; none yet, so no schema is owed).

## What is drawn

| Thing | How |
| :--- | :--- |
| **Every live shot, each frame, from `S.shots`** | Interpolated: the state is the end of the last tick, so a frame between ticks is drawn a fraction of a tick back along the shot's velocity (none for a shot fired this tick, and none through a hit-stop or a pause, when shots stand still). In its owner's lane colour (`VfxAura.lane_color`: never white, gold or red), so a deflected shot, which the sim hands to the other fighter, changes colour as it turns back |
| **A bolt** | A small cel disc (a darker rim, the lane colour, a lighter core) with a short tapering tail |
| **A charged shot** | Bigger by its power and by its charge (a tap, 44 damage, is smaller than a full 66), with a longer tail and a thin halo ring |
| **A seeking shot** | On a slight arc, zero at both ends (a tenth of a fighter height, more for a longer flight): it leaves and arrives on its true line. Game Design's "may be drawn on a slight arc" |
| **The charge on the hand** (`blast_charge` to `blast_full`) | Each fighter's own look at the forearm of the arm toward the rival, in the lane colour: **plates stacking along the forearm for the Anti-hero** (a villain), **thin rings stacking along it for the others**; one more each fifth of the charge; a pulse ring along the forearm at `blast_full`; gone when the shot leaves, or on `blast_cancel` or `charge_stopped`. Never a sphere growing in a palm, hands at a hip or a two-hand push (Legal), checked: no disc among its quads |
| **A hit** (`shot_hit`) | By outcome: `hit` a flash and a ring; `guard` a splash fanning back toward the shooter; `deflect` a bigger ring in the deflector's colour, and the shot itself is seen turning back; `shrug` and `stop` a smaller flash; `dodge` nothing at him (the shot flies on) |
| **A trade** (`shot_clash`) | A ring in each fighter's colour and a burst of eight short lines |
| **A miss** (`shot_end`) | On the ground: dust and a few chunks off the point (World's crater comes by its own `crater` event, and gets the blast amplification as before); on the water: the water plunge; at the end of its life: a small fading ring |

## Legal

The first energy slice's rule for the charge look (`docs/legal/agency-pass-screen.md` section 3) is kept as above. No white, gold or red (the core is the lane colour lightened a little and checked to stay coloured); no sky change; no lightning or flame. The stacking rule: a shot is not one of the seven marks; the charge on the hand is a thin ring or plate stack, not the crouch, scream or flame aura; the ground puff at a miss is mark 4's one-off (rubble and ground), never a held state.

## Budget

At most 32 live shots (the sim's cap), 4 quads a bolt and 5 a charged shot, so 160 at most, plus up to 14 for the hit and trade effects and 16 for the two charges: **one MultiMesh, one draw call, 224 quads reserved** (the transformation's shader). In the debris pool only for a miss on the ground (no draw call). Not measured: the web build and an old laptop (the hash check's matches fire 60 shots and draw 3 at once at most).

## Where it hangs

The view is a child of `VfxTrailView` (`trail_view.gd`), which the layer already updates every frame, and updated at the start of its `update`; `VfxLayer` is untouched. If you would rather it were the layer's own child, that is a two-line move.

## Checks

`effects_check.gd` `_shots()` (34 cases): a shot in `S.shots` is drawn and none once it is gone; 32 shots in one draw; the interpolation (60, 30 and 0 units back), a shot fired this tick and a hit-stop held in place; the arc's ends; size by kind, power and charge; each shot in its owner's colour, never white, gold or red; each outcome's effect; a trade drawn and gone after its life; a miss on the ground throws dust; the charge starts, builds to full in 30 ticks, pulses, ends when the shot leaves, on cancel and on stop; the Anti-hero's plates and the others' rings; no sphere; flag off; data fallback. `hash_check.gd`: 60 shots fired and up to 3 drawn at once over its matches, hash unchanged. `determinism.gd` passes.

## Pictures

Real sim shots fired by `SimShots.fire` on the desert (the web build in the browser pane, 800x600):

| Volley (three bolts, one trading with VORR's) | A charged shot in flight, the muzzle ring at KAI |
| :---: | :---: |
| ![](img/shots-volley.jpg) | ![](img/shots-charged.jpg) |

| The charge on the hand: KAI's rings, VORR's plates | A deflect: the shot turns back in VORR's colour, ring at his hand |
| :---: | :---: |
| ![](img/shots-charge-on-hand.jpg) | ![](img/shots-deflect.jpg) |

| A trade: shots fired | A trade: VORR's charged shot meets KAI's bolts |
| :---: | :---: |
| ![](img/shots-trade-fired.jpg) | ![](img/shots-trade.jpg) |

Open: the ground burst and the guard splash have no picture; the pressure rings' drawing still waits for Orb.
