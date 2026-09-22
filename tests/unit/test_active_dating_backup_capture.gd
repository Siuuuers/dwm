extends GutTest
## Production Bootstrap admission and capture with bounded source-owner fixtures.
## These tests prove custody and detachment, not Dating record/schema validity; the
## real physical-owner/v7 save integration remains in test_production_pause_controller.
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const DATING_PATH := "res://scenes/dating/DatingScene.tscn"

class Bootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}
	func _ready() -> void: pass
	func _target(target_name: StringName) -> Node: return targets.get(target_name)

class Source extends Control:
	var command: Dictionary = {}
	func get_presentation_projection() -> Dictionary: return command.duplicate(true)

class Lifecycle extends RefCounted:
	var state := {"run_id": "active-dating-capture"}
	func to_dict() -> Dictionary: return state.duplicate(true)

class Game extends Node:
	var _run_lifecycle := Lifecycle.new()
	var handle := {"active": true, "generation": 1, "run_id": "active-dating-capture", "owner_id": 42}
	var record: Dictionary = {}
	var capture_ok := true
	var session_valid := true
	var record_ok := true
	var session_captures := 0
	func capture_live_session() -> Dictionary:
		session_captures += 1
		return {"ok": true, "value": handle.duplicate(true)} if capture_ok else {"ok": false, "code": &"fixture_session_unavailable"}
	func validate_live_session(expected: Dictionary) -> Dictionary:
		return {"ok": true} if session_valid and handle.active and expected == handle else {"ok": false, "code": &"fixture_session_stale"}
	func capture_dating_challenge_state() -> Dictionary:
		return {"ok": true, "value": record.duplicate(true)} if record_ok else {"ok": false, "code": &"fixture_record_unavailable"}

class Router extends Node:
	var route := "dating"
	func get_current_route_id() -> String: return route

class Bridge extends Node:
	var active := false
	var timeline := ""
	func has_active_playback() -> bool: return active
	func get_current_timeline_id() -> String: return timeline

class Physical extends RefCounted:
	var phase := "challenge"
	var expected_command: Dictionary = {}
	var pulls := 0
	func pull_physical(command: Dictionary) -> Dictionary:
		pulls += 1
		if command != expected_command: return {"ok": false, "code": &"fixture_command_stale"}
		return {"ok": true, "value": {"phase": phase}}

class DayCapture extends RefCounted:
	var inputs: Dictionary = {}
	var on_capture := Callable()
	var calls := 0
	var received_lifecycle: Dictionary = {}
	func _checkpoint_inputs(lifecycle: Dictionary) -> Dictionary:
		calls += 1
		received_lifecycle = lifecycle.duplicate(true)
		if on_capture.is_valid(): on_capture.call()
		return inputs

class ScheduleView extends RefCounted:
	var view := {"day": 1, "draft": {"selected": []}}
	func snapshot() -> Dictionary: return {"ok": true, "value": {"view": view}}

var bootstrap: Bootstrap
var source: Source
var game: Game
var router: Router
var bridge: Bridge
var physical: Physical
var day_capture: DayCapture
var schedule: ScheduleView
var gate: RefCounted
var original: Node

func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	original = get_tree().current_scene
	source = Source.new()
	source.scene_file_path = DATING_PATH
	source.command = {"physical_token": "capture-physical", "command_sha256": "capture-command",
		"completion_transaction_id": "capture-completion", "context": {"participants": ["priscilla"]}}
	get_tree().root.add_child(source)
	get_tree().current_scene = source
	game = Game.new()
	game.record = source.command.duplicate(true)
	game.record["board"] = {"revision": 3, "flagged_indices": [18]}
	router = Router.new()
	bridge = Bridge.new()
	for owner: Node in [game, router, bridge]: add_child_autofree(owner)
	physical = Physical.new()
	physical.expected_command = source.command.duplicate(true)
	day_capture = DayCapture.new()
	day_capture.inputs = {"snapshot_input": {"lifecycle": game._run_lifecycle.to_dict(),
		"gameplay": {"route_context": {"active_dating_challenge": game.record.duplicate(true)}}},
		"route_id": "dating", "active_app_id": null, "dialogic_checkpoint": {},
		"audio_context": {"music": {"track": "fixture-track"}}, "content_version": 1}
	schedule = ScheduleView.new()
	gate = GATE.new()
	bootstrap = Bootstrap.new()
	bootstrap.targets = {&"GameState": game, &"SceneRouter": router, &"DialogicBridge": bridge}
	bootstrap.set("_application_gate", gate)
	bootstrap.set("_retained_dating_presentation_port", physical)
	bootstrap.set("_retained_day_resolution_state_port", day_capture)
	bootstrap.set("_retained_schedule_view_controller", schedule)
	add_child_autofree(bootstrap)

func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = original
	day_capture.on_capture = Callable()
	if is_instance_valid(source): source.free()

func _capture() -> Dictionary:
	return bootstrap._capture_active_dating_checkpoint_inputs()

func _assert_unavailable() -> void:
	assert_eq(bootstrap._admit_active_dating_quick(source).get("code"), &"backup_capture_unavailable")
	assert_eq(_capture().get("code"), &"backup_capture_unavailable")
	assert_eq(day_capture.calls, 0, "Refusal happens before checkpoint capture")

func test_live_capture_keeps_exact_producers_and_returns_a_detached_result() -> void:
	var command := source.command.duplicate(true)
	var record := game.record.duplicate(true)
	var captured := _capture()
	assert_true(captured.get("ok", false), str(captured))
	if not captured.get("ok", false): return
	assert_eq(captured.value.route_id, "dating")
	assert_null(captured.value.active_app_id)
	assert_eq(captured.value.dialogic_checkpoint, {})
	assert_eq(captured.value.snapshot_input.gameplay.route_context.active_dating_challenge, record)
	assert_eq(captured.value.snapshot_input.schedule_view, schedule.view)
	assert_eq(captured.value.audio_context, day_capture.inputs.audio_context)
	assert_eq(day_capture.received_lifecycle, game._run_lifecycle.to_dict())
	captured.value.snapshot_input.gameplay.route_context.active_dating_challenge.board.flagged_indices.append(19)
	captured.value.snapshot_input.gameplay.route_context.active_dating_challenge.context.participants.append("lavinia")
	captured.value.snapshot_input.schedule_view.draft.selected.append("changed-copy")
	captured.value.audio_context.music.track = "changed-copy"
	assert_eq(day_capture.inputs.snapshot_input.gameplay.route_context.active_dating_challenge, record)
	assert_eq(schedule.view.draft.selected, [])
	assert_eq(day_capture.inputs.audio_context.music.track, "fixture-track")
	assert_eq(source.command, command)
	assert_eq(game.record, record)
	assert_false(get_tree().paused)
	assert_true(source.visible)

func test_admission_returns_detached_session_command_and_record_proof() -> void:
	var admitted: Dictionary = bootstrap._admit_active_dating_quick(source)
	assert_true(admitted.get("ok", false), str(admitted))
	if not admitted.get("ok", false): return
	assert_eq(admitted.value.session, game.handle)
	assert_eq(admitted.value.command, source.command)
	assert_eq(admitted.value.record, game.record)
	assert_eq(admitted.value.phase, physical.phase)
	admitted.value.session.generation += 1
	admitted.value.command.context.participants.append("lavinia")
	admitted.value.record.board.flagged_indices.append(19)
	assert_eq(game.handle.generation, 1)
	assert_eq(source.command.context.participants, ["priscilla"])
	assert_eq(game.record.board.flagged_indices, [18])
	assert_eq(day_capture.calls, 0)

func test_admission_requires_the_current_visible_processing_dating_scene() -> void:
	var foreign := Source.new()
	foreign.scene_file_path = DATING_PATH
	foreign.command = source.command.duplicate(true)
	add_child_autofree(foreign)
	assert_eq(bootstrap._admit_active_dating_quick(foreign).get("code"), &"backup_capture_unavailable")
	assert_eq(bootstrap._admit_active_dating_quick(null).get("code"), &"backup_capture_unavailable")
	for defect: String in ["path", "route", "hidden", "disabled", "paused", "presentation", "bridge", "game"]:
		match defect:
			"path": source.scene_file_path = "res://scenes/main/MainGameScene.tscn"
			"route": router.route = "main"
			"hidden": source.hide()
			"disabled": source.process_mode = Node.PROCESS_MODE_DISABLED
			"paused": get_tree().paused = true
			"presentation": bootstrap.set("_retained_dating_presentation_port", null)
			"bridge": bootstrap.targets.erase(&"DialogicBridge")
			"game": bootstrap.targets.erase(&"GameState")
		_assert_unavailable()
		source.scene_file_path = DATING_PATH
		router.route = "dating"
		source.show()
		source.process_mode = Node.PROCESS_MODE_INHERIT
		get_tree().paused = false
		bootstrap.set("_retained_dating_presentation_port", physical)
		bootstrap.targets[&"DialogicBridge"] = bridge
		bootstrap.targets[&"GameState"] = game

func test_live_narrative_or_retained_timeline_refuses_before_session_capture() -> void:
	bridge.active = true
	_assert_unavailable()
	bridge.active = false
	bridge.timeline = "dating.solo.priscilla.day1.pre_challenge"
	_assert_unavailable()
	assert_eq(game.session_captures, 0)
	assert_eq(physical.pulls, 0)

func test_mutation_gate_refuses_admission_and_capture_before_snapshot_work() -> void:
	var held: Dictionary = gate.acquire(&"restore")
	assert_true(held.ok)
	assert_eq(bootstrap._admit_active_dating_quick(source).get("code"), &"TRANSACTION_ACTIVE")
	assert_eq(_capture().get("code"), &"TRANSACTION_ACTIVE")
	assert_eq(day_capture.calls, 0)
	assert_true(gate.release(&"restore", held.value.token).ok)
	assert_true(_capture().get("ok", false))

func test_session_proof_is_required_for_both_admission_and_capture() -> void:
	game.capture_ok = false
	assert_false(bootstrap._admit_active_dating_quick(source).get("ok", true))
	assert_false(_capture().get("ok", true))
	game.capture_ok = true
	game.session_valid = false
	assert_false(bootstrap._admit_active_dating_quick(source).get("ok", true))
	assert_false(_capture().get("ok", true))
	game.session_valid = true
	game.handle.active = false
	assert_false(bootstrap._admit_active_dating_quick(source).get("ok", true))
	assert_false(_capture().get("ok", true))
	assert_eq(day_capture.calls, 0)

func test_command_record_identity_mismatch_refuses_before_snapshot_work() -> void:
	var exact := game.record.duplicate(true)
	for key: String in ["physical_token", "command_sha256", "completion_transaction_id", "context"]:
		game.record[key] = {"participants": ["lavinia"]} if key == "context" else "foreign-value"
		assert_false(bootstrap._admit_active_dating_quick(source).get("ok", true), key)
		assert_false(_capture().get("ok", true), key)
		game.record = exact.duplicate(true)
	game.record_ok = false
	assert_false(bootstrap._admit_active_dating_quick(source).get("ok", true))
	assert_false(_capture().get("ok", true))
	assert_eq(day_capture.calls, 0)

func test_physical_owner_rejection_and_unstable_phase_refuse_capture() -> void:
	source.command["physical_token"] = "foreign-scene-command"
	assert_false(bootstrap._admit_active_dating_quick(source).get("ok", true))
	assert_false(_capture().get("ok", true))
	source.command = physical.expected_command.duplicate(true)
	for phase: String in ["settlement_retry", "completed", "unknown_phase"]:
		physical.phase = phase
		if phase == "settlement_retry":
			assert_true(bootstrap._admit_active_dating_quick(source).get("ok", false),
				"An exact retry source remains available for Quick Load")
		assert_false(_capture().get("ok", true), phase)
	assert_eq(day_capture.calls, 0)

func test_missing_command_identity_is_not_accepted_when_the_record_also_omits_it() -> void:
	source.command.erase("physical_token")
	game.record.erase("physical_token")
	physical.expected_command = source.command.duplicate(true)
	assert_eq(bootstrap._admit_active_dating_quick(source).get("code"), &"backup_source_changed")
	assert_eq(_capture().get("code"), &"backup_source_changed")
	assert_eq(day_capture.calls, 0)

func test_session_change_during_capture_refuses_the_old_run_proof() -> void:
	day_capture.on_capture = func() -> void: game.handle.generation += 1
	assert_eq(_capture().get("code"), &"backup_source_changed")
	assert_eq(day_capture.calls, 1)

func test_scene_command_change_during_capture_refuses_even_when_its_record_is_unchanged() -> void:
	day_capture.on_capture = func() -> void: source.command["fixture_revision"] = 2
	assert_eq(_capture().get("code"), &"backup_source_changed")
	assert_eq(game.record.board.revision, 3)

func test_physical_record_change_during_capture_refuses_even_when_command_matches() -> void:
	day_capture.on_capture = func() -> void: game.record.board.revision += 1
	assert_eq(_capture().get("code"), &"backup_source_changed")
	assert_eq(source.command, physical.expected_command)

func test_new_narrative_during_capture_never_becomes_an_empty_checkpoint() -> void:
	for active: bool in [true, false]:
		bridge.active = false
		bridge.timeline = ""
		day_capture.on_capture = func() -> void:
			bridge.active = active
			bridge.timeline = "" if active else "foreign-timeline"
		assert_eq(_capture().get("code"), &"backup_source_changed")

func test_replaced_scene_during_capture_refuses_the_previous_scene() -> void:
	var replacement := Source.new()
	replacement.scene_file_path = DATING_PATH
	replacement.command = source.command.duplicate(true)
	add_child_autofree(replacement)
	day_capture.on_capture = func() -> void: get_tree().current_scene = replacement
	assert_eq(_capture().get("code"), &"backup_source_changed")

func test_snapshot_run_or_record_drift_is_not_repaired_from_the_live_source() -> void:
	day_capture.inputs.snapshot_input.lifecycle.run_id = "another-run"
	assert_eq(_capture().get("code"), &"backup_source_changed")
	day_capture.inputs.snapshot_input.lifecycle.run_id = game.handle.run_id
	day_capture.inputs.snapshot_input.gameplay.route_context.active_dating_challenge.board.revision = 2
	assert_eq(_capture().get("code"), &"backup_source_changed")
	assert_eq(game.record.board.revision, 3)
