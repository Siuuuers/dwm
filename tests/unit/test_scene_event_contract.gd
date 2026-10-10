extends "res://addons/gut/test.gd"
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
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

func test_local_return_targets_are_structural_and_callable_targets_require_entry() -> void:
	for kind: String in ["local", "return"]:
		var bundle := _scene_bundle()
		bundle.targets[0].target.kind = kind
		bundle.targets[0].target.label = "TEST.internal"
		assert_true(CONTRACT.validate_bundle_structure(bundle).ok, "installed-label existence belongs to trusted DTL registration")
		for pair: Array in [["kind", "unknown"], ["entry_id", "TEST.missing"], ["label", ""], ["content_version", 2], ["program_sha256", "d".repeat(64)]]:
			var bad: Dictionary = bundle.duplicate(true)
			bad.targets[0].target[pair[0]] = pair[1]
			assert_false(CONTRACT.validate_bundle_structure(bad).ok)
		bundle.targets[0].target.extra = true
		assert_false(CONTRACT.validate_bundle_structure(bundle).ok)
	for kind: String in ["scene", "contact", "ending"]:
		var bundle := _scene_bundle()
		bundle.targets[0].target.kind = kind
		assert_true(CONTRACT.validate_bundle_structure(bundle).ok)
		bundle.targets[0].target.label = "TEST.exit"
		assert_false(CONTRACT.validate_bundle_structure(bundle).ok)

func test_authentic_registration_accepts_ordinary_return_label_without_effect_marker() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/dialogic/scene_reading_registration_compat.json")
	assert_eq(text.sha256_text(), "099e0ef79457c1bb56ecd06849f5c0abf3cd829d71b355f3d0292822a04a4f4b")
	var parsed: Dictionary = STRICT.parse_object(text)
	assert_true(parsed.ok)
	if not parsed.ok: return
	var bundle: Dictionary = parsed.value
	assert_eq(bundle.targets[0].target.kind, "return")
	assert_eq(bundle.targets[0].target.label, "scene.test.a.loop")
	assert_eq(bundle.scene_programme.entries[1].entry_id, "scene.test.a")
	assert_eq(bundle.scene_programme.entries[1].markers, [])
	assert_true(CONTRACT.validate_bundle_structure(bundle).ok, "structural compatibility only; full installed DTL validation belongs to A")

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


func _playable_event() -> Dictionary:
	var event := _scene_event()
	event.event_id = "TEST.playable"
	event.kind = "challenge.playable"
	event.payload = {"challenge_id": "TEST.challenge"}
	return event

func _playable_result() -> Dictionary:
	# Independent fixed vector for canonical JSON ["TEST.occurrence","TEST.challenge"].
	return {"kind": "challenge_playable", "challenge_occurrence": "db23df5fa0bcdb2aa7d9d45ac6809a5c7a02a389f2e83a768d8699a195d8490d"}

func test_playable_result_is_exact_availability_not_start_or_closure() -> void:
	var event := _playable_event()
	var result := _playable_result()
	var bundle := _challenge_bundle()
	assert_true(CONTRACT.inspect_scene(event, bundle).ok)
	assert_true(CONTRACT.validate_scene_result(event, result, bundle).ok)
	var receipt: Dictionary = CONTRACT.make_scene_receipt(event, _scene_anchor(), result, bundle)
	assert_true(receipt.ok)
	if not receipt.ok: return
	assert_eq(receipt.value.scene_event.result, result)
	assert_eq(receipt.value.scene_event.result.size(), 2)
	assert_eq(receipt.value.transaction_id, event.command_id)
	assert_eq(receipt.value.scene_event.schema_version, 2)
	assert_false(receipt.value.scene_event.semantic.has("playback_token"))
	assert_eq(receipt.value.request_fingerprint, CONTRACT.inspect_scene(event, bundle).value.digest)
	for field: String in ["attempt_id", "attempt_proof", "board", "outcome", "target_id", "playable_command_id", "profile_branch"]:
		var polluted: Dictionary = result.duplicate(true)
		polluted[field] = null
		assert_false(CONTRACT.validate_scene_result(event, polluted, bundle).ok, field)

func test_playable_result_rejects_missing_extra_and_non_json_members() -> void:
	var event := _playable_event()
	var bundle := _challenge_bundle()
	for value: Variant in [null, [], "challenge_playable", 1, true, {}, {"kind": "challenge_playable"},
			{"challenge_occurrence": _playable_result().challenge_occurrence}]:
		assert_false(CONTRACT.validate_scene_result(event, value, bundle).ok)
	for field: String in ["kind", "challenge_occurrence"]:
		for value: Variant in [null, 1, 1.0, true, [], {}, &"challenge_playable"]:
			var bad := _playable_result()
			bad[field] = value
			assert_false(CONTRACT.validate_scene_result(event, bad, bundle).ok, field)
	var named_hash := _playable_result()
	named_hash.challenge_occurrence = StringName(named_hash.challenge_occurrence)
	assert_false(CONTRACT.validate_scene_result(event, named_hash, bundle).ok)
	var extra := _playable_result()
	extra[1] = "not a JSON object key"
	assert_false(CONTRACT.validate_scene_result(event, extra, bundle).ok)

