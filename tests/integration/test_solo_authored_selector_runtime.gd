extends "res://addons/gut/test.gd"
## Real Bridge -> mounted Dialogic -> caption ledger, with explicitly noncanon
## selector prose. The isolated Profile uses FakeFileOps; no real save is written.

const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const CATALOG := preload("res://tests/support/SoloAuthoredSelectorTimelineCatalog.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const IDS := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const FIXTURE := "res://tests/fixtures/dialogic/solo_authored_selector.dtl"
const DOCUMENT := "res://tests/fixtures/dialogic/solo_authored_selector_catalogue.json"
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const LAYER := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
const PRE := "dating.solo.priscilla.day1.pre_challenge"
const POST := "dating.solo.priscilla.day1.post_challenge"
const TOKEN := "fixture:selector-native"

class Checkpoints extends RefCounted:
	var calls: Array[Dictionary] = []
	var completions: Array[Dictionary] = []
	func commit_current_boundary(_checkpoint: Dictionary) -> Dictionary: return {"ok": true}
	func preview_checkpoint_id(_checkpoint: Dictionary) -> Dictionary: return {"ok": true}
	func capture() -> Dictionary: return {"ok": true}
	func prepare_candidate(_checkpoint: Dictionary) -> Dictionary: return {"ok": true}
	func commit(_candidate: Dictionary) -> Dictionary: return {"ok": true}
	func rollback(_backup: Dictionary) -> Dictionary: return {"ok": true}
	func complete_entry(intent: Dictionary) -> Dictionary:
		completions.append(intent.duplicate(true))
		return {"ok": true}
	func commit_reading_next(checkpoint: Dictionary, operation_id: String, phase: String) -> Dictionary:
		calls.append({"checkpoint": checkpoint.duplicate(true), "operation_id": operation_id, "phase": phase})
		return {"ok": true, "receipt": {"operation_id": operation_id, "phase": phase}}

class SpeechRecorder extends Node:
	signal speech_completed(token: int, outcome: StringName)
	var requests: Array[Dictionary] = []
	var active_source := ""
	func request_speech(copy: String, locale: String, rate: StringName, source: String) -> Dictionary:
		requests.append({"text": copy, "locale": locale, "rate": rate, "source": source})
		active_source = source
		return {"ok": true, "value": {"token": requests.size()}}
	func stop_source(source: String, _reason: StringName) -> Dictionary:
		if source == active_source: active_source = ""
		return {"ok": true}
	func is_speaking(source: String = "") -> bool:
		return not active_source.is_empty() and (source.is_empty() or source == active_source)

var _runtime: DialogicGameHandler
var _adapter: DialogicRuntimeAdapter
var _bridge: Node
var _profile: Node
var _gate: ApplicationMutationGate
var _port: Checkpoints
var _speech: SpeechRecorder
var _viewport: SubViewport
var _document: Dictionary
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _style_directory: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _profile_before: Dictionary = {}
var _publications: Array[Dictionary] = []
var _native_text: Array[String] = []
var _restored: Array[Dictionary] = []
var _fixture_layouts: Array[Node] = []
var _fixture_text_nodes: Array[Node] = []
var _baseline_text_nodes: Array[Node] = []
var _baseline_text_ids: Array[int] = []

func before_each() -> void:
	_fixture_layouts.clear()
	_fixture_text_nodes.clear()
	_baseline_text_nodes.assign(get_tree().get_nodes_in_group("dialogic_dialog_text"))
	_baseline_text_ids = _node_identities(_baseline_text_nodes)
	_publications.clear()
	_native_text.clear()
	_restored.clear()
	_settings.clear()
	_profile_before = get_node("/root/ProfileManager").get_profile_snapshot().duplicate(true)
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(DOCUMENT))
	assert_true(parsed.ok, str(parsed))
	_document = parsed.value
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
	_runtime.Text.text_started.connect(func(info: Dictionary) -> void: _native_text.append(str(info.text)))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	add_child(_viewport)
	_gate = GATE.new()
	_profile = MANAGER.new()
	add_child(_profile)
	assert_true(_profile.configure_mutation_gate(_gate).ok)
	var ids := IDS.load_ids_default()
	assert_true(ids.ok, str(ids))
	assert_true(_profile.configure_line_registry(ids.value).ok)
	var wrapper := OS.get_environment("DWM_TEST_ROOT").strip_edges()
	assert_false(wrapper.is_empty(), "cloud wrapper supplies the isolated test root")
	assert_true(_profile.initialize(STORAGE.new(wrapper.path_join("selector-native"), FILES.new())).ok)
	assert_true(_profile.set_preference(&"preferences.reading.read_aloud_enabled", true).ok)
	_speech = SpeechRecorder.new()
	add_child(_speech)
	_port = Checkpoints.new()
	_new_bridge()

