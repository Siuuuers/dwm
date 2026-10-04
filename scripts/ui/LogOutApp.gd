extends PanelContainer
class_name LogOutApp
## Confirmed Logout saves the current desktop before retiring its live session.
signal window_hidden

@onready var confirm_label: Label = %ConfirmLabel
@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton
var _exit: Object
var _locale := "en"
var _busy := false
var _home: Button

func _ready() -> void:
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(hide_window)

func configure_exit(owner: Object, locale: String) -> Dictionary:
	if owner == null or not owner.has_method("return_to_title"):
		return {"ok": false, "code": &"logout_unavailable"}
	_exit = owner
	_locale = locale if locale in ["en", "zh-CN", "zh-HK", "ja", "ko"] else "en"
	confirm_label.text = {"en": "Save your progress and log out?", "zh-CN": "保存进度并登出？", "zh-HK": "儲存進度並登出？", "ja": "進行状況を保存してログアウトしますか？", "ko": "진행 상황을 저장하고 로그아웃할까요?"}[_locale]
	return {"ok": true}

func configure_desktop_home(button: Button) -> void: _home = button
func can_return_home() -> bool: return not _busy
func show_window() -> void:
	show()
	no_button.grab_focus()
func hide_window() -> void:
	if _busy: return
	hide()
	window_hidden.emit()

func _on_yes_pressed() -> void:
	if _busy or _exit == null: return
	_busy = true
	yes_button.disabled = true
	no_button.disabled = true
	var result: Dictionary = _exit.return_to_title(true)
	if result.get("ok", false): return
	# A post-retirement route failure admits only retrying the same confirmed exit.
	_busy = result.get("code") == &"exit_route_retry_required"
	confirm_label.text = {"en": "Log out could not finish. Please try again.",
		"zh-CN": "暂时无法登出。请重试。", "zh-HK": "暫時無法登出。請重試。", "ja": "ログアウトを完了できませんでした。再試行してください。", "ko": "로그아웃을 완료하지 못했습니다. 다시 시도하세요."}[_locale]
	yes_button.disabled = false
	no_button.disabled = _busy
	# Keep navigation blocked after retirement while allowing the same Yes command.
	if _busy:
		yes_button.pressed.disconnect(_on_yes_pressed)
		yes_button.pressed.connect(_retry_exit)

func _retry_exit() -> void:
	var result: Dictionary = _exit.return_to_title(true)
	if not result.get("ok", false): yes_button.grab_focus()
