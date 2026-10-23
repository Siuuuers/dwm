# True-Observation Postscript Foundation (dwm-p2r.7 Task 6 tail)

Status: approved design, pending implementation plan
Date: 2026-08-03
Scope: dwm-p2r.7 — the doable-now foundation for the true-observation postscript
(story/05 §1-§3). Playback integration and real board-mastery/observer signal
wiring are deferred (see "Deferred").

## Goal

Resolve the orphaned `.true` ending inconsistency and encode the canon
conjunctive postscript gate. Task 6 retired the `.true` endings as primaries
(`VALID_PRIMARY_IDS` excludes them), yet they remain live ids in
`CANONICAL_ENDING_IDS`, `ProfileSchema.ENDING_IDS`, `GalleryScene`, and
`SaveMigrations`. This foundation converts them to true-observation **postscript**
ids, retires `sylvia.true`, and adds a pure conjunctive gate resolver.

## Context and findings

- Canon (story/05 §1): the third slot per pairing is the true (observation) end —
  the Observer postscript, gated **conjunctively** by *board mastery* (§3: every
  attended challenge with that pairing is a perfect clear) **and** *observer
  behaviour* (the pairing's Observer language). Neither half alone qualifies.
  Sylvia is Special-only, no Observer end. `dating_endings.md` line 37:
  postscript ids "register as postscripts, not destinations."
- The `.true` ids are orphaned: retired as primaries but still present as active
  gallery/profile/canonical ids and in `SaveMigrations.ENDING_ID_MAP`.
- The English gallery titles `gallery.ending.{priscilla,lavinia,sylvia}.true.title`
  are in the **immutable** localization fingerprint
  (`evidence/phase_2r/localization/legacy_subset_fingerprint.json`).
  `tests/unit/test_localization_extraction.gd` asserts the frozen 50/25/25 records
  **remain in the catalogs exactly**. So we must NOT remove or change those frozen
  records, and must NOT regenerate the fingerprint.

## Decisions (locked with the user)

- Postscript ids stay in the `ending.` namespace: `ending.priscilla.observation`,
  `ending.lavinia.observation`. Postscript-ness is a **category**, not a
  namespace.
- An old `sylvia.true` gallery unlock migrates to `ending.sylvia.special`
  (idempotent union), not dropped.
- The Priscilla–Lavinia (Persistence) postscript is **deferred**; this pass does
  priscilla + lavinia only.

## (A) Rename / register

- Ids: `ending.priscilla.true` → `ending.priscilla.observation`;
  `ending.lavinia.true` → `ending.lavinia.observation`; `ending.sylvia.true`
  retired (no replacement).
- New `DatingEndingRules.POSTSCRIPT_IDS = ["ending.lavinia.observation",
  "ending.priscilla.observation"]` — included in `CANONICAL_ENDING_IDS` but NOT in
  `VALID_PRIMARY_IDS`, mirroring how `ending.priscilla_lavinia` is epilogue-only.
- Id-list swaps: `DatingEndingRules.CANONICAL_ENDING_IDS`,
  `ProfileSchema.ENDING_IDS`, `GalleryScene.ALL_ENDING_IDS` — replace the two
  `.true` leaves with `.observation`, remove `sylvia.true`.
- Migration:
  - `SaveMigrations.ENDING_ID_MAP` / `migrate_ending_id`: legacy `priscilla.true`
    and `ending.priscilla.true` → `ending.priscilla.observation` (same for
    lavinia); legacy `sylvia.true` / `ending.sylvia.true` →
    `ending.sylvia.special`.
  - `ProfileMigration`: a loaded profile's `gallery_unlocks` array maps each
    retired `.true` id through the same rule and unions the result (so a profile
    already holding `ending.sylvia.special` plus a legacy `ending.sylvia.true`
    ends with a single `ending.sylvia.special`).
- Localization: **keep** the frozen `.true` title records untouched; **add**
  `gallery.ending.priscilla.observation.title` and
  `gallery.ending.lavinia.observation.title` to the catalogs. The immutable
  fingerprint and its test remain green (frozen records still present; new records
  are additive).

## (B) Pure conjunctive gate resolver

`DatingEndingRules.resolve_postscript(input: Dictionary) -> Dictionary` returning
`{ok: true, code: &"ok", value: {unlocked_ids: Array}}` or a failure for a
malformed input.

- Input shape (exact keys `priscilla`, `lavinia`; each a Dictionary with exact
  keys `board_mastery`, `observer_behaviour`, both bool):
  `{"priscilla": {"board_mastery": bool, "observer_behaviour": bool},
    "lavinia": {"board_mastery": bool, "observer_behaviour": bool}}`.
- Logic (canon §1/§3): for each of `priscilla`, `lavinia`, include
  `ending.<friend>.observation` in `unlocked_ids` iff `board_mastery == true` AND
  `observer_behaviour == true`. `unlocked_ids` is sorted and unique. Sylvia is
  never accepted or produced; the Priscilla–Lavinia postscript is not handled.
- Pure and side-effect free; never mutates the input.

## Testing

- Pure resolver unit tests in `tests/unit/test_dating_ending_rules.gd`: both halves
  → unlock; each half alone → no unlock; both pairings independent; malformed input
  rejected; Sylvia/PL never produced.
- Id-consistency: `POSTSCRIPT_IDS ⊂ CANONICAL_ENDING_IDS`, disjoint from
  `VALID_PRIMARY_IDS`; `.true` no longer in `CANONICAL_ENDING_IDS`.
- Migration tests (`tests/unit/test_save_migrations.gd`, profile-migration suite):
  `priscilla.true`/`lavinia.true` → `.observation`; `sylvia.true` →
  `ending.sylvia.special`; gallery-unlocks union is idempotent.
- Localization suite (`test_localization_extraction`) stays green; the new
  `.observation` title keys validate through the bundle.
- Blast-radius: ending, profile, save-migration, and localization clusters green.

## Success criteria

- The `.true` ids are gone from `CANONICAL_ENDING_IDS` / `ProfileSchema` /
  `GalleryScene`; `POSTSCRIPT_IDS` are registered as a canonical, non-primary
  category with gallery titles.
- Legacy `.true` unlocks migrate correctly (incl. `sylvia.true → special`).
- `resolve_postscript` encodes the conjunctive gate, fully unit-tested.
- No regressions; the immutable localization fingerprint is untouched and green.

## Deferred

- **(C) Postscript playback** in the ending sequence — coupled to the Dialogic
  port (`.8`), and the `AudioManifest` `.true` → `.observation` audio-track rename
  lands with it (postscript audio is only read during playback).
- **(D) Real signal wiring** — feeding `resolve_postscript` actual per-pairing
  board-mastery and observer-behaviour signals from the Minesweeper/Observer
  mechanics (a later phase). Until C+D, the foundation is dormant: ids registered,
  gate encoded and tested, but nothing unlocks a postscript in live play yet.
- The Priscilla–Lavinia (Persistence) postscript.
