extends "res://tests/integration/verify_reading_rail_journey.gd"
## Connected, explicitly injected noncanonical Hospital proof. Real owners alone
## admit Contacts, commit Schedule, restore, complete Hospital and advance the day.
const HOSPITAL_LOCATOR := preload("res://tests/support/HospitalReadingTimelineCatalog.gd")
const HOSPITAL_FIXTURE := preload("res://tests/support/HospitalReadingFixture.gd")
const FROZEN_RUN := preload("res://scripts/narrative/FrozenRunContext.gd")
const HOSPITAL_ENTRY := "hospital.faint.day3"
const NEXT_CATALOGUE := "res://tests/fixtures/dialogic/hospital_next_solo_catalogue.json"
var _hospital_stages: Dictionary = {}
var _hospital_completions: Array = []
var _physical_completions: Array = []
var _text_starts: Array = []
var _catalogue_documents: Dictionary = {}

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hospital-reading-mode="):
			_reading_mode = argument.trim_prefix("--hospital-reading-mode=")
	if not _check(_reading_mode in ["write", "read", "forge"], "explicit Hospital mode"): return
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty()
		and DisplayServer.get_name() != "headless", "isolated real cloud rendering required"): return
	print("HOSPITAL_READING_PROCESS: " + JSON.stringify({"mode": _reading_mode,
		"process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://")}))
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	if not _check(bootstrap.get_startup_state().get("ready", false), "production startup ready"): return
	var bridge: Node = root.get_node("DialogicBridge")
	if not _check(bridge.initialize(HOSPITAL_LOCATOR).get("ok", false), "explicit noncanonical locator injection"): return
	var solo_path := READING_CATALOGUE if _reading_mode == "write" else NEXT_CATALOGUE
	var solo: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(solo_path))
	var hospital := HOSPITAL_FIXTURE.catalogue(3)
	if not _check(solo.get("ok", false) and bridge.configure_reading_catalogue(solo.value).get("ok", false)
		and bridge.configure_reading_catalogue(hospital).get("ok", false), "independent immutable family catalogues"): return
	_catalogue_documents = {"solo": solo.value, "hospital": hospital, "production_content": false}
	if not _check(_write_text(_reading_mode + "-catalogues.json", JSON.stringify(_catalogue_documents, "\t")), "retain exact process catalogue documents"): return
	bridge.hospital_reading_finished.connect(func(command: Dictionary, result: Dictionary) -> void:
		_hospital_completions.append({"command": command.duplicate(true), "result": result.duplicate(true)}))
	var physical: Object = bootstrap.get("_retained_presentation_owner_adapter")
	physical.physical_completion_ready.connect(func(receipt: Dictionary) -> void:
		_physical_completions.append(receipt.duplicate(true)))
	root.get_node("Dialogic").Text.text_started.connect(func(info: Dictionary) -> void:
		_text_starts.append({"text": str(info.get("text", "")), "frame": Engine.get_process_frames()}))
	var speech: Node = root.get_node("SystemTtsCoordinator")
	speech.speech_admitted.connect(func(_token: int, _source: String) -> void: _speech_admissions += 1)
	var capability: Dictionary = speech.refresh_capability("en")
	if not _check(capability.get("ok", false) and capability.value.get("available", false), "native speech available"): return
	if _reading_mode == "forge":
		await _hospital_forge()
		return
	if _reading_mode == "read":
		await _hospital_read()
		return
	var preferences: Dictionary = root.get_node("ProfileManager").set_preferences({
		&"preferences.reading.read_aloud_enabled": true, &"preferences.reading.reveal_speed": "slow",
		&"preferences.reading.auto_enabled": false})
	if not _check(preferences.get("ok", false), "real slow non-auto reading preferences"): return
	await _hospital_write()

