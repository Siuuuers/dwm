extends "res://tests/ui/render_witnessed_caption.gd"
## Three mounted recovery captures plus a separately scoped native Retry action probe.

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
const RECOVERY_SCENE := preload("res://scenes/ui/witnessed/WitnessedTransportRecovery.tscn")
const SOURCE_CANVAS := preload("res://scripts/ui/witnessed/WitnessedSourceCanvas.gd")

var _activations := 0
var _pressed_signals := 0
var _capture_failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var allocated: Dictionary = TEMPORARY_STORAGE.create("witnessed-reading-recovery-capture")
	if not allocated.get("ok", false) or DisplayServer.get_name() == "headless":
		printerr("WITNESSED_READING_RECOVERY_CAPTURE_FAILED root/display ", allocated)
		quit(1)
		return
	var isolated := str(allocated.value)
	var profile: Node = root.get_node_or_null("ProfileManager")
	var localization: Node = root.get_node_or_null("LocalizationManager")
	if profile == null or localization == null \
			or not profile.initialize(STORAGE.new(isolated.path_join("profile"))).get("ok", false) \
			or not localization.initialize(profile).get("ok", false):
		printerr("WITNESSED_READING_RECOVERY_CAPTURE_FAILED owner initialization")
		quit(1)
		return
	for frame: int in 3: await process_frame
	_folder = isolated.path_join("witnessed-reading-recovery")
	if DirAccess.make_dir_recursive_absolute(_folder) != OK or not await _mount():
		quit(1)
		return
	if "--native-invoke" in OS.get_cmdline_user_args():
		await _native_invoke(localization)
		return
	var captures: Array[Dictionary] = []
	for locale: String in ["en", "zh-CN", "zh-HK"]:
		if not localization.set_locale(locale.replace("-", "_")).get("ok", false) \
				or not await _show_fixture(locale, 150, "AfterHours", false):
			_capture_failure(locale + " fixture did not mount")
			break
		var recovery := _caption.get("recovery_overlay") as Control
		if recovery == null:
			_capture_failure("mounted caption has no RecoveryLayer/Recovery")
			break
		if not bool(recovery.get("_bound")):
			var input_owner: Node = root.get_node_or_null("InputManager")
			if input_owner == null or not bool(recovery.call("bind_owners",
					localization, input_owner, func() -> bool: return true)):
				_capture_failure(locale + " recovery owners did not bind")
				break
		var source_invariants: Dictionary = _invariants()
		var source_pixels: Image = _viewport.get_texture().get_image()
		var source_canvas := _caption.get("canvas") as Control
		source_canvas.set("accessibility_withdrawn", true)
		if not bool(recovery.call("configure_presentation",
				locale, 150, "AfterHours", false, "standard", false)) \
				or not bool(recovery.call("present", true, true)):
			_capture_failure(locale + " recovery presentation was refused")
			break
		await _frames()
		var retry := recovery.get("retry_button") as Button
		var cancel := recovery.get("cancel_button") as Button
		var body := recovery.get("message_label") as Label
		var recovery_layer := _caption.get("recovery_layer") as CanvasLayer
		var pixels: Image = _viewport.get_texture().get_image()
		var filename := locale + "-150-retry-cancel.png"
		var focused: Control = _viewport.gui_get_focus_owner()
		var invariants_after: Dictionary = _invariants()
		var pixels_available := source_pixels != null and pixels != null
		var dimensions_equal := pixels_available and source_pixels.get_size() == pixels.get_size()
		var image_changed := dimensions_equal and source_pixels.get_data() != pixels.get_data()
		var png_error := pixels.save_png(_folder.path_join(filename)) if pixels != null else ERR_UNAVAILABLE
		var observations := {
			"recovery_visible": recovery.is_visible_in_tree(),
			"retry_visible": retry.visible, "retry_disabled": retry.disabled,
			"cancel_visible": cancel.visible, "cancel_disabled": cancel.disabled,
			"retry_has_focus": retry.has_focus(),
			"focus_owner": str(focused.get_path()) if focused != null else "",
			"message_nonempty": not body.text.strip_edges().is_empty(),
			"message": body.text, "retry": retry.text, "cancel": cancel.text,
			"retry_language": retry.language, "cancel_language": cancel.language,
			"source_invariants_equal": invariants_after == source_invariants,
			"source_before": str(source_invariants), "source_after": str(invariants_after),
			"source_accessibility_withdrawn": bool(source_canvas.get("accessibility_withdrawn")),
			"recovery_layer": recovery_layer.layer if recovery_layer != null else -1,
			"pixels_available": pixels_available,
			"source_size": str(source_pixels.get_size()) if source_pixels != null else "",
			"overlay_size": str(pixels.get_size()) if pixels != null else "",
			"dimensions_equal": dimensions_equal,
			"whole_image_bytes_changed": image_changed,
			"png_error": png_error,
		}
		var valid: bool = bool(observations.recovery_visible) \
			and bool(observations.retry_visible) and not bool(observations.retry_disabled) \
			and bool(observations.cancel_visible) and not bool(observations.cancel_disabled) \
			and bool(observations.retry_has_focus) and bool(observations.message_nonempty) \
			and observations.retry_language == locale and observations.cancel_language == locale \
			and bool(observations.source_invariants_equal) \
			and bool(observations.source_accessibility_withdrawn) \
			and int(observations.recovery_layer) > 0 and bool(observations.pixels_available) \
			and bool(observations.dimensions_equal) \
			and bool(observations.whole_image_bytes_changed) and int(observations.png_error) == OK
		if not valid:
			_capture_failure(locale + " mounted recovery capture was incomplete: " \
				+ JSON.stringify(observations))
			break
		captures.append({"locale": locale, "text_percent": 150, "file": filename,
			"message": body.text, "retry": retry.text, "cancel": cancel.text,
			"retry_rect": str(retry.get_global_rect()), "cancel_rect": str(cancel.get_global_rect()),
			"caption_text": _caption.caption_text.get_parsed_text(),
			"canvas_layer": recovery_layer.layer, "source_state_preserved": true,
			"source_accessibility_withdrawn": true})
		recovery.call("dismiss")
		source_canvas.set("accessibility_withdrawn", false)
		await _frames()
	var report_path := _folder.path_join("measurements.json")
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({
			"scope": "Synthetic captions through the installed Dialogic style with its actual mounted reading-recovery overlay; no authored-story, storage-Retry, or assistive-technology acceptance claim",
			"captures": captures, "failures": _capture_failures,
		}, "\t") + "\n")
		report.close()
	await _restore()
	var ok: bool = captures.size() == 3 and _capture_failures.is_empty() and report != null
	print("WITNESSED_READING_RECOVERY_CAPTURE " + JSON.stringify({"ok": ok,
		"captures": captures.size(), "failures": _capture_failures, "evidence": _folder}))
	quit(0 if ok else 1)


