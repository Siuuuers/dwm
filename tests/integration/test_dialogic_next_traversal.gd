extends "res://addons/gut/test.gd"
## Real Bridge, frozen Solo session, Profile and application gate. The physical
## storage refusal and native renderer are isolated here; mounted runtime and
## fresh-process durability are proved by their separate cloud suites.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const IDS := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const PRE := "dating.solo.priscilla.day1.pre_challenge"
const FIRST := "fixture.solo.pre.a"
const SECOND := "fixture.solo.pre.b"

class NativeSeek extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	signal caption_publication_recorded(result: Dictionary)
	signal reading_seek_finished(result: Dictionary)
	var line_id := FIRST
	var publication: Dictionary = {}
	var complete := false
	var active := true
	var reveals := 0
	var advances := 0
	var applies := 0
	var preparations: Array[Dictionary] = []
	var apply_callback := Callable()
	var reveal_callback := Callable()
	var apply_failure: Dictionary = {}
	func start_timeline(_path: String, _event_index: Variant = 0) -> Dictionary: return {"ok": true}
	func current_line_id() -> String: return line_id
	func is_current_line_complete() -> bool: return complete
	func has_active_playback() -> bool: return active
	func can_capture_reading_frontier() -> bool: return active and not publication.is_empty()
	func capture_reading_frontier() -> Dictionary: return {"ok": true, "value": publication.duplicate(true)}
	func capture_pause_frontier() -> Dictionary:
		return {"ok": true, "value": {"generation": 1, "event_index": 0,
			"request_id": "next-owner-fixture", "paused": false}}
	func reveal_current_line(_preserve: bool = false) -> Dictionary:
		reveals += 1
		complete = true
		if reveal_callback.is_valid(): reveal_callback.call()
		return {"ok": true}
	func complete_reading_frontier() -> Dictionary:
		complete = true
		return capture_reading_frontier()
	func classify_next_event() -> StringName: return &"text"
	func advance_one_event() -> Dictionary:
		advances += 1
		return {"ok": true}
	func halt_with_error(_failure: Dictionary) -> Dictionary: return {"ok": false}
	func prepare_reading_seek(source: Dictionary, entry: String, _lines: Array, destination: String = "") -> Dictionary:
		var plan := {"source": source.duplicate(true), "entry_id": entry, "destination_line_id": destination}
		preparations.append(plan)
		return {"ok": true, "value": plan.duplicate(true)}
	func apply_reading_seek(plan: Dictionary, _ledger: NarrativeCaptionLedger, frontier: Dictionary = {}) -> Dictionary:
		applies += 1
		if apply_callback.is_valid(): apply_callback.call()
		if not apply_failure.is_empty(): return apply_failure.duplicate(true)
		publication = frontier.duplicate(true)
		line_id = str(plan.destination_line_id)
		complete = false
		active = not frontier.is_empty()
		if active: caption_publication_recorded.emit({"ok": true, "value": {"duplicate": true}})
		else: timeline_ended_signal.emit()
		reading_seek_finished.emit({"ok": true, "value": {"frontier": frontier, "terminal": not active}})
		return {"ok": true, "value": {"pending": false}}

class Checkpoints extends RefCounted:
	var calls: Array[Dictionary] = []
	var completions: Array[Dictionary] = []
	var reject_phase := ""
	var callback := Callable()
	var persisted: Dictionary = {}
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
		if callback.is_valid(): callback.call(phase)
		if reject_phase == phase:
			reject_phase = ""
			return {"ok": false, "code": &"fixture_storage_refused", "fatal": false}
		persisted = checkpoint.duplicate(true)
		return {"ok": true, "receipt": {"operation_id": operation_id, "phase": phase}}

var _bridge: Node
var _profile: Node
var _native: NativeSeek
var _port: Checkpoints
var _gate: ApplicationMutationGate
var _document: Dictionary

func before_each() -> void:
	var wrapper := OS.get_environment("DWM_TEST_ROOT").strip_edges()
	assert_false(wrapper.is_empty(), "the cloud wrapper supplies isolated storage")
	_gate = GATE.new()
	_profile = autofree(MANAGER.new())
	assert_true(_profile.configure_mutation_gate(_gate).ok)
	var ids := IDS.load_ids_default()
	assert_true(ids.ok, str(ids))
	assert_true(_profile.configure_line_registry(ids.value).ok)
	assert_true(_profile.initialize(STORAGE.new(wrapper.path_join("next-owner-bridge"), FILES.new())).ok)
	_native = NativeSeek.new()
	_port = Checkpoints.new()
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)
	assert_true(_bridge.initialize(null, _native).ok)
	assert_true(_bridge.configure_mutation_gate(_gate).ok)
	assert_true(_bridge.configure_skip_context(_profile, &"read_only").ok)
	assert_true(_bridge.configure_narrative_checkpoint_port(_port).ok)
	assert_true(_bridge.configure_playback_completion_port(_port).ok)
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/dialogic/solo_reading_rail_catalogue.json"))
	assert_true(parsed.ok, str(parsed))
	_document = parsed.value

