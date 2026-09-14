extends GutTest

const PROFILE := preload("res://autoload/ProfileManager.gd")
const REPLAY := preload("res://scripts/application/ending/GalleryReplayOwner.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")

const LOCALES := ["en", "zh_CN", "zh_HK"]
const START_FAILED_KEY := "gallery.replay.start_failed"
const RETRY_KEY := "gallery.retry"

class CatalogLocale extends Node:
	signal locale_changed(locale: String)
	var locale := "en"
	var messages := {}
	func _init() -> void:
		for id: String in ["en", "zh_CN", "zh_HK"]:
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ui/%s.json" % id))
			var catalog := {}
			if parsed is Dictionary:
				for row: Variant in parsed.get("messages", []):
					if row is Dictionary: catalog[str(row.get("id", ""))] = str(row.get("text", ""))
			messages[id] = catalog
	func get_locale() -> String: return locale
	func has_key(key: String) -> bool: return (messages.get(locale, {}) as Dictionary).has(key)
	func t(key: String, _parameters: Dictionary = {}) -> String: return str(messages.get(locale, {}).get(key, key))
	func select(value: String) -> void:
		locale = value
		locale_changed.emit(value)

class ReplayBridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	var mode := "refuse"
	var starts: Array[String] = []
	var cancels: Array[String] = []
	var token_ordinal := 0
	var deny_cancel := false
	var active_signature := ""
	var active_token := ""
	func configure_reached_replay(_profile: Object) -> Dictionary: return {"ok": true}
	func replay_reached_signature(signature_id: String) -> Dictionary:
		starts.append(signature_id)
		if mode == "refuse": return {"ok": false, "code": &"narrative_playback_active", "value": null}
		token_ordinal += 1
		active_signature = signature_id
		active_token = "gallery:%d" % token_ordinal
		var receipt := {"playback_token": active_token}
		if mode in ["sync_start_failure", "sync_start_failure_ok", "wrong_start_failure"]:
			var failed := _failure(&"runtime_start_failed", &"start")
			if mode == "wrong_start_failure": failed.signature_id = "not-the-requested-signature"
			reached_replay_finished.emit(failed)
			active_signature = ""
			active_token = ""
			if mode == "sync_start_failure_ok": return {"ok": true, "receipt": receipt}
			return {"ok": false, "code": &"runtime_start_failed", "value": null,
				"failure_phase": &"start", "signature_id": failed.signature_id,
				"playback_token": failed.playback_token}
		if mode == "sync_completed_ok":
			complete()
			return {"ok": true, "receipt": receipt}
		return {"ok": true, "receipt": receipt}
	func fail(code: StringName = &"runtime_start_failed", phase: StringName = &"start") -> void:
		var result := _failure(code, phase)
		active_signature = ""
		active_token = ""
		reached_replay_finished.emit(result)
	func complete() -> void:
		var result := {"signature_id": active_signature, "playback_token": active_token,
			"outcome": "completed", "code": &""}
		active_signature = ""
		active_token = ""
		reached_replay_finished.emit(result)
	func cancel_reached_replay(signature_id: String) -> Dictionary:
		cancels.append(signature_id)
		if deny_cancel: return {"ok": false, "code": &"cancel_denied"}
		active_signature = ""
		active_token = ""
		return {"ok": true}
	func _failure(code: StringName, phase: StringName = &"") -> Dictionary:
		return {"signature_id": active_signature, "playback_token": active_token,
			"outcome": "failed", "code": code, "failure_phase": phase}

var _profile: Node
var _files: RefCounted
var _bridge: ReplayBridge
var _locale: CatalogLocale
var _gallery: Control
var _home: Button

func before_each() -> void:
	_files = FILES.new()
	_profile = PROFILE.new()
	add_child_autofree(_profile)
	assert_true(_profile.initialize(STORAGE.new("gallery-replay-status.memory", _files)).get("ok", false))
	_record(_alone("ending.alone.normal", "alone_normal"))
	_record(_alone("ending.alone.dark_mode", "alone_dark_mode"))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-status:fixture").get("ok", false))
	_bridge = ReplayBridge.new()
	_locale = CatalogLocale.new()
	add_child_autofree(_locale)
	_home = Button.new()
	add_child_autofree(_home)
	_gallery = GALLERY.instantiate()
	assert_true(_gallery.configure_title_host(_home, _locale, _profile).get("ok", false))
	assert_true(_gallery.configure_replay(_bridge).get("ok", false))
	add_child_autofree(_gallery)
	_gallery.open_in_title_host()
	await get_tree().process_frame

func _alone(entry_id: String, form: String) -> Dictionary:
	return {"entry_id": entry_id, "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": form}}

func _record(signature: Dictionary) -> void:
	assert_true(_profile.record_reached_presentation(signature).get("ok", false))

func _catalog(locale: String, key: String) -> String:
	return str(_locale.messages.get(locale, {}).get(key, ""))

