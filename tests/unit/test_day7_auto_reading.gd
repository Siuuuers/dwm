extends GutTest

const SURFACE := preload("res://scripts/ui/Day7PreludeSurface.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const ART := preload("res://scripts/data/ArtManifest.gd")
const GALLERY_THEME := preload("res://scripts/ui/gallery/GalleryTheme.gd")
const AUTO_ENABLED := &"preferences.reading.auto_enabled"
const AUTO_DELAY := &"preferences.reading.auto_delay"


class ReadingProfile extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	signal profile_restored(profile: Dictionary)
	var values := {
		"preferences.reading.auto_enabled": false,
		"preferences.reading.auto_delay": "normal",
	}

	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return values.get(String(path), fallback)

	func publish(path: StringName, value: Variant) -> void:
		values[String(path)] = value
		preference_changed.emit(path, value)

	func restore(enabled: bool, delay: String) -> void:
		values["preferences.reading.auto_enabled"] = enabled
		values["preferences.reading.auto_delay"] = delay
		profile_restored.emit({"preferences": {"reading": {
			"auto_enabled": enabled, "auto_delay": delay}}})


class Acknowledgment extends RefCounted:
	var calls: Array[Dictionary] = []
	var succeed := true

	func accept(receipt: Dictionary) -> Dictionary:
		calls.append(receipt.duplicate(true))
		return {"ok": succeed, "code": &"ok" if succeed else &"write_failed"}


func after_each() -> void:
	get_tree().paused = false


func _card(token: String = "card-one", suffix: String = "a") -> Dictionary:
	return {"title": "Lavinia / Day 1", "body": "A remembered detail: [reply %s]" % suffix,
		"receipt": {"entry_id": "echo.fallback.day7", "view_token": token,
			"echo_id": "echo.lavinia.day1.reply." + suffix,
			"presentation_atom_id": "atom.echo.lavinia.day1.reply.%s.fallback.day7" % suffix}}


func _mount(enabled: bool = true, delay: String = "normal", allow_auto: bool = true,
		locale: String = "en", presentation_receipts: bool = true,
		bind_custody: bool = true, bind_preferences_first: bool = true,
		succeed: bool = true) -> Dictionary:
	var profile := ReadingProfile.new()
	profile.values[String(AUTO_ENABLED)] = enabled
	profile.values[String(AUTO_DELAY)] = delay
	var acknowledgment := Acknowledgment.new()
	acknowledgment.succeed = succeed
	var input := INPUT.new()
	add_child_autofree(input)
	var surface := SURFACE.new()
	if bind_preferences_first:
		assert_true(surface.bind_reading_preferences(profile))
	assert_true(surface.configure(_card(), acknowledgment.accept, locale, null, allow_auto).ok)
	if not bind_preferences_first:
		assert_true(surface.bind_reading_preferences(profile))
	if presentation_receipts:
		assert_true(surface.use_presentation_receipts().ok)
	if bind_custody:
		assert_true(surface.bind_input_custody(input))
	var advances: Array[Dictionary] = []
	var acknowledged: Array[Dictionary] = []
	surface.advance_requested.connect(func(receipt: Dictionary): advances.append(receipt.duplicate(true)))
	surface.card_acknowledged.connect(func(receipt: Dictionary, _result: Dictionary): acknowledged.append(receipt.duplicate(true)))
	add_child_autofree(surface)
	# Engine frames settle deferred receipt/focus work; test time advances only below.
	surface.set_process(false)
	return {"surface": surface, "profile": profile, "input": input,
		"ack": acknowledgment, "advances": advances, "acknowledged": acknowledged}


func _witness(fixture: Dictionary) -> void:
	var surface: Node = fixture.surface
	var expected_call_count: int = fixture.ack.calls.size() + 1
	if DisplayServer.get_name() == "headless":
		# Replacement scroll alignment is deferred; mirror native redraws until its
		# leading edge is eligible rather than treating the old receipt as success.
		for frame: int in 12:
			surface._current_body.draw.emit()
			await get_tree().process_frame
			if fixture.ack.calls.size() == expected_call_count:
				break
	else:
		for frame: int in 12:
			await RenderingServer.frame_post_draw
			if fixture.ack.calls.size() == expected_call_count:
				break
	await get_tree().process_frame
	assert_eq(fixture.ack.calls.size(), expected_call_count)
	if fixture.ack.calls.size() == expected_call_count:
		assert_eq(fixture.ack.calls[-1], surface._card.receipt)
	await get_tree().process_frame
	# Consume the post-draw generation guard without spending reading time.
	surface._process(0.0)


func _draw_gallery(surface: Node) -> void:
	if DisplayServer.get_name() == "headless":
		surface._current_body.draw.emit()
	else:
		await RenderingServer.frame_post_draw
	await get_tree().process_frame


func _action(pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	return event


func _key(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_A
	event.pressed = pressed
	return event


func test_indicator_is_visible_localized_and_tracks_profile_publications() -> void:
	var expected := {"en": "Auto On", "zh-CN": "自动：开启", "zh-HK": "自動：開啟"}
	for locale: String in expected:
		var f := _mount(true, "normal", true, locale, true, true, locale != "zh-CN")
		var indicator := f.surface.find_child("AutoReadingState", true, false) as Label
		assert_not_null(indicator, locale)
		if indicator == null:
			continue
		assert_true(indicator.is_visible_in_tree(), locale)
		assert_eq(indicator.text, expected[locale], locale)
		f.profile.publish(AUTO_ENABLED, false)
		assert_eq(indicator.text, "Auto Off" if locale == "en" else ("自动：关闭" if locale == "zh-CN" else "自動：關閉"), locale)
		f.profile.restore(true, "normal")
		assert_eq(indicator.text, expected[locale], locale)


func test_auto_requires_draw_acceptance_opt_in_custody_and_a_nonfinal_card() -> void:
	var not_drawn := _mount()
	not_drawn.surface._process(20.0)
	assert_eq(not_drawn.ack.calls, [])
	assert_eq(not_drawn.advances, [])

	var failed := _mount(true, "short", true, "en", true, true, true, false)
	await _witness(failed)
	failed.surface._process(20.0)
	failed.surface._process(20.0)
	assert_eq(failed.ack.calls.size(), 1, "Auto never retries a failed persistence operation")
	assert_eq(failed.acknowledged, [])
	assert_eq(failed.advances, [])

	var final_card := _mount(true, "short", false)
	await _witness(final_card)
	final_card.surface._process(20.0)
	assert_eq(final_card.acknowledged, [_card().receipt])
	assert_eq(final_card.advances, [])

	var no_custody := _mount(true, "short", true, "en", true, false)
	await _witness(no_custody)
	no_custody.surface._process(20.0)
	assert_eq(no_custody.advances, [])

	var gallery := _mount(true, "short", true, "en", false, true)
	await _draw_gallery(gallery.surface)
	gallery.surface._process(20.0)
	assert_eq(gallery.ack.calls, [], "Gallery's default receipt mode stays manual")
	assert_eq(gallery.advances, [])


func test_disabled_auto_never_advances_an_acknowledged_card() -> void:
	var f := _mount(false, "short")
	await _witness(f)
	f.surface._process(100.0)
	assert_eq(f.acknowledged, [_card().receipt])
	assert_eq(f.advances, [])


func test_delay_presets_count_exact_foreground_seconds_once_without_clicking() -> void:
	var delays := {"short": 1.0, "normal": 2.0, "long": 4.0}
	for delay: String in delays:
		var f := _mount(true, delay)
		var button_presses := [0]
		f.surface._next.pressed.connect(func(): button_presses[0] += 1)
		await _witness(f)
		var seconds: float = delays[delay]
		f.surface._process(seconds - 0.01)
		assert_eq(f.advances, [], delay)
		f.surface._process(0.02)
		f.surface._process(seconds * 2.0)
		assert_eq(f.advances, [_card().receipt], delay)
		assert_eq(f.ack.calls.size(), 1, delay + ": navigation adds no receipt")
		assert_eq(button_presses[0], 0, delay + ": Auto does not fabricate a Button press")


func test_focus_pause_cover_and_held_input_suspend_the_remaining_delay() -> void:
	var f := _mount(true, "short")
	await _witness(f)
	f.surface._process(0.2)

	f.surface._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	f.surface._process(5.0)
	assert_eq(f.advances, [])
	f.surface._notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await get_tree().process_frame

	get_tree().paused = true
	f.surface._process(5.0)
	get_tree().paused = false
	assert_eq(f.advances, [])
	await get_tree().process_frame

	var captured: Dictionary = f.surface.capture_pause_view({"source": "fixture"})
	assert_true(captured.ok)
	assert_true(f.surface.cover_pause_view(captured.value))
	f.surface._process(5.0)
	assert_eq(f.advances, [])
	assert_true(f.surface.restore_pause_view(captured.value))
	await get_tree().process_frame

	f.input.observe_physical_contact(_key(true))
	f.surface._process(5.0)
	assert_eq(f.advances, [])
	f.input.observe_physical_contact(_key(false))
	f.surface._process(0.79)
	assert_eq(f.advances, [])
	f.surface._process(0.02)
	assert_eq(f.advances, [_card().receipt])


func test_delay_and_enabled_publications_restart_a_full_generation() -> void:
	var timing := _mount(true, "short")
	await _witness(timing)
	timing.surface._process(0.75)
	timing.profile.publish(AUTO_DELAY, "long")
	timing.surface._process(0.0)
	timing.surface._process(3.99)
	assert_eq(timing.advances, [])
	timing.surface._process(0.02)
	assert_eq(timing.advances, [_card().receipt])

	var toggle := _mount(true, "short")
	await _witness(toggle)
	toggle.surface._process(0.75)
	toggle.profile.publish(AUTO_ENABLED, false)
	toggle.surface._process(20.0)
	assert_eq(toggle.advances, [])
	toggle.profile.restore(true, "short")
	toggle.surface._process(0.0)
	toggle.surface._process(0.99)
	assert_eq(toggle.advances, [])
	toggle.surface._process(0.02)
	assert_eq(toggle.advances, [_card().receipt])


func test_replacing_a_card_retires_its_deadline_and_starts_the_new_card_full() -> void:
	var f := _mount(true, "short")
	await _witness(f)
	f.surface._process(0.75)
	var replacement := _card("card-two", "b")
	assert_true(f.surface.present_card(replacement, true).ok)
	await _witness(f)
	assert_eq(f.ack.calls, [_card().receipt, replacement.receipt])
	f.surface._process(0.99)
	assert_eq(f.advances, [], "the old card's remaining quarter-second cannot cross identities")
	f.surface._process(0.02)
	assert_eq(f.advances, [replacement.receipt])


func test_manual_next_retires_auto_and_neither_path_can_duplicate_navigation() -> void:
	var f := _mount(true, "short")
	await _witness(f)
	f.surface._process(0.8)
	f.surface._next.grab_focus()
	f.surface._input(_action(true))
	f.surface._input(_action(false))
	assert_eq(f.advances, [_card().receipt])
	f.surface._process(20.0)
	f.surface._input(_action(true))
	f.surface._input(_action(false))
	assert_eq(f.advances, [_card().receipt])
	assert_eq(f.ack.calls.size(), 1)


func test_native_auto_footer_preserves_the_art_card_reading_aperture_at_production_sizes() -> void:
	if DisplayServer.get_name() == "headless":
		pending("requires native CanvasItem draws and viewport geometry")
		return
	var catalog := {"schema_version": 1,
		"assets": {"fixture.background": {"path": "res://icon.svg", "size": [128, 128]}},
		"scenes": {"echo.fallback.day7": {
			"background": "fixture.background", "portraits": [], "cg": ""}}}
	var file := FileAccess.open("user://day7-auto-footer-art.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog))
	file.close()
	assert_true(ART.reload_placements("user://day7-auto-footer-art.json"))
	for percent: int in [100, 125, 150]:
		var context := "%d%% production GalleryTheme" % percent
		var profile := ReadingProfile.new()
		profile.values[String(AUTO_ENABLED)] = true
		var acknowledgment := Acknowledgment.new()
		var input := INPUT.new()
		add_child_autofree(input)
		var surface := SURFACE.new()
		assert_true(surface.bind_reading_preferences(profile), context)
		assert_true(surface.configure(_card("auto-footer-%d" % percent), acknowledgment.accept, "en",
			GALLERY_THEME.build("en", percent, &"after_hours"), true).ok, context)
		assert_true(surface.use_presentation_receipts().ok, context)
		assert_true(surface.bind_input_custody(input), context)
		add_child(surface)
		surface.set_process(false)
		for frame: int in 12:
			await RenderingServer.frame_post_draw
			if acknowledgment.calls.size() == 1:
				break
		assert_eq(acknowledgment.calls, [surface._card.receipt], context + ": real body draw acknowledges")
		assert_true(surface.is_card_acknowledged(surface._card.receipt), context)
		assert_eq(surface.get_presentation_history(), [surface._card], context)
		assert_true(surface._scene_art.visible, context)
		assert_not_null(surface._scene_art._background.texture, context)
		var indicator := surface.find_child("AutoReadingState", true, false) as Label
		assert_not_null(indicator, context)
		if indicator == null:
			surface.free()
			continue
		assert_eq(indicator.text, "Auto On", context)
		assert_eq(indicator.get_parent(), surface._next.get_parent(), context + ": Auto and Next share one footer")
		assert_true(indicator.get_parent() is HBoxContainer, context)
		var aperture: Rect2 = surface._scroll.get_global_rect().intersection(surface._root.get_viewport_rect())
		var title_rect: Rect2 = surface._current_title.get_global_rect()
		var body_rect: Rect2 = surface._current_body.get_global_rect()
		assert_true(aperture.has_area(), context + ": scroll retains a reading aperture")
		assert_true(aperture.intersects(title_rect), context + ": title remains in the aperture")
		assert_true(aperture.intersects(body_rect), context + ": drawn body remains in the aperture")
		assert_gte(body_rect.position.y, aperture.position.y - 1.0, context)
		assert_lt(body_rect.position.y, aperture.end.y, context)
		surface.free()
	ART.reload_placements()
