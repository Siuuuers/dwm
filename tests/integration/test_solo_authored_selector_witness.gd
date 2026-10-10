extends "res://addons/gut/test.gd"

## Authored noncanonical selector programmes cross the actual semantic ledger,
## Bridge acknowledgement and durable Profile transaction. Only native playback
## is replaced; this does not claim rendered or production-catalogue acceptance.
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const IDS := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const NEXT := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const PRE := "dating.solo.priscilla.day1.pre_challenge"
const POST := "dating.solo.priscilla.day1.post_challenge"
const PRE_A := "fixture.selector.pre.a"
const PRE_B := "fixture.selector.pre.b"
const POST_A := "fixture.selector.post.a"
const POST_B := "fixture.selector.post.b"

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
	var line_id := PRE_A
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
			"request_id": "authored-selector-fixture", "paused": false}}
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
	assert_true(_profile.initialize(STORAGE.new(wrapper.path_join("authored-selector-witness"), _files)).ok)
	_native = NativeFrontier.new()
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)
	assert_true(_bridge.initialize(null, _native).ok)
	assert_true(_bridge.configure_skip_context(_profile, &"read_only").ok)
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/dialogic/solo_authored_selector_catalogue.json"))
	assert_true(parsed.ok, str(parsed))
	_document = parsed.value

func _session() -> RefCounted:
	var session := SESSION.new()
	var configured: Dictionary = session.configure(_document)
	assert_true(configured.ok, str(configured))
	return session

func _context(entry_id: String, causal: String, tone: String = "sweet", perfect: bool = false) -> Dictionary:
	var phase := "pre_challenge" if entry_id == PRE else "post_challenge"
	var fields := {"entry_id": entry_id, "entry_role": "solo_" + phase, "day": 1,
		"friend_id": "priscilla", "tier": "friend", "tone": tone, "attitude": "",
		"run_id": causal + ":run", "branch_id": causal + ":branch",
		"challenge_slot": "dating.solo.priscilla.day1", "phase": phase,
		"due_echoes": [], "attempt_residue_id": null}
	if entry_id == POST:
		fields.merge({"attempt_id": causal + ":attempt", "board_result": "perfect" if perfect else "cleared",
			"perfect_reasons": ["no_flag"] if perfect else [],
			"relationship_outcome": "foresight" if perfect else "loved", "effect_receipt_id": causal + ":effect"})
	var frozen := FROZEN.build(entry_id, fields)
	assert_true(frozen.ok, str(frozen))
	return {"expected_stage": phase, "playback_id": causal + ":physical:" + phase,
		"role": "dating_phase", "transaction_id": causal + ":" + phase, "presentation": frozen.value}

func _publish(session: RefCounted, entry_id: String, line_id: String) -> Dictionary:
	var allocated: Dictionary = session.ledger.allocate_publication(session.command_id, entry_id)
	assert_true(allocated.ok, str(allocated))
	var published: Dictionary = session.ledger.publish_line(session.command_id, allocated.value, entry_id, line_id)
	assert_true(published.ok, str(published))
	return {"line_id": line_id, "publication_id": allocated.value}

func _mount(session: RefCounted, entry_id: String, frontier: Dictionary, causal: String) -> void:
	_native.line_id = frontier.line_id
	_native.publication = frontier.duplicate(true)
	_native.generation += 1
	_bridge._reading_session = session
	_bridge._active_entry = {"entry_id": entry_id, "token": causal + ":token",
		"stage": "pre_challenge" if entry_id == PRE else "post_challenge", "execution_mode": &"canonical"}

func _activate(causal: String, tone: String = "sweet", post: bool = false,
		perfect: bool = false, skip_allocation: bool = false) -> RefCounted:
	var session := _session()
	assert_true(session.begin(causal, PRE).ok)
	assert_true(session.admit(PRE, _context(PRE, causal, tone)).ok)
	var entry_id := PRE
	var line_id := PRE_A
	if post:
		_publish(session, PRE, PRE_A)
		_publish(session, PRE, PRE_B)
		session.completed(PRE)
		assert_true(session.admit(POST, _context(POST, causal, tone, perfect)).ok)
		entry_id = POST
		line_id = POST_A
	if skip_allocation:
		assert_true(session.ledger.allocate_publication(causal, entry_id).ok)
	_mount(session, entry_id, _publish(session, entry_id, line_id), causal)
	return session

func _proof() -> Dictionary:
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(proof.ok, str(proof))
	return proof

func _acknowledge() -> Dictionary:
	return _bridge.acknowledge_current_line_presentation(_proof())

func _text(session: RefCounted, frontier: Dictionary) -> String:
	var projected: Dictionary = session.project(frontier)
	assert_true(projected.ok, str(projected))
	return projected.value.captions.back().text

