extends Control
class_name MenuScene

## Menu logic: New Acc / Log in / Gallery / Setting / Shut down (prompt_docs/INDEX.md).

const BACKUP_APP_SCENE := preload("res://scenes/apps/BackupApp.tscn")
const SETTING_SCENE := preload("res://scenes/menu/Setting.tscn")
const GALLERY_SCENE := preload("res://scenes/menu/GalleryScene.tscn")
const BACKUP_PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const HOME_BUTTON := preload("res://scripts/ui/desktop/DesktopHomeButton.gd")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const CONFIRMATION := preload("res://scripts/ui/desktop/DesktopConfirmation.gd")
const BACKUP_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")
const ROUTINE_CLOCK := preload("res://scripts/ui/desktop/RoutineClock.gd")
const ART_MANIFEST := preload("res://scripts/data/ArtManifest.gd")
const TITLE_WELCOME := preload("res://scripts/ui/desktop/TitleWelcome.gd")
const SHUTDOWN_COPY := {
	"en": ["Shut down?", "Close the game.", "Cancel", "Shut down"],
	"zh-CN": ["关闭游戏？", "退出游戏。", "取消", "关闭游戏"],
	"zh-HK": ["關閉遊戲？", "退出遊戲。", "取消", "關閉遊戲"],
}

# Operational copy follows the accepted New Acc sheet; live-only replacement
# must not claim an Autosave exists. These facts come only from the owner.
const NEW_ACC_COPY := {
	"en": ["Start a new account?", "Autosave will be replaced. Other saves will remain.",
		"Current progress will be replaced. Other saves will remain.", "Cancel", "Start",
		"New Acc unavailable", "The account could not be prepared. Try again.",
		"The available state changed. Review New Acc again before starting.",
		"New Acc needs recovery", "The account has not finished starting. Retry to complete the same operation.", "Retry"],
	"zh-CN": ["开始新账号？", "自动存档将被替换。其他存档将保留。",
		"当前进度将被替换。其他存档将保留。", "取消", "开始",
		"无法新建账号", "暂时无法准备新账号。请重试。",
		"当前状态已改变。开始前，请重新确认新建账号。",
		"新账号需要恢复", "新账号尚未完成启动。请重试以完成同一次操作。", "重试"],
	"zh-HK": ["開始新帳號？", "自動存檔將被替換。其他存檔將保留。",
		"目前進度將被替換。其他存檔將保留。", "取消", "開始",
		"無法建立帳號", "暫時無法準備新帳號。請重試。",
		"目前狀態已改變。開始前，請重新確認建立帳號。",
		"新帳號需要復原", "新帳號尚未完成啟動。請重試以完成同一次操作。", "重試"],
}

