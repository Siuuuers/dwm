extends "res://addons/gut/test.gd"

const COORDINATOR_PATH := "res://scripts/application/run/DayResolutionCoordinator.gd"
const STATE_PATH := "res://tests/support/FakeDayResolutionStatePort.gd"
const CHECKPOINT_PATH := "res://tests/support/FakeCheckpointPort.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const DAY_ADVANCE_PATH := "res://scripts/application/run/CausalDayAdvanceIdentityPort.gd"
const PRESENTATION_PORT_PATH := "res://tests/support/FakePresentationPort.gd"
const PRESENTATION_ROUTER_PATH := "res://tests/support/FakePresentationRouter.gd"

func _all_exist() -> bool:
	for path: String in [COORDINATOR_PATH, STATE_PATH, CHECKPOINT_PATH, GATE_PATH]:
		if not ResourceLoader.exists(path, "Script"):
			return false
	return true

## `configure_day_advance` mirrors production: ApplicationBootstrap always installs the shared
## advance-identity port, so a Days 1-6 walk can reach increment_day. Only the fail-closed case
## deliberately leaves it out.
func _wired(day: int, configure_day_advance: bool = true) -> Dictionary:
	var calls: Array[String] = []
	var state: RefCounted = load(STATE_PATH).new(calls)
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	state.seed_playing_day("run-1", day, [])
	checkpoint.seed_empty("run-1")
	var gate: RefCounted = load(GATE_PATH).new()
	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	assert_true(coordinator.configure(state, checkpoint, gate)["ok"])
	var day_advance_port: Variant = null
	if configure_day_advance and ResourceLoader.exists(DAY_ADVANCE_PATH, "Script"):
		day_advance_port = load(DAY_ADVANCE_PATH).new()
		assert_true(coordinator.configure_day_advance_identity_port(day_advance_port)["ok"])
	return {"coordinator": coordinator, "state": state, "checkpoint": checkpoint, "gate": gate,
		"calls": calls, "day_advance_port": day_advance_port}

func test_checkpoint_commit_failure_rolls_back_without_publication() -> void:
	for path in [COORDINATOR_PATH, STATE_PATH, CHECKPOINT_PATH]:
		assert_true(ResourceLoader.exists(path, "Script"), path + " must exist")
		if not ResourceLoader.exists(path, "Script"):
			return
	var calls: Array[String] = []
	var state: RefCounted = load(STATE_PATH).new(calls)
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	state.seed_playing_day("run-1", 3, [])
	checkpoint.seed_empty("run-1")
	checkpoint.set_failure(&"commit_after_mutation")
	var state_before: Dictionary = state.peek_state()
	var checkpoint_before: Dictionary = checkpoint.peek_state()
	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	assert_true(coordinator.configure(state, checkpoint, load(GATE_PATH).new())["ok"])
	var result: Dictionary = coordinator.request_schedule_done("done:run-1:day-3")
	assert_false(result["ok"])
	assert_eq(result["code"], &"checkpoint_commit_failed")
	assert_eq(state.peek_state(), state_before)
	assert_eq(checkpoint.peek_state(), checkpoint_before)
	assert_eq(state.get_publication_count(), 0)
	assert_eq(calls, [
		"state.begin_or_resume", "state.begin_next_stage",
		"state.capture", "checkpoint.capture",
		"state.prepare_completion", "checkpoint.prepare",
		"checkpoint.commit", "checkpoint.rollback",
	])

