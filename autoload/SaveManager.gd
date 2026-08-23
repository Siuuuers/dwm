extends Node

## SaveManager — isolated, atomic save-document and checkpoint persistence
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).
## Owns slot/quick/autosave I/O through one injected StorageAdapter and the
## in-memory CheckpointJournal. Never interprets gameplay rules.

signal save_completed(result: Dictionary)
signal load_completed(result: Dictionary)
signal save_failed(result: Dictionary)
signal load_failed(result: Dictionary)
signal slot_metadata_changed()
signal run_restored(checkpoint_id: String, route_id: String)
signal save_capability_changed(capability: Dictionary)

const MIN_SLOT := 1
const MAX_SLOT := 7

const CHECKPOINT_JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const SAVE_MIGRATIONS := preload("res://scripts/infrastructure/save/SaveMigrations.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")
## Plan 02 Task 6 (dwm-p2r.32), Phase C2: the external New-Run/restore continuation journal (Task 1,
## dwm-p2r.16) -- distinct from `_journal` (CheckpointJournal) below, which is SaveManager's OWN
## in-memory per-run bundle history. `_continuation_journal` durably records the intent/allocation/
## participant-apply state machine that survives a process crash; `DesktopIdentityAllocationRestore
## Participant` cannot drive its `advance()` calls itself (its frozen `prepare()` input carries no
## `request_fingerprint` -- only whoever calls `prepare_intent()`/`commit_intent()` ever sees one), so
## SaveManager is the one place all journal advancement happens, for both new_run and restore.
const CONTINUATION_JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")

const _GATE_CONTRACT_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]
const _LOCK_OWNERS: Array[StringName] = [&"minesweeper_board", &"scene_transition", &"restore"]
const _CHECKPOINT_INPUT_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint",
	"route_id", "snapshot_input",
]
## IMPORTANT 5 (brief line 209: "input containing any issuer/allocation/remap field rejects before
## durable allocation"). The exact allow-list `commit_prepared_restore()` accepts: the 9 keys
## `_prepare_bundle_with_all_participants()` puts into a genuine `prepare_restore_slot|quick|
## autosave()` result, which is a superset of the 3-key hand-built shape the pure fake-participant
## orchestration tests use (`participant_plans`, `checkpoint_id`, `route_id`). A stray issuer/
## allocation/remap-shaped key (e.g. `identity_allocation_bundle`, `transaction_issuer_receipt`,
## `transaction_remap`) is never legitimate top-level input here -- those are produced INSIDE
## `_begin_restore_continuation()`, never accepted from a caller.
const _PREPARED_RESTORE_ALLOWED_KEYS: Array[String] = [
	"bundle", "journal_seed", "participant_plans", "route_id", "checkpoint_id",
	"source_locator", "existing_run_id", "source_desktop_timeline_generation",
	"remap_source_transaction_ids",
]

var _storage: RefCounted = null
var _journal: RefCounted = CHECKPOINT_JOURNAL.new()
var _continuation_journal: RefCounted = CONTINUATION_JOURNAL.new()
var _mutation_gate: Object = null
var _identity_issuer: Object = null
var _identity_allocation_participant: Object = null
var _lock_owner: StringName = &""
var _pending_deferred_save := false
var _restore_participants: Dictionary = {}

## The exact 8-item `DesktopContinuationOperationJournal.PARTICIPANT_ORDER` (Plan 02 Task 6,
## dwm-p2r.32, Phase C2): this array IS already the correct apply order, so a single constant now
## serves both the exact-key-set validation `configure_restore_participants()` performs and the
## apply/finalize order below (rollback runs the exact reverse). `identity_allocation` is NOT one of
## these 8 -- it is applied once, before this loop even starts, only for a restore (see
## `_begin_restore_continuation()`), through its own separately-configured seam.
const _PARTICIPANT_KEYS: Array[String] = [
	"run", "desktop_consequence", "desktop_board", "profile", "localization", "audio", "route", "narrative",
]
const _PARTICIPANT_APPLY_ORDER: Array[String] = [
	"run", "desktop_consequence", "desktop_board", "profile", "localization", "audio", "route", "narrative",
]

func initialize(storage: StorageAdapter = null) -> Dictionary:
	if storage == null:
		return _fail(&"invalid_storage", "SaveManager requires an injected StorageAdapter")
	_storage = storage
	var journal_ready: Dictionary = _continuation_journal.configure(storage, self)
	if not journal_ready.get("ok", false):
		return _fail(StringName(str(journal_ready.get("code", "continuation_journal_configure_failed"))),
			str(journal_ready.get("message", "")))
	return {"ok": true, "code": &"ok", "value": {"root": storage.describe_root()}}

## Plan 02 Task 6 (dwm-p2r.32): the desktop identity issuer `start_new_run()` allocates a real
## branch/generation/causal-day identity through, rather than inventing or accepting one from the
## caller. Mirrors GameState's own `configure_identity_issuer` DI pattern; SaveManager needs its own
## reference because it -- not GameState -- owns the New-Run transaction boundary.
func configure_identity_issuer(identity_issuer: Object) -> Dictionary:
	if identity_issuer == null:
		return _fail(&"invalid_identity_issuer", "identity issuer is required")
	for method_name: String in ["issue", "prepare_continuation_allocation", "commit_continuation_allocation"]:
		if not identity_issuer.has_method(method_name):
			return _fail(&"invalid_identity_issuer", "missing " + method_name)
	if _identity_issuer != null:
		if _identity_issuer == identity_issuer:
			return {"ok": true, "code": &"ok",
				"value": {"issuer_instance_id": _identity_issuer.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return _fail(&"identity_issuer_already_configured", "")
	_identity_issuer = identity_issuer
	return {"ok": true, "code": &"ok",
		"value": {"issuer_instance_id": _identity_issuer.get_instance_id(), "already_configured": false},
		"receipt": {}}

## Plan 02 Task 6 (dwm-p2r.32), Phase C2. Separate from `configure_restore_participants()` on
## purpose: `identity_allocation` is not one of the 8 ordinary participants (it applies once, before
## their loop, only for a restore -- new_run never touches it), so it is not folded into that
## exact-8-key validation. Duck-typed to the same prepare/capture/apply_silent/rollback_silent/
## finalize shape as every other participant.
func configure_identity_allocation_participant(participant: Object) -> Dictionary:
	if participant == null:
		return _fail(&"invalid_identity_allocation_participant", "identity allocation participant is required")
	for method: String in ["prepare", "capture", "apply_silent", "rollback_silent", "finalize"]:
		if not participant.has_method(method):
			return _fail(&"invalid_identity_allocation_participant", "missing " + method)
	if _identity_allocation_participant != null:
		if _identity_allocation_participant == participant:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}}
		return _fail(&"identity_allocation_participant_already_configured", "")
	_identity_allocation_participant = participant
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}}

func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return _fail(&"invalid_mutation_gate", "gate contract incomplete")
	for method in _GATE_CONTRACT_METHODS:
		if not gate.has_method(method):
			return _fail(&"invalid_mutation_gate", "missing method: " + method)
	if _mutation_gate != null:
		if gate == _mutation_gate:
			return {"ok": true, "code": &"ok",
				"value": {"gate_instance_id": _mutation_gate.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return _fail(&"mutation_gate_already_configured", "")
	_mutation_gate = gate
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _mutation_gate.get_instance_id(), "already_configured": false},
		"receipt": {}}

