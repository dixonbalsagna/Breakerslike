# Parked data batch (Q4)

Finished copies of `data/combat/templates.json` and `data/combat/finishers.json` carrying the EP-approved Q4 batch. They are parked here because they change the combat data hash and the goldens. Files under `docs/` are not loaded or hashed by the sim.

The batch (`variety-pass.md` section 6):
1. a finisher `kind` on every finisher;
2. `contest.struggle.byState`;
3. PRESSURE's R4 counter as `selectorByProfile.dynamic`;
4. about 30 new cue names.

**When to land it:** after World's slice and the dynamic slice, in one commit with Tools' schema changes (items 1 to 3) and Encounter's Q4 loader work.

**Before copying back:** these copies were cut from the data files as of commit `b3eaf4b`. If either file has changed since, merge rather than overwrite.
