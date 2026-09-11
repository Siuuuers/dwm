extends Control
class_name ComputerDesktop

const APP_REGISTRY := preload("res://scripts/domain/desktop/DesktopAppRegistry.gd")
const LAUNCHER_BUTTON := preload("res://scripts/ui/desktop/DesktopLauncherButton.gd")
const ART_MANIFEST := preload("res://scripts/data/ArtManifest.gd")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const HOME_BUTTON := preload("res://scripts/ui/desktop/DesktopHomeButton.gd")
const BACKUP_PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const QUICK_COMMANDS := preload("res://scripts/ui/desktop/DesktopQuickCommands.gd")
const CONFIRMATION := preload("res://scripts/ui/desktop/DesktopConfirmation.gd")
const MINESWEEPER_GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")
const WARNING_NAVIGATION_TARGETS := {
	&"open_contacts_list": &"contacts",
	&"open_minesweeper": &"minesweeper",
}
const LABELS := {
	"en": ["Minesweeper", "Contacts", "Schedule", "Shop", "Backup", "Settings", "Log out"],
	"zh-CN": ["扫雷", "联系人", "日程", "商店", "备份", "设置", "退出登录"],
	"zh-HK": ["踩地雷", "聯絡人", "日程", "商店", "備份", "設定", "登出"],
}
const CONTACT_NAMES := {"priscilla": "Priscilla", "lavinia": "Lavinia", "sylvia": "Sylvia"}

@onready var icon_grid: GridContainer = %IconGrid
@onready var app_window_host: Control = %AppWindowHost
@onready var notification_layer: Control = %NotificationLayer
@onready var contacts_button: Button = %ContactsButton
@onready var background_image: TextureRect = $BackgroundImage
@onready var message_notification: PanelContainer = %MinesweeperMessageNotification
@onready var notification_title: Label = %NotificationTitle
@onready var notification_body: Label = %NotificationBody
@onready var notification_close: Button = %CloseButton
@onready var notification_go: Button = %GoButton

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
var _minesweeper_port: Object
var _minesweeper_input: Object
var _shop_port: Object
var _session_exit: Object
var _schedule_port: Object
var _schedule_done := Callable()
var _schedule_warning_port: Object
var _schedule_warning_commands: Object
var _confirmation: Control
var _quick_commands: Node
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
var _run_configuration_owner: Object
var _run_palette: StringName = &"after_hours"
var _run_configuration_required := false
var _run_configuration_ready := false
var _run_configuration_masked := false
var _show_after_run_configuration := false
var _warning_navigation_serial := 0
var _prepared_warning_navigation: Dictionary = {}
var _message_notification_queue: Array[Dictionary] = []
var _seen_message_notifications: Dictionary = {}

func configure_run_configuration(owner: Object) -> Dictionary:
	if not is_instance_valid(owner) or not owner.has_method("get_run_configuration") or Callable(owner,"get_run_configuration").get_argument_count() != 0:
		return {"ok":false,"code":&"invalid_run_configuration_owner"}
	if _run_configuration_owner != null and _run_configuration_owner != owner:
		return {"ok":false,"code":&"run_configuration_already_configured"}
	var result: Variant = owner.get_run_configuration()
	if typeof(result) != TYPE_DICTIONARY or typeof(result.get("ok")) != TYPE_BOOL or not result.ok or typeof(result.get("value")) != TYPE_DICTIONARY:
		return {"ok":false,"code":&"run_configuration_unavailable"}
	if result.value.size() != 1 or typeof(result.value.get("dark_mode")) != TYPE_BOOL:
		return {"ok":false,"code":&"invalid_run_configuration"}
	var palette: StringName = &"midnight" if result.value.dark_mode else &"after_hours"
	if _run_configuration_ready and palette != _run_palette:
		return {"ok":false,"code":&"run_configuration_changed"}
	if not _run_configuration_ready and not _cached_app_windows.is_empty():
		return {"ok":false,"code":&"run_configuration_bound_too_late"}
	_run_configuration_owner = owner
	_run_palette = palette
	_run_configuration_ready = true
	if is_instance_valid(home_button): _refresh_launcher()
	return {"ok":true,"code":&"ok"}


