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
