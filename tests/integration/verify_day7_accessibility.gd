extends SceneTree
## Native Windows UI Automation probe. The external wrapper owns DWM_TEST_ROOT and invokes Next.

const SURFACE := preload("res://scripts/ui/Day7PreludeSurface.gd")
const EXPECTED_CAPTION := "Next"
const TIMEOUT_MS := 30000

class ReceiptTracker extends RefCounted:
	var acknowledgments: Array[Dictionary] = []
	var navigations: Array[Dictionary] = []

	func acknowledge(receipt: Dictionary) -> Dictionary:
		acknowledgments.append(receipt.duplicate(true))
		return {"ok": true, "code": &"ok"}

	func advance(receipt: Dictionary) -> void:
		navigations.append(receipt.duplicate(true))

var _test_root := ""
var _pid := 0
var _window_title := ""
var _ready_path := ""
var _result_path := ""
var _tracker := ReceiptTracker.new()
var _input_owner: Node
var _surface: Node
var _pressed_signals := 0
var _programmatic_pressed_rejected := false
var _max_physical_contacts := 0
var _ready_frame := -1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _prove_test_root():
		_finish(false, "unproven_test_root")
		return
	for frame: int in 3:
		await process_frame
	var bootstrap: Node = root.get_node_or_null("ApplicationBootstrap")
	var startup: Dictionary = bootstrap.get_startup_state() if bootstrap != null else {}
	if bootstrap == null or startup.get("mode") != &"test_manual":
		_finish(false, "bootstrap_not_in_manual_test_mode")
		return
	if DisplayServer.get_name() == "headless":
		_finish(false, "native_display_required")
		return
	_input_owner = root.get_node_or_null("InputManager")
	if _input_owner == null:
		_finish(false, "input_manager_unavailable")
		return

	_pid = OS.get_process_id()
	_window_title = "DWM Day 7 Accessibility %d" % _pid
	DisplayServer.window_set_title(_window_title)
	root.size = Vector2i(960, 640)
	var receipt := {"entry_id": "echo.fallback.day7", "view_token": "uia-%d" % _pid,
		"echo_id": "echo.fixture.day7.accessibility",
		"presentation_atom_id": "atom.fixture.day7.accessibility"}
	var card := {"title": "Day 7 remembered detail",
		"body": "A rendered, acknowledged, non-final presentation card.", "receipt": receipt}
	_surface = SURFACE.new()
	if not _surface.configure(card, _tracker.acknowledge).get("ok", false) \
			or not _surface.use_presentation_receipts().get("ok", false) \
			or not _surface.bind_input_custody(_input_owner):
		_finish(false, "surface_configuration_failed")
		return
	_surface.advance_requested.connect(_tracker.advance)
	root.add_child(_surface)

	var draw_deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < draw_deadline and not (_surface._drawn and _surface._accepted \
			and _tracker.acknowledgments.size() == 1 and not _surface._next.disabled):
		await process_frame
	if not (_surface._drawn and _surface._accepted and _tracker.acknowledgments == [receipt]):
		_finish(false, "rendered_acknowledgment_missing")
		return

	_surface._next.accessibility_name = EXPECTED_CAPTION
	_surface._next.pressed.connect(_on_pressed)
	_surface._next.pressed.emit()
	await process_frame
	_programmatic_pressed_rejected = _pressed_signals == 1 and _tracker.navigations.is_empty() \
		and _tracker.acknowledgments.size() == 1
	_pressed_signals = 0
	if not _programmatic_pressed_rejected:
		_finish(false, "programmatic_pressed_was_admitted")
		return
	_surface._next.grab_focus()
	_surface._next.queue_accessibility_update()
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_ready_frame = Engine.get_process_frames()
	var ready := _snapshot(true, "awaiting_uia_invoke")
	if not _publish(_ready_path, ready):
		_finish(false, "readiness_write_failed")
		return
	print("READY " + JSON.stringify(ready))

	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	var observed_at := -1
	while Time.get_ticks_msec() < deadline:
		_max_physical_contacts = maxi(_max_physical_contacts,
			(_input_owner.get_physical_contacts() as Dictionary).size())
		if _tracker.navigations.size() > 1 or _tracker.acknowledgments.size() != 1:
			_finish(false, "duplicate_or_mutated_outcome")
			return
		if _tracker.navigations.size() == 1:
			if observed_at < 0: observed_at = Time.get_ticks_msec()
			if Time.get_ticks_msec() - observed_at >= 400:
				var exact := _tracker.navigations[0] == receipt and _max_physical_contacts == 0
				_finish(exact, "ok" if exact else "invalid_native_outcome")
				return
		elif _pressed_signals > 0:
			if observed_at < 0: observed_at = Time.get_ticks_msec()
			if Time.get_ticks_msec() - observed_at >= 400:
				_finish(false, "native_pressed_rejected")
				return
		await process_frame
	_finish(false, "native_invoke_timeout")

func _on_pressed() -> void:
	_pressed_signals += 1

func _prove_test_root() -> bool:
	var candidate := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests").replace("\\", "/").simplify_path().trim_suffix("/")
	if candidate.is_empty() or candidate.nocasecmp_to(allowed) == 0 \
			or not candidate.to_lower().begins_with(allowed.to_lower() + "/") \
			or not DirAccess.dir_exists_absolute(candidate):
		return false
	_test_root = candidate
	_ready_path = candidate.path_join("day7-accessibility-ready.json")
	_result_path = candidate.path_join("day7-accessibility-result.json")
	for path: String in [_ready_path, _result_path, _ready_path + ".tmp", _result_path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	return true

func _snapshot(ok: bool, code: String) -> Dictionary:
	var contacts: Dictionary = _input_owner.get_physical_contacts() if is_instance_valid(_input_owner) else {}
	return {"schema_version": 1, "ok": ok, "code": code, "pid": _pid,
		"window_title": _window_title, "expected_caption": EXPECTED_CAPTION,
		"ready_path": _ready_path, "result_path": _result_path,
		"display_server": DisplayServer.get_name(), "rendered_draw": is_instance_valid(_surface) and _surface._drawn,
		"accepted": is_instance_valid(_surface) and _surface._accepted,
		"programmatic_pressed_rejected": _programmatic_pressed_rejected,
		"acknowledgments": _tracker.acknowledgments.size(), "pressed_signals": _pressed_signals,
		"navigations": _tracker.navigations.size(), "physical_contacts": contacts.size(),
		"max_physical_contacts": _max_physical_contacts, "ready_engine_frame": _ready_frame,
		"engine_frame": Engine.get_process_frames()}

func _publish(path: String, payload: Dictionary) -> bool:
	if path.is_empty(): return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(payload))
	file.close()
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK: return false
	return DirAccess.rename_absolute(temporary, path) == OK

func _finish(ok: bool, code: String) -> void:
	var result := _snapshot(ok, code)
	if not _result_path.is_empty(): _publish(_result_path, result)
	print("RESULT " + JSON.stringify(result))
	quit(0 if ok else 1)