func _hospital_write() -> void:
	var game: Node = root.get_node("GameState")
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	current_scene.get_node("%NewAccButton").pressed.emit()
	if not await _wait_desktop(1): return
	if not await _unlock_invitation("priscilla", 1): return
	if not await _schedule_friend("priscilla", 1): return
	if not await _wait_line("fixture.solo.pre.a"): return
	var prior := _observe()
	_stage("prior_solo", prior)
	if not _check(prior.source.history.captions.size() == 1, "prior Solo is observed while alive"): return
	if not await _advance_line("fixture.solo.pre.a", "fixture.solo.pre.b"): return
	if not await _advance_line("fixture.solo.pre.b", ""): return
	var dating: Node = current_scene
	if not await _wait_for_dating_board(dating): return
	dating.worksheet.cell_action_requested.emit(&"reveal", 0, int(dating.get("_physical_view").board.revision))
	var record: Dictionary = game.capture_dating_challenge_state().value
	if not record.board.terminal:
		dating.worksheet.cell_action_requested.emit(&"reveal", int(record.board.mine_indices[0]), int(dating.get("_physical_view").board.revision))
	if not await _wait_line("fixture.solo.post.a"): return
	if not await _advance_line("fixture.solo.post.a", "fixture.solo.post.b"): return
	if not await _advance_line("fixture.solo.post.b", ""): return
	if not await _wait_desktop(2): return
	var bridge: Node = root.get_node("DialogicBridge")
	_stage("prior_retired", {"day": game.day, "history": bridge.get_reading_history(),
		"lifecycle": game._run_lifecycle.to_dict(), "contacts": game.contacts.duplicate(true)})
	if not _check(not bridge.get_reading_history().get("ok", false)
		and game.contacts.solo_actions["solo:priscilla:day1"].state == "RESOLVED_ATTENDED",
		"prior Solo retires only after native completion and canonical settlement"): return
	# The empty Day-2 Schedule is lawful public progression. No group source is
	# opened or suppressed; the coordinator owns any canonical required work.
	if not await _schedule_done(): return
	if not await _wait_desktop(3): return
	if not await _unlock_invitation("sylvia", 3): return
	if not await _schedule_friend("sylvia", 3): return
	if not await _wait_line("fixture.hospital.a"): return
	var first := _observe()
	var state_port: Object = root.get_node("ApplicationBootstrap").get("_retained_day_resolution_state_port")
	first["deferred_pair_preview"] = state_port._deferred_pair_preview()
	_stage("hospital_a", first)
	if not _check(first.source.history.captions.size() == 1
		and first.source.history.captions[0].line_id == "fixture.hospital.a"
		and first.source.history.session_id != prior.source.history.session_id
		and first.source.command.context.presentation.fields.sylvia_eligible
		and first.source.command.context.presentation.fields.sylvia_witness_receipt_id == null
		and first.deferred_pair_preview.get("ok", false)
		and first.deferred_pair_preview.value.required == false,
		"new Hospital session publishes only A with receipt-proven Sylvia and no deferred pair"): return
	if not _check(bridge.get("_runtime_adapter").reveal_current_line(true).get("ok", false), "arrange completed Hospital A"): return
	var transport := await _hospital_advance_and_pause()
	var entered := _observe()
	entered["transport"] = transport
	_stage("paused_b", entered)
	if not _check(paused and entered.native.line_id == "fixture.hospital.b" and entered.native.revealing
		and entered.native.visible_characters < entered.native.total_characters
		and entered.source.history.captions.size() == 2, "plain Pause retains literal partial B and only actual A/B"): return
	if not await _hospital_pause_save(): return
	var disk: Dictionary = root.get_node("SaveManager").get("_storage").read_text("slot_3.json")
	var report := _base_report()
	report["saved_checkpoint"] = _hospital_stages.saved.source.checkpoint
	report["hospital_command"] = _hospital_stages.saved.source.command
	report["slot_sha256"] = str(disk.value).sha256_text()
	report["slot_bytes"] = str(disk.value).to_utf8_buffer().size()
	if not _check(_write_text("write.json", JSON.stringify(report, "\t")), "retain Hospital writer report"): return
	print("HOSPITAL_READING_WRITE_PASS: real prior Solo -> lawful retirement -> Schedule-Done Sylvia Hospital -> partial B -> Pause/History/Cancel -> explicit Save")
	await _finish_proof()

func _wait_desktop(day: int) -> bool:
	var game: Node = root.get_node("GameState")
	for frame: int in 1800:
		if game.day == day and current_scene != null and current_scene.find_child("ComputerDesktop", true, false) != null \
			and not bool(root.get_node("SaveManager").get("_new_run_busy")):
			await _frames()
			return true
		await process_frame
	return _check(false, "canonical desktop day did not arrive: " + str(day))

