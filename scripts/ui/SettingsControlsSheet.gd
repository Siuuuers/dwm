extends VBoxContainer
## Settings presentation only. ProfileManager owns proposals and atomic publication.

const REGISTRY := preload("res://scripts/settings/ControlsActionRegistry.gd")
const CAPTURE := preload("res://scripts/settings/ControlsCaptureSession.gd")
const PRESENTATION := preload("res://scripts/ui/SettingsTheme.gd")
const RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const LEGACY := preload("res://scripts/settings/ControlsLegacyPresentation.gd")
const POSITIONS := {
	JOY_BUTTON_X: "west", JOY_BUTTON_Y: "north",
	JOY_BUTTON_LEFT_STICK: "left_stick", JOY_BUTTON_RIGHT_STICK: "right_stick",
	JOY_BUTTON_MISC1: "auxiliary", JOY_BUTTON_PADDLE1: "paddle_1",
	JOY_BUTTON_PADDLE2: "paddle_2", JOY_BUTTON_PADDLE3: "paddle_3",
	JOY_BUTTON_PADDLE4: "paddle_4", JOY_BUTTON_TOUCHPAD: "touchpad",
}

class InputDialog extends ConfirmationDialog:
	var input_receiver: Callable
	func _input(event: InputEvent) -> void:
		if visible and input_receiver.is_valid():
			input_receiver.call(event)

var capture_dialog: ConfirmationDialog
var conflict_dialog: ConfirmationDialog
var original_dialog: ConfirmationDialog
var import_dialog: ConfirmationDialog
var review_button: Button
var original_button: Button
var apply_review_button: Button
var cancel_review_button: Button
var _content: Control
var _profile: Object
var _buttons: Dictionary = {}
var _headers: Dictionary = {}
var _slot_labels: Array[Label] = []
var _status: Label
var _status_key := ""
var _conflict_scroll: ScrollContainer
var _conflict_rows: VBoxContainer
var _session: RefCounted
var _source: Button
var _action := ""
var _slot := ""
var _proposal: Dictionary = {}
var _release_event: InputEvent
var _release_result: Dictionary = {}
var _held: Dictionary = {}
var _last_activation: InputEvent
var _opening_activation: InputEvent
var _activation_released := false
var _own_depart_pending := false
var _generation := 0
var _font_size := 24
var _large_targets := false
var _controller_mapped: Callable
var _suppressed_events: Dictionary = {}
var _pending_source: Button
var _opening_capture := false
var _review: Dictionary = {}
var _review_draft: Dictionary = {}
var _proposal_kind: StringName = &"profile"
var _import_proposal: Dictionary = {}
var _original_rows: VBoxContainer
var _import_rows: VBoxContainer
var _review_buttons: Array[Button] = []
var _review_scrolls: Array[ScrollContainer] = []
var _original_source: Dictionary = {}


