extends "res://tests/integration/verify_playable_startup.gd"
## Connected cloud proof, with test-only prose and real gameplay/persistence owners.
## The driver seals WRITE/READ before separate repeat, changed-variant and Profile-read processes.

const FIXTURE_CATALOG := preload("res://tests/support/SoloReadingRailTimelineCatalog.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const READING_CATALOGUE := "res://tests/fixtures/dialogic/solo_reading_rail_catalogue.json"
const VARIANT_B_CATALOGUE := "res://tests/fixtures/dialogic/solo_reading_rail_variant_b_catalogue.json"
const WITNESSES := preload("res://scripts/profile/CaptionWitnessLedger.gd")
const LAYOUT_PROBE := preload("res://tests/support/ColdChallengeLayoutProbe.gd")
const EXPECTED_LINES := ["fixture.solo.pre.a", "fixture.solo.pre.b", "fixture.solo.post.a"]

var _reading_mode := ""
var _speech_admissions := 0
var _history_observations := 0
var _trace_sequence := 0
var _pause_save_proof: Dictionary = {}
var _witness_beat: Dictionary = {}
var _witness_initial_profile: Dictionary = {}
var _witness_failure: Dictionary = {}
var _witness_fault: RefCounted
var _replacement_confirmations := 0
var _next_observations: Dictionary = {}
var _next_observers_installed := false
var _next_checkpoint_results: Array[Dictionary] = []


## Observe the real source/destination writes without substituting their results.
class NextCheckpointObserver extends RefCounted:
	var target: RefCounted
	var results: Array[Dictionary]
	func _init(port: RefCounted, observed: Array[Dictionary]) -> void:
		target = port
		results = observed
	func commit_reading_next(checkpoint: Dictionary, operation_id: String, phase: String) -> Dictionary:
		var result: Dictionary = target.commit_reading_next(checkpoint, operation_id, phase)
		results.append({"phase": phase, "result": result.duplicate(true)})
		return result


## One candidate-specific filesystem refusal; all successful storage operations
## delegate to the real FileOps instance and use the actual Profile transaction.
class FailOneCaptionWitnessWrite extends RefCounted:
	const JSON_READER := preload("res://scripts/validation/StrictJson.gd")
	var target: RefCounted
	var witness_id: String
	var refusals := 0
	var matching_writes := 0
	var previous_text := ""
	func _init(real_ops: RefCounted, identity: String) -> void:
		target = real_ops
		witness_id = identity
	func exists(path: String) -> bool: return target.exists(path)
	func read_bytes(path: String) -> Dictionary: return target.read_bytes(path)
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if path.ends_with("/profile.json.next") or path.ends_with("\\profile.json.next"):
			var parsed: Dictionary = JSON_READER.parse_object(bytes.get_string_from_utf8())
			if parsed.get("ok", false) and parsed.value.get("witnessed_caption_variants", {}).has(witness_id):
				matching_writes += 1
				if refusals == 0:
					refusals += 1
					var old: Dictionary = target.read_bytes(path.trim_suffix(".next"))
					if old.get("ok", false): previous_text = old.value.get_string_from_utf8()
					return {"ok": false, "code": &"write_failed", "message": "isolated exact-witness candidate refusal"}
		return target.write_bytes(path, bytes)
	func flush_path(path: String) -> Dictionary: return target.flush_path(path)
	func rename_path(source: String, destination: String) -> Dictionary: return target.rename_path(source, destination)
	func remove_path(path: String) -> Dictionary: return target.remove_path(path)
	func sha256(bytes: PackedByteArray) -> String: return target.sha256(bytes)


## The transport must durably turn Auto Off before it takes Next custody.
## Reject only that real Profile candidate, once; every other operation is real.
class FailOneAutoOffWrite extends RefCounted:
	const JSON_READER := preload("res://scripts/validation/StrictJson.gd")
	var target: RefCounted
	var refusals := 0
	var matching_writes := 0
	func _init(real_ops: RefCounted) -> void: target = real_ops
	func exists(path: String) -> bool: return target.exists(path)
	func read_bytes(path: String) -> Dictionary: return target.read_bytes(path)
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if path.replace("\\", "/").ends_with("/profile.json.next"):
			var parsed: Dictionary = JSON_READER.parse_object(bytes.get_string_from_utf8())
			if parsed.get("ok", false) and parsed.value.get("preferences", {}).get("reading", {}).get("auto_enabled") == false:
				matching_writes += 1
				if refusals == 0:
					refusals += 1
					return {"ok": false, "code": &"write_failed", "message": "isolated Next Auto Off candidate refusal"}
		return target.write_bytes(path, bytes)
	func flush_path(path: String) -> Dictionary: return target.flush_path(path)
	func rename_path(source: String, destination: String) -> Dictionary: return target.rename_path(source, destination)
	func remove_path(path: String) -> Dictionary: return target.remove_path(path)
	func sha256(bytes: PackedByteArray) -> String: return target.sha256(bytes)


## Passive mutation receipt: each operation still executes on the real FileOps.
## Shared receipts prove that Settings Save writes only the Quick transaction family.
class SettingsQuickFileObserver extends RefCounted:
	var target: RefCounted
	var owner: String
	var receipts: Array[Dictionary]
	func _init(real_ops: RefCounted, storage_owner: String, observed: Array[Dictionary]) -> void:
		target = real_ops
		owner = storage_owner
		receipts = observed
	func exists(path: String) -> bool: return target.exists(path)
	func read_bytes(path: String) -> Dictionary: return target.read_bytes(path)
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		var result: Dictionary = target.write_bytes(path, bytes)
		_record("write", path, result, {"bytes": bytes.size(), "sha256": sha256(bytes)})
		return result
	func flush_path(path: String) -> Dictionary:
		var result: Dictionary = target.flush_path(path)
		_record("flush", path, result)
		return result
	func rename_path(source: String, destination: String) -> Dictionary:
		var result: Dictionary = target.rename_path(source, destination)
		_record("rename", source, result, {"destination": destination.replace("\\", "/").get_file()})
		return result
	func remove_path(path: String) -> Dictionary:
		var result: Dictionary = target.remove_path(path)
		_record("remove", path, result)
		return result
	func sha256(bytes: PackedByteArray) -> String:
		return target.sha256(bytes)
	func _record(operation: String, path: String, result: Dictionary, extra: Dictionary = {}) -> void:
		var receipt := {"sequence": receipts.size() + 1, "owner": owner, "operation": operation,
			"path": path.replace("\\", "/").get_file(), "ok": bool(result.get("ok", false))}
		receipt.merge(extra)
		receipts.append(receipt)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--reading-rail-mode="):
			_reading_mode = argument.trim_prefix("--reading-rail-mode=")
	if not _check(_reading_mode in ["write", "read", "repeat", "variant", "witness-read", "next-unseen", "next", "next-read", "settings-write", "settings-read", "settings-load"], "explicit reading process mode"): return
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty(), "isolated test root required"): return
	if not _check(DisplayServer.get_name() != "headless", "real cloud software rendering required"): return
	await _frames()
	if not _check(root.get_node("ApplicationBootstrap").get_startup_state().get("ready", false), "real bootstrap is ready"): return
	var bridge: Node = root.get_node("DialogicBridge")
	var installed: Dictionary = bridge.initialize(FIXTURE_CATALOG)
	if not _check(installed.get("ok", false), "test-only locator injection: " + str(installed)): return
	var catalogue_path: String = VARIANT_B_CATALOGUE if _reading_mode in ["variant", "witness-read"] else READING_CATALOGUE
	var catalogue: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(catalogue_path))
	if not _check(catalogue.get("ok", false), "strict noncanonical catalogue"): return
	if _reading_mode == "next-unseen":
		# Explicitly different fixed revision, with unchanged noncanonical prose.
		# The original variant-B witnessing and Read Only proof remain independent.
		catalogue.value.entries[0].lines[0].revision = "fixture-next-unseen-v1"
	var configured: Dictionary = bridge.configure_reading_catalogue(catalogue.value)
	if not _check(configured.get("ok", false), "real reading owner accepts fixture catalogue: " + str(configured)): return
	var first_entry: Dictionary = catalogue.value.entries[0]
	var first_line: Dictionary = first_entry.lines[0]
	_witness_beat = {"beat_id": first_line.beat_id, "line_id": first_line.line_id,
		"owning_entry_id": first_entry.entry_id, "presentation_signature": {
			"content_revision": first_line.revision, "variant_id": first_line.beat_id}}
	if _reading_mode == "witness-read":
		_witness_read_process()
		return
	var speech: Node = root.get_node("SystemTtsCoordinator")
	speech.speech_admitted.connect(func(_token: int, _source: String) -> void: _speech_admissions += 1)
	var capability: Dictionary = speech.refresh_capability("en")
	if not _check(capability.get("ok", false) and capability.value.get("available", false), "real native English speech control available"): return
	if _reading_mode == "read":
		await _read_process()
		return
	if _reading_mode == "next-read":
		await _next_read_process()
		return
	if _reading_mode == "settings-load":
		await _settings_quick_load_process()
		return
	if _reading_mode == "settings-read":
		await _settings_quick_read_process()
		return
	var profile: Node = root.get_node("ProfileManager")
	var preferences: Dictionary = profile.set_preferences({
		&"preferences.reading.read_aloud_enabled": true,
		&"preferences.reading.reveal_speed": "slow",
		&"preferences.reading.auto_enabled": false,
	})
	if not _check(preferences.get("ok", false), "real reading preferences commit"): return
	if _reading_mode == "write":
		_trace("fixture_registered", {"catalogue": READING_CATALOGUE, "production_content": false})
	elif _reading_mode != "settings-write":
		_witness_initial_profile = profile.get_profile_snapshot()
		if not _check(profile.is_caption_variant_witnessed(_witness_beat) == (_reading_mode in ["repeat", "next"]),
			"fresh process admits only the exact previously witnessed variant"): return
		_confirm_replacement_new_account.call_deferred()
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
	if _reading_mode == "variant":
		var profile: Node = root.get_node("ProfileManager")
		var storage: RefCounted = profile.get("_storage")
		var identity: Dictionary = WITNESSES.describe(_witness_beat)
		if not _check(identity.get("ok", false), "strict B witness identity"): return
		_witness_fault = FailOneCaptionWitnessWrite.new(storage.get("_file_ops"), identity.value.witness_id)
		storage.set("_file_ops", _witness_fault)
		profile.profile_write_failed.connect(func(failure: Dictionary) -> void: _witness_failure = failure.duplicate(true))
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
	if _reading_mode == "settings-write":
		await _settings_quick_write_process(game, dating)
		return
	if _reading_mode in ["repeat", "variant"]:
		await _witness_session(game, dating)
		return
	if _reading_mode in ["next-unseen", "next"]:
		await _next_session(game, dating)
		return
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


