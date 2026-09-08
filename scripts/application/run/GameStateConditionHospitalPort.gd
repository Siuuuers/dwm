class_name GameStateConditionHospitalPort
extends RefCounted

## The existing ConditionHospitalPlan owns progress. This adapter prepares detached owner
## values and reuses the same physical Hospital/Dating ports and causal-day allocator.
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const CLOSURE := preload("res://scripts/application/run/ConditionHospitalContactsAdapter.gd")
const VIEW := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const BOARD := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const RULES := preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd")

signal progress_ready()
signal presentation_failed(failure: Dictionary)

var _game: Object
var _issuer: Object
var _day_advance: Object
var _view: Object
var _board: Object
var _consequence: Object
var _capture_inputs := Callable()
var _hospital: Object
var _dating: Object
var _route := Callable()
var _commands: Dictionary = {}
var _completions: Dictionary = {}
var _routed: Dictionary = {}
var _published_days: Dictionary = {}
var _pair_deck: Object = null

func configure(game_state: Object, identity_issuer: Object, causal_day_advance: Object,
		schedule_view: Object, board_state: Object, consequence_state: Object,
		checkpoint_inputs: Callable) -> Dictionary:
	if game_state == null or not game_state.has_method("capture_run_snapshot_input") \
			or not game_state.has_method("_apply_gameplay_silent"):
		return _fail(&"invalid_game_state")
	if identity_issuer == null or not identity_issuer.has_method("derive_child") \
			or causal_day_advance == null or not causal_day_advance.has_method("commit_advance") \
			or schedule_view == null or not schedule_view.has_method("install_restored_view") \
			or board_state == null or not board_state.has_method("prepare_restore") \
			or consequence_state == null or not consequence_state.has_method("prepare_restore") \
			or not checkpoint_inputs.is_valid(): return _fail(&"invalid_condition_hospital_owners")
	if _game != null:
		return _ok({}) if _game == game_state and _issuer == identity_issuer \
			and _day_advance == causal_day_advance and _view == schedule_view and _board == board_state \
			and _consequence == consequence_state and _capture_inputs == checkpoint_inputs \
			else _fail(&"condition_hospital_adapter_already_configured")
	_game = game_state
	_issuer = identity_issuer
	_day_advance = causal_day_advance
	_view = schedule_view
	_board = board_state
	_consequence = consequence_state
	_capture_inputs = checkpoint_inputs
	return _ok({})

func configure_pair_deck(port: Object) -> Dictionary:
	if port == null or not port.has_method("prepare_condition"): return _fail(&"pair_deck_unavailable")
	if _pair_deck != null and _pair_deck != port: return _fail(&"pair_deck_already_configured")
	_pair_deck = port
	return _ok({})

func configure_presentation(hospital_port: Object, route_presentation: Callable,
		dating_port: Object = null) -> Dictionary:
	if hospital_port == null or not hospital_port.has_method("begin") \
			or not hospital_port.has_signal("completion_ready") or not route_presentation.is_valid():
		return _fail(&"invalid_condition_hospital_presentation")
	if _hospital != null and (_hospital != hospital_port or _route != route_presentation or _dating != dating_port):
		return _fail(&"condition_hospital_presentation_already_configured")
	_hospital = hospital_port
	_dating = dating_port
	_route = route_presentation
	for port: Object in [_hospital, _dating]:
		if port == null: continue
		if not port.is_connected("completion_ready", _on_completion): port.connect("completion_ready", _on_completion)
		if port.has_signal("completion_failed") and not port.is_connected("completion_failed", _on_failure):
			port.connect("completion_failed", _on_failure)
	return _ok({})

