extends CanvasLayer
## A title-owned practice surface. The retained owner contains only detached run data.
signal closed
const SANDBOX := preload("res://scripts/application/run/DatingRehearsalOwner.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const ADMISSION := preload("res://scripts/domain/narrative/DatingRehearsalAdmission.gd")
const DATING := preload("res://scenes/dating/DatingScene.tscn")
const COPY := {
	"zh-HK": ["\u7df4\u7fd2", "\u7df4\u7fd2\u7684\u7d50\u679c\u662f\u5047\u8a2d\u6027\u7684\uff0c\u4e0d\u6703\u6539\u8b8a\u76ee\u524d\u904a\u6232\u9032\u5ea6\u3002", "\u958b\u59cb", "\u8fd4\u56de", "\u9084\u6c92\u6709\u53ef\u7df4\u7fd2\u7684\u7d04\u6703\u8a18\u9304\u3002", "\u66ab\u6642\u7121\u6cd5\u958b\u59cb\u7df4\u7fd2\uff0c\u8acb\u91cd\u8a66\u3002", "\u7df4\u7fd2\u5b8c\u6210\u3002", "\u7b2c %d \u5929", "\u7248\u672c %d", "\u7df4\u7fd2 / \u5047\u8a2d\u6027\u7d50\u679c"],
	"en": ["Practice", "Practice uses hypothetical outcomes. Your current run is unchanged.", "Start", "Return", "No reached dates are available yet.", "Practice could not start. Please try again.", "Practice complete.", "Day %d", "Version %d", "Practice / hypothetical outcomes"],
	"zh": ["\u7ec3\u4e60", "\u7ec3\u4e60\u7684\u7ed3\u679c\u662f\u5047\u8bbe\u6027\u7684\uff0c\u4e0d\u4f1a\u6539\u53d8\u5f53\u524d\u6e38\u620f\u8fdb\u5ea6\u3002", "\u5f00\u59cb", "\u8fd4\u56de", "\u8fd8\u6ca1\u6709\u53ef\u7ec3\u4e60\u7684\u7ea6\u4f1a\u8bb0\u5f55\u3002", "\u6682\u65f6\u65e0\u6cd5\u5f00\u59cb\u7ec3\u4e60\uff0c\u8bf7\u91cd\u8bd5\u3002", "\u7ec3\u4e60\u5b8c\u6210\u3002", "\u7b2c %d \u5929", "\u7248\u672c %d", "\u7ec3\u4e60 / \u5047\u8bbe\u6027\u7ed3\u679c"]}
const VIEW_SAVE_COPY := {
	"en": "Could not save the board view. Please try again.",
	"zh": "\u65e0\u6cd5\u4fdd\u5b58\u68cb\u76d8\u89c6\u56fe\uff0c\u8bf7\u91cd\u8bd5\u3002",
	"zh-HK": "\u7121\u6cd5\u5132\u5b58\u68cb\u76e4\u6aa2\u8996\uff0c\u8acb\u91cd\u8a66\u3002",
}
var _profile: Object
var _game: Object
var _bridge: Object
var _input: Object
var _locale := "en"
var _percent := 100
var _presentation_theme: Theme
var _sandbox: RefCounted
var _records: Array[Dictionary] = []
var _root: Control
var _selection: CenterContainer
var _dates: OptionButton
var _start: Button
var _return_button: Button
var _status: Label
var _dating: Control
var _header: HBoxContainer
var _command: Dictionary = {}

func configure(profile: Object, game: Object, bridge: Object, input_owner: Object,
		locale: String, percent: int, presentation_theme: Theme) -> Dictionary:
	if is_node_ready() or _profile != null: return {"ok": false, "code": &"practice_already_configured"}
	if profile == null or not profile.has_method("has_completed_ending") or not profile.has_completed_ending():
		return {"ok": false, "code": &"rehearsal_milestone_required"}
	if bridge == null or not bridge.has_method("capture_rehearsal_variables"):
		return {"ok": false, "code": &"practice_variables_unavailable"}
	var sandbox := SANDBOX.new()
	var result: Dictionary = sandbox.configure(profile, game)
	if not result.get("ok", false): return result
	_profile = profile
	_game = game
	_bridge = bridge
	_input = input_owner
	_locale = locale
	_percent = percent
	_presentation_theme = presentation_theme
	_sandbox = sandbox
	_sandbox.finished.connect(_on_finished)
	return {"ok": true}

func _ready() -> void:
	layer = 40
	_root = Control.new()
	_root.name = "PracticeRoot"
	_root.theme = _presentation_theme.duplicate() if _presentation_theme != null else Theme.new()
	if _presentation_theme != null:
		var ink: Color = _presentation_theme.get_color("paper_ink", "Gallery")
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_root.theme.set_color(state, "Button", ink)
		var paper := StyleBoxFlat.new()
		paper.bg_color = _presentation_theme.get_color("paper", "Gallery")
		paper.border_color = ink
		paper.set_border_width_all(1)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			_root.theme.set_stylebox(state, "Button", paper)
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = _presentation_theme.get_color("paper", "Gallery") if _presentation_theme != null else Color("28313d")
	_root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection = CenterContainer.new()
	_root.add_child(_selection)
	_selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection.offset_top = 80
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	panel.add_theme_constant_override("separation", 20)
	_selection.add_child(panel)
	var description := Label.new()
	description.text = _copy(1)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 720
	panel.add_child(description)
	_dates = OptionButton.new()
	_dates.name = "ReachedDate"
	_dates.custom_minimum_size.y = 56
	panel.add_child(_dates)
	_start = Button.new()
	_start.name = "StartPractice"
	_start.text = _copy(2)
	_start.custom_minimum_size.y = 56
	_start.pressed.connect(_on_start)
	panel.add_child(_start)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_status)
	_header = HBoxContainer.new()
	_root.add_child(_header)
	_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_header.offset_left = 24
	_header.offset_right = -24
	_header.offset_top = 12
	_header.offset_bottom = 68
	var title := Label.new()
	title.text = _copy(9)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title)
	_return_button = Button.new()
	_return_button.name = "ReturnFromPractice"
	_return_button.text = _copy(3)
	_return_button.custom_minimum_size = Vector2(176, 56)
	_return_button.pressed.connect(request_return)
	_header.add_child(_return_button)
	_refresh_records()