func _settings_disk_state() -> Dictionary:
	var saves: RefCounted = root.get_node("SaveManager").get("_storage")
	var profile: RefCounted = root.get_node("ProfileManager").get("_storage")
	var state := {}
	for key: String in ["quick", "autosave", "profile"]:
		var storage: RefCounted = profile if key == "profile" else saves
		var filename := "quicksave.json" if key == "quick" else key + ".json"
		var inspected: Dictionary = storage.inspect_revision(filename)
		if not _check(inspected.get("ok", false), "Settings proof raw revision has no pending transaction: " + key): return {}
		var exists: bool = inspected.value.exists
		if not _check((exists and inspected.value.text is String) or key == "quick" and not exists,
			"Settings proof has actual Profile/Autosave bytes"): return {}
		var text: String = inspected.value.text if exists else ""
		if not _check(not exists or inspected.value.revision == text.sha256_text(), "raw revision binds exact UTF-8 bytes"): return {}
		state[key] = {"exists": exists, "sha256": text.sha256_text() if exists else "",
			"bytes": text.to_utf8_buffer().size() if exists else 0}
	return state


func _settings_host_observation(pause_owner: Node, settings: Control) -> Dictionary:
	var focus: Control = root.gui_get_focus_owner()
	return {"tree_paused": paused, "host_id": settings.get_instance_id(),
		"visible": settings.is_visible_in_tree(), "entered_action": str(pause_owner.surface.entered_action),
		"selected_category": str(settings.get_content_host().get("_selected")),
		"focus_id": focus.get_instance_id() if focus != null else 0,
		"focus_path": str(settings.get_path_to(focus)) if focus != null and settings.is_ancestor_of(focus) else "",
		"suspension": pause_owner.get("_handle").duplicate(true),
		"backup_mode": str(pause_owner.surface.get("_hosts")[&"backup"].active_mode),
		"backup_locator": str(pause_owner.surface.get("_hosts")[&"backup"].selected_locator)}


func _settings_quick_write_process(game: Node, dating: Node) -> void:
	var bridge: Node = root.get_node("DialogicBridge")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	var pause_owner: Node = root.get_node("SceneRouter").get("_production_pause")
	var saves: RefCounted = root.get_node("SaveManager").get("_storage")
	var profile: RefCounted = root.get_node("ProfileManager").get("_storage")
	if not _check(runtime.current_line_id() == "fixture.solo.pre.a" and not runtime.is_current_line_complete()
		and _speech_admissions > 0, "Settings proof starts at an actual partly revealed spoken line"): return
	var desktop_host: RefCounted = root.get_node("ApplicationBootstrap").get("_desktop_host_state")
	var desktop_context: Dictionary = desktop_host.capture_persistent_state().duplicate(true)
	if not _check(desktop_context.active_app_id == &"schedule", "real Dating retains its canonical Schedule context"): return
	var before_disk := _settings_disk_state()
	if not _check(not before_disk.is_empty() and not before_disk.quick.exists, "separate Settings profile begins without Quick"): return
	var mutations: Array[Dictionary] = []
	var save_ops: RefCounted = saves.get("_file_ops")
	var profile_ops: RefCounted = profile.get("_file_ops")
	saves.set("_file_ops", SettingsQuickFileObserver.new(save_ops, "saves", mutations))
	profile.set("_file_ops", SettingsQuickFileObserver.new(profile_ops, "profile", mutations))
	await _pause_key()
	var entered := _reading_pause_observation(game)
	if not _check(paused and pause_owner.surface.is_visible_in_tree() and entered.native.revealing
		and entered.native.visible_characters >= 0 and entered.native.visible_characters < entered.native.total_characters,
		"ordinary Pause retains literal partial reading for Settings"): return
	_trace("settings_pause_entered", entered)
	pause_owner.surface.rows[&"settings"].grab_focus()
	if not await _ordinary_accept_focused(pause_owner.surface.rows[&"settings"], "ordinary Settings entry"): return
	var settings: Control = pause_owner.surface.get("_hosts")[&"settings"]
	var reading_row: Button = settings.get_content_host().get("_rails")["reading"]
	reading_row.grab_focus()
	if not await _ordinary_accept_focused(reading_row, "Settings Reading category"): return
	var hosted := _reading_pause_observation(game)
	var host_before := _settings_host_observation(pause_owner, settings)
	if not _check(hosted == entered and host_before.tree_paused and host_before.visible
		and host_before.entered_action == "settings" and host_before.selected_category == "reading"
		and not host_before.focus_path.is_empty() and mutations.is_empty()
		and _settings_disk_state() == before_disk,
		"Settings entry and focus preserve partial reveal, semantic source and every save/Profile byte"): return
	_trace("settings_host_entered", {"reading": hosted, "host": host_before})
	var quick: Node = pause_owner.get("_quick_commands")
	if not _check(quick.last_result.is_empty(), "Settings physical Quick command has no earlier result"): return
	dating.get_window().grab_focus()
	await _dating_quick_key(KEY_F5)
	var saved := _reading_pause_observation(game)
	var host_after := _settings_host_observation(pause_owner, settings)
	var after_disk := _settings_disk_state()
	if not _check(quick.last_result.get("ok", false) and quick.edge.key == &"saved" and quick.edge.visible
		and saved.source == entered.source and host_after == host_before
		and saved.native.line_id == entered.native.line_id and saved.native.caption_id == entered.native.caption_id
		and saved.native.text == entered.native.text and saved.native.total_characters == entered.native.total_characters
		and saved.native.reveal_generation == entered.native.reveal_generation + 1
		and not saved.native.revealing and saved.native.visible_ratio == 1.0
		and (saved.native.visible_characters == -1 or saved.native.visible_characters >= saved.native.total_characters)
		and after_disk.profile == before_disk.profile and after_disk.autosave == before_disk.autosave
		and after_disk.quick.exists, "physical Settings F5 completes only current reveal, retains exact host/focus/source and commits only Quick"): return
	var candidate_writes := 0
	var family := ["quicksave.json", "quicksave.json.next", "quicksave.json.txn.json", "quicksave.json.bak", "quicksave.json.revision-prior"]
	for receipt: Dictionary in mutations:
		if not _check(receipt.owner == "saves" and receipt.ok and receipt.path in family
			and (not receipt.has("destination") or receipt.destination in family), "only real Quick family mutations are admitted"): return
		if receipt.operation == "write" and receipt.path == "quicksave.json.next":
			candidate_writes += 1
			if not _check(receipt.sha256 == after_disk.quick.sha256 and receipt.bytes == after_disk.quick.bytes,
				"observed physical Quick candidate is the exact committed file"): return
	if not _check(candidate_writes == 1, "one physical F5 commits exactly one Quick candidate"): return
	var disk: Dictionary = saves.inspect_revision("quicksave.json")
	var parsed: Dictionary = STRICT.parse_object(disk.value.text)
	if not _check(parsed.get("ok", false), "Settings Quick is strict exact-number JSON"): return
	var admitted: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(parsed.value)
	if not _check(admitted.get("ok", false), "Settings Quick passes the actual Save schema"): return
	var snapshot: Dictionary = admitted.value.candidate.current_snapshot.snapshot
	if not _check(snapshot.narrative_checkpoint == entered.source.checkpoint and snapshot.route_id == "dating"
		and snapshot.active_app_id == desktop_context.active_app_id and desktop_host.capture_persistent_state() == desktop_context
		and snapshot.gameplay.route_context.active_dating_challenge == entered.source.physical_record,
		"Settings Quick stores exact canonical reading and Dating; transient Settings owns no saved route"): return
	var committed_mutations: Array[Dictionary] = mutations.duplicate(true)
	_trace("settings_quick_committed", {"reading": saved, "host": host_after, "disk": after_disk,
		"mutations": committed_mutations})
	await _pause_key()
	if not _check(paused and pause_owner.surface.entered_action == &"" and pause_owner.surface.rows[&"settings"].has_focus(),
		"Settings Back returns to its retained Pause row"): return
	var continued := {}
	pause_owner.coordinator.pause_closed.connect(func() -> void:
		continued.merge(_reading_pause_observation(game), true), CONNECT_ONE_SHOT)
	pause_owner.surface.rows[&"continue"].grab_focus()
	if not await _ordinary_accept_focused(pause_owner.surface.rows[&"continue"], "Settings saved reading Continue"): return
	if not _check(not paused and current_scene == dating and continued == saved and _reading_pause_observation(game) == saved
		and _settings_disk_state() == after_disk and mutations == committed_mutations,
		"Continue retains the full same line and exact persisted files without additional writes"): return
	saves.set("_file_ops", save_ops)
	profile.set("_file_ops", profile_ops)
	var report := {"mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "entered": entered, "hosted": hosted, "saved": saved,
		"continued": continued, "host_before": host_before, "host_after": host_after,
		"disk_before": before_disk, "disk_after": after_disk, "mutations": mutations,
		"saved_checkpoint": snapshot.narrative_checkpoint, "physical_record": entered.source.physical_record,
		"canonical_transcript": entered.source.history.captions, "speech_admissions": _speech_admissions,
		"desktop_context": desktop_context}
	if not _check(_write_text("saved-settings-quick.json", disk.value.text)
		and _write_text("settings-write.json", JSON.stringify(report, "\t")), "retain exact Settings Quick bytes and WRITE proof"): return
	_trace("settings_continue_verified", report)
	print("READING_RAIL_SETTINGS_WRITE_PASS: partial reading -> Pause -> Settings -> physical F5 -> same line, host and focus -> Quick-only mutation -> Continue")
	await _finish_proof()


