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
signal live_session_ready()

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
var _new_run_profile_owner: Object = null
var _new_run_busy := false
var _new_run_gate_token := ""
# Process-local tickets survive same-operation retries; never saved in player data.
var _session_activation_tickets: Dictionary = {}
var _new_run_transaction_id := ""
var _new_run_intent: Dictionary = {}
var _prepared_new_run: Dictionary = {}
var _prepared_new_run_counter := 0
var _identity_allocation_participant: Object = null
var _lock_owner: StringName = &""
var _pending_deferred_save := false
var _restore_participants: Dictionary = {}
var _backup_actions: Dictionary = {}
var _backup_action_sequence := 0
var _backup_capture_provider: Callable
var _paused_desktop_admission: Callable
var _backup_capture_configured := false

## Bootstrap owns the live desktop source. Fixtures without this provider retain
## their explicit latest-stable contract; production never silently falls back.
func configure_backup_capture_provider(provider: Callable, paused_desktop_admission: Callable = Callable()) -> Dictionary:
	if not provider.is_valid() or provider.get_argument_count() != 0 or provider.get_object_id() == 0:
		return _fail(&"invalid_backup_capture_provider", "A bound zero-argument provider is required")
	if paused_desktop_admission.is_valid() and paused_desktop_admission.get_argument_count() != 1:
		return _fail(&"invalid_backup_capture_provider", "Paused desktop admission takes exact capture inputs")
	if _backup_capture_configured and (_backup_capture_provider != provider or _paused_desktop_admission != paused_desktop_admission):
		return _fail(&"backup_capture_already_configured", "")
	_backup_capture_provider = provider
	_paused_desktop_admission = paused_desktop_admission
	_backup_capture_configured = true
	return {"ok": true}

## The exact 9-item `DesktopContinuationOperationJournal.PARTICIPANT_ORDER` (Plan 02 Task 6,
## dwm-p2r.32, Phase C2): this array IS already the correct apply order, so a single constant now
## serves both the exact-key-set validation `configure_restore_participants()` performs and the
## apply/finalize order below (rollback runs the exact reverse). `identity_allocation` is NOT one of
## these 9 -- it is applied once, before this loop even starts, only for a restore (see
## `_begin_restore_continuation()`), through its own separately-configured seam.
const _PARTICIPANT_KEYS: Array[String] = [
	"run", "desktop_consequence", "desktop_board", "schedule_view", "profile", "localization", "audio", "route", "narrative",
]
const _PARTICIPANT_APPLY_ORDER: Array[String] = [
	"run", "desktop_consequence", "desktop_board", "schedule_view", "profile", "localization", "audio", "route", "narrative",
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
## purpose: `identity_allocation` is not one of the 9 ordinary participants (it applies once, before
## their loop, only for a restore -- new_run never touches it), so it is not folded into that
## exact-9-key validation. Duck-typed to the same prepare/capture/apply_silent/rollback_silent/
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
	gate.capability_changed.connect(_on_backup_gate_capability_changed)
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
	save_capability_changed.emit(get_save_capability())
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

## Only the confirmed session-exit owner may write under abandonment custody.
func save_session_exit_checkpoint(inputs: Dictionary, handle: Dictionary) -> Dictionary:
	if _mutation_gate == null or not _mutation_gate.is_internal_owner_active(&"session_abandonment"):
		return _fail(&"session_abandonment_required", "")
	if not _restore_participants.has("run") \
			or _restore_participants.run.capture_live_session().get("value") != handle \
			or not handle.get("active", false):
		return _fail(&"stale_live_session", "")
	var recorded := record_stable_checkpoint(inputs, &"scene_transition")
	if not recorded.get("ok", false): return recorded
	return _write_latest(_resolve_locator(&"autosave", -1), "logout", true)


func prepare_restore_slot(slot_id: int) -> Dictionary:
	return _prepare_restore(_resolve_locator(&"slot", slot_id))

func prepare_restore_quick() -> Dictionary:
	return _prepare_restore(_resolve_locator(&"quick", -1))

func prepare_restore_autosave() -> Dictionary:
	return _prepare_restore(_resolve_locator(&"autosave", -1))

## Brief line 209: `commit_prepared_restore()` accepts only the opaque value returned by
## `prepare_restore_slot|quick|autosave` above. When that value carries a `source_locator` (every
## real `_prepare_restore()` result does, Phase C2 on), this drives the FULL identity-allocation +
## remap + external-journal sequence before running the 9-participant transaction; a hand-built
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

	var has_source_locator := typeof(prepared.get("source_locator")) == TYPE_DICTIONARY
	var gate_token := ""
	var gate_acquired := false
	var lock_acquired := false
	if has_source_locator:
		# FIX (dwm-p2r.35.4 remediation, finding B-C1): the save lock and mutation-gate lease are the
		# transaction's actual anti-interleave guarantee, so both must be held BEFORE the issuer mints
		# `transaction_id` or the continuation journal commits `intent_committed` -- never after. A busy
		# gate or an already-held `restore` save lock now fails closed here, before any identity is
		# burned and before any journal record is ever written.
		var lock: Dictionary = acquire_save_lock(&"restore")
		if not lock.get("ok", false):
			return lock
		lock_acquired = true
		if _mutation_gate != null:
			var acquired: Dictionary = _mutation_gate.acquire(&"restore")
			if not acquired.get("ok", false):
				release_save_lock(&"restore")
				return acquired
			gate_token = str(acquired["value"]["token"])
			gate_acquired = true

	var continuation: Dictionary = {}
	if has_source_locator:
		var begun := _begin_restore_continuation(prepared)
		if not begun.get("ok", false):
			if gate_acquired:
				_mutation_gate.release(&"restore", gate_token)
			if lock_acquired:
				release_save_lock(&"restore")
			return begun
		var remapped_snapshot: Dictionary = (begun["value"] as Dictionary)["remapped_snapshot"]
		var run_plan: Dictionary = (plans.get("run", {}) as Dictionary).duplicate(true)
		run_plan["snapshot"] = remapped_snapshot
		plans["run"] = run_plan
		var remapped_desktop: Dictionary = remapped_snapshot["desktop"]
		var consequence_prep: Dictionary = _restore_participants["desktop_consequence"].prepare(
			{"state": remapped_desktop["consequence"]})
		if not consequence_prep.get("ok", false):
			if gate_acquired:
				_mutation_gate.release(&"restore", gate_token)
			if lock_acquired:
				release_save_lock(&"restore")
			return consequence_prep
		plans["desktop_consequence"] = (consequence_prep["value"] as Dictionary)["consequence_plan"]
		var board_prep: Dictionary = _restore_participants["desktop_board"].prepare(
			{"state": remapped_desktop["board"]})
		if not board_prep.get("ok", false):
			if gate_acquired:
				_mutation_gate.release(&"restore", gate_token)
			if lock_acquired:
				release_save_lock(&"restore")
			return board_prep
		plans["desktop_board"] = (board_prep["value"] as Dictionary)["board_plan"]
		var view_prep: Dictionary = _restore_participants["schedule_view"].prepare(_schedule_view_input(remapped_snapshot))
		if not view_prep.get("ok", false):
			if gate_acquired:
				_mutation_gate.release(&"restore", gate_token)
			if lock_acquired:
				release_save_lock(&"restore")
			return view_prep
		plans["schedule_view"] = view_prep["value"]["schedule_view_plan"]
		continuation = (begun["value"] as Dictionary)["continuation"]

	for key: String in _PARTICIPANT_KEYS:
		if typeof(plans.get(key)) != TYPE_DICTIONARY:
			if gate_acquired:
				_mutation_gate.release(&"restore", gate_token)
			if lock_acquired:
				release_save_lock(&"restore")
			return _fail(&"invalid_prepared_restore", "missing participant plan: " + key)
	return _run_participant_transaction(&"restore", plans, prepared.get("journal_seed"),
		str(prepared.get("route_id", "")), str(prepared.get("checkpoint_id", "")), true, continuation, gate_token)

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
		"new_run_materials": null,
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
				"identity_allocation_bundle": identity_candidate["identity_allocation_bundle"],
				"source_identity": _source_identity_from_lifecycle(prepared["bundle"]["snapshot"]["lifecycle"])},
		},
	}}

## PREPARE_INTENT is the durable decision. Before it, preparation is detached;
## after it, errors retain custody and retries finish the same frozen pair forward.
func configure_new_run_profile_owner(owner: Object) -> Dictionary:
	if owner == null or not is_instance_valid(owner):
		return _fail(&"invalid_new_run_profile_owner", "")
	for method: String in ["prepare_new_run_consumption", "persist_new_run_consumption", "prove_new_run_consumption", "get_profile_revision"]:
		if not owner.has_method(method):
			return _fail(&"invalid_new_run_profile_owner", method)
	if _new_run_profile_owner != null and _new_run_profile_owner != owner:
		return _fail(&"new_run_profile_owner_already_configured", "")
	_new_run_profile_owner = owner
	return {"ok": true, "code": &"ok"}

func _new_run_ready(live: bool) -> Dictionary:
	if live and _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "")
	if _identity_issuer == null:
		return _fail(&"identity_issuer_not_configured", "")
	if _storage == null or _mutation_gate == null or _new_run_profile_owner == null:
		return _fail(&"new_run_not_configured", "")
	if live and not _restore_participants["schedule_view"].has_method("prepare_new_run"):
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "schedule_view cannot prepare a new run")
	if live and not _restore_participants["profile"].has_method("prepare_frozen_profile"):
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "")
	return {"ok": true}

func _take_new_run_custody(transaction_id: String = "") -> Dictionary:
	if not _new_run_gate_token.is_empty():
		if _mutation_gate.is_fatal_latched() or not _mutation_gate.is_internal_owner_active(&"new_run") or _new_run_transaction_id != transaction_id:
			return _fail(&"new_run_recovery_conflict", "")
		return {"ok": true}
	var acquired: Dictionary = _mutation_gate.acquire(&"new_run")
	if not acquired.get("ok", false): return acquired
	_new_run_gate_token = str(acquired["value"]["token"])
	_new_run_transaction_id = transaction_id
	return {"ok": true}

func _release_new_run_custody() -> Dictionary:
	var released: Dictionary = _mutation_gate.release(&"new_run", _new_run_gate_token)
	if not released.get("ok", false): return _new_run_failure(released)
	_new_run_gate_token = ""
	_new_run_transaction_id = ""
	_new_run_intent.clear()
	return {"ok": true}

func _new_run_failure(failure: Dictionary) -> Dictionary:
	return {"ok": false, "code": &"NEW_RUN_RECOVERY_PENDING", "recovery_required": true,
		"transaction_id": _new_run_transaction_id, "details": {"cause": failure.duplicate(true)}}

