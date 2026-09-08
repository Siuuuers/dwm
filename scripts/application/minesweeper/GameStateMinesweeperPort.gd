class_name GameStateMinesweeperPort
extends RefCounted

## Production Minesweeper state port (dwm-p2r.9 Plan 06 Task 2).
##
## Bridges MinesweeperRoundCoordinator to the real GameState facade. It owns NO
## reward, task, or counter rules of its own: every economic effect is produced by
## GameState's existing production functions, applied to a DETACHED GameState clone
## so preparation never mutates live state and never emits a domain signal. Only
## `commit()`/`rollback()` touch live state, and only `publish()` emits.
##
## `latch_fatal`, `is_fatal_latched`, and `guard_external` delegate to the ONE
## already-configured ApplicationMutationGate. This adapter keeps no local fatal
## field and no retained-failure cache; it returns the gate's exact results.

const GAME_STATE_SCRIPT_PATH := "res://autoload/GameState.gd"
const CHECKPOINT_PROVIDER_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint", "route_id",
]
const DEFAULT_ROUTE_ID := "main"
const DEFAULT_CONTENT_VERSION := 1

const COUNTER_KEYS: Array[String] = ["money", "motivation", "app_rounds", "health", "pressure"]

## Task IDs each outcome records, by difficulty. `no_flag` and `foresight` keep the
## approved perfect-equivalent REWARD while recording their own distinct task IDs.
const _COMPLETION_TASK_IDS := {
	"exploded": [],
	"cleared": ["complete_%s"],
	"perfect": ["complete_%s", "perfect_%s"],
	"no_flag": ["complete_%s", "no_flag_finish"],
	"foresight": ["complete_%s", "foresight_finish"],
}

var _game_state: Object = null
var _gate: Object = null
var _checkpoint_providers: Dictionary = {}
var _provider_identity: Dictionary = {}


func _init(game_state: Object = null) -> void:
	_game_state = game_state


## Accepts the ONE ApplicationMutationGate Bootstrap constructed, and proves GameState
## retained that same object. There is no public gate getter on GameState, so identity is
## asserted through the instance id `configure_mutation_gate` already reports.
func configure(mutation_gate: Object) -> Dictionary:
	if _game_state == null:
		return _fail(&"invalid_minesweeper_state_port", "port requires a GameState")
	if mutation_gate == null:
		return _fail(&"invalid_mutation_gate", "gate contract incomplete")
	for method in ["guard_external", "latch_fatal", "is_fatal_latched"]:
		if not mutation_gate.has_method(method):
			return _fail(&"invalid_mutation_gate", "missing method: " + method)
	if not _game_state.has_method("get_mutation_gate_instance_id"):
		return _fail(&"invalid_minesweeper_state_port", "GameState cannot report its gate identity")
	var retained: int = int(_game_state.call(&"get_mutation_gate_instance_id"))
	if retained != mutation_gate.get_instance_id():
		return _fail(&"mutation_gate_identity_mismatch", "GameState retained another gate")
	if _gate != null:
		if _gate == mutation_gate:
			return {"ok": true, "code": &"ok",
				"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return _fail(&"mutation_gate_already_configured", "")
	_gate = mutation_gate
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": false},
		"receipt": {}}


## Takes the EXACT five Callables Bootstrap already handed the day-resolution state port, so
## both checkpoint producers read one set of provider identities.
func configure_checkpoint_providers(providers: Dictionary) -> Dictionary:
	if typeof(providers) != TYPE_DICTIONARY or providers.size() != CHECKPOINT_PROVIDER_KEYS.size():
		return _fail(&"invalid_checkpoint_providers", "providers must be exactly " + str(CHECKPOINT_PROVIDER_KEYS))
	var identity := {}
	for key in CHECKPOINT_PROVIDER_KEYS:
		if not providers.has(key) or typeof(providers[key]) != TYPE_CALLABLE:
			return _fail(&"invalid_checkpoint_providers", "missing or non-Callable provider: " + key)
		var callable: Callable = providers[key]
		if not callable.is_valid() or callable.get_object_id() == 0 or callable.get_argument_count() != 0:
			return _fail(&"invalid_checkpoint_providers", "provider must be a zero-argument Callable with stable identity: " + key)
		identity[key] = [callable.get_object_id(), String(callable.get_method())]
	if not _checkpoint_providers.is_empty():
		if identity == _provider_identity:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"checkpoint_providers_already_configured", "")
	_checkpoint_providers = providers.duplicate()
	_provider_identity = identity
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


