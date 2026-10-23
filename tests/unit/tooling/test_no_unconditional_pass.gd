extends "res://addons/gut/test.gd"
# No test may pass unconditionally (dwm-p2r.8, Plan-05 Task 5 Step 5.3). A suite whose only
# effective assertion is assert_true(true) or pass_test() proves nothing while reporting green.

const AUDIT_PATH := "res://tools/testing/UnconditionalPassAudit.gd"

var _audit: GDScript


func before_all() -> void:
	if ResourceLoader.exists(AUDIT_PATH, "Script"):
		_audit = load(AUDIT_PATH)


func test_audit_tool_exists() -> void:
	assert_true(ResourceLoader.exists(AUDIT_PATH, "Script"), "missing UnconditionalPassAudit.gd")


func test_audit_flags_a_constant_true_assertion() -> void:
	if _audit == null:
		return
	var source := "func test_stub() -> void:\n\tassert_true(true, \"stub\")\n"
	var findings: Array = _audit.call(&"audit_source", "res://tests/example.gd", source)
	assert_eq(findings.size(), 1, "one unconditional test flagged")
	assert_eq(str((findings[0] as Dictionary)["function"]), "test_stub")


func test_audit_flags_bare_pass_test() -> void:
	if _audit == null:
		return
	var source := "func test_nothing() -> void:\n\tpass_test(\"ok\")\n"
	assert_eq(_audit.call(&"audit_source", "res://tests/example.gd", source).size(), 1, "pass_test-only is unconditional")


func test_audit_accepts_a_real_assertion() -> void:
	if _audit == null:
		return
	var source := "func test_real() -> void:\n\tassert_eq(compute(), 5, \"value\")\n"
	assert_eq(_audit.call(&"audit_source", "res://tests/example.gd", source).size(), 0, "a real assertion is not flagged")


func test_audit_accepts_constant_true_alongside_a_real_assertion() -> void:
	if _audit == null:
		return
	var source := "func test_mixed() -> void:\n\tassert_true(true, \"marker\")\n\tassert_eq(x, 1, \"real\")\n"
	assert_eq(_audit.call(&"audit_source", "res://tests/example.gd", source).size(), 0,
		"only tests whose ONLY effective assertion is constant are flagged")


func test_audit_ignores_non_test_functions() -> void:
	if _audit == null:
		return
	var source := "func helper() -> void:\n\tassert_true(true, \"fine\")\n"
	assert_eq(_audit.call(&"audit_source", "res://tests/example.gd", source).size(), 0, "only test_ functions are audited")


func test_repository_contains_no_unconditional_pass_tests() -> void:
	if _audit == null:
		return
	var findings: Array = _audit.call(&"audit_directory", "res://tests")
	var names: Array = []
	for finding in findings:
		names.append("%s::%s" % [str((finding as Dictionary)["path"]), str((finding as Dictionary)["function"])])
	assert_eq(findings.size(), 0, "no test may pass unconditionally: " + str(names))
