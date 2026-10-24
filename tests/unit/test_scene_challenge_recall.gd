extends "res://addons/gut/test.gd"
## Pure synthetic receipt selection, not issuer/ledger/persistence qualification.
## Rendered create/load separately exercises the real retained ledger and storage.
const FIXTURE := preload("res://tests/support/SceneChallengeRecallFixture.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const EVENTS := preload("res://tests/support/SceneEventFixture.gd")

func _event() -> Dictionary:
	var event: Dictionary = EVENTS.new().event_at(0)
	event.schema_version = 2
	event.source.entry_id = FIXTURE.LATER
	event.event_id = FIXTURE.LATER + ".recall"
	event.kind = "challenge.recall"
	event.payload = FIXTURE.recall_payload()
	# Synthetic chronological metadata; this test does not claim issuer validity.
	event.issuer_receipt.counter = 100
	return event

func _closure(event: Dictionary, outcome: String, command_id: String = "TEST.closed") -> Dictionary:
	var envelope: Dictionary = event.duplicate(true)
	envelope.source.entry_id = FIXTURE.START
	envelope.source.scene_occurrence = "TEST.earlier.occurrence"
	envelope.event_id = FIXTURE.START + ".end"
	envelope.kind = "challenge.end"
	envelope.payload = {"challenge_id": FIXTURE.CHALLENGE_ID}
	envelope.command_id = command_id
	envelope.issuer_receipt.token = command_id
	envelope.issuer_receipt.counter = 50
	var occurrence: String = str(CONTRACT.WRITER.stringify([envelope.source.scene_occurrence, FIXTURE.CHALLENGE_ID]).value).sha256_text()
	var proof: Variant = null
	if outcome != "never_started":
		proof = {"run_id": envelope.source.run_id, "slot_id": "scene.challenge." + occurrence,
			"attempt_id": "TEST.attempt", "branch_id": envelope.source.branch_id, "generation": 1, "revision": 1,
			"record_sha256": "a".repeat(64), "checkpoint": {"checkpoint_id": "TEST.checkpoint",
				"checkpoint_sequence": 1, "snapshot_sha256": "b".repeat(64)}}
	var result := {"kind": "challenge_closed", "outcome": outcome, "target_id": FIXTURE.target_id(outcome),
		"challenge_occurrence": occurrence, "playable_command_id": "TEST.playable", "attempt_proof": proof}
	var anchor := {"session_id": envelope.source.scene_occurrence, "entry_id": FIXTURE.START,
		"content_version": 1, "catalogue_fingerprint": "TEST.catalogue", "publication_id": "TEST.publication",
		"line_id": "line." + FIXTURE.START + ".two"}
	var receipt: Dictionary = CONTRACT.make_scene_receipt(envelope, anchor, result, FIXTURE.bundle().value)
	assert_true(receipt.ok, str(receipt))
	return receipt.get("value", {})

func test_installed_fixture_binds_five_distinct_end_targets_and_recall_targets() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok, str(built))
	if not built.ok: return
	assert_true(FIXTURE.MANIFEST.validate_scene_registration(built.value).ok)
	assert_true(CONTRACT.validate_bundle_structure(built.value).ok)
	assert_eq(built.value.challenges[0].targets.size(), 5)
	var targets: Array = built.value.challenges[0].targets.values()
	for outcome: String in FIXTURE.OUTCOMES:
		assert_has(targets, FIXTURE.target_id(outcome))
	var broken: Dictionary = built.value.duplicate(true)
	for programme: Dictionary in broken.scene_programme.entries:
		if programme.entry_id == FIXTURE.LATER:
			programme.markers[0].payload.perfect_target_id = "TEST.missing"
	assert_false(CONTRACT.validate_bundle_structure(broken).ok)