func configure(content: Control, profile: Object, controller_mapped: Callable = Callable()) -> void:
	if not is_node_ready():
		_content = content
		_profile = profile
		_controller_mapped = controller_mapped


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status = _label()
	_status.name = "ControlsStatus"
	add_child(_status)
	review_button = _review_button("ReviewImportedBindings", begin_import_review)
	original_button = _review_button("OriginalBindings", show_original_bindings)
	apply_review_button = _review_button("ApplyReviewedBindings", confirm_import_review)
	cancel_review_button = _review_button("CancelBindingReview", cancel_import_review)
	for record: Dictionary in REGISTRY.records():
		var action := String(record.id)
		var section := VBoxContainer.new()
		section.name = action.to_pascal_case() + "Bindings"
		section.add_theme_constant_override("separation", 8)
		add_child(section)
		var header := _label()
		_headers[action] = header
		section.add_child(header)
		var slots := HBoxContainer.new()
		slots.add_theme_constant_override("separation", 16)
		section.add_child(slots)
		for slot: String in ["keyboard", "controller"]:
			var column := VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slots.add_child(column)
			var slot_label := _label()
			slot_label.set_meta("controls_slot", slot)
			_slot_labels.append(slot_label)
			column.add_child(slot_label)
			var button := Button.new()
			button.name = action.to_pascal_case() + slot.to_pascal_case()
			button.clip_text = true
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var caption := _label()
			caption.name = "BindingCaption"
			caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			caption.offset_left = 12
			caption.offset_top = 8
			caption.offset_right = -12
			caption.offset_bottom = -8
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			button.add_child(caption)
			column.add_child(button)
			_buttons[action + "/" + slot] = button
			PRESENTATION.attach_state(button)
			button.pressed.connect(func() -> void: begin_capture(action, slot))
			button.focus_entered.connect(_reveal.bind(button))
	capture_dialog = _dialog("ControlsCapture")
	capture_dialog.input_receiver = _capture_input
	capture_dialog.get_ok_button().hide()
	capture_dialog.canceled.connect(_cancel_and_restore)
	capture_dialog.close_requested.connect(_cancel_and_restore)
	conflict_dialog = _dialog("ControlsConflict")
	conflict_dialog.input_receiver = _conflict_input
	conflict_dialog.confirmed.connect(_commit_proposal)
	conflict_dialog.canceled.connect(_cancel_and_restore)
	conflict_dialog.close_requested.connect(_cancel_and_restore)
	conflict_dialog.get_label().hide()
	_conflict_scroll = ScrollContainer.new()
	_conflict_scroll.name = "ConflictReview"
	_conflict_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_conflict_scroll.custom_minimum_size = Vector2(672, 320)
	conflict_dialog.add_child(_conflict_scroll)
	_conflict_rows = VBoxContainer.new()
	_conflict_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conflict_rows.add_theme_constant_override("separation", 16)
	_conflict_scroll.add_child(_conflict_rows)
	original_dialog = _dialog("OriginalBindingsReview")
	original_dialog.input_receiver = _confirmation_input.bind(original_dialog, &"cancelled")
	original_dialog.get_ok_button().hide()
	original_dialog.canceled.connect(_cancel_and_restore)
	original_dialog.close_requested.connect(_cancel_and_restore)
	_original_rows = _review_body(original_dialog)
	import_dialog = _dialog("ApplyBindingReview")
	import_dialog.input_receiver = _confirmation_input.bind(import_dialog, &"apply_import")
	import_dialog.confirmed.connect(_apply_import)
	import_dialog.canceled.connect(_cancel_and_restore)
	import_dialog.close_requested.connect(_cancel_and_restore)
	_import_rows = _review_body(import_dialog)
	visibility_changed.connect(_on_visibility_changed)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if _profile != null and _profile.has_signal("controls_bindings_changed"):
		_profile.controls_bindings_changed.connect(refresh)
	var source_theme: Theme = _content.theme
	if source_theme == null:
		source_theme = PRESENTATION.build(_content.current_locale(), 100)
	set_presentation(source_theme, source_theme.default_font_size, false)
	refresh()


