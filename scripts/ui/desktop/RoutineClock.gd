extends Label
## Read-only audience local time. No gameplay clock or background elapsed-time model.

const FONT := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const NAMES := {"en": "Local time", "zh-CN": "本地时间", "zh-HK": "本地時間",
	"ja": "現地時刻",
	"ko": "현지 시간",
}
const UNAVAILABLE := {"en": "Time unavailable", "zh-CN": "时间不可用", "zh-HK": "時間不可用",
	"ja": "時刻を表示できません",
	"ko": "시간을 표시할 수 없어요",
}

var _reader: Callable = Time.get_time_dict_from_system
var _timer: Timer
var _foreground_eligible := true
var _foreground_configured := false
var _available := false
var _locale := "en"

func _init() -> void:
	text = "--:--"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := FontVariation.new()
	font.base_font = FONT
	font.opentype_features = {"tnum": 1}
	add_theme_font_override("font", font)
	set_presentation("en", 100)

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(refresh_clock)
	add_child(_timer)
	if not _foreground_configured:
		_foreground_eligible = get_window().has_focus()
	refresh_clock()

func configure_clock(reader: Callable) -> void:
	_reader = reader
	if is_node_ready():
		refresh_clock()

func set_presentation(locale: String, percent: int) -> void:
	_locale = locale.replace("_", "-")
	if not NAMES.has(_locale):
		_locale = "en"
	var scale_percent := percent if percent in [100, 125, 150] else 100
	add_theme_font_size_override("font_size", int(24 * scale_percent / 100.0))
	_refresh_description()

func set_foreground_eligible(eligible: bool) -> void:
	_foreground_configured = true
	_foreground_eligible = eligible
	if not is_node_ready():
		return
	if eligible:
		refresh_clock()
	else:
		_timer.stop()

func refresh_clock() -> void:
	if not is_node_ready() or not _foreground_eligible:
		return
	var value: Variant = _reader.call() if _reader.is_valid() else null
	var valid := value is Dictionary
	if valid:
		for field: String in ["hour", "minute", "second"]:
			if typeof(value.get(field)) != TYPE_INT:
				valid = false
				break
	if valid:
		valid = value.hour >= 0 and value.hour < 24 and value.minute >= 0 and value.minute < 60 and value.second >= 0 and value.second < 60
	_available = valid
	text = "%02d:%02d" % [value.hour, value.minute] if valid else "--:--"
	_refresh_description()
	_timer.start(60 - int(value.second) if valid else 60)

func _refresh_description() -> void:
	accessibility_name = NAMES[_locale]
	accessibility_description = "" if _available else UNAVAILABLE[_locale]

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_foreground_eligible(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_foreground_eligible(false)