func _ready() -> void:
	custom_minimum_size = Vector2(800, 720)
	var desktop_art := ART_MANIFEST.get_texture("ui.desktop")
	if desktop_art != null:
		background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background_image.texture = desktop_art
		background_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background_image.offset_top = 64
	app_window_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_notification.mouse_filter = Control.MOUSE_FILTER_STOP
	notification_close.pressed.connect(_dismiss_message_notification)
	notification_go.pressed.connect(_open_contacts_from_notification)
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
		# The production method masks an early mount; isolated overrides retain
		# their explicit fixture configuration without opting into global owners.
		_configure_from_bootstrap()
	var saves := get_node_or_null("/root/SaveManager")
	if saves != null and saves.has_signal("live_session_ready") \
			and not saves.is_connected("live_session_ready", _configure_from_bootstrap):
		saves.connect("live_session_ready", _configure_from_bootstrap)
	var state := get_node_or_null("/root/GameState")
	if state != null and not state.daily_state_reset.is_connected(_on_daily_state_reset):
		state.daily_state_reset.connect(_on_daily_state_reset)
	if state != null:
		if state.has_signal("contact_message_unlocked") and not state.is_connected("contact_message_unlocked", _on_contact_message_unlocked):
			state.connect("contact_message_unlocked", _on_contact_message_unlocked)
		for event in ["contact_open_committed", "contact_choice_selected", "invitation_reply_committed"]:
			if state.has_signal(event) and not state.is_connected(event, _on_contacts_changed):
				state.connect(event, _on_contacts_changed)
	if _schedule_port != null and _host_state != null and _host_state.get_state().get("active_app_id") == &"schedule":
		_restore_bound_app(&"schedule")
	elif _shop_port != null and _host_state != null and _host_state.get_state().get("active_app_id") == &"shop":
		_restore_bound_app(&"shop")
	elif _active_id == &"":
		_focus_initial_launcher.call_deferred()

func _focus_initial_launcher() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or not can_process() or _active_id != &"" or _restoration_failed:
		return
	if _host_state != null and _host_state.get_state().get("active_app_id") != null: return
	var target: Control = launcher_buttons[&"minesweeper"]
	if target.is_visible_in_tree() and target.get_focus_mode_with_override() == Control.FOCUS_ALL:
		target.grab_focus()

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
		button.set_icon_texture(ART_MANIFEST.get_texture("launcher.%s" % String(id), Vector2i(48, 48)))
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
	if (_schedule_port != null or _shop_port != null) and (localization != _localization or profile != _profile or host_state != _host_state or day != _day):
		return {"ok":false,"code":&"desktop_owner_mismatch"}
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

func configure_minesweeper(port: Object, localization: Object = null, profile: Object = null,
		host_state: Object = null, day: int = 1, input_owner: Object = null) -> Dictionary:
	for method: String in ["pull","dispatch","set_foreground"]:
		if not is_instance_valid(port) or not port.has_method(method): return {"ok":false,"code":&"invalid_minesweeper_port"}
	var candidate_input: Object = input_owner if input_owner != null else get_node_or_null("/root/InputManager")
	if candidate_input != null and not MINESWEEPER_GRID.accepts_input_owner(candidate_input): return {"ok":false,"code":&"invalid_minesweeper_input"}
	if _minesweeper_port != null and (_minesweeper_port != port or _minesweeper_input != candidate_input): return {"ok":false,"code":&"minesweeper_already_configured"}
	if (_host_state != null and host_state != null and _host_state != host_state) \
			or (_localization != null and localization != null and _localization != localization) \
			or (_profile != null and profile != null and _profile != profile): return {"ok":false,"code":&"desktop_owner_mismatch"}
	if host_state == null and _host_state == null: return {"ok":false,"code":&"desktop_owner_unavailable"}
	var candidate_host: Object = host_state if host_state != null else _host_state
	for method: String in ["get_state","open_app","close_app"]:
		if not candidate_host.has_method(method): return {"ok":false,"code":&"desktop_owner_unavailable"}
	if day < 1: return {"ok":false,"code":&"desktop_owner_unavailable"}
	_minesweeper_port = port
	_minesweeper_input = candidate_input
	if host_state != null: _host_state = host_state
	if localization != null: _localization = localization
	if profile != null: _profile = profile
	_day = day
	if _localization != null and _localization.has_signal("locale_changed") and not _localization.is_connected("locale_changed",_on_launcher_locale_changed):
		_localization.connect("locale_changed",_on_launcher_locale_changed)
	if _profile != null and _profile.has_signal("preference_changed") and not _profile.is_connected("preference_changed",_on_preference_changed):
		_profile.connect("preference_changed",_on_preference_changed)
	if is_node_ready():
		_refresh_launcher()
		if _host_state.get_state().get("active_app_id") == &"minesweeper": return open_app(&"minesweeper")
	return {"ok":true}

