extends "res://tests/integration/verify_playable_startup.gd"
## Connected cloud proof, with test-only prose and real gameplay/persistence owners.
## The Python driver starts WRITE and READ as separate processes in one proven root.

const FIXTURE_CATALOG := preload("res://tests/support/SoloReadingRailTimelineCatalog.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const READING_CATALOGUE := "res://tests/fixtures/dialogic/solo_reading_rail_catalogue.json"
const EXPECTED_LINES := ["fixture.solo.pre.a", "fixture.solo.pre.b", "fixture.solo.post.a"]

var _reading_mode := ""
var _speech_admissions := 0
var _history_observations := 0
var _trace_sequence := 0
var _pause_save_proof: Dictionary = {}


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--reading-rail-mode="):
			_reading_mode = argument.trim_prefix("--reading-rail-mode=")
	if not _check(_reading_mode in ["write", "read"], "explicit write/read process mode"): return
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty(), "isolated test root required"): return
	if not _check(DisplayServer.get_name() != "headless", "real cloud software rendering required"): return
	await _frames()
	if not _check(root.get_node("ApplicationBootstrap").get_startup_state().get("ready", false), "real bootstrap is ready"): return
	var bridge: Node = root.get_node("DialogicBridge")
	var installed: Dictionary = bridge.initialize(FIXTURE_CATALOG)
	if not _check(installed.get("ok", false), "test-only locator injection: " + str(installed)): return
	var catalogue: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(READING_CATALOGUE))
	if not _check(catalogue.get("ok", false), "strict noncanonical catalogue"): return
	var configured: Dictionary = bridge.configure_reading_catalogue(catalogue.value)
	if not _check(configured.get("ok", false), "real reading owner accepts fixture catalogue: " + str(configured)): return
	var speech: Node = root.get_node("SystemTtsCoordinator")
	speech.speech_admitted.connect(func(_token: int, _source: String) -> void: _speech_admissions += 1)
	var capability: Dictionary = speech.refresh_capability("en")
	if not _check(capability.get("ok", false) and capability.value.get("available", false), "real native English speech control available"): return
	if _reading_mode == "read":
		await _read_process()
		return
	var profile: Node = root.get_node("ProfileManager")
	var preferences: Dictionary = profile.set_preferences({
		&"preferences.reading.read_aloud_enabled": true,
		&"preferences.reading.reveal_speed": "slow",
		&"preferences.reading.auto_enabled": false,
	})
	if not _check(preferences.get("ok", false), "real reading preferences commit"): return
	_trace("fixture_registered", {"catalogue": READING_CATALOGUE, "production_content": false})
	# Reuse real title/New Account/desktop/first board. This calls our Dating override.
	await super._run()


