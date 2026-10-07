extends "res://addons/gut/test.gd"
## Trusted programme, traversal, receipt and restore contract. The native test
## below mounts Dialogic; these detached cases do not claim fresh-process proof.
const FIXTURE := preload("res://tests/support/SceneNextNotificationFixture.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const OP := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const EVENT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")

func _plan(session: RefCounted) -> Dictionary:
	return session.prepare_marker_next(FIXTURE.frontier(session), func(_variant: Dictionary) -> bool: return false,
		FIXTURE.semantic(session))

func _receipt(plan: Dictionary) -> Dictionary:
	var envelope: Dictionary = plan.destination.semantic.duplicate(true)
	envelope.playback_token = "fixture.live"
	return EVENT.make_receipt(envelope, plan.destination.anchor)

func test_first_marker_stops_before_any_later_witness_query_or_caption_publication() -> void:
	var session: RefCounted = FIXTURE.started()
	assert_not_null(session)
	if session == null: return
	var before: Dictionary = session.ledger.snapshot()
	var queried: Array = []
	var plan: Dictionary = session.prepare_marker_next(FIXTURE.frontier(session), func(variant: Dictionary) -> bool:
		queried.append(variant)
		return true, FIXTURE.semantic(session))
	assert_true(plan.ok, str(plan))
	if not plan.ok: return
	assert_eq(plan.value.destination.kind, "notification")
	assert_eq(plan.value.traversed_captions, [])
	assert_eq(queried, [], "even a previously witnessed SECOND cannot cross this marker")
	assert_eq(session.ledger.snapshot(), before, "planning is detached")
	var projected: Dictionary = OP.project(plan.value, "destination")
	assert_true(projected.ok, str(projected))
	assert_eq(projected.value.boundary, "notification")
	assert_eq(projected.value.ledger, before, "the marker is not a History caption")
	assert_true(session.validate_saved(projected.value, FIXTURE.ENTRY).ok)

func test_notification_restore_requires_exact_receipt_then_next_reaches_second_once() -> void:
	var session: RefCounted = FIXTURE.started()
	assert_not_null(session)
	if session == null: return
	var plan := _plan(session)
	assert_true(plan.ok, str(plan))
	if not plan.ok: return
	var saved: Dictionary = OP.project(plan.value, "destination").value
	var receipt := _receipt(plan.value)
	assert_true(receipt.ok, str(receipt))
	if not receipt.ok: return
	var receipts := {receipt.value.transaction_id: receipt.value}
	var run_id: String = plan.value.destination.semantic.source.run_id
	assert_eq(session.validate_marker_receipts(saved, FIXTURE.ENTRY, {}, run_id).code, &"reading_marker_receipt_missing")
	assert_true(session.validate_marker_receipts(saved, FIXTURE.ENTRY, receipts, run_id).ok)
	var fresh: RefCounted = FIXTURE.configured()
	assert_true(fresh.restore(saved, FIXTURE.ENTRY).ok)
	assert_eq(fresh.capture({}).value, saved)
	var resumed: Dictionary = fresh.prepare_marker_next(saved.frontier,
		func(_variant: Dictionary) -> bool: return false)
	assert_true(resumed.ok, str(resumed))
	if not resumed.ok: return
	assert_eq(resumed.value.destination.kind, "line")
	assert_eq(resumed.value.destination.caption.beat.line_id, FIXTURE.SECOND)
	var second: Dictionary = OP.project(resumed.value, "destination").value
	assert_eq(second.ledger.captions.size(), 2)
	assert_true(fresh.validate_marker_receipts(second, FIXTURE.ENTRY, receipts, run_id).ok)
	assert_eq(fresh.validate_marker_receipts(second, FIXTURE.ENTRY, {}, run_id).code, &"reading_marker_receipt_missing",
		"a later caption cannot erase the converse marker obligation")
	assert_true(fresh.restore(saved, FIXTURE.ENTRY).ok)
	assert_eq(fresh.ledger.snapshot().captions.size(), 1, "repeated restore retains original publication")

