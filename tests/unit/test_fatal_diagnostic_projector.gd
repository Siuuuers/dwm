extends "res://addons/gut/test.gd"

const PROJECTOR_PATH := "res://scripts/application/transaction/FatalDiagnosticProjector.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"

func _projector_exists() -> bool:
	return ResourceLoader.exists(PROJECTOR_PATH, "Script")

func _diagnostic(owner_id: Variant, operation: Variant, result: Dictionary) -> Dictionary:
	return {"owner_id": owner_id, "operation": operation, "result": result}

func _project(context: Dictionary, diagnostics: Array) -> Dictionary:
	return load(PROJECTOR_PATH).project_failure(
		&"day_resolution", "rollback", &"fatal_rollback_failed", context, diagnostics)

func test_fatal_diagnostic_projector_exists() -> void:
	assert_true(_projector_exists(), "FatalDiagnosticProjector must exist")

func test_projection_normalizes_and_detaches() -> void:
	assert_true(_projector_exists(), "FatalDiagnosticProjector must exist")
	if not _projector_exists():
		return
	var context := {"transaction_id": "t-1", &"stage_id": &"lock_day", "nested": {"count": 2}}
	var projected := _project(context, [])
	assert_true(projected["ok"], JSON.stringify(projected))
	var failure: Dictionary = projected["value"]["failure"]
	var keys := failure.keys()
	keys.sort()
	assert_eq(keys, ["code", "details", "phase", "source"])
	assert_eq(failure["source"], "day_resolution")
	assert_eq(failure["phase"], "rollback")
	assert_eq(failure["code"], "fatal_rollback_failed")
	assert_eq(failure["details"]["context"]["stage_id"], "lock_day", "StringName keys and values become String")
	context["nested"]["count"] = 99
	assert_eq(failure["details"]["context"]["nested"]["count"], 2, "projection is recursively detached")

func test_invalid_subtrees_replaced_with_sentinels() -> void:
	assert_true(_projector_exists(), "FatalDiagnosticProjector must exist")
	if not _projector_exists():
		return
	var object_value: Dictionary = _project({"bad": RefCounted.new()}, [])["value"]["failure"]
	assert_eq(object_value["details"]["context"]["bad"],
		{"reason": "unsupported_type", "path": "$.context.bad"})
	var nonfinite: Dictionary = _project({"bad": INF}, [])["value"]["failure"]
	assert_eq(nonfinite["details"]["context"]["bad"],
		{"reason": "nonfinite_number", "path": "$.context.bad"})
	var non_string_key: Dictionary = _project({"holder": {3: "x"}}, [])["value"]["failure"]
	assert_eq(non_string_key["details"]["context"]["holder"],
		{"reason": "non_string_key", "path": "$.context.holder"})
	var packed: Dictionary = _project({"bad": PackedByteArray([1, 2])}, [])["value"]["failure"]
	assert_eq(packed["details"]["context"]["bad"],
		{"reason": "unsupported_type", "path": "$.context.bad"})

func test_depth_budget_maps_to_unsupported_type() -> void:
	assert_true(_projector_exists(), "FatalDiagnosticProjector must exist")
	if not _projector_exists():
		return
	var deep: Dictionary = {"leaf": true}
	for _index: int in range(100):
		deep = {"next": deep}
	var failure: Dictionary = _project({"deep": deep}, [])["value"]["failure"]
	var found_sentinel := JSON.stringify(failure["details"]["context"]).contains("unsupported_type")
	assert_true(found_sentinel, "budget exhaustion becomes the unsupported_type sentinel")

func test_diagnostics_projection_and_malformed_replacement() -> void:
	assert_true(_projector_exists(), "FatalDiagnosticProjector must exist")
	if not _projector_exists():
		return
	var success := _diagnostic(&"state_port", "rollback", {"ok": true, "code": &"ok", "value": {"secret": 1}})
	var failed := _diagnostic("checkpoint_port", &"rollback",
		{"ok": false, "code": "rollback_failed", "message": &"io error", "details": {"path": "slot-1"}})
	var malformed := {"owner_id": "x"}
	var failure: Dictionary = _project({}, [success, failed, malformed])["value"]["failure"]
	var diagnostics: Array = failure["details"]["diagnostics"]
	assert_eq(diagnostics.size(), 3, "order and count preserved")
	assert_eq(diagnostics[0]["owner_id"], "state_port")
	assert_eq(diagnostics[0]["ok"], true)
	assert_eq(diagnostics[0]["message"], "", "success projects an empty message")
	assert_eq(diagnostics[0]["details"], {}, "success never copies value/receipt")
	assert_false(diagnostics[0].has("value"))
	assert_eq(diagnostics[1]["ok"], false)
	assert_eq(diagnostics[1]["message"], "io error")
	assert_eq(diagnostics[1]["details"], {"path": "slot-1"})
	assert_eq(diagnostics[2]["code"], "invalid_fatal_diagnostic")
	assert_eq(diagnostics[2]["owner_id"], "fatal_diagnostic_projector")
	assert_eq(diagnostics[2]["details"]["reason"], "malformed_diagnostic")
	assert_eq(diagnostics[2]["details"]["path"], "$.diagnostics[2]")

func test_validate_failure_and_invariant_fallback() -> void:
	assert_true(_projector_exists(), "FatalDiagnosticProjector must exist")
	if not _projector_exists():
		return
	var projector: Script = load(PROJECTOR_PATH)
	var failure: Dictionary = _project({"id": "t"}, [])["value"]["failure"]
	assert_true(projector.validate_failure(failure)["ok"], "projected failures validate")
	assert_false(projector.validate_failure({"source": "x"}).get("ok", true), "wrong keys reject")
	var fallback: Dictionary = projector.get_invariant_fallback()
	assert_eq(fallback, {
		"source": "fatal_diagnostic_projector",
		"phase": "project_failure",
		"code": "FATAL_PROJECTOR_INVARIANT",
		"details": {"reason": "invalid_projector_output", "path": "$"},
	})
	fallback["code"] = "mutated"
	assert_eq(projector.get_invariant_fallback()["code"], "FATAL_PROJECTOR_INVARIANT",
		"fallback returns a fresh copy")
	assert_true(projector.validate_failure(projector.get_invariant_fallback())["ok"])

func test_real_gate_accepts_every_projected_failure() -> void:
	assert_true(_projector_exists(), "FatalDiagnosticProjector must exist")
	if not _projector_exists():
		return
	assert_true(ResourceLoader.exists(GATE_PATH, "Script"), "ApplicationMutationGate must exist")
	if not ResourceLoader.exists(GATE_PATH, "Script"):
		return
	var projector: Script = load(PROJECTOR_PATH)
	var candidates: Array[Dictionary] = [
		_project({"bad": RefCounted.new()}, [])["value"]["failure"],
		_project({}, [{"owner_id": "x"}])["value"]["failure"],
		projector.get_invariant_fallback(),
	]
	for candidate: Dictionary in candidates:
		var gate: RefCounted = load(GATE_PATH).new()
		var latched: Dictionary = gate.latch_fatal(candidate)
		assert_true(latched.get("ok", false), "gate must accept: " + JSON.stringify(latched))

func test_single_projector_class() -> void:
	assert_true(_projector_exists(), "FatalDiagnosticProjector must exist")
	if not _projector_exists():
		return
	var matches := 0
	for root: String in ["res://scripts", "res://autoload", "res://scenes"]:
		matches += _count_class_declarations(root, "class_name FatalDiagnosticProjector")
	assert_eq(matches, 1, "exactly one FatalDiagnosticProjector class")

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
