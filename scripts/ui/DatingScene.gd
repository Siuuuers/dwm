extends Control
class_name DatingScene

## Presentation-only canonical challenge host. SceneRouter injects the retained presentation
## port and exact admitted command; only that port may receive player challenge commands.
## Narrative scenes remain scene-oriented assets, with detailed dialogue deferred.
const _PORT_METHODS: Array[String] = ["begin", "complete"]
const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const FLAG_BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperFlagButton.gd")
const CHROME_COPY := preload("res://scripts/ui/minesweeper/MinesweeperChromeCopy.gd")
const PRESENTATION_SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const SCENE_ART_VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
const QUICK_COMMANDS := preload("res://scripts/ui/dating/DatingQuickCommands.gd")
class QuickConfirmation extends "res://scripts/ui/desktop/DesktopConfirmation.gd":
	var input_owner: Object
	func _input(event: InputEvent) -> void:
		# Confirmation can consume input before the scene sees it. Keep physical
		# contacts in the same ledger so its closing contact cannot advance Dating.
		input_owner.observe_physical_contact(event)
		super._input(event)

const DRAFT_UI_COPY := {
	"zh-CN": {
		"Special mine": "特殊地雷",
		"Retry": "重试",
		"Continue": "继续",
		"Retry to finish processing the result.": "重试以完成结果处理。",
		"Reveal, flag, or drag to explore the board.": "揭开格子、标旗或拖动以查看棋盘。",
		"Board cleared.": "棋盘已完成。",
		"Try again.": "请重试。",
		"The attempt is saved. Retry to finish saving this point.": "本次尝试已记录。重试以完成此处的保存。",
		"Action unavailable. ": "此操作不可用。 "
	},
	"zh-HK": {
		"Special mine": "特殊地雷",
		"Retry": "重試",
		"Continue": "繼續",
		"Retry to finish processing the result.": "重試以完成結果處理。",
		"Reveal, flag, or drag to explore the board.": "揭開格子、標旗或拖動以查看棋盤。",
		"Board cleared.": "棋盤已完成。",
		"Try again.": "請重試。",
		"The attempt is saved. Retry to finish saving this point.": "本次嘗試已記錄。重試以完成此處的儲存。",
		"Action unavailable. ": "此操作不可用。 "
	},
	"ja": {
		"Special mine": "特殊な地雷",
		"Retry": "再試行",
		"Continue": "続ける",
		"Retry to finish processing the result.": "再試行して結果の処理を完了してください。",
		"Reveal, flag, or drag to explore the board.": "マスを開く、旗を立てる、ドラッグで盤面を操作できます。",
		"Board cleared.": "盤面をクリアしました。",
		"Try again.": "再試行してください。",
		"The attempt is saved. Retry to finish saving this point.": "プレイ結果は保存済みです。再試行してこの時点の保存を完了してください。",
		"Action unavailable. ": "この操作は利用できません。 "
	},
	"ko": {
		"Special mine": "특수 지뢰",
		"Retry": "다시 시도",
		"Continue": "계속",
		"Retry to finish processing the result.": "다시 시도하여 결과 처리를 완료하세요.",
		"Reveal, flag, or drag to explore the board.": "칸을 열고, 깃발을 놓거나 드래그하여 보드를 살펴보세요.",
		"Board cleared.": "보드를 클리어했습니다.",
		"Try again.": "다시 시도하세요.",
		"The attempt is saved. Retry to finish saving this point.": "시도는 저장되었습니다. 다시 시도하여 이 지점의 저장을 완료하세요.",
		"Action unavailable. ": "이 작업은 사용할 수 없습니다. "
	}
}


