---
name: Tome — Martial Arts
description: A lacquered lineage hall of mounted forms, drawn in one ink hand under one raking light.
colors:
  lacquer: "#141013"
  lacquer-deep: "#0C090B"
  bone: "#E7DDCA"
  bone-dim: "#9A9384"
  vermilion: "#B23A2E"
  vermilion-ink: "#8E2C22"
  gold: "#B8933F"
  slate: "#6E7377"
  locked-ink: "#433A2D"
  west-ground: "#2E1810"
  east-ground: "#0B171C"
typography:
  display-large:
    fontFamily: "Cinzel, Georgia, serif"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: "1.0px"
    fontVariation: "wght 700"
  display:
    fontFamily: "Cinzel, Georgia, serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.12
    letterSpacing: "1.4px"
    fontVariation: "wght 600"
  heading:
    fontFamily: "Cinzel, Georgia, serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "2.6px"
    fontVariation: "wght 600"
  label:
    fontFamily: "Archivo, Helvetica Neue, sans-serif"
    fontSize: "10.5px"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "1.9px"
    textTransform: "uppercase"
    fontVariation: "wght 640"
  body:
    fontFamily: "Archivo, Helvetica Neue, sans-serif"
    fontSize: "13.5px"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "0.1px"
    fontVariation: "wght 440"
  reading:
    fontFamily: "Archivo, Helvetica Neue, sans-serif"
    fontSize: "14.5px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0.1px"
    fontVariation: "wght 420"
  measure:
    fontFamily: "SplineSansMono, ui-monospace, monospace"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.2
    letterSpacing: "0.2px"
    fontVariation: "wght 460"
  measure-strong:
    fontFamily: "SplineSansMono, ui-monospace, monospace"
    fontSize: "12.5px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.2px"
    fontVariation: "wght 560"
rounded:
  chrome: "0px"
  mark: "2px"
  plate: "3px"
spacing:
  hair: "4px"
  tight: "6px"
  snug: "8px"
  step: "12px"
  panel: "16px"
  frame: "22px"
components:
  button-seal:
    backgroundColor: "{colors.vermilion}"
    textColor: "{colors.bone}"
    typography: "{typography.label}"
    rounded: "{rounded.mark}"
    padding: "11px 18px"
  button-seal-hover:
    backgroundColor: "{colors.vermilion}"
    textColor: "{colors.bone}"
  button-plain:
    backgroundColor: "{colors.lacquer}"
    textColor: "{colors.bone}"
    typography: "{typography.label}"
    rounded: "{rounded.mark}"
    padding: "11px 18px"
  button-quiet:
    backgroundColor: "{colors.lacquer}"
    textColor: "{colors.bone-dim}"
    typography: "{typography.label}"
    rounded: "{rounded.mark}"
    padding: "8px 12px"
  button-gold:
    backgroundColor: "{colors.lacquer}"
    textColor: "{colors.gold}"
    typography: "{typography.label}"
    rounded: "{rounded.mark}"
    padding: "11px 18px"
  mount:
    backgroundColor: "{colors.bone}"
    textColor: "{colors.lacquer-deep}"
    typography: "{typography.label}"
    rounded: "{rounded.plate}"
    size: "132px"
  mount-locked:
    backgroundColor: "{colors.bone-dim}"
    textColor: "{colors.locked-ink}"
  mount-compact:
    backgroundColor: "{colors.bone}"
    textColor: "{colors.lacquer-deep}"
    size: "104px"
  panel-rail:
    backgroundColor: "{colors.lacquer}"
    textColor: "{colors.bone}"
    rounded: "{rounded.chrome}"
    padding: "22px 22px 20px"
    width: "320px"
  panel-foot:
    backgroundColor: "{colors.lacquer}"
    textColor: "{colors.bone}"
    rounded: "{rounded.chrome}"
    padding: "12px 16px 14px"
  sheet:
    backgroundColor: "{colors.lacquer}"
    textColor: "{colors.bone}"
    rounded: "{rounded.chrome}"
    padding: "18px 22px 22px"
  sheet-commit:
    backgroundColor: "{colors.lacquer}"
    textColor: "{colors.bone}"
    rounded: "{rounded.chrome}"
    padding: "16px 24px 24px"
  synergy-tag:
    backgroundColor: "{colors.lacquer}"
    textColor: "{colors.gold}"
    typography: "{typography.measure-strong}"
    rounded: "{rounded.chrome}"
    padding: "4px 8px"
  synergy-tag-mismatch:
    textColor: "{colors.slate}"
  reward-card:
    textColor: "{colors.bone}"
    typography: "{typography.display}"
    rounded: "{rounded.plate}"
    padding: "18px 18px 16px"
