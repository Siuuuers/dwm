extends GutTest
const SURFACE := preload("res://scripts/ui/Day7PreludeSurface.gd")
const ART := preload("res://scripts/data/ArtManifest.gd")
const GALLERY_THEME := preload("res://scripts/ui/gallery/GalleryTheme.gd")

class Acknowledgment extends RefCounted:
	signal released
	var calls: Array[Dictionary] = []
	var succeed := true
	var hold := false
	func accept(receipt: Dictionary) -> Dictionary:
		calls.append(receipt.duplicate(true))
		if hold: await released
		return {"ok": succeed, "value": {"retained": receipt.duplicate(true)}, "code": &"ok" if succeed else &"write_failed"}


class ApertureAcknowledgment extends RefCounted:
	var surface: Node
	var calls: Array[Dictionary] = []
	var geometry: Array[Dictionary] = []
	func accept(receipt: Dictionary) -> Dictionary:
		calls.append(receipt.duplicate(true))
		var aperture: Rect2 = surface._scroll.get_global_rect().intersection(surface._root.get_viewport_rect())
		var body_rect: Rect2 = surface._current_body.get_global_rect()
		var child_count: int = surface._history_list.get_child_count()
		var title_rect: Rect2 = surface._history_list.get_child(child_count - 2).get_global_rect()
		geometry.append({"aperture": aperture, "body": body_rect, "title": title_rect,
			"leading_edge_visible": body_rect.position.y > 0.0
				and body_rect.position.y >= aperture.position.y - 1.0
				and body_rect.position.y < aperture.end.y,
			"body_fully_visible": body_rect.position.y >= aperture.position.y - 1.0
				and body_rect.end.y <= aperture.end.y + 1.0})
		return {"ok": true}

func _card(token: String = "card-one", suffix: String = "a") -> Dictionary:
	return {"title": "Lavinia / Day 1", "body": "A remembered detail: [reply %s]" % suffix,
		"receipt": {"entry_id": "echo.fallback.day7", "view_token": token,
			"echo_id": "echo.lavinia.day1.reply." + suffix,
			"presentation_atom_id": "atom.echo.lavinia.day1.reply.%s.fallback.day7" % suffix}}

func test_only_drawn_current_card_can_acknowledge_and_failed_save_retries_exact_receipt() -> void:
	var acknowledgment := Acknowledgment.new()
	acknowledgment.succeed = false
	var card := _card()
	var original := card.duplicate(true)
	var surface := SURFACE.new()
	assert_true(surface.configure(card, acknowledgment.accept).ok)
	card.body = "changed by caller"
	card.receipt.echo_id = "changed by caller"
	add_child_autofree(surface)
	surface._next.pressed.emit()
	assert_eq(acknowledgment.calls, [], "node creation and programmatic Next are not a physical witness")
	assert_eq(surface._current_body.text, original.body, "staging is plain detached text")
	surface._current_body.draw.emit()
	assert_eq(surface.get_presentation_history(), [original])
	assert_false(surface.present_card(_card("next", "b")).ok)
	surface._next.pressed.emit()
	await get_tree().process_frame
	assert_eq(acknowledgment.calls, [original.receipt])
	assert_eq(surface._next.text, "Retry")
	assert_false(surface._accepted)
	assert_eq(surface._current_body.text, original.body)
	acknowledgment.succeed = true
	watch_signals(surface)
	surface._next.pressed.emit()
	await get_tree().process_frame
	assert_eq(acknowledgment.calls, [original.receipt, original.receipt])
	assert_signal_emit_count(surface, "card_acknowledged", 1)
	assert_true(surface._accepted)
	assert_eq(surface.get_presentation_history(), [original], "save retries do not invent another presentation")
	surface._next.pressed.emit()
	assert_eq(acknowledgment.calls.size(), 2)

func test_prior_draw_and_reused_token_cannot_admit_a_new_card_and_history_stays_detached() -> void:
	var acknowledgment := Acknowledgment.new()
	var first := _card()
	var surface := SURFACE.new()
	assert_true(surface.configure(first, acknowledgment.accept).ok)
	add_child_autofree(surface)
	surface._current_body.draw.emit()
	surface._next.pressed.emit()
	await get_tree().process_frame
	var forged := _card("card-one", "b")
	assert_eq(surface.present_card(forged).code, &"prelude_card_identity_mismatch")
	var second := _card("card-two", "b")
	assert_true(surface.present_card(second).ok)
	assert_true(surface._next.disabled)
	surface._on_body_drawn(first.receipt)
	assert_true(surface._next.disabled, "an old label redraw cannot witness the current atom")
	surface._current_body.draw.emit()
	assert_eq(surface.get_presentation_history(), [first, second])
	var history := surface.get_presentation_history()
	history[0].receipt.echo_id = "caller change"
	assert_eq(surface.get_presentation_history(), [first, second])
	assert_eq(surface._history_list.get_child_count(), 4, "prior title and detail remain in visible scrollback")