func record_stable_checkpoint(checkpoint_inputs: Dictionary, checkpoint_kind: StringName) -> Dictionary:
	if _storage == null:
		return _fail(&"not_initialized", "")
	var input_error := _validate_checkpoint_inputs(checkpoint_inputs)
	if input_error != "":
		return _fail(&"invalid_checkpoint_inputs", input_error)
	var run_id := str((checkpoint_inputs["snapshot_input"]["lifecycle"] as Dictionary).get("run_id", ""))
	var peeked: Dictionary = _journal.peek_next_sequence(run_id)
	if not peeked.get("ok", false):
		return peeked
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		checkpoint_inputs["snapshot_input"], checkpoint_inputs["dialogic_checkpoint"],
		str(checkpoint_inputs["route_id"]), checkpoint_inputs["active_app_id"],
		checkpoint_inputs["audio_context"], int(checkpoint_inputs["content_version"]),
		int(peeked["value"]["checkpoint_sequence"]))
	if not built.get("ok", false):
		return built
	var prepared: Dictionary = _journal.prepare_record(built["value"]["snapshot"], checkpoint_kind)
	if not prepared.get("ok", false):
		return prepared
	var committed: Dictionary = _journal.commit_prepared(prepared["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	if _pending_deferred_save and _lock_owner == &"":
		_pending_deferred_save = false
		autosave_latest()
	return committed

func get_latest_stable_checkpoint() -> Dictionary:
	return _journal.get_current_bundle()

func save_latest_to_slot(slot_id: int) -> Dictionary:
	return _write_latest(_resolve_locator(&"slot", slot_id), "manual")

func quick_save_latest() -> Dictionary:
	return _write_latest(_resolve_locator(&"quick", -1), "quick")

func autosave_latest() -> Dictionary:
	return _write_latest(_resolve_locator(&"autosave", -1), "automatic")

func save_for_logout() -> Dictionary:
	if not _journal.get_current_bundle().get("ok", false):
		return {"ok": true, "code": &"ok", "value": {"written": false, "save_reason": "logout"}}
	return _write_latest(_resolve_locator(&"autosave", -1), "logout")

func prepare_restore_slot(slot_id: int) -> Dictionary:
	return _prepare_restore(_resolve_locator(&"slot", slot_id))

func prepare_restore_quick() -> Dictionary:
	return _prepare_restore(_resolve_locator(&"quick", -1))

func prepare_restore_autosave() -> Dictionary:
	return _prepare_restore(_resolve_locator(&"autosave", -1))

## Brief line 209: `commit_prepared_restore()` accepts only the opaque value returned by
## `prepare_restore_slot|quick|autosave` above. When that value carries a `source_locator` (every
## real `_prepare_restore()` result does, Phase C2 on), this drives the FULL identity-allocation +
## remap + external-journal sequence before running the 8-participant transaction; a hand-built
## `prepared` with no `source_locator` (e.g. a fake-participant orchestration test) skips straight to
## the participant transaction with whatever "run"/"desktop_consequence"/"desktop_board" plans it
## already supplied, exactly as this method behaved before Task 6.
func commit_prepared_restore(prepared: Dictionary) -> Dictionary:
	if _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "configure_restore_participants first")
	for key: Variant in prepared.keys():
		if str(key) not in _PREPARED_RESTORE_ALLOWED_KEYS:
			return _fail(&"invalid_prepared_restore", "unexpected prepared key: " + str(key))
	if typeof(prepared.get("participant_plans")) != TYPE_DICTIONARY:
		return _fail(&"invalid_prepared_restore", "prepared requires participant_plans")
	var plans: Dictionary = (prepared["participant_plans"] as Dictionary).duplicate(true)

	var continuation: Dictionary = {}
	if typeof(prepared.get("source_locator")) == TYPE_DICTIONARY:
		var begun := _begin_restore_continuation(prepared)
		if not begun.get("ok", false):
			return begun
		var remapped_snapshot: Dictionary = (begun["value"] as Dictionary)["remapped_snapshot"]
		var run_plan: Dictionary = (plans.get("run", {}) as Dictionary).duplicate(true)
		run_plan["snapshot"] = remapped_snapshot
		plans["run"] = run_plan
		var remapped_desktop: Dictionary = remapped_snapshot["desktop"]
		var consequence_prep: Dictionary = _restore_participants["desktop_consequence"].prepare(
			{"state": remapped_desktop["consequence"]})
		if not consequence_prep.get("ok", false):
			return consequence_prep
		plans["desktop_consequence"] = (consequence_prep["value"] as Dictionary)["consequence_plan"]
		var board_prep: Dictionary = _restore_participants["desktop_board"].prepare(
			{"state": remapped_desktop["board"]})
		if not board_prep.get("ok", false):
			return board_prep
		plans["desktop_board"] = (board_prep["value"] as Dictionary)["board_plan"]
		continuation = (begun["value"] as Dictionary)["continuation"]

	for key: String in _PARTICIPANT_KEYS:
		if typeof(plans.get(key)) != TYPE_DICTIONARY:
			return _fail(&"invalid_prepared_restore", "missing participant plan: " + key)
	return _run_participant_transaction(&"restore", plans, prepared.get("journal_seed"),
		str(prepared.get("route_id", "")), str(prepared.get("checkpoint_id", "")), true, continuation)

## Drives the identity-allocation participant plus the external continuation journal's
## `intent_committed -> identity_allocation_committed -> participants_applying` sequence for a
## restore (Plan 02 Task 6, dwm-p2r.32, Phase C2, brief lines 259-293). Mints the restore transaction
## token itself (the identity-allocation participant's frozen input requires it already minted), then
## hands the participant everything it needs to reload+hash-verify the source independently ("reloads
## that value's semantic locator and document hash" -- brief line 209) and reproduce the exact
## allocation candidate this method computed the fingerprint from.
func _begin_restore_continuation(prepared: Dictionary) -> Dictionary:
	if _identity_allocation_participant == null:
		return _fail(&"identity_allocation_participant_not_configured", "configure_identity_allocation_participant first")
	if _identity_issuer == null:
		return _fail(&"identity_issuer_not_configured", "configure_identity_issuer first")
	var source_locator: Dictionary = prepared["source_locator"]
	var existing_run_id := str(prepared.get("existing_run_id", ""))
	var source_generation := int(prepared.get("source_desktop_timeline_generation", 0))
	var remap_ids: Array = prepared.get("remap_source_transaction_ids", [])

	var issued: Dictionary = _identity_issuer.call(&"issue", &"transaction_id")
	if not issued.get("ok", false):
		return issued
	var restore_transaction_id := str(issued["value"]["token"])
	var transaction_issuer_receipt: Dictionary = issued["value"]["issuer_receipt"]

	var alloc_request := {
		"existing_run_id": existing_run_id, "kind": "restore", "remap_source_transaction_ids": remap_ids,
		"source_desktop_timeline_generation": source_generation, "transaction_id": restore_transaction_id,
		"transaction_issuer_receipt": transaction_issuer_receipt,
	}
	var prepared_alloc: Dictionary = _identity_issuer.call(&"prepare_continuation_allocation", alloc_request)
	if not prepared_alloc.get("ok", false):
		return prepared_alloc
	var raw_candidate: Dictionary = prepared_alloc["value"]
	var allocation_fingerprint := _canonical_sha256(raw_candidate)
	if allocation_fingerprint.is_empty():
		return _fail(&"allocation_candidate_not_canonicalizable", "")

	var request_fingerprint := _canonical_sha256({
		"kind": "restore", "transaction_id": restore_transaction_id, "source_locator": source_locator,
	})
	if request_fingerprint.is_empty():
		return _fail(&"continuation_request_not_canonicalizable", "")

	var intent_prepared: Dictionary = _continuation_journal.prepare_intent({
		"allocation_candidate_fingerprint": allocation_fingerprint, "initial_context": null,
		"initial_context_sha256": null, "kind": "restore", "request_fingerprint": request_fingerprint,
		"source_locator": source_locator, "transaction_id": restore_transaction_id,
		"transaction_issuer_receipt": transaction_issuer_receipt,
	})
	if not intent_prepared.get("ok", false):
		return intent_prepared
	var intent_committed: Dictionary = _continuation_journal.commit_intent(intent_prepared["value"])
	if not intent_committed.get("ok", false):
		return intent_committed

	var identity_input := {
		"restore_transaction_id": restore_transaction_id, "transaction_issuer_receipt": transaction_issuer_receipt,
		"source_locator": source_locator, "existing_run_id": existing_run_id,
		"source_desktop_timeline_generation": source_generation, "remap_source_transaction_ids": remap_ids,
		"allocation_candidate_fingerprint": allocation_fingerprint,
	}
	var identity_prepared: Dictionary = _identity_allocation_participant.prepare(identity_input)
	if not identity_prepared.get("ok", false):
		return identity_prepared
	var identity_candidate: Dictionary = (identity_prepared["value"] as Dictionary)["candidate"]
	var identity_applied: Dictionary = _identity_allocation_participant.apply_silent(identity_candidate)
	if not identity_applied.get("ok", false):
		return identity_applied
	var allocation_receipt: Dictionary = (identity_applied["value"] as Dictionary)["allocation_receipt"]

	var advance_to_allocated: Dictionary = _continuation_journal.advance({
		"transaction_id": restore_transaction_id, "request_fingerprint": request_fingerprint,
		"expected_stage": CONTINUATION_JOURNAL.STAGE_INTENT, "next_stage": CONTINUATION_JOURNAL.STAGE_ALLOCATED,
		"expected_next_participant_index": 0, "allocation_receipt": allocation_receipt,
		"participant_name": null, "participant_receipt": null, "failure": null,
	})
	if not advance_to_allocated.get("ok", false):
		# Root allocation is already durably, irreversibly committed above; recovery must advance
		# forward from here (brief line 249), never roll back.
		return advance_to_allocated
	var advance_to_applying: Dictionary = _continuation_journal.advance({
		"transaction_id": restore_transaction_id, "request_fingerprint": request_fingerprint,
		"expected_stage": CONTINUATION_JOURNAL.STAGE_ALLOCATED, "next_stage": CONTINUATION_JOURNAL.STAGE_APPLYING,
		"expected_next_participant_index": 0, "allocation_receipt": null,
		"participant_name": null, "participant_receipt": null, "failure": null,
	})
	if not advance_to_applying.get("ok", false):
		return advance_to_applying

	return {"ok": true, "code": &"ok", "value": {
		"restore_transaction_id": restore_transaction_id,
		"identity_allocation_bundle": identity_candidate["identity_allocation_bundle"],
		"remapped_snapshot": identity_candidate["remapped_snapshot"],
		"continuation": {
			"transaction_id": restore_transaction_id, "request_fingerprint": request_fingerprint,
			"remap": {"restore_transaction_id": restore_transaction_id,
				"identity_allocation_bundle": identity_candidate["identity_allocation_bundle"]},
		},
	}}

func start_new_run(initial_context: Dictionary) -> Dictionary:
	if _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "configure_restore_participants first")
	if _identity_issuer == null:
		return _fail(&"identity_issuer_not_configured", "configure_identity_issuer first")
	var context_error := _validate_new_run_context(initial_context)
	if context_error != "":
		return _fail(&"invalid_initial_context", context_error)

	var begun := _begin_new_run_continuation(initial_context)
	if not begun.get("ok", false):
		return begun
	var identity: Dictionary = (begun["value"] as Dictionary)["identity"]
	var continuation: Dictionary = (begun["value"] as Dictionary)["continuation"]

	# Ask the run participant for a detached Day-1 snapshot input for the new run, bound to the
	# durably allocated identity.
	var new_run: Dictionary = _restore_participants["run"].prepare_new_run(
		str(identity["run_id"]), str(identity["branch_id"]), int(identity["desktop_timeline_generation"]),
		str(identity["causal_day_instance"]), identity["causal_day_instance_issuer_receipt"])
	if not new_run.get("ok", false):
		return new_run
	var snapshot_input: Dictionary = new_run["value"]["snapshot_input"]
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		snapshot_input, initial_context["dialogic_checkpoint"], str(initial_context["route_id"]),
		initial_context["active_app_id"], initial_context["audio_context"],
		int(initial_context["content_version"]), 1)
	if not built.get("ok", false):
		return built
	var snapshot: Dictionary = built["value"]["snapshot"]

	# desktop_consequence/desktop_board plans go through the SAME participants a restore uses,
	# prepared against the fresh empty state the run participant's snapshot already carries.
	var consequence_prep: Dictionary = _restore_participants["desktop_consequence"].prepare(
		{"state": snapshot["desktop"]["consequence"]})
	if not consequence_prep.get("ok", false):
		return consequence_prep
	var board_prep: Dictionary = _restore_participants["desktop_board"].prepare(
		{"state": snapshot["desktop"]["board"]})
	if not board_prep.get("ok", false):
		return board_prep

	# Empty profile patch preserves the complete global profile for a new game.
	#
	# dwm-p2r.32 Plan 02 Task 9, HONEST GAP (NOT fixed by Task 9): this comment's own stated intent
	# is not what happens. Neither literal below is routed through its participant's `prepare()`, so
	# neither can ever satisfy its real validator -- ProfileSchema.validate({}) rejects the empty
	# "profile" candidate (an exact 7-key object is required) and
	# LocalizationManager._is_restore_plan_valid({}) rejects the empty "localization" candidate (four
	# keys are required) the same way. start_new_run() therefore cannot complete against the real
	# ProfileManager/LocalizationManager pair today; confirmed live in
	# tests/integration/test_desktop_crash_recovery.gd, which proves the fail-closed result rather
	# than papering over it. This file is one of Task 9's own authorized Modify targets, so this is
	# not blocked by file ownership -- it is left unfixed because the correct fix (what locale/
	# profile a brand-new run should start from, including the case where no profile.json exists yet)
	# is a real design decision this task's own brief never specifies.
	var plans := {
		"run": {"snapshot": snapshot},
		"desktop_consequence": (consequence_prep["value"] as Dictionary)["consequence_plan"],
		"desktop_board": (board_prep["value"] as Dictionary)["board_plan"],
		"profile": {"profile": {}},
		"localization": {},
		"audio": {"snapshot": initial_context["audio_context"]},
		"route": {"route_id": str(initial_context["route_id"]), "route_context": {}},
		"narrative": {"narrative_checkpoint": initial_context["dialogic_checkpoint"]},
	}
	# Prepare the Run-B journal as a full reset with the Day-1 bundle current.
	var reset: Dictionary = _journal.prepare_reset_with_initial(snapshot, &"day_start")
	if not reset.get("ok", false):
		return reset
	var result := _run_participant_transaction(&"new_run", plans, reset["value"]["candidate"],
		str(initial_context["route_id"]), str(snapshot["checkpoint_id"]), false, continuation)
	if not result.get("ok", false):
		return result
	result["value"]["run_id"] = str(identity["run_id"])
	return result

