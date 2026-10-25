extends "res://tests/integration/scene_seven_day_connected_child.gd"
## Current shipped content, real viewport input and physical Save/Load.
## Run create, load, replay in separate rendered processes sharing DWM_TEST_ROOT.
const AUTHORED_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const AUTHORED_TEXT := preload("res://scripts/localization/StoryLocalization.gd")
const AUTHORED_ROUTE := [
	"Day1", "Day1.photo.default", "Day1.reading", "Day1.result.A", "Day1.coda",
	"Day2", "Day2.food.default", "Day2.answer", "Day2.result.A",
	"Day3", "Day3.lavinia", "Day3.lavinia.result.A",
	"Day4", "Day4.pastille.default", "Day4.impulse", "Day4.A",
	"Day5", "Day5.impulse", "Day5.A", "Day6", "Day6.rehearsal.default", "Day6.impulse", "Day6.A",
	"Day7", "Day7.clipboard.default", "Day7.untouched.impulse", "Day7.A", "ending.alone.normal"]
const DAY4_INDEX := 468
const ENDING_INDEX := 814
var _expected: Array[Dictionary] = []
var _timings: Array[Dictionary] = []
var _texts: Dictionary = {}
var _phase := ""

func _install_content_registration() -> Dictionary:
	for flag: String in ["DWM_SCENE_READING_FIXTURE", "DWM_RETAINED_CONTRACT_FIXTURE"]:
		if OS.get_environment(flag) == "1": return {"ok": false, "code": "authored_fixture_forbidden"}
	if "--scene-reading-fixture" in OS.get_cmdline_user_args() or "--scene-reading-fixture" in OS.get_cmdline_args():
		return {"ok": false, "code": "authored_fixture_argument_forbidden"}
	var selected: Dictionary = AUTHORED_MANIFEST.scene_registration()
	if not selected.get("ok", false): return selected
	if selected.value.get("schema_version") != 3 or AUTHORED_MANIFEST.first_target_id() != "target.Day1":
		return {"ok": false, "code": "authored_shipped_registration_required"}
	return selected

func _setup_authored() -> bool:
	assert_ne(DisplayServer.get_name(), "headless", "authored journey requires rendered evidence")
	if DisplayServer.get_name() == "headless" or not _start_services(): return false
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	if _phase == "create":
		if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return false
		if not _ok(profile.set_preference(&"preferences.reading.reveal_speed", "instant")): return false
		if not _ok(get_node("/root/LocalizationManager").set_locale("en")): return false
	else:
		assert_eq(profile.get_preference(&"preferences.reading.auto_enabled", true), false)
		assert_eq(profile.get_preference(&"preferences.reading.reveal_speed", ""), "instant")
		assert_eq(get_node("/root/LocalizationManager").get_locale(), "en")
	_texts = AUTHORED_TEXT.catalog("en")
	var selected: Dictionary = AUTHORED_MANIFEST.scene_registration()
	if not _ok(selected): return false
	var entries := {}
	for entry: Dictionary in selected.value.caption_registry.entries: entries[entry.entry_id] = entry.lines
	for entry_id: String in AUTHORED_ROUTE:
		assert_true(entries.has(entry_id), entry_id)
		if not entries.has(entry_id): return false
		for line: Dictionary in entries[entry_id]:
			_expected.append({"entry_id": entry_id, "line_id": line.line_id})
	assert_eq(_expected.size(), 836, "pinned authored default route census")
	assert_eq(_expected[DAY4_INDEX].line_id, "line.Day4.one")
	assert_eq(_expected[ENDING_INDEX].line_id, "line.ending.alone.normal.001")
	return _expected.size() == 836

