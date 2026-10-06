extends SceneTree
## Explicit TEST replay captions: real Menu/Gallery exit and durable History, no story claim.
## Native line wait/visible-layer lookup follow the accepted reading-rail journey,
## without inheriting its canonical run, Save/Load, or ending-completion setup.

const LOCATOR := preload("res://tests/support/EndingReadingTimelineCatalog.gd")
const FIXTURE := preload("res://tests/support/EndingReadingFixture.gd")
const MENU := preload("res://scenes/menu/MenuScene.tscn")
const ENTRY := "ending.sylvia.special.full"
const FIRST := "fixture.ending.first"
const SECOND := "fixture.ending.prior"
const UNSEEN := "fixture.ending.boundary"

class ExitFiles extends "res://scripts/infrastructure/storage/FileOps.gd":
	var refuse_writes := false
	var refuse_cleanup := false
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if refuse_writes and "/profile.json" in path: return {"ok": false, "code": &"fixture_write_refused"}
		return super.write_bytes(path, bytes)
	func remove_path(path: String) -> Dictionary:
		if refuse_cleanup and path.ends_with("/profile.json.txn.json"): return {"ok": false, "code": &"fixture_cleanup_refused"}
		return super.remove_path(path)

class LongCopy extends "res://scripts/ui/gallery/GalleryRecordCatalog.gd":
	func projection(_record_id: String, _signature: String, _locale: String) -> Dictionary:
		return {"sentence": "TEST record copy for retained paper scrolling.\n".repeat(40), "media_asset_id": ""}

var _menu: Control
var _exit_files := ExitFiles.new()
var _return_context: Dictionary = {}

