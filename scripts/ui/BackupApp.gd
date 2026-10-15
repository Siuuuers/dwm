extends AppWindowBase
class_name BackupApp
signal navigation_state_changed()

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const DRAWER := preload("res://scripts/ui/backup/BackupDrawer.gd")
const KEY := preload("res://scripts/ui/backup/BackupKey.gd")
const BACKUP_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")
const LOCATORS := ["autosave", "quick", "slot:1", "slot:2", "slot:3", "slot:4", "slot:5", "slot:6", "slot:7"]
# Cloud Label matrix: English Autosave147px; Japanese older-state360px.
# A180px text measure plus two4px edges is the smallest even common width.
const DRAWER_WIDTH := DRAWER.MINIMUM_SIZE.x
const DRAWER_HEIGHT := DRAWER.MINIMUM_SIZE.y
const DRAWER_GAP := 8.0
const BODY_MARGIN := 14.0
const RIGHT_X := BODY_MARGIN + 3.0 * DRAWER_WIDTH + 2.0 * DRAWER_GAP + 16.0
const RIGHT_MARGIN := BODY_MARGIN
const RIGHT_MIN_WIDTH := 176.0
const BODY_MIN_WIDTH := RIGHT_X + RIGHT_MIN_WIDTH + RIGHT_MARGIN
const BODY_PREFERRED_WIDTH := RIGHT_X + 304.0 + RIGHT_MARGIN
const MAIN_HEIGHT := 544.0
const ACTION_GAP := 16.0
const COMPACT_COPY := {
	"ja": {"save": "保存", "load": "読込", "autosave": "自動", "quick": "Q保存", "slot": "保存 {n}"},
	"ko": {"load": "로드", "autosave": "자동", "quick": "퀵 저장"},
}
const COPY := {
	"ja": {"save": "セーブ","load": "ロード","delete": "削除","cancel": "キャンセル","retry": "再試行","overwrite": "上書き","autosave": "オートセーブ","quick": "クイックセーブ","slot": "セーブ {n}","empty": "空き","unavailable": "利用不可","day": "{day}日目 · {time}","automatic": "オートセーブは自動で作成されます。","fallback": "以前の互換性のあるチェックポイントのみロードできます。","load_unavailable": "現在、このセーブはロードできません。","no_compatible": "互換性のあるチェックポイントがありません。","newer": "より新しいゲームバージョンが必要です。","unreadable": "このセーブは読み取れません。","save_unavailable": "現在はセーブできません。","saved": "セーブしました","failed": "処理に失敗しました。","stale": "セーブが変更されました。","failure_details": "処理が完了しませんでした。キャンセルするか、現在のセーブ情報を確認して再試行してください。","overwrite_title": "{record}を上書きしますか？","delete_title": "{record}を削除しますか？","load_title": "{record}をロードしますか？","fallback_title": "以前のチェックポイントをロードしますか？","replace_progress": "現在の未保存の進行状況は置き換えられます。","delete_body": "このセーブは削除されます。","older": "旧バージョンのセーブ","older_details": "古いバージョンのセーブのためロードできません。","replaceable": "「セーブ」で現在のゲームをこのセーブに上書きできます。"},
	"ko": {"save": "저장","load": "불러오기","delete": "삭제","cancel": "취소","retry": "다시 시도","overwrite": "덮어쓰기","autosave": "자동 저장","quick": "빠른 저장","slot": "저장 {n}","empty": "비어 있음","unavailable": "사용 불가","day": "{day}일째 · {time}","automatic": "자동 저장은 자동으로 생성됩니다.","fallback": "이전의 호환되는 체크포인트만 불러올 수 있습니다.","load_unavailable": "현재 이 저장을 불러올 수 없습니다.","no_compatible": "호환되는 체크포인트가 없습니다.","newer": "더 최신 게임 버전이 필요합니다.","unreadable": "이 저장을 읽을 수 없습니다.","save_unavailable": "지금은 저장할 수 없습니다.","saved": "저장 완료","failed": "작업에 실패했습니다.","stale": "저장이 변경되었습니다.","failure_details": "작업이 완료되지 않았습니다. 취소하거나 현재 저장 정보를 확인한 뒤 다시 시도하세요.","overwrite_title": "{record}을(를) 덮어쓸까요?","delete_title": "{record}을(를) 삭제할까요?","load_title": "{record}을(를) 불러올까요?","fallback_title": "이전 체크포인트를 불러올까요?","replace_progress": "현재 게임의 저장하지 않은 진행 상황이 대체됩니다.","delete_body": "이 저장이 삭제됩니다.","older": "이전 버전의 저장","older_details": "이전 버전에서 만든 저장이므로 불러올 수 없습니다.","replaceable": "저장을 선택하면 현재 게임으로 이 저장을 덮어쓸 수 있습니다."},
	"en": {"save":"Save","load":"Load","delete":"Delete","cancel":"Cancel","retry":"Retry","overwrite":"Overwrite","autosave":"Autosave","quick":"Quick","slot":"Slot {n}","empty":"Empty","unavailable":"Unavailable","day":"Day {day} · {time}","automatic":"Autosave is created automatically.","fallback":"Only an earlier compatible checkpoint can be loaded.","load_unavailable":"This save cannot currently be loaded.","no_compatible":"No compatible checkpoint is available.","newer":"Newer game version required.","unreadable":"Can't read this save.","older":"Older save","older_details":"This save is from an older build and cannot be loaded.","replaceable":"Choose Save to replace it with your current game.","save_unavailable":"Saving is currently unavailable.","saved":"Saved","failed":"Operation failed.","stale":"Save changed.","failure_details":"The operation did not complete. Cancel or try again using current record details.","overwrite_title":"Overwrite {record}?","delete_title":"Delete {record}?","load_title":"Load {record}?","fallback_title":"Load earlier checkpoint?","replace_progress":"Unsaved progress in the current game will be replaced.","delete_body":"This save will be deleted."},
	"zh-CN": {"save":"保存","load":"载入","delete":"删除","cancel":"取消","retry":"重试","overwrite":"覆盖","autosave":"自动存档","quick":"快速存档","slot":"存档 {n}","empty":"空","unavailable":"不可用","day":"第 {day} 天 · {time}","automatic":"自动存档由系统自动创建。","fallback":"只能载入较早的兼容检查点。","load_unavailable":"当前无法载入此存档。","no_compatible":"没有兼容的检查点。","newer":"需要更新的游戏版本。","unreadable":"无法读取此存档。","save_unavailable":"当前无法保存。","saved":"已保存","failed":"操作失败。","stale":"存档已变更。","failure_details":"操作未完成。请取消，或根据当前存档信息重试。","overwrite_title":"覆盖{record}？","delete_title":"删除{record}？","load_title":"载入{record}？","fallback_title":"载入较早的检查点？","replace_progress":"当前游戏中未保存的进度将被替换。","delete_body":"此存档将被删除。","older":"旧版存档","older_details":"此存档来自较旧版本，无法载入。","replaceable":"选择保存，即可用当前游戏覆盖此存档。"},
	"zh-HK": {"save":"儲存","load":"載入","delete":"刪除","cancel":"取消","retry":"重試","overwrite":"覆寫","autosave":"自動存檔","quick":"快速存檔","slot":"存檔 {n}","empty":"空","unavailable":"不可用","day":"第 {day} 天 · {time}","automatic":"自動存檔由系統自動建立。","fallback":"只能載入較早的相容檢查點。","load_unavailable":"目前無法載入此存檔。","no_compatible":"沒有相容的檢查點。","newer":"需要更新的遊戲版本。","unreadable":"無法讀取此存檔。","save_unavailable":"目前無法儲存。","saved":"已儲存","failed":"操作失敗。","stale":"存檔已變更。","failure_details":"操作未完成。請取消，或根據目前存檔資訊重試。","overwrite_title":"覆寫{record}？","delete_title":"刪除{record}？","load_title":"載入{record}？","fallback_title":"載入較早的檢查點？","replace_progress":"目前遊戲中未儲存的進度將被取代。","delete_body":"此存檔將被刪除。","older":"舊版存檔","older_details":"此存檔來自較舊版本，無法載入。","replaceable":"選擇儲存，即可用目前遊戲覆寫此存檔。"},
}

