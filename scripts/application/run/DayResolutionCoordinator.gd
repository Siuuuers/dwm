class_name DayResolutionCoordinator
extends RefCounted

## Atomic day-resolution completion engine behind the GameState facade
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 3).

const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")

const GATE_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]
const STATE_PORT_METHODS: Array[String] = [
	"begin_or_resume", "inspect_next_stage", "begin_next_stage",
	"prepare_completion", "capture", "commit", "rollback", "publish",
	"presentation_stage_receipt",
]
const CHECKPOINT_PORT_METHODS: Array[String] = [
	"preview_checkpoint_id", "capture", "prepare", "commit", "rollback",
]
## The exact CausalDayAdvanceIdentityPort capability (Plan 02 .16, consumed unwidened by Plan 01).
const DAY_ADVANCE_IDENTITY_METHODS: Array[String] = [
	"configure", "prepare_advance", "commit_advance",
]
## The exact frozen Schedule-Done presentation-port capability (Plan 01 Task 8, dwm-p2r.14).
const PRESENTATION_PORT_METHODS: Array[String] = [
	"begin", "complete", "is_ready",
]
## The exact SceneRouter presentation-route capability (Plan 01 Task 8 Step 8.6, dwm-p2r.18).
## Consumed unwidened: the coordinator asks the router to show ONE committed presentation and never
## to change a scene, clear a draft, or advance a day.
const PRESENTATION_ROUTER_METHODS: Array[String] = [
	"is_schedule_presentation_ports_configured", "route_presentation",
]

const STAGE_CONTRACTS := {
	"lock_day": {"owner_id": "day_resolution_coordinator", "kind": "day_lock",
		"value": {"locked": "const_true"}},
	"validate_schedule": {"owner_id": "schedule_rules", "kind": "schedule_validation",
		"value": {"schedule_digest": "string", "ordered_entry_ids": "array_string"}},
	"execute_schedule_actions": {"owner_id": "schedule_rules", "kind": "schedule_actions_complete",
		"value": {"entry_receipt_ids": "array_string"}},
	"commit_outcomes": {"owner_id": "game_state", "kind": "outcomes_commit",
		"value": {"outcome_ids": "array_string", "effect_transaction_ids": "array_string"}},
	# Task 7 (dwm-p2r.14): Hospital is owned by HospitalRules, not by the ending rules, and it
	# supersedes EVERY committed date rather than a single "prevented" one.
	# dwm-p2r.18: a presentation stage additionally carries the EXACT completion receipt its
	# configured port published. That is what makes "checkpoint the receipt, then advance" literally
	# true -- the receipt is inside the bytes the checkpoint durably records, not merely observed
	# in memory before the stage completed. It is null for a Hospital that presented nothing.
	"hospital_if_triggered": {"owner_id": "hospital_rules", "kind": "hospital_resolution",
		"value": {"required": "bool", "date_schedule_entry_ids": "array_string",
			"superseded_entry_ids": "array_string", "witness_entry_id": "string_or_null",
			"presentation_completion_receipt": "dictionary_or_null"}},
	"execute_schedule_dates": {"owner_id": "schedule_rules", "kind": "schedule_dates_complete",
		"value": {"entry_receipt_ids": "array_string", "superseded_entry_ids": "array_string"}},
	"twofriends_if_deferred": {"owner_id": "contact_invitation_state", "kind": "twofriends_resolution",
		"value": {"required": "bool", "route_receipt_id": "string_or_null",
			"message_transaction_ids": "array_string",
			"presentation_completion_receipt": "dictionary_or_null"}},
	"invitation_rollover": {"owner_id": "contact_invitation_state", "kind": "invitation_rollover",
		"value": {"target_day": "int", "message_transaction_ids": "array_string"}},
	"increment_day": {"owner_id": "run_lifecycle", "kind": "day_increment",
		"value": {"source_day": "int", "target_day": "int"}},
	"reset_day_scope": {"owner_id": "game_state", "kind": "day_scope_reset",
		"value": {"target_day": "int", "reset_ids": "array_string"}},
	"new_day_autosave": {"owner_id": "save_manager", "kind": "disk_checkpoint_request",
		"value": {"save_kind": "const_autosave", "save_reason": "const_day_start"}},
	"unlock_day": {"owner_id": "day_resolution_coordinator", "kind": "day_unlock",
		"value": {"locked": "const_false"}},
	"close_invitations_run_end": {"owner_id": "contact_invitation_state", "kind": "run_end_close",
		"value": {"resolved_action_ids": "array_string"}},
	"validate_day7_provenance": {"owner_id": "day7_schedule_provenance", "kind": "day7_provenance_validation",
		"value": {"cause": "string", "schedule_entry_id": "string_or_null", "source_receipt_id": "string_or_null"}},
	# Task 8 Step 8.7 (dwm-p2r.14): the checkpoint now carries the DERIVED
	# P01.schedule.day7_provenance child and its full provenance, not just the cause the aggregate
	# already showed. This receipt is the whole Plan-01 Day-7 output; dwm-oyo.3 / dwm-oyo.6 consume
	# exactly these bytes and Plan 01 creates nothing else on Day 7.
	"checkpoint_day7_provenance": {"owner_id": "day7_schedule_provenance", "kind": "day7_provenance_checkpoint",
		"value": {"cause": "string", "schedule_commit_receipt_id": "string_or_null",
			"day7_provenance_receipt_id": "string",
			"day7_provenance_receipt_provenance": "dictionary"}},
	"resolve_ending_plan": {"owner_id": "dating_ending_rules", "kind": "ending_resolution",
		"value": {"ending_plan": "dictionary"}},
	"enter_ending": {"owner_id": "run_lifecycle", "kind": "enter_ending",
		"value": {"state": "const_ending_state", "primary_id": "string", "epilogue_id": "string_or_null"}},
	"ending_autosave": {"owner_id": "save_manager", "kind": "disk_checkpoint_request",
		"value": {"save_kind": "const_autosave", "save_reason": "const_ending"}},
}

