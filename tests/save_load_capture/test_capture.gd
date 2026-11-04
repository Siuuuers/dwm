extends SceneTree
## Current scene capture with real schema/reading owners and memory destination storage.
const MANAGER := preload("res://autoload/SaveManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const FIXTURE := preload("res://tests/support/SceneRunSaveFixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scope := preload("res://tests/support/SceneValidationScope.gd").new()
	scope.install(true)
	var fixture := FIXTURE.new()
	var setup: Dictionary = fixture.setup(self)
	_check(setup.ok, str(setup))
	if setup.ok: _capture(fixture)
	fixture.close()
	scope.restore()
	print("SAVE_LOAD_CAPTURE_PASS %d checks; failures=0" % checks) if failures == 0 else printerr("SAVE_LOAD_CAPTURE_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _capture(fixture: RefCounted) -> void:
	var files := FILES.new()
	var storage := STORAGE.new("memory/capture", files)
	var manager: Node = MANAGER.new()
	_check(manager.initialize(storage).ok, "initialize")
	_check(manager.configure_mutation_gate(GATE.new()).ok, "gate")
	var snapshot: Dictionary = fixture.snapshot
	var seeded: Dictionary = manager._journal.prepare_seed(fixture.document, fixture.document.current_snapshot)
	_check(seeded.ok, "initial scene checkpoint accepted")
	if not seeded.ok:
		manager.free()
		return
	manager._journal.commit_prepared(seeded.value.candidate)
	var adopted: Dictionary = fixture.game.apply_restore_silent({"snapshot": snapshot})
	_check(adopted.ok, str(adopted))
	var input: Dictionary = fixture.game.capture_run_snapshot_input()
	# This Run fixture has no Board participant to install its empty retry ledger.
	input.desktop.board["command_receipts"] = {}
	input.gameplay.money = 200
	var expanded: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").expand_player_checkpoint(snapshot.narrative_checkpoint)
	_check(expanded.ok, str(expanded))
	var inputs := {"snapshot_input": input, "route_id": "scene", "active_app_id": null,
		"dialogic_checkpoint": expanded.value, "audio_context": {},
		"content_version": snapshot.content_version}
	var capture := func() -> Dictionary: return {"ok": true, "value": inputs.duplicate(true)}
	_check(manager.configure_backup_capture_provider(capture).ok, "configure current scene capture")
	var before: Dictionary = manager._journal.capture_state()
	var disk_before: Dictionary = files.snapshot_persisted()
	var prepared: Dictionary = manager.prepare_backup_action("save", "slot:1")
	_check(prepared.ok, str(prepared))
	if prepared.ok:
		_check(manager._journal.capture_state() == before and files.snapshot_persisted() == disk_before, "prepare is read-only")
		manager.cancel_backup_action(prepared.value.token)
		_check(manager._journal.capture_state() == before and files.snapshot_persisted() == disk_before, "cancel preserves progress")
		prepared = manager.prepare_backup_action("save", "slot:1")
		var saved: Dictionary = manager.commit_backup_action(prepared.value.token)
		_check(saved.ok, str(saved))
		if saved.ok:
			var parsed: Dictionary = StrictJson.parse_object(storage.read_text("slot_1.json").value)
			var checked: Dictionary = SCHEMA.validate(parsed.value)
			_check(checked.ok, str(checked))
			var current: Dictionary = checked.value.candidate.current_snapshot
			_check(current.snapshot.gameplay.money == 200, "save captures current gameplay")
			_check(current.snapshot.narrative_checkpoint == snapshot.narrative_checkpoint, "save retains exact reading anchor")
			_check(current == manager.get_latest_stable_checkpoint().value.bundle, "journal agrees with durable manual checkpoint")
	manager.free()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)
