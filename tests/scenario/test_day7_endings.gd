extends "res://addons/gut/test.gd"

# Resumable ending playback (dwm-p2r.7 Task 6, req.ending.playback). EndingScene starts the
# current command through an injected playback port and advances the stage ONLY from a matching
# playback_completed callback -- never on start. .7 proves this with recording fakes; .8 supplies
# the real Dialogic-backed port.

class FakeEndingStatePort:
	extends RefCounted
	var completion_calls: Array[Dictionary] = []
	func request_next_ending_command() -> Dictionary:
		return {"ok": true, "code": &"play_ending", "value": {
			"kind": &"play_ending", "ending_id": "ending.alone",
			"playback_context": {
				"playback_id": "run-1:primary",
				"transaction_id": "run-1:primary:complete",
				"expected_stage": &"PRIMARY_PENDING",
				"role": &"primary",
			}}, "receipt": {}}
	func complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary:
		completion_calls.append({"transaction_id": transaction_id, "expected_stage": expected_stage, "receipt": receipt.duplicate(true)})
		return {"ok": true, "code": &"ok", "value": {}, "receipt": receipt}

class FakeEndingPlaybackPort:
	extends RefCounted
	signal playback_completed(completion: Dictionary)
	signal playback_failed(failure: Dictionary)
	var starts: Array[Dictionary] = []
	func is_ready() -> bool:
		return true
	func start_ending_id(ending_id: String, context: Dictionary = {}) -> Dictionary:
		starts.append({"ending_id": ending_id, "context": context.duplicate(true)})
		return {"ok": true, "code": &"started", "value": {}, "receipt": {
			"playback_id": context["playback_id"],
			"transaction_id": context["transaction_id"],
			"expected_stage": context["expected_stage"],
			"role": context["role"],
			"ending_id": ending_id,
			"playback_token": "fake-token-1",
			"started": true,
		}}

func _completion() -> Dictionary:
	return {
		"playback_id": "run-1:primary",
		"ending_id": "ending.alone",
		"expected_stage": &"PRIMARY_PENDING",
		"transaction_id": "run-1:primary:complete",
		"timeline_completion_receipt_id": "timeline:alone:complete",
		"outcome": &"completed",
	}

func test_stage_does_not_advance_until_matching_playback_completed() -> void:
	var scene: Node = load("res://scripts/ui/EndingScene.gd").new()
	add_child_autofree(scene)
	var state := FakeEndingStatePort.new()
	var playback := FakeEndingPlaybackPort.new()
	assert_true(scene.configure_ending_ports(state, playback).get("ok", false))
	assert_true(scene.resume_ending().get("ok", false))
	assert_eq(playback.starts.size(), 1)
	assert_eq(playback.starts[0]["context"], {
		"playback_id": "run-1:primary",
		"transaction_id": "run-1:primary:complete",
		"expected_stage": &"PRIMARY_PENDING",
		"role": &"primary",
	})
	assert_eq(state.completion_calls.size(), 0, "start must not advance the stage")
	playback.playback_completed.emit(_completion())
	assert_eq(state.completion_calls.size(), 1, "a matching completion advances the stage exactly once")
	assert_eq(state.completion_calls[0]["transaction_id"], "run-1:primary:complete")
	assert_eq(state.completion_calls[0]["expected_stage"], &"PRIMARY_PENDING")

func test_mismatched_completion_does_not_advance() -> void:
	var scene: Node = load("res://scripts/ui/EndingScene.gd").new()
	add_child_autofree(scene)
	var state := FakeEndingStatePort.new()
	var playback := FakeEndingPlaybackPort.new()
	scene.configure_ending_ports(state, playback)
	scene.resume_ending()
	var wrong := _completion()
	wrong["transaction_id"] = "run-1:primary:WRONG"
	playback.playback_completed.emit(wrong)
	assert_eq(state.completion_calls.size(), 0, "a completion that does not match the pending command is ignored")

func test_duplicate_completion_advances_only_once() -> void:
	var scene: Node = load("res://scripts/ui/EndingScene.gd").new()
	add_child_autofree(scene)
	var state := FakeEndingStatePort.new()
	var playback := FakeEndingPlaybackPort.new()
	scene.configure_ending_ports(state, playback)
	scene.resume_ending()
	playback.playback_completed.emit(_completion())
	playback.playback_completed.emit(_completion())
	assert_eq(state.completion_calls.size(), 1, "a duplicate identical completion returns the stored receipt, no re-advance")

func test_configure_rejects_replacement_while_a_command_is_pending() -> void:
	var scene: Node = load("res://scripts/ui/EndingScene.gd").new()
	add_child_autofree(scene)
	var state := FakeEndingStatePort.new()
	var playback := FakeEndingPlaybackPort.new()
	scene.configure_ending_ports(state, playback)
	scene.resume_ending()
	var replaced: Dictionary = scene.configure_ending_ports(FakeEndingStatePort.new(), FakeEndingPlaybackPort.new())
	assert_false(replaced.get("ok", true), "ports cannot be swapped while a command is pending")

# ---- Table-driven coverage of every canonical primary (plan-04 Step 6.4) ----
# Drives the REAL GameState ending facade for each primary, with and without the inter-friend
# epilogue, from PRIMARY_PENDING to COMPLETED. Also proves each intermediate stage is a resumable
# save point. This is verification of existing behaviour, not new logic.