## Journal loading can reconcile durable artifacts, so it needs admission even
## before the actual New Run lease is acquired. All these operations are synchronous.
func _admit_new_run_journal_io() -> Dictionary:
	if _new_run_gate_token.is_empty():
		return _mutation_gate.guard_external(&"new_run_journal")
	if _mutation_gate.is_fatal_latched():
		return _mutation_gate.guard_external(&"new_run_journal")
	if not _mutation_gate.is_internal_owner_active(&"new_run"):
		return _fail(&"new_run_recovery_conflict", "retained custody is no longer active")
	# A prepared UI commit holds the New Run lease before it checks durable
	# incompletes, but has deliberately not issued its transaction identity yet.
	if _new_run_transaction_id.is_empty() and _prepared_new_run.is_empty():
		return _fail(&"new_run_recovery_conflict", "retained custody has no operation")
	return {"ok": true}

## Freezes the exact replaceable sources for the title consent sheet. This is a
## read-only operation: it neither loads the continuation journal nor allocates
## identity, reconciles storage, or changes live run state.
func prepare_new_run_action(initial_context: Dictionary) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	var ready := _new_run_ready(true)
	if not ready.get("ok", false): return ready
	var context_error := _validate_new_run_context(initial_context)
	if not context_error.is_empty(): return _fail(&"invalid_initial_context", context_error)
	if not _new_run_transaction_id.is_empty() or not _new_run_intent.is_empty():
		return _new_run_failure(_fail(&"new_run_recovery_required", ""))
	var admitted: Dictionary = _mutation_gate.guard_external(&"new_run_prepare")
	if not admitted.get("ok", false): return admitted
	var profile: Dictionary = _new_run_profile_owner.prepare_new_run_consumption(
		_new_run_profile_owner.get_profile_revision())
	if not profile.get("ok", false): return profile
	var autosave := _capture_prepared_autosave_baseline()
	if not autosave.get("ok", false): return autosave
	var live := _capture_prepared_live_baseline()
	if not live.get("ok", false): return live
	_prepared_new_run_counter += 1
	var token := "prepared-new-run-%d-%d" % [get_instance_id(), _prepared_new_run_counter]
	_prepared_new_run = {
		"token": token,
		"initial_context": initial_context.duplicate(true),
		"profile": (profile["value"] as Dictionary).duplicate(true),
		"autosave": (autosave["value"] as Dictionary).duplicate(true),
		"live": (live["value"] as Dictionary).duplicate(true),
	}
	var replaces_live: bool = bool(_prepared_new_run["live"]["present"])
	var replaces_autosave: bool = bool(_prepared_new_run["autosave"]["occupied"])
	return {"ok": true, "code": &"ok", "value": {
		"token": token,
		"requires_confirmation": replaces_live or replaces_autosave,
		"replaces_live": replaces_live,
		"replaces_autosave": replaces_autosave,
	}}

func cancel_prepared_new_run(token: String) -> Dictionary:
	if token.is_empty() or _prepared_new_run.is_empty() or token != str(_prepared_new_run.get("token", "")):
		return _fail(&"invalid_new_run_preparation", "")
	_prepared_new_run.clear()
	return {"ok": true, "code": &"ok", "value": {"cancelled": true}}

func commit_prepared_new_run(token: String) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	if token.is_empty() or _prepared_new_run.is_empty() or token != str(_prepared_new_run.get("token", "")):
		return _fail(&"invalid_new_run_preparation", "")
	var ready := _new_run_ready(true)
	if not ready.get("ok", false): return ready
	if not _new_run_transaction_id.is_empty() or not _new_run_intent.is_empty():
		_prepared_new_run.clear()
		return _new_run_failure(_fail(&"new_run_recovery_required", ""))
	_new_run_busy = true
	var result := _commit_prepared_new_run()
	_new_run_busy = false
	return result

func _commit_prepared_new_run() -> Dictionary:
	var acquired := _take_new_run_custody()
	if not acquired.get("ok", false): return acquired
	var retained := _prepared_new_run.duplicate(true)
	var listed: Dictionary = _continuation_journal.list_incomplete()
	if not listed.get("ok", false):
		return _release_prepared_new_run_after_refusal(listed, false)
	if not listed["value"].is_empty():
		return _release_prepared_new_run_after_refusal(
			_fail(&"continuation_recovery_required", "an unresolved operation must recover before New Run"), false)
	var profile: Dictionary = _new_run_profile_owner.prepare_new_run_consumption(
		retained["profile"]["profile_revision"])
	if not profile.get("ok", false):
		if profile.get("code") in [&"profile_revision_changed", &"profile_source_changed"]:
			return _release_prepared_new_run_after_refusal(
				_fail(&"NEW_RUN_PREPARATION_STALE", "Profile changed after preparation"), true)
		return _release_prepared_new_run_after_refusal(profile, false)
	if profile["value"] != retained["profile"]:
		return _release_prepared_new_run_after_refusal(
			_fail(&"NEW_RUN_PREPARATION_STALE", "Profile changed after preparation"), true)
	var autosave := _capture_prepared_autosave_baseline()
	if not autosave.get("ok", false):
		return _release_prepared_new_run_after_refusal(autosave, false)
	if autosave["value"] != retained["autosave"]:
		return _release_prepared_new_run_after_refusal(
			_fail(&"NEW_RUN_PREPARATION_STALE", "Autosave changed after preparation"), true)
	var live := _capture_prepared_live_baseline()
	if not live.get("ok", false):
		return _release_prepared_new_run_after_refusal(live, false)
	if live["value"] != retained["live"]:
		return _release_prepared_new_run_after_refusal(
			_fail(&"NEW_RUN_PREPARATION_STALE", "Live run changed after preparation"), true)
	var prepared := _prepare_new_run_decision_from_sources(
		retained["initial_context"], retained["profile"], retained["autosave"])
	if not prepared.get("ok", false):
		return _release_prepared_new_run_after_refusal(prepared, false)
	# The next write establishes (or ambiguously may establish) the durable decision.
	# From this point recovery is by transaction id, never by replaying the UI token.
	_prepared_new_run.clear()
	return _commit_new_run_intent(prepared)

func _release_prepared_new_run_after_refusal(failure: Dictionary, consume: bool) -> Dictionary:
	if consume: _prepared_new_run.clear()
	var released := _release_new_run_custody()
	return failure if released.get("ok", false) else released

func _capture_prepared_autosave_baseline() -> Dictionary:
	var inspected: Dictionary = _storage.inspect_revision("autosave.json")
	if not inspected.get("ok", false): return inspected
	var evidence: Variant = inspected.get("value")
	if typeof(evidence) != TYPE_DICTIONARY:
		return _fail(&"invalid_autosave_revision_evidence", "")
	var source := evidence as Dictionary
	if typeof(source.get("exists")) != TYPE_BOOL or typeof(source.get("revision")) != TYPE_STRING:
		return _fail(&"invalid_autosave_revision_evidence", "")
	var text: Variant = source.get("text")
	if text != null and typeof(text) != TYPE_STRING:
		return _fail(&"invalid_autosave_revision_evidence", "")
	var occupied: bool = bool(source["exists"]) and (text == null or not str(text).is_empty())
	return {"ok": true, "code": &"ok", "value": {
		"revision": str(source["revision"]), "occupied": occupied}}

func _capture_prepared_live_baseline() -> Dictionary:
	var participant: Object = _restore_participants.get("run")
	if participant == null or not participant.has_method("get_new_run_replacement_baseline"):
		return _fail(&"new_run_replacement_unavailable", "")
	var captured: Dictionary = participant.get_new_run_replacement_baseline()
	if not captured.get("ok", false): return captured
	var value: Variant = captured.get("value")
	if typeof(value) != TYPE_DICTIONARY:
		return _fail(&"new_run_replacement_unavailable", "")
	var baseline := value as Dictionary
	var keys: Array = baseline.keys()
	keys.sort()
	if keys != ["present", "revision"] or typeof(baseline["present"]) != TYPE_BOOL \
			or typeof(baseline["revision"]) != TYPE_STRING or not _is_sha256(str(baseline["revision"])):
		return _fail(&"new_run_replacement_unavailable", "")
	return {"ok": true, "code": &"ok", "value": baseline.duplicate(true)}

func start_new_run(initial_context: Dictionary) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	var ready := _new_run_ready(true)
	if not ready.get("ok", false): return ready
	var context_error := _validate_new_run_context(initial_context)
	if not context_error.is_empty(): return _fail(&"invalid_initial_context", context_error)
	# A fresh Start cannot replace an unresolved decision or resample its preferences.
	if not _new_run_transaction_id.is_empty():
		return _new_run_failure(_fail(&"new_run_recovery_required", ""))
	# An explicit non-UI start supersedes any uncommitted title preparation.
	_prepared_new_run.clear()
	var admitted := _admit_new_run_journal_io()
	if not admitted.get("ok", false): return admitted
	var listed: Dictionary = _continuation_journal.list_incomplete()
	if not listed.get("ok", false): return listed
	if not listed["value"].is_empty():
		return _fail(&"continuation_recovery_required", "an unresolved operation must recover before New Run")
	_new_run_busy = true
	var result := _start_new_run_decision(initial_context)
	_new_run_busy = false
	return result

func _start_new_run_decision(initial_context: Dictionary) -> Dictionary:
	var acquired := _take_new_run_custody()
	if not acquired.get("ok", false): return acquired
	var prepared := _prepare_new_run_decision(initial_context)
	if not prepared.get("ok", false):
		var released := _release_new_run_custody()
		return prepared if released.get("ok", false) else released
	return _commit_new_run_intent(prepared)

func _commit_new_run_intent(prepared: Dictionary) -> Dictionary:
	_new_run_intent = prepared["value"].duplicate(true)
	_new_run_transaction_id = str(_new_run_intent["transaction_id"])
	# Even an uncertain journal write keeps the exact candidate for an explicit retry.
	var committed: Dictionary = _continuation_journal.commit_intent(_new_run_intent)
	if not committed.get("ok", false): return _new_run_failure(committed)
	_new_run_intent.clear()
	return _resume_new_run(committed["value"], _new_run_gate_token)

func retry_new_run(transaction_id: String) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	var ready := _new_run_ready(true)
	if not ready.get("ok", false): return ready
	if transaction_id.is_empty(): return _fail(&"invalid_new_run_transaction", "")
	_new_run_busy = true
	var result := _retry_new_run(transaction_id)
	_new_run_busy = false
	return result

