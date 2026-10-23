extends "res://addons/gut/test.gd"

## Real registered Solo occurrences and Profile transactions, with only the native
## playhead replaced. Physical mounted/fresh-process evidence lives in the journey.
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const IDS := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const PRE := "dating.solo.priscilla.day1.pre_challenge"
const POST := "dating.solo.priscilla.day1.post_challenge"
const LINE := "fixture.solo.pre.a"

class RetryableFiles extends "res://tests/support/FakeFileOps.gd":
	var reject_next_marker := false
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if reject_next_marker and path.replace("\\", "/").ends_with("/profile.json.txn.json"):
			reject_next_marker = false
			return {"ok": false, "code": &"fixture_marker_refusal"}
		return super.write_bytes(path, bytes)

class NativeFrontier extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	var line_id := LINE
	var publication: Dictionary = {}
	var generation := 1
	var advances := 0
	var reveal_callback := Callable()
	func start_timeline(_path: String, _event_index: Variant = 0) -> Dictionary: return {"ok": true}
	func current_line_id() -> String: return line_id
	func is_current_line_complete() -> bool: return true
	func capture_reading_frontier() -> Dictionary: return {"ok": true, "value": publication.duplicate(true)}
	func capture_pause_frontier() -> Dictionary:
		return {"ok": true, "value": {"generation": generation, "event_index": 0,
			"request_id": "variant-fixture", "paused": false}}
	func reveal_current_line(_preserve_boundary: bool = false) -> Dictionary:
		var callback := reveal_callback
		reveal_callback = Callable()
		if callback.is_valid(): callback.call()
		return {"ok": true}
	func classify_next_event() -> StringName: return &"text"
	func advance_one_event() -> Dictionary:
		advances += 1
		return {"ok": true}
	func halt_with_error(_failure: Dictionary) -> Dictionary: return {"ok": false}

var _bridge: Node
var _profile: Node
var _native: NativeFrontier
var _files: RetryableFiles
var _document: Dictionary

func before_each() -> void:
	var wrapper := OS.get_environment("DWM_TEST_ROOT").strip_edges()
	assert_false(wrapper.is_empty(), "cloud wrapper owns the isolated storage root")
	_files = RetryableFiles.new()
	_profile = autofree(MANAGER.new())
	var ids := IDS.load_ids_default()
	assert_true(ids.ok, str(ids))
	assert_true(_profile.configure_line_registry(ids.value).ok)
	assert_true(_profile.initialize(STORAGE.new(wrapper.path_join("caption-variant-bridge"), _files)).ok)
	_native = NativeFrontier.new()
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)
	assert_true(_bridge.initialize(null, _native).ok)
	assert_true(_bridge.configure_skip_context(_profile, &"read_only").ok)
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/dialogic/solo_reading_rail_catalogue.json"))
	assert_true(parsed.ok, str(parsed))
	_document = parsed.value

func _context(entry_id: String, causal: String) -> Dictionary:
	var phase := "pre_challenge" if entry_id == PRE else "post_challenge"
	var fields := {"entry_id": entry_id, "entry_role": "solo_" + phase, "day": 1,
		"friend_id": "priscilla", "tier": "friend", "tone": "sweet", "attitude": "",
		"run_id": causal + ":run", "branch_id": causal + ":branch",
		"challenge_slot": "dating.solo.priscilla.day1", "phase": phase,
		"due_echoes": [], "attempt_residue_id": null}
	if entry_id == POST:
		fields.merge({"attempt_id": causal + ":attempt", "board_result": "cleared",
			"perfect_reasons": [], "relationship_outcome": "loved", "effect_receipt_id": causal + ":effect"})
	var frozen := FROZEN.build(entry_id, fields)
	assert_true(frozen.ok, str(frozen))
	return {"expected_stage": phase, "playback_id": causal + ":physical:" + phase,
		"role": "dating_phase", "transaction_id": causal + ":" + phase, "presentation": frozen.value}

func _publish(session: RefCounted, entry_id: String, line_id: String) -> Dictionary:
	var allocated: Dictionary = session.ledger.allocate_publication(session.command_id, entry_id)
	assert_true(allocated.ok, str(allocated))
	assert_true(session.ledger.publish_line(session.command_id, allocated.value, entry_id, line_id).ok)
	return {"line_id": line_id, "publication_id": allocated.value}

