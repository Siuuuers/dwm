extends GutTest

const MAIN := preload("res://scenes/main/MainGameScene.tscn")
const ROW_IDS := ["DayLabel", "PressureRow", "HealthRow", "MotivationRow", "MoneyRow",
	"CoinRow", "ConditionDisplay", "PenaltyLabel", "UnavailableLabel"]
const CORE_COPY := {
	"en": ["Day", "Pressure", "Health", "Motivation", "Money", "Coins"],
	"zh-CN": ["天数", "压力", "健康", "动力", "金钱", "硬币"],
	"zh-HK": ["天數", "壓力", "健康", "動力", "金錢", "硬幣"],
}


class PublicOwner extends Node:
	signal stat_changed(stat: String, value: int, minimum: int, maximum: int)
	signal day_changed(day: int)
	signal condition_effect_resolved(result: Dictionary)
	var day := 3
	var money := 9223372036854775807
	var coins := -9223372036854775807
	var condition_effects_today: Array = ["nausea", "dizzy", "sequela", "faint"]
	var penalty_points_today := 6
	var stats := {"pressure": 9, "health": 0, "motivation": 7}
	var forbidden_reads := 0
	var writes := 0
	func get_stat_display_value(stat: String) -> int:
		return clampi(stats[stat], 0, get_stat_display_max(stat))
	func get_stat_display_max(stat: String) -> int:
		return 7 if stat == "motivation" else 9
	func get_run_configuration() -> Dictionary:
		return {"ok": true, "value": {"dark_mode": false}}
	func get_stat(_stat: String) -> int:
		forbidden_reads += 1
		return -31337
	func get_minesweeper_display_rounds_left() -> int:
		forbidden_reads += 1
		return 31337
	func get_minesweeper_display_rounds_max() -> int:
		forbidden_reads += 1
		return 31338
	func set_stat(_stat: String, _value: int) -> void:
		writes += 1
	func capture() -> Dictionary:
		return {"day": day, "money": money, "coins": coins, "stats": stats.duplicate(),
			"conditions": condition_effects_today.duplicate(), "penalty": penalty_points_today}


class Locale extends Node:
	signal locale_changed(locale: String)
	var locale := "en"
	func get_locale() -> String: return locale
	func change(value: String) -> void:
		locale = value
		locale_changed.emit(value)


class Profile extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var values := {}
	func get_preference(path: String, fallback: Variant = null) -> Variant:
		return values.get(path, fallback)
	func change(path: StringName, value: Variant) -> void:
		values[String(path)] = value
		preference_changed.emit(path, value)


var _viewport: SubViewport
var _main: Control
var _owner: PublicOwner
var _locale: Locale
var _profile: Profile
var _hud: Control
var _panel: Control
var _art: Control
var _split: Container


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_owner = PublicOwner.new()
	_locale = Locale.new()
	_profile = Profile.new()
	add_child_autofree(_owner)
	add_child_autofree(_locale)
	_main = MAIN.instantiate()
	assert_true(_main.bind_view_preferences(null))
	_hud = _main.get_node("%StatHud")
	_hud.configure(_owner, _locale, _profile)
	# Main's actual art, stat overlay and divider; unrelated desktop commands stay absent.
	var desktop := Control.new()
	_main._computer_desktop_instance = desktop
	_main.get_node("%ComputerPanel").add_child(desktop)
	_viewport.add_child(_main)
	_panel = _main.get_node("%AngelaPanel")
	_art = _main.get_node("%AngelaImage")
	_split = _main.get_node("RootHBox")
	await _settle()


func _settle() -> void:
	for _frame: int in range(6): await get_tree().process_frame


func _row(id: String) -> Label:
	return _hud.get_node("%" + id) as Label


func _public_surface(node: Node) -> Array:
	var result: Array = []
	if node is Control:
		var metadata := {}
		for key: StringName in node.get_meta_list(): metadata[key] = node.get_meta(key)
		var surface := {"path": str(node.name), "visible": node.visible, "rect": node.get_rect(),
			"name": node.accessibility_name, "description": node.accessibility_description,
			"tooltip": node.tooltip_text, "metadata": metadata, "focus": node.focus_mode}
		if node is Label: surface["text"] = node.text
		result.append(surface)
	for child: Node in node.get_children(): result.append_array(_public_surface(child))
	return result


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_viewport.push_input(event, true)


