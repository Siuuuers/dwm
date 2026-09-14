extends GutTest

const ART := preload("res://scripts/data/ArtManifest.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")

class ReplayBridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	var starts: Array[String] = []
	func configure_reached_replay(_profile: Object) -> Dictionary: return {"ok": true}
	func replay_reached_signature(signature_id: String) -> Dictionary:
		starts.append(signature_id)
		return {"ok": true, "receipt": {"playback_token": "fixture"}}
	func cancel_reached_replay(_signature_id: String) -> Dictionary: return {"ok": true}

class UnavailableProfile extends PROFILE:
	func get_gallery_discovery_snapshot() -> Dictionary:
		return {"ok": false, "code": &"unavailable"}

var _profile: Node

func before_each() -> void:
	ART.reload_placements()
	_profile = PROFILE.new()
	add_child_autofree(_profile)
	assert_true(_profile.initialize(STORAGE.new("gallery-art.memory", FILES.new())).get("ok", false))

func after_each() -> void:
	ART.reload_placements()

func _alone(entry_id: String, form: String) -> Dictionary:
	return {"entry_id": entry_id, "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": form}}

func _record(signature: Dictionary) -> void:
	assert_true(_profile.record_reached_presentation(signature).get("ok", false))

func _version_index(gallery: Control, entry_id: String) -> int:
	for index: int in range(gallery._versions.size()):
		if gallery._versions[index].signature.entry_id == entry_id: return index
	return -1

func _tile(gallery: Control, record_id: String) -> Button:
	for tile: Button in gallery.get_node("%EndingTileGrid").get_children():
		if tile.get_meta(&"gallery_record_id") == record_id: return tile
	return null

func _mount(localization: Node = null) -> Dictionary:
	var home := Button.new()
	add_child_autofree(home)
	var bridge := ReplayBridge.new()
	var gallery: Control = GALLERY.instantiate()
	assert_true(gallery.configure_title_host(home, localization, _profile).get("ok", false))
	assert_true(gallery.configure_replay(bridge).get("ok", false))
	add_child_autofree(gallery)
	gallery.open_in_title_host()
	return {"gallery": gallery, "bridge": bridge}

func _record_title(gallery: Control) -> Label:
	return gallery.get_node("%GalleryHost/RecordTitle")

