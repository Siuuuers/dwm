extends "res://tests/support/DurableSceneEventFixture.gd"
## Non-canon authored marker programme; production startup never registers it.
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const BASE := preload("res://tests/support/ReadingNextFixture.gd")
const ENTRY := BASE.ENTRY
const FIRST := "fixture.next.a"
const SECOND := "fixture.next.b"
const EVENT := "fixture.notice.set"
const PATH := "res://tests/fixtures/dialogic/scene_next_notification.dtl"

static func catalogue() -> Dictionary:
	return {"kind": "solo_reading_catalogue", "schema_version": 1, "entries": [
		{"entry_id": ENTRY, "content_version": 1, "lines": [
			{"beat_id": "fixture.next.beat.a", "line_id": FIRST, "text": "FIRST — a deliberately long partial reveal that remains visible until one Next activation finishes it and commits the registered notification without publishing SECOND.", "revision": "fixture-v1"},
			{"beat_id": "fixture.next.beat.b", "line_id": SECOND, "text": "SECOND — visible only after the next deliberate activation.", "revision": "fixture-v1"}]},
		{"entry_id": "dating.solo.priscilla.day1.post_challenge", "content_version": 1, "lines": [
			{"beat_id": "fixture.next.post", "line_id": "fixture.next.post", "text": "POST", "revision": "fixture-v1"}]}]}

static func markers(fingerprint: String) -> Dictionary:
	return {"kind": "reading_notification_markers", "schema_version": 1, "entries": [
		{"entry_id": ENTRY, "content_version": 1, "catalogue_fingerprint": fingerprint, "marker": {
			"event_id": EVENT, "ordinal": 0, "predecessor": "", "kind": "notification.set",
			"payload": {"notification_id": "fixture.notice", "content_id": "fixture.notice.text", "parameters": {}},
			"after_line_id": FIRST, "before_line_id": SECOND, "label": "scene.marker." + EVENT}}]}

static func configured(document: Dictionary = {}) -> RefCounted:
	var session := SESSION.new()
	var result: Dictionary = session.configure(catalogue() if document.is_empty() else document)
	if not result.ok: return null
	result = session.configure_markers(markers(session.fingerprint))
	return session if result.ok else null

static func started(publish: bool = true) -> RefCounted:
	var session: RefCounted = configured()
	if session == null: return null
	var seed := BASE.snapshot()
	var reading: Dictionary = seed.narrative_checkpoint.reading_session
	if not session.begin(reading.ledger.session_token, ENTRY).ok: return null
	if not session.admit(ENTRY, seed.narrative_checkpoint.frozen_context).ok: return null
	if publish:
		var allocation: Dictionary = session.ledger.allocate_publication(session.command_id, ENTRY)
		if not allocation.ok: return null
		if not session.ledger.publish_line(session.command_id, allocation.value, ENTRY, FIRST).ok: return null
	return session

static func frontier(session: RefCounted) -> Dictionary:
	var tail: Dictionary = session.ledger.snapshot().captions.back()
	return {"line_id": tail.beat.line_id, "publication_id": tail.publication_id}

static func semantic(session: RefCounted) -> Dictionary:
	var seed := BASE.snapshot()
	return {"schema_version": 1, "source": {"run_id": seed.run_id,
		"branch_id": seed.lifecycle.branch_id, "causal_day_instance": "fixture.day.1",
		"scene_occurrence": session.command_id, "entry_id": ENTRY, "content_version": 1},
		"event_id": EVENT, "ordinal": 0, "predecessor": "", "kind": "notification.set",
		"payload": {"notification_id": "fixture.notice", "content_id": "fixture.notice.text", "parameters": {}},
		"command_id": "fixture.marker.command", "issuer_receipt": {"token": "fixture.marker.command"}}