## Real, durable Task-1 issuer allocation for the New-Run identity bundle (brief line 362: "direct-
## v4 New Run over Task-1 issuer/journal seams"), now (Phase C2) ALSO driven through the external
## DesktopContinuationOperationJournal's `intent_committed -> identity_allocation_committed ->
## participants_applying` sequence -- the same journal a restore drives, just without the identity-
## allocation PARTICIPANT (new_run mints its own identity directly on the issuer; there is no source
## snapshot to remap).
func _begin_new_run_continuation(initial_context: Dictionary) -> Dictionary:
	var issued: Dictionary = _identity_issuer.call(&"issue", &"transaction_id")
	if not issued.get("ok", false):
		return issued
	var transaction_id := str(issued["value"]["token"])
	var transaction_issuer_receipt: Dictionary = issued["value"]["issuer_receipt"]
	var request := {
		"existing_run_id": null, "kind": "new_run", "remap_source_transaction_ids": [],
		"source_desktop_timeline_generation": null, "transaction_id": transaction_id,
		"transaction_issuer_receipt": transaction_issuer_receipt,
	}
	var prepared: Dictionary = _identity_issuer.call(&"prepare_continuation_allocation", request)
	if not prepared.get("ok", false):
		return prepared
	var raw_candidate: Dictionary = prepared["value"]
	var allocation_fingerprint := _canonical_sha256(raw_candidate)
	if allocation_fingerprint.is_empty():
		return _fail(&"allocation_candidate_not_canonicalizable", "")
	var initial_context_hash := _canonical_sha256(initial_context)
	if initial_context_hash.is_empty():
		return _fail(&"initial_context_not_canonicalizable", "")
	var request_fingerprint := _canonical_sha256({
		"kind": "new_run", "transaction_id": transaction_id, "initial_context": initial_context,
	})
	if request_fingerprint.is_empty():
		return _fail(&"continuation_request_not_canonicalizable", "")

	var intent_prepared: Dictionary = _continuation_journal.prepare_intent({
		"allocation_candidate_fingerprint": allocation_fingerprint, "initial_context": initial_context,
		"initial_context_sha256": initial_context_hash, "kind": "new_run",
		"request_fingerprint": request_fingerprint, "source_locator": null,
		"transaction_id": transaction_id, "transaction_issuer_receipt": transaction_issuer_receipt,
	})
	if not intent_prepared.get("ok", false):
		return intent_prepared
	var intent_committed: Dictionary = _continuation_journal.commit_intent(intent_prepared["value"])
	if not intent_committed.get("ok", false):
		return intent_committed

	var committed: Dictionary = _identity_issuer.call(&"commit_continuation_allocation", raw_candidate)
	if not committed.get("ok", false):
		return committed
	var allocated: Dictionary = committed["value"]

	var advance_to_allocated: Dictionary = _continuation_journal.advance({
		"transaction_id": transaction_id, "request_fingerprint": request_fingerprint,
		"expected_stage": CONTINUATION_JOURNAL.STAGE_INTENT, "next_stage": CONTINUATION_JOURNAL.STAGE_ALLOCATED,
		"expected_next_participant_index": 0, "allocation_receipt": allocated,
		"participant_name": null, "participant_receipt": null, "failure": null,
	})
	if not advance_to_allocated.get("ok", false):
		return advance_to_allocated
	var advance_to_applying: Dictionary = _continuation_journal.advance({
		"transaction_id": transaction_id, "request_fingerprint": request_fingerprint,
		"expected_stage": CONTINUATION_JOURNAL.STAGE_ALLOCATED, "next_stage": CONTINUATION_JOURNAL.STAGE_APPLYING,
		"expected_next_participant_index": 0, "allocation_receipt": null,
		"participant_name": null, "participant_receipt": null, "failure": null,
	})
	if not advance_to_applying.get("ok", false):
		return advance_to_applying

	return {"ok": true, "code": &"ok", "value": {
		"identity": {
			"run_id": str(allocated["run_id"]), "branch_id": str(allocated["branch_id"]),
			"desktop_timeline_generation": int(allocated["desktop_timeline_generation"]),
			"causal_day_instance": str(allocated["causal_day_instance"]),
			"causal_day_instance_issuer_receipt": (allocated["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true),
		},
		"continuation": {"transaction_id": transaction_id, "request_fingerprint": request_fingerprint},
	}}

## `continuation` (Plan 02 Task 6, dwm-p2r.32, Phase C2), when non-empty, is `{transaction_id,
## request_fingerprint, remap: {restore_transaction_id, identity_allocation_bundle} | absent}` --
## produced by `_begin_new_run_continuation()`/`_begin_restore_continuation()` above. Empty means a
## caller supplied a hand-built `prepared`/`plans` with no external-journal identity to advance (the
## pure fake-participant orchestration tests): this method then behaves exactly as it did before
## Task 6. When present, this drives `DesktopContinuationOperationJournal.advance()` for every
## participant position PLUS the run-identity remap step, right after "run"'s own ordinary apply.
func _run_participant_transaction(
		owner: StringName, plans: Dictionary, journal_candidate: Variant,
		route_id: String, checkpoint_id: String, emit_restored: bool, continuation: Dictionary = {}
) -> Dictionary:
	# `restore` also holds the SaveManager save lock; `new_run` relies on the gate.
	var holds_save_lock := owner == &"restore"
	if holds_save_lock:
		var lock: Dictionary = acquire_save_lock(&"restore")
		if not lock.get("ok", false):
			return lock
	var gate_token := ""
	if _mutation_gate != null:
		var acquired: Dictionary = _mutation_gate.acquire(owner)
		if not acquired.get("ok", false):
			if holds_save_lock:
				release_save_lock(&"restore")
			return acquired
		gate_token = str(acquired["value"]["token"])

	var backups := {}
	for key: String in _PARTICIPANT_APPLY_ORDER:
		var captured: Dictionary = _restore_participants[key].capture()
		if not captured.get("ok", false):
			_release_transaction(owner, gate_token, holds_save_lock)
			return captured
		backups[key] = captured["value"]

	var applied: Array[String] = []
	var route_ready_token: Variant = null
	for index: int in range(_PARTICIPANT_APPLY_ORDER.size()):
		var key: String = _PARTICIPANT_APPLY_ORDER[index]
		var plan: Dictionary = (plans[key] as Dictionary).duplicate(true)
		if key == "narrative" and route_ready_token != null:
			plan["route_ready_token"] = route_ready_token
		var result: Dictionary = _restore_participants[key].apply_silent(plan)
		if not result.get("ok", false):
			return _rollback_transaction(owner, applied, backups, gate_token, holds_save_lock, result)
		if key == "run" and continuation.has("remap"):
			var remap_info: Dictionary = continuation["remap"]
			var remapped: Dictionary = _restore_participants["run"].apply_continuation_remap(
				str(remap_info["restore_transaction_id"]), remap_info["identity_allocation_bundle"])
			if not remapped.get("ok", false):
				applied.append(key)
				return _rollback_transaction(owner, applied, backups, gate_token, holds_save_lock, remapped)
		applied.append(key)
		if key == "route":
			route_ready_token = (result.get("value", {}) as Dictionary).get("route_ready_token")
		if not continuation.is_empty():
			var receipt_value: Variant = result.get("value", {})
			var participant_receipt: Dictionary = receipt_value if typeof(receipt_value) == TYPE_DICTIONARY else {}
			var advanced: Dictionary = _continuation_journal.advance({
				"transaction_id": continuation["transaction_id"], "request_fingerprint": continuation["request_fingerprint"],
				"expected_stage": CONTINUATION_JOURNAL.STAGE_APPLYING, "next_stage": CONTINUATION_JOURNAL.STAGE_APPLYING,
				"expected_next_participant_index": index, "allocation_receipt": null,
				"participant_name": key, "participant_receipt": participant_receipt, "failure": null,
			})
			if not advanced.get("ok", false):
				return _rollback_transaction(owner, applied, backups, gate_token, holds_save_lock, advanced)

	if not continuation.is_empty():
		var advanced_to_applied: Dictionary = _continuation_journal.advance({
			"transaction_id": continuation["transaction_id"], "request_fingerprint": continuation["request_fingerprint"],
			"expected_stage": CONTINUATION_JOURNAL.STAGE_APPLYING, "next_stage": CONTINUATION_JOURNAL.STAGE_APPLIED,
			"expected_next_participant_index": _PARTICIPANT_APPLY_ORDER.size(), "allocation_receipt": null,
			"participant_name": null, "participant_receipt": null, "failure": null,
		})
		if not advanced_to_applied.get("ok", false):
			return _rollback_transaction(owner, applied, backups, gate_token, holds_save_lock, advanced_to_applied)

	if typeof(journal_candidate) == TYPE_DICTIONARY:
		var committed: Dictionary = _journal.commit_prepared(journal_candidate)
		if not committed.get("ok", false):
			return _rollback_transaction(owner, applied, backups, gate_token, holds_save_lock, committed)
		if checkpoint_id.is_empty():
			checkpoint_id = str(committed["value"]["checkpoint_id"])

	for key: String in _PARTICIPANT_APPLY_ORDER:
		var finalized: Dictionary = _restore_participants[key].finalize()
		if not finalized.get("ok", false):
			return _rollback_transaction(owner, applied, backups, gate_token, holds_save_lock, finalized)
	_release_transaction(owner, gate_token, holds_save_lock)
	if not continuation.is_empty():
		# Best-effort: participants are already finalized and the checkpoint journal already
		# committed, so a failure here is NOT rolled back (that would undo genuinely-completed work).
		# The journal's own replay-safe advance() lets a later reconciliation pass finish this.
		_continuation_journal.advance({
			"transaction_id": continuation["transaction_id"], "request_fingerprint": continuation["request_fingerprint"],
			"expected_stage": CONTINUATION_JOURNAL.STAGE_APPLIED, "next_stage": CONTINUATION_JOURNAL.STAGE_COMPLETED,
			"expected_next_participant_index": _PARTICIPANT_APPLY_ORDER.size(), "allocation_receipt": null,
			"participant_name": null, "participant_receipt": null, "failure": null,
		})
	if emit_restored:
		run_restored.emit(checkpoint_id, route_id)
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": checkpoint_id, "route_id": route_id}}

func _validate_new_run_context(initial_context: Dictionary) -> String:
	var keys: Array = initial_context.keys()
	keys.sort()
	if keys != ["active_app_id", "audio_context", "content_version", "dialogic_checkpoint", "route_id"]:
		return "unexpected initial_context keys: " + str(keys)
	if str(initial_context["route_id"]) != "opening":
		return "route_id must be \"opening\""
	if typeof(initial_context["dialogic_checkpoint"]) != TYPE_DICTIONARY or not (initial_context["dialogic_checkpoint"] as Dictionary).is_empty():
		return "dialogic_checkpoint must be {}"
	if initial_context["active_app_id"] != null:
		return "active_app_id must be null"
	if typeof(initial_context["audio_context"]) != TYPE_DICTIONARY or not (initial_context["audio_context"] as Dictionary).is_empty():
		return "audio_context must be {}"
	if typeof(initial_context["content_version"]) != TYPE_INT or int(initial_context["content_version"]) < 1:
		return "content_version must be a positive integer"
	return ""

func _release_transaction(owner: StringName, gate_token: String, holds_save_lock: bool) -> void:
	if _mutation_gate != null and gate_token != "":
		_mutation_gate.release(owner, gate_token)
	if holds_save_lock:
		release_save_lock(&"restore")

func _rollback_transaction(owner: StringName, applied: Array[String], backups: Dictionary, gate_token: String, holds_save_lock: bool, original_failure: Dictionary) -> Dictionary:
	var attempts: Array = []
	var all_recovered := true
	for index: int in range(applied.size() - 1, -1, -1):
		var key: String = applied[index]
		var rolled: Dictionary = _restore_participants[key].rollback_silent(backups[key])
		attempts.append({"owner_id": key, "operation": "rollback_silent", "result": rolled})
		if not rolled.get("ok", false):
			all_recovered = false
	if all_recovered:
		_release_transaction(owner, gate_token, holds_save_lock)
		return original_failure
	return _fatal_transaction_recovery(String(owner), attempts)

func _fatal_transaction_recovery(source: String, raw_diagnostics: Array) -> Dictionary:
	if _mutation_gate == null:
		return {"ok": false, "code": &"restore_rollback_failed", "message": "rollback failed with no gate"}
	var already_retained := false
	for diagnostic: Dictionary in raw_diagnostics:
		if str((diagnostic.get("result", {}) as Dictionary).get("code", "")) == "APPLICATION_FATAL":
			already_retained = true
	if not already_retained and not _mutation_gate.is_fatal_latched():
		var projected: Dictionary = PROJECTOR.project_failure(
			source, "rollback", "fatal_rollback_failed", {"phase": source + "_recovery"}, raw_diagnostics)
		var candidate: Dictionary = PROJECTOR.get_invariant_fallback()
		if projected.get("ok", false) and PROJECTOR.validate_failure(projected["value"]["failure"]).get("ok", false):
			candidate = projected["value"]["failure"]
		_mutation_gate.latch_fatal(candidate)
	return _mutation_gate.guard_external(StringName(source + "_recovery"))

func delete_slot(slot_id: int) -> Dictionary:
	return _delete(_resolve_locator(&"slot", slot_id))

func delete_quick_save() -> Dictionary:
	return _delete(_resolve_locator(&"quick", -1))

func delete_autosave() -> Dictionary:
	return _delete(_resolve_locator(&"autosave", -1))

func save_exists(kind: StringName, slot_id: int = -1) -> bool:
	var locator := _resolve_locator(kind, slot_id)
	if locator.is_empty() or _storage == null:
		return false
	return _storage.exists(str(locator["relative_path"]))

func get_save_metadata(kind: StringName, slot_id: int = -1) -> Dictionary:
	var locator := _resolve_locator(kind, slot_id)
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "%s/%d" % [kind, slot_id])
	if _storage == null:
		return _fail(&"not_initialized", "")
	var relative_path := str(locator["relative_path"])
	if not _storage.exists(relative_path):
		return {"ok": true, "code": &"ok", "value": {
			"exists": false, "kind": str(locator["kind"]), "slot_id": locator["slot_id"],
			"save_reason": null, "run_id": null, "day": null, "state": null, "checkpoint_id": null,
		}}
	var read: Dictionary = _storage.read_text(relative_path)
	if not read.get("ok", false):
		return read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(read["value"]))
	if not parsed.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var document: Dictionary = validated["value"]["candidate"]
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	return {"ok": true, "code": &"ok", "value": {
		"exists": true,
		"kind": str(document["kind"]),
		"slot_id": document["slot_id"],
		"save_reason": str(document["save_reason"]),
		"run_id": str(snapshot["run_id"]),
		"day": int(snapshot["lifecycle"]["day"]),
		"state": str(snapshot["lifecycle"]["state"]),
		"checkpoint_id": str(snapshot["checkpoint_id"]),
	}}

