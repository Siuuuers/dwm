extends "res://addons/gut/test.gd"
## Source-backed pair admission: real Contacts commands and issuer, frozen lifecycle projection.
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const DATING := preload("res://scripts/application/run/DatingPresentationPort.gd")
const PHYSICAL := preload("res://tests/support/FakeDatingPresentationOwner.gd")

class FrozenLifecycle extends RefCounted:
	var plan: Dictionary
	func to_dict() -> Dictionary: return {"active_resolution_plan": plan.duplicate(true)}
	func get_day() -> int: return int(plan.source_day)

class State extends RefCounted:
	var contacts: Dictionary
	var _run_lifecycle: FrozenLifecycle = FrozenLifecycle.new()

class StartSeam extends RefCounted:
	func prepare_from_committed_schedule(_request: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"unused_fixture_start"}

var state: State
var issuer: RefCounted
var registry: RefCounted
var state_port: RefCounted
var dating: RefCounted
var physical: RefCounted

func before_each() -> void:
	issuer = ISSUER.new()
	assert_true(issuer.configure(ROOT.new("96".repeat(32), 1)).ok)
	registry = REGISTRY.load_current().value.registry
	state = State.new()
	state.contacts = CONTACTS.make_defaults()
	state_port = STATE_PORT.new(state)
	assert_true(state_port.configure_resolution_identity(issuer, StartSeam.new()).ok)
	physical = PHYSICAL.new()
	dating = DATING.new()
	assert_true(dating.configure(issuer, physical).ok)

func test_unopened_and_unanswered_windows_present_private_pair_on_days_two_and_six() -> void:
	for day in [2, 6]:
		for opened in [false, true]:
			_plan(day)
			_group(day)
			if opened: _open_or_reply(day, false)
			var before: Dictionary = state.contacts.duplicate(true)
			var site: Dictionary = state_port._deferred_pair_site()
			assert_false(site.is_empty())
			assert_eq(site.pair_preview.value.closure_receipt.pl_window.outcome, "private_visible")
			var request: Dictionary = _admit(site)
			assert_eq(request.context.schedule_entry_id, "group:priscilla_lavinia:day%d" % day)
			assert_eq(request.timeline_id, "dating.twofriends.priscilla_lavinia.day%d.pre_challenge" % day)
			assert_eq(state.contacts, before, "preview/admission queues and counts nothing")
			assert_eq(state._run_lifecycle.plan.committed_schedule.entries, [], "no Schedule entry is invented")

func test_accepted_unscheduled_group_presents_missed_pair_and_binds_real_sources() -> void:
	_plan(2)
	_group(2)
	_open_or_reply(2, false)
	_open_or_reply(2, true)
	var site: Dictionary = state_port._deferred_pair_site()
	assert_eq(site.pair_preview.value.closure_receipt.pl_window.outcome, "missed")
	var request: Dictionary = _admit(site)
	assert_eq(request.context.kind, "twofriends_if_deferred")
	var inputs: Dictionary = state_port._presentation_inputs(site, {})
	assert_true(inputs.ok)
	assert_has(inputs.value.input_receipt_ids, state.contacts.group_action.transaction_id)
	for receipt: Dictionary in state.contacts.schedule_source_receipts.values():
		assert_has(inputs.value.input_receipt_ids, receipt.receipt_id)

func test_attended_group_suppresses_second_board_and_hospital_supersession_keeps_original_identity() -> void:
	_plan(2)
	_group(2)
	_open_or_reply(2, false)
	_open_or_reply(2, true)
	_completed_date("group", false)
	assert_true(state_port._deferred_pair_site().is_empty(), "attended group already had its board")
	_completed_date("group", true)
	var site: Dictionary = state_port._deferred_pair_site()
	assert_eq(site.schedule_entry_id, "committed.date")
	assert_false(site.has("pair_preview"), "existing Hospital command ancestry remains unchanged")
	var inputs: Dictionary = state_port._presentation_inputs(site, {})
	assert_eq(inputs.value.input_receipt_ids, ["committed.date", "source.committed.date"])
	assert_eq(_admit(site).context.kind, "twofriends_if_deferred")

