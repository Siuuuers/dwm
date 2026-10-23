extends "res://addons/gut/test.gd"
# Day-7 Schedule provenance HANDOFF, driven through the production day-resolution walk
# (Plan 01 Task 8 Steps 8.3 / 8.4 / 8.7, dwm-p2r.14).
#
# WHAT THIS FILE OWNS. Task 7 checkpointed only what the committed aggregate already proved: a
# literal `cause` string read straight off the frozen entries. This file proves what Task 8 adds --
# that both Day-7 stages are driven through the ONE configured `Day7ScheduleProvenance` service and
# checkpoint the REAL derived `P01.schedule.day7_provenance` child, so a Day-7 resolution can no
# longer report a cause that no issuer ever anchored.
#
# SUBSTRATE. The same real-object substrate as tests/integration/test_committed_schedule_effect_
# order.gd: a GUID-isolated root, a real DesktopIssuerRootStore over real JsonFileStorage, the real
# DesktopIdentityNonceIssuer, the production ScheduleActionRegistry via load_current(), a real
# GameState in the tree, and the real GameStateScheduleCommitPort. No fake supplies a success: every
# aggregate below was minted by the production commit port and installed into the real owner, and
# every solo source receipt was minted through the real invitation ancestry.
#
# WHAT PLAN 01 STILL MAY NOT DO (Step 8.4). Day 7 ends AT the provenance checkpoint. No ending is
# selected, no ending plan is frozen, no dating board is started, and DatingEndingRules is never
# reached. Those assertions are as load-bearing here as the positive ones.

const COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const DAY7_PROVENANCE := preload("res://scripts/domain/schedule/Day7ScheduleProvenance.gd")

const CAUSAL_DAY := "causal_day_instance.7777777777777777777777777777777777777777777777777777777777777777"
const VIEW_FINGERPRINT := "schedule_view.77777777777777777777777777777777"
const DAY := 7
## Hard cap on every walk here; a stage that stops advancing is a defect, not a reason to spin.
const MAX_WALK_STEPS := 20

var _root := ""
var _root_counter := 0
var _storage: RefCounted
var _root_store: RefCounted
var _issuer: RefCounted
var _registry: RefCounted
var _fingerprint := ""
var _game_state: Node
var _commit_port: RefCounted
var _state_port: RefCounted
var _provenance: RefCounted
var _commands: Dictionary = {}


