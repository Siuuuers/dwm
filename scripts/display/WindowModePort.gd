class_name WindowModePort
extends RefCounted
## Physical main-window output only. Profile, custody and compensation belong to
## the caller. The Windows backend is verified synchronously, never by a timer.
## Godot 4.6: platform/windows/display_server_windows.cpp uses MoveWindow and
## GetClientRect/ClientToScreen. Other backends need their own completion proof.

const BASELINE := Vector2i(1280, 720)
const WINDOW_SIZES := {"1280x720": BASELINE, "1600x900": Vector2i(1600, 900), "1920x1080": Vector2i(1920, 1080)}
# Leave room for ordinary Windows borders and the title bar. The native readback
# remains authoritative if the platform rejects the requested client size.
const FRAME_ALLOWANCE := Vector2i(32, 64)
const MAIN := DisplayServer.MAIN_WINDOW_ID
const WINDOWED := DisplayServer.WINDOW_MODE_WINDOWED
const BORDERLESS := DisplayServer.WINDOW_FLAG_BORDERLESS
const METHODS := [
	&"get_name", &"get_window_list", &"get_screen_count", &"screen_get_usable_rect",
	&"window_get_mode", &"window_get_flag", &"window_get_current_screen",
	&"window_get_position", &"window_get_size", &"window_set_mode",
	&"window_set_flag", &"window_set_current_screen", &"window_set_position", &"window_set_size",
]
var _platform: Object
var _engine: Object

func _init(platform: Object = null, engine: Object = null) -> void:
	_platform = DisplayServer if platform == null else platform
	_engine = Engine if engine == null else engine

func capture_output() -> Dictionary:
	if not _available(): return _failure(&"window_output_unavailable")
	var snapshot := _read()
	if not _valid_snapshot(snapshot): return _failure(&"window_output_unavailable")
	return _success(snapshot)

func apply_mode(mode: Variant, window_size: Variant = "1280x720") -> Dictionary:
	if not _valid_mode(mode): return _failure(&"invalid_window_mode")
	if not _valid_size(window_size): return _failure(&"invalid_window_size")
	var captured := capture_output()
	if not captured.ok: return captured
	var target: Dictionary = captured.value.duplicate(true)
	var usable: Variant = _platform.screen_get_usable_rect(target.screen)
	if not _valid_rect(usable): return _failure(&"window_output_unavailable")
	target.mode = WINDOWED
	target.borderless = mode == "borderless"
	target.size = usable.size if target.borderless else _fitted_size(window_size, usable.size)
	target.position = usable.position if target.borderless else usable.position + (usable.size - target.size) / 2
	_write(target)
	if _read() != target: return _failure(&"window_output_unproven")
	return _success({"mode": String(mode)})

func output_matches(mode: Variant, window_size: Variant = "1280x720") -> bool:
	if not _valid_mode(mode) or not _valid_size(window_size): return false
	var captured := capture_output()
	if not captured.ok: return false
	var actual: Dictionary = captured.value
	if actual.mode != WINDOWED or actual.borderless != (mode == "borderless"): return false
	var usable: Variant = _platform.screen_get_usable_rect(actual.screen)
	if not _valid_rect(usable): return false
	if mode == "windowed": return actual.size == _fitted_size(window_size, usable.size)
	return actual.position == usable.position and actual.size == usable.size

func get_available_window_sizes() -> Array[String]:
	var sizes: Array[String] = []
	var captured := capture_output()
	if not captured.ok: return sizes
	var usable: Variant = _platform.screen_get_usable_rect(captured.value.screen)
	if not _valid_rect(usable): return sizes
	for id: String in WINDOW_SIZES:
		if _fitted_size(id, usable.size) == WINDOW_SIZES[id]: sizes.append(id)
	return sizes

func _fitted_size(id: String, usable: Vector2i) -> Vector2i:
	# A saved preference may be reopened on a smaller monitor. Fit safely without
	# rewriting that preference; it remains available on the original monitor.
	var desired: Vector2i = WINDOW_SIZES[id]
	var available := Vector2i(maxi(1, usable.x - FRAME_ALLOWANCE.x), maxi(1, usable.y - FRAME_ALLOWANCE.y))
	var factor := minf(1.0, minf(float(available.x) / desired.x, float(available.y) / desired.y))
	return Vector2i(maxi(1, floori(desired.x * factor)), maxi(1, floori(desired.y * factor)))

func _valid_size(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and WINDOW_SIZES.has(value)

func restore_output(snapshot: Variant) -> Dictionary:
	if not _available(): return _failure(&"window_output_unavailable")
	if not _valid_snapshot(snapshot): return _failure(&"invalid_window_output_snapshot")
	_write(snapshot)
	if _read() != snapshot: return _failure(&"window_output_restore_unproven")
	return _success({"restored": true})

func _read() -> Dictionary:
	return {"owner_id": get_instance_id(), "mode": _platform.window_get_mode(MAIN),
		"borderless": _platform.window_get_flag(BORDERLESS, MAIN),
		"screen": _platform.window_get_current_screen(MAIN),
		"position": _platform.window_get_position(MAIN), "size": _platform.window_get_size(MAIN)}

func _write(target: Dictionary) -> void:
	# Geometry setters are ignored in maximized/fullscreen mode. Restore that mode
	# last; never overwrite unrelated flags (topmost, resizability, transparency).
	_platform.window_set_mode(WINDOWED, MAIN)
	_platform.window_set_flag(BORDERLESS, target.borderless, MAIN)
	_platform.window_set_current_screen(target.screen, MAIN)
	_platform.window_set_size(target.size, MAIN)
	_platform.window_set_position(target.position, MAIN)
	if target.mode != WINDOWED: _platform.window_set_mode(target.mode, MAIN)

func _available() -> bool:
	# Godot owns the embedded window; native setters are ignored and cannot be proved.
	if _engine.is_embedded_in_editor(): return false
	if not is_instance_valid(_platform): return false
	for method: StringName in METHODS:
		if not _platform.has_method(method): return false
	# Headless returns dummy window values; Wayland does not support positioning.
	# No other backend is claimed until its completion/rollback is verified.
	return _platform.get_name() == "Windows" and MAIN in _platform.get_window_list() \
		and _platform.get_screen_count() > 0

func _valid_snapshot(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != 6: return false
	for key: String in ["owner_id", "mode", "borderless", "screen", "position", "size"]:
		if not value.has(key): return false
	return typeof(value.owner_id) == TYPE_INT and value.owner_id == get_instance_id() \
		and typeof(value.mode) == TYPE_INT and value.mode >= WINDOWED \
		and value.mode <= DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN \
		and typeof(value.borderless) == TYPE_BOOL \
		and typeof(value.screen) == TYPE_INT and value.screen >= 0 \
		and value.screen < _platform.get_screen_count() \
		and typeof(value.position) == TYPE_VECTOR2I and typeof(value.size) == TYPE_VECTOR2I \
		and value.size.x > 0 and value.size.y > 0

func _valid_mode(value: Variant) -> bool:
	return typeof(value) in [TYPE_STRING, TYPE_STRING_NAME] and value in ["windowed", "borderless"]

func _valid_rect(value: Variant) -> bool:
	return typeof(value) == TYPE_RECT2I and value.size.x > 0 and value.size.y > 0

func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}

func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
