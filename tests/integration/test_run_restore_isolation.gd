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
	for declaration: Dictionary in owner.get_signal_list():
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


func _restore_retired_source(source: String) -> String:
	# The removed unused methods are evidence, never executable compatibility APIs.
	# Pin their exact historical bytes without exempting test code from retirement.
	var text := FileAccess.get_file_as_string("res://tests/fixtures/source/game_state_retired_candidate_seams.json").replace("\r\n", "\n")
	const SOURCE_ARTIFACT_SHA256 := "a5cdc71da32cc7d6bbe2298157d63e8edda3511658b346e8536023ecd4874e82"
	assert_eq(text.sha256_text(), SOURCE_ARTIFACT_SHA256, "exact non-executable retirement source artifact")
	if text.sha256_text() != SOURCE_ARTIFACT_SHA256: return ""
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "retirement source artifact is an object")
	if not parsed is Dictionary: return ""
	var keys: Array = parsed.keys()
	keys.sort()
	var expected_keys := ["before_live_capture", "before_live_restore", "schema", "source_commit", "source_sha256"]
	assert_eq(keys, expected_keys, "exact retirement source fields")
	if keys != expected_keys: return ""
	assert_eq(parsed.schema, "dwm_retired_game_state_source.v1")
	assert_eq(parsed.source_commit, REFERENCE.SOURCE_COMMIT, "retirement and alias controls share the historical source")
	assert_eq(parsed.source_sha256, REFERENCE.SOURCE_SHA256)
	if parsed.schema != "dwm_retired_game_state_source.v1" or parsed.source_commit != REFERENCE.SOURCE_COMMIT \
			or parsed.source_sha256 != REFERENCE.SOURCE_SHA256: return ""
	for placement: Array in [
			["before_live_capture", "func capture_live_run_state() -> Dictionary:"],
			["before_live_restore", "func restore_live_run_state(backup: Dictionary) -> Dictionary:"]]:
		var fragment: Variant = parsed[placement[0]]
		var anchor: String = placement[1]
		assert_true(fragment is String and not fragment.is_empty(), "historical source fragment is present")
		assert_eq(source.count(anchor), 1, "one retained method anchors the historical fragment")
		if not fragment is String or fragment.is_empty() or source.count(anchor) != 1: return ""
		source = source.replace(anchor, fragment + anchor)
	return source


func _restore_retired_query_source(source: String) -> String:
	# Superseded query bodies and their old comment remain non-executable evidence.
	var text := FileAccess.get_file_as_string("res://tests/fixtures/source/game_state_retired_query_seams.json").replace("\r\n", "\n")
	const SOURCE_ARTIFACT_SHA256 := "9c896f9f868f5d3b7d4fcbc59c4db013ba626284974d428a440e54cc174fe442"
	assert_eq(text.sha256_text(), SOURCE_ARTIFACT_SHA256, "exact non-executable query retirement artifact")
	if text.sha256_text() != SOURCE_ARTIFACT_SHA256: return ""
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "query retirement artifact is an object")
	if not parsed is Dictionary: return ""
	var keys: Array = parsed.keys()
	keys.sort()
	var expected_keys := ["before_app_start", "before_scheduled_friends", "current_schedule_comment",
		"historical_schedule_comment", "schema", "source_commit", "source_sha256"]
	assert_eq(keys, expected_keys, "exact query retirement source fields")
	if keys != expected_keys: return ""
	assert_eq(parsed.schema, "dwm_retired_game_state_queries.v1")
	assert_eq(parsed.source_commit, REFERENCE.SOURCE_COMMIT, "query retirement shares the historical source")
	assert_eq(parsed.source_sha256, REFERENCE.SOURCE_SHA256)
	if parsed.schema != "dwm_retired_game_state_queries.v1" or parsed.source_commit != REFERENCE.SOURCE_COMMIT \
			or parsed.source_sha256 != REFERENCE.SOURCE_SHA256: return ""
	for placement: Array in [
			["before_app_start", "func can_start_minesweeper_app_round() -> bool:"],
			["before_scheduled_friends", "func get_scheduled_date_friend_ids() -> Array[String]:"]]:
		var fragment: Variant = parsed[placement[0]]
		var anchor: String = placement[1]
		assert_true(fragment is String and not fragment.is_empty(), "historical query source fragment is present")
		assert_eq(source.count(anchor), 1, "one retained method anchors each retired query")
		if not fragment is String or fragment.is_empty() or source.count(anchor) != 1: return ""
		source = source.replace(anchor, fragment + anchor)
	var current_comment: Variant = parsed.current_schedule_comment
	var historical_comment: Variant = parsed.historical_schedule_comment
	assert_true(current_comment is String and not current_comment.is_empty(), "current comment anchor is present")
	assert_true(historical_comment is String and not historical_comment.is_empty(), "historical comment is present")
	if not current_comment is String or current_comment.is_empty() \
			or not historical_comment is String or historical_comment.is_empty(): return ""
	assert_eq(source.count(current_comment), 1, "one exact current comment anchors the historical comment")
	if source.count(current_comment) != 1: return ""
	return source.replace(current_comment, historical_comment)


