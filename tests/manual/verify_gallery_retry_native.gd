extends SceneTree
## Mounted Gallery retry rendering at the native half-size window used by release captures.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const ART := preload("res://scripts/data/ArtManifest.gd")

const LOCALES := ["en", "zh_CN", "zh_HK"]
const PERCENTS := [100, 125, 150]
const PALETTES := ["AfterHours", "Midnight"]

class ReplayBridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	var fail_start := true
	var starts: Array[String] = []
	var active_signature := ""
	var active_token := ""
	var ordinal := 0

	func configure_reached_replay(_profile: Object) -> Dictionary:
		return {"ok": true}

	func replay_reached_signature(signature_id: String) -> Dictionary:
		starts.append(signature_id)
		if fail_start:
			return {"ok": false, "code": &"runtime_start_failed", "value": null,
				"failure_phase": &"start", "signature_id": signature_id,
				"playback_token": ""}
		ordinal += 1
		active_signature = signature_id
		active_token = "gallery-retry-native:%d" % ordinal
		return {"ok": true, "receipt": {"playback_token": active_token}}

	func complete() -> void:
		var result := {"signature_id": active_signature, "playback_token": active_token,
			"outcome": "completed", "code": &""}
		active_signature = ""
		active_token = ""
		reached_replay_finished.emit(result)

	func cancel_reached_replay(_signature_id: String) -> Dictionary:
		active_signature = ""
		active_token = ""
		return {"ok": true}


var _viewport: SubViewport
var _profile: Node
var _localization: Node
var _gallery: Control
var _bridge := ReplayBridge.new()
var _folder := ""
var _samples: Array[Dictionary] = []
var _failures: Array[String] = []
var _checks := 0
var _captures := 0
var _deadline := 0
var _evidence_ready := false
var _art_overridden := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_deadline = Time.get_ticks_msec() + 60000
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests").replace("\\", "/").simplify_path().trim_suffix("/")
	var wrapper_root := isolated.get_base_dir()
	_folder = ProjectSettings.globalize_path("user://evidence/gallery_retry_native").replace("\\", "/").simplify_path()
	if not _check(isolated.get_file() == "dwm_test_root" and wrapper_root.to_lower().begins_with(allowed.to_lower() + "/")
			and DirAccess.dir_exists_absolute(isolated), "invalid isolated test root") \
			or not _check(_folder.to_lower().begins_with(wrapper_root.to_lower() + "/appdata/"),
				"evidence path escapes the isolated test root") \
			or not _check(DisplayServer.get_name() != "headless", "native renderer unavailable") \
			or not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "evidence directory unavailable"):
		_finish()
		return
	_evidence_ready = true
	ART.reload_placements()
	ART.set_overlay_info("", "cg.ending.alone.normal",
		"res://tests/fixtures/art/placement-cg.svg", Vector2i(1280, 448), "fixture")
	_art_overridden = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.size_2d_override = Vector2i(1280, 720)
	_viewport.size_2d_override_stretch = true
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_profile = PROFILE.new()
	_localization = LOCALIZATION.new()
	_viewport.add_child(_profile)
	_viewport.add_child(_localization)
	var files := FILES.new()
	if not _check(_profile.initialize(STORAGE.new(isolated.path_join("gallery-retry-native/profile"), files)).get("ok", false),
			"real Profile failed to initialize") \
			or not _check(_localization.initialize(_profile).get("ok", false), "real localization failed to initialize"):
		_finish()
		return
	var candidate: Dictionary = _profile.get_profile_snapshot()
	candidate.preferences.dark_mode.available = true
	if not _check(_profile.commit_prepared_profile(candidate).get("ok", false), "Standard palette capability unavailable"):
		_finish()
		return
	for signature: Dictionary in [_alone("ending.alone.normal", "alone_normal"),
			_alone("ending.alone.dark_mode", "alone_dark_mode")]:
		if not _check(_profile.record_reached_presentation(signature).get("ok", false), "reached fixture rejected"):
			_finish()
			return
	if not _check(_profile.unlock_ending("ending.alone", "gallery-retry-native:fixture").get("ok", false),
			"discovery fixture rejected"):
		_finish()
		return
	var home := Button.new()
	_viewport.add_child(home)
	_gallery = GALLERY.instantiate()
	if not _check(_gallery.configure_title_host(home, _localization, _profile).get("ok", false), "Gallery host rejected") \
			or not _check(_gallery.configure_replay(_bridge).get("ok", false), "real replay owner rejected"):
		_finish()
		return
	_viewport.add_child(_gallery)
	_gallery.open_in_title_host()
	await _frames()
	var normal_index := -1
	var versions: Array = _gallery.get("_versions")
	for index: int in range(versions.size()):
		if str(versions[index].signature.entry_id) == "ending.alone.normal": normal_index = index
	if not _check(normal_index >= 0, "normal reached presentation unavailable"):
		_finish()
		return
	(_gallery.get("_version_selector") as OptionButton).item_selected.emit(normal_index)
	await _frames()
	for locale: String in LOCALES:
		for percent: int in PERCENTS:
			for palette: String in PALETTES:
				if not await _sample(locale, percent, palette):
					_finish()
					return
	_check(_samples.size() == 18, "incomplete 18-tuple matrix")
	_finish()