var _bridge: Node
var _profile: Node
var _gallery: Control
var _adapter: RefCounted
var _signature_id := ""
var _folder := ""
var _profile_path := ""
var _baseline: Dictionary = {}
var _publications: Array[Dictionary] = []
var _samples: Array[Dictionary] = []
var _failures: Array[String] = []
var _checks := 0
var _active_attempt := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_folder = OS.get_environment("DWM_GALLERY_COLLECTION_OUTPUT")
	if _folder.is_empty(): _folder = ProjectSettings.globalize_path("user://evidence/gallery_caption_collection")
	if not _check(DisplayServer.get_name() != "headless" and not OS.get_environment("DWM_TEST_ROOT").is_empty(), "isolated rendered runner required") \
			or not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "evidence folder unavailable"):
		_finish()
		return
	for frame: int in 180:
		if root.get_node("ApplicationBootstrap").get_startup_state().get("ready", false): break
		await process_frame
	if not _check(root.get_node("ApplicationBootstrap").get_startup_state().get("ready", false), "production startup not ready"):
		_finish()
		return
	_bridge = root.get_node("DialogicBridge")
	_profile = root.get_node("ProfileManager")
	var signature := _signature()
	var admissions: Array[Dictionary] = [{"signature": signature, "collectable_line_ids": [FIRST]}]
	if not _check(_bridge.initialize(LOCATOR).get("ok", false), "fixture locator rejected") \
			or not _check(_bridge.configure_reached_caption_collection(FIXTURE.catalogue(), admissions).get("ok", false), "explicit replay caption admission rejected") \
			or not _check(_profile.unlock_ending("ending.sylvia.special", "caption-collection:TEST").get("ok", false), "fixture discovery rejected"):
		_finish()
		return
	var reached: Dictionary = _profile.record_reached_presentation(signature)
	if not _check(reached.get("ok", false), "fixture exact signature rejected"):
		_finish()
		return
	_signature_id = str(reached.value.signature_id)
	# Mount the production Menu host, then enter through its actual Gallery command.
	_menu = MENU.instantiate()
	if not _check(_menu.configure_gallery_replay(_profile, _bridge).get("ok", false), "Menu replay services rejected"):
		_finish()
		return
	root.add_child(_menu)
	await _frames()
	_menu.get_node("%GalleryButton").grab_focus()
	await process_frame
	await _key(KEY_SPACE)
	_gallery = _menu.get("_gallery_instance")
	if not _check(is_instance_valid(_gallery) and _gallery.is_visible_in_tree(), "Menu did not open Gallery"):
		_finish()
		return
	_gallery.set("_record_catalog", LongCopy.new())
	for ending_id: String in preload("res://scripts/profile/ProfileSchema.gd").ENDING_IDS:
		_check(_profile.unlock_ending(ending_id, "caption-collection:scroll-TEST:" + ending_id).get("ok", false), "scroll fixture discovery refused")
	var other := signature.duplicate(true)
	other.fields.ending_role = "primary"
	_check(_profile.record_reached_presentation(other).get("ok", false), "second witnessed version refused")
	_profile.publish_restore()
	await _frames()
	for row: Button in _gallery.get_node("%EndingTileGrid").get_children():
		if row.get_meta(&"gallery_record_id") == "ending.sylvia.special": row.pressed.emit()
	for index: int in _gallery.get("_versions").size():
		if _gallery.get("_versions")[index].signature_id == _signature_id: _gallery.call("_on_version_selected", index)
	await _frames()
	_gallery.set("_index_offset", 48.0)
	_gallery.call("_update_scroll")
	_gallery.get("_record_paper").scroll_to(96.0)
	_return_context = _context()
	_check(_return_context.index > 0 and _return_context.paper > 0, "fixture must exercise nonzero scroll anchors")
	_adapter = _bridge.get("_runtime_adapter")
	_adapter.caption_publication_recorded.connect(_on_publication)
	var storage: RefCounted = _profile.get("_storage")
	_profile_path = str(storage.get("_root_dir")).path_join("profile.json")
	storage.set("_file_ops", _exit_files)
	if not _check(FileAccess.file_exists(_profile_path), "isolated persisted Profile missing"):
		_finish()
		return
	_baseline = _state()
	_active_attempt = 1
	if not await _start_and_wait(FIRST):
		_finish()
		return
	var first: Dictionary = _bridge.capture_reached_caption_collection()
	var old_frontier: Dictionary = _bridge.capture_current_line_presentation_frontier()
	if not _check(first.get("ok", false) and _line_ids(first) == [FIRST], "visible first caption not collected exactly") \
			or not _check(old_frontier.get("ok", false) and _bridge.is_current_line_presentation_acknowledged(), "visible source acknowledgement missing") \
			or not _check(_empty_first_publication(1), "publication alone collected before mounted acknowledgement") \
			or not _unchanged("first visible acknowledgement"):
		_finish()
		return
	# Returned collections are detached. This edit must not replace the owner proof.
	var detached: Dictionary = _bridge.capture_reached_caption_collection()
	detached.value.captions[0].line_id = "TEST forged detached copy"
	if not _check(_line_ids(_bridge.capture_reached_caption_collection()) == [FIRST], "collection query leaked mutable storage") \
			or not await _capture("first-visible", first):
		_finish()
		return
	var next: Dictionary = await _bridge.request_next(old_frontier)
	var save: Dictionary = _bridge.capture_reading_checkpoint()
	var skip: Dictionary = _bridge.request_skip_step()
	if not _check(not next.get("ok", false) and not save.get("ok", false)
			and not skip.get("ok", false) and not _bridge.can_auto_advance_current_line(), "transient replay acquired canonical transport or Save authority"):
		_finish()
		return
	# Two fresh physical Accepts reveal then advance, following native caption rules.
	for press: int in 2:
		if _adapter.current_line_id() == SECOND: break
		await _accept()
	if not await _wait_visible(SECOND):
		_finish()
		return
	var second: Dictionary = _bridge.capture_reached_caption_collection()
	if not _check(_bridge.is_current_line_presentation_acknowledged(), "visible noncollectable source was not acknowledged") \
			or not _check(_line_ids(second) == [FIRST], "noncollectable or unseen caption entered candidate") \
			or not _check(not _published(UNSEEN), "fixture advanced into unseen final caption") \
			or not _unchanged("second visible acknowledgement") \
			or not await _capture("second-visible-not-collectable", second):
		_finish()
		return
	_profile.publish_restore() # Separate refresh while replay owns the exact return address.
	_menu.call("_return_from_title_host")
	await _frames()
	if not _check(not _bridge.capture_reached_caption_collection().get("ok", false), "closed candidate remained accessible") \
			or not _check(_gallery.is_visible_in_tree() and _context() == _return_context, "exit did not restore exact Gallery context") \
			or not _check(_gallery.get_node("%ReplayButton").has_focus(), "exit did not restore Replay focus") \
			or not _check(_gallery.get("_status_key") == "gallery.history.added", "new durable History notice missing") \
			or not _check(_profile.is_line_visited(FIRST) and not _profile.is_line_visited(SECOND) and not _profile.is_line_visited(UNSEEN), "durable History admitted unseen/ineligible lines"):
		_finish()
		return
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(_profile_path))
	_check(disk is Dictionary and FIRST in disk.visited_line_ids and SECOND not in disk.visited_line_ids and UNSEEN not in disk.visited_line_ids, "Profile bytes disagree with confirmed notice")
	_check(_state().game == _baseline.game, "exit changed canonical run")
	for key: String in _baseline.profile:
		if key not in ["visited_line_ids", "witnessed_caption_variants"]:
			_check(_profile.get_profile_snapshot()[key] == _baseline.profile[key], "unrelated Profile mutation: " + key)
	_profile.publish_restore()
	await _frames()
	_check(_gallery.get("_status_key") == "gallery.history.added" and _context() == _return_context, "Profile restoration refresh cleared notice or context")
	_menu.call("_on_gallery_pressed")
	_check(_gallery.get("_status_key") == "gallery.history.added" and _context() == _return_context, "same Gallery command reset context")
	await _status_locales()
	# Restore ordinary fixture preferences and prove a version command clears notice.
	root.get_node("LocalizationManager").set_locale("en")
	_profile.set_preference(&"preferences.accessibility.text_size", 100)
	_gallery.call("_on_version_selected", int(_gallery.get("_selected_version")))
	_check(_gallery.get("_status_key") == "", "same-version command did not clear notice")
	_baseline = _state()
	_active_attempt = 2
	if not await _start_and_wait(FIRST):
		_finish()
		return
	var restarted: Dictionary = _bridge.capture_reached_caption_collection()
	var refused: Dictionary = _bridge.acknowledge_current_line_presentation(old_frontier)
	if not _check(restarted.get("ok", false) and restarted.value.playback_token != first.value.playback_token, "restart did not acquire a new replay token") \
			or not _check(_empty_first_publication(2), "restart retained collection before its new visible acknowledgement") \
			or not _check(not refused.get("ok", false), "old replay frontier accepted after restart") \
			or not _check(_bridge.capture_reached_caption_collection() == restarted, "stale frontier changed the new collection") \
			or not _unchanged("restart and stale acknowledgement") \
			or not await _capture("restarted-visible", restarted):
		_finish()
		return
	_menu.call("_return_from_title_host")
	var commanded_row: Button
	for row: Button in _gallery.get_node("%EndingTileGrid").get_children():
		if row.get_meta(&"gallery_record_id") == _gallery.get("_selected_id"):
			commanded_row = row
			row.grab_focus()
			row.pressed.emit()
	await _frames()
	_check(is_instance_valid(commanded_row) and commanded_row.has_focus(), "deferred replay restoration stole later record-command focus")
	_check(not _bridge.capture_reached_caption_collection().get("ok", false), "second close retained candidate")
	_check(_gallery.get("_status_key") == "", "duplicate-only replay announced additions")
	_unchanged("duplicate-only exit")
	# A fresh actual batch exercises proven FileOps refusal, blocked destinations,
	# then natural completion and an uncertain disk promotion.
	_check(_profile.reset_visited_history().get("ok", false), "failure-fixture reset refused")
	_active_attempt = 3
	if not await _start_and_wait(FIRST):
		_finish()
		return
	var held: Dictionary = _bridge.capture_reached_caption_collection()
	_exit_files.refuse_writes = true
	_menu.call("_on_setting_pressed")
	await _frames()
	_check(_gallery.is_visible_in_tree() and not _menu.get("_setting_host").visible, "Settings opened over retained exit")
	_check(_gallery.get("_status_key") == "gallery.history.failed", "proven failure copy missing")
	_check(_bridge.capture_reached_caption_collection() == held, "refused exit lost exact batch")
	await _status_capture("failed-real")
	_menu.call("_on_log_in_pressed")
	await _frames()
	_check(not _menu.get("_backup_app_host").visible, "Log in bypassed retained exit")
	_menu.call("_on_new_acc_pressed")
	await _frames()
	_check(_menu.get("_new_acc_token") == "" and _gallery.is_visible_in_tree(), "New Acc bypassed retained exit")
	_menu.call("_on_shut_down_pressed")
	_check(not is_instance_valid(_menu.get("_confirmation")), "Shutdown confirmation bypassed retained exit")
	_menu.call("_on_gallery_pressed")
	_check(_bridge.capture_reached_caption_collection() == held, "same Gallery command discarded custody")
	_exit_files.refuse_writes = false
	_menu.call("_return_from_title_host")
	await _frames()
	_check(_gallery.get("_status_key") == "gallery.history.added", "fresh close did not confirm retained batch")
	_check(_profile.reset_visited_history().get("ok", false), "natural-fixture reset refused")
	_active_attempt = 4
	if not await _start_and_wait(FIRST):
		_finish()
		return
	# Finish through real caption input, including the noncollectable final line.
	for step: int in 12:
		if not _bridge.has_active_playback(): break
		await _accept()
	await _frames()
	_check(not _bridge.has_active_playback() and _gallery.get("_status_key") == "gallery.history.added", "natural completion did not merge and restore Gallery")
	_check(_profile.reset_visited_history().get("ok", false), "uncertain-fixture reset refused")
	_active_attempt = 5
	if not await _start_and_wait(FIRST):
		_finish()
		return
	held = _bridge.capture_reached_caption_collection()
	_exit_files.refuse_cleanup = true
	_menu.call("_return_from_title_host")
	await _frames()
	_check(_gallery.get("_status_key") == "gallery.history.uncertain", "uncertain durability copy missing")
	_check(_bridge.capture_reached_caption_collection() == held and _gallery.is_visible_in_tree(), "uncertain exit discarded custody")
	await _status_capture("uncertain-real")
	_menu.call("_on_setting_pressed")
	_menu.call("_on_log_in_pressed")
	await _frames()
	_check(not _menu.get("_setting_host").visible and not _menu.get("_backup_app_host").visible, "uncertainty allowed destination switch")
	_finish()