func configure_session_exit(owner: Object) -> Dictionary:
	if owner == null or not owner.has_method("return_to_title"): return {"ok": false, "code": &"invalid_session_exit"}
	if _session_exit != null and _session_exit != owner: return {"ok": false, "code": &"session_exit_already_configured"}
	_session_exit = owner
	return {"ok": true}

func configure_shop(provider: Object, localization: Object = null, profile: Object = null,
		host_state: Object = null, day: int = 1) -> Dictionary:
	if not is_instance_valid(provider) or not provider.has_method("get_catalog") or not provider.has_signal("catalog_changed") \
			or Callable(provider,"get_catalog").get_argument_count() != 1: return {"ok":false,"code":&"invalid_shop_provider"}
	for event: Dictionary in provider.get_signal_list():
		if event.name == "catalog_changed" and not event.args.is_empty(): return {"ok":false,"code":&"invalid_shop_provider"}
	if _shop_port != null and _shop_port != provider: return {"ok":false,"code":&"shop_already_configured"}
	if (_host_state != null and host_state != null and _host_state != host_state) \
			or (_localization != null and localization != null and _localization != localization) \
			or (_profile != null and profile != null and _profile != profile): return {"ok":false,"code":&"desktop_owner_mismatch"}
	var candidate_host: Object = host_state if host_state != null else _host_state
	for method: String in ["get_state","open_app","close_app"]:
		if not is_instance_valid(candidate_host) or not candidate_host.has_method(method): return {"ok":false,"code":&"desktop_owner_unavailable"}
	if day < 1 or int(candidate_host.get_state().get("current_day",0)) != day: return {"ok":false,"code":&"desktop_owner_day_mismatch"}
	var candidate_locale: Object = localization if localization != null else _localization
	var candidate_profile: Object = profile if profile != null else _profile
	if candidate_locale != null and (not is_instance_valid(candidate_locale) or not candidate_locale.has_method("get_locale") or not candidate_locale.has_signal("locale_changed")):
		return {"ok":false,"code":&"invalid_shop_preferences"}
	if candidate_profile != null and (not is_instance_valid(candidate_profile) or not candidate_profile.has_method("get_preference") or not candidate_profile.has_signal("preference_changed")):
		return {"ok":false,"code":&"invalid_shop_preferences"}
	_shop_port = provider
	_host_state = candidate_host
	_localization = candidate_locale
	_profile = candidate_profile
	_day = day
	if _localization != null and not _localization.is_connected("locale_changed",_on_launcher_locale_changed):
		_localization.connect("locale_changed",_on_launcher_locale_changed)
	if _profile != null and not _profile.is_connected("preference_changed",_on_preference_changed):
		_profile.connect("preference_changed",_on_preference_changed)
	if is_node_ready():
		_refresh_launcher()
		if _host_state.get_state().get("active_app_id") == &"shop": return _restore_bound_app(&"shop")
	return {"ok":true}

