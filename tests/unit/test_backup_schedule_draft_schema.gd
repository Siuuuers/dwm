extends "res://addons/gut/test.gd"

const FIXTURE := preload("res://tests/support/BackupSnapshotFixture.gd")
const SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CONTROLLER := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const VIEW_PARTICIPANT := preload("res://scripts/application/restore/ScheduleViewRestoreParticipant.gd")
const MANAGER := preload("res://autoload/SaveManager.gd")
const CHECKPOINT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")

class CaptureSource extends RefCounted:
	var inputs: Dictionary
	func capture() -> Dictionary: return {"ok": true, "value": inputs.duplicate(true)}

func _participant() -> RefCounted:
	var registry: RefCounted = REGISTRY.load_current().value.registry
	var controller := CONTROLLER.new()
	assert_true(controller.configure(registry, RULES, registry.fingerprint()).ok)
	# Composition uses only this actual retained registry; restore does not call it.
	return VIEW_PARTICIPANT.new(controller, registry, RefCounted.new(),
		preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd"))


func _draft_snapshot() -> Dictionary:
	var fixture: Dictionary = FIXTURE.make_snapshot()
	assert_true(fixture.get("ok", false), str(fixture))
	if not fixture.get("ok", false): return {}
	var snapshot: Dictionary = fixture.value.candidate
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false): return {}
	var registry: RefCounted = loaded.value.registry
	var controller := CONTROLLER.new()
	assert_true(controller.configure(registry, RULES, registry.fingerprint()).ok)
	assert_true(controller.open_day(snapshot.lifecycle.day, snapshot.lifecycle.causal_day_instance).ok)
	var added: Dictionary = controller.prepare_add("training", null, 0, "backup-draft-training")
	assert_true(added.get("ok", false), str(added))
	if not added.get("ok", false): return {}
	assert_true(controller.commit(added.value.candidate).ok)
	snapshot.schedule_view = controller.snapshot().value.view
	return snapshot

func test_nonempty_uncommitted_draft_requires_a_current_registry_fact() -> void:
	var snapshot := _draft_snapshot()
	if snapshot.is_empty(): return
	assert_null(snapshot.committed_schedule.registry_fingerprint)
	assert_true(snapshot.committed_schedule.entries.is_empty())
	assert_null(snapshot.committed_schedule.commit_receipt)
	var before := snapshot.duplicate(true)
	var rejected: Dictionary = SCHEMA.validate(snapshot)
	assert_eq(rejected.get("code"), &"invalid_expected_fingerprint")
	assert_eq(snapshot, before, "validation never stamps a registry or fabricates a commit")

func test_current_registry_accepts_draft_without_spending_or_committing_schedule() -> void:
	var snapshot := _draft_snapshot()
	if snapshot.is_empty(): return
	var before := snapshot.duplicate(true)
	var composed: Dictionary = _participant().compose_live_checkpoint_input(snapshot)
	assert_false(is_same(composed, snapshot), "stamping a draft detaches from the live input")
	var validated: Dictionary = SCHEMA.validate(composed)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false): return
	assert_eq(snapshot, before)
	assert_eq(validated.value.candidate.schedule_view.entries, before.schedule_view.entries)
	assert_true(validated.value.candidate.committed_schedule.entries.is_empty())
	assert_null(validated.value.candidate.committed_schedule.commit_receipt)
	assert_eq(validated.value.candidate.gameplay, before.gameplay)

func test_nonempty_draft_rejects_stale_registry_without_rewriting_it() -> void:
	var snapshot := _draft_snapshot()
	if snapshot.is_empty(): return
	snapshot.committed_schedule.registry_fingerprint = "0".repeat(64)
	var before := snapshot.duplicate(true)
	var composed: Dictionary = _participant().compose_live_checkpoint_input(snapshot)
	assert_eq(composed, before)
	assert_eq(SCHEMA.validate(composed).get("code"), &"stale_registry_fingerprint")
	assert_eq(snapshot, before)

func test_historical_null_registry_stays_legal_for_an_empty_view() -> void:
	var fixture: Dictionary = FIXTURE.make_snapshot()
	assert_true(fixture.get("ok", false), str(fixture))
	if not fixture.get("ok", false): return
	var snapshot: Dictionary = fixture.value.candidate
	assert_true(snapshot.schedule_view.entries.is_empty())
	assert_null(snapshot.committed_schedule.registry_fingerprint)
	var composed: Dictionary = _participant().compose_live_checkpoint_input(snapshot)
	assert_true(is_same(composed, snapshot), "the common empty-view path avoids another snapshot clone")
	assert_eq(composed, snapshot)
	assert_true(SCHEMA.validate(composed).get("ok", false))

