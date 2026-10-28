extends GutTest
## Canonical storage contract with the retained valid snapshot fixture.
const MANAGER := preload("res://autoload/SaveManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const FIXTURE := preload("res://tests/support/BackupSnapshotFixture.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

class WriteRefusal extends "res://tests/support/FakeFileOps.gd":
	var refuse_write := false
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if refuse_write: return {"ok": false, "code": &"write_failed", "message": "TEST storage write unavailable"}
		return super.write_bytes(path, bytes)

func test_existing_unmarked_document_and_detached_marked_roundtrip() -> void:
	var fixture: Dictionary = FIXTURE.make_snapshot()
	assert_true(fixture.get("ok", false), str(fixture))
	if not fixture.get("ok", false): return
	var built: Dictionary = SCHEMA.build(&"slot", 1, &"manual", {
		"checkpoint_kind": "day_start", "snapshot": fixture.value.candidate}, [])
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false): return
	assert_false(built.value.has("ink_marks"), "old documents require no new decoration")
	assert_true(SCHEMA.validate(built.value).get("ok", false))
	built.value.ink_marks = [17, 420, 9123]
	var checked: Dictionary = SCHEMA.validate(built.value)
	assert_true(checked.get("ok", false), str(checked))
	if not checked.get("ok", false): return
	assert_eq(checked.value.candidate.ink_marks, [17, 420, 9123])
	built.value.ink_marks.append(99)
	assert_eq(checked.value.candidate.ink_marks, [17, 420, 9123], "validated document owns its metadata")
	var canonical: Dictionary = preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify(checked.value.candidate)
	assert_true(canonical.get("ok", false), str(canonical))
	if not canonical.get("ok", false): return
	var parsed: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(canonical.value)
	assert_true(parsed.get("ok", false), str(parsed))
	if not parsed.get("ok", false): return
	assert_eq(parsed.value.ink_marks, [17, 420, 9123])

func test_refused_atomic_overwrite_preserves_ink_and_retry_adds_once() -> void:
	var files := WriteRefusal.new()
	var storage := STORAGE.new("memory/save-ink", files)
	var manager: Node = MANAGER.new()
	add_child_autofree(manager)
	assert_true(manager.initialize(storage).get("ok", false))
	assert_true(manager.configure_mutation_gate(GATE.new()).get("ok", false))
	var fixture: Dictionary = FIXTURE.make_snapshot()
	assert_true(fixture.get("ok", false), str(fixture))
	if not fixture.get("ok", false): return
	var snapshot: Dictionary = fixture.value.candidate
	manager._journal.reset(snapshot.run_id)
	var prepared: Dictionary = manager._journal.prepare_record(snapshot, &"day_start")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_true(manager._journal.commit_prepared(prepared.value.candidate).get("ok", false))
	var first: Dictionary = manager.save_latest_to_slot(1)
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	var original: Dictionary = JSON.parse_string(storage.read_text("slot_1.json").value)
	assert_eq(original.ink_marks.size(), 1)
	var before: Dictionary = files.snapshot_persisted()
	files.refuse_write = true
	assert_false(manager.save_latest_to_slot(1).get("ok", false))
	assert_eq(files.snapshot_persisted(), before, "failed write does not age or append durable ink")
	files.refuse_write = false
	var retry: Dictionary = manager.save_latest_to_slot(1)
	assert_true(retry.get("ok", false), str(retry))
	if not retry.get("ok", false): return
	var written: Dictionary = JSON.parse_string(storage.read_text("slot_1.json").value)
	assert_eq(written.ink_marks.size(), 2, "only successful replacement adds a splash")
	assert_eq(written.ink_marks[0], original.ink_marks[0])
