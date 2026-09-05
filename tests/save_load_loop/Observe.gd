extends Node
## Test-only observer, installed first in the disposable copy's autoload list.
## Production startup, owners and main scene remain intact.
const SAVE_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")

var _checks := 0
var _failures: Array[String] = []
var _facts: Dictionary = {}

func _enter_tree() -> void:
	var expected := OS.get_environment("DWM_EXPECTED_USER_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().trim_suffix("/")
	if expected.is_empty() or actual.nocasecmp_to(expected) != 0:
		printerr("SAVE_LOAD_ISOLATION_REFUSED expected=", expected, " actual=", actual)
		# quit() is deferred; stop before subsequent production autoloads can write.
		OS.kill(OS.get_process_id())
		return
	_facts["user_root"] = actual
	print("SAVE_LOAD_ISOLATION_PROVEN ", actual)

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
		printerr("SAVE_LOAD_CHECK_FAILED ", description)
	return condition

func _run() -> void:
	await get_tree().process_frame
	var bootstrap: Node = get_node_or_null("/root/ApplicationBootstrap")
	if not _check(bootstrap != null, "Production Bootstrap autoload exists"):
		_finish(false)
		return
	var startup: Dictionary = bootstrap.get_startup_state()
	_facts["startup"] = startup
	if not _check(startup.get("ready", false) and startup.get("mode") == &"final", "Full production startup reaches final ready: " + JSON.stringify(startup)):
		_finish(false)
		return
	var scene: Node = get_tree().current_scene
	if not _check(scene != null and scene.scene_file_path == "res://scenes/menu/MenuScene.tscn", "Original production Menu is the startup scene"):
		_finish(false)
		return
	if OS.get_environment("DWM_SAVE_LOAD_PHASE") == "smoke":
		_finish(true)
		return
	await _exercise_loop(scene, bootstrap)
	_finish(_failures.is_empty())

func _exercise_loop(menu: Node, bootstrap: Node) -> void:
	var state: Node = get_node("/root/GameState")
	var saves: Node = get_node("/root/SaveManager")
	var router: Node = get_node("/root/SceneRouter")
	var route_before: Dictionary = router.capture_restore_state()
	var rejected: Dictionary = router.prepare_route_restore("missing.integration.route", {})
	_check(not rejected.get("ok", false) and router.capture_restore_state() == route_before, "Unknown restore route rejects without changing live route")
	menu.get_node("%NewAccButton").pressed.emit()
	if not await _await_scene("res://scenes/opening/OpeningScene.tscn"):
		return
	var opening: Node = get_tree().current_scene
	if not _check(not opening.get("_dialogic_blocked"), "Production registered opening timeline starts"):
		return
	opening.get_node("%ContinueButton").pressed.emit()
	if not await _await_scene("res://scenes/main/MainGameScene.tscn"):
		return
	var main: Node = get_tree().current_scene
	var desktop: Node = main.get("_computer_desktop_instance")
	if not _check(is_instance_valid(desktop), "Production main scene mounts desktop"):
		return
	desktop.launcher_buttons[&"backup"].pressed.emit()
	await _settle()
	var app: Node = desktop._cached_app_windows.get(&"backup")
	if not _check(is_instance_valid(app) and app.visible, "Actual launcher opens configured Backup"):
		return
	if not _check(not app.action_buttons.save.disabled, "Real owner enables fresh in-run Save"):
		return
	var saved_money: int = state.money
	var saved_day: int = state.day
	var saved_gameplay: Dictionary = state.capture_run_snapshot_input()["gameplay"]
	app.action_buttons.save.pressed.emit()
	await _settle()
	if not _check(app.status_label.text == "Saved" and app.last_result.get("ok", false), "UI publishes Saved after the real disk owner completes"):
		_facts["save_result"] = app.last_result
		return
	var slot_path: String = str(_facts.user_root).path_join("saves/slot_1.json")
	var original_bytes := FileAccess.get_file_as_string(slot_path)
	var document: Variant = JSON.parse_string(original_bytes)
	if not _check(document is Dictionary and document.has("current_snapshot"), "Real slot file contains a save document"):
		return
	var validated: Dictionary = SAVE_SCHEMA.validate(document)
	if not _check(validated.get("ok", false), "Real schema validates the disk document"):
		return
	document = validated.value.candidate
	var snapshot: Dictionary = document.current_snapshot.snapshot
	_facts["saved"] = {"route": snapshot.route_id, "active_app": snapshot.active_app_id, "day": snapshot.lifecycle.day, "money": snapshot.gameplay.money, "kind": document.current_snapshot.checkpoint_kind}
	if not _check(snapshot.route_id == "main" and snapshot.active_app_id == "backup" and snapshot.gameplay.opening_seen, "Saved checkpoint reflects current desktop and completed opening, not the initial opening checkpoint"):
		return
	_check(snapshot.gameplay.money == saved_money and snapshot.lifecycle.day == saved_day, "Saved durable facts match the live state at Save")
	var graph: Dictionary = bootstrap.get_desktop_contract_state()
	var board: Object = instance_from_id(int(graph.board_state_instance_id))
	var consequence: Object = instance_from_id(int(graph.consequence_state_instance_id))
	_check(snapshot.desktop.board == board.capture() and snapshot.desktop.consequence == consequence.capture().value.state, "Saved desktop equals the actual retained board and consequence owners")
	var issuer: Object = instance_from_id(int(graph.issuer_instance_id))
	var issued: Dictionary = issuer.issue(&"transaction_id")
	if not _check(issued.get("ok", false), "Production identity owner issues the test transaction ID"):
		return
	var effects: Array[String] = ["money:+5"]
	var changed: Dictionary = state.commit_effect_transaction(str(issued.value.token), effects, "save_load_loop.integration_probe")
	if not _check(changed.get("ok", false) and state.money == saved_money + 5, "Real effect owner applies registered money:+5 transaction"):
		_facts["mutation_result"] = changed
		return
	# Visit another real app, so restore must replace actual host/cache presentation.
	desktop.return_home()
	desktop.launcher_buttons[&"settings"].pressed.emit()
	await _settle()
	_check(desktop._active_id == &"settings", "Unsaved presentation moves to Settings")
	desktop.return_home()
	desktop.launcher_buttons[&"backup"].pressed.emit()
	await _settle()
	app = desktop._cached_app_windows[&"backup"]
	app.mode_buttons.load.pressed.emit()
	await _settle()
	var before_load: Dictionary = state.capture_run_snapshot_input()
	var old_scene_id := main.get_instance_id()
	app.action_buttons.load.pressed.emit()
	await _settle()
	if not _check(is_instance_valid(app.confirmation) and app.confirmation.cancel_button.has_focus(), "Real Load preparation opens Cancel-first confirmation"):
		return
	app.confirmation.cancel_button.pressed.emit()
	await _settle()
	_check(state.capture_run_snapshot_input() == before_load and main.get_instance_id() == old_scene_id, "Cancelling real Load preserves unsaved run and scene")
	app.action_buttons.load.pressed.emit()
	await _settle()
	if not _check(is_instance_valid(app.confirmation), "A second Load requires fresh consent"):
		return
	# Change only this runner's proven isolated file after consent preparation.
	var file := FileAccess.open(slot_path, FileAccess.WRITE)
	if not _check(file != null, "Isolated stale-target fixture is writable"):
		return
	file.store_string(original_bytes + "\n")
	file.close()
	app.confirmation.confirm_button.pressed.emit()
	await _settle()
	_check(not app.last_result.get("ok", false) and app.action_buttons.has("cancel"), "Changed real disk revision rejects the prepared Load")
	_check(state.capture_run_snapshot_input() == before_load and get_tree().current_scene.get_instance_id() == old_scene_id, "Rejected real Load preserves live run and actual scene")
	file = FileAccess.open(slot_path, FileAccess.WRITE)
	file.store_string(original_bytes)
	file.close()
	app.action_buttons.cancel.pressed.emit()
	await _settle()
	_facts["restore_notifications"] = 0
	saves.run_restored.connect(func(_checkpoint: String, _route: String): _facts["restore_notifications"] += 1)
	app.action_buttons.load.pressed.emit()
	await _settle()
	if not _check(is_instance_valid(app.confirmation), "Restored exact file requires another fresh confirmation"):
		return
	app.confirmation.confirm_button.pressed.emit()
	_facts["load_result"] = app.last_result.duplicate(true)
	if not _check(app.last_result.get("ok", false), "Real owner accepts the fresh confirmed Load: " + JSON.stringify(app.last_result)):
		return
	if not await _await_scene("res://scenes/main/MainGameScene.tscn", old_scene_id):
		return
	await _settle()
	_check(_facts.restore_notifications == 1, "Restore owner publishes exactly one completed restore")
	_check(state.money == saved_money and state.day == saved_day and state.opening_seen, "Load restores saved money, day and opening progress")
	var restored_gameplay: Dictionary = state.capture_run_snapshot_input()["gameplay"]
	for key in ["coins", "stats", "story_flags", "inventory", "friends"]:
		_check(restored_gameplay[key] == saved_gameplay[key], "Load preserves saved gameplay field " + key)
	_check(not state.capture_run_snapshot_input().applied_effect_transaction_ids.has(str(issued.value.token)), "Load removes the unsaved effect transaction receipt")
	_check(not state.capture_run_snapshot_input().command_receipts.has(str(issued.value.token)), "Load removes the unsaved command receipt")
	var restored_main: Node = get_tree().current_scene
	var restored_desktop: Node = restored_main.get("_computer_desktop_instance")
	if not _check(is_instance_valid(restored_desktop) and restored_desktop._active_id == &"backup", "Actual restored scene reopens saved Backup host route"):
		return
	var restored_app: Node = restored_desktop._cached_app_windows.get(&"backup")
	if not _check(is_instance_valid(restored_app) and restored_app.visible and restored_app.active_mode == "save" and restored_app.selected_locator == "slot:1", "Restored Backup resets transient UI to Save and Slot 1"):
		return
	_check(not restored_app.action_buttons.save.disabled, "Restored Backup is usable after the real owner releases its gate")
	_check(restored_desktop.return_home().get("ok", false) and restored_desktop.icon_grid.visible, "Home remains usable in the physically restored desktop")
	_facts["restored"] = {"scene": restored_main.scene_file_path, "scene_replaced": restored_main.get_instance_id() != old_scene_id, "money": state.money, "day": state.day}

func _settle() -> void:
	for frame in 4:
		await get_tree().process_frame

func _await_scene(path: String, previous_id: int = 0) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var scene: Node = get_tree().current_scene
		if scene != null and scene.scene_file_path == path and scene.is_node_ready() and scene.get_instance_id() != previous_id:
			return _check(true, "Actual ready scene " + path)
	return _check(false, "Timed out awaiting actual ready scene " + path)

func _finish(passed: bool) -> void:
	print("SAVE_LOAD_LOOP_SUMMARY ", JSON.stringify({"checks": _checks, "failures": _failures, "facts": _facts}))
	if passed and _failures.is_empty():
		print("SAVE_LOAD_STARTUP_PASS" if OS.get_environment("DWM_SAVE_LOAD_PHASE") == "smoke" else "SAVE_LOAD_LOOP_PASS")
	get_tree().quit(0 if passed and _failures.is_empty() else 1)