func _assert_frozen_provenance() -> bool:
	# A later owner edit must deliberately rebase this comparison contract and
	# retain a reproducible failing control; do not silently loosen these hashes.
	const LIVE_REFERENCE := preload("res://tests/support/LiveRunRollbackAliasingReference.gd")
	var source := _without_authenticated_scene_event_extension(_without_authenticated_note_counts(FileAccess.get_file_as_string("res://autoload/GameState.gd").replace("\r\n", "\n")))
	var reference := FileAccess.get_file_as_string("res://tests/support/RunRestoreAliasingReference.gd").replace("\r\n", "\n")
	var live_reference := FileAccess.get_file_as_string("res://tests/support/LiveRunRollbackAliasingReference.gd").replace("\r\n", "\n")
	var capture := _source_method(source, "capture_restore_state")
	var install := _source_method(source, "_apply_gameplay_silent")
	var live_capture := _source_method(source, "capture_live_run_state")
	var live_rollback := _source_method(source, "restore_live_run_state")
	var capture_reference := _source_method(reference, "capture_restore_state")
	var install_reference := _source_method(reference, "_apply_gameplay_silent")
	var live_capture_reference := _source_method(live_reference, "capture_live_run_state")
	var live_rollback_reference := _source_method(live_reference, "restore_live_run_state")
	assert_eq(capture_reference.sha256_text(), REFERENCE.CAPTURE_RESTORE_STATE_SHA256, "exact historical capture control")
	assert_eq(install_reference.sha256_text(), REFERENCE.APPLY_GAMEPLAY_SILENT_SHA256, "exact historical installation control")
	assert_eq(live_capture_reference.sha256_text(), LIVE_REFERENCE.CAPTURE_LIVE_RUN_STATE_SHA256, "exact historical active-run capture control")
	assert_eq(live_rollback_reference.sha256_text(), LIVE_REFERENCE.RESTORE_LIVE_RUN_STATE_SHA256, "exact historical active-run rollback control")
	assert_eq(capture.count("to_save_dict().duplicate(true)"), 1, "one capture detachment edit")
	assert_eq(install.count("v.duplicate(true)"), 2, "dictionary and array installation edits")
	assert_eq(live_capture.count("to_save_dict().duplicate(true)"), 1, "one active-run capture detachment edit")
	assert_eq(live_rollback.count('detached["gameplay"].duplicate(true)'), 1, "one active-run rollback detachment edit")
	if capture.is_empty() or install.is_empty() or capture.count("to_save_dict().duplicate(true)") != 1 \
			or install.count("v.duplicate(true)") != 2 or live_capture.is_empty() or live_rollback.is_empty() \
			or live_capture.count("to_save_dict().duplicate(true)") != 1 \
			or live_rollback.count('detached["gameplay"].duplicate(true)') != 1:
		return false
	assert_eq(source.count(capture), 1, "unique capture source body")
	assert_eq(source.count(install), 1, "unique installation source body")
	assert_eq(source.count(live_capture), 1, "unique active-run capture source body")
	assert_eq(source.count(live_rollback), 1, "unique active-run rollback source body")
	var restored := source.replace(capture, capture.replace("to_save_dict().duplicate(true)", "to_save_dict()"))
	restored = restored.replace(install, install.replace("v.duplicate(true)", "v.duplicate()"))
	restored = restored.replace(live_capture, live_capture.replace("to_save_dict().duplicate(true)", "to_save_dict()"))
	restored = restored.replace(live_rollback, live_rollback.replace('detached["gameplay"].duplicate(true)', 'detached["gameplay"]'))
	restored = _restore_retired_source(restored)
	restored = _restore_retired_query_source(restored)
	assert_eq(restored.sha256_text(), REFERENCE.SOURCE_SHA256, "five isolation edits and exact retirement fragments reconstruct the historical owner")
	return capture_reference.sha256_text() == REFERENCE.CAPTURE_RESTORE_STATE_SHA256 \
		and install_reference.sha256_text() == REFERENCE.APPLY_GAMEPLAY_SILENT_SHA256 \
		and live_capture_reference.sha256_text() == LIVE_REFERENCE.CAPTURE_LIVE_RUN_STATE_SHA256 \
		and live_rollback_reference.sha256_text() == LIVE_REFERENCE.RESTORE_LIVE_RUN_STATE_SHA256 \
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


