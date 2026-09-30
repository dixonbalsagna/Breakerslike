# VFX plan: speed you can read, destruction that hits

Owner: VFX Director. Written 2026-09-29 for the EP's brief "make speed readable and destruction impressive". As built: `docs/vfx/README.md`; budgets: `docs/vfx/effect-budgets.md`. It replaces the wave-1 paper brief (inventory, style options, budgets, readability); what still fits is folded in below (section 1, section 6 and section 7). Nothing in this file is locked. Every number is a starting value that lives in one look file (`render/vfx/vfx_look.gd`), so tuning never touches logic.

## 0. What Orb asked for, and what "done" is

Orb's playtest (`docs/ep/vision.md`, "Playtest feedback"):

- Speed. "It's hard to follow when a fighter picks up a lot of speed. Simple stylised motion trails, used sparingly and effectively, could help ground the viewer."
- Destruction. "Cracked and split ground, a fighter colliding with skyscrapers bursting out the other side with glass and steel shrapnel, buildings collapsing."

Done when (each is a test in section 8):

1. A fast fighter leaves a trail and the world gives the eye something fixed to read speed against, and nothing shows below melee speed.
2. Impacts and slides crack the ground in proportion to their energy, and the biggest ones split it.
3. A launch through a tower reads as in one side, out the other, with glass and steel; a collapse reads as weight (dust, rubble, a ripple).
4. Effects never cover a fighter, never change the gameplay hash, and hold their budget on an old laptop.

## 1. Ground rules

- **Presentation only.** VFX reads `S`, the fx event stream and the render's own state. It never writes the sim, never reads or advances `S.rng`, and never feeds anything back. The sim already holds no cosmetic state (`docs/architecture/fx-events.md`), so QA-002 is closed on the sim side. VFX's own randomness comes from streams derived from the match seed by `SimRng.deriveSeed(seed, "vfx.<class>")`, one stream per effect class (`vfx.trail`, `vfx.crack`, `vfx.shard`, `vfx.dust`).
- **Rebuildable from state.** Permanent marks (cracks) are a pure function of the sim's records (`S.craters`, `S.slides`) plus the match seed, so a seek, a snapshot restore or a late join draws the same cracks. Transient effects (trails, shards, dust) need events and are simply absent after a seek, like all particles.
- **Own paths.** `render/vfx/` and `docs/vfx/`. Nothing in `render/core/` changes; the hooks I need are listed in section 5 and go through the EP.
- **Style** (`docs/art/style-guide.md` sections 0 and 7): effects are hard-edged cut-out shapes with two or three value steps, no outline, a hot core and a darker rim, no soft additive glow as the main look. Fire owns orange and yellow. A fighter's accent, never gold, yellow, red or orange for the Protagonist and the Anti-hero, is the trail's rim colour. No power-level text, no numbers on effects.
- **Never obscure the fight.** Every effect near a fighter sits behind the fighter plane (z below 0) or is capped in alpha and radius (`readability` rules in section 7).

### What exists today, and who owns it

| Effect | Where | Owner | VFX plan |
| :--- | :--- | :--- | :--- |
| Sparks, rings, debris, dust, splash, flame, afterimage | `sim/core/view/fx.gd` (reference consumer), drawn by `render/core/particle_view.gd` (one MultiMesh, 3,601 quads) | Rendering | Stays. VFX takes over the look later through Art's palette |
| Crater ejecta, rim dust, shock ring, groove heat, embers, slide dust, skim spray, ripples | `render/core/impact_fx.gd` (cap 1,200) | Rendering | Stays; VFX adds cracks on top of the same events |
| Pavement crack tint, trench, bowls | `S.crack`, `terrain.gdshader`, `ground_field.gd` | Rendering | Stays; VFX's cracks are geometry lines over it |
| Head flashes | `flash_view.gd` | Rendering and Art | Untouched |
| Beams | `beam_view.gd` (80 lines, cylinders) | Rendering | Later (P2 below): variant looks |
| Aura, streaks, charge orb | `fighter_view.gd` | Rendering | Off while flashes are on (Art: no standing aura) |
| **Motion trails, cracks, shrapnel, collapse dust** | did not exist | **VFX** | This plan |

