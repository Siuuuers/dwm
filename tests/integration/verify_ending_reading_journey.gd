extends "res://tests/integration/verify_reading_rail_journey.gd"
## Noncanonical prose/eligibility arrangement; real ending, Save and restore owners.
const ENDING_FIXTURE := preload("res://tests/support/EndingReadingFixture.gd")
const ENDING_LOCATOR := preload("res://tests/support/EndingReadingTimelineCatalog.gd")
const ENDING_FROZEN := preload("res://scripts/narrative/EndingFrozenContext.gd")
const ENDING_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const ENDING_LINES := ["fixture.ending.first", "fixture.ending.second"]
var _ending_completions: Array = []
var _ending_texts: Array = []
var _ending_stages: Dictionary = {}
var _ending_failures: Array = []

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ending-reading-mode="): _reading_mode = argument.trim_prefix("--ending-reading-mode=")
	if not _check(_reading_mode in ["write", "read"] and DisplayServer.get_name() != "headless"
		and not OS.get_environment("DWM_TEST_ROOT").is_empty(), "isolated rendered mode required"): return
	print("ENDING_READING_PROCESS: " + JSON.stringify({"mode": _reading_mode, "process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://")}))
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	var bridge: Node = root.get_node("DialogicBridge")
	if not _check(bootstrap.get_startup_state().get("ready", false) and bridge.initialize(ENDING_LOCATOR).get("ok", false)
		and bridge.configure_reading_catalogue(ENDING_FIXTURE.catalogue()).get("ok", false), "production startup and explicit ending fixture injection"): return
	bridge.entry_playback_failed.connect(func(_token: String, _entry_id: String, failure: Dictionary) -> void:
		_ending_failures.append(failure.duplicate(true)))
	bridge.narrative_validation_failed.connect(func(failure: Dictionary) -> void:
		_ending_failures.append(failure.duplicate(true)))
	bootstrap.get("_ending_playback_port").playback_failed.connect(func(failure: Dictionary) -> void:
		_ending_failures.append(failure.duplicate(true)))
	bootstrap.get("_ending_playback_port").playback_completed.connect(func(completion: Dictionary) -> void:
		_ending_completions.append(completion.duplicate(true)))
	root.get_node("Dialogic").Text.text_started.connect(func(info: Dictionary) -> void: _ending_texts.append(str(info.get("text", ""))))
	var speech: Node = root.get_node("SystemTtsCoordinator")
	speech.speech_admitted.connect(func(_token: int, _source: String) -> void: _speech_admissions += 1)
	var capability: Dictionary = speech.refresh_capability("en")
	if not _check(capability.get("ok", false) and capability.value.get("available", false), "native speech capability proves restore silence nonvacuously"): return
	if _reading_mode == "write": await _ending_write()
	else: await _ending_read()

func _wait_line(line_id: String) -> bool:
	var bridge: Node = root.get_node("DialogicBridge")
	for frame: int in 360:
		var runtime: Variant = bridge.get("_runtime_adapter")
		if runtime != null and runtime.current_line_id() == line_id:
			await _frames()
			return true
		await process_frame
	var diagnostic_runtime: RefCounted = bridge.get("_runtime_adapter")
	var diagnostic := {"expected_line": line_id, "actual_line": diagnostic_runtime.current_line_id(),
		"retry_available": current_scene.get("_retry_available"),
		"pending_command": current_scene.get("_pending_ending_command"),
		"pending_completion": current_scene.get("_pending_completion"),
		"bridge_state": bridge.get_state(), "active_entry": bridge.get("_active_entry"),
		"runtime_phase": diagnostic_runtime.get("_activity_phase"), "failures": _ending_failures,
		"lifecycle": root.get_node("GameState")._run_lifecycle.to_dict(),
		"completions": _ending_completions, "text_starts": _ending_texts}
	_write_text(_reading_mode + "-line-timeout.json", JSON.stringify(diagnostic, "\t"))
	return _check(false, "ending caption timeout: " + JSON.stringify(diagnostic))

func _wait_desktop(day: int) -> bool:
	var game: Node = root.get_node("GameState")
	for frame: int in 1800:
		if game.day == day and current_scene != null and current_scene.find_child("ComputerDesktop", true, false) != null \
			and not bool(root.get_node("SaveManager").get("_new_run_busy")):
			await _frames()
			return true
		await process_frame
	return _check(false, "canonical desktop day did not arrive: " + str(day))

