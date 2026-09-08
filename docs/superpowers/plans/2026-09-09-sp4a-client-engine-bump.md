# SP4a (client) — Staged `build_engine` bump `314f75a` → HEAD — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `Tome_client`'s `build_engine` git pin from `314f75a` (2026-09-01) to engine `main` HEAD across five sequential, independently-green PRs — one per engine milestone (SP0a → SP0b → SP1 → SP2 → SP3) — with no new UX.

**Architecture:** Each stage is a `pubspec.yaml` `build_engine.ref` bump plus the minimal compatibility work that stage's engine surface forces. The audit predicts exactly **one hard compile break** (`lib/core/engine/combat_adapter.dart` ×3, at the SP1 stage); every other stage should be compile-clean and behaviourally inert for the client. Local iteration uses a gitignored `pubspec_overrides.yaml` pointing at a local engine worktree checked out to the stage's ref (this session cannot fetch the private engine over HTTPS); each PR still **lands** with the real git `ref` in `pubspec.yaml` and `pubspec.lock`, which authenticated CI validates.

**Tech Stack:** Flutter (stable channel), Dart. `flutter pub get` / `flutter analyze` / `flutter test` / `scripts/package_itch.sh`. `build_engine` is a private git dependency.

**Specs:**
- **This client's spec:** `docs/superpowers/specs/2026-09-08-sp4a-client-bump-design.md` — read it; `§` references point into it.
- **Engine contract register (authoritative):** in the engine repo at `docs/superpowers/specs/2026-09-08-sp4a-engine-bump-design.md` §5. Per stage it lists the exact engine ref to pin and the public surface the client may rely on. A full copy of the relevant rows is inlined per task below so an executor needs no engine checkout to read requirements.
- **Engine audit backing both:** engine repo `docs/superpowers/specs/2026-09-08-sp4a-engine-bump-notes.md`.

## Global Constraints

