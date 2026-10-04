extends "res://addons/gut/test.gd"

## Real Bridge admission, caption ledger and Profile; only the native playhead is
## replaced. Explicit TEST copy is noncanonical. This proves collection contracts,
## not mounted visibility, production admission, or durable History merging.
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const ENTRY := "ending.alone.normal"
const FIRST := "fixture.gallery.collect.first"
const SECOND := "fixture.gallery.collect.second"
const OTHER := "fixture.gallery.collect.other"

class NativeFrontier extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	signal playback_start_failed(failure: Dictionary)
	signal caption_publication_recorded(result: Dictionary)
	var _caption_ledger: RefCounted
	var token := ""
	var entry := ""
	var publication: Dictionary = {}
	var line_id := ""
	var generation := 0
	var active := false
	var reject_start := false
	var reject_programme := false
	var advances := 0
	var retain_layout := false
	var frozen_fields: Dictionary = {}
	var validated_lines: Array = []
	func validate_reading_entry(_path: String, _label: String, lines: Array) -> Dictionary:
		validated_lines = lines.duplicate(true)
		return {"ok": false, "code": &"fixture_programme_mismatch"} if reject_programme else {"ok": true}
	func bind_caption_ledger(owner: RefCounted, session: String, entry_id: String, retain: bool = false) -> Dictionary:
		if _caption_ledger != null: return {"ok": false, "code": &"fixture_binding_busy"}
		_caption_ledger = owner
		token = session
		entry = entry_id
		retain_layout = retain
		return {"ok": true}
	func _retire_caption_binding() -> void:
		_caption_ledger = null
		token = ""
		entry = ""
		publication = {}
		line_id = ""
	func install_frozen_replay(signature: Dictionary, mode: String) -> Dictionary:
		var built := preload("res://scripts/narrative/FrozenReplayContext.gd").immutable_fields(signature, mode)
		if not built.ok: return built
		frozen_fields = built.value
		return {"ok": true}
	func release_frozen_presentation() -> void: frozen_fields = {}
	func start_timeline(_path: String, _label: Variant = 0) -> Dictionary:
		generation += 1
		if reject_start: return {"ok": false, "code": &"fixture_start_refused"}
		active = true
		return {"ok": true}
	func has_active_playback() -> bool: return active
	func current_line_id() -> String: return line_id
	func is_current_line_complete() -> bool: return true
	func capture_reading_frontier() -> Dictionary:
		return {"ok": true, "value": publication.duplicate(true)}
	func capture_pause_frontier() -> Dictionary:
		return {"ok": true, "value": {"generation": generation, "event_index": 0,
			"request_id": "gallery-collection-test", "paused": false}}
	func classify_next_event() -> StringName: return &"text"
	func advance_one_event() -> Dictionary:
		advances += 1
		return {"ok": true}
	func halt_with_error(_failure: Dictionary) -> Dictionary:
		active = false
		_retire_caption_binding()
		release_frozen_presentation()
		return {"ok": true}
	func finish() -> void:
		active = false
		_retire_caption_binding()
		release_frozen_presentation()
		timeline_ended_signal.emit()
	func publish(identity: String) -> Dictionary:
		if _caption_ledger == null: return {"ok": false, "code": &"fixture_unbound"}
		var allocated: Dictionary = _caption_ledger.allocate_publication(token, entry)
		if not allocated.ok: return allocated
		line_id = identity
		publication = {"line_id": identity, "publication_id": allocated.value}
		var result: Dictionary = _caption_ledger.publish_line(token, allocated.value, entry, identity)
		caption_publication_recorded.emit(result)
		return result

var _bridge: Node
var _profile: Node
var _native: NativeFrontier
var _files: RefCounted
var _document: Dictionary
var _identity := ""

func before_each() -> void:
	var wrapper := OS.get_environment("DWM_TEST_ROOT").strip_edges()
	assert_false(wrapper.is_empty(), "cloud wrapper owns isolated storage")
	_files = FILES.new()
	_profile = autofree(MANAGER.new())
	assert_true(_profile.initialize(STORAGE.new(wrapper.path_join("gallery-caption-collection"), _files)).ok)
	_native = NativeFrontier.new()
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)
	assert_true(_bridge.initialize(null, _native).ok)
	assert_true(_bridge.configure_reached_replay(_profile).ok)
	assert_true(_bridge.configure_skip_context(_profile, &"read_only").ok)
	_document = {"kind": "ending_reading_catalogue", "schema_version": 1, "entries": [
		{"entry_id": ENTRY, "content_version": 1, "lines": [_line(FIRST), _line(SECOND)]},
		{"entry_id": "ending.alone.dark_mode", "content_version": 1, "lines": [_line(OTHER)]}]}
	var reached: Dictionary = _profile.record_reached_presentation(_signature())
	assert_true(reached.ok, str(reached))
	_identity = str(reached.value.signature_id)
	assert_true(_profile.unlock_ending("ending.alone", "fixture:gallery-collection").ok)