func _wait_line(line_id: String) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if bridge._runtime_adapter.current_line_id() == line_id \
				and bridge._runtime_adapter.is_current_line_complete() \
				and bridge.is_current_line_presentation_acknowledged():
			var caption: Node = _caption()
			var inputs: Node = bridge._runtime_adapter._dialogic.get_subsystem("Inputs")
			if is_instance_valid(caption) and caption.caption_text.is_visible_in_tree() \
					and not caption.caption_text.revealing and not inputs.is_input_blocked():
				await RenderingServer.frame_post_draw
				var event: DialogicTextEvent = bridge._runtime_adapter._current_skip_text(true)
				assert_not_null(event)
				if event == null: return false
				assert_eq(event.state, DialogicTextEvent.States.DONE, line_id)
				assert_eq(float(caption.caption_text.visible_ratio), 1.0, line_id)
				assert_true(_texts.has(line_id), "authored English caption exists")
				assert_eq(caption.caption_text.get_parsed_text(), _texts.get(line_id, ""), line_id)
				observed_lines.append(line_id)
				return true
		await get_tree().process_frame
	await _screenshot("authored-week-timeout")
	fail_test("Authored caption timeout: " + line_id + "; actual=" + bridge._runtime_adapter.current_line_id())
	return false

func _day_timings() -> Dictionary:
	var totals := {}
	for row: Dictionary in _timings:
		var day: String = str(row.entry_id).get_slice(".", 0)
		totals[day] = int(totals.get(day, 0)) + int(row.elapsed_ms)
	return totals

func _walk_authored(first: int, last: int) -> bool:
	for index: int in range(first, last + 1):
		var started := Time.get_ticks_msec()
		print("AUTHORED_WEEK_ADVANCE_BEGIN index=", index, " line=", _expected[index].line_id, " ticks_ms=", started)
		await _accept()
		if not await _wait_line(_expected[index].line_id): return false
		assert_eq(bridge._reading_session.latest_entry, _expected[index].entry_id, "shipped route entry")
		# Record scalars only; copying the growing checkpoint per caption would
		# distort the journey being measured. Boundary captures carry full state.
		_timings.append({"entry_id": _expected[index].entry_id, "line_id": _expected[index].line_id,
			"elapsed_ms": Time.get_ticks_msec() - started})
		print("AUTHORED_WEEK_TIMING " + JSON.stringify(_timings.back()))
		if str(_expected[index].line_id).ends_with(".one"):
			await _screenshot("authored-" + str(_expected[index].entry_id))
			print("AUTHORED_WEEK_BOUNDARY ", _expected[index].entry_id, " ticks_ms=", Time.get_ticks_msec())
	return true

func _press_authored(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree() or control.get("disabled") == true:
		fail_test("Authored journey requires a visible enabled control")
		return false
	await _click(control)
	return true

func _save_authored(slot: int, label: String) -> Dictionary:
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return {}
	var native := _native_observation()
	if not await _press_authored(_caption().transport_rail.get_node("Save")): return {}
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	var app: Control = sheet.surface._hosts[&"backup"]
	if not await _press_authored(app.drawer_buttons.get("slot:%d" % slot)): return {}
	if not await _press_authored(app.action_buttons.get("save")): return {}
	var path := "user://saves/slot_%d.json" % slot
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and (app._in_operation or not FileAccess.file_exists(path)):
		await get_tree().process_frame
	if app._in_operation or not FileAccess.file_exists(path):
		fail_test("Authored physical Save timeout")
		return {}
	if not _ok(app.last_result): return {}
	if sheet.surface._direct_host:
		if not await _press_authored(sheet.surface._sheet_back): return {}
	else:
		# Ending uses the retained Pause host: Escape leaves Backup, then Continue.
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ESCAPE
			event.physical_keycode = KEY_ESCAPE
			event.pressed = pressed
			get_viewport().push_input(event, true)
			await get_tree().process_frame
		assert_eq(sheet.surface.entered_action, &"", "native Back leaves ending Backup")
		if sheet.surface.entered_action != &"": return {}
		if not await _press_authored(sheet.surface.rows[&"continue"]): return {}
	assert_false(get_tree().paused)
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(path))
	if not _ok(parsed): return {}
	var snapshot: Dictionary = parsed.value.current_snapshot.snapshot
	var player_reading: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").project_player_checkpoint(reading.value)
	if not _ok(player_reading): return {}
	assert_eq(snapshot.narrative_checkpoint, player_reading.value, "physical Save preserves exact visible position without history")
	assert_eq(bridge.capture_reading_checkpoint(false).value, reading.value, "Back preserves frontier")
	await _screenshot("authored-" + label)
	var proof := {"process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"registration_sha256": AUTHORED_MANIFEST.scene_registration_fingerprint(),
		"checkpoint": snapshot.narrative_checkpoint, "snapshot": snapshot, "saved_native": native,
		"profile": profile.get_profile_snapshot(), "slot_sha256": FileAccess.get_sha256(path),
		"autosave_sha256": FileAccess.get_sha256("user://saves/autosave.json"),
		"profile_sha256": FileAccess.get_sha256("user://profile.json"),
		"observed_lines": observed_lines.duplicate(), "timings": _timings.duplicate(true), "day_elapsed_ms": _day_timings(),
		"window_size": [get_window().size.x, get_window().size.y],
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]}
	if not _write_json("user://authored-week-" + label + ".json", proof): return {}
	if not _write_json("res://.godot/ci/authored-week-" + label + ".json", proof): return {}
	return proof

