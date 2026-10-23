extends "res://addons/gut/test.gd"

const MATERIALS := preload("res://scripts/infrastructure/save/NewRunMaterials.gd")
const PROFILE_SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const READER := preload("res://scripts/validation/StrictJson.gd")


## Reusable v3 New Run fixture for the journal suites. A caller may pass the exact candidate returned
## by DesktopIdentityNonceIssuer.prepare_continuation_allocation(); this helper invents no second
## identity and derives every other frozen byte from that candidate.
static func make_valid_fixture(allocation_candidate: Dictionary = {}, captured_dark: bool = true,
		profile_source_text: String = "") -> Dictionary:
	var allocation: Dictionary = allocation_candidate.duplicate(true) \
		if not allocation_candidate.is_empty() else make_allocation_candidate()
	var transaction_id: String = str((allocation.get("request", {}) as Dictionary).get("transaction_id", ""))
	var allocation_fingerprint: String = _canonical_sha256(allocation)
	var initial_context: Dictionary = {
		"active_app_id": null,
		"audio_context": {},
		"content_version": 1,
		"dialogic_checkpoint": {},
		"dark_mode": captured_dark,
		"route_id": "main",
	}
	var before: Dictionary = PROFILE_SCHEMA.make_defaults()
	before["preferences"]["dark_mode"]["available"] = true
	before["preferences"]["dark_mode"]["next_run_enabled"] = captured_dark
	var candidate: Dictionary = before.duplicate(true)
	candidate["preferences"]["dark_mode"]["next_run_enabled"] = false
	var before_canonical: String = _canonical_text(before)
	var outgoing_profile: String = _canonical_text(candidate)
	var raw_source: String = profile_source_text if not profile_source_text.is_empty() \
		else "\n" + before_canonical + "\n"
	var profile: Dictionary = {
		"before": before,
		"candidate": candidate,
		"captured_dark": captured_dark,
		"profile_revision": 7,
		"source_revision": raw_source.sha256_text(),
		"outgoing_text": outgoing_profile,
		"outgoing_hash": outgoing_profile.sha256_text(),
	}

	var game_state: Node = GAME_STATE.new()
	game_state.reset_game()
	var prepared: Dictionary = game_state.prepare_new_run_snapshot_input(
		str(allocation.get("run_id", "")), str(allocation.get("branch_id", "")),
		int(allocation.get("desktop_timeline_generation", -1)),
		str(allocation.get("causal_day_instance", "")),
		allocation.get("causal_day_instance_issuer_receipt", {}), captured_dark)
	game_state.free()
	if not prepared.get("ok", false):
		return prepared
	var snapshot_input: Dictionary = prepared["value"]["snapshot_input"]
	var empty_view: Dictionary = VIEW_STATE.make_empty(1,
		str(allocation.get("causal_day_instance", "")))
	if not empty_view.get("ok", false):
		return empty_view
	snapshot_input["schedule_view"] = empty_view["value"]["view"]
	var built_snapshot: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		snapshot_input, initial_context["dialogic_checkpoint"],
		initial_context["route_id"], initial_context["active_app_id"], {
			"ambience_context": {}, "ambience_context_id": "",
			"music_context": {}, "music_context_id": "",
		}, initial_context["content_version"], 1)
	if not built_snapshot.get("ok", false):
		return built_snapshot
	var built_document: Dictionary = SAVE_DOCUMENT_SCHEMA.build(
		&"autosave", null, &"day_start",
		{"checkpoint_kind": "day_start", "snapshot": built_snapshot["value"]["snapshot"]}, [],
		{"unix_seconds": 0, "utc_offset_minutes": 0, "hhmm": "00:00"})
	if not built_document.get("ok", false):
		return built_document
	var autosave_text: String = _canonical_text(built_document["value"]) + "\n"
	var materials: Dictionary = {
		"allocation_candidate": allocation,
		"autosave": {
			"source_revision": "absent",
			"outgoing_text": autosave_text,
			"outgoing_hash": autosave_text.sha256_text(),
		},
		"profile": profile,
	}
	var request_fingerprint: String = _canonical_sha256({
		"kind": "new_run",
		"transaction_id": transaction_id,
		"initial_context": initial_context,
		"new_run_materials": materials,
	})
	return {"ok": true, "value": {
		"allocation_candidate": allocation,
		"allocation_fingerprint": allocation_fingerprint,
		"initial_context": initial_context,
		"initial_context_sha256": _canonical_sha256(initial_context),
		"materials": materials,
		"request_fingerprint": request_fingerprint,
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": (allocation["request"] as Dictionary)["transaction_issuer_receipt"],
	}}