func _desktop() -> Node:
	return current_scene.find_child("ComputerDesktop", true, false)

func _unlock_invitation(friend: String, day: int) -> bool:
	var game: Node = root.get_node("GameState")
	var invitation := "solo:%s:day%d" % [friend, day]
	for round_index: int in 2:
		if game.contacts.solo_actions.has(invitation): break
		var desktop := _desktop()
		if not _check(desktop.open_app(&"minesweeper").get("ok", false), "real invitation-unlock board opens"): return false
		await _frames()
		var app: Node = desktop.get("_cached_app_windows")[&"minesweeper"]
		var panel: Control = app.panel
		if panel.public_view.settled: panel.dock.action_requested.emit(&"new_board")
		var before: int = game.minesweeper_app_rounds_finished_today
		panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
		var physical: Dictionary = root.get_node("ApplicationBootstrap").get("_desktop_board_state").capture().board.board
		if not panel.public_view.board.terminal:
			panel.worksheet.cell_action_requested.emit(&"reveal", int(physical.mine_indices[0]), int(panel.public_view.board.revision))
		if not await _wait_app_round_settled(game, app, before): return false
		if not _check(desktop.return_home().get("ok", false), "Home after actual invitation round"): return false
	return _check(game.contacts.solo_actions.has(invitation), "calendar-owned invitation exists: " + invitation)

func _schedule_friend(friend: String, day: int) -> bool:
	var desktop := _desktop()
	var game: Node = root.get_node("GameState")
	var invitation := "solo:%s:day%d" % [friend, day]
	if not _check(desktop.open_app(&"contacts").get("ok", false), "real Contacts opens"): return false
	await _frames()
	var contacts: Node = desktop.get("_cached_app_windows")[&"contacts"]
	contacts.contacts_panel.open_requested.emit(friend)
	if not _check(contacts.last_result.get("ok", false) and game.contacts.solo_actions[invitation].state == "ACCEPTED", "read accepts calendar-owned invitation"): return false
	if not _check(desktop.return_home().get("ok", false) and desktop.open_app(&"schedule").get("ok", false), "real Schedule opens"): return false
	await _frames()
	var schedule: Node = desktop.get("_cached_app_windows")[&"schedule"]
	schedule.panel.source_requested.emit(invitation)
	if not _check(schedule.last_result.get("ok", false), "accepted Contacts source enters Schedule"): return false
	if friend == "sylvia" and day == 3:
		# Explicit condition fixture immediately before Schedule Done, matching the
		# existing rendered ingress. Contacts and Schedule already own their receipts.
		game.set_stat("health", 0)
		game.set_stat("pressure", 10)
		game.condition_effects_today.assign(["sequela"])
	return await _schedule_done()