func test_actual_solo_attendance_prevents_pair_but_hospital_superseded_solo_does_not() -> void:
	_plan(2)
	_group(2)
	_completed_date("solo", false)
	assert_true(state_port._deferred_pair_site().is_empty())
	_completed_date("solo", true)
	var site: Dictionary = state_port._deferred_pair_site()
	assert_false(site.is_empty())
	assert_eq(site.pair_preview.value.closure_receipt.pl_window.outcome, "private_visible")
	assert_false(_admit(site).is_empty())

func test_absent_group_is_offscreen_and_rollover_is_the_only_count_authority() -> void:
	_plan(2)
	assert_true(state_port._deferred_pair_site().is_empty())
	var rollover: String = _stage("invitation_rollover").transaction_id
	var offscreen: Dictionary = state_port._prepare_contacts_day_end(rollover)
	assert_eq(offscreen.receipt.pl_window, {"outcome": "private_offscreen", "counts": true, "visible": false})
	_group(2)
	var before: Dictionary = state.contacts.duplicate(true)
	var site: Dictionary = state_port._deferred_pair_site()
	var prepared: Dictionary = state_port._prepare_contacts_day_end(rollover)
	assert_eq(site.pair_preview.value.closure_receipt, prepared.receipt)
	assert_eq(state.contacts, before)
	assert_eq(prepared.receipt.counter_deltas["pl_window_counts.priscilla_lavinia"], 1)
	state.contacts = prepared.value.candidate
	var replay: Dictionary = state_port._prepare_contacts_day_end(rollover)
	assert_eq(replay.receipt, prepared.receipt)
	assert_eq(replay.value.candidate, state.contacts)

func test_changed_or_missing_operation_source_refuses_admission_and_cold_preview_is_stable() -> void:
	_plan(2)
	_group(2)
	var original: Dictionary = state.contacts.duplicate(true)
	var site: Dictionary = state_port._deferred_pair_site()
	var request: Dictionary = _admit(site)
	var fresh: RefCounted = STATE_PORT.new(state)
	assert_true(fresh.configure_resolution_identity(issuer, StartSeam.new()).ok)
	var restored_site: Dictionary = fresh._deferred_pair_site()
	assert_eq(restored_site, site)
	assert_eq(fresh._presentation_command(_stage("twofriends_if_deferred"), restored_site).value.presentation_request, request)
	_open_or_reply(2, false)
	assert_false(state_port._presentation_inputs(site, {}).ok, "an admission cannot change its preview source")
	state.contacts = original
	state.contacts.transaction_receipts.erase(state.contacts.group_action.transaction_id)
	var missing: Dictionary = state_port._deferred_pair_site()
	assert_false(missing.is_empty(), "missing proof fails admission rather than silently skipping the board")
	assert_false(state_port._presentation_command(_stage("twofriends_if_deferred"), missing).ok)

func test_accepted_source_with_unreproducible_child_id_is_refused() -> void:
	_plan(2)
	_group(2)
	_open_or_reply(2, false)
	_open_or_reply(2, true)
	var sources: Dictionary = state.contacts.schedule_source_receipts
	var original_id: String = str(sources.keys()[0])
	var source: Dictionary = sources[original_id].duplicate(true)
	var forged_id: String = "contact_source." + "f".repeat(64)
	source.receipt_id = forged_id
	source.receipt_provenance.child_id = forged_id
	sources.erase(original_id)
	sources[forged_id] = source
	for operation: Dictionary in state.contacts.transaction_receipts.values():
		if operation.get("source_receipt_id") == original_id: operation.source_receipt_id = forged_id
	assert_true(CONTACTS.validate_state(state.contacts).ok, "shape and operation linkage alone cannot prove child identity")
	var preview: Dictionary = state_port._deferred_pair_preview()
	assert_false(preview.ok)
	assert_eq(preview.get("code"), &"child_id_not_reproducible")
	var site: Dictionary = state_port._deferred_pair_site()
	assert_false(state_port._presentation_command(_stage("twofriends_if_deferred"), site).ok)

