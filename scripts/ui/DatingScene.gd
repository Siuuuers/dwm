extends Control
class_name DatingScene

## Presentation-only canonical challenge host. SceneRouter injects the retained presentation
## port and exact admitted command; only that port may receive player challenge commands.
## Narrative scenes remain scene-oriented assets, with detailed dialogue deferred.
const _PORT_METHODS: Array[String] = ["begin", "complete"]
const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const CHROME_COPY := preload("res://scripts/ui/minesweeper/MinesweeperChromeCopy.gd")
const PRESENTATION_SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")

## Shared provisional physical copy: readonly entry replay uses the same visible words.
static func presentation_copy(context: Dictionary, phase: String, locale: String = "en") -> Dictionary:
	if phase not in ["pre_challenge", "post_challenge"] or context.get("day") not in range(1, 7) \
			or not context.get("participants") is Array:
		return {"ok": false, "code": &"dating_copy_unavailable"}
	var names := ""
	if context.get("kind") == "solo" and context.participants.size() == 1 \
			and context.participants[0] in ["priscilla", "lavinia", "sylvia"]:
		names = str(context.participants[0]).capitalize()
	elif context.get("kind") in ["group", "twofriends_if_deferred"] and context.participants == ["priscilla", "lavinia"]:
		names = "Priscilla & Lavinia"
	else: return {"ok": false, "code": &"dating_copy_unavailable"}
	var copy: Array = ["Day %d", "Ready to begin.", "Challenge complete."]
	var normalized: String = locale.replace("_", "-")
	if normalized == "zh-CN": copy = ["\u7b2c %d \u5929", "\u51c6\u5907\u5f00\u59cb\u3002", "\u6311\u6218\u5b8c\u6210\u3002"]
	elif normalized == "zh-HK": copy = ["\u7b2c %d \u5929", "\u6e96\u5099\u958b\u59cb\u3002", "\u6311\u6230\u5b8c\u6210\u3002"]
	return {"ok": true, "value": {"title": names + " / " + (str(copy[0]) % int(context.day)),
		"body": str(copy[1 if phase == "pre_challenge" else 2])}}

static func reached_presentation_copy(signature: Dictionary, locale: String = "en") -> Dictionary:
	var checked: Dictionary = PRESENTATION_SIGNATURE.validate(signature)
	if not checked.ok: return checked
	var entry: Dictionary = PRESENTATION_SIGNATURE.entry_record(str(signature.entry_id))
	if not entry.ok: return entry
	var row: Dictionary = entry.value
	if row.role not in ["solo_pre_challenge", "solo_post_challenge", "pair_pre_challenge_scene", "pair_post_challenge_scene"]:
		return {"ok": false, "code": &"dating_copy_unavailable"}
	var parts: PackedStringArray = str(signature.entry_id).split(".")
	if parts.size() != 5 or parts[0] != "dating": return {"ok": false, "code": &"dating_copy_unavailable"}
	var context := {"kind": "twofriends_if_deferred" if parts[1] == "twofriends" else parts[1],
		"day": int(row.day), "participants": [parts[2]] if parts[1] == "solo" else ["priscilla", "lavinia"]}
	return presentation_copy(context, parts[4], locale)

var worksheet: Control
var _status_label: Label
var _continue_button: Button
var _special_mine_button: Button
var _mode_buttons: Array[Button] = []
var _rules_button: Button
var _physical_view: Dictionary = {}
var _input_owner: Object
var _locale: String = "en"
var _percent: int = 100
var _large_cells: bool = false
var _palette: StringName = &"after_hours"
var _high_contrast: bool = false
var _colour_preset: String = "standard"
var _dispatching: bool = false
var _pre_challenge_drawn := false
var _pre_challenge_ack_attempted := false
var _pre_challenge_reached := false
var _post_challenge_drawn := false
var _post_challenge_ack_attempted := false
var _post_challenge_reached := false
var _observer_panel: VBoxContainer
var _observer_action: Button
var _comparison_overlay: Label
var _false_cursor: Label
var _observer_view: Dictionary = {}
var _observer_rendered := false
var _observer_drawn := false
var _comparison_drawn := false
var _observer_tick_ms := 0.0
var _observer_close_failed := false


