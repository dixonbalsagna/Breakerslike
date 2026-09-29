# Name screening

How Legal screens candidate names. Narrative proposes, Legal screens, Orb picks, and counsel clears the final one. Written 2026-09-28 for the next wave, when Narrative's longlist arrives. Not legal advice. A screen is not a clearance.

## What a screen can and cannot do

It finds obvious problems early and cheaply: names that echo the franchise, names already used by games or brands, and names that would be hard to own or to find. It cannot promise a name is free to use. Only a formal trademark search and advice from a trademark lawyer can do that, and only for the final one or two names (stage 5).

A trademark protects a name or logo used to sell goods or services, so customers are not confused about who made what. It can be registered in each country, or arise from use. Two names can clash without being identical, if they look, sound or mean something similar and are used for similar things.

## What Narrative sends for each candidate

- The name, its spelling variants and how it is said aloud.
- What it means, in which language, and why it fits.
- Any tagline or subtitle that goes with it.

Send 20 to 50 candidates. Legal runs stages 0 and 1 on all of them, and stages 2 to 4 only on the shortlist. The same funnel covers fighter names (stages 0 and 1, plus stage 2 for any that will be marketed). Move names get stages 0 and 1 only.

## The funnel

| Stage | For | Time each | Purpose |
|---|---|---|---|
| 0. Quick knock-outs | every candidate | 2 min | Drop the obvious. No search needed. |
| 1. Web and store screen | every survivor | 10 to 15 min | Is the name already in use for games or brands? |
| 2. Trademark registers | shortlist, up to 8 | 30 to 45 min | Is a similar mark registered or pending? |
| 3. Domains and handles | shortlist, up to 5 | 15 min | Can we hold the name in the wild? |
| 4. Meaning, sound and language | shortlist, up to 5 | 10 min | Does it work, in speech and in other languages? |
| 5. Counsel | final 1 or 2 | outside | Formal clearance before anything is public. |

### Stage 0: quick knock-outs
Drop a candidate that:
- contains, sounds like, or plays on a franchise word: Dragon, Ball, Z (as in "Ball Z"), Saiyan or Sayan, Kai or Kaio, Kame, Namek, Budokai, Tenkaichi, Xenoverse, FighterZ, Sparking, Kakarot, Breakers, or any franchise character name; or follows its naming habits ("___ Ball", "___ Z", "Super ___", food or vegetable puns);
- is a single ordinary word with no distinctive partner (for example Meridian): crowded and hard to protect, unless a second word makes it ours;
- is hard to say, spell or search, is offensive, or is misleading;
- is a real person, a known brand, a company or a protected place name.

### Stage 1: web and store screen
1. **Web search** (a US-only tool): the name in quotes, plus "game", "video game" and "fighting game". Record who uses it, for what, and how big they are.
2. **Steam:** `https://store.steampowered.com/search/?term=NAME&category1=998` (games only). Record the total, exact-title matches and near matches.
3. **itch.io:** `https://itch.io/search?q=NAME`. Needs a browser. A plain page fetch is not reliable.
4. **App Store:** `https://itunes.apple.com/search?term=NAME&entity=software&limit=25` (returns JSON). Google Play has no simple API, so search by hand for the shortlist. Same for Epic, GOG, Nintendo, PlayStation and Xbox stores.
5. **Reference sites:** Wikipedia, IGDB, MobyGames and Fandom pages for the name.
6. **GitHub:** `https://api.github.com/search/repositories?q=NAME+in:name`, and the user or organisation name.

Ask: is it used for games, toys, media or apparel? By whom? Is it live? Drop it if any of these is true:
- an exact-title live game from a known publisher, or a well-known one;
- three or more live games with the exact title (crowded);
- any hit that ties it to Dragon Ball or another big franchise.

### Stage 2: trademark registers
Search the exact name and its variants: singular and plural, spacing, hyphen, common misspellings, sound-alikes and translations. Search these registers:

