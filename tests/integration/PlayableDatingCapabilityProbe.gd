extends RefCounted
## GPU startup probe. The caller's only injected fact is owned inventory before Date entry.
## Hidden board reads below select legal test inputs; no board, result, receipt or RNG state is written.
const PERFORMANCE := preload("res://scripts/domain/minesweeper/BoardPerformance.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")
const CANONICAL := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
var _deadline := 0
var _actions := 0
var _started_ms := 0
var _max_action_ms := 0
var _max_dispatch_ms := 0
var _total_action_ms := 0

func run(tree: SceneTree, game: Node, dating: Node, debug_mode: bool) -> void:
	_started_ms = Time.get_ticks_msec()
	# The measured 18x18 run has 51 3BV and synchronous durable actions; keep a finite five-minute cap.
	_deadline = _started_ms + 300000
	if not _check(tree, DisplayServer.get_name() != "headless", "real rendered window required"): return
	dating.get_window().grab_focus()
	while not bool(dating.get("_pre_challenge_reached")) and Time.get_ticks_msec() < _deadline:
		await tree.process_frame
	if not _check(tree, bool(dating.get("_pre_challenge_reached")), "canonical pre-challenge was actually drawn"): return
	if not _check(tree, dating.get("_input_owner") == tree.root.get_node("InputManager")
		and dating.worksheet.grid.get("_input_owner") == tree.root.get_node("InputManager"), "real input owner is composed"): return
	dating.get("_continue_button").pressed.emit()
	if debug_mode:
		await _debug(tree, game, dating)
	else:
		await _marked(tree, game, dating)

func _debug(tree: SceneTree, game: Node, dating: Node) -> void:
	if not _check(tree, _record(game).phase == "preparing", "Continue enters real bounded Debug preparation"): return
	while _record(game).phase == "preparing" and Time.get_ticks_msec() < _deadline:
		if not _check(tree, not bool(dating.get("_preparation_failed")), "Debug pump: " + str(dating.get("_status_label").text)): return
		await tree.process_frame
	var prepared: Dictionary = _record(game)
	if not _check(tree, prepared.phase == "challenge" and prepared.board == null, "Debug reaches a stable unrevealed shell"): return
	if not _check(tree, prepared.spec.width == 18 and prepared.spec.height == 18 and prepared.spec.base_mine_count == 36
		and prepared.spec.capability_ids.has("first_cell_zero") and prepared.spec.capability_ids.has("forced_no_guess"), "registered dimensions and actual Lucky/Debug capability are frozen"): return
	var cells: Array = dating.get("_physical_view").board.cells
	var legal: Array = []
	for cell: Dictionary in cells:
		if cell.actions.has("reveal"): legal.append(cell.index)
		if not _check(tree, cell.actions.has("flag"), "prepared covered cells retain Flag"): return
	var forced: int = int(prepared.envelope.forced_cell)
	if not _check(tree, legal == [forced] and cells[forced].bracketed and cells[forced].actions == ["reveal", "flag"], "only the certified forced cell permits Reveal"): return
	await tree.call("_capture_screen", "14-dating-debug-prepared")
	dating = await _reload(tree, game, prepared)
	if dating == null: return
	await tree.call("_capture_screen", "15-dating-debug-restored")
	if not _check(tree, dating.worksheet.grid.focus_cell(forced), "restored forced cell takes actual board focus"): return
	_press_enter()
	await tree.process_frame
	_release_enter()
	await tree.process_frame
	var revealed: Dictionary = _record(game)
	if not _check(tree, revealed.board is Dictionary and revealed.board.revealed_indices.has(forced)
		and int(revealed.board.adjacency_counts[forced]) == 0, "actual Enter reveals the certified zero cell"): return
	if not _check(tree, revealed.spec == prepared.spec and revealed.envelope.prepared_layout == prepared.envelope.prepared_layout,
		"Load and first Reveal retain the exact prepared fate"): return
	if revealed.board.terminal:
		if not _check(tree, revealed.phase == "post_challenge" and revealed.outcome == "perfect"
			and revealed.relationship_outcome == "foresight" and not bool(dating.get("_physical_view").special_mine_visible), "natural first-Reveal Perfect settles automatically"): return
	await tree.call("_capture_screen", "16-dating-debug-first-reveal")
	print("PLAYABLE_DATING_DEBUG_PASS: real capability -> bounded preparation -> exact full Autosave Load -> actual forced Reveal")
	tree.quit(0)