func configure_schedule(port: Object, localization: Object = null, profile: Object = null,
		host_state: Object = null, day: int = 1, done_handler: Callable = Callable(),
		warning_presentation: Object = null, warning_commands: Object = null) -> Dictionary:
	for method: String in ["project", "append", "move", "remove"]:
		if not is_instance_valid(port) or not port.has_method(method): return {"ok":false,"code":&"invalid_schedule_port"}
	if not done_handler.is_null() and (not done_handler.is_valid() or done_handler.get_argument_count() != 0):
		return {"ok":false,"code":&"invalid_schedule_done"}
	if (warning_presentation == null) != (warning_commands == null): return {"ok":false,"code":&"invalid_schedule_warning"}
	if warning_presentation != null and (not is_instance_valid(warning_presentation) or not is_instance_valid(warning_commands)
			or not warning_presentation.has_method("project") or not warning_commands.has_method("resolve_warning")
			or Callable(warning_presentation,"project").get_argument_count() != 1
			or Callable(warning_commands,"resolve_warning").get_argument_count() != 2
			or not port.has_method("project_modal_background")): return {"ok":false,"code":&"invalid_schedule_warning"}
	if _schedule_port != null and (_schedule_port != port or _schedule_done != done_handler
			or _schedule_warning_port != warning_presentation or _schedule_warning_commands != warning_commands):
		return {"ok":false,"code":&"schedule_already_configured"}
	if (_host_state != null and host_state != null and _host_state != host_state) \
			or (_localization != null and localization != null and _localization != localization) \
			or (_profile != null and profile != null and _profile != profile): return {"ok":false,"code":&"desktop_owner_mismatch"}
	var candidate_host: Object = host_state if host_state != null else _host_state
	for method: String in ["get_state", "open_app", "close_app"]:
		if not is_instance_valid(candidate_host) or not candidate_host.has_method(method): return {"ok":false,"code":&"desktop_owner_unavailable"}
	if day < 1 or int(candidate_host.get_state().get("current_day",0)) != day: return {"ok":false,"code":&"desktop_owner_day_mismatch"}
	var candidate_locale: Object = localization if localization != null else _localization
	var candidate_profile: Object = profile if profile != null else _profile
	if candidate_locale != null and (not is_instance_valid(candidate_locale) or not candidate_locale.has_method("get_locale") or not candidate_locale.has_signal("locale_changed")):
		return {"ok":false,"code":&"invalid_schedule_preferences"}
	if candidate_profile != null and (not is_instance_valid(candidate_profile) or not candidate_profile.has_method("get_preference") or not candidate_profile.has_signal("preference_changed")):
		return {"ok":false,"code":&"invalid_schedule_preferences"}
	_schedule_port = port
	_schedule_done = done_handler
	_schedule_warning_port = warning_presentation
	_schedule_warning_commands = warning_commands
	_host_state = candidate_host
	if localization != null: _localization = localization
	if profile != null: _profile = profile
	_day = day
	if _localization != null and not _localization.is_connected("locale_changed",_on_launcher_locale_changed):
		_localization.connect("locale_changed",_on_launcher_locale_changed)
	if _profile != null and not _profile.is_connected("preference_changed",_on_preference_changed):
		_profile.connect("preference_changed",_on_preference_changed)
	if is_node_ready():
		_refresh_launcher()
		if _host_state.get_state().get("active_app_id") == &"schedule": return _restore_bound_app(&"schedule")
	return {"ok":true}

func _restore_bound_app(app_id: StringName) -> Dictionary:
	var restored := open_app(app_id)
	if not restored.get("ok",false):
		_restoration_failed = true
		_active_id = app_id
		icon_grid.hide()
		_refresh_launcher()
	return restored

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

func configure_quick_commands(port: Object, input_owner: Object, source_admission: Callable = Callable()) -> Dictionary:
	if not is_node_ready() or port != _backup_port: return {"ok": false, "code": &"quick_owner_mismatch"}
	if _quick_commands != null: return {"ok": false, "code": &"quick_already_configured"}
	var candidate := QUICK_COMMANDS.new()
	var admission := source_admission if not source_admission.is_null() else _quick_production_admitted
	if not candidate.configure(self, port, input_owner, admission):
		candidate.free()
		return {"ok": false, "code": &"quick_owners_unavailable"}
	_quick_commands = candidate
	add_child(candidate)
	return {"ok": true}

