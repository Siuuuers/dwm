extends "res://tests/ui/render_witnessed_caption.gd"
## Real caption/style captures plus a separately scoped native accessibility rail probe.

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const RAIL := preload("res://scripts/ui/witnessed/WitnessedTransportRail.gd")
var _activations := 0
var _pressed_signals := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests").replace("\\", "/").simplify_path().trim_suffix("/")
	if not isolated.to_lower().begins_with(allowed.to_lower() + "/") \
			or not DirAccess.dir_exists_absolute(isolated) or DisplayServer.get_name() == "headless":
		quit(1)
		return
	var profile: Node = root.get_node("ProfileManager")
	var localization: Node = root.get_node("LocalizationManager")
	if not profile.initialize(STORAGE.new(isolated.path_join("transport-profile"))).get("ok", false) \
			or not localization.initialize(profile).get("ok", false):
		quit(1)
		return
	for frame: int in 3: await process_frame
	if "--native-invoke" in OS.get_cmdline_user_args():
		await _native_invoke()
		return
	_folder = isolated.path_join("witnessed-transport")
	if DirAccess.make_dir_recursive_absolute(_folder) != OK or not await _mount():
		quit(1)
		return
	var captures: Array[Dictionary] = []
	for locale: String in ["en", "zh-CN", "zh-HK"]:
		if not localization.set_locale(locale.replace("-", "_")).get("ok", false):
			await _restore()
			quit(1)
			return
		if not await _show_fixture(locale, 150, "AfterHours", false):
			await _restore()
			quit(1)
			return
		await RenderingServer.frame_post_draw
		var pixels: Image = _viewport.get_texture().get_image()
		var path := _folder.path_join(locale + "-150.png")
		if pixels == null or pixels.save_png(path) != OK:
			await _restore()
			quit(1)
			return
		var labels: Array[String] = []
		var enabled: Dictionary = {}
		for button: Button in _caption.transport_rail.get_children():
			labels.append(button.text)
			enabled[button.name] = not button.disabled
		captures.append({"locale": locale, "text_percent": 150, "file": path,
			"labels": labels, "enabled": enabled})
	await _restore()
	print("WITNESSED_TRANSPORT_CAPTURE " + JSON.stringify({"captures": captures,
		"scope": "Synthetic captions through the actual mounted style; six controls; no story or full transport completion claim"}))
	quit(0)

func _native_invoke() -> void:
	if not is_accessibility_enabled():
		push_error("Native accessibility evidence requires --accessibility always.")
		quit(1)
		return
	var input_owner: Node = root.get_node_or_null("InputManager")
	var profile: Node = root.get_node_or_null("ProfileManager")
	if input_owner == null or profile == null:
		quit(1)
		return
	var control := "Skip"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--control="):
			control = argument.trim_prefix("--control=").capitalize()
	if control not in ["Skip", "Auto"]:
		push_error("Native accessibility control must be Skip or Auto.")
		quit(1)
		return
	var pid := OS.get_process_id()
	var title := "DWM Witnessed Transport Accessibility %d" % pid
	DisplayServer.window_set_title(title)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var rail := RAIL.new()
	rail.position = Vector2(0, 656)
	rail.size = Vector2(1280, 64)
	root.add_child(rail)
	if not rail.bind_localization(root.get_node("LocalizationManager")):
		quit(1)
		return
	if not rail.configure_presentation(THEME.build("en", 100, "AfterHours"), "en"):
		quit(1)
		return
	var auto_before: bool = bool(profile.get_preference(&"preferences.reading.auto_enabled", false))
	var probe := {"profile_result": {}}
	if control == "Auto":
		if not rail.bind_auto_admission(func() -> bool: return true, input_owner):
			quit(1)
			return
		rail.auto_requested.connect(func() -> void:
			_activations += 1
			probe.profile_result = profile.set_preference(
				&"preferences.reading.auto_enabled", not auto_before)
			rail.project(false, false,
				bool(profile.get_preference(&"preferences.reading.auto_enabled", false)), true))
		if not rail.project(false, false, auto_before, true):
			quit(1)
			return
	else:
		if not rail.bind_admission(func() -> bool: return true, input_owner):
			quit(1)
			return
		rail.skip_requested.connect(func(): _activations += 1)
		if not rail.project(true, false, auto_before):
			quit(1)
			return
	var button: Button = rail.get_node(control)
	button.accessibility_name = control
	button.pressed.connect(func(): _pressed_signals += 1)
	button.pressed.emit()
	for frame: int in 3: await process_frame
	if _activations != 0 or _pressed_signals != 1:
		print("RESULT " + JSON.stringify({"ok": false, "code": "programmatic_pressed_admitted"}))
		quit(1)
		return
	_pressed_signals = 0
	button.grab_focus()
	button.queue_accessibility_update()
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	print("READY " + JSON.stringify({"pid": pid, "window_title": title,
		"control": control, "expected_caption": control + ": " + button.text,
		"activations": _activations, "physical_contacts": input_owner.get_physical_contacts().size(),
		"profile_auto_enabled": auto_before, "programmatic_pressed_rejected": true,
		"scope": "native UIA provider and isolated Profile preference; no narrative integration claim"}))
	var deadline := Time.get_ticks_msec() + 30000
	while _activations == 0 and _pressed_signals == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	for frame: int in 6: await process_frame
	var auto_after: bool = bool(profile.get_preference(&"preferences.reading.auto_enabled", false))
	var profile_ok: bool = control != "Auto" or (probe.profile_result.get("ok", false)
		and not auto_before and auto_after)
	var ok: bool = _activations == 1 and _pressed_signals == 0 \
		and input_owner.get_physical_contacts().is_empty() and profile_ok
	print("RESULT " + JSON.stringify({"ok": ok, "activations": _activations,
		"control": control, "pressed_signals": _pressed_signals,
		"physical_contacts": input_owner.get_physical_contacts().size(),
		"profile_auto_enabled_before": auto_before, "profile_auto_enabled_after": auto_after,
		"profile_write_ok": probe.profile_result.get("ok", false) if control == "Auto" else null}))
	quit(0 if ok else 1)