var mode_buttons: Dictionary = {}
var drawer_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var active_mode := "save"
var selected_locator := "slot:1"
var info_scroll: ScrollContainer
var status_region: Control
var status_label: Label
var action_dock: Control
var confirmation: Control
var last_result: Dictionary = {}
var _info_text: Label
var _info_margin: MarginContainer
var _info_overlay: Control
var _body: Control
var _port: Object
var _localization: Object
var _profile: Object
var _home: Button
var _confirmation_host: Object
var _records: Dictionary = {}
var _locale := "en"
var _percent := 100
var _font_style := "pixel"
var _action_layout_queued := false
var _run_palette: StringName = &"after_hours"
var _day: Variant = 1
var _scene_presentation := false
var _pending_presentation := false
var _ready_result := {"ok": false, "code": &"backup_unconfigured"}
var _pending_token: Variant
var _source_action := ""
var _confirmation_kind := "none"
var _recovering := false
var _in_operation := false
var _status_key := ""
var _saved_focus := "drawer:slot:1"
var _measure_revision := 0
var _projection_valid := false
var _retry_enabled := false
var _title_login := false

func configure_title_login() -> void:
	# Set before mounting: title has one load mode and no phantom mode controls.
	_title_login = true
	active_mode = "load"

func _exit_tree() -> void:
	if _pending_token != null and is_instance_valid(_port):
		_port.cancel_action(_pending_token)
	_pending_token = null

func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(BODY_MIN_WIDTH, 656)
	if _title_login:
		# Own only this content body's placement inside the unchanged title host.
		size.x = minf(BODY_PREFERRED_WIDTH, get_parent().size.x)
		position.x = floorf((get_parent().size.x - size.x) / 4.0) * 2.0
	else:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	$VBoxContainer/TopBar.hide()
	$VBoxContainer.add_theme_constant_override("separation", 0)
	_content_host.custom_minimum_size = Vector2(BODY_MIN_WIDTH, 656)
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme = BACKUP_THEME.build_scene(_locale, _percent, _run_palette) if _scene_presentation else BACKUP_THEME.build(_locale, _percent, _run_palette, _day)
	_body = Control.new()
	_body.name = "BackupBody"
	_body.size = Vector2(BODY_MIN_WIDTH, 656)
	_content_host.add_child(_body)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.draw.connect(_draw_body)
	for index in (0 if _title_login else 2):
		var mode: String = ["save", "load"][index]
		var key := KEY.new()
		key.name = mode.to_pascal_case() + "Mode"
		key.position = Vector2(16 + index * 112, 16)
		key.size = Vector2(96, 64)
		key.set_caption(_t(mode))
		key.pressed.connect(_set_mode.bind(mode))
		key.gui_input.connect(_mode_input.bind(mode))
		_body.add_child(key)
		mode_buttons[mode] = key
	for index in LOCATORS.size():
		var locator: String = LOCATORS[index]
		var drawer := DRAWER.new()
		drawer.name = "Drawer" + str(index)
		drawer.position = Vector2(BODY_MARGIN + (index % 3) * (DRAWER_WIDTH + DRAWER_GAP), (16 if _title_login else 96) + (index / 3) * (DRAWER_HEIGHT + DRAWER_GAP))
		drawer.size = Vector2(DRAWER_WIDTH, DRAWER_HEIGHT)
		drawer.pressed.connect(_select_drawer.bind(locator))
		drawer.focus_entered.connect(_select_drawer.bind(locator))
		_body.add_child(drawer)
		drawer_buttons[locator] = drawer
	info_scroll = ScrollContainer.new()
	info_scroll.name = "InformationViewport"
	info_scroll.position = Vector2(RIGHT_X, 16 if _title_login else 96)
	info_scroll.size = Vector2(304, 336)
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	info_scroll.gui_input.connect(_information_input)
	_body.add_child(info_scroll)
	_info_margin = MarginContainer.new()
	_info_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		_info_margin.add_theme_constant_override("margin_" + edge, 12)
	info_scroll.add_child(_info_margin)
	_info_text = Label.new()
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_margin.add_child(_info_text)
	_info_overlay = Control.new()
	_info_overlay.position = info_scroll.position
	_info_overlay.size = info_scroll.size
	_info_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_overlay.draw.connect(_draw_information)
	_body.add_child(_info_overlay)
	info_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _info_overlay.queue_redraw())
	info_scroll.focus_entered.connect(_info_overlay.queue_redraw)
	info_scroll.focus_exited.connect(_info_overlay.queue_redraw)
	status_region = Control.new()
	status_region.name = "PinnedStatus"
	status_region.position = Vector2(RIGHT_X, 352 if _title_login else 432)
	status_region.size = Vector2(304, 96)
	_body.add_child(status_region)
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(12, 4)
	status_label.size = Vector2(280, 88)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_region.add_child(status_label)
	status_label.minimum_size_changed.connect(_queue_action_layout)
	action_dock = Control.new()
	action_dock.name = "PinnedActions"
	action_dock.position = Vector2(RIGHT_X, 448 if _title_login else 528)
	action_dock.size = Vector2(304, 112)
	_body.add_child(action_dock)
	_body.resized.connect(_layout_presentation_geometry)
	_layout_presentation_geometry()
	get_viewport().gui_focus_changed.connect(_remember_focus)
	if _port != null:
		refresh_view()

