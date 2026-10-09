extends "res://addons/gut/test.gd"
## Real native predecessor -> held playable control, with TEST-only admission.
## No SaveManager/receipt/issuer/Bridge acknowledgement or rendered acceptance.
## The future durable producer must call this installer only after its own ack.
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const BASE := preload("res://tests/support/SceneDayReadingFixture.gd")
const PATH := "res://tests/fixtures/dialogic/scene_playable_native.dtl"
const OP := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const CHALLENGE := preload("res://tests/support/SceneChallengeFixture.gd")
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
var _runtime: DialogicGameHandler
var _adapter: DialogicRuntimeAdapter
var _viewport: SubViewport
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _style_directory: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _results: Array[Dictionary] = []
var _profile_before: Dictionary = {}

var _source: RefCounted
var _source_reading: Dictionary = {}
var _source_frontier: Dictionary = {}
var _source_token: RefCounted
var _candidate: RefCounted
var _reading: Dictionary = {}
var _markers: Array = []

class MutatingCandidate:
	extends "res://scripts/narrative/SoloReadingSession.gd"
	var on_capture: Callable
	func capture(frontier: Dictionary) -> Dictionary:
		var result: Dictionary = super.capture(frontier)
		if on_capture.is_valid():
			var callback := on_capture
			on_capture = Callable()
			callback.call()
		return result

func before_all() -> void:
	var parsed: Dictionary = BASE.JSON_READER.parse_object(FileAccess.get_file_as_string(BASE.REGISTRATION))
	assert_true(parsed.ok, str(parsed))
	if not parsed.ok: return
	var bundle: Dictionary = parsed.value
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		entry.locators.en.path = PATH
		if entry.entry_id == BASE.B:
			entry.allowed_signals = ["challenge.end", "challenge.playable", "history.line.witness"]
	bundle.ids_registry.signals.append({"signal_id": "challenge.end", "payload_fields": ["challenge_id"]})
	bundle.ids_registry.signals.append({"signal_id": "challenge.playable", "payload_fields": ["challenge_id"]})
	bundle.ids_registry.signals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.signal_id < b.signal_id)
	var hashes := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == BASE.B:
			programme.markers = [
				{"marker_id": "scene.test.b.playable", "label": "scene.test.b.playable",
					"after_line_id": "line.scene.test.b.one", "kind": "challenge.playable",
					"payload": {"challenge_id": "TEST.challenge"}},
				{"marker_id": "scene.test.b.end", "label": "scene.test.b.end",
					"after_line_id": "line.scene.test.b.two", "kind": "challenge.end",
					"payload": {"challenge_id": "TEST.challenge"}}]
		var compiled: Dictionary = ADAPTER.compile_scene_programme(PATH, programme.entry_id, labels, programme.markers)
		assert_true(compiled.ok, str(compiled))
		if not compiled.ok: return
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
		hashes[programme.entry_id] = programme.program_sha256
	for row: Dictionary in bundle.targets: row.target.program_sha256 = hashes[row.target.entry_id]
	bundle.board_profiles = CHALLENGE.bundle().board_profiles
	bundle.challenges = [{"challenge_id": "TEST.challenge", "entry_id": BASE.B,
		"playable_marker_id": "scene.test.b.playable", "end_marker_id": "scene.test.b.end",
		"board_profile_id": "TEST.profile", "targets": {"never_started": "target_a",
			"unfinished": "target_a", "lost": "target_a", "won": "target_a"}}]
	var selected: Dictionary = BASE.MANIFEST.configure_test_scene_registration(bundle)
	assert_true(selected.ok, str(selected))

func before_each() -> void:
	_results.clear()
	_markers.clear()
	_source_token = null
	_source = null
	_candidate = null
	_reading = {}
	_profile_before = get_node("/root/ProfileManager").get_profile_snapshot().duplicate(true)
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	_style_directory = DialogicStylesUtil.style_directory.duplicate(true)
	_original_runtime = get_node("/root/Dialogic")
	_original_runtime_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_layout_parent = _original_layout.get_parent()
		_original_layout_index = _original_layout.get_index()
		_original_layout_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	get_tree().root.add_child(_runtime)
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	add_child(_viewport)
	var layout: Node = _runtime.Styles.load_style(STYLE, _viewport)
	assert_not_null(layout)
	if not layout.is_node_ready(): await layout.ready
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok)
	_adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void: _results.append(result.duplicate(true)))

	_adapter.runtime_signal_event.connect(func(value: Variant) -> void: _markers.append(value))

