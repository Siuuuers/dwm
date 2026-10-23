extends "res://tests/manual/verify_gallery_record_media_native.gd"
## Required-record failure preserves trusted copy and paints its exact leaf.

class FailedLookupProfile extends PROFILE:
	var fail_lookup := false
	func get_reached_presentations(entry_id: String = "") -> Dictionary:
		if fail_lookup: return {"ok": false, "code": &"fixture_projection_failed"}
		return super.get_reached_presentations(entry_id)

func _create_profile() -> Node:
	return FailedLookupProfile.new()

func _sample(locale: String, percent: int, palette: String) -> bool:
	if not await super._sample(locale, percent, palette): return false
	var before: Dictionary = _profile.get_profile_snapshot()
	var starts := _bridge.starts.duplicate()
	var selected: String = _gallery._selected_id
	_profile.fail_lookup = true
	_gallery._refresh_tiles()
	await _frames()
	if not _check(_gallery._status_key == "gallery.record.unavailable", "failed lookup was called unreached"):
		return false
	var paper: Control = _gallery._record_paper
	var title: Label = paper.title_label
	var status: Label = _gallery.get_node("%ReplayStatus")
	var replay: Button = _gallery.get_node("%ReplayButton")
	var top: float = 48 + title.size.y
	_check(title.visible and not title.text.is_empty() and title.position == Vector2.ZERO,
		"independently trustworthy title was removed")
	_check(_gallery._canvas.unavailable_top == top and status.position == Vector2(408, top + 8),
		"unavailable leaf did not follow the title")
	_check(status.accessibility_name == status.text and not status.text.is_empty(), "unavailable literal lacks assistive parity")
	_check(paper._media.texture == null and not paper.sentence_label.visible and not _gallery._version_selector.visible,
		"failed record exposes media, sentence or versions")
	_check(replay.visible and replay.disabled and replay.focus_mode == Control.FOCUS_NONE,
		"failed record Replay remains available")
	_check(paper.focus_mode == Control.FOCUS_NONE and _gallery._canvas.paper_extent == 0,
		"failed record retains a scroll target or witness")
	var filename := "%s-%d-%s-unavailable.png" % [locale.replace("_", "-"), percent, palette]
	var picture := await _capture(filename)
	if picture == null: return false
	var ink := _gallery.theme.get_color("paper_ink", "Gallery")
	var face := _gallery.theme.get_color("paper", "Gallery")
	var y := int(top / 2)
	_check(_near_rgb8(picture.get_pixel(196, y), ink) and _near_rgb8(picture.get_pixel(198, y), face),
		"unavailable perimeter lost its two-on/two-off raster")
	_check(_near_rgb8(picture.get_pixel(447, y + 1), ink), "unavailable hatch missing")
	_check(_near_rgb8(picture.get_pixel(196, y - 1), face), "unavailable leaf consumes title gap")
	var status_rect := Rect2i(Vector2i(status.global_position / 2), Vector2i(status.size / 2))
	_check(_find_ink(picture, status_rect, ink, face) != Vector2i(-1, -1), "unavailable literal has no native ink")
	_check(_gallery._selected_id == selected and _profile.get_profile_snapshot() == before and _bridge.starts == starts,
		"failure projection changes record, Profile or playback")
	var sample: Dictionary = _samples[-1]
	sample["record_unavailable_file"] = filename
	sample["record_unavailable_checks"] = {"trusted_title": true, "leaf": true, "no_mutation": true}
	_samples[-1] = sample
	_profile.fail_lookup = false
	_gallery._refresh_tiles()
	await _frames()
	_check(not _gallery._canvas.unavailable_record and not replay.disabled, "valid refresh did not restore Replay")
	return _failures.is_empty()
