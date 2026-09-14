extends GutTest
## Empty Gallery is announced once per visible entry, never by hidden setup or refresh.

const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")

class FailedProjection extends Node:
	signal profile_restored(snapshot: Dictionary)
	func get_gallery_discovery_snapshot() -> Dictionary:
		return {"ok": false, "code": &"fixture_projection_failed"}
	func get_preference(_path: StringName, fallback: Variant = null) -> Variant:
		return fallback

var _surface: SubViewport
var _profile: Node
var _localization: Node
var _home: Button
var _host: Control
var _gallery: Control

func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.handle_input_locally = true
	add_child(_surface)
	_profile = PROFILE.new()
	_surface.add_child(_profile)
	assert_true(_profile.initialize(STORAGE.new("gallery-empty-announcement.memory", FILES.new())).ok)
	_localization = LOCALIZATION.new()
	_surface.add_child(_localization)
	assert_true(_localization.initialize(_profile).ok)
	_home = Button.new()
	_home.text = "Return"
	_home.position = Vector2(320, 0)
	_home.size = Vector2(64, 64)
	_surface.add_child(_home)

func after_each() -> void:
	_surface.free()

func _settle() -> void:
	for frame: int in range(3): await get_tree().process_frame

func _mount_hidden(owner: Object = null) -> void:
	_host = Control.new()
	_host.position = Vector2(320, 64)
	_host.size = Vector2(960, 656)
	_surface.add_child(_host)
	_gallery = GALLERY.instantiate()
	assert_true(_gallery.configure_title_host(
		_home, _localization, _profile if owner == null else owner).ok)
	_gallery.hide()
	_host.add_child(_gallery)
	await _settle()

func _status() -> Label:
	return _gallery.get_node("%ReplayStatus")

func _assert_empty_live(locale: String) -> void:
	assert_true(_gallery.is_visible_in_tree())
	assert_eq(_gallery.get_node("%EndingTileGrid").get_child_count(), 0)
	assert_eq(_status().text, _localization.t("gallery.empty"))
	assert_eq(_status().accessibility_name, _status().text)
	assert_eq(_status().language, locale.replace("_", "-"))
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_POLITE)

func test_empty_is_announced_once_per_visible_entry_across_locales() -> void:
	await _mount_hidden()
	assert_false(_gallery.is_visible_in_tree())
	assert_eq(_status().text, _localization.t("gallery.empty"))
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF,
		"Hidden mounting cannot consume or publish the empty announcement.")

	_gallery.open_in_title_host()
	await _settle()
	_assert_empty_live("en")

	_profile.emit_signal(&"profile_restored", _profile.get_profile_snapshot())
	await _settle()
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF,
		"A same-entry Profile refresh cannot announce Empty again.")
	_home.grab_focus()
	_gallery.refresh_return_navigation()
	await _settle()
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF,
		"Focus/navigation refresh cannot revive the announcement.")
	assert_true(_profile.set_preference(&"preferences.accessibility.text_size", 125).ok)
	await _settle()
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF,
		"A same-entry preference refresh cannot announce Empty again.")

	assert_true(_gallery.close_for_title_host())
	assert_true(_localization.set_locale("zh_CN").ok)
	_gallery.open_in_title_host()
	await _settle()
	_assert_empty_live("zh_CN")
	assert_true(_localization.set_locale("zh_HK").ok)
	await _settle()
	assert_eq(_status().text, _localization.t("gallery.empty"))
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF,
		"Locale reprojection changes public copy without repeating the same entry announcement.")

	assert_true(_gallery.close_for_title_host())
	_gallery.open_in_title_host()
	await _settle()
	_assert_empty_live("zh_HK")
	_profile.emit_signal(&"profile_restored", _profile.get_profile_snapshot())
	await _settle()
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF,
		"The fresh entry still owns exactly one announcement.")

func test_populated_and_technical_failure_states_never_publish_empty_live_copy() -> void:
	assert_true(_profile.unlock_ending("ending.alone", "gallery-empty-announcement:populated").ok)
	await _mount_hidden()
	_gallery.open_in_title_host()
	await _settle()
	assert_eq(_gallery.get_node("%EndingTileGrid").get_child_count(), 1)
	assert_ne(_status().text, _localization.t("gallery.empty"))
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF)

	assert_true(_gallery.close_for_title_host())
	_host.remove_child(_gallery)
	_gallery.queue_free()
	await _settle()
	var failed := FailedProjection.new()
	_surface.add_child(failed)
	await _mount_hidden(failed)
	_gallery.open_in_title_host()
	await _settle()
	assert_eq(_gallery.get_node("%EndingTileGrid").get_child_count(), 0)
	assert_eq(_status().text, _localization.t("gallery.archive.unavailable"))
	assert_ne(_status().text, _localization.t("gallery.empty"))
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF)
