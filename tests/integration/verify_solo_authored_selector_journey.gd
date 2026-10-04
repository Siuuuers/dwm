extends "res://tests/integration/verify_playable_startup.gd"
## Two real cloud processes; fixture prose only, production gameplay and storage owners.
const FIXTURE_CATALOG := preload("res://tests/support/SoloAuthoredSelectorTimelineCatalog.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const TRAVERSAL := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const RESTORE := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")
const READING_CATALOGUE := "res://tests/fixtures/dialogic/solo_authored_selector_catalogue.json"
const PRE := "dating.solo.priscilla.day1.pre_challenge"
const POST := "dating.solo.priscilla.day1.post_challenge"
const EXPECTED_LINES := ["fixture.selector.pre.a", "fixture.selector.pre.b", "fixture.selector.post.a", "fixture.selector.post.b"]

var _reading_mode := ""
var _document: Dictionary = {}
var _speech_admissions := 0
var _history_observations := 0
var _trace_sequence := 0
var _next_results: Array[Dictionary] = []
var _checkpoint_results: Array[Dictionary] = []
var _next_observations: Dictionary = {}
var _next_observers_installed := false

## Observe actual writes and receipts without replacing the existing checkpoint owner.
class CheckpointObserver extends RefCounted:
	var target: RefCounted
	var observed: Array[Dictionary]
	var storage: RefCounted
	var folder: String
	func _init(port: RefCounted, results: Array[Dictionary], real_storage: RefCounted, evidence_folder: String) -> void:
		target = port
		observed = results
		storage = real_storage
		folder = evidence_folder
	func commit_reading_next(checkpoint: Dictionary, operation_id: String, phase: String) -> Dictionary:
		var result: Dictionary = target.commit_reading_next(checkpoint, operation_id, phase)
		var receipt := {"checkpoint": checkpoint.duplicate(true), "operation_id": operation_id,
			"phase": phase, "result": result.duplicate(true), "autosave": {}}
		if result.get("ok", false):
			var disk: Dictionary = storage.inspect_revision("autosave.json")
			if disk.get("ok", false) and disk.value.get("exists", false) and disk.value.get("text") is String:
				var text: String = disk.value.text
				var name := "saved-next-" + phase + ".json"
				var file: FileAccess = FileAccess.open(folder.path_join(name), FileAccess.WRITE)
				if file != null:
					file.store_string(text)
					file.close()
					receipt.autosave = {"file": name, "sha256": text.sha256_text(), "bytes": text.to_utf8_buffer().size()}
		observed.append(receipt)
		return result


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solo-authored-selector-mode="):
			_reading_mode = argument.trim_prefix("--solo-authored-selector-mode=")
	if not _check(_reading_mode in ["write", "read"], "explicit physical selector process mode"): return
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty(), "isolated test root required"): return
	if not _check(DisplayServer.get_name() != "headless", "real cloud software rendering required"): return
	await _frames()
	if not _check(root.get_node("ApplicationBootstrap").get_startup_state().get("ready", false), "real bootstrap ready"): return
	var bridge: Node = root.get_node("DialogicBridge")
	if not _check(bridge.initialize(FIXTURE_CATALOG).get("ok", false), "test-only physical locator injection"): return
	var parsed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(READING_CATALOGUE))
	if not _check(parsed.get("ok", false), "strict noncanonical finite catalogue"): return
	_document = parsed.value
	if not _check(bridge.configure_reading_catalogue(_document).get("ok", false), "catalogue-v2 admitted"): return
	bridge.next_request_finished.connect(func(_frontier: Dictionary, result: Dictionary) -> void:
		_next_results.append(result.duplicate(true)))
	var speech: Node = root.get_node("SystemTtsCoordinator")
	speech.speech_admitted.connect(func(_token: int, _source: String) -> void: _speech_admissions += 1)
	var capability: Dictionary = speech.refresh_capability("en")
	if not _check(capability.get("ok", false) and capability.value.get("available", false), "native English speech available"): return
	if _reading_mode == "read":
		await _read_process()
		return
	var preferences: Dictionary = root.get_node("ProfileManager").set_preferences({
		&"preferences.reading.read_aloud_enabled": true,
		&"preferences.reading.reveal_speed": "slow",
		&"preferences.reading.auto_enabled": false})
	if not _check(preferences.get("ok", false), "actual reading preferences commit"): return
	_trace("fixture_registered", {"catalogue": READING_CATALOGUE, "catalogue_schema_version": 2, "production_content": false})
	await super._run()


