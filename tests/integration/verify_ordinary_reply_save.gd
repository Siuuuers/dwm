extends "res://tests/integration/verify_playable_startup.gd"
## Isolated public UI probe. The explicit locale fixture reproduces the reported setting.
## --reply-choice=A|B|C selects one registered first-day reply; A is the default.
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const RECOVERY_PROOF_PATH := "user://ordinary-reply-recovery-proof.json"
var _reply_choice := "A"
var _reply_retry_proof := false
var _reply_recovery_resume := false
var _isolated_root := ""
var _user_root := ""


class OneShotAutosaveMarkerBlocker extends "res://scripts/infrastructure/storage/FileOps.gd":
	var target_path := ""
	var attempts := 0
	var injected := false
	var target_was_occupied := false
	var create_error := OK
	var cleanup_error := OK
	var raw_result: Dictionary = {}
	var _created_directory := false

	func _init(path: String) -> void:
		target_path = path.replace("\\", "/").simplify_path()

	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if attempts > 0 or path.replace("\\", "/").simplify_path() != target_path:
			return super.write_bytes(path, bytes)
		attempts += 1
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			target_was_occupied = true
			return super.write_bytes(path, bytes)
		create_error = DirAccess.make_dir_absolute(path)
		if create_error != OK:
			return super.write_bytes(path, bytes)
		_created_directory = true
		injected = true
		raw_result = super.write_bytes(path, bytes)
		cleanup_created_directory()
		return raw_result.duplicate(true)

	func cleanup_created_directory() -> bool:
		if not _created_directory:
			return cleanup_error == OK
		var directory := DirAccess.open(target_path)
		if directory == null or not directory.get_files().is_empty() or not directory.get_directories().is_empty():
			cleanup_error = ERR_ALREADY_IN_USE
			return false
		cleanup_error = DirAccess.remove_absolute(target_path)
		if cleanup_error == OK:
			_created_directory = false
		return cleanup_error == OK

func _initialize() -> void:
	var destination := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path()
	var isolated_appdata := isolated.get_base_dir().path_join("appdata").to_lower()
	if not _check(not isolated.is_empty() and isolated.get_file() == "dwm_test_root" and destination.to_lower().begins_with(isolated_appdata + "/"), "reply probe requires isolated user directory"): return
	_isolated_root = isolated
	_user_root = destination
	var choice_seen := false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--reply-retry-proof":
			if not _check(not _reply_retry_proof, "duplicate --reply-retry-proof"): return
			_reply_retry_proof = true
			continue
		if argument == "--reply-recovery-resume":
			if not _check(not _reply_recovery_resume, "duplicate --reply-recovery-resume"): return
			_reply_recovery_resume = true
			continue
		if argument.begins_with("--reply-choice="):
			var requested := argument.trim_prefix("--reply-choice=")
			if not _check(not choice_seen and requested in ["A", "B", "C"], "reply choice must be one explicit A, B or C"): return
			_reply_choice = requested
			choice_seen = true
			continue
		if not argument.begins_with("--reply-seed-root="): continue
		var source := ProjectSettings.globalize_path(argument.trim_prefix("--reply-seed-root="))
		if not _copy_reply_seed(source, destination): return
	if not _check(not (_reply_retry_proof and _reply_recovery_resume), "reply recovery modes are mutually exclusive"): return
	_run.call_deferred()

func _copy_reply_seed(source: String, destination: String) -> bool:
	var directory := DirAccess.open(source)
	if not _check(directory != null, "reply seed source exists"): return false
	if not _check(DirAccess.make_dir_recursive_absolute(destination) == OK, "reply seed target directory"): return false
	for folder: String in directory.get_directories():
		if folder == "logs": continue
		if not _copy_reply_seed(source.path_join(folder), destination.path_join(folder)): return false
	for filename: String in directory.get_files():
		if not _check(DirAccess.copy_absolute(source.path_join(filename), destination.path_join(filename)) == OK, "reply seed copied " + filename): return false
	return true