static func make_allocation_candidate() -> Dictionary:
	var namespace_value: String = "4".repeat(64)
	var transaction_receipt: Dictionary = _receipt(namespace_value, 0, "transaction_id", null)
	var run_receipt: Dictionary = _receipt(namespace_value, 1, "run_id", null)
	var branch_receipt: Dictionary = _receipt(namespace_value, 2, "branch_id", null)
	var generation_receipt: Dictionary = _receipt(namespace_value, 3, "desktop_timeline_generation", 0)
	var causal_receipt: Dictionary = _receipt(namespace_value, 4, "causal_day_instance", null)
	return {
		"schema_version": 1,
		"kind": "new_run",
		"request": {
			"existing_run_id": null,
			"kind": "new_run",
			"remap_source_transaction_ids": [],
			"source_desktop_timeline_generation": null,
			"transaction_id": transaction_receipt["token"],
			"transaction_issuer_receipt": transaction_receipt,
		},
		"root_namespace": namespace_value,
		"root_next_counter": 1,
		"run_id": run_receipt["token"],
		"run_id_issuer_receipt": run_receipt,
		"branch_id": branch_receipt["token"],
		"branch_id_issuer_receipt": branch_receipt,
		"desktop_timeline_generation": 0,
		"desktop_timeline_generation_issuer_receipt": generation_receipt,
		"causal_day_instance": causal_receipt["token"],
		"causal_day_instance_issuer_receipt": causal_receipt,
		"remap_transaction_issuer_receipts": {},
		"transaction_remap": {},
	}


static func make_intent_request(fixture_value: Dictionary) -> Dictionary:
	return {
		"allocation_candidate_fingerprint": fixture_value["allocation_fingerprint"],
		"initial_context": fixture_value["initial_context"].duplicate(true),
		"initial_context_sha256": fixture_value["initial_context_sha256"],
		"kind": "new_run",
		"new_run_materials": fixture_value["materials"].duplicate(true),
		"request_fingerprint": fixture_value["request_fingerprint"],
		"source_locator": null,
		"transaction_id": fixture_value["transaction_id"],
		"transaction_issuer_receipt": fixture_value["transaction_issuer_receipt"].duplicate(true),
	}


static func _receipt(namespace_value: String, counter: int, purpose: String,
		numeric_value: Variant) -> Dictionary:
	var token: String = "%s.%s" % [purpose,
		_sha256_text("%s\n%d\n%s" % [namespace_value, counter, purpose])]
	return {
		"counter": counter,
		"namespace": namespace_value,
		"numeric_value": numeric_value,
		"purpose": purpose,
		"receipt_id": "issuer_receipt." + _sha256_text(
			"desktop_issuer_receipt_v1\n%s\n%d\n%s\n%s" % [namespace_value, counter, purpose, token]),
		"token": token,
	}


func test_complete_material_accepts_raw_profile_source_revision_and_round_trips_detached() -> void:
	var fixture: Dictionary = make_valid_fixture({}, true)
	assert_true(fixture.get("ok", false), str(fixture))
	if not fixture.get("ok", false):
		return
	var value: Dictionary = fixture["value"]
	var validated: Dictionary = MATERIALS.validate(value["materials"], value["initial_context"],
		value["transaction_id"], value["allocation_fingerprint"])
	assert_true(validated.get("ok", false), str(validated))
	assert_ne(value["materials"]["profile"]["source_revision"],
		_canonical_text(value["materials"]["profile"]["before"]).sha256_text(),
		"source_revision binds the actual noncanonical source bytes")
	validated["value"]["materials"]["profile"]["candidate"]["gallery_unlocks"].append("ending.alone")
	assert_true((value["materials"]["profile"]["candidate"]["gallery_unlocks"] as Array).is_empty(),
		"validated output is detached from the caller")


