extends "res://addons/gut/test.gd"

const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"

const REQUIRED_METHODS := [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]

var _signals: Array[Dictionary] = []

func _gate_exists() -> bool:
	return ResourceLoader.exists(GATE_PATH, "Script")

func _fresh_gate() -> RefCounted:
	var gate: RefCounted = load(GATE_PATH).new()
	_signals = []
	gate.capability_changed.connect(func(capability: Dictionary) -> void: _signals.append(capability))
	return gate

func _valid_failure() -> Dictionary:
	return {
		"source": "day_resolution",
		"phase": "commit",
		"code": "fatal_rollback_failed",
		"details": {"transaction_id": "resolution-1:lock_day", "stage_id": "lock_day"},
	}

func test_application_mutation_gate_exists_with_contract() -> void:
	assert_true(_gate_exists(), "ApplicationMutationGate must exist")
	if not _gate_exists():
		return
	var gate := _fresh_gate()
	for method: String in REQUIRED_METHODS:
		assert_true(gate.has_method(method), "missing method: " + method)
	assert_false(gate.has_method("unlatch"), "no unlatch API may exist")
	assert_false(gate.has_method("reset"), "no reset API may exist")
	assert_true(gate.has_signal("capability_changed"))

func test_acquire_release_guard_owner_rules() -> void:
	assert_true(_gate_exists(), "ApplicationMutationGate must exist")
	if not _gate_exists():
		return
	var gate := _fresh_gate()
	assert_true(gate.guard_external(&"probe")["ok"], "guard succeeds while no owner is active")
	assert_false(gate.acquire(&"minesweeper").get("ok", true), "only restore/new_run/causal_transaction may acquire")
	var acquired: Dictionary = gate.acquire(&"restore")
	assert_true(acquired["ok"], JSON.stringify(acquired))
	var token := str(acquired["value"]["token"])
	assert_true(gate.is_active())
	assert_eq(gate.get_active_owner(), &"restore")
	assert_true(gate.is_internal_owner_active(&"restore"))
	assert_false(gate.acquire(&"restore").get("ok", true), "nested acquisition rejects")
	assert_false(gate.acquire(&"new_run").get("ok", true), "competing acquisition rejects")
	var guarded: Dictionary = gate.guard_external(&"probe")
	assert_false(guarded.get("ok", true))
	assert_eq(guarded["code"], &"TRANSACTION_ACTIVE")
	assert_false(gate.release(&"restore", "wrong-token").get("ok", true), "release requires the exact token")
	assert_false(gate.release(&"new_run", token).get("ok", true), "release requires the exact owner")
	assert_true(gate.release(&"restore", token)["ok"])
	assert_false(gate.is_active())
	assert_eq(gate.get_active_owner(), &"")

func test_causal_transaction_is_a_valid_owner() -> void:
	assert_true(_gate_exists(), "ApplicationMutationGate must exist")
	if not _gate_exists():
		return
	var gate := _fresh_gate()
	var acquired: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(acquired["ok"], JSON.stringify(acquired))
	assert_eq(gate.get_active_owner(), &"causal_transaction")
	assert_true(gate.is_internal_owner_active(&"causal_transaction"))
	assert_false(gate.acquire(&"restore").get("ok", true), "causal_transaction excludes restore")
	var token := str(acquired["value"]["token"])
	assert_true(gate.release(&"causal_transaction", token)["ok"])

func test_latch_fatal_input_validation_changes_nothing() -> void:
	assert_true(_gate_exists(), "ApplicationMutationGate must exist")
	if not _gate_exists():
		return
	var gate := _fresh_gate()
	var missing_key := _valid_failure()
	missing_key.erase("phase")
	assert_eq(gate.latch_fatal(missing_key)["code"], &"INVALID_FATAL_FAILURE")
	var extra_key := _valid_failure()
	extra_key["extra"] = 1
	assert_eq(gate.latch_fatal(extra_key)["code"], &"INVALID_FATAL_FAILURE")
	var empty_source := _valid_failure()
	empty_source["source"] = ""
	assert_eq(gate.latch_fatal(empty_source)["code"], &"INVALID_FATAL_FAILURE")
	var object_detail := _valid_failure()
	object_detail["details"] = {"bad": RefCounted.new()}
	assert_eq(gate.latch_fatal(object_detail)["code"], &"INVALID_FATAL_FAILURE")
	var nonfinite := _valid_failure()
	nonfinite["details"] = {"bad": INF}
	assert_eq(gate.latch_fatal(nonfinite)["code"], &"INVALID_FATAL_FAILURE")
	var non_string_key := _valid_failure()
	non_string_key["details"] = {3: "x"}
	assert_eq(gate.latch_fatal(non_string_key)["code"], &"INVALID_FATAL_FAILURE")
	assert_false(gate.is_fatal_latched(), "invalid input never latches")
	assert_eq(_signals.size(), 0, "invalid input emits nothing")
	assert_true(gate.guard_external(&"probe")["ok"], "gate remains open")

