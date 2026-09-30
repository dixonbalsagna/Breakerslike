# Licence recommendation for the free, open-source release

Owner: Legal and IP Compliance. 2026-09-28. For Orb, who decides, and the EP. Not legal advice. Have a lawyer read the final choice before the repo goes public (section 9). Where an answer from Orb changes the advice, it is marked **Orb decides**.

## 1. The recommendation in short

- **Code:** MIT.
- **Art, audio, data files and docs:** CC BY 4.0.
- **Name, logos and fighter names:** not licensed. Kept as trademarks, with a short policy in the README.
- **Outside contributors:** sign each commit with the DCO. No CLA.
- **AI:** Orb's answer (2026-09-28): AI-generated assets are allowed, and assets will be procedural. So: disclosed, logged per asset, never prompted with franchise material, and real human authorship on everything that defines the game.

**Status, 2026-09-29:** Orb accepted pairing 1 (relayed by the EP). Ready-to-place files are in `drafts/`. Option B (GPL) is dropped and kept below only for the record. The repo's own code and docs were written with AI assistance, so the README and NOTICE say so.
- The alternative, if Orb's answers below point the other way: GPL-3.0-or-later with CC BY-SA 4.0, and a written Steam plan settled before any outside contribution is merged (section 5).

Until Orb approves a licence and a name, the repo stays private. With no licence file, the default is "all rights reserved".

## 2. What Orb decides

1. **If someone forks the game, may they close their fork and sell it?** Yes points to MIT (recommended). No points to GPL.
2. **May others reuse our characters and art in their own games, including for money, if they credit us?** Yes points to CC BY (recommended). Only if they share what they make from it points to CC BY-SA. No means the art is not open, and "free and open source" would describe the code only.
3. **Is Steam a real target? Consoles or mobile?** Orb's answer: itch.io, Steam (free) and GitHub, on platforms that include mobile. Steam works with MIT. GPL would need a written permission plan (section 3B). Mobile and console store terms have not been checked, and permissive licences are the safer fit for them.
4. **Who is named as copyright holder in the LICENSE files?** Orb's legal name, "Orb", or a project name such as "<Game name> contributors". Counsel should advise. Steam will also want a verified publisher identity (section 7).

## 3. Code licence options

### A. MIT (recommended)
- **What it means:** anyone may use, copy, change, sell and re-license the code, including in closed products, if they keep our copyright notice and the licence text. Apache-2.0 is the same idea with an express patent grant and a NOTICE file. It adds paperwork and buys little for a game.
- **Good for us:** Godot itself is MIT, so nothing pulls the other way. Valve's Steamworks guidance lists MIT among the licences that work with Steam. It is the easiest licence for any later port or store. The deterministic sim core could be reused by other projects, which helps the community.
- **Costs:** someone can take the code, close it and ship a competing game. The licence does nothing about that. The name (trademark) and the art licence are the tools for the rest.
- **Contributors:** simple. They contribute under the same licence, with a DCO sign-off (section 6). The project can later move new versions to GPL without asking anyone, because MIT code may be included in a GPL work. The reverse is not possible. That keeps our options open.
- **itch.io:** no issue.
- **Steam:** no issue.

