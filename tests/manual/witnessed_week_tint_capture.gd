extends "res://tests/ui/render_witnessed_caption.gd"
## Six native captures from installed Dialogic caption controls and the real art hold.
## The inherited fixture mounts/restores the isolated Dialogic root and native layout.

const PALETTES := preload("res://scripts/ui/witnessed/WitnessedPaletteRegistry.gd")
const HOLD := preload("res://scripts/ui/witnessed/SceneArtHoldSurface.gd")
const FOLDER := "res://.godot/phase2r_logs/witnessed_week_tint"
const PINK := Color("e34db1")

class RunOwner extends RefCounted:
	var day := 1
	var dark_mode := false
	func get_run_configuration() -> Dictionary:
		return {"ok": true, "value": {"dark_mode": dark_mode}}

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("WITNESSED_WEEK_TINT_CAPTURE_FAILED: " + message)
	return condition


func _run() -> void:
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty(),
			"DWM_TEST_ROOT is required for isolated native evidence") \
			or not _check(DisplayServer.get_name() != "headless",
			"a nonheadless display server is required"):
		quit(1)
		return
	_folder = ProjectSettings.globalize_path(FOLDER)
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "cannot create capture folder"):
		quit(1)
		return
	if not await _mount():
		quit(1)
		return
	var caption_ok := await _capture_caption_five()
	await _restore()
	var art_ok := false
	if caption_ok:
		art_ok = await _capture_art_only()
	var complete := caption_ok and art_ok and _records.size() == 6 and _failures.is_empty()
	var report := FileAccess.open(_folder.path_join("measurements.json"), FileAccess.WRITE)
	if _check(report != null, "cannot write measurements"):
		report.store_string(JSON.stringify({
			"scope": "Five synthetic three-leaf native Dialogic captions and one art-only hold; no authored story or assistive-technology acceptance",
			"renderer": "native OpenGL3 1280x720; inherited isolated root mount and restore",
			"pixel_tolerance": "Day 1 and High Contrast flat roles, focus, solid glyph interiors and art are exact RGB8; only computed week-tint flat roles allow one RGB8 channel level.",
			"captures": _records.size(), "checks": _checks,
			"failures": _failures, "samples": _records,
		}, "\t") + "\n")
		report.close()
	if complete and report != null:
		print("WITNESSED_WEEK_TINT_CAPTURE_VERIFIED captures=", _records.size(),
			" checks=", _checks, " failures=0 evidence=", _folder)
	else:
		print("WITNESSED_WEEK_TINT_CAPTURE_FAILED captures=", _records.size(),
			" checks=", _checks, " failures=", _failures.size(), " evidence=", _folder)
	quit(0 if complete and report != null else 1)


func _capture_caption_five() -> bool:
	var cases := [
		{"name": "after-hours-day1", "palette": "AfterHours", "day": 1,
			"contrast": false, "preset": "standard", "overflow": false},
		{"name": "after-hours-day7", "palette": "AfterHours", "day": 7,
			"contrast": false, "preset": "standard", "overflow": false},
		{"name": "midnight-day7", "palette": "Midnight", "day": 7,
			"contrast": false, "preset": "standard", "overflow": false},
		{"name": "high-contrast-day7", "palette": "AfterHours", "day": 7,
			"contrast": true, "preset": "standard", "overflow": false},
		{"name": "protan-day7-scrolled", "palette": "AfterHours", "day": 7,
			"contrast": false, "preset": "protan", "overflow": true},
	]
	var first_ink: Array[Vector2i] = []
	for index: int in cases.size():
		var spec: Dictionary = cases[index]
		if index != 1:
			if not await _show_fixture("en", 100, spec.palette, spec.overflow,
					spec.contrast, spec.preset): return false
		var native: DialogicNode_DialogText = _caption.caption_text
		var bar: VScrollBar = _caption.get_scroll_bar()
		var before: Dictionary = _invariants()
		var before_scroll: float = bar.value
		var owner := RunOwner.new()
		owner.day = spec.day
		owner.dark_mode = spec.palette == "Midnight"
		if not _check(_caption.configure_run_presentation(owner), spec.name + " installed run rejected"):
			return false
		if not _check(_caption.caption_text == native and _invariants() == before,
				spec.name + " changed native text, retained copies or Dialogic state"): return false
		if not _check(bar.value == before_scroll and native.has_focus(),
				spec.name + " changed scroll or focus on colour-only publication"): return false
		if spec.overflow:
			await _frames()
			bar.value = minf(100.0, maxf(0.0, bar.max_value - bar.page))
			if not _check(bar.value > 0.0, "overflow did not expose manual shared scroll"):
				return false
		var sample: Dictionary = await _caption_image(spec)
		if not sample.get("ok", false): return false
		if index == 0:
			first_ink = sample.ink_positions
		elif index == 1:
			if not _check(sample.ink_positions == first_ink,
					"Day 7 changed the exact interior pixels of protected Day 1 copy"):
				return false
	return true


