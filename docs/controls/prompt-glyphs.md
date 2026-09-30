# Prompt glyphs per device

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
| Light (also parry, chain, struggle) | F | , | diamond, west filled |
| Heavy (also parry, chain, struggle) | G | . | diamond, north filled |
| Signature | R | / | diamond, east filled |
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

| Prompt | Where | Content | Timing |
| :--- | :--- | :--- | :--- |
| **Parry** | on the parry ring (crown) | the light glyph large, the heavy glyph small ("either") | drawn for the window's `dur_ticks`; the clean-parry sector (last 6 or 8 ticks) is a brighter band |
| **Chain** | on the chevrons | light glyph (extend), heavy glyph (cash out) once Combat's link grammar exists | drawn for 36 ticks |
| **Struggle** | on the beat rings | one glyph (light), heavy small | rings at −18 and 0 (count-in), then 18, 36, 54 ticks from `contestOpen` |
| **Signature** | on the ki chip | glyph plus `NEED 45 CHARGE` when short (glossary) | while ki < 45 and the button is pressed |
| **Stance** | on the stance chip | four positions with the glyph for each; the current one filled | in training, at match start for 3 s, and whenever the stance changes |
| **Special / Transform** | on the plate | glyph plus a hold ring that fills over `confirmTicks` (30) for transform | drawn only when the action is available |
| **Encore** (Empress) | on the plate | the transform glyph, an 18-tick hold ring, and a second ring showing the 180-tick offer's time left | only inside the offer, after she enters the brink |
| **Press acknowledged** | small mark at the fighter | `hit`, `early`, `locked` as three distinct shapes | within 2 ticks of the press (`press_ack`) |

Sim events UI needs: `window_open {actor, kind, dur_ticks, clean_ticks}`, `press_ack {actor, kind, result}`, `struggle_open {actor, beats[], half_width}`, and `availability {actor, action, ticks_left}` for transform, special and the Encore offer, so a prompt appears only when the action can be used.

## 6. Test

- A headless check that every action in `input-map.md` has a glyph entry for both `kbd` and `pad` (a missing one fails).
- Rebind an action, then read the prompt: it shows the new key.
- Switch device mid-match (keyboard to pad and back): the prompt changes on the next press.
- AZERTY, QWERTZ and a Nordic layout, on desktop and on the target browsers: the label matches the keycap.
- A colour-blind simulation: no prompt relies on colour.
- **A Legal check before release:** no lettered or coloured face marks, no four-shape layout, nothing lifted from a maker's guide. Legal signs off the art (RL-037).
