extends Control
class_name MenuScene

## Menu logic: New Acc / Log in / Gallery / Setting / Shut down (prompt_docs/INDEX.md).

const BACKUP_APP_SCENE := preload("res://scenes/apps/BackupApp.tscn")
const SETTING_SCENE := preload("res://scenes/menu/Setting.tscn")
const BACKUP_PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const HOME_BUTTON := preload("res://scripts/ui/desktop/DesktopHomeButton.gd")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const CONFIRMATION := preload("res://scripts/ui/desktop/DesktopConfirmation.gd")
const BACKUP_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")
const ROUTINE_CLOCK := preload("res://scripts/ui/desktop/RoutineClock.gd")
const SHUTDOWN_COPY := {
	"en": ["Shut down?", "Close the game.", "Cancel", "Shut down"],
	"zh-CN": ["关闭游戏？", "退出游戏。", "取消", "关闭游戏"],
	"zh-HK": ["關閉遊戲？", "退出遊戲。", "取消", "關閉遊戲"],
}

@onready var _new_acc_button: Button = %NewAccButton
@onready var _log_in_button: Button = %LogInButton
@onready var _gallery_button: Button = %GalleryButton
@onready var _setting_button: Button = %SettingButton
@onready var _shut_down_button: Button = %ShutDownButton
@onready var _backup_app_host: Control = %BackupAppHost
@onready var _setting_host: Control = %SettingHost

var _backup_app_instance: Node = null
var _setting_instance: Node = null
var _title_home: Button
var _title_label: Label
var _title_status: Label
var _title_port: Object
var _confirmation: Control
var _login_result: Dictionary = {}
var _ledger_custody: Array[Dictionary] = []
var _title_strip: Control
var _clock_label: Label
var _locale := "en"
var _percent := 100

func _ready() -> void:
	_build_login_shell()
	if is_instance_valid(_new_acc_button) and not _new_acc_button.pressed.is_connected(_on_new_acc_pressed):
		_new_acc_button.pressed.connect(_on_new_acc_pressed)
	if is_instance_valid(_log_in_button) and not _log_in_button.pressed.is_connected(_on_log_in_pressed):
		_log_in_button.pressed.connect(_on_log_in_pressed)
	if is_instance_valid(_gallery_button) and not _gallery_button.pressed.is_connected(_on_gallery_pressed):
		_gallery_button.pressed.connect(_on_gallery_pressed)
	if is_instance_valid(_setting_button) and not _setting_button.pressed.is_connected(_on_setting_pressed):
		_setting_button.pressed.connect(_on_setting_pressed)
	if is_instance_valid(_shut_down_button) and not _shut_down_button.pressed.is_connected(_on_shut_down_pressed):
		_shut_down_button.pressed.connect(_on_shut_down_pressed)
	for button in _ledger_buttons():
		button.gui_input.connect(_ledger_input.bind(button))
	_update_title_destination()
	_new_acc_button.call_deferred("grab_focus")

func _on_new_acc_pressed() -> void:
	if not _can_leave_login():
		return
	# New Game runs as one atomic transaction; the prepared route participant is the
	# only opening transition (no separate SceneRouter.start_game_from_menu call).
	if not has_node("/root/SaveManager"):
		return
	var save_manager := get_node("/root/SaveManager")
	if not save_manager.has_method("start_new_run"):
		return
	var initial_context := {
		"route_id": "opening",
		"dialogic_checkpoint": {},
		"active_app_id": null,
		"audio_context": {},
		"content_version": 1,
	}
	# Phase 2R route readiness resolves synchronously; when it becomes awaited
	# (real target-scene layout readiness) this call gains `await`.
	var result: Dictionary = save_manager.start_new_run(initial_context)
	if not result.get("ok", false):
		push_warning("MenuScene: start_new_run failed (%s)." % str(result.get("code", "")))

