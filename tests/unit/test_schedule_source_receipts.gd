extends "res://addons/gut/test.gd"

const CONTACT_STATE_PATH := "res://scripts/domain/contact/ContactInvitationState.gd"
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

var _identity_issuer: RefCounted
var _registry: RefCounted
var _commands: Dictionary


func before_each() -> void:
	var root := FAKE_ROOT.new("22".repeat(32), 7)
	_identity_issuer = ISSUER.new()
	assert_true(_identity_issuer.configure(root).get("ok", false))
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = loaded.get("value", {}).get("registry")
	_commands = {}


func _state_script() -> Script:
	return load(CONTACT_STATE_PATH)


func _offered_solo(script: Script, friend_id: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend_id, day]
	var offered: Dictionary = script.prepare_offer_solo(
		script.make_defaults(), friend_id, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	return offered.get("value", {}).get("candidate", {})


func _activated_group(script: Script, day: int) -> Dictionary:
	var state: Dictionary = script.make_defaults()
	state = script.prepare_offer_solo(
		state, "priscilla", day, "solo:priscilla:day%d" % day,
		"offer.solo:priscilla:day%d" % day)["value"]["candidate"]
	state = script.prepare_offer_solo(
		state, "lavinia", day, "solo:lavinia:day%d" % day,
		"offer.solo:lavinia:day%d" % day)["value"]["candidate"]
	return script.prepare_activate_group_after_round(
		state, day, 2, 3, "offer.group:priscilla_lavinia:day%d" % day)["value"]["candidate"]


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _identity_issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str(issued.get("value", {}).get("token", "")),
			"receipt": issued.get("value", {}).get("issuer_receipt", {}).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


func _record(action_id: String) -> Dictionary:
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	return found.get("value", {}).get("record", {})


func _open(script: Script, state: Dictionary, friend_id: String, day: int,
		label: String) -> Dictionary:
	var command := _command(label)
	var action_id := "group:priscilla_lavinia:day%d" % day \
		if str(state.get("group_action", {}).get("state", "")) in script.GROUP_OPEN_STATES \
		else "solo:%s:day%d" % [friend_id, day]
	return script.prepare_open_contact(state, friend_id, day, command["id"],
		command["receipt"], _identity_issuer, _record(action_id))


func _reply(script: Script, state: Dictionary, friend_id: String, day: int,
		label: String) -> Dictionary:
	var command := _command(label)
	return script.prepare_reply(state, friend_id, day, command["id"],
		command["receipt"], _identity_issuer,
		_record("group:priscilla_lavinia:day%d" % day))


func test_contacts_defaults_reserve_two_exact_source_indexes() -> void:
	var state: Dictionary = _state_script().make_defaults()
	assert_true(state.has("schedule_source_receipts"),
		"RED: Contacts must own a separate Schedule-source receipt index")
	assert_true(state.has("sylvia_hospital_witness_receipts"),
		"RED: Contacts must reserve the strict Sylvia witness handoff index")
	assert_eq(state.get("schedule_source_receipts"), {})
	assert_eq(state.get("sylvia_hospital_witness_receipts"), {})


func test_opening_solo_is_the_acceptance_and_creates_a_distinct_source() -> void:
	var script := _state_script()
	var state := _offered_solo(script, "priscilla", 1)
	var opened: Dictionary = _open(script, state, "priscilla", 1, "command.open.priscilla.day1")
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return
	var candidate: Dictionary = opened["value"]["candidate"]
	assert_eq(candidate["solo_actions"]["solo:priscilla:day1"]["state"], "ACCEPTED",
		"RED: opening a solo offer performs the scripted acceptance")
	assert_eq(candidate.get("schedule_source_receipts", {}).size(), 1,
		"RED: acceptance persists one separate source receipt")
	assert_ne(str(opened.get("receipt", {}).get("receipt_id", "")),
		str(_command("command.open.priscilla.day1")["id"]),
		"the source child must not masquerade as its command root")


func test_solo_has_no_separate_reply_transition() -> void:
	var script := _state_script()
	var state := _offered_solo(script, "sylvia", 3)
	var command := _command("command.reply.sylvia.day3")
	var replied: Dictionary = script.prepare_reply(
		state, "sylvia", 3, command["id"], command["receipt"], _identity_issuer,
		_record("solo:sylvia:day3"))
	assert_false(replied.get("ok", true),
		"RED: solo reply was removed because opening is acceptance")
	assert_eq(replied.get("code"), &"solo_reply_not_required")


func test_group_reply_is_the_only_reply_that_creates_a_source() -> void:
	var script := _state_script()
	var state := _activated_group(script, 2)
	state = _open(script, state, "priscilla", 2, "command.open.group.day2")["value"]["candidate"]
	var replied: Dictionary = _reply(script, state, "lavinia", 2, "command.reply.group.day2")
	assert_true(replied.get("ok", false), str(replied))
	if not replied.get("ok", false):
		return
	var candidate: Dictionary = replied["value"]["candidate"]
	assert_eq(candidate.get("schedule_source_receipts", {}).size(), 1,
		"RED: the first canonical-pair reply persists one group source")
	assert_eq(replied.get("receipt", {}).get("kind"), "group_reply_acceptance")


func test_solo_source_persists_the_exact_matrix_row_and_replays_byte_identically() -> void:
	var script := _state_script()
	var state := _offered_solo(script, "priscilla", 1)
	var first := _open(script, state, "priscilla", 1, "solo-open")
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false):
		return
	var receipt: Dictionary = first["receipt"]
	assert_eq(_sorted_keys(receipt), [
		"action_id", "day", "kind", "participants", "previous_receipt_id",
		"receipt_id", "receipt_provenance",
	])
	assert_eq(receipt["kind"], "solo_read_acceptance")
	assert_eq(receipt["action_id"], "solo:priscilla:day1")
	assert_eq(receipt["participants"], ["priscilla"])
	assert_eq(receipt["previous_receipt_id"], "offer.solo:priscilla:day1")
	var command := _command("solo-open")
	var expected_sources: Array[String] = [
		'action_id="solo:priscilla:day1"',
		'command_id=%s' % JSON.stringify(command["id"]),
		'day=1',
		'kind="solo_read_acceptance"',
		'participants=["priscilla"]',
		'previous_receipt_id="offer.solo:priscilla:day1"',
		'role="contact_source.solo"',
	]
	expected_sources.sort()
	assert_eq(receipt["receipt_provenance"]["parent_receipt_id"], command["receipt"]["receipt_id"])
	assert_eq(receipt["receipt_provenance"]["child_kind"], "contact_source")
	assert_eq(receipt["receipt_provenance"]["ordinal"], 0)
	assert_eq(receipt["receipt_provenance"]["source_ids"], expected_sources)
	var replay := _open(script, first["value"]["candidate"], "priscilla", 1, "solo-open")
	assert_true(replay.get("ok", false), str(replay))
	assert_eq(replay["receipt"], receipt)
	assert_eq(replay["value"]["candidate"], first["value"]["candidate"])