func test_legacy_four_and_exact_five_maps_allow_convergent_content_but_no_partial_shape() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var bundle: Dictionary = built.value.duplicate(true)
	for outcome: String in FIXTURE.OUTCOMES: bundle.challenges[0].targets[outcome] = "echo_a_day1"
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id != FIXTURE.LATER: continue
		for outcome: String in FIXTURE.OUTCOMES: programme.markers[0].payload[outcome + "_target_id"] = "recall_a_day1"
	assert_true(CONTRACT.validate_bundle_structure(bundle).ok, "all outcomes may share a content target")
	bundle.challenges[0].targets.erase("perfect")
	assert_true(CONTRACT.validate_bundle_structure(bundle).ok, "legacy four-result saved registration remains valid")
	bundle.challenges[0].targets.erase("lost")
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)
	bundle = built.value.duplicate(true)
	bundle.challenges[0].targets["extra"] = "echo_a_day1"
	assert_false(CONTRACT.validate_bundle_structure(bundle).ok)

func test_pure_recall_selects_each_recorded_outcome_without_mutating_inputs() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	for outcome: String in FIXTURE.OUTCOMES:
		var event := _event()
		var receipts := {"TEST.closed": _closure(event, outcome)}
		var before := {"event": event.duplicate(true), "receipts": receipts.duplicate(true), "bundle": built.value.duplicate(true)}
		var resolved: Dictionary = CONTRACT.resolve_scene_challenge_recall(event, receipts, built.value)
		assert_true(resolved.ok, str(resolved))
		if not resolved.ok: continue
		assert_eq(resolved.value, {"kind": "challenge_recalled", "closure_command_id": "TEST.closed",
			"outcome": outcome, "target_id": FIXTURE.target_id(outcome, true)})
		assert_eq(event, before.event)
		assert_eq(receipts, before.receipts)
		assert_eq(built.value, before.bundle)
		resolved.value.outcome = "changed"
		assert_eq(receipts, before.receipts, "returned selection is detached")

func test_pure_recall_refuses_missing_wrong_run_future_or_ambiguous_closure() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var event := _event()
	assert_false(CONTRACT.resolve_scene_challenge_recall(event, {}, built.value).ok)
	for invalid: String in ["wrong_run", "wrong_challenge", "future", "equal_counter", "ambiguous"]:
		var receipts := {"TEST.closed": _closure(event, "won")}
		match invalid:
			"wrong_run": receipts["TEST.closed"].scene_event.semantic.source.run_id = "TEST.other.run"
			"wrong_challenge": receipts["TEST.closed"].scene_event.semantic.payload.challenge_id = "TEST.other.challenge"
			"future": receipts["TEST.closed"].scene_event.semantic.issuer_receipt.counter = 101
			"equal_counter": receipts["TEST.closed"].scene_event.semantic.issuer_receipt.counter = 100
			"ambiguous": receipts["TEST.second"] = _closure(event, "lost", "TEST.second")
		assert_false(CONTRACT.resolve_scene_challenge_recall(event, receipts, built.value).ok, invalid)

func test_recall_receipt_binds_outcome_target_and_anchor_shape() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var event := _event()
	var anchor := {"session_id": event.source.scene_occurrence, "entry_id": FIXTURE.LATER,
		"content_version": 1, "catalogue_fingerprint": "TEST.catalogue", "publication_id": "TEST.publication",
		"line_id": "line." + FIXTURE.LATER + ".one"}
	var result := {"kind": "challenge_recalled", "closure_command_id": "TEST.closed",
		"outcome": "perfect", "target_id": "recall_e_day1"}
	assert_true(CONTRACT.make_scene_receipt(event, anchor, result, built.value).ok)
	result.target_id = "recall_c_day1"
	assert_false(CONTRACT.make_scene_receipt(event, anchor, result, built.value).ok)
	result.target_id = "recall_e_day1"
	result["extra"] = true
	assert_false(CONTRACT.make_scene_receipt(event, anchor, result, built.value).ok)
	result.erase("extra")
	anchor.line_id = "line." + FIXTURE.START + ".one"
	assert_false(CONTRACT.make_scene_receipt(event, anchor, result, built.value).ok)
	anchor.line_id = "line." + FIXTURE.LATER + ".one"
	result.closure_command_id = ""
	assert_false(CONTRACT.make_scene_receipt(event, anchor, result, built.value).ok)

