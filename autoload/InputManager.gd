extends Node
# InputManager (CONTRACTS §7): owns input actions, controller mappings, focus helpers,
# and safe rebinds. Does not hardcode keyboard-only logic in UI. Every gameplay button
# must be keyboard/controller focusable.

signal input_scheme_changed(scheme: String)
signal controller_connected(device_id: int)
signal controller_disconnected(device_id: int)
signal input_bindings_changed()
signal source_input_custody_changed()

const ACTION_REGISTRY := preload("res://scripts/settings/ControlsActionRegistry.gd")
# These names are no longer active shortcuts. Stored legacy records stay in the
# profile as provenance; their installed events must not survive the cutover.
const _RETIRED_GAME_ACTIONS := [
	"game_open_log", "game_skip_text", "game_toggle_auto", "game_hint",
	"game_close_window", "game_next_tab", "game_prev_tab", "game_page_next",
	"game_page_prev", "game_open_settings", "game_open_schedule", "game_open_contacts",
]

const _REQUIRED_UI_ACTIONS := [
	"ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right",
	"ui_focus_next", "ui_focus_prev",
]

var _current_scheme: String = "keyboard"
var _profile: Node
var _mutation_gate: Object
var _suspension_handle: Dictionary = {}
var _physical_contacts: Dictionary = {}
var _contact_generation := 0
var _resume_quarantine: Dictionary = {}
var _resume_frame := -1


func _enter_tree() -> void:
	# Observe releases during Pause without consuming input from its ALWAYS UI.
	process_mode = Node.PROCESS_MODE_ALWAYS


func begin_suspend(handle: Variant) -> Dictionary:
	if not _valid_suspension_handle(handle):
		return _input_lifecycle_failure(&"invalid_suspension_handle")
	if not _suspension_handle.is_empty() and _suspension_handle != handle:
		return _input_lifecycle_failure(&"input_already_suspended")
	if _suspension_handle.is_empty():
		_suspension_handle = handle.duplicate(true)
		source_input_custody_changed.emit()
	return {"ok": true, "code": &"ok", "value": {"frontier_id": "input:%s" % handle.handle_id}}


func resume(handle: Variant) -> Dictionary:
	if not _valid_suspension_handle(handle) or _suspension_handle.is_empty() or _suspension_handle != handle:
		return _input_lifecycle_failure(&"invalid_suspension_handle")
	_suspension_handle.clear()
	_resume_quarantine = _physical_contacts.duplicate()
	_resume_frame = Engine.get_process_frames()
	source_input_custody_changed.emit()
	return {"ok": true, "code": &"ok", "value": {"resumed": true}}


func get_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"state": &"Active" if _suspension_handle.is_empty() else &"Suspended"}}


func is_source_input_admitted() -> bool:
	return _suspension_handle.is_empty() and _resume_quarantine.is_empty() \
		and Engine.get_process_frames() != _resume_frame


## Contact identity is independent of action mappings. Callers receive no mutable
## ownership of the ledger, and a released contact never reuses its generation.
func get_physical_contacts() -> Dictionary:
	return _physical_contacts.duplicate()


func get_physical_contact_id(event: InputEvent) -> String:
	if event == null or event.device == InputEvent.DEVICE_ID_EMULATION:
		return ""
	return _physical_contact(event)


func _input(event: InputEvent) -> void:
	observe_physical_contact(event)


## Embedded input windows forward here before consuming their packets. A parent
## delivery of the same press/release is harmless and does not create a new edge.
func observe_physical_contact(event: InputEvent) -> void:
	var contact := get_physical_contact_id(event)
	if contact.is_empty():
		return
	if event.is_pressed():
		if not _physical_contacts.has(contact):
			# An echo without its original press is not a fresh activation.
			if event is InputEventKey and event.echo: return
			_contact_generation += 1
			_physical_contacts[contact] = _contact_generation
	else:
		_physical_contacts.erase(contact)
		_resume_quarantine.erase(contact)