func test_command_proof_rejections_and_conflicts_preserve_contacts() -> void:
	var script := _state_script()
	var state := _offered_solo(script, "priscilla", 1)
	var before := state.duplicate(true)
	var command := _command("proof")
	var forged: Dictionary = command["receipt"].duplicate(true)
	forged["token"] = "transaction_id.forged"
	var rejected: Dictionary = script.prepare_open_contact(
		state, "priscilla", 1, command["id"], forged, _identity_issuer,
		_record("solo:priscilla:day1"))
	assert_false(rejected.get("ok", true))
	assert_eq(state, before, "forged receipt rejection cannot mutate the input state")
	var accepted := _open(script, state, "priscilla", 1, "conflict")
	assert_true(accepted.get("ok", false), str(accepted))
	var occupied: Dictionary = accepted["value"]["candidate"]
	var same_command := _command("conflict")
	var conflict: Dictionary = script.prepare_open_contact(
		occupied, "sylvia", 1, same_command["id"], same_command["receipt"],
		_identity_issuer, _record("solo:sylvia:day1"))
	assert_false(conflict.get("ok", true))
	assert_eq(conflict.get("code"), &"command_transaction_conflict")
	assert_eq(occupied, accepted["value"]["candidate"])


func test_source_query_is_detached_and_registry_bound_including_day7() -> void:
	var script := _state_script()
	for friend_id: String in ["priscilla", "lavinia", "sylvia"]:
		var state := _offered_solo(script, friend_id, 7)
		var opened := _open(script, state, friend_id, 7, "day7.%s" % friend_id)
		assert_true(opened.get("ok", false), str(opened))
		if not opened.get("ok", false):
			continue
		var receipt: Dictionary = opened["receipt"]
		var action_id := "solo:%s:day7" % friend_id
		var validated: Dictionary = script.validate_schedule_source_receipt(
			opened["value"]["candidate"], receipt["receipt_id"], _record(action_id), 7)
		assert_true(validated.get("ok", false), str(validated))
		validated["value"]["receipt"]["participants"].append("forged")
		assert_eq(opened["value"]["candidate"]["schedule_source_receipts"][receipt["receipt_id"]]["participants"], [friend_id])
		var wrong_day: Dictionary = script.validate_schedule_source_receipt(
			opened["value"]["candidate"], receipt["receipt_id"], _record(action_id), 6)
		assert_false(wrong_day.get("ok", true), "a stale-day source cannot validate")