## Art follows the admitted scene, never a result, relationship tier, or expression variant.
static func scene_art_entry(context: Dictionary) -> String:
	if not presentation_copy(context, "pre_challenge").get("ok", false): return ""
	var kind := str(context.kind)
	if kind == "solo":
		return "dating.solo.%s.day%d.pre_challenge" % [context.participants[0], int(context.day)]
	if int(context.day) not in [2, 6]: return ""
	return "dating.%s.priscilla_lavinia.day%d.pre_challenge" % [
		"twofriends" if kind == "twofriends_if_deferred" else "group", int(context.day)]

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
	elif normalized == "ja": copy = ["%d日目", "開始の準備ができました。", "チャレンジ完了。"]
	elif normalized == "ko": copy = ["%d일째", "시작할 준비가 되었습니다.", "도전 완료."]
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
var _scene_art: SCENE_ART_VIEW
var _challenge_content: ScrollContainer
var _challenge_panel: VBoxContainer
var _challenge_band := Vector2i.ZERO
var _challenge_layout_pending := false
var _split_dragging := false
var _status_label: Label
var _continue_button: Button
var _special_mine_button: Button
var _mode_buttons: Array[Button] = []
var _rules_button: Button
var _view_footer: HBoxContainer
var _physical_view: Dictionary = {}
var _input_owner: Object
var _locale: String = "en"
var _percent: int = 100
var _large_cells: bool = false
var _palette: StringName = &"after_hours"
var _high_contrast: bool = false
var _colour_preset: String = "standard"
var _font_style := "pixel"
var _dispatching: bool = false
var _choice_released := false
var _preparation_failed := false
## dwm-634.2: a refused `settle` waits for Retry instead of being re-sent every frame.
var _settlement_failed := false
var _narrative_phase := ""
var _narrative_started := false
var _narrative_failed := false
var _narrative_retry_requested := false
var _narrative_attachment_failed := false
var _boundary_failed := false
var _advance_contacts: Dictionary = {}
var _advance_contact_key := ""


var _presentation_port: Object = null
var _presentation_command: Dictionary = {}
var _view_profile: Object
var _quick_commands: Node
var _confirmation: Control
var _quick_status_rect := Rect2()

@onready var dating_background: TextureRect = %DatingBackground
@onready var character_zone_left: Control = %CharacterZoneLeft
@onready var character_zone_center: Control = %CharacterZoneCenter
@onready var character_zone_right: Control = %CharacterZoneRight
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var challenge_overlay_host: Control = %ChallengeOverlayHost

func _ready() -> void:
	if not is_presentation_configured() or not _presentation_port.has_method("pull_physical"): return
	var pulled: Dictionary = _presentation_port.pull_physical(_presentation_command)
	if not pulled.get("ok", false): return
	_physical_view = pulled.value.duplicate(true)
	if _presentation_port.has_method("attach_narrative_presentation"):
		var attached: Dictionary = _presentation_port.attach_narrative_presentation(_presentation_command)
		_narrative_attachment_failed = not attached.get("ok", false)
		if _narrative_attachment_failed:
			_narrative_failed = true
			_narrative_phase = str(_physical_view.phase)
	_build_challenge()
	_refresh_challenge()
	# Provisional Observer interactions are suspended; see dwm-6gk.


## Off-tree composition installs only the canonical run's Backup port. Gallery
## rehearsal configures presentation services alone and never receives this door.
func configure_quick_commands(port: Object, bridge: Object, session_owner: Object) -> Dictionary:
	if _quick_commands != null or is_node_ready():
		return _fail(&"quick_already_configured", "")
	var candidate := QUICK_COMMANDS.new()
	if not candidate.configure_dating(self, port, _input_owner, bridge, session_owner):
		candidate.free()
		return _fail(&"quick_owners_unavailable", "")
	_quick_commands = candidate
	add_child(candidate)
	return {"ok": true}


func present_quick_confirmation(request: Dictionary, accept: Callable, cancel: Callable) -> Dictionary:
	if is_instance_valid(_confirmation) or not is_instance_valid(_quick_commands):
		return _fail(&"confirmation_already_active", "")
	_confirmation = QuickConfirmation.new()
	_confirmation.input_owner = _input_owner
	_confirmation.request = request.duplicate(true)
	_confirmation.theme = request.get("theme", theme)
	_confirmation.finished.connect(func(accepted: bool):
		_confirmation = null
		(accept if accepted else cancel).call())
	challenge_overlay_host.add_child(_confirmation)
	_quick_commands.retain_contacts()
	return {"ok": true, "value": {"confirmation": _confirmation}}


func quick_status_safe_rect() -> Rect2:
	return _quick_status_rect


func _quick_blocks_gameplay() -> bool:
	return is_instance_valid(_quick_commands) and _quick_commands.blocks_gameplay()


