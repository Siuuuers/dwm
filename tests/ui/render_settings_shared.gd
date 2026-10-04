extends SceneTree
## Real shared Settings UI and isolated Profile/Localization/Input owners.
## Only FakeFileOps receives preference writes. No audio preview or player files.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
class FailureFiles extends "res://tests/support/FakeFileOps.gd":
	var refuse_cleanup := false
	func remove_path(path: String) -> Dictionary:
		if refuse_cleanup and path.ends_with("/profile.json.txn.json"):
			_record(&"remove_path", path)
			return _injected_failure()
		return super.remove_path(path)
const SETTINGS := preload("res://scenes/apps/SettingsApp.tscn")
const PAUSE := preload("res://scenes/overlay/PauseSurface.tscn")
const PRESENTATION := preload("res://scripts/ui/SettingsTheme.gd")
const LOCALES := {"en": "en", "zh_CN": "zh-CN", "zh_HK": "zh-HK"}
const COPY_KEYS := ["continue", "backup", "settings", "return", "title", "question", "warning", "cancel"]

var _files: RefCounted
var _failure_journey := false
var _viewport: SubViewport
var _profile: Node
var _localization: Node
var _input: Node
var _app: Control
var _pause: Control
var _content: Control
var _folder := ""
var _failure := ""
var _records: Array[Dictionary] = []
var _input_backup: Dictionary = {}

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	for action: StringName in InputMap.get_actions():
		_input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}
	_folder = ProjectSettings.globalize_path("user://evidence/settings_shared")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "cannot create evidence directory"):
		await _finish(false)
		return
	_failure_journey = "--settings-write-failure" in OS.get_cmdline_user_args()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.size_2d_override = Vector2i(1280, 720)
	_viewport.size_2d_override_stretch = true
	_viewport.gui_embed_subwindows = true
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	if _failure_journey:
		await _render_failure()
		return
	for locale: String in LOCALES:
		for percent: int in [100, 125, 150]:
			if not await _mount(locale, percent, false):
				await _finish(false)
				return
			_content.select_category("accessibility")
			_content.focus_sheet()
			if not await _capture(locale, percent, "desktop-accessibility"):
				await _finish(false)
				return
	if not await _mount("en", 100, true):
		await _finish(false)
		return
	_pause.rows[&"settings"].grab_focus()
	await _frames()
	if not _check(not _content.is_interaction_enabled() and _pause.entered_action == &"", "Pause preview acquired Settings custody"):
		await _finish(false)
		return
	if not await _capture("en", 100, "pause-preview"):
		await _finish(false)
		return
	await _key(KEY_RIGHT)
	if not _check(_pause.entered_action == &"settings" and _content.is_interaction_enabled() and _content.is_processing_unhandled_input(), "native Right did not restore entered Settings input"):
		await _finish(false)
		return
	if not await _capture("en", 100, "pause-entered"):
		await _finish(false)
		return
	await _finish(_check(_records.size() == 11, "incomplete nine-tuple plus two custody-state matrix"))