func get_all_save_metadata() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for slot_id: int in range(MIN_SLOT, MAX_SLOT + 1):
		records.append(get_save_metadata(&"slot", slot_id))
	records.append(get_save_metadata(&"quick", -1))
	records.append(get_save_metadata(&"autosave", -1))
	return records

func acquire_save_lock(owner_id: StringName) -> Dictionary:
	if owner_id not in _LOCK_OWNERS:
		return _fail(&"invalid_lock_owner", String(owner_id))
	if _lock_owner != &"" and _lock_owner != owner_id:
		return _fail(&"save_lock_held", String(_lock_owner))
	var was_locked := _lock_owner == owner_id
	_lock_owner = owner_id
	if not was_locked:
		save_capability_changed.emit(get_save_capability())
	return {"ok": true, "code": &"ok", "value": {"owner_id": owner_id, "already_locked": was_locked}}

func release_save_lock(owner_id: StringName) -> Dictionary:
	if _lock_owner == &"" or owner_id != _lock_owner:
		return _fail(&"save_lock_mismatch", String(owner_id))
	_lock_owner = &""
	save_capability_changed.emit(get_save_capability())
	if _pending_deferred_save:
		_pending_deferred_save = false
		autosave_latest()
	return {"ok": true, "code": &"ok", "value": {"owner_id": owner_id}}

