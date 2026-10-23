extends "res://tests/integration/verify_reading_rail_journey.gd"
## Connected, explicitly injected noncanonical Hospital proof. Real owners alone
## admit Contacts, commit Schedule, restore, complete Hospital and advance the day.
const HOSPITAL_LOCATOR := preload("res://tests/support/HospitalReadingTimelineCatalog.gd")
const HOSPITAL_FIXTURE := preload("res://tests/support/HospitalReadingFixture.gd")
const FROZEN_RUN := preload("res://scripts/narrative/FrozenRunContext.gd")
const HOSPITAL_ENTRY := "hospital.faint.day3"
const NEXT_CATALOGUE := "res://tests/fixtures/dialogic/hospital_next_solo_catalogue.json"
var _with_sylvia := true
var _hospital_stages: Dictionary = {}
var _hospital_completions: Array = []
var _physical_completions: Array = []
var _text_starts: Array = []
var _catalogue_documents: Dictionary = {}
var _hospital_owner_events: Array = []
var _manual_restriction: Dictionary = {}

func _run() -> void:
	var variant := OS.get_environment("DWM_HOSPITAL_SYLVIA").strip_edges()
	if not _check(variant in ["", "yes", "no"], "explicit Hospital Sylvia variant"): return
	_with_sylvia = variant != "no"
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
		_hospital_completions.append({"command": command.duplicate(true), "result": result.duplicate(true)})
		_owner_event("hospital_reading_finished", {"command": command, "result": result}))
	bridge.narrative_validation_failed.connect(func(failure: Dictionary) -> void:
		_owner_event("narrative_validation_failed", failure))
	bridge.entry_playback_failed.connect(func(token: String, entry_id: String, failure: Dictionary) -> void:
		_owner_event("entry_playback_failed", {"token": token, "entry_id": entry_id, "failure": failure}))
	var physical: Object = bootstrap.get("_retained_presentation_owner_adapter")
	physical.physical_completion_ready.connect(func(receipt: Dictionary) -> void:
		_physical_completions.append(receipt.duplicate(true))
		_owner_event("physical_completion_ready", receipt))
	physical.physical_completion_failed.connect(func(failure: Dictionary) -> void:
		_owner_event("physical_completion_failed", failure))
	var hospital_port: Object = bootstrap.get("_retained_hospital_presentation_port")
	hospital_port.completion_ready.connect(func(result: Dictionary) -> void:
		_owner_event("hospital_port_completion_ready", result))
	hospital_port.completion_failed.connect(func(failure: Dictionary) -> void:
		_owner_event("hospital_port_completion_failed", failure))
	var coordinator: Object = bootstrap.get("_retained_day_resolution_coordinator")
	coordinator.resolution_completed.connect(func(result: Dictionary) -> void:
		_owner_event("resolution_completed", result))
	root.get_node("Dialogic").timeline_ended_with_generation.connect(func(generation: int) -> void:
		_owner_event("native_timeline_ended", {"generation": generation}))
	root.get_node("Dialogic").timeline_started_with_generation.connect(func(generation: int, request_id: String) -> void:
		_owner_event("native_timeline_started", {"generation": generation, "request_id": request_id}))
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
	# Seed only the prerequisite record; the Hospital checks below inject real F5/F9.
	var quick_fixture: Dictionary = root.get_node("SaveManager").quick_save_latest()
	if not _check(quick_fixture.get("ok", false) and root.get_node("SaveManager").save_exists(&"quick"),
		"test-only pre-Hospital Quick fixture makes F9 refusal nonvacuous: " + str(quick_fixture)): return
	if _with_sylvia:
		if not await _unlock_invitation("sylvia", 3): return
		if not await _schedule_friend("sylvia", 3): return
	else:
		_inject_faint_condition()
		if not await _schedule_done(): return
	if not await _wait_line("fixture.hospital.a"): return
	var rail: Node = _caption_layer().transport_rail
	var router: Node = root.get_node("SceneRouter")
	_manual_restriction["active_rail"] = {"save_disabled": rail.get_node("Save").disabled,
		"load_disabled": rail.get_node("Load").disabled,
		"save_available": router.can_open_witnessed_backup_save(_caption_layer()),
		"load_available": router.can_open_witnessed_backup_load(_caption_layer())}
	if not _check(_manual_restriction.active_rail.save_disabled and _manual_restriction.active_rail.load_disabled
		and not _manual_restriction.active_rail.save_available and not _manual_restriction.active_rail.load_available,
		"active Hospital rail disables manual Save and Load"): return
	var refused_save: Dictionary = await router.open_witnessed_backup_save(_caption_layer())
	var refused_load: Dictionary = await router.open_witnessed_backup_load(_caption_layer())
	_manual_restriction["rail_activation"] = {"save": refused_save, "load": refused_load}
	if not _check(not refused_save.get("ok", true) and not refused_load.get("ok", true) and not paused,
		"direct Hospital rail activations cannot open Backup"): return
	var first := _observe()
	var state_port: Object = root.get_node("ApplicationBootstrap").get("_retained_day_resolution_state_port")
	first["deferred_pair_preview"] = state_port._deferred_pair_preview()
	_stage("hospital_a", first)
	if not _check(first.source.history.captions.size() == 1
		and first.source.history.captions[0].line_id == "fixture.hospital.a"
		and first.source.history.session_id != prior.source.history.session_id
		and first.source.command.context.presentation.fields.sylvia_eligible == _with_sylvia
		and first.source.command.context.presentation.fields.sylvia_witness_receipt_id == null
		and first.deferred_pair_preview.get("ok", false)
		and first.deferred_pair_preview.value.required == false,
		"new Hospital session publishes only A with receipt-proven eligibility and no deferred pair"): return
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
	print("HOSPITAL_READING_WRITE_PASS: real prior Solo -> lawful retirement -> Schedule-Done Hospital -> partial B -> manual Save/Load refused -> test-only internal fixture checkpoint")
	await _finish_proof()

