extends "res://tests/integration/scene_computer_child.gd"
## Rendered production title journey. The inherited fixture installer is replaced
## with inspection of the shipped registration; no test registration is installed.
const CURRENT_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const STORY_TEXT := preload("res://scripts/localization/StoryLocalization.gd")
const CURRENT_ART := preload("res://scripts/data/ArtManifest.gd")
const TITLE_PROOF := "user://current-title-scene-proof.json"
const TITLE_SLOT := "user://saves/slot_1.json"
const FIRST_LINE := "line.Day1.one"

func _screenshot(label: String) -> void:
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	await super._screenshot(label)

func _install_content_registration() -> Dictionary:
	for flag: String in ["DWM_SCENE_READING_FIXTURE", "DWM_RETAINED_CONTRACT_FIXTURE"]:
		if OS.get_environment(flag) == "1":
			return {"ok": false, "code": "current_title_fixture_forbidden", "flag": flag}
	if "--scene-reading-fixture" in OS.get_cmdline_user_args() or "--scene-reading-fixture" in OS.get_cmdline_args():
		return {"ok": false, "code": "current_title_fixture_argument_forbidden"}
	var selected: Dictionary = CURRENT_MANIFEST.scene_registration()
	if not selected.get("ok", false): return selected
	if selected.value.get("schema_version") != 3 or CURRENT_MANIFEST.first_target_id() != "target.Day1":
		return {"ok": false, "code": "current_title_shipped_registration_required"}
	return selected