func _copy(index: int) -> String:
	return COPY["zh-HK" if _locale.replace("_", "-") == "zh-HK" else ("zh" if _locale.begins_with("zh") else "en")][index]

func _refresh_records() -> void:
	_records.clear()
	_dates.clear()
	var reached: Dictionary = _profile.get_reached_presentations()
	var versions: Dictionary = {}
	if reached.get("ok", false):
		for record: Dictionary in reached.value.records:
			var admitted: Dictionary = ADMISSION.prepare(record, reached.value.records, _profile.has_completed_ending())
			if not admitted.get("ok", false): continue
			var entry_id: String = record.signature.entry_id
			versions[entry_id] = int(versions.get(entry_id, 0)) + 1
			var context: Dictionary = admitted.value.context
			var who: String = str(context.participants[0]).capitalize() if context.kind == "solo" else "Priscilla & Lavinia"
			var variation: String = ""
			if context.kind != "solo":
				variation = (" / Group" if context.kind == "group" else " / Encounter") if not _locale.begins_with("zh") else (" / \u5171\u540c\u7ea6\u4f1a" if context.kind == "group" else " / \u76f8\u9047")
			_dates.add_item("%s / %s%s / %s" % [who, _copy(7) % context.day, variation, _copy(8) % versions[entry_id]])
			_records.append(record.duplicate(true))
	_start.disabled = _records.is_empty()
	_dates.disabled = _records.is_empty()
	_status.text = _copy(4) if _records.is_empty() else ""
	_dates.focus_previous = _return_button.get_path()
	_dates.focus_next = _start.get_path()
	_start.focus_previous = _dates.get_path()
	_return_button.focus_previous = _start.get_path() if not _records.is_empty() else _return_button.get_path()
	_start.focus_next = _return_button.get_path()
	_return_button.focus_next = _dates.get_path() if not _records.is_empty() else _return_button.get_path()
	(_return_button if _records.is_empty() else _dates).grab_focus.call_deferred()

func _on_start() -> void:
	if is_instance_valid(_dating) or _dates.selected < 0 or _dates.selected >= _records.size(): return
	var captured: Dictionary = _bridge.capture_rehearsal_variables()
	if not captured.get("ok", false):
		_status.text = _copy(5)
		return
	var begun: Dictionary = _sandbox.begin(_records[_dates.selected], captured.value.variables)
	if not begun.get("ok", false):
		_status.text = _copy(5)
		return
	_command = begun.value.presentation_command.duplicate(true)
	_dating = DATING.instantiate()
	_dating.name = "PracticeDating"
	var large: Variant = _profile.get_preference("preferences.accessibility.large_targets", null)
	if large == null: large = _profile.get_preference("preferences.accessibility.large_click_targets", false)
	var colour: Variant = _profile.get_preference("preferences.accessibility.colour_differentiation", null)
	if colour == null:
		var legacy: String = str(_profile.get_preference("preferences.accessibility.colorblind_mode", "none"))
		colour = {"none": "standard", "protanopia": "protan", "deuteranopia": "deutan", "tritanopia": "tritan"}.get(legacy, "standard")
	var services: Dictionary = _dating.configure_presentation_services(_input, _locale, _percent,
		bool(large), &"after_hours", bool(_profile.get_preference("preferences.accessibility.high_contrast", false)), str(colour), _profile)
	var bound: Dictionary = _dating.configure_presentation(_sandbox, _command) if services.get("ok", false) else services
	if not bound.get("ok", false):
		_dating.free()
		_dating = null
		_sandbox.close()
		_command = {}
		_status.text = _copy(5)
		return
	_selection.hide()
	_root.add_child(_dating)
	_dating.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dating.offset_top = 80
	_root.move_child(_header, -1)
	_return_button.grab_focus()

func request_return() -> void:
	if is_instance_valid(_dating):
		_return_to_selection(false)
		return
	_sandbox.close()
	closed.emit()

func _on_finished(receipt: Dictionary) -> void:
	# Let the scene finish dispatch; a stale completion cannot close a replacement board.
	_finish_current.call_deferred(str(receipt.get("physical_token", "")))

func _finish_current(token: String) -> void:
	if token.is_empty() or token != str(_command.get("physical_token", "")): return
	_return_to_selection(true)

func _return_to_selection(completed: bool) -> void:
	if not is_inside_tree() or not is_instance_valid(_dating): return
	if not _dating.worksheet.flush_view_preferences():
		_status.text = VIEW_SAVE_COPY["zh-HK" if _locale.replace("_", "-") == "zh-HK" else ("zh" if _locale.begins_with("zh") else "en")]
		return
	_root.remove_child(_dating)
	_dating.queue_free()
	_dating = null
	_sandbox.close()
	_command = {}
	_selection.show()
	_status.text = _copy(6) if completed else ""
	_start.grab_focus()

func _exit_tree() -> void:
	if _sandbox != null: _sandbox.close()
