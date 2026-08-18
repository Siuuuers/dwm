extends "res://addons/gut/test.gd"
# Committed ordinary effects, applied EXACTLY ONCE in causal order
# (Plan 01 Task 7 Step 7.2, dwm-p2r.14).
#
# SUBSTRATE. The same real-object substrate as test_committed_schedule_day_resolution.gd: a
# GUID-isolated root, a real DesktopIssuerRootStore over real JsonFileStorage, the real
# DesktopIdentityNonceIssuer, the production ScheduleActionRegistry through load_current(), a real
# GameState, and the real GameStateScheduleCommitPort. No fake supplies a success here: every
# aggregate below was minted by the production commit port and installed into the real owner.
#
# WHAT THIS FILE OWNS. Task 6 proved the committed entries REACH the plan. This file proves what
# Task 7 adds: that each ordinary entry's REGISTERED effects are committed exactly once through the
# existing effect-transaction owner, keyed by that entry's own substage transaction, and that
# repeats apply repeatedly through distinct ids rather than collapsing into one.

const COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")

const CAUSAL_DAY := "causal_day_instance.3333333333333333333333333333333333333333333333333333333333333333"
const VIEW_FINGERPRINT := "schedule_view.44444444444444444444444444444444"

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
var _commands: Dictionary = {}


