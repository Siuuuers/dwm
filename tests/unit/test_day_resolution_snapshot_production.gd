extends "res://addons/gut/test.gd"
# Real snapshot production for coordinator disk checkpoints (dwm-7e6).
#
# GameStateDayResolutionPort.prepare_completion previously emitted a stub {run_id, day}, which the
# real SaveManagerCheckpointPort rejects with invalid_checkpoint_inputs. The coordinator passes that
# field STRAIGHT THROUGH as the whole checkpoint_inputs argument, so it must carry the complete
# CHECKPOINT_INPUT_KEYS bundle built from live GameState capture plus the five injected providers.

const PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const REAL_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const SCHEDULE_RESTORE_FIXTURE := preload("res://tests/support/ScheduleRestoreFixture.gd")


class _Providers extends RefCounted:
	var calls: Array = []
	func narrative_checkpoint() -> Dictionary:
		calls.append("narrative")
		return {"timeline_id": "contact.ordinary.lavinia.day1"}
	func route_id() -> String:
		calls.append("route")
		return "main"
	func active_app_id() -> Variant:
		calls.append("app")
		return null
	func audio_context() -> Dictionary:
		calls.append("audio")
		return {"music_context_id": "main_desktop"}
	func content_version() -> int:
		calls.append("content")
		return 1
	func callables() -> Dictionary:
		return {
			"dialogic_checkpoint": Callable(self, "narrative_checkpoint"),
			"route_id": Callable(self, "route_id"),
			"active_app_id": Callable(self, "active_app_id"),
			"audio_context": Callable(self, "audio_context"),
			"content_version": Callable(self, "content_version"),
		}


func before_each() -> void:
	GameState.reset_game()


func _port() -> Object:
	return PORT.new(GameState)


## Drives the port's FIRST real stage far enough to produce a bundle. prepare_completion now applies
## the transaction to a detached lifecycle, so it requires a genuine active stage -- a synthetic
## transaction id would be exactly the test convenience that let the stub survive.
func _prepared_first_stage(port: Object) -> Dictionary:
	var run_id := str(GameState._run_lifecycle.to_dict()["run_id"])
	assert_true(port.begin_or_resume("done:%s:day-1" % run_id).get("ok", false), "resolution begun")
	var begun: Dictionary = port.begin_next_stage()
	assert_true(begun.get("ok", false), str(begun))
	var stage: Dictionary = begun["value"]["stage"]
	var prepared: Dictionary = port.prepare_completion(str(stage["transaction_id"]), begun["value"]["receipt"])
	assert_true(prepared.get("ok", false), str(prepared))
	return prepared["value"]


func _bundle(port: Object) -> Dictionary:
	return _prepared_first_stage(port)["snapshot_input"]


func _schedule_restore_fixture() -> Dictionary:
	var fixture: Dictionary = SCHEDULE_RESTORE_FIXTURE.create()
	assert_true(fixture.get("ok", false), "schedule-view restore fixture configured")
	if not fixture.get("ok", false):
		return {}
	var lifecycle: Dictionary = GameState._run_lifecycle.to_dict()
	var opened: Dictionary = fixture["value"]["view"].open_day(
		int(lifecycle["day"]), str(lifecycle["causal_day_instance"]))
	assert_true(opened.get("ok", false), "schedule-view fixture opened on the live lifecycle day")
	return fixture


## Walks the real plan to target_stage_id, committing every earlier stage live exactly as the
## coordinator does, and returns the prepared value for the target stage WITHOUT committing it.
func _prepared_at_stage(port: Object, target_stage_id: String) -> Dictionary:
	var run_id := str(GameState._run_lifecycle.to_dict()["run_id"])
	assert_true(port.begin_or_resume("done:%s:day-1" % run_id).get("ok", false), "resolution begun")
	for _iteration in range(64):
		var begun: Dictionary = port.begin_next_stage()
		if not begun.get("ok", false):
			return {}
		var stage: Dictionary = begun["value"]["stage"]
		var prepared: Dictionary = port.prepare_completion(
			str(stage["transaction_id"]), begun["value"]["receipt"])
		if not prepared.get("ok", false):
			return {}
		if str(stage["stage_id"]) == target_stage_id:
			return prepared["value"]
		if not port.commit(prepared["value"]["run_candidate"]).get("ok", false):
			return {}
	return {}