## 2. Motion trails

### 2.1 What we are fixing

In the split screen and in the launch follow the camera holds the fighter in place and the world streams past (`split-screen.md` section 8: "the world streams past; the fighter stays fixed on screen"). A launch at the median 10,800 units a second is about 6,000 px a second at the pane zoom, so the ground is a blur and the fighter has no visible motion. The fix is two things: a **trail** that stays attached to the fighter (so speed shows as length), and **fixed marks in the world** that the camera flies past (so speed shows as motion against something still).

### 2.2 When

Speed is measured from the fighter's displacement over each unfrozen tick, in body heights (bh, 75 units) a second. That covers free flight, launches, slides and rushes alike, and it is independent of zoom: the camera keeps a fighter 32 to 47 px tall, so bh a second maps to a steady number of pixels a second.

| Reading | bh/s | units/s | Where it comes from | Trail |
| :--- | ---: | ---: | :--- | :--- |
| Walk, melee dash | up to 18 | up to 1,340 | `fighter.gd` free flight, `TRAV_FREE` off (opponent under 1,500 units) | none |
| Long rush | 12 to 50 | 940 to 3,750 | `stepRush` (already has `after` silhouettes) | none to faint |
| Traversal dash | 60 to 180 | 4,500 to 13,500 | dash ×10 at 12,000 separation | full |
| Launch | 40 to 300 | 3,000 to 22,000 | `TRAV_LAUNCH` ×6 horizontal, median 10,800 | full at the start, fades with the drag |
| Slide | 10 to 100 | 750 to 7,500 | `WorldSlide.step` | ribbon only above the on threshold |

- `V_ON` = 40 bh/s, `V_FULL` = 110 bh/s. Intensity `k` = smoothstep of speed between them, eased in over 0.06 s and out over 0.25 s so a trail does not flicker at the threshold.
- Sparse by rule: nothing below `V_ON`, at most one ribbon and ten streaks per fighter, and a trail never draws while the fighter is `down`, `charging` or hit-stopped (frozen ticks add no points).
- **Orb decides** the two thresholds; they are constants.

### 2.3 What it looks like (our style: stylised, cel, sparse)

Three parts, all hard-edged:

1. **Ribbon.** A tapered blade from the fighter's chest back along its last 0.07 to 0.2 s of path (up to 4 straight segments, so a curved launch bends), at most 14 bh long. Two nested layers: an outer band (0.5 bh wide at the head, the fighter's accent in its light step, 55% alpha) and a core (0.22 bh, near white, 90% alpha). Three stepped bands along the length (full, then two half-value steps) instead of a smooth fade. It sits at z = -12, behind the fighter, so it can never cover it.
2. **Wind marks.** Thin dashes fixed in the world, spawned ahead of the fighter along its path and left behind, so the camera flies past them. Length is speed × 0.05 s, so each mark spans at least three frames of travel and never strobes. They keep at least 0.7 bh off the fighter's centre line and sit at z between -30 and -8. Off in reduced motion.
3. **Break ring** (P1, after the first two are approved). A single thin arc at the fighter's front the first time it crosses `V_FULL` from below, 0.25 s, once per crossing. It is the only "moment"; everything else is continuous.

Colour: the fighter's `aura` colour (accent) with a near-white core; if that hue falls in the fire range (orange, yellow, red) it is swapped for the haze neutral. Art owns the final roles (section 7, rule R5).

### 2.4 Budget

| Item | Per pane | Notes |
| :--- | ---: | :--- |
| Ribbon segments | 2 fighters × 2 layers × 4 = 16 quads | one MultiMesh, one draw call |
| Wind marks | 2 × 10 = 20 quads | same MultiMesh |
| CPU per frame | under 0.05 ms per pane | 36 quads written to one float buffer, the way `particle_view.gd` does it |
| Overdraw | 36 thin quads | far under one full-screen layer |