func _context() -> Dictionary:
	return {"record": _gallery.get("_selected_id"), "signature": _gallery.call("_selected_signature_id"),
		"index": _gallery.get("_index_offset"), "paper": _gallery.get("_record_paper").scroll_offset}

func _status_locales() -> void:
	var prior_style: String = _profile.get_preference(&"preferences.accessibility.font_style", "pixel")
	for style: String in ["pixel", "readable"]:
		_check(root.get_node("LocalizationManager").set_font_style(style).get("ok", false), "font style refused")
		_check(_profile.get_preference(&"preferences.accessibility.font_style") == style, "matrix font style was not applied")
		for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
			_check(root.get_node("LocalizationManager").set_locale(locale).get("ok", false), "locale refused")
			for percent: int in [100, 125, 150]:
				_check(_profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false), "text size refused")
				for status: String in ["added", "failed", "uncertain"]:
					# Projection-only matrix; real owner outcomes are checked separately.
					_gallery.set("_history_status", "gallery.history." + status)
					_gallery.call("_set_replay_status", "gallery.history." + status)
					await _frames()
					await _status_capture("status-%s-%s-%d-%s" % [style, locale, percent, status])
	root.get_node("LocalizationManager").set_font_style(prior_style)
	_gallery.set("_history_status", "gallery.history.added")
	_gallery.call("_set_replay_status", "gallery.history.added")

