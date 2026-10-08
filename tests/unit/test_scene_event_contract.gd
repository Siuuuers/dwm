extends "res://addons/gut/test.gd"
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const FIXTURE := preload("res://tests/support/SceneEventFixture.gd")

func test_all_nine_registered_kinds_have_narrow_fixture_payloads() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var kinds := {}
	for event: Dictionary in fixture.events:
		assert_true(CONTRACT.inspect(event).ok, event.kind)
		assert_true(CONTRACT.match_registration(event, fixture.registrations[event.event_id]).ok)
		kinds[event.kind] = true
	assert_eq(kinds.size(), 9)

func test_token_is_ephemeral_but_payload_and_source_are_semantic() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var event: Dictionary = fixture.event_at(0)
	var first: Dictionary = CONTRACT.inspect(event)
	event.playback_token = "TEST.next.process"
	assert_eq(CONTRACT.inspect(event).value, first.value)
	event.payload.scene_id = "TEST.other"
	assert_ne(CONTRACT.inspect(event).value.digest, first.value.digest)
	event = fixture.event_at(0)
	event.source.scene_occurrence = "TEST.other"
	assert_ne(CONTRACT.inspect(event).value.digest, first.value.digest)

func test_closed_envelope_rejects_malformed_values_without_throwing() -> void:
	var fixture: RefCounted = FIXTURE.new()
	for value: Variant in [null, [], "event", {}, 1]: assert_false(CONTRACT.inspect(value).ok)
	for key: String in CONTRACT.ENVELOPE_KEYS:
		var missing: Dictionary = fixture.event_at(0)
		missing.erase(key)
		assert_false(CONTRACT.inspect(missing).ok, key)
	var cases := {"schema_version": 1.0, "source": [], "event_id": "res://bad.gd", "ordinal": -1,
		"predecessor": null, "kind": "unregistered", "payload": {}, "command_id": "", "issuer_receipt": [], "playback_token": ""}
	for key: String in cases:
		var invalid: Dictionary = fixture.event_at(0)
		invalid[key] = cases[key]
		assert_false(CONTRACT.inspect(invalid).ok, key)
	var extra: Dictionary = fixture.event_at(0)
	extra.raw_signal = true
	assert_false(CONTRACT.inspect(extra).ok)

func test_source_and_payload_types_are_strict_and_no_paths_are_commands() -> void:
	var fixture: RefCounted = FIXTURE.new()
	for key: String in CONTRACT.SOURCE_KEYS:
		var bad: Dictionary = fixture.event_at(0)
		bad.source[key] = 1.0
		assert_false(CONTRACT.inspect(bad).ok, key)
	for event: Dictionary in fixture.events:
		for key: String in event.payload:
			var bad: Dictionary = event.duplicate(true)
			bad.payload[key] = []
			assert_false(CONTRACT.inspect(bad).ok, event.kind + key)
		var extra: Dictionary = event.duplicate(true)
		extra.payload.raw_path = "res://evil.gd"
		assert_false(CONTRACT.inspect(extra).ok)

func test_day_bounds_and_parameter_dictionary_are_closed_primitives() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var day: Dictionary = fixture.event_at(3)
	for value: Variant in [0, 8, 1.0, true, "1"]:
		day.payload.target_day = value
		assert_false(CONTRACT.inspect(day).ok)
	var notice: Dictionary = fixture.event_at(6)
	for value: Variant in [[], {"nested": {}}, {"object": RefCounted.new()}, {1: "wrong key"}]:
		notice.payload.parameters = value
		assert_false(CONTRACT.inspect(notice).ok)

func test_registration_matches_whole_payload_identity_and_predecessor() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var event: Dictionary = fixture.event_at(0)
	assert_false(CONTRACT.match_registration(event, null).ok)
	for key: String in CONTRACT.RECORD_KEYS:
		var record: Dictionary = fixture.registrations[event.event_id].duplicate(true)
		record[key] = "TEST.changed"
		assert_false(CONTRACT.match_registration(event, record).ok, key)

func test_digest_and_registration_results_are_detached() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var event: Dictionary = fixture.event_at(0)
	var result: Dictionary = CONTRACT.inspect(event)
	result.value.semantic.payload.scene_id = "TEST.changed"
	assert_eq(event.payload.scene_id, "TEST.A")
	event.payload.scene_id = "TEST.changed"
	assert_eq(fixture.registrations[event.event_id].payload.scene_id, "TEST.A")

