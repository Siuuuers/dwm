@tool
class_name DialogicWaitEvent
extends DialogicEvent

## Event that waits for some time before continuing.


### Settings

## The time in seconds that the event will stop before continuing.
var time: float = 1.0
## If true the text box will be hidden while the event waits.
var hide_text := true
## If true the wait can be skipped with user input
var skippable := false

var _tween: Tween
var _execution_token := 0
var _execution_generation := -1
var _execution_event_index := -1
var _execution_owner: DialogicGameHandler
var _pending := false
var _active := false
var _finishing := false
var _finish_callback := Callable()
var _pause_callback := Callable()
var _resume_callback := Callable()


#region EXECUTE
################################################################################

## Capture this invocation before the deferred body or event_started observers run.
## A cached Wait resource can be cancelled and executed again in the same frame.
func execute(_dialogic_game_handler) -> void:
	_clear_state()
	dialogic = _dialogic_game_handler
	_execution_owner = dialogic
	_execution_generation = dialogic.get_timeline_generation()
	_execution_event_index = dialogic.current_event_idx
	_pending = true
	var token := _execution_token
	event_started.emit(self)
	call_deferred("_execute_wait", token)


func _execute_wait(token: int) -> void:
	if not _owns_execution(token) or not _pending:
		return
	_pending = false
	_active = true
	var owner := _execution_owner
	var final_wait_time := time

	# Hidden, non-skippable holds retain their authored duration under Skip.
	# Other authored Wait events keep the existing native auto-skip behavior.
	if owner.Inputs.auto_skip.enabled and (skippable or not hide_text):
		var time_per_event: float = owner.Inputs.auto_skip.time_per_event
		final_wait_time = min(time, time_per_event)

	_finish_callback = _on_finish.bind(token)
	_pause_callback = _on_pause.bind(token)
	_resume_callback = _on_resume.bind(token)
	owner.dialogic_paused.connect(_pause_callback)
	owner.dialogic_resumed.connect(_resume_callback)
	if skippable:
		owner.Inputs.dialogic_action.connect(_finish_callback)

	_tween = owner.create_tween()
	if DialogicUtil.is_physics_timer():
		_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_callback(_finish_callback).set_delay(final_wait_time)
	if owner.paused:
		_tween.pause()

	if hide_text and owner.has_subsystem("Text"):
		owner.Text.update_dialog_text('', true)
		if not _owns_execution(token):
			return
		owner.Text.hide_textbox()
		if not _owns_execution(token):
			return

	owner.current_state = owner.States.WAITING


## Pure, ephemeral identity for a live timer. No timing cursor is persisted.
## Pending deferred execution and retired/cancelled events have no frontier.
func get_wait_execution_state() -> Dictionary:
	if not _owns_execution(_execution_token) or not _active or _finishing:
		return {}
	if not is_instance_valid(_tween) or not _tween.is_valid():
		return {}
	if _execution_owner.current_state != _execution_owner.States.WAITING:
		return {}
	if not is_finite(time) or time <= 0.0:
		return {}
	return {
		"execution_token": _execution_token,
		"timeline_generation": _execution_generation,
		"event_index": _execution_event_index,
		"paused": _execution_owner.paused,
		"hide_text": hide_text,
		"skippable": skippable,
	}


func _owns_execution(token: int) -> bool:
	if token != _execution_token or not is_instance_valid(_execution_owner):
		return false
	if dialogic != _execution_owner or _execution_owner.is_ending_timeline():
		return false
	if _execution_owner.get_timeline_generation() != _execution_generation:
		return false
	if _execution_owner.current_timeline == null:
		return false
	if _execution_owner.current_event_idx != _execution_event_index:
		return false
	if _execution_event_index < 0 or _execution_event_index >= _execution_owner.current_timeline_events.size():
		return false
	return _execution_owner.current_timeline_events[_execution_event_index] == self


func _on_pause(token: int) -> void:
	if _owns_execution(token) and _active and not _finishing and is_instance_valid(_tween) and _tween.is_valid():
		_tween.pause()


func _on_resume(token: int) -> void:
	if _owns_execution(token) and _active and not _finishing and is_instance_valid(_tween) and _tween.is_valid():
		_tween.play()


func _on_finish(token: int) -> void:
	if not _owns_execution(token) or not _active or _finishing:
		return
	var owner := _execution_owner
	if owner.paused:
		return
	_finishing = true
	_stop_owned_activity()

	if owner.Animations.is_animating():
		owner.Animations.stop_animation()
		if not _owns_execution(token):
			return
	owner.current_state = owner.States.IDLE
	if not _owns_execution(token):
		return

	# Retire before emitting: duplicate callbacks cannot finish this event twice.
	_clear_state()
	finish()


func _clear_state() -> void:
	_execution_token += 1
	_pending = false
	_active = false
	_finishing = false
	_stop_owned_activity()
	_execution_owner = null
	_execution_generation = -1
	_execution_event_index = -1


func _stop_owned_activity() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	if is_instance_valid(_execution_owner):
		if _pause_callback.is_valid() and _execution_owner.dialogic_paused.is_connected(_pause_callback):
			_execution_owner.dialogic_paused.disconnect(_pause_callback)
		if _resume_callback.is_valid() and _execution_owner.dialogic_resumed.is_connected(_resume_callback):
			_execution_owner.dialogic_resumed.disconnect(_resume_callback)
		if _finish_callback.is_valid() and _execution_owner.has_subsystem("Inputs"):
			if _execution_owner.Inputs.dialogic_action.is_connected(_finish_callback):
				_execution_owner.Inputs.dialogic_action.disconnect(_finish_callback)
	_finish_callback = Callable()
	_pause_callback = Callable()
	_resume_callback = Callable()

#endregion


#region INITIALIZE
################################################################################

func _init() -> void:
	event_name = "Wait"
	event_description = "Waits a given amount of time. Can hide the textbox and be skippable."
	set_default_color('Color5')
	event_category = "Flow"
	event_sorting_index = 11

#endregion


#region SAVING/LOADING
################################################################################

func get_shortcode() -> String:
	return "wait"


func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name : property_info
		"time" 		:  {"property": "time", 		"default": 1},
		"hide_text" :  {"property": "hide_text", 	"default": true},
		"skippable" :  {"property": "skippable", 	"default": false},
	}

#endregion


#region EDITOR REPRESENTATION
################################################################################

func build_event_editor() -> void:
	add_header_edit('time', ValueType.NUMBER, {'left_text':'Wait', 'autofocus':true, 'min':0.1})
	add_header_label('seconds', 'time != 1')
	add_header_label('second', 'time == 1')
	add_body_edit('hide_text', ValueType.BOOL, {'left_text':'Hide text box:'})
	add_body_edit('skippable', ValueType.BOOL, {'left_text':'Skippable:'})

#endregion
