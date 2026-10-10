extends "res://addons/gut/test.gd"

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const STORE_ROOT := "presentation-chronology"
const EMPTY_CHRONOLOGY := {"first_witnessed": [], "legacy_unordered": []}

class CountingStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var writes := 0
	var failure: Dictionary = {}
	func _init(file_ops: RefCounted) -> void:
		super("presentation-chronology", file_ops)
	func write_atomic(path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary:
		writes += 1
		if not failure.is_empty(): return failure.duplicate(true)
		return super.write_atomic(path, text, validator, keep_backup)

func _manager(storage: RefCounted) -> Node:
	var manager := MANAGER.new()
	autofree(manager)
	var initialized: Dictionary = manager.initialize(storage)
	assert_true(initialized.get("ok", false), str(initialized))
	return manager

func _alone(dark: bool = false) -> Dictionary:
	return {"schema_version": 1, "entry_id": "ending.alone.dark_mode" if dark else "ending.alone.normal",
		"fields": {"ending_role": "core", "ending_form": "alone_dark_mode" if dark else "alone_normal"}}

func _date() -> Dictionary:
	return {"schema_version": 1, "entry_id": "dating.solo.lavinia.day2.pre_challenge",
		"fields": {"tier": "ambiguous", "tone": "sweet", "attitude": "neutral", "echo_ids": []}}

func _id(signature: Dictionary) -> String:
	var checked := SIGNATURE.validate(signature)
	assert_true(checked.ok, str(checked))
	return str(checked.value.signature_id)

func _v8(signatures: Array) -> Dictionary:
	var source := SCHEMA.make_defaults()
	source.schema_version = 8
	source.erase("reached_presentation_chronology")
	source.erase("witnessed_caption_variants")
	for signature: Dictionary in signatures:
		source.reached_presentations[_id(signature)] = signature.duplicate(true)
	return source

func _record_ids(result: Dictionary) -> Array:
	var ids: Array = []
	for record: Dictionary in result.value.records: ids.append(record.signature_id)
	return ids

func test_v8_upgrade_preserves_signatures_and_explicitly_unknown_order() -> void:
	var source := _v8([_alone(true), _alone()])
	var before := source.duplicate(true)
	var migrated := MIGRATION.prepare_document(source)
	assert_true(migrated.ok, str(migrated))
	if not migrated.ok: return
	assert_eq(migrated.value.schema_version, 10)
	assert_eq(migrated.migration_id, &"profile_v8_to_v10")
	assert_eq(migrated.value.witnessed_caption_variants, {}, "legacy membership does not invent exact captions")
	assert_eq(migrated.value.reached_presentations, before.reached_presentations)
	var membership: Array = before.reached_presentations.keys()
	membership.sort()
	assert_eq(migrated.value.reached_presentation_chronology,
		{"first_witnessed": [], "legacy_unordered": membership})
	assert_eq(source, before, "migration is detached and does not infer insertion order")
	assert_true(SCHEMA.validate(migrated.value).ok)
	assert_false(SCHEMA.validate(source).ok, "v8 remains an explicit migration source")
	var extra := source.duplicate(true)
	extra.reached_presentation_chronology = EMPTY_CHRONOLOGY.duplicate(true)
	assert_false(MIGRATION.prepare_document(extra).ok, "historical root shape stays exact")
	var corrupt := source.duplicate(true)
	corrupt.reached_presentations[_id(_alone())].fields.ending_form = "invented"
	assert_false(MIGRATION.prepare_document(corrupt).ok, "v8 signatures are validated before migration")

func test_first_witness_order_is_durable_and_duplicate_completion_is_write_free() -> void:
	var storage := CountingStorage.new(OPS.new())
	var manager := _manager(storage)
	var signatures: Array[Dictionary] = [_alone(), _alone(true)]
	signatures.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _id(a) < _id(b))
	var oldest := _id(signatures[0])
	var newest := _id(signatures[1])
	assert_true(manager.record_reached_presentation(signatures[0]).ok)
	assert_true(manager.record_reached_presentation(signatures[1]).ok)
	var before: Dictionary = manager.get_profile_snapshot()
	var revision: int = manager.get_profile_revision()
	var writes := storage.writes
	assert_true(manager.record_reached_presentation(signatures[0]).value.already_reached)
	assert_eq(storage.writes, writes)
	assert_eq(manager.get_profile_revision(), revision)
	assert_eq(manager.get_profile_snapshot(), before)
	var result: Dictionary = manager.get_reached_presentations()
	assert_eq(_record_ids(result), [newest, oldest], "first-witness order replaces lexical hash order")
	assert_eq(result.value.chronology, {"first_witnessed": [oldest, newest], "legacy_unordered": []})
	result.value.chronology.first_witnessed.clear()
	result.value.records[0].signature.fields.clear()
	assert_eq(manager.get_profile_snapshot(), before, "query projections are detached")
	var restarted := _manager(storage)
	assert_eq(restarted.get_profile_snapshot(), before)
	assert_eq(_record_ids(restarted.get_reached_presentations()), [newest, oldest])
	assert_eq(storage.writes, writes, "current read/reload never rewrites chronology")