func test_prepare_completion_emits_every_checkpoint_input_key() -> void:
	var bundle := _bundle(_port())
	var keys: Array = bundle.keys()
	keys.sort()
	var expected: Array = REAL_CHECKPOINT_PORT.CHECKPOINT_INPUT_KEYS.duplicate()
	expected.sort()
	assert_eq(keys, expected, "the coordinator passes this straight to the real checkpoint port")


func test_inner_snapshot_input_carries_the_live_lifecycle() -> void:
	var bundle := _bundle(_port())
	var snapshot_input: Dictionary = bundle["snapshot_input"]
	assert_eq(typeof(snapshot_input.get("lifecycle")), TYPE_DICTIONARY, "lifecycle is mandatory for the real port")
	assert_false(str((snapshot_input["lifecycle"] as Dictionary).get("run_id", "")).is_empty(), "run_id present")
	assert_true((snapshot_input["lifecycle"] as Dictionary).has("ending_plan"), "ending_plan travels with the lifecycle")
	for member in ["gameplay", "contacts", "committed_schedule", "dating", "applied_effect_transaction_ids", "applied_variable_transaction_ids", "command_receipts"]:
		assert_true(snapshot_input.has(member), "snapshot input carries " + member)


func test_no_stub_run_id_day_shape_remains() -> void:
	var bundle := _bundle(_port())
	assert_false(bundle.has("day"), "the {run_id, day} stub is gone")
	assert_false(bundle.has("run_id"), "the {run_id, day} stub is gone")


func test_unconfigured_port_still_emits_a_valid_shape() -> void:
	# Existing coordinator tests construct the port without providers; the SHAPE must still be
	# complete so nothing silently regresses to the stub.
	var bundle := _bundle(_port())
	assert_eq(typeof(bundle["dialogic_checkpoint"]), TYPE_DICTIONARY, "default narrative checkpoint")
	assert_false(str(bundle["route_id"]).is_empty(), "a registered default route id")
	assert_eq(typeof(bundle["audio_context"]), TYPE_DICTIONARY, "default audio context")
	assert_true(int(bundle["content_version"]) > 0, "positive content version")


func test_configured_providers_supply_the_five_non_game_state_fields() -> void:
	var providers := _Providers.new()
	var port: Object = _port()
	assert_true(port.configure_checkpoint_providers(providers.callables()).get("ok", false), "providers configured")
	var bundle := _bundle(port)
	assert_eq(bundle["dialogic_checkpoint"], {"timeline_id": "contact.ordinary.lavinia.day1"}, "narrative checkpoint from the bridge")
	assert_eq(str(bundle["route_id"]), "main")
	assert_eq(bundle["active_app_id"], null)
	assert_eq(bundle["audio_context"], {"music_context_id": "main_desktop"})
	assert_eq(int(bundle["content_version"]), 1)
	assert_eq(providers.calls, ["narrative", "route", "app", "audio", "content"], "each provider consulted once, in order")


func test_configure_rejects_wrong_provider_sets_and_replacement() -> void:
	var providers := _Providers.new()
	var port: Object = _port()
	var short_set: Dictionary = providers.callables()
	short_set.erase("route_id")
	assert_false(port.configure_checkpoint_providers(short_set).get("ok", false), "missing provider rejected")
	var extra_set: Dictionary = providers.callables()
	extra_set["extra"] = Callable(providers, "route_id")
	assert_false(port.configure_checkpoint_providers(extra_set).get("ok", false), "extra provider rejected")
	assert_true(port.configure_checkpoint_providers(providers.callables()).get("ok", false), "first valid set accepted")
	assert_true(port.configure_checkpoint_providers(providers.callables()).get("ok", false), "same set is idempotent")
	assert_false(port.configure_checkpoint_providers(_Providers.new().callables()).get("ok", false), "replacement rejected")


