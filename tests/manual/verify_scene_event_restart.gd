extends "res://tests/integration/verify_playable_startup.gd"
## Real rendered owners and disk; retained JSON reports are comparisons, never state seeds.
const EVENT_FIXTURE := preload("res://tests/support/DurableSceneEventFixture.gd")
const CATALOG := preload("res://tests/support/SoloReadingRailTimelineCatalog.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const RUN_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
var _phase := ""
var _fault := ""
var _report_dir := "res://.godot/ci/restart"

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scene-event-fault="): _fault = argument.trim_prefix("--scene-event-fault=")
		if argument.begins_with("--scene-event-phase="): _phase = argument.trim_prefix("--scene-event-phase=")
		if argument.begins_with("--scene-event-report-dir="): _report_dir = argument.trim_prefix("--scene-event-report-dir=")
	if not _check(_phase in ["produce", "consume", "consume-again", "missing-registry", "mismatched-registry", "fault-produce", "fault-consume", "produce-other", "consume-other", "old-format"], "explicit scene event phase"): return
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
	if _phase in ["fault-produce", "fault-consume"] and not _check(_fault in ["before-write", "lost-ack", "rollback-fail", "adoption"], "explicit injected fault"): return
	if _phase in ["produce", "fault-produce"]: await super._run()
	elif _phase == "fault-consume": await _fault_consume()
	elif _phase in ["produce-other", "consume-other"]: await _other_occurrence()
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
	if _phase == "fault-produce": await _fault_produce()
	else: await _produce()

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
	if _phase == "old-format":
		if not _verify_old_occupied_slot(): return
		await _finish()
		return
	if prior.has("live_session"):
		var stale_session: Dictionary = bridge.dispatch_scene_event(prior.live_session, prior.envelope)
		if not _check(not stale_session.get("ok", false), "old live session refused"): return
	if not _check(not _dispatch(prior.envelope).get("ok", false), "actual prior process playback token refused with current live handle"): return
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
	prepared = saves.prepare_backup_action("load", "slot:1")
	if not _check(prepared.get("ok", false), "second actual manual slot Load prepares"): return
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
		var read: Dictionary = _raw_primary(path)
		result[path] = str(read.value).sha256_text() if read.get("ok", false) else "missing"
	return result

func _disk_snapshot(path: String) -> Dictionary:
	var read: Dictionary = _raw_primary(path)
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
	if destination.is_empty():
		await _frames()
		return true
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


## TEST seam at native FileOps: every noninjected operation remains real disk I/O.
class AutosaveFaultOps extends RefCounted:
	var target: RefCounted
	var armed := false
	var persistent := false
	var failures := 0
	func _init(native: RefCounted) -> void: target = native
	func exists(path: String) -> bool: return target.exists(path)
	func read_bytes(path: String) -> Dictionary: return target.read_bytes(path)
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if armed and path.replace("\\", "/").ends_with("/autosave.json.next"):
			failures += 1
			if not persistent: armed = false
			return {"ok": false, "code": &"write_failed", "message": "TEST native Autosave candidate write refusal"}
		return target.write_bytes(path, bytes)
	func flush_path(path: String) -> Dictionary: return target.flush_path(path)
	func rename_path(source: String, destination: String) -> Dictionary: return target.rename_path(source, destination)
	func remove_path(path: String) -> Dictionary: return target.remove_path(path)
	func sha256(bytes: PackedByteArray) -> String: return target.sha256(bytes)


## Lost acknowledgement follows a completed real disk+journal commit. Failure of
## compensation is then injected inside real FileOps, not fabricated rollback.
class SceneEventFaultPort extends RefCounted:
	var target: Object
	var files: AutosaveFaultOps
	var fault: String
	var commit_result := {}
	var rollback_result := {}
	func _init(real_port: Object, file_ops: AutosaveFaultOps, mode: String) -> void:
		target = real_port
		files = file_ops
		fault = mode
	func preview_checkpoint_id(run_id: String) -> Dictionary: return target.preview_checkpoint_id(run_id)
	func capture() -> Dictionary: return target.capture()
	func prepare(inputs: Dictionary, kind: StringName, write: Dictionary) -> Dictionary:
		return target.prepare(inputs, kind, write)
	func commit(candidate: Dictionary) -> Dictionary:
		if fault == "before-write": files.armed = true
		commit_result = target.commit(candidate)
		if commit_result.get("ok", false) and fault in ["lost-ack", "rollback-fail"]:
			return {"ok": false, "code": &"TEST_lost_ack", "message": "TEST interrupted acknowledgement after real commit"}
		return commit_result
	func rollback(backup: Dictionary) -> Dictionary:
		if fault == "rollback-fail":
			files.armed = true
			files.persistent = true
		rollback_result = target.rollback(backup)
		return rollback_result


func _fault_produce() -> void:
	var game: Node = root.get_node("GameState")
	var bridge: Node = root.get_node("DialogicBridge")
	var saves: Node = root.get_node("SaveManager")
	var gate: RefCounted = root.get_node("ApplicationBootstrap").get("_application_gate")
	var adapter: RefCounted = game.get("_narrative_checkpoint_port")
	var real_port: Object = adapter.get("_real_port")
	var storage: RefCounted = saves.get("_storage")
	var native_files: RefCounted = storage.get("_file_ops")
	var fault_files := AutosaveFaultOps.new(native_files)
	var fault_port := SceneEventFaultPort.new(real_port, fault_files, _fault)
	var prior_disk: Dictionary = _raw_primary("autosave.json")
	if not _check(prior_disk.get("ok", false), "actual Autosave preimage exists"): return
	var prior_journal: Dictionary = real_port.capture()
	if not _check(prior_journal.get("ok", false), "actual journal preimage"): return
	var prior_live: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var prior_reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(prior_reading.get("ok", false), "fault reading source"): return
	var prior_profile: Dictionary = root.get_node("ProfileManager").get_profile_snapshot().duplicate(true)
	var envelope := _envelope("fixture.notice.set")
	if envelope.is_empty(): return
	storage.set("_file_ops", fault_files)
	adapter.set("_real_port", fault_port)
	if _fault == "adoption": game.set("_scene_event_before_adoption", func() -> bool: return false)
	var failed := _dispatch(envelope)
	# Restore only I/O machinery for observation/retry. Never clear fatal custody.
	storage.set("_file_ops", native_files)
	adapter.set("_real_port", real_port)
	game.set("_scene_event_before_adoption", Callable())
	if not _check(not failed.get("ok", false), "injected fault refused " + str(failed)): return
	if not _check(game.capture_run_snapshot_input() == prior_live and bridge.capture_reading_checkpoint(false).value == prior_reading.value and root.get_node("ProfileManager").get_profile_snapshot() == prior_profile, "fault retains exact live owner reading and Profile"): return
	var after_disk: Dictionary = _raw_primary("autosave.json")
	if not _check(after_disk.get("ok", false), "actual post-fault primary readable"): return
	var fatal: bool = gate.is_fatal_latched()
	var compensated: bool = _fault in ["before-write", "lost-ack"]
	if compensated:
		if not _check(not fatal and after_disk.value == prior_disk.value and real_port.capture() == prior_journal, "proven compensation restores exact primary journal and live"): return
		var retry := _dispatch(envelope)
		if not _check(retry.get("ok", false) and not retry.get("duplicate", false), "same command retries once after proven compensation " + str(retry)): return
	else:
		if not _check(fatal and after_disk.value != prior_disk.value, "committed interruption retains fatal custody with new primary"): return
		var bypass: Dictionary = saves.prepare_backup_action("save", "slot:1")
		if not _check(not bypass.get("ok", false) and not _dispatch(envelope).get("ok", false), "fatal custody refuses Save and event bypass"): return
		if not _check(_raw_primary("autosave.json").value == after_disk.value and game.capture_run_snapshot_input() == prior_live, "refused bypass cannot alter retained disk or stale live"): return
	if _fault == "before-write" and not _check(fault_files.failures == 1, "one real candidate write was refused"): return
	if _fault == "rollback-fail" and not _check(fault_files.failures > 0 and not fault_port.rollback_result.get("ok", false), "actual rollback file write failed"): return
	if _fault in ["lost-ack", "rollback-fail"] and not _check(fault_port.commit_result.get("ok", false), "lost ack followed actual committed write"): return
	var snapshot := _disk_snapshot("autosave.json")
	if snapshot.is_empty(): return
	if not _check(snapshot.command_receipts.has(envelope.command_id), "fresh recovery input contains actual committed receipt"): return
	var report := {"phase": _phase, "fault": _fault, "process_id": OS.get_process_id(),
		"scope": "injected native file/ack/adoption faults; ordinary process exit, not a process crash",
		"envelope": envelope, "checkpoint": snapshot.narrative_checkpoint, "receipts": snapshot.command_receipts,
		"profile": prior_profile, "disk": _disk_hashes(), "prior_primary_sha256": str(prior_disk.value).sha256_text(),
		"failure": failed, "fatal": fatal, "compensated": compensated, "file_refusals": fault_files.failures,
		"native_commit": fault_port.commit_result, "native_rollback": fault_port.rollback_result}
	if not _write_report("fault-produce", report): return
	if fatal:
		# Do not invoke cleanup commands through fatal custody; the controller starts
		# a new process over these exact bytes. This is explicitly ordinary exit.
		print("SCENE_EVENT_FAULT_PRODUCE_PASS")
		quit(0)
	else: await _finish()


func _fault_consume() -> void:
	var prior := _read_report("fault-produce")
	if prior.is_empty(): return
	if not _check(prior.fault == _fault and int(prior.process_id) != OS.get_process_id(), "matched fault and independent fresh process"): return
	if not _check(_disk_hashes().get("autosave.json") == prior.disk["autosave.json"], "fresh process reads exact fault producer Autosave"): return
	var saves: Node = root.get_node("SaveManager")
	var game: Node = root.get_node("GameState")
	var bridge: Node = root.get_node("DialogicBridge")
	var profile: Dictionary = root.get_node("ProfileManager").get_profile_snapshot().duplicate(true)
	if not _check(profile == prior.profile, "exact Profile survives fault process"): return
	var prepared: Dictionary = saves.prepare_restore_autosave()
	if not _check(prepared.get("ok", false), "prepare real fault Autosave " + str(prepared)): return
	var restored: Dictionary = saves.commit_prepared_restore(prepared.value)
	if not _check(restored.get("ok", false), "commit real fault Autosave " + str(restored)): return
	if not await _wait_line(prior.checkpoint.reading_session.frontier.line_id): return
	if not _check(game.capture_run_snapshot_input().command_receipts == prior.receipts and bridge.capture_reading_checkpoint(false).value.reading_session == prior.checkpoint.reading_session, "fresh fault Load restores exact receipt and History"): return
	if not _check(not _dispatch(prior.envelope).get("ok", false), "actual fault producer token refused after Load"): return
	var envelope: Dictionary = prior.envelope.duplicate(true)
	var context: Dictionary = game.scene_event_context()
	if not _check(context.get("ok", false), "fresh fault event owner"): return
	envelope["playback_token"] = context.value.playback_token
	var disk_before := _disk_hashes()
	var result := _dispatch(envelope)
	if not _check(result.get("ok", false) and result.get("duplicate", false) and _disk_hashes() == disk_before, "fault receipt duplicate performs no new write " + str(result)): return
	if not _check(root.get_node("ProfileManager").get_profile_snapshot() == profile and bridge.capture_reading_checkpoint(false).value.reading_session == prior.checkpoint.reading_session, "fault duplicate leaves Profile and History intact"): return
	var report := _report(envelope)
	report["fault"] = _fault
	report["duplicate_no_write"] = true
	if not _write_report("fault-consume", report): return
	await _finish()


## Evidence inspection is raw and read-only: cold/fatal storage may deliberately
## have no read lease. These bytes never become an input to an admission owner.
func _raw_primary(path: String) -> Dictionary:
	var storage: RefCounted = root.get_node("SaveManager").get("_storage")
	var absolute: String = storage.describe_root().path_join(path)
	if not FileAccess.file_exists(absolute): return {"ok": false}
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null: return {"ok": false}
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return {"ok": true, "value": bytes.get_string_from_utf8()}


func _other_occurrence() -> void:
	var prior := _read_report("produce-other" if _phase == "consume-other" else "consume")
	if prior.is_empty(): return
	if not _check(int(prior.process_id) != OS.get_process_id(), "other entry uses fresh process"): return
	if not _check(_disk_hashes()["quicksave.json"] == prior.disk["quicksave.json"], "other entry starts from exact retained Quick"): return
	var saves: Node = root.get_node("SaveManager")
	var game: Node = root.get_node("GameState")
	var bridge: Node = root.get_node("DialogicBridge")
	var profile: Dictionary = root.get_node("ProfileManager").get_profile_snapshot().duplicate(true)
	if not _check(profile == prior.profile, "other entry fresh Profile matches"): return
	var prepared: Dictionary = saves.prepare_backup_action("load", "quick")
	if not _check(prepared.get("ok", false), "other entry actual Quick prepares " + str(prepared)): return
	var loaded: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(loaded.get("ok", false), "other entry actual Quick commits " + str(loaded)): return
	if not await _wait_line(prior.checkpoint.reading_session.frontier.line_id): return
	if not _check(game.capture_run_snapshot_input().command_receipts == prior.receipts and bridge.capture_reading_checkpoint(false).value.reading_session == prior.checkpoint.reading_session, "other entry Load preserves every receipt and full reading ledger"): return
	if not _check(root.get_node("ProfileManager").get_profile_snapshot() == profile, "other entry Load is Profile neutral"): return
	if _phase == "consume-other":
		if not _check(not _dispatch(prior.envelope).get("ok", false), "prior post-entry token refused"): return
		var duplicate: Dictionary = prior.envelope.duplicate(true)
		var context: Dictionary = game.scene_event_context()
		if not _check(context.get("ok", false) and context.value.next_ordinal == 1, "restored post group owns frontier1"): return
		duplicate["playback_token"] = context.value.playback_token
		var before := _disk_hashes()
		var result := _dispatch(duplicate)
		if not _check(result.get("ok", false) and result.get("duplicate", false) and _disk_hashes() == before, "post duplicate no new disk write " + str(result)): return
		if not _check(game.capture_run_snapshot_input().command_receipts == prior.receipts and bridge.capture_reading_checkpoint(false).value.reading_session == prior.checkpoint.reading_session and root.get_node("ProfileManager").get_profile_snapshot() == profile, "post duplicate preserves both chains History and Profile"): return
		if not _write_report(_phase, _report(duplicate)): return
		await _finish()
		return
	var dating: Node = current_scene
	if not _check(dating != null and dating.get("worksheet") != null, "actual Dating host mounted"): return
	if not await _advance_line("fixture.solo.pre.b", ""): return
	if not await _wait_for_dating_board(dating): return
	dating.worksheet.cell_action_requested.emit(&"reveal", 0, int(dating.get("_physical_view").board.revision))
	var physical: Dictionary = game.capture_dating_challenge_state().value
	if not _check(physical.board is Dictionary, "actual Reveal materializes board"): return
	# Read hidden fixture state only to choose the next legal player Reveal.
	if not bool(physical.board.terminal):
		dating.worksheet.cell_action_requested.emit(&"reveal", int(physical.board.mine_indices[0]), int(dating.get("_physical_view").board.revision))
	if not await _wait_line("fixture.solo.post.a"): return
	physical = game.capture_dating_challenge_state().value
	if not _check(physical.phase == "post_challenge" and physical.board.terminal, "real terminal result precedes post entry"): return
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false).value
	var before_profile: Dictionary = root.get_node("ProfileManager").get_profile_snapshot().duplicate(true)
	var before_receipts: Dictionary = game.capture_run_snapshot_input().command_receipts.duplicate(true)
	var envelope := _envelope("fixture.notice.set")
	if envelope.is_empty(): return
	if not _check(envelope.source.entry_id == CATALOG.FIXTURE_ENTRIES[1] and envelope.ordinal == 0 and envelope.source.scene_occurrence == prior.envelope.source.scene_occurrence, "new entry has independent ordinal0 within same real reading session"): return
	var committed := _dispatch(envelope)
	if not _check(committed.get("ok", false), "actual second entry set commits " + str(committed)): return
	var receipts: Dictionary = game.capture_run_snapshot_input().command_receipts
	for key: String in before_receipts:
		if not _check(receipts.get(key) == before_receipts[key], "all prior receipt bytes retained " + key): return
	if not _check(bridge.capture_reading_checkpoint(false).value == checkpoint and root.get_node("ProfileManager").get_profile_snapshot() == before_profile, "post set leaves History and Profile unchanged"): return
	var contract: Script = preload("res://scripts/domain/narrative/SceneEventContract.gd")
	var validated: Dictionary = contract.validate_receipts(receipts)
	if not _check(validated.get("ok", false) and validated.value.occurrences.size() == 2, "two admitted event occurrence groups"): return
	var old_group: Dictionary = validated.value.occurrences[contract.occurrence_key(prior.envelope.source)]
	var new_group: Dictionary = validated.value.occurrences[contract.occurrence_key(envelope.source)]
	if not _check(old_group.next_ordinal == 2 and old_group.notification.is_empty() and new_group.next_ordinal == 1 and new_group.notification.notification_id == "fixture.notice", "independent prior clear and post set projections"): return
	if not _save("quick"): return
	var report := _report(envelope)
	report["occurrence_count"] = 2
	report["prior_receipts_preserved"] = true
	if not _write_report(_phase, report): return
	await _finish()


