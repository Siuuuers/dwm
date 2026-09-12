extends "res://addons/gut/test.gd"
## Exercise the real CLI decision without constructing SceneTree or writing scene files.

const CLI := preload("res://tools/dialogic/validate_dialogic_contract.gd")
const VALIDATOR := preload("res://tools/dialogic/DtlStructureValidator.gd")
const ROOT := "res://dialogic/timelines/en/"


func _guard() -> bool:
	var script: Script = CLI
	for method: Dictionary in script.get_script_method_list():
		if method["name"] == "validate_scenes": return true
	fail_test("the CLI needs a callable scene-validation decision")
	return false


func _entry(label: String, path: String) -> Dictionary:
	return {"locators": {"en": {"path": path, "label": label}},
		"role": "ordinary_message", "allowed_signals": ["history.line.witness"]}


func _document(entries: Array) -> Dictionary:
	return {"entries": entries, "entry_count": entries.size()}


func test_valid_scenes_forward_exact_semantic_hooks_and_legacy_labels_once() -> void:
	if not _guard(): return
	var path := ROOT + "contacts/shared.dtl"
	var legacy_path := ROOT + "core/opening.dtl"
	var document := _document([_entry("scene.first", path), _entry("scene.second", path)])
	var timelines := {"records": [
		{"path": path.trim_prefix("res://"), "labels": ["history"]},
		{"path": legacy_path.trim_prefix("res://"), "labels": ["opening"]}]}
	var calls: Array = []
	var validate_scene := func(scene_path: String, expected: Array, legacy: Array) -> Dictionary:
		calls.append({"path": scene_path, "expected": expected, "legacy": legacy})
		return {"ok": true, "failures": []}
	var script: Script = CLI
	var status: int = script.call(&"validate_scenes", document, timelines, validate_scene)
	assert_eq(status, 0)
	assert_eq_deep(calls, [
		{"path": path, "expected": [
			{"label": "scene.first", "role": "ordinary_message", "allowed_signals": ["history.line.witness"]},
			{"label": "scene.second", "role": "ordinary_message", "allowed_signals": ["history.line.witness"]}],
			"legacy": ["history"]},
		{"path": legacy_path, "expected": [], "legacy": ["opening"]}])


func test_failed_scene_returns_nonzero_and_does_not_skip_remaining_scenes() -> void:
	if not _guard(): return
	var bad_path := ROOT + "contacts/bad.dtl"
	var good_path := ROOT + "contacts/good.dtl"
	var timelines := {"records": [
		{"path": bad_path.trim_prefix("res://"), "labels": []},
		{"path": good_path.trim_prefix("res://"), "labels": []}]}
	var calls: Array = []
	var validate_scene := func(path: String, expected: Array, legacy: Array) -> Dictionary:
		calls.append(path)
		var text := "return\nSomeone: prose\n" if path == bad_path else "return\n"
		return VALIDATOR.validate_text(path, text, expected, legacy)
	var script: Script = CLI
	var status: int = script.call(&"validate_scenes", _document([]), timelines, validate_scene)
	assert_eq(status, 1, "one rejected scene must fail the CLI")
	assert_eq(calls, [bad_path, good_path], "all registered scenes are checked after a failure")


func _assert_path_refused(path: String) -> void:
	var calls: Array = []
	var validate_scene := func(scene_path: String, _expected: Array, _legacy: Array) -> Dictionary:
		calls.append(scene_path)
		return {"ok": true, "failures": []}
	var script: Script = CLI
	var status: int = script.call(&"validate_scenes", _document([_entry("scene.entry", path)]),
		{"records": []}, validate_scene)
	assert_eq(status, 1)
	assert_eq(calls.size(), 0, "refuse the path before reading it")


func test_path_outside_english_scene_root_is_refused_before_file_validation() -> void:
	if not _guard(): return
	_assert_path_refused("res://outside/contacts/scene.dtl")


func test_flat_master_style_path_is_refused_before_file_validation() -> void:
	if not _guard(): return
	_assert_path_refused(ROOT + "day_1.dtl")
