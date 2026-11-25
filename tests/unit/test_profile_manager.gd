extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const ROOT := "profile-tests/root"

var _schema: Script
var _manager_script: Script
var _storage_script: Script
var _fake_ops_script: Script
var _gate_script: Script

func before_all() -> void:
	_schema = _load("res://scripts/profile/ProfileSchema.gd")
	_manager_script = _load("res://autoload/ProfileManager.gd")
	_storage_script = _load("res://scripts/infrastructure/storage/JsonFileStorage.gd")
	_fake_ops_script = _load("res://tests/support/FakeFileOps.gd")
	_gate_script = _load("res://tests/support/FakeApplicationMutationGate.gd")

func _load(path: String) -> Script:
	var result := PROBE.load_script(path)
	assert_true(result.get("ok", false), "%s: %s" % [path, result])
	return result.get("value")

func _new_manager() -> Dictionary:
	var ops: RefCounted = _fake_ops_script.new()
	var storage: RefCounted = _storage_script.new(ROOT, ops)
	var manager: Node = autofree(_manager_script.new())
	var initialized: Dictionary = manager.call(&"initialize", storage)
	assert_true(initialized.get("ok", false), str(initialized))
	return {"manager": manager, "ops": ops, "storage": storage}

func _configure_lines(manager: Node, ids: Array[String]) -> void:
	var lines: Array[Dictionary] = []
	for line_id: String in ids:
		lines.append({"line_id": line_id})
	var configured: Dictionary = manager.call(&"configure_line_registry", {"reply_lines": lines})
	assert_true(configured.get("ok", false), str(configured))


func test_defaults_are_schema_valid_and_exact() -> void:
	var profile: Dictionary = _schema.call(&"make_defaults")
	var result: Dictionary = _schema.call(&"validate", profile)
	assert_true(result.get("ok", false), str(result))
	assert_eq(profile["schema_version"], 10)
	assert_eq(profile["preferences"]["reading"]["skip_mode"], "read_only")
	assert_eq(profile["gallery_transaction_receipts"], {})
	assert_eq(profile["migration_receipts"].size(), 3)
	profile.dialogue_library.checkpoints.append("edited")
	profile.controls_bindings.game_quick_save.keyboard.physical_keycode = KEY_A
	var fresh: Dictionary = _schema.call(&"make_defaults")
	assert_eq(fresh.dialogue_library.checkpoints, [])
	assert_eq(fresh.controls_bindings.game_quick_save.keyboard.physical_keycode, KEY_F5)

func test_silent_rollback_restores_profile_retained_before_adoption() -> void:
	var manager: Node = _new_manager().manager
	var before: Dictionary = manager.get_profile_snapshot()
	var candidate: Dictionary = manager.get_profile_snapshot()
	candidate.preferences.reading.skip_mode = "all_text"
	assert_true(manager.apply_restore_silent({"profile": candidate}).ok)
	assert_eq(manager.get_preference(&"preferences.reading.skip_mode"), "all_text")
	assert_true(manager.rollback_restore_silent({}).ok)
	assert_eq(manager.get_profile_snapshot(), before)

func test_display_default_preserves_saved_choices_until_explicit_reset() -> void:
	var fixture := _new_manager()
	var manager: Node = fixture.manager
	var path := &"preferences.display.window_mode"
	assert_eq(manager.get_preference(path), "borderless", "A fresh profile uses borderless")
	for mode: String in ["windowed", "borderless"]:
		assert_true(manager.set_preference(path, mode).get("ok", false))
		var restarted: Node = autofree(_manager_script.new())
		var files: RefCounted = _fake_ops_script.new(fixture.ops.snapshot_persisted())
		assert_true(restarted.initialize(_storage_script.new(ROOT, files)).get("ok", false))
		assert_eq(restarted.get_preference(path), mode, "Existing display choice survives restart")
		assert_true(restarted.set_preference(path, "windowed").get("ok", false))
		assert_true(restarted.reset_preferences().get("ok", false))
		assert_eq(restarted.get_preference(path), "borderless", "Preferences reset uses current defaults")
		assert_true(restarted.set_preference(path, "windowed").get("ok", false))
		assert_true(restarted.reset_entire_profile().get("ok", false))
		assert_eq(restarted.get_preference(path), "borderless", "Entire-profile reset uses current defaults")

