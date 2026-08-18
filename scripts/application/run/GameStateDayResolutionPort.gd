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
## The registry and its pure projector. Route, effects, kind and participants come ONLY from the
## registry the committed aggregate names by fingerprint -- never from a caller field or an
## action-id parse (Plan 01 global constraint; Task 7 Step 7.5).
const SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const SCHEDULE_RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
## The pure Schedule-Done Hospital owner (Task 7 Step 7.3).
const HOSPITAL_RULES := preload("res://scripts/domain/hospital/HospitalRules.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")

const CHECKPOINT_PROVIDER_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint", "route_id",
]
const DEFAULT_ROUTE_ID := "main"
const DEFAULT_CONTENT_VERSION := 1

var _game_state: Object = null
var _checkpoint_providers: Dictionary = {}
var _provider_identity: Dictionary = {}

## The one configured Day-7 provenance service, injected by Bootstrap; never constructed here.
var _day7_provenance: Object = null


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
	# Step 6.6 (dwm-p2r.13): the resolution begins from the owner's REAL canonical committed
	# Schedule. This used to pass a synthetic empty array, which silently claimed "no entries" for
	# every day regardless of what had actually been committed.
	var aggregate: Dictionary = _game_state._canonical_committed_schedule()
	# Task 7 Step 7.5 (dwm-p2r.14): the plan must carry the FROZEN REGISTRY PROJECTION, because the
	# execute stages read each entry's effects out of it. Without this the plan persisted an empty
	# route_plan and no committed ordinary effect could ever be applied.
	var projection := _frozen_route_plan(aggregate)
	if not projection.get("ok", false):
		return projection
	var commit_receipt: Variant = aggregate.get("commit_receipt")
	var commit_receipt_id: Variant = null
	if typeof(commit_receipt) == TYPE_DICTIONARY:
		commit_receipt_id = (commit_receipt as Dictionary).get("receipt_id")
	var begun: Dictionary = lifecycle.begin_day_resolution(
		command_id, aggregate, (projection["value"] as Dictionary)["route_plan"],
		commit_receipt_id, null)
	if not begun.get("ok", false):
		return begun
	return {"ok": true, "code": &"ok",
		"value": {"run_id": str(lifecycle.to_dict()["run_id"])}}


## Projects the committed aggregate through the registry it was COMMITTED against.
##
## The aggregate records the exact `registry_fingerprint` its entries were validated with, so the
## currently loadable registry is accepted only when it is byte-identical. A registry that has moved
## on since the commit fails closed rather than silently re-pricing a committed day.
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

func begin_next_stage() -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var begun: Dictionary = lifecycle.begin_next_stage()
	if not begun.get("ok", false):
		return begun
	var stage: Dictionary = begun["value"]["stage"]
	# An entry SUBSTAGE is not just a second delivery of its parent stage's envelope: an
	# ordinary_action substage is where that entry's registered effects actually reach the owner
	# (Task 7 Step 7.2, dwm-p2r.14).
	var substage_id := str(stage.get("substage_id", ""))
	if substage_id.begins_with("ordinary_action:"):
		return _begin_ordinary_action_substage(stage, substage_id)
	if substage_id.begins_with("surviving_date:"):
		return _begin_surviving_date_substage(stage, substage_id)
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": _immediate_receipt(str(stage["stage_id"])),
	}}


## Commits ONE committed ordinary entry's registered effects through the existing effect
## transaction owner, keyed by that entry's own substage transaction id.
##
## The effect ids come from the plan's persisted `route_plan` -- the frozen registry projection --
## and never from a caller-supplied field, an action-id parse, or a live registry re-read. Because
## GameState.commit_effect_transaction is already idempotent per transaction id, a duplicate
## delivery of the same substage replays its stored receipt instead of applying twice; two repeated
## Rest/Training/Working entries carry DISTINCT substage ids and so apply twice, as the registry
## intends for repeatable actions.
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


## One committed DATE entry, after Hospital has had its say.
##
## A date Hospital superseded completes as a recorded miss and starts no board; only a surviving
## date carries a presentation. Either way the substage completes exactly once, so the plan stays
## resumable and a crash cannot leave a date half-run.
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
		}),
	}}


