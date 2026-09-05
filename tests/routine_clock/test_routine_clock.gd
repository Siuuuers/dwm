extends SceneTree
const CLOCK := preload("res://scripts/ui/desktop/RoutineClock.gd")
var failures := 0
var reads := 0
var clock_value: Variant = {"hour": 9, "minute": 5, "second": 47}

func _initialize() -> void:
	call_deferred("_run")

func _read_time() -> Variant:
	reads += 1
	return clock_value

func _run() -> void:
	var clock := CLOCK.new()
	clock.configure_clock(_read_time)
	clock.set_foreground_eligible(true)
	root.add_child(clock)
	_check(reads == 1, "initial mount reads exactly once before any post-mount refresh")
	_check(clock.text == "09:05", "initial foreground read uses padded local time")
	_check(clock._timer.one_shot and clock._timer.wait_time == 13, "one-shot aligns next read to minute")
	_check(clock.focus_mode == Control.FOCUS_NONE and clock.mouse_filter == Control.MOUSE_FILTER_IGNORE, "clock has no focus or pointer target")
	_check(int(clock.accessibility_live) == 0, "clock is not a live announcement region")
	var font: Font = clock.get_theme_font("font")
	for percent: int in [100, 125, 150]:
		clock.set_presentation("en", percent)
		var font_size := clock.get_theme_font_size("font_size")
		_check(font_size == int(24 * percent / 100.0), "shared font scaling")
		_check(is_equal_approx(font.get_string_size("11:11", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
			font.get_string_size("00:00", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x), "clock digits have stable tabular widths")
	clock_value = {"hour": 23, "minute": 59, "second": 59}
	clock.refresh_clock()
	_check(clock.text == "23:59" and clock._timer.wait_time == 1, "last second schedules next minute")
	clock_value = {"hour": 0, "minute": 0, "second": 0}
	clock.refresh_clock()
	_check(clock.text == "00:00" and clock._timer.wait_time == 60, "midnight uses the observed system clock")
	clock.set_foreground_eligible(false)
	var before := reads
	clock_value = {"hour": 15, "minute": 42, "second": 10}
	clock.refresh_clock()
	_check(reads == before and clock._timer.is_stopped(), "background eligibility stops timer and reads")
	clock.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(reads == before + 1 and clock.text == "15:42" and clock._timer.wait_time == 50, "foreground notification refreshes immediately")
	clock.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(clock._timer.is_stopped(), "focus-out notification stops timer")
	clock.set_foreground_eligible(true)
	for malformed: Variant in [null, [], {"hour": 24, "minute": 0, "second": 0},
		{"hour": 0, "minute": 60, "second": 0}, {"hour": 0, "minute": 0, "second": 60},
		{"hour": 0.0, "minute": 0, "second": 0}, {"hour": 0, "minute": 0},
		{"hour": -1, "minute": 0, "second": 0}]:
		clock_value = malformed
		clock.refresh_clock()
		_check(clock.text == "--:--" and clock._timer.wait_time == 60, "malformed time is unavailable without guessing")
	for locale: String in ["en", "zh-CN", "zh-HK"]:
		clock.set_presentation(locale, 100)
		_check(clock.accessibility_name == CLOCK.NAMES[locale] and clock.accessibility_description == CLOCK.UNAVAILABLE[locale], "unavailable accessibility copy follows locale")
	clock.configure_clock(Callable())
	_check(clock.text == "--:--", "missing time reader fails closed")
	clock.configure_clock(_read_time)
	clock_value = {"hour": 8, "minute": 3, "second": 4}
	clock.refresh_clock()
	_check(clock.text == "08:03" and clock.accessibility_description.is_empty(), "recovery clears stale unavailable description")
	clock.free()
	print("ROUTINE_CLOCK_PASS" if failures == 0 else "ROUTINE_CLOCK_FAIL %d" % failures)
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", message)