func test_bundle_is_detached_from_live_state() -> void:
	var port: Object = _port()
	var bundle := _bundle(port)
	(bundle["snapshot_input"] as Dictionary)["gameplay"]["injected"] = true
	var again := _bundle(port)
	assert_false((again["snapshot_input"] as Dictionary)["gameplay"].has("injected"), "each bundle is a detached copy")


# ---- dwm-7e6 acceptance: the REAL SaveManagerCheckpointPort accepts the produced bundle ----
# Previously it rejected the stub with invalid_checkpoint_inputs; coordinator tests only passed
# because FakeCheckpointPort does not validate input shape.

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SAVE_MANAGER := preload("res://autoload/SaveManager.gd")


func _real_checkpoint_port() -> Object:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("dwm7e6").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = SAVE_MANAGER.new()
	add_child_autofree(manager)
	manager.initialize(STORAGE.new(root))
	var schedule_restore: Dictionary = _schedule_restore_fixture()
	manager._restore_participants = {
		"schedule_view": schedule_restore["value"]["participant"],
	}
	var port: Object = REAL_CHECKPOINT_PORT.new(manager)
	var gate: Object = GATE.new()
	port.configure_fatal_latch(gate)
	# The journal must know the live run before it will issue a sequence for it.
	manager._journal.reset(str(GameState._run_lifecycle.to_dict()["run_id"]))
	return port


func test_real_checkpoint_port_accepts_the_produced_bundle() -> void:
	var bundle := _bundle(_port())
	var prepared: Dictionary = _real_checkpoint_port().prepare(bundle, &"day_start", {"kind": &"none", "reason": &"stage"})
	assert_false(str(prepared.get("code", "")) == "invalid_checkpoint_inputs",
		"the real port must no longer reject the produced bundle: " + str(prepared))
	assert_true(prepared.get("ok", false), str(prepared))
	assert_false(str((prepared.get("value", {}) as Dictionary).get("checkpoint_id", "")).is_empty(), "a real checkpoint id is issued")


func test_day_seven_ending_plan_survives_into_the_prepared_snapshot() -> void:
	# The ending-durability spec's core requirement: the ending_plan must travel with the lifecycle.
	var lifecycle: RefCounted = GameState._run_lifecycle
	var bundle := _bundle(_port())
	var lifecycle_input: Dictionary = (bundle["snapshot_input"] as Dictionary)["lifecycle"]
	assert_true(lifecycle_input.has("ending_plan"), "ending_plan is carried, not dropped")
	assert_eq(str(lifecycle_input["run_id"]), str(lifecycle.to_dict()["run_id"]), "the live run id travels")


# ---- dwm-7e6: the checkpoint records the state its own transaction PRODUCES ----
# prepare_completion used to snapshot the LIVE lifecycle, which had not yet had the stage applied,
# so every stage's checkpoint lagged one stage behind its own transaction: a crash restored to a
# point claiming the work was still pending after it had durably happened. The transaction is
# capture backups -> prepare a DETACHED completed lifecycle -> commit the checkpoint -> commit that
# exact lifecycle live, so live state is never mutated before the checkpoint is durable.


## The lifecycle the checkpoint would durably record, out of a prepared value.
func _checkpointed_lifecycle(prepared: Dictionary) -> Dictionary:
	return ((prepared["snapshot_input"] as Dictionary)["snapshot_input"] as Dictionary)["lifecycle"]


func test_checkpoint_carries_the_post_completion_lifecycle() -> void:
	var port: Object = _port()
	var live_day := int(GameState._run_lifecycle.get_day())
	var prepared := _prepared_at_stage(port, "increment_day")
	assert_false(prepared.is_empty(), "the walk reached increment_day")
	var lifecycle := _checkpointed_lifecycle(prepared)
	assert_eq(int(lifecycle["day"]), live_day + 1, "the checkpoint records the day this stage produces")
	assert_eq(int(GameState._run_lifecycle.get_day()), live_day,
		"and live state stays untouched until the checkpoint is durable")


func test_commit_applies_the_exact_lifecycle_the_checkpoint_recorded() -> void:
	# The durable record and the live state must be the SAME state, not two independent derivations.
	var port: Object = _port()
	var prepared := _prepared_at_stage(port, "increment_day")
	assert_false(prepared.is_empty(), "the walk reached increment_day")
	var checkpointed := _checkpointed_lifecycle(prepared)
	assert_true(port.commit(prepared["run_candidate"]).get("ok", false), "the stage commits live")
	assert_eq(GameState._run_lifecycle.to_dict(), checkpointed,
		"live state is exactly what was durably recorded")