# ---- Frozen coordinator port surface ----

func capture() -> Dictionary:
	if _game_state == null:
		return _fail(&"invalid_minesweeper_state_port", "port requires a GameState")
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"save": _game_state.to_save_dict(),
		# Contacts ride the round transaction as a SIBLING section (dwm-p2r.17), mirroring
		# capture_live_run_state: the whitelist walk cannot carry them.
		"contacts": (_game_state.get("contacts") as Dictionary).duplicate(true),
		"run_id": str(lifecycle.get("run_id", "")),
		"day": int(lifecycle.get("day", 1)),
		"next_ordinal": int(_game_state.get("minesweeper_app_rounds_finished_today")) + 1,
	}}}


func prepare_begin(request: Dictionary, round_id: String) -> Dictionary:
	if _game_state == null:
		return _fail(&"invalid_minesweeper_state_port", "port requires a GameState")
	var context := str(request.get("context", ""))
	var difficulty := str(request.get("difficulty", ""))
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var day := int(lifecycle.get("day", 1))
	var ordinal: int = int(_game_state.get("minesweeper_app_rounds_finished_today")) + 1
	var dating_evidence: Variant = null
	if context == "app":
		if not bool(_game_state.call(&"has_minesweeper_app_round_available")):
			return _fail(&"NO_APP_ROUND_AVAILABLE", "no app round remains")
		if int(_game_state.call(&"get_stat", "motivation")) <= 0:
			return _fail(&"INSUFFICIENT_MOTIVATION", "motivation is exhausted")
		if not bool(_game_state.call(&"can_start_minesweeper_app_round")):
			return _fail(&"NO_APP_ROUND_AVAILABLE", "an app round is already unfinished")
	else:
		var resolved := _resolve_dating_evidence()
		if not resolved.get("ok", false):
			return resolved
		dating_evidence = resolved["value"]
	var active_round := {
		"round_id": round_id,
		"run_id": str(lifecycle.get("run_id", "")),
		"context": context,
		"difficulty": difficulty,
		"day": day,
		"ordinal": ordinal,
		"dating_evidence": dating_evidence,
	}
	var clone: Object = _detached_clone()
	if clone == null:
		return _fail(&"invalid_minesweeper_state_port", "could not build a detached candidate")
	if context == "app":
		clone.call(&"start_minesweeper_app_round", difficulty)
	var candidate := {
		"gameplay": clone.call(&"to_save_dict"),
		"contacts": (clone.get("contacts") as Dictionary).duplicate(true),
	}
	clone.free()
	return {"ok": true, "code": &"ok", "value": {
		"candidate": candidate,
		"active_round": active_round.duplicate(true),
		# Captured from the STILL-UNCONSUMED live run: the pre-board checkpoint must record the
		# state a restart would resume from, not the state the round has already spent.
		"pre_board_checkpoint_inputs": _checkpoint_inputs(lifecycle),
		"start_receipt": {
			"round_id": round_id, "context": context, "difficulty": difficulty,
			"day": day, "ordinal": ordinal,
		},
	}}