func _quick_production_admitted() -> bool:
	var scene := get_tree().current_scene
	var bridge := get_node_or_null("/root/DialogicBridge")
	return scene != null and scene.scene_file_path == "res://scenes/main/MainGameScene.tscn" \
		and scene.is_ancestor_of(self) and bridge != null and not bridge.has_active_playback() \
		and bridge.get_current_timeline_id().is_empty()

func _input(event: InputEvent) -> void:
	if is_instance_valid(_quick_commands): _quick_commands.observe_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_quick_commands) and _quick_commands.handle_input(event) and is_inside_tree():
		get_viewport().set_input_as_handled()

func quick_status_safe_rect() -> Rect2:
	# Known blank regions only. Other apps wait for their own protected-region map.
	for child: Node in notification_layer.get_children():
		if child is Control and child.is_visible_in_tree(): return Rect2()
	if _active_id == &"backup": return Rect2(480, 80, 304, 64)
	if _active_id == &"": return Rect2(24, 640, 752, 64)
	return Rect2()

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
	if _run_configuration_required and (not _run_configuration_ready or _run_configuration_masked):
		return _route_failure(&"run_configuration_unavailable")
	if is_instance_valid(_confirmation): return {"ok": false, "code": &"desktop_modal_active"}
	var foreground: Node = _cached_app_windows.get(_active_id)
	if is_instance_valid(foreground) and foreground.has_method("can_return_home") and not foreground.can_return_home():
		return {"ok": false, "code": &"desktop_modal_active"}
	if not APP_REGISTRY.new().has_app(app_id):
		return _route_failure(&"unknown_app_id")
	if app_id not in [&"contacts", &"settings", &"backup", &"minesweeper", &"schedule", &"shop", &"logout"] or (app_id == &"minesweeper" and _minesweeper_port == null):
		return _route_failure(&"desktop_app_unavailable")
	if _active_id != &"" and _active_id != app_id:
		return _route_failure(&"desktop_app_transition_unavailable")
	if _host_state != null:
		var active: Variant = _host_state.get_state().get("active_app_id")
		if active != null and active != "" and active != app_id:
			return _route_failure(&"desktop_app_transition_unavailable")
	if app_id == &"contacts" and _presentation_port == null:
		return _route_failure(&"contacts_unavailable")
	if app_id == &"logout" and _session_exit == null:
		return _route_failure(&"logout_unavailable")
	if app_id == &"shop" and _shop_port == null:
		return _route_failure(&"shop_unavailable")
	if app_id == &"schedule" and _schedule_port == null:
		return _route_failure(&"schedule_unavailable")
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
		elif app_id == &"minesweeper":
			configured = app.configure_presentation(_minesweeper_port, _localization, _profile, _minesweeper_input, _run_palette)
		elif app_id == &"logout":
			configured = app.configure_exit(_session_exit, _locale)
		elif app_id == &"shop":
			app.configure_desktop_home(home_button)
			configured = app.configure_catalog(_shop_port, _localization, _profile, _run_palette)
		elif app_id == &"schedule":
			app.configure_desktop_home(home_button)
			configured = app.configure_presentation(_schedule_port, _locale, int(theme.default_font_size * 100 / 24),
				false, _schedule_done, _run_palette, _schedule_warning_port, _schedule_warning_commands)
			if configured.get("ok",false): configured = app.configure_shared_preferences(_localization, _profile)
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
		if app_id == &"minesweeper":
			app.recovery_requested.connect(_route_failure)
			app.panel.presentation_changed.connect(status_label.hide)
		if app_id == &"shop":
			app.recovery_requested.connect(func(code: String): _route_failure(StringName(code)))
		if app_id == &"schedule":
			app.recovery_requested.connect(_route_failure)
			app.warning_foreground_changed.connect(func(_active: bool): _refresh_launcher())
			app.command_custody_changed.connect(func(_active: bool): _refresh_launcher())
		_cached_app_windows[app_id] = app
	elif app_id in [&"backup", &"minesweeper", &"schedule", &"shop"]:
		var refreshed: Dictionary = app.refresh_view()
		if not refreshed.get("ok", false):
			return _route_failure(refreshed.get("code", &"desktop_app_unavailable"))
	if app.has_method("prepare_show_window"):
		var prepared: Dictionary = app.prepare_show_window()
		if not prepared.get("ok",false): return _route_failure(prepared.get("code",&"desktop_open_rejected"))
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