func _line(identity: String) -> Dictionary:
	return {"beat_id": identity, "line_id": identity, "revision": "TEST-gallery-collection-v1",
		"text": "TEST noncanonical Gallery collection caption: " + identity}

func _signature() -> Dictionary:
	return {"entry_id": ENTRY, "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": "alone_normal"}}

func _admissions() -> Array[Dictionary]:
	var lines: Array[String] = [FIRST]
	return [{"signature": _signature(), "collectable_line_ids": lines}]

func _configure() -> void:
	var admitted: Dictionary = _bridge.configure_reached_caption_collection(_document, _admissions())
	assert_true(admitted.ok, str(admitted))

func _start() -> void:
	var started: Dictionary = _bridge.replay_reached_signature(_identity)
	assert_true(started.ok, str(started))
	assert_not_null(_native._caption_ledger)
	assert_false(_native.retain_layout, "Gallery does not retain a canonical ending handoff")

func _proof() -> Dictionary:
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(proof.ok, str(proof))
	return proof

func _captions() -> Array:
	var captured: Dictionary = _bridge.capture_reached_caption_collection()
	assert_true(captured.ok, str(captured))
	return captured.get("value", {}).get("captions", [])

func test_exact_admission_is_opt_in_and_invalid_declarations_never_partially_admit() -> void:
	var malformed: Array[Dictionary] = []
	var missing := _admissions()[0].duplicate(true)
	missing.erase("collectable_line_ids")
	malformed.append(missing)
	var unknown := _admissions()[0].duplicate(true)
	unknown.collectable_line_ids = ["fixture.gallery.unknown"]
	malformed.append(unknown)
	var foreign := _admissions()[0].duplicate(true)
	foreign.collectable_line_ids = [OTHER]
	malformed.append(foreign)
	var duplicate := _admissions()[0].duplicate(true)
	duplicate.collectable_line_ids = [FIRST, FIRST]
	malformed.append(duplicate)
	var wrong_type := _admissions()[0].duplicate(true)
	wrong_type.collectable_line_ids = [17]
	malformed.append(wrong_type)
	var extra := _admissions()[0].duplicate(true)
	extra.implicit_all = true
	malformed.append(extra)
	var bad_signature := _admissions()[0].duplicate(true)
	bad_signature.signature.fields.unproved_cause = "TEST"
	malformed.append(bad_signature)
	var undeclared := _admissions()[0].duplicate(true)
	undeclared.signature.entry_id = "fixture.unregistered.entry"
	malformed.append(undeclared)
	for invalid: Dictionary in malformed:
		var admissions: Array[Dictionary] = [invalid]
		assert_false(_bridge.configure_reached_caption_collection(_document, admissions).ok)
	var late_invalid := _admissions()[0].duplicate(true)
	late_invalid.signature.fields.ending_role = "primary"
	late_invalid.collectable_line_ids = [OTHER]
	var prefix: Array[Dictionary] = [_admissions()[0], late_invalid]
	assert_false(_bridge.configure_reached_caption_collection(_document, prefix).ok)
	assert_true(_bridge.replay_reached_signature(_identity).ok)
	assert_null(_native._caption_ledger, "no prefix of a refused declaration becomes an admission")
	assert_false(_bridge.capture_reached_caption_collection().ok)
	assert_true(_bridge.cancel_reached_replay(_identity).ok)
	_configure()
	_start()