func _dating_journey(game: Node, desktop: Node) -> void:
	if not _check(game.day == 1, "fresh Day 1 production run"): return
	var opened: Dictionary = desktop.open_app(&"contacts")
	if not _check(opened.get("ok", false), "real Contacts opens"): return
	await _frames()
	var contacts: Node = desktop.get("_cached_app_windows")[&"contacts"]
	contacts.contacts_panel.open_requested.emit("priscilla")
	if not _check(contacts.last_result.get("ok", false)
		and game.contacts.solo_actions.get("solo:priscilla:day1", {}).get("state") == "ACCEPTED",
		"actual first-round invitation is read and accepted"): return
	if not _check(desktop.return_home().get("ok", false), "Home after Contacts"): return
	if not _check(desktop.open_app(&"schedule").get("ok", false), "real Schedule opens"): return
	await _frames()
	var schedule: Node = desktop.get("_cached_app_windows")[&"schedule"]
	schedule.panel.source_requested.emit("solo:priscilla:day1")
	if not _check(schedule.last_result.get("ok", false), "real invitation scheduled"): return
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "Schedule Done: " + str(done)): return
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		if not _check(ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss").get("ok", false),
			"real Schedule warning acknowledged"): return
	if not await _wait_line("fixture.solo.pre.a"): return
	if not _check(current_scene != null and current_scene.get("worksheet") != null, "real Dating scene mounted"): return
	var dating: Node = current_scene
	if not await _ordinary_reading_pause_save(game, dating): return
	if not await _advance_line("fixture.solo.pre.a", "fixture.solo.pre.b"): return
	if not await _inspect_history("04-pre-history", 2): return
	var bridge: Node = root.get_node("DialogicBridge")
	var pre_history: Dictionary = bridge.get_reading_history().value.duplicate(true)
	_trace("pre_history", pre_history)
	if not await _advance_line("fixture.solo.pre.b", ""): return
	if not await _wait_for_dating_board(dating): return
	_trace("automatic_board_handoff", {"record": game.capture_dating_challenge_state().value})
	dating.worksheet.cell_action_requested.emit(&"reveal", 0, int(dating.get("_physical_view").board.revision))
	var physical: Dictionary = game.capture_dating_challenge_state().value
	if not _check(physical.board is Dictionary, "actual first Reveal materializes the Dating board"): return
	await _capture_screen("05-dating-board")
	# Read hidden state only to select a legal mine input; real owners commit the loss.
	if not bool(physical.board.terminal):
		dating.worksheet.cell_action_requested.emit(&"reveal", int(physical.board.mine_indices[0]),
			int(dating.get("_physical_view").board.revision))
	if not await _wait_line("fixture.solo.post.a"): return
	physical = game.capture_dating_challenge_state().value
	if not _check(physical.phase == "post_challenge" and physical.board.terminal,
		"real terminal board and committed result precede post-prose"): return
	var post_history: Dictionary = bridge.get_reading_history().value
	if not _check(post_history.session_id == pre_history.session_id and post_history.captions.size() == 3
		and post_history.captions.slice(0, 2) == pre_history.captions,
		"one semantic session retains exact pre-prose through the real board"): return
	_trace("committed_result_then_post_prose", {"physical_record": physical, "history": post_history})
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	if not _check(not runtime.is_current_line_complete(), "Save begins while the real long post-line is partly revealed"): return
	var checkpoint_before: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(checkpoint_before.get("ok", false), "pure current reading checkpoint admitted"): return
	var saves: Node = root.get_node("SaveManager")
	var quick: Node = dating.get("_quick_commands")
	dating.get_window().grab_focus()
	await _dating_quick_key(KEY_F5)
	if not _check(quick.last_result.get("ok", false), "physical F5 saves the admitted reading frontier: " + str(quick.last_result)): return
	if not _check(runtime.current_line_id() == "fixture.solo.post.a" and runtime.is_current_line_complete(),
		"Quick completes reveal without advancing the semantic beat"): return
	var disk: Dictionary = saves.get("_storage").read_text("quicksave.json")
	if not _check(disk.get("ok", false), "real Quick bytes readable"): return
	var parsed: Dictionary = STRICT.parse_object(disk.value)
	if not _check(parsed.get("ok", false), "strict exact-number Quick document"): return
	var admitted: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(parsed.value)
	if not _check(admitted.get("ok", false), "saved document admitted by actual schema: " + str(admitted.get("code"))): return
	var snapshot: Dictionary = admitted.value.candidate.current_snapshot.snapshot
	var reading: Dictionary = snapshot.narrative_checkpoint
	if not _check(reading.get("reading_session", {}).get("frontier", {}).get("line_id") == "fixture.solo.post.a"
		and reading.reading_session.ledger.captions.size() == 3,
		"Quick contains complete session plus exact current post-line"): return
	if not _check(reading.reading_session.ledger.entry_contexts.size() == 2,
		"both immutable entry frames are durable"): return
	_trace("quick_committed", {"sha256": str(disk.value).sha256_text(), "checkpoint": reading})
	if not await _inspect_history("06-post-history", 3): return
	if not await _cancel_reading_quick_load(game, dating, reading, disk.value): return
	# Manual Backup and Quick consume the same real capture owner, with distinct slots.
	var manual: Dictionary = saves.prepare_backup_action("save", "slot:1")
	if not _check(manual.get("ok", false), "real manual Save prepares at the same frontier: " + str(manual)): return
	var committed: Dictionary = saves.commit_backup_action(manual.value.token)
	if not _check(committed.get("ok", false), "real manual Save commits: " + str(committed)): return
	if not _check(bridge.capture_reading_checkpoint(false).value == reading,
		"manual Save and Quick preserve the same admitted semantic frontier"): return
	await _capture_screen("07-post-save")
	var report: Dictionary = _report(game, reading, disk.value)
	report["ordinary_pause_save"] = _pause_save_proof.duplicate(true)
	if not _check(_write_text("saved-quick.json", disk.value), "retain exact saved Quick bytes"): return
	# A later real publication makes a prepared Save stale. Refusal must preserve
	# the later live source and the accepted Quick file; READ must restore the old beat.
	var stale: Dictionary = saves.prepare_backup_action("save", "slot:2")
	if not _check(stale.get("ok", false), "prepare candidate before deliberate live-frontier change"): return
	if not await _advance_line("fixture.solo.post.a", "fixture.solo.post.b"): return
	var changed: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(changed.get("ok", false), "later real post-line capture admitted"): return
	var refused: Dictionary = saves.commit_backup_action(stale.value.token)
	if not _check(not refused.get("ok", false), "changed-frontier manual Save refuses"): return
	if not _check(bridge.capture_reading_checkpoint(false).value == changed.value
		and saves.get("_storage").read_text("quicksave.json").value == disk.value,
		"refused candidate installs no old live state and changes no Quick byte"): return
	_trace("stale_candidate_refused", {"failure": refused, "retained_frontier": changed.value.reading_session.frontier})
	report["diverged_line_before_exit"] = runtime.current_line_id()
	report["speech_admissions"] = _speech_admissions
	report["history_observations"] = _history_observations
	if not _check(_write_text("write.json", JSON.stringify(report, "\t")), "retain WRITE report"): return
	print("READING_RAIL_WRITE_PASS: real partial Solo -> Pause/Cancel/Continue -> Backup entry -> UI Save -> History -> board -> committed result -> partial post-prose -> F5 -> manual Save -> stale-candidate refusal")
	await _finish_proof()