func _run() -> void:
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	var startup: Dictionary = bootstrap.get_startup_state()
	var startup_deadline := Time.get_ticks_msec() + 15000
	while not startup.get("ready", false) and Time.get_ticks_msec() < startup_deadline:
		await process_frame
		startup = bootstrap.get_startup_state()
	if not _check(startup.get("ready", false), "reply probe startup " + JSON.stringify(startup)): return
	var profile: Node = root.get_node("ProfileManager")
	var candidate: Dictionary = profile.get_profile_snapshot()
	candidate.preferences.language = {"primary_locale_id": "zh_CN", "secondary_locale_id": "en", "dual_enabled": true}
	var localized: Dictionary = profile.commit_prepared_profile(candidate)
	if not _check(localized.get("ok", false), "reply locale fixture " + str(localized.get("code"))): return
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	if not _check(current_scene != null and current_scene.has_node("%NewAccButton"), "reply probe real title"): return
	if "--reply-login" in OS.get_cmdline_user_args() or _reply_recovery_resume:
		var login: Button = current_scene.get_node("%LogInButton")
		if not _check(not login.disabled, "reply saved Login available"): return
		login.pressed.emit()
		await _frames()
		var picker: Node = current_scene._backup_app_instance
		if not _check(picker != null and picker.is_visible_in_tree(), "reply real Login picker"): return
		picker.drawer_buttons["autosave"].pressed.emit()
		if not _check(not picker.action_buttons["load"].disabled, "reply Autosave Load available"): return
		picker.action_buttons["load"].pressed.emit()
		if is_instance_valid(picker.confirmation): picker.confirmation.confirm_button.pressed.emit()
	else:
		var menu: Node = current_scene
		menu.get_node("%NewAccButton").pressed.emit()
		await _frames()
		if is_instance_valid(menu) and is_instance_valid(menu._confirmation):
			if not _check(not str(menu._new_acc_token).is_empty(), "reply New Account has a real prepared replacement"): return
			menu._confirmation.confirm_button.pressed.emit()
	await _frames()
	var game: Node = root.get_node("GameState")
	var save_manager: Node = root.get_node("SaveManager")
	var desktop: Node
	var desktop_deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < desktop_deadline:
		if is_instance_valid(current_scene):
			desktop = current_scene.find_child("ComputerDesktop", true, false)
		if desktop != null and desktop.is_visible_in_tree() and not bool(save_manager.get("_new_run_busy")) \
				and game.capture_live_session().get("value", {}).get("active", false): break
		await process_frame
	if not _check(desktop != null and desktop.is_visible_in_tree() and not bool(save_manager.get("_new_run_busy")) \
			and game.capture_live_session().get("value", {}).get("active", false), "reply probe active desktop after completed transaction before deadline"): return
	if _reply_recovery_resume:
		await _verify_recovery_resume(game, desktop)
		return
	if "--reply-active-board" in OS.get_cmdline_user_args():
		if not _check(desktop.open_app(&"minesweeper").get("ok", false), "reply active board open"): return
		await _frames()
		var mines: Node = desktop._cached_app_windows[&"minesweeper"]
		mines.panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(mines.panel.public_view.board.revision))
		if not _check(mines.last_result.get("ok", false), "reply prior first Reveal " + str(mines.last_result.get("code"))): return
		if not _check(desktop.return_home().get("ok", false), "reply Home after active board"): return
	var home: Dictionary = desktop.return_home()
	if not _check(home.get("ok", false), "reply Home " + JSON.stringify(home)): return
	var opened: Dictionary = desktop.open_app(&"contacts")
	if not _check(opened.get("ok", false), "reply Contacts open " + JSON.stringify(opened)): return
	await _frames()
	var app: Node = desktop._cached_app_windows[&"contacts"]
	app.contacts_panel.open_requested.emit("lavinia")
	await _frames()
	var choice: Button = app.find_child("OrdinaryReply" + _reply_choice, true, false)
	if not _check(choice != null and choice.is_visible_in_tree() and not choice.disabled, "reply actual " + _reply_choice + " visible " + str(app.last_result.get("code"))): return
	if not await _capture_screen("reply-01-lavinia-before-click"): return
	if _reply_retry_proof:
		await _run_retry_proof(bootstrap, game, app, choice)
		return
	if not await _click_reply(choice): return
	for frame: int in 180:
		await process_frame
		if game.get_pending_ordinary_echoes().size() == 1 or not app.last_result.get("ok", false): break
	var diagnostic := {"choice": _reply_choice, "code": str(app.last_result.get("code", "")), "message": str(app.last_result.get("message", "")),
		"path": str(app.last_result.get("path", "")), "phase": "commit" if not app._ordinary_pending.is_empty() else "prepare",
		"drawn": app._ordinary_drawn, "busy": app._ordinary_busy, "locale": app._primary,
		"gate": str(bootstrap._application_gate.get_active_owner()), "echo_count": game.get_pending_ordinary_echoes().size()}
	if not await _capture_screen("reply-02-lavinia-after-click"): return
	print("ORDINARY_REPLY_DIAGNOSTIC: " + JSON.stringify(diagnostic))
	if not _check(game.get_pending_ordinary_echoes().size() == 1, "reply did not persist " + JSON.stringify(diagnostic)): return
	if not _check(game.get_pending_ordinary_echoes()[0].reply_id == "reply.ordinary.lavinia.day1." + _reply_choice.to_lower(), "reply persisted the exact clicked choice"): return
	print("ORDINARY_REPLY_SAVE_PASS: real title entry -> Chinese ordinary reply " + _reply_choice + " -> actual draw -> durable echo")
	quit(0)