func _wait_desktop(day: int) -> bool:
	var game: Node = root.get_node("GameState")
	for frame: int in 1800:
		if game.day == day and current_scene != null and current_scene.find_child("ComputerDesktop", true, false) != null \
			and not bool(root.get_node("SaveManager").get("_new_run_busy")):
			await _frames()
			return true
		await process_frame
	var diagnostic := _desktop_timeout_diagnostic(day)
	_check(_write_text(_reading_mode + "-desktop-timeout.json", JSON.stringify(diagnostic, "\t")), "retain exact failed desktop wait state")
	_owner_event("desktop_timeout", diagnostic)
	return _check(false, "canonical desktop day did not arrive: " + str(day))

## Failure-only state capture never resumes an owner or retries a command. The
## original wait budget/assertion stays unchanged; raw bytes survive early exit.
func _desktop_timeout_diagnostic(expected_day: int) -> Dictionary:
	var game: Node = root.get_node("GameState")
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	var bridge: Node = root.get_node("DialogicBridge")
	var router: Node = root.get_node("SceneRouter")
	var dialogic: Node = root.get_node("Dialogic")
	var coordinator: Object = bootstrap.get("_retained_day_resolution_coordinator")
	var physical: Object = bootstrap.get("_retained_presentation_owner_adapter")
	var hospital_port: Object = bootstrap.get("_retained_hospital_presentation_port")
	var dispatcher: Object = bootstrap.get("_retained_schedule_done_dispatcher")
	var gate: Object = bootstrap.get("_application_gate")
	var reading: Variant = bridge.get("_reading_session")
	var runtime: Variant = bridge.get("_runtime_adapter")
	var reading_state := {}
	if reading != null:
		for key: String in ["family", "command_id", "pre_entry_id", "latest_entry", "boundary"]:
			reading_state[key] = reading.get(key)
		if reading.ledger != null: reading_state["ledger"] = reading.ledger.snapshot()
	var bindings := {}
	for key: String in ["_active_entry", "_active_playback", "_ordinary_playback", "_current_timeline_id",
		"_current_timeline_context", "_hospital_reading_command", "_hospital_reading_token", "_hospital_reading_completed",
		"_reading_restore_pending", "_reading_restore_adoption", "_reading_restore_token", "_pause_handle"]:
		bindings[key] = bridge.get(key)
	var diagnostic := {"mode": _reading_mode, "process_id": OS.get_process_id(), "frame": Engine.get_process_frames(),
		"expected_day": expected_day, "actual_day": game.day, "route_id": str(router.get_current_route_id()),
		"scene": {"path": current_scene.scene_file_path if is_instance_valid(current_scene) else "",
			"node_path": str(current_scene.get_path()) if is_instance_valid(current_scene) else "",
			"has_desktop": is_instance_valid(current_scene) and current_scene.find_child("ComputerDesktop", true, false) != null},
		"tree_paused": paused, "lifecycle": game._run_lifecycle.to_dict(), "gameplay": game.to_save_dict(),
		"contacts": game.contacts.duplicate(true), "live_session": game.capture_live_session(),
		"bridge": {"has_active_playback": bridge.has_active_playback(), "bindings": bindings, "reading_state": reading_state,
			"checkpoint": bridge.capture_reading_checkpoint(false), "history": bridge.get_reading_history(), "suspension": bridge.get_state()},
		"native": {"timeline": dialogic.current_timeline, "ending": dialogic.is_ending_timeline(),
			"generation": dialogic.get_timeline_generation(),
			"event_index": dialogic.current_event_idx, "event_count": dialogic.current_timeline_events.size(),
			"state": dialogic.current_state, "state_info": dialogic.current_state_info,
			"runtime_frontier": runtime.capture_reading_frontier() if runtime != null else {},
			"adapter": {"activity_phase": runtime.get("_activity_phase"), "runtime_generation": runtime.get("_runtime_generation"),
				"request_id": runtime.get("_request_id"), "requested_path": runtime.get("_requested_path")} if runtime != null else {}},
		"hospital_completions": _hospital_completions.duplicate(true), "physical_completions": _physical_completions.duplicate(true),
		"text_starts": _text_starts.duplicate(true), "speech_admissions": _speech_admissions,
		"coordinator": {"last_completion": coordinator.get_last_presentation_completion(),
			"last_failure": coordinator.get_last_presentation_failure(), "awaiting": coordinator.get("_awaiting"),
			"launched_transaction": coordinator.get("_launched_transaction"), "run_id": coordinator.get("_run_id")},
		"physical_owner": {"in_flight": physical.get("_in_flight"), "completed": physical.get("_completed")},
		"hospital_port": {"commands": hospital_port.get("_commands"), "settled": hospital_port.get("_settled")},
		"dispatcher_last_result": dispatcher.get_last_dispatch_result() if dispatcher != null else {},
		"bootstrap_continuation": {"pending": bootstrap.get("_pending_live_continuation"),
			"queued": bootstrap.get("_live_continuation_queued"), "last_condition_result": bootstrap.get("_last_condition_hospital_result")},
		"route_restore_publication_held": router.is_restore_publication_held(),
		"gate": {"active": gate.is_active(), "owner": str(gate.get_active_owner()), "fatal": gate.is_fatal_latched(),
			"fatal_failure": gate.get("_fatal_failure")},
		"save_manager": {"new_run_busy": root.get_node("SaveManager").get("_new_run_busy")},
		"owner_events": _hospital_owner_events.duplicate(true)}
	return _diagnostic_value(diagnostic)