func test_configuration_matrix_and_gate_identity() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	var calls: Array[String] = []
	var state: RefCounted = load(STATE_PATH).new(calls)
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	# The THREE-OWNER seam (Plan 01 Task 6 Step 6.5, dwm-p2r.13). The gate no longer arrives through
	# a separate configure_fatal_latch() call, so there is no longer a half-owned state in which a
	# state port is retained but no gate is -- every owner is validated and adopted together.
	var gate: RefCounted = load(GATE_PATH).new()
	assert_eq(coordinator.configure(state, checkpoint, null).get("code"), &"invalid_mutation_gate")
	assert_eq(coordinator.configure(state, checkpoint, RefCounted.new()).get("code"),
		&"invalid_mutation_gate")
	assert_eq(coordinator.configure(null, checkpoint, gate).get("code"), &"invalid_state_port")
	assert_eq(coordinator.configure(state, null, gate).get("code"), &"invalid_checkpoint_port")
	# Every rejection above must have left the coordinator wholly unconfigured, not partly owned.
	assert_eq(coordinator.verify_configuration(state, checkpoint, gate).get("code"),
		&"day_resolution_coordinator_unconfigured",
		"a refused configure retains nothing at all")

	var configured: Dictionary = coordinator.configure(state, checkpoint, gate)
	assert_true(configured["ok"])
	assert_eq(configured["value"]["gate_instance_id"], gate.get_instance_id())
	assert_eq(configured["value"]["already_configured"], false)
	var repeat: Dictionary = coordinator.configure(state, checkpoint, gate)
	assert_true(repeat["ok"], "the identical three-owner replay is idempotent")
	assert_eq(repeat["value"]["already_configured"], true)
	for replacement: Array in [[state, checkpoint, load(GATE_PATH).new()],
			[load(STATE_PATH).new(calls), checkpoint, gate],
			[state, load(CHECKPOINT_PATH).new(calls), gate]]:
		assert_eq(coordinator.configure(replacement[0], replacement[1], replacement[2]).get("code"),
			&"day_resolution_coordinator_already_configured",
			"a changed owner in any position is refused before mutation")

	# verify_configuration COMPARES and returns only primitives; it never hands an owner back.
	assert_eq(coordinator.verify_configuration(state, checkpoint, gate),
		{"ok": true, "code": &"ok", "value": {"configured": true}, "receipt": {}},
		"the exact primitive master envelope")
	assert_eq(coordinator.verify_configuration(load(STATE_PATH).new(calls), checkpoint, gate).get("code"),
		&"day_resolution_coordinator_owner_mismatch")
	assert_false(coordinator.has_method("get_state_port"),
		"the private-bag accessor is removed, not merely unused")
	assert_eq(coordinator.request_schedule_done("").get("code"), &"invalid_command_id")

func test_day3_full_resolution_reaches_plan_complete() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3)
	var result: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["code"], &"plan_complete")
	assert_true(str(result["value"]["checkpoint_id"]).begins_with("run-1:"))
	assert_eq(wired["state"].peek_state()["lifecycle"]["day"], 4, "day advanced once")
	assert_true(wired["state"].get_publication_count() > 0, "successful stages publish")
	var replay: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	assert_true(replay.get("ok", false), "repeated Done with the same command is idempotent")
	assert_eq(replay["code"], &"plan_complete")
	assert_eq(wired["state"].peek_state()["lifecycle"]["day"], 4, "replay never advances the day again")

func test_registered_command_pause_and_completion() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3)
	wired["state"].set_registered_stage("hospital_if_triggered")
	var paused: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	assert_true(paused.get("ok", false), JSON.stringify(paused))
	assert_eq(paused["code"], &"await_registered_command")
	var command: Dictionary = paused["value"]["command"]
	assert_eq(command["stage_id"], "hospital_if_triggered")
	var wrong_owner := {"owner_id": "impostor", "kind": "hospital_resolution",
		"value": {"required": false, "route_receipt_id": null, "prevented_entry_id": null}}
	assert_false(wired["coordinator"].complete_route_stage(
		str(command["transaction_id"]), wrong_owner).get("ok", true), "owner mismatch rejects")
	wired["state"].set_registered_stage("")
	# Task 7 (dwm-p2r.14): Hospital is owned by HospitalRules and reports the FULL supersession
	# set, not a single "prevented" entry.
	# dwm-p2r.18: a Hospital stage additionally records the presentation completion it checkpointed,
	# and null is the honest value for a Hospital that presented nothing.
	var receipt := {"owner_id": "hospital_rules", "kind": "hospital_resolution",
		"value": {"required": false, "date_schedule_entry_ids": [],
			"superseded_entry_ids": [], "witness_entry_id": null,
			"presentation_completion_receipt": null}}
	var finished: Dictionary = wired["coordinator"].complete_route_stage(
		str(command["transaction_id"]), receipt)
	assert_true(finished.get("ok", false), JSON.stringify(finished))
	assert_eq(finished["code"], &"plan_complete")
	assert_eq(wired["state"].peek_state()["lifecycle"]["day"], 4)

