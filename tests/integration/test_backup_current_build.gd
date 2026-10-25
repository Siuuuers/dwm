extends "res://addons/gut/test.gd"
## Real current-build creation and storage; the existing scene fixture supplies
## diagnostic activation participants. Rendered/fresh-process restoration is
## covered separately by the current_title suite.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")

# Observe the first restore participant without replacing the exact production
# SaveManager owner required by scene creation and saved scene authority.
class ObservedRunPreparation extends RefCounted:
	var delegate: RefCounted
	var snapshots: Array[Dictionary] = []
	var refuse := false
	func prepare(input: Dictionary) -> Dictionary:
		snapshots.append(input.snapshot.duplicate(true))
		if refuse: return {"ok": false, "code": &"fixture_selected_state_refused"}
		return delegate.prepare(input)
	func capture_live_session() -> Dictionary:
		return delegate.capture_live_session()

var fixture: RefCounted
var manager: Node
var observer: ObservedRunPreparation
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var setup: Dictionary = fixture.setup(get_tree())
	manager = fixture.manager
	assert_true(setup.get("ok", false), str(setup))
	if not setup.get("ok", false): return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	fixture_ready = manager.capture_committed_scene_creation(started.transaction_id).get("ok", false)
	assert_true(fixture_ready)

func before_each() -> void:
	if not fixture_ready: return
	observer = ObservedRunPreparation.new()
	observer.delegate = manager._restore_participants.run
	manager._restore_participants.run = observer

func after_each() -> void:
	if observer == null: return
	manager._restore_participants.run = observer.delegate
	observer = null

func after_all() -> void:
	if fixture != null: fixture.close()

func test_listing_save_and_delete_never_prepare_restoration() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var source: Dictionary = fixture.read_autosave()
	assert_true(source.get("ok", false), str(source))
	if not source.get("ok", false): return
	var port := PORT.new()
	assert_true(port.configure(manager, "title").get("ok", false))
	var projection: Dictionary = port.get_projection()
	assert_true(projection.get("ok", false), str(projection))
	assert_true(observer.snapshots.is_empty(), "opening Backup only reads slot information")
	var saved: Dictionary = manager.prepare_backup_action("save", "slot:1")
	assert_true(saved.get("ok", false), str(saved))
	if not saved.get("ok", false): return
	assert_true(manager.commit_backup_action(saved.value.token).get("ok", false))
	var read: Dictionary = fixture.storage.read_text("slot_1.json")
	assert_true(read.get("ok", false), str(read))
	if not read.get("ok", false): return
	var parsed: Dictionary = STRICT.parse_object(read.value)
	assert_true(parsed.get("ok", false), str(parsed))
	if not parsed.get("ok", false): return
	var document: Dictionary = parsed.value
	assert_eq(document.current_snapshot, source.value.current_snapshot, "Save writes the selected current state")
	var overwritten: Dictionary = manager.prepare_backup_action("save", "slot:1")
	assert_true(overwritten.get("ok", false), str(overwritten))
	if not overwritten.get("ok", false): return
	assert_true(manager.commit_backup_action(overwritten.value.token).get("ok", false))
	var deleted: Dictionary = manager.prepare_backup_action("delete", "slot:1")
	assert_true(deleted.get("ok", false), str(deleted))
	if not deleted.get("ok", false): return
	assert_true(manager.commit_backup_action(deleted.value.token).get("ok", false))
	assert_false(fixture.storage.exists("slot_1.json"))
	assert_true(observer.snapshots.is_empty(), "neither initial Save, overwrite nor Delete prepares a Load")

