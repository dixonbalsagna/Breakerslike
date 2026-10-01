# Fight lanes: Rendering's section (ADR 0009)

Owner: Rendering and Technical Art. Status: plan only, 2026-10-01. Nothing here is built. It answers Simulation's four asks in `docs/architecture/fight-lanes.md` section 8, and the EP's question on closer framing. Everything in it is render only: it reads the sim and writes nothing.

## Summary

1. **Occlusion:** I recommend a cut-away for the fight and the porthole for flights. The porthole alone is not enough once fights happen in the back street: the whole street is behind block row 1, and a round hole shows a fighter but not the beam, the opponent or the ground between them. Orb's pick decides; the three methods and their costs are in section 2. No new sim state is needed for any of them.
2. **Terrain strips:** 8 rows are affordable for the renderer, and so would 16 be. The ground mesh is already a grid in depth, displaced on the GPU from a data texture, so rows cost texture size and upload, not geometry. The phone is unmeasured; I give the measurement I would run before T1.
3. **One real problem with the slice order:** between L4 (fighters at depth) and T2 (craters local in depth), either craters in the band are drawn as trenches across it ("canyons", which Orb rejected) or fighters at depth float over ground that is drawn without the dent. This bears on Simulation's question 3 to the EP.
4. **Depth aids:** the ground shadow is built. I add a lane cue drawn by the ground shader (no draw call) and painted streets from the lane table. Both read only `groundY(S, x, z)` and the fighters' positions.
5. **Closer framing:** the fighter is the cheap part. The world is the expensive part: at twice today's size the buildings are blank slabs and the ground's 32-unit columns show as facets. A cosmetic close-up needs a fighter level of detail that does not exist yet.

## 1. What B3 already covers, and what it does not

Built and live (63ba157, with Camera's 33e565e and VFX's d904497):

- The fighter is drawn at the sim's `z`, interpolated like the pose, in every pane. Perspective scale, the planet's bend at depth and depth sorting against buildings follow from his position.
- The outline thins with depth, down to 0.75 px.
- A ground shadow under each fighter at his depth, on the ground or the water as drawn.
- The porthole: up to two per pane, dithered, cutting whatever of a building is nearer the camera than the fighter.
- Floor tunnels from `fmask`, and footings from `WorldStructures.baseY`.
- Camera follows `z` (zoom compensation and lead), the HUD anchors take `z`, and the motion trail follows him.

Not covered, because B3 assumed depth lasts a second or two inside a solo shot:

- **Things attached to a fighter that still sit on the plane:** head flashes, auras and glows, pose cues, and every VFX emitter placed from an event's `x` and `y`. After L0 every event carries `z`; `particle_view.gd` and VFX's hub must place by it. Beams are VFX's and need `oz` and `zs` (L5).
- **The ground under a fighter at depth.** Today the drawn ground equals the sim's only on the plane row. Section 3.
- **Occluders other than buildings:** trees, rubble heaps, formations, props and terrain ridges have no porthole.
- **Two fighters in depth at once, for minutes.** The porthole was tuned for one brief flight.
- **The crowd's startle and flight** measure distance along x only. They become plan distance.

## 2. Occlusion

From the side camera a fighter in the back street is behind all of block row 1, whose towers are up to 57 fighter heights tall. Research measured a fighter hidden 35% of the time. Three methods:

| Method | What Orb sees | Cost and state | Weakness |
| :--- | :--- | :--- | :--- |
| **Porthole** (built) | A dithered round window around each hidden fighter. Buildings stay whole. | Nothing measurable. Two `vec4` uniforms a pane. Reads the fighters' positions. | Shows the fighter, not the fight: a beam along the back street, the opponent's approach and the ground are hidden outside the two holes. Noisy when both fighters are behind towers for a long time. |
| **Cut-away** | The buildings in front of the fight are cut down to a low stub, eased in over about 0.2 s. The stub keeps the footprint visible. | One small texture a pane (a cut height a building; I already have this for row 0's fade). A few footprint tests a frame through the sim's bucket index. Reads positions, footprints, and for a launch or beam its waypoint, so the cut opens along the path before the body arrives. | The skyline changes when the fight moves behind a row. Research: "buildings pop out of sight, and with them the reason for the collision". The stub and the ease are my answer to that. |
| **Silhouette** | Buildings stay whole; a hidden fighter shows through them as a flat tinted shape with his outline. | One more draw call a fighter a pane (an inverted depth test). Reads nothing new. Needs a one-day spike: I have not confirmed the inverted depth test on the Compatibility renderer in WebGL2. | The pose reads, but nothing else does: no cosmetics, no VFX, no ground, no opponent's context. An exchange fought behind a row would be two flat shapes for its whole length. |

**Recommendation: cut-away for the fight, porthole for flights.**
- Cut-away when a fighter is settled behind a block row (free, in an exchange, charging, firing): the buildings between the camera and the span from one fighter to the other, plus a margin, go down to stubs. Each pane has its own cut.
- Porthole, as built, while a body is in flight (launched, thrown, rushing): it passes behind a tower for a fraction of a second, and cutting and restoring towers at that rate would flicker.
- The porthole's discard moves into a shared include so trees, formations and props in front of a fighter open too.
- I would hold the silhouette in reserve. If Orb picks it, the spike comes first.

**State needed from the sim: none new.** I read `Fighter.z`, the footprints, `ex.z`, the flight waypoint (`aimX0`, `aimZ0`, `aimZ1`, `aimD`) and, after L5, the beam's `oz` and `zs`. `launch_depth` for every launch (L0) is enough to open a cut ahead of a flight.

## 3. Terrain strips

**How the ground is drawn today.** One grid: terrain columns by 24 rows in depth across the crater band, coarser with distance. Heights are computed in the vertex stage from a float data texture (21 data rows of 4,800 values, 403 KB), which is uploaded whole whenever the ground changes. Because the sim has one row, the renderer invents the depth: it sums each crater record as a round bowl, spreads scorch grooves and slide trenches to a width, and lays rubble as a plateau to the fallen building's far face. Only the row on the fighter plane is the sim's own, bit for bit.

**With sim rows.** Inside the band the drawn ground becomes exactly `groundY(S, x, z)`: the same two rows and the same linear blend as the sim. The renderer's inventions (the bowl sum, the groove and trench widths, the rubble plateau) are needed only outside the band, in front of the first row and behind the last, continuing from the edge rows. So T2 removes render code inside the band. Props, the crowd, shadows and the lane cue all stand on `groundY(S, x, z)`.

**Cost of 8 rows, estimated from today's numbers:**

| | Today | 8 rows |
| :--- | :--- | :--- |
| Geometry and draw calls | 24 mesh rows in depth | Unchanged. Mesh rows are placed on the sim's rows. |
| Data texture | 403 KB in one texture | About 1.3 MB, split into three textures by how often they change (static; water and shore; the rest). |
| Upload on a tick where water moves (12% of ticks) | 403 KB | About 310 KB (only the water texture). |
| Upload on a dig | 403 KB | About 0.9 MB, once per dig. |
| Vertex stage | Some tens of texel reads a vertex (not counted) | About 6 more (a second row for each blended field). Fewer in the band once the bowl sum is gone. |
| CPU ground update (desktop, water ticks) | p50 0.23 ms, p99 0.6 ms | The shore scan runs per row. Up to 8 times that if every row's water changed; I will compare rows in chunks and scan only the ones that changed, as today. |

**Answer: 8 rows are affordable on the Compatibility renderer. 16 would be too** (about 2.5 MB of texture, the same geometry). The row count is limited by the sim's tick and hash, not by drawing.

**The phone is not measured.** The two risks are the float-texture upload on a frame where the ground changed and the vertex stage's texture reads on a weak mobile GPU. The game already depends on both. Before T1 I can build a behaviour-neutral mock (8 identical rows through the new texture layout) and run it on `/bench/`; the phone number needs Orb's real phone. For reference, today's web build at a 4x CPU slowdown is 13 ms mean and 23 ms at p95, so the old-laptop proxy already misses 60 fps at p95. Nothing in this plan may add CPU per frame.

**What 300-unit rows look like.** A small bowl (radius 160) lies between two rows, so in depth it is a V, not a curve. From the side camera depth is foreshortened about ten to one, and I can keep the shading round by taking normals from the crater records, so it will read as a bowl. If Orb's camera answers raise the camera much (toward the prototype's three-quarter view), the facets will show and 16 rows of 150 units would be worth their sim cost.