func test_receipt_ahead_of_cursor_and_changed_run_refuse_before_installation() -> void:
	var session: RefCounted = FIXTURE.started()
	assert_not_null(session)
	if session == null: return
	var plan := _plan(session)
	assert_true(plan.ok, str(plan))
	if not plan.ok: return
	var receipt := _receipt(plan.value)
	assert_true(receipt.ok, str(receipt))
	if not receipt.ok: return
	var receipts := {receipt.value.transaction_id: receipt.value}
	var before: Dictionary = session.ledger.snapshot()
	var source: Dictionary = OP.project(plan.value, "source").value
	var target: Dictionary = OP.project(plan.value, "destination").value
	assert_eq(session.validate_marker_receipts(source, FIXTURE.ENTRY, receipts,
		plan.value.destination.semantic.source.run_id).code, &"reading_marker_receipt_ahead")
	assert_false(session.validate_marker_receipts(target, FIXTURE.ENTRY, receipts, "different.run").ok)
	assert_eq(session.ledger.snapshot(), before)

func test_changed_plan_digest_extra_fields_and_projection_refuse() -> void:
	var session: RefCounted = FIXTURE.started()
	assert_not_null(session)
	if session == null: return
	var plan := _plan(session)
	assert_true(plan.ok, str(plan))
	if not plan.ok: return
	var saved: Dictionary = OP.project(plan.value, "destination").value
	var corruptions: Array[Dictionary] = []
	var changed := saved.duplicate(true)
	changed.next_operation.operation_id = "0".repeat(64)
	corruptions.append(changed)
	changed = saved.duplicate(true)
	changed.frontier.event_digest = "0".repeat(64)
	corruptions.append(changed)
	changed = saved.duplicate(true)
	changed.frontier.anchor.publication_id = "caption:99"
	corruptions.append(changed)
	changed = saved.duplicate(true)
	changed.marker_program_fingerprint = "0".repeat(64)
	corruptions.append(changed)
	changed = saved.duplicate(true)
	changed["native_event_index"] = 2
	corruptions.append(changed)
	for bad: Dictionary in corruptions:
		assert_false(session.validate_saved(bad, FIXTURE.ENTRY).ok, str(bad))
	assert_true(session.validate_saved(saved, FIXTURE.ENTRY).ok, "positive control after each negative")

func test_recomputed_plan_cannot_bypass_registered_marker_or_change_payload() -> void:
	var session: RefCounted = FIXTURE.started()
	assert_not_null(session)
	if session == null: return
	var planned := _plan(session)
	assert_true(planned.ok, str(planned))
	if not planned.ok: return
	var bypass: Dictionary = planned.value.duplicate(true)
	bypass.destination = {"kind": "line", "caption": FIXTURE.BASE.caption("b", 2)}
	var forged: Dictionary = OP.project(bypass, "destination")
	assert_true(forged.ok, "shape and digest are internally consistent: " + str(forged))
	if forged.ok:
		assert_eq(session.validate_saved(forged.value, FIXTURE.ENTRY).code, &"reading_marker_bypassed")
	var changed: Dictionary = planned.value.duplicate(true)
	changed.destination.semantic.payload.content_id = "fixture.forged"
	forged = OP.project(changed, "destination")
	assert_true(forged.ok, str(forged))
	if forged.ok:
		assert_eq(session.validate_saved(forged.value, FIXTURE.ENTRY).code, &"reading_marker_registration_mismatch")