func _read_process() -> void:
	var expected: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("write.json")))
	if not _check(expected.get("ok", false), "WRITE report exists in this exact user root"): return
	if not _check(int(expected.value.process_id) != OS.get_process_id(), "READ is a fresh operating-system process"): return
	var saves: Node = root.get_node("SaveManager")
	var profile: Node = root.get_node("ProfileManager")
	if not _check(profile.get_preference(&"preferences.reading.read_aloud_enabled", false), "read-aloud control remains enabled after restart"): return
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var prepared: Dictionary = saves.prepare_backup_action("load", "quick")
	if not _check(prepared.get("ok", false), "fresh-process physical Quick restore prepares: " + str(prepared)): return
	_trace("fresh_restore_prepared", {"process_id": OS.get_process_id()})
	var restored: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(restored.get("ok", false), "fresh-process coordinated restore commits: " + str(restored)): return
	if not await _wait_line("fixture.solo.post.a"): return
	var game: Node = root.get_node("GameState")
	var bridge: Node = root.get_node("DialogicBridge")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(checkpoint.get("ok", false), "fresh current semantic checkpoint admitted"): return
	if not _check(current_scene != null and current_scene.get("worksheet") != null
		and game.capture_live_session().value.active, "fresh Load remounts real active Dating"): return
	if not _check(checkpoint.value.reading_session == expected.value.saved_checkpoint.reading_session,
		"fresh Load reconstructs exact complete ledger, immutable frames and stable frontier"): return
	if not _check(bridge.get("_runtime_adapter").is_current_line_complete(), "Load shows the saved beat fully visible"): return
	if not _check(game.capture_dating_challenge_state().value == expected.value.physical_record,
		"Load preserves exact committed physical result without repeating it"): return
	if not _check(profile.get_profile_snapshot() == profile_before, "Load preserves monotonic Profile history"): return
	if not _check(_speech_admissions == 0, "fresh restored beat does not repeat speech with read-aloud enabled"): return
	if not await _inspect_history("08-restored-history", 3): return
	await _capture_screen("09-restored-line")
	var disk: Dictionary = saves.get("_storage").read_text("quicksave.json")
	if not _check(disk.get("ok", false), "Quick remains physically readable after restoration"): return
	var report: Dictionary = _report(game, checkpoint.value, disk.value)
	if not _check(_write_text("read.json", JSON.stringify(report, "\t")), "retain READ report"): return
	_trace("fresh_restore_verified", {"checkpoint": checkpoint.value, "speech_admissions": _speech_admissions})
	print("READING_RAIL_READ_PASS: new process -> actual Quick Load -> same committed board -> exact stable line and complete History -> no repeated speech")
	await _finish_proof()