func test_changed_authored_tone_keeps_stable_identity_but_requires_an_exact_new_witness() -> void:
	var sweet := _activate("tone-sweet")
	var sweet_proof := _proof()
	var sweet_text := _text(sweet, _native.publication)
	assert_true(_acknowledge().ok)
	var revision: int = _profile.get_profile_revision()
	var dark := _activate("tone-dark", "dark")
	var dark_proof := _proof()
	assert_ne(_text(dark, _native.publication), sweet_text, "the admitted tone chooses genuinely different authored prose")
	assert_eq(dark_proof.value.caption_variant.line_id, PRE_A)
	assert_eq(dark_proof.value.caption_variant.beat_id, PRE_A)
	assert_eq(dark_proof.value.caption_variant.beat_id, sweet_proof.value.caption_variant.beat_id)
	assert_ne(dark_proof.value.caption_variant.presentation_signature, sweet_proof.value.caption_variant.presentation_signature)
	assert_eq(dark.entry_program(PRE).value.beats[1], sweet.entry_program(PRE).value.beats[1],
		"an unchanged caption does not inherit selectors belonging only to the opening")
	assert_true(_profile.is_line_visited(PRE_A), "the coarse stable line was already visited")
	assert_false(_profile.is_caption_variant_witnessed(dark_proof.value.caption_variant))
	var acknowledged := _acknowledge()
	assert_true(acknowledged.ok, str(acknowledged))
	assert_false(acknowledged.receipt.was_visited_before_presentation)
	assert_eq(_profile.get_profile_revision(), revision + 1)
	assert_eq(_profile.get_profile_snapshot().visited_line_ids, [PRE_A])
	assert_eq(_profile.get_profile_snapshot().witnessed_caption_variants.size(), 2)
	assert_false(_bridge.request_skip_step().value.advance, "the first activation retains its pre-write unseen baseline")
	assert_eq(_native.advances, 0)
	assert_true(_bridge.request_skip_step().value.advance)

func test_changed_causal_receipts_preserve_selected_variant_without_rewriting_profile() -> void:
	var first := _activate("causal-first", "dark", true, true)
	var first_proof := _proof()
	var first_text := _text(first, _native.publication)
	assert_true(_acknowledge().ok)
	var bytes: Dictionary = _files.snapshot_persisted()
	var revision: int = _profile.get_profile_revision()
	var second := _activate("causal-second", "dark", true, true, true)
	var second_proof := _proof()
	assert_ne(first.ledger.snapshot().entry_contexts[POST], second.ledger.snapshot().entry_contexts[POST])
	assert_ne(first_proof.value.token, second_proof.value.token)
	assert_ne(first_proof.value.caption_publication, second_proof.value.caption_publication)
	assert_eq(first_proof.value.caption_variant, second_proof.value.caption_variant)
	assert_eq(_text(second, _native.publication), first_text)
	var acknowledged := _acknowledge()
	assert_true(acknowledged.ok, str(acknowledged))
	assert_true(acknowledged.receipt.was_visited_before_presentation)
	assert_true(_bridge.request_skip_step().value.advance)
	assert_eq(_profile.get_profile_revision(), revision)
	assert_eq(_files.snapshot_persisted(), bytes)

func test_post_result_selects_different_prose_and_signature_at_the_same_stable_beat() -> void:
	var cleared := _activate("cleared", "sweet", true)
	var cleared_proof := _proof()
	var cleared_text := _text(cleared, _native.publication)
	assert_true(_acknowledge().ok)
	var perfect := _activate("perfect", "sweet", true, true)
	var perfect_proof := _proof()
	assert_ne(_text(perfect, _native.publication), cleared_text)
	assert_eq(perfect_proof.value.caption_variant.beat_id, POST_A)
	assert_eq(perfect_proof.value.caption_variant.line_id, cleared_proof.value.caption_variant.line_id)
	assert_ne(perfect_proof.value.caption_variant.presentation_signature, cleared_proof.value.caption_variant.presentation_signature)
	assert_true(_profile.is_line_visited(POST_A))
	assert_false(_profile.is_caption_variant_witnessed(perfect_proof.value.caption_variant))
	assert_false(_acknowledge().receipt.was_visited_before_presentation)
	assert_false(_bridge.request_skip_step().value.advance)

