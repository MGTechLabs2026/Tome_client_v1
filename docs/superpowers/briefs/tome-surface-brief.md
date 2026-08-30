# Design Brief — The Tome Surface

**Status:** confirmed direction, no code. Produced by `/impeccable shape tome`.
**Surface:** the Tome (main build screen + its sheets + first-run + grid-expansion return).
**Visitor mode:** Operate — a build-craft editor the player dwells in.
**Direction locked:** "The Lineage Hall" (seed `6f69b7e6`, assigned card, code-led).

---

## 1. Job and audience

A solo roguelike player at the **deliberate heart of a run** — between fights, having just taken loot, deciding what their build becomes. They are leaning in, not passing through: weighing whether a new knife combines with the two they own, which style/physique tradition match multiplies their damage, what a technique evolved from and whether it can go further. They reach this screen many times per run and linger each time.

Two first-class contexts, two real layouts (not one stretched): **phone portrait (~390–430 dp)** on a couch, and **desktop/pointer (~1280 dp+)**.

## 2. Outcome and proof

- **Primary task:** assemble and evolve the Tome — place/move/remove components on the grid, fire combines, spend upgrade points, send a component to training, then commit to the next fight.
- **Success:** the player can read every mechanical relationship *at a glance* — which components combine, which technique came from what, which style matches this physique — without opening a stat sheet; and dwelling here feels rewarding, not administrative.
- **Product truth this surface must carry (never decorate over):** every visible state is a live engine query — mastery thresholds, `itemClass` / grade-evolution paths, technique-evolution lineage accumulated from `TechniqueEvolved` events, tradition affinity multipliers (×1.25 / ×0.85), `canCombine` eligibility. No blind boxes: loot, combine inputs, and combine cost are shown with real identity before any commit. Relationships stay visible even when unavailable (a matched-but-maxed combine is shown, dimmed, not hidden).
- **Evidence on hand:** `docs/superpowers/specs/2026-08-25-tome-client-ux-design.md` §4.2–4.3 and §5 (interaction model, IA, and state table — authoritative); the shipped placeholder implementation in `lib/features/tome/`. No player-facing game name or logo exists yet.

## 3. Selected direction — "The Lineage Hall"

**Visual authority:** a school's lineage hall — a graded rack of mounted forms, the cords strung between related pieces, and the vertical descent (a *keizu* lineage scroll) that produced each one. Carved **seal chops** mark identity and ownership. The world holds **western and eastern martial traditions with equal authority** (a fencing lineage is mounted with the same gravity as a Wing Chun one) — it is a hall that trains both, not a literal Japanese dojo.

**Palette / material:** lacquered near-black board `#141013`; aged bone / rice-paper mounts `#E7DDCA`; **vermilion seal-ink `#B23A2E`** for live cords, chops, and the strike-mark; **tarnished gold `#B8933F` reserved for _mastered_**; cold slate `#6E7377` for dead / slack. One raking light source models the whole hall.

**Structural / interaction thesis:** the board is a **fixed coordinate lattice you pan and zoom over** (the rack is larger than the frame by design), not a grid that reflows to fit. The **western↔eastern tradition axis runs left→right across the hall as a real ground-and-light gradient** — where a piece hangs is information before any label is read. This axis is the one thing that never collapses on phone.

**Six raises carried into the direction (from the hands it beat):**

| From | Raise |
|---|---|
| Teletext Service | Every mount sits at a fixed `(row,col)`; the board **scales the cell, never reflows**; the grid address is part of the mount's label. |
| Timetable Slide-Rack | **Rank by weight, case and rule — never size.** State is a **fixed-cell mark** (filled / hollow / struck / sealed), never colour alone. A **position-and-extent rail** appears whenever the rack outruns the frame. |
| Tensegrity Column | Every relationship is **a quantity pinned to its node on a leader line** — `×1.25` at the mount, `cls I → II · 1 pt` on the cord. Every mount and cord names its state explicitly. |
| Precisionist Plate | One consistent **raking light**: the active mount takes the light, the rest fall into their own shadow — **selection reads as illumination**, not an outline colour. |
| ASCII Live-Scene Render | **One drawn ink substrate** — seals, rank rings, cords, lineage names, and the controls themselves are brushed/carved in a single hand. No stock widgets, no icon-font. |
| Gravity-Rain Garden | **One dominant organising axis** the eye follows first: the left→right tradition gradient, immovable on phone. |

