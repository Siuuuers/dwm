extends Control
class_name ComputerDesktop

const APP_REGISTRY := preload("res://scripts/domain/desktop/DesktopAppRegistry.gd")
const LAUNCHER_BUTTON := preload("res://scripts/ui/desktop/DesktopLauncherButton.gd")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const HOME_BUTTON := preload("res://scripts/ui/desktop/DesktopHomeButton.gd")
const BACKUP_PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const CONFIRMATION := preload("res://scripts/ui/desktop/DesktopConfirmation.gd")
const LABELS := {
	"en": ["Minesweeper", "Contacts", "Schedule", "Shop", "Backup", "Settings", "Log out"],
	"zh-CN": ["扫雷", "联系人", "日程", "商店", "备份", "设置", "退出登录"],
	"zh-HK": ["踩地雷", "聯絡人", "日程", "商店", "備份", "設定", "登出"],
}

@onready var icon_grid: GridContainer = %IconGrid
@onready var app_window_host: Control = %AppWindowHost
@onready var notification_layer: Control = %NotificationLayer
@onready var contacts_button: Button = %ContactsButton

var launcher_buttons: Dictionary = {}
var home_button: Button
var title_label: Label
var clock_label: Label
var status_label: Label
var _clock_timer: Timer
var _clock_reader: Callable
var _cached_app_windows: Dictionary = {}
var _presentation_port: Object
var _backup_port: Object
var _confirmation: Control
var _localization: Object
var _profile: Object
var _host_state: Object
var _day := 1
var _bootstrap: Node
var _active_id: StringName = &""
var _locale := "en"
var _clock_available := false
var _foreground_eligible := true
var _restoration_failed := false

func _ready() -> void:
	custom_minimum_size = Vector2(800, 720)
	app_window_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()
	_refresh_launcher()
	_foreground_eligible = get_window().has_focus()
	configure_clock(_clock_reader if _clock_reader.is_valid() else Time.get_time_dict_from_system)
	if not _foreground_eligible:
		clock_label.text = "--:--"
	_bootstrap = get_node_or_null("/root/ApplicationBootstrap")
	if _bootstrap != null:
		if not _bootstrap.application_ready.is_connected(_configure_from_bootstrap):
			_bootstrap.application_ready.connect(_configure_from_bootstrap)
		if _bootstrap.get_startup_state().get("ready", false):
			_configure_from_bootstrap()
	var state := get_node_or_null("/root/GameState")
	if state != null and not state.daily_state_reset.is_connected(_on_daily_state_reset):
		state.daily_state_reset.connect(_on_daily_state_reset)
	if state != null:
		for event in ["contact_message_unlocked", "contact_open_committed", "contact_choice_selected", "invitation_reply_committed"]:
			if state.has_signal(event) and not state.is_connected(event, _on_contacts_changed):
				state.connect(event, _on_contacts_changed)
	if _active_id == &"":
		launcher_buttons[&"minesweeper"].call_deferred("grab_focus")

func _build_shell() -> void:
	var strip := HBoxContainer.new()
	strip.name = "AppStrip"
	strip.size = Vector2(800, 64)
	strip.add_theme_constant_override("separation", 16)
	add_child(strip)
	home_button = HOME_BUTTON.new()
	home_button.name = "HomeButton"
	home_button.custom_minimum_size = Vector2(64, 64)
	home_button.pressed.connect(return_home)
	strip.add_child(home_button)
	title_label = Label.new()
	title_label.name = "CurrentTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(title_label)
	clock_label = Label.new()
	clock_label.name = "AudienceClock"
	clock_label.custom_minimum_size.x = 152
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(clock_label)
	_clock_timer = Timer.new()
	_clock_timer.one_shot = true
	_clock_timer.timeout.connect(refresh_clock)
	add_child(_clock_timer)
	icon_grid.position = Vector2(24, 88)
	icon_grid.add_theme_constant_override("h_separation", 16)
	icon_grid.add_theme_constant_override("v_separation", 16)
	var ids: Array[StringName] = APP_REGISTRY.new().get_ids()
	for index in ids.size():
		var id: StringName = ids[index]
		var button: Button = contacts_button if id == &"contacts" else LAUNCHER_BUTTON.new()
		if id != &"contacts":
			button.name = String(id).to_pascal_case() + "Button"
			icon_grid.add_child(button)
		icon_grid.move_child(button, index)
		launcher_buttons[id] = button
		button.pressed.connect(open_app.bind(id))
	for index in ids.size():
		var button: Button = launcher_buttons[ids[index]]
		var left := index - 1 if index % 4 > 0 else index
		var right := index + 1 if index % 4 < 3 and index + 1 < ids.size() else index
		var up := index - 4 if index >= 4 else index
		var down := index + 4 if index + 4 < ids.size() else index
		button.focus_neighbor_left = button.get_path_to(launcher_buttons[ids[left]])
		button.focus_neighbor_right = button.get_path_to(launcher_buttons[ids[right]])
		button.focus_neighbor_top = button.get_path_to(launcher_buttons[ids[up]])
		button.focus_neighbor_bottom = button.get_path_to(launcher_buttons[ids[down]])
		button.focus_next = button.get_path_to(launcher_buttons[ids[mini(index + 1, ids.size() - 1)]])
		button.focus_previous = button.get_path_to(launcher_buttons[ids[maxi(index - 1, 0)]])
	status_label = Label.new()
	status_label.name = "DesktopStatus"
	status_label.position = Vector2(24, 484)
	status_label.size = Vector2(752, 140)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.hide()
	add_child(status_label)