## A owns admission and action custody. Validate the public presentation snapshot
## before replacing services, dismissing consent or changing any installed view.
func configure_scene_backup(port: Object, localization: Object = null,
		profile: Object = null, palette: StringName = &"after_hours") -> Dictionary:
	if _pending_token != null or is_instance_valid(confirmation) or _in_operation or _recovering:
		return {"ok": false, "code": &"backup_busy"}
	for method in ["get_projection", "prepare_action", "commit_action", "cancel_action"]:
		if not is_instance_valid(port) or not port.has_method(method):
			return {"ok": false, "code": &"invalid_backup_port"}
	if (localization != null and (not is_instance_valid(localization) or not localization.has_method("get_locale"))) or (
		profile != null and (not is_instance_valid(profile) or not profile.has_method("get_preference"))):
		return {"ok": false, "code": &"invalid_backup_presentation"}
	var candidate := _presentation_candidate(palette, null, localization, profile, true)
	if candidate.is_empty():
		return {"ok": false, "code": &"invalid_backup_presentation"}
	var result: Variant = port.get_projection()
	var next := _projection_records(result, true)
	if next.is_empty():
		return {"ok": false, "code": &"invalid_backup_projection"}
	# The validated snapshot is adopted once, without a second port read.
	for binding in [[_port, "projection_changed", refresh_view],
			[_localization, "locale_changed", _on_locale_changed],
			[_profile, "preference_changed", _on_preference_changed]]:
		var previous: Object = binding[0]
		if is_instance_valid(previous) and previous.has_signal(binding[1]) and previous.is_connected(binding[1], binding[2]):
			previous.disconnect(binding[1], binding[2])
	_port = port
	_localization = localization
	_profile = profile
	_run_palette = palette
	_day = null
	_scene_presentation = true
	_records = next
	_projection_valid = true
	_status_key = ""
	last_result = result.duplicate(true)
	for binding in [[_port, "projection_changed", refresh_view],
			[_localization, "locale_changed", _on_locale_changed],
			[_profile, "preference_changed", _on_preference_changed]]:
		var source: Object = binding[0]
		if is_instance_valid(source) and source.has_signal(binding[1]) and not source.is_connected(binding[1], binding[2]):
			source.connect(binding[1], binding[2])
	if is_node_ready():
		_apply_presentation(candidate)
	else:
		_locale = candidate.locale
		_percent = candidate.percent
		_font_style = candidate.font_style
		theme = candidate.theme
	_ready_result = {"ok": true}
	return _ready_result.duplicate(true)

func configure_backup(port: Object, localization: Object = null, profile: Object = null,
		palette: StringName = &"after_hours", day: int = 1) -> Dictionary:
	if _scene_presentation:
		return {"ok": false, "code": &"scene_presentation_active"}
	for method in ["get_projection", "prepare_action", "commit_action", "cancel_action"]:
		if port == null or not port.has_method(method):
			return {"ok": false, "code": &"invalid_backup_port"}
	if _presentation_candidate(palette, day, localization, profile).is_empty():
		return {"ok": false, "code": &"invalid_backup_presentation"}
	_run_palette = palette
	_day = day
	_port = port
	_localization = localization
	_profile = profile
	if localization != null and localization.has_signal("locale_changed") and not localization.is_connected("locale_changed", _on_locale_changed):
		localization.connect("locale_changed", _on_locale_changed)
	if profile != null and profile.has_signal("preference_changed") and not profile.is_connected("preference_changed", _on_preference_changed):
		profile.connect("preference_changed", _on_preference_changed)
	if port.has_signal("projection_changed") and not port.is_connected("projection_changed", refresh_view):
		port.connect("projection_changed", refresh_view)
	_ready_result = refresh_view() if is_node_ready() else {"ok": true}
	return _ready_result

func configure_run_presentation(palette: StringName, day: int) -> Dictionary:
	if _scene_presentation:
		return {"ok": false, "code": &"scene_presentation_active"}
	if palette == _run_palette and day == _day:
		return {"ok": true}
	var candidate: Dictionary = _presentation_candidate(palette, day, _localization, _profile)
	if candidate.is_empty():
		return {"ok": false, "code": &"invalid_backup_presentation"}
	_run_palette = palette
	_day = day
	if _pending_token != null or is_instance_valid(confirmation) or _in_operation:
		_pending_presentation = true
	elif is_node_ready():
		_apply_presentation(candidate)
	return {"ok": true}