func test_scene_saves_omit_reason_and_retired_metadata_does_not_gate_load() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var source: Dictionary = fixture.read_autosave()
	assert_true(source.ok, str(source))
	if not source.ok: return
	assert_false(source.value.has("save_reason"), "initial Scene save has no diagnostic reason")
	assert_false(source.value.current_snapshot.snapshot.has("audio_context"))
	var saved: Dictionary = manager.save_latest_to_slot(6)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	assert_eq(saved.value.save_reason, "manual", "the operation result retains its diagnostic label")
	var parsed: Dictionary = STRICT.parse_object(fixture.storage.read_text("slot_6.json").value)
	assert_true(parsed.ok, str(parsed))
	if not parsed.ok: return
	var document: Dictionary = parsed.value
	assert_false(document.has("save_reason"))
	assert_eq(document.current_snapshot, source.value.current_snapshot)
	assert_eq(manager.get_save_metadata(&"slot", 6).value.save_reason, null)
	var writer := preload("res://scripts/validation/CanonicalJsonWriter.gd")
	var schema := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
	for retired: Variant in ["manual", "not-a-reason", 42, null, {"old": true}, ["old"]]:
		var input: Dictionary = document.duplicate(true)
		input["save_reason"] = retired
		input.current_snapshot.snapshot["audio_context"] = retired
		var admitted: Dictionary = schema.validate(input)
		assert_true(admitted.ok, str(admitted))
		if not admitted.ok: continue
		assert_eq(admitted.value.candidate, document, "retired metadata does not alter normalized progress")
		assert_true(input.has("save_reason"), "admission does not mutate its source")
		assert_true(_replace_target("slot_6.json", writer.stringify(input).value + "\n").ok)
		observer.snapshots.clear()
		var loaded: Dictionary = manager.prepare_backup_action("load", "slot:6")
		assert_true(loaded.ok, str(loaded))
		if loaded.ok:
			assert_eq(observer.snapshots, [document.current_snapshot.snapshot])
			manager.cancel_backup_action(loaded.value.token)
	var bad: Dictionary = document.duplicate(true)
	bad.slot_id = 8
	assert_false(schema.validate(bad).ok, "required slot identity remains checked")
	bad = document.duplicate(true)
	bad.current_snapshot.snapshot.gameplay.erase("money")
	assert_false(schema.validate(bad).ok, "retiring metadata must not admit missing gameplay")
	assert_true(manager.save_latest_to_slot(6).ok)
	assert_false(STRICT.parse_object(fixture.storage.read_text("slot_6.json").value).value.has("save_reason"),
		"a later Save never carries forward retired input metadata")
	assert_true(manager.quick_save_latest().ok)
	assert_false(STRICT.parse_object(fixture.storage.read_text("quicksave.json").value).value.has("save_reason"))


func test_selected_load_prepares_current_state_once_without_older_substitution() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var source: Dictionary = fixture.read_autosave()
	assert_true(source.get("ok", false), str(source))
	if not source.get("ok", false): return
	var selected: Dictionary = manager.prepare_backup_action("load", "autosave")
	assert_true(selected.get("ok", false), str(selected))
	if not selected.get("ok", false): return
	assert_eq(observer.snapshots, [source.value.current_snapshot.snapshot])
	manager.cancel_backup_action(selected.value.token)
	# Exercise the selection rule at its boundary: a refusal of the current
	# state must be returned, never replaced with an earlier state.
	observer.snapshots.clear()
	observer.refuse = true
	var current := {"snapshot": {"marker": "current"}}
	var earlier := {"snapshot": {"marker": "earlier"}}
	var refused: Dictionary = manager._prepare_restore_document({},
		{"current_snapshot": current, "recovery_journal": [earlier]}, {})
	observer.refuse = false
	assert_eq(refused.get("code"), &"fixture_selected_state_refused")
	assert_eq(observer.snapshots, [current.snapshot], "only the explicitly selected current state is attempted")

func test_refused_write_reports_failure_without_changing_live_state() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var before_game: Dictionary = fixture.game.capture_restore_state()
	var before_profile: Dictionary = fixture.profile.get_profile_snapshot()
	var before_journal: Dictionary = manager._journal.capture_state()
	var saved: Dictionary = manager.prepare_backup_action("save", "slot:2")
	assert_true(saved.get("ok", false), str(saved))
	if not saved.get("ok", false): return
	# Refuse before the storage layer writes any bytes; restore the hook after
	# the call so other tests remain independent of execution order.
	var original: Callable = fixture.storage._before_write
	fixture.storage._before_write = func() -> Dictionary:
		return {"ok": false, "code": &"fixture_write_refused"}
	var refused: Dictionary = manager.commit_backup_action(saved.value.token)
	fixture.storage._before_write = original
	assert_false(refused.get("ok", true), str(refused))
	assert_eq(refused.get("code"), &"before_write_refused")
	assert_false(fixture.storage.exists("slot_2.json"))
	assert_eq(fixture.game.capture_restore_state(), before_game)
	assert_eq(fixture.profile.get_profile_snapshot(), before_profile)
	assert_eq(manager._journal.capture_state(), before_journal)
	assert_true(observer.snapshots.is_empty())
	assert_eq(manager.commit_backup_action(saved.value.token).get("code"), &"stale_backup_action")


func _replace_target(path: String, text: String) -> Dictionary:
	var absolute: String = fixture.storage.describe_root().path_join(path)
	var written: Dictionary = fixture.storage._file_ops.write_bytes(absolute, text.to_utf8_buffer())
	if not written.get("ok", false): return written
	return fixture.storage._file_ops.flush_path(absolute)