func prepare_stage(plan: Dictionary, stage_id: String) -> Dictionary:
	if _game == null: return _fail(&"condition_hospital_adapter_unconfigured")
	var live: Dictionary = _game._run_lifecycle.to_dict()
	if _hash(live.get("active_condition_hospital_plan")) != _hash(plan):
		return _fail(&"condition_hospital_plan_conflict")
	var inputs: Array = [str(plan.resolution_receipt.receipt_id)]
	var prepared := {"kind": stage_id}
	match stage_id:
		"close_invitation_sources":
			var closed: Dictionary = CLOSURE.prepare(_game.contacts, plan, _issuer)
			if not closed.get("ok", false): return closed
			prepared["owner_candidate"] = {"contacts": closed.value.contacts,
				"gameplay": _closure_gameplay(closed.value.misses)}
			prepared["output"] = closed.value.output
			if _pair_window_counts(closed.value.output.get("pl_window")):
				var pair_candidate := _prepare_pair_candidate(prepared.owner_candidate)
				if not pair_candidate.ok: return pair_candidate
				prepared["owner_candidate"] = pair_candidate.value
			for source: Dictionary in plan.accepted_sources: inputs.append(str(source.receipt_id))
		"present_hospital":
			var closure: Dictionary = plan.stages[0].receipt.output
			var context := {"kind": "hospital", "day": int(plan.source_day),
				"source_entry_ids": closure.source_receipt_ids.duplicate(true),
				"miss_receipt_ids": closure.miss_receipt_ids.duplicate(true)}
			var request := _presentation_request(plan, stage_id, context, "hospital.faint", _hospital)
			if not request.get("ok", false): return request
			prepared["presentation_request"] = request.value.request
		"resolve_deferred_pair":
			var window: Variant = plan.stages[0].receipt.output.get("pl_window")
			# Contacts' frozen receipt is the count authority; route frozen_form stays untouched.

			prepared["output"] = {"pl_window": window, "after_hospital": true}
		"present_deferred_pair":
			var window: Variant = plan.stages[2].receipt.output.get("pl_window")
			prepared["required"] = window is Dictionary and bool(window.get("visible", false))
			if prepared.required:
				var context := {"kind": "twofriends_if_deferred", "day": int(plan.source_day),
					"participants": ["priscilla", "lavinia"],
					"schedule_entry_id": "group:priscilla_lavinia:day%d" % int(plan.source_day)}
				var request := _presentation_request(plan, stage_id, context,
					"dating.twofriends.priscilla_lavinia.day%d.pre_challenge" % int(plan.source_day), _dating)
				if not request.get("ok", false): return request
				prepared["presentation_request"] = request.value.request
		"advance_day":
			var advance := _prepare_day(plan)
			if not advance.get("ok", false): return advance
			prepared.merge(advance.value, true)
		"autosave_new_day": pass
		_: return _fail(&"condition_hospital_stage_invalid")
	inputs.sort()
	return _ok({"input_receipt_ids": inputs, "prepared": prepared})

func execute_stage(_plan: Dictionary, stage: Dictionary) -> Dictionary:
	var prepared: Dictionary = stage.prepared
	var stage_id := str(stage.stage_id)
	if prepared.has("presentation_request"):
		if stage_id == "present_deferred_pair":
			if _pair_deck == null: return _fail(&"pair_deck_unconfigured")
			var pair_ready: Dictionary = _pair_deck.prepare_condition(true)
			if not pair_ready.get("ok", false): return pair_ready
		var request: Dictionary = prepared.presentation_request
		var key := str(request.completion_transaction_id)
		if _completions.has(key):
			return _ok({"output": {"presented": true, "presentation_completion_receipt": _completions[key].duplicate(true)},
				"owner_candidate": null})
		var port: Object = _hospital if stage_id == "present_hospital" else _dating
		if port == null: return _fail(&"condition_hospital_presentation_unconfigured")
		_commands[key] = request.duplicate(true)
		var begun: Dictionary = port.begin(request)
		if not begun.get("ok", false): return begun
		if not _routed.has(key):
			var routed: Dictionary = _route.call(str(request.route_id), begun.value.presentation_command)
			if not routed.get("ok", false): return routed
			_routed[key] = true
		return _ok({"awaiting_presentation": true})
	var owner_candidate: Variant = prepared.get("owner_candidate")
	# Old active-stage saves may predate draw binding. Reconcile their count candidate
	# against the Profile receipt before the stage can durably complete.
	if stage_id == "close_invitation_sources" and _pair_window_counts(prepared.get("output", {}).get("pl_window")):
		var pair_candidate := _prepare_pair_candidate(owner_candidate)
		if not pair_candidate.ok: return pair_candidate
		owner_candidate = pair_candidate.value
	return _ok({"output": prepared.get("output", {"presented": false}).duplicate(true),
		"owner_candidate": owner_candidate})

func _prepare_pair_candidate(candidate: Dictionary) -> Dictionary:
	if _pair_deck == null: return _fail(&"pair_deck_unconfigured")
	var drawn: Dictionary = _pair_deck.prepare_condition()
	if not drawn.get("ok", false): return drawn
	var detached := candidate.duplicate(true)
	detached.gameplay.inter_friend_route_state["priscilla_lavinia"] = drawn.value.pair_state.duplicate(true)
	return _ok(detached)

static func _pair_window_counts(window: Variant) -> bool:
	return window is Dictionary and bool(window.get("counts", false))

