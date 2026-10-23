extends "res://tests/manual/verify_gallery_action_states_native.gd"
## Real Gallery with test-only long copy; shipping catalog and persistence stay intact.
const LONG_GALLERY := preload("res://tests/support/GalleryLongRecord.gd")

func _create_gallery() -> Control:
	var gallery: Control = GALLERY.instantiate()
	gallery.set_script(LONG_GALLERY)
	return gallery

func _sample(locale: String, percent: int, palette: String) -> bool:
	if not await super._sample(locale, percent, palette): return false
	if percent != 150: return true
	var paper: Control = _gallery._record_paper
	var before: Dictionary = _profile.get_profile_snapshot()
	var starts := _bridge.starts.duplicate()
	var signature: String = _gallery._selected_signature_id()
	_gallery.long_record = true
	_gallery._refresh_record_copy()
	paper.grab_focus()
	await _frames()
	_check(paper.has_overflow() and paper.has_focus(true), "overflow paper lacks visible native focus")
	var stem := "%s-%d-%s-paper" % [locale.replace("_", "-"), percent, palette]
	var top_file := stem + "-top.png"
	var top := await _capture(top_file)
	if top == null: return false
	var ink := _gallery.theme.get_color("paper_ink", "Gallery")
	var face := _gallery.theme.get_color("paper", "Gallery")
	_focus_pixels(top, paper.get_global_rect(), ink,
		_gallery.theme.get_color("paper_focus", "Gallery"), face, "Record details")
	_check(_near_rgb8(top.get_pixel(467, 16), ink), "top thumb missing")
	_check(_near_rgb8(top.get_pixel(467, 271), face), "top thumb incorrectly reaches bottom")
	_check(_near_rgb8(top.get_pixel(200, 278), face), "long copy paints below its clip")
	await _key(KEY_END)
	_check(paper.scroll_offset == paper.content_extent - 512, "End did not clamp to record bottom")
	await _key(KEY_DOWN)
	_check(paper.has_focus(), "bottom boundary leaked keyboard focus")
	var end_file := stem + "-end.png"
	var end := await _capture(end_file)
	if end == null: return false
	_check(_near_rgb8(end.get_pixel(467, 16), face), "end thumb incorrectly remains at top")
	_check(_near_rgb8(end.get_pixel(467, 271), ink), "end thumb missing")
	_check(_near_rgb8(end.get_pixel(200, 278), face), "scrolled copy paints below its clip")
	_check(paper.get_global_rect().encloses(_gallery._version_selector.get_global_rect().grow(8)),
		"bottom scroll clips the retained version action")
	await _key(KEY_ENTER)
	await _key(KEY_SPACE)
	_check(_bridge.starts == starts, "Record details Accept started replay")
	_check(_gallery._selected_signature_id() == signature, "scrolling changed the selected replay")
	_gallery.long_record = false
	_gallery._refresh_record_copy()
	await _frames()
	_check(not paper.has_overflow() and paper.focus_mode == Control.FOCUS_NONE,
		"fitting paper retained a scroll focus target")
	var fit_file := stem + "-fit.png"
	var fit := await _capture(fit_file)
	if fit == null: return false
	for point: Vector2i in [Vector2i(467, 16), Vector2i(468, 150), Vector2i(467, 271), Vector2i(192, 24)]:
		_check(_near_rgb8(fit.get_pixelv(point), face), "fitting paper retained witness/focus paint")
	_check(_profile.get_profile_snapshot() == before, "scrolling changed Profile")
	var sample: Dictionary = _samples[-1]
	sample["record_paper_files"] = [top_file, end_file, fit_file]
	sample["record_paper_checks"] = {"overflow_focus": true, "clipped": true,
		"top_and_end_witness": true, "boundary_custody": true, "fit_absence": true,
		"profile_unchanged": true, "selected_signature_retained": true}
	_samples[-1] = sample
	return _failures.is_empty()