func test_profile_material_allows_only_pending_dark_consumption_and_exact_canonical_output() -> void:
	var fixture: Dictionary = make_valid_fixture()
	assert_true(fixture.get("ok", false), str(fixture))
	if not fixture.get("ok", false):
		return
	var value: Dictionary = fixture["value"]
	var changed_preference: Dictionary = value["materials"].duplicate(true)
	changed_preference["profile"]["candidate"]["preferences"]["reading"]["reveal_speed"] = "slow"
	_rewrite_profile_output(changed_preference)
	assert_false(_validate(changed_preference, value).get("ok", true),
		"a second Profile change is refused even when its outgoing bytes and hash agree")
	var unavailable_dark: Dictionary = value["materials"].duplicate(true)
	unavailable_dark["profile"]["before"]["preferences"]["dark_mode"]["available"] = false
	unavailable_dark["profile"]["candidate"]["preferences"]["dark_mode"]["available"] = false
	_rewrite_profile_output(unavailable_dark)
	assert_false(_validate(unavailable_dark, value).get("ok", true),
		"a captured enabled Dark selector must remain available in its frozen source Profile")
	var final_newline: Dictionary = value["materials"].duplicate(true)
	final_newline["profile"]["outgoing_text"] += "\n"
	final_newline["profile"]["outgoing_hash"] = \
		str(final_newline["profile"]["outgoing_text"]).sha256_text()
	assert_false(_validate(final_newline, value).get("ok", true),
		"Profile output uses the owner's canonical no-newline convention")
	var raw_revision: Dictionary = value["materials"].duplicate(true)
	raw_revision["profile"]["source_revision"] = "a".repeat(64)
	assert_true(_validate(raw_revision, value).get("ok", false),
		"the validator retains a valid raw-byte revision without pretending it can rebuild source bytes")


func test_legacy_profile_material_whose_validation_reports_migrated_is_admitted_as_normalized() -> void:
	var fixture: Dictionary = make_valid_fixture()
	assert_true(fixture.get("ok", false), str(fixture))
	if not fixture.get("ok", false):
		return
	var value: Dictionary = fixture["value"]
	# Every entry of ProfileSchema._MINESWEEPER_VIEW_LEAVES, named here because that constant is
	# script-private; ProfileSchema admits these display defaults into a validated legacy profile.
	var admitted_display_leaves: Array[String] = [
		"minesweeper_app_beginner_cell_size", "minesweeper_app_beginner_always_fit",
		"minesweeper_app_intermediate_cell_size", "minesweeper_app_intermediate_always_fit",
		"minesweeper_app_expert_cell_size", "minesweeper_app_expert_always_fit",
		"minesweeper_challenge_cell_size", "minesweeper_challenge_always_fit",
	]
	var legacy: Dictionary = value["materials"].duplicate(true)
	for side: String in ["before", "candidate"]:
		var preferences: Dictionary = legacy["profile"][side]["preferences"]
		for leaf: String in admitted_display_leaves:
			(preferences["display"] as Dictionary).erase(leaf)
		(preferences["accessibility"] as Dictionary).erase("steady_interface")
	_rewrite_profile_output(legacy)
	var before_valid: Dictionary = PROFILE_SCHEMA.validate(legacy["profile"]["before"] as Dictionary)
	assert_true(before_valid.get("ok", false), str(before_valid))
	assert_true(before_valid.get("migrated", false),
		"the erased leaves are exactly the ones ProfileSchema admits, so validation reports migrated")
	assert_true(_validate(legacy, value).get("ok", false),
		"a legacy profile material whose validation reports migrated is admitted as normalized (dwm-6fl)")
	var foreign_candidate: Dictionary = value["materials"].duplicate(true)
	foreign_candidate["profile"]["candidate"]["preferences"]["reading"]["reveal_speed"] = "slow"
	assert_false(_validate(foreign_candidate, value).get("ok", true),
		"a non-admission difference is still refused")