## The frozen registry projection the ACTIVE plan persisted for one committed entry.
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
				# Already durable. Re-applying it would be a no-op, but building a candidate for it
				# would misrepresent a replay as fresh work.
				return _prepared(transaction_id, receipt, snapshot, true, stage["receipt"])
	var produced := _completed_lifecycle(snapshot, transaction_id, receipt)
	if not produced.get("ok", false):
		return produced
	var prepared := _prepared(transaction_id, receipt, produced["value"]["lifecycle"], false, null)
	# The Hospital stage carries the Contacts half of its own transaction.
	var contacts_candidate := _hospital_contacts_candidate(snapshot, transaction_id, receipt)
	if not contacts_candidate.is_empty():
		((prepared["value"] as Dictionary)["run_candidate"] as Dictionary)["contacts"] = 			contacts_candidate
	return prepared


## The Contacts candidate a completing Hospital stage produces, or {} when it produces none.
##
## Append-only and idempotent: the witness is keyed by the Hospital stage's own transaction id, so
## replaying the same stage rewrites the byte-identical record rather than appending a second one.
## The witness is recomputed from the SAME pure owner that produced the stage envelope, so the two
## can never disagree; the caller's receipt only decides WHETHER a witness exists.
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
	# Contacts joins the backup because the Hospital stage commits the Sylvia witness into the
	# Contacts handoff index in the SAME transaction (Task 7 Step 7.3, dwm-p2r.14). Backing up only
	# the lifecycle would leave a witness behind for a supersession that was rolled back.
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"lifecycle": _game_state._run_lifecycle.to_dict(),
		"contacts": (_game_state.contacts as Dictionary).duplicate(true),
	}}}