func initialize_with_bridge(bridge: Node) -> Dictionary:
	var made: Dictionary = preload("res://tests/support/TemporaryStorage.gd").create("durable_scene_event")
	if not made.ok: return made
	files = MarkerFileOps.new()
	storage = STORAGE.new(str(made.value).path_join("saves"), files)
	manager = SAVE.new()
	var result: Dictionary = manager.initialize(storage)
	if not result.ok: return result
	gate = GATE.new()
	result = manager.configure_mutation_gate(gate)
	if not result.ok: return result
	game = GAME.new()
	game.reset_game()
	result = game.configure_mutation_gate(gate)
	if not result.ok: return result
	issuer_root = ROOT.new("ab".repeat(32), 1)
	issuer = ISSUER.new()
	result = issuer.configure(issuer_root)
	if not result.ok: return result
	result = game.configure_identity_issuer(issuer)
	if not result.ok: return result
	snapshot = READING.snapshot()
	var acquired: Dictionary = gate.acquire(&"new_run")
	if not acquired.ok: return acquired
	result = game.apply_restore_silent({"snapshot": snapshot})
	if not result.ok: return result
	var session: Dictionary = game.capture_live_session()
	result = game.activate_live_session({"operation_id": "fixture.install",
		"expected_generation": session.value.generation, "owner_id": game.get_instance_id(),
		"run_id": snapshot.run_id})
	if not result.ok: return result
	result = gate.release(&"new_run", acquired.value.token)
	if not result.ok: return result
	result = manager._journal.reset(snapshot.run_id)
	if not result.ok: return result
	view = ViewCapture.new()
	view.view = snapshot.schedule_view.duplicate(true)
	manager._restore_participants = {"schedule_view": view}
	real = MarkerFaultPort.new(manager)
	real.files = files
	result = real.configure_fatal_latch(gate)
	if not result.ok: return result
	context = CONTEXT.new()
	context.route_id_value = "dating"
	context.audio_context_value = snapshot.audio_context.duplicate(true)
	context.content_version_value = snapshot.content_version
	adapter = ADAPTER.new()
	var providers: Dictionary = context.provider_callables()
	providers.snapshot_input = Callable(game, "capture_run_snapshot_input")
	result = adapter.configure(real, providers)
	if not result.ok: return result
	result = game.configure_narrative_checkpoint_port(adapter)
	if not result.ok: return result
	result = game.configure_scene_event_owner(bridge)
	if not result.ok: return result
	result = game.configure_test_scene_event_registry(registry())
	if not result.ok: return result
	port = PORT.new()
	result = port.configure(game, gate, issuer)
	if not result.ok: return result
	result = bridge.configure_mutation_gate(gate)
	if not result.ok: return result
	result = bridge.configure_narrative_checkpoint_port(adapter)
	if not result.ok: return result
	return bridge.configure_scene_event_port(port, Callable(game, "validate_live_session"), Callable(game, "scene_event_context"))

## Failure is armed at the actual disk commit, after production preimage capture.
class MarkerFileOps extends "res://tests/support/FakeFileOps.gd":
	var fail_next_write := false
	var failed_writes := 0
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if fail_next_write:
			fail_next_write = false
			failed_writes += 1
			return {"ok": false, "code": &"injected_failure", "message": "TEST marker write refusal"}
		return super.write_bytes(path, bytes)

class MarkerFaultPort extends "res://scripts/application/run/SaveManagerCheckpointPort.gd":
	var files: RefCounted
	var commits := 0
	var fail_on_commit := 0
	func commit(candidate: Dictionary) -> Dictionary:
		commits += 1
		if commits == fail_on_commit:
			files.fail_next_write = true
		return super.commit(candidate)

## The support script also provides the two locator functions consumed by Bridge.
## Save input never supplies these test-only authored substitutions.
static func get_entry(entry_id: String, locale: String = "") -> Dictionary:
	var result: Dictionary = preload("res://scripts/data/DialogicTimelineCatalog.gd").get_entry(entry_id, locale)
	if result.get("ok", false) and entry_id in [ENTRY, "dating.solo.priscilla.day1.post_challenge"]:
		result.value.path = PATH
		result.value.label = entry_id
	return result

static func get_path_for_id(timeline_id: String) -> Dictionary:
	return preload("res://scripts/data/DialogicTimelineCatalog.gd").get_path_for_id(timeline_id)

