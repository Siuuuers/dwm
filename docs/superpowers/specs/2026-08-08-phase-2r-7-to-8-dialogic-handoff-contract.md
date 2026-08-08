# dwm-p2r.7 → .8 Dialogic Handoff Contract (dwm-p2r.7.1)

Status: frozen interface contract. Replaces the obsolete "all of dwm-p2r.7 closed"
gate in plan-05 and the Phase-2R master. `.8` depends on THIS contract, never on
the full closure of `.7`.
Date: 2026-08-08

## Why this contract exists

Plan-05 (`.8`, Dialogic) was written to start only after `.3`–`.7` close. But the
corrected Beads graph orders **`.8` → `dwm-7e6` → remaining `.7` tails**: `.7` now
depends on `dwm-7e6`, which depends on `.8`. So `.7` cannot close before `.8`
starts. This contract freezes exactly what `.8` consumes from `.7`'s completed
domain work, so `.8` can proceed honestly while `.7` stays open for tails ordered
after `.8`/`dwm-7e6`. `.7` is NOT declared complete; only this narrow interface is.

## Provenance (hash/commit bound)

The `.7` domain work this contract freezes is committed on branch
`docs/recover-design-brain`:

- Endings resumability / exactly-once recovery / semantic restore validation /
  8-primary coverage: `dbb6247`, `175eeda`, `56b6fb4`, `5ec8a62`.
- Schedule validation consolidation: `6c1bd70`, `335e544`, `c93bc56`.
- True-observation postscript foundation (ids, resolver, migration, gallery
  titles): `43ca453`, `aa80f74`, `65217cd`, `dd8fb84`, `faec305`.

`.3`–`.6` are closed. `dwm-7e6` and the `.7` tails remain open by design.

## 1. Canonical ending-ID locator table (11 = 8 primary + 2 postscript + 1 epilogue)

Authority: `DatingEndingRules.CANONICAL_ENDING_IDS`. `endings.json` (built in `.8`
Task 1) is the sole ending-ID → physical-locator map and MUST equal this set.

| Ending ID | Role | In VALID_PRIMARY_IDS | In POSTSCRIPT_IDS |
|---|---|:--:|:--:|
| `ending.alone` | primary | yes | no |
| `ending.priscilla.sweet` | primary | yes | no |
| `ending.priscilla.dark` | primary | yes | no |
| `ending.lavinia.sweet` | primary | yes | no |
| `ending.lavinia.dark` | primary | yes | no |
| `ending.sylvia.sweet` | primary | yes | no |
| `ending.sylvia.dark` | primary | yes | no |
| `ending.sylvia.special` | primary | yes | no |
| `ending.priscilla.observation` | postscript | no | yes |
| `ending.lavinia.observation` | postscript | no | yes |
| `ending.priscilla_lavinia` | epilogue | no | no |

Retired and MUST reject before mutation (never aliased): `ending.priscilla.true`,
`ending.lavinia.true`, `ending.sylvia.true`. Legacy migration mappings are already
live: `SaveMigrations.ENDING_ID_MAP` and `ProfileMigration` map the retired ids to
`.observation` / `ending.sylvia.special` (idempotent union).

## 2. Physical DTL label dispositions (`.8` Task 1 owns the edits)

Current `dialogic/timelines/en/ending/*.dtl` still carry `.true` labels. `.8`
Task 1 makes them consistent with §1:

- `priscilla.dtl`: rename label `ending.priscilla.true` → `ending.priscilla.observation`.
- `lavinia.dtl`: rename label `ending.lavinia.true` → `ending.lavinia.observation`.
- `sylvia.dtl`: retire label `ending.sylvia.true`; add label `ending.sylvia.special`.
- `alone.dtl`, `priscilla_lavinia.dtl`: unchanged (primary / epilogue timelines).
- Existing `sweet`/`dark` primary labels are unchanged; labels remain TODO-only
  placeholders (no prose invented).

Semantic IDs in §1 are the save/Gallery/history identities; DTL labels are
locators only.

## 3. Playback stage + context contract (verified against `.7` code)

- Stage sequence (frozen): `PRIMARY_PENDING`, `PRIMARY_PLAYED`, `EPILOGUE_PLAYED`,
  `GALLERY_RECORDED`. Authority: `RunSnapshotSchema.PLAYBACK_SEQUENCE` ==
  `DatingEndingRules.PLAYBACK_STAGES`.
- `GameState.request_next_ending_command()` returns a `play_ending` command whose
  `playback_context` has EXACTLY four keys: `playback_id`, `transaction_id`,
  `expected_stage`, `role`. `.8`'s `EndingScene`/`DialogicBridge` pass this
  dictionary through unchanged and compare every field on completion.
- `GameState.complete_ending_playback_stage(transaction_id, expected_stage,
  receipt)` advances the stage only from a matching completion; a stale stage is
  rejected; duplicates return the stored receipt. `.8` never advances state from a
  start.

## 4. Postscript + AudioManifest ownership (decided)

**`.8` owns postscript playback and postscript audio.** `.7` registered the
postscript ids, the pure `resolve_postscript` gate, migration, and gallery titles,
and explicitly deferred playback + audio (see the `.7` postscript spec, "Deferred
(C)"). Therefore:

- The `.observation` DTL labels (§2) and their playback land in `.8`.
- The `AudioManifest` `.true` → `.observation` audio-track rename lands in `.8`,
  NOT `.7`. Until then `AudioManifest` keeps its legacy `ending_*_true` tracks; no
  code reads a postscript track before `.8` wires playback.
- Real board-mastery / observer signal wiring that drives `resolve_postscript`
  remains a later phase (out of `.8`).

## 5. Ending receipt-ledger / fatal-recovery ownership (decided, testable)

**The ending gallery receipt-ledger and its exactly-once forward recovery are
owned by `.7` and are already done and tested** — `ProfileManager`
`gallery_transaction_receipts` + `GameState._complete_record_gallery`
(`profile_ahead_profile_batch_failed`, stage-stays-pending, retry-reuses-receipt).
Proven by `tests/unit/test_game_state.gd`
(`test_gallery_record_recovers_forward_after_a_partial_profile_failure`).

`.8`'s Task 3 owns a **separate** ledger: the narrative **effect/variable**
transaction ledger (allowlisted descriptors, all-or-nothing atomic idempotent
commit through `GameState`). `.8` MUST NOT create a second ending-gallery ledger;
it reuses `ProfileManager`'s. The effect-transaction ledger and its fatal-recovery
seam are `.8` Task 3's to build and test.

## 6. Gate replacement (what the amendments do)

- Phase-2R master dependency table: `.8`'s dependency `…, .7` becomes `…, .7.1`.
- plan-05 Global Constraints + Step 1.1: "starts only after `.3`–`.7` close" and
  "every blocker must be closed" become "starts after `.3`–`.6` close AND this
  `dwm-p2r.7.1` contract is committed; `.7` stays open for tails ordered after
  `.8`/`dwm-7e6`." `.8` Task-1's blocker check verifies `.3`–`.6` closed and this
  contract present, not `.7` closed.

## 7. Verification (focused suites green at freeze time)

`test_dating_ending_rules`, `test_dating_ending_rules_migration`, `test_game_state`,
`test_game_state_facade_contract`, `test_run_snapshot_schema`,
`test_save_migrations`, `test_profile_manager`, and `test_localization_extraction`
all pass at this commit (run via `Invoke-IsolatedGodot.ps1`). The 11-id set, stage
names, and four-key context above are asserted by those suites.
