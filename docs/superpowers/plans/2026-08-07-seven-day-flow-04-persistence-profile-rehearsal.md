# Seven-Day Flow Phase 04: Persistence, Profile Ledgers, and Rehearsal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make challenge choices irreversible within the first week, safely forkable after the first ending milestone, exactly resumable mid-board, profile-aware across old saves, transactionally consistent across run/profile writes, and consequence-free in Rehearsal.

**Architecture:** Bump the existing profile/run/save schemas in lockstep. `BoardAttemptLedger` is a pure profile-owned overlay keyed by run/branch/slot/attempt and owns the stable P–L draw. Saves keep branch-local canonical pointers and active-board state but cannot overwrite the monotonic ledger. `CrossStoreTransactionCoordinator` durably stages both target candidates before applying either store. `CanonicalPresentationRecorder` records reached signatures and pair witnesses through that boundary. `RehearsalSession` runs isolated copies and merges only validated visited-line IDs.

**Tech Stack:** Godot 4.6.3, GDScript, existing `ProfileManager`, `SaveManager`, `JsonFileStorage`, strict JSON schemas/migrations, GUT crash injection/property tests.

## Global Constraints

- [ ] Required skills: `godot-master` with `save-load-systems`, `autoload-architecture`, `scene-management`, `mechanic-secrets`, and `testing-patterns`, plus `security-and-hardening`, `deprecation-and-migration`, `test-driven-development`, `incremental-implementation`, and `superpowers:verification-before-completion`.
- [ ] Plans 01–03 pure schemas and receipts must be green before this plan changes persistence.
- [ ] Never let a save slot replace profile-owned ledger/history wholesale. Merge by validated IDs and monotonic revision only.
- [ ] Never regenerate a board loaded from a mid-board or post-clear snapshot.
- [ ] Before the first ending, an old same-run pre-board save must reuse the first entered canonical attempt and reconcile its effects at the causal boundary.
- [ ] After the milestone, regeneration occurs only when crossing a fresh pre-challenge entry boundary. It forks a branch and appends an attempt; it does not rewrite sibling branches.
- [ ] Rehearsal cannot mutate any canonical or profile consequence except validated visited-line history.
- [ ] Do not trust save strings as DTL syntax, BBCode, paths, labels, object types, or method names.
- [ ] All migrations are non-destructive. Future/unmappable data leaves the original file untouched.

---

## Task Interface Map

| Task | Consumes | Produces |
|---:|---|---|
| 1 | Closed ending/evidence IDs | Profile v2 ledger/evidence/settings schema |
| 2 | Profile v2 plus solo/pair snapshots | Monotonic attempt ledger and detached stable-draw candidates |
| 3 | Board/relationship/contact contracts | EndingPlanSchema, RunSnapshot v3, SaveDocument v3, migrations |
| 4 | Ledger plus v3 snapshots | Branch creation and exact active-board checkpoint/restore |
| 5 | Detached profile/run candidates | Recoverable cross-store commit and final pair/day composition |
| 6 | Manifest signatures and cross-store boundary | Canonical signature/pair witness recording and isolated Rehearsal |

## Task 1: Define profile ledger and evidence schema v2

**Specification:** Sections 6.5, 10.2–10.5, 11.4, 11.6–11.10, 14.4.

**Files:**

- Modify: `scripts/profile/ProfileSchema.gd`
- Modify: `scripts/profile/ProfileMigration.gd`
- Modify: `schemas/profile.schema.json`
- Modify: `autoload/ProfileManager.gd`
- Create: `scripts/domain/run/RunIdAllocator.gd`
- Modify: `tests/unit/test_profile_manager.gd`
- Create: `tests/unit/test_profile_ledger_schema.gd`
- Create: `tests/unit/test_run_id_allocator.gd`

- [ ] Write RED tests for a strict profile schema v2 containing the existing preferences/input/history fields plus:

```gdscript
{
	"milestones": {"first_ending_step_completed": false},
	"observer_evidence": {
		"priscilla_verification": {},
		"lavinia_restraint": {},
	},
	"pair_combinations_witnessed": [],
	"reached_presentation_signatures": {
		"next_completion_sequence": 1,
		"records_by_receipt": {},
		"latest_receipt_by_entry": {},
	},
	"run_ledgers": {},
	"attempt_history": [],
	"run_id_allocator": {"installation_id": String, "next_sequence": 1, "receipts": {}},
	"dark_mode": {"available": false, "enabled": false},
	"exceptional_replay": {"available": false, "replay_full": false},
	# existing gallery, visited, preferences, mappings, migration receipts
}
```