func test_first_latch_repeat_and_conflict() -> void:
	assert_true(_gate_exists(), "ApplicationMutationGate must exist")
	if not _gate_exists():
		return
	var gate := _fresh_gate()
	var failure := _valid_failure()
	var first: Dictionary = gate.latch_fatal(failure)
	assert_true(first["ok"], JSON.stringify(first))
	assert_eq(first["value"], {"fatal_latched": true, "already_latched": false})
	assert_eq(first["receipt"]["failure"]["source"], "day_resolution")
	assert_true(gate.is_fatal_latched())
	assert_eq(_signals.size(), 1, "exactly one capability signal")
	assert_eq(_signals[0]["enabled"], false)
	assert_eq(_signals[0]["code"], &"APPLICATION_FATAL")
	assert_eq(_signals[0]["fatal_latched"], true)
	failure["details"]["transaction_id"] = "mutated-after-latch"
	var repeat: Dictionary = gate.latch_fatal(_valid_failure())
	assert_true(repeat["ok"], "byte-identical repeat is idempotent")
	assert_eq(repeat["value"], {"fatal_latched": true, "already_latched": true})
	assert_eq(_signals.size(), 1, "repeat emits nothing")
	assert_eq(repeat["receipt"]["failure"]["details"]["transaction_id"], "resolution-1:lock_day",
		"caller mutation after latch never reaches the retained failure")
	var different := _valid_failure()
	different["code"] = "different_code"
	var conflict: Dictionary = gate.latch_fatal(different)
	assert_false(conflict.get("ok", true))
	assert_eq(conflict["code"], &"APPLICATION_FATAL_CONFLICT")
	assert_eq(conflict["details"]["latched_failure"]["code"], "fatal_rollback_failed")
	assert_eq(conflict["details"]["requested_failure"]["code"], "different_code")
	assert_eq(_signals.size(), 1, "conflict emits nothing")

func test_post_latch_fences_all_operations() -> void:
	assert_true(_gate_exists(), "ApplicationMutationGate must exist")
	if not _gate_exists():
		return
	var gate := _fresh_gate()
	var acquired: Dictionary = gate.acquire(&"new_run")
	var token := str(acquired["value"]["token"])
	assert_true(gate.latch_fatal(_valid_failure())["ok"], "latch while owner active")
	assert_true(gate.is_active(), "latching does not change the current owner")
	assert_eq(gate.get_active_owner(), &"new_run")
	assert_false(gate.is_internal_owner_active(&"new_run"),
		"post-latch internal-owner checks report false")
	for result: Dictionary in [
		gate.guard_external(&"probe"),
		gate.acquire(&"restore"),
		gate.release(&"new_run", token),
	]:
		assert_false(result.get("ok", true))
		assert_eq(result["code"], &"APPLICATION_FATAL")
		assert_eq(result["details"]["failure"]["code"], "fatal_rollback_failed")

func test_single_production_gate_class() -> void:
	assert_true(_gate_exists(), "ApplicationMutationGate must exist")
	if not _gate_exists():
		return
	var matches := 0
	for root: String in ["res://scripts", "res://autoload", "res://scenes"]:
		matches += _count_class_declarations(root, "class_name ApplicationMutationGate")
	assert_eq(matches, 1, "exactly one production ApplicationMutationGate class")

func _count_class_declarations(root: String, needle: String) -> int:
	var count := 0
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		var directory := DirAccess.open(current)
		if directory == null:
			continue
		directory.list_dir_begin()
		var name := directory.get_next()
		while not name.is_empty():
			var child := current.path_join(name)
			if directory.current_is_dir():
				if not name.begins_with("."):
					pending.append(child)
			elif name.get_extension() == "gd":
				if FileAccess.get_file_as_string(child).contains(needle):
					count += 1
			name = directory.get_next()
		directory.list_dir_end()
	return count


func test_release_event_observes_unlocked_state_and_does_not_reuse_fatal_signal() -> void:
	var gate := _fresh_gate()
	var observed: Array = []
	gate.transaction_released.connect(func() -> void:
		observed.append({"active": gate.is_active(), "owner": gate.get_active_owner(),
			"can_resume": gate.guard_external(&"hospital_resume").get("ok", false)}))
	var acquired: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(acquired.get("ok", false))
	assert_false(gate.release(&"causal_transaction", "wrong").get("ok", false))
	assert_eq(observed.size(), 0, "a failed release cannot wake another transaction")
	assert_true(gate.release(&"causal_transaction", str(acquired.value.token)).get("ok", false))
	assert_eq(observed, [{"active": false, "owner": &"", "can_resume": true}])
	assert_eq(_signals.size(), 0, "capability_changed retains its fatal-only contract")