func _activate(document: Dictionary, causal: String, entry_id: String = PRE, publish: bool = true) -> RefCounted:
	var session := SESSION.new()
	assert_true(session.configure(document).ok)
	assert_true(session.begin(causal, PRE).ok)
	assert_true(session.admit(PRE, _context(PRE, causal)).ok)
	if entry_id == POST:
		_publish(session, PRE, LINE)
		_publish(session, PRE, "fixture.solo.pre.b")
		session.completed(PRE)
		assert_true(session.admit(POST, _context(POST, causal)).ok)
	_native.line_id = LINE if entry_id == PRE else "fixture.solo.post.a"
	_native.publication = _publish(session, entry_id, _native.line_id) if publish else {}
	_native.generation += 1
	_bridge._reading_session = session
	_bridge._active_entry = {"entry_id": entry_id, "token": causal + ":token",
		"stage": "pre_challenge" if entry_id == PRE else "post_challenge", "execution_mode": &"canonical"}
	return session

func _acknowledge() -> Dictionary:
	var frontier: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(frontier.get("ok", false), str(frontier))
	return _bridge.acknowledge_current_line_presentation(frontier)

func test_registered_visible_acknowledgement_writes_exact_and_base_once_then_read_only_stops() -> void:
	_activate(_document, "first")
	var before: Dictionary = _profile.get_profile_snapshot()
	var revision: int = _profile.get_profile_revision()
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(proof.ok, str(proof))
	assert_true(_bridge.requires_line_presentation_acknowledgement())
	assert_true(_bridge.can_skip_current_line())
	assert_false(_bridge._skip_line_owners.has(LINE), "fixture IDs never enter the production coarse registry")
	assert_eq(_profile.get_profile_snapshot(), before, "registration and frontier capture do not witness")
	var acknowledged: Dictionary = _bridge.acknowledge_current_line_presentation(proof)
	assert_true(acknowledged.ok, str(acknowledged))
	assert_false(acknowledged.receipt.was_visited_before_presentation)
	assert_true(_profile.is_line_visited(LINE))
	assert_true(_profile.is_caption_variant_witnessed(proof.value.caption_variant))
	assert_eq(_profile.get_profile_revision(), revision + 1, "base and exact history commit atomically")
	var bytes: Dictionary = _files.snapshot_persisted()
	assert_eq(_bridge.acknowledge_current_line_presentation(proof), acknowledged)
	assert_eq(_files.snapshot_persisted(), bytes)
	assert_eq(_profile.get_profile_revision(), revision + 1)
	var stopped: Dictionary = _bridge.request_skip_step()
	assert_true(stopped.ok, str(stopped))
	assert_false(stopped.value.advance, "the first held activation uses the pre-write unseen baseline")
	assert_eq(_native.advances, 0)
	assert_true(_bridge.request_skip_step().value.advance, "a later deliberate activation may continue")
	assert_eq(_native.advances, 1)

func test_causal_run_branch_attempt_and_publication_changes_do_not_create_another_variant() -> void:
	var first := _activate(_document, "causal-a", POST)
	var original: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(_acknowledge().ok)
	var bytes: Dictionary = _files.snapshot_persisted()
	var revision: int = _profile.get_profile_revision()
	var second := _activate(_document, "causal-b", POST, false)
	assert_true(second.ledger.allocate_publication(second.command_id, POST).ok)
	_native.publication = _publish(second, POST, "fixture.solo.post.a")
	var repeated: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_ne(first.ledger.snapshot().entry_contexts[POST], second.ledger.snapshot().entry_contexts[POST])
	assert_ne(original.value.token, repeated.value.token)
	assert_ne(original.value.caption_publication, repeated.value.caption_publication)
	assert_eq(original.value.caption_variant, repeated.value.caption_variant)
	var acknowledged := _acknowledge()
	assert_true(acknowledged.ok, str(acknowledged))
	assert_true(acknowledged.receipt.was_visited_before_presentation)
	assert_true(_bridge.request_skip_step().value.advance)
	assert_eq(_files.snapshot_persisted(), bytes, "duplicate exact witness does not rewrite durable Profile")
	assert_eq(_profile.get_profile_revision(), revision)
	assert_eq(_profile.get_profile_snapshot().witnessed_caption_variants.size(), 1)