## Preflights the real warning target while Schedule still owns modal custody. The detached receipt
## is retained by this desktop and is the only value commit_warning_navigation accepts.
func prepare_warning_navigation(intent: StringName) -> Dictionary:
	if not WARNING_NAVIGATION_TARGETS.has(intent):
		return _warning_navigation_fail(&"invalid_warning_navigation_intent")
	if not _prepared_warning_navigation.is_empty():
		if str(_prepared_warning_navigation["intent"]) == str(intent):
			return _warning_navigation_ok(_prepared_warning_navigation)
		return _warning_navigation_fail(&"warning_navigation_already_prepared")
	var target: StringName = WARNING_NAVIGATION_TARGETS[intent]
	var available := _warning_navigation_preflight(target)
	if not available.get("ok", false):
		return available
	_warning_navigation_serial += 1
	_prepared_warning_navigation = {
		"navigation_id": "warning-navigation-%d" % _warning_navigation_serial,
		"intent": str(intent),
		"source_app_id": "schedule",
		"target_app_id": str(target),
		"day": _day,
	}
	return _warning_navigation_ok(_prepared_warning_navigation)


## Moves the actual foreground scene before the warning controller records navigation_committed.
## A failed target open restores Schedule with its still-pending modal and returns the real code.
func commit_warning_navigation(receipt: Dictionary) -> Dictionary:
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != ["day", "intent", "navigation_id", "source_app_id", "target_app_id"] \
			or receipt != _prepared_warning_navigation:
		return _warning_navigation_fail(&"invalid_warning_navigation_receipt")
	var target := StringName(receipt["target_app_id"])
	var available := _warning_navigation_preflight(target)
	if not available.get("ok", false):
		return available
	var schedule: Node = _cached_app_windows[&"schedule"]
	var closed: Variant = _host_state.close_app()
	if typeof(closed) != TYPE_DICTIONARY or not (closed as Dictionary).get("ok", false):
		return closed as Dictionary if typeof(closed) == TYPE_DICTIONARY \
			else _warning_navigation_fail(&"desktop_home_rejected")
	schedule.hide()
	_active_id = &""
	icon_grid.show()
	_refresh_launcher()
	var opened: Dictionary = open_app(target)
	if not opened.get("ok", false):
		var restored: Variant = _host_state.open_app(&"schedule", _day)
		if typeof(restored) != TYPE_DICTIONARY or not (restored as Dictionary).get("ok", false):
			_prepared_warning_navigation = {}
			return _warning_navigation_fail(&"warning_navigation_restore_failed")
		_active_id = &"schedule"
		icon_grid.hide()
		status_label.hide()
		_refresh_launcher()
		schedule.show()
		return opened
	_prepared_warning_navigation = {}
	return {
		"ok": true,
		"code": &"ok",
		"value": {"app": opened["value"]["app"], "target_app_id": target},
		"receipt": receipt.duplicate(true),
	}