var _presentation_port: Object = null
var _presentation_command: Dictionary = {}

@onready var dating_background: TextureRect = %DatingBackground
@onready var character_zone_left: Control = %CharacterZoneLeft
@onready var character_zone_center: Control = %CharacterZoneCenter
@onready var character_zone_right: Control = %CharacterZoneRight
@onready var previous_dialogue_list: VBoxContainer = %PreviousDialogueList
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var challenge_overlay_host: Control = %ChallengeOverlayHost

func _ready() -> void:
	if not is_presentation_configured() or not _presentation_port.has_method("pull_physical"): return
	var pulled: Dictionary = _presentation_port.pull_physical(_presentation_command)
	if not pulled.get("ok", false): return
	_physical_view = pulled.value.duplicate(true)
	_build_challenge()
	_refresh_challenge()
	_build_observer()

## Input/accessibility settings are composition-owned. This scene never looks up autoloads.
func configure_presentation_services(input_owner: Object, locale: String = "en", percent: int = 100,
		large_cells: bool = false, palette: StringName = &"after_hours", high_contrast: bool = false,
		colour_preset: String = "standard") -> Dictionary:
	if _input_owner != null and _input_owner != input_owner:
		return _fail(&"presentation_services_already_configured", "input owner replacement refused")
	_input_owner = input_owner
	_locale = locale.replace("_", "-")
	_percent = percent
	_large_cells = large_cells
	_palette = palette
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	if is_instance_valid(worksheet):
		if not worksheet.configure(str(_physical_view.host), _locale, _percent, _large_cells,
				_palette, Vector2i.ZERO, _high_contrast, _colour_preset):
			return _fail(&"invalid_challenge_presentation", "unsupported presentation settings")
		if input_owner != null and not worksheet.grid.configure_input(input_owner):
			return _fail(&"invalid_challenge_input", "input contract incomplete")
		_refresh_challenge()
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

func _build_challenge() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_node("DatingRoot").hide()
	challenge_overlay_host.show()
	var backdrop := ColorRect.new()
	backdrop.color = Color("151920") if _palette == &"after_hours" else Color("d5d4ce")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_overlay_host.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_overlay_host.add_child(center)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	center.add_child(panel)
	var title := Label.new()
	title.name = "ChallengeTitle"
	title.text = presentation_copy(_presentation_command.context, "pre_challenge", _locale).value.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	title.draw.connect(func(): _pre_challenge_drawn = true)
	worksheet = WORKSHEET.new()
	worksheet.name = "DatingWorksheet"
	worksheet.configure(str(_physical_view.host), _locale, _percent, _large_cells,
		_palette, Vector2i.ZERO, _high_contrast, _colour_preset)
	if _input_owner != null: worksheet.grid.configure_input(_input_owner)
	panel.theme = worksheet.theme
	panel.add_child(worksheet)
	worksheet.cell_action_requested.connect(_on_cell_action)
	var toolbar := HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(toolbar)
	for mode: String in ["reveal", "flag", "drag"]:
		var button := Button.new()
		button.name = mode.capitalize()
		button.set_meta("mode", mode)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(120, 40)
		button.pressed.connect(_select_mode.bind(mode))
		toolbar.add_child(button)
		_mode_buttons.append(button)
	_rules_button = Button.new()
	_rules_button.name = "Rules"
	_rules_button.custom_minimum_size = Vector2(120, 40)
	_rules_button.pressed.connect(func(): worksheet.open_rules(_rules_button))
	toolbar.add_child(_rules_button)
	_special_mine_button = Button.new()
	_special_mine_button.name = "SpecialMine"
	_special_mine_button.text = "\u25c6"
	_special_mine_button.accessibility_name = "Special mine"
	_special_mine_button.tooltip_text = "Special mine"
	_special_mine_button.custom_minimum_size = Vector2(64, 40)
	_special_mine_button.pressed.connect(_dispatch_action.bind("special_mine", -1))
	toolbar.add_child(_special_mine_button)
	_status_label = Label.new()
	_status_label.name = "ChallengeStatus"
	_status_label.draw.connect(_on_challenge_status_drawn)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_status_label)
	_continue_button = Button.new()
	_continue_button.name = "ContinueChallenge"
	_continue_button.custom_minimum_size = Vector2(0, 44)
	_continue_button.pressed.connect(_on_continue)
	panel.add_child(_continue_button)