func test_recoverable_failures_restore_pre_command_state() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	for phase: StringName in [&"prepare_completion", &"commit", &"publish"]:
		var wired := _wired(2)
		wired["state"].set_failure(phase)
		var state_before: Dictionary = wired["state"].peek_state()
		var checkpoint_before: Dictionary = wired["checkpoint"].peek_state()
		var result: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-2")
		assert_false(result.get("ok", true), String(phase))
		assert_eq(wired["state"].peek_state(), state_before, String(phase) + " restores state")
		assert_eq(wired["checkpoint"].peek_state(), checkpoint_before, String(phase) + " restores checkpoint")
		assert_eq(wired["state"].get_publication_count(), 0, String(phase) + " publishes nothing")
		if phase == &"prepare_completion":
			assert_false("state.rollback" in (wired["calls"] as Array[String]),
				"prepare failure performs no rollback")
		else:
			assert_true("state.rollback" in (wired["calls"] as Array[String]),
				String(phase) + " failure rolls state back")

func test_rollback_failure_latches_shared_gate_and_returns_fatal() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(2)
	var gate: RefCounted = wired["gate"]
	var coordinator: RefCounted = wired["coordinator"]
	wired["state"].set_failure(&"commit")
	wired["checkpoint"].set_failure(&"rollback")
	var result: Dictionary = coordinator.request_schedule_done("done:run-1:day-2")
	assert_false(result.get("ok", true))
	assert_eq(result["code"], &"APPLICATION_FATAL", JSON.stringify(result))
	assert_true(gate.is_fatal_latched(), "shared gate latched exactly once")
	var failure: Dictionary = result["details"]["failure"]
	assert_eq(failure["source"], "day_resolution")
	assert_eq(failure["code"], "fatal_rollback_failed")
	assert_true(failure["details"]["context"].has("transaction_id"))
	assert_true(failure["details"]["context"].has("stage_id"))
	assert_true(failure["details"]["diagnostics"].size() > 0, "raw recovery results are projected")
	var after: Dictionary = coordinator.request_schedule_done("done:run-1:day-2-again")
	assert_eq(after["code"], &"APPLICATION_FATAL", "post-fatal commands return the retained failure")

# -------------------------------------------------------------------------------------------------
# complete_presentation_stage(): the seam dwm-p2r.14's acceptance criteria name
# -------------------------------------------------------------------------------------------------
#
# WHY THESE ARE NEW. Until now `complete_presentation_stage()` had NO caller anywhere in the repo --
# not in production, where Plan 03 still owns the Done dispatch, and not in any test. The suites
# that drive real presentations call the state port's `presentation_stage_receipt()` and then
# complete the stage through `RunLifecycle` directly, which bypasses the coordinator's ordering
# entirely. So "the coordinator checkpoints the port's completion receipt before advancing the
# stage" was true by reading and unproven by execution.


## The published receipt reaches the checkpoint, and only then does the stage advance.
func test_a_published_completion_is_checkpointed_and_then_advances_the_stage() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired_presentation(3)
	var paused: Dictionary = wired["paused"]
	assert_eq(str(paused["code"]), "await_registered_command", "the walk paused on the presentation")
	var checkpoints_before: Dictionary = wired["checkpoint"].peek_state()

	wired["hospital_port"].publish_completion(_completion_receipt())
	assert_eq(wired["coordinator"].get_last_presentation_completion()["receipt_id"],
		COMPLETION_TRANSACTION_ID, "the signal made the receipt available")
	assert_eq(wired["checkpoint"].peek_state(), checkpoints_before,
		"the SIGNAL ALONE checkpoints nothing and advances nothing")

	var completed: Dictionary = wired["coordinator"].complete_presentation_stage()
	assert_true(completed.get("ok", false), JSON.stringify(completed))
	assert_ne(wired["checkpoint"].peek_state(), checkpoints_before,
		"completing the stage checkpointed the receipt")
	assert_eq(_stage_state(wired["state"], "hospital_if_triggered"), "completed",
		"and only then did the stage advance")
	assert_eq(wired["coordinator"].get_last_presentation_completion(), {},
		"the settled completion is not left retained")


