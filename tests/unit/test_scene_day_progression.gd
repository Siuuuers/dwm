extends "res://addons/gut/test.gd"
const RULES := preload("res://scripts/domain/narrative/SceneDayProgression.gd")
const FIXTURE := preload("res://tests/support/SceneDayProgressionFixture.gd")

func _complete(document: Dictionary, day: int, ending: Variant = null) -> Dictionary:
	return RULES.plan_completion(document, day, FIXTURE.envelope(document, day), FIXTURE.position(document, day), ending)

func _refuses(result: Dictionary, code: StringName) -> void:
	assert_eq(result, {"ok": false, "code": code})
	assert_true(result.is_read_only())

func _expected(kind: String, day: int, row: Dictionary) -> Dictionary:
	return {"ok": true, "value": {"kind": kind, "target_day": day, "entry_id": row.entry_id,
		"content_version": row.content_version, "content_sha256": row.content_sha256}}

func test_all_eight_routes_use_exact_registered_descriptors() -> void:
	var document: Dictionary = FIXTURE.document()
	assert_eq(RULES.plan_new_run(document), _expected("enter_day", 1, document.days[0]))
	for day in range(1, 7):
		assert_eq(_complete(document, day), _expected("enter_day", day + 1, document.days[day]))
	assert_eq(_complete(document, 7, "TEST.ending.b"), _expected("enter_ending", 7, document.endings[1]))

func test_empty_endings_admit_initial_and_six_edges_but_never_day7_default() -> void:
	var document: Dictionary = FIXTURE.document()
	document.endings.clear()
	assert_true(RULES.plan_new_run(document).ok)
	for day in range(1, 7): assert_true(_complete(document, day).ok)
	for ending: Variant in [null, "TEST.ending.a"]:
		_refuses(_complete(document, 7, ending), &"ending_invalid")

func test_multiple_endings_require_explicit_registered_selection() -> void:
	var document: Dictionary = FIXTURE.document()
	for row: Dictionary in document.endings:
		assert_eq(_complete(document, 7, row.ending_id), _expected("enter_ending", 7, row))
	for ending: Variant in [null, "", "TEST.unknown", 1, [], {}, true, "res://ending.dtl"]:
		_refuses(_complete(document, 7, ending), &"ending_invalid")
	for day in range(1, 7): _refuses(_complete(document, day, "TEST.ending.a"), &"ending_invalid")

func test_invalid_days_never_produce_day8() -> void:
	var document: Dictionary = FIXTURE.document()
	for day: Variant in [null, 0, 8, -1, 1.0, true, "1", [], {}]:
		_refuses(RULES.plan_completion(document, day, {}, {}), &"day_invalid")

func test_document_containers_and_seven_ordered_rows_are_strict() -> void:
	for value: Variant in [null, [], "document", 1, true, {}]:
		_refuses(RULES.plan_new_run(value), &"registration_invalid")
	for key: String in ["days", "endings"]:
		for value: Variant in [null, {}, "rows", 7]:
			var document: Dictionary = FIXTURE.document()
			document[key] = value
			_refuses(RULES.plan_new_run(document), &"registration_invalid")
	for count in [0, 6, 8]:
		var document: Dictionary = FIXTURE.document()
		document.days.resize(count)
		_refuses(RULES.plan_new_run(document), &"registration_invalid")
	var reordered: Dictionary = FIXTURE.document()
	reordered.days.reverse()
	_refuses(RULES.plan_new_run(reordered), &"registration_invalid")
	for value: Variant in [null, [], "row", 1]:
		for part: String in ["day", "terminal", "ending"]:
			var document: Dictionary = FIXTURE.document()
			if part == "day": document.days[0] = value
			elif part == "terminal": document.days[0].terminal = value
			else: document.endings[0] = value
			_refuses(RULES.plan_new_run(document), &"registration_invalid")

func test_every_document_object_rejects_missing_extra_and_nonstring_keys() -> void:
	for part: String in ["document", "day", "terminal", "ending"]:
		var sample: Dictionary = FIXTURE.document()
		var keys: Array = _part(sample, part).keys()
		for key: String in keys:
			var document: Dictionary = FIXTURE.document()
			_part(document, part).erase(key)
			_refuses(RULES.plan_new_run(document), &"registration_invalid")
		for key: Variant in ["extra", 1, &"extra"]:
			var document: Dictionary = FIXTURE.document()
			_part(document, part)[key] = true
			_refuses(RULES.plan_new_run(document), &"registration_invalid")
		var wrong_key: Dictionary = FIXTURE.document()
		var object: Dictionary = _part(wrong_key, part)
		var first_key: String = keys[0]
		var original_value: Variant = object[first_key]
		object.erase(first_key)
		object[StringName(first_key)] = original_value
		_refuses(RULES.plan_new_run(wrong_key), &"registration_invalid")

func _part(document: Dictionary, part: String) -> Dictionary:
	if part == "day": return document.days[0]
	if part == "terminal": return document.days[0].terminal
	if part == "ending": return document.endings[0]
	return document