func _report(game: Node, checkpoint: Dictionary, quick_text: String) -> Dictionary:
	return {"mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "saved_checkpoint": checkpoint.duplicate(true),
		"canonical_transcript": root.get_node("DialogicBridge").get_reading_history().value.captions.duplicate(true),
		"current_line_id": checkpoint.reading_session.frontier.line_id,
		"physical_record": game.capture_dating_challenge_state().value.duplicate(true),
		"quick_sha256": quick_text.sha256_text(), "quick_bytes": quick_text.to_utf8_buffer().size(),
		"speech_admissions": _speech_admissions, "history_observations": _history_observations}


func _finish_proof() -> void:
	# Evidence is sealed before teardown. Abort prevents the live test text from
	# fabricating natural completion while native coroutines and speech retire.
	var bridge: Node = root.get_node("DialogicBridge")
	# Retire the fixture's reveal await before aborting. This is cleanup after
	# proof, not evidence that arbitrary partial-reveal cancellation is leak-free.
	var before_cleanup: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(before_cleanup.get("ok", false), "capture cleanup frontier"): return
	var completed: Dictionary = bridge.capture_reading_checkpoint(true)
	if not _check(completed.get("ok", false) and completed.value == before_cleanup.value,
		"fixture cleanup completes reveal without changing the ledger or frontier"): return
	var retired: Dictionary = bridge.abort_current_entry(&"reading_fixture_teardown")
	if not _check(retired.get("ok", false), "retire exact test playback without a completion receipt"): return
	var speech: Node = root.get_node("SystemTtsCoordinator")
	speech.stop(&"reading_fixture_teardown")
	await speech.wait_until_recovered()
	var dialogic: Node = root.get_node("Dialogic")
	for frame: int in 120:
		if dialogic.current_timeline == null and not dialogic.is_ending_timeline(): break
		await process_frame
	if not _check(dialogic.current_timeline == null and not dialogic.is_ending_timeline(),
		"native reading coroutine retired before process exit"): return
	await _frames()
	quit(0)