func test_v8_migration_write_failure_does_not_publish_or_change_older_profile_bytes() -> void:
	var source := _v8([_alone()])
	var ops := OPS.new({STORE_ROOT + "/profile.json": JSON.stringify(source).to_utf8_buffer()})
	var storage := CountingStorage.new(ops)
	storage.failure = {"ok": false, "code": &"fixture_write_failed"}
	var persisted: Dictionary = ops.snapshot_persisted()
	var manager := MANAGER.new()
	autofree(manager)
	watch_signals(manager)
	assert_false(manager.initialize(storage).ok)
	assert_signal_emit_count(manager, "profile_restored", 0)
	assert_eq(manager.get_profile_snapshot(), {})
	assert_eq(ops.snapshot_persisted(), persisted)
	storage.failure.clear()
	var restarted := _manager(storage)
	assert_eq(restarted.get_profile_snapshot().reached_presentations, source.reached_presentations)
	assert_eq(restarted.get_profile_snapshot().reached_presentation_chronology,
		{"first_witnessed": [], "legacy_unordered": [_id(_alone())]})

func test_failed_atomic_write_keeps_both_membership_and_chronology_then_retry_commits_once() -> void:
	var ops := OPS.new()
	var storage := CountingStorage.new(ops)
	var manager := _manager(storage)
	assert_true(manager.record_reached_presentation(_alone()).ok)
	var before: Dictionary = manager.get_profile_snapshot()
	var persisted: Dictionary = ops.snapshot_persisted()
	var revision: int = manager.get_profile_revision()
	storage.failure = {"ok": false, "code": &"fixture_write_failed"}
	assert_false(manager.record_reached_presentation(_date()).ok)
	assert_eq(manager.get_profile_snapshot(), before)
	assert_eq(manager.get_profile_revision(), revision)
	assert_eq(ops.snapshot_persisted(), persisted)
	storage.failure.clear()
	assert_true(manager.record_reached_presentation(_date()).ok)
	assert_eq(_record_ids(manager.get_reached_presentations()), [_id(_date()), _id(_alone())])
	var writes := storage.writes
	assert_true(manager.record_reached_presentation(_date()).value.already_reached)
	assert_eq(storage.writes, writes)
	assert_eq(_manager(storage).get_profile_snapshot(), manager.get_profile_snapshot())

func test_indeterminate_write_latches_before_another_chronology_append() -> void:
	var storage := CountingStorage.new(OPS.new())
	var manager := _manager(storage)
	var before: Dictionary = manager.get_profile_snapshot()
	storage.failure = {"ok": false, "code": &"indeterminate_commit", "fatal": true}
	assert_eq(manager.record_reached_presentation(_alone()).get("code"), &"indeterminate_commit")
	storage.failure.clear()
	var writes := storage.writes
	assert_eq(manager.record_reached_presentation(_date()).get("code"), &"indeterminate_commit")
	assert_eq(storage.writes, writes)
	assert_eq(manager.get_profile_snapshot(), before)

func test_schema_requires_complete_disjoint_and_closed_chronology_provenance() -> void:
	var valid := SCHEMA.make_defaults()
	var first := _id(_alone())
	var second := _id(_alone(true))
	valid.reached_presentations = {first: _alone(), second: _alone(true)}
	valid.reached_presentation_chronology = {"first_witnessed": [first], "legacy_unordered": [second]}
	assert_true(SCHEMA.validate(valid).ok)
	var invalid_chronologies: Array = [
		null, [], {}, {"first_witnessed": [first], "legacy_unordered": [second], "time": 1},
		{"first_witnessed": [first, first], "legacy_unordered": [second]},
		{"first_witnessed": [first], "legacy_unordered": [first, second]},
		{"first_witnessed": [], "legacy_unordered": [second]},
		{"first_witnessed": [first, "unknown"], "legacy_unordered": [second]},
		{"first_witnessed": [first, 2], "legacy_unordered": [second]},
	]
	for chronology: Variant in invalid_chronologies:
		var invalid := valid.duplicate(true)
		invalid.reached_presentation_chronology = chronology
		var checked := SCHEMA.validate(invalid)
		assert_false(checked.ok, str(chronology))
		assert_true(str(checked.get("path", "")).begins_with("reached_presentation_chronology"), str(checked))
	var unsorted := valid.duplicate(true)
	var legacy: Array = [first, second]
	legacy.sort()
	legacy.reverse()
	unsorted.reached_presentation_chronology = {"first_witnessed": [], "legacy_unordered": legacy}
	assert_false(SCHEMA.validate(unsorted).ok, "unordered membership has one canonical representation")

