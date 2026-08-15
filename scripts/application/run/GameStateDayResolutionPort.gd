class_name GameStateDayResolutionPort
extends RefCounted

## Production state port bridging DayResolutionCoordinator to the GameState
## facade and its RunLifecycle
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 3).
##
## Phase 2R scope note: every stage completes immediately with a
## deterministic owner receipt; registered external route commands and real
## schedule-substage receipts arrive with the Plan04 integration tasks.

## Real snapshot production (dwm-7e6). GameState supplies the inner snapshot_input through its pure
## capture seam; the five non-GameState fields arrive through injected Callables, mirroring the
## SaveManagerNarrativeCheckpointPort provider seam. Unconfigured, safe defaults keep the SHAPE
## complete so no caller can silently regress to the old {run_id, day} stub.
const RUN_LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")

const CHECKPOINT_PROVIDER_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint", "route_id",
]
const DEFAULT_ROUTE_ID := "main"
const DEFAULT_CONTENT_VERSION := 1

var _game_state: Object = null
var _checkpoint_providers: Dictionary = {}
var _provider_identity: Dictionary = {}

func _init(game_state: Object) -> void:
	_game_state = game_state

func configure_checkpoint_providers(providers: Dictionary) -> Dictionary:
	if typeof(providers) != TYPE_DICTIONARY or providers.size() != CHECKPOINT_PROVIDER_KEYS.size():
		return {"ok": false, "code": &"invalid_checkpoint_providers", "message": "providers must be exactly " + str(CHECKPOINT_PROVIDER_KEYS), "details": {}}
	var identity := {}
	for key in CHECKPOINT_PROVIDER_KEYS:
		if not providers.has(key) or typeof(providers[key]) != TYPE_CALLABLE:
			return {"ok": false, "code": &"invalid_checkpoint_providers", "message": "missing or non-Callable provider: " + key, "details": {}}
		var callable: Callable = providers[key]
		if not callable.is_valid() or callable.get_object_id() == 0 or callable.get_argument_count() != 0:
			return {"ok": false, "code": &"invalid_checkpoint_providers", "message": "provider must be a zero-argument Callable with stable identity: " + key, "details": {}}
		identity[key] = [callable.get_object_id(), String(callable.get_method())]
	if not _checkpoint_providers.is_empty():
		if identity == _provider_identity:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return {"ok": false, "code": &"checkpoint_providers_already_configured", "message": "", "details": {}}
	_checkpoint_providers = providers.duplicate()
	_provider_identity = identity
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}

## Builds the complete CHECKPOINT_INPUT_KEYS bundle the coordinator hands straight to the real
## SaveManagerCheckpointPort. Providers are consulted once each, in a fixed order.
##
## `lifecycle` is supplied by the caller rather than read from live state: a stage's checkpoint must
## record the lifecycle that stage PRODUCES (dwm-7e6). Every other field is genuinely live, because
## completing a stage mutates the RunLifecycle alone.
func _checkpoint_inputs(lifecycle: Dictionary) -> Dictionary:
	var snapshot_input: Dictionary = _game_state.capture_run_snapshot_input()
	snapshot_input["lifecycle"] = lifecycle.duplicate(true)
	# v3 committed-Schedule boundary (Plan 01 Task 5, dwm-p2r.13). Because the recorded lifecycle is
	# the one the stage PRODUCES rather than live state, it can name a later day than the owner has
	# entered. A snapshot names ONE day, so the aggregate must describe the recorded day: a day the
	# owner has not begun has no committed Schedule yet, so it records the canonical empty aggregate
	# with a null fingerprint. When the days already agree this leaves the real aggregate untouched.
	var recorded_day := int(lifecycle.get("day", 0))
	var aggregate_value: Variant = snapshot_input.get("committed_schedule", {})
	var aggregate: Dictionary = aggregate_value if typeof(aggregate_value) == TYPE_DICTIONARY else {}
	if int(aggregate.get("day", -1)) != recorded_day:
		snapshot_input["committed_schedule"] = {
			"schema_version": int(aggregate.get("schema_version", 1)),
			"day": recorded_day,
			"registry_fingerprint": null,
			"entries": [],
			"commit_receipt": null,
		}
	return {
		"snapshot_input": snapshot_input,
		"dialogic_checkpoint": _provided("dialogic_checkpoint", {}),
		"route_id": _provided("route_id", DEFAULT_ROUTE_ID),
		"active_app_id": _provided("active_app_id", null),
		"audio_context": _provided("audio_context", {}),
		"content_version": _provided("content_version", DEFAULT_CONTENT_VERSION),
	}

