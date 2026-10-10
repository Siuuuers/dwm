extends GutTest

const PORT := preload("res://scripts/display/WindowModePort.gd")

## Explicit platform double: no test in this suite moves the runner's OS window.
class Platform extends RefCounted:
	var backend := "Windows"
	var windows := PackedInt32Array([0])
	var screens := [Rect2i(0, 0, 1920, 1040), Rect2i(-1600, 40, 1600, 860)]
	var mode: int = DisplayServer.WINDOW_MODE_MAXIMIZED
	var flags := {DisplayServer.WINDOW_FLAG_BORDERLESS: false,
		DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP: true, DisplayServer.WINDOW_FLAG_RESIZE_DISABLED: true}
	var screen := 1
	var position := Vector2i(-1400, 110)
	var size := Vector2i(1100, 700)
	var operations: Array = []
	var ignore_size := false
	var ignore_mode := false
	func get_name() -> String: return backend
	func get_window_list() -> PackedInt32Array: return windows
	func get_screen_count() -> int: return screens.size()
	func screen_get_usable_rect(index: int) -> Variant: return screens[index]
	func window_get_mode(_window: int) -> int: return mode
	func window_get_flag(flag: int, _window: int) -> bool: return flags.get(flag, false)
	func window_get_current_screen(_window: int) -> int: return screen
	func window_get_position(_window: int) -> Vector2i: return position
	func window_get_size(_window: int) -> Vector2i: return size
	func window_set_mode(value: int, window: int) -> void:
		operations.append(["mode", value, window])
		if not ignore_mode: mode = value
	func window_set_flag(flag: int, value: bool, window: int) -> void:
		operations.append(["flag", flag, value, window])
		flags[flag] = value
	func window_set_current_screen(value: int, window: int) -> void:
		operations.append(["screen", value, window])
		screen = value
	func window_set_size(value: Vector2i, window: int) -> void:
		operations.append(["size", value, window])
		if not ignore_size and mode == DisplayServer.WINDOW_MODE_WINDOWED: size = value
	func window_set_position(value: Vector2i, window: int) -> void:
		operations.append(["position", value, window])
		if mode == DisplayServer.WINDOW_MODE_WINDOWED: position = value

func test_capture_is_actual_detached_and_main_window_only() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	var captured: Dictionary = port.capture_output()
	assert_true(captured.ok)
	assert_eq(captured.value.size(), 6)
	assert_eq(captured.value.mode, DisplayServer.WINDOW_MODE_MAXIMIZED)
	assert_eq(captured.value.screen, 1)
	assert_eq(captured.value.position, Vector2i(-1400, 110))
	assert_eq(captured.value.size, Vector2i(1100, 700))
	captured.value.position = Vector2i.ZERO
	assert_eq(platform.position, Vector2i(-1400, 110))
	assert_true(platform.operations.is_empty())

func test_borderless_uses_current_screen_usable_bounds_and_preserves_foreign_flags() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	assert_true(port.apply_mode("borderless").ok)
	assert_eq(platform.mode, DisplayServer.WINDOW_MODE_WINDOWED)
	assert_true(platform.flags[DisplayServer.WINDOW_FLAG_BORDERLESS])
	assert_eq(platform.position, Vector2i(-1600, 40))
	assert_eq(platform.size, Vector2i(1600, 860))
	assert_eq(platform.screen, 1)
	assert_true(port.output_matches("borderless"))
	assert_false(port.output_matches("windowed"))
	assert_true(platform.flags[DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP])
	assert_true(platform.flags[DisplayServer.WINDOW_FLAG_RESIZE_DISABLED])
	for operation: Array in platform.operations:
		assert_eq(operation.back(), DisplayServer.MAIN_WINDOW_ID)
		if operation[0] == "flag": assert_eq(operation[1], DisplayServer.WINDOW_FLAG_BORDERLESS)

func test_windowed_uses_baseline_without_fullscreen_and_readback_detects_external_drift() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	assert_true(port.apply_mode(&"windowed").ok)
	assert_eq(platform.size, Vector2i(1280, 720))
	assert_eq(platform.position, Vector2i(-1440, 110))
	assert_false(platform.flags[DisplayServer.WINDOW_FLAG_BORDERLESS])
	assert_true(port.output_matches("windowed"))
	platform.size.x += 1
	assert_false(port.output_matches("windowed"))
	assert_eq(port.capture_output().value.size.x, 1281)

func test_restore_proves_exact_prior_mode_screen_position_size_and_borderless() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	var captured: Dictionary = port.capture_output().value
	assert_true(port.apply_mode("borderless").ok)
	platform.screen = 0
	assert_true(port.restore_output(captured).ok)
	assert_eq(port.capture_output().value, captured)
	assert_eq(platform.operations.back(), ["mode", DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.MAIN_WINDOW_ID])
	assert_true(platform.flags[DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP])
	assert_true(platform.flags[DisplayServer.WINDOW_FLAG_RESIZE_DISABLED])