func before_each() -> void:
	_commands = {}
	_root = _isolated_root()
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

	# ADDED TO THE TREE, unlike the Task-6 suites: committing an effect transaction resolves
	# /root/EffectResolver by node path, so a detached GameState could never apply a real effect.
	_game_state = load(GAME_STATE_PATH).new()
	add_child_autofree(_game_state)
	_game_state.reset_game()

	var ledger: RefCounted = LEDGER.new()
	assert_true(ledger.configure(_storage).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	_commit_port = COMMIT_PORT.new(_game_state, _registry, _issuer, ledger)
	_state_port = STATE_PORT.new(_game_state)


func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root: String = wrapper.path_join("committed-effect-order-%d" % _root_counter)
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	return root


# ---- Step 7.2: registered effects, exactly once, per committed ordinary entry ----

func test_each_committed_ordinary_entry_applies_its_registered_effects_exactly_once() -> void:
	# `working` is pressure:+2, health:-2, money:+30 in the v1 registry. Committing one of them
	# must move the owner by exactly that much -- no more, and never twice.
	var before_money: int = _game_state.money
	var before_pressure: int = _game_state.get_stat("pressure")
	var before_health: int = _game_state.get_stat("health")

	_commit_and_begin(3, [_ordinary("d1", 0, "working", 3)])
	_drive_through_ordinary_substages()

	assert_eq(_game_state.money, before_money + 30, "money moved by exactly the registered amount")
	assert_eq(_game_state.get_stat("pressure"), before_pressure + 2, "pressure applied once")
	assert_eq(_game_state.get_stat("health"), before_health - 2, "health applied once")


func test_repeated_ordinary_entries_apply_once_each_through_distinct_substage_ids() -> void:
	# `rest` is repeatable (pressure:-2, health:+1). Two committed rests are TWO applications
	# through two distinct schedule_entry ids and two distinct zero-based substage ordinals --
	# they must not collapse into a single effect transaction.
	var before_health: int = _game_state.get_stat("health")
	var before_pressure: int = _game_state.get_stat("pressure")

	_commit_and_begin(3, [_ordinary("r1", 0, "rest", 3), _ordinary("r2", 1, "rest", 3)])
	var substage_ids := _drive_through_ordinary_substages()

	assert_eq(substage_ids.size(), 2, "two committed rests produce two distinct substages")
	assert_ne(substage_ids[0], substage_ids[1], "each repeat carries its own substage identity")
	# health is the unambiguous "applied twice" signal here: +1 per rest, well inside its domain.
	assert_eq(_game_state.get_stat("health"), before_health + 2, "rest applied TWICE, not once")
	# pressure is -2 per rest but CLAMPS at its owner-defined floor, so two rests from a low
	# starting pressure land on the floor rather than going negative. Asserting the clamped value
	# keeps this a test of "applied twice" rather than an accidental test of the clamp.
	assert_eq(_game_state.get_stat("pressure"),
		maxi(_game_state.get_stat_min("pressure"), before_pressure - 4),
		"pressure fell twice, clamped to its floor")


func test_ordinary_effects_commit_before_the_hospital_and_date_stages() -> void:
	# req.flow.hospital_order at the level that matters for effects: by the time the walk reaches
	# hospital_if_triggered, every committed ordinary effect is already durable.
	var before_money: int = _game_state.money
	_commit_and_begin(3, [_ordinary("w1", 0, "working", 3)])
	var visited: Array[String] = []
	var steps := 0
	var cursor: Dictionary = _state_port.inspect_next_stage()
	while cursor.get("ok", false) and cursor["value"]["has_stage"]:
		steps += 1
		if steps > MAX_WALK_STEPS:
			assert_true(false, "the walk never reached hospital_if_triggered")
			break
		var stage_id := str(cursor["value"]["stage"]["stage_id"])
		if stage_id == "hospital_if_triggered":
			break
		visited.append(stage_id)
		if not _complete_current():
			break
		cursor = _state_port.inspect_next_stage()

	assert_true("execute_schedule_actions" in visited,
		"the ordinary stage ran before Hospital was reached")
	assert_false("execute_schedule_dates" in visited,
		"no date stage ran before Hospital")
	assert_eq(_game_state.money, before_money + 30,
		"the ordinary effect is already durable when Hospital is reached")


func test_a_faint_supersedes_every_committed_date_before_any_board_runs() -> void:
	# req.flow.hospital_order END TO END, over the real committed aggregate: ordinary effects, then
	# condition truth, then Hospital, then the dates Hospital did not supersede.
	_commit_and_begin(3, [
		_ordinary("w1", 0, "working", 3),
		_date("d-lav", 2, "lavinia", 3),
	])
	# The faint the earlier stages would have resolved. Set directly so this suite tests ORDERING
	# rather than re-testing the condition ladder, which test_conditions owns.
	_game_state.pending_hospital = true

	var hospital: Dictionary = _receipt_for_stage("hospital_if_triggered")
	assert_false(hospital.is_empty(), "the walk reached hospital_if_triggered")
	if hospital.is_empty():
		return
	assert_true(bool(hospital["required"]), "a pending faint requires Hospital")
	assert_eq(hospital["date_schedule_entry_ids"], hospital["superseded_entry_ids"],
		"EVERY committed date is superseded when Hospital triggers")
	assert_eq((hospital["superseded_entry_ids"] as Array).size(), 1,
		"the one committed date was superseded exactly once")


func test_without_a_faint_the_committed_dates_survive() -> void:
	_commit_and_begin(3, [_date("d-lav", 2, "lavinia", 3)])
	assert_false(_game_state.pending_hospital, "no faint was resolved")

	var hospital: Dictionary = _receipt_for_stage("hospital_if_triggered")
	assert_false(hospital.is_empty(), "the walk reached hospital_if_triggered")
	if hospital.is_empty():
		return
	assert_false(bool(hospital["required"]), "no faint, no Hospital")
	assert_eq(hospital["superseded_entry_ids"], [],
		"an untriggered Hospital supersedes NOTHING; the committed date survives")
	assert_eq((hospital["date_schedule_entry_ids"] as Array).size(), 1,
		"the surviving date is still reported so the date stage can run it")


func test_a_superseded_sylvia_date_commits_its_witness_into_the_contacts_index() -> void:
	# The Hospital transaction commits the byte-identical witness into the append-only Contacts
	# handoff index. The index outlives the resolution plan so dwm-oyo.4 can consume it.
	_commit_and_begin(3, [_date("d-syl", 0, "sylvia", 3)])
	_game_state.pending_hospital = true

	var before: Dictionary = (_game_state.contacts as Dictionary)["sylvia_hospital_witness_receipts"]
	assert_eq(before.size(), 0, "the index starts empty")

	var hospital: Dictionary = _receipt_for_stage("hospital_if_triggered")
	assert_false(hospital.is_empty(), "the walk reached hospital_if_triggered")
	if hospital.is_empty():
		return
	assert_eq(str(hospital["witness_entry_id"]), _entry_id_for("d-syl"),
		"the superseded Sylvia date is the witness")
	# Complete the stage so the transaction actually commits.
	assert_true(_complete_active_with(hospital), "the Hospital stage commits")

	var index: Dictionary = (_game_state.contacts as Dictionary)["sylvia_hospital_witness_receipts"]
	assert_eq(index.size(), 1, "exactly one witness was committed")
	if index.is_empty():
		return
	var record: Dictionary = index.values()[0]
	assert_eq(str(record["kind"]), "sylvia_hospital_witness")
	assert_eq(str(record["resolution_kind"]), "schedule_done")
	assert_eq(int(record["care_followup_day"]), 4, "care lands the day after the faint")
	assert_eq(int(record["affection_delta"]), 2, "the frozen fact is RECORDED, not applied")
	# Plan 01 applies nothing: Sylvia's affection is untouched by the witness.
	assert_eq(int((_game_state.affection as Dictionary).get("sylvia", 0)), 0,
		"Plan 01 records the witness and applies no relationship change")


func test_a_faint_without_a_sylvia_date_writes_no_witness() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	_game_state.pending_hospital = true
	var hospital: Dictionary = _receipt_for_stage("hospital_if_triggered")
	if hospital.is_empty():
		return
	assert_eq(hospital["witness_entry_id"], null, "another friend cannot witness")
	assert_true(_complete_active_with(hospital), "the Hospital stage commits")
	assert_eq((_game_state.contacts as Dictionary)["sylvia_hospital_witness_receipts"].size(), 0,
		"no witness is written without a superseded Sylvia date")


func test_rolling_back_the_hospital_stage_restores_the_contacts_index() -> void:
	_commit_and_begin(3, [_date("d-syl", 0, "sylvia", 3)])
	_game_state.pending_hospital = true
	var hospital: Dictionary = _receipt_for_stage("hospital_if_triggered")
	if hospital.is_empty():
		return
	# capture() must back up BOTH owners, or a rolled-back Hospital would leave a witness behind
	# for a supersession that never committed.
	var captured: Dictionary = _state_port.capture()
	assert_true(captured.get("ok", false), JSON.stringify(captured))
	assert_true(_complete_active_with(hospital), "the Hospital stage commits")
	assert_eq((_game_state.contacts as Dictionary)["sylvia_hospital_witness_receipts"].size(), 1)

	assert_true(_state_port.rollback((captured["value"] as Dictionary)["backup"]).get("ok", false))
	assert_eq((_game_state.contacts as Dictionary)["sylvia_hospital_witness_receipts"].size(), 0,
		"rollback restores the Contacts index, not just the plan stage")


# ---- helpers ----

## Completes the CURRENT active record with an envelope carrying `value`.
func _complete_active_with(value: Dictionary) -> bool:
	var plan: Variant = _game_state._run_lifecycle.to_dict()["active_resolution_plan"]
	if typeof(plan) != TYPE_DICTIONARY:
		return false
	for stage: Dictionary in ((plan as Dictionary)["stages"] as Array):
		if str(stage["state"]) != "active":
			continue
		var prepared: Dictionary = _state_port.prepare_completion(
			str(stage["transaction_id"]), {"owner_id": "hospital_rules",
				"kind": "hospital_resolution", "value": value.duplicate(true)})
		if not prepared.get("ok", false):
			assert_true(false, JSON.stringify(prepared))
			return false
		var committed: Dictionary = _state_port.commit(
			(prepared["value"] as Dictionary)["run_candidate"])
		assert_true(committed.get("ok", false), JSON.stringify(committed))
		return committed.get("ok", false)
	return false


## The committed schedule_entry_id minted for a given draft id.
func _entry_id_for(draft_entry_id: String) -> String:
	for entry: Variant in (_game_state._canonical_committed_schedule()["entries"] as Array):
		if str((entry as Dictionary).get("draft_entry_id", "")) == draft_entry_id:
			return str((entry as Dictionary)["schedule_entry_id"])
	for entry: Variant in (_game_state._canonical_committed_schedule()["entries"] as Array):
		return str((entry as Dictionary)["schedule_entry_id"])
	return ""



## Drives the walk until `stage_id` is the current record and returns that stage's receipt value.
func _receipt_for_stage(stage_id: String) -> Dictionary:
	var steps := 0
	var cursor: Dictionary = _state_port.inspect_next_stage()
	while cursor.get("ok", false) and cursor["value"]["has_stage"]:
		steps += 1
		if steps > MAX_WALK_STEPS:
			assert_true(false, "the walk never reached " + stage_id)
			return {}
		if str(cursor["value"]["stage"]["stage_id"]) == stage_id \
				and not cursor["value"]["stage"].has("substage_id"):
			var begun: Dictionary = _state_port.begin_next_stage()
			assert_true(begun.get("ok", false), JSON.stringify(begun))
			if not begun.get("ok", false):
				return {}
			return ((begun["value"] as Dictionary)["receipt"] as Dictionary)["value"]
		if not _complete_current():
			return {}
		cursor = _state_port.inspect_next_stage()
	return {}


## A committed solo date backed by a REAL invitation source receipt.
##
## The production commit port resolves every date's source ancestry against the Contacts index, so
## a fabricated id is refused outright (unresolved_source_receipt). The offer is therefore genuinely
## offered and opened first, exactly as Task 3 requires.
func _date(draft_entry_id: String, slot_index: int, friend: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend, day]
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": "solo",
		"participants": [friend],
		"source_receipt_id": _seed_solo_source(friend, day, action_id),
	}


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
	return str(opened["receipt"]["receipt_id"])

