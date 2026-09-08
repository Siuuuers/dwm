extends "res://addons/gut/test.gd"
# Invitation closure AFTER a Schedule-Done Hospital (Plan 01 Task 7 Step 7.3, dwm-p2r.14).
#
# WHAT THIS FILE OWNS. Hospital supersedes every committed date before any board runs; the day-end
# rollover then has to close those invitations correctly. A friend whose date was prevented by the
# faint is still MISSED and still asks about it -- EXCEPT Sylvia, when she witnessed the faint. She
# saw why the date did not happen, so she sends care the next day instead of asking what happened.
#
# The witness index is the seam that carries that fact from the Hospital transaction to the
# rollover. It is an append-only HANDOFF: rollover READS it and never consumes or clears it, so it
# survives for dwm-oyo.4.
#
# PURE DOMAIN. This suite drives ContactInvitationState directly over a real identity issuer. No
# GameState, no coordinator: the closure law is domain law, and testing it here keeps it honest.

const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const HOSPITAL_RULES := preload("res://scripts/domain/hospital/HospitalRules.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")

const WITNESS_INDEX := "sylvia_hospital_witness_receipts"
const FAINT_DAY := 3

var _root := ""
var _root_counter := 0
var _issuer: RefCounted
var _registry: RefCounted
var _commands: Dictionary = {}


func before_each() -> void:
	_commands = {}
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	_root = wrapper.path_join("hospital-closures-%d" % _root_counter)
	assert_eq(DirAccess.make_dir_recursive_absolute(_root), OK)

	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(JsonFileStorage.new(_root), NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(root_store).get("ok", false))

	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")


# ---- closure after a faint ----

func test_a_witnessing_sylvia_asks_no_missed_question() -> void:
	var state := _accepted_solo(CONTACT_STATE.make_defaults(), "sylvia", FAINT_DAY)
	state = _with_witness(state, "solo:sylvia:day%d" % FAINT_DAY)

	var resolved := _resolve_day_end(state)
	assert_true(resolved.get("ok", false), JSON.stringify(resolved))
	if not resolved.get("ok", false):
		return

	# She is still MISSED -- the date genuinely did not happen.
	assert_eq(_action_state(resolved, "solo:sylvia:day%d" % FAINT_DAY), "RESOLVED_MISSED",
		"a prevented date is still a missed date")
	# But she does not ask what happened, because she was there.
	assert_false(_queued_types(resolved, "sylvia").has("missed_question"),
		"a witnessing Sylvia sends care next day rather than asking what happened")


func test_without_a_witness_sylvia_asks_normally() -> void:
	# The control. Same faint, same missed date, no witness record: the ordinary closure applies.
	var state := _accepted_solo(CONTACT_STATE.make_defaults(), "sylvia", FAINT_DAY)

	var resolved := _resolve_day_end(state)
	assert_true(resolved.get("ok", false), JSON.stringify(resolved))
	if not resolved.get("ok", false):
		return
	assert_eq(_action_state(resolved, "solo:sylvia:day%d" % FAINT_DAY), "RESOLVED_MISSED")
	assert_true(_queued_types(resolved, "sylvia").has("missed_question"),
		"without a witness the ordinary missed-question closure applies")


func test_a_sylvia_witness_never_suppresses_another_friend() -> void:
	# Lavinia's date was prevented by the same faint, but she did not witness it, so she still asks.
	var state := _accepted_solo(CONTACT_STATE.make_defaults(), "sylvia", FAINT_DAY)
	state = _accepted_solo(state, "lavinia", FAINT_DAY)
	state = _with_witness(state, "solo:sylvia:day%d" % FAINT_DAY)

	var resolved := _resolve_day_end(state)
	assert_true(resolved.get("ok", false), JSON.stringify(resolved))
	if not resolved.get("ok", false):
		return
	assert_false(_queued_types(resolved, "sylvia").has("missed_question"),
		"the witness suppresses only the friend who witnessed")
	assert_true(_queued_types(resolved, "lavinia").has("missed_question"),
		"another friend's missed question is untouched by a Sylvia witness")


