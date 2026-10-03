# Everything waiting for Orb, and where it is

Written by the EP on 2026-10-01. Paths are from the project folder. The fuller state of the build is in docs/ep/status-2026-10-01.md.

## Play and watch

- The game: https://dixonbalsagna.github.io/orb-combat-ex/play/
- The opening (entrance and staredown), off by default: https://dixonbalsagna.github.io/orb-combat-ex/play/?intro=1 . Decide whether it becomes the default.
- Two-controller test checklist: docs/controls/local-two-player.md. Phone checklist: docs/controls/phone-test-checklist.md. Old-laptop benchmark: /bench/ on the live site.

## Sound

- Music, three 30 s sketches to choose from by ear: audio/preview/sketch-a-town-band.wav, sketch-b-furnace.wav, sketch-c-kitchen-drums.wav. The pitch behind them: docs/audio/direction.md section 3.
- Fighter voices (babble): audio/preview/babble-protagonist.wav, babble-anti_hero.wav, babble-empress.wav, babble-cyborg.wav.
- Grunts, two versions each: audio/preview/voice.protagonist.*.wav and voice.anti_hero.*.wav. Notes: docs/audio/grunts.md.
- Impacts, two versions each: audio/preview/impact.light, impact.heavy, impact.crater (v0 and v1).
- Face cut-in stings: audio/preview/flash-circles-*.wav.
- How to hear them in the engine: audio/README.md.

## Art

- Close-up faces, the three directions (A and B are the mask directions Orb has now parked): art/concepts/closeups/closeups-comparison.svg, others-C.svg, anti-hero-C.svg. Notes: docs/art/closeup-directions.md.
- Faces and portraits: art/concepts/faces/faces-1-anti-hero.svg, faces-2-others.svg.
- Silhouettes: art/concepts/silhouettes/ragdoll-silhouettes.svg.
- Turnarounds: art/concepts/turnaround/ (cyborg, empress, protagonist, coil). Notes: docs/art/cyborg-turnaround.md and the others beside it.
- Coming: the refinement sheets, Cyborg first, in art/concepts/refine/ (README.md is the index).
- Open: whether the Anti-hero's tail stays; the Anti-hero's aura colour (violet range is Legal-safe, amber is not).

## Animation

- Review packs, five A/B letters each: art/animation/review/wave1/README.md and wave2/README.md; three A/B pairs in art/animation/review/step3/README.md.
- Reels: art/animation/overhaul-L-showcase-reel.gif, golive1-before-after.gif, intro-reel.gif, ground-*.gif, laststand-*.gif, tumble-broken-arm-before-after.gif.
- The joint-limit fix for the unnatural bends is live: docs/animation/joint-limits.md; before and after in art/animation/joint-limits/ (four GIFs). 150 of 359 poses changed, including wave 1 and 2 poses, and the wave 1, wave 2 and step 3 packs are now rebuilt on the new rig (each README has a "What changed" section). A new pack covers the knock-back slides, the buried fighter, the taunt and the charges: art/animation/review/agency1/README.md. The list of changed poses: art/animation/records/joint-limits.md; old against new, side by side: art/animation/joint-limits/changed-poses-1.png to -5.png.
- Decide: go or no go on the rich moveset (docs/combat/m0-rich.md, docs/combat/pending/waves-index.md, docs/animation/review-plan.md), and switching on wave 1's strikes.
- Decide: whether the transformation's "draw in, snap, hold still" staging is what Orb wanted.

## Writing

- The voice-lab packet to edit: docs/narrative/voice-lab/ (read known-tells.md and README.md first; one CSV per fighter, plus staredown-last-stand.csv).

## Design questions

- The third rule-of-cool questionnaire (the EP shows it as a form on request). The first two are recorded in docs/ep/vision.md; the feature list is docs/design/rule-of-cool.md.
- Simple layouts transforming automatically: docs/controls/auto-form-spec.md (the EP recommends yes).
- Depth: what happens when a fighter flying freely meets a building at his depth (docs/world/fight-lanes-world.md section 14).
- The EP's rulings made in Orb's absence, to overrule or keep: the last section of docs/ep/status-2026-10-01.md.

## Legal and business