## A well-formed completion for some OTHER command is not this stage's evidence.
func test_a_completion_that_does_not_settle_the_awaiting_command_is_refused() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired_presentation(3)
	var foreign := _completion_receipt()
	foreign["receipt_id"] = "completion.some-other-presentation"
	wired["hospital_port"].publish_completion(foreign)

	var refused: Dictionary = wired["coordinator"].complete_presentation_stage()
	assert_false(refused.get("ok", true), "a foreign completion is refused")
	assert_eq(str(refused.get("code", "")), "presentation_completion_untrusted",
		"and names why rather than failing obscurely")
	assert_eq(_stage_state(wired["state"], "hospital_if_triggered"), "active",
		"the stage stays active: nothing advanced on a completion it never awaited")


## dwm-p2r.18 review, smaller item. A duplicate means the plan ALREADY completed this stage, so the
## coordinator's retained awaiting state is stale by definition. It returned early without dropping
## it, leaving the coordinator awaiting a stage that was already done: every later call returned
## duplicate again, and this path never reached `resume()`. The success path drops both.
##
## Unlike `complete_route_stage`, this transaction id is READ FROM `_awaiting` itself, so it cannot
## be an older transaction whose replay should leave a newer awaiting command alone.
func test_a_duplicate_completion_does_not_leave_the_coordinator_awaiting_a_finished_stage() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired_presentation(3)
	var command: Dictionary = (wired["paused"]["value"] as Dictionary)["command"]

	# The plan completes the stage behind the coordinator's back -- the shape a crash between the
	# durable completion and the coordinator hearing about it leaves.
	var out_of_band: Dictionary = wired["state"]._lifecycle.complete_active_stage(
		str(command["transaction_id"]),
		{"value": (_hospital_receipt()["value"] as Dictionary).duplicate(true)})
	assert_true(out_of_band.get("ok", false), JSON.stringify(out_of_band))

	wired["hospital_port"].publish_completion(_completion_receipt())
	var replay: Dictionary = wired["coordinator"].complete_presentation_stage()
	assert_true(replay.get("ok", false), "the replay is not an error: the stage really is complete")
	assert_eq(str(replay.get("code", "")), "duplicate_transaction",
		"and still reports the duplicate rather than swallowing it")

	assert_eq(wired["coordinator"].get_last_presentation_completion(), {},
		"the stale completion is dropped, exactly as on the success path")
	var again: Dictionary = wired["coordinator"].complete_presentation_stage()
	assert_false(again.get("ok", true),
		"and the coordinator is no longer awaiting a stage the plan already completed")


const COMPLETION_TRANSACTION_ID := "completion.hospital.day3"


## A coordinator paused on a Hospital PRESENTATION, with fake ports adopted as its owners and a
## fake router adopted as its dispatch surface.
##
## dwm-p2r.18: the router is not optional scaffolding here. A coordinator that can PAUSE on a
## presentation must be able to LAUNCH it, so a presentation site with no configured router fails
## closed rather than pausing on a scene nobody will ever show -- which is what
## `test_an_unconfigured_router_never_starts_a_physical_presentation` proves.
##
## `configure_router` mirrors production for every other case: `ApplicationBootstrap` configures the
## ports and the router on the same coordinator, in that order.
func _wired_presentation(day: int, configure_router: bool = true) -> Dictionary:
	var wired := _wired(day)
	var calls: Array[String] = wired["calls"]
	var hospital_port: RefCounted = load(PRESENTATION_PORT_PATH).new(calls)
	var dating_port: RefCounted = load(PRESENTATION_PORT_PATH).new(calls)
	assert_true(wired["coordinator"].configure_presentation_ports(
		hospital_port, dating_port).get("ok", false))
	var router: RefCounted = load(PRESENTATION_ROUTER_PATH).new(calls)
	if configure_router:
		assert_true(wired["coordinator"].configure_presentation_router(router).get("ok", false))
	wired["state"].set_registered_stage("hospital_if_triggered")
	wired["state"].set_registered_presentation(COMPLETION_TRANSACTION_ID)
	wired["paused"] = wired["coordinator"].request_schedule_done("done:run-1:day-%d" % day)
	wired["hospital_port"] = hospital_port
	wired["dating_port"] = dating_port
	wired["router"] = router
	return wired