func _warning_navigation_preflight(target: StringName) -> Dictionary:
	if _run_configuration_required and (not _run_configuration_ready or _run_configuration_masked):
		return _warning_navigation_fail(&"run_configuration_unavailable")
	if is_instance_valid(_confirmation):
		return _warning_navigation_fail(&"desktop_modal_active")
	if _active_id != &"schedule" or not is_instance_valid(_host_state):
		return _warning_navigation_fail(&"desktop_app_transition_unavailable")
	var host_view: Dictionary = _host_state.get_state()
	if host_view.get("active_app_id") != &"schedule" or int(host_view.get("current_day", 0)) != _day:
		return _warning_navigation_fail(&"desktop_app_transition_unavailable")
	var schedule: Node = _cached_app_windows.get(&"schedule")
	if not is_instance_valid(schedule) or not schedule.visible \
			or not is_instance_valid(schedule.get("warning_sheet")):
		return _warning_navigation_fail(&"schedule_warning_unavailable")
	if target == &"contacts" and _presentation_port == null:
		return _warning_navigation_fail(&"contacts_unavailable")
	if target == &"minesweeper" and _minesweeper_port == null:
		return _warning_navigation_fail(&"desktop_app_unavailable")
	if target not in [&"contacts", &"minesweeper"]:
		return _warning_navigation_fail(&"desktop_app_unavailable")
	if not is_instance_valid(_cached_app_windows.get(target)):
		var record: Dictionary = APP_REGISTRY.new().get_record(target)
		if not record.get("ok", false):
			return _warning_navigation_fail(StringName(record.get("code", &"unknown_app_id")))
		if load(record["scene"]) as PackedScene == null:
			return _warning_navigation_fail(&"desktop_scene_unavailable")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func _warning_navigation_ok(receipt: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok",
		"value": {"receipt": receipt.duplicate(true)}, "receipt": receipt.duplicate(true)}


func _warning_navigation_fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": "", "details": {}}


func return_home() -> Dictionary:
	if is_instance_valid(_confirmation): return {"ok": false, "code": &"desktop_modal_active"}
	if _active_id == &"":
		return {"ok": true}
	var app: Node = _cached_app_windows.get(_active_id)
	if not is_instance_valid(app):
		return _route_failure(&"desktop_view_unavailable")
	if app.has_method("can_return_home") and not app.can_return_home():
		return {"ok": false, "code": &"desktop_modal_active"}
	if app.has_method("prepare_return_home"):
		var prepared: Dictionary = app.prepare_return_home()
		if not prepared.get("ok",false): return _route_failure(prepared.get("code",&"desktop_home_rejected"))
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

func _mask_run_configuration(code: StringName) -> void:
	if not _run_configuration_masked:
		_show_after_run_configuration = visible
	_run_configuration_masked = true
	_restoration_failed = true
	hide()
	icon_grid.hide()
	_refresh_launcher()
	_route_failure(code)

func _configure_from_bootstrap() -> void:
	_run_configuration_required = true
	if _bootstrap == null or not _bootstrap.get_startup_state().get("ready",false):
		_mask_run_configuration(&"run_configuration_unavailable")
		return
	var owner: Object = _run_configuration_owner if _run_configuration_owner != null else get_node_or_null("/root/GameState")
	var configured := configure_run_configuration(owner)
	if not configured.get("ok",false):
		_mask_run_configuration(configured.code)
		return
	var reveal_after_configuration := _run_configuration_masked and _show_after_run_configuration
	if _run_configuration_masked:
		_run_configuration_masked = false
		_restoration_failed = false
		if _active_id == &"": icon_grid.show()
		status_label.hide()
		_refresh_launcher()
	if _backup_port == null:
		var save_manager := get_node_or_null("/root/SaveManager")
		if save_manager != null:
			var port := BACKUP_PORT.new()
			if port.configure(save_manager).get("ok", false):
				configure_backup_port(port)
	if _bootstrap.has_method("configure_contacts_desktop"):
		_bootstrap.configure_contacts_desktop(self)
	if _bootstrap.has_method("configure_gameplay_desktop"):
		_bootstrap.configure_gameplay_desktop(self)
	if _bootstrap.has_method("configure_session_exit_desktop"):
		_bootstrap.configure_session_exit_desktop(self)
	if _quick_commands == null and _backup_port != null:
		configure_quick_commands(_backup_port, get_node_or_null("/root/InputManager"))
	if reveal_after_configuration and not _run_configuration_masked:
		show()
		# The first deferred request may have run while readiness kept us hidden.
		# The helper leaves restored app focus in its owning view.
		_focus_initial_launcher.call_deferred()