- [ ] Replace old ending allowlists with the exact 13 IDs. Retired `.true` and generic `ending.priscilla_lavinia` values must migrate through an explicit table or reject; they must not silently unlock Observer/P–L variants.
- [ ] Define finite Observer evidence records:

  - Verification Capture: evidence ID, source entry/atom/line, comparison key, run ID, receipt ID;
  - Verification Compare: registered counterpart, different run ID, matching key, receipt ID;
  - Restraint: evidence ID, registered opportunity entry/atom, opened/closed tokens, accessibility-neutral clock policy, no-intervention receipt.

- [ ] Rehearsal, visited-line history, generic inactivity, duplicated same-run Capture, and a false cursor cannot satisfy evidence validation.
- [ ] Define pair witnessed values exactly: `ambiguous_sweet`, `ambiguous_dark`, `love_sweet`, `love_dark`.
- [ ] Each `records_by_receipt` value has exactly `completion_receipt_id`, `entry_id`, nullable `ending_id`, `manifest_fingerprint`, `signature_hash`, `frozen_signature`, and `completion_sequence`. Append with the current sequence then increment; identical receipt+hash is a no-op, receipt conflict fails, and records never overwrite one another. `latest_receipt_by_entry` is a derived validated index. Gallery selects the greatest completion sequence matching its ending identity/form, so Alone's latest actually completed form is deterministic. No rendered wording or raw BBCode is stored.
- [ ] `RunIdAllocator` creates `installation_id` once from 128 cryptographic random bits encoded as lowercase hex, then allocates the concatenation `run.` + installation ID + `.` + next decimal sequence inside a detached profile candidate. Sequence increases monotonically; identical transaction reuse returns the same receipt/ID, conflicting reuse rejects, overflow/collision fails closed, and no wall clock, engine tick, or global `randi()` is accepted.
- [ ] Migration v1 -> v2 preserves gallery/visited/preferences and initializes new fields empty/false. Record a migration receipt; rerunning it is idempotent.
- [ ] Run GREEN and commit:

```text
feat(profile): add milestones evidence and run ledgers
```

## Task 2: Implement the monotonic board-attempt ledger

**Specification:** Sections 10.1–10.4.

**Files:**

- Create: `scripts/domain/run/BoardAttemptLedger.gd`
- Create: `scripts/application/pair/ProfilePairDeckPort.gd`
- Create: `tests/unit/test_board_attempt_ledger.gd`
- Modify: `autoload/ProfileManager.gd`
- Create: `tests/integration/test_profile_board_ledger.gd`
- Create: `tests/unit/test_profile_pair_deck_port.gd`

- [ ] Write RED tests for immutable run/slot entry, active snapshot updates, terminal receipts, P–L draw receipt, attempt append, branch head isolation, duplicate identical receipts, and conflicting revision/receipt rejection. Cover all twelve solo slot IDs and both pair slot IDs `pair.priscilla_lavinia.day_2|day_6`.
- [ ] Define one run ledger:

```gdscript
{
	"run_id": String,
	"revision": int,
	"first_entry_by_slot": Dictionary,
	"attempts_by_id": Dictionary,
	"pair_draw_receipt": Variant,
	"receipts": Dictionary,
}
```

Each attempt has this exact key set (inapplicable terminal values are `null`, never omitted or replaced with sentinels):

```gdscript
{
	"attempt_id": String,
	"slot_id": String,
	"slot_kind": "solo" or "pair",
	"branch_id": String,
	"generation": int,
	"board_nonce": String,
	"board_snapshot": Dictionary,
	"board_phase": String,
	"board_result": Variant,
	"perfect_reasons": Array[String],
	"relationship_outcome": Variant,
	"pair_result": Variant,
	"terminal_receipt_id": Variant,
	"effect_receipt_id": Variant,
	"promotion_receipt_id": Variant,
	"append_revision": int,
}
```
- [ ] Implement pure operations:

```gdscript
class_name BoardAttemptLedger
extends RefCounted

static func make_run(run_id: String) -> Dictionary
static func prepare_enter_slot(ledger: Dictionary, request: Dictionary) -> Dictionary
static func prepare_update_board(ledger: Dictionary, request: Dictionary) -> Dictionary
static func prepare_commit_terminal(ledger: Dictionary, request: Dictionary) -> Dictionary
static func prepare_pair_draw(ledger: Dictionary, draw_receipt: Dictionary) -> Dictionary
static func validate(ledger: Dictionary) -> Dictionary
```

