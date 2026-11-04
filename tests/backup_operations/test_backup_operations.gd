extends SceneTree

const FIXTURE := preload("res://tests/support/ScenePauseLoadFixture.gd")
const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
var failures := 0
var projection_events := 0
var fixture: RefCounted

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	fixture = FIXTURE.new()
	if not _ok(await fixture.setup_pause(self), "current scene owners"):
		_finish()
		return
	var manager: Node = fixture.manager
	var port := PORT.new()
	if not _ok(port.configure(manager), "Backup presentation"):
		_finish()
		return
	var empty := port.get_projection()
	if not _ok(empty, "empty projection"):
		_finish()
		return
	_check(empty.value.records.size() == 9, "nine drawers")
	for index: int in range(9):
		var record: Dictionary = empty.value.records[index]
		_check(record.locator == PORT.LOCATORS[index] and record.state == "empty", "exact empty locator")
	var board := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
	fixture.participants.desktop_board = preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd").new(board, fixture.issuer)
	if not _ok(manager.configure_scene_restore_participants(fixture.participants), "live board restore owner"):
		_finish()
		return
	if not _ok(await fixture.start_text(), "current New Run"):
		_finish()
		return
	if not _ok(fixture.game.configure_desktop_snapshot_provider(func() -> Dictionary:
		return {"board": board.capture(), "consequence": fixture.game._desktop_snapshot.consequence}), "live board capture"):
		_finish()
		return
	fixture.pause._services.backup_capture = root.get_node("ApplicationBootstrap")._capture_paused_checkpoint_inputs
	if not _ok(await fixture.pause.request_pause(), "pause current reading"):
		_finish()
		return
	if not _ok(manager.configure_backup_capture_provider(
		fixture.router.capture_pause_backup_checkpoint_inputs), "current capture provider"):
		_finish()
		return
	port.projection_changed.connect(func() -> void: projection_events += 1)
	await process_frame
	projection_events = 0
	var initial := port.prepare_action("save", "slot:2")
	if not _ok(initial, "prepare numbered save"):
		_finish()
		return
	_check(not initial.value.confirmation_required, "empty numbered save needs no confirmation")
	_check(not fixture.storage.exists("slot_2.json"), "preparation does not write")
	if not _ok(port.commit_action(initial.value.token), "commit numbered save"):
		_finish()
		return
	var record: Dictionary = port.get_projection().value.records[3]
	_check(record.state == "occupied" and record.family == "scene" and record.actions.load, "current save is loadable")
	var saved: Dictionary = fixture.storage.read_text("slot_2.json")
	if not _ok(saved, "saved bytes"):
		_finish()
		return
	_check(SCHEMA.validate(preload("res://scripts/validation/StrictJson.gd").parse_object(saved.value).value).ok, "current saved document validates")
	var overwrite := port.prepare_action("save", "slot:2")
	if _ok(overwrite, "prepare overwrite"):
		_check(overwrite.value.confirmation_kind == "overwrite", "occupied slot asks to overwrite")
		port.cancel_action(overwrite.value.token)
		_check(fixture.storage.read_text("slot_2.json").value == saved.value, "cancel preserves exact bytes")
	var quick := port.prepare_action("save", "quick")
	if _ok(quick, "prepare Quick"):
		_ok(port.commit_action(quick.value.token), "save Quick")
	var deletion := port.prepare_action("delete", "slot:2")
	if _ok(deletion, "prepare delete"):
		_check(deletion.value.confirmation_required, "delete asks for confirmation")
		_ok(port.commit_action(deletion.value.token), "delete numbered save")
		_check(not fixture.storage.exists("slot_2.json"), "delete removes selected file")
		_check(fixture.storage.exists("quicksave.json"), "delete preserves Quick")
	_check(projection_events == 0, "commits defer projection notification")
	await process_frame
	_check(projection_events == 1, "owner changes coalesce into one projection notification")
	_finish()

func _ok(result: Dictionary, message: String) -> bool:
	_check(result.get("ok", false), message + ": " + str(result))
	return result.get("ok", false)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", message)

func _finish() -> void:
	if is_instance_valid(fixture.game): fixture.game._desktop_snapshot_provider = Callable()
	await fixture.close_restart()
	print("BACKUP_OPERATIONS_PASS" if failures == 0 else "BACKUP_OPERATIONS_FAIL %d" % failures)
	quit(0 if failures == 0 else 1)