func test_contacts_and_source_receipts_reject_widened_or_loosely_typed_state() -> void:
	var script := _state_script()
	var widened: Dictionary = script.make_defaults()
	widened["unexpected"] = true
	assert_false(script.validate_state(widened).get("ok", true),
		"Contacts has an exact top-level member set")
	var integral_float: Dictionary = script.make_defaults()
	integral_float["next_sequence"] = 1.0
	assert_false(script.validate_state(integral_float).get("ok", true),
		"an integral float is not an int")
	var premature_witness: Dictionary = script.make_defaults()
	premature_witness["sylvia_hospital_witness_receipts"] = {"invented": {}}
	assert_false(script.validate_state(premature_witness).get("ok", true),
		"Task 3 reserves but cannot populate the Task-7 witness index")

	var opened := _open(script, _offered_solo(script, "sylvia", 1),
		"sylvia", 1, "strict-source")
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return
	var state: Dictionary = opened["value"]["candidate"]
	var receipt_id := str(opened["receipt"]["receipt_id"])
	var tampered: Dictionary = state.duplicate(true)
	tampered["schedule_source_receipts"][receipt_id]["receipt_provenance"]["source_ids"] = []
	assert_false(script.get_schedule_source_receipt(tampered, receipt_id).get("ok", true),
		"a structurally exact but semantically empty child projection is rejected")


func test_source_validation_requires_exact_contacts_local_operation_and_predecessor_links() -> void:
	var script := _state_script()
	var command := _command("local-linkage")
	var offered := _offered_solo(script, "priscilla", 1)
	var opened: Dictionary = script.prepare_open_contact(
		offered, "priscilla", 1, command["id"], command["receipt"], _identity_issuer,
		_record("solo:priscilla:day1"))
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return
	var base: Dictionary = opened["value"]["candidate"]
	var receipt_id := str(opened["receipt"]["receipt_id"])
	var predecessor_id := str(opened["receipt"]["previous_receipt_id"])
	var fabricated_id := "contact_source.%s" % "ab".repeat(32)
	var wrong_parent := "issuer_receipt.%s" % "cd".repeat(32)
	var wrong_token := "transaction_id.%s" % "ef".repeat(32)
	var cases: Array[Dictionary] = []

	var fabricated: Dictionary = base.duplicate(true)
	var fabricated_receipt: Dictionary = opened["receipt"].duplicate(true)
	fabricated_receipt["receipt_id"] = fabricated_id
	fabricated_receipt["receipt_provenance"]["child_id"] = fabricated_id
	fabricated["schedule_source_receipts"][fabricated_id] = fabricated_receipt
	cases.append({"name": "fabricated source has no command operation membership", "state": fabricated,
		"receipt_id": fabricated_id})

	var missing_predecessor: Dictionary = base.duplicate(true)
	missing_predecessor["transaction_receipts"].erase(predecessor_id)
	cases.append({"name": "predecessor operation is absent", "state": missing_predecessor,
		"receipt_id": receipt_id})

	var changed_predecessor: Dictionary = base.duplicate(true)
	changed_predecessor["transaction_receipts"][predecessor_id]["action_id"] = "solo:sylvia:day1"
	cases.append({"name": "predecessor operation bytes changed", "state": changed_predecessor,
		"receipt_id": receipt_id})

	var changed_command_receipt: Dictionary = base.duplicate(true)
	changed_command_receipt["transaction_receipts"][command["id"]]["command_issuer_receipt"]["token"] = wrong_token
	cases.append({"name": "stored full command receipt changed", "state": changed_command_receipt,
		"receipt_id": receipt_id})

	var parent_mismatch: Dictionary = base.duplicate(true)
	parent_mismatch["schedule_source_receipts"][receipt_id]["receipt_provenance"]["parent_receipt_id"] = wrong_parent
	cases.append({"name": "child parent differs from stored full command receipt", "state": parent_mismatch,
		"receipt_id": receipt_id})

	var token_mismatch: Dictionary = base.duplicate(true)
	var sources: Array = token_mismatch["schedule_source_receipts"][receipt_id]["receipt_provenance"]["source_ids"]
	for index: int in range(sources.size()):
		if str(sources[index]).begins_with("command_id="):
			sources[index] = "command_id=%s" % JSON.stringify(wrong_token)
			sources.sort()
			break
	cases.append({"name": "projected command token differs from operation token", "state": token_mismatch,
		"receipt_id": receipt_id})

	var source_operation_mismatch: Dictionary = base.duplicate(true)
	source_operation_mismatch["transaction_receipts"][command["id"]]["source_receipt_id"] = fabricated_id
	cases.append({"name": "command operation points at another source", "state": source_operation_mismatch,
		"receipt_id": receipt_id})

	for entry: Dictionary in cases:
		var before: Dictionary = entry["state"].duplicate(true)
		var checked: Dictionary = script.validate_schedule_source_receipt(
			entry["state"], entry["receipt_id"], _record("solo:priscilla:day1"), 1)
		assert_false(checked.get("ok", true), "RED local linkage: %s" % entry["name"])
		assert_eq(entry["state"], before, "validation is pure: %s" % entry["name"])

	var replay_tamper: Dictionary = base.duplicate(true)
	replay_tamper["transaction_receipts"][command["id"]]["action_id"] = "solo:sylvia:day1"
	var replay_before := replay_tamper.duplicate(true)
	var replayed: Dictionary = script.prepare_open_contact(
		replay_tamper, "priscilla", 1, command["id"], command["receipt"], _identity_issuer,
		_record("solo:priscilla:day1"))
	assert_false(replayed.get("ok", true),
		"RED replay: a tampered stored command operation cannot replay a valid-looking source")
	assert_eq(replay_tamper, replay_before, "tampered replay rejection preserves input Contacts")


