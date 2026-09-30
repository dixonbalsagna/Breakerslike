# Before the store page: a checklist for Orb

Written 2026-09-30. Plain language, one screen. Not legal advice. Legal reviews the store page, trailer and screenshots before they go live.

## 1. Steam AI-content disclosure
- Steam asks you to describe AI used to make anything that **ships in the game or appears on the store page**: art, music, dialogue, text and store images. Tools that only help you build it, like a coding assistant, are exempt. Steam has asked since January 2024 and rewrote the rules on 16 January 2026.
- With a mostly vibe-coded game, the answer will say most shipped content is AI-made. That is fine. Saying it honestly is what matters. The provenance records (tool, model, date, brief) are how we fill it in.
- No AI that generates content while the game runs: say no. itch.io has its own AI field. Fill it in the same way.

## 2. Trademark
- **The clash:** a small open-source mobile game called OrbCombat already exists (a Godot game on GitHub). Decide: contact the author, add a distinguishing word, or pick another title. Do this before buying a domain or opening a store page.
- **Search:** a person or a lawyer runs a proper search (US, EU, UK, Japan) for ORB COMBAT and COMBAT EX in software, games and entertainment. Our screen is not a clearance.
- **Registering:** you can apply at the US trademark office yourself for the title, and later the logo, in the classes for game software and entertainment. A lawyer makes it smoother. Until then, use the ™ mark. The trademark is what protects the name and logo, and it does not depend on who drew them.

## 3. Third-party licences
- **Godot:** show its MIT licence text and the libraries it bundles in a credits or licences screen. Godot has calls that produce the text.
- **Fonts:** Godot's built-in Open Sans is covered by that screen. Any font you add needs a row in the register first.
- **Sounds and music:** our synthesised sounds need nothing. Any sample pack, loop or soundtrack needs a licence on file. An AI audio tool needs Legal to read its terms first.
- **Libraries and assets:** every one has a row in `licence-register.md` and an accepted licence. "No licence stated" means no.

## 4. If friends contribute
- They keep their copyright and agree their work is under the project's licence. Ask them to sign off their commits (`git commit -s`). That is the whole contributor agreement, and you do not need a CLA.
- Ask for the same rules you follow: nothing from other games or franchises, say where third-party material comes from, and say if AI helped.

## 5. Copyright holder and store accounts
- **Holder name:** pick who is named in the LICENSE files and on the stores: your legal name, "Orb", or a project name. Stores ask for a verified identity and tax details whatever the answer. A pseudonym can work for the public name, but the account holder must be a real person or entity. A lawyer can advise.
- **Steam:** a fee per game (currently $100, returned only once it earns $1,000), identity and tax checks, and a waiting period. A free game will not get the fee back. Check Steamworks before you pay.
- **itch.io:** a free account is enough. Add payout details only if you ever charge.

## 6. Licence for a public repo that sells builds
- MIT and CC BY let **anyone** copy, build and sell the game, including other people's copies. The GPL also lets people sell copies, so a copyleft licence would not stop that either. And parts made entirely by AI may have no copyright to enforce.
- What protects you is the trademark (the title and logo), being the original and the place players get updates, plus the store page.
- **Orb decides:**
  1. Keep MIT and CC BY (the recommended pairing) and rely on the trademark and the store.
  2. Keep the code MIT and keep the art and audio all rights reserved. It is less open, and only the code counts as open source.
  3. Stay private until release, then open up.
- **Before the store page:** place the licence files (they are out of the repo now), decide the holder name, and have counsel read them, the README wording and the store text.
