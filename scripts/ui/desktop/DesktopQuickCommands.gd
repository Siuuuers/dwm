extends Node
## Live desktop shortcut presentation; Backup owns target preparation and durability.
const EDGE := preload("res://scripts/ui/desktop/QuickStatusEdge.gd")
const BACKUP_COPY := preload("res://scripts/ui/BackupApp.gd").COPY
const BACKUP_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")
const ACTIONS := {&"game_quick_save": "save", &"game_quick_load": "load"}

var edge: Label
var last_result: Dictionary = {}
var _desktop: Control
var _port: Object
var _input_owner: Object
var _admission: Callable
var _contacts: Dictionary = {}
var _pending_token := ""
var _source: Dictionary = {}
var _condition: Dictionary = {}
var _return_focus: WeakRef
var _return_semantic := ""
var _observed_source: Dictionary = {}
var _in_operation := false
var _foreground := true
var _focus_restore_pending := false
var _was_admitted := false
var _presentation := {}
var _pending_poll := 0.0

func configure(desktop: Control, port: Object, input_owner: Object, admission: Callable) -> bool:
	if _desktop != null or not admission.is_valid() or admission.get_argument_count() != 0: return false
	for method: String in ["get_quick_capability", "prepare_quick_action", "is_quick_condition_current", "commit_action", "cancel_action"]:
		if not is_instance_valid(port) or not port.has_method(method): return false
	for method: String in ["get_physical_contacts", "get_physical_contact_id", "observe_physical_contact", "is_source_input_admitted"]:
		if not is_instance_valid(input_owner) or not input_owner.has_method(method): return false
	for event: String in ["input_bindings_changed", "source_input_custody_changed"]:
		if not input_owner.has_signal(event): return false
	_desktop = desktop
	_port = port
	_input_owner = input_owner
	_admission = admission
	_input_owner.input_bindings_changed.connect(retain_contacts)
	_input_owner.source_input_custody_changed.connect(retain_contacts)
	return true

func _ready() -> void:
	edge = EDGE.new()
	edge.name = "QuickStatus"
	edge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desktop.desktop_canvas.add_child.call_deferred(edge)
	_desktop.visibility_changed.connect(retain_contacts)
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
		# An out/in pair before the next frame still consumes its old consent.
		if not _pending_token.is_empty():
			_cancel_pending()
			if is_instance_valid(_desktop._confirmation): _desktop._confirmation._finish(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _foreground = true
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN,
			NOTIFICATION_DISABLED, NOTIFICATION_ENABLED, NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED]:
		retain_contacts()

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
	if Input.is_action_pressed(&"ui_accept"): return true
	_desktop.get_viewport().set_input_as_handled()
	_request(action)
	return true

func _source_snapshot() -> Dictionary:
	if not is_instance_valid(_desktop) or _desktop._host_state == null: return {}
	var host: Dictionary = _desktop._host_state.get_state()
	if int(host.get("current_day", 0)) != _desktop._day: return {}
	var active: String = str(host.get("active_app_id")) if host.get("active_app_id") != null else ""
	if active != String(_desktop._active_id): return {}
	return {"day": _desktop._day, "app": active, "desktop": _desktop.get_instance_id()}

static func _focus_custody_enabled(control: Control) -> bool:
	# The desktop itself is not focusable. Resolve inherited custody separately
	# from focus_mode, honoring the closest explicit recursive override.
	var current := control
	while current != null:
		if current.focus_behavior_recursive != Control.FOCUS_BEHAVIOR_INHERITED:
			return current.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_ENABLED
		current = current.get_parent_control()
	return true

func _base_admitted() -> bool:
	return (_foreground and is_instance_valid(_desktop) and _desktop.is_inside_tree() and _desktop.is_visible_in_tree()
		and _desktop.can_process() and _focus_custody_enabled(_desktop) and _desktop._foreground_eligible and not _desktop._restoration_failed
		and is_instance_valid(_input_owner) and _input_owner.is_source_input_admitted()
		and _admission.is_valid() and _admission.call() == true and not _source_snapshot().is_empty())

func _admitted() -> bool:
	if not _base_admitted() or _in_operation or not _pending_token.is_empty() or is_instance_valid(_desktop._confirmation): return false
	var app: Node = _desktop._cached_app_windows.get(_desktop._active_id)
	return not is_instance_valid(app) or not app.has_method("can_return_home") or app.can_return_home()

func _request(action: String) -> void:
	_in_operation = true
	_source = _source_snapshot()
	var focus := _desktop.get_viewport().gui_get_focus_owner()
	_return_focus = weakref(focus) if focus != null else null
	_return_semantic = ""
	_focus_restore_pending = false
	var app: Node = _desktop._cached_app_windows.get(&"backup")
	if _desktop._active_id == &"backup" and is_instance_valid(app) and focus != null and app.is_ancestor_of(focus):
		_return_semantic = app._saved_focus
	var prepared: Dictionary = _port.prepare_quick_action(action)
	_in_operation = false
	last_result = prepared.duplicate(true)
	if not _admitted() or _source_snapshot() != _source:
		if prepared.get("ok", false): _port.cancel_action(str(prepared.value.token))
		return
	if not prepared.get("ok", false):
		_publish(str(prepared.get("status_key", "unavailable")), prepared.get("condition", {}), _source)
		return
	var value: Dictionary = prepared.value
	_pending_token = str(value.token)
	_condition = value.condition.duplicate(true)
	if action == "load":
		edge.clear_status()
		var shown: Dictionary = _desktop.present_confirmation(_load_copy(value.record), _confirm_load, _cancel_load)
		if not shown.get("ok", false): _cancel_load()
		return
	# Production commit is synchronous: no fabricated Saving frame or focus move.
	var token := _pending_token
	_pending_token = ""
	_in_operation = true
	var result: Dictionary = _port.commit_action(token)
	_in_operation = false
	last_result = result.duplicate(true)
	if not is_inside_tree() or not _base_admitted() or _source_snapshot() != _source: return
	var now: Dictionary = _port.get_quick_capability("save")
	_publish("saved" if result.get("ok", false) else "unavailable", now.get("value", {}).get("condition", {}), _source)