func _new_bridge() -> void:
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok)
	_adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void:
		_publications.append(result.duplicate(true)))
	_adapter.reading_frontier_restored.connect(func(result: Dictionary) -> void:
		_restored.append(result.duplicate(true)))
	_bridge = BRIDGE.new()
	add_child(_bridge)
	assert_true(_bridge.initialize(CATALOG, _adapter).ok)
	assert_true(_bridge.configure_mutation_gate(_gate).ok)
	assert_true(_bridge.configure_skip_context(_profile, &"read_only").ok)
	assert_true(_bridge.configure_narrative_checkpoint_port(_port).ok)
	assert_true(_bridge.configure_playback_completion_port(_port).ok)
	assert_true(_bridge.configure_reading_catalogue(_document).ok)

func after_each() -> void:
	if is_instance_valid(_adapter) and _adapter.can_capture_reading_frontier():
		assert_true(_adapter.complete_reading_frontier().ok)
	assert_eq(get_node("/root/ProfileManager").get_profile_snapshot(), _profile_before,
		"native selector tests never mutate the real Profile")
	if is_instance_valid(_bridge): _bridge.free()
	# Only nodes mounted by this fixture are stopped. The detached production
	# layout and any pre-existing owner remain outside this cleanup boundary.
	for text_node: Node in _fixture_text_nodes:
		if is_instance_valid(text_node): text_node.set_process(false)
	if is_instance_valid(_runtime):
		_runtime.paused = false
		await _runtime.clear()
		# abort_current_entry can already own clear()'s one-frame timeline drain.
		# Let that exact native end continuation retire before restoring production.
		await get_tree().process_frame
	# Natural endings detach layouts before queueing them, so the viewport and
	# global Styles metadata cannot prove ownership at teardown.
	for layout: Node in _fixture_layouts:
		if is_instance_valid(layout): layout.free()
	for text_node: Node in _fixture_text_nodes:
		var survived := is_instance_valid(text_node)
		assert_false(survived, "fixture caption survived its exact layout: " + _node_diagnostic(text_node))
		if survived: text_node.free()
	_fixture_layouts.clear()
	_fixture_text_nodes.clear()
	if is_instance_valid(_viewport): _viewport.free()
	if is_instance_valid(_runtime): _runtime.free()
	_adapter = null
	_profile.free()
	_speech.free()
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout) and is_instance_valid(_original_layout_parent):
		_original_layout_parent.add_child(_original_layout)
		_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	var restored_text_nodes: Array[Node] = []
	restored_text_nodes.assign(get_tree().get_nodes_in_group("dialogic_dialog_text"))
	assert_eq(_node_identities(restored_text_nodes), _baseline_text_ids,
		"caption group must return to its exact pre-fixture owners; actual=" + _nodes_diagnostic(restored_text_nodes)
		+ " baseline=" + _nodes_diagnostic(_baseline_text_nodes))
	_baseline_text_nodes.clear()
	_baseline_text_ids.clear()
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null

func _node_diagnostic(node: Variant) -> String:
	if not is_instance_valid(node): return "<freed>"
	var parent: Node = node.get_parent()
	return JSON.stringify({"id": node.get_instance_id(), "name": str(node.name),
		"path": str(node.get_path()) if node.is_inside_tree() else "<detached>",
		"parent": str(parent.get_path()) if is_instance_valid(parent) and parent.is_inside_tree() else "<detached>",
		"text": str(node.get_parsed_text()).left(120) if node.has_method("get_parsed_text") else ""})

func _nodes_diagnostic(nodes: Array[Node]) -> String:
	var rows: Array[String] = []
	for node: Node in nodes: rows.append(_node_diagnostic(node))
	return "[" + ", ".join(rows) + "]"

func _node_identities(nodes: Array[Node]) -> Array[int]:
	var ids: Array[int] = []
	for node: Node in nodes:
		if is_instance_valid(node): ids.append(node.get_instance_id())
	ids.sort()
	return ids

func _settle() -> void:
	for frame: int in 6: await get_tree().process_frame