**Sequence / focal moment:** placing is quiet (a mount settles with an ink-settle; a valid target shows a faint registration mark, an invalid one a dry scratch + struck note). The **memorable moment is firing a Combine**: the vermilion cord between two matching mounts draws taut, the two forms resolve into the survivor, a **seal is pressed onto it** (stamp motion + ink bloom), and the new class / stat delta is annotated on a leader line.

**Implementation consequence:** the grid cannot be a viewport-fitting `GridView` — it is a transformable lattice canvas (pan/zoom) with a dedicated cord/annotation overlay layer (the existing `_CombineTetherPainter` is the seed of this) and a position rail. The raking light is a single directional model (one gradient + shadow logic) applied everywhere. "One ink substrate" means custom-painted controls — counters, the upgrade-point spend, buttons — in the drawn hand, not Material components.

## 4. Scope and boundaries

**In scope (full Tome surface, production fidelity):**
- Character strip / frontispiece (name, physique + style marks, tradition-match synergy notation). The tap-to-expand stat sheet is **noted but out of this milestone's build scope** unless confirmed.
- Tome grid: pan/zoom lattice, drag place / move / remove, replace-not-overwrite on an occupied cell, valid/invalid drop feedback.
- Combine tethers: pairwise cords + **radial hub for 3+ matches**; eligible vs ineligible treatments.
- Component tray ("the loose rack"): horizontal, filter tabs (All / Items / Techniques), per-item state mark.
- Bottom bar: Train, Start Fight, upgrade-points tally (tap to spend); the **hammer mark** on any owned item / learned technique whenever `upgrade_points > 0`.
- Component Detail sheet: art, name, category/tier, properties, state banner, mastery-progress line with numeric readout + reason, evolution chip + expandable lineage chain, "combinable with →" row, contextual actions (Equip / Unequip / Train / Remove / Upgrade).
- Combine Confirmation sheet: inputs shown, cost `= itemClass` upgrade points, `[Attempt Combine]` → outcome reveal (Fail / ClassUpgrade / GradeUpgrade) → board re-settles around the survivor.
- First-run: one-time dismissible callout on the starting Knife + Cloth mounts.
- Grid-expansion return: arriving back from Loot after a `Grid Expansion` reward — the lattice grows, existing mounts hold their `(row,col)`, and new components get a **tray spotlight**.
- Every state in spec §5.

**Untouched:**
- `lib/core/engine/*` adapter contracts and the rule that `package:build_engine/*` is imported only there.
- Bloc contracts: `TomeBloc` / `TomeState` / `TomeEvent`, `RunBloc` phase machine, `go_router` phase redirects. New view-model fields may be requested; the phase graph and adapter APIs may not change.
- `TrainingPresentation` / `CombatPresentation` seams and everything outside the Tome surface.
- All product and mechanical truth; the engine as sole rules authority.

**Anti-goals:**
- The neon "gamer" build screen (near-black + one cyan/orange glow, hex slots, beveled panels) — the category rut.
- Its opposite: the monochrome hairline wireframe that admits it's a spreadsheet.
- The **illuminated-grimoire / scriptorium** reading the word "Tome" invites — no cream ground, no display-serif labels, no gilt flourish. (This is why the working-manual candidate is the *pick*, not the roll.)
- Material / HIG stock components anywhere in the committed surface.
- **Any state encoded by colour alone** (violates the PRODUCT.md a11y baseline; the direction already answers this with fixed-cell marks and illumination).

## 5. States and ranges

