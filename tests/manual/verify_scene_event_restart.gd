extends "res://tests/integration/verify_playable_startup.gd"
## Real rendered owners and disk; retained JSON reports are comparisons, never state seeds.
const EVENT_FIXTURE := preload("res://tests/support/DurableSceneEventFixture.gd")
const CATALOG := preload("res://tests/support/SoloReadingRailTimelineCatalog.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const RUN_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
var _phase := ""
var _report_dir := "res://.godot/ci/restart"

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scene-event-phase="): _phase = argument.trim_prefix("--scene-event-phase=")
		if argument.begins_with("--scene-event-report-dir="): _report_dir = argument.trim_prefix("--scene-event-report-dir=")
	if not _check(_phase in ["produce", "consume", "consume-again", "missing-registry", "mismatched-registry"], "explicit scene event phase"): return
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty()
		and DisplayServer.get_name() != "headless", "isolated rendered scene event proof"): return
	await _frames()
	if not _check(root.get_node("ApplicationBootstrap").get_startup_state().get("ready", false), "final bootstrap ready"): return
	var bridge: Node = root.get_node("DialogicBridge")
	if not _check(bridge.initialize(CATALOG).get("ok", false), "trusted fixture physical catalogue"): return
	var parsed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string("res://tests/fixtures/dialogic/solo_reading_rail_catalogue.json"))
	if not _check(parsed.get("ok", false), "strict fixture catalogue"): return
	if not _check(bridge.configure_reading_catalogue(parsed.value).get("ok", false), "trusted reading catalogue"): return
	if _phase != "missing-registry":
		var registry: Dictionary = EVENT_FIXTURE.registry()
		if _phase == "mismatched-registry":
			registry[CATALOG.FIXTURE_ENTRIES[0]].events["fixture.notice.set"].payload.content_id = "fixture.changed"
		if not _check(root.get_node("GameState").configure_test_scene_event_registry(registry).get("ok", false), "fixed TEST registration"): return
	if _phase == "produce": await super._run()
	else: await _consume()