---

# Design System: Tome — Martial Arts

## Overview

**Creative North Star: "The Lineage Hall"**

The surface is a dim hall of lacquered boards with martial forms mounted on it — bone plates hung on a coordinate lattice, cords tied between the ones that combine, seals chopped into each plate to name it. It refuses the two obvious neighbours: the neon-glass build screen and the monochrome data grid. Every mark in the build is drawn — chops, rank rings, cords, state marks, button edges, the vitality gauge, the hammer glyph — from one small set of ink primitives on canvas. There are no stock Material widgets, no icon fonts, and no glyph typefaces in the committed surface. The lone exception is the threshold — the title screen and the menus it opens — which is pre-diegetic and may float one oiled-paper panel blurred over the background art behind it; the hall proper never does.

Density is high but never crowded: the board is a pannable lattice with a 22px gutter between 132px cells, and every panel around it is a flat lacquer plane divided from its neighbour by a single 1px bone hairline at 16% alpha. The world is lit by exactly one raking light from the upper-left (`Alignment(-0.72, -0.86)`), and that constant is what makes it read as a physical room rather than a dark theme: the ground's light pool, its answering shade, each plate's inner light-to-shade gradient, and every cast shadow are derived from that one vector.

The palette is deliberately near-monochrome in the field and saturated only at the point of meaning. The board holds at lacquered near-black across its full width; the only chromatic movement is a warm-to-cold tint carried in hue at near-constant value — west traditions hang left in ember umber, east traditions right in cold steel. Bone is the material of anything the player owns. Vermilion is the ink of anything live. Gold is what the hall's light is made of, and at full strength it means mastered.

**Key Characteristics:**
- One ink hand: every mark is canvas-drawn from `handRect` / `inkStroke`, never a widget or icon
- One light: `Alignment(-0.72, -0.86)`, and every shadow, gradient, and highlight derives from it
- Bone plates on a lacquered near-black board; vermilion for live, gold for earned, slate for dead
- A near-flat type ramp where tracking and case, not size, carry rank
- Structural chrome is square and hairline-ruled; only drawn marks get corners
- Deterministic hand-wobble seeded by content id — never animated, never jittering
- State is always shape before colour (four fixed ink marks: filled / hollow / struck / sealed)
- The wordmark is type, not a drawn logogram — *TOME* in Cinzel over the edition line in the mono, with the seal chop as its only identity mark

## Colors

A near-monochrome hall — lacquered black ground, aged bone material, and two inks that mean something the moment they appear.

### Primary
- **Vermilion Seal-Ink** (`{colors.vermilion}`): The one live accent. It is the fill of the commit button (Start Fight, Bind the Cord), the taut cord between two combinable forms, the strike-mark, the active filter-tab underline, drop-registration crosshairs, the text cursor and selection, and the 2px top edge of a sheet that asks for a commit. It renders as dry ink, not flat paint: the filled button lays it at 92% alpha (~`#A5362B` on screen) and only reaches full strength on hover.
- **Vermilion Chop-Ink** (`{colors.vermilion-ink}`): The darker sibling, used exclusively for marks drawn *on* the bone plate — the seal chop and the state mark on a usable mount — where the lighter vermilion would not hold against bone.

### Secondary
- **Tarnished Gold** (`{colors.gold}`): The colour of the hall's light and of what has been earned, and nothing else. At washes of 3.5–5.5% alpha it *is* the raking light — the pool on the wall, the light wash across the ground, the selection highlight, the focus tint. At full strength it appears only on a mastered form (gold chop, gold rank rings, gold sealed state-mark) and on the matched synergy tag. A first-run board contains no full-strength gold at all.

### Tertiary
- **Cold Slate** (`{colors.slate}`): Everything dead, slack, or opposed — the dashed struck cord between forms that cannot combine, a locked mount's state mark, the mismatched synergy tag, and the 22%-alpha grey wash that dulls a locked plate.