func test_the_witness_index_survives_the_rollover_it_informed() -> void:
	# APPEND-ONLY HANDOFF. Rollover reads the index; it never consumes, clears, or rewrites it,
	# because dwm-oyo.4 consumes it after this plan has retired.
	var state := _accepted_solo(CONTACT_STATE.make_defaults(), "sylvia", FAINT_DAY)
	state = _with_witness(state, "solo:sylvia:day%d" % FAINT_DAY)
	var before: Dictionary = (state[WITNESS_INDEX] as Dictionary).duplicate(true)

	var resolved := _resolve_day_end(state)
	assert_true(resolved.get("ok", false), JSON.stringify(resolved))
	if not resolved.get("ok", false):
		return
	var after: Dictionary = _candidate(resolved)[WITNESS_INDEX]
	assert_eq(after, before, "the witness index is byte-identical after the rollover it informed")
	assert_true(CONTACT_STATE.validate_state(_candidate(resolved)).get("ok", false),
		"the closed state still validates with its witness intact")


# ---- helpers ----

## An ACCEPTED solo for `friend` on `day`. Opening a solo offer IS its acceptance, so offer+open
## leaves the action in the state the day-end rollover treats as a missed date.
func _accepted_solo(state: Dictionary, friend: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend, day]
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
		state, friend, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	if not offered.get("ok", false):
		return state
	var command := _command("open." + action_id)
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		offered["value"]["candidate"], friend, day, command["id"], command["receipt"],
		_issuer, _record(action_id))
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return state
	return opened["value"]["candidate"]


## Writes the exact witness record the Hospital transaction would have committed.
func _with_witness(state: Dictionary, action_id: String) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	(detached[WITNESS_INDEX] as Dictionary)["witness." + action_id] = {
		"kind": HOSPITAL_RULES.WITNESS_KIND,
		"resolution_kind": HOSPITAL_RULES.WITNESS_RESOLUTION_KIND,
		"schedule_entry_id": "schedule_entry." + action_id,
		"action_id": action_id,
		"source_receipt_id": "source." + action_id,
		"hospital_miss_ordinal": 0,
		"care_followup_day": FAINT_DAY + 1,
		"care_followup_entry_id": "care.sylvia.day%d" % (FAINT_DAY + 1),
		"affection_delta": HOSPITAL_RULES.WITNESS_AFFECTION_DELTA,
		"dark_delta": HOSPITAL_RULES.WITNESS_DARK_DELTA,
		"attitude": HOSPITAL_RULES.WITNESS_ATTITUDE,
		"tier_transition": HOSPITAL_RULES.WITNESS_TIER_TRANSITION,
	}
	assert_true(CONTACT_STATE.validate_state(detached).get("ok", false),
		"the seeded witness is a valid record")
	return detached


## Day-end with NOTHING attended: every accepted date was prevented by the faint.
func _resolve_day_end(state: Dictionary) -> Dictionary:
	return CONTACT_STATE.prepare_resolve_day_end(
		state, FAINT_DAY, {"solo_attended_action_ids": []}, "rollover.day%d" % FAINT_DAY)


func _candidate(resolved: Dictionary) -> Dictionary:
	return (resolved["value"] as Dictionary)["candidate"]


func _action_state(resolved: Dictionary, action_id: String) -> String:
	return str((_candidate(resolved)["solo_actions"] as Dictionary)[action_id]["state"])


## The message types queued FOR one friend by this rollover.
func _queued_types(resolved: Dictionary, friend: String) -> Array:
	var types: Array = []
	for message: Variant in ((_candidate(resolved)["messages"] as Dictionary)[friend] as Array):
		types.append(str((message as Dictionary).get("type", "")))
	return types


func _record(action_id: String) -> Dictionary:
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	return ((found.get("value", {}) as Dictionary).get("record", {}) as Dictionary)


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


func _condition_plan(state: Dictionary, source_day: int = FAINT_DAY) -> Dictionary:
	var sources: Array = []
	for receipt_id: String in state.schedule_source_receipts:
		var source: Dictionary = state.schedule_source_receipts[receipt_id]
		if int(source.day) == source_day:
			sources.append({"action_id": source.action_id, "receipt_id": receipt_id})
	sources.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.action_id) < str(right.action_id))
	var root := _command("condition.hospital")
	var derived: Dictionary = _issuer.derive_child({"child_kind": "hospital_resolution",
		"parent_receipt_id": root.receipt.receipt_id, "ordinal": 0, "source_ids": ["condition.fixture"]})
	assert_true(derived.get("ok", false), str(derived))
	return {"source_day": source_day, "accepted_sources": sources,
		"resolution_receipt": {"receipt_id": derived.value.child_id,
			"receipt_provenance": derived.value.provenance}}