func _schedule_done() -> bool:
	var desktop := _desktop()
	if not _check(desktop.open_app(&"schedule").get("ok", false), "Schedule ready for Done"): return false
	await _frames()
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "real Schedule Done: " + str(done)): return false
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: return true
		if not _check(ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss").get("ok", false), "real Schedule warning dismissal"): return false
	return _check(false, "Schedule warning budget exceeded")

func _observe() -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var game: Node = root.get_node("GameState")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	var history: Dictionary = bridge.get_reading_history()
	var layer: Node = _caption_layer()
	if not _check(checkpoint.get("ok", false) and history.get("ok", false) and layer != null, "pure live reading observation admitted"): return {}
	var text: DialogicNode_DialogText = layer.caption_text
	var command := {}
	if current_scene.has_method("get_presentation_projection"): command = current_scene.get_presentation_projection()
	return {"native": {"line_id": checkpoint.value.reading_session.frontier.get("line_id", ""),
		"caption_id": text.get_instance_id(), "reveal_generation": text.get_reveal_generation(),
		"text": text.get_parsed_text(), "visible_characters": text.visible_characters,
		"total_characters": text.get_total_character_count(), "visible_ratio": text.visible_ratio, "revealing": text.revealing},
		"source": {"checkpoint": checkpoint.value, "history": history.value, "command": command,
			"live_session": game.capture_live_session().value, "gameplay": game.to_save_dict(),
			"lifecycle": game._run_lifecycle.to_dict(), "contacts": game.contacts.duplicate(true),
			"profile": root.get_node("ProfileManager").get_profile_snapshot(), "speech_admissions": _speech_admissions,
			"hospital_completions": _hospital_completions.duplicate(true), "physical_completions": _physical_completions.duplicate(true)}}

func _stage(name: String, value: Dictionary) -> void:
	var retained := value.duplicate(true)
	retained["ui"] = _ui_observation()
	_hospital_stages[name] = retained
	_check(_write_text(_reading_mode + "-" + name + ".json", JSON.stringify(retained, "\t")), "retain Hospital stage " + name)
	_trace(name, retained)

func _ui_observation() -> Dictionary:
	var pause: Node = root.get_node("SceneRouter").get("_production_pause")
	var bridge: Node = root.get_node("DialogicBridge")
	var layer: Node = _caption_layer()
	var focus: Control = root.gui_get_focus_owner()
	var overlay: Variant = layer.get("_history_overlay") if layer != null else null
	var button: Node = layer.transport_rail.get_node("History") if layer != null else null
	return {"tree_paused": paused, "focus_owner": str(focus.get_path()) if is_instance_valid(focus) else "",
		"pause_visible": pause.surface.is_visible_in_tree(), "pause_entered_action": str(pause.surface.entered_action),
		"history_open": bool(layer.get("_history_open")) if layer != null else false,
		"history_focus": is_instance_valid(overlay) and is_instance_valid(focus) and overlay.is_ancestor_of(focus),
		"history_button_focus": is_instance_valid(button) and focus == button,
		"bridge_suspension": bridge.get_state(), "bridge_pause_handle": bridge.get("_pause_handle").duplicate(true)}

func _base_report() -> Dictionary:
	return {"schema_version": 1, "mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "catalogues": _catalogue_documents.duplicate(true),
		"fixture": {"production_content": false, "condition": {"health": 0, "pressure": 10, "condition_effects_today": ["sequela"]},
			"condition_injection": "after real day3 Sylvia Contacts acceptance and Schedule placement, immediately before Done",
			"days": {"prior_solo": 1, "empty_schedule": 2, "hospital": 3, "next_solo": 4},
			"forgery_scope": "one shared Hospital frame: coherent current/ledger forgery and foreign earlier caption; not an earlier-only-frame forgery"},
		"stages": _hospital_stages.duplicate(true), "text_starts": _text_starts.duplicate(true),
		"speech_admissions": _speech_admissions, "hospital_completions": _hospital_completions.duplicate(true),
		"physical_completions": _physical_completions.duplicate(true)}

func _hospital_pause_save() -> bool:
	var pause: Node = root.get_node("SceneRouter").get("_production_pause")
	var saves: Node = root.get_node("SaveManager")
	var initial := _observe()
	pause.surface.rows[&"return"].grab_focus()
	if not await _ordinary_accept_focused(pause.surface.rows[&"return"], "Hospital Return confirmation"): return false
	if not _check(pause.surface.cancel_button.has_focus(), "Cancel-first confirmation"): return false
	if not await _ordinary_accept_focused(pause.surface.cancel_button, "Hospital Return Cancel"): return false
	_stage("pause_cancelled", _observe())
	if not _check(_observe() == initial and paused, "Cancel preserves exact partial native and canonical source"): return false
	var capability: Dictionary = saves.get_backup_save_capability()
	var source: Dictionary = pause.capture_pause_source()
	_stage("availability", {"capability": capability, "pause_source": source, "observation": _observe()})
	if not _check(_observe() == initial and source.get("ok", false), "availability queries are pure on partial Hospital"): return false
	var released := {}
	pause.coordinator.pause_closed.connect(func() -> void: released.merge(_observe(), true), CONNECT_ONE_SHOT)
	pause.surface.rows[&"continue"].grab_focus()
	if not await _ordinary_accept_focused(pause.surface.rows[&"continue"], "Hospital partial Continue"): return false
	if not _check(released == initial and not paused, "Continue releases the exact suspended partial source"): return false
	_stage("pause_continued", released)
	if not await _hospital_history("hospital-partial-history", ["fixture.hospital.a", "fixture.hospital.b"]): return false
	await _pause_key()
	var reentered := _observe()
	_stage("pause_reentered", reentered)
	if not _check(paused and reentered.native.revealing and reentered.source == initial.source, "Hospital B stays partial before explicit Backup"): return false
	pause.surface.rows[&"backup"].grab_focus()
	await _frames()
	if not _check(_observe() == reentered, "Backup focus preview remains pure"): return false
	if not await _ordinary_accept_focused(pause.surface.rows[&"backup"], "Hospital explicit Backup entry"): return false
	var backup: Control = pause.surface.get("_hosts")[&"backup"]
	var hosted := _observe()
	_stage("backup_entered", hosted)
	if not _check(not hosted.native.revealing and hosted.native.visible_ratio == 1.0
		and hosted.native.line_id == "fixture.hospital.b" and hosted.source == initial.source,
		"explicit Backup completes B only without publication/completion/witness/route changes"): return false
	backup.drawer_buttons["slot:3"].grab_focus()
	if not await _ordinary_accept_focused(backup.drawer_buttons["slot:3"], "Hospital manual slot selection"): return false
	backup.action_buttons["save"].grab_focus()
	if not await _ordinary_accept_focused(backup.action_buttons["save"], "Hospital manual Save"): return false
	if not _check(backup.last_result.get("ok", false) and backup.get("_status_key") == "saved", "Hospital manual Save committed"): return false
	var disk: Dictionary = saves.get("_storage").read_text("slot_3.json")
	if not _check(disk.get("ok", false) and _write_text("saved-hospital-slot.json", disk.value), "retain original physical Hospital Save bytes"): return false
	var document: Dictionary = STRICT.parse_object(disk.value)
	var admitted: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(document.value)
	if not _check(admitted.get("ok", false), "actual Save schema admits Hospital bytes"): return false
	var snapshot: Dictionary = admitted.value.candidate.current_snapshot.snapshot
	var saved := _observe()
	_stage("saved", saved)
	if not _check(saved == hosted and snapshot.narrative_checkpoint == saved.source.checkpoint
		and snapshot.narrative_checkpoint.reading_session.ledger.captions.size() == 2,
		"manual Save records exact Hospital A/B ledger and stable B"): return false
	await _capture_screen("hospital-saved")
	await _pause_key()
	pause.surface.rows[&"continue"].grab_focus()
	return await _ordinary_accept_focused(pause.surface.rows[&"continue"], "Hospital saved Continue")

func _hospital_history(label: String, expected_ids: Array) -> bool:
	var layer: Node = _caption_layer()
	var button: Button = layer.transport_rail.get_node("History")
	button.grab_focus()
	if not await _ordinary_accept_focused(button, "Hospital History open"): return false
	for frame: int in 120:
		if layer.get("_history_open"): break
		await process_frame
	var entered := _observe()
	var overlay: Node = layer.get("_history_overlay")
	var ids: Array = []
	var texts: Array[String] = []
	for row: Dictionary in entered.source.history.captions:
		ids.append(row.line_id)
		texts.append(row.text)
	_stage(label + "-entered", entered)
	if not _check(paused and layer.get("_history_open") and ids == expected_ids
		and overlay.get_captions() == texts and overlay.is_ancestor_of(root.gui_get_focus_owner()), "History projects only actual ordered captions and owns focus"): return false
	await _capture_screen(label)
	var released := {}
	root.get_node("SceneRouter").get("_production_pause").coordinator.pause_closed.connect(
		func() -> void: released.merge(_observe(), true), CONNECT_ONE_SHOT)
	overlay.close_button.grab_focus()
	if not await _ordinary_accept_focused(overlay.close_button, "Hospital History Close"): return false
	for frame: int in 120:
		if not layer.get("_history_open") and not layer.get("_history_pending"): break
		await process_frame
	_stage(label + "-closed", released)
	return _check(not paused and released == entered and root.gui_get_focus_owner() == button,
		"History returns literal reveal/source/ledger and original rail focus")

func _hospital_read() -> void:
	var expected: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("write.json")))
	if not _check(expected.get("ok", false) and int(expected.value.process_id) != OS.get_process_id(), "fresh process reads writer proof"): return
	var saves: Node = root.get_node("SaveManager")
	var profile_before: Dictionary = root.get_node("ProfileManager").get_profile_snapshot()
	if not _check(root.get_node("ProfileManager").get_preference(&"preferences.reading.read_aloud_enabled", false),
		"fresh process retains enabled read-aloud control"): return
	var initial_texts := _text_starts.size()
	var prepared: Dictionary = saves.prepare_backup_action("load", "slot:3")
	if not _check(prepared.get("ok", false), "real Hospital manual Load prepares: " + str(prepared)): return
	var restored: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(restored.get("ok", false), "real Hospital coordinated Load commits: " + str(restored)): return
	if not await _wait_line("fixture.hospital.b"): return
	var loaded := _observe()
	loaded["text_starts_during_restore"] = _text_starts.slice(initial_texts)
	_stage("loaded", loaded)
	if not _check(loaded.source.checkpoint.reading_session == expected.value.saved_checkpoint.reading_session
		and loaded.source.command == expected.value.hospital_command and not loaded.native.revealing
		and loaded.native.visible_ratio == 1.0 and loaded.source.profile == profile_before
		and _speech_admissions == 0 and _hospital_completions.is_empty() and _physical_completions.is_empty(),
		"fresh Load adopts exact Hospital command/token/B/History with no repeated speech or completion"): return
	for started: Dictionary in loaded.text_starts_during_restore:
		if not _check(started.text != HOSPITAL_FIXTURE.catalogue(3).entries[0].lines[0].text, "Load never starts A before seeking B"): return
	if not await _hospital_history("hospital-restored-history", ["fixture.hospital.a", "fixture.hospital.b"]): return
	await _capture_screen("hospital-restored")
	# Only this ordinary caption key completes the native Hospital coroutine.
	var completion_input := await _hospital_complete_input()
	_stage("completion_input", completion_input)
	if not _check(completion_input.admitted and completion_input.source_line == "fixture.hospital.b"
		and completion_input.contacts_after.is_empty(), "fresh ordinary input completes the actual Hospital caption"): return
	if not await _wait_desktop(4): return
	var game: Node = root.get_node("GameState")
	var bridge: Node = root.get_node("DialogicBridge")
	var autosave: Dictionary = saves.get("_storage").read_text("autosave.json")
	if not _check(autosave.get("ok", false) and _write_text("settled-hospital-autosave.json", autosave.value), "retain actual post-Hospital durable Autosave"): return
	var parsed_auto: Dictionary = STRICT.parse_object(autosave.value)
	var auto_schema: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(parsed_auto.value)
	if not _check(auto_schema.get("ok", false), "post-Hospital Autosave admitted"): return
	var durable: Dictionary = auto_schema.value.candidate.current_snapshot.snapshot
	var settled := {"day": game.day, "gameplay": game.to_save_dict(), "lifecycle": game._run_lifecycle.to_dict(),
		"contacts": game.contacts.duplicate(true), "history": bridge.get_reading_history(),
		"hospital_completions": _hospital_completions.duplicate(true), "physical_completions": _physical_completions.duplicate(true),
		"autosave_sha256": str(autosave.value).sha256_text(), "autosave_bytes": str(autosave.value).to_utf8_buffer().size(),
		"durable_snapshot": durable.duplicate(true)}
	_stage("settled", settled)
	if not _check(_hospital_completions.size() == 1 and _physical_completions.size() == 1
		and not settled.history.get("ok", false) and game.get_stat("health") == 6
		and game.get_stat("pressure") == 3 and not game.pending_hospital
		and game.contacts.solo_actions["solo:sylvia:day3"].state == "RESOLVED_MISSED"
		and game.contacts.sylvia_hospital_witness_receipts.size() == 1
		and durable.lifecycle.day == 4 and durable.contacts == game.contacts,
		"one native Hospital completion settles durably and retires its session on next-day desktop"): return
	if not await _unlock_invitation("priscilla", 4): return
	if not await _schedule_friend("priscilla", 4): return
	if not await _wait_line("fixture.next.solo.pre.a"): return
	var next := _observe()
	_stage("next_solo", next)
	if not _check(next.source.history.session_id != loaded.source.history.session_id
		and next.source.history.captions.size() == 1
		and next.source.history.captions[0].line_id == "fixture.next.solo.pre.a", "next canonical Solo starts fresh with no Hospital rows"): return
	if not await _hospital_history("next-solo-history", ["fixture.next.solo.pre.a"]): return
	var report := _base_report()
	report["writer_process_id"] = expected.value.process_id
	report["saved_checkpoint"] = loaded.source.checkpoint
	report["hospital_command"] = loaded.source.command
	if not _check(_write_text("read.json", JSON.stringify(report, "\t")), "retain Hospital reader report"): return
	print("HOSPITAL_READING_READ_PASS: fresh real Load -> exact saved B/no A replay -> native ordinary input completion -> durable next day -> fresh Solo History")
	await _finish_proof()

