extends "res://tests/manual/verify_gallery_retry_native.gd"
## Native proof for Gallery action focus, pointer states, and canceled activation.


class PracticeGame extends RefCounted:
	func capture_run_snapshot_input() -> Dictionary:
		return {}


func _sample(locale: String, percent: int, palette: String) -> bool:
	if not await super._sample(locale, percent, palette):
		return false
	var replay: Button = _gallery.get_node("%ReplayButton")
	var picker: OptionButton = _gallery.get("_version_selector")
	var replay_rect := replay.get_global_rect()
	var picker_rect := picker.get_global_rect()
	var stem := "%s-%d-%s-action" % [locale.replace("_", "-"), percent, palette]
	replay.grab_focus()
	await _frames()
	var replay_file := stem + "-replay-focus.png"
	var replay_image := await _capture(replay_file)
	if replay_image == null:
		return false
	var replay_pixels := _focus_pixels(replay_image, replay_rect,
		_gallery.theme.get_color("ink", "Gallery"),
		_gallery.theme.get_color("focus", "Gallery"),
		_gallery.theme.get_color("face", "Gallery"), "Replay")
	_check(replay.has_focus(), "Replay did not own native focus")
	_check(replay.get_global_rect() == replay_rect and picker.get_global_rect() == picker_rect,
		"Replay focus changed action geometry")
	picker.grab_focus()
	await _frames()
	var picker_file := stem + "-selector-focus.png"
	var picker_image := await _capture(picker_file)
	if picker_image == null:
		return false
	var picker_pixels := _focus_pixels(picker_image, picker_rect,
		_gallery.theme.get_color("paper_ink", "Gallery"),
		_gallery.theme.get_color("paper_focus", "Gallery"),
		_gallery.theme.get_color("paper", "Gallery"), "plural selector")
	_check(picker.has_focus(), "plural selector did not own native focus")
	_check(replay.get_global_rect() == replay_rect and picker.get_global_rect() == picker_rect,
		"selector focus changed action geometry")
	replay.grab_focus()
	await _frames()
	if not _check(replay.has_focus(), "Replay focus was not restored after selector proof"):
		return false
	var sample: Dictionary = _samples[-1]
	sample["action_state_files"] = {"replay_focus": replay_file, "selector_focus": picker_file}
	sample["action_state_checks"] = {"replay": replay_pixels, "selector": picker_pixels,
		"geometry_unchanged": true, "replay_focus_restored": true}
	_samples[-1] = sample
	if _samples.size() == 1:
		await _first_tuple_pointer_and_practice(replay, replay_rect, sample)
	return _failures.is_empty()