func configure_contacts(port: Object, localization: Object = null, profile: Object = null,
		host_state: Object = null, day: int = 1) -> Dictionary:
	if port == null or not port.has_method("get_projection") or not port.has_method("open_friend") or not port.has_method("reply_to_group"):
		return {"ok": false, "code": &"invalid_contacts_presentation_port"}
	if _presentation_port != null and _presentation_port != port:
		return {"ok": false, "code": &"contacts_already_configured"}
	_presentation_port = port
	_localization = localization
	_profile = profile
	_host_state = host_state
	_day = day
	if localization != null and localization.has_signal("locale_changed"):
		if not localization.is_connected("locale_changed", _on_launcher_locale_changed):
			localization.connect("locale_changed", _on_launcher_locale_changed)
	if profile != null and profile.has_signal("preference_changed"):
		if not profile.is_connected("preference_changed", _on_preference_changed):
			profile.connect("preference_changed", _on_preference_changed)
	if is_node_ready():
		_refresh_launcher()
		var restored_value: Variant = _host_state.get_state().get("active_app_id") if _host_state != null else null
		var restored := StringName(restored_value) if restored_value != null else &""
		if restored != &"":
			var result := open_app(restored)
			if not result.get("ok", false):
				_restoration_failed = true
				_active_id = restored
				icon_grid.hide()
				_refresh_launcher()
			return result
	return {"ok": true}

func open_contacts() -> Dictionary:
	return open_app(&"contacts")

func configure_backup_port(port: Object) -> Dictionary:
	for method in ["get_projection", "prepare_action", "commit_action", "cancel_action"]:
		if port == null or not port.has_method(method):
			return {"ok": false, "code": &"invalid_backup_port"}
	if _backup_port != null and _backup_port != port:
		return {"ok": false, "code": &"backup_already_configured"}
	_backup_port = port
	if is_node_ready() and _restoration_failed and _active_id == &"backup":
		return open_app(&"backup")
	return {"ok": true}

func present_confirmation(request: Dictionary, accept: Callable, cancel: Callable) -> Dictionary:
	if is_instance_valid(_confirmation):
		return {"ok": false, "code": &"confirmation_already_active"}
	_confirmation = CONFIRMATION.new()
	_confirmation.request = request.duplicate(true)
	_confirmation.theme = request.get("theme", theme)
	_confirmation.finished.connect(func(accepted: bool):
		_confirmation = null
		(accept if accepted else cancel).call())
	add_child(_confirmation)
	return {"ok": true, "value": {"confirmation": _confirmation}}

