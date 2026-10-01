# Local two-player: the join rule, the pairings, what to wire, what to check

Owner: Controls and Game Feel. Date: 2026-10-01. Status: built and tested (`join_test` 51 checks through the real sim; `hub_test` 50). Host wiring: [join-glue.patch](join-glue.patch) (sim_host.gd, 28 lines). Code: `sim/input/hub.gd`.

## The rule

A **device** is the keyboard, one pad (by its device id) or the touch screen. A device that drives no slot is given one the first time it is used, in this order:

1. a **human slot no device drives yet** (a player the mouse or the T key made human), the lower slot first;
2. **slot 0**, if nobody is playing (the demo): the first input is player one;
3. **slot 1, if it is the AI: the device joins as player two** (the hub asks the host to make the slot human);
4. both players are driven already: a pad, key or touch goes to a slot that is on another kind of device (a player changing device); a spare pad is ignored.

Consequences you can rely on:
- **A second pad plugged in while P2 is the AI joins as P2.** It never takes slot 0 from the pad that is playing (tested with P1 mid-guard and mid-stick).
- **Any pad button joins**, bound or not, including a trigger past its threshold; a stick alone does not. For the keyboard, **any key a keyboard layout uses** joins (an unbound key does not), so a stray modifier does not start a game.
- One keyboard player uses the solo layout; two keyboard players (after T, or a keyboard joining beside a human on a keyboard) use the shared halves; **one keyboard next to a pad is solo**, for either player.
- Touch is one device and takes a slot like any other: player one in the demo, else player two.
- **Leaving:** player two hands the slot back to the AI with `hub.leave(1)` (the pause menu), or by unplugging the pad that drives it. Unplugging player one's pad leaves player one human, back on the keyboard. Player one cannot leave. After a leave the slot is joinable again, by the same pad or another.
- Each slot has **its own pad preset** (Arena, Brawler, Simple): `hub.set_pad_preset(id, slot)`; `slot = -1` sets the default for both. `hub.layout_of(slot)` names the preset a slot plays with now (`kb-solo`, `kb-shared-p1`, `kb-shared-p2`, a pad preset or a touch preset), and `hub.device_of(slot)` the device: both are for UI's hints, legend and glyphs.
- **Remaps are per player** (`remap.md`, "Per-player remaps"): two players on the same layout can each rebind it; the file keeps player one's in `presets` and player two's in `presets_p2`.
- **Start joins on a new pad.** `hub.start_joins(device)` is true when the pad drives no slot and a second player could join; the host then lets Start through as the join instead of pausing ([start-joins.patch](start-joins.patch), one line in `main.gd`). On a pad that is playing, in the demo, or with both players in, Start pauses as before.
- **Replays are unaffected**: a replay records intents, and the test shows the same actions from a pad and from the keyboard are the same match.
- Assists (Simple layouts) are set at match start, so a player who joins or changes to Simple gets them from the next match.

## What the hub gives the host and UI

| Call | For |
| :--- | :--- |
| `hub.joinable()` | true while player one is playing and slot 1 is the AI: UI shows "P2: press any button to join" |
| `hub.take_joins()`, `take_leaves()` | slots to make human or hand to the AI; the host drains them each tick (the patch) |
| `hub.take_notes()` → `host.input_note(note)` | `{kind: "joined" or "left", slot, device}`: UI's "P2 joined" or "P2 left" line |
| `hub.leave(1)` | the pause menu's "Hand P2 to the AI" entry (shown while slot 1 is human); returns false otherwise |
| `hub.device_of(slot)`, `layout_of(slot)`, `pad_preset_of(slot)` | per-player hints, legend and prompts |
| `hub.reset_claims()` | forget every device assignment (a fresh start; tests) |

## What Rendering must wire

1. Apply `join-glue.patch` to `render/core/sim_host.gd`: it drains `take_joins()` and `take_leaves()` before each tick (toggling the AI) and emits `input_note`.
2. **The pause menu must work from a pad.** Today it takes mouse, touch and keys; Start only pauses. Add d-pad up/down to move, A (south) to choose, B (east) to go back, from any pad, so a player on a pad can resume, open How to play or Settings, and hand P2 back. UI's Settings and How to play already take a pad.
3. Apply `start-joins.patch` to `render/core/main.gd`: Start on a pad that is not playing, while a second player could join, joins instead of pausing. Nothing else changes in `main.gd`: pad events already carry their device id.

## What UI must show

- **"P2: press any button to join"** (and "or press T" while the keyboard is the only device) while `host.hub.joinable()`; hide it once P2 is human.
- **"P2 joined" / "P2 left"** for about two seconds from `host.input_note`.
- **Per-player hints and legend:** each player's legend and prompts come from `hub.layout_of(slot)` and `device_of(slot)`, not one global scheme; the P1 and P2 plates carry their own device glyph.
- **Pause menu entry "Hand P2 to the AI"** (calls `host.hub.leave(1)`), shown only while slot 1 is human.
- **Settings:** the controller layout is per player (Player 1 layout, Player 2 layout, calling `hub.set_pad_preset(id, slot)`); each player's remap is their own (the Remap screen picks the player).

## Manual checks for Orb, two real controllers

Do these in order, in one sitting, with the build open on the title or in a match.

1. **One pad.** Plug in pad A. Press any button: you are P1 and the match runs. The screen says "P2: press any button to join".
2. **Second pad joins.** Plug in pad B (while P2 is still the computer). Press A on pad B. P2 becomes a person. P1 keeps playing on pad A without a hiccup: hold guard on A while you press B, and A's guard must not drop. A "P2 joined" note shows.
3. **Both play.** Fly, guard, attack on both pads at once. Each pad moves only its own fighter.
4. **A third pad does nothing.** If you have one, press it: nothing changes.
5. **Leave and rejoin.** Pause on either pad (Start), choose "Hand P2 to the AI" with the d-pad and A: P2 becomes the computer again. Press a button on pad B: P2 rejoins.
6. **Unplug.** Hold the stick on pad B, then pull its cable (or switch it off): the fighter stops, P2 goes back to the computer. Plug it in and press a button: P2 rejoins. Unplug pad A (P1): P1 stays human, now on the keyboard; the next key you press is P1.
7. **Pad plus keyboard.** Fresh start: P1 on pad A. Press a movement key on the keyboard (W, A, S or D): the keyboard joins as P2. Both play. Then try the reverse: P1 on the keyboard, then a pad button joins as P2.
8. **Keyboard shared.** One player on the keyboard, press T: two players on the keyboard, left half and right half (check the legend shows both). Check there is no ghosting when both hold their chords (Space+Q and Period+Slash); tell us which keyboard it was if keys stop registering.
9. **Different layouts.** In Settings give P1 Arena and P2 Brawler (or Simple). Check each pad does what its own legend says, and the other player's controls are not changed.
10. **Touch plus pad.** On a tablet or phone with a pad paired: touch the screen (you are P1), press a pad button (P2 joins); then the reverse.
11. **Pause from either device.** With two players, pause from pad B, then from pad A, then from the keyboard (P): the menu works the same, and nothing fires when you resume.
12. **New match.** Press N (or start a new match): both players keep their devices and layouts.

13. **Start joins.** With P1 on pad A and P2 the computer, press **Start** on pad B: P2 joins and the game does not pause. Press Start again on pad B: it pauses.
14. **Everything held at once on the shared keyboard,** and the Firefox `/` check: see [two-player-feel.md](two-player-feel.md).

Note anything that feels slow or confusing, which pad model (Xbox, PlayStation, Switch Pro, generic) and which browser or desktop build you used.