func _dating_journey(game: Node, desktop: Node) -> void:
	if not _check(game.day == 1, "actual Day 1 run"): return
	if not _check(desktop.open_app(&"contacts").get("ok", false), "real Contacts opens"): return
	await _frames()
	var contacts: Node = desktop.get("_cached_app_windows")[&"contacts"]
	contacts.contacts_panel.open_requested.emit("priscilla")
	if not _check(contacts.last_result.get("ok", false)
		and game.contacts.solo_actions.get("solo:priscilla:day1", {}).get("state") == "ACCEPTED", "actual invitation accepted"): return
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
		if not _check(ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss").get("ok", false), "Schedule warning acknowledged"): return
	if not await _wait_line(EXPECTED_LINES[0]): return
	if not _check(current_scene != null and current_scene.get("worksheet") != null, "real Dating mounted"): return
	var dating: Node = current_scene
	if not _assert_selected_caption(PRE, 0): return
	if not await _advance_line(EXPECTED_LINES[0], EXPECTED_LINES[1]): return
	if not _assert_selected_caption(PRE, 1): return
	if not await _inspect_history("04-pre-history", 2): return
	var bridge: Node = root.get_node("DialogicBridge")
	var pre_history: Dictionary = bridge.get_reading_history().value.duplicate(true)
	var pre_frames: Dictionary = _authoritative_frames(game)
	if not _check(pre_frames.size() == 1 and pre_frames.has(PRE), "post facts are not predicted during pre-prose"): return
	_trace("pre_history", {"history": pre_history, "authoritative_frames": pre_frames})
	if not await _advance_line(EXPECTED_LINES[1], ""): return
	if not await _wait_for_dating_board(dating): return
	dating.worksheet.cell_action_requested.emit(&"reveal", 0, int(dating.get("_physical_view").board.revision))
	var physical: Dictionary = game.capture_dating_challenge_state().value
	if not _check(physical.board is Dictionary and not physical.board.terminal, "first actual Reveal materializes a nonterminal board"): return
	await _capture_screen("05-dating-board")
	# Hidden mine inspection selects an input only. Production owners commit result and attitude.
	dating.worksheet.cell_action_requested.emit(&"reveal", int(physical.board.mine_indices[0]), int(dating.get("_physical_view").board.revision))
	if not await _wait_line(EXPECTED_LINES[2]): return
	physical = game.capture_dating_challenge_state().value
	if not _check(physical.phase == "post_challenge" and physical.board.terminal and physical.outcome == "exploded",
		"committed physical explosion precedes post-prose"): return
	var frames := _authoritative_frames(game)
	var fields: Dictionary = frames[POST].fields
	var attitudes := {"hatred": "hostile", "upset": "upset", "amused": "amused"}
	if not _check(frames.size() == 2 and frames[PRE] == pre_frames[PRE]
		and fields.board_result == "exploded" and fields.tone == "sweet" and fields.tier == "friend"
		and attitudes.has(fields.relationship_outcome) and fields.attitude == attitudes[fields.relationship_outcome]
		and fields.relationship_outcome == physical.relationship_outcome
		and fields.effect_receipt_id == physical.applied_result.receipt.terminal_fact.transaction_id,
		"selected post facts bind actual terminal effect and preserve the immutable pre frame"): return
	if not _assert_selected_caption(POST, 0): return
	var post_history: Dictionary = bridge.get_reading_history().value
	if not _check(post_history.session_id == pre_history.session_id and post_history.captions.size() == 3
		and post_history.captions.slice(0, 2) == pre_history.captions, "one ledger spans actual pre, board and post"): return
	_trace("committed_result_then_post_prose", {"physical_record": physical, "history": post_history, "authoritative_frames": frames})
	var next_proof := await _prove_next(game)
	if next_proof.is_empty(): return
	if not _assert_selected_caption(POST, 1): return
	if not await _inspect_history("06-post-history", 4): return
	var saves: Node = root.get_node("SaveManager")
	var quick: Node = dating.get("_quick_commands")
	dating.get_window().grab_focus()
	await _dating_quick_key(KEY_F5)
	if not _check(quick.last_result.get("ok", false), "physical F5 saves selected post-B: " + str(quick.last_result)): return
	var disk := _quick_disk()
	if disk.is_empty(): return
	var admitted := _admit_quick(disk.text)
	if admitted.is_empty(): return
	var snapshot: Dictionary = admitted.current_snapshot.snapshot
	var reading: Dictionary = snapshot.narrative_checkpoint
	var live: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(live.get("ok", false) and reading == live.value
		and reading.reading_session.ledger.captions.size() == 4 and reading.reading_session.ledger.entry_contexts.size() == 2
		and reading.reading_session.frontier.line_id == EXPECTED_LINES[3]
		and snapshot.gameplay.route_context.dating_frozen_contexts_v1.entries == frames
		and reading.reading_session.ledger.entry_contexts == _authoritative_entry_contexts(game)
		and snapshot.gameplay.route_context.active_dating_challenge == physical, "real Quick retains exact ledger, Next, phase frames and terminal effect"): return
	var profile_disk := _witness_disk()
	if profile_disk.is_empty(): return
	_trace("quick_committed", {"sha256": disk.sha256, "checkpoint": reading, "profile_sha256": profile_disk.sha256})
	await _capture_screen("07-post-save")
	var report := _report(game, reading, disk, profile_disk)
	report["unseen_stop"] = next_proof.unseen_stop
	report["next"] = next_proof.next
	if not _check(_speech_admissions > 0, "writer exercised enabled native speech before restore suppression"): return
	if not _check(_write_text("saved-quick.json", disk.text) and _write_text("saved-profile.json", profile_disk.text)
		and _write_text("write.json", JSON.stringify(report, "\t")), "retain exact writer bytes and report"): return
	print("SOLO_AUTHORED_SELECTOR_WRITE_PASS: actual selected pre -> committed exploded board -> unseen stop -> Next destination -> physical Quick")
	await _finish_proof()


func _prove_next(game: Node) -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var profile: Node = root.get_node("ProfileManager")
	var runtime: RefCounted = bridge.get("_runtime_adapter")
	var source: Dictionary = bridge.capture_reading_checkpoint(false)
	var publication: Dictionary = bridge.capture_current_line_presentation_frontier()
	var ack: Dictionary = bridge.acknowledge_current_line_presentation(publication)
	if not _check(source.get("ok", false) and ack.get("ok", false) and not ack.receipt.was_visited_before_presentation
		and runtime.current_line_id() == EXPECTED_LINES[2] and not runtime.is_current_line_complete(), "initially unseen selected post-A is partial"): return {}
	var native_before := _native_caption()
	var game_before: Dictionary = game.to_save_dict().duplicate(true)
	var witnesses_before: Dictionary = profile.get_profile_snapshot().witnessed_caption_variants.duplicate(true)
	var real_port: RefCounted = bridge.get("_narrative_checkpoint_port")
	bridge.set("_narrative_checkpoint_port", CheckpointObserver.new(real_port, _checkpoint_results, root.get_node("SaveManager").get("_storage"), _evidence_path("")))
	_begin_next_observation()
	if not await _activate_next("first deliberate selected Next"): return {}
	var unseen_observations := _end_next_observation()
	var after: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(_next_results.size() == 1 and _next_results[0].get("ok", false)
		and _next_results[0].get("code") == &"unseen_stop" and _checkpoint_results.is_empty()
		and _next_is_silent(unseen_observations)
		and after.get("ok", false) and after.value == source.value and game.to_save_dict() == game_before
		and runtime.current_line_id() == EXPECTED_LINES[2] and runtime.is_current_line_complete()
		and profile.get_profile_snapshot().witnessed_caption_variants == witnesses_before,
		"first Next completes unseen A without semantic motion or source/destination writes"): return {}
	var unseen := {"result": _next_results[0].duplicate(true), "before_checkpoint": source.value.duplicate(true),
		"after_checkpoint": after.value.duplicate(true), "checkpoint_writes": _checkpoint_results.duplicate(true),
		"native_before": native_before, "native_after": _native_caption(), "acknowledgement_receipt": ack.receipt.duplicate(true),
		"observations": unseen_observations}
	_trace("next_unseen_verified", unseen)
	_begin_next_observation()
	if not await _activate_next("second deliberate selected Next"): return {}
	var next_observations := _end_next_observation()
	bridge.set("_narrative_checkpoint_port", real_port)
	if not await _wait_line(EXPECTED_LINES[3]): return {}
	var destination: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(_next_results.size() == 2 and _next_results[1].get("ok", false)
		and _next_results[1].get("code") == &"next_complete" and _next_results[1].value.destination == "line"
		and _checkpoint_results.size() == 2 and _checkpoint_results[0].phase == "source"
		and _checkpoint_results[1].phase == "destination" and _checkpoint_results[0].result.get("ok", false)
		and _checkpoint_results[1].result.get("ok", false) and destination.get("ok", false), "second Next durably commits source then destination"): return {}
	if not _check(next_observations.text_started == 1 and next_observations.about_to_show_text == 1
		and next_observations.caption_publications == 1 and next_observations.exclusive_activations == 1
		and next_observations.texts == [_native_caption().text]
		and next_observations.publications[0].get("ok", false)
		and next_observations.publications[0].value.get("duplicate", false)
		and next_observations.intermediate_checkpoint_admissions == 0,
		"selected Next publishes only its fresh B destination using the already committed occurrence, with no intermediate capture admission"): return {}
	for receipt: Dictionary in _checkpoint_results:
		if not _check(not receipt.autosave.is_empty(), "retain actual physical Next endpoint bytes"): return {}
		var document := _admit_quick(FileAccess.get_file_as_string(_evidence_path(receipt.autosave.file)))
		if not _check(not document.is_empty() and document.current_snapshot.snapshot.narrative_checkpoint == receipt.checkpoint,
			"actual committed Autosave contains the exact observed Next endpoint"): return {}
	var operation: Dictionary = destination.value.reading_session.next_operation
	if not _check(operation.phase == "destination" and operation.plan.traversed_captions == []
		and operation.plan.destination.kind == "line" and operation.plan.destination.caption.beat.line_id == EXPECTED_LINES[3]
		and operation.plan.source_ledger == source.value.reading_session.ledger
		and operation.plan.source_frontier == source.value.reading_session.frontier
		and _checkpoint_results[0].checkpoint.reading_session.next_operation.operation_id == operation.operation_id
		and _checkpoint_results[1].checkpoint == destination.value
		and not bridge.is_next_traversal_active(), "Next retains exact original source and first unseen B without crossed captions"): return {}
	# The mounted presenter normally acknowledges after custody releases. Explicitly
	# verify idempotence before sealing the Profile that a fresh process must retain.
	var proof: Dictionary = bridge.capture_current_line_presentation_frontier()
	var destination_ack: Dictionary = bridge.acknowledge_current_line_presentation(proof)
	var beat: Dictionary = operation.plan.destination.caption.beat
	if not _check(destination_ack.get("ok", false) and not destination_ack.receipt.was_visited_before_presentation
		and profile.is_caption_variant_witnessed(beat), "visible B acknowledges one exact witness while retaining its false prepublication baseline"): return {}
	var next := {"result": _next_results[1].duplicate(true), "checkpoint_results": _checkpoint_results.duplicate(true),
		"source_ack": ack.receipt.duplicate(true), "destination_ack": destination_ack.receipt.duplicate(true),
		"operation": operation.duplicate(true), "checkpoint": destination.value.duplicate(true), "observations": next_observations}
	_trace("next_destination_verified", next)
	return {"unseen_stop": unseen, "next": next}


func _read_process() -> void:
	var parsed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(_evidence_path("write.json")))
	if not _check(parsed.get("ok", false) and int(parsed.value.process_id) != OS.get_process_id(), "writer report belongs to a distinct OS process"): return
	var expected: Dictionary = parsed.value
	var saves: Node = root.get_node("SaveManager")
	var profile: Node = root.get_node("ProfileManager")
	if not _check(profile.get_preference(&"preferences.reading.read_aloud_enabled", false), "Read Aloud remains enabled across restart"): return
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var profile_disk := _witness_disk()
	var quick_before := _quick_disk()
	if not _check(not profile_disk.is_empty() and not quick_before.is_empty()
		and profile_disk.sha256 == expected.profile_sha256 and profile_disk.bytes == expected.profile_bytes
		and quick_before.sha256 == expected.quick_sha256 and quick_before.bytes == expected.quick_bytes,
		"fresh process opens exact physical writer Quick and Profile bytes"): return
	if not _check(_write_text("read-before-quick.json", quick_before.text)
		and _write_text("read-before-profile.json", profile_disk.text), "retain untouched reader-before physical bytes"): return
	var prepared: Dictionary = saves.prepare_backup_action("load", "quick")
	if not _check(prepared.get("ok", false), "actual fresh Quick Load prepares: " + str(prepared)): return
	_trace("fresh_restore_prepared", {"process_id": OS.get_process_id(), "quick_sha256": quick_before.sha256})
	var restored: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not _check(restored.get("ok", false), "actual coordinated Quick Load commits: " + str(restored)): return
	if not await _wait_line(EXPECTED_LINES[3]): return
	var bridge: Node = root.get_node("DialogicBridge")
	var game: Node = root.get_node("GameState")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(checkpoint.get("ok", false) and current_scene != null and current_scene.get("worksheet") != null
		and game.capture_live_session().value.active and checkpoint.value == expected.saved_checkpoint
		and _authoritative_frames(game) == expected.authoritative_frames
		and _authoritative_entry_contexts(game) == expected.authoritative_entry_contexts
		and game.capture_dating_challenge_state().value == expected.physical_record
		and bridge.get("_runtime_adapter").is_current_line_complete() and not bridge.is_next_traversal_active(),
		"fresh physical Load restores exact selected phase frames, ledger, Next and committed board"): return
	if not _assert_selected_caption(POST, 1): return
	if not _check(bridge.validate_reading_checkpoint(checkpoint.value, expected.authoritative_entry_contexts).get("ok", false)
		and bridge.validate_reading_checkpoint(checkpoint.value, _authoritative_entry_contexts(game)).get("ok", false),
		"restored checkpoint agrees independently with writer and restored Run frame authority"): return
	var admitted := _admit_quick(quick_before.text)
	if admitted.is_empty(): return
	var forgery := _prove_forgery_refused(game, checkpoint.value, admitted.current_snapshot.snapshot, expected.authoritative_entry_contexts)
	if forgery.is_empty(): return
	_trace("forged_checkpoint_refused", forgery)
	if not await _inspect_history("08-restored-history", 4): return
	await _capture_screen("09-restored-line")
	if not _check(profile.get_profile_snapshot() == profile_before and _witness_disk() == profile_disk
		and _quick_disk() == quick_before and _speech_admissions == 0,
		"Load and inspection preserve all exact Profile/Quick bytes and repeat no speech with Read Aloud enabled"): return
	var quick_after := _quick_disk()
	var profile_after := _witness_disk()
	if not _check(_write_text("read-after-quick.json", quick_after.text)
		and _write_text("read-after-profile.json", profile_after.text), "retain unchanged reader-after physical bytes"): return
	var report := _report(game, checkpoint.value, quick_after, profile_after)
	if not _check(report.selected_programmes == expected.selected_programmes
		and report.canonical_transcript == expected.canonical_transcript
		and report.native_caption.label == expected.native_caption.label
		and report.native_caption.line_id == expected.native_caption.line_id
		and report.native_caption.text == expected.native_caption.text
		and report.native_caption.total_characters == expected.native_caption.total_characters
		and report.native_caption.fully_visible and expected.native_caption.fully_visible
		and not report.native_caption.revealing and not expected.native_caption.revealing,
		"fresh selected native label/text and four-caption History match writer exactly"): return
	report["profile_unchanged"] = true
	report["quick_unchanged"] = true
	report["forged_checkpoint"] = forgery
	if not _check(_write_text("read.json", JSON.stringify(report, "\t")), "retain reader report"): return
	_trace("fresh_restore_verified", {"checkpoint": checkpoint.value, "speech_admissions": _speech_admissions})
	print("SOLO_AUTHORED_SELECTOR_READ_PASS: actual fresh Quick Load -> selected post-B and exact History/Next/frames -> forged pre refuses -> no speech replay")
	await _finish_proof()


