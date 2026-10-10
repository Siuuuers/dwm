extends SceneTree
## Transient, explicitly admitted TEST replay captions; no History merge or story claim.
## Native line wait/visible-layer lookup follow the accepted reading-rail journey,
## without inheriting its canonical run, Save/Load, or ending-completion setup.

const LOCATOR := preload("res://tests/support/EndingReadingTimelineCatalog.gd")
const FIXTURE := preload("res://tests/support/EndingReadingFixture.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const ENTRY := "ending.sylvia.special.full"
const FIRST := "fixture.ending.first"
const SECOND := "fixture.ending.prior"
const UNSEEN := "fixture.ending.boundary"

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
	var home := Button.new()
	home.text = "TEST return"
	root.add_child(home)
	_gallery = GALLERY.instantiate()
	if not _check(_gallery.configure_title_host(home, root.get_node("LocalizationManager"), _profile).get("ok", false), "Gallery host rejected") \
			or not _check(_gallery.configure_replay(_bridge).get("ok", false), "Gallery replay owner rejected"):
		_finish()
		return
	root.add_child(_gallery)
	_gallery.open_in_title_host()
	await _frames()
	_adapter = _bridge.get("_runtime_adapter")
	_adapter.caption_publication_recorded.connect(_on_publication)
	var storage: RefCounted = _profile.get("_storage")
	_profile_path = str(storage.get("_root_dir")).path_join("profile.json")
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
	if not _check(_gallery.close_for_title_host(), "safe replay close refused"):
		_finish()
		return
	await _frames()
	if not _check(not _bridge.capture_reached_caption_collection().get("ok", false), "closed candidate remained accessible") \
			or not _unchanged("safe close discards transient candidate"):
		_finish()
		return
	_gallery.open_in_title_host()
	await _frames()
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
	if not _check(_gallery.close_for_title_host(), "second close refused"):
		_finish()
		return
	await _frames()
	_check(not _bridge.capture_reached_caption_collection().get("ok", false), "second close retained candidate")
	_unchanged("second close")
	_finish()

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
				"scope": "Explicit fixture-only replay admission, real Gallery/Bridge/Profile/native Dialogic and mounted CaptionLayer; transient collection only. No merge, production content admission, physical keyboard, or native accessibility claim."}, "\t") + "\n")
			report.close()
	print("GALLERY_CAPTION_COLLECTION_RENDER_", "VERIFIED" if _failures.is_empty() else "FAILED", " captures=", _samples.size(), " evidence=", _folder)
	quit(0 if _failures.is_empty() else 1)