## Keyed by the receipt KIND a substage returns, because a substage does not answer to its parent
## stage's envelope: an `execute_schedule_dates` substage reports the one date it ran, not the
## stage-level `schedule_dates_complete` aggregate.
##
## THIS TABLE WAS DEAD UNTIL dwm-p2r.18. `_commit_completion` validated every record against
## `STAGE_CONTRACTS[stage_id]`, so any substage driven through the coordinator would have been
## rejected for a kind mismatch. No test reached it: the entry-substage suites drive the state port
## and lifecycle directly, and the only coordinator-driven walk commits an empty Schedule, which has
## no substages at all. Wiring the date presentation is what finally routes a substage through here.
const SUBSTAGE_CONTRACTS := {
	"route_complete": {"owner_id": "scene_router", "value": {"route_receipt_id": "string"}},
	"schedule_entry_complete": {"owner_id": "schedule_rules",
		"value": {"entry_receipt_id": "string", "outcome_ids": "array_string"}},
	"schedule_date_complete": {"owner_id": "schedule_rules",
		"value": {"entry_receipt_id": "string", "superseded": "bool", "reason": "string_or_null",
			"presentation_completion_receipt": "dictionary_or_null"}},
	"effect_transaction": {"owner_id": "effect_resolver",
		"value": {"transaction_id": "string", "effect_ids": "array_string"}},
}

var _gate: Object = null
var _state_port: Object = null
var _checkpoint_port: Object = null
## ONE retained shared advance-identity port. Bootstrap owns initial configuration and keeps the
## same object for Plan 03's condition-Hospital advancement; this coordinator never constructs,
## wraps, or replaces it, and never calls raw issue(&"causal_day_instance").
var _day_advance_identity_port: Object = null
## The TWO retained presentation ports. The coordinator accepts a completion only from these exact
## object identities; it never constructs, wraps, or replaces either.
var _hospital_presentation_port: Object = null
var _dating_presentation_port: Object = null
## The ONE retained route surface. Bootstrap injects the same SceneRouter it already gave those two
## ports; the coordinator never constructs, wraps, or replaces it, and never changes a scene itself.
var _presentation_router: Object = null
## The transaction whose presentation is ALREADY SHOWING. `resume()` is a public seam any caller may
## drive again while a stage is still awaiting, and the ports and the physical owner are idempotent
## -- but `route_presentation` is NOT: a second dispatch instantiates a second scene and frees the
## live one underneath a timeline that keeps playing. A FAILED launch records nothing here, so a
## refused route still re-dispatches on the next `resume()`, which is what a retry is for.
var _launched_transaction := ""
var _last_presentation_completion: Dictionary = {}
var _last_presentation_failure: Dictionary = {}
var _run_id := ""
var _awaiting: Dictionary = {}
var _registered_history: Dictionary = {}

## THE SOLE three-owner configuration seam (Plan 01 Task 6 Step 6.5, dwm-p2r.13).
##
## The gate used to arrive through a separate `configure_fatal_latch()` call, so the coordinator
## could sit half-owned between the two calls and no single result described who owned it. All three
## owners now arrive together, are validated together, and are adopted together.
##
## Identical replay is idempotent. A CHANGED owner in any position returns the exact
## `day_resolution_coordinator_already_configured` failure BEFORE any mutation, so a second wiring
## attempt can never partially re-point a live coordinator.
func configure(state_port: Object, checkpoint_port: Object, mutation_gate: Object) -> Dictionary:
	if not _is_valid_gate(mutation_gate):
		return {"ok": false, "code": &"invalid_mutation_gate", "message": "gate contract incomplete"}
	if state_port == null or not _has_all_methods(state_port, STATE_PORT_METHODS):
		return {"ok": false, "code": &"invalid_state_port", "message": ""}
	if checkpoint_port == null or not _has_all_methods(checkpoint_port, CHECKPOINT_PORT_METHODS):
		return {"ok": false, "code": &"invalid_checkpoint_port", "message": ""}
	if _gate != null or _state_port != null or _checkpoint_port != null:
		if _gate != mutation_gate or _state_port != state_port \
				or _checkpoint_port != checkpoint_port:
			return {"ok": false, "code": &"day_resolution_coordinator_already_configured",
				"message": "a configured coordinator never adopts a replacement owner"}
		return _gate_identity_result(true)
	_gate = mutation_gate
	_state_port = state_port
	_checkpoint_port = checkpoint_port
	return _gate_identity_result(false)

