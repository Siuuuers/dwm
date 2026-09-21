extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const ROOT := "sandbox/root"
const RELATIVE_PATH := "profile.json"
const FINAL_PATH := ROOT + "/" + RELATIVE_PATH
const NEXT_PATH := FINAL_PATH + ".next"
const MARKER_PATH := FINAL_PATH + ".txn.json"
const BACKUP_PATH := FINAL_PATH + ".bak"
const OLD_TEXT := "{\"generation\":1}"
const NEW_TEXT := "{\"generation\":2}"

var _storage_script: Script
var _fake_ops_script: Script
var _strict_script: Script
var _writer_script: Script

func before_all() -> void:
	_storage_script = _require_script("res://scripts/infrastructure/storage/JsonFileStorage.gd")
	_fake_ops_script = _require_script("res://tests/support/FakeFileOps.gd")
	_strict_script = _require_script("res://scripts/validation/StrictJson.gd")
	_writer_script = _require_script("res://scripts/validation/CanonicalJsonWriter.gd")

func _require_script(path: String) -> Script:
	var result: Dictionary = PROBE.load_script(path)
	assert_true(result.get("ok", false), "required script must load: %s" % result)
	return result.get("value")

func _generation_validator(text: String) -> Dictionary:
	var parsed: Dictionary = _strict_script.call(&"parse_object", text)
	if not parsed.get("ok", false):
		return parsed
	var value: Dictionary = parsed["value"]
	if value.keys() != ["generation"] or typeof(value["generation"]) != TYPE_INT:
		return {"ok": false, "code": &"invalid_fixture", "message": "generation:int required"}
	return {"ok": true, "value": value.duplicate(true)}

func _seed(text_by_path: Dictionary) -> Dictionary:
	var output := {}
	for path in text_by_path:
		output[path] = str(text_by_path[path]).to_utf8_buffer()
	return output

func _restart_and_reconcile(persisted: Dictionary) -> Dictionary:
	var restarted_ops: RefCounted = _fake_ops_script.new(persisted.duplicate(true))
	var restarted: RefCounted = _storage_script.new(ROOT, restarted_ops)
	return restarted.call(&"reconcile", RELATIVE_PATH, _generation_validator)

func _hash(text: String) -> String:
	var ops: RefCounted = _fake_ops_script.new()
	return ops.call(&"sha256", text.to_utf8_buffer())

func _write_marker(marker: Dictionary) -> String:
	var emitted: Dictionary = _writer_script.call(&"stringify", marker)
	assert_true(emitted.get("ok", false), str(emitted))
	return emitted.get("value", "")

func test_absent_reconcile_write_read_replace_and_restart() -> void:
	var fake: RefCounted = _fake_ops_script.new()
	var storage: RefCounted = _storage_script.new(ROOT, fake)
	var absent: Dictionary = storage.call(&"reconcile", RELATIVE_PATH, _generation_validator)
	assert_true(absent.get("ok", false), str(absent))
	assert_false(absent.get("exists", true))
	var first: Dictionary = storage.call(&"write_atomic", RELATIVE_PATH, OLD_TEXT, _generation_validator)
	assert_true(first.get("ok", false), str(first))
	assert_eq(storage.call(&"read_text", RELATIVE_PATH).get("value"), OLD_TEXT)
	var replacement: Dictionary = storage.call(&"write_atomic", RELATIVE_PATH, NEW_TEXT, _generation_validator)
	assert_true(replacement.get("ok", false), str(replacement))
	var persisted: Dictionary = fake.call(&"snapshot_persisted")
	assert_eq((persisted[FINAL_PATH] as PackedByteArray).get_string_from_utf8(), NEW_TEXT)
	assert_eq((persisted[BACKUP_PATH] as PackedByteArray).get_string_from_utf8(), OLD_TEXT)
	assert_false(persisted.has(NEXT_PATH))
	assert_false(persisted.has(MARKER_PATH))
	var restarted: Dictionary = _restart_and_reconcile(persisted)
	assert_true(restarted.get("ok", false), str(restarted))
	assert_eq(restarted.get("hash"), _hash(NEW_TEXT))

