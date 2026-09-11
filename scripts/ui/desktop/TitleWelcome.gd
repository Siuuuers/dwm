extends Control
## Title-only presentation. Busy copy describes the current operation, never a guessed percentage.

const TITLE_FONT := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const BUSY_COPY := {
	"en": {"preparing": "Preparing your account", "starting": "Starting your desktop", "retrying": "Resuming startup"},
	"zh-CN": {"preparing": "正在准备账户", "starting": "正在启动桌面", "retrying": "正在恢复启动"},
	"zh-HK": {"preparing": "正在準備帳戶", "starting": "正在啟動桌面", "retrying": "正在恢復啟動"},
}
var wordmark: Label
var welcome: Label
var status: Label
var _locale := "en"
var _stage := ""
var _dot_started_us := 0
var _dot_count := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	wordmark = _label("Wordmark", Vector2(104, 140), Vector2(752, 204))
	wordmark.text = "DWM"
	wordmark.add_theme_font_override("font", TITLE_FONT)
	welcome = _label("Welcome", Vector2(112, 344), Vector2(744, 84))
	welcome.text = "Welcome! :)"
	welcome.add_theme_font_override("font", TITLE_FONT)
	status = _label("StartupStatus", Vector2(112, 472), Vector2(744, 120))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_presentation(_locale, 100)

func _label(node_name: String, at: Vector2, extent: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func set_presentation(locale: String, percent: int) -> void:
	_locale = locale if BUSY_COPY.has(locale) else "en"
	if not is_instance_valid(wordmark): return
	wordmark.add_theme_font_size_override("font_size", 144)
	welcome.add_theme_font_size_override("font_size", int(32 * percent / 100.0))
	status.add_theme_font_size_override("font_size", int(24 * percent / 100.0))
	wordmark.add_theme_color_override("font_color", get_theme_color("ink", "Desktop"))
	welcome.add_theme_color_override("font_color", get_theme_color("ink", "Desktop"))
	status.add_theme_color_override("font_color", get_theme_color("ink", "Desktop"))
	set_busy(_stage)
	queue_redraw()

func set_busy(stage: String) -> void:
	if _stage != stage:
		_dot_started_us = Time.get_ticks_usec()
		_dot_count = 1
	_stage = stage
	set_process(not stage.is_empty())
	_refresh_status()

func _process(_delta: float) -> void:
	# Engine delta is clamped after a slow frame. Keep feedback on wall-clock cadence
	# so save work cannot leave the first dot advancing in slow motion afterwards.
	var count := 1 + int((Time.get_ticks_usec() - _dot_started_us) / 350000.0) % 3
	if count != _dot_count:
		_dot_count = count
		_refresh_status()

func _refresh_status() -> void:
	if not is_instance_valid(status): return
	var copy: String = BUSY_COPY[_locale].get(_stage, "")
	status.visible = not copy.is_empty()
	status.text = copy + ".".repeat(_dot_count) if status.visible else ""

func _draw() -> void:
	draw_rect(Rect2(112, 444, 144, 2), get_theme_color("focus", "Desktop"))
	draw_rect(Rect2(260, 444, 484, 2), get_theme_color("structure", "Desktop"))
