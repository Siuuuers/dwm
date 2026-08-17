extends "res://addons/gut/test.gd"

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")

class FakeEvictionPort extends RefCounted:
	var raw_result: Dictionary = {"ok": true, "code": &"ok"}
	func dispatch_desktop_eviction(_command: Dictionary) -> Dictionary:
		return raw_result

func _build(cached_apps: Array, port: Object = null) -> Array:
	var bootstrap: Node = BOOTSTRAP.new()
	var gate: RefCounted = GATE.new()
	var host: RefCounted = HOST.new()
	host.reset(1)
	for app_id in cached_apps:
		host.open_app(StringName(app_id), 1)
	bootstrap._application_gate = gate
	bootstrap._desktop_host_state = host
	bootstrap._desktop_eviction_port = port
	return [bootstrap, gate, host]

func _nonprimitive_details(kind: String) -> Dictionary:
	match kind:
		"collision":
			var d := {}
			d["1"] = "a"
			d[1] = "b"
			return d
		"nonfinite":
			return {"v": INF}
		"object":
			return {"o": Object.new()}
		"callable":
			return {"c": Callable(self, "_noop")}
		"packed_bytes":
			return {"b": PackedByteArray([1, 2, 3])}
	return {}

func _noop() -> void:
	pass

func test_host_change_day_eviction_command_shape() -> void:
	var host: RefCounted = HOST.new()
	host.reset(1)
	host.open_app(&"minesweeper", 1)
	host.open_app(&"contacts", 1)
	var changed: Dictionary = host.change_day(2)
	assert_true(changed.get("ok", false), JSON.stringify(changed))
	var command: Dictionary = changed["value"]["eviction_command"]
	assert_eq(command["command_id"], "desktop-day:2")
	assert_eq(command["kind"], &"evict_cached_apps")
	assert_eq(int(command["day"]), 2)
	assert_eq(command["app_ids"], [&"minesweeper", &"contacts"])

func test_missing_eviction_port_latches_application_fatal() -> void:
	var built := _build([&"minesweeper"], null)
	var bootstrap: Node = built[0]
	var gate: RefCounted = built[1]
	bootstrap._on_day_changed(2)
	assert_true(gate.is_fatal_latched(), "missing port latches the fatal fence")
	assert_eq(gate.guard_external(&"desktop_day_change_dispatch")["code"], &"APPLICATION_FATAL")
	built[0].free()

func test_successful_dispatch_does_not_latch() -> void:
	var port := FakeEvictionPort.new()
	port.raw_result = {"ok": true, "code": &"evicted"}
	var built := _build([&"minesweeper"], port)
	var bootstrap: Node = built[0]
	var gate: RefCounted = built[1]
	bootstrap._on_day_changed(2)
	assert_false(gate.is_fatal_latched(), "a successful dispatch does not latch")
	assert_eq(port.raw_result["code"], &"evicted")
	built[0].free()

func test_nonprimitive_dispatch_failures_project_then_latch_application_fatal() -> void:
	for kind in ["collision", "nonfinite", "object", "callable", "packed_bytes"]:
		var port := FakeEvictionPort.new()
		port.raw_result = {"ok": false, "code": &"dispatch_failed", "message": "boom",
			"details": _nonprimitive_details(kind)}
		var built := _build([&"minesweeper", &"contacts"], port)
		var bootstrap: Node = built[0]
		var gate: RefCounted = built[1]
		bootstrap._on_day_changed(2)
		assert_true(gate.is_fatal_latched(), "non-primitive %s latches the fatal fence" % kind)
		var retained: Dictionary = gate._fatal_failure
		assert_eq(retained["code"], "DESKTOP_EVICTION_DISPATCH_FAILED",
			"retained failure carries the dispatch code for %s" % kind)
		# The latched failure must still be a valid primitive fatal (no rejected data leaked).
		assert_true(PROJECTOR.validate_failure(retained).get("ok", false),
			"retained failure is primitive-valid for %s" % kind)
		assert_eq(gate.guard_external(&"desktop_day_change_dispatch")["code"], &"APPLICATION_FATAL")
		built[0].free()
