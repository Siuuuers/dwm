extends GutTest

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const CATALOG := preload("res://scripts/ui/gallery/GalleryRecordCatalog.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const GALLERY_PRESENTER := preload("res://scripts/ui/GalleryScene.gd")
const ENTRY_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const GOOD_DATE_ID := "dating.solo.lavinia.day2.pre_challenge"
const BAD_DATE_ID := "dating.solo.sylvia.day1.pre_challenge"

class TitlelessGallery extends GALLERY_PRESENTER:
	func _trusted_record_title(_record_id: String) -> String: return ""

class LocatorCatalog extends RefCounted:
	static var mode := "valid"
	static func get_entry(entry_id: String, locale: String) -> Dictionary:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/manifests/dialogic_entries.json"))
		for row: Dictionary in document.entries:
			if row.entry_id != entry_id: continue
			if mode == "missing_locator": row.locators.erase("en")
			elif mode == "missing_master": row.locators.en.path = "res://tests/fixtures/dialogic/not-installed.dtl"
			elif mode == "duplicate_locator":
				for other: Dictionary in document.entries:
					if other.entry_id != entry_id:
						other.locators.en = row.locators.en.duplicate(true)
						break
			break
		return ENTRY_MANIFEST.resolve_entry(document, entry_id, locale)

class FaultProfile extends PROFILE:
	var reached_mode := "valid"

	func get_reached_presentations(entry_id: String = "") -> Dictionary:
		if reached_mode == "failure":
			return {"ok": false, "code": &"reached_presentations_unavailable", "value": null}
		if reached_mode == "empty": return {"ok": true, "value": {"records": []}}
		var result: Dictionary = super.get_reached_presentations(entry_id)
		if reached_mode in ["mixed", "mixed_repaired"]:
			for record: Dictionary in result.value.records:
				if reached_mode == "mixed" \
						and record.signature.entry_id == "dating.solo.sylvia.day1.pre_challenge":
					record.signature.schema_version = 2
			result.value.records.append({"signature_id": "corrupt-ordinary", "signature": {
				"entry_id": "contact.ordinary.lavinia.day1", "schema_version": 2, "fields": {}}})
			result.value.records.append({"signature_id": "corrupt-unknown", "signature": {
				"entry_id": "unknown.gallery.fixture", "schema_version": 1, "fields": {}}})
			return result
		if reached_mode == "valid" or not result.get("ok", false): return result
		for record: Dictionary in result.value.records:
			match reached_mode:
				"schema": record.signature.schema_version = 2
				"signature": record.signature.fields.ending_form = "unregistered_form"
				"digest": record.signature_id = "0".repeat(64)
		return result

class ReplayBridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	var refuse := false
	var starts: Array[String] = []

	func configure_reached_replay(_profile: Object) -> Dictionary:
		return {"ok": true}

	func replay_reached_signature(signature_id: String) -> Dictionary:
		starts.append(signature_id)
		if refuse:
			return {"ok": false, "code": &"narrative_playback_active", "value": null}
		return {"ok": true, "receipt": {"playback_token": "fixture"}}

	func cancel_reached_replay(_signature_id: String) -> Dictionary:
		return {"ok": true}

var _profile: FaultProfile
var _files: RefCounted
var _localization: Node
var _bridge: ReplayBridge
var _gallery: Control

func before_each() -> void:
	_files = FILES.new()
	_profile = FaultProfile.new()
	add_child_autofree(_profile)
	assert_true(_profile.initialize(STORAGE.new("gallery-record-unavailable.memory", _files)).get("ok", false))
	assert_true(_profile.record_reached_presentation(_alone()).get("ok", false))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-unavailable:fixture").get("ok", false))
	_localization = LOCALIZATION.new()
	add_child_autofree(_localization)
	assert_true(_localization.initialize(_profile).get("ok", false))
	_bridge = ReplayBridge.new()

func _alone() -> Dictionary:
	return {"entry_id": "ending.alone.normal", "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": "alone_normal"}}

func _date(entry_id: String) -> Dictionary:
	return {"entry_id": entry_id, "schema_version": 1,
		"fields": {"tier": "ambiguous", "tone": "sweet", "attitude": "neutral",
			"echo_ids": []}}

func _tile(record_id: String) -> Button:
	for tile: Button in _gallery.get_node("%EndingTileGrid").get_children():
		if tile.get_meta(&"gallery_record_id") == record_id: return tile
	return null

func _tile_index(record_id: String) -> int:
	var rows: Array[Node] = _gallery.get_node("%EndingTileGrid").get_children()
	for index: int in range(rows.size()):
		if rows[index].get_meta(&"gallery_record_id") == record_id: return index
	return -1