func _dating_journey(game: Node, desktop: Node) -> void:
	if not _check(desktop.open_app(&"contacts").get("ok", false), "Contacts opens"): return
	await _frames()
	var contacts: Node = desktop.get("_cached_app_windows")[&"contacts"]
	contacts.contacts_panel.open_requested.emit("priscilla")
	if not _check(contacts.last_result.get("ok", false), "real invitation accepted"): return
	if not _check(desktop.return_home().get("ok", false), "Home"): return
	if not _check(desktop.open_app(&"schedule").get("ok", false), "Schedule opens"): return
	await _frames()
	var schedule: Node = desktop.get("_cached_app_windows")[&"schedule"]
	schedule.panel.source_requested.emit("solo:priscilla:day1")
	if not _check(schedule.last_result.get("ok", false), "real invitation scheduled"): return
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "Schedule Done " + str(done)): return
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		if not _check(ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss").get("ok", false), "schedule warning"): return
	if not await _wait_line("fixture.solo.pre.a"): return
	await _produce()

func _envelope(event_id: String) -> Dictionary:
	var context: Dictionary = root.get_node("GameState").scene_event_context()
	if not _check(context.get("ok", false), "live event context " + str(context)): return {}
	var issuer: RefCounted = root.get_node("ApplicationBootstrap").get("_desktop_identity_nonce_issuer")
	var issued: Dictionary = issuer.issue(&"transaction_id")
	if not _check(issued.get("ok", false), "real command issuance"): return {}
	var value: Dictionary = EVENT_FIXTURE.registry()[context.value.source.entry_id].events[event_id].duplicate(true)
	value["schema_version"] = 1
	value["source"] = context.value.source.duplicate(true)
	value["command_id"] = issued.value.token
	value["issuer_receipt"] = issued.value.issuer_receipt.duplicate(true)
	value["playback_token"] = context.value.playback_token
	return value

func _dispatch(envelope: Dictionary) -> Dictionary:
	var game: Node = root.get_node("GameState")
	return root.get_node("DialogicBridge").dispatch_scene_event(game.capture_live_session().value, envelope)

func _produce() -> void:
	var bridge: Node = root.get_node("DialogicBridge")
	var before: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(before.get("ok", false), "real starting reading checkpoint"): return
	var profile: Dictionary = root.get_node("ProfileManager").get_profile_snapshot().duplicate(true)
	var envelope := _envelope("fixture.notice.set")
	if envelope.is_empty(): return
	var result := _dispatch(envelope)
	if not _check(result.get("ok", false), "set commits " + str(result)): return
	if not _check(bridge.capture_reading_checkpoint(false).value == before.value and root.get_node("ProfileManager").get_profile_snapshot() == profile, "event leaves reading and Profile unchanged"): return
	var actual := _disk_snapshot("autosave.json")
	if actual.is_empty(): return
	if not _check(actual.command_receipts.has(envelope.command_id), "actual Autosave owns new receipt"): return
	if not _check(actual.narrative_checkpoint == before.value, "actual Autosave owns exact reading checkpoint"): return
	var disk_before := _disk_hashes()
	result = _dispatch(envelope)
	if not _check(result.get("ok", false) and result.get("duplicate", false) and _disk_hashes() == disk_before, "duplicate set writes nothing"): return
	if not _save("slot:1") or not _save("quick"): return
	var report := _report(envelope)
	report["duplicate_no_write"] = true
	report["live_session"] = root.get_node("GameState").capture_live_session().value
	if not _write_report("produce", report): return
	await _finish()

func _consume() -> void:
	var prior := _read_report("consume" if _phase == "consume-again" else "produce")
	if prior.is_empty(): return
	if not _check(int(prior.process_id) != OS.get_process_id(), "fresh OS process"): return
	if not _check(_disk_hashes().get("quicksave.json") == prior.disk["quicksave.json"], "exact producer Quick bytes before Load"): return
	var saves: Node = root.get_node("SaveManager")
	var profile: Dictionary = root.get_node("ProfileManager").get_profile_snapshot().duplicate(true)
	if not _check(profile == prior.profile, "fresh process restores producer Profile"): return
	var original_disk := _disk_hashes()
	var prepared: Dictionary = saves.prepare_backup_action("load", "quick")
	if _phase in ["missing-registry", "mismatched-registry"]:
		var refused: Dictionary = saves.commit_backup_action(prepared.value.token) if prepared.get("ok", false) else prepared
		if not _check(not refused.get("ok", false) and _disk_hashes() == original_disk and root.get_node("ProfileManager").get_profile_snapshot() == profile, "unregistered restore refused without primary writes"): return
		if not _write_report(_phase, {"process_id": OS.get_process_id(), "refused": refused, "disk": original_disk}): return
		print("SCENE_EVENT_" + _phase.to_upper().replace("-", "_") + "_PASS")
		quit(0)
		return
	if not _check(prepared.get("ok", false), "prepare actual Quick Load " + str(prepared)): return
	var loaded: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(loaded.get("ok", false), "commit actual Quick Load " + str(loaded)): return
	var line: String = prior.checkpoint.reading_session.frontier.line_id
	if not await _wait_line(line): return
	var game: Node = root.get_node("GameState")
	var bridge: Node = root.get_node("DialogicBridge")
	if not _check(bridge.capture_reading_checkpoint(false).value.reading_session == prior.checkpoint.reading_session and game.capture_run_snapshot_input().command_receipts == prior.receipts, "restored complete ledger and receipts"): return
	if not _check(root.get_node("ProfileManager").get_profile_snapshot() == profile, "Load preserves Profile"): return
	if prior.has("live_session"):
		var stale_session: Dictionary = bridge.dispatch_scene_event(prior.live_session, prior.envelope)
		if not _check(not stale_session.get("ok", false), "old live session refused"): return
	var duplicate: Dictionary = prior.envelope.duplicate(true)
	var context: Dictionary = game.scene_event_context()
	if not _check(context.get("ok", false), "restored owner context"): return
	# An intentionally stale token must fail even if process-local counters coincide.
	duplicate["playback_token"] = "fixture.stale.retired.token"
	if not _check(not _dispatch(duplicate).get("ok", false), "stale playback refused"): return
	duplicate["playback_token"] = context.value.playback_token
	var before_duplicate := _disk_hashes()
	var repeated := _dispatch(duplicate)
	if not _check(repeated.get("ok", false) and repeated.get("duplicate", false) and _disk_hashes() == before_duplicate, "fresh-token duplicate no write " + str(repeated)): return
	if _phase == "consume-again":
		if not _check(root.get_node("ProfileManager").get_profile_snapshot() == profile, "restart duplicate Profile neutral"): return
		if not _write_report(_phase, _report(duplicate)): return
		await _finish()
		return
	var first_handle: Dictionary = game.capture_live_session().value
	prepared = saves.prepare_backup_action("load", "quick")
	if not _check(prepared.get("ok", false), "second Load prepares"): return
	loaded = saves.commit_backup_action(prepared.value.token)
	if not _check(loaded.get("ok", false), "second Load commits"): return
	if not await _wait_line(line): return
	if not _check(not game.validate_live_session(first_handle).get("ok", false), "Load remaps old live authority"): return
	if not _check(bridge.capture_reading_checkpoint(false).value.reading_session == prior.checkpoint.reading_session and game.capture_run_snapshot_input().command_receipts == prior.receipts, "second Load preserves immutable event bytes"): return
	if not await _advance_line("fixture.solo.pre.a", "fixture.solo.pre.b"): return
	var clear := _envelope("fixture.notice.clear")
	if clear.is_empty(): return
	var before_clear: Dictionary = bridge.capture_reading_checkpoint(false).value
	var clear_profile: Dictionary = root.get_node("ProfileManager").get_profile_snapshot().duplicate(true)
	var cleared := _dispatch(clear)
	if not _check(cleared.get("ok", false), "clear after restored continuation " + str(cleared)): return
	var receipts: Dictionary = game.capture_run_snapshot_input().command_receipts
	if not _check(receipts[prior.envelope.command_id] == prior.receipts[prior.envelope.command_id], "older set receipt unchanged"): return
	if not _check(receipts[clear.command_id].scene_event.reading_anchor.line_id == "fixture.solo.pre.b" and receipts[clear.command_id].scene_event.reading_anchor.publication_id != receipts[prior.envelope.command_id].scene_event.reading_anchor.publication_id, "clear owns later actual caption anchor"): return
	if not _check(bridge.capture_reading_checkpoint(false).value == before_clear and root.get_node("ProfileManager").get_profile_snapshot() == clear_profile, "clear leaves reading and Profile unchanged"): return
	if not _save("slot:2") or not _save("quick"): return
	var report := _report(clear)
	report["live_session"] = game.capture_live_session().value
	if not _write_report("consume", report): return
	await _finish()

func _save(slot: String) -> bool:
	var saves: Node = root.get_node("SaveManager")
	var prepared: Dictionary = saves.prepare_backup_action("save", slot)
	if not _check(prepared.get("ok", false), "prepare Save " + slot + " " + str(prepared)): return false
	var committed: Dictionary = saves.commit_backup_action(prepared.value.token)
	return _check(committed.get("ok", false), "actual Save " + slot + " " + str(committed))

func _disk_hashes() -> Dictionary:
	var storage: RefCounted = root.get_node("SaveManager").get("_storage")
	var result := {}
	for path: String in ["autosave.json", "quicksave.json"]:
		var read: Dictionary = storage.read_text(path)
		result[path] = str(read.value).sha256_text() if read.get("ok", false) else "missing"
	return result

func _disk_snapshot(path: String) -> Dictionary:
	var read: Dictionary = root.get_node("SaveManager").get("_storage").read_text(path)
	if not _check(read.get("ok", false), "read real " + path): return {}
	var parsed: Dictionary = STRICT.parse_object(read.value)
	if not _check(parsed.get("ok", false), "strict saved bytes"): return {}
	var admitted: Dictionary = DOCUMENT.validate(parsed.value)
	if not _check(admitted.get("ok", false), "real saved schema " + str(admitted)): return {}
	return admitted.value.candidate.current_snapshot.snapshot

func _report(envelope: Dictionary) -> Dictionary:
	return {"phase": _phase, "process_id": OS.get_process_id(), "envelope": envelope.duplicate(true),
		"checkpoint": root.get_node("DialogicBridge").capture_reading_checkpoint(false).value,
		"receipts": root.get_node("GameState").capture_run_snapshot_input().command_receipts,
		"profile": root.get_node("ProfileManager").get_profile_snapshot(), "disk": _disk_hashes()}

func _write_report(name: String, report: Dictionary) -> bool:
	if not _check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_report_dir)) == OK, "report folder"): return false
	var file := FileAccess.open(_report_dir.path_join(name + ".json"), FileAccess.WRITE)
	if not _check(file != null, "report file"): return false
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	return true