func _on_log_in_pressed() -> void:
	if not _can_leave_login():
		return
	_close_setting()
	_backup_app_host.visible = true
	_update_title_destination()
	if is_instance_valid(_backup_app_instance):
		_backup_app_instance.show_window()
		return
	var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
	if bootstrap == null or not bootstrap.get_startup_state().get("ready", false):
		_show_login_unavailable()
		return
	_title_port = BACKUP_PORT.new()
	_login_result = _title_port.configure(get_node_or_null("/root/SaveManager"), "title")
	if not _login_result.get("ok", false):
		_show_login_unavailable()
		return
	_backup_app_instance = BACKUP_APP_SCENE.instantiate()
	_backup_app_instance.configure_title_login()
	_backup_app_instance.position = Vector2(80, 64)
	_backup_app_instance.window_hidden.connect(_close_backup_app)
	_backup_app_instance.navigation_state_changed.connect(_sync_title_navigation)
	_backup_app_host.add_child(_backup_app_instance)
	_backup_app_instance.set_confirmation_host(self)
	_backup_app_instance.configure_desktop_home(_title_home)
	_login_result = _backup_app_instance.configure_backup(_title_port,
		get_node_or_null("/root/LocalizationManager"), get_node_or_null("/root/ProfileManager"))
	_title_status.hide()
	_backup_app_instance.show_window()

func _on_gallery_pressed() -> void:
	if not _can_leave_login():
		return
	if has_node("/root/SceneRouter"):
		get_node("/root/SceneRouter").goto_scene_id("gallery")

func _on_setting_pressed() -> void:
	if not _can_leave_login():
		return
	_close_backup_app()
	if is_instance_valid(_setting_instance):
		_setting_host.visible = true
		_setting_instance.show()
		_update_title_destination()
		_setting_instance.get_node("%LanguageOption").grab_focus()
		return
	_setting_instance = SETTING_SCENE.instantiate()
	_setting_host.add_child(_setting_instance)
	_setting_instance.visibility_changed.connect(func():
		if is_instance_valid(_setting_instance) and not _setting_instance.visible and _setting_host.visible:
			_close_setting())
	_setting_host.visible = true
	_update_title_destination()
	_setting_instance.get_node("%LanguageOption").grab_focus()

func _on_shut_down_pressed() -> void:
	if not _can_leave_login():
		return
	var copy: Array = SHUTDOWN_COPY.get(_locale, SHUTDOWN_COPY.en)
	present_confirmation({"title": copy[0], "body": copy[1], "cancel": copy[2],
		"confirm": copy[3], "risk": "neutral", "warning": false,
		"theme": BACKUP_THEME.build(_locale, _percent)},
		_on_shut_down_confirmed, func(): _shut_down_button.grab_focus())

func _on_shut_down_confirmed() -> void:
	get_tree().quit()

func _close_backup_app() -> void:
	if not _can_leave_login():
		return
	var was_visible := _backup_app_host.visible
	if is_instance_valid(_backup_app_host):
		_backup_app_host.visible = false
	_update_title_destination()
	if was_visible:
		_log_in_button.grab_focus()

func _close_setting() -> void:
	if not _can_leave_login():
		return
	var was_visible := _setting_host.visible
	if is_instance_valid(_setting_host):
		_setting_host.visible = false
	_update_title_destination()
	if was_visible:
		_setting_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(_backup_app_host) and _backup_app_host.visible:
			# Backup owns recovery cancellation; one Back never closes two layers.
			if is_instance_valid(_backup_app_instance):
				_backup_app_instance._unhandled_input(event)
			else:
				_close_backup_app()
			get_viewport().set_input_as_handled()
		elif is_instance_valid(_setting_host) and _setting_host.visible:
			_close_setting()
			get_viewport().set_input_as_handled()