## Input/accessibility settings are composition-owned. This scene never looks up autoloads.
func configure_presentation_services(input_owner: Object, locale: String = "en", percent: int = 100,
		large_cells: bool = false, palette: StringName = &"after_hours", high_contrast: bool = false,
		colour_preset: String = "standard", view_profile: Object = null) -> Dictionary:
	if _input_owner != null and _input_owner != input_owner:
		return _fail(&"presentation_services_already_configured", "input owner replacement refused")
	_input_owner = input_owner
	if is_instance_valid(_view_profile) and _view_profile.has_signal("preference_changed") and _view_profile.is_connected("preference_changed", _on_font_style_changed):
		_view_profile.disconnect("preference_changed", _on_font_style_changed)
	_view_profile = view_profile
	_font_style = str(_view_profile.get_preference("preferences.accessibility.font_style", "pixel")) if _view_profile != null else "pixel"
	if _view_profile != null and _view_profile.has_signal("preference_changed"):
		_view_profile.connect("preference_changed", _on_font_style_changed)
	_locale = locale.replace("_", "-")
	_percent = percent
	_large_cells = large_cells
	_palette = palette
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	if is_instance_valid(worksheet):
		if not worksheet.bind_view_preferences(_view_profile, "challenge"):
			return _fail(&"invalid_challenge_presentation", "view preferences unavailable")
		if not worksheet.configure(str(_physical_view.host), _locale, _percent, _large_cells,
				_palette, _challenge_band, _high_contrast, _colour_preset, _font_style, int(_presentation_command.context.day)):
			return _fail(&"invalid_challenge_presentation", "unsupported presentation settings")
		if input_owner != null and not worksheet.grid.configure_input(input_owner):
			return _fail(&"invalid_challenge_input", "input contract incomplete")
		worksheet.get_parent().theme = worksheet.theme
		_refresh_challenge()
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

func _on_font_style_changed(path: StringName, _value: Variant) -> void:
	if path != &"preferences.accessibility.font_style": return
	configure_presentation_services(_input_owner, _locale, _percent, _large_cells,
		_palette, _high_contrast, _colour_preset, _view_profile)

func _build_challenge() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_node("DatingRoot").hide()
	challenge_overlay_host.show()
	var backdrop := ColorRect.new()
	backdrop.color = Color("151920") if _palette == &"after_hours" else Color("d5d4ce")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_overlay_host.add_child(backdrop)
	_scene_art = SCENE_ART_VIEW.new()
	_scene_art.name = "SceneArt"
	challenge_overlay_host.add_child(_scene_art)
	_scene_art.split_changed.connect(_on_challenge_split_changed)
	_scene_art.split_drag_changed.connect(_on_challenge_split_drag_changed)
	_scene_art.set_split_input_admission(_is_split_input_admitted)
	var center := ScrollContainer.new()
	_challenge_content = center
	center.name = "ChallengeContent"
	# Do not let the previous worksheet width become the pane's minimum width.
	center.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	center.follow_focus = true
	challenge_overlay_host.add_child(center)
	var panel := VBoxContainer.new()
	_challenge_panel = panel
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 10)
	center.add_child(panel)
	panel.resized.connect(_queue_challenge_layout)
	center.resized.connect(_queue_challenge_layout)
	var title := Label.new()
	title.name = "ChallengeTitle"
	title.text = presentation_copy(_presentation_command.context, "pre_challenge", _locale).value.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(title)
	worksheet = WORKSHEET.new()
	worksheet.name = "DatingWorksheet"
	worksheet.bind_view_preferences(_view_profile, "challenge")
	worksheet.configure(str(_physical_view.host), _locale, _percent, _large_cells,
		_palette, Vector2i.ZERO, _high_contrast, _colour_preset, _font_style, int(_presentation_command.context.day))
	if _input_owner != null: worksheet.grid.configure_input(_input_owner)
	panel.theme = worksheet.theme
	_scene_art.theme = worksheet.theme
	panel.add_child(worksheet)
	worksheet.cell_action_requested.connect(_on_cell_action)
	var toolbar := HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(toolbar)
	for mode: String in ["flag", "drag"]:
		var button: Button = FLAG_BUTTON.new() if mode == "flag" else Button.new()
		button.name = mode.capitalize()
		button.set_meta("mode", mode)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(120, 40)
		button.pressed.connect(_select_mode.bind(mode))
		toolbar.add_child(button)
		_mode_buttons.append(button)
	worksheet.information_closed.connect(_refresh_challenge)
	worksheet.grid.mode_changed.connect(func(_mode: StringName): _refresh_mode_controls())
	_rules_button = Button.new()
	_rules_button.name = "Rules"
	_rules_button.custom_minimum_size = Vector2(120, 40)
	_rules_button.pressed.connect(func():
		worksheet.open_rules(_rules_button)
		_refresh_mode_controls())
	toolbar.add_child(_rules_button)
	_special_mine_button = Button.new()
	_special_mine_button.name = "SpecialMine"
	_special_mine_button.text = "\u25c6"
	_special_mine_button.custom_minimum_size = Vector2(64, 40)
	_special_mine_button.pressed.connect(_dispatch_action.bind("special_mine", -1))
	toolbar.add_child(_special_mine_button)
	_status_label = Label.new()
	_status_label.name = "ChallengeStatus"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_status_label)
	_continue_button = Button.new()
	_continue_button.name = "ContinueChallenge"
	_continue_button.custom_minimum_size = Vector2(0, 44)
	_continue_button.pressed.connect(_on_continue)
	panel.add_child(_continue_button)
	_view_footer = HBoxContainer.new()
	_view_footer.name = "ChallengeViewFooter"
	_view_footer.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(_view_footer)
	worksheet.set_footer_host(_view_footer)
	_queue_challenge_layout()