func _caption() -> Node:
	var layout: Node = _runtime.Styles.get_layout_node()
	if layout != null:
		for layer: Node in layout.get_layers():
			if layer.get_script() == LAYER: return layer
	return null

func _mount() -> bool:
	var layout: Node = _runtime.Styles.get_layout_node()
	if layout == null: layout = _runtime.Styles.load_style(STYLE, _viewport)
	assert_not_null(layout)
	if layout == null: return false
	if not _fixture_layouts.has(layout): _fixture_layouts.append(layout)
	await _settle()
	assert_same(layout.get_parent(), _viewport)
	var caption := _caption()
	assert_not_null(caption)
	if caption == null: return false
	var text_node: Node = caption.caption_text
	assert_true(layout.is_ancestor_of(text_node), "recorded fixture caption belongs to its mounted layout")
	if not _fixture_text_nodes.has(text_node): _fixture_text_nodes.append(text_node)
	assert_true(caption.configure_reading_transport(_profile, _bridge))
	assert_true(caption.configure_speech(_profile, _bridge, _speech))
	return true

func _context(entry_id: String, tone: String = "dark", result: String = "cleared") -> Dictionary:
	var phase := "pre_challenge" if entry_id == PRE else "post_challenge"
	var fields := {"entry_id": entry_id, "entry_role": "solo_" + phase, "day": 1,
		"friend_id": "priscilla", "tier": "friend", "tone": tone, "attitude": "",
		"run_id": "fixture:selector-run", "branch_id": "fixture:selector-branch",
		"challenge_slot": "dating.solo.priscilla.day1", "phase": phase,
		"due_echoes": [], "attempt_residue_id": null}
	if entry_id == POST:
		fields.merge({"attempt_id": "fixture:selector-attempt", "board_result": result,
			"perfect_reasons": ["no_flag"] if result == "perfect" else [],
			"relationship_outcome": "foresight" if result == "perfect" else "loved",
			"effect_receipt_id": "fixture:selector-effect"})
	var frozen := FROZEN.build(entry_id, fields)
	assert_true(frozen.ok, str(frozen))
	return {"expected_stage": phase, "playback_id": "fixture:selector-physical:" + phase,
		"role": "dating_phase", "transaction_id": TOKEN + ":" + phase, "presentation": frozen.value}

func _begin() -> bool:
	var begun: Dictionary = _bridge.begin_reading_session({"timeline_id": PRE,
		"completion_transaction_id": TOKEN, "context": {"kind": "solo"}})
	assert_true(begun.ok, str(begun))
	return begun.ok

func _start(entry_id: String, tone: String = "dark", result: String = "cleared") -> bool:
	if not await _mount(): return false
	var started: Dictionary = _bridge.start_entry(entry_id, _context(entry_id, tone, result))
	assert_true(started.ok, str(started))
	if not started.ok: return false
	var label := "fixture.selector.pre." + tone if entry_id == PRE else "fixture.selector.post." + tone + "." + result
	assert_eq(started.receipt.label, label, "Bridge replaces semantic locator with the selected native label")
	await _settle()
	return true

func _advance() -> bool:
	var completed := _adapter.complete_reading_frontier()
	assert_true(completed.ok, str(completed))
	if not completed.ok: return false
	var advanced := _adapter.advance_one_event()
	assert_true(advanced.ok, str(advanced))
	await _settle()
	return advanced.ok

func _assert_caption(entry_id: String, ordinal: int) -> void:
	var programme: Dictionary = _bridge._reading_session.entry_program(entry_id)
	assert_true(programme.ok, str(programme))
	if not programme.ok: return
	var caption := _caption()
	assert_not_null(caption)
	if caption == null: return
	assert_eq(caption.caption_text.get_parsed_text(), programme.value.lines[ordinal].text)
	var frontier := _adapter.capture_reading_frontier()
	assert_true(frontier.ok, str(frontier))
	if not frontier.ok: return
	assert_eq(frontier.value.line_id, programme.value.lines[ordinal].line_id)
	var ledger: Dictionary = _bridge._reading_session.ledger.snapshot()
	assert_eq(ledger.captions.back().beat, programme.value.beats[ordinal],
		"native publication uses the selected per-caption descriptor, despite shared line IDs")
	var history: Dictionary = _bridge.get_reading_history()
	assert_true(history.ok, str(history))
	if history.ok: assert_eq(history.value.captions.back().text, programme.value.lines[ordinal].text)

