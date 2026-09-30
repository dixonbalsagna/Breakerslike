# Grunt palettes and how to make them for free

Owner: Audio and Music. Version 1, 2026-09-29. Companion to `direction.md` (section 7 is the system design). The gestures come from Narrative's voice bibles (`docs/narrative/voices/`) and the line system (`docs/narrative/line-system.md`). Twelve grunts exist as sounds: `effort.heavy`, `pain.head` and `pain.limb` for the Protagonist and the Anti-hero (working) and, as **placeholders** so every sound family has a voice until the F-slices, the same three for the Empress and the Cyborg (a higher theatrical voice, and a tight saturated one; her cackle and his static, chirp and munch are still plans). Earlier: six grunts exist as working sounds (`effort.heavy`, `pain.head` and `pain.limb`, each for the Protagonist and the Anti-hero); everything else in the tables is a plan. `pain.head` and `pain.limb` are the generic wear-scaled pain grunts from `line-system.md`.

**Not yet listened to by a person.** The working grunts were checked with numbers and spectrograms (pitch track, level, spectrum), not by ear. Synthesised laughs in particular are the hardest thing here, and I expect to need Orb's ears, and possibly Orb's voice, to get them right (route B, below).

## 1. How the synthesiser is controlled

One engine makes every vocal gesture: a pulse train (the vocal folds) plus breath noise, shaped by moving resonances (the mouth). A gesture is a row of numbers in `audio/data/grunts.json`. These are the knobs and what they do to the listener:

| Knob | Sets | Perceived as |
| :--- | :--- | :--- |
| `f0` start and end, `f0_tau` | The pitch and how fast it settles | Size and mood. A drop is effort or authority; a rise is a question or a laugh; low is heavy or cold |
| `f0_jitter`, `shimmer` | Cycle-to-cycle wobble in pitch and loudness | Age, strain, rough. High values are ragged or hurt |
| `open` | How open the vocal fold pulse is | Low is pressed and bright (strain, anger); high is soft and breathy |
| `fry` | Every other cycle quieter | A growl, a creak; the cold, low fry of a held-back voice |
| `vowel_a`, `vowel_b`, `glide` | Three resonances and how they move | The vowel: "ah", "aw", "oh". A glide from open to closed is an exhale or a "hah" ending |
| `breath`, `h_onset` | Noise level, and the breath before the voice | A gust or a sigh; the "h" of "hah" |
| `attack`, `hold`, `t60` | The loudness shape | Sudden effort against a lingering sigh |
| `chest` | A low resonance on the source | Body, the feeling of a big chest |
| `drive` | Saturation | Power and strain; too much is a rasp |

Female and small voices raise the resonances by 15 to 20% and the pitch by an octave. Mechanical voices add a bit-crusher and ring modulator after the engine (a planned post stage, not built yet).

## 2. The palettes

Difficulty is how hard the gesture is to make convincing by synthesis alone: easy, medium or hard. Route is the recommended way to make it: **S** synthesis, **H** hybrid (synthesis plus recorded breath or texture layers), **R** Orb's recording, processed. Variants are the number of different renderings per gesture (three by default).

### 2.1 The Protagonist

Register: a warm baritone to tenor, pitch 110 to 180 Hz, open "ah" vowels, smiling. Never harsh, never cruel: **no cruel laugh** (voice bible). The delight shows in how quickly a gesture comes back up.