func is_save_locked() -> bool:
	return _lock_owner != &""

func get_save_capability() -> Dictionary:
	match _lock_owner:
		&"minesweeper_board":
			return {"enabled": false, "silent": true, "deferred": false}
		&"scene_transition":
			return {"enabled": false, "silent": true, "deferred": true}
		&"restore":
			return {"enabled": false, "silent": true, "deferred": false}
	return {"enabled": true, "silent": false, "deferred": false}

func configure_restore_participants(participants: Dictionary) -> Dictionary:
	var keys: Array = participants.keys()
	keys.sort()
	# `_PARTICIPANT_KEYS` is apply order, not alphabetical (Plan 02 Task 6, dwm-p2r.32, Phase C2 --
	# it doubles as `_PARTICIPANT_APPLY_ORDER`), so the exact-set check needs its own sorted copy.
	var expected := _PARTICIPANT_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return _fail(&"invalid_restore_participants", "exactly eight participants required: " + str(keys))
	for key: String in _PARTICIPANT_KEYS:
		var participant: Variant = participants[key]
		if typeof(participant) != TYPE_OBJECT or participant == null:
			return _fail(&"invalid_restore_participants", key + " must be an object")
		for method: String in ["prepare", "capture", "apply_silent", "rollback_silent", "finalize"]:
			if not (participant as Object).has_method(method):
				return _fail(&"invalid_restore_participants", "%s is missing %s" % [key, method])
	_restore_participants = participants.duplicate()
	return {"ok": true, "code": &"ok", "value": {"participant_count": _PARTICIPANT_KEYS.size()}}