func _label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _review_button(node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.clip_text = true
	var caption := _label()
	caption.name = "BindingCaption"
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_left = 12
	caption.offset_right = -12
	caption.offset_top = 8
	caption.offset_bottom = -8
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(caption)
	add_child(button)
	PRESENTATION.attach_state(button)
	button.pressed.connect(action)
	button.focus_entered.connect(_reveal.bind(button))
	_review_buttons.append(button)
	return button


func _review_body(dialog: ConfirmationDialog) -> VBoxContainer:
	dialog.get_label().hide()
	var scroll := ScrollContainer.new()
	scroll.name = "ReviewScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(672, 320)
	dialog.add_child(scroll)
	_review_scrolls.append(scroll)
	var body := VBoxContainer.new()
	body.name = "ReviewRows"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	return body


func _dialog(node_name: String) -> InputDialog:
	var dialog := InputDialog.new()
	dialog.name = node_name
	dialog.exclusive = true
	dialog.unresizable = true
	dialog.dialog_autowrap = true
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(dialog)
	for button: Button in [dialog.get_cancel_button(), dialog.get_ok_button()]:
		PRESENTATION.attach_state(button, true)
	return dialog


func button_for(action: String, slot: String) -> Button:
	return _buttons.get(action + "/" + slot)


func refresh() -> void:
	if _status == null:
		return
	var result: Dictionary = _profile.get_controls_binding_snapshot() if _profile != null and _profile.has_method("get_controls_binding_snapshot") else {"ok": false}
	var value: Dictionary = result.get("value", {}) if result.get("value", {}) is Dictionary else {}
	var unavailable: bool = not result.get("ok", false)
	var pending: bool = value.get("import_pending", false)
	if is_reviewing_import() and not pending:
		depart()
	var bindings: Dictionary = _review_draft if is_reviewing_import() else value.get("bindings", {})
	for record: Dictionary in REGISTRY.records():
		var action := String(record.id)
		_headers[action].text = _action_label(action)
		for slot: String in ["keyboard", "controller"]:
			var button := button_for(action, slot)
			var binding: Dictionary = bindings.get(action, {}).get(slot, {})
			button.text = _binding_label(binding)
			button.get_node("BindingCaption").text = button.text
			button.accessibility_name = "%s, %s, %s" % [_action_label(action), _text("settings.controls." + slot), button.text]
			button.disabled = unavailable or (pending and not is_reviewing_import())
			_style_button(button)
	for label: Label in _slot_labels:
		label.text = _text("settings.controls." + String(label.get_meta("controls_slot")))
	_status.text = _text("settings.controls.review_draft") if is_reviewing_import() else (_text("settings.controls.pending_import") if pending else (_text("settings.status.unavailable") if unavailable else ""))
	if not _status_key.is_empty():
		_status.text += ("\n" if not _status.text.is_empty() else "") + _text(_status_key)
	_status.visible = not _status.text.is_empty()
	capture_dialog.title = _text("settings.controls.capture")
	capture_dialog.get_cancel_button().text = _text("settings.cancel")
	conflict_dialog.title = _text("settings.controls.conflict")
	conflict_dialog.get_cancel_button().text = _text("settings.cancel")
	conflict_dialog.get_ok_button().text = _text("settings.controls.swap")
	var keys := ["settings.controls.review_import", "settings.controls.original_bindings", "settings.controls.review_apply", "settings.cancel"]
	for index: int in range(_review_buttons.size()):
		var button := _review_buttons[index]
		button.text = _text(keys[index])
		button.get_node("BindingCaption").text = button.text
		button.accessibility_name = button.text
		_style_button(button, 456)
	review_button.visible = pending and not is_reviewing_import()
	original_button.visible = pending
	apply_review_button.visible = is_reviewing_import()
	cancel_review_button.visible = is_reviewing_import()
	original_dialog.title = _text("settings.controls.original_bindings")
	original_dialog.get_cancel_button().text = _text("settings.cancel")
	import_dialog.title = _text("settings.controls.review_apply_title")
	import_dialog.get_ok_button().text = _text("settings.controls.review_apply")
	import_dialog.get_cancel_button().text = _text("settings.cancel")
	if capture_dialog.visible:
		_refresh_capture_copy()
	if not _proposal.is_empty():
		_render_proposal()
	if import_dialog.visible:
		_render_import()
	if original_dialog.visible:
		_render_original(_original_source)


func set_presentation(source_theme: Theme, font_size: int, large_targets: bool) -> void:
	theme = source_theme
	_font_size = font_size
	_large_targets = large_targets
	if _status == null or capture_dialog == null:
		return
	for button: Button in _buttons.values():
		_style_button(button)
	for dialog: ConfirmationDialog in [capture_dialog, conflict_dialog, original_dialog, import_dialog]:
		dialog.theme = PRESENTATION.confirmation_theme(source_theme, font_size, large_targets)
		dialog.get_label().add_theme_font_size_override("font_size", font_size)
		dialog.get_label().add_theme_font_override("font", dialog.theme.default_font)
	PRESENTATION.apply_scroll(_conflict_scroll, true)
	for scroll: ScrollContainer in _review_scrolls:
		PRESENTATION.apply_scroll(scroll, true)
	refresh()


func _style_button(button: Button, text_width: int = 216) -> void:
	var roles := PRESENTATION.roles_for(button)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var caption: Label = button.get_node("BindingCaption")
	caption.add_theme_color_override("font_color", roles.paper_ink)
	caption.add_theme_font_size_override("font_size", _font_size)
	var height := theme.default_font.get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, _font_size).y
	button.custom_minimum_size.y = maxf(64 if _large_targets else 48, height + 16)