func _build_login_shell() -> void:
	_title_strip = Control.new()
	_title_strip.name = "TitleStrip"
	_title_strip.position = Vector2(320, 0)
	_title_strip.size = Vector2(960, 64)
	_title_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_strip)
	_title_strip.draw.connect(func():
		_title_strip.draw_rect(Rect2(0, 0, 960, 64), get_theme_color("face", "Desktop"))
		_title_strip.draw_rect(Rect2(0, 62, 960, 2), get_theme_color("structure", "Desktop")))
	_title_home = HOME_BUTTON.new()
	_title_home.name = "TitleReturn"
	_title_home.current_on_launcher = false
	_title_home.return_arrow = true
	_title_home.size = Vector2(64, 64)
	_title_home.pressed.connect(_return_from_title_host)
	_title_strip.add_child(_title_home)
	_title_label = Label.new()
	_title_label.position = Vector2(80, 0)
	_title_label.size = Vector2(696, 64)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_strip.add_child(_title_label)
	_clock_label = ROUTINE_CLOCK.new()
	_clock_label.position = Vector2(792, 0)
	_clock_label.size = Vector2(152, 64)
	_title_strip.add_child(_clock_label)
	_title_status = Label.new()
	_title_status.position = Vector2(80, 80)
	_title_status.size = Vector2(800, 96)
	_title_status.hide()
	_backup_app_host.add_child(_title_status)
	var locale := get_node_or_null("/root/LocalizationManager")
	var profile := get_node_or_null("/root/ProfileManager")
	if locale != null:
		locale.locale_changed.connect(_refresh_login_shell)
	if profile != null:
		profile.preference_changed.connect(func(_path, _value): _refresh_login_shell())
	var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
	if bootstrap != null:
		bootstrap.application_ready.connect(_refresh_login_shell)
	_refresh_login_shell()

func _refresh_login_shell(_value: String = "") -> void:
	var localization := get_node_or_null("/root/LocalizationManager")
	var locale := str(localization.get_locale()).replace("_", "-") if localization != null else "en"
	_locale = locale if SHUTDOWN_COPY.has(locale) else "en"
	var profile := get_node_or_null("/root/ProfileManager")
	var scale_value := float(profile.get_preference("preferences.accessibility.font_scale", 1.0)) if profile != null else 1.0
	_percent = 150 if scale_value >= 1.5 else (125 if scale_value >= 1.25 else 100)
	theme = DESKTOP_THEME.build(_locale, _percent)
	_title_home.theme = theme
	_title_home.accessibility_name = {"en": "Return", "zh-CN": "返回", "zh-HK": "返回"}.get(locale, "Return")
	for button in [_new_acc_button, _log_in_button, _gallery_button, _setting_button, _shut_down_button]:
		button.custom_minimum_size.y = 64
	_title_status.text = {"en": "Unavailable", "zh-CN": "不可用", "zh-HK": "不可用"}.get(locale, "Unavailable")
	_clock_label.set_presentation(_locale, _percent)
	_title_strip.queue_redraw()
	_update_title_destination()
	queue_redraw()

func _update_title_destination() -> void:
	if not is_instance_valid(_title_home):
		return
	var hosted := _backup_app_host.visible or _setting_host.visible
	_title_home.visible = hosted
	_title_home.focus_mode = Control.FOCUS_ALL if hosted and _can_leave_login() else Control.FOCUS_NONE
	_title_label.visible = hosted
	var key := "menu.login" if _backup_app_host.visible else "menu.setting"
	var localization := get_node_or_null("/root/LocalizationManager")
	_title_label.text = localization.t(key) if localization != null and localization.has_key(key) else ("Log in" if _backup_app_host.visible else "Setting")
	_update_ledger_navigation()

func _return_from_title_host() -> void:
	if _backup_app_host.visible:
		_close_backup_app()
	elif _setting_host.visible:
		_close_setting()

func _ledger_buttons() -> Array[Button]:
	var rows: Array[Button] = []
	for button in [_new_acc_button, _log_in_button, _gallery_button, _setting_button, _shut_down_button]:
		if is_instance_valid(button) and button.visible:
			rows.append(button)
	return rows