func _render_failure() -> void:
	if not await _mount("en", 100, true):
		await _finish(false)
		return
	_pause.rows[&"settings"].grab_focus()
	await _frames()
	await _key(KEY_RIGHT)
	_content.select_category("accessibility")
	var toggle: CheckBox = _content.control_for(&"preferences.accessibility.high_contrast")
	toggle.grab_focus()
	await _frames()
	if not _check(_pause.entered_action == &"settings" and toggle.has_focus(), "failure journey did not enter actual Settings"):
		await _finish(false)
		return
	if not await _capture("en", 100, "failure-before"):
		await _finish(false)
		return
	var before: Dictionary = _profile.get_profile_snapshot()
	_files.refuse_cleanup = true
	await _key(KEY_SPACE)
	var persisted: Dictionary = _files.snapshot_persisted()
	var durable: Dictionary = JSON.parse_string(persisted["settings-render.memory/profile.json"].get_string_from_utf8())
	var operations: int = _files.operation_count()
	var recovery: Control = _content.get_node_or_null("SettingsWriteRecovery")
	if not _check(_content.is_profile_write_uncertain() and is_instance_valid(recovery) and recovery.is_presented()
		and durable.preferences.accessibility.high_contrast and _profile.get_profile_snapshot() == before,
		"real marker-cleanup failure did not retain truthful uncertainty"):
		await _finish(false)
		return
	if not await _capture_failure(recovery, "failure-uncertain"):
		await _finish(false)
		return
	await _key(KEY_SPACE)
	await _key(KEY_ESCAPE)
	await _key(KEY_F5)
	await _key(KEY_F9)
	_pause.leave_host()
	_pause.set_interactive(false)
	_pause.set_interactive(true)
	if not _check(_pause.entered_action == &"settings" and not _content.is_interaction_enabled()
		and not _pause.quick_input_admitted("save") and not _pause.quick_input_admitted("load")
		and _files.operation_count() == operations and _files.snapshot_persisted() == persisted
		and _profile.get_profile_snapshot() == before, "repeated input escaped uncertainty custody"):
		await _finish(false)
		return
	await _finish(await _capture_failure(recovery, "failure-refused"))

func _capture_failure(recovery: Control, state: String) -> bool:
	await _frames()
	var message: Label = recovery.message_label
	if not _check(message.text == _localization.t("settings.status.uncertain")
		and not recovery.retry_button.visible and not recovery.cancel_button.visible,
		"uncertainty copy or no-Retry presentation diverged"): return false
	var measurements: Array[Dictionary] = []
	if not _measure_text(recovery, 100, measurements): return false
	if not _check(_content.get_global_rect().encloses(message.get_global_rect()), "uncertainty text escaped Settings"): return false
	var name := state + ".png"
	if not _check(_viewport.get_texture().get_image().save_png(_folder.path_join(name)) == OK, "cannot save uncertainty capture"): return false
	_records.append({"file": name, "state": state, "message": message.text,
		"text_metrics": measurements, "input_blocked": not _content.is_interaction_enabled(),
		"departure_blocked": _content.is_departure_blocked(), "retry": recovery.retry_button.visible,
		"cancel": recovery.cancel_button.visible, "file_operations": _files.operation_count()})
	return true

func _mount(locale: String, percent: int, in_pause: bool) -> bool:
	await _unmount()
	_profile = PROFILE.new()
	_localization = LOCALIZATION.new()
	_input = INPUT.new()
	for owner: Node in [_profile, _localization, _input]: root.add_child(owner)
	_files = FailureFiles.new()
	if not _check(_profile.initialize(STORAGE.new("settings-render.memory", _files)).get("ok", false), "Profile memory initialization failed"): return false
	if not _check(_localization.initialize(_profile).get("ok", false), "Localization initialization failed"): return false
	if not _check(_localization.set_locale(locale).get("ok", false), "canonical locale commit failed"): return false
	if not _check(_profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false), "canonical text-size commit failed"): return false
	if not _check(_input.initialize(_profile).get("ok", false), "Input initialization failed"): return false
	_app = SETTINGS.instantiate()
	_app.get_node("SettingsContent").configure_services({"profile": _profile, "localization": _localization,
		"input": _input, "audio": null, "volume": null, "tts": null,
		"profile_reset_admission": func() -> bool: return true})
	_app.get_node("LocalePresentationRoot").set("_localization", _localization)
	if in_pause:
		_pause = PAUSE.instantiate()
		if not _check(_pause.set_host(&"settings", _app), "Pause refused Settings host"): return false
		_viewport.add_child(_pause)
		var copy := {}
		for key: String in COPY_KEYS: copy[key] = _localization.t("ui.pause." + key)
		if not _check(_pause.configure_presentation(LOCALES[locale], percent, "AfterHours") and _pause.configure_copy(copy), "Pause presentation/copy refused"): return false
		_pause.open_surface()
	else:
		_app.position = Vector2(480, 64)
		_app.size = Vector2(800, 656)
		_viewport.add_child(_app)
		_app.show_window()
	_content = _app.settings_content
	await _frames()
	return _check(_app.get_desktop_ready_result().get("ok", false), "actual Settings host is not ready")

