extends AppWindowBase
class_name ScheduleApp

signal recovery_requested(code: StringName)
signal warning_foreground_changed(active: bool)
signal command_custody_changed(active: bool)
const PANEL := preload("res://scripts/ui/schedule/SchedulePanel.gd")
const WARNING_SHEET := preload("res://scripts/ui/schedule/ScheduleWarningSheet.gd")

var panel: Control
var last_result: Dictionary = {"ok":false,"code":&"schedule_unconfigured"}
var _port: Object
var _projection: Dictionary = {}
var _locale := "en"
var _home: Button
var _done: Callable
var _busy := false
var _failure: Label
var _remembered_focus := "fresh"
var warning_sheet: Control
var _warning_port: Object
var _warning_commands: Object
var _warning_data: Dictionary = {}
var _warning_focus := "close"
var _warning_prior_process := Node.PROCESS_MODE_INHERIT
var _percent := 100
var _large := false
var _palette := &"after_hours"
var _day := 1
var _high_contrast := false
var _colour_preset := "standard"
var _command_sequence := 0
var _localization: Object
var _profile: Object
var _preferences_pending := false
const SHARED_KEYS := ["preferences.accessibility.text_size", "preferences.accessibility.large_targets",
	"preferences.accessibility.high_contrast", "preferences.accessibility.colour_differentiation"]

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
	get_viewport().gui_focus_changed.connect(func(_control):
		remember_focus()
		if _preferences_pending: _apply_shared_preferences.call_deferred())
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			panel.cancel_contacts()
			panel.clear_status()
			if panel.has_method("cancel_drag"): panel.cancel_drag())

func configure_presentation(port: Object, locale: String = "en", percent: int = 100,
		large: bool = false, done_handler: Callable = Callable(), palette: StringName = &"after_hours",
		warning_presentation: Object = null, warning_commands: Object = null,
		day: int = 1) -> Dictionary:
	if warning_presentation != null or warning_commands != null:
		var warning_validation := _validate_warning_pair(warning_presentation,warning_commands)
		if not warning_validation.ok: return warning_validation
	if port == null: return _fail(&"schedule_unconfigured")
	for method in ["project","append","move","remove"]:
		if not port.has_method(method): return _fail(&"invalid_schedule_presentation")
	var next_locale := locale.replace("_","-")
	if not panel.configure(next_locale,percent,large,palette,day,_high_contrast,_colour_preset):
		return _fail(&"invalid_schedule_configuration")
	_locale = next_locale
	_percent = percent
	_large = large
	_palette = palette
	_day = day
	_port = port
	if warning_presentation != null:
		_warning_port = warning_presentation
		_warning_commands = warning_commands
	_done = done_handler
	panel.set_done_enabled(_done.is_valid())
	return refresh_view()

func configure_desktop_home(home: Button) -> void:
	_home = home
	panel.configure_home(home)

func _validate_warning_pair(presentation: Object, commands: Object) -> Dictionary:
	if not is_instance_valid(presentation) or not presentation.has_method("project") or not is_instance_valid(commands) or not commands.has_method("resolve_warning"):
		return {"ok":false,"code":&"invalid_warning_presentation"}
	if Callable(presentation,"project").get_argument_count() != 1 or Callable(commands,"resolve_warning").get_argument_count() != 2:
		return {"ok":false,"code":&"invalid_warning_presentation"}
	if _warning_port != null and (_warning_port != presentation or _warning_commands != commands):
		return {"ok":false,"code":&"warning_presentation_already_configured"}
	return {"ok":true,"code":&"ok"}

func configure_warning(presentation: Object, commands: Object) -> Dictionary:
	var validation := _validate_warning_pair(presentation,commands)
	if not validation.ok: return validation
	_warning_port = presentation
	_warning_commands = commands
	return refresh_view()

func configure_shared_preferences(localization: Object = null, profile: Object = null) -> Dictionary:
	if localization != null and (not is_instance_valid(localization) or not localization.has_method("get_locale") or not localization.has_signal("locale_changed")):
		return {"ok":false,"code":&"invalid_schedule_preferences"}
	if profile != null and (not is_instance_valid(profile) or not profile.has_method("get_preference") or not profile.has_signal("preference_changed")):
		return {"ok":false,"code":&"invalid_schedule_preferences"}
	if (_localization != null and localization != null and _localization != localization) or (_profile != null and profile != null and _profile != profile):
		return {"ok":false,"code":&"schedule_preferences_already_configured"}
	var next_localization: Object = localization if localization != null else _localization
	var next_profile: Object = profile if profile != null else _profile
	var tuple := _read_shared_preferences(next_localization,next_profile)
	if not tuple.ok: return tuple
	if _localization == null and next_localization != null:
		_localization = next_localization
		_localization.connect("locale_changed",_on_shared_locale_changed)
	if _profile == null and next_profile != null:
		_profile = next_profile
		_profile.connect("preference_changed",_on_shared_preference_changed)
	_preferences_pending = true
	return _apply_shared_preferences()