# ---- Deprecated wrappers (one issue only; delegate to the new facade) ----

func save_slot(slot_id: int) -> Dictionary:
	return save_latest_to_slot(slot_id)

func load_slot(slot_id: int) -> Dictionary:
	var prepared := prepare_restore_slot(slot_id)
	if not prepared.get("ok", false):
		return prepared
	return commit_prepared_restore(prepared["value"]["prepared"])

func quick_save() -> Dictionary:
	return quick_save_latest()

func quick_load() -> Dictionary:
	var prepared := prepare_restore_quick()
	if not prepared.get("ok", false):
		return prepared
	return commit_prepared_restore(prepared["value"]["prepared"])

func autosave() -> Dictionary:
	return autosave_latest()

func load_autosave() -> Dictionary:
	var prepared := prepare_restore_autosave()
	if not prepared.get("ok", false):
		return prepared
	return commit_prepared_restore(prepared["value"]["prepared"])

func has_slot(slot_id: int) -> bool:
	return save_exists(&"slot", slot_id)

func get_slot_metadata(slot_id: int) -> Dictionary:
	return get_save_metadata(&"slot", slot_id)

func get_all_slot_metadata() -> Array:
	return get_all_save_metadata()

# ---- Internals ----

func _resolve_locator(kind: StringName, public_slot_id: int) -> Dictionary:
	match kind:
		&"slot":
			if public_slot_id < MIN_SLOT or public_slot_id > MAX_SLOT:
				return {}
			return {"kind": "slot", "slot_id": public_slot_id,
				"relative_path": "slot_%d.json" % public_slot_id}
		&"quick":
			if public_slot_id != -1:
				return {}
			return {"kind": "quick", "slot_id": null, "relative_path": "quicksave.json"}
		&"autosave":
			if public_slot_id != -1:
				return {}
			return {"kind": "autosave", "slot_id": null, "relative_path": "autosave.json"}
	return {}

func _write_latest(locator: Dictionary, save_reason: String) -> Dictionary:
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	match _lock_owner:
		&"minesweeper_board", &"restore":
			return {"ok": false, "code": &"save_locked", "message": "",
				"details": {"silent": true, "deferred": false}}
		&"scene_transition":
			_pending_deferred_save = true
			return {"ok": false, "code": &"save_locked", "message": "",
				"details": {"silent": true, "deferred": true}}
	var bundle: Dictionary = _journal.get_current_bundle()
	if not bundle.get("ok", false):
		return _fail(&"no_stable_checkpoint", "")
	var built: Dictionary = SAVE_DOCUMENT_SCHEMA.build(
		StringName(str(locator["kind"])), locator["slot_id"], StringName(save_reason),
		bundle["value"]["bundle"], _journal.get_bundles_for_disk())
	if not built.get("ok", false):
		save_failed.emit(built)
		return built
	var canonical: Dictionary = CANONICAL_JSON.stringify(built["value"])
	if not canonical.get("ok", false):
		return _fail(&"canonical_serialization_failed", "")
	var relative_path := str(locator["relative_path"])
	var written: Dictionary = _storage.write_atomic(
		relative_path, str(canonical["value"]) + "\n", _document_text_validator)
	if not written.get("ok", false):
		save_failed.emit(written)
		return written
	var re_read: Dictionary = _storage.read_text(relative_path)
	if not re_read.get("ok", false):
		return re_read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(re_read["value"]))
	if not parsed.get("ok", false):
		return _fail(&"reread_mismatch", relative_path)
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return _fail(&"reread_mismatch", relative_path)
	var document: Dictionary = validated["value"]["candidate"]
	if str(document["kind"]) != str(locator["kind"]) or str(document["save_reason"]) != save_reason:
		return _fail(&"reread_mismatch", "locator or reason drift")
	var result := {"ok": true, "code": &"ok", "value": {
		"kind": str(locator["kind"]),
		"slot_id": locator["slot_id"],
		"save_reason": save_reason,
		"checkpoint_id": str(document["current_snapshot"]["snapshot"]["checkpoint_id"]),
		"written": true,
	}}
	save_completed.emit(result)
	slot_metadata_changed.emit()
	return result