func prepare_complete(active_round: Dictionary, result: Dictionary, transaction_id: String) -> Dictionary:
	if _game_state == null:
		return _fail(&"invalid_minesweeper_state_port", "port requires a GameState")
	var context := str(active_round.get("context", ""))
	var difficulty := str(active_round.get("difficulty", ""))
	var outcome := str(result.get("outcome", ""))
	# Optional derived reasons are an input only: durable receipts retain their closed schema.
	# Legacy callers without this field keep their existing outcome/task mapping.
	var reasons: Array = []
	if result.has("perfect_reasons"):
		if not result.perfect_reasons is Array:
			return _fail(&"invalid_perfect_reasons", "reasons must be an array")
		for reason: Variant in result.perfect_reasons:
			if not reason is String or reason not in ["efficiency_gt_100", "no_flag"] or reasons.has(reason):
				return _fail(&"invalid_perfect_reasons", "reasons must be distinct known qualifiers")
			reasons.append(reason)
		if (outcome == "perfect") != (not reasons.is_empty()):
			return _fail(&"invalid_perfect_reasons", "derived qualifiers must agree with Perfect outcome")
	var task_ids := _task_ids_for(outcome, difficulty)
	if reasons.has("no_flag"): task_ids.append("no_flag_finish")
	if reasons.has("efficiency_gt_100"): task_ids.append("foresight_finish")
	var clone: Object = _detached_clone()
	if clone == null:
		return _fail(&"invalid_minesweeper_state_port", "could not build a detached candidate")
	var before := _counters(clone)
	# Snapshot the receipt ids BEFORE the round, so the diff below reports exactly the contact
	# transactions THIS round recorded and nothing older (dwm-p2r.17).
	var receipts_before: Dictionary = (((clone.get("contacts") as Dictionary) \
		.get("transaction_receipts", {})) as Dictionary).duplicate(true)
	if context == "app":
		# The production reward/task/message/group rules run UNCHANGED on the clone; every signal
		# they emit lands on an out-of-tree node with no listeners.
		clone.call(&"finish_minesweeper_app_round", {
			"context": "app", "difficulty": difficulty, "outcome": outcome, "task_ids": task_ids,
		})
	else:
		# Dating rounds consume no app round and award no app money, task, or group activation.
		clone.call(&"clear_unfinished_minesweeper_round")
	var after := _counters(clone)
	# Classify each NEW contact receipt by the kind the DOMAIN recorded -- the port never
	# re-derives the activation rule (dwm-p2r.17, the bead's own design sentence).
	var receipts_after: Dictionary = ((clone.get("contacts") as Dictionary) \
		.get("transaction_receipts", {})) as Dictionary
	var group_activation_id: Variant = null
	var message_ids: Array = []
	for tid: Variant in receipts_after:
		if receipts_before.has(tid):
			continue
		var kind := str((receipts_after[tid] as Dictionary).get("kind", ""))
		if kind == "activate_group":
			group_activation_id = str(tid)
		elif kind == "offer_solo":
			message_ids.append(str(tid))
	message_ids.sort()
	var candidate := {
		"gameplay": clone.call(&"to_save_dict"),
		"contacts": (clone.get("contacts") as Dictionary).duplicate(true),
	}
	var claimed: Array = []
	for tid: Variant in task_ids:
		if (clone.get("minesweeper_task_rewards_claimed") as Dictionary).has(str(tid)):
			claimed.append(str(tid))
	clone.free()
	var deltas := {}
	for key: String in COUNTER_KEYS:
		deltas[key] = int(after[key]) - int(before[key])
	if context != "app":
		for key: String in ["money", "motivation", "app_rounds"]:
			deltas[key] = 0
		claimed = []
	var receipt := {
		"transaction_id": transaction_id,
		"round_id": str(active_round.get("round_id", "")),
		"context": context,
		"difficulty": difficulty,
		"outcome": outcome,
		"counter_deltas": deltas,
		"task_ids": claimed,
		"effect_transaction_ids": [],
		"message_transaction_ids": message_ids,
		"group_activation_transaction_id": group_activation_id,
		"dating_outcome_id": null if context == "app" else "%s:%s" % [str(active_round.get("round_id", "")), outcome],
		"checkpoint_id": "",
	}
	var events: Array[Dictionary] = [{
		"event_id": "round_completed",
		"round_id": str(active_round.get("round_id", "")),
		"context": context,
		"difficulty": difficulty,
		"outcome": outcome,
	}]
	return {"ok": true, "code": &"ok", "value": {
		"prepared_candidate": candidate,
		"prepared_domain_receipt": receipt,
		"domain_events": events,
		"checkpoint_input_template": {"active_round": active_round.duplicate(true)},
	}}