func _read_shared_preferences(localization: Object, profile: Object) -> Dictionary:
	if (localization != null and not is_instance_valid(localization)) or (profile != null and not is_instance_valid(profile)):
		return {"ok":false,"code":&"invalid_schedule_preferences"}
	var locale: Variant = localization.get_locale() if localization != null else _locale
	var percent: Variant = profile.get_preference(SHARED_KEYS[0],null) if profile != null else _percent
	var large: Variant = profile.get_preference(SHARED_KEYS[1],null) if profile != null else _large
	var high_contrast: Variant = profile.get_preference(SHARED_KEYS[2],false) if profile != null else _high_contrast
	var colour_preset: Variant = profile.get_preference(SHARED_KEYS[3],"standard") if profile != null else _colour_preset
	if typeof(locale) != TYPE_STRING or locale.replace("_","-") not in ["en","zh-CN","zh-HK", "ja", "ko"] or typeof(percent) != TYPE_INT or percent not in [100,125,150] or typeof(large) != TYPE_BOOL or typeof(high_contrast) != TYPE_BOOL or typeof(colour_preset) != TYPE_STRING or colour_preset not in ["standard","protan","deutan","tritan"]:
		return {"ok":false,"code":&"invalid_schedule_preferences"}
	return {"ok":true,"code":&"ok","value":[locale.replace("_","-"),percent,large,high_contrast,colour_preset]}

func _on_shared_locale_changed(_locale_id: String) -> void:
	_preferences_pending = true
	_apply_shared_preferences()

func _on_shared_preference_changed(path: StringName, _value: Variant) -> void:
	if str(path) not in SHARED_KEYS: return
	_preferences_pending = true
	_apply_shared_preferences()

func _apply_shared_preferences(on_open: bool = false) -> Dictionary:
	if not _preferences_pending: return {"ok":true,"code":&"unchanged"}
	var tuple := _read_shared_preferences(_localization,_profile)
	if not tuple.ok: return tuple
	if tuple.value == [_locale,_percent,_large,_high_contrast,_colour_preset]:
		_preferences_pending = false
		return {"ok":true,"code":&"unchanged"}
	var focused := get_viewport().gui_get_focus_owner()
	# A shared modal may have saved per-control custody. Do not replace those
	# controls underneath its saved state or steal its foreground focus.
	if _busy or not can_process() or not _focus_custody_enabled() or not is_visible_in_tree() or (not on_open and focused != null and not is_ancestor_of(focused)):
		return {"ok":true,"code":&"deferred"}
	if not on_open and panel.process_mode == Node.PROCESS_MODE_DISABLED and not is_instance_valid(warning_sheet):
		return {"ok":true,"code":&"deferred"}
	remember_focus()
	panel.cancel_contacts()
	panel.cancel_drag()
	if not panel.configure(tuple.value[0],tuple.value[1],tuple.value[2],_palette,_day,
			tuple.value[3],tuple.value[4]):
		return {"ok":false,"code":&"invalid_schedule_preferences"}
	_locale = tuple.value[0]
	_percent = tuple.value[1]
	_large = tuple.value[2]
	_high_contrast = tuple.value[3]
	_colour_preset = tuple.value[4]
	_preferences_pending = false
	return refresh_view(true)

func refresh_view(preserve_presentation: bool = false) -> Dictionary:
	if _port == null: return _fail(&"schedule_unconfigured")
	if _warning_port != null:
		var warning: Dictionary = _warning_port.project(_locale)
		if not warning.get("ok",false): return _fail(StringName(warning.get("code","warning_unavailable")))
		if warning.value.warning != null: return _show_warning(warning.value.warning)
		_clear_warning()
	var projected: Dictionary = _port.project(_locale)
	var restore_scroll := not _projection.is_empty()
	if not preserve_presentation and projected.get("ok",false) and not _projection.is_empty() and projected.value.fingerprint != _projection.fingerprint:
		# An externally replaced view is a fresh presentation, not an old cache.
		clear_presentation_cache()
		restore_scroll = false
	return _publish(projected,panel.selected_id,_remembered_focus,restore_scroll)

func remember_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and panel.is_ancestor_of(focused): _remembered_focus = _focused_key()
	if is_instance_valid(warning_sheet):
		if focused == warning_sheet.go_button: _warning_focus = "go"
		elif focused == warning_sheet.close_button: _warning_focus = "close"

