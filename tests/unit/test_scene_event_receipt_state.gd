extends "res://addons/gut/test.gd"
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")

func _event(ordinal: int = 0, occurrence: String = "TEST.session") -> Dictionary:
	return {"schema_version": 1, "source": {"run_id": "TEST.run", "branch_id": "TEST.branch",
		"causal_day_instance": "TEST.day", "scene_occurrence": occurrence,
		"entry_id": "TEST.entry", "content_version": 1}, "event_id": "TEST.event.%d" % ordinal,
		"ordinal": ordinal, "predecessor": "" if ordinal == 0 else "TEST.event.%d" % (ordinal - 1),
		"kind": "notification.set", "payload": {"notification_id": "TEST.notice",
			"content_id": "TEST.copy", "parameters": {"count": 1}},
		"command_id": occurrence + ".command.%d" % ordinal, "issuer_receipt": {"token": occurrence + ".command.%d" % ordinal}, "playback_token": "TEST.live"}

func _receipt(event: Dictionary) -> Dictionary:
	var anchor := {"session_id": event.source.scene_occurrence, "entry_id": event.source.entry_id,
		"content_version": event.source.content_version, "catalogue_fingerprint": "ab".repeat(32),
		"publication_id": "TEST.publication", "line_id": "TEST.line"}
	return CONTRACT.make_receipt(event, anchor).value

func _map(items: Array) -> Dictionary:
	var result := {}
	for item: Dictionary in items: result[item.transaction_id] = item
	return result

func test_rebuilds_set_clear_chain_independent_of_dictionary_order() -> void:
	var first: Dictionary = _receipt(_event())
	var clear: Dictionary = _event(1)
	clear.kind = "notification.clear"
	clear.payload = {"notification_id": "TEST.notice"}
	var result: Dictionary = CONTRACT.validate_receipts(_map([_receipt(clear), first]))
	assert_true(result.ok, str(result))
	if not result.ok: return
	var state: Dictionary = result.value.occurrences[CONTRACT.occurrence_key(clear.source)]
	assert_eq(state.next_ordinal, 2)
	assert_eq(state.predecessor, clear.event_id)
	assert_eq(state.notification, {})
	assert_false(first.scene_event.semantic.has("playback_token"))
	state.receipts[0].scene_event.semantic.payload.parameters.count = 99
	assert_eq(first.scene_event.semantic.payload.parameters.count, 1)

func test_receipt_retains_issuer_but_does_not_retain_live_token() -> void:
	var event: Dictionary = _event()
	event.issuer_receipt["epoch"] = 1
	var first: Dictionary = _receipt(event)
	event.playback_token = "TEST.new_process"
	assert_eq(_receipt(event), first)
	event.issuer_receipt.epoch = 2
	assert_ne(_receipt(event).request_fingerprint, first.request_fingerprint)

func test_rejects_tampered_digests_results_and_closed_shapes() -> void:
	for field: String in ["request_fingerprint", "source_id", "transaction_id"]:
		var item: Dictionary = _receipt(_event())
		item[field] = "TEST.changed"
		assert_false(CONTRACT.validate_receipts({"TEST.session.command.0": item}).ok, field)
	for field: String in ["registration_fingerprint", "semantic", "reading_anchor", "result", "schema_version"]:
		var item: Dictionary = _receipt(_event())
		item.scene_event[field] = null
		assert_false(CONTRACT.validate_receipts(_map([item])).ok, field)
	var wrong: Dictionary = _receipt(_event())
	wrong.scene_event.result.notification.parameters.count = 9
	assert_false(CONTRACT.validate_receipts(_map([wrong])).ok)
	wrong = _receipt(_event())
	wrong.scene_event.result.ordinal = 0.0
	assert_false(CONTRACT.validate_receipts(_map([wrong])).ok)
	wrong = _receipt(_event())
	wrong.scene_event.semantic.playback_token = "TEST.persisted"
	assert_false(CONTRACT.validate_receipts(_map([wrong])).ok)
	wrong = _receipt(_event())
	wrong.scene_event.result.extra = true
	assert_false(CONTRACT.validate_receipts(_map([wrong])).ok)