func test_authenticated_replay_revalidates_the_exact_issuer_derived_source_child() -> void:
	var script := _state_script()
	var solo_command := _command("fix3-solo-derived-replay")
	var solo_opened: Dictionary = script.prepare_open_contact(
		_offered_solo(script, "priscilla", 1), "priscilla", 1,
		solo_command["id"], solo_command["receipt"], _identity_issuer,
		_record("solo:priscilla:day1"))
	assert_true(solo_opened.get("ok", false), str(solo_opened))
	var group_state := _activated_group(script, 2)
	group_state = _open(script, group_state, "priscilla", 2,
		"fix3-group-first-open")["value"]["candidate"]
	var group_command := _command("fix3-group-derived-replay")
	var group_replied: Dictionary = script.prepare_reply(
		group_state, "lavinia", 2, group_command["id"], group_command["receipt"],
		_identity_issuer, _record("group:priscilla_lavinia:day2"))
	assert_true(group_replied.get("ok", false), str(group_replied))
	var cases: Array[Dictionary] = [
		{"name": "solo", "state": solo_opened["value"]["candidate"],
			"source_id": solo_opened["receipt"]["receipt_id"], "command": solo_command},
		{"name": "group", "state": group_replied["value"]["candidate"],
			"source_id": group_replied["receipt"]["receipt_id"], "command": group_command},
	]
	for index: int in range(cases.size()):
		var entry: Dictionary = cases[index]
		var fabricated_id := "contact_source.%s" % ("a%d" % (index + 1)).repeat(32)
		var changed := _replace_source_child_id(entry["state"], entry["command"]["id"],
			entry["source_id"], fabricated_id)
		var before: Dictionary = changed.duplicate(true)
		var replayed: Dictionary
		if entry["name"] == "solo":
			replayed = script.prepare_open_contact(
				changed, "priscilla", 1, entry["command"]["id"], entry["command"]["receipt"],
				_identity_issuer, _record("solo:priscilla:day1"))
		else:
			replayed = script.prepare_reply(
				changed, "lavinia", 2, entry["command"]["id"], entry["command"]["receipt"],
				_identity_issuer, _record("group:priscilla_lavinia:day2"))
		assert_false(replayed.get("ok", true),
			"RED fix3 %s replay must reproduce the stored source child" % entry["name"])
		assert_eq(changed, before, "derived-child replay rejection is pure")

	var wrong_issuer: RefCounted = ISSUER.new()
	assert_true(wrong_issuer.configure(FAKE_ROOT.new("33".repeat(32), 1)).get("ok", false))
	for issuer: Variant in [null, wrong_issuer]:
		var solo_before: Dictionary = cases[0]["state"].duplicate(true)
		assert_false(script.prepare_open_contact(
			cases[0]["state"], "priscilla", 1, solo_command["id"], solo_command["receipt"],
			issuer, _record("solo:priscilla:day1")).get("ok", true))
		assert_eq(cases[0]["state"], solo_before)
		var group_before: Dictionary = cases[1]["state"].duplicate(true)
		assert_false(script.prepare_reply(
			cases[1]["state"], "lavinia", 2, group_command["id"], group_command["receipt"],
			issuer, _record("group:priscilla_lavinia:day2")).get("ok", true))
		assert_eq(cases[1]["state"], group_before)


func _replace_source_child_id(state: Dictionary, command_id: String, old_id: String,
		new_id: String) -> Dictionary:
	var changed: Dictionary = state.duplicate(true)
	var source: Dictionary = changed["schedule_source_receipts"][old_id]
	changed["schedule_source_receipts"].erase(old_id)
	source["receipt_id"] = new_id
	source["receipt_provenance"]["child_id"] = new_id
	changed["schedule_source_receipts"][new_id] = source
	changed["transaction_receipts"][command_id]["source_receipt_id"] = new_id
	return changed