func _marked(tree: SceneTree, game: Node, dating: Node) -> void:
	if not _check(tree, _record(game).phase == "challenge" and not _record(game).spec.capability_ids.has("forced_no_guess"), "ordinary pre-Reveal shell is available"): return
	if not await _emit(tree, game, dating, "flag", 0): return
	var first: int = int(_record(game).spec.width) * int(_record(game).spec.height) - 1
	if not _check(tree, dating.worksheet.grid.focus_cell(first), "first cell takes actual board focus"): return
	_press_enter()
	await tree.process_frame
	if not _check(tree, _record(game).board is Dictionary, "actual Enter materializes the board after its saved shell flag"): return
	# A one-opening immediate clear has 3BV=1 and at least two real clicks; it is already non-Perfect.
	if _record(game).phase == "challenge":
		_release_enter()
		await tree.process_frame
		var guard: int = _guard_safe(_record(game).board)
		if not _check(tree, guard >= 0, "an unfinished board has a covered safe cell"): return
		if not _record(game).board.flagged_indices.has(guard):
			if not await _emit(tree, game, dating, "flag", guard): return
		var special: int = int(_record(game).envelope.special_cell)
		# First perform the necessary safe Reveals, retaining one flagged safe guard.
		for _iteration in 324:
			var safe: int = _next_safe(_record(game).board, guard)
			if safe < 0: break
			if _record(game).board.flagged_indices.has(safe):
				if not await _emit(tree, game, dating, "unflag", safe): return
			if not await _emit(tree, game, dating, "reveal", safe): return
		if not _check(tree, _record(game).phase == "challenge" and _next_safe(_record(game).board, guard) < 0, "flagged guard is the last safe cell"): return
		# The final guard Unflag and Reveal add two accepted clicks. Add only any deficit.
		var board: Dictionary = _record(game).board
		var remaining_clicks: int = maxi(0, PERFORMANCE.three_bv(board) + 1 - PERFORMANCE.click_count(board) - 2)
		print("DATING_MARKED_INPUT_BUDGET: ", JSON.stringify({"three_bv": PERFORMANCE.three_bv(board),
			"clicks_before_final_guard": PERFORMANCE.click_count(board), "extra_toggles": remaining_clicks,
			"accepted_actions": _actions, "remaining_ms": _deadline - Time.get_ticks_msec()}))
		for _click in remaining_clicks:
			var action: String = "unflag" if _record(game).board.flagged_indices.has(special) else "flag"
			if not await _emit(tree, game, dating, action, special): return
		if not await _emit(tree, game, dating, "unflag", guard): return
		if not _check(tree, dating.worksheet.grid.focus_cell(guard), "last safe cell takes actual focus"): return
		_press_enter()
		await tree.process_frame
	var cleared: Dictionary = _record(game)
	if not _check(tree, cleared.phase == "cleared_awaiting_terminal_choice" and cleared.outcome == "cleared"
		and cleared.perfect_reasons.is_empty(), "real play reaches the non-Perfect choice"): return
	if not _check(tree, not bool(dating.get("_choice_released")) and dating.get("_continue_button").disabled,
		"the clearing key cannot carry into either terminal choice"): return
	_release_enter()
	await tree.process_frame
	await tree.process_frame
	if not _check(tree, bool(dating.get("_choice_released")) and dating.get("_continue_button").has_focus(), "release enables choices and focuses Continue"): return
	var marked: int = int(cleared.envelope.special_cell)
	var public_cell: Dictionary = dating.get("_physical_view").board.cells[marked]
	if not _check(tree, public_cell.actions == ["activate"] and public_cell.mark in ["marked_flag", "marked_mine"], "one actual marked mine is actionable"): return
	await tree.call("_capture_screen", "17-dating-marked-choice")
	if not _check(tree, dating.worksheet.grid.focus_cell(marked), "marked mine takes real keyboard focus"): return
	_press_enter()
	await tree.process_frame
	_release_enter()
	await tree.process_frame
	var terminal: Dictionary = _record(game)
	if not _check(tree, terminal.phase == "post_challenge" and terminal.relationship_outcome == "dark"
		and terminal.applied_result.get("receipt", {}).get("terminal_fact", {}).get("relationship_outcome") == "dark", "actual marked-cell activation applies the exact Dark receipt"): return
	if not await _post_draw(tree, dating): return
	await tree.call("_capture_screen", "18-dating-dark-post")
	dating = await _reload(tree, game, terminal)
	if dating == null or not await _post_draw(tree, dating): return
	var restored: Dictionary = _record(game)
	var profile: Node = tree.root.get_node("ProfileManager")
	var run_id: String = str(game.capture_live_session().value.run_id)
	var attempt: Dictionary = profile.get_dating_attempt(run_id, ATTEMPTS.semantic_slot(restored.context))
	if not _check(tree, attempt.get("ok", false) and attempt.value.get("record", {}).get("relationship_outcome") == "dark", "full Load retains the irreversible canonical Dark attempt"): return
	await tree.call("_capture_screen", "19-dating-dark-restored")
	var prior_day: int = int(game.day)
	dating.get("_continue_button").pressed.emit()
	while Time.get_ticks_msec() < _deadline:
		await tree.process_frame
		if game.day == prior_day + 1 and tree.current_scene.find_child("ComputerDesktop", true, false) != null: break
	if not _check(tree, game.day == prior_day + 1, "real post-scene Continue advances exactly one day"): return
	print("PLAYABLE_DATING_MARKED_PASS: saved shell flag -> legal non-Perfect clear -> release gate -> actual marked cell -> durable Dark -> drawn post scene -> next day")
	tree.quit(0)

