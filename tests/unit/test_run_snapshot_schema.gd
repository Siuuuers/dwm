extends "res://addons/gut/test.gd"

const SCHEMA_PATH := "res://scripts/domain/run/RunSnapshotSchema.gd"
const SCHEDULE_STATE_SCHEMA_PATH := "res://scripts/domain/schedule/ScheduleStateSchema.gd"
const VALID_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"
const DAY8_FIXTURE := "res://tests/fixtures/snapshots/invalid_day8.json"
const SHAPES_FIXTURE := "res://tests/fixtures/snapshots/invalid_object_shapes.json"
const V3_COMMITTED_FIXTURE := "res://tests/fixtures/snapshots/v3_committed_schedule.json"
const CANONICAL_JSON_PATH := "res://scripts/validation/CanonicalJsonWriter.gd"

func _schema_exists() -> bool:
	return ResourceLoader.exists(SCHEMA_PATH, "Script")

## Test-authored current cases reuse historical fixture payloads without changing those files.
## Explicit Dark=false and removed retired fields are fixture authoring, never a save migration.
func _issuer_receipt(token: String) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-" + token, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": token, "numeric_value": null}

func _empty_desktop() -> Dictionary:
	return {
		"board": {"schema_version": 1, "phase": "NONE", "revision": 0, "identity": null,
			"candidate": null, "board": null, "settlement": null, "command_receipts": {}, "terminal_receipts": {}},
		"consequence": {"schema_version": 1, "run_revision": 0, "causal_sequence": 0,
			"causal_day_instance": "causal-day-1",
			"causal_day_instance_issuer_receipt": _issuer_receipt("causal-day-1"),
			"pending": null, "outbox": {}, "shop_ledger": {"supportz_branch_purchase_count": 0,
				"supportz_last_purchase_causal_day_instance": "", "base_completion_receipts": []}},
	}

func _current_fixture(snapshot: Dictionary) -> Dictionary:
	var upgraded := snapshot.duplicate(true)
	upgraded["schema_version"] = 6
	upgraded["gameplay"].erase("opening_seen")
	upgraded["gameplay"].erase("tutorial_seen")
	var lifecycle: Dictionary = (upgraded["lifecycle"] as Dictionary).duplicate(true)
	lifecycle["dark_mode"] = false
	lifecycle["active_condition_hospital_plan"] = null
	lifecycle["condition_hospital_history"] = {}
	lifecycle["terminal_intent_handoff"] = null
	if not lifecycle.has("branch_id"):
		lifecycle["branch_id"] = "branch-1"
		lifecycle["desktop_timeline_generation"] = 0
		lifecycle["causal_day_instance"] = "causal-day-1"
		lifecycle["causal_day_instance_issuer_receipt"] = _issuer_receipt("causal-day-1")
		lifecycle["restore_provenance"] = null
	upgraded["lifecycle"] = lifecycle
	if not upgraded.has("desktop"):
		upgraded["desktop"] = _empty_desktop()
	upgraded["schedule_view"] = {
		"day": lifecycle["day"],
		"causal_day_instance": lifecycle["causal_day_instance"],
		"entries": [],
		"date_entry_seen": false,
		"pending_warning": null,
		"consumed_warning_receipts": {},
		"condition_departure_receipts": {},
	}
	return upgraded

func _fixture(path: String) -> Dictionary:
	return _current_fixture(JSON.parse_string(FileAccess.get_file_as_string(path)))

func _snapshot_input_from(snapshot: Dictionary) -> Dictionary:
	return {
		"lifecycle": snapshot["lifecycle"],
		"gameplay": snapshot["gameplay"],
		"contacts": snapshot["contacts"],
		"committed_schedule": snapshot["committed_schedule"],
		"desktop": snapshot["desktop"],
		"schedule_view": snapshot["schedule_view"],
		"dating": snapshot["dating"],
		"applied_effect_transaction_ids": snapshot["applied_effect_transaction_ids"],
		"applied_variable_transaction_ids": snapshot["applied_variable_transaction_ids"],
	}

func test_run_snapshot_schema_exists() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")