const STARTUP_UNAVAILABLE_COPY := {
	"en": ["Unable to finish starting", "Startup could not finish. Close and reopen the game to try again."],
	"zh-CN": ["无法完成启动", "启动未能完成。请关闭并重新打开游戏以重试。"],
	"zh-HK": ["無法完成啟動", "啟動未能完成。請關閉並重新開啟遊戲以重試。"],
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
var _title_welcome: Control
var _title_port: Object
var _confirmation: Control
var _login_result: Dictionary = {}
var _ledger_custody: Array[Dictionary] = []
var _title_strip: Control
var _clock_label: Label
var _locale := "en"
var _percent := 100
var _settings_services: Dictionary = {}
var _gallery_host: Control
var _gallery_instance: Control
var _gallery_replay_profile: Object
var _gallery_replay_bridge: Object
var _gallery_rehearsal_game: Object
var _gallery_rehearsal_input: Object
var _title_transition := false
var _new_acc_owner: Object
var _new_acc_token := ""
var _new_acc_transaction := ""
var _new_acc_source: WeakRef
var _new_acc_source_captured := false
var _startup_recovery_owner: Object
var _startup_recovery_owner_bound := false
var _startup_recovery_active := false

func configure_settings_services(services: Dictionary) -> void:
	_settings_services = services.duplicate()
	if not is_node_ready() and services.get("localization") != null:
		for child: Node in get_children():
			if child.name == &"LocalePresentationRoot" or String(child.name).begins_with("L10n"):
				child.set("_localization", services.localization)

func _menu_profile() -> Object:
	return _settings_services.get("profile", get_node_or_null("/root/ProfileManager"))

func _menu_localization() -> Node:
	return _settings_services.get("localization", get_node_or_null("/root/LocalizationManager"))

func _ready() -> void:
	_mount_title_art()
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
	_bind_startup_recovery()

func _mount_title_art() -> void:
	var texture := ART_MANIFEST.get_texture("ui.title")
	if texture == null: return
	var art := TextureRect.new()
	art.name = "TitleArtwork"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = texture
	art.position = Vector2(320, 64)
	art.size = Vector2(960, 656)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	move_child(art, 0)

func configure_startup_recovery_owner(owner: Object) -> void:
	if is_instance_valid(_startup_recovery_owner) and _startup_recovery_owner.has_signal("startup_recovery_changed"):
		if _startup_recovery_owner.startup_recovery_changed.is_connected(_queue_startup_recovery_check):
			_startup_recovery_owner.startup_recovery_changed.disconnect(_queue_startup_recovery_check)
	_startup_recovery_owner = owner
	_startup_recovery_owner_bound = true
	if is_node_ready(): _bind_startup_recovery()

func _bind_startup_recovery() -> void:
	if not _startup_recovery_owner_bound:
		_startup_recovery_owner = get_node_or_null("/root/ApplicationBootstrap")
		_startup_recovery_owner_bound = true
	if not is_instance_valid(_startup_recovery_owner): return
	if not _startup_recovery_owner.has_method("get_new_run_startup_recovery"): return
	if _startup_recovery_owner.has_signal("startup_recovery_changed"):
		if not _startup_recovery_owner.startup_recovery_changed.is_connected(_queue_startup_recovery_check):
			_startup_recovery_owner.startup_recovery_changed.connect(_queue_startup_recovery_check)
	_queue_startup_recovery_check()

func _queue_startup_recovery_check() -> void:
	# Bootstrap may signal while its Retry call still owns the current stack.
	if _title_source_alive(): _check_startup_recovery.call_deferred()

func _startup_recovery_fact() -> Dictionary:
	if not is_instance_valid(_startup_recovery_owner): return {}
	if not _startup_recovery_owner.has_method("get_new_run_startup_recovery"): return {}
	var result: Dictionary = _startup_recovery_owner.get_new_run_startup_recovery()
	if not result.get("ok", false) or not result.get("value") is Dictionary: return {}
	var value: Dictionary = result.value
	if typeof(value.get("available")) != TYPE_BOOL or typeof(value.get("transaction_id")) != TYPE_STRING: return {}
	return value

func _check_startup_recovery() -> void:
	if not _title_source_alive() or _title_transition or is_instance_valid(_confirmation): return
	if not _new_acc_transaction.is_empty() or not _new_acc_token.is_empty(): return
	var recovery := _startup_recovery_fact()
	var retryable: bool = recovery.get("available", false) and not str(recovery.get("transaction_id", "")).is_empty()
	if not retryable:
		if not is_instance_valid(_startup_recovery_owner) or not _startup_recovery_owner.has_method("get_startup_state"): return
		var startup: Dictionary = _startup_recovery_owner.get_startup_state()
		if startup.get("ready", false) or not startup.get("fatal_result") is Dictionary or startup.fatal_result.is_empty(): return
	var scene := get_tree().current_scene
	_new_acc_source = weakref(scene) if scene != null else null
	_new_acc_source_captured = true
	_startup_recovery_active = true
	if retryable:
		_new_acc_transaction = str(recovery.transaction_id)
		_show_new_acc_recovery()
	else:
		# A generic startup failure cannot authorize fresh gameplay or invent a
		# retryable NewRun transaction merely because SaveManager is initialized.
		_show_startup_unavailable()

func _retry_startup_new_acc() -> void:
	_title_transition = true
	_sync_title_navigation()
	if not await _present_new_acc_busy("retrying"):
		_finish_new_acc_transition()
		return
	var result := {"ok": false}
	if is_instance_valid(_startup_recovery_owner) and _startup_recovery_owner.has_method("retry_new_run_startup"):
		result = _startup_recovery_owner.retry_new_run_startup(_new_acc_transaction)
	if not _finish_new_acc_transition(): return
	if result.get("ok", false):
		_startup_recovery_active = false
		_handle_new_acc_result(result)
		_focus_new_acc()
		return
	var recovery := _startup_recovery_fact()
	if recovery.get("available", false) and str(recovery.get("transaction_id", "")) == _new_acc_transaction:
		_show_new_acc_recovery()
	else:
		_show_startup_unavailable()

func _show_startup_unavailable() -> void:
	var copy: Array = STARTUP_UNAVAILABLE_COPY[_locale]
	present_confirmation({"title": copy[0], "body": copy[1], "confirm": SHUTDOWN_COPY[_locale][3],
		"cancelable": false, "risk": "neutral", "warning": false,
		"theme": BACKUP_THEME.build(_locale, _percent)}, _on_startup_shutdown, Callable())

func _on_startup_shutdown() -> void:
	if _new_acc_source_is_current(): _on_shut_down_confirmed()

func configure_new_acc_owner(owner: Object) -> void:
	# A presentation seam for the same SaveManager capability used in production.
	_new_acc_owner = owner

func _menu_new_acc_owner() -> Object:
	if is_instance_valid(_new_acc_owner): return _new_acc_owner
	return get_node_or_null("/root/SaveManager") if is_inside_tree() else null

func _title_source_alive() -> bool:
	if not is_inside_tree(): return false
	var node: Node = self
	while node != null:
		if node.is_queued_for_deletion(): return false
		node = node.get_parent()
	return true

func _new_acc_source_is_current() -> bool:
	if not _title_source_alive() or not _new_acc_source_captured: return false
	if _new_acc_source == null: return get_tree().current_scene == null
	var source: Node = _new_acc_source.get_ref() as Node
	return is_instance_valid(source) and not source.is_queued_for_deletion() and get_tree().current_scene == source

## Two frame boundaries let the status reach the renderer before synchronous save work.
## The existing title mask holds input; a route change while yielding cannot start an account.
func _present_new_acc_busy(stage: String) -> bool:
	_title_welcome.set_busy(stage)
	await get_tree().process_frame
	if not _new_acc_source_is_current(): return false
	await get_tree().process_frame
	return _new_acc_source_is_current()


func _finish_new_acc_transition() -> bool:
	_title_transition = false
	if not _new_acc_source_is_current(): return false
	_end_title_transition()
	return true

func _on_new_acc_pressed() -> void:
	if not _title_source_alive() or not _begin_title_transition(): return
	var scene := get_tree().current_scene
	_new_acc_source = weakref(scene) if scene != null else null
	_new_acc_source_captured = true
	if not await _close_setting():
		_finish_new_acc_transition()
		return
	if not _new_acc_source_is_current():
		_title_transition = false
		return
	_close_backup_app()
	_close_gallery()
	if _backup_app_host.visible or _gallery_host.visible:
		_end_title_transition()
		return
	var owner := _menu_new_acc_owner()
	if owner == null or not owner.has_method("prepare_new_run_action"):
		_end_title_transition()
		_show_new_acc_unavailable(false)
		return
	# Route finalization can detach Menu before commit returns. Retain this exact
	# capability for transient cleanup and Retry instead of looking up a new owner.
	_new_acc_owner = owner
	if not await _present_new_acc_busy("preparing"):
		_finish_new_acc_transition()
		return
	if not is_instance_valid(owner):
		_finish_new_acc_transition()
		_show_new_acc_unavailable(false)
		return
	var prepared: Dictionary = owner.prepare_new_run_action({
		"route_id": "main", "dialogic_checkpoint": {}, "active_app_id": null,
		"audio_context": {}, "content_version": 1})
	if not _finish_new_acc_transition():
		if prepared.get("ok", false): owner.cancel_prepared_new_run(str(prepared.value.token))
		return
	if not prepared.get("ok", false):
		_handle_new_acc_result(prepared)
		return
	_new_acc_token = str(prepared.value.token)
	if not prepared.value.requires_confirmation:
		_commit_new_acc()
		return
	var copy: Array = NEW_ACC_COPY[_locale]
	present_confirmation({"title": copy[0],
		"body": copy[1] if prepared.value.replaces_autosave else copy[2],
		"cancel": copy[3], "confirm": copy[4], "risk": "danger", "warning": true,
		"theme": BACKUP_THEME.build(_locale, _percent)}, _commit_new_acc, _cancel_new_acc)

func _cancel_new_acc() -> void:
	var owner := _new_acc_owner
	if not _new_acc_token.is_empty() and is_instance_valid(owner):
		owner.cancel_prepared_new_run(_new_acc_token)
	_new_acc_token = ""
	_focus_new_acc()

func _commit_new_acc() -> void:
	if _new_acc_token.is_empty() or _title_transition: return
	if not _new_acc_source_is_current():
		_cancel_new_acc()
		return
	var owner := _menu_new_acc_owner()
	_title_transition = true
	_sync_title_navigation()
	if not await _present_new_acc_busy("starting"):
		_cancel_new_acc()
		_finish_new_acc_transition()
		return
	var result := {"ok": false}
	if is_instance_valid(owner):
		if owner.has_method("commit_prepared_new_run_responsive"):
			result = await owner.commit_prepared_new_run_responsive(_new_acc_token)
		else:
			result = owner.commit_prepared_new_run(_new_acc_token)
	# Release only the transient preparation. A durable decision belongs to Retry.
	_cancel_new_acc()
	if _finish_new_acc_transition(): _handle_new_acc_result(result)

func _handle_new_acc_result(result: Dictionary) -> void:
	if not _new_acc_source_is_current(): return
	if result.get("ok", false):
		_new_acc_transaction = ""
		_sync_title_navigation()
		return
	if result.get("recovery_required", false) and not str(result.get("transaction_id", "")).is_empty():
		_new_acc_transaction = str(result.transaction_id)
		_show_new_acc_recovery()
		return
	_show_new_acc_unavailable(str(result.get("code", "")) == "NEW_RUN_PREPARATION_STALE")

func _show_new_acc_unavailable(stale: bool) -> void:
	var copy: Array = NEW_ACC_COPY[_locale]
	present_confirmation({"title": copy[5], "body": copy[7] if stale else copy[6],
		"cancel": copy[3], "confirm": copy[10], "risk": "neutral", "warning": false,
		"theme": BACKUP_THEME.build(_locale, _percent)}, _on_new_acc_pressed, _focus_new_acc)

func _show_new_acc_recovery() -> void:
	var copy: Array = NEW_ACC_COPY[_locale]
	present_confirmation({"title": copy[8], "body": copy[9], "confirm": copy[10],
		"cancelable": false, "risk": "neutral", "warning": false,
		"theme": BACKUP_THEME.build(_locale, _percent)}, _retry_new_acc, Callable())

func _retry_new_acc() -> void:
	if _new_acc_transaction.is_empty() or _title_transition or not _new_acc_source_is_current(): return
	if _startup_recovery_active:
		_retry_startup_new_acc()
		return
	var owner := _menu_new_acc_owner()
	_title_transition = true
	_sync_title_navigation()
	if not await _present_new_acc_busy("retrying"):
		_finish_new_acc_transition()
		return
	var result := {"ok": false}
	if is_instance_valid(owner):
		if owner.has_method("retry_new_run_responsive"):
			result = await owner.retry_new_run_responsive(_new_acc_transaction)
		else:
			result = owner.retry_new_run(_new_acc_transaction)
	if not _finish_new_acc_transition(): return
	if result.get("ok", false):
		_handle_new_acc_result(result)
	else:
		# Even an unavailable retry cannot grant cancellation of a durable decision.
		_show_new_acc_recovery()

func _focus_new_acc() -> void:
	if _new_acc_source_is_current() and not _title_transition:
		_new_acc_button.grab_focus()

func _exit_tree() -> void:
	# Menu teardown can cancel preparation only, never a retained durable operation.
	if not _new_acc_token.is_empty():
		var owner := _new_acc_owner
		if is_instance_valid(owner): owner.cancel_prepared_new_run(_new_acc_token)
		_new_acc_token = ""

func _on_log_in_pressed() -> void:
	if not _begin_title_transition(): return
	if not await _close_setting():
		_end_title_transition()
		return
	_close_gallery()
	_backup_app_host.visible = true
	_update_title_destination()
	if is_instance_valid(_backup_app_instance):
		_backup_app_instance.show_window()
		_end_title_transition()
		return
	var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
	if bootstrap == null or not bootstrap.get_startup_state().get("ready", false):
		_end_title_transition()
		_show_login_unavailable()
		return
	_title_port = BACKUP_PORT.new()
	_login_result = _title_port.configure(get_node_or_null("/root/SaveManager"), "title")
	if not _login_result.get("ok", false):
		_end_title_transition()
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
	_end_title_transition()

func configure_gallery_replay(profile: Object, bridge: Object) -> Dictionary:
	if profile == null or bridge == null or not profile.has_method("get_reached_presentations") \
			or not bridge.has_method("configure_reached_replay"):
		return {"ok":false, "code":&"gallery_replay_unavailable"}
	if _gallery_replay_profile != null and (_gallery_replay_profile != profile or _gallery_replay_bridge != bridge):
		return {"ok":false, "code":&"gallery_replay_already_configured"}
	_gallery_replay_profile = profile
	_gallery_replay_bridge = bridge
	return {"ok":true}

func configure_gallery_rehearsal(game_state: Object, input_owner: Object) -> Dictionary:
	if game_state == null or not game_state.has_method("capture_run_snapshot_input"):
		return {"ok": false, "code": &"rehearsal_game_unavailable"}
	if _gallery_rehearsal_game != null and [_gallery_rehearsal_game, _gallery_rehearsal_input] != [game_state, input_owner]:
		return {"ok": false, "code": &"rehearsal_already_configured"}
	_gallery_rehearsal_game = game_state
	_gallery_rehearsal_input = input_owner
	return {"ok": true}

func _on_gallery_practice_visibility_changed(_active: bool) -> void:
	_sync_title_navigation()

func _on_gallery_pressed() -> void:
	if not _begin_title_transition(): return
	if not await _close_setting():
		_end_title_transition()
		return
	_close_backup_app()
	if not is_instance_valid(_gallery_instance):
		if _gallery_replay_profile == null:
			var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
			if bootstrap != null and bootstrap.has_method("configure_gallery_replay_services"):
				bootstrap.configure_gallery_replay_services(self)
		_gallery_instance = GALLERY_SCENE.instantiate()
		var configured: Dictionary = _gallery_instance.configure_title_host(_title_home, _menu_localization(), _menu_profile())
		if not configured.get("ok", false):
			_gallery_instance.free()
			_gallery_instance = null
			_end_title_transition()
			return
		if _gallery_replay_profile != null:
			_gallery_instance.configure_replay(_gallery_replay_bridge)
		if _gallery_rehearsal_game != null:
			_gallery_instance.configure_rehearsal(_gallery_rehearsal_game, _gallery_rehearsal_input)
		_gallery_instance.practice_visibility_changed.connect(_on_gallery_practice_visibility_changed)
		_gallery_host.add_child(_gallery_instance)
	_gallery_host.show()
	_gallery_instance.open_in_title_host()
	_end_title_transition()

func _on_setting_pressed() -> void:
	if not _can_leave_login():
		return
	_close_backup_app()
	_close_gallery()
	if is_instance_valid(_setting_instance):
		_setting_host.visible = true
		_setting_instance.show_window()
		_update_title_destination()
		return
	_setting_instance = SETTING_SCENE.instantiate()
	_setting_instance.get_node("SettingsContent").configure_services(_settings_services)
	_setting_host.add_child(_setting_instance)
	_setting_instance.window_hidden.connect(_setting_closed)
	_setting_host.visible = true
	_update_title_destination()
	_setting_instance.show_window()

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
	if not _source_departure_admitted():
		return
	var was_visible := _backup_app_host.visible
	if is_instance_valid(_backup_app_host):
		_backup_app_host.visible = false
	_update_title_destination()
	if was_visible and not _title_transition:
		_log_in_button.grab_focus()

func _close_setting() -> bool:
	if not _source_departure_admitted(): return false
	if is_instance_valid(_setting_instance) and _setting_instance.is_visible_in_tree():
		await _setting_instance.hide_window()
		if not is_inside_tree() or _setting_instance.is_visible_in_tree(): return false
	else:
		_setting_closed()
	return true

func _close_gallery() -> void:
	if not is_instance_valid(_gallery_host) or not _gallery_host.visible: return
	if is_instance_valid(_gallery_instance) and not _gallery_instance.close_for_title_host(): return
	_gallery_host.hide()
	_update_title_destination()
	if not _title_transition: _gallery_button.grab_focus()

func _begin_title_transition() -> bool:
	if not _can_leave_login(): return false
	_title_transition = true
	_sync_title_navigation()
	_update_title_destination()
	return true

func _end_title_transition() -> void:
	_title_transition = false
	if not is_inside_tree(): return
	if is_instance_valid(_title_welcome): _title_welcome.set_busy("")
	_sync_title_navigation()
	_update_title_destination()

func _setting_closed() -> void:
	var was_visible := _setting_host.visible
	if is_instance_valid(_setting_host):
		_setting_host.visible = false
	_update_title_destination()
	if was_visible and not _title_transition:
		_setting_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _title_transition:
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(_backup_app_host) and _backup_app_host.visible:
			# Backup owns recovery cancellation; one Back never closes two layers.
			if is_instance_valid(_backup_app_instance):
				_backup_app_instance._unhandled_input(event)
			else:
				_close_backup_app()
			get_viewport().set_input_as_handled()
		elif is_instance_valid(_setting_host) and _setting_host.visible:
			get_viewport().set_input_as_handled()
			if is_instance_valid(_setting_instance): _setting_instance.settings_content.handle_back()
		elif is_instance_valid(_gallery_host) and _gallery_host.visible and _can_leave_login():
			get_viewport().set_input_as_handled()
			_close_gallery()

func _build_login_shell() -> void:
	_gallery_host = Control.new()
	_gallery_host.name = "GalleryHost"
	_gallery_host.position = Vector2(320,64)
	_gallery_host.size = Vector2(960,656)
	_gallery_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gallery_host.hide()
	add_child(_gallery_host)
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
	_title_welcome = TITLE_WELCOME.new()
	_title_welcome.name = "TitleWelcome"
	_title_welcome.position = Vector2(320, 64)
	_title_welcome.size = Vector2(960, 656)
	add_child(_title_welcome)
	var locale := _menu_localization()
	var profile := _menu_profile()
	if locale != null:
		locale.locale_changed.connect(_refresh_login_shell)
	if profile != null:
		profile.preference_changed.connect(func(_path, _value): _refresh_login_shell())
	var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
	if bootstrap != null:
		bootstrap.application_ready.connect(_refresh_login_shell)
	_refresh_login_shell()

func _refresh_login_shell(_value: String = "") -> void:
	# application_ready may publish after route recovery detached this old title.
	if not _title_source_alive(): return
	var localization := _menu_localization()
	var locale := str(localization.get_locale()).replace("_", "-") if localization != null else "en"
	_locale = locale if SHUTDOWN_COPY.has(locale) else "en"
	var profile := _menu_profile()
	_percent = int(profile.get_preference("preferences.accessibility.text_size", 100)) if profile != null else 100
	theme = DESKTOP_THEME.build(_locale, _percent)
	_title_home.theme = theme
	_title_home.accessibility_name = {"en": "Return", "zh-CN": "返回", "zh-HK": "返回"}.get(locale, "Return")
	for button in [_new_acc_button, _log_in_button, _gallery_button, _setting_button, _shut_down_button]:
		button.custom_minimum_size.y = 64
	_title_status.text = {"en": "Unavailable", "zh-CN": "不可用", "zh-HK": "不可用"}.get(locale, "Unavailable")
	_clock_label.set_presentation(_locale, _percent)
	_title_welcome.set_presentation(_locale, _percent)
	_title_strip.queue_redraw()
	_update_title_destination()
	queue_redraw()

func _update_title_destination() -> void:
	if not is_instance_valid(_title_home):
		return
	var hosted := _backup_app_host.visible or _setting_host.visible or _gallery_host.visible
	_title_welcome.visible = not hosted
	_title_home.visible = hosted
	_title_home.focus_mode = Control.FOCUS_ALL if hosted and _can_leave_login() else Control.FOCUS_NONE
	_title_label.visible = hosted
	var key := "menu.login" if _backup_app_host.visible else ("menu.gallery" if _gallery_host.visible else "menu.setting")
	var localization := _menu_localization()
	_title_label.text = localization.t(key) if localization != null and localization.has_key(key) else ("Log in" if _backup_app_host.visible else ("Gallery" if _gallery_host.visible else "Setting"))
	_update_ledger_navigation()

func _return_from_title_host() -> void:
	if not _can_leave_login(): return
	if _backup_app_host.visible:
		_close_backup_app()
	elif _setting_host.visible:
		if _begin_title_transition():
			var closed := await _close_setting()
			_end_title_transition()
			if closed and is_inside_tree(): _setting_button.grab_focus()
	elif _gallery_host.visible:
		_close_gallery()

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
		var source: Button = _log_in_button if _backup_app_host.visible else (_gallery_button if _gallery_host.visible else _setting_button)
		_title_home.focus_neighbor_left = _title_home.get_path_to(source)
		_title_home.focus_neighbor_top = _title_home.get_path_to(_title_home)
		_title_home.focus_neighbor_right = _title_home.get_path_to(_title_home)
		if _setting_host.visible and is_instance_valid(_setting_instance):
			var first: Control = _setting_instance.settings_content.find_child("LanguageCategory",true,false)
			_title_home.focus_next = _title_home.get_path_to(first)
			_title_home.focus_neighbor_bottom = _title_home.get_path_to(first)
			_title_home.focus_previous = _title_home.get_path_to(first)
		elif _gallery_host.visible and is_instance_valid(_gallery_instance):
			_gallery_instance.refresh_return_navigation()
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
	return not _title_transition and not _startup_recovery_active and _new_acc_transaction.is_empty() and _source_departure_admitted()

func _source_departure_admitted() -> bool:
	return not (is_instance_valid(_gallery_instance) and _gallery_instance.has_active_rehearsal()) \
		and not is_instance_valid(_confirmation) \
		and (not is_instance_valid(_backup_app_instance) or _backup_app_instance.can_return_home()) \
		and (not is_instance_valid(_setting_instance) or _setting_instance.can_return_home())

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