func _replay_button() -> Button: return _gallery.get_node("%ReplayButton")
func _status() -> Label: return _gallery.get_node("%ReplayStatus")
func _selector() -> OptionButton: return _gallery.get("_version_selector")
func _selected_signature() -> String:
	var versions: Array = _gallery.get("_versions")
	var selected: int = _gallery.get("_selected_version")
	return str((versions[selected] as Dictionary).get("signature_id", ""))
func _view_state() -> Dictionary:
	return {"record": _gallery.get("_selected_id"), "version": _gallery.get("_selected_version"),
		"signature": _selected_signature(), "offset": _gallery.get("_index_offset")}

func _assert_catalog_copy(locale: String, expected_english: String) -> void:
	var failed_copy := _catalog(locale, START_FAILED_KEY)
	var retry_copy := _catalog(locale, RETRY_KEY)
	assert_false(failed_copy.is_empty(), "%s owns determinate start-failure copy" % locale)
	assert_false(retry_copy.is_empty(), "%s owns Retry copy" % locale)
	if locale == "en": assert_eq(failed_copy, expected_english)
	assert_eq(_status().text, failed_copy)
	assert_eq(_replay_button().text, retry_copy)
	assert_eq(_replay_button().accessibility_name, retry_copy)

func _assert_error_dock() -> void:
	assert_eq(_status().position, Vector2(408, 568))
	assert_eq(_status().size, Vector2(360, 64))
	assert_eq(_replay_button().position, Vector2(776, 568))
	assert_eq(_replay_button().size, Vector2(160, 64))
	assert_eq(_selector().position, Vector2(408, 488))
	assert_eq(_selector().size, Vector2(288, 64))
	assert_false(_selector().get_rect().intersects(_status().get_rect()))
	assert_false(_selector().get_rect().intersects(_replay_button().get_rect()))
	assert_eq(_selector().focus_mode, Control.FOCUS_ALL)

func test_determinate_synchronous_start_failure_is_stable_and_retry_reuses_exact_signature_without_mutation() -> void:
	_bridge.mode = "sync_start_failure"
	var button := _replay_button()
	button.grab_focus()
	await get_tree().process_frame
	var signature := _selected_signature()
	var view_before := _view_state()
	var profile_before: Dictionary = _profile.get_profile_snapshot()
	var files_before: Dictionary = _files.snapshot_persisted()
	button.pressed.emit()
	assert_eq(_bridge.starts, [signature])
	assert_eq(_view_state(), view_before)
	assert_eq(_profile.get_profile_snapshot(), profile_before)
	assert_eq(_files.snapshot_persisted(), files_before)
	assert_eq(get_viewport().gui_get_focus_owner(), button)
	assert_false(button.disabled)
	_assert_catalog_copy("en", "Replay did not begin")
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_POLITE)
	_assert_error_dock()

	button.release_focus()
	_selector().grab_focus()
	await get_tree().process_frame
	assert_eq(_status().text, _catalog("en", START_FAILED_KEY), "focus movement cannot clear Error")
	button.grab_focus()
	_bridge.mode = "accept"
	button.pressed.emit()
	assert_eq(_bridge.starts, [signature, signature], "Retry preserves the exact failed signature")
	assert_true(button.disabled)
	assert_eq(button.text, _catalog("en", "gallery.replay"))
	assert_eq(_status().text, _catalog("en", "gallery.replay.playing"))
	assert_eq(_profile.get_profile_snapshot(), profile_before)
	assert_eq(_files.snapshot_persisted(), files_before)

func test_synchronous_early_terminal_result_is_not_overwritten_by_successful_begin_return() -> void:
	_bridge.mode = "sync_start_failure_ok"
	var signature := _selected_signature()
	var before: Dictionary = _profile.get_profile_snapshot()
	_replay_button().grab_focus()
	_replay_button().pressed.emit()
	assert_eq(_bridge.starts, [signature])
	assert_false(_replay_button().disabled)
	_assert_catalog_copy("en", "Replay did not begin")
	assert_eq(get_viewport().gui_get_focus_owner(), _replay_button())
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_POLITE)
	_replay_button().pressed.emit()
	assert_eq(_bridge.starts, [signature, signature])
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF,
		"repeating the same determinate failure does not republish the old Error")

	_bridge.mode = "sync_completed_ok"
	_replay_button().pressed.emit()
	assert_eq(_bridge.starts, [signature, signature, signature])
	assert_eq(_status().text, "", "synchronous completion is not overwritten with Playing")
	assert_eq(_replay_button().text, _catalog("en", "gallery.replay"))
	assert_false(_replay_button().disabled)
	assert_eq(_profile.get_profile_snapshot(), before)