func before_each() -> void:
	_commands = {}
	_root = _isolated_root()
	if _root.is_empty():
		return
	_storage = JsonFileStorage.new(_root)
	_root_store = ROOT_STORE.new()
	assert_true(_root_store.configure(_storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(_root_store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(_root_store).get("ok", false))

	var loaded_registry: Dictionary = REGISTRY.load_current()
	assert_true(loaded_registry.get("ok", false), str(loaded_registry))
	_registry = (loaded_registry.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded_registry.get("value", {}) as Dictionary).get("registry_fingerprint", ""))

	_game_state = load(GAME_STATE_PATH).new()
	add_child_autofree(_game_state)
	_game_state.reset_game()

	var ledger: RefCounted = LEDGER.new()
	assert_true(ledger.configure(_storage).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	_commit_port = COMMIT_PORT.new(_game_state, _registry, _issuer, ledger)
	_state_port = STATE_PORT.new(_game_state)

	# Exactly the composition ApplicationBootstrap performs: ONE service, already configured with
	# the retained registry/issuer pair, injected INTO the retained state port.
	_provenance = DAY7_PROVENANCE.new()
	assert_true(_provenance.configure(_registry, _issuer).get("ok", false))
	assert_true(_state_port.configure_day7_provenance(_provenance).get("ok", false))


func _isolated_root() -> String:
	_root_counter += 1
	var result: Dictionary = TemporaryStorage.create("day7-provenance-%d" % _root_counter)
	assert_true(result.ok, result.get("message", ""))
	if not result.ok:
		return ""
	return result.value


# -------------------------------------------------------------------------------------------------
# Step 8.3: the two accepted causes, each carrying a REAL derived child
# -------------------------------------------------------------------------------------------------

func test_receipt_backed_empty_done_checkpoints_the_exact_empty_done_provenance() -> void:
	_commit_and_begin([])
	var stages := _walk_day7()

	assert_eq(_stage_value(stages, "validate_day7_provenance")["cause"], "empty_done")
	assert_null(_stage_value(stages, "validate_day7_provenance")["schedule_entry_id"],
		"an empty Done names no entry")
	assert_null(_stage_value(stages, "validate_day7_provenance")["source_receipt_id"],
		"an empty Done names no source receipt")

	var checkpoint: Dictionary = _stage_value(stages, "checkpoint_day7_provenance")
	assert_eq(checkpoint["cause"], "empty_done")
	# The whole point of Step 8.7: the checkpoint carries an ANCHORED id, not a literal.
	assert_false(str(checkpoint["day7_provenance_receipt_id"]).is_empty(),
		"the checkpoint carries the derived P01.schedule.day7_provenance id")
	var provenance: Dictionary = checkpoint["day7_provenance_receipt_provenance"]
	assert_eq(str(provenance["child_kind"]), "day7_schedule_provenance")
	assert_eq(int(provenance["ordinal"]), 0, "one handoff child for the commit root")
	assert_eq(str(provenance["child_id"]), str(checkpoint["day7_provenance_receipt_id"]))


func test_one_eligible_committed_solo_checkpoints_the_exact_scheduled_solo_provenance() -> void:
	var source_id := _seed_solo_source("sylvia", DAY, "solo:sylvia:day7")
	_commit_and_begin([_solo("s1", 0, "solo:sylvia:day7", ["sylvia"], source_id)])
	var stages := _walk_day7()

	var validated: Dictionary = _stage_value(stages, "validate_day7_provenance")
	assert_eq(validated["cause"], "scheduled_solo")
	assert_eq(str(validated["source_receipt_id"]), source_id,
		"the cause names the EXACT minted source receipt")
	assert_false(str(validated["schedule_entry_id"]).is_empty())

	var checkpoint: Dictionary = _stage_value(stages, "checkpoint_day7_provenance")
	assert_eq(checkpoint["cause"], "scheduled_solo")
	assert_eq(str(checkpoint["schedule_commit_receipt_id"]),
		str(_committed()["commit_receipt"]["receipt_id"]),
		"the checkpoint binds the aggregate's own commit receipt")
	assert_eq(str(checkpoint["day7_provenance_receipt_provenance"]["child_id"]),
		str(checkpoint["day7_provenance_receipt_id"]))


func test_the_checkpointed_child_revalidates_through_the_issuer_that_derived_it() -> void:
	# A child id that does not follow from its own provenance members is exactly the failure the
	# issuer's validate_child() exists to catch, so the checkpoint is proved against it.
	_seed_solo_source("priscilla", DAY, "solo:priscilla:day7")
	_commit_and_begin([_solo("s1", 0, "solo:priscilla:day7", ["priscilla"],
		_source_id("priscilla", DAY))])
	var checkpoint: Dictionary = _stage_value(_walk_day7(), "checkpoint_day7_provenance")

	var revalidated: Dictionary = _issuer.validate_child(
		checkpoint["day7_provenance_receipt_provenance"], &"day7_schedule_provenance")
	assert_true(revalidated.get("ok", false),
		"the checkpointed child revalidates: " + str(revalidated))


func test_the_two_causes_derive_distinct_children_from_distinct_source_projections() -> void:
	_commit_and_begin([])
	var empty_id := str(_stage_value(_walk_day7(), "checkpoint_day7_provenance")["day7_provenance_receipt_id"])

	before_each()
	var source_id := _seed_solo_source("lavinia", DAY, "solo:lavinia:day7")
	_commit_and_begin([_solo("s1", 0, "solo:lavinia:day7", ["lavinia"], source_id)])
	var solo_id := str(_stage_value(_walk_day7(), "checkpoint_day7_provenance")["day7_provenance_receipt_id"])

	assert_ne(empty_id, solo_id,
		"a different cause projects different source tokens and so a different child")


# -------------------------------------------------------------------------------------------------
# Step 8.3: refusals. Every one of these must fail BEFORE the stage mutates.
# -------------------------------------------------------------------------------------------------

func test_an_unconfigured_service_fails_closed_before_the_day7_stage_mutates() -> void:
	# The production graph always holds the one configured service; an ISOLATED port must refuse
	# rather than invent a cause of its own.
	var isolated: RefCounted = STATE_PORT.new(_game_state)
	_commit_and_begin([])
	_replace_state_port(isolated)

	var result := _walk_until_day7_stage()
	assert_false(result.get("ok", true), "an unconfigured Day-7 handoff cannot proceed")
	assert_eq(result.get("code"), &"day7_provenance_unconfigured", str(result))
	assert_eq(_stage_state("validate_day7_provenance"), "pending",
		"the refused stage never became active")


func test_a_group_destination_is_not_an_accepted_day7_cause() -> void:
	# Only an empty Done or ONE solo may end the run. A committed date whose registry-owned kind is
	# `group` is refused outright rather than silently downgraded to empty_done.
	var source_id := _seed_solo_source("sylvia", DAY, "solo:sylvia:day7")
	_commit_and_begin([_solo("s1", 0, "solo:sylvia:day7", ["sylvia"], source_id)])

	var request := _handoff_request()
	(((request["committed_schedule"] as Dictionary)["entries"] as Array)[0]
		as Dictionary)["action_kind"] = "group"
	var result: Dictionary = _provenance.validate_handoff(request)
	assert_false(result.get("ok", true), "a group destination is not a Day-7 cause: " + str(result))


func test_more_than_one_committed_entry_is_not_an_accepted_day7_cause() -> void:
	# Day 7 carries at most one committed entry. Two is a corrupt Done, not a "first one wins".
	var sylvia := _seed_solo_source("sylvia", DAY, "solo:sylvia:day7")
	var lavinia := _seed_solo_source("lavinia", DAY, "solo:lavinia:day7")
	_commit_and_begin([_solo("s1", 0, "solo:sylvia:day7", ["sylvia"], sylvia)])

	var request := _handoff_request()
	var entries: Array = (request["committed_schedule"] as Dictionary)["entries"]
	var second: Dictionary = (entries[0] as Dictionary).duplicate(true)
	second["slot_index"] = 1
	second["source_receipt_id"] = lavinia
	entries.append(second)
	var result: Dictionary = _provenance.validate_handoff(request)
	assert_false(result.get("ok", true), "two Day-7 entries are refused: " + str(result))


func test_a_source_receipt_missing_from_the_contacts_index_is_refused() -> void:
	var source_id := _seed_solo_source("sylvia", DAY, "solo:sylvia:day7")
	_commit_and_begin([_solo("s1", 0, "solo:sylvia:day7", ["sylvia"], source_id)])

	# The committed entry keeps its id; the INDEX loses the record it resolved through. Nothing may
	# re-bless the cause from the entry alone.
	var contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	(contacts["schedule_source_receipts"] as Dictionary).erase(source_id)
	_game_state.contacts = contacts

	var result := _walk_until_day7_stage()
	assert_false(result.get("ok", true), "an unresolved source receipt is refused: " + str(result))
	assert_eq(result.get("code"), &"day7_source_receipt_unresolved", str(result))


func test_a_registry_that_moved_on_since_the_commit_is_refused() -> void:
	# The saved fingerprint is the truth. A service configured against a DIFFERENT registry cannot
	# re-bless an aggregate committed under the old one.
	_commit_and_begin([])
	var foreign: RefCounted = DAY7_PROVENANCE.new()
	assert_true(foreign.configure(_ForeignRegistry.new(), _issuer).get("ok", false))
	var isolated: RefCounted = STATE_PORT.new(_game_state)
	assert_true(isolated.configure_day7_provenance(foreign).get("ok", false))
	_replace_state_port(isolated)

	var result := _walk_until_day7_stage()
	assert_false(result.get("ok", true), "a moved registry is refused: " + str(result))
	assert_eq(result.get("code"), &"day7_registry_fingerprint_mismatch", str(result))


func test_no_day8_aggregate_can_reach_the_handoff() -> void:
	# Day 8 is structurally impossible: the schema refuses the aggregate outright, so no Day-8
	# provenance can exist to be checkpointed.
	var handoff: Dictionary = _provenance.validate_handoff({
		"transaction_id": "t",
		"transaction_issuer_receipt": {},
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": {"schema_version": 1, "day": 8, "entries": [],
			"registry_fingerprint": _fingerprint, "commit_receipt": null},
		"source_receipt_index": {},
	})
	assert_false(handoff.get("ok", true), "no Day-8 aggregate is accepted: " + str(handoff))


func test_a_receiptless_aggregate_is_not_an_accepted_cause() -> void:
	# Planned/draft-only state carries no commit receipt. It is not an empty DONE.
	var handoff: Dictionary = _provenance.validate_handoff({
		"transaction_id": "t",
		"transaction_issuer_receipt": {},
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": {"schema_version": 1, "day": DAY, "entries": [],
			"registry_fingerprint": _fingerprint, "commit_receipt": null},
		"source_receipt_index": {},
	})
	assert_false(handoff.get("ok", true), "a receiptless aggregate is refused: " + str(handoff))


