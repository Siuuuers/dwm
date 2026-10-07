extends "res://addons/gut/test.gd"
## Real GameState + save adapter/journal/storage integration with injected FileOps.
## Reading admission and Schedule capture are controlled doubles; no UI, fresh
## process, OS termination, power-loss, or production registration proof is claimed.
const FIXTURE := preload("res://tests/support/DurableSceneEventFixture.gd")
var _fixtures: Array[RefCounted] = []

func after_each() -> void:
	for fixture: RefCounted in _fixtures: fixture.dispose()
	_fixtures.clear()

func _fixture() -> RefCounted:
	var fixture: RefCounted = FIXTURE.new()
	_fixtures.append(fixture)
	var initialized: Dictionary = fixture.initialize()
	assert_true(initialized.get("ok", false), str(initialized))
	return fixture if initialized.get("ok", false) else null

func test_set_clear_and_duplicate_share_durable_receipts_without_consuming_reading() -> void:
	var f := _fixture()
	if f == null: return
	var reading: Dictionary = f.boundary.checkpoint.duplicate(true)
	var first: Dictionary = f.port.dispatch(f.event_at(0))
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	var disk: Dictionary = f.disk_snapshot()
	assert_true(disk.get("ok", false), str(disk))
	if not disk.get("ok", false): return
	assert_eq(disk.value.command_receipts, f.game.capture_run_snapshot_input().command_receipts)
	assert_eq(disk.value.command_receipts.size(), 1)
	assert_eq(disk.value.narrative_checkpoint, reading)
	assert_eq(first.value.notification.notification_id, "fixture.notice")
	var saved: Dictionary = f.files.snapshot_persisted()
	var journal: Dictionary = f.manager._journal.capture_state()
	var duplicate: Dictionary = f.port.dispatch(f.event_at(0))
	assert_true(duplicate.get("ok", false), str(duplicate))
	assert_true(duplicate.get("duplicate", false))
	assert_eq(duplicate.value, first.value)
	assert_eq(f.files.snapshot_persisted(), saved)
	assert_eq(f.manager._journal.capture_state(), journal)
	assert_eq(f.real.commits, 1)
	var clear: Dictionary = f.port.dispatch(f.event_at(1))
	assert_true(clear.get("ok", false), str(clear))
	if not clear.get("ok", false): return
	disk = f.disk_snapshot()
	assert_true(disk.get("ok", false), str(disk))
	if not disk.get("ok", false): return
	assert_eq(disk.value.command_receipts.size(), 2)
	assert_eq(disk.value.narrative_checkpoint, reading)
	assert_eq(f.boundary.checkpoint, reading)
	assert_eq(f.game.scene_event_context().value.notification, {})
	assert_eq(f.game.scene_event_context().value.next_ordinal, 2)
	assert_false(f.gate.is_active())

func test_prewrite_io_refusal_restores_primary_and_journal_then_exact_retry_commits() -> void:
	var f := _fixture()
	if f == null: return
	assert_true(f.port.dispatch(f.event_at(0)).get("ok", false))
	var saved: Dictionary = f.files.snapshot_persisted()
	var journal: Dictionary = f.manager._journal.capture_state()
	var live: Dictionary = f.game.capture_run_snapshot_input()
	f.real.fail_next_write = true
	var failed: Dictionary = f.port.dispatch(f.event_at(1))
	assert_false(failed.get("ok", true), str(failed))
	assert_true(failed.get("rolled_back", false), "adapter proved paired compensation")
	var restored: Dictionary = f.files.snapshot_persisted()
	var primary: String = f.storage.describe_root().path_join("autosave.json")
	assert_eq(restored[primary], saved[primary], "exact admitted primary preimage restored")
	# The existing atomic compensation rotates a coherent backup; it does not
	# promise to restore an incidental old .bak directory entry byte-for-byte.
	assert_eq(restored.get(primary + ".bak"), saved[primary])
	assert_false(restored.has(primary + ".next"))
	assert_false(restored.has(primary + ".txn.json"))
	assert_eq(f.manager._journal.capture_state(), journal)
	assert_eq(f.game.capture_run_snapshot_input(), live)
	assert_false(f.gate.is_fatal_latched())
	assert_false(f.gate.is_active())
	var retry: Dictionary = f.port.dispatch(f.event_at(1))
	assert_true(retry.get("ok", false), str(retry))
	assert_eq(f.game.scene_event_context().value.next_ordinal, 2)