### Neutral
- **Aged Bone** (`{colors.bone}`): The material of every mount plate, and the reading colour of every piece of text on a dark ground. Also the hairline: at 14–28% alpha it is every divider, panel edge, tooltip border, extent rail, and empty-position bracket in the build.
- **Dimmed Bone** (`{colors.bone-dim}`): Secondary readouts — struck labels, leader-line quantities, inactive filter tabs, the "0 PTS" hammer count at zero. 6.2:1 on lacquer.
- **Lacquer** (`{colors.lacquer}`): The board ground and the fill of every panel: frontispiece rail, loose rack, foot bar, sheets, callout.
- **Deep Lacquer** (`{colors.lacquer-deep}`): The wall behind the rack, the app scaffold, the tooltip and cord-label grounds, and the ink of a mount's name and address on a bone plate.
- **Locked Ink** (`{colors.locked-ink}`): The lettering and chop of a locked or undiscovered mount, on its greyed bone plate. Chosen to clear 5.78:1 in that dimmed state.
- **West Ground / East Ground** (`{colors.west-ground}` / `{colors.east-ground}`): The two ends of the tradition axis. Both sit near lacquer's value; the halves differ only in temperature.

### Named Rules

**The Earned Gold Rule.** Gold is light or it is mastery — never decoration. Below ~6% alpha it may appear anywhere as the raking light. At any strength above that it must mean the player earned something: a mastered form, a matched synergy, the currently selected plate taking the light. A first-run screen shows no full-strength gold, and that absence is the point.

**The One Organising Axis Rule.** West↔east is the only axis that never collapses. It is carried in *hue at constant value* — a monotonic `srcOver` tint from `{colors.west-ground}` to `{colors.east-ground}` at 55%→16%→16%→55% alpha over lacquer — so the board still reads as near-black `#141013` at 1.0× and the halves only lean warm or cold. Never carry this axis in brightness, saturation, or a hue that lifts the ground off lacquer.

**The Shape-Before-Colour Rule.** No derived state is signalled by colour alone. Locked / usable / mastered / maxed each get one of four fixed ink marks (hollow / filled / sealed / struck) in the plate's top-right corner; cords carry eligibility as taut-vs-dashed-and-struck before they carry it as vermilion-vs-slate; synergy carries as an up-pointing solid triangle vs. a down-pointing struck one before it carries as gold-vs-slate. Colour reinforces; it never informs alone.

## Typography

**Display Font:** Cinzel (with Georgia, serif) — self-hosted variable, `assets/fonts/Cinzel.ttf`
**Body Font:** Archivo (with Helvetica Neue, sans-serif) — `assets/fonts/Archivo.ttf`
**Label/Mono Font:** Spline Sans Mono (with ui-monospace) — `assets/fonts/SplineSansMono.ttf`

**Character:** A carved Roman capital for names, a quiet drawing-office grotesque for everything read, and a measurement hand for anything that is a quantity. The pairing reads as an inscription plate above a technical annotation — inherited weight over engineering precision, with no third voice.

### Hierarchy
- **Display Large** (`{typography.display-large}`): The lineage's own name — the frontispiece rail's character name, set at 27px there — and the game wordmark *TOME* on the title screen, set large. Nothing else. Uppercase always.
- **Display** (`{typography.display}`): Sheet titles and the compact frontispiece name (16px). Uppercase.
- **Heading** (`{typography.heading}`): Section titles inside overlays and sheets — the first-run callout head, the combine-reveal verdict, sheet sub-headers. Runs down to 11–12px in place; the 2.6px tracking is what keeps it a heading at that size.
- **Body** (`{typography.body}`): Every readout and control value — physique, style, tradition, hint lines. Steps to 11–12.5px in dense contexts.
- **Reading** (`{typography.reading}`): Sheet and callout prose only — the one style with a comfortable 1.5 line-height.
- **Label** (`{typography.label}`): Struck, stamped, uppercase micro-labels — PHYSIQUE, THE LOOSE RACK, VITALITY, PTS, filter tabs, mount names, and every button caption. Steps to 9–9.5px for field labels.
- **Measure** / **Measure Strong** (`{typography.measure}` / `{typography.measure-strong}`): Quantities and addresses only — `×1.25 synergy`, `cls I -> II · 1 pt`, `1·1`, `100 / 100`, the upgrade-point count. Strong when the number is the subject.

### Named Rules