func test_caller_authored_ending_or_relationship_fields_are_refused_as_extra_inputs() -> void:
	# Step 8.4: the handoff request member set is EXACT. A Dark-mode flag, a Sylvia read receipt, a
	# hospital-skip counter, or an ending id cannot ride along as a "hint".
	_commit_and_begin([])
	var base := _handoff_request()
	for extra: String in ["ending_id", "dark_mode", "sylvia_read_receipt_id",
			"hospital_skipped_sylvia_solo_count", "relationship_tier", "board_receipt_id",
			"date_completed"]:
		var polluted: Dictionary = base.duplicate(true)
		polluted[extra] = "x"
		var result: Dictionary = _provenance.validate_handoff(polluted)
		assert_false(result.get("ok", true), extra + " is not an accepted input: " + str(result))


func test_a_rewritten_cause_projection_cannot_reach_the_same_child() -> void:
	# Every cause-specific nullable projection feeds the child derivation. Swapping the committed
	# entry's source receipt for another VALID indexed one must move the derived id.
	var sylvia := _seed_solo_source("sylvia", DAY, "solo:sylvia:day7")
	_commit_and_begin([_solo("s1", 0, "solo:sylvia:day7", ["sylvia"], sylvia)])
	var honest: Dictionary = _provenance.validate_handoff(_handoff_request())
	assert_true(honest.get("ok", false), str(honest))

	var lavinia := _seed_solo_source("lavinia", DAY, "solo:lavinia:day7")
	var forged := _handoff_request()
	var committed: Dictionary = forged["committed_schedule"]
	((committed["entries"] as Array)[0] as Dictionary)["source_receipt_id"] = lavinia
	var drifted: Dictionary = _provenance.validate_handoff(forged)
	if drifted.get("ok", false):
		assert_ne(str(drifted["receipt"]["receipt_id"]), str(honest["receipt"]["receipt_id"]),
			"a different source projection cannot reuse the honest child id")
	else:
		assert_false(drifted.get("ok", true), "a rewritten entry is refused outright")