func test_a_rejected_stage_never_reaches_live_state() -> void:
	# The detached clone is also the port's validation seam: a transaction the plan does not know
	# must fail during prepare, before any checkpoint is written and before live state moves.
	# (Receipt-envelope shape is the coordinator's guard, checked before it ever calls this port.)
	var port: Object = _port()
	var run_id := str(GameState._run_lifecycle.to_dict()["run_id"])
	assert_true(port.begin_or_resume("done:%s:day-1" % run_id).get("ok", false), "resolution begun")
	port.begin_next_stage()
	var before: Dictionary = GameState._run_lifecycle.to_dict()
	var prepared: Dictionary = port.prepare_completion(
		"impostor:transaction", {"owner_id": "day_resolution_coordinator", "kind": "day_lock", "value": {"locked": true}})
	assert_false(prepared.get("ok", false), "an unknown transaction is refused")
	assert_eq(str(prepared.get("code")), "unknown_transaction", "typed refusal")
	assert_eq(GameState._run_lifecycle.to_dict(), before, "and live state is untouched")


# ---- dwm-7e6: the source_day relaxation is BOUNDED ----
# An active plan may legally trail the day by exactly one (the increment_day -> unlock_day window).
# Anything wider is still a corrupt bundle; these guard against the relaxation being widened later.

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")


func _snapshot_with_active_plan() -> Dictionary:
	var port: Object = _port()
	assert_true(port.begin_or_resume("done:%s:day-1" % str(GameState._run_lifecycle.to_dict()["run_id"])).get("ok", false), "resolution begun")
	var bundle := _bundle(port)
	var schedule_restore: Dictionary = _schedule_restore_fixture()
	var schedule_view: Dictionary = schedule_restore["value"]["view"].snapshot()
	assert_true(schedule_view.get("ok", false), "the schema fixture carries a real saved Schedule view")
	bundle["snapshot_input"]["schedule_view"] = schedule_view["value"]["view"]
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		bundle["snapshot_input"], bundle["dialogic_checkpoint"], str(bundle["route_id"]),
		bundle["active_app_id"], bundle["audio_context"], int(bundle["content_version"]), 1)
	assert_true(built.get("ok", false), "a snapshot with an active plan builds: " + str(built))
	return built["value"]["snapshot"]


func _validate_with_day(snapshot: Dictionary, day: int) -> Dictionary:
	var candidate: Dictionary = snapshot.duplicate(true)
	(candidate["lifecycle"] as Dictionary)["day"] = day
	return RUN_SNAPSHOT_SCHEMA.validate(candidate)


func test_active_plan_may_trail_the_day_by_exactly_one() -> void:
	var snapshot := _snapshot_with_active_plan()
	var source_day := int((snapshot["lifecycle"] as Dictionary)["day"])
	assert_true(_validate_with_day(snapshot, source_day).get("ok", false), "source_day == day is legal")
	# This plan's increment_day is still pending, so a one-day trail must NOT be accepted.
	assert_false(_validate_with_day(snapshot, source_day + 1).get("ok", false),
		"a trail is illegal until increment_day completes")
	# The POSITIVE post-increment case is proven end-to-end by the real Days 1-7 walk in
	# test_day_resolution_disk_durability.gd, which completes increment_day through production
	# receipts. Synthesising a half-completed plan here would violate from_dict's ordering scan.


func test_active_plan_trailing_by_two_still_rejects() -> void:
	var snapshot := _snapshot_with_active_plan()
	var source_day := int((snapshot["lifecycle"] as Dictionary)["day"])
	var result := _validate_with_day(snapshot, source_day + 2)
	assert_false(result.get("ok", false), "a two-day gap is still a corrupt bundle")
	assert_eq(str(result.get("code")), "invalid_lifecycle", "typed lifecycle rejection")