**The Three Hands Rule.** Three faces, three jobs, never crossed. Cinzel letters names and section titles and nothing else. Archivo carries all prose, labels, and control captions. Spline Sans Mono is reserved for quantities, classes, ranks, and grid addresses — if a number is a measurement, it is set in the mono; if it is part of a sentence, it is not.

**The Tracking-Carries-Rank Rule.** The size ramp is deliberately flat — 34 / 22 / 15 / 14.5 / 13.5 / 12 / 10.5, most of the surface living between 9 and 14.5px. Hierarchy is carried by tracking and case instead: tracking climbs as size falls (1.0 → 1.4 → 2.6 → 1.9), and anything at label rank is uppercase. Do not reach for a bigger size to make something important; reach for caps and letterspacing.

**The Wordmark-Is-Type Rule.** The game's name is set, never drawn: *TOME* in Cinzel Display Large, the edition line (*The Martial Art Edition*) in Spline Sans Mono at label size beneath a hairline rule. No logogram, monogram, or icon lockup — the seal chop is the only identity mark the product carries.

## Layout

One breakpoint, at **760px viewport width**, and two arrangements of the same four regions.

**Wide (≥760):** board fills the left, a fixed **320px** frontispiece rail sits at the right behind a 1px bone hairline (padding `22 / 22 / 22 / 20`), the loose rack spans the full width below it, and the foot bar closes the screen. Board cells are **132px**; the rack is **132px** tall.

**Narrow (<760):** the frontispiece collapses to a compact top rule (padding `16 / 10 / 16 / 11`), the board expands to fill, the rack becomes a **120px** bottom drawer, and the foot bar stays at the foot. Board cells drop to **108px**.

The board itself is a fixed coordinate lattice inside an `InteractiveViewer` (scale 0.5–2.4, `boundaryMargin` of 1.5 cells) with a **22px** gutter between cells and around the edge. It auto-fits once — scaled to fill the vertical space, clamped to 0.55–1.7, and allowed to overrun horizontally so the player pans along the west↔east axis. Double-tap re-fits. Thin **2–3px** extent rails appear at the right and bottom edges only when the lattice outruns the frame.

The loose rack is a horizontal list of **104px** pieces at a **12px** gap, and always shows at least **12** mounting positions — a rack with visible capacity, never a black void.

Spacing runs on a two-tick rhythm — 4, 6, 8, 10, 12, 14, 16, 18, 22, 24 — with panel padding sitting at 14–24 and inline gaps at 4–12. Sheets pad `22 / 18 / 22 / 22` (detail) and `24 / 16 / 24 / 24` (commit); the combine reveal is the one place that opens to 28/24.

**Threshold surfaces** — the title screen and the menus it opens — do not use the four-region layout. They centre one oiled-paper panel in the field, wordmark and a vertical action column stacked inside it, with space kept around it for a background painting. That composition is theirs alone; the in-game surface never adopts it.

**The Hairline Division Rule.** Regions are separated by exactly one 1px bone rule at 16% alpha on the shared edge — never by a gap, a shadow, a colour step, or a rounded card. The only heavier rule in the build is a sheet's 2px top edge, which is what makes a sheet read as arriving rather than as another panel.

## Elevation & Depth

Depth is modelled, not stacked. There is one light source — `kRakingLight = Alignment(-0.72, -0.86)` — and every depth cue in the build is derived from it, so a mount, a button, a callout, and the board ground all agree about where the light is. Shadows are soft and always cast down-and-right; there are no zero-offset colour halos and no hard offset shadows anywhere in the build.

Three cues stack, in this order:
1. **A cast shadow** offset along `-kRakingLight` and blurred.
2. **An inner light-to-shade gradient** on the lit surface itself: white at 16% alpha at the light corner → transparent at midpoint → black at 14% alpha at the opposite corner.
3. **A carved edge stroke** — 1.6px at 50% alpha at rest, widening to 2.6px in the selection's gold when the plate takes the light.