## Installs the EXACT lifecycle the checkpoint recorded, rather than re-deriving the completion from
## live state. Re-deriving would let the durable record and the live run drift apart (dwm-7e6).
func commit(candidate: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var prepared: Dictionary = lifecycle.prepare_restore(candidate["lifecycle"])
	if not prepared.get("ok", false):
		return prepared
	var committed: Dictionary = lifecycle.commit_restore(prepared["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	# The Contacts half of the SAME transaction. Validated before install, so a malformed witness
	# can never reach the owner, and absent when the stage produced none.
	if candidate.has("contacts"):
		var validated: Dictionary = CONTACT_STATE.validate_state(candidate["contacts"])
		if not validated.get("ok", false):
			return validated
		_game_state.contacts = (candidate["contacts"] as Dictionary).duplicate(true)
	return committed

func rollback(backup: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var restored: Dictionary = lifecycle.prepare_restore(backup["lifecycle"])
	if not restored.get("ok", false):
		return restored
	var committed: Dictionary = lifecycle.commit_restore(restored["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	# Restore BOTH owners, so a rolled-back Hospital leaves no witness behind.
	if backup.has("contacts"):
		_game_state.contacts = (backup["contacts"] as Dictionary).duplicate(true)
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

## Injects the ONE configured Day-7 provenance service Bootstrap retained (Plan 01 Task 6 Step 6.5,
## dwm-p2r.13).
##
## The service arrives ALREADY CONFIGURED with the exact registry/issuer pair; this port never
## configures it and never constructs one, so there is no second place a Day-7 handoff could be
## minted from a different identity root. Idempotent for the same instance, refuses a replacement.
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


## The committed entry identities the ACTIVE plan froze, in its own persisted substage order.
##
## Read from the plan rather than recomputed from live state: the plan is what the resolution
## actually began from, and live state can legitimately have moved on by the time this stage runs.
## Scoped to ONE entry stage (Task 7, dwm-p2r.14). The ordinary stage and the date stage own
## disjoint substage sets and run on opposite sides of Hospital, so a single flat read across every
## stage would report dates as already executed before Hospital had a chance to supersede them.
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
		"execute_schedule_actions":
			# Step 6.6 (dwm-p2r.13): the receipt ids are READ from the committed substages this
			# plan actually froze, never synthesized. An empty list here now means the committed
			# Schedule was genuinely empty, rather than meaning nobody supplied one.
			return _envelope("schedule_rules", "schedule_actions_complete",
				{"entry_receipt_ids": _committed_entry_receipt_ids("execute_schedule_actions")})
		"execute_schedule_dates":
			# Runs AFTER hospital_if_triggered, so the supersession set is already durable and is
			# READ from that completed stage rather than recomputed here.
			return _envelope("schedule_rules", "schedule_dates_complete",
				{"entry_receipt_ids": _committed_entry_receipt_ids("execute_schedule_dates"),
					"superseded_entry_ids": _superseded_entry_ids()})
		"commit_outcomes":
			return _envelope("game_state", "outcomes_commit", {"outcome_ids": [], "effect_transaction_ids": []})
		"hospital_if_triggered":
			return _envelope("hospital_rules", "hospital_resolution", _hospital_envelope())
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
		"validate_day7_provenance":
			return _envelope("day7_schedule_provenance", "day7_provenance_validation",
				_day7_provenance_facts())
		"checkpoint_day7_provenance":
			var facts: Dictionary = _day7_provenance_facts()
			return _envelope("day7_schedule_provenance", "day7_provenance_checkpoint",
				{"cause": facts["cause"], "schedule_commit_receipt_id": _active_commit_receipt_id()})
		"resolve_ending_plan":
			return _envelope("dating_ending_rules", "ending_resolution", {"ending_plan": _default_ending_plan()})
		"enter_ending":
			return _envelope("run_lifecycle", "enter_ending",
				{"state": "ENDING", "primary_id": _resolved_primary_id(), "epilogue_id": null})
		"ending_autosave":
			return _envelope("save_manager", "disk_checkpoint_request",
				{"save_kind": "autosave", "save_reason": "ending"})
	return _envelope("unknown", "unknown", {})

## The Hospital completion envelope, projected by the pure HospitalRules owner from condition truth
## plus the committed aggregate this plan froze (Task 7 Step 7.3, dwm-p2r.14).
##
## Condition truth comes from the owner's own pending-hospital flag, resolved by the earlier
## commit_outcomes stage -- never from a caller field. When Hospital triggers, EVERY committed date
## is superseded here, before the date stage runs a single board.
func _hospital_envelope() -> Dictionary:
	var required: bool = bool(_game_state.should_route_hospital()) 		if _game_state.has_method("should_route_hospital") else false
	var planned: Dictionary = HOSPITAL_RULES.plan_resolution({
		"required": required,
		"source_day": _active_source_day(),
		"committed_entries": _active_committed_entries(),
	})
	if not planned.get("ok", false):
		# A malformed committed aggregate cannot silently become "no Hospital"; report the
		# supersession set as unknown-empty and let the stage contract reject it.
		return {"required": required, "date_schedule_entry_ids": [],
			"superseded_entry_ids": [], "witness_entry_id": null}
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
	}


## The entry ids Hospital already superseded, read from this plan's COMPLETED hospital stage.
##
## Read from the durable stage receipt rather than recomputed, so a date substage resumed after a
## crash sees exactly the supersession the Hospital transaction committed.
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

## Day-7 provenance facts READ from the committed aggregate the active plan froze (Task 7).
##
## Only two causes exist: a receipt-backed empty Done, and exactly one eligible committed solo.
## Nothing here selects an ending, reads a board, or trusts `date_completed`; Task 8 routes these
## same facts through the configured Day7ScheduleProvenance service and derives the real child.
func _day7_provenance_facts() -> Dictionary:
	var entries: Array = _active_committed_entries()
	if entries.is_empty():
		return {"cause": "empty_done", "schedule_entry_id": null, "source_receipt_id": null}
	var entry: Dictionary = entries[0]
	return {
		"cause": "scheduled_solo",
		"schedule_entry_id": str(entry.get("schedule_entry_id", "")),
		"source_receipt_id": entry.get("source_receipt_id"),
	}


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


func _active_commit_receipt_id() -> Variant:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return null
	return (plan as Dictionary).get("schedule_commit_receipt_id")


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
