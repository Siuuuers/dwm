extends PanelContainer
class_name StatHud
## Read-only public facts. Hidden stat ranges and mechanical causes stay with GameState.

const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const COPY := {
	"en": {"day": "Day", "pressure": "Pressure", "health": "Health", "motivation": "Motivation", "money": "Money", "coins": "Coins", "condition": "Condition", "penalty": "Daily penalty", "unavailable": "Status unavailable", "condition_unavailable": "Condition unavailable", "nausea": "Nausea", "dizzy": "Dizziness", "sequela": "Aftereffects", "faint": "Fainting"},
	"zh-CN": {"day": "天数", "pressure": "压力", "health": "健康", "motivation": "动力", "money": "金钱", "coins": "硬币", "condition": "状态", "penalty": "当日惩罚", "unavailable": "状态信息不可用", "condition_unavailable": "状态不可用", "nausea": "恶心", "dizzy": "头晕", "sequela": "后遗症", "faint": "昏厥"},
	"zh-HK": {"day": "天數", "pressure": "壓力", "health": "健康", "motivation": "動力", "money": "金錢", "coins": "硬幣", "condition": "狀態", "penalty": "當日懲罰", "unavailable": "狀態資訊無法使用", "condition_unavailable": "狀態無法使用", "nausea": "噁心", "dizzy": "頭暈", "sequela": "後遺症", "faint": "昏厥"},
	"ja": {"day": "日数", "pressure": "プレッシャー", "health": "体調", "motivation": "意欲", "money": "所持金", "coins": "コイン", "condition": "状態", "penalty": "本日のペナルティ", "unavailable": "状態を表示できません", "condition_unavailable": "状態を確認できません", "nausea": "吐き気", "dizzy": "めまい", "sequela": "後遺症", "faint": "失神"},
	"ko": {"day": "일수", "pressure": "압박감", "health": "건강", "motivation": "의욕", "money": "소지금", "coins": "코인", "condition": "상태", "penalty": "오늘의 페널티", "unavailable": "상태 정보를 볼 수 없어요", "condition_unavailable": "상태를 확인할 수 없어요", "nausea": "메스꺼움", "dizzy": "어지러움", "sequela": "후유증", "faint": "실신"},
}
const CONDITION_IDS := ["nausea", "dizzy", "sequela", "faint"]
const STAT_ROWS := {"pressure": "PressureRow", "health": "HealthRow", "motivation": "MotivationRow"}
const SCROLL_NAMES := {"en": "Scroll status", "zh-CN": "滚动查看状态", "zh-HK": "捲動查看狀態",
	"ja": "状態をスクロール",
	"ko": "상태 스크롤",
}

var _owner: Object
var _localization: Object
var _profile: Object
var _configured := false
var _connections: Array[Dictionary] = []
var _locale := "en"
var _presentation_key := ""


func configure(owner: Object, localization: Object = null, profile: Object = null) -> void:
	_disconnect_sources()
	_owner = owner
	_localization = localization
	_profile = profile
	_configured = true
	if is_node_ready():
		_bind_sources()
		refresh_all()


func _ready() -> void:
	if not _configured:
		_owner = get_node_or_null("/root/GameState")
		_localization = get_node_or_null("/root/LocalizationManager")
		_profile = get_node_or_null("/root/ProfileManager")
	_bind_sources()
	%StatScroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	refresh_all()


func _exit_tree() -> void:
	_disconnect_sources()


func _bind_sources() -> void:
	for signal_name: StringName in [&"stat_changed", &"money_changed", &"coins_changed", &"day_changed", &"condition_effect_resolved", &"daily_state_reset", &"save_relevant_state_changed"]:
		_connect_source(_owner, signal_name)
	_connect_source(_localization, &"locale_changed")
	_connect_source(_profile, &"preference_changed")
	_connect_source(get_node_or_null("/root/ApplicationBootstrap"), &"application_ready")
	_connect_source(get_node_or_null("/root/SaveManager"), &"live_session_ready")


func _connect_source(source: Object, signal_name: StringName) -> void:
	if not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, refresh_all):
		source.connect(signal_name, refresh_all)
		_connections.append({"source": source, "signal": signal_name})


func _disconnect_sources() -> void:
	for connection: Dictionary in _connections:
		var source: Object = connection.source
		if is_instance_valid(source) and source.is_connected(connection.signal, refresh_all):
			source.disconnect(connection.signal, refresh_all)
	_connections.clear()


