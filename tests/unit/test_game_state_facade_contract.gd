extends "res://addons/gut/test.gd"

const GAME_STATE_PATH := "res://autoload/GameState.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const CHECKPOINT_PATH := "res://tests/support/FakeCheckpointPort.gd"
const SURFACE_PATH := "res://evidence/phase_2r/runtime/game_state_surface.json"

func _fresh_game_state() -> Node:
	var game_state: Node = load(GAME_STATE_PATH).new()
	game_state.reset_game()
	autofree(game_state)
	return game_state

func test_configure_mutation_gate_matrix_without_side_effects() -> void:
	var game_state := _fresh_game_state()
	var emissions: Array[Dictionary] = []
	var gate: RefCounted = load(GATE_PATH).new()
	gate.capability_changed.connect(func(capability: Dictionary) -> void: emissions.append(capability))
	assert_eq(game_state.configure_mutation_gate(null).get("code"), &"invalid_mutation_gate")
	assert_eq(game_state.configure_mutation_gate(RefCounted.new()).get("code"), &"invalid_mutation_gate")
	var configured: Dictionary = game_state.configure_mutation_gate(gate)
	assert_true(configured["ok"], JSON.stringify(configured))
	assert_eq(configured["value"]["gate_instance_id"], gate.get_instance_id())
	assert_eq(configured["value"]["already_configured"], false)
	assert_eq(configured["receipt"], {})
	var repeat: Dictionary = game_state.configure_mutation_gate(gate)
	assert_true(repeat["ok"], "identical instance is idempotent")
	assert_eq(repeat["value"]["already_configured"], true)
	assert_eq(game_state.configure_mutation_gate(load(GATE_PATH).new()).get("code"),
		&"mutation_gate_already_configured", "replacement rejects")
	assert_eq(emissions.size(), 0, "configuration performs no signal emission")
	assert_false(gate.is_active(), "configuration never mutates the gate")
	assert_eq(game_state.day, 1, "configuration never mutates run state")

func test_day_is_read_only_compatibility() -> void:
	var game_state := _fresh_game_state()
	assert_eq(game_state.day, 1, "day reads from the lifecycle")
	game_state._lifecycle_set_playing_day(5)
	assert_eq(game_state.day, 5, "day changes only through lifecycle commands")
	assert_true(FileAccess.file_exists(SURFACE_PATH), "surface inventory must exist")
	if not FileAccess.file_exists(SURFACE_PATH):
		return
	var parsed := StrictJson.parse_object(FileAccess.get_file_as_string(SURFACE_PATH))
	assert_true(parsed.get("ok", false))
	var day_record: Dictionary = {}
	for record: Dictionary in parsed["value"]["records"]:
		if str(record.get("symbol", "")) == "day":
			day_record = record
	assert_eq(str(day_record.get("disposition", "")), "replace",
		"the inventory reports every direct day-assignment caller for migration")
	assert_true(str(day_record.get("contract_test", "")).length() > 0)

