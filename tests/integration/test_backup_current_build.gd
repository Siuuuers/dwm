extends "res://addons/gut/test.gd"
## Real current-build creation and storage; the existing scene fixture supplies
## diagnostic activation participants. Rendered/fresh-process restoration is
## covered separately by the current_title suite.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")

class ObservedSaveManager extends "res://autoload/SaveManager.gd":
	var restore_documents := 0
	var prepared_bundles: Array[Dictionary] = []
	var refuse_bundle := false
	func _prepare_restore_document(locator: Dictionary, document: Dictionary, migration_output: Dictionary,
			scene_seed_material: Dictionary = {}) -> Dictionary:
		restore_documents += 1
		return super._prepare_restore_document(locator, document, migration_output, scene_seed_material)
	func _prepare_bundle_with_all_participants(bundle: Dictionary, migration_output: Dictionary,
			document: Dictionary, locator: Dictionary, scene_seed_material: Dictionary = {}) -> Dictionary:
		prepared_bundles.append(bundle.duplicate(true))
		if refuse_bundle: return {"ok": false, "code": &"fixture_selected_state_refused"}
		return super._prepare_bundle_with_all_participants(bundle, migration_output, document, locator, scene_seed_material)

var fixture: RefCounted
var manager: ObservedSaveManager
var ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	manager = ObservedSaveManager.new()
	var setup: Dictionary = fixture.setup(get_tree(), "", manager)
	assert_true(setup.get("ok", false), str(setup))
	if not setup.get("ok", false): return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	ready = manager.capture_committed_scene_creation(started.transaction_id).get("ok", false)
	assert_true(ready)

func after_all() -> void:
	if fixture != null: fixture.close()

func test_listing_save_and_delete_never_prepare_restoration() -> void:
	assert_true(ready)
	if not ready: return
	manager.restore_documents = 0
	manager.prepared_bundles.clear()
	var source: Dictionary = fixture.read_autosave()
	assert_true(source.get("ok", false), str(source))
	if not source.get("ok", false): return
	var port := PORT.new()
	assert_true(port.configure(manager, "title").get("ok", false))
	var projection: Dictionary = port.get_projection()
	assert_true(projection.get("ok", false), str(projection))
	assert_eq(manager.restore_documents, 0, "opening Backup only reads slot information")
	assert_true(manager.prepared_bundles.is_empty())
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
	assert_eq(manager.restore_documents, 0, "neither initial Save, overwrite nor Delete prepares a Load")
	assert_true(manager.prepared_bundles.is_empty())

func test_selected_load_prepares_current_state_once_without_older_substitution() -> void:
	assert_true(ready)
	if not ready: return
	manager.restore_documents = 0
	manager.prepared_bundles.clear()
	var source: Dictionary = fixture.read_autosave()
	assert_true(source.get("ok", false), str(source))
	if not source.get("ok", false): return
	var selected: Dictionary = manager.prepare_backup_action("load", "autosave")
	assert_true(selected.get("ok", false), str(selected))
	if not selected.get("ok", false): return
	assert_eq(manager.restore_documents, 1)
	assert_eq(manager.prepared_bundles, [source.value.current_snapshot])
	manager.cancel_backup_action(selected.value.token)
	# Exercise the selection rule at its boundary: a refusal of the current
	# state must be returned, never replaced with an earlier state.
	manager.prepared_bundles.clear()
	manager.refuse_bundle = true
	var current := {"snapshot": {"marker": "current"}}
	var earlier := {"snapshot": {"marker": "earlier"}}
	var refused: Dictionary = manager._prepare_restore_document({},
		{"current_snapshot": current, "recovery_journal": [earlier]}, {})
	manager.refuse_bundle = false
	assert_eq(refused.get("code"), &"fixture_selected_state_refused")
	assert_eq(manager.prepared_bundles, [current], "only the explicitly selected current state is attempted")

func test_refused_write_reports_failure_without_changing_live_state() -> void:
	assert_true(ready)
	if not ready: return
	var before_game: Dictionary = fixture.game.capture_restore_state()
	var before_profile: Dictionary = fixture.profile.get_profile_snapshot()
	var before_journal: Dictionary = manager._journal.capture_state()
	var before_preparations := manager.restore_documents
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
	assert_eq(manager.restore_documents, before_preparations)
	assert_eq(manager.commit_backup_action(saved.value.token).get("code"), &"stale_backup_action")
