extends GutTest

const ART := preload("res://scripts/data/ArtManifest.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const CATALOG := preload("res://scripts/ui/gallery/GalleryRecordCatalog.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")

const VALID_ART := "res://tests/fixtures/art/gallery-258x78.svg"
const WRONG_ART := "res://tests/fixtures/art/placement-cg.svg"

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
var _files: RefCounted

func before_each() -> void:
	ART.reload_placements()
	_files = FILES.new()
	_profile = PROFILE.new()
	add_child_autofree(_profile)
	assert_true(_profile.initialize(STORAGE.new("gallery-metadata.memory", _files)).get("ok", false))

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

func _mount(profile: Node, catalog: RefCounted, localization: Node = null) -> Dictionary:
	var home := Button.new()
	add_child_autofree(home)
	var bridge := ReplayBridge.new()
	var gallery: Control = GALLERY.instantiate()
	gallery._record_catalog = catalog
	assert_true(gallery.configure_title_host(home, localization, profile).get("ok", false))
	assert_true(gallery.configure_replay(bridge).get("ok", false))
	add_child_autofree(gallery)
	gallery.open_in_title_host()
	await _settle()
	return {"gallery": gallery, "bridge": bridge}

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _baseline(profile: Node, files: RefCounted) -> Dictionary:
	return {"profile": profile.get_profile_snapshot(),
		"discovery": profile.get_gallery_discovery_snapshot(),
		"bytes": files.snapshot_persisted()}

func _assert_unchanged(profile: Node, files: RefCounted, bridge: ReplayBridge,
		before: Dictionary) -> void:
	assert_eq(profile.get_profile_snapshot(), before.profile)
	assert_eq(profile.get_gallery_discovery_snapshot(), before.discovery)
	assert_eq(files.snapshot_persisted(), before.bytes)
	assert_true(bridge.starts.is_empty())

func _media(paper: Control) -> Texture2D:
	return paper._media.texture

func _assert_copy(paper: Control, sentence: String, has_media: bool) -> void:
	assert_true(paper.title_label.visible)
	assert_false(paper.title_label.text.is_empty())
	assert_eq(paper.sentence_label.text, sentence)
	assert_eq(paper.sentence_label.visible, not sentence.is_empty())
	assert_eq(_media(paper) != null, has_media)
	assert_eq(paper.title_label.position.y, 176.0 if has_media else 0.0)
	if has_media:
		assert_eq(_media(paper).get_size(), Vector2(258, 78))
	if not sentence.is_empty():
		assert_eq(paper.sentence_label.position.y,
			paper.title_label.position.y + paper.title_label.size.y + 16.0)

func test_exact_version_and_locale_republish_authored_details_without_side_effects() -> void:
	ART.set_overlay_info("", "fixture.gallery.default", VALID_ART, Vector2i(258, 78), "fixture")
	var normal := _alone("ending.alone.normal", "alone_normal")
	var dark := _alone("ending.alone.dark_mode", "alone_dark_mode")
	_record(normal)
	_record(dark)
	assert_true(_profile.unlock_ending("ending.alone", "gallery-metadata:alone").get("ok", false))
	var catalog := CATALOG.new({"ending.alone": {
		"sentence": ["Default EN", "默认简", "預設繁"],
		"media_asset_id": "fixture.gallery.default"}}, [
		{"signature": normal, "sentence": ["Normal EN", "普通简", "普通繁"]},
		{"signature": dark, "sentence": ["Dark EN", "暗色简", "暗色繁"],
			"media_asset_id": ""}])
	assert_true(catalog.valid)
	var localization := LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(_profile).get("ok", false))
	var mounted: Dictionary = await _mount(_profile, catalog, localization)
	var gallery: Control = mounted.gallery
	var bridge: ReplayBridge = mounted.bridge
	var normal_index := _version_index(gallery, "ending.alone.normal")
	var dark_index := _version_index(gallery, "ending.alone.dark_mode")
	assert_ne(normal_index, -1)
	assert_ne(dark_index, -1)
	var locales := ["en", "zh_CN", "zh_HK"]
	var normal_copy := ["Normal EN", "普通简", "普通繁"]
	var dark_copy := ["Dark EN", "暗色简", "暗色繁"]
	for locale_index: int in range(locales.size()):
		assert_true(localization.set_locale(locales[locale_index]).get("ok", false))
		await _settle()
		var before := _baseline(_profile, _files)
		gallery._version_selector.item_selected.emit(normal_index)
		await _settle()
		_assert_copy(gallery._record_paper, normal_copy[locale_index], true)
		gallery._version_selector.item_selected.emit(dark_index)
		await _settle()
		_assert_copy(gallery._record_paper, dark_copy[locale_index], false)
		_assert_unchanged(_profile, _files, bridge, before)

