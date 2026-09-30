# Head-flash prototype: spec for Rendering

Owner: Art Director, for Rendering and Technical Art (routed by the EP). 2026-09-29. Draft. Build it after the cheat-out. Orb wants to judge the flashes in motion, not from stills, so this is a small in-engine prototype on the placeholder fighters. Design: `docs/art/marked-aura.md`. Data: `data/art/flashes.json` (canonical, owned by Art). Nothing here writes to the sim.

## 1. What the prototype must show

Brief, iconic pops at a fighter's head that say what it senses or feels, then nothing. Thirteen flashes in the fighter's own shape family, driven by a state, with real timing (0.3 to 1 s), a real priority rule, and no clutter at rest. Orb should be able to play a match, see the flashes fire from real events, and fire each one by hand to compare.

## 2. Scope

- **Placeholder fighters only.** The greybox capsules and boxes. No sigil or mask work is needed; the flash draws over the greybox head.
- **Render-side only.** Reads the fx events and the fighter state. Never writes the sim. Jitter and any randomness come from a cosmetic render stream (name it `vfx.flash`), never the sim stream. The gameplay hash must be unchanged with the prototype on or off (run `render/tools/determinism.gd`, including its negative control).
- **A switch to compare.** `F7` toggles the prototype. When it is on, the placeholder tier aura sphere and the streaks (`aura`, `orb_*` in `fighter_view.gd`) are hidden, so the flash is judged on its own. `F8` toggles the legacy shapes (section 9).

## 3. How it draws

- **One `FlashView` per fighter,** a child of the `head` node in `render/core/fighter_view.gd`, so it follows the head and the cheat-out staging, and mirrors with the body. It uses the hybrid projection (`render/shaders/ortho.gdshaderinc`) like every other fighter part, so it does not warp at the screen edge.
- **Flat filled quads, no textures.** A `MultiMeshInstance3D` of 12 quads (one draw call), plus one quad for the glyph (one draw call). Unshaded, `blend_mix`, depth test on, no depth write, cull disabled. Use `RenderMats.flat_alpha` as the pattern.
- **Shapes are drawn in the fragment shader** from a signed distance per family, chosen by a uniform `family` (0 circles, 1 blades, 2 wedges, 3 steps). The shapes:
  - circles: a disc of radius `size * 0.3`;
  - blades: a triangle from the base point out along the angle, half-width `2.3` units (thin, after the playtest), with a rounded-tip option;
  - wedges: the same with half-width `5.2` units;
  - steps: a square of side `size * 0.6`, snapped to a 3-unit grid in world space.