func test_build_produces_exact_valid_shape() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var fixture := _fixture(VALID_FIXTURE)
	var built: Dictionary = schema.build(
		_snapshot_input_from(fixture), {}, "main", null, {}, 1, 42)
	assert_true(built.get("ok", false), JSON.stringify(built))
	var snapshot: Dictionary = built["value"]["snapshot"]
	var normalized_fixture: Dictionary = schema.validate(fixture)["value"]["candidate"]
	assert_eq(snapshot, normalized_fixture, "build output matches the explicitly authored current fixture after normalization")
	assert_true(schema.validate(built["value"]["snapshot"])["ok"])

func test_validate_accepts_fixture_and_rejects_day8_and_shapes() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	assert_true(schema.validate(_fixture(VALID_FIXTURE))["ok"], "valid day-3 fixture validates")
	assert_false(schema.validate(_fixture(DAY8_FIXTURE)).get("ok", true), "Day 8 rejects")
	assert_false(schema.validate(_fixture(SHAPES_FIXTURE)).get("ok", true), "malformed shapes reject")

func test_validate_rejection_matrix() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var base := _fixture(VALID_FIXTURE)

	# v6 is current; the unsupported-future probe must remain newer.
	var future := base.duplicate(true)
	future["schema_version"] = 7
	assert_false(schema.validate(future).get("ok", true), "unsupported future schema version rejects")

	var non_integral := base.duplicate(true)
	non_integral["checkpoint_sequence"] = 42.5
	assert_false(schema.validate(non_integral).get("ok", true), "non-integral sequence rejects")

	var integral_float := base.duplicate(true)
	integral_float["checkpoint_sequence"] = 42.0
	integral_float["lifecycle"]["day"] = 3.0
	assert_true(schema.validate(integral_float).get("ok", false), "JSON integral numbers normalize to integers")

	var duplicate_ids := base.duplicate(true)
	duplicate_ids["applied_effect_transaction_ids"] = ["t-1", "t-1"]
	assert_false(schema.validate(duplicate_ids).get("ok", true), "duplicate transaction IDs reject")

	var unknown_gameplay := base.duplicate(true)
	unknown_gameplay["gameplay"]["mystery_field"] = 1
	assert_false(schema.validate(unknown_gameplay).get("ok", true), "unregistered gameplay key rejects")

	var unregistered_variable := base.duplicate(true)
	unregistered_variable["gameplay"]["narrative_variables"] = {"unregistered": true}
	assert_false(schema.validate(unregistered_variable).get("ok", true),
		"narrative_variables accepts only registered IDs (none yet)")

	var extra_key := base.duplicate(true)
	extra_key["board_state"] = {}
	assert_false(schema.validate(extra_key).get("ok", true), "unknown top-level key rejects")

	var missing_key := base.duplicate(true)
	missing_key.erase("audio_context")
	assert_false(schema.validate(missing_key).get("ok", true), "absent required field is not silently filled")

func _ending_snapshot(ending_plan: Dictionary) -> Dictionary:
	# A day-7 ENDING snapshot carrying the given ending_plan, built from the frozen day-3 fixture.
	# v3: a snapshot names ONE day, so the committed aggregate moves with the lifecycle.
	var base := _fixture(VALID_FIXTURE)
	base["lifecycle"]["day"] = 7
	base["lifecycle"]["state"] = "ENDING"
	base["lifecycle"]["ending_plan"] = ending_plan
	(base["committed_schedule"] as Dictionary)["day"] = 7
	(base["schedule_view"] as Dictionary)["day"] = 7
	return base