func open_app(app_id: StringName) -> Dictionary:
	var foreground: Node = _cached_app_windows.get(_active_id)
	if is_instance_valid(foreground) and foreground.has_method("can_return_home") and not foreground.can_return_home():
		return {"ok": false, "code": &"desktop_modal_active"}
	if not APP_REGISTRY.new().has_app(app_id):
		return _route_failure(&"unknown_app_id")
	if app_id not in [&"contacts", &"settings", &"backup"]:
		return _route_failure(&"desktop_app_unavailable")
	if _active_id != &"" and _active_id != app_id:
		return _route_failure(&"desktop_app_transition_unavailable")
	if _host_state != null:
		var active: Variant = _host_state.get_state().get("active_app_id")
		if active != null and active != "" and active != app_id:
			return _route_failure(&"desktop_app_transition_unavailable")
	if app_id == &"contacts" and _presentation_port == null:
		return _route_failure(&"contacts_unavailable")
	if app_id == &"backup" and _backup_port == null:
		return _route_failure(&"backup_unavailable")
	if app_id == &"settings" and (_host_state == null or get_node_or_null("/root/ProfileManager") == null or get_node_or_null("/root/LocalizationManager") == null):
		return _route_failure(&"settings_dependencies_unavailable")
	var app: Node = _cached_app_windows.get(app_id)
	if not is_instance_valid(app):
		var record: Dictionary = APP_REGISTRY.new().get_record(app_id)
		var scene := load(record.scene) as PackedScene
		if scene == null:
			return _route_failure(&"desktop_scene_unavailable")
		app = scene.instantiate()
		app.hide()
		app_window_host.add_child(app)
		var configured: Dictionary
		if app_id == &"contacts":
			configured = app.configure_presentation(_presentation_port, _localization, _profile)
		elif app_id == &"backup":
			app.set_confirmation_host(self)
			configured = app.configure_backup(_backup_port, _localization, _profile)
		else:
			configured = app.get_desktop_ready_result()
		if not configured.get("ok", false):
			app_window_host.remove_child(app)
			app.queue_free()
			return _route_failure(configured.get("code", &"desktop_app_unavailable"))
		app.configure_desktop_home(home_button)
		app.window_hidden.connect(_on_app_hidden.bind(app_id))
		_cached_app_windows[app_id] = app
	elif app_id == &"backup":
		var refreshed: Dictionary = app.refresh_view()
		if not refreshed.get("ok", false):
			return _route_failure(&"backup_unavailable")
	if _host_state != null:
		var opened: Dictionary = _host_state.open_app(app_id, _day)
		if not opened.get("ok", false):
			return _route_failure(opened.get("code", &"desktop_open_rejected"))
	_active_id = app_id
	_restoration_failed = false
	app.configure_desktop_home(home_button)
	icon_grid.hide()
	status_label.hide()
	_refresh_launcher()
	app.show_window()
	return {"ok": true, "value": {"app": app}}

func return_home() -> Dictionary:
	if _active_id == &"":
		return {"ok": true}
	var app: Node = _cached_app_windows.get(_active_id)
	if not is_instance_valid(app):
		return _route_failure(&"desktop_view_unavailable")
	if app.has_method("can_return_home") and not app.can_return_home():
		return {"ok": false, "code": &"desktop_modal_active"}
	if _host_state != null:
		var closed: Dictionary = _host_state.close_app()
		if not closed.get("ok", false):
			return _route_failure(closed.get("code", &"desktop_home_rejected"))
	var source := _active_id
	if app.has_method("remember_focus"):
		app.remember_focus()
	app.hide()
	_active_id = &""
	_restoration_failed = false
	icon_grid.show()
	status_label.hide()
	_refresh_launcher()
	launcher_buttons[source].grab_focus()
	return {"ok": true}

func _on_app_hidden(app_id: StringName) -> void:
	if _active_id != app_id:
		return
	var result := return_home()
	if not result.get("ok", false):
		_cached_app_windows[app_id].show()

func _on_daily_state_reset() -> void:
	if is_instance_valid(_confirmation):
		_confirmation._finish(false)
	for window in _cached_app_windows.values():
		if is_instance_valid(window):
			window.hide()
			window.queue_free()
	_cached_app_windows.clear()
	_active_id = &""
	_restoration_failed = false
	icon_grid.show()
	status_label.hide()
	_refresh_launcher()
	launcher_buttons[&"minesweeper"].grab_focus()

func dispatch_desktop_eviction(command: Dictionary) -> Dictionary:
	if command.get("kind") != &"evict_cached_apps" or int(command.get("day", 0)) <= 0:
		return {"ok": false, "code": &"invalid_desktop_eviction"}
	_day = int(command.day)
	_on_daily_state_reset()
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

func _configure_from_bootstrap() -> void:
	if _backup_port == null:
		var save_manager := get_node_or_null("/root/SaveManager")
		if save_manager != null:
			var port := BACKUP_PORT.new()
			if port.configure(save_manager).get("ok", false):
				configure_backup_port(port)
	if _bootstrap.has_method("configure_contacts_desktop"):
		_bootstrap.configure_contacts_desktop(self)