func _mount(mode: String, with_details: bool = false, titleless: bool = false) -> void:
	_profile.reached_mode = mode
	var home := Button.new()
	add_child_autofree(home)
	_gallery = GALLERY.instantiate()
	if titleless: _gallery.set_script(TitlelessGallery)
	if with_details:
		_gallery._record_catalog = CATALOG.new({}, [{"signature": _alone(),
			"sentence": ["Exact archived detail", "Exact archived detail", "Exact archived detail"]}])
	assert_true(_gallery.configure_title_host(home, _localization, _profile).get("ok", false))
	assert_true(_gallery.configure_replay(_bridge).get("ok", false))
	add_child_autofree(_gallery)
	_gallery.open_in_title_host()
	await _settle()

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _baseline() -> Dictionary:
	return {"profile": _profile.get_profile_snapshot(), "bytes": _files.snapshot_persisted()}

func _assert_storage_unchanged(before: Dictionary) -> void:
	assert_eq(_profile.get_profile_snapshot(), before.profile)
	assert_eq(_files.snapshot_persisted(), before.bytes)

func _assert_required_record_unavailable(before: Dictionary) -> void:
	var rows: GridContainer = _gallery.get_node("%EndingTileGrid")
	assert_eq(_gallery._status_key, "gallery.record.unavailable",
		"invalid required record data is distinct from a valid unreached record")
	if _gallery._status_key != "gallery.record.unavailable": return
	var paper: Control = _gallery._record_paper
	var status: Label = _gallery.get_node("%ReplayStatus")
	var replay: Button = _gallery.get_node("%ReplayButton")
	var canvas: Control = _gallery.get_node("%GalleryHost")
	assert_eq(rows.get_child_count(), 1, "the discovered record keeps its personal position")
	assert_eq(rows.get_child(0).text, "A Quiet Morning")
	assert_true(paper.title_label.visible)
	assert_eq(paper.title_label.text, "A Quiet Morning")
	assert_eq(paper.title_label.position, Vector2.ZERO)
	var leaf_top: float = 48.0 + paper.title_label.size.y
	assert_eq(status.text, "Unavailable record")
	assert_eq(status.accessibility_name, status.text)
	assert_eq(status.position, Vector2(408, leaf_top + 8.0))
	assert_eq(canvas.get("unavailable_top"), leaf_top)
	assert_true(canvas.get("unavailable_record"))
	assert_true(replay.visible)
	assert_true(replay.disabled)
	assert_eq(replay.focus_mode, Control.FOCUS_NONE)
	assert_true(_gallery._version_selector.get_item_count() == 0)
	assert_false(_gallery._version_selector.visible)
	assert_false(paper.sentence_label.visible)
	assert_true(paper.sentence_label.text.is_empty())
	assert_null(paper._media.texture)
	assert_false(paper.has_overflow(), "required failure has no record scroll witness")
	assert_true(_bridge.starts.is_empty())
	_assert_storage_unchanged(before)

func test_required_record_query_and_invalid_exact_records_use_the_unavailable_leaf() -> void:
	var before := _baseline()
	await _mount("failure", true)
	_assert_required_record_unavailable(before)
	for mode: String in ["schema", "signature", "digest"]:
		_profile.reached_mode = mode
		_profile.profile_restored.emit(_profile.get_profile_snapshot())
		await _settle()
		_assert_required_record_unavailable(before)

	_profile.reached_mode = "valid"
	_profile.profile_restored.emit(_profile.get_profile_snapshot())
	await _settle()
	assert_false(_gallery.get_node("%GalleryHost").get("unavailable_record"))
	assert_true(_gallery.get_node("%ReplayStatus").text.is_empty())
	assert_false(_gallery.get_node("%ReplayButton").disabled)
	assert_eq(_gallery.get_node("%ReplayButton").focus_mode, Control.FOCUS_ALL)
	assert_eq(_gallery._record_paper.title_label.text, "A Quiet Morning")
	assert_eq(_gallery._record_paper.sentence_label.text, "Exact archived detail")
	assert_false(_gallery._record_paper.has_overflow())
	assert_true(_bridge.starts.is_empty())
	_assert_storage_unchanged(before)

func test_missing_english_locator_or_master_uses_existing_manifest_failure_without_starting() -> void:
	var before := _baseline()
	await _mount("valid", true)
	_gallery._replay_owner._entry_catalog = LocatorCatalog
	for mode: String in ["missing_locator", "duplicate_locator", "missing_master"]:
		LocatorCatalog.mode = mode
		_gallery._refresh_tiles()
		await _settle()
		_assert_required_record_unavailable(before)
	LocatorCatalog.mode = "valid"
	_gallery._refresh_tiles()
	await _settle()
	assert_false(_gallery.get_node("%GalleryHost").unavailable_record)
	assert_false(_gallery.get_node("%ReplayButton").disabled)
	assert_true(_bridge.starts.is_empty())
	_assert_storage_unchanged(before)

func test_missing_required_title_keeps_the_record_and_uses_titleless_leaf_geometry() -> void:
	var before := _baseline()
	await _mount("valid", true, true)
	assert_eq(_gallery._status_key, "gallery.record.unavailable")
	assert_eq(_gallery.get_node("%EndingTileGrid").get_child(0).text, "Unavailable record")
	assert_false(_gallery._record_paper.title_label.visible)
	assert_false(_gallery._record_paper.sentence_label.visible)
	assert_eq(_gallery.get_node("%GalleryHost").unavailable_top, 32.0)
	assert_eq(_gallery.get_node("%ReplayStatus").position, Vector2(408, 40))
	assert_true(_gallery.get_node("%ReplayButton").disabled)
	assert_true(_bridge.starts.is_empty())
	_assert_storage_unchanged(before)