### Shadow Vocabulary
- **Plate shadow** (`translate(4.4, 5.4)`, blur 9, black @ 44%): The mounted form's own shadow on the board. The single most-used depth mark in the build.
- **Control shadow** (`translate(2.4, 3)`, blur 5, black @ 34%): Under an `InkButton` at rest. Removed entirely while pressed — a button sits down into the board rather than changing colour.
- **Raking shadow, elevation 1** (`offset(4.3, 5.2)` blur 14 @ 42% + `offset(1.4, 1.7)` blur 4 @ 22%): The two-layer stack from `rakingShadow()`, used on floating overlays such as the first-run callout. Both layers derive their offset from `-kRakingLight`, scaled by an `elevation` multiplier.
- **Threshold panel** (`BackdropFilter` blur ~10 + bone fill @ 66–82% + `rakingShadow(elevation: 1.2)`): The oiled-paper panel behind the title screen and its menus — the only `BackdropFilter` in the project.

### Named Rules

**The One Light Rule.** Every shadow, highlight, gradient, and inner shade in the build derives from `kRakingLight`. A new element must read its direction from that constant, never hard-code an arbitrary offset, and never introduce a second source. If a surface needs to look lifted, cast a soft shadow down-and-right and lighten its upper-left; nothing else.

**The Press-Is-Depth Rule.** A pressed control loses its shadow and thickens its edge stroke (1.6 → 2px); it does not change colour. Hover raises the fill alpha (0.05 → 0.12 outlined, 0.92 → 1.0 filled) and the edge alpha (0.7 → 0.95). Disabled drops the whole control to 40% opacity.

**The Frost-Is-Threshold-Only Rule.** A `BackdropFilter` blur appears on exactly one class of surface: the pre-diegetic threshold — the title screen and the menus it opens — where a panel must stay legible over background art not yet placed. It reads as oiled paper, not glass: a warm bone tint, a matte `handRect` edge, a soft raking shadow — never a bright rim-light, a specular streak, or a high-chroma wash. The hall proper — board, rails, rack, foot bar, sheets — stays opaque flat lacquer.

## Shapes

Two form languages, kept strictly apart.

**Drawn marks** are hand-cut. Every one of them is a `handRect` — a rounded rectangle with a **2–3px radius** and a deterministic ±0.9px wobble on all eight control points, seeded by the element's content id or label hash. This is the corner language of mount plates (r3), button edges (r2), the chop border (r3), the board's own carved frame (r2), the four state marks (r1–2), and the two plates that are not mounts — the reward card and the threshold panel, both drawn `handRect` outlines at r3, never Material cards. Because the wobble comes from a hash and not a random source, a given form's plate looks identical on every rebuild and every frame.

**Structural chrome** is square. The frontispiece rail, loose rack, foot bar, bottom sheets, tooltips, and synergy tag all have **0px radius** and no fill variation — flat lacquer planes divided by 1px bone hairlines. The scrollbar thumb is a 3px square-cornered bar at 22% bone.

Recurring geometry:
- **Corner brackets, not boxes.** An empty mounting position is four L-shaped brackets at 16% of the cell's shortest side plus a small "+" at 22% alpha — a registration mark, never an outlined box. A full dashed `handRect` outline appears only when a drop is armed or hovering.
- **Concentric rings** carry rank: one 1.6px circle per mastery level stepping inward at 5px, with a 2.4px open progress arc on the outermost track starting from twelve o'clock.
- **The chop** is a square border with 3–4 carved strokes on a 3×3 sub-grid plus one horizontal base rule, all chosen from a hash of the content id. It is an identity mark, not an icon: it is never authored by hand and never reused across content.
- **Rules and leader lines.** Quantities are annotated with a 1.6px dot, a 22px 1.2px rule, and the mono value — the hall's one way of pointing at a number.

## Components

### Buttons
Struck ink edges, never Material. Four tones off one painter.
- **Shape:** Hand-cut corners (`{rounded.mark}` with wobble), a soft shadow down-and-right, no shadow while pressed.
- **Seal (primary/commit):** Vermilion fill at 92% alpha (full on hover) with a 1.4px black inner stroke at 25%, bone uppercase caption. Reserved for the one committing action on the surface — Start Fight, Bind the Cord.
- **Plain / Gold / Quiet (secondary):** No fill of their own — a 5% tint of the tone's ink (12% on hover) inside a 1.6px stroke of that ink at 70% (95% on hover). Plain is bone, gold is the mastery path, quiet is dimmed bone for a cancel.
- **Padding:** `11px 18px` standard, `8px 12px` dense. Caption is Archivo uppercase 11px (dense 10px) at 1.8px tracking.
- **Glyph:** An optional 14px canvas-drawn glyph 8px before the caption. Drawn, never an icon font.
- **Disabled:** The whole control at 40% opacity, non-interactive, cursor stays default.

