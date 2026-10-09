extends "res://tests/support/FakeNarrativeCheckpointContext.gd"
## Positive prepared-save port injected below the REAL narrative adapter.
## No acknowledgement producer is replaced. This test port is not SaveManager,
## disk durability, a supported Save8 scene document, or a scene receipt issuer.
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
var current: Dictionary = {}
var prepared_object: Dictionary = {}
var committed_same_object := false
var after_prepare: Callable
var before_capture: Callable
var before_commit: Callable
var commit_count := 0
var rollback_count := 0

static func digest(value: Variant) -> String:
	var encoded := JSON_WRITER.stringify(value)
	return str(encoded.value).sha256_text() if encoded.ok else ""

func capture() -> Dictionary:
	calls.append("capture")
	if before_capture.is_valid(): before_capture.call()
	return {"ok": true, "value": {"backup": {"current": {"snapshot": current.duplicate(true)}}}}

func prepare(inputs: Dictionary, _kind: StringName, _disk: Dictionary) -> Dictionary:
	calls.append("prepare")
	if not prepare_ok: return {"ok": false, "code": &"prepared_port_refused"}
	var snapshot := {"checkpoint_id": "composition:target", "checkpoint_sequence": 2,
		"narrative_checkpoint": inputs.dialogic_checkpoint.duplicate(true),
		"payload": inputs.snapshot_input.duplicate(true)}
	prepared_object = {"checkpoint_id": snapshot.checkpoint_id,
		"journal_candidate": {"current": {"snapshot": snapshot}},
		"autosave_document": {"current_snapshot": {"snapshot": snapshot.duplicate(true)}},
		"storage_backup": {"original": current.duplicate(true)}}
	if after_prepare.is_valid(): after_prepare.call()
	return {"ok": true, "value": {"candidate": prepared_object, "checkpoint_id": snapshot.checkpoint_id}}

func commit(candidate: Dictionary) -> Dictionary:
	calls.append("commit")
	commit_count += 1
	committed_same_object = is_same(candidate, prepared_object)
	if before_commit.is_valid(): before_commit.call()
	if not commit_ok: return {"ok": false, "code": &"prepared_port_write_refused"}
	current = candidate.journal_candidate.current.snapshot.duplicate(true)
	return {"ok": true, "value": {"checkpoint_id": candidate.checkpoint_id}}

func rollback(backup: Dictionary) -> Dictionary:
	calls.append("rollback")
	rollback_count += 1
	if not rollback_ok: return {"ok": false, "code": &"prepared_port_rollback_uncertain"}
	current = backup.journal_backup.current.snapshot.duplicate(true)
	return {"ok": true}

func dispose_callbacks() -> void:
	after_prepare = Callable()
	before_capture = Callable()
	before_commit = Callable()

