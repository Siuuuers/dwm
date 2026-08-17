extends "res://addons/gut/test.gd"

const COORDINATOR := preload("res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd")
const FAKE_STATE := preload("res://tests/support/FakeMinesweeperStatePort.gd")
const FAKE_SAVE := preload("res://tests/support/FakeMinesweeperSavePort.gd")
const FAKE_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")
const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")

const ROUND_ID := "run-1:day-1:round-1"


## Returns recovery failures whose details carry deliberately NON-PRIMITIVE payloads. Subclassed
## here rather than widened on the frozen fake, so the shared double keeps its exact surface.
class HostileRecoveryStatePort:
	extends "res://tests/support/FakeMinesweeperStatePort.gd"
	var hostile_rollback := false

	static func hostile_payload() -> Dictionary:
		# In turn: a normalized-key collision, a non-finite float, an Object, a Resource, a
		# Callable, packed bytes, and another packed array.
		return {
			"a.b": 1, "a": {"b": 2},
			"nan": NAN,
			"object": RefCounted.new(),
			"resource": Resource.new(),
			"callable": Callable(),
			"bytes": PackedByteArray([1, 2, 3]),
			"floats": PackedFloat32Array([1.5, 2.5]),
		}

	func rollback(backup: Dictionary) -> Dictionary:
		if hostile_rollback:
			_calls.rollback += 1
			return {"ok": false, "code": &"rollback_failed", "message": "hostile",
				"details": hostile_payload()}
		return super.rollback(backup)


func _make_coordinator(gate: RefCounted = null) -> Dictionary:
	var state := FAKE_STATE.new(gate)
	var save := FAKE_SAVE.new()
	var coord := COORDINATOR.new()
	var cfg := coord.configure(save, state)
	return {"coord": coord, "state": state, "save": save}


func test_configure_ok_and_begin_requires_config() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.configure(made.save, made.state).ok)
	# A fresh coordinator cannot begin before configure.
	var fresh := COORDINATOR.new()
	var r: Dictionary = fresh.begin_round({"context": &"app", "difficulty": &"beginner"})
	assert_false(r.ok)
	assert_eq(r.code, &"NOT_CONFIGURED")


func test_begin_round_sets_active_and_counts() -> void:
	var made := _make_coordinator()
	var r: Dictionary = made.coord.begin_round({"context": &"app", "difficulty": &"beginner"})
	assert_true(r.ok)
	assert_eq(r.value.round_id, "run-1:day-1:round-1")
	assert_eq(made.coord.get_active_round().value.round_id, "run-1:day-1:round-1")
	var sc: Dictionary = made.state.get_call_counts()
	var wc: Dictionary = made.save.get_call_counts()
	assert_eq(sc.capture, 1)
	assert_eq(sc.prepare_begin, 1)
	assert_eq(wc.preview_checkpoint_id, 1)
	assert_eq(wc.prepare_checkpoint, 1)
	assert_eq(wc.commit_checkpoint, 1)
	assert_eq(wc.acquire_board_lock, 1)
	assert_eq(sc.commit, 1)
	assert_eq(sc.publish, 1)
	# Lock is held while a round is active.
	assert_true(made.save.owns_board_lock())


func test_begin_when_active_is_rejected() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).ok)
	var r: Dictionary = made.coord.begin_round({"context": &"app", "difficulty": &"beginner"})
	assert_false(r.ok)
	assert_eq(r.code, &"ROUND_ALREADY_ACTIVE")


func test_complete_round_full_flow_releases_lock() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).ok)
	var r: Dictionary = made.coord.complete_round("run-1:day-1:round-1", {"outcome": &"cleared"}, "tx-1")
	assert_true(r.ok)
	assert_eq(r.value.checkpoint_id, "run-1:1")
	var sc: Dictionary = made.state.get_call_counts()
	var wc: Dictionary = made.save.get_call_counts()
	assert_eq(sc.prepare_complete, 1)
	assert_eq(sc.finalize_complete, 1)
	assert_eq(sc.commit, 2)
	# Cumulative across the run: begin_round prepares/commits the pre-board checkpoint and
	# complete_round prepares/commits the post-result checkpoint.
	assert_eq(wc.prepare_checkpoint, 2)
	assert_eq(wc.commit_checkpoint, 2)
	assert_eq(wc.release_board_lock, 1)
	assert_false(made.save.owns_board_lock())
	assert_true(made.coord.get_active_round().get("ok", false) == false or made.coord.get_active_round().get("code", &"") == &"no_active_round")