func _refresh_challenge() -> void:
	if not is_instance_valid(worksheet) or _physical_view.is_empty(): return
	worksheet.present(_physical_view.board)
	var phase: String = str(_physical_view.phase)
	var terminal := bool(_physical_view.get("board", {}).get("terminal", false))
	var contact_key := phase + (":terminal" if terminal else "")
	if contact_key != _advance_contact_key:
		_advance_contact_key = contact_key
		_advance_contacts = _input_owner.get_physical_contacts() if is_instance_valid(_input_owner) else {}
	_scene_art.configure_entry(scene_art_entry(_presentation_command.context), _percent, true)
	worksheet.visible = phase in ["challenge", "cleared_awaiting_terminal_choice", "preparing"]
	_challenge_panel.alignment = BoxContainer.ALIGNMENT_BEGIN if worksheet.visible else BoxContainer.ALIGNMENT_CENTER
	_challenge_panel.size_flags_vertical = Control.SIZE_FILL if worksheet.visible else Control.SIZE_EXPAND_FILL
	_scene_art.theme = worksheet.theme
	_on_challenge_split_changed(_scene_art.get_right_rect())
	var face := StyleBoxFlat.new()
	face.bg_color = worksheet.get_theme_color("habitat", "Minesweeper")
	face.content_margin_left = 12.0
	face.content_margin_top = 12.0
	face.content_margin_right = 12.0
	face.content_margin_bottom = 12.0
	_challenge_content.add_theme_stylebox_override("panel", face)
	_status_label.visible = phase != "preparing" or _preparation_failed
	var copy: Dictionary = presentation_copy(_presentation_command.context,
		"post_challenge" if _physical_view.phase in ["post_challenge", "completed"] else "pre_challenge", _locale)
	var title: Label = _status_label.get_parent().get_node("ChallengeTitle")
	title.text = copy.value.title
	# Challenge chrome uses the worksheet habitat across both presentation palettes.
	var ink: Color = worksheet.get_theme_color("primary_dark_copy", "Minesweeper")
	title.add_theme_color_override("font_color", ink)
	_status_label.add_theme_color_override("font_color", ink)
	_refresh_mode_controls()
	_view_footer.visible = worksheet.visible
	_view_footer.custom_minimum_size.y = WORKSHEET.view_controls_height(_locale, worksheet.theme, _large_cells)
	_special_mine_button.visible = false
	_special_mine_button.disabled = true
	_special_mine_button.accessibility_name = _ui_text("Special mine")
	_special_mine_button.tooltip_text = _ui_text("Special mine")
	_continue_button.visible = phase in ["settlement_retry", "checkpoint_retry"] \
		or _preparation_failed or _settlement_failed or _narrative_failed or _boundary_failed
	_continue_button.text = _ui_text("Retry")
	title.visible = worksheet.visible
	_challenge_content.visible = worksheet.visible or _continue_button.visible
	match phase:
		"pre_challenge", "post_challenge", "completed": _status_label.text = _ui_text("Try again.") if _narrative_failed or _boundary_failed else ""
		"challenge": _status_label.text = _ui_text("Retry to finish processing the result.") if _settlement_failed else _ui_text("Reveal, flag, or drag to explore the board.")
		"cleared_awaiting_terminal_choice": _status_label.text = _ui_text("Board cleared.")
		"preparing": _status_label.text = _ui_text("Try again.") if _preparation_failed else ""
		"checkpoint_retry": _status_label.text = _ui_text("The attempt is saved. Retry to finish saving this point.")
		"settlement_retry": _status_label.text = _ui_text("Retry to finish processing the result.")
		_: _status_label.text = str(copy.value.body)
	_refresh_challenge_input()
	_queue_challenge_layout()