func _refresh_challenge() -> void:
	if not is_instance_valid(worksheet) or _physical_view.is_empty(): return
	worksheet.present(_physical_view.board)
	var phase: String = str(_physical_view.phase)
	var copy: Dictionary = presentation_copy(_presentation_command.context,
		"post_challenge" if _physical_view.phase in ["post_challenge", "completed"] else "pre_challenge", _locale)
	var title: Label = _status_label.get_parent().get_node("ChallengeTitle")
	title.text = copy.value.title
	# These labels sit on Dating's backdrop, even when Gallery supplies a paper theme.
	var ink: Color = worksheet.get_theme_color("primary_dark_copy" if _palette == &"after_hours" else "primary_paper_copy", "Minesweeper")
	title.add_theme_color_override("font_color", ink)
	_status_label.add_theme_color_override("font_color", ink)
	for button: Button in _mode_buttons:
		var mode: String = str(button.get_meta("mode"))
		button.text = str(CHROME_COPY.get_copy(_locale).get(mode, mode.capitalize()))
		button.disabled = phase != "challenge"
		button.set_pressed_no_signal(str(worksheet.grid.mode) == mode)
	_rules_button.text = str(CHROME_COPY.get_copy(_locale).get("rules", "Rules"))
	_rules_button.disabled = phase != "challenge"
	_special_mine_button.visible = bool(_physical_view.special_mine_visible)
	_special_mine_button.disabled = not bool(_physical_view.special_mine_enabled)
	_continue_button.visible = phase != "challenge"
	_continue_button.text = "Retry" if phase in ["settlement_retry", "checkpoint_retry"] else "Continue"
	match phase:
		"pre_challenge": _status_label.text = str(copy.value.body)
		"challenge": _status_label.text = "Reveal, flag, or drag to explore the board."
		"cleared_awaiting_terminal_choice": _status_label.text = "Board cleared. Continue or activate the special mine."
		"checkpoint_retry": _status_label.text = "The attempt is saved. Retry to finish saving this point."
		"settlement_retry": _status_label.text = "Retry to finish processing the result."
		_: _status_label.text = str(copy.value.body)
	_refresh_observer()

func _acknowledge_pre_challenge_draw() -> bool:
	if not _presentation_port.has_method("acknowledge_pre_challenge_render"):
		# The separate Rehearsal facade never owns canonical reach/history capabilities.
		_pre_challenge_reached = true
		_pre_challenge_ack_attempted = true
		return true
	if not _pre_challenge_drawn: return false
	_pre_challenge_ack_attempted = true
	var reached: Dictionary = _presentation_port.acknowledge_pre_challenge_render(_presentation_command)
	_pre_challenge_reached = bool(reached.get("ok", false))
	if not _pre_challenge_reached:
		_status_label.text = "This moment could not be saved. Try again."
		_continue_button.text = "Retry"
	return _pre_challenge_reached

func _on_challenge_status_drawn() -> void:
	if _physical_view.get("phase") == "post_challenge" and is_visible_in_tree():
		_post_challenge_drawn = true