func _reload(tree: SceneTree, game: Node, exact: Dictionary) -> Node:
	var session: Dictionary = game.capture_live_session().value
	var source_scene_id: int = tree.current_scene.get_instance_id()
	var source_port: Object = tree.current_scene.get("_presentation_port")
	if not _check(tree, is_instance_valid(source_port), "source Dating presentation owner exists before Load"): return null
	var profile: Node = tree.root.get_node("ProfileManager")
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var saves: Node = tree.root.get_node("SaveManager")
	var prepared: Dictionary = saves.prepare_restore_autosave()
	if not _check(tree, prepared.get("ok", false), "full Autosave Load prepares: " + str(prepared.get("code", ""))): return null
	var mount_events: Array = []
	var mount_signal := {"scene_changed": false}
	var scene_changed_callback: Callable = func() -> void:
		mount_signal.scene_changed = true
		_capture_mount_event(tree, mount_events, "scene_changed")
	var child_entered_callback: Callable = func(child: Node) -> void:
		if child.has_method("is_presentation_configured"):
			_capture_mount_event(tree, mount_events, "child_entered", child)
	tree.scene_changed.connect(scene_changed_callback)
	tree.root.child_entered_tree.connect(child_entered_callback)
	_capture_mount_event(tree, mount_events, "before_commit")
	var committed: Dictionary = saves.commit_prepared_restore(prepared.value.prepared)
	_capture_mount_event(tree, mount_events, "commit_return")
	if not committed.get("ok", false):
		tree.scene_changed.disconnect(scene_changed_callback)
		tree.root.child_entered_tree.disconnect(child_entered_callback)
		_check(tree, false, "full Autosave Load commits: " + str(committed.get("code", "")))
		return null
	var mount_deadline: int = mini(_deadline, Time.get_ticks_msec() + 30000)
	var current: Node = null
	var command: Dictionary = {}
	var mount_diagnostic: Dictionary = {}
	while Time.get_ticks_msec() < mount_deadline:
		await tree.process_frame
		var candidate: Node = tree.current_scene
		var resumed: Dictionary = game.capture_live_session().value
		mount_diagnostic = {"session_active": resumed.get("active", false), "fresh_session": resumed != session,
			"scene": candidate.scene_file_path if is_instance_valid(candidate) else ""}
		if not resumed.get("active", false) or resumed == session or not is_instance_valid(candidate): continue
		if not mount_signal.scene_changed: continue
		if candidate.get_instance_id() == source_scene_id or not candidate.has_method("is_presentation_configured"): continue
		mount_diagnostic["configured"] = candidate.is_presentation_configured()
		if not candidate.is_presentation_configured(): continue
		var port: Object = candidate.get("_presentation_port")
		if not is_instance_valid(port) or port != source_port or not port.has_method("pull_physical"): continue
		var worksheet: Node = candidate.get("worksheet")
		if not is_instance_valid(worksheet) or candidate.get("_input_owner") != tree.root.get_node("InputManager"): continue
		if worksheet.grid.get("_input_owner") != tree.root.get_node("InputManager"): continue
		var admitted: Dictionary = candidate.get_presentation_projection()
		if admitted.is_empty(): continue
		var trusted: Dictionary = port.pull_physical(admitted)
		mount_diagnostic["pull_code"] = str(trusted.get("code", ""))
		if not trusted.get("ok", false): continue
		if candidate.get("_physical_view").get("phase", "") != exact.phase: continue
		current = candidate
		command = admitted
		break
	_capture_mount_event(tree, mount_events, "adopted" if current != null else "mount_timeout")
	tree.scene_changed.disconnect(scene_changed_callback)
	tree.root.child_entered_tree.disconnect(child_entered_callback)
	print("DATING_RESTORE_MOUNT_TRACE: ", JSON.stringify(mount_events))
	if current == null:
		mount_diagnostic["native_scene_changed"] = mount_signal.scene_changed
		var bootstrap: Node = tree.root.get_node("ApplicationBootstrap")
		mount_diagnostic["route"] = tree.root.get_node("SceneRouter").get_current_route_id()
		mount_diagnostic["record_phase"] = _record(game).get("phase", "")
		mount_diagnostic["continuation_pending"] = bootstrap.get("_pending_live_continuation")
		mount_diagnostic["continuation_queued"] = bootstrap.get("_live_continuation_queued")
		var dispatcher: Object = bootstrap.get("_retained_schedule_done_dispatcher")
		if is_instance_valid(dispatcher): mount_diagnostic["dispatch"] = dispatcher.get_last_dispatch_result()
		var router: Node = tree.root.get_node("SceneRouter")
		mount_diagnostic["route_generation"] = router.capture_restore_state().value.backup.route_generation
		mount_diagnostic["route_custody_revision"] = router.get("_route_custody_revision")
		mount_diagnostic["pending_restore_scene_id"] = router.get("_pending_restore_scene_id")
		mount_diagnostic["source_scene_id"] = source_scene_id
		mount_diagnostic["current_scene_id"] = tree.current_scene.get_instance_id() if is_instance_valid(tree.current_scene) else 0
		var coordinator: Object = bootstrap.get("_retained_day_resolution_coordinator")
		if is_instance_valid(coordinator):
			mount_diagnostic["launched_route_generation"] = coordinator.get("_launched_route_generation")
			mount_diagnostic["launched_transaction"] = coordinator.get("_launched_transaction")
			mount_diagnostic["awaiting_transaction"] = coordinator.get("_awaiting").get("transaction_id", "")
		var lifecycle: Dictionary = game._run_lifecycle.to_dict()
		mount_diagnostic["lifecycle_state"] = lifecycle.state
		mount_diagnostic["stages"] = []
		if lifecycle.active_resolution_plan is Dictionary:
			for stage: Dictionary in lifecycle.active_resolution_plan.stages:
				mount_diagnostic.stages.append({"id": stage.stage_id, "state": stage.state})
		mount_diagnostic["dating_mounts"] = []
		for child: Node in tree.root.get_children():
			if child.has_method("is_presentation_configured") and child.has_method("get_presentation_projection"):
				var child_port: Object = child.get("_presentation_port")
				mount_diagnostic.dating_mounts.append({"id": child.get_instance_id(),
					"current": child == tree.current_scene, "configured": child.is_presentation_configured(),
					"retained_port": child_port == source_port,
					"worksheet": is_instance_valid(child.get("worksheet")), "queued_for_deletion": child.is_queued_for_deletion()})
		_check(tree, false, "Load did not mount its configured current-session Dating owner: " + JSON.stringify(mount_diagnostic))
		return null
	# The physical owner explicitly rebinds exactly these four fields to the new admitted command.
	# Its retained port accepted that exact command above; compare every other saved field unchanged.
	var request := command.duplicate(true)
	request.erase("command_sha256")
	request.erase("physical_token")
	var command_hash: Dictionary = CANONICAL.canonical_sha256(request)
	var token_hash: Dictionary = CANONICAL.canonical_sha256(str(command.completion_transaction_id) + "|" + str(command.command_sha256))
	if not _check(tree, command_hash.get("ok", false) and token_hash.get("ok", false)
		and command.command_sha256 == command_hash.value.sha256
		and command.physical_token == "dating_challenge." + str(token_hash.value.sha256), "restored completion, command hash and physical token retain their exact derivation"): return null
	var context_keys: Array = command.context.keys(); context_keys.sort()
	if not _check(tree, context_keys == ["day", "kind", "participants", "schedule_entry_id"]
		and command.context.day == exact.context.day and command.context.kind == exact.context.kind
		and command.context.participants == exact.context.participants
		and ATTEMPTS.semantic_slot(command.context) == ATTEMPTS.semantic_slot(exact.context), "restored command retains the exact same solo Date and participant"): return null
	var expected := exact.duplicate(true)
	for field: String in ["context", "completion_transaction_id", "command_sha256", "physical_token"]:
		expected[field] = command[field].duplicate(true) if command[field] is Dictionary else command[field]
	var before_text: Dictionary = WRITER.stringify(expected)
	var after_text: Dictionary = WRITER.stringify(_record(game))
	if not _check(tree, before_text.get("ok", false) and after_text.get("ok", false) and before_text.value == after_text.value,
		"full Load preserves every physical field with only the exact admitted command rebinding"): return null
	if not _check(tree, profile.get_profile_snapshot() == profile_before, "Load does not alter Profile attempt history"): return null
	current.get_window().grab_focus()
	return current

