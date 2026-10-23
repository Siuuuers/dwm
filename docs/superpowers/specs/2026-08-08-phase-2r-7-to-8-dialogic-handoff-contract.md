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

Retired and MUST be rejected by validation before playback or mutation (never aliased): `ending.priscilla.true`,
`ending.lavinia.true`, `ending.sylvia.true`. Legacy migration mappings are already
live: `SaveMigrations.ENDING_ID_MAP` and `ProfileMigration` map the retired ids to
`.observation` / `ending.sylvia.special` (idempotent union).

## 2. Physical DTL label dispositions (`.8` Task 1 owns the edits)

Current `dialogic/timelines/en/ending/*.dtl` still carry `.true` labels. `.8`
Task 1 makes them consistent with §1:

- `priscilla.dtl`: rename label `ending.priscilla.true` → `ending.priscilla.observation` and replace `true` with `observation` in `# contains`.
- `lavinia.dtl`: rename label `ending.lavinia.true` → `ending.lavinia.observation` and replace `true` with `observation` in `# contains`.
- `sylvia.dtl`: retire label `ending.sylvia.true`; add label `ending.sylvia.special`; replace `true` with `special` in `# contains`.
- `alone.dtl`: add the explicit locator `label ending.alone` before its terminal `return`.
- `priscilla_lavinia.dtl`: add the explicit locator `label ending.priscilla_lavinia` before its terminal `return`.
- Existing `sweet`/`dark` primary labels are unchanged; labels remain TODO-only
  placeholders (no prose invented). The three friend-ending files therefore stay
  `placeholder`; Alone and Priscilla-Lavinia remain `draft` because adding a label
  does not add a TODO marker.

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

## 4. Postscript locator capability + AudioManifest ownership (decided)

`.7` registered the postscript ids, the pure `resolve_postscript` gate,
migration, and gallery titles, and explicitly deferred Dialogic/audio work (see
the `.7` postscript spec, "Deferred (C)"). `.8` owns the following bounded
handoff:

- Task 1 registers the two `.observation` records as `role=postscript` and gives
  each one a physical DTL label.
- Task 2 provides manifest-validated, tokenized bridge capability through
  `DialogicBridge.start_postscript_id(postscript_id:String) -> Dictionary`. It
  accepts only an `endings.json` record whose role is `postscript` and reuses the
  bridge's physical completion/failure machinery. It has no EndingPlan
  `playback_context` and MUST NOT call a GameState ending method, add/change a
  playback stage, unlock or record a postscript, or enqueue it in the live ending
  sequence.
- The existing `.7` `DialogicEndingPlaybackPort` remains exactly the
  primary/epilogue adapter. It rejects `postscript` before calling the bridge.
  `.8` MUST NOT change `DatingEndingRules.ENDING_PLAN_KEYS`,
  `DatingEndingRules.PLAYBACK_STAGES`, `RunLifecycle`, `RunSnapshotSchema`, or
  GameState ending sequencing to manufacture a temporary postscript slot.
- Eligibility, live scheduling, persistence, stage advancement, and Gallery
  recording remain dormant until the later ordered-ending-plan migration and the
  real board-mastery/observer signal wiring. That later work consumes this
  locator capability instead of back-porting its schema into `.8`.
- Task 2 replaces ending audio ids exactly:
  `ending_priscilla_true` → `ending_priscilla_observation`,
  `ending_lavinia_true` → `ending_lavinia_observation`, and
  `ending_sylvia_true` → `ending_sylvia_special`. Ending-context resolution is an
  exact map over all 11 canonical ending ids; empty, unknown, and retired `.true`
  semantic ids fail before audio mutation. The generic ending suffix fallback and
  generic `ending_true` ending-tier track are retired. Non-ending dating/challenge
  track ids are outside this handoff and are not silently renamed here.

## 5. Ending receipt-ledger / fatal-recovery ownership (decided, testable)

**The ending gallery receipt-ledger and its exactly-once forward recovery are
owned by `.7` and are already done and tested** — `ProfileManager`
`gallery_transaction_receipts` + `GameState._complete_record_gallery`
(`profile_ahead_profile_batch_failed`, stage-stays-pending, retry-reuses-receipt).
Proven by `tests/unit/test_game_state.gd`
(`test_gallery_record_recovers_forward_after_a_partial_profile_failure`).

`.8`'s Task 3 creates the previously planned but absent top-level RunSnapshot
`command_receipts: Dictionary`. In Task 3 it accepts only the narrative
`effect_transaction` and `variable_transaction` wrapper/receipt variants; later
facade work may extend this same run-level map rather than create another run
ledger. The map is disjoint from `ProfileManager.gallery_transaction_receipts`:
`.8` MUST NOT read, write, copy, or recreate that ending-gallery ledger.

The two applied transaction-ID arrays must equal their sorted receipt-kind
partitions of `command_receipts`, and their union must equal all map keys. A
provisional snapshot missing the map may default to `{}` only when both arrays
are empty; no migration may invent a receipt for a nonempty legacy array.

Task 3 also creates the absent detached GameState candidate/restore seams, live
narrative-variable and transaction-id state, and the private
`_latch_facade_recovery_fatal(original_phase:StringName, command_id:String,
raw_rollback_diagnostics:Array[Dictionary]) -> Dictionary` call-order helper
while reusing the one
injected `ApplicationMutationGate` and unchanged `FatalDiagnosticProjector`. It
creates no second gate, projector, fatal Boolean, or snapshot authority.

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
