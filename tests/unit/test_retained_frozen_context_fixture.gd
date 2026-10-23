extends "res://addons/gut/test.gd"

const FIXTURE := preload("res://tests/support/RetainedFrozenContextFixture.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const RUN_TEST := preload("res://tests/unit/test_frozen_run_context.gd")
const SNAPSHOT_TEST := preload("res://tests/unit/test_run_snapshot_schema.gd")
const ENTRY := "dating.solo.priscilla.day2.pre_challenge"
var _saved_schemas: Dictionary
var _saved_ids: Dictionary
var _fixture: RefCounted

# Exercise the real _dating early-return path, followed by its real after_each.
# No deliberate failed assertion is needed to simulate a refused context build.
class RefusedDatingBuild:
	extends "res://tests/unit/test_frozen_run_context.gd"
	func _solo_fields(_phase: String) -> Dictionary:
		return {}

func before_each() -> void:
	_saved_schemas = FROZEN._schemas
	_saved_ids = FROZEN._ids
	_fixture = FIXTURE.new()

func after_each() -> void:
	_fixture.restore()
	FROZEN._schemas = _saved_schemas
	FROZEN._ids = _saved_ids

func _assert_same_cache(schemas: Dictionary, ids: Dictionary) -> void:
	assert_true(is_same(FROZEN._schemas, schemas), "exact schema cache object restored")
	assert_true(is_same(FROZEN._ids, ids), "exact ID cache object restored")

func _assert_current_scene_build() -> void:
	var selected := MANIFEST.scene_registration()
	assert_true(selected.get("ok", false), str(selected))
	if not selected.get("ok", false): return
	var entry_id := ""
	for row: Dictionary in selected.value.context_registry.schemas:
		if row.fields.get("entry_role") == {"const": "scene"}:
			entry_id = row.entry_id
			break
	assert_false(entry_id.is_empty(), "current registration must have a scene")
	if entry_id.is_empty(): return
	var result := FROZEN.build(entry_id, {"entry_id": entry_id, "entry_role": "scene",
		"occurrence_id": "test:isolation", "admission_receipt_id": "test:isolation"})
	assert_true(result.get("ok", false), "current scene builds after teardown: " + str(result))
	assert_false(FROZEN.schema_for_entry(ENTRY).get("ok", false),
		"retained dating schema must not leak into current scene registration")

func test_empty_cache_identity_restored_before_lazy_current_scene_load() -> void:
	var schemas := {}
	var ids := {}
	FROZEN._schemas = schemas
	FROZEN._ids = ids
	assert_true(_fixture.install([ENTRY]).get("ok", false))
	assert_true(FROZEN.schema_for_entry(ENTRY).get("ok", false))
	_fixture.restore()
	_assert_same_cache(schemas, ids)
	assert_true(schemas.is_empty())
	assert_true(ids.is_empty())
	_assert_current_scene_build()

func test_populated_cache_identity_and_contents_restored() -> void:
	FROZEN._schemas = {}
	FROZEN._ids = {}
	_assert_current_scene_build()
	var schemas := FROZEN._schemas
	var ids := FROZEN._ids
	var before_schemas := schemas.duplicate(true)
	var before_ids := ids.duplicate(true)
	assert_true(_fixture.install([ENTRY]).get("ok", false))
	assert_false(is_same(FROZEN._schemas, schemas))
	assert_false(is_same(FROZEN._ids, ids))
	_fixture.restore()
	_fixture.restore() # Repeated cleanup cannot replace or clear the original objects.
	_assert_same_cache(schemas, ids)
	assert_eq(schemas, before_schemas)
	assert_eq(ids, before_ids)
	_assert_current_scene_build()

func test_failed_setup_and_reinstall_leave_cache_owner_unchanged() -> void:
	for populated: bool in [false, true]:
		FROZEN._schemas = {}
		FROZEN._ids = {}
		if populated: _assert_current_scene_build()
		var schemas := FROZEN._schemas
		var ids := FROZEN._ids
		var before_schemas := schemas.duplicate(true)
		var before_ids := ids.duplicate(true)
		for entries: Array in [[], [ENTRY, "missing:retained:entry"], [ENTRY, ENTRY]]:
			assert_false(_fixture.install(entries).get("ok", true))
			_fixture.restore()
			_assert_same_cache(schemas, ids)
			assert_eq(schemas, before_schemas, "failed setup preserves schema contents")
			assert_eq(ids, before_ids, "failed setup preserves ID contents")
		assert_true(_fixture.install([ENTRY]).get("ok", false))
		var installed_schemas := FROZEN._schemas
		var installed_ids := FROZEN._ids
		assert_false(_fixture.install([ENTRY]).get("ok", true))
		_assert_same_cache(installed_schemas, installed_ids)
		_fixture.restore()
		_assert_same_cache(schemas, ids)
		_assert_current_scene_build()

func test_dating_early_return_uses_real_suite_teardown() -> void:
	FROZEN._schemas = {}
	FROZEN._ids = {}
	_assert_current_scene_build()
	var schemas := FROZEN._schemas
	var ids := FROZEN._ids
	var suite: Node = autofree(RefusedDatingBuild.new())
	suite.gut = gut
	assert_true(suite._dating().is_empty(), "refused field build returns early")
	assert_false(is_same(FROZEN._schemas, schemas), "fixture was installed before early return")
	suite.after_each()
	assert_null(suite._retained_contexts)
	_assert_same_cache(schemas, ids)
	_assert_current_scene_build()

func test_both_historical_suites_restore_before_current_scene_in_same_process() -> void:
	FROZEN._schemas = {}
	FROZEN._ids = {}
	_assert_current_scene_build()
	var schemas := FROZEN._schemas
	var ids := FROZEN._ids
	var run_suite: Node = autofree(RUN_TEST.new())
	run_suite.gut = gut
	var snapshot_suite: Node = autofree(SNAPSHOT_TEST.new())
	snapshot_suite.gut = gut
	for suite: Node in [run_suite, snapshot_suite]:
		if suite == run_suite:
			suite.test_saved_dating_binds_run_board_and_effect_but_keeps_original_branch_and_tier()
		else:
			suite.test_v8_requires_generated_contact_context_before_preparing_a_detached_candidate()
		suite.after_each()
		assert_null(suite._retained_contexts)
		_assert_same_cache(schemas, ids)
		_assert_current_scene_build()
