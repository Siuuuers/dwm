extends "res://scripts/ui/desktop/DesktopQuickCommands.gd"
## Active Dating host for the existing Quick input/token protocol. Physical saves
## and restores remain Backup-owned; admitted reading uses the same semantic
## checkpoint as Witnessed Save instead of a second Quick playhead.
const CAPTION := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")

var _bridge: Object
var _session_owner: Object
var _notice_caption: Node
var _status_layer: CanvasLayer

func configure_dating(scene: Control, port: Object, input_owner: Object, bridge: Object, session_owner: Object) -> bool:
	if not is_instance_valid(bridge) or not bridge.has_method("has_active_playback"): return false
	if not is_instance_valid(session_owner) or not session_owner.has_method("capture_live_session"): return false
	_bridge = bridge
	_session_owner = session_owner
	return configure(scene, port, input_owner, _source_is_current)

func _ready() -> void:
	if not _desktop.is_node_ready(): _desktop.ready.connect(_mount_status, CONNECT_ONE_SHOT)
	else: _mount_status()
	_desktop.visibility_changed.connect(retain_contacts)
	retain_contacts()

func _mount_status() -> void:
	_status_layer = CanvasLayer.new()
	# Below Witnessed recovery (3) and Pause (100); no focusable surface is added.
	_status_layer.layer = 2
	add_child(_status_layer)
	edge = EDGE.new()
	edge.name = "DatingQuickStatus"
	edge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_layer.add_child(edge)
	_refresh_edge()

func _source_is_current() -> bool:
	return is_instance_valid(_desktop) and is_inside_tree() and _desktop == get_tree().current_scene \
		and _desktop.scene_file_path == "res://scenes/dating/DatingScene.tscn"

func _source_snapshot() -> Dictionary:
	if not _source_is_current(): return {}
	var command: Dictionary = _desktop._presentation_command
	var session: Dictionary = _session_owner.capture_live_session()
	if not session.get("ok", false): return {}
	var board: Variant = _desktop._physical_view.get("board")
	var source := {"scene": _desktop.get_instance_id(), "command": str(command.get("physical_token", "")),
		"digest": str(command.get("command_sha256", "")), "phase": str(_desktop._physical_view.get("phase", "")),
		"narrative": _bridge.has_active_playback(), "session": session.value.duplicate(true),
		"revision": int(board.get("revision", -1)) if board is Dictionary else -1}
	if is_instance_valid(_notice_caption) and _notice_caption.canvas.is_visible_in_tree():
		source["caption"] = _notice_caption.get_instance_id()
		source["publication"] = _notice_caption._speech_generation
		source["recovery"] = _notice_caption.is_reading_recovery_active()
	return source

func _base_admitted() -> bool:
	return _foreground and _source_is_current() and _desktop.is_visible_in_tree() \
		and _desktop.can_process() and not get_tree().paused \
		and _input_owner.is_source_input_admitted() and not _source_snapshot().is_empty() \
		and (not is_instance_valid(_notice_caption) or not _notice_caption.is_reading_recovery_active())

func _admitted() -> bool:
	return _base_admitted() and not _in_operation and _pending_token.is_empty() \
		and not is_instance_valid(_desktop._confirmation) and not _desktop._split_dragging \
		and not _desktop._dispatching

func observe_input(event: InputEvent) -> void:
	# Resolve caption ownership only for a Quick press and retain the visible
	# result. Pointer motion must never turn into a whole-tree search.
	if not _bridge.has_active_playback(): _notice_caption = null
	elif not is_instance_valid(_notice_caption) or not _notice_caption.canvas.is_visible_in_tree():
		if event is InputEventKey or event is InputEventJoypadButton:
			for action: StringName in ACTIONS:
				if InputMap.has_action(action) and event.is_action_pressed(action, false, true):
					_notice_caption = _find_caption(get_tree().root)
					break
	super.observe_input(event)

func _find_caption(node: Node) -> Node:
	if node is Viewport and node != get_viewport(): return null
	if node.get_script() == CAPTION and node.canvas.is_visible_in_tree(): return node
	for child: Node in node.get_children():
		var found := _find_caption(child)
		if found != null: return found
	return null