func test_active_plan_ahead_of_the_day_still_rejects() -> void:
	var snapshot := _snapshot_with_active_plan()
	var source_day := int((snapshot["lifecycle"] as Dictionary)["day"])
	assert_false(_validate_with_day(snapshot, source_day - 1).get("ok", false), "a plan ahead of the day is corrupt")


# ---- dwm-7e6: ONE authority for the active-plan day window ----
# A snapshot that RunSnapshotSchema accepts must also survive RunLifecycle restore. Two validators
# disagreeing would let the game write a save it can never load.

const RUN_LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const DAY_RESOLUTION_PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")


func test_both_validators_share_one_active_plan_day_window() -> void:
	for offset: int in ([-1, 0, 1, 2] as Array[int]):
		var source_day: int = 3
		var day: int = source_day + offset
		var plan_data := {"stages": [{"stage_id": "increment_day", "state": "completed"}]}
		var legal: bool = DAY_RESOLUTION_PLAN.is_active_source_day_legal(source_day, day, plan_data)
		var schema_error: String = DAY_RESOLUTION_PLAN.active_source_day_error(source_day, day, plan_data)
		assert_eq(legal, schema_error.is_empty(), "the predicate and the error agree at offset %d" % offset)
	# STAGE-AWARE: the one-day trail is legal only when increment_day has completed in that plan.
	var incremented := {"stages": [{"stage_id": "increment_day", "state": "completed"}]}
	var not_incremented := {"stages": [{"stage_id": "increment_day", "state": "pending"}]}
	assert_true(DAY_RESOLUTION_PLAN.is_active_source_day_legal(3, 3), "same day is legal")
	assert_true(DAY_RESOLUTION_PLAN.is_active_source_day_legal(3, 4, incremented), "legal after increment_day completed")
	assert_false(DAY_RESOLUTION_PLAN.is_active_source_day_legal(3, 4, not_incremented), "NOT legal merely because the numbers differ by one")
	assert_false(DAY_RESOLUTION_PLAN.is_active_source_day_legal(3, 5, incremented), "a two-day gap is corrupt")
	assert_false(DAY_RESOLUTION_PLAN.is_active_source_day_legal(3, 2, incremented), "a plan ahead of the day is corrupt")


func test_a_snapshot_the_schema_accepts_also_restores_through_run_lifecycle() -> void:
	var snapshot := _snapshot_with_active_plan()
	var source_day := int((snapshot["lifecycle"] as Dictionary)["day"])
	# The post-increment window: previously this passed the schema and failed lifecycle restore.
	# Both validators must agree. With increment_day still pending, BOTH must reject a one-day
	# trail -- the asymmetry this test exists to prevent is disagreement, in either direction.
	var candidate: Dictionary = snapshot.duplicate(true)
	(candidate["lifecycle"] as Dictionary)["day"] = source_day + 1
	var schema_ok: bool = RUN_SNAPSHOT_SCHEMA.validate(candidate).get("ok", false)
	var lifecycle: RefCounted = RUN_LIFECYCLE.new()
	var lifecycle_ok: bool = lifecycle.prepare_restore(candidate["lifecycle"]).get("ok", false)
	assert_eq(schema_ok, lifecycle_ok, "schema and lifecycle agree on the same bundle")
	assert_false(schema_ok, "and both reject a trail before increment_day completes")


func test_both_validators_reject_a_two_day_gap() -> void:
	var snapshot := _snapshot_with_active_plan()
	var source_day := int((snapshot["lifecycle"] as Dictionary)["day"])
	var candidate: Dictionary = snapshot.duplicate(true)
	(candidate["lifecycle"] as Dictionary)["day"] = source_day + 2
	assert_false(RUN_SNAPSHOT_SCHEMA.validate(candidate).get("ok", false), "the schema rejects it")
	var lifecycle: RefCounted = RUN_LIFECYCLE.new()
	assert_false(lifecycle.prepare_restore(candidate["lifecycle"]).get("ok", false), "and so does RunLifecycle")