# -------------------------------------------------------------------------------------------------
# the walk LAUNCHES the adapter: the last dwm-p2r.18 SCOPE bullet
# -------------------------------------------------------------------------------------------------
#
# WHY THESE ARE NEW. `SceneRouter.route_presentation()` and the presentation ports' `begin()` both
# had ZERO production callers. The producer derived an exact `P01.presentation.intent`, the walk
# paused on `await_registered_command` carrying its `route_id` and `presentation_request` -- and
# then nothing handed those to anything. No Hospital or Dating adapter was ever launched, which is
# the acceptance criterion dwm-p2r.14 could not meet and this bead exists to close.
#
# WHAT THE COORDINATOR OWES, and what it does not. It owes: start the physical presentation through
# the configured port, then show the scene through the configured router, with the route the command
# names and the CANONICAL command the port returned; refuse before starting anything physical when
# it cannot do both; and leave a failed launch resumable. It does not owe route legality, port
# readiness or scene configuration -- those are `SceneRouter`'s contract, proved against the real
# router in `tests/integration/test_schedule_presentation_bootstrap_wiring.gd`.


func test_the_presentation_router_seam_configures_once_and_rejects_replacement() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var coordinator: RefCounted = _wired(3)["coordinator"]
	var router: RefCounted = load(PRESENTATION_ROUTER_PATH).new()

	var first: Dictionary = coordinator.configure_presentation_router(router)
	assert_true(first.get("ok", false), JSON.stringify(first))
	assert_eq(first["value"], {"configured": true, "already_configured": false,
		"router_instance_id": router.get_instance_id()})
	assert_eq(first["receipt"], {})

	var replay: Dictionary = coordinator.configure_presentation_router(router)
	assert_true(replay.get("ok", false), "identical replay with the SAME object is idempotent")
	assert_true(bool(replay["value"]["already_configured"]))

	var replaced: Dictionary = coordinator.configure_presentation_router(
		load(PRESENTATION_ROUTER_PATH).new())
	assert_false(replaced.get("ok", true), "a configured coordinator never adopts a replacement")
	assert_eq(str(replaced.get("code", "")), "presentation_router_conflict")

	var incomplete: RefCounted = load(PRESENTATION_PORT_PATH).new()
	assert_false(load(COORDINATOR_PATH).new().configure_presentation_router(
		incomplete).get("ok", true), "an object without the exact router capability is refused")
	assert_false(load(COORDINATOR_PATH).new().configure_presentation_router(
		null).get("ok", true), "and so is nothing at all")


## THE WIRE. A paused presentation starts the physical owner and then shows the scene.
func test_a_paused_presentation_starts_the_physical_owner_then_routes_the_scene() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired_presentation(3)
	var paused: Dictionary = wired["paused"]
	assert_true(paused.get("ok", false), JSON.stringify(paused))
	assert_eq(str(paused["code"]), "await_registered_command", "the walk still pauses")

	var requests: Array[Dictionary] = wired["hospital_port"].get_requests()
	assert_eq(requests.size(), 1, "the configured port was asked to begin exactly once")
	if requests.size() != 1:
		return
	assert_eq(requests[0], {
		"completion_transaction_id": COMPLETION_TRANSACTION_ID, "route_id": "hospital",
	}, "and was handed the command's own presentation_request, unaltered")

	var routes: Array[Dictionary] = wired["router"].get_routes()
	assert_eq(routes.size(), 1, "the configured router was asked to route exactly once")
	if routes.size() != 1:
		return
	assert_eq(str(routes[0]["route_id"]), "hospital", "under the route the command names")
	assert_eq(routes[0]["command"], {
		"completion_transaction_id": COMPLETION_TRANSACTION_ID,
		"route_id": "hospital",
		"command_sha256": "sha256:%s" % COMPLETION_TRANSACTION_ID,
		"physical_token": "token:%s" % COMPLETION_TRANSACTION_ID,
	}, "carrying the port's CANONICAL command -- the started one, not the raw request")

	var calls: Array[String] = wired["calls"]
	assert_true(calls.has("port.begin") and calls.has("router.route_presentation"),
		"both halves of the launch really ran")
	assert_true(calls.find("port.begin") < calls.find("router.route_presentation"),
		"the physical presentation starts BEFORE the scene is shown: the scene projects the "
		+ "command_sha256 and physical_token only a started presentation carries")
	assert_eq(_stage_state(wired["state"], "hospital_if_triggered"), "active",
		"and the stage is still awaiting its completion: launching advanced nothing")


