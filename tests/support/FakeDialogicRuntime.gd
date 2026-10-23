extends Node
## Test double for the installed Dialogic autoload, exposing ONLY the audited API surface
## (dwm-p2r.8, Plan-05 Task 2 Step 2.1). Records call order; can omit a subsystem to prove the
## adapter's safe error; exposes get_full_state() but counts reads so a test can prove the
## adapter never serializes full addon state.

signal timeline_started
signal timeline_ended
signal event_handled(resource)
signal signal_event(argument)
signal dialogic_paused
signal dialogic_resumed

var current_timeline: Object = null
var current_timeline_events: Array = []
var current_event_idx: int = -1
var paused: bool = false

var calls: Array = []
var _full_state_reads := 0


class _TextSubsystem extends RefCounted:
	signal text_started(info: Dictionary)
	signal text_finished(info: Dictionary)
	var calls: Array = []
	func skip_text_reveal() -> void:
		calls.append("skip_text_reveal")


class _ChoicesSubsystem extends RefCounted:
	signal question_shown(info: Dictionary)
	signal choice_selected(info: Dictionary)
	var calls: Array = []
	func select_choice(button_index: int) -> void:
		calls.append("select_choice:%d" % button_index)


var _text_subsystem: RefCounted = null
var _choices_subsystem: RefCounted = null


func _init(include_text := true, include_choices := true) -> void:
	if include_text:
		_text_subsystem = _TextSubsystem.new()
	if include_choices:
		_choices_subsystem = _ChoicesSubsystem.new()


func has_subsystem(subsystem_name: String) -> bool:
	return get_subsystem(subsystem_name) != null


func get_subsystem(subsystem_name: String) -> RefCounted:
	match subsystem_name:
		"Text":
			return _text_subsystem
		"Choices":
			return _choices_subsystem
	return null


func start(timeline: Variant, label_or_idx: Variant = "") -> Object:
	calls.append("start:%s:%s" % [str(timeline), str(label_or_idx)])
	current_timeline = RefCounted.new()
	current_event_idx = int(label_or_idx) if typeof(label_or_idx) == TYPE_INT else 0
	timeline_started.emit()
	return null


func start_timeline(timeline: Variant, label_or_idx: Variant = "") -> void:
	calls.append("start_timeline:%s:%s" % [str(timeline), str(label_or_idx)])
	current_timeline = RefCounted.new()
	current_event_idx = int(label_or_idx) if typeof(label_or_idx) == TYPE_INT else 0


func end_timeline(skip_ending := false) -> void:
	calls.append("end_timeline:%s" % str(skip_ending))
	current_timeline = null
	current_event_idx = -1
	timeline_ended.emit()


func handle_next_event(_ignore: Variant = "") -> void:
	calls.append("handle_next_event")
	current_event_idx += 1


func handle_event(event_index: int) -> void:
	calls.append("handle_event:%d" % event_index)
	current_event_idx = event_index


func clear(flags := 0) -> void:
	calls.append("clear:%d" % flags)
	current_timeline = null
	current_event_idx = -1


func get_full_state() -> Dictionary:
	_full_state_reads += 1
	return {}


func full_state_reads() -> int:
	return _full_state_reads