## The one Task-7 dependency seam (dwm-p2r.14 Step 7.3a). It does NOT touch configure()'s frozen
## three-owner signature and does not renumber a stage.
##
## Failure is uniform `day_advance_identity_port_conflict`: a missing object, an object without the
## exact capability, and a replacement are all refusals to adopt an identity owner, and all of them
## return BEFORE any stage mutation.
func configure_day_advance_identity_port(day_advance_identity_port: Object) -> Dictionary:
	if day_advance_identity_port == null 			or not _has_all_methods(day_advance_identity_port, DAY_ADVANCE_IDENTITY_METHODS):
		return {"ok": false, "code": &"day_advance_identity_port_conflict",
			"message": "an exact CausalDayAdvanceIdentityPort capability is required"}
	if _day_advance_identity_port != null:
		if _day_advance_identity_port != day_advance_identity_port:
			return {"ok": false, "code": &"day_advance_identity_port_conflict",
				"message": "a configured coordinator never adopts a replacement identity port"}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_day_advance_identity_port = day_advance_identity_port
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


## The Task-8 presentation seam (dwm-p2r.14 Step 8.6). Like the Task-7 identity seam above it does
## NOT touch configure()'s frozen three-owner signature and renumbers no stage.
##
## The coordinator connects each exact port's completion/failure signals ONCE here, before any
## `begin()`, and thereafter accepts a completion only from the port identity it retained. A
## completion arriving from any other object is not this resolution's completion, however well
## formed it looks.
##
## Failure is uniform `presentation_ports_conflict`: a missing port, a port without the exact
## capability, and a replacement are all refusals to adopt a presentation owner, and all of them
## return BEFORE any stage mutation.
func configure_presentation_ports(hospital_port: Object, dating_port: Object) -> Dictionary:
	if hospital_port == null or not _has_all_methods(hospital_port, PRESENTATION_PORT_METHODS) \
			or dating_port == null or not _has_all_methods(dating_port, PRESENTATION_PORT_METHODS):
		return {"ok": false, "code": &"presentation_ports_conflict",
			"message": "an exact presentation-port capability is required"}
	for port: Object in [hospital_port, dating_port]:
		if not port.has_signal("completion_ready") or not port.has_signal("completion_failed"):
			return {"ok": false, "code": &"presentation_ports_conflict",
				"message": "a presentation port declares both completion signals"}
	if _hospital_presentation_port != null or _dating_presentation_port != null:
		if _hospital_presentation_port != hospital_port \
				or _dating_presentation_port != dating_port:
			return {"ok": false, "code": &"presentation_ports_conflict",
				"message": "a configured coordinator never adopts a replacement presentation port"}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true,
				"hospital_port_instance_id": hospital_port.get_instance_id(),
				"dating_port_instance_id": dating_port.get_instance_id()},
			"receipt": {}}
	_hospital_presentation_port = hospital_port
	_dating_presentation_port = dating_port
	# The emitting port is BOUND into each connection. Godot signals do not tell a handler who
	# emitted, so without this the coordinator could not tell a configured port's completion from
	# any other object's -- and "accepts completion only from the configured port identity" would be
	# unenforceable rather than merely unenforced.
	for port: Object in [hospital_port, dating_port]:
		var ready_handler := _on_presentation_completion_ready.bind(port)
		var failed_handler := _on_presentation_completion_failed.bind(port)
		if not port.is_connected("completion_ready", ready_handler):
			port.connect("completion_ready", ready_handler)
		if not port.is_connected("completion_failed", failed_handler):
			port.connect("completion_failed", failed_handler)
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false,
			"hospital_port_instance_id": hospital_port.get_instance_id(),
			"dating_port_instance_id": dating_port.get_instance_id()},
		"receipt": {}}


