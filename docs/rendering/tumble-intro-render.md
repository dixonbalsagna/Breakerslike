# The tumble and the intro's sky shot: Rendering's plan

Owner: Rendering and Technical Art. Status: plan only, 2026-10-02. Nothing on this page is built. It covers Rendering's part of two things other directors have planned:
- the tumble (World's `docs/world/ground-contact.md`: skid, bounce, tumble, rims; Animation's active ragdoll);
- the entrance (Camera's `docs/camera/rule-of-cool-shots.md` row 7; Simulation's `docs/architecture/intro-phase.md`).

Rendering reads the sim and writes nothing in both.

## 1. The tumble

**Who draws what.** The body's pose is Animation's (the ragdoll reads `mode`, `spin` and `bounces`). Dust, the contact flash and tumble blur are VFX's. Rendering has the fighter's place on screen, his shadow, the ground he marks and the rims he flies off.

### 1.1 The body touches the ground at a bounce

The host draws a fighter between his last two ticks. A bounce turns him round inside one tick, so the straight line between the two ticks cuts the corner and the body never reaches the ground.
- **How far off:** at most a quarter of a tick's travel in and out. A 1,500 units a second landing that rebounds at 675 is drawn up to 9 units above the ground at the bounce, 12% of a fighter's height. At twice the speed it is 18 units.
- **The fix:** on a tick with a `bounce` or `land` event the host draws prev, then the contact point, then cur, in two straight pieces. The events already carry the contact's `x`, `y` and `z`.
- **What it needs:** the share of the tick at which the contact happened (a field `u`, 0 to 1, on `bounce` and `land`). Without it I split the tick by the two speeds, which is close.
- **Not needed if** the sim leaves the fighter on the contact point at the end of the bounce tick. World should say which it is.

Spin needs nothing: `rot` is not wrapped in the sim, so the plain blend between ticks turns the right way at any spin World allows (3 turns a second is 18 degrees a tick).

### 1.2 The shadow

The ground shadow already follows the ground as drawn, fades to a quarter and widens by half with height, and sits on water. Two changes for bounces:
- **Height above the ground under him, not above his start.** A bounce over a rim or a slope changes the ground under the arc, so the shadow's fade must come from the gap to the ground at his x and depth each frame. It does today; a check is added to the pane check for a body over a rim.
- **A tumbling body's shadow is round.** Today's ellipse is as wide as a standing fighter. In a tumble or a skid it takes the body's drawn extent along the ground (Animation's pose bounds), so a body lying flat has a long shadow.

### 1.3 Marks on the ground

- **The trench of a skid** is sim terrain and is drawn today.
- **A tumble's scuffs** (Game Design: one scuff a contact, at most three a second, no trench). If World records them (as it records scorch), the ground shader draws them from state and they survive a replay seek. If they are cosmetic, they are VFX's decals. I prefer the record: marks that stay are pillar 4, and the shader path costs no draw call. World and VFX should settle which.
- **Wider rims** (World's G1: a lip 0.5 R wide, a crest up to 0.40 of the depth). The renderer rounds each crater into a bowl in depth from its record, and the rim must come out as a ring, not a wall across the band. The bowl function needs World's new rim profile. It must be the same pure function the sim uses, or the drawn lip and the one a skid leaves from will differ.

### 1.4 What stays as it is

- **The cut-away** follows a tumbling fighter behind buildings as it follows any fighter.
- **The lane cue** shows while his depth changes; the events' `z` is the body's depth.
- **Battle damage** comes from wounds only. A tumble adds no marks to the body unless the sim's wear says so.

### 1.5 Cost

Nothing per pixel. The contact point is a few numbers a tick. The rim term is part of the bowl function that already runs when a crater is dug.

## 2. The intro's sky shot

Camera's beat: a low wide angle on the empty landing spot (pitch -6 degrees, the fighter 7% of the screen's height), the sky above, a speck falls into frame, he lands in a crater.

### 2.1 What works today

- **The low angle.** A negative pitch is checked on the real renderer (`README.md`, "The camera's pitch").
- **The landing's crater** is a real dig, drawn like any crater at the tick it happens.
- **The fall's motion.** The fall is fast (a body height or more a tick) but straight, so the blend between ticks is smooth.

### 2.2 What needs building

- **The speck.** A fighter far up is a few pixels tall and can vanish between pixels. Below about 6 pixels of drawn height the view adds a small bright point in his aura colour at his chest, so he reads as a falling light and grows into a body. It is a marker, so the inset and the reduced version follow the same rule as the head badge.
- **The sky answers the fall.** The clouds part round the falling fighter with the opening the sky already has for tier 3 (`sky_react`), at half strength, from `entrance_fall` until 0.6 s after `entrance_land`. It only lightens and there is no lightning, as Legal asked. This is a world reaction before the clock and below tier 3, so **Game Design must allow it**; without it the fighter falls through clouds that do not move.
- **Clouds at the low angle.** At -6 degrees the top of the frame looks higher than the fight ever does, where the cloud band has faded out. I will check the frame and, if the top is bare, lift the band's upper edge for the shot.
- **No head badges before the clock.** The badge is a HUD-space marker. The host switches markers off while the intro runs, as UI hides the HUD.
- **A clock for easing.** The sky's opening and the lane cue ease on tick time, and `S.T` stays 0 before the clock. They need a tick count that runs through the intro (`S.intro.t`, or `S.tick` if it advances).

### 2.3 The host (`sim_host.gd`, `main.gd`)

- **Pre-clock ticks pass intents.** The host drops input edges on a set-piece pause's ticks. On intro ticks it must pass them, because any press skips.
- **The demo.** The first key or button takes player one over. With an intro running, that same press also skips it. I propose that it does both.
- **Overlays.** The first-run How to play card freezes the sim, so the intro waits behind it and plays when it closes.
- **Who gets an intro.** The game's own matches ask for it (`"intro": true`). The tools, the bench, `--frames` and `--shot` do not, so every check and measurement keeps today's opening.
- **Events on pre-clock ticks** must still reach the host's drain (VFX, Audio, Camera and the crowd read them there). Simulation should confirm that `step` returning false still leaves the tick's events in `S.out`.

### 2.4 Cost and the reduced version

- The speck is one small quad a fighter. The sky's opening is the shader that already runs.
- **Reduced:** no opening in the sky and no clouds at low quality (as today); the speck stays, since it is the only thing that shows him.

## 3. What I need, in one list

| From | What |
| :--- | :--- |
| World | Whether a bounce tick ends on the contact point; if not, `u` on `bounce` and `land`. The rim profile as a shared pure function. Whether a tumble's scuffs are recorded |
| VFX | Agreement on who draws scuffs |
| Animation | The pose's extent along the ground, for the shadow |
| Game Design | Whether the sky may part for the entrance, before the clock and below tier 3 |
| Simulation | A tick count that runs through the intro; events still drained on pre-clock ticks |
| Controls | Agreement that the take-over press also skips the intro in the demo |
| UI | Nothing new (the HUD hides itself) |

## 4. Build order

1. With World's G3 (the contact events): the contact point in the blend, the shadow's extent, the pane check for a body over a rim.
2. With World's G1 (rims): the rim term in the bowl function.
3. With Simulation's intro slice: the host's pre-clock ticks, markers off, the easing clock, the speck, and the sky's opening if Game Design allows it.
