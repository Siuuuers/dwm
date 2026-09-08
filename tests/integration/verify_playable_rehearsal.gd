extends SceneTree
## Isolated actual-player practice journey. The ONLY injected gameplay-history fixture is one
## explicitly labeled prior-ending Profile milestone; date reach and both boards are real.
## Run with --prior-ending-fixture; --render-evidence additionally saves actual GPU frames.
## --probe-date-replay also replays the actually reached Before scene after Practice returns.

const ENTRY := "dating.solo.priscilla.day1.pre_challenge"
var _stage := "startup"
var _failed := false
var _bootstrap: Node
var _game: Node
var _profile: Node
var _router: Node
var _baseline: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, detail: String) -> bool:
	if not condition and not _failed:
		_failed = true
		printerr("PLAYABLE_REHEARSAL_FAIL: " + detail + " " + JSON.stringify(_diagnostics()))
		quit(1)
	return condition

func _diagnostics() -> Dictionary:
	var facts := {"stage": _stage, "paused": paused,
		"scene": current_scene.scene_file_path if current_scene != null else "none"}
	if _game != null:
		facts["day"] = _game.day
		facts["session"] = _game.capture_live_session()
		var captured: Dictionary = _game.capture_dating_challenge_state()
		var date_state: Variant = captured.get("value", {})
		facts["dating_phase"] = date_state.get("phase", "") if date_state is Dictionary else str(captured.get("code", "unavailable"))
	if _router != null: facts["route"] = str(_router.get_current_route_id())
	if _bootstrap != null and _bootstrap.get("_application_gate") != null:
		facts["gate"] = str(_bootstrap.get("_application_gate").get_active_owner())
	return facts

func _frames(count: int = 4) -> void:
	for index: int in count: await process_frame

func _wait_until(predicate: Callable, detail: String, max_frames: int = 600, max_ms: int = 60000) -> bool:
	var deadline := Time.get_ticks_msec() + max_ms
	for frame: int in max_frames:
		if _failed: return false
		if bool(predicate.call()): return true
		if Time.get_ticks_msec() >= deadline: break
		await process_frame
	return _check(false, "Timed out: " + detail)

func _capture_screen(label: String) -> bool:
	if "--render-evidence" not in OS.get_cmdline_user_args(): return true
	if not _check(DisplayServer.get_name() != "headless", "--render-evidence requires a real display driver"): return false
	var observed := {"drawn": false}
	var on_draw := func(): observed.drawn = true
	RenderingServer.frame_post_draw.connect(on_draw, CONNECT_ONE_SHOT)
	var drawn := await _wait_until(func(): return observed.drawn, "rendered frame for " + label, 180, 15000)
	if not drawn:
		if RenderingServer.frame_post_draw.is_connected(on_draw): RenderingServer.frame_post_draw.disconnect(on_draw)
		return false
	var folder := ProjectSettings.globalize_path("user://evidence/practice")
	if not _check(DirAccess.make_dir_recursive_absolute(folder) == OK, "create practice evidence directory"): return false
	var pixels: Image = root.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), "real rendered image for " + label): return false
	var path := folder.path_join(label + ".png")
	if not _check(pixels.save_png(path) == OK, "save rendered screen " + label): return false
	print("PRACTICE_RENDER_CAPTURE: " + path)
	return true

func _desktop() -> Node:
	return current_scene.find_child("ComputerDesktop", true, false) if current_scene != null else null

func _reached_date() -> Dictionary:
	if _profile == null: return {}
	var reached: Dictionary = _profile.get_reached_presentations(ENTRY)
	if not reached.get("ok", false) or reached.value.records.is_empty(): return {}
	return reached.value.records[0].duplicate(true)

func _variables() -> Dictionary:
	var dialogic: Node = root.get_node("Dialogic")
	return (dialogic.current_state_info.get("variables", {}) as Dictionary).duplicate(true)

func _capture_baseline() -> void:
	_baseline = {"run": _game.to_save_dict().duplicate(true),
		"session": _game.capture_live_session().duplicate(true),
		"profile": _profile.get_profile_snapshot().duplicate(true), "variables": _variables()}

func _unchanged(detail: String) -> bool:
	return _check(_game.to_save_dict() == _baseline.run, detail + ": canonical Run unchanged") \
		and _check(_game.capture_live_session() == _baseline.session, detail + ": canonical session unchanged") \
		and _check(_profile.get_profile_snapshot() == _baseline.profile, detail + ": Profile unchanged") \
		and _check(_variables() == _baseline.variables, detail + ": live Dialogic variables unchanged")

func _probe_reached_date_replay(gallery: Node, title: Node, reached: Dictionary) -> bool:
	_stage = "public exact reached-date replay"
	if not _check(DisplayServer.get_name() != "headless", "date replay probe requires actual GPU draw"): return false
	var selected: Button
	for row: Button in gallery.get_node("%EndingTileGrid").get_children():
		if row.get_meta(&"gallery_record_id", "") == reached.signature.entry_id: selected = row
	if not _check(selected != null and selected.is_visible_in_tree(), "actual Gallery contains canonically reached Before scene"): return false
	if not _check(not selected.text.contains("dating.") and not selected.text.contains("signature"), "date picker uses audience-facing title"): return false
	selected.pressed.emit()
	var version := -1
	for index: int in gallery.get("_versions").size():
		if gallery.get("_versions")[index] == reached: version = index
	if not _check(version >= 0, "selected row exposes exact actual reached signature"): return false
	gallery.get("_version_selector").select(version)
	gallery.get("_version_selector").item_selected.emit(version)
	var replay_button: Button = gallery.get_node("%ReplayButton")
	if not _check(not replay_button.disabled, "actual reached date Replay enabled"): return false
	replay_button.pressed.emit()
	var bridge: Node = root.get_node("DialogicBridge")
	if not await _wait_until(func(): return bridge.get("_reached_replay").has("surface"), "real readonly date surface mounts"): return false
	var playback: Dictionary = bridge.get("_reached_replay")
	if not _check(playback.signature == reached.signature and playback.signature_id == reached.signature_id,
		"readonly presentation freezes the exact canonically reached source"): return false
	var token: String = playback.token
	var surface: Node = playback.surface
	if not await _wait_until(func(): return is_instance_valid(surface) and surface.get("_drawn") and not surface.get("_next").disabled,
		"actual renderer draws replay card before Next"): return false
	if not _check(surface.get_presentation_history().size() == 1 and surface.get_presentation_history()[0].receipt.view_token == token,
		"real staging history carries this exact playback token"): return false
	if not _check(surface.get("_current_body").text == preload("res://scripts/ui/DatingScene.gd").reached_presentation_copy(
		reached.signature, str(root.get_node("LocalizationManager").get_locale())).value.body,
		"actual replay uses the canonical date's shared phase copy"): return false
	if not _unchanged("actual date replay displayed"): return false
	if not await _capture_screen("09-exact-reached-date-replay"): return false
	surface.get("_next").pressed.emit()
	if not await _wait_until(func(): return not gallery.get("_replay_owner").is_playing() and not bridge.has_active_playback(),
		"actual Next completes only readonly replay"): return false
	if not _unchanged("date replay completed"): return false
	gallery.get("_return_button").pressed.emit()
	if not await _wait_until(func(): return current_scene == title and not title.get("_gallery_host").visible,
		"public Gallery Return restores title home"): return false
	if not _unchanged("Gallery Return after replay"): return false
	if not await _capture_screen("10-title-after-exact-date-replay"): return false
	print("PLAYABLE_REACHED_DATE_REPLAY_PASS: exact canonical Before signature -> public Gallery Replay -> actual card draw -> Next -> Gallery Return; Run/Profile/Dialogic unchanged.")
	return true

func _seed_explicit_prior_ending_fixture() -> bool:
	if not _check("--prior-ending-fixture" in OS.get_cmdline_user_args(), "explicit --prior-ending-fixture flag is required"): return false
	var isolated_path := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not _check(isolated_path.contains("/.godot/phase2r_tests/"), "fixture is restricted to the isolated phase2r_tests user directory"): return false
	if not _check(not _profile.has_completed_ending() and _profile.get_reached_presentations().value.records.is_empty(),
		"isolated Profile starts without ending or reached-presentation history"): return false
	var gate: Object = _bootstrap.get("_application_gate")
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	if not _check(lease.get("ok", false), "fixture causal lease: " + JSON.stringify(lease)): return false
	var seeded: Dictionary = _profile.record_ending_completion("ending.alone",
		"ending:isolated-practice-prior-ending-fixture:gallery:ending.alone")
	var released: Dictionary = gate.release(&"causal_transaction", lease.value.token)
	if not _check(seeded.get("ok", false) and released.get("ok", false), "explicit prior-ending fixture: " + JSON.stringify(seeded)): return false
	if not _check(_profile.has_completed_ending() and _profile.get_reached_presentations().value.records.is_empty(),
		"milestone fixture creates no reached signature"): return false
	print("PRACTICE_FIXTURE: one prior-ending Profile milestone seeded in isolated storage; this probe does not earn an ending.")
	return true

func _run() -> void:
	await _frames(12)
	_bootstrap = root.get_node_or_null("ApplicationBootstrap")
	_game = root.get_node_or_null("GameState")
	_profile = root.get_node_or_null("ProfileManager")
	_router = root.get_node_or_null("SceneRouter")
	if not _check(_bootstrap != null and _game != null and _profile != null and _router != null, "actual autoload composition exists"): return
	if not await _wait_until(func(): return _bootstrap.get_startup_state().get("ready", false), "actual startup ready"): return
	if not _seed_explicit_prior_ending_fixture(): return
	_router.goto_menu()
	if not await _wait_until(func(): return current_scene != null and current_scene.has_node("%NewAccButton"), "actual title"): return
	if not await _capture_screen("01-title-with-explicit-milestone-fixture"): return
	var new_account: Button = current_scene.get_node("%NewAccButton")
	if not _check(not new_account.disabled, "public New Account enabled"): return
	new_account.pressed.emit()
	if not await _wait_until(func(): return _game.capture_live_session().value.active and _desktop() != null, "New Account activates actual desktop"): return
	var desktop: Node = _desktop()
	_stage = "real Day 1 invitation round"
	var opened: Dictionary = desktop.open_app(&"minesweeper")
	if not _check(opened.get("ok", false), "open actual Minesweeper: " + JSON.stringify(opened)): return
	await _frames()
	var mine_app: Node = desktop.get("_cached_app_windows")[&"minesweeper"]
	var board_panel: Control = mine_app.panel
	if not _check(board_panel.has_valid_presentation(), "actual board presentation ready"): return
	var before_rounds: int = _game.minesweeper_rounds_left
	board_panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(board_panel.public_view.board.revision))
	if not _check(mine_app.last_result.get("ok", false) and _game.minesweeper_rounds_left == before_rounds - 1,
		"public first Reveal creates and charges one actual round: " + JSON.stringify(mine_app.last_result)): return
	if not bool(board_panel.public_view.settled):
		# Only the test reads a real hidden mine to finish the round through public Reveal.
		var actual: Dictionary = _bootstrap.get("_desktop_board_state").capture().board.board
		board_panel.worksheet.cell_action_requested.emit(&"reveal", int(actual.mine_indices[0]), int(board_panel.public_view.board.revision))
	if not _check(mine_app.last_result.get("ok", false) and board_panel.public_view.settled, "actual round is settled"): return
	if not _check(_game.contacts.solo_actions.has("solo:priscilla:day1"), "real round unlocked Priscilla invitation"): return
	if not _check(desktop.return_home().get("ok", false), "Home after round"): return
	opened = desktop.open_app(&"contacts")
	if not _check(opened.get("ok", false), "open actual Contacts"): return
	await _frames()
	var contacts: Node = desktop.get("_cached_app_windows")[&"contacts"]
	contacts.contacts_panel.open_requested.emit("priscilla")
	if not _check(contacts.last_result.get("ok", false) and _game.contacts.solo_actions["solo:priscilla:day1"].state == "ACCEPTED",
		"actual invitation read accepts Priscilla: " + JSON.stringify(contacts.last_result)): return
	if not _check(desktop.return_home().get("ok", false), "Home after Contacts"): return
	opened = desktop.open_app(&"schedule")
	if not _check(opened.get("ok", false), "open actual Schedule"): return
	await _frames()
	var schedule: Node = desktop.get("_cached_app_windows")[&"schedule"]
	schedule.panel.source_requested.emit("solo:priscilla:day1")
	if not _check(schedule.last_result.get("ok", false) and schedule.get("_projection").entries.size() == 1,
		"actual invitation scheduled: " + JSON.stringify(schedule.last_result)): return
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	var admitted := false
	for attempt: int in 8:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "public Schedule Done: " + JSON.stringify(done)): return
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null:
			admitted = true
			break
		var dismissed: Dictionary = ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss")
		if not _check(dismissed.get("ok", false), "explicitly dismiss optional-work warning: " + JSON.stringify(dismissed)): return
	if not _check(admitted, "Schedule finished its bounded warnings"): return
	_stage = "canonical date physically reached"
	if not await _wait_until(func(): return current_scene != null and current_scene.has_method("get_presentation_projection") and current_scene.get("worksheet") != null,
		"actual canonical Dating scene"): return
	var dating: Node = current_scene
	if not _check(dating.get("_input_owner") == root.get_node("InputManager") and dating.worksheet.grid.get("_input_owner") == root.get_node("InputManager"),
		"actual canonical Dating input service is composed"): return
	# No draw signal or reached-record writer is called by this test. Real rendering earns it.
	if not await _wait_until(func(): return not _reached_date().is_empty(), "actual pre-challenge draw records its exact reached presentation"): return
	var reached: Dictionary = _reached_date()
	if not _check(reached.signature.entry_id == ENTRY and bool(dating.get("_pre_challenge_reached")), "canonical draw and recorded signature agree"): return
	if not await _capture_screen("02-canonical-date-reached"): return
	dating.get("_continue_button").pressed.emit()
	if not _check(dating.get("_physical_view").phase == "challenge", "actual Continue starts canonical challenge"): return
	dating.worksheet.cell_action_requested.emit(&"reveal", 0, int(dating.get("_physical_view").board.revision))
	if not _check(_game.capture_dating_challenge_state().value.board != null, "actual canonical first Reveal creates board"): return
	if not await _wait_until(func(): return not dating.get("_dispatching") and not _bootstrap.get("_application_gate").is_active(), "idle canonical board before Pause"): return
	await _frames()
	if not await _capture_screen("03-canonical-board-before-pause"): return
	_stage = "public Pause Return"
	var pause_controller: Node = _router.get("_production_pause")
	if not _check(pause_controller != null, "production Pause controller composed"): return
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = false
	Input.parse_input_event(event)
	if not await _wait_until(func(): return paused and pause_controller.surface.is_visible_in_tree(), "real ui_cancel opens Pause"): return
	pause_controller.surface.rows[&"return"].pressed.emit()
	if not _check(pause_controller.surface.confirmation.visible, "public Return confirmation visible"): return
	if not await _capture_screen("04-confirm-return-from-canonical-date"): return
	pause_controller.surface.return_button.pressed.emit()
	if not await _wait_until(func(): return not paused and current_scene != null and current_scene.has_node("%NewAccButton"), "confirmed Return reaches title"): return
	if not _check(not _game.capture_live_session().value.active, "Return retires canonical live session"): return
	await _frames()
	_capture_baseline()
	var title: Node = current_scene
	_stage = "public Gallery practice picker"
	title.get_node("%GalleryButton").pressed.emit()
	if not await _wait_until(func(): return title.get("_gallery_instance") != null and title.get("_gallery_instance").is_visible_in_tree(), "actual Gallery opens"): return
	var gallery: Node = title.get("_gallery_instance")
	if not _check(gallery.get("_practice_button") != null and gallery.get("_practice_button").is_visible_in_tree()
		and not gallery.get("_practice_button").disabled, "milestone-gated actual Practice enabled"): return
	gallery.get("_practice_button").pressed.emit()
	if not await _wait_until(func(): return gallery.get("_practice_host") != null, "actual Practice picker mounts"): return
	var practice: Node = gallery.get("_practice_host")
	var selected_index := -1
	for index: int in practice.get("_records").size():
		if practice.get("_records")[index] == reached: selected_index = index
	if not _check(selected_index >= 0, "picker contains only the exact physically reached date version"): return
	practice.get("_dates").select(selected_index)
	practice.get("_dates").item_selected.emit(selected_index)
	if not _unchanged("picker"): return
	if not await _capture_screen("05-practice-exact-reached-picker"): return
	practice.get("_start").pressed.emit()
	if not await _wait_until(func(): return practice.get("_dating") != null, "actual Practice Dating scene mounts"): return
	var practice_scene: Node = practice.get("_dating")
	var sandbox: Object = practice.get("_sandbox")
	var command: Dictionary = practice.get("_command").duplicate(true)
	if not _check(command.execution_mode == "rehearsal" and sandbox.capture_presentation(command).value.signature == reached.signature,
		"sandbox starts exact reached presentation"): return
	if not _check(practice_scene.get("_input_owner") == root.get_node("InputManager")
		and practice_scene.worksheet.grid.get("_input_owner") == root.get_node("InputManager"), "actual Practice board input service is composed"): return
	practice_scene.get("_continue_button").pressed.emit()
	if not _check(practice_scene.get("_physical_view").phase == "challenge", "public Practice Continue starts real board"): return
	practice_scene.worksheet.cell_action_requested.emit(&"reveal", 0, int(practice_scene.get("_physical_view").board.revision))
	# Read-only inspection verifies the production generator/reducer; no board is fabricated.
	var private_record: Dictionary = sandbox.get("_sandbox").capture_dating_challenge_state().value
	if not _check(private_record.board != null and private_record.spec.width == 18 and private_record.spec.height == 18
		and private_record.spec.requested_mine_count == 36 and private_record.board.revealed_indices.has(0), "real 18x18/36 Practice board accepts first Reveal"): return
	if not _unchanged("practice first Reveal"): return
	if not await _capture_screen("06-practice-board"): return
	_stage = "Practice returns without canonical mutation"
	practice.get("_return_button").pressed.emit()
	if not await _wait_until(func(): return practice.get("_dating") == null and practice.get("_selection").visible, "first Return restores picker"): return
	if not _check(sandbox.get("_sandbox") == null, "first Return discards private board owner"): return
	if not _unchanged("return to picker"): return
	if not await _capture_screen("07-return-to-picker"): return
	practice.get("_return_button").pressed.emit()
	if not await _wait_until(func(): return not gallery.has_active_rehearsal() and gallery.get("_canvas").visible, "second Return restores Gallery"): return
	await _frames()
	if not _check(current_scene == title and gallery.is_visible_in_tree(), "two Practice Returns retain actual title Gallery"): return
	if not _unchanged("return to Gallery"): return
	if not await _capture_screen("08-return-gallery"): return
	if "--probe-date-replay" in OS.get_cmdline_user_args():
		if not await _probe_reached_date_replay(gallery, title, reached): return
	print("PLAYABLE_REHEARSAL_PASS: real New Account -> Day1 round -> accepted/scheduled date -> actual reached draw -> canonical board -> public Pause Return -> Gallery Practice -> exact version -> real private board -> Return twice; Run/Profile/Dialogic unchanged during practice.")
	quit(0)
