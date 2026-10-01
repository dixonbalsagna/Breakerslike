# Two players at once: latency, the queue, fairness and the shared keyboard

Owner: Controls and Game Feel. Date: 2026-10-01. Measured by `sim/input/test/mash_probe.gd` (6 hard checks, through the real sim and the real queue):

```
godot --headless --path . --script res://sim/input/test/mash_probe.gd -- --seeds=12 --ticks=2400
```

## Verdict

Two people mashing at once is **fair and instant**. Two things to know, neither a bug in the input layer: a perfectly periodic mash can phase-lock the queue (below), and a shared keyboard has a hardware ceiling (below).

## Latency: 0 ticks

A press while the director is free starts its exchange **on the same tick**, for slot 0 and for slot 1 alike (the check runs both). Nothing in the input path adds a tick: a tap fires on press, and the hub hands each slot its own intent. The only deliberate delay is the Simple layouts' light-on-release bridge (a light fires when the button comes up), which goes when Encounter's queue takes the held-attack upgrade.

## The queue (Encounter's, `sim/director/exchange.gd`)

| Rule | Measured |
| :--- | :--- |
| Depth 3 | ten presses in ten ticks during an exchange leave exactly 3 queued; the rest are dropped |
| Expiry 36 ticks | waiting requests are gone after 40 ticks |
| One exchange at a time | the oldest request starts first; slots alternate on a tie |

Both numbers stand. Do not raise the depth: a deeper queue makes a masher's stale presses fire half a second after they stopped.

## Fairness: nobody starves the other

Starts of exchanges over 12 seeds of 2400 ticks (about 40 s each), through the queue:

| Scenario | P1 starts | P2 starts | Verdict |
| :--- | ---: | ---: | :--- |
| both mash every 4 ticks | 318 | 318 | 50/50, longest run by one player 3 |
| both jittered around 6 ticks (what mashing really is) | 311 | 325 | 49/51 |
| both jittered around 12 ticks | 328 | 327 | 50/50 |
| P1 mashes (4), P2 presses about every 20 ticks | 240 | 176 | the patient player still gets 42% of the starts on 1/5 of the presses |
| P1 mashes (4), P2 presses about every 40 ticks | 129 | 63 | the patient player gets 33% on 1/11 of the presses |

So mashing buys little: eleven times the presses buys twice the starts. That is the design (experts beat mashers).

**The artifact.** Two players pressing at *exactly* the same fixed gap (every 7 or 12 ticks, no jitter) can phase-lock: the oldest request wins, and the attacker's own queue entries keep their old timestamps, so one player can take up to 19 (gap 7) or 54 (gap 12, in two of twelve seeds) consecutive starts. Human hands never hold a gap to the tick (the jittered rows above are fair), so this is not a live problem. If Encounter wants it shut for good: **on a tie of age, prefer the fighter who did not start the last exchange**, or clear the finished attacker's stale queue entries at the end of an exchange. Encounter's call; I changed nothing.

## The shared keyboard: what hardware allows

The sim reads every key independently, so any two-player combination is fine **if the keyboard reports it**. The limit is the keyboard:

- **Keys held at once, per player, in a real fight:** diagonal flight (2 movement keys), sprint (Space or Period held), one attack, and Guard (a modifier on the left half, a normal key on the right). That is **4 normal keys, 5 with Shift**, per player at the extreme, 3 at a typical busy moment. Two players: **up to 8 normal keys**, typically 6.
- A keyboard with **6-key rollover** (the USB boot standard: 6 normal keys plus modifiers, common on office keyboards and many laptops) drops keys in the 7-and-8 moments. A keyboard with **N-key rollover** (most gaming boards) never does. Membrane and laptop matrices can also lose particular 3-key combinations (a "ghost" or a blank) well below their rollover.
- **Windows Sticky Keys:** five quick Shift presses open its dialog and steal focus. Player one's Guard is Shift, so a mashed perfect block can do it. Turning off the shortcut (Settings, Accessibility, Keyboard, Sticky keys, "Allow the shortcut key to start Sticky Keys") removes the risk; the web build cannot prevent it. Worth one line on the How to play screen's shared-keyboard note.
- **Firefox Quick Find:** `/` and `'` can open a find bar when the page does not swallow the key. Player two's Power key is `/`. Rendering: make sure the web build calls `preventDefault` for the layout keys while a match runs; I list it as manual check 14 below.
- Keys are named by **physical position** (`KeyboardEvent.code`), so AZERTY, Dvorak and other layouts keep the same shape.

**What to do about it.** The real answer is the one built: a pad per player, or a pad beside the keyboard. The shared keyboard is the fallback and is honest as one: the hints can say "two on one keyboard works best on a gaming keyboard". Nothing in the layout can be cut without losing a button; if a playtest shows real loss, the cheapest relief is an **assist "auto-sprint" while both are held** (sprint on Dodge hold is the key that pushes the count over), which is a sim-side toggle I would specify then, not now.

### Manual check for Orb, 14

Add to the list in [local-two-player.md](local-two-player.md): on the shared keyboard, **both players hold their heaviest set at once** (left: W, D, Space, F and Shift; right: I, L, Period, H) for three seconds and fly. Note which keyboard it was and which fighter stops moving or attacking. Then open the web build in Firefox and press `/` and `'` during a match: no find bar may open.