class RefuseDestinationCommit extends RefCounted:
	var target: Object
	var commits := 0
	func _init(owner: Object) -> void: target = owner
	func preview_checkpoint_id(run_id: String) -> Dictionary: return target.preview_checkpoint_id(run_id)
	func capture() -> Dictionary: return target.capture()
	func prepare(inputs: Dictionary, kind: StringName, write: Dictionary) -> Dictionary:
		return target.prepare(inputs, kind, write)
	func commit(candidate: Dictionary) -> Dictionary:
		commits += 1
		if commits == 2: return {"ok": false, "code": &"TEST_marker_destination_refused"}
		return target.commit(candidate)
	func rollback(backup: Dictionary) -> Dictionary: return target.rollback(backup)

var _phase_test: Node
var _phase_tree: SceneTree
var _phase_name := ""
var _phase_reports := ""

func _phase_check(ok: bool, detail: String) -> bool:
	_phase_test.assert_true(ok, detail)
	return ok

func _phase_node(name: String) -> Node:
	return _phase_tree.root.get_node(name)

func _phase_frames(count: int = 12) -> void:
	for frame: int in count: await _phase_tree.process_frame

func _phase_wait_frontier(expected: Dictionary) -> bool:
	var bridge: Node = _phase_node("DialogicBridge")
	for frame: int in 480:
		var actual: Dictionary = bridge.capture_reading_checkpoint(false)
		if actual.get("ok", false) and actual.value.reading_session == expected:
			await _phase_frames()
			return true
		await _phase_tree.process_frame
	return _phase_check(false, "restored exact reading cursor did not become available: " + str(expected))

func _phase_save(slot: String) -> bool:
	var saves: Node = _phase_node("SaveManager")
	var prepared: Dictionary = saves.prepare_backup_action("save", slot)
	if not _phase_check(prepared.get("ok", false), "actual Save prepares " + slot + ": " + str(prepared)): return false
	var result: Dictionary = saves.commit_backup_action(prepared.value.token)
	return _phase_check(result.get("ok", false), "actual Save commits " + slot + ": " + str(result))

func _phase_load(slot: String, paused: bool = false) -> bool:
	var saves: Node = _phase_node("SaveManager")
	var owner: Node = _phase_node("SceneRouter").get("_production_pause")
	if paused:
		var pause: Dictionary = await owner.request_pause()
		if not _phase_check(pause.get("ok", false), "real Pause retains source: " + str(pause)): return false
	var prepared: Dictionary = saves.prepare_backup_action("load", slot)
	if not _phase_check(prepared.get("ok", false), "actual Load prepares " + slot + ": " + str(prepared)): return false
	if paused:
		var released: Dictionary = await owner.release_for_backup_load()
		if not _phase_check(released.get("ok", false), "Pause hands source to restore: " + str(released)): return false
	var result: Dictionary = saves.commit_backup_action(prepared.value.token)
	if paused: result = await owner.finish_backup_load(result)
	return _phase_check(result.get("ok", false), "actual Load commits " + slot + ": " + str(result))

func _phase_raw(path: String) -> String:
	var storage: RefCounted = _phase_node("SaveManager").get("_storage")
	return FileAccess.get_file_as_string(storage.describe_root().path_join(path))

func _phase_snapshot(path: String) -> Dictionary:
	var raw := _phase_raw(path)
	if not _phase_check(not raw.is_empty(), "retained physical save exists " + path): return {}
	var parsed: Dictionary = STRICT.parse_object(raw)
	if not _phase_check(parsed.get("ok", false), "strict saved JSON " + path): return {}
	var admitted: Dictionary = DOCUMENT.validate(parsed.value)
	if not _phase_check(admitted.get("ok", false), "actual save schema " + str(admitted)): return {}
	return admitted.value.candidate.current_snapshot.snapshot

func _phase_report(path: String, extra: Dictionary = {}) -> bool:
	var snapshot_value := _phase_snapshot(path)
	if snapshot_value.is_empty(): return false
	var report := {"phase": _phase_name, "process_id": OS.get_process_id(), "path": path,
		"sha256": _phase_raw(path).sha256_text(), "checkpoint": snapshot_value.narrative_checkpoint,
		"receipts": snapshot_value.command_receipts,
		"saved_lifecycle": snapshot_value.lifecycle,
		"profile": _phase_node("ProfileManager").get_profile_snapshot(),
		"live_session": _phase_node("GameState").capture_live_session().value,
		"scope": "real Bootstrap, native disk, SaveManager Backup Load and ordinary process exit"}
	for key: String in extra: report[key] = extra[key]
	if not _phase_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_phase_reports)) == OK, "report directory"): return false
	var file := FileAccess.open(_phase_reports.path_join(_phase_name + ".json"), FileAccess.WRITE)
	if not _phase_check(file != null, "write retained report"): return false
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("SCENE_NEXT_NOTIFICATION_PHASE_PASS: " + _phase_name)
	return true