func get_desktop_ready_result() -> Dictionary:
	return _ready_result.duplicate(true)

func configure_desktop_home(home: Button) -> void:
	_home = home
	_update_navigation()

func set_confirmation_host(host: Object) -> void:
	_confirmation_host = host

func can_return_home() -> bool:
	return not _recovering and not _in_operation and not is_instance_valid(confirmation)

## Pause may enter the real in-run cabinet from an external semantic command.
## An empty mode preserves the established Pause-row entry and its same-day view state.
func focus_entry(mode: StringName = &"") -> bool:
	if _title_login or not is_node_ready() or not is_instance_valid(_port) \
			or _in_operation or _recovering or is_instance_valid(confirmation) \
			or _pending_token != null:
		return false
	if mode != &"" and (mode not in [&"save", &"load"] or not mode_buttons.has(String(mode))):
		return false
	if mode != &"":
		active_mode = String(mode)
	show_window()
	return true

func refresh_view() -> Dictionary:
	if not is_inside_tree():
		return {"ok": false, "code": &"backup_view_unmounted"}
	if _port == null:
		return {"ok": false, "code": &"backup_unconfigured"}
	if is_instance_valid(confirmation):
		confirmation._finish(false)
	var result: Variant = _port.get_projection()
	if not result is Dictionary:
		_projection_failure()
		return {"ok": false, "code": &"invalid_backup_projection"}
	last_result = result.duplicate(true)
	if not result.get("ok", false):
		_projection_failure()
		return result
	var next := _projection_records(result, _scene_presentation)
	if next.is_empty():
		_projection_failure()
		return {"ok": false, "code": &"invalid_backup_projection"}
	_records = next
	_projection_valid = true
	if _recovering:
		_retry_enabled = bool(_records[selected_locator].actions.get(_source_action, false))
	_apply_typography()
	_refresh_presentation()
	return result

## Surface validation only: never re-admit a Save, derive a family or grant an action.
func _projection_records(result: Variant, require_family: bool) -> Dictionary:
	if not result is Dictionary or typeof(result.get("ok")) != TYPE_BOOL or not result.ok:
		return {}
	var value: Variant = result.get("value")
	if not value is Dictionary:
		return {}
	var records: Variant = value.get("records")
	if not records is Array or records.size() != LOCATORS.size():
		return {}
	var next := {}
	for index in LOCATORS.size():
		var record: Variant = records[index]
		if not record is Dictionary or record.get("locator") != LOCATORS[index] or not record.has_all(["state", "actions"]):
			return {}
		if require_family and not _scene_record_valid(record, LOCATORS[index]):
			return {}
		next[LOCATORS[index]] = record.duplicate(true)
	return next

func _scene_record_valid(record: Variant, locator: String) -> bool:
	var fields := ["locator", "state", "family", "day", "saved_time", "fallback",
		"load_family", "load_day", "load_saved_time", "reason", "actions"]
	if not record is Dictionary or record.size() != fields.size() or not record.has_all(fields):
		return false
	if record.locator != locator or record.state not in ["empty", "occupied", "unavailable"]:
		return false
	if record.family not in [null, "scene", "legacy_day"] or record.load_family not in [null, "scene", "legacy_day"]:
		return false
	if typeof(record.fallback) != TYPE_BOOL or not record.reason is String:
		return false
	for prefix in ["", "load_"]:
		if typeof(record[prefix + "day"]) not in [TYPE_NIL, TYPE_INT, TYPE_FLOAT]:
			return false
		var saved_time: Variant = record[prefix + "saved_time"]
		if saved_time != null and not saved_time is String:
			return false
		if record[prefix + "family"] == "scene" and record[prefix + "day"] != null:
			return false
	if record.fallback and record.load_saved_time != null:
		return false
	var actions: Variant = record.actions
	if not actions is Dictionary or actions.size() != 3:
		return false
	for action in ["save", "load", "delete"]:
		if typeof(actions.get(action)) != TYPE_BOOL:
			return false
	return true

func _projection_failure() -> void:
	_projection_valid = false
	_recovering = false
	_status_key = "unavailable"
	_refresh_presentation()
	status_label.text = _t("unavailable")

func _presentation_candidate(palette: StringName, day: Variant, localization: Object,
		profile: Object, scene: bool = false) -> Dictionary:
	var locale := _locale
	if localization != null:
		var requested := str(localization.get_locale()).replace("_", "-")
		if COPY.has(requested):
			locale = requested
	var percent := int(profile.get_preference("preferences.accessibility.text_size", 100)) if profile != null else 100
	var high_contrast := bool(profile.get_preference("preferences.accessibility.high_contrast", false)) if profile != null else false
	var colour_preset := str(profile.get_preference("preferences.accessibility.colour_differentiation", "standard")) if profile != null else "standard"
	var font_style := str(profile.get_preference("preferences.accessibility.font_style", "pixel")) if profile != null else "pixel"
	var candidate: Theme = BACKUP_THEME.build_scene(locale, percent, palette, high_contrast, colour_preset, font_style) if scene else BACKUP_THEME.build(locale, percent, palette, day, high_contrast, colour_preset, font_style)
	if candidate == null:
		return {}
	return {"locale": locale, "percent": percent, "font_style": font_style, "theme": candidate}

func _apply_typography(refresh_content: bool = false) -> void:
	var candidate: Dictionary = _presentation_candidate(_run_palette, _day, _localization, _profile, _scene_presentation)
	if not candidate.is_empty():
		_apply_presentation(candidate, refresh_content)

func _apply_presentation(candidate: Dictionary, refresh_content: bool = true) -> void:
	_locale = candidate.locale
	_percent = candidate.percent
	_font_style = candidate.font_style
	theme = candidate.theme
	_pending_presentation = false
	for drawer in drawer_buttons.values():
		drawer.theme = theme
		for label in [drawer.identity_label, drawer.state_label]:
			label.add_theme_font_size_override("font_size", TYPOGRAPHY.font_size(_locale, _percent, 20, _font_style))
	_info_text.add_theme_color_override("font_color", theme.get_color("paper_ink", "Backup"))
	status_label.add_theme_color_override("font_color", theme.get_color("paper_ink", "Backup"))
	_body.queue_redraw()
	_info_overlay.queue_redraw()
	if refresh_content and not _records.is_empty():
		_refresh_presentation()

