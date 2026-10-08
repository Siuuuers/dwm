extends "res://addons/gut/test.gd"
## Mounted installed Dialogic proof with an explicitly simulated confirmation
## port. This suite does not write/activate Save8 or authenticate G receipts.
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const BASE := preload("res://tests/support/SceneDayReadingFixture.gd")
const HELD := preload("res://tests/support/SceneHeldSourceFixture.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
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
var _bridge: Node
var _port: RefCounted
var _session: RefCounted
var _binding: Dictionary = {}
var _source_snapshot: Dictionary = {}

func before_all() -> void:
	assert_true(BASE.configure().ok)

func before_each() -> void:
	_results.clear()
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
	assert_not_null(_runtime.Styles.load_style(STYLE, _viewport))
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok)
	_adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void: _results.append(result.duplicate(true)))

	_bridge = BRIDGE.new()
	autofree(_bridge)
	_bridge._runtime_adapter = _adapter
	_port = HELD.SimulatedCheckpointPort.new()
	_binding = HELD.binding("target_a", "a:next")
	assert_true(_bridge.configure_scene_staging(_port,
		func(provided: Dictionary) -> Dictionary:
			return {"ok": provided == _binding},
		func(_entry: String, _context: Dictionary) -> Dictionary:
			return {"ok": true, "value": _binding.duplicate(true)}).ok)
	_adapter.reading_frontier_restored.connect(_bridge._on_reading_frontier_restored)

func _start_source(target_id: String = "target_a", hold: bool = true) -> bool:
	_binding = HELD.binding(target_id, "a:parent" if target_id == "return_a" else "a:next")
	var created := BASE.create_session()
	assert_true(created.ok, str(created))
	if not created.ok: return false
	_session = created.value
	# A retained parent visit is admitted by this TEST owner; native playback
	# below supplies both B captions from actual installed text event objects.
	assert_true(BASE.enter(_session, BASE.A, "a:parent").ok)
	var frame := BASE.frame(BASE.B, "b:held")
	assert_true(_session.admit_scene(BASE.B, frame).ok)
	assert_true(_adapter.bind_caption_ledger(_session.ledger, _session.command_id,
		BASE.B, false, "b:held").ok)
	assert_true(_adapter.start_timeline(HELD.PATH, BASE.B).ok)
	await _settle()
	assert_true(_adapter.reveal_current_line(true).ok)
	await _settle()
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	var frontier := _adapter.capture_reading_frontier()
	assert_true(frontier.ok, str(frontier))
	if not frontier.ok: return false
	assert_eq(frontier.value.line_id, "line.scene.test.b.two")
	# Match the authenticated compiled semantic node after native publication.
	# This fixture setup is not a claim that production progression is wired.
	_session.scene_index = 1
	_bridge._reading_session = _session
	_bridge._active_entry = {"entry_id": BASE.B, "token": "held:test:live", "stage": "scene",
		"execution_mode": &"canonical", "transaction_id": frame.transaction_id,
		"context_fingerprint": "held:test:frame", "content_version": 1,
		"path": HELD.PATH, "label": BASE.B, "frozen_context": frame}
	var captured: Dictionary = _bridge.capture_reading_checkpoint(false)
	assert_true(captured.ok, str(captured))
	if not captured.ok: return false
	_source_snapshot = captured.value.duplicate(true)
	if not hold: return true
	var held: Dictionary = _bridge.hold_scene_entry_source()
	assert_true(held.ok, str(held))
	if not held.ok: return false
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	return true

func _prepare() -> Dictionary:
	return _bridge.prepare_day_entry(BASE.A, BASE.frame(BASE.A, _binding.target_occurrence_id))

func _assert_source_unchanged() -> void:
	assert_same(_bridge._reading_session, _session)
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	var captured: Dictionary = _bridge.capture_reading_checkpoint(false)
	assert_true(captured.ok, str(captured))
	if captured.ok: assert_eq(captured.value, _source_snapshot)
	assert_eq(_adapter.current_line_id(), "line.scene.test.b.two")