func test_document_primitive_types_and_values_are_strict() -> void:
	var mutations := {
		"document": {"schema_version": [true, 1.0, "1", 0, 2]},
		"day": {"day": [true, 1.0, "1", 0, 8], "entry_id": [null, "", "res://x", &"TEST.day1"],
			"content_version": [true, 1.0, 0, -1], "content_sha256": [null, "a", "A".repeat(64), "g".repeat(64)]},
		"terminal": {"event_id": [null, "", "x/y"], "ordinal": [true, 0.0, -1],
			"predecessor": [null, 0, "TEST.prior"], "label": [null, "TEST.wrong"],
			"after_line_id": [null, "", "x y"], "successor_id": [null, "", "TEST.wrong"]},
		"ending": {"ending_id": [null, "", "x/y"], "entry_id": [null, "", "x y"],
			"content_version": [true, 1.0, 0], "content_sha256": [null, "", "A".repeat(64)]}}
	for part: String in mutations:
		for key: String in mutations[part]:
			for value: Variant in mutations[part][key]:
				var document: Dictionary = FIXTURE.document()
				_part(document, part)[key] = value
				_refuses(RULES.plan_new_run(document), &"registration_invalid")

func test_identifier_boundary_and_positive_predecessor_rule() -> void:
	var document: Dictionary = FIXTURE.document()
	document.days[0].terminal.after_line_id = "A".repeat(256)
	document.days[0].terminal.ordinal = 2
	document.days[0].terminal.predecessor = "TEST.previous"
	assert_true(_complete(document, 1).ok)
	for predecessor: Variant in ["", "TEST.day1.complete", "bad/path"]:
		document.days[0].terminal.predecessor = predecessor
		_refuses(RULES.plan_new_run(document), &"registration_invalid")
	document = FIXTURE.document()
	document.days[0].entry_id = "A".repeat(257)
	_refuses(RULES.plan_new_run(document), &"registration_invalid")

func test_duplicates_and_cross_category_entry_collisions_refuse() -> void:
	for duplicate: String in ["day_entry", "ending_id", "ending_entry", "cross_entry", "event", "label"]:
		var document: Dictionary = FIXTURE.document()
		match duplicate:
			"day_entry": document.days[1].entry_id = document.days[0].entry_id
			"ending_id": document.endings[1].ending_id = document.endings[0].ending_id
			"ending_entry": document.endings[1].entry_id = document.endings[0].entry_id
			"cross_entry": document.endings[0].entry_id = document.days[0].entry_id
			"event":
				document.days[1].terminal.event_id = document.days[0].terminal.event_id
				document.days[1].terminal.label = document.days[0].terminal.label
			"label": document.days[1].terminal.label = document.days[0].terminal.label
		_refuses(RULES.plan_new_run(document), &"registration_invalid")

func test_complete_document_is_revalidated_for_every_plan() -> void:
	var document: Dictionary = FIXTURE.document()
	assert_true(_complete(document, 1).ok)
	document.days[6].terminal.successor_id = "TEST.day8"
	_refuses(RULES.plan_new_run(document), &"registration_invalid")
	_refuses(_complete(document, 1), &"registration_invalid")

func test_envelope_shapes_types_and_nonterminal_events_refuse() -> void:
	var document: Dictionary = FIXTURE.document()
	var position: Dictionary = FIXTURE.position(document, 1)
	for value: Variant in [null, [], {}, "EOF", 1]:
		_refuses(RULES.plan_completion(document, 1, value, position), &"event_invalid")
	var sample: Dictionary = FIXTURE.envelope(document, 1)
	for key: String in sample:
		var event: Dictionary = sample.duplicate(true)
		event.erase(key)
		_refuses(RULES.plan_completion(document, 1, event, position), &"event_invalid")
	for key: String in sample:
		var event: Dictionary = sample.duplicate(true)
		event[key] = null
		_refuses(RULES.plan_completion(document, 1, event, position), &"event_invalid")
	var event: Dictionary = sample.duplicate(true)
	event.extra = true
	_refuses(RULES.plan_completion(document, 1, event, position), &"event_invalid")
	event = sample.duplicate(true)
	event.kind = "notification.clear"
	event.payload = {"notification_id": "TEST.notice"}
	_refuses(RULES.plan_completion(document, 1, event, position), &"event_invalid")

func test_source_payload_and_marker_mismatches_refuse() -> void:
	var document: Dictionary = FIXTURE.document()
	for key: String in ["entry_id", "content_version"]:
		var event: Dictionary = FIXTURE.envelope(document, 1)
		event.source[key] = "TEST.other" if key == "entry_id" else 2
		_refuses(RULES.plan_completion(document, 1, event, FIXTURE.position(document, 1)), &"source_mismatch")
	var event: Dictionary = FIXTURE.envelope(document, 1)
	event.payload.source_day = 2
	_refuses(RULES.plan_completion(document, 1, event, FIXTURE.position(document, 1)), &"source_mismatch")
	for key: String in ["event_id", "ordinal", "predecessor", "successor_id"]:
		event = FIXTURE.envelope(document, 1)
		if key == "successor_id": event.payload[key] = "TEST.wrong"
		else: event[key] = 1 if key == "ordinal" else "TEST.wrong"
		_refuses(RULES.plan_completion(document, 1, event, FIXTURE.position(document, 1)), &"marker_mismatch")