func _prove_forgery_refused(game: Node, checkpoint: Dictionary, snapshot: Dictionary, writer_frames: Dictionary) -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var live_before: Dictionary = bridge.capture_reading_checkpoint(false)
	var game_before: Dictionary = game.to_save_dict().duplicate(true)
	var profile_before: Dictionary = root.get_node("ProfileManager").get_profile_snapshot()
	var quick_before := _quick_disk()
	var disk_before := _witness_disk()
	var changed := checkpoint.duplicate(true)
	var plan: Dictionary = changed.reading_session.next_operation.plan.duplicate(true)
	var alternate: Dictionary = plan.source_ledger.entry_contexts[PRE].duplicate(true)
	alternate.presentation.fields.tone = "dark"
	plan.source_ledger.entry_contexts[PRE] = alternate
	var resolver := SESSION.new()
	if not _check(resolver.configure(_document).get("ok", false), "pure alternate selector resolver configured"): return {}
	var programme: Dictionary = resolver.entry_program(PRE, alternate)
	if not _check(programme.get("ok", false), "alternate earlier pre programme is internally valid"): return {}
	for row: Dictionary in plan.source_ledger.captions:
		if row.beat.owning_entry_id == PRE:
			for beat: Dictionary in programme.value.beats:
				if beat.line_id == row.beat.line_id: row.beat = beat.duplicate(true)
	var projection: Dictionary = TRAVERSAL.project(plan, "destination")
	if not _check(projection.get("ok", false), "coherent forged Next plan has a regenerated exact operation identity"): return {}
	changed.reading_session = projection.value
	var internal: Dictionary = bridge.validate_reading_checkpoint(changed)
	var writer_refusal: Dictionary = bridge.validate_reading_checkpoint(changed, writer_frames)
	var route_refusal: Dictionary = bridge.validate_reading_checkpoint(changed, _authoritative_entry_contexts(game))
	var forged_snapshot := snapshot.duplicate(true)
	forged_snapshot.narrative_checkpoint = changed.duplicate(true)
	var participant := RESTORE.new(bridge)
	var refused: Dictionary = participant.prepare({"content_version": checkpoint.content_version,
		"narrative_checkpoint": changed, "snapshot": forged_snapshot})
	var live_unchanged: bool = bridge.capture_reading_checkpoint(false) == live_before and game.to_save_dict() == game_before 		and root.get_node("ProfileManager").get_profile_snapshot() == profile_before
	var files_unchanged: bool = _quick_disk() == quick_before and _witness_disk() == disk_before
	if not _check(internal.get("ok", false) and not writer_refusal.get("ok", true) and writer_refusal.get("code") == &"reading_context_invalid"
		and not route_refusal.get("ok", true) and route_refusal.get("code") == &"reading_context_invalid"
		and not refused.get("ok", true) and refused.get("code") == &"invalid_narrative_checkpoint"
		and refused.get("message") == "reading_entry_context_mismatch" and live_unchanged and files_unchanged,
		"coherent alternate earlier prose cannot override independent physical Run frames or mutate live/files"): return {}
	return {"internally_valid": internal, "writer_authority_refusal": writer_refusal, "route_authority_refusal": route_refusal,
		"restore_participant_refusal": refused, "forged_checkpoint": changed, "live_unchanged": live_unchanged,
		"files_unchanged": files_unchanged, "quick_sha256": quick_before.sha256, "profile_sha256": disk_before.sha256}