func _provided(key: String, fallback: Variant) -> Variant:
	if not _checkpoint_providers.has(key):
		return fallback
	var produced: Variant = (_checkpoint_providers[key] as Callable).call()
	if typeof(produced) == TYPE_DICTIONARY or typeof(produced) == TYPE_ARRAY:
		return produced.duplicate(true)
	return produced

func begin_or_resume(command_id: String) -> Dictionary:
	if command_id.is_empty():
		return {"ok": false, "code": &"invalid_command_id", "message": "", "details": {}}
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var begun: Dictionary = lifecycle.begin_day_resolution(command_id, [])
	if not begun.get("ok", false):
		return begun
	return {"ok": true, "code": &"ok",
		"value": {"run_id": str(lifecycle.to_dict()["run_id"])}}

func inspect_next_stage() -> Dictionary:
	var cursor: Dictionary = _game_state._run_lifecycle.resume_resolution()
	return cursor

func begin_next_stage() -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var begun: Dictionary = lifecycle.begin_next_stage()
	if not begun.get("ok", false):
		return begun
	var stage: Dictionary = begun["value"]["stage"]
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": _immediate_receipt(str(stage["stage_id"])),
	}}

func prepare_completion(transaction_id: String, receipt: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var snapshot: Dictionary = lifecycle.to_dict()
	if snapshot["active_resolution_plan"] != null:
		for stage: Dictionary in snapshot["active_resolution_plan"]["stages"]:
			if str(stage["transaction_id"]) == transaction_id and str(stage["state"]) == "completed":
				# Already durable. Re-applying it would be a no-op, but building a candidate for it
				# would misrepresent a replay as fresh work.
				return _prepared(transaction_id, receipt, snapshot, true, stage["receipt"])
	var produced := _completed_lifecycle(snapshot, transaction_id, receipt)
	if not produced.get("ok", false):
		return produced
	return _prepared(transaction_id, receipt, produced["value"]["lifecycle"], false, null)


## Applies the stage to a DETACHED clone of the lifecycle. The checkpoint is then built from the
## state the transaction PRODUCES, while live state stays untouched until the coordinator has
## durably committed that checkpoint and replays this exact lifecycle into it (dwm-7e6).
func _completed_lifecycle(snapshot: Dictionary, transaction_id: String, receipt: Dictionary) -> Dictionary:
	var detached: RefCounted = RUN_LIFECYCLE.new()
	var prepared: Dictionary = detached.prepare_restore(snapshot)
	if not prepared.get("ok", false):
		return prepared
	var restored: Dictionary = detached.commit_restore(prepared["value"]["candidate"])
	if not restored.get("ok", false):
		return restored
	# The clone is also the validation seam: an illegal receipt fails here, before any checkpoint.
	var completed: Dictionary = detached.complete_active_stage(
		transaction_id, _plan_receipt_from_envelope(receipt))
	if not completed.get("ok", false):
		return completed
	return {"ok": true, "code": &"ok", "value": {"lifecycle": detached.to_dict()}}


func _prepared(
		transaction_id: String, receipt: Dictionary, lifecycle: Dictionary,
		duplicate: bool, stored_receipt: Variant
) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {
		"run_candidate": {
			"transaction_id": transaction_id,
			"receipt": receipt.duplicate(true),
			"lifecycle": lifecycle.duplicate(true),
		},
		# Despite the key name, the coordinator forwards this value verbatim as the real checkpoint
		# port's `checkpoint_inputs`, so it must be the COMPLETE bundle (dwm-7e6).
		"snapshot_input": _checkpoint_inputs(lifecycle),
		"stage": {"transaction_id": transaction_id},
		"publication": {
			"transaction_id": transaction_id,
			"signals": ["day_changed", "save_relevant_state_changed"],
		},
		"duplicate": duplicate,
		"stored_receipt": stored_receipt,
	}}

func capture() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"lifecycle": _game_state._run_lifecycle.to_dict(),
	}}}