func _status_capture(name: String) -> void:
	var status: Label = _gallery.get_node("%ReplayStatus")
	_check(not status.text.is_empty() and not status.text.begins_with("gallery."), "status untranslated")
	var line_height: float = status.get_theme_font("font").get_height(status.get_theme_font_size("font_size"))
	_check(status.get_line_count() * line_height <= 64.0, "status exceeds dock height")
	_check(status.position.x + status.size.x <= _gallery.get_node("%ReplayButton").position.x, "status overlaps Replay action")
	if _gallery.get("_status_key") == "gallery.history.added":
		_check(not _gallery.get("_canvas").history_failed and status.get_theme_color("font_color") == _gallery.theme.get_color("ink", "Gallery"), "success inherited failure styling")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty() and image.save_png(_folder.path_join(name + ".png")) == OK, "status capture failed")
	_samples.append({"file": name + ".png", "status": status.text, "rect": str(status.get_rect()), "context": _context()})

func _signature() -> Dictionary:
	return {"entry_id": ENTRY, "schema_version": 1, "fields": {"tier": "friend", "tone": "sweet",
		"attitude": "", "echo_ids": [], "miss_reasons": [], "ending_role": "core",
		"ending_form": "special_full", "residue": false}}

func _start_and_wait(line_id: String) -> bool:
	if not _check(str(_gallery.call("_selected_signature_id")) == _signature_id, "Gallery selected another exact signature"): return false
	var button: Button = _gallery.get_node("%ReplayButton")
	button.grab_focus()
	await _key(KEY_SPACE)
	return await _wait_visible(line_id)