The split screen draws the world twice, so the trail is drawn per pane from a shared history.

## 3. Destruction: events and looks

`crater`, `slide`, `slide_dust`, `scorch` and (in the working tree, B1) `building_fall` exist. `building_hit`, `chain_link` and `launch_depth` are B2 and do not. The right-hand column says which are mock-driven.

| Effect | Sim input | Exists | What it looks like | Tier scaling | Built |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **Ground cracks** | `crater` {x, r, depth, rim, energy, cause, skid} | yes | Hairline web out of the rim: radial spokes with jogs and Y forks, two dark steps with a lit lip on the near side, draped on the ground surface. High energy adds fissures: fewer, longer, wider splits with a dark throat, drawn at a least thickness on screen so they read at the grazing camera (a cutaway gash at the ground profile was tried on paper and dropped: land in front of the plane occludes it) | Spoke count and length grow with sqrt(energy); fissures only above a threshold (Orb: "save the biggest for special attacks") | tonight |
| **Slide cracks** | `slide_dust` (a sample every 40 × WS), `slide` (end), `S.crack`, `S.slides` | yes | Herringbone spurs off the trench edges on paved ground, shattered slab lines, one fissure fan off the stop berm at the end | By energy and paved or not; paved only gets the slab pattern | tonight |
| **Skyscraper burst-through** | `building_hit` {b, x, y, z, damage, ratio, outcome, link, n, spd, keep, ux, uy, kind, w, h, victim} (B2, `docs/world/b2-plan.md` §5), `chain_link` | no (B2) | In: a flash ring, glass thrown back toward the camera, a dust puff, a jagged hole decal on the near face. Out: a cone of glass slivers and steel pieces along the flight, a hole on the far face, a smoke tunnel behind. The fighter is hidden inside by the building's own facade | `outcome` (crack, wreck, heavy, collapse) and `spd`: crack gets dust only, wreck and heavy add shards and leave a hole, collapse adds the full cone and the fall | tonight, mock-driven |
| **Chain link tunnel** | `chain_link` {from, to, x0..z1, dur, link} | no (B2) | Debris and dust streamed along the segment between two hits, thickening with each link | `link` index | mock-driven |
| **Building collapse: implode** | `building_fall` {b, x, y (= z), w, depth (= height), mode "implode", delay, cx, rubble, n} | yes | A dust skirt around the base, a rising column, chips falling straight down, a ground ring, staggered by `delay` so a block goes in a ripple outward from `cx`. The heap itself is the ground (`S.rubble`, Rendering) | Size by width and height; a summary event (`b` -1, `n` folded) becomes one district cloud, not n | tonight, driven by real events plus a mock scene |
| **Building collapse: burst** | `building_fall` mode "burst" after a `building_hit` | mode yes, hit no | The burst-through effect finishing in a fall: heavier dust, bigger chips | as above | with the burst-through |
| **Beam scorch embers** | `scorch` {x, y, w, power, variant, owner} | yes | Rendering's embers today are uniform sparks. VFX version: per-variant ember shape and colour (a glass trench sheds bright glass flecks, a firestorm long cinders), rising and drifting, counts by power | `power` P (0.5 to 4.5) | P2, after the above |
| **Fissure vent** (P2) | crater or fissure record | yes | A thin dust jet from a fresh fissure for 1 s | energy | P2 |

Events I need that do not exist yet (through the EP, to World and Encounter for B2):

- `building_hit`, `chain_link`, `launch_depth` as specified in `docs/world/buildings-in-depth.md` section 5, and B2 already adds `victim`, `ux`, `uy`, `kind`, `w`, `h`, which is all I asked for (`docs/world/b2-plan.md` §5). The consumer reads those names; the mock (`render/vfx/mock/vfx_mock.gd`) emits them.
- The direction of travel is the sign of the launched fighter's `vx` at the event tick, read from `S.fighters`. No new field is needed for that.
- When a chain lands, one `building_hit` per building, each on the tick the fighter reaches it, exactly as B2 already plans.

