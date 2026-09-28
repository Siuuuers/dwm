extends "res://addons/gut/test.gd"

## Real owner/participant integration. Failure catalogue: a captured backup must
## not edit live state; live state must not edit its backup; applied plans and
## rollback backups must not share nested containers with the installed owner.
## The frozen control witnesses each old failure in the same cloud process.
## No filesystem storage, mocked GameState, or copied expected-value alias.
const GAME_STATE := preload("res://autoload/GameState.gd")
const PARTICIPANT := preload("res://scripts/application/restore/RunRestoreParticipant.gd")
const REFERENCE := preload("res://tests/support/RunRestoreAliasingReference.gd")


func _fixture(reference: bool = false) -> Dictionary:
	var owner: Node = REFERENCE.new() if reference else GAME_STATE.new()
	autofree(owner)
	owner.reset_game()
	# Exercise both a dictionary-owned nested array and an array-owned dictionary.
	owner.missed_invitations = [{"friend_id": "priscilla", "source": "solo", "day": 1}]
	watch_signals(owner)
	return {"owner": owner, "participant": PARTICIPANT.new(owner)}


func _mutate_nested(gameplay: Dictionary) -> void:
	gameplay.dating_route_state.priscilla.dark_points = 3
	gameplay.dating_route_state.priscilla.progression_event_ids.append("fixture-event")
	gameplay.missed_invitations[0].day = 2


func _mutate_owner(owner: Node) -> void:
	owner.dating_route_state.priscilla.dark_points = 3
	owner.dating_route_state.priscilla.progression_event_ids.append("fixture-event")
	owner.missed_invitations[0].day = 2


func _assert_publication(owner: Node, finalized: bool) -> void:
	for declaration: Dictionary in GAME_STATE.get_script_signal_list():
		var signal_name := str(declaration.name)
		if finalized and signal_name == "save_relevant_state_changed":
			assert_signal_emit_count(owner, signal_name, 1, "one publication at finalization")
		else:
			assert_signal_not_emitted(owner, signal_name, "restore remains silent: " + signal_name)


func _observe_isolation(actual: Dictionary, expected: Dictionary) -> Dictionary:
	return {
		"whole_gameplay": var_to_bytes(actual) == var_to_bytes(expected),
		"nested_dictionary": actual.dating_route_state.priscilla.dark_points == expected.dating_route_state.priscilla.dark_points,
		"nested_array": var_to_bytes(actual.dating_route_state.priscilla.progression_event_ids) == var_to_bytes(expected.dating_route_state.priscilla.progression_event_ids),
		"array_child_dictionary": var_to_bytes(actual.missed_invitations) == var_to_bytes(expected.missed_invitations),
	}


func _capture_probe(owner_to_backup: bool, reference: bool = false) -> Dictionary:
	var f := _fixture(reference)
	var captured: Dictionary = f.participant.capture()
	assert_true(captured.get("ok", false), "real owner capture succeeds")
	if not captured.get("ok", false): return {}
	var backup: Dictionary = captured.value.backup
	# Copy independently before mutation: a buggy backup cannot move the oracle.
	var expected: Dictionary = f.owner.to_save_dict().duplicate(true)
	if owner_to_backup:
		_mutate_owner(f.owner)
	else:
		_mutate_nested(backup.gameplay)
	_assert_publication(f.owner, false)
	# The backup also carries narrative_variables, which to_save_dict excludes.
	var protected: Dictionary = backup.gameplay.duplicate(true) if owner_to_backup else f.owner.to_save_dict()
	protected.erase("narrative_variables")
	return _observe_isolation(protected, expected)


func _installation_probe(rollback: bool, owner_to_payload: bool, reference: bool = false) -> Dictionary:
	var f := _fixture(reference)
	var captured: Dictionary = f.participant.capture()
	assert_true(captured.get("ok", false), "real owner capture succeeds")
	if not captured.get("ok", false): return {}
	# Deliberately detach here so capture's separate regression cannot mask the
	# apply/rollback boundary being exercised, even in the historical control.
	var payload: Dictionary = captured.value.backup.duplicate(true)
	var expected: Dictionary = f.owner.to_save_dict().duplicate(true)
	var installed: Dictionary
	if rollback:
		_mutate_owner(f.owner)
		installed = f.participant.rollback_silent(payload)
	else:
		var source := {"snapshot": payload.duplicate(true)}
		var prepared: Dictionary = f.participant.prepare(source)
		assert_true(prepared.get("ok", false), "real participant prepares its detached plan")
		if not prepared.get("ok", false): return {}
		var plan: Dictionary = prepared.value.run_plan
		_mutate_nested(source.snapshot.gameplay)
		assert_eq(plan.snapshot, payload, "caller edits cannot change the prepared plan")
		payload = plan.snapshot
		_mutate_owner(f.owner)
		installed = f.participant.apply_silent(plan)
	assert_true(installed.get("ok", false), "real owner installation succeeds")
	if not installed.get("ok", false): return {}
	assert_eq(f.owner.to_save_dict(), expected, "installation restores the independent original oracle")
	if owner_to_payload:
		_mutate_owner(f.owner)
	else:
		_mutate_nested(payload.gameplay)
	_assert_publication(f.owner, false)
	var protected: Dictionary = payload.gameplay.duplicate(true) if owner_to_payload else f.owner.to_save_dict()
	protected.erase("narrative_variables")
	var observation := _observe_isolation(protected, expected)
	assert_true(f.participant.finalize().get("ok", false), "real owner finalization succeeds")
	_assert_publication(f.owner, true)
	return observation