# These TEST-only nested registration placeholders exercise G's nonwired table
# contract. A's nested validators/installed DTL and real disk custody are separate.
func _scene_bundle() -> Dictionary:
	return {"kind": "scene_reading_registration", "schema_version": 1,
		"entry_manifest": {"TEST": "manifest"}, "context_registry": {"TEST": "contexts"},
		"ids_registry": {"TEST": "ids"}, "caption_registry": {"TEST": "captions"},
		"scene_programme": {"kind": "scene_programme", "schema_version": 1, "entries": [
			{"entry_id": "TEST.scene", "content_version": 1, "content_sha256": "a".repeat(64),
				"program_sha256": "b".repeat(64), "markers": [
					{"marker_id": "TEST.transition", "label": "TEST.exit", "after_line_id": "TEST.line",
						"kind": "scene.transition", "payload": {"target_id": "TEST.target"}}]}]},
		"targets": [{"target_id": "TEST.target", "target": {"kind": "scene", "entry_id": "TEST.scene",
			"label": "TEST.scene", "content_version": 1, "program_sha256": "b".repeat(64)}}],
		"board_profiles": [], "challenges": [], "contacts": []}

func _scene_event() -> Dictionary:
	var fixture: RefCounted = FIXTURE.new()
	var event: Dictionary = fixture.event_at(0)
	event.schema_version = 2
	event.event_id = "TEST.transition"
	event.kind = "scene.transition"
	event.payload = {"target_id": "TEST.target"}
	return event

func _scene_anchor() -> Dictionary:
	return {"session_id": "TEST.occurrence", "entry_id": "TEST.scene", "content_version": 1,
		"catalogue_fingerprint": "TEST.catalogue", "publication_id": "TEST.publication", "line_id": "TEST.line"}

func test_scene_bundle_binds_every_nested_document_and_g_table() -> void:
	var bundle := _scene_bundle()
	var first: Dictionary = CONTRACT.bundle_fingerprint(bundle)
	assert_true(first.ok)
	for key: String in ["entry_manifest", "context_registry", "ids_registry", "caption_registry"]:
		var changed: Dictionary = bundle.duplicate(true)
		changed[key].TEST = "changed"
		assert_ne(CONTRACT.bundle_fingerprint(changed).value, first.value, key)
	var changed: Dictionary = bundle.duplicate(true)
	changed.targets[0].target.kind = "ending"
	assert_ne(CONTRACT.bundle_fingerprint(changed).value, first.value)
	changed = bundle.duplicate(true)
	changed.scene_programme.entries[0].content_sha256 = "c".repeat(64)
	assert_ne(CONTRACT.bundle_fingerprint(changed).value, first.value)
	changed = bundle.duplicate(true)
	changed.targets.append(changed.targets[0].duplicate(true))
	assert_false(CONTRACT.validate_bundle_structure(changed).ok)
	changed = bundle.duplicate(true)
	changed.extra_table = []
	assert_false(CONTRACT.validate_bundle_structure(changed).ok)

func test_scene_marker_binds_whole_source_payload_and_registered_version() -> void:
	var bundle := _scene_bundle()
	var event := _scene_event()
	assert_true(CONTRACT.inspect_scene(event, bundle).ok)
	for pair: Array in [["event_id", "TEST.unknown"], ["payload", {"target_id": "TEST.other"}], ["schema_version", 2.0]]:
		var bad: Dictionary = event.duplicate(true)
		bad[pair[0]] = pair[1]
		assert_false(CONTRACT.inspect_scene(bad, bundle).ok)
	event.source.content_version = 2
	assert_false(CONTRACT.inspect_scene(event, bundle).ok)
	assert_false(CONTRACT.match_registration(_scene_event(), {}).ok, "scene2 cannot use legacy per-record registration")
	assert_false(CONTRACT.make_receipt(_scene_event(), _scene_anchor()).ok)
	var fixture: RefCounted = FIXTURE.new()
	var notification: Dictionary = fixture.event_at(6)
	notification.schema_version = 2
	assert_false(CONTRACT.inspect(notification).ok, "legacy application port cannot admit scene2")
	assert_false(CONTRACT.make_receipt(notification, _scene_anchor()).ok)
	assert_false(CONTRACT.match_registration(notification, fixture.registrations[notification.event_id]).ok)

func test_local_return_targets_require_registered_internal_label_and_callable_targets_require_entry() -> void:
	var bundle := _scene_bundle()
	bundle.targets[0].target.kind = "return"
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)
	bundle.targets[0].target.label = "TEST.exit"
	assert_true(CONTRACT.validate_bundle_structure(bundle).ok)
	bundle.targets[0].target.kind = "scene"
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)
	bundle.targets[0].target.label = "TEST.scene"
	bundle.targets[0].target.program_sha256 = "d".repeat(64)
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)