func clear_presentation_cache() -> void:
	_remembered_focus = "fresh"
	panel.clear_status()
	panel.selected_id = ""
	panel.clear_scroll_anchors()

func hide_window() -> void:
	if not can_return_home(): return
	remember_focus()
	super.hide_window()

func show_window() -> void:
	show()
	_apply_shared_preferences(true)
	refresh_view()
	if is_instance_valid(warning_sheet): _restore_warning_focus.call_deferred()

func _restore_warning_focus() -> void:
	if not is_visible_in_tree() or not can_process() or not _focus_custody_enabled() or _busy or not is_instance_valid(warning_sheet): return
	var button: Button = warning_sheet.go_button if _warning_focus == "go" else warning_sheet.close_button
	if button.get_focus_mode_with_override() == Control.FOCUS_ALL: button.grab_focus()

func can_return_home() -> bool:
	if _busy or is_instance_valid(warning_sheet): return false
	if panel.has_method("is_dragging") and panel.is_dragging(): return false
	if _port != null:
		var current: Dictionary = _port.project(_locale)
		if str(current.get("code","")) == "warning_modal_active": return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if is_instance_valid(warning_sheet):
		# The sheet handles Back; unhandled input cannot reach the desk or Home.
		get_viewport().set_input_as_handled()
		return
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
	_command_sequence += 1
	_busy = true
	var result: Dictionary = _port.append(source_id,_projection.fingerprint,_locale)
	_busy = false
	if not result.get("ok",false):
		_refused(result)
		return
	panel.clear_status()
	var entries: Array = result.value.entries
	var selected: String = entries[-1].id if not entries.is_empty() else ""
	var focus_key := "source:"+source_id
	if result.value.day_seven and not _projection.entries.is_empty() and result.value.entries != _projection.entries:
		focus_key = "entry:"+selected
	_publish(result,selected,focus_key)

func _move(id: String, target: int) -> void:
	if not _admit(): return
	_command_sequence += 1
	_busy = true
	var result: Dictionary = _port.move(id,target,_projection.fingerprint,_locale)
	_busy = false
	if not result.get("ok",false): _refused(result)
	else:
		panel.clear_status()
		_publish(result,id,"entry:"+id)

func _remove(id: String) -> void:
	if not _admit(): return
	_command_sequence += 1
	var old_index := 0
	for i in _projection.entries.size():
		if _projection.entries[i].id == id: old_index = i
	_busy = true
	var result: Dictionary = _port.remove(id,_projection.fingerprint,_locale)
	_busy = false
	if not result.get("ok",false):
		_refused(result)
		return
	panel.clear_status()
	var entries: Array = result.value.entries
	var selected: String = entries[mini(old_index,entries.size()-1)].id if not entries.is_empty() else ""
	_publish(result,selected,"entry:"+selected if selected != "" else "fresh")

func _dispatch_done() -> void:
	if not _admit() or not _done.is_valid(): return
	_command_sequence += 1
	panel.clear_status()
	_busy = true
	command_custody_changed.emit(true)
	panel.cancel_contacts()
	var prior_process := panel.process_mode
	panel.process_mode = Node.PROCESS_MODE_DISABLED
	# Shared Home custody belongs to its host. can_return_home() refuses while
	# this command is pending; never restore over a destination's newer state.
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	var source_scene: Node = _command_source_scene()
	var result: Variant = await _done.call()
	if not is_instance_valid(self) or not _command_source_is_current(source_scene): return
	panel.cancel_contacts()
	panel.process_mode = prior_process
	_busy = false
	command_custody_changed.emit(false)
	if _preferences_pending: _apply_shared_preferences.call_deferred()
	if typeof(result) != TYPE_DICTIONARY: _fail(&"schedule_done_invalid_result")
	elif not result.get("ok",false): _refused(result)
	elif _warning_port != null and is_visible_in_tree(): refresh_view(true)
	# Done's actual navigation/warning owner controls the accepted next surface.

func _command_source_scene() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null and (scene == self or scene.is_ancestor_of(self)) else null

func _command_source_is_current(source_scene: Node) -> bool:
	if not is_inside_tree() or not is_instance_valid(panel): return false
	if source_scene != null and (not is_instance_valid(source_scene) or get_tree().current_scene != source_scene or (source_scene != self and not source_scene.is_ancestor_of(self))): return false
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion(): return false
		ancestor = ancestor.get_parent()
	return true

func _admit() -> bool:
	return can_process() and panel.can_process() and _focus_custody_enabled() and not _busy and not is_instance_valid(warning_sheet) and not panel.is_dragging() and is_visible_in_tree() and _port != null and last_result.get("ok",false)

