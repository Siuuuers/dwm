extends SceneTree
## Noncanonical TEST catalogue cues; real Gallery/Profile owners and viewport keys.
## Run only in GitHub Actions with the standard Godot 4.6.3 renderer.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const CATALOG := preload("res://scripts/ui/gallery/GalleryRecordCatalog.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")

class ReplayBridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	var starts: Array[String] = []
	func configure_reached_replay(_profile: Object) -> Dictionary:
		return {"ok": true}
	func replay_reached_signature(signature_id: String) -> Dictionary:
		starts.append(signature_id)
		return {"ok": false, "code": &"runtime_start_failed", "failure_phase": &"start"}
	func cancel_reached_replay(_signature_id: String) -> Dictionary:
		return {"ok": true}

var _viewport: SubViewport
var _profile: Node
var _localization: Node
var _gallery: Control
var _files := FILES.new()
var _bridge := ReplayBridge.new()
var _folder := ""
var _samples: Array[Dictionary] = []
var _failures: Array[String] = []
var _checks := 0
var _collapsed_counts: Array[int] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_folder = OS.get_environment("DWM_GALLERY_REGISTER_OUTPUT")
	if _folder.is_empty(): _folder = ProjectSettings.globalize_path("user://evidence/gallery_version_register")
	if not _check(DisplayServer.get_name() != "headless", "renderer unavailable") \
			or not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "evidence directory unavailable"):
		_finish()
		return
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
	var isolated := OS.get_environment("DWM_TEST_ROOT")
	if isolated.is_empty(): isolated = "user://gallery-version-register-fixture"
	if not _check(_profile.initialize(STORAGE.new(isolated.path_join("profile"), _files)).get("ok", false), "Profile initialization") \
			or not _check(_localization.initialize(_profile).get("ok", false), "Localization initialization"):
		_finish()
		return
	var candidate: Dictionary = _profile.get_profile_snapshot()
	candidate.preferences.dark_mode.available = true
	if not _check(_profile.commit_prepared_profile(candidate).get("ok", false), "palette capability") \
			or not _check(_profile.unlock_ending("ending.alone", "gallery-version-register:TEST").get("ok", false), "fixture discovery"):
		_finish()
		return
	var home := Button.new()
	_viewport.add_child(home)
	_gallery = GALLERY.instantiate()
	_gallery.set("_record_catalog", _catalog())
	if not _check(_gallery.configure_title_host(home, _localization, _profile).get("ok", false), "Gallery host") \
			or not _check(_gallery.configure_replay(_bridge).get("ok", false), "Replay owner"):
		_finish()
		return
	_viewport.add_child(_gallery)
	_gallery.open_in_title_host()
	await _frames()
	if not _collapse(0):
		_finish()
		return
	for dark: bool in [false, true]:
		if not _check(_profile.record_reached_presentation(_alone(dark)).get("ok", false), "reached fixture"):
			_finish()
			return
		_profile.publish_restore()
		await _frames()
		if not dark and not _collapse(1):
			_finish()
			return
	for locale: String in ["en", "zh_CN", "zh_HK"]:
		for percent: int in [100, 125, 150]:
			for palette: String in ["AfterHours", "Midnight"]:
				if not await _sample(locale, percent, palette):
					_finish()
					return
	_check(_samples.size() == 18, "incomplete matrix")
	var fitting := false
	var overflowing := false
	for sample: Dictionary in _samples:
		fitting = fitting or float(sample.paper_content_extent) <= 512.0
		overflowing = overflowing or float(sample.paper_content_extent) > 512.0
	_check(fitting and overflowing, "missing fitting or overflowing rendered paper")
	_finish()

func _alone(dark: bool) -> Dictionary:
	return {"entry_id": "ending.alone.dark_mode" if dark else "ending.alone.normal", "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": "alone_dark_mode" if dark else "alone_normal"}}

func _id(dark: bool) -> String:
	return str(SIGNATURE.validate(_alone(dark)).value.signature_id)