| Register | Address | Notes |
|---|---|---|
| USPTO (United States) | https://tmsearch.uspto.gov/ | Tested from Legal's session on 2026-09-28. Works in the browser pane with no login or CAPTCHA. Shows wordmark, status, classes and owner. |
| EUIPO eSearch plus and TMview (EU and many national offices) | https://www.tmdn.org/tmview/ | Not tested. Needs a browser. |
| WIPO Global Brand Database (international registrations and many countries) | https://branddb.wipo.int/ | Showed a CAPTCHA on 2026-09-28. A person runs this one. We do not bypass CAPTCHAs. |
| UK Intellectual Property Office | https://www.gov.uk/search-for-trademark | Not tested. |
| Japan, J-PlatPat (the franchise's home market) | https://www.j-platpat.inpit.go.jp/ | Not tested. Search in Latin letters and katakana. |
| Others by sales market: Canada, Australia, South Korea, China | national office sites | **Orb decides** the markets. |

Classes to focus on (Nice classification): 9 (downloadable game software), 41 (entertainment, online games), 28 (games and toys), 25 (clothing), 16 (printed matter), 35 (retail) and 42 (software services).

How to read the results:
- A live or pending mark for games, entertainment or toys (classes 9, 41, 28) that is identical or similar: drop the name, or ask counsel.
- The same word in unrelated classes (for example 5 or 30): usually fine. Note it.
- Dead or abandoned marks: note them. They can be revived, so counsel checks them.

Some registers ask you to accept terms or solve a CAPTCHA. A person accepts the terms, or Orb gives the go-ahead. If a CAPTCHA or login appears, Legal stops and asks the EP.

### Stage 3: domains and handles
- **Domains:** `.com` first, then `.game`, `.games`, `.gg`, `.io` and `.org`. Look up the registry record, for example `https://rdap.verisign.com/com/v1/domain/NAME.com`. A record means taken. A 404 means free. A person registers the ones we want. Note parked and for-sale domains.
- **Handles:** GitHub, `NAME.itch.io`, X, Bluesky, Instagram, TikTok, YouTube, Reddit, Discord vanity link, Twitch. Most social sites need a login, so check by hand in a browser. Aggregators such as namechk.com are hints only.
- We do not need every exact handle, but the name must not be hopelessly occupied, for example an active verified account with a different meaning.

### Stage 4: meaning, sound and language
- Search dictionaries and slang sites for the name and its parts.
- Check the meaning in Japanese, Spanish, Portuguese, French, German, Chinese, Korean and Russian. Ask Localization for a native check, through the EP, when unsure.
- Say-it-aloud test: can a listener spell it? Search test: is the game the top result for the name?
- Sound-alike test against franchise vocabulary.

### Stage 5: counsel
For the final one or two names, a trademark lawyer runs a formal search in the countries where we will sell, gives an opinion, and advises whether to file. Do this before any public reveal, logo, domain purchase or store page. **Orb decides** whether to file a trademark, and where.

## Ratings and what gets recorded

Same scale as `review-log.md`.
- **Low:** no franchise echo and no conflict found. Decision GO: moves on to the next stage, or to counsel.
- **Medium:** a collision or association to fix (a second word, another spelling), then re-screen. Decision CONDITIONAL.
- **High:** identical or confusingly similar mark or game, a franchise echo, or too crowded. Decision NO-GO.

**Labels are screened more lightly.** The drop rules in stages 0 and 1 (single common word, crowded, a well-known brand word) apply to game titles, fighter names and anything that will be marketed. A move or mechanic label that players read inside the game may use an ordinary word, or a word that is also someone else's brand, if it passes the franchise-echo check, is never used in a title, logo, store text, tag or fighter name, and Legal records the exception in `review-log.md`. FIRESTORM (a DC hero's name) and HORIZON CLEAVE (a Sony brand word) are logged this way (RL-006, RL-008). Labels get stage 0 and a web and Steam look, not stages 2 to 5.

Each screened candidate gets a review-log entry: name, stage reached, date, what was searched, hits, rating and recommendation. Names that fall at stage 0 or 1 are listed in one batch entry with the reason.

## After Orb picks

1. Legal repeats stages 1 to 3 on the chosen name and records "clear as of" with the date. Repeat within 30 days before any reveal.
2. A person registers the domain and handles at once.
3. Counsel clears the name (stage 5) before anything is public.
4. Update the placeholder names, the repo name (review-log RL-012) and the README. Ask counsel to look at the wording about the homage.
5. Keep watching for new filings of similar names, and keep the evidence with its dates.

## What this session can run (checked 2026-09-28)

| Check | Works? | How |
|---|---|---|
| Web search | Yes, US only | search tool |
| Steam store search | Yes | page fetch |
| itch.io search | Not reliably | browser |
| App Store | Yes | iTunes search API |
| GitHub repositories | Yes | GitHub search API |
| .com domain record | Yes | registry (RDAP) |
| USPTO trademark search | Yes | browser pane |
| WIPO Global Brand Database | No, CAPTCHA | a person |
| TMview, EUIPO, UK IPO, J-PlatPat | Not tested, may need a person to accept terms | browser |
| Google Play, console stores, social handles | Not tested, login walls likely | by hand |


## Title screen, round 2 (2026-09-29)

Candidates from Narrative's "Round 2": Sunburners, Sky Arsonists, Redline Sky. Stages 1 to 3, a screen and not a clearance. Logged as RL-021 to RL-023 in `review-log.md`.

| | Sunburners | Sky Arsonists | Redline Sky |
|---|---|---|---|
| Steam (games) | No title of that name. The top hit is Sunburnt (2018). Sunburn (a game released 2026-09-22) also exists. | 0 results, and none for "arsonist" | 1 unrelated result |
| App Store | none | none | none |
| Google Play | not run | not run | not run |
| itch.io | Search page unreliable. A web search found only a creator's collection named "SunBurner's Collection". | not run | not run |
| GitHub repos | 0 | not run | 0 |
| USPTO (games classes 9, 28, 41) | No records for SUNBURNERS | 7,336 records for the two words, almost all the single word SKY. No combined mark among the top hits. | not run |
| EUIPO, UK, Japan | not run | not run | not run |
| .com | sunburners.com registered (since 2016, expires 2026-10-30) | free | free |
| Web | The SunBurners, an active steel-drum party band in Cincinnati (live entertainment, class 41 in kind) | no exact match | no exact match. Redline is also a 2009 anime film and a 2007 film. |
| Big-franchise tie | One word away from Skyburners, a Destiny faction that Narrative already rated High. | none | none found. "Redline" is a crowded word. |
| Rating | **Medium** | **Low** | **Low (watch)** |
| Decision | CONDITIONAL | GO to the next stage | GO to the next stage, USPTO first |