## Owner method: inserts the previewed checkpoint id into the detached receipt and candidate,
## then rebuilds the post-result checkpoint inputs from THAT final candidate.
func finalize_complete(prepared_completion: Dictionary, checkpoint_id: String) -> Dictionary:
	if checkpoint_id.is_empty():
		return _fail(&"invalid_checkpoint_id", "checkpoint_id must be nonempty")
	var inner: Dictionary = prepared_completion.get("value", prepared_completion) as Dictionary
	if typeof(inner.get("prepared_domain_receipt")) != TYPE_DICTIONARY:
		return _fail(&"invalid_prepared_completion", "prepared completion was not issued by this port")
	var receipt: Dictionary = (inner["prepared_domain_receipt"] as Dictionary).duplicate(true)
	if str(receipt.get("checkpoint_id", "")) != "":
		return _fail(&"invalid_prepared_completion", "prepared receipt already carries a checkpoint id")
	receipt["checkpoint_id"] = checkpoint_id
	var candidate: Dictionary = (inner["prepared_candidate"] as Dictionary).duplicate(true)
	var events: Array = (inner.get("domain_events", []) as Array).duplicate(true)
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	return {"ok": true, "code": &"ok", "value": {
		"candidate": candidate,
		"domain_receipt": receipt,
		"domain_events": events,
		# Built from the FINAL candidate, so the durable snapshot records the completed round.
		"post_result_checkpoint_inputs": _checkpoint_inputs(lifecycle, candidate),
	}}


func prepare_abort(active_round: Dictionary, reason: StringName, transaction_id: String) -> Dictionary:
	if _game_state == null:
		return _fail(&"invalid_minesweeper_state_port", "port requires a GameState")
	# The pre-board run candidate, with no reward and no event.
	var clone: Object = _detached_clone()
	if clone == null:
		return _fail(&"invalid_minesweeper_state_port", "could not build a detached candidate")
	clone.call(&"clear_unfinished_minesweeper_round")
	var restored: Dictionary = clone.call(&"to_save_dict")
	if str(active_round.get("context", "")) == "app":
		restored["minesweeper_rounds_left"] = int(restored.get("minesweeper_rounds_left", 0)) + 1
		var stats: Dictionary = (restored.get("stats", {}) as Dictionary).duplicate()
		stats["motivation"] = int(stats.get("motivation", 0)) + 1
		restored["stats"] = stats
	# The abort candidate is consumed by rollback() (the coordinator funnels it there), so it
	# carries the ROLLBACK shape -- "save" beside "contacts" -- not the commit shape
	# (dwm-p2r.17; the eleventh review's catch).
	var abort_candidate := {
		"save": restored,
		"contacts": (clone.get("contacts") as Dictionary).duplicate(true),
	}
	clone.free()
	return {"ok": true, "code": &"ok", "value": {
		"candidate": abort_candidate,
		"abort_receipt": {
			"round_id": str(active_round.get("round_id", "")),
			"reason": reason,
			"transaction_id": transaction_id,
		},
	}}


