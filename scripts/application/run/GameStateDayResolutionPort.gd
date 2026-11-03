class_name GameStateDayResolutionPort
extends RefCounted


const RUN_LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const SCHEDULE_RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const HOSPITAL_RULES := preload("res://scripts/domain/hospital/HospitalRules.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const SCHEDULE_STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const DAY_RESOLUTION_PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")
const HOSPITAL_CONTEXT := preload("res://scripts/narrative/HospitalFrozenContext.gd")

const CHECKPOINT_PROVIDER_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint", "route_id",
]
const DEFAULT_ROUTE_ID := "main"
const DEFAULT_CONTENT_VERSION := 1

const DAY_VIEW := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const DAY_BOARD := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const DAY_CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")

var _day_view: Object = null
var _day_board: Object = null
var _day_consequence: Object = null
var _game_state: Object = null
var _checkpoint_providers: Dictionary = {}
var _provider_identity: Dictionary = {}
var _pair_deck: Object = null
var _frozen_hospital_contexts_enabled := false

func configure_frozen_hospital_contexts() -> Dictionary:
	if _game_state == null or not _game_state.has_method("read_hospital_presentation_request") \
			or not _game_state.has_method("retain_hospital_presentation_request"):
		return {"ok": false, "code": &"hospital_frozen_store_unavailable"}
	_frozen_hospital_contexts_enabled = true
	return {"ok": true}

var _day7_provenance: Object = null

var _identity_issuer: Object = null
var _day_resolution_start_port: Object = null

var _desktop_consequence_source: Object = null

const _ISSUER_METHODS: Array[String] = ["issue", "verify_issued", "derive_child", "validate_child"]
const _START_PORT_METHODS: Array[String] = ["prepare_from_committed_schedule"]
const _CONSEQUENCE_SOURCE_METHODS: Array[String] = [
	"resolve_board_fate_receipt", "resolve_condition_receipt",
]
const ROOT_PURPOSE := &"transaction_id"


func _init(game_state: Object) -> void:
	_game_state = game_state

func configure_day_advance_owners(view: Object, board: Object, consequence: Object) -> Dictionary:
	if view == null or not view.has_method("install_restored_view") or not view.has_method("snapshot") 			or board == null or not board.has_method("prepare_restore") 			or consequence == null or not consequence.has_method("prepare_restore"):
		return {"ok": false, "code": &"invalid_day_advance_owners"}
	if _day_view != null and (_day_view != view or _day_board != board or _day_consequence != consequence):
		return {"ok": false, "code": &"day_advance_owners_already_configured"}
	_day_view = view
	_day_board = board
	_day_consequence = consequence
	return {"ok": true}

func configure_pair_deck(port: Object) -> Dictionary:
	if port == null or not port.has_method("prepare_schedule"):
		return {"ok": false, "code": &"pair_deck_unavailable"}
	if _pair_deck != null and _pair_deck != port:
		return {"ok": false, "code": &"pair_deck_already_configured"}
	_pair_deck = port
	return {"ok": true}


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

func _checkpoint_inputs(lifecycle: Dictionary) -> Dictionary:
	var snapshot_input: Dictionary = _game_state.capture_run_snapshot_input()
	snapshot_input["lifecycle"] = lifecycle.duplicate(true)
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
	var existing := _active_plan()
	var prior_day_resume := not existing.is_empty() and str(existing.get("command_id", "")) == command_id \
		and int(existing.get("source_day", 7)) < 7
	if not prior_day_resume and _game_state.has_method("require_day7_presentations_complete"):
		var presentations: Dictionary = _game_state.require_day7_presentations_complete()
		if not presentations.get("ok", false): return presentations
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var aggregate: Dictionary = _game_state._canonical_committed_schedule()
	var projection := _frozen_route_plan(aggregate)
	if not projection.get("ok", false):
		return projection
	var commit_receipt: Variant = aggregate.get("commit_receipt")
	var commit_receipt_id: Variant = null
	if typeof(commit_receipt) == TYPE_DICTIONARY:
		commit_receipt_id = (commit_receipt as Dictionary).get("receipt_id")
	var route_plan: Array = (projection["value"] as Dictionary)["route_plan"]
	var minted := _resolution_start(command_id, aggregate, route_plan)
	if not minted.get("ok", false):
		return minted
	var resolution_start: Dictionary = (minted["value"] as Dictionary)["resolution_start"]
	var begun: Dictionary = lifecycle.begin_day_resolution(
		str((minted["value"] as Dictionary)["resolution_id"]), aggregate, route_plan,
		commit_receipt_id, _board_fate_receipt_id(resolution_start), resolution_start)
	if not begun.get("ok", false):
		return begun
	return {"ok": true, "code": &"ok",
		"value": {"run_id": str(lifecycle.to_dict()["run_id"])}}


static func _board_fate_receipt_id(resolution_start: Dictionary) -> Variant:
	var start: Variant = resolution_start.get("day_resolution_start_receipt")
	if typeof(start) != TYPE_DICTIONARY:
		return null
	return (start as Dictionary).get("board_fate_receipt_id")


func _resolution_start(command_id: String, aggregate: Dictionary,
		route_plan: Array) -> Dictionary:
	var existing := _active_plan()
	if not existing.is_empty() and str(existing.get("command_id", "")) == command_id:
		return {"ok": true, "code": &"ok", "value": {
			"resolution_id": str(existing["resolution_id"]),
			"resolution_start": {
				"command_id": command_id,
				"resolution_issuer_receipt": existing["resolution_issuer_receipt"],
				"day_resolution_start_receipt": existing["day_resolution_start_receipt"],
			} if existing["resolution_issuer_receipt"] != null else {},
		}}
	if not is_presentation_producer_ready():
		return {"ok": true, "code": &"ok",
			"value": {"resolution_id": command_id, "resolution_start": {}}}
	if not existing.is_empty() and not _plan_is_complete(existing):
		return {"ok": false, "code": &"resolution_conflict",
			"message": str(existing.get("resolution_id", "")), "details": {}}
	var commit_receipt: Variant = aggregate.get("commit_receipt")
	if typeof(commit_receipt) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"resolution_start_unavailable",
			"message": "a receiptless aggregate cannot anchor a resolution root", "details": {}}
	var causal_day_instance := str((commit_receipt as Dictionary).get("causal_day_instance", ""))
	var board_fate: Variant = _desktop_consequence_source.call(&"resolve_board_fate_receipt", {
		"causal_day_instance": causal_day_instance,
		"source_day": int(aggregate.get("day", 0)),
	})
	if typeof(board_fate) != TYPE_DICTIONARY or not (board_fate as Dictionary).get("ok", false):
		return board_fate if typeof(board_fate) == TYPE_DICTIONARY else {
			"ok": false, "code": &"board_fate_receipt_unavailable",
			"message": "the desktop consequence source returned no CommandResult", "details": {}}
	var issued: Variant = _identity_issuer.call(&"issue", ROOT_PURPOSE)
	if typeof(issued) != TYPE_DICTIONARY or not (issued as Dictionary).get("ok", false):
		return issued if typeof(issued) == TYPE_DICTIONARY else {
			"ok": false, "code": &"resolution_root_unavailable",
			"message": "the issuer refused to mint a resolution root", "details": {}}
	var issued_value: Dictionary = (issued as Dictionary)["value"]
	var root_receipt: Dictionary = issued_value["issuer_receipt"]
	var resolution_id := str(issued_value["token"])
	var prepared: Variant = _day_resolution_start_port.call(&"prepare_from_committed_schedule", {
		"resolution_id": resolution_id,
		"resolution_issuer_receipt": root_receipt.duplicate(true),
		"causal_day_instance": causal_day_instance,
		"committed_schedule": aggregate.duplicate(true),
		"route_plan": route_plan.duplicate(true),
		"board_fate_receipt":
			(((board_fate as Dictionary)["value"] as Dictionary)["board_fate_receipt"] as Dictionary).duplicate(true),
	})
	if typeof(prepared) != TYPE_DICTIONARY or not (prepared as Dictionary).get("ok", false):
		return prepared if typeof(prepared) == TYPE_DICTIONARY else {
			"ok": false, "code": &"resolution_start_unavailable",
			"message": "the start port returned no CommandResult", "details": {}}
	return {"ok": true, "code": &"ok", "value": {
		"resolution_id": resolution_id,
		"resolution_start": {
			"command_id": command_id,
			"resolution_issuer_receipt": root_receipt.duplicate(true),
			"day_resolution_start_receipt":
				(((prepared as Dictionary)["value"] as Dictionary)["start_receipt"] as Dictionary).duplicate(true),
		},
	}}


func _active_plan() -> Dictionary:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	return (plan as Dictionary) if typeof(plan) == TYPE_DICTIONARY else {}


static func _plan_is_complete(plan: Dictionary) -> bool:
	for stage_value: Variant in (plan.get("stages", []) as Array):
		if str((stage_value as Dictionary).get("state", "")) != "completed":
			return false
	return true


func _frozen_route_plan(aggregate: Dictionary) -> Dictionary:
	var entries: Variant = aggregate.get("entries", [])
	if typeof(entries) != TYPE_ARRAY or (entries as Array).is_empty():
		return {"ok": true, "code": &"ok", "value": {"route_plan": []}}
	var loaded: Dictionary = SCHEDULE_ACTION_REGISTRY.load_current()
	if not loaded.get("ok", false):
		return loaded
	var loaded_value: Dictionary = loaded["value"]
	var committed_fingerprint: Variant = aggregate.get("registry_fingerprint")
	if committed_fingerprint != null \
			and str(committed_fingerprint) != str(loaded_value.get("registry_fingerprint", "")):
		return {"ok": false, "code": &"registry_fingerprint_mismatch",
			"message": "the committed Schedule was validated against a different registry",
			"details": {}}
	return SCHEDULE_RULES.build_route_plan(aggregate, loaded_value["registry"])

