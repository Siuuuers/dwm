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
