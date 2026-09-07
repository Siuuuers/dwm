extends "res://addons/gut/test.gd"
## Actual title Menu, Gallery, Settings and Backup views with real memory profile,
## localization, input and audio owners. No route or replay owner participates.

const MENU := preload("res://scenes/menu/MenuScene.tscn")
const BACKUP := preload("res://scenes/apps/BackupApp.tscn")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const PLAYBACK := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")


class DelayedAudio extends AUDIO:
	signal cancel_ready()
	signal commit_ready()
	signal preview_ready()
	var hold_cancel := false
	var hold_commit := false
	var hold_preview := false

	func preview_settings_volume(holder: Variant, path: Variant, value: Variant,
			preview_handle: Variant = null) -> Dictionary:
		if hold_preview:
			await preview_ready
			hold_preview = false
		return super.preview_settings_volume(holder, path, value, preview_handle)

	func cancel_settings_volume_preview(handle: Variant) -> Dictionary:
		if hold_cancel:
			await cancel_ready
			hold_cancel = false
		return super.cancel_settings_volume_preview(handle)

	func commit_settings_audio_preference(holder: Variant, path: Variant, value: Variant,
			preview_handle: Variant = null) -> Dictionary:
		if hold_commit:
			await commit_ready
			hold_commit = false
		return super.commit_settings_audio_preference(holder, path, value, preview_handle)


class BackupPort:
	extends RefCounted
	var cancelled: Array[String] = []

	func get_projection() -> Dictionary:
		var records: Array[Dictionary] = []
		for locator: String in ["autosave", "quick", "slot:1", "slot:2", "slot:3", "slot:4", "slot:5", "slot:6", "slot:7"]:
			var occupied := locator == "slot:1"
			records.append({"locator": locator, "state": "occupied" if occupied else "empty",
				"day": 2 if occupied else null, "saved_time": "12:00" if occupied else null,
				"fallback": false, "load_day": null, "load_saved_time": null, "reason": "",
				"actions": {"save": false, "load": occupied, "delete": occupied}})
		return {"ok": true, "value": {"records": records, "save_capability": {"enabled": false}}}

	func prepare_action(action: String, locator: String) -> Dictionary:
		if action != "delete" or locator != "slot:1":
			return {"ok": false, "code": &"backup_action_unavailable"}
		return {"ok": true, "value": {"confirmation_required": true,
			"confirmation_kind": "delete", "token": "delete:slot:1",
			"record": get_projection().value.records[2]}}

	func commit_action(_token: String) -> Dictionary:
		return {"ok": true, "value": {}}

	func cancel_action(token: String) -> void:
		cancelled.append(token)


var _surface: SubViewport
var _profile: Node
var _localization: Node
var _input: Node
var _audio: Node
var _playback: RefCounted
var _menu: Control
var _input_backup: Dictionary = {}


func before_each() -> void:
	for action: StringName in InputMap.get_actions():
		_input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action),
			"events": InputMap.action_get_events(action).duplicate(true)}
	_profile = PROFILE.new()
	_localization = LOCALIZATION.new()
	_input = INPUT.new()
	_playback = PLAYBACK.new()
	_audio = DelayedAudio.new(_playback)
	for owner: Node in [_profile, _localization, _input, _audio]: add_child(owner)
	assert_true(_profile.initialize(STORAGE.new("menu-gallery-host.memory", FILES.new())).get("ok", false))
	assert_true(_localization.initialize(_profile).get("ok", false))
	assert_true(_input.initialize(_profile).get("ok", false))
	assert_true(_audio.initialize(_profile).get("ok", false))
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.gui_embed_subwindows = true
	add_child(_surface)
	_menu = MENU.instantiate()
	_menu.configure_settings_services(_services())
	_surface.add_child(_menu)
	await _settle()


func after_each() -> void:
	if is_instance_valid(_surface): _surface.free()
	for owner: Node in [_audio, _input, _localization, _profile]:
		if is_instance_valid(owner): owner.free()
	for action: StringName in InputMap.get_actions():
		if not _input_backup.has(action): InputMap.erase_action(action)
	for action: StringName in _input_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _input_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _input_backup[action].events: InputMap.action_add_event(action, event)
	_input_backup.clear()