func _retry_new_run(transaction_id: String) -> Dictionary:
	if not _new_run_transaction_id.is_empty() and transaction_id != _new_run_transaction_id:
		return _fail(&"new_run_recovery_conflict", "")
	var admitted := _admit_new_run_journal_io()
	if not admitted.get("ok", false): return admitted
	var listed: Dictionary = _continuation_journal.list_incomplete()
	if not listed.get("ok", false): return listed
	for pending: Dictionary in listed["value"]:
		if pending["kind"] != "new_run" or pending["transaction_id"] != transaction_id:
			return _fail(&"new_run_recovery_conflict", "another unresolved operation exists")
	var found: Dictionary = _continuation_journal.get_operation(transaction_id)
	if not found.get("ok", false) and _new_run_intent.is_empty(): return found
	if found.get("ok", false) and found["value"]["kind"] != "new_run":
		return _fail(&"invalid_new_run_transaction", "")
	var acquired := _take_new_run_custody(transaction_id)
	if not acquired.get("ok", false): return acquired
	if not _new_run_intent.is_empty():
		var committed: Dictionary = _continuation_journal.commit_intent(_new_run_intent)
		if not committed.get("ok", false): return _new_run_failure(committed)
		_new_run_intent.clear()
		found = committed
	return _resume_new_run(found["value"], _new_run_gate_token)

## Bootstrap invokes this before Profile.initialize: no live participant is touched.
func reconcile_new_run_storage() -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	var ready := _new_run_ready(false)
	if not ready.get("ok", false): return ready
	_new_run_busy = true
	var result := _reconcile_new_run_storage()
	_new_run_busy = false
	return result

func _reconcile_new_run_storage() -> Dictionary:
	var admitted := _admit_new_run_journal_io()
	if not admitted.get("ok", false): return admitted
	var listed: Dictionary = _continuation_journal.list_incomplete()
	if not listed.get("ok", false): return listed
	var pending: Array[Dictionary] = []
	for operation: Dictionary in listed["value"]:
		if operation["kind"] == "new_run": pending.append(operation)
	if not pending.is_empty() and listed["value"].size() != 1:
		return _fail(&"new_run_recovery_conflict", "conflicting incomplete continuations")
	var settled: Array[String] = []
	for operation: Dictionary in listed["value"]:
		if operation["kind"] != "new_run": continue
		var acquired := _take_new_run_custody(str(operation["transaction_id"]))
		if not acquired.get("ok", false): return acquired
		var result := _settle_new_run_pair(operation)
		if not result.get("ok", false): return _new_run_failure(result)
		settled.append(str(operation["transaction_id"]))
		var released := _release_new_run_custody()
		if not released.get("ok", false): return released
	return {"ok": true, "code": &"ok", "value": {"settled": settled}}

func _prepare_new_run_decision(initial_context: Dictionary) -> Dictionary:
	var profile: Dictionary = _new_run_profile_owner.prepare_new_run_consumption(_new_run_profile_owner.get_profile_revision())
	if not profile.get("ok", false): return profile
	var source: Dictionary = _storage.inspect_revision("autosave.json")
	if not source.get("ok", false): return source
	return _prepare_new_run_decision_from_sources(initial_context, profile["value"], {
		"revision": source["value"]["revision"],
		"occupied": bool(source["value"]["exists"]) and (source["value"]["text"] == null
			or not str(source["value"]["text"]).is_empty()),
	})

func _prepare_new_run_decision_from_sources(initial_context: Dictionary,
		profile_material: Dictionary, autosave_source: Dictionary) -> Dictionary:
	var issued: Dictionary = _identity_issuer.issue(&"transaction_id")
	if not issued.get("ok", false): return issued
	var transaction_id := str(issued["value"]["token"])
	var request := {"existing_run_id": null, "kind": "new_run", "remap_source_transaction_ids": [],
		"source_desktop_timeline_generation": null, "transaction_id": transaction_id,
		"transaction_issuer_receipt": issued["value"]["issuer_receipt"]}
	var allocation: Dictionary = _identity_issuer.prepare_continuation_allocation(request)
	if not allocation.get("ok", false): return allocation
	var identity: Dictionary = allocation["value"]
	var context := initial_context.duplicate(true)
	context["dark_mode"] = profile_material["captured_dark"]
	var witnessed_forms: Array[String] = []
	for form: String in profile_material["before"]["pair_form_witness_receipts"].values():
		if form not in witnessed_forms: witnessed_forms.append(form)
	witnessed_forms.sort()
	var run: Dictionary = _restore_participants["run"].prepare_new_run(
		str(identity["run_id"]), str(identity["branch_id"]), int(identity["desktop_timeline_generation"]),
		str(identity["causal_day_instance"]), identity["causal_day_instance_issuer_receipt"], context["dark_mode"], witnessed_forms)
	if not run.get("ok", false): return run
	var snapshot_input: Dictionary = run["value"]["snapshot_input"]
	var view: Dictionary = _restore_participants["schedule_view"].prepare_new_run({
		"run_id": str(identity["run_id"]), "day": 1,
		"causal_day_instance": str(identity["causal_day_instance"]),
		"causal_day_instance_issuer_receipt": identity["causal_day_instance_issuer_receipt"],
		"registry_fingerprint": snapshot_input["committed_schedule"]["registry_fingerprint"]})
	if not view.get("ok", false): return view
	snapshot_input["schedule_view"] = view["value"]["schedule_view_plan"]["candidate"]
	var audio_context := {"ambience_context": {}, "ambience_context_id": "", "music_context": {}, "music_context_id": ""}
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(snapshot_input, {}, "main", null,
		audio_context, int(context["content_version"]), 1)
	if not built.get("ok", false): return built
	var snapshot: Dictionary = built["value"]["snapshot"]
	var plans := _prepare_new_run_plans(snapshot, profile_material["candidate"])
	if not plans.get("ok", false): return plans
	var reset: Dictionary = _journal.prepare_reset_with_initial(snapshot, &"day_start")
	if not reset.get("ok", false): return reset
	var document: Dictionary = SAVE_DOCUMENT_SCHEMA.build(&"autosave", null, &"day_start",
		reset["value"]["candidate"]["current"], [], _capture_saved_time())
	if not document.get("ok", false): return document
	var serialized: Dictionary = CANONICAL_JSON.stringify(document["value"])
	if not serialized.get("ok", false): return serialized
	var outgoing := str(serialized["value"]) + "\n"
	var materials := {"allocation_candidate": identity, "profile": profile_material,
		"autosave": {"source_revision": autosave_source["revision"], "outgoing_text": outgoing,
			"outgoing_hash": outgoing.sha256_text()}}
	var fingerprint := _canonical_sha256({"kind": "new_run", "transaction_id": transaction_id,
		"initial_context": context, "new_run_materials": materials})
	return _continuation_journal.prepare_intent({"allocation_candidate_fingerprint": _canonical_sha256(identity),
		"initial_context": context, "initial_context_sha256": _canonical_sha256(context), "kind": "new_run",
		"request_fingerprint": fingerprint, "source_locator": null, "transaction_id": transaction_id,
		"transaction_issuer_receipt": issued["value"]["issuer_receipt"], "new_run_materials": materials})

func _prepare_new_run_plans(snapshot: Dictionary, profile_candidate: Dictionary) -> Dictionary:
	var profile: Dictionary = _restore_participants["profile"].prepare_frozen_profile(profile_candidate)
	if not profile.get("ok", false): return profile
	var inputs := {"run": {"snapshot": snapshot},
		"desktop_consequence": {"state": snapshot["desktop"]["consequence"]},
		"desktop_board": {"state": snapshot["desktop"]["board"]},
		"schedule_view": _schedule_view_input(snapshot),
		"localization": {"locale_id": str(profile["value"]["locale_id"])},
		"audio": {"preferences": profile_candidate["preferences"], "audio_context": snapshot["audio_context"]},
		"route": {"route_id": "main", "route_context": {}, "active_app_id": null, "day": 1}}
	var plan_keys := {"run": "run_plan", "desktop_consequence": "consequence_plan",
		"desktop_board": "board_plan", "schedule_view": "schedule_view_plan", "localization": "localization_plan", "audio": "audio_plan", "route": "route_plan"}
	var plans := {"profile": profile["value"]["profile_plan"], "narrative": {"narrative_checkpoint": {}}}
	for key: String in inputs:
		var prepared: Dictionary = _restore_participants[key].prepare(inputs[key])
		if not prepared.get("ok", false): return prepared
		plans[key] = prepared["value"][plan_keys[key]]
	return {"ok": true, "value": plans}

func _advance_new_run(operation: Dictionary, next_stage: String, allocation: Variant = null) -> Dictionary:
	return _continuation_journal.advance({"transaction_id": operation["transaction_id"],
		"request_fingerprint": operation["request_fingerprint"], "expected_stage": operation["stage"],
		"next_stage": next_stage, "expected_next_participant_index": operation["next_participant_index"],
		"allocation_receipt": allocation, "participant_name": null, "participant_receipt": null, "failure": null})

func _record_new_run_target(operation: Dictionary, target: StringName, revision: String) -> Dictionary:
	if operation["stage"] != CONTINUATION_JOURNAL.STAGE_ALLOCATED:
		return {"ok": true, "value": operation}
	return _continuation_journal.record_new_run_target(str(operation["transaction_id"]),
		str(operation["request_fingerprint"]), target, revision)

func _settle_new_run_pair(operation: Dictionary) -> Dictionary:
	if not _identity_issuer.has_method("verify_issued"):
		return _fail(&"invalid_identity_issuer", "verify_issued is required for recovery")
	var verified: Dictionary = _continuation_journal.reconcile_startup(str(operation["transaction_id"]), _identity_issuer)
	if not verified.get("ok", false): return verified
	var refreshed: Dictionary = _continuation_journal.get_operation(str(operation["transaction_id"]))
	if not refreshed.get("ok", false): return refreshed
	operation = refreshed["value"]
	var materials: Dictionary = operation["new_run_materials"]
	var candidate: Dictionary = materials["allocation_candidate"]
	var prepared: Dictionary = _identity_issuer.prepare_continuation_allocation(candidate["request"])
	if not prepared.get("ok", false): return prepared
	if _canonical_sha256(prepared["value"]) != str(operation["allocation_candidate_fingerprint"]):
		return _fail(&"allocation_candidate_fingerprint_mismatch", "")
	var committed: Dictionary = _identity_issuer.commit_continuation_allocation(candidate)
	if not committed.get("ok", false): return committed
	if _canonical_sha256(committed["value"]) != str(operation["allocation_candidate_fingerprint"]):
		return _fail(&"allocation_candidate_fingerprint_mismatch", "")
	if operation["stage"] == CONTINUATION_JOURNAL.STAGE_INTENT:
		var allocated := _advance_new_run(operation, CONTINUATION_JOURNAL.STAGE_ALLOCATED, committed["value"])
		if not allocated.get("ok", false): return allocated
		operation = allocated["value"]
	var identity := _record_new_run_target(operation, &"identity", str(operation["allocation_candidate_fingerprint"]))
	if not identity.get("ok", false): return identity
	operation = identity["value"]
	var autosave := _persist_new_run_autosave(materials["autosave"])
	if not autosave.get("ok", false): return autosave
	var saved := _record_new_run_target(operation, &"autosave", str(materials["autosave"]["outgoing_hash"]))
	if not saved.get("ok", false): return saved
	operation = saved["value"]
	# A fresh process may already have initialized Profile from the consumed target.
	# Proof is independent of the former live revision; persistence still requires it.
	var profile: Dictionary = _new_run_profile_owner.prove_new_run_consumption(materials["profile"])
	if not profile.get("ok", false):
		profile = _new_run_profile_owner.persist_new_run_consumption(materials["profile"])
		if not profile.get("ok", false): return profile
	profile = _new_run_profile_owner.prove_new_run_consumption(materials["profile"])
	if not profile.get("ok", false): return profile
	autosave = _prove_new_run_autosave(materials["autosave"])
	if not autosave.get("ok", false): return autosave
	return _record_new_run_target(operation, &"profile", str(materials["profile"]["outgoing_hash"]))