func test_read_and_remove_require_a_fresh_unchanged_lease() -> void:
	var fake: RefCounted = _fake_ops_script.new(_seed({FINAL_PATH: OLD_TEXT}))
	var storage: RefCounted = _storage_script.new(ROOT, fake)
	assert_eq(storage.call(&"read_text", RELATIVE_PATH).get("code"), &"reconcile_required")
	assert_eq(storage.call(&"remove", RELATIVE_PATH).get("code"), &"reconcile_required")
	assert_true(storage.call(&"reconcile", RELATIVE_PATH, _generation_validator).get("ok", false))
	assert_eq(storage.call(&"read_text", RELATIVE_PATH).get("value"), OLD_TEXT)
	assert_true(fake.call(&"write_bytes", FINAL_PATH, NEW_TEXT.to_utf8_buffer()).get("ok", false))
	assert_true(fake.call(&"flush_path", FINAL_PATH).get("ok", false))
	assert_eq(storage.call(&"read_text", RELATIVE_PATH).get("code"), &"reconcile_required")

func test_remove_uses_durable_tombstone_and_cannot_resurrect_backup() -> void:
	var fake: RefCounted = _fake_ops_script.new(_seed({FINAL_PATH: NEW_TEXT, BACKUP_PATH: OLD_TEXT}))
	var storage: RefCounted = _storage_script.new(ROOT, fake)
	assert_true(storage.call(&"reconcile", RELATIVE_PATH, _generation_validator).get("ok", false))
	var removed: Dictionary = storage.call(&"remove", RELATIVE_PATH)
	assert_true(removed.get("ok", false), str(removed))
	var persisted: Dictionary = fake.call(&"snapshot_persisted")
	assert_eq(persisted.keys(), [])
	var restarted: Dictionary = _restart_and_reconcile(persisted)
	assert_true(restarted.get("ok", false), str(restarted))
	assert_false(restarted.get("exists", true))

func test_markerless_final_wins_but_unowned_next_alone_is_indeterminate() -> void:
	var old_wins_ops: RefCounted = _fake_ops_script.new(_seed({FINAL_PATH: OLD_TEXT, NEXT_PATH: NEW_TEXT}))
	var old_wins: RefCounted = _storage_script.new(ROOT, old_wins_ops)
	var reconciled: Dictionary = old_wins.call(&"reconcile", RELATIVE_PATH, _generation_validator)
	assert_true(reconciled.get("ok", false), str(reconciled))
	assert_eq(reconciled.get("hash"), _hash(OLD_TEXT))
	assert_false(old_wins_ops.call(&"snapshot_persisted").has(NEXT_PATH))
	var orphan_ops: RefCounted = _fake_ops_script.new(_seed({NEXT_PATH: NEW_TEXT}))
	var orphan: RefCounted = _storage_script.new(ROOT, orphan_ops)
	var indeterminate: Dictionary = orphan.call(&"reconcile", RELATIVE_PATH, _generation_validator)
	assert_eq(indeterminate.get("code"), &"indeterminate_transaction")
	assert_true(indeterminate.get("fatal", false))
	assert_true(orphan_ops.call(&"snapshot_persisted").has(NEXT_PATH))

func test_prepared_marker_with_outgoing_next_promotes_new_winner() -> void:
	var marker := {
		"backup_hash": null, "keep_backup": true, "next_hash": null,
		"operation": "write", "outgoing_hash": _hash(NEW_TEXT), "previous_hash": null,
		"relative_path": RELATIVE_PATH, "schema_version": 1, "stage": "prepared",
	}
	var fake: RefCounted = _fake_ops_script.new(_seed({NEXT_PATH: NEW_TEXT, MARKER_PATH: _write_marker(marker)}))
	var storage: RefCounted = _storage_script.new(ROOT, fake)
	var result: Dictionary = storage.call(&"reconcile", RELATIVE_PATH, _generation_validator)
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("hash"), _hash(NEW_TEXT))

func test_missing_validated_candidate_and_corrupt_marker_fail_closed() -> void:
	var marker := {
		"backup_hash": null, "keep_backup": true, "next_hash": _hash(NEW_TEXT),
		"operation": "write", "outgoing_hash": _hash(NEW_TEXT), "previous_hash": null,
		"relative_path": RELATIVE_PATH, "schema_version": 1, "stage": "next_validated",
	}
	var missing_ops: RefCounted = _fake_ops_script.new(_seed({MARKER_PATH: _write_marker(marker)}))
	var missing: RefCounted = _storage_script.new(ROOT, missing_ops)
	assert_eq(missing.call(&"reconcile", RELATIVE_PATH, _generation_validator).get("code"), &"indeterminate_commit")
	var corrupt_ops: RefCounted = _fake_ops_script.new(_seed({FINAL_PATH: OLD_TEXT, MARKER_PATH: "{"}))
	var corrupt: RefCounted = _storage_script.new(ROOT, corrupt_ops)
	assert_eq(corrupt.call(&"reconcile", RELATIVE_PATH, _generation_validator).get("code"), &"indeterminate_transaction")
	assert_eq(corrupt_ops.call(&"snapshot_persisted").size(), 2)