func _seed_ordered_plan() -> bool:
	# Arrangement only: no timeline completion, Profile discovery or prior-step receipt is invented.
	var game: Node = root.get_node("GameState")
	game._lifecycle_set_playing_day(7)
	var plan := {"ending_id": "ending.sylvia.special", "epilogue_ending_id": "", "source_day": 7,
		"playback_stage": "PRIMARY_PENDING", "playback_receipts": {}, "next_step_index": 0,
		"steps": [{"ending_id": "ending.sylvia.special", "role": "special_prefix"}, {"ending_id": "ending.sylvia.dark", "role": "core"}]}
	var inputs := {"dark_mode": false, "pair_form": "", "special_variant": "full"}
	for friend: String in ENDING_FROZEN.FRIENDS:
		inputs[friend] = {"tier": "friend", "tone": "sweet", "attitude": "", "echo_ids": [], "miss_reasons": []}
	var seed := ENDING_FROZEN.make_seed(inputs, {"priscilla": [], "lavinia": [], "sylvia": [], "priscilla_lavinia": []}, [], "empty_done")
	if not _check(seed.get("ok", false) and game._run_lifecycle.enter_ending(plan).get("ok", false), "explicit eligible two-step arrangement"): return false
	game.route_context["provisional_ending_plan"] = {"steps": plan.steps.duplicate(true), "eligibility_snapshot": {"presentation_by_scope": inputs, "hospital_required": false}}
	game.route_context["ending_frozen_contexts_v1"] = {"schema_version": 1, "seed": seed.value, "presentations": {}}
	game.route_context["ending_id"] = "ending.sylvia.special"
	game.route_context["epilogue_ending_id"] = ""
	return true

func _ending_write() -> void:
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	current_scene.get_node("%NewAccButton").pressed.emit()
	if not await _wait_desktop(1): return
	if not _check(root.get_node("ProfileManager").set_preferences({&"preferences.reading.read_aloud_enabled": true,
		&"preferences.reading.reveal_speed": "slow", &"preferences.reading.auto_enabled": false}).get("ok", false), "save real non-auto reading preferences"): return
	if not _seed_ordered_plan(): return
	root.get_node("SceneRouter").goto_ending()
	if not await _wait_line(ENDING_LINES[0]): return
	_ending_stages["first"] = _ending_observe()
	if not _check(_ending_stages.first.history.captions.size() == 1 and _ending_completions.is_empty(), "fresh chain has first caption only and no completion"): return
	# First Enter completes a partial reveal; a separate fresh Enter completes the native step.
	if not await _fresh_caption_accept(): return
	await _frames()
	if not _check(root.get_node("DialogicBridge").get("_runtime_adapter").is_current_line_complete(), "first real input finishes first reveal"): return
	if not await _fresh_caption_accept(): return
	if not await _wait_line(ENDING_LINES[1]): return
	_ending_stages["second"] = _ending_observe()
	if not _check(_ending_completions.size() == 1 and _ending_stages.second.lifecycle.ending_plan.next_step_index == 1
		and _ending_stages.second.history.session_id == _ending_stages.first.history.session_id
		and _ending_stages.second.history.captions.size() == 2, "physical first completion crosses boundary without splitting History"): return
	if not await _ending_pause_save(): return
	if not await _ending_history("ending-saved-history"): return
	var report := _ending_report()
	report["saved"] = _ending_observe()
	if not _check(_write_text("write.json", JSON.stringify(report, "\t")), "retain ending writer report"): return
	print("ENDING_READING_WRITE_PASS: physical first completion -> partial second Pause -> actual manual Save -> chronological History")
	await _finish_proof()

func _ending_pause_save() -> bool:
	var pause: Node = root.get_node("SceneRouter").get("_production_pause")
	if not _check(not root.get_node("DialogicBridge").get("_runtime_adapter").is_current_line_complete(), "second caption is still partly revealed before Pause"): return false
	await _pause_key()
	if not _check(paused and pause.surface.visible and _caption_layer().caption_text.revealing, "Pause retains second partial reveal"): return false
	_ending_stages["partial_pause"] = _ending_observe()
	await _capture_screen("ending-partial-pause")
	pause.surface.rows[&"backup"].grab_focus()
	if not await _ordinary_accept_focused(pause.surface.rows[&"backup"], "ending Backup entry"): return false
	var backup: Control = pause.surface.get("_hosts")[&"backup"]
	if not _check(backup.active_mode == "save" and not _caption_layer().caption_text.revealing, "Backup stabilizes exact second caption"): return false
	backup.drawer_buttons["slot:3"].grab_focus()
	if not await _ordinary_accept_focused(backup.drawer_buttons["slot:3"], "ending Slot 3 selection"): return false
	backup.action_buttons["save"].grab_focus()
	if not await _ordinary_accept_focused(backup.action_buttons["save"], "ending actual Save"): return false
	if not _check(backup.last_result.get("ok", false) and backup.get("_status_key") == "saved", "ending UI truthfully reports Saved: " + str(backup.last_result)): return false
	var disk: Dictionary = root.get_node("SaveManager").get("_storage").read_text("slot_3.json")
	if not _check(disk.get("ok", false) and _write_text("saved-ending-slot.json", disk.value), "retain physical ending slot bytes"): return false
	var parsed: Dictionary = STRICT.parse_object(disk.value)
	var admitted: Dictionary = ENDING_SCHEMA.validate(parsed.value)
	if not _check(admitted.get("ok", false), "ending slot passes actual schema: " + str(admitted)): return false
	_ending_stages["saved_snapshot"] = admitted.value.candidate.current_snapshot.snapshot
	await _capture_screen("ending-saved")
	await _pause_key()
	pause.surface.rows[&"continue"].grab_focus()
	return await _ordinary_accept_focused(pause.surface.rows[&"continue"], "ending saved Continue")