## Separate passive trace: canonical acceptance stages keep their original exact
## order. This stream also retains failures that prevent a final mode report.
func _owner_event(kind: String, value: Dictionary) -> void:
	var event := {"mode": _reading_mode, "process_id": OS.get_process_id(), "sequence": _hospital_owner_events.size() + 1,
		"frame": Engine.get_process_frames(), "kind": kind, "value": _diagnostic_value(value)}
	_hospital_owner_events.append(event)
	var path := _evidence_path(_reading_mode + "-owner-events.jsonl")
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if not _check(file != null, "retain passive owner event trace"): return
	file.seek_end()
	file.store_line(JSON.stringify(event))
	file.close()

func _diagnostic_value(value: Variant) -> Variant:
	if value is Dictionary:
		var copy := {}
		for key: Variant in value: copy[str(key)] = _diagnostic_value(value[key])
		return copy
	if value is Array:
		var copy: Array = []
		for item: Variant in value: copy.append(_diagnostic_value(item))
		return copy
	if value is Object:
		if not is_instance_valid(value): return null
		var identity := {"class": value.get_class(), "instance_id": value.get_instance_id()}
		if value is Resource: identity["resource_path"] = value.resource_path
		if value is Node and value.is_inside_tree(): identity["node_path"] = str(value.get_path())
		return identity
	return value

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
		_inject_faint_condition()
	return await _schedule_done()

