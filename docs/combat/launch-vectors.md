# Launch vectors and landings: what Combat's pieces must change

Owner: Combat and Choreography (the launch-vector vocabulary and the reaction pieces). Scoring is Encounter's; landing physics is World's. Date: 2026-10-01. Status: note and plan; no data or code.

**Why.** Game Design ruled on landings (`docs/design/balance-targets.md` section 19) and on how a launched fighter crosses the ground (section 20). Orb wants landings "weighted towards skidding to a halt", fighters knocked about (skid, tumble, bounce, fly off a crater's lip), and craters kept as events. QA measured today's launches as slam-first: 54% slams and 25% slides.

**The target mix** (share of all launches): slide 40 to 60%, slam 12 to 25%, caught in the air 10 to 25%, water 5 to 15%, brunt 4 to 10%. Section 20 adds a bounce class.

---

## 1. The vectors today
From `sim/director/launch.gd`, as direction (along the launcher's facing, up):

| Vector | Direction today | Where it lands today |
| :--- | :--- | :--- |
| UPPERCUT | (0.25, 1.0): nearly straight up | falls back steeply: a slam |
| SLAM DOWN | (0.2, −1.25): nearly straight down | a slam |
| SMASH ACROSS | (1, 0.32), at double force: the long haul | shallow: a slide |
| BRUNT (BUILDING SMASH; MOUNTAINSIDE until World's D2) | toward a structure | a brunt |

Two of the three open-ground vectors are steep, which is why slams dominate.

## 2. What changes

| # | Piece | Change | Why |
| ---: | :--- | :--- | :--- |
| 1 | **SLAM DOWN becomes a drive, by default** | Down and forward at **25 to 50 degrees below level** (Game Design's ruling, section 19). The angle has no draw: 25 degrees when the rival is within 2 bh of the ground, rising evenly to 50 degrees at 12 bh and above. As a direction: (0.91, −0.42) at 25 degrees to (0.64, −0.77) at 50 | Section 19, step 2. Section 20 treats a 30 to 70 degree contact as a bounce, so Combat's first proposal of 40 to 55 would have made every drive a bounce. With 25 to 50, a low drive (under 30 degrees) skids at once, and a drive from height bounces once and then skids: "ploughs in and skids to a halt" |
| 2 | **The straight-down slam is kept as its own, gated vector** (working label CRATER SLAM; Narrative names it) | Direction (0.2, −1.25) as today. Offered only for: a break or finisher launch; a rival **directly below** the attacker, meaning within 1 bh sideways and at least 3 bh lower; and the planner's crater set piece, at tier 3 or above, at most once every 30 s per fighter (Game Design's gates) | Section 19: "a slam is an event and a slide is the norm". Craters keep their weight (pillar 4) |
| 3 | **UPPERCUT gets more forward carry** | From (0.25, 1.0) to about (0.45, 1.0), so its fall meets the ground at under 70 degrees. Only if slides are still under 40% after changes 1 and 2 | Section 19, step 3 |
| 4 | **Each vector declares its angle band and intent** | New fields on the vector vocabulary: the angle range, the intent (`drive`, `loft`, `across`, `crater`, `brunt`) and its gates. The planner can then predict the landing class and hold the bands | Encounter scores; Combat owns the vocabulary |
| 5 | **Reaction pieces for the journey** | The fighter's own reaction set (`moveset-system.md` section 1.1) grows from 12 to 15. It already has skid, bounce, splash, embed, knock-away and crumple. It adds: **tumble** (a roll, up to 1.2 s), **lip launch** (thrown clear off a rim, back to airborne), and **tech flip** (the dodge-tap recovery). It also needs two get-ups: quick (0.35 s, after a skid or tumble) and slow (0.75 s, after a slam) | Section 20's states: airborne, skid, bounce, slam, tumble, skip, down |
| 6 | **The chain link's small pop** | No change to the vector. If nobody catches the body, its contact is slow (350 to 900), so it tumbles and gets up quickly | Section 20 |
| 7 | **The blitz intercept reads the whole journey** | `blitz.md` section 1.2 predicts the body's flight. It must use World's journey prediction (bounces, skips and lips included), and prefer an intercept **before the first contact**, which is the "caught in the air" class | Sections 19 and 20: the journey is deterministic, so the planner can predict it |

## 3. Pieces that already fit

| Piece | Fits because |
| :--- | :--- |
| KAI's finisher (final blow skyward) and VORR's finisher (a slam, then the planner's long launch) | finisher launches keep the straight slam and their own vectors |
| The dive grab ("a slam straight down") | it is the "rival directly below" case when the rival is at least 3 bh lower and within 1 bh sideways. Otherwise it ends in the drive |
| The ground-brawl style's launch hints | `ground_throw` is a low throw (a skid). `ground_slam` becomes the drive by default, and the straight slam only under the gates in change 2 |
| Throws from a grab (`moveset-system.md` section 9.9) | toward: across (a skid); neutral: "a slam down" becomes the drive unless the rival is directly below; away: a back throw |
| SMASH ACROSS and brunts | unchanged |

## 4. What others need from this
- **Encounter:** the drive and the gated crater slam as candidates; the angle rule; the vector fields in change 4 when the vocabulary moves to data; the journey prediction in the intercept planner.
- **World:** the 94% slam threshold and the section 20 states. Combat's reaction pieces follow World's state names.
- **Animation:** the three new reactions and the two get-ups.
- **Game Design:** done. The two-vector split is confirmed, the drive's angle is set at 25 to 50 degrees by altitude, and the crater slam's gates are as written in change 2.
- **QA:** the landing mix per vector, so each vector's class is checked against its intent.
- **Narrative:** a label for the gated straight slam, and whether SLAM DOWN keeps its name now that it is a drive.

## 5. A target behind the launcher: the turn throw
**Why.** Since the contact slice no launch goes back through the launcher (`docs/director/contact-plan.md`, rule 8), so a building or a slope behind the launcher is no longer offered. MOUNTAINSIDE fell from 24.3% to 14.6% of launches.

**Answer: yes, a turning throw should exist.** It is an entry to a launch, not a new vector, and it is not urgent.

| | |
| :--- | :--- |
| **What it is** | The launcher takes hold of the body at contact distance, turns half way round carrying it (the pair swaps sides), and releases it along the planned vector. The body goes round the launcher, never through it |
| **The piece** | The back throw already planned for the grab (`moveset-system.md` section 9.9: "away: a back throw, over the shoulder"). The same poses; here the director picks it. No extra piece for Animation |
| **What it costs** | 10 ticks before the release: hold 2, turn 8 (the step-around's length). The launch and every beat after it move back by that much |
| **When a rear target may be offered** | All three: (a) it is a brunt target (a structure, a formation, MOUNTAINSIDE until World's D2); (b) the launch follows a heavy, an ender, a guard break or a finisher strike, never a light string's launch or a chain link's pop; (c) the body is held at contact, not already flying |
| **Scoring** | The candidate's usual score less a turn cost, so a forward target of equal worth wins. The variety and personality terms apply as usual: VORR turns for a populated tower, KAI for an empty formation |
| **Sides** | The one cross-over outside the dodge. The planner picks it at launch time, so it is not a `"side": "cross"` beat: the launch event says it turned, for the animator and the camera. A branch's `endSides` keeps describing the authored beats up to the launch |

**Why it is not urgent.** The landing band for brunts is 4 to 10% of launches. After the contact slice brunt landings are 4.0% (up from 2.9%, probably because a forward launch now reaches its target). So the band holds without it. What the turn throw buys is variety and personality: the rear MOUNTAINSIDE targets alone were about 10 points of launches, and the villain's pull toward a tower works in both directions again.

**Staging.** Build it with the grab and throw family at M0, when the back throw's poses exist. No data now. Until then forward-only stands.

**Needs.** Game Design: the gates in the table, and whether the turn costs ki. Encounter: the rear candidates, the turn cost in the score, the turn move. Animation: nothing beyond the back throw.