### B. GPL-3.0-or-later
- **What it means:** anyone may use, change and sell the code, but if they give copies to others, including modified forks, those copies must come with the source under the GPL. That stops closed-source forks.
- **Good for us:** every fork stays open. A strong "free software" message. Pairs naturally with CC BY-SA assets.
- **Costs:**
  - Steam. Valve's guidance says any licence with a copyleft element is problematic next to the Steamworks SDK. A GPL game can be listed only if the copyright holders give Valve explicit permission, or decide that the Steamworks link does not trigger the GPL. That works if Orb holds all the copyright, or every contributor agrees in writing. Each outside contribution accepted without that agreement makes it harder.
  - Other platforms (console stores, Apple's App Store) have terms that often clash with copyleft. We have not checked. If they are targets, ask counsel before choosing GPL.
  - Closed projects cannot reuse our sim core.
- **Contributors:** a DCO records who wrote what, but the licence cannot be changed later without every contributor. To keep the option of a Steam exception, use a CLA or collect written permission at merge time.
- **itch.io:** no issue.
- **Steam:** possible only with the permission above.

### C. MPL-2.0
- **What it means:** file-level copyleft. Changes to our files must be shared under MPL-2.0, but those files can sit inside a larger project under other licences.
- **Good for us:** a middle path. Forks share improvements to our files but may add closed parts.
- **Costs:** less familiar to contributors. Valve's page calls any copyleft element problematic, so Steam would need the same care as GPL. MPL is generally easier to combine with proprietary code than GPL, but Valve has not said so, so ask counsel. More review work for little gain.
- **Contributors:** DCO.
- **itch.io:** no issue.
- **Steam:** needs care, as above.

## 4. Art, audio, data and docs options

"Assets" here means art, animation, audio, music, fonts we make, the data files (atoms, exchanges, fighters, biomes) and the docs. Creative Commons itself advises against using its licences for software, and says they are fine for game art and music. So the folders split like this:

- Code (`sim/`, `render/`, `ui/`, `net/`, `tools/`, `prototype/`): the code licence.
- Content (`art/`, `audio/`, `data/`, `docs/`): the asset licence.

Tools can mark this with SPDX headers or a REUSE-style file, so each file's licence is machine-readable and CI can check it.

### A. CC BY 4.0 (recommended)
- **What it means:** anyone may copy, change and reuse the material, including for money, if they credit us and say what they changed.
- **Good for us:** the simplest and best-understood option. Welcoming to mods and fan art. Creative Commons treats BY as the licence closest to open-culture principles.
- **Costs:** others can reuse our characters and art in their own games, commercially. We cannot stop that. Only trademark protects the name. The licence also has nothing to grip on parts where nobody holds copyright, such as pure AI output (section 8).
- **Contributors:** artists and composers license their work under CC BY 4.0. No assignment needed.
- **itch.io and Steam:** no issue. Only the AI disclosures in sections 7 and 8 apply.

### B. CC BY-SA 4.0
- **What it means:** the same, but anything adapted from our material must be shared under the same licence.
- **Good for us:** derived art stays open. Creative Commons lists it as one-way compatible with GPLv3: you may bring BY-SA material into a GPLv3 work, but not the reverse.
- **Costs:** some game makers avoid share-alike assets. Contributors must track which assets are adaptations. It cannot be mixed with material under conflicting licences.
- **Contributors:** as A.
- **itch.io and Steam:** as A.

### C. CC0
- **What it means:** gives up all rights as far as the law allows. No credit needed.
- **Good for us:** the simplest. Suits placeholder art, UI icons and heavily AI-made assets.
- **Costs:** no credit. It cannot protect the look, only the name.

### Not recommended: CC BY-NC, CC BY-ND, or art kept all rights reserved
NC and ND limit the freedoms that open licences are about (Creative Commons made this point in its 2008 post on free cultural works), and NC would stop others redistributing on stores. If Orb wants the characters to stay exclusive, that is a different project shape: open code, closed content. It is Orb's call, but then "free and open source" would describe the code only.

### Names and logos
MIT and CC BY do not license names and logos. Add a short trademark note to the README: the game's name, logo and fighter names are not licensed, and forks must rename. That is how many open projects stop a fork passing itself off as the original. The name must first be screened and cleared (`name-screening.md`), and Orb decides whether to register it.

### Third-party content
It keeps its own licence and is listed in `licence-register.md`.

## 5. Pairings

| Pairing | Choose it when | Main cost |
|---|---|---|
| 1. MIT + CC BY 4.0 (recommended) | Orb answers yes to questions 1 and 2, Steam is a real target, and low friction matters | A fork can go closed, and art can be reused commercially. The brand is protected only by trademark. |
| 2. GPL-3.0-or-later + CC BY-SA 4.0 | "No closed forks, and derived art stays open" matters most | Steam needs permission from every copyright holder. Consoles and app stores are unchecked. Closed projects cannot reuse our code. A CLA is needed for flexibility. |
| 3. MPL-2.0 + CC BY-SA 4.0 | Forks should share changes to our files but may add closed parts | Less familiar. Steam still needs care. More review work. |

**Why pairing 1:**
- It matches Godot and Valve's own guidance for open-source games on Steam.
- It puts no barrier in front of contributors and needs no CLA.
- It keeps the upgrade path. MIT to GPL later is possible without asking anyone. GPL to MIT is not.
- The risk it leaves, someone closing a fork, matters little for a free game. What is distinctive about the project (its name, look and community) is protected by trademark and by being the original.
- For AI-assisted art, a permissive licence is the honest choice, because parts may have no copyright at all (section 8).

## 6. Contributors

- Contributors keep their copyright and license their contribution under the project licence. Outside contributors sign off each commit with the DCO (`git commit -s`), which says "I wrote this, or I have the right to submit it under this licence". No CLA under pairing 1.
- Orb and the AI sessions do not need sign-off for internal commits. Orb's ownership and the `Co-Authored-By` lines already record who did what.
- Every pull request carries a short originality note: no franchise names, designs, audio or code; third-party items listed with their licence; any AI assistance stated. Tools can add a PR template.
- Third-party code or assets in a pull request need a row in `licence-register.md` before merge, and only accepted licences (register, part C).
- Nothing from Lemming Ball Z or any other fan game (`originality-rules.md`).
- Under pairing 2 or 3 with a Steam plan, use a CLA or written permission at merge time.

## 7. Distribution: itch.io and Steam

**itch.io**
- We found no licence requirement for game pages. itch expects you to have the rights to what you upload. Every option above works. Read its current terms at upload.
- Free games are allowed. Godot can export web (HTML5) builds.
- AI disclosure: itch has a generative-AI field. As announced it is mandatory for asset creators, which would apply if we ever publish our art or audio as separate asset packs, and optional for games. Recheck at upload. Answering yes adds an "AI Generated" tag, with sub-tags for graphics, sound, text and dialogue, and code. Answering no adds "No AI". AI assets left untagged can be dropped from browse pages.

**Steam**
- Cost: a $100 fee per app, recoupable once the game earns $1,000 in sales. A free game with no sales would not get it back. Verify at signup on Valve's Steamworks page. Guides also report identity and tax verification and a waiting period after paying. That means a real person or entity is named as publisher (question 4).
- Rights: we warrant that we have the rights to everything and that nothing infringes. Valve gives rights holders DMCA and trademark complaint forms and judges AI content like any other. A lookalike can be pulled.
- Open source: Valve's page names MIT, BSD (3-clause and 4-clause), Apache-2.0 and WTFPL as fine. It calls copyleft problematic and says a GPL game needs the copyright holders' permission. Valve does not review licence compatibility for us. The warranty is ours.
- Keep the Steamworks SDK out of a public repo unless its terms allow it. Register it first.
- AI disclosure (Steam has asked for it since January 2024, and rewrote the rules on 16 January 2026): disclose AI used to make content that ships in the game or appears on the store page, such as art, music, dialogue and localisation, with a description of the tools. There is a separate box for content generated while the game runs, with a description of the guardrails. AI tools that only speed up development, such as code assistants, are exempt. We plan no live generation. Valve shows the statement on the store page, as we understand it.

## 8. AI-generated code and assets

### 8.1 Copyright status (US)
- The US Copyright Office's report of 29 January 2025 says work made entirely by AI is not protected, because copyright needs a human author. Writing prompts alone does not make you the author. What can be protected is the human part: what you write or draw yourself, your creative selection and arrangement of AI output, and your creative edits to it.
- In Thaler v. Perlmutter an appeals court held that copyright needs a human author. The US Supreme Court declined to hear the case on 2 March 2026, so that rule stands today.
- For us: in US law, AI-only output is effectively free for anyone to copy, whatever licence we put on it. Our licence still covers the parts a human authored, and the project's structure and design choices. How much human input is "enough" is decided case by case, and is untested for games.
- Outside the US the rules differ and some are under review. This note does not cover them.

### 8.2 Terms of the tools
- **Anthropic (Claude).** The Consumer Terms (effective 8 October 2025) assign Anthropic's rights in Outputs, "if any", to the user and offer no IP indemnity to consumer users. The Commercial Terms (effective 17 June 2025) say the customer owns the Outputs and include an IP indemnity for authorised use, with exclusions. Which set applies depends on how Claude is accessed (a consumer plan, or an API or business account). Orb uses the Pro plan (confirmed via the EP, 2026-09-29), a consumer plan, so the Consumer Terms apply and there is no vendor IP indemnity. Re-check both sets of terms before the repo goes public.
- **Any other AI tool** (images, music, voice, video): read its terms for commercial use and output ownership before using it, and record it in the register. Free tiers often bar commercial use.

### 8.3 Infringement risk
- Models can produce output that resembles existing works, above all when a prompt names a franchise or a character. Under a consumer plan that risk sits with us, not the vendor.
- For code, models can reproduce open-source code. On 16 September 2026 the Ninth Circuit affirmed the dismissal of the DMCA section 1202(b) claims in Doe v. GitHub. The open-source licence contract claims continue in the district court, so whether reproducing licensed code breaks its licence is not settled. Re-check at each phase gate.

### 8.4 Store disclosure
See section 7. Steam: content that ships or appears on the store page. itch.io: the generative-AI field. Other stores were not reviewed. Check at submission.

### 8.5 Rules for this project
1. No franchise names, character names, reference images or audio in any prompt, brief or image-to-image input.
2. Every shipped asset gets an origin row (`licence-register.md`, part B): tool, model, date, where the prompt is kept, and what a human changed.
3. ~~Characters, signature designs and music themes need real human authorship.~~ **Changed by ADR 0007 (2026-09-30):** no content class requires a human author. Orb accepts that purely AI-made parts may be unprotected. Protection rests on the trademark, Orb's own contributions and the whole work. The originality screens, franchise-free briefs, provenance records, third-party licence checks and Legal's pre-store review stay mandatory.
4. Review AI code before it merges. Reject long verbatim snippets and anything that carries someone else's licence header. Use a licence scanner when in doubt.
5. State AI assistance in the README, and answer each store's disclosure honestly. Git history already records it through the `Co-Authored-By` lines.
6. **Orb decides:** may AI-generated art, audio or dialogue ship in the game at all? "No" keeps the store disclosures simplest ("No AI" on assets, and coding assistance is exempt on Steam). "Yes, with human authorship and disclosure" is workable.

### 8.6 What is uncertain
How courts will treat mixed human and AI work in games. Other countries' law. Future store rules. Whether MIT or CC conditions can be enforced on parts nobody holds copyright in.

## 9. When to involve a lawyer

1. **Before the repo goes public.** Confirm the licence choice, the README wording about the homage, the contributor terms and the trademark note. A short review is enough.
2. **Before the game's name is locked.** A formal trademark search and advice, and a decision on whether to file. Legal's screen (`name-screening.md`) is not a clearance.
3. **Before a store page or trailer.** Review the homage wording, the screenshots and the final fighter designs against Dragon Ball resemblance.
4. **If GPL is chosen and Steam or consoles are targets.** A written permission or exception.
5. **If anyone contacts us with a claim, takedown or demand.** Stop, do not reply, and tell Orb and the EP. Counsel handles it.
6. **Before accepting a CLA, taking money (donations, sales) or using fan-game material.**

## 10. Sources (checked 2026-09-28)

- Valve on open source and Steam: [Distributing Open Source Applications on Steam](https://partner.steamgames.com/doc/sdk/uploading/distributing_opensource)
- Valve on AI disclosure: [Steamworks content survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey), [Game Developer on the 16 January 2026 change](https://www.gamedeveloper.com/business/valve-tweaks-and-clarifies-ai-disclosure-rules-for-steam)
- Steam fee: [Steam Direct fee](https://partner.steamgames.com/doc/gettingstarted/appfee)
- itch.io: [Generative AI Disclosure tagging](https://itch.io/t/4309690/generative-ai-disclosure-tagging)
- Godot: [licence](https://godotengine.org/license/), [complying with licences](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)
- Creative Commons: [compatible licences](https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses/), [FAQ](https://creativecommons.org/faq/)
- US Copyright Office: [Copyright and Artificial Intelligence](https://www.copyright.gov/ai/), [Crowell summary of Part 2](https://www.crowell.com/en/insights/client-alerts/us-copyright-office-releases-part-2-of-artificial-intelligence-report-clarifying-copyrightability-of-generative-ai-outputs)
- Thaler v. Perlmutter: [Mayer Brown](https://www.mayerbrown.com/en/insights/publications/2026/03/supreme-court-denies-review-in-ai-authorship-case)
- Doe v. GitHub: [Gibson Dunn](https://www.gibsondunn.com/ninth-circuit-clarifies-limits-of-dmca-liability-for-ai-generated-code/), [Haynes Boone](https://www.haynesboone.com/news/alerts/ai-legal-news-ninth-circuit-rejects-dmca-section-1202(b)-theory)
- Anthropic: [Consumer Terms](https://www.anthropic.com/legal/consumer-terms), [Commercial Terms](https://www.anthropic.com/legal/commercial-terms)