func commit(candidate: Dictionary) -> Dictionary:
	if _game_state == null:
		return _fail(&"invalid_minesweeper_state_port", "port requires a GameState")
	if typeof(candidate) != TYPE_DICTIONARY or candidate.is_empty():
		return _fail(&"invalid_candidate", "candidate was not issued by this port")
	var gameplay: Variant = candidate.get("gameplay")
	if typeof(gameplay) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate was not issued by this port")
	var applied: Dictionary = _game_state.call(&"apply_save_dict", gameplay)
	if not applied.get("ok", false):
		return applied
	var contacts: Variant = candidate.get("contacts")
	if typeof(contacts) == TYPE_DICTIONARY:
		_game_state.set("contacts", (contacts as Dictionary).duplicate(true))
	return applied


## Desktop settlement already owns the causal lease and durable recovery candidate.
## Apply absolute prepared values silently; restore APIs would reset the lifecycle.
func commit_desktop_completion(candidate: Dictionary) -> Dictionary:
	if _gate == null or not _gate.is_internal_owner_active(&"causal_transaction"):
		return _fail(&"causal_transaction_lease_required", "")
	if not candidate.get("gameplay") is Dictionary or not candidate.get("contacts") is Dictionary:
		return _fail(&"invalid_candidate", "completion requires gameplay and contacts")
	if int(candidate.gameplay.get("day", -1)) != int(_game_state.day):
		return _fail(&"completion_day_mismatch", "")
	_game_state.call(&"_apply_gameplay_silent", candidate.gameplay.duplicate(true))
	_game_state.set("contacts", candidate.contacts.duplicate(true))
	_game_state.call(&"clear_unfinished_minesweeper_round")
	return {"ok": true}


var _accepted_notifications: Dictionary = {}
var _published_notifications: Dictionary = {}


func publish_desktop_completion(receipt: Dictionary, events: Array) -> Dictionary:
	var published := publish(receipt, events)
	if not published.get("ok", false): return published
	_game_state.emit_signal("money_changed", int(_game_state.money))
	_game_state.emit_signal("coins_changed", int(_game_state.coins))
	for stat_id in ["health", "pressure", "motivation"]:
		_game_state.emit_signal("stat_changed", stat_id, int(_game_state.get_stat(stat_id)),
			int(_game_state.call(&"_stat_min", stat_id)), int(_game_state.call(&"_stat_max", stat_id)))
	return published


## The view is a refresh of persisted unread Contacts, so accepting it twice never adds messages.
func accept_desktop_notification(record: Dictionary) -> Dictionary:
	var action: Dictionary = record.get("action_receipt", {})
	var condition: Dictionary = record.get("condition_receipt", {})
	var intent: Dictionary = record.get("payload", {})
	var key := str(record.get("key", ""))
	if _game_state == null or key.is_empty() or record.get("consumer") != "desktop_notification" \
			or condition.get("decision") != "no_departure" or intent.get("intent_id") != key \
			or intent.get("action_commit_receipt_id") != action.get("commit_receipt_id") \
			or int(action.get("day", -1)) != int(_game_state.day):
		return _fail(&"invalid_desktop_notification", "")
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	for field in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"]:
		if action.get(field) != lifecycle.get(field): return _fail(&"stale_desktop_notification", "")
	if _accepted_notifications.has(key):
		return {"ok": true} if _accepted_notifications[key] == record \
			else _fail(&"desktop_notification_conflict", "")
	_accepted_notifications[key] = record.duplicate(true)
	return {"ok": true}


## Emission waits until the full checkpoint is durable and command custody has been released.
func publish_desktop_notifications() -> void:
	for key: String in _accepted_notifications:
		if _published_notifications.has(key): continue
		var record: Dictionary = _accepted_notifications[key]
		_published_notifications[key] = true
		if not record.action_receipt.get("unlock_receipt_ids", []).is_empty():
			_game_state.emit_signal("contact_message_unlocked", {"day": int(_game_state.day),
				"notification_id": key})


