extends "res://addons/gut/test.gd"
## Real reset sheets and Settings controller; all profile/audio writes end in existing doubles.

const FIXTURES := preload("res://tests/scene/test_settings_localization_scene.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FAKE_OPS := preload("res://tests/support/FakeFileOps.gd")
const CONTENT := preload("res://scenes/shared/SettingsContent.tscn")
const RESET_IDS := ["preferences", "visited_history", "gallery", "entire_profile"]
const LOCALES := ["en", "zh_CN", "zh_HK"]
const SIZES := [100, 125, 150]

var _surface: SubViewport
var _original_locale := "en"


class ResetProfile extends FIXTURES.FakeSettingsProfile:
	func reset_visited_history(expected_revision: int = -1) -> Dictionary:
		direct_resets.append("reset_visited_history")
		reset_revisions.append(expected_revision)
		return {"ok": true}
	func reset_gallery(expected_revision: int = -1) -> Dictionary:
		direct_resets.append("reset_gallery")
		reset_revisions.append(expected_revision)
		return {"ok": true}


class DelayedStopAudio extends FIXTURES.FakeSettingsAudio:
	signal stop_ready()
	func stop_settings_preview(handle: Variant) -> Dictionary:
		stops.append(handle)
		await stop_ready
		return {"ok": true, "code": &"ok"}


func before_all() -> void:
	var profile := get_node("/root/ProfileManager")
	if not bool(profile.get("_initialized")):
		assert_true(profile.initialize(STORAGE.new("settings-reset-sheet-tests", FAKE_OPS.new())).get("ok", false))
	var localization := get_node("/root/LocalizationManager")
	if localization.get_readiness() == &"uninitialized":
		assert_true(localization.initialize(profile).get("ok", false))
	_original_locale = localization.get_locale()


func after_all() -> void:
	assert_true(get_node("/root/LocalizationManager").set_locale(_original_locale).get("ok", false))


func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(800, 656)
	_surface.gui_embed_subwindows = true
	add_child_autofree(_surface)


func _fixture(locale: String, percent: int, audio_override: RefCounted = null) -> Dictionary:
	var localization := get_node("/root/LocalizationManager")
	assert_true(localization.set_locale(locale).get("ok", false), locale)
	var profile := ResetProfile.new()
	profile.values[&"preferences.language.primary_locale_id"] = locale
	profile.values[&"preferences.accessibility.text_size"] = percent
	profile.values[&"preferences.accessibility.large_targets"] = true
	var volume := FIXTURES.FakeVolumeSink.new()
	volume.profile = profile
	var audio: RefCounted = audio_override if audio_override != null else FIXTURES.FakeSettingsAudio.new()
	var tts := FIXTURES.FakeSettingsTts.new()
	var content: Control = CONTENT.instantiate()
	content.host_context = "title"
	content.configure_services({"profile": profile, "localization": localization, "audio": audio, "tts": tts, "volume": volume, "input": null, "profile_reset_admission": func() -> bool: return true})
	_surface.add_child(content)
	content.select_category("records")
	return {"content": content, "profile": profile, "audio": audio, "tts": tts, "volume": volume}


func _settle() -> void:
	for frame: int in range(4):
		await get_tree().process_frame


func _open(content: Control, reset_id: String) -> ConfirmationDialog:
	var button: Button = content.find_child(reset_id.to_pascal_case() + "ResetButton", true, false)
	assert_not_null(button, reset_id + ": explicit entry command")
	button.pressed.emit()
	await _settle()
	var dialog: ConfirmationDialog = content.confirmations[reset_id]
	assert_true(dialog.visible, reset_id + ": sheet opened")
	return dialog


func test_all_reset_sheets_fit_the_actual_workfield_in_nine_presentations() -> void:
	for locale: String in LOCALES:
		for percent: int in SIZES:
			var fixture := _fixture(locale, percent)
			var content: Control = fixture.content
			await _settle()
			for reset_id: String in RESET_IDS:
				var dialog: ConfirmationDialog = await _open(content, reset_id)
				var context := "%s %d%% %s" % [locale, percent, reset_id]
				var body := dialog.get_label()
				var cancel := dialog.get_cancel_button()
				var action := dialog.get_ok_button()
				assert_eq(dialog.gui_get_focus_owner(), cancel, context + ": Cancel first")
				_assert_inside(Rect2(Vector2(dialog.position), Vector2(dialog.size)), Rect2(0, 0, 800, 656), context + ": sheet")
				var border: StyleBoxFlat = dialog.theme.get_stylebox("embedded_border", "Window")
				var painted_sheet := Rect2(Vector2(dialog.position), Vector2(dialog.size)).grow_individual(border.expand_margin_left, border.expand_margin_top, border.expand_margin_right, border.expand_margin_bottom)
				_assert_inside(painted_sheet, Rect2(0, 0, 800, 656), context + ": complete embedded title and border")
				var viewport := Rect2(Vector2.ZERO, Vector2(dialog.size))
				_assert_inside(body.get_global_rect(), viewport, context + ": body")
				_assert_inside(cancel.get_global_rect(), viewport, context + ": Cancel")
				_assert_inside(action.get_global_rect(), viewport, context + ": action")
				assert_false(body.get_global_rect().intersects(cancel.get_global_rect()), context + ": body/Cancel separation")
				assert_false(body.get_global_rect().intersects(action.get_global_rect()), context + ": body/action separation")
				assert_false(cancel.get_global_rect().intersects(action.get_global_rect()), context + ": command separation")
				assert_gte(body.size.y + 1.0, body.get_minimum_size().y, context + ": all body lines")
				assert_eq(body.get_theme_font_size("font_size"), int(24 * percent / 100.0), context + ": body type size")
				assert_false(body.clip_text, context + ": no hidden body text")
				assert_eq(body.text, content.text("settings.confirm." + reset_id), context + ": exact scope")
				assert_false(body.text.begins_with("settings."), context + ": translated body")
				assert_eq(action.text, content.text("settings.reset." + reset_id), context + ": explicit action")
				assert_ne(action.text, content.text("settings.confirm"), context + ": no generic Confirm")
				assert_eq(cancel.text, content.text("settings.cancel"), context)
				assert_eq(dialog.get("risk_class"), "danger" if reset_id == "preferences" else "destructive", context)
				for button: Button in [cancel, action]:
					assert_eq(button.get_theme_font_size("font_size"), int(24 * percent / 100.0), context)
					assert_gte(button.size.y, 64.0, context + ": large target")
					assert_false(button.clip_text, context + ": no clipped command")
					var style: StyleBoxFlat = button.get_theme_stylebox("normal")
					assert_true(style.bg_color in [content.theme.get_color("face", "Settings"), content.theme.get_color("habitat", "Settings")], context + ": dark command face")
				var panel: StyleBoxFlat = dialog.theme.get_stylebox("panel", "AcceptDialog")
				assert_eq(panel.bg_color, content.theme.get_color("paper", "Settings"), context + ": cream sheet")
				await _key(dialog, KEY_ESCAPE)
				assert_false(dialog.visible, context + ": Escape dismisses")
				_assert_no_reset(fixture, context)
			content.free()


func test_activating_initial_cancel_is_inert_for_every_reset_and_locale() -> void:
	for locale: String in LOCALES:
		var fixture := _fixture(locale, 150)
		var content: Control = fixture.content
		await _settle()
		for reset_id: String in RESET_IDS:
			var dialog: ConfirmationDialog = await _open(content, reset_id)
			assert_eq(dialog.gui_get_focus_owner(), dialog.get_cancel_button(), locale + ": " + reset_id)
			# Real keyboard activation follows the initial focus. Emitting canceled
			# directly would not prove which command receives the first Enter.
			await _key(dialog, KEY_ENTER)
			assert_false(dialog.visible, locale + ": Enter activates initial Cancel")
			_assert_no_reset(fixture, locale + ": " + reset_id)
		content.free()


func test_escape_cancels_even_after_the_scoped_action_gains_focus() -> void:
	var fixture := _fixture("en", 150)
	var content: Control = fixture.content
	await _settle()
	for reset_id: String in RESET_IDS:
		var dialog: ConfirmationDialog = await _open(content, reset_id)
		dialog.get_ok_button().grab_focus()
		await _settle()
		assert_eq(dialog.gui_get_focus_owner(), dialog.get_ok_button())
		await _key(dialog, KEY_ESCAPE)
		assert_false(dialog.visible, reset_id)
		_assert_no_reset(fixture, reset_id + ": Escape with action focused")
	content.free()


func test_changed_profile_invalidates_consent_and_cancel_reopen_binds_the_new_revision() -> void:
	for reset_id: String in RESET_IDS:
		var fixture := _fixture("en", 100)
		var content: Control = fixture.content
		await _settle()
		var dialog: ConfirmationDialog = await _open(content, reset_id)
		var old_revision: int = fixture.profile.get_profile_revision()
		assert_true(fixture.profile.set_preference(&"preferences.accessibility.reduced_motion", true).get("ok", false))
		assert_gt(fixture.profile.get_profile_revision(), old_revision)
		dialog.get_ok_button().grab_focus()
		await _key(dialog, KEY_ENTER)
		assert_eq(fixture.profile.direct_resets, [], reset_id + ": stale consent never reaches profile reset")
		assert_eq(fixture.volume.resets, [], reset_id + ": stale consent never reaches audio reset")
		# Cancellation also consumes the consent. A forged repeated confirmation
		# must not execute after the window has been dismissed.
		if dialog.visible:
			await _key(dialog, KEY_ESCAPE)
		dialog = await _open(content, reset_id)
		await _key(dialog, KEY_ESCAPE)
		dialog.confirmed.emit()
		await _settle()
		assert_eq(fixture.profile.direct_resets, [], reset_id + ": canceled profile consent")
		assert_eq(fixture.volume.resets, [], reset_id + ": canceled audio consent")
		var new_revision: int = fixture.profile.get_profile_revision()
		dialog = await _open(content, reset_id)
		dialog.get_ok_button().grab_focus()
		await _key(dialog, KEY_ENTER)
		if reset_id in ["preferences", "entire_profile"]:
			assert_eq(fixture.volume.resets.size(), 1, reset_id + ": one fresh reset request")
			if fixture.volume.resets.size() == 1:
				assert_eq(fixture.volume.resets[0].expected_revision, new_revision)
				assert_eq(fixture.volume.resets[0].method, StringName("reset_" + reset_id))
		else:
			assert_eq(fixture.profile.direct_resets, ["reset_" + reset_id])
			assert_eq(fixture.profile.reset_revisions, [new_revision])
		dialog.confirmed.emit()
		await _settle()
		assert_eq(fixture.volume.resets.size() + fixture.profile.direct_resets.size(), 1, reset_id + ": consumed consent cannot replay")
		assert_eq(fixture.profile.commits.size(), 1, "Only the intentional intervening preference change")
		content.free()


func test_focus_loss_during_sample_shutdown_cannot_open_a_late_reset_sheet() -> void:
	var audio := DelayedStopAudio.new()
	audio.available = true
	var fixture := _fixture("en", 150, audio)
	var content: Control = fixture.content
	await _settle()
	# Admit one real controller sample, then hold its physical shutdown so the
	# reset opener has a genuine asynchronous departure to wait for.
	await content.get_controller().toggle_test("Music")
	assert_eq(audio.starts.size(), 1)
	var button: Button = content.find_child("PreferencesResetButton", true, false)
	var dialog: ConfirmationDialog = content.confirmations.preferences
	button.pressed.emit()
	await _settle()
	assert_eq(audio.stops.size(), 1, "Reset opening waits for the admitted sample shutdown")
	assert_false(dialog.visible, "No sheet while departure is still pending")
	content.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _settle()
	audio.stop_ready.emit()
	await _settle()
	assert_false(dialog.visible, "A late shutdown completion must not open an inactive sheet")
	dialog.confirmed.emit()
	await _settle()
	_assert_no_reset(fixture, "Focus loss invalidates pending reset consent")
	content.free()


func test_leaving_records_during_sample_shutdown_cannot_open_the_old_reset_sheet() -> void:
	var audio := DelayedStopAudio.new()
	audio.available = true
	var fixture := _fixture("en", 150, audio)
	var content: Control = fixture.content
	await _settle()
	await content.get_controller().toggle_test("Music")
	var dialog: ConfirmationDialog = content.confirmations.preferences
	content.find_child("PreferencesResetButton", true, false).pressed.emit()
	await _settle()
	assert_eq(audio.stops.size(), 1, "Reset opening waits for the active sample")
	assert_false(dialog.visible)
	content.select_category("language")
	await _settle()
	audio.stop_ready.emit()
	await _settle()
	assert_true(content.get_node("SheetScroll/Sheets/LanguageSheet").visible)
	assert_false(dialog.visible, "The former Records request cannot open over a new category")
	dialog.confirmed.emit()
	await _settle()
	_assert_no_reset(fixture, "Leaving Records invalidates the pending reset request")
	content.free()


func test_revision_change_during_reset_departure_releases_busy_controls_after_refusal() -> void:
	var audio := DelayedStopAudio.new()
	audio.available = true
	var fixture := _fixture("en", 150, audio)
	var content: Control = fixture.content
	await _settle()
	var controller: RefCounted = content.get_controller()
	await controller.toggle_test("Music")
	var checkbox: CheckBox = content.control_for(&"preferences.accessibility.reduced_motion")
	var captured_revision: int = fixture.profile.get_profile_revision()
	controller.reset_profile("reset_preferences", captured_revision)
	await _settle()
	assert_eq(audio.stops.size(), 1, "Reset holds custody until its sample has stopped")
	assert_true(checkbox.disabled, "Pending reset owns the preference controls")
	assert_true(fixture.profile.set_preference(&"preferences.accessibility.reduced_motion", true).get("ok", false))
	audio.stop_ready.emit()
	await _settle()
	assert_eq(fixture.volume.resets, [], "Stale post-departure revision never reaches the reset sink")
	assert_eq(fixture.profile.direct_resets, [], "Stale post-departure revision never resets the profile")
	assert_false(checkbox.disabled, "Refusal must restore control actionability")
	assert_true(checkbox.button_pressed, "The independently committed value remains displayed")
	var slider: HSlider = content.control_for(&"preferences.audio.music_volume")
	assert_true(slider.editable, "Audio controls recover from reset custody too")
	var status: Label = content.find_child("SettingsStatus", true, false)
	assert_eq(status.text, content.text("settings.status.failed"), "The determinate refusal is visible")
	assert_eq(fixture.profile.commits.size(), 1, "Only the intentional intervening preference change")
	content.free()


func _key(dialog: Window, keycode: int) -> void:
	assert_true(dialog.visible, "Key input targets the open embedded reset sheet")
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	# The embedding viewport forwards native Window shortcuts (including
	# Escape/close) before GUI delivery. Pushing straight into the Window skips
	# that production path even though ordinary Button Enter still works.
	_surface.push_input(event)
	await _settle()
	event = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = false
	_surface.push_input(event)
	await _settle()


func _assert_no_reset(fixture: Dictionary, context: String) -> void:
	assert_eq(fixture.profile.direct_resets, [], context + ": no direct reset")
	assert_eq(fixture.profile.commits, [], context + ": no preference write")
	assert_eq(fixture.volume.resets, [], context + ": no audio/profile reset request")
	assert_eq(fixture.volume.commits, [], context + ": no audio preference commit")


func _assert_inside(inner: Rect2, outer: Rect2, context: String) -> void:
	assert_gte(inner.position.x + 1.0, outer.position.x, context + ": left")
	assert_gte(inner.position.y + 1.0, outer.position.y, context + ": top")
	assert_lte(inner.end.x - 1.0, outer.end.x, context + ": right")
	assert_lte(inner.end.y - 1.0, outer.end.y, context + ": bottom")