func test_daily_reset_is_detached_checkpointed_and_reversible() -> void:
	GameState.minesweeper_rounds_left = 0
	GameState.minesweeper_app_rounds_finished_today = 2
	GameState.set_stat("motivation", 1)
	GameState.condition_streak_days = 1
	var port: Object = _port()
	var value := _prepared_at_stage(port, "reset_day_scope")
	assert_false(value.is_empty())
	if value.is_empty(): return
	var gameplay: Dictionary = value.snapshot_input.snapshot_input.gameplay
	assert_eq(GameState.minesweeper_rounds_left, 0, "prepare does not mutate live resources")
	assert_eq(gameplay.minesweeper_rounds_left, 2, "checkpoint records reset resources")
	assert_eq(gameplay.minesweeper_app_rounds_finished_today, 0)
	assert_eq(gameplay.stats.motivation, 7)
	assert_eq(gameplay.condition_effects_today, ["sequela"], "uncleared condition carries once")
	assert_eq(gameplay.condition_streak_days, 0)
	var backup: Dictionary = port.capture().value.backup
	assert_true(port.commit(value.run_candidate).get("ok", false))
	assert_eq(GameState.capture_run_snapshot_input().gameplay, gameplay, "live commit matches saved projection")
	assert_true(port.rollback(backup).get("ok", false))
	assert_eq(GameState.minesweeper_rounds_left, 0)
	assert_eq(GameState.get_stat("motivation"), 1)
	assert_eq(GameState.condition_streak_days, 1)


func test_daily_reset_without_carried_condition_clears_today_effects() -> void:
	GameState.condition_effects_today = ["sequela"]
	GameState.condition_streak_days = 0
	var projected: Dictionary = GameState.capture_new_day_gameplay()
	assert_eq(projected.condition_effects_today, [])
	assert_eq(GameState.condition_effects_today, ["sequela"], "pure projection")


func test_schedule_condition_is_detached_checkpointed_and_rolls_back_with_the_stage() -> void:
	GameState.set_stat("pressure", 10)
	GameState.set_stat("health", 5)
	GameState.condition_effects_today.assign(["sequela"])
	var port := _port()
	var prepared := _prepared_at_stage(port, "commit_outcomes")
	assert_false(prepared.is_empty())
	if prepared.is_empty(): return
	var backup: Dictionary = port.capture().value.backup
	assert_false(GameState.pending_hospital, "preparation does not trigger Hospital live")
	assert_eq(GameState.get_stat("pressure"), 10)
	var candidate: Dictionary = prepared.run_candidate.gameplay
	assert_true(candidate.pending_hospital, "either danger boundary with carried sequela triggers")
	assert_eq(candidate.stats.pressure, 9)
	assert_eq(candidate.condition_resolved_day, 1)
	assert_eq(prepared.snapshot_input.snapshot_input.gameplay, candidate, "disk candidate includes the exact condition result")
	assert_true(port.commit(prepared.run_candidate).get("ok", false))
	assert_true(GameState.pending_hospital)
	var once: Dictionary = GameState.capture_run_snapshot_input().gameplay
	assert_true(port.commit(prepared.run_candidate).get("ok", false))
	assert_eq(GameState.capture_run_snapshot_input().gameplay, once, "absolute retry cannot charge penalty twice")
	assert_true(port.rollback(backup).get("ok", false))
	assert_false(GameState.pending_hospital)
	assert_eq(GameState.get_stat("pressure"), 10)


func test_schedule_condition_requires_carried_sequela_and_day7_bypasses_it() -> void:
	GameState.set_stat("pressure", 10)
	GameState.set_stat("health", 0)
	var source: Dictionary = GameState.capture_run_snapshot_input().gameplay
	var first: Dictionary = PORT._prepare_schedule_condition_gameplay(source, 1)
	assert_false(first.pending_hospital, "new danger alone cannot invent hospitalization")
	assert_eq(first.condition_streak_days, 1)
	assert_eq(source.stats.pressure, 10, "preparation is detached")
	var carried := source.duplicate(true)
	carried.condition_effects_today.assign(["sequela"])
	assert_eq(PORT._prepare_schedule_condition_gameplay(carried, 7), carried, "Day7 Done never evaluates a new condition")
	carried.condition_resolved_day = 1
	assert_eq(PORT._prepare_schedule_condition_gameplay(carried, 1), carried, "already resolved day is not reevaluated")