func _catalog(long_copy: bool = false, wrapped_cues: bool = false) -> RefCounted:
	# Repeated noncanonical text deliberately produces a real overflowing paper.
	var repeat_count := 12 if long_copy else 1
	var base := ["TEST paper layout sentence. ".repeat(repeat_count),
		"TEST 纸面布局测试句子。".repeat(repeat_count), "TEST 紙面佈局測試句子。".repeat(repeat_count)]
	var entries: Array = []
	for dark: bool in [false, true]:
		var mark := "B" if dark else "A"
		entries.append({"signature": _alone(dark),
			"sentence": [base[0] + mark, base[1] + mark, base[2] + mark],
			"version_cue": ["TEST paper specimen ".repeat(7 if wrapped_cues else 1) + mark,
				"TEST 纸面样本 ".repeat(7 if wrapped_cues else 1) + mark,
				"TEST 紙面樣本 ".repeat(7 if wrapped_cues else 1) + mark]})
	return CATALOG.new({}, entries)

func _collapse(count: int) -> bool:
	var register: Control = _gallery.get("_version_register")
	var versions: Array = _gallery.get("_versions")
	var ok := _check(versions.size() == count, "collapsed version count") \
		and _check(not register.visible and register.size.y == 0 and register.get_rows().is_empty(),
			"zero/single register retained geometry or rows") \
		and _check(register.focus_mode == Control.FOCUS_NONE, "collapsed register retained focus")
	if ok: _collapsed_counts.append(count)
	return ok