func compose_checkpoint_inputs(lifecycle: Dictionary, owner_candidate: Variant,
		consequence_candidate: Variant = null) -> Dictionary:
	var inputs: Dictionary = _capture_inputs.call(lifecycle.duplicate(true))
	for key: String in ["snapshot_input", "dialogic_checkpoint", "route_id", "active_app_id", "audio_context", "content_version"]:
		if not inputs.has(key): return _fail(&"condition_hospital_checkpoint_inputs_incomplete")
	var snapshot: Dictionary = inputs.snapshot_input.duplicate(true)
	snapshot["lifecycle"] = lifecycle.duplicate(true)
	snapshot["schedule_view"] = _view.snapshot().value.view
	snapshot["desktop"] = {"board": _board.capture(), "consequence": _consequence.capture().value.state}
	if owner_candidate is Dictionary:
		for key: String in owner_candidate:
			if key == "desktop":
				for part: String in owner_candidate.desktop: snapshot.desktop[part] = owner_candidate.desktop[part].duplicate(true)
			else: snapshot[key] = owner_candidate[key].duplicate(true)
	if consequence_candidate is Dictionary: snapshot.desktop.consequence = consequence_candidate.state_after.duplicate(true)
	inputs["snapshot_input"] = snapshot
	# Completed stage boundaries contain no active narrative resume. The persisted stage
	# command owns replay; target-day checkpoints always reopen the desktop.
	inputs["dialogic_checkpoint"] = {}
	inputs["route_id"] = "main"
	return _ok({"checkpoint_inputs": inputs})

func commit_stage(_stage_id: String, candidate: Variant) -> Dictionary:
	if candidate == null: return _ok({})
	if not candidate is Dictionary: return _fail(&"condition_hospital_owner_candidate_invalid")
	# All plans were validated before the checkpoint; these installs apply absolute values.
	if candidate.has("contacts"): _game.contacts = candidate.contacts.duplicate(true)
	if candidate.has("gameplay"): _game._apply_gameplay_silent(candidate.gameplay)
	if candidate.has("committed_schedule"): _game._committed_schedule = candidate.committed_schedule.duplicate(true)
	if candidate.has("schedule_view"):
		var view: Dictionary = _view.install_restored_view(candidate.schedule_view)
		if not view.get("ok", false): return view
	if candidate.has("desktop"):
		for pair: Array in [["board", _board], ["consequence", _consequence]]:
			if not candidate.desktop.has(pair[0]): continue
			var restored: Dictionary = pair[1].prepare_restore(candidate.desktop[pair[0]])
			if not restored.get("ok", false): return restored
			var committed: Dictionary = pair[1].commit(restored.value.candidate)
			if not committed.get("ok", false): return committed
	return _ok({})

func _prepare_day(plan: Dictionary) -> Dictionary:
	if not _game.has_method("capture_new_day_gameplay"): return _fail(&"condition_hospital_day_reset_unavailable")
	# The allocator/root-store contract hashes this exact two-key identity projection.
	# Keep the full acceptance receipt unchanged in the owning persisted Hospital plan.
	var resolution := {"receipt_id": str(plan.resolution_receipt.receipt_id),
		"provenance": plan.resolution_receipt.receipt_provenance.duplicate(true)}
	var request := {"resolution_kind": "condition_hospital", "source_resolution_receipt": resolution,
		"run_id": plan.run_id, "branch_id": plan.branch_id,
		"desktop_timeline_generation": plan.desktop_timeline_generation, "source_day": plan.source_day,
		"source_causal_day_instance": plan.causal_day_instance,
		"source_causal_day_instance_issuer_receipt": plan.causal_day_instance_issuer_receipt}
	var prepared: Dictionary = _day_advance.prepare_advance(request)
	if not prepared.get("ok", false): return prepared
	var committed: Dictionary = _day_advance.commit_advance(prepared.value.day_advance_identity_candidate)
	if not committed.get("ok", false): return committed
	var allocation: Dictionary = committed.value.day_advance_identity_receipt
	var gameplay: Dictionary = _game.capture_new_day_gameplay()
	gameplay.stats["health"] = RULES.HOSPITAL_RECOVERY.health
	gameplay.stats["pressure"] = RULES.HOSPITAL_RECOVERY.pressure
	gameplay["condition_effects_today"] = []
	gameplay["condition_streak_days"] = 0
	gameplay["condition_resolved_day"] = 0
	gameplay["pending_hospital"] = false
	var target_day := int(allocation.target_day)
	var causal := str(allocation.target_causal_day_instance)
	var view: Dictionary = VIEW.make_empty(target_day, causal).value.view
	view.condition_departure_receipts = _view.snapshot().value.view.condition_departure_receipts.duplicate(true)
	var consequence: Dictionary = CONSEQUENCE.make_empty({"causal_day_instance": causal,
		"causal_day_instance_issuer_receipt": allocation.target_causal_day_instance_issuer_receipt}).value.state
	var owner := {"gameplay": gameplay,
		"committed_schedule": {"schema_version": 1, "day": target_day, "registry_fingerprint": null,
			"entries": [], "commit_receipt": null}, "schedule_view": view,
		"desktop": {"board": BOARD.new().capture(), "consequence": consequence}}
	return _ok({"target_day": target_day, "target_causal_day_instance": causal,
		"target_causal_day_instance_issuer_receipt": allocation.target_causal_day_instance_issuer_receipt,
		"owner_candidate": owner, "output": {"target_day": target_day,
			"target_causal_day_instance": causal,
			"target_causal_day_instance_issuer_receipt": allocation.target_causal_day_instance_issuer_receipt,
			"day_advance_identity_receipt": allocation}})