func begin_capture(action: String, slot: String, activation: InputEvent = null) -> void:
	var button := button_for(action, slot)
	if not _lawful() or button == null or button.disabled or _content.get_controller().is_commit_pending() \
			or _opening_capture or _session != null or _modal_visible():
		return
	_generation += 1
	var generation := _generation
	_source = button
	_opening_capture = true
	_opening_activation = activation if activation != null else (_last_activation if _held.has(_identity(_last_activation)) else null)
	_activation_released = false
	# Controller.depart calls this component synchronously once. Later departures
	# during physical sample cleanup invalidate this request normally.
	_own_depart_pending = true
	await _content.get_controller().depart()
	if generation != _generation or not _lawful():
		return
	_own_depart_pending = false
	_opening_capture = false
	_source = button
	_action = action
	_slot = slot
	_proposal.clear()
	_session = CAPTURE.new()
	var held_events: Array[InputEvent] = []
	for event: InputEvent in _held.values():
		held_events.append(event)
	_session.begin(action, slot, null if _activation_released else _opening_activation, held_events)
	_opening_activation = null
	_refresh_capture_copy()
	capture_dialog.popup_centered(Vector2i(720, 240))
	capture_dialog.get_cancel_button().grab_focus()


func _refresh_capture_copy() -> void:
	capture_dialog.dialog_text = _action_label(_action) + "\n" + _text("settings.controls." + _slot) + "\n\n" + _text("settings.controls.release" if _release_event != null else "settings.controls.capture_" + _slot)


func _input(event: InputEvent) -> void:
	var suppress: bool = _suppressed_events.has(_identity(event))
	_track(event)
	if suppress:
		get_viewport().set_input_as_handled()


func _track(event: InputEvent) -> void:
	var id := _identity(event)
	if id.is_empty():
		return
	if event.pressed:
		if not event is InputEventKey or not event.echo:
			_held[id] = event.duplicate()
			_last_activation = event.duplicate()
	else:
		_held.erase(id)
		_suppressed_events.erase(id)
		if _opening_activation != null and id == _identity(_opening_activation):
			_activation_released = true


func _capture_input(event: InputEvent) -> void:
	var suppress: bool = _suppressed_events.has(_identity(event))
	_track(event)
	if suppress:
		capture_dialog.set_input_as_handled()
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# The only pointer destination in this exclusive window is Cancel.
		return
	capture_dialog.set_input_as_handled()
	if _release_event != null:
		_retire_on_back(event)
		_finish_release(event)
		return
	if _session == null or not _session.is_active():
		return
	if event is InputEventJoypadButton and event.button_index != JOY_BUTTON_B and not _is_controller_mapped(event.device):
		capture_dialog.dialog_text = _text("settings.controls.unsupported")
		return
	var result: Dictionary = _session.handle_event(event)
	if result.state in [&"captured", &"cancelled"]:
		_release_event = event.duplicate()
		_release_result = result
		_refresh_capture_copy()
	elif result.code in [&"unsupported_key", &"unsupported_button", &"invalid_capture_device"]:
		capture_dialog.dialog_text = _text("settings.controls.unsupported")


func _finish_release(event: InputEvent) -> void:
	if _identity(event) != _identity(_release_event) or event.pressed:
		return
	var result := _release_result
	_release_event = null
	_release_result = {}
	if result.get("state") == &"captured":
		_propose(result.binding)
	elif result.get("state") == &"swap":
		_commit_proposal()
	elif result.get("state") == &"apply_import":
		_apply_import()
	else:
		_cancel_and_restore()


func _propose(binding: Dictionary) -> void:
	if not _lawful():
		depart()
		return
	_proposal_kind = &"draft" if is_reviewing_import() else &"profile"
	var result: Dictionary = RULES.propose(_review_draft, _action, _slot, binding, _review.revision) if _proposal_kind == &"draft" else _profile.prepare_controls_change(_action, _slot, binding)
	if not result.get("ok", false):
		_status_key = _failure_key(result.get("code", &""))
		_cancel_and_restore()
		return
	_proposal = result.value.duplicate(true)
	capture_dialog.hide()
	if _proposal.operation == &"rebind" and _proposal.can_commit:
		_commit_proposal()
	else:
		_render_proposal()
		conflict_dialog.popup_centered(Vector2i(720, 480))
		conflict_dialog.get_cancel_button().grab_focus()


func _render_proposal() -> void:
	for child: Node in _conflict_rows.get_children():
		_conflict_rows.remove_child(child)
		child.queue_free()
	var hint := _label()
	hint.text = _text("settings.controls.review_scroll")
	_conflict_rows.add_child(hint)
	var affected: Array = [_proposal.action]
	affected.append_array(_proposal.conflicts)
	for action: String in affected:
		var label := _label()
		label.text = "%s\n%s: %s\n%s: %s" % [
			_action_label(action), _text("settings.controls.before"),
			_binding_label(_proposal.before[action][_proposal.slot]),
			_text("settings.controls.after"), _binding_label(_proposal.after[action][_proposal.slot]),
		]
		_conflict_rows.add_child(label)
	conflict_dialog.get_ok_button().disabled = not _proposal.can_commit
	if not _proposal.can_commit:
		var reason := _label()
		reason.text = _text("settings.controls.swap_unavailable")
		_conflict_rows.add_child(reason)