func _run_retry_proof(bootstrap: Node, game: Node, app: Node, choice: Button) -> void:
	var manager: Node = root.get_node("SaveManager")
	var storage: Object = manager._storage
	if not _check(storage == bootstrap._saves_storage, "reply proof uses Bootstrap's retained save storage"): return
	var selected_root := str(bootstrap._selected_root).replace("\\", "/").simplify_path()
	var storage_root := str(storage.describe_root()).replace("\\", "/").simplify_path()
	var selected_is_isolated := selected_root.to_lower() == _isolated_root.to_lower() or selected_root.to_lower() == _user_root.to_lower()
	if not _check(selected_is_isolated and storage_root.to_lower() == selected_root.path_join("saves").to_lower(), "reply fault target belongs to this isolated run"): return
	var autosave_path := storage_root.path_join("autosave.json")
	var marker_path := storage_root.path_join("autosave.json.txn.json")
	if not _check(marker_path.get_base_dir().to_lower() == storage_root.to_lower(), "reply marker target stays in the isolated save root"): return
	if not _check(FileAccess.file_exists(autosave_path), "reply proof has a real autosave baseline"): return
	if not _check(not FileAccess.file_exists(marker_path) and not DirAccess.dir_exists_absolute(marker_path), "reply marker target starts absent"): return
	var contacts_before: Dictionary = game.contacts.duplicate(true)
	var autosave_before := FileAccess.get_file_as_bytes(autosave_path)
	if not _check(not autosave_before.is_empty(), "reply autosave baseline has bytes"): return
	var original_ops: Object = storage._file_ops
	if not _check(original_ops != null and original_ops._open_writes.is_empty(), "reply original FileOps has no pending write"): return
	var blocker := OneShotAutosaveMarkerBlocker.new(marker_path)
	storage._file_ops = blocker
	var clicked := await _click_reply(choice)
	if clicked:
		for frame: int in 180:
			await process_frame
			if blocker.attempts == 1 and not app._ordinary_busy \
					and is_instance_valid(app._ordinary_retry) and not app._ordinary_retry.disabled:
				break
	var cleaned := blocker.cleanup_created_directory()
	storage._file_ops = original_ops
	if not _check(clicked, "reply fault click completed"): return
	if not _check(storage._file_ops == original_ops and original_ops._open_writes.is_empty(), "reply proof restored the exact original FileOps"): return
	if not _check(blocker.attempts == 1 and blocker.injected and not blocker.target_was_occupied \
			and blocker.create_error == OK and cleaned and blocker.cleanup_error == OK,
		"one real empty-directory marker fault was injected and removed"): return
	if not _check(not blocker.raw_result.get("ok", false) and blocker.raw_result.get("code") == &"write_failed",
		"native FileAccess returned the marker write failure " + JSON.stringify(blocker.raw_result)): return
	if not _check(not app.last_result.get("ok", false), "reply save failure reached the visible app"): return
	if not _check(game.contacts == contacts_before, "failed reply restores the full Contacts state"): return
	if not _check(FileAccess.get_file_as_bytes(autosave_path) == autosave_before, "failed reply restores exact autosave bytes"): return
	if not _check(not FileAccess.file_exists(marker_path) and not DirAccess.dir_exists_absolute(marker_path), "reply fault leaves no marker blocker"): return
	var command: Dictionary = app._ordinary_pending.duplicate(true)
	var retained: Dictionary = app._presentation_port.get_pending_ordinary_reply()
	if not _check(not command.is_empty() and retained.get("value", {}).get("command") == command,
		"failed reply retains its exact pending command"): return
	if not _check(app._ordinary_drawn and app.contacts_panel._pending_reply == command.rendered_line \
			and is_instance_valid(app.contacts_panel._pending_label) \
			and app.contacts_panel._pending_label.text == command.rendered_line.text,
		"failed reply retains the actually drawn line"): return
	var retry: Button = app._ordinary_retry
	if not _check(is_instance_valid(retry) and retry.is_visible_in_tree() and not retry.disabled, "native Retry is available"): return
	if not await _capture_screen("reply-03-save-failure-retained"): return
	if not await _click_reply(retry): return
	for frame: int in 180:
		await process_frame
		if game.get_pending_ordinary_echoes().size() == 1 and app._ordinary_pending.is_empty(): break
	var echoes: Array = game.get_pending_ordinary_echoes()
	if not _check(echoes.size() == 1 and app.last_result.get("ok", false) and app._ordinary_pending.is_empty(),
		"one native Retry durably commits the retained reply"): return
	if not _check(echoes[0].reply_transaction_id == command.command_id and echoes[0].reply_id == command.reply_id,
		"durable echo belongs to the retained command"): return
	var receipt: Dictionary = game.contacts.transaction_receipts.get(command.command_id, {})
	if not _check(receipt.get("kind") == "ordinary_reply" and receipt.get("command_issuer_receipt") == command.command_issuer_receipt \
			and receipt.get("rendered_line") == command.rendered_line,
		"durable receipt preserves the exact command and drawn line"): return
	if not _check(receipt.get("message_ids", []).size() == 3,
		"retried receipt owns the incoming message, outgoing reply and response"): return
	for message_id: String in receipt.get("message_ids", []):
		var occurrences := 0
		for message: Dictionary in game.contacts.messages[command.friend_id]:
			if message.get("message_id") == message_id and message.get("parameters", {}).get("reply_transaction_id") == command.command_id:
				occurrences += 1
		if not _check(occurrences == 1, "Retry creates one owned message " + message_id): return
	await _frames()
	if not _check(game.get_pending_ordinary_echoes().size() == 1 \
			and game.contacts.transaction_receipts.get(command.command_id) == receipt,
		"draw and refresh callbacks do not duplicate the retried reply"): return
	if not _write_recovery_proof(game.contacts, echoes[0], command, autosave_path): return
	if not await _capture_screen("reply-04-retry-saved"): return
	print("ORDINARY_REPLY_RETRY_PROOF_PASS: real marker write failure -> exact rollback -> native Retry once -> durable reply; seed=" + _user_root)
	quit(0)


