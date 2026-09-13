extends SceneTree
## Isolated pixel and native-provider probe for the Ending recovery projection.
## The underlay is synthetic; this proves no narrative, recovery-owner, or route behavior.

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const ENDING := preload("res://scenes/ending/EndingScene.tscn")
const COPY := {
	"en": ["Retry", "Unable to continue. Please retry."],
	"zh_CN": ["重试", "暂时无法继续。请重试。"],
	"zh_HK": ["重試", "暫時無法繼續。請重試。"],
}

class ProbeEnding extends "res://scripts/ui/EndingScene.gd":
	# This records entry into the projection handler. The fixture deliberately has no
	# ending ports, so the count is not evidence that a real retry operation ran.
	var retry_requests := 0
	func _on_return_pressed() -> void:
		retry_requests += 1
		super()

var _folder := ""
var _activations := 0
var _pressed_signals := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests").replace("\\", "/").simplify_path().trim_suffix("/")
	if not isolated.to_lower().begins_with(allowed.to_lower() + "/") \
			or not DirAccess.dir_exists_absolute(isolated) or DisplayServer.get_name() == "headless":
		_fail("isolated visible DWM_TEST_ROOT required")
		return
	var profile: Node = root.get_node_or_null("ProfileManager")
	var localization: Node = root.get_node_or_null("LocalizationManager")
	if profile == null or localization == null \
			or not profile.initialize(STORAGE.new(isolated.path_join("ending-recovery-profile"))).get("ok", false) \
			or not localization.initialize(profile).get("ok", false) \
			or not profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false):
		_fail("isolated profile/localization setup")
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	for frame: int in 3: await process_frame
	if "--native-invoke" in OS.get_cmdline_user_args():
		await _native_invoke(localization)
	else:
		await _capture_locales(isolated, localization)


func _capture_locales(isolated: String, localization: Node) -> void:
	_folder = isolated.path_join("ending-recovery")
	if DirAccess.make_dir_recursive_absolute(_folder) != OK:
		_fail("capture directory")
		return
	var captures: Array[Dictionary] = []
	for locale: String in ["en", "zh_CN", "zh_HK"]:
		if not localization.set_locale(locale).get("ok", false):
			_fail("locale " + locale)
			return
		var mounted: Dictionary = await _mount(false)
		var scene: Control = mounted.scene
		var underlay: CanvasLayer = mounted.underlay
		var recovery := _projection(scene, true)
		var recovery_path := _folder.path_join(locale.replace("_", "-") + "-recovery-150.png")
		if not await _capture(recovery_path):
			_fail("recovery capture " + locale)
			return
		if not recovery.ok or recovery.button != COPY[locale][0] or recovery.body != COPY[locale][1]:
			_fail("recovery projection " + locale + " " + JSON.stringify(recovery))
			return
		captures.append({"locale": locale, "state": "recovery", "file": recovery_path,
			"body": recovery.body, "button": recovery.button, "panel_rect": recovery.panel_rect,
			"canvas_layer": recovery.canvas_layer})
		scene.call("_set_playback_status", false)
		for frame: int in 2: await process_frame
		var normal := _projection(scene, false)
		if not normal.ok:
			_fail("normal projection " + locale + " " + JSON.stringify(normal))
			return
		var normal_path := _folder.path_join(locale.replace("_", "-") + "-normal-150.png")
		if not await _capture(normal_path):
			_fail("normal capture " + locale)
			return
		captures.append({"locale": locale, "state": "normal_hidden", "file": normal_path,
			"title_hidden": normal.title_hidden, "body_hidden": normal.body_hidden,
			"button_hidden": normal.button_hidden, "panel_hidden": normal.panel_hidden})
		scene.free()
		underlay.free()
		await process_frame
	print("ENDING_RECOVERY_CAPTURE " + JSON.stringify({"captures": captures,
		"scope": "actual EndingScene no-ports recovery projection over a synthetic material underlay; no narrative, retry-operation, recovery-owner, durability, or route claim"}))
	quit(0)


