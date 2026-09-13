extends SceneTree
## Native SettingsContent sample with real preference transactions in memory only.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const CONTENT := preload("res://scenes/shared/SettingsContent.tscn")
const PATH := &"preferences.accessibility.steady_interface"
const FOLDER := "res://.godot/phase2r_logs/steady_interface"
const LABELS := {"en": "Steady interface", "zh_CN": "稳定界面", "zh_HK": "穩定介面"}

var _profile: Node
var _localization: Node
var _surface: SubViewport
var _records: Array[Dictionary] = []
var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("STEADY_INTERFACE_CAPTURE_FAILED: " + message)
	return condition

func _run() -> void:
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty(), "isolated root required") \
			or not _check(DisplayServer.get_name() != "headless", "native renderer required"):
		quit(1)
		return
	if not _check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER)) == OK, "capture folder"):
		quit(1)
		return
	_profile = PROFILE.new()
	_localization = LOCALIZATION.new()
	root.add_child(_profile)
	root.add_child(_localization)
	if not _check(_profile.initialize(STORAGE.new("steady-interface.memory", FILES.new())).get("ok", false), "memory profile") \
			or not _check(_localization.initialize(_profile).get("ok", false), "localization"):
		_finish()
		return
	_surface = SubViewport.new()
	_surface.size = Vector2i(800, 656)
	_surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_surface.handle_input_locally = true
	_surface.gui_embed_subwindows = true
	root.add_child(_surface)
	for locale: String in LABELS:
		if not await _capture(locale, 100 if locale == "en" else 150):
			_finish()
			return
	_check(_records.size() == 3, "three native locale samples")
	_finish()

func _capture(locale: String, percent: int) -> bool:
	if not _check(_localization.set_locale(locale).get("ok", false), locale + " installed locale") \
			or not _check(_profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false), "text scale") \
			or not _check(_profile.set_preference(PATH, false).get("ok", false), "initial unchecked state"):
		return false
	var content: Control = CONTENT.instantiate()
	content.configure_services({"profile": _profile, "localization": _localization,
		"audio": null, "volume": null, "tts": null, "input": null,
		"profile_reset_admission": func() -> bool: return false})
	_surface.add_child(content)
	content.select_category("accessibility")
	await _frames()
	var checkbox: CheckBox = content.control_for(PATH)
	var description: Label = content.find_child("SteadyInterfaceDescription", true, false)
	if not _check(checkbox != null and description != null, "real row and description"):
		content.queue_free()
		return false
	checkbox.grab_focus()
	await _frames()
	if not _check(checkbox.accessibility_name == LABELS[locale], locale + " localized accessible name") \
			or not _check(not description.text.is_empty() and checkbox.accessibility_description == description.text,
				locale + " localized visible and accessible description"):
		content.queue_free()
		return false
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.pressed = true
	_surface.push_input(press, true)
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	_surface.push_input(release, true)
	await _frames()
	if not _check(checkbox.button_pressed and _profile.get_preference(PATH) == true,
			locale + " native Enter commits the preference") \
			or not _check(checkbox.has_focus(), "committed toggle retains focus"):
		content.queue_free()
		return false
	var aperture: Rect2 = content.sheet_scroll.get_global_rect()
	var label: Label = content.rows[PATH].get_child(0)
	if not _check(aperture.encloses(label.get_global_rect()) and aperture.encloses(checkbox.get_global_rect()) \
			and aperture.encloses(description.get_global_rect()),
			locale + " name, focused control and full description fit the reading aperture"):
		content.queue_free()
		return false
	var filename := locale + "-" + str(percent) + ".png"
	var pixels: Image = _surface.get_texture().get_image()
	if not _check(pixels.save_png(ProjectSettings.globalize_path(FOLDER.path_join(filename))) == OK, "save native capture"):
		content.queue_free()
		return false
	_records.append({"file": filename, "locale": locale, "text_percent": percent,
		"name": checkbox.accessibility_name, "description": description.text,
		"checked": checkbox.button_pressed, "focused": checkbox.has_focus(),
		"scroll": content.sheet_scroll.scroll_vertical})
	content.queue_free()
	await _frames()
	return true

func _frames() -> void:
	for frame: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw

func _finish() -> void:
	var output := FileAccess.open(FOLDER.path_join("measurements.json"), FileAccess.WRITE)
	if _check(output != null, "write measurements"):
		output.store_string(JSON.stringify({"scope": "Real SettingsContent, memory ProfileManager, injected native Enter; no physical-device or assistive-technology acceptance",
			"renderer": "Windows OpenGL3 800x656", "checks": _checks,
			"samples": _records, "failures": _failures}, "\t") + "\n")
		output.close()
	var success := _failures.is_empty() and _records.size() == 3
	print("STEADY_INTERFACE_CAPTURE_", "VERIFIED" if success else "FAILED",
		" captures=", _records.size(), " checks=", _checks, " failures=", _failures.size())
	if is_instance_valid(_surface): _surface.queue_free()
	if is_instance_valid(_localization): _localization.queue_free()
	if is_instance_valid(_profile): _profile.queue_free()
	quit(0 if success else 1)
