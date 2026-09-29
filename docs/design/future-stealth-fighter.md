# Future stealth fighter: the hiding kit, kept

Owner: Game Design. Status: parked for a future roster addition (Orb removed hiding from the base game). Date: 2026-09-29.

Hiding was part of the prototype and the early design. Orb removed it from the base game and kept it for a future stealth-specialist fighter (`docs/ep/vision.md`). This page keeps the kit as it was, so that fighter can be designed from it. The base game keeps only line-of-sight lock breaks (`spec-wounds.md` §1c).

## The kit as it was

| Part | Rule | Source |
| :--- | :--- | :--- |
| **Going to ground** | In the ESCAPE stance, free, in cover, more than 170 units from the opponent, not charging or dashing, and moving slower than 260 units per second. After 0.9 s the fighter is hidden | `prototype/index.html` at `7233c96`, `L683-686` |
| **Cover types** | *Submerged:* ocean, 60 or more below sea level, over deep ground. *Canopy:* forest, low, within 120 of a living tree. *Ridge:* mountains, within 40 of the ground. Later added: smoke and dust clouds, crater bowls, and rubble heaps (`living-destruction-numbers.md` §3) | `L668-674` |
| **While hidden** | +40 HP per second in the prototype, which became battered wear fading 3 per second under Wounds; +25 ki per second. The opponent has no lock-on: an attack costs 2 ki and a 0.5 s cooldown | `L758`, `L762`, `L397-401` |
| **Found** | Hiding ends when the opponent comes within 240 units, when the hider leaves cover or the ESCAPE stance, or when they dash or charge. The Found flash shows | `L687` |
| **Ambush** | After more than 1.8 s hidden: the next attack within 2.5 s of leaving cover, or an attack straight from cover (a 1 s window), deals ×1.5 damage. It always reads an evader, always catches a fleeing target, and cannot be clashed or dodged by a signature. The Primed flash shows the window | `L324`, `L402-403`, `L687`, `L441`, `L458`, `L586-588` |
| **The hunter** | The AI searches around the last-seen spot with random offsets of up to ±1,700 units (seeded), flying low. The planet strip shows a "?" at the hider | `L825-828`, `L1140` |
| **The hunter's view** | Split screen, so the hider's position is truly secret. This was Research's split-screen and fog spike | Risk register #4 |
| **Flashes** | Primed (the ambush window), Found and Searching. Found and Searching stay in the base game for lock breaks | Art |
| **Bands used before removal** | Hides 2 to 5 per match; at least one hide in 70% of matches; 25 to 50% of hides in cover the fight made; hidden time at most 10% of match time; ambush attacks at least 0.5 per match. Prototype: 0.63 hides and 0.061 ambushes per match (QA §8) | `balance-targets.md` history |

## Notes for whoever designs the fighter

- **Make hiding the fighter's identity,** not a shared rule. Only this fighter goes to ground; everyone else keeps line-of-sight lock breaks.
- **Recovery was the balance problem.** Hidden recovery made the hider hard to finish. Give the fighter a cost: slower recovery, a Wounds region that cannot recover while hidden, or a meter that drains while hidden.
- **The ambush was rare in AI play** (0.061 per match), because the AI never attacked from ESCAPE. A stealth fighter's AI must be built around the ambush.
- **Hidden information needs its own screen.** On a shared screen, hiding only denies lock-on. True stealth needs split screen or online play.
- **Pillar 3 still holds.** Being hidden can never make a fighter untouchable for long. Bound it with a time limit or a found radius.