func _settings_quick_read_process() -> void:
	var prior: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("settings-write.json")))
	if not _check(prior.get("ok", false) and int(prior.value.process_id) != OS.get_process_id(), "Settings restore uses a fresh operating-system process"): return
	var saves: Node = root.get_node("SaveManager")
	var profile: Node = root.get_node("ProfileManager")
	var before_disk := _settings_disk_state()
	var profile_before: Dictionary = profile.get_profile_snapshot()
	if not _check(before_disk == prior.value.disk_after and profile.get_preference(&"preferences.reading.read_aloud_enabled", false),
		"fresh Settings restore has exact Quick/Autosave/Profile bytes and read-aloud enabled"): return
	var prepared: Dictionary = saves.prepare_backup_action("load", "quick")
	if not _check(prepared.get("ok", false), "fresh Settings Quick Load prepares"): return
	_trace("settings_restore_prepared", {"disk": before_disk, "speech_admissions": _speech_admissions})
	var restored: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(restored.get("ok", false), "fresh Settings Quick Load commits"): return
	if not await _wait_line("fixture.solo.pre.a"): return
	var game: Node = root.get_node("GameState")
	var bridge: Node = root.get_node("DialogicBridge")
	var desktop_host: RefCounted = root.get_node("ApplicationBootstrap").get("_desktop_host_state")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	var observed_history: Dictionary = bridge.get_reading_history()
	var observed_physical: Dictionary = game.capture_dating_challenge_state()
	var observed_session: Dictionary = game.capture_live_session()
	var observed_desktop: Dictionary = desktop_host.capture_persistent_state()
	var observed_profile: Dictionary = profile.get_profile_snapshot()
	var observed_disk := _settings_disk_state()
	var observed_complete: bool = bridge.get("_runtime_adapter").is_current_line_complete()
	var checks := {"dating_scene_mounted": current_scene != null and current_scene.get("worksheet") != null,
		"tree_unpaused": not paused, "live_session_active": observed_session.get("value", {}).get("active", false),
		"checkpoint_admitted": checkpoint.get("ok", false),
		"checkpoint_exact": checkpoint.get("value", {}) == prior.value.saved_checkpoint,
		"reading_session_exact": checkpoint.get("value", {}).get("reading_session", {}) == prior.value.saved_checkpoint.reading_session,
		"history_exact": observed_history.get("value", {}) == prior.value.entered.source.history,
		# The owner returns StringName; retained JSON necessarily contains String.
		# Dictionary equality compares Variant types, so compare this exact semantic field.
		"desktop_context_exact": observed_desktop.keys() == ["active_app_id"]
			and prior.value.desktop_context.keys() == ["active_app_id"]
			and str(observed_desktop.active_app_id) == prior.value.desktop_context.active_app_id,
		"physical_record_exact": observed_physical.get("value", {}) == prior.value.physical_record,
		"current_line_complete": observed_complete, "zero_speech_admissions": _speech_admissions == 0,
		"profile_unchanged": observed_profile == profile_before, "disk_unchanged": observed_disk == before_disk}
	var failed: Array[String] = []
	for key: String in checks:
		if checks[key] != true: failed.append(key)
	var observation := {"mode": _reading_mode, "process_id": OS.get_process_id(), "checks": checks,
		"failed_checks": failed, "checkpoint": checkpoint, "history": observed_history,
		"physical_record": observed_physical, "live_session": observed_session, "desktop_context": observed_desktop,
		"profile_before": profile_before, "profile_after": observed_profile, "disk_before": before_disk,
		"disk_after": observed_disk, "speech_admissions": _speech_admissions,
		"current_line_id": str(bridge.get("_runtime_adapter").current_line_id()), "current_line_complete": observed_complete,
		"expected_checkpoint": prior.value.saved_checkpoint, "expected_history": prior.value.entered.source.history,
		"expected_physical_record": prior.value.physical_record, "expected_desktop_context": prior.value.desktop_context,
		"desktop_app_type": typeof(observed_desktop.get("active_app_id")),
		"expected_desktop_app_type": typeof(prior.value.desktop_context.get("active_app_id")),
		"desktop_app_scalar_equal": observed_desktop.get("active_app_id") == prior.value.desktop_context.get("active_app_id")}
	if not _check(_write_text("settings-read-observation.json", JSON.stringify(observation, "\t")),
		"retain per-component Settings restoration observations before acceptance"): return
	if not _check(failed.is_empty(), "fresh Settings Quick restoration invariants: " + ", ".join(failed)): return
	if not await _inspect_history("settings-restored-history", 1): return
	var after_disk := _settings_disk_state()
	if not _check(after_disk == before_disk and _speech_admissions == 0, "restored History is disk- and speech-neutral"): return
	var report := {"mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "saved_checkpoint": checkpoint.value,
		"physical_record": game.capture_dating_challenge_state().value,
		"history": bridge.get_reading_history().value, "canonical_transcript": bridge.get_reading_history().value.captions,
		"desktop_context": desktop_host.capture_persistent_state(),
		"disk_before": before_disk, "disk_after": after_disk, "profile_unchanged": profile.get_profile_snapshot() == profile_before,
		"speech_admissions": _speech_admissions, "history_observations": _history_observations,
		"current_line_complete": bridge.get("_runtime_adapter").is_current_line_complete()}
	if not _check(_write_text("settings-read.json", JSON.stringify(report, "\t")), "retain fresh Settings Quick READ proof"): return
	_trace("settings_restore_verified", report)
	print("READING_RAIL_SETTINGS_READ_PASS: fresh exact Settings Quick Load -> same complete line and History -> zero repeated speech -> unchanged Quick/Autosave/Profile")
	await _finish_proof()



## F9 is a separate process and report: the accepted F5 write/read trace remains sealed.
func _settings_load_host_observation(pause_owner: Node, settings: Control) -> Dictionary:
	var observation := _settings_host_observation(pause_owner, settings)
	var content: Control = settings.get_content_host()
	observation["rail_scroll"] = [content.rail_scroll.scroll_horizontal, content.rail_scroll.scroll_vertical]
	observation["sheet_scroll"] = [content.sheet_scroll.scroll_horizontal, content.sheet_scroll.scroll_vertical]
	return observation


func _settings_load_stage(stage: String, observation: Dictionary, checks: Dictionary) -> bool:
	var failed: Array[String] = []
	for key: String in checks:
		if checks[key] != true: failed.append(key)
	observation["checks"] = checks
	observation["failed_checks"] = failed
	# Persist every component before failing, including modal/focus and disk state.
	if not _check(_write_text("settings-load-" + stage + ".json", JSON.stringify(observation, "\t")),
		"retain Settings F9 " + stage + " observation before assertions"): return false
	_trace("settings_load_" + stage, observation)
	return _check(failed.is_empty(), "Settings F9 " + stage + ": " + ", ".join(failed))


func _settings_load_retain_baseline() -> bool:
	for key: String in ["quick", "autosave", "profile"]:
		var storage: RefCounted = root.get_node("ProfileManager" if key == "profile" else "SaveManager").get("_storage")
		var filename := "quicksave.json" if key == "quick" else key + ".json"
		var source: String = ProjectSettings.globalize_path(storage.describe_root().path_join(filename))
		var bytes := FileAccess.get_file_as_bytes(source)
		if not _check(not bytes.is_empty(), "retain real paused-source bytes for " + key): return false
		var file := FileAccess.open(_evidence_path("settings-load-baseline-" + key + ".json"), FileAccess.WRITE)
		if not _check(file != null, "open retained paused-source file for " + key): return false
		file.store_buffer(bytes)
		file.close()
	return true