func _focus_custody_enabled() -> bool:
	var current: Control = self
	while current != null:
		if current.focus_behavior_recursive != Control.FOCUS_BEHAVIOR_INHERITED:
			return current.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_ENABLED
		current = current.get_parent_control()
	return true

func _show_warning(data: Dictionary) -> Dictionary:
	if not _port.has_method("project_modal_background"): return _fail(&"warning_background_unavailable")
	var background: Dictionary = _port.project_modal_background(_locale)
	if not background.get("ok",false): return _fail(StringName(background.get("code","warning_background_unavailable")))
	# Preserve exact Docket evidence. No disabled/source-state repaint is fabricated.
	var published := _publish(background,panel.selected_id,"",true)
	if not published.ok: return published
	if not is_instance_valid(warning_sheet):
		_warning_prior_process = panel.process_mode
		panel.cancel_contacts()
		panel.cancel_drag()
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and panel.is_ancestor_of(focused): focused.release_focus()
		panel.process_mode = Node.PROCESS_MODE_DISABLED
		_warning_focus = "close"
		warning_sheet = WARNING_SHEET.new()
		warning_sheet.z_index = 40
		_content_host.add_child(warning_sheet)
		warning_sheet.close_requested.connect(func(): _resolve_warning(&"dismiss"))
		warning_sheet.go_requested.connect(func(): _resolve_warning(_warning_data.go_intent))
		warning_foreground_changed.emit(true)
	if not warning_sheet.configure(_locale,_percent,_large,_palette,_day,_high_contrast,_colour_preset) or not warning_sheet.present(data.activation_id,data.copy,data.error):
		return _fail(&"invalid_warning_copy_layout")
	_warning_data = data.duplicate(true)
	return last_result

func _clear_warning() -> void:
	if not is_instance_valid(warning_sheet): return
	warning_sheet.hide()
	warning_sheet.queue_free()
	warning_sheet = null
	_warning_data.clear()
	panel.process_mode = _warning_prior_process
	warning_foreground_changed.emit(false)

func _resolve_warning(intent: StringName) -> void:
	if _busy or not can_process() or not _focus_custody_enabled() or not is_instance_valid(warning_sheet) or _warning_data.is_empty(): return
	_busy = true
	command_custody_changed.emit(true)
	warning_sheet.set_busy(true)
	var source_scene: Node = _command_source_scene()
	var result: Variant = await _warning_commands.resolve_warning(_warning_data.activation_id,intent)
	if not is_instance_valid(self) or not _command_source_is_current(source_scene): return
	_busy = false
	command_custody_changed.emit(false)
	if _preferences_pending: _apply_shared_preferences.call_deferred()
	if is_instance_valid(warning_sheet): warning_sheet.set_busy(false)
	if not is_visible_in_tree():
		_clear_warning()
		return
	if typeof(result) != TYPE_DICTIONARY: _fail(&"invalid_warning_command_result")
	elif not result.get("ok",false): _fail(StringName(result.get("code","warning_command_failed")))
	else:
		# A failed Go is projected only from the owner's retained failed-attempt
		# fact. The UI neither consumes its receipt nor invents a success route.
		refresh_view(true)

func _publish(result: Dictionary, selected: String = "", focus_key: String = "", preserve_scroll: bool = false) -> Dictionary:
	if not result.get("ok",false): return _fail(StringName(result.get("code","schedule_unavailable")))
	if not is_visible_in_tree() or _busy or is_instance_valid(warning_sheet): focus_key = ""
	if not panel.set_projection(result.value,selected,focus_key,preserve_scroll): return _fail(&"schedule_presentation_integrity_failed")
	_projection = result.value.duplicate(true)
	last_result = {"ok":true,"code":&"ok"}
	panel.show()
	if is_instance_valid(_failure): _failure.hide()
	return last_result

func _refused(result: Dictionary) -> void:
	if str(result.get("code","")) == "insufficient_motivation":
		panel.set_refusal_status(str(_command_sequence),&"insufficient_motivation")
		panel.focus_target("done")
		return
	if str(result.get("code","")) in ["stale_view_fingerprint","schedule_source_unavailable"]:
		var focus_key := _focused_key()
		var refreshed := _publish(_port.project(_locale),panel.selected_id,focus_key,true)
		if refreshed.ok: panel.set_refusal_status(str(_command_sequence))
		return
	if str(result.get("code","")) in ["invalid_target_index","draft_entry_not_found","day7_move_refused"]:
		panel.set_refusal_status(str(_command_sequence))
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
	_clear_warning()
	if is_instance_valid(panel): panel.clear_status()
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
