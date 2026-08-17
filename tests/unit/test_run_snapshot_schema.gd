extends "res://addons/gut/test.gd"

const SCHEMA_PATH := "res://scripts/domain/run/RunSnapshotSchema.gd"
const SCHEDULE_STATE_SCHEMA_PATH := "res://scripts/domain/schedule/ScheduleStateSchema.gd"
const VALID_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"
const DAY8_FIXTURE := "res://tests/fixtures/snapshots/invalid_day8.json"
const SHAPES_FIXTURE := "res://tests/fixtures/snapshots/invalid_object_shapes.json"
const V3_COMMITTED_FIXTURE := "res://tests/fixtures/snapshots/v3_committed_schedule.json"

func _schema_exists() -> bool:
	return ResourceLoader.exists(SCHEMA_PATH, "Script")

func _fixture(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _snapshot_input_from(snapshot: Dictionary) -> Dictionary:
	return {
		"lifecycle": snapshot["lifecycle"],
		"gameplay": snapshot["gameplay"],
		"contacts": snapshot["contacts"],
		"committed_schedule": snapshot["committed_schedule"],
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
	assert_eq(snapshot, normalized_fixture, "build output matches the frozen v2 fixture after normalization")
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

	# v3 is now the CURRENT version (dwm-p2r.13 Task 5), so the unsupported-future probe moves to 4.
	var future := base.duplicate(true)
	future["schema_version"] = 4
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

func test_schema_version_is_three() -> void:
	assert_true(_schema_exists(), "RunSnapshotSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	assert_eq(int(schema.SCHEMA_VERSION), 3, "the committed-Schedule boundary is snapshot v3")

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
	assert_eq(int(snapshot["schema_version"]), 3, "build stamps the current version")
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
