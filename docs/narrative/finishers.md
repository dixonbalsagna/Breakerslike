# Finishers: placeholder names and barks

Owner: Narrative and Fighter Identity. Version 1, 2026-09-29. Companion to Combat's `data/combat/finishers.json`. **Every name here is a placeholder label. Orb names things later.** Lines are original and unsearched.

**Where the barks fire.** A finisher ends the match unless the loser wins the contest. Two bark moments matter (they match the data's outcomes):
- **`finisher_landed`** fires at the `last_look` cue (the camera pushes in, and a bark pause runs before the final blow). It is the winner's line.
- **`finisher_survived`** fires when the loser breaks the hold and the `holds_on` cue plays (HOLDS ON). There are two lines: the winner's reaction, and the survivor's own line.

Both pick a line by the **matchup register** (`line-system.md` section 10), so a sparring win sounds different from a world-ender's.

## 1. The finishers and their placeholder names

| Data id | Fighter | Placeholder name *(placeholder)* | What it is (from the data) |
|---|---|---|---|
| `generic` | any fighter without their own | **Finishing Blow** | Catch, two strikes, a final windup, the contest, then a blow. |
| `kai` | KAI (the prototype hero; a legacy placeholder) | **Skyward Lance** | Catches the foe in flight, a three-blow flurry, then rises and drives a point-blank lance skyward. |
| `vorr` | VORR (the prototype villain; a legacy placeholder) | **The Display** | Seizes by the throat, headbutts, slams, stomps, then hoists the foe toward the nearest settlement. |
| `protagonist` | The Protagonist | **Everything** | An all-out energy finisher: catch, a ripple-step flurry of teleport strikes, a rise and gather, the contest, a point-blank all-out blast. |
| `antihero` | The Anti-hero | **The Verdict** | Finish by hand: an energy barrage until the loser submits, then a close-in hand finish, no beam. |
| `empress` | The Empress | **Clean Cut** | A precise cutting finisher: cutting beams pin the loser, train strikes, the contest, one exact cutting beam. |
| `cyborg` | The Cyborg | **Last Orders** | Portal blitz and devour: a blitz from several portals, a seize, the contest, the devour (graphic; Mature rating). |

(The names avoid Legal's banned patterns: no "Final ___", "Big Bang ___", "Spirit ___" or "Special ___ Cannon".)

## 2. The barks

Each block gives the **landed** bark (the winner's last look), then the two **survived** lines (the winner's reaction and the survivor's own line). Alternates are separated by a slash. Register is the matchup register in bold.

### The Protagonist: *Everything* (placeholder)

| Register | Landed (winner) | Survived: the winner reacts | Survived: the survivor's line |
|---|---|---|---|
| **playful** (a sparring rival or mirror) | "That's it. That's the one. Thank you." / "Ready? ...Everything!" / "Hold still, friend. This is the best one." | "You're kidding! ...Good. Again!" / "Ha! How? I love it." | (see the survivor block below) |
| **grim** (a world-ender) | "It ends here. Nobody else pays for you." / "I'm sorry. I'm not stopping." / "Everything. All of it. Now." | "No. Stay down. Please stay down." / "You're still standing. Fine. I'll hit harder." | |

*As the survivor (the Protagonist holds on):* "Not yet. I'll be fine in a minute." / "Ha! Nope. Not today." / "Hold on. Hold on. I've got one more."

### The Anti-hero: *The Verdict* (placeholder)

| Register | Landed (winner) | Survived: the winner reacts |
|---|---|---|
| **contemptuous** (a rival or mirror) | "You were adequate. This is the verdict." / "Fourth. Behind the goons. Sit down." / "The court has ruled. It ruled ages ago." | "You are still here. That is not a compliment." / "Persistent. Vulgar." |
| **disgusted** (the Empress or the Cyborg) | "Filth. Be quiet." / "You were noise. Now there is none." / "This is the last thing you will not deserve." | "Stay down. Filth." / "Die properly." |

*As the survivor:* "This does not count." / "I did not fall. I chose the floor." / "Do not look at me." If his facade has cracked: "I can't... I'm still here." / "Don't. Don't look."

### The Empress: *Clean Cut* (placeholder)

| Register | Landed (winner) | Survived: the winner reacts |
|---|---|---|
| **leering** (the Protagonist, the Anti-hero) | "Hold still, petitioner. It is a precision matter. ...Clean cut." / "One line. No corrections needed." / "Sign here." | "We will have that in writing! Try again!" / "How irregular. You were supposed to stop." |
| **condescending** (the Cyborg, the mirror) | "We will take that as your complaint. ...Denied." / "Our guard is waiting outside. So is your ending." | "Rude! We were mid-sentence!" / "That is not how the procedure goes." |

*As the survivor:* "We are not hurt. We are pending." / "That was a very rude interruption of a very good cut!" / "Guard! A moment, please!" (if any guard remains)

### The Cyborg: *Last Orders* (placeholder)

| Register | Landed (winner) | Survived: the winner reacts |
|---|---|---|
| **polite menace** (all opponents) | "Your order is coming. Please look at the portal." / "Table for one, with a view. Enjoy." / "The chef recommends the finale." | "I am sorry, that is not on the menu. Try again." / "Sir, you were supposed to be delicious." |
| **polite, to his own kind** (the mirror) | "After you. ...No, after you. ...Oh, all right, me." | "You have kept your seat! Rude, and impressive." |

*As the survivor:* "Not the chip! ...It's fine. It's fine." / "One moment. Rebooting." / "I demand a second serving."

### KAI, VORR and the generic finisher (legacy)

| Fighter | Landed | Survived: the winner reacts | As the survivor |
|---|---|---|---|
| **KAI** (*Skyward Lance*) | "Sorry, friend. This is the last one." / "Hold on tight!" | "You held! ...Good." | "Not yet!" |
| **VORR** (*The Display*) | "Look. It was lovely." / "Let it be the last thing you see." | "You hold. How interesting." | "So. It is not yet the end." |
| **Generic** (*Finishing Blow*) | "That's the one." / "It's over." | "Not over." | "Not yet." |

## 3. Notes

- **Registers.** The register comes from the matchup and shifts with the fight. The Protagonist's landed line is warm against a friend and grim against a world-ender, and his survived reaction changes with it.
- **Data hooks (suggested).** In `finishers.json` a finisher can carry `bark_landed` and `bark_survived` as trigger ids (`finisher_landed`, `finisher_survived`), so the line system selects by fighter, register and outcome. Combat owns the format.
- **The bark pause.** The `last_look` cue already includes a bark pause. Landed lines should be short (about two seconds), so the final blow is not delayed.
- **The Empress's fold.** Her `Clean Cut` uses "Sign here" as a leer, in her voice only. There is no visible paperwork (Orb's rule).
- **Cyborg graphic content.** The devour is graphic. The bark stays polite, and the store content rating is still unchecked.