func test_first_write_failpoints_restart_to_exact_new_or_absence() -> void:
	var baseline_ops: RefCounted = _fake_ops_script.new()
	var baseline: RefCounted = _storage_script.new(ROOT, baseline_ops)
	assert_true(baseline.call(&"write_atomic", RELATIVE_PATH, NEW_TEXT, _generation_validator).get("ok", false))
	var operation_count: int = baseline_ops.call(&"operation_count")
	assert_gt(operation_count, 0)
	for ordinal in range(1, operation_count + 1):
		var failing_ops: RefCounted = _fake_ops_script.new()
		failing_ops.call(&"fail_after", ordinal)
		var failing: RefCounted = _storage_script.new(ROOT, failing_ops)
		var operation_result: Dictionary = failing.call(&"write_atomic", RELATIVE_PATH, NEW_TEXT, _generation_validator)
		assert_true(operation_result.get("ok", false) or operation_result.get("code") in [&"write_not_committed", &"indeterminate_commit"], "ordinal %d: %s" % [ordinal, operation_result])
		var persisted: Dictionary = failing_ops.call(&"snapshot_persisted")
		var restarted: Dictionary = _restart_and_reconcile(persisted)
		if restarted.get("ok", false):
			assert_true(not restarted.get("exists", false) or restarted.get("hash") == _hash(NEW_TEXT), "ordinal %d" % ordinal)
		else:
			assert_true(restarted.get("code") in [&"write_not_committed", &"indeterminate_commit", &"indeterminate_transaction"], "ordinal %d: %s" % [ordinal, restarted])

func test_path_escapes_and_unbound_validators_reject_before_mutation() -> void:
	var fake: RefCounted = _fake_ops_script.new()
	var storage: RefCounted = _storage_script.new(ROOT, fake)
	for unsafe in ["", "../profile.json", "a/../profile.json", "C:/profile.json", "user://profile.json", "a\\profile.json", "a//profile.json", "profile.json:stream", "profile" + String.chr(0xFFFD) + ".json"]:
		assert_eq(storage.call(&"reconcile", unsafe, _generation_validator).get("code"), &"invalid_relative_path", unsafe)
	assert_eq(storage.call(&"write_atomic", RELATIVE_PATH, NEW_TEXT, Callable()).get("code"), &"invalid_validator")
	assert_eq(fake.call(&"snapshot_persisted"), {})
	assert_eq(fake.call(&"operation_count"), 0, "unsafe paths and unbound validators never mutate storage")


func test_before_write_hook_runs_before_any_mutation_and_a_refusal_writes_nothing() -> void:
	var ops: RefCounted = _fake_ops_script.new(_seed({FINAL_PATH: OLD_TEXT}))
	var storage: RefCounted = _storage_script.new(ROOT, ops)
	var observed: Array = []
	var refuse: Array = [false]
	var hook: Callable = func() -> Dictionary:
		observed.append(ops.call(&"snapshot_persisted"))
		if refuse[0]: return {"ok": false, "code": &"fixture_hook_refused"}
		return {"ok": true}
	assert_true(storage.call(&"configure_before_write", hook).get("ok", false))
	assert_true(storage.call(&"configure_before_write", hook).get("ok", false), "an identical replay is idempotent")
	var other: Callable = func() -> Dictionary: return {"ok": true}
	assert_false(storage.call(&"configure_before_write", other).get("ok", false), "a second, different hook is refused")
	refuse[0] = true
	var refused: Dictionary = storage.call(&"write_atomic", RELATIVE_PATH, NEW_TEXT, _generation_validator)
	assert_false(refused.get("ok", false))
	assert_eq(refused.get("code"), &"before_write_refused")
	assert_eq(observed.size(), 1)
	assert_eq(ops.call(&"snapshot_persisted"), _seed({FINAL_PATH: OLD_TEXT}), "a refused hook leaves every byte untouched")
	refuse[0] = false
	var written: Dictionary = storage.call(&"write_atomic", RELATIVE_PATH, NEW_TEXT, _generation_validator)
	assert_true(written.get("ok", false), str(written))
	assert_eq(observed.size(), 2)
	assert_eq(observed[1], _seed({FINAL_PATH: OLD_TEXT}), "the hook ran before the new bytes reached storage")
	assert_eq(_restart_and_reconcile(ops.call(&"snapshot_persisted")).get("hash"), _hash(NEW_TEXT))
	var revision: Dictionary = storage.call(&"inspect_revision", RELATIVE_PATH)
	assert_true(revision.get("ok", false), str(revision))
	var revised: Dictionary = storage.call(&"write_atomic_if_revision", RELATIVE_PATH, OLD_TEXT, _generation_validator, str(revision.value.revision))
	assert_true(revised.get("ok", false), str(revised))
	assert_eq(observed.size(), 3, "the revision writer runs the same hook before it mutates")