func _prove_new_run_autosave(material: Dictionary) -> Dictionary:
	var inspected: Dictionary = _storage.inspect_revision("autosave.json")
	if not inspected.get("ok", false): return inspected
	if inspected["value"].get("revision") != material["outgoing_hash"] or inspected["value"].get("text") != material["outgoing_text"]:
		return _fail(&"new_run_autosave_unproven", "")
	return {"ok": true, "value": {"outgoing_hash": material["outgoing_hash"]}}

func _persist_new_run_autosave(material: Dictionary) -> Dictionary:
	var inspected: Dictionary = _storage.inspect_revision("autosave.json")
	if not inspected.get("ok", false) and inspected.get("code") == &"reconcile_required":
		# Never reconcile another operation's pending file family.
		var marker_read: Dictionary = _storage.inspect_revision("autosave.json.txn.json")
		if not marker_read.get("ok", false) or not marker_read["value"].get("exists", false):
			return _fail(&"new_run_autosave_foreign_pending", "")
		var parsed: Dictionary = STRICT_JSON.parse_object(str(marker_read["value"]["text"]))
		if not parsed.get("ok", false): return _fail(&"new_run_autosave_foreign_pending", "")
		var marker: Dictionary = parsed["value"]
		var prior: Variant = null if material["source_revision"] == "absent" else material["source_revision"]
		if marker.get("schema_version") != 2 or marker.get("operation") != "write_revision" \
				or marker.get("relative_path") != "autosave.json" or marker.get("previous_hash") != prior \
				or marker.get("outgoing_hash") != material["outgoing_hash"]:
			return _fail(&"new_run_autosave_foreign_pending", "")
		var reconciled: Dictionary = _storage.reconcile("autosave.json", _document_text_validator)
		if not reconciled.get("ok", false) and reconciled.get("code") != &"write_not_committed": return reconciled
		inspected = _storage.inspect_revision("autosave.json")
	if not inspected.get("ok", false): return inspected
	if inspected["value"].get("revision") == material["outgoing_hash"] and inspected["value"].get("text") == material["outgoing_text"]:
		return _prove_new_run_autosave(material)
	if inspected["value"].get("revision") != material["source_revision"]:
		return _fail(&"new_run_autosave_source_changed", "")
	var written: Dictionary = _storage.write_atomic_if_revision("autosave.json", material["outgoing_text"],
		_document_text_validator, material["source_revision"])
	if not written.get("ok", false): return written
	return _prove_new_run_autosave(material)

## `continuation` (Plan 02 Task 6, dwm-p2r.32, Phase C2), when non-empty, is `{transaction_id,
## request_fingerprint, remap: {restore_transaction_id, identity_allocation_bundle} | absent}` --
## produced by `_begin_restore_continuation()` above. Empty means a
## caller supplied a hand-built `prepared`/`plans` with no external-journal identity to advance (the
## pure fake-participant orchestration tests): this method then behaves exactly as it did before
## Task 6. When present, this drives `DesktopContinuationOperationJournal.advance()` for every
## participant position PLUS the run-identity remap step, right after "run"'s own ordinary apply.
## `pre_acquired_gate_token` (dwm-p2r.35.4 remediation, finding B-C1): when nonempty, the caller
## already holds the `owner` lease (acquired before minting `transaction_id`/committing
## `intent_committed`, per the frozen continuation law) and this method must NOT try to acquire it
## again (the gate is exclusive/non-reentrant). Empty means the caller never pre-acquired -- the
## pure fake-participant orchestration path this method already supported before Task 6 -- so this
## method acquires it itself, exactly as before.
## `already_applied` (dwm-p2r.35.4 remediation, finding B-C2): true only when resuming an operation
## whose journal record is ALREADY at `participants_applied` (every participant already durably
## recorded before the crash). The journal's own per-participant replay path only accepts a replay
## while the operation's stage is still `participants_applying` -- once it has moved past that to
## `participants_applied`, resubmitting an index-N `advance()` call is correctly refused as
## `illegal_stage`, not silently replayed. So a resume from `participants_applied` still needs every
## participant's `apply_silent()` called (a fresh process's live participants start empty/default and
## must be genuinely re-applied), but must skip the per-participant and to-`participants_applied`
## `advance()` calls entirely -- there is nothing left for either to legitimately record.
func _run_participant_transaction(
		owner: StringName, plans: Dictionary, journal_candidate: Variant,
		route_id: String, checkpoint_id: String, emit_restored: bool, continuation: Dictionary = {},
		pre_acquired_gate_token: String = "", already_applied: bool = false
) -> Dictionary:
	# `restore` also holds the SaveManager save lock; `new_run` relies on the gate.
	# acquire_save_lock() is idempotent for an already-held `restore` lock, so this is safe to call
	# again even when the caller pre-acquired the lock itself before this transaction began.
	var holds_save_lock := owner == &"restore"
	if holds_save_lock:
		var lock: Dictionary = acquire_save_lock(&"restore")
		if not lock.get("ok", false):
			return lock
	var gate_token := pre_acquired_gate_token
	if gate_token == "" and _mutation_gate != null:
		var acquired: Dictionary = _mutation_gate.acquire(owner)
		if not acquired.get("ok", false):
			if holds_save_lock:
				release_save_lock(&"restore")
			return acquired
		gate_token = str(acquired["value"]["token"])

	var operation_id := str(continuation.get("transaction_id", gate_token))
	var activation := _prepare_live_session_activation(plans, operation_id)
	if not activation.get("ok", false):
		_release_transaction(owner, gate_token, holds_save_lock)
		return activation
	var activation_ticket: Dictionary = activation["value"]

	var journal_backup: Variant = null
	if typeof(journal_candidate) == TYPE_DICTIONARY:
		var captured_journal: Dictionary = _journal.capture_state()
		if not captured_journal.get("ok", false):
			_release_transaction(owner, gate_token, holds_save_lock)
			return captured_journal
		journal_backup = captured_journal["value"]["backup"]

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
				str(remap_info["restore_transaction_id"]), remap_info["identity_allocation_bundle"],
				remap_info["source_identity"])
			if not remapped.get("ok", false):
				applied.append(key)
				return _rollback_transaction(owner, applied, backups, gate_token, holds_save_lock, remapped)
		applied.append(key)
		if key == "route":
			route_ready_token = (result.get("value", {}) as Dictionary).get("route_ready_token")
		if not continuation.is_empty() and not already_applied:
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

	if not continuation.is_empty() and not already_applied:
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

	# Route dispatch queues a physical scene change that rollback cannot cancel.
	# Finish every other fallible participant before requesting that change.
	var finalize_order := _PARTICIPANT_APPLY_ORDER.duplicate()
	finalize_order.erase("route")
	finalize_order.append("route")
	for key: String in finalize_order:
		if key == "route" and not activation_ticket.is_empty():
			var validated: Dictionary = _restore_participants["run"].validate_live_session_activation(activation_ticket)
			if not validated.get("ok", false):
				return _rollback_transaction(owner, applied, backups, gate_token, holds_save_lock, validated, journal_backup)
		var finalized: Dictionary = _restore_participants[key].finalize()
		if not finalized.get("ok", false):
			return _rollback_transaction(owner, applied, backups, gate_token, holds_save_lock, finalized, journal_backup)
	if not activation_ticket.is_empty():
		var activated: Dictionary = _restore_participants["run"].activate_live_session(activation_ticket)
		if not activated.get("ok", false):
			# The route has dispatched: compensating the previous run is no longer safe.
			return _fatal_transaction_recovery(String(owner), [{"owner_id": "run",
				"operation": "activate_live_session", "result": activated}])
	_release_transaction(owner, gate_token, holds_save_lock)
	if not continuation.is_empty():
		# Best-effort: participants are already finalized and the checkpoint journal already
		# committed, so a failure here is NOT rolled back (that would undo genuinely-completed work).
		# FIX (dwm-p2r.35.4 remediation, finding B-C2/B-C3): this advance's own failure is no longer a
		# dead end. `reconcile_incomplete_continuations()` -> `_resume_operation()` finds this
		# transaction still nonterminal on the next boot (stage stays `participants_applied`), reacquires
		# the `owner` lease, and drives this exact APPLIED -> COMPLETED advance forward through
		# `_resume_new_run()`/`_resume_restore()` -- see those methods below.
		var completed: Dictionary = _continuation_journal.advance({
			"transaction_id": continuation["transaction_id"], "request_fingerprint": continuation["request_fingerprint"],
			"expected_stage": CONTINUATION_JOURNAL.STAGE_APPLIED, "next_stage": CONTINUATION_JOURNAL.STAGE_COMPLETED,
			"expected_next_participant_index": _PARTICIPANT_APPLY_ORDER.size(), "allocation_receipt": null,
			"participant_name": null, "participant_receipt": null, "failure": null,
		})
		if completed.get("ok", false):
			_session_activation_tickets.erase(operation_id)
	else:
		_session_activation_tickets.erase(operation_id)
	if not activation_ticket.is_empty(): live_session_ready.emit()
	if emit_restored:
		run_restored.emit(checkpoint_id, route_id)
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": checkpoint_id, "route_id": route_id}}


func _validate_new_run_context(initial_context: Dictionary) -> String:
	var keys: Array = initial_context.keys()
	keys.sort()
	if keys != ["active_app_id", "audio_context", "content_version", "dialogic_checkpoint", "route_id"]:
		return "unexpected initial_context keys: " + str(keys)
	if typeof(initial_context["route_id"]) != TYPE_STRING or initial_context["route_id"] != "main":
		return "route_id must be \"main\""
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