func _conflict_input(event: InputEvent) -> void:
	_confirmation_input(event, conflict_dialog, &"swap")


func _confirmation_input(event: InputEvent, dialog: ConfirmationDialog, accept_state: StringName) -> void:
	var suppress: bool = _suppressed_events.has(_identity(event))
	_track(event)
	if suppress:
		dialog.set_input_as_handled()
		return
	if not event is InputEventKey and not event is InputEventJoypadButton:
		return
	if _release_event != null:
		dialog.set_input_as_handled()
		_retire_on_back(event)
		_finish_release(event)
		return
	if _scroll_review(event, dialog):
		dialog.set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		dialog.set_input_as_handled()
		if event is InputEventKey and event.echo:
			return
		var accept: bool = event.is_action_pressed("ui_accept") and dialog.gui_get_focus_owner() == dialog.get_ok_button() and not dialog.get_ok_button().disabled
		_release_event = event.duplicate()
		_release_result = {"state": accept_state if accept else &"cancelled"}


func _scroll_review(event: InputEvent, dialog: ConfirmationDialog) -> bool:
	var scroll: ScrollContainer = _conflict_scroll if dialog == conflict_dialog else dialog.get_node_or_null("ReviewScroll")
	if scroll == null:
		return false
	var delta := 0
	if event.is_action_pressed("ui_down", true):
		delta = _font_size * 2
	elif event.is_action_pressed("ui_up", true):
		delta = -_font_size * 2
	elif event is InputEventKey and event.pressed:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_PAGEDOWN:
			delta = maxi(1, int(scroll.size.y) - _font_size * 2)
		elif key == KEY_PAGEUP:
			delta = -maxi(1, int(scroll.size.y) - _font_size * 2)
	if delta == 0:
		return false
	scroll.scroll_vertical += delta
	return true