func test_schema_rejects_unknown_nested_fields_bad_types_and_aliases() -> void:
	var profile: Dictionary = _schema.call(&"make_defaults")
	profile["preferences"]["audio"]["unknown"] = true
	assert_false(_schema.call(&"validate", profile).get("ok", true))
	profile = _schema.call(&"make_defaults")
	profile["preferences"]["audio"]["music_volume"] = 1
	assert_false(_schema.call(&"validate", profile).get("ok", true), "volume must remain TYPE_FLOAT")
	profile = _schema.call(&"make_defaults")
	var validated: Dictionary = _schema.call(&"validate", profile)
	profile["preferences"]["audio"]["music_volume"] = 0.1
	assert_eq(validated["value"]["preferences"]["audio"]["music_volume"], 0.8)


func test_previous_profile_documents_are_refused_without_rewriting_history() -> void:
	var old: Dictionary = _schema.make_defaults()
	old.visited_line_ids = ["read.in.previous.build"]
	old.erase("displayed_artwork_ids")
	old.erase("dialogue_library")
	for version: int in [10, 9]:
		old.schema_version = version
		if version == 9: old.erase("witnessed_caption_variants")
		var files := {ROOT + "/profile.json": JSON.stringify(old).to_utf8_buffer()}
		var ops: RefCounted = _fake_ops_script.new(files)
		var manager: Node = autofree(_manager_script.new())
		assert_false(manager.initialize(_storage_script.new(ROOT, ops)).ok)
		assert_eq(ops.snapshot_persisted(), files)


func test_manager_initializes_once_and_uses_detached_snapshots() -> void:
	var fixture := _new_manager()
	var manager: Node = fixture["manager"]
	assert_eq(manager.call(&"initialize", fixture["storage"]).get("code"), &"already_initialized")
	var snapshot: Dictionary = manager.call(&"get_profile_snapshot")
	var unchanged: Dictionary = manager.set_preferences({})
	assert_true(unchanged.unchanged)
	unchanged.value.visited_line_ids.append("edited")
	assert_false(manager.is_line_visited("edited"))
	snapshot["preferences"]["audio"]["music_volume"] = 0.1
	assert_eq(manager.call(&"get_preference", &"preferences.audio.music_volume"), 0.8)

func test_flat_fully_qualified_preference_batch_is_atomic() -> void:
	var manager: Node = _new_manager()["manager"]
	var prepared: Dictionary = manager.call(&"prepare_preferences", {
		&"preferences.audio.music_volume": 0.5,
		&"preferences.reading.skip_mode": "all_text",
	})
	assert_true(prepared.get("ok", false), str(prepared))
	assert_eq(prepared["changed_paths"], [&"preferences.audio.music_volume", &"preferences.reading.skip_mode"])
	assert_eq(manager.call(&"prepare_preferences", {"preferences.audio.music_volume": 0.2}).get("code"), &"invalid_preference_path")
	assert_eq(manager.call(&"prepare_preferences", {&"audio.music_volume": 0.2}).get("code"), &"invalid_preference_path")
	assert_eq(manager.call(&"prepare_preferences", {&"preferences.language.primary_locale_id": "zh_HK", &"preferences.audio.music_volume": 0.2}).get("code"), &"managed_preference")
	assert_eq(manager.call(&"get_preference", &"preferences.audio.music_volume"), 0.8)