func _touch(point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	_viewport.push_input(event, true)


func test_portrait_fills_the_panel_behind_an_inset_translucent_stat_card() -> void:
	for width: int in [480, 320]:
		_split.set_angela_width(width)
		await _settle()
		assert_eq(_art.get_global_rect(), _panel.get_global_rect(), "facts no longer reserve portrait height")
		assert_true(_panel.get_global_rect().encloses(_hud.get_global_rect()))
		assert_true(_art.get_global_rect().intersects(_hud.get_global_rect()), "card overlays the artwork")
		assert_gt(_hud.get_global_rect().position.x, _panel.get_global_rect().position.x)
		assert_lt(_hud.get_global_rect().end.x, _panel.get_global_rect().end.x)
		assert_gt(_hud.get_global_rect().position.y, _panel.get_global_rect().position.y)
		assert_lt(_hud.get_global_rect().end.y, _panel.get_global_rect().end.y)
		assert_false(_hud.get_global_rect().intersects(_split.get_node("SplitDragHandle").get_global_rect()),
			"the whole card stays clear of the divider target")
		assert_gt(_art.get_child_count(), 0, "actual shipped artwork is mounted")
		for layer: Control in _art.get_children():
			assert_eq(layer.get_global_rect(), _art.get_global_rect())
			assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var panel: StyleBoxFlat = _hud.get_theme_stylebox("panel")
	assert_gt(panel.bg_color.a, 0.0, "a readable tinted surface remains")
	assert_lt(panel.bg_color.a, 1.0, "normal mode lets the artwork show through")


func test_all_public_facts_stay_readable_at_both_widths_and_all_supported_text_sizes() -> void:
	var initial := _owner.capture()
	for width: int in [480, 320]:
		_split.set_angela_width(width)
		for locale: String in ["en", "zh-CN", "zh-HK"]:
			_locale.change(locale)
			for percent: int in [100, 125, 150]:
				_profile.change(&"preferences.accessibility.text_size", percent)
				await _settle()
				var context := "%s/%s/%s" % [width, locale, percent]
				assert_true(_panel.get_global_rect().encloses(_hud.get_global_rect()), context)
				var scroll: ScrollContainer = _hud.get_node("%StatScroll")
				assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, context)
				assert_eq(_row("PressureRow").get_theme_font_size("font_size"), 24 * percent / 100, context)
				for index: int in range(6):
					assert_true(_row(ROW_IDS[index]).text.begins_with(CORE_COPY[locale][index]), context)
				assert_true(_row("MoneyRow").text.ends_with(str(_owner.money)), context)
				assert_true(_row("CoinRow").text.ends_with(str(_owner.coins)), context)
				var previous := Rect2()
				for id: String in ROW_IDS:
					var row := _row(id)
					if not row.visible: continue
					assert_eq(row.max_lines_visible, -1, context + ": no hidden lines")
					assert_eq(row.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, context)
					assert_gte(row.size.y, row.get_minimum_size().y, context + ": full wrapped height")
					assert_lte(row.get_minimum_size().x, row.size.x, context + ": full horizontal text")
					assert_eq(row.accessibility_name, row.text, context)
					assert_eq(row.focus_mode, Control.FOCUS_NONE, context)
					assert_false(previous.intersects(row.get_rect()), context + ": rows never overlap")
					previous = row.get_rect()
					scroll.ensure_control_visible(row)
					await _settle()
					assert_true(scroll.get_global_rect().grow(0.01).encloses(row.get_global_rect()), context + ": %s is reachable" % id)
	assert_eq(_owner.capture(), initial)
	assert_eq(_owner.forbidden_reads, 0)
	assert_eq(_owner.writes, 0)


func test_conditional_rows_withdraw_and_invalid_facts_do_not_leak_identifiers() -> void:
	assert_true(_row("ConditionDisplay").visible)
	assert_true(_row("PenaltyLabel").visible)
	assert_eq(_row("ConditionDisplay").text, "Condition: Nausea, Dizziness, Aftereffects, Fainting")
	assert_eq(_row("PenaltyLabel").text, "Daily penalty: 6")
	var complete_height := _hud.size.y
	_owner.condition_effects_today.clear()
	_owner.penalty_points_today = 0
	_hud.refresh_all()
	await _settle()
	assert_false(_row("ConditionDisplay").visible)
	assert_false(_row("PenaltyLabel").visible)
	assert_lt(_hud.size.y, complete_height, "empty conditions do not reserve blank card space")
	_owner.condition_effects_today = ["unknown_private_condition"]
	_owner.condition_effect_resolved.emit({"condition": "another_private_payload"})
	await _settle()
	assert_eq(_row("ConditionDisplay").text, "Condition unavailable")
	assert_false(str(_public_surface(_hud)).contains("private"))
	_owner.day = 8
	_owner.day_changed.emit(8)
	await _settle()
	assert_true(_row("UnavailableLabel").visible)
	for id: String in ROW_IDS:
		if id != "UnavailableLabel": assert_false(_row(id).visible)
	assert_eq(_row("UnavailableLabel").text, "Status unavailable")


func test_high_contrast_replaces_glass_with_the_exact_opaque_accessible_surface() -> void:
	_profile.change(&"preferences.accessibility.high_contrast", true)
	await _settle()
	var panel: StyleBoxFlat = _hud.get_theme_stylebox("panel")
	assert_eq(panel.bg_color, _hud.theme.get_color("habitat", "Desktop"))
	assert_eq(panel.bg_color.a, 1.0)
	assert_eq(_row("PressureRow").get_theme_color("font_color"), _hud.theme.get_color("ink", "Desktop"))
	_profile.change(&"preferences.accessibility.high_contrast", false)
	await _settle()
	assert_lt(_hud.get_theme_stylebox("panel").bg_color.a, 1.0)