func _assert_all_isolated(observation: Dictionary, isolated: bool, label: String) -> void:
	assert_eq(observation.size(), 4, label + ": all custody observations executed")
	for fact: String in observation:
		assert_eq(observation[fact], isolated, label + ": " + fact)


func _source_method(source: String, method_name: String) -> String:
	var lines := PackedStringArray()
	var started := false
	for line: String in source.split("\n"):
		if not started:
			if not line.begins_with("func " + method_name + "("): continue
			started = true
		elif not line.is_empty() and not line.begins_with("\t"):
			break
		lines.append(line)
	return "\n".join(lines).strip_edges(false, true) + "\n" if started else ""


func _assert_frozen_provenance() -> bool:
	# A later owner edit must deliberately rebase this comparison contract and
	# retain a reproducible failing control; do not silently loosen these hashes.
	var source := FileAccess.get_file_as_string("res://autoload/GameState.gd").replace("\r\n", "\n")
	var reference := FileAccess.get_file_as_string("res://tests/support/RunRestoreAliasingReference.gd").replace("\r\n", "\n")
	var capture := _source_method(source, "capture_restore_state")
	var install := _source_method(source, "_apply_gameplay_silent")
	var capture_reference := _source_method(reference, "capture_restore_state")
	var install_reference := _source_method(reference, "_apply_gameplay_silent")
	assert_eq(capture_reference.sha256_text(), REFERENCE.CAPTURE_RESTORE_STATE_SHA256, "exact historical capture control")
	assert_eq(install_reference.sha256_text(), REFERENCE.APPLY_GAMEPLAY_SILENT_SHA256, "exact historical installation control")
	assert_eq(capture.count("to_save_dict().duplicate(true)"), 1, "one capture detachment edit")
	assert_eq(install.count("v.duplicate(true)"), 2, "dictionary and array installation edits")
	if capture.is_empty() or install.is_empty() or capture.count("to_save_dict().duplicate(true)") != 1 \
			or install.count("v.duplicate(true)") != 2:
		return false
	assert_eq(source.count(capture), 1, "unique capture source body")
	assert_eq(source.count(install), 1, "unique installation source body")
	var restored := source.replace(capture, capture.replace("to_save_dict().duplicate(true)", "to_save_dict()"))
	restored = restored.replace(install, install.replace("v.duplicate(true)", "v.duplicate()"))
	assert_eq(restored.sha256_text(), REFERENCE.SOURCE_SHA256, "three edits reconstruct the exact historical owner source")
	return capture_reference.sha256_text() == REFERENCE.CAPTURE_RESTORE_STATE_SHA256 \
		and install_reference.sha256_text() == REFERENCE.APPLY_GAMEPLAY_SILENT_SHA256 \
		and restored.sha256_text() == REFERENCE.SOURCE_SHA256


func test_frozen_owner_reproduces_all_six_historical_alias_directions() -> void:
	if not _assert_frozen_provenance(): return
	for owner_to_payload: bool in [false, true]:
		_assert_all_isolated(_capture_probe(owner_to_payload, true), false, "historical capture")
		_assert_all_isolated(_installation_probe(false, owner_to_payload, true), false, "historical apply")
		_assert_all_isolated(_installation_probe(true, owner_to_payload, true), false, "historical rollback")
	print("RESTORE_ALIAS_CONTROL: six historical directions observed; nested dictionary/array aliases reproduced")


func test_captured_backup_mutation_cannot_change_live_gameplay() -> void:
	_assert_all_isolated(_capture_probe(false), true, "backup to owner")


func test_live_gameplay_mutation_cannot_change_captured_backup() -> void:
	_assert_all_isolated(_capture_probe(true), true, "owner to backup")


func test_prepared_restore_plan_and_installed_owner_remain_independent_until_finalize() -> void:
	for owner_to_payload: bool in [false, true]:
		_assert_all_isolated(_installation_probe(false, owner_to_payload), true, "prepared apply")


func test_rollback_backup_and_restored_owner_remain_independent_until_finalize() -> void:
	for owner_to_payload: bool in [false, true]:
		_assert_all_isolated(_installation_probe(true, owner_to_payload), true, "rollback")