func _acknowledge_post_challenge_draw() -> bool:
	if not _presentation_port.has_method("acknowledge_post_challenge_render"):
		# The private Practice owner never receives the canonical history writer.
		_post_challenge_reached = true
		_post_challenge_ack_attempted = true
		return true
	if not _post_challenge_drawn: return false
	_post_challenge_ack_attempted = true
	var reached: Dictionary = _presentation_port.acknowledge_post_challenge_render(_presentation_command)
	_post_challenge_reached = bool(reached.get("ok", false))
	if not _post_challenge_reached:
		_status_label.text = "This moment could not be saved. Try again."
		_continue_button.text = "Retry"
	return _post_challenge_reached

func _build_observer() -> void:
	if not _presentation_port.has_method("pull_observer"): return
	var pulled: Dictionary = _presentation_port.pull_observer(_presentation_command)
	if not pulled.get("ok", false) or pulled.value.is_empty(): return
	_observer_view = pulled.value.duplicate(true)
	_observer_panel = VBoxContainer.new()
	_observer_panel.name = "DatingSceneMoment"
	_continue_button.get_parent().add_child(_observer_panel)
	_continue_button.get_parent().move_child(_observer_panel, _continue_button.get_index())
	var line := Button.new()
	line.name = "PreviousSceneLine"
	line.flat = true
	line.text = "                    " if _observer_view.counterpart else str(_observer_view.text)
	line.accessibility_name = "A blank in the previous line" if _observer_view.counterpart else line.text
	line.custom_minimum_size = Vector2(500, 44)
	_observer_panel.add_child(line)
	line.draw.connect(func(): _observer_drawn = true)
	if _observer_view.scope == "priscilla":
		_observer_action = Button.new()
		_observer_action.name = "Compare" if _observer_view.counterpart else "Capture"
		_observer_action.text = "COMPARE" if _observer_view.counterpart else "CAPTURE"
		_observer_action.visible = bool(_observer_view.counterpart)
		if _observer_view.counterpart:
			_observer_panel.add_child(_observer_action)
		else:
			# Keep Capture within the hovered history line: no disappearing gap between
			# the source and its affordance. Focus on either retains keyboard access.
			line.alignment = HORIZONTAL_ALIGNMENT_LEFT
			line.add_child(_observer_action)
			_observer_action.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
			_observer_action.offset_left = -120.0
			_observer_action.offset_right = 0.0
		if not _observer_view.counterpart:
			line.mouse_entered.connect(func(): _observer_action.show())
			line.mouse_exited.connect(_hide_capture_if_unfocused.bind(line))
			line.focus_entered.connect(func(): _observer_action.show())
			line.focus_exited.connect(_hide_capture_if_unfocused.bind(line))
			_observer_action.mouse_exited.connect(_hide_capture_if_unfocused.bind(line))
			_observer_action.focus_exited.connect(_hide_capture_if_unfocused.bind(line))
		_observer_action.pressed.connect(_on_observer_action)
	else:
		_observer_action = Button.new()
		_observer_action.name = "MoveCup"
		_observer_action.text = "Move the cup"
		_observer_panel.add_child(_observer_action)
		_observer_action.pressed.connect(_on_observer_action)
		_false_cursor = Label.new()
		_false_cursor.text = "\u2196"
		_false_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_false_cursor.add_theme_font_size_override("font_size", 30)
		_observer_action.add_child(_false_cursor)
	_refresh_observer()

func _hide_capture_if_unfocused(line: Control) -> void:
	# Hover transfers from the designated history line to its Capture affordance;
	# keyboard focus provides the same gesture without requiring pointer precision.
	await get_tree().process_frame
	if not is_instance_valid(_observer_action): return
	if line.has_focus() or _observer_action.has_focus(): return
	var pointer := get_global_mouse_position()
	if line.get_global_rect().has_point(pointer) or _observer_action.get_global_rect().has_point(pointer): return
	_observer_action.hide()