func _caption_image(spec: Dictionary) -> Dictionary:
	await _frames()
	var palette: String = spec.palette
	var day: int = spec.day
	var contrast: bool = spec.contrast
	var preset: String = spec.preset
	var roles: Dictionary = PALETTES.resolve_tinted(palette, contrast, preset, day)
	var literal: Dictionary = PALETTES.resolve(palette, contrast, preset)
	var expected: Theme = THEME.build("en", 100, palette, contrast, preset, false, day)
	if not _check(expected != null and roles.size() == 7, spec.name + " has no authored theme"):
		return {"ok": false}
	if day == 1 or contrast:
		if not _check(roles == literal, spec.name + " changed an authored Day 1/HC tuple"):
			return {"ok": false}
	var projection: Dictionary = _caption.get_caption_projection()
	var expected_copy: String = (COPY["en"] + " ").repeat(100).strip_edges() if spec.overflow else COPY["en"]
	if not _check(projection.palette == palette and projection.day == day
			and projection.retained_captions == RETAINED_COPY["en"]
			and projection.text == expected_copy,
			spec.name + " lost installed context or retained copy"):
		return {"ok": false}
	var node: RichTextLabel = _caption.caption_text
	if not _check(node.has_focus() and node.visible_ratio == 1.0,
			spec.name + " current caption lost native focus/reveal"):
		return {"ok": false}
	var pixels: Image = _viewport.get_texture().get_image()
	var field: Rect2 = projection.field_rect
	var leaf: Rect2 = projection.caption_rect
	var points := {&"field": Vector2i(2, int(field.position.y) + 8),
		&"deep": Vector2i(2, 680), &"rule": Vector2i(2, int(field.position.y)),
		&"current": Vector2i(int(leaf.position.x) + 12,
			maxi(int(leaf.position.y) + 12, int(field.position.y) + 12))}
	for role: StringName in points:
		var pixel: Color = pixels.get_pixelv(points[role])
		var matches: bool = _exact_rgb8(pixel, roles[role]) if day == 1 or contrast else \
			_within_one_rgb8(pixel, roles[role])
		if not _check(matches,
				spec.name + " framebuffer " + str(role) + " mismatch at " + str(points[role])):
			return {"ok": false}
	var origin := Vector2i(node.get_global_transform_with_canvas() * Vector2.ZERO)
	if not _caption_frame(pixels, origin, int(node.size.x), int(node.size.y),
			roles, day == 1 or contrast):
		return {"ok": false}
	var ink_positions: Array[Vector2i] = []
	var aperture: Rect2i = Rect2i(leaf.grow(-18)).intersection(_visible_aperture())
	for y: int in range(aperture.position.y, aperture.end.y):
		for x: int in range(aperture.position.x, aperture.end.x):
			if _exact_rgb8(pixels.get_pixel(x, y), roles[&"text"]):
				ink_positions.append(Vector2i(x, y))
	if not _check(ink_positions.size() > 20, spec.name + " has no protected glyph interiors"):
		return {"ok": false}
	var filename: String = str(spec.name) + ".png"
	if not _check(pixels.save_png(_folder.path_join(filename)) == OK,
			spec.name + " PNG save failed"): return {"ok": false}
	_records.append({"file": filename, "palette": palette, "day": day,
		"high_contrast": contrast, "colour_preset": preset,
		"scroll": projection.scroll_offset, "retained": projection.retained_captions,
		"focus": node.has_focus(), "role_points": points,
		"glyph_interior_pixels": ink_positions.size()})
	return {"ok": true, "ink_positions": ink_positions}