func test_retired_surface_does_not_publish_after_an_inflight_acknowledgment() -> void:
	var acknowledgment := Acknowledgment.new()
	acknowledgment.hold = true
	var surface := SURFACE.new()
	assert_true(surface.configure(_card(), acknowledgment.accept).ok)
	add_child_autofree(surface)
	watch_signals(surface)
	surface._current_body.draw.emit()
	surface._next.pressed.emit()
	assert_true(surface._busy)
	surface._next.pressed.emit()
	assert_eq(acknowledgment.calls.size(), 1)
	remove_child(surface)
	acknowledgment.released.emit()
	await get_tree().process_frame
	assert_signal_emit_count(surface, "card_acknowledged", 0)
	assert_false(surface._accepted)


class Preparation extends RefCounted:
	var surface: Node
	var next_card: Dictionary
	var calls := 0
	var succeed := false
	func retry() -> Dictionary:
		calls += 1
		return surface.present_card(next_card) if succeed else {"ok": false, "code": &"issuer_unavailable"}

func test_initial_preparation_retry_has_no_fabricated_card_or_history_and_can_install_first_real_card() -> void:
	var acknowledgment := Acknowledgment.new()
	var preparation := Preparation.new()
	var surface := SURFACE.new()
	preparation.surface = surface
	preparation.next_card = _card()
	assert_true(surface.configure_waiting(preparation.retry, acknowledgment.accept).ok)
	add_child_autofree(surface)
	assert_true(surface._card.is_empty())
	assert_eq(surface.get_presentation_history(), [])
	assert_eq(surface._next.text, "Retry")
	surface._next.pressed.emit()
	assert_eq(preparation.calls, 1)
	assert_eq(acknowledgment.calls, [])
	assert_eq(surface.get_presentation_history(), [])
	assert_false(surface._next.disabled)
	preparation.succeed = true
	surface._next.pressed.emit()
	assert_eq(preparation.calls, 2)
	assert_eq(surface._card, preparation.next_card)
	assert_true(surface._next.disabled, "preparation is not a physical witness")
	assert_eq(surface.get_presentation_history(), [])
	surface._current_body.draw.emit()
	surface._next.pressed.emit()
	assert_eq(acknowledgment.calls, [preparation.next_card.receipt])

func test_next_card_preparation_retry_never_reacknowledges_the_previous_card() -> void:
	var acknowledgment := Acknowledgment.new()
	var preparation := Preparation.new()
	var first := _card()
	var surface := SURFACE.new()
	preparation.surface = surface
	preparation.next_card = _card("second-card", "b")
	assert_true(surface.configure(first, acknowledgment.accept).ok)
	add_child_autofree(surface)
	assert_false(surface.show_advance_retry(preparation.retry).ok, "pending card cannot be bypassed")
	surface._current_body.draw.emit()
	surface._next.pressed.emit()
	assert_true(surface.show_advance_retry(preparation.retry).ok)
	surface._next.pressed.emit()
	assert_eq(preparation.calls, 1)
	assert_eq(acknowledgment.calls, [first.receipt])
	assert_eq(surface.get_presentation_history(), [first])
	preparation.succeed = true
	surface._next.pressed.emit()
	assert_eq(acknowledgment.calls, [first.receipt])
	assert_eq(surface._card, preparation.next_card)
	surface._current_body.draw.emit()
	surface._next.pressed.emit()
	assert_eq(acknowledgment.calls, [first.receipt, preparation.next_card.receipt])
	assert_eq(surface.get_presentation_history(), [first, preparation.next_card])

func test_free_during_acknowledgment_releases_callback_without_resuming_a_destroyed_instance() -> void:
	var acknowledgment := Acknowledgment.new()
	acknowledgment.hold = true
	var surface := SURFACE.new()
	assert_true(surface.configure(_card(), acknowledgment.accept).ok)
	add_child(surface)
	surface._current_body.draw.emit()
	surface._next.pressed.emit()
	assert_eq(acknowledgment.calls.size(), 1)
	surface.free()
	acknowledgment.released.emit()
	await get_tree().process_frame
	assert_false(is_instance_valid(surface))


