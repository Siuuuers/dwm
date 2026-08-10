extends "res://addons/gut/test.gd"
# dwm-7e6 acceptance: the REAL coordinator + REAL SaveManagerCheckpointPort + REAL SaveManager
# write a genuine disk autosave whose snapshot round-trips. Before real snapshot production this
# path was impossible: the port emitted a {run_id, day} stub and the real checkpoint port rejected
# it with invalid_checkpoint_inputs (coordinator tests only passed via FakeCheckpointPort).

const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const SAVE_MANAGER := preload("res://autoload/SaveManager.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")

var _root := ""
var _manager: Node


func before_each() -> void:
	GameState.reset_game()
	_root = OS.get_environment("DWM_TEST_ROOT").path_join("dwm7e6_disk").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(_root)
	_manager = SAVE_MANAGER.new()
	add_child_autofree(_manager)
	_manager.initialize(STORAGE.new(_root))
	# Real six-participant wiring so a restore genuinely prepares plans rather than failing with
	# TRANSACTION_PARTICIPANTS_NOT_CONFIGURED (dwm-7e6 repair).
	_manager.configure_mutation_gate(GATE.new())
	# The real participants delegate to live autoloads, so those must be initialized too -- in
	# ApplicationBootstrap's dependency order (profile -> localization -> input -> accessibility ->
	# audio -> dialogic), because each later manager reads the profile the earlier ones established.
	_initialize_live_autoloads()
	_manager.configure_restore_participants({
		"run": preload("res://scripts/application/restore/RunRestoreParticipant.gd").new(GameState),
		"profile": preload("res://scripts/application/restore/ProfileRestoreParticipant.gd").new(ProfileManager),
		"localization": preload("res://scripts/application/restore/LocalizationRestoreParticipant.gd").new(LocalizationManager),
		"audio": preload("res://scripts/application/restore/AudioRestoreParticipant.gd").new(AudioManager),
		"route": preload("res://scripts/application/restore/RouteRestoreParticipant.gd").new(SceneRouter),
		"narrative": preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd").new(DialogicBridge),
	})


## Brings the live autoloads the restore participants delegate to into a genuinely initialized
## state, following ApplicationBootstrap's STAGE_ORDER. Each initializer is reported so a harness
## failure surfaces as a named stage rather than an opaque downstream `*_not_ready`.
func _initialize_live_autoloads() -> void:
	var stages: Array = [
		["profile", ProfileManager.initialize(STORAGE.new(_root.path_join("profile")))],
		["localization", LocalizationManager.initialize(ProfileManager)],
		["input", InputManager.initialize(ProfileManager)],
		["accessibility", AccessibilityManager.initialize(ProfileManager)],
		["audio", AudioManager.initialize(ProfileManager)],
		["dialogic", DialogicBridge.initialize()],
	]
	for stage: Array in stages:
		var result: Dictionary = stage[1]
		# Autoloads are process-wide and initialize exactly once, so every before_each after the
		# first legitimately reports already_initialized.
		if str(result.get("code", "")) == "already_initialized":
			continue
		assert_true(result.get("ok", false),
			"autoload stage %s must initialize: %s" % [str(stage[0]), str(result)])


## The participant plans inside a successful prepare_restore_autosave result.
func _participant_plans(prepared: Dictionary) -> Dictionary:
	return ((prepared["value"] as Dictionary)["prepared"] as Dictionary)["participant_plans"]


## The run snapshot the restore would install.
func _restored_snapshot(prepared: Dictionary) -> Dictionary:
	return (_participant_plans(prepared)["run"] as Dictionary)["snapshot"]


func _active_app_id() -> Variant:
	return null


func _content_version() -> int:
	return 1


func _wired() -> Dictionary:
	var run_id := str(GameState._run_lifecycle.to_dict()["run_id"])
	var state_port: Object = STATE_PORT.new(GameState)
	# The same five providers ApplicationBootstrap._configure_day_resolution_providers installs.
	# Without them the port falls back to safe defaults whose empty audio context writes an autosave
	# that cannot be restored -- which is precisely what this suite exists to catch.
	assert_true(state_port.configure_checkpoint_providers({
		"dialogic_checkpoint": Callable(DialogicBridge, "get_current_narrative_checkpoint"),
		"route_id": Callable(SceneRouter, "get_current_route_id"),
		"active_app_id": Callable(self, "_active_app_id"),
		"audio_context": Callable(AudioManager, "get_semantic_audio_context"),
		"content_version": Callable(self, "_content_version"),
	}).get("ok", false), "day-resolution checkpoint providers configured")
	var checkpoint_port: Object = CHECKPOINT_PORT.new(_manager)
	var gate: Object = GATE.new()
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false), "checkpoint port latched")
	_manager._journal.reset(run_id)
	var coordinator: Object = COORDINATOR.new()
	assert_true(coordinator.configure_fatal_latch(gate).get("ok", false), "coordinator latched")
	assert_true(coordinator.configure(state_port, checkpoint_port).get("ok", false), "coordinator configured")
	return {"coordinator": coordinator, "run_id": run_id, "checkpoint_port": checkpoint_port}