| Gesture | Sound | Difficulty | Route |
| :--- | :--- | :--- | :--- |
| `effort.light` | A short "hup" or "hn", 0.12 s, pitch falling | easy | S |
| `effort.heavy` | A hearty "hah": breath, then an open vowel, pitch 178 to 118 Hz, 0.36 s **(working, `voice.protagonist.effort.heavy`)** | easy | S |
| `wince` | A hiss through the teeth, then a small "ss-ah" | medium | S |
| `pain.head` | A sharp, high "eh-ow": pitch 230 to 160 Hz, a sudden start, strained **(working)** | easy | S |
| `pain.limb` | A strained "aw" through the teeth: pitch 150 to 105 Hz, more breath, a longer fall **(working)** | easy | S |
| `laugh.short` | A delighted "hah": one bright pulse, pitch up then down | medium | H |
| `laugh.long` | A full, warm laugh: 4 to 6 pulses that decay, a little pitch wobble, a breath in | hard | H or R |
| `sigh` | A happy exhale after a good hit: long breathy "haa", falling | easy | S |
| `gasp` | An inhale: a reversed-envelope breath with a voiced start | medium | S |
| `roar` | Only at the top of a transformation: "aah" from 200 to 300 Hz, saturated, slow vibrato | medium | S |
| `steam` | A long breath at Hot Blood, with a whistle-like partial high in the noise (ties to the heat track's kettle) | medium | S |

About 11 gestures, 3 variants each: 33 clips.

### 2.2 The Anti-hero

Register: low, pitch 70 to 110 Hz, pressed (a low open quotient), a creak in the fry, held back. No warm laugh. He never shouts: even the effort is a pressed exhale. When his facade cracks (Pride below half) the palette changes to `ragged`.

| Gesture | Sound | Difficulty | Route |
| :--- | :--- | :--- | :--- |
| `effort.light` | A clipped low "hn" | easy | S |
| `effort.heavy` | A low pressed exhale, pitch 104 to 72 Hz, creak, 0.42 s **(working, `voice.anti_hero.effort.heavy`)** | easy | S |
| `pain.head` | Pressed and suppressed: pitch 130 to 90 Hz, creak, quieter than the Protagonist's. He hides pain **(working)** | easy | S |
| `pain.limb` | The same, lower and longer, pitch 110 to 80 Hz **(working)** | easy | S |
| `growl` | From the chest: strong creak, noise, a slow swell and fall | easy | S |
| `sneer` | A short exhale through the nose: a nasal noise band with a quick fall | medium | S |
| `scoff` | One dry puff, "tch" or "ha", barely voiced | medium | S |
| `sigh` | A flat, cold, single exhale | easy | S |
| `laugh.dry` | A single breath "ha", barely voiced, then nothing | medium | S |
| `roar` | Only when transforming: low, big, saturated | medium | S |
| `ragged` | After the facade cracks: breath and voice, unsteady, the pitch 20% higher, high jitter, breaks | hard | H |
| `swallow` | "A grit and a swallow": a throat click and gulp | hard | R |

About 12 gestures: 36 clips. This is the fighter synthesis suits best: the voice is low, held back and mostly breath.

### 2.3 The Empress

Register: theatrical, pitch 190 to 300 Hz with the resonances up about 17%. Every gesture leans on the joke (she rides her own laughs). Nothing sincere. She uses "we" and slips to "I": the grunt palette slips too, from a controlled laugh to a plain, short shriek.

| Gesture | Sound | Difficulty | Route |
| :--- | :--- | :--- | :--- |
| `cackle` | A wheeze that builds: a pulse train of voiced bursts speeding from 5 to 9 Hz while the pitch climbs 260 to 380 Hz, with a wheezing inhale between; 1.2 to 2 s | hard | H or R |
| `snort` | A nasal blast: a low-passed noise burst with two nasal resonances | medium | S |
| `laugh.cruel` | Low and staccato: "ha. ha. ha.", slower than the cackle, chesty | hard | H |
| `shriek` | Escalating: pitch 350 to 700 Hz, saturated, fast vibrato | hard | H |
| `sigh` | Theatrical: a long exhale sweeping down with vibrato | easy | S |
| `sigh.heavy` | The weary sigh of someone facing a mountain of paperwork: lower, longer, more breath, a glottal shake | medium | S |
| `pain.head`, `pain.limb` | Indignation first: a short outraged shriek that slips to plain "I" (higher, thinner) as wear grows | medium | S |
| `growl` | Short and sharp | easy | S |
| `hm` | A leering hum: nasal, gliding up and down | easy | S |
| `mutter` | Form numbers, indistinct: a low murmur of pseudo-syllables at about 5 a second, the resonances moving | medium | S |
| Guard unison | "Hup!" from three men at once, slightly detuned and offset (the recall call and the salute) | medium | S: three effort grunts summed |

About 12 gestures: 36 clips, plus the guard chorus. The cackle and the laugh are the two sounds I would most want a person to perform.

### 2.4 The Cyborg

Not a voice box: a polite machine with an appetite. Most gestures are not vocal, so synthesis is easier here than for anyone. He speeds up when hungry and never raises his voice.

| Gesture | Sound | Difficulty | Route |
| :--- | :--- | :--- | :--- |
| `static` | A growl with interference: the voice engine with a bit-crusher, ring modulator and noise dropouts | medium | S |
| `munch` | Crunching: a wet, granular crunch, about 8 to 12 bites a second, with squelch | medium | R is best: record biting a cracker, celery or a sandwich (graphic and funny) |
| `chirp` | A cheerful digital ping: a two-tone FM blip, 1.2 then 1.8 kHz, 80 ms, with a tiny reverb | easy | S |
| `servo` | A whirr when he moves: a sawtooth glide 300 to 900 Hz with resonance sweeps and gear noise | easy | S |
| `laugh.glitch` | A stuttering laugh looping on one syllable: a short laugh repeated 3 to 6 times with a pitch step and bit reduction | medium | S over a recorded or synthesised "ha" |
| `growl`, `effort.light`, `effort.heavy`, `pain.head`, `pain.limb` | The voice engine with high resonances and a light bit-crush; pain adds a stutter | easy | S |
| `sigh` | A fan spinning down: noise and a falling whirr | easy | S |

About 11 gestures: 33 clips. Legal's Press condition applies: mechanical, no ray and no sparkle.

Total: about 46 gestures and about 138 clips for the four fighters (some gestures, such as `effort.heavy`, exist for several fighters with different numbers), about 2.5 MB in memory, and about 1.0 s to render on a desktop for all four (about 0.5 s for the two in a match). Estimated from the 6 to 12 ms each of the working grunts.

**Babble.** The captions are babbled, not only punctuated by grunts: see `direction.md` section 7.1. The babble syllables and laughs come from the same engine, and a `sigh` gesture now exists for all four voices (the babble uses it after an ellipsis).

## 3. Making them for free

Three routes. They mix: the engine can carry pitch, timing and vowel, and a recording can carry breath and texture.

### A. Synthesis (the default, working today)

- **What.** The engine above, driven by recipes in data.
- **Good.** No cost, no recording, no third-party file, no voice-likeness issue, deterministic and tiny, easy to tune (Orb or a director can change a number), and every gesture can be varied without limit.
- **Bad.** It sounds a little synthetic, and laughs and cackles are the weakest. I expect the effort grunts, growls, sighs and the Cyborg to be good enough, and the laughs to need help.
- **Licence.** Ours. One asset row per generator (proposed in `audio/README.md`).

### B. Orb records themselves, and a processing chain makes the four voices

- **The session.** About 30 minutes with a phone in a wardrobe or under a duvet, 44.1 kHz WAV, peaks around −6 dB, three takes of each: "hah" at three efforts (light, hard, all-out), a short laugh, a long warm laugh, a cruel laugh, a cackle building, a wheeze and inhale, a growl, a sigh (happy, cold, weary), a gasp, a hiss through the teeth, a dry "tch", a snort, a hum, a shriek (into a pillow), a throat clear and swallow, and biting a cracker, celery and a sandwich. I can write the exact take list and how to perform each one when Orb wants to do it.
- **One performer, four voices.** A free editor (Audacity, a development tool that never ships) and Godot's own effects change the character:

| Voice | Processing |
| :--- | :--- |
| Protagonist | As recorded; a little warmth around 200 Hz; up 0 to 2 semitones with the vowel colour kept |
| Anti-hero | Down about 5 semitones, the vowel colour lowered less; an octave-down layer at 20%; slow compression; dry |
| Empress | Up about 4 semitones with the vowel colour raised 18%; a light chorus; a short plate reverb; the cackle sped up |
| Cyborg | A 10 to 12 bit crush; a 60 Hz ring modulation at about 12%; a 300 Hz to 4 kHz band; a tiny metallic comb; random dropouts |

- **Good.** The most human, and Orb's own performance also counts as real human authorship for the characters (`licence-recommendation.md` 8.5).
- **Bad.** It needs Orb's time and a quiet room. Orb's voice becomes public when the repo does, and Orb is known by a pseudonym: heavy processing hides the voice but never fully. Orb decides.
- **Licence.** Origin: human-made; author: Orb; the device and date; a licence Orb chooses (CC BY 4.0 or CC0); Orb's written OK to publish. Legal reviews.

### C. Hybrid (my recommendation for the laughs)

Synthesis drives pitch, timing and the vowel; a recorded breath, lip smack or cloth layer (Orb's, or CC0) rides underneath. That fixes the "too clean" problem without recording every gesture, and keeps the variation and the tuning in data. Start with the recorded layer only for the laughs, the cackle and the munch.

### D. AI-generated voices (not recommended)

Orb allows AI-generated assets, but for audio I recommend against it for now: a tool's terms have to be read and logged first (free tiers often bar commercial use); voices and laughs are what defines a character, which the licence advice says needs real human authorship; a model can drift towards a real person or franchise voice even with a clean prompt; and store disclosure applies (Steam and itch.io ask about AI-made audio). If Orb wants it anyway, it goes to Legal first with the tool, model, date and the prompt.

### Recommendation

Ship A now, and use C for the laughs and the munch when Orb wants more realism. Keep B as the way to give the game a truly human voice. Keep D off.

## 4. What a person should listen for

When Orb (or anyone) plays `audio/preview/` or the demo:

1. Does the Protagonist's grunt sound like a hearty effort, or like a buzzer?
2. Does the Anti-hero's sound low and held back, or just like the same sound pitched down?
3. Can you tell the two fighters apart with your eyes shut?
4. Is anything harsh, clicky or fatiguing after ten repeats? (The variants and the pitch spread should help.)
5. Do the light, heavy and crater impacts feel like three sizes of the same world?
6. Does a heavy hit have enough weight on laptop speakers?
7. Do the sounds pan correctly when moved left and right (`P` in the demo)?

## 5. Open questions

For Orb:
Settled (Orb, via the EP, 2026-09-29): synthesis first, and Orb may record laughs and the munch later; AI-generated audio is allowed once Legal clears the specific tool's terms; Narrative writes the caption strings.

Still for Orb:
1. Are you comfortable with your own voice in the game, heavily processed?
2. Is the Anti-hero's held-back effort (a pressed exhale) the right feel, or should he grunt louder?

For the EP: the file shape and the caption ownership are open (`direction.md`, section 10).