### Cards / Containers
There are no Material cards and no rounded structural chrome. Regions are flat lacquer planes with a single 1px bone hairline at 16% alpha on the edge they share with the next region, zero radius, and no shadow. The two container-like objects that do exist — the **reward card** and the **threshold panel**, both documented below — are drawn plates (`handRect` outline, r3), not cards. Anything else that needs to look like an object is a **mount**.

### Sheets
- **Style:** Bottom sheets on `{colors.lacquer}`, zero radius, zero elevation, no surface tint, over a 62% black barrier. A 28px × 3px bone grab-rule at 28% alpha sits at the top.
- **Top edge:** 2px, and its colour is the tell — bone at 20% for a detail sheet, **vermilion at 50%** when the sheet asks for a commit.
- **Padding:** `18 / 22 / 22 / 22` detail, `16 / 24 / 24 / 24` commit.

### Navigation
The rack's filter tabs are the only navigation: uppercase Archivo at 9.5px, dimmed bone when inactive and full bone when active, with a **2px vermilion underline** under the active one and 14px of leading space between tabs. No pill, no background, no border.

### The Mount (signature)
The build's defining component, used identically on the board, in the loose rack, and inside sheet previews so a form looks the same wherever it hangs.

A bone plate carrying, in fixed positions: the **seal chop** at upper-left (a content-hashed identity glyph), the **rank rings** at upper-right when mastery exists, the **state mark** pinned to the top-right corner at 16% of the plate's side, the **name** in uppercase label ink below, and the **address plus annotation** in mono beneath that (`1·1   cls I`). Padding is proportional — 11% of the plate's short side, 9% when compact.

States:
- **Usable / learned / active** — full bone plate, vermilion chop-ink, filled state mark.
- **Locked / unknown** — plate washed with slate at 22%, all lettering and the chop in `{colors.locked-ink}` (5.78:1), hollow state mark. A locked form stays *legible*; its state is carried by the mark's shape, not by dimming it away.
- **Mastered** — gold chop, gold concentric rank rings, gold sealed state mark. The only place gold reaches full strength on a plate.
- **Maxed** — the state mark becomes the struck mark, in whichever ink its base state carries.
- **Selected** — the plate takes the raking light (a gold radial wash at 22% from its upper-left) and its carved edge widens to 2.6px in gold; every other mount drops to 52% opacity.
- **Spotlight** (just arrived) — an extra 2.4px vermilion edge stroke over the plate.
- **Dragging** — the source cell falls back to its empty-position brackets at 25% opacity; the drag ghost is the same mount at 92% opacity, pointer-anchored.

### The Cord (signature)
The tether drawn *under* the mounts between forms that share a definition and class.
- **Eligible:** a taut 3px vermilion `inkStroke` at 92% alpha — a brushed doubled line with a slight bow, mid-labelled `cls I -> II · 1 pt` on a deep-lacquer plate at 78%.
- **Ineligible:** a dashed 1.6px slate stroke at 50% with a perpendicular strike through its midpoint, labelled `maxed`.
- **Three or more:** the cords converge on a radial hub — a 5px filled dot inside an 8px 1.4px ring — labelled `N matched`.

### Empty Mounting Position
Four corner brackets plus a "+" at 22% bone. When a piece is armed or hovering, brackets and hint rise to 80–90% alpha and a dashed hand-cut outline appears; on accept, everything switches to vermilion and four registration crosshairs strike the corners.

### The Frontispiece
Carved uppercase name over hairline rules, then **struck marks** (a 9px uppercase label above a 13px body value, 12px apart), the **synergy tag** (a bordered box carrying a directional triangle glyph and the mono multiplier — gold and pointing up when matched, slate and pointing down-and-struck when not), and the **vitality gauge**: a 132×6 rule filled to fraction in bone at 85% over bone at 18%, notched at the quarters.

### The Reward Card
The one plate used away from the board, on the FIGHT REWARDS screen — three abreast on wide, a stack on narrow. A drawn `handRect` outline at r3 in bone at 50%, no fill, padded `18 / 18 / 18 / 16`. Top to bottom inside: a 52px vermilion **seal chop** keyed to the reward's identity, the reward title in Cinzel Display at 16px, an optional vermilion uppercase **badge** (`CLASS I`, `TECHNIQUE`), the explanation in dimmed-bone body, one row per rolled effect (a 5px solid vermilion square before a mono line), and a seal-tone **Take** button at the bottom-left. The whole card is a tap target, not only the button.