func _read_report(name: String) -> Dictionary:
	var parsed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_report_dir.path_join(name + ".json")))
	if not _check(parsed.get("ok", false), "prior process report"): return {}
	return RUN_SCHEMA._normalize_integral_floats(parsed.value)

func _wait_line(line_id: String) -> bool:
	var bridge: Node = root.get_node("DialogicBridge")
	for frame: int in 360:
		var runtime: Variant = bridge.get("_runtime_adapter")
		if runtime != null and runtime.current_line_id() == line_id:
			await _frames()
			return true
		await process_frame
	return _check(false, "real caption timeout " + line_id)

func _advance_line(source: String, destination: String) -> bool:
	var runtime: RefCounted = root.get_node("DialogicBridge").get("_runtime_adapter")
	if not _check(runtime.current_line_id() == source, "actual source line"): return false
	if not _check(runtime.reveal_current_line(true).get("ok", false), "real reveal completes"): return false
	await _frames()
	if not _check(runtime.advance_one_event().get("ok", false), "native coroutine advances"): return false
	return await _wait_line(destination)

func _finish() -> void:
	var bridge: Node = root.get_node("DialogicBridge")
	var before: Dictionary = bridge.capture_reading_checkpoint(false)
	var completed: Dictionary = bridge.capture_reading_checkpoint(true)
	if not _check(before.get("ok", false) and completed.get("ok", false) and before.value == completed.value, "teardown reveal keeps frontier"): return
	if not _check(bridge.abort_current_entry(&"scene_event_fixture_teardown").get("ok", false), "retire test playback"): return
	var speech: Node = root.get_node("SystemTtsCoordinator")
	speech.stop(&"scene_event_fixture_teardown")
	await speech.wait_until_recovered()
	var dialogic: Node = root.get_node("Dialogic")
	for frame: int in 120:
		if dialogic.current_timeline == null and not dialogic.is_ending_timeline(): break
		await process_frame
	if not _check(dialogic.current_timeline == null and not dialogic.is_ending_timeline(), "native coroutine retired"): return
	await _frames()
	print("SCENE_EVENT_" + _phase.to_upper().replace("-", "_") + "_PASS")
	quit(0)