func _start_source(entry: String = BASE.B, index: int = 0, hold: bool = true) -> bool:
	_source = BASE.SESSION.new()
	var checked: Dictionary = _source.configure_scene()
	if checked.ok: checked = _source.begin_scene("TEST.native.playable.session")
	if checked.ok: checked = _source.admit_scene(entry, BASE.frame(entry, "TEST.native.playable.occurrence"), index)
	assert_true(checked.ok, str(checked))
	if not checked.ok: return false
	checked = _adapter.bind_caption_ledger(_source.ledger, _source.command_id, entry, false, _source.scene_occurrence)
	assert_true(checked.ok, str(checked))
	if not checked.ok: return false
	var bundle: Dictionary = BASE.MANIFEST.scene_registration().value
	var markers: Array = []
	var labels: Array = []
	for row: Dictionary in bundle.entry_manifest.entries: labels.append(row.entry_id)
	for row: Dictionary in bundle.scene_programme.entries:
		if row.entry_id == entry: markers = row.markers
	var compiled: Dictionary = ADAPTER.compile_scene_programme(PATH, entry, labels, markers)
	assert_true(compiled.ok, str(compiled))
	if not compiled.ok: return false
	# TEST-selected entry admission at an actual compiled caption. Native text
	# callbacks, not detached ledger publication, establish its live frontier.
	checked = _adapter.start_timeline(PATH, int(compiled.value.native_indices[index]))
	assert_true(checked.ok, str(checked))
	if not checked.ok: return false
	await _settle()
	var frontier: Dictionary = _adapter.capture_reading_frontier()
	assert_true(frontier.ok, str(frontier))
	if not frontier.ok: return false
	_source_frontier = frontier.value.duplicate(true)
	var captured: Dictionary = _source.capture(_source_frontier)
	assert_true(captured.ok, str(captured))
	if not captured.ok: return false
	_source_reading = captured.value.duplicate(true)
	if not hold: return true
	checked = _adapter.hold_scene_source(_source)
	assert_true(checked.ok, str(checked))
	if not checked.ok: return false
	checked = _adapter.retain_scene_source(_source)
	assert_true(checked.ok, str(checked))
	if not checked.ok: return false
	_source_token = checked.value
	return true

func _stage(candidate: RefCounted = null) -> bool:
	var plan: Dictionary = _source.prepare_scene_next(_source_frontier, func(_beat: Dictionary) -> bool: return false)
	assert_true(plan.ok, str(plan))
	if not plan.ok: return false
	var projected: Dictionary = OP.project(plan.value, "destination")
	assert_true(projected.ok, str(projected))
	if not projected.ok: return false
	_reading = projected.value.duplicate(true)
	_candidate = BASE.SESSION.new() if candidate == null else candidate
	var checked: Dictionary = _candidate.configure_scene()
	if checked.ok: checked = _candidate.restore(_reading, _source.latest_entry)
	assert_true(checked.ok, str(checked))
	return checked.ok

func _assert_source_retained() -> void:
	assert_true(_adapter.validate_scene_source(_source_token, _source).ok)
	assert_eq(_source.capture(_source_frontier).value, _source_reading)
	assert_eq(_adapter.capture_reading_frontier().value, _source_frontier)
	assert_eq(_markers, [])
	assert_false(_adapter.capture_scene_control_position(_candidate).ok)

func test_real_caption_installs_exact_control_without_replay_and_consumes_source_once() -> void:
	if not await _start_source() or not _stage(): return
	assert_eq(_source_frontier.line_id, "line.scene.test.b.one")
	assert_eq(_reading.boundary, "control")
	var native_event: DialogicTextEvent = _adapter._caption_event
	var execution: int = native_event._execution_generation
	var native_identity: Dictionary = _adapter.marker_source_identity().value
	var publications := _results.size()
	var installed: Dictionary = _adapter.install_scene_control(_candidate, _reading, _source_token)
	assert_true(installed.ok, str(installed))
	if not installed.ok: return
	assert_eq(installed.value, _reading)
	assert_eq(_adapter.capture_scene_control_position(_candidate).value, _reading)
	assert_eq(_adapter.capture_reading_frontier().value, _source_frontier)
	assert_eq(_adapter.marker_source_identity().value, native_identity)
	assert_same(_adapter._caption_event, native_event)
	assert_eq(native_event._execution_generation, execution)
	assert_true(_adapter.is_marker_source_held())
	assert_same(_adapter._caption_ledger, _candidate.ledger)
	assert_eq(_source.capture(_source_frontier).value, _source_reading)
	assert_eq(_candidate.ledger.snapshot(), _source_reading.ledger)
	assert_eq(_results.size(), publications, "handoff publishes no caption")
	assert_eq(_markers, [], "handoff executes no native marker")
	assert_false(_adapter.validate_scene_source(_source_token, _source).ok)
	assert_false(_adapter.install_scene_control(_candidate, _reading, _source_token).ok)
	assert_eq(_adapter.capture_scene_control_position(_candidate).value, _reading)
	assert_false(_adapter.capture_scene_control_position(_source).ok)
	await _settle()
	assert_eq(_results.size(), publications)
	assert_eq(_markers, [])

