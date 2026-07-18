extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FAKE_OPS := preload("res://tests/support/FakeFileOps.gd")
const PROFILE_SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")

func before_all() -> void:
	var profile := get_node("/root/ProfileManager")
	if not bool(profile.get("_initialized")):
		assert_true(profile.initialize(STORAGE.new("settings-scene-tests", FAKE_OPS.new())).get("ok", false))
	var localization := get_node("/root/LocalizationManager")
	if localization.get_readiness() == &"uninitialized":
		assert_true(localization.initialize(profile).get("ok", false))

func test_settings_controller_and_scenes_exist_with_shared_contract() -> void:
	var loaded := PROBE.load_script("res://scripts/ui/SettingsPanelController.gd")
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false): return
	var controller: RefCounted = loaded["value"].new()
	assert_true(controller.has_method("bind"))
	assert_true(controller.has_method("unbind"))
	for path in ["res://scenes/menu/Setting.tscn", "res://scenes/apps/SettingsApp.tscn"]:
		var scene: PackedScene = load(path)
		assert_not_null(scene, path)
		var instance: Node = autofree(scene.instantiate())
		assert_not_null(instance.get_node_or_null("LocalePresentationRoot"), path)
		assert_not_null(instance.find_child("LanguageStatus", true, false), path)

func test_both_settings_hosts_share_languages_skip_modes_and_confirmed_resets() -> void:
	for path in ["res://scenes/menu/Setting.tscn", "res://scenes/apps/SettingsApp.tscn"]:
		var instance: Node = load(path).instantiate()
		add_child(instance)
		var language: OptionButton = instance.find_child("LanguageOption", true, false)
		assert_eq(language.item_count, 3, path)
		assert_true(language.get_item_text(1).ends_with("[draft]"), path)
		var skip: OptionButton = instance.find_child("SkipModeOption", true, false)
		assert_not_null(skip, path)
		assert_eq([skip.get_item_metadata(0), skip.get_item_metadata(1)], ["read_only", "all_text"])
		var profile := get_node("/root/ProfileManager")
		assert_true(profile.set_preference(&"preferences.accessibility.high_contrast", true).get("ok", false))
		var reset_button: Button = instance.find_child("PreferencesResetButton", true, false)
		var confirmation: ConfirmationDialog = instance.find_child("PreferencesResetConfirmation", true, false)
		assert_not_null(reset_button, path)
		assert_not_null(confirmation, path)
		reset_button.pressed.emit()
		assert_true(profile.get_preference(&"preferences.accessibility.high_contrast"), path)
		confirmation.confirmed.emit()
		assert_false(profile.get_preference(&"preferences.accessibility.high_contrast"), path)
		instance.free()

func test_shared_controller_exposes_every_nonlanguage_preference_leaf() -> void:
	var instance: Node = load("res://scenes/menu/Setting.tscn").instantiate()
	add_child(instance)
	var controller: RefCounted = instance.get("_controller")
	var controls: Dictionary = controller.get("_controls")
	var expected: Array = PROFILE_SCHEMA.PREFERENCE_DEFAULTS.keys()
	expected.erase("preferences.language")
	assert_eq(controls.size(), expected.size())
	for path in expected:
		assert_true(controls.has(StringName(path)), path)
	var profile := get_node("/root/ProfileManager")
	var music_slider: HSlider = controls[&"preferences.audio.music_volume"]
	music_slider.value = 0.25
	assert_eq(profile.get_preference(&"preferences.audio.music_volume"), 0.25)
	var skip: OptionButton = controls[&"preferences.dialogue.skip_mode"]
	skip.select(1)
	skip.item_selected.emit(1)
	assert_eq(profile.get_preference(&"preferences.dialogue.skip_mode"), "all_text")
	var colorblind: OptionButton = controls[&"preferences.accessibility.colorblind_mode"]
	colorblind.select(2)
	colorblind.item_selected.emit(2)
	assert_eq(profile.get_preference(&"preferences.accessibility.colorblind_mode"), "deuteranopia")
	instance.free()

func test_each_reset_is_inert_until_its_own_confirmation() -> void:
	var instance: Node = load("res://scenes/menu/Setting.tscn").instantiate()
	add_child(instance)
	var profile := get_node("/root/ProfileManager")
	assert_true(profile.mark_line_visited("settings-reset-line").get("ok", false))
	assert_true(profile.unlock_ending("ending.alone", "settings-reset-gallery").get("ok", false))
	assert_true(profile.set_preference(&"preferences.display.fullscreen", true).get("ok", false))
	_assert_reset_requires_confirmation(instance, "VisitedHistory", func() -> bool: return profile.is_line_visited("settings-reset-line"))
	assert_false(profile.is_line_visited("settings-reset-line"))
	_assert_reset_requires_confirmation(instance, "Gallery", func() -> bool: return profile.has_gallery_unlock("ending.alone"))
	assert_false(profile.has_gallery_unlock("ending.alone"))
	_assert_reset_requires_confirmation(instance, "Preferences", func() -> bool: return profile.get_preference(&"preferences.display.fullscreen"))
	assert_false(profile.get_preference(&"preferences.display.fullscreen"))
	assert_true(profile.set_preference(&"preferences.accessibility.high_contrast", true).get("ok", false))
	_assert_reset_requires_confirmation(instance, "EntireProfile", func() -> bool: return profile.get_preference(&"preferences.accessibility.high_contrast"))
	assert_false(profile.get_preference(&"preferences.accessibility.high_contrast"))
	instance.free()

func _assert_reset_requires_confirmation(instance: Node, prefix: String, still_present: Callable) -> void:
	var button: Button = instance.find_child("%sResetButton" % prefix, true, false)
	var confirmation: ConfirmationDialog = instance.find_child("%sResetConfirmation" % prefix, true, false)
	assert_not_null(button, prefix)
	assert_not_null(confirmation, prefix)
	button.pressed.emit()
	assert_true(still_present.call(), "%s mutated before confirmation" % prefix)
	confirmation.confirmed.emit()
	confirmation.hide()