func rollback(backup: Dictionary) -> Dictionary:
	if _game_state == null:
		return _fail(&"invalid_minesweeper_state_port", "port requires a GameState")
	var payload: Variant = backup.get("backup", backup)
	if typeof(payload) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "backup was not issued by this port")
	var save: Variant = (payload as Dictionary).get("save", payload)
	if typeof(save) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "backup was not issued by this port")
	var applied: Dictionary = _game_state.call(&"apply_save_dict", save)
	if not applied.get("ok", false):
		return applied
	var contacts: Variant = (payload as Dictionary).get("contacts")
	if typeof(contacts) == TYPE_DICTIONARY:
		_game_state.set("contacts", (contacts as Dictionary).duplicate(true))
	return applied


## Pre-emission failpoint: the WHOLE batch is validated before the first emission, so a
## failure guarantees zero signals and a retry stays well defined.
func publish(receipt: Dictionary, domain_events: Array) -> Dictionary:
	if _game_state == null:
		return _fail(&"invalid_minesweeper_state_port", "port requires a GameState")
	if typeof(receipt) != TYPE_DICTIONARY or str(receipt.get("round_id", "")) == "":
		return _fail(&"invalid_publication", "receipt requires a round_id")
	for event: Variant in domain_events:
		if typeof(event) != TYPE_DICTIONARY:
			return _fail(&"invalid_publication", "every domain event must be a Dictionary")
		var record := event as Dictionary
		if str(record.get("event_id", "")) == "":
			return _fail(&"invalid_publication", "every domain event requires an event_id")
		if str(record.get("round_id", "")) != str(receipt.get("round_id", "")):
			return _fail(&"invalid_publication", "domain event disagrees with the receipt round_id")
	for event: Variant in domain_events:
		var record := event as Dictionary
		match str(record.get("event_id", "")):
			"round_started":
				_game_state.emit_signal("minesweeper_rounds_changed",
					int(_game_state.call(&"get_minesweeper_display_rounds_left")),
					int(_game_state.call(&"get_minesweeper_display_rounds_max")))
			"round_completed":
				_game_state.emit_signal("minesweeper_rounds_changed",
					int(_game_state.call(&"get_minesweeper_display_rounds_left")),
					int(_game_state.call(&"get_minesweeper_display_rounds_max")))
				_game_state.emit_signal("minesweeper_reward_changed", receipt.duplicate(true))
	_game_state.emit_signal("save_relevant_state_changed")
	return {"ok": true, "code": &"ok", "value": {"published": true}}


func latch_fatal(failure: Dictionary) -> Dictionary:
	if _gate == null:
		return _fail(&"mutation_gate_not_configured", "")
	return _gate.call(&"latch_fatal", failure)


func is_fatal_latched() -> bool:
	if _gate == null:
		return false
	return bool(_gate.call(&"is_fatal_latched"))


func guard_external(operation_id: StringName) -> Dictionary:
	if _gate == null:
		return _fail(&"mutation_gate_not_configured", "")
	return _gate.call(&"guard_external", operation_id)


# ---- Internal helpers ----

## Builds an out-of-tree GameState carrying the live whitelisted state. Production reward,
## task, message, and group rules run here so preparation stays free of live mutation.
func _detached_clone() -> Object:
	var clone: Object = load(GAME_STATE_SCRIPT_PATH).new()
	if clone == null:
		return null
	clone.call(&"reset_game")
	clone.call(&"apply_save_dict", _game_state.call(&"to_save_dict"))
	# The whitelist round trip resets contacts to defaults; seed the live section so the
	# production message/group rules run against real contacts on the clone (dwm-p2r.17).
	clone.set("contacts", (_game_state.get("contacts") as Dictionary).duplicate(true))
	return clone


func _counters(target: Object) -> Dictionary:
	return {
		"money": int(target.get("money")),
		"motivation": int(target.call(&"get_stat", "motivation")),
		"app_rounds": int(target.get("minesweeper_app_rounds_finished_today")),
		"health": int(target.call(&"get_stat", "health")),
		"pressure": int(target.call(&"get_stat", "pressure")),
	}


