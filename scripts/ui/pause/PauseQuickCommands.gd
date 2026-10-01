extends Node
signal load_cancelled
signal load_finished(result: Dictionary)
## Quick input for the retained Pause source. The existing Backup port owns all
## permissions, prepared tokens, durability and restore compensation.
const EDGE := preload("res://scripts/ui/desktop/QuickStatusEdge.gd")
const COPY := preload("res://scripts/ui/BackupApp.gd").COPY
const BACKUP_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")
const ACTIONS := {&"game_quick_save": "save", &"game_quick_load": "load"}

var edge: Label
var last_result: Dictionary = {}
var _surface: Control
var _port: Object
var _input_owner: Object
var _admission: Callable
var _source_reader: Callable
var _contacts: Dictionary = {}
var _source: Dictionary = {}
var _condition: Dictionary = {}
var _pending_token := ""
var _confirmation: Control
var _return_focus: WeakRef
var _return_host: StringName = &""
var _return_semantic := ""
var _focus_restore_pending := false
var _in_operation := false
var _foreground := true
var _was_admitted := false
var _observed_source: Dictionary = {}
var _presentation: Dictionary = {}
var _pending_poll := 0.0

func configure(surface: Control, port: Object, input_owner: Object,
		admission: Callable, source_reader: Callable) -> bool:
	if _surface != null or not is_instance_valid(surface) or not admission.is_valid() \
			or not source_reader.is_valid(): return false
	for method: String in ["get_quick_capability", "prepare_quick_action", "is_quick_condition_current", "commit_action", "cancel_action"]:
		if not is_instance_valid(port) or not port.has_method(method): return false
	for method: String in ["get_physical_contacts", "get_physical_contact_id", "observe_physical_contact"]:
		if not is_instance_valid(input_owner) or not input_owner.has_method(method): return false
	for event: String in ["input_bindings_changed", "source_input_custody_changed"]:
		if not input_owner.has_signal(event): return false
	_surface = surface
	_port = port
	_input_owner = input_owner
	_admission = admission
	_source_reader = source_reader
	_input_owner.input_bindings_changed.connect(retain_contacts)
	_input_owner.source_input_custody_changed.connect(retain_contacts)
	_surface.visibility_changed.connect(retain_contacts)
	process_mode = Node.PROCESS_MODE_ALWAYS
	return true

func _ready() -> void:
	edge = EDGE.new()
	edge.name = "PauseQuickStatus"
	edge.position = Vector2(32, 544)
	edge.size = Vector2(416, 144)
	_surface.add_child(edge)
	retain_contacts()

func _exit_tree() -> void:
	_cancel_pending()
	if is_instance_valid(edge): edge.queue_free()

func retain_contacts() -> void:
	if is_instance_valid(_input_owner): _contacts = _input_owner.get_physical_contacts()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_foreground = false
		if is_instance_valid(edge): edge.set_eligible(false)
		# Invalidate consent at the event boundary, including an out/in pair that
		# occurs before the next frame. Focus restoration waits for foreground.
		_cancel_pending()
		if is_instance_valid(_confirmation): _confirmation._finish(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _foreground = true
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN,
			NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]: retain_contacts()

func _base_admitted() -> bool:
	return _foreground and _source_owned()

func _source_owned() -> bool:
	return is_instance_valid(_surface) and _surface.is_visible_in_tree() \
		and _surface.can_process() and _admission.is_valid() and bool(_admission.call()) \
		and not _source_snapshot().is_empty()

func _admitted() -> bool:
	return _base_admitted() and not _in_operation and _pending_token.is_empty() \
		and _surface.quick_input_admitted()

func _source_snapshot() -> Dictionary:
	return _source_reader.call() if _source_reader.is_valid() else {}

func observe_input(event: InputEvent) -> void:
	_input_owner.observe_physical_contact(event)
	if not _admitted(): retain_contacts()