func test_prepare_new_run_snapshot_input_is_pure() -> void:
	var game_state := _fresh_game_state()
	game_state._lifecycle_set_playing_day(4)
	game_state.money = 55
	var live_before: Dictionary = game_state.to_save_dict()
	assert_false(game_state.prepare_new_run_snapshot_input("").get("ok", true), "empty run id rejects")
	assert_false(game_state.prepare_new_run_snapshot_input("run-local").get("ok", true),
		"reused run id rejects")
	var prepared: Dictionary = game_state.prepare_new_run_snapshot_input("run-b")
	assert_true(prepared["ok"], JSON.stringify(prepared))
	var snapshot_input: Dictionary = prepared["value"]["snapshot_input"]
	assert_eq(snapshot_input["lifecycle"], {
		"run_id": "run-b", "day": 1, "state": "PLAYING",
		"active_resolution_plan": null, "ending_plan": null,
	})
	# Shape matches RunSnapshotSchema.build: gameplay bag plus own contacts/schedule/dating/ledgers.
	assert_eq(int(snapshot_input["gameplay"]["money"]), 0, "detached defaults are the reset values")
	assert_eq(snapshot_input["gameplay"]["narrative_variables"], {}, "gameplay carries the narrative bag")
	# Fresh run carries a valid empty stateless contacts bag (dwm-p2r.6), not a bare {}.
	assert_eq(int(snapshot_input["contacts"]["next_sequence"]), 1, "fresh run has default contacts bag")
	assert_eq((snapshot_input["contacts"]["messages"]["priscilla"] as Array).size(), 0, "no invitations yet")
	assert_eq(snapshot_input["committed_schedule"], {
		"schema_version": 1, "day": 1, "registry_fingerprint": null,
		"entries": [], "commit_receipt": null,
	}, "fresh run carries the canonical empty aggregate with no registry fingerprint")
	assert_eq(snapshot_input["dating"], {}, "fresh run has empty dating")
	assert_eq(snapshot_input["applied_effect_transaction_ids"], [], "empty run-scoped ledgers")
	assert_eq(snapshot_input["applied_variable_transaction_ids"], [], "empty run-scoped ledgers")
	assert_false(snapshot_input["gameplay"].has("day"), "day lives in the lifecycle, not the gameplay bag")
	assert_eq(game_state.to_save_dict(), live_before, "live run state is untouched")
	assert_eq(game_state.day, 4, "live day is untouched")

func test_request_schedule_done_delegates_through_production_port() -> void:
	var game_state := _fresh_game_state()
	assert_eq(game_state.request_schedule_done("done:day-1").get("code"),
		&"day_resolution_unconfigured", "unconfigured facade rejects")
	var gate: RefCounted = load(GATE_PATH).new()
	assert_true(game_state.configure_mutation_gate(gate)["ok"])
	var calls: Array[String] = []
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	checkpoint.seed_empty("run-local")
	assert_true(game_state._configure_day_resolution(checkpoint)["ok"])
	var day_signals: Array[int] = []
	game_state.day_changed.connect(func(new_day: int) -> void: day_signals.append(new_day))
	var result: Dictionary = game_state.request_schedule_done("done:day-1")
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["code"], &"plan_complete")
	assert_eq(game_state.day, 2, "the production Schedule Done path advanced the day once")
	assert_true(day_signals.size() > 0, "publications emit committed state through declared signals")
	var resumed: Dictionary = game_state.resume_day_resolution()
	assert_true(resumed.get("ok", false), "resume exposes coordinator results")
	assert_eq(resumed["code"], &"plan_complete")

const TASK4_SCHEDULE_SEAMS: Array[String] = [
	"capture_schedule_commit_state", "prepare_schedule_commit_candidate",
	"commit_schedule_commit_candidate", "rollback_schedule_commit_state",
	"publish_schedule_commit",
]