func _refresh_appearance() -> void:
	if _pending_token != null or is_instance_valid(confirmation) or _in_operation:
		_pending_presentation = true
		return
	if is_node_ready():
		_apply_typography(true)

func _refresh_presentation() -> void:
	if _records.is_empty():
		return
	for locator in LOCATORS:
		var drawer: Button = drawer_buttons[locator]
		drawer.selected = locator == selected_locator
		var identity := _identity(locator)
		var identity_key := "slot" if locator.begins_with("slot:") else str(locator)
		var compact := _compact_text(identity_key, identity, {"n": locator.trim_prefix("slot:")})
		var visible_identity := _fit_caption(identity, compact, drawer.identity_label)
		drawer.present(visible_identity, _record_state(_records[locator]), _records[locator].state == "unavailable")
		drawer.accessibility_name = identity + ", " + _record_state(_records[locator])
		drawer.tooltip_text = identity if visible_identity != identity else ""
	for mode in mode_buttons:
		var button: Button = mode_buttons[mode]
		button.selected = mode == active_mode
		var full := _t(mode)
		var visible_copy := _fit_caption(full, _compact_text(mode, full), button.caption)
		button.set_caption(visible_copy)
		button.accessibility_name = full
		button.tooltip_text = full if visible_copy != full else ""
	var record: Dictionary = _records[selected_locator]
	var facts := [_identity(selected_locator), _record_state(record)]
	if selected_locator == "autosave":
		facts.append(_t("automatic"))
	if record.get("fallback", false):
		facts.append(_t("fallback"))
		facts.append(_record_time(record, true))
	if record.get("reason", "") != "":
		facts.append(_reason_text(str(record.reason)))
	if active_mode == "save" and record.state == "unavailable" and record.actions.get("save", false):
		facts.append(_t("replaceable"))
	if active_mode == "save" and not record.actions.get("save", false) and selected_locator != "autosave":
		facts.append(_t("save_unavailable"))
	if _recovering:
		facts.append(_t("failure_details"))
	_info_text.text = "\n\n".join(facts)
	status_label.text = _t(_status_key) if _status_key != "" else ""
	status_label.add_theme_color_override("font_color", theme.get_color("ink" if _recovering else "paper_ink", "Backup"))
	_build_actions()
	_measure_revision += 1
	_measure_information.call_deferred(_measure_revision)
	_body.queue_redraw()
	navigation_state_changed.emit()

func _build_actions() -> void:
	var prior_focus := ""
	for action in action_buttons:
		if action_buttons[action].has_focus():
			prior_focus = action
	for key in action_buttons.values():
		action_dock.remove_child(key)
		key.queue_free()
	action_buttons.clear()
	var actions: Array = ["save"] if active_mode == "save" else ["load", "delete"]
	if _recovering:
		actions = ["cancel", "retry"] if _retry_enabled else ["cancel"]
	var record: Dictionary = _records[selected_locator]
	for index in actions.size():
		var action: String = actions[index]
		var key := KEY.new()
		key.name = action.to_pascal_case() + "Action"
		key.position = Vector2.ZERO
		key.size = Vector2(_right_width(), 64)
		key.set_caption(_t(action if action != "retry" or _source_action == "save" and _confirmation_kind == "none" else (_source_action if _source_action != "save" else "overwrite")))
		key.add_theme_font_size_override("font_size", TYPOGRAPHY.font_size(_locale, _percent, 20, _font_style))
		key.disabled = not _projection_valid or (not record.actions.get(action, false) if not _recovering else false)
		key.focus_mode = Control.FOCUS_NONE if key.disabled else Control.FOCUS_ALL
		key.risk = "danger" if action == "load" and not _title_login else ("destructive" if action == "delete" else "neutral")
		if action == "retry":
			key.risk = "danger" if _source_action == "load" and not _title_login else ("destructive" if _source_action == "delete" or _confirmation_kind == "overwrite" else "neutral")
		key.pressed.connect(_action_pressed.bind(action))
		action_dock.add_child(key)
		key.caption.add_theme_font_size_override("font_size", TYPOGRAPHY.font_size(_locale, _percent, 20, _font_style))
		key.caption.minimum_size_changed.connect(_queue_action_layout)
		action_buttons[action] = key
	_layout_action_buttons()
	if action_buttons.has(prior_focus) and not action_buttons[prior_focus].disabled:
		action_buttons[prior_focus].grab_focus()
	_update_navigation()

func _set_mode(mode: String) -> void:
	if _title_login or not can_return_home() or mode == active_mode:
		return
	active_mode = mode
	_status_key = "" if _projection_valid else "unavailable"
	_recovering = false
	_refresh_presentation()
	mode_buttons[mode].grab_focus()

func _select_drawer(locator: String) -> void:
	if not can_return_home() or locator == selected_locator:
		return
	selected_locator = locator
	info_scroll.scroll_vertical = 0
	_status_key = "" if _projection_valid else "unavailable"
	_recovering = false
	_refresh_presentation()

func _mode_input(event: InputEvent, mode: String) -> void:
	if not can_return_home():
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		mode_buttons["load" if event.is_action_pressed("ui_right") else "save"].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		drawer_buttons[selected_locator].grab_focus()
		get_viewport().set_input_as_handled()

