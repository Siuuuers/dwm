extends "res://addons/gut/test.gd"
## Real Bridge + real acknowledgement producer + installed native runtime.
## Only the lower prepared-save port is injected; no Save8 acceptance is claimed.
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const BASE := preload("res://tests/support/SceneDayReadingFixture.gd")
const HELD := preload("res://tests/support/SceneHeldSourceFixture.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const PRODUCER := preload("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd")
const LOWER := preload("res://tests/support/SceneOwnerCompositionFixture.gd")
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
var _lower: RefCounted
var _authority_callback: Callable
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
	_lower = LOWER.new()
	_lower.route_id_value = "dating"
	_port = PRODUCER.new()
	assert_true(_port.configure(_lower, _lower.provider_callables()).ok)
	_binding = HELD.binding("target_a", "a:next")
	assert_true(_bridge.configure_scene_staging(_port,
		func(provided: Dictionary) -> Dictionary:
			if _authority_callback.is_valid(): _authority_callback.call()
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
	_lower.current = {"checkpoint_id": "composition:source", "checkpoint_sequence": 1,
		"narrative_checkpoint": _source_snapshot.duplicate(true)}
	_binding.source_checkpoint = {"checkpoint_id": _lower.current.checkpoint_id,
		"checkpoint_sequence": _lower.current.checkpoint_sequence, "snapshot_sha256": LOWER.digest(_lower.current)}
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


func _save(prepared: Dictionary, payload: Dictionary = {"test_owner": true}) -> Dictionary:
	return _port.commit_scene_event(payload, prepared.value.narrative_checkpoint)

func _assert_real_ack(prepared: Dictionary, saved: Dictionary) -> void:
	var ack: Dictionary = _port._scene_entry.ack
	assert_eq(ack.capability_id, prepared.value.capability_id)
	assert_eq(ack.operation_id, _binding.operation_id)
	assert_eq(ack.source_checkpoint, _binding.source_checkpoint)
	assert_eq(ack.binding_sha256, LOWER.digest(_binding))
	assert_eq(ack.narrative_checkpoint_sha256, LOWER.digest(_lower.current.narrative_checkpoint))
	assert_eq(ack.narrative_checkpoint_sha256, LOWER.digest(prepared.value.narrative_checkpoint))
	assert_eq(ack.target_checkpoint.snapshot_sha256, LOWER.digest(_lower.current))
	assert_eq(ack.target_checkpoint, saved.value.checkpoint_reference)
	assert_true(_lower.committed_same_object, "producer commits lower port's exact prepared object")

func test_real_owner_chain_confirms_committed_snapshot_then_adopts_saved_publication_once() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_same(_port._scene_authority, _bridge, "actual Bridge supplies capability validation")
	_assert_source_unchanged()
	var saved := _save(prepared)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	_assert_real_ack(prepared, saved)
	_assert_source_unchanged()
	var committed: Dictionary = _bridge.commit_day_entry(prepared.value)
	assert_true(committed.ok, str(committed))
	await _settle()
	if not committed.ok: return
	_assert_target(prepared, "line.scene.test.a.one")
	assert_eq(_lower.current.narrative_checkpoint, prepared.value.narrative_checkpoint)
	assert_eq(_lower.commit_count, 1)
	assert_true(_port._scene_used.has(prepared.value.capability_id))
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_false(_port.consume_scene_entry_ack(prepared.value.capability_id).ok)
	assert_eq(_lower.commit_count, 1)

func test_real_owner_chain_internal_return_retains_parent_frame_and_history() -> void:
	if not await _start_source("return_a"): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var saved := _save(prepared)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	_assert_real_ack(prepared, saved)
	assert_true(_bridge.commit_day_entry(prepared.value).ok)
	await _settle()
	_assert_target(prepared, "line.scene.test.a.two")
	assert_eq(_lower.current.narrative_checkpoint.reading_session.occurrence_id, "a:parent")

func test_guessed_private_binding_and_altered_target_cannot_authorize_real_producer() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var fake_owner := RefCounted.new()
	assert_false(_port.retain_scene_entry(fake_owner, prepared.value.capability_id,
		_binding, prepared.value.narrative_checkpoint).ok)
	assert_false(_port.consume_scene_entry_ack(prepared.value.capability_id).ok,
		"known capability cannot consume outside real Bridge commit custody")
	var altered: Dictionary = prepared.duplicate(true)
	altered.value.narrative_checkpoint.transaction_id = "forged"
	assert_false(_save(altered).ok)
	assert_false(_bridge.commit_day_entry(altered.value).ok)
	assert_eq(_lower.commit_count, 0)
	_assert_source_unchanged()

func test_no_write_prepare_refusal_retains_same_capability_for_successful_retry() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_lower.prepare_ok = false
	assert_false(_save(prepared).ok)
	assert_eq(_lower.commit_count, 0)
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_false(_bridge._scene_stage_fatal)
	_assert_source_unchanged()
	_lower.prepare_ok = true
	var saved := _save(prepared)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	_assert_real_ack(prepared, saved)
	assert_true(_bridge.commit_day_entry(prepared.value).ok)
	await _settle()
	_assert_target(prepared, "line.scene.test.a.one")

func test_final_capture_callback_cannot_mutate_prepared_candidate_before_write() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_lower.before_capture = func() -> void:
		if _lower.prepared_object.is_empty(): return
		_lower.prepared_object.journal_candidate.current.snapshot.payload["callback_changed"] = true
		_lower.prepared_object.autosave_document.current_snapshot.snapshot = _lower.prepared_object.journal_candidate.current.snapshot.duplicate(true)
	var refused := _save(prepared)
	assert_false(refused.ok)
	assert_eq(refused.code, &"scene_entry_candidate_invalid")
	assert_eq(_lower.commit_count, 0)
	assert_eq(_lower.rollback_count, 0)
	_assert_source_unchanged()
	_lower.dispose_callbacks()
	assert_true(_save(prepared).ok)
	assert_true(_bridge.commit_day_entry(prepared.value).ok)
	await _settle()
	_assert_target(prepared, "line.scene.test.a.one")

func test_prepare_callback_source_mutation_refuses_before_write() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var original_source: Dictionary = _lower.current.duplicate(true)
	_lower.after_prepare = func() -> void: _lower.current["foreign_source"] = true
	assert_false(_save(prepared).ok)
	assert_eq(_lower.commit_count, 0)
	_assert_source_unchanged()
	_lower.dispose_callbacks()
	_lower.current = original_source
	assert_true(_save(prepared).ok)
	assert_true(_bridge.commit_day_entry(prepared.value).ok)
	await _settle()
	_assert_target(prepared, "line.scene.test.a.one")

func test_real_authority_and_lower_callbacks_cannot_reenter_acknowledgement_producer() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var attempts: Array = []
	_authority_callback = func() -> void:
		attempts.append(_port.consume_scene_entry_ack(prepared.value.capability_id))
		attempts.append(_save(prepared))
		attempts.append(_bridge.commit_day_entry(prepared.value))
	_lower.before_commit = func() -> void:
		attempts.append(_port.consume_scene_entry_ack(prepared.value.capability_id))
		attempts.append(_save(prepared))
	var saved := _save(prepared)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	_authority_callback = Callable()
	_lower.dispose_callbacks()
	assert_gt(attempts.size(), 0)
	for result: Dictionary in attempts: assert_false(result.ok)
	assert_false(_bridge._scene_stage_fatal)
	assert_eq(_lower.commit_count, 1)
	assert_true(_bridge.commit_day_entry(prepared.value).ok)
	await _settle()
	_assert_target(prepared, "line.scene.test.a.one")

func test_caller_checkpoint_mutation_in_real_authority_callback_does_not_change_committed_target() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var original: Dictionary = prepared.duplicate(true)
	_authority_callback = func() -> void:
		prepared.value.narrative_checkpoint.content_version = 777
		prepared.value.narrative_checkpoint.transaction_id = "caller:callback"
	var saved := _save(prepared)
	assert_true(saved.ok, str(saved))
	_authority_callback = Callable()
	if not saved.ok: return
	assert_ne(prepared.value.narrative_checkpoint, original.value.narrative_checkpoint)
	_assert_real_ack(original, saved)
	assert_eq(_lower.current.narrative_checkpoint, original.value.narrative_checkpoint)
	assert_true(_bridge.commit_day_entry(original.value).ok)
	await _settle()
	_assert_target(original, "line.scene.test.a.one")

func test_replaced_committed_snapshot_cannot_consume_real_ack() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_true(_save(prepared).ok)
	_lower.current["later_snapshot"] = true
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_true(_bridge._scene_stage_fatal)
	assert_false(_port._scene_used.has(prepared.value.capability_id))
	assert_eq(_adapter.current_line_id(), "line.scene.test.b.two")
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)

func test_confirmed_ack_then_native_source_failure_retains_target_without_rollback() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var saved := _save(prepared)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	_assert_real_ack(prepared, saved)
	# This callback runs during actual producer consumption readback, after the
	# producer's authority check. Real Bridge must recheck native custody.
	_lower.before_capture = func() -> void: _adapter._bound = false
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_true(_port._scene_used.has(prepared.value.capability_id))
	assert_true(_bridge._scene_stage_fatal)
	assert_eq(_bridge._scene_stage.committed_checkpoint, saved.value.checkpoint_reference)
	assert_eq(_lower.current.narrative_checkpoint, prepared.value.narrative_checkpoint)
	assert_eq(_lower.rollback_count, 0)
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	_adapter._bound = true
	_lower.dispose_callbacks()
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_eq(_lower.commit_count, 1)


func test_bridge_reentry_during_lower_commit_exposes_no_target_and_keeps_real_ack_custody() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var nested: Array = []
	_lower.before_commit = func() -> void:
		nested.append(_bridge.commit_day_entry(prepared.value))
	var saved := _save(prepared)
	assert_true(saved.ok, str(saved))
	assert_eq(nested.size(), 1)
	if nested.size() == 1: assert_false(nested[0].ok)
	assert_true(_bridge._scene_stage_fatal,
		"current consumer conservatively treats producer-busy confirmation as uncertain")
	if not saved.ok: return
	_assert_real_ack(prepared, saved)
	assert_false(_port._scene_used.has(prepared.value.capability_id))
	assert_eq(_port._scene_entry.state, "committed")
	assert_eq(_bridge._scene_stage.candidate.ledger.snapshot(),
		prepared.value.narrative_checkpoint.reading_session.ledger)
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	assert_eq(_adapter.current_line_id(), "line.scene.test.b.two")
	assert_same(_bridge._reading_session, _session)
	assert_eq(_lower.rollback_count, 0)
	_lower.dispose_callbacks()
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_eq(_lower.commit_count, 1)

func test_failed_lower_commit_and_rollback_keep_uncertain_nonexposure() -> void:
	if not await _start_source(): return
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_lower.commit_ok = false
	_lower.rollback_ok = false
	var refused := _save(prepared)
	assert_false(refused.ok)
	assert_true(refused.committed)
	assert_eq(_port._scene_entry.state, "uncertain")
	assert_false(_bridge.commit_day_entry(prepared.value).ok)
	assert_true(_bridge._scene_stage_fatal)
	assert_eq(_session.ledger.snapshot(), _source_snapshot.reading_session.ledger)
	assert_eq(_adapter.current_line_id(), "line.scene.test.b.two")
	assert_false(_port._scene_used.has(prepared.value.capability_id))

func after_each() -> void:
	_authority_callback = Callable()
	if _lower != null: _lower.dispose_callbacks()
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