func test_complete_duplicate_returns_stored_receipt_with_zero_calls() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).ok)
	assert_true(made.coord.complete_round("run-1:day-1:round-1", {"outcome": &"cleared"}, "tx-1").ok)
	made.state.reset_call_counts()
	made.save.reset_call_counts()
	var again: Dictionary = made.coord.complete_round("run-1:day-1:round-1", {"outcome": &"cleared"}, "tx-1")
	assert_true(again.ok)
	assert_eq(again.value.checkpoint_id, "run-1:1")
	var sc: Dictionary = made.state.get_call_counts()
	var wc: Dictionary = made.save.get_call_counts()
	# guard_external is the mandated first operation of every public call, ahead of the
	# completed-transaction lookup, so a replay still guards exactly once and nothing else runs.
	for key in sc.keys():
		var expected_state_calls: int = 1 if str(key) == "guard_external" else 0
		assert_eq(sc[key], expected_state_calls, "state.%s on duplicate" % key)
	for key in wc.keys():
		assert_eq(wc[key], 0, "save.%s should be 0 on duplicate" % key)


func test_complete_wrong_round_id_is_rejected() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).ok)
	var r: Dictionary = made.coord.complete_round("wrong-round", {"outcome": &"cleared"}, "tx-2")
	assert_false(r.ok)
	assert_eq(r.code, &"ROUND_ID_MISMATCH")


func test_complete_invalid_result_is_rejected() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).ok)
	var r: Dictionary = made.coord.complete_round("run-1:day-1:round-1", {"outcome": &"win"}, "tx-3")
	assert_false(r.ok)
	assert_eq(r.code, &"INVALID_RESULT")


func test_abort_round_releases_lock() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).ok)
	var r: Dictionary = made.coord.abort_round("run-1:day-1:round-1", &"user_abort", "tx-a")
	assert_true(r.ok)
	assert_false(made.save.owns_board_lock())
	assert_true(made.coord.get_active_round().get("code", &"") == &"no_active_round")


# ---- Step 2.5: recovery, retry, and conflict boundaries ----

func _hostile_round(gate: RefCounted) -> Dictionary:
	var state := HostileRecoveryStatePort.new(gate)
	var save := FAKE_SAVE.new()
	var coord := COORDINATOR.new()
	assert_true(coord.configure(save, state).get("ok", false))
	return {"coord": coord, "state": state, "save": save}


## Successful recovery after a pre-emission publication failure: nothing was emitted, the
## pre-active state is restored, the lock is released, and the durable pre-board record stands.
func test_round_start_publication_failure_recovers_without_latching() -> void:
	var made := _make_coordinator()
	made.state.set_failure(&"publish", 1)
	var begun: Dictionary = made.coord.begin_round({"context": &"app", "difficulty": &"beginner"})
	assert_false(begun.get("ok", false))
	assert_eq(begun.code, &"ROUND_START_PUBLICATION_FAILED")
	var sc: Dictionary = made.state.get_call_counts()
	var wc: Dictionary = made.save.get_call_counts()
	assert_eq(sc.publish, 1, "publication was attempted exactly once and emitted nothing")
	assert_eq(sc.rollback, 1, "the committed active candidate rolled back first")
	assert_eq(wc.release_board_lock, 1, "the lock released second")
	assert_false(made.save.owns_board_lock())
	assert_eq(wc.commit_checkpoint, 1, "the durable pre-board checkpoint remains committed")
	assert_eq(made.coord.get_active_round().get("code"), &"no_active_round")
	assert_false(made.state.is_fatal_latched(), "a successful recovery latches nothing")


