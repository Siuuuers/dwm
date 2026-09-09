extends GutTest
const SURFACE := preload("res://scripts/ui/Day7PreludeSurface.gd")
const ART := preload("res://scripts/data/ArtManifest.gd")

class Acknowledgment extends RefCounted:
	signal released
	var calls: Array[Dictionary] = []
	var succeed := true
	var hold := false
	func accept(receipt: Dictionary) -> Dictionary:
		calls.append(receipt.duplicate(true))
		if hold: await released
		return {"ok": succeed, "value": {"retained": receipt.duplicate(true)}, "code": &"ok" if succeed else &"write_failed"}

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