func _on_challenge_split_changed(right_rect: Rect2) -> void:
	if not is_instance_valid(_challenge_content): return
	_challenge_content.position = right_rect.position
	_challenge_content.size = right_rect.size
	_quick_status_rect = Rect2()
	if is_instance_valid(_quick_commands):
		# Reserve one inert shell band; status never covers board, Rules or footer.
		_challenge_content.size.y = maxf(0.0, right_rect.size.y - 64.0)
		_quick_status_rect = Rect2(right_rect.position + Vector2(24, _challenge_content.size.y),
			Vector2(maxf(0.0, right_rect.size.x - 48.0), 64))
	_queue_challenge_layout()

func _queue_challenge_layout() -> void:
	if _challenge_layout_pending: return
	_challenge_layout_pending = true
	_layout_challenge.call_deferred()

func _layout_challenge() -> void:
	_challenge_layout_pending = false
	if not is_inside_tree() or not is_instance_valid(worksheet) or not worksheet.is_inside_tree() \
			or not is_instance_valid(_challenge_content): return
	var scroll_bar := _challenge_content.get_v_scroll_bar()
	var width := floori((_challenge_content.size.x - 24.0 - (scroll_bar.size.x if scroll_bar.visible else 0.0)) / 2.0) * 2
	if width <= 128: return
	_challenge_panel.custom_minimum_size.x = width
	var chrome_height := 24.0
	var visible_count := 0
	for child: Control in _challenge_panel.get_children():
		if not child.visible: continue
		visible_count += 1
		if child == worksheet: continue
		child.size.x = width
		chrome_height += child.get_combined_minimum_size().y
	chrome_height += maxi(0, visible_count - 1) * _challenge_panel.get_theme_constant("separation")
	# Measure the complete Rules row, including its header, Return button and rail.
	# Tall copy scrolls the host instead of shrinking fonts or refusing Rules.
	var minimum_height: int = WORKSHEET.SHEET.minimum_rules_height(worksheet.theme, _locale, _large_cells, width)
	var band := Vector2i(width / 2, maxi(minimum_height / 2, floori((_challenge_content.size.y - chrome_height) / 2.0)))
	if band == _challenge_band: return
	if worksheet.configure(str(_physical_view.host), _locale, _percent, _large_cells,
			_palette, band, _high_contrast, _colour_preset, _font_style, int(_presentation_command.context.day)):
		_challenge_band = band

func _is_split_input_admitted() -> bool:
	if _quick_blocks_gameplay(): return false
	return is_visible_in_tree() and can_process() and not get_tree().paused \
		and _physical_view.get("phase") not in ["pre_challenge", "post_challenge", "completed"] \
		and (not is_instance_valid(_input_owner) or _input_owner.is_source_input_admitted())

func _on_challenge_split_drag_changed(active: bool) -> void:
	_split_dragging = active
	if not is_instance_valid(worksheet): return
	_refresh_challenge_input()
	_refresh_mode_controls()
	_special_mine_button.disabled = active or not bool(_physical_view.get("special_mine_enabled", false))

func _refresh_challenge_input() -> void:
	var blocked: bool = _split_dragging
	worksheet.set_interaction_blocked(blocked)
	_continue_button.disabled = blocked

