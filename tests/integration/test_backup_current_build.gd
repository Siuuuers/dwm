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