## Accepts the ONE production route surface once (dwm-p2r.18). Identical replay is idempotent and a
## replacement is refused, exactly as the port seam above.
##
## WHY THE COORDINATOR HOLDS IT. It is the object that PAUSES the walk on a presentation, so it is
## the object that must be able to launch one. Handing the route to a caller instead would leave
## "the Hospital and Dating adapters are actually launched" resting on a caller that does not exist.
func configure_presentation_router(router: Object) -> Dictionary:
	if router == null or not _has_all_methods(router, PRESENTATION_ROUTER_METHODS):
		return {"ok": false, "code": &"presentation_router_conflict",
			"message": "an exact presentation-route capability is required"}
	if _presentation_router != null:
		if _presentation_router != router:
			return {"ok": false, "code": &"presentation_router_conflict",
				"message": "a configured coordinator never adopts a replacement route surface"}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true,
				"router_instance_id": router.get_instance_id()},
			"receipt": {}}
	_presentation_router = router
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false,
			"router_instance_id": router.get_instance_id()},
		"receipt": {}}


## One configured port published a completion. The stage advances only after the returned receipt is
## CHECKPOINTED through the ordinary completion path -- never on the signal alone.
func _on_presentation_completion_ready(completion_result: Dictionary, port: Object) -> void:
	if port != _hospital_presentation_port and port != _dating_presentation_port:
		_last_presentation_failure = {"ok": false, "code": &"presentation_completion_untrusted",
			"message": "a completion arrived from an object this coordinator never configured"}
		return
	if typeof(completion_result) != TYPE_DICTIONARY \
			or not completion_result.get("ok", false) \
			or typeof(completion_result.get("receipt")) != TYPE_DICTIONARY:
		_last_presentation_failure = {"ok": false, "code": &"invalid_presentation_completion",
			"message": "a presentation port published a malformed completion"}
		return
	# THE SIGNAL ALONE ADVANCES NOTHING. It only makes the receipt available; the stage advances
	# through complete_presentation_stage(), and only after that receipt is durably checkpointed.
	var receipt: Dictionary = completion_result["receipt"]
	_last_presentation_completion = receipt.duplicate(true)


func _on_presentation_completion_failed(failure: Dictionary, port: Object) -> void:
	if port != _hospital_presentation_port and port != _dating_presentation_port:
		return
	_last_presentation_failure = failure.duplicate(true) if typeof(failure) == TYPE_DICTIONARY \
		else {"ok": false, "code": &"presentation_failed", "message": ""}


## Completes the awaiting presentation stage with the receipt a configured port published.
##
## THE ORDER IS THE POINT (plan line 1174). The port's completion receipt is folded into the stage
## envelope, the whole envelope is checkpointed through the ordinary completion path, and only a
## SUCCESSFUL checkpoint advances the stage. A crash between the physical completion and this call
## resumes at the same awaiting boundary and replays the same byte-identical receipt, because the
## port settles its completion transaction idempotently.
func complete_presentation_stage() -> Dictionary:
	var fatal := _fatal_guard()
	if not fatal.is_empty():
		return fatal
	if _state_port == null or _checkpoint_port == null:
		return {"ok": false, "code": &"ports_not_configured", "message": ""}
	if _last_presentation_completion.is_empty():
		return {"ok": false, "code": &"no_presentation_completion",
			"message": "no configured port has published a completion"}
	if _awaiting.is_empty():
		return {"ok": false, "code": &"unknown_transaction",
			"message": "no stage is awaiting a presentation"}
	var completion: Dictionary = _last_presentation_completion
	var request: Dictionary = _awaiting.get("presentation_request", {})
	# The receipt must settle the command this stage is actually waiting on. A well-formed receipt
	# from another presentation is not this stage's evidence.
	if str(completion.get("receipt_id", "")) != str(request.get("completion_transaction_id", "")):
		return {"ok": false, "code": &"presentation_completion_untrusted",
			"message": "the published completion does not settle the awaiting command"}
	var transaction_id := str(_awaiting["transaction_id"])
	var envelope: Dictionary = _state_port.presentation_stage_receipt(transaction_id, completion)
	if not envelope.get("ok", false):
		return envelope
	var completed := _commit_completion({
		"stage_id": str(_awaiting["stage_id"]),
		"substage_id": str(_awaiting.get("substage_id", "")),
		"transaction_id": transaction_id,
	}, (envelope["value"] as Dictionary)["receipt"])
	if not completed.get("ok", false):
		return completed
	# A duplicate means the plan ALREADY completed this stage, so the retained awaiting state is
	# stale by definition and is dropped exactly as on the success path -- otherwise the coordinator
	# is left awaiting a finished stage, every later call returns duplicate again, and this path
	# never reaches resume(). The duplicate is still REPORTED rather than resumed over: unlike the
	# success path, nothing new was checkpointed here.
	#
	# Safe here in a way it would not be in `complete_route_stage`: this transaction id is read from
	# `_awaiting` itself, so it can never be an older transaction whose replay should leave a newer
	# awaiting command untouched.
	_awaiting = {}
	_launched_transaction = ""
	_last_presentation_completion = {}
	if completed.get("code") == &"duplicate_transaction":
		return completed
	return resume()