func test_validate_enforces_ending_id_is_a_canonical_primary() -> void:
	# A restored ending_plan is structurally valid AND semantically valid: a tampered save cannot
	# smuggle an epilogue-only or retired ending id in as the primary, nor a bogus epilogue. Restore
	# defers to DatingEndingRules.validate_ending_plan for that authority (story/05 sec 1 binary tone).
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var canonical := {"ending_id": "ending.priscilla.sweet", "epilogue_ending_id": "", "playback_receipts": {}, "playback_stage": "PRIMARY_PENDING", "source_day": 7}
	assert_true(schema.validate(_ending_snapshot(canonical)).get("ok", false), "a canonical primary ending plan validates")
	var with_epilogue := canonical.duplicate(true)
	with_epilogue["ending_id"] = "ending.sylvia.special"
	with_epilogue["epilogue_ending_id"] = "ending.priscilla_lavinia"
	assert_true(schema.validate(_ending_snapshot(with_epilogue)).get("ok", false), "a canonical primary + canonical epilogue validates")
	var epilogue_as_primary := canonical.duplicate(true)
	epilogue_as_primary["ending_id"] = "ending.priscilla_lavinia"
	assert_false(schema.validate(_ending_snapshot(epilogue_as_primary)).get("ok", true), "the epilogue-only id is never a valid primary")
	var retired_true := canonical.duplicate(true)
	retired_true["ending_id"] = "ending.priscilla.true"
	assert_false(schema.validate(_ending_snapshot(retired_true)).get("ok", true), "a retired true-path id is not a valid primary")
	var bogus_epilogue := canonical.duplicate(true)
	bogus_epilogue["epilogue_ending_id"] = "ending.sylvia.sweet"
	assert_false(schema.validate(_ending_snapshot(bogus_epilogue)).get("ok", true), "the epilogue must be empty or ending.priscilla_lavinia")

func test_validate_primitive_tree_rejects_engine_types() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	assert_true(schema.validate_primitive_tree({"a": [1, "x", null, true, 2.5]})["ok"])
	assert_false(schema.validate_primitive_tree({"a": RefCounted.new()}).get("ok", true), "Object rejects")
	assert_false(schema.validate_primitive_tree({"a": &"name"}).get("ok", true), "StringName rejects")
	assert_false(schema.validate_primitive_tree({"a": INF}).get("ok", true), "non-finite float rejects")
	assert_false(schema.validate_primitive_tree({3: "x"}).get("ok", true), "non-string key rejects")
	assert_false(schema.validate_primitive_tree({"a": PackedByteArray([1])}).get("ok", true), "packed bytes reject")
	var node := Node.new()
	assert_false(schema.validate_primitive_tree({"a": node}).get("ok", true), "Node rejects")
	node.free()

func test_prepare_candidate_is_detached() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var source := _fixture(VALID_FIXTURE)
	var prepared: Dictionary = schema.prepare_candidate(source)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	source["gameplay"]["narrative_variables"] = {"mutated": true}
	assert_eq(prepared["value"]["candidate"]["gameplay"]["narrative_variables"], {},
		"prepared candidate is recursively detached")

func test_is_compatible_bundle_checks_versions() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var bundle := {"checkpoint_kind": "day_start", "snapshot": _fixture(VALID_FIXTURE)}
	assert_true(schema.is_compatible_bundle(bundle, {"content_version": 1}))
	assert_false(schema.is_compatible_bundle(bundle, {"content_version": 2}), "content mismatch is incompatible")
	assert_false(schema.is_compatible_bundle({}, {"content_version": 1}), "empty bundle is incompatible")

func test_derive_route_restore_context_exact_shape() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var derived: Dictionary = schema.derive_route_restore_context(_fixture(VALID_FIXTURE))
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	assert_eq(derived["value"], {
		"run_id": "run-uuid",
		"day": 3,
		"lifecycle_state": "PLAYING",
		"active_app_id": null,
		"ending_plan": null,
		"contacts": {},
		"committed_schedule": {
			"schema_version": 1,
			"day": 3,
			"registry_fingerprint": null,
			"entries": [],
			"commit_receipt": null,
		},
		"dating": {},
	}, "derived context carries exactly the eight documented fields")
	assert_false(derived["value"].has("route_id"), "route_id is not duplicated into the context")
	assert_false(schema.derive_route_restore_context(_fixture(DAY8_FIXTURE)).get("ok", true),
		"derivation validates first")


# ---- dwm-p2r.13 Task 5: the v3 committed-Schedule boundary ----
# Top-level `schedule` is replaced by top-level `committed_schedule`, and `gameplay.schedule_entries`
# retires in the same boundary. Committed validation is DELEGATED to ScheduleStateSchema; this module
# owns no second copy of the aggregate law.

