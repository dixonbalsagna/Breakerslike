# A gap in the clouds that stays where it opened

Owner: Rendering and Technical Art. Status: a note for Orb to accept or drop, 2026-10-02. **Nothing here is built.** The sky's reaction to tier 3 and 4 is off by default (`README.md`, "Clouds, and the reaction that is off by default"); this is what could replace it.

## Why the one that follows a fighter failed twice

The built reaction is tied to the direction from the camera to the fighter. So it is a patch of sky that travels with him. The clouds slide under it as he or the camera moves, and the lit edge lights whichever cloud is passing. Orb read it as a pale pillar the first time (GB-002) and as a big glowing texture over each fighter that shimmers the second time (GB-002 reopened). Both are the same fault: something stuck to a fighter does not read as weather.

## What the anchored version would be

- **An event, not a state.** A gap opens once, at the moment a fighter's tier rises to 3 or to 4. Standing at tier 4 afterwards does nothing more.
- **It belongs to the clouds.** The gap is stored in the cloud pattern's own coordinates (where round the planet, and how high in the band), not as a direction. It slides with the clouds when the camera moves and drifts with their wind. Neither fighter moves it.
- **It fades.** It opens over about a second, holds for a few, and the clouds close over it in about ten. At most four are kept; the oldest goes first.
- **Leave and come back.** Fly away and it slides off the screen with the clouds. Come back before it closes and it is where it was.
- **The same in every pane.** A split shows one gap in one place, in both panes. The built one opened a different gap in each pane.
- **No lit edge in the fighter's colour.** The lit edge is what read as a glowing texture. At most the edge is a little lighter for the half second it opens. Legal's rules stay: nothing darkens, nothing goes white, no lightning.
- **Reduced motion:** none of it. **A replay seek** forgets the open gaps (they are a memory of the renderer, not sim state).

## What it would not do

- **It would not stay above the spot on the ground.** The sky is a backdrop: its clouds move about 0.12 pixels for each unit the camera travels (at 1280×720), far slower than the ground. A gap opens above the fighter and from then on keeps its place among the clouds, not above the crater he left. That is the right reading for weather, but "above where it happened" is only true at the moment it opens.
- **It would be easy to miss.** One cell of the cloud pattern is about half a screen wide, and half the sky is clear. A gap can open where there is little cloud to part, and then it shows little. Making cloud to part was tried in the first fix and looked wrong.
- **It would not carry feature 12 alone.** VFX's floating rubble and World's cracks under a standing fighter are the parts of the feature that read at once.

## Cost and check

About half a day: a short list of gaps in `PaneWorld` (shared by the panes), the same loop in the sky shader that the built reaction uses, numbers in `RenderLook`. `tools/sky_check.gd` would assert that a gap's place does not change when either fighter or the camera moves, and that it is gone after its time.

## Recommendation

Drop the sky's part unless the ground effects turn out not to be enough at tier 4. If Orb wants the sky to answer, build this version and not the one that follows a fighter, and judge it in play with the flag before it goes on by default.