func _ordinary_reading_pause_save(game: Node, dating: Node) -> bool:
	var bridge: Node = root.get_node("DialogicBridge")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	var pause_owner: Node = root.get_node("SceneRouter").get("_production_pause")
	var saves: Node = root.get_node("SaveManager")
	if not _check(runtime.current_line_id() == "fixture.solo.pre.a" and not runtime.is_current_line_complete(),
		"ordinary Pause begins on real partial pre-prose"): return false
	await _pause_key()
	if not _check(paused and pause_owner.surface.is_visible_in_tree(), "ordinary Back opens real reading Pause"): return false
	var entered := _reading_pause_observation(game)
	if not _check(entered.native.revealing and entered.native.visible_characters >= 0
		and entered.native.visible_characters < entered.native.total_characters,
		"ordinary Pause retains a literal partial native caption"): return false
	_record_reading_pause("ordinary_pause_entered", entered)
	var foreign: Dictionary = bridge.complete_paused_reading_reveal({"handle_id": "foreign"}, _caption_layer().caption_text)
	if not _check(not foreign.get("ok", false) and foreign.get("code") == &"invalid_suspension_handle"
		and _reading_pause_observation(game) == entered,
		"real Bridge refuses foreign reveal custody without changing the retained partial source"): return false
	_pause_save_proof["foreign_handle_refused"] = true
	# Cancel an actual confirmation before any Backup request or accepted reveal completion.
	pause_owner.surface.rows[&"return"].grab_focus()
	if not await _ordinary_accept_focused(pause_owner.surface.rows[&"return"], "partial reading Return preview activation"): return false
	if not _check(pause_owner.surface.entered_action == &"return" and pause_owner.surface.cancel_button.has_focus(),
		"ordinary Return confirmation initially owns Cancel"): return false
	if not await _ordinary_accept_focused(pause_owner.surface.cancel_button, "partial reading Return Cancel"): return false
	var cancelled := _reading_pause_observation(game)
	if not _check(paused and pause_owner.surface.entered_action == &"" and cancelled == entered,
		"Cancel preserves literal partial reveal, speech, History, game and Profile"): return false
	_record_reading_pause("ordinary_pause_cancelled", cancelled)
	# Observe the release signal synchronously: later rendered frames may legitimately reveal more text.
	var continued := {}
	pause_owner.coordinator.pause_closed.connect(func() -> void:
		continued.merge(_reading_pause_observation(game), true), CONNECT_ONE_SHOT)
	pause_owner.surface.rows[&"continue"].grab_focus()
	if not await _ordinary_accept_focused(pause_owner.surface.rows[&"continue"], "partial reading Continue"): return false
	if not _check(not paused and current_scene == dating and not pause_owner.surface.visible
		and continued == entered, "Continue restores the exact partial native frontier before its next reveal frame"): return false
	_record_reading_pause("ordinary_pause_continued", continued)
	await _pause_key()
	var reentered := _reading_pause_observation(game)
	if not _check(paused and pause_owner.surface.visible and reentered.native.revealing
		and reentered.native.line_id == entered.native.line_id and reentered.source == entered.source,
		"ordinary Pause reenters the same still-partial source"): return false
	_record_reading_pause("ordinary_pause_reentered", reentered)
	pause_owner.surface.rows[&"backup"].grab_focus()
	await _frames()
	var previewed := _reading_pause_observation(game)
	if not _check(pause_owner.surface.entered_action == &"" and previewed == reentered,
		"Backup focus-only preview does not complete or mutate the partial line"): return false
	_record_reading_pause("ordinary_backup_previewed", previewed)
	if not await _ordinary_accept_focused(pause_owner.surface.rows[&"backup"], "ordinary reading Backup entry"): return false
	var backup: Control = pause_owner.surface.get("_hosts")[&"backup"]
	var hosted := _reading_pause_observation(game)
	if not _check(paused and pause_owner.surface.entered_action == &"backup" and backup.is_visible_in_tree()
		and not hosted.native.revealing and runtime.is_current_line_complete()
		and hosted.native.line_id == entered.native.line_id
		and hosted.native.reveal_generation == reentered.native.reveal_generation + 1
		and hosted.source == entered.source,
		"explicit Backup entry completes only the same line while retaining suspended source custody"): return false
	_record_reading_pause("ordinary_backup_entered", hosted)
	if not _check(backup.active_mode == "save" and backup.get("_records")["slot:3"].state == "empty"
		and not saves.get("_storage").exists("slot_3.json"),
		"real empty manual slot is available before the explicit Save"): return false
	backup.drawer_buttons["slot:3"].grab_focus()
	if not await _ordinary_accept_focused(backup.drawer_buttons["slot:3"], "ordinary reading manual-slot selection"): return false
	backup.action_buttons["save"].grab_focus()
	if not await _ordinary_accept_focused(backup.action_buttons["save"], "ordinary reading hosted Save"): return false
	if not _check(backup.last_result.get("ok", false) and backup.get("_status_key") == "saved"
		and not is_instance_valid(backup.confirmation) and paused and pause_owner.surface.entered_action == &"backup",
		"actual hosted Save commits and remains in Backup with truthful Saved status: " + str(backup.last_result)): return false
	var disk: Dictionary = saves.get("_storage").read_text("slot_3.json")
	if not _check(disk.get("ok", false), "ordinary Pause Save writes physical manual-slot bytes"): return false
	var parsed: Dictionary = STRICT.parse_object(disk.value)
	if not _check(parsed.get("ok", false), "ordinary Pause Save is strict JSON"): return false
	var admitted: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(parsed.value)
	if not _check(admitted.get("ok", false), "ordinary Pause Save passes the actual document schema"): return false
	var snapshot: Dictionary = admitted.value.candidate.current_snapshot.snapshot
	var reading: Dictionary = snapshot.narrative_checkpoint
	var saved := _reading_pause_observation(game)
	if not _check(saved == hosted and reading == entered.source.checkpoint
		and reading.reading_session.ledger.captions.size() == 1
		and snapshot.gameplay.route_context.active_dating_challenge == entered.source.physical_record,
		"physical manual Save retains the exact semantic line, ledger and unmodified Dating record"): return false
	_record_reading_pause("ordinary_pause_save_committed", saved)
	if not _check(_write_text("saved-pause-slot.json", disk.value), "retain exact ordinary Pause Save bytes"): return false
	_pause_save_proof["saved_checkpoint"] = reading.duplicate(true)
	_pause_save_proof["slot_locator"] = "slot:3"
	_pause_save_proof["slot_sha256"] = str(disk.value).sha256_text()
	_pause_save_proof["slot_bytes"] = str(disk.value).to_utf8_buffer().size()
	await _pause_key()
	if not _check(paused and pause_owner.surface.entered_action == &"" and pause_owner.surface.rows[&"backup"].has_focus(),
		"Backup Back returns to its exact Pause row without resuming"): return false
	var saved_continued := {}
	pause_owner.coordinator.pause_closed.connect(func() -> void:
		saved_continued.merge(_reading_pause_observation(game), true), CONNECT_ONE_SHOT)
	pause_owner.surface.rows[&"continue"].grab_focus()
	if not await _ordinary_accept_focused(pause_owner.surface.rows[&"continue"], "saved reading Continue"): return false
	if not _check(not paused and current_scene == dating and not pause_owner.surface.visible
		and saved_continued == hosted and _reading_pause_observation(game) == hosted
		and saves.get("_storage").read_text("slot_3.json").value == disk.value,
		"Continue after Save retains the same full line without speech, History, game, Profile or slot mutation"): return false
	_record_reading_pause("ordinary_pause_save_continued", saved_continued)
	return true