func _ending_read() -> void:
	var prior: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("write.json")))
	if not _check(prior.get("ok", false) and int(prior.value.process_id) != OS.get_process_id(), "fresh process reads writer proof"): return
	var saves: Node = root.get_node("SaveManager")
	var profile: Dictionary = root.get_node("ProfileManager").get_profile_snapshot()
	if not _check(root.get_node("ProfileManager").get_preference(&"preferences.reading.read_aloud_enabled", false), "saved read-aloud is enabled"): return
	# Reject a coherent earlier-frame forgery against the unmodified authoritative Run.
	var candidate: Dictionary = prior.value.stages.saved_snapshot.duplicate(true)
	var earlier: Dictionary = candidate.narrative_checkpoint.reading_session.ledger.entry_contexts["ending.sylvia.special.full"]
	earlier.presentation.fields.stored_tone = "dark"
	var participant: Object = saves.get("_restore_participants")["narrative"]
	var before_forge := _ending_idle()
	var refused: Dictionary = participant.prepare({"content_version": 1, "narrative_checkpoint": candidate.narrative_checkpoint, "snapshot": candidate})
	_ending_stages["forgery"] = {"refusal": refused, "unchanged": before_forge == _ending_idle()}
	if not _check(not refused.get("ok", false) and _ending_stages.forgery.unchanged, "changed earlier frame refuses before installation"): return
	if not _check(_write_text("forged-ending-snapshot.json", JSON.stringify(candidate, "\t")), "retain exact refused forgery"): return
	var prepared: Dictionary = saves.prepare_backup_action("load", "slot:3")
	if not _check(prepared.get("ok", false), "ending real Load prepares: " + str(prepared)): return
	var loaded: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(loaded.get("ok", false), "ending real Load commits: " + str(loaded)): return
	if not await _wait_line(ENDING_LINES[1]): return
	var restored := _ending_observe()
	_ending_stages["restored"] = restored
	if not _check(restored.checkpoint == prior.value.saved.checkpoint and restored.history == prior.value.saved.history
		and _ending_restore_identity_matches(restored.lifecycle, prior.value.saved.lifecycle) and restored.profile == profile
		and not restored.native.revealing and restored.native.visible_ratio == 1.0
		and _speech_admissions == 0 and _ending_completions.is_empty(), "fresh Load restores exact second caption/History silently without repeated effects"): return
	if not _check(ENDING_FIXTURE.catalogue().entries[0].lines[0].text not in _ending_texts, "Load never starts first caption before seeking second"): return
	await _capture_screen("ending-restored")
	if not await _ending_history("ending-restored-history"): return
	var game: Node = root.get_node("GameState")
	var first: Dictionary = restored.lifecycle.ending_plan.playback_receipts["step:0"]
	var before_duplicate := _ending_observe()
	var duplicate: Dictionary = game.complete_ending_playback_stage(str(restored.lifecycle.run_id) + ":ending:0:complete", &"PRIMARY_PENDING", first.value)
	if not _check(duplicate.get("ok", false) and _ending_observe() == before_duplicate, "actual first completion retry neither advances nor repeats consequences"): return
	_ending_stages["duplicate"] = {"ok": true, "unchanged": true}
	if not await _fresh_caption_accept(): return
	for frame: int in 360:
		if game._run_lifecycle.get_state() == &"COMPLETED": break
		await process_frame
	await _frames()
	if not _check(game._run_lifecycle.get_state() == &"COMPLETED" and _ending_completions.size() == 1
		and not root.get_node("DialogicBridge").get_reading_history().get("ok", false), "one remaining native completion finishes chain and retires History"): return
	_ending_stages["completed"] = {"lifecycle": game._run_lifecycle.to_dict(), "profile": root.get_node("ProfileManager").get_profile_snapshot()}
	var report := _ending_report()
	if not _check(_write_text("read.json", JSON.stringify(report, "\t")), "retain ending reader report"): return
	print("ENDING_READING_READ_PASS: fresh exact second Load -> silent ordered History -> duplicate first refusal to repeat -> one remaining completion")
	root.get_node("SystemTtsCoordinator").stop(&"ending_fixture_teardown")
	await root.get_node("SystemTtsCoordinator").wait_until_recovered()
	await _frames()
	quit(0)