func _hospital_forge() -> void:
	var document: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("saved-hospital-slot.json")))
	var admitted: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(document.value)
	if not _check(admitted.get("ok", false), "original retained Hospital bytes validate before forgery"): return
	var original: Dictionary = admitted.value.candidate.current_snapshot.snapshot
	var participant: Object = root.get_node("SaveManager").get("_restore_participants")["narrative"]
	var bridge: Node = root.get_node("DialogicBridge")
	var genuine: Dictionary = participant.prepare({"content_version": 1,
		"narrative_checkpoint": original.narrative_checkpoint, "snapshot": original})
	if not _check(genuine.get("ok", false), "real participant admits original Hospital snapshot without installation"): return
	var cases := {}
	for kind: String in ["frame", "caption"]:
		var candidate := original.duplicate(true)
		var checkpoint: Dictionary = candidate.narrative_checkpoint
		if kind == "frame":
			# Coherent current+ledger-frame forgery. The one Hospital frame is shared
			# by A and B; this is NOT an earlier-only-frame claim.
			checkpoint.frozen_context.presentation.fields.sylvia_eligible = false
			checkpoint.reading_session.ledger.entry_contexts[HOSPITAL_ENTRY] = checkpoint.frozen_context.duplicate(true)
		else:
			checkpoint.reading_session.ledger.captions[0].beat.owning_entry_id = "hospital.faint.day4"
		var before := _idle_observation()
		var independent: Dictionary = FROZEN_RUN.validate_reading_checkpoint(checkpoint, candidate)
		var refused: Dictionary = participant.prepare({"content_version": 1, "narrative_checkpoint": checkpoint, "snapshot": candidate})
		var after := _idle_observation()
		if not _check(_write_text("forge-" + kind + "-candidate.json", JSON.stringify(candidate, "\t")), "retain exact forged candidate"): return
		cases[kind] = {"independent": independent, "admission": refused, "before": before, "after": after}
		_stage("forge-" + kind, cases[kind])
		if not _check(not independent.get("ok", false) and not refused.get("ok", false)
			and refused.get("code") == &"invalid_narrative_checkpoint" and before == after
			and not bridge.has_active_playback(), "forgery refuses before publication, staging or installation"): return
	var report := _base_report()
	report["genuine_admission"] = {"ok": genuine.get("ok", false)}
	report["cases"] = cases
	if not _check(_write_text("forge.json", JSON.stringify(report, "\t")), "retain Hospital forgery report"): return
	print("HOSPITAL_READING_FORGE_PASS: unchanged saved Run authority refuses coherent Hospital frame and foreign earlier caption before installation")
	root.get_node("SystemTtsCoordinator").stop(&"hospital_fixture_teardown")
	await root.get_node("SystemTtsCoordinator").wait_until_recovered()
	await _frames()
	quit(0)

