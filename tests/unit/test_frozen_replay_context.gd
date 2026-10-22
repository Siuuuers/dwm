extends "res://addons/gut/test.gd"

const REPLAY := preload("res://scripts/narrative/FrozenReplayContext.gd")

func _solo() -> Dictionary:
	return {"entry_id": "ending.priscilla.sweet", "schema_version": 1, "fields": {
		"tier": "love", "tone": "sweet", "attitude": "affectionate", "echo_ids": [], "miss_reasons": [],
		"ending_role": "core", "ending_form": "derived_sweet", "residue": false}}

func test_replay_fields_are_detached_readonly_and_never_acquire_canonical_authority() -> void:
	var signature := _solo()
	var built := REPLAY.build(signature)
	assert_true(built.ok, str(built))
	var immutable := REPLAY.immutable_fields(signature)
	assert_true(immutable.ok)
	assert_true(immutable.value.is_read_only())
	assert_true(immutable.value.echo_ids.is_read_only())
	signature.fields.tone = "dark"
	assert_eq(built.value.fields.stored_tone, "sweet")
	assert_eq(immutable.value.stored_tone, "sweet")
	assert_eq(built.value.fields.context_source, "reached_signature")
	for key: String in ["run_id", "branch_id", "attempt_id", "step_token", "effect_receipt_id", "evidence_receipt_ids", "prerequisite_receipt_ids"]:
		assert_false(built.value.fields.has(key), key)

func test_replay_validation_rejects_added_missing_or_changed_fields() -> void:
	var signature := _solo()
	var built := REPLAY.build(signature)
	assert_true(REPLAY.validate(built.value, signature).ok)
	for changed: Dictionary in [{"step_token": "invented"}, {"stored_tone": "dark"}, {"context_source": "live_run"}]:
		var edited: Dictionary = built.value.duplicate(true)
		edited.fields.merge(changed, true)
		assert_false(REPLAY.validate(edited, signature).ok)
	var missing: Dictionary = built.value.duplicate(true)
	missing.fields.erase("attitude")
	assert_false(REPLAY.validate(missing, signature).ok)
	assert_false(REPLAY.build(signature, "canonical").ok)
	assert_false(REPLAY.build(signature, "date_rehearsal").ok)

func test_old_alone_and_ordinary_records_do_not_invent_missing_prose_selectors() -> void:
	var alone := {"entry_id": "ending.alone.normal", "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": "alone_normal"}}
	var built := REPLAY.build(alone)
	assert_true(built.ok, str(built))
	assert_false(built.value.fields.has("alone_cause"))
	for key: String in ["tier", "tone", "friend_id", "attitude"]: assert_false(built.value.fields.has(key))
	var ordinary := {"entry_id": "contact.ordinary.lavinia.day1", "schema_version": 1,
		"fields": {"tier": "friend", "tone": "sweet", "attitude": "", "echo_ids": []}}
	built = REPLAY.build(ordinary)
	assert_true(built.ok, str(built))
	assert_eq(built.value.fields.day, 1)
	for key: String in ["phase", "selected_reply_id", "witnessed_line_id"]: assert_false(built.value.fields.has(key))
