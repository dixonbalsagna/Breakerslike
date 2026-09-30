# Pace measurements before the dynamic-feel pass

Owner: Encounter Systems Director. Status: measurements only, no sim change. Why: Orb's playtest says combat feels slower than the prototype, with fighters locking together and idling before attacks (`docs/combat/dynamic-feel.md`).

Method: read-only probes on a9d0363 (spaced profile, k 0.065), 100 AI matches, default arm. The what-ifs ran in scratch copies of the tree, 50 matches each, seeds 1 to 50.

## Where the time goes

- 47% of fight time is in exchanges and 53% between them.
- Between exchanges:

  | What | Share of the time |
  | :--- | ---: |
  | Director cooldown | 45% |
  | Someone launched or down | 12% |
  | Both free within 400 units | 17% |
  | Both free and further apart | 25% |
  | Lock broken | 0.5% |

- The first press after an exchange ends comes after a median of 2.1 s (p90 5.1). The next exchange starts after a median of 2.8 s (p90 6.1). The dynamic-feel target is at most 1.0 s from release to the next request.
- The AI's attack beats outside exchanges:
  - 55% hold;
  - 36% start an attack;
  - 6.6% press during the cooldown and are refused;
  - 2.7% press at a target that is still airborne and are refused.

  Every beat, refused or not, re-arms the AI's timer for 1.2 to 3.6 s.
- Inside exchanges the median exchange lasts 2.75 s. The first hit comes after a median of 1.45 s (p90 2.40):
  - DODGE & READ, DODGE & COUNTER and both HEAVY CLASH templates: 1.45 s;
  - PURSUIT: 0.73 s;
  - TRADE BLOWS, PRESSURE and GUARD BREAK: 0.40 s;
  - signatures: about 0.8 s.

  9% of exchanges land no hit at all.

## What-ifs

| Change (scratch copy only) | Gap, median / p90 | First press, median | Exchanges per minute | Wasted presses |
| :--- | ---: | ---: | ---: | ---: |
| The tree as it is | 2.77 / 6.08 s | 2.05 s | 9.7 | 9.4% |
| Cooldown a flat 0.3 s | 2.32 / 5.75 s | 2.08 s | 10.3 | 4.6% |
| Fewer holds (P_ATTACK 0.85) | 2.05 / 3.83 s | 1.62 s | 11.1 | 21.3% |
| Both | 1.67 / 3.42 s | 1.62 s | 11.8 | 8.9% |

## Reading

1. **The AI's timer is the real gate, and the cooldown hides it.** The timer is held at its stance floor (1.2 to 2.0 s) through every exchange. After that, 55% of beats hold and re-arm it. With the cooldown cut alone, the first press does not move at all (2.1 s).
2. **Refused presses waste beats.** Cutting the holds without the cooldown makes this worse: 16% of beats then press into the cooldown. The AI should wait out a cooldown or an airborne target without re-arming its timer.
3. **The close-range halt.** An AGGRESSIVE AI stops moving within 130 units and waits for its timer. That is most of the 17% "both free within 400 units" share, and what dynamic-feel item 4 (circle and feint) replaces.
4. **Inside exchanges**, the dodge and clash templates spend 1.45 s before the first hit. That timing is Combat's `dynamic` profile, not code.