func _rollback_transaction(owner: StringName, applied: Array[String], backups: Dictionary, gate_token: String, holds_save_lock: bool, original_failure: Dictionary, journal_backup: Variant = null) -> Dictionary:
	var attempts: Array = []
	var all_recovered := true
	# The checkpoint commits after participant apply, so compensate it first.
	# Only post-commit failures supply this backup; earlier refusals leave it alone.
	if typeof(journal_backup) == TYPE_DICTIONARY:
		var journal_rolled: Dictionary = _journal.restore_state(journal_backup)
		attempts.append({"owner_id": "checkpoint_journal", "operation": "restore_state", "result": journal_rolled})
		if not journal_rolled.get("ok", false):
			all_recovered = false
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

## Read-only Backup projection. Revision is custody evidence, never UI copy or save validity.
func inspect_backup(locator_id: String) -> Dictionary:
	var inspected := _inspect_backup(locator_id)
	if inspected.get("ok", false):
		inspected["value"].erase("prepared_restore")
	return inspected

func get_backup_save_capability() -> Dictionary:
	var allowed := _backup_guard()
	if not allowed.get("ok", false):
		return {"enabled": false, "reason": str(allowed.get("code", "unavailable"))}
	if not get_latest_stable_checkpoint().get("ok", false):
		return {"enabled": false, "reason": "no_stable_checkpoint"}
	if _backup_capture_configured:
		var captured := _capture_backup_inputs()
		if not captured.get("ok", false):
			return {"enabled": false, "reason": str(captured.get("code", "backup_capture_unavailable"))}
	return {"enabled": true, "reason": ""}

## Quick commands share Backup tokens but cannot silently overwrite an unproved target.
## Conditions are opaque, detached evidence; they are never display copy or save data.
func get_backup_quick_capability(action: String) -> Dictionary:
	if action not in ["save", "load"]:
		return {"ok": false, "code": &"invalid_backup_action", "status_key": "unavailable", "condition": {}}
	var condition := _quick_condition(action)
	var enabled := false
	var status := _quick_guard_status(action)
	if status == "":
		var stable := get_latest_stable_checkpoint()
		var inspected := _inspect_backup("quick")
		if stable.get("ok", false) and inspected.get("ok", false):
			var record: Dictionary = inspected["value"]
			if action == "load":
				enabled = record.get("loadable", false)
			else:
				enabled = get_backup_save_capability().get("enabled", false) and _quick_save_record_allowed(record)
		if not enabled or not is_quick_condition_current(condition):
			enabled = false
			status = "unavailable"
	return {"ok": true, "value": {"enabled": enabled, "status_key": status, "condition": condition}}

func prepare_quick_backup_action(action: String) -> Dictionary:
	var capability := get_backup_quick_capability(action)
	if not capability.get("ok", false):
		return capability
	var value: Dictionary = capability["value"]
	if not value["enabled"]:
		return _quick_failure(action, value["status_key"])
	var condition: Dictionary = value["condition"]
	var prepared := prepare_backup_action(action, "quick")
	if not prepared.get("ok", false):
		return _quick_failure(action)
	var token: String = prepared["value"]["token"]
	if not is_quick_condition_current(condition) or (action == "save" and not _quick_save_record_allowed(prepared["value"]["record"])):
		cancel_backup_action(token)
		return _quick_failure(action)
	_backup_actions[token]["quick_condition"] = condition.duplicate(true)
	prepared["value"]["condition"] = condition.duplicate(true)
	return prepared

func is_quick_condition_current(condition: Dictionary) -> bool:
	if condition.size() != 2 or typeof(condition.get("action")) != TYPE_STRING or condition.get("action") not in ["save", "load"] \
			or typeof(condition.get("signature")) != TYPE_STRING or condition["signature"].is_empty():
		return false
	return condition == _quick_condition(condition["action"])

func _quick_condition(action: String) -> Dictionary:
	var stable := get_latest_stable_checkpoint()
	var captured := _capture_backup_inputs() if _backup_capture_configured else {"ok": false, "code": &"not_configured"}
	var target: Dictionary = {"ok": false, "code": &"not_initialized"}
	if _storage != null:
		target = _storage.inspect_revision(str(_backup_locator("quick")["relative_path"]))
	var evidence := {
		"owner": str(get_instance_id()), "action": action,
		"stable": _canonical_sha256(stable["value"]["bundle"]) if stable.get("ok", false) else "",
		"capture": _canonical_sha256(captured["value"]) if captured.get("ok", false) else str(captured.get("code", "unavailable")),
		"target": target["value"]["revision"] if target.get("ok", false) else str(target.get("code", "unavailable")),
		"lock": str(_lock_owner),
		"gate_owner": str(_mutation_gate.get_active_owner()) if _mutation_gate != null else "",
		"fatal": _mutation_gate.is_fatal_latched() if _mutation_gate != null else false,
	}
	return {"action": action, "signature": _canonical_sha256(evidence)}

func _quick_guard_status(action: String) -> String:
	if _storage == null or (_mutation_gate != null and _mutation_gate.is_fatal_latched()):
		return "unavailable"
	if is_save_locked() or (_mutation_gate != null and _mutation_gate.is_active()):
		return "please_wait" if action == "load" else "unavailable"
	return "" if _backup_guard().get("ok", false) else "unavailable"

func _quick_failure(action: String, status: String = "") -> Dictionary:
	if status == "":
		status = _quick_guard_status(action)
	return {"ok": false, "code": &"backup_action_unavailable",
		"status_key": "unavailable" if status == "" else status, "condition": _quick_condition(action)}

static func _quick_save_record_allowed(record: Dictionary) -> bool:
	return record.get("state") in ["empty", "occupied"] and not record.get("fallback", false) and record.get("reason", "") == ""

func _on_backup_gate_capability_changed(_capability: Dictionary) -> void:
	save_capability_changed.emit(get_backup_save_capability())

func _inspect_backup(locator_id: String) -> Dictionary:
	var locator := _backup_locator(locator_id)
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	var inspected: Dictionary = _storage.inspect_revision(str(locator["relative_path"]))
	if not inspected.get("ok", false):
		return inspected
	var evidence: Dictionary = inspected["value"]
	var record := {"locator": locator_id, "revision": evidence["revision"],
		"state": "empty" if not evidence["exists"] else "unavailable", "day": null,
		"saved_time": null, "fallback": false, "load_day": null, "load_saved_time": null,
		"reason": "", "loadable": false, "operation_allowed": _backup_guard().get("ok", false)}
	if not evidence["exists"]:
		return {"ok": true, "value": record}
	if typeof(evidence.get("text")) != TYPE_STRING:
		record["reason"] = "unreadable"
		return {"ok": true, "value": record}
	var parsed := STRICT_JSON.parse_object(evidence["text"])
	if not parsed.get("ok", false):
		record["reason"] = "unreadable"
		return {"ok": true, "value": record}
	# The legacy migrator reconstructs outer keys. Validate the actual outer evidence first;
	# otherwise a future version/wrong locator or false time could be silently relabeled.
	var valid := SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not valid.get("ok", false):
		var version: Variant = parsed["value"].get("schema_version")
		record["reason"] = "unreadable"
		if typeof(version) == TYPE_INT and version > 0:
			if version > SAVE_DOCUMENT_SCHEMA.DOCUMENT_VERSION: record["reason"] = "newer_version"
			elif version < SAVE_DOCUMENT_SCHEMA.DOCUMENT_VERSION: record["reason"] = "older_version"
		return {"ok": true, "value": record}
	var document: Dictionary = valid["value"]["candidate"]
	var migrated := SAVE_MIGRATIONS.migrate_document(parsed["value"],
		{"kind": locator["kind"], "slot_id": locator["slot_id"]})
	if not migrated.get("ok", false):
		record["reason"] = "unreadable"
		return {"ok": true, "value": record}
	if document["kind"] != locator["kind"] or document["slot_id"] != locator["slot_id"]:
		record["reason"] = "unreadable"
		return {"ok": true, "value": record}
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	record["state"] = "occupied"
	record["day"] = int(snapshot["lifecycle"]["day"])
	record["saved_time"] = document.get("saved_time", {}).get("hhmm")
	var prepared := _prepare_restore_document(locator, document, migrated["value"])
	if prepared.get("ok", false):
		var target: Dictionary = prepared["value"]["prepared"]
		record["loadable"] = true
		record["fallback"] = str(target["checkpoint_id"]) != str(snapshot["checkpoint_id"])
		record["load_day"] = int(target["bundle"]["snapshot"]["lifecycle"]["day"])
		record["load_saved_time"] = null if record["fallback"] else record["saved_time"]
		record["prepared_restore"] = target
	else:
		record["reason"] = "no_compatible_checkpoint" if prepared.get("code") == &"NO_COMPATIBLE_BUNDLE" else "restore_unavailable"
		if prepared.get("code") != &"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED":
			record["state"] = "unavailable"
			record["day"] = null
			record["saved_time"] = null
	return {"ok": true, "value": record}

## Detached candidates remain owner-private; tokens convey consent to exactly one candidate.
func prepare_backup_action(action: String, locator_id: String) -> Dictionary:
	if action not in ["save", "load", "delete"]:
		return _fail(&"invalid_backup_action", "")
	var guard := _backup_guard()
	if not guard.get("ok", false):
		return guard
	var inspected := _inspect_backup(locator_id)
	if not inspected.get("ok", false):
		return inspected
	var record: Dictionary = inspected["value"]
	var locator := _backup_locator(locator_id)
	var candidate := {"action": action, "locator": locator, "revision": record["revision"]}
	if action == "save":
		if locator_id == "autosave":
			return _fail(&"automatic_save_only", "")
		var stable := get_latest_stable_checkpoint()
		if not stable.get("ok", false):
			return _fail(&"no_stable_checkpoint", "")
		var bundle: Dictionary = stable["value"]["bundle"]
		var earlier: Array = _journal.get_bundles_for_disk()
		if _backup_capture_configured:
			var fresh := _prepare_backup_capture()
			if not fresh.get("ok", false):
				return fresh
			candidate.merge(fresh["value"])
			bundle = candidate["journal_candidate"]["current"]
			earlier = candidate["journal_candidate"]["earlier"]
		var built := SAVE_DOCUMENT_SCHEMA.build(StringName(locator["kind"]), locator["slot_id"],
			&"quick" if locator_id == "quick" else &"manual", bundle, earlier, _capture_saved_time())
		if not built.get("ok", false):
			return built
		candidate["document"] = built["value"]
		candidate["stable_hash"] = _canonical_sha256(stable["value"]["bundle"])
	elif action == "load":
		if not record["loadable"]:
			return _fail(&"backup_load_unavailable", "")
		candidate["prepared_restore"] = record["prepared_restore"]
	elif record["state"] == "empty":
		return _fail(&"save_absent", "")
	record.erase("prepared_restore")
	_backup_action_sequence += 1
	var token := "backup-%d" % _backup_action_sequence
	_backup_actions[token] = candidate.duplicate(true)
	return {"ok": true, "value": {"token": token, "record": record}}