func test_composition_does_not_repair_receipt_backed_or_malformed_aggregates() -> void:
	var snapshot := _draft_snapshot()
	if snapshot.is_empty(): return
	var participant := _participant()
	for kind: String in ["receipt", "committed_entries", "missing_fingerprint"]:
		var malformed := snapshot.duplicate(true)
		match kind:
			"receipt": malformed.committed_schedule.commit_receipt = {"forged": true}
			"committed_entries": malformed.committed_schedule.entries = [{"forged": true}]
			"missing_fingerprint": malformed.committed_schedule.erase("registry_fingerprint")
		var before := malformed.duplicate(true)
		var composed: Dictionary = participant.compose_live_checkpoint_input(malformed)
		assert_eq(composed, before)
		assert_eq(malformed, before)
		assert_false(SCHEMA.validate(composed).get("ok", false))

func test_manual_automatic_and_direct_checkpoint_paths_preserve_unsaved_draft() -> void:
	for mode: String in ["manual", "paused", "automatic", "direct"]:
		var base: Dictionary = FIXTURE.make_snapshot().value.candidate
		var snapshot := _draft_snapshot()
		if snapshot.is_empty(): return
		var manager: Node = MANAGER.new()
		autofree(manager)
		var storage := STORAGE.new("memory/draft-" + mode, FILES.new())
		assert_true(manager.initialize(storage).ok)
		var gate := GATE.new()
		assert_true(manager.configure_mutation_gate(gate).ok)
		# The capture-only path uses this real participant. Native verification owns full restore.
		manager._restore_participants = {"schedule_view": _participant()}
		manager._journal.reset(base.run_id)
		var seeded: Dictionary = manager._journal.prepare_record(base, &"day_start")
		assert_true(seeded.get("ok", false), str(seeded))
		if not seeded.get("ok", false): return
		assert_true(manager._journal.commit_prepared(seeded.value.candidate).ok)
		var source := CaptureSource.new()
		source.inputs = {"snapshot_input": snapshot, "route_id": "main", "active_app_id": "backup",
			"dialogic_checkpoint": {}, "audio_context": {}, "content_version": 1}
		if mode == "paused": source.inputs.active_app_id = "minesweeper"
		var before := source.inputs.duplicate(true)
		var committed: Dictionary
		if mode in ["manual", "paused"]:
			var admission: Callable = (func(inputs: Dictionary) -> bool: return inputs == source.inputs) if mode == "paused" else Callable()
			assert_true(manager.configure_backup_capture_provider(source.capture, admission).ok)
			var prepared: Dictionary = manager.prepare_backup_action("save", "slot:1")
			assert_true(prepared.get("ok", false), str(prepared))
			if not prepared.get("ok", false): return
			committed = manager.commit_backup_action(prepared.value.token)
		elif mode == "automatic":
			var checkpoint := CHECKPOINT.new(manager)
			assert_true(checkpoint.configure_fatal_latch(gate).ok)
			var prepared: Dictionary = checkpoint.prepare(source.inputs, &"safe_marker",
				{"kind": &"autosave", "reason": &"automatic"})
			assert_true(prepared.get("ok", false), str(prepared))
			if not prepared.get("ok", false): return
			committed = checkpoint.commit(prepared.value.candidate)
		else:
			committed = manager.record_stable_checkpoint(source.inputs, &"safe_marker")
		assert_true(committed.get("ok", false), str(committed))
		assert_eq(source.inputs, before, mode + " capture leaves live state unchanged")
		var saved: Dictionary = manager.get_latest_stable_checkpoint().value.bundle.snapshot
		assert_eq(saved.schedule_view.entries, snapshot.schedule_view.entries)
		assert_eq(saved.committed_schedule.registry_fingerprint, REGISTRY.load_current().value.registry.fingerprint())
		assert_true(saved.committed_schedule.entries.is_empty())
		assert_null(saved.committed_schedule.commit_receipt)
		assert_eq(saved.gameplay, snapshot.gameplay)
		if mode != "direct":
			var path := "slot_1.json" if mode in ["manual", "paused"] else "autosave.json"
			var persisted: Dictionary = STRICT.parse_object(storage.read_text(path).value)
			assert_true(persisted.get("ok", false), str(persisted))
			assert_eq(persisted.value.current_snapshot.snapshot.schedule_view.entries, saved.schedule_view.entries)