func _authoritative_frames(game: Node) -> Dictionary:
	return game.route_context.get("dating_frozen_contexts_v1", {}).get("entries", {}).duplicate(true)


func _authoritative_entry_contexts(game: Node) -> Dictionary:
	var physical: Dictionary = game.capture_dating_challenge_state().value
	var result := {}
	var frames := _authoritative_frames(game)
	for entry_id: String in frames:
		var phase := "pre_challenge" if entry_id == PRE else "post_challenge"
		result[entry_id] = {"expected_stage": phase, "playback_id": str(physical.physical_token) + ":" + phase,
			"role": "dating_phase", "transaction_id": str(physical.completion_transaction_id) + ":" + phase,
			"presentation": frames[entry_id].duplicate(true)}
	return result


func _selected_programmes() -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var result := {}
	for entry_id: String in [PRE, POST]:
		var programme: Dictionary = bridge.get("_reading_session").entry_program(entry_id)
		if programme.get("ok", false): result[entry_id] = programme.value.duplicate(true)
	return result


func _assert_selected_caption(entry_id: String, ordinal: int) -> bool:
	var bridge: Node = root.get_node("DialogicBridge")
	var programme: Dictionary = bridge.get("_reading_session").entry_program(entry_id)
	if not _check(programme.get("ok", false), "admitted selected programme"): return false
	var native := _native_caption()
	var history: Dictionary = bridge.get_reading_history()
	return _check(native.label == programme.value.label and native.line_id == programme.value.lines[ordinal].line_id
		and native.text == programme.value.lines[ordinal].text and history.get("ok", false)
		and history.value.captions.back().text == native.text
		and bridge.get("_reading_session").ledger.snapshot().captions.back().beat == programme.value.beats[ordinal],
		"native label, literal caption, semantic descriptor and History use the same selected programme")


