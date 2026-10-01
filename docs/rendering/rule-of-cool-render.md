# Rule of cool: Rendering's plan-only items

Owner: Rendering and Technical Art. Status: plan, 2026-10-01; section 1 built the same day. Sections 2 to 4 are plans; nothing in them is built. They answer the EP's wave 0 brief for the items of `docs/design/rule-of-cool.md` that are not Rendering's to build yet. What is built (battle damage on the mannequin, the sky reacting from tier 3, windows and their blow-outs) is in `README.md`, "Battle damage, the sky and windows".

## 1. Windows blowing out (feature 12): built

This was a plan when the page was written. It is built now and described in `README.md`, "Windows, and windows blowing out": the building shader draws windows on every wall, and the facade's windows go out from VFX's `host.vfx.react.blowouts` list, on VFX's rows of floors, and stay out for the match.

What is still open:
- **Blow-outs do not survive a replay seek** past VFX's six-second list. A sim record of them (World's structure reach, `balance-targets.md` section 21) would fix it.
- **Glass starts from VFX's floors, not from window cells.** If VFX wants shards to start at real windows, I can expose where each one is: `PlanetView.window_point(building, face, column, floor)`. Not built; nobody has asked.
- **The look of every building changed.** It wants Orb's or Art's nod.

## 2. Land scars stay; water closes (feature 9)

**Already true, with two limits worth knowing.**
- Craters, trenches, scorch, cracks and rubble are sim state and stay all match; the renderer rebuilds all of them from state, so they survive a replay seek. Water closes over a cut in the sea within seconds by the sim's own flow, and the renderer draws `S.water` every frame.
- The glow of a fresh groove is the only part that fades (about 5 s). It is cosmetic.
- **Limit 1.** The sim keeps 400 crater records and 200 slide records and drops the oldest. A dropped crater keeps its dent on the fighter plane, but the renderer then spreads it in depth as a groove, not a round bowl. AI matches make tens of craters, so this is far off; a very long match at tier 4 could reach it.
- **Limit 2.** Until World's terrain rows (slice T), a scar is one profile across the whole band; the renderer rounds it into a bowl only away from the fighter plane.

## 3. A tunnel through a mountain that stays (feature 18)

World is right that a heightfield cannot hold a tunnel: one height a column. The renderer can fake one that reads correctly in the side view, if the sim keeps the tunnel as a record (its two mouths on the profile and a radius), as it keeps craters.

**Today, for Camera's tunnel shot.** The cut-away that exists (the hole round a fighter, and the stubs) only opens buildings. Terrain is never cut, whether a pane's cut-away request is on or off, so a rock stays whole.

**The fake.** The side view already shows buildings in cross-section when a fighter flies through them (B3's floor tunnels). The same idea for rock:
- **A cut-away in the near rock.** The ground shader finds, for each pixel of the foreground slope, where its sight line meets the fighter plane. Where that point lies inside a tunnel's bore (a capsule between the two mouths), the pixel is not drawn. That opens a window through the near side of the mountain onto the bore, anchored to the world, so it stays put and stays all match.
- **A back wall.** Behind the bore a dark strip of rock is drawn (one small mesh a tunnel), so the opening shows a tunnel's inside and not the sky behind the mountain. Its ends take the daylight of the two mouths.
- **Mouths.** A ragged rim where the bore meets the slope, from the same noise the crater floors use.
- A fighter inside the bore is then seen flying through the mountain at his own depth, as in a building.

**Cost.** One ray-plane step and a capsule test per ground pixel per tunnel; with the budget of three planet-scale launches a match, at most three tunnels. One draw call a tunnel for the back wall.

**Limits.** The ground above the bore does not sag or collapse, and the heightfield under it is unchanged, so only what the sim lets through (launches, by its record) passes. From the three-quarter camera the fake reads less well: the cut-away is a side-view convention. Formations with real footprints (World's N1) could instead be real meshes with a hole, which is the better answer for mesas if N1 lands first.

## 4. Throwable vehicles and ships (feature 17)

These are sim props (World's V1 and P1): the sim owns where each one is, who holds it and where it flies. Rendering draws them.

- **Meshes.** Greybox shapes built in code until Art's models: a car (two boxes), a lorry, a boat (a hull prism) and a ship (a hull and blocks). One MultiMesh a kind, so about four draw calls a planet copy. Sizes from World's data (a car is 2.5 by 1.0 fighter heights; a ship is many times that).
- **Motion.** The host keeps each moving prop's last two ticks, as it does the fighters', and the view interpolates. A parked prop is placed once. A held prop sits at the fighter's hand socket, which Animation's rig already gives (`hand_r`).
- **Scale against the fighter.** Props take the world's perspective, not the fighter's flat projection, so a ship reads as huge next to him. A held lorry will cross through the fighter's flat silhouette at some angles; Animation's carry pose has to hold it clear.
- **Readability.** A prop in front of a fighter needs the cut-away hole, so the hole's shader code moves into an include that the prop material shares (already planned for trees). Each prop gets the same soft ground shadow the fighters have. A ship floats at the sim's water level; a small bob is cosmetic.
- **People bail out first** (Orb, tone 6 of 10). That is the crowd's flight with a prop as its source: it needs World's `evacuate` event to name the prop, then the runners I already draw leave it.
- **Wrecks.** The burst is VFX's; the wreck that stays is a second mesh state of the same instance.
- **Cost and reduced version.** Tens of instances at most near a fight. Far props are boxes. Nothing here is per pixel.

**Needs before any of it:** World's prop record with depth (fight lanes, P1), the pick-up rule (Combat, Controls), and Art's say on the shapes.