## Round-start publication fails BEFORE emission, and its recovery then fails too -- separately
## for each owner and for both together. Every case must attempt both actions in order, project
## hostile diagnostics into primitives, validate, latch exactly once, and return only the gate's
## retained APPLICATION_FATAL while keeping the lock.
func test_minesweeper_recovery_nonprimitive_failure_projects_then_returns_retained_application_fatal() -> void:
	for scenario: String in ["rollback_only", "release_only", "both"]:
		var gate: RefCounted = FAKE_GATE.new()
		var made := _hostile_round(gate)
		made.state.set_failure(&"publish", 1)
		if scenario != "release_only":
			made.state.hostile_rollback = true
		if scenario != "rollback_only":
			made.save.set_failure(&"release_board_lock", 1)

		var result: Dictionary = made.coord.begin_round({"context": &"app", "difficulty": &"beginner"})

		assert_false(result.get("ok", false), scenario)
		assert_eq(result.get("code"), &"APPLICATION_FATAL", scenario)
		assert_ne(result.get("code"), &"ROUND_START_PUBLICATION_FAILED",
			"%s: the irreversible fence outranks the ordinary code" % scenario)
		var failure: Dictionary = result["details"]["failure"]
		assert_false(failure.is_empty(), "%s: fatal details are never empty" % scenario)
		assert_true(PROJECTOR.validate_failure(failure).get("ok", false),
			"%s: the full failure validated before latching" % scenario)
		assert_eq(str(failure["source"]), "minesweeper", scenario)
		assert_eq(str(failure["code"]), "ROLLBACK_FAILED",
			"%s: ROLLBACK_FAILED survives only as inner identity" % scenario)

		# BOTH recovery attempts ran, in the frozen order, even after the first failed.
		var diagnostics: Array = failure["details"]["diagnostics"]
		assert_eq(diagnostics.size(), 2, "%s: both attempts recorded" % scenario)
		assert_true(JSON.stringify(diagnostics[0]).contains("rollback"), scenario)
		assert_true(JSON.stringify(diagnostics[1]).contains("release_board_lock"), scenario)

		if scenario != "release_only":
			# Hostile values became sentinels, and no rejected bytes survived.
			var text := JSON.stringify(failure)
			assert_true(text.contains("unsupported_type"), "%s: hostile values projected" % scenario)
			assert_true(text.contains("\"path\""), "%s: every sentinel records its path" % scenario)

		# Exactly one latch, no acquire owner, lock retained, and no second publication.
		assert_true(made.state.is_fatal_latched(), scenario)
		assert_null(gate.get_active_owner(), "%s: a fatal latch never acquires an owner" % scenario)
		var latches := 0
		for entry: Dictionary in gate.get_call_log():
			if entry["method"] == &"latch_fatal":
				latches += 1
		assert_eq(latches, 1, "%s: exactly one latch" % scenario)
		assert_eq(int(made.state.get_call_counts()["publish"]), 1,
			"%s: publication is never retried automatically" % scenario)

		# An identical repeat is idempotent, and a different valid latch never displaces the first.
		assert_true(gate.latch_fatal(failure)["value"]["already_latched"], scenario)
		assert_eq(gate.latch_fatal({"source": "other", "phase": "other", "code": "OTHER", "details": {}})
			.get("code"), &"APPLICATION_FATAL_CONFLICT", scenario)
		assert_eq(gate.guard_external(&"probe")["details"]["failure"], failure,
			"%s: the first failure and its exact details remain authoritative" % scenario)


func test_recovery_failure_latches_once_and_returns_only_the_retained_application_fatal() -> void:
	var gate: RefCounted = FAKE_GATE.new()
	var made := _hostile_round(gate)
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).get("ok", false))
	# The completion's state commit fails, and BOTH required rollbacks then fail too.
	made.state.set_failure(&"commit", 1)
	made.state.hostile_rollback = true
	made.save.set_failure(&"rollback", 1)
	var result: Dictionary = made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-fatal")

	# Only the gate's retained APPLICATION_FATAL is returned -- never outer ROLLBACK_FAILED,
	# never a latch ok/conflict envelope, never empty details.
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"APPLICATION_FATAL")
	assert_ne(result.get("code"), &"ROLLBACK_FAILED", "ROLLBACK_FAILED is inner identity only")
	assert_true(result.has("details"))
	var failure: Dictionary = result["details"]["failure"]
	assert_false(failure.is_empty(), "the retained fatal details are never empty")

	# The projection survived every hostile value: primitives only, with sentinel reason/path.
	assert_eq(str(failure["source"]), "minesweeper")
	assert_eq(str(failure["code"]), "ROLLBACK_FAILED", "inner retained code identity")
	var text := JSON.stringify(failure)
	assert_true(text.contains("unsupported_type"), "hostile values became sentinels")
	assert_true(text.contains("\"path\""), "every sentinel records its path")
	assert_true(PROJECTOR.validate_failure(failure).get("ok", false),
		"the full failure was validated before latching")
	# The context carries only stable identifiers.
	var context: Dictionary = failure["details"]["context"]
	assert_eq(str(context.get("round_id", "")), ROUND_ID)
	assert_eq(str(context.get("transaction_id", "")), "tx-fatal")

	# Latched exactly once, with no acquire owner, and every later guard repeats it unchanged.
	assert_true(gate.is_fatal_latched())
	assert_null(gate.get_active_owner(), "a fatal latch never acquires an owner")
	var latch_calls := 0
	for entry: Dictionary in gate.get_call_log():
		if entry["method"] == &"latch_fatal":
			latch_calls += 1
	assert_eq(latch_calls, 1, "exactly one latch")
	var later: Dictionary = gate.guard_external(&"any_later_operation")
	assert_eq(later.get("code"), &"APPLICATION_FATAL")
	assert_eq(later["details"]["failure"], failure, "the first failure stays authoritative")