func _autosave_text() -> String:
	var path := _root.path_join("autosave.json")
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func test_real_ports_resolve_a_day_without_rejecting_the_snapshot() -> void:
	var wired := _wired()
	var run_id: String = wired["run_id"]
	var result: Dictionary = wired["coordinator"].request_schedule_done("done:%s:day-1" % run_id)
	assert_false(str(result.get("code", "")) == "invalid_checkpoint_inputs",
		"the real checkpoint port must accept real snapshot production: " + str(result))
	assert_true(result.get("ok", false), str(result))


func test_real_day_resolution_writes_a_parsable_disk_autosave() -> void:
	var wired := _wired()
	var run_id: String = wired["run_id"]
	assert_true(wired["coordinator"].request_schedule_done("done:%s:day-1" % run_id).get("ok", false), "day resolved")
	var text := _autosave_text()
	assert_false(text.is_empty(), "a real autosave.json is written to disk")
	if text.is_empty():
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	assert_true(parsed.get("ok", false), "the autosave is strict-parsable: " + str(parsed))


func test_disk_autosave_validates_as_a_save_document() -> void:
	var wired := _wired()
	var run_id: String = wired["run_id"]
	wired["coordinator"].request_schedule_done("done:%s:day-1" % run_id)
	var text := _autosave_text()
	if text.is_empty():
		assert_true(false, "no autosave written")
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	assert_true(validated.get("ok", false), "the written document round-trips through its schema: " + str(validated))


func test_persisted_snapshot_carries_the_live_lifecycle_and_ledger() -> void:
	var wired := _wired()
	var run_id: String = wired["run_id"]
	wired["coordinator"].request_schedule_done("done:%s:day-1" % run_id)
	var text := _autosave_text()
	if text.is_empty():
		assert_true(false, "no autosave written")
		return
	var document: Dictionary = STRICT_JSON.parse_object(text)["value"]
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	assert_eq(str(snapshot["run_id"]), run_id, "the live run id persisted")
	assert_true((snapshot["lifecycle"] as Dictionary).has("ending_plan"), "ending_plan persisted with the lifecycle")
	assert_true(snapshot.has("command_receipts"), "the effect/variable ledger persisted")
	assert_true(snapshot.has("narrative_checkpoint"), "the narrative checkpoint field persisted")


func test_persisted_snapshot_is_restorable_by_the_save_manager() -> void:
	var wired := _wired()
	var run_id: String = wired["run_id"]
	wired["coordinator"].request_schedule_done("done:%s:day-1" % run_id)
	var text := _autosave_text()
	if text.is_empty():
		assert_true(false, "no autosave written")
		return
	var prepared: Dictionary = _manager.prepare_restore_autosave()
	# dwm-7e6 repair: the earlier version asserted only `prepared.has("ok")`, which is trivially
	# true even on total failure -- it proved nothing. Asserting real success exposed two genuine
	# gaps: a restore needs every participant's autoload initialized (ProfileManager ->
	# Localization -> Input -> Accessibility -> Audio -> Dialogic), and the coordinator needs its
	# five checkpoint providers wired, or it writes an autosave with an empty audio context that
	# can never be restored. Both are now part of this harness.
	assert_true(prepared.get("ok", false), "the written autosave genuinely prepares a restore: " + str(prepared))
	if not prepared.get("ok", false):
		return
	var plans := _participant_plans(prepared)
	for participant in ["run", "profile", "localization", "audio", "route", "narrative"]:
		assert_true(plans.has(participant), "every participant prepared a plan: " + participant)
	var snapshot := _restored_snapshot(prepared)
	assert_eq(str(snapshot.get("run_id", "")), str(GameState._run_lifecycle.to_dict()["run_id"]),
		"the restored snapshot is the run we actually persisted")
	assert_true((snapshot.get("lifecycle", {}) as Dictionary).has("ending_plan"),
		"the restored lifecycle carries its ending_plan")