func test_phase_admission_freezes_only_available_facts_and_restores_one_ordered_history() -> void:
	var session := _session()
	assert_true(session.begin("phase-facts", PRE).ok)
	assert_true(session.ledger.snapshot().get("entry_contexts", {}).is_empty())
	assert_true(session.registry.is_empty(), "no selector-dependent beat is registered before a real frame")
	var pre_context := _context(PRE, "phase-facts")
	assert_true(session.admit(PRE, pre_context).ok)
	var first := _publish(session, PRE, PRE_A)
	var original_text := _text(session, first)
	_publish(session, PRE, PRE_B)
	session.completed(PRE)
	var board: Dictionary = session.capture({})
	assert_true(board.ok, str(board))
	assert_false(board.value.ledger.entry_contexts.has(POST), "no post-board frame exists before the committed result")
	assert_false(session.entry_program(POST).ok, "a future frame cannot choose an implicit programme")
	pre_context.presentation.fields.tone = "dark"
	var restored := _session()
	assert_true(restored.restore(board.value, PRE).ok)
	var post_context := _context(POST, "phase-facts", "dark", true)
	var missing_row := post_context.duplicate(true)
	missing_row.presentation.fields.tier = "ambiguous"
	assert_false(restored.admit(POST, missing_row).ok, "canonical facts without an authored row cannot choose a default")
	assert_eq(restored.capture({}).value, board.value)
	assert_false(restored.entry_program(POST).ok)
	assert_true(restored.admit(POST, post_context).ok)
	var post_frontier := _publish(restored, POST, POST_A)
	var original_post_text := _text(restored, post_frontier)
	post_context.presentation.fields.tone = "sweet"
	var history: Dictionary = restored.project(post_frontier)
	assert_true(history.ok, str(history))
	assert_eq(history.value.captions.size(), 3)
	assert_eq(history.value.captions[0].text, original_text)
	assert_eq(history.value.captions[0].line_id, PRE_A)
	assert_eq(history.value.captions[1].line_id, PRE_B)
	assert_eq(history.value.captions[2].line_id, POST_A)
	assert_eq(history.value.captions[2].text, original_post_text)
	assert_eq(restored.ledger.snapshot().entry_contexts[PRE].presentation.fields.tone, "sweet")
	assert_eq(restored.ledger.snapshot().entry_contexts[POST].presentation.fields.tone, "dark")
	assert_eq(restored.ledger.snapshot().entry_contexts[POST].presentation.fields.board_result, "perfect")
	assert_false(restored.admit(POST, post_context).ok, "later caller mutation cannot rebind the selected frame")
	var checkpoint: Dictionary = restored.capture(post_frontier).value
	assert_false(restored.admit(PRE, _context(PRE, "phase-facts")).ok, "a completed prior phase cannot replace the live post frame")
	assert_eq(restored.capture(post_frontier).value, checkpoint)
	var loaded := _session()
	assert_true(loaded.restore(checkpoint, POST).ok)
	assert_eq(loaded.capture(post_frontier).value, checkpoint)
	assert_eq(loaded.project(post_frontier).value, history.value)
	assert_eq(loaded.current_caption_variant(POST, post_frontier), restored.current_caption_variant(POST, post_frontier))

func test_next_queries_the_selected_variant_and_never_substitutes_a_coarse_visit() -> void:
	var sweet := _activate("next-sweet", "sweet", true)
	var witnessed := _publish(sweet, POST, POST_B)
	_mount(sweet, POST, witnessed, "next-sweet-tail")
	var sweet_proof := _proof()
	assert_true(_acknowledge().ok)
	var dark := _activate("next-dark", "dark", true)
	var frontier := _native.publication.duplicate(true)
	var before: Dictionary = dark.capture(frontier).value
	var profile_before: Dictionary = _files.snapshot_persisted()
	var programme: Dictionary = dark.entry_program(POST)
	assert_true(programme.ok, str(programme))
	var selected: Dictionary = programme.value.beats[1]
	assert_eq(selected.line_id, POST_B)
	assert_ne(selected.presentation_signature, sweet_proof.value.caption_variant.presentation_signature)
	assert_true(_profile.is_line_visited(POST_B))
	var queried: Array = []
	var planned: Dictionary = dark.prepare_next(frontier, func(beat: Dictionary) -> bool:
		queried.append(beat.duplicate(true))
		return _profile.is_caption_variant_witnessed(beat))
	assert_true(planned.ok, str(planned))
	assert_eq(queried, [selected])
	assert_eq(planned.value.traversed_captions, [])
	assert_eq(planned.value.destination.kind, "line")
	assert_eq(planned.value.destination.caption.beat, selected)
	assert_eq(dark.capture(frontier).value, before, "planning cannot replace the retained source")
	assert_eq(_files.snapshot_persisted(), profile_before, "planning is an exact-membership read")
	var destination: Dictionary = NEXT.project(planned.value, "destination")
	assert_true(destination.ok, str(destination))
	var loaded := _session()
	assert_true(loaded.restore(destination.value, POST).ok)
	assert_eq(loaded.project(destination.value.frontier).value.captions.back().text, programme.value.lines[1].text)
	assert_eq(loaded.current_caption_variant(POST, destination.value.frontier).value, selected)