func test_real_bridge_plays_only_selected_pre_and_post_programmes_for_every_fixture_context() -> void:
	for tone: String in ["sweet", "dark"]:
		for result: String in ["cleared", "perfect"]:
			_native_text.clear()
			_publications.clear()
			if not _begin(): return
			if not await _start(PRE, tone): return
			var pre: Dictionary = _bridge._reading_session.entry_program(PRE).value
			_assert_caption(PRE, 0)
			if not await _advance(): return
			_assert_caption(PRE, 1)
			if not await _advance(): return
			assert_false(_adapter.has_active_playback())
			assert_eq(_bridge._reading_session.boundary, "between_entries")
			if not await _start(POST, tone, result): return
			var post: Dictionary = _bridge._reading_session.entry_program(POST).value
			_assert_caption(POST, 0)
			if not await _advance(): return
			_assert_caption(POST, 1)
			if not await _advance(): return
			assert_false(_adapter.has_active_playback())
			assert_eq(_native_text, [pre.lines[0].text, pre.lines[1].text, post.lines[0].text, post.lines[1].text],
				"unselected labels never reach native text publication")
			assert_eq(_publications.size(), 4)
			for published: Dictionary in _publications: assert_true(published.ok, str(published))
			var history: Dictionary = _bridge.get_reading_history()
			assert_true(history.ok, str(history))
			if history.ok: assert_eq(history.value.captions.size(), 4)
	assert_eq(_port.completions.size(), 8, "each actual pre/post return completes once")

func test_whole_selected_label_refuses_other_tone_even_when_first_post_caption_matches() -> void:
	var session := SESSION.new()
	assert_true(session.configure(_document).ok)
	var selected: Dictionary = session.entry_program(POST, _context(POST, "dark", "perfect"))
	var other: Dictionary = session.entry_program(POST, _context(POST, "sweet", "perfect"))
	assert_true(selected.ok, str(selected))
	assert_true(other.ok, str(other))
	if not selected.ok or not other.ok: return
	assert_eq(selected.value.lines[0].text, other.value.lines[0].text)
	assert_ne(selected.value.lines[1].text, other.value.lines[1].text)
	assert_true(_adapter.validate_reading_line(FIXTURE, other.value.label,
		selected.value.lines[0].line_id, selected.value.lines[0].text).ok,
		"a first-line-only lookup would incorrectly accept the other tone")
	var refused := _adapter.validate_reading_entry(FIXTURE, other.value.label, selected.value.lines)
	assert_false(refused.ok)
	assert_eq(refused.code, &"reading_line_content_mismatch")
	assert_true(_adapter.validate_reading_entry(FIXTURE, selected.value.label, selected.value.lines).ok)
	assert_eq(_native_text, [], "compatibility validation performs no native playback")
	assert_eq(_publications, [])
	assert_false(_adapter.has_active_playback())

