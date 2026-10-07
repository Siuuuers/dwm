extends "res://addons/gut/test.gd"

## Timing instrumentation must describe actual proof work without changing durable behavior.
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROFILE_ENV := "DWM_CHECKPOINT_PROFILE"

class RecordingPort extends "res://scripts/application/run/SaveManagerCheckpointPort.gd":
	var records: Array[Dictionary] = []
	func _profile_result(profile: Dictionary, result: Dictionary) -> Dictionary:
		var returned := super._profile_result(profile, result)
		if not profile.is_empty(): records.append(profile.duplicate(true))
		return returned

class Manager extends RefCounted:
	var _journal := JOURNAL.new()
	var _storage: RefCounted
	var _restore_participants := {}

var _had_profile_env := false
var _previous_profile_env := ""

func before_each() -> void:
	_had_profile_env = OS.has_environment(PROFILE_ENV)
	_previous_profile_env = OS.get_environment(PROFILE_ENV)
	OS.unset_environment(PROFILE_ENV)

func after_each() -> void:
	if _had_profile_env: OS.set_environment(PROFILE_ENV, _previous_profile_env)
	else: OS.unset_environment(PROFILE_ENV)

func _wired() -> Dictionary:
	var parsed := STRICT.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	assert_true(parsed.get("ok", false), "fixture strict parse: " + str(parsed.get("code", "")))
	parsed.value["schema_version"] = SNAPSHOT.SCHEMA_VERSION
	var validated := SNAPSHOT.validate(parsed.get("value", {}))
	assert_true(validated.get("ok", false), "fixture snapshot validation: " + str(validated.get("code", "")))
	var snapshot: Dictionary = validated.get("value", {}).get("candidate", {})
	var files := FILES.new()
	var manager := Manager.new()
	manager._storage = STORAGE.new("checkpoint-diagnostics", files)
	var port := RecordingPort.new(manager)
	assert_true(port.configure_fatal_latch(GATE.new()).get("ok", false))
	assert_true(manager._journal.reset(str(snapshot.run_id)).get("ok", false))
	return {"files": files, "manager": manager, "port": port, "snapshot": snapshot}

func _prepare(wired: Dictionary, money: int, durable: bool = true,
		kind: StringName = &"post_result") -> Dictionary:
	var snapshot: Dictionary = wired.snapshot.duplicate(true)
	snapshot["gameplay"]["money"] = money # The absent key must be a JSON String, not StringName.
	var input := {}
	for key: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "dating",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids", "desktop",
			"schedule_view", "command_receipts"]:
		input[key] = snapshot[key]
	var disk_write := {"kind": &"autosave", "reason": &"automatic"} if durable \
		else {"kind": &"none", "reason": &"stage"}
	var result: Dictionary = wired.port.prepare({"snapshot_input": input, "dialogic_checkpoint": {},
		"route_id": "main", "active_app_id": snapshot.active_app_id,
		"audio_context": snapshot.audio_context, "content_version": snapshot.content_version}, kind, disk_write)
	assert_true(result.get("ok", false), "checkpoint prepare: " + str(result.get("code", "")) + " " + str(result.get("message", "")))
	return result.get("value", {}).get("candidate", {})

func _commit(wired: Dictionary, money: int, durable: bool = true,
		kind: StringName = &"post_result") -> Dictionary:
	var candidate := _prepare(wired, money, durable, kind)
	var result: Dictionary = wired.port.commit(candidate)
	assert_true(result.get("ok", false), "checkpoint commit: " + str(result.get("code", "")) + " " + str(result.get("message", "")))
	return candidate

func _last(wired: Dictionary, scope: String) -> Dictionary:
	var records: Array = wired.port.records
	for index: int in range(records.size() - 1, -1, -1):
		if records[index].get("scope") == scope: return records[index]
	assert_true(false, "missing diagnostic scope: " + scope)
	return {}

func _assert_timers(record: Dictionary, required: Array[String]) -> void:
	assert_eq(record.get("diagnostics_version"), 2)
	for field: String in required:
		assert_true(record.has(field), "missing timer: " + field)
	for field: String in record:
		if field.ends_with("_us"):
			assert_eq(typeof(record[field]), TYPE_INT, field)
			assert_gte(int(record[field]), 0, field)

func test_profile_on_and_off_preserve_documents_journal_and_every_physical_operation() -> void:
	var plain := _wired()
	var measured := _wired()
	for step: int in range(3):
		OS.unset_environment(PROFILE_ENV)
		var expected := _commit(plain, 200 + step, step != 1,
			&"line" if step == 1 else &"post_result")
		OS.set_environment(PROFILE_ENV, "1")
		var actual := _commit(measured, 200 + step, step != 1,
			&"line" if step == 1 else &"post_result")
		assert_true(WRITER._deep_same(actual, expected), "diagnostics never enter prepared data")
		assert_true(measured.files.snapshot_persisted() == plain.files.snapshot_persisted(), "profile preserves exact persisted bytes")
		assert_true(measured.files.operation_trace() == plain.files.operation_trace(), "profile preserves every physical operation")
		assert_true(measured.manager._journal.capture_state() == plain.manager._journal.capture_state(), "profile preserves exact journal state")
	assert_true(plain.port.records.is_empty(), "disabled diagnostics emit no records")
	var prepared := _last(measured, "save_checkpoint_prepare")
	_assert_timers(prepared, ["document_build_us", "document_proof_lookup_us", "document_schema_build_us",
		"document_schema_normalize_current_us", "document_schema_normalize_journal_us",
		"document_schema_validate_current_us", "document_schema_validate_journal_us", "document_schema_compose_us"])
	var committed := _last(measured, "save_checkpoint")
	_assert_timers(committed, ["outgoing_schema_us", "outgoing_normalize_us", "outgoing_validate_us",
		"outgoing_history_capture_us", "outgoing_schema_envelope_normalize_us",
		"outgoing_schema_validate_current_us", "journal_proof_us", "journal_current_compare_us",
		"journal_current_remember_us", "journal_history_learning_us", "document_proof_remember_us"])
	assert_gt(int(committed.get("history_proof_hits", 0)), 0, "the full write encounters a warm retained proof")
	assert_gt(int(committed.get("history_proof_misses", 0)), 0, "the same full write encounters memory-only history")
	assert_eq(committed.get("history_proof_learn_successes"), committed.get("history_proof_misses"))
	assert_gte(int(prepared.document_build_us), int(prepared.document_schema_build_us), "build timer is inclusive")
	assert_gte(int(committed.journal_proof_us), int(committed.journal_history_learning_us), "proof timer is inclusive")