func _process(delta: float) -> void:
	if _post_challenge_drawn and not _post_challenge_ack_attempted and _physical_view.get("phase") == "post_challenge":
		_acknowledge_post_challenge_draw()
	if _pre_challenge_drawn and not _pre_challenge_ack_attempted and _physical_view.get("phase") == "pre_challenge":
		_acknowledge_pre_challenge_draw()
	if not is_instance_valid(_observer_panel) or not _observer_panel.is_visible_in_tree() \
			or _physical_view.get("phase") != "pre_challenge": return
	if get_tree().paused or not get_window().has_focus(): return
	if not _observer_rendered:
		if not _observer_drawn: return
		_observer_rendered = _send_observer("render").get("ok", false)
		return
	if _observer_view.scope != "lavinia" or _observer_view.closed or _observer_close_failed or _observer_view.checkpoint_pending: return
	_observer_tick_ms += delta * 1000.0
	if _observer_tick_ms < 100.0: return
	var elapsed := mini(1000, int(_observer_tick_ms))
	_observer_tick_ms = 0.0
	var ticked := _send_observer("tick", elapsed)
	if not ticked.get("ok", false): return
	if int(_observer_view.elapsed_ms) >= int(_observer_view.duration_ms):
		var closed := _send_observer("close")
		if not closed.get("ok", false):
			_observer_close_failed = true
			_observer_action.text = "Retry"

func _send_observer(action: String, elapsed_ms: int = 0) -> Dictionary:
	var result: Dictionary = _presentation_port.dispatch_observer(_presentation_command,
		str(_observer_view.presentation_atom_id), action, elapsed_ms)
	if result.get("ok", false):
		_observer_view = result.value.duplicate(true)
		_refresh_observer()
	else:
		var pulled: Dictionary = _presentation_port.pull_observer(_presentation_command)
		if pulled.get("ok", false) and not pulled.value.is_empty():
			_observer_view = pulled.value.duplicate(true)
			_refresh_observer()
	return result

func _on_observer_action() -> void:
	if not _observer_rendered: return
	if _observer_view.checkpoint_pending:
		_send_observer("retry")
		return
	if _observer_view.scope == "lavinia":
		var action := "close" if _observer_close_failed else "intervene"
		var result := _send_observer(action)
		if result.get("ok", false): _observer_close_failed = false
	elif _observer_view.counterpart:
		var compared := _send_observer("compare")
		if not compared.get("ok", false): return
		if not is_instance_valid(_comparison_overlay):
			_comparison_overlay = Label.new()
			_comparison_overlay.name = "ComparedLines"
			_comparison_overlay.text = str(_observer_view.text) + "\n" + str(_observer_view.counterpart_text)
			_comparison_overlay.draw.connect(_on_comparison_drawn)
			_observer_panel.add_child(_comparison_overlay)
		elif _comparison_drawn and _comparison_overlay.is_visible_in_tree():
			_send_observer("compare_rendered")
	else:
		_send_observer("capture")

func _on_comparison_drawn() -> void:
	if _comparison_drawn: return
	_comparison_drawn = true
	# CanvasItem.draw proves the actual overlay rendered; process_frame precedes draw.
	_send_observer("compare_rendered")

func _refresh_observer() -> void:
	if not is_instance_valid(_observer_panel): return
	_observer_panel.visible = _physical_view.get("phase") == "pre_challenge"
	if _observer_view.checkpoint_pending:
		_observer_action.show()
		_observer_action.disabled = false
		_observer_action.text = "Retry"
		return
	_observer_action.text = ("COMPARE" if _observer_view.counterpart else "CAPTURE") if _observer_view.scope == "priscilla" else "Move the cup"
	if _observer_view.scope == "priscilla":
		_observer_action.disabled = not _observer_view.counterpart and bool(_observer_view.captured)
	else:
		_observer_action.disabled = bool(_observer_view.closed) or bool(_observer_view.intervened)
		if is_instance_valid(_false_cursor):
			_false_cursor.visible = not _observer_view.closed and not _observer_view.intervened
			var fraction := float(_observer_view.elapsed_ms) / float(_observer_view.duration_ms)
			_false_cursor.position = Vector2(30.0 + fraction * 160.0, -40.0 + fraction * 50.0)