- The licence: docs/legal/licence-recommendation.md (the repo is all rights reserved until Orb picks).
- The title clash, before any store page: docs/legal/name-screening.md and docs/legal/pre-store-checklist.md.
- Legal's review of the fighter concepts: docs/legal/fighter-concepts-review.md.
- The private feedback target (where players' feedback goes; never Orb's personal email without Orb's say).
- The launch roster size.

## Housekeeping

- Delete the empty folder C:\AppData (made by mistake by a director session).

## Added 2026-10-02

- The sky reaction at tiers 3 and 4 (the "strange aura" Orb saw): fixed to a gap in the clouds with a lit edge. It is now subtle, and shows nothing under clear sky. Before and after: docs/rendering/img/sky-gb002-high-before.png and sky-gb002-high-after.png. Decide whether it is now too faint (a stronger lit edge, or clouds gathering round the fighter).
- Cyborg directions and the refine sheets: art/concepts/refine/README.md.
- Player agency (from the two-player playtest): docs/design/agency-pass.md (rules and two pitches), docs/controls/agency-input.md, docs/director/agency-evidence.md, docs/combat/alchemist-content.md.
- Taunt lines that stay fresh: docs/narrative/taunt-system.md (five questions for Orb in section 12) and 208 draft lines to edit in docs/narrative/voice-lab/taunts-draft.csv.
- Energy (2026-10-02): the rules are docs/design/agency-pass.md sections 15 and 16. Pictures of the explosions and the mine looks: docs/vfx/img/explode-charged-after.jpg, explode-bolt-after.jpg, explode-knocked-loose.jpg, mine-kai-armed.jpg, mine-vorr-armed.jpg, mine-fuse.jpg, mine-blast.jpg. Poses for the swat, laying a mine and the spray: art/animation/review/energy1/README.md. Decide: which extra blast kinds to build (splitting shot, rain, curving shot, ricochet, burning wake, shield orb); six mines a fighter; the signature limit (the switch is on: 15 s).
- The sky: docs/rendering/sky-gap-anchored.md (accept a world-anchored cloud gap, or drop it).
- The launch pair plan (the Protagonist and the rival): docs/design/launch-pair-plan.md. Decide: the rival gains +2 Pride per building he levels (yes or no); names for both.
- The rival's glasses: art/concepts/refine/anti-hero-glasses.svg. Decide: the frame (Art's lead: blade lenses; second: cut hex), whether the glare hides his eyes completely, and whether the glasses are always on.
- The launch pair's look (2026-10-03), three sheets in art/concepts/refine/: glasses-compare.svg (frame A lead blade lenses with a lit top line, B bevelled with hinge tabs, C bare wedge, D the earlier plates; Art picks A), launch-pair-protagonist.svg (big fists and a broader body with the forelock, or the long swept tuft?), launch-pair-rival.svg (long tail and coat blades, or the swept shoulder blade?).
- The Protagonist's strikes (42 slots, 12 re-posed, 8 of his own): art/animation/review/protag1/README.md.

## Decisions waiting on Orb (2026-10-03, after slices 8 to 12 went live)

- Match length: widen the median band to 6:00 to 8:30 (Game Design, agency-pass.md section 19), or keep 8:00. QA is re-measuring a wear lever on df05b9f that may hold 8:00 without shortening the last stand.
- Front-row buildings (52.7% lost, ceiling 50): raise the ceiling, soften landing blasts to about a third (World, ground-contact.md section 32), or reduce top-tier reach into buildings (QA's lever, being re-measured).
- Which extra blast kinds ship: curving shot (Protagonist), splitting shot and rain (rival); whether rain can hit its thrower; rain on a roof (launch-pair-plan.md section 9).
- The look picks: glasses frame A, B or C (art/concepts/refine/glasses-compare.svg), launch-pair-protagonist.svg, launch-pair-rival.svg.
- The landing ring that shows where a deflected shot will explode: keep, or make the landing a surprise.
- The rush jolt in split screen (Camera: docs/camera/split-screen.md section 21c): tackle in this update or later.
- The beat-pace metronome earning the perfect blur about a quarter of the time: build Controls' fix (docs/controls/agency-input.md, option B) or leave it.
- The fighters' names; the split to PROTAGONIST and RIVAL can run on neutral ids meanwhile.