func _sample(locale: String, percent: int, palette: String) -> bool:
	_gallery.set("_record_catalog", _catalog(percent == 150, percent == 125))
	_gallery.call("_refresh_replay_selection")
	if not _check(_localization.set_locale(locale).get("ok", false), "locale rejected") \
			or not _check(_profile.set_preferences({
				&"preferences.accessibility.text_size": percent,
				&"preferences.accessibility.high_contrast": false,
				&"preferences.accessibility.colour_differentiation": "standard",
				&"preferences.dark_mode.next_run_enabled": palette == "Midnight",
			}).get("ok", false), "preferences rejected"):
		return false
	await _frames()
	var before: Dictionary = _profile.get_profile_snapshot()
	var revision: int = _profile.get_profile_revision()
	var persisted: Dictionary = _files.snapshot_persisted()
	var operations: int = _files.operation_count()
	var register: Control = _gallery.get("_version_register")
	var rows: Array = register.get_rows()
	if not _check(register.visible and rows.size() == 2, "plural register missing") \
			or not _check(not (_gallery.get("_version_selector") as Control).visible, "legacy selector remained visible") \
			or not _check(rows[0] == register.row_for_signature(_id(true)) and rows[1] == register.row_for_signature(_id(false)), "witness chronology changed"):
		return false
	var cue_line_counts: Array[int] = []
	for row: Button in rows:
		cue_line_counts.append(row.caption.get_line_count())
		if percent == 125 and not _check(row.caption.get_line_count() > 1, "wrapped cue fixture did not wrap"):
			return false
		if not _check(row.text.begins_with("TEST ") and not row.text.contains("ending.") and not row.text.contains(_id(false))
				and not row.text.contains(_id(true)), "internal identity leaked into cue"):
			return false
	(rows[0] as Control).grab_focus()
	await _frames()
	await _key(KEY_DOWN)
	var selected: Button = register.row_for_signature(_id(false))
	var paper: Control = _gallery.get("_record_paper")
	if not _check(selected.has_focus() and selected.selected, "Down did not select/focus next exact version") \
			or not _check(str(_gallery.call("_selected_signature_id")) == _id(false), "exact selected identity changed") \
			or not _check(paper.sentence_label.text.ends_with("A"), "selection did not republish exact projection") \
			or not _check(paper.scroll_offset > 0 if paper.content_extent > paper.size.y else paper.scroll_offset == 0, "paper reveal did not match overflow") \
			or not _check(paper.get_global_rect().encloses(selected.get_global_rect().grow(8)), "focus perimeter clipped"):
		return false
	await _key(KEY_DOWN)
	if not _check(selected.has_focus(), "last version wrapped"): return false
	await _key(KEY_UP)
	if not _check(str(_gallery.call("_selected_signature_id")) == _id(true)
			and paper.sentence_label.text.ends_with("B"), "Up lost exact projection"): return false
	await _key(KEY_DOWN)
	selected = register.row_for_signature(_id(false))
	if not _check(_profile.get_profile_snapshot() == before and _profile.get_profile_revision() == revision
			and _files.snapshot_persisted() == persisted and _files.operation_count() == operations,
			"inspection changed profile or storage") \
			or not _check(_bridge.starts.is_empty(), "inspection started replay"):
		return false
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var filename := "%s-%d-%s.png" % [locale.replace("_", "-"), percent, palette]
	if not _check(image != null and image.get_size() == Vector2i(640, 360), "capture dimensions") \
			or not _check(image.save_png(_folder.path_join(filename)) == OK, "PNG write failed"):
		return false
	var rect := selected.get_global_rect()
	# Sample protected row body and both detached focus perimeter sides at x/2.
	var native := Rect2i(Vector2i(rect.position / 2), Vector2i(rect.size / 2))
	var face_point := native.position + Vector2i(2, 2)
	var left_point := Vector2i(native.position.x - 4, native.position.y + floori(native.size.y / 2.0))
	var right_point := Vector2i(native.end.x + 3, left_point.y)
	if not _check(_near(image.get_pixelv(face_point), _gallery.theme.get_color("filed", "Gallery")), "selected plane pixel") \
			or not _check(_near(image.get_pixelv(left_point), _gallery.theme.get_color("paper_ink", "Gallery"))
				and _near(image.get_pixelv(right_point), _gallery.theme.get_color("paper_ink", "Gallery")), "detached focus pixel sides"):
		return false
	_samples.append({"locale": locale, "percent": percent, "palette": palette, "file": filename,
		"selected_signature_id": _id(false), "selected_cue": selected.text,
		"cue_line_counts": cue_line_counts,
		"row_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"paper_scroll_offset": paper.scroll_offset, "paper_content_extent": paper.content_extent,
		"long_fixture_copy": percent == 150, "profile_revision": revision,
		"file_operations": operations, "inspection_writes": 0, "replay_starts": 0,
		"focus_perimeter_enclosed": true, "plane_and_focus_pixels": true})
	return true

func _near(actual: Color, expected: Color) -> bool:
	return absi(roundi(actual.r * 255) - roundi(expected.r * 255)) <= 1 \
		and absi(roundi(actual.g * 255) - roundi(expected.g * 255)) <= 1 \
		and absi(roundi(actual.b * 255) - roundi(expected.b * 255)) <= 1

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

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("GALLERY_VERSION_REGISTER_RENDER_FAILED: " + message)
	return condition

func _finish() -> void:
	if DirAccess.dir_exists_absolute(_folder):
		var report := FileAccess.open(_folder.path_join("measurements.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"ok": _failures.is_empty(), "checks": _checks,
				"failures": _failures, "samples": _samples, "requested_tuples": 18,
				"collapsed_counts": _collapsed_counts, "fixture_only_cues": true,
				"physical_size": [640, 360], "logical_size": [1280, 720],
				"scope": "Mounted Gallery with real owners and noncanonical TEST cues. Viewport keyboard injection and renderer pixels; no OS keyboard, UIA, authored production cue completeness, or production cutover claim."}, "\t") + "\n")
			report.close()
	print("GALLERY_VERSION_REGISTER_RENDER_", "VERIFIED" if _failures.is_empty() else "FAILED",
		" tuples=", _samples.size(), " evidence=", _folder)
	if is_instance_valid(_viewport): _viewport.queue_free()
	quit(0 if _failures.is_empty() else 1)