**Sunburners against Sunburnt and Sunburn.** Yes, there is a real confusion risk. It differs from Sunburnt by ending and from Sunburn by two letters, and Steam's own search for "sunburners" returns Sunburnt first. Both are live games on the same store, and one launched last week. Meaning helps a little (people who burn suns, against a skin condition), and the sound is close. Add the live band with a near-identical name, the taken .com, and the one-word echo of Skyburners, and the total is Medium. A distinctive second word could bring it down, but that is a new candidate.

**Sky Arsonists** is clean on every check run. "Sky" as a prefix is crowded (Skybound, Skyfire), but nothing takes "Arsonists". **Redline Sky** is clean too, but "Redline" is used everywhere, so run USPTO and EUIPO on it before it goes further.

**Recommended order:** 1. Sky Arsonists, 2. Redline Sky, 3. Sunburners.

Not run for any of the three: EUIPO, UK and Japan registers, Google Play, other domains and handles, a language check, and counsel (stages 4 and 5).


## Title screen: "Orb Combat EX" (2026-09-29)

Orb's pick. Stages 1 to 3, plus stage 4 and 5 prep. A screen, not a clearance.

**Verdict: CONDITIONAL (Medium).** Usable as a working public title, but an existing open-source mobile game called OrbCombat is a direct name clash to resolve before any store page.

| Check | Result |
|---|---|
| Steam (games) | No title named Orb Combat or OrbCombat. 360 results for the two words, including Orb Breaker (2026), OrbWars (2023), Orb Devils (2025). "Combat EX": 251 results, no title ending that way. |
| App Store | No app of that name. Results are other orb and combat games. |
| Google Play, itch.io | Not run reliably. A web search found no itch.io game called Orb Combat, but several orb-themed games (Orb Battlegrounds, Orbo, Battle Orb on other stores). |
| GitHub | **Cascachu/OrbCombat**: a mobile game about fights between orbs, in GDScript (Godot), GPL-3.0, with a web page repo. Same name, same engine, and mobile is on our platform list. |
| USPTO | 1,943 records for the two words, dominated by the single word ORB (many dead, some live, none in games seen). No combined ORB COMBAT mark among the top hits. The search does not match the exact phrase. |
| EUIPO, UK, Japan | Not run. |
| Domains and handles | orbcombat.com free, orbcombatex.com free (registry lookup). GitHub name "orbcombat" free. itch.io and Steam page names not checkable. |
| The Orb (band) | An English ambient-house act since 1988. Different field. A risk only if a soundtrack is released under the name "Orb". |
| Madness Combat | Krinkels' flash series. We found no published fan-game or trademark policy. Fan games freely use "Madness" names. "Combat" is an ordinary word, and the first words differ. Complaint risk is low, but the nod is deliberate. |
| Dragon Ball orbs | "Orb" alone is generic. Together with orb-shaped artefacts it echoes the franchise's seven-ball device (already a signature, see `fighter-concepts-review.md`). |

**Conditions.**
1. **Resolve OrbCombat.** It is a small unregistered project, but it is the same name in the same engine and on a platform we target. Options: contact the author, or add a distinguishing word. Decide before a store page or a domain purchase. Orb decides.
2. **Formal search.** Have a person (or counsel) run EUIPO, UK, Japan and the exact-phrase USPTO search, and Google Play, for ORB COMBAT and COMBAT EX in classes 9, 28 and 41.
3. **Keep the artefacts un-orb-like.** The protagonist's gathered items must not be orbs. Keep to the Keystones replacement.
4. **Keep distance from Madness Combat.** No borrowed art style elements, character designs, catchphrases or the word "Madness". Mention it, if at all, as a factual influence in a devlog, not in the pitch line.
5. **Say who "Orb" is.** Orb is also the creator's pseudonym. Counsel should advise how the title and the pseudonym relate to the copyright holder line.

**Stage 4 (meaning and language), partly done.** "Orb" and "EX" are common loanwords in Japanese and English, and no negative meaning is known. Not run: a native check in other languages. "EX" reads as the fighting-game "extended" convention and implies a base title. Localization can confirm.

**Stage 5 (counsel) brief, for the final title.** Ask counsel to: (a) run a formal search in the US, EU, UK and Japan for the title in classes 9, 28 and 41, (b) assess the OrbCombat clash, (c) advise on the "-Combat" nod to Madness Combat, (d) advise on filing and on the pseudonym, and (e) read the licence files and README before the repo goes public.