func test_locale_candidate_commits_deferred_and_publishes_exactly_once() -> void:
	var manager: Node = _new_manager()["manager"]
	var events: Array = []
	manager.preference_changed.connect(func(path: StringName, value: Variant) -> void: events.append([path, value]))
	var prepared: Dictionary = manager.call(&"prepare_locale_preference", "zh_HK")
	assert_true(prepared.get("ok", false), str(prepared))
	var committed: Dictionary = manager.call(&"commit_prepared_profile", prepared["value"], true)
	assert_true(committed.get("ok", false), str(committed))
	prepared.value.preferences.language.primary_locale_id = "en"
	assert_eq(manager.get_preference(&"preferences.language.primary_locale_id"), "zh_HK")
	assert_eq(events, [])
	var publication_id: String = committed["value"]["publication_id"]
	assert_true(manager.call(&"publish_deferred_profile_signals", publication_id).get("ok", false))
	assert_eq(events, [[&"preferences.language.primary_locale_id", "zh_HK"]])
	assert_eq(manager.call(&"publish_deferred_profile_signals", publication_id).get("code"), &"unknown_publication")

func test_visited_publication_orders_only_added_and_removed_lines() -> void:
	var manager: Node = _new_manager()["manager"]
	var candidate: Dictionary = manager.get_profile_snapshot()
	candidate.visited_line_ids = ["留", "a", "é"]
	assert_true(manager.commit_prepared_profile(candidate).ok)
	var events: Array = []
	manager.visited_history_changed.connect(func(id: String, visited: bool) -> void: events.append([id, visited]))
	candidate.visited_line_ids = ["猫", "é", "Z"]
	var committed: Dictionary = manager.commit_prepared_profile(candidate, true)
	assert_true(committed.ok)
	assert_eq(events, [])
	assert_true(manager.publish_deferred_profile_signals(committed.value.publication_id).ok)
	assert_eq(events, [["Z", true], ["a", false], ["猫", true], ["留", false]])

func test_prepared_gallery_transaction_is_idempotent_and_conflicts_fail() -> void:
	var manager: Node = _new_manager()["manager"]
	var prepared: Dictionary = manager.call(&"prepare_ending_unlock", "ending.alone", "run-1-ending")
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(prepared["value"]["requires_commit"])
	var committed: Dictionary = manager.call(&"commit_prepared_profile", prepared["value"]["candidate"], true)
	var publication_id: String = committed["value"]["publication_id"]
	var repeat: Dictionary = manager.call(&"prepare_ending_unlock", "ending.alone", "run-1-ending")
	assert_false(repeat["value"]["requires_commit"])
	assert_eq(repeat["value"]["pending_publication_id"], publication_id)
	assert_eq(manager.call(&"prepare_ending_unlock", "ending.priscilla.dark", "run-1-ending").get("code"), &"gallery_transaction_conflict")

func test_gallery_and_entire_reset_retain_internal_ledgers() -> void:
	var manager: Node = _new_manager()["manager"]
	assert_true(manager.call(&"unlock_ending", "ending.alone", "transaction-retained").get("ok", false))
	assert_true(manager.call(&"reset_gallery").get("ok", false))
	var snapshot: Dictionary = manager.call(&"get_profile_snapshot")
	assert_eq(snapshot["gallery_unlocks"], [])
	assert_true(snapshot["gallery_transaction_receipts"].has("transaction-retained"))
	assert_true(manager.call(&"reset_entire_profile").get("ok", false))
	snapshot = manager.call(&"get_profile_snapshot")
	assert_true(snapshot["gallery_transaction_receipts"].has("transaction-retained"))


func test_preference_reset_publishes_leaf_changes_before_one_summary() -> void:
	var manager: Node = _new_manager()["manager"]
	assert_true(manager.call(&"set_preferences", {
		&"preferences.audio.music_volume": 0.2,
		&"preferences.reading.reveal_speed": "slow",
	}).get("ok", false))
	var events: Array = []
	manager.preference_changed.connect(func(path: StringName, _value: Variant) -> void: events.append(["preference", path]))
	manager.profile_reset.connect(func(section: StringName) -> void: events.append(["reset", section]))
	assert_true(manager.call(&"reset_preferences").get("ok", false))
	assert_eq(events, [
		["preference", &"preferences.audio.music_volume"],
		["preference", &"preferences.reading.reveal_speed"],
		["reset", &"preferences"],
	])
	assert_eq(manager.call(&"get_preference", &"preferences.audio.music_volume"), 0.8)
	assert_eq(manager.call(&"get_preference", &"preferences.reading.reveal_speed"), "normal")