func test_cold_history_learning_is_distinct_from_next_prepares_proof_hits() -> void:
	var wired := _wired()
	_commit(wired, 301, false, &"line")
	_commit(wired, 302, false, &"manual_save")
	OS.set_environment(PROFILE_ENV, "1")
	var candidate := _commit(wired, 303)
	var prepared := _last(wired, "save_checkpoint_prepare")
	var committed := _last(wired, "save_checkpoint")
	var history: Array = candidate.autosave_document.recovery_journal
	assert_gt(history.size(), 0)
	assert_eq(prepared.get("document_proof_hits"), 0)
	assert_eq(prepared.get("document_proof_misses"), 1, "lookup stops at its first missing proof")
	assert_false(bool(prepared.get("document_schema_journal_proven", true)))
	assert_false(bool(committed.get("journal_spliced", true)))
	assert_eq(committed.get("history_proof_entries"), history.size())
	assert_eq(committed.get("history_proof_misses"), history.size())
	assert_eq(committed.get("history_proof_learn_attempts"), history.size())
	assert_eq(committed.get("history_proof_learn_successes"), history.size())
	for bundle: Dictionary in history:
		var checkpoint_id := str(bundle.snapshot.checkpoint_id)
		assert_false(wired.manager._journal.get_retained_bundle_text(checkpoint_id).is_empty())
		assert_true(WRITER._deep_same(wired.manager._journal.get_retained_bundle_document(checkpoint_id), bundle))
	_commit(wired, 304)
	prepared = _last(wired, "save_checkpoint_prepare")
	committed = _last(wired, "save_checkpoint")
	assert_eq(prepared.get("document_proof_hits"), prepared.get("document_proof_entries"))
	assert_eq(prepared.get("document_proof_misses"), 0)
	assert_true(bool(prepared.get("document_schema_journal_proven", false)))
	assert_true(bool(committed.get("journal_spliced", false)))
	assert_eq(committed.get("history_proof_learn_attempts"), 0)
	assert_eq(committed.get("history_proof_learn_successes"), 0)
	assert_eq(committed.get("journal_current_learn_attempts"), 1)
	assert_eq(committed.get("journal_current_learn_successes"), 1)

func test_schema_valid_history_edit_counts_a_learning_attempt_without_a_success() -> void:
	var wired := _wired()
	_commit(wired, 401, false, &"line")
	OS.set_environment(PROFILE_ENV, "1")
	var candidate := _prepare(wired, 402)
	var history: Array = candidate.autosave_document.recovery_journal
	assert_eq(history.size(), 1)
	var checkpoint_id := str(history[0].snapshot.checkpoint_id)
	history[0].snapshot.content_version += 100
	var result: Dictionary = wired.port.commit(candidate)
	assert_true(result.get("ok", false), "edited-history checkpoint commit: " + str(result.get("code", "")))
	var committed := _last(wired, "save_checkpoint")
	assert_eq(committed.get("history_proof_misses"), 1)
	assert_eq(committed.get("history_proof_learn_attempts"), 1)
	assert_eq(committed.get("history_proof_learn_successes"), 0,
		"only the journal's successful retained-value check counts as learning")
	assert_true(wired.manager._journal.get_retained_bundle_text(checkpoint_id).is_empty())

func test_refused_journal_commit_never_reports_or_creates_successful_learning() -> void:
	var plain := _wired()
	var measured := _wired()
	_commit(plain, 501, false, &"line")
	_commit(measured, 501, false, &"line")
	var expected := _prepare(plain, 502)
	OS.set_environment(PROFILE_ENV, "1")
	var candidate := _prepare(measured, 502)
	expected.journal_candidate.next_sequence += 1
	candidate.journal_candidate.next_sequence += 1
	OS.unset_environment(PROFILE_ENV)
	var reference: Dictionary = plain.port.commit(expected)
	OS.set_environment(PROFILE_ENV, "1")
	var result: Dictionary = measured.port.commit(candidate)
	assert_false(result.get("ok", true))
	assert_eq(result, reference)
	assert_true(measured.files.snapshot_persisted() == plain.files.snapshot_persisted(), "refusal preserves exact persisted bytes")
	assert_true(measured.files.operation_trace() == plain.files.operation_trace(), "refusal preserves every physical operation")
	assert_true(measured.manager._journal.capture_state() == plain.manager._journal.capture_state(), "refusal preserves exact journal state")
	var committed := _last(measured, "save_checkpoint")
	assert_false(bool(committed.get("ok", true)))
	assert_false(committed.has("journal_proof_us"), "proof phase was not reached")
	assert_false(committed.has("history_proof_learn_successes"), "absence means unexecuted, not measured zero")
	for bundle: Dictionary in candidate.autosave_document.recovery_journal:
		assert_true(measured.manager._journal.get_retained_bundle_text(str(bundle.snapshot.checkpoint_id)).is_empty())