func test_ordinary_commit_and_restore_cannot_reorder_or_downgrade_known_history() -> void:
	var storage := CountingStorage.new(OPS.new())
	var manager := _manager(storage)
	assert_true(manager.record_reached_presentation(_alone()).ok)
	var older: Dictionary = manager.get_profile_snapshot()
	assert_true(manager.record_reached_presentation(_alone(true)).ok)
	var before: Dictionary = manager.get_profile_snapshot()
	var reordered := before.duplicate(true)
	reordered.reached_presentation_chronology.first_witnessed.reverse()
	var downgraded := before.duplicate(true)
	var membership: Array = before.reached_presentations.keys()
	membership.sort()
	downgraded.reached_presentation_chronology = {"first_witnessed": [], "legacy_unordered": membership}
	var writes := storage.writes
	for altered: Dictionary in [reordered, downgraded]:
		assert_true(SCHEMA.validate(altered).ok, "the no-rewrite owner guard, not shape validation, must refuse")
		assert_eq(manager.commit_prepared_profile(altered).get("code"), &"presentation_chronology_rewrite")
		assert_eq(manager.apply_restore_silent({"profile": altered}).get("code"), &"presentation_chronology_rewrite")
		assert_eq(manager.get_profile_snapshot(), before)
	assert_false(manager.apply_restore_silent({"profile": older}).ok, "an older run cannot erase a reached version")
	assert_eq(storage.writes, writes)
	assert_true(manager.apply_restore_silent({"profile": before}).ok)
	assert_true(manager.rollback_restore_silent({"profile": before}).ok)
	assert_eq(manager.get_profile_snapshot(), before)

func test_legacy_rewitness_stays_unknown_and_new_witnesses_precede_unknown_membership() -> void:
	var source := _v8([_alone(), _alone(true)])
	var ops := OPS.new({STORE_ROOT + "/profile.json": JSON.stringify(source).to_utf8_buffer()})
	var storage := CountingStorage.new(ops)
	var manager := _manager(storage)
	var migrated: Dictionary = manager.get_profile_snapshot()
	var writes := storage.writes
	assert_true(manager.record_reached_presentation(_alone()).value.already_reached)
	assert_eq(storage.writes, writes)
	assert_eq(manager.get_profile_snapshot(), migrated)
	assert_true(manager.record_reached_presentation(_date()).ok)
	var result: Dictionary = manager.get_reached_presentations()
	var legacy: Array = source.reached_presentations.keys()
	legacy.sort()
	assert_eq(_record_ids(result), [_id(_date())] + legacy)
	assert_eq(result.value.chronology, {"first_witnessed": [_id(_date())], "legacy_unordered": legacy})
	var filtered: Dictionary = manager.get_reached_presentations(_alone().entry_id)
	assert_eq(filtered.value.chronology, {"first_witnessed": [], "legacy_unordered": [_id(_alone())]})
	var before: Dictionary = manager.get_profile_snapshot()
	var invented := before.duplicate(true)
	invented.reached_presentation_chronology.legacy_unordered.erase(_id(_alone()))
	invented.reached_presentation_chronology.first_witnessed.append(_id(_alone()))
	assert_true(SCHEMA.validate(invented).ok)
	assert_eq(manager.commit_prepared_profile(invented).get("code"), &"presentation_chronology_rewrite")
	assert_eq(manager.apply_restore_silent({"profile": invented}).get("code"), &"presentation_chronology_rewrite")
	assert_eq(_manager(storage).get_profile_snapshot(), before)

func test_resets_preserve_or_clear_chronology_with_its_reached_signatures_atomically() -> void:
	var source := _v8([_alone()])
	var storage := CountingStorage.new(OPS.new({STORE_ROOT + "/profile.json": JSON.stringify(source).to_utf8_buffer()}))
	var manager := _manager(storage)
	assert_true(manager.record_reached_presentation(_date()).ok)
	var chronology: Dictionary = manager.get_profile_snapshot().reached_presentation_chronology.duplicate(true)
	assert_true(manager.reset_preferences().ok)
	assert_true(manager.reset_visited_history().ok)
	assert_eq(manager.get_profile_snapshot().reached_presentation_chronology, chronology)
	var before: Dictionary = manager.get_profile_snapshot()
	storage.failure = {"ok": false, "code": &"fixture_write_failed"}
	assert_false(manager.reset_gallery().ok)
	assert_eq(manager.get_profile_snapshot(), before)
	storage.failure.clear()
	assert_true(manager.reset_gallery().ok)
	assert_eq(manager.get_profile_snapshot().reached_presentations, {})
	assert_eq(manager.get_profile_snapshot().reached_presentation_chronology, EMPTY_CHRONOLOGY)
	assert_true(manager.record_reached_presentation(_alone()).ok)
	assert_eq(manager.get_profile_snapshot().reached_presentation_chronology.first_witnessed, [_id(_alone())])
	assert_true(manager.reset_entire_profile().ok)
	assert_eq(manager.get_profile_snapshot().reached_presentations, {})
	assert_eq(manager.get_profile_snapshot().reached_presentation_chronology, EMPTY_CHRONOLOGY)