func test_async_start_failure_retains_error_across_locales_and_version_change_clears_it() -> void:
	_bridge.mode = "accept"
	_replay_button().grab_focus()
	var initial_signature := _selected_signature()
	_replay_button().pressed.emit()
	_bridge.fail(&"runtime_start_failed")
	for locale: String in LOCALES:
		_locale.select(locale)
		await get_tree().process_frame
		assert_eq(_selected_signature(), initial_signature)
		assert_eq(get_viewport().gui_get_focus_owner(), _replay_button())
		_assert_catalog_copy(locale, "Replay did not begin")
		assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF,
			"locale refresh translates retained Error without announcing it again")
		_assert_error_dock()
	var snapshot: Dictionary = _profile.get_profile_snapshot()
	_profile.profile_restored.emit(snapshot.duplicate(true))
	await get_tree().process_frame
	assert_eq(_selected_signature(), initial_signature)
	assert_eq(_status().text, _catalog("zh_HK", START_FAILED_KEY), "same-profile refresh retains exact Error")
	assert_eq(_replay_button().text, _catalog("zh_HK", RETRY_KEY))
	assert_eq(get_viewport().gui_get_focus_owner(), _replay_button())
	assert_eq(_status().accessibility_live, DisplayServer.LIVE_OFF)

	_selector().grab_focus()
	var replacement := 1 if int(_gallery.get("_selected_version")) == 0 else 0
	_selector().item_selected.emit(replacement)
	assert_eq(_status().text, "", "a new exact version command clears the stale start Error")
	assert_eq(_replay_button().text, _catalog("zh_HK", "gallery.replay"))
	assert_eq(get_viewport().gui_get_focus_owner(), _selector())
	assert_eq(_bridge.starts.size(), 1)

func test_only_a_different_record_or_version_command_clears_error_without_starting_replay() -> void:
	assert_true(_profile.unlock_ending("ending.priscilla.sweet", "gallery-status:other-record").get("ok", false))
	await get_tree().process_frame
	_bridge.mode = "sync_start_failure"
	_replay_button().pressed.emit()
	assert_eq(_status().text, _catalog("en", START_FAILED_KEY))
	var starts_before: Array[String] = _bridge.starts.duplicate()
	var selected_tile: Button = null
	var different_tile: Button = null
	for child: Node in _gallery.get_node("%EndingTileGrid").get_children():
		if str(child.get_meta(&"gallery_record_id")) == str(_gallery.get("_selected_id")):
			selected_tile = child as Button
		else:
			different_tile = child as Button
	assert_not_null(selected_tile)
	assert_not_null(different_tile)
	if selected_tile == null or different_tile == null: return
	selected_tile.pressed.emit()
	assert_eq(_status().text, _catalog("en", START_FAILED_KEY), "same record is not a new command target")
	_selector().item_selected.emit(int(_gallery.get("_selected_version")))
	assert_eq(_status().text, _catalog("en", START_FAILED_KEY), "same exact version does not clear Error")
	different_tile.pressed.emit()
	assert_ne(_status().text, _catalog("en", START_FAILED_KEY))
	assert_eq(_replay_button().text, _catalog("en", "gallery.replay"))
	assert_eq(_bridge.starts, starts_before)
	assert_eq(get_viewport().gui_get_focus_owner(), different_tile)

func test_unproved_refusal_and_post_start_replacement_do_not_claim_pre_session_retry() -> void:
	var ordinary_replay := _catalog("en", "gallery.replay")
	_replay_button().pressed.emit()
	assert_eq(_replay_button().text, ordinary_replay)
	assert_ne(_status().text, _catalog("en", START_FAILED_KEY))
	_bridge.mode = "wrong_start_failure"
	_replay_button().pressed.emit()
	assert_eq(_replay_button().text, ordinary_replay, "a different signature cannot authorize Retry")
	assert_ne(_status().text, _catalog("en", START_FAILED_KEY))

	_bridge.mode = "accept"
	_replay_button().pressed.emit()
	_bridge.fail(&"runtime_playback_replaced", &"live")
	assert_eq(_status().text, _catalog("en", "gallery.replay.failed"))
	assert_eq(_replay_button().text, ordinary_replay)
	assert_ne(_status().text, _catalog("en", START_FAILED_KEY))

func test_exit_clears_start_error_and_denied_cancel_retains_active_replay() -> void:
	_bridge.mode = "sync_start_failure"
	_replay_button().pressed.emit()
	assert_eq(_status().text, _catalog("en", START_FAILED_KEY))
	assert_true(_gallery.close_for_title_host())
	_gallery.open_in_title_host()
	await get_tree().process_frame
	assert_eq(_status().text, "")
	assert_eq(_replay_button().text, _catalog("en", "gallery.replay"))
	_bridge.mode = "accept"
	_replay_button().pressed.emit()
	_bridge.deny_cancel = true
	assert_false(_gallery.close_for_title_host())
	assert_true(_gallery.visible)
	assert_true(_replay_button().disabled)
	assert_eq(_bridge.cancels, [_selected_signature()])