**The slice order problem.** After L4 fighters stand at any depth, on the sim's ground. Until T2 the sim's crater is a trench across the whole band, while I draw a bowl that fades away from the plane. Between L4 and T2 I must choose:
- draw the sim's truth, so every crater in the band is a trench 2,400 units deep into the screen (Orb's "canyons"); or
- keep the bowls, and fighters at depth sink into or float over the drawn ground by up to a crater's depth.

Neither is good. My input to Simulation's question 3: land T1 and T2 with L4, or accept trenches in the band for the time between.

**Asks about the rows (for Simulation and World):**
1. One row lies exactly on z = 0, so the plane row and its bit-for-bit check stay. For example rows at z = +300, 0, -300 … -1,800.
2. Outside the first and last rows, `groundY` clamps to the edge row.
3. Water between rows. If rows never share water, a lake in one row beside a dry, lower row gives a sloped or cut water sheet in depth, the same artefact I fixed along x in Playtest 2. I can apply the shore rule in depth as well (one more data row per row). A sim rule that levels water across the rows one crater covers would be cleaner.

## 4. Depth aids

All of these read the fighters' interpolated `x`, `y`, `z` and `groundY(S, x, z)` (and the water surface). Nothing else.

- **Ground shadow (built).** It stays on for both fighters at all times.
- **Lane cue (new).** A soft stripe on the ground at each fighter's depth, in his colour, running a few fighter heights each way along the street and fading out. Drawn inside the ground shader from two uniforms a pane, so it costs no draw call and follows craters. Shown only when it carries information: the two fighters are at different depths, or a fighter's depth is changing. On water it lies on the surface.
- **Altitude line (new, optional).** A faint vertical line from a high fighter down to his shadow, so the shadow is tied to him when he is far above it. One quad a fighter. Off below a height. Camera and Orb decide whether it is wanted.
- **Painted streets.** The strongest depth cue is the street itself. With World's lane table the ground shader paints road, kerb and pavement bands by `z`, so a fighter's shadow is seen on a street or between buildings. This needs the lane table as a small texture or uniform array (L1).
- Not proposed: tinting or hazing a deep fighter. It would cost readability exactly where he is already small.

## 5. Traffic and street crowd (ask 4)

Cosmetic, as Simulation says: placed from the lane table and driven by the `evacuate` events, on sim time, from render-side streams seeded from the world seed. One MultiMesh per kind (cars, bikes, pedestrians share the crowd's), about three more draw calls a copy.

One rule I need agreed: **nothing cosmetic is ever within a fighter's reach.** ADR 0009 says collisions are true, so a car a fighter flies through would break it on screen. Cosmetic traffic drives off and pedestrians run before the fight arrives (I have the blows and the fighters' positions). Anything still standing near the fight must be one of World's props in state (P1).

## 6. Closer framing and close-ups

Today a fighter is about 45 px tall in play (75 units at zoom 0.6) and 86 px at the zoom cap. The mannequin is about 2,700 triangles, rigid-skinned, flat-coloured with no textures, with a 1.5 px inverted-hull outline. Animation's level-of-detail tiers are near (30 px and up, 2,500 triangles plus 500 of cosmetics), mid (900) and far (250).