## Nothing physical may start when the scene cannot be shown.
func test_an_unconfigured_router_never_starts_a_physical_presentation() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired_presentation(3, false)
	var paused: Dictionary = wired["paused"]
	assert_false(paused.get("ok", true), "a presentation site with no router fails closed")
	assert_eq(str(paused.get("code", "")), "presentation_router_unconfigured",
		"and names the missing owner rather than silently skipping the presentation")
	assert_eq(wired["hospital_port"].get_requests(), [],
		"the port was never asked to begin: no timeline runs behind a scene that cannot open")
	assert_eq(_stage_state(wired["state"], "hospital_if_triggered"), "active",
		"the stage stays active and unreceipted, so the run resumes at this exact boundary")

	# The stages BEFORE the presentation legitimately completed and published; what must not move is
	# anything from the presentation onward. Re-resuming proves the refusal is inert rather than
	# merely first: it neither advances the stage nor publishes a second time.
	var published: int = wired["state"].get_publication_count()
	var checkpoints: Dictionary = wired["checkpoint"].peek_state()
	var again: Dictionary = wired["coordinator"].resume()
	assert_false(again.get("ok", true), "and it keeps failing closed rather than draining away")
	assert_eq(wired["state"].get_publication_count(), published, "no publication for this stage")
	assert_eq(wired["checkpoint"].peek_state(), checkpoints, "and no checkpoint for it either")


## The other half of the composition gap: a router but no ports.
##
## Stated separately from the missing-router case because the two failures are not interchangeable.
## A missing router means nobody can show the scene; a missing PORT means nobody owns the physical
## presentation, and the code has to say which, or a mis-composed graph is debugged by guesswork.
func test_a_presentation_site_with_no_configured_ports_fails_closed() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3)
	var router: RefCounted = load(PRESENTATION_ROUTER_PATH).new(wired["calls"])
	assert_true(wired["coordinator"].configure_presentation_router(router).get("ok", false))
	wired["state"].set_registered_stage("hospital_if_triggered")
	wired["state"].set_registered_presentation(COMPLETION_TRANSACTION_ID)

	var refused: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	assert_false(refused.get("ok", true), "a presentation with no port to own it fails closed")
	assert_eq(str(refused.get("code", "")), "presentation_ports_unconfigured",
		"and names the missing ports rather than the router that IS configured")
	assert_eq(router.get_routes(), [], "no scene was shown")
	assert_eq(_stage_state(wired["state"], "hospital_if_triggered"), "active",
		"the stage stays active and resumable")


## A refused route leaves the stage resumable, and the retry replays the identical command.
func test_a_refused_route_leaves_the_stage_active_and_replays_the_identical_command() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3)
	var calls: Array[String] = wired["calls"]
	var hospital_port: RefCounted = load(PRESENTATION_PORT_PATH).new(calls)
	assert_true(wired["coordinator"].configure_presentation_ports(
		hospital_port, load(PRESENTATION_PORT_PATH).new(calls)).get("ok", false))
	var router: RefCounted = load(PRESENTATION_ROUTER_PATH).new(calls)
	router.set_failure(&"presentation_scene_missing")
	assert_true(wired["coordinator"].configure_presentation_router(router).get("ok", false))
	wired["state"].set_registered_stage("hospital_if_triggered")
	wired["state"].set_registered_presentation(COMPLETION_TRANSACTION_ID)

	var refused: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	assert_false(refused.get("ok", true), "the walk reports the route it could not make")
	assert_eq(str(refused.get("code", "")), "presentation_scene_missing",
		"verbatim from the router, rather than reduced to a generic failure")
	assert_eq(_stage_state(wired["state"], "hospital_if_triggered"), "active",
		"the stage stays ACTIVE and unreceipted")
	var published: int = wired["state"].get_publication_count()

	# THE RETRY. `begin()` is idempotent per completion transaction, so resuming re-derives the same
	# command and re-offers it without restarting a presentation that may already be running.
	var retried: Dictionary = wired["coordinator"].resume()
	assert_false(retried.get("ok", true), "the router still refuses")
	var requests: Array[Dictionary] = hospital_port.get_requests()
	assert_eq(requests.size(), 2, "the retry went through the port again")
	if requests.size() != 2:
		return
	assert_eq(requests[0], requests[1], "with byte-identical request bytes")
	var routes: Array[Dictionary] = router.get_routes()
	assert_eq(routes.size(), 2, "and through the router again")
	if routes.size() != 2:
		return
	assert_eq(routes[0], routes[1], "with a byte-identical route command")
	assert_eq(wired["state"].get_publication_count(), published,
		"and the retry published nothing: a presentation that never opened settles nothing")