func _capture_mount_event(tree: SceneTree, events: Array, event: String, entered: Node = null) -> void:
	if events.size() >= 32: return
	var current: Node = tree.current_scene
	var router: Node = tree.root.get_node("SceneRouter")
	var captured: Dictionary = router.capture_restore_state()
	var backup: Dictionary = captured.get("value", {}).get("backup", {})
	var coordinator: Object = tree.root.get_node("ApplicationBootstrap").get("_retained_day_resolution_coordinator")
	var row := {"event": event, "ticks_ms": Time.get_ticks_msec(), "frame": Engine.get_process_frames(),
		"current_id": current.get_instance_id() if is_instance_valid(current) else 0,
		"current_configured": current.is_presentation_configured() if is_instance_valid(current) and current.has_method("is_presentation_configured") else false,
		"route_generation": backup.get("route_generation", -1), "route_custody_revision": router.get("_route_custody_revision")}
	if is_instance_valid(coordinator):
		row["launched_route_generation"] = coordinator.get("_launched_route_generation")
		row["launched_transaction"] = coordinator.get("_launched_transaction")
	if is_instance_valid(entered):
		row["entered_id"] = entered.get_instance_id()
		row["entered_configured"] = entered.is_presentation_configured()
		row["entered_scene"] = entered.scene_file_path
	events.append(row)

func _emit(tree: SceneTree, game: Node, dating: Node, action: String, index: int) -> bool:
	if _actions >= 1024 or Time.get_ticks_msec() >= _deadline:
		print("DATING_INPUT_TIMING: ", JSON.stringify(_input_timing(game, "budget_exhausted")))
		_check(tree, false, "bounded legal input budget")
		return false
	var before: Dictionary = _record(game)
	var action_started: int = Time.get_ticks_msec()
	dating.worksheet.cell_action_requested.emit(StringName(action), index, int(dating.get("_physical_view").board.revision))
	var dispatch_ms: int = Time.get_ticks_msec() - action_started
	await tree.process_frame
	var action_ms: int = Time.get_ticks_msec() - action_started
	_actions += 1
	_total_action_ms += action_ms
	_max_action_ms = maxi(_max_action_ms, action_ms)
	_max_dispatch_ms = maxi(_max_dispatch_ms, dispatch_ms)
	if _actions % 10 == 0:
		var timing: Dictionary = _input_timing(game, "ten_actions")
		timing["last_action"] = action
		timing["last_action_ms"] = action_ms
		timing["last_dispatch_ms"] = dispatch_ms
		print("DATING_INPUT_TIMING: ", JSON.stringify(timing))
	return _check(tree, _record(game) != before and dating.get("_physical_view").phase != "checkpoint_retry",
		"accepted " + action + ": " + str(dating.get("_status_label").text))

func _input_timing(game: Node, boundary: String) -> Dictionary:
	var record: Dictionary = _record(game)
	var row := {"boundary": boundary, "actions": _actions,
		"elapsed_ms": Time.get_ticks_msec() - _started_ms, "total_action_ms": _total_action_ms,
		"max_action_ms": _max_action_ms, "max_dispatch_ms": _max_dispatch_ms,
		"phase": record.get("phase", "")}
	if record.get("board") is Dictionary:
		row["revealed"] = record.board.revealed_indices.size()
		row["click_count"] = PERFORMANCE.click_count(record.board)
		row["three_bv"] = PERFORMANCE.three_bv(record.board)
	return row

func _post_draw(tree: SceneTree, dating: Node) -> bool:
	while not bool(dating.get("_post_challenge_reached")) and Time.get_ticks_msec() < _deadline:
		await tree.process_frame
	return _check(tree, bool(dating.get("_post_challenge_reached")), "canonical post-challenge was actually drawn and reached")

func _guard_safe(board: Dictionary) -> int:
	# A numbered guard cannot split a zero opening while the probe clears the remaining board.
	for index in int(board.width) * int(board.height):
		if not board.mine_indices.has(index) and not board.revealed_indices.has(index) \
				and int(board.adjacency_counts[index]) > 0: return index
	return _next_safe(board, -1)

func _next_safe(board: Dictionary, excluded: int) -> int:
	var numbered: int = -1
	for index in int(board.width) * int(board.height):
		if index == excluded or board.mine_indices.has(index) or board.revealed_indices.has(index): continue
		if int(board.adjacency_counts[index]) == 0: return index
		if numbered < 0: numbered = index
	return numbered

func _record(game: Node) -> Dictionary:
	return game.capture_dating_challenge_state().value.duplicate(true)

func _press_enter() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)

func _release_enter() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = false
	Input.parse_input_event(event)

func _check(tree: SceneTree, condition: bool, detail: String) -> bool:
	if not condition: _release_enter()
	return bool(tree.call("_check", condition, "Dating capability: " + detail))