The mock (`render/vfx/mock/brunt_mock.gd`) emits events with the same field names and units. When B2 lands, the consumer reads the real ones with no code change; the mock and its flag go.

## 4. Look details that need Orb or Art

These are open. Each has a default so I can build now.

| Question | Default | Who |
| :--- | :--- | :--- |
| Trail colour: the fighter's accent, or one neutral for both fighters | Accent rim, near-white core | Art (palette roles), Orb |
| How much glass versus steel in a skyscraper burst | 70% glass slivers, 30% dark steel | Art |
| Are cracks black-lined (cel line) or biome-darkened | The biome's shadow step, darker by about 30 in L* | Art |
| Trail and marks under "reduced motion" | Ribbon only at half alpha, no marks | UI and Accessibility |

## 5. Hooks I need from Rendering (through the EP)

I own `render/vfx/`. To draw in the game I need Rendering to add these lines. I do not touch `render/core/`.

1. `SimHost`: `var vfx := VfxHub.new()`; in `new_match`: `vfx.reset(seed)`; in `tick`, just before `S.out.fx.clear()`: `vfx.consume(S, S.out.fx)`. (One line each.)
2. `PaneWorld`: `var vfx_layer := VfxLayer.new()` added as a child; in `build(S)`: `vfx_layer.build(S)`; in `render(...)` after the fighters update: `vfx_layer.update(host, a, cam_x, cam, vp)`. A second pane shares the hub, exactly as it shares the planet's ground field.
3. `PlanetView`: expose the ground field (`ground`) so my cracks can read `ground_at(S, x, z)`. It already exists as `planet.ground`; please keep it public.
4. `ParticleView` stays as it is. My shards and dust use my own pools so the 3,601-quad cap is not squeezed.

Until then I test through an inherited scene, `render/vfx/tools/vfx_main.tscn`, that adds the hub and the layers on top of `render/main.tscn` without editing it.

Other requests: **Camera** shake per chain link is already proposed in `buildings-in-depth.md` 4b; I do not add any. **Art**: semantic effect colours (trail rim, glass, steel, dust, crack line, lit lip). **Performance**: the particle row and the worst-case scene; my numbers are in section 6. **UI**: I read the existing `reduced_motion` option; I would like a separate `vfx_quality` (auto, high, medium, low) in the options.

## 6. Budgets (draft, to align with Performance)

Worst case for these effects: a chain through four towers at tier 4, a fissure from a tier-4 slam, two fighters at full trail, dust from a district implode, all in one frame.

