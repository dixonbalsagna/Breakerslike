# step3: timing

Each sequence is as long as the sim's own state it dresses (data/combat/templates.json, sim/director/interrupt.gd), so the pose never outlasts the game's stagger or riposte window.

| Sequence | Ticks | Seconds | The sim number it answers |
| :--- | ---: | ---: | :--- |
| perfect_block | 30 | 0.50 | riposteTicks 30 (the riposte window the defender holds loaded) |
| stagger_blocked | 24 | 0.40 | staggerTicks 24 (the blocked attacker) |
| stagger_short | 12 | 0.20 |  |
| reversal | 8 | 0.13 | the counter-delay beat, 8 ticks |
| stagger_countered | 16 | 0.27 | the delay and land of the reversal (about 16) |
| dodge_cancel | 10 | 0.17 | the dash out, about 10 ticks |
| burst | 14 | 0.23 | the burst, no sim length (the shove is the sim's) |
| shoved | 12 | 0.20 | the shove, about 12 ticks |
| stagger_bait | 30 | 0.50 | baitStaggerTicks 30 (the burster absorbed) |
| absorb | 12 | 0.20 | the burst absorbed, a brief brace |