func _confirm_load() -> void:
	var token := _pending_token
	_pending_token = ""
	if token.is_empty(): return
	if not _base_admitted() or _source_snapshot() != _source or not _port.is_quick_condition_current(_condition):
		_port.cancel_action(token)
		_restore_focus()
		return
	_in_operation = true
	var result: Dictionary = _port.commit_action(token)
	_in_operation = false
	last_result = result.duplicate(true)
	# Successful restore owns scene replacement and focus. Never touch its new tree.
	if result.get("ok", false) or not is_inside_tree() or not _base_admitted(): return
	_restore_focus()
	var now: Dictionary = _port.get_quick_capability("load")
	_publish("unavailable", now.get("value", {}).get("condition", {}), _source)

func _cancel_pending() -> void:
	if not _pending_token.is_empty() and is_instance_valid(_port): _port.cancel_action(_pending_token)
	_pending_token = ""

func _cancel_load() -> void:
	_cancel_pending()
	_restore_focus()

func _restore_focus() -> void:
	_focus_restore_pending = false
	if not _foreground:
		_focus_restore_pending = is_instance_valid(_desktop) and _source_snapshot() == _source
		return
	if not _base_admitted() or _source_snapshot() != _source: return
	var focus: Control = _return_focus.get_ref() as Control if _return_focus != null else null
	if (is_instance_valid(focus) and not focus.is_queued_for_deletion() and focus.is_visible_in_tree() and focus.can_process()
		and focus.get_focus_mode_with_override() != Control.FOCUS_NONE):
		focus.grab_focus()
		return
	var app: Node = _desktop._cached_app_windows.get(&"backup")
	if _source.app == "backup" and is_instance_valid(app) and app.can_return_home():
		var replacement: Control
		if _return_semantic.begins_with("action:"):
			replacement = app.action_buttons.get(_return_semantic.trim_prefix("action:"))
		elif _return_semantic.begins_with("mode:"):
			replacement = app.mode_buttons.get(_return_semantic.trim_prefix("mode:"))
		elif _return_semantic == "information": replacement = app.info_scroll
		if not is_instance_valid(replacement) or replacement.get_focus_mode_with_override() == Control.FOCUS_NONE:
			replacement = app.drawer_buttons.get(app.selected_locator)
		if is_instance_valid(replacement) and replacement.get_focus_mode_with_override() != Control.FOCUS_NONE: replacement.grab_focus()

func _publish(key: String, condition: Dictionary, source: Dictionary) -> void:
	if condition.is_empty() or not is_instance_valid(edge): return
	_refresh_edge()
	var captured := condition.duplicate(true)
	var context := source.duplicate(true)
	edge.publish_status(StringName(key), {"condition": captured, "source": context}, func() -> bool:
		return is_instance_valid(_port) and _source_snapshot() == context and _port.is_quick_condition_current(captured))

func _process(delta: float) -> void:
	if not is_instance_valid(edge) or not edge.is_inside_tree(): return
	if _focus_restore_pending and _foreground: _restore_focus()
	var current_source := _source_snapshot()
	if current_source != _observed_source:
		_observed_source = current_source
		retain_contacts()
		if edge.current_binding.get("source", {}) != current_source: edge.clear_status()
	var admitted := _admitted()
	if admitted != _was_admitted:
		retain_contacts()
		_was_admitted = admitted
	_pending_poll += delta
	if not _pending_token.is_empty():
		var stale := not _base_admitted() or _source_snapshot() != _source
		if _pending_poll >= 0.25:
			_pending_poll = 0.0
			stale = stale or not _port.is_quick_condition_current(_condition)
		if stale:
			_cancel_pending()
			if is_instance_valid(_desktop._confirmation): _desktop._confirmation._finish(false)
	_refresh_edge()

func _refresh_edge() -> void:
	var rect: Rect2 = _desktop.quick_status_safe_rect()
	edge.position = rect.position
	edge.size = rect.size
	var presentation := {"locale": _desktop._locale, "percent": _desktop._percent, "font_style": _desktop._font_style, "theme": _desktop.theme}
	if _presentation != presentation:
		_presentation = presentation
		edge.set_presentation(presentation.locale, presentation.percent, presentation.font_style)
		edge.theme = _desktop.theme
	edge.set_eligible(_admitted() and rect.has_area())

func _load_copy(record: Dictionary) -> Dictionary:
	var copy: Dictionary = BACKUP_COPY.get(_desktop._locale, BACKUP_COPY.en)
	var fallback: bool = record.get("fallback", false)
	var day: Variant = record.get("load_day" if fallback else "day")
	var time: Variant = record.get("load_saved_time" if fallback else "saved_time")
	var stamp: String = copy.day.replace("{day}", str(day)).replace("{time}", str(time) if time != null else "--:--")
	var body: String = copy.fallback + "\n" + stamp if fallback else stamp
	body += "\n\n" + copy.replace_progress
	return {"title": copy.fallback_title if fallback else copy.load_title.replace("{record}", copy.quick),
		"body": body, "cancel": copy.cancel, "confirm": copy.load, "risk": "danger",
		"theme": BACKUP_THEME.build(_desktop._locale, _desktop._percent, &"after_hours", 1, false, "standard", _desktop._font_style)}