func _refresh_mode_controls() -> void:
	var active: bool = _physical_view.get("phase") == "challenge"
	var document_open: bool = worksheet.information_sheet != null
	var copy := CHROME_COPY.get_copy(_locale)
	for button: Button in _mode_buttons:
		var mode := str(button.get_meta("mode"))
		button.visible = active
		if mode == "flag":
			button.configure(copy.flag, worksheet.theme, _large_cells, 80)
			button.present_state(active and not document_open and not _split_dragging, worksheet.grid.mode == &"flag")
			button.accessibility_name = copy.flag + ": " + copy[String(worksheet.grid.mode)]
			button.tooltip_text = button.accessibility_name
		else:
			button.text = copy[mode]
			button.disabled = not active or document_open or _split_dragging
			button.set_pressed_no_signal(worksheet.grid.mode == StringName(mode))
	_rules_button.text = copy.rules
	_rules_button.visible = active
	_rules_button.disabled = not active or _split_dragging
	_rules_button.toggle_mode = true
	_rules_button.set_pressed_no_signal(document_open)
	if document_open:
		var sheet: Control = worksheet.information_sheet
		# The sheet remains part of the host's navigation, rather than a focus trap.
		sheet.return_button.focus_next = sheet.return_button.get_path_to(_rules_button)
		_rules_button.focus_previous = _rules_button.get_path_to(sheet.return_button)
		_rules_button.focus_next = _rules_button.get_path_to(sheet.rows[0])
		sheet.rows[0].focus_previous = sheet.rows[0].get_path_to(_rules_button)
	else:
		_rules_button.focus_previous = NodePath()
		_rules_button.focus_next = NodePath()

func _input(event: InputEvent) -> void:
	if is_instance_valid(_quick_commands):
		_quick_commands.observe_input(event)
		if _quick_commands.handle_input(event):
			get_viewport().set_input_as_handled()
			return
	if _quick_blocks_gameplay(): return
	if _split_dragging or _physical_view.get("phase") != "cleared_awaiting_terminal_choice" or not _choice_released \
			or not is_visible_in_tree() or not event.is_pressed() or get_tree().paused: return
	if not (event is InputEventKey or event is InputEventJoypadButton): return
	var directional := false
	for action: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		directional = directional or event.is_action_pressed(action)
	if not directional: return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == _continue_button: worksheet.grid.grab_focus()
	elif focused == worksheet.grid: _continue_button.grab_focus()
	else: return
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	# Quick Load consent retains the exact physical boundary, including a painted
	# terminal board whose automatic settlement would otherwise run below.
	if _quick_blocks_gameplay(): return
	# dwm-634.2: a terminal click paints first; its settlement runs here on the next processed
	# frame and waits for neither window focus nor a held contact, because it is a durable save.
	# A save taken before it runs commits the painted board as unsettled (flush_pending_attempt).
	if _physical_view.get("phase") == "challenge" and _physical_view.get("board") is Dictionary \
			and bool(_physical_view.board.get("terminal", false)):
		if not _settlement_failed: _dispatch_action("settle", -1)
		return
	if _physical_view.get("phase") == "preparing":
		if not _preparation_failed and not get_tree().paused and get_window().has_focus():
			_dispatch_action("prepare", -1)
		return
	if not _phase_input_released() or _boundary_failed: return
	var phase := str(_physical_view.get("phase", ""))
	if phase in ["pre_challenge", "post_challenge"]:
		_pump_narrative_phase(_narrative_retry_requested)
	elif phase in ["cleared_awaiting_terminal_choice", "completed"]:
		_dispatch_action("resume_completion" if phase == "completed" else "continue", -1)

## Settlement never waits for input release. The next dialogue/board does, so one held
## pointer/key/controller activation cannot clear the board and consume its first line.
func _phase_input_released() -> bool:
	if _quick_blocks_gameplay(): return false
	if not is_visible_in_tree() or get_tree().paused or _split_dragging: return false
	if DisplayServer.get_name() != "headless" and not get_window().has_focus(): return false
	if is_instance_valid(_input_owner) and _input_owner.has_method("is_source_input_admitted") \
			and not _input_owner.is_source_input_admitted(): return false
	var contacts: Dictionary = _input_owner.get_physical_contacts() if is_instance_valid(_input_owner) else {}
	for contact: String in _advance_contacts.keys():
		if contacts.get(contact) != _advance_contacts[contact]: _advance_contacts.erase(contact)
	return _advance_contacts.is_empty() and contacts.is_empty()