func _assert_written_archive(gallery: Control, title: Label) -> void:
	assert_null(gallery.get_node_or_null("%GalleryHost/GalleryArtworkPreview"))
	var media := gallery.get_node("%GalleryHost").get_children().filter(func(node: Node) -> bool: return node is TextureRect)
	assert_true(media.is_empty(), "Unexpected Gallery media: %s" % str(media))
	assert_eq(title.position, Vector2(392, 32))
	assert_eq(title.size.x, 504.0)
	assert_ne(title.autowrap_mode, TextServer.AUTOWRAP_OFF)
	assert_false(title.clip_text)
	assert_eq(title.focus_mode, Control.FOCUS_NONE)
	assert_eq(title.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_exact_reached_version_selects_authored_title_without_scene_media_or_mutation() -> void:
	ART.set_overlay_info("", "cg.ending.alone.normal",
		"res://tests/fixtures/art/placement-cg.svg", Vector2i(1280, 448), "fixture")
	ART.set_overlay_info("", "cg.ending.alone.dark_mode",
		"res://tests/fixtures/art/placement-background.svg", Vector2i(1280, 720), "fixture")
	_record(_alone("ending.alone.normal", "alone_normal"))
	_record(_alone("ending.alone.dark_mode", "alone_dark_mode"))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-art:alone").get("ok", false))
	assert_true(_profile.unlock_ending("ending.priscilla.sweet", "gallery-art:unreached").get("ok", false))
	var discovery_before: Dictionary = _profile.get_gallery_discovery_snapshot()
	var profile_before: Dictionary = _profile.get_profile_snapshot()
	var mounted := _mount()
	var gallery: Control = mounted.gallery
	var bridge: ReplayBridge = mounted.bridge
	var title := _record_title(gallery)
	_assert_written_archive(gallery, title)
	var normal_index := _version_index(gallery, "ending.alone.normal")
	var dark_index := _version_index(gallery, "ending.alone.dark_mode")
	assert_ne(normal_index, -1)
	assert_ne(dark_index, -1)
	gallery._version_selector.item_selected.emit(normal_index)
	assert_eq(gallery._selected_signature_id(), str(gallery._versions[normal_index].signature_id))
	assert_true(title.visible)
	assert_eq(title.text, _tile(gallery, "ending.alone").text)
	assert_false(title.text.is_empty())
	assert_false(title.text.contains("ending.alone"))
	gallery._version_selector.item_selected.emit(dark_index)
	assert_eq(gallery._selected_signature_id(), str(gallery._versions[dark_index].signature_id))
	assert_true(title.visible)
	assert_eq(title.text, _tile(gallery, "ending.alone").text)
	ART.set_overlay_info("", "cg.ending.alone.dark_mode",
		"res://tests/fixtures/art/missing.svg", Vector2i(1280, 448), "missing")
	gallery._version_selector.item_selected.emit(dark_index)
	_assert_written_archive(gallery, title)
	assert_true(title.visible, "missing scene media must not suppress the written record")
	assert_eq(_profile.get_gallery_discovery_snapshot(), discovery_before)
	assert_eq(_profile.get_profile_snapshot(), profile_before)
	assert_true(bridge.starts.is_empty())

func test_unreached_and_empty_records_keep_inert_title_semantics() -> void:
	assert_true(_profile.unlock_ending("ending.priscilla.sweet", "gallery-art:unreached").get("ok", false))
	var mounted := _mount()
	var gallery: Control = mounted.gallery
	var title := _record_title(gallery)
	_assert_written_archive(gallery, title)
	assert_true(title.visible, "a discovered record keeps its authored written title")
	assert_eq(title.text, _tile(gallery, "ending.priscilla.sweet").text)
	assert_false(gallery.get_node("%ReplayStatus").text.is_empty())
	assert_eq(gallery.get_node("%ReplayStatus").position, Vector2(408, 568))
	assert_true((mounted.bridge as ReplayBridge).starts.is_empty())

	var empty_profile := PROFILE.new()
	add_child_autofree(empty_profile)
	assert_true(empty_profile.initialize(STORAGE.new("gallery-art-empty.memory", FILES.new())).get("ok", false))
	var home := Button.new()
	add_child_autofree(home)
	var empty_gallery: Control = GALLERY.instantiate()
	assert_true(empty_gallery.configure_title_host(home, null, empty_profile).get("ok", false))
	add_child_autofree(empty_gallery)
	empty_gallery.open_in_title_host()
	var empty_title := _record_title(empty_gallery)
	_assert_written_archive(empty_gallery, empty_title)
	assert_false(empty_title.visible)
	assert_true(empty_title.text.is_empty())
	assert_false(empty_title.has_focus())

	var unavailable := UnavailableProfile.new()
	add_child_autofree(unavailable)
	assert_true(unavailable.initialize(STORAGE.new("gallery-art-unavailable.memory", FILES.new())).get("ok", false))
	_profile = unavailable
	var unavailable_gallery: Control = _mount().gallery
	var unavailable_title := _record_title(unavailable_gallery)
	_assert_written_archive(unavailable_gallery, unavailable_title)
	assert_false(unavailable_title.visible)
	assert_true(unavailable_title.text.is_empty())
	assert_false(unavailable_title.has_focus())

func test_record_title_uses_active_locale_font_and_wraps_fully() -> void:
	_record(_alone("ending.alone.normal", "alone_normal"))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-art:locale").get("ok", false))
	var localization := LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(_profile).get("ok", false))
	assert_true(localization.set_locale("zh_HK").get("ok", false))
	assert_true(_profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false))
	var profile_before: Dictionary = _profile.get_profile_snapshot()
	var mounted := _mount(localization)
	var gallery: Control = mounted.gallery
	var title := _record_title(gallery)
	await get_tree().process_frame
	_assert_written_archive(gallery, title)
	assert_true(title.visible)
	assert_eq(title.language, "zh-HK")
	assert_eq(title.text, _tile(gallery, "ending.alone").text)
	assert_eq(title.get_theme_font_size("font_size"), gallery.theme.default_font_size)
	assert_lte(title.get_minimum_size().y, title.size.y, "active 150% title must fit its wrapped height")
	assert_eq(_profile.get_profile_snapshot(), profile_before)
	assert_true((mounted.bridge as ReplayBridge).starts.is_empty())
