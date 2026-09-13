extends "res://tests/ui/render_witnessed_caption.gd"
## Real caption/style captures plus a separately scoped native accessibility rail probe.

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
		for button: Button in _caption.transport_rail.get_children(): labels.append(button.text)
		captures.append({"locale": locale, "text_percent": 150, "file": path, "labels": labels})
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
	if input_owner == null:
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
	rail.configure_presentation(THEME.build("en", 100, "AfterHours"), "en")
	rail.bind_admission(func() -> bool: return true, input_owner)
	rail.project(true, false, false)
	rail.skip_requested.connect(func(): _activations += 1)
	var skip: Button = rail.get_node("Skip")
	skip.accessibility_name = "Skip"
	skip.pressed.connect(func(): _pressed_signals += 1)
	skip.pressed.emit()
	for frame: int in 3: await process_frame
	if _activations != 0 or _pressed_signals != 1:
		print("RESULT " + JSON.stringify({"ok": false, "code": "programmatic_pressed_admitted"}))
		quit(1)
		return
	_pressed_signals = 0
	skip.grab_focus()
	skip.queue_accessibility_update()
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	print("READY " + JSON.stringify({"pid": pid, "window_title": title,
		"expected_caption": "Skip: " + skip.text, "activations": _activations,
		"physical_contacts": input_owner.get_physical_contacts().size(), "programmatic_pressed_rejected": true}))
	var deadline := Time.get_ticks_msec() + 30000
	while _activations == 0 and _pressed_signals == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	for frame: int in 6: await process_frame
	var ok: bool = _activations == 1 and _pressed_signals == 0 and input_owner.get_physical_contacts().is_empty()
	print("RESULT " + JSON.stringify({"ok": ok, "activations": _activations,
		"pressed_signals": _pressed_signals, "physical_contacts": input_owner.get_physical_contacts().size()}))
	quit(0 if ok else 1)