## The last completion/failure a CONFIGURED port published, for the caller that drives the stage.
## Detached copies: reading this never lets a caller mutate what the coordinator retained.
func get_last_presentation_completion() -> Dictionary:
	return _last_presentation_completion.duplicate(true)


func get_last_presentation_failure() -> Dictionary:
	return _last_presentation_failure.duplicate(true)


## Confirms the three owners GameState is about to install are the exact ones this coordinator
## already holds. It COMPARES the supplied references internally and never returns one: the removed
## read-only state-port accessor handed a live Object back to its caller, which is precisely how a
## private bag leaks. No Dictionary returned here carries an Object reference.
##
## The removed accessor's name is deliberately not written out anywhere in this file, because Step
## 6.7's static gate is a text search and a comment naming it would keep the gate red forever.
func verify_configuration(state_port: Object, checkpoint_port: Object,
		mutation_gate: Object) -> Dictionary:
	if _gate == null or _state_port == null or _checkpoint_port == null:
		return {"ok": false, "code": &"day_resolution_coordinator_unconfigured", "message": ""}
	if _state_port != state_port or _checkpoint_port != checkpoint_port or _gate != mutation_gate:
		return {"ok": false, "code": &"day_resolution_coordinator_owner_mismatch", "message": ""}
	return {"ok": true, "code": &"ok", "value": {"configured": true}, "receipt": {}}

func request_schedule_done(command_id: String) -> Dictionary:
	var fatal := _fatal_guard()
	if not fatal.is_empty():
		return fatal
	if _state_port == null or _checkpoint_port == null:
		return {"ok": false, "code": &"ports_not_configured", "message": ""}
	if command_id.is_empty():
		return {"ok": false, "code": &"invalid_command_id", "message": ""}
	var begun: Dictionary = _state_port.begin_or_resume(command_id)
	if not begun.get("ok", false):
		return begun
	_run_id = str((begun.get("value", {}) as Dictionary).get("run_id", _run_id))
	return resume()

func resume() -> Dictionary:
	var fatal := _fatal_guard()
	if not fatal.is_empty():
		return fatal
	if _state_port == null or _checkpoint_port == null:
		return {"ok": false, "code": &"ports_not_configured", "message": ""}
	while true:
		var cursor: Dictionary = _state_port.inspect_next_stage()
		if not cursor.get("ok", false):
			return cursor
		if not cursor["value"]["has_stage"]:
			var preview: Dictionary = _checkpoint_port.preview_checkpoint_id(_run_id)
			if not preview.get("ok", false):
				return preview
			return {"ok": true, "code": &"plan_complete",
				"value": {"checkpoint_id": str(preview["value"]["checkpoint_id"])}}
		# A logical-day change may only happen through the ONE shared root-atomic identity port.
		# Refuse at the boundary rather than at plan start, so every earlier stage stays completed
		# and the run resumes forward once bootstrap has configured the port.
		if str((cursor["value"]["stage"] as Dictionary).get("stage_id", "")) == "increment_day" 				and _day_advance_identity_port == null:
			return {"ok": false, "code": &"day_advance_identity_port_unconfigured",
				"message": "increment_day requires the shared causal day advance identity port"}
		var begun: Dictionary = _state_port.begin_next_stage()
		if not begun.get("ok", false):
			return begun
		var mode: StringName = begun["value"]["mode"]
		var stage: Dictionary = begun["value"]["stage"]
		if mode == &"await_registered_command":
			var command: Dictionary = begun["value"]["command"]
			if stage.has("substage_id"):
				command["substage_id"] = str(stage["substage_id"])
			_awaiting = command.duplicate(true)
			_registered_history[str(command["transaction_id"])] = command.duplicate(true)
			# The command is registered BEFORE the launch: a port whose physical owner completes
			# synchronously publishes into a coordinator that is already awaiting this exact
			# transaction, rather than into one that has not heard of it yet.
			var launched := _launch_presentation(command)
			if not launched.is_empty() and not launched.get("ok", false):
				return launched
			return {"ok": true, "code": &"await_registered_command",
				"value": {"stage": stage, "command": command}}
		var completed := _commit_completion(stage, begun["value"]["receipt"])
		if not completed.get("ok", false):
			return completed
	return {"ok": false, "code": &"unreachable", "message": ""}

