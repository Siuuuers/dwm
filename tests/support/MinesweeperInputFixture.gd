extends RefCounted
## Isolated canonical bindings for grid tests; native routes keep the input owner
## in the same viewport as the consuming Control.
const PROFILE := preload("res://autoload/ProfileManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
var _map: Dictionary = {}

func _init() -> void:
	for action: StringName in InputMap.get_actions():
		_map[action] = {"deadzone": InputMap.action_get_deadzone(action),
			"events": InputMap.action_get_events(action).duplicate(true)}

func bind_grid(grid: Control, parent: Node) -> bool:
	var profile := PROFILE.new()
	parent.add_child(profile)
	if not profile.initialize(STORAGE.new("minesweeper-input.memory", FILES.new())).ok:
		profile.free()
		return false
	var owner := INPUT.new()
	parent.add_child(owner)
	if not owner.initialize(profile).ok or not grid.configure_input(owner):
		owner.free()
		profile.free()
		return false
	return true

func restore_map() -> void:
	for action: StringName in InputMap.get_actions():
		if not _map.has(action): InputMap.erase_action(action)
	for action: StringName in _map:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _map[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _map[action].events: InputMap.action_add_event(action, event)
	_map.clear()
