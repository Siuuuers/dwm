extends Label
## One shell-owned, noninteractive Quick voice. Placement/collision belongs to the host.
signal status_announced(text: String)
const PRESENTATION := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const COPY := {
	"en": {&"saving":"Saving…",&"saved":"Saved",&"unavailable":"Unavailable",&"please_wait":"Please wait"},
	"zh-CN": {&"saving":"正在保存…",&"saved":"已保存",&"unavailable":"不可用",&"please_wait":"请稍候"},
	"zh-HK": {&"saving":"正在儲存…",&"saved":"已儲存",&"unavailable":"不可用",&"please_wait":"請稍候"},
	"ja": {"saving": "保存中…", "saved": "保存しました", "unavailable": "利用できません", "please_wait": "お待ちください"},
	"ko": {"saving": "저장 중…", "saved": "저장했어요", "unavailable": "이용할 수 없어요", "please_wait": "잠시 기다려 주세요"},
}
const VALIDATION_INTERVAL := 0.25
var key: StringName = &""
var current_binding: Dictionary:
	get: return _binding.duplicate(true)
var remaining_seconds := 0.0
var _binding: Dictionary = {}
var _validator := Callable()
var _eligible := false
var _announced := false
var _generation := 0
var _validation_elapsed := 0.0
var _locale := "en"

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_live = DisplayServer.LIVE_OFF
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	max_lines_visible = -1
	clip_text = false
	hide()
	set_presentation("en",100)

func _ready() -> void:
	if _eligible: _show_current()

func publish_status(next_key: StringName, binding: Dictionary, validator: Callable) -> void:
	if not COPY.en.has(next_key) or not validator.is_valid() or validator.get_argument_count() != 0:
		clear_status()
		return
	if key == next_key and _binding == binding:
		_validator = validator
		if _eligible: _show_current()
		return
	clear_status()
	key = next_key
	_binding = binding.duplicate(true)
	_validator = validator
	remaining_seconds = 2.0 if key == &"saved" else (0.0 if key == &"saving" else 4.0)
	if _eligible: _show_current()

func clear_status() -> void:
	_generation += 1
	key = &""
	_binding.clear()
	_validator = Callable()
	_announced = false
	_validation_elapsed = 0.0
	remaining_seconds = 0.0
	accessibility_live = DisplayServer.LIVE_OFF
	text = ""
	accessibility_name = ""
	hide()

func set_eligible(eligible: bool) -> void:
	if _eligible == eligible: return
	_eligible = eligible
	_validation_elapsed = 0.0
	if not eligible:
		accessibility_live = DisplayServer.LIVE_OFF
		hide()
	else: _show_current()

func set_presentation(locale: String, percent: int, font_style: String = "pixel") -> void:
	var normalized := locale.replace("_","-")
	if not COPY.has(normalized) or percent not in [100,125,150] or font_style not in ["pixel","readable"]: return
	_locale = normalized
	accessibility_live = DisplayServer.LIVE_OFF
	theme = PRESENTATION.build(_locale,percent,&"after_hours",0.0,false,"standard",font_style)
	if not key.is_empty() and _announced:
		text = COPY[_locale][key]
		accessibility_name = text

func _process(delta: float) -> void:
	advance_eligible_time(delta)

func advance_eligible_time(delta: float) -> void:
	if not is_finite(delta) or delta < 0 or not _eligible or key.is_empty(): return
	if not visible or not _announced:
		_show_current()
		return # Never charge the interval before first publication.
	if not is_visible_in_tree(): return
	var generation := _generation
	_validation_elapsed += delta
	if _validation_elapsed >= VALIDATION_INTERVAL:
		_validation_elapsed = 0.0
		if not _validate_current(): return
	if generation != _generation or not _eligible: return
	if key != &"saving":
		remaining_seconds = maxf(0.0,remaining_seconds-delta)
		if remaining_seconds == 0: clear_status()

func _validate_current() -> bool:
	var generation := _generation
	var valid: Variant = _validator.call() if _validator.is_valid() else false
	if generation != _generation: return false
	if typeof(valid) != TYPE_BOOL or not valid:
		clear_status()
		return false
	return true

func _show_current() -> void:
	if key.is_empty() or not _eligible or not is_inside_tree(): return
	var parent_item := get_parent() as CanvasItem
	if parent_item != null and not parent_item.is_visible_in_tree(): return
	if not _validate_current() or not _eligible: return
	# Parent visibility is part of actual publication, not merely local `visible`.
	show()
	if not is_visible_in_tree(): return
	if _announced: return
	_announced = true
	accessibility_live = DisplayServer.LIVE_OFF
	text = ""
	# Godot 4.6 Control.accessibility_live / DisplayServer.LIVE_POLITE.
	accessibility_live = DisplayServer.LIVE_POLITE
	text = COPY[_locale][key]
	accessibility_name = text
	status_announced.emit(text)