func _pump_narrative_phase(retry: bool = false) -> void:
	var phase := str(_physical_view.get("phase", ""))
	if phase not in ["pre_challenge", "post_challenge"] or not _phase_input_released(): return
	if phase != _narrative_phase:
		_narrative_phase = phase
		_narrative_started = false
		_narrative_failed = false
	if _narrative_failed and not retry: return
	_narrative_retry_requested = false
	var refresh_needed := _narrative_failed or not _narrative_started or retry
	if _narrative_attachment_failed:
		var attached: Dictionary = _presentation_port.attach_narrative_presentation(_presentation_command)
		_narrative_attachment_failed = not attached.get("ok", false)
		if _narrative_attachment_failed:
			_refresh_challenge()
			return
	var played: Dictionary
	if not _presentation_port.has_method("begin_narrative_phase") or not _presentation_port.has_method("pull_narrative_phase"):
		played = {"ok": false, "code": &"dating_narrative_unavailable"}
	elif not _narrative_started or retry:
		played = _presentation_port.begin_narrative_phase(_presentation_command, retry)
		_narrative_started = bool(played.get("ok", false))
	else:
		played = _presentation_port.pull_narrative_phase(_presentation_command)
	_narrative_failed = not played.get("ok", false)
	if _narrative_failed:
		_refresh_challenge()
		return
	if refresh_needed: _refresh_challenge()
	if played.value.get("status") == "completed":
		_dispatch_action("continue", -1)

func _select_mode(mode: String) -> void:
	if _split_dragging: return
	if mode == "flag": mode = "reveal" if worksheet.grid.mode == &"flag" else "flag"
	if worksheet.set_mode(StringName(mode)): _refresh_mode_controls()

func _on_cell_action(action: StringName, index: int, revision: int) -> void:
	if _split_dragging: return
	if _physical_view.get("phase") == "cleared_awaiting_terminal_choice" and not _choice_released: return
	_dispatch_action(str(action), index, revision)

func _on_continue() -> void:
	if _split_dragging: return
	var phase: String = str(_physical_view.get("phase", ""))
	if phase in ["pre_challenge", "post_challenge"]:
		if not _narrative_failed and not _boundary_failed: return
		_boundary_failed = false
		_narrative_retry_requested = true
		_pump_narrative_phase(true)
		return
	if phase in ["cleared_awaiting_terminal_choice", "completed"]:
		_boundary_failed = false
		return
	if phase == "preparing":
		_preparation_failed = false
		_dispatch_action("prepare", -1)
		return
	if phase == "challenge" and _settlement_failed:
		_settlement_failed = false
		_dispatch_action("settle", -1)
		return
	_dispatch_action("retry" if phase in ["settlement_retry", "checkpoint_retry"] else (
		"resume_completion" if phase == "completed" else "continue"), -1)

func _dispatch_action(action: String, index: int, revision: int = -1) -> void:
	if _quick_blocks_gameplay(): return
	if _split_dragging and action == "special_mine": return
	if _dispatching or _physical_view.is_empty(): return
	_dispatching = true
	var expected: int = int(_physical_view.board.revision) if revision < 0 else revision
	var result: Dictionary = _presentation_port.dispatch_physical(_presentation_command, action, index, expected)
	_dispatching = false
	if result.get("ok", false): _boundary_failed = false
	# Completion may synchronously remove this scene; do not republish its stale projection.
	if not is_inside_tree() or is_queued_for_deletion(): return
	var pulled: Dictionary = _presentation_port.pull_physical(_presentation_command)
	if pulled.get("ok", false):
		_physical_view = pulled.value.duplicate(true)
		if _physical_view.get("phase") != "challenge": _settlement_failed = false
		_refresh_challenge()
	if not result.get("ok", false):
		if action == "prepare":
			_preparation_failed = true
			_refresh_challenge()
		elif action == "settle":
			_settlement_failed = true
			_refresh_challenge()
		else:
			_boundary_failed = true
			_refresh_challenge()


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


func _ui_text(english: String) -> String:
	return str(DRAFT_UI_COPY.get(_locale.replace("_", "-"), {}).get(english, english))