## A port that cannot start its presentation never reaches the router.
func test_a_port_that_cannot_start_never_reaches_the_router() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3)
	var calls: Array[String] = wired["calls"]
	var hospital_port: RefCounted = load(PRESENTATION_PORT_PATH).new(calls)
	# The exact shape Phase 2R's Dating route already has: a port with no configured physical owner.
	hospital_port.set_begin_failure(&"dating_physical_owner_unconfigured")
	assert_true(wired["coordinator"].configure_presentation_ports(
		hospital_port, load(PRESENTATION_PORT_PATH).new(calls)).get("ok", false))
	var router: RefCounted = load(PRESENTATION_ROUTER_PATH).new(calls)
	assert_true(wired["coordinator"].configure_presentation_router(router).get("ok", false))
	wired["state"].set_registered_stage("hospital_if_triggered")
	wired["state"].set_registered_presentation(COMPLETION_TRANSACTION_ID)

	var refused: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	assert_false(refused.get("ok", true), "the walk fails closed on the port's refusal")
	assert_eq(str(refused.get("code", "")), "dating_physical_owner_unconfigured",
		"verbatim from the port")
	assert_eq(router.get_routes(), [],
		"and no scene was ever shown for a presentation that never started")
	assert_eq(_stage_state(wired["state"], "hospital_if_triggered"), "active",
		"the stage stays active and resumable")


## The port-published completion receipt, in the shape `_on_presentation_completion_ready` accepts.
func _completion_receipt() -> Dictionary:
	return {
		"receipt_id": COMPLETION_TRANSACTION_ID,
		"resolution_id": "resolution-1",
		"route_id": "hospital",
		"timeline_id": "hospital.faint",
	}


func _hospital_receipt() -> Dictionary:
	return {"owner_id": "hospital_rules", "kind": "hospital_resolution",
		"value": {"required": false, "date_schedule_entry_ids": [],
			"superseded_entry_ids": [], "witness_entry_id": null,
			"presentation_completion_receipt": null}}


func _stage_state(state: RefCounted, stage_id: String) -> String:
	var plan: Variant = state._lifecycle.to_dict()["active_resolution_plan"]
	if typeof(plan) != TYPE_DICTIONARY:
		return ""
	for stage_value: Variant in ((plan as Dictionary)["stages"] as Array):
		var stage: Dictionary = stage_value
		if str(stage["stage_id"]) == stage_id:
			return str(stage["state"])
	return ""


func test_duplicate_transaction_returns_stored_receipt_without_new_checkpoint() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3)
	wired["state"].set_registered_stage("hospital_if_triggered")
	var paused: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	var command: Dictionary = paused["value"]["command"]
	wired["state"].set_registered_stage("")
	# Task 7 (dwm-p2r.14): Hospital is owned by HospitalRules and reports the FULL supersession
	# set, not a single "prevented" entry.
	# dwm-p2r.18: a Hospital stage additionally records the presentation completion it checkpointed,
	# and null is the honest value for a Hospital that presented nothing.
	var receipt := {"owner_id": "hospital_rules", "kind": "hospital_resolution",
		"value": {"required": false, "date_schedule_entry_ids": [],
			"superseded_entry_ids": [], "witness_entry_id": null,
			"presentation_completion_receipt": null}}
	assert_true(wired["coordinator"].complete_route_stage(str(command["transaction_id"]), receipt)["ok"])
	var checkpoints_after: Dictionary = wired["checkpoint"].peek_state()
	var publications_after: int = wired["state"].get_publication_count()
	var replay: Dictionary = wired["coordinator"].complete_route_stage(str(command["transaction_id"]), receipt)
	assert_true(replay.get("ok", false), "duplicate completion succeeds: " + JSON.stringify(replay))
	assert_eq(wired["checkpoint"].peek_state(), checkpoints_after, "no second checkpoint")
	assert_eq(wired["state"].get_publication_count(), publications_after, "no second publication")

