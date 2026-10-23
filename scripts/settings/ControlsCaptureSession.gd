extends RefCounted
## One transient capture. No InputMap, profile, timer, or gameplay operations.
const REGISTRY := preload("res://scripts/settings/ControlsActionRegistry.gd")

var _active := false
var _action := ""
var _slot := ""
var _held: Dictionary = {}
var _device := -1


func begin(action: String, slot: String, activation: InputEvent = null, held_events: Array[InputEvent] = []) -> Dictionary:
	if _active:
		return _result(&"waiting", &"already_active")
	_action = action
	_slot = slot
	_held.clear()
	_device = -1
	var registered := false
	for record in REGISTRY.records():
		registered = registered or String(record.id) == action
	if not registered:
		return _result(&"cancelled", &"unknown_action")
	if slot not in ["keyboard", "controller"]:
		return _result(&"cancelled", &"invalid_slot")
	_active = true
	for event: InputEvent in held_events:
		_remember_held(event)
	_remember_held(activation)
	if slot == "controller" and activation is InputEventJoypadButton and activation.device >= 0:
		_device = activation.device
	return _result(&"waiting", &"capture_started")


func handle_event(event: InputEvent) -> Dictionary:
	if not _active:
		return _result(&"cancelled", &"inactive")
	if event == null:
		return _result(&"waiting", &"unsupported_event")
	var identity := _identity(event)
	if not identity.is_empty() and _held.has(identity):
		if not _pressed(event):
			_held.erase(identity)
			return _result(&"waiting", &"held_released")
		return _result(&"waiting", &"held_input")
	if event is InputEventKey and event.echo:
		return _result(&"waiting", &"echo_ignored")
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		if not _pressed(event):
			return _result(&"waiting", &"release_ignored")
	if event is InputEventKey:
		if event.physical_keycode == KEY_ESCAPE or (event.physical_keycode == 0 and event.keycode == KEY_ESCAPE):
			return cancel(&"back")
		if _slot != "keyboard":
			return _result(&"waiting", &"other_input_slot")
		var code: int = event.physical_keycode
		if code <= 0 or code & KEY_MODIFIER_MASK != 0 or OS.find_keycode_from_string(OS.get_keycode_string(code)) != code:
			return _result(&"waiting", &"unsupported_key")
		return _capture({"kind": "key", "physical_keycode": code, "keycode": 0,
			"shift": event.shift_pressed, "alt": event.alt_pressed,
			"ctrl": event.ctrl_pressed, "meta": event.meta_pressed})
	if event is InputEventJoypadButton:
		if event.device < 0:
			return _result(&"waiting", &"invalid_capture_device")
		if _device >= 0 and event.device != _device:
			return _result(&"waiting", &"other_controller")
		if event.button_index == JOY_BUTTON_B:
			return cancel(&"back")
		if _slot != "controller":
			return _result(&"waiting", &"other_input_slot")
		_device = event.device
		if event.button_index < 0 or event.button_index >= JOY_BUTTON_SDL_MAX:
			return _result(&"waiting", &"unsupported_button")
		return _capture({"kind": "joypad_button", "button_index": event.button_index, "device": -1})
	return _result(&"waiting", &"unsupported_event")


func cancel(reason: StringName) -> Dictionary:
	if not _active:
		return _result(&"cancelled", &"inactive")
	_active = false
	_held.clear()
	return _result(&"cancelled", reason)


func disconnect_device(device: int) -> Dictionary:
	if not _active:
		return _result(&"cancelled", &"inactive")
	if _slot == "controller" and _device >= 0 and device == _device:
		return cancel(&"capture_device_disconnected")
	return _result(&"waiting", &"other_device")


func is_active() -> bool:
	return _active


func _capture(binding: Dictionary) -> Dictionary:
	_active = false
	_held.clear()
	var result := _result(&"captured", &"ok")
	result["binding"] = binding.duplicate(true)
	return result


func _remember_held(event: InputEvent) -> void:
	if event != null and _pressed(event):
		var identity := _identity(event)
		if not identity.is_empty():
			_held[identity] = true


func _identity(event: InputEvent) -> String:
	if event is InputEventKey:
		if event.physical_keycode != 0:
			return "key:%d" % event.physical_keycode
		if event.keycode != 0:
			return "logical_key:%d" % event.keycode
	elif event is InputEventJoypadButton:
		return "controller:%d:%d" % [event.device, event.button_index]
	elif event is InputEventMouseButton:
		return "mouse:%d:%d" % [event.device, event.button_index]
	return ""


func _pressed(event: InputEvent) -> bool:
	return (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.pressed


func _result(state: StringName, code: StringName) -> Dictionary:
	return {"state": state, "code": code, "action": _action, "slot": _slot}