func test_trusted_registration_refuses_terminal_nonadjacent_and_unknown_markers() -> void:
	for mode: String in ["terminal", "nonadjacent", "unknown", "duplicate", "float"]:
		var session := SESSION.new()
		assert_true(session.configure(FIXTURE.catalogue()).ok)
		var document: Dictionary = FIXTURE.markers(session.fingerprint)
		match mode:
			"terminal": document.entries[0].marker.before_line_id = ""
			"nonadjacent": document.entries[0].marker.after_line_id = FIXTURE.SECOND
			"unknown": document.entries[0].marker.after_line_id = "fixture.unknown"
			"duplicate": document.entries.append(document.entries[0].duplicate(true))
			"float": document.entries[0].marker.ordinal = 0.0
		assert_false(session.configure_markers(document).ok, mode)
		assert_true(session.marker_entries.is_empty(), "rejected registration cannot partially install")

func test_native_authored_locator_requires_explicit_matching_trusted_marker() -> void:
	var session: RefCounted = FIXTURE.configured()
	assert_not_null(session)
	if session == null: return
	var adapter := ADAPTER.new()
	var lines: Array = session.catalogue[FIXTURE.ENTRY].lines
	var marker: Dictionary = session.marker_entries[FIXTURE.ENTRY]
	assert_true(adapter.validate_reading_entry(FIXTURE.PATH, FIXTURE.ENTRY, lines, marker).ok)
	assert_false(adapter.validate_reading_entry(FIXTURE.PATH, FIXTURE.ENTRY, lines).ok)
	var changed := marker.duplicate(true)
	changed.label = "scene.marker.unregistered"
	assert_false(adapter.validate_reading_entry(FIXTURE.PATH, FIXTURE.ENTRY, lines, changed).ok)

const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
var _durable_fixtures: Array[RefCounted] = []
var _native_session: RefCounted
var _runtime: DialogicGameHandler
var _adapter: DialogicRuntimeAdapter
var _ledger: NarrativeCaptionLedger
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
var _completion_at_publication: Array[bool] = []
var _restored: Array[Dictionary] = []
var _profile_before: Dictionary = {}
var _seek_results: Array[Dictionary] = []

func _mount_native() -> void:
	_results.clear()
	_restored.clear()
	_completion_at_publication.clear()
	_seek_results.clear()
	_profile_before = get_node("/root/ProfileManager").get_profile_snapshot().duplicate(true)
	_native_session = FIXTURE.started(false)
	assert_not_null(_native_session)
	_ledger = _native_session.ledger
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
	_adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void:
		_results.append(result.duplicate(true))
		_completion_at_publication.append(_adapter.is_current_line_complete()))
	_adapter.reading_frontier_restored.connect(func(result: Dictionary) -> void:
		_restored.append(result.duplicate(true)))
	_adapter.reading_seek_finished.connect(func(result: Dictionary) -> void:
		_seek_results.append(result.duplicate(true)))

func after_each() -> void:
	for fixture: RefCounted in _durable_fixtures: fixture.dispose()
	_durable_fixtures.clear()
	if not is_instance_valid(_runtime): return
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