func _activate(document: Dictionary = {}) -> RefCounted:
	var selected := _document if document.is_empty() else document
	assert_true(_bridge.configure_reading_catalogue(selected).ok)
	var session := SESSION.new()
	assert_true(session.configure(selected).ok)
	assert_true(session.begin("next-fixture", PRE).ok)
	var fields := {"entry_id": PRE, "entry_role": "solo_pre_challenge", "day": 1,
		"friend_id": "priscilla", "tier": "friend", "tone": "sweet", "attitude": "",
		"run_id": "next:run", "branch_id": "next:branch", "challenge_slot": "dating.solo.priscilla.day1",
		"phase": "pre_challenge", "due_echoes": [], "attempt_residue_id": null}
	var frozen := FROZEN.build(PRE, fields)
	assert_true(frozen.ok, str(frozen))
	var context := {"expected_stage": "pre_challenge", "playback_id": "next:physical",
		"role": "dating_phase", "transaction_id": "next-fixture:pre_challenge", "presentation": frozen.value}
	assert_true(session.admit(PRE, context).ok)
	var allocation: Dictionary = session.ledger.allocate_publication(session.command_id, PRE)
	assert_true(allocation.ok)
	assert_true(session.ledger.publish_line(session.command_id, allocation.value, PRE, FIRST).ok)
	_native.publication = {"line_id": FIRST, "publication_id": allocation.value}
	_bridge._reading_session = session
	_bridge._active_entry = {"entry_id": PRE, "token": "next:token", "stage": "pre_challenge",
		"execution_mode": &"canonical", "transaction_id": context.transaction_id,
		"context_fingerprint": "next:context"}
	return session

func _seed(lines: Array, document: Dictionary = {}) -> void:
	var session := SESSION.new()
	assert_true(session.configure(_document if document.is_empty() else document).ok)
	for beat: Dictionary in session.registry.beats:
		if beat.line_id in lines:
			assert_true(_profile.mark_caption_variant_witnessed(beat, session.registry).ok)

func _proof() -> Dictionary:
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(proof.ok, str(proof))
	return proof

func test_partial_unseen_next_finishes_and_witnesses_current_line_then_seeks_in_same_activation() -> void:
	_activate()
	var proof := _proof()
	assert_true(_bridge.can_next_current_line())
	var result: Dictionary = await _bridge.request_next(proof)
	assert_true(result.ok, str(result))
	assert_eq(result.value.destination, "line")
	assert_eq(_native.reveals, 1)
	assert_eq(_native.applies, 1)
	assert_eq(_port.calls.size(), 2)
	assert_eq(_native.line_id, SECOND)
	assert_false(_native.complete, "destination retains ordinary partial reveal")
	assert_true(_profile.is_caption_variant_witnessed(proof.value.caption_variant))
	assert_eq(_bridge.get_reading_history().value.captions.size(), 2)
	assert_false(_gate.is_active())
	assert_false(_bridge.is_next_traversal_active())

func test_complete_source_seeks_first_unseen_caption_after_both_durable_phases_without_witnessing_target() -> void:
	_activate()
	_native.complete = true
	var result: Dictionary = await _bridge.request_next(_proof())
	assert_true(result.ok, str(result))
	assert_eq(result.value.destination, "line")
	assert_eq(_port.calls.size(), 2)
	assert_eq(_port.calls[0].phase, "source")
	assert_eq(_port.calls[1].phase, "destination")
	assert_eq(_port.calls[0].operation_id, _port.calls[1].operation_id)
	assert_eq(_port.persisted.reading_session.frontier, _native.publication)
	assert_eq(_native.line_id, SECOND)
	assert_false(_native.complete, "first unseen destination retains ordinary reveal")
	assert_eq(_native.applies, 1)
	assert_eq(_profile.get_profile_snapshot().witnessed_caption_variants.size(), 1)
	var target_proof := _proof()
	assert_false(_profile.is_caption_variant_witnessed(target_proof.value.caption_variant))
	assert_eq(_bridge.get_reading_history().value.captions.size(), 2)
	assert_false(_gate.is_active())