func _inject_faint_condition() -> void:
	var game: Node = root.get_node("GameState")
	game.set_stat("health", 0)
	game.set_stat("pressure", 10)
	game.condition_effects_today.assign(["sequela"])

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
	var command := {}
	if current_scene != null and current_scene.has_method("get_presentation_projection"):
		command = current_scene.get_presentation_projection()
	var art: Array = []
	if not command.is_empty():
		art = preload("res://scripts/ui/HospitalScene.gd").art_participants({}, command.context)
	var notice := current_scene.find_child("FaintNotice", true, false) if current_scene != null else null
	return {"hospital_art_participants": art, "scene_art": bridge.get_current_scene_art(), "faint_notice_visible": is_instance_valid(notice) and notice.is_visible_in_tree(),
		"tree_paused": paused, "focus_owner": str(focus.get_path()) if is_instance_valid(focus) else "",
		"pause_visible": pause.surface.is_visible_in_tree(), "pause_entered_action": str(pause.surface.entered_action),
		"history_open": bool(layer.get("_history_open")) if layer != null else false,
		"history_focus": is_instance_valid(overlay) and is_instance_valid(focus) and overlay.is_ancestor_of(focus),
		"history_button_focus": is_instance_valid(button) and focus == button,
		"bridge_suspension": bridge.get_state(), "bridge_pause_handle": bridge.get("_pause_handle").duplicate(true)}