func _capture(locale: String, percent: int, state: String) -> bool:
	await _frames()
	var expected := Rect2(480, 64, 800, 656)
	if not _check(_app.get_global_rect() == expected and _content.get_global_rect() == expected, "Settings escaped exact 800x656 workfield"): return false
	if not _check(_content.theme.default_font_size == int(24 * percent / 100.0), "canonical full text size changed"): return false
	if not _check(_content.current_locale() == locale, "rendered locale differs from canonical owner"): return false
	var primary: Font = {"en": PRESENTATION.ENGLISH, "zh_CN": PRESENTATION.SIMPLIFIED, "zh_HK": PRESENTATION.TRADITIONAL}[locale]
	var rendered_font := _content.theme.default_font as FontVariation
	if not _check(rendered_font != null and rendered_font.base_font == primary, "locale lost its authored primary font"): return false
	var focused: Control = _viewport.gui_get_focus_owner()
	if state == "pause-preview":
		if not _check(focused == _pause.rows[&"settings"], "preview focus left the Pause action"): return false
	elif not _check(focused != null and _content.is_ancestor_of(focused), "entered Settings has no exclusive focus owner"): return false
	var scroll: ScrollContainer = _content.sheet_scroll
	if not _check(scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1.0, "shared sheet has horizontal overflow"): return false
	var measurements: Array[Dictionary] = []
	if not _measure_text(_content, percent, measurements): return false
	for caption: Label in _content.get("_sample_labels"):
		if not _check(caption.get_parent().get_global_rect().encloses(caption.get_global_rect()), "sample caption escaped its state specimen"): return false
	var pixels := _viewport.get_texture().get_image()
	if not _check(pixels != null and pixels.get_size() == Vector2i(640, 360), "capture is not native 640x360"): return false
	var name := "%s-%d-AfterHours-standard-%s.png" % [locale, percent, state]
	if not _check(pixels.save_png(_folder.path_join(name)) == OK, "cannot save native image"): return false
	_records.append({"file": name, "locale": locale, "text_percent": percent, "state": state,
		"palette": "AfterHours", "high_contrast": false, "colour_preset": "standard", "large_targets": false,
		"native_size": [640, 360], "logical_size": [1280, 720], "workfield": [480, 64, 800, 656],
		"focus": str(focused.name), "primary_font": primary.resource_path,
		"sheet_scroll": scroll.scroll_vertical, "sheet_extent": maxf(0.0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page),
		"text_metrics": measurements})
	return true

