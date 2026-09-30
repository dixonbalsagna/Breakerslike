# Shake pass: per-event values and the split's per-pane shake

Owner: Controls and Game Feel (the per-impact numbers). Camera owns the global cap, decay, the user scale and the panes. Date: 2026-09-29. Audience: Camera, VFX, Rendering. Companion to the hit-stop table in `rulings.md` §5.

## 1. What is in place (checked)

| Fact | Where |
| :--- | :--- |
| The sim already emits `shake {k, x}` with the world `x` of the cause. **Camera's "wanted: world x" is done** | `sim/core/fx.gd:79-80`, field list `sim/core/hash.gd:222` |
| The consumer keeps `shake = max(shake, k)` and decays it once per tick by `0.02^dt` (0.937 per tick, half-life 10.6 ticks = 0.18 s) | `sim/core/view/fx.gd:227-228, 245` |
| Decay also runs on **frozen** ticks (hit-stop), so an 8-tick freeze already loses about 40% of the amplitude before the world moves again | `fx.gd:245` runs after the `tick {frozen}` event |
| Pane jitter is `(rand − 0.5) × shake_px` per axis, capped at 3.0% of the screen height and scaled by the player's shake scale (a quarter in reduced motion) | `render/camera/pane_shake.gd:19-23`, `split-screen.md` §12 |
| The split shakes the nearer pane fully and the other pane at 35% | `split-screen.md` §12 |
| Every k below is on the prototype's 0 to 30 scale, where **30 = the cap**. Camera maps k to pixels through its own cap; I give k, not pixels | |

For orientation at 720p, with Camera's cap (21 px at k = 30, 0.7 px per unit): k 4 = 2.8 px, 8 = 5.6, 12 = 8.4, 16 = 11.2, 22 = 15.4, 30 = 21.

## 2. Per-event table

Ordered by weight. "Proto" is the value the sim writes today. "Proposed" is to fit Camera's cap. The hierarchy follows the hit-stop table: the shake should never be louder than the freeze that goes with it, except on the finisher.

| Event | Sim source | Proto k | **Proposed k** | Hit-stop (ticks) | Near pane | Far pane (35%) | Notes |
| :--- | :--- | ---: | ---: | ---: | :--- | ---: | :--- |
| Light strike | `damage.gd:64` | 6 | **4** | 4 | both fighters' panes | 1.4 | Many per exchange; 6 kept the camera from ever settling |
| Chain link | `exchange.gd:126` | 6 | **6, then +1 per link, cap 9** | 5 | both | 2.1 to 3.2 | Escalates with the +12% per link |
| TRADE BLOWS last blow | `melee.gd:101,105` | 6 | **8** | 6 | both | 2.8 | |
| Heavy strike | `melee.gd:114,119` | 12 | **10** | 7 | both | 3.5 | |
| Parry | `melee.gd:214` | 9 | **8** | 9 (clean 12) | both | 2.8 | The reward cue; the freeze is bigger than the shake |
| GUARD BREAK | `melee.gd:86,178` | 12 | **12** | 8 | both | 4.2 | |
| Structure collapse (h > 200) | `structures.gd:53` | 10 | **10** | 0 | nearer pane | 3.5 | Fall off with distance (below) |
| Launch | `launch.gd:207` | 10 | **8** | 0 | target's pane | 2.8 | Frequent; not a hit |
| Tier-up | `fighter.gd:18` | 14 | **12** | 0 | the fighter's pane | 4.2 | Local and self-inflicted |
| Beam fire | `beam.gd:169` | 14 | **10** | 0 | source's pane | 3.5 | The connect is the peak, not the shot |
| Explosion | `structures.gd:86` | 16 | **14** | 5 | nearer pane | 4.9 | Clusters: max-stack keeps it from summing |
| HEAVY CLASH shockwave | `melee.gd:199` | 18 | **16** | 7 | both | 5.6 | |
| Beam connect | `beam.gd:88` | 16 | **16** | 9 | both | 5.6 | |
| Beam clash resolution | `beam.gd:156` | 18 | **18** | 10 | both | 6.3 | |
| Launch impact (ground) | `fighter.gd:56` | min(30, v×0.01) | **unchanged** | 4 | landing pane | 35% | Proportional to speed already |
| **Finisher final blow** | finisher `finalBlow` | 14 | **22** | **18** | both | 7.7 | The peak of the game; give it the biggest freeze and shake |
| Clash held (beam struggle) | `sim.gd:99` | 7 per tick | **4 per tick** | 0 | source's pane | 1.4 | Sustained: 3.4 s of 7 tires the eye |

Five values are unchanged on purpose (GUARD BREAK 12, beam connect 16, resolution 18, structure collapse 10, ground impact): they were already in proportion once the light and chain values came down.

## 3. Per-pane rule

1. The sim emits one `shake {k, x}` per cause. Camera keeps its own pane weights.
2. For each pane, **near** means the pane's view contains `x` (wrapped distance). Near = 100% of k, far = 35% (Camera's value).
3. **A hit between the two fighters is near for both panes** (the fighters are within a few hundred units), so both shake fully. Beam fire, launches and impacts can be near for one pane only, which is the point of the split.
4. Each pane has its own stream (`camera`, `camera_b`), so identical events shake the two panes differently but reproducibly.
5. **Distance falloff (single view too):** an event at wrapped distance d from the view centre is scaled by `clamp(1 − d / 4000, 0.35, 1)`. A collapse across the planet does not shake a close-up. The 4000 is a starting value for Camera to fit.
6. **Cap after weighting, then scale:** `amp = min(k × w, 30) / 30 × 3.0% × screen_height × shake_scale`. Reduced motion is `shake_scale × 0.25` (Camera's rule).

## 4. Two proposals for Camera (not required)

- **Hold the shake through the freeze.** The consumer decays every tick, including frozen ones, so the peak is spent before the world resumes. Pausing the decay while `frozen` (`if not frozen:` around the `shake *= …` line) keeps the punch visible. It is cosmetic, but it changes `V.shake`, which is in the goldens (`hash.gd:77`), so QA regenerates them with the same commit.
- **Tier scaling** ("power has weight", pillar 4): `k' = min(30, k × (1 + 0.06 × (tier − 1)))` for hit, impact, explosion and beam events, so tier 4 is ×1.18. Game Design decides whether tier scaling belongs in shake at all.

## 5. What I ask of others

- **Camera:** confirm the falloff constant, the near test and the far weight; confirm k maps through your cap as in §1. You own the cap and decay; I own the per-event k.
- **Rendering / Camera:** hold the shake through freezes (§4) if you agree.
- **VFX:** the finisher struggle is a state-resolved beat with no press; no extra camera motion is added for it.
- **Accessibility:** shake scale and reduced motion are yours. Note that hit-stop is a sim value and **cannot** be scaled by the player without changing the simulation; I propose a match-header `hitstopScale` (0.5 or 1.0) recorded in replays if Accessibility wants a "reduce freezes" option. Netcode would have to agree it for online matches. **Orb decides** whether that option exists.