### The Vitality Bar
The combatants' health on the combat screen, one bar each. An uppercase **label** name, a `measure` readout (`72 / 100`, or `—` before the first snapshot), and between them an **8px track** in bone at 14% carrying a vermilion fill — slate at zero. The enemy's bar is mirrored: name, numerals and fill sit right and the fill drains from the centre outward, so the player always reads from the left edge and the enemy from the right. This is the in-fight readout; the frontispiece's 132×6 **vitality gauge** is the between-fight one.

### The Threshold Panel
The oiled-paper panel carrying the title screen and every menu opened from it. A `BackdropFilter` blur (~10px) behind a bone fill at ~72% (buttons on it deepen to ~82%), edged with a `handRect` stroke at r3 and lifted on `rakingShadow(elevation: 1.2)`. It exists so those pre-diegetic screens stay legible over a full-bleed background painting not yet placed. It is the project's only translucent surface (see The Frost-Is-Threshold-Only Rule) and must read as waxed paper, not glass. The game **wordmark** heads it — *TOME* in Cinzel Display Large over *The Martial Art Edition* in the mono, a hairline between, the **seal chop** alongside as identity — then a vertical column of `InkButton`s with the one seal-tone action (New Run) leading and Quit shown on desktop only.

## Do's and Don'ts

### Do:
- **Do** draw every new mark from `ink.dart` — `handRect`, `inkStroke`, `drawInkMark`, `rakingShadow` — so it joins the one ink hand.
- **Do** derive every shadow, highlight, and gradient from `kRakingLight = Alignment(-0.72, -0.86)`; a new element reads its light direction from that constant.
- **Do** seed every hand-wobble from a content id or label hash so a mark is identical on every rebuild.
- **Do** give every state a shape before you give it a colour — one of the four fixed ink marks, a stroke weight, a dash pattern, or a direction.
- **Do** hold the board at lacquered near-black `{colors.lacquer}` across its width, letting only the west↔east hue tint move.
- **Do** reach for uppercase and letterspacing when something needs rank, not for a larger size.
- **Do** set every quantity, class, rank, and grid address in Spline Sans Mono, and everything readable in Archivo.
- **Do** separate regions with a single 1px bone hairline at 16% alpha.
- **Do** keep the commit action to exactly one seal-tone button per surface.
- **Do** collapse animation to 1ms under `MediaQuery.disableAnimations`, as the combine reveal does.
- **Do** set the game wordmark as type only — *TOME* in Cinzel over *The Martial Art Edition* in the mono, the seal chop as its identity mark — never a drawn logogram or an icon lockup.
- **Do** keep `BackdropFilter` frost to the threshold (title screen and the menus it opens): a warm bone tint with a matte `handRect` edge, over the background art.

### Don't:
- **Don't** use a Material button, icon font, or glyph typeface in the committed surface — the build ships none, and adding one breaks the one-hand claim.
- **Don't** put gold above ~6% alpha on anything the player has not earned. Selection, mastery, and matched synergy only.
- **Don't** round structural chrome. Rails, racks, foot bars, sheets, tooltips, and tags are 0px; corners belong to drawn marks.
- **Don't** add a second light, a zero-offset colour halo, or an unblurred offset shadow.
- **Don't** carry the west↔east axis in brightness or saturation — it is hue at constant value, or it collapses.
- **Don't** dim a locked mount into illegibility; wash the plate and switch to `{colors.locked-ink}`, which holds 5.78:1.
- **Don't** signal a state with colour alone, and don't introduce a fifth state mark — the four fixed cells are the vocabulary.
- **Don't** show an empty region as a black void; show its mounting positions (the rack always renders at least 12).
- **Don't** animate the hand-wobble, add idle motion, or use a splash/ripple — the build sets `NoSplash` and a transparent highlight deliberately.
- **Don't** give the wordmark a logogram, monogram, or icon lockup, and don't let the threshold panel read as glass — no bright rim-light, specular streak, or high-chroma wash; it is oiled paper over the light.
- **Don't** bring `BackdropFilter` or any translucency into the in-game surface — board, rails, rack, foot bar and sheets stay opaque flat lacquer.