func _load_authored(slot: int, proof: Dictionary) -> bool:
	assert_ne(OS.get_process_id(), proof.process_id, "fresh OS process")
	assert_eq(ProjectSettings.globalize_path("user://"), proof.user_dir)
	assert_eq(AUTHORED_MANIFEST.scene_registration_fingerprint(), proof.registration_sha256)
	var path := "user://saves/slot_%d.json" % slot
	assert_eq(FileAccess.get_sha256(path), proof.slot_sha256)
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	get_node("/root/SceneRouter").goto_menu()
	if not await _wait_route(MENU): return false
	var menu: Node = get_tree().current_scene
	saves.live_session_ready.connect(func() -> void: _ready_observation = _native_observation())
	if not await _press_authored(menu.get_node("%LogInButton")): return false
	var app: Control = menu._backup_app_instance
	assert_not_null(app, "Title LogIn mounts Backup")
	if not is_instance_valid(app): return false
	if not await _press_authored(app.drawer_buttons.get("slot:%d" % slot)): return false
	if not await _press_authored(app.action_buttons.get("load")): return false
	if is_instance_valid(app) and is_instance_valid(app.confirmation):
		if not await _press_authored(app.confirmation.confirm_button): return false
	if not await _await_ready(): return false
	var expanded: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").expand_player_checkpoint(proof.checkpoint)
	if not _ok(expanded): return false
	var line_id: String = expanded.value.reading_session.frontier.line_id
	if not await _wait_line(line_id): return false
	assert_eq(_ready_observation.line_id, line_id)
	assert_true(_ready_observation.visible)
	assert_false(_ready_observation.revealing)
	assert_true(_ready_observation.event_done)
	assert_eq(float(_ready_observation.visible_ratio), 1.0)
	assert_eq(_ready_observation.ledger, expanded.value.reading_session.ledger)
	assert_eq(bridge.capture_reading_checkpoint(false).value, expanded.value)
	var current: Dictionary = game.capture_run_snapshot_input()
	assert_eq(current.lifecycle.run_id, proof.snapshot.lifecycle.run_id)
	assert_ne(current.lifecycle.branch_id, proof.snapshot.lifecycle.branch_id)
	for key: String in ["gameplay", "scene"]:
		assert_eq(current[key], proof.snapshot[key], "Load preserves " + key)
	assert_eq(profile.get_profile_snapshot(), profile_before, "Load preserves current profile")
	assert_eq(FileAccess.get_sha256(path), proof.slot_sha256)
	await _screenshot("authored-restored-slot-%d" % slot)
	return true

func _complete_authored() -> Dictionary:
	await _accept()
	if not await _wait_route(MENU): return {}
	var finished: Dictionary = game._run_lifecycle.to_dict().duplicate(true)
	assert_eq(finished.state, "COMPLETED")
	assert_false(finished.has("ending_plan"), "ordinary passage completion has no terminal plan")
	assert_false(game.capture_live_session().value.active)
	var durable: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(durable): return {}
	assert_eq(durable.value.current_snapshot.snapshot.lifecycle.state, "COMPLETED")
	assert_false(durable.value.current_snapshot.snapshot.lifecycle.has("ending_plan"))
	assert_eq(durable.value.current_snapshot.snapshot.narrative_checkpoint.entry_id, "ending.alone.normal")
	await _screenshot("authored-" + _phase + "-completed-title")
	return finished