func test_mutation_gate_configuration_is_identity_stable_and_side_effect_free() -> void:
	var manager: Node = autofree(_manager_script.new())
	var gate: RefCounted = _gate_script.new()
	var first: Dictionary = manager.call(&"configure_mutation_gate", gate)
	assert_true(first.get("ok", false), str(first))
	assert_false(first["value"]["already_configured"])
	var same: Dictionary = manager.call(&"configure_mutation_gate", gate)
	assert_true(same["value"]["already_configured"])
	assert_eq(manager.call(&"configure_mutation_gate", null).get("code"), &"invalid_mutation_gate")
	assert_eq(manager.call(&"configure_mutation_gate", _gate_script.new()).get("code"), &"mutation_gate_already_configured")

func test_profile_schema_registers_observation_not_true() -> void:
	var schema: Script = load("res://scripts/profile/ProfileSchema.gd")
	assert_true("ending.priscilla.observation" in schema.ENDING_IDS)
	assert_true("ending.lavinia.observation" in schema.ENDING_IDS)
	assert_false("ending.priscilla.true" in schema.ENDING_IDS, "retired .true is gone")
	assert_false("ending.sylvia.true" in schema.ENDING_IDS, "sylvia.true is retired")


func test_visited_history_is_global_and_idempotent() -> void:
	var manager: Node = _new_manager()["manager"]
	_configure_lines(manager, ["line.contact.ordinary.lavinia.day1.reply.a"])
	assert_false(manager.call(&"is_line_visited", "line.contact.ordinary.lavinia.day1.reply.a"), "unread by default")
	var first: Dictionary = manager.call(&"mark_line_visited", "line.contact.ordinary.lavinia.day1.reply.a")
	assert_true(first.get("ok", false), str(first))
	assert_true(manager.call(&"is_line_visited", "line.contact.ordinary.lavinia.day1.reply.a"), "now visited")
	var again: Dictionary = manager.call(&"mark_line_visited", "line.contact.ordinary.lavinia.day1.reply.a")
	assert_true(again.get("ok", false), "re-marking is safe")
	assert_true(again.get("unchanged", false), "and reports no change")

func test_visited_history_survives_a_new_run_and_only_its_own_reset_clears_it() -> void:
	var fixture := _new_manager()
	var manager: Node = fixture["manager"]
	_configure_lines(manager, ["dating.solo.sylvia.day3.line.1"])
	manager.call(&"mark_line_visited", "dating.solo.sylvia.day3.line.1")
	# A new run must NOT touch visited ids or skip mode (Plan-05 Task 4).
	var snapshot: Dictionary = manager.call(&"get_profile_snapshot")
	assert_true("dating.solo.sylvia.day3.line.1" in snapshot["visited_line_ids"], "persisted in the profile")
	var mode_before: Variant = manager.call(&"get_preference", &"preferences.reading.skip_mode")
	var reset: Dictionary = manager.call(&"reset_visited_history")
	assert_true(reset.get("ok", false), str(reset))
	assert_false(manager.call(&"is_line_visited", "dating.solo.sylvia.day3.line.1"), "explicit reset clears visited ids")
	assert_eq(manager.call(&"get_preference", &"preferences.reading.skip_mode"), mode_before,
		"a visited-history reset never changes skip mode")

func test_visited_reset_leaves_other_profile_state_intact() -> void:
	var manager: Node = _new_manager()["manager"]
	_configure_lines(manager, ["line.contact.ordinary.lavinia.day1.reply.b"])
	manager.call(&"prepare_preferences", {&"preferences.audio.music_volume": 0.42})
	var volume_before: Variant = manager.call(&"get_preference", &"preferences.audio.music_volume")
	manager.call(&"mark_line_visited", "line.contact.ordinary.lavinia.day1.reply.b")
	manager.call(&"reset_visited_history")
	assert_eq(manager.call(&"get_preference", &"preferences.audio.music_volume"), volume_before,
		"resetting visited history touches nothing else")