func inspect_next_stage() -> Dictionary:
	var cursor: Dictionary = _game_state._run_lifecycle.resume_resolution()
	return cursor

const DAY7_PROVENANCE_STAGES: Array[String] = [
	"validate_day7_provenance", "checkpoint_day7_provenance",
]


func begin_next_stage() -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var peeked: Dictionary = lifecycle.resume_resolution()
	var presentation_request: Dictionary = {}
	var contacts_receipt: Dictionary = {}
	if peeked.get("ok", false) and bool(peeked["value"]["has_stage"]):
		var pending: Dictionary = peeked["value"]["stage"]
		var pending_id := str(pending.get("stage_id", ""))
		if pending_id == "increment_day" and _identity_issuer != null and _day_view == null:
			return {"ok": false, "code": &"day_advance_owners_unconfigured"}
		if pending_id in ["invitation_rollover", "close_invitations_run_end"]:
			var contacts_end := _prepare_contacts_day_end(str(pending["transaction_id"]))
			if not contacts_end.get("ok", false): return contacts_end
			contacts_receipt = _contacts_stage_envelope(pending_id, contacts_end["receipt"])
		if pending_id == "resolve_ending_plan" and _default_ending_plan().is_empty():
			return {"ok": false, "code": &"ending_plan_unavailable"}
		if pending_id in DAY7_PROVENANCE_STAGES:
			var handoff := _day7_handoff()
			if not handoff.get("ok", false):
				return handoff
		var retained := {}
		if _frozen_hospital_contexts_enabled and pending_id == HOSPITAL_STAGE:
			var read: Dictionary = _game_state.read_hospital_presentation_request(str(_active_plan().resolution_id))
			if not read.get("ok", false): return read
			retained = read.value
			if retained.is_empty() and pending.get("state") == "active":
				return {"ok": false, "code": &"hospital_frozen_context_required"}
		var site := {"kind": "hospital", "stage_name": HOSPITAL_STAGE, "route_id": "hospital",
			"schedule_entry_id": null} if not retained.is_empty() else _presentation_site(pending)
		if not site.is_empty():
			var command := {"ok": true, "value": {"presentation_request": retained}} \
				if not retained.is_empty() else _presentation_command(pending, site)
			if not command.get("ok", false):
				return command
			presentation_request = (command["value"] as Dictionary)["presentation_request"]
			var pair_ready := _prepare_pair_presentation(site)
			if not pair_ready.get("ok", false): return pair_ready
	var begun: Dictionary = lifecycle.begin_next_stage()
	if not begun.get("ok", false):
		return begun
	var stage: Dictionary = begun["value"]["stage"]
	if not presentation_request.is_empty():
		return {"ok": true, "code": &"ok", "value": {
			"mode": &"await_registered_command",
			"stage": stage.duplicate(true),
			"command": {
				"transaction_id": str(stage["transaction_id"]),
				"stage_id": str(stage["stage_id"]),
				"route_id": str(presentation_request["route_id"]),
				"presentation_request": presentation_request,
			},
		}}
	var substage_id := str(stage.get("substage_id", ""))
	if substage_id.begins_with("ordinary_action:"):
		return _begin_ordinary_action_substage(stage, substage_id)
	if substage_id.begins_with("surviving_date:"):
		return _begin_surviving_date_substage(stage, substage_id)
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": contacts_receipt if not contacts_receipt.is_empty() else _immediate_receipt(str(stage["stage_id"])),
	}}


func _begin_ordinary_action_substage(stage: Dictionary, substage_id: String) -> Dictionary:
	var parts: PackedStringArray = substage_id.split(":")
	if parts.size() != 4:
		return {"ok": false, "code": &"invalid_substage_id", "message": substage_id, "details": {}}
	var entry_id := parts[3]
	var projected := _route_plan_entry(entry_id)
	if projected.is_empty():
		return {"ok": false, "code": &"unprojected_schedule_entry",
			"message": "no registry projection for committed entry " + entry_id, "details": {}}
	var effect_ids: Array[String] = []
	for effect_id: Variant in (projected.get("effect_ids", []) as Array):
		effect_ids.append(str(effect_id))
	var transaction_id := str(stage["transaction_id"])
	if not effect_ids.is_empty():
		var applied: Dictionary = _game_state.commit_effect_transaction(
			transaction_id, effect_ids, "schedule_entry")
		if not applied.get("ok", false):
			return applied
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": _envelope("schedule_rules", "schedule_entry_complete",
			{"entry_receipt_id": entry_id, "outcome_ids": effect_ids}),
	}}


func _begin_surviving_date_substage(stage: Dictionary, substage_id: String) -> Dictionary:
	var parts: PackedStringArray = substage_id.split(":")
	if parts.size() != 4:
		return {"ok": false, "code": &"invalid_substage_id", "message": substage_id, "details": {}}
	var entry_id := parts[3]
	var superseded: bool = entry_id in _superseded_entry_ids()
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": _envelope("schedule_rules", "schedule_date_complete", {
			"entry_receipt_id": entry_id,
			"superseded": superseded,
			"reason": HOSPITAL_RULES.MISS_REASON if superseded else null,
			"presentation_completion_receipt": null,
		}),
	}}


func _route_plan_entry(schedule_entry_id: String) -> Dictionary:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return {}
	for projected: Variant in ((plan as Dictionary).get("route_plan", []) as Array):
		if typeof(projected) != TYPE_DICTIONARY:
			continue
		if str((projected as Dictionary).get("schedule_entry_id", "")) == schedule_entry_id:
			return projected as Dictionary
	return {}