func test_optional_scene_art_uses_exact_card_entry_and_keeps_acknowledgment_and_missing_art_layout() -> void:
	var date_entry := "dating.solo.priscilla.day1.pre_challenge"
	var catalog := {"schema_version": 1,
		"assets": {"fixture.portrait": {"path": "res://icon.svg", "size": [128, 128]}},
		"scenes": {
			date_entry: {"background": "", "portraits": ["fixture.portrait"], "cg": ""},
			"echo.fallback.day7": {"background": "fixture.portrait", "portraits": [], "cg": ""}}}
	var file := FileAccess.open("user://prelude-art-binding.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog))
	file.close()
	assert_true(ART.reload_placements("user://prelude-art-binding.json"))
	var acknowledgment := Acknowledgment.new()
	var date_card := _card("date-replay")
	date_card.receipt = {"entry_id": date_entry, "view_token": "date-replay", "signature_id": "reached-version"}
	var presentation_theme := Theme.new()
	presentation_theme.default_font_size = 24
	var surface := SURFACE.new()
	assert_true(surface.configure(date_card, acknowledgment.accept, "en", presentation_theme).ok)
	add_child_autofree(surface)
	await get_tree().process_frame
	assert_true(surface._scene_art.visible)
	assert_eq(surface._scene_art._entry_id, date_entry)
	assert_not_null(surface._scene_art._portraits[0].texture)
	assert_eq(surface._scene_art.size, Vector2(1280, 448))
	assert_eq(surface._scene_art.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_lt(surface._scene_art.get_index(), surface._reading_margin.get_index())
	assert_gte(surface._current_body.get_global_rect().position.y, surface._scene_art.get_global_rect().end.y)
	assert_lte(surface._next.get_global_rect().end.y, surface._root.size.y)
	surface._current_body.draw.emit()
	surface._next.pressed.emit()
	assert_eq(acknowledgment.calls, [date_card.receipt], "art adds no second acknowledgment")
	var echo_card := _card("echo-next")
	presentation_theme.default_font_size = 36
	assert_true(surface.present_card(echo_card).ok)
	assert_eq(surface._scene_art._entry_id, "echo.fallback.day7")
	assert_not_null(surface._scene_art._background.texture)
	assert_null(surface._scene_art._portraits[0].texture, "a new card clears the prior portrait")
	assert_eq(surface._scene_art.size.y, 328.0)
	surface._current_body.draw.emit()
	surface._next.pressed.emit()
	var missing := _card("missing-art")
	missing.receipt.entry_id = "fixture.without.art"
	assert_true(surface.present_card(missing).ok)
	assert_false(surface._scene_art.visible)
	assert_eq(surface._reading_margin.get_theme_constant("margin_top"), 48)
	assert_eq(surface._current_body.text, missing.body)
	assert_eq(surface.get_presentation_history(), [date_card, echo_card])
	ART.reload_placements()


func _presentation_receipt_surface(acknowledgment: Acknowledgment) -> Node:
	var surface := SURFACE.new()
	assert_true(surface.configure(_card(), acknowledgment.accept).ok)
	assert_true(surface.has_method("use_presentation_receipts"), "Day 7 selects semantic presentation receipts")
	if not surface.has_method("use_presentation_receipts"):
		surface.free()
		return null
	assert_true(surface.call("use_presentation_receipts").ok)
	add_child_autofree(surface)
	return surface


func test_presentation_receipt_is_durable_on_draw_but_navigation_waits_for_next() -> void:
	var acknowledgment := Acknowledgment.new()
	var surface := _presentation_receipt_surface(acknowledgment)
	if surface == null: return
	watch_signals(surface)
	surface._next.pressed.emit()
	assert_eq(acknowledgment.calls, [], "neither creation nor Next fabricates a visual witness")
	surface._current_body.draw.emit()
	assert_eq(acknowledgment.calls, [], "a render callback never performs synchronous save work")
	await get_tree().process_frame
	assert_eq(acknowledgment.calls, [_card().receipt])
	assert_true(surface.is_card_acknowledged(_card().receipt))
	assert_signal_emit_count(surface, "card_acknowledged", 1)
	assert_signal_emit_count(surface, "advance_requested", 0)
	assert_eq(surface._current_body.text, _card().body, "the witnessed card remains available to read")
	surface._current_body.draw.emit()
	await get_tree().process_frame
	assert_eq(acknowledgment.calls.size(), 1, "redraw and passive frames never repeat the receipt")
	assert_signal_emit_count(surface, "advance_requested", 0)
	surface._next.pressed.emit()
	surface._next.pressed.emit()
	assert_signal_emit_count(surface, "advance_requested", 1)
	assert_eq(acknowledgment.calls.size(), 1, "navigation never saves the same receipt again")


func test_failed_presentation_save_retries_same_receipt_without_navigating() -> void:
	var acknowledgment := Acknowledgment.new()
	acknowledgment.succeed = false
	var surface := _presentation_receipt_surface(acknowledgment)
	if surface == null: return
	watch_signals(surface)
	surface._current_body.draw.emit()
	await get_tree().process_frame
	assert_eq(acknowledgment.calls, [_card().receipt])
	assert_false(surface.is_card_acknowledged(_card().receipt))
	assert_eq(surface._next.text, "Retry")
	assert_false(surface.present_card(_card("replacement", "b")).ok)
	acknowledgment.succeed = true
	surface._next.pressed.emit()
	await get_tree().process_frame
	assert_eq(acknowledgment.calls, [_card().receipt, _card().receipt])
	assert_true(surface.is_card_acknowledged(_card().receipt))
	assert_eq(surface._next.text, "Next")
	assert_signal_emit_count(surface, "advance_requested", 0)
	assert_eq(surface.get_presentation_history(), [_card()])
	surface._next.pressed.emit()
	assert_signal_emit_count(surface, "advance_requested", 1)


func test_queued_presentation_cannot_acknowledge_a_retired_surface() -> void:
	var acknowledgment := Acknowledgment.new()
	var surface := _presentation_receipt_surface(acknowledgment)
	if surface == null: return
	surface._current_body.draw.emit()
	surface.queue_free()
	await get_tree().process_frame
	assert_eq(acknowledgment.calls, [], "retiring before deferred admission leaves the atom pending")


func test_production_text_sizes_show_short_body_and_gate_long_card_until_its_leading_edge() -> void:
	if DisplayServer.get_name() == "headless":
		pending("requires native CanvasItem draws and viewport geometry")
		return
	var lines: Array[String] = []
	for index: int in 80:
		lines.append("Remembered line %02d stays available in the complete Day 7 card." % index)
	for percent: int in [100, 125, 150]:
		var context := "%d%% production GalleryTheme" % percent
		var acknowledgment := ApertureAcknowledgment.new()
		var first := _card("first-%d" % percent)
		var surface := SURFACE.new()
		acknowledgment.surface = surface
		assert_true(surface.configure(first, acknowledgment.accept, "en",
			GALLERY_THEME.build("en", percent, &"after_hours")).ok, context)
		assert_true(surface.use_presentation_receipts().ok, context)
		add_child(surface)
		for frame: int in 12:
			await RenderingServer.frame_post_draw
			if acknowledgment.calls.size() == 1: break
		assert_eq(acknowledgment.calls, [first.receipt], context + ": initial real draw acknowledges")
		assert_eq(acknowledgment.geometry.size(), 1, context + ": initial draw records geometry")
		if acknowledgment.geometry.size() != 1:
			surface.free()
			continue
		assert_true(acknowledgment.geometry[0].leading_edge_visible,
			context + ": the initial short body's leading edge enters the aperture")
		assert_true(acknowledgment.geometry[0].body_fully_visible,
			context + ": the complete short line is available at acknowledgment")
		assert_eq(surface._current_body.text, first.body, context + ": exact short copy remains visible")
		var long_card := _card("long-%d" % percent, "b")
		long_card.body = "\n".join(lines)
		assert_true(surface.present_card(long_card).ok, context)
		for frame: int in 20:
			await RenderingServer.frame_post_draw
			if acknowledgment.calls.size() == 2: break
		assert_eq(acknowledgment.calls, [first.receipt, long_card.receipt], context)
		assert_eq(acknowledgment.geometry.size(), 2, context)
		if acknowledgment.geometry.size() < 2:
			surface.free()
			continue
		var witnessed: Dictionary = acknowledgment.geometry[1]
		assert_true(witnessed.leading_edge_visible,
			context + ": a clipped CanvasItem draw cannot acknowledge the long body")
		assert_gt(witnessed.body.size.y, witnessed.aperture.size.y, context + ": long fixture genuinely overflows")
		assert_almost_eq(float(witnessed.title.position.y), float(witnessed.aperture.position.y), 1.0,
			context + ": the new card begins at the scroll and viewport aperture")
		assert_eq(surface._current_body.text, long_card.body, context + ": exact long copy remains available")
		assert_false(surface._current_body.clip_text, context)
		assert_eq(surface.get_presentation_history(), [first, long_card], context + ": history retains full cards")
		for frame: int in 4: await RenderingServer.frame_post_draw
		assert_eq(acknowledgment.calls.size(), 2, context + ": layout and redraw acknowledge each card once")
		surface.free()