func _without_authenticated_scene_event_extension(source: String) -> String:
	# Reverse only this reviewed append-only extension; preserve the historical oracle.
	const ANCHOR := "\n\n# Scene events share the existing Run receipt map."
	const EXTENSION_SHA256 := "e11d2990a0737baf57a85b43ed0fd3d2755dc3929cbef9231a9b62e5b0f99552"
	const FOUNDATION_SHA256 := "02ed11392633e9ded43609d93977adb0805870880add55b67c483d5d305694bc"
	assert_eq(source.count(ANCHOR), 1, "one exact scene-event extension anchor")
	if source.count(ANCHOR) != 1: return ""
	var offset := source.find(ANCHOR)
	var extension := source.substr(offset)
	var foundation := source.substr(0, offset)
	assert_eq(extension.to_utf8_buffer().size(), 10108, "exact scene-event extension byte count")
	assert_eq(extension.sha256_text(), EXTENSION_SHA256, "exact complete scene-event extension")
	assert_eq(foundation.sha256_text(), FOUNDATION_SHA256, "exact accepted foundation owner")
	if extension.to_utf8_buffer().size() != 10108 or extension.sha256_text() != EXTENSION_SHA256 \
			or foundation.sha256_text() != FOUNDATION_SHA256:
		return ""
	return foundation


