extends PanelContainer
class_name StatHud
## Read-only public facts. Hidden stat ranges and mechanical causes stay with GameState.

const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const COPY := {
	"en": {"day": "Day", "pressure": "Pressure", "health": "Health", "motivation": "Motivation", "money": "Money", "coins": "Coins", "condition": "Condition", "penalty": "Daily penalty", "unavailable": "Status unavailable", "condition_unavailable": "Condition unavailable", "nausea": "Nausea", "dizzy": "Dizziness", "sequela": "Aftereffects", "faint": "Fainting"},
	"zh-CN": {"day": "天数", "pressure": "压力", "health": "健康", "motivation": "动力", "money": "金钱", "coins": "硬币", "condition": "状态", "penalty": "当日惩罚", "unavailable": "状态信息不可用", "condition_unavailable": "状态不可用", "nausea": "恶心", "dizzy": "头晕", "sequela": "后遗症", "faint": "昏厥"},
	"zh-HK": {"day": "天數", "pressure": "壓力", "health": "健康", "motivation": "動力", "money": "金錢", "coins": "硬幣", "condition": "狀態", "penalty": "當日懲罰", "unavailable": "狀態資訊無法使用", "condition_unavailable": "狀態無法使用", "nausea": "噁心", "dizzy": "頭暈", "sequela": "後遺症", "faint": "昏厥"},
}
const CONDITION_IDS := ["nausea", "dizzy", "sequela", "faint"]
const STAT_ROWS := {"pressure": "PressureRow", "health": "HealthRow", "motivation": "MotivationRow"}

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
	refresh_all()


func _exit_tree() -> void:
	_disconnect_sources()


func _bind_sources() -> void:
	for signal_name: StringName in [&"stat_changed", &"money_changed", &"coins_changed", &"day_changed", &"condition_effect_resolved", &"daily_state_reset", &"save_relevant_state_changed"]:
		_connect_source(_owner, signal_name)
	_connect_source(_localization, &"locale_changed")
	_connect_source(_profile, &"preference_changed")


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
	_publish(%DayLabel, "%s: %d" % [COPY[_locale].day, day])
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
		_publish(%ConditionDisplay, "%s: %s" % [COPY[_locale].condition, (", " if _locale == "en" else "、").join(names)])


func _refresh_presentation() -> void:
	_locale = str(_localization.get_locale()).replace("_", "-") if is_instance_valid(_localization) and _localization.has_method("get_locale") else "en"
	if not COPY.has(_locale):
		_locale = "en"
	var scale_value := float(_profile.get_preference("preferences.accessibility.font_scale", 1.0)) if is_instance_valid(_profile) and _profile.has_method("get_preference") else 1.0
	var percent := 150 if scale_value >= 1.5 else (125 if scale_value >= 1.25 else 100)
	var presentation_key := "%s:%d" % [_locale, percent]
	if presentation_key == _presentation_key:
		return
	_presentation_key = presentation_key
	theme = DESKTOP_THEME.build(_locale, percent)
	var font := FontVariation.new()
	font.base_font = theme.default_font
	font.opentype_features = {"tnum": 1}
	theme.default_font = font
	var panel := StyleBoxFlat.new()
	panel.bg_color = theme.get_color("habitat", "Desktop")
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	add_theme_stylebox_override("panel", panel)


func _publish(label: Label, value: String) -> void:
	label.text = value
	label.accessibility_name = value
	label.accessibility_description = ""
	label.visible = not value.is_empty()