func _capture_art_only() -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var hold := HOLD.new()
	# This is a real registered scene ID. Its optional assets are replaced only
	# within this view by a known synthetic image; no ArtManifest reloading.
	hold.configure("hospital.faint.day1", "synthetic-art-token", 100, "en", false)
	viewport.add_child(hold)
	var pink := _pink_texture()
	hold.art.configure_textures(pink, [])
	await _frames()
	var image_before: Image = viewport.get_texture().get_image()
	var art_before: Color = image_before.get_pixel(640, 200)
	var texture_before: Texture2D = hold.art._background.texture
	var button: Button = hold.next_button
	var token: String = hold._token
	var neutral: bool = hold._await_neutral
	hold.set_presentation_paused(true)
	var owner := RunOwner.new()
	owner.day = 7
	owner.dark_mode = true
	if not _check(hold.configure_run_presentation(owner),
			"art hold rejected installed Midnight Day 7"):
		viewport.queue_free()
		return false
	if not _check(hold.art._background.texture == texture_before
			and hold.art.modulate == Color.WHITE and hold.art.self_modulate == Color.WHITE
			and hold.next_button == button and hold._token == token
			and hold._await_neutral == neutral and hold._paused and button.disabled,
			"art texture or Continue custody changed with room material"):
		viewport.queue_free()
		return false
	hold.set_presentation_paused(false)
	await _frames()
	var roles: Dictionary = PALETTES.resolve_tinted("Midnight", false, "standard", 7)
	var image: Image = viewport.get_texture().get_image()
	if not _check(not button.disabled and button.has_focus(),
			"art Continue did not regain its native focus after Pause release"):
		viewport.queue_free()
		return false
	if not _check(_exact_rgb8(image.get_pixel(640, 200), art_before)
			and _exact_rgb8(art_before, PINK), "synthetic artwork changed under tint"):
		viewport.queue_free()
		return false
	for sample: Dictionary in [
		{"role": &"field", "point": Vector2i(100, 580)},
		{"role": &"deep", "point": Vector2i(100, 680)},
		{"role": &"current", "point": Vector2i(470, 675)},
		{"role": &"focus_outer", "point": Vector2i(697, 707)},
	]:
		var actual: Color = image.get_pixelv(sample.point)
		var exact: bool = sample.role == &"focus_outer"
		if not _check(_exact_rgb8(actual, roles[sample.role]) if exact else
				_within_one_rgb8(actual, roles[sample.role]),
				"art hold " + str(sample.role) + " pixel mismatch"):
			viewport.queue_free()
			return false
	var filename := "art-only-midnight-day7.png"
	if not _check(image.save_png(_folder.path_join(filename)) == OK, "art-only PNG save failed"):
		viewport.queue_free()
		return false
	_records.append({"file": filename, "palette": "Midnight", "day": 7,
		"synthetic_art": PINK.to_html(false), "art_pixel_unchanged": true,
		"texture_identity_unchanged": true, "token_unchanged": true,
		"paused_custody_unchanged": true})
	viewport.queue_free()
	await process_frame
	return true


func _pink_texture() -> ImageTexture:
	var pixels := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	pixels.fill(PINK)
	return ImageTexture.create_from_image(pixels)


func _caption_frame(pixels: Image, origin: Vector2i, width: int, height: int,
		roles: Dictionary, exact_room: bool) -> bool:
	var outer := Rect2i(2, 2, width - 4, height - 4)
	var outer_inside := Rect2i(4, 4, width - 8, height - 8)
	var inner := Rect2i(6, 6, width - 12, height - 12)
	var inner_inside := Rect2i(8, 8, width - 16, height - 16)
	var visible := Rect2i(origin, Vector2i(width, height)).intersection(_visible_aperture())
	for y: int in range(visible.position.y - origin.y, visible.end.y - origin.y):
		for x: int in range(visible.position.x - origin.x, visible.end.x - origin.x):
			if y >= 16 and y < height - 16 and x >= 16 and x < width - 16:
				continue
			var local := Vector2i(x, y)
			var role := &"rule" if y < 2 else &"current"
			if outer.has_point(local) and not outer_inside.has_point(local):
				role = &"focus_outer"
			if inner.has_point(local) and not inner_inside.has_point(local):
				role = &"focus_inner"
			var actual: Color = pixels.get_pixelv(origin + local)
			var exact: bool = exact_room or role in [&"focus_outer", &"focus_inner"]
			if not (_exact_rgb8(actual, roles[role]) if exact else
					_within_one_rgb8(actual, roles[role])):
				return _check(false, "protected caption frame mismatch role=%s local=%s" % [role, local])
	return _check(true, "protected caption frame")


func _exact_rgb8(actual: Color, expected: Color) -> bool:
	return roundi(actual.r * 255.0) == roundi(expected.r * 255.0) \
		and roundi(actual.g * 255.0) == roundi(expected.g * 255.0) \
		and roundi(actual.b * 255.0) == roundi(expected.b * 255.0)


func _within_one_rgb8(actual: Color, expected: Color) -> bool:
	return absi(roundi(actual.r * 255.0) - roundi(expected.r * 255.0)) <= 1 \
		and absi(roundi(actual.g * 255.0) - roundi(expected.g * 255.0)) <= 1 \
		and absi(roundi(actual.b * 255.0) - roundi(expected.b * 255.0)) <= 1
