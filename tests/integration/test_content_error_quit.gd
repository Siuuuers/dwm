extends "res://addons/gut/test.gd"

const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

class ContentErrorBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	func _ready() -> void:
		pass

var _bootstrap: Node
var _previous_pause := false

func before_each() -> void:
	_previous_pause = get_tree().paused
	_bootstrap = ContentErrorBootstrap.new()
	_bootstrap._application_gate = GATE.new()
	get_tree().root.add_child(_bootstrap)

func after_each() -> void:
	get_tree().paused = _previous_pause
	_bootstrap.free()

func test_content_error_keeps_missing_id_visible_and_blocks_saving_until_quit() -> void:
	var underlying := Button.new()
	get_tree().root.add_child(underlying)
	underlying.grab_focus()
	_bootstrap.show_content_error({"ok": false, "code": &"reading_content_error",
		"message": "Missing dialogue ID: line.missing", "details": {"line_id": "line.missing", "cause": "internal_cause"}})
	var confirmation: Control = _bootstrap.get_node("ContentError/ContentErrorConfirmation")
	assert_true(get_tree().paused, "reading and automatic progression stop")
	assert_eq(confirmation.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_true(confirmation.can_process(), "Quit remains interactive while the game is paused")
	assert_true(confirmation.is_visible_in_tree())
	underlying.grab_focus()
	assert_same(get_viewport().gui_get_focus_owner(), confirmation.confirm_button,
		"a late underlying focus restore cannot steal Quit")
	assert_string_contains(confirmation.request.body, "line.missing")
	assert_eq(confirmation.request.body, "Missing dialogue ID: line.missing", "internal diagnostics stay out of player copy")
	assert_eq(confirmation.request.confirm, "Quit")
	assert_false(confirmation.cancel_button.visible)
	assert_eq(_bootstrap._application_gate.guard_external(&"save").code, &"APPLICATION_FATAL")
	assert_eq(_bootstrap._application_gate.acquire(&"causal_transaction").code, &"APPLICATION_FATAL")
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	confirmation._input(escape)
	assert_true(confirmation.is_visible_in_tree(), "Escape cannot dismiss the error")
	assert_false(confirmation.is_queued_for_deletion())
	_bootstrap.show_content_error({"code": &"reading_content_error", "message": "Later failure"})
	assert_same(_bootstrap.get_node("ContentError/ContentErrorConfirmation"), confirmation)
	assert_string_contains(confirmation.request.body, "line.missing", "the original diagnosis remains")
	underlying.free()
	get_tree().paused = _previous_pause