func test_condition_hospital_closes_exact_sources_and_retains_distinct_sylvia_witness() -> void:
	var state := _accepted_solo(CONTACT_STATE.make_defaults(), "sylvia", FAINT_DAY)
	state = _accepted_solo(state, "lavinia", FAINT_DAY)
	var before := state.duplicate(true)
	var plan := _condition_plan(state)
	var helper := preload("res://scripts/application/run/ConditionHospitalContactsAdapter.gd")
	var result: Dictionary = helper.prepare(state, plan, _issuer)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_eq(state, before, "preparing Hospital closure never mutates Contacts")
	assert_eq(result.value.misses.size(), 2, "each accepted source has one separate Hospital miss")
	for miss: Dictionary in result.value.misses:
		assert_true(_issuer.validate_child(miss.receipt_provenance, &"hospital_miss").get("ok", false))
		assert_true(miss.receipt_provenance.source_ids.has(plan.resolution_receipt.receipt_id))
	var candidate: Dictionary = result.value.contacts
	assert_eq(candidate.solo_actions["solo:sylvia:day3"].state, "RESOLVED_MISSED")
	assert_eq(candidate.solo_actions["solo:lavinia:day3"].state, "RESOLVED_MISSED")
	assert_true(CONTACT_STATE.validate_state(candidate).get("ok", false))
	var witness: Dictionary = result.value.output.sylvia_witness
	assert_eq(witness.resolution_kind, "condition_hospital")
	assert_true(_issuer.validate_child(witness.receipt_provenance, &"sylvia_hospital_witness").get("ok", false))
	assert_true(witness.receipt_provenance.source_ids.has(plan.resolution_receipt.receipt_id))
	assert_false(witness.has("schedule_entry_id"), "pre-Done never fabricates a committed Schedule entry")
	assert_eq(witness.affection_delta, 2, "the record freezes future care; it applies no relationship fields")
	assert_false(candidate.messages.sylvia.any(func(row: Dictionary) -> bool: return row.type == "missed_question"))
	assert_true(candidate.messages.lavinia.any(func(row: Dictionary) -> bool: return row.type == "missed_question"))
	var replay: Dictionary = helper.prepare(state, plan, _issuer)
	assert_eq(preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify(replay.value).value,
		preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify(result.value).value)

func test_condition_hospital_refuses_changed_source_before_closure() -> void:
	var state := _accepted_solo(CONTACT_STATE.make_defaults(), "sylvia", FAINT_DAY)
	var before := state.duplicate(true)
	var plan := _condition_plan(state)
	plan.accepted_sources[0]["action_id"] = "solo:lavinia:day3"
	var result: Dictionary = preload("res://scripts/application/run/ConditionHospitalContactsAdapter.gd").prepare(state, plan, _issuer)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"condition_hospital_source_mismatch")
	assert_eq(state, before)

func test_condition_hospital_preserves_offscreen_pair_window_without_a_fake_date() -> void:
	var state := CONTACT_STATE.make_defaults()
	var result: Dictionary = preload("res://scripts/application/run/ConditionHospitalContactsAdapter.gd").prepare(
		state, _condition_plan(state, 2), _issuer)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_eq(result.value.output.pl_window, {"outcome": "private_offscreen", "counts": true, "visible": false})
	assert_eq(result.value.misses, [])
	assert_eq(result.value.output.closure_receipt.counter_deltas, {"pl_window_counts.priscilla_lavinia": 1})

func test_condition_witness_cannot_be_retagged_as_schedule_done() -> void:
	var state := _accepted_solo(CONTACT_STATE.make_defaults(), "sylvia", FAINT_DAY)
	var result: Dictionary = preload("res://scripts/application/run/ConditionHospitalContactsAdapter.gd").prepare(
		state, _condition_plan(state), _issuer)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	var witness: Dictionary = result.value.output.sylvia_witness.duplicate(true)
	witness["resolution_kind"] = "schedule_done"
	assert_false(CONTACT_STATE._validate_sylvia_witness_shape(witness).get("ok", true))