func _verify_old_occupied_slot() -> bool:
	var saves: Node = root.get_node("SaveManager")
	var storage: RefCounted = saves.get("_storage")
	var path: String = storage.describe_root().path_join("slot_3.json")
	if not _check(not FileAccess.file_exists(path), "old-format test destination starts empty"): return false
	var historical: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	if not _check(historical.get("ok", false), "original historical v7 snapshot"): return false
	# Synthetic old document envelope; original historical snapshot stays untouched.
	var old := {"schema_version": 7, "kind": "slot", "slot_id": 3, "save_reason": "manual",
		"current_snapshot": {"checkpoint_kind": "safe_marker", "snapshot": historical.value}, "journal": []}
	var text := JSON.stringify(old, "\t") + "\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "write isolated occupied old-format fixture"): return false
	file.store_string(text)
	file.close()
	if not _write_report("old-format-original", {"document": old, "original_text": text, "sha256": text.sha256_text()}): return false
	var profile: Dictionary = root.get_node("ProfileManager").get_profile_snapshot().duplicate(true)
	var results := {}
	for action: String in ["load", "save"]:
		var prepared: Dictionary = saves.prepare_backup_action(action, "slot:3")
		var result: Dictionary = saves.commit_backup_action(prepared.value.token) if prepared.get("ok", false) else prepared
		results[action] = result
		_write_report("old-format-observed", {"results": results, "current_sha256": FileAccess.get_file_as_string(path).sha256_text(), "expected_sha256": text.sha256_text()})
		if not _check(not result.get("ok", false), "old v7 occupied destination refuses " + action): return false
		if not _check(FileAccess.get_file_as_string(path) == text, "old v7 bytes retained after " + action): return false
	if not _check(root.get_node("ProfileManager").get_profile_snapshot() == profile, "old-format refusal leaves Profile intact"): return false
	return _write_report("old-format", {"original_sha256": text.sha256_text(), "bytes": text.to_utf8_buffer().size(), "results": results})