func _native_caption() -> Dictionary:
	var bridge: Node = root.get_node("DialogicBridge")
	var layer: Node = _caption_layer()
	var text_node: DialogicNode_DialogText = layer.caption_text
	return {"label": bridge.get("_active_entry").get("label", ""),
		"line_id": bridge.get("_runtime_adapter").current_line_id(), "text": text_node.get_parsed_text(),
		"fully_visible": not text_node.revealing and text_node.visible_ratio == 1.0,
		"revealing": text_node.revealing, "visible_characters": text_node.visible_characters,
		"total_characters": text_node.get_total_character_count(), "visible_ratio": text_node.visible_ratio}


func _quick_disk() -> Dictionary:
	var inspected: Dictionary = root.get_node("SaveManager").get("_storage").inspect_revision("quicksave.json")
	if not _check(inspected.get("ok", false) and inspected.value.get("exists", false)
		and inspected.value.get("text") is String, "physical Quick has no pending transaction"): return {}
	var text: String = inspected.value.text
	return {"text": text, "sha256": text.sha256_text(), "bytes": text.to_utf8_buffer().size()}


func _admit_quick(text: String) -> Dictionary:
	var parsed: Dictionary = STRICT.parse_object(text)
	if not _check(parsed.get("ok", false), "strict exact-number physical Quick"): return {}
	var admitted: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(parsed.value)
	if not _check(admitted.get("ok", false), "physical Quick passes shipped save schema: " + str(admitted.get("code"))): return {}
	return admitted.value.candidate