func create_authored_week() -> void:
	_phase = "create"
	if not _setup_authored(): return
	assert_false(FileAccess.file_exists("user://saves/slot_1.json"))
	if FileAccess.file_exists("user://saves/slot_1.json"): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1): return
	if not await _walk_authored(1, DAY4_INDEX): return
	assert_eq(observed_lines.size(), 469)
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	await _save_authored(1, "day4")

func load_authored_week() -> void:
	_phase = "load"
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://authored-week-day4.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	_assert_source_files(proof)
	if not _setup_authored(): return
	_assert_source_files(proof)
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	if not await _load_authored(1, proof): return
	if not await _walk_authored(DAY4_INDEX + 1, ENDING_INDEX): return
	assert_eq(get_tree().current_scene.scene_file_path, HOST, "umbrella passage remains ordinary Scene playback")
	var ending_proof: Dictionary = await _save_authored(2, "ending")
	if ending_proof.is_empty(): return
	if not await _walk_authored(ENDING_INDEX + 1, _expected.size() - 1): return
	assert_eq(observed_lines.size(), 368)
	var finished: Dictionary = await _complete_authored()
	if finished.is_empty(): return
	var completed_profile: Dictionary = profile.get_profile_snapshot()
	var gallery_id := "passage:%s:gallery:passage.umbrella" % str(proof.snapshot.lifecycle.run_id)
	assert_eq(completed_profile.gallery_transaction_receipts.get(gallery_id), {"ending_id": "passage.umbrella", "unlocked": true})
	assert_eq(completed_profile.gallery_transaction_receipts.size(), proof.profile.gallery_transaction_receipts.size() + 1)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), ending_proof.slot_sha256)
	_write_json("res://.godot/ci/authored-week-load.json", {"process_id": OS.get_process_id(),
		"window_size": [get_window().size.x, get_window().size.y],
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"creator_process_id": proof.process_id, "ready_native": _ready_observation,
		"registration_sha256": AUTHORED_MANIFEST.scene_registration_fingerprint(),
		"observed_lines": observed_lines, "timings": _timings, "day_elapsed_ms": _day_timings(), "completed_lifecycle": finished,
		"completed_profile": completed_profile})

func replay_authored_ending() -> void:
	_phase = "replay"
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://authored-week-ending.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	if not _setup_authored(): return
	var before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var gallery_id := "passage:%s:gallery:passage.umbrella" % str(proof.snapshot.lifecycle.run_id)
	assert_true(before.gallery_transaction_receipts.has(gallery_id), "previous process completed ending")
	var day4_hash := FileAccess.get_sha256("user://saves/slot_1.json")
	if not await _load_authored(2, proof): return
	if not await _walk_authored(ENDING_INDEX + 1, _expected.size() - 1): return
	assert_eq(observed_lines.size(), 22)
	var finished: Dictionary = await _complete_authored()
	if finished.is_empty(): return
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts, before.gallery_transaction_receipts,
		"replaying physical ending Save creates no duplicate Gallery receipt")
	if not await _new_from_title(2): return
	var fresh: Dictionary = game.capture_run_snapshot_input()
	assert_ne(fresh.lifecycle.run_id, proof.snapshot.lifecycle.run_id)
	assert_eq(fresh.lifecycle.state, "PLAYING")
	assert_false(fresh.lifecycle.has("ending_plan"))
	assert_eq(bridge._reading_session.ledger.snapshot().captions.size(), 1)
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts, before.gallery_transaction_receipts)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), day4_hash)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.slot_sha256)
	await _screenshot("authored-fresh-day1")
	_write_json("res://.godot/ci/authored-week-replay.json", {"process_id": OS.get_process_id(),
		"window_size": [get_window().size.x, get_window().size.y],
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"creator_process_id": proof.process_id,
		"registration_sha256": AUTHORED_MANIFEST.scene_registration_fingerprint(), "observed_lines": observed_lines, "timings": _timings, "day_elapsed_ms": _day_timings(),
		"completed_lifecycle": finished, "fresh_lifecycle": fresh.lifecycle,
		"gallery_receipts": profile.get_profile_snapshot().gallery_transaction_receipts})