func _phase_prior(name: String) -> Dictionary:
	var parsed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_phase_reports.path_join(name + ".json")))
	if not _phase_check(parsed.get("ok", false), "prior process report " + name): return {}
	var prior: Dictionary = parsed.value
	if not _phase_check(prior.process_id != OS.get_process_id(), "different operating system process"): return {}
	if not _phase_check(_phase_raw(prior.path).sha256_text() == prior.sha256, "exact producer bytes precede Load"): return {}
	return prior

func _phase_new_run() -> bool:
	_phase_node("SceneRouter").goto_menu()
	await _phase_frames()
	var menu: Node = _phase_tree.current_scene
	if not _phase_check(menu != null and menu.has_node("%NewAccButton"), "actual title mounted"): return false
	var button: Button = menu.get_node("%NewAccButton")
	if not _phase_check(not button.disabled, "New Account enabled"): return false
	button.pressed.emit()
	var desktop: Node
	for frame: int in 1200:
		if _phase_tree.current_scene != null:
			desktop = _phase_tree.current_scene.find_child("ComputerDesktop", true, false)
		if desktop != null and not _phase_node("SaveManager").get("_new_run_busy"): break
		await _phase_tree.process_frame
	if not _phase_check(desktop != null, "actual New Account reached desktop"): return false
	# The production Day1 journey retains its initial board prerequisite. Finish
	# it through actual inputs before scheduling the synthetic Solo presentation.
	var game: Node = _phase_node("GameState")
	if not _phase_check(desktop.open_app(&"minesweeper").get("ok", false), "initial board opens"): return false
	await _phase_frames()
	var app: Node = desktop.get("_cached_app_windows")[&"minesweeper"]
	var panel: Control = app.panel
	var finished_before: int = game.minesweeper_app_rounds_finished_today
	panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
	if not _phase_check(app.last_result.get("ok", false), "initial actual Reveal"): return false
	var physical: Dictionary = _phase_node("ApplicationBootstrap").get("_desktop_board_state").capture().board.board
	if not panel.public_view.board.terminal:
		panel.worksheet.cell_action_requested.emit(&"reveal", int(physical.mine_indices[0]), int(panel.public_view.board.revision))
	for frame: int in 480:
		if game.minesweeper_app_rounds_finished_today > finished_before: break
		await _phase_tree.process_frame
	if not _phase_check(game.minesweeper_app_rounds_finished_today == finished_before + 1, "initial board settled once"): return false
	if not _phase_check(desktop.return_home().get("ok", false), "Home after initial board"): return false
	if not _phase_check(desktop.open_app(&"contacts").get("ok", false), "Contacts opens"): return false
	await _phase_frames()
	var contacts: Node = desktop.get("_cached_app_windows")[&"contacts"]
	contacts.contacts_panel.open_requested.emit("priscilla")
	if not _phase_check(contacts.last_result.get("ok", false), "real invitation accepted"): return false
	if not _phase_check(desktop.return_home().get("ok", false), "Home"): return false
	if not _phase_check(desktop.open_app(&"schedule").get("ok", false), "Schedule opens"): return false
	await _phase_frames()
	var schedule: Node = desktop.get("_cached_app_windows")[&"schedule"]
	schedule.panel.source_requested.emit("solo:priscilla:day1")
	if not _phase_check(schedule.last_result.get("ok", false), "real invitation scheduled"): return false
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _phase_check(done.get("ok", false), "Schedule Done: " + str(done)): return false
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		if not _phase_check(ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss").get("ok", false), "warning dismisses"): return false
	var bridge: Node = _phase_node("DialogicBridge")
	for frame: int in 480:
		if bridge.get("_runtime_adapter").current_line_id() == FIRST:
			await _phase_frames()
			return true
		await _phase_tree.process_frame
	return _phase_check(false, "actual FIRST caption timeout: " + str(bridge.get_state())
		+ " physical=" + str(game.capture_dating_challenge_state()))

func _phase_next(refuse_destination: bool = false) -> Dictionary:
	var bridge: Node = _phase_node("DialogicBridge")
	var frontier: Dictionary = bridge.capture_next_frontier()
	if not _phase_check(frontier.get("ok", false), "admitted Next frontier " + str(frontier)): return frontier
	var adapter: RefCounted = _phase_node("GameState").get("_narrative_checkpoint_port")
	var real_port: Object = adapter.get("_real_port")
	var refused := RefuseDestinationCommit.new(real_port)
	if refuse_destination: adapter.set("_real_port", refused)
	var result: Dictionary = await bridge.request_next(frontier)
	if refuse_destination:
		adapter.set("_real_port", real_port)
		_phase_check(not result.get("ok", false) and refused.commits == 2, "source committed before injected destination refusal: " + str(result))
		_phase_check(not _phase_node("ApplicationBootstrap").get("_application_gate").is_fatal_latched(), "compensated refusal retains retry")
	else:
		_phase_check(result.get("ok", false), "real Next completed " + str(result))
	return result

func run_process_phase(test_owner: Node, phase: String, report_directory: String) -> void:
	_phase_test = test_owner
	_phase_tree = test_owner.get_tree()
	_phase_name = phase
	_phase_reports = report_directory
	var phases := ["produce-pre-marker", "consume-pre-marker-source", "consume-source-marker",
		"consume-marker-source", "consume-marker-source-later", "consume-later-completion", "consume-completion"]
	if not _phase_check((phase in phases or phase in ["fault-install-produce", "fault-install-consume"]) and not report_directory.is_empty(), "explicit controlled process phase and report directory"): return
	if not _phase_check(DisplayServer.get_name() != "headless" and not OS.get_environment("DWM_TEST_ROOT").is_empty(), "isolated rendered process"): return
	await _phase_frames()
	var bootstrap: Node = _phase_node("ApplicationBootstrap")
	if not _phase_check(bootstrap.get_startup_state().get("ready", false), "retained final Bootstrap is ready"): return
	var bridge: Node = _phase_node("DialogicBridge")
	# Use this loaded support script's two static catalogue functions. No saved
	# document may provide executable locator or registration data.
	if not _phase_check(bridge.initialize(get_script()).get("ok", false), "fixture physical locator admitted"): return
	if not _phase_check(bridge.configure_reading_catalogue(catalogue()).get("ok", false), "trusted reading programme"): return
	var trusted: RefCounted = configured()
	if not _phase_check(trusted != null, "trusted marker programme"): return
	if not _phase_check(_phase_node("GameState").configure_test_scene_event_registry(registry()).get("ok", false), "independent event registry"): return
	var marker_result: Dictionary = bridge.configure_test_reading_markers(markers(trusted.fingerprint), bootstrap.get("_desktop_identity_nonce_issuer"))
	if not _phase_check(marker_result.get("ok", false), "real Bootstrap issuer bound " + str(marker_result)): return
	if phase == "fault-install-produce":
		await _phase_fault_install_produce()
		return
	if phase == "produce-pre-marker":
		if not await _phase_new_run(): return
		if not _phase_save("quick") or not _phase_save("slot:1"): return
		var initial := _phase_snapshot("quicksave.json")
		if not _phase_check(not initial.is_empty() and initial.narrative_checkpoint.reading_session.boundary == "line"
			and initial.narrative_checkpoint.reading_session.next_operation == null and _phase_event_count(initial.command_receipts) == 0, "ordinary pre-marker save has no synthetic marker receipt"): return
		_phase_report("quicksave.json")
		await _phase_finish()
		return
	var previous: String = "fault-install-produce" if phase == "fault-install-consume" else phases[phases.find(phase) - 1]
	var prior := _phase_prior(previous)
	if prior.is_empty(): return
	var profile: Dictionary = _phase_node("ProfileManager").get_profile_snapshot().duplicate(true)
	if not _phase_check(profile == prior.profile, "independent process retained exact Profile"): return
	var slot := "quick" if prior.path == "quicksave.json" else "autosave"
	if not await _phase_load(slot): return
	if not await _phase_wait_frontier(prior.checkpoint.reading_session): return
	var game: Node = _phase_node("GameState")
	if not _phase_check(game.capture_run_snapshot_input().command_receipts == prior.receipts, "Load retains immutable event receipts"): return
	# Object IDs/generations are local counters and can numerically repeat in a
	# fresh process. Durable continuation identity, not serialized local handles,
	# proves this Load's new branch; the launcher separately proves distinct PIDs.
	if not _phase_check(game.capture_run_snapshot_input().lifecycle.branch_id != prior.saved_lifecycle.branch_id,
		"fresh Load allocates a distinct durable continuation branch"): return
	if not _phase_check(_phase_node("ProfileManager").get_profile_snapshot() == profile, "Load does not witness a caption"): return
	if phase == "fault-install-consume":
		if not _phase_check(prior.get("fatal", false) and prior.get("live_receipt_adopted", false), "producer recorded post-owner installation failure"): return
		if not _phase_check(prior.checkpoint.reading_session.boundary == "notification"
			and prior.checkpoint.reading_session.ledger.captions.size() == 1, "fresh consumer restores committed marker before SECOND"): return
		if not _phase_check(not bootstrap.get("_application_gate").is_fatal_latched(), "fresh validated restore has current custody"): return
		var native: RefCounted = bridge.get("_runtime_adapter")
		if not _phase_check(native.is_marker_source_held(), "fresh native marker capability is restored"): return
		_phase_report(prior.path, {"recovered_post_owner_install_failure": true})
		await _phase_finish()
		return
	if phase == "consume-marker-source":
		var live: Dictionary = game.capture_live_session().value
		if not await _phase_load("slot:2", true): return
		if not await _phase_wait_frontier(prior.checkpoint.reading_session): return
		if not _phase_check(not game.validate_live_session(live).get("ok", false), "repeated Slot Load remaps live authority"): return
		if not _phase_check(game.capture_run_snapshot_input().command_receipts == prior.receipts
			and _phase_node("ProfileManager").get_profile_snapshot() == profile, "repeated Load preserves receipts and Profile"): return
	if phase in ["consume-pre-marker-source", "consume-marker-source"]:
		var refused: Dictionary = await _phase_next(true)
		if refused.get("ok", true): return
		var source := _phase_snapshot("autosave.json")
		if source.is_empty(): return
		if not _phase_check(source.narrative_checkpoint.reading_session.next_operation.phase == "source", "actual source operation is retained"): return
		if not _phase_check(source.command_receipts == prior.receipts, "failed destination adds no receipt"): return
		if not _phase_check(source.narrative_checkpoint.reading_session.boundary == prior.checkpoint.reading_session.boundary, "failed destination retains source boundary"): return
		_phase_report("autosave.json")
	elif phase in ["consume-source-marker", "consume-marker-source-later"]:
		var result: Dictionary = await _phase_next()
		if not result.get("ok", false): return
		var expected := "notification" if phase == "consume-source-marker" else "line"
		if not _phase_check(result.value.destination == expected, "restored source reaches exact expected stop"): return
		if not _phase_save("quick"): return
		if phase == "consume-source-marker" and not _phase_save("slot:2"): return
		var destination := _phase_snapshot("quicksave.json")
		if destination.is_empty(): return
		if not _phase_check(_phase_event_count(destination.command_receipts) == 1, "exactly one notification receipt across processes"): return
		if phase == "consume-marker-source-later":
			if not _phase_check(destination.command_receipts == prior.receipts, "later-caption Next does not reissue marker"): return
			if not _phase_check(destination.narrative_checkpoint.reading_session.ledger.captions.size() == 2, "FIRST and SECOND each occur once"): return
		else:
			if not _phase_check(destination.narrative_checkpoint.reading_session.ledger.captions.size() == 1, "marker stop remains before SECOND"): return
		_phase_report("quicksave.json")
	elif phase == "consume-later-completion":
		var result: Dictionary = await _phase_next()
		if not result.get("ok", false): return
		if not _phase_check(result.value.destination == "completion", "later caption reaches natural completion"): return
		var completion := _phase_snapshot("autosave.json")
		if completion.is_empty(): return
		if not _phase_check(completion.command_receipts == prior.receipts
			and completion.narrative_checkpoint.reading_session.boundary == "between_entries", "completion retains receipt and semantic stop"): return
		_phase_report("autosave.json")
	else:
		if not _phase_check(prior.checkpoint.reading_session.boundary == "between_entries", "fresh completion cursor"): return
		_phase_report(prior.path)
	await _phase_finish()

func _phase_finish() -> void:
	var bridge: Node = _phase_node("DialogicBridge")
	if not bridge.get("_active_entry").is_empty():
		var stopped: Dictionary = bridge.abort_current_entry(&"scene_marker_phase_teardown")
		if not _phase_check(stopped.get("ok", false), "retire active native phase without saving"): return
	var speech: Node = _phase_node("SystemTtsCoordinator")
	speech.stop(&"scene_marker_phase_teardown")
	await speech.wait_until_recovered()
	for frame: int in 120:
		var runtime: Node = _phase_node("Dialogic")
		if runtime.current_timeline == null and not runtime.is_ending_timeline(): break
		await _phase_tree.process_frame
	await _phase_frames()

func _phase_event_count(receipts: Dictionary) -> int:
	var count := 0
	for receipt: Dictionary in receipts.values():
		if receipt.get("kind") == "scene_event": count += 1
	return count

## Existing owner seam runs after actual disk commitment and immediately before
## live receipt adoption. Change only the native locator: source identity and
## immutable cursor stay valid, so owner adoption succeeds before Bridge install.
func _phase_fault_install_produce() -> void:
	if not await _phase_new_run(): return
	var game: Node = _phase_node("GameState")
	var bridge: Node = _phase_node("DialogicBridge")
	var native: RefCounted = bridge.get("_runtime_adapter")
	var gate: RefCounted = _phase_node("ApplicationBootstrap").get("_application_gate")
	var frontier: Dictionary = bridge.capture_next_frontier()
	if not _phase_check(frontier.get("ok", false), "fault producer owns FIRST frontier"): return
	var hook_calls := {"count": 0}
	game.set("_scene_event_before_adoption", func() -> bool:
		hook_calls.count += 1
		var binding: Dictionary = native.get("_marker_binding").duplicate(true)
		binding.label = "scene.marker.fixture.invalid_install_locator"
		native.set("_marker_binding", binding)
		return true)
	var result: Dictionary = await bridge.request_next(frontier)
	game.set("_scene_event_before_adoption", Callable())
	if not _phase_check(hook_calls.count == 1, "existing post-commit owner seam ran exactly once"): return
	if not _phase_check(not result.get("ok", false) and result.get("code") == &"reading_marker_install_failed",
		"native locator rejection occurs after receipt adoption: " + str(result)): return
	if not _phase_check(gate.is_fatal_latched(), "committed native install failure retains fatal custody"): return
	var committed := _phase_snapshot("autosave.json")
	if committed.is_empty(): return
	var live: Dictionary = game.capture_run_snapshot_input()
	if not _phase_check(_phase_event_count(committed.command_receipts) == 1
		and live.command_receipts == committed.command_receipts, "Run owner adopted exactly the actually saved receipt"): return
	if not _phase_check(committed.narrative_checkpoint.reading_session.boundary == "notification"
		and committed.narrative_checkpoint.reading_session.ledger.captions.size() == 1, "durable marker precedes SECOND"): return
	if not _phase_check(native.current_line_id() != SECOND and native.is_marker_source_held(), "failed install never publishes SECOND"): return
	var raw_before := _phase_raw("autosave.json")
	var bypass: Dictionary = _phase_node("SaveManager").prepare_backup_action("save", "slot:1")
	if not _phase_check(not bypass.get("ok", false), "fatal custody refuses manual Save bypass"): return
	var retried: Dictionary = await bridge.request_next(frontier)
	if not _phase_check(not retried.get("ok", false) and _phase_raw("autosave.json") == raw_before
		and game.capture_run_snapshot_input().command_receipts == live.command_receipts, "fatal retry preserves confirmed bytes and adopted receipts"): return
	_phase_report("autosave.json", {"fatal": true, "live_receipt_adopted": true,
		"failure": result, "hook_calls": hook_calls.count, "second_published": false})
	# No cleanup command crosses fatal custody. GUT exits this isolated process;
	# the consumer reopens these exact native bytes with a pristine runtime.
