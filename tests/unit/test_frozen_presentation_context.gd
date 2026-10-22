extends "res://addons/gut/test.gd"

const CONTEXT := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const DECK := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const SOLO := "dating.solo.priscilla.day2.pre_challenge"

static func solo_fields(entry_id: String = SOLO) -> Dictionary:
	return {"entry_id": entry_id, "entry_role": "solo_pre_challenge", "day": 2,
		"friend_id": "priscilla", "tier": "friend", "tone": "sweet", "attitude": "",
		"run_id": "fixture:run", "branch_id": "fixture:branch",
		"challenge_slot": "dating.solo.priscilla.day2", "phase": "pre_challenge",
		"due_echoes": [], "attempt_residue_id": null}

func test_every_manifest_entry_has_an_exact_schema_and_rejects_every_missing_field() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTEXT.ENTRIES_PATH))
	assert_eq(manifest.entries.size(), 137)
	for entry: Dictionary in manifest.entries:
		var schema: Dictionary = CONTEXT.schema_for_entry(entry.entry_id)
		assert_true(schema.ok, str(schema))
		if not schema.ok: continue
		assert_eq(schema.value.schema_id, entry.context_schema_id)
		var fields := _fixture_fields(schema.value)
		var built := CONTEXT.build(entry.entry_id, fields)
		assert_true(built.ok, entry.entry_id + ":" + str(built))
		if not built.ok: continue
		for key: String in fields:
			var missing := fields.duplicate(true)
			missing.erase(key)
			assert_false(CONTEXT.build(entry.entry_id, missing).ok, entry.entry_id + ":" + key)
		var extra := fields.duplicate(true)
		extra["undeclared"] = "not admitted"
		assert_false(CONTEXT.build(entry.entry_id, extra).ok, entry.entry_id)

func test_solo_entry_binds_day_friend_role_and_no_retired_choice() -> void:
	for change: Dictionary in [{"day": 6}, {"friend_id": "lavinia"}, {"entry_role": "solo_post_challenge"},
			{"tier": "invented"}, {"tone": "neutral"}, {"attempt_residue_id": "unregistered"},
			{"special_mine_phase": "detonated"}, {"observer_capture": true}]:
		var fields := solo_fields()
		fields.merge(change, true)
		assert_false(CONTEXT.build(SOLO, fields).ok, str(change))
	var fields := solo_fields()
	var object := RefCounted.new()
	fields.tier = object
	assert_false(CONTEXT.build(SOLO, fields).ok, "object references cannot enter a frozen projection")

func test_pair_and_alone_omit_every_inapplicable_solo_field() -> void:
	for entry_id: String in ["ending.priscilla_lavinia.sweet", "ending.alone.normal"]:
		var schema := CONTEXT.schema_for_entry(entry_id)
		var fields := _fixture_fields(schema.value)
		for key: String in ["friend_id", "tier", "attitude"]:
			assert_false(fields.has(key))
			var poisoned := fields.duplicate(true)
			poisoned[key] = "neutral"
			assert_false(CONTEXT.build(entry_id, poisoned).ok, entry_id + ":" + key)

func test_pair_count_and_terminal_observation_discriminators_are_consistent() -> void:
	var entry_id := "dating.group.priscilla_lavinia.day2.post_challenge"
	var fields := _fixture_fields(CONTEXT.schema_for_entry(entry_id).value)
	assert_true(CONTEXT.build(entry_id, fields).ok)
	fields.pair_count_status = "committed"
	assert_false(CONTEXT.build(entry_id, fields).ok, "a committed count requires its receipt")
	fields.pair_count_status = "pending_rollover"
	fields.board_result = "exploded"
	assert_false(CONTEXT.build(entry_id, fields).ok, "explosion cannot promise a full observation")
	fields.observation_form = "truncated"
	fields.combination_witness_capability = false
	assert_true(CONTEXT.build(entry_id, fields).ok)

func test_reply_and_witness_must_be_exact_registered_selection_pair() -> void:
	var id := "contact.ordinary.lavinia.day1"
	var fields := _fixture_fields(CONTEXT.schema_for_entry(id).value)
	fields.phase = "after_selection"
	fields.selected_reply_id = "reply.ordinary.lavinia.day1.a"
	fields.witnessed_line_id = "line.contact.ordinary.lavinia.day1.reply.a"
	assert_true(CONTEXT.build(id, fields).ok)
	fields.witnessed_line_id = "line.contact.ordinary.lavinia.day1.reply.b"
	assert_false(CONTEXT.build(id, fields).ok)
	fields.phase = "awaiting_reply"
	assert_false(CONTEXT.build(id, fields).ok)

func test_snapshot_and_recursive_projection_do_not_alias_mutable_sources() -> void:
	var fields := solo_fields()
	var built := CONTEXT.build(SOLO, fields)
	assert_true(built.ok)
	var frozen := CONTEXT.immutable_fields(built.value)
	fields.tier = "love"
	fields.due_echoes.append({"echo_id": "not real"})
	built.value.fields.tone = "dark"
	assert_eq(frozen.tier, "friend")
	assert_eq(frozen.tone, "sweet")
	assert_true(frozen.due_echoes.is_empty())
	assert_true(frozen.is_read_only())
	assert_true(frozen.due_echoes.is_read_only())

func _fixture_fields(schema: Dictionary) -> Dictionary:
	var fields := {}
	for key: String in schema.fields:
		fields[key] = _fixture_value(schema.fields[key])
	if fields.has("combination_witness_capability"): fields.combination_witness_capability = true
	return fields

func _fixture_value(descriptor: Variant) -> Variant:
	if descriptor is Dictionary:
		if descriptor.has("const"): return int(descriptor["const"]) if descriptor["const"] is float else descriptor["const"]
		return descriptor["enum"][0]
	match descriptor:
		"id": return "fixture:issued-source"
		"bool": return false
		"no_residue", "nullable_id", "nullable_pair_friend", "nullable_group_variation", "nullable_pair_count": return null
		"ids", "participants", "echoes", "perfect_reasons": return []
		"board_result": return "cleared"
		"relationship_outcome": return "loved"
		"contact_variation": return "normal"
		"deck": return DECK.build_draw([], 0).value
		"pair_count": return {"transaction_id": "fixture:window", "outcome": "group", "counts": true, "visible": true}
		"progression": return {"evaluated": true, "promotion_applied": false, "relationship_state": "friend"}
	if CONTEXT.ENUMS.has(descriptor): return CONTEXT.ENUMS[descriptor][0]
	return null