func _task_ids_for(outcome: String, difficulty: String) -> Array:
	var ids: Array = []
	for template: Variant in _COMPLETION_TASK_IDS.get(outcome, []):
		var text := str(template)
		ids.append(text % difficulty if text.contains("%s") else text)
	return ids


## Resolves the ONE active dating route SUBSTAGE (dwm-p2r.23). The untrusted request carries no
## friend or entry identifier; every trusted value is read from the active resolution plan
## itself: the entry from the substage's own id, the friends from the FROZEN committed entry's
## participants, the route transaction from the substage record. The parent stage is NOT
## required to be active -- it stays pending while its substage runs -- so the descend inspects
## every stage's substages and matches on the substage's own state and kind. A date Hospital
## superseded is refused even while its substage sits ACTIVE between the route door's begin and
## the caller's completion: the durable supersession set in the completed hospital stage's
## receipt is the authority, never the live flag -- the same law the presentation settle seam
## keeps (dwm-p2r.27). The deferred-pair presentation is a top-level STAGE with no substage:
## when that stage is ACTIVE the pair evidence is minted STAGE-LEVEL from the Hospital-
## superseded committed GROUP entry (dwm-p2r.30). The substage branch's superseded-date
## refusal deliberately does not reach it -- the pair IS the presentation of a superseded
## entry, so refusing superseded entries there would refuse its whole reason to exist.
func _resolve_dating_evidence() -> Dictionary:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return _fail(&"DATING_ROUTE_NOT_ACTIVE", "no active resolution plan")
	var stages: Variant = (plan as Dictionary).get("stages", [])
	if typeof(stages) != TYPE_ARRAY:
		return _fail(&"DATING_ROUTE_NOT_ACTIVE", "resolution plan carries no stages")
	var superseded: Array = _superseded_entry_ids(plan as Dictionary)
	for stage: Variant in stages:
		if typeof(stage) != TYPE_DICTIONARY:
			continue
		var stage_record := stage as Dictionary
		var stage_is_pair := str(stage_record.get("stage_id", "")) == "twofriends_if_deferred"
		if stage_is_pair and str(stage_record.get("state", "")) == "active":
			return _superseded_group_evidence(
				plan as Dictionary, superseded, str(stage_record.get("transaction_id", "")))
		for substage_value: Variant in (stage_record.get("substages", []) as Array):
			if typeof(substage_value) != TYPE_DICTIONARY:
				continue
			var record := substage_value as Dictionary
			if str(record.get("state", "")) != "active":
				continue
			var substage_id := str(record.get("substage_id", ""))
			if not substage_id.begins_with("surviving_date:"):
				continue
			var parts: PackedStringArray = substage_id.split(":")
			var entry_id := parts[3] if parts.size() == 4 else ""
			if entry_id in superseded:
				continue
			var friend_ids := _committed_participants(plan as Dictionary, entry_id)
			if friend_ids.is_empty() or friend_ids.size() > 2:
				continue
			return {"ok": true, "code": &"ok", "value": {
				"entry_id": entry_id,
				"route_transaction_id": str(record.get("transaction_id", "")),
				"friend_ids": friend_ids,
			}}
	return _fail(&"DATING_ROUTE_NOT_ACTIVE", "no active route substage")


## The entry ids Hospital already superseded, read from this plan's COMPLETED hospital stage
## receipt -- the durable authority, never the live flag (FINDING-4's law, dwm-p2r.27's read).
func _superseded_entry_ids(plan: Dictionary) -> Array:
	for stage_value: Variant in (plan.get("stages", []) as Array):
		if typeof(stage_value) != TYPE_DICTIONARY:
			continue
		var stage := stage_value as Dictionary
		if str(stage.get("stage_id", "")) != "hospital_if_triggered":
			continue
		var receipt: Variant = stage.get("receipt")
		if typeof(receipt) != TYPE_DICTIONARY:
			return []
		var value: Variant = (receipt as Dictionary).get("value")
		if typeof(value) != TYPE_DICTIONARY:
			return []
		var ids: Variant = (value as Dictionary).get("superseded_entry_ids", [])
		return (ids as Array) if typeof(ids) == TYPE_ARRAY else []
	return []