func _ending_history(label: String) -> bool:
	var before := _ending_observe()
	var layer: Node = _caption_layer()
	var button: Button = layer.transport_rail.get_node("History")
	button.grab_focus()
	if not await _ordinary_accept_focused(button, "ending History"): return false
	var overlay: Node = layer.get("_history_overlay")
	var texts: Array[String] = []
	var ids: Array = []
	for row: Dictionary in before.history.captions:
		texts.append(row.text)
		ids.append(row.line_id)
	if not _check(layer.get("_history_open") and ids == ENDING_LINES and overlay.get_captions() == texts, "one actual chronological cross-step History"): return false
	await _capture_screen(label)
	overlay.close_button.grab_focus()
	if not await _ordinary_accept_focused(overlay.close_button, "ending History Close"): return false
	return _check(_ending_observe() == before and root.gui_get_focus_owner() == button, "History closes without source mutation or repeated effects")

func _ending_observe() -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	var history: Dictionary = bridge.get_reading_history()
	if not _check(checkpoint.get("ok", false) and history.get("ok", false), "ending observation has admitted checkpoint/History"): return {}
	var text: DialogicNode_DialogText = _caption_layer().caption_text
	return {"checkpoint": checkpoint.value, "history": history.value,
		"native": {"text": text.get_parsed_text(), "revealing": text.revealing, "visible_ratio": text.visible_ratio},
		"lifecycle": root.get_node("GameState")._run_lifecycle.to_dict(),
		"profile": root.get_node("ProfileManager").get_profile_snapshot(), "speech_admissions": _speech_admissions}

func _ending_restore_identity_matches(restored: Dictionary, saved: Dictionary) -> bool:
	# Load allocates a fresh continuation identity; the ending cursor/receipts stay exact.
	var restored_story := restored.duplicate(true)
	var saved_story := saved.duplicate(true)
	for key: String in ["branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt", "restore_provenance"]:
		restored_story.erase(key)
		saved_story.erase(key)
	var provenance: Dictionary = restored.get("restore_provenance", {})
	return restored_story == saved_story and restored.branch_id != saved.branch_id \
		and int(restored.desktop_timeline_generation) > int(saved.desktop_timeline_generation) \
		and restored.causal_day_instance != saved.causal_day_instance \
		and provenance.get("source_branch_id") == saved.branch_id \
		and provenance.get("source_desktop_timeline_generation") == saved.desktop_timeline_generation \
		and provenance.get("source_causal_day_instance") == saved.causal_day_instance \
		and provenance.get("source_issuer_observed_counter") == saved.causal_day_instance_issuer_receipt.get("counter", 0) \
		and not str(provenance.get("restore_transaction_id", "")).is_empty()

func _ending_idle() -> Dictionary:
	return {"gameplay": root.get_node("GameState").to_save_dict(), "lifecycle": root.get_node("GameState")._run_lifecycle.to_dict(),
		"profile": root.get_node("ProfileManager").get_profile_snapshot(), "active": root.get_node("DialogicBridge").has_active_playback(),
		"texts": _ending_texts.duplicate(), "speech": _speech_admissions, "completions": _ending_completions.duplicate(true)}

func _ending_report() -> Dictionary:
	return {"schema_version": 1, "mode": _reading_mode, "process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"fixture_scope": "Noncanonical prose and seeded Day7 eligibility; real physical completions, Save and Load.",
		"catalogue": ENDING_FIXTURE.catalogue(), "stages": _ending_stages, "completions": _ending_completions,
		"text_starts": _ending_texts, "speech_admissions": _speech_admissions}

func _evidence_path(name: String) -> String:
	var folder := ProjectSettings.globalize_path("user://evidence/ending-reading")
	DirAccess.make_dir_recursive_absolute(folder)
	return folder.path_join(name)

func _check(value: bool, detail: String) -> bool:
	if not value:
		printerr("ENDING_READING_FAIL: " + detail)
		quit(1)
	return value