func _select_mode(mode: String) -> void:
	if worksheet.set_mode(StringName(mode)): _refresh_challenge()

func _on_cell_action(action: StringName, index: int, revision: int) -> void:
	_dispatch_action(str(action), index, revision)

func _on_continue() -> void:
	var phase: String = str(_physical_view.get("phase", ""))
	if phase == "pre_challenge" and not _pre_challenge_reached and not _acknowledge_pre_challenge_draw(): return
	if phase == "post_challenge" and not _post_challenge_reached and not _acknowledge_post_challenge_draw(): return
	_dispatch_action("retry" if phase in ["settlement_retry", "checkpoint_retry"] else (
		"resume_completion" if phase == "completed" else "continue"), -1)

func _dispatch_action(action: String, index: int, revision: int = -1) -> void:
	if _dispatching or _physical_view.is_empty(): return
	_dispatching = true
	var expected: int = int(_physical_view.board.revision) if revision < 0 else revision
	var result: Dictionary = _presentation_port.dispatch_physical(_presentation_command, action, index, expected)
	_dispatching = false
	# Completion may synchronously remove this scene; do not republish its stale projection.
	if not is_inside_tree() or is_queued_for_deletion(): return
	var pulled: Dictionary = _presentation_port.pull_physical(_presentation_command)
	if pulled.get("ok", false):
		_physical_view = pulled.value.duplicate(true)
		_refresh_challenge()
	if not result.get("ok", false):
		_status_label.text = "Action unavailable. " + str(result.get("code", ""))


## The ONE injection seam. Called by `SceneRouter` before `add_child()`. Identical replay is
## idempotent; a replacement port is refused rather than adopted.
func configure_presentation(port: Object, presentation_command: Dictionary) -> Dictionary:
	if port == null or not _has_methods(port, _PORT_METHODS):
		return _fail(&"invalid_presentation_port", "the presentation port contract is incomplete")
	if typeof(presentation_command) != TYPE_DICTIONARY or presentation_command.is_empty():
		return _fail(&"invalid_presentation_command", "a presentation command is required")
	if _presentation_port != null and _presentation_port != port:
		return _fail(&"presentation_port_already_configured",
			"a configured scene never adopts a replacement port")
	_presentation_port = port
	_presentation_command = presentation_command.duplicate(true)
	return {"ok": true, "code": &"ok",
		"value": {"port_instance_id": port.get_instance_id()}, "receipt": {}}


func is_presentation_configured() -> bool:
	return _presentation_port != null and not _presentation_command.is_empty()


## The exact command this scene was given, detached so a caller cannot mutate the scene's copy.
func get_presentation_projection() -> Dictionary:
	return _presentation_command.duplicate(true)


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}


## Forwards the narrative bridge to the hosted DialogueBox (dwm-p2r.8, Plan-05 Task 4). The scene
## never calls the bridge itself; it only wires the box that emits skip commands.
func configure_narrative_bridge(bridge: Object) -> Dictionary:
	if not is_instance_valid(dialogue_box) or not dialogue_box.has_method("configure_narrative_bridge"):
		return {"ok": false, "code": &"missing_dialogue_box", "message": "", "details": {}}
	return dialogue_box.configure_narrative_bridge(bridge)


## The visible transcript is RUN-specific presentation and is never the ProfileManager visited set:
## visited history is global and persists across runs, while this list resets with the scene.
func append_previous_dialogue_line(rendered_text: String) -> void:
	if not is_instance_valid(previous_dialogue_list):
		return
	var line := Label.new()
	line.text = rendered_text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	previous_dialogue_list.add_child(line)