func test_font_style_default_and_explicit_values_remain_strict() -> void:
	var f := _new_manager()
	var first: Node = f.manager
	assert_eq(first.get_preference(&"preferences.accessibility.font_style"), "pixel")
	assert_eq(first.set_preference(&"preferences.accessibility.font_style", "readable").get("code"), &"managed_preference")
	var candidate: Dictionary = first.prepare_font_style_preference("readable")
	assert_true(candidate.get("ok", false), str(candidate))
	assert_eq(first.get_preference(&"preferences.accessibility.font_style"), "pixel", "Preparation is inert")
	assert_true(first.commit_prepared_profile(candidate.value).get("ok", false))
	var restarted: Node = autofree(_manager_script.new())
	assert_true(restarted.initialize(f.storage).get("ok", false))
	assert_eq(restarted.get_preference(&"preferences.accessibility.font_style"), "readable")
	assert_true(restarted.reset_preferences().get("ok", false))
	assert_eq(restarted.get_preference(&"preferences.accessibility.font_style"), "pixel")
	for bad: Variant in [null, true, 100, "serif"]:
		var malformed: Dictionary = _schema.make_defaults()
		malformed.preferences.accessibility.font_style = bad
		assert_false(_schema.validate(malformed).get("ok", true), "Invalid style must not be repaired: " + str(bad))

func test_panel_width_preferences_are_hidden_and_reject_invalid_ranges_steps_and_types() -> void:
	var registry := _load("res://scripts/settings/SettingsPreferenceRegistry.gd")
	var paths := [&"preferences.display.angela_panel_width", &"preferences.display.dating_solo_portrait_width", &"preferences.display.dating_group_portrait_width"]
	for record: Dictionary in registry.visible_records(&"display"):
		assert_false(record.path in paths, "The divider owns width adjustment; Settings gains no extra rows")
	for path: StringName in paths:
		assert_true(registry.is_player_writable(path))
		for valid: int in [320, 400, 480]:
			assert_true(_schema.validate_preference(path, valid).get("ok", false), "%s: %s" % [path, valid])
		for invalid: Variant in [null, true, "400", 400.0, -1, 318, 321, 642]:
			assert_false(_schema.validate_preference(path, invalid).get("ok", true), "%s: %s" % [path, invalid])
	assert_false(_schema.validate_preference(paths[0], 0).get("ok", true))
	assert_false(_schema.validate_preference(paths[0], 482).get("ok", true))
	for path: StringName in [paths[1], paths[2]]:
		assert_true(_schema.validate_preference(path, 0).get("ok", false), "Zero retains inheritance")
		assert_true(_schema.validate_preference(path, 640).get("ok", false))
	assert_true(_schema.validate_preference(paths[1], 402).get("ok", false))
	assert_false(_schema.validate_preference(paths[2], 402).get("ok", true), "Two portrait centres need four-pixel width steps")


func test_solo_group_and_desktop_widths_are_independent_and_survive_restart() -> void:
	var fixture := _new_manager()
	var manager: Node = fixture.manager
	assert_true(manager.set_preference(&"preferences.display.angela_panel_width", 402).get("ok", false))
	assert_true(manager.set_preference(&"preferences.display.dating_solo_portrait_width", 562).get("ok", false))
	assert_eq(manager.get_preference(&"preferences.display.dating_group_portrait_width"), 0, "A solo adjustment leaves group inheritance intact")
	assert_true(manager.set_preference(&"preferences.display.dating_group_portrait_width", 600).get("ok", false))
	assert_true(manager.set_preference(&"preferences.display.angela_panel_width", 360).get("ok", false))
	var restarted: Node = autofree(_manager_script.new())
	assert_true(restarted.initialize(_storage_script.new(ROOT, _fake_ops_script.new(fixture.ops.snapshot_persisted()))).get("ok", false))
	assert_eq(restarted.get_preference(&"preferences.display.angela_panel_width"), 360)
	assert_eq(restarted.get_preference(&"preferences.display.dating_solo_portrait_width"), 562)
	assert_eq(restarted.get_preference(&"preferences.display.dating_group_portrait_width"), 600)