func test_ordinary_bridge_refusal_uses_the_dock_without_staining_record_details() -> void:
	var before := _baseline()
	await _mount("valid", true)
	_bridge.refuse = true
	var title: String = _gallery._record_paper.title_label.text
	var sentence: String = _gallery._record_paper.sentence_label.text
	var replay: Button = _gallery.get_node("%ReplayButton")
	var selected_row: Button = _gallery.get_node("%EndingTileGrid").get_child(0)
	replay.grab_focus()
	replay.pressed.emit()
	await _settle()
	assert_eq(_gallery._status_key, "gallery.replay.unavailable")
	assert_false(_gallery.get_node("%GalleryHost").get("unavailable_record"))
	assert_eq(_gallery.get_node("%ReplayStatus").position, Vector2(408, 568))
	assert_eq(_gallery._record_paper.title_label.text, title)
	assert_eq(_gallery._record_paper.sentence_label.text, sentence)
	assert_eq(replay.text, "Replay")
	assert_true(replay.disabled)
	assert_eq(replay.focus_mode, Control.FOCUS_NONE)
	assert_true(selected_row.has_focus(), "ordinary refusal returns focus to the selected record")
	assert_eq(_bridge.starts.size(), 1, "ordinary refusal attempts only the selected exact signature")
	_assert_storage_unchanged(before)

func test_valid_no_versions_remains_a_genuine_unreached_record() -> void:
	var before := _baseline()
	await _mount("empty")
	assert_eq(_gallery._status_key, "gallery.replay.unreached")
	assert_false(_gallery.get_node("%GalleryHost").get("unavailable_record"))
	assert_eq(_gallery.get_node("%EndingTileGrid").get_child_count(), 1)
	assert_eq(_gallery._record_paper.title_label.text, "A Quiet Morning")
	assert_false(_gallery._record_paper.sentence_label.visible)
	assert_true(_gallery.get_node("%ReplayButton").disabled)
	assert_eq(_gallery.get_node("%ReplayButton").focus_mode, Control.FOCUS_NONE)
	assert_true(_bridge.starts.is_empty())
	_assert_storage_unchanged(before)

func test_mixed_corruption_is_scoped_to_the_known_invalid_date_and_recovers_in_place() -> void:
	assert_true(_profile.record_reached_presentation(_date(GOOD_DATE_ID)).get("ok", false))
	assert_true(_profile.record_reached_presentation(_date(BAD_DATE_ID)).get("ok", false))
	var before := _baseline()
	await _mount("mixed")
	var rows: GridContainer = _gallery.get_node("%EndingTileGrid")
	assert_eq(rows.get_child_count(), 3,
		"unrelated corrupt ordinary and unknown rows create no Gallery records")
	assert_not_null(_tile("ending.alone"))
	var good_date := _tile(GOOD_DATE_ID)
	var bad_date := _tile(BAD_DATE_ID)
	assert_not_null(good_date)
	assert_not_null(bad_date)
	if good_date == null or bad_date == null: return
	assert_eq(_gallery._selected_id, "ending.alone")
	assert_true(_gallery._status_key.is_empty())
	assert_false(_gallery.get_node("%ReplayButton").disabled,
		"the valid ending is not stained by unrelated corrupt rows")

	good_date.pressed.emit()
	await _settle()
	assert_eq(_gallery._selected_id, GOOD_DATE_ID)
	assert_true(_gallery._status_key.is_empty())
	assert_false(_gallery.get_node("%ReplayButton").disabled)
	assert_false(_gallery._selected_signature_id().is_empty())
	assert_ne(good_date.text, "Unavailable record")

	bad_date.pressed.emit()
	await _settle()
	assert_eq(_gallery._selected_id, BAD_DATE_ID)
	assert_eq(_gallery._status_key, "gallery.record.unavailable")
	assert_eq(_tile(BAD_DATE_ID).text, "Unavailable record")
	assert_true(_gallery.get_node("%ReplayButton").disabled)
	assert_true(_gallery._versions.is_empty())
	var retained_index := _tile_index(BAD_DATE_ID)
	assert_ne(retained_index, -1)
	assert_true(_bridge.starts.is_empty())
	_assert_storage_unchanged(before)

	_profile.reached_mode = "mixed_repaired"
	_profile.profile_restored.emit(_profile.get_profile_snapshot())
	await _settle()
	assert_eq(rows.get_child_count(), 3)
	assert_eq(_tile_index(BAD_DATE_ID), retained_index)
	assert_eq(_gallery._selected_id, BAD_DATE_ID)
	assert_true(_gallery._status_key.is_empty())
	assert_ne(_tile(BAD_DATE_ID).text, "Unavailable record")
	assert_false(_gallery.get_node("%ReplayButton").disabled)
	assert_false(_gallery._selected_signature_id().is_empty())
	assert_true(_bridge.starts.is_empty())
	_assert_storage_unchanged(before)