func test_contact_source_rejects_every_malformed_registry_record_member() -> void:
	var script := _state_script()
	var state := _offered_solo(script, "priscilla", 1)
	var valid := _record("solo:priscilla:day1")
	var cases: Array[Dictionary] = []
	for key: String in [
		"action_id", "action_kind", "allowed_days", "effect_ids", "motivation_cost",
		"participants", "repeatable", "route_id", "source_receipt_kind",
	]:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(key)
		cases.append({"name": "missing %s" % key, "record": missing})
	var extra: Dictionary = valid.duplicate(true)
	extra["unexpected"] = true
	cases.append({"name": "extra member", "record": extra})
	for entry: Dictionary in [
		{"name": "action_id StringName coercion", "path": "action_id", "value": &"solo:priscilla:day1"},
		{"name": "action_kind StringName coercion", "path": "action_kind", "value": &"solo"},
		{"name": "allowed_days integral float", "path": "allowed_days", "value": [1.0, 2, 3, 4, 5, 6, 7]},
		{"name": "allowed_days order", "path": "allowed_days", "value": [2, 1, 3, 4, 5, 6, 7]},
		{"name": "allowed_days widened", "path": "allowed_days", "value": [1, 2]},
		{"name": "effect_ids item type", "path": "effect_ids", "value": [1]},
		{"name": "unexpected date effect", "path": "effect_ids", "value": ["effects.energy.gain"]},
		{"name": "motivation integral float", "path": "motivation_cost", "value": 1.0},
		{"name": "motivation wrong value", "path": "motivation_cost", "value": 2},
		{"name": "participants StringName coercion", "path": "participants", "value": [&"priscilla"]},
		{"name": "repeatable integer coercion", "path": "repeatable", "value": 0},
		{"name": "repeatable wrong value", "path": "repeatable", "value": true},
		{"name": "route StringName coercion", "path": "route_id", "value": &"dating"},
		{"name": "route wrong enum", "path": "route_id", "value": null},
		{"name": "source kind StringName coercion", "path": "source_receipt_kind", "value": &"solo_read_acceptance"},
	]:
		var changed: Dictionary = valid.duplicate(true)
		changed[entry["path"]] = entry["value"]
		cases.append({"name": entry["name"], "record": changed})

	for index: int in range(cases.size()):
		var command := _command("registry-negative-%d" % index)
		var before := state.duplicate(true)
		var result: Dictionary = script.prepare_open_contact(
			state, "priscilla", 1, command["id"], command["receipt"], _identity_issuer,
			cases[index]["record"])
		assert_false(result.get("ok", true), "RED registry primitive: %s" % cases[index]["name"])
		assert_eq(state, before, "registry rejection preserves Contacts: %s" % cases[index]["name"])


func test_solo_and_group_sources_enforce_every_plan01_projection_and_child_member() -> void:
	var script := _state_script()
	var solo_command := _command("matrix-solo")
	var solo_opened: Dictionary = script.prepare_open_contact(
		_offered_solo(script, "priscilla", 1), "priscilla", 1,
		solo_command["id"], solo_command["receipt"], _identity_issuer,
		_record("solo:priscilla:day1"))
	assert_true(solo_opened.get("ok", false), str(solo_opened))
	var solo_state: Dictionary = solo_opened["value"]["candidate"]
	var solo_id := str(solo_opened["receipt"]["receipt_id"])
	_assert_source_matrix_rejections(script, solo_state, solo_id,
		_record("solo:priscilla:day1"), 1, {
			"role=": 'role="contact_source.group"',
			"command_id=": 'command_id="transaction_id.%s"' % "aa".repeat(32),
			"kind=": 'kind="group_reply_acceptance"',
			"action_id=": 'action_id="solo:sylvia:day1"',
			"day=": "day=2",
			"participants=": 'participants=["sylvia"]',
			"previous_receipt_id=": 'previous_receipt_id="offer.changed"',
		}, "solo")
	var solo_replay: Dictionary = script.prepare_open_contact(
		solo_state, "priscilla", 1, solo_command["id"], solo_command["receipt"],
		_identity_issuer, _record("solo:priscilla:day1"))
	assert_true(solo_replay.get("ok", false), str(solo_replay))
	assert_eq(solo_replay.get("receipt"), solo_opened.get("receipt"),
		"genuine solo replay is byte-identical")

	var group_state := _activated_group(script, 2)
	assert_eq(group_state["solo_actions"]["solo:priscilla:day2"]["state"], "SUPERSEDED")
	assert_eq(group_state["solo_actions"]["solo:lavinia:day2"]["state"], "SUPERSEDED")
	assert_true(group_state["schedule_source_receipts"].is_empty(),
		"superseded solo offers expose no usable Schedule source")
	group_state = _open(script, group_state, "priscilla", 2, "matrix-group-open")["value"]["candidate"]
	var reversed_record := _record("group:priscilla_lavinia:day2")
	reversed_record["participants"] = ["lavinia", "priscilla"]
	var reversed_command := _command("matrix-group-reversed-record")
	var group_before_rejection: Dictionary = group_state.duplicate(true)
	var reversed_rejected: Dictionary = script.prepare_reply(
		group_state, "lavinia", 2, reversed_command["id"], reversed_command["receipt"],
		_identity_issuer, reversed_record)
	assert_false(reversed_rejected.get("ok", true),
		"the registry group participant array has one canonical order")
	assert_eq(group_state, group_before_rejection)
	var group_command := _command("matrix-group-reply")
	var group_replied: Dictionary = script.prepare_reply(
		group_state, "lavinia", 2, group_command["id"], group_command["receipt"],
		_identity_issuer, _record("group:priscilla_lavinia:day2"))
	assert_true(group_replied.get("ok", false), str(group_replied))
	var group_candidate: Dictionary = group_replied["value"]["candidate"]
	var group_id := str(group_replied["receipt"]["receipt_id"])
	var expected_group_sources: Array[String] = [
		'action_id="group:priscilla_lavinia:day2"',
		'command_id=%s' % JSON.stringify(group_command["id"]),
		'day=2',
		'kind="group_reply_acceptance"',
		'participants=["priscilla","lavinia"]',
		'previous_receipt_id="offer.group:priscilla_lavinia:day2"',
		'role="contact_source.group"',
	]
	expected_group_sources.sort()
	assert_eq(group_replied["receipt"]["receipt_provenance"]["source_ids"],
		expected_group_sources, "the group positive vector binds the exact P01.group row")
	_assert_source_matrix_rejections(script, group_candidate, group_id,
		_record("group:priscilla_lavinia:day2"), 2, {
			"role=": 'role="contact_source.solo"',
			"command_id=": 'command_id="transaction_id.%s"' % "bb".repeat(32),
			"kind=": 'kind="solo_read_acceptance"',
			"action_id=": 'action_id="group:priscilla_lavinia:day6"',
			"day=": "day=6",
			"participants=": 'participants=["lavinia","priscilla"]',
			"previous_receipt_id=": 'previous_receipt_id="offer.changed"',
		}, "group")
	var group_replay: Dictionary = script.prepare_reply(
		group_candidate, "lavinia", 2, group_command["id"], group_command["receipt"],
		_identity_issuer, _record("group:priscilla_lavinia:day2"))
	assert_true(group_replay.get("ok", false), str(group_replay))
	assert_eq(group_replay.get("receipt"), group_replied.get("receipt"),
		"genuine group replay is byte-identical")
	var conflicting: Dictionary = script.prepare_reply(
		group_candidate, "priscilla", 2, group_command["id"], group_command["receipt"],
		_identity_issuer, _record("group:priscilla_lavinia:day2"))
	assert_false(conflicting.get("ok", true), "same group transaction with another participant conflicts")