func _base_report() -> Dictionary:
	return {"schema_version": 1, "mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "catalogues": _catalogue_documents.duplicate(true),
		"manual_restriction": _manual_restriction.duplicate(true),
		"fixture": {"save_scope": "test-only internal checkpoint and compatibility restore; Hospital manual Save/Load disabled", "production_content": false, "sylvia_eligible": _with_sylvia, "condition": {"health": 0, "pressure": 10, "condition_effects_today": ["sequela"]},
			"condition_injection": "after real day3 Sylvia Contacts acceptance and Schedule placement, immediately before Done" if _with_sylvia else "empty day3 Schedule, immediately before Done",
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
	var disk_before := _hospital_save_disk_state()
	if not _check(not disk_before.is_empty() and disk_before.quick.exists and not pause.can_save_backup() and not pause.can_load_backup(),
		"Hospital Pause refuses both manual capabilities"): return false
	for host: String in ["root", "settings"]:
		if host == "settings":
			pause.surface.rows[&"settings"].grab_focus()
			if not await _ordinary_accept_focused(pause.surface.rows[&"settings"], "Hospital Settings entry"): return false
		for code: Key in [KEY_F5, KEY_F9]:
			await _dating_quick_key(code)
			var observation := _observe()
			var disk_after := _hospital_save_disk_state()
			var key := host + ("_f5" if code == KEY_F5 else "_f9")
			_manual_restriction[key] = {"unchanged_reading": observation == reentered,
				"before_disk": disk_before, "after_disk": disk_after,
				"host": str(pause.surface.entered_action)}
			if not _check(observation == reentered and disk_after == disk_before and paused
				and pause.surface.entered_action == (&"settings" if host == "settings" else &""),
				"Hospital " + key + " refuses without reveal, write or restore"): return false
		if host == "settings": await _pause_key()
	pause.surface.rows[&"backup"].grab_focus()
	await _frames()
	if not _check(_observe() == reentered, "Backup focus preview remains pure"): return false
	if not await _ordinary_accept_focused(pause.surface.rows[&"backup"], "Hospital read-only Backup entry"): return false
	var backup: Control = pause.surface.get("_hosts")[&"backup"]
	var hosted := _observe()
	_stage("backup_entered", hosted)
	backup.drawer_buttons["slot:3"].grab_focus()
	if not await _ordinary_accept_focused(backup.drawer_buttons["slot:3"], "Hospital slot inspection"): return false
	var manual_slot_save_disabled: bool = backup.action_buttons["save"].disabled
	backup.mode_buttons["load"].grab_focus()
	if not await _ordinary_accept_focused(backup.mode_buttons["load"], "Hospital Load mode inspection"): return false
	backup.drawer_buttons["autosave"].grab_focus()
	if not await _ordinary_accept_focused(backup.drawer_buttons["autosave"], "Hospital existing Autosave inspection"): return false
	_manual_restriction["backup"] = {"save_disabled": manual_slot_save_disabled,
		"load_disabled": backup.action_buttons["load"].disabled,
		"unchanged_reading": _observe() == reentered, "before_disk": disk_before,
		"after_disk": _hospital_save_disk_state()}
	if not _check(hosted == reentered and _observe() == reentered
		and manual_slot_save_disabled and disk_before.autosave.exists and backup.action_buttons["load"].disabled
		and _hospital_save_disk_state() == disk_before,
		"Hospital Backup inspection disables Save/Load and preserves partial reveal and files"): return false
	await _capture_screen("hospital-save-load-disabled")
	await _pause_key()
	# Explicit test-only compatibility fixture. No player entry point admits this save.
	# Keep the existing shared owners responsible for capture, validation and disk writing.
	var bridge: Node = root.get_node("DialogicBridge")
	var completed: Dictionary = _caption_layer().complete_pause_reading_reveal(
		pause.get("_caption_anchor"), bridge, pause.get("_handle"))
	if not _check(completed.get("ok", false), "test-only fixture stabilizes retained B"): return false
	var capture: Dictionary = root.get_node("ApplicationBootstrap")._capture_paused_checkpoint_inputs()
	if not _check(capture.get("ok", false), "test-only shared owner capture"): return false
	var recorded: Dictionary = saves.record_stable_checkpoint(capture.value, &"safe_marker")
	if not _check(recorded.get("ok", false), "test-only internal Hospital checkpoint"): return false
	var written: Dictionary = saves.save_latest_to_slot(3)
	if not _check(written.get("ok", false), "test-only compatibility fixture written by shared save owner"): return false
	var disk: Dictionary = saves.get("_storage").read_text("slot_3.json")
	if not _check(disk.get("ok", false) and _write_text("saved-hospital-slot.json", disk.value), "retain test-only physical Hospital fixture bytes"): return false
	var document: Dictionary = STRICT.parse_object(disk.value)
	var admitted: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(document.value)
	if not _check(admitted.get("ok", false), "actual Save schema admits Hospital bytes"): return false
	var snapshot: Dictionary = admitted.value.candidate.current_snapshot.snapshot
	var saved := _observe()
	_stage("saved", saved)
	if not _check(saved.source == hosted.source and not saved.native.revealing and snapshot.narrative_checkpoint == saved.source.checkpoint
		and snapshot.narrative_checkpoint.reading_session.ledger.captions.size() == 2,
		"test-only checkpoint records exact Hospital A/B ledger and stable B"): return false
	await _capture_screen("hospital-saved")
	pause.surface.rows[&"continue"].grab_focus()
	return await _ordinary_accept_focused(pause.surface.rows[&"continue"], "Hospital saved Continue")

func _hospital_save_disk_state() -> Dictionary:
	var state := _settings_disk_state()
	var slot: Dictionary = root.get_node("SaveManager").get("_storage").inspect_revision("slot_3.json")
	if not _check(slot.get("ok", false), "Hospital slot inspection has no pending write"): return {}
	var text: String = slot.value.text if slot.value.exists else ""
	state["slot"] = {"exists": slot.value.exists, "sha256": text.sha256_text() if slot.value.exists else "",
		"bytes": text.to_utf8_buffer().size()}
	return state

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
	if not _check(prepared.get("ok", false), "compatibility Hospital fixture Load prepares from title: " + str(prepared)): return
	var restored: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(restored.get("ok", false), "compatibility Hospital fixture coordinated Load commits: " + str(restored)): return
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
	var restored_layer: Node = _caption_layer()
	restored_layer.accept_input.normal_accept_requested.connect(func() -> void:
		_owner_event("witnessed_normal_accept_requested", {"line_id": str(loaded.native.line_id)}))
	root.get_node("Dialogic").Inputs.dialogic_action.connect(func() -> void:
		_owner_event("native_dialogic_action", {"line_id": str(loaded.native.line_id)}))
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
		and (not _with_sylvia or game.contacts.solo_actions["solo:sylvia:day3"].state == "RESOLVED_MISSED")
		and game.contacts.sylvia_hospital_witness_receipts.size() == (1 if _with_sylvia else 0)
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
			checkpoint.frozen_context.presentation.fields.sylvia_eligible = not _with_sylvia
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
