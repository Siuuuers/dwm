extends GutTest

const ART := preload("res://scripts/data/ArtManifest.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const REPLAY := preload("res://scripts/application/ending/GalleryReplayOwner.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")

class ReplayBridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	func configure_reached_replay(_profile: Object) -> Dictionary: return {"ok": true}
	func replay_reached_signature(_signature_id: String) -> Dictionary:
		return {"ok": true, "receipt": {"playback_token": "fixture"}}
	func cancel_reached_replay(_signature_id: String) -> Dictionary: return {"ok": true}

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

func test_exact_reached_version_selects_optional_art_without_changing_discovery() -> void:
	ART.set_overlay_info("", "cg.ending.alone.normal",
		"res://tests/fixtures/art/placement-cg.svg", Vector2i(1280, 448), "fixture")
	ART.set_overlay_info("", "cg.ending.alone.dark_mode",
		"res://tests/fixtures/art/placement-background.svg", Vector2i(1280, 720), "fixture")
	_record(_alone("ending.alone.normal", "alone_normal"))
	_record(_alone("ending.alone.dark_mode", "alone_dark_mode"))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-art:alone").get("ok", false))
	assert_true(_profile.unlock_ending("ending.priscilla.sweet", "gallery-art:unreached").get("ok", false))
	var discovery_before: Dictionary = _profile.get_gallery_discovery_snapshot()
	var home := Button.new()
	add_child_autofree(home)
	var gallery: Control = GALLERY.instantiate()
	assert_true(gallery.configure_title_host(home, null, _profile).get("ok", false))
	assert_true(gallery.configure_replay(ReplayBridge.new()).get("ok", false))
	add_child_autofree(gallery)
	gallery.open_in_title_host()

	var preview: TextureRect = gallery.get("_art_preview")
	assert_not_null(preview)
	assert_eq(preview.position, Vector2(392, 32))
	assert_eq(preview.size, Vector2(520, 512))
	assert_eq(preview.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(preview.focus_mode, Control.FOCUS_NONE)
	assert_lt(preview.get_index(), gallery.get_node("%ReplayStatus").get_index())
	assert_lt(preview.get_index(), gallery.get_node("%ReplayButton").get_index())

	var normal_index := _version_index(gallery, "ending.alone.normal")
	var dark_index := _version_index(gallery, "ending.alone.dark_mode")
	assert_ne(normal_index, -1)
	assert_ne(dark_index, -1)
	gallery._version_selector.item_selected.emit(normal_index)
	assert_true(preview.visible)
	var normal_texture: Texture2D = preview.texture
	assert_not_null(normal_texture)
	gallery._version_selector.item_selected.emit(dark_index)
	assert_true(preview.visible)
	assert_not_null(preview.texture)
	assert_ne(preview.texture, normal_texture)

	ART.set_overlay_info("", "cg.ending.alone.dark_mode",
		"res://tests/fixtures/art/missing.svg", Vector2i(1280, 448), "missing")
	gallery._version_selector.item_selected.emit(dark_index)
	assert_false(preview.visible)
	assert_null(preview.texture)
	var unreached := _tile(gallery, "ending.priscilla.sweet")
	assert_not_null(unreached)
	if unreached != null: unreached.pressed.emit()
	assert_false(preview.visible)
	assert_null(preview.texture)
	assert_false(gallery.get_node("%ReplayStatus").text.is_empty())
	assert_false(gallery.get_node("%ReplayStatus").text.contains("ending.priscilla.sweet"))
	assert_eq(_profile.get_gallery_discovery_snapshot(), discovery_before)