func test_successful_writes_read_back_only_the_promoted_final() -> void:
	# dwm-634.1: the staged marker protocol is unchanged, but a write that succeeds trusts its own
	# flushed markers, candidate and backup. The only read after writing starts is the promoted
	# final, which every later start will read and which must re-read to the outgoing hash.
	var ops: RefCounted = _fake_ops_script.new(_seed({FINAL_PATH: OLD_TEXT}))
	var storage: RefCounted = _storage_script.new(ROOT, ops)
	var written: Dictionary = storage.call(&"write_atomic", RELATIVE_PATH, NEW_TEXT, _generation_validator)
	assert_true(written.get("ok", false), str(written))
	assert_eq(written.get("hash"), _hash(NEW_TEXT))
	assert_eq(written.get("value"), {"generation": 2})
	_assert_only_final_read_after_first_write(ops.call(&"operation_trace"), "write_atomic")
	var persisted: Dictionary = ops.call(&"snapshot_persisted")
	assert_eq((persisted[FINAL_PATH] as PackedByteArray).get_string_from_utf8(), NEW_TEXT)
	assert_eq((persisted[BACKUP_PATH] as PackedByteArray).get_string_from_utf8(), OLD_TEXT)
	assert_false(persisted.has(NEXT_PATH))
	assert_false(persisted.has(MARKER_PATH))
	assert_eq(storage.call(&"read_text", RELATIVE_PATH).get("value"), NEW_TEXT, "the new bytes hold the lease")
	var revision_ops: RefCounted = _fake_ops_script.new(_seed({FINAL_PATH: OLD_TEXT}))
	var revision_storage: RefCounted = _storage_script.new(ROOT, revision_ops)
	var revised: Dictionary = revision_storage.call(&"write_atomic_if_revision", RELATIVE_PATH, NEW_TEXT, _generation_validator, _hash(OLD_TEXT))
	assert_true(revised.get("ok", false), str(revised))
	assert_eq(revised.get("hash"), _hash(NEW_TEXT))
	_assert_only_final_read_after_first_write(revision_ops.call(&"operation_trace"), "write_atomic_if_revision")
	assert_eq(revision_ops.call(&"snapshot_persisted"), _seed({FINAL_PATH: NEW_TEXT}), "the revision writer leaves exactly the new final")
	assert_eq(revision_storage.call(&"read_text", RELATIVE_PATH).get("value"), NEW_TEXT)
	assert_eq(_restart_and_reconcile(revision_ops.call(&"snapshot_persisted")).get("hash"), _hash(NEW_TEXT))


func _assert_only_final_read_after_first_write(trace: Array, label: String) -> void:
	var first_write := -1
	var late_reads: Array = []
	for entry: Dictionary in trace:
		var operation: StringName = entry.get("operation", &"")
		if first_write < 0 and operation == &"write_bytes":
			first_write = int(entry.get("ordinal", 0))
		elif first_write >= 0 and operation == &"read_bytes":
			late_reads.append(entry.get("path"))
	assert_gt(first_write, 0, "%s must write" % label)
	assert_eq(late_reads, [FINAL_PATH], "%s reads back exactly the promoted final and nothing else" % label)


# ---- owner ruling 2026-09-14: one disk read and one hash per family artifact per write ----
#
# `write_atomic()` classifies the whole family from disk (`reconcile()`), and an owner that has to
# know what is already there has to classify it once itself before it can build its candidate. That
# is the same family read and hashed twice inside one synchronous write. The opt-in twin
# `write_atomic_reconciled()` reuses the classification the owner's OWN `reconcile()` on this
# instance and path just proved, so the family is read and hashed once before the write. Nothing
# else moves: the marker sequence, the temp write and flush, the rename order, the one read-back of
# the promoted final and every refusal code in its order are the same code path, and a caller that
# does not opt in keeps its trace call for call. The classification is consumed by the one write
# that reuses it and erased by every mutation, so it can never answer for a later write.

