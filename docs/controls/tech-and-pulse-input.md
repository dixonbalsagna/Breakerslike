# Input specs: the tech, the pulse-clash and the beam answer

Owner: Controls and Game Feel. Date: 2026-10-01. For **Encounter** (the clash and the beam answer, `sim/director`) and **World** (the tech, the launched fighter's journey). Sources: `balance-targets.md` §20 "Recovering early (the tech)", `rule-of-cool.md` §2, `control-rules.md` §1 and §2, `input-scheme.md`. Whole ticks, 60 a second, like everything in `data/input/timing.json`; every number below is a data key, proposed names in the last section.

None of these needs a new field in the intent record. Each reads an edge or a held direction the layout layer already produces on every layout (keyboard, all three pad presets, touch Simple and Full).

## 1. The tech

**Input: a fresh `dodge` edge.** Dodge is a tap on every layout (Space or Period, the pad's dodge button, the touch flick or button). A tap fires on press with no delay, so the tech has no input latency. A dodge that is already held when the launch happens is not a tap: **the player must press again** (a held dodge that passes 12 ticks becomes `sprint`, which the sim must ignore while the fighter is launched; please confirm it already does).

**When it reads (World's rule, in ticks):**

| Moment | A press is |
| :--- | :--- |
| 4 ticks before a bounce's contact, up to 8 ticks after it | on time. The 4 before is the dodge buffer (`dodge.buffer`) and lets a player who presses as they see the ground still get it |
| any tick of a tumble | on time |
| a skid over 900 | ignored: no ki, no cooldown, `press_ack` says `speed` |
| a slam, water, a break or finisher launch | ignored, `press_ack` says `set_piece` |
| no 15 ki, or inside the 3 s dodge-cancel cooldown | ignored, `press_ack` says `ki` or `cooldown` (the pips by the ki bar already show it) |

- **Touch** gets +2 ticks after the contact (10), as the perfect block's early tolerance does, because a flick is slower than a tap.
- **Hit-stop.** A bounce contact may carry hit-stop. The 8-tick window should **start when the freeze ends**, and a press during the freeze counts as a press on the first live tick (the input stage already runs during a freeze and keeps the edge). A player should never lose the window to a freeze they cannot act in.
- **No lockout on a wasted press.** A press that is early (before the 4-tick buffer), in a skid over 900 or without ki costs nothing and locks nothing. The tech is already paid for by 15 ki and a 3 s cooldown; a lockout would only punish a player for trying. The first valid press wins, so a masher gets it as soon as it is legal, which is acceptable for a recovery.
- **No queueing past a skid:** a press at speed 950 is not remembered until the skid drops under 900. Each press is judged on its own tick.
- **One press, one result.** A tech consumes the edge. The same press must not also be read as a dodge-cancel (there is no exchange, but the order of two interrupts on one tick in `control-rules.md` §2 applies if a launched fighter is inside one: the tech goes **after** the dodge-cancel, since it is the quieter recovery).
- **Assist (accessibility):** the 8 ticks after contact become 16, matching the perfect block's assist factor.
- **Feedback** (UI, VFX, Audio): `press_ack{kind: "tech", ok, why, ticks_from_contact}`. `why` is one of `ok`, `speed`, `set_piece`, `ki`, `cooldown`, `early`. A successful tech flips the fighter to his feet; a failed one is the small acknowledgement and nothing else.

## 2. The pulse-clash

**Input: a fresh `light` or `heavy` edge**, the attack buttons, the same buttons the finisher struggle used. A clash is an attack meeting an attack; nothing new to learn. `sig` and `special` do not count (they cost ki and carry meaning of their own). A clash press is **a press, not an attack**.

**Encounter must not queue it.** While a clash is live, `light` and `heavy` edges from the clashing fighters go to the clash only, and are not passed to `requestAttack`. Otherwise three mashed presses become three queued attacks that fire up to 36 ticks after the clash ends. After the clash, any press in the same tick is spent, not carried over.

**Windows (rule-of-cool §2):** 3 pulses, each with an **8-tick window centred on the pulse tick: from 4 ticks before to 3 ticks after** (the same ±4 as the old struggle beats). **10 ticks on touch** (5 before, 4 after). Assist: windows ×2 and the lockout off. The optional per-player timing offset (−6 to +6, in the match header) shifts the pulse centres for that player only, so replays stay identical.

| A press | Result |
| :--- | :--- |
| inside a pulse's window, once per pulse | a **surge**: +10 to the clash score. A second press in the same window does nothing |
| outside every window | **off the pulse**: that pulse is not missed, but **the next press is locked out for 20 ticks** |
| during a lockout | does nothing, and **restarts the 20 ticks** (the perfect block's rule, so there is one anti-mash rule to learn) |

The restart on a locked press is my reading of "so mashing loses"; rule-of-cool says only that an off-pulse press locks the next press out for 20 ticks. **Game Design to confirm.** The lockout is the clash's own: it does not touch the perfect block's lockout, which belongs to a different button.

**Where the cost lands.** With 3 pulses a few ticks apart, one wild press at the wrong time costs the surge on the next pulse. That is the design. Check the spacing: if pulses are under 20 ticks apart, an off-pulse press just after one pulse locks out the next whole pulse; I want that to be true for a mash but not for a single honest early press, so **pulse spacing of 24 ticks or more** keeps one early press from costing more than one surge.

**Simple layouts need one host call.** Simple fires a light on *release* (the bridge until the queue upgrade), which makes the pulse lag by the length of the press. When a clash is live the layout should fire on *press*. I can build it as `hub.set_clash(slot, on)`, called by the host each tick from the sim state (the same shape as `transform_hold`); it is small and I will do it as soon as Encounter confirms the clash exposes "this slot is in a live clash". Full touch and every pad and keyboard preset already fire on press.

**Feedback** (UI, VFX, Audio): `press_ack{kind: "pulse", result: hit | off | locked, pulse: 1..3, ticks_from_centre}`. The signed offset lets UI show early or late, which is what teaches the timing.

**AI:** 40%, 65% and 85% of pulses (easy, medium, hard), drawn from the seeded RNG at the clash start, not per tick.

## 3. The beam answer (a perfect block against a signature)

**Input: a fresh `guardPress` inside the signature's wind-up window**, exactly the perfect block (8 ticks for a light tell, 10 for a heavy, 4 before the window counts, the 20-tick anti-mash lockout, assist ×2 and no lockout). **No new button**: the beam answer *is* the perfect block, as Game Design ruled.

**The direction picks the look.** Three classes, read from `mx` (the horizontal axis; `my` is ignored, because the answer is about the attacker's side):

| Class | `mx` relative to the attacker (shortest arc) |
| :--- | :--- |
| away | pushing away from the attacker beyond the dead zone |
| toward | pushing toward the attacker beyond the dead zone |
| neutral | inside the dead zone (`stick.awayDead`, 0.3 of full deflection, about 38 on the 1/127 grid) |

- **When it is sampled: at the tick the block resolves (contact), not the tick of the press.** The press has to be inside an 8-tick window, and a player cannot press a button and a direction on the same frame; sampling at the press would turn every slightly late stick into the wrong look. Sampling at contact lets the stick settle inside the window. If the sim wants the press tick instead (to make the look a commitment), tell me, since it changes the hint copy. **Game Design to confirm.**
- **Digital keys and touch** give full deflection (127), so the keyboard's two keys are always away or toward or neither; the dead zone only matters on a stick. On a pad the stick's 16-step quantisation (`stick.quant`) is already in the intent.
- **Toward/away is shortest-arc**, as every distance in the sim, and **flips with the wrap**: the sim must use the sign the escape stance uses (`i.mx * jsign(sdx(f.x, opp.x))` against `SimAct.awayDead`, `sim/core/act.gd:73`), never a fixed screen direction. A player who is flying across the seam toward the attacker is still "toward".
- **Held, not pressed.** Holding the direction from before the press works; the layout does not require it to be fresh. Whoever holds toward while pressing guard walks through the beam.
- **Any input path.** The three results must be reachable on every layout without a new button: keyboard (guard key plus A or D), pad (guard plus stick), touch (the Guard button with the move stick held; the left thumb moves, the right guards). The touch Full layout's move stick is the left thumb, so there is no conflict.
- **Feedback:** `press_ack{kind: "block", result: "perfect", look: away | neutral | toward}`; UI can show the three looks as the three prompts only once a signature's wind-up opens, as the perfect-block prompt does today.

## 4. Data (proposed keys for `data/input/timing.json`)

```json
"tech":    { "bufferBefore": 4, "windowAfter": 8, "touchBonus": 2, "assistFactor": 2, "kiCost": 15 },
"clash":   { "pulses": 3, "window": 8, "touchWindow": 10, "lockout": 20, "surge": 10, "assistFactor": 2 }
```

`kiCost`, `surge` and the pulse spacing are Game Design's and Encounter's, not mine; they sit here so the input side reads one file. I will add these keys and their validator rows the moment Encounter or World confirms the names (the schema is Tools'; a patch if it needs one). The beam answer adds nothing: it uses `perfectBlock` and `stick.awayDead`.

## 5. What I need back

- **World:** the tech's tick source for "contact" and whether hit-stop starts the window after the freeze (§1).
- **Encounter:** clash presses bypass `requestAttack` (§2); a "slot is in a live clash" flag the host can read; the direction sample at contact (§3).
- **Game Design:** the lockout restart on a locked press (§2); the direction sample at contact or at the press (§3).