func test_autosave_is_exact_initial_day_one_and_binds_context_and_allocated_identity() -> void:
	var fixture: Dictionary = make_valid_fixture()
	assert_true(fixture.get("ok", false), str(fixture))
	if not fixture.get("ok", false):
		return
	var value: Dictionary = fixture["value"]
	var wrong_sequence: Dictionary = value["materials"].duplicate(true)
	var document: Dictionary = _parse_autosave(wrong_sequence)
	document["current_snapshot"]["snapshot"]["checkpoint_sequence"] = 2
	document["current_snapshot"]["snapshot"]["checkpoint_id"] = \
		str(value["allocation_candidate"]["run_id"]) + ":2"
	_rewrite_autosave(wrong_sequence, document)
	assert_false(_validate(wrong_sequence, value).get("ok", true))
	var wrong_context: Dictionary = value["materials"].duplicate(true)
	document = _parse_autosave(wrong_context)
	document["current_snapshot"]["snapshot"]["audio_context"] = {"foreign": true}
	_rewrite_autosave(wrong_context, document)
	assert_false(_validate(wrong_context, value).get("ok", true),
		"Autosave bytes cannot substitute another runtime context")
	var wrong_identity: Dictionary = value["materials"].duplicate(true)
	document = _parse_autosave(wrong_identity)
	document["current_snapshot"]["snapshot"]["run_id"] = "foreign-run"
	document["current_snapshot"]["snapshot"]["checkpoint_id"] = "foreign-run:1"
	document["current_snapshot"]["snapshot"]["lifecycle"]["run_id"] = "foreign-run"
	_rewrite_autosave(wrong_identity, document)
	assert_false(_validate(wrong_identity, value).get("ok", true))


func test_material_and_allocation_shapes_are_closed_and_fingerprint_bound() -> void:
	var fixture: Dictionary = make_valid_fixture({}, false)
	assert_true(fixture.get("ok", false), str(fixture))
	if not fixture.get("ok", false):
		return
	var value: Dictionary = fixture["value"]
	for member: String in ["allocation_candidate", "autosave", "profile"]:
		var missing: Dictionary = value["materials"].duplicate(true)
		missing.erase(member)
		assert_false(_validate(missing, value).get("ok", true), "missing " + member)
	var extra: Dictionary = value["materials"].duplicate(true)
	extra["snapshot"] = {}
	assert_false(_validate(extra, value).get("ok", true), "duplicate snapshot storage is refused")
	assert_false(MATERIALS.validate(value["materials"], value["initial_context"],
		value["transaction_id"], "f".repeat(64)).get("ok", true),
		"allocation fingerprint is part of the decision identity")
	for malformed_receipt: Variant in [null, "receipt", []]:
		var malformed: Dictionary = value["materials"].duplicate(true)
		malformed["allocation_candidate"]["desktop_timeline_generation_issuer_receipt"] = malformed_receipt
		var changed_fingerprint: String = _canonical_sha256(malformed["allocation_candidate"])
		assert_false(MATERIALS.validate(malformed, value["initial_context"],
			value["transaction_id"], changed_fingerprint).get("ok", true),
			"malformed generation receipt is a typed refusal: " + str(malformed_receipt))
	var wrong_transaction: String = "transaction_id." + "1".repeat(64)
	assert_false(MATERIALS.validate(value["materials"], value["initial_context"],
		wrong_transaction, value["allocation_fingerprint"]).get("ok", true))


func _validate(materials: Dictionary, fixture_value: Dictionary) -> Dictionary:
	return MATERIALS.validate(materials, fixture_value["initial_context"],
		fixture_value["transaction_id"], fixture_value["allocation_fingerprint"])


func _rewrite_profile_output(materials: Dictionary) -> void:
	var outgoing: String = _canonical_text(materials["profile"]["candidate"])
	materials["profile"]["outgoing_text"] = outgoing
	materials["profile"]["outgoing_hash"] = outgoing.sha256_text()


func _parse_autosave(materials: Dictionary) -> Dictionary:
	var parsed: Dictionary = READER.parse_object(materials["autosave"]["outgoing_text"])
	assert_true(parsed.get("ok", false), str(parsed))
	return parsed.get("value", {})


func _rewrite_autosave(materials: Dictionary, document: Dictionary) -> void:
	var outgoing: String = _canonical_text(document) + "\n"
	materials["autosave"]["outgoing_text"] = outgoing
	materials["autosave"]["outgoing_hash"] = outgoing.sha256_text()


static func _canonical_text(value: Variant) -> String:
	var emitted: Dictionary = WRITER.stringify(value)
	return str(emitted.get("value", "")) if emitted.get("ok", false) else ""


static func _canonical_sha256(value: Variant) -> String:
	var text: String = _canonical_text(value)
	return text.sha256_text() if not text.is_empty() else ""


static func _sha256_text(text: String) -> String:
	return text.sha256_text()