func _request(action: String) -> void:
	if action == "save" and _bridge.has_method("has_reading_session") and _bridge.has_reading_session():
		# Only an activated Save may complete reveal. Background capability and
		# token/source checks retain the literal live frontier without mutation.
		var reading: Dictionary = _bridge.capture_reading_checkpoint(true)
		if not reading.get("ok", false):
			last_result = reading.duplicate(true)
			_publish("unavailable", {}, _source_snapshot())
			return
	_source = _source_snapshot()
	var focus := _desktop.get_viewport().gui_get_focus_owner()
	_return_focus = weakref(focus) if focus != null else null
	_focus_restore_pending = false
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
		var shown: Dictionary = _desktop.present_quick_confirmation(_load_copy(prepared.value.record), _confirm_load, _cancel_load)
		if not shown.get("ok", false): _cancel_load()
		return
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
	var result: Dictionary = await _port.commit_action(token)
	_in_operation = false
	last_result = result.duplicate(true)
	# The restore owner compensates failure. Only an unchanged live source may
	# reclaim its old focus; successful publication owns the destination itself.
	if result.get("ok", false) or not is_inside_tree() or not _base_admitted() or _source_snapshot() != _source: return
	_restore_focus()
	var now: Dictionary = _port.get_quick_capability("load")
	_publish("unavailable", now.get("value", {}).get("condition", {}), _source)

func blocks_gameplay() -> bool:
	return _in_operation or not _pending_token.is_empty() or is_instance_valid(_desktop._confirmation)

func _restore_focus() -> void:
	_focus_restore_pending = false
	if not _foreground:
		_focus_restore_pending = _source_snapshot() == _source
		return
	if not _base_admitted() or _source_snapshot() != _source: return
	var focus: Control = _return_focus.get_ref() as Control if _return_focus != null else null
	if is_instance_valid(focus) and not focus.is_queued_for_deletion() and focus.is_visible_in_tree() \
			and focus.can_process() and focus.get_focus_mode_with_override() != Control.FOCUS_NONE:
		focus.grab_focus()
	retain_contacts()

func _publish(key: String, condition: Dictionary, source: Dictionary) -> void:
	if not is_instance_valid(edge): return
	var captured := condition.duplicate(true)
	var context := source.duplicate(true)
	edge.publish_status(StringName(key), {"condition": captured, "source": context}, func() -> bool:
		return _base_admitted() and _source_snapshot() == context \
			and (captured.is_empty() or _port.is_quick_condition_current(captured)))
	_refresh_edge()

func _refresh_edge() -> void:
	if not is_instance_valid(edge): return
	var rect: Rect2 = _desktop.quick_status_safe_rect()
	var theme_owner: Control = _desktop.worksheet
	if _bridge.has_active_playback():
		rect = Rect2()
		if is_instance_valid(_notice_caption) and _notice_caption.canvas.is_visible_in_tree() \
				and not _notice_caption.is_reading_recovery_active() \
				and not _notice_caption._speech_status.is_visible_in_tree():
			# The caption already reserves this notice band above protected prose.
			rect = Rect2(24, int(CAPTION.FIELD_TOP[_notice_caption._text_percent]) - 64, 1232, 64)
			theme_owner = _notice_caption.canvas
	edge.position = rect.position
	edge.size = rect.size
	var presentation := {"locale": _desktop._locale, "percent": _desktop._percent,
		"font_style": _desktop._font_style, "theme": theme_owner.theme if is_instance_valid(theme_owner) else _desktop.theme}
	if _presentation != presentation:
		_presentation = presentation
		edge.set_presentation(presentation.locale, presentation.percent, presentation.font_style)
		edge.theme = presentation.theme
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
		"theme": BACKUP_THEME.build(_desktop._locale, _desktop._percent, _desktop._palette,
			int(_desktop._presentation_command.context.day), _desktop._high_contrast,
			_desktop._colour_preset, _desktop._font_style)}