func _press(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		fail_test("current title journey requires a visible backed control")
		return false
	if control.get("disabled") == true:
		fail_test("current title journey control disabled: " + str(control.get_path()))
		return false
	await _click(control)
	return true

func _wait_first_caption() -> bool:
	var expected: Variant = STORY_TEXT.catalog("en").get(FIRST_LINE)
	if not expected is String or str(expected).strip_edges().is_empty():
		fail_test("current title requires nonempty shipped English text for " + FIRST_LINE)
		return false
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var failure: Dictionary = saves._scene_restore_activation.get("failure", {})
		if not failure.is_empty(): return _ok(failure)
		if ready_count == 1 and is_instance_valid(get_tree().current_scene) \
				and get_tree().current_scene.scene_file_path == HOST:
			var caption: Node = _caption()
			if is_instance_valid(caption) and caption.caption_text.is_visible_in_tree() \
					and not caption.caption_text.revealing \
					and caption.caption_text.get_parsed_text() == expected \
					and bridge.is_current_line_presentation_acknowledged():
				var reading: Dictionary = bridge.capture_reading_checkpoint(false)
				if reading.get("ok", false) and reading.value.reading_session.entry_id == "Day1" \
						and reading.value.reading_session.frontier.get("line_id") == FIRST_LINE: return true
		await get_tree().process_frame
	fail_test("current title first caption timeout: " + str({"ready_count": ready_count,
		"activation": saves._scene_restore_activation, "reading": bridge.capture_reading_checkpoint(false)}))
	return false

func _title_menu() -> Node:
	get_node("/root/SceneRouter").goto_menu()
	for frame: int in 5: await get_tree().process_frame
	var menu: Node = get_tree().current_scene
	assert_not_null(menu, "production title must mount")
	return menu

func _current_art_proof() -> Dictionary:
	var caption: Node = _caption()
	var art_layer: Node
	for sibling: Node in caption.get_parent().get_children():
		if sibling.get_script() != null and sibling.get_script().resource_path == "res://scripts/ui/witnessed/WitnessedArtLayer.gd":
			art_layer = sibling
			break
	assert_not_null(art_layer, "shipped Dialogic layout mounts artwork")
	if art_layer == null: return {}
	var view: Control = art_layer._view
	assert_not_null(view)
	if view == null: return {}
	var placement: Dictionary = CURRENT_ART.get_scene_art("Day1")
	var expected_background := CURRENT_ART.get_asset_path(str(placement.background))
	var actual_background: Texture2D = view._background.texture
	assert_false(expected_background.is_empty(), "Day1 has authored background")
	assert_not_null(actual_background, "New Acc/Load hydrates art without a Settings change")
	if actual_background == null: return {}
	assert_eq(view._entry_id, "Day1", "art observes the adopted entry")
	assert_eq(actual_background.resource_path, expected_background)
	assert_true(view.is_visible_in_tree())
	assert_true(view._background.is_visible_in_tree())
	assert_gt(view._background.size.x, 0.0)
	assert_gt(view._background.size.y, 0.0)
	assert_true(view._dating_split, "shipped Day1 split panels are active")
	assert_true(caption._dating_overlay, "caption follows the same art publication")
	var portraits: Array[Dictionary] = []
	assert_eq(view._portrait_count, placement.portraits.size())
	for index: int in placement.portraits.size():
		var expected_path := CURRENT_ART.get_asset_path(str(placement.portraits[index]))
		var portrait: TextureRect = view._portraits[index]
		assert_not_null(portrait.texture, "Day1 portrait hydrates with background")
		if portrait.texture == null: return {}
		assert_eq(portrait.texture.resource_path, expected_path)
		assert_true(portrait.is_visible_in_tree())
		assert_gt(portrait.size.x, 0.0)
		assert_gt(portrait.size.y, 0.0)
		portraits.append({"expected_path": expected_path, "texture_path": portrait.texture.resource_path,
			"visible": portrait.is_visible_in_tree(), "size": [portrait.size.x, portrait.size.y]})
	return {"entry_id": view._entry_id, "expected_background": expected_background,
		"background_texture": actual_background.resource_path, "visible": view.is_visible_in_tree(),
		"background_visible": view._background.is_visible_in_tree(),
		"background_size": [view._background.size.x, view._background.size.y],
		"split_panels": view._dating_split, "caption_overlay": caption._dating_overlay, "portraits": portraits}

func _current_proof() -> Dictionary:
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return {}
	var snapshot: Dictionary = game.capture_run_snapshot_input()
	return {"scope": "current_shipped_title_authored_day1", "process_id": OS.get_process_id(),
		"window_size": [get_window().size.x, get_window().size.y],
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"user_dir": ProjectSettings.globalize_path("user://"),
		"registration_sha256": CURRENT_MANIFEST.scene_registration_fingerprint(),
		"entry_id": "Day1", "line_id": FIRST_LINE,
		"visible_text": _caption().caption_text.get_parsed_text(), "reading": reading.value,
		"art": _current_art_proof(),
		"gameplay": snapshot.gameplay, "scene": snapshot.scene,
		"command_receipts": snapshot.command_receipts,
		"profile": profile.get_profile_snapshot(),
		"slot_sha256": FileAccess.get_sha256(TITLE_SLOT) if FileAccess.file_exists(TITLE_SLOT) else "",
		"source_branch": snapshot.lifecycle.branch_id, "source_run": snapshot.lifecycle.run_id,
		"ready_count": ready_count}

func _assert_same_state(witness: Dictionary) -> void:
	var actual: Dictionary = _current_proof()
	for key: String in ["registration_sha256", "visible_text", "reading", "gameplay", "scene",
			"command_receipts", "profile", "slot_sha256", "source_run", "ready_count", "art"]:
		assert_eq(actual.get(key), witness.get(key), "current title preserves " + key)

func create_current_title_scene() -> void:
	assert_ne(DisplayServer.get_name(), "headless", "current title proof requires rendering")
	if DisplayServer.get_name() == "headless": return
	assert_false(FileAccess.file_exists(TITLE_SLOT), "creator requires an isolated fresh profile")
	if FileAccess.file_exists(TITLE_SLOT) or not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	if not _ok(profile.set_preference(&"preferences.reading.reveal_speed", "fast")): return
	if not _ok(get_node("/root/LocalizationManager").set_locale("en")): return
	var menu: Node = await _title_menu()
	if not is_instance_valid(menu): return
	await _screenshot("current-title-menu")
	if not await _press(menu.get_node_or_null("%NewAccButton")): return
	if not await _wait_first_caption(): return
	var before: Dictionary = _current_proof()
	await _screenshot("current-title-day1")
	var host: Node = get_tree().current_scene
	if not await _press(_controls(host, "CheckComputer")): return
	assert_true(host.is_computer_open(), "actual Computer control opens the computer")
	if not host.is_computer_open(): return
	assert_eq(bridge.capture_reading_checkpoint(false).value, before.reading)
	await _screenshot("current-title-computer")
	if not await _press(_controls(host, "Save")): return
	var pause: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(pause.can_save_backup(), str(pause.last_result))
	if not pause.can_save_backup(): return
	var app: Control = pause.surface._hosts[&"backup"]
	if not await _press(app.drawer_buttons.get("slot:1")): return
	if not await _press(app.action_buttons.get("save")): return
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and (app._in_operation or not FileAccess.file_exists(TITLE_SLOT)):
		await get_tree().process_frame
	if app._in_operation or not FileAccess.file_exists(TITLE_SLOT):
		fail_test("current title manual Save timeout: " + str(app.last_result))
		return
	if not _ok(app.last_result): return
	var written: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(TITLE_SLOT))
	if not _ok(written): return
	assert_eq(written.value.schema_version, 9)
	assert_eq(written.value.recovery_journal, [], "the real manual Save emits no fallback snapshots")
	await _screenshot("current-title-save")
	if not await _press(pause.surface._sheet_back): return
	assert_false(get_tree().paused)
	if not await _wait_first_caption(): return
	var proof: Dictionary = _current_proof()
	for key: String in ["reading", "gameplay", "scene", "command_receipts", "profile", "art"]:
		assert_eq(proof[key], before[key], "manual Save cannot change " + key)
	assert_eq(str(proof.slot_sha256).length(), 64)
	if not _write_json(TITLE_PROOF, proof): return
	_write_json("res://.godot/ci/current-title-scene-create-proof.json", proof)