**Fighters twice as large in play (about 100 px):**
- The fighter costs almost nothing more. The triangle count is not a load, and the draw calls do not change.
- The outline should grow with the drawn height (Art sets the curve). The hull has been checked at 1.5 px only. A wider outline needs the crack check rerun, since a corner reaches up to 2.5 times the width.
- Glows and auras cover four times the pixels. That is fill rate on a phone; VFX's quality levels have to cover it.
- No anti-aliasing is on today. Larger, slower silhouettes show stair-steps more. 2x MSAA on the pane viewports is the fix, as a quality setting, unmeasured on phones.
- **The lens, not the distance.** The camera has a 30 degree lens. Moving it closer to enlarge fighters brings it up to the front street. At 100 px the camera is about 1,000 units from the plane, and a fighter at the band's front edge (375 toward the camera) draws 1.6 times the size of one on the plane. At 225 px the camera is 450 units away, 75 from that edge. A longer lens enlarges fighters without that, and it shrinks deep fighters less. A lens change costs me a day: the sky's horizon and the foreground rule take the lens angle as a constant today.
- **The world is the real cost.** At that size a 32-unit ground column is over 40 px wide, so crater rims and slopes show as straight segments. Buildings are flat boxes in one colour and fill the screen as blank slabs (already visible in B3's shots). The crowd figures are simple. I can add windows and floor lines to the building shader procedurally, with no textures, and smooth the ground's shading. Real façades, street furniture and a better crowd figure are Art's and World's work.

**Close-ups for cosmetics (300 px and up):**
- This needs a level of detail above "near" that does not exist: more triangles in the hands, head and face (I would budget 8,000 to 12,000), and a way to show cosmetic detail. Today each part is one flat colour. Emblems, trim and patterns need UVs with a small atlas, or vertex colours. That is a decision for Art and Animation, and it changes the body shader.
- Facets are the style, but at this size each one is large. Art should say whether close-ups keep hard facets or get smoothed groups.
- A cosmetic viewer in a menu is cheap: one fighter in a small viewport with no world. In-match close-ups (intro, finisher, victory) put the world's lack of detail behind him, so they want a shallow background treatment (Camera) or the façade work above.
- Level-of-detail selection by drawn height per pane, with Animation's merge at equip for cosmetic pieces. Still two draw calls a fighter.

## 7. What I need from the others (through the EP)

- **Orb / Camera:** the occlusion pick; the camera's elevation and lens (they decide whether 8 rows read as bowls and how I enlarge fighters); whether the altitude line is wanted.
- **Simulation / World:** the three row asks in section 3; the lane table in a form the ground shader can read; the order of T1 and T2 against L4.
- **VFX:** every emitter placed by the event's `z`; beams with `oz` and `zs`; the porthole include in its materials that can stand in front of a fighter.
- **Art / Animation:** the outline curve against drawn height; the close-up level of detail and how cosmetic detail is carried.

## 8. My work, by slice

| When | Work |
| :--- | :--- |
| Now, no sim window needed | The occlusion method Orb picks, on today's brunt flights and a staged back-street pose. The lane cue. The inverted-depth spike if the silhouette is chosen. |
| After L0 | Particles and impact marks placed by the events' `z`. Crowd startle by plan distance. |
| After L1 | Painted streets from the lane table. Cosmetic traffic and street crowd. |
| Before T1 | The 8-row texture layout as a neutral mock, benched on the web and on Orb's phone. |
| With T2 | The band's ground from the sim's rows; render-side bowls, grooves and rubble plateaus kept only outside the band. The ground check extends from the plane row to every row. |
| With L4 | Both fighters at depth all the time: flashes, glows and cues at depth; the checks (pane, seam, flash, cue) gain a depth sweep. |