func _report(game: Node, checkpoint: Dictionary, quick: Dictionary, profile: Dictionary) -> Dictionary:
	return {"schema_version": 1, "mode": _reading_mode, "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "saved_checkpoint": checkpoint.duplicate(true),
		"canonical_transcript": root.get_node("DialogicBridge").get_reading_history().value.captions.duplicate(true),
		"current_line_id": checkpoint.reading_session.frontier.line_id, "current_text": _native_caption().text,
		"physical_record": game.capture_dating_challenge_state().value.duplicate(true),
		"authoritative_frames": _authoritative_frames(game), "authoritative_entry_contexts": _authoritative_entry_contexts(game),
		"selected_programmes": _selected_programmes(), "native_caption": _native_caption(),
		"quick_sha256": quick.sha256, "quick_bytes": quick.bytes, "profile_sha256": profile.sha256, "profile_bytes": profile.bytes,
		"witnesses": root.get_node("ProfileManager").get_profile_snapshot().witnessed_caption_variants.duplicate(true),
		"speech_admissions": _speech_admissions, "history_observations": _history_observations,
		"next_active": root.get_node("DialogicBridge").is_next_traversal_active()}


func _capture_screen(label: String) -> bool:
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), "rendered selector screen available"): return false
	var path := _evidence_path(label + ".png")
	if not _check(pixels.save_png(path) == OK, "retain rendered selector screen " + label): return false
	print("SOLO_AUTHORED_SELECTOR_CAPTURE: " + path)
	return true