func _presentation_request(plan: Dictionary, stage_id: String, context: Dictionary,
		timeline_id: String, port: Object) -> Dictionary:
	if port == null: return _fail(&"condition_hospital_presentation_unconfigured")
	var root_id := str(plan.transaction_issuer_receipt.receipt_id)
	var ordinal := 1 if stage_id == "present_hospital" else 3
	var sources: Array = ["condition_hospital=" + str(plan.resolution_receipt.receipt_id),
		"stage=" + stage_id, "context=" + _hash(context)]
	sources.sort()
	var intent: Dictionary = _issuer.derive_child({"child_kind": "day_resolution_stage",
		"parent_receipt_id": root_id, "ordinal": ordinal, "source_ids": sources})
	if not intent.get("ok", false): return intent
	var request := {"resolution_id": str(plan.resolution_receipt.receipt_id),
		"resolution_issuer_receipt": plan.transaction_issuer_receipt.duplicate(true),
		"stage_id": str(plan.resolution_receipt.receipt_id) + ":" + stage_id,
		"substage_id": str(intent.value.child_id), "route_id": "hospital" if stage_id == "present_hospital" else "dating",
		"timeline_id": timeline_id, "context": context,
		"completion_transaction_id": "", "completion_transaction_provenance": {}}
	var completion: Dictionary = _issuer.derive_child({"child_kind": "day_resolution_stage",
		"parent_receipt_id": root_id, "ordinal": ordinal,
		"source_ids": port._completion_sources(request)})
	if not completion.get("ok", false): return completion
	request.completion_transaction_id = str(completion.value.child_id)
	request.completion_transaction_provenance = completion.value.provenance.duplicate(true)
	return _ok({"request": request})

func _closure_gameplay(misses: Array) -> Dictionary:
	var gameplay: Dictionary = _game.capture_run_snapshot_input().gameplay
	var retained: Array = gameplay.get("missed_invitations", []).duplicate(true)
	for miss: Dictionary in misses:
		for friend: String in miss.participants:
			retained.append({"friend_id": friend, "source": "group" if miss.participants.size() > 1 else "solo",
				"day": int(miss.day), "missed_reason": "hospital", "source_receipt_id": miss.source_receipt_id,
				"hospital_miss_receipt_id": miss.receipt_id})
	gameplay["missed_invitations"] = retained
	return gameplay

func _on_completion(result: Dictionary) -> void:
	var receipt: Dictionary = result.get("value", {}).get("completion_receipt", result.get("receipt", {}))
	var key := str(receipt.get("receipt_id", ""))
	if not _commands.has(key): return
	var request: Dictionary = _commands[key]
	if receipt.get("resolution_id") != request.resolution_id or receipt.get("stage_id") != request.stage_id:
		return
	_completions[key] = receipt.duplicate(true)
	progress_ready.emit()

func _on_failure(failure: Dictionary) -> void:
	if not _commands.is_empty(): presentation_failed.emit(failure.duplicate(true))

static func _hash(value: Variant) -> String:
	var encoded: Dictionary = CANON.stringify(value)
	return str(encoded.value).sha256_text() if encoded.get("ok", false) else ""

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": str(code), "details": {}}

func publish_stage(stage_id: String, candidate: Variant) -> Dictionary:
	if stage_id != "advance_day" or not candidate is Dictionary: return _ok({})
	var causal := str(candidate.schedule_view.causal_day_instance)
	if _published_days.has(causal): return _ok({})
	_published_days[causal] = true
	_game.emit_signal("day_changed", int(candidate.schedule_view.day))
	_game.emit_signal("daily_state_reset")
	_game.emit_signal("save_relevant_state_changed")
	return _ok({})