func _settings_quick_load_process() -> void:
	var prior: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("settings-write.json")))
	var read_prior: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("settings-read.json")))
	if not _check(prior.get("ok", false) and read_prior.get("ok", false)
		and int(prior.value.process_id) != OS.get_process_id() and int(read_prior.value.process_id) != OS.get_process_id(),
		"Settings F9 follows the retained F5 pair in an independent process"): return
	var saves: Node = root.get_node("SaveManager")
	var profile: Node = root.get_node("ProfileManager")
	var game: Node = root.get_node("GameState")
	var bridge: Node = root.get_node("DialogicBridge")
	var desktop: RefCounted = root.get_node("ApplicationBootstrap").get("_desktop_host_state")
	var input_disk := _settings_disk_state()
	var prepared: Dictionary = saves.prepare_backup_action("load", "quick")
	if not _check(prepared.get("ok", false), "Settings F9 starts with real retained Quick Load"): return
	var restored: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(restored.get("ok", false), "Settings F9 initial Quick Load commits"): return
	if not await _wait_line("fixture.solo.pre.a"): return
	var initial := {"reading": _reading_pause_observation(game), "disk": _settings_disk_state(),
		"speech_admissions": _speech_admissions, "current_line_complete": bridge.get("_runtime_adapter").is_current_line_complete()}
	if not _settings_load_stage("initial", initial, {
		"retained_f5_input": input_disk == prior.value.disk_after,
		"saved_checkpoint_exact": initial.reading.source.checkpoint == prior.value.saved_checkpoint,
		"saved_history_exact": initial.reading.source.history == prior.value.entered.source.history,
		"saved_line_complete": initial.current_line_complete,
		"initial_load_silent": _speech_admissions == 0, "initial_load_disk_neutral": initial.disk == input_disk}): return
	# The saved line is fully visible. A fresh physical Accept uses the actual
	# caption transport to publish the different, partly revealed second line.
	var transport: Dictionary = await _settings_load_advance_and_pause()
	# Pause promptly at the admitted successor, after a released neutral Enter frame.
	var dating: Node = current_scene
	var source_scene_id := dating.get_instance_id()
	var pause_owner: Node = root.get_node("SceneRouter").get("_production_pause")
	var entered := _reading_pause_observation(game)
	var advanced := {"reading": entered, "transport": transport, "scene_id": source_scene_id, "tree_paused": paused,
		"pause_visible": pause_owner.surface.is_visible_in_tree()}
	if not _settings_load_stage("advanced", advanced, {"ordinary_pause_open": advanced.tree_paused and advanced.pause_visible and transport.get("back_admitted", false),
		"different_partial_line": entered.native.line_id == "fixture.solo.pre.b" and entered.native.revealing
			and entered.native.visible_characters >= 0 and entered.native.visible_characters < entered.native.total_characters}): return
	pause_owner.surface.rows[&"settings"].grab_focus()
	if not await _ordinary_accept_focused(pause_owner.surface.rows[&"settings"], "F9 ordinary Settings entry"): return
	var settings: Control = pause_owner.surface.get("_hosts")[&"settings"]
	var content: Control = settings.get_content_host()
	var reading_row: Button = content.get("_rails")["reading"]
	reading_row.grab_focus()
	if not await _ordinary_accept_focused(reading_row, "F9 Reading category"): return
	# Focus a real enabled sheet control without changing its value. Follow-focus
	# supplies its ordinary sheet scroll; preserve both actual scroll positions.
	var origin: OptionButton = content.controls[&"preferences.reading.read_aloud_rate"]
	origin.grab_focus()
	await _frames()
	var before := {"reading": _reading_pause_observation(game), "host": _settings_load_host_observation(pause_owner, settings),
		"disk": _settings_disk_state(), "scene_id": source_scene_id, "desktop_context": desktop.capture_persistent_state()}
	if not _settings_load_retain_baseline(): return
	var mutations: Array[Dictionary] = []
	var save_storage: RefCounted = saves.get("_storage")
	var profile_storage: RefCounted = profile.get("_storage")
	var save_ops: RefCounted = save_storage.get("_file_ops")
	var profile_ops: RefCounted = profile_storage.get("_file_ops")
	save_storage.set("_file_ops", SettingsQuickFileObserver.new(save_ops, "saves", mutations))
	profile_storage.set("_file_ops", SettingsQuickFileObserver.new(profile_ops, "profile", mutations))
	if not _settings_load_stage("entered", before, {"partial_source_preserved": before.reading == entered,
		"different_saved_line": before.reading.source.checkpoint != prior.value.saved_checkpoint,
		"two_history_occurrences": before.reading.source.history.captions.size() == 2,
		"settings_interactive": before.host.visible and before.host.tree_paused and before.host.entered_action == "settings",
		"reading_category": before.host.selected_category == "reading", "exact_enabled_origin": origin.has_focus() and not origin.disabled,
		"suspension_present": not before.host.suspension.is_empty(), "new_line_speech_control": _speech_admissions > 0}): return
	var quick: Node = pause_owner.get("_quick_commands")
	var report := {"mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "input_disk": input_disk, "initial": initial, "advanced": advanced, "before": before}
	for attempt: int in 2:
		dating.get_window().grab_focus()
		await _dating_quick_key(KEY_F9)
		var sheet: Control = quick.get("_confirmation")
		var consent := {"reading": _reading_pause_observation(game), "disk": _settings_disk_state(),
			"scene_id": current_scene.get_instance_id(), "suspension": pause_owner.get("_handle").duplicate(true),
			"cancel_focused": is_instance_valid(sheet) and sheet.cancel_button.has_focus(),
			"confirmation_open": is_instance_valid(sheet) and sheet.is_visible_in_tree(),
			"settings_covered": not settings.is_visible_in_tree(), "tree_paused": paused,
			"pending_token": str(quick.get("_pending_token")), "mutations": mutations.duplicate(true)}
		var stage := "prepared" if attempt == 0 else "reprepared"
		if not _settings_load_stage(stage, consent, {"cancel_first_confirmation": consent.confirmation_open and consent.cancel_focused,
			"bound_quick_candidate": not consent.pending_token.is_empty(), "no_early_restore": consent.reading == before.reading,
			"source_scene_retained": consent.scene_id == source_scene_id,
			"suspension_retained": consent.suspension == before.host.suspension,
			"exclusive_modal": consent.settings_covered and consent.tree_paused,
			"disk_unchanged": consent.disk == before.disk, "zero_mutations": mutations.is_empty()}): return
		report[stage] = consent
		if attempt == 0:
			if not await _ordinary_accept_focused(sheet.cancel_button, "Settings F9 ordinary Cancel"): return
			# Observe after deferred focus/visibility handlers have actually settled.
			await _frames()
			var cancelled := {"reading": _reading_pause_observation(game), "host": _settings_load_host_observation(pause_owner, settings),
				"disk": _settings_disk_state(), "scene_id": current_scene.get_instance_id(),
				"pending_token": str(quick.get("_pending_token")), "confirmation_open": is_instance_valid(quick.get("_confirmation")),
				"mutations": mutations.duplicate(true)}
			if not _settings_load_stage("cancelled", cancelled, {"exact_partial_source": cancelled.reading == before.reading,
				"exact_host_focus_scroll_suspension": cancelled.host == before.host,
				"source_scene_retained": cancelled.scene_id == source_scene_id,
				"consent_retired": cancelled.pending_token.is_empty() and not cancelled.confirmation_open,
				"disk_unchanged": cancelled.disk == before.disk, "zero_mutations": mutations.is_empty()}): return
			report["cancelled"] = cancelled
		else:
			if not _check(consent.pending_token != report.prepared.pending_token, "fresh F9 binds a new one-use consent token"): return
			sheet.confirm_button.grab_focus()
			if not await _ordinary_accept_focused(sheet.confirm_button, "Settings F9 ordinary Confirm Load"): return
	if not await _wait_line("fixture.solo.pre.a"): return
	await _frames()
	var after := {"checkpoint": bridge.capture_reading_checkpoint(false), "history": bridge.get_reading_history(),
		"physical_record": game.capture_dating_challenge_state(), "live_session": game.capture_live_session(),
		"desktop_context": desktop.capture_persistent_state(), "disk": _settings_disk_state(),
		"profile": profile.get_profile_snapshot(), "speech_admissions": _speech_admissions,
		"current_line_complete": bridge.get("_runtime_adapter").is_current_line_complete(),
		"current_line_id": str(bridge.get("_runtime_adapter").current_line_id()), "tree_paused": paused,
		"pause_visible": pause_owner.surface.is_visible_in_tree(),
		"settings_visible": is_instance_valid(settings) and settings.is_visible_in_tree(),
		"suspension": pause_owner.get("_handle").duplicate(true), "scene_id": current_scene.get_instance_id(),
		"load_result": quick.last_result.duplicate(true), "mutations": mutations.duplicate(true)}
	if not _settings_load_stage("confirmed", after, {"load_committed": after.load_result.get("ok", false),
		"saved_checkpoint_exact": after.checkpoint.get("value", {}) == prior.value.saved_checkpoint,
		"saved_history_exact": after.history.get("value", {}) == prior.value.entered.source.history,
		"saved_physical_exact": after.physical_record.get("value", {}) == prior.value.physical_record,
		"saved_app_exact": after.desktop_context.keys() == ["active_app_id"] and str(after.desktop_context.active_app_id) == prior.value.desktop_context.active_app_id,
		"saved_earlier_line_complete": after.current_line_id == "fixture.solo.pre.a" and after.current_line_complete,
		"restored_live_session": after.live_session.get("value", {}).get("active", false),
		"old_pause_settings_closed": not after.tree_paused and not after.pause_visible and not after.settings_visible and after.suspension.is_empty(),
		"restored_scene_mounted": current_scene.get("worksheet") != null and after.scene_id != source_scene_id,
		"no_restored_speech": after.speech_admissions == before.reading.source.speech_admissions,
		"profile_unchanged": after.profile == before.reading.source.profile,
		"disk_unchanged": after.disk == before.disk, "zero_mutations": mutations.is_empty()}): return
	report["after"] = after
	save_storage.set("_file_ops", save_ops)
	profile_storage.set("_file_ops", profile_ops)
	if not _check(_write_text("settings-load.json", JSON.stringify(report, "\t")), "retain independent Settings F9 report"): return
	print("READING_RAIL_SETTINGS_LOAD_PASS: retained Quick -> physical advance -> partial Pause Settings -> physical F9 Cancel exact source -> fresh F9 Confirm saved earlier line -> no Load speech or disk mutation")
	await _finish_proof()


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
	var continued_exactly: bool = not paused and current_scene == dating and not pause_owner.surface.visible \
		and continued == entered and runtime.current_line_id() == entered.native.line_id
	if not continued_exactly:
		_trace("ordinary_pause_continue_failed", {"expected": entered, "release_observation": continued,
			"current_observation": _reading_pause_observation(game), "tree_paused": paused,
			"same_scene": current_scene == dating, "surface_visible": pause_owner.surface.visible,
			"controller_result": pause_owner.last_result, "coordinator_state": pause_owner.coordinator.get_state(),
			"foreground_line_id": runtime.current_line_id()})
	if not _check(continued_exactly, "Continue restores the exact partial native frontier before its next reveal frame"): return false
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
		and not hosted.native.revealing and hosted.native.visible_ratio == 1.0
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
		and runtime.current_line_id() == hosted.native.line_id and runtime.is_current_line_complete()
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
	var semantic: Dictionary = runtime.capture_reading_frontier()
	if not _check(layer != null and checkpoint.get("ok", false) and history.get("ok", false)
		and semantic.get("ok", false) and semantic.value == checkpoint.value.reading_session.frontier,
		"pure reading Pause observation is admitted"): return {}
	var text: DialogicNode_DialogText = layer.caption_text
	# Foreground Skip helpers deliberately return no line while paused. The admitted
	# semantic capture still proves the exact hidden native publication and ledger.
	return {"native": {"line_id": semantic.value.line_id, "caption_id": text.get_instance_id(),
		"reveal_generation": text.get_reveal_generation(), "text": text.get_parsed_text(),
		"visible_characters": text.visible_characters, "total_characters": text.get_total_character_count(),
		"visible_ratio": text.visible_ratio, "revealing": text.revealing},
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
	# The original WRITE/READ captures are sealed before supplemental New Accounts.
	if _reading_mode not in ["write", "read"]: return true
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
	var path: String = _evidence_path("settings-load-transactions.jsonl" if _reading_mode == "settings-load" else "transactions.jsonl")
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
		if _reading_mode == "next":
			var bridge: Node = root.get_node("DialogicBridge")
			var layer: Node = _caption_layer()
			printerr("READING_RAIL_NEXT_STATE: " + JSON.stringify({
				"checkpoint_results": _next_checkpoint_results,
				"checkpoint": bridge.capture_reading_checkpoint(false),
				"runtime_result": bridge.get("_next_runtime_result"),
				"gate": bridge.get("_mutation_gate").guard_external(&"reading_fixture_observation"),
				"recovery": layer.get("_reading_recovery") if is_instance_valid(layer) else {},
				"physical": root.get_node("GameState").capture_dating_challenge_state(),
				"observations": _next_observations}))
		printerr("READING_RAIL_FAIL: " + detail)
		quit(1)
	return value


func _confirm_replacement_new_account() -> void:
	# Only supplemental processes replace an occupied Autosave. Use the real
	# title consent after its source-bound token exists; do not erase files.
	for frame: int in 1800:
		var menu: Node = current_scene
		if menu != null and menu.has_node("%NewAccButton"):
			var confirmation: Variant = menu.get("_confirmation")
			if is_instance_valid(confirmation) and not bool(menu.get("_title_transition")):
				if not _check(_replacement_confirmations == 0 and not str(menu.get("_new_acc_token")).is_empty(),
					"one source-bound New Account replacement confirmation"): return
				_replacement_confirmations += 1
				confirmation.confirm_button.grab_focus()
				await _ordinary_accept_focused(confirmation.confirm_button, "fresh causal run replacement")
				return
		await process_frame
	_check(false, "supplemental New Account never requested its real replacement consent")


func _witness_disk() -> Dictionary:
	var profile: Node = root.get_node("ProfileManager")
	var inspected: Dictionary = profile.get("_storage").inspect_revision("profile.json")
	if not _check(inspected.get("ok", false) and inspected.value.get("exists", false)
		and inspected.value.get("text") is String, "actual Profile bytes have no pending transaction"): return {}
	var text: String = inspected.value.text
	return {"text": text, "sha256": text.sha256_text(), "bytes": text.to_utf8_buffer().size()}


func _witness_session(game: Node, dating: Node) -> void:
	var profile: Node = root.get_node("ProfileManager")
	var bridge: Node = root.get_node("DialogicBridge")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	if not _check(_replacement_confirmations == 1, "fresh causal session used actual replacement consent"): return
	var prior: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("write.json")))
	if not _check(prior.get("ok", false), "sealed original WRITE report remains available"): return
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(checkpoint.get("ok", false), "new causal session owns an admitted exact first line"): return
	var current_id: String = checkpoint.value.reading_session.ledger.session_token
	var prior_id: String = prior.value.saved_checkpoint.reading_session.ledger.session_token
	if not _check(current_id != prior_id, "fresh New Account has a distinct causal semantic session"): return
	var before_profile: Dictionary = profile.get_profile_snapshot()
	var before_disk := _witness_disk()
	if before_disk.is_empty(): return
	var report := {"mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"),
		"catalogue": VARIANT_B_CATALOGUE if _reading_mode == "variant" else READING_CATALOGUE,
		"beat": _witness_beat.duplicate(true), "prior_session_id": prior_id, "current_session_id": current_id,
		"first_line_id": "fixture.solo.pre.a", "profile_before_sha256": before_disk.sha256,
		"witnesses_before": before_profile.witnessed_caption_variants.duplicate(true),
		"seen_before": _reading_mode == "repeat", "replacement_confirmations": _replacement_confirmations}
	if _reading_mode == "repeat":
		if not _check(profile.is_caption_variant_witnessed(_witness_beat)
			and before_profile.witnessed_caption_variants == _witness_initial_profile.witnessed_caption_variants,
			"same exact A remains witnessed despite new run/branch/playback identities"): return
		_trace("witness_repeat_entered", {"session_id": current_id, "beat": _witness_beat,
			"witnesses": before_profile.witnessed_caption_variants})
	else:
		if not _check(_witness_fault != null and int(_witness_fault.get("refusals")) == 1
			and int(_witness_fault.get("matching_writes")) == 1 and not _witness_failure.get("ok", true)
			and not _witness_failure.get("fatal", false) and not profile.get("_mutation_blocked")
			and not profile.is_caption_variant_witnessed(_witness_beat),
			"one real recoverable Profile write refusal grants no B witness"): return
		if not _check(before_disk.text == _witness_fault.get("previous_text")
			and runtime.current_line_id() == "fixture.solo.pre.a"
			and before_profile.witnessed_caption_variants == _witness_initial_profile.witnessed_caption_variants,
			"failed B write rolls back exact Profile bytes and preserves the current publication"): return
		report["write_faults"] = 1
		report["write_failure"] = _witness_failure.duplicate(true)
		report["failed_profile_sha256"] = before_disk.sha256
		_trace("witness_variant_refused", {"failure": _witness_failure, "beat": _witness_beat,
			"profile_sha256": before_disk.sha256, "frontier": checkpoint.value.reading_session.frontier})
		if not await _witness_queries_and_pause_are_neutral(game, dating, before_profile, before_disk.text): return
		report["neutrality_before_retry"] = true
		_trace("witness_neutrality_verified", {"profile_sha256": before_disk.sha256,
			"witnessed": profile.is_caption_variant_witnessed(_witness_beat), "refusals": _witness_fault.get("refusals")})
		if not _check(not runtime.is_current_line_complete(), "fresh Accept retry begins before this long fixture line completes"): return
		if not await _fresh_caption_accept(): return
		if not _check(runtime.current_line_id() == "fixture.solo.pre.a" and runtime.is_current_line_complete()
			and profile.is_caption_variant_witnessed(_witness_beat)
			and int(_witness_fault.get("refusals")) == 1 and int(_witness_fault.get("matching_writes")) == 2,
			"fresh physical Accept retries once, commits B and completes only its current reveal"): return
	var frontier: Dictionary = bridge.capture_current_line_presentation_frontier()
	var disk_before_ack := _witness_disk()
	var acknowledged: Dictionary = bridge.acknowledge_current_line_presentation(frontier)
	if not _check(acknowledged.get("ok", false)
		and acknowledged.receipt.get("was_visited_before_presentation") == (_reading_mode == "repeat")
		and _witness_disk() == disk_before_ack,
		"idempotent actual acknowledgement retains the exact pre-publication seen baseline"): return
	report["acknowledgement_receipt"] = acknowledged.receipt.duplicate(true)
	if _reading_mode == "variant":
		_trace("witness_retry_committed", {"receipt": acknowledged.receipt,
			"profile_sha256": disk_before_ack.sha256, "refusals": _witness_fault.get("refusals")})
		var witnessed_before_history: Dictionary = profile.get_profile_snapshot()
		if not await _inspect_history("variant-history-not-captured", 1): return
		if not _check(profile.get_profile_snapshot() == witnessed_before_history
			and _witness_disk() == disk_before_ack, "History and return grant no extra exact witness or write"): return
		report["history_after_retry_neutral"] = true
	var skip: Dictionary = bridge.request_skip_step()
	if not _check(skip.get("ok", false) and skip.value.get("advance") == (_reading_mode == "repeat"),
		"Read Only uses the retained baseline instead of credit from its own current publication: " + str(skip)): return
	if _reading_mode == "repeat":
		if not await _wait_line("fixture.solo.pre.b"): return
	else:
		if not _check(runtime.current_line_id() == "fixture.solo.pre.a"
			and bridge.capture_reading_checkpoint(false).value == checkpoint.value,
			"first Read Only operation stops on newly witnessed B without semantic advance"): return
	var final_disk := _witness_disk()
	if final_disk.is_empty(): return
	report["skip_result"] = skip.duplicate(true)
	report["resulting_line_id"] = runtime.current_line_id()
	report["seen_after"] = profile.is_caption_variant_witnessed(_witness_beat)
	report["profile_after_sha256"] = final_disk.sha256
	report["witnesses_after"] = profile.get_profile_snapshot().witnessed_caption_variants.duplicate(true)
	if _reading_mode == "variant":
		report["profile_sha256"] = final_disk.sha256
		report["profile_bytes"] = final_disk.bytes
		if not _check(_write_text("witness-profile.json", final_disk.text), "retain exact physical Profile with B witness"): return
	if not _check(_write_text(_reading_mode + ".json", JSON.stringify(report, "\t")), "retain exact witness session report"): return
	_trace("witness_repeat_verified" if _reading_mode == "repeat" else "witness_unseen_stop_verified", report)
	print("READING_RAIL_" + _reading_mode.to_upper() + "_PASS: actual new causal session and exact-variant Profile/Read Only proof")
	await _finish_proof()


