extends "res://addons/gut/test.gd"

const NARRATIVE_PARTICIPANT := "res://scripts/application/restore/NarrativeRestoreParticipant.gd"


class IncompatibleCatalog extends RefCounted:
	## Every lookup misses, so any nonempty playhead is reported as unavailable content.
	func get_record(timeline_id: String) -> Dictionary:
		return {"ok": false, "code": &"unknown_timeline_id", "message": timeline_id}
	func get_timeline_path(_timeline_id: String, _locale: String = "en") -> String:
		return ""


func test_narrative_content_failure_is_reported_directly() -> void:
	var participant: Object = load(NARRATIVE_PARTICIPANT).new(RefCounted.new(), IncompatibleCatalog.new())
	var result: Dictionary = participant.prepare({
		"narrative_checkpoint": {"timeline_id": "removed.timeline", "line_id": "removed.line"},
		"content_version": 1,
	})
	assert_false(result.get("ok", false), "removed content rejects")
	assert_eq(str(result.get("code")), "NARRATIVE_CONTENT_UNAVAILABLE", "selected snapshot reports its unavailable content")
	assert_eq(str((result.get("details", {}).get("cause", {}) as Dictionary).get("reason", "")), "content_unavailable", "carries the failure cause")


func test_empty_playhead_needs_no_narrative_content() -> void:
	var participant: Object = load(NARRATIVE_PARTICIPANT).new(RefCounted.new(), IncompatibleCatalog.new())
	var result: Dictionary = participant.prepare({"narrative_checkpoint": {}, "content_version": 1})
	assert_true(result.get("ok", false), "an empty playhead needs no content lookup")


func test_malformed_narrative_input_is_fail_closed_not_incompatible() -> void:
	var participant: Object = load(NARRATIVE_PARTICIPANT).new(RefCounted.new(), IncompatibleCatalog.new())
	var missing_version: Dictionary = participant.prepare({"narrative_checkpoint": {}})
	assert_eq(str(missing_version.get("code")), "invalid_narrative_input", "malformed input keeps the fail-closed code")
	var missing_checkpoint: Dictionary = participant.prepare({"content_version": 1})
	assert_eq(str(missing_checkpoint.get("code")), "invalid_narrative_input", "missing checkpoint keeps the fail-closed code")


class SparseRollbackFailure extends RefCounted:
	func rollback_silent(_backup: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"TEST.rollback_refused", "message": "owner could not restore"}

func test_failed_rollback_preserves_sparse_owner_and_original_refusals() -> void:
	var manager: Node = autofree(preload("res://autoload/SaveManager.gd").new())
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	assert_true(manager.configure_mutation_gate(gate).ok)
	manager._restore_participants["run"] = SparseRollbackFailure.new()
	var acquired: Dictionary = gate.acquire(&"restore")
	assert_true(acquired.ok, str(acquired))
	if not acquired.ok: return
	assert_true(manager.acquire_save_lock(&"restore").ok)
	var original := {"ok": false, "code": &"TEST.original_refusal", "message": "initial owner refusal"}
	var before := original.duplicate(true)
	var applied: Array[String] = ["run"]
	var result: Dictionary = manager._rollback_transaction(&"restore", applied, {"run": {}},
		acquired.value.token, true, original)
	assert_eq(result.get("code"), &"APPLICATION_FATAL")
	assert_true(gate.is_fatal_latched())
	assert_true(manager.is_save_locked(), "uncertain compensation retains save custody")
	assert_eq(original, before, "diagnostic projection cannot change owner evidence")
	var diagnostics: Array = result.details.failure.details.diagnostics
	assert_eq(diagnostics.size(), 2)
	assert_eq(diagnostics[0].owner_id, "run")
	assert_eq(diagnostics[0].operation, "rollback_silent")
	assert_eq(diagnostics[0].code, "TEST.rollback_refused")
	assert_eq(diagnostics[0].message, "owner could not restore")
	assert_eq(diagnostics[0].details, {})
	assert_eq(diagnostics[1].operation, "original_failure")
	assert_eq(diagnostics[1].code, "TEST.original_refusal")
	assert_eq(diagnostics[1].message, "initial owner refusal")
	assert_eq(diagnostics[1].details, {})