const PRIMARIES: Array[String] = [
	"ending.alone",
	"ending.priscilla.sweet", "ending.priscilla.dark",
	"ending.lavinia.sweet", "ending.lavinia.dark",
	"ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.special",
]

func _init_profile() -> Node:
	var profile := get_tree().root.get_node_or_null("ProfileManager")
	if profile == null:
		return null
	var ops: RefCounted = load("res://tests/support/FakeFileOps.gd").new()
	profile.call(&"initialize", load("res://scripts/infrastructure/storage/JsonFileStorage.gd").new("day7-table/root", ops))
	return profile

func _enter(primary: String, epilogue: String, run_id: String) -> void:
	# A fresh run id keeps each case's gallery transactions isolated (the ledger is retained across
	# reset_gallery), then enter ENDING directly with the chosen plan.
	# Plan 02 Task 6 (dwm-p2r.32): branch_id/desktop_timeline_generation/causal_day_instance/receipt
	# arrive already allocated in production; this test supplies a self-consistent placeholder.
	var receipt := {"receipt_id": "issuer_receipt.fixture-causal-day-%s" % run_id, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": "causal-day-%s" % run_id, "numeric_value": null}
	GameState._run_lifecycle.reset(run_id, "branch-%s" % run_id, 0, "causal-day-%s" % run_id,
		{"causal_day_instance_issuer_receipt": receipt}, false)
	GameState._lifecycle_set_playing_day(7)
	var entered: Dictionary = GameState._run_lifecycle.enter_ending({
		"ending_id": primary, "epilogue_ending_id": epilogue,
		"source_day": 7, "playback_stage": "PRIMARY_PENDING", "playback_receipts": {},
	})
	assert_true(entered.get("ok", false), "enter_ending %s: %s" % [primary, entered])

func _advance_current() -> Dictionary:
	# Reads the live command and feeds it a matching completion (play_ending needs a receipt).
	var cmd: Dictionary = GameState.request_next_ending_command()
	if not cmd.get("ok", false):
		return cmd
	var value: Dictionary = cmd["value"]
	if value.has("playback_context"):
		return GameState.complete_ending_playback_stage(
			str(value["playback_context"]["transaction_id"]),
			value["playback_context"]["expected_stage"], {"outcome": "completed"})
	return GameState.complete_ending_playback_stage("", value["expected_stage"], {})

func _drive_to_completion() -> Dictionary:
	var last := {"ok": false}
	for _i in range(5):
		if GameState._run_lifecycle.get_state() == &"COMPLETED":
			return last
		last = _advance_current()
		if not last.get("ok", false):
			return last
	return last

func test_every_primary_and_epilogue_variant_completes_to_the_menu() -> void:
	var profile := _init_profile()
	if profile == null:
		return
	var case_index := 0
	for primary: String in PRIMARIES:
		for epilogue: String in ["", "ending.priscilla_lavinia"]:
			profile.reset_gallery()
			_enter(primary, epilogue, "table-%d" % case_index)
			case_index += 1
			var label := "%s + [%s]" % [primary, epilogue]
			var finished: Dictionary = _drive_to_completion()
			assert_true(finished.get("ok", false), "walk completes for %s: %s" % [label, finished])
			assert_eq(str((finished.get("value", {}) as Dictionary).get("route", "")), "menu", "routes to menu for %s" % label)
			assert_eq(GameState._run_lifecycle.get_state(), &"COMPLETED", "COMPLETED for %s" % label)
			assert_eq(GameState.day, 7, "day stays 7 for %s" % label)
			assert_true(profile.has_gallery_unlock(primary), "primary recorded for %s" % label)
			var expected_count := 1
			if not epilogue.is_empty():
				assert_true(profile.has_gallery_unlock(epilogue), "epilogue recorded for %s" % label)
				expected_count = 2
			assert_eq((profile.get_profile_snapshot()["gallery_unlocks"] as Array).size(), expected_count,
				"exactly %d canonical gallery id(s) for %s" % [expected_count, label])

func test_resume_at_every_stage_reproduces_the_same_next_command() -> void:
	# plan-04 Step 6.4: at each playback stage a serialize/restore round-trip resumes to the SAME
	# next command -- no remaining action is lost or replayed. Representative with-epilogue case.
	var profile := _init_profile()
	if profile == null:
		return
	profile.reset_gallery()
	_enter("ending.sylvia.special", "ending.priscilla_lavinia", "resume-run")
	for stage: String in ["PRIMARY_PENDING", "PRIMARY_PLAYED", "EPILOGUE_PLAYED", "GALLERY_RECORDED"]:
		var before: Dictionary = GameState.request_next_ending_command()
		assert_true(before.get("ok", false), "a command is available at %s" % stage)
		var backup: Dictionary = GameState.capture_restore_state()["value"]["backup"]
		GameState.rollback_restore_silent(backup)
		var after: Dictionary = GameState.request_next_ending_command()
		assert_eq(after["value"], before["value"], "the same command resumes after a round-trip at %s" % stage)
		assert_true(_advance_current().get("ok", false), "advance from %s" % stage)
	assert_eq(GameState._run_lifecycle.get_state(), &"COMPLETED", "the resumed walk reaches COMPLETED")
	assert_true(profile.has_gallery_unlock("ending.sylvia.special"), "primary recorded")
	assert_true(profile.has_gallery_unlock("ending.priscilla_lavinia"), "epilogue recorded")