func refresh_all(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	if not is_node_ready():
		return
	_refresh_presentation()
	for child: Node in %Rows.get_children():
		_publish(child as Label, "")
	if not is_instance_valid(_owner) or not _owner.has_method("get_stat_display_value") or not _owner.has_method("get_stat_display_max"):
		_publish(%UnavailableLabel, COPY[_locale].unavailable)
		return
	var day: Variant = _owner.get("day")
	if typeof(day) != TYPE_INT or day < 1 or day > 7:
		_publish(%UnavailableLabel, COPY[_locale].unavailable)
		return
	var day_text := "%s: %d" % [COPY[_locale].day, day]
	if _locale == "ja": day_text = "%d日目" % day
	elif _locale == "ko": day_text = "%d일차" % day
	_publish(%DayLabel, day_text)
	for stat: String in STAT_ROWS:
		var value: int = _owner.get_stat_display_value(stat)
		var maximum: int = _owner.get_stat_display_max(stat)
		_publish(get_node("%" + STAT_ROWS[stat]) as Label, "%s: %d / %d" % [COPY[_locale][stat], value, maximum])
	_publish(%MoneyRow, "%s: %d" % [COPY[_locale].money, _owner.get("money")])
	_publish(%CoinRow, "%s: %d" % [COPY[_locale].coins, _owner.get("coins")])
	_refresh_conditions(_owner.get("condition_effects_today"))
	var penalty: int = _owner.get("penalty_points_today")
	if penalty != 0:
		_publish(%PenaltyLabel, "%s: %d" % [COPY[_locale].penalty, penalty])


func _refresh_conditions(conditions: Variant) -> void:
	if not conditions is Array:
		_publish(%ConditionDisplay, COPY[_locale].condition_unavailable)
		return
	var names := PackedStringArray()
	for condition: Variant in conditions:
		if condition not in CONDITION_IDS:
			_publish(%ConditionDisplay, COPY[_locale].condition_unavailable)
			return
		var public_name: String = COPY[_locale][condition]
		if public_name not in names:
			names.append(public_name)
	if not names.is_empty():
		_publish(%ConditionDisplay, "%s: %s" % [COPY[_locale].condition, (", " if _locale in ["en", "ko"] else "、").join(names)])


func _refresh_presentation() -> void:
	_locale = str(_localization.get_locale()).replace("_", "-") if is_instance_valid(_localization) and _localization.has_method("get_locale") else "en"
	if not COPY.has(_locale):
		_locale = "en"
	var percent := int(_profile.get_preference("preferences.accessibility.text_size", 100)) if is_instance_valid(_profile) and _profile.has_method("get_preference") else 100
	var high_contrast := bool(_profile.get_preference("preferences.accessibility.high_contrast", false)) if is_instance_valid(_profile) and _profile.has_method("get_preference") else false
	var colour_preset := str(_profile.get_preference("preferences.accessibility.colour_differentiation", "standard")) if is_instance_valid(_profile) and _profile.has_method("get_preference") else "standard"
	var palette: StringName = &"after_hours"
	if is_instance_valid(_owner) and _owner.has_method("get_run_configuration"):
		var configuration: Variant = _owner.get_run_configuration()
		if configuration is Dictionary and configuration.get("ok", false) and configuration.get("value") is Dictionary \
				and typeof(configuration.value.get("dark_mode")) == TYPE_BOOL:
			palette = &"midnight" if configuration.value.dark_mode else &"after_hours"
	var day: Variant = _owner.get("day") if is_instance_valid(_owner) else null
	var tint: float = WEEK_TINT.tint_for_day(int(day)) if typeof(day) == TYPE_INT else 0.0
	var presentation_key := "%s:%d:%s:%s:%s:%.2f" % [_locale, percent, palette, high_contrast, colour_preset, tint]
	if presentation_key == _presentation_key:
		return
	var next_theme: Theme = DESKTOP_THEME.build(_locale, percent, palette, tint, high_contrast, colour_preset)
	if next_theme == null: return
	_presentation_key = presentation_key
	theme = next_theme
	%StatScroll.get_v_scroll_bar().accessibility_name = SCROLL_NAMES[_locale]
	var font := FontVariation.new()
	font.base_font = theme.default_font
	font.opentype_features = {"tnum": 1}
	theme.default_font = font
	%DayLabel.add_theme_font_size_override("font_size", roundi(theme.default_font_size * (4.0 / 3.0 if _locale in ["ja", "ko"] else 1.16)))
	var day_spacing := StyleBoxEmpty.new()
	day_spacing.content_margin_bottom = 6
	%DayLabel.add_theme_stylebox_override("normal", day_spacing)
	var panel := StyleBoxFlat.new()
	panel.bg_color = theme.get_color("habitat", "Desktop")
	panel.bg_color.a = 1.0 if high_contrast else 0.74
	panel.border_color = theme.get_color("structure" if high_contrast else "ink", "Desktop")
	panel.border_color.a = 1.0 if high_contrast else 0.32
	panel.set_border_width_all(1)
	panel.border_width_top = 2
	panel.set_corner_radius_all(12)
	if not high_contrast:
		panel.shadow_color = Color(0, 0, 0, 0.2)
		panel.shadow_size = 10
		panel.shadow_offset = Vector2(0, 4)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	add_theme_stylebox_override("panel", panel)


func _publish(label: Label, value: String) -> void:
	label.text = value
	label.accessibility_name = value
	label.accessibility_description = ""
	label.visible = not value.is_empty()