- [ ] Before milestone: an existing `run_id + slot` returns the original attempt/snapshot/result. A later branch reaches effects only at its own causal boundary; ledger existence alone cannot inject future stats into an earlier scene.
- [ ] After milestone: a fresh pre-challenge entry appends a new attempt generation and branch-local head; active/mid-board restore requests return the named attempt unchanged.
- [ ] ProfileManager publishes candidates atomically and emits no partial signals. Board history survives old save loads and full run reset; only explicit full profile reset removes it.
- [ ] `ProfilePairDeckPort.prepare_draw()` reads the validated witnessed set and run ledger, delegates the pure draw to Plan 03, and returns detached profile/run candidates. It performs no write in this task; Task 5 commits both candidates and the day-resolution receipt together.
- [ ] Run GREEN and commit:

```text
feat(profile): persist monotonic board attempt history
```

## Task 3: Bump run snapshot and save document schemas together

**Specification:** Sections 10, 11.9, 14.3–14.4, 16.3.

**Files:**

- Modify: `scripts/domain/run/RunSnapshotSchema.gd`
- Create: `scripts/domain/run/GameplaySnapshotSchema.gd`
- Create: `scripts/domain/ending/EndingPlanSchema.gd`
- Modify: `scripts/domain/run/RunLifecycle.gd`
- Modify: `scripts/infrastructure/save/SaveDocumentSchema.gd`
- Modify: `scripts/infrastructure/save/SaveMigrations.gd`
- Modify: `autoload/SaveManager.gd`
- Modify: `tests/unit/test_run_snapshot_schema.gd`
- Create: `tests/unit/test_gameplay_snapshot_schema.gd`
- Create: `tests/unit/test_ending_plan_schema.gd`
- Modify: `tests/unit/test_run_lifecycle.gd`
- Modify: `tests/unit/test_save_document_schema.gd`
- Modify: `tests/unit/test_save_migrations.gd`
- Add fixtures: `tests/fixtures/saves/seven_day_v2_primary_epilogue.json`
- Add fixtures: `tests/fixtures/saves/seven_day_v3_active_board.json`

- [ ] First define and RED-test the exact `EndingPlanSchema` consumed by save migration and Plan 05's resolver:

```gdscript
{
	"schema_version": 2,
	"plan_id": String,
	"steps": Array[Dictionary],
	"next_step_index": int,
	"gallery_state": {
		"phase": "pending" or "publishing" or "durable",
		"published_receipt_ids": Dictionary,
		"active_transaction_id": Variant,
	},
	"state": "active" or "completed",
}
```

