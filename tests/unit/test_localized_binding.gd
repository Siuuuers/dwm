extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")

class FakeLocalization:
	extends Node
	signal locale_changed(locale_id: String)
	var calls := 0
	var known_keys := {"test.greeting": true, "test.plain": true}
	func has_key(key: String) -> bool: return known_keys.has(key)
	func t(key: String, params: Dictionary = {}) -> String:
		calls += 1
		if key == "test.greeting":
			if params.keys() != ["name"]: return "[format_error:%s]" % key
			return "Hello, %s" % params["name"]
		return "Plain"
	func register_presentation_root(_root: Node) -> Dictionary: return {"ok": true, "code": &"pending_registration"}
	func unregister_presentation_root(_root: Node) -> Dictionary: return {"ok": true}

var _binding_script: Script
var _presentation_script: Script

func before_all() -> void:
	_binding_script = _require("res://scripts/ui/LocalizedBinding.gd")
	_presentation_script = _require("res://scripts/ui/LocalePresentationRoot.gd")

func _require(path: String) -> Script:
	var result := PROBE.load_script(path)
	assert_true(result.get("ok", false), "%s: %s" % [path, result])
	return result.get("value")

func _make_binding(target: Control, property: String, key: String, params: Dictionary = {}) -> Array:
	var host: Node = autofree(Node.new())
	add_child(host)
	target.name = "Target"
	host.add_child(target)
	var localization: Node = autofree(FakeLocalization.new())
	var binding: Node = _binding_script.new()
	binding.target_path = NodePath("../Target")
	binding.target_property = property
	binding.key = key
	binding.parameters = params
	binding.set("_localization", localization)
	host.add_child(binding)
	return [binding, localization]

func test_ready_refreshes_each_supported_property_once() -> void:
	var label_result := _make_binding(Label.new(), "text", "test.plain")
	assert_eq((label_result[0].get_node("../Target") as Label).text, "Plain")
	assert_eq(label_result[1].calls, 1)
	var line_result := _make_binding(LineEdit.new(), "placeholder_text", "test.plain")
	assert_eq((line_result[0].get_node("../Target") as LineEdit).placeholder_text, "Plain")
	var tooltip_result := _make_binding(Button.new(), "tooltip_text", "test.plain")
	assert_eq((tooltip_result[0].get_node("../Target") as Button).tooltip_text, "Plain")
	var accessible_result := _make_binding(Button.new(), "accessibility_name", "test.plain")
	assert_eq((accessible_result[0].get_node("../Target") as Button).accessibility_name, "Plain")

func test_parameters_are_recursive_copies_and_refresh_only_after_valid_commit() -> void:
	var source := {"name": "Iris", "nested": {"value": 1}}
	var result := _make_binding(Label.new(), "text", "test.greeting", {"name": "Iris"})
	var binding: Node = result[0]
	assert_eq(binding.set_parameters({"name": "Rose"}).get("ok"), true)
	assert_eq((binding.get_node("../Target") as Label).text, "Hello, Rose")
	var before_calls: int = result[1].calls
	assert_eq(binding.set_parameters(source).get("code"), &"parameter_mismatch")
	source["nested"]["value"] = 2
	assert_eq(result[1].calls, before_calls + 1)
	assert_eq(binding.parameters, {"name": "Rose"})

func test_locale_signal_refreshes_exactly_once_and_invalid_contracts_reject() -> void:
	var result := _make_binding(Label.new(), "text", "test.plain")
	var binding: Node = result[0]
	var localization: Node = result[1]
	var before: int = localization.calls
	localization.locale_changed.emit("zh_HK")
	assert_eq(localization.calls, before + 1)
	assert_eq(binding.refresh().get("ok"), true)
	binding.key = "missing"
	assert_eq(binding.refresh().get("code"), &"unknown_localization_key")
	binding.key = "test.plain"
	binding.target_property = "visible"
	assert_eq(binding.refresh().get("code"), &"invalid_target_property")

func test_presentation_prepare_apply_rollback_and_manager_registration() -> void:
	var host: Node = autofree(Node.new())
	add_child(host)
	var target := Control.new()
	target.name = "Target"
	target.layout_direction = Control.LAYOUT_DIRECTION_RTL
	target.theme = Theme.new()
	target.theme.default_font_size = 19
	host.add_child(target)
	var localization: Node = autofree(FakeLocalization.new())
	var root: Node = _presentation_script.new()
	root.target_path = NodePath("../Target")
	root.set("_localization", localization)
	host.add_child(root)
	var profile := {"locale_id": "en", "font_profile": "project_default", "layout_direction": "ltr"}
	var prepared: Dictionary = root.prepare_presentation(profile)
	assert_true(prepared.get("ok", false), str(prepared))
	assert_eq(target.layout_direction, Control.LAYOUT_DIRECTION_RTL)
	assert_eq(target.theme.default_font_size, 19)
	var backup: Dictionary = root.capture_presentation_state()
	assert_true(root.apply_presentation_silent(prepared["value"]).get("ok", false))
	assert_eq(target.layout_direction, Control.LAYOUT_DIRECTION_LTR)
	assert_true(root.rollback_presentation_silent(backup["value"]).get("ok", false))
	assert_eq(target.layout_direction, Control.LAYOUT_DIRECTION_RTL)
	assert_eq(target.theme.default_font_size, 19)
	assert_true(root.finalize_presentation().get("ok", false))