func _idle_observation() -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var game: Node = root.get_node("GameState")
	var captured: Dictionary = bridge.capture_restore_state()
	# Object identity remains an observation, not JSON's lossy object stringification.
	var owner: Variant = captured.value.backup.reading_owner
	captured.value.backup.reading_owner = owner.get_instance_id() if owner != null else null
	return {"bridge": captured, "gameplay": game.to_save_dict(),
		"lifecycle": game._run_lifecycle.to_dict(), "contacts": game.contacts.duplicate(true),
		"route_id": str(root.get_node("SceneRouter").get_current_route_id()),
		"profile": root.get_node("ProfileManager").get_profile_snapshot(),
		"live_session": game.capture_live_session(), "text_starts": _text_starts.duplicate(true),
		"speech_admissions": _speech_admissions, "hospital_completions": _hospital_completions.duplicate(true),
		"physical_completions": _physical_completions.duplicate(true)}

func _evidence_path(name: String) -> String:
	var folder := ProjectSettings.globalize_path("user://evidence/hospital-reading")
	DirAccess.make_dir_recursive_absolute(folder)
	return folder.path_join(name)

func _check(value: bool, detail: String) -> bool:
	if not value:
		printerr("HOSPITAL_READING_FAIL: " + detail)
		quit(1)
	return value