func _without_authenticated_note_counts(source: String) -> String:
	# Reverse only the finite reviewed E count delta; unknown drift fails closed.
	var fragments: Array = [{"current": "const _DAY7_FOLLOWUPS := preload(\"res://scripts/domain/contact/Day7FollowupState.gd\")\nconst _DATING_ENDING_RULES := preload(\"res://scripts/domain/ending/DatingEndingRules.gd\")\nconst _PROVISIONAL_RELATIONSHIP_RULES := preload(\"res://scripts/domain/relationship/ProvisionalProgressionRules.gd\")\nconst _NOTE_PURCHASE_RULES := preload(\"res://scripts/domain/shop/RunNotePurchaseRules.gd\")\nconst _SCHEDULE_ACTION_REGISTRY := preload(\"res://scripts/domain/schedule/ScheduleActionRegistry.gd\")\n\nvar _run_lifecycle: RefCounted = _RUN_LIFECYCLE_SCRIPT.new()\n", "accepted": "const _DAY7_FOLLOWUPS := preload(\"res://scripts/domain/contact/Day7FollowupState.gd\")\nconst _DATING_ENDING_RULES := preload(\"res://scripts/domain/ending/DatingEndingRules.gd\")\nconst _PROVISIONAL_RELATIONSHIP_RULES := preload(\"res://scripts/domain/relationship/ProvisionalProgressionRules.gd\")\nconst _SCHEDULE_ACTION_REGISTRY := preload(\"res://scripts/domain/schedule/ScheduleActionRegistry.gd\")\n\nvar _run_lifecycle: RefCounted = _RUN_LIFECYCLE_SCRIPT.new()\n", "bytes": 548, "sha256": "89be671feaffb4954ff28e0ae381d97d2089c8499cb8a197f275a748e01f5c5e"}, {"current": "\t\treturn _transaction_failure(&\"invalid_run_backup\", \"backup was not issued by capture_live_run_state\")\n\tvar detached: Dictionary = source as Dictionary\n\tif typeof(detached.get(\"gameplay\")) == TYPE_DICTIONARY:\n\t\tvar gameplay_check: Dictionary = _prepare_note_restore_gameplay(detached[\"gameplay\"])\n\t\tif not gameplay_check.get(\"ok\", false):\n\t\t\treturn gameplay_check\n\t\tapply_save_dict(gameplay_check[\"value\"][\"gameplay\"].duplicate(true))\n\tif typeof(detached.get(\"contacts\")) == TYPE_DICTIONARY:\n\t\tcontacts = (detached[\"contacts\"] as Dictionary).duplicate(true)\n\t_command_receipts = (detached[\"command_receipts\"] as Dictionary).duplicate(true)\n", "accepted": "\t\treturn _transaction_failure(&\"invalid_run_backup\", \"backup was not issued by capture_live_run_state\")\n\tvar detached: Dictionary = source as Dictionary\n\tif typeof(detached.get(\"gameplay\")) == TYPE_DICTIONARY:\n\t\tapply_save_dict(detached[\"gameplay\"].duplicate(true))\n\tif typeof(detached.get(\"contacts\")) == TYPE_DICTIONARY:\n\t\tcontacts = (detached[\"contacts\"] as Dictionary).duplicate(true)\n\t_command_receipts = (detached[\"command_receipts\"] as Dictionary).duplicate(true)\n", "bytes": 641, "sha256": "9153868acdee74aea0fdd813be91d71a888b3b9181a8cc939177de4e97f5f793"}, {"current": "\t\treturn {\"ok\": false, \"code\": &\"invalid_run_backup\", \"message\": \"run backup requires gameplay and lifecycle\"}\n\tif typeof(source.get(\"run_configuration_installed\")) != TYPE_BOOL:\n\t\treturn {\"ok\": false, \"code\": &\"invalid_run_backup\", \"message\": \"run installation evidence is required\"}\n\tvar gameplay_check: Dictionary = _prepare_note_restore_gameplay(source[\"gameplay\"])\n\tif not gameplay_check.get(\"ok\", false):\n\t\treturn gameplay_check\n\tvar bookkeeping := _prepare_restore_bookkeeping(source, true)\n\tif not bookkeeping.get(\"ok\", false):\n\t\treturn bookkeeping\n", "accepted": "\t\treturn {\"ok\": false, \"code\": &\"invalid_run_backup\", \"message\": \"run backup requires gameplay and lifecycle\"}\n\tif typeof(source.get(\"run_configuration_installed\")) != TYPE_BOOL:\n\t\treturn {\"ok\": false, \"code\": &\"invalid_run_backup\", \"message\": \"run installation evidence is required\"}\n\tvar bookkeeping := _prepare_restore_bookkeeping(source, true)\n\tif not bookkeeping.get(\"ok\", false):\n\t\treturn bookkeeping\n", "bytes": 557, "sha256": "30d2dda19667d8f8922fd72f2fb47272c9bf59f7080d70f9b4029ee66932cec3"}, {"current": "\telif dating_backup != null:\n\t\treturn _transaction_failure(&\"invalid_dating_reconciliation_backup\", \"local owner is not configured\")\n\t_run_lifecycle.commit_restore(restored[\"value\"][\"candidate\"])\n\t_apply_gameplay_silent(gameplay_check[\"value\"][\"gameplay\"])\n\t_apply_restore_bookkeeping(bookkeeping[\"value\"])\n\t_restore_contacts_section((source as Dictionary).get(\"contacts\"))\n\tif not validated_backup.is_empty():\n", "accepted": "\telif dating_backup != null:\n\t\treturn _transaction_failure(&\"invalid_dating_reconciliation_backup\", \"local owner is not configured\")\n\t_run_lifecycle.commit_restore(restored[\"value\"][\"candidate\"])\n\t_apply_gameplay_silent((source as Dictionary)[\"gameplay\"])\n\t_apply_restore_bookkeeping(bookkeeping[\"value\"])\n\t_restore_contacts_section((source as Dictionary).get(\"contacts\"))\n\tif not validated_backup.is_empty():\n", "bytes": 411, "sha256": "c0c117401758a810021bfe6f6ee5d726f05a25f6265be10a254f79ad8c385459"}, {"current": "func _apply_run_snapshot_silent(snapshot: Dictionary) -> Dictionary:\n\tif typeof(snapshot.get(\"lifecycle\")) != TYPE_DICTIONARY:\n\t\treturn {\"ok\": false, \"code\": &\"invalid_run_plan\", \"message\": \"snapshot.lifecycle is required\"}\n\tvar gameplay_check: Dictionary = {}\n\tif typeof(snapshot.get(\"gameplay\")) == TYPE_DICTIONARY:\n\t\tgameplay_check = _prepare_note_restore_gameplay(snapshot[\"gameplay\"])\n\t\tif not gameplay_check.get(\"ok\", false):\n\t\t\treturn gameplay_check\n\tvar bookkeeping := _prepare_restore_bookkeeping(snapshot)\n\tif not bookkeeping.get(\"ok\", false):\n\t\treturn bookkeeping\n", "accepted": "func _apply_run_snapshot_silent(snapshot: Dictionary) -> Dictionary:\n\tif typeof(snapshot.get(\"lifecycle\")) != TYPE_DICTIONARY:\n\t\treturn {\"ok\": false, \"code\": &\"invalid_run_plan\", \"message\": \"snapshot.lifecycle is required\"}\n\tvar bookkeeping := _prepare_restore_bookkeeping(snapshot)\n\tif not bookkeeping.get(\"ok\", false):\n\t\treturn bookkeeping\n", "bytes": 575, "sha256": "de939370595e2717226206d36b1fb1f5dfcb1fbc6251e03c1da9ca8ba1c80e11"}, {"current": "\t\t\treturn {\"ok\": false, \"code\": &\"invalid_run_plan\", \"message\": desktop_error}\n\t_run_lifecycle.commit_restore(restored[\"value\"][\"candidate\"])\n\tif typeof(snapshot.get(\"gameplay\")) == TYPE_DICTIONARY:\n\t\t_apply_gameplay_silent(gameplay_check[\"value\"][\"gameplay\"])\n\t_apply_restore_bookkeeping(bookkeeping[\"value\"])\n\t_restore_contacts_section(snapshot.get(\"contacts\"))\n\tif not validated_committed.is_empty():\n", "accepted": "\t\t\treturn {\"ok\": false, \"code\": &\"invalid_run_plan\", \"message\": desktop_error}\n\t_run_lifecycle.commit_restore(restored[\"value\"][\"candidate\"])\n\tif typeof(snapshot.get(\"gameplay\")) == TYPE_DICTIONARY:\n\t\t_apply_gameplay_silent(snapshot[\"gameplay\"])\n\t_apply_restore_bookkeeping(bookkeeping[\"value\"])\n\t_restore_contacts_section(snapshot.get(\"contacts\"))\n\tif not validated_committed.is_empty():\n", "bytes": 404, "sha256": "fc1b53ce409591a325b940f546d2cc40641fdd6286da3e66de41bac1183b61ed"}, {"current": "\t\t_desktop_snapshot = (desktop as Dictionary).duplicate(true)\n\t_run_configuration_installed = true\n\treturn {\"ok\": true, \"code\": &\"ok\"}\n\n\n## Only restore defaults an omitted count map. Runtime floats remain invalid.\nfunc _prepare_note_restore_gameplay(gameplay: Dictionary) -> Dictionary:\n\tvar checked: Dictionary = _NOTE_PURCHASE_RULES.validate_counts(gameplay.get(\"shop_purchase_counts\", {}))\n\tif not checked.get(\"ok\", false):\n\t\treturn checked\n\tvar detached: Dictionary = gameplay.duplicate()\n\tdetached[\"shop_purchase_counts\"] = checked[\"value\"][\"shop_purchase_counts\"]\n\treturn {\"ok\": true, \"code\": &\"ok\", \"value\": {\"gameplay\": detached}}\n\n\n## Canonical saves carry all receipt fields; old partial owner plans may omit the\n", "accepted": "\t\t_desktop_snapshot = (desktop as Dictionary).duplicate(true)\n\t_run_configuration_installed = true\n\treturn {\"ok\": true, \"code\": &\"ok\"}\n\n\n## Canonical saves carry all receipt fields; old partial owner plans may omit the\n", "bytes": 724, "sha256": "71dcee620ccf4be5ca1d3a60fb647ded1e738c466f2d0134a338ec77bd302319"}]
	for fragment: Dictionary in fragments:
		var current: String = fragment.current
		assert_eq(source.count(current), 1, "unique exact Notes count fragment")
		assert_eq(current.to_utf8_buffer().size(), fragment.bytes, "Notes count fragment bytes")
		assert_eq(current.sha256_text(), fragment.sha256, "Notes count fragment hash")
		if source.count(current) != 1 or current.to_utf8_buffer().size() != fragment.bytes or current.sha256_text() != fragment.sha256:
			return ""
		source = source.replace(current, fragment.accepted)
	const ACCEPTED_SHA256 := "ce2fb9fc8c9821c8857641a377d0832fb1a862bafd86268c43226b24329ff2a8"
	assert_eq(source.sha256_text(), ACCEPTED_SHA256, "exact accepted af944020 owner before historical reversal")
	return source if source.sha256_text() == ACCEPTED_SHA256 else ""
