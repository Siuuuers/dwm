extends GutTest
## Real Pause/Settings/Backup/Input/Audio/Profile controls and owners. The current scene,
## run-session and router doubles isolate source custody; no player storage or engine startup.
const CONTROLLER := preload("res://scripts/application/lifecycle/ProductionPauseController.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const AUDIO_FIXTURE := preload("res://tests/unit/test_audio_pause_suspension.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SETTINGS_THEME := preload("res://scripts/ui/SettingsTheme.gd")
const PRELUDE := preload("res://scripts/ui/Day7PreludeSurface.gd")
const DATING_FIXTURE := preload("res://tests/unit/test_dating_physical_owner.gd")

class RunOwner extends RefCounted:
	var dating_state: Object
	var day := 1
	var dark_mode := false
	var session_captures := 0
	func capture_dating_challenge_state() -> Dictionary:
		return dating_state.capture_dating_challenge_state()
	var gate: Object
	var handle := {"active": true, "generation": 1, "run_id": "pause-run", "owner_id": 42}
	func capture_live_session() -> Dictionary:
		session_captures += 1
		return {"ok": true, "value": handle.duplicate(true)}
	func validate_live_session(expected: Dictionary) -> Dictionary:
		return {"ok": expected == handle and handle.active and gate.guard_external(&"pause_fixture").ok}
	func get_run_configuration() -> Dictionary: return {"ok": true, "value": {"dark_mode": dark_mode}}
	func retire_live_session(expected: Dictionary) -> Dictionary:
		if not gate.is_internal_owner_active(&"session_abandonment") or expected != handle: return {"ok": false}
		handle.active = false
		handle.generation += 1
		return {"ok": true}

class SourceScene extends Control:
	var command: Dictionary = {}
	func get_presentation_projection() -> Dictionary: return command.duplicate(true)

class Router extends RefCounted:
	var tree: SceneTree
	var gate: Object
	var route := "main"
	var source: Control
	var title: Control
	var fail_publication_once := false
	var publications := 0
	var restore_hold: Dictionary = {}
	func begin_restore_publication_hold(handle: Dictionary) -> Dictionary:
		if not restore_hold.is_empty() or tree.current_scene != source: return {"ok": false}
		restore_hold = handle.duplicate(true)
		return {"ok": true}
	func cancel_restore_publication_hold(handle: Dictionary) -> Dictionary:
		if handle != restore_hold or tree.current_scene != source: return {"ok": false}
		restore_hold.clear()
		return {"ok": true}
	func get_current_route_id() -> String: return route
	func prepare_return_to_title() -> Dictionary:
		return {"ok": tree.current_scene == source, "value": {"token": "prepared-pause-title"}}
	func validate_prepared_return_to_title(token: String) -> Dictionary:
		return {"ok": token == "prepared-pause-title" and tree.current_scene == source and gate.is_internal_owner_active(&"session_abandonment")}
	func cancel_prepared_return_to_title(_token: String) -> Dictionary: return {"ok": true}
	func publish_prepared_return_to_title(token: String) -> Dictionary:
		publications += 1
		if fail_publication_once:
			fail_publication_once = false
			return {"ok": false, "code": &"fixture_route_failed"}
		if not validate_prepared_return_to_title(token).ok: return {"ok": false}
		title = Control.new()
		tree.root.add_child(title)
		tree.current_scene = title
		route = "menu"
		return {"ok": true}

class Saves extends RefCounted:
	var writes := 0
	var inspections := 0
	var populated := false
	var pending: Dictionary = {}
	var on_load := Callable()
	var fail_load := false
	var loaded := 0
	func get_backup_quick_capability(action: String) -> Dictionary:
		return {"ok": true, "value": {"enabled": populated and action == "load", "status_key": "unavailable",
			"condition": {"action": action, "populated": populated}}}
	func is_quick_condition_current(condition: Dictionary) -> bool:
		return condition == {"action": "load", "populated": populated}
	func prepare_quick_backup_action(action: String) -> Dictionary:
		var result := prepare_backup_action(action, "quick")
		if result.get("ok", false): result.value.condition = {"action": action, "populated": populated}
		return result
	func get_backup_save_capability() -> Dictionary: return {"enabled": false, "reason": "fixture_capture_unavailable"}
	func inspect_backup(locator: String) -> Dictionary:
		inspections += 1
		if not populated: return {"ok": false}
		return {"ok": true, "value": {"locator": locator, "revision": "fixture-record", "state": "occupied",
			"day": 1, "saved_time": "12:30", "fallback": false, "load_day": 1, "load_saved_time": "12:30",
			"reason": "", "loadable": true, "operation_allowed": true}}
	func prepare_backup_action(action: String, locator: String) -> Dictionary:
		var record: Dictionary = inspect_backup(locator)
		if not record.ok: return record
		pending["prepared-" + action] = action
		return {"ok": true, "value": {"token": "prepared-" + action, "record": record.value}}
	func commit_backup_action(token: String) -> Dictionary:
		if not pending.has(token): return {"ok": false}
		var action: String = pending[token]
		pending.erase(token)
		if action == "load":
			loaded += 1
			if on_load.is_valid(): on_load.call()
			return {"ok": not fail_load, "code": &"fixture_load_failed" if fail_load else &"ok"}
		writes += 1
		return {"ok": true}
	func cancel_backup_action(token: String) -> void: pending.erase(token)
	func save_session_exit_checkpoint(_inputs: Dictionary, _handle: Dictionary) -> Dictionary:
		writes += 1
		return {"ok": true}

class IdleBridge extends RefCounted:
	var foreign_live := false
	func has_active_playback() -> bool: return foreign_live
	func capture_pause_frontier(_timeline_id: String = "") -> Dictionary: return {"ok": false, "code": &"pause_frontier_unavailable"}

var controller: Node
var profile: Node
var localization: Node
var input_owner: Node
var audio_owner: Node
var run_owner: RunOwner
var router: Router
var saves: Saves
var bridge: IdleBridge
var gate: RefCounted
var source: SourceScene
var focus: Button
var original: Node
var input_backup: Dictionary = {}

func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	original = get_tree().current_scene
	for action: StringName in InputMap.get_actions():
		input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}
	gate = GATE.new()
	profile = PROFILE.new()
	localization = LOCALIZATION.new()
	input_owner = INPUT.new()
	audio_owner = AUDIO.new(AUDIO_FIXTURE.FaultPort.new())
	for port: Node in [profile, localization, input_owner, audio_owner]: add_child(port)
	assert_true(profile.initialize(STORAGE.new("pause-controller.memory", FILES.new())).ok)
	assert_true(localization.initialize(profile).ok)
	assert_true(input_owner.initialize(profile).ok)
	assert_true(audio_owner.initialize(profile).ok)
	assert_true(input_owner.configure_mutation_gate(gate).ok)
	run_owner = RunOwner.new()
	run_owner.gate = gate
	saves = Saves.new()
	bridge = IdleBridge.new()
	source = SourceScene.new()
	source.scene_file_path = "res://scenes/main/MainGameScene.tscn"
	source.size = Vector2(1280, 720)
	get_tree().root.add_child(source)
	get_tree().current_scene = source
	focus = Button.new()
	focus.text = "Fixture action"
	source.add_child(focus)
	focus.grab_focus()
	router = Router.new()
	router.tree = get_tree()
	router.gate = gate
	router.source = source
	controller = CONTROLLER.new()
	add_child(controller)
	assert_true(controller.configure({"game_state": run_owner, "saves": saves, "bridge": bridge,
		"input": input_owner, "audio": audio_owner, "gate": gate, "profile": profile,
		"localization": localization, "settings_services": {"tts": null, "window": null,
			"profile_reset_admission": func() -> bool: return false}}, router).ok)

func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = original
	if is_instance_valid(controller): controller.free()
	if is_instance_valid(source): source.free()
	if is_instance_valid(router.title): router.title.free()
	for port: Node in [audio_owner, input_owner, localization, profile]:
		if is_instance_valid(port): port.free()
	for action: StringName in InputMap.get_actions():
		if not input_backup.has(action): InputMap.erase_action(action)
	for action: StringName in input_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, input_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in input_backup[action].events: InputMap.action_add_event(action, event)
	input_backup.clear()

func _open_pause() -> bool:
	var result: Dictionary = await controller.request_pause()
	assert_true(result.get("ok", false), JSON.stringify(result))
	return result.get("ok", false)

func test_witnessed_load_refuses_foreign_caption_without_session_or_backup_work() -> void:
	assert_true(controller.has_method("can_open_witnessed_backup_load"))
	assert_true(controller.has_method("open_witnessed_backup_load"))
	if not controller.has_method("open_witnessed_backup_load"): return
	var foreign := Node.new()
	source.add_child(foreign)
	var captures := run_owner.session_captures
	for frame in 100:
		assert_false(controller.call("can_open_witnessed_backup_load", foreign))
		assert_false(controller.call("can_open_witnessed_backup_load", null))
	var refused: Dictionary = await controller.call("open_witnessed_backup_load", foreign)
	assert_false(refused.get("ok", true))
	assert_eq(run_owner.session_captures, captures,
		"availability projection and refused foreign input never copy the live session")
	assert_eq(saves.inspections, 0)
	assert_eq(saves.writes, 0)
	assert_false(get_tree().paused)
	assert_true(source.visible)
	assert_true(focus.has_focus())

func test_router_witnessed_load_facade_refuses_when_pause_owner_is_absent() -> void:
	var facade: Node = load("res://autoload/SceneRouter.gd").new()
	add_child_autofree(facade)
	assert_true(facade.has_method("can_open_witnessed_backup_load"))
	assert_true(facade.has_method("open_witnessed_backup_load"))
	if not facade.has_method("open_witnessed_backup_load"): return
	assert_false(facade.call("can_open_witnessed_backup_load", source))
	var refused: Dictionary = await facade.call("open_witnessed_backup_load", source)
	assert_false(refused.get("ok", true))
	assert_false(get_tree().paused)

func test_desktop_pause_continue_preserves_scene_focus_and_real_input_custody() -> void:
	if not await _open_pause(): return
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_true(controller.surface.rows[&"continue"].has_focus())
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	assert_true((await controller.request_continue()).ok)
	assert_false(get_tree().paused)
	assert_true(source.visible)
	assert_true(focus.has_focus())
	assert_eq(input_owner.get_state().value.state, &"Active")
	assert_eq(saves.writes, 0)

func test_day7_overlay_is_covered_and_continue_restores_its_card_and_focus() -> void:
	var prelude := PRELUDE.new()
	var card := {"title": "Priscilla", "body": "No worries. Maybe another day.",
		"receipt": {"entry_id": "day7.followup", "view_token": "day7-pause-card"}}
	assert_true(prelude.configure(card, func(_receipt: Dictionary) -> Dictionary: return {"ok": true}).ok)
	assert_true(prelude.use_presentation_receipts().ok)
	add_child_autofree(prelude)
	prelude._current_body.draw.emit()
	await get_tree().process_frame
	prelude._next.grab_focus()
	assert_true(prelude.is_card_acknowledged(card.receipt))
	var history := prelude.get_presentation_history()
	watch_signals(prelude)
	if not await _open_pause(): return
	assert_false(prelude.visible, "the Day 7 layer outside current_scene is covered too")
	assert_true(controller.surface.rows[&"continue"].has_focus())
	assert_true((await controller.request_continue()).ok)
	await get_tree().process_frame
	assert_true(prelude.visible)
	assert_true(prelude._next.has_focus(), "Continue restores the actual Day 7 focus, not the hidden desktop")
	assert_eq(prelude.get_presentation_history(), history)
	assert_true(prelude.is_card_acknowledged(card.receipt))
	assert_signal_emit_count(prelude, "advance_requested", 0)
	assert_signal_emit_count(prelude, "card_acknowledged", 0)
	assert_eq(saves.writes, 0)

func test_day7_preparation_retry_survives_pause_without_preparing_or_acknowledging() -> void:
	var calls := []
	var prelude := PRELUDE.new()
	assert_true(prelude.configure_waiting(
		func() -> Dictionary:
			calls.append("prepare")
			return {"ok": false},
		func(_receipt: Dictionary) -> Dictionary:
			calls.append("acknowledge")
			return {"ok": false}).ok)
	assert_true(prelude.use_presentation_receipts().ok)
	add_child_autofree(prelude)
	prelude._next.grab_focus()
	if not await _open_pause(): return
	assert_false(prelude.visible)
	assert_true((await controller.request_continue()).ok)
	await get_tree().process_frame
	assert_true(prelude._next.has_focus())
	assert_eq(prelude._next.text, "Retry")
	assert_true(prelude._card.is_empty())
	assert_eq(prelude.get_presentation_history(), [])
	assert_eq(calls, [])

func test_retired_day7_overlay_cannot_restore_focus_into_the_same_desktop() -> void:
	var prelude := PRELUDE.new()
	assert_true(prelude.configure_waiting(func() -> Dictionary: return {"ok": false},
		func(_receipt: Dictionary) -> Dictionary: return {"ok": false}).ok)
	assert_true(prelude.use_presentation_receipts().ok)
	add_child_autofree(prelude)
	if not await _open_pause(): return
	prelude.queue_free()
	await get_tree().process_frame
	var resumed: Dictionary = await controller.request_continue()
	assert_false(resumed.ok)
	assert_eq(resumed.code, &"pause_source_changed")
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_false(focus.has_focus())

func test_day7_lost_view_anchor_keeps_desktop_hidden_during_recovery() -> void:
	var prelude := PRELUDE.new()
	assert_true(prelude.configure_waiting(func() -> Dictionary: return {"ok": false},
		func(_receipt: Dictionary) -> Dictionary: return {"ok": false}).ok)
	assert_true(prelude.use_presentation_receipts().ok)
	add_child_autofree(prelude)
	if not await _open_pause(): return
	var captured: Dictionary = controller.capture_pause_source()
	# The semantic source is unchanged, but its retained physical anchor is lost.
	# Failure discovered by the view must not publish the desktop behind it.
	prelude._pause_anchor.capture_id += 1
	assert_eq(controller.capture_pause_source(), captured)
	var resumed: Dictionary = await controller.request_continue()
	assert_false(resumed.ok)
	assert_eq(resumed.code, &"pause_view_unavailable")
	assert_eq(controller.coordinator.get_state().value.state, &"Recovery")
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_false(prelude.visible)
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	assert_eq(saves.writes, 0)

func test_failed_day7_load_keeps_view_input_and_tree_suspended_through_restore_handoff() -> void:
	var calls := []
	var prelude := PRELUDE.new()
	assert_true(prelude.configure_waiting(func() -> Dictionary:
		calls.append("prepare")
		return {"ok": false}, func(_receipt: Dictionary) -> Dictionary:
		calls.append("acknowledge")
		return {"ok": false}).ok)
	assert_true(prelude.use_presentation_receipts().ok)
	add_child_autofree(prelude)
	prelude._next.grab_focus()
	if not await _open_pause(): return
	var captured: Dictionary = controller.capture_pause_source()
	var handle: Dictionary = controller._handle.duplicate(true)
	assert_true((await controller.release_for_backup_load()).ok)
	assert_eq(controller.coordinator.get_state().value.state, &"Restoring")
	assert_eq(router.restore_hold, handle)
	assert_true(get_tree().paused)
	assert_false(prelude.visible)
	assert_false(source.visible)
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	assert_false(input_owner.is_source_input_admitted())
	var failed := {"ok": false, "code": &"fixture_restore_failed"}
	assert_eq(await controller.finish_backup_load(failed), failed)
	assert_eq(controller.coordinator.get_state().value.state, &"Suspended")
	assert_true(router.restore_hold.is_empty())
	assert_true(get_tree().paused)
	assert_false(prelude.visible)
	assert_eq(controller.capture_pause_source(), captured)
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	assert_eq(calls, [])
	assert_eq(saves.writes, 0)
	assert_true((await controller.request_continue()).ok)
	await get_tree().process_frame
	assert_true(prelude._next.has_focus())


func test_production_pause_reuses_hosts_with_current_day_and_appearance_cannot_touch_backup_action() -> void:
	run_owner.day = 6
	run_owner.dark_mode = true
	saves.populated = true
	if not await _open_pause(): return
	var settings: Control = controller.surface.get("_hosts")[&"settings"]
	var content: Control = settings.settings_content
	var identity: int = settings.get_instance_id()
	var expected: Theme = SETTINGS_THEME.build("en", 100, &"midnight", false, "standard", 6)
	assert_eq(content.get_palette_id(), &"midnight")
	assert_eq(content.theme.get_color("paper", "Settings"), expected.get_color("paper", "Settings"))
	assert_eq(controller.surface.get("_day"), 6)
	var prepared: Dictionary = controller._backup_port.prepare_action("delete", "slot:1")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	var pending: Dictionary = saves.pending.duplicate(true)
	var inspections: int = saves.inspections
	var pause_focus: Control = get_viewport().gui_get_focus_owner()
	for style: String in ["readable", "pixel"]:
		assert_true(localization.set_font_style(style).get("ok", false))
		assert_same(controller.surface.theme.default_font, preload("res://scripts/ui/UiTypography.gd").font("en", 100, style))
		assert_same(controller.surface.get("_hosts")[&"settings"], settings)
		assert_same(get_viewport().gui_get_focus_owner(), pause_focus)
		assert_eq(saves.pending, pending)
		assert_eq(saves.inspections, inspections)
		assert_true(get_tree().paused)
	assert_true(profile.set_preference(&"preferences.accessibility.high_contrast", true).get("ok", false))
	run_owner.day = 7
	controller._refresh_presentation()
	var high: Theme = SETTINGS_THEME.build("en", 100, &"midnight", true, "standard", 7)
	assert_eq(content.theme.get_color("paper", "Settings"), high.get_color("paper", "Settings"))
	assert_eq(content.get("_run_day"), 7)
	assert_eq(controller.surface.get("_day"), 7)
	assert_eq(saves.inspections, inspections, "appearance refresh does not re-inspect Backup records")
	assert_eq(saves.pending, pending, "appearance refresh retains the prepared action")
	assert_eq(saves.writes, 0, "appearance refresh cannot commit an action")
	controller._backup_port.cancel_action(prepared.value.token)
	assert_true((await controller.request_continue()).ok)
	assert_true(focus.has_focus(), "source focus returns after appearance refresh")
	run_owner.day = 3
	if not await _open_pause(): return
	assert_eq(controller.surface.get("_hosts")[&"settings"].get_instance_id(), identity)
	assert_eq(content.get("_run_day"), 3, "cached Settings host receives the new day on reopen")
	assert_eq(controller.surface.get("_day"), 3)
	assert_true((await controller.request_continue()).ok)

func test_physical_dating_source_resumes_exact_command_and_changed_command_refuses() -> void:
	router.route = "dating"
	source.scene_file_path = "res://scenes/dating/DatingScene.tscn"
	source.command = {"route_id": "dating", "physical_token": "date-1", "command_sha256": "exact",
		"completion_transaction_id": "complete-date-1", "timeline_id": "dating.priscilla.day1.pre_challenge"}
	if not await _open_pause(): return
	source.command.physical_token = "foreign-date"
	assert_false((await controller.request_continue()).ok)
	assert_true(get_tree().paused)
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	source.command.physical_token = "date-1"
	assert_true((await controller.request_continue()).ok)
	assert_eq(saves.writes, 0)

func test_return_route_failure_retains_paused_retry_and_never_saves_or_resumes_discarded_source() -> void:
	if not await _open_pause(): return
	router.fail_publication_once = true
	assert_eq(controller.request_return().get("code"), &"exit_route_retry_required")
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_false(run_owner.handle.active)
	assert_eq(controller.coordinator.get_state().value.state, &"Retired")
	assert_true(controller.surface.cancel_button.disabled)
	assert_true(controller.surface.handle_back())
	assert_eq(controller.surface.entered_action, &"return")
	assert_false((await controller.request_continue()).ok)
	assert_true(controller.request_return().ok)
	assert_false(get_tree().paused)
	assert_eq(get_tree().current_scene, router.title)
	assert_eq(saves.writes, 0)
	assert_eq(router.publications, 2)
	assert_eq(input_owner.get_state().value.state, &"Active")

func test_foreign_runtime_and_title_cannot_be_admitted_as_idle_playback() -> void:
	bridge.foreign_live = true
	assert_eq((await controller.request_pause()).get("code"), &"pause_frontier_unavailable")
	assert_false(get_tree().paused)
	bridge.foreign_live = false
	router.route = "menu"
	assert_false((await controller.request_pause()).ok)
	assert_eq(input_owner.get_state().value.state, &"Active")

func test_pause_backup_inspects_nine_records_and_does_not_claim_unsupported_operations() -> void:
	if not await _open_pause(): return
	controller.surface.rows[&"backup"].pressed.emit()
	assert_eq(controller.surface.entered_action, &"backup")
	assert_gte(saves.inspections, 9)
	var projection: Dictionary = controller._backup_port.get_projection()
	assert_eq(projection.value.records.size(), 9)
	for record: Dictionary in projection.value.records:
		assert_eq(record.actions, {"save": false, "load": false, "delete": false})
	assert_true((await controller.request_continue()).ok)

func test_global_back_does_not_steal_a_text_field_event() -> void:
	var edit := LineEdit.new()
	source.add_child(edit)
	edit.grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	controller._unhandled_input(event)
	assert_false(get_tree().paused)
	assert_false(controller.surface.visible)


func test_pause_delete_keeps_exact_suspension_and_never_saves_the_source() -> void:
	saves.populated = true
	if not await _open_pause(): return
	var held: Dictionary = controller._handle.duplicate(true)
	var before: Dictionary = controller.capture_pause_source()
	var prepared: Dictionary = controller._backup_port.prepare_action("delete", "slot:1")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_true(prepared.value.confirmation_required)
	assert_true((await controller._backup_port.commit_action(prepared.value.token)).ok)
	assert_true(get_tree().paused)
	assert_eq(controller._handle, held)
	assert_eq(controller.capture_pause_source(), before)
	assert_eq(saves.writes, 1, "Only the explicitly confirmed Delete reaches storage")
	assert_eq(saves.loaded, 0)
	assert_true((await controller.request_continue()).ok)

func test_idle_pause_load_failure_reacquires_exact_source_then_retry_follows_new_session() -> void:
	saves.populated = true
	saves.fail_load = true
	if not await _open_pause(): return
	var before: Dictionary = controller.capture_pause_source()
	var old_handle: Dictionary = controller._handle.duplicate(true)
	var prepared: Dictionary = controller._backup_port.prepare_action("load", "slot:1")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_true(prepared.value.confirmation_required)
	var failed: Dictionary = await controller._backup_port.commit_action(prepared.value.token)
	assert_eq(failed.get("code"), &"fixture_load_failed")
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_eq(controller.capture_pause_source(), before)
	assert_ne(controller._handle, old_handle, "Reversible rollback acquires a fresh suspension of the same exact source")
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	saves.fail_load = false
	saves.on_load = func() -> void:
		run_owner.handle.generation += 1
		router.title = Control.new()
		router.title.scene_file_path = "res://scenes/main/MainGameScene.tscn"
		get_tree().root.add_child(router.title)
		get_tree().current_scene = router.title
		source.hide()
	prepared = controller._backup_port.prepare_action("load", "slot:1")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_true((await controller._backup_port.commit_action(prepared.value.token)).ok)
	assert_false(get_tree().paused)
	assert_false(controller.surface.visible)
	assert_true(controller._handle.is_empty())
	assert_eq(input_owner.get_state().value.state, &"Active")
	assert_eq(saves.writes, 0)
	assert_eq(saves.loaded, 2)

func test_failed_load_with_changed_session_cannot_resume_either_source() -> void:
	saves.populated = true
	saves.fail_load = true
	saves.on_load = func() -> void: run_owner.handle.generation += 1
	if not await _open_pause(): return
	var prepared: Dictionary = controller._backup_port.prepare_action("load", "slot:1")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	var failed: Dictionary = await controller._backup_port.commit_action(prepared.value.token)
	assert_eq(failed.get("code"), &"pause_load_recovery_required")
	assert_true(failed.recovery_required)
	assert_true(get_tree().paused)
	assert_false((await controller.request_continue()).ok)
	assert_false(controller.request_return().ok)
	assert_eq(saves.writes, 0)


class DatingSaveState extends DATING_FIXTURE.State:
	var lifecycle: Dictionary
	func capture_run_snapshot_input() -> Dictionary:
		return {"lifecycle": lifecycle.duplicate(true)}


class DatingCapture extends RefCounted:
	var snapshot: Dictionary
	var state: Object
	func capture() -> Dictionary:
		var current := snapshot.duplicate(true)
		current.gameplay["route_context"] = state.route_context.duplicate(true)
		current.gameplay.route_context["active_dating_challenge"] = state.saved.duplicate(true)
		return {"ok": true, "value": {"snapshot_input": current, "route_id": "dating",
			"active_app_id": null, "dialogic_checkpoint": {}, "audio_context": {}, "content_version": 1}}


func _dating_save_fixture(debug: bool = false) -> Dictionary:
	var snapshot_result: Dictionary = preload("res://tests/support/BackupSnapshotFixture.gd").make_snapshot()
	assert_true(snapshot_result.get("ok", false), str(snapshot_result))
	if not snapshot_result.get("ok", false): return {}
	var snapshot: Dictionary = snapshot_result.value.candidate
	var dating_state := DatingSaveState.new()
	dating_state.lifecycle = snapshot.lifecycle.duplicate(true)
	if debug: dating_state.inventory = {"debug_key": 1, "lucky_charm": 1}
	var dating_profile: RefCounted = DATING_FIXTURE.ReachedProfile.new()
	var issuer := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd").new()
	assert_true(issuer.configure(preload("res://tests/support/FakeDesktopIssuerRootStore.gd").new("91".repeat(32), 1)).ok)
	var generation: RefCounted = preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd").new() if debug else preload("res://tests/support/FakeMinesweeperGenerationPort.gd").new()
	var mines: Array = []
	for index in 36: mines.append(index)
	if not debug:
		generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18,
			"mine_indices": mines, "mine_count": 36})
	var physical := preload("res://scripts/application/run/DatingPhysicalOwner.gd").new()
	assert_true(physical.configure(issuer, dating_state, dating_profile, generation).ok)
	assert_true(physical.configure_frozen_narrative_contexts().ok)
	var presentation := preload("res://scripts/application/run/DatingPresentationPort.gd").new()
	assert_true(presentation.configure(issuer, physical).ok)
	var context := {"day": 1, "kind": "solo", "participants": ["priscilla"], "schedule_entry_id": "pause-date"}
	var root_receipt: Dictionary = issuer.issue(&"transaction_id").value.issuer_receipt
	var request := {"resolution_id": "pause-date-resolution", "resolution_issuer_receipt": root_receipt,
		"stage_id": "execute_dates", "substage_id": "pause-date", "route_id": "dating",
		"timeline_id": "dating.solo.priscilla.day1.pre_challenge", "context": context,
		"completion_transaction_id": "", "completion_transaction_provenance": {}}
	var canonical := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
	var sources: Array = []
	for key: String in ["resolution_id", "stage_id", "substage_id", "route_id", "timeline_id"]:
		sources.append(key + "=" + str(canonical.canonical_json(request[key]).value.text))
	sources.append("role=" + str(canonical.canonical_json("presentation.completion").value.text))
	sources.append("context_sha256=" + str(canonical.canonical_json(canonical.canonical_sha256(context).value.sha256).value.text))
	sources.sort()
	var child: Dictionary = issuer.derive_child({"parent_receipt_id": root_receipt.receipt_id,
		"child_kind": presentation.COMPLETION_CHILD_KIND, "ordinal": 0, "source_ids": sources})
	assert_true(child.ok)
	request.completion_transaction_id = child.value.child_id
	request.completion_transaction_provenance = child.value.provenance
	var begun: Dictionary = presentation.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return {}
	source.command = begun.value.presentation_command
	source.scene_file_path = "res://scenes/dating/DatingScene.tscn"
	router.route = "dating"
	run_owner.handle.run_id = snapshot.run_id
	run_owner.dating_state = dating_state
	var files := FILES.new()
	var storage := STORAGE.new("pause-dating-save", files)
	var manager: Node = autofree(preload("res://autoload/SaveManager.gd").new())
	assert_true(manager.initialize(storage).ok)
	assert_true(manager.configure_mutation_gate(gate).ok)
	manager._journal.reset(snapshot.run_id)
	var seeded: Dictionary = manager._journal.prepare_record(snapshot, &"day_start")
	assert_true(seeded.get("ok", false), str(seeded))
	if not seeded.get("ok", false): return {}
	assert_true(manager._journal.commit_prepared(seeded.value.candidate).ok)
	var capture := DatingCapture.new()
	capture.state = dating_state
	capture.snapshot = {}
	for key: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "desktop", "dating",
			"schedule_view", "applied_effect_transaction_ids", "applied_variable_transaction_ids", "command_receipts"]:
		capture.snapshot[key] = snapshot[key].duplicate(true)
	controller.free()
	controller = CONTROLLER.new()
	add_child(controller)
	assert_true(controller.configure({"game_state": run_owner, "saves": manager, "bridge": bridge,
		"input": input_owner, "audio": audio_owner, "gate": gate, "profile": profile,
		"localization": localization, "backup_capture": capture.capture, "dating_presentation": presentation,
		"settings_services": {"tts": null, "window": null, "profile_reset_admission": func() -> bool: return false}}, router).ok)
	assert_true(manager.configure_backup_capture_provider(controller.capture_backup_checkpoint_inputs).ok)
	return {"state": dating_state, "profile": dating_profile, "issuer": issuer, "generation": generation,
		"physical": physical, "presentation": presentation, "manager": manager, "files": files, "storage": storage,
		"capture": capture}


func test_paused_dating_manual_and_quick_save_restore_exact_board_and_command() -> void:
	var fixture := _dating_save_fixture()
	if fixture.is_empty() or not await _open_pause(): return
	var held: Dictionary = controller._handle.duplicate(true)
	var first: Dictionary = controller._backup_port.prepare_action("save", "slot:1")
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	assert_true((await controller._backup_port.commit_action(first.value.token)).ok)
	assert_eq(controller._handle, held)
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_true((await controller.request_continue()).ok)
	assert_true(fixture.presentation.dispatch_physical(source.command, "continue", -1, 0).ok)
	assert_true(fixture.presentation.dispatch_physical(source.command, "reveal", 36, 0).ok)
	assert_true(fixture.presentation.dispatch_physical(source.command, "flag", 18, 0).ok)
	var exact_record: Dictionary = fixture.state.saved.duplicate(true)
	if not await _open_pause(): return
	held = controller._handle.duplicate(true)
	var quick: Dictionary = controller._backup_port.prepare_quick_action("save")
	assert_true(quick.get("ok", false), str(quick))
	if not quick.get("ok", false): return
	assert_false(quick.value.confirmation_required)
	assert_true((await controller._backup_port.commit_action(quick.value.token)).ok)
	assert_eq(controller._handle, held, "saving never releases or replaces Pause custody")
	assert_true(get_tree().paused)
	assert_eq(fixture.state.saved, exact_record)
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	var loaded_text: Dictionary = fixture.storage.read_text("quicksave.json")
	assert_true(loaded_text.get("ok", false), str(loaded_text))
	if not loaded_text.get("ok", false): return
	var document: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(JSON.parse_string(loaded_text.value))
	assert_true(document.get("ok", false), str(document))
	if not document.get("ok", false): return
	var saved: Dictionary = document.value.candidate.current_snapshot.snapshot
	assert_eq(saved.route_id, "dating")
	assert_null(saved.active_app_id, "there is no substitute main/Backup foreground app")
	assert_eq(saved.narrative_checkpoint, {})
	assert_eq(saved.gameplay.route_context.active_dating_challenge, exact_record)
	assert_eq(saved.gameplay.route_context.dating_frozen_contexts_v1,
		fixture.state.route_context.dating_frozen_contexts_v1)
	var restored: Node = add_child_autofree(preload("res://autoload/GameState.gd").new())
	restored.reset_game()
	var participant := preload("res://scripts/application/restore/RunRestoreParticipant.gd").new(restored)
	var prepared: Dictionary = participant.prepare({"snapshot": saved})
	assert_true(prepared.ok)
	var applied: Dictionary = participant.apply_silent(prepared.value.run_plan)
	assert_true(applied.get("ok", false), str(applied))
	if not applied.get("ok", false): return
	var fresh := preload("res://scripts/application/run/DatingPhysicalOwner.gd").new()
	assert_true(fresh.configure(fixture.issuer, restored, fixture.profile, fixture.generation).ok)
	assert_true(fresh.configure_frozen_narrative_contexts().ok)
	assert_true(fresh.begin_physical(source.command).ok)
	assert_eq(restored.capture_dating_challenge_state().value, exact_record)
	assert_eq(restored.route_context.dating_frozen_contexts_v1,
		fixture.state.route_context.dating_frozen_contexts_v1)
	assert_eq(fresh.pull_physical(source.command.physical_token).value.board,
		fixture.presentation.pull_physical(source.command).value.board)
	assert_eq(fixture.generation.call_log.size(), 1, "restore never rerolls the saved board")
	assert_true((await controller.request_continue()).ok)


func test_paused_dating_save_cancellation_and_board_drift_preserve_suspension_and_disk() -> void:
	var fixture := _dating_save_fixture()
	if fixture.is_empty(): return
	assert_true(fixture.presentation.dispatch_physical(source.command, "continue", -1, 0).ok)
	assert_true(fixture.presentation.dispatch_physical(source.command, "reveal", 36, 0).ok)
	if not await _open_pause(): return
	var held: Dictionary = controller._handle.duplicate(true)
	var disk: Dictionary = fixture.files.snapshot_persisted()
	var journal: Dictionary = fixture.manager._journal.capture_state()
	var prepared: Dictionary = controller._backup_port.prepare_action("save", "slot:2")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	controller._backup_port.cancel_action(prepared.value.token)
	assert_eq(fixture.files.snapshot_persisted(), disk)
	assert_eq(fixture.manager._journal.capture_state(), journal)
	prepared = controller._backup_port.prepare_action("save", "slot:2")
	assert_true(prepared.ok)
	# Simulate a concurrent owner change through the public reducer command door.
	assert_true(fixture.presentation.dispatch_physical(source.command, "flag", 18, 0).ok)
	var refused: Dictionary = await controller._backup_port.commit_action(prepared.value.token)
	assert_eq(refused.get("code"), &"stale_backup_source")
	assert_eq(fixture.files.snapshot_persisted(), disk)
	assert_eq(fixture.manager._journal.capture_state(), journal)
	assert_eq(controller._handle, held)
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	assert_true((await controller.request_continue()).ok)


func test_desktop_pause_capture_preserves_the_covered_app_and_suspension() -> void:
	var inputs := {"snapshot_input": {"lifecycle": {"run_id": run_owner.handle.run_id},
		"desktop": {"board": {"fixture_identity": "same-board"}}},
		"route_id": "main", "active_app_id": "minesweeper", "dialogic_checkpoint": {}}
	controller._services["backup_capture"] = func() -> Dictionary: return {"ok": true, "value": inputs}
	assert_false(controller.can_save_backup(), "a provider cannot create Pause custody")
	if not await _open_pause(): return
	var handle: Dictionary = controller._handle.duplicate(true)
	var captured: Dictionary = controller.capture_backup_checkpoint_inputs()
	assert_true(captured.ok, str(captured))
	if not captured.ok: return
	assert_eq(captured.value, inputs)
	captured.value.snapshot_input.desktop.board.fixture_identity = "changed-copy"
	assert_eq(inputs.snapshot_input.desktop.board.fixture_identity, "same-board")
	assert_eq(controller._handle, handle)
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_eq(saves.writes, 0, "capturing never writes or resumes")

func test_desktop_pause_capture_refuses_route_session_and_narrative_drift() -> void:
	var inputs := {"snapshot_input": {"lifecycle": {"run_id": run_owner.handle.run_id}},
		"route_id": "main", "active_app_id": "contacts", "dialogic_checkpoint": {}}
	controller._services["backup_capture"] = func() -> Dictionary: return {"ok": true, "value": inputs}
	if not await _open_pause(): return
	for field: String in ["route", "run", "narrative"]:
		var prior: Dictionary = inputs.duplicate(true)
		if field == "route": inputs.route_id = "dating"
		elif field == "run": inputs.snapshot_input.lifecycle.run_id = "another-run"
		else: inputs.dialogic_checkpoint = {"timeline": "unowned"}
		var refused: Dictionary = controller.capture_backup_checkpoint_inputs()
		assert_eq(refused.code, &"pause_source_changed", field)
		inputs.clear()
		inputs.merge(prior)
	assert_true(get_tree().paused)
	assert_eq(saves.writes, 0)


func test_paused_debug_preparation_save_preserves_exact_frontier_without_entering_attempt() -> void:
	var fixture := _dating_save_fixture(true)
	if fixture.is_empty(): return
	var entered: Dictionary = fixture.presentation.dispatch_physical(source.command, "continue", -1, 0)
	assert_true(entered.get("ok", false), str(entered))
	if not entered.get("ok", false): return
	assert_eq(fixture.state.saved.phase, "preparing")
	assert_true(preload("res://scripts/application/run/DatingChallengeEnvelope.gd").validate(fixture.state.saved))
	var exact: Dictionary = fixture.state.saved.duplicate(true)
	var history: Dictionary = fixture.physical._history_state()
	assert_true(fixture.physical._pending_checkpoint.is_empty())
	if not await _open_pause(): return
	var prepared: Dictionary = controller._backup_port.prepare_quick_action("save")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	var committed: Dictionary = await controller._backup_port.commit_action(prepared.value.token)
	assert_true(committed.get("ok", false), str(committed))
	if not committed.get("ok", false): return
	var stored: Dictionary = fixture.storage.read_text("quicksave.json")
	assert_true(stored.get("ok", false), str(stored))
	if not stored.get("ok", false): return
	var document: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(JSON.parse_string(stored.value))
	assert_true(document.get("ok", false), str(document))
	if not document.get("ok", false): return
	assert_eq(document.value.candidate.current_snapshot.snapshot.gameplay.route_context.active_dating_challenge, exact)
	assert_eq(fixture.state.saved, exact)
	assert_eq(fixture.physical._history_state(), history, "saving preparation does not enter an irreversible Profile attempt")
	assert_true(fixture.physical._pending_checkpoint.is_empty())
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_true((await controller.request_continue()).ok)


func _quick_native_key(code: Key, pressed: bool, echo: bool = false, shift_pressed: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	event.shift_pressed = shift_pressed
	get_viewport().push_input(event, true)

func _quick_native_tap(code: Key) -> void:
	_quick_native_key(code, true)
	_quick_native_key(code, false)

func _quick_window_key(window: Window, code: Key, pressed: bool, frames: int = 4) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	window.push_input(event, true)
	for frame in frames: await get_tree().process_frame

func _quick_native_pad(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 42
	event.button_index = button
	event.pressed = pressed
	get_viewport().push_input(event, true)

func _quick_write_count(files: RefCounted) -> int:
	var count := 0
	for operation: Dictionary in files.operation_trace():
		if operation.operation == &"write_bytes": count += 1
	return count

func test_paused_quick_save_uses_real_dating_capture_without_changing_focus_or_backup_selection() -> void:
	var fixture := _dating_save_fixture()
	if fixture.is_empty() or not await _open_pause(): return
	var backup: Control = controller.surface._hosts[&"backup"]
	var selected: String = backup.selected_locator
	var mode: String = backup.active_mode
	var focused := get_viewport().gui_get_focus_owner()
	var held: Dictionary = controller._handle.duplicate(true)
	_quick_native_tap(KEY_F5)
	assert_true(fixture.storage.exists("quicksave.json"), str(controller._quick_commands.last_result))
	assert_true(controller._quick_commands.last_result.get("ok", false))
	assert_eq(controller._handle, held)
	assert_true(get_tree().paused)
	assert_eq(backup.selected_locator, selected)
	assert_eq(backup.active_mode, mode)
	assert_same(get_viewport().gui_get_focus_owner(), focused)
	assert_eq(controller.surface.entered_action, &"")
	assert_eq(controller._quick_commands.edge.key, &"saved")
	# This fixture deliberately has no restore graph. Once the file exists, the
	# real owner refuses a further overwrite of that unproved target.
	var written := _quick_write_count(fixture.files)
	controller._quick_commands.last_result = {}
	_quick_native_key(KEY_F5, true)
	assert_eq(controller._quick_commands.last_result.get("code"), &"backup_action_unavailable")
	assert_eq(controller._quick_commands.edge.key, &"unavailable")
	controller._quick_commands.last_result = {}
	_quick_native_key(KEY_F5, true, true)
	_quick_native_key(KEY_F5, true)
	assert_true(controller._quick_commands.last_result.is_empty(), "Held and echoed contacts never call the owner again")
	assert_eq(_quick_write_count(fixture.files), written)
	_quick_native_key(KEY_F5, false)

func test_paused_quick_rebinding_quarantines_the_held_new_key_until_release() -> void:
	var fixture := _dating_save_fixture()
	if fixture.is_empty() or not await _open_pause(): return
	_quick_native_key(KEY_F6, true)
	var replacement := InputEventKey.new()
	replacement.physical_keycode = KEY_F6
	assert_true(input_owner.rebind_action("game_quick_save", replacement).ok)
	_quick_native_key(KEY_F6, true)
	assert_false(fixture.storage.exists("quicksave.json"))
	_quick_native_key(KEY_F6, false)
	_quick_native_tap(KEY_F5)
	assert_false(fixture.storage.exists("quicksave.json"), "The replaced binding is inert")
	_quick_native_tap(KEY_F6)
	assert_true(fixture.storage.exists("quicksave.json"), str(controller._quick_commands.last_result))

func test_paused_quick_rejects_unsupported_modifier_binding_and_preserves_default() -> void:
	var fixture := _dating_save_fixture()
	if fixture.is_empty(): return
	var mappings: Dictionary = profile.get_controls_binding_snapshot()
	var replacement := InputEventKey.new()
	replacement.physical_keycode = KEY_F6
	replacement.shift_pressed = true
	var rebound: Dictionary = input_owner.rebind_action("game_quick_save", replacement)
	assert_false(rebound.ok)
	assert_eq(rebound.code, &"modifier_arbitration_unavailable")
	assert_eq(profile.get_controls_binding_snapshot(), mappings)
	if not await _open_pause(): return
	_quick_native_key(KEY_SHIFT, true, false, true)
	_quick_native_key(KEY_F5, true, false, true)
	assert_false(fixture.storage.exists("quicksave.json"), "A modified packet cannot trigger the unmodified default")
	_quick_native_key(KEY_F5, false, false, true)
	_quick_native_key(KEY_SHIFT, false)
	_quick_native_tap(KEY_F5)
	assert_true(fixture.storage.exists("quicksave.json"), str(controller._quick_commands.last_result))

func test_paused_quick_load_cancel_retains_backup_drawer_mode_and_exact_focus() -> void:
	saves.populated = true
	if not await _open_pause(): return
	var backup: Control = controller.surface._hosts[&"backup"]
	var selected: String = backup.selected_locator
	var mode: String = backup.active_mode
	var focused := get_viewport().gui_get_focus_owner()
	_quick_native_tap(KEY_F9)
	assert_not_null(controller.surface._host_confirmation)
	assert_eq(controller.surface.entered_action, &"")
	assert_eq(controller.surface.selected_action, &"continue")
	assert_eq(backup.selected_locator, selected)
	assert_eq(backup.active_mode, mode)
	assert_eq(saves.loaded, 0)
	assert_eq(saves.pending.size(), 1)
	_quick_native_tap(KEY_ESCAPE)
	assert_null(controller.surface._host_confirmation)
	assert_true(saves.pending.is_empty())
	assert_same(get_viewport().gui_get_focus_owner(), focused)
	assert_eq(controller.surface.entered_action, &"")
	assert_true(get_tree().paused)

func test_paused_controller_quick_load_uses_saved_binding_and_compensates_failure() -> void:
	saves.populated = true
	saves.fail_load = true
	var replacement := InputEventJoypadButton.new()
	replacement.button_index = JOY_BUTTON_PADDLE1
	assert_true(input_owner.rebind_action("game_quick_load", replacement).ok)
	if not await _open_pause(): return
	_quick_native_pad(JOY_BUTTON_RIGHT_STICK, true)
	_quick_native_pad(JOY_BUTTON_RIGHT_STICK, false)
	assert_null(controller.surface._host_confirmation)
	_quick_native_pad(JOY_BUTTON_PADDLE1, true)
	_quick_native_pad(JOY_BUTTON_PADDLE1, false)
	var sheet: Control = controller.surface._host_confirmation
	assert_not_null(sheet)
	if sheet == null: return
	var old_handle: Dictionary = controller._handle.duplicate(true)
	sheet._finish(true)
	for frame in 4: await get_tree().process_frame
	assert_eq(saves.loaded, 1)
	assert_true(get_tree().paused)
	assert_false(source.visible)
	assert_ne(controller._handle, old_handle)
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	assert_eq(controller._quick_commands.edge.key, &"unavailable")
	assert_true(saves.pending.is_empty())

func test_paused_settings_quick_save_keeps_host_focus_and_exact_canonical_source() -> void:
	var fixture := _dating_save_fixture()
	if fixture.is_empty() or not await _open_pause(): return
	controller.surface._activate(&"settings")
	for frame in 4: await get_tree().process_frame
	var settings: Control = controller.surface._hosts[&"settings"]
	var content: Control = settings.get_content_host()
	content.select_category("reading")
	content.focus_sheet()
	var focused := get_viewport().gui_get_focus_owner()
	assert_true(is_instance_valid(focused) and settings.is_ancestor_of(focused))
	var held: Dictionary = controller._handle.duplicate(true)
	var exact: Dictionary = fixture.state.saved.duplicate(true)
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var backup: Control = controller.surface._hosts[&"backup"]
	var selected: String = backup.selected_locator
	var mode: String = backup.active_mode
	_quick_native_tap(KEY_F5)
	assert_true(controller._quick_commands.last_result.get("ok", false), str(controller._quick_commands.last_result))
	var stored: Dictionary = fixture.storage.read_text("quicksave.json")
	assert_true(stored.get("ok", false), str(stored))
	if not stored.get("ok", false): return
	var document: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(JSON.parse_string(stored.value))
	assert_true(document.get("ok", false), str(document))
	if not document.get("ok", false): return
	var saved: Dictionary = document.value.candidate.current_snapshot.snapshot
	assert_eq(saved.route_id, "dating")
	assert_null(saved.active_app_id, "Settings and Pause do not become canonical desktop apps")
	assert_eq(saved.gameplay.route_context.active_dating_challenge, exact)
	assert_eq(fixture.state.saved, exact)
	assert_eq(profile.get_profile_snapshot(), profile_before)
	assert_eq(controller._handle, held)
	assert_true(get_tree().paused)
	assert_eq(input_owner.get_state().value.state, &"Suspended")
	assert_eq(controller.surface.entered_action, &"settings")
	assert_eq(content._selected, "reading")
	assert_same(get_viewport().gui_get_focus_owner(), focused)
	assert_eq(backup.selected_locator, selected)
	assert_eq(backup.active_mode, mode)
	assert_eq(controller._quick_commands.edge.key, &"saved")
	controller._quick_commands._process(0.0)
	assert_true(controller._quick_commands.edge.visible)
	assert_true(controller._backup_port._pending.is_empty())

func test_paused_settings_quick_load_remains_unavailable_and_cannot_wake_on_exit() -> void:
	saves.populated = true
	if not await _open_pause(): return
	controller.surface._activate(&"settings")
	assert_eq(controller.surface.entered_action, &"settings")
	assert_eq(controller._quick_commands.request_load().get("code"), &"pause_load_unavailable")
	var inspections := saves.inspections
	_quick_native_key(KEY_F9, true)
	assert_true(controller._quick_commands.last_result.is_empty())
	assert_true(saves.pending.is_empty())
	assert_eq(saves.inspections, inspections)
	assert_null(controller.surface._host_confirmation)
	controller.surface.leave_host()
	_quick_native_key(KEY_F9, true)
	assert_true(controller._quick_commands.last_result.is_empty(), "Held Settings F9 cannot become a root Load")
	_quick_native_key(KEY_F9, false)
	_quick_native_tap(KEY_F9)
	assert_not_null(controller.surface._host_confirmation)
	assert_eq(saves.loaded, 0)
	assert_eq(saves.pending.size(), 1)
	controller.surface._host_confirmation._finish(false)
	assert_true(saves.pending.is_empty())

func test_paused_quick_refusal_is_visible_and_settings_custody_blocks_shortcuts() -> void:
	if not await _open_pause(): return
	_quick_native_tap(KEY_F5)
	controller._quick_commands._process(0.0)
	assert_false(controller._quick_commands.last_result.get("ok", true))
	assert_eq(controller._quick_commands.edge.key, &"unavailable")
	assert_true(controller._quick_commands.edge.visible)
	assert_eq(saves.writes, 0)
	controller.surface._activate(&"settings")
	assert_eq(controller.surface.entered_action, &"settings")
	var content: Control = controller.surface._hosts[&"settings"].get_content_host()
	await content._open_reset_confirmation("preferences")
	var dialog: Window = content.confirmations["preferences"]
	assert_true(dialog.visible)
	controller._quick_commands.last_result = {}
	var inspections := saves.inspections
	# Even a packet delivered to the parent viewport must respect this modal.
	# Native child-Window contact forwarding is a separate custody boundary.
	_quick_native_key(KEY_F5, true)
	assert_true(controller._quick_commands.last_result.is_empty())
	assert_eq(saves.inspections, inspections)
	assert_true(saves.pending.is_empty())
	dialog.hide()
	_quick_native_key(KEY_F5, true)
	assert_true(controller._quick_commands.last_result.is_empty(), "Held confirmation contact cannot turn into Settings Save")
	_quick_native_key(KEY_F5, false)
	_quick_native_tap(KEY_F5)
	assert_eq(controller._quick_commands.edge.key, &"unavailable")
	assert_false(controller._quick_commands.last_result.is_empty())
	assert_eq(controller.surface.entered_action, &"settings")
	assert_eq(saves.writes, 0)

func test_paused_settings_reset_window_forwards_contacts_without_saving_or_queued_replay() -> void:
	var fixture := _dating_save_fixture()
	if fixture.is_empty() or not await _open_pause(): return
	controller.surface._activate(&"settings")
	var content: Control = controller.surface._hosts[&"settings"].get_content_host()
	var profile_before: Dictionary = profile.get_profile_snapshot()
	# A contact may start in the host and finish in its trusted child Window.
	_quick_native_key(KEY_F6, true)
	assert_false(input_owner.get_physical_contacts().is_empty())
	await content._open_reset_confirmation("preferences")
	var dialog: Window = content.confirmations["preferences"]
	assert_true(dialog.visible)
	await _quick_window_key(dialog, KEY_F6, false)
	assert_true(input_owner.get_physical_contacts().is_empty(), "The Window forwards releases to the same input owner")
	await _quick_window_key(dialog, KEY_F5, true)
	await _quick_window_key(dialog, KEY_F5, false)
	assert_true(input_owner.get_physical_contacts().is_empty())
	assert_true(controller._quick_commands.last_result.is_empty())
	assert_false(fixture.storage.exists("quicksave.json"))
	assert_true(controller._backup_port._pending.is_empty())
	await _quick_window_key(dialog, KEY_ESCAPE, true)
	_quick_native_key(KEY_ESCAPE, false)
	assert_false(dialog.visible)
	# Open, receive a held Save contact and cancel without a process-frame poll.
	# Visibility custody must retire the contact synchronously, not on a timer.
	await content._open_reset_confirmation("preferences")
	var input_frame := Engine.get_process_frames()
	_quick_window_key(dialog, KEY_F5, true, 0)
	_quick_window_key(dialog, KEY_ESCAPE, true, 0)
	assert_false(dialog.visible)
	_quick_native_key(KEY_ESCAPE, false)
	_quick_native_key(KEY_F5, true)
	assert_eq(Engine.get_process_frames(), input_frame)
	assert_true(controller._quick_commands.last_result.is_empty())
	assert_false(fixture.storage.exists("quicksave.json"))
	assert_eq(profile.get_profile_snapshot(), profile_before)
	_quick_native_key(KEY_F5, false)
	assert_true(input_owner.get_physical_contacts().is_empty())
	_quick_native_tap(KEY_F5)
	assert_true(controller._quick_commands.last_result.get("ok", false), str(controller._quick_commands.last_result))
	assert_true(fixture.storage.exists("quicksave.json"))
	assert_eq(controller.surface.entered_action, &"settings")
	assert_true(get_tree().paused)

func test_paused_settings_binding_capture_never_saves_and_requires_fresh_release() -> void:
	var fixture := _dating_save_fixture()
	if fixture.is_empty() or not await _open_pause(): return
	controller.surface._activate(&"settings")
	var content: Control = controller.surface._hosts[&"settings"].get_content_host()
	content.select_category("controls")
	var sheet: Control = content._controls_sheet
	await sheet.begin_capture("game_quick_save", "keyboard")
	assert_true(sheet.capture_dialog.visible)
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var event := InputEventKey.new()
	event.keycode = KEY_F5
	event.physical_keycode = KEY_F5
	event.pressed = true
	sheet.capture_dialog.push_input(event, true)
	for frame in 4: await get_tree().process_frame
	assert_true(sheet.capture_dialog.visible)
	assert_true(controller._quick_commands.last_result.is_empty())
	assert_false(fixture.storage.exists("quicksave.json"))
	assert_true(controller._backup_port._pending.is_empty())
	sheet.capture_dialog.canceled.emit()
	for frame in 4: await get_tree().process_frame
	assert_false(sheet.capture_dialog.visible)
	assert_eq(profile.get_profile_snapshot(), profile_before)
	_quick_native_key(KEY_F5, true)
	assert_true(controller._quick_commands.last_result.is_empty(), "Captured contact remains consumed after Cancel")
	assert_false(fixture.storage.exists("quicksave.json"))
	_quick_native_key(KEY_F5, false)
	_quick_native_tap(KEY_F5)
	assert_true(controller._quick_commands.last_result.get("ok", false), str(controller._quick_commands.last_result))
	assert_true(fixture.storage.exists("quicksave.json"))
	assert_eq(controller.surface.entered_action, &"settings")
	assert_true(get_tree().paused)

func test_paused_settings_pending_preference_commit_retires_save_until_release() -> void:
	var fixture := _dating_save_fixture()
	if fixture.is_empty() or not await _open_pause(): return
	controller.surface._activate(&"settings")
	var content: Control = controller.surface._hosts[&"settings"].get_content_host()
	# Retain a preference transaction at its asynchronous owner boundary. The
	# Quick command must remain inert until that owner and physical contact end.
	content.get_controller().set("_busy", true)
	_quick_native_key(KEY_F5, true)
	assert_true(controller._quick_commands.last_result.is_empty())
	assert_false(fixture.storage.exists("quicksave.json"))
	content.get_controller().set("_busy", false)
	_quick_native_key(KEY_F5, true)
	assert_true(controller._quick_commands.last_result.is_empty())
	assert_false(fixture.storage.exists("quicksave.json"))
	_quick_native_key(KEY_F5, false)
	_quick_native_tap(KEY_F5)
	assert_true(controller._quick_commands.last_result.get("ok", false), str(controller._quick_commands.last_result))
	assert_true(fixture.storage.exists("quicksave.json"))
	assert_eq(controller.surface.entered_action, &"settings")

func test_paused_quick_load_success_releases_only_through_the_existing_restore_owner() -> void:
	saves.populated = true
	saves.on_load = func() -> void:
		run_owner.handle.generation += 1
		router.title = Control.new()
		router.title.scene_file_path = "res://scenes/main/MainGameScene.tscn"
		get_tree().root.add_child(router.title)
		get_tree().current_scene = router.title
		source.hide()
	if not await _open_pause(): return
	_quick_native_tap(KEY_F9)
	var sheet: Control = controller.surface._host_confirmation
	assert_not_null(sheet)
	if sheet == null: return
	sheet._finish(true)
	for frame in 4: await get_tree().process_frame
	assert_eq(saves.loaded, 1)
	assert_eq(saves.writes, 0)
	assert_true(saves.pending.is_empty())
	assert_false(get_tree().paused)
	assert_false(controller.surface.visible)
	assert_true(controller._handle.is_empty())
	assert_eq(input_owner.get_state().value.state, &"Active")
	assert_same(get_tree().current_scene, router.title)

func test_paused_quick_focus_loss_cancels_prepared_consent_without_loading() -> void:
	saves.populated = true
	if not await _open_pause(): return
	var origin := get_viewport().gui_get_focus_owner()
	_quick_native_tap(KEY_F9)
	assert_not_null(controller.surface._host_confirmation)
	controller._quick_commands._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	controller._quick_commands._process(0.0)
	assert_null(controller.surface._host_confirmation)
	assert_true(saves.pending.is_empty())
	assert_eq(saves.loaded, 0)
	assert_true(get_tree().paused)
	controller._quick_commands._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	controller._quick_commands._process(0.0)
	assert_same(get_viewport().gui_get_focus_owner(), origin)
	_quick_native_tap(KEY_F9)
	assert_not_null(controller.surface._host_confirmation)
	_quick_native_tap(KEY_ESCAPE)

func test_paused_quick_cancel_restores_rebuilt_backup_action_by_semantic_focus() -> void:
	saves.populated = true
	if not await _open_pause(): return
	controller.surface._activate(&"backup")
	var backup: Control = controller.surface._hosts[&"backup"]
	assert_true(backup.focus_entry(&"load"))
	backup.action_buttons.load.grab_focus()
	var old_focus_id: int = backup.action_buttons.load.get_instance_id()
	var selected: String = backup.selected_locator
	_quick_native_tap(KEY_F9)
	assert_not_null(controller.surface._host_confirmation)
	backup.refresh_view()
	await get_tree().process_frame
	assert_ne(backup.action_buttons.load.get_instance_id(), old_focus_id)
	_quick_native_tap(KEY_ESCAPE)
	assert_null(controller.surface._host_confirmation)
	assert_true(backup.action_buttons.load.has_focus())
	assert_eq(backup.selected_locator, selected)
	assert_eq(backup.active_mode, "load")
	assert_eq(saves.loaded, 0)
	assert_true(saves.pending.is_empty())

func test_quick_focus_out_and_in_before_a_frame_still_retires_load_consent() -> void:
	saves.populated = true
	if not await _open_pause(): return
	var origin := get_viewport().gui_get_focus_owner()
	_quick_native_tap(KEY_F9)
	assert_not_null(controller.surface._host_confirmation)
	controller._quick_commands._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	controller._quick_commands._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_null(controller.surface._host_confirmation)
	assert_true(saves.pending.is_empty())
	controller._quick_commands._process(0.0)
	assert_same(get_viewport().gui_get_focus_owner(), origin)
	assert_eq(saves.loaded, 0)

func test_failed_quick_load_while_backgrounded_restores_origin_on_focus_return() -> void:
	saves.populated = true
	saves.fail_load = true
	saves.on_load = func() -> void:
		controller._quick_commands._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	if not await _open_pause(): return
	var origin := get_viewport().gui_get_focus_owner()
	var old_handle: Dictionary = controller._handle.duplicate(true)
	_quick_native_tap(KEY_F9)
	var sheet: Control = controller.surface._host_confirmation
	assert_not_null(sheet)
	if sheet == null: return
	sheet._finish(true)
	for frame in 4: await get_tree().process_frame
	assert_eq(saves.loaded, 1)
	assert_ne(controller._handle, old_handle)
	assert_true(get_tree().paused)
	controller._quick_commands._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	controller._quick_commands._process(0.0)
	assert_same(get_viewport().gui_get_focus_owner(), origin)
	assert_eq(controller._quick_commands.edge.key, &"unavailable")
	assert_eq(input_owner.get_state().value.state, &"Suspended")