Each step has only `step_id`, `ending_id`, `entry_id`, `role`, `frozen_context`, `playback_mode`, `prerequisite_receipt_ids`, `transaction_token`, `state`, `completion_receipt_id`, and `gallery_receipt_id`; state is `pending | playing | completed`, and the two receipt fields are `null` until their corresponding durable write. `published_receipt_ids` maps only completed semantic ending IDs to their gallery receipt IDs. The cursor invariant is exact: every step before `next_step_index` is completed with both receipts; at most the indexed step is playing; every later step is pending; plan `state = completed` iff the cursor equals step count and Gallery phase is durable. `RunLifecycle` gains generic current-step, mark-playing, complete-matching-step, gallery-durable, and finish operations. Plan 05 may resolve values into this schema but may not redefine it.
- [ ] Write RED tests for RunSnapshot schema v3 and SaveDocument version 3. Preserve the existing complete snapshot envelope while adding branch/flow fields. The exact top-level v3 keys are `schema_version`, `content_version`, `manifest_fingerprint`, `checkpoint_id`, `checkpoint_sequence`, `run_id`, `branch_id`, `lifecycle`, `route_id`, `active_app_id`, `audio_context`, `narrative_checkpoint`, `gameplay`, `calendar_state`, `contact_state`, `committed_schedule`, `relationship_state`, `challenge_heads`, `active_challenge`, `pending_echoes`, `day_resolution_plan`, `ending_plan`, `applied_effect_transaction_ids`, `applied_variable_transaction_ids`, and `applied_cross_store_receipts`; reject every extra key.
- [ ] `GameplaySnapshotSchema` replaces the loose legacy bag with five exact nested records: `economy` (money, coins, inventory, Shop purchase counts/receipts); `condition` (health, pressure, carried sequela, daily effects, streak/day fields, penalties, pending Hospital); `minesweeper_app` (difficulty, rounds/floor/finished, money earned, task rewards, RNG state, unlock/reward receipts); `story` (friends, chat/story/opening/tutorial flags); and `route_runtime` (pending date queue/index/friend/group, route context, post-ending queue). It migrates every current `GAMEPLAY_FIELDS` value into one declared field or an explicit retired-field disposition; no health/economy/RNG/reward state may disappear.
- [ ] Migrate the three v2 owner sections explicitly: `contacts` passes through `ContactInvitationState.migrate_v2_to_current()` and becomes validated `contact_state`; `schedule` passes through Plan 02's exact per-entry mapping and becomes `committed_schedule`; valid empty `{}` `dating` becomes no additional state because the actual pending queue/route fields migrate from the v2 gameplay bag into `gameplay.route_runtime`. A nonempty v2 `dating` object has no committed owner in the released v2 capture contract, so it fails with `unmappable_v2_dating_state` and leaves the source slot untouched. Tests cover empty, valid contacts/schedule, every mapping field, and this rejection.
- [ ] Replace positional/partial construction with the exact API `RunSnapshotSchema.build_v3(input: Dictionary) -> Dictionary` and `RunSnapshotSchema.validate_v3(snapshot: Dictionary) -> Dictionary`. `build_v3` requires precisely the twenty-four top-level input fields named above except `schema_version`, derives `schema_version = 3`, deep-copies primitives, and rejects missing/extra input. SaveDocument v3 retains exactly the current six document keys—`current_snapshot`, `kind`, `recovery_journal`, `save_reason`, `schema_version`, and `slot_id`—with `schema_version = 3`; `current_snapshot` still has exactly `checkpoint_kind` and the validated v3 `snapshot`. No checksum field is invented. Existing atomic storage, discriminators, checkpoint-kind validation, and recovery-journal validation remain authoritative.
- [ ] Save active-board state with every section listed in specification 10.1, including hidden mine classes and post-clear special-mine phase. Validate exact keys and primitive types.
- [ ] Replace the existing `minesweeper_board` save prohibition with an active-board checkpoint contract: active and post-clear boards are valid save payloads once `BoardAttemptCoordinator` supplies a validated snapshot/reference. The lock may prevent a concurrent write only; it cannot make mid-board saves impossible.
- [ ] Migrate old fixed `{primary_id, epilogue_id, playback_stage}` plans into ordered step arrays without inventing Observer/Special/P–L tone. Preserve only identities derivable from old state; ambiguous retired IDs reject or map through the approved migration table.
- [ ] Map old stages deterministically:

  - `PRIMARY_PENDING -> next_step_index 0`;
  - `PRIMARY_PLAYED -> index 1` when an old epilogue exists, otherwise gallery-pending state;
  - `EPILOGUE_PLAYED -> all old steps complete, gallery-pending`;
  - `GALLERY_RECORDED -> all steps complete, gallery durable`.

- [ ] Reject physical DTL path, label, line index, Object/Resource/Callable, unknown semantic ID, wrong manifest/content version, and invalid branch/attempt pointer.
- [ ] Preserve the original slot/file on future or unmappable data. Recovery may choose the latest fully compatible checkpoint bundle; it cannot substitute route defaults.
- [ ] Run GREEN and commit:

```text
feat(save): persist branches attempts and ordered endings
```

## Task 4: Implement branch creation and old-save ledger reconciliation

**Specification:** Sections 10.2–10.4, 14.3.

**Files:**

- Create: `scripts/application/run/BoardAttemptCoordinator.gd`
- Create: `tests/support/FakeBoardAttemptLedgerPort.gd`
- Create: `tests/unit/test_board_attempt_coordinator.gd`
- Modify: `scripts/application/restore/RunRestoreParticipant.gd`
- Modify: `autoload/SaveManager.gd`
- Modify: `autoload/GameState.gd`
- Create: `tests/integration/test_board_restore_equivalence.gd`