func test_failed_first_dating_width_write_preserves_inheritance_and_publishes_no_change() -> void:
	var fixture := _new_manager()
	var manager: Node = fixture.manager
	assert_true(manager.set_preference(&"preferences.display.angela_panel_width", 400).get("ok", false))
	var before_profile: Dictionary = manager.get_profile_snapshot()
	var before_bytes: Dictionary = fixture.ops.snapshot_persisted()
	var changes: Array = []
	manager.preference_changed.connect(func(path: StringName, _value: Variant) -> void: changes.append(path))
	fixture.ops.fail_after(fixture.ops.operation_count() + 1)
	var result: Dictionary = manager.set_preference(&"preferences.display.dating_solo_portrait_width", 560)
	assert_false(result.get("ok", true), str(result))
	assert_eq(manager.get_preference(&"preferences.display.dating_solo_portrait_width"), 0, "A failed save never becomes an override")
	assert_eq(manager.get_profile_snapshot(), before_profile)
	assert_eq(fixture.ops.snapshot_persisted(), before_bytes)
	assert_eq(changes, [])


func test_preferences_reset_restores_panel_width_inheritance() -> void:
	var fixture := _new_manager()
	var manager: Node = fixture.manager
	assert_true(manager.set_preferences({&"preferences.display.angela_panel_width": 400,
		&"preferences.display.dating_solo_portrait_width": 562,
		&"preferences.display.dating_group_portrait_width": 600}).get("ok", false))
	assert_true(manager.reset_preferences().get("ok", false))
	assert_eq(manager.get_preference(&"preferences.display.angela_panel_width"), 480)
	assert_eq(manager.get_preference(&"preferences.display.dating_solo_portrait_width"), 0)
	assert_eq(manager.get_preference(&"preferences.display.dating_group_portrait_width"), 0)

func test_every_reset_refuses_cleanly_before_initialization() -> void:
	var manager: Node = autofree(_manager_script.new())
	for method: StringName in [&"reset_preferences", &"reset_controls", &"reset_visited_history",
			&"reset_gallery", &"reset_entire_profile"]:
		var result: Dictionary = manager.call(method)
		assert_false(result.get("ok", true), String(method))
		assert_eq(result.get("code"), &"not_initialized", String(method))


func test_deferred_raw_mapping_publication_survives_as_inert_compatibility_signal() -> void:
	var manager: Node = autofree(_manager_script.new())
	assert_true(manager.initialize(_storage_script.new(ROOT, _fake_ops_script.new())).get("ok", false))
	var live_before: Dictionary = manager.get_input_mappings()
	var input_events: Array[StringName] = []
	var controls_events: Array[bool] = []
	manager.input_mappings_changed.connect(func(action: StringName) -> void: input_events.append(action))
	manager.controls_bindings_changed.connect(func() -> void: controls_events.append(true))
	var candidate: Dictionary = manager.get_profile_snapshot()
	candidate.input_mappings["game_open_log"] = [{"kind": "key", "physical_keycode": KEY_F6,
		"keycode": 0, "shift": false, "alt": false, "ctrl": false, "meta": false}]
	var committed: Dictionary = manager.commit_prepared_profile(candidate, true)
	assert_true(committed.get("ok", false), str(committed))
	assert_eq(input_events, [], "a deferred commit publishes nothing early")
	assert_eq(manager.get_input_mappings(), live_before,
		"retained raw provenance never becomes the active Controls map")
	assert_true(manager.publish_deferred_profile_signals(committed.value.publication_id).get("ok", false))
	assert_eq(input_events, [&"game_open_log"])
	assert_eq(controls_events, [], "unchanged canonical Controls do not publish a false change")