func _witness_queries_and_pause_are_neutral(game: Node, dating: Node, profile_before: Dictionary, disk_before: String) -> bool:
	var profile: Node = root.get_node("ProfileManager")
	var bridge: Node = root.get_node("DialogicBridge")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	for query: int in 3:
		bridge.can_skip_current_line()
		bridge.is_current_line_presentation_acknowledged()
		bridge.capture_current_line_presentation_frontier()
		bridge.capture_reading_checkpoint(false)
		bridge.get_reading_history()
	if not _check(profile.get_profile_snapshot() == profile_before and _witness_disk().text == disk_before,
		"capability/checkpoint/History queries never retry or witness B"): return false
	await _pause_key()
	var pause_owner: Node = root.get_node("SceneRouter").get("_production_pause")
	if not _check(paused and pause_owner.surface.is_visible_in_tree(), "plain Pause retains failed-witness source"): return false
	pause_owner.surface.rows[&"backup"].grab_focus()
	await _frames()
	if not _check(pause_owner.surface.entered_action == &"" and profile.get_profile_snapshot() == profile_before
		and _witness_disk().text == disk_before and not profile.is_caption_variant_witnessed(_witness_beat),
		"focus-only Backup preview creates no exact-witness credit"): return false
	pause_owner.surface.rows[&"continue"].grab_focus()
	if not await _ordinary_accept_focused(pause_owner.surface.rows[&"continue"], "failed-witness plain Pause Continue"): return false
	return _check(not paused and current_scene == dating and profile.get_profile_snapshot() == profile_before
		and _witness_disk().text == disk_before and bridge.capture_reading_checkpoint(false).value == checkpoint.value
		and int(_witness_fault.get("matching_writes")) == 1,
		"plain Pause and Continue preserve B's failure, exact source and physical Profile bytes")