func _retire_on_back(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (not event is InputEventKey or not event.echo):
		_release_result = {"state": &"cancelled"}
		_suppressed_events[_identity(event)] = true


func _commit_proposal() -> void:
	if _proposal.is_empty() or not _proposal.get("can_commit", false) or not _lawful():
		return
	var proposal := _proposal.duplicate(true)
	_proposal.clear() # One consent can make only one owner request.
	if _proposal_kind == &"draft":
		if not is_reviewing_import() or proposal.before != _review_draft:
			_status_key = "settings.controls.stale"
		else:
			_review_draft = proposal.after.duplicate(true)
			_status_key = ""
		_cancel_and_restore()
		return
	var result: Dictionary = _profile.commit_controls_change(proposal)
	_status_key = "settings.controls.applied" if result.get("ok", false) else _failure_key(result.get("code", &""))
	_cancel_and_restore()


func _cancel_and_restore() -> void:
	var source := _source
	depart(true)
	refresh()
	if source != null:
		call_deferred("_restore_focus", source, _generation)


func depart(preserve_review: bool = false) -> void:
	var keep_review := preserve_review or _own_depart_pending
	if _own_depart_pending:
		_own_depart_pending = false
	else:
		_generation += 1
		if is_instance_valid(_source) and (_opening_capture or _session != null or not _proposal.is_empty()):
			_pending_source = _source
		_opening_capture = false
	if _session != null and _session.is_active():
		_session.cancel(&"departure")
	_session = null
	if _release_event != null:
		_suppressed_events[_identity(_release_event)] = true
	_release_event = null
	_release_result.clear()
	_proposal.clear()
	if is_instance_valid(capture_dialog):
		capture_dialog.hide()
	if is_instance_valid(conflict_dialog):
		conflict_dialog.hide()
	if is_instance_valid(original_dialog):
		original_dialog.hide()
	if is_instance_valid(import_dialog):
		import_dialog.hide()
	_import_proposal.clear()
	_original_source.clear()
	if not keep_review:
		_review.clear()
		_review_draft.clear()
		if is_node_ready():
			refresh()


func handle_back() -> bool:
	if is_instance_valid(capture_dialog) and _modal_visible():
		_cancel_and_restore()
		return true
	if is_reviewing_import():
		cancel_import_review()
		return true
	return false


func _restore_focus(source: Button, generation: int) -> void:
	if generation == _generation and is_instance_valid(source):
		_pending_source = source
		restore_pending_focus()


func restore_pending_focus() -> bool:
	if not is_instance_valid(_pending_source) or not _lawful() or not _pending_source.is_visible_in_tree() or _pending_source.disabled \
			or _opening_capture or _modal_visible():
		return false
	var source := _pending_source
	_pending_source = null
	source.grab_focus()
	_reveal(source)
	return true


func _reveal(button: Button) -> void:
	if _content != null and _content.has_method("_ensure_focus_visible"):
		_content._ensure_focus_visible(_content.sheet_scroll, button)


func _lawful() -> bool:
	return is_inside_tree() and is_visible_in_tree() and _content != null and _content.is_interaction_enabled()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		depart()
	else:
		call_deferred("restore_pending_focus")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		depart()
		_held.clear()
		_suppressed_events.clear()
		_last_activation = null
		_opening_activation = null
		_activation_released = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		call_deferred("restore_pending_focus")


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	if _opening_capture and _opening_activation is InputEventJoypadButton and _opening_activation.device == device:
		_cancel_and_restore()
	elif _release_event is InputEventJoypadButton and _release_event.device == device:
		_cancel_and_restore()
	elif _session != null and _session.is_active():
		if _session.disconnect_device(device).state == &"cancelled":
			_cancel_and_restore()
	# Disconnect retires this physical device's contacts: no release can arrive.
	# A future device reusing its index must start with fresh capture identity.
	var prefix := "joy:%d:" % device
	for identity: String in _held.keys():
		if identity.begins_with(prefix): _held.erase(identity)
	for identity: String in _suppressed_events.keys():
		if identity.begins_with(prefix): _suppressed_events.erase(identity)
	if _last_activation is InputEventJoypadButton and _last_activation.device == device:
		_last_activation = null
	if _opening_activation is InputEventJoypadButton and _opening_activation.device == device:
		_opening_activation = null
		_activation_released = true


func is_reviewing_import() -> bool:
	return not _review.is_empty()


func get_review_draft() -> Dictionary:
	return _review_draft.duplicate(true)


func _modal_visible() -> bool:
	for dialog: ConfirmationDialog in [capture_dialog, conflict_dialog, original_dialog, import_dialog]:
		if is_instance_valid(dialog) and dialog.visible:
			return true
	return false


func begin_import_review() -> void:
	if not _lawful() or _modal_visible() or _opening_capture or is_reviewing_import() or _content.get_controller().is_commit_pending():
		return
	var result: Dictionary = _profile.get_controls_import_review()
	if not result.get("ok", false):
		_status_key = _failure_key(result.get("code", &""))
		refresh()
		return
	_review = result.value.duplicate(true)
	# Original records are evidence, never an implicit conflict winner. This
	# explicitly labelled draft starts from registered defaults even if a pending
	# profile happened to retain a different legal inactive map.
	_review_draft = RULES.defaults()
	_status_key = ""
	refresh()
	_source = button_for("game_quick_save", "keyboard")
	call_deferred("_restore_focus", _source, _generation)


func cancel_import_review() -> void:
	if not is_reviewing_import():
		return
	depart()
	_source = review_button
	_status_key = ""
	refresh()
	call_deferred("_restore_focus", review_button, _generation)


func show_original_bindings() -> void:
	if not _lawful() or _modal_visible() or _opening_capture or _content.get_controller().is_commit_pending():
		return
	var result: Dictionary = {"ok": true, "value": _review} if is_reviewing_import() else _profile.get_controls_import_review()
	if not result.get("ok", false):
		_status_key = _failure_key(result.get("code", &""))
		refresh()
		return
	_source = original_button
	_original_source = result.value.legacy_bindings.duplicate(true)
	_render_original(_original_source)
	original_dialog.popup_centered(Vector2i(720, 480))
	original_dialog.get_cancel_button().grab_focus()


func _render_original(legacy: Dictionary) -> void:
	_clear_rows(_original_rows)
	var legend := _label()
	legend.text = _text("settings.controls.original_legend") + "\n" + _text("settings.controls.review_scroll")
	_original_rows.add_child(legend)
	for record: Dictionary in LEGACY.rows(legacy, _content.current_locale(), _text):
		var label := _label()
		label.set_meta("controls_legacy_action", record.action_id)
		label.text = record.label + (" · " + _text("settings.controls.retired") if record.retired else "") + "\n" + "\n".join(record.bindings)
		_original_rows.add_child(label)


func confirm_import_review() -> void:
	if not is_reviewing_import() or not _lawful() or _modal_visible() or _opening_capture or _content.get_controller().is_commit_pending():
		return
	var result: Dictionary = _profile.prepare_controls_import(_review_draft, _review.revision)
	if not result.get("ok", false):
		_status_key = _failure_key(result.get("code", &""))
		if result.get("code") in [&"profile_revision_changed", &"controls_import_not_pending"]:
			depart()
		refresh()
		return
	_import_proposal = result.value.duplicate(true)
	_source = apply_review_button
	_render_import()
	import_dialog.popup_centered(Vector2i(720, 480))
	import_dialog.get_cancel_button().grab_focus()


func _render_import() -> void:
	if _import_proposal.is_empty():
		return
	_clear_rows(_import_rows)
	var intro := _label()
	intro.text = _text("settings.controls.review_apply_body") + "\n" + _text("settings.controls.review_scroll")
	_import_rows.add_child(intro)
	for record: Dictionary in REGISTRY.records():
		var action := String(record.id)
		var label := _label()
		label.set_meta("controls_review_action", action)
		label.text = "%s\n%s: %s\n%s: %s" % [
			_action_label(action), _text("settings.controls.keyboard"),
			_binding_label(_import_proposal.after[action].keyboard),
			_text("settings.controls.controller"), _binding_label(_import_proposal.after[action].controller),
		]
		_import_rows.add_child(label)


func _apply_import() -> void:
	if _import_proposal.is_empty() or not is_reviewing_import() or not _lawful():
		return
	var proposal := _import_proposal.duplicate(true)
	var review := _review.duplicate(true)
	var draft := _review_draft.duplicate(true)
	_import_proposal.clear()
	_review.clear()
	_review_draft.clear()
	var result: Dictionary = _profile.commit_controls_import(proposal)
	if not result.get("ok", false):
		var current: Dictionary = _profile.get_controls_import_review()
		if current.get("ok", false) and current.value.revision == review.revision \
				and current.value.bindings == review.bindings and current.value.legacy_bindings == review.legacy_bindings:
			_review = review
			_review_draft = draft
	_status_key = "settings.controls.applied" if result.get("ok", false) else _failure_key(result.get("code", &""))
	_source = button_for("game_quick_save", "keyboard") if result.get("ok", false) else (apply_review_button if is_reviewing_import() else review_button)
	_cancel_and_restore()


func _clear_rows(body: VBoxContainer) -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()


func _identity(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % (event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if event is InputEventJoypadButton:
		return "joy:%d:%d" % [event.device, event.button_index]
	if event is InputEventMouseButton:
		return "mouse:%d:%d" % [event.device, event.button_index]
	return ""


func _action_label(action: String) -> String:
	var locale: String = _content.current_locale().replace("_", "-")
	for record: Dictionary in REGISTRY.records():
		if String(record.id) == action:
			return record.labels.get(locale, record.labels.en)
	return _text("settings.status.unavailable")


func _binding_label(binding: Dictionary) -> String:
	if binding.get("kind") == "key":
		return OS.get_keycode_string(int(binding.get("physical_keycode", 0)))
	if binding.get("kind") == "joypad_button" and POSITIONS.has(binding.get("button_index")):
		return _text("settings.controls.position." + POSITIONS[binding.button_index])
	return _text("settings.status.unavailable")


func _failure_key(code: StringName) -> String:
	if code in [&"profile_revision_changed", &"binding_source_changed"]:
		return "settings.controls.stale"
	if code == &"modifier_arbitration_unavailable":
		return "settings.controls.modifiers"
	if code == &"protected_binding":
		return "settings.controls.protected"
	if code in [&"unsupported_key", &"unsupported_button", &"invalid_controller_binding", &"invalid_keyboard_binding"]:
		return "settings.controls.unsupported"
	return "settings.controls.failed"


func _text(key: String, parameters: Dictionary = {}) -> String:
	return _content.text(key, parameters)


func _is_controller_mapped(device: int) -> bool:
	if device < 0:
		return false
	var result: Variant = _controller_mapped.call(device) if _controller_mapped.is_valid() else Input.is_joy_known(device)
	return typeof(result) == TYPE_BOOL and result