const RECONCILED_WRITE := "write_atomic_reconciled"


## RED-safe probe: on a tree without the opt-in twin the method does not exist, so a row that needs
## it fails once with a readable message instead of erroring out on a nonexistent call.
func _requires_reconciled_write(storage: RefCounted) -> bool:
	if storage.has_method(RECONCILED_WRITE):
		return true
	assert_true(false, "JsonFileStorage must own %s() for the deduped owner write path" % RECONCILED_WRITE)
	return false


func _read_counts(trace: Array, from_index: int = 0) -> Dictionary:
	var counts := {}
	for entry: Dictionary in trace.slice(from_index):
		if entry.get("operation", &"") == &"read_bytes":
			var path := str(entry.get("path", ""))
			counts[path] = int(counts.get(path, 0)) + 1
	return counts


func _hash_calls(trace: Array, from_index: int = 0) -> int:
	var total := 0
	for entry: Dictionary in trace.slice(from_index):
		if entry.get("operation", &"") == &"sha256":
			total += 1
	return total


func test_a_reconciled_write_reads_each_family_artifact_once_and_lands_the_same_bytes() -> void:
	var seeded := _seed({FINAL_PATH: OLD_TEXT, BACKUP_PATH: OLD_TEXT})
	var ops: RefCounted = _fake_ops_script.new(seeded)
	var storage: RefCounted = _storage_script.new(ROOT, ops)
	if not _requires_reconciled_write(storage):
		return
	var reconciled: Dictionary = storage.call(&"reconcile", RELATIVE_PATH, _generation_validator)
	assert_true(reconciled.get("ok", false), str(reconciled))
	assert_eq(reconciled.get("text"), OLD_TEXT, "reconcile hands back the exact text it just classified")
	var written: Dictionary = storage.call(RECONCILED_WRITE, RELATIVE_PATH, NEW_TEXT, _generation_validator, true)
	assert_true(written.get("ok", false), str(written))
	assert_eq(written.get("hash"), _hash(NEW_TEXT))
	assert_eq(written.get("text"), NEW_TEXT, "the one read-back that stays hands its own text back")
	var trace: Array = ops.call(&"operation_trace")
	assert_eq(_read_counts(trace), {FINAL_PATH: 2, BACKUP_PATH: 1},
		"the final is classified once and read back once; the backup is classified once")
	assert_eq(_hash_calls(trace), 4, "one hash per classified artifact, the outgoing bytes and the read-back")
	assert_eq(_reads_after_first_write(trace), [FINAL_PATH], "the only read after writing starts is the promoted final")
	# Byte for byte the untouched writer's own result over the same seed.
	var twin_ops: RefCounted = _fake_ops_script.new(seeded)
	var twin: RefCounted = _storage_script.new(ROOT, twin_ops)
	assert_true(twin.call(&"reconcile", RELATIVE_PATH, _generation_validator).get("ok", false))
	assert_true(twin.call(&"write_atomic", RELATIVE_PATH, NEW_TEXT, _generation_validator).get("ok", false))
	assert_eq(ops.call(&"snapshot_persisted"), twin_ops.call(&"snapshot_persisted"),
		"the deduped write leaves exactly the bytes the untouched writer leaves")
	assert_eq(_restart_and_reconcile(ops.call(&"snapshot_persisted")).get("hash"), _hash(NEW_TEXT))


func _reads_after_first_write(trace: Array) -> Array:
	var writing := false
	var reads: Array = []
	for entry: Dictionary in trace:
		var operation: StringName = entry.get("operation", &"")
		if operation == &"write_bytes":
			writing = true
		elif writing and operation == &"read_bytes":
			reads.append(str(entry.get("path", "")))
	return reads