- **Each instance has custom data** `(angle, distance, size, opacity)` from the layout table, plus a per-layer tint. Two layers per shape: a rim at full size in the accent's mid step, and a core at 0.58 size in the accent's light step. Info flashes use a thin keyline for the rim (`info_colours[family].line` in `flashes.json`) and a pale core (`info_colours[family].core`), at full opacity. The core fills 84% of the rim, so the keyline is thin. Never yellow, red-orange or a thick black outline.
- **Glyphs** ("found" is a bang, "searching" is a question, "hazard" is two bangs side by side, both in the family's shapes and never a font) are drawn in a second quad by the same shader with `glyph` set to 1 or 2. The bang is a stem and a dot; the question is a hook and a dot. Each is built from the family's primitive: capsule and dot, blade and diamond, wedge and triangle, snapped squares. `ma-2-flashes.svg` shows all four, and `gen.mjs` (`glyphPolys`) has the exact geometry.
- **Size and keep-out (`keep_out` in the data).** About half the size of the first version (the surge a third): the largest shape is 40, most are 30 or less. Every shape sits up and back of the head, angle 65 to 175 degrees in the facing frame (0 forward, 90 up, 180 back), never forward toward the opponent and never below the head centre, so nothing covers a torso or a face on either fighter. The glyphs are drawn at 1.1 head units (were 1.7). Rendering should assert the angle range in a debug check.
- **Unit and place.** All sizes are in hundredths of a body height (`FighterView.HEIGHT`, 90 units), so `size 60` is 54 world units. Anchor: the head centre, plus 2 units up. The glyph sits 7 units of head size above it. The flash is behind the head (about 6 units behind the fighter plane), and the glyph is above the head, so neither hides the mask, the sigil or the chest. The layout is written in the fighter's facing frame (0 degrees is forward, 90 is up) and mirrors with the body.
- **Ground shards** (the surge only) are instances with `ground = true`: their y is the ground height under the fighter, read from the terrain the way the fighter's shadow is.

## 4. The data

`flashes.json` has, per flash: `class` (info or emotion), `pulse` (`count`, `on`, `off`, `fade` in seconds, and `total`), `total`, `priority` (1 is highest), `cooldown` (seconds, per fighter), `kind` (layout or glyph), `glyph`, `layout` (the instances), `moment`, `event`, `sound`. The file lives at `data/art/flashes.json`, and Rendering reads it from there (`res://data/art/flashes.json`). Art edits it through `art/concepts/marked-aura/gen.mjs`, which is where the layouts and timings are authored. Numbers live in data, not code.

## 5. The state machine (per fighter)

- **State:** `id` of the flash showing, `t` (seconds since it fired), a small queue, and a cooldown timer per flash id.
- **Time base:** sim time, so a flash holds still in hit-stop and pause, like the staging turn. The surge runs on cinematic time.
- **Envelope `k` (pulses):** a flash pulses two or three times, then is gone (`pulse.count`). Pulse `i` starts at `i * (on + off)`. It rises to 1 over `0.3 * on` (eased, `1 - (1 - x/rise)^2`) and then shrinks to 0 by the end of `on` (`1 - ((x - rise)/(on - rise))^2`), with a beat of nothing for `off`. The last pulse holds at 1 to the end of `on` and then fades over `fade` (`1 - ((x - on)/fade)^2`). `total = count * on + (count - 1) * off + fade`, 0.4 to 0.8 s, and the surge 1.85 s (three slow pulses, never a standing cloud, not held for the cinematic). Size scales by `0.55 + 0.45 k` and opacity by `k`. `reduced_motion`: one pulse and a plain fade.
- **Firing:** `fire(actor, id)` checks the cooldown, the priority rule and the arbitration rule (section 7), then starts or queues the flash.

## 6. Triggers

Wire the events that exist today, and add debug triggers for the rest.

| Flash | From an existing event (`docs/architecture/fx-events.md`) | Until then |
|---|---|---|
| Found | `found` (actor is the finder) | debug key |
| Hurt | `damage` with `kind` heavy, or `region_broken`, when the crown is not up | |
| Triumph | `ko` (winner) | |
| Surge | `tier_up` as a stand-in, until `cinematic_start` and `cinematic_end` exist (hold for the cinematic length) | |
| Resolve | `brink_exit` as a stand-in, until `rally` exists. Sequenced (section 7): it starts 0.1 s after the crown's wear pop fades | |
| Rage | `banner` events for a clash, as a stand-in only for the prototype | debug key |
| Danger sense, hazard, searching, fear, pride, respect, taunt | none yet (Encounter's slices: `hazard_telegraph`, lock lost by line of sight; Game Design; Narrative barks; respect from `clash_draw`, `finisher_blocked` and the rival's `rally`) | debug key |

**Debug triggers** (Rendering's debug overlay, not Controls' bindings): hold Alt and press the keys in the order of `flashes.json`: 1 to 9 for danger sense, hazard, found, searching, fear, rage, hurt, resolve, triumph; 0 for pride; minus for respect; equals for taunt; the left bracket for the surge. It fires on P1; add Shift for P2.
**Audio:** emit a cosmetic `flash` event `{actor, id}` when a flash starts, so Audio can pair its cue. The prototype plays nothing.

## 7. Priority and arbitration

Priority, highest first: surge, danger sense, hazard, found, searching, fear, rage, hurt, resolve, triumph, pride, respect, taunt (the numbers are in `flashes.json`).
- One flash at a time per fighter. A higher priority preempts (the lower fades in 0.1 s). The same priority extends the hold and never replays the attack. A lower priority waits up to 0.25 s and is then dropped.
- **Never a flash and a crown together.** UI's crown owns wear. Rendering needs a callback from UI, `crown_up(actor) -> bool` (the crown's `crown_hold` above 0). A flash due while the crown is up waits up to 0.25 s and is then dropped. A wear event arriving while a flash is up fades the flash in 0.1 s. The surge is the exception: during a transformation cinematic the crown stays down.
- Info flashes are never dropped for an emotion flash, only for the surge.
- A hidden fighter shows no flash.
- **Resolve is sequenced, not dropped.** On a Rally the crown pops first. Resolve (`flashes.json`, `flashes.resolve.sequence`) waits for `crown_up(actor)` to turn false, starts `delay_after_crown_down` (0.1 s) later, waits up to `wait_max` (2.0 s) and is never dropped by the 0.25 s rule or by a lower-priority flash. Only the surge can preempt it. `arbitration` in the data carries the default wait (0.25 s) and this exception.
- **Held: Primed** (the ambush window) is out of the active set because hiding left the base game. Its layout stays in `flashes.json` under `held`, with Winded, Smug and Bored. Respect has no star and no hand pose; it is a level pair of shapes and a small one above.

