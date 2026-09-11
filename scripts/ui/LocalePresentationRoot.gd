class_name LocalePresentationRoot
extends Node

const CATALOG := preload("res://scripts/localization/LocalizationCatalog.gd")

@export var target_path: NodePath = NodePath("..")

var _localization: Node
var _target: Control
var _runtime_backup: Dictionary = {}
var _registration_result: Dictionary = {}


func _ready() -> void:
	_target = get_node_or_null(target_path) as Control
	if _localization == null:
		_localization = get_node_or_null("/root/LocalizationManager")
	if _localization != null and _localization.has_method("register_presentation_root"):
		_registration_result = _localization.register_presentation_root(self).duplicate(true)


func _exit_tree() -> void:
	if _localization != null and _localization.has_method("unregister_presentation_root"):
		_localization.unregister_presentation_root(self)


func prepare_presentation(profile: Dictionary) -> Dictionary:
	var target_result := _resolve_target()
	if not target_result.get("ok", false):
		return target_result
	if not profile.has_all(["locale_id", "font_profile", "layout_direction"]):
		return _fail(&"invalid_presentation_profile")
	var direction: String = profile["layout_direction"]
	if direction not in ["ltr", "rtl"]:
		return _fail(&"invalid_layout_direction")
	var font_paths: Dictionary
	if _localization != null and _localization.has_method("get_font_paths"):
		font_paths = _localization.get_font_paths(str(profile["font_profile"]))
	else:
		# Standalone preview roots can still resolve without a configured owner.
		var loaded: Dictionary = CATALOG.load_bundle("res://localization/manifest.json")
		if not loaded.get("ok", false):
			return loaded
		font_paths = _font_paths_for_profile(loaded["value"]["manifest"], str(profile["font_profile"]))
	if not font_paths.get("ok", false):
		return font_paths
	var theme := _target.theme.duplicate(true) as Theme if _target.theme != null else Theme.new()
	var fonts: Array[Font] = []
	for relative_path in font_paths["value"]:
		var font: Font = load("res://localization/%s" % relative_path) as Font
		if font == null:
			return _fail(&"font_load_failed")
		fonts.append(font)
	if not fonts.is_empty():
		var primary: Font = fonts[0].duplicate(true)
		var fallbacks: Array[Font] = []
		for index in range(1, fonts.size()):
			fallbacks.append(fonts[index].duplicate(true))
		primary.fallbacks = fallbacks
		theme.default_font = primary
	return _success({
		"theme": theme,
		"layout_direction": Control.LAYOUT_DIRECTION_LTR if direction == "ltr" else Control.LAYOUT_DIRECTION_RTL,
	})


func capture_presentation_state() -> Dictionary:
	var target_result := _resolve_target()
	if not target_result.get("ok", false):
		return target_result
	var theme_copy: Theme = _target.theme.duplicate(true) as Theme if _target.theme != null else null
	return _success({"theme": theme_copy, "layout_direction": _target.layout_direction})


func apply_presentation_silent(plan: Dictionary) -> Dictionary:
	var target_result := _resolve_target()
	if not target_result.get("ok", false):
		return target_result
	if not plan.has_all(["theme", "layout_direction"]) or not plan["theme"] is Theme:
		return _fail(&"invalid_presentation_plan")
	_runtime_backup = capture_presentation_state()["value"]
	_target.theme = (plan["theme"] as Theme).duplicate(true)
	_target.layout_direction = int(plan["layout_direction"]) as Control.LayoutDirection
	return _success()


func rollback_presentation_silent(backup: Dictionary) -> Dictionary:
	var target_result := _resolve_target()
	if not target_result.get("ok", false):
		return target_result
	var value: Dictionary = backup.get("value", backup)
	if not value.has_all(["theme", "layout_direction"]):
		return _fail(&"invalid_presentation_backup")
	_target.theme = (value["theme"] as Theme).duplicate(true) if value["theme"] != null else null
	_target.layout_direction = int(value["layout_direction"]) as Control.LayoutDirection
	_runtime_backup = {}
	return _success()


func finalize_presentation() -> Dictionary:
	_runtime_backup = {}
	return _success()


func _resolve_target() -> Dictionary:
	if _target == null or not is_instance_valid(_target):
		_target = get_node_or_null(target_path) as Control
	if _target == null:
		return _fail(&"invalid_presentation_target")
	return _success()


func _font_paths_for_profile(manifest: Dictionary, profile_id: String) -> Dictionary:
	var records := {}
	for record in manifest["font_profiles"]:
		records[record["id"]] = record
	if not records.has(profile_id):
		return _fail(&"unknown_font_profile")
	var output: Array[String] = []
	var cursor: Variant = profile_id
	while cursor != null:
		for path in records[cursor]["font_files"]:
			output.append(path)
		cursor = records[cursor]["fallback_profile"]
	return _success(output)


func _success(value: Variant = {}) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