func _fresh_caption_accept() -> bool:
	current_scene.get_window().grab_focus()
	await _frames()
	var layer: Node = _caption_layer()
	if not _check(layer != null and layer.caption_text.is_visible_in_tree(), "visible caption owns witness retry"): return false
	layer.caption_text.grab_focus()
	await process_frame
	if not _check(layer.caption_text.has_focus(), "retry begins with current caption Focus"): return false
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await _frames()
	return true


func _witness_read_process() -> void:
	var prior: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("variant.json")))
	if not _check(prior.get("ok", false) and int(prior.value.process_id) != OS.get_process_id(),
		"B witness verification uses a fresh operating-system process"): return
	var profile: Node = root.get_node("ProfileManager")
	var before: Dictionary = profile.get_profile_snapshot()
	var disk := _witness_disk()
	if not _check(not disk.is_empty() and disk.sha256 == prior.value.profile_sha256
		and disk.bytes == prior.value.profile_bytes
		and before.witnessed_caption_variants == prior.value.witnesses_after
		and profile.is_caption_variant_witnessed(_witness_beat),
		"fresh Profile startup independently restores exact durable B membership"): return
	var bridge: Node = root.get_node("DialogicBridge")
	bridge.can_skip_current_line()
	bridge.is_current_line_presentation_acknowledged()
	if not _check(profile.get_profile_snapshot() == before and _witness_disk() == disk,
		"fresh witness inspection changes no Profile bytes"): return
	var report := {"mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "beat": _witness_beat.duplicate(true),
		"witnessed": true, "profile_bytes": disk.bytes, "profile_sha256": disk.sha256,
		"witnesses": before.witnessed_caption_variants.duplicate(true), "profile_unchanged": true}
	if not _check(_write_text("witness-read.json", JSON.stringify(report, "\t")), "retain fresh B witness read report"): return
	_trace("witness_restart_verified", report)
	print("READING_RAIL_WITNESS_READ_PASS: fresh Profile loads exact B witness without publication or mutation")
	quit(0)


func _begin_next_observation() -> void:
	_next_observations = {"observing": true, "text_started": 0, "about_to_show_text": 0,
		"caption_publications": 0, "speech_before": _speech_admissions,
		"exclusive_frames": 0, "exclusive_activations": 0, "intermediate_checkpoint_admissions": 0}
	if _next_observers_installed: return
	_next_observers_installed = true
	var bridge: Node = root.get_node("DialogicBridge")
	var dialogic: Node = root.get_node("Dialogic")
	dialogic.Text.text_started.connect(func(_info: Dictionary) -> void:
		if _next_observations.get("observing", false): _next_observations.text_started += 1)
	dialogic.Text.about_to_show_text.connect(func(_info: Dictionary) -> void:
		if _next_observations.get("observing", false): _next_observations.about_to_show_text += 1)
	bridge.get("_runtime_adapter").caption_publication_recorded.connect(func(_result: Dictionary) -> void:
		if _next_observations.get("observing", false): _next_observations.caption_publications += 1)
	bridge.next_traversal_changed.connect(func() -> void:
		if not _next_observations.get("observing", false) or not bridge.is_next_traversal_active(): return
		_next_observations.exclusive_activations += 1
		var exposed: Dictionary = bridge.capture_reading_checkpoint(false)
		if bridge.can_capture_reading_checkpoint() or exposed.get("ok", false):
			_next_observations.intermediate_checkpoint_admissions += 1)
	process_frame.connect(func() -> void:
		if not _next_observations.get("observing", false) or not bridge.is_next_traversal_active(): return
		_next_observations.exclusive_frames += 1
		if bridge.can_capture_reading_checkpoint(): _next_observations.intermediate_checkpoint_admissions += 1)


func _end_next_observation() -> Dictionary:
	_next_observations.observing = false
	var result := _next_observations.duplicate(true)
	result.erase("observing")
	result["speech_after"] = _speech_admissions
	return result


func _activate_next(detail: String) -> bool:
	var bridge: Node = root.get_node("DialogicBridge")
	var layer: Node = _caption_layer()
	if not _check(layer != null and bridge.can_next_current_line(), detail + " has a real admitted Next source"): return false
	var layer_reference: WeakRef = weakref(layer)
	var button: Button = layer.transport_rail.get_node("Next")
	current_scene.get_window().grab_focus()
	button.grab_focus()
	# Preference and foreground changes retire held input in their own frame.
	# Let that generation boundary settle before supplying a fresh physical press.
	await _frames()
	if not _check(button._admitted(), detail + " has settled fresh physical input admission"): return false
	if not await _ordinary_accept_focused(button, detail): return false
	return await _wait_next_settled(layer_reference, detail)