## Launches the adapter for ONE awaiting presentation command, and returns `{}` both when the
## awaiting command is not a presentation at all and when its presentation is already showing
## (dwm-p2r.18, the last SCOPE bullet).
##
## THE ORDER IS FORCED, not chosen. `route_presentation` hands the scene the CANONICAL command --
## the request plus the `command_sha256` and the owner-derived `physical_token` -- and only `begin()`
## produces those bytes, so the physical presentation necessarily starts before the scene opens.
## Every precondition knowable WITHOUT those bytes is therefore checked FIRST -- the route id, the
## route surface, this coordinator's ports, and the router's OWN presentation ports -- so none of
## them can leave a timeline running behind a scene that was never going to open.
##
## THE REMAINING ROUTER REFUSALS ARE NOT PRE-CHECKABLE, and this does not pretend otherwise. A
## missing scene, a scene that cannot be configured, the scene's OWN `configure_presentation` refusal
## (returned verbatim, so not even a fixed code), and an unavailable tree are properties of the ROUTE,
## and `route_presentation` cannot judge them without the canonical command only `begin()` produces.
## Those four necessarily land after the physical presentation started; the paragraph below is what
## makes that survivable rather than a claim that it cannot happen.
##
## A REFUSAL LEAVES THE RUN RESUMABLE, which is why nothing is rolled back here. The stage is already
## ACTIVE by this point and stays active and unreceipted, `_awaiting` keeps this exact command, and
## no domain state was touched. `begin()` is idempotent per completion transaction, so the next
## `resume()` re-derives byte-identical bytes and re-offers them without restarting a presentation
## that may already be running.
func _launch_presentation(command: Dictionary) -> Dictionary:
	var request: Variant = command.get("presentation_request")
	if typeof(request) != TYPE_DICTIONARY or (request as Dictionary).is_empty():
		return {}
	if str(command.get("transaction_id", "")) == _launched_transaction:
		return {}
	var route_id := str(command.get("route_id", ""))
	if route_id != "hospital" and route_id != "dating":
		return {"ok": false, "code": &"invalid_presentation_route", "message": route_id}
	if _presentation_router == null:
		return {"ok": false, "code": &"presentation_router_unconfigured",
			"message": "a presentation stage requires the configured route surface"}
	var port: Object = _hospital_presentation_port if route_id == "hospital" \
		else _dating_presentation_port
	if port == null:
		# Distinct from `presentation_ports_conflict`, which the configure seam returns for a port
		# it REFUSES. Nothing was refused here: the graph never composed one at all.
		return {"ok": false, "code": &"presentation_ports_unconfigured",
			"message": "a presentation stage requires the configured presentation ports"}
	# The ONE router refusal knowable without the canonical command: the router's own presentation
	# ports are a property of the object already held, not of this route. Asked BEFORE `begin()` so a
	# router that can show nothing never gets a timeline running behind it. Distinct from
	# `presentation_ports_unconfigured` above, which is THIS coordinator's ports; a mis-composed graph
	# has to say which half is missing.
	if not bool(_presentation_router.call(&"is_schedule_presentation_ports_configured")):
		return {"ok": false, "code": &"presentation_router_ports_unconfigured",
			"message": "the route surface has no presentation ports to show a scene with"}
	var started: Variant = port.call(&"begin", (request as Dictionary).duplicate(true))
	if typeof(started) != TYPE_DICTIONARY or not (started as Dictionary).get("ok", false):
		return started if typeof(started) == TYPE_DICTIONARY else {"ok": false,
			"code": &"presentation_begin_failed", "message": route_id}
	var canonical: Variant = ((started as Dictionary).get("value", {}) as Dictionary).get(
		"presentation_command")
	if typeof(canonical) != TYPE_DICTIONARY or (canonical as Dictionary).is_empty():
		return {"ok": false, "code": &"invalid_presentation_command",
			"message": "the port returned no canonical command for the scene to project"}
	var routed: Variant = _presentation_router.call(&"route_presentation", route_id,
		(canonical as Dictionary).duplicate(true))
	if typeof(routed) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"presentation_route_failed", "message": route_id}
	if not (routed as Dictionary).get("ok", false):
		return routed
	_launched_transaction = str(command.get("transaction_id", ""))
	return routed


func complete_route_stage(transaction_id: String, receipt: Dictionary) -> Dictionary:
	var fatal := _fatal_guard()
	if not fatal.is_empty():
		return fatal
	var command: Dictionary = {}
	if not _awaiting.is_empty() and str(_awaiting.get("transaction_id", "")) == transaction_id:
		command = _awaiting
	elif _registered_history.has(transaction_id):
		command = _registered_history[transaction_id]
	else:
		return {"ok": false, "code": &"unknown_transaction", "message": transaction_id}
	var stage_id := str(command["stage_id"])
	var envelope_error := _validate_envelope(stage_id, receipt)
	if envelope_error != "":
		return {"ok": false, "code": &"invalid_receipt", "message": envelope_error}
	var completed := _commit_completion(
		{"stage_id": stage_id, "transaction_id": transaction_id}, receipt)
	if not completed.get("ok", false):
		return completed
	if completed.get("code") == &"duplicate_transaction":
		return completed
	_awaiting = {}
	_launched_transaction = ""
	return resume()