func test_the_plain_write_keeps_its_own_full_reconcile_and_reread_trace() -> void:
	var ops: RefCounted = _fake_ops_script.new(_seed({FINAL_PATH: OLD_TEXT, BACKUP_PATH: OLD_TEXT}))
	var storage: RefCounted = _storage_script.new(ROOT, ops)
	assert_true(storage.call(&"reconcile", RELATIVE_PATH, _generation_validator).get("ok", false))
	var start: int = (ops.call(&"operation_trace") as Array).size()
	var written: Dictionary = storage.call(&"write_atomic", RELATIVE_PATH, NEW_TEXT, _generation_validator)
	assert_true(written.get("ok", false), str(written))
	var trace: Array = ops.call(&"operation_trace")
	assert_eq(_read_counts(trace, start), {FINAL_PATH: 2, BACKUP_PATH: 1},
		"a caller that does not opt in still reconciles the whole family inside its own write")
	assert_eq(_hash_calls(trace, start), 4, "and still hashes every artifact that reconcile reads")
	assert_true(storage.has_method(RECONCILED_WRITE),
		"the deduped path must be a separate, opt-in entry point so this trace can never change")


func test_the_fresh_classification_is_consumed_by_one_write_and_never_outlives_it() -> void:
	var ops: RefCounted = _fake_ops_script.new(_seed({FINAL_PATH: OLD_TEXT}))
	var storage: RefCounted = _storage_script.new(ROOT, ops)
	if not _requires_reconciled_write(storage):
		return
	assert_true(storage.call(&"reconcile", RELATIVE_PATH, _generation_validator).get("ok", false))
	assert_true(storage.call(RECONCILED_WRITE, RELATIVE_PATH, NEW_TEXT, _generation_validator, true).get("ok", false))
	# Foreign bytes land with no reconcile in between: the consumed classification must not answer
	# for them, so the second opt-in write classifies the family from disk itself and fails closed.
	assert_true(ops.call(&"write_bytes", FINAL_PATH, "{ not json".to_utf8_buffer()).get("ok", false))
	assert_true(ops.call(&"flush_path", FINAL_PATH).get("ok", false))
	var start: int = (ops.call(&"operation_trace") as Array).size()
	var refused: Dictionary = storage.call(RECONCILED_WRITE, RELATIVE_PATH, OLD_TEXT, _generation_validator, true)
	assert_false(refused.get("ok", true), str(refused))
	assert_eq(refused.get("code"), &"indeterminate_transaction",
		"a write with no fresh classification of its own reconciles from disk and refuses foreign bytes")
	assert_eq(int(_read_counts(ops.call(&"operation_trace"), start).get(FINAL_PATH, 0)), 1,
		"and it got there by reading the final itself")


func test_reconciled_write_failpoints_restart_to_exact_new_or_exact_previous() -> void:
	var seeded := _seed({FINAL_PATH: OLD_TEXT})
	var baseline_ops: RefCounted = _fake_ops_script.new(seeded)
	var baseline: RefCounted = _storage_script.new(ROOT, baseline_ops)
	if not _requires_reconciled_write(baseline):
		return
	assert_true(baseline.call(&"reconcile", RELATIVE_PATH, _generation_validator).get("ok", false))
	var reconcile_operations: int = baseline_ops.call(&"operation_count")
	assert_true(baseline.call(RECONCILED_WRITE, RELATIVE_PATH, NEW_TEXT, _generation_validator, true).get("ok", false))
	var operation_count: int = baseline_ops.call(&"operation_count")
	assert_gt(operation_count, reconcile_operations)
	for ordinal in range(reconcile_operations + 1, operation_count + 1):
		var failing_ops: RefCounted = _fake_ops_script.new(seeded)
		var failing: RefCounted = _storage_script.new(ROOT, failing_ops)
		assert_true(failing.call(&"reconcile", RELATIVE_PATH, _generation_validator).get("ok", false), "ordinal %d setup" % ordinal)
		failing_ops.call(&"fail_after", ordinal)
		var operation_result: Dictionary = failing.call(RECONCILED_WRITE, RELATIVE_PATH, NEW_TEXT, _generation_validator, true)
		assert_true(operation_result.get("ok", false) or operation_result.get("code") in [&"write_not_committed", &"indeterminate_commit"], "ordinal %d: %s" % [ordinal, operation_result])
		var restarted: Dictionary = _restart_and_reconcile(failing_ops.call(&"snapshot_persisted"))
		if restarted.get("ok", false):
			assert_true(restarted.get("hash") in [_hash(OLD_TEXT), _hash(NEW_TEXT)], "ordinal %d: %s" % [ordinal, restarted])
		else:
			assert_true(restarted.get("code") in [&"write_not_committed", &"indeterminate_commit", &"indeterminate_transaction"], "ordinal %d: %s" % [ordinal, restarted])