func test_mounted_partial_reveal_parks_without_second_then_resumes_original_coroutine_once() -> void:
	await _mount_native()
	var marker: Dictionary = _native_session.marker_entries[FIXTURE.ENTRY]
	assert_true(_adapter.bind_caption_ledger(_ledger, _native_session.command_id, FIXTURE.ENTRY).ok)
	assert_true(_adapter.bind_reading_marker(marker).ok)
	assert_true(_adapter.start_timeline(FIXTURE.PATH, FIXTURE.ENTRY).ok)
	await _settle()
	var source: Dictionary = _adapter.capture_reading_frontier()
	assert_true(source.ok, str(source))
	if not source.ok: return
	assert_eq(source.value.line_id, FIXTURE.FIRST)
	assert_false(_adapter.is_current_line_complete())
	var retained: Dictionary = _ledger.snapshot()
	var planned := _plan(_native_session)
	assert_true(planned.ok, str(planned))
	if not planned.ok: return
	var target: Dictionary = OP.project(planned.value, "destination").value
	var prepared: Dictionary = _adapter.prepare_marker_seek(FIXTURE.ENTRY,
		_native_session.catalogue[FIXTURE.ENTRY].lines, FIXTURE.FIRST)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var parked: Dictionary = _adapter.hold_marker_source(source.value)
	assert_true(parked.ok, str(parked))
	if not parked.ok: return
	var candidate: RefCounted = FIXTURE.configured()
	assert_true(candidate.restore(target, FIXTURE.ENTRY).ok)
	var installed: Dictionary = _adapter.install_marker_candidate(prepared.value, candidate.ledger, target.frontier)
	assert_true(installed.ok, str(installed))
	await _settle()
	assert_eq(candidate.ledger.snapshot(), retained)
	assert_eq(_results.size(), 1, "SECOND has not been physically published")
	assert_true(_adapter.hold_marker_source(source.value).ok, "held retry never advances a retired coroutine")
	var resumed: Dictionary = candidate.prepare_marker_next(target.frontier,
		func(_variant: Dictionary) -> bool: return false)
	assert_true(resumed.ok, str(resumed))
	if not resumed.ok: return
	var second: Dictionary = OP.project(resumed.value, "destination").value
	prepared = _adapter.prepare_marker_seek(FIXTURE.ENTRY, candidate.catalogue[FIXTURE.ENTRY].lines, FIXTURE.SECOND)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var destination: RefCounted = FIXTURE.configured()
	assert_true(destination.restore(second, FIXTURE.ENTRY).ok)
	installed = _adapter.install_marker_candidate(prepared.value, destination.ledger, second.frontier)
	assert_true(installed.ok, str(installed))
	await _settle()
	assert_eq(_adapter.current_line_id(), FIXTURE.SECOND)
	assert_eq(destination.ledger.snapshot().captions.size(), 2)
	assert_eq(_results.size(), 2)
	assert_false(_adapter.install_marker_candidate(prepared.value, destination.ledger, second.frontier).ok,
		"consumed held capability cannot replay physical publication")

func test_witnessed_intermediate_caption_is_retained_once_before_marker_stop() -> void:
	var session := SESSION.new()
	var document: Dictionary = FIXTURE.catalogue()
	var gap := {"beat_id": "fixture.next.beat.gap", "line_id": "fixture.next.gap",
		"text": "An already witnessed intermediate caption.", "revision": "fixture-v1"}
	document.entries[0].lines.insert(1, gap)
	assert_true(session.configure(document).ok)
	var markers: Dictionary = FIXTURE.markers(session.fingerprint)
	markers.entries[0].marker.after_line_id = gap.line_id
	assert_true(session.configure_markers(markers).ok)
	var checkpoint: Dictionary = FIXTURE.BASE.snapshot().narrative_checkpoint
	assert_true(session.begin(checkpoint.reading_session.ledger.session_token, FIXTURE.ENTRY).ok)
	assert_true(session.admit(FIXTURE.ENTRY, checkpoint.frozen_context).ok)
	var allocated: Dictionary = session.ledger.allocate_publication(session.command_id, FIXTURE.ENTRY)
	assert_true(allocated.ok)
	assert_true(session.ledger.publish_line(session.command_id, allocated.value, FIXTURE.ENTRY, FIXTURE.FIRST).ok)
	var queries: Array = []
	var plan: Dictionary = session.prepare_marker_next(FIXTURE.frontier(session), func(variant: Dictionary) -> bool:
		queries.append(variant.line_id)
		return variant.line_id == gap.line_id, FIXTURE.semantic(session))
	assert_true(plan.ok, str(plan))
	if not plan.ok: return
	assert_eq(queries, [gap.line_id], "the later SECOND witness is not queried")
	assert_eq(plan.value.traversed_captions.size(), 1)
	assert_eq(plan.value.destination.anchor.line_id, gap.line_id)
	var saved: Dictionary = OP.project(plan.value, "destination").value
	assert_true(session.validate_saved(saved, FIXTURE.ENTRY).ok)
	assert_eq(saved.ledger.captions.size(), 2)
	var receipt := _receipt(plan.value)
	assert_true(receipt.ok, str(receipt))
	if not receipt.ok: return
	assert_true(session.validate_marker_receipts(saved, FIXTURE.ENTRY,
		{receipt.value.transaction_id: receipt.value}, plan.value.destination.semantic.source.run_id).ok)
	assert_true(session.restore(saved, FIXTURE.ENTRY).ok)
	assert_true(session.restore(saved, FIXTURE.ENTRY).ok)
	assert_eq(session.ledger.snapshot().captions.size(), 2)

