# Prompt glyphs per device

> **Superseded in part by ADR 0008 (2026-09-30):** the stance, weight and signature-chip prompts retire; the rules, families and neutral marks stand. New prompts (mode chip, context icon, guard and perfect-block cue, hold rings) are UI's with the triggers in `input-scheme.md`. See [input-scheme.md](input-scheme.md).

Owner: Controls and Game Feel (the binding-to-glyph map and rules). UI/UX draws and places the glyphs (`docs/ui/hud-spec.md` §11 asks for this). Date: 2026-09-29. Bindings are in `input-map.md`. **Legal's verdict RL-037 applies: one neutral glyph set of our own, everywhere.**

## 1. Rules

1. **A prompt shows the glyph of the device that last sent input for that slot.** Press a key, then a pad button, and the prompt changes on the next press. No device menu.
2. **The glyph always matches the live binding**, including after a rebind. It is looked up, never hard-coded.
3. **Keyboard glyphs are plain keycaps with the key's label on the player's layout**, not the QWERTY position. Bindings are physical keycodes. Godot 4.4+ has `DisplayServer.keyboard_get_label_from_physical`; on the web build it may be missing, in which case the QWERTY label is shown and the tooltip says "key position". Test on the target browsers.
4. **Pad glyphs are positional and neutral.** Godot's `JOY_BUTTON_A/B/X/Y` are south, east, west, north on every pad, so one picture serves every family. The four face buttons are drawn as a **position diamond**: four equal, uncoloured marks in a diamond, the pressed one filled. **No letters, no console symbols, no colours** on the face marks.
5. **Never colour alone** (HUD spec §13): every glyph has a shape, and hold prompts have a fill ring.
6. **Where and when:** prompts sit on the crown windows and the fighter's plate, never over the fighters. They show always in training, in the first three matches and when **Show prompts** is on; otherwise only the cue (ring, chevrons) is drawn.
7. **Legal (RL-037):**
   - the glyph set is ours and is clearly unlike the console makers' four-shape layouts and lettered, coloured buttons;
   - no maker's symbols in the repo, the web build or itch.io;
   - plain keycaps with letters are fine;
   - **on Steam later**, Steam Input's own glyph images are the route; check Steamworks terms first, then switch the pad glyphs to them behind the same lookup.

## 2. Families

Device family still matters for *layout facts* (which pads have a D-pad, a click on the right stick, analogue triggers), not for art. Detection is from `Input.get_joy_name(device)` and the GUID, case-insensitive:

| Family | Match on | Art | Notes |
| :--- | :--- | :--- | :--- |
| `pad` | any pad ("xbox", "playstation", "dualsense", "nintendo", "steam", anything else) | our neutral set | Same picture for all. Trigger and bumper marks are drawn shapes (below) |
| `kbd` | keyboard input | keycaps with labels | |
| `touch` | touch input | on-screen shapes (`platform-plan.md` §7) | |

A user setting can force `kbd` or `pad` art. Steam (later) adds a `steam` family that swaps in Steam Input's images.

## 3. Neutral pad marks

| Control | Mark |
| :--- | :--- |
| Face buttons (south, east, west, north) | the position diamond, one position filled |
| Left and right stick, with click | a circle with a small arrow ring; a centre dot for the click |
| Left and right trigger | a tall rounded shape at the left or right, "pulled" line through it |
| Left and right bumper | a short wide shape at the left or right |
| D-pad | a plus shape, one arm filled; drawn as a shape, never as arrow characters (the web fallback font has no `→`, HUD spec §9) |
| Start | a small rounded rectangle with three lines |

Screen-reader and tooltip text uses plain words: "south face button", "right trigger", "left bumper".

## 4. Action to glyph

| Prompt | Keyboard P1 | Keyboard P2 | Pad (neutral) |
| :--- | :--- | :--- | :--- |
| Light (sets weight) | F | , | diamond, west filled |
| Heavy (sets weight) | G | . | diamond, north filled |
| Signature (queue or cancel) | R | / | diamond, east filled |
| Dash (hold) | Space | Enter | diamond, south filled |
| Charge (hold; also Press near people) | Q | ; | right trigger |
| Special (hold) | E | ' | left trigger |
| Transform (hold to confirm; also Encore) | X | [ | right stick click |
| PRESS (direct) | 1 | 7 | D-pad, top arm |
| GUARD | 2 | 8 | D-pad, right arm |
| DODGE | 3 | 9 | D-pad, bottom arm |
| ESCAPE | 4 | 0 | D-pad, left arm |
| Stance previous / next | ` / 5 | 6 / - | left bumper / right bumper |
| Move | W A S D | arrows | left stick |
| Pause | P | P | start |

The map is by position, so a Switch-layout pad (where the south button is physically the one the maker labels differently) needs no separate table.

## 5. Prompt kinds and what they carry

There are **no press prompts for parry, chain or the struggle**: no timing press exists (Game Design, Q4). Their tells stay as non-interactive reads (a pose, a ring that shows what the director is about to do).

| Prompt | Where | Content | Timing |
| :--- | :--- | :--- | :--- |
| **Weight** | on the stance ring | a light or heavy mark beside the current stance; the light and heavy glyphs in training | always shown; changes within 2 ticks of a press |
| **Weight fallback** | on the stance ring | a small "short of ki" mark on the heavy mark | while ki < 4 and heavy is latched |
| **Signature** | on the plate's chip | the signature glyph; an armed state when queued; a fill toward 45 with `NEED 45 CHARGE` while unfunded; a countdown ring for the 180-tick cap once funded | from the press until it fires, cancels or expires |
| **Stance** | on the stance chip | four positions with the glyph for each; the current one filled | in training, at match start for 3 s, and whenever the stance changes |
| **Special** | on the plate | glyph and a hold state | drawn only when the fighter has a special |
| **Transform** | on the plate | glyph plus a hold ring that fills over `confirmTicks` (30) | drawn only when a fill is complete or the action is available |
| **Encore** (Empress) | on the plate | the transform glyph, an 18-tick hold ring, and a second ring showing the 180-tick offer's time left | only inside the offer, after she enters the brink |

Sim events UI needs: `press_ack {actor, kind}` with `kind` in `weight_light`, `weight_heavy`, `weight_fallback`, `sig_queued`, `sig_cancelled`, `sig_funded`, `sig_expired`, `sig_fired` (`stage-c-spec.md` section 5); `availability {actor, action, ticks_left}` for transform, special and the Encore offer, so a prompt appears only when the action can be used. `window_open` and `struggle_open` are no longer press cues; whether UI keeps a read-only ring is UI's and Combat's call.

## 6. Test

- A headless check that every action in `input-map.md` has a glyph entry for both `kbd` and `pad` (a missing one fails).
- Rebind an action, then read the prompt: it shows the new key.
- Switch device mid-match (keyboard to pad and back): the prompt changes on the next press.
- AZERTY, QWERTZ and a Nordic layout, on desktop and on the target browsers: the label matches the keycap.
- A colour-blind simulation: no prompt relies on colour.
- **A Legal check before release:** no lettered or coloured face marks, no four-shape layout, nothing lifted from a maker's guide. Legal signs off the art (RL-037).