func _write_recovery_proof(contacts: Dictionary, echo: Dictionary, command: Dictionary, autosave_path: String) -> bool:
	var contacts_json := _canonical(contacts, "reply proof Contacts canonicalize")
	var echo_json := _canonical(echo, "reply proof echo canonicalizes")
	var command_json := _canonical(command, "reply proof command canonicalizes")
	if contacts_json.is_empty() or echo_json.is_empty() or command_json.is_empty(): return false
	var proof := CANON.stringify({"contacts_json": contacts_json, "echo_json": echo_json,
		"command": command.duplicate(true), "command_json": command_json,
		"autosave_sha256": _sha256(FileAccess.get_file_as_bytes(autosave_path))})
	if not _check(proof.get("ok", false), "reply recovery proof canonicalizes"): return false
	var proof_path := ProjectSettings.globalize_path(RECOVERY_PROOF_PATH).replace("\\", "/").simplify_path()
	if not _check(proof_path.to_lower().begins_with(_user_root.to_lower() + "/"), "reply proof remains in isolated user data"): return false
	var output := FileAccess.open(proof_path, FileAccess.WRITE)
	if not _check(output != null, "reply recovery proof opens"): return false
	output.store_string(str(proof.value))
	output.flush()
	var write_error := output.get_error()
	output.close()
	return _check(write_error == OK, "reply recovery proof flushes")