func _reading_pause_observation(game: Node) -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	var layer: Node = _caption_layer()
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	var history: Dictionary = bridge.get_reading_history()
	if not _check(layer != null and checkpoint.get("ok", false) and history.get("ok", false),
		"pure reading Pause observation is admitted"): return {}
	var text: DialogicNode_DialogText = layer.caption_text
	return {"native": {"line_id": runtime.current_line_id(), "caption_id": text.get_instance_id(),
		"reveal_generation": text.get_reveal_generation(), "text": text.get_parsed_text(),
		"visible_characters": text.visible_characters, "total_characters": text.get_total_character_count(),
		"revealing": text.revealing},
		"source": {"checkpoint": checkpoint.value.duplicate(true), "history": history.value.duplicate(true),
			"live_session": game.capture_live_session().value.duplicate(true), "gameplay": game.to_save_dict().duplicate(true),
			"physical_record": game.capture_dating_challenge_state().value.duplicate(true),
			"profile": root.get_node("ProfileManager").get_profile_snapshot(), "speech_admissions": _speech_admissions}}


func _record_reading_pause(kind: String, observation: Dictionary) -> void:
	_pause_save_proof[kind] = observation.duplicate(true)
	_trace(kind, observation)


func _cancel_reading_quick_load(game: Node, dating: Node, checkpoint: Dictionary, quick_text: String) -> bool:
	var source: Dictionary = game.capture_live_session().value.duplicate(true)
	var gameplay: Dictionary = game.to_save_dict().duplicate(true)
	var speech_before: int = _speech_admissions
	await _dating_quick_key(KEY_F9)
	var pause_owner: Node = root.get_node("SceneRouter").get("_production_pause")
	var sheet: Control = pause_owner.surface.get("_host_confirmation")
	if not _check(is_instance_valid(sheet) and sheet.cancel_button.has_focus(),
		"reading F9 enters real retained Cancel-first Quick consent"): return false
	if not _check(game.capture_live_session().value == source and game.to_save_dict() == gameplay,
		"reading Quick consent performs no early restoration"): return false
	if not await _ordinary_accept_focused(sheet.cancel_button, "reading Quick Load Cancel"): return false
	for frame: int in 120:
		if not paused and not pause_owner.surface.is_visible_in_tree(): break
		await process_frame
	var bridge: Node = root.get_node("DialogicBridge")
	var current: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(not paused and current_scene == dating and current.get("ok", false)
		and current.value == checkpoint and game.capture_live_session().value == source
		and game.to_save_dict() == gameplay and _speech_admissions == speech_before
		and root.get_node("SaveManager").get("_storage").read_text("quicksave.json").value == quick_text,
		"reading F9 Cancel resumes exact source without changed bytes, gameplay or speech"): return false
	_trace("reading_quick_load_cancelled", {"checkpoint": current.value})
	return true


