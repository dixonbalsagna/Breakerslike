# ADR 0003: Director session models, effort and ultracode

Status: accepted (EP, 2026-09-28, on Orb's instruction)

## Context
Orb asked for ultracode on the most heavily involved director sessions and, for the rest, the most efficient and capable settings for each role. The models available are Claude Fable 5.1 (the most capable, at about 2.5 times Opus pricing), Claude Opus 5.5, Claude Sonnet 5.5 and Claude Haiku 4.5. Effort ranges from low to max.

While briefing wave 1, the EP also found that eight charters named deliverables in docs folders their owned paths did not include.

## Decision
- **Ultracode, Opus 5.5 at max effort:** Game Design, Simulation and Engine, Encounter Systems, Combat and Choreography, Research and Prototyping. These five carry the architecture and the core design, and they run workflows for substantive work.
- **Opus 5.5 at xhigh:** Netcode and Online. It is architecturally critical but lightly loaded until P5.
- **Sonnet 5.5 at xhigh:** the roles whose code, data or specs other directors build on. These are World and Environment, Tools and Pipeline, QA and Balance, Controls and Game Feel, Camera and Cinematography, Performance and Platform, UI and UX, VFX, Art, and Narrative and Fighter Identity.
- **Sonnet 5.5 at high:** the documentation and support roles. These are Legal and IP Compliance, Production Operations, Animation, Audio and Music, Community and Marketing, and Accessibility and Localization.
- **Fable 5.1 is held in reserve** for a specific hard problem, at Orb's call, because of its price.
- **Charter paths corrected:**
  - Encounter Systems gains docs/director/ and data/director/ (director tuning data).
  - World gains docs/world/.
  - Animation gains docs/animation/.
  - VFX gains docs/vfx/.
  - Camera gains docs/camera/.
  - Audio gains docs/audio/.
  - UI and UX gains docs/ux/.
  - Netcode gains docs/net/.

## Consequences
- The settings live in tools/gen_directors.py, and the session list with model and effort is in docs/directors/README.md.
- The EP revisits these settings at each phase gate, or sooner when usage limits bind.