func test_wrong_sized_and_missing_media_collapse_media_space_but_keep_copy() -> void:
	ART.set_overlay_info("", "fixture.gallery.wrong", WRONG_ART, Vector2i(1280, 448), "fixture")
	ART.set_overlay_info("", "fixture.gallery.missing",
		"res://tests/fixtures/art/missing.svg", Vector2i(258, 78), "fixture")
	var normal := _alone("ending.alone.normal", "alone_normal")
	var dark := _alone("ending.alone.dark_mode", "alone_dark_mode")
	_record(normal)
	_record(dark)
	assert_true(_profile.unlock_ending("ending.alone", "gallery-metadata:media").get("ok", false))
	var catalog := CATALOG.new({}, [
		{"signature": normal, "sentence": ["Wrong size", "尺寸错误", "尺寸錯誤"],
			"media_asset_id": "fixture.gallery.wrong"},
		{"signature": dark, "sentence": ["Missing", "缺失", "缺失"],
			"media_asset_id": "fixture.gallery.missing"}])
	var before := _baseline(_profile, _files)
	var mounted: Dictionary = await _mount(_profile, catalog)
	var gallery: Control = mounted.gallery
	var bridge: ReplayBridge = mounted.bridge
	gallery._version_selector.item_selected.emit(_version_index(gallery, "ending.alone.normal"))
	await _settle()
	_assert_copy(gallery._record_paper, "Wrong size", false)
	gallery._version_selector.item_selected.emit(_version_index(gallery, "ending.alone.dark_mode"))
	await _settle()
	_assert_copy(gallery._record_paper, "Missing", false)
	assert_null(ART.get_texture("fixture.gallery.wrong", Vector2i(258, 78)))
	assert_null(ART.get_texture("fixture.gallery.missing", Vector2i(258, 78)))
	_assert_unchanged(_profile, _files, bridge, before)

func test_unreached_cross_record_empty_and_unavailable_never_leak_details() -> void:
	ART.set_overlay_info("", "fixture.gallery.leak", VALID_ART, Vector2i(258, 78), "fixture")
	var alone := _alone("ending.alone.normal", "alone_normal")
	_record(alone)
	assert_true(_profile.unlock_ending("ending.alone", "gallery-metadata:alone").get("ok", false))
	assert_true(_profile.unlock_ending("ending.priscilla.sweet", "gallery-metadata:unreached").get("ok", false))
	var catalog := CATALOG.new({"ending.priscilla.sweet": {
		"sentence": ["Unreached default", "未到达默认", "未到達預設"]}}, [
		{"signature": alone, "sentence": ["Alone exact", "独处精确", "獨處精確"],
			"media_asset_id": "fixture.gallery.leak"}])
	var before := _baseline(_profile, _files)
	var mounted: Dictionary = await _mount(_profile, catalog)
	var gallery: Control = mounted.gallery
	_tile(gallery, "ending.priscilla.sweet").pressed.emit()
	await _settle()
	assert_true(gallery._selected_signature_id().is_empty())
	_assert_copy(gallery._record_paper, "", false)
	_assert_unchanged(_profile, _files, mounted.bridge, before)

	var empty_files := FILES.new()
	var empty_profile := PROFILE.new()
	add_child_autofree(empty_profile)
	assert_true(empty_profile.initialize(STORAGE.new("gallery-metadata-empty.memory", empty_files)).get("ok", false))
	var empty_before := _baseline(empty_profile, empty_files)
	var empty_mount: Dictionary = await _mount(empty_profile, catalog)
	_assert_absent(empty_mount.gallery._record_paper)
	_assert_unchanged(empty_profile, empty_files, empty_mount.bridge, empty_before)

	var unavailable_files := FILES.new()
	var unavailable := UnavailableProfile.new()
	add_child_autofree(unavailable)
	assert_true(unavailable.initialize(STORAGE.new(
		"gallery-metadata-unavailable.memory", unavailable_files)).get("ok", false))
	var unavailable_profile_before := unavailable.get_profile_snapshot()
	var unavailable_bytes_before := unavailable_files.snapshot_persisted()
	var unavailable_mount: Dictionary = await _mount(unavailable, catalog)
	_assert_absent(unavailable_mount.gallery._record_paper)
	assert_eq(unavailable.get_profile_snapshot(), unavailable_profile_before)
	assert_eq(unavailable_files.snapshot_persisted(), unavailable_bytes_before)
	assert_true((unavailable_mount.bridge as ReplayBridge).starts.is_empty())

func _assert_absent(paper: Control) -> void:
	assert_false(paper.title_label.visible)
	assert_true(paper.title_label.text.is_empty())
	assert_false(paper.sentence_label.visible)
	assert_true(paper.sentence_label.text.is_empty())
	assert_null(_media(paper))