func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventKey or event is InputEventJoypadButton): return false
	var action := ""
	for mapped: StringName in ACTIONS:
		if InputMap.has_action(mapped) and event.is_action_pressed(mapped, false, true): action = ACTIONS[mapped]
	if action.is_empty(): return false
	var current: Dictionary = _input_owner.get_physical_contacts()
	for contact: String in _contacts.keys():
		if current.get(contact) != _contacts[contact]: _contacts.erase(contact)
	var id: String = _input_owner.get_physical_contact_id(event)
	if id.is_empty() or not current.has(id): return true
	var fresh := _contacts.is_empty() and current.size() == 1
	_contacts[id] = current[id]
	if not fresh or not _admitted(): return true
	_surface.get_viewport().set_input_as_handled()
	_request(action)
	return true

## The live-reading F9 owner has already consumed its one physical activation
## and acquired literal Pause custody. Reuse the same token and consent flow.
func request_load() -> Dictionary:
	if not _admitted(): return {"ok": false, "code": &"pause_load_unavailable"}
	_request("load")
	if not _pending_token.is_empty() and is_instance_valid(_confirmation):
		return {"ok": true, "value": {"opened": true}}
	return last_result.duplicate(true) if not last_result.get("ok", false) \
		else {"ok": false, "code": &"pause_load_unavailable"}

func _request(action: String) -> void:
	_source = _source_snapshot()
	var focus := _surface.get_viewport().gui_get_focus_owner()
	_return_focus = weakref(focus) if focus != null else null
	_return_host = _surface.entered_action
	_return_semantic = ""
	_focus_restore_pending = false
	var backup: Control = _surface._hosts.get(&"backup")
	if _return_host == &"backup" and is_instance_valid(backup) and focus != null and backup.is_ancestor_of(focus):
		_return_semantic = backup._saved_focus
	_in_operation = true
	var prepared: Dictionary = _port.prepare_quick_action(action)
	_in_operation = false
	last_result = prepared.duplicate(true)
	if not _admitted() or _source_snapshot() != _source:
		if prepared.get("ok", false): _port.cancel_action(str(prepared.value.token))
		return
	if not prepared.get("ok", false):
		_publish(str(prepared.get("status_key", "unavailable")), prepared.get("condition", {}), _source)
		return
	_pending_token = str(prepared.value.token)
	_condition = prepared.value.condition.duplicate(true)
	if action == "load":
		edge.clear_status()
		var shown: Dictionary = _surface.present_quick_confirmation(_load_copy(prepared.value.record), _confirm_load, _cancel_load)
		if shown.get("ok", false): _confirmation = shown.value.confirmation
		else: _cancel_load()
		return
	_commit("save")

func _confirm_load() -> void:
	_confirmation = null
	if not _base_admitted() or _source_snapshot() != _source or not _port.is_quick_condition_current(_condition):
		_cancel_load()
		return
	_commit("load")

func _commit(action: String) -> void:
	var token := _pending_token
	_pending_token = ""
	if token.is_empty(): return
	_in_operation = true
	var result: Dictionary = await _port.commit_action(token)
	_in_operation = false
	last_result = result.duplicate(true)
	if action == "load": load_finished.emit(result.duplicate(true))
	# Successful Load owns the destination tree. A compensated failure may own a
	# new suspension handle, so publish its refusal only on that current source.
	if action == "load" and result.get("ok", false): return
	if not is_inside_tree() or not _source_owned(): return
	if action == "save" and _source_snapshot() != _source: return
	if action == "load":
		var restored := _source_snapshot()
		if restored.get("scene_id") != _source.get("scene_id") or restored.get("source") != _source.get("source"): return
		_source = restored
	var now: Dictionary = _port.get_quick_capability(action)
	_publish("saved" if result.get("ok", false) else "unavailable", now.get("value", {}).get("condition", {}), _source_snapshot())
	if action == "load": _restore_focus()

func _cancel_pending() -> void:
	if not _pending_token.is_empty() and is_instance_valid(_port): _port.cancel_action(_pending_token)
	_pending_token = ""

func _cancel_load() -> void:
	_confirmation = null
	_cancel_pending()
	_restore_focus()
	load_cancelled.emit()