func test_recall_rechecks_changed_bundle_on_each_public_call() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var event := _event()
	var receipts := {"TEST.closed": _closure(event, "won")}
	assert_true(CONTRACT.resolve_scene_challenge_recall(event, receipts, built.value).ok)
	var changed: Dictionary = built.value.duplicate(true)
	changed.caption_registry["TEST.changed"] = "different registration"
	assert_true(CONTRACT.validate_bundle_structure(changed).ok,
		"the changed registration remains structurally valid")
	var refused: Dictionary = CONTRACT.resolve_scene_challenge_recall(event, receipts, changed)
	assert_eq(refused.get("code"), &"scene_receipt_mismatch",
		"a prior call cannot authorize a closure under a different bundle fingerprint")
	assert_true(CONTRACT.resolve_scene_challenge_recall(event, receipts, built.value).ok,
		"the original registration still proves the retained closure")

func test_recall_revalidates_matching_closure_shape_anchor_result_and_fingerprint() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var event := _event()
	var closure := _closure(event, "won")
	var expected := {"version": &"scene_event_version_invalid", "marker": &"scene_marker_unregistered",
		"anchor": &"event_anchor_invalid", "target": &"scene_result_invalid",
		"attempt": &"scene_attempt_proof_invalid", "registration": &"scene_receipt_mismatch",
		"fingerprint": &"scene_receipt_mismatch"}
	for mutation: String in expected:
		var changed: Dictionary = closure.duplicate(true)
		match mutation:
			"version": changed.scene_event.semantic.schema_version = 2.0
			"marker": changed.scene_event.semantic.event_id = "TEST.missing"
			"anchor": changed.scene_event.reading_anchor.line_id = "TEST.other.line"
			"target": changed.scene_event.result.target_id = "TEST.other.target"
			"attempt": changed.scene_event.result.attempt_proof = null
			"registration": changed.scene_event.registration_fingerprint = "0".repeat(64)
			"fingerprint": changed.request_fingerprint = "0".repeat(64)
		var before: Dictionary = changed.duplicate(true)
		var refused: Dictionary = CONTRACT.resolve_scene_challenge_recall(event, {"TEST.closed": changed}, built.value)
		assert_eq(refused.get("code"), expected[mutation], mutation)
		assert_eq(changed, before, mutation + " refusal preserves the submitted closure")

func test_recall_keeps_event_bundle_and_closure_refusal_order() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var event := _event()
	var closure := _closure(event, "won")
	var bad_event: Dictionary = event.duplicate(true)
	bad_event.schema_version = 2.0
	var bad_closure: Dictionary = closure.duplicate(true)
	bad_closure.scene_event.semantic.schema_version = 2.0
	var receipts := {"TEST.closed": bad_closure}
	assert_eq(CONTRACT.resolve_scene_challenge_recall(bad_event, receipts, {}).get("code"),
		&"scene_event_version_invalid", "the recall envelope precedes bundle and closure admission")
	assert_eq(CONTRACT.resolve_scene_challenge_recall(event, receipts, {}).get("code"),
		&"scene_bundle_invalid", "fresh bundle admission precedes matching closure admission")
	var second := _closure(event, "lost", "TEST.second")
	second.scene_event.reading_anchor.line_id = "TEST.other.line"
	assert_eq(CONTRACT.resolve_scene_challenge_recall(event,
		{"TEST.closed": closure, "TEST.second": second}, built.value).get("code"),
		&"event_anchor_invalid", "the second closure must validate before reporting ambiguity")