func _retry_next() -> bool:
	var layer: Node = _caption_layer()
	if not _check(layer != null and layer.is_reading_recovery_active()
		and layer.recovery_overlay.is_presented(), "refused Next exposes its actual Retry owner"): return false
	var layer_reference: WeakRef = weakref(layer)
	var retry: Button = layer.recovery_overlay.retry_button
	retry.grab_focus()
	await _frames()
	if not _check(retry._admitted(), "Next Retry has settled fresh physical input admission"): return false
	if not await _ordinary_accept_focused(retry, "fresh physical Next recovery Retry"): return false
	return await _wait_next_settled(layer_reference, "Next recovery Retry")


func _wait_next_settled(layer_reference: WeakRef, detail: String) -> bool:
	var bridge: Node = root.get_node("DialogicBridge")
	for frame: int in 600:
		# Natural completion removes the source caption layout before this physical
		# input helper resumes. Never pass a freed Node through a typed parameter.
		var layer: Node = layer_reference.get_ref()
		if not bridge.is_next_traversal_active() and (not is_instance_valid(layer) or not bool(layer.get("_next_pending"))):
			await _frames()
			return true
		await process_frame
	return _check(false, detail + " did not release its bounded traversal custody")


func _next_session(game: Node, dating: Node) -> void:
	var bridge: Node = root.get_node("DialogicBridge")
	var profile: Node = root.get_node("ProfileManager")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	var source: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(source.get("ok", false) and runtime.current_line_id() == "fixture.solo.pre.a"
		and not runtime.is_current_line_complete(), "Next starts on the real partial first caption"): return
	var publication: Dictionary = bridge.capture_current_line_presentation_frontier()
	var ack: Dictionary = bridge.acknowledge_current_line_presentation(publication)
	if not _check(ack.get("ok", false)
		and ack.receipt.was_visited_before_presentation == (_reading_mode == "next"),
		"Next retains the exact seen baseline from before visible publication"): return
	var report := {"mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"),
		"source_checkpoint": source.value.duplicate(true), "beat": _witness_beat.duplicate(true),
		"acknowledgement_receipt": ack.receipt.duplicate(true),
		"replacement_confirmations": _replacement_confirmations}
	if _reading_mode == "next-unseen":
		await _next_unseen_session(game, dating, report)
		return
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var real_checkpoint_port: RefCounted = bridge.get("_narrative_checkpoint_port")
	bridge.set("_narrative_checkpoint_port", NextCheckpointObserver.new(real_checkpoint_port, _next_checkpoint_results))
	var layout_probe := LAYOUT_PROBE.new()
	layout_probe.start(self)
	_begin_next_observation()
	if not await _activate_next("witnessed one-shot Next rail activation"): return
	bridge.set("_narrative_checkpoint_port", real_checkpoint_port)
	if not await _wait_for_dating_board(dating): return
	var observations := _end_next_observation()
	if not _check(_next_checkpoint_results.size() == 2
		and _next_checkpoint_results[0].phase == "source" and _next_checkpoint_results[0].result.get("ok", false)
		and _next_checkpoint_results[1].phase == "destination" and _next_checkpoint_results[1].result.get("ok", false),
		"real checkpoint owner commits exactly source then destination before physical completion"): return
	if not _check(_next_is_silent(observations) and observations.exclusive_activations == 1,
		"one witnessed traversal holds exclusive custody and never executes intermediate text, presentation or speech"): return
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	var history: Dictionary = bridge.get_reading_history()
	var physical: Dictionary = game.capture_dating_challenge_state()
	if not _check(checkpoint.get("ok", false) and history.get("ok", false) and physical.get("ok", false)
		and checkpoint.value.reading_session.boundary == "between_entries"
		and checkpoint.value.reading_session.frontier.is_empty()
		and physical.value.phase == "challenge" and not bridge.has_active_playback(),
		"Next reaches the real challenge owner and exact between-entry semantic boundary"): return
	var reading: Dictionary = checkpoint.value.reading_session
	var operation: Dictionary = reading.get("next_operation", {})
	if not _check(reading.schema_version == 2 and operation.get("schema_version") == 1
		and operation.get("phase") == "destination" and operation.get("plan", {}).get("destination") == {"kind": "completion", "caption": null}
		and operation.plan.source_ledger == report.source_checkpoint.reading_session.ledger
		and operation.plan.source_frontier == report.source_checkpoint.reading_session.frontier
		and operation.plan.traversed_captions.size() == 1
		and operation.plan.traversed_captions[0].beat.line_id == "fixture.solo.pre.b"
		and reading.ledger.captions == operation.plan.source_ledger.captions + operation.plan.traversed_captions,
		"durable Next operation binds exact source and one ordered witnessed suffix to challenge completion"): return
	if not _check(history.value.captions.size() == 2
		and history.value.captions[0].line_id == "fixture.solo.pre.a"
		and history.value.captions[1].line_id == "fixture.solo.pre.b"
		and profile.get_profile_snapshot().witnessed_caption_variants == profile_before.witnessed_caption_variants,
		"silently crossed witnessed caption enters canonical History without new Profile credit"): return
	var disk: Dictionary = root.get_node("SaveManager").get("_storage").read_text("autosave.json")
	if not _check(disk.get("ok", false), "Next challenge Autosave exists physically"): return
	var parsed: Dictionary = STRICT.parse_object(disk.value)
	if not _check(parsed.get("ok", false), "Next Autosave is strict JSON"): return
	var snapshot: Dictionary = parsed.value.current_snapshot.snapshot
	if not _check(snapshot.narrative_checkpoint == checkpoint.value
		and snapshot.gameplay.route_context.active_dating_challenge == physical.value,
		"actual challenge Autosave durably contains exact Next History and physical boundary"): return
	if not await _retain_layout_probe(layout_probe, "next"): return
	if not await _capture_next_screen("02-next-board"): return
	if not _check(_write_text("layout-next-minimums.json", JSON.stringify(layout_probe.measure_minimums(), "\t")),
		"retain minimum-size queries after passive observation and screenshot"): return
	report.merge({"checkpoint": checkpoint.value.duplicate(true), "history": history.value.duplicate(true),
		"checkpoint_results": _next_checkpoint_results.duplicate(true),
		"physical_record": physical.value.duplicate(true), "observations": observations,
		"autosave_sha256": str(disk.value).sha256_text(), "autosave_bytes": str(disk.value).to_utf8_buffer().size(),
		"witnesses_before": profile_before.witnessed_caption_variants.duplicate(true),
		"witnesses_after": profile.get_profile_snapshot().witnessed_caption_variants.duplicate(true)}, true)
	if not _check(_write_text("next-autosave.json", disk.value)
		and _write_text("next.json", JSON.stringify(report, "\t")), "retain Next board report and exact Autosave bytes"): return
	_trace("next_challenge_verified", report)
	print("READING_RAIL_NEXT_PASS: physical Next -> silent witnessed traversal -> real challenge -> durable Autosave and ordered History")
	await _finish_next_board_proof()