func test_a_latched_fatal_blocks_every_later_operation_at_the_first_guard() -> void:
	var gate: RefCounted = FAKE_GATE.new()
	var made := _hostile_round(gate)
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).get("ok", false))
	made.state.set_failure(&"commit", 1)
	made.state.hostile_rollback = true
	made.save.set_failure(&"rollback", 1)
	assert_eq(made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-a").get("code"),
		&"APPLICATION_FATAL")
	var authoritative: Dictionary = gate.guard_external(&"probe")["details"]["failure"]

	# A different valid latch never displaces the first retained failure.
	var intruder: Dictionary = gate.latch_fatal(
		{"source": "other", "phase": "other", "code": "OTHER", "details": {}})
	assert_false(intruder.get("ok", false))
	assert_eq(intruder.get("code"), &"APPLICATION_FATAL_CONFLICT")
	assert_eq(gate.guard_external(&"probe")["details"]["failure"], authoritative)

	# Every later public call stops at its first-operation guard with zero further port work.
	made.state.reset_call_counts()
	made.save.reset_call_counts()
	for result: Dictionary in [
		made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}),
		made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-b"),
		made.coord.abort_round(ROUND_ID, &"teardown", "tx-c"),
	]:
		assert_eq(result.get("code"), &"APPLICATION_FATAL")
		assert_eq(result["details"]["failure"], authoritative)
	var sc: Dictionary = made.state.get_call_counts()
	for key: Variant in sc.keys():
		var expected: int = 3 if str(key) == "guard_external" else 0
		assert_eq(int(sc[key]), expected, "state.%s after the fence" % key)
	for key: Variant in made.save.get_call_counts().keys():
		assert_eq(int(made.save.get_call_counts()[key]), 0, "save.%s after the fence" % key)


func test_committed_unpublished_retry_resumes_only_its_recorded_phase() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).get("ok", false))
	made.state.reset_call_counts()
	made.save.reset_call_counts()
	made.state.set_failure(&"publish", 1)
	var unpublished: Dictionary = made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-1")
	assert_false(unpublished.get("ok", false))
	assert_eq(unpublished.code, &"COMPLETION_COMMITTED_UNPUBLISHED")
	var sc: Dictionary = made.state.get_call_counts()
	var wc: Dictionary = made.save.get_call_counts()
	assert_eq(sc.prepare_complete, 1)
	assert_eq(sc.finalize_complete, 1)
	assert_eq(wc.preview_checkpoint_id, 1)
	assert_eq(wc.prepare_checkpoint, 1)
	assert_eq(wc.commit_checkpoint, 1)
	assert_eq(sc.commit, 1)
	assert_eq(wc.release_board_lock, 0, "the lock is still held after a publication failure")

	# The exact retry increments ONLY publish, then release_board_lock.
	made.state.reset_call_counts()
	made.save.reset_call_counts()
	var retried: Dictionary = made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-1")
	assert_true(retried.get("ok", false), str(retried))
	var sc2: Dictionary = made.state.get_call_counts()
	var wc2: Dictionary = made.save.get_call_counts()
	assert_eq(sc2.publish, 1)
	assert_eq(wc2.release_board_lock, 1)
	for key: String in ["prepare_complete", "finalize_complete", "capture", "commit"]:
		assert_eq(int(sc2[key]), 0, "retry re-ran state.%s" % key)
	for key: String in ["preview_checkpoint_id", "prepare_checkpoint", "commit_checkpoint", "capture"]:
		assert_eq(int(wc2[key]), 0, "retry re-ran save.%s" % key)


