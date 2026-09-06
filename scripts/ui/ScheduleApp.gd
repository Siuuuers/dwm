extends AppWindowBase
class_name ScheduleApp

signal recovery_requested(code: StringName)
const PANEL := preload("res://scripts/ui/schedule/SchedulePanel.gd")

var panel: Control
var last_result: Dictionary = {"ok":false,"code":&"schedule_unconfigured"}
var _port: Object
var _projection: Dictionary = {}
var _locale := "en"
var _home: Button
var _done: Callable
var _busy := false
var _failure: Label

func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(800,656)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	$VBoxContainer/TopBar.hide()
	$VBoxContainer.add_theme_constant_override("separation",0)
	_content_host.custom_minimum_size = Vector2(800,656)
	panel = PANEL.new()
	_content_host.add_child(panel)
	panel.source_requested.connect(_append)
	panel.move_requested.connect(_move)
	panel.remove_requested.connect(_remove)
	panel.done_requested.connect(_dispatch_done)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			panel.cancel_contacts()
			if panel.has_method("cancel_drag"): panel.cancel_drag())

func configure_presentation(port: Object, locale: String = "en", percent: int = 100,
		large: bool = false, done_handler: Callable = Callable()) -> Dictionary:
	if port == null: return _fail(&"schedule_unconfigured")
	for method in ["project","append","move","remove"]:
		if not port.has_method(method): return _fail(&"invalid_schedule_presentation")
	_locale = locale.replace("_","-")
	if not panel.configure(_locale,percent,large): return _fail(&"invalid_schedule_configuration")
	_port = port
	_done = done_handler
	panel.set_done_enabled(_done.is_valid())
	return refresh_view()

func configure_desktop_home(home: Button) -> void:
	_home = home
	panel.configure_home(home)

func refresh_view() -> Dictionary:
	if _port == null: return _fail(&"schedule_unconfigured")
	var projected: Dictionary = _port.project(_locale)
	return _publish(projected,panel.selected_id,_focused_key())

func show_window() -> void:
	show()
	if last_result.get("ok",false): panel.focus_target()
	elif is_instance_valid(_home): _home.grab_focus()

func can_return_home() -> bool:
	if _busy: return false
	if panel.has_method("is_dragging") and panel.is_dragging(): return false
	if _port != null:
		var current: Dictionary = _port.project(_locale)
		if str(current.get("code","")) == "warning_modal_active": return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel"):
		if panel.has_method("is_dragging") and panel.is_dragging():
			panel.cancel_drag()
			get_viewport().set_input_as_handled()
			return
		panel.cancel_contacts()
		if can_return_home(): hide_window()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(panel):
		panel.cancel_contacts()
		if panel.has_method("cancel_drag"): panel.cancel_drag()

func _append(source_id: String) -> void:
	if not _admit(): return
	_busy = true
	var result: Dictionary = _port.append(source_id,_projection.fingerprint,_locale)
	_busy = false
	if not result.get("ok",false):
		_refused(result)
		return
	var entries: Array = result.value.entries
	var selected: String = entries[-1].id if not entries.is_empty() else ""
	var focus_key := "source:"+source_id
	if result.value.day_seven and not _projection.entries.is_empty() and result.value.entries != _projection.entries:
		focus_key = "entry:"+selected
	_publish(result,selected,focus_key)

func _move(id: String, target: int) -> void:
	if not _admit(): return
	_busy = true
	var result: Dictionary = _port.move(id,target,_projection.fingerprint,_locale)
	_busy = false
	if not result.get("ok",false): _refused(result)
	else: _publish(result,id,"entry:"+id)

func _remove(id: String) -> void:
	if not _admit(): return
	var old_index := 0
	for i in _projection.entries.size():
		if _projection.entries[i].id == id: old_index = i
	_busy = true
	var result: Dictionary = _port.remove(id,_projection.fingerprint,_locale)
	_busy = false
	if not result.get("ok",false):
		_refused(result)
		return
	var entries: Array = result.value.entries
	var selected: String = entries[mini(old_index,entries.size()-1)].id if not entries.is_empty() else ""
	_publish(result,selected,"entry:"+selected if selected != "" else "fresh")

func _dispatch_done() -> void:
	if not _admit() or not _done.is_valid(): return
	_busy = true
	panel.cancel_contacts()
	var prior_process := panel.process_mode
	panel.process_mode = Node.PROCESS_MODE_DISABLED
	# Shared Home custody belongs to its host. can_return_home() refuses while
	# this command is pending; never restore over a destination's newer state.
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	var result: Variant = await _done.call()
	panel.cancel_contacts()
	panel.process_mode = prior_process
	_busy = false
	if typeof(result) != TYPE_DICTIONARY: _fail(&"schedule_done_invalid_result")
	elif not result.get("ok",false): _refused(result)
	# Done's actual navigation/warning owner controls the accepted next surface.

func _admit() -> bool:
	return not _busy and not panel.is_dragging() and is_visible_in_tree() and _port != null and last_result.get("ok",false)

func _publish(result: Dictionary, selected: String = "", focus_key: String = "") -> Dictionary:
	if not result.get("ok",false): return _fail(StringName(result.get("code","schedule_unavailable")))
	if not panel.set_projection(result.value,selected,focus_key): return _fail(&"schedule_presentation_integrity_failed")
	_projection = result.value.duplicate(true)
	last_result = {"ok":true,"code":&"ok"}
	panel.show()
	if is_instance_valid(_failure): _failure.hide()
	return last_result

func _refused(result: Dictionary) -> void:
	if str(result.get("code","")) in ["stale_view_fingerprint","schedule_source_unavailable"]:
		var focus_key := _focused_key()
		_publish(_port.project(_locale),panel.selected_id,focus_key)
		return
	if str(result.get("code","")) in ["invalid_target_index","draft_entry_not_found","day7_move_refused"]:
		# Expected refusal retains this frame and its Focus/inspection. Host may refresh.
		return
	_fail(StringName(result.get("code","schedule_unavailable")))

func _focused_key() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	for id in panel.source_buttons:
		if panel.source_buttons[id] == focused: return "source:"+id
	for id in panel.entry_buttons:
		if panel.entry_buttons[id] == focused: return "entry:"+id
	for id in panel.commands:
		if panel.commands[id] == focused: return id
	if focused == _home: return "home"
	return "done" if focused == panel.done_button else "fresh"

func _fail(code: StringName) -> Dictionary:
	last_result = {"ok":false,"code":code}
	if is_instance_valid(panel):
		panel.cancel_contacts()
		panel.hide()
		if not is_instance_valid(_failure):
			_failure = Label.new()
			_failure.position = Vector2(16,16)
			_failure.size = Vector2(768,80)
			_failure.theme = panel.theme
			_content_host.add_child(_failure)
		_failure.text = PANEL.COPY[_locale][5]
		_failure.show()
	if is_instance_valid(_home) and is_visible_in_tree(): _home.grab_focus()
	recovery_requested.emit(code)
	return last_result