func _services() -> Dictionary:
	return {"profile": _profile, "localization": _localization, "input": _input,
		"audio": _audio, "volume": _audio, "tts": null,
		"profile_reset_admission": func() -> bool: return true}


func _settle() -> void:
	for _frame: int in range(4): await get_tree().process_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	_surface.push_input(event, true)


func _tap(code: Key) -> void:
	_key(code, true)
	await _settle()
	_key(code, false)
	await _settle()


func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_surface.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_surface.push_input(event, true)
		await _settle()


func _open_gallery() -> Control:
	await _click(_menu.get_node("%GalleryButton"))
	var gallery: Control = _menu.get("_gallery_instance")
	assert_not_null(gallery)
	return gallery


func _open_settings() -> Control:
	await _click(_menu.get_node("%SettingButton"))
	var app: Control = _menu.get("_setting_instance")
	assert_not_null(app)
	return app.settings_content if app != null else null


func test_actual_entry_return_back_and_reopen_reuse_one_gallery() -> void:
	assert_true(_profile.unlock_ending("ending.alone", "menu-gallery:first").get("ok", false))
	var gallery := await _open_gallery()
	if gallery == null: return
	var identity := gallery.get_instance_id()
	assert_true(_menu.get("_gallery_host").visible)
	assert_eq(gallery.get_node("%EndingTileGrid").get_child_count(), 1)
	assert_same(_surface.gui_get_focus_owner(), gallery.get_node("%EndingTileGrid").get_child(0))
	await _click(_menu.get("_title_home"))
	assert_false(_menu.get("_gallery_host").visible)
	assert_true(_menu.get_node("%GalleryButton").has_focus())
	gallery = await _open_gallery()
	assert_eq(gallery.get_instance_id(), identity)
	await _tap(KEY_ESCAPE)
	assert_false(_menu.get("_gallery_host").visible)
	assert_true(_menu.get_node("%GalleryButton").has_focus())


func test_settings_capture_and_pending_commit_refuse_gallery_then_return_restores_settings_row() -> void:
	var content := await _open_settings()
	if content == null: return
	content.select_category("controls")
	var sheet: Control = content.get("_controls_sheet")
	var source: Button = sheet.button_for("game_quick_save", "keyboard")
	source.grab_focus()
	await _tap(KEY_ENTER)
	assert_true(sheet.capture_dialog.visible)
	_menu._on_gallery_pressed()
	await _settle()
	assert_null(_menu.get("_gallery_instance"))
	assert_true(_menu.get("_setting_host").visible)
	await _tap(KEY_ESCAPE)

	content.select_category("audio")
	_audio.hold_commit = true
	content.get_controller().commit_preference(&"preferences.audio.music_muted", true)
	await _settle()
	assert_true(content.get_controller().is_commit_pending())
	_menu._on_gallery_pressed()
	await _settle()
	assert_null(_menu.get("_gallery_instance"))
	assert_true(_menu.get("_setting_host").visible)
	_audio.commit_ready.emit()
	await _settle()
	assert_true(_profile.get_preference(&"preferences.audio.music_muted"))
	await _click(_menu.get("_title_home"))
	assert_false(_menu.get("_setting_host").visible)
	assert_true(_menu.get_node("%SettingButton").has_focus())


func test_backup_confirmation_is_exclusive_and_one_back_only_cancels_it() -> void:
	var backup: Control = BACKUP.instantiate()
	backup.configure_title_login()
	_menu.get("_backup_app_host").add_child(backup)
	backup.set_confirmation_host(_menu)
	backup.configure_desktop_home(_menu.get("_title_home"))
	assert_true(backup.configure_backup(BackupPort.new(), _localization, _profile).get("ok", false))
	_menu.set("_backup_app_instance", backup)
	await _menu._on_log_in_pressed()
	await _settle()
	backup.drawer_buttons["slot:1"].grab_focus()
	backup.action_buttons.delete.grab_focus()
	backup._action_pressed("delete")
	await _settle()
	assert_true(is_instance_valid(_menu.get("_confirmation")))
	_menu._on_gallery_pressed()
	_menu._on_setting_pressed()
	await _settle()
	assert_true(_menu.get("_backup_app_host").visible)
	assert_false(_menu.get("_gallery_host").visible)
	assert_false(_menu.get("_setting_host").visible)
	await _tap(KEY_ESCAPE)
	assert_false(is_instance_valid(_menu.get("_confirmation")))
	assert_true(_menu.get("_backup_app_host").visible)
	assert_true(backup.action_buttons.delete.has_focus())