func test_bridge_next_keeps_selected_label_and_fresh_resume_preserves_history_without_speech_replay() -> void:
	if not _begin(): return
	if not await _start(PRE): return
	assert_gt(_speech.requests.size(), 0, "the mounted speech recorder is enabled before proving restore suppression")
	if not await _advance(): return
	if not await _advance(): return
	if not await _start(POST, "dark", "perfect"): return
	_assert_caption(POST, 0)
	assert_true(_adapter.complete_reading_frontier().ok)
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(proof.ok, str(proof))
	if not proof.ok: return
	var moved: Dictionary = await _bridge.request_next(proof)
	assert_true(moved.ok, str(moved))
	if not moved.ok: return
	await _settle()
	assert_eq(moved.value.destination, "line")
	_assert_caption(POST, 1)
	assert_eq(_port.calls.size(), 2)
	if _port.calls.size() != 2: return
	assert_eq(_port.calls[0].phase, "source")
	assert_eq(_port.calls[1].phase, "destination")
	assert_eq(_port.calls[1].checkpoint.reading_session.frontier.line_id, "fixture.selector.post.b")
	assert_eq(_native_text.back(), "NONCANONICAL dark closing.")
	assert_eq(_native_text.size(), 4, "Next cannot publish any other tone or board result")
	# This test activates the coordinator directly. A real rail completion asks
	# its presenter to acknowledge this visible destination after custody settles.
	var destination_proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(_bridge.acknowledge_current_line_presentation(destination_proof).ok)
	var spoken: Dictionary = _bridge.capture_current_speech_presentation()
	assert_true(spoken.ok, str(spoken))
	if spoken.ok: assert_false(spoken.value.suppress_replay, "new Next destination remains a fresh speech publication")
	var saved: Dictionary = _bridge.capture_reading_checkpoint(false)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	_assert_independent_restore_frames(saved.value)
	# Retire a completed reveal without advancing its semantic occurrence. This
	# suite does not extend the separate native partial-reveal abort contract.
	assert_true(_adapter.complete_reading_frontier().ok)
	await _settle()
	var history: Dictionary = _bridge.get_reading_history()
	var profile_before: Dictionary = _profile.get_profile_snapshot()
	var old_adapter_id := _adapter.get_instance_id()
	var old_bridge_id := _bridge.get_instance_id()
	_bridge.free()
	_adapter.halt_with_error({"code": &"fixture_process_retired"})
	await _settle()
	_adapter = null
	_new_bridge()
	assert_ne(_adapter.get_instance_id(), old_adapter_id)
	assert_ne(_bridge.get_instance_id(), old_bridge_id)
	_native_text.clear()
	_publications.clear()
	_speech.requests.clear()
	if not await _mount(): return
	var resumed: Dictionary = _bridge.resume_entry(saved.value)
	assert_true(resumed.ok, str(resumed))
	if not resumed.ok: return
	assert_eq(resumed.receipt.label, "fixture.selector.post.dark.perfect")
	await _settle()
	assert_eq(_restored.size(), 1, str(_restored))
	_assert_caption(POST, 1)
	assert_eq(_bridge.get_reading_history(), history, "fresh reconstruction retains all earlier selected captions")
	assert_eq(_bridge.capture_reading_checkpoint(false), saved,
		"resume reuses the exact semantic occurrence and committed Next operation")
	assert_eq(_profile.get_profile_snapshot(), profile_before)
	assert_true(_adapter.is_current_line_complete(), "restored caption finishes without rerunning crossed prose")
	assert_eq(_native_text, ["NONCANONICAL dark closing."])
	assert_eq(_publications.size(), 1)
	if _publications.size() == 1:
		assert_true(_publications[0].ok, str(_publications[0]))
		if _publications[0].ok: assert_true(_publications[0].value.get("duplicate", false))
	var restored_speech: Dictionary = _bridge.capture_current_speech_presentation()
	assert_true(restored_speech.ok, str(restored_speech))
	if restored_speech.ok: assert_true(restored_speech.value.suppress_replay)
	assert_eq(_speech.requests, [], "visible restored caption never speaks again")
	if not await _advance(): return
	assert_false(_adapter.has_active_playback(), "freshly resumed selected label still reaches its natural return")

func _assert_independent_restore_frames(checkpoint: Dictionary) -> void:
	var authority: Dictionary = checkpoint.reading_session.ledger.entry_contexts.duplicate(true)
	assert_true(_bridge.validate_reading_checkpoint(checkpoint, authority).ok)
	# An attacker can rewrite every internally related saved value coherently.
	# Only the independently admitted Run frames distinguish that alternate story.
	var changed := checkpoint.duplicate(true)
	changed.reading_session.schema_version = 1
	changed.reading_session.erase("next_operation")
	var resolver := SESSION.new()
	assert_true(resolver.configure(_document).ok)
	var descriptors := {}
	for entry_id: String in [PRE, POST]:
		var replacement := _context(entry_id, "sweet", "perfect")
		changed.reading_session.ledger.entry_contexts[entry_id] = replacement
		if entry_id == changed.entry_id: changed.frozen_context = replacement.duplicate(true)
		var programme: Dictionary = resolver.entry_program(entry_id, replacement)
		assert_true(programme.ok, str(programme))
		if not programme.ok: return
		for beat: Dictionary in programme.value.beats: descriptors[beat.line_id] = beat
	for row: Dictionary in changed.reading_session.ledger.captions:
		row.beat = descriptors[row.beat.line_id].duplicate(true)
	assert_true(_bridge.validate_reading_checkpoint(changed).ok,
		"coherently rewritten captions and frames are an internally valid alternate programme")
	var refused: Dictionary = _bridge.validate_reading_checkpoint(changed, authority)
	assert_false(refused.ok)
	assert_eq(refused.code, &"reading_context_invalid",
		"saved selector self-consistency cannot override independently admitted Run frames")