func _action_pressed(action: String) -> void:
	if _in_operation or is_instance_valid(confirmation) or not _projection_valid:
		return
	if _recovering != (action in ["cancel", "retry"]):
		return
	if action == "retry" and not _retry_enabled:
		return
	if action == "cancel":
		_recovering = false
		_status_key = ""
		refresh_view()
		_restore_source_focus()
		return
	if action != "retry":
		_source_action = action
	_confirmation_kind = "none"
	var prepared: Dictionary = _port.prepare_action(_source_action, selected_locator)
	last_result = prepared.duplicate(true)
	if not prepared.get("ok", false):
		_operation_failed(prepared)
		return
	var prepared_value: Variant = prepared.get("value")
	if _scene_presentation and (not prepared_value is Dictionary or not _scene_record_valid(prepared_value.get("record"), selected_locator)):
		if prepared_value is Dictionary and prepared_value.get("token") != null:
			_port.cancel_action(prepared_value.token)
		last_result = {"ok": false, "code": &"invalid_backup_projection"}
		_operation_failed(last_result)
		return
	var value: Dictionary = prepared_value
	_pending_token = value.token
	_confirmation_kind = str(value.get("confirmation_kind", "none"))
	if value.get("confirmation_required", false):
		if _confirmation_host == null:
			_port.cancel_action(_pending_token)
			_pending_token = null
			_operation_failed({"ok": false, "code": &"confirmation_host_unavailable"})
			return
		var shown: Dictionary = _confirmation_host.present_confirmation(_confirmation_copy(value.record), _on_confirmed, _on_cancelled)
		if shown.get("ok", false):
			confirmation = shown.value.confirmation
			navigation_state_changed.emit()
		else:
			_on_cancelled()
		return
	_commit_pending()

func _confirmation_copy(record: Dictionary) -> Dictionary:
	var kind := _confirmation_kind
	var title_key := "overwrite_title" if kind == "overwrite" else ("delete_title" if kind == "delete" else "load_title")
	var body := _record_time(record, true) if _source_action == "load" else _record_state(record)
	if kind == "fallback":
		title_key = "fallback_title"
		body = _t("fallback") + "\n" + _record_time(record, true)
	elif kind.begins_with("replace_progress"):
		if record.get("fallback", false):
			title_key = "fallback_title"
			body = _t("fallback") + "\n" + _record_time(record, true)
		body += "\n\n" + _t("replace_progress")
	elif kind == "delete":
		body += "\n\n" + _t("delete_body")
	return {"title": _t(title_key, {"record": _identity(selected_locator)}), "body": body,
		"cancel": _t("cancel"), "confirm": _t("overwrite" if kind == "overwrite" else _source_action),
		"risk": ("neutral" if _title_login else "danger") if _source_action == "load" else "destructive", "theme": theme}

func _on_confirmed() -> void:
	confirmation = null
	_commit_pending()

func _on_cancelled() -> void:
	confirmation = null
	if _pending_token != null:
		_port.cancel_action(_pending_token)
	_pending_token = null
	if _pending_presentation:
		_refresh_appearance()
	_measure_revision += 1
	_measure_information.call_deferred(_measure_revision)
	_restore_source_focus()
	navigation_state_changed.emit()

func _commit_pending() -> void:
	if _pending_token == null:
		return
	_in_operation = true
	var token: Variant = _pending_token
	_pending_token = null
	var result: Dictionary = await _port.commit_action(token)
	_in_operation = false
	last_result = result.duplicate(true)
	if not result.get("ok", false):
		if _pending_presentation and is_inside_tree():
			_refresh_appearance()
		_operation_failed(result)
		return
	_recovering = false
	_status_key = "saved" if _source_action == "save" else ""
	# SceneTree removes the outgoing scene immediately and frees it later.
	if is_queued_for_deletion() or not is_inside_tree():
		return
	refresh_view()
	if _pending_presentation:
		_refresh_appearance()
	_restore_source_focus()

func _operation_failed(result: Dictionary) -> void:
	_recovering = true
	_retry_enabled = false
	var current: Variant = _port.get_projection()
	var records := _projection_records(current, _scene_presentation)
	if not records.is_empty():
		_retry_enabled = bool(records[selected_locator].actions.get(_source_action, false))
	_status_key = "stale" if "stale" in str(result.get("code", "")) else "failed"
	_refresh_presentation()
	if action_buttons.has("cancel"):
		action_buttons.cancel.accessibility_description = _t("failure_details")
		action_buttons.cancel.grab_focus()

func _restore_source_focus() -> void:
	if not is_visible_in_tree() or focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED: return
	if _recovering and action_buttons.has("cancel"):
		action_buttons.cancel.grab_focus()
	elif action_buttons.has(_source_action) and not action_buttons[_source_action].disabled:
		action_buttons[_source_action].grab_focus()
	else:
		drawer_buttons[selected_locator].grab_focus()

func _measure_information(revision: int) -> void:
	if not is_inside_tree() or revision != _measure_revision or is_instance_valid(confirmation) or _in_operation:
		return
	var overflowing := _info_margin.size.y > info_scroll.size.y
	info_scroll.focus_mode = Control.FOCUS_ALL if overflowing else Control.FOCUS_NONE
	if not overflowing:
		info_scroll.scroll_vertical = 0
	_update_navigation()
	_info_overlay.queue_redraw()