func _refresh_launcher() -> void:
	if _localization != null and _localization.has_method("get_locale"):
		var requested := str(_localization.get_locale()).replace("_", "-")
		if LABELS.has(requested):
			_locale = requested
	var scale_value := float(_profile.get_preference("preferences.accessibility.font_scale", 1.0)) if _profile != null and _profile.has_method("get_preference") else 1.0
	var percent := 150 if scale_value >= 1.5 else (125 if scale_value >= 1.25 else 100)
	theme = DESKTOP_THEME.build(_locale, percent)
	var ids: Array[StringName] = APP_REGISTRY.new().get_ids()
	for index in ids.size():
		var button: Button = launcher_buttons[ids[index]]
		button.theme = theme
		button.set_caption(LABELS[_locale][index])
	var home: String = {"en": "Home", "zh-CN": "主页", "zh-HK": "主頁"}[_locale]
	home_button.accessibility_name = home
	home_button.current_on_launcher = _active_id == &""
	home_button.disabled = _active_id == &"" or _restoration_failed
	home_button.focus_mode = Control.FOCUS_NONE if home_button.disabled else Control.FOCUS_ALL
	var foreground: Node = _cached_app_windows.get(_active_id)
	if is_instance_valid(_confirmation) or is_instance_valid(foreground) and foreground.has_method("can_return_home") and not foreground.can_return_home():
		home_button.focus_mode = Control.FOCUS_NONE
	title_label.text = home if _active_id == &"" else (LABELS[_locale][ids.find(_active_id)] if _active_id in ids else {"en": "Unavailable", "zh-CN": "不可用", "zh-HK": "不可用"}[_locale])
	clock_label.add_theme_font_override("font", DESKTOP_THEME.ENGLISH)
	clock_label.accessibility_name = {"en": "Local time", "zh-CN": "本地时间", "zh-HK": "本地時間"}[_locale]
	_refresh_clock_description()
	if status_label.visible:
		_set_failure_copy()
	queue_redraw()

func _route_failure(code: StringName) -> Dictionary:
	_set_failure_copy()
	status_label.show()
	return {"ok": false, "code": code}

func _set_failure_copy() -> void:
	status_label.text = {"en": "This action is currently unavailable.", "zh-CN": "此操作暂不可用。", "zh-HK": "此操作暫不可用。"}[_locale]

func _on_launcher_locale_changed(_locale_id: String) -> void:
	_refresh_launcher()

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path == &"preferences.accessibility.font_scale":
		_refresh_launcher()

func _on_contacts_changed(_result: Dictionary) -> void:
	var app: Node = _cached_app_windows.get(&"contacts")
	if is_instance_valid(app):
		app.call_deferred("refresh_view")

func configure_clock(reader: Callable) -> void:
	_clock_reader = reader
	if is_node_ready():
		refresh_clock()

func refresh_clock() -> void:
	if not _foreground_eligible:
		return
	var value: Variant = _clock_reader.call() if _clock_reader.is_valid() else {}
	var valid := value is Dictionary and typeof(value.get("hour")) == TYPE_INT and typeof(value.get("minute")) == TYPE_INT
	valid = valid and int(value.hour) >= 0 and int(value.hour) < 24 and int(value.minute) >= 0 and int(value.minute) < 60
	var second: Variant = value.get("second", 0) if value is Dictionary else 0
	valid = valid and typeof(second) == TYPE_INT and int(second) >= 0 and int(second) < 60
	_clock_available = valid
	clock_label.text = "%02d:%02d" % [value.hour, value.minute] if valid else "--:--"
	_refresh_clock_description()
	_clock_timer.start(60 - int(second) if valid else 60)

func _refresh_clock_description() -> void:
	clock_label.accessibility_description = "" if _clock_available else {"en": "Time unavailable", "zh-CN": "时间不可用", "zh-HK": "時間不可用"}[_locale]

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_foreground_eligible = true
		refresh_clock()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_foreground_eligible = false
		_clock_timer.stop()

func _draw() -> void:
	if theme == null:
		return
	draw_rect(Rect2(0, 0, 800, 720), get_theme_color("habitat", "Desktop"))
	draw_rect(Rect2(0, 0, 800, 64), get_theme_color("face", "Desktop"))
	draw_rect(Rect2(0, 62, 800, 2), get_theme_color("structure", "Desktop"))