func _evidence_path(name: String) -> String:
	var folder := ProjectSettings.globalize_path("user://evidence/solo-authored-selector")
	DirAccess.make_dir_recursive_absolute(folder)
	return folder.path_join(name)


func _check(value: bool, detail: String) -> bool:
	if not value:
		printerr("SOLO_AUTHORED_SELECTOR_FAIL: " + detail)
		quit(1)
	return value


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
		if not bool(layer.get("_history_open")) and not bool(layer.get("_history_pending")) and root.gui_get_focus_owner() == history_button: break
		await process_frame
	if not _check(not bool(layer.get("_history_open")) and not bool(layer.get("_history_pending")) and root.gui_get_focus_owner() == history_button,
		"closing History restores exact rail focus; actual=%s restore_id=%s" % [root.gui_get_focus_owner(), layer.get("_load_focus_restore_id")]): return false
	if not _check(game.to_save_dict() == gameplay and profile.get_profile_snapshot() == profile_before
		and bridge.get_reading_history().value == history.value and _speech_admissions == speech_before,
		"History return preserves exact source without advancement"): return false
	_history_observations += 1
	_trace("history_inspected", {"label": label, "history": history.value})
	return true


func _witness_disk() -> Dictionary:
	var profile: Node = root.get_node("ProfileManager")
	var inspected: Dictionary = profile.get("_storage").inspect_revision("profile.json")
	if not _check(inspected.get("ok", false) and inspected.value.get("exists", false)
		and inspected.value.get("text") is String, "actual Profile bytes have no pending transaction"): return {}
	var text: String = inspected.value.text
	return {"text": text, "sha256": text.sha256_text(), "bytes": text.to_utf8_buffer().size()}


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


