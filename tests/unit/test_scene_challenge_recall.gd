extends "res://addons/gut/test.gd"
## Pure current-fact selection and chronology on valid synthetic commands.
## These tests do not qualify issuer authority or persistence.
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

func _closure(event: Dictionary, outcome: String, command_id: String = "TEST.closed",
		counter: int = 50, occurrence_id: String = "TEST.earlier.occurrence") -> Dictionary:
	var envelope: Dictionary = event.duplicate(true)
	envelope.source.entry_id = FIXTURE.START
	envelope.source.scene_occurrence = occurrence_id
	envelope.event_id = FIXTURE.START + ".end"
	envelope.kind = "challenge.end"
	envelope.payload = {"challenge_id": FIXTURE.CHALLENGE_ID}
	envelope.command_id = command_id
	envelope.issuer_receipt.token = command_id
	envelope.issuer_receipt.counter = counter
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

func test_current_recall_selects_each_saved_outcome_without_receipts_or_mutation() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	for outcome: String in FIXTURE.OUTCOMES:
		var event := _event()
		var outcomes := {"a".repeat(64): {"challenge_id": FIXTURE.CHALLENGE_ID, "outcome": outcome}}
		var before := {"event": event.duplicate(true), "outcomes": outcomes.duplicate(true), "bundle": built.value.duplicate(true)}
		var resolved: Dictionary = CONTRACT.resolve_scene_challenge_recall(event, outcomes, built.value)
		assert_true(resolved.ok, str(resolved))
		if not resolved.ok: continue
		assert_eq(resolved.value, {"kind": "challenge_recalled", "outcome": outcome,
			"target_id": FIXTURE.target_id(outcome, true)})
		assert_eq(event, before.event)
		assert_eq(outcomes, before.outcomes)
		assert_eq(built.value, before.bundle)
		resolved.value.outcome = "changed"
		assert_eq(outcomes, before.outcomes, "returned selection is detached")

func test_current_recall_refuses_missing_or_ambiguous_saved_outcome_without_mutation() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var event := _event()
	for case: String in ["missing", "other_challenge", "ambiguous", "ambiguous_equal"]:
		var outcomes := {}
		if case == "other_challenge":
			outcomes["a".repeat(64)] = {"challenge_id": "TEST.other.challenge", "outcome": "never_started"}
		elif case.begins_with("ambiguous"):
			outcomes["a".repeat(64)] = {"challenge_id": FIXTURE.CHALLENGE_ID, "outcome": "won"}
			outcomes["b".repeat(64)] = {"challenge_id": FIXTURE.CHALLENGE_ID, "outcome": "won" if case == "ambiguous_equal" else "lost"}
		var before := {"event": event.duplicate(true), "outcomes": outcomes.duplicate(true), "bundle": built.value.duplicate(true)}
		var refused: Dictionary = CONTRACT.resolve_scene_challenge_recall(event, outcomes, built.value)
		assert_eq(refused.get("code"), &"scene_challenge_recall_ambiguous" if case.begins_with("ambiguous") else &"scene_challenge_recall_missing", case)
		assert_eq(event, before.event, case + " preserves the event")
		assert_eq(outcomes, before.outcomes, case + " preserves saved facts")
		assert_eq(built.value, before.bundle, case + " preserves registration")

func test_current_recall_rejects_malformed_facts_after_event_and_registration() -> void:
	var bundle: Dictionary = FIXTURE.bundle().value
	var event := _event()
	for invalid: Variant in [null, [], {"a".repeat(64): {"challenge_id": FIXTURE.CHALLENGE_ID, "outcome": "unknown"}}]:
		assert_eq(CONTRACT.resolve_scene_challenge_recall(event, invalid, bundle).get("code"),
			&"scene_challenge_recall_invalid")
	assert_eq(CONTRACT.resolve_scene_challenge_recall(event, null, {}).get("code"), &"scene_bundle_invalid")
	event.schema_version = 2.0
	assert_eq(CONTRACT.resolve_scene_challenge_recall(event, null, {}).get("code"), &"scene_event_version_invalid")

func test_historical_recall_keeps_earlier_result_when_another_closure_happens_later() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var event := _event()
	var earlier := _closure(event, "won")
	var later := _closure(event, "lost", "TEST.later", 150, "TEST.later.occurrence")
	var receipts := {"TEST.later": later, "TEST.closed": earlier}
	var before := receipts.duplicate(true)
	var resolved: Dictionary = CONTRACT._resolve_scene_challenge_recall_history(event, receipts)
	assert_true(resolved.ok, str(resolved))
	assert_eq(resolved.get("value"), {"kind": "challenge_recalled", "outcome": "won", "target_id": FIXTURE.target_id("won", true)},
		"a closure after the recall cannot retroactively make the saved recall ambiguous")
	assert_eq(receipts, before)
	event.issuer_receipt.counter = 150
	assert_eq(CONTRACT._resolve_scene_challenge_recall_history(event, receipts), resolved,
		"a closure at the recall counter is not an earlier completion")
	event.issuer_receipt.counter = 200
	assert_eq(CONTRACT._resolve_scene_challenge_recall_history(event, receipts).get("code"),
		&"scene_challenge_recall_ambiguous", "a later recall sees both completed occurrences")

func test_recall_receipt_binds_outcome_target_and_anchor_shape() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var event := _event()
	var anchor := {"session_id": event.source.scene_occurrence, "entry_id": FIXTURE.LATER,
		"content_version": 1, "catalogue_fingerprint": "TEST.catalogue", "publication_id": "TEST.publication",
		"line_id": "line." + FIXTURE.LATER + ".one"}
	var result := {"kind": "challenge_recalled", "outcome": "perfect", "target_id": "recall_e_day1"}
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
	result["closure_command_id"] = "TEST.closed"
	assert_false(CONTRACT.make_scene_receipt(event, anchor, result, built.value).ok)
