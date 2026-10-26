extends "res://addons/gut/test.gd"
## Real filesystem, Profile, issuer, Run and SaveManager. Route/native activation
## use diagnostic participants; rendered and fresh-process Load have separate tests.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const IDENTITY := preload("res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
var fixture: RefCounted
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var setup: Dictionary = fixture.setup(get_tree())
	if setup.get("ok", false):
		setup = fixture.manager.configure_identity_allocation_participant(IDENTITY.new(fixture.issuer, fixture.manager))
	assert_true(setup.get("ok", false), str(setup))
	fixture_ready = setup.get("ok", false)

func after_all() -> void:
	if fixture != null: fixture.close()

func test_new_runs_preserve_disk_and_profile_then_normal_save_load_restores_progress() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	assert_true(fixture.profile.set_preference(&"preferences.audio.master_volume", 0.5).ok)
	assert_true(fixture.profile.unlock_ending("ending.alone", "TEST.previous.discovery").ok)
	assert_true(fixture.profile.configure_line_registry({"reply_lines": [{"line_id": "TEST.previous.line"}]}).ok)
	assert_true(fixture.profile.mark_line_visited("TEST.previous.line").ok)
	var profile_before: Dictionary = fixture.profile.get_profile_snapshot()
	var profile_bytes: Dictionary = fixture.storage.read_text("profile.json")
	assert_false(fixture.read_autosave().ok, "fresh storage has no initial Autosave")
	var journal_before: Dictionary = fixture.storage.inspect_revision(JOURNAL.JOURNAL_PATH)
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	var initial: Dictionary = fixture.manager.get_latest_stable_checkpoint().value.bundle.snapshot
	assert_eq(initial.schema_version, 9)
	assert_eq(initial.checkpoint_sequence, 1)
	assert_eq(initial.scene.entry_id, "scene.test.b")
	assert_eq(initial.scene.active_occurrence_id, started.transaction_id)
	assert_false(initial.lifecycle.has("scene_assignment"))
	assert_false(fixture.read_autosave().ok, "activation prepares only an in-memory checkpoint")
	assert_eq(fixture.storage.inspect_revision(JOURNAL.JOURNAL_PATH), journal_before,
		"New Run does not create a continuation-recovery operation")
	fixture.confirm_activation()
	assert_true(fixture.game.capture_live_session().value.active)
	assert_eq(fixture.profile.get_profile_snapshot(), profile_before)
	assert_eq(fixture.storage.read_text("profile.json"), profile_bytes)
	assert_eq(fixture.participants.route.publications, 1)
	assert_eq(fixture.participants.narrative.publications, 1)

	fixture.game.money = 17
	fixture.game.inventory["debug_key"] = 1
	fixture.game.story_flags["TEST.first.run"] = true
	var first_inventory: Dictionary = fixture.game.inventory
	var checkpoint_input: Dictionary = fixture.game.capture_run_snapshot_input()
	# Diagnostic board activation does not reconstruct live retry containers.
	# No board was started; match the real board restore owner's empty live ledger.
	checkpoint_input.desktop.board["command_receipts"] = {}
	var recorded: Dictionary = fixture.manager.record_stable_checkpoint({
		"snapshot_input": checkpoint_input,
		"dialogic_checkpoint": initial.narrative_checkpoint, "route_id": "scene",
		"active_app_id": null, "audio_context": {}, "content_version": initial.content_version}, &"safe_marker")
	assert_true(recorded.ok, str(recorded))
	if not recorded.ok: return
	var saved: Dictionary = fixture.manager.autosave_latest()
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	var old_bytes: Dictionary = fixture.storage.read_text("autosave.json")
	var saved_document: Dictionary = fixture.read_autosave().value
	var saved_snapshot: Dictionary = saved_document.current_snapshot.snapshot
	assert_eq(saved_snapshot.gameplay.money, 17)
	assert_false(saved_snapshot.lifecycle.has("scene_assignment"))

	var second: Dictionary = fixture.start()
	assert_eq(second.get("code"), &"scene_activation_pending", str(second))
	if second.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	var fresh: Dictionary = fixture.manager.get_latest_stable_checkpoint().value.bundle.snapshot
	assert_ne(fresh.run_id, initial.run_id)
	assert_eq(fresh.scene.entry_id, initial.scene.entry_id)
	assert_eq(fresh.narrative_checkpoint.reading_session.position_id, initial.narrative_checkpoint.reading_session.position_id,
		"fresh reading starts at the same authored content")
	assert_eq(fixture.game.money, 0)
	assert_true(fixture.game.inventory.is_empty())
	assert_true(fixture.game.story_flags.is_empty())
	first_inventory["debug_key"] = 9
	assert_true(fixture.game.inventory.is_empty(), "successive runs never share mutable inventory")
	assert_eq(fixture.storage.read_text("autosave.json"), old_bytes,
		"starting a later run preserves the previous real save")
	assert_eq(fixture.profile.get_profile_snapshot(), profile_before)

	var prepared: Dictionary = fixture.manager.prepare_restore_autosave()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var loaded: Dictionary = fixture.manager.commit_prepared_restore(prepared.value.prepared)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	assert_eq(fixture.game.money, 17)
	assert_eq(fixture.game.inventory, {"debug_key": 1})
	assert_true(fixture.game.story_flags["TEST.first.run"])
	var restored: Dictionary = fixture.manager.get_latest_stable_checkpoint().value.bundle.snapshot
	assert_eq(restored.narrative_checkpoint, saved_snapshot.narrative_checkpoint)
	assert_false(restored.lifecycle.has("scene_assignment"))
	assert_eq(fixture.profile.get_profile_snapshot(), profile_before)
