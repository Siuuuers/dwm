extends "res://addons/gut/test.gd"

## Timing instrumentation must describe actual proof work without changing durable behavior.
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROFILE_ENV := "DWM_CHECKPOINT_PROFILE"

var _scene_fixture: RefCounted
var _scene_scope: RefCounted
var _scene_snapshot: Dictionary = {}

func before_all() -> void:
	_scene_scope = preload("res://tests/support/SceneValidationScope.gd").new()
	_scene_scope.install(true)
	_scene_fixture = preload("res://tests/support/SceneRunSaveFixture.gd").new()
	var setup: Dictionary = _scene_fixture.setup(get_tree())
	assert_true(setup.ok, str(setup))
	if not setup.ok: return
	_scene_snapshot = _scene_fixture.snapshot.duplicate(true)

func after_all() -> void:
	if _scene_fixture != null: _scene_fixture.close()
	if _scene_scope != null: _scene_scope.restore()


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
	var snapshot: Dictionary = _scene_snapshot.duplicate(true)
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
	for key: String in ["lifecycle", "gameplay", "contacts", "desktop", "scene"]:
		input[key] = snapshot[key].duplicate(true)
	input.merge({"command_receipts": {}, "applied_effect_transaction_ids": [], "applied_variable_transaction_ids": []})
	var board := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
	var restored: Dictionary = board.prepare_player_restore_scene(snapshot.desktop.board, _scene_fixture.issuer)
	assert_true(restored.ok, str(restored))
	assert_true(board.commit(restored.value.candidate).ok)
	input.desktop.board = board.capture()
	var disk_write := {"kind": &"autosave", "reason": &"automatic"} if durable \
		else {"kind": &"none", "reason": &"stage"}
	var result: Dictionary = wired.port.prepare({"snapshot_input": input, "dialogic_checkpoint": snapshot.narrative_checkpoint,
		"route_id": "scene", "active_app_id": null,
		"audio_context": {}, "content_version": snapshot.content_version}, kind, disk_write)
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
	assert_eq(int(committed.get("history_proof_hits", 0)), 0)
	assert_eq(int(committed.get("history_proof_misses", 0)), 0)
	assert_eq(committed.get("history_proof_learn_successes"), committed.get("history_proof_misses"))
	assert_gte(int(prepared.document_build_us), int(prepared.document_schema_build_us), "build timer is inclusive")
	assert_gte(int(committed.journal_proof_us), int(committed.journal_history_learning_us), "proof timer is inclusive")

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