func test_playable_result_requires_lowercase_exact_occurrence_hash() -> void:
	var expected := _playable_result()
	var encoded: Dictionary = CONTRACT.WRITER.stringify(["TEST.occurrence", "TEST.challenge"])
	assert_eq(str(encoded.value).sha256_text(), expected.challenge_occurrence)
	for value: String in ["", "0".repeat(64), "g".repeat(64), "a".repeat(63), "a".repeat(65),
			expected.challenge_occurrence.to_upper(), " " + expected.challenge_occurrence, expected.challenge_occurrence + "\n"]:
		var bad := _playable_result()
		bad.challenge_occurrence = value
		assert_false(CONTRACT.validate_scene_result(_playable_event(), bad, _challenge_bundle()).ok)

func test_playable_result_binds_registered_marker_kind_payload_and_version() -> void:
	var bundle := _challenge_bundle()
	var result := _playable_result()
	for pair: Array in [["schema_version", 1], ["schema_version", 2.0], ["event_id", "TEST.end"],
			["event_id", "TEST.unregistered"], ["kind", "challenge.end"], ["kind", "notification.set"],
			["payload", {"challenge_id": "TEST.foreign"}], ["payload", {"challenge_id": "TEST.challenge", "start": true}]]:
		var bad := _playable_event()
		bad[pair[0]] = pair[1]
		assert_false(CONTRACT.validate_scene_result(bad, result, bundle).ok, str(pair))
	var end := _playable_event()
	end.event_id = "TEST.end"
	end.kind = "challenge.end"
	assert_true(CONTRACT.inspect_scene(end, bundle).ok)
	assert_false(CONTRACT.validate_scene_result(end, result, bundle).ok)
	assert_false(CONTRACT.validate_scene_result(_scene_event(), result, bundle).ok)
	var version := _playable_event()
	version.source.content_version = 2
	assert_false(CONTRACT.validate_scene_result(version, result, bundle).ok)

func test_playable_result_rederives_occurrence_from_semantic_source() -> void:
	var event := _playable_event()
	var bundle := _challenge_bundle()
	var result := _playable_result()
	event.source.scene_occurrence = "TEST.other.occurrence"
	assert_true(CONTRACT.inspect_scene(event, bundle).ok)
	assert_false(CONTRACT.validate_scene_result(event, result, bundle).ok)
	var encoded: Dictionary = CONTRACT.WRITER.stringify([event.source.scene_occurrence, event.payload.challenge_id])
	result.challenge_occurrence = str(encoded.value).sha256_text()
	assert_true(CONTRACT.validate_scene_result(event, result, bundle).ok)
	# Structural result validity is not issuer, admission, cursor, or disk proof.
	assert_false(CONTRACT.make_scene_receipt(event, _scene_anchor(), result, bundle).ok)

func test_playable_receipt_keeps_semantic_identity_across_live_token_change() -> void:
	var event := _playable_event()
	var bundle := _challenge_bundle()
	var result := _playable_result()
	var first: Dictionary = CONTRACT.make_scene_receipt(event, _scene_anchor(), result, bundle)
	assert_true(first.ok)
	if not first.ok: return
	event.playback_token = "TEST.new.authenticated.process"
	var retried: Dictionary = CONTRACT.make_scene_receipt(event, _scene_anchor(), result, bundle)
	assert_eq(retried, first)
	# Authentication of that new token remains the application port's responsibility.
	var moved: Dictionary = event.duplicate(true)
	moved.source.branch_id = "TEST.other.branch"
	assert_ne(CONTRACT.inspect_scene(moved, bundle).value.digest, first.value.request_fingerprint)

func test_playable_receipt_requires_exact_predecessor_anchor_and_detaches_result() -> void:
	var event := _playable_event()
	var bundle := _challenge_bundle()
	var result := _playable_result()
	var anchor := _scene_anchor()
	var original_event: Dictionary = event.duplicate(true)
	var original_bundle: Dictionary = bundle.duplicate(true)
	var first: Dictionary = CONTRACT.make_scene_receipt(event, anchor, result, bundle)
	assert_true(first.ok)
	if not first.ok: return
	first.value.scene_event.result.challenge_occurrence = "0".repeat(64)
	assert_eq(result, _playable_result())
	assert_eq(event, original_event)
	assert_eq(bundle, original_bundle)
	anchor.line_id = "TEST.other.line"
	assert_false(CONTRACT.make_scene_receipt(event, anchor, result, bundle).ok)
	anchor = _scene_anchor()
	anchor.session_id = "TEST.other.occurrence"
	assert_false(CONTRACT.make_scene_receipt(event, anchor, result, bundle).ok)
	assert_eq(event, original_event)
	assert_eq(bundle, original_bundle)
