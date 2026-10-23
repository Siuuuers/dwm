class_name FakeDesktopEvictionPort
extends RefCounted

# Test double for the desktop eviction port consumed by ApplicationBootstrap's
# day-change owner. Records dispatch count and the last command for assertions.

var _calls := {"dispatch_desktop_eviction": 0}
var _failures := {}
var _last_command := {}


func reset_call_counts() -> void:
	_calls = {"dispatch_desktop_eviction": 0}


func get_call_counts() -> Dictionary:
	return _calls.duplicate()


func set_failure(method: StringName, remaining_failures: int = 1) -> void:
	_failures[method] = remaining_failures


func dispatch_desktop_eviction(command: Dictionary) -> Dictionary:
	_calls.dispatch_desktop_eviction += 1
	_last_command = command.duplicate(true)
	if _failures.has(&"dispatch_desktop_eviction") and _failures[&"dispatch_desktop_eviction"] > 0:
		_failures[&"dispatch_desktop_eviction"] -= 1
		return {"ok": false, "code": &"eviction_dispatch_failed", "details": {}}
	return {"ok": true, "code": &"ok", "value": {"dispatched": true}}