func _inspect_history(label: String, expected_count: int) -> bool:
	var bridge: Node = root.get_node("DialogicBridge")
	var history: Dictionary = bridge.get_reading_history()
	if not _check(history.get("ok", false) and history.value.captions.size() == expected_count, "complete History is available"): return false
	var texts: Array[String] = []
	for index: int in history.value.captions.size():
		var row: Dictionary = history.value.captions[index]
		if not _check(row.line_id == EXPECTED_LINES[index], "History preserves exact canonical occurrence order"): return false
		texts.append(row.text)
	var layer: Node = _caption_layer()
	if not _check(layer != null, "real Witnessed caption layer exists"): return false
	var game: Node = root.get_node("GameState")
	var profile: Node = root.get_node("ProfileManager")
	var gameplay: Dictionary = game.to_save_dict().duplicate(true)
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var speech_before: int = _speech_admissions
	var history_button: Button = layer.transport_rail.get_node("History")
	history_button.grab_focus()
	if not await _ordinary_accept_focused(history_button, "real History rail activation"): return false
	for frame: int in 120:
		if bool(layer.get("_history_open")): break
		await process_frame
	if not _check(bool(layer.get("_history_open")), "History opens through actual suspension owner"): return false
	var overlay: Node = layer.get("_history_overlay")
	if not _check(overlay.get_captions() == texts and overlay.is_ancestor_of(root.gui_get_focus_owner()),
		"History projects canonical captions and owns focus"): return false
	await _capture_screen(label)
	if not _check(game.to_save_dict() == gameplay and profile.get_profile_snapshot() == profile_before
		and bridge.get_reading_history().value == history.value and _speech_admissions == speech_before,
		"History inspection changes no game/Profile/ledger and repeats no speech"): return false
	var close: Button = overlay.close_button
	close.grab_focus()
	if not await _ordinary_accept_focused(close, "actual History close"): return false
	for frame: int in 120:
		if not bool(layer.get("_history_open")) and not bool(layer.get("_history_pending")): break
		await process_frame
	if not _check(not bool(layer.get("_history_open")) and root.gui_get_focus_owner() == history_button,
		"closing History restores exact rail focus"): return false
	if not _check(game.to_save_dict() == gameplay and profile.get_profile_snapshot() == profile_before
		and bridge.get_reading_history().value == history.value and _speech_admissions == speech_before,
		"History return preserves exact source without advancement"): return false
	_history_observations += 1
	_trace("history_inspected", {"label": label, "history": history.value})
	return true


func _caption_layer() -> Node:
	var dialogic: Node = root.get_node("Dialogic")
	var layout: Node = dialogic.Styles.get_layout_node()
	return layout.find_child("WitnessedCaptionLayer", true, false) if is_instance_valid(layout) else null


func _wait_line(line_id: String) -> bool:
	var bridge: Node = root.get_node("DialogicBridge")
	for frame: int in 360:
		var runtime: Variant = bridge.get("_runtime_adapter")
		if runtime != null and runtime.current_line_id() == line_id:
			await _frames()
			return true
		await process_frame
	return _check(false, "native authored line did not arrive: " + line_id + " / " + JSON.stringify(bridge.get_state()))


func _advance_line(line_id: String, successor: String) -> bool:
	var bridge: Node = root.get_node("DialogicBridge")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	if not _check(runtime.current_line_id() == line_id, "advance starts at exact authored line " + line_id): return false
	if not _check(runtime.reveal_current_line(true).get("ok", false), "finish real native reveal"): return false
	await _frames()
	if not _check(runtime.advance_one_event().get("ok", false), "advance the actual native text coroutine"): return false
	if not successor.is_empty(): return await _wait_line(successor)
	await _frames()
	return true


func _capture_screen(label: String) -> bool:
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), "rendered screen available"): return false
	var path: String = _evidence_path(label + ".png")
	if not _check(pixels.save_png(path) == OK, "write cloud screenshot " + label): return false
	print("READING_RAIL_CAPTURE: " + path)
	return true


func _evidence_path(name: String) -> String:
	var folder: String = ProjectSettings.globalize_path("user://evidence/reading-rail")
	DirAccess.make_dir_recursive_absolute(folder)
	return folder.path_join(name)


func _write_text(name: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(_evidence_path(name), FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.close()
	return true


func _trace(kind: String, value: Dictionary) -> void:
	_trace_sequence += 1
	var path: String = _evidence_path("transactions.jsonl")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		_check(false, "transaction evidence cannot be opened")
		return
	file.seek_end()
	file.store_line(JSON.stringify({"mode": _reading_mode, "sequence": _trace_sequence,
		"process_id": OS.get_process_id(), "kind": kind, "value": value}))
	file.close()


func _check(value: bool, detail: String) -> bool:
	if not value:
		printerr("READING_RAIL_FAIL: " + detail)
		quit(1)
	return value