func _assert_target(prepared: Dictionary, expected_line: String) -> void:
	var checkpoint: Dictionary = prepared.value.narrative_checkpoint
	assert_same(_bridge._reading_session.ledger, _adapter._caption_ledger)
	assert_eq(_bridge._reading_session.ledger.snapshot(), checkpoint.reading_session.ledger)
	var native := _adapter.capture_reading_frontier()
	assert_true(native.ok, str(native))
	if not native.ok: return
	assert_eq(native.value, checkpoint.reading_session.frontier)
	assert_eq(native.value.line_id, expected_line)
	var history: Dictionary = _bridge.get_reading_history()
	assert_true(history.ok, str(history))
	if history.ok:
		var lines: Array = []
		for row: Dictionary in history.value.captions: lines.append(row.line_id)
		assert_eq(lines, ["line.scene.test.a.one", "line.scene.test.b.one",
			"line.scene.test.b.two", expected_line])
	var retained: Dictionary = _bridge._reading_session.ledger.snapshot()
	_runtime.Text.about_to_show_text.emit({})
	_runtime.Text.text_started.emit({})
	assert_eq(_bridge._reading_session.ledger.snapshot(), retained, "duplicate native callbacks reuse saved target publication")
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)

func test_prepare_refuses_unheld_source_without_revealing_or_retiring_it() -> void:
	if not await _start_source("target_a", false): return
	var source_event: DialogicTextEvent = _adapter._caption_event
	var execution_generation: int = source_event._execution_generation
	var was_complete := _adapter.is_current_line_complete()
	assert_false(_prepare().ok)
	assert_eq(_port.retains, 0)
	assert_eq(source_event._execution_generation, execution_generation)
	assert_eq(_adapter.is_current_line_complete(), was_complete)
	_assert_source_unchanged()
	assert_true(_bridge.hold_scene_entry_source().ok)
	assert_true(_prepare().ok)
	_assert_source_unchanged()

func test_real_held_source_replacement_waits_for_confirmation_and_installs_saved_publication_once() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_assert_source_unchanged()
	assert_false(_adapter.install_scene_target(_bridge._scene_stage.candidate,
		prepared.value.narrative_checkpoint, HELD.target("target_a")).ok,
		"active native replacement requires the privately retained source capability")
	_assert_source_unchanged()
	assert_false(_bridge.commit_day_entry(prepared.value).ok, "simulated proven no-write")
	_assert_source_unchanged()
	assert_eq(_port.retains, 1)
	_port.confirmed = true
	var committed: Dictionary = _bridge.commit_day_entry(prepared.value)
	assert_true(committed.ok, str(committed))
	await _settle()
	if not committed.ok: return
	_assert_target(prepared, "line.scene.test.a.one")
	assert_eq(_port.retains, 1, "retry retains original detached target")
	var consumes: int = _port.consumes
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_eq(_port.consumes, consumes, "duplicate commit cannot consume acknowledgement again")

func test_real_internal_return_uses_parent_occurrence_and_exact_post_call_label() -> void:
	if not await _start_source("return_a"): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_assert_source_unchanged()
	assert_eq(prepared.value.narrative_checkpoint.reading_session.occurrence_id, "a:parent")
	assert_eq(prepared.value.narrative_checkpoint.reading_session.program_index, 1)
	_port.confirmed = true
	var committed: Dictionary = _bridge.commit_day_entry(prepared.value)
	assert_true(committed.ok, str(committed))
	await _settle()
	if committed.ok: _assert_target(prepared, "line.scene.test.a.two")

func test_altered_and_reentrant_capabilities_cannot_replace_the_held_source() -> void:
	if not await _start_source(): return
	var reentries: Array = []
	_port.on_retain = func() -> void: reentries.append(_prepare())
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_eq(reentries.size(), 1)
	assert_eq(reentries[0].code, &"scene_staging_busy")
	var altered: Dictionary = prepared.value.duplicate(true)
	altered.narrative_checkpoint.content_version = 2
	assert_false(_bridge.commit_day_entry(altered).ok)
	assert_eq(_port.consumes, 0)
	_assert_source_unchanged()
	_port.confirmed = true
	_port.on_consume = func() -> void:
		reentries.append(_bridge.commit_day_entry(prepared.value))
		reentries.append(_prepare())
	var committed: Dictionary = _bridge.commit_day_entry(prepared.value)
	assert_true(committed.ok, str(committed))
	await _settle()
	assert_eq(reentries.size(), 3)
	for result: Dictionary in reentries: assert_eq(result.code, &"scene_staging_busy")
	assert_eq(_port.consumes, 1)
	if committed.ok: _assert_target(prepared, "line.scene.test.a.one")