func cancel_backup_action(token: String) -> void:
	_backup_actions.erase(token)

func commit_backup_action(token: String) -> Dictionary:
	if not _backup_actions.has(token):
		return _fail(&"stale_backup_action", "")
	var candidate: Dictionary = _backup_actions[token]
	# Every result consumes consent; retries require a fresh prepare and confirmation.
	_backup_actions.erase(token)
	var guard := _backup_guard()
	if not guard.get("ok", false):
		return guard
	if candidate.has("quick_condition") and not is_quick_condition_current(candidate["quick_condition"]):
		return _fail(&"stale_backup_source", "")
	var locator: Dictionary = candidate["locator"]
	var path := str(locator["relative_path"])
	var current: Dictionary = _storage.inspect_revision(path)
	if not current.get("ok", false):
		return current
	if current["value"]["revision"] != candidate["revision"]:
		return _fail(&"stale_backup_target", "")
	match str(candidate["action"]):
		"load":
			var reconciled: Dictionary = _storage.reconcile(path, _document_text_validator)
			if not reconciled.get("ok", false):
				return reconciled
			current = _storage.inspect_revision(path)
			if not current.get("ok", false) or current["value"]["revision"] != candidate["revision"]:
				return _fail(&"stale_backup_target", "")
			return commit_prepared_restore(candidate["prepared_restore"])
		"delete":
			var removed: Dictionary = _storage.remove_if_revision(path, candidate["revision"])
			if removed.get("ok", false):
				slot_metadata_changed.emit()
			return removed
		"save":
			var stable := get_latest_stable_checkpoint()
			if not stable.get("ok", false) or _canonical_sha256(stable["value"]["bundle"]) != candidate["stable_hash"]:
				return _fail(&"stale_backup_source", "")
			if candidate.has("journal_candidate"):
				var captured := _capture_backup_inputs()
				if not captured.get("ok", false):
					return captured
				if _canonical_sha256(captured["value"]) != candidate["capture_hash"] or _backup_journal_hash() != candidate["journal_hash"]:
					return _fail(&"stale_backup_source", "")
			var canonical := CANONICAL_JSON.stringify(candidate["document"])
			if not canonical.get("ok", false):
				return canonical
			var bytes := str(canonical["value"]) + "\n"
			var written: Dictionary = _storage.write_atomic_if_revision(path, bytes, _document_text_validator, candidate["revision"])
			if not written.get("ok", false):
				save_failed.emit(written)
				return written
			var read: Dictionary = _storage.read_text(path)
			if not read.get("ok", false) or str(read["value"]) != bytes:
				return _fail(&"reread_mismatch", "")
			if candidate.has("journal_candidate"):
				if _backup_journal_hash() != candidate["journal_hash"]:
					return _fail(&"backup_journal_changed_after_write", "Durable save remains available; journal was not overwritten")
				var advanced: Dictionary = _journal.commit_prepared(candidate["journal_candidate"])
				if not advanced.get("ok", false):
					return _fail(&"backup_journal_commit_failed", "Durable save remains available; checkpoint publication failed")
			var result := {"ok": true, "value": {"written": true}}
			save_completed.emit(result)
			slot_metadata_changed.emit()
			return result
	return _fail(&"invalid_backup_action", "")

func _capture_backup_inputs() -> Dictionary:
	if not _backup_capture_provider.is_valid():
		return _fail(&"backup_capture_unavailable", "Configured source is no longer available")
	var raw: Variant = _backup_capture_provider.call()
	if not raw is Dictionary:
		return _fail(&"invalid_backup_capture", "Capture provider must return a result")
	if not raw.get("ok", false):
		return raw.duplicate(true)
	if not raw.get("value") is Dictionary:
		return _fail(&"invalid_backup_capture", "Capture inputs are required")
	var inputs: Dictionary = raw["value"].duplicate(true)
	var shape_error := _validate_checkpoint_inputs(inputs)
	if shape_error != "":
		return _fail(&"invalid_backup_capture", shape_error)
	if not inputs["dialogic_checkpoint"] is Dictionary or not inputs["audio_context"] is Dictionary \
			or typeof(inputs["route_id"]) not in [TYPE_STRING, TYPE_STRING_NAME] \
			or typeof(inputs["active_app_id"]) not in [TYPE_NIL, TYPE_STRING, TYPE_STRING_NAME] \
			or not inputs["content_version"] is int:
		return _fail(&"invalid_backup_capture", "Capture context types are invalid")
	inputs["route_id"] = str(inputs["route_id"])
	if inputs["active_app_id"] != null:
		inputs["active_app_id"] = str(inputs["active_app_id"])
	var desktop: bool = inputs["route_id"] == "main" and inputs["active_app_id"] == "backup"
	if inputs["route_id"] == "main" and not desktop and _paused_desktop_admission.is_valid():
		# The retained Pause owner rechecks this exact suspended source. Never relabel its app.
		var paused_admission: Variant = _paused_desktop_admission.call(inputs.duplicate(true))
		desktop = typeof(paused_admission) == TYPE_BOOL and paused_admission
	var gameplay: Variant = inputs["snapshot_input"].get("gameplay")
	var route_context: Variant = gameplay.get("route_context") if gameplay is Dictionary else null
	var dating_record: Variant = route_context.get("active_dating_challenge") if route_context is Dictionary else null
	var dating: bool = inputs["route_id"] == "dating" and dating_record is Dictionary \
		and not dating_record.is_empty() and dating_record.get("phase") in ["pre_challenge", "preparing", "challenge", "cleared_awaiting_terminal_choice", "post_challenge"]
	if not (desktop or dating) or not inputs["dialogic_checkpoint"].is_empty() or inputs["snapshot_input"]["lifecycle"].get("state") != "PLAYING":
		return _fail(&"backup_capture_unavailable", "A qualified desktop or paused Dating capture is required")
	return {"ok": true, "value": inputs}

func _backup_journal_hash() -> String:
	return _canonical_sha256(_journal.capture_state()["value"]["backup"])

func _prepare_backup_capture() -> Dictionary:
	var journal_hash := _backup_journal_hash()
	var captured := _capture_backup_inputs()
	if not captured.get("ok", false):
		return captured
	var inputs: Dictionary = captured["value"]
	var run_id := str(inputs["snapshot_input"]["lifecycle"].get("run_id", ""))
	var sequence: Dictionary = _journal.peek_next_sequence(run_id)
	if not sequence.get("ok", false):
		return sequence
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(inputs["snapshot_input"], inputs["dialogic_checkpoint"],
		inputs["route_id"], inputs["active_app_id"], inputs["audio_context"], inputs["content_version"], sequence["value"]["checkpoint_sequence"])
	if not built.get("ok", false):
		return built
	var prepared: Dictionary = _journal.prepare_record(built["value"]["snapshot"], &"manual_save")
	if not prepared.get("ok", false):
		return prepared
	if _backup_journal_hash() != journal_hash:
		return _fail(&"stale_backup_source", "Journal changed during capture")
	return {"ok": true, "value": {"journal_candidate": prepared["value"]["candidate"],
		"capture_hash": _canonical_sha256(inputs), "journal_hash": journal_hash}}

func _backup_guard() -> Dictionary:
	if _storage == null:
		return _fail(&"not_initialized", "")
	if is_save_locked():
		return _fail(&"save_locked", "")
	if _mutation_gate != null:
		return _mutation_gate.guard_external(&"backup")
	return {"ok": true}

func _backup_locator(locator_id: String) -> Dictionary:
	if locator_id not in ["autosave", "quick", "slot:1", "slot:2", "slot:3", "slot:4", "slot:5", "slot:6", "slot:7"]:
		return {}
	return _resolve_locator_from_slot_id(locator_id)

func _capture_saved_time() -> Dictionary:
	var instant := int(Time.get_unix_time_from_system())
	var offset := int(Time.get_time_zone_from_system()["bias"])
	var clock := Time.get_datetime_dict_from_unix_time(instant + offset * 60)
	return {"unix_seconds": instant, "utc_offset_minutes": offset,
		"hhmm": "%02d:%02d" % [clock["hour"], clock["minute"]]}

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
	if _mutation_gate != null and not _mutation_gate.guard_external(&"save_write").get("ok", false):
		return {"enabled": false, "silent": true, "deferred": false}
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
		return _fail(&"invalid_restore_participants", "exactly nine participants required: " + str(keys))
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

func _write_latest(locator: Dictionary, save_reason: String, session_exit: bool = false) -> Dictionary:
	if session_exit and (_mutation_gate == null or not _mutation_gate.is_internal_owner_active(&"session_abandonment")):
		return _fail(&"session_abandonment_required", "")
	if _mutation_gate != null and not session_exit:
		var admitted: Dictionary = _mutation_gate.guard_external(&"save_write")
		if not admitted.get("ok", false): return admitted
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
		bundle["value"]["bundle"], _journal.get_bundles_for_disk(), _capture_saved_time())
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
	if _canonical_sha256(document) != _canonical_sha256(built["value"]):
		return _fail(&"reread_mismatch", "saved candidate drift")
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
	return _prepare_restore_document(locator, document, migrated["value"])

## Pure shared preparation: Backup inspections do not reconcile files or acquire leases.
func _prepare_restore_document(locator: Dictionary, document: Dictionary, migration_output: Dictionary) -> Dictionary:
	if _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "")

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
		var prepared := _prepare_bundle_with_all_participants(bundle, migration_output, document, locator)
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
	var view_prep: Dictionary = _restore_participants["schedule_view"].prepare(_schedule_view_input(snapshot))
	if not view_prep.get("ok", false):
		return view_prep
	plans["schedule_view"] = view_prep["value"]["schedule_view_plan"]

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