func test_confirmed_commit_interrupted_before_adoption_fences_retry_and_manual_save() -> void:
	var f := _fixture()
	if f == null: return
	var live: Dictionary = f.game.capture_run_snapshot_input()
	f.game._scene_event_before_adoption = func() -> bool: return false
	var interrupted: Dictionary = f.port.dispatch(f.event_at(0))
	assert_false(interrupted.get("ok", true), str(interrupted))
	assert_true(f.gate.is_fatal_latched())
	assert_eq(f.game.capture_run_snapshot_input(), live, "adoption did not occur")
	var disk: Dictionary = f.disk_snapshot()
	assert_true(disk.get("ok", false), str(disk))
	if not disk.get("ok", false): return
	assert_true(disk.value.command_receipts.has(f.event_at(0).command_id), "confirmed bytes remain")
	assert_eq(disk.value.narrative_checkpoint, f.boundary.checkpoint)
	var saved: Dictionary = f.files.snapshot_persisted()
	assert_false(f.port.dispatch(f.event_at(0)).get("ok", true))
	assert_false(f.port.dispatch(f.event_at(1)).get("ok", true))
	assert_false(f.manager.save_slot(1).get("ok", true), "manual save cannot publish stale live state")
	assert_eq(f.files.snapshot_persisted(), saved)
	assert_eq(f.real.commits, 1)

func test_stale_source_token_unregistered_and_out_of_order_refuse_before_storage() -> void:
	var f := _fixture()
	if f == null: return
	var candidates: Array[Dictionary] = []
	var event: Dictionary = f.event_at(0)
	event.source.branch_id = "fixture.old_branch"
	candidates.append(event)
	event = f.event_at(0)
	event.playback_token = "fixture.old_process"
	candidates.append(event)
	event = f.event_at(0)
	event.event_id = "fixture.unregistered"
	candidates.append(event)
	candidates.append(f.event_at(1))
	var saved: Dictionary = f.files.snapshot_persisted()
	var live: Dictionary = f.game.capture_run_snapshot_input()
	for candidate: Dictionary in candidates:
		assert_false(f.port.dispatch(candidate).get("ok", true))
		assert_eq(f.files.snapshot_persisted(), saved)
		assert_eq(f.game.capture_run_snapshot_input(), live)
		assert_false(f.gate.is_active())
	assert_eq(f.real.commits, 0)

func test_registered_unsupported_kind_and_conflicting_duplicate_refuse_without_save() -> void:
	var f := _fixture()
	if f == null: return
	assert_true(f.port.dispatch(f.event_at(0)).get("ok", false))
	assert_true(f.port.dispatch(f.event_at(1)).get("ok", false))
	var saved: Dictionary = f.files.snapshot_persisted()
	var journal: Dictionary = f.manager._journal.capture_state()
	var unsupported: Dictionary = f.port.dispatch(f.event_at(2))
	assert_eq(unsupported.get("code"), &"event_kind_unsupported")
	var changed: Dictionary = f.event_at(0)
	changed.payload.content_id = "fixture.changed"
	assert_eq(f.port.dispatch(changed).get("code"), &"duplicate_transaction_conflict")
	assert_eq(f.files.snapshot_persisted(), saved)
	assert_eq(f.manager._journal.capture_state(), journal)
	assert_eq(f.real.commits, 2)

func test_restore_preparation_requires_registry_and_active_reading_before_mutation() -> void:
	var f := _fixture()
	if f == null: return
	var committed: Dictionary = f.port.dispatch(f.event_at(0))
	assert_true(committed.get("ok", false), str(committed))
	if not committed.get("ok", false): return
	var disk: Dictionary = f.disk_snapshot()
	assert_true(disk.get("ok", false), str(disk))
	if not disk.get("ok", false): return
	var participant := preload("res://scripts/application/restore/RunRestoreParticipant.gd").new(f.game)
	var before: Dictionary = f.game.capture_run_snapshot_input()
	assert_true(participant.prepare({"snapshot": disk.value}).get("ok", false))
	var stripped: Dictionary = disk.value.duplicate(true)
	stripped.narrative_checkpoint = {}
	var refused: Dictionary = participant.prepare({"snapshot": stripped})
	assert_eq(refused.get("code"), &"event_anchor_invalid")
	f.game._scene_event_registry = {}
	refused = participant.prepare({"snapshot": disk.value})
	assert_eq(refused.get("code"), &"event_registration_invalid")
	assert_eq(f.game.capture_run_snapshot_input(), before, "prepare never installs a partial run")
	assert_eq(f.disk_snapshot().value, disk.value, "refusal preserves actual saved snapshot")
