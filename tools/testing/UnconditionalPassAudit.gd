class_name UnconditionalPassAudit
extends RefCounted
## Rejects test functions whose ONLY effective assertion is a constant success
## (dwm-p2r.8, Plan-05 Task 5 Step 5.3).
##
## A suite like `func test_stub(): assert_true(true, "stub")` reports green forever while proving
## nothing. This audit finds those so a gate cannot be satisfied by a stub.

## Assertions that are always true regardless of the system under test.
const CONSTANT_ASSERTIONS := [
	"assert_true(true", "assert_false(false", "assert_null(null",
	"assert_eq(true, true", "assert_eq(false, false", "assert_eq(1, 1", "assert_eq(0, 0",
]
const BARE_PASS := "pass_test("
## Any of these means the function actually exercises something.
const ASSERTION_PREFIXES := [
	"assert_", "pending(", "watch_signals(", "assert_signal", "gut.p(",
]


static func audit_source(path: String, source: String) -> Array:
	var findings: Array = []
	var current_function := ""
	var effective := 0
	var constant_only := 0
	for raw_line in source.split("\n"):
		var line := (raw_line as String).strip_edges()
		if line.begins_with("func "):
			_flush(findings, path, current_function, effective, constant_only)
			current_function = _function_name(line)
			effective = 0
			constant_only = 0
			continue
		if current_function.is_empty() or not current_function.begins_with("test_"):
			continue
		if line.begins_with("#"):
			continue
		if _is_constant_assertion(line):
			constant_only += 1
			continue
		if line.begins_with(BARE_PASS):
			constant_only += 1
			continue
		for prefix: String in ASSERTION_PREFIXES:
			if line.begins_with(prefix):
				effective += 1
				break
	_flush(findings, path, current_function, effective, constant_only)
	return findings


static func audit_directory(root: String) -> Array:
	var findings: Array = []
	var dir := DirAccess.open(root)
	if dir == null:
		return findings
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := root + "/" + name
		if dir.current_is_dir():
			if name != "." and name != "..":
				findings.append_array(audit_directory(full))
		elif name.ends_with(".gd"):
			findings.append_array(audit_source(full, FileAccess.get_file_as_string(full)))
		name = dir.get_next()
	dir.list_dir_end()
	return findings


static func _flush(findings: Array, path: String, function_name: String, effective: int, constant_only: int) -> void:
	if function_name.is_empty() or not function_name.begins_with("test_"):
		return
	# Flagged only when the function asserts SOMETHING and everything it asserts is constant.
	if effective == 0 and constant_only > 0:
		findings.append({"path": path, "function": function_name, "reason": "unconditional_pass"})


static func _is_constant_assertion(line: String) -> bool:
	for pattern: String in CONSTANT_ASSERTIONS:
		if line.begins_with(pattern):
			return true
	return false


static func _function_name(line: String) -> String:
	var without_keyword := line.substr(5).strip_edges()
	var paren := without_keyword.find("(")
	if paren < 0:
		return ""
	return without_keyword.substr(0, paren).strip_edges()