func test_condition_hospital_stage_presentation_and_retirement_use_real_root_ancestry() -> void:
	var lifecycle := preload("res://scripts/domain/run/RunLifecycle.gd").new()
	var causal := {"receipt_id": "issuer.causal.source", "purpose": "causal_day_instance",
		"namespace": "fixture", "counter": 1, "numeric_value": null, "token": "causal.source"}
	lifecycle.reset("run", "branch", 0, "causal.source", {"causal_day_instance_issuer_receipt": causal}, false)
	var hospital := preload("res://scripts/domain/run/ConditionHospitalState.gd").new()
	assert_true(hospital.configure(lifecycle, _issuer).get("ok", false))
	var root := _command("condition.stages")
	var accepted: Dictionary = hospital.prepare_accept({
		"action_receipt": {"receipt_id": "action.fixture", "transaction_id": root.id,
			"transaction_issuer_receipt": root.receipt},
		"condition_receipt": {"receipt_id": "condition.fixture"},
		"destination_record": {"key": "destination.fixture", "status": "pending",
			"payload": {"kind": "hospital_day", "accepted_unfulfilled_sources": []}}})
	assert_true(accepted.get("ok", false), str(accepted))
	if not accepted.get("ok", false): return
	assert_true(hospital.commit(accepted.value.condition_hospital_candidate).get("ok", false))
	var plan: Dictionary = lifecycle.to_dict().active_condition_hospital_plan
	var resolution_id := str(plan.resolution_receipt.receipt_id)
	var adapter := preload("res://scripts/application/run/GameStateConditionHospitalPort.gd").new()
	adapter._issuer = _issuer
	var presentation: Dictionary = adapter._presentation_request(plan, "present_hospital",
		{"kind": "hospital", "day": 1, "source_entry_ids": [], "miss_receipt_ids": []},
		"hospital.faint", preload("res://scripts/application/run/HospitalPresentationPort.gd").new())
	assert_true(presentation.get("ok", false), str(presentation))
	if not presentation.get("ok", false): return
	assert_true(_issuer.validate_child(presentation.value.request.completion_transaction_provenance,
		&"day_resolution_stage").get("ok", false))
	for index: int in range(plan.stages.size()):
		var stage_id := str(plan.stages[index].stage_id)
		var derived: Dictionary = hospital.prepare_stage_identity({"resolution_receipt_id": resolution_id,
			"stage_id": stage_id, "input_receipt_ids": []})
		assert_true(derived.get("ok", false), str(derived))
		if not derived.get("ok", false): return
		var identity: Dictionary = derived.value.stage_identity
		assert_true(_issuer.validate_child(identity.provenance, &"condition_hospital_stage").get("ok", false))
		assert_eq(identity.provenance.parent_receipt_id, root.receipt.receipt_id)
		assert_true(identity.provenance.source_ids.has(resolution_id))
		var prepared := {"kind": stage_id}
		var output := {}
		if stage_id == "advance_day":
			var target := causal.duplicate(true)
			target.receipt_id = "issuer.causal.target"
			target.token = "causal.target"
			target.counter = 2
			output = {"target_day": 2, "target_causal_day_instance": "causal.target",
				"target_causal_day_instance_issuer_receipt": target}
			prepared.merge(output, true)
		elif stage_id == "autosave_new_day":
			output = {"checkpoint_id": "run:42", "day": 2, "target_causal_day_instance": "causal.target"}
		var active: Dictionary = hospital.prepare_stage({"resolution_receipt_id": resolution_id,
			"stage_id": stage_id, "stage_identity": identity, "prepared": prepared})
		assert_true(active.get("ok", false), str(active))
		if not active.get("ok", false): return
		assert_true(hospital.commit_stage(active.value).get("ok", false))
		var receipt := {"input_receipt_ids": identity.input_receipt_ids.duplicate(true),
			"output": output, "receipt_id": identity.child_id, "receipt_provenance": identity.provenance,
			"resolution_kind": "condition_hospital", "resolution_receipt_id": resolution_id,
			"stage_id": stage_id, "stage_index": index}
		var completed: Dictionary = hospital.complete_stage({"resolution_receipt_id": resolution_id,
			"stage_id": stage_id, "stage_identity": identity, "prepared": prepared, "stage_receipt": receipt})
		assert_true(completed.get("ok", false), str(completed))
		if not completed.get("ok", false): return
		assert_true(hospital.commit_stage(completed.value).get("ok", false))
	plan = lifecycle.to_dict().active_condition_hospital_plan
	var retired: Dictionary = hospital.prepare_retirement({"completed_plan": plan,
		"autosave_stage_receipt": plan.stages[5].receipt})
	assert_true(retired.get("ok", false), str(retired))
	if not retired.get("ok", false): return
	var provenance: Dictionary = retired.value.retirement_receipt.receipt_provenance
	assert_true(_issuer.validate_child(provenance, &"condition_hospital_retirement").get("ok", false))
	assert_eq(provenance.parent_receipt_id, root.receipt.receipt_id)
	assert_true(provenance.source_ids.has(resolution_id))