func test_source_creation_rejects_id_only_wrong_purpose_and_mismatched_full_proof() -> void:
	var script := _state_script()
	var state := _offered_solo(script, "priscilla", 1)
	var command := _command("proof-matrix-command")
	var before := state.duplicate(true)
	var id_only: Dictionary = script.prepare_open_contact(
		state, "priscilla", 1, command["id"], {}, _identity_issuer,
		_record("solo:priscilla:day1"))
	assert_false(id_only.get("ok", true), "caller-authored ID alone never proves a source")
	assert_eq(state, before)
	var wrong_issued: Dictionary = _identity_issuer.issue(&"receipt_id")
	assert_true(wrong_issued.get("ok", false), str(wrong_issued))
	var wrong_purpose: Dictionary = script.prepare_open_contact(
		state, "priscilla", 1, wrong_issued["value"]["token"],
		wrong_issued["value"]["issuer_receipt"], _identity_issuer,
		_record("solo:priscilla:day1"))
	assert_false(wrong_purpose.get("ok", true), "wrong-purpose full proof is rejected")
	assert_eq(state, before)
	var other := _command("proof-matrix-other")
	var mismatch: Dictionary = script.prepare_open_contact(
		state, "priscilla", 1, command["id"], other["receipt"], _identity_issuer,
		_record("solo:priscilla:day1"))
	assert_false(mismatch.get("ok", true), "token/full-receipt mismatch is rejected")
	assert_eq(state, before)


func test_day7_source_ancestry_rejects_offer_watermark_stale_participant_and_caller_id() -> void:
	var script := _state_script()
	for friend_id: String in ["priscilla", "lavinia", "sylvia"]:
		var offered := _offered_solo(script, friend_id, 7)
		var offer_id := "offer.solo:%s:day7" % friend_id
		assert_false(script.get_schedule_source_receipt(offered, offer_id).get("ok", true),
			"an offer operation is not a Schedule source: %s" % friend_id)
		var watermark_only: Dictionary = offered.duplicate(true)
		watermark_only["read_watermarks"][friend_id] = 999
		assert_true(watermark_only["schedule_source_receipts"].is_empty(),
			"a caller-authored watermark does not mint ancestry")
		var opened := _open(script, offered, friend_id, 7, "day7-matrix-%s" % friend_id)
		assert_true(opened.get("ok", false), str(opened))
		var receipt_id := str(opened["receipt"]["receipt_id"])
		var candidate: Dictionary = opened["value"]["candidate"]
		assert_true(script.validate_schedule_source_receipt(candidate, receipt_id,
			_record("solo:%s:day7" % friend_id), 7).get("ok", false))
		assert_false(script.validate_schedule_source_receipt(candidate, receipt_id,
			_record("solo:%s:day7" % friend_id), 6).get("ok", true), "stale day fails")
		var wrong_participant: Dictionary = candidate.duplicate(true)
		wrong_participant["schedule_source_receipts"][receipt_id]["participants"] = [
			"sylvia" if friend_id != "sylvia" else "lavinia"]
		assert_false(script.validate_schedule_source_receipt(wrong_participant, receipt_id,
			_record("solo:%s:day7" % friend_id), 7).get("ok", true), "wrong participant fails")
		var caller_id := "contact_source.%s" % "12".repeat(32)
		assert_false(script.validate_schedule_source_receipt(candidate, caller_id,
			_record("solo:%s:day7" % friend_id), 7).get("ok", true), "caller ID alone fails")