func _native_invoke(localization: Node) -> void:
	if not is_accessibility_enabled():
		_fail("native accessibility evidence requires --accessibility always")
		return
	if not localization.set_locale("en").get("ok", false):
		_fail("English locale")
		return
	var input_owner: Node = root.get_node_or_null("InputManager")
	if input_owner == null:
		_fail("InputManager")
		return
	var pid := OS.get_process_id()
	var title := "DWM Ending Recovery Accessibility %d" % pid
	DisplayServer.window_set_title(title)
	var mounted: Dictionary = await _mount(true)
	var scene: Control = mounted.scene
	var normal_ready := false
	scene.call("_set_playback_status", false)
	for frame: int in 2: await process_frame
	normal_ready = bool(_projection(scene, false).get("ok", false))
	scene.call("_set_playback_status", true)
	for frame: int in 3: await process_frame
	var recovery := _projection(scene, true)
	var button: Button = scene.get_node_or_null("%ReturnToMenuButton") as Button
	if not normal_ready or not recovery.ok or recovery.button != COPY.en[0] \
			or recovery.body != COPY.en[1] or button == null or not button.has_signal("activated"):
		_fail("native projection contract")
		return
	button.connect(&"activated", func() -> void: _activations += 1)
	button.pressed.connect(func() -> void: _pressed_signals += 1)
	button.pressed.emit()
	for frame: int in 3: await process_frame
	if _activations != 0 or int(scene.get("retry_requests")) != 0 or _pressed_signals != 1:
		print("RESULT " + JSON.stringify({"ok": false, "code": "programmatic_pressed_admitted",
			"activations": _activations, "retry_requests": int(scene.get("retry_requests"))}))
		quit(1)
		return
	_pressed_signals = 0
	button.grab_focus()
	button.queue_accessibility_update()
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	print("READY " + JSON.stringify({"pid": pid, "window_title": title, "locale": "en",
		"expected_caption": button.text, "body": recovery.body, "activations": _activations,
		"retry_requests": int(scene.get("retry_requests")), "pressed_signals": _pressed_signals,
		"physical_contacts": input_owner.get_physical_contacts().size(),
		"normal_hidden_verified": normal_ready, "programmatic_pressed_rejected": true,
		"scope": "native Windows UIA provider and actual EndingScene no-ports recovery projection; handler entry only, with no retry-operation, recovery-owner, durability, or route claim"}))
	var deadline := Time.get_ticks_msec() + 30000
	while _activations == 0 and _pressed_signals == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	for frame: int in 6: await process_frame
	var ok: bool = _activations == 1 and int(scene.get("retry_requests")) == 1 \
		and _pressed_signals == 0 and input_owner.get_physical_contacts().is_empty()
	print("RESULT " + JSON.stringify({"ok": ok, "activations": _activations,
		"retry_requests": int(scene.get("retry_requests")), "pressed_signals": _pressed_signals,
		"physical_contacts": input_owner.get_physical_contacts().size()}))
	quit(0 if ok else 1)


func _mount(probe: bool) -> Dictionary:
	# Dialogic's real default layout base is a layer-1 CanvasLayer. An opaque stand-in
	# prevents this probe from falsely approving a recovery Control drawn underneath it.
	var underlay := CanvasLayer.new()
	underlay.name = "SyntheticTrustworthyUnderlay"
	underlay.layer = 1
	root.add_child(underlay)
	var field := ColorRect.new()
	field.name = "MaterialField"
	field.color = Color("171a20")
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underlay.add_child(field)
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scene: Control = ENDING.instantiate()
	if probe: scene.set_script(ProbeEnding)
	root.add_child(scene)
	for frame: int in 4: await process_frame
	return {"scene": scene, "underlay": underlay}


func _projection(scene: Control, recovery: bool) -> Dictionary:
	var title: Control = scene.get_node_or_null("%EndingTitleLabel") as Control
	var body: Label = scene.get_node_or_null("%EndingBodyLabel") as Label
	var button: Button = scene.get_node_or_null("%ReturnToMenuButton") as Button
	var panel: Control = body.get_parent() as Control if body != null else null
	while panel != null and not panel is PanelContainer and panel != scene:
		panel = panel.get_parent() as Control
	var title_hidden := title == null or not title.is_visible_in_tree()
	var body_hidden := body == null or not body.is_visible_in_tree() or body.text.is_empty()
	var button_hidden := button == null or not button.is_visible_in_tree()
	var panel_hidden := panel == null or not panel.is_visible_in_tree()
	if not recovery:
		return {"ok": title_hidden and body_hidden and button_hidden and panel_hidden and button != null \
			and button.disabled and button.focus_mode == Control.FOCUS_NONE,
			"title_hidden": title_hidden, "body_hidden": body_hidden,
			"button_hidden": button_hidden, "panel_hidden": panel_hidden}
	var panel_rect := []
	if panel != null:
		panel_rect = [panel.global_position.x, panel.global_position.y, panel.size.x, panel.size.y]
	var canvas_layer := 0
	var ancestor: Node = panel
	while ancestor != null and ancestor != scene:
		if ancestor is CanvasLayer:
			canvas_layer = (ancestor as CanvasLayer).layer
			break
		ancestor = ancestor.get_parent()
	return {"ok": title_hidden and canvas_layer > 1 \
		and panel != null and panel.is_visible_in_tree() \
		and body != null and body.is_visible_in_tree() \
		and not body.text.is_empty() and button != null and button.is_visible_in_tree() \
		and not button.disabled and button.focus_mode != Control.FOCUS_NONE \
		and button.size.x > 0.0 and button.size.y >= 48.0,
		"title_hidden": title_hidden, "body": body.text if body != null else "",
		"button": button.text if button != null else "", "panel_rect": panel_rect,
		"canvas_layer": canvas_layer}


func _capture(path: String) -> bool:
	for frame: int in 3: await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	return pixels != null and pixels.save_png(path) == OK


func _fail(message: String) -> void:
	push_error("ENDING_RECOVERY_PROBE_FAIL: " + message)
	quit(1)