func _verify_recovery_resume(game: Node, desktop: Node) -> void:
	var parsed := STRICT.parse_object(FileAccess.get_file_as_string(RECOVERY_PROOF_PATH))
	if not _check(parsed.get("ok", false), "prior reply recovery proof exists"): return
	var proof: Dictionary = parsed.value
	var contacts_json := _canonical(game.contacts, "restored Contacts canonicalize")
	if contacts_json.is_empty(): return
	if not _check(contacts_json == proof.get("contacts_json"), "fresh Load restores exact Contacts"): return
	var echoes: Array = game.get_pending_ordinary_echoes()
	if not _check(echoes.size() == 1 and _canonical(echoes[0], "restored echo canonicalizes") == proof.get("echo_json"),
		"fresh Load restores the exact pending echo"): return
	var command_value: Variant = proof.get("command")
	if not _check(command_value is Dictionary and not command_value.is_empty(), "reply recovery proof retains the command"): return
	var command: Dictionary = command_value
	if not _check(_canonical(command, "restored command canonicalizes") == proof.get("command_json"),
		"fresh Load proof retains the exact command"): return
	var receipt: Dictionary = game.contacts.transaction_receipts.get(command.command_id, {})
	if not _check(receipt.get("transaction_id") == command.command_id and receipt.get("reply_id") == command.reply_id \
			and receipt.get("friend_id") == command.friend_id and receipt.get("locale") == command.locale \
			and receipt.get("command_issuer_receipt") == command.command_issuer_receipt \
			and receipt.get("rendered_line") == command.rendered_line \
			and echoes[0].reply_transaction_id == command.command_id,
		"fresh Load retains the reply's exact command binding"): return
	var storage: Object = root.get_node("SaveManager")._storage
	var autosave_path := str(storage.describe_root()).path_join("autosave.json")
	if not _check(_sha256(FileAccess.get_file_as_bytes(autosave_path)) == proof.get("autosave_sha256"),
		"fresh Load uses the successful Retry autosave"): return
	if not _check(desktop.return_home().get("ok", false) and desktop.open_app(&"contacts").get("ok", false), "recovery Contacts opens"): return
	await _frames()
	var app: Node = desktop._cached_app_windows[&"contacts"]
	app.contacts_panel.open_requested.emit(str(command.friend_id))
	await _frames()
	if not _check(app._ordinary_choices.is_empty() and app._ordinary_pending.is_empty() \
			and app._presentation_port.get_pending_ordinary_reply().get("value", {}).is_empty(),
		"fresh Load offers no duplicate reply choices or stale pending command"): return
	if not await _capture_screen("reply-05-cold-restored"): return
	print("ORDINARY_REPLY_RECOVERY_RESUME_PASS: fresh process -> real Login -> Autosave Load -> exact Contacts and command")
	quit(0)


func _canonical(value: Variant, detail: String) -> String:
	var result: Dictionary = CANON.stringify(value)
	if not _check(result.get("ok", false), detail): return ""
	return str(result.value)


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _click_reply(button: Button) -> bool:
	var window := button.get_window()
	window.grab_focus()
	for frame: int in 3: await process_frame
	if not _check(window.has_focus() and button.is_visible_in_tree() and not button.disabled, "reply real mouse source is focused and visible"): return false
	var point := button.get_global_rect().get_center()
	if not _check(button.get_viewport_rect().has_point(point), "reply mouse point lies in the actual viewport"): return false
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	Input.parse_input_event(press)
	for frame: int in 3: await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.global_position = point
	release.pressed = false
	Input.parse_input_event(release)
	return true