func test_same_stable_line_with_another_variant_or_revision_starts_unseen() -> void:
	_activate(_document, "variant-a")
	assert_true(_acknowledge().ok)
	for change: String in ["beat_id", "revision"]:
		var changed := _document.duplicate(true)
		changed.entries[0].lines[0][change] = "alternate-" + change
		_activate(changed, change)
		var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
		assert_true(_profile.is_line_visited(LINE), "coarse history cannot stand in for this exact variant")
		assert_false(_profile.is_caption_variant_witnessed(proof.value.caption_variant))
		var acknowledged := _acknowledge()
		assert_true(acknowledged.ok, str(acknowledged))
		assert_false(acknowledged.receipt.was_visited_before_presentation)
		assert_false(_bridge.request_skip_step().value.advance)
	assert_eq(_profile.get_profile_snapshot().witnessed_caption_variants.size(), 3)
	assert_eq(_profile.get_profile_snapshot().visited_line_ids, [LINE])

func test_unpublished_or_stale_semantic_occurrence_never_falls_back_to_coarse_witness() -> void:
	var session := _activate(_document, "unpublished", PRE, false)
	var before: Dictionary = _profile.get_profile_snapshot()
	assert_true(_bridge.requires_line_presentation_acknowledgement())
	assert_false(_bridge.can_skip_current_line())
	assert_false(_bridge.capture_current_line_presentation_frontier().ok)
	assert_false(_bridge.request_skip_step().ok)
	_native.publication = _publish(session, PRE, LINE)
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(proof.ok, str(proof))
	_native.publication.publication_id = "unpublished-replacement"
	assert_false(_bridge.acknowledge_current_line_presentation(proof).ok)
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_native.advances, 0)

func test_recoverable_profile_write_failure_preserves_exact_baseline_for_explicit_retry() -> void:
	assert_true(_profile.set_preference(&"preferences.reading.auto_enabled", true).ok)
	_activate(_document, "retry")
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	var before: Dictionary = _profile.get_profile_snapshot()
	var bytes: Dictionary = _files.snapshot_persisted()
	_files.reject_next_marker = true
	var failed: Dictionary = _bridge.acknowledge_current_line_presentation(proof)
	assert_false(failed.ok)
	assert_eq(failed.code, &"write_not_committed")
	assert_false(failed.get("fatal", false))
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_files.snapshot_persisted(), bytes)
	assert_false(_bridge.is_current_line_presentation_acknowledged())
	assert_false(_bridge.can_auto_advance_current_line())
	assert_false(_bridge.request_auto_step(proof).ok)
	assert_eq(_profile.get_profile_snapshot(), before, "automatic gates never retry the failed write")
	var retried: Dictionary = _bridge.request_skip_step()
	assert_true(retried.ok, str(retried))
	assert_false(retried.value.advance)
	assert_false(retried.receipt.was_visited_before_reveal)
	assert_true(_bridge.is_current_line_presentation_acknowledged())
	assert_eq(_profile.get_profile_snapshot().witnessed_caption_variants.size(), 1)
	assert_eq(_native.advances, 0)

func test_synchronous_exact_publication_blocks_reentrant_commands_and_rejects_replaced_source() -> void:
	_activate(_document, "reentrant")
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	var nested: Array[Dictionary] = []
	_profile.caption_variant_witness_changed.connect(func(_id: String, _witnessed: bool) -> void:
		nested.append(_bridge.acknowledge_current_line_presentation(proof))
		nested.append(_bridge.request_skip_step())
		_bridge._active_entry.token = "replacement-token")
	var result: Dictionary = _bridge.acknowledge_current_line_presentation(proof)
	assert_false(result.ok)
	assert_eq(result.code, &"presentation_frontier_changed")
	assert_eq(nested.size(), 2)
	for refusal: Dictionary in nested:
		assert_false(refusal.ok)
		assert_eq(refusal.code, &"presentation_acknowledgement_in_progress")
	assert_true(_profile.is_caption_variant_witnessed(proof.value.caption_variant), "only the accepted old source committed")
	assert_false(_bridge.is_current_line_presentation_acknowledged())
	assert_eq(_native.advances, 0)

func test_reveal_callback_cannot_turn_a_fresh_exact_variant_into_previously_seen_text() -> void:
	var session := _activate(_document, "before-reveal")
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	_native.reveal_callback = func() -> void:
		assert_true(_profile.mark_caption_variant_witnessed(proof.value.caption_variant, session.registry).ok)
	var result: Dictionary = _bridge.request_skip_step()
	assert_true(result.ok, str(result))
	assert_false(result.value.advance)
	assert_false(result.receipt.was_visited_before_reveal)
	assert_eq(_native.advances, 0)
