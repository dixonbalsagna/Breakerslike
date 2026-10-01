# Pending core slices

Owner: Simulation and Engine. Nothing in this folder is run by CI, the validator, the sim or Godot. It holds slices that are built and proven in a scratch copy and wait for the sim slot.

Nothing is pending. L0 and L2 (fight lanes) were applied on 940cf02 (2026-10-02); the notes are in `docs/architecture/fight-lanes.md` section 15. The digest comparison they used is now a tool: `python sim/core/tools/golden_cmp.py <old golden.json> <new golden.json>`.