func _next_unseen_session(game: Node, dating: Node, report: Dictionary) -> void:
	var bridge: Node = root.get_node("DialogicBridge")
	var profile: Node = root.get_node("ProfileManager")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	if not _check(profile.set_preference(&"preferences.reading.auto_enabled", true).get("ok", false),
		"enable real Auto before testing Next arbitration"): return
	var storage: RefCounted = profile.get("_storage")
	var real_ops: RefCounted = storage.get("_file_ops")
	var fault := FailOneAutoOffWrite.new(real_ops)
	storage.set("_file_ops", fault)
	var before_profile: Dictionary = profile.get_profile_snapshot()
	var before_disk := _witness_disk()
	var before_game: Dictionary = game.to_save_dict().duplicate(true)
	_begin_next_observation()
	if not await _activate_next("Next with refused Auto Off"): return
	var refusal_observations := _end_next_observation()
	var refused_checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	var refusal_state := {"refusals": fault.refusals, "matching_writes": fault.matching_writes,
		"profile_unchanged": profile.get_profile_snapshot() == before_profile,
		"disk_unchanged": _witness_disk() == before_disk, "game_unchanged": game.to_save_dict() == before_game,
		"scene_unchanged": current_scene == dating, "checkpoint": refused_checkpoint,
		"checkpoint_unchanged": refused_checkpoint.get("value", {}) == report.source_checkpoint,
		"line_complete": runtime.is_current_line_complete(), "observations": refusal_observations,
		"recovery": _caption_layer().get("_reading_recovery")}
	if not _check(fault.refusals == 1 and fault.matching_writes == 1
		and profile.get_profile_snapshot() == before_profile and _witness_disk() == before_disk
		and game.to_save_dict() == before_game and current_scene == dating
		and refused_checkpoint.get("ok", false) and refused_checkpoint.value == report.source_checkpoint
		and not runtime.is_current_line_complete() and _next_is_silent(refusal_observations),
		"Auto Off refusal starts no traversal and preserves exact durable Profile, game and partial source: "
		+ JSON.stringify(refusal_state)): return
	_trace("next_auto_off_refused", {"profile_sha256": before_disk.sha256, "observations": refusal_observations})
	_begin_next_observation()
	if not await _retry_next(): return
	var observations := _end_next_observation()
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(fault.refusals == 1 and fault.matching_writes == 2
		and not profile.get_preference(&"preferences.reading.auto_enabled", true)
		and runtime.current_line_id() == "fixture.solo.pre.a" and runtime.is_current_line_complete()
		and checkpoint.get("ok", false)
		and checkpoint.value.reading_session.ledger == report.source_checkpoint.reading_session.ledger
		and checkpoint.value.reading_session.frontier == report.source_checkpoint.reading_session.frontier
		and profile.get_profile_snapshot().witnessed_caption_variants == before_profile.witnessed_caption_variants
		and _next_is_silent(observations),
		"fresh one-shot Next durably turns Auto Off, completes only the unseen current line, and grants no extra witness"): return
	storage.set("_file_ops", real_ops)
	var layer: Node = _caption_layer()
	if not _check(layer != null and layer.caption_text.has_focus(), "unseen Next stop returns caption Focus"): return
	if not await _capture_next_screen("01-next-unseen"): return
	if not await _inspect_history("next-unseen-history-not-captured", 1): return
	report.merge({"checkpoint": checkpoint.value.duplicate(true), "observations": observations,
		"refusal_observations": refusal_observations, "auto_off_refusals": fault.refusals,
		"auto_off_matching_writes": fault.matching_writes, "auto_enabled_after": false,
		"refused_profile_sha256": before_disk.sha256, "profile_after_sha256": _witness_disk().sha256,
		"witnesses_before": before_profile.witnessed_caption_variants.duplicate(true),
		"witnesses_after": profile.get_profile_snapshot().witnessed_caption_variants.duplicate(true),
		"current_line_complete": true, "history_observations": _history_observations}, true)
	if not _check(_write_text("next-unseen.json", JSON.stringify(report, "\t")), "retain unseen Next refusal/retry report"): return
	_trace("next_unseen_verified", report)
	print("READING_RAIL_NEXT_UNSEEN_PASS: real Auto Off refusal -> physical retry -> complete current unseen only -> caption Focus and neutral History")
	await _finish_proof()


func _next_is_silent(observations: Dictionary) -> bool:
	return observations.text_started == 0 and observations.about_to_show_text == 0 \
		and observations.caption_publications == 0 and observations.speech_before == observations.speech_after \
		and observations.intermediate_checkpoint_admissions == 0


func _next_read_process() -> void:
	var prior: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("next.json")))
	if not _check(prior.get("ok", false) and int(prior.value.process_id) != OS.get_process_id(),
		"Next board restoration has a distinct operating-system process"): return
	var saves: Node = root.get_node("SaveManager")
	var profile: Node = root.get_node("ProfileManager")
	var before_profile: Dictionary = profile.get_profile_snapshot()
	# Fresh storage has no process-local read lease until the real Load commits.
	# Raw inspection proves the untouched physical bytes without reconciling them.
	var before_disk: Dictionary = saves.get("_storage").inspect_revision("autosave.json")
	if not _check(before_disk.get("ok", false) and before_disk.value.exists
		and typeof(before_disk.value.text) == TYPE_STRING
		and before_disk.value.revision == prior.value.autosave_sha256
		and str(before_disk.value.text).sha256_text() == prior.value.autosave_sha256
		and str(before_disk.value.text).to_utf8_buffer().size() == prior.value.autosave_bytes,
		"fresh Next restore opens exactly the retained physical Autosave"): return
	var before_profile_disk := _witness_disk()
	var layout_probe := LAYOUT_PROBE.new()
	layout_probe.start(self)
	var prepared: Dictionary = saves.prepare_backup_action("load", "autosave")
	if not _check(prepared.get("ok", false), "fresh Next Autosave Load prepares: " + str(prepared)): return
	var restored: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(restored.get("ok", false), "fresh Next Autosave Load commits: " + str(restored)): return
	for frame: int in 600:
		if current_scene != null and current_scene.get("worksheet") != null \
			and current_scene.get("_physical_view").get("phase") == "challenge": break
		await process_frame
	if not _check(current_scene != null and current_scene.get("worksheet") != null, "fresh Next Load remounts real Dating"): return
	if not await _wait_for_dating_board(current_scene): return
	await _frames()
	if not await _retain_layout_probe(layout_probe, "next-read"): return
	var bridge: Node = root.get_node("DialogicBridge")
	var game: Node = root.get_node("GameState")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	var history: Dictionary = bridge.get_reading_history()
	var physical: Dictionary = game.capture_dating_challenge_state()
	if not _check(checkpoint.get("ok", false) and checkpoint.value == prior.value.checkpoint
		and history.get("ok", false) and history.value == prior.value.history
		and physical.get("ok", false) and physical.value == prior.value.physical_record
		and not bridge.has_active_playback() and not bridge.is_next_traversal_active()
		and _speech_admissions == 0 and profile.get_profile_snapshot() == before_profile
		and _witness_disk() == before_profile_disk,
		"fresh Next Load restores exact physical boundary, ordered History and operation without replay or new Profile credit"): return
	var after_disk: Dictionary = saves.get("_storage").read_text("autosave.json")
	if not _check(after_disk.get("ok", false) and after_disk.value == before_disk.value.text,
		"fresh Next Load leaves exact physical Autosave bytes unchanged"): return
	if not await _capture_next_screen("03-next-restored-board"): return
	if not _check(_write_text("layout-next-read-minimums.json", JSON.stringify(layout_probe.measure_minimums(), "\t")),
		"retain cold minimum-size queries after passive observation and screenshot"): return
	var report := {"mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "checkpoint": checkpoint.value.duplicate(true),
		"history": history.value.duplicate(true), "physical_record": physical.value.duplicate(true),
		"autosave_sha256": str(after_disk.value).sha256_text(), "autosave_bytes": str(after_disk.value).to_utf8_buffer().size(),
		"profile_sha256": before_profile_disk.sha256, "profile_bytes": before_profile_disk.bytes,
		"speech_admissions": _speech_admissions, "profile_unchanged": true, "next_active": false}
	if not _check(_write_text("next-read.json", JSON.stringify(report, "\t")), "retain fresh Next board restore report"): return
	_trace("next_restart_verified", report)
	print("READING_RAIL_NEXT_READ_PASS: fresh Autosave Load -> exact challenge and History -> inactive Next and no repeated speech")
	await _finish_next_board_proof()


func _retain_layout_probe(probe: RefCounted, label: String) -> bool:
	for frame: int in 600:
		if probe.is_complete(): break
		await process_frame
	var complete: bool = probe.is_complete()
	probe.stop()
	var report: Dictionary = probe.report()
	report["mode"] = label
	report["process_id"] = OS.get_process_id()
	if not _check(_write_text("layout-" + label + ".json", JSON.stringify(report, "\t")),
		"retain passive challenge layout observations"): return false
	return _check(complete, "observe 120 process frames and draws of the visible challenge")


func _capture_next_screen(label: String) -> bool:
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), "rendered Next screen available"): return false
	var folder: String = _evidence_path("next")
	if not _check(DirAccess.make_dir_recursive_absolute(folder) == OK, "create distinct Next screenshot folder"): return false
	var path: String = folder.path_join(label + ".png")
	if not _check(pixels.save_png(path) == OK, "write Next screenshot " + label): return false
	print("READING_RAIL_NEXT_CAPTURE: " + path)
	return true


func _finish_next_board_proof() -> void:
	var bridge: Node = root.get_node("DialogicBridge")
	if not _check(not bridge.has_active_playback() and not bridge.is_next_traversal_active(),
		"board proof exits without aborting or completing another narrative source"): return
	var speech: Node = root.get_node("SystemTtsCoordinator")
	speech.stop(&"reading_next_fixture_teardown")
	await speech.wait_until_recovered()
	var dialogic: Node = root.get_node("Dialogic")
	for frame: int in 120:
		if dialogic.current_timeline == null and not dialogic.is_ending_timeline(): break
		await process_frame
	if not _check(dialogic.current_timeline == null and not dialogic.is_ending_timeline(),
		"Next source native coroutine is retired before board proof exit"): return
	await _frames()
	quit(0)


## The short second fixture line must be paused while it is actually revealing.
## Observe admission; inject one Enter and one Escape, each with a real release.
## Never stretch the fixture, finish/restart its reveal, or call a transport command.
func _settings_load_advance_and_pause() -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var input_owner: Node = root.get_node("InputManager")
	var pause_owner: Node = root.get_node("SceneRouter").get("_production_pause")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	var layer: Node = _caption_layer()
	var observation := {"packet_type": "InputEventKey", "events": [], "back_admitted": false}
	current_scene.get_window().grab_focus()
	layer.caption_text.grab_focus()
	# Focus and input custody may settle on a deferred frame. The saved A line is
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
	if observation.accept_admitted and observation.source_line == "fixture.solo.pre.a":
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
			if str(frontier.get("line_id", "")) == "fixture.solo.pre.b" \
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
	_check(_write_text("settings-load-input.json", JSON.stringify(observation, "\t")), "retain prompt physical Accept/Back observations")
	return observation