func _plan(day: int) -> void:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	var stages: Array = []
	for id: String in PLAN.stage_allowlist(day):
		stages.append({"stage_id": id, "transaction_id": str(issued.value.token) + ":" + id,
			"state": "pending", "substages": [], "receipt": null})
	state._run_lifecycle.plan = {"source_day": day, "resolution_id": issued.value.token,
		"resolution_issuer_receipt": issued.value.issuer_receipt,
		"day_resolution_start_receipt": {"receipt_id": "frozen.start", "causal_day_instance": "frozen.causal.day"},
		"committed_schedule": {"entries": []}, "route_plan": [], "stages": stages}

func _stage(id: String) -> Dictionary:
	for stage: Dictionary in state._run_lifecycle.plan.stages:
		if stage.stage_id == id: return stage
	return {}

func _group(day: int) -> void:
	state.contacts = CONTACTS.make_defaults()
	for friend: String in ["priscilla", "lavinia"]:
		var offer: Dictionary = CONTACTS.prepare_offer_solo(state.contacts, friend, day,
			"offer." + friend, "offer.tx." + friend)
		assert_true(offer.ok)
		state.contacts = offer.value.candidate
	var activation: Dictionary = issuer.issue(&"transaction_id")
	var grouped: Dictionary = CONTACTS.prepare_activate_group_after_round(state.contacts, day, 2, 3, activation.value.token)
	assert_true(grouped.ok)
	state.contacts = grouped.value.candidate
	assert_true(CONTACTS.validate_state(state.contacts).ok)

func _open_or_reply(day: int, reply: bool) -> void:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	var action: Dictionary = registry.find_record("group:priscilla_lavinia:day%d" % day).value.record
	var changed: Dictionary
	if reply:
		changed = CONTACTS.prepare_reply(state.contacts, "priscilla", day, issued.value.token,
			issued.value.issuer_receipt, issuer, action)
	else:
		changed = CONTACTS.prepare_open_contact(state.contacts, "priscilla", day, issued.value.token,
			issued.value.issuer_receipt, issuer, action)
	assert_true(changed.ok, str(changed))
	if changed.ok: state.contacts = changed.value.candidate

func _completed_date(kind: String, superseded: bool) -> void:
	var day: int = state._run_lifecycle.get_day()
	var action_id: String = "group:priscilla_lavinia:day%d" % day if kind == "group" else "solo:priscilla:day%d" % day
	var entry: Dictionary = {"schedule_entry_id": "committed.date", "action_kind": kind,
		"action_id": action_id, "participants": ["priscilla", "lavinia"] if kind == "group" else ["priscilla"],
		"source_receipt_id": "source.committed.date", "slot_index": 0}
	state._run_lifecycle.plan.committed_schedule.entries = [entry]
	state._run_lifecycle.plan.route_plan = [entry]
	var dates: Dictionary = _stage("execute_schedule_dates")
	dates.state = "completed"
	dates.substages = [{"state": "completed", "transaction_id": "completed.date.receipt",
		"receipt": {"value": {"entry_receipt_id": "committed.date", "superseded": superseded}}}]
	var hospital: Dictionary = _stage("hospital_if_triggered")
	hospital.state = "completed"
	hospital.receipt = {"value": {"superseded_entry_ids": ["committed.date"] if superseded else []}}

func _admit(site: Dictionary) -> Dictionary:
	var begun: Dictionary = state_port._presentation_command(_stage("twofriends_if_deferred"), site)
	assert_true(begun.ok, str(begun))
	if not begun.ok: return {}
	var request: Dictionary = begun.value.presentation_request
	var accepted: Dictionary = dating.begin(request)
	assert_true(accepted.ok, str(accepted))
	return request