func _alone(entry_id: String, form: String) -> Dictionary:
	return {"entry_id": entry_id, "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": form}}


func _sample(locale: String, percent: int, palette: String) -> bool:
	if not _check(Time.get_ticks_msec() < _deadline, "capture deadline exceeded"):
		return false
	if not _check(_localization.set_locale(locale).get("ok", false), "locale rejected: " + locale):
		return false
	var preferences := {
		&"preferences.accessibility.text_size": percent,
		&"preferences.accessibility.high_contrast": false,
		&"preferences.accessibility.colour_differentiation": "standard",
		&"preferences.dark_mode.next_run_enabled": palette == "Midnight",
	}
	if not _check(_profile.set_preferences(preferences).get("ok", false), "presentation preferences rejected"):
		return false
	await _frames()
	var replay: Button = _gallery.get_node("%ReplayButton")
	var status: Label = _gallery.get_node("%ReplayStatus")
	var picker: OptionButton = _gallery.get("_version_selector")
	var title: Label = _gallery.get_node("%GalleryHost/RecordTitle")
	var signature := str(_gallery.call("_selected_signature_id"))
	if not _check(not signature.is_empty(), "Gallery selected no reached signature"): return false
	var starts_before := _bridge.starts.size()
	_bridge.fail_start = true
	replay.grab_focus()
	await _key(KEY_ENTER)
	if not _check(_bridge.starts.size() == starts_before + 1 and _bridge.starts[-1] == signature,
			"Replay did not submit the exact selected signature") \
			or not _check(replay.has_focus(), "start Error did not retain Replay focus") \
			or not _check(status.text == _localization.t("gallery.replay.start_failed"), "localized start Error changed") \
			or not _check(replay.text == _localization.t("gallery.retry"), "localized Retry changed"):
		return false
	var geometry := _geometry(status, replay, picker, title)
	if not geometry.get("ok", false): return false
	var filename := "%s-%d-%s-error.png" % [locale.replace("_", "-"), percent, palette]
	var image := await _capture(filename)
	if image == null: return false
	var pixels := _pixel_proof(image, _gallery.theme)
	if not pixels.get("ok", false): return false
	var success_file := ""
	if _samples.is_empty():
		_bridge.fail_start = false
		await _key(KEY_ENTER)
		if not _check(_bridge.starts.size() == starts_before + 2 and _bridge.starts[-1] == signature,
				"Retry did not reuse the failed signature") \
				or not _check(status.text == _localization.t("gallery.replay.playing"), "successful Retry did not enter Playing"):
			return false
		success_file = "en-100-AfterHours-retry-success.png"
		if await _capture(success_file) == null: return false
		_bridge.complete()
		await _frames()
		if not _check(replay.has_focus(), "completed Retry did not restore Replay focus"): return false
	_samples.append({"locale": locale, "text_percent": percent, "palette": palette,
		"high_contrast": false, "colour_differentiation": "standard",
		"error_file": filename, "retry_success_file": success_file,
		"status_copy": status.text if success_file.is_empty() else _localization.t("gallery.replay.start_failed"),
		"retry_copy": _localization.t("gallery.retry"), "signature_id": signature,
		"geometry": geometry, "pixels": pixels, "focus_retained": true})
	return _failures.is_empty()


func _geometry(status: Label, replay: Button, picker: OptionButton, title: Label) -> Dictionary:
	var status_rect := Rect2(status.position, status.size)
	var replay_rect := Rect2(replay.position, replay.size)
	var picker_rect := Rect2(picker.position, picker.size)
	var title_rect := Rect2(title.position, title.size)
	var font := replay.get_theme_font("font")
	var text_width := font.get_string_size(replay.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		replay.get_theme_font_size("font_size")).x
	var ok := _check(status_rect == Rect2(408, 568, 360, 64), "Error status rectangle changed") \
		and _check(replay_rect == Rect2(776, 568, 160, 64), "Replay rectangle changed") \
		and _check(picker_rect == Rect2(408, 488, 288, 64), "version picker rectangle changed") \
		and _check(title.position == Vector2(392, 32) and title.size.x == 504,
			"compact title has a reserved media gap or wrong measure") \
		and _check(title.visible and not title.text.is_empty() and title.get_minimum_size().y <= title.size.y,
			"compact title is hidden or clipped") \
		and _check(not picker_rect.intersects(title_rect), "version picker overlaps record title") \
		and _check(_gallery.get_node_or_null("%GalleryHost/GalleryArtworkPreview") == null,
			"unregistered scene artwork still owns Gallery geometry") \
		and _check(status.get_line_count() <= 2 and status.get_minimum_size().y <= status.size.y,
			"Error status overflows its two-line dock") \
		and _check(not replay.text.contains("\n") and text_width <= replay.size.x,
			"Replay/Retry does not fit one line")
	return {"ok": ok, "status": [408, 568, 360, 64], "replay": [776, 568, 160, 64],
		"picker": [408, 488, 288, 64], "title": [392, 32, 504, title.size.y], "status_lines": status.get_line_count(),
		"replay_text_width": text_width}