func test_dense_facts_are_reachable_with_wheel_native_keyboard_and_touch() -> void:
	_split.set_angela_width(320)
	_profile.change(&"preferences.accessibility.text_size", 150)
	await _settle()
	var scroll: ScrollContainer = _hud.get_node("%StatScroll")
	var bar := scroll.get_v_scroll_bar()
	assert_true(bar.visible)
	assert_eq(bar.focus_mode, Control.FOCUS_ALL)
	assert_false(bar.accessibility_name.is_empty())
	assert_false(_hud.get_global_rect().intersects(_split.get_node("SplitDragHandle").get_global_rect()))
	scroll.scroll_vertical = 0
	var wheel := InputEventMouseButton.new()
	wheel.position = scroll.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	_viewport.push_input(wheel, true)
	await _settle()
	assert_gt(scroll.scroll_vertical, 0, "wheel reaches facts below the compact card")
	bar.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_END
	key.physical_keycode = KEY_END
	key.pressed = true
	_viewport.push_input(key, true)
	await _settle()
	assert_true(scroll.get_global_rect().grow(0.01).encloses(_row("PenaltyLabel").get_global_rect()),
		"native scrollbar End reaches the last public fact")
	key = key.duplicate()
	key.keycode = KEY_HOME
	key.physical_keycode = KEY_HOME
	_viewport.push_input(key, true)
	await _settle()
	assert_eq(scroll.scroll_vertical, 0, "native scrollbar Home returns to the day")
	scroll.scroll_vertical = 0
	# Native ScrollContainer uses touch-emulated mouse packets; raw ScreenDrag
	# bypasses that engine path when pushed directly into a SubViewport.
	var prior_emulation := Input.is_emulating_touch_from_mouse()
	Input.set_emulate_touch_from_mouse(true)
	assert_true(DisplayServer.is_touchscreen_available())
	var start := scroll.get_global_rect().get_center()
	_mouse(start, true)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = start - Vector2(0, 100)
	drag.global_position = drag.position
	drag.relative = Vector2(0, -100)
	_viewport.push_input(drag, true)
	drag = drag.duplicate()
	drag.position -= Vector2(0, 20)
	drag.global_position = drag.position
	drag.relative = Vector2(0, -20)
	_viewport.push_input(drag, true)
	_mouse(drag.position, false)
	Input.set_emulate_touch_from_mouse(prior_emulation)
	await _settle()
	assert_gt(scroll.scroll_vertical, 0, "native touch dragging scrolls long facts")
	assert_eq(_split.get_angela_width(), 320.0, "scroll gestures never acquire the divider")
	assert_eq(_owner.writes, 0)


func test_hidden_ranges_remain_indistinguishable_on_the_complete_public_surface() -> void:
	var public_before := _public_surface(_hud)
	for pressure: int in [10, 11, 12]:
		for health: int in [-1, -2]:
			_owner.stats.pressure = pressure
			_owner.stats.health = health
			var owner_before := _owner.capture()
			_owner.stat_changed.emit("pressure", pressure, 0, 12)
			_owner.stat_changed.emit("health", health, -2, 9)
			await _settle()
			assert_eq(_public_surface(_hud), public_before, "glass cannot disclose hidden stats through text, metadata or layout")
			assert_eq(_owner.capture(), owner_before)
	assert_eq(_owner.forbidden_reads, 0)
	assert_eq(_owner.writes, 0)


func test_mouse_and_touch_divider_keep_focus_and_commit_once_after_release() -> void:
	var focus := Button.new()
	focus.size = Vector2(100, 50)
	_main.get_node("%ComputerPanel").add_child(focus)
	focus.grab_focus()
	var changes: Array[float] = []
	_split.split_changed.connect(func(width: float): changes.append(width))
	var initial_art := _art.get_global_rect()
	var initial_hud := _hud.get_global_rect()
	_mouse(Vector2(472, 360), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(312, 360)
	motion.global_position = motion.position
	motion.relative = Vector2(-160, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(motion, true)
	await _settle()
	assert_eq(_art.get_global_rect(), initial_art)
	assert_eq(_hud.get_global_rect(), initial_hud)
	assert_true(changes.is_empty())
	_mouse(motion.position, false)
	await _settle()
	assert_eq(changes, [320.0])
	assert_eq(_art.size.x, 320.0)
	assert_same(_viewport.gui_get_focus_owner(), focus)
	_touch(Vector2(312, 360), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(472, 360)
	drag.relative = Vector2(160, 0)
	_viewport.push_input(drag, true)
	await _settle()
	assert_eq(_art.size.x, 320.0, "glass and portrait remain stable during touch preview")
	_touch(drag.position, false, true)
	await _settle()
	assert_eq(changes, [320.0], "cancelled touch cannot commit")
	_touch(Vector2(312, 360), true)
	_viewport.push_input(drag, true)
	_touch(drag.position, false)
	await _settle()
	assert_eq(changes, [320.0, 480.0])
	assert_eq(_art.get_global_rect(), initial_art)
	assert_same(_viewport.gui_get_focus_owner(), focus)
	assert_eq(_owner.writes, 0)