func test_exact_witnessed_tail_goes_to_natural_completion_with_once_only_history_and_no_profile_growth() -> void:
	_seed([FIRST, SECOND])
	_activate()
	var profile_before: Dictionary = _profile.get_profile_snapshot()
	var proof := _proof()
	var notifications: Array[Dictionary] = []
	_bridge.next_request_finished.connect(func(frontier: Dictionary, result: Dictionary) -> void:
		notifications.append({"frontier": frontier, "result": result})
		assert_false(_bridge.is_next_traversal_active(), "completion belongs to the surviving Bridge after custody settles")
		assert_false(_gate.is_active()))
	var result: Dictionary = await _bridge.request_next(proof)
	assert_true(result.ok, str(result))
	assert_eq(notifications, [{"frontier": proof, "result": result}])
	assert_eq(result.value.destination, "completion")
	assert_eq(_native.applies, 1)
	assert_eq(_port.completions.size(), 1)
	assert_eq(_port.completions[0].completion_kind, &"natural_end")
	assert_eq(_bridge._reading_session.boundary, "between_entries")
	assert_eq(_bridge.get_reading_history().value.captions.size(), 2)
	assert_eq(_profile.get_profile_snapshot(), profile_before)
	assert_eq(_port.persisted.reading_session.boundary, "between_entries")
	assert_eq(_bridge.capture_next_physical_checkpoint().value, _port.persisted)
	assert_false(_gate.is_active())

func test_auto_on_refuses_next_without_profile_acknowledgement_or_native_motion() -> void:
	_activate()
	assert_true(_profile.set_preference(&"preferences.reading.auto_enabled", true).ok)
	var before: Dictionary = _profile.get_profile_snapshot()
	var result: Dictionary = await _bridge.request_next(_proof())
	assert_false(result.ok)
	assert_eq(result.code, &"reading_next_auto_enabled")
	assert_eq(_native.reveals, 0)
	assert_eq(_native.applies, 0)
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_port.calls, [])

func test_source_write_refusal_keeps_native_source_and_retries_the_same_operation() -> void:
	_seed([FIRST, SECOND])
	var session := _activate()
	var source: Dictionary = session.ledger.snapshot()
	var proof := _proof()
	_port.reject_phase = "source"
	var refused: Dictionary = await _bridge.request_next(proof)
	assert_eq(refused.code, &"fixture_storage_refused")
	assert_eq(_native.applies, 0)
	assert_eq(_native.reveals, 0)
	assert_eq(session.ledger.snapshot(), source)
	assert_eq(session.next_operation, {})
	assert_false(_gate.is_active())
	var retried: Dictionary = await _bridge.request_next(proof)
	assert_true(retried.ok, str(retried))
	assert_eq(_port.calls.size(), 3)
	assert_eq(_port.calls[0].operation_id, _port.calls[1].operation_id)
	assert_eq(_native.applies, 1)

func test_destination_write_refusal_keeps_exact_durable_source_then_retry_uses_identical_plan() -> void:
	_seed([FIRST, SECOND])
	var session := _activate()
	var proof := _proof()
	var source: Dictionary = session.ledger.snapshot()
	_port.reject_phase = "destination"
	var refused: Dictionary = await _bridge.request_next(proof)
	assert_eq(refused.code, &"fixture_storage_refused")
	assert_eq(_native.applies, 0)
	assert_eq(session.ledger.snapshot(), source)
	assert_eq(session.next_operation.phase, "source")
	assert_eq(_port.persisted.reading_session.next_operation, session.next_operation)
	assert_false(_gate.is_active())
	var retried: Dictionary = await _bridge.request_next(proof)
	assert_true(retried.ok, str(retried))
	assert_eq(_port.calls.size(), 4)
	assert_eq(_port.calls[0].checkpoint, _port.calls[2].checkpoint)
	assert_eq(_port.calls[1].checkpoint, _port.calls[3].checkpoint)
	assert_eq(_native.applies, 1)