func test_nested_envelope_members_keep_existing_strict_shape_law() -> void:
	var document: Dictionary = FIXTURE.document()
	var position: Dictionary = FIXTURE.position(document, 1)
	for part: String in ["source", "payload"]:
		var sample: Dictionary = FIXTURE.envelope(document, 1)
		for key: String in sample[part]:
			var missing: Dictionary = sample.duplicate(true)
			missing[part].erase(key)
			_refuses(RULES.plan_completion(document, 1, missing, position), &"event_invalid")
			var bad_type: Dictionary = sample.duplicate(true)
			bad_type[part][key] = []
			_refuses(RULES.plan_completion(document, 1, bad_type, position), &"event_invalid")
		var extra: Dictionary = sample.duplicate(true)
		extra[part].extra = true
		_refuses(RULES.plan_completion(document, 1, extra, position), &"event_invalid")
	for value: Variant in [true, 1.0, "1"]:
		var event: Dictionary = FIXTURE.envelope(document, 1)
		event.payload.source_day = value
		_refuses(RULES.plan_completion(document, 1, event, position), &"event_invalid")

func test_observed_position_is_exact_and_closed() -> void:
	var document: Dictionary = FIXTURE.document()
	var event: Dictionary = FIXTURE.envelope(document, 1)
	for value: Variant in [null, [], {}, "EOF", 1]:
		_refuses(RULES.plan_completion(document, 1, event, value), &"marker_mismatch")
	for key: String in RULES.POSITION_KEYS:
		for value: Variant in [null, "TEST.wrong", 1, &"TEST.wrong"]:
			var position: Dictionary = FIXTURE.position(document, 1)
			position[key] = value
			_refuses(RULES.plan_completion(document, 1, event, position), &"marker_mismatch")
		var missing: Dictionary = FIXTURE.position(document, 1)
		missing.erase(key)
		_refuses(RULES.plan_completion(document, 1, event, missing), &"marker_mismatch")
	var extra: Dictionary = FIXTURE.position(document, 1)
	extra.extra = true
	_refuses(RULES.plan_completion(document, 1, event, extra), &"marker_mismatch")

func test_playback_token_variation_preserves_plan_but_not_semantic_mismatch() -> void:
	var document: Dictionary = FIXTURE.document()
	var event: Dictionary = FIXTURE.envelope(document, 1)
	var position: Dictionary = FIXTURE.position(document, 1)
	var first: Dictionary = RULES.plan_completion(document, 1, event, position)
	event.playback_token = "TEST.another.playback"
	assert_eq(RULES.plan_completion(document, 1, event, position), first)
	# These valid identities are shape-only inputs here; the live adapter authenticates them.
	for key: String in ["run_id", "branch_id", "causal_day_instance", "scene_occurrence"]:
		event.source[key] = "TEST.another.identity"
		assert_eq(RULES.plan_completion(document, 1, event, position), first)
	event.source.entry_id = "TEST.other"
	_refuses(RULES.plan_completion(document, 1, event, position), &"source_mismatch")
	# This asserts pure repeatability, not live token authentication or durable replay.

func test_plans_are_detached_read_only_and_all_inputs_unchanged() -> void:
	var document: Dictionary = FIXTURE.document()
	var event: Dictionary = FIXTURE.envelope(document, 7)
	var position: Dictionary = FIXTURE.position(document, 7)
	var before := [document.duplicate(true), event.duplicate(true), position.duplicate(true)]
	var first: Dictionary = RULES.plan_completion(document, 7, event, position, "TEST.ending.b")
	assert_eq([document, event, position], before)
	assert_eq(first, _complete(FIXTURE.document(), 7, "TEST.ending.b"))
	assert_true(first.is_read_only())
	assert_true(first.value.is_read_only())
	var expected: Dictionary = first.duplicate(true)
	document.endings[1].entry_id = "TEST.changed"
	event.source.entry_id = "TEST.changed"
	position.after_line_id = "TEST.changed"
	assert_eq(first, expected)
	var initial_document: Dictionary = FIXTURE.document()
	var initial: Dictionary = RULES.plan_new_run(initial_document)
	assert_true(initial.is_read_only())
	assert_true(initial.value.is_read_only())
	initial_document.days[0].entry_id = "TEST.changed"
	assert_eq(initial.value.entry_id, "TEST.day1")
	var invalid: Dictionary = FIXTURE.document()
	invalid.days[0].content_version = 1.0
	var invalid_before: Dictionary = invalid.duplicate(true)
	_refuses(RULES.plan_new_run(invalid), &"registration_invalid")
	assert_eq(invalid, invalid_before)
