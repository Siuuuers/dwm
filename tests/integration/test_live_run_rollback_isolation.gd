extends "res://addons/gut/test.gd"

## The active effect/variable rollback seam must detach nested gameplay at both
## custody boundaries. These real-owner probes preserve its current day restore
## and one-signal publication; the frozen control witnesses the old aliases.
const GAME_STATE := preload("res://autoload/GameState.gd")
const REFERENCE := preload("res://tests/support/LiveRunRollbackAliasingReference.gd")


func _fixture(reference: bool = false) -> Node:
	var owner: Node = REFERENCE.new() if reference else GAME_STATE.new()
	autofree(owner)
	owner.reset_game()
	owner._lifecycle_set_playing_day(3)
	assert_eq(owner.day, 3, "fixture establishes the captured day before observation")
	owner.money = 17
	owner.missed_invitations = [{"friend_id": "priscilla", "source": "solo", "day": 2}]
	watch_signals(owner)
	return owner


func _mutate_nested(gameplay: Dictionary) -> void:
	gameplay.dating_route_state.priscilla.dark_points = 3
	gameplay.dating_route_state.priscilla.progression_event_ids.append("rollback-fixture-event")
	gameplay.missed_invitations[0].day = 4


func _mutate_owner(owner: Node) -> void:
	owner.dating_route_state.priscilla.dark_points = 3
	owner.dating_route_state.priscilla.progression_event_ids.append("rollback-fixture-event")
	owner.missed_invitations[0].day = 4


func _assert_publication(owner: Node, restored: bool) -> void:
	for declaration: Dictionary in owner.get_signal_list():
		var signal_name := str(declaration.name)
		if restored and signal_name == "save_relevant_state_changed":
			assert_signal_emit_count(owner, signal_name, 1, "existing rollback publishes once")
		else:
			assert_signal_not_emitted(owner, signal_name, "unchanged publication behavior: " + signal_name)


func _observe_isolation(actual: Dictionary, expected: Dictionary) -> Dictionary:
	return {
		"whole_gameplay": var_to_bytes(actual) == var_to_bytes(expected),
		"nested_dictionary": actual.dating_route_state.priscilla.dark_points == expected.dating_route_state.priscilla.dark_points,
		"nested_array": var_to_bytes(actual.dating_route_state.priscilla.progression_event_ids) == var_to_bytes(expected.dating_route_state.priscilla.progression_event_ids),
		"array_child_dictionary": var_to_bytes(actual.missed_invitations) == var_to_bytes(expected.missed_invitations),
	}


func _capture_probe(owner_to_backup: bool, reference: bool = false) -> Dictionary:
	var owner := _fixture(reference)
	var captured: Dictionary = owner.capture_live_run_state()
	assert_true(captured.get("ok", false), "real active-run capture succeeds")
	if not captured.get("ok", false): return {}
	var backup: Dictionary = captured.value.backup
	# The oracle is independently copied from the owner before either side moves.
	var expected: Dictionary = owner.to_save_dict().duplicate(true)
	if owner_to_backup:
		_mutate_owner(owner)
	else:
		_mutate_nested(backup.gameplay)
	_assert_publication(owner, false)
	var protected: Dictionary = backup.gameplay if owner_to_backup else owner.to_save_dict()
	return _observe_isolation(protected, expected)


func _rollback_probe(owner_to_backup: bool, wrapped: bool, reference: bool = false) -> Dictionary:
	var owner := _fixture(reference)
	var captured: Dictionary = owner.capture_live_run_state()
	assert_true(captured.get("ok", false), "real active-run capture succeeds")
	if not captured.get("ok", false): return {}
	# Isolate installation from capture's separate alias regression.
	var backup: Dictionary = captured.value.backup.duplicate(true)
	var expected: Dictionary = owner.to_save_dict().duplicate(true)
	_mutate_owner(owner)
	owner.money = 91
	owner._lifecycle_set_playing_day(5)
	var result: Dictionary = owner.restore_live_run_state({"backup": backup} if wrapped else backup)
	assert_eq(result, {"ok": true, "code": &"ok", "value": {}, "receipt": {}}, "existing successful rollback result")
	if not result.get("ok", false): return {}
	assert_eq(var_to_bytes(owner.to_save_dict()), var_to_bytes(expected), "rollback installs the independent original oracle")
	assert_eq(owner.day, 3, "rollback restores the captured day")
	assert_eq(owner.money, 17, "rollback restores captured scalar gameplay")
	if owner_to_backup:
		_mutate_owner(owner)
	else:
		_mutate_nested(backup.gameplay)
	_assert_publication(owner, true)
	var protected: Dictionary = backup.gameplay if owner_to_backup else owner.to_save_dict()
	return _observe_isolation(protected, expected)


func _assert_all_isolated(observation: Dictionary, isolated: bool, label: String) -> void:
	assert_eq(observation.size(), 4, label + ": all custody observations executed")
	for fact: String in observation:
		assert_eq(observation[fact], isolated, label + ": " + fact)


func test_frozen_live_run_control_reproduces_capture_and_rollback_aliases() -> void:
	# The companion restore-isolation witness checks these exact frozen method
	# hashes, reinstates the exact retired source, and reverses all five isolation edits.
	for owner_to_backup: bool in [false, true]:
		_assert_all_isolated(_capture_probe(owner_to_backup, true), false, "historical capture")
		for wrapped: bool in [false, true]:
			_assert_all_isolated(_rollback_probe(owner_to_backup, wrapped, true), false, "historical rollback")
	print("LIVE_RUN_ALIAS_CONTROL: six historical directions observed; raw and wrapped rollback reproduce nested aliases")


func test_active_run_capture_and_owner_keep_independent_nested_gameplay() -> void:
	for owner_to_backup: bool in [false, true]:
		_assert_all_isolated(_capture_probe(owner_to_backup), true, "active capture")


func test_active_run_rollback_keeps_independent_nested_gameplay_and_existing_publication() -> void:
	for owner_to_backup: bool in [false, true]:
		for wrapped: bool in [false, true]:
			_assert_all_isolated(_rollback_probe(owner_to_backup, wrapped), true, "active rollback")