## The pair evidence for the ACTIVE deferred-pair STAGE (dwm-p2r.30): the Hospital-superseded
## committed GROUP entry that stage exists to present. The derivation is the day-resolution
## port's own `_deferred_pair_entry_id` law repeated byte-for-byte -- scan the FROZEN
## committed entries for action_kind == "group" with membership in the durable superseded
## set -- so the two ports agree BY CONSTRUCTION. First match wins to stay identical with
## that law; uniqueness is a MANIFEST invariant (the registry's two group actions carry
## disjoint allowed_days), not a registry-code law. FAILS CLOSED when nothing matches:
## tampered restored bytes or the empty-site transient mint no evidence here.
func _superseded_group_evidence(
		plan: Dictionary, superseded: Array, stage_transaction_id: String) -> Dictionary:
	var aggregate: Dictionary = plan.get("committed_schedule", {}) as Dictionary
	for entry_value: Variant in (aggregate.get("entries", []) as Array):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := entry_value as Dictionary
		if str(entry.get("action_kind", "")) != "group":
			continue
		var entry_id := str(entry.get("schedule_entry_id", ""))
		if not (entry_id in superseded):
			continue
		var friend_ids := _committed_participants(plan, entry_id)
		if friend_ids.is_empty() or friend_ids.size() > 2:
			continue
		return {"ok": true, "code": &"ok", "value": {
			"entry_id": entry_id,
			"route_transaction_id": stage_transaction_id,
			"friend_ids": friend_ids,
		}}
	return _fail(&"DATING_ROUTE_NOT_ACTIVE", "no superseded group entry for the pair stage")


## The deduped, nonblank participants of the FROZEN committed entry with this id -- the trusted
## friend source the docstring above promises, read from the plan's own committed_schedule.
func _committed_participants(plan: Dictionary, entry_id: String) -> Array:
	var aggregate: Dictionary = plan.get("committed_schedule", {}) as Dictionary
	for entry_value: Variant in (aggregate.get("entries", []) as Array):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := entry_value as Dictionary
		if str(entry.get("schedule_entry_id", "")) != entry_id:
			continue
		var out: Array = []
		for fid: Variant in (entry.get("participants", []) as Array):
			var text := str(fid)
			if text != "" and not out.has(text):
				out.append(text)
		return out
	return []


## The COMPLETE six-key bundle the real SaveManagerCheckpointPort requires. When a final
## candidate is supplied its whitelisted values replace the live gameplay bag, so the durable
## snapshot records what the transaction produces rather than what it started from.
func _checkpoint_inputs(lifecycle: Dictionary, candidate: Variant = null) -> Dictionary:
	var snapshot_input: Dictionary = _game_state.call(&"capture_run_snapshot_input")
	snapshot_input["lifecycle"] = lifecycle.duplicate(true)
	if typeof(candidate) == TYPE_DICTIONARY:
		var source: Dictionary = candidate as Dictionary
		var gameplay_section: Dictionary = source.get("gameplay", source) as Dictionary
		var gameplay: Dictionary = (snapshot_input.get("gameplay", {}) as Dictionary).duplicate(true)
		for key: Variant in gameplay_section:
			if gameplay.has(key):
				gameplay[key] = gameplay_section[key]
		snapshot_input["gameplay"] = gameplay
		# The candidate's contacts REPLACE the live read, so the post-result checkpoint can
		# never record post-round gameplay beside pre-round contacts (dwm-p2r.17).
		var candidate_contacts: Variant = source.get("contacts")
		if typeof(candidate_contacts) == TYPE_DICTIONARY:
			snapshot_input["contacts"] = (candidate_contacts as Dictionary).duplicate(true)
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


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}, "receipt": {}}
