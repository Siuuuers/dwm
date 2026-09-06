extends "res://addons/gut/test.gd"

const OWNERS := preload("res://tests/unit/test_settings_controls_reset.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const CONTENT := preload("res://scenes/shared/SettingsContent.tscn")
const REDUCED := &"preferences.accessibility.reduced_motion"
const SHAKE := &"preferences.accessibility.screen_shake"
var _surface: SubViewport
var _fixtures: Array[Dictionary] = []


func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(800, 656)
	_surface.gui_embed_subwindows = true
	add_child_autofree(_surface)


func after_each() -> void:
	for fixture: Dictionary in _fixtures:
		for id: String in ["content", "localization", "profile"]:
			if is_instance_valid(fixture[id]):
				fixture[id].free()
	_fixtures.clear()


func _fixture(locale: String = "en", percent: int = 100) -> Dictionary:
	var ops := OWNERS.FILES.new()
	var profile := OWNERS.PROFILE.new()
	add_child(profile)
	assert_true(profile.initialize(OWNERS.STORAGE.new("settings-motion.memory", ops)).get("ok", false))
	var localization := LOCALIZATION.new()
	add_child(localization)
	assert_true(localization.initialize(profile).get("ok", false))
	assert_true(localization.set_locale(locale).get("ok", false))
	assert_true(profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false))
	var content: Control = CONTENT.instantiate()
	content.configure_services({"profile": profile, "localization": localization, "audio": null, "tts": null, "volume": null, "input": null})
	_surface.add_child(content)
	content.select_category("accessibility")
	var fixture := {"profile": profile, "localization": localization, "content": content, "ops": ops}
	_fixtures.append(fixture)
	return fixture


func _settle() -> void:
	for frame: int in range(4):
		await get_tree().process_frame


func test_reduced_motion_retains_every_shake_choice_across_locales_and_sizes() -> void:
	for locale: String in ["en", "zh_CN", "zh_HK"]:
		for percent: int in [100, 125, 150]:
			var f := _fixture(locale, percent)
			var content: Control = f.content
			var controller: RefCounted = content.get_controller()
			var shake: OptionButton = content.control_for(SHAKE)
			await _settle()
			for choice: String in ["off", "low", "normal"]:
				assert_true((await controller.commit_preference(SHAKE, choice)).get("ok", false))
				var expected: Dictionary = f.profile.get_profile_snapshot()
				expected.preferences.accessibility.reduced_motion = true
				assert_true((await controller.commit_preference(REDUCED, true)).get("ok", false))
				assert_eq(f.profile.get_profile_snapshot(), expected, "Only Reduced Motion changes")
				assert_eq(shake.get_selected_metadata(), choice, "Stored choice remains Selected")
				assert_true(shake.disabled)
				assert_eq(shake.focus_mode, Control.FOCUS_NONE)
				assert_eq(content.statuses[SHAKE].text, f.localization.t("settings.status.reduced_motion_on"))
				assert_ne(content.statuses[SHAKE].text, "settings.status.reduced_motion_on")
				assert_true((await controller.commit_preference(REDUCED, false)).get("ok", false))
				assert_eq(f.profile.get_preference(SHAKE), choice)
				assert_false(shake.disabled)
				assert_eq(shake.focus_mode, Control.FOCUS_ALL)
				assert_eq(content.statuses[SHAKE].text, "")
			content.free()


func test_motion_change_retires_open_dropdown_and_rejects_queued_and_direct_mutation() -> void:
	var f := _fixture()
	var content: Control = f.content
	var shake: OptionButton = content.control_for(SHAKE)
	await _settle()
	shake.grab_focus()
	shake.show_popup()
	assert_true(shake.get_popup().visible)
	# Another visible preference publisher may commit while this native popup is open.
	assert_true(f.profile.set_preference(REDUCED, true).get("ok", false))
	assert_false(shake.get_popup().visible, "Obsolete native selection closes synchronously")
	await _settle()
	assert_eq(_surface.gui_get_focus_owner(), content.control_for(REDUCED), "Focus returns to the controlling action")
	var before: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	shake.select(2)
	shake.item_selected.emit(2)
	assert_false((await content.get_controller().commit_preference(SHAKE, "normal")).get("ok", true))
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(shake.get_selected_metadata(), "low", "Refused selection restores the remembered value")
	assert_true((await content.get_controller().commit_preference(REDUCED, false)).get("ok", false))
	assert_eq(f.profile.get_preference(SHAKE), "low", "Refused commands do not queue on re-enabling")
	assert_true((await content.get_controller().commit_preference(SHAKE, "normal")).get("ok", false))
	assert_eq(f.profile.get_preference(SHAKE), "normal", "Fresh input can change the restored action")


func test_failed_motion_commit_retains_profile_and_presentation() -> void:
	var f := _fixture()
	var content: Control = f.content
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	f.ops.fail_after(f.ops.operation_count() + 1)
	assert_false((await content.get_controller().commit_preference(REDUCED, true)).get("ok", true))
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_false(content.control_for(SHAKE).disabled)
	assert_false(content.control_for(REDUCED).button_pressed)


func test_hidden_motion_changes_do_not_take_focus() -> void:
	var f := _fixture()
	var content: Control = f.content
	await _settle()
	content.hide()
	var other := Button.new()
	_surface.add_child(other)
	other.grab_focus()
	assert_true(f.profile.set_preference(REDUCED, true).get("ok", false))
	await _settle()
	assert_true(other.has_focus(), "Hidden Settings must not reclaim focus after publication")
	other.free()