func _measure_text(node: Node, percent: int, records: Array[Dictionary]) -> bool:
	if node is Control and not node.is_visible_in_tree(): return true
	if node is Label and not node.text.is_empty():
		var label := node as Label
		var expected := int(24 * percent / 100.0)
		if not _check(label.get_theme_font_size("font_size") == expected, "label shrank below authored text size: " + str(label.get_path())): return false
		if not _check(label.visible_characters == -1 and label.max_lines_visible == -1, "label copy is character/line capped"): return false
		if not _check(label.size.y + 0.1 >= label.get_minimum_size().y, "label text clips vertically: " + label.text): return false
		if label.get_parent() is Button and not _check(label.get_parent().get_global_rect().encloses(label.get_global_rect()), "rail caption escaped its target: %s label=%s target=%s" % [label.text, label.get_global_rect(), label.get_parent().get_global_rect()]): return false
		if not _glyphs(label.get_theme_font("font"), label.text): return false
		records.append({"node": str(_content.get_path_to(label)), "text": label.text,
			"font_size": expected, "size": [label.size.x, label.size.y], "minimum_height": label.get_minimum_size().y,
			"unwrapped_advance": label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, expected).x})
	elif node is Button and not node.text.is_empty():
		var button := node as Button
		var font: Font = button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		if not _check(font_size == int(24 * percent / 100.0), "button text shrank below authored size"): return false
		if not _glyphs(font, button.text): return false
		var aperture := button.size.x - button.get_theme_stylebox("normal").get_minimum_size().x
		if button is OptionButton: aperture -= button.get_theme_icon("arrow").get_width() + button.get_theme_constant("h_separation")
		elif button is CheckBox: aperture -= button.get_theme_icon("unchecked").get_width() + button.get_theme_constant("h_separation")
		var advance := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if not _check(advance <= aperture + 0.1, "button's complete copy exceeds text aperture: " + button.text): return false
		records.append({"node": str(_content.get_path_to(button)), "text": button.text,
			"font_size": font_size, "text_advance": advance, "text_aperture": aperture})
	for child: Node in node.get_children():
		if child is Window: continue
		if not _measure_text(child, percent, records): return false
	return true

func _glyphs(font: Font, copy: String) -> bool:
	if not _check(not copy.contains("[missing:") and not copy.contains("[format_error:") and not copy.contains("�") and not copy.begins_with("settings."), "missing or malformed localized copy"): return false
	for character: String in copy:
		if character in ["\n", "\r", "\t", " "]: continue
		if not _check(font.has_char(character.unicode_at(0)), "authored font stack lacks visible glyph: " + character): return false
	return true

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame
	await _frames()

func _frames() -> void:
	for frame: int in range(3): await RenderingServer.frame_post_draw

func _unmount() -> void:
	if is_instance_valid(_pause):
		_pause.close_surface()
		_pause.queue_free()
	elif is_instance_valid(_app):
		_app.queue_free()
	await process_frame
	_pause = null
	_app = null
	_content = null
	for owner: Node in [_input, _localization, _profile]:
		if is_instance_valid(owner): owner.free()
	_input = null
	_localization = null
	_profile = null

func _check(ok: bool, message: String) -> bool:
	if not ok:
		if _failure.is_empty(): _failure = message
		push_error("SETTINGS_SHARED_RENDER_FAILED: " + message)
	return ok

func _finish(ok: bool) -> void:
	var report := FileAccess.open(_folder.path_join("settings-shared-measurements.json"), FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"ok": ok, "failure": _failure, "captures": _records.size(),
			"scope": "Actual Pause Settings keyboard journey with real Profile/Localization/Input and in-memory marker-cleanup refusal after durable promotion; no physical disk or OS-crash claim." if _failure_journey else "Nine bare SettingsApp Accessibility sheets and two actual PauseSurface Settings custody states; real Profile/Localization/Input, in-memory storage. No full desktop, audio preview, TTS, lifecycle, or assistive-technology acceptance.",
			"palette_scope": "AfterHours Standard ordinary targets only.",
			"glyph_scope": "Authored locale primary font plus explicit companion-font coverage and full-size geometry checks; no claim of perceptual or screen-reader acceptance. Offscreen sheet rows remain reachable by vertical scroll.",
			"samples": _records}, "\t") + "\n")
		report.close()
	else:
		ok = false
		push_error("SETTINGS_SHARED_RENDER_FAILED: cannot write measurement report")
	await _unmount()
	if is_instance_valid(_viewport): _viewport.queue_free()
	await process_frame
	for action: StringName in InputMap.get_actions():
		if not _input_backup.has(action): InputMap.erase_action(action)
	for action: StringName in _input_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _input_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _input_backup[action].events: InputMap.action_add_event(action, event)
	print("SETTINGS_SHARED_RENDER_", "VERIFIED" if ok else "FAILED", " captures=", _records.size(), " evidence=", _folder)
	quit(0 if ok else 1)