func _native_invoke(localization: Node) -> void:
	if not is_accessibility_enabled():
		_capture_failure("native accessibility evidence requires --accessibility always")
		await _restore()
		quit(1)
		return
	if not localization.set_locale("en").get("ok", false) \
			or not await _show_fixture("en", 150, "AfterHours", false):
		_capture_failure("native source caption did not mount")
		await _restore()
		quit(1)
		return
	await RenderingServer.frame_post_draw
	var source_image: Image = _viewport.get_texture().get_image()
	var source_path := _folder.path_join("native-source.png")
	if source_image == null or source_image.save_png(source_path) != OK:
		_capture_failure("native source image was not preserved")
		await _restore()
		quit(1)
		return
	await _restore()
	var input_owner: Node = root.get_node_or_null("InputManager")
	if input_owner == null:
		_capture_failure("InputManager is unavailable")
		quit(1)
		return
	var pid := OS.get_process_id()
	var title := "DWM Witnessed Reading Recovery Accessibility %d" % pid
	DisplayServer.window_set_title(title)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var recovery_layer := CanvasLayer.new()
	recovery_layer.name = "RecoveryLayer"
	recovery_layer.layer = 3
	root.add_child(recovery_layer)
	var recovery: Control = RECOVERY_SCENE.instantiate()
	recovery_layer.add_child(recovery)
	var source_canvas := SOURCE_CANVAS.new()
	root.add_child(source_canvas)
	source_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	source_canvas.set("accessibility_withdrawn", false)
	var source := TextureRect.new()
	source_canvas.add_child(source)
	source.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	source.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	source.stretch_mode = TextureRect.STRETCH_SCALE
	source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.texture = ImageTexture.create_from_image(source_image)
	var source_texture: Texture2D = source.texture
	var source_probe := Label.new()
	source_probe.name = "ReadingRecoverySourceProbe"
	source_probe.text = "Reading recovery source probe"
	source_probe.position = Vector2(24, 24)
	source_probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_canvas.add_child(source_probe)
	source_probe.queue_accessibility_update()
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	var source_ack_path := _folder.path_join("source-visible.ack")
	if FileAccess.file_exists(source_ack_path):
		_capture_failure("native source acknowledgement was stale")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 60000
	print("SOURCE_READY " + JSON.stringify({"pid": pid, "window_title": title,
		"source_label": source_probe.text, "acknowledge_file": source_ack_path,
		"source_accessibility_withdrawn": false}))
	while not FileAccess.file_exists(source_ack_path) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not FileAccess.file_exists(source_ack_path):
		_capture_failure("native source visibility acknowledgement timed out")
		quit(1)
		return
	source_canvas.set("accessibility_withdrawn", true)
	source_canvas.queue_accessibility_update()
	if not bool(recovery.call("bind_owners", localization, input_owner,
			func() -> bool: return true)) \
			or not bool(recovery.call("configure_presentation",
				"en", 150, "AfterHours", false, "standard", false)) \
			or not bool(recovery.call("present", true, true)):
		_capture_failure("native recovery did not bind and present")
		quit(1)
		return
	recovery.queue_accessibility_update()
	var retry := recovery.get("retry_button") as Button
	recovery.connect("retry_requested", func() -> void:
		_activations += 1
		recovery.call("dismiss")
		source_canvas.set("accessibility_withdrawn", false))
	retry.pressed.connect(func() -> void: _pressed_signals += 1)
	retry.pressed.emit()
	for frame: int in 3: await process_frame
	if _activations != 0 or _pressed_signals != 1:
		print("RESULT " + JSON.stringify({"ok": false,
			"code": "programmatic_pressed_admitted"}))
		quit(1)
		return
	_pressed_signals = 0
	retry.grab_focus()
	retry.queue_accessibility_update()
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	print("READY " + JSON.stringify({"pid": pid, "window_title": title,
		"control": "Retry", "expected_caption": retry.text,
		"withdrawn_source_label": source_probe.text,
		"activations": _activations,
		"physical_contacts": input_owner.get_physical_contacts().size(),
		"programmatic_pressed_rejected": true, "source_image": source_path,
		"scope": "native UIA provider and guarded recovery Retry presentation; no storage-Retry claim"}))
	while _activations == 0 and _pressed_signals == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	for frame: int in 6: await process_frame
	var source_preserved: bool = source.is_visible_in_tree() and source.texture == source_texture
	var overlay_hidden: bool = not recovery.is_visible_in_tree()
	var source_accessibility_restored: bool = not bool(
		source_canvas.get("accessibility_withdrawn"))
	var ok: bool = _activations == 1 and _pressed_signals == 0 \
		and input_owner.get_physical_contacts().is_empty() and source_preserved and overlay_hidden \
		and source_accessibility_restored
	print("RESULT " + JSON.stringify({"ok": ok, "activations": _activations,
		"pressed_signals": _pressed_signals,
		"physical_contacts": input_owner.get_physical_contacts().size(),
		"source_image_preserved": source_preserved, "overlay_hidden": overlay_hidden,
		"source_accessibility_restored": source_accessibility_restored,
		"uia_tree_expected_hidden_while_presented": true, "storage_retry_invoked": false}))
	quit(0 if ok else 1)


func _capture_failure(message: String) -> void:
	_capture_failures.append(message)
	push_error("WITNESSED_READING_RECOVERY_CAPTURE_FAILED: " + message)
