# ADR 0001: Engine choice

Status: proposed (needs Orb's confirmation)

## Context
The prototype is a single-file JavaScript canvas game. The real game needs a wrapped deformable planet, a deterministic simulation for replays and rollback online, four fighters with authored animation atoms, and heavy VFX.

## Options
1. **Godot 4** with a deterministic sim written in GDScript or C#, 2.5D presentation. Recommended in design consultation: open licence, strong 2D and 2.5D, fast iteration.
2. **Stay web** (TypeScript, WebGL or WebGPU). Fastest sharing and playtests, weaker path to console, more custom tooling.
3. **Unity or Unreal.** More features and reach, heavier, licensing and determinism cost.

## To decide with evidence
- One-day spike by Research and Simulation: wrapped terrain with deformation and camera across the seam, 60 fps with the worst-case effects scene.
- Determinism: fixed-point or float-safe approach suitable for rollback.
- Art pipeline fit for the Art Director's chosen presentation.

## Decision
Pending.
