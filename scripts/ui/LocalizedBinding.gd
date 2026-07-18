class_name LocalizedBinding
extends Node

const TARGET_PROPERTIES := ["text", "placeholder_text", "tooltip_text", "accessibility_name"]

@export var target_path: NodePath = NodePath("..")
@export_enum("text", "placeholder_text", "tooltip_text", "accessibility_name")
var target_property: String = "text"
@export var key: String = ""
@export var parameters: Dictionary = {}

var _localization: Node
var _target: Object


func _ready() -> void:
	parameters = parameters.duplicate(true)
	if _localization == null:
		_localization = get_node_or_null("/root/LocalizationManager")
	_target = get_node_or_null(target_path)
	if _localization != null and _localization.has_signal("locale_changed"):
		if not _localization.locale_changed.is_connected(_on_locale_changed):
			_localization.locale_changed.connect(_on_locale_changed)
	var refreshed := refresh()
	if not refreshed.get("ok", false) and _localization != null and _localization.has_method("get_readiness"):
		call_deferred("_refresh_after_bootstrap")


func set_parameters(value: Dictionary) -> Dictionary:
	var candidate := value.duplicate(true)
	var validated := _validate_contract()
	if not validated.get("ok", false):
		return validated
	var translated: String = _localization.t(key, candidate)
	if translated == "[format_error:%s]" % key:
		return _fail(&"parameter_mismatch")
	parameters = candidate.duplicate(true)
	_target.set(target_property, translated)
	return _success()


func refresh() -> Dictionary:
	var validated := _validate_contract()
	if not validated.get("ok", false):
		return validated
	var translated: String = _localization.t(key, parameters.duplicate(true))
	if translated == "[format_error:%s]" % key:
		return _fail(&"parameter_mismatch")
	_target.set(target_property, translated)
	return _success()


func _on_locale_changed(_locale_id: String) -> void:
	refresh()


func _refresh_after_bootstrap() -> void:
	if _localization != null and _localization.get_readiness() == &"ready":
		refresh()


func _validate_contract() -> Dictionary:
	if _localization == null or not _localization.has_method("t") or not _localization.has_method("has_key"):
		return _fail(&"localization_not_available")
	if _target == null or not is_instance_valid(_target):
		_target = get_node_or_null(target_path)
	if _target == null:
		return _fail(&"invalid_target")
	if target_property not in TARGET_PROPERTIES or not _has_property(_target, target_property):
		return _fail(&"invalid_target_property")
	if key.is_empty() or not _localization.has_key(key):
		return _fail(&"unknown_localization_key")
	return _success()


func _has_property(target: Object, property_name: String) -> bool:
	for property in target.get_property_list():
		if property["name"] == property_name:
			return true
	return false


func _success() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