func _commit_completion(stage: Dictionary, receipt: Dictionary) -> Dictionary:
	var stage_id := str(stage["stage_id"])
	var transaction_id := str(stage["transaction_id"])
	# A SUBSTAGE answers to its own contract, keyed by the receipt kind it returns.
	var envelope_error := _validate_substage_envelope(receipt) 		if str(stage.get("substage_id", "")) != "" else _validate_envelope(stage_id, receipt)
	if envelope_error != "":
		return {"ok": false, "code": &"invalid_receipt", "message": envelope_error}
	var state_capture: Dictionary = _state_port.capture()
	if not state_capture.get("ok", false):
		return state_capture
	var state_backup: Dictionary = state_capture["value"]["backup"]
	var checkpoint_capture: Dictionary = _checkpoint_port.capture()
	if not checkpoint_capture.get("ok", false):
		return checkpoint_capture
	var checkpoint_backup: Dictionary = checkpoint_capture["value"]["backup"]
	var prepared: Dictionary = _state_port.prepare_completion(transaction_id, receipt)
	if not prepared.get("ok", false):
		return prepared
	if bool(prepared["value"].get("duplicate", false)):
		var current_id := "%s:%d" % [str(checkpoint_backup.get("run_id", _run_id)),
			int(checkpoint_backup.get("sequence", 0))]
		return {"ok": true, "code": &"duplicate_transaction", "value": {
			"receipt": prepared["value"].get("stored_receipt"),
			"checkpoint_id": current_id,
		}}
	var checkpoint_kind: StringName = &"day_start" if stage_id == "new_day_autosave" else &"day_resolution_stage"
	var prepared_checkpoint: Dictionary = _checkpoint_port.prepare(
		prepared["value"]["snapshot_input"], checkpoint_kind, _disk_write_for(stage_id))
	if not prepared_checkpoint.get("ok", false):
		return prepared_checkpoint
	var checkpoint_commit: Dictionary = _checkpoint_port.commit(prepared_checkpoint["value"]["candidate"])
	if not checkpoint_commit.get("ok", false):
		var checkpoint_rollback: Dictionary = _checkpoint_port.rollback(checkpoint_backup)
		if not checkpoint_rollback.get("ok", false):
			return _fatal_rollback("checkpoint_commit", transaction_id, stage_id, [
				_raw_diagnostic("checkpoint_port", "rollback", checkpoint_rollback),
			])
		return checkpoint_commit
	var state_commit: Dictionary = _state_port.commit(prepared["value"]["run_candidate"])
	if not state_commit.get("ok", false):
		return _recover_both("state_commit", transaction_id, stage_id,
			state_backup, checkpoint_backup, state_commit)
	var published: Dictionary = _state_port.publish(prepared["value"]["publication"])
	if not published.get("ok", false):
		return _recover_both("publish", transaction_id, stage_id,
			state_backup, checkpoint_backup, published)
	return {"ok": true, "code": &"stage_completed", "value": {
		"receipt": receipt.duplicate(true),
		"checkpoint_id": str(checkpoint_commit["value"]["checkpoint_id"]),
	}}

func _recover_both(
		phase: String, transaction_id: String, stage_id: String,
		state_backup: Dictionary, checkpoint_backup: Dictionary,
		original_failure: Dictionary
) -> Dictionary:
	var state_rollback: Dictionary = _state_port.rollback(state_backup)
	var checkpoint_rollback: Dictionary = _checkpoint_port.rollback(checkpoint_backup)
	if state_rollback.get("ok", false) and checkpoint_rollback.get("ok", false):
		return original_failure
	return _fatal_rollback(phase, transaction_id, stage_id, [
		_raw_diagnostic("state_port", "rollback", state_rollback),
		_raw_diagnostic("checkpoint_port", "rollback", checkpoint_rollback),
	])

func _fatal_rollback(
		phase: String, transaction_id: String, stage_id: String,
		raw_diagnostics: Array
) -> Dictionary:
	var already_retained := false
	for diagnostic: Dictionary in raw_diagnostics:
		var result: Dictionary = diagnostic.get("result", {})
		if str(result.get("code", "")) == "APPLICATION_FATAL":
			already_retained = true
	if not already_retained and not _gate.is_fatal_latched():
		var projected: Dictionary = PROJECTOR.project_failure(
			"day_resolution", phase, "fatal_rollback_failed",
			{"transaction_id": transaction_id, "stage_id": stage_id},
			raw_diagnostics)
		var candidate: Dictionary = PROJECTOR.get_invariant_fallback()
		if projected.get("ok", false):
			var failure: Dictionary = projected["value"]["failure"]
			if PROJECTOR.validate_failure(failure).get("ok", false):
				candidate = failure
		_gate.latch_fatal(candidate)
	return _gate.guard_external(&"day_resolution_recovery")

func _fatal_guard() -> Dictionary:
	if _gate != null and _gate.is_fatal_latched():
		return _gate.guard_external(&"day_resolution_recovery")
	return {}