static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true

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
##
## FIX (dwm-p2r.35.4 remediation, findings B-C2/B-C3): each nonterminal operation now goes through
## `_resume_operation()` below, which genuinely drives the frozen continuation law's recovery
## sequence -- reacquiring the gate lease, verifying the source/context, and advancing forward
## through allocation/participants/completion (or recording a pre-allocation abort) -- instead of
## merely calling the journal's own `reconcile_startup()` and reporting whatever it said. This
## method's own outer envelope is unchanged (`{"ok": true, "value": {"reconciled": [...]}}`): a
## per-operation resume outcome (completed/aborted/fatal_latched/already_terminal) is never treated
## as a reason to fail the whole reconciliation pass, since one operation's fatal must not stop the
## next incomplete operation from being examined.
func reconcile_incomplete_continuations() -> Dictionary:
	if _mutation_gate != null:
		var admitted := _admit_new_run_journal_io()
		if not admitted.get("ok", false): return admitted
	if _identity_issuer == null:
		return _fail(&"identity_issuer_not_configured", "configure_identity_issuer first")
	var listed: Dictionary = _continuation_journal.list_incomplete()
	if not listed.get("ok", false):
		return listed
	var results: Array = []
	for operation: Variant in (listed["value"] as Array):
		var transaction_id := str((operation as Dictionary)["transaction_id"])
		var reconciled: Dictionary = _resume_operation((operation as Dictionary).duplicate(true))
		results.append({"transaction_id": transaction_id, "result": reconciled})
		if operation.get("kind") == "new_run" and not reconciled.get("ok", false):
			return reconciled
	return {"ok": true, "code": &"ok", "value": {"reconciled": results}}

## FIX (dwm-p2r.35.4 remediation, finding B-C2): the frozen continuation law (plan02-frozen-
## contracts.md, around line 543) requires startup to, for every nonterminal operation, "reacquire[]
## the owner implied by kind, reload[]/hash-verif[y] the exact restore locator or rehash[] the
## retained New-Run initial context, and recompute[] the deterministic allocation candidate."
## Before allocation, a proven missing/hash-changed source records `aborted` with a typed failure
## and no live mutation. From `identity_allocation_committed` on, recovery can only advance forward
## (never abort); when it cannot prove forward progress, it persists a typed diagnostic and latches
## a fatal recovery failure instead, per `_latch_recovery_diagnostic()` below.
func _resume_operation(operation: Dictionary) -> Dictionary:
	if operation.get("kind") == "new_run":
		return retry_new_run(str(operation["transaction_id"]))
	var transaction_id := str(operation["transaction_id"])
	var kind := str(operation["kind"])
	var owner := StringName(kind)

	var gate_token := ""
	var gate_acquired := false
	if _mutation_gate != null:
		var acquired: Dictionary = _mutation_gate.acquire(owner)
		if not acquired.get("ok", false):
			return acquired
		gate_token = str(acquired["value"]["token"])
		gate_acquired = true

	var verified: Dictionary = _continuation_journal.reconcile_startup(transaction_id, _identity_issuer)
	if not verified.get("ok", false):
		if str(operation.get("stage", "")) == CONTINUATION_JOURNAL.STAGE_INTENT:
			# Before allocation: a proven missing/hash-changed source or mismatched context records
			# `aborted` with a typed failure and no live mutation (frozen law) -- nothing was ever
			# minted yet, so there is nothing to roll back.
			var abort_failure := {
				"code": "source_unprovable",
				"message": "the retained restore source or new-run context could not be reverified at startup",
				"details": {"transaction_id": transaction_id, "kind": kind, "verify_code": str(verified.get("code", ""))},
			}
			var aborted: Dictionary = _continuation_journal.advance({
				"transaction_id": transaction_id, "request_fingerprint": str(operation["request_fingerprint"]),
				"expected_stage": CONTINUATION_JOURNAL.STAGE_INTENT, "next_stage": CONTINUATION_JOURNAL.STAGE_ABORTED,
				"expected_next_participant_index": 0, "allocation_receipt": null,
				"participant_name": null, "participant_receipt": null, "failure": abort_failure,
			})
			if gate_acquired:
				_mutation_gate.release(owner, gate_token)
			if not aborted.get("ok", false):
				return aborted
			return {"ok": true, "code": &"ok", "value": {"transaction_id": transaction_id, "outcome": "aborted"}}
		return _latch_recovery_diagnostic(operation, owner, verified)

	var refreshed: Dictionary = _continuation_journal.get_operation(transaction_id)
	if not refreshed.get("ok", false):
		if gate_acquired:
			_mutation_gate.release(owner, gate_token)
		return refreshed
	operation = refreshed["value"]
	var stage := str(operation.get("stage", ""))
	if stage == CONTINUATION_JOURNAL.STAGE_COMPLETED or stage == CONTINUATION_JOURNAL.STAGE_ABORTED:
		if gate_acquired:
			_mutation_gate.release(owner, gate_token)
		return {"ok": true, "code": &"ok", "value": {"transaction_id": transaction_id, "outcome": "already_terminal"}}

	return _resume_restore(operation, gate_token)

## The retained SaveDocument and Profile candidate drive every live retry. Disk
## targets are reproved first; recorded participant prefixes are not process-local state.
func _resume_new_run(operation: Dictionary, _gate_token: String) -> Dictionary:
	if operation["stage"] == CONTINUATION_JOURNAL.STAGE_COMPLETED:
		var released := _release_new_run_custody()
		if not released.get("ok", false): return released
		return {"ok": true, "code": &"ok", "value": {"transaction_id": operation["transaction_id"], "outcome": "already_terminal"}}
	var settled := _settle_new_run_pair(operation)
	if not settled.get("ok", false): return _new_run_failure(settled)
	operation = settled["value"]
	if operation["stage"] == CONTINUATION_JOURNAL.STAGE_ALLOCATED:
		var advanced := _advance_new_run(operation, CONTINUATION_JOURNAL.STAGE_APPLYING)
		if not advanced.get("ok", false): return _new_run_failure(advanced)
		operation = advanced["value"]
	var materials: Dictionary = operation["new_run_materials"]
	var parsed: Dictionary = STRICT_JSON.parse_object(str(materials["autosave"]["outgoing_text"]))
	if not parsed.get("ok", false): return _new_run_failure(parsed)
	var snapshot: Dictionary = parsed["value"]["current_snapshot"]["snapshot"]
	var prepared := _prepare_new_run_plans(snapshot, materials["profile"]["candidate"])
	if not prepared.get("ok", false): return _new_run_failure(prepared)
	var plans: Dictionary = prepared["value"]
	var activation := _prepare_live_session_activation(plans, str(operation["transaction_id"]))
	if not activation.get("ok", false): return _new_run_failure(activation)
	var activation_ticket: Dictionary = activation["value"]
	var reset: Dictionary = _journal.prepare_reset_with_initial(snapshot, &"day_start")
	if not reset.get("ok", false): return _new_run_failure(reset)
	# Reapply every live owner in a fresh process. Persist only the unrecorded suffix:
	# the route-ready token is process-local and must never be compared to an old receipt.
	var route_ready_token: Variant = null
	for index: int in range(_PARTICIPANT_APPLY_ORDER.size()):
		var key: String = _PARTICIPANT_APPLY_ORDER[index]
		var plan: Dictionary = plans[key].duplicate(true)
		if key == "narrative" and route_ready_token != null:
			plan["route_ready_token"] = route_ready_token
		var applied: Dictionary = _restore_participants[key].apply_silent(plan)
		if not applied.get("ok", false): return _new_run_failure(applied)
		if key == "route": route_ready_token = applied.get("value", {}).get("route_ready_token")
		if operation["stage"] == CONTINUATION_JOURNAL.STAGE_APPLYING and index >= int(operation["next_participant_index"]):
			var receipt: Variant = applied.get("value", {})
			var advanced: Dictionary = _continuation_journal.advance({
				"transaction_id": operation["transaction_id"], "request_fingerprint": operation["request_fingerprint"],
				"expected_stage": CONTINUATION_JOURNAL.STAGE_APPLYING, "next_stage": CONTINUATION_JOURNAL.STAGE_APPLYING,
				"expected_next_participant_index": index, "allocation_receipt": null, "participant_name": key,
				"participant_receipt": receipt if typeof(receipt) == TYPE_DICTIONARY else {}, "failure": null})
			if not advanced.get("ok", false): return _new_run_failure(advanced)
			operation = advanced["value"]
	if operation["stage"] == CONTINUATION_JOURNAL.STAGE_APPLYING:
		var advanced := _advance_new_run(operation, CONTINUATION_JOURNAL.STAGE_APPLIED)
		if not advanced.get("ok", false): return _new_run_failure(advanced)
		operation = advanced["value"]
	var checkpoint_candidate: Dictionary = reset["value"]["candidate"]
	var expected_checkpoint := checkpoint_candidate.duplicate(true)
	expected_checkpoint.erase("candidate_kind")
	var captured_checkpoint: Dictionary = _journal.capture_state()
	if not captured_checkpoint.get("ok", false): return _new_run_failure(captured_checkpoint)
	if _canonical_sha256(captured_checkpoint["value"]["backup"]) != _canonical_sha256(expected_checkpoint):
		var checkpoint: Dictionary = _journal.commit_prepared(checkpoint_candidate)
		if not checkpoint.get("ok", false): return _new_run_failure(checkpoint)
	var finalize_order := _PARTICIPANT_APPLY_ORDER.duplicate()
	finalize_order.erase("route")
	finalize_order.append("route")
	for key: String in finalize_order:
		if key == "route" and not activation_ticket.is_empty():
			var validated: Dictionary = _restore_participants["run"].validate_live_session_activation(activation_ticket)
			if not validated.get("ok", false): return _new_run_failure(validated)
		var finalized: Dictionary = _restore_participants[key].finalize()
		if not finalized.get("ok", false): return _new_run_failure(finalized)
	if not activation_ticket.is_empty():
		var activated: Dictionary = _restore_participants["run"].activate_live_session(activation_ticket)
		if not activated.get("ok", false):
			return _fatal_transaction_recovery("new_run", [{"owner_id": "run",
				"operation": "activate_live_session", "result": activated}])
	var completed := _advance_new_run(operation, CONTINUATION_JOURNAL.STAGE_COMPLETED)
	if not completed.get("ok", false): return _new_run_failure(completed)
	_session_activation_tickets.erase(str(operation["transaction_id"]))
	var released := _release_new_run_custody()
	if not released.get("ok", false): return released
	live_session_ready.emit()
	return {"ok": true, "code": &"ok", "value": {"transaction_id": operation["transaction_id"],
		"outcome": "completed", "run_id": snapshot["run_id"], "checkpoint_id": snapshot["checkpoint_id"], "route_id": "main"}}