func _layer() -> Node:
	var layout: Node = root.get_node("Dialogic").Styles.get_layout_node()
	return layout.find_child("WitnessedCaptionLayer", true, false) if is_instance_valid(layout) else null

func _wait_visible(line_id: String) -> bool:
	var expected := ""
	for line: Dictionary in FIXTURE.catalogue().entries[0].lines:
		if str(line.line_id) == line_id: expected = str(line.text)
	for frame: int in 240:
		var layer: Node = _layer()
		if _adapter.current_line_id() == line_id and layer != null \
				and layer.caption_text.is_visible_in_tree() and layer.caption_text.get_parsed_text() == expected \
				and layer.caption_text.visible_ratio > 0.0 and _bridge.is_current_line_presentation_acknowledged():
			await _frames()
			return true
		await process_frame
	return _check(false, "visible acknowledged fixture caption did not arrive: " + line_id)

func _on_publication(result: Dictionary) -> void:
	var collection: Dictionary = _bridge.capture_reached_caption_collection()
	_publications.append({"attempt": _active_attempt, "publication": result.duplicate(true),
		"line_id": str(_adapter.current_line_id()), "collected_line_ids": _line_ids(collection)})

func _empty_first_publication(attempt: int) -> bool:
	for row: Dictionary in _publications:
		if int(row.attempt) == attempt and str(row.line_id) == FIRST:
			return row.publication.get("ok", false) and row.collected_line_ids.is_empty()
	return false

func _published(line_id: String) -> bool:
	for row: Dictionary in _publications:
		if str(row.line_id) == line_id: return true
	return false

func _line_ids(collection: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if collection.get("ok", false):
		for beat: Dictionary in collection.value.captions: result.append(str(beat.line_id))
	return result

func _state() -> Dictionary:
	return {"profile": _profile.get_profile_snapshot(), "revision": _profile.get_profile_revision(),
		"bytes": FileAccess.get_file_as_bytes(_profile_path),
		"game": root.get_node("GameState").capture_run_snapshot_input()}

func _unchanged(stage: String) -> bool:
	return _check(_state() == _baseline, "Profile or canonical run changed at " + stage)

func _accept() -> void:
	var layer: Node = _layer()
	if layer == null: return
	layer.caption_text.grab_focus()
	await process_frame
	await _key(KEY_ENTER)

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()

func _frames() -> void:
	for frame: int in 12: await process_frame

func _capture(name: String, collection: Dictionary) -> bool:
	var expected_line: String = _adapter.current_line_id()
	if not _check(_adapter.reveal_current_line(true).get("ok", false), "native current-line reveal refused"): return false
	await _frames()
	if not _check(_adapter.current_line_id() == expected_line and _bridge.capture_reached_caption_collection() == collection, "capture reveal advanced or changed collected records"): return false
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not _check(image != null and not image.is_empty() and image.save_png(_folder.path_join(name + ".png")) == OK, "render capture failed"): return false
	var layer: Node = _layer()
	_samples.append({"file": name + ".png", "caption": layer.caption_text.get_parsed_text(),
		"visible_ratio": layer.caption_text.visible_ratio, "collection": collection.duplicate(true),
		"profile_revision": _profile.get_profile_revision(), "profile_and_run_unchanged": true})
	return true

func _check(value: bool, detail: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(detail)
		push_error("GALLERY_CAPTION_COLLECTION_RENDER_FAILED: " + detail)
	return value

func _finish() -> void:
	if DirAccess.dir_exists_absolute(_folder):
		var report := FileAccess.open(_folder.path_join("measurements.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"ok": _failures.is_empty(), "checks": _checks,
				"failures": _failures, "samples": _samples, "publications": _publications,
				"scope": "Explicit fixture-only replay admission, real Gallery/Bridge/Profile/native Dialogic and mounted CaptionLayer; durable exit merging, refusal/uncertainty and locale projections. No production content admission, physical keyboard, or native accessibility claim."}, "\t") + "\n")
			report.close()
	print("GALLERY_CAPTION_COLLECTION_RENDER_", "VERIFIED" if _failures.is_empty() else "FAILED", " captures=", _samples.size(), " evidence=", _folder)
	quit(0 if _failures.is_empty() else 1)
