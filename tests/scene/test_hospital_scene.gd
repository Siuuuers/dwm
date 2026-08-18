extends "res://addons/gut/test.gd"
# HospitalScene ownership (Plan 01 Task 8 Step 8.1, dwm-p2r.14).
#
# WHAT THIS FILE OWNS. That a Control node cannot decide gameplay. Before Task 8 this scene started
# the faint timeline itself and then called `GameState.apply_hospital_recovery_and_advance_day()`
# and routed to main or to an ending -- so a button press owned recovery, the day, and the ending.
# Every assertion below is a fact about what the scene may no longer touch.
#
# HOW IT PROVES IT. GameState, the run lifecycle, the Contacts index, the committed Schedule and the
# route context are all snapshotted before `_ready()` and before input, and compared byte-for-byte
# afterwards. A scene that mutated any of them fails here regardless of which seam it used.

const HOSPITAL_SCENE_PATH := "res://scenes/hospital/HospitalScene.tscn"
const PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const FAKE_DATING_OWNER := preload("res://tests/support/FakeDatingPresentationOwner.gd")

var _port: RefCounted


func before_each() -> void:
	GameState.reset_game()
	_port = PORT.new()


func _instantiate() -> Node:
	assert_true(ResourceLoader.exists(HOSPITAL_SCENE_PATH), "the Hospital scene exists")
	var scene: Node = (load(HOSPITAL_SCENE_PATH) as PackedScene).instantiate()
	return scene


func _command() -> Dictionary:
	return {
		"resolution_id": "resolution.day3",
		"resolution_issuer_receipt": {"receipt_id": "root.day3"},
		"stage_id": "resolution.day3:hospital_if_triggered",
		"substage_id": "presentation.intent.hospital.day3",
		"route_id": "hospital",
		"timeline_id": "hospital.faint",
		"context": {"kind": "hospital", "day": 3, "source_entry_ids": [], "miss_receipt_ids": []},
		"completion_transaction_id": "completion.hospital.day3",
		"completion_transaction_provenance": {"child_id": "completion.hospital.day3"},
		"command_sha256": "a".repeat(64),
		"physical_token": "narrative_presentation.token",
	}


## Everything a Hospital scene must be incapable of moving.
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
	assert_false(scene.is_presentation_configured(), "a fresh instance owns no port")
	var configured: Dictionary = scene.configure_presentation(_port, _command())
	assert_true(configured.get("ok", false), str(configured))
	assert_eq(int(configured["value"]["port_instance_id"]), _port.get_instance_id())
	assert_true(scene.is_presentation_configured())
	add_child_autofree(scene)


func test_configuration_is_idempotent_and_refuses_a_replacement_port() -> void:
	var scene := _instantiate()
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false))
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false),
		"identical replay is idempotent")
	var replaced: Dictionary = scene.configure_presentation(PORT.new(), _command())
	assert_false(replaced.get("ok", true), "a configured scene never adopts a replacement port")
	assert_eq(replaced.get("code"), &"presentation_port_already_configured")
	add_child_autofree(scene)


func test_an_incomplete_port_or_empty_command_is_refused() -> void:
	var scene := _instantiate()
	assert_eq(scene.configure_presentation(null, _command()).get("code"),
		&"invalid_presentation_port")
	assert_eq(scene.configure_presentation(RefCounted.new(), _command()).get("code"),
		&"invalid_presentation_port")
	assert_eq(scene.configure_presentation(_port, {}).get("code"),
		&"invalid_presentation_command")
	add_child_autofree(scene)


func test_the_scene_holds_only_a_detached_projection() -> void:
	var scene := _instantiate()
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false))
	add_child_autofree(scene)
	var projection: Dictionary = scene.get_presentation_projection()
	projection["route_id"] = "dating"
	assert_eq(str(scene.get_presentation_projection()["route_id"]), "hospital",
		"a caller cannot mutate the scene's copy of the command")


# -------------------------------------------------------------------------------------------------
# ownership: _ready
# -------------------------------------------------------------------------------------------------

func test_ready_mutates_no_gameplay_state() -> void:
	var scene := _instantiate()
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false))
	var before := _owner_snapshot()
	add_child_autofree(scene)
	assert_eq(_owner_snapshot(), before,
		"_ready() touches no stat, day, Schedule, Contacts index, or route context")


func test_an_unconfigured_scene_reaching_the_tree_does_nothing_at_all() -> void:
	# A Hospital scene without a committed presentation intent behind it is a bug. Showing an empty
	# room is a far better failure than inventing a recovery.
	var scene := _instantiate()
	var before := _owner_snapshot()
	add_child_autofree(scene)
	assert_false(scene.is_presentation_configured())
	assert_eq(_owner_snapshot(), before, "an unconfigured scene mutates nothing")
	assert_eq(scene.get_presentation_projection(), {})


# -------------------------------------------------------------------------------------------------
# ownership: input
# -------------------------------------------------------------------------------------------------

func test_button_input_mutates_no_gameplay_state() -> void:
	var scene := _instantiate()
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false))
	add_child_autofree(scene)
	var before := _owner_snapshot()

	var button: Button = scene.get_node("%ContinueButton")
	button.pressed.emit()
	button.pressed.emit()

	assert_eq(_owner_snapshot(), before,
		"the continue button advances no day, applies no recovery, and selects no ending")


func test_button_input_never_advances_the_day_or_enters_an_ending() -> void:
	# The two specific mutations the OLD scene performed, named explicitly so a regression is
	# unmistakable rather than buried in a snapshot diff.
	var scene := _instantiate()
	assert_true(scene.configure_presentation(_port, _command()).get("ok", false))
	add_child_autofree(scene)
	var day_before := int(GameState._run_lifecycle.get_day())

	scene.get_node("%ContinueButton").pressed.emit()

	assert_eq(int(GameState._run_lifecycle.get_day()), day_before, "no day advance")
	assert_eq(String(GameState._run_lifecycle.get_state()), "PLAYING", "no ENDING transition")
	assert_eq(GameState.route_context.get("ending_id", ""), "", "no ending id was selected")


func test_the_scene_exposes_no_mutation_seam() -> void:
	# The scene may hold a port; it may not hand anyone a way to change gameplay through it.
	var scene := _instantiate()
	add_child_autofree(scene)
	for forbidden: String in ["apply_hospital_recovery_and_advance_day", "advance_day",
			"commit_effect_transaction", "prepare_dating_entries", "goto_ending",
			"set_presentation_result", "complete_presentation"]:
		assert_false(scene.has_method(forbidden),
			"HospitalScene must not expose " + forbidden)
