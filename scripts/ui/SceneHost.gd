extends Control
## Scene chrome only. Bootstrap owns admission, persistence, and panel mounting.

var _actions: Dictionary = {}
var _computer_open := false
var _busy := false

func _ready() -> void:
	$SceneControlsLayer/Surface/Controls/CheckComputer.pressed.connect(_toggle_computer)
	for action: String in ["settings", "backup", "save", "load"]:
		get_node("SceneControlsLayer/Surface/Controls/" + action.capitalize()).pressed.connect(_invoke.bind(action))
	if _actions.is_empty():
		var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
		if bootstrap != null and bootstrap.has_method("configure_scene_host_view"):
			bootstrap.configure_scene_host_view(self)
	_update_controls()

func configure_scene_controls(actions: Dictionary) -> void:
	_actions = actions.duplicate()
	if is_node_ready(): _update_controls()

func get_challenge_mount() -> Control:
	return $SceneControlsLayer/Surface/ChallengeMount

func is_computer_open() -> bool:
	return _computer_open

func set_computer_open(open: bool) -> void:
	_computer_open = open
	$SceneControlsLayer/Surface/ChallengeMount.visible = open
	$SceneControlsLayer/Surface/Controls/CheckComputer.text = "Close Computer" if open else "Check Computer"
	_update_controls()

func _toggle_computer() -> void:
	# Consume before awaiting: closing must not forward this click into dialogue.
	get_viewport().set_input_as_handled()
	if _busy: return
	var opening := not _computer_open
	var action := "computer_open" if opening else "computer_close"
	var callback: Callable = _actions.get(action, Callable())
	if not callback.is_valid(): return
	_busy = true
	_update_controls()
	var result: Variant = await callback.call()
	if not is_inside_tree(): return
	if result is Dictionary and result.get("ok", false):
		set_computer_open(opening)
	_busy = false
	_update_controls()

func _invoke(action: String) -> void:
	get_viewport().set_input_as_handled()
	if _busy: return
	var callback: Callable = _actions.get(action, Callable())
	if not callback.is_valid(): return
	_busy = true
	_update_controls()
	await callback.call()
	if not is_inside_tree(): return
	_busy = false
	_update_controls()

func _update_controls() -> void:
	if not is_inside_tree(): return
	var computer: Callable = _actions.get("computer_close" if _computer_open else "computer_open", Callable())
	$SceneControlsLayer/Surface/Controls/CheckComputer.disabled = _busy or not computer.is_valid()
	for action: String in ["settings", "backup", "save", "load"]:
		var callback: Callable = _actions.get(action, Callable())
		get_node("SceneControlsLayer/Surface/Controls/" + action.capitalize()).disabled = _busy or not callback.is_valid()
