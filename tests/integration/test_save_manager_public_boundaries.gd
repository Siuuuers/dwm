extends "res://addons/gut/test.gd"

const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
var fixture: RefCounted
var _scope := preload("res://tests/support/SceneValidationScope.gd").new()

func before_each() -> void:
	_scope.install(true)
	fixture = preload("res://tests/support/SceneNewRunFixture.gd").new()
	var setup: Dictionary = fixture.setup(get_tree())
	assert_true(setup.get("ok", false), str(setup))
	if not setup.get("ok", false): return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") == &"scene_activation_pending": fixture.confirm_activation()

func after_each() -> void:
	fixture.close()
	_scope.restore()

func _inputs() -> Dictionary:
	var snapshot: Dictionary = fixture.manager.get_latest_stable_checkpoint().value.bundle.snapshot
	var input: Dictionary = fixture.game.capture_run_snapshot_input()
	# The diagnostic board participant does not install an empty live retry ledger.
	input.desktop.board["command_receipts"] = {}
	return {"snapshot_input": input, "dialogic_checkpoint": snapshot.narrative_checkpoint,
		"route_id": "scene", "active_app_id": null, "audio_context": {},
		"content_version": snapshot.content_version}

func test_session_exit_checkpoint_keeps_session_retirement_with_the_exit_owner() -> void:
	var handle: Dictionary = fixture.game.capture_live_session().value
	var lease: Dictionary = fixture.gate.acquire(&"session_abandonment")
	assert_true(lease.ok, str(lease))
	if not lease.ok: return
	var completed: Array = []
	fixture.manager.save_completed.connect(func(receipt: Dictionary) -> void: completed.append(receipt.duplicate(true)))
	var result: Dictionary = fixture.manager.save_session_exit_checkpoint(_inputs(), handle)
	assert_true(result.get("ok", false), str(result))
	if result.get("ok", false):
		assert_true(result.value.written)
		assert_eq(result.value.save_reason, "logout")
		assert_eq(completed.size(), 1)
		var saved: Dictionary = fixture.read_autosave()
		assert_true(saved.ok, str(saved))
		assert_eq(saved.value.current_snapshot.snapshot.run_id, handle.run_id)
	assert_eq(fixture.game.capture_live_session().value, handle,
		"the exit coordinator, not storage, owns retirement")
	assert_true(fixture.gate.is_lease_active(&"session_abandonment", lease.value.token))
	assert_true(fixture.gate.release(&"session_abandonment", lease.value.token).ok)

func test_load_context_reads_the_exact_current_snapshot_without_mutation() -> void:
	var snapshot: Dictionary = fixture.manager.get_latest_stable_checkpoint().value.bundle.snapshot
	assert_true(fixture.manager.save_latest_to_slot(1).ok)
	assert_true(fixture.manager.quick_save_latest().ok)
	assert_true(fixture.manager.autosave_latest().ok)
	var before_files := {}
	for path: String in ["slot_1.json", "quicksave.json", "autosave.json"]:
		before_files[path] = fixture.storage.read_text(path)
	var before_run: Dictionary = fixture.game.capture_restore_state()
	var before_profile: Dictionary = fixture.profile.get_profile_snapshot()
	var before_journal: Dictionary = fixture.manager._journal.capture_state()
	for locator: String in ["slot:1", "quick", "autosave"]:
		var read: Dictionary = fixture.manager.load_context({"slot_id": locator, "checkpoint_id": snapshot.checkpoint_id})
		assert_true(read.get("ok", false), str(read))
		if not read.get("ok", false): continue
		assert_eq(read.value.context, snapshot)
		assert_eq(read.value.context_sha256, str(WRITER.stringify(snapshot).value).sha256_text())
		read.value.context.gameplay.money = -1234
		var again: Dictionary = fixture.manager.load_context({"slot_id": locator, "checkpoint_id": snapshot.checkpoint_id})
		assert_true(again.ok, str(again))
		assert_eq(again.value.context, snapshot, "returned context is detached")
	for path: String in before_files:
		assert_eq(fixture.storage.read_text(path), before_files[path])
	assert_eq(fixture.game.capture_restore_state(), before_run)
	assert_eq(fixture.profile.get_profile_snapshot(), before_profile)
	assert_eq(fixture.manager._journal.capture_state(), before_journal)