func _prepare_restore(locator: Dictionary) -> Dictionary:
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	if _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "configure_restore_participants first")
	var relative_path := str(locator["relative_path"])
	if not _storage.exists(relative_path):
		return _fail(&"save_absent", relative_path)
	var read: Dictionary = _storage.read_text(relative_path)
	if not read.get("ok", false):
		return read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(read["value"]))
	if not parsed.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)

	# Migrate the document and every retained bundle. Structural/future-schema
	# failures are frozen and never fall back to compatibility selection.
	var migrated: Dictionary = SAVE_MIGRATIONS.migrate_document(parsed["value"],
		{"kind": str(locator["kind"]), "slot_id": locator["slot_id"]})
	if not migrated.get("ok", false):
		return migrated
	var document: Dictionary = migrated["value"]["document"]
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(document)
	if not validated.get("ok", false):
		return validated
	document = validated["value"]["candidate"]

	# Order candidates: current bundle first, then earlier journal bundles by
	# descending checkpoint_sequence. No field is ever combined across bundles.
	var candidates: Array[Dictionary] = [document["current_snapshot"]]
	var earlier: Array = (document["recovery_journal"] as Array).duplicate(true)
	earlier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["snapshot"]["checkpoint_sequence"]) > int(b["snapshot"]["checkpoint_sequence"]))
	for entry: Dictionary in earlier:
		candidates.append(entry)

	var causes: Array = []
	for bundle: Dictionary in candidates:
		var prepared := _prepare_bundle_with_all_participants(bundle, migrated["value"], document, locator)
		if prepared.get("ok", false):
			return {"ok": true, "code": &"ok", "value": {"prepared": prepared["value"]}}
		if prepared.get("code") == &"BUNDLE_CONTENT_INCOMPATIBLE":
			causes.append(prepared.get("details", {}))
			continue
		# Structural/primitive/migration failures never fall back.
		return prepared
	return {"ok": false, "code": &"NO_COMPATIBLE_BUNDLE", "message": "", "details": {"causes": causes}}

func _prepare_bundle_with_all_participants(bundle: Dictionary, migration_output: Dictionary, document: Dictionary, locator: Dictionary) -> Dictionary:
	var snapshot: Dictionary = bundle["snapshot"]
	var sequence := int(snapshot["checkpoint_sequence"])
	var plans := {}

	var run_prep: Dictionary = _restore_participants["run"].prepare({"snapshot": snapshot})
	if not run_prep.get("ok", false):
		return run_prep
	plans["run"] = run_prep["value"]["run_plan"]

	# Plan 02 Task 6 (dwm-p2r.32), Phase C2. Built here against the UN-remapped snapshot bytes so a
	# plan genuinely exists right after prepare_restore_slot|quick|autosave (proven by
	# test_persisted_snapshot_is_restorable_by_the_save_manager and
	# test_prepare_builds_six_plans_and_commits); `commit_prepared_restore()` OVERWRITES all three of
	# "run"/"desktop_consequence"/"desktop_board" with fresh plans built against the REMAPPED snapshot
	# once real identity allocation runs (see `_begin_restore_continuation()`), so a plan prepared
	# here is never the one actually applied for a genuine production restore.
	var consequence_prep: Dictionary = _restore_participants["desktop_consequence"].prepare(
		{"state": snapshot["desktop"]["consequence"]})
	if not consequence_prep.get("ok", false):
		return consequence_prep
	plans["desktop_consequence"] = consequence_prep["value"]["consequence_plan"]

	var board_prep: Dictionary = _restore_participants["desktop_board"].prepare(
		{"state": snapshot["desktop"]["board"]})
	if not board_prep.get("ok", false):
		return board_prep
	plans["desktop_board"] = board_prep["value"]["board_plan"]

	var profile_prep: Dictionary = _restore_participants["profile"].prepare(
		{"legacy_profile_patch_input": migration_output["legacy_profile_patch_input"]})
	if not profile_prep.get("ok", false):
		return profile_prep
	plans["profile"] = profile_prep["value"]["profile_plan"]
	var locale_id := str(profile_prep["value"]["locale_id"])
	var preferences: Dictionary = (plans["profile"].get("profile", {}) as Dictionary).get("preferences", {})

	var loc_prep: Dictionary = _restore_participants["localization"].prepare({"locale_id": locale_id})
	if not loc_prep.get("ok", false):
		return _content_incompatible_or_fail("localization", sequence, loc_prep)
	plans["localization"] = loc_prep["value"]["localization_plan"]

	var audio_prep: Dictionary = _restore_participants["audio"].prepare(
		{"preferences": preferences, "audio_context": snapshot["audio_context"]})
	if not audio_prep.get("ok", false):
		return _content_incompatible_or_fail("audio", sequence, audio_prep)
	plans["audio"] = audio_prep["value"]["audio_plan"]

	var route_context := RUN_SNAPSHOT_SCHEMA.derive_route_restore_context(snapshot)
	if not route_context.get("ok", false):
		return route_context
	var route_prep: Dictionary = _restore_participants["route"].prepare(
		{"route_id": str(snapshot["route_id"]), "route_context": route_context["value"]})
	if not route_prep.get("ok", false):
		return _content_incompatible_or_fail("route", sequence, route_prep)
	plans["route"] = route_prep["value"]["route_plan"]

	var narr_prep: Dictionary = _restore_participants["narrative"].prepare(
		{"narrative_checkpoint": snapshot["narrative_checkpoint"], "content_version": int(snapshot["content_version"])})
	if not narr_prep.get("ok", false):
		return _content_incompatible_or_fail("narrative", sequence, narr_prep)
	plans["narrative"] = narr_prep["value"]["narrative_plan"]

	var seed: Dictionary = _journal.prepare_seed(document, bundle)
	if not seed.get("ok", false):
		return seed

	var remap_ids: Dictionary = REMAPPER.collect_rewindable_transaction_ids(snapshot)
	if not remap_ids.get("ok", false):
		return remap_ids
	return {"ok": true, "code": &"ok", "value": {
		"bundle": bundle.duplicate(true),
		"journal_seed": seed["value"]["candidate"],
		"participant_plans": plans,
		"route_id": str(snapshot["route_id"]),
		"checkpoint_id": str(snapshot["checkpoint_id"]),
		"source_locator": _build_source_locator(str(locator["kind"]), locator["slot_id"], bundle),
		"existing_run_id": str(snapshot["run_id"]),
		"source_desktop_timeline_generation": int(snapshot["lifecycle"]["desktop_timeline_generation"]),
		"remap_source_transaction_ids": (remap_ids["value"] as Dictionary)["transaction_ids"],
	}}

static func _content_incompatible_or_fail(participant_id: String, sequence: int, failure: Dictionary) -> Dictionary:
	# A typed content-unavailability becomes a recoverable BUNDLE_CONTENT_INCOMPATIBLE so
	# _prepare_restore can try an earlier whole bundle; anything else is a hard failure.
	var content_codes := ["NARRATIVE_CONTENT_UNAVAILABLE", "LOCALIZATION_CONTENT_UNAVAILABLE",
		"AUDIO_CONTENT_UNAVAILABLE", "ROUTE_CONTENT_UNAVAILABLE", "BUNDLE_CONTENT_INCOMPATIBLE"]
	if str(failure.get("code", "")) in content_codes:
		return {"ok": false, "code": &"BUNDLE_CONTENT_INCOMPATIBLE", "message": "",
			"details": {"participant_id": participant_id, "cause": failure.get("details", {}), "checkpoint_sequence": sequence}}
	return failure

