---
version: 1
slug: "lib-features-tome-tome-screen-dart"
primary_target: "lib/features/tome/tome_screen.dart"
related_targets: []
---

Scope: the Tome — the primary build-craft surface of Tome: Martial Arts (Flutter). First surface built; it establishes the game's visual world. Visitor mode: Operate (an editor the player dwells in).

Audience & job: a solo roguelike player at the deliberate heart of a run — between fights, deciding what the build becomes. Weighs synergies, re-reads lineage and combine odds. Reaches the screen many times per run and lingers. Two first-class layouts: phone portrait and desktop.

Action / task: place, move, remove components on a pannable coordinate lattice; fire combines; spend upgrade points; send a component to training; commit to the next fight.

Proof / content: every visible state is a live engine query — mastery thresholds, itemClass/grade paths, technique-evolution lineage, tradition affinity multipliers (x1.25 / x0.85), canCombine eligibility. No blind boxes. Relationships stay drawn even when unavailable (a matched-but-maxed combine hangs slack, not hidden).

Chosen direction: "The Lineage Hall" (seed 6f69b7e6, code-led). A lacquered near-black board; aged-bone mounts carrying carved content-seeded seal chops, concentric rank rings, and fixed-cell state marks whose SHAPE carries the meaning (never colour alone); vermilion for live cords/chops/strike-marks; tarnished gold reserved for mastered only; one raking light from the upper-left that every shadow obeys. The west<->east tradition axis runs left->right across the board as a warm->cool ground tint at near-lacquer value — the one axis that never collapses; the player pans along it. Carved Roman display (Cinzel), quiet grotesque readouts (Archivo), a monospace measurement hand (Spline Sans Mono) for leader-line quantities only. Every mark, including controls, is one drawn ink hand — no stock widgets.

Memorable moment: firing a Combine — the vermilion cord between two matching mounts draws taut, the forms resolve into the survivor, a seal is pressed onto it (stamp + ink bloom), and the new class lands on a leader line. All motion gated behind reduced-motion.

Constraints: engine adapter + Bloc + RunBloc phase-machine + go_router contracts untouched; PRODUCT.md game-a11y baseline (shape not colour, scalable text, non-drag alternative to every drag, full prefers-reduced-motion, Semantics on the drawn board).

Unresolved / follow-up: grid-growth ceiling is an open game-design question (built to survive 6x5+ via pan/zoom + extent rail); no player-facing game name or logo confirmed (frontispiece uses plain lettered text); the combine-cord overlay, radial hub, seal-press reveal, tray spotlight, and both bottom sheets are built but were not captured in the fresh-run screenshots (no combine possible at one placed item); an accessibility-inspector pass on the Semantics wrappers is worth doing before the a11y rule in DESIGN.md is treated as verified.
