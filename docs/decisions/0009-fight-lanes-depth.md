# ADR 0009: fight lanes, with depth handled by the choreographer

Status: accepted, 2026-10-01. Decided by Orb after playing Rendering's option A (B3) and Research's option B prototype (research/band-proto).

## Context

In the 2.5D view a launched fighter seemed to bounce off an invisible wall when the building he hit stood in a background row. Option A draws the launch at the sim's depth. Option B gives the fighting ground real depth. Orb found the prototype "fantastic" and more organic, with believable streets.

## Decision

1. **Depth is real, and the choreographer owns it entirely.** Fighters have a depth position in a band of lanes. The player never steers depth, and no depth nudge enters the control scheme (ADR 0008 is unchanged).
2. **Small deviations by default.** Every smash, launch and throw carries a slight variation of angle, so a back-and-forth fight zigzags a little across the lanes.
3. **Large deviations only for targets.** A fighter leaves the lane by a lot only when the director targets a building or another dynamic blocker (a formation, a prop).
4. **Collisions are true.** Buildings and blockers stand on real footprints, and nothing collides unless it is really in the way.
5. **The city becomes believable blocks.** Streets and blocks, with cars, bikes and foot traffic (World's districts, props and vehicles plans).
6. **The camera sells the impacts,** and fighters should read larger on screen, especially in fast passages. Camera's rules are being set with Orb (a camera questionnaire).

## Consequences

- Simulation: depth joins the fighter's position everywhere, hashed and deterministic. Terrain, structures, civilians, beams and launches gain depth where they need it.
- Encounter: the director plans the depth of every exchange, launch and throw (the small-angle rule, the targeted deviations, alignment before an exchange).
- World: lanes, block layouts on real footprints, traffic and props; the terrain rows.
- Camera and Rendering: framing in depth, occlusion (cut-away or porthole), larger fighters.
- Research's prototype is the reference for feel; its README lists the costs. Rendering's B3, Camera's depth follow and VFX's depth trail carry over.
- This is a large change. It is planned first (Simulation leads the architecture plan), then built in slices with one sim editor at a time.