func _update_navigation() -> void:
	if drawer_buttons.is_empty() or is_instance_valid(confirmation):
		return
	for key in mode_buttons.values() + drawer_buttons.values():
		key.focus_mode = Control.FOCUS_NONE if _recovering else Control.FOCUS_ALL
	if is_instance_valid(_home) and is_visible_in_tree():
		_home.focus_mode = Control.FOCUS_NONE if _recovering else Control.FOCUS_ALL
	if _recovering:
		var recovery_stops: Array[Control] = []
		if info_scroll.focus_mode == Control.FOCUS_ALL:
			recovery_stops.append(info_scroll)
		for key in action_buttons.values():
			if not key.disabled:
				recovery_stops.append(key)
		for index in recovery_stops.size():
			var control := recovery_stops[index]
			var previous := control.get_path_to(recovery_stops[posmod(index - 1, recovery_stops.size())])
			var next := control.get_path_to(recovery_stops[(index + 1) % recovery_stops.size()])
			control.focus_previous = previous
			control.focus_next = next
			control.focus_neighbor_left = previous
			control.focus_neighbor_top = previous
			control.focus_neighbor_right = next
			control.focus_neighbor_bottom = next
		return
	var mode: Button = mode_buttons[active_mode] if not _title_login else (_home if is_instance_valid(_home) else drawer_buttons.autosave)
	for key in mode_buttons.values():
		key.focus_next = key.get_path_to(drawer_buttons.autosave)
		key.focus_previous = key.get_path_to(_home) if is_instance_valid(_home) else key.get_path()
		key.focus_neighbor_bottom = key.get_path_to(drawer_buttons[selected_locator])
		key.focus_neighbor_top = key.get_path_to(_home) if is_instance_valid(_home) else key.get_path()
	var after: Control = null
	if info_scroll != null and info_scroll.focus_mode == Control.FOCUS_ALL:
		after = info_scroll
	else:
		for key in action_buttons.values():
			if not key.disabled:
				after = key
				break
	for index in LOCATORS.size():
		var drawer: Button = drawer_buttons[LOCATORS[index]]
		drawer.focus_neighbor_left = drawer.get_path_to(drawer_buttons[LOCATORS[index - 1]]) if index % 3 > 0 else drawer.get_path_to(drawer)
		drawer.focus_neighbor_right = drawer.get_path_to(drawer_buttons[LOCATORS[index + 1]]) if index % 3 < 2 else drawer.get_path_to(after if after != null else drawer)
		drawer.focus_neighbor_top = drawer.get_path_to(drawer_buttons[LOCATORS[index - 3]]) if index >= 3 else drawer.get_path_to(drawer if _title_login else mode)
		drawer.focus_neighbor_bottom = drawer.get_path_to(drawer_buttons[LOCATORS[index + 3]]) if index < 6 else drawer.get_path_to(_home if is_instance_valid(_home) else drawer)
		var next: Control = drawer_buttons[LOCATORS[index + 1]] if index < 8 else (after if after != null else _home)
		drawer.focus_next = drawer.get_path_to(next if is_instance_valid(next) else drawer)
		drawer.focus_previous = drawer.get_path_to(drawer_buttons[LOCATORS[index - 1]] if index > 0 else mode)
	var stops: Array[Control] = []
	if info_scroll != null and info_scroll.focus_mode == Control.FOCUS_ALL:
		stops.append(info_scroll)
	for key in action_buttons.values():
		if not key.disabled:
			stops.append(key)
	for index in stops.size():
		var control: Control = stops[index]
		control.focus_neighbor_left = control.get_path_to(drawer_buttons[selected_locator])
		control.focus_previous = control.get_path_to(stops[index - 1] if index > 0 else drawer_buttons["slot:7"])
		control.focus_next = control.get_path_to(stops[index + 1] if index + 1 < stops.size() else (_home if is_instance_valid(_home) else control))
	if is_instance_valid(_home) and is_visible_in_tree():
		_home.focus_next = _home.get_path_to(drawer_buttons.autosave if _title_login else mode)
		_home.focus_neighbor_bottom = _home.get_path_to(drawer_buttons[selected_locator] if _title_login else mode)
		_home.focus_previous = _home.get_path_to(stops.back() if not stops.is_empty() else drawer_buttons["slot:7"])

func _information_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		info_scroll.scroll_vertical += -240 if event.keycode == KEY_PAGEUP else 240
		get_viewport().set_input_as_handled()

## True means this child consumed one retreat; false yields to its enclosing host.
func handle_back() -> bool:
	if _in_operation: return true
	if is_instance_valid(confirmation):
		confirmation._finish(false)
		return true
	if _recovering:
		_action_pressed("cancel")
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel", false):
		if not handle_back(): hide_window()
		get_viewport().set_input_as_handled()

func _remember_focus(control: Control) -> void:
	if not is_visible_in_tree() or not is_ancestor_of(control):
		return
	for mode in mode_buttons:
		if control == mode_buttons[mode]:
			_saved_focus = "mode:" + mode
	for locator in drawer_buttons:
		if control == drawer_buttons[locator]:
			_saved_focus = "drawer:" + locator
	for action in action_buttons:
		if control == action_buttons[action]:
			_saved_focus = "action:" + action
	if control == info_scroll:
		_saved_focus = "information"

func show_window() -> void:
	var focus := _saved_focus
	show()
	_status_key = ""
	_recovering = false
	refresh_view()
	if _title_login:
		selected_locator = "autosave"
		for locator in LOCATORS:
			if _records.get(locator, {}).get("actions", {}).get("load", false):
				selected_locator = locator
				break
		info_scroll.scroll_vertical = 0
		_refresh_presentation()
		drawer_buttons[selected_locator].grab_focus()
		return
	if focus.begins_with("mode:"):
		mode_buttons[active_mode].grab_focus()
	elif focus.begins_with("action:") and action_buttons.has(focus.trim_prefix("action:")) and not action_buttons[focus.trim_prefix("action:")].disabled:
		action_buttons[focus.trim_prefix("action:")].grab_focus()
	elif focus == "information" and info_scroll.focus_mode == Control.FOCUS_ALL:
		info_scroll.grab_focus()
	else:
		drawer_buttons[selected_locator].grab_focus()

func hide_window() -> void:
	if can_return_home():
		_status_key = ""
		super.hide_window()

func _on_locale_changed(_value: String) -> void:
	_refresh_appearance()

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path in [&"preferences.accessibility.font_style", &"preferences.accessibility.text_size", &"preferences.accessibility.high_contrast",
			&"preferences.accessibility.colour_differentiation"]:
		_refresh_appearance()

func _t(key: String, replacements: Dictionary = {}) -> String:
	return str(COPY[_locale].get(key, key)).format(replacements)

func _compact_text(key: String, fallback: String, replacements: Dictionary = {}) -> String:
	return str(COMPACT_COPY.get(_locale, {}).get(key, fallback)).format(replacements)