func _assert_source_matrix_rejections(script: Script, state: Dictionary, receipt_id: String,
		action_record: Dictionary, day: int, replacements: Dictionary, label: String) -> void:
	var cases: Array[Dictionary] = []
	for prefix: Variant in replacements:
		cases.append({"name": "%s projection" % prefix, "state": _replace_source_projection(
			state, receipt_id, str(prefix), str(replacements[prefix]), true)})
	var wrong_parent: Dictionary = state.duplicate(true)
	wrong_parent["schedule_source_receipts"][receipt_id]["receipt_provenance"]["parent_receipt_id"] = \
		"issuer_receipt.%s" % "34".repeat(32)
	cases.append({"name": "parent", "state": wrong_parent})
	var wrong_kind: Dictionary = state.duplicate(true)
	wrong_kind["schedule_source_receipts"][receipt_id]["receipt_provenance"]["child_kind"] = "schedule_entry"
	cases.append({"name": "child kind", "state": wrong_kind})
	var wrong_ordinal: Dictionary = state.duplicate(true)
	wrong_ordinal["schedule_source_receipts"][receipt_id]["receipt_provenance"]["ordinal"] = 1
	cases.append({"name": "ordinal", "state": wrong_ordinal})
	var wrong_order: Dictionary = state.duplicate(true)
	var ordered: Array = wrong_order["schedule_source_receipts"][receipt_id]["receipt_provenance"]["source_ids"]
	var swap: Variant = ordered[0]
	ordered[0] = ordered[1]
	ordered[1] = swap
	cases.append({"name": "source order", "state": wrong_order})
	var missing: Dictionary = state.duplicate(true)
	missing["schedule_source_receipts"][receipt_id]["receipt_provenance"]["source_ids"].remove_at(0)
	cases.append({"name": "source deletion", "state": missing})
	var added: Dictionary = state.duplicate(true)
	added["schedule_source_receipts"][receipt_id]["receipt_provenance"]["source_ids"].append('z_extra="x"')
	cases.append({"name": "source addition", "state": added})
	for entry: Dictionary in cases:
		var before: Dictionary = entry["state"].duplicate(true)
		var checked: Dictionary = script.validate_schedule_source_receipt(
			entry["state"], receipt_id, action_record, day)
		assert_false(checked.get("ok", true),
			"Plan P01.%s rejects changed %s" % [label, entry["name"]])
		assert_eq(entry["state"], before, "matrix rejection preserves Contacts")


func _replace_source_projection(state: Dictionary, receipt_id: String, prefix: String,
		replacement: String, sort_after: bool) -> Dictionary:
	var changed: Dictionary = state.duplicate(true)
	var sources: Array = changed["schedule_source_receipts"][receipt_id]["receipt_provenance"]["source_ids"]
	for index: int in range(sources.size()):
		if str(sources[index]).begins_with(prefix):
			sources[index] = replacement
			break
	if sort_after:
		sources.sort()
	return changed


func test_solo_source_rejects_valid_typed_local_ancestry_tampers_at_every_seam() -> void:
	var script := _state_script()
	var command := _command("fix2-solo-open")
	var opened: Dictionary = script.prepare_open_contact(
		_offered_solo(script, "priscilla", 1), "priscilla", 1,
		command["id"], command["receipt"], _identity_issuer,
		_record("solo:priscilla:day1"))
	assert_true(opened.get("ok", false), str(opened))
	var base: Dictionary = opened["value"]["candidate"]
	var source_id := str(opened["receipt"]["receipt_id"])
	var predecessor_id := str(opened["receipt"]["previous_receipt_id"])
	var offer_sequence: int = base["messages"]["priscilla"][0]["sequence"]
	var cases: Array[Dictionary] = []
	for entry: Dictionary in [
		{"name": "predecessor message id", "path": ["transaction_receipts", predecessor_id, "message_ids", 0], "value": "another-offer-message"},
		{"name": "predecessor child transaction", "path": ["transaction_receipts", predecessor_id, "child_transaction_ids", 0], "value": "another:message:0"},
		{"name": "predecessor message sequence", "path": ["transaction_receipts", predecessor_id, "message_sequences", 0], "value": offer_sequence + 1},
		{"name": "opening prior watermark", "path": ["transaction_receipts", command["id"], "prior_watermark"], "value": offer_sequence},
		{"name": "opening new watermark", "path": ["transaction_receipts", command["id"], "new_watermark"], "value": offer_sequence - 1},
		{"name": "accepted action state", "path": ["solo_actions", "solo:priscilla:day1", "state"], "value": "AVAILABLE"},
	]:
		cases.append({"name": entry["name"], "state": _mutate_schedule_state(
			base, entry["path"], entry["value"])})
	for entry: Dictionary in cases:
		var before: Dictionary = entry["state"].duplicate(true)
		assert_false(script.validate_state(entry["state"]).get("ok", true),
			"RED fix2 validate_state: %s" % entry["name"])
		assert_false(script.validate_schedule_source_receipt(
			entry["state"], source_id, _record("solo:priscilla:day1"), 1).get("ok", true),
			"RED fix2 source validation: %s" % entry["name"])
		var replayed: Dictionary = script.prepare_open_contact(
			entry["state"], "priscilla", 1, command["id"], command["receipt"],
			_identity_issuer, _record("solo:priscilla:day1"))
		assert_false(replayed.get("ok", true), "RED fix2 authenticated replay: %s" % entry["name"])
		assert_eq(entry["state"], before, "all local ancestry checks are pure")