func _update_ledger_navigation() -> void:
	var rows := _ledger_buttons()
	for index in rows.size():
		var button: Button = rows[index]
		button.focus_neighbor_top = button.get_path_to(rows[maxi(0, index - 1)])
		button.focus_neighbor_bottom = button.get_path_to(rows[mini(rows.size() - 1, index + 1)])
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(_title_home if _title_home.visible else button)
		button.focus_previous = button.get_path_to(rows[posmod(index - 1, rows.size())])
		button.focus_next = button.get_path_to(rows[index + 1] if index + 1 < rows.size() else (_title_home if _title_home.visible else rows[0]))
	if _title_home.visible:
		var source: Button = _log_in_button if _backup_app_host.visible else _setting_button
		_title_home.focus_neighbor_left = _title_home.get_path_to(source)
		_title_home.focus_neighbor_top = _title_home.get_path_to(_title_home)
		_title_home.focus_neighbor_right = _title_home.get_path_to(_title_home)
		if _setting_host.visible and is_instance_valid(_setting_instance):
			var first: Control = _setting_instance.get_node("%LanguageOption")
			_title_home.focus_next = _title_home.get_path_to(first)
			_title_home.focus_neighbor_bottom = _title_home.get_path_to(first)
			_title_home.focus_previous = _title_home.get_path_to(_setting_instance.get_node("%CloseButton"))
		elif not is_instance_valid(_backup_app_instance):
			_title_home.focus_next = _title_home.get_path_to(source)
			_title_home.focus_previous = _title_home.get_path_to(source)
			_title_home.focus_neighbor_bottom = _title_home.get_path_to(_title_home)

func _ledger_input(event: InputEvent, source: Button) -> void:
	if not event.is_pressed() or not _can_leave_login():
		return
	var rows := _ledger_buttons()
	var index := rows.find(source)
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		rows[clampi(index + (-1 if event.is_action_pressed("ui_up") else 1), 0, rows.size() - 1)].grab_focus()
	elif event.is_action_pressed("ui_right"):
		if _title_home.visible:
			_title_home.grab_focus()
	elif not event.is_action_pressed("ui_left"):
		return
	get_viewport().set_input_as_handled()

func _draw() -> void:
	if theme != null:
		draw_rect(Rect2(320, 64, 960, 656), get_theme_color("habitat", "Desktop"))

func _show_login_unavailable() -> void:
	_title_status.show()
	_title_home.grab_focus()

func _can_leave_login() -> bool:
	return not is_instance_valid(_confirmation) and (not is_instance_valid(_backup_app_instance) or _backup_app_instance.can_return_home())

func _sync_title_navigation() -> void:
	# The shared sheet owns modal masks. Recovery owns this separate ledger mask;
	# neither changes whether the underlying title commands are canonically enabled.
	if is_instance_valid(_confirmation):
		return
	var blocked := not _can_leave_login()
	if blocked and _ledger_custody.is_empty():
		for button in [_new_acc_button, _log_in_button, _gallery_button, _setting_button, _shut_down_button]:
			_ledger_custody.append({"button": button, "focus": button.focus_mode, "mouse": button.mouse_filter})
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif not blocked:
		for prior in _ledger_custody:
			prior.button.focus_mode = prior.focus
			prior.button.mouse_filter = prior.mouse
		_ledger_custody.clear()

func present_confirmation(request: Dictionary, accept: Callable, cancel: Callable) -> Dictionary:
	if is_instance_valid(_confirmation):
		return {"ok": false, "code": &"confirmation_already_open"}
	_confirmation = CONFIRMATION.new()
	_confirmation.request = request.duplicate(true)
	_confirmation.theme = request.get("theme", theme)
	_confirmation.finished.connect(func(accepted: bool):
		_confirmation = null
		(accept if accepted else cancel).call()
		if is_inside_tree():
			_sync_title_navigation())
	add_child(_confirmation)
	_confirmation.get_node("ConfirmationSheet").position.x = 520
	return {"ok": true, "value": {"confirmation": _confirmation}}