func _physical_contact(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%s:%s" % [event.device, event.physical_keycode if event.physical_keycode else event.keycode]
	if event is InputEventMouseButton:
		# Wheel packets are impulses and do not provide a held release frontier.
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return ""
		return "mouse:%s:%s" % [event.device, event.button_index]
	if event is InputEventScreenTouch:
		return "touch:%s:%s" % [event.device, event.index]
	if event is InputEventJoypadButton:
		return "joy:%s:%s" % [event.device, event.button_index]
	if event is InputEventAction:
		return "action:%s:%s" % [event.device, event.action]
	return ""


func _valid_suspension_handle(handle: Variant) -> bool:
	return typeof(handle) == TYPE_DICTIONARY and handle.size() == 4 \
		and typeof(handle.get("generation")) == TYPE_INT and handle.generation > 0 \
		and typeof(handle.get("handle_id")) == TYPE_STRING and not handle.handle_id.is_empty() \
		and typeof(handle.get("holder")) == TYPE_STRING_NAME and handle.holder != &"" \
		and typeof(handle.get("reason")) == TYPE_STRING_NAME and handle.reason == &"universal_pause"


func _input_lifecycle_failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "value": null}


func _ready() -> void:
	pass

func configure_mutation_gate(gate: Object) -> Dictionary:
	return _configure_gate(gate)

func initialize(profile: Node) -> Dictionary:
	if profile == null or not profile.has_method("get_input_mappings") or not profile.has_method("set_input_mapping"):
		return {"ok": false, "code": &"invalid_profile_manager"}
	_profile = profile
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_default_input_map()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed): Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if profile.has_signal("controls_bindings_changed"):
		if not profile.controls_bindings_changed.is_connected(apply_profile_mappings): profile.controls_bindings_changed.connect(apply_profile_mappings)
	elif not profile.input_mappings_changed.is_connected(apply_profile_mappings):
		profile.input_mappings_changed.connect(apply_profile_mappings)
	if profile.has_signal("profile_restored") and not profile.profile_restored.is_connected(_on_profile_restored):
		profile.profile_restored.connect(_on_profile_restored)
	apply_profile_mappings()
	return {"ok": true}

func apply_profile_mappings(_action_id: StringName = &"") -> Dictionary:
	if _profile == null: return {"ok": false, "code": &"not_initialized"}
	var mappings: Dictionary = _profile.get_input_mappings()
	# A profile publication may change several actions. Apply the complete committed
	# map before notifying listeners, even when reached through a per-action signal.
	var actions: Array = _game_action_ids()
	for action_value in actions:
		var action := String(action_value)
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for record: Dictionary in mappings.get(action, []):
			var event: InputEvent
			if record["kind"] == "key":
				var key_event := InputEventKey.new()
				key_event.physical_keycode = record["physical_keycode"]
				key_event.keycode = record["keycode"]
				key_event.shift_pressed = record["shift"]
				key_event.alt_pressed = record["alt"]
				key_event.ctrl_pressed = record["ctrl"]
				key_event.meta_pressed = record["meta"]
				event = key_event
			else:
				var joy_event := InputEventJoypadButton.new()
				joy_event.button_index = record["button_index"]
				joy_event.device = record["device"]
				event = joy_event
			InputMap.action_add_event(action, event)
	emit_signal("input_bindings_changed")
	return {"ok": true}


func _on_profile_restored(_snapshot: Dictionary) -> void:
	apply_profile_mappings()


func _game_action_ids() -> Array:
	var actions: Array = []
	for record in ACTION_REGISTRY.records(): actions.append(String(record.id))
	return actions


func ensure_default_input_map() -> void:
	# Ensure ui_* exist (Godot usually provides them; add empty ones if missing so lookups are safe).
	for action in _REQUIRED_UI_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	for action in _RETIRED_GAME_ACTIONS:
		if InputMap.has_action(action): InputMap.erase_action(action)
	# Only create the canonical actions. The profile publishes their complete
	# bindings, or none while import resolution is pending.
	for action in _game_action_ids():
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func get_current_input_scheme() -> String:
	return _current_scheme


