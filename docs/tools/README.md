# Tools: CI, setup and the web build

Owner: Tools and Pipeline. Free GitHub-hosted runners only, no secrets beyond the built-in Pages token permissions, no paid services.

## One-command setup

From a fresh clone:

| System | Command |
| :--- | :--- |
| Windows | `tools\setup.cmd` (wraps `tools/setup.ps1` and bypasses the execution policy for that one run) |
| Linux, macOS | `sh tools/setup.sh` |

It checks, in order:

1. **Node** (required). Missing or older than 18: it stops with exit 1. Any major other than 24 gives a warning, because the golden hashes were recorded on Node 24.19.0 and are skipped on other majors (ADR 0004), so a pass proves less.
2. **npm** (required, ships with Node).
3. **Godot** (optional today). Looks for `$GODOT`, then `godot` and `godot4` on the path (Windows also tries the `Godot_v4.7.2-stable_win64*.exe` names). Warns if it is missing, is not 4.7.x, or is the .NET build (ADR 0001: standard build, GDScript).
4. **npm dependencies**: `npm ci` in the root, `prototype/`, `sim/` and `qa/`, only where a `package-lock.json` exists. Today only `prototype/` has one: it installs `@napi-rs/canvas` 1.0.9 (optional, MIT), which `prototype/tools/screenshot.js` needs to write a real PNG. The suites do not need it.

Exit 0 means ready, warnings allowed. Exit 1 means a required tool is missing or an install failed. Then run `node qa/run-all.js --quick` (about 40 s) or `npm test --prefix sim`.

## Data validation

`node tools/validate.js` checks every data file against its JSON Schema (draft 2020-12) and then the cross-references between files. Node built-ins only, no install, deterministic (no clock, no random), about half a second.

| Command | What it does |
| :--- | :--- |
| `node tools/validate.js` | Everything under `data/`, `audio/data/` and `ui/data/`, plus the cross-references. Exit 0 if there are no errors (warnings allowed; a missing or empty data folder is fine), 1 on any error, 2 on bad usage |
| `node tools/validate.js <paths>` | Only those files or folders, schema and lint checks only. Add `--xref` for the cross-references too |
| `node tools/validate.js --self-test` | Proves the validator can fail, and on the right rule (see below) |
| `node tools/validate.js --list` | Prints the folder-to-schema map |

Every finding names the file, the line, the JSON pointer and the rule, for example `error  data/combat/finishers.json:155 /finishers/3/beats/8/args/bark  [type] must be string (got boolean)`. A JSON file in a folder with no schema (for example `data/director/`) gives a warning, not a failure.

**What is checked**
- **Per file:** it must be strict JSON (no comments, trailing commas, byte-order mark), with no duplicate key in one object (`JSON.parse` and Godot silently keep the last) and no number with more than 15 significant digits (so JavaScript and Godot read the same double; `docs/architecture/d1-roster-data.md` section 4). Then the schema.
- **Schemas** (`tools/schemas/`, one per data family, listed in `map.json`): each has a version field (`schema` or `version`, pinned by `const`) and states its policy in its description. The policy everywhere: objects are closed (an unknown key is an error) except keys starting with an underscore, which are comments and are ignored by the canonical data hash; free-form synth or option tables are open with typed values.
- **Cross-references** (`tools/lib/xref.js`), each an error unless noted:

| Rule | Checks |
| :--- | :--- |
| `finisher-key`, `finisher-id` | `select.byFighter` and `fallback` name real finishers; finisher ids are unique; a fighter's `finishers.*` keys exist (a finisher owned by another fighter is a warning) |
| `cue` | every `cue` beat in templates and authored finishers uses a cue in `finishers.json` `cues` |
| `selector-branch`, `template-id`, `branch-id` | selectors point at branches of their own template; ids are unique |
| `flash-audio`, `flash-rank`, `flash-held`, `flash-id` | every active flash in `data/art/flashes.json` has an audio cue and a rank in `cues.json`; every audio cue is an art flash; held flashes are marked held; legal rules name real flashes |
| `flash-pulse`, `flash-duration`, `flash-total`, `flash-priority` | audio pulses equal Art's, `max_s` equals Art's `total`, `total = count x on + (count - 1) x off + fade`, active priorities are unique |
| `flash-keep-out` | active flash shapes sit inside Art's `keep_out` angles (ground shards exempt) |
| `effects-haze`, `effects-family`, `effects-lightness` | in `data/art/effects.json`: the fire-range swap rim is the haze colour and names real families; glass light and mid have L* above 80, steel mid and shadow below 40 |
| `tempo-name`, `dynamic-beats` | a tick's `add`/`sub` names and `{ticks: name}` durations are keys of that profile's `tempo`; with the `dynamic` profile active every branch and the chain link has dynamic beats |
| `voice`, `bus`, `sound` | voices, buses and impact sounds named in `cues.json` and `flash_cues.json` exist (a voice not yet synthesised is a warning) |
| `babble-onset`, `babble-vowel`, `babble-syllable`, `babble-timbre`, `babble-mood`, `babble-gesture` | in `babble.json`: syllables use real onsets and vowels, lexicons use real syllables, moods use real timbres, `mood_map`, `voice_moods` and `styles` name real babble moods, cue and punctuation gestures exist in `grunts.json` (a voice's own `laugh` counts); `babble_captions.json` moods are babble moods or mapped Narrative tags; babble voices and caption voices exist (`voice`) |
| `effects-deutan` | Art's deuteranopia contrast table for the embers is recomputed from the hex values (Machado severity 1.0, WCAG contrast, best of step and rim per ground) and must match to 0.01 and stay at or above the 3.7 its result line promises |
| `style-id`, `style-template`, `style-bands`, `style-clash-order`, `style-finisher`, `style-fighter`, `style-tempo-name` | in `data/combat/styles.json`: style ids are unique; `appliesTo` names real templates; altitude and mood bands tile; the clash `order` lists every shape once; telegraph kinds name real finishers or fighter shapes and every kind has a cue; trait owners are real fighters; tempo names used in beats, `blitz.gap` and `cadence.linkGap` exist |
| `feel-order`, `feel-cap`, `feel-encore`, `feel-hitstop-budget`, `feel-ticks-only` | in `data/input/feel.json` (Controls' rules): `triggerOff < triggerOn`; a funded signature does not outlive an unfunded one; the Encore confirm fits its offer; no hit-stop above 30 ticks; no key in seconds. `feel-hitstop-order` (the impact hierarchy) is a warning |
| `mood-bands`, `style-priority`, `style-hysteresis`, `style-window`, `style-measure` | in `data/fight/mood.json` and `style.json` (drafts): band thresholds and hysteresis order correctly; every style label is in `priority`; `leavePct` is below `enterPct`; holds fit the window; a measure names known counters |
| `anim-bone`, `anim-pose`, `anim-role`, `anim-pick`, `anim-profile`, `anim-cue` | in `data/anim/` (render only): pose fk bones exist in `bone_lag`; key-set and cue poses exist in `poses.json`; a role appears once per key set; picks are key sets; the default profile exists; each cue is in the cue vocabulary of `finishers.json` |
| `hash-render`, `hash-anim-read` | the replay data hash covers only `templates.json`, `finishers.json` and `data/fighters/**`: no `render` block may appear in them, and no sim file may mention `data/anim` |
| `actions-id`, `actions-value`, `actions-layer` | in `data/input/actions.json` (ADR 0008): action ids are unique; layer and gesture actions carry a value, layer actions a layer |
| `layout-action`, `layout-device`, `layout-required`, `layout-conflict`, `layout-layer`, `layout-pair`, `layout-reserved`, `layout-default`, `layout-axis`, `layout-id` | in `data/input/layouts.json` (Controls' eight rules plus unique preset ids): bound actions exist; a control's device prefix matches the preset's; each preset binds every required action; no control carries two actions on one layer (gestures and chord parts exempt); layered bindings need `power` and may only be special, signature or upgrade; a pair points back, has players 2 and shares no control; no reserved keyboard key (N, T, Y, P, Escape, F-keys); exactly one default per device; a keyboard move has four controls and an axis |
| `timing-order`, `timing-perfect`, `timing-hold`, `timing-hitstop-budget` | in `data/input/timing.json`: `triggerOff < triggerOn`; perfect-block windows within the authored tells (15 and 20); `encoreConfirm <= transformConfirm < encoreOffer`; no hit-stop above 30 (an unfunded signature is refused at once, so there is no expiry rule). `timing-hitstop-order` is a warning |
| `bars`, `stance`, `places`, `profile`, `option-default` | score arrays match `bars`; stance ids and texts agree; places tile the planet; aliases name real profiles; option defaults sit in their range or choices |
| `settings-option`, `settings-needs`, `settings-duplicate`, `settings-labels`, `settings-section`, `settings-unlisted` | every Settings item, `needs`, `hidden` and `labels` entry names a real option; every `needs` names a flag in features.json; no option is listed twice or both listed and hidden; label words are real choices; section ids are unique; an option on no screen and not hidden is a warning |
| `vfx-water-range`, `settings-remap` | data/vfx/water.json min/max pairs are not inverted; the Remap words (settings.json `remap`, or the older `_remap`) name real presets in layouts.json, real actions in input actions.json (a non-touch preset with no name is a warning); each sentence keeps its {tokens} (schema pattern) |
| `vfx-transform-range`, `vfx-transform-beats` | data/vfx/transform.json: the ring starts smaller than it ends; the beats agree with data/anim/forms.json (a mismatch is a warning) |
| `vfx-react-range` | data/vfx/react.json: each min is at most its max (rubble rise, life and size; window floors; speed-line length and gap) |
| `vfx-earth-range` | data/vfx/earth.json: each min is at most its max (debris and flame size and life, flame rise, landing chunk size) |
| `vfx-power-range`, `vfx-power-tier` | data/vfx/power.json: each min is at most its max (rock radius, height, drift, size, count by tier; blast scale, ring, settle and chunk size; pressure ring radius); pressure rest_bh is below fast_bh; a count above the 12 pieces rocks.gd keeps, and a tier multiplier that falls with the tier, are warnings |
| `pause-ticks`, `pause-order` | data/fight/pause.json: every length and gap is a whole number of ticks (60 a second); the bank starts at most at its cap; short length is below full length, which is at most the final length; the short gap is at most the full gap; a length above the bank cap is a warning |
| `forms-pose`, `forms-hold`, `forms-pause-sum` | data/anim/forms.json: each beat's pose is in poses.json; hold is at most settle; the full and short versions' gather + break + settle equal their pause in data/fight/pause.json in ticks (live is free) |
| `ragdoll-id`, `ragdoll-bone`, `ragdoll-limits` | data/anim/ragdoll.json: dof ids are unique; bone and bone2 are in profiles.json bone_lag; share goes with bone2; lo is below hi; k_loose is at most k_stiff; tuck, brace and tsg inside lo..hi (a warning); a0 at most a_max; tuck_spin and brace_time rise |
| `quality-order`, `personality-tiers` | data/anim/quality.json: each level (high, medium, low, minimal) switches off at least what the one above does, and every layer is one of the ten (schema). data/anim/personality.json: a higher tier is calmer (a warning if sway, hz, bounce or breath_hz rise, or breath_amp falls) |
| `winner-shape` | data/anim/winner.json: every `end` key other than `default` is a shape key in ragdoll_motion.json shapes |
| `moments-id`, `moments-pose`, `moments-marks` | data/anim/moments.json: moment ids are unique; every pose is in poses.json; Legal's stacking rule: a moment with three or more of the seven marks is an error, with two a warning |
| `lint-allow-pose`, `effector-pose` | data/anim/lint_allow.json and effectors.json: every pose is in poses.json (an overlay prefix that matches no pose is a warning) |
| `sockets-bone`, `sockets-reach`, `anim-target`, `anim-limb` | data/anim/sockets.json: every bone is in profiles.json bone_lag (with an _l or _r suffix for a sided limb); lunge_max is at most step_max; every key set `target` is a region and every key set `limb` is a limb (without its side) |
| `shapes-key` | data/anim/shapes.json: every shape key is in ragdoll_motion.json shapes (a shape there with no entry here is a warning) |
| `joints-bone`, `joints-order`, `joints-shape` | data/anim/joints.json: every joint bone is in profiles.json bone_lag and in one joint only; a hinge's min is below its max (and is -give_deg, a warning); a twist range rises and the straight twist is at least as wide; straight_below_deg is below bent_above_deg; every shapes key is `default` or a shape in ragdoll_motion.json (a shape with no scale is a warning) |
| `targets-pose`, `targets-limb` | data/anim/targets.json: every pose is in poses.json or a wave's poses file; a strike's contact pose does not retarget the hand or foot that lands the blow (the key set's limb or limb2) |
| `agency-pose`, `agency-seq`, `poles-pose` | data/anim/agency.json: every held pose is in poses.json or a wave's poses file and every sequence is in a wave's sequences file; data/anim/target_poles.json: every pose is in a pose file |
| `flight-order` | data/anim/flight.json: each (from, to) pair (speed, spin, steep, lay) rises |
| `ground-surface`, `ground-order` | data/anim/ground.json: surface has a multiplier for each of the five surfaces of data/biomes/contact.json (plus optional `water`, nothing else); paving and rock are not below soil and sand and rubble not above it (warnings) |
| `intro-shape`, `intro-seq` | data/anim/intro.json: every beat shape key is in ragdoll_motion.json shapes; every beat sequence is in data/anim/waves/intro1.sequences.json |
| `laststand-shape`, `laststand-seq` | data/anim/laststand.json: every ready key is `default` or a shape in ragdoll_motion.json shapes; every ready sequence, and ls.slump, is in data/anim/waves/laststand1.sequences.json |
| `intro-order`, `intro-staredown`, `wounds-last-stand` | data/fight/intro.json: each fall is before its landing, A lands no later than B, B lands by the staredown, the staredown is before the clock, skipFrom is before the clock (the loader checks the same); data/anim/intro.json: tense_lead and each beat fit in the staredown (warnings); a fighter's lastStand.windowS is a whole number of ticks |
| `shots-lob`, `shots-order` | data/fight/shots.json: a kind has lobTicks and lobArc together (lobTicks longer than lifeTicks is a warning); a kind that trades with more power does not do less damage (a warning) |
| `wave-pose`, `wave-keyset`, `wave-manifest`, `wave-reach` | data/anim/waves/<wave>.*.json (parked strike waves, validated as live data): every key set pose and manifest pose is in the wave's poses file; every manifest strike is a key set of the wave and agrees with it (limb, limb2, target, weight); ids are unique; offset is at most reach; the target and limbs are in sockets.json (`anim-target`, `anim-limb`) |
| `wave-entry` | data/anim/waves/<wave>.entries.json and .entrymap.json: every entry phase pose and every map pose is in the wave's poses file (`wave-pose`); every map row is an entry of the wave and agrees with it (direction, ground, path, poses, start and arrive ticks); the map's phase names match its poses; ids are unique; an entry with no map row is a warning (variants excepted) |
| `wave-live-keyset`, `wave-live-weight`, `wave-live-shape` | data/anim/waves/<wave>.live.json: every picked and gated key set is in the wave's keysets file; a pick list holds key sets of its weight (or `any`); a gated key set has the weight it is gated into; a gated key set that is also picked is a warning; every shape is in ragdoll_motion.json shapes |
| `wave-seq-dur`, `wave-cue-seq`, `wave-seq-map` | data/anim/waves/<wave>.sequences.json, .cues.json and .seqmap.json (step 3 cue sequences): every phase pose and map pose is in the wave's poses file (`wave-pose`); a sequence's fixed phase ticks fit in its dur; every cue names sequences of the wave; every map row is a sequence of the wave and agrees with it (dur, poses), its phase names match its poses, and its cues equal the cues file's; a sequence with no map row is a warning (variants excepted) |
| `ragdoll-motion-dofs`, `-shape`, `-limits`, `pause-gather` | data/anim/ragdoll_motion.json: per-dof arrays and hit.dofs match ragdoll.json in length and order; each fighter names a shape that exists; shape angles inside each dof's lo..hi (a warning). data/fight/pause.json: gatherTicks is under the length in ticks, and a mismatch with the forms.json gather beat is a warning |
| `strike-lead` | every dynamic strike beat is scheduled at least 6 ticks after its list starts, taking an approach-anchored beat at the shortest approach (approach.min) |
| `launch-order`, `launch-direction` | data/director/launch.json: the drive's lowDeg is at most highDeg and lowBh is below highBh; CRATER SLAM's uy is negative (a warning if not); knockBack distBh and skidSpeed do not fall with the tier (warnings) and UPPERCUT's uy is positive (an error if not) |
| `timing-read` | data/input/timing.json `read` (the press reader): rhythmNeed is at most rhythmOf; mashPresses, mixShort and rhythmOf are at most logSize; mashGap is at most mashClear and mashClear at most staleTicks |
| `contact-order`, `contact-surface` | data/biomes/contact.json: nothingBelow below tumbleBelow; skidSin2 below slamSin2; each bounce keeps less than the one before; bounces and spin caps do not fall with the tier (warnings); every biomeSurface value is a surface and every paving biome has a biomeSurface; `contact-area`: area.touch above area.slam is a warning |
| `blast-kind`, `blast-tier` | data/biomes/blast.json: every shot kind of data/fight/shots.json has an entry in kinds (a warning); tierEnergy and tierDamage do not fall with the tier (warnings) |
| `ai-level`, `ai-levels-order`, `ai-level-beam` | data/director/ai.json: `level` is one of `levels`; a harder level does not play worse on beamAnswer, perfectBlockMul, punish, breakGuard, guardRepeat, launchIntent, heldHeavy, earnerUse, buriedFollowUp or barrageGuard (a warning); the old top-level beamAnswer is the medium level's (a warning) |
| `buried-order` | data/director/interrupts.json buried: guardFromTick and burstFromTick are at most the embed ticks of data/biomes/contact.json and at most landByTick |
| `launch-setup` | data/director/launch.json setup.weight: a key that is not a decisive kind (launch, clash, guard_break, interrupt, knockback, beam, beam_clash, blast, barrage), default, blurPlain or barragePlain is a warning (it would never be read) |
| `blast-shot-kind` | data/director/interrupts.json blast: the light and heavy kinds are shot kinds of data/fight/shots.json; a heavy kind that trades with less power than the light one is a warning (and holdMaxTicks below chargeTicks is an `interrupts-order` error) |
| `bands-order` | data/director/interrupts.json bands (the ranged press): engageBh is at most closeBh, closeBh is below midBh, each approach's minTicks (lunge, far, charge, meet) is at most its maxTicks, and the light charge's holdTicks is below the heavy's |
| `ai-approach-react` | data/director/ai.json: each level's three approachReact chances sum to at most 1 |
| `interrupts-order`, `interrupts-window` | data/director/interrupts.json: a light window is at most its heavy window; oneArmedOff leaves every window a tick; kiPatient is at most ki; the stale maximums are at least one repeat's step; the free cancel's freeGapTicks is at most cooldownTicks (a warning); a perfect-block window is not longer than the wind-up it ends (a warning) |
| `ladder-reach-order` | a fighter ladder's reach.structure does not fall with the tier (a warning) |
| `faces-expression`, `faces-fighter`, `faces-priority` | ui/data/faces.json: default_expression, every gesture_expression value and every fighter's expressions are in expressions; every fighter id is `default`, a readout profile or an alias; min_priority is at most always_priority |
| `damage-fighter`, `damage-silhouette` | data/art/damage.json: fighter ids are readout profiles; stage 3 changes a silhouette piece (a warning if not) |
| `auras-hue`, `auras-white` | data/art/auras.json (Legal's aura rule): hue_range, every form's stated hue and every colour's own hue sit in 260 to 320; an aura core and a flash light are at most L* 86; no colour is pure white (L* 97 or more) |
| `barks-id` | data/narrative/combat_barks.json: every line id is unique across shouts, taunts, On the Chin and the last stand |
| `hints-fix-key`, `hints-fix-length` | data/narrative/hints_fix.json: every key is a hint in ui/data/reads.json and its beat is in beat_ids; a line over twelve words is a warning |
| `fighter-id`, `roster-id`, `increasing`, `family-weights`, `fighter-files` | a fighter's id equals its folder and is unique; every roster id has a `fighter.json`; wound stages and ladder thresholds strictly increase; family weights match the region count; each fighter has `wounds.json` |

**Input schemas (ADR 0008, `docs/controls/input-schema.md`).** `input-actions`, `input-layouts` and `input-timing` are adopted for `data/input/`; the files do not exist yet, so the self-test uses the proposal's samples as neutral fixtures (`tools/fixtures/virtual/data/input/`). `input-feel` and `data/input/feel.json` stay mapped until Controls removes that file (timing.json supersedes it). The player's `user://input.json` is not in the repo and has no schema here. Three places where the proposal contradicted its own samples, resolved as follows (Controls to confirm): (1) the Simple presets reach heavy and signature through the `upgrade_heavy` and `upgrade_sig` gestures, so those count as binding them; (2) keyboard presets bind no `pause` (its keys are reserved), so `pause` is required for pad and touch only; (3) no touch preset had `default: true`, so the fixture marks `touch-simple` default (`layout-default` needs one per device).

**Draft schemas, fight level.** `fight-mood` and `fight-style` are drafts from `docs/architecture/mood-style.md` and Narrative's `docs/narrative/style.draft.json`; the data lands with Simulation's M1, whose commit tightens them. `combat-styles` is written from the file (design data, not yet loaded), so its overlays and chain beat lists are open objects until the loader lands. `input-feel` is Controls' proposal (`docs/controls/feel-schema.md`) adopted as written, with one fix: the hit-stop map takes underscore comment keys like every other object. Its underscore idiom (`additionalProperties: false` beside `patternProperties: {"^_": true}`) is exactly how every schema here expresses "closed except underscore keys"; the engine has no flag or keyword for it. For folders whose data does not exist yet (\`data/fighters/\`, \`data/fight/\`, \`data/input/\`) the self-test uses neutral fixtures under \`tools/fixtures/virtual/\`.

**Fighter schemas (D1a as built).** `fighter`, `fighter-wounds`, `fighter-meters` and `fighter-roster` follow `docs/architecture/d1-roster-data.md` sections 3 and 7b and validate the real `data/fighters/` files: wounds are closed with the ten penalty keys, the stricter brink (`brinkLimbs`), the act-1 damping and the overtime ramp; meters have the anguish and menace shapes (sources casualty and evacuee, four effect keys with the fields each needs); a fighter's identity carries Narrative's six optional keys (tagline, blurb, voice_device, voice_bible, pronoun, placeholder); the roster is a bare array or {"schema": "roster/1", "order": [...]}. `fighter-ladder` is still a draft (D1b guesses its field names). A new key in any of these files needs its schema line in the same commit.

**Self-test** (`tools/lib/selftest.js`, about 300 checks): the strict parser agrees with `JSON.parse` on every data file; every schema keyword the engine supports passes and fails as it should (`tools/fixtures/engine-cases.json`); every schema file uses only supported keywords, resolves its `$ref`s and is used; and about 90 invalid-data cases (`tools/fixtures/cases.json`) each mutate real data and must produce the named finding, at the named pointer, that the unmutated data does not. Every schema must have a valid document and at least three invalid cases. Fighter data does not exist yet, so the self-test uses neutral fixtures (`tools/fixtures/virtual/data/fighters`: `FIXTURE_HERO`, `FIXTURE_VILLAIN`) and ignores any real `data/fighters`. If a case fails with "fixture path missing", the data's shape changed: update the case.

**Engine.** `tools/lib/schema.js` is a small validator of our own that implements only the keywords the schemas use and rejects a schema that uses any other, so a constraint can never be silently ignored. The trade-off against a library such as ajv: no dependency, no install step, no lockfile, no Legal register row, and it is trivial to keep identical on any runner; the cost is that we maintain about 250 lines and a new keyword needs a line of code and a test case. It is JavaScript, not GDScript: it runs in CI without downloading Godot. The loaders' own checks stay in GDScript.

**Adding or changing a schema**
1. Write `tools/schemas/<name>.schema.json` (draft 2020-12, a version field, a "Policy: ..." sentence in the description).
2. Add a rule for its files to `tools/schemas/map.json` (first match wins).
3. Add at least three invalid cases to `tools/fixtures/cases.json` (and a virtual valid document under `tools/fixtures/virtual/` if no real data exists).
4. Cross-references go in `tools/lib/xref.js`, with a case each.
5. Run `node tools/validate.js --self-test` and `node tools/validate.js`.

Data files are owned by their directors; the validator reports problems and never edits data.

## CI

`.github/workflows/ci.yml` runs on every push, pull request and manual run, on the pinned image `ubuntu-24.04` (not `ubuntu-latest`, so a GitHub image migration cannot change a result without a commit):

| Job | Runs | Time |
| :--- | :--- | :--- |
| `qa` | `node qa/run-all.js` (Node 24.19.0) | about 35 s |
| `sim` | `npm test --prefix sim` (Node 24.19.0) | about 1.5 min |
| `data` | `node tools/validate.js --self-test`, then `node tools/validate.js` (Node 24.19.0): schemas and cross-references | a few seconds |
| `godot-parity` | Godot 4.7.2 headless: import, GDScript parity, render determinism, render seam sweep | about 1 min |
| `site` | Godot Web export, then assembles the Pages site (`tools/build-site.mjs`) | about 2 to 3 min (the 1.28 GB templates download dominates) |
| `deploy` | Publishes the site to GitHub Pages. Only on push (or manual run) on `main`, and only after the five jobs above pass | seconds |

The first five run in parallel. Two of them use Godot (`godot-parity` and `site`); the cap is six. There are no npm install steps because the suites use Node built-ins only; CI runs without `@napi-rs/canvas` and the golden hashes match with and without it (the runner never calls `render()`). Add `npm ci` (with a lockfile) the day a suite grows a dependency.

Settings: `permissions: contents: read` (only `deploy` adds `pages: write` and `id-token: write`, the built-in Pages token permissions), no secrets, `persist-credentials: false` on checkout, a timeout on every job. A newer push cancels an older run of the same branch, except on `main`, where every run finishes so a deploy is never cut off.

### Pinned actions

| Action | Version | Commit SHA |
| :--- | :--- | :--- |
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-node` | v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` |
| `actions/upload-pages-artifact` | v5.0.0 | `fc324d3547104276b827a68afc52ff2a11cc49c9` |
| `actions/deploy-pages` | v5.0.1 | `368f82528645a54fb793d4d04e342629a3f51346` |

All are first-party GitHub actions. To bump one, look up the tag's commit (`gh api repos/actions/checkout/git/ref/tags/<tag>`; if the type is `tag` rather than `commit`, follow it once more), replace the SHA and the version comment together, and update this table.

### The Godot jobs and the pinned download

Both Godot jobs use the local action `.github/actions/setup-godot`, so the pin lives in one place. It downloads the official Godot 4.7.2 Linux build (standard, not .NET) from the GitHub release and verifies its SHA-512 (from the release's `SHA512-SUMS.txt`) before running it, then sets `GODOT`. With `web-templates: 'true'` it also downloads `Godot_v4.7.2-stable_export_templates.tpz` (1.28 GB), verifies its SHA-512, and unpacks only the single-threaded Web templates (`web_nothreads_release.zip` and `_debug.zip`, about 20 MB). Nothing binary is committed. To bump Godot, change the version and both checksums together in that file and update this page.

`godot-parity` runs, from the repo root (`project.godot` is there): `--import` (registers the `class_name` scripts on a fresh clone), then `sim/core/tools/parity.gd`, `render/tools/determinism.gd` and `render/tools/seam_sweep.gd -- --size=1280x720`. Each exits 0 on pass. The `.godot/` import cache is created on the runner only (it is in `.gitignore`). The `sim` job does not set `GODOT`, so `npm test --prefix sim` skips its own godot stage there and the parity check runs once.

### Web export and the Pages site

`export_presets.cfg` (repo root) holds two presets:

- **Web**: Compatibility renderer (from `project.godot`), single-threaded, no extensions, so it needs no cross-origin isolation and runs on GitHub Pages as it is. Default output `build/web/index.html`.
- **Windows Desktop**: x86-64, pck embedded in one `.exe`, default output `build/win/orb-combat-ex.exe`. Not built in CI. The engine's Windows export template is in the same 1.28 GB download, so adding it later is a small change.

Both exclude `prototype/`, `qa/`, `research/`, `docs/`, `tools/` and `.github/` from the pack. Locally (with the 4.7.2 export templates installed):

```
godot --headless --path . --import
godot --headless --path . --export-release "Web" build/web/index.html
node tools/build-site.mjs --web build/web --out build/site
```

The `build/` folder should be in `.gitignore` (the EP's file). Serve `build/site` with any static server to try it; the web pack was about 0.6 MB and the wasm 39.5 MB (about 10 MB gzipped, which Pages applies).

**Build info for the feedback report.** `node tools/write-build-info.mjs` writes `build_info.json` at the repo root (`res://build_info.json`) as `{"commit": "<sha7>", "date": "<yyyy-mm-dd>"}`: the commit from `--commit`, then `GITHUB_SHA`, then `git rev-parse`, and the date is that commit's own date (`git log -1 --format=%cs`), never the clock. With no git it writes `"unknown"` and still exits 0, so a local build without git does not break. CI runs it before the web export. The export presets pack it through `include_filter="build_info.json"`; an export without the file still succeeds (the game must treat a missing file as unknown, as it does in the editor). The file is not under `data/`, so the sim hash never sees it, and `/build_info.json` must be in `.gitignore` (the EP's file). For a local web export, run the script first.

`tools/build-site.mjs` lays out the site: `/` a small landing page, `/prototype/` the single-file prototype (the URL Orb shares, unchanged), `/play/` the Godot build, and `/bench/` (below), which the landing page does not link. It fails if the export folder has no `index.html` and `.wasm`.

**The band prototype at `/band/`.** Research's option B prototype (`research/band-proto`, a standalone Godot project with its own export preset) is exported in CI and hosted at `/band/` with `build-site.mjs --band <dir>`. When its engine files (`index.wasm`, `index.js`) are byte-identical to `/play/`'s (the same Godot 4.7.2 and web templates) the site ships only its `index.html` (patched to load the engine from `../play/` and its own `mainPack`) and its `index.pck` (about 37 KB), so there is no second 39.5 MB wasm; otherwise the whole export is copied. It is a throwaway page: not linked from the landing page, and never validated or run through the sim checks (the validator scans only `data/`, `audio/data/` and `ui/data/`).

### The bench page and the old-laptop range

**`/bench/` (one click, the real number).** `https://dixonbalsagna.github.io/orb-combat-ex/bench/` runs the same web build (loaded from `/play/`, so the site carries one copy of the 39 MB wasm) with the bench arguments baked in: fixed 60 Hz steps, seed 4, 2400 frames, vsync off. It shows a results panel and a "Copy result" button; the copied text holds every bench figure (frame ms mean, p50, p95, p99, max, draw calls, sim tick), the build (short commit), the browser, cores, memory, screen, window and the unmasked WebGL renderer. Someone with an old laptop opens the link, leaves the tab visible for a minute or a few, and pastes the text back. It is not linked from the landing page and is marked noindex. Options in the URL (combine with `&`): `?nosplit`, `?novfx`, `?noragdoll` (the animation overhaul off), `?noclouds` (the sky bare), `?anim-quality=high|medium|low|minimal` (an animation quality level; any other value is ignored), `?frames=N`. `build-site.mjs` fails the build if the Godot page template changes shape (it patches the exported `index.html`), so a Godot upgrade cannot silently ship a broken page.

**Keys while the canvas has lost focus.** The export preset's `head_include` also holds a small `keydown` guard: when the canvas is not the target (the player clicked the page around it), the space bar, the arrow keys, Page Up, Page Down, Home and End no longer scroll the page. It leaves alone any key with Ctrl, Alt or Meta held (browser shortcuts), and any key typed in an input, textarea, select, button or link (so the bench page's Copy button still works from the keyboard). It takes effect at the next web export.

**`tools/bench-web.mjs` (a range on your own machine).** It serves a built site (`--dir`) or takes a URL (`--url`), and runs the `/bench/` page in fresh Chrome or Edge profiles: an unthrottled baseline, then each `--cpu-throttle` factor (default 4,6) using Chrome's CPU throttle, and with `--floor` a software-rendering (SwiftShader) run. It prints a table and a range, and writes every run to `--out` as JSON. About 4 minutes for baseline, x4, x6 and the floor at 1200 frames.

```
node tools/build-site.mjs --web build/web --out build/site
node tools/bench-web.mjs --dir build/site --cpu-throttle 4,6 --floor --frames 1200 --out build/bench.json
```

Read the result as a range, never a measurement. The throttle slows the browser's CPU work (the wasm simulation and the engine building draw calls), which is the likely limit for this game, but not the GPU, memory or a hot laptop; SwiftShader is a GPU-free floor far worse than any real laptop. First run (2026-09-29, Ryzen 7 9800X3D, Chrome 154, 1366x768, 1200 frames): baseline 3.1 ms mean (p95 3.8), x4 10.3 (p95 16.3), x6 17.3 (p95 26.2), SwiftShader 145. So a machine six times slower on the CPU side would miss a 60 fps frame at p95; the real old-laptop number from `/bench/` decides whether that is a worry.

### Switching Pages to GitHub Actions (a repo setting)

Today Pages is "Deploy from a branch" (`main`, `/`), served by GitHub's own `pages build and deployment` workflow. The `deploy` job cannot publish until the source is "GitHub Actions". The exact change:

- Web: repository **Settings, Pages, Build and deployment, Source**: change "Deploy from a branch" to **GitHub Actions**.
- CLI: `gh api -X PUT repos/dixonbalsagna/orb-combat-ex/pages -f build_type=workflow`

Order: push the workflow first (the tests and `site` job run; `deploy` fails harmlessly while the source is still a branch and `/prototype/` keeps serving). After Orb agrees, flip the setting, then re-run the failed `deploy` job (or start CI by hand on `main`) so the site goes live at once. The site then serves only `/`, `/prototype/` and `/play/`: other repo files that the branch source used to publish at their paths (for example `/docs/...`) are no longer served. Switching back is the same setting in reverse.

### What is and isn't proven

- **Proven on GitHub:** `qa`, `sim` and `godot-parity` (parity only, before the render checks were added) have passed on `ubuntu-latest` (before the runner pin to `ubuntu-24.04`, the same Linux family), so the golden hashes hold across OSes.
- **Proven locally only:** the render checks (determinism 11 s, seam sweep 1 s), the Web and Windows exports, and the assembled site (loaded in a browser: title "Orb Combat EX", the greybox match runs). The template download and unpack, the Pages artifact and the deploy have not run on GitHub yet; the first run on `main` is the proof.
- **Branch protection** is available (the repository is public) but not needed while only the EP commits.

## Held for now

CONTRIBUTING.md, the pull request template and any licence field or licence check are on hold while Orb reconsiders the licence.