## 8. Colour and motion

- **Colour** is the fighter's accent, two steps (`flashes.json` `accents`, the canonical steps; do not copy them into code by hand), from the palette in `art/concepts/marked-aura/gen.mjs` (`CALM`): Protagonist teal `#4fb9a8`, Anti-hero orchid `#9a80d8`, Empress moss `#b8c96a`, Cyborg coral `#d8705f`. No red, red-orange or gold for the Protagonist or the Anti-hero. The placeholder fighters have their own greybox colours (`RenderLook`); use the accent from `flashes.json`'s companion palette until the real palettes land.
- **Contrast on the hair.** The Protagonist's teal flashes overlap his teal hair (the placeholder's hair is teal too). Use `emotion_colours.overrides.P`: the rim is the accent light step and the core is near-white, so the flash stays lighter than the hair. Info flashes are unaffected (a pale core with a dark keyline).
- **Hurt is capped.** Its cooldown is 6 s per fighter, so a flurry of heavy hits gives one flash. If it is still busy for Orb, raise it, or fire it only for `region_broken`.
- **Emotion flashes** are translucent (34 to 55% opacity). **Info flashes** are solid and keylined. That is the rule that tells a player at a glance whether a flash is a feeling or a fact.
- **Motion:** the flash pulses (section 5): a quick swell and shrink, two or three times, a beat of nothing between, then gone. It changes shape as it pulses (size scales with the envelope). Hurt fragments jitter, at most 4% of a body height, irregularly (noise on the cosmetic stream, seeded from the tick). `reduced_motion`: one pulse, no jitter, a plain fade.

## 9. Legal's conditions (in the data as `legal_rules`)

Legal screened the set (`docs/legal/q3-screen.md`) and Art applied the conditions in the data, so Rendering reads them and does not hard-code them:
- **Round tips** for the Anti-hero's `pride`, `triumph`, `surge` and `danger` (`legal_rules.round_tip.A`): the same triangle with a rounded end (radius `0.95 * half-width`). His rage stays pointed.
- **Wide, low crest** for the Empress's `pride`, `triumph`, `surge` and `resolve`, and the Anti-hero's `surge` (`legal_rules.low_crest`): the angle `a` becomes `atan2(sin(a) * 0.4, cos(a))` plus 42 degrees, the size times 0.7, the distance plus 4. Ground shards are unchanged.
- **Danger sense is a pointer train**: three shapes along one ray, default angle 132 degrees. Rotate the whole train to the threat's bearing (the facing frame), clamped to 65 to 175 degrees, so it is always above or behind the head. Never radiate it around the head.
- **`F8` shows the legacy shapes** (tall pointed blades and wedges, the radiating danger fan is gone for good) so Orb can compare before and after. It is a uniform (`legacy`), off by default.

## 10. Performance

At most two draw calls per fighter, both hidden when idle (`visible = false`, zero cost). No textures, no per-frame allocations, under 0.05 ms per frame with a flash up. The web build must not lose its frame time (Performance's check).

## 11. What Orb should judge, and the checks

**Orb judges:** does each flash read at a glance and go away in time, do they get in the way of the fight, do the info flashes help, and is anything too loud or too quiet.

**Acceptance:**
1. At rest, no flash is drawn, and nothing changes in the frame.
2. Each of the thirteen fires from its debug key, with the timing in the table (within a frame), and is gone by its total time.
3. Priority and arbitration behave as in section 7: a heavy hit during a taunt cancels the taunt in 0.1 s, a crown pop drops a waiting flash, the surge preempts everything.
4. The flash mirrors with the fighter when it swaps sides, and never covers the head, the chest or the sigil area.
5. The gameplay hash is identical with the prototype on and off, at seeds 12345 and 4, and the determinism negative control still fails when a fighter is nudged.
6. Frame time with all four flashes up is within noise of the greybox baseline, on desktop and web.

## 12. Dependencies and open questions

- **Rendering:** the cheat-out staging (in progress) and the hybrid projection are needed first.
- **UI:** the `crown_up` callback, and the crown changes suggested in `marked-aura.md` (pop only for wear, stay down during a cinematic).
- **Audio:** cue ids for the thirteen flashes (words are in `flashes.json`).
- **Encounter and Game Design:** events for danger sense (ambush, telegraph), searching (lock lost, hunting), taunt, pride (a decisive exchange won) and the drop-act family.
- **Open:** should the prototype also draw the sigil on the greybox head, so Orb sees a flash and a mark together? It is cheap (a decal on the head) and I recommend it as a second step.
