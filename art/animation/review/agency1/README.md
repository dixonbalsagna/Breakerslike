# agency1: the pack for Orb (the slice-3 events as poses)

Machine pass (see exceptions.md): the poses are checked by the same lints as the waves (`pose_lint` incl. Legal's `_legal` rules, silhouette, stacking). Then what Orb sees:

1. **The sheet** `agency1-sheet.png`: the twelve poses (the taunt's three, the embed's three, the three charges, the three knockbacks).
2. **Eight A/B GIFs**, each the same event with the new poses OFF on the left (what the fighter did before) and ON on the right: `ab-taunt.gif`, `ab-charge_light.gif`, `ab-charge_heavy.gif`, `ab-charge_feint.gif`, `ab-knock_short.gif`, `ab-knock_long.gif`, `ab-drift.gif`, `ab-embed.gif`. Two fighters, side on; the lab sends the events as the sim does (`render/anim/tools/agency_lab.gd`).

What is in it (docs/animation/pose-pipeline.md 9.22):

- **Knockback** (slideShort, slideLong, drift): a held pose while he is sent back, eased in and out: heels skidding with the arms out for balance; sat back low with the feet wide; floating with the arms loose.
- **The embed:** lying in the crater on his back, a hand stirring, the hands to the floor and a knee drawn up, over the 60 held-down ticks; the ground contact's get-up takes over.
- **The far taunt:** a shrug with the palms open and turned up, the shoulders lifted and the chin cocked, played over the flight. No beckoning (Legal's rule). It is cut by `taunt_end_cut`.
- **The charges:** light: one narrow blade, the lead shoulder and its forearm guard ahead, the other arm folded to the chest (the dash's look); heavy (`charge.heavy_lead`): both forearms side by side ahead of him, parallel and never crossed, the head tucked behind them; the feint's peel (`charge.peel`): side-on and braking, the leading arm swung wide (open hand, not a punch), one knee up. Legal's dash rule: not both arms trailed straight back, not one fist punched ahead.

For Orb: whether the taunt reads as a challenge rather than a gesture (it is one beat, at 92% over the flight), whether the heavy charge's two-forearm line reads as a shield, and whether the embed's lying pose and the stir say "driven in".

Not wired because the sim does not send it: the answerer's pose (`challenge_answered`) and the taunt's credit cues. `--no-agency-poses` switches all of it off; reduced motion plays it at 60%.