## Plan 02 Task 6 (dwm-p2r.32), Phase C2: SaveManager's own `source_loader` implementation, bound as
## `DesktopContinuationOperationJournal.configure(storage, self)` (initialize() above) and as
## `DesktopIdentityAllocationRestoreParticipant.new(issuer, self)`'s second argument wherever
## Bootstrap/tests construct that participant. Reuses the SAME read/migrate/validate chain
## `_prepare_restore()` already runs, but returns the bare v4 RunSnapshot ("context") plus its
## canonical hash rather than participant plans -- exactly the duck-typed `load_context(locator) ->
## {ok,value:{context,context_sha256}}` contract both callers above already expect.
func load_context(locator: Dictionary) -> Dictionary:
	if _storage == null:
		return _fail(&"not_initialized", "")
	var resolved := _resolve_locator_from_slot_id(str(locator.get("slot_id", "")))
	if resolved.is_empty():
		return _fail(&"invalid_source_locator", "unrecognized slot_id: " + str(locator.get("slot_id", "")))
	var relative_path := str(resolved["relative_path"])
	if not _storage.exists(relative_path):
		return _fail(&"save_absent", relative_path)
	var read: Dictionary = _storage.read_text(relative_path)
	if not read.get("ok", false):
		return read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(read["value"]))
	if not parsed.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var migrated: Dictionary = SAVE_MIGRATIONS.migrate_document(parsed["value"],
		{"kind": str(resolved["kind"]), "slot_id": resolved["slot_id"]})
	if not migrated.get("ok", false):
		return migrated
	var document: Dictionary = migrated["value"]["document"]
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(document)
	if not validated.get("ok", false):
		return validated
	document = validated["value"]["candidate"]
	var bundle := _find_bundle_by_checkpoint_id(document, str(locator.get("checkpoint_id", "")))
	if bundle.is_empty():
		return _fail(&"source_bundle_not_found", str(locator.get("checkpoint_id", "")))
	var context: Dictionary = bundle["snapshot"]
	var context_hash := _canonical_sha256(context)
	if context_hash.is_empty():
		return _fail(&"context_not_canonicalizable", "")
	return {"ok": true, "code": &"ok", "value": {
		"context": (context as Dictionary).duplicate(true), "context_sha256": context_hash,
	}}

## The inverse of `_slot_id_string()` below: the source locator's `slot_id` union ("quick" |
## "autosave" | "slot:N") back to `_resolve_locator()`'s own (kind, public_slot_id) shape.
func _resolve_locator_from_slot_id(slot_id_str: String) -> Dictionary:
	if slot_id_str == "quick":
		return _resolve_locator(&"quick", -1)
	if slot_id_str == "autosave":
		return _resolve_locator(&"autosave", -1)
	if slot_id_str.begins_with("slot:"):
		var suffix := slot_id_str.trim_prefix("slot:")
		if suffix.is_valid_int():
			return _resolve_locator(&"slot", int(suffix))
	return {}

func _find_bundle_by_checkpoint_id(document: Dictionary, checkpoint_id: String) -> Dictionary:
	var current: Variant = document.get("current_snapshot")
	if typeof(current) == TYPE_DICTIONARY \
			and str(((current as Dictionary).get("snapshot", {}) as Dictionary).get("checkpoint_id", "")) == checkpoint_id:
		return current
	for entry: Variant in document.get("recovery_journal", []):
		if typeof(entry) == TYPE_DICTIONARY \
				and str(((entry as Dictionary).get("snapshot", {}) as Dictionary).get("checkpoint_id", "")) == checkpoint_id:
			return entry
	return {}

## Builds this restore's `source_locator` (Plan 02 Task 6, dwm-p2r.32, Phase C2 -- own design choice,
## not literally frozen by the brief). `bundle_id` distinguishes exactly WHICH bundle within a
## document was selected (current vs. an earlier recovery_journal entry): the canonical hash of the
## whole `{checkpoint_kind,snapshot}` bundle record. `document_sha256` is the canonical hash of the
## bundle's OWN snapshot -- the same value `load_context()` reproduces as `context_sha256`, so a
## reload can prove it landed on the exact same bytes.
func _build_source_locator(kind: String, slot_id: Variant, bundle: Dictionary) -> Dictionary:
	return {
		"bundle_id": _canonical_sha256(bundle),
		"checkpoint_id": str((bundle["snapshot"] as Dictionary)["checkpoint_id"]),
		"document_sha256": _canonical_sha256(bundle["snapshot"]),
		"slot_id": _slot_id_string(kind, slot_id),
	}

static func _slot_id_string(kind: String, slot_id: Variant) -> String:
	if kind == "slot":
		return "slot:%d" % int(slot_id)
	return kind

static func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()

## Plan 02 Task 6 (dwm-p2r.32), brief line 293: "Every New-Run/restore startup calls
## DesktopContinuationOperationJournal.list_incomplete() before run input." Exposed here for whoever
## owns application boot to call; NOT wired into any boot sequence by this task -- per the brief,
## Task 9 owns ApplicationBootstrap.gd's own stage sequence, and where exactly this hook belongs in
## it was never resolved by this task (see the handoff report).
func reconcile_incomplete_continuations() -> Dictionary:
	if _identity_issuer == null:
		return _fail(&"identity_issuer_not_configured", "configure_identity_issuer first")
	var listed: Dictionary = _continuation_journal.list_incomplete()
	if not listed.get("ok", false):
		return listed
	var results: Array = []
	for operation: Variant in (listed["value"] as Array):
		var transaction_id := str((operation as Dictionary)["transaction_id"])
		var reconciled: Dictionary = _continuation_journal.reconcile_startup(transaction_id, _identity_issuer)
		results.append({"transaction_id": transaction_id, "result": reconciled})
	return {"ok": true, "code": &"ok", "value": {"reconciled": results}}

func _delete(locator: Dictionary) -> Dictionary:
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	var relative_path := str(locator["relative_path"])
	var removed: Dictionary = _storage.remove(relative_path)
	if not removed.get("ok", false):
		return removed
	var reconciled: Dictionary = _storage.reconcile(relative_path, _document_text_validator)
	if not reconciled.get("ok", false):
		return reconciled
	if _storage.exists(relative_path):
		return _fail(&"delete_incomplete", relative_path)
	slot_metadata_changed.emit()
	return {"ok": true, "code": &"ok", "value": {"deleted": true, "relative_path": relative_path}}

func _document_text_validator(text: String) -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"invalid_json", "message": "strict parse failed"}
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": validated["value"]["candidate"]}

func _validate_checkpoint_inputs(checkpoint_inputs: Dictionary) -> String:
	var keys: Array = checkpoint_inputs.keys()
	keys.sort()
	var expected := _CHECKPOINT_INPUT_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return "unexpected checkpoint input keys: " + str(keys)
	if typeof(checkpoint_inputs["snapshot_input"]) != TYPE_DICTIONARY \
			or typeof(checkpoint_inputs["snapshot_input"].get("lifecycle")) != TYPE_DICTIONARY:
		return "snapshot_input.lifecycle is required"
	return ""

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