func test_exclusive_next_coalesces_identical_activation_and_blocks_every_intermediate_command() -> void:
	_seed([FIRST, SECOND])
	_activate()
	var proof := _proof()
	var observations: Array[Dictionary] = []
	var notifications: Array[Dictionary] = []
	_bridge.next_request_finished.connect(func(frontier: Dictionary, result: Dictionary) -> void:
		notifications.append({"frontier": frontier, "result": result}))
	_port.callback = func(phase: String) -> void:
		if phase != "source": return
		assert_true(_bridge.is_next_traversal_active())
		assert_eq(_gate.get_active_owner(), &"causal_transaction")
		var identical: Dictionary = await _bridge.request_next(proof)
		observations.append(identical)
		assert_true(notifications.is_empty(), "coalescing cannot announce completion of the still-active original request")
		var changed := proof.duplicate(true)
		changed.value.token = "stale-next-command"
		var conflict: Dictionary = await _bridge.request_next(changed)
		observations.append(conflict)
		assert_false(_bridge.can_next_current_line())
		assert_false(_bridge.can_capture_reading_checkpoint())
		assert_false(_bridge.capture_reading_checkpoint(true).ok, "Save cannot finish an intermediate frontier")
		assert_false(_bridge.get_reading_history().ok)
		assert_false(_bridge.capture_pause_frontier().ok)
		assert_false(_bridge.request_skip_step().ok)
		assert_false(_bridge.request_auto_step(proof).ok)
		assert_false(_bridge.acknowledge_current_line_presentation(proof).ok)
		assert_false(_profile.set_preference(&"preferences.reading.auto_enabled", true).ok)
	var result: Dictionary = await _bridge.request_next(proof)
	assert_true(result.ok, str(result))
	assert_eq(observations.size(), 2)
	assert_eq(observations[0].code, &"coalesced")
	assert_eq(observations[1].code, &"reading_next_command_conflict")
	assert_eq(notifications.size(), 2)
	assert_eq(notifications[0].result.code, &"reading_next_command_conflict")
	assert_ne(notifications[0].frontier, proof)
	assert_eq(notifications[1], {"frontier": proof, "result": result})
	assert_eq(_native.applies, 1)
	assert_false(_gate.is_active())

func test_reentrant_source_replacement_after_source_commit_fences_without_overwriting_new_owner() -> void:
	_seed([FIRST, SECOND])
	_activate()
	_port.callback = func(phase: String) -> void:
		if phase == "source": _bridge._active_entry.token = "replacement-owner"
	var result: Dictionary = await _bridge.request_next(_proof())
	assert_false(result.ok)
	assert_eq(result.code, &"reading_next_source_replaced")
	assert_true(result.fatal)
	assert_true(_gate.is_fatal_latched())
	assert_eq(_bridge._active_entry.token, "replacement-owner")
	assert_eq(_port.calls.size(), 1)
	assert_eq(_native.applies, 0)
	assert_eq(_port.persisted.reading_session.next_operation.phase, "source")

func test_changed_exact_revision_is_acknowledged_before_traversing_witnessed_tail() -> void:
	_seed([FIRST, SECOND])
	var changed := _document.duplicate(true)
	changed.entries[0].lines[0].revision = "next-fixture-revised-source"
	_activate(changed)
	var proof := _proof()
	assert_true(_profile.is_line_visited(FIRST))
	assert_false(_profile.is_caption_variant_witnessed(proof.value.caption_variant))
	var result: Dictionary = await _bridge.request_next(proof)
	assert_true(result.ok, str(result))
	assert_eq(result.value.destination, "completion")
	assert_true(_profile.is_caption_variant_witnessed(proof.value.caption_variant))
	assert_eq(_native.applies, 1)
	assert_eq(_port.calls.size(), 2)

func test_normal_publication_after_refused_destination_retires_only_the_live_operation() -> void:
	_seed([FIRST, SECOND])
	var session := _activate()
	_port.reject_phase = "destination"
	var refused: Dictionary = await _bridge.request_next(_proof())
	assert_false(refused.ok)
	var durable := _port.persisted.duplicate(true)
	assert_false(session.next_operation.is_empty())
	var allocation: Dictionary = session.ledger.allocate_publication(session.command_id, PRE)
	assert_true(allocation.ok)
	assert_true(session.ledger.publish_line(session.command_id, allocation.value, PRE, SECOND).ok)
	_native.line_id = SECOND
	_native.publication = {"line_id": SECOND, "publication_id": allocation.value}
	_native.caption_publication_recorded.emit({"ok": true, "value": {"duplicate": false}})
	assert_eq(session.next_operation, {})
	assert_eq(_port.persisted, durable, "ordinary progress does not rewrite the retained recovery checkpoint")
	assert_eq(_bridge.get_reading_history().value.captions.size(), 2)

func test_durable_destination_with_native_rejection_keeps_exact_target_and_fatal_custody() -> void:
	_seed([FIRST, SECOND])
	_activate()
	_native.apply_failure = {"ok": false, "code": &"reading_seek_stale"}
	var result: Dictionary = await _bridge.request_next(_proof())
	assert_false(result.ok)
	assert_true(result.fatal)
	assert_eq(result.code, &"reading_seek_stale")
	assert_true(_gate.is_fatal_latched())
	assert_eq(_port.persisted.reading_session.next_operation.phase, "destination")
	assert_eq(_bridge._reading_session.next_operation, _port.persisted.reading_session.next_operation)
	assert_eq(_port.completions, [])