## Drives a restore operation forward from wherever it stopped. Unlike new_run, restore's
## participant plans depend on the source save document, so a resumed restore must first
## reconstruct byte-identical plans through `_reconstruct_restore_materials()` before it can either
## mint the allocation (at `intent_committed`) or replay/continue the participant loop (at
## `identity_allocation_committed` or later).
func _resume_restore(operation: Dictionary, gate_token: String) -> Dictionary:
	var transaction_id := str(operation["transaction_id"])
	var lock: Dictionary = acquire_save_lock(&"restore")
	if not lock.get("ok", false):
		return _latch_recovery_diagnostic(operation, &"restore", lock)

	var materials := _reconstruct_restore_materials(operation)
	if not materials.get("ok", false):
		return _latch_recovery_diagnostic(operation, &"restore", materials)
	var built: Dictionary = materials["value"]

	var stage := str(operation.get("stage", ""))
	if stage == CONTINUATION_JOURNAL.STAGE_INTENT:
		var identity_applied: Dictionary = _identity_allocation_participant.apply_silent(built["identity_candidate"])
		if not identity_applied.get("ok", false):
			return _latch_recovery_diagnostic(operation, &"restore", identity_applied)
		var allocation_receipt: Dictionary = (identity_applied["value"] as Dictionary)["allocation_receipt"]
		var advance_to_allocated: Dictionary = _continuation_journal.advance({
			"transaction_id": transaction_id, "request_fingerprint": str(operation["request_fingerprint"]),
			"expected_stage": CONTINUATION_JOURNAL.STAGE_INTENT, "next_stage": CONTINUATION_JOURNAL.STAGE_ALLOCATED,
			"expected_next_participant_index": 0, "allocation_receipt": allocation_receipt,
			"participant_name": null, "participant_receipt": null, "failure": null,
		})
		if not advance_to_allocated.get("ok", false):
			return _latch_recovery_diagnostic(operation, &"restore", advance_to_allocated)
		stage = CONTINUATION_JOURNAL.STAGE_ALLOCATED

	if stage == CONTINUATION_JOURNAL.STAGE_ALLOCATED:
		var advance_to_applying: Dictionary = _continuation_journal.advance({
			"transaction_id": transaction_id, "request_fingerprint": str(operation["request_fingerprint"]),
			"expected_stage": CONTINUATION_JOURNAL.STAGE_ALLOCATED, "next_stage": CONTINUATION_JOURNAL.STAGE_APPLYING,
			"expected_next_participant_index": 0, "allocation_receipt": null,
			"participant_name": null, "participant_receipt": null, "failure": null,
		})
		if not advance_to_applying.get("ok", false):
			return _latch_recovery_diagnostic(operation, &"restore", advance_to_applying)

	var result := _run_participant_transaction(&"restore", built["plans"], built["journal_candidate"],
		str(built["route_id"]), str(built["checkpoint_id"]), true, built["continuation"], gate_token,
		stage == CONTINUATION_JOURNAL.STAGE_APPLIED)
	if not result.get("ok", false):
		return _latch_recovery_diagnostic(operation, &"restore", result)
	return {"ok": true, "code": &"ok", "value": {
		"transaction_id": transaction_id, "outcome": "completed", "result": result["value"]}}

## Reconstructs the exact `prepared`/plan bytes `_prepare_restore()` would have produced for this
## operation's retained `source_locator`, by re-reading, re-migrating, and re-validating the SAME
## save document and selecting the SAME specific bundle by `checkpoint_id` (never the "try every
## candidate" search `_prepare_restore()` runs for a caller with no fixed locator -- the locator here
## already names the exact bundle that was originally selected). `existing_run_id`/`source_desktop_
## timeline_generation`/`remap_source_transaction_ids` are re-derived from the reloaded document,
## byte-for-byte the same way `_prepare_bundle_with_all_participants()` derives them live; calling
## `_identity_allocation_participant.prepare()` again is safe and mutation-free (its own doc comment:
## "Mutation-free"), and its own fingerprint check against `allocation_candidate_fingerprint` is
## exactly "recompute[ing] the deterministic allocation candidate" the frozen law requires.
func _reconstruct_restore_materials(operation: Dictionary) -> Dictionary:
	var locator: Dictionary = operation["source_locator"]
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
	var prepared_bundle := _prepare_bundle_with_all_participants(bundle, migrated["value"], document, resolved)
	if not prepared_bundle.get("ok", false):
		return prepared_bundle
	var prepared: Dictionary = prepared_bundle["value"]
	if prepared.get("source_locator") != locator:
		return _fail(&"continuation_source_drifted",
			"the reloaded bundle no longer reproduces the retained source_locator")

	var identity_input := {
		"restore_transaction_id": str(operation["transaction_id"]),
		"transaction_issuer_receipt": operation["transaction_issuer_receipt"],
		"source_locator": locator,
		"existing_run_id": str(prepared["existing_run_id"]),
		"source_desktop_timeline_generation": int(prepared["source_desktop_timeline_generation"]),
		"remap_source_transaction_ids": prepared["remap_source_transaction_ids"],
		"allocation_candidate_fingerprint": str(operation["allocation_candidate_fingerprint"]),
	}
	var identity_prepared: Dictionary = _identity_allocation_participant.prepare(identity_input)
	if not identity_prepared.get("ok", false):
		return identity_prepared
	var identity_candidate: Dictionary = (identity_prepared["value"] as Dictionary)["candidate"]
	var remapped_snapshot: Dictionary = identity_candidate["remapped_snapshot"]

	var plans: Dictionary = (prepared["participant_plans"] as Dictionary).duplicate(true)
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
	var view_prep: Dictionary = _restore_participants["schedule_view"].prepare(_schedule_view_input(remapped_snapshot))
	if not view_prep.get("ok", false):
		return view_prep
	plans["schedule_view"] = view_prep["value"]["schedule_view_plan"]

	return {"ok": true, "code": &"ok", "value": {
		"plans": plans,
		"identity_candidate": identity_candidate,
		"journal_candidate": prepared.get("journal_seed"),
		"route_id": str(prepared.get("route_id", "")),
		"checkpoint_id": str(prepared.get("checkpoint_id", "")),
		"continuation": {
			"transaction_id": str(operation["transaction_id"]),
			"request_fingerprint": str(operation["request_fingerprint"]),
			"remap": {"restore_transaction_id": str(operation["transaction_id"]),
				"identity_allocation_bundle": identity_candidate["identity_allocation_bundle"],
				"source_identity": _source_identity_from_lifecycle(prepared["bundle"]["snapshot"]["lifecycle"])},
		},
	}}

## FIX (dwm-p2r.35.4 remediation, findings B-C2/B-C4): the frozen continuation law requires that once
## `identity_allocation_committed`, a startup that cannot prove forward progress "persists the typed
## failure diagnostic without changing that forward stage, latches a fatal recovery failure, and
## leaves the retained operation/issuer high-water untouched." This is the one place that happens:
## every resume failure past `intent_committed` funnels through here rather than being silently
## swallowed (the old `reconcile_incomplete_continuations()` behavior finding B-C2 describes) or
## left to strand the journal record with no trace and no blocked input. `code` is always
## `source_unprovable` regardless of the underlying reason: the journal's own `_apply_recovery_
## diagnostic()` requires exactly that code for a first-time diagnostic at `identity_allocation_
## committed`, and using it uniformly keeps every stage's diagnostic replay-safe (byte-identical on
## a retry of the same still-unrecoverable operation) without depending on the failing step's own
## code staying stable. The real reason is preserved in `details.reason_code` for diagnosis. Always
## returns `ok:true`: the reconciliation pass itself succeeded at doing its job (recording the
## diagnostic and blocking further mutation) even though the underlying operation could not complete.
func _latch_recovery_diagnostic(operation: Dictionary, owner: StringName, raw_failure_context: Dictionary) -> Dictionary:
	var transaction_id := str(operation["transaction_id"])
	var stage := str(operation.get("stage", ""))
	var journal_failure := {
		"code": "source_unprovable",
		"message": "continuation recovery could not prove forward progress at startup",
		"details": {
			"transaction_id": transaction_id, "kind": String(owner), "stage": stage,
			"reason_code": str(raw_failure_context.get("code", "")),
		},
	}
	var diagnostic_advance: Dictionary = _continuation_journal.advance({
		"transaction_id": transaction_id, "request_fingerprint": str(operation["request_fingerprint"]),
		"expected_stage": stage, "next_stage": stage,
		"expected_next_participant_index": int(operation.get("next_participant_index", 0)),
		"allocation_receipt": null, "participant_name": null, "participant_receipt": null,
		"failure": journal_failure,
	})
	var gate_failure := {
		"source": "continuation_reconciliation", "phase": "resume_" + String(owner),
		"code": "source_unprovable",
		"details": {"transaction_id": transaction_id, "stage": stage,
			"reason_code": str(raw_failure_context.get("code", ""))},
	}
	var latched: Dictionary = {"ok": true}
	if _mutation_gate != null:
		latched = _mutation_gate.latch_fatal(gate_failure)
	return {"ok": true, "code": &"ok", "value": {
		"transaction_id": transaction_id, "outcome": "fatal_latched",
		"diagnostic": diagnostic_advance, "gate_latch": latched,
	}}

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

## Keep source identity explicit: live run state already contains the remapped destination.
static func _source_identity_from_lifecycle(lifecycle: Dictionary) -> Dictionary:
	var receipt: Variant = lifecycle.get("causal_day_instance_issuer_receipt")
	return {"branch_id": lifecycle.get("branch_id"),
		"desktop_timeline_generation": lifecycle.get("desktop_timeline_generation"),
		"causal_day_instance": lifecycle.get("causal_day_instance"),
		"causal_day_instance_issuer_receipt": receipt.duplicate(true) if typeof(receipt) == TYPE_DICTIONARY else receipt}

static func _schedule_view_input(snapshot: Dictionary) -> Dictionary:
	return {"schedule_view": snapshot["schedule_view"],
		"registry_fingerprint": snapshot["committed_schedule"]["registry_fingerprint"]}

## Freeze the current lifetime before any candidate apply. Pure participant
## orchestration without a run snapshot has no live session to replace.
func _prepare_live_session_activation(plans: Dictionary, operation_id: String) -> Dictionary:
	var plan: Dictionary = plans.get("run", {})
	if not plan.has("snapshot"):
		return {"ok": true, "value": {}}
	if _session_activation_tickets.has(operation_id):
		return {"ok": true, "value": _session_activation_tickets[operation_id].duplicate(true)}
	var run: Object = _restore_participants["run"]
	if not run.has_method("capture_live_session"):
		return _fail(&"session_owner_unconfigured", "run participant requires live-session ownership")
	var captured: Dictionary = run.capture_live_session()
	if not captured.get("ok", false): return captured
	var session: Dictionary = captured["value"]
	var ticket := {"operation_id": operation_id, "expected_generation": session["generation"],
		"owner_id": session["owner_id"], "run_id": plan["snapshot"]["run_id"]}
	_session_activation_tickets[operation_id] = ticket.duplicate(true)
	return {"ok": true, "value": ticket}