func _commit_and_begin(day: int, drafts: Array) -> void:
	_game_state._lifecycle_set_playing_day(day)
	var command: Dictionary = _command("commit.day%d" % day)
	var prepared: Dictionary = _commit_port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
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


## Hard cap on every walk in this suite. A stage that stops advancing is a real defect, and without
## a cap the driver would spin forever instead of reporting it.
const MAX_WALK_STEPS := 40


## Drives the walk up to (not into) commit_outcomes, returning the ordinary substage ids it passed.
func _drive_through_ordinary_substages() -> Array[String]:
	var seen: Array[String] = []
	var steps := 0
	var cursor: Dictionary = _state_port.inspect_next_stage()
	while cursor.get("ok", false) and cursor["value"]["has_stage"]:
		steps += 1
		if steps > MAX_WALK_STEPS:
			assert_true(false, "the walk stopped advancing before commit_outcomes")
			break
		var record: Dictionary = cursor["value"]["stage"]
		if str(record["stage_id"]) == "commit_outcomes":
			break
		var substage_id := str(record.get("substage_id", ""))
		if substage_id.begins_with("ordinary_action"):
			seen.append(substage_id)
		if not _complete_current():
			break
		cursor = _state_port.inspect_next_stage()
	return seen


## Drives one record through the SAME seam test_committed_schedule_day_resolution._advance_stage
## uses: the port produces the owner receipt, and the lifecycle completes the active record.
## Returns false when the record failed to complete, so every caller stops rather than spinning.
func _complete_current() -> bool:
	var begun: Dictionary = _state_port.begin_next_stage()
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	if not begun.get("ok", false):
		return false
	var stage: Dictionary = (begun["value"] as Dictionary)["stage"]
	var receipt: Dictionary = (begun["value"] as Dictionary)["receipt"]
	var completed: Dictionary = _game_state._run_lifecycle.complete_active_stage(
		str(stage["transaction_id"]), {"value": (receipt["value"] as Dictionary).duplicate(true)})
	assert_true(completed.get("ok", false), JSON.stringify(completed))
	return completed.get("ok", false)


func _ordinary(draft_entry_id: String, slot_index: int, action_id: String, day: int) -> Dictionary:
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": "ordinary",
		"participants": [],
		"source_receipt_id": null,
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