- **Grid:** 3×3 at run start → **6×5+ and effectively open-ended** over a long run (one +1 column per Grid Expansion loot). Design for pan/zoom + position rail from the first build; the growth ceiling is an **open game-design decision** — build to survive the large case, flag the cap.
- **Tray:** 0 at a fresh run → **20+** loose components at peak. Horizontal scroll must stay usable at that count; filter tabs earn their place there.
- **Combine matches on board:** 0 typical early → occasional; **3+ renders as a radial hub, never pairwise spaghetti**; the Combine sheet defaults to all matched instances selected, deselectable.
- **Lineage chain:** one hop shown inline ("Evolved from: Light Punch"); `[View Lineage]` expands the client's full accumulated chain (can be several hops by run end).
- **Upgrade points:** 0 → N; the hammer mark appears/disappears live as the count crosses 0.
- **Component states:** unknown → discovered → unlocked → usable (discovered + mastery met) → active (on grid). Plus §5: Empty (registration outline + "+" hint), valid drop (registration mark), invalid drop (dry scratch + struck reason), Locked (in shadow, seal dimmed, mastery rule + numeric reason on tap), Mastered (gold), Newly discovered (a one-time mark + settle, not a persistent ribbon), Selected (takes the light; valid targets lit), Upgraded (seal re-pressed + delta on a leader line).
- **Combine tether states:** eligible (taut vermilion cord, tappable, midpoint annotation) / ineligible-because-maxed (slack grey cord, struck, not tappable — the relationship still drawn).

## 6. Interaction and layout (intent, not CSS)

- **Hierarchy:** the rack/grid is visually dominant; the frontispiece is a thin strip; the tray is a subordinate rail/drawer; the bottom bar is a foot rule. Annotations (leader-line quantities) are always secondary to the mount they describe.
- **Topology — desktop:** grid centre-left at generous scale on the pannable lattice; a right column carries the frontispiece above the loose rack; lineage descent opens as a panel from the right; legend / force-vector key at the foot; bottom bar full-width. Component Detail and Combine Confirmation are sheets, not routes.
- **Topology — phone portrait:** frontispiece → a thin top rule; grid fills the viewport as the pannable lattice (you move over a sheet larger than the screen); tray → a bottom drawer of loose pieces; bottom bar → foot-of-page rule; the left→right tradition gradient is preserved and never collapses; sheets slide up.
- **Navigation of a rack larger than the frame:** pinch/scroll-zoom + drag-pan; a **position-and-extent rail** shows where you are and how much rack exists; double-tap a mount or a tray item to centre it.
- **Affordances:** drag is the primary placement gesture; **every drag has a tap / press-hold alternative** (tap a tray item then tap a target cell) for reach and accessibility. Targets are generous; the whole mount is the hit area, not just its seal.
- **Feedback:** ink-settle on place; dry-scratch + struck note on rejected drop (with the reason); cord draw-taut on an armed combine; seal-press + ink-bloom on a resolved combine/upgrade with the delta on a leader line; the raking light shifts to the newly selected mount.
- **Transitions / motion grammar:** one orchestrated motion vocabulary — ink settling, light raking across to the active mount, cord tension, seal press. Not scattered hovers. **All of it gated behind reduced-motion**: the light snaps instead of rakes, cords appear instead of draw, the seal stamps without bloom; every piece of information remains available statically.

## 7. Constraints and open decisions

**Constraints:**
- Flutter + `flutter_bloc` + `go_router`. `## Platform: web` in PRODUCT.md means design-language freedom (custom game UI, no obligation to native components) — but the surface must be genuinely excellent as **two real layouts**, phone portrait and desktop, not one scaled.
- Accessibility baseline (PRODUCT.md): state never by colour alone (met by fixed-cell marks + illumination); text respects OS text-scale without clipping; large forgiving targets with a non-drag alternative; full `prefers-reduced-motion`; captions for any audio added later.
- Performance: the pannable lattice + cord overlay must stay smooth with 30+ mounts and a radial combine hub on a mid phone.
- The cord/annotation overlay should build on the existing `_CombineTetherPainter` rather than replace the tether concept.

**Choices a builder must not invent:**
- **Typefaces** — the direction names *character* only: a brushed or carved-relief display for school / lineage names, and a quiet workhorse for readouts and annotations. Explicitly **not** the training-data defaults (Fraunces, Playfair, Space Grotesk, IBM Plex-as-display, DM Serif, etc.). The specific faces are chosen at world-commit / build time.
- **Grid-growth ceiling** — open game-design question; do not hard-code a max as if it were decided.
- **Player-facing game name / logo** — none confirmed. The frontispiece uses the working title as plain lettered text; do not design or introduce a logo mark.
- **The character strip's expanded stat sheet** — in the IA, but confirm whether it is built this milestone before investing in it.
- **DESIGN.md** — written at finish from the built world by the documenter, not before.
