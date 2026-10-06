extends SceneTree

class StateFixture extends Node:
	signal stat_changed(stat_id: String, value: int, min_value: int, max_value: int)
	signal money_changed(value: int)
	signal coins_changed(value: int)
	signal day_changed(day: int)
	signal condition_effect_resolved(result: Dictionary)
	signal minesweeper_rounds_changed(left: int, maximum: int)
	const STAT_PRESSURE := "pressure"
	const STAT_HEALTH := "health"
	const STAT_MOTIVATION := "motivation"
	var day := 3
	var money := -250
	var coins := 12
	var stats := {"pressure": 3, "health": 6, "motivation": 7}
	var condition_effects_today: Array[String] = []
	var penalty_points_today := 0
	var forbidden_reads := 0
	var writes := 0
	func get_stat_display_value(id: String) -> int:
		return clampi(stats[id], 0, get_stat_display_max(id))
	func get_stat_display_max(id: String) -> int:
		return 7 if id == "motivation" else 9
	func get_stat(_id: String) -> int:
		forbidden_reads += 1
		return -999
	func get_minesweeper_display_rounds_left() -> int:
		forbidden_reads += 1
		return 31337
	func get_minesweeper_display_rounds_max() -> int:
		forbidden_reads += 1
		return 31338
	func set_stat(_id: String, _value: int) -> void:
		writes += 1
	func capture() -> Dictionary:
		return {"day": day, "money": money, "coins": coins, "stats": stats.duplicate(true),
			"conditions": condition_effects_today.duplicate(), "penalty": penalty_points_today}

class LocaleFixture extends Node:
	signal locale_changed(locale: String)
	var locale := "en"
	func get_locale() -> String:
		return locale
	func change(value: String) -> void:
		locale = value
		locale_changed.emit(value)

class ProfileFixture extends Node:
	signal preference_changed(path: StringName, value: Variant)
	var scale := 1.0
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return roundi(scale * 100) if path == &"preferences.accessibility.text_size" else fallback
	func change(value: float) -> void:
		scale = value
		preference_changed.emit(&"preferences.accessibility.text_size", roundi(value * 100))

const ROWS := ["DayLabel", "PressureRow", "HealthRow", "MotivationRow", "MoneyRow", "CoinRow", "ConditionDisplay", "PenaltyLabel", "UnavailableLabel"]
const NAMES := {
	"en": ["Day", "Pressure", "Health", "Motivation", "Money", "Coins"],
	"zh-CN": ["天", "压力", "健康", "动力", "金钱", "硬币"],
	"zh-HK": ["天", "壓力", "健康", "動力", "金錢", "硬幣"],
	"ja": ["日目", "プレッシャー", "体調", "意欲", "所持金", "コイン"],
	"ko": ["일차", "압박감", "건강", "의욕", "소지금", "코인"]}
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in 4:
		await process_frame

func row(hud: Control, id: String) -> Label:
	return hud.get_node("%" + id) as Label

func public_snapshot(node: Node) -> Array:
	var result: Array = []
	if node is Control:
		var control := node as Control
		var metadata := {}
		for key: StringName in control.get_meta_list():
			metadata[key] = control.get_meta(key)
		var entry := {"path": str(control.name), "visible": control.visible, "rect": control.get_rect(),
			"tooltip": control.tooltip_text, "name": control.accessibility_name,
			"description": control.accessibility_description, "metadata": metadata,
			"focus": control.focus_mode, "modulate": control.modulate, "self_modulate": control.self_modulate}
		if control is Label:
			entry["text"] = control.text
			entry["color"] = control.get_theme_color("font_color")
			entry["font_size"] = control.get_theme_font_size("font_size")
		result.append(entry)
	for child: Node in node.get_children():
		result.append_array(public_snapshot(child))
	return result

func visible_rows(hud: Control) -> Array[Label]:
	var result: Array[Label] = []
	for id: String in ROWS:
		var label := row(hud, id)
		if label.is_visible_in_tree():
			result.append(label)
	return result