func test_rejects_gaps_wrong_predecessors_duplicate_ordinals_and_events() -> void:
	var first: Dictionary = _receipt(_event())
	assert_eq(CONTRACT.validate_receipts(_map([first, _receipt(_event(2))])).get("code"), &"event_receipt_chain_invalid")
	var second: Dictionary = _event(1)
	second.predecessor = "TEST.wrong"
	assert_eq(CONTRACT.validate_receipts(_map([first, _receipt(second)])).get("code"), &"event_receipt_chain_invalid")
	second = _event()
	second.command_id = "TEST.other_command"
	second.issuer_receipt.token = second.command_id
	second.event_id = "TEST.other_event"
	assert_eq(CONTRACT.validate_receipts(_map([first, _receipt(second)])).get("code"), &"event_receipt_chain_invalid")
	second = _event(1)
	second.event_id = "TEST.event.0"
	assert_eq(CONTRACT.validate_receipts(_map([first, _receipt(second)])).get("code"), &"event_receipt_chain_invalid")

func test_clear_requires_matching_current_notification() -> void:
	var clear: Dictionary = _event()
	clear.kind = "notification.clear"
	clear.payload = {"notification_id": "TEST.notice"}
	assert_eq(CONTRACT.validate_receipts(_map([_receipt(clear)])).get("code"), &"event_notification_clear_invalid")
	clear = _event(1)
	clear.kind = "notification.clear"
	clear.payload = {"notification_id": "TEST.other"}
	assert_eq(CONTRACT.validate_receipts(_map([_receipt(_event()), _receipt(clear)])).get("code"), &"event_notification_clear_invalid")

func test_occurrences_are_isolated_and_source_is_immutable() -> void:
	var one: Dictionary = _event()
	var two: Dictionary = _event(0, "TEST.other_session")
	var result: Dictionary = CONTRACT.validate_receipts(_map([_receipt(one), _receipt(two)]))
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.occurrences.size(), 2)
	var changed: Dictionary = _event(1)
	changed.source.branch_id = "TEST.other_branch"
	assert_eq(CONTRACT.validate_receipts(_map([_receipt(one), _receipt(changed)])).get("code"), &"event_receipt_source_changed")
	one.source.scene_occurrence = "a:b"
	one.source.entry_id = "c"
	two.source.scene_occurrence = "a"
	two.source.entry_id = "b:c"
	assert_ne(CONTRACT.occurrence_key(one.source), CONTRACT.occurrence_key(two.source))

func test_rejects_anchor_mismatch_and_unsupported_kinds() -> void:
	var event: Dictionary = _event()
	var anchor: Dictionary = _receipt(event).scene_event.reading_anchor
	for field: String in ["session_id", "entry_id", "content_version"]:
		var wrong: Dictionary = anchor.duplicate(true)
		wrong[field] = 2 if field == "content_version" else "TEST.other"
		assert_false(CONTRACT.make_receipt(event, wrong).ok, field)
	event.kind = "background.set"
	event.payload = {"art_id": "TEST.art"}
	assert_false(CONTRACT.make_receipt(event, anchor).ok)
	assert_true(CONTRACT.validate_receipts({"legacy": {"kind": "existing_variant"}}).ok)

func test_rejects_anchor_drift_and_unbound_issuer_token() -> void:
	var first: Dictionary = _receipt(_event())
	var event: Dictionary = _event(1)
	var anchor: Dictionary = _receipt(event).scene_event.reading_anchor
	anchor.catalogue_fingerprint = "cd".repeat(32)
	var second: Dictionary = CONTRACT.make_receipt(event, anchor).value
	assert_eq(CONTRACT.validate_receipts(_map([first, second])).get("code"), &"event_anchor_changed")
	event.issuer_receipt.token = "TEST.other_command"
	assert_false(CONTRACT.make_receipt(event, anchor).ok)
	event.issuer_receipt = {}
	assert_false(CONTRACT.make_receipt(event, anchor).ok)

func test_later_publication_and_line_anchor_are_permitted_in_same_occurrence() -> void:
	var first: Dictionary = _receipt(_event())
	var event: Dictionary = _event(1)
	var anchor: Dictionary = _receipt(event).scene_event.reading_anchor
	anchor.publication_id = "TEST.later_publication"
	anchor.line_id = "TEST.later_line"
	var second: Dictionary = CONTRACT.make_receipt(event, anchor).value
	var result: Dictionary = CONTRACT.validate_receipts(_map([first, second]))
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.occurrences[CONTRACT.occurrence_key(event.source)].next_ordinal, 2)