# -------------------------------------------------------------------------------------------------
# Step 8.4: what Day 7 must NOT do
# -------------------------------------------------------------------------------------------------

func test_day7_stops_after_the_provenance_checkpoint_with_no_ending_and_no_board() -> void:
	_commit_and_begin([])
	var stages := _walk_day7()

	assert_eq(stages.size(), 5, "Day 7 runs exactly its five frozen stages")
	assert_eq(str(stages[stages.size() - 1]["stage_id"]), "checkpoint_day7_provenance",
		"the run ends AT the handoff checkpoint")
	for stage: Dictionary in stages:
		assert_false(str(stage["stage_id"]) in
			["resolve_ending_plan", "enter_ending", "ending_autosave", "increment_day",
				"execute_schedule_dates", "reset_day_scope"],
			"Day 7 never reaches " + str(stage["stage_id"]))

	assert_eq(str(_game_state._run_lifecycle.to_dict()["state"]), "PLAYING",
		"Plan 01 leaves the run PLAYING; dwm-oyo.6 owns entering ENDING")
	assert_eq(int(_game_state._run_lifecycle.get_day()), DAY, "no Day 8 is ever allocated")
	assert_eq(_game_state.route_context.get("ending_id", ""), "",
		"Plan-01 Day-7 provenance never selects an ending id")