- **Five PRs, strictly sequential.** PR N does not begin until PR N−1 is merged to `main` and its gate is green. Each PR pins one specific engine commit and does only that stage's compat work. Branch names: `sp4a-bump-1-sp0a`, `sp4a-bump-2-sp0b`, `sp4a-bump-3-sp1`, `sp4a-bump-4-sp2`, `sp4a-bump-5-sp3`.
- **Green gate, every PR:** `flutter pub get && flutter analyze && flutter test`. PR 5 additionally: `scripts/package_itch.sh` (web release build; it is in CI).
- **Determinism-property check, every PR:** after the bump, re-run `test/core/engine/combat_adapter_test.dart`, `test/core/engine/combat_mastery_test.dart`, `test/features/run/run_bloc_test.dart`, `test/core/engine/training_adapter_test.dart`. The property that must hold: *same `EngineSession(seed)` + same submitted `TrainingAttempt`s / same combat inputs, run twice → identical outcome.* If a specific seed's asserted number/pattern moved **but the property holds**, update the inline expectation to the observed value and note it in the PR. **If two identical runs diverge, STOP — real bug, do not touch the fixture.**
- **Scope freeze (client spec §2.2).** SP4a does **NOT**: roll tiered affixes or change the reward model; touch `component_detail_sheet`; adopt `AuraBinder` or `ConsumableBinder`; register `ConsumablePlugin`; add consumable UI/reward entries; mint or hang `TechniqueVariant` instances; call `resolveTechniqueInspirationAfterTraining`; derive real `ownedRefs` (a `const []` placeholder with a `// SP4b` marker is the SP4a fix); build a `TomeClientAlmanacAdapter`. **If a stage cannot go green without one of these, STOP** and report — the SP4a/SP4b boundary needs revisiting, not the scope.
- **Contract discipline (client spec §2.3).** Do not touch engine surface not listed as merged in that stage's contract-register rows below. If breakage points at an API outside the listed rows, STOP and report.
- **The `pubspec_overrides.yaml` file and any `.claude/` / `.superpowers/` scratch never land.** Task 0 gitignores them. Every stage commit contains only: `pubspec.yaml` (the `ref` line), `pubspec.lock` (two SHA lines), and that stage's compat fixes / fixture re-baselines.
- **Commit trailer** — every commit message ends with:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01E3k4BFeWXfPzkZzXinqTZk
  ```
- **Engine ref for the final stage.** The client spec §4 table wrote Stage 5 as `1dc7e5d` ("engine HEAD" at spec-writing time). Engine HEAD has since advanced to **`b43b414`** (the SP4a Part A merge — engine-internal Almanac changes only, none of which the client consumes). Stage 5 pins `b43b414`. This is the one deliberate deviation from the spec table; it is a strict superset of `1dc7e5d` and client-inert.

---

## Local iteration mechanism (used by Tasks 1–5)

The client's `pubspec.yaml` keeps its real `git: {url: https://github.com/MGTechLabs2026/built_engine.git, ref: <SHA>}` dependency. Local `flutter pub get` cannot fetch that private URL in this environment, so each stage overrides it locally:

- **`ENGINE_WT`** = `/Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine` — a single engine worktree, created once in Task 0, `git checkout`ed to the stage's ref at the start of each stage.
- **`pubspec_overrides.yaml`** (gitignored, repo root) contains, for the whole run:
  ```yaml
  dependency_overrides:
    build_engine:
      path: /Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine
  ```
  `flutter pub get` reads it automatically; it resolves `build_engine` from the worktree's current checkout regardless of `pubspec.yaml`'s `ref`.
- **`pubspec.lock`** while the override is active records `build_engine` as a `path` source. That must **not** be committed. Each stage's commit instead sets the lock's `build_engine` block back to the `git` source with the stage ref, via:
  ```bash
  # from the client repo root, with the stage SHA in $REF
  perl -0pi -e 's/(  build_engine:\n(?:    .*\n)*?    source: )path/${1}git/;
                 s/(  build_engine:\n    dependency: "direct main"\n    description:\n      )path: "\."/${1}path: "."/;
                 s/(  build_engine:\n(?:    .*\n)*?      ref: ")[0-9a-f]{40}(")/${1}$ENV{REF}${2}/;
                 s/(  build_engine:\n(?:    .*\n)*?      resolved-ref: ")[0-9a-f]{40}(")/${1}$ENV{REF}${2}/' pubspec.lock
  ```
  If that regex is fragile on your machine, hand-edit the `build_engine:` block in `pubspec.lock` to exactly:
  ```
    build_engine:
      dependency: "direct main"
      description:
        path: "."
        ref: "<full-40-char stage SHA>"
        resolved-ref: "<same full-40-char stage SHA>"
        url: "https://github.com/MGTechLabs2026/built_engine.git"
      source: git
      version: "0.1.0"
  ```
  CI's authenticated `flutter pub get` is the real validation that this lock resolves; a mismatch fails CI loudly.
- **Full engine SHAs** (the `perl`/lock edit needs the 40-char form; get them in Task 0):
  `git -C $ENGINE_WT rev-parse cb32b02 ff8c7db 0663e8e dc213d4 b43b414`

---

## Task 0: Local iteration harness + baseline

**Files:**
- Create: `pubspec_overrides.yaml` (repo root, will be gitignored)
- Modify: `.gitignore`
- Create: `docs/superpowers/plans/sp4a-engine-shas.txt` (scratch note of the 5 full SHAs — gitignored via the same `.gitignore` line pattern? no — put it in the SDD workspace instead; see Steps)

**Interfaces:**
- Produces: `ENGINE_WT` worktree at a known path; a working `pubspec_overrides.yaml`; the 5 full engine SHAs recorded in the SDD ledger; a confirmed-green baseline at the current pin `314f75a`.

- [ ] **Step 1: Create the engine worktree**

```bash
git -C "/Users/m4maxpro/Projects/Tome:RougelikeGame" worktree add \
  "/Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine" 314f75a
```
Expected: worktree created, detached HEAD at `314f75a` (the client's current pin — so the baseline in Step 4 matches what CI would resolve today).

- [ ] **Step 2: Record the 5 full engine SHAs**

```bash
git -C "/Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine" \
  rev-parse cb32b02 ff8c7db 0663e8e dc213d4 b43b414
```
Write the five 40-char SHAs into the SDD ledger (or `<sdd-workspace>/engine-shas.txt`), labelled SP0a / SP0b / SP1 / SP2 / SP3. Tasks 1–5 read them from there.

- [ ] **Step 3: Add the gitignore lines + the override file**

Append to `.gitignore` (below the existing `.worktrees/` line, ~line 122):
```
pubspec_overrides.yaml
.claude/
.superpowers/
```
Create `pubspec_overrides.yaml` at the repo root:
```yaml
# LOCAL ONLY — gitignored. SP4a client engine bump: resolve build_engine
# from a local worktree while iterating, because this environment cannot
# fetch the private engine over HTTPS. Each PR still lands the real git
# ref in pubspec.yaml / pubspec.lock; CI validates resolution.
dependency_overrides:
  build_engine:
    path: /Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine
```
Verify: `git status --porcelain` shows ONLY ` M .gitignore` (the override file and any `.claude/` dir are ignored).

- [ ] **Step 4: Baseline green at the current pin**

```bash
flutter pub get
flutter analyze
flutter test
```
Expected: `flutter pub get` resolves `build_engine` from the worktree (at `314f75a`); `flutter analyze` clean; `flutter test` all pass. This is the pre-bump reference — record the test count.
If `flutter pub get` fails to read the override path, fix the path in `pubspec_overrides.yaml` (must be absolute, must exist) before proceeding.
If `flutter analyze` or `flutter test` is **not** clean at `314f75a`, STOP — the baseline is dirty and every later failure becomes ambiguous. Report it.

- [ ] **Step 5: Commit the gitignore change**

```bash
git checkout -b sp4a-bump-0-harness
git add .gitignore
git commit -m "chore: gitignore SP4a local-iteration scratch

pubspec_overrides.yaml (local engine path override while the private
engine dep can't be fetched here) plus .claude/ / .superpowers/ agent
scratch. None of these land in a bump PR.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E3k4BFeWXfPzkZzXinqTZk"
```
Merge it to `main` (fast-forward) before starting Task 1 — it is a prerequisite for every later branch being clean.
```bash
git checkout main && git merge --ff-only sp4a-bump-0-harness && git branch -d sp4a-bump-0-harness
```

---

## Task 1: PR 1 — bump to SP0a (technique instancing)

**Engine contract register — Stage 1 (verbatim from engine spec §5):**
> **Stage 1 — SP0a · pin `cb32b02`**
> - **Relied on:** unchanged base-family accessors — `techniqueDefinition`, `discoverTechnique`, `isTechniqueDiscovered`, `isTechniqueLearned`, `techniqueMasteryLevel`, `trainTechniqueMastery`, `attemptToLearnTechnique`. `addTechniqueToTome` / `TomeService.insert` / `.replace` with a bare `BuildComponentRef` (null `instanceEntityId`) — documented legacy path, still resolves as the bare base.
> - **NOT relied on in SP4a:** `TechniqueVariant`, `mintTechniqueVariant`, `hangTechniqueVariant`, `removeTechniqueVariant`, `ownedTechniqueVariants`, `TechniqueVariantResolver`, `composeAxisProfile`, `techniqueInstanceSubject`, `trainTechniqueVariantMastery`, `techniqueVariantMasteryLevel`, `mintVariantForLegacyEvolvedId`, `LegacyTechniqueMigrationException`, `TechniqueDescriptor`, `TechniqueAxes`, events `TechniqueVariantMinted` / `TechniqueVariantRemoved`, optional `instanceId` on `TechniqueAddedToTome`.
> - **Client compatibility work:** none expected (compile-clean, inert).
> - **Migration hazard:** `mintVariantForLegacyEvolvedId` is the only path that throws `LegacyTechniqueMigrationException`; the client must not call it. Its evolution stays `resolveTechniqueEvolutionAfterTraining` → string id → `tome.replace` (null instance).

**Files:**
- Modify: `pubspec.yaml` (the `build_engine:` `ref:` line — the audit places it ~line 53)
- Modify: `pubspec.lock` (`build_engine` block — `ref` + `resolved-ref`, per the mechanism section)
- Possibly modify: nothing else expected. Any `lib/` or `test/` change here is unanticipated — see Step 5.

**Interfaces:**
- Consumes: `ENGINE_WT`, `pubspec_overrides.yaml`, the SP0a full SHA from Task 0.
- Produces: `main` with `build_engine` pinned at SP0a `cb32b02`, gate green.

- [ ] **Step 1: Branch + point the worktree at SP0a**

```bash
git checkout main && git pull --ff-only && git checkout -b sp4a-bump-1-sp0a
git -C "/Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine" checkout cb32b02
```

- [ ] **Step 2: Bump the pin**

In `pubspec.yaml`, set the `build_engine:` `ref:` value to the **short** ref `cb32b02` (match the file's existing style — it currently holds a 40-char SHA; either the short or full form is fine for git, use the full 40-char SP0a SHA from Task 0 for consistency with how the pin was written before).

- [ ] **Step 3: Resolve + gate**

```bash
flutter pub get     # resolves build_engine from ENGINE_WT (now at cb32b02)
flutter analyze
flutter test
```
Expected: all clean/green, test count identical to the Task 0 baseline. SP0a is "data + lifecycle only" and the client mints no variants, so `instanceEntityId` stays null everywhere and every `TechniqueVariant*` path stays dormant.

- [ ] **Step 4: Determinism-property check**

Re-run the four determinism-sensitive test files (Global Constraints). Expect identical results. Any drift here at SP0a is unexpected (SP0a changes no combat math) — investigate before continuing.

- [ ] **Step 5: If analyze/test is NOT clean**

Triage every error against the **Relied on** vs **NOT relied on** lists above:
- Error names a **Relied on** symbol whose signature changed → fix per the engine's `CHANGELOG.md` "Added — Technique instancing (SP0a)" section (read it in `ENGINE_WT/CHANGELOG.md`). Keep the change minimal and on the legacy path.
- Error names a **NOT relied on** symbol → the client is using engine surface it shouldn't for SP4a. **STOP**, report which symbol and where — this is a scope/boundary question, not a fix-it-and-move-on.
- `LegacyTechniqueMigrationException` thrown at runtime in a test → the client is calling `mintVariantForLegacyEvolvedId` somewhere. **STOP** and report; the client's evolution path must stay string-id + legacy `tome.replace`.

- [ ] **Step 6: Fix `pubspec.lock` for landing**

Set the `build_engine` block in `pubspec.lock` back to the `git` source with `ref` and `resolved-ref` both = the **full 40-char SP0a SHA** (mechanism section). Confirm `git diff pubspec.lock` shows only those lines (and `source: path` → `source: git`) changed.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock   # + any Step-5 compat fixes, explicitly listed
git commit -m "build(engine): bump build_engine to SP0a (technique instancing)

Ref cb32b02. Compile-clean and behaviourally inert for the client: no
TechniqueVariant is minted, instanceEntityId stays null, the legacy
addTechniqueToTome / tome.replace path is unchanged. <add: 'No source
changes.' OR the one-line summary of any Step-5 compat fix.>

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E3k4BFeWXfPzkZzXinqTZk"
```

- [ ] **Step 8: PR + merge**

Push `sp4a-bump-1-sp0a`, open a PR against `main` titled `SP4a bump 1/5 — SP0a (technique instancing)`, body linking this plan and the client spec. Wait for CI green (CI does the authenticated `flutter pub get` — this is where the hand-edited lock is validated). Merge. Delete the branch. **Do not start Task 2 until this is merged and green.**

---

## Task 2: PR 2 — bump to SP0b (technique inspiration / discovery)

**Engine contract register — Stage 2 (verbatim):**
> **Stage 2 — SP0b · pin `ff8c7db`**
> - **Relied on:** `resolveTechniqueEvolutionAfterTraining(owner, technique, profile, context) → EvolutionResult { evolved, chosenCandidate.targetId, eligibleCandidates }` — signature + shape verified unchanged at HEAD.
> - **NOT relied on:** `CombatAction.sourceRef` (+ matching optional ctor param on `AttackAction` / `SelfEffectAction`), `TechniqueUsageComponent`, `recordTechniqueVariantUsage`, `techniqueVariantUsage`, `TechniqueInspirationResolver`, `Inspirer` / `InspirationResult`, `resolveTechniqueInspirationAfterTraining`, `TechniqueVariantInspired`, `styleCentre`, `techniqueFamilyOf`, `requireTechniqueVariant`, the `kInspiration*` constants.
> - **Client compatibility work:** none. The inspiration hook is not called; the client owns no `TechniqueVariant` for it to draw from; no `context.rng` draw occurs.
> - **Optional-param note:** `AttackAction` / `SelfEffectAction` gained an optional named `sourceRef`. The client's existing constructions are unaffected.

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`. Nothing else expected.

**Interfaces:**
- Consumes: Task 1 merged (`main` at SP0a); the SP0b full SHA from Task 0.
- Produces: `main` with `build_engine` at SP0b `ff8c7db`, gate green.

- [ ] **Step 1: Branch + worktree**

```bash
git checkout main && git pull --ff-only && git checkout -b sp4a-bump-2-sp0b
git -C "/Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine" checkout ff8c7db
```

- [ ] **Step 2: Bump `pubspec.yaml` `ref:` → the full SP0b SHA.**

- [ ] **Step 3: Gate**

```bash
flutter pub get && flutter analyze && flutter test
```
Expected: clean/green, count identical to Task 1. SP0b's new surface is entirely in the "NOT relied on" list and inert for the client.

- [ ] **Step 4: Determinism-property check** (the four files). Expect identical; no `context.rng` draw is added on any client path.

- [ ] **Step 5: If not clean** — same triage as Task 1 Step 5, against Stage 2's Relied/NOT-relied lists. An optional-param compile error on `AttackAction`/`SelfEffectAction` would be surprising (they are additive) — if it happens, it means the client passed positional args past the new optional slot; fix by naming the args. Anything touching `resolveTechniqueInspirationAfterTraining` → STOP (client must not call it in SP4a).

- [ ] **Step 6: Fix `pubspec.lock`** → full SP0b SHA (mechanism section).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock   # + any listed compat fix
git commit -m "build(engine): bump build_engine to SP0b (technique inspiration)

Ref ff8c7db. Inert for the client: resolveTechniqueInspirationAfterTraining
is never called, the client owns no TechniqueVariant, no context.rng draw
is added. resolveTechniqueEvolutionAfterTraining signature unchanged.
<'No source changes.' OR the compat-fix one-liner.>

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E3k4BFeWXfPzkZzXinqTZk"
```

- [ ] **Step 8: PR + merge** — `SP4a bump 2/5 — SP0b (technique inspiration)`. CI green → merge → delete branch. Do not start Task 3 until merged.

---

## Task 3: PR 3 — bump to SP1 (tiered component effects) — the compile break

**Engine contract register — Stage 3 (verbatim):**
> **Stage 3 — SP1 · pin `0663e8e`**
> This pin also crosses **Almanac v1** and the **SP1 game-run migration**. Both are **inert for the client**: it calls no `runGame`, constructs no `AlmanacRecorder`, imports no `almanac*` barrel; and it stays on the legacy null-instance technique path so the game-run's variant-first `TrainingStage` rewrite and typed `RunTrainingTarget` policies never touch it (the client uses no engine decision policy).
> - **Relied on (changed surface):**
>   - `TomeService.resolve(EntityId owner, {required List<BuildComponentRef> ownedRefs}) → ResolvedBuild`. `ResolvedBuild` exposes `owner` / `active` / `owned` / `asActiveBuild` — **no `.components`**.
>   - `BuildActionInterpreter.interpret({required ResolvedBuild build, …})` (`ItemActionInterpreter` included).
>   - `ItemInstance.statBonuses` (field) and `addItemStatBonuses` (writer) — **retained**; now feed `ItemEffectContributor`'s `supporting` tier instead of an `affix:*` `Modifier`. Client reads/writes stay valid.
>   - `WeaponStatTags` — relocated to `item_plugin.dart`; compat re-export from `build_interpretation.dart` retained, so `show WeaponStatTags` imports keep working.
> - **NOT relied on:** `EffectTier`, `EffectProfile`, `EffectContributor`, `EffectProfileResolver`, `ItemEffectContributor` (directly), `BuildComponentRef` value equality (as a client concern), the `active`/`permanent` tiers.
> - **Client compatibility work — the one hard compile break:** `combat_adapter.dart`:
>   1. `_ctx.tome.resolve(_me)` → `_ctx.tome.resolve(_me, ownedRefs: const [])` (`// SP4b: derive real ownedRefs` — reference: `game_run.dart` `ownedComponentRefs(character, context)`).
>   2. `build.components` (×2) → `build.active`.
>   3. `_itemInterpreter.interpret(build: build, …)` — correct once `build` is the `ResolvedBuild` from (1).
> - **Behavioural drift to expect:** two hung copies of one item now each contribute scaled `attack` (old `build:<itemId>` source collapsed duplicates); item modifier source is per-actor. Re-baseline any drifted `combat_adapter_test.dart` / `combat_mastery_test.dart` inline seed expectations to observed values. Grep client tests for `affix:` / `build:` / `removeBySource(` modifier-source assertions (none expected).

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Modify: `lib/core/engine/combat_adapter.dart` — three edits (below, exact)
- Possibly modify: `test/core/engine/combat_adapter_test.dart`, `test/core/engine/combat_mastery_test.dart` — inline seed re-baselines **only if** a value drifts and the determinism property still holds

**Interfaces:**
- Consumes: Task 2 merged (`main` at SP0b); the SP1 full SHA from Task 0.
- Produces: `main` with `build_engine` at SP1 `0663e8e`, `combat_adapter.dart` compiling against `ResolvedBuild`, gate green.

- [ ] **Step 1: Branch + worktree**

```bash
git checkout main && git pull --ff-only && git checkout -b sp4a-bump-3-sp1
git -C "/Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine" checkout 0663e8e
```

- [ ] **Step 2: Bump `pubspec.yaml` `ref:` → the full SP1 SHA.**

- [ ] **Step 3: `flutter pub get` then apply the three `combat_adapter.dart` edits**

In `lib/core/engine/combat_adapter.dart`:

1. **Line ~79** — change:
   ```dart
   final build = _ctx.tome.resolve(_me);
   ```
   to:
   ```dart
   // SP4b: derive real ownedRefs (ref: build_engine game_run.dart
   // ownedComponentRefs). SP4a passes [] — the client reads only the
   // hung set and has no tiered affixes yet.
   final build = _ctx.tome.resolve(_me, ownedRefs: const []);
   ```

2. **Lines ~86 and ~97** — change both occurrences of:
   ```dart
   for (final ref in build.components) {
   ```
   to:
   ```dart
   for (final ref in build.active) {
   ```

3. **The `_itemInterpreter.interpret(build: build, …)` call (~line 82)** — no edit needed once (1) makes `build` a `ResolvedBuild`; `interpret` now takes `ResolvedBuild`. Confirm it compiles.

- [ ] **Step 4: Gate**

```bash
flutter analyze
flutter test
```
Expected: `analyze` clean after the three edits; `flutter test` — mostly green. `combat_adapter_test.dart` / `combat_mastery_test.dart` inline seed expectations **may** shift (two-copy item summing, per-actor modifier scoping). For each failure:
- Confirm it is a value/pattern shift, not a crash or wrong winner.
- Run that test file twice — identical both times (determinism property holds).
- Update the inline expected value to the observed one. Note each re-baseline in the PR body.

- [ ] **Step 5: Semantic-continuity grep**

```bash
grep -rn "affix:\|removeBySource(\|'build:\|\"build:" test/ lib/
```
Expected: no client test asserts on the old `affix:*` / `build:<id>` modifier-source strings. If one does, it needs updating to the new `effectprofile:item:<actorValue>:<stat>` source name (engine `CHANGELOG.md` "Changed — Tiered Component Effects (SP1)").

- [ ] **Step 6: Determinism-property check** — the four files, twice each. The property MUST hold. A true divergence (same inputs, different output across two runs) is a STOP-and-diagnose bug, not a re-baseline.

- [ ] **Step 7: Guard against scope creep**

If green requires touching `item_adapter.dart`, `reward_adapter.dart`, `technique_adapter.dart`, `tome_adapter.dart`, `engine_session.dart`, or any `features/` file — **STOP and report**. The audit says the break is confined to `combat_adapter.dart` ×3; anything wider means either a mis-diagnosis or SP4b work leaking in. `ItemInstance.statBonuses` / `addItemStatBonuses` are retained, so `item_adapter.dart` / `reward_adapter.dart` should need no change.

- [ ] **Step 8: Fix `pubspec.lock`** → full SP1 SHA.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/engine/combat_adapter.dart
# + test/core/engine/combat_adapter_test.dart and/or combat_mastery_test.dart
#   ONLY if Step 4 re-baselined a drifted value — list them explicitly
git commit -m "build(engine): bump build_engine to SP1 (tiered component effects)

Ref 0663e8e. TomeService.resolve now requires ownedRefs and returns
ResolvedBuild; BuildActionInterpreter.interpret takes ResolvedBuild.
combat_adapter.dart: resolve(_me, ownedRefs: const []) (// SP4b marker),
build.components -> build.active (x2). ItemInstance.statBonuses /
addItemStatBonuses retained, so item/reward adapters unchanged.
<if re-baselined: 'Re-baseline <file> seed expectations: <what moved>,
determinism property (same seed+inputs -> identical, twice) verified.'>
Also crosses Almanac v1 + the SP1 game-run migration — both client-inert.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E3k4BFeWXfPzkZzXinqTZk"
```

- [ ] **Step 10: PR + merge** — `SP4a bump 3/5 — SP1 (tiered component effects)`. Body: the three `combat_adapter.dart` edits, and every fixture re-baseline with its before/after value and the determinism-property confirmation. CI green → merge → delete branch. Do not start Task 4 until merged.

---

## Task 4: PR 4 — bump to SP2 (per-active auras)

**Engine contract register — Stage 4 (verbatim):**
> **Stage 4 — SP2 · pin `dc213d4`**
> - **Relied on:** nothing new. `const ItemActionInterpreter()` still constructs and still `interpret`s.
> - **NOT relied on:** `AuraScope`, `AuraRule`, `AuraContributor`, `ItemAuraContributor` / `TechniqueAuraContributor`, `SubjectIs`, `AuraBinder` / `AuraBinding`, `BuildActionInterpreter.auraRules({build, context})`, `ItemDefinition.auraRuleIds` / `TechniqueDefinition.auraRuleIds`, the `auras` content field, `ContentRegistry.hasTrigger`, `CombatPlugin.initialize`'s `TurnStarted` / `TurnEnded` / `ActionCompleted` trigger registration.
> - **`auraRules()` interface addition — non-breaking for the client:** it implements/subclasses no `BuildActionInterpreter` or `CompositeBuildActionInterpreter`, has no interface test double, and builds no interpreter list. The concrete `ItemActionInterpreter` gains a method the client never calls.
> - **Client compatibility work:** none — but **lock the init order.** `engine_session.dart` already initialises `CombatPlugin` **before** `ItemPlugin` / `TechniquePlugin`; the `hasTrigger`-gated aura-content load requires Combat-first, permanently, for that `PluginContext`. Add a comment at the `CombatPlugin()..initialize(context)` line stating this is load-bearing.
> - **Inert-content check:** the engine added `auras` keys to 7 content ids (`cloth_armor`, `training_staff`, `training_shoes`, `warlords_iron_sword`, `crushing_gauntlets`, `basic_guard`, `basic_slash`). The client never calls `AuraBinder`, so a hung one of these contributes **no aura** in the client. Verify a client build hanging one produces identical combat numbers pre/post bump — a drift there means an aura path leaked in; **stop**.

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Modify: `lib/core/engine/engine_session.dart` — one comment (below)

**Interfaces:**
- Consumes: Task 3 merged (`main` at SP1); the SP2 full SHA from Task 0.
- Produces: `main` with `build_engine` at SP2 `dc213d4`, init-order comment added, gate green.

- [ ] **Step 1: Branch + worktree**

```bash
git checkout main && git pull --ff-only && git checkout -b sp4a-bump-4-sp2
git -C "/Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine" checkout dc213d4
```

- [ ] **Step 2: Bump `pubspec.yaml` `ref:` → the full SP2 SHA.**

- [ ] **Step 3: Add the load-bearing-order comment**

In `lib/core/engine/engine_session.dart`, immediately above the line `combatPlugin = CombatPlugin()..initialize(context);` (the audit places it ~line 47), add:
```dart
    // Load-bearing order: CombatPlugin MUST initialise before ItemPlugin /
    // TechniquePlugin. SP2 aura content is loaded through a hasTrigger gate
    // that needs Combat's TurnStarted/TurnEnded/ActionCompleted triggers
    // registered first; the plugins' load-once guard never revisits a
    // skipped load, so a Combat-last order permanently drops aura content
    // for this PluginContext. (build_engine CHANGELOG, SP2.)
```

- [ ] **Step 4: Gate**

```bash
flutter pub get && flutter analyze && flutter test
```
Expected: clean/green, count identical to Task 3. `auraRules()` is a method the client never calls; the client binds no auras.

- [ ] **Step 5: Inert-content check**

If any determinism-sensitive test hangs one of the 7 aura-tagged ids (`cloth_armor`, `training_staff`, `training_shoes`, `warlords_iron_sword`, `crushing_gauntlets`, `basic_guard`, `basic_slash`) and its combat numbers **drift**, that means an aura contributed in the client path — which SP4a says cannot happen. **STOP and report.** A clean pass here is the confirmation that SP2 is inert.

- [ ] **Step 6: Determinism-property check** — the four files, twice each.

- [ ] **Step 7: Guard against scope creep** — any change beyond `engine_session.dart`'s one comment + optional fixture re-baselines → STOP and report.

- [ ] **Step 8: Fix `pubspec.lock`** → full SP2 SHA.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/engine/engine_session.dart
git commit -m "build(engine): bump build_engine to SP2 (per-active auras)

Ref dc213d4. Inert for the client: it binds no auras (combat_adapter
builds its own action pool, never calls AuraBinder), and auraRules() is
a method it never calls. Adds a comment locking the CombatPlugin-first
init order that SP2's hasTrigger-gated aura-content load depends on.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E3k4BFeWXfPzkZzXinqTZk"
```

- [ ] **Step 10: PR + merge** — `SP4a bump 4/5 — SP2 (per-active auras)`. CI green → merge → delete branch. Do not start Task 5 until merged.

---

## Task 5: PR 5 — bump to SP3 / engine HEAD (per-fight consumables)

**Engine contract register — Stage 5 (verbatim, ref updated per Global Constraints):**
> **Stage 5 — SP3 · pin `b43b414`** (engine HEAD; = `1dc7e5d` + the SP4a Part A merge, which is engine-internal Almanac only)
> - **Relied on:** nothing new. `RuleContext.modifiers` default keeps `RuleEngine._fire` identical; `AttackAction` / `SelfEffectAction` gain an optional `priority` param (client constructions unaffected).
> - **NOT relied on:** the entire `consumable_plugin.dart` barrel (`ConsumablePlugin`, `ConsumableDefinition`, `ConsumableTarget`, `ConsumableEffectSpec` + 4 variants, `consumableReferenceType`, `consumableChargeResource`, `consumableDefinition*`, `ConsumableIds`), `RemoveAllStatuses`, `GrantModifier`, `ConsumableActionInterpreter`, `ConsumableBinder` / `ConsumableCharges`, `ConsumableAwareActionScorer`, the engine `RewardStage` / `TomeManager.placeConsumable` reward-pool wiring, the C1 `ResourceAbove` guard + fallback-strike injection.
> - **Client compatibility work:** none. `ConsumablePlugin` is **not** registered in `engine_session.dart` and must not be in SP4a. The client's combat pool has no consumable branch; it has its own fallback strike (`combat_adapter._Resolver`), so C1 does not apply to it.
> - **Final-stage gate:** run `scripts/package_itch.sh` (web release build) — it is in client CI.

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`. Nothing else expected.

**Interfaces:**
- Consumes: Task 4 merged (`main` at SP2); the SP3/HEAD full SHA (`b43b414`) from Task 0.
- Produces: `main` with `build_engine` at engine HEAD, gate + web build green. **Client is on engine HEAD — SP4a Part B complete.**

- [ ] **Step 1: Branch + worktree**

```bash
git checkout main && git pull --ff-only && git checkout -b sp4a-bump-5-sp3
git -C "/Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine" checkout b43b414
```

- [ ] **Step 2: Bump `pubspec.yaml` `ref:` → `b43b414` (full 40-char).**

- [ ] **Step 3: Gate**

```bash
flutter pub get && flutter analyze && flutter test
```
Expected: clean/green, count identical to Task 4. `ConsumablePlugin` is not registered; the client's combat pool has no consumable branch; `RuleContext.modifiers` default preserves `RuleEngine._fire`.

- [ ] **Step 4: Web release build**

```bash
chmod +x scripts/*.sh
scripts/package_itch.sh
```
Expected: succeeds (produces `dist/itch/tome-web.zip` per CI). If it fails on something engine-related, triage against Stage 5's lists; if it fails on packaging/Flutter-web infra unrelated to the bump, note it but it is likely pre-existing — check by running the same script on `main` before the bump.

- [ ] **Step 5: Determinism-property check** — the four files, twice each.

- [ ] **Step 6: Guard against scope creep** — any `lib/` or non-fixture `test/` change → STOP and report.

- [ ] **Step 7: Fix `pubspec.lock`** → `b43b414` (full 40-char), `ref` + `resolved-ref`.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "build(engine): bump build_engine to engine HEAD (SP3 + SP4a Part A)

Ref b43b414. Inert for the client: ConsumablePlugin is not registered,
the combat pool has no consumable branch, RuleContext.modifiers default
preserves RuleEngine._fire. Client is now on engine HEAD — SP4a Part B
complete. (b43b414 = the SP3 merge 1dc7e5d plus the engine-internal
SP4a Part A Almanac change, which the client does not consume.)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E3k4BFeWXfPzkZzXinqTZk"
```

- [ ] **Step 9: PR + merge** — `SP4a bump 5/5 — SP3 / engine HEAD`. Body notes the client is now on engine HEAD and lists any web-build caveat. CI green (incl. its own `scripts/package_itch.sh` step) → merge → delete branch.

---

## Task 6: Wrap-up

**Files:** none (verification + cleanup).

- [ ] **Step 1: Confirm the end state**

```bash
git checkout main && git pull --ff-only
grep -n "ref:" pubspec.yaml           # build_engine ref == b43b414
grep -A2 "build_engine:" pubspec.lock # ref / resolved-ref == b43b414
git log --oneline -7                  # the 5 bump merges + harness, in order
```

- [ ] **Step 2: Full local gate one more time on merged `main`**

```bash
flutter pub get && flutter analyze && flutter test && scripts/package_itch.sh
```
All green.

- [ ] **Step 3: Tear down the local harness**

```bash
rm pubspec_overrides.yaml
git -C "/Users/m4maxpro/Projects/Tome:RougelikeGame" worktree remove \
  "/Users/m4maxpro/Projects/Tome:RougelikeGame/.claude/worktrees/sp4a-client-engine"
git -C "/Users/m4maxpro/Projects/Tome:RougelikeGame" worktree prune
```
The `.gitignore` lines from Task 0 stay (harmless, and useful for SP4b).

- [ ] **Step 4: Report**

Client on engine HEAD, five bump PRs merged, gate + web build green. SP4a (both halves) complete. Note for SP4b: the client composition migration will want the engine's `2026-09-04-sp1-techniquevariant-first-game-run` migration as its blueprint (mint/hang variants, adopt `AuraBinder` / `ConsumableBinder`, tiered affixes, `TomeClientAlmanacAdapter`).

---

## Self-Review

**1. Spec coverage** (`2026-09-08-sp4a-client-bump-design.md`):

| Spec item | Task |
|-----------|------|
| §2.1 five sequential bumps, `pubspec.lock` regenerated each | Tasks 1–5, each Step "Fix pubspec.lock" |
| §2.2 scope freeze (no affixes/detail-sheet/binders/plugin/variants/adapter/real-ownedRefs) | Global Constraints + per-task "Guard against scope creep" Steps |
| §2.3 contract discipline (no unlisted engine surface) | Per-task Step 5/7 triage against the inlined register rows |
| §3 the one compile break — `combat_adapter.dart` ×3, exact edits | Task 3 Step 3 |
| §3 `_itemInterpreter.interpret` correct once `build` is `ResolvedBuild` | Task 3 Step 3(3) |
| §3 semantic-continuity grep for `affix:` / `build:` / `removeBySource(` | Task 3 Step 5 |
| §3 `statBonuses` / `addItemStatBonuses` retained → no item/reward adapter change | Task 3 Step 7 |
| §4 PR table: refs cb32b02 / ff8c7db / 0663e8e / dc213d4 / (1dc7e5d→b43b414) | Tasks 1–5 Step 2, with the HEAD-advanced note in Global Constraints |
| §4.1 lock the plugin init order (comment) | Task 4 Step 3 |
| §4.2 do not register `ConsumablePlugin` | Task 5 Step 3 + Global Constraints |
| §5 four determinism cases (drift→observe / nondeterminism→stop / compile→mechanical / regression→stop) | Global Constraints "Determinism-property check" + per-task Steps |
| §5 `tome_visual_capture_test.dart` should not move | covered by "same count as baseline" checks; a move surfaces as a test failure to triage |
| §6 files-expected-to-change list | matches each task's **Files** block |
| §6 not-expected: item/reward/technique/tome/character adapters, features/, widget/bloc tests | per-task scope-creep guards |
| §7 verify per stage: analyze / test / determinism / (PR5) web build | per-task gate Steps + Task 6 |
| §8 after PR 5 the client is on engine HEAD, SP4b may begin | Task 5 Produces + Task 6 Step 4 |

**2. Placeholder scan:** the only intentionally-open items are the compat fixes at Stages 1/2/4/5 — the audit predicts none, and each task's Step 5/7 gives concrete triage (fix per the named CHANGELOG section, or STOP with a named symbol). Stage 3's break has literal before/after code. Fixture re-baselines are "observe the new value the test prints" — inherently not pre-knowable, bounded by the determinism-property rule. This is discovery work; the plan constrains rather than scripts it, deliberately.

**3. Type consistency:** `ENGINE_WT` path identical across Tasks 0–6. Engine refs (`cb32b02` / `ff8c7db` / `0663e8e` / `dc213d4` / `b43b414`) consistent between each task's contract-register row, its Step 1 `git checkout`, and its Step 2 bump. `build.active` (not `build.components`, not `asActiveBuild.components`) used consistently in Task 3. `ownedRefs: const []` matches the spec §3 wording. `pubspec_overrides.yaml` / `.gitignore` handling consistent between Task 0 (create) and Task 6 (remove).