func _restore_focus() -> void:
	_focus_restore_pending = false
	if not _foreground:
		_focus_restore_pending = is_instance_valid(_surface) and _surface.is_visible_in_tree() and _source_snapshot() == _source
		return
	if not _base_admitted() or _source_snapshot() != _source: return
	var focus: Control = _return_focus.get_ref() as Control if _return_focus != null else null
	if is_instance_valid(focus) and not focus.is_queued_for_deletion() and focus.is_visible_in_tree() and focus.can_process() \
			and focus.get_focus_mode_with_override() != Control.FOCUS_NONE:
		focus.grab_focus()
		return
	var backup: Control = _surface._hosts.get(&"backup")
	if _return_host != &"backup" or _surface.entered_action != &"backup" \
			or not is_instance_valid(backup) or not backup.can_return_home(): return
	var replacement: Control
	if _return_semantic.begins_with("action:"):
		replacement = backup.action_buttons.get(_return_semantic.trim_prefix("action:"))
	elif _return_semantic.begins_with("mode:"):
		replacement = backup.mode_buttons.get(_return_semantic.trim_prefix("mode:"))
	elif _return_semantic == "information": replacement = backup.info_scroll
	if not is_instance_valid(replacement) or replacement.get_focus_mode_with_override() == Control.FOCUS_NONE:
		replacement = backup.drawer_buttons.get(backup.selected_locator)
	if is_instance_valid(replacement) and replacement.get_focus_mode_with_override() != Control.FOCUS_NONE:
		replacement.grab_focus()

func _publish(key: String, condition: Dictionary, source: Dictionary) -> void:
	if not is_instance_valid(edge): return
	var captured := condition.duplicate(true)
	var context := source.duplicate(true)
	edge.publish_status(StringName(key), {"condition": captured, "source": context}, func() -> bool:
		return is_instance_valid(_port) and _base_admitted() and _source_snapshot() == context \
			and (captured.is_empty() or _port.is_quick_condition_current(captured)))

func _process(delta: float) -> void:
	if not is_instance_valid(edge): return
	if _focus_restore_pending and _foreground: _restore_focus()
	var source := _source_snapshot()
	if source != _observed_source:
		_observed_source = source
		retain_contacts()
		if edge.current_binding.get("source", {}) != source: edge.clear_status()
	var admitted := _admitted()
	if admitted != _was_admitted:
		_was_admitted = admitted
		retain_contacts()
	_pending_poll += delta
	if not _pending_token.is_empty():
		var stale := not _base_admitted() or source != _source
		if _pending_poll >= 0.25:
			_pending_poll = 0.0
			stale = stale or not _port.is_quick_condition_current(_condition)
		if stale:
			_cancel_pending()
			if is_instance_valid(_confirmation): _confirmation._finish(false)
	var presentation := {"locale": _surface._locale, "percent": _surface._percent, "font": _surface._font_style, "theme": _surface.theme}
	if presentation != _presentation:
		_presentation = presentation
		edge.set_presentation(presentation.locale, presentation.percent, presentation.font)
		edge.theme = _surface.theme
	edge.set_eligible(admitted)

func _load_copy(record: Dictionary) -> Dictionary:
	var copy: Dictionary = COPY.get(_surface._locale, COPY.en)
	var fallback: bool = record.get("fallback", false)
	var day: Variant = record.get("load_day" if fallback else "day")
	var time: Variant = record.get("load_saved_time" if fallback else "saved_time")
	var stamp: String = copy.day.replace("{day}", str(day)).replace("{time}", str(time) if time != null else "--:--")
	var body: String = copy.fallback + "\n" + stamp if fallback else stamp
	body += "\n\n" + copy.replace_progress
	return {"title": copy.fallback_title if fallback else copy.load_title.replace("{record}", copy.quick),
		"body": body, "cancel": copy.cancel, "confirm": copy.load, "risk": "danger",
		"theme": BACKUP_THEME.build(_surface._locale, _surface._percent,
			&"midnight" if _surface._palette == "Midnight" else &"after_hours", _surface._day,
			_surface._high_contrast, _surface._colour_preset, _surface._font_style)}