func _refresh_launcher() -> void:
	if _localization != null and _localization.has_method("get_locale"):
		var requested := str(_localization.get_locale()).replace("_", "-")
		if LABELS.has(requested):
			_locale = requested
	var percent := int(_profile.get_preference("preferences.accessibility.text_size", 100)) if _profile != null and _profile.has_method("get_preference") else 100
	theme = DESKTOP_THEME.build(_locale, percent, _run_palette)
	var notice_style := StyleBoxFlat.new()
	notice_style.bg_color = theme.get_color("face", "Desktop")
	notice_style.border_color = theme.get_color("structure", "Desktop")
	notice_style.set_border_width_all(2)
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		notice_style.set_content_margin(edge, 16)
	message_notification.add_theme_stylebox_override("panel", notice_style)
	_refresh_message_notification_copy()
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
	_refresh_contact_notice()
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

func _on_contact_message_unlocked(result: Dictionary) -> void:
	_on_contacts_changed(result)
	var notification_id := str(result.get("notification_id", ""))
	var friend_id := str(result.get("friend_id", ""))
	if notification_id.is_empty() or friend_id not in CONTACT_NAMES or _seen_message_notifications.has(notification_id): return
	_seen_message_notifications[notification_id] = true
	_message_notification_queue.append({"notification_id": notification_id, "friend_id": friend_id})
	_present_next_message_notification()


func _present_next_message_notification() -> void:
	if message_notification.visible or _message_notification_queue.is_empty(): return
	var entry: Dictionary = _message_notification_queue.pop_front()
	message_notification.set_meta("notification_id", entry.notification_id)
	message_notification.set_meta("friend_id", entry.friend_id)
	_refresh_message_notification_copy()
	message_notification.show()


func _refresh_message_notification_copy() -> void:
	if not message_notification.has_meta("notification_id"): return
	var friend_name := str(CONTACT_NAMES.get(str(message_notification.get_meta("friend_id", "")), ""))
	if _localization != null and _localization.has_method("t"):
		notification_title.text = _localization.t("desktop.notification.new_message_title")
		notification_body.text = _localization.t("desktop.notification.new_message_from_friend", {"friend_name": friend_name})
	else:
		notification_title.text = "New message"
		notification_body.text = "Angela received a new message from %s." % friend_name
	message_notification.accessibility_name = notification_title.text
	message_notification.accessibility_description = notification_body.text


func _dismiss_message_notification() -> void:
	message_notification.hide()
	message_notification.remove_meta("notification_id")
	message_notification.remove_meta("friend_id")
	_present_next_message_notification()


func _open_contacts_from_notification() -> void:
	var home: Dictionary = return_home()
	if not home.get("ok", false): return
	var opened: Dictionary = open_app(&"contacts")
	if opened.get("ok", false):
		_dismiss_message_notification()

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path == &"preferences.accessibility.text_size":
		_refresh_launcher()

func _on_contacts_changed(_result: Dictionary) -> void:
	_refresh_contact_notice()
	var app: Node = _cached_app_windows.get(&"contacts")
	if is_instance_valid(app):
		app.call_deferred("refresh_view")

## One unread indicator is rebuilt from saved Contacts on mount and after accepted notifications.
func _refresh_contact_notice() -> void:
	if not is_node_ready() or _presentation_port == null: return
	var view: Dictionary = _presentation_port.get_projection("", _locale)
	if not view.get("ok", false): return
	var unread: bool = view.value.unread.values().has(true)
	var caption: String = LABELS[_locale][1]
	contacts_button.set_caption(caption + (" •" if unread else ""))
	contacts_button.accessibility_name = caption + ({"en": ", new message",
		"zh-CN": "，有新消息", "zh-HK": "，有新訊息"}[_locale] if unread else "")


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
