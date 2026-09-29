# Risk register (starting set)

| # | Risk | Likelihood | Impact | Owner | Mitigation |
|---|------|-----------|--------|-------|-----------|
| 1 | Homage drifts into copying characters, names or music | Medium | High | Legal and IP | Originality rules at P0, review every locked design and audio asset |
| 2 | Procedural director feels unfair or unreadable to players | Medium | High | Encounter Systems | Debug feed, feel tests, parry and chain windows tuned by Controls and Feel |
| 3 | Determinism breaks rollback online | Medium | High | Netcode and Simulation | Determinism contract at P0, replay verification in CI |
| 4 | Hidden-information mechanic cannot work on one screen | High | Medium | Research and Prototyping | Spike split-screen versus fog before P3 |
| 5 | Deformable wrapped terrain and effects blow the frame budget | Medium | High | Performance | Budgets at P1, worst-case scene profiling each phase |
| 6 | Destruction escalates too fast or too slow | High | Medium | World and Game Design | Tune with the sim harness, tier-scaled damage |
| 7 | Balance skew from asymmetric hero and villain mechanics | High | Medium | QA and Balance | Win-rate dashboard per phase, mirror tests |
| 8 | Too many directors active at once burns context and money | Medium | Medium | Executive Producer | Use the activation schedule, parallelise only independent work |
| 9 | Scope grows beyond four fighters and one planet | Medium | High | Executive Producer | Gate scope changes through Orb |
| 10 | Art pipeline cannot support authored atoms for four fighters | Medium | High | Art and Animation | Shared rig and retargeting, atom contract owned by Combat |