func _first_tuple_pointer_and_practice(replay: Button, replay_rect: Rect2, sample: Dictionary) -> void:
	var before_signature := str(_gallery.call("_selected_signature_id"))
	var before_starts := _bridge.starts.duplicate()
	var before_profile: Dictionary = _profile.get_profile_snapshot()
	var native := Rect2i(Vector2i(replay_rect.position / 2.0), Vector2i(replay_rect.size / 2.0))
	var inside := native.get_center()
	var pointer_inside := replay_rect.get_center()
	var outside := Vector2(1000, 540)
	await _mouse_motion(pointer_inside)
	_check(replay.is_hovered(), "Replay did not receive pointer hover")
	var hover_file := "en-100-AfterHours-action-replay-hover.png"
	var hover := await _capture(hover_file)
	if hover == null: return
	_check(_near_rgb8(hover.get_pixel(native.position.x, inside.y),
		_gallery.theme.get_color("ink", "Gallery")), "Replay hover rule pixel changed")
	await _mouse_button(pointer_inside, true)
	_check(replay.is_pressed(), "Replay did not receive pointer hold")
	var pressed_file := "en-100-AfterHours-action-replay-pressed.png"
	var pressed := await _capture(pressed_file)
	if pressed == null: return
	_check(_near_rgb8(pressed.get_pixel(inside.x, native.position.y),
		_gallery.theme.get_color("ink", "Gallery")), "Replay pressed rule pixel changed")
	await _mouse_motion(outside, MOUSE_BUTTON_MASK_LEFT)
	await _mouse_button(outside, false)
	var cancel_file := "en-100-AfterHours-action-replay-cancel.png"
	var canceled := await _capture(cancel_file)
	if canceled == null: return
	var face := _gallery.theme.get_color("face", "Gallery")
	_check(_near_rgb8(canceled.get_pixel(native.position.x, inside.y), face)
		and _near_rgb8(canceled.get_pixel(inside.x, native.position.y), face),
		"canceled Replay press did not restore footer substrate")
	_check(_bridge.starts == before_starts, "canceled Replay press emitted a replay command")
	_check(str(_gallery.call("_selected_signature_id")) == before_signature,
		"Replay pointer states changed the selected signature")
	_check(_profile.get_profile_snapshot() == before_profile, "Replay pointer states changed Profile")
	_check(replay.get_global_rect() == replay_rect, "Replay pointer states changed geometry")
	_check(_gallery.configure_rehearsal(PracticeGame.new(), null).get("ok", false),
		"Practice fixture was rejected")
	await _frames()
	var practice: Button = _gallery.get("_practice_button")
	var practice_rect := practice.get_global_rect()
	practice.grab_focus()
	await _frames()
	var practice_file := "en-100-AfterHours-action-practice-focus.png"
	var practice_image := await _capture(practice_file)
	if practice_image == null: return
	var practice_pixels := _focus_pixels(practice_image, practice_rect,
		_gallery.theme.get_color("paper_ink", "Gallery"),
		_gallery.theme.get_color("paper_focus", "Gallery"),
		_gallery.theme.get_color("paper", "Gallery"), "Practice")
	_check(practice.visible and practice.has_focus(), "visible Practice did not own focus")
	_check(practice.get_global_rect() == practice_rect, "Practice focus changed geometry")
	replay.grab_focus()
	await _frames()
	var files: Dictionary = sample["action_state_files"]
	files.merge({"replay_hover": hover_file, "replay_pressed": pressed_file,
		"replay_canceled": cancel_file, "practice_focus": practice_file})
	var checks: Dictionary = sample["action_state_checks"]
	checks["pointer_cancel"] = {
		"signature_retained": str(_gallery.call("_selected_signature_id")) == before_signature,
		"bridge_starts_retained": _bridge.starts == before_starts,
		"profile_retained": _profile.get_profile_snapshot() == before_profile,
		"geometry_unchanged": replay.get_global_rect() == replay_rect}
	checks["practice"] = practice_pixels
	_samples[-1] = sample


func _mouse_motion(point: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = mask
	_viewport.push_input(event, true)
	await _frames()


func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = point
	event.global_position = point
	_viewport.push_input(event, true)
	await _frames()


func _focus_pixels(image: Image, logical: Rect2, outer: Color, inner: Color,
		substrate: Color, label: String) -> Dictionary:
	var native := Rect2i(Vector2i(logical.position / 2.0), Vector2i(logical.size / 2.0))
	var outer_rect := native.grow(4)
	var inner_rect := native.grow(2)
	var y := native.get_center().y
	var points: Array[Vector2i] = [Vector2i(native.position.x - 4, y),
		Vector2i(native.position.x - 2, y), Vector2i(native.position.x - 3, y),
		Vector2i(native.position.x - 1, y)]
	var expected: Array[Color] = [outer, inner, substrate, substrate]
	var names := ["outer ring", "inner ring", "outer gap", "inner gap"]
	var ok := true
	for index: int in points.size():
		ok = _check(_near_rgb8(image.get_pixelv(points[index]), expected[index]),
			label + " " + names[index] + " pixel changed") and ok
	return {"ok": ok, "logical_rect": [logical.position.x, logical.position.y, logical.size.x, logical.size.y],
		"outer_native": _rect_receipt(outer_rect), "inner_native": _rect_receipt(inner_rect),
		"points": _point_receipts(image, points)}


func _point_receipts(image: Image, points: Array[Vector2i]) -> Array[Dictionary]:
	var receipts: Array[Dictionary] = []
	for point: Vector2i in points:
		receipts.append({"point": [point.x, point.y], "rgb": image.get_pixelv(point).to_html(false)})
	return receipts


func _rect_receipt(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