- [ ] Write model-based RED cases around snapshots taken at pre-entry, active board, post-clear, terminal-before-effects, effects-before-promotion, and post-promotion.
- [ ] `BoardAttemptCoordinator.enter_challenge(request)` obtains the profile ledger candidate before board generation. Before milestone it returns/reuses the first attempt. After milestone it forks a new branch only at fresh pre-entry and appends one attempt.
- [ ] Every accepted reveal/flag/chord, explosion, clear, post-clear special activation, and normal terminal finish calls one injected checkpoint method after the detached board/ledger candidates validate. The checkpoint contains the active attempt ID and exact snapshot; a failed write leaves the prior durable snapshot/head authoritative and reports retryable failure.
- [ ] Generate branch IDs and attempt IDs from persisted nonces/idempotency keys, not runtime instance IDs or wall-clock-only guesses.
- [ ] Restore merges the monotonic profile ledger over slot data by run/branch/slot/receipt. It must:

  - resume exact mid-board state;
  - resume post-clear terminal choice without payout;
  - reapply terminal/promotion receipts once when the restored branch reaches their causal boundary;
  - keep sibling branch canonical pointers independent;
  - never union mastery across branches.

- [ ] Add a generated reference model and compare hundreds of seeded save-prefix/restore/suffix sequences to uninterrupted execution.
- [ ] Run GREEN and commit:

```text
feat(save): reconcile irreversible boards across old saves
```

## Task 5: Add the recoverable cross-store transaction journal

**Specification:** Section 14.4.

**Files:**

- Create: `scripts/infrastructure/save/CrossStoreTransactionJournal.gd`
- Create: `scripts/application/transaction/CrossStoreTransactionCoordinator.gd`
- Modify: `autoload/SaveManager.gd`
- Modify: `autoload/ProfileManager.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `scripts/application/run/GameStateDayResolutionPort.gd`
- Modify: `scripts/application/run/DayResolutionCoordinator.gd`
- Modify: `scripts/application/pair/ProfilePairDeckPort.gd`
- Create: `scripts/ui/RecoveryOverlay.gd`
- Create: `scenes/ui/RecoveryOverlay.tscn`
- Modify: `scripts/application/transaction/FatalDiagnosticProjector.gd`
- Create: `tests/unit/test_cross_store_transaction_journal.gd`
- Create: `tests/integration/test_cross_store_recovery.gd`
- Modify: `tests/integration/test_new_run_transaction.gd`
- Create: `tests/integration/test_pair_draw_day_resolution.gd`
- Create: `tests/scene/test_recovery_overlay.gd`
- Create: `tests/integration/test_new_run_id_transaction.gd`

- [ ] Write RED crash-injection tests at: before intent; after intent; after profile write; after run write; after validation; after completion mark; and during duplicate recovery.
- [ ] Use a dedicated validated journal at `user://transactions/cross_store.json`, stored through injected `JsonFileStorage`. Before marking the intent durable, atomically write exact validated canonical profile/run candidates to transaction-scoped staged blobs. The journal record contains transaction ID, kind, exact active profile/slot target locators, precondition hashes/revisions, staged-blob locators and hashes, exact profile/run receipt IDs, applied-side flags, and status. Reject extra keys, traversal, target changes, and hash/precondition mismatch.
- [ ] Implement:

```gdscript
class_name CrossStoreTransactionCoordinator
extends RefCounted

func prepare(kind: StringName, profile_candidate: Dictionary, run_candidate: Dictionary, metadata: Dictionary) -> Dictionary
func commit(prepared: Dictionary) -> Dictionary
func reconcile_pending() -> Dictionary
```

- [ ] Commit order is durable intent -> profile atomic replacement -> run-slot atomic replacement -> validate both -> complete intent. Existing identical receipts are no-ops; hash/payload conflicts fail closed.
- [ ] `reconcile_pending()` reloads and validates the staged candidates, target locators, and preconditions, then deterministically applies only the missing side. Completion removes staged blobs only after both stores validate; it never tries to reconstruct a candidate from hashes alone.
- [ ] Use this coordinator for the first counted P–L draw plus pair/day receipt, first-ending milestone + Gallery + ending cursor, pair combination witness when a run-side prerequisite also advances, and any other Plan 05 cross-store command. Do not call Profile then hope GameState advances.
- [ ] Use it for New Game as well: allocate/increment the profile-owned run ID and create the initial run slot in one recoverable transaction before scene routing. A crash may leave neither side or reconcile both; it can never create two IDs for one transaction or reuse an ID for another run.
- [ ] Finish the Plan 02 day seam: consume its typed pair request through Plan 03's encounter/deck rules, obtain/reuse the profile-backed draw, and commit pair mode/count/deferred entry/draw references in the single day-resolution receipt. Hospital and solo-date ordering remains unchanged.
- [ ] Bootstrap reconciles pending intents before allowing load/New Game/ending continuation. Failure latches the existing mutation gate and sends a bounded user-safe projection to `RecoveryOverlay`; Retry reruns reconciliation, Return to Title preserves the slot/journal, and raw IDs/details go only to the diagnostic sink. Scene tests cover keyboard/controller focus and both actions.
- [ ] Run GREEN and commit:

```text
feat(save): reconcile profile and run commits after crashes
```

## Task 6: Implement exact reached signatures and Rehearsal isolation

**Specification:** Sections 10.3, 10.5, 11.10, 12.3, 12.8.

**Files:**

- Create: `scripts/domain/rehearsal/RehearsalRules.gd`
- Create: `scripts/application/rehearsal/RehearsalSession.gd`
- Create: `scripts/application/presentation/CanonicalPresentationRecorder.gd`
- Create: `tests/unit/test_rehearsal_rules.gd`
- Create: `tests/integration/test_rehearsal_isolation.gd`
- Create: `tests/integration/test_canonical_presentation_recorder.gd`
- Modify: `autoload/DialogicBridge.gd`
- Modify: `autoload/ProfileManager.gd`

- [ ] Write RED tests for exact signature access, full-date sandbox outcomes, isolated RNG/nonce/receipts, visited-line-only merge, and denial of every Observer/pair-witness/gallery/ending/echo-canonical command.
- [ ] Write RED recorder tests for canonical completion/signals. `CanonicalPresentationRecorder` exposes idempotent `prepare_record_signature(entry_id, frozen_context, manifest_fingerprint, completion_receipt_id)` and `prepare_pair_witness(entry_id, combination_id, presentation_atom_id, transaction_id)` commands; both derive exact values from the validated active bridge token and manifest capability rather than caller text. The signature command appends one sequence record and updates the derived latest index atomically.
- [ ] On every successful canonical entry completion, record its complete manifest-defined frozen-context signature through ProfileManager. On `pair.combination.witness`, commit exactly one profile combination plus the matching run presentation receipt through the cross-store coordinator. Only the four registered full-observation atoms owned by the D2/D6 Group or twofriends post entries are capable; Exploded, truncated, offscreen, Gallery, and Rehearsal are denied.
- [ ] `RehearsalRules` asks Plan 01's manifest for the complete signature schema for an entry and validates equality with a canonically reached signature. No short hand-picked signature list is legal.
- [ ] Direct replay permits only exact reached signatures. Full-date Rehearsal begins from a reached pre-challenge signature, uses the production board rules in a sandbox, and may show hypothetical post-result lines without adding those result signatures to canonical history.
- [ ] `RehearsalSession.begin()` deep-copies run state, profile state, Dialogic variable state, RNG state, nonce generators, receipt ledgers, and command capabilities. It creates a separate board RNG namespace.
- [ ] `end()` computes a deep diff. The only allowed canonical change is union of validated visited-line IDs. Any other difference fails, restores backups, and latches fatal if restoration cannot be proven.
- [ ] Rehearsal attempts never enter `attempt_history`; residue derives only from discarded canonical branch attempts through a finite manifest-owned ID, default `none`.
- [ ] Run GREEN and commit:

```text
feat(rehearsal): isolate replay from canonical consequences
```

## Phase 04 Verification Gate

- [ ] Profile v2, run snapshot v3, and save document v3 migrate and validate together.
- [ ] Old same-run saves cannot erase entered boards, results, effects, promotions, or P–L draws.
- [ ] Post-milestone fresh pre-entry creates a branch-local attempt; mid-board never regenerates.
- [ ] Current-run mastery reads only active branch heads.
- [ ] Both pair slot IDs persist; the first counted window commits one profile-backed stable draw and the matching day receipt atomically.
- [ ] Crash at every profile/run write boundary reconciles to one unambiguous state.
- [ ] Canonical entry signatures and full-observation pair witnesses record once; Rehearsal/truncated/offscreen paths cannot record them.
- [ ] Rehearsal restores deep-equivalent run/profile/RNG state except visited lines.
- [ ] Future/corrupt/unmappable data is rejected without overwriting the original slot/profile.