func test_restore_rejects_known_alternate_signature_and_frame_mismatch_without_replacing_state() -> void:
	var sweet := _activate("restore-sweet")
	var saved: Dictionary = sweet.capture(_native.publication).value
	var sweet_frontier := _native.publication.duplicate(true)
	var dark := _activate("restore-dark", "dark")
	var alternate: Dictionary = dark.current_caption_variant(PRE, _native.publication).value
	var before: Dictionary = dark.capture(_native.publication).value
	var retained_frontier := _native.publication.duplicate(true)
	var forged := saved.duplicate(true)
	forged.ledger.captions[0].beat = alternate
	assert_false(dark.restore(forged, PRE).ok, "a genuinely authored alternate still conflicts with the retained sweet frame")
	assert_eq(dark.capture(retained_frontier).value, before)
	forged = saved.duplicate(true)
	forged.ledger.entry_contexts[PRE].presentation.fields.tone = "dark"
	assert_false(dark.restore(forged, PRE).ok, "a valid frozen frame must reselect the exact saved signature")
	assert_eq(dark.capture(retained_frontier).value, before)
	assert_true(dark.restore(saved, PRE).ok)
	assert_eq(dark.capture(sweet_frontier).value, saved)
	assert_eq(_text(dark, sweet_frontier), _text(sweet, sweet_frontier))

func test_next_restore_checks_unpublished_future_variant_against_the_admitted_frame() -> void:
	var sweet := _activate("future-sweet", "sweet", true)
	var sweet_programme: Dictionary = sweet.entry_program(POST).value
	var dark := _activate("future-dark", "dark", true)
	var frontier := _native.publication.duplicate(true)
	var before: Dictionary = dark.capture(frontier).value
	var planned: Dictionary = dark.prepare_next(frontier, func(_beat: Dictionary) -> bool: return false)
	assert_true(planned.ok, str(planned))
	var forged: Dictionary = planned.value.duplicate(true)
	forged.destination.caption.beat = sweet_programme.beats[1].duplicate(true)
	var source: Dictionary = NEXT.project(forged, "source")
	assert_true(source.ok, "the operation digest is valid; authored frame admission must reject the alternate future")
	assert_false(dark.restore(source.value, POST).ok)
	assert_eq(dark.capture(frontier).value, before)

func test_failed_profile_commit_and_explicit_retry_keep_selected_variant_unseen_baseline() -> void:
	_activate("retry-sweet")
	assert_true(_acknowledge().ok)
	assert_true(_profile.set_preference(&"preferences.reading.auto_enabled", true).ok)
	_activate("retry-dark", "dark")
	var proof := _proof()
	var before: Dictionary = _profile.get_profile_snapshot()
	var bytes: Dictionary = _files.snapshot_persisted()
	_files.reject_next_marker = true
	var failed: Dictionary = _bridge.acknowledge_current_line_presentation(proof)
	assert_false(failed.ok)
	assert_eq(failed.code, &"write_not_committed")
	assert_false(failed.get("fatal", false))
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_files.snapshot_persisted(), bytes)
	assert_false(_profile.is_caption_variant_witnessed(proof.value.caption_variant))
	assert_false(_bridge.can_auto_advance_current_line())
	assert_false(_bridge.request_auto_step(proof).ok)
	assert_eq(_files.snapshot_persisted(), bytes, "an automatic gate cannot retry the failed transaction")
	var retried: Dictionary = _bridge.request_skip_step()
	assert_true(retried.ok, str(retried))
	assert_false(retried.value.advance)
	assert_false(retried.receipt.was_visited_before_reveal)
	assert_true(_profile.is_caption_variant_witnessed(proof.value.caption_variant))
	assert_eq(_profile.get_profile_snapshot().witnessed_caption_variants.size(), 2)
	assert_eq(_native.advances, 0)

func test_reveal_callback_cannot_reclassify_the_selected_unseen_variant_as_previously_seen() -> void:
	_activate("callback-sweet")
	assert_true(_acknowledge().ok)
	var dark := _activate("callback-dark", "dark")
	var proof := _proof()
	_native.reveal_callback = func() -> void:
		assert_true(_profile.mark_caption_variant_witnessed(proof.value.caption_variant, dark.registry).ok)
	var result: Dictionary = _bridge.request_skip_step()
	assert_true(result.ok, str(result))
	assert_false(result.value.advance)
	assert_false(result.receipt.was_visited_before_reveal)
	assert_eq(_native.advances, 0)