func test_checkpoint_preview_matches_prepare_without_mutation() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var calls: Array[String] = []
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	checkpoint.seed_empty("run-1")
	var before: Dictionary = checkpoint.peek_state()
	var preview: Dictionary = checkpoint.preview_checkpoint_id("run-1")
	assert_true(preview["ok"])
	assert_eq(checkpoint.peek_state(), before, "preview never mutates")
	var prepared: Dictionary = checkpoint.prepare({"run_id": "run-1"}, &"day_resolution_stage",
		{"kind": &"none", "reason": &"stage"})
	assert_true(prepared["ok"])
	assert_eq(str(preview["value"]["checkpoint_id"]), str(prepared["value"]["checkpoint_id"]),
		"preview and immediate prepare agree")


# ---- Task 7 Step 7.3a: the shared day-advance identity seam (dwm-p2r.14) ----
#
# The coordinator gains ONE new dependency seam. It does NOT change the frozen three-owner
# configure(state_port, checkpoint_port, mutation_gate) signature and does not renumber a stage.
# Bootstrap alone configures it, and retains the same object for Plan 03 composition.

func test_day_advance_identity_seam_configures_once_and_rejects_replacement() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	assert_true(ResourceLoader.exists(DAY_ADVANCE_PATH, "Script"), "CausalDayAdvanceIdentityPort must exist")
	if not ResourceLoader.exists(DAY_ADVANCE_PATH, "Script"):
		return
	var wired := _wired(3, false)
	var coordinator: RefCounted = wired["coordinator"]
	var port: RefCounted = load(DAY_ADVANCE_PATH).new()

	var first: Dictionary = coordinator.configure_day_advance_identity_port(port)
	assert_true(first.get("ok", false), JSON.stringify(first))
	assert_eq(first["value"], {"configured": true, "already_configured": false})
	assert_eq(first["receipt"], {})

	# Byte-identical replay with the SAME object is idempotent.
	var replay: Dictionary = coordinator.configure_day_advance_identity_port(port)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay["value"], {"configured": true, "already_configured": true})

	# A different instance of the right type is still a REPLACEMENT and must reject.
	var replacement: Dictionary = coordinator.configure_day_advance_identity_port(
		load(DAY_ADVANCE_PATH).new())
	assert_false(replacement.get("ok", true), "a configured coordinator never adopts a replacement")
	assert_eq(replacement["code"], &"day_advance_identity_port_conflict")

func test_day_advance_identity_seam_requires_the_exact_capability() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var coordinator: RefCounted = _wired(3, false)["coordinator"]
	assert_false(coordinator.configure_day_advance_identity_port(null).get("ok", true),
		"a missing object rejects")
	# The checkpoint fake is a real Object that lacks the advance-identity capability.
	var wrong: RefCounted = load(CHECKPOINT_PATH).new([] as Array[String])
	var rejected: Dictionary = coordinator.configure_day_advance_identity_port(wrong)
	assert_false(rejected.get("ok", true), "an object without the exact capability rejects")
	assert_eq(rejected["code"], &"day_advance_identity_port_conflict")

func test_resume_fails_closed_at_increment_day_without_the_identity_port() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3, false)
	var coordinator: RefCounted = wired["coordinator"]
	var state: RefCounted = wired["state"]
	# No configure_day_advance_identity_port() call: the seam is deliberately unconfigured.
	var result: Dictionary = coordinator.request_schedule_done("done:run-1:day-3")
	assert_false(result.get("ok", true), "an unconfigured advance identity fails closed")
	assert_eq(result["code"], &"day_advance_identity_port_unconfigured")

	# EARLIER stages remain recoverable: the walk got as far as increment_day and stopped there,
	# rather than refusing to start or rolling the whole plan back.
	var cursor: Dictionary = state.inspect_next_stage()
	assert_true(cursor.get("ok", false), JSON.stringify(cursor))
	assert_true(cursor["value"]["has_stage"], "the plan is still open at the blocked stage")
	assert_eq(str(cursor["value"]["stage"]["stage_id"]), "increment_day",
		"it stops AT increment_day, with every earlier stage already completed")

func test_day7_resume_never_needs_the_identity_port() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	# Day 7 has no increment_day stage at all, so it must resolve fully without the seam.
	var wired := _wired(7)
	var result: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-7")
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["code"], &"plan_complete", "Day 7 completes without any day advance")