func load_current_title_scene() -> void:
	assert_ne(DisplayServer.get_name(), "headless", "current title proof requires rendering")
	if DisplayServer.get_name() == "headless": return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(TITLE_PROOF))
	if not _ok(parsed): return
	var witness: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), witness.process_id, "Load must use a fresh OS process")
	assert_eq(ProjectSettings.globalize_path("user://"), witness.user_dir)
	assert_eq(FileAccess.get_sha256(TITLE_SLOT), witness.slot_sha256)
	if not _start_services(): return
	assert_eq(profile.get_profile_snapshot(), witness.profile)
	var menu: Node = await _title_menu()
	if not is_instance_valid(menu): return
	if not await _press(menu.get_node_or_null("%LogInButton")): return
	var app: Control = menu._backup_app_instance
	assert_not_null(app, "title LogIn mounts the actual Backup app")
	if not is_instance_valid(app): return
	if not await _press(app.drawer_buttons.get("slot:1")): return
	if not await _press(app.action_buttons.get("load")): return
	if is_instance_valid(app) and is_instance_valid(app.confirmation):
		if not await _press(app.confirmation.confirm_button): return
	if not await _wait_first_caption(): return
	_assert_same_state(witness)
	assert_ne(game.capture_run_snapshot_input().lifecycle.branch_id, witness.source_branch)
	await _screenshot("current-title-loaded-day1")
	var host: Node = get_tree().current_scene
	if not await _press(_controls(host, "CheckComputer")): return
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return
	await _screenshot("current-title-loaded-computer")
	if not await _press(_controls(host, "CheckComputer")): return
	assert_false(host.is_computer_open())
	_assert_same_state(witness)
	var proof: Dictionary = _current_proof()
	proof["creator_process_id"] = witness.process_id
	proof["destination_branch"] = proof.source_branch
	proof.source_branch = witness.source_branch
	_write_json("res://.godot/ci/current-title-scene-load-proof.json", proof)
