extends "res://addons/gut/test.gd"

const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")

class FailedProfile extends RefCounted:
	var writes := 0
	func is_line_visited(_line_id: String) -> bool: return false
	func mark_line_visited(_line_id: String) -> Dictionary:
		writes += 1
		return {"ok": false, "code": &"indeterminate_commit", "fatal": true,
			"message": "Durable transaction evidence cannot prove one winner"}

class VisibleFrontier extends RefCounted:
	func current_line_id() -> String: return "fixture.visible"
	func capture_pause_frontier() -> Dictionary:
		return {"ok": true, "value": {"generation": 1, "paused": false}}

class ContentErrorBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	func _ready() -> void:
		pass

var _bootstrap: Node
var _previous_pause := false
var _original_bootstrap: Node
var _previous_witness_stages: Array
var _previous_line_owners: Dictionary

func before_each() -> void:
	_previous_pause = get_tree().paused
	_previous_witness_stages = BRIDGE._line_witness_stages.duplicate()
	_previous_line_owners = BRIDGE._skip_line_owners.duplicate()
	_bootstrap = ContentErrorBootstrap.new()
	_bootstrap._application_gate = GATE.new()
	get_tree().root.add_child(_bootstrap)

func after_each() -> void:
	get_tree().paused = _previous_pause
	BRIDGE._line_witness_stages = _previous_witness_stages
	BRIDGE._skip_line_owners = _previous_line_owners
	_bootstrap.free()
	if _original_bootstrap != null:
		_original_bootstrap.name = "ApplicationBootstrap"
		_original_bootstrap = null

func test_fatal_caption_acknowledgement_defers_terminal_ui_and_retains_failure() -> void:
	_original_bootstrap = get_node("/root/ApplicationBootstrap")
	_original_bootstrap.name = "OriginalApplicationBootstrap"
	_bootstrap.name = "ApplicationBootstrap"
	var profile := FailedProfile.new()
	var bridge := BRIDGE.new()
	add_child_autofree(bridge)
	bridge._skip_profile = profile
	bridge._runtime_adapter = VisibleFrontier.new()
	bridge._active_entry = {"token": "visible", "stage": "pre_challenge", "entry_id": "fixture.entry"}
	BRIDGE._line_witness_stages = ["pre_challenge"]
	bridge._skip_line_owners = {"fixture.visible": "fixture.entry"}
	var frontier: Dictionary = bridge.capture_current_line_presentation_frontier()
	assert_true(frontier.ok, str(frontier))
	var result: Dictionary = bridge.acknowledge_current_line_presentation(frontier)
	assert_eq(result.code, &"indeterminate_commit")
	assert_eq(bridge._progression_phase, bridge.ProgressionPhase.IDLE)
	assert_false(bridge._line_presentation.acknowledged)
	assert_false(_bootstrap.has_node("ContentError"), "terminal UI waits until acknowledgement releases ownership")
	assert_eq(bridge.acknowledge_current_line_presentation(frontier), result)
	assert_eq(profile.writes, 1, "a retained fatal outcome must not retry persistence")
	await get_tree().process_frame
	var confirmation: Control = _bootstrap.get_node_or_null("ContentError/ContentErrorConfirmation")
	assert_not_null(confirmation, "fatal acknowledgement must present terminal UI")
	if confirmation == null: return
	assert_true(confirmation.is_visible_in_tree())
	assert_true(get_tree().paused)
	assert_eq(confirmation.request.body, result.message)
	assert_eq(confirmation.request.confirm, "Quit")
	assert_same(get_viewport().gui_get_focus_owner(), confirmation.confirm_button)
	assert_eq(_bootstrap._application_gate.guard_external(&"save").code, &"APPLICATION_FATAL")

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
	assert_eq(underlying.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	# Live Next completion restores its saved canvas custody after reporting failure.
	underlying.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
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