func test_schema_version_is_six() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	assert_eq(int(schema.SCHEMA_VERSION), 6, "the reconciled snapshot contract requires v6")

func test_top_level_committed_schedule_replaces_legacy_schedule() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	assert_true("committed_schedule" in schema.TOP_KEYS, "committed_schedule is a v3 top-level member")
	assert_false("schedule" in schema.TOP_KEYS, "the legacy top-level schedule array is gone")

	var base := _fixture(V3_COMMITTED_FIXTURE)
	assert_true(schema.validate(base).get("ok", false), "the v3 fixture validates")

	var legacy := base.duplicate(true)
	legacy["schedule"] = []
	assert_false(schema.validate(legacy).get("ok", true),
		"a v3 snapshot carrying the legacy schedule array rejects")

	var missing := base.duplicate(true)
	missing.erase("committed_schedule")
	assert_false(schema.validate(missing).get("ok", true),
		"committed_schedule is mandatory and is never silently defaulted")

func test_gameplay_schedule_entries_is_retired() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	assert_false("schedule_entries" in schema.GAMEPLAY_FIELDS,
		"gameplay.schedule_entries retires at the v3 boundary")
	var base := _fixture(V3_COMMITTED_FIXTURE)
	base["gameplay"]["schedule_entries"] = []
	assert_false(schema.validate(base).get("ok", true),
		"a surviving gameplay.schedule_entries rejects as an unregistered gameplay key")

func test_committed_schedule_validation_delegates_to_schedule_state_schema() -> void:
	# The aggregate law lives in exactly one module. RunSnapshotSchema must surface the delegate's
	# own typed code rather than inventing a parallel structural check.
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var state_schema: Script = load(SCHEDULE_STATE_SCHEMA_PATH)
	var base := _fixture(V3_COMMITTED_FIXTURE)

	var extra_member := base.duplicate(true)
	(extra_member["committed_schedule"] as Dictionary)["unexpected"] = true
	var delegate: Dictionary = state_schema.validate_aggregate(extra_member["committed_schedule"])
	assert_false(delegate.get("ok", true), "the delegate rejects an unknown aggregate member")
	var validated: Dictionary = schema.validate(extra_member)
	assert_false(validated.get("ok", true), "the snapshot rejects it too")
	assert_eq(str(validated.get("code")), str(delegate.get("code")),
		"the delegate's typed code is surfaced unchanged")

	var receiptless_nonempty := base.duplicate(true)
	(receiptless_nonempty["committed_schedule"] as Dictionary)["entries"] = [{}]
	assert_false(schema.validate(receiptless_nonempty).get("ok", true),
		"a nonempty aggregate without its commit receipt rejects")

func test_committed_schedule_day_must_equal_lifecycle_day() -> void:
	# Recorded sub-decision (dwm-p2r.13, this session): the aggregate day and the lifecycle day are
	# one fact. Step 5.2 migration makes this true by construction, so nothing legal is excluded.
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var base := _fixture(V3_COMMITTED_FIXTURE)
	assert_eq(int(base["lifecycle"]["day"]), int(base["committed_schedule"]["day"]),
		"the fixture itself is internally consistent")
	var skewed := base.duplicate(true)
	(skewed["committed_schedule"] as Dictionary)["day"] = 4
	assert_false(schema.validate(skewed).get("ok", true),
		"a committed_schedule day that disagrees with the lifecycle day rejects")

func test_committed_schedule_is_recursively_detached() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var source := _fixture(V3_COMMITTED_FIXTURE)
	var prepared: Dictionary = schema.prepare_candidate(source)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	(source["committed_schedule"] as Dictionary)["entries"] = ["mutated"]
	assert_eq(prepared["value"]["candidate"]["committed_schedule"]["entries"], [],
		"the prepared candidate does not alias the caller's aggregate")

	# ONE parsed source, reused: re-reading the fixture from disk for the second derivation would
	# make this assertion pass even if derive_route_restore_context aliased its input.
	var shared_source := _fixture(V3_COMMITTED_FIXTURE)
	var derived: Dictionary = schema.derive_route_restore_context(shared_source)
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	(derived["value"]["committed_schedule"] as Dictionary)["entries"] = ["mutated"]
	assert_eq((shared_source["committed_schedule"] as Dictionary)["entries"], [],
		"mutating the derived context cannot reach the snapshot it came from")
	var rederived: Dictionary = schema.derive_route_restore_context(shared_source)
	assert_eq(rederived["value"]["committed_schedule"]["entries"], [],
		"the derived restore context hands out a detached aggregate")

