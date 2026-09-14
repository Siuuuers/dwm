extends "res://tests/ui/render_witnessed_caption.gd"
## Mounted synthetic-caption renders of the factual speech failure status.
## These images do not establish human screen-reader or speech parity.

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")

var _capture_failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var allocated: Dictionary = TEMPORARY_STORAGE.create("witnessed-speech-status-capture")
	if not allocated.get("ok", false) or DisplayServer.get_name() != "Windows":
		printerr("WITNESSED_SPEECH_STATUS_CAPTURE_FAILED root/display ", allocated)
		quit(1)
		return
	var isolated := str(allocated.value)
	var profile: Node = root.get_node_or_null("ProfileManager")
	var localization: Node = root.get_node_or_null("LocalizationManager")
	if profile == null or localization == null:
		printerr("WITNESSED_SPEECH_STATUS_CAPTURE_FAILED owner initialization")
		quit(1)
		return
	var profile_result: Dictionary = profile.call(&"initialize",
		STORAGE.new(isolated.path_join("profile")))
	var localization_result: Dictionary = localization.call(&"initialize", profile)
	if not profile_result.get("ok", false) or not localization_result.get("ok", false):
		printerr("WITNESSED_SPEECH_STATUS_CAPTURE_FAILED owner initialization")
		quit(1)
		return
	for frame: int in 3: await process_frame
	_folder = isolated.path_join("witnessed-speech-status")
	if DirAccess.make_dir_recursive_absolute(_folder) != OK or not await _mount():
		quit(1)
		return

	var captures: Array[Dictionary] = []
	for locale: String in ["en", "zh-CN", "zh-HK"]:
		var locale_result: Dictionary = localization.call(
			&"set_locale", locale.replace("-", "_"))
		if not locale_result.get("ok", false) \
				or not await _show_fixture(locale, 150, "AfterHours", false):
			_capture_failures.append(locale + " mounted caption fixture failed")
			break
		var status: Label = _caption.get_node_or_null("Canvas/Overlay/SpeechStatus")
		if status == null or status.visible:
			_capture_failures.append(locale + " status was not clean before publication")
			break
		var source_invariants: Dictionary = _invariants()
		var source_projection: Dictionary = _caption.get_caption_projection()
		var before: Image = _viewport.get_texture().get_image()
		if before == null or not bool(status.call(&"show_failure")):
			_capture_failures.append(locale + " status publication failed")
			break
		await _frames()
		var after: Image = _viewport.get_texture().get_image()
		var status_rect := Rect2i(status.get_global_rect())
		var difference := _difference(before, after, status_rect)
		var focus_owner: Control = _viewport.gui_get_focus_owner()
		var projection_after: Dictionary = _caption.get_caption_projection()
		var filename := locale + "-150-speech-failure.png"
		var file_path := _folder.path_join(filename)
		var saved: bool = after != null and after.save_png(file_path) == OK
		var valid: bool = saved and status.visible and not status.text.strip_edges().is_empty() \
			and status.text == status.accessibility_name \
			and status.language == locale \
			and status.accessibility_live == DisplayServer.LIVE_POLITE \
			and status.focus_mode == Control.FOCUS_NONE and not status.has_focus() \
			and difference.changed_pixels > 0 and difference.outside_pixels == 0 \
			and status_rect.encloses(difference.bounds) \
			and before.get_size() == Vector2i(1280, 720) \
			and after.get_size() == before.get_size() \
			and _invariants() == source_invariants \
			and projection_after.text == source_projection.text \
			and projection_after.retained_captions == source_projection.retained_captions \
			and projection_after.caption_rect == source_projection.caption_rect \
			and _caption.caption_text.visible_ratio == 1.0
		if not valid:
			_capture_failures.append(locale + " status render contract failed")
			break
		captures.append({
			"locale": locale, "text_percent": 150, "file": file_path,
			"image_size": [after.get_width(), after.get_height()],
			"status_text": status.text, "accessibility_name": status.accessibility_name,
			"accessibility_live": "polite", "status_rect": str(status_rect),
			"text_pixel_bounds": str(difference.bounds),
			"changed_pixels": difference.changed_pixels,
			"outside_status_pixels_changed": difference.outside_pixels,
			"status_focus_mode": "none", "status_has_focus": status.has_focus(),
			"focus_owner": str(focus_owner.get_path()) if focus_owner != null else "",
			"current_caption": projection_after.text,
			"current_caption_rect": str(projection_after.caption_rect),
			"retained_captions": projection_after.retained_captions,
			"caption_fully_revealed": _caption.caption_text.visible_ratio == 1.0,
			"caption_state_preserved": true,
			"synthetic_substrate_outside_status_preserved": true,
		})
		status.call(&"clear_status")
		await _frames()

	var report_path := _folder.path_join("measurements.json")
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({
			"scope": "Synthetic captions through the installed Witnessed style and its actual mounted polite speech status; no authored-story, human audibility, or screen-reader parity claim",
			"captures": captures, "failures": _capture_failures,
		}, "\t") + "\n")
		report.close()
	else:
		_capture_failures.append("measurements write failed")
	await _restore()
	var ok: bool = captures.size() == 3 and _capture_failures.is_empty() and report != null
	print("WITNESSED_SPEECH_STATUS_CAPTURE " + JSON.stringify({"ok": ok,
		"captures": captures.size(), "failures": _capture_failures,
		"evidence": _folder, "measurements": report_path}))
	quit(0 if ok else 1)


func _difference(before: Image, after: Image, allowed: Rect2i) -> Dictionary:
	if before == null or after == null or before.get_size() != after.get_size():
		return {"bounds": Rect2i(), "changed_pixels": 0, "outside_pixels": -1}
	var minimum := before.get_size()
	var maximum := Vector2i(-1, -1)
	var changed := 0
	var outside := 0
	for y: int in before.get_height():
		for x: int in before.get_width():
			var point := Vector2i(x, y)
			if before.get_pixelv(point) == after.get_pixelv(point): continue
			changed += 1
			minimum = Vector2i(mini(minimum.x, x), mini(minimum.y, y))
			maximum = Vector2i(maxi(maximum.x, x), maxi(maximum.y, y))
			if not allowed.has_point(point): outside += 1
	var bounds := Rect2i()
	if changed > 0: bounds = Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	return {"bounds": bounds, "changed_pixels": changed, "outside_pixels": outside}
