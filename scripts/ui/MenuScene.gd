extends Control
class_name MenuScene

## Menu logic: New Acc / Log in / Gallery / Setting / Shut down (prompt_docs/INDEX.md).

const BACKUP_APP_SCENE := preload("res://scenes/apps/BackupApp.tscn")
const SETTING_SCENE := preload("res://scenes/menu/Setting.tscn")

@onready var _new_acc_button: Button = %NewAccButton
@onready var _log_in_button: Button = %LogInButton
@onready var _gallery_button: Button = %GalleryButton
@onready var _setting_button: Button = %SettingButton
@onready var _shut_down_button: Button = %ShutDownButton
@onready var _backup_app_host: Control = %BackupAppHost
@onready var _setting_host: Control = %SettingHost
@onready var _shut_down_confirm: ConfirmationDialog = %ShutDownConfirm
@onready var _title_art_presenter: Control = %TitleArtPresenter

var _backup_app_instance: Node = null
var _setting_instance: Node = null
var _active_title_host: Control = null
var _active_title_source: BaseButton = null

func _ready() -> void:
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
	if is_instance_valid(_shut_down_confirm) and not _shut_down_confirm.confirmed.is_connected(_on_shut_down_confirmed):
		_shut_down_confirm.confirmed.connect(_on_shut_down_confirmed)
	if has_node("/root/InputManager"):
		get_node("/root/InputManager").call_deferred("focus_first_control", self)

func _on_new_acc_pressed() -> void:
	# New Game runs as one atomic transaction; the prepared route participant is the
	# only opening transition (no separate SceneRouter.start_game_from_menu call).
	if not has_node("/root/SaveManager"):
		return
	var save_manager := get_node("/root/SaveManager")
	if not save_manager.has_method("start_new_run"):
		return
	var run_id := "run-%d-%d" % [Time.get_ticks_usec(), randi()]
	var initial_context := {
		"route_id": "opening",
		"dialogic_checkpoint": {},
		"active_app_id": null,
		"audio_context": {},
		"content_version": 1,
	}
	# Phase 2R route readiness resolves synchronously; when it becomes awaited
	# (real target-scene layout readiness) this call gains `await`.
	var result: Dictionary = save_manager.start_new_run(run_id, initial_context)
	if not result.get("ok", false):
		push_warning("MenuScene: start_new_run failed (%s)." % str(result.get("code", "")))

func _on_log_in_pressed() -> void:
	if not is_instance_valid(_backup_app_instance):
		_backup_app_instance = BACKUP_APP_SCENE.instantiate()
		_backup_app_host.add_child(_backup_app_instance)
		var backup_window := _backup_app_instance as AppWindowBase
		if backup_window != null and not backup_window.window_hidden.is_connected(close_active_title_destination):
			backup_window.window_hidden.connect(close_active_title_destination)
	_show_title_destination(_backup_app_host, _log_in_button)

func _on_gallery_pressed() -> void:
	if has_node("/root/SceneRouter"):
		get_node("/root/SceneRouter").goto_scene_id("gallery")

func _on_setting_pressed() -> void:
	if not is_instance_valid(_setting_instance):
		_setting_instance = SETTING_SCENE.instantiate()
		_setting_host.add_child(_setting_instance)
		var close_button := _setting_instance.get_node("%CloseButton") as Button
		if not close_button.pressed.is_connected(close_active_title_destination):
			close_button.pressed.connect(close_active_title_destination)
	_show_title_destination(_setting_host, _setting_button)

func _on_shut_down_pressed() -> void:
	if is_instance_valid(_shut_down_confirm):
		_shut_down_confirm.popup_centered()

func _on_shut_down_confirmed() -> void:
	get_tree().quit()

func _show_title_destination(host: Control, source: BaseButton) -> void:
	if is_instance_valid(_active_title_host) and _active_title_host != host:
		_active_title_host.hide()
	_title_art_presenter.hide()
	for child in host.get_children():
		child.show()
	host.show()
	_active_title_host = host
	_active_title_source = source

func close_active_title_destination() -> void:
	var source := _active_title_source
	if is_instance_valid(_backup_app_host):
		_backup_app_host.hide()
	if is_instance_valid(_setting_host):
		_setting_host.hide()
	_active_title_host = null
	_active_title_source = null
	_title_art_presenter.show()
	if is_instance_valid(source):
		source.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_instance_valid(_shut_down_confirm) and _shut_down_confirm.visible:
		_shut_down_confirm.hide()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(_active_title_host):
		close_active_title_destination()
		get_viewport().set_input_as_handled()