func test_invalid_modes_and_capsules_refuse_before_mutation() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	var snapshot: Dictionary = port.capture_output().value
	for mode: Variant in ["fullscreen", "Windowed", " windowed", 0, null]:
		assert_eq(port.apply_mode(mode).code, &"invalid_window_mode")
		assert_false(port.output_matches(mode))
	var malformed: Array = [null, {}, PORT.new(platform).capture_output().value]
	for field: String in ["owner_id", "mode", "borderless", "screen", "position", "size"]:
		var candidate := snapshot.duplicate(true)
		candidate[field] = "wrong"
		malformed.append(candidate)
	for delta: Dictionary in [{"mode": 5}, {"screen": 2}, {"size": Vector2i.ZERO}, {"extra": true}]:
		var candidate := snapshot.duplicate(true)
		candidate.merge(delta, true)
		malformed.append(candidate)
	for candidate: Variant in malformed:
		assert_eq(port.restore_output(candidate).code, &"invalid_window_output_snapshot")
	assert_true(platform.operations.is_empty())
	assert_eq(port.capture_output().value, snapshot)

func test_headless_unsupported_missing_window_and_bad_screen_bounds_refuse() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	for backend: String in ["headless", "Wayland", "X11"]:
		platform.backend = backend
		assert_false(port.capture_output().ok)
		assert_false(port.apply_mode("borderless").ok)
		assert_false(port.output_matches("windowed"))
	platform.backend = "Windows"
	platform.windows.clear()
	assert_false(port.capture_output().ok)
	platform.windows.append(0)
	platform.screens[1] = Rect2i()
	assert_false(port.apply_mode("borderless").ok)
	assert_true(platform.operations.is_empty())

func test_silent_setter_failure_cannot_claim_apply_or_restoration_success() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	var snapshot: Dictionary = port.capture_output().value
	platform.ignore_size = true
	assert_eq(port.apply_mode("borderless").code, &"window_output_unproven")
	assert_false(port.output_matches("borderless"))
	platform.ignore_size = false
	assert_true(port.apply_mode("borderless").ok)
	platform.ignore_mode = true
	assert_eq(port.restore_output(snapshot).code, &"window_output_restore_unproven")
	platform.ignore_mode = false
	assert_true(port.restore_output(snapshot).ok)
	assert_eq(port.capture_output().value, snapshot)


class EmbeddedEngine extends RefCounted:
	func is_embedded_in_editor() -> bool: return true

func test_editor_embedding_never_attempts_to_control_the_host_window() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform, EmbeddedEngine.new())
	assert_eq(port.capture_output().code, &"window_output_unavailable")
	assert_eq(port.apply_mode("windowed").code, &"window_output_unavailable")
	assert_eq(port.apply_mode("borderless").code, &"window_output_unavailable")
	assert_false(port.output_matches("windowed"))
	assert_true(platform.operations.is_empty(), "the editor owns embedded-window geometry")

func test_window_size_presets_follow_current_monitor_and_leave_frame_space() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	assert_eq(port.get_available_window_sizes(), ["1280x720"])
	platform.screen = 0
	assert_eq(port.get_available_window_sizes(), ["1280x720", "1600x900"])
	assert_true(port.apply_mode("windowed", "1600x900").ok)
	assert_eq(platform.size, Vector2i(1600, 900))
	assert_eq(platform.position, Vector2i(160, 70))
	assert_true(port.output_matches("windowed", "1600x900"))
	assert_false(port.output_matches("windowed", "1280x720"))

func test_saved_large_window_fits_a_smaller_monitor_without_clipping() -> void:
	var platform := Platform.new()
	platform.screens[1] = Rect2i(-1366, 0, 1366, 728)
	var port := PORT.new(platform)
	assert_true(port.get_available_window_sizes().is_empty())
	assert_true(port.apply_mode("windowed", "1920x1080").ok)
	assert_lte(platform.size.x, 1366 - PORT.FRAME_ALLOWANCE.x)
	assert_lte(platform.size.y, 728 - PORT.FRAME_ALLOWANCE.y)
	assert_true(port.output_matches("windowed", "1920x1080"))
	assert_true(platform.screens[1].encloses(Rect2i(platform.position, platform.size)))

func test_invalid_window_sizes_never_reach_native_setters() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	for value: Variant in ["", "4096x2160", "1280X720", Vector2i(1280, 720), null]:
		assert_eq(port.apply_mode("windowed", value).code, &"invalid_window_size")
		assert_false(port.output_matches("windowed", value))
	assert_true(platform.operations.is_empty())

func test_borderless_ignores_window_size_and_keeps_native_usable_bounds() -> void:
	var platform := Platform.new()
	var port := PORT.new(platform)
	assert_true(port.apply_mode("borderless", "1920x1080").ok)
	assert_eq(platform.size, platform.screens[1].size)
	assert_eq(platform.position, platform.screens[1].position)
	assert_true(port.output_matches("borderless", "1920x1080"))
