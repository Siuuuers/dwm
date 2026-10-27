extends GutTest
## Host routing contract; production save/restart is covered by the cloud journey.
const SCENE := preload("res://scenes/narrative/SceneHost.tscn")

class Actions extends RefCounted:
	var calls: Array[String] = []
	var allow := true
	func dispatch(action: String) -> Dictionary:
		calls.append(action)
		return {"ok": allow}

var _host: Control
var _actions: Actions

func before_each() -> void:
	_actions = Actions.new()
	_host = SCENE.instantiate()
	var actions := {}
	for action: String in ["computer_open", "computer_close", "apps", "contacts"]:
		actions[action] = _actions.dispatch.bind(action)
	_host.configure_scene_controls(actions)
	add_child_autofree(_host)

func test_open_close_only_changes_view_after_admitted_callback() -> void:
	assert_false(_host.is_computer_open())
	assert_false(_host.get_challenge_mount().visible)
	_host.get_node("SceneControlsLayer/Surface/Controls/CheckComputer").pressed.emit()
	assert_eq(_actions.calls, ["computer_open"])
	assert_true(_host.is_computer_open())
	assert_true(_host.get_challenge_mount().visible)
	assert_false(get_tree().paused, "Computer UI never pauses the scene tree or board.")
	_actions.allow = false
	_host.get_node("SceneControlsLayer/Surface/Controls/CheckComputer").pressed.emit()
	assert_true(_host.is_computer_open(), "Refused close retains the admitted view.")
	_actions.allow = true
	_host.get_node("SceneControlsLayer/Surface/Controls/CheckComputer").pressed.emit()
	assert_false(_host.is_computer_open())
	assert_eq(_actions.calls, ["computer_open", "computer_close", "computer_close"])

func test_refused_open_does_not_display_an_unadmitted_panel() -> void:
	_actions.allow = false
	_host.get_node("SceneControlsLayer/Surface/Controls/CheckComputer").pressed.emit()
	assert_false(_host.is_computer_open())
	assert_false(_host.get_challenge_mount().visible)

func test_computer_apps_remain_and_duplicate_scene_commands_are_removed() -> void:
	for name: String in ["Settings", "Backup", "Save", "Load"]:
		assert_false(_host.has_node("SceneControlsLayer/Surface/Controls/" + name))
	for action: String in ["apps", "contacts"]:
		_host.get_node("SceneControlsLayer/Surface/Controls/" + action.capitalize()).pressed.emit()
	assert_eq(_actions.calls, ["apps", "contacts"])
	assert_null(_host.find_child("Pause", true, false))
	assert_null(_host.find_child("Start", true, false))
	assert_false(_host.is_computer_open())
	assert_false(get_tree().paused)


func test_caret_is_above_save_and_outside_computer_and_challenge() -> void:
	var caret: Button = _host.get_node("SceneControlsLayer/Surface/Controls/CheckComputer")
	assert_eq(caret.get_rect(), Rect2(287, 592, 64, 64))
	assert_eq(caret.text, "^")
	assert_false(caret.get_global_rect().intersects(_host.get_challenge_mount().get_global_rect()))
	assert_false(caret.get_global_rect().intersects(_host.get_computer_mount().get_global_rect()))
	var board := Control.new()
	board.size = Vector2(960, 656)
	_host.get_challenge_mount().add_child(board)
	assert_eq(board.scale, Vector2.ONE * (928.0 / 960.0))