func test_lock_release_pending_retry_never_republishes() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).get("ok", false))
	made.save.set_failure(&"release_board_lock", 1)
	made.state.reset_call_counts()
	made.save.reset_call_counts()
	var pending: Dictionary = made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-2")
	assert_false(pending.get("ok", false))
	assert_eq(pending.code, &"LOCK_RELEASE_PENDING")
	assert_eq(int(made.state.get_call_counts()["publish"]), 1)

	made.state.reset_call_counts()
	made.save.reset_call_counts()
	var retried: Dictionary = made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-2")
	assert_true(retried.get("ok", false), str(retried))
	assert_eq(int(made.state.get_call_counts()["publish"]), 0, "it never republishes")
	assert_eq(int(made.save.get_call_counts()["release_board_lock"]), 1,
		"the retry calls only release_board_lock")


func test_conflicting_retries_mutate_nothing_in_either_pending_phase() -> void:
	for failing_method: StringName in [&"publish", &"release_board_lock"]:
		var made := _make_coordinator()
		assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).get("ok", false))
		if failing_method == &"publish":
			made.state.set_failure(&"publish", 1)
		else:
			made.save.set_failure(&"release_board_lock", 1)
		var first: Dictionary = made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-p")
		assert_false(first.get("ok", false), String(failing_method))
		var pending_before: Dictionary = (made.coord.get("_pending") as Dictionary).duplicate(true)

		for conflict: Array in [
			[ROUND_ID, {"outcome": &"perfect"}, "tx-p"],
			["run-1:day-1:round-9", {"outcome": &"cleared"}, "tx-p"],
			[ROUND_ID, {"outcome": &"cleared"}, "tx-other"],
		]:
			made.state.reset_call_counts()
			made.save.reset_call_counts()
			var result: Dictionary = made.coord.complete_round(conflict[0], conflict[1], conflict[2])
			assert_false(result.get("ok", false), str(conflict))
			assert_eq(result.get("code"), &"TRANSACTION_ID_CONFLICT", str(conflict))
			var sc: Dictionary = made.state.get_call_counts()
			for key: Variant in sc.keys():
				var expected: int = 1 if str(key) == "guard_external" else 0
				assert_eq(int(sc[key]), expected, "state.%s during conflict" % key)
			for key: Variant in made.save.get_call_counts().keys():
				assert_eq(int(made.save.get_call_counts()[key]), 0, "save.%s during conflict" % key)
			assert_eq(made.coord.get("_pending"), pending_before, "pending bytes are unchanged")


func test_exact_duplicate_after_release_returns_the_stored_receipt_then_conflicts_on_variation() -> void:
	var made := _make_coordinator()
	assert_true(made.coord.begin_round({"context": &"app", "difficulty": &"beginner"}).get("ok", false))
	var completed: Dictionary = made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-d")
	assert_true(completed.get("ok", false))
	assert_eq(made.coord.get_active_round().get("code"), &"no_active_round",
		"no active round remains, yet the duplicate is still reachable")

	made.state.reset_call_counts()
	made.save.reset_call_counts()
	var duplicate: Dictionary = made.coord.complete_round(ROUND_ID, {"outcome": &"cleared"}, "tx-d")
	assert_true(duplicate.get("ok", false))
	assert_eq(duplicate["value"], completed["value"], "the detached stored receipt is returned")
	for key: Variant in made.save.get_call_counts().keys():
		assert_eq(int(made.save.get_call_counts()[key]), 0, "save.%s on duplicate" % key)

	# Varying outcome or round under the stored transaction conflicts instead.
	for conflict: Array in [
		[ROUND_ID, {"outcome": &"perfect"}],
		["run-1:day-1:round-9", {"outcome": &"cleared"}],
	]:
		var result: Dictionary = made.coord.complete_round(conflict[0], conflict[1], "tx-d")
		assert_false(result.get("ok", false), str(conflict))
		assert_eq(result.get("code"), &"TRANSACTION_ID_CONFLICT", str(conflict))


func test_guard_first_op_when_fatal_latched() -> void:
	var gate := FAKE_GATE.new()
	# The gate's FatalFailure contract requires a String code; a StringName is rejected.
	assert_true(gate.latch_fatal({"source": "test", "phase": "test", "code": "TEST_FATAL", "details": {}}).ok)
	var made := _make_coordinator(gate)
	var r: Dictionary = made.coord.begin_round({"context": &"app", "difficulty": &"beginner"})
	assert_false(r.ok)
	assert_eq(r.code, &"APPLICATION_FATAL")
	assert_true(r.details.has("failure"))