func layout_valid(hud: Control) -> bool:
	if hud.size.x > 480.0 or hud.size.y > 720.0:
		print("LAYOUT hud size ", hud.size)
		return false
	var previous: Rect2 = Rect2()
	for label: Label in visible_rows(hud):
		var rect := label.get_global_rect()
		if not hud.get_global_rect().encloses(rect) or rect.size.y < label.get_minimum_size().y:
			print("LAYOUT bounds ", label.name, " ", rect, " minimum ", label.get_minimum_size(), " hud ", hud.get_global_rect())
			return false
		if label.max_lines_visible != -1 or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			print("LAYOUT truncation ", label.name, " ", label.max_lines_visible, " ", label.text_overrun_behavior)
			return false
		if previous.has_area() and previous.intersects(rect):
			return false
		previous = rect
	return true

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var owner := StateFixture.new()
	var locale := LocaleFixture.new()
	var profile := ProfileFixture.new()
	root.add_child(owner)
	root.add_child(locale)
	root.add_child(profile)
	var hud: Control = load("res://scenes/shared/StatHud.tscn").instantiate()
	var initial := owner.capture()
	if not hud.has_method("configure"):
		check(false, "Actual StatHud exposes the injected projection seam")
		hud.free()
		_finish(owner, locale, profile)
		return
	hud.call("configure", owner, locale, profile)
	hud.position = Vector2.ZERO
	hud.size = Vector2(480, 720)
	root.add_child(hud)
	await settle()
	# Reapply the allocated body after the first container layout, just as the
	# parent game's container does. Godot still enforces the real minimum size.
	hud.size = Vector2(480, 720)
	await settle()
	check(row(hud, "DayLabel").text.contains("3"), "Day projects the current logical day")
	check(row(hud, "PressureRow").text.contains("3 / 9") and row(hud, "HealthRow").text.contains("6 / 9") and row(hud, "MotivationRow").text.contains("7 / 7"), "All three stats show audience values and public maxima")
	check(row(hud, "MoneyRow").text.contains("-250") and row(hud, "CoinRow").text.contains("12"), "Balances retain exact signed money and coins")
	check(not row(hud, "ConditionDisplay").visible and not row(hud, "PenaltyLabel").visible, "No condition or zero penalty publishes a placeholder")
	check(hud.find_child("MinesweeperRoundRow", true, false) == null, "Global Minesweeper round counter is absent from the scene")
	check(owner.capture() == initial and owner.writes == 0 and owner.forbidden_reads == 0, "Mounting and initial refresh read only audience owner facts")

	# Compare the complete exposed Control surface, not just the visible number.
	owner.stats["pressure"] = 9
	owner.stats["health"] = 0
	hud.call("refresh_all")
	await settle()
	var clamp_baseline := public_snapshot(hud)
	for hidden_pressure: int in [10, 11, 12]:
		for hidden_health: int in [-1, -2]:
			owner.stats["pressure"] = hidden_pressure
			owner.stats["health"] = hidden_health
			var owner_before_signal := owner.capture()
			owner.stat_changed.emit("pressure", hidden_pressure, 0, 12)
			owner.stat_changed.emit("health", hidden_health, -2, 9)
			await settle()
			check(public_snapshot(hud) == clamp_baseline and owner.capture() == owner_before_signal, "Hidden pressure %s / health %s remains unchanged and indistinguishable from public 9 / 0" % [hidden_pressure, hidden_health])
	owner.money = 975
	owner.money_changed.emit(owner.money)
	owner.coins = -4
	owner.coins_changed.emit(owner.coins)
	owner.day = 7
	owner.day_changed.emit(owner.day)
	await settle()
	check(row(hud, "MoneyRow").text.contains("975") and row(hud, "CoinRow").text.contains("-4") and row(hud, "DayLabel").text.contains("7"), "Owner signals refresh exact public balances and day")
	owner.condition_effects_today.assign(["nausea"])
	owner.penalty_points_today = 3
	owner.condition_effect_resolved.emit({"condition": "nausea", "faint": false})
	await settle()
	check(row(hud, "ConditionDisplay").visible and row(hud, "ConditionDisplay").text.contains("Nausea"), "Known current condition has localized public copy")
	check(row(hud, "PenaltyLabel").visible and row(hud, "PenaltyLabel").text.contains("3"), "Nonzero current daily penalty is shown without cumulative explanation")
	var condition_before_payload := public_snapshot(hud)
	owner.condition_effect_resolved.emit({"condition": "payload_secret_not_canonical", "faint": true})
	await settle()
	check(public_snapshot(hud) == condition_before_payload, "Signal payload cannot replace canonical current condition or leak extra facts")
	owner.condition_effects_today.assign(["unregistered_secret_condition"])
	owner.penalty_points_today = 0
	owner.condition_effect_resolved.emit({"condition": "unregistered_secret_condition"})
	await settle()
	check(not str(public_snapshot(hud)).contains("unregistered_secret_condition") and row(hud, "ConditionDisplay").text == "Condition unavailable", "Unknown condition identifiers yield neutral unavailability without disclosure")
	check(not row(hud, "PenaltyLabel").visible, "Clearing daily penalty removes its row")

	owner.condition_effects_today.assign(["nausea", "dizzy", "sequela", "faint"])
	owner.penalty_points_today = 6
	owner.day = 3
	owner.day_changed.emit(owner.day)
	for code: String in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
		locale.change(code)
		for scale: float in [1.0, 1.25, 1.5]:
			profile.change(scale)
			await settle()
			var names_present := true
			for i: int in 6:
				names_present = names_present and row(hud, ROWS[i]).text.contains(NAMES[code][i])
			check(names_present, "%s %.2f has localized labels for every core fact" % [code, scale])
			check(layout_valid(hud), "%s %.2f complete text fits the 480x720 HUD without overlap or truncation" % [code, scale])
			var accessible := true
			for label: Label in visible_rows(hud):
				accessible = accessible and label.focus_mode == Control.FOCUS_NONE and label.accessibility_name == label.text and label.tooltip_text.is_empty()
			check(accessible, "%s %.2f visible facts equal noninteractive accessible facts" % [code, scale])
			check(row(hud, "PressureRow").get_theme_font_size("font_size") >= int(20 * scale), "%s %.2f respects the requested readable text scale" % [code, scale])
	owner.day = 8
	owner.day_changed.emit(8)
	await settle()
	check(row(hud, "UnavailableLabel").visible and visible_rows(hud).size() == 1 and not row(hud, "UnavailableLabel").text.contains("8"), "Terminal day withdraws all desktop facts into neutral unavailability")
	owner.day = 2
	owner.condition_effects_today.clear()
	owner.penalty_points_today = 0
	owner.day_changed.emit(2)
	await settle()
	check(not row(hud, "UnavailableLabel").visible and row(hud, "DayLabel").visible and not row(hud, "ConditionDisplay").visible, "A valid owner refresh restores only current permitted facts")
	var final_owner := owner.capture()
	hud.call("refresh_all")
	locale.change("en")
	profile.change(1.0)
	await settle()
	check(owner.capture() == final_owner and owner.writes == 0 and owner.forbidden_reads == 0, "Refresh and preference changes neither mutate owners nor consult hidden values")
	hud.queue_free()
	await process_frame
	_finish(owner, locale, profile)

func _finish(owner: Node, locale: Node, profile: Node) -> void:
	owner.free()
	locale.free()
	profile.free()
	print(JSON.stringify({"suite": "stat_hud", "checks": checks, "failures": failures}))
	if failures.is_empty():
		print("STAT_HUD_PASS")
	quit(0 if failures.is_empty() else 1)