func test_unheld_and_forged_tokens_cannot_install_or_consume_the_real_source() -> void:
	if not await _start_source(BASE.B, 0, false) or not _stage(): return
	assert_false(_adapter.install_scene_control(_candidate, _reading, null).ok)
	assert_false(_adapter.install_scene_control(_candidate, _reading, RefCounted.new()).ok)
	assert_true(_adapter.hold_scene_source(_source).ok)
	var retained: Dictionary = _adapter.retain_scene_source(_source)
	assert_true(retained.ok, str(retained))
	if not retained.ok: return
	_source_token = retained.value
	assert_false(_adapter.install_scene_control(_candidate, _reading, RefCounted.new()).ok)
	_assert_source_retained()

func test_malformed_projection_and_valid_but_unplanned_control_refuse_without_consuming() -> void:
	if not await _start_source() or not _stage(): return
	var cases: Array[Dictionary] = []
	for pair: Array in [["schema_version", 5.0], ["program_index", 1.0],
		["occurrence_id", "TEST.other"], ["registration_sha256", "0".repeat(64)],
		["next_operation", null], ["frontier", _source_frontier]]:
		var changed: Dictionary = _reading.duplicate(true)
		changed[pair[0]] = pair[1]
		cases.append(changed)
	var changed: Dictionary = _reading.duplicate(true)
	changed.next_operation.phase = "source"
	cases.append(changed)
	changed = _reading.duplicate(true)
	changed.extra = true
	cases.append(changed)
	for bad: Dictionary in cases:
		assert_false(_adapter.install_scene_control(_candidate, bad, _source_token).ok)
		_assert_source_retained()
	assert_true(_adapter.install_scene_control(_candidate, _reading, _source_token).ok)

func test_end_control_is_not_playable_adoption_authority() -> void:
	# B's second caption directly precedes the genuine registered End control.
	# This is TEST admission, not a claim that gameplay crossed playable to End.
	if not await _start_source(BASE.B, 2) or not _stage(): return
	assert_eq(_source_frontier.line_id, "line.scene.test.b.two")
	assert_eq(_reading.boundary, "control")
	assert_false(_adapter.install_scene_control(_candidate, _reading, _source_token).ok)
	_assert_source_retained()

func test_contact_return_control_is_not_playable_adoption_authority() -> void:
	if not await _start_source(BASE.CONTACT) or not _stage(): return
	assert_false(_adapter.install_scene_control(_candidate, _reading, _source_token).ok)
	_assert_source_retained()

func test_changed_candidate_and_stale_native_identity_refuse_before_consumption() -> void:
	if not await _start_source() or not _stage(): return
	_candidate.command_id = "TEST.foreign.session"
	assert_false(_adapter.install_scene_control(_candidate, _reading, _source_token).ok)
	_candidate.command_id = _source.command_id
	_assert_source_retained()
	var index := _runtime.current_event_idx
	_runtime.current_event_idx = index + 1
	assert_false(_adapter.install_scene_control(_candidate, _reading, _source_token).ok)
	_runtime.current_event_idx = index
	_assert_source_retained()
	assert_true(_adapter.install_scene_control(_candidate, _reading, _source_token).ok)

func test_callback_input_mutation_is_refused_without_consuming_source() -> void:
	if not await _start_source(): return
	var mutating := MutatingCandidate.new()
	if not _stage(mutating): return
	var original: Dictionary = _reading.duplicate(true)
	mutating.on_capture = func() -> void: _reading.program_index = 3
	assert_false(_adapter.install_scene_control(mutating, _reading, _source_token).ok)
	_reading = original
	_assert_source_retained()
	assert_true(_adapter.install_scene_control(mutating, _reading, _source_token).ok)

func test_callback_candidate_mutation_is_refused_before_native_adoption() -> void:
	if not await _start_source(): return
	var mutating := MutatingCandidate.new()
	if not _stage(mutating): return
	mutating.on_capture = func() -> void: mutating.scene_index = 3
	assert_false(_adapter.install_scene_control(mutating, _reading, _source_token).ok)
	mutating.scene_index = _reading.program_index
	_assert_source_retained()
	assert_true(_adapter.install_scene_control(mutating, _reading, _source_token).ok)

func after_each() -> void:
	assert_eq(get_node("/root/ProfileManager").get_profile_snapshot(), _profile_before,
		"internal publication capture cannot write the real Profile")
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(_runtime):
		_runtime.paused = false
		await _runtime.clear()
		var remaining: Node = _runtime.Styles.get_layout_node()
		if is_instance_valid(remaining) and not _viewport.is_ancestor_of(remaining): remaining.queue_free()
	_viewport.queue_free()
	await get_tree().process_frame
	if is_instance_valid(_runtime): _runtime.free()
	_adapter = null
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout) and is_instance_valid(_original_layout_parent):
		_original_layout_parent.add_child(_original_layout)
		_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null

func _settle() -> void:
	for frame: int in 6: await get_tree().process_frame