func prepare_completion(transaction_id: String, receipt: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var snapshot: Dictionary = lifecycle.to_dict()
	if snapshot["active_resolution_plan"] != null:
		for stage: Dictionary in snapshot["active_resolution_plan"]["stages"]:
			if str(stage["transaction_id"]) == transaction_id and str(stage["state"]) == "completed":
				if _plan_receipt_for_snapshot(receipt, snapshot) == stage["receipt"]:
					return _prepared(transaction_id, receipt, snapshot, true, stage["receipt"])
			for substage: Dictionary in stage["substages"]:
				if str(substage["transaction_id"]) != transaction_id \
						or str(substage["state"]) != "completed":
					continue
				if _plan_receipt_from_envelope(receipt) == substage["receipt"]:
					return _prepared(transaction_id, receipt, snapshot, true, substage["receipt"])
	var stage_id := _stage_id_for_transaction(snapshot, transaction_id)
	var day_end: Dictionary = {}
	if stage_id in ["invitation_rollover", "close_invitations_run_end"]:
		day_end = _prepare_contacts_day_end(transaction_id)
		if not day_end.get("ok", false): return day_end
		if receipt != _contacts_stage_envelope(stage_id, day_end["receipt"]):
			return {"ok": false, "code": &"contacts_rollover_receipt_conflict"}
	if stage_id == "increment_day" and receipt.value.has("day_advance_identity_receipt"):
		var allocation_check := _validate_day_advance(snapshot, receipt.value)
		if not allocation_check.get("ok", false): return allocation_check
	var produced := _completed_lifecycle(snapshot, transaction_id, receipt)
	if not produced.get("ok", false):
		return produced
	var prepared := _prepared(transaction_id, receipt, produced["value"]["lifecycle"], false, null)
	var contacts_candidate := _hospital_contacts_candidate(snapshot, transaction_id, receipt)
	if not day_end.is_empty():
		contacts_candidate = day_end["value"]["candidate"]
	if not contacts_candidate.is_empty():
		prepared.value.run_candidate["contacts"] = contacts_candidate.duplicate(true)
		prepared.value.snapshot_input.snapshot_input["contacts"] = contacts_candidate.duplicate(true)
	if not day_end.is_empty() and _pair_window_counts(day_end.receipt.get("pl_window")):
		if _pair_deck == null: return {"ok": false, "code": &"pair_deck_unconfigured"}
		var drawn: Dictionary = _pair_deck.prepare_schedule()
		if not drawn.get("ok", false): return drawn
		var gameplay: Dictionary = _game_state.capture_run_snapshot_input()["gameplay"].duplicate(true)
		gameplay.inter_friend_route_state["priscilla_lavinia"] = drawn.value.pair_state.duplicate(true)
		prepared.value.run_candidate["gameplay"] = gameplay
		prepared.value.snapshot_input.snapshot_input["gameplay"] = gameplay.duplicate(true)
	if stage_id == "commit_outcomes":
		var condition_gameplay := _prepare_schedule_condition_gameplay(
			_game_state.capture_run_snapshot_input()["gameplay"], _active_source_day())
		prepared.value.run_candidate["gameplay"] = condition_gameplay
		prepared.value.snapshot_input.snapshot_input["gameplay"] = condition_gameplay.duplicate(true)
	if stage_id == "hospital_if_triggered" and bool(receipt.value.get("required", false)) \
			and receipt.value.get("presentation_completion_receipt") is Dictionary:
		var recovery: Dictionary = preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd").HOSPITAL_RECOVERY
		var gameplay: Dictionary = _game_state.capture_run_snapshot_input()["gameplay"].duplicate(true)
		gameplay.stats["health"] = int(recovery["health"])
		gameplay.stats["pressure"] = int(recovery["pressure"])
		gameplay["pending_hospital"] = false
		gameplay["condition_effects_today"] = []
		gameplay["condition_streak_days"] = 0
		gameplay["condition_resolved_day"] = 0
		if _frozen_hospital_contexts_enabled:
			var plan := _active_plan()
			var retained: Dictionary = _game_state.read_hospital_presentation_request(str(plan.resolution_id))
			if not retained.get("ok", false): return retained
			if retained.value.is_empty(): return {"ok": false, "code": &"hospital_frozen_context_required"}
			var projected := _derive_hospital_rows(plan, plan.resolution_issuer_receipt, plan.day_resolution_start_receipt)
			if not projected.ok: return projected
			var planned: Dictionary = HOSPITAL_RULES.plan_resolution({"required": true,
				"source_day": _active_source_day(), "committed_entries": _active_committed_entries()})
			if not planned.ok: return planned
			var captured := _capture_schedule_hospital_misses(gameplay, _game_state.contacts, retained.value,
				planned.value.misses, projected.value.hospital_miss_receipt_ids)
			if not captured.ok: return captured
			gameplay = captured.value
		prepared.value.run_candidate["gameplay"] = gameplay
		prepared.value.snapshot_input.snapshot_input["gameplay"] = gameplay.duplicate(true)
	if stage_id == "increment_day" and receipt.value.has("day_advance_identity_receipt"):
		var owners := _prepare_new_day_owners(receipt.value)
		if not owners.get("ok", false): return owners
		for key: String in owners.value:
			prepared.value.run_candidate[key] = owners.value[key].duplicate(true)
			prepared.value.snapshot_input.snapshot_input[key] = owners.value[key].duplicate(true)
	if stage_id == "reset_day_scope":
		var value: Dictionary = prepared["value"]
		var gameplay: Dictionary = _game_state.capture_new_day_gameplay()
		value.run_candidate["gameplay"] = gameplay
		value.run_candidate["committed_schedule"] = {}
		value.snapshot_input.snapshot_input["gameplay"] = gameplay.duplicate(true)
		value.publication.signals.append("daily_state_reset")
		value.publication.signals.append("schedule_changed")
	if _frozen_hospital_contexts_enabled and not contacts_candidate.is_empty():
		var gameplay: Dictionary = prepared.value.run_candidate.get("gameplay", _game_state.capture_run_snapshot_input().gameplay)
		var captured := preload("res://scripts/narrative/ContactsFrozenContext.gd").capture_candidate(
			_game_state.contacts, contacts_candidate, gameplay, _active_source_day())
		if not captured.ok: return captured
		prepared.value.run_candidate["gameplay"] = captured.value
		prepared.value.snapshot_input.snapshot_input["gameplay"] = captured.value.duplicate(true)
	return prepared

static func _capture_schedule_hospital_misses(gameplay: Dictionary, contacts: Dictionary, request: Dictionary,
		misses: Array, miss_ids: Array) -> Dictionary:
	var checked := HOSPITAL_CONTEXT.validate_request(request)
	if not checked.ok: return checked
	var sorted_ids := miss_ids.duplicate()
	sorted_ids.sort()
	if misses.size() != miss_ids.size() or sorted_ids != request.context.miss_receipt_ids:
		return {"ok": false, "code": &"hospital_frozen_source_mismatch"}
	var candidate := gameplay.duplicate(true)
	var retained: Array = candidate.get("missed_invitations", []).duplicate(true)
	for index: int in range(misses.size()):
		var miss: Dictionary = misses[index]
		if miss.get("source_receipt_id") not in request.context.presentation.fields.accepted_record_ids:
			return {"ok": false, "code": &"hospital_frozen_source_mismatch"}
		var source := CONTACT_STATE.get_schedule_source_receipt(contacts, str(miss.source_receipt_id))
		if not source.get("ok", false): return source
		if source.value.receipt.day != request.context.day or source.value.receipt.action_id != miss.get("action_id"):
			return {"ok": false, "code": &"hospital_frozen_source_mismatch"}
		var participants: Array = source.value.receipt.participants
		for friend: String in participants:
			var annotation := {"friend_id": friend, "source": "group" if participants.size() > 1 else "solo",
				"day": request.context.day, "missed_reason": "hospital", "source_receipt_id": miss.source_receipt_id,
				"hospital_miss_receipt_id": miss_ids[index], "schedule_hospital_resolution_id": request.resolution_id}
			for prior: Variant in retained:
				if prior is Dictionary and prior.get("friend_id") == friend and prior.get("source_receipt_id") == miss.source_receipt_id \
						and prior.get("missed_reason") == "hospital" and prior != annotation:
					return {"ok": false, "code": &"hospital_frozen_miss_conflict"}
			if annotation not in retained: retained.append(annotation)
	candidate["missed_invitations"] = retained
	return {"ok": true, "value": candidate}


func _prepare_contacts_day_end(transaction_id: String) -> Dictionary:
	var attendance := {"solo_attended_action_ids": [], "group_outcome": "not_scheduled"}
	for stage: Dictionary in _active_plan().get("stages", []):
		if str(stage.get("stage_id", "")) != "execute_schedule_dates": continue
		for substage: Dictionary in stage.get("substages", []):
			if str(substage.get("state", "")) != "completed": continue
			var saved: Dictionary = substage.get("receipt", {})
			var facts: Dictionary = saved.get("value", {})
			var entry := _route_plan_entry(str(facts.get("entry_receipt_id", "")))
			if entry.is_empty(): continue
			var superseded := bool(facts.get("superseded", false))
			if str(entry.get("action_kind", "")) == "solo" and not superseded:
				attendance.solo_attended_action_ids.append(str(entry["action_id"]))
			elif str(entry.get("action_kind", "")) == "group":
				attendance.group_outcome = "prevented_by_fainting" if superseded else "attended"
	attendance.solo_attended_action_ids.sort()
	return CONTACT_STATE.prepare_resolve_day_end(_game_state.contacts, _active_source_day(),
		attendance, transaction_id)


func _contacts_stage_envelope(stage_id: String, receipt: Dictionary) -> Dictionary:
	if stage_id == "close_invitations_run_end":
		var resolved: Array[String] = []
		for transition: Dictionary in receipt.get("state_transitions", []):
			resolved.append(str(transition["action_id"]))
		return _envelope("contact_invitation_state", "run_end_close", {"resolved_action_ids": resolved})
	return _envelope("contact_invitation_state", "invitation_rollover", {
		"target_day": _active_source_day() + 1,
		"message_transaction_ids": receipt.get("child_transaction_ids", []).duplicate(),
	})


func _stage_id_for_transaction(snapshot: Dictionary, transaction_id: String) -> String:
	var plan: Variant = snapshot.get("active_resolution_plan")
	if not plan is Dictionary: return ""
	for stage: Dictionary in plan.get("stages", []):
		if str(stage.get("transaction_id", "")) == transaction_id:
			return str(stage.get("stage_id", ""))
	return ""


func _hospital_contacts_candidate(snapshot: Dictionary, transaction_id: String,
		receipt: Dictionary) -> Dictionary:
	if not _is_hospital_stage(snapshot, transaction_id):
		return {}
	var value: Variant = receipt.get("value")
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	if (value as Dictionary).get("witness_entry_id") == null:
		return {}
	var planned: Dictionary = HOSPITAL_RULES.plan_resolution({
		"required": true,
		"source_day": _active_source_day(),
		"committed_entries": _active_committed_entries(),
	})
	if not planned.get("ok", false):
		return {}
	var witness: Variant = (planned["value"] as Dictionary)["witness"]
	if typeof(witness) != TYPE_DICTIONARY:
		return {}
	var contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	(contacts["sylvia_hospital_witness_receipts"] as Dictionary)[transaction_id] = 		(witness as Dictionary).duplicate(true)
	return contacts


func _is_hospital_stage(snapshot: Dictionary, transaction_id: String) -> bool:
	var plan: Variant = snapshot.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return false
	for stage_value: Variant in ((plan as Dictionary).get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("transaction_id", "")) == transaction_id:
			return str(stage.get("stage_id", "")) == "hospital_if_triggered"
	return false


func _completed_lifecycle(snapshot: Dictionary, transaction_id: String, receipt: Dictionary) -> Dictionary:
	var detached: RefCounted = RUN_LIFECYCLE.new()
	var prepared: Dictionary = detached.prepare_restore(snapshot)
	if not prepared.get("ok", false):
		return prepared
	var restored: Dictionary = detached.commit_restore(prepared["value"]["candidate"])
	if not restored.get("ok", false):
		return restored
	var completed: Dictionary = detached.complete_active_stage(
		transaction_id, _plan_receipt_for_snapshot(receipt, snapshot))
	if not completed.get("ok", false):
		return completed
	return {"ok": true, "code": &"ok", "value": {"lifecycle": detached.to_dict()}}


func _prepared(
		transaction_id: String, receipt: Dictionary, lifecycle: Dictionary,
		duplicate: bool, stored_receipt: Variant
) -> Dictionary:
	var signals: Array[String] = ["save_relevant_state_changed"]
	if not duplicate and int(lifecycle.get("day", 0)) != int(_game_state.day):
		signals.push_front("day_changed")
	return {"ok": true, "code": &"ok", "value": {
		"run_candidate": {
			"transaction_id": transaction_id,
			"receipt": receipt.duplicate(true),
			"lifecycle": lifecycle.duplicate(true),
		},
		"snapshot_input": _checkpoint_inputs(lifecycle),
		"stage": {"transaction_id": transaction_id},
		"publication": {
			"transaction_id": transaction_id,
			"signals": signals,
		},
		"duplicate": duplicate,
		"stored_receipt": stored_receipt,
	}}

func capture() -> Dictionary:
	var backup := {
		"lifecycle": _game_state._run_lifecycle.to_dict(),
		"contacts": (_game_state.contacts as Dictionary).duplicate(true),
		"gameplay": _game_state.capture_run_snapshot_input()["gameplay"].duplicate(true),
		"committed_schedule": _game_state._committed_schedule.duplicate(true),
	}
	if _day_view != null:
		var view: Dictionary = _day_view.snapshot()
		if not view.get("ok", false): return view
		backup["schedule_view"] = view.value.view.duplicate(true)
		backup["desktop"] = {"board": _day_board.capture(),
			"consequence": _day_consequence.capture().value.state}
	return {"ok": true, "code": &"ok", "value": {"backup": backup}}

func commit(candidate: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var prepared: Dictionary = lifecycle.prepare_restore(candidate["lifecycle"])
	if not prepared.get("ok", false):
		return prepared
	var committed: Dictionary = lifecycle.commit_restore(prepared["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	if candidate.has("contacts"):
		var validated: Dictionary = CONTACT_STATE.validate_state(candidate["contacts"])
		if not validated.get("ok", false):
			return validated
		_game_state.contacts = (candidate["contacts"] as Dictionary).duplicate(true)
	if candidate.has("gameplay"):
		_game_state._apply_gameplay_silent(candidate["gameplay"])
	if candidate.has("committed_schedule"):
		_game_state._committed_schedule = candidate["committed_schedule"].duplicate(true)
	var installed := _install_day_owners(candidate)
	if not installed.get("ok", false): return installed
	return committed

func rollback(backup: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var restored: Dictionary = lifecycle.prepare_restore(backup["lifecycle"])
	if not restored.get("ok", false):
		return restored
	var committed: Dictionary = lifecycle.commit_restore(restored["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	if backup.has("contacts"):
		_game_state.contacts = (backup["contacts"] as Dictionary).duplicate(true)
	if backup.has("gameplay"):
		_game_state._apply_gameplay_silent(backup["gameplay"])
	if backup.has("committed_schedule"):
		_game_state._committed_schedule = backup["committed_schedule"].duplicate(true)
	var installed := _install_day_owners(backup)
	if not installed.get("ok", false): return installed
	return committed

func prepare_day_advance_source(snapshot: Dictionary) -> Dictionary:
	if _identity_issuer == null:
		return {"ok": false, "code": &"day_advance_source_unavailable"}
	var root: Dictionary = _identity_issuer.capture_root()
	if not root.get("ok", false): return root
	var source: Dictionary = preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd").schedule_day_advance_source(snapshot, root.value)
	if not source.get("ok", false): return source
	var start: Dictionary = snapshot.active_resolution_plan.day_resolution_start_receipt
	var original: Dictionary = _identity_issuer.validate_child(start.receipt_provenance, &"day_resolution_stage")
	if not original.get("ok", false): return original
	if source.value.has("source_resolution_receipt"): return source
	var derived: Dictionary = _identity_issuer.derive_child(source.value.derivation_request)
	if not derived.get("ok", false): return derived
	var checked: Dictionary = _identity_issuer.validate_child(derived.value.provenance, &"day_resolution_stage")
	if not checked.get("ok", false): return checked
	return {"ok": true, "value": {"source_resolution_receipt": {
		"receipt_id": str(derived.value.child_id), "provenance": derived.value.provenance.duplicate(true)}}}

func _validate_day_advance(snapshot: Dictionary, value: Dictionary) -> Dictionary:
	if _identity_issuer == null or _day_view == null:
		return {"ok": false, "code": &"day_advance_owners_unconfigured"}
	var allocation: Dictionary = value.get("day_advance_identity_receipt", {})
	var resolved := prepare_day_advance_source(snapshot)
	if not resolved.get("ok", false): return resolved
	var identity: Dictionary = resolved.value.source_resolution_receipt
	if str(allocation.get("resolution_kind", "")) != "schedule_done" \
			or allocation.get("source_resolution_receipt_id") != identity.receipt_id \
			or allocation.get("source_resolution_receipt_provenance") != identity.provenance \
			or allocation.get("source_resolution_receipt_sha256") != _sha256(identity):
		return {"ok": false, "code": &"day_advance_allocation_conflict"}
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation"]:
		if allocation.get(key) != snapshot.get(key):
			return {"ok": false, "code": &"day_advance_allocation_conflict"}
	if allocation.get("source_day") != snapshot.day or allocation.get("target_day") != int(snapshot.day) + 1 			or allocation.get("source_causal_day_instance") != snapshot.causal_day_instance 			or allocation.get("source_causal_day_instance_issuer_receipt") != snapshot.causal_day_instance_issuer_receipt:
		return {"ok": false, "code": &"day_advance_allocation_conflict"}
	for key: String in ["source_day", "target_day", "source_causal_day_instance", 			"target_causal_day_instance", "target_causal_day_instance_issuer_receipt"]:
		if value.get(key) != allocation.get(key):
			return {"ok": false, "code": &"day_advance_allocation_conflict"}
	var root: Dictionary = _identity_issuer.capture_root()
	if not root.get("ok", false): return root
	if root.value.get("day_advance_allocation_receipts", {}).get(str(allocation.get("allocation_key", ""))) != allocation:
		return {"ok": false, "code": &"day_advance_allocation_not_durable"}
	return _identity_issuer.verify_issued(allocation.target_causal_day_instance_issuer_receipt, &"causal_day_instance")

func _prepare_new_day_owners(value: Dictionary) -> Dictionary:
	var view: Dictionary = DAY_VIEW.make_empty(int(value.target_day), str(value.target_causal_day_instance))
	if not view.get("ok", false): return view
	var live_view: Dictionary = _day_view.snapshot()
	if not live_view.get("ok", false): return live_view
	view.value.view.condition_departure_receipts = live_view.value.view.condition_departure_receipts.duplicate(true)
	var consequence: Dictionary = DAY_CONSEQUENCE.make_empty({
		"causal_day_instance": value.target_causal_day_instance,
		"causal_day_instance_issuer_receipt": value.target_causal_day_instance_issuer_receipt})
	if not consequence.get("ok", false): return consequence
	return {"ok": true, "value": {"schedule_view": view.value.view,
		"desktop": {"board": DAY_BOARD.new().capture(), "consequence": consequence.value.state},
		"committed_schedule": {"schema_version": 1, "day": int(value.target_day),
			"registry_fingerprint": null, "entries": [], "commit_receipt": null}}}

func _install_day_owners(candidate: Dictionary) -> Dictionary:
	if not candidate.has("desktop"): return {"ok": true}
	if _day_view == null: return {"ok": false, "code": &"day_advance_owners_unconfigured"}
	for pair: Array in [["board", _day_board], ["consequence", _day_consequence]]:
		var prepared: Dictionary = pair[1].prepare_restore(candidate.desktop[pair[0]])
		if not prepared.get("ok", false): return prepared
		var installed: Dictionary = pair[1].commit(prepared.value.candidate)
		if not installed.get("ok", false): return installed
	var view: Dictionary = _day_view.install_restored_view(candidate.schedule_view)
	if not view.get("ok", false): return view
	_game_state._desktop_snapshot = candidate.desktop.duplicate(true)
	return {"ok": true}

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

func configure_resolution_identity(identity_issuer: Object, start_port: Object) -> Dictionary:
	if identity_issuer == null or not _has_methods(identity_issuer, _ISSUER_METHODS) 			or start_port == null or not _has_methods(start_port, _START_PORT_METHODS):
		return {"ok": false, "code": &"resolution_identity_conflict",
			"message": "an exact issuer and day-resolution start port are required", "details": {}}
	if _identity_issuer != null or _day_resolution_start_port != null:
		if _identity_issuer != identity_issuer or _day_resolution_start_port != start_port:
			return {"ok": false, "code": &"resolution_identity_conflict",
				"message": "a configured port never adopts a replacement identity owner",
				"details": {}}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_identity_issuer = identity_issuer
	_day_resolution_start_port = start_port
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


func configure_desktop_consequence_source(source: Object) -> Dictionary:
	if source == null or not _has_methods(source, _CONSEQUENCE_SOURCE_METHODS):
		return {"ok": false, "code": &"desktop_consequence_source_conflict",
			"message": "an exact board-fate and condition receipt source is required", "details": {}}
	if _desktop_consequence_source != null:
		if _desktop_consequence_source != source:
			return {"ok": false, "code": &"desktop_consequence_source_conflict",
				"message": "a configured port never adopts a replacement source", "details": {}}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_desktop_consequence_source = source
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


func is_presentation_producer_ready() -> bool:
	return _identity_issuer != null and _day_resolution_start_port != null 		and _desktop_consequence_source != null


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	if target == null:
		return false
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true


func configure_day7_provenance(service: Object) -> Dictionary:
	if service == null or not service.has_method("validate_handoff"):
		return {"ok": false, "code": &"invalid_day7_provenance_service", "message": "", "details": {}}
	if _day7_provenance != null:
		if _day7_provenance == service:
			return {"ok": true, "code": &"ok", "value": {"configured": true}, "receipt": {}}
		return {"ok": false, "code": &"day7_provenance_already_configured", "message": "",
			"details": {}}
	_day7_provenance = service
	return {"ok": true, "code": &"ok", "value": {"configured": true}, "receipt": {}}


func _committed_entry_receipt_ids(owning_stage_id: String) -> Array:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return []
	var receipt_ids: Array = []
	for stage_value: Variant in ((plan as Dictionary).get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("stage_id", "")) != owning_stage_id:
			continue
		for substage_value: Variant in (stage.get("substages", []) as Array):
			var parts: PackedStringArray = str(
				(substage_value as Dictionary)["substage_id"]).split(":")
			if parts.size() == 4:
				receipt_ids.append(parts[3])
	return receipt_ids


func _active_source_day() -> int:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) == TYPE_DICTIONARY and (plan as Dictionary).has("source_day"):
		return int((plan as Dictionary)["source_day"])
	return int(_game_state._run_lifecycle.get_day())


func _immediate_receipt(stage_id: String, presented: bool = false) -> Dictionary:
	var day: int = _active_source_day()
	match stage_id:
		"lock_day":
			return _envelope("day_resolution_coordinator", "day_lock", {"locked": true})
		"validate_schedule":
			return _envelope("schedule_rules", "schedule_validation",
				{"schedule_digest": "digest-day-%d" % day, "ordered_entry_ids": []})
		"execute_schedule_actions":
			return _envelope("schedule_rules", "schedule_actions_complete",
				{"entry_receipt_ids": _committed_entry_receipt_ids("execute_schedule_actions")})
		"execute_schedule_dates":
			return _envelope("schedule_rules", "schedule_dates_complete",
				{"entry_receipt_ids": _committed_entry_receipt_ids("execute_schedule_dates"),
					"superseded_entry_ids": _superseded_entry_ids()})
		"commit_outcomes":
			return _envelope("game_state", "outcomes_commit", {"outcome_ids": [], "effect_transaction_ids": []})
		"hospital_if_triggered":
			return _envelope("hospital_rules", "hospital_resolution", _hospital_envelope(presented))
		"twofriends_if_deferred":
			return _envelope("contact_invitation_state", "twofriends_resolution",
				{"required": not _deferred_pair_entry_id().is_empty(),
					"route_receipt_id": null, "message_transaction_ids": [],
					"presentation_completion_receipt": null})
		"invitation_rollover":
			return _envelope("contact_invitation_state", "invitation_rollover",
				{"target_day": day + 1, "message_transaction_ids": []})
		"increment_day":
			return _envelope("run_lifecycle", "day_increment", {"source_day": day, "target_day": day + 1})
		"reset_day_scope":
			return _envelope("game_state", "day_scope_reset", {"target_day": day + 1, "reset_ids": ["motivation", "minesweeper_daily",
					"condition_daily", "contacts_daily", "pending_dates", "committed_schedule"]})
		"new_day_autosave":
			return _envelope("save_manager", "disk_checkpoint_request",
				{"save_kind": "autosave", "save_reason": "day_start"})
		"unlock_day":
			return _envelope("day_resolution_coordinator", "day_unlock", {"locked": false})
		"close_invitations_run_end":
			return _envelope("contact_invitation_state", "run_end_close", {"resolved_action_ids": []})
		"validate_day7_provenance":
			var validated: Dictionary = _day7_terminal_provenance()
			return _envelope("day7_schedule_provenance", "day7_provenance_validation", {
				"cause": str(validated["cause"]),
				"schedule_entry_id": validated["schedule_entry_id"],
				"source_receipt_id": validated["source_receipt_id"],
			})
		"checkpoint_day7_provenance":
			var terminal: Dictionary = _day7_terminal_provenance()
			return _envelope("day7_schedule_provenance", "day7_provenance_checkpoint", {
				"cause": str(terminal["cause"]),
				"schedule_commit_receipt_id": terminal["schedule_commit_receipt_id"],
				"day7_provenance_receipt_id": str(terminal["receipt_id"]),
				"day7_provenance_receipt_provenance":
					(terminal["receipt_provenance"] as Dictionary).duplicate(true),
			})
		"resolve_ending_plan":
			return _envelope("dating_ending_rules", "ending_resolution", {"ending_plan": _default_ending_plan()})
		"enter_ending":
			return _envelope("run_lifecycle", "enter_ending",
				{"state": "ENDING", "primary_id": _resolved_primary_id(), "epilogue_id": _resolved_epilogue_id()})
		"ending_autosave":
			return _envelope("save_manager", "disk_checkpoint_request",
				{"save_kind": "autosave", "save_reason": "ending"})
	return _envelope("unknown", "unknown", {})


const HOSPITAL_TIMELINE_ID := "hospital.faint"
const PAIR_PARTICIPANTS: Array[String] = ["priscilla", "lavinia"]
const PAIR_SLUG := "priscilla_lavinia"
const DATING_TIMELINE_PHASE := "pre_challenge"

const HOSPITAL_STAGE := "hospital_if_triggered"
const DATES_STAGE := "execute_schedule_dates"
const PAIR_STAGE := "twofriends_if_deferred"

const INTENT_ROLE := "presentation.intent"
const COMPLETION_ROLE := "presentation.completion"
const PRESENTATION_CHILD_KIND := &"day_resolution_stage"
const HOSPITAL_RESOLUTION_ROLE := "hospital.resolution"
const HOSPITAL_RESOLUTION_CHILD_KIND := &"hospital_resolution"
const HOSPITAL_MISS_ROLE := "hospital.miss"
const HOSPITAL_MISS_CHILD_KIND := &"hospital_miss"


func _prepare_pair_presentation(site: Dictionary) -> Dictionary:
	var pair_site: bool = site.get("kind") == "twofriends_if_deferred"
	if site.get("kind") == "surviving_date":
		pair_site = _route_plan_entry(str(site.get("schedule_entry_id", ""))).get("action_kind") == "group"
	if not pair_site: return {"ok": true}
	if _pair_deck == null: return {"ok": false, "code": &"pair_deck_unconfigured"}
	return _pair_deck.prepare_schedule(true)


static func _pair_window_counts(window: Variant) -> bool:
	return window is Dictionary and bool(window.get("counts", false))


func _presentation_site(stage: Dictionary) -> Dictionary:
	var stage_id := str(stage.get("stage_id", ""))
	var substage_id := str(stage.get("substage_id", ""))
	if substage_id.begins_with("surviving_date:"):
		return _surviving_date_site(substage_id)
	if substage_id != "":
		return {}
	if stage_id == HOSPITAL_STAGE:
		return _hospital_site()
	if stage_id == PAIR_STAGE:
		return _deferred_pair_site()
	return {}


func _hospital_site() -> Dictionary:
	var required: bool = bool(_game_state.should_route_hospital()) \
		if _game_state.has_method("should_route_hospital") else false
	if not required:
		return {}
	return {"kind": "hospital", "stage_name": HOSPITAL_STAGE, "route_id": "hospital",
		"schedule_entry_id": null}


func _surviving_date_site(substage_id: String) -> Dictionary:
	var parts: PackedStringArray = substage_id.split(":")
	if parts.size() != 4:
		return {}
	var entry_id := parts[3]
	if entry_id in _superseded_entry_ids():
		return {}
	return {"kind": "surviving_date", "stage_name": DATES_STAGE, "route_id": "dating",
		"schedule_entry_id": entry_id}


func _deferred_pair_site() -> Dictionary:
	var committed_id: String = _hospital_deferred_pair_entry_id()
	if not committed_id.is_empty():
		return {"kind": "twofriends_if_deferred", "stage_name": PAIR_STAGE,
			"route_id": "dating", "schedule_entry_id": committed_id}
	var preview: Dictionary = _deferred_pair_preview()
	if preview.get("ok", false) and not bool(preview.value.get("required", false)): return {}
	return {"kind": "twofriends_if_deferred", "stage_name": PAIR_STAGE,
		"route_id": "dating", "schedule_entry_id": str(preview.get("value", {}).get("action_id", "")),
		"pair_preview": preview.duplicate(true)}


static func _top_level_stage_transaction_id(plan: Dictionary, stage_id: String) -> String:
	for stage_value: Variant in (plan.get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("stage_id", "")) == stage_id:
			return str(stage.get("transaction_id", ""))
	return ""


func _deferred_pair_entry_id() -> String:
	var committed_id: String = _hospital_deferred_pair_entry_id()
	if not committed_id.is_empty(): return committed_id
	var preview: Dictionary = _deferred_pair_preview()
	if not preview.get("ok", false) or not bool(preview.value.get("required", false)): return ""
	return str(preview.value.action_id)

func _hospital_deferred_pair_entry_id() -> String:
	var superseded: Array = _superseded_entry_ids()
	for entry_value: Variant in _active_committed_entries():
		var entry: Dictionary = entry_value
		if str(entry.get("action_kind", "")) == "group" \
				and str(entry.get("schedule_entry_id", "")) in superseded:
			return str(entry.schedule_entry_id)
	return ""

func _deferred_pair_preview() -> Dictionary:
	var plan: Dictionary = _active_plan()
	var day: int = int(plan.get("source_day", 0))
	if day not in [2, 6]: return {"ok": true, "value": {"required": false}}
	var contacts: Dictionary = _game_state.contacts
	var checked: Dictionary = CONTACT_STATE.validate_state(contacts)
	if not checked.get("ok", false): return checked
	var rollover_id: String = _top_level_stage_transaction_id(plan, "invitation_rollover")
	if rollover_id.is_empty(): return {"ok": false, "code": &"pair_closure_source_unavailable"}
	var prepared: Dictionary = _prepare_contacts_day_end(rollover_id)
	if not prepared.get("ok", false): return prepared
	var window: Variant = prepared.receipt.get("pl_window")
	if not window is Dictionary or not bool(window.get("visible", false)) \
			or str(window.get("outcome", "")) not in ["missed", "private_visible"]:
		return {"ok": true, "value": {"required": false}}
	var group: Dictionary = contacts.group_action
	var action_id: String = str(group.get("action_id", ""))
	var activation_id: String = str(group.get("transaction_id", ""))
	var activation: Variant = contacts.transaction_receipts.get(activation_id)
	if group.get("day") != day or not activation is Dictionary \
			or activation.get("kind") != "activate_group" or activation.get("action_id") != action_id \
			or activation.get("day") != day or activation.get("transaction_id") != activation_id:
		return {"ok": false, "code": &"pair_activation_source_unavailable"}
	var source_ids: Array = [action_id, activation_id]
	for operation: Dictionary in contacts.transaction_receipts.values():
		if operation.get("action_id") != action_id or operation.get("day") != day \
				or operation.get("kind") not in ["open_group_first", "open_group_second", "reply_group"]: continue
		if _identity_issuer == null: return {"ok": false, "code": &"pair_source_issuer_unavailable"}
		var verified: Dictionary = _identity_issuer.verify_issued(operation.command_issuer_receipt,
			ROOT_PURPOSE)
		if not verified.get("ok", false): return verified
		source_ids.append(str(operation.transaction_id))
		if operation.has("source_receipt_id"):
			var source: Dictionary = contacts.schedule_source_receipts[str(operation.source_receipt_id)]
			var proven: Dictionary = _identity_issuer.validate_child(source.receipt_provenance, &"contact_source")
			if not proven.get("ok", false): return proven
			source_ids.append(str(operation.source_receipt_id))
	for stage: Dictionary in plan.get("stages", []):
		if stage.get("stage_id") == "hospital_if_triggered" and stage.get("state") == "completed":
			source_ids.append(str(stage.transaction_id))
		if stage.get("stage_id") != "execute_schedule_dates": continue
		for substage: Dictionary in stage.get("substages", []):
			if substage.get("state") == "completed": source_ids.append(str(substage.transaction_id))
	return {"ok": true, "value": {"required": true, "action_id": action_id,
		"source_day": day, "resolution_id": str(plan.get("resolution_id", "")),
		"input_receipt_ids": _id_list(source_ids), "closure_receipt": prepared.receipt.duplicate(true)}}

func _validated_pair_preview(site: Dictionary) -> Dictionary:
	var preview: Variant = site.get("pair_preview")
	if not preview is Dictionary or not preview.get("ok", false):
		return preview if preview is Dictionary else {"ok": false, "code": &"pair_source_unavailable"}
	var current: Dictionary = _deferred_pair_preview()
	if current != preview or not bool(current.get("value", {}).get("required", false)) \
			or str(site.get("schedule_entry_id", "")) != str(current.value.get("action_id", "")):
		return {"ok": false, "code": &"pair_source_changed"}
	return current


func _presentation_command(stage: Dictionary, site: Dictionary) -> Dictionary:
	var plan := _active_plan()
	var root: Variant = plan.get("resolution_issuer_receipt")
	var start: Variant = plan.get("day_resolution_start_receipt")
	if typeof(root) != TYPE_DICTIONARY or typeof(start) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"presentation_intent_unavailable",
			"message": "this resolution persisted no root, so no presentation child can be derived"
				+ " (the Plan-02 desktop consequence source is unconfigured)",
			"details": {"stage_id": str(stage.get("stage_id", ""))}}
	if _identity_issuer == null:
		return {"ok": false, "code": &"presentation_intent_unavailable",
			"message": "this port has no configured identity issuer to derive a presentation under",
			"details": {"stage_id": str(stage.get("stage_id", ""))}}
	var stage_child_id := _top_level_stage_transaction_id(plan, str(stage.get("stage_id", "")))
	if stage_child_id.is_empty():
		return {"ok": false, "code": &"presentation_intent_unavailable",
			"message": "this resolution carries no top-level stage for this presentation",
			"details": {"stage_id": str(stage.get("stage_id", ""))}}

	var hospital_rows: Dictionary = {}
	if str(site["kind"]) == "hospital":
		var derived_rows := _derive_hospital_rows(plan, root as Dictionary, start as Dictionary)
		if not derived_rows.get("ok", false):
			return derived_rows
		hospital_rows = derived_rows["value"]

	var context := _presentation_context(site, plan, hospital_rows)
	if context.is_empty():
		return {"ok": false, "code": &"invalid_presentation_context",
			"message": "the frozen presentation context is not derivable", "details": {}}
	if str(site.kind) == "hospital" and _frozen_hospital_contexts_enabled:
		var frozen := HOSPITAL_CONTEXT.from_schedule(context, _game_state.contacts, _active_committed_entries())
		if not frozen.get("ok", false): return frozen
		context = frozen.value
	var timeline_id := _presentation_timeline_id(context)
	if timeline_id.is_empty():
		return {"ok": false, "code": &"unregistered_presentation_timeline",
			"message": "no registered locator exists for this presentation", "details": {}}
	var inputs := _presentation_inputs(site, hospital_rows)
	if not inputs.get("ok", false):
		return inputs
	var ordinal := _presentation_ordinal(site)
	if ordinal < 0:
		return {"ok": false, "code": &"invalid_presentation_ordinal",
			"message": "the within-stage presentation ordinal is not derivable", "details": {}}
	var stage_index := _stage_index(str(site["stage_name"]), int(plan["source_day"]))
	if stage_index < 0:
		return {"ok": false, "code": &"invalid_presentation_stage_index",
			"message": "this stage is not in the frozen stage array for this day", "details": {}}

	var context_hash := _sha256(context)
	if context_hash.is_empty():
		return {"ok": false, "code": &"invalid_presentation_context",
			"message": "the context is not canonically hashable", "details": {}}
	var root_receipt: Dictionary = root
	var start_receipt: Dictionary = start
	var intent := _derive_row(str(root_receipt["receipt_id"]), PRESENTATION_CHILD_KIND, ordinal, [
		_project("role", INTENT_ROLE),
		_project("resolution_id", str(plan["resolution_id"])),
		_project("causal_day_instance", str(start_receipt["causal_day_instance"])),
		_project("source_day", int(plan["source_day"])),
		_project("day_resolution_start_receipt_id", str(start_receipt["receipt_id"])),
		_project("stage_name", str(site["stage_name"])),
		_project("stage_index", stage_index),
		_project("presentation_kind", str(context["kind"])),
		_project("schedule_entry_id", site["schedule_entry_id"]),
		_project("route_id", str(site["route_id"])),
		_project("timeline_id", timeline_id),
		_project("context_sha256", context_hash),
		_project("input_receipt_ids", (inputs["value"] as Dictionary)["input_receipt_ids"]),
	])
	if not intent.get("ok", false):
		return intent
	var intent_id := str((intent["value"] as Dictionary)["child_id"])

	var completion := _derive_row(str(root_receipt["receipt_id"]), PRESENTATION_CHILD_KIND, ordinal, [
		_project("role", COMPLETION_ROLE),
		_project("resolution_id", str(plan["resolution_id"])),
		_project("stage_id", stage_child_id),
		_project("substage_id", intent_id),
		_project("route_id", str(site["route_id"])),
		_project("timeline_id", timeline_id),
		_project("context_sha256", context_hash),
	])
	if not completion.get("ok", false):
		return completion

	var request := {
		"resolution_id": str(plan["resolution_id"]),
		"resolution_issuer_receipt": root_receipt.duplicate(true),
		"stage_id": stage_child_id,
		"substage_id": intent_id,
		"route_id": str(site["route_id"]),
		"timeline_id": timeline_id,
		"context": context,
		"completion_transaction_id": str((completion["value"] as Dictionary)["child_id"]),
		"completion_transaction_provenance":
			((completion["value"] as Dictionary)["provenance"] as Dictionary).duplicate(true),
	}
	if str(site.kind) == "hospital" and _frozen_hospital_contexts_enabled:
		var retained: Dictionary = _game_state.retain_hospital_presentation_request(request)
		if not retained.get("ok", false): return retained
		request = retained.value
	return {"ok": true, "code": &"ok", "value": {"presentation_request": request}}


func _presentation_context(site: Dictionary, plan: Dictionary,
		hospital_rows: Dictionary) -> Dictionary:
	var day := int(plan["source_day"])
	if str(site["kind"]) == "hospital":
		var source_entry_ids := _id_list(hospital_rows["date_schedule_entry_ids"] as Array)
		var miss_ids := _id_list(hospital_rows["hospital_miss_receipt_ids"] as Array)
		return {"kind": "hospital", "day": day, "source_entry_ids": source_entry_ids,
			"miss_receipt_ids": miss_ids}
	if site.has("pair_preview"):
		var preview: Dictionary = _validated_pair_preview(site)
		if not preview.get("ok", false): return {}
		return {"kind": "twofriends_if_deferred", "day": day,
			"schedule_entry_id": str(preview.value.action_id), "participants": PAIR_PARTICIPANTS.duplicate()}
	var entry := _committed_entry(str(site["schedule_entry_id"]))
	if entry.is_empty():
		return {}
	var kind := "twofriends_if_deferred" if str(site["kind"]) == "twofriends_if_deferred" \
		else str(entry.get("action_kind", ""))
	var participants: Array[String] = []
	if kind == "twofriends_if_deferred" or kind == "group":
		participants = PAIR_PARTICIPANTS.duplicate()
	else:
		for participant: Variant in (entry.get("participants", []) as Array):
			participants.append(str(participant))
	return {"kind": kind, "day": day, "schedule_entry_id": str(site["schedule_entry_id"]),
		"participants": participants}


func _presentation_timeline_id(context: Dictionary) -> String:
	var day := int(context["day"])
	var timeline_id := ""
	match str(context["kind"]):
		"hospital":
			timeline_id = HOSPITAL_TIMELINE_ID
		"solo":
			var participants: Array = context["participants"]
			if participants.size() != 1:
				return ""
			timeline_id = "dating.solo.%s.day%d.%s" % [
				str(participants[0]), day, DATING_TIMELINE_PHASE]
		"group":
			timeline_id = "dating.group.%s.day%d.%s" % [PAIR_SLUG, day, DATING_TIMELINE_PHASE]
		"twofriends_if_deferred":
			timeline_id = "dating.twofriends.%s.day%d.%s" % [PAIR_SLUG, day, DATING_TIMELINE_PHASE]
		_:
			return ""
	return timeline_id if DialogicTimelineCatalog.has_timeline_id(timeline_id) else ""


func _presentation_inputs(site: Dictionary, hospital_rows: Dictionary) -> Dictionary:
	if str(site["kind"]) == "hospital":
		var ids: Array = [str(hospital_rows["condition_receipt_id"])]
		ids.append_array(hospital_rows["hospital_miss_receipt_ids"] as Array)
		return {"ok": true, "code": &"ok", "value": {"input_receipt_ids": _id_list(ids)}}
	if site.has("pair_preview"):
		var preview: Dictionary = _validated_pair_preview(site)
		if not preview.get("ok", false): return preview
		return {"ok": true, "code": &"ok", "value": {
			"input_receipt_ids": preview.value.input_receipt_ids.duplicate()}}
	var entry := _committed_entry(str(site["schedule_entry_id"]))
	if entry.is_empty():
		return {"ok": false, "code": &"invalid_presentation_intent",
			"message": "no committed entry backs this presentation", "details": {}}
	var source_receipt_id: Variant = entry.get("source_receipt_id")
	if typeof(source_receipt_id) != TYPE_STRING or str(source_receipt_id).is_empty():
		return {"ok": false, "code": &"invalid_presentation_intent",
			"message": "a committed date presents only under its own source receipt", "details": {}}
	return {"ok": true, "code": &"ok", "value": {"input_receipt_ids": _id_list([
		str(site["schedule_entry_id"]), str(source_receipt_id)])}}


func _derive_hospital_rows(plan: Dictionary, root: Dictionary, start: Dictionary) -> Dictionary:
	if _desktop_consequence_source == null:
		return {"ok": false, "code": &"condition_receipt_unavailable",
			"message": "a Hospital resolution projects the Plan-02 condition receipt", "details": {}}
	var condition: Variant = _desktop_consequence_source.call(&"resolve_condition_receipt", {
		"causal_day_instance": str(start["causal_day_instance"]),
		"source_day": int(plan["source_day"]),
	})
	if typeof(condition) != TYPE_DICTIONARY or not (condition as Dictionary).get("ok", false):
		return condition if typeof(condition) == TYPE_DICTIONARY else {
			"ok": false, "code": &"condition_receipt_unavailable",
			"message": "the desktop consequence source returned no CommandResult", "details": {}}
	var condition_receipt: Variant = ((condition as Dictionary)["value"] as Dictionary).get(
		"condition_receipt")
	if typeof(condition_receipt) != TYPE_DICTIONARY \
			or str((condition_receipt as Dictionary).get("receipt_id", "")).is_empty():
		return {"ok": false, "code": &"condition_receipt_unavailable",
			"message": "the condition receipt carries no receipt_id", "details": {}}
	var condition_receipt_id := str((condition_receipt as Dictionary)["receipt_id"])

	var planned: Dictionary = HOSPITAL_RULES.plan_resolution({
		"required": true,
		"source_day": int(plan["source_day"]),
		"committed_entries": _active_committed_entries(),
	})
	if not planned.get("ok", false):
		return planned
	var planned_value: Dictionary = planned["value"]
	var parent_id := str(root["receipt_id"])
	var resolution_row := _derive_row(parent_id, HOSPITAL_RESOLUTION_CHILD_KIND, 0, [
		_project("role", HOSPITAL_RESOLUTION_ROLE),
		_project("resolution_id", str(plan["resolution_id"])),
		_project("causal_day_instance", str(start["causal_day_instance"])),
		_project("source_day", int(plan["source_day"])),
		_project("day_resolution_start_receipt_id", str(start["receipt_id"])),
		_project("schedule_commit_receipt_id", plan.get("schedule_commit_receipt_id")),
		_project("condition_receipt_id", condition_receipt_id),
		_project("date_schedule_entry_ids", planned_value["date_schedule_entry_ids"]),
		_project("required", true),
	])
	if not resolution_row.get("ok", false):
		return resolution_row
	var hospital_resolution_id := str((resolution_row["value"] as Dictionary)["child_id"])

	var miss_ids: Array[String] = []
	for miss_value: Variant in (planned_value["misses"] as Array):
		var miss: Dictionary = miss_value
		var miss_row := _derive_row(parent_id, HOSPITAL_MISS_CHILD_KIND, int(miss["ordinal"]), [
			_project("role", HOSPITAL_MISS_ROLE),
			_project("resolution_id", str(plan["resolution_id"])),
			_project("causal_day_instance", str(start["causal_day_instance"])),
			_project("source_day", int(plan["source_day"])),
			_project("hospital_resolution_id", hospital_resolution_id),
			_project("schedule_entry_id", str(miss["schedule_entry_id"])),
			_project("action_id", str(miss["action_id"])),
			_project("source_receipt_id", miss["source_receipt_id"]),
			_project("reason", str(miss["reason"])),
		])
		if not miss_row.get("ok", false):
			return miss_row
		miss_ids.append(str((miss_row["value"] as Dictionary)["child_id"]))
	return {"ok": true, "code": &"ok", "value": {
		"condition_receipt_id": condition_receipt_id,
		"hospital_resolution_id": hospital_resolution_id,
		"hospital_miss_receipt_ids": miss_ids,
		"date_schedule_entry_ids": planned_value["date_schedule_entry_ids"],
	}}


func presentation_stage_receipt(transaction_id: String, completion: Dictionary) -> Dictionary:
	var plan := _active_plan()
	if plan.is_empty():
		return {"ok": false, "code": &"no_active_plan", "message": "", "details": {}}
	for stage_value: Variant in (plan.get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("transaction_id", "")) == transaction_id:
			if not str(stage["stage_id"]) in [HOSPITAL_STAGE, PAIR_STAGE]:
				return {"ok": false, "code": &"invalid_presentation_stage",
					"message": str(stage["stage_id"]), "details": {}}
			var envelope := _immediate_receipt(str(stage["stage_id"]), true)
			(envelope["value"] as Dictionary)["presentation_completion_receipt"] = 				completion.duplicate(true)
			return {"ok": true, "code": &"ok", "value": {"receipt": envelope}}
		for substage_value: Variant in (stage.get("substages", []) as Array):
			var substage: Dictionary = substage_value
			if str(substage.get("transaction_id", "")) != transaction_id:
				continue
			var substage_id := str(substage["substage_id"])
			if not substage_id.begins_with("surviving_date:"):
				return {"ok": false, "code": &"invalid_presentation_substage",
					"message": substage_id, "details": {}}
			var entry_id := substage_id.split(":")[3] if substage_id.split(":").size() == 4 else ""
			if entry_id in _superseded_entry_ids():
				return {"ok": false, "code": &"invalid_presentation_substage",
					"message": substage_id, "details": {}}
			return {"ok": true, "code": &"ok", "value": {"receipt": _envelope(
				"schedule_rules", "schedule_date_complete", {
					"entry_receipt_id": entry_id,
					"superseded": false,
					"reason": null,
					"presentation_completion_receipt": completion.duplicate(true),
				})}}
	return {"ok": false, "code": &"unknown_transaction", "message": transaction_id, "details": {}}


func _presentation_ordinal(site: Dictionary) -> int:
	if str(site["kind"]) != "surviving_date":
		return 0
	var superseded := _superseded_entry_ids()
	var ordered: Array = _active_committed_entries().duplicate(true)
	ordered.sort_custom(func(left: Variant, right: Variant) -> bool:
		return int((left as Dictionary).get("slot_index", 0)) \
			< int((right as Dictionary).get("slot_index", 0)))
	var ordinal := 0
	for entry_value: Variant in ordered:
		var entry: Dictionary = entry_value
		if not (str(entry.get("action_kind", "")) in HOSPITAL_RULES.DATE_KINDS):
			continue
		var entry_id := str(entry.get("schedule_entry_id", ""))
		if entry_id in superseded:
			continue
		if entry_id == str(site["schedule_entry_id"]):
			return ordinal
		ordinal += 1
	return -1


static func _stage_index(stage_name: String, source_day: int) -> int:
	return DAY_RESOLUTION_PLAN.stage_allowlist(source_day).find(stage_name)


func _committed_entry(schedule_entry_id: String) -> Dictionary:
	for entry_value: Variant in _active_committed_entries():
		var entry: Dictionary = entry_value
		if str(entry.get("schedule_entry_id", "")) == schedule_entry_id:
			return entry
	return {}


func _derive_row(parent_receipt_id: String, child_kind: StringName, ordinal: int,
		tokens: Array) -> Dictionary:
	for token: String in tokens:
		if token.is_empty():
			return {"ok": false, "code": &"invalid_presentation_intent",
				"message": "a projection member is not canonically representable", "details": {}}
	var sources: Array = tokens.duplicate()
	sources.sort()
	var derived: Variant = _identity_issuer.call(&"derive_child", {
		"parent_receipt_id": parent_receipt_id,
		"child_kind": child_kind,
		"ordinal": ordinal,
		"source_ids": sources,
	})
	if typeof(derived) != TYPE_DICTIONARY or not (derived as Dictionary).get("ok", false):
		return {"ok": false, "code": &"presentation_identity_unavailable",
			"message": "the issuer refused the derivation",
			"details": {"child_kind": String(child_kind)}}
	var value: Variant = (derived as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("provenance")) != TYPE_DICTIONARY \
			or str((value as Dictionary).get("child_id", "")).is_empty():
		return {"ok": false, "code": &"presentation_identity_unavailable",
			"message": "the issuer returned no full provenance", "details": {}}
	var provenance: Dictionary = (value as Dictionary)["provenance"]
	if (derived as Dictionary).get("receipt") != provenance:
		return {"ok": false, "code": &"presentation_identity_unavailable",
			"message": "the issuer receipt is not byte-equal to its provenance", "details": {}}
	var revalidated: Variant = _identity_issuer.call(&"validate_child", provenance, child_kind)
	if typeof(revalidated) != TYPE_DICTIONARY or not (revalidated as Dictionary).get("ok", false):
		return {"ok": false, "code": &"presentation_identity_unavailable",
			"message": "the issuer refused to revalidate its own child", "details": {}}
	return {"ok": true, "code": &"ok", "value": {
		"child_id": str((value as Dictionary)["child_id"]), "provenance": provenance}}


static func _id_list(ids: Array) -> Array[String]:
	var seen := {}
	var listed: Array[String] = []
	for id_value: Variant in ids:
		var id_text := str(id_value)
		if id_text.is_empty() or seen.has(id_text):
			continue
		seen[id_text] = true
		listed.append(id_text)
	listed.sort()
	return listed


static func _project(path: String, value: Variant) -> String:
	var canonical: Dictionary = SCHEDULE_STATE_SCHEMA.canonical_json(value)
	if not canonical.get("ok", false):
		return ""
	return path + "=" + str((canonical["value"] as Dictionary)["text"])


static func _sha256(value: Variant) -> String:
	var hashed: Dictionary = SCHEDULE_STATE_SCHEMA.canonical_sha256(value)
	if not hashed.get("ok", false):
		return ""
	return str((hashed["value"] as Dictionary)["sha256"])


func _hospital_envelope(presented: bool) -> Dictionary:
	var required := presented
	if not presented:
		required = bool(_game_state.should_route_hospital()) 			if _game_state.has_method("should_route_hospital") else false
	var planned: Dictionary = HOSPITAL_RULES.plan_resolution({
		"required": required,
		"source_day": _active_source_day(),
		"committed_entries": _active_committed_entries(),
	})
	if not planned.get("ok", false):
		return {"required": required, "date_schedule_entry_ids": [],
			"superseded_entry_ids": [], "witness_entry_id": null,
			"presentation_completion_receipt": null}
	var value: Dictionary = planned["value"]
	var superseded: Array[String] = []
	for miss: Variant in (value["misses"] as Array):
		superseded.append(str((miss as Dictionary)["schedule_entry_id"]))
	var witness: Variant = value["witness"]
	return {
		"required": bool(value["required"]),
		"date_schedule_entry_ids": value["date_schedule_entry_ids"],
		"superseded_entry_ids": superseded,
		"witness_entry_id": str((witness as Dictionary)["schedule_entry_id"]) if witness != null else null,
		"presentation_completion_receipt": null,
	}


func _superseded_entry_ids() -> Array:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return []
	for stage_value: Variant in ((plan as Dictionary).get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("stage_id", "")) != "hospital_if_triggered":
			continue
		var receipt: Variant = stage.get("receipt")
		if typeof(receipt) != TYPE_DICTIONARY:
			return []
		var value: Variant = (receipt as Dictionary).get("value")
		if typeof(value) != TYPE_DICTIONARY:
			return []
		var superseded: Variant = (value as Dictionary).get("superseded_entry_ids", [])
		return (superseded as Array) if typeof(superseded) == TYPE_ARRAY else []
	return []

func _day7_handoff() -> Dictionary:
	if _day7_provenance == null:
		return {"ok": false, "code": &"day7_provenance_unconfigured",
			"message": "the Day-7 handoff requires the one configured provenance service",
			"details": {}}
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_provenance_unavailable",
			"message": "no active resolution plan carries a committed Day-7 aggregate",
			"details": {}}
	var committed: Variant = (plan as Dictionary).get("committed_schedule")
	if typeof(committed) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_provenance_unavailable",
			"message": "the active plan carries no committed aggregate", "details": {}}
	var commit_receipt: Variant = (committed as Dictionary).get("commit_receipt")
	if typeof(commit_receipt) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_provenance_unavailable",
			"message": "a receiptless aggregate is not an accepted Day-7 cause", "details": {}}
	var contacts: Variant = _game_state.get("contacts")
	if typeof(contacts) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_source_index_unavailable",
			"message": "the owner exposes no Contacts source receipt index", "details": {}}
	var sources: Variant = (contacts as Dictionary).get("schedule_source_receipts", {})
	if typeof(sources) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_source_index_unavailable",
			"message": "the Contacts source receipt index is malformed", "details": {}}
	return _day7_provenance.call(&"validate_handoff", {
		"transaction_id": str((commit_receipt as Dictionary)["transaction_id"]),
		"transaction_issuer_receipt":
			((commit_receipt as Dictionary)["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": str((commit_receipt as Dictionary)["causal_day_instance"]),
		"committed_schedule": (committed as Dictionary).duplicate(true),
		"source_receipt_index": (sources as Dictionary).duplicate(true),
	})


func _day7_terminal_provenance() -> Dictionary:
	var handoff := _day7_handoff()
	if not handoff.get("ok", false):
		return {"cause": "", "schedule_entry_id": null, "source_receipt_id": null,
			"schedule_commit_receipt_id": null, "receipt_id": "", "receipt_provenance": {}}
	return ((handoff["value"] as Dictionary)["terminal_provenance"] as Dictionary)


func _active_committed_entries() -> Array:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return []
	var aggregate: Variant = (plan as Dictionary).get("committed_schedule")
	if typeof(aggregate) != TYPE_DICTIONARY:
		return []
	var entries: Variant = (aggregate as Dictionary).get("entries", [])
	return (entries as Array) if typeof(entries) == TYPE_ARRAY else []



func prepare_terminal_ending_source() -> Dictionary:
	var snapshot: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = snapshot.get("active_resolution_plan")
	if int(snapshot.get("day", 0)) != 7 or str(snapshot.get("state", "")) != "PLAYING" \
			or not plan is Dictionary or int(plan.get("source_day", 0)) != 7:
		return {"ok": false, "code": &"day7_terminal_source_unavailable"}
	var stored: Dictionary = {}
	for stage: Dictionary in plan.get("stages", []):
		if str(stage.get("state", "")) != "completed":
			return {"ok": false, "code": &"day7_resolution_incomplete"}
		if str(stage.get("stage_id", "")) == "checkpoint_day7_provenance":
			stored = stage.get("receipt", {}).get("value", {}).duplicate(true)
	if stored.is_empty(): return {"ok": false, "code": &"day7_terminal_source_unavailable"}
	var handoff := _day7_handoff()
	if not handoff.get("ok", false): return handoff
	var proof: Dictionary = handoff.value.terminal_provenance
	var expected := {"cause": str(proof.cause), "schedule_commit_receipt_id": proof.schedule_commit_receipt_id,
		"day7_provenance_receipt_id": str(proof.receipt_id),
		"day7_provenance_receipt_provenance": proof.receipt_provenance.duplicate(true)}
	if stored != expected:
		return {"ok": false, "code": &"day7_terminal_source_conflict"}
	return {"ok": true, "value": {"source_kind": "schedule_done", "terminal_provenance": proof.duplicate(true)}}


func _resolved_primary_id() -> String:
	return str(_default_ending_plan().get("ending_id", ""))


func _resolved_epilogue_id() -> Variant:
	var ending_id := str(_default_ending_plan().get("epilogue_ending_id", ""))
	return null if ending_id.is_empty() else ending_id


func _default_ending_plan() -> Dictionary:
	var resolved := _resolved_ending_plan_from_snapshot(_game_state._run_lifecycle.to_dict())
	if not resolved.is_empty(): return resolved
	return _game_state.get_frozen_ordered_ending_plan()


static func _resolved_ending_plan_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var plan: Variant = snapshot.get("active_resolution_plan")
	if not plan is Dictionary: return {}
	for stage: Dictionary in plan.get("stages", []):
		if str(stage.get("stage_id", "")) == "resolve_ending_plan" and str(stage.get("state", "")) == "completed":
			return (stage.get("receipt", {}).get("value", {}).get("ending_plan", {}) as Dictionary).duplicate(true)
	return {}


static func _plan_receipt_for_snapshot(envelope: Dictionary, snapshot: Dictionary) -> Dictionary:
	if str(envelope.get("kind", "")) != "enter_ending":
		return _plan_receipt_from_envelope(envelope)
	var frozen := _resolved_ending_plan_from_snapshot(snapshot)
	if frozen.is_empty():
		return {"value": {"ending_plan": {}}}
	var value: Dictionary = envelope.value
	var epilogue := str(value.epilogue_id) if value.get("epilogue_id") != null else ""
	if str(value.get("primary_id", "")) != str(frozen.get("ending_id", "")) \
			or epilogue != str(frozen.get("epilogue_ending_id", "")):
		return {"value": {"ending_plan": {}}}
	return {"value": {"ending_plan": frozen}}


static func _envelope(owner_id: String, kind: String, value: Dictionary) -> Dictionary:
	return {"owner_id": owner_id, "kind": kind, "value": value}

static func _plan_receipt_from_envelope(envelope: Dictionary) -> Dictionary:
	var value: Dictionary = envelope["value"]
	match str(envelope["kind"]):
		"day_increment":
			var projected := value.duplicate(true)
			projected["day"] = int(value["target_day"])
			return {"value": projected}
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


static func _prepare_schedule_condition_gameplay(gameplay: Dictionary, day: int) -> Dictionary:
	var candidate := gameplay.duplicate(true)
	if day >= 7 or int(candidate.get("condition_resolved_day", 0)) == day: return candidate
	var pressure := int(candidate.stats.pressure)
	var health := int(candidate.stats.health)
	var carried: bool = "sequela" in candidate.condition_effects_today
	var danger: bool = pressure >= 10 or health <= 0
	var triggered := carried and danger
	var condition := "none"
	var penalty := 0
	if danger:
		condition = "dizzy" if pressure >= 10 and health <= 0 else "nausea"
		penalty = mini(maxi(0, pressure - 9) + maxi(0, 1 - health), 6)
		candidate.penalty_points_today = penalty
		candidate.penalty_points_total = mini(int(candidate.penalty_points_total) + penalty, 42)
		candidate.stats.pressure = mini(pressure, 9)
		candidate.stats.health = maxi(health, 1)
		candidate.condition_streak_days = 1
		candidate.condition_effects_today.append(condition)
	if triggered: candidate.condition_effects_today.append("faint")
	candidate.pending_hospital = triggered
	candidate.condition_resolved_day = day
	if triggered:
		candidate.route_context["provisional_hospital_resolution"] = {
			"required": true, "branch": "code_only",
			"recovery": preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd").HOSPITAL_RECOVERY.duplicate(true),
			"condition_input": {"day": day, "pressure": pressure, "health": health, "carried_sequela": carried},
		}
	else:
		candidate.route_context.erase("provisional_hospital_resolution")
	return candidate