# ---- dwm-7e6 acceptance: the full Days 1-7 walk, not just Day 1 ----
# The issue requires driving the REAL coordinator across every day with the REAL checkpoint port,
# and for Day 7 the ending_plan must survive into the persisted snapshot.

func _drive_days(coordinator: Object, run_id: String, through_day: int) -> Dictionary:
	var results: Array = []
	for day in range(1, through_day + 1):
		var result: Dictionary = coordinator.request_schedule_done("done:%s:day-%d" % [run_id, day])
		results.append({"day": day, "ok": result.get("ok", false), "code": str(result.get("code", ""))})
		if not result.get("ok", false):
			break
	return {"results": results, "last_day": int(GameState._run_lifecycle.get_day()), "state": String(GameState._run_lifecycle.get_state())}


func test_real_coordinator_resolves_every_day_one_through_seven() -> void:
	var wired := _wired()
	var walk := _drive_days(wired["coordinator"], str(wired["run_id"]), 7)
	for entry in walk["results"]:
		assert_true((entry as Dictionary)["ok"],
			"day %d must resolve through the real checkpoint port: %s" % [int((entry as Dictionary)["day"]), str((entry as Dictionary)["code"])])
	assert_eq((walk["results"] as Array).size(), 7, "all seven days were driven")


func test_day_seven_walk_enters_ending_with_a_surviving_ending_plan() -> void:
	var wired := _wired()
	var walk := _drive_days(wired["coordinator"], str(wired["run_id"]), 7)
	assert_eq(str(walk["state"]), "ENDING", "the Day-7 walk enters ENDING")
	assert_eq(int(walk["last_day"]), 7, "day stays 7; there is no Day 8")
	var text := _autosave_text()
	assert_false(text.is_empty(), "the Day-7 ending autosave reaches disk")
	if text.is_empty():
		return
	var document: Dictionary = STRICT_JSON.parse_object(text)["value"]
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	var lifecycle: Dictionary = snapshot["lifecycle"]
	assert_eq(str(lifecycle["state"]), "ENDING", "the persisted lifecycle is in ENDING")
	assert_true(lifecycle["ending_plan"] != null, "the ending_plan survives to disk")
	if lifecycle["ending_plan"] == null:
		return
	var plan: Dictionary = lifecycle["ending_plan"]
	assert_eq(int(plan["source_day"]), 7, "the ending plan is sourced from Day 7")
	assert_eq(str(plan["playback_stage"]), "PRIMARY_PENDING", "playback begins pending, as .7 requires")
	assert_false(str(plan["ending_id"]).is_empty(), "a real primary ending id persisted")


func test_a_day_seven_crash_restores_from_disk_with_the_ending_intact() -> void:
	# The crash case the ending-durability spec exists for: the player reaches Day 7, the process
	# dies, and the game must come back holding the SAME ending plan -- not a fresh run, and not a
	# run stranded mid-resolution.
	var wired := _wired()
	var run_id: String = str(wired["run_id"])
	_drive_days(wired["coordinator"], run_id, 7)
	var live: Dictionary = GameState._run_lifecycle.to_dict()
	assert_eq(str(live["state"]), "ENDING", "the run reached ENDING before the crash")

	# The crash: live state is lost entirely. Only what reached disk survives.
	GameState.reset_game()
	assert_ne(str(GameState._run_lifecycle.to_dict()["state"]), "ENDING", "live state is genuinely gone")

	var prepared: Dictionary = _manager.prepare_restore_autosave()
	assert_true(prepared.get("ok", false), "the Day-7 autosave prepares a restore: " + str(prepared))
	if not prepared.get("ok", false):
		return
	var restored := _restored_snapshot(prepared)
	var lifecycle: Dictionary = restored["lifecycle"]
	assert_eq(str(restored["run_id"]), run_id, "the SAME run comes back, not a fresh one")
	assert_eq(str(lifecycle["state"]), "ENDING", "and it comes back in ENDING")
	assert_eq(int(lifecycle["day"]), 7, "on Day 7")
	assert_true(lifecycle["ending_plan"] != null, "with its ending plan intact")
	if lifecycle["ending_plan"] == null:
		return
	assert_eq(lifecycle["ending_plan"], live["ending_plan"],
		"the recovered ending plan is byte-identical to the one the run produced")