# Plan 01 Task 4 (dwm-p2r.13): these five seams are facade DELEGATION only. They cover current
# motivation, the canonical committed_schedule and the narrow precondition fingerprint; they are not
# a second validator, and GameStateScheduleCommitPort keeps the public transaction interface.
func test_schedule_commit_seams_are_narrow_reversible_and_silent() -> void:
	var game_state := _fresh_game_state()
	var absent: Array[String] = []
	for seam: String in TASK4_SCHEDULE_SEAMS:
		if not game_state.has_method(seam):
			absent.append(seam)
	assert_eq(absent, [] as Array[String], "the narrow committed-Schedule seams must exist")
	if not absent.is_empty():
		return
	var emissions: Array[String] = []
	for entry: Dictionary in game_state.get_script().get_script_signal_list():
		var signal_name := str(entry.get("name", ""))
		if (entry.get("args", []) as Array).size() == 0:
			game_state.connect(signal_name, func() -> void: emissions.append(signal_name))
		elif (entry.get("args", []) as Array).size() == 1:
			game_state.connect(signal_name, func(_a) -> void: emissions.append(signal_name))

	var captured: Dictionary = game_state.capture_schedule_commit_state()
	assert_true(captured["ok"], JSON.stringify(captured))
	var captured_keys: Array = (captured["value"] as Dictionary).keys()
	captured_keys.sort()
	assert_eq(captured_keys, ["before_fingerprint", "committed_schedule", "motivation"],
		"the capture seam is exactly narrow")
	var aggregate: Dictionary = captured["value"]["committed_schedule"]
	assert_eq(aggregate, {
		"schema_version": 1, "day": 1, "registry_fingerprint": null,
		"entries": [], "commit_receipt": null,
	}, "an uninitialized owner exposes the canonical empty aggregate for its day")
	assert_eq(int(captured["value"]["motivation"]), 7)

	var prepared: Dictionary = game_state.prepare_schedule_commit_candidate(aggregate, 2)
	assert_true(prepared["ok"], JSON.stringify(prepared))
	assert_eq(int(prepared["value"]["candidate"]["motivation"]), 5, "the candidate carries the charge")
	assert_eq(game_state.get_stat("motivation"), 7, "prepare applies nothing")
	assert_false(game_state.prepare_schedule_commit_candidate(aggregate, 8).get("ok", true),
		"the owner refuses a charge it cannot pay")
	assert_false(game_state.prepare_schedule_commit_candidate(aggregate, -1).get("ok", true))
	assert_false(game_state.prepare_schedule_commit_candidate({}, 0).get("ok", true),
		"the seam validates the canonical aggregate it is handed")
	assert_eq(emissions, [] as Array[String], "capture and prepare are silent")

	var committed: Dictionary = game_state.commit_schedule_commit_candidate(prepared["value"]["candidate"])
	assert_true(committed["ok"], JSON.stringify(committed))
	assert_eq(game_state.get_stat("motivation"), 5, "commit changes motivation")
	assert_eq(game_state.capture_schedule_commit_state()["value"]["committed_schedule"], aggregate)
	assert_eq(emissions, [] as Array[String], "commit installs the candidate silently")
	assert_false(game_state.commit_schedule_commit_candidate(prepared["value"]["candidate"]).get("ok", true),
		"a candidate prepared against a stale precondition fingerprint is refused")

	var restored: Dictionary = game_state.rollback_schedule_commit_state({
		"motivation": 7, "committed_schedule": aggregate,
	})
	assert_true(restored["ok"], JSON.stringify(restored))
	assert_eq(restored["value"], {"restored": true})
	assert_eq(game_state.get_stat("motivation"), 7, "rollback restores exactly the backup")
	assert_eq(emissions, [] as Array[String], "rollback is silent")
	assert_false(game_state.rollback_schedule_commit_state({"motivation": 7}).get("ok", true),
		"the backup member set is exact")

	assert_false(game_state.publish_schedule_commit({
		"committed_schedule": aggregate, "schedule_commit_receipt": null,
	}).get("ok", true), "a publication without its commit receipt is refused")
	assert_false(game_state.publish_schedule_commit({
		"committed_schedule": {"schema_version": 1, "day": 2, "registry_fingerprint": null,
			"entries": [], "commit_receipt": null},
		"schedule_commit_receipt": {},
	}).get("ok", true), "a publication the owner does not hold is refused")
	assert_eq(emissions, [] as Array[String], "a refused publication emits nothing")

func test_day7_terminal_via_facade_never_creates_day8() -> void:
	var game_state := _fresh_game_state()
	game_state._lifecycle_set_playing_day(7)
	var resolved: Dictionary = game_state.resolve_day7_ending()
	assert_true(resolved.get("ok", false), JSON.stringify(resolved))
	assert_eq(game_state.day, 7, "no Day 8 exists on any runtime path")
	assert_eq(game_state._run_lifecycle.get_state(), &"ENDING")
	var legacy_eight: Dictionary = {"day": 8, "route_context": {"ending_id": "ending.alone", "epilogue_ending_id": ""}}
	var applied: Dictionary = game_state.apply_save_dict(legacy_eight)
	assert_true(applied.get("ok", false))
	assert_eq(game_state.day, 7, "a legacy Day-8 sentinel migrates to the Day-7 terminal")
	assert_eq(game_state._run_lifecycle.get_state(), &"ENDING")