func test_no_day7_stage_carries_an_ending_plan_or_a_board_receipt() -> void:
	_seed_solo_source("sylvia", DAY, "solo:sylvia:day7")
	_commit_and_begin([_solo("s1", 0, "solo:sylvia:day7", ["sylvia"], _source_id("sylvia", DAY))])
	for stage: Dictionary in _walk_day7():
		var text := JSON.stringify(stage)
		assert_false(text.contains("ending_plan"), "no Day-7 stage freezes an ending plan")
		assert_false(text.contains("playback_stage"), "no Day-7 stage carries playback state")
		assert_false(text.contains("board_"), "no Day-7 stage carries a board receipt")


# -------------------------------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------------------------------

## A registry whose fingerprint deliberately differs, so the saved-fingerprint law has something
## honest to refuse. It answers the exact two-method contract Day7ScheduleProvenance requires.
class _ForeignRegistry extends RefCounted:
	func fingerprint() -> String:
		return "schedule_registry.deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"

	func find_record(_action_id: String) -> Dictionary:
		return {"ok": false, "code": &"unknown_action", "message": "", "details": {}}


func _committed() -> Dictionary:
	var plan: Variant = _game_state._run_lifecycle.to_dict().get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return {}
	return ((plan as Dictionary).get("committed_schedule", {}) as Dictionary).duplicate(true)


