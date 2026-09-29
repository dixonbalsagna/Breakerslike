# Prompt glyphs per device

Owner: Controls and Game Feel (the binding-to-glyph map and rules). UI/UX draws and places the glyphs (`docs/ui/hud-spec.md` §11 asks for this). Date: 2026-09-29. Bindings are in `input-map.md`.

## 1. Rules

1. **A prompt shows the glyph of the device that last sent input for that slot.** If the player presses a key, then a pad button, the prompt changes on the next press. No device menu.
2. **The glyph always matches the active binding**, including after a rebind. It is looked up from the live binding, never hard-coded.
3. **Keyboard glyphs show the key's label on the player's layout**, not the QWERTY position. Bindings are physical keycodes, so an AZERTY player who binds "the F position" sees `F` on their own keycap letter for that position. Godot 4.4+ has `DisplayServer.keyboard_get_label_from_physical`; on the web build it may be unavailable, in which case the QWERTY label is shown and the tooltip says "key position". To test on the target browsers.
4. **Pad glyphs are positional.** `JOY_BUTTON_A/B/X/Y` are south, east, west, north on every pad, so the same binding shows a different label per family: the picture is the same, the printed mark differs.
5. **Never colour alone** (HUD spec §13): every glyph has a shape or a letter, and hold prompts have a fill ring.
6. **Where and when:** prompts are drawn on the crown windows and the fighter's plate, not over the fighters. They show always in training, in the first three matches and when **Show prompts** is on; otherwise only the cue (ring, chevrons) is drawn.
7. **Originality and trademarks:** the default glyph set is **our own**: a neutral "position diamond" (the four face positions, the pressed one filled) plus a short text mark. We do not reproduce a console maker's button icons as art. **Flag to Legal via the EP:** whether any platform's face symbols or colours may be used at all in an open-source release; until answered, only the neutral diamond and letters ship.

## 2. Device families

Detected from `Input.get_joy_name(device)` and the GUID, case-insensitive:

| Family | Match on | Face marks (south, east, west, north) | Triggers, bumpers |
| :--- | :--- | :--- | :--- |
| `xbox` | "xbox", "xinput", "microsoft" | A, B, X, Y | LT, RT, LB, RB |
| `ps` | "playstation", "dualshock", "dualsense", "ps4", "ps5", "sony" | positions only, marked by letter `S E W N` in the neutral set | L2, R2, L1, R1 |
| `switch` | "nintendo", "switch", "joy-con", "pro controller" | B, A, Y, X (physical layout) | ZL, ZR, L, R |
| `deck` | "steam" | as `xbox` | L2, R2, L1, R1 |
| `generic` | anything else | positions only: `S E W N` | LT, RT, LB, RB |
| `kbd` | keyboard input | key labels | n/a |
| `touch` | touch input | on-screen shapes (`platform-plan.md` §7) | n/a |

A user override ("Glyph style") can force a family. The neutral position diamond is the fallback and the default until Legal answers rule 7.

## 3. Action to glyph, per device

The label is the mark a player sees; the second line is the underlying binding. `prev` and `next` are the stance cycle.

| Prompt | Keyboard P1 | Keyboard P2 | `xbox` / `deck` | `ps` | `switch` | `generic` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Light (also parry, chain, struggle) | F | , | X | west mark | Y | west |
| Heavy (also parry, chain, struggle) | G | . | Y | north mark | X | north |
| Signature | R | / | B | east mark | A | east |
| Dash (hold) | Space | Enter | A | south mark | B | south |
| Charge (hold) | Q | ; | RT | R2 | ZR | RT |
| Special (hold) | E | ' | LT | L2 | ZL | LT |
| Transform (hold to confirm) | X | [ | R3 (click) | R3 | R3 | R3 |
| PRESS (direct) | 1 | 7 | D-pad up | D-pad up | D-pad up | D-pad up |
| GUARD | 2 | 8 | D-pad right | same | same | same |
| DODGE | 3 | 9 | D-pad down | same | same | same |
| ESCAPE | 4 | 0 | D-pad left | same | same | same |
| Stance previous / next | ` / 5 | 6 / - | LB / RB | L1 / R1 | L / R | LB / RB |
| Move | W A S D | arrows | left stick | left stick | left stick | left stick |
| Pause | P | P | Start | Options | + | Start |

Note for the Switch family: the pad's physical **south** button is labelled **B**, so the "A" mark in the Xbox column is the same physical position as the "B" mark here. The prompt follows the family's label for that position.

## 4. Prompt kinds and what they carry

| Prompt | Where | Content | Timing |
| :--- | :--- | :--- | :--- |
| **Parry** | on the parry ring (crown) | the light glyph large, the heavy glyph small ("either") | drawn for the window's `dur_ticks`; the clean-parry sector (last 6 or 8 ticks) is a brighter band |
| **Chain** | on the chevrons | light glyph (extend), heavy glyph (cash out) once Combat's link grammar exists | drawn for 36 ticks |
| **Struggle** | on the beat rings | one glyph (light), heavy small | rings at −18, 0 (count-in), then 18, 36, 54 ticks from `contestOpen` |
| **Signature** | on the ki chip | glyph plus `NEED 45 CHARGE` when short (glossary) | while ki < 45 and the button is pressed |
| **Stance** | on the stance chip | four positions with the glyph for each; the current one filled | in training, at match start for 3 s, and whenever the stance changes |
| **Special / Transform** | on the plate | glyph plus a **hold ring** that fills over `confirmTicks` (30) for transform | drawn only when the action is available |
| **Press acknowledged** | small mark at the fighter | `hit`, `early`, `locked` as three distinct shapes | within 2 ticks of the press (`press_ack`) |

Sim events UI needs (added to the wish list): `window_open {actor, kind, dur_ticks, clean_ticks}`, `press_ack {actor, kind, result}`, `struggle_open {actor, beats[], half_width}`, and `availability {actor, action}` for transform and special (so the prompt appears only when it can be used).

## 5. Text mark set (neutral, drawn by UI)

For the neutral set: `S E W N` for south, east, west, north; `LT RT LB RB` for triggers and bumpers with `L2 R2 L1 R1` as the `ps` labels; `D↑ D→ D↓ D←` drawn as a small D-pad shape, never as arrow characters (the web fallback font has no `→`, HUD spec §9; UI draws arrows as vectors). Keyboard glyphs use the keycap label in a rounded box; long labels shorten (`Space`, `Enter`, `Esc`).

## 6. Test

- A headless check that every action in `input-map.md` has a glyph entry for every family (a missing one fails).
- Rebind an action, then read the prompt: it shows the new key.
- Switch device mid-match (keyboard to pad and back): the prompt changes on the next press.
- AZERTY, QWERTZ and a Nordic layout on desktop and on the target browsers: the label matches the keycap.
- A colour-blind simulation: no prompt relies on colour.