func test_other_signature_of_same_entry_stays_legacy_and_admission_inputs_are_detached() -> void:
	var admissions := _admissions()
	assert_true(_bridge.configure_reached_caption_collection(_document, admissions).ok)
	admissions[0].signature.fields.ending_role = "primary"
	admissions[0].collectable_line_ids.clear()
	_document.entries[0].lines[0].revision = "tampered"
	var other: Dictionary = _profile.record_reached_presentation(admissions[0].signature)
	assert_true(other.ok, str(other))
	assert_true(_bridge.replay_reached_signature(other.value.signature_id).ok)
	assert_null(_native._caption_ledger, "same semantic entry does not admit another reached signature")
	assert_false(_bridge.capture_reached_caption_collection().ok)
	assert_true(_bridge.cancel_reached_replay(other.value.signature_id).ok)
	_start()
	assert_true(_native.publish(FIRST).ok)
	var proof := _proof()
	assert_eq(proof.value.caption_variant.presentation_signature.content_revision, "TEST-gallery-collection-v1")
	assert_true(_bridge.acknowledge_current_line_presentation(proof).ok)
	assert_eq(_captions(), [proof.value.caption_variant])

func test_fixed_programme_version_mismatch_refuses_start_without_binding() -> void:
	var changed := _document.duplicate(true)
	changed.entries[0].content_version = 999
	assert_true(_bridge.configure_reached_caption_collection(changed, _admissions()).ok)
	assert_false(_bridge.replay_reached_signature(_identity).ok)
	assert_null(_native._caption_ledger)
	assert_false(_bridge.capture_reached_caption_collection().ok)
	assert_false(_bridge.has_active_playback())

func test_runtime_programme_validation_precedes_caption_binding() -> void:
	_configure()
	_native.reject_programme = true
	assert_false(_bridge.replay_reached_signature(_identity).ok)
	assert_null(_native._caption_ledger)
	assert_false(_bridge.capture_reached_caption_collection().ok)
	assert_false(_bridge.has_active_playback())
	_native.reject_programme = false
	_start()
	assert_eq(_native.validated_lines, _document.entries[0].lines)

func test_publication_is_not_acknowledgement_and_snapshot_is_detached_exact_session() -> void:
	_configure()
	_start()
	assert_true(_native.publish(FIRST).ok)
	assert_eq(_captions(), [])
	assert_true(_bridge.requires_line_presentation_acknowledgement())
	assert_false(_bridge.is_current_line_presentation_acknowledged())
	var proof := _proof()
	assert_eq(_captions(), [], "frontier inspection cannot collect")
	assert_true(_bridge.acknowledge_current_line_presentation(proof).ok)
	assert_true(_bridge.is_current_line_presentation_acknowledged())
	var snapshot: Dictionary = _bridge.capture_reached_caption_collection()
	assert_eq(snapshot.value.signature_id, _identity)
	assert_eq(snapshot.value.playback_token, _native.token)
	assert_eq(snapshot.value.captions, [proof.value.caption_variant])
	snapshot.value.captions[0].line_id = "tampered"
	snapshot.value.captions.clear()
	snapshot.value.signature_id = "tampered"
	assert_eq(_captions(), [proof.value.caption_variant])

func test_duplicate_acknowledgements_and_repeated_occurrences_collect_once() -> void:
	_configure()
	_start()
	assert_true(_native.publish(FIRST).ok)
	var proof := _proof()
	var first: Dictionary = _bridge.acknowledge_current_line_presentation(proof)
	assert_true(first.ok, str(first))
	assert_eq(_bridge.acknowledge_current_line_presentation(proof), first)
	assert_true(_native.publish(FIRST).ok)
	var repeated := _proof()
	assert_ne(proof.value.caption_publication, repeated.value.caption_publication)
	assert_true(_bridge.acknowledge_current_line_presentation(repeated).ok)
	assert_eq(_captions(), [proof.value.caption_variant])

func test_stale_occurrence_and_previous_session_proofs_cannot_collect() -> void:
	_configure()
	_start()
	assert_true(_native.publish(FIRST).ok)
	var old := _proof()
	assert_true(_native.publish(SECOND).ok)
	assert_false(_bridge.acknowledge_current_line_presentation(old).ok)
	assert_eq(_captions(), [])
	assert_true(_bridge.cancel_reached_replay(_identity).ok)
	assert_false(_bridge.capture_reached_caption_collection().ok)
	_start()
	assert_true(_native.publish(FIRST).ok)
	var replacement := _proof()
	assert_ne(replacement.value.token, old.value.token)
	assert_false(_bridge.acknowledge_current_line_presentation(old).ok)
	assert_eq(_captions(), [])
	assert_true(_bridge.acknowledge_current_line_presentation(replacement).ok)
	assert_eq(_captions(), [replacement.value.caption_variant])