static func _raw_diagnostic(owner_id: String, operation: String, result: Dictionary) -> Dictionary:
	return {"owner_id": owner_id, "operation": operation, "result": result}

static func _disk_write_for(stage_id: String) -> Dictionary:
	match stage_id:
		"new_day_autosave":
			return {"kind": &"autosave", "reason": &"day_start"}
		"ending_autosave":
			return {"kind": &"autosave", "reason": &"ending"}
	return {"kind": &"none", "reason": &"stage"}

static func _validate_envelope(stage_id: String, receipt: Dictionary) -> String:
	var keys := receipt.keys()
	keys.sort()
	if keys != ["kind", "owner_id", "value"]:
		return "receipt must have exactly owner_id/kind/value"
	if not STAGE_CONTRACTS.has(stage_id):
		return "unknown stage: " + stage_id
	var contract: Dictionary = STAGE_CONTRACTS[stage_id]
	if str(receipt["owner_id"]) != str(contract["owner_id"]):
		return "owner mismatch for " + stage_id
	if str(receipt["kind"]) != str(contract["kind"]):
		return "kind mismatch for " + stage_id
	if typeof(receipt["value"]) != TYPE_DICTIONARY:
		return "value must be a Dictionary"
	var value: Dictionary = receipt["value"]
	var value_keys := value.keys()
	value_keys.sort()
	var spec: Dictionary = contract["value"]
	var spec_keys := spec.keys()
	spec_keys.sort()
	if value_keys != spec_keys:
		return "value keys mismatch for " + stage_id
	for key: String in spec:
		var error := _validate_spec_value(value[key], str(spec[key]))
		if error != "":
			return key + ": " + error
	return ""

## The substage twin of `_validate_envelope`. Selects the contract by receipt KIND, because a
## substage's owner is the entry it ran rather than the stage that contains it.
static func _validate_substage_envelope(receipt: Dictionary) -> String:
	var keys := receipt.keys()
	keys.sort()
	if keys != ["kind", "owner_id", "value"]:
		return "receipt must have exactly owner_id/kind/value"
	var kind := str(receipt["kind"])
	if not SUBSTAGE_CONTRACTS.has(kind):
		return "unknown substage receipt kind: " + kind
	var contract: Dictionary = SUBSTAGE_CONTRACTS[kind]
	if str(receipt["owner_id"]) != str(contract["owner_id"]):
		return "owner mismatch for " + kind
	if typeof(receipt["value"]) != TYPE_DICTIONARY:
		return "value must be a Dictionary"
	var value: Dictionary = receipt["value"]
	var value_keys := value.keys()
	value_keys.sort()
	var spec: Dictionary = contract["value"]
	var spec_keys := spec.keys()
	spec_keys.sort()
	if value_keys != spec_keys:
		return "value keys mismatch for " + kind
	for key: String in spec:
		var error := _validate_spec_value(value[key], str(spec[key]))
		if error != "":
			return key + ": " + error
	return ""


static func _validate_spec_value(value: Variant, spec: String) -> String:
	match spec:
		"bool":
			return "" if typeof(value) == TYPE_BOOL else "expected bool"
		"int":
			return "" if typeof(value) == TYPE_INT else "expected int"
		"string":
			return "" if typeof(value) == TYPE_STRING and not str(value).is_empty() else "expected nonempty String"
		"string_or_null":
			if value == null or typeof(value) == TYPE_STRING:
				return ""
			return "expected String or null"
		"array_string":
			if typeof(value) != TYPE_ARRAY:
				return "expected Array of String"
			for element: Variant in value:
				if typeof(element) != TYPE_STRING:
					return "expected Array of String"
			return ""
		"dictionary":
			return "" if typeof(value) == TYPE_DICTIONARY else "expected Dictionary"
		"dictionary_or_null":
			if value == null or typeof(value) == TYPE_DICTIONARY:
				return ""
			return "expected Dictionary or null"
		"const_true":
			return "" if value == true else "expected true"
		"const_false":
			return "" if value == false else "expected false"
		"const_autosave":
			return "" if str(value) == "autosave" else "expected \"autosave\""
		"const_day_start":
			return "" if str(value) == "day_start" else "expected \"day_start\""
		"const_ending":
			return "" if str(value) == "ending" else "expected \"ending\""
		"const_ending_state":
			return "" if str(value) == "ENDING" else "expected \"ENDING\""
	return "unknown spec"

func _gate_identity_result(already_configured: bool) -> Dictionary:
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": already_configured},
		"receipt": {}}

static func _is_valid_gate(gate: Object) -> bool:
	if gate == null or not gate.has_signal("capability_changed"):
		return false
	return _has_all_methods(gate, GATE_METHODS)

static func _has_all_methods(target: Object, methods: Array[String]) -> bool:
	for method: String in methods:
		if not target.has_method(method):
			return false
	return true