func test_connected_bridge_partial_next_commits_marker_and_later_next_preserves_receipt() -> void:
	var process_phase := OS.get_environment("DWM_SCENE_MARKER_PHASE").strip_edges()
	if not process_phase.is_empty():
		await FIXTURE.new().run_process_phase(self, process_phase,
			OS.get_environment("DWM_SCENE_MARKER_REPORT_DIR").strip_edges())
		return
	await _mount_native()
	var bridge: Node = preload("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(bridge)
	assert_true(bridge.initialize(null, _adapter).ok)
	var fixture: RefCounted = FIXTURE.new()
	_durable_fixtures.append(fixture)
	var initialized: Dictionary = fixture.initialize_with_bridge(bridge)
	assert_true(initialized.ok, str(initialized))
	if not initialized.ok: return
	var profile: Node = autofree(preload("res://autoload/ProfileManager.gd").new())
	assert_true(profile.configure_mutation_gate(fixture.gate).ok)
	var ids: Dictionary = preload("res://scripts/narrative/DialogicEntryManifest.gd").load_ids_default()
	assert_true(ids.ok, str(ids))
	assert_true(profile.configure_line_registry(ids.value).ok)
	assert_true(profile.initialize(preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		OS.get_environment("DWM_TEST_ROOT").path_join("marker-profile"),
		preload("res://tests/support/FakeFileOps.gd").new())).ok)
	assert_true(bridge.configure_skip_context(profile, &"read_only").ok)
	assert_true(bridge.configure_reading_catalogue(FIXTURE.catalogue()).ok)
	assert_true(bridge.configure_test_reading_markers(FIXTURE.markers(_native_session.fingerprint), fixture.issuer).ok)
	bridge._reading_session = _native_session
	var frame: Dictionary = fixture.snapshot.narrative_checkpoint.frozen_context
	bridge._active_entry = {"entry_id": FIXTURE.ENTRY, "token": "marker.fixture.live", "stage": "pre_challenge",
		"execution_mode": &"canonical", "transaction_id": frame.transaction_id,
		"context_fingerprint": "fixture.marker.context", "content_version": 1,
		"path": FIXTURE.PATH, "label": FIXTURE.ENTRY, "frozen_context": frame}
	assert_true(_adapter.bind_caption_ledger(_ledger, _native_session.command_id, FIXTURE.ENTRY).ok)
	assert_true(_adapter.bind_reading_marker(_native_session.marker_entries[FIXTURE.ENTRY]).ok)
	assert_true(_adapter.start_timeline(FIXTURE.PATH, FIXTURE.ENTRY).ok)
	await _settle()
	assert_false(_adapter.is_current_line_complete())
	var proof: Dictionary = bridge.capture_next_frontier()
	assert_true(proof.ok, str(proof))
	if not proof.ok: return
	var admission_profile: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var admission_files: Dictionary = fixture.files.snapshot_persisted()
	for busy: String in ["_line_ack_in_progress", "_auto_step_in_progress", "_skip_step_in_progress"]:
		bridge.set(busy, true)
		var busy_result: Dictionary = await bridge.request_next(proof)
		bridge.set(busy, false)
		assert_false(busy_result.ok, busy)
		assert_false(_adapter.is_current_line_complete(), "busy refusal precedes revealing")
	bridge._pause_restore = {"applied": false}
	var pause_refused: Dictionary = await bridge.request_next(proof)
	bridge._pause_restore = {}
	assert_false(pause_refused.ok)
	bridge._line_ack_fatal_failure = {"ok": false, "code": &"fixture_retained_ack_failure"}
	var fatal_refused: Dictionary = await bridge.request_next(proof)
	bridge._line_ack_fatal_failure = {}
	assert_eq(fatal_refused.code, &"fixture_retained_ack_failure")
	assert_false(_adapter.is_current_line_complete())
	assert_eq(profile.get_profile_snapshot(), admission_profile)
	assert_eq(fixture.files.snapshot_persisted(), admission_files)
	assert_eq(_results.size(), 1)
	fixture.real.fail_on_commit = 2
	var refused: Dictionary = await bridge.request_next(proof)
	assert_false(refused.ok, "destination write fails after the source commit")
	assert_false(fixture.gate.is_fatal_latched(), str(refused))
	assert_false(fixture.gate.is_active())
	assert_true(_adapter.is_marker_source_held(), "retry retains the retired coroutine capability")
	var source_disk: Dictionary = fixture.disk_snapshot()
	assert_true(source_disk.ok, str(source_disk))
	if not source_disk.ok: return
	assert_eq(source_disk.value.command_receipts.size(), 0)
	assert_eq(source_disk.value.narrative_checkpoint.reading_session.next_operation.phase, "source")
	var frozen_command: Dictionary = source_disk.value.narrative_checkpoint.reading_session.next_operation.plan.destination.semantic
	assert_eq(_results.size(), 1)
	var retry_frontier: Dictionary = bridge.capture_next_frontier()
	assert_true(retry_frontier.ok, str(retry_frontier))
	var result: Dictionary = await bridge.request_next(retry_frontier)
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.destination, "notification")
	var disk: Dictionary = fixture.disk_snapshot()
	assert_true(disk.ok, str(disk))
	if not disk.ok: return
	assert_eq(disk.value.narrative_checkpoint.reading_session.boundary, "notification")
	assert_eq(disk.value.command_receipts.size(), 1)
	assert_eq(disk.value.narrative_checkpoint.reading_session.ledger.captions.size(), 1)
	assert_eq(_results.size(), 1)
	assert_eq(profile.get_profile_snapshot().witnessed_caption_variants.size(), 1)
	assert_false(fixture.gate.is_active())
	var saved_receipts: Dictionary = disk.value.command_receipts.duplicate(true)
	assert_true(saved_receipts.has(frozen_command.command_id), "compensated retry retains the issued command")
	assert_eq(saved_receipts[frozen_command.command_id].scene_event.semantic, frozen_command)
	var held: Dictionary = bridge.capture_next_frontier()
	assert_true(held.ok, str(held))
	assert_ne(held, proof)
	var stale: Dictionary = await bridge.request_next(proof)
	assert_false(stale.ok)
	assert_eq(fixture.disk_snapshot().value.command_receipts, saved_receipts)
	result = await bridge.request_next(held)
	assert_true(result.ok, str(result))
	if not result.ok: return
	await _settle()
	assert_eq(result.value.destination, "line")
	assert_eq(_adapter.current_line_id(), FIXTURE.SECOND)
	disk = fixture.disk_snapshot()
	assert_true(disk.ok, str(disk))
	if not disk.ok: return
	assert_eq(disk.value.command_receipts, saved_receipts)
	assert_eq(disk.value.narrative_checkpoint.reading_session.ledger.captions.size(), 2)
	assert_eq(profile.get_profile_snapshot().witnessed_caption_variants.size(), 1,
		"the destination is published but remains unwitnessed")
	assert_eq(_results.size(), 2)
	assert_false(fixture.gate.is_active())