func test_noncollectable_caption_can_be_acknowledged_but_unknown_source_cannot_collect() -> void:
	_configure()
	_start()
	assert_true(_native.publish(SECOND).ok)
	assert_true(_bridge.acknowledge_current_line_presentation(_proof()).ok)
	assert_true(_bridge.is_current_line_presentation_acknowledged())
	assert_eq(_captions(), [])
	_native.line_id = "fixture.gallery.unknown"
	_native.publication = {"line_id": _native.line_id, "publication_id": "unregistered"}
	assert_false(_bridge.capture_current_line_presentation_frontier().ok)
	assert_false(_bridge.acknowledge_current_line_presentation({"ok": true, "value": {}}).ok)
	assert_eq(_captions(), [])

func test_collection_and_completion_preserve_profile_variables_and_canonical_capabilities() -> void:
	_configure()
	var before: Dictionary = _profile.get_profile_snapshot()
	var persisted: Dictionary = _files.snapshot_persisted()
	var revision: int = _profile.get_profile_revision()
	var dialogic := get_node_or_null("/root/Dialogic")
	var variables: Dictionary = dialogic.current_state_info.get("variables", {}).duplicate(true)
	var canonical_counter: int = _bridge._playback_counter
	watch_signals(_bridge)
	_start()
	assert_true(_native.publish(FIRST).ok)
	assert_true(_bridge.acknowledge_current_line_presentation(_proof()).ok)
	assert_false(_bridge.has_reading_session())
	assert_false(_bridge.can_capture_reading_checkpoint())
	assert_false(_bridge.capture_reading_checkpoint().ok)
	assert_false(_bridge.can_next_current_line())
	assert_false(_bridge.can_skip_current_line())
	assert_eq(_bridge.request_skip_step().get("code"), &"rehearsal_commit_denied")
	assert_eq(_bridge.acknowledge_signal("history.line.witness", {}).get("code"), &"rehearsal_commit_denied")
	assert_false(_native.frozen_fields.has("step_token"))
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_files.snapshot_persisted(), persisted)
	assert_eq(_profile.get_profile_revision(), revision)
	_native.finish()
	assert_false(_bridge.capture_reached_caption_collection().ok)
	assert_false(_bridge.has_active_playback())
	assert_null(_native._caption_ledger)
	assert_eq(_profile.get_profile_snapshot(), before, "completion discards; this increment never merges")
	assert_eq(_files.snapshot_persisted(), persisted)
	assert_eq(_profile.get_profile_revision(), revision)
	assert_eq(dialogic.current_state_info.get("variables", {}), variables)
	assert_eq(_bridge._playback_counter, canonical_counter)
	assert_eq(_native.advances, 0)
	assert_signal_emit_count(_bridge, "timeline_failed", 0)

func test_start_and_publication_failures_discard_binding_and_allow_fresh_replay() -> void:
	_configure()
	var before: Dictionary = _profile.get_profile_snapshot()
	var persisted: Dictionary = _files.snapshot_persisted()
	_native.reject_start = true
	assert_false(_bridge.replay_reached_signature(_identity).ok)
	assert_null(_native._caption_ledger)
	assert_true(_native.frozen_fields.is_empty())
	assert_false(_bridge.capture_reached_caption_collection().ok)
	_native.reject_start = false
	_start()
	assert_true(_native.publish(FIRST).ok)
	assert_true(_bridge.acknowledge_current_line_presentation(_proof()).ok)
	watch_signals(_bridge)
	assert_false(_native.publish("fixture.gallery.unknown").ok)
	assert_false(_bridge.has_active_playback())
	assert_null(_native._caption_ledger)
	assert_true(_native.frozen_fields.is_empty())
	assert_false(_bridge.capture_reached_caption_collection().ok)
	assert_signal_emit_count(_bridge, "timeline_failed", 0, "Gallery failure stays out of canonical recovery")
	_start()
	assert_eq(_captions(), [], "failed session collection cannot leak into a retry")
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_files.snapshot_persisted(), persisted)

func test_replay_teardown_preserves_a_replaced_runtime_caption_binding() -> void:
	_configure()
	_start()
	var foreign := preload("res://scripts/narrative/NarrativeCaptionLedger.gd").new()
	_native._caption_ledger = foreign
	# Runtime replacement reports failure after installing its own owner. The old
	# Gallery cleanup must not retire that foreign binding; no collection is forged.
	_native.active = false
	_native.playback_start_failed.emit({"ok": false, "code": &"runtime_playback_replaced"})
	assert_same(_native._caption_ledger, foreign)
	assert_false(_bridge.capture_reached_caption_collection().ok)
	assert_false(_bridge.has_active_playback())