func test_real_foreign_playback_invalidates_source_before_ack_consumption() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_runtime.start_timeline(HELD.PATH, BASE.A, "held:test:foreign")
	await _settle()
	_port.confirmed = true
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_eq(_port.consumes, 0)
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)

func test_caller_transport_mutation_during_ack_cannot_redirect_private_target() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var original: Dictionary = prepared.duplicate(true)
	_port.confirmed = true
	_port.on_consume = func() -> void:
		prepared.value.narrative_checkpoint.content_version = 777
		prepared.value.narrative_checkpoint.transaction_id = "caller:changed:during:ack"
	var committed: Dictionary = _bridge.commit_day_entry(prepared.value)
	assert_true(committed.ok, str(committed))
	if not committed.ok: return
	assert_eq(committed.value, original.value.narrative_checkpoint,
		"the result must name the original privately retained checkpoint")
	assert_ne(prepared.value.narrative_checkpoint, original.value.narrative_checkpoint)
	await _settle()
	_assert_target(original, "line.scene.test.a.one")
	assert_eq(_port.checkpoint, original.value.narrative_checkpoint)
	assert_eq(_port.consumes, 1)

func test_foreign_native_playback_during_confirmed_ack_retains_target_under_fatal_custody() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_port.confirmed = true
	_port.on_consume = func() -> void:
		_runtime.start_timeline(HELD.PATH, BASE.A, "held:test:foreign:during:ack")
	var committed: Dictionary = _bridge.commit_day_entry(prepared.value)
	assert_false(committed.ok)
	assert_true(_port.consumed)
	assert_true(_bridge._scene_stage_fatal)
	assert_eq(_bridge._scene_stage.transport, prepared.value)
	assert_true(_bridge._scene_stage.has("committed_checkpoint"))
	assert_eq(_bridge._scene_stage.candidate.ledger.snapshot(),
		prepared.value.narrative_checkpoint.reading_session.ledger)
	assert_same(_bridge._reading_session, _session,
		"foreign playback is not adoption of the confirmed target")
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	await _settle()
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	var consumes: int = _port.consumes
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_eq(_port.consumes, consumes)

func test_uncertain_confirmation_keeps_fatal_custody_and_exposes_no_target() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_port.uncertain = true
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_true(_bridge._scene_stage_fatal)
	assert_same(_bridge._reading_session, _session)
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	assert_eq(_adapter.current_line_id(), "line.scene.test.b.two")
	_port.uncertain = false
	_port.confirmed = true
	var consumes: int = _port.consumes
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_eq(_port.consumes, consumes)

func test_altered_acknowledgement_is_fatal_without_target_publication() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_port.confirmed = true
	_port.corrupt = true
	var publications := _results.size()
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_true(_port.consumed)
	assert_true(_bridge._scene_stage_fatal)
	assert_eq(_results.size(), publications)
	assert_eq(_adapter.current_line_id(), "line.scene.test.b.two")
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	_port.corrupt = false
	var consumes: int = _port.consumes
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_eq(_port.consumes, consumes)

func test_confirmed_native_failure_retains_committed_target_without_second_adoption() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_port.confirmed = true
	# Inject failure after confirmation in the actual adapter's qualified
	# installation guard, without replacing it with a fake native adapter.
	_port.on_consume = func() -> void: _adapter._bound = false
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_true(_port.consumed)
	assert_true(_bridge._scene_stage_fatal)
	assert_eq(_bridge._scene_stage.transport, prepared.value)
	assert_true(_bridge._scene_stage.has("committed_checkpoint"))
	assert_eq(_bridge._scene_stage.candidate.ledger.snapshot(),
		prepared.value.narrative_checkpoint.reading_session.ledger)
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	_adapter._bound = true
	var consumes: int = _port.consumes
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_eq(_port.consumes, consumes)

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