func test_original_scene_completion_has_exact_nine_canonical_projections() -> void:
	var event := _scene_event()
	var request: Dictionary = CONTRACT.scene_completion_request(event, _scene_anchor(), _scene_bundle())
	assert_true(request.ok)
	assert_eq(request.value.ordinal, 0)
	assert_eq(request.value.child_kind, "scene_day_completion")
	assert_eq(request.value.parent_receipt_id, event.issuer_receipt.receipt_id)
	assert_eq(request.value.source_ids.size(), 9)
	assert_has(request.value.source_ids, 'role="scene_day_complete"')
	assert_has(request.value.source_ids, 'successor_id="TEST.target"')
	assert_has(request.value.source_ids, 'source_scene_occurrence="TEST.occurrence"')
	var changed: Dictionary = event.duplicate(true)
	changed.playback_token = "TEST.restarted"
	assert_eq(CONTRACT.scene_completion_request(changed, _scene_anchor(), _scene_bundle()), request)
	var anchor := _scene_anchor()
	anchor.publication_id = "TEST.other"
	assert_ne(CONTRACT.scene_completion_request(event, anchor, _scene_bundle()), request)

func test_transition_receipt_rederives_c0_instead_of_accepting_an_arbitrary_child() -> void:
	var event := _scene_event()
	var bundle := _scene_bundle()
	var request: Dictionary = CONTRACT.scene_completion_request(event, _scene_anchor(), bundle).value
	var parent: Dictionary = event.issuer_receipt
	var encoded: Dictionary = CONTRACT.WRITER.stringify(request.source_ids)
	var child := "scene_day_completion." + ("desktop_child_v1\n%s\n%d\n%s\n%s\n%d\n%s" % [
		parent.namespace, parent.counter, request.parent_receipt_id, request.child_kind, request.ordinal, encoded.value]).sha256_text()
	var result := {"kind": "scene_transition_accepted", "source_scene_occurrence": event.source.scene_occurrence,
		"target_id": "TEST.target", "target": bundle.targets[0].target.duplicate(true), "resolution_receipt": {
			"receipt_id": child, "provenance": {"schema_version": 1, "parent_receipt_id": request.parent_receipt_id,
				"child_kind": request.child_kind, "ordinal": 0, "source_ids": request.source_ids, "child_id": child}}}
	var accepted: Dictionary = CONTRACT.make_scene_receipt(event, _scene_anchor(), result, bundle)
	assert_true(accepted.ok)
	assert_eq(accepted.value.scene_event.schema_version, 2)
	result.resolution_receipt.provenance.source_ids[0] = 'command_id="TEST.forged"'
	assert_false(CONTRACT.make_scene_receipt(event, _scene_anchor(), result, bundle).ok)
	assert_ne(accepted.value.scene_event.result, result, "returned canonical receipt is detached")

func test_scene_tables_reject_dangling_markers_unsorted_ids_and_untyped_hashes() -> void:
	var bundle := _scene_bundle()
	bundle.scene_programme.entries[0].markers[0].payload.target_id = "TEST.missing"
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)
	bundle = _scene_bundle()
	bundle.scene_programme.entries[0].content_sha256 = "A".repeat(64)
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)
	bundle = _scene_bundle()
	var first: Dictionary = bundle.targets[0].duplicate(true)
	first.target_id = "AAA"
	bundle.targets.append(first)
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)
	bundle = _scene_bundle()
	bundle.scene_programme.entries[0].markers[0].ordinal = 0
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok, "traversal ordinal is not a static marker index")

func _challenge_bundle() -> Dictionary:
	var bundle := _scene_bundle()
	bundle.scene_programme.entries[0].markers.append({"marker_id": "TEST.playable", "label": "TEST.playable.label",
		"after_line_id": "TEST.line", "kind": "challenge.playable", "payload": {"challenge_id": "TEST.challenge"}})
	bundle.scene_programme.entries[0].markers.append({"marker_id": "TEST.end", "label": "TEST.end.label",
		"after_line_id": "TEST.line", "kind": "challenge.end", "payload": {"challenge_id": "TEST.challenge"}})
	bundle.board_profiles = [{"board_profile_id": "TEST.profile", "board_kind": "TEST.board", "difficulty_id": "TEST.difficulty",
		"width": 8, "height": 8, "base_mine_count": 10, "generator_version": "dwm_generator_v1",
		"verifier_version": "visible_deduction_v1", "capability_policy_id": "TEST.policy"}]
	bundle.challenges = [{"challenge_id": "TEST.challenge", "entry_id": "TEST.scene", "playable_marker_id": "TEST.playable",
		"end_marker_id": "TEST.end", "board_profile_id": "TEST.profile", "targets": {
			"never_started": "TEST.target", "unfinished": "TEST.target", "lost": "TEST.target", "won": "TEST.target"}}]
	return bundle