func _hospital_complete_input() -> Dictionary:
	var layer: Node = _caption_layer()
	var input: Node = root.get_node("InputManager")
	var runtime: RefCounted = root.get_node("DialogicBridge").get("_runtime_adapter")
	current_scene.get_window().grab_focus()
	layer.caption_text.grab_focus()
	for frame: int in 120:
		if layer.caption_text.has_focus() and layer.accept_input.is_source_admitted() \
			and input.get_physical_contacts().is_empty() and not Input.is_action_pressed(&"ui_accept"): break
		await process_frame
	var result := {"packet_type": "InputEventKey", "source_line": runtime.current_line_id(),
		"admitted": layer.caption_text.has_focus() and layer.accept_input.is_source_admitted()
			and input.get_physical_contacts().is_empty() and not Input.is_action_pressed(&"ui_accept"), "events": []}
	if result.admitted:
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			result.events.append({"key": "Enter", "pressed": pressed, "frame": Engine.get_process_frames(),
				"contacts": input.get_physical_contacts()})
			await process_frame
	result["contacts_after"] = input.get_physical_contacts()
	_check(_write_text("hospital-completion-input.json", JSON.stringify(result, "\t")), "retain ordinary Hospital completion input")
	return result


func _hospital_advance_and_pause() -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var input_owner: Node = root.get_node("InputManager")
	var pause_owner: Node = root.get_node("SceneRouter").get("_production_pause")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	var layer: Node = _caption_layer()
	var observation := {"packet_type": "InputEventKey", "events": [], "back_admitted": false}
	current_scene.get_window().grab_focus()
	layer.caption_text.grab_focus()
	# Focus and input custody may settle on a deferred frame. The arranged A line is
	# already complete, so waiting here cannot consume B's short reveal interval.
	await process_frame
	for frame: int in 120:
		if layer.caption_text.has_focus() and layer.accept_input.is_source_admitted() \
				and input_owner.get_physical_contacts().is_empty() \
				and not Input.is_action_pressed(&"ui_accept"): break
		await process_frame
	observation["accept_admitted"] = layer.caption_text.has_focus() and layer.accept_input.is_source_admitted() \
		and input_owner.get_physical_contacts().is_empty() and not Input.is_action_pressed(&"ui_accept")
	observation["source_line"] = str(runtime.current_line_id())
	if observation.accept_admitted and observation.source_line == "fixture.hospital.a":
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			observation.events.append({"key": "Enter", "pressed": pressed,
				"frame": Engine.get_process_frames(), "contacts": input_owner.get_physical_contacts()})
			# In particular, the release is followed by a neutral process frame
			# before Escape is eligible. No generic twelve-frame delay follows it.
			await process_frame
		for frame: int in 120:
			var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
			var frontier: Dictionary = checkpoint.get("value", {}).get("reading_session", {}).get("frontier", {})
			if str(frontier.get("line_id", "")) == "fixture.hospital.b" \
					and input_owner.is_source_input_admitted() and input_owner.get_physical_contacts().is_empty() \
					and not Input.is_action_pressed(&"ui_accept"):
				var source: Dictionary = pause_owner.capture_pause_source()
				observation["pause_source_admission"] = {"ok": source.get("ok", false), "code": str(source.get("code", ""))}
				if source.get("ok", false):
					observation["admitted_frontier"] = frontier.duplicate(true)
					observation["back_admitted"] = true
					break
			await process_frame
	if observation.back_admitted:
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ESCAPE
			event.physical_keycode = KEY_ESCAPE
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			observation.events.append({"key": "Escape", "pressed": pressed,
				"frame": Engine.get_process_frames(), "contacts": input_owner.get_physical_contacts()})
			await process_frame
		# These frames occur only after physical Back requested literal Pause.
		for frame: int in 120:
			if paused and pause_owner.surface.is_visible_in_tree(): break
			await process_frame
	observation["contacts_after"] = input_owner.get_physical_contacts()
	observation["tree_paused"] = paused
	# Retain the protocol even if the following semantic observation cannot admit.
	_check(_write_text("hospital-input.json", JSON.stringify(observation, "\t")), "retain prompt physical Accept/Back observations")
	return observation