func test_group_source_rejects_open_tuple_and_group_lineage_tampers_at_every_seam() -> void:
	var script := _state_script()
	var state := _activated_group(script, 2)
	var first_command := _command("fix2-group-first-open")
	var first_open: Dictionary = script.prepare_open_contact(
		state, "priscilla", 2, first_command["id"], first_command["receipt"],
		_identity_issuer, _record("group:priscilla_lavinia:day2"))
	assert_true(first_open.get("ok", false), str(first_open))
	state = first_open["value"]["candidate"]
	var second_command := _command("fix2-group-second-open")
	state = script.prepare_open_contact(
		state, "lavinia", 2, second_command["id"], second_command["receipt"],
		_identity_issuer, _record("group:priscilla_lavinia:day2"))["value"]["candidate"]
	var reply_command := _command("fix2-group-reply")
	var replied: Dictionary = script.prepare_reply(
		state, "lavinia", 2, reply_command["id"], reply_command["receipt"],
		_identity_issuer, _record("group:priscilla_lavinia:day2"))
	assert_true(replied.get("ok", false), str(replied))
	var base: Dictionary = replied["value"]["candidate"]
	var source_id := str(replied["receipt"]["receipt_id"])
	var cases: Array[Dictionary] = []
	for entry: Dictionary in [
		{"name": "first-open message id tuple", "path": ["transaction_receipts", first_command["id"], "message_ids", 0], "value": "another-group-message"},
		{"name": "first-open child transaction tuple", "path": ["transaction_receipts", first_command["id"], "child_transaction_ids", 0], "value": "another:message:0"},
		{"name": "first-open message sequence tuple", "path": ["transaction_receipts", first_command["id"], "message_sequences", 0], "value": 999},
		{"name": "group inviter linkage", "path": ["group_action", "inviter_id"], "value": "lavinia"},
		{"name": "group opened linkage", "path": ["group_action", "opened_ids"], "value": ["lavinia"]},
		{"name": "group replied linkage", "path": ["group_action", "replied_ids"], "value": ["priscilla"]},
	]:
		cases.append({"name": entry["name"], "state": _mutate_schedule_state(
			base, entry["path"], entry["value"])})
	var swapped: Dictionary = base.duplicate(true)
	for key: String in ["message_ids", "child_transaction_ids", "message_sequences"]:
		var values: Array = swapped["transaction_receipts"][first_command["id"]][key]
		var temporary: Variant = values[0]
		values[0] = values[1]
		values[1] = temporary
	cases.append({"name": "first-open paired tuple order", "state": swapped})
	for entry: Dictionary in cases:
		var before: Dictionary = entry["state"].duplicate(true)
		assert_false(script.validate_state(entry["state"]).get("ok", true),
			"RED fix2 group state: %s" % entry["name"])
		assert_false(script.validate_schedule_source_receipt(
			entry["state"], source_id, _record("group:priscilla_lavinia:day2"), 2).get("ok", true),
			"RED fix2 group source: %s" % entry["name"])
		var reply_replay: Dictionary = script.prepare_reply(
			entry["state"], "lavinia", 2, reply_command["id"], reply_command["receipt"],
			_identity_issuer, _record("group:priscilla_lavinia:day2"))
		assert_false(reply_replay.get("ok", true), "RED fix2 group reply replay: %s" % entry["name"])
		var open_replay: Dictionary = script.prepare_open_contact(
			entry["state"], "priscilla", 2, first_command["id"], first_command["receipt"],
			_identity_issuer, _record("group:priscilla_lavinia:day2"))
		assert_false(open_replay.get("ok", true), "RED fix2 group open replay: %s" % entry["name"])
		assert_eq(entry["state"], before, "group ancestry checks are pure")


func _mutate_schedule_state(state: Dictionary, path: Array, value: Variant) -> Dictionary:
	var changed: Dictionary = state.duplicate(true)
	var cursor: Variant = changed
	for index: int in range(path.size() - 1):
		cursor = (cursor as Dictionary)[path[index]] if typeof(cursor) == TYPE_DICTIONARY \
			else (cursor as Array)[int(path[index])]
	if typeof(cursor) == TYPE_DICTIONARY:
		(cursor as Dictionary)[path[-1]] = value
	else:
		(cursor as Array)[int(path[-1])] = value
	return changed


func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys
