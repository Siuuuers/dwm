extends "res://addons/gut/test.gd"
# DatingScene ownership (Plan 01 Task 8 Step 8.1, dwm-p2r.14).
#
# WHAT THIS FILE OWNS. That the dating scene decides nothing. It holds a port and a projection, and
# `_ready()` performs no gameplay at all: no challenge start, no affection change, no invitation
# closure, no day advance, no Schedule write, no ending selection.
#
# THE PHASE-2R REALITY IT ALSO PINS. The Dating port is deliberately production-unconfigured, so in
# this phase the scene is never legitimately reached. The suite asserts that an unconfigured scene is
# inert rather than improvising a date, and that the port it would be given fails closed.

const DATING_SCENE_PATH := "res://scenes/dating/DatingScene.tscn"
const PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const FAKE_OWNER := preload("res://tests/support/FakeDatingPresentationOwner.gd")

var _port: RefCounted


func before_each() -> void:
	GameState.reset_game()
	_port = PORT.new()


func _instantiate() -> Node:
	assert_true(ResourceLoader.exists(DATING_SCENE_PATH), "the Dating scene exists")
	return (load(DATING_SCENE_PATH) as PackedScene).instantiate()


func _command() -> Dictionary:
	return {
		"resolution_id": "resolution.day3",
		"resolution_issuer_receipt": {"receipt_id": "root.day3"},
		"stage_id": "resolution.day3:execute_schedule_dates",
		"substage_id": "presentation.intent.date.day3",
		"route_id": "dating",
		"timeline_id": "dating.solo.sylvia.day3.pre_challenge",
		"context": {"kind": "solo", "day": 3, "schedule_entry_id": "entry.sylvia.day3",
			"participants": ["sylvia"]},
		"completion_transaction_id": "completion.date.day3",
		"completion_transaction_provenance": {"child_id": "completion.date.day3"},
		"command_sha256": "b".repeat(64),
		"physical_token": "dating_challenge.token",
	}


func _owner_snapshot() -> Dictionary:
	return {
		"day": int(GameState._run_lifecycle.get_day()),
		"state": String(GameState._run_lifecycle.get_state()),
		"lifecycle": GameState._run_lifecycle.to_dict(),
		"contacts": (GameState.contacts as Dictionary).duplicate(true),
		"schedule": GameState._canonical_committed_schedule(),
		"route_context": (GameState.route_context as Dictionary).duplicate(true),
		"money": GameState.money,
		"health": GameState.get_stat("health"),
		"pressure": GameState.get_stat("pressure"),
	}


# -------------------------------------------------------------------------------------------------
# injection
# -------------------------------------------------------------------------------------------------

func test_the_scene_is_configured_off_tree_and_reports_it() -> void:
	var scene := _instantiate()
	assert_false(scene.is_presentation_configured())
	var configured: Dictionary = scene.configure_presentation(_port, _command())
	assert_true(configured.get("ok", false), str(configured))
	assert_eq(int(configured["value"]["port_instance_id"]), _port.get_instance_id())
	add_child_autofree(scene)


func test_configuration_is_idempotent_and_refuses_a_replacement_port() -> void:
	var scene := _instantiate()
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false))
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false))
	assert_eq(scene.configure_presentation(PORT.new(), _command()).get("code"),
		&"presentation_port_already_configured")
	add_child_autofree(scene)


func test_an_incomplete_port_or_empty_command_is_refused() -> void:
	var scene := _instantiate()
	assert_eq(scene.configure_presentation(null, _command()).get("code"),
		&"invalid_presentation_port")
	assert_eq(scene.configure_presentation(_port, {}).get("code"),
		&"invalid_presentation_command")
	add_child_autofree(scene)


func test_the_scene_holds_only_a_detached_projection() -> void:
	var scene := _instantiate()
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false))
	add_child_autofree(scene)
	var projection: Dictionary = scene.get_presentation_projection()
	(projection["context"] as Dictionary)["participants"] = ["lavinia"]
	assert_eq((scene.get_presentation_projection()["context"] as Dictionary)["participants"],
		["sylvia"], "a caller cannot mutate the scene's copy of the command")


# -------------------------------------------------------------------------------------------------
# ownership
# -------------------------------------------------------------------------------------------------

func test_ready_mutates_no_gameplay_state() -> void:
	var scene := _instantiate()
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false))
	var before := _owner_snapshot()
	add_child_autofree(scene)
	assert_eq(_owner_snapshot(), before,
		"_ready() starts no challenge and touches no affection, invitation, day or Schedule")


func test_an_unconfigured_scene_reaching_the_tree_does_nothing_at_all() -> void:
	var scene := _instantiate()
	var before := _owner_snapshot()
	add_child_autofree(scene)
	assert_false(scene.is_presentation_configured())
	assert_eq(_owner_snapshot(), before)
	assert_eq(scene.get_presentation_projection(), {})


func test_the_scene_exposes_no_mutation_seam() -> void:
	var scene := _instantiate()
	add_child_autofree(scene)
	for forbidden: String in ["advance_date_queue_or_day", "prepare_dating_entries",
			"commit_effect_transaction", "apply_date_outcome", "set_presentation_result",
			"complete_presentation", "goto_ending"]:
		assert_false(scene.has_method(forbidden), "DatingScene must not expose " + forbidden)


# -------------------------------------------------------------------------------------------------
# the deliberate Phase-2R handoff, seen from the scene side
# -------------------------------------------------------------------------------------------------

func test_the_port_this_scene_would_receive_is_not_ready_in_phase_2r() -> void:
	assert_false(_port.is_ready(),
		"Phase 2R composes no relationship-board owner, so the Dating route fails closed")
	var begun: Dictionary = _port.begin(_command())
	assert_false(begun.get("ok", true))
	assert_eq(begun.get("code"), &"dating_physical_owner_unconfigured")


func test_a_configured_port_makes_the_scene_reachable_for_dwm_oyo_4() -> void:
	# The handoff is a MISSING OWNER, not a broken scene: give the port an owner and the same scene
	# configures cleanly. This is what dwm-oyo.4 will do through the composition root.
	var ready_port: RefCounted = PORT.new()
	var scene := _instantiate()
	assert_true(scene.configure_presentation(ready_port, _command()).get("ok", false))
	add_child_autofree(scene)
	assert_true(scene.is_presentation_configured())
