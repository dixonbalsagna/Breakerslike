# Orb's first two-player playtest: mountain tumbles, embedded impacts, terrain destruction

Scratch scripts and patches behind docs/world/ground-contact.md sections 18 to 20 (headless only: `godot --headless --path <scratch copy> --script res://<script> -- <first seed> <last seed>`).

- `mtn.gd`: speed in and out of every contact by slope, journeys' peak speeds by biome. `mcase.gd`: the seed-6 cliff-top tumble as a standalone case (run once per variant).
- `speed_cap.diff` (a patch to `contact.gd`; data keys `slope.speedCap` and `slope.gravity` in `contact.json`): the cap on speed gained.
- `cr.gd`, `emb.gd`: crater depths by cause and the embed threshold counts.
- `trn.gd`, `furr.gd`, `furrow.diff` (data key block `furrow`): what a skid and a roll carve today, and the richer prototype.
