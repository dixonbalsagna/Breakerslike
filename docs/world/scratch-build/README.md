# The scratch build of G1 and reach, and G2 to G5 (ground contact)

Built and measured in a scratch copy of local HEAD (08f5cd0); nothing here is in the tree. To rebuild:

```
git archive HEAD | tar -x -C <dir>          # a fresh HEAD export
python docs/world/scratch-build/build.py <dir> docs/world/scratch-build [enable]
godot --headless --path <dir> --import
```

- `g1_reach.py`: rims (lip 0.5 R, crest 0.40 d, footings skipped), heaps (slope 0.6, spill 1.0), structure reach by tier (scaled falloff, ring cap), the ladder data and schema, `fighter_data.gd`'s parse, `beam.gd`'s explicit 1.0.
- `g1_freeze.py`: a slide's trench never relaxes the column he stands on or the ground ahead.
- `g2_contact.py`: the fields, events, hash lines and hooks of G2 and G3 (switched off by data), plus `contact.gd` and `contact.json`.
- `probe_g1.txt`, `probe_g2.txt`: the probe sections. `light.gd`: the light per-tick digest used for the neutrality proof. `jstats.gd`: landing classes and journeys.
- `enable` flips `contact.json` to `"enabled": true`.