## Installs the EXACT lifecycle the checkpoint recorded, rather than re-deriving the completion from
## live state. Re-deriving would let the durable record and the live run drift apart (dwm-7e6).
func commit(candidate: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var prepared: Dictionary = lifecycle.prepare_restore(candidate["lifecycle"])
	if not prepared.get("ok", false):
		return prepared
	return lifecycle.commit_restore(prepared["value"]["candidate"])

func rollback(backup: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var restored: Dictionary = lifecycle.prepare_restore(backup["lifecycle"])
	if not restored.get("ok", false):
		return restored
	var committed: Dictionary = lifecycle.commit_restore(restored["value"]["candidate"])
	return committed

func publish(publication: Dictionary) -> Dictionary:
	if typeof(publication.get("signals")) != TYPE_ARRAY:
		return {"ok": false, "code": &"invalid_publication", "message": "", "details": {}}
	for signal_name: Variant in publication["signals"]:
		if typeof(signal_name) != TYPE_STRING or not _game_state.has_signal(str(signal_name)):
			return {"ok": false, "code": &"invalid_publication", "message": str(signal_name), "details": {}}
	for signal_name: Variant in publication["signals"]:
		match str(signal_name):
			"day_changed":
				_game_state.emit_signal("day_changed", int(_game_state._run_lifecycle.get_day()))
			_:
				_game_state.emit_signal(str(signal_name))
	return {"ok": true, "code": &"ok"}

## The day this resolution was created for, independent of how far its stages have advanced.
func _active_source_day() -> int:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) == TYPE_DICTIONARY and (plan as Dictionary).has("source_day"):
		return int((plan as Dictionary)["source_day"])
	return int(_game_state._run_lifecycle.get_day())


func _immediate_receipt(stage_id: String) -> Dictionary:
	# Freeze the resolution's SOURCE day (dwm-7e6). Reading the live day here made
	# reset_day_scope.target_day become source + 2 once increment_day had already advanced it.
	var day: int = _active_source_day()
	match stage_id:
		"lock_day":
			return _envelope("day_resolution_coordinator", "day_lock", {"locked": true})
		"validate_schedule":
			return _envelope("schedule_rules", "schedule_validation",
				{"schedule_digest": "digest-day-%d" % day, "ordered_entry_ids": []})
		"execute_schedule_entries":
			return _envelope("schedule_rules", "schedule_entries_complete", {"entry_receipt_ids": []})
		"commit_outcomes":
			return _envelope("game_state", "outcomes_commit", {"outcome_ids": [], "effect_transaction_ids": []})
		"hospital_if_triggered":
			return _envelope("dating_ending_rules", "hospital_resolution",
				{"required": false, "route_receipt_id": null, "prevented_entry_id": null})
		"twofriends_if_deferred":
			return _envelope("contact_invitation_state", "twofriends_resolution",
				{"required": false, "route_receipt_id": null, "message_transaction_ids": []})
		"invitation_rollover":
			return _envelope("contact_invitation_state", "invitation_rollover",
				{"target_day": day + 1, "message_transaction_ids": []})
		"increment_day":
			return _envelope("run_lifecycle", "day_increment", {"source_day": day, "target_day": day + 1})
		"reset_day_scope":
			return _envelope("game_state", "day_scope_reset", {"target_day": day + 1, "reset_ids": []})
		"new_day_autosave":
			return _envelope("save_manager", "disk_checkpoint_request",
				{"save_kind": "autosave", "save_reason": "day_start"})
		"unlock_day":
			return _envelope("day_resolution_coordinator", "day_unlock", {"locked": false})
		"close_invitations_run_end":
			return _envelope("contact_invitation_state", "run_end_close", {"resolved_action_ids": []})
		"resolve_ending_plan":
			return _envelope("dating_ending_rules", "ending_resolution", {"ending_plan": _default_ending_plan()})
		"enter_ending":
			return _envelope("run_lifecycle", "enter_ending",
				{"state": "ENDING", "primary_id": _resolved_primary_id(), "epilogue_id": null})
		"ending_autosave":
			return _envelope("save_manager", "disk_checkpoint_request",
				{"save_kind": "autosave", "save_reason": "ending"})
	return _envelope("unknown", "unknown", {})

func _resolved_primary_id() -> String:
	var route_context: Dictionary = _game_state.route_context
	return str(route_context.get("ending_id", "ending.alone"))

func _default_ending_plan() -> Dictionary:
	return {
		"ending_id": _resolved_primary_id(),
		"epilogue_ending_id": "",
		"source_day": 7,
		"playback_stage": "PRIMARY_PENDING",
		"playback_receipts": {},
	}

static func _envelope(owner_id: String, kind: String, value: Dictionary) -> Dictionary:
	return {"owner_id": owner_id, "kind": kind, "value": value}

static func _plan_receipt_from_envelope(envelope: Dictionary) -> Dictionary:
	var value: Dictionary = envelope["value"]
	match str(envelope["kind"]):
		"day_increment":
			return {"value": {"day": int(value["target_day"])}}
		"enter_ending":
			var epilogue: Variant = value.get("epilogue_id")
			return {"value": {"ending_plan": {
				"ending_id": str(value["primary_id"]),
				"epilogue_ending_id": str(epilogue) if epilogue != null else "",
				"source_day": 7,
				"playback_stage": "PRIMARY_PENDING",
				"playback_receipts": {},
			}}}
	return {"value": value.duplicate(true)}