| Pool | Max live | Instances per event | Draw calls | Degrade order (first to go) |
| :--- | ---: | :--- | ---: | :---: |
| Trail ribbons and marks | 36 per pane | n/a | 1 | 3: marks first, then the outer band |
| Crack meshes (static) | 60 crack sets, about 9,000 triangles in all | 6 to 40 lines per set | up to 8 (batched by chunk), frustum culled | 4: hairlines first, then oldest sets |
| Glass and steel shards | 220 | up to 60 per hit, 24 in `low` | 1 | 1: glass first, steel last |
| Dust puffs (VFX pool, not Rendering's) | 240 | up to 40 per building, 120 per blast | 1 | 2: the far ones |
| Hole decals | 3 per building, 24 in all | 2 per burst-through | 1 | 5: oldest |
| Break ring | 2 | 1 | 0 (shares the trail's MultiMesh) | 6 |

Per-blast cap: 700 particles however many buildings the blast levels; the folded summary event is one cloud. Every pool drops its oldest instance when full and never drops a gameplay-critical effect: the hit flash and the fall dust of the building the director chose are reserved slots. `VfxQuality` has three levels (high, medium, low); `low` drops the marks, the outer band, hairline cracks, and cuts shard counts to 35%. An automatic step-down watches the frame time (presentation only): below 42 fps for two seconds drops a level, at or above 57 fps for eight seconds (and 20 s after a drop) climbs back. Desktop defaults to high, the browser to medium.

## 7. Readability rules (kept from wave 1)

Each has a test and a dependency, phrased as a request for the EP.

| # | Rule | Test | Depends on |
| :--- | :--- | :--- | :--- |
| R1 | No effect covers a fighter: trail and marks sit at z below the fighter plane; shards and dust near a fighter are capped at 60% alpha and never draw in front of its body | Screenshot test: fighter pixels unchanged with effects on, within the outline | Rendering (fighter draw order) |
| R2 | A hit window is never hidden: the hit flash and ring stay under 0.4 bh around the contact point at 0.15 s | Frame test at contact: fighter bounding boxes clear of fill above 60% alpha | Combat (hit and window events) |
| R3 | Trail readable at minimum zoom: at the pane's usual 32 px fighter the ribbon core is at least 2 px | Pixel test on a posed launch | Camera (zoom floor) |
| R4 | Semantic colour lanes, each also carried by shape or motion: trail (accent rim, blade shape, moves with the fighter), glass (pale cyan, thin slivers), steel (dark grey, chunky), dust (biome grey-brown, soft disc), crack (dark line, lit lip). Fire keeps orange and yellow | Greyscale and colour-blind simulation of the sheet: every lane still separable by shape | Art (palette), Accessibility |
| R5 | No flash above three per second across the screen; reduced motion removes marks and cuts shard counts | Frame-difference test on a chain scene | UI (reduced_motion option), Accessibility |

## 8. Build order and tests

Tonight, in this order, each with a check:

1. **Trails** (`render/vfx/`): hub, per-fighter history and intensity, the MultiMesh view. Check: no trail under `V_ON` in a 60 s match; a launch shows one; caps hold over 3 seeds; the seam crossing draws continuously.
2. **Ground cracks**: generator (pure, seeded), static draped meshes, from `crater` and `slide` events and rebuilt from `S.craters` and `S.slides`. Check: live and rebuilt meshes are byte-identical.
3. **Hash and determinism**: `render/vfx/tools/hash_check.gd` runs seeds 12345, 4 and 7 with VFX off and on, at 60 Hz, 144 Hz and jitter, comparing the gameplay hash every 60 ticks, plus a negative control and a check that `S.rng` is not touched. Must pass before anything else is reported.
4. **Shrapnel and collapse** prototype: mock scenes (a single burst-through, a three-tower chain, a district implode) on the real consumer.
5. **Frame time**: `--bench` baseline against VFX on, desktop (split on, seed 4), and web if an export is available; plus a worst-case scene run (the mock chain with cracks and trails). Numbers go in `docs/vfx/README.md` (as built).

Later (not tonight): break ring, fissure vents, variant embers, beam and clash looks, tier readability, the aura and surge (Art's surge cinematic).

## 9. Risks

- **The camera is nearly level.** The ground band is foreshortened about ten to one, so surface cracks read as thin dashes unless the camera is high. The shader therefore widens each crack to a least thickness on screen. Built and checked in pictures (`docs/vfx/README.md`); a real notch in the ground profile (World carving fissures into `S.deform`) would read from every angle and is the stronger option if Orb wants the split more dramatic.
- **Crater energy is being retuned** (Orb: small craters for most impacts). My crack scaling reads `energy`, so it follows World's new range; the thresholds are constants until World settles.
- **B2 is not in.** The burst-through is a prototype on mock events. If World changes the field names, the consumer's adapter is one function.
- **Streak strobing.** Marks shorter than a frame's travel would flicker. The length rule above prevents it and the frame-difference test checks it.
- **Old laptops.** Everything is one MultiMesh or static meshes with no loops in shaders. The measured cost goes in the as-built doc; if a low-end pass shows trouble the `low` level is the answer, not a rewrite.