func _fit_caption(full: String, compact: String, label: Label) -> String:
	var font := label.get_theme_font("font")
	var width := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	return full if width <= label.size.x else compact

func _identity(locator: String) -> String:
	return _t("slot", {"n": locator.trim_prefix("slot:")}) if locator.begins_with("slot:") else _t(locator)

func _record_state(record: Dictionary) -> String:
	if record.get("reason") == "older_version": return _t("older")
	return _record_time(record) if record.get("state") == "occupied" else _t("empty" if record.get("state") == "empty" else "unavailable")

func _record_time(record: Dictionary, selected: bool = false) -> String:
	var prefix := "load_" if selected else ""
	var saved_time: Variant = record.get(prefix + "saved_time")
	if record.get(prefix + "family") == "legacy_day":
		return _day_time(record.get(prefix + "day"), saved_time)
	# Scene and unknown records carry no inferred calendar or authored scene title.
	return str(saved_time) if saved_time != null else "--:--"

func _day_time(day: Variant, saved_time: Variant) -> String:
	return _t("day", {"day": str(day) if day != null else "—", "time": str(saved_time) if saved_time != null else "--:--"})

func _reason_text(reason: String) -> String:
	if reason == "no_compatible_checkpoint": return _t("no_compatible")
	if reason == "restore_unavailable": return _t("load_unavailable")
	if reason == "older_version": return _t("older_details")
	if "future" in reason or "newer" in reason:
		return _t("newer")
	if "compatib" in reason or "fallback" in reason:
		return _t("fallback")
	return _t("unreadable")

func _draw_body() -> void:
	var right_width := _right_width()
	_body.draw_rect(Rect2(Vector2.ZERO, _body.size), theme.get_color("habitat", "Backup"))
	_body.draw_rect(Rect2(RIGHT_X, info_scroll.position.y, right_width, MAIN_HEIGHT), theme.get_color("paper", "Backup"))
	if _recovering:
		_body.draw_rect(Rect2(RIGHT_X, status_region.position.y, right_width, status_region.size.y), theme.get_color("face", "Backup"))
		_body.draw_rect(Rect2(RIGHT_X, status_region.position.y, 2, status_region.size.y), theme.get_color("destructive", "Backup"))
	elif _status_key == "saved":
		_body.draw_rect(Rect2(RIGHT_X, status_region.position.y, 2, status_region.size.y), theme.get_color("paper_ink", "Backup"))

func _draw_information() -> void:
	var width := _info_overlay.size.x
	var viewport_height := _info_overlay.size.y
	var content_height := _info_margin.size.y
	if content_height > viewport_height:
		var thumb := maxf(16.0, floorf(viewport_height * viewport_height / content_height / 2.0) * 2.0)
		var at := floorf((viewport_height - thumb) * info_scroll.scroll_vertical / (content_height - viewport_height) / 2.0) * 2.0
		_info_overlay.draw_rect(Rect2(width - 2, 0, 2, viewport_height), theme.get_color("structure", "Backup"))
		_info_overlay.draw_rect(Rect2(width - 2, at, 2, thumb), theme.get_color("paper_ink", "Backup"))
	if info_scroll.has_focus():
		_info_overlay.draw_rect(Rect2(3, 3, width - 6, viewport_height - 6), theme.get_color("paper_ink", "Backup"), false, 2)
		_info_overlay.draw_rect(Rect2(7, 7, width - 14, viewport_height - 14), theme.get_color("paper_focus", "Backup"), false, 2)


func _right_width() -> float:
	return maxf(RIGHT_MIN_WIDTH, _body.size.x - RIGHT_X - RIGHT_MARGIN)


func _layout_presentation_geometry() -> void:
	if not is_instance_valid(info_scroll):
		return
	var right_width := _right_width()
	info_scroll.size.x = right_width
	_info_overlay.size.x = right_width
	status_region.size.x = right_width
	status_label.size.x = right_width - 24
	action_dock.size.x = right_width
	_layout_action_buttons()
	_body.queue_redraw()
	_info_overlay.queue_redraw()


func _queue_action_layout() -> void:
	if _action_layout_queued or not is_inside_tree():
		return
	_action_layout_queued = true
	_reflow_action_buttons.call_deferred()

func _reflow_action_buttons() -> void:
	_action_layout_queued = false
	_layout_action_buttons()

func _layout_action_buttons() -> void:
	var count := action_buttons.size()
	if not is_instance_valid(action_dock):
		return
	var key_width := action_dock.size.x if count == 1 else (action_dock.size.x - ACTION_GAP) / 2.0
	var row_height := 64.0
	for key in action_buttons.values():
		# Establish wrapping width before measuring the full selected-size caption.
		key.size.x = key_width
		key._sync_caption()
		row_height = maxf(row_height, ceilf((key.caption.get_minimum_size().y + 8.0) / 2.0) * 2.0)
	# Full selected-size status/action captions own their required height. The
	# remaining inspector area is the only scroll owner; no text is capped.
	var dock_height := maxf(112.0, row_height)
	var status_height := maxf(96.0, ceilf((status_label.get_minimum_size().y + 8.0) / 2.0) * 2.0)
	var top := 16.0 if _title_login else 96.0
	var info_height := MAIN_HEIGHT - dock_height - status_height
	info_scroll.size.y = info_height
	_info_overlay.size.y = info_height
	status_region.position.y = top + info_height
	status_region.size.y = status_height
	status_label.size.y = status_height - 8.0
	action_dock.position.y = top + MAIN_HEIGHT - dock_height
	action_dock.size.y = dock_height
	_measure_revision += 1
	_measure_information.call_deferred(_measure_revision)
	_body.queue_redraw()
	_info_overlay.queue_redraw()
	# The host retains horizontal order and owns the vertical action-row space.
	var row_top := maxf(0.0, floorf((action_dock.size.y - row_height) / 2.0))
	var index := 0
	for key: Button in action_buttons.values():
		key.position = Vector2(index * (key_width + ACTION_GAP), row_top)
		key.size = Vector2(key_width, row_height)
		index += 1