func test_challenge_closure_separates_never_started_from_exact_attempt_proof() -> void:
	var bundle := _challenge_bundle()
	var event := _scene_event()
	event.event_id = "TEST.end"
	event.kind = "challenge.end"
	event.payload = {"challenge_id": "TEST.challenge"}
	var encoded: Dictionary = CONTRACT.WRITER.stringify([event.source.scene_occurrence, "TEST.challenge"])
	var occurrence := str(encoded.value).sha256_text()
	var result := {"kind": "challenge_closed", "challenge_occurrence": occurrence, "playable_command_id": "TEST.playable.command",
		"attempt_proof": null, "outcome": "never_started", "target_id": "TEST.target"}
	assert_true(CONTRACT.validate_scene_result(event, result, bundle).ok)
	result.outcome = "unfinished"
	assert_false(CONTRACT.validate_scene_result(event, result, bundle).ok)
	result.attempt_proof = {"run_id": event.source.run_id, "slot_id": "scene.challenge." + occurrence,
		"attempt_id": "TEST.board.token", "branch_id": "TEST.branch", "generation": 1, "revision": 1,
		"record_sha256": "a".repeat(64), "checkpoint": {"checkpoint_id": "TEST.checkpoint",
			"checkpoint_sequence": 1, "snapshot_sha256": "b".repeat(64)}}
	for outcome: String in ["unfinished", "lost", "won"]:
		result.outcome = outcome
		assert_true(CONTRACT.validate_scene_result(event, result, bundle).ok, outcome)
	result.outcome = "never_started"
	assert_false(CONTRACT.validate_scene_result(event, result, bundle).ok)
	result.outcome = "unfinished"
	result.attempt_proof.slot_id = "scene.challenge.other"
	assert_false(CONTRACT.validate_scene_result(event, result, bundle).ok)

func test_every_additional_table_is_in_the_one_bundle_fingerprint() -> void:
	var bundle := _challenge_bundle()
	var first: Dictionary = CONTRACT.bundle_fingerprint(bundle)
	assert_true(first.ok)
	var changed: Dictionary = bundle.duplicate(true)
	changed.board_profiles[0].capability_policy_id = "TEST.other.policy"
	assert_ne(CONTRACT.bundle_fingerprint(changed).value, first.value)
	changed = bundle.duplicate(true)
	changed.targets[0].target.kind = "return"
	changed.targets[0].target.label = "TEST.exit"
	changed.contacts = [{"contact_event_id": "TEST.contact", "entry_id": "TEST.scene",
		"source_fact_ids": ["TEST.fact"], "return_target_id": "TEST.target"}]
	var contact_fingerprint: Dictionary = CONTRACT.bundle_fingerprint(changed)
	assert_true(contact_fingerprint.ok)
	changed.contacts[0].source_fact_ids = ["TEST.other.fact"]
	assert_ne(CONTRACT.bundle_fingerprint(changed).value, contact_fingerprint.value)
	changed.contacts[0].source_fact_ids = ["TEST.fact", "TEST.fact"]
	assert_false(CONTRACT.bundle_fingerprint(changed).ok)

func test_scene_admission_shape_never_claims_pristine_or_checkpoint_authentication() -> void:
	var bundle := _scene_bundle()
	var result := {"kind": "scene_admitted", "occurrence_id": "TEST.command", "entry_id": "TEST.scene",
		"target_id": "TEST.target", "source_checkpoint": {"checkpoint_id": "TEST.checkpoint",
			"checkpoint_sequence": 1, "snapshot_sha256": "a".repeat(64)}, "trigger_command_id": null, "return_to": null}
	assert_true(CONTRACT.validate_scene_admission(result, bundle).ok)
	result.resolution_receipt = {}
	assert_false(CONTRACT.validate_scene_admission(result, bundle).ok, "C0 exists only in original transition result")
	result.erase("resolution_receipt")
	result.source_checkpoint.checkpoint_sequence = 1.0
	assert_false(CONTRACT.validate_scene_admission(result, bundle).ok)

func test_scene_contract_rejects_engine_string_aliases_before_canonicalization() -> void:
	var bundle := _scene_bundle()
	bundle.kind = &"scene_reading_registration"
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)
	bundle = _scene_bundle()
	bundle.entry_manifest.TEST = &"manifest"
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)
	var event := _scene_event()
	event.issuer_receipt.token = StringName(event.command_id)
	assert_false(CONTRACT.inspect_scene(event, _scene_bundle()).ok)
	var result := {"kind": &"scene_admitted", "occurrence_id": "TEST.command", "entry_id": "TEST.scene",
		"target_id": "TEST.target", "source_checkpoint": {"checkpoint_id": "TEST.checkpoint",
			"checkpoint_sequence": 1, "snapshot_sha256": "a".repeat(64)}, "trigger_command_id": null, "return_to": null}
	assert_false(CONTRACT.validate_scene_admission(result, _scene_bundle()).ok)