func test_v3_build_round_trips_the_aggregate_unchanged() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var fixture := _fixture(V3_COMMITTED_FIXTURE)
	var built: Dictionary = schema.build(
		_snapshot_input_from(fixture), {}, "main", null, {}, 1, 42)
	assert_true(built.get("ok", false), JSON.stringify(built))
	var snapshot: Dictionary = built["value"]["snapshot"]
	assert_eq(int(snapshot["schema_version"]), 6, "build stamps the current version")
	# JSON parsing yields floats for integral numbers, so the expectation is the schema's own
	# normalized projection of the same fixture -- not the raw parse.
	var normalized_fixture: Dictionary = schema.validate(fixture)["value"]["candidate"]
	assert_eq(snapshot["committed_schedule"], normalized_fixture["committed_schedule"],
		"the aggregate survives build byte-for-byte")
	assert_false(snapshot.has("schedule"), "build never emits the legacy member")
	assert_true(schema.validate(snapshot).get("ok", false), "the built snapshot revalidates")


# ---- dwm-p2r.9 Plan 02 Task 1: active_app_id is now gated by DesktopAppRegistry.has_app() ----
func test_validate_active_app_id_rejects_unregistered_and_accepts_registered_or_null() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var base := _fixture(VALID_FIXTURE)
	var unregistered := base.duplicate(true)
	unregistered["active_app_id"] = "not_a_real_app"
	assert_false(schema.validate(unregistered).get("ok", true), "an unregistered active_app_id rejects")
	var registered := base.duplicate(true)
	registered["active_app_id"] = &"minesweeper"
	assert_true(schema.validate(registered).get("ok", false), "a registered active_app_id validates")
	var nulled := base.duplicate(true)
	nulled["active_app_id"] = null
	assert_true(schema.validate(nulled).get("ok", false), "null active_app_id still validates")


# ---- dwm-p2r.32 Task 6: the v4 desktop aggregate ----
func test_desktop_is_a_v4_top_level_member() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	assert_true("desktop" in schema.TOP_KEYS, "desktop is a v4 top-level member")
	var base := _fixture(VALID_FIXTURE)
	var missing := base.duplicate(true)
	missing.erase("desktop")
	assert_false(schema.validate(missing).get("ok", true), "desktop is mandatory and never silently defaulted")
	var extra_desktop_key := base.duplicate(true)
	(extra_desktop_key["desktop"] as Dictionary)["extra"] = 1
	assert_false(schema.validate(extra_desktop_key).get("ok", true), "desktop carries exactly board and consequence")
	var board_only := base.duplicate(true)
	(board_only["desktop"] as Dictionary).erase("consequence")
	assert_false(schema.validate(board_only).get("ok", true), "a board-only desktop value rejects")

func test_desktop_lifecycle_identity_fields_are_exact_and_bound() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var base := _fixture(VALID_FIXTURE)
	assert_true("branch_id" in schema.LIFECYCLE_KEYS)
	assert_true("desktop_timeline_generation" in schema.LIFECYCLE_KEYS)
	assert_true("causal_day_instance" in schema.LIFECYCLE_KEYS)
	assert_true("causal_day_instance_issuer_receipt" in schema.LIFECYCLE_KEYS)
	assert_true("restore_provenance" in schema.LIFECYCLE_KEYS)

	var blank_branch := base.duplicate(true)
	(blank_branch["lifecycle"] as Dictionary)["branch_id"] = ""
	assert_false(schema.validate(blank_branch).get("ok", true), "blank branch_id rejects")

	var id_only_receipt := base.duplicate(true)
	(id_only_receipt["lifecycle"] as Dictionary)["causal_day_instance_issuer_receipt"] = {"receipt_id": "x"}
	assert_false(schema.validate(id_only_receipt).get("ok", true), "an ID-only receipt rejects")

	var mismatched_token := base.duplicate(true)
	(mismatched_token["lifecycle"] as Dictionary)["causal_day_instance_issuer_receipt"] = _issuer_receipt("some-other-token")
	assert_false(schema.validate(mismatched_token).get("ok", true),
		"a receipt whose token does not match causal_day_instance rejects")