func _pixel_proof(image: Image, gallery_theme: Theme) -> Dictionary:
	var face := gallery_theme.get_color("face", "Gallery")
	var rule := gallery_theme.get_color("error_rule", "Gallery")
	var ink := gallery_theme.get_color("error_ink", "Gallery")
	var dock_point := Vector2i(200, 282)
	var rule_point := Vector2i(196, 300)
	var ink_point := _find_ink(image, Rect2i(204, 284, 180, 32), ink, face)
	var paper := gallery_theme.get_color("paper", "Gallery")
	var title: Label = _gallery.get_node("%GalleryHost/RecordTitle")
	var title_ink := _find_ink(image, Rect2i(196, 16, 252, int(title.size.y / 2)),
		gallery_theme.get_color("paper_ink", "Gallery"), paper)
	var nonpaper_pixels := 0
	for y: int in range(16 + int(title.size.y / 2), 240, 4):
		for x: int in range(200, 456, 4):
			if not _near_rgb8(image.get_pixel(x, y), paper): nonpaper_pixels += 1
	var ok := _check(image.get_size() == Vector2i(640, 360), "native capture size changed") \
		and _check(_near_rgb8(image.get_pixelv(dock_point), face), "dock face sample changed") \
		and _check(_near_rgb8(image.get_pixelv(rule_point), rule), "2x48 Error rule sample changed") \
		and _check(ink_point != Vector2i(-1, -1), "Error status has no protected ink pixel") \
		and _check(title_ink != Vector2i(-1, -1), "compact title has no native ink pixels") \
		and _check(nonpaper_pixels == 0, "unregistered media painted the bare record paper")
	return {"ok": ok, "dock_point": [dock_point.x, dock_point.y],
		"rule_point": [rule_point.x, rule_point.y], "ink_point": [ink_point.x, ink_point.y],
		"dock_rgb": image.get_pixelv(dock_point).to_html(false),
		"rule_rgb": image.get_pixelv(rule_point).to_html(false),
		"title_ink_point": [title_ink.x, title_ink.y], "nonpaper_sample_count": nonpaper_pixels}


func _find_ink(image: Image, rect: Rect2i, ink: Color, face: Color) -> Vector2i:
	# The existing Source Sans/Han fonts are antialiased. Require a high-coverage
	# glyph pixel with the expected foreground/background blend, not a solid fill.
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var actual := image.get_pixel(x, y)
			var coverage := (actual.r - face.r) / (ink.r - face.r)
			if coverage >= 0.8 and coverage <= 1.01 and _near_rgb8(actual, face.lerp(ink, coverage)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


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
	for _frame: int in 3: await RenderingServer.frame_post_draw


func _capture(filename: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	if image == null or not _check(image.save_png(_folder.path_join(filename)) == OK, "PNG write failed: " + filename):
		return null
	_captures += 1
	return image


func _near_rgb8(actual: Color, expected: Color) -> bool:
	return absi(roundi(actual.r * 255.0) - roundi(expected.r * 255.0)) <= 1 \
		and absi(roundi(actual.g * 255.0) - roundi(expected.g * 255.0)) <= 1 \
		and absi(roundi(actual.b * 255.0) - roundi(expected.b * 255.0)) <= 1


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("GALLERY_RETRY_NATIVE_FAILED: " + message)
	return condition


func _finish() -> void:
	if _evidence_ready:
		var report := FileAccess.open(_folder.path_join("gallery-retry-native.json"), FileAccess.WRITE)
		if report != null:
			var retry_success := false
			for sample: Dictionary in _samples:
				if not str(sample.get("retry_success_file", "")).is_empty(): retry_success = true
			report.store_string(JSON.stringify({"ok": _failures.is_empty(), "failures": _failures,
				"checks": _checks, "captures": _captures, "requested_tuples": 18,
				"tuple_count": _samples.size(), "matrix_complete": _samples.size() == 18,
				"retry_success_proved": retry_success, "bridge_start_count": _bridge.starts.size(),
				"native_size": [640, 360], "logical_size": [1280, 720], "samples": _samples,
				"art_fixture": "res://tests/fixtures/art/placement-cg.svg",
				"scope": "Mounted Gallery, real Profile/catalogs/themes, injected viewport keyboard, exact pre-session Retry and native pixels; no hardware input, UIA, full visual-conformance, storage-Retry, or whole-journey claim."}, "\t") + "\n")
			report.close()
	print("GALLERY_RETRY_NATIVE_", "VERIFIED" if _failures.is_empty() else "FAILED",
		" captures=", _captures, " tuples=", _samples.size(), " evidence=", _folder)
	if _art_overridden: ART.reload_placements()
	if is_instance_valid(_viewport): _viewport.queue_free()
	quit(0 if _failures.is_empty() else 1)