func set_current_input_scheme(scheme: String) -> void:
	if scheme != _current_scheme:
		_current_scheme = scheme
		emit_signal("input_scheme_changed", scheme)


func is_controller_connected() -> bool:
	return Input.get_connected_joypads().size() > 0


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		emit_signal("controller_connected", device_id)
	else:
		var prefix := "joy:%s:" % device_id
		for contact: String in _physical_contacts.keys():
			if contact.begins_with(prefix): _physical_contacts.erase(contact)
		for contact: String in _resume_quarantine.keys():
			if contact.begins_with(prefix): _resume_quarantine.erase(contact)
		emit_signal("controller_disconnected", device_id)


func get_action_label(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return ""
	var events := InputMap.action_get_events(action_name)
	for ev in events:
		if ev is InputEventKey:
			var code: int = (ev as InputEventKey).physical_keycode
			if code == 0:
				code = (ev as InputEventKey).keycode
			return OS.get_keycode_string(code)
		if ev is InputEventJoypadButton:
			return "Joy %d" % (ev as InputEventJoypadButton).button_index
	return ""


func rebind_action(action_name: String, event: InputEvent) -> Dictionary:
	if not InputMap.has_action(action_name):
		return {"ok": false, "reason": "unknown_action", "action": action_name}
	if event == null:
		return {"ok": false, "reason": "null_event", "action": action_name}
	if _profile == null: return {"ok": false, "reason": "not_initialized", "action": action_name}
	var mappings: Dictionary = _profile.get_input_mappings()
	if not mappings.has(action_name):
		return {"ok": false, "reason": "unregistered_action", "action": action_name}
	var record: Dictionary
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == 0 and key_event.keycode == 0:
			return {"ok": false, "reason": "empty_key", "action": action_name}
		record = {"kind": "key", "physical_keycode": key_event.physical_keycode, "keycode": key_event.keycode, "shift": key_event.shift_pressed, "alt": key_event.alt_pressed, "ctrl": key_event.ctrl_pressed, "meta": key_event.meta_pressed}
	elif event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		if joy_event.button_index < 0 or joy_event.button_index >= JOY_BUTTON_SDL_MAX:
			return {"ok": false, "reason": "invalid_button", "action": action_name}
		# Bind a controller position, not the transient device that supplied it.
		record = {"kind": "joypad_button", "button_index": joy_event.button_index, "device": -1}
	else: return {"ok": false, "reason": "unsupported_event", "action": action_name}
	# ProfileManager preserves the other slot, checks the complete canonical map,
	# and publishes only after commit. A conflict requires an explicit Swap path.
	var events: Array[Dictionary] = [record]
	return _profile.set_input_mapping(StringName(action_name), events)


func reset_bindings_to_default() -> Dictionary:
	return {"ok": false, "code": &"controls_reset_confirmation_required"}


# ---- Focus helpers ----
func focus_first_control(root: Node) -> bool:
	var target := _find_first_focusable(root)
	if target != null:
		target.grab_focus()
		return true
	return false


func _find_first_focusable(node: Node) -> Control:
	if node == null:
		return null
	if node is Control:
		var c := node as Control
		if c.focus_mode == Control.FOCUS_ALL and c.visible and not _is_disabled(c):
			return c
	for child in node.get_children():
		var found := _find_first_focusable(child)
		if found != null:
			return found
	return null


func _is_disabled(control: Control) -> bool:
	if control is BaseButton:
		return (control as BaseButton).disabled
	return false


func make_button_focusable(button: BaseButton) -> void:
	if button != null:
		button.focus_mode = Control.FOCUS_ALL


func apply_focus_to_tree(root: Node) -> void:
	if root == null:
		return
	if root is BaseButton:
		(root as BaseButton).focus_mode = Control.FOCUS_ALL
	for child in root.get_children():
		apply_focus_to_tree(child)

func _configure_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id(): return {"ok": false, "code": &"mutation_gate_already_configured", "details": {}, "receipt": {}}
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}