func test_desktop_board_and_consequence_delegate_to_their_own_owners() -> void:
	# Neither module's own shape law is duplicated here; this schema surfaces their typed rejection.
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var base := _fixture(VALID_FIXTURE)
	var bad_board := base.duplicate(true)
	(bad_board["desktop"] as Dictionary)["board"] = {"phase": "NONE"}
	assert_false(schema.validate(bad_board).get("ok", true), "a malformed board rejects")
	var bad_consequence := base.duplicate(true)
	(bad_consequence["desktop"] as Dictionary)["consequence"] = {"pending": null}
	assert_false(schema.validate(bad_consequence).get("ok", true), "a malformed consequence rejects")

func test_v3_pre_desktop_fixture_lacks_the_v4_member() -> void:
	# The raw pre-desktop fixture is a genuine legacy artifact: it must NOT already carry desktop
	# (that would make the "no v3->v4 migration" law untestable at the SaveMigrations boundary).
	var raw: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/saves/v3_pre_desktop.json"))
	var snapshot: Dictionary = raw["current_snapshot"]["snapshot"]
	assert_eq(int(snapshot["schema_version"]), 3)
	assert_false(snapshot.has("desktop"), "the pre-desktop fixture carries no desktop member")
	assert_false((snapshot["lifecycle"] as Dictionary).has("branch_id"),
		"the pre-desktop fixture's lifecycle carries no v4 identity members")


func test_validate_normalizes_the_snapshot_without_a_prior_deep_copy() -> void:
	# A1: validate() deep-copies the caller's snapshot and then hands the copy to
	# _normalize_integral_floats, which already allocates a fresh Dictionary or Array at EVERY
	# container node. The copy is therefore pure waste on every one of the five validate() calls a
	# save makes. Removing it is allocation-only -- it has no value observable, because the
	# normalizer's output is byte-for-byte the same tree either way -- so the source text is the
	# observable, in the idiom of test_contact_scene_authors_no_identity_or_global_state_fallback.
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var source := FileAccess.get_file_as_string(SCHEMA_PATH)
	assert_false(source.is_empty(), "the schema source must be readable")
	assert_false(source.contains("_normalize_integral_floats(snapshot.duplicate(true))"),
		"validate() must not deep-copy the snapshot before a walk that rebuilds every container")
	assert_true(source.contains("_normalize_integral_floats(snapshot)"),
		"validate() normalizes the caller's snapshot once, in place of the discarded copy")

	# The invariant that makes the copy removable: a fresh container at every node, source untouched.
	var tree := {"envelope": {"nested": [1.0, {"leaf": 2.0}]}}
	var normalized: Variant = schema._normalize_integral_floats(tree)
	assert_false(is_same(normalized, tree), "the normalizer allocates a fresh root")
	assert_false(is_same(normalized["envelope"], tree["envelope"]),
		"the normalizer allocates a fresh Dictionary at every node")
	assert_false(is_same(normalized["envelope"]["nested"], tree["envelope"]["nested"]),
		"the normalizer allocates a fresh Array at every node")
	assert_false(is_same(normalized["envelope"]["nested"][1], tree["envelope"]["nested"][1]),
		"the normalizer allocates a fresh container inside an Array too")
	assert_eq(typeof(normalized["envelope"]["nested"][0]), TYPE_INT, "integral floats still normalize")
	assert_eq(typeof(tree["envelope"]["nested"][0]), TYPE_FLOAT, "the normalizer never mutates its source")

	# Proof obligation for the leaf types the normalizer passes through by reference rather than
	# copying (Packed arrays, Objects): none of them can ever reach a saved document, so the
	# removed copy protected nothing. Two independent owners refuse them.
	assert_eq(schema.validate_primitive_tree({"probe": PackedInt32Array([1])}).get("code", &""),
		&"invalid_primitive", "a Packed leaf is refused by the primitive sweep")
	assert_eq(schema.validate_primitive_tree({"probe": RefCounted.new()}).get("code", &""),
		&"invalid_primitive", "an Object leaf is refused by the primitive sweep")
	var packed_snapshot := _fixture(VALID_FIXTURE)
	packed_snapshot["narrative_checkpoint"] = {"probe": PackedInt32Array([1])}
	assert_eq(schema.validate(packed_snapshot).get("code", &""), &"invalid_primitive",
		"a Packed leaf inside a snapshot member is refused by validate")
	var writer: Script = load(CANONICAL_JSON_PATH)
	assert_eq(writer.stringify({"probe": PackedByteArray([1])}).get("code", &""), &"unsupported_type",
		"CanonicalJsonWriter refuses a Packed leaf, so one can never be written to disk")
	assert_eq(writer.stringify({"probe": PackedStringArray(["x"])}).get("code", &""), &"unsupported_type",
		"every Packed variant is refused, not just bytes")