func test_visible_clear_restore_refreshes_and_hidden_publication_cannot_take_focus() -> void:
	assert_true(_profile.unlock_ending("ending.alone", "menu-gallery:restore").get("ok", false))
	var restored: Dictionary = _profile.get_profile_snapshot()
	var gallery := await _open_gallery()
	if gallery == null: return
	assert_eq(gallery.get_node("%EndingTileGrid").get_child_count(), 1)
	assert_true(_profile.reset_gallery().get("ok", false))
	await _settle()
	assert_eq(gallery.get_node("%EndingTileGrid").get_child_count(), 0)
	assert_true(_profile.apply_restore_silent({"profile": restored}).get("ok", false))
	_profile.publish_restore()
	await _settle()
	assert_eq(gallery.get_node("%EndingTileGrid").get_child_count(), 1)
	await _click(_menu.get("_title_home"))
	var focus_before: Control = _surface.gui_get_focus_owner()
	assert_true(_profile.reset_gallery().get("ok", false))
	assert_true(_localization.set_locale("zh_HK").get("ok", false))
	await _settle()
	assert_same(_surface.gui_get_focus_owner(), focus_before)
	assert_true(_menu.get_node("%GalleryButton").has_focus())
	gallery = await _open_gallery()
	assert_eq(gallery.get_node("%EndingTileGrid").get_child_count(), 0)


func test_native_dropdown_back_dismisses_only_modal_and_gallery_stays_refused() -> void:
	var content := await _open_settings()
	if content == null: return
	content.select_category("language")
	var option: OptionButton = content.control_for(&"preferences.language.primary_locale_id")
	option.show_popup()
	await _settle()
	assert_true(option.get_popup().visible)
	_menu._on_gallery_pressed()
	await _settle()
	assert_null(_menu.get("_gallery_instance"))
	await _tap(KEY_ESCAPE)
	assert_false(option.get_popup().visible)
	assert_true(_menu.get("_setting_host").visible)


func test_gallery_waits_for_settings_cleanup_and_login_cannot_race_transition() -> void:
	var content := await _open_settings()
	if content == null: return
	content.select_category("audio")
	var controller: RefCounted = content.get_controller()
	# Start one real preview request, then retire its pointer transaction before
	# the output owner answers. Departure is admitted, but must await this detached
	# request and cancel the late handle before Gallery can become visible.
	_audio.hold_preview = true
	controller.begin_volume_drag(&"preferences.audio.music_volume")
	controller._on_volume_changed(0.4, &"preferences.audio.music_volume")
	await _settle()
	assert_false(controller.get("_drag").is_empty())
	controller.finish_volume_drag(false, &"preferences.audio.music_volume")
	await _settle()
	assert_true(controller.get("_drag").is_empty())
	assert_false(controller.get("_preview_operations").is_empty())
	_audio.hold_cancel = true
	_menu._on_gallery_pressed()
	await _settle()
	assert_true(_menu.get("_setting_host").visible)
	assert_null(_menu.get("_gallery_instance"))
	assert_true(_menu.get("_title_transition"))
	_menu._on_log_in_pressed()
	await _settle()
	assert_false(_menu.get("_backup_app_host").visible)
	_audio.preview_ready.emit()
	await _settle()
	assert_true(_menu.get("_setting_host").visible)
	assert_null(_menu.get("_gallery_instance"))
	_audio.cancel_ready.emit()
	await _settle()
	assert_false(_menu.get("_setting_host").visible)
	assert_true(_menu.get("_gallery_host").visible)
	assert_not_null(_menu.get("_gallery_instance"))
	assert_false(_menu.get("_title_transition"))
