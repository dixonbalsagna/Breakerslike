# Prototype bugs that matter to design

Owner: Game Design. Status: P0, for the EP to schedule. Date: 2026-09-29.

Defects in `prototype/index.html` at commit `7233c96`, each with the design intent it breaks. **Nothing here is fixed in the prototype.** The prototype stays behaviour-identical until the port proves parity (EP ruling), and the EP schedules the fixes. Where Combat (`docs/combat/move-grammar.md` §5) or QA (`qa/baseline-p0.md`) logged the same defect first, their ID is given. This list adds the design intent and the severity for design.

| ID | Where | What happens | Design intent | Severity | Also |
| :--- | :--- | :--- | :--- | :--- | :--- |
| GD-B01 | `L589` | A signature's HIT chance against ESCAPE *falls* as the attacker's tier advantage grows: `0.5 − 0.05·(A.tier − D.tier)`. Every other tier term favours whoever is ahead | A tier advantage always helps its owner (`stance-matrix.md` R7) | High | CC-004 |
| GD-B02 | `L326-328`, `L411` | The ×1.35 damage against a charging defender, and the reset to `free`, never apply: the defender is already `locked` when `hit()` runs | Charging is punished by the CHARGE INTERRUPT template (base ×1.4). Delete the dead multiplier in the port; do not revive it | Low | CC-003 |
| GD-B03 | `L544-547`, `L572-575` | After a parry the chain window still opens. The attacker can spend 6 ki on a "chain" whose strike and launch are cancelled | No chain after a parried exchange (R6) | Medium | CC-001 |
| GD-B04 | `L479-480`, `L554` | After PRESSURE — GUARD HOLDS a chain window opens, and the chain strike ignores stance, so it bypasses the guard | A held guard ends the exchange; no chain window (R6) | Medium | CC-002 |
| GD-B05 | `L494-500` | TRADE BLOWS has two endings, attacker wins or defender wins, under one feed tag | Every outcome is visible in the feed (P2 exit) | Medium | QA-004 context |
| GD-B06 | `L479` | PRESSURE's counter is a 40% roll the defender never earns | The defender earns the counter by input (R4) | Medium | Combat §3.2 |
| GD-B07 | `L525`, `L853` | A missed parry press costs nothing, so mashing parries every wind-up is free | The parry is a read; a miss costs 5 ki and locks the parry for 0.5 s (R5) | Medium | CC-008 |
| GD-B08 | `L589` versus `L441` | An ambush does not affect a signature against ESCAPE, but always catches a melee pursuit | An ambush is consistent across attack kinds | Low | CC-007 |
| GD-B09 | `L322`, `L759`, `L823`, `L274` | Role hooks are hard-coded by role name:<br>• every non-villain gets the comeback bonus and the anguish regen term;<br>• only role `hero` lures;<br>• only the first hero gets anguish | Ego mechanics are per-fighter data (`economy.md` §4). Four fighters and post-launch mods need it | High for the roster | QA-003 |
| GD-B10 | `L272` | Menace never decays and grants four stacking buffs | Every ego meter decays or is spent (`economy.md` §4.1). A design change more than a bug; listed so the port does not copy it as intended | Medium | QA finding 1 |
| GD-B11 | `L616`, `L620` | A dodged signature leaves the defender frozen and locked, 300 units up, for about 0.9 s | No dead air (`balance-targets.md` §3) | Low | CC-005 |
| GD-B13 | `L584`, `L649-655` | The variant is chosen by the defender's biome, but its extras apply along the whole path: a FIRESTORM fired from the forest burns the desert | A variant marks the land it names (pillar 7) | Low | CC-012 |
| GD-B12 | Cosmetic calls to `R()` and `rng()` (for example `L381`, `L654`, `L784`) | Visual effects draw from the simulation RNG, so any VFX change rewrites gameplay | Rendering never changes the sim (CLAUDE.md rules) | High for P5 netcode | QA-002 |