func _begin_next_observation() -> void:
	_next_observations = {"observing": true, "text_started": 0, "about_to_show_text": 0,
		"caption_publications": 0, "texts": [], "publications": [], "speech_before": _speech_admissions,
		"exclusive_frames": 0, "exclusive_activations": 0, "intermediate_checkpoint_admissions": 0}
	if _next_observers_installed: return
	_next_observers_installed = true
	var bridge: Node = root.get_node("DialogicBridge")
	var dialogic: Node = root.get_node("Dialogic")
	dialogic.Text.text_started.connect(func(info: Dictionary) -> void:
		if _next_observations.get("observing", false):
			_next_observations.text_started += 1
			_next_observations.texts.append(str(info.text)))
	dialogic.Text.about_to_show_text.connect(func(_info: Dictionary) -> void:
		if _next_observations.get("observing", false): _next_observations.about_to_show_text += 1)
	bridge.get("_runtime_adapter").caption_publication_recorded.connect(func(result: Dictionary) -> void:
		if _next_observations.get("observing", false):
			_next_observations.caption_publications += 1
			_next_observations.publications.append(result.duplicate(true)))
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


func _next_is_silent(observations: Dictionary) -> bool:
	return observations.text_started == 0 and observations.about_to_show_text == 0 \
		and observations.caption_publications == 0 and observations.speech_before == observations.speech_after \
		and observations.intermediate_checkpoint_admissions == 0