func test_current_session_exit_replaces_unrestorable_autosave_without_retiring_session() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var source: Dictionary = fixture.read_autosave()
	assert_true(source.get("ok", false), str(source))
	if not source.get("ok", false): return
	var snapshot: Dictionary = source.value.current_snapshot.snapshot
	assert_eq(snapshot.schema_version, 9, "the outgoing state is a genuine current scene save")
	# The activation fixture uses a diagnostic board participant. Install the actual
	# board owner before exercising a live producer; a player snapshot is not a live backup.
	var live_board := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
	var board_plan: Dictionary = live_board.prepare_player_restore_scene(snapshot.desktop.board, fixture.issuer)
	assert_true(board_plan.get("ok", false), str(board_plan))
	if not board_plan.get("ok", false): return
	assert_true(live_board.commit(board_plan.value.candidate).get("ok", false))
	var configured: Dictionary = fixture.game.configure_desktop_snapshot_provider(func() -> Dictionary:
		return {"board": live_board.capture(), "consequence": snapshot.desktop.consequence.duplicate(true)})
	assert_true(configured.get("ok", false), str(configured))
	if not configured.get("ok", false): return
	var inputs := {"snapshot_input": fixture.game.capture_run_snapshot_input(),
		"dialogic_checkpoint": snapshot.narrative_checkpoint, "route_id": snapshot.route_id,
		"active_app_id": null, "audio_context": preload("res://scripts/domain/run/RunSnapshotSchema.gd").derive_scene_audio_context(snapshot).value,
		"content_version": snapshot.content_version}
	var handle: Dictionary = fixture.game.capture_live_session().value
	var before_profile: Dictionary = fixture.profile.get_profile_snapshot()
	var replaced := _replace_target("autosave.json", "not a restorable save\n")
	assert_true(replaced.get("ok", false), str(replaced))
	if not replaced.get("ok", false): return
	var lease: Dictionary = fixture.gate.acquire(&"session_abandonment")
	assert_true(lease.get("ok", false), str(lease))
	if not lease.get("ok", false): return
	var result: Dictionary = manager.save_session_exit_checkpoint(inputs, handle)
	assert_true(fixture.gate.is_lease_active(&"session_abandonment", lease.value.token))
	assert_true(fixture.gate.release(&"session_abandonment", lease.value.token).get("ok", false))
	assert_true(result.get("ok", false), str(result))
	assert_eq(fixture.game.capture_live_session().value, handle, "the exit coordinator owns retirement")
	assert_eq(fixture.profile.get_profile_snapshot(), before_profile)
	assert_true(observer.snapshots.is_empty(), "replacing an Autosave never prepares restoration")
	if not result.get("ok", false): return
	assert_eq(result.value.save_reason, "logout")
	var saved: Dictionary = fixture.read_autosave()
	assert_true(saved.get("ok", false), str(saved))
	if not saved.get("ok", false): return
	assert_false(saved.value.has("save_reason"), "operation labels are not player progress")
	assert_eq(saved.value.current_snapshot, manager.get_latest_stable_checkpoint().value.bundle)


func test_latest_save_refuses_concurrent_target_change_and_retry_preserves_current_state() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var replaced := _replace_target("slot_3.json", "old replaceable bytes\n")
	assert_true(replaced.get("ok", false), str(replaced))
	if not replaced.get("ok", false): return
	var before_game: Dictionary = fixture.game.capture_restore_state()
	var before_profile: Dictionary = fixture.profile.get_profile_snapshot()
	var before_journal: Dictionary = manager._journal.capture_state()
	var completed: Array[Dictionary] = []
	var on_completed := func(result: Dictionary) -> void: completed.append(result.duplicate(true))
	manager.save_completed.connect(on_completed)
	var original: Callable = fixture.storage._before_write
	fixture.storage._before_write = func() -> Dictionary:
		return _replace_target("slot_3.json", "concurrent replacement\n")
	var refused: Dictionary = manager.save_latest_to_slot(3)
	fixture.storage._before_write = original
	manager.save_completed.disconnect(on_completed)
	assert_eq(refused.get("code"), &"revision_changed", str(refused))
	# Refusal cannot grant a read lease to the competing writer's unvalidated bytes.
	var retained: Dictionary = fixture.storage.inspect_revision("slot_3.json")
	assert_true(retained.get("ok", false), str(retained))
	if retained.get("ok", false):
		assert_eq(retained.value.text, "concurrent replacement\n")
		assert_eq(retained.value.revision, "concurrent replacement\n".sha256_text())
	assert_true(completed.is_empty(), "a refused write emits no completion")
	assert_eq(fixture.game.capture_restore_state(), before_game)
	assert_eq(fixture.profile.get_profile_snapshot(), before_profile)
	assert_eq(manager._journal.capture_state(), before_journal)
	var retried: Dictionary = manager.save_latest_to_slot(3)
	assert_true(retried.get("ok", false), str(retried))
	if not retried.get("ok", false): return
	var parsed: Dictionary = STRICT.parse_object(fixture.storage.read_text("slot_3.json").value)
	assert_true(parsed.get("ok", false), str(parsed))
	if parsed.get("ok", false):
		assert_eq(parsed.value.current_snapshot, manager.get_latest_stable_checkpoint().value.bundle)
	assert_eq(fixture.game.capture_restore_state(), before_game)
	assert_eq(fixture.profile.get_profile_snapshot(), before_profile)
	assert_eq(manager._journal.capture_state(), before_journal)