func test_validate_neither_aliases_nor_mutates_the_caller_snapshot() -> void:
	# A1 guard: with the defensive deep copy gone, detachment rests entirely on the normalizer
	# rebuilding every container. Pin both directions at four independent depths so a future
	# "optimization" that shares a subtree reddens here rather than in a save file.
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var source := _fixture(VALID_FIXTURE)
	var validated: Dictionary = schema.validate(source)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	if not validated.get("ok", false):
		return
	var candidate: Dictionary = validated["value"]["candidate"]
	assert_false(is_same(candidate, source), "the candidate is not the caller's snapshot")
	assert_false(is_same(candidate["narrative_checkpoint"], source["narrative_checkpoint"]),
		"a depth-1 member is not shared")
	assert_false(is_same(candidate["gameplay"]["narrative_variables"],
		source["gameplay"]["narrative_variables"]), "a depth-2 member is not shared")
	assert_false(is_same(candidate["desktop"]["board"]["command_receipts"],
		source["desktop"]["board"]["command_receipts"]), "a depth-3 member is not shared")
	assert_false(is_same(candidate["applied_effect_transaction_ids"],
		source["applied_effect_transaction_ids"]), "an Array member is not shared")

	# Mutating the candidate cannot reach the caller.
	(candidate["narrative_checkpoint"] as Dictionary)["injected"] = true
	(candidate["gameplay"]["narrative_variables"] as Dictionary)["injected"] = true
	(candidate["desktop"]["board"]["command_receipts"] as Dictionary)["injected"] = true
	(candidate["applied_effect_transaction_ids"] as Array).append("injected")
	assert_eq((source["narrative_checkpoint"] as Dictionary).size(), 0, "depth 1 stayed clean")
	assert_eq((source["gameplay"]["narrative_variables"] as Dictionary).size(), 0, "depth 2 stayed clean")
	assert_eq((source["desktop"]["board"]["command_receipts"] as Dictionary).size(), 0, "depth 3 stayed clean")
	assert_eq((source["applied_effect_transaction_ids"] as Array).size(), 0, "the Array member stayed clean")

	# Mutating the caller cannot reach a candidate that was already handed out.
	(source["narrative_checkpoint"] as Dictionary)["late"] = true
	(source["gameplay"]["narrative_variables"] as Dictionary)["late"] = true
	(source["desktop"]["board"]["command_receipts"] as Dictionary)["late"] = true
	(source["applied_effect_transaction_ids"] as Array).append("late")
	assert_false((candidate["narrative_checkpoint"] as Dictionary).has("late"), "depth 1 stayed detached")
	assert_false((candidate["gameplay"]["narrative_variables"] as Dictionary).has("late"),
		"depth 2 stayed detached")
	assert_false((candidate["desktop"]["board"]["command_receipts"] as Dictionary).has("late"),
		"depth 3 stayed detached")
	assert_eq((candidate["applied_effect_transaction_ids"] as Array).size(), 1,
		"the Array member stayed detached")
