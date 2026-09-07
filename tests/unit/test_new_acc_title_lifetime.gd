extends GutTest

const MENU := preload("res://scenes/menu/MenuScene.tscn")

class Locale extends Node:
	signal locale_changed(locale: String)
	func get_locale() -> String: return "en"
	func has_key(_key: String) -> bool: return true
	func t(key: String, _parameters: Dictionary = {}) -> String: return key

class Profile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	func get_preference(_path: StringName, fallback: Variant = null) -> Variant: return fallback

class DeferredSettings extends Control:
	signal departure_resolved()
	signal window_hidden()
	var settings_content: Control
	var departing := false
	func _ready() -> void:
		settings_content = Control.new()
		add_child(settings_content)
		var rail := Button.new()
		rail.name = "LanguageCategory"
		settings_content.add_child(rail)
	func can_return_home() -> bool: return true
	func hide_window() -> void:
		departing = true
		await departure_resolved
		hide()
		window_hidden.emit()

class NewAccOwner extends RefCounted:
	var prepares := 0
	var commits := 0
	var cancels: Array[String] = []
	var on_commit: Callable
	func prepare_new_run_action(_context: Dictionary) -> Dictionary:
		prepares += 1
		return {"ok": true, "value": {"token": "prepared-lifetime", "requires_confirmation": true,
			"replaces_autosave": true, "replaces_live": false}}
	func commit_prepared_new_run(_token: String) -> Dictionary:
		commits += 1
		if on_commit.is_valid(): on_commit.call()
		return {"ok": false, "recovery_required": true, "transaction_id": "retained-lifetime"}
	func cancel_prepared_new_run(token: String) -> Dictionary:
		cancels.append(token)
		return {"ok": true}
	func retry_new_run(_transaction: String) -> Dictionary:
		return {"ok": false}

var original_scene: Node
var source: Control
var destination: Control
var destination_button: Button
var menu: Control
var save_owner: NewAccOwner
var settings: DeferredSettings

func before_each() -> void:
	original_scene = get_tree().current_scene
	source = Control.new()
	source.size = Vector2(1280, 720)
	get_tree().root.add_child(source)
	get_tree().current_scene = source
	var locale := Locale.new()
	var profile := Profile.new()
	source.add_child(locale)
	source.add_child(profile)
	save_owner = NewAccOwner.new()
	menu = MENU.instantiate()
	menu.configure_settings_services({"profile": profile, "localization": locale})
	menu.configure_new_acc_owner(save_owner)
	source.add_child(menu)
	for frame in 3: await get_tree().process_frame

func after_each() -> void:
	get_tree().current_scene = original_scene if is_instance_valid(original_scene) else null
	if is_instance_valid(source): source.free()
	if is_instance_valid(destination): destination.free()
	await get_tree().process_frame

func _install_deferred_settings() -> void:
	settings = DeferredSettings.new()
	menu._setting_host.add_child(settings)
	menu._setting_instance = settings
	settings.window_hidden.connect(menu._setting_closed)
	menu._setting_host.show()
	menu._update_title_destination()

func _show_destination(change_scene: bool) -> void:
	destination = Control.new()
	destination.size = Vector2(1280, 720)
	get_tree().root.add_child(destination)
	destination_button = Button.new()
	destination_button.text = "Destination action"
	destination_button.size = Vector2(240, 64)
	destination.add_child(destination_button)
	if change_scene: get_tree().current_scene = destination
	destination_button.grab_focus()

func _assert_no_outgoing_preparation() -> void:
	assert_eq(save_owner.prepares, 0, "Retired title cannot prepare New Acc")
	assert_eq(save_owner.commits, 0, "Retired title cannot commit New Acc")
	assert_false(is_instance_valid(menu._confirmation), "Retired title cannot mount a consent sheet")
	assert_eq(get_tree().root.gui_get_focus_owner(), destination_button, "Destination keeps native focus")

func test_scene_replacement_during_settings_departure_cannot_prepare_from_still_live_title() -> void:
	_install_deferred_settings()
	menu._new_acc_button.pressed.emit()
	assert_true(settings.departing, "Real Menu waits for Settings departure")
	assert_eq(save_owner.prepares, 0)
	_show_destination(true)
	assert_true(source.is_inside_tree(), "Source intentionally remains alive to isolate scene identity")
	settings.departure_resolved.emit()
	_assert_no_outgoing_preparation()
	await get_tree().process_frame
	assert_eq(get_tree().root.gui_get_focus_owner(), destination_button)

func test_queued_source_ancestor_during_departure_cannot_prepare_before_frame_end() -> void:
	_install_deferred_settings()
	menu._new_acc_button.pressed.emit()
	assert_true(settings.departing)
	_show_destination(false)
	source.queue_free()
	assert_true(menu.is_inside_tree(), "Queued ancestor has not left the tree yet")
	assert_false(menu.is_queued_for_deletion(), "Checking only Menu itself would miss retirement")
	settings.departure_resolved.emit()
	_assert_no_outgoing_preparation()
	await get_tree().process_frame
	assert_false(is_instance_valid(source))
	assert_eq(get_tree().root.gui_get_focus_owner(), destination_button)

func test_synchronous_commit_retiring_title_cannot_mount_post_return_recovery() -> void:
	menu._new_acc_button.pressed.emit()
	assert_eq(save_owner.prepares, 1)
	assert_true(is_instance_valid(menu._confirmation))
	save_owner.on_commit = func():
		_show_destination(true)
		source.queue_free()
	var sheet: Control = menu._confirmation
	sheet.confirm_button.pressed.emit()
	assert_eq(save_owner.commits, 1)
	assert_false(is_instance_valid(menu._confirmation), "No recovery sheet may appear on retired title")
	assert_eq(get_tree().root.gui_get_focus_owner(), destination_button)
	await get_tree().process_frame
	assert_false(is_instance_valid(source))
	assert_eq(get_tree().root.gui_get_focus_owner(), destination_button)

func test_synchronous_commit_detaches_source_before_return_without_new_root_lookup() -> void:
	menu._new_acc_button.pressed.emit()
	assert_eq(save_owner.prepares, 1)
	save_owner.on_commit = func():
		_show_destination(true)
		source.get_parent().remove_child(source)
	var sheet: Control = menu._confirmation
	sheet.confirm_button.pressed.emit()
	assert_eq(save_owner.commits, 1)
	assert_false(source.is_inside_tree())
	assert_false(is_instance_valid(menu._confirmation), "Detached Menu cannot mount recovery")
	assert_eq(get_tree().root.gui_get_focus_owner(), destination_button)
	assert_false(save_owner.cancels.is_empty(), "Retained owner receives transient cleanup")