## The exact request the state port builds, reconstructed here so the refusal tests can mutate one
## member at a time without reaching into the port's privates.
func _handoff_request() -> Dictionary:
	var committed := _committed()
	var commit_receipt: Dictionary = committed["commit_receipt"]
	var contacts: Dictionary = _game_state.contacts
	return {
		"transaction_id": str(commit_receipt["transaction_id"]),
		"transaction_issuer_receipt": (commit_receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": str(commit_receipt["causal_day_instance"]),
		"committed_schedule": committed,
		"source_receipt_index": (contacts["schedule_source_receipts"] as Dictionary).duplicate(true),
	}


func _stage_value(stages: Array, stage_id: String) -> Dictionary:
	for stage: Dictionary in stages:
		if str(stage["stage_id"]) == stage_id:
			return ((stage["receipt"] as Dictionary)["value"] as Dictionary)
	assert_true(false, "the walk never completed " + stage_id)
	return {}


func _stage_state(stage_id: String) -> String:
	var plan: Variant = _game_state._run_lifecycle.to_dict().get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return ""
	for stage: Variant in ((plan as Dictionary)["stages"] as Array):
		if str((stage as Dictionary)["stage_id"]) == stage_id:
			return str((stage as Dictionary)["state"])
	return ""


## Swaps the driving port AFTER the resolution has begun, so the isolated-negative cases exercise a
## real in-flight plan rather than a plan that never started.
func _replace_state_port(port: RefCounted) -> void:
	_state_port = port


## Drives the whole Day-7 plan and returns each completed stage record in order.
func _walk_day7() -> Array:
	var completed: Array = []
	var steps := 0
	var cursor: Dictionary = _state_port.inspect_next_stage()
	while cursor.get("ok", false) and cursor["value"]["has_stage"]:
		steps += 1
		if steps > MAX_WALK_STEPS:
			assert_true(false, "the Day-7 walk stopped advancing")
			break
		var begun: Dictionary = _state_port.begin_next_stage()
		assert_true(begun.get("ok", false), JSON.stringify(begun))
		if not begun.get("ok", false):
			break
		var stage: Dictionary = (begun["value"] as Dictionary)["stage"]
		var receipt: Dictionary = (begun["value"] as Dictionary)["receipt"]
		var done: Dictionary = _game_state._run_lifecycle.complete_active_stage(
			str(stage["transaction_id"]), {"value": (receipt["value"] as Dictionary).duplicate(true)})
		assert_true(done.get("ok", false), JSON.stringify(done))
		if not done.get("ok", false):
			break
		completed.append({"stage_id": str(stage["stage_id"]), "receipt": receipt})
		cursor = _state_port.inspect_next_stage()
	return completed


## Drives until a Day-7 provenance stage refuses, and returns that refusal.
func _walk_until_day7_stage() -> Dictionary:
	var steps := 0
	var cursor: Dictionary = _state_port.inspect_next_stage()
	while cursor.get("ok", false) and cursor["value"]["has_stage"]:
		steps += 1
		if steps > MAX_WALK_STEPS:
			return {"ok": false, "code": &"walk_stalled"}
		var begun: Dictionary = _state_port.begin_next_stage()
		if not begun.get("ok", false):
			return begun
		var stage: Dictionary = (begun["value"] as Dictionary)["stage"]
		var receipt: Dictionary = (begun["value"] as Dictionary)["receipt"]
		var done: Dictionary = _game_state._run_lifecycle.complete_active_stage(
			str(stage["transaction_id"]), {"value": (receipt["value"] as Dictionary).duplicate(true)})
		if not done.get("ok", false):
			return done
		cursor = _state_port.inspect_next_stage()
	return {"ok": true, "code": &"plan_complete"}


func _commit_and_begin(drafts: Array) -> void:
	_game_state._lifecycle_set_playing_day(DAY)
	var command: Dictionary = _command("commit.day%d" % DAY)
	var prepared: Dictionary = _commit_port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": DAY,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": _fingerprint,
	})
	assert_true(prepared.get("ok", false),
		"the production commit port mints a real aggregate: " + str(prepared))
	if not prepared.get("ok", false):
		return
	var value: Dictionary = (prepared.get("value", {}) as Dictionary).duplicate(true)
	assert_true(_commit_port.call(&"commit", value["game_state_candidate"]).get("ok", false))
	var begun: Dictionary = _state_port.begin_or_resume(str(command["id"]) + ":resolution")
	assert_true(begun.get("ok", false),
		"the resolution begins from the committed aggregate: " + str(begun))


var _source_ids: Dictionary = {}


func _source_id(friend_id: String, day: int) -> String:
	return str(_source_ids.get("%s.day%d" % [friend_id, day], ""))


func _seed_solo_source(friend_id: String, day: int, action_id: String) -> String:
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
		_game_state.contacts, friend_id, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	if not offered.get("ok", false):
		return ""
	var command: Dictionary = _command("open.%s.day%d" % [friend_id, day])
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	if not found.get("ok", false):
		return ""
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		offered["value"]["candidate"], friend_id, day, command["id"], command["receipt"],
		_issuer, ((found["value"] as Dictionary)["record"] as Dictionary))
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return ""
	_game_state.contacts = opened["value"]["candidate"]
	var receipt_id := str(opened["receipt"]["receipt_id"])
	_source_ids["%s.day%d" % [friend_id, day]] = receipt_id
	return receipt_id


func _solo(draft_entry_id: String, slot_index: int, action_id: String, participants: Array,
		source_receipt_id: String) -> Dictionary:
	return {
		"draft_entry_id": draft_entry_id,
		"day": DAY,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": "solo",
		"participants": participants.duplicate(),
		"source_receipt_id": source_receipt_id,
	}


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)
