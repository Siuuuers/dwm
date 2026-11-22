extends Node


var _profile: Node
var _mutation_gate: Object

func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id(): return {"ok": false, "code": &"mutation_gate_already_configured", "details": {}, "receipt": {}}
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}

func initialize(profile: Node) -> Dictionary:
	if profile == null or not profile.has_method("get_preference"): return {"ok": false, "code": &"invalid_profile_manager"}
	_profile = profile
	return {"ok": true}


func _setting(key: String, default_value: Variant) -> Variant:
	if _profile == null: return default_value
	return _profile.get_preference(StringName("preferences.accessibility." + key), default_value)


func apply_settings_to_tree(root: Node) -> void:
	if root == null:
		return
	apply_font_scale(root, int(_setting("text_size", 100)) / 100.0)
	apply_high_contrast(root, bool(_setting("high_contrast", false)))
	apply_large_click_targets(root)
	apply_reduced_motion_to_tree(root)


func apply_font_scale(root: Node, scale: float) -> void:
	if root == null or scale <= 0.0:
		return
	if root is Control:
		(root as Control).set_meta("a11y_font_scale", scale)
	for child in root.get_children():
		apply_font_scale(child, scale)


func apply_high_contrast(root: Node, enabled: bool) -> void:
	if root == null:
		return
	if root is Control:
		(root as Control).set_meta("a11y_high_contrast", enabled)
	for child in root.get_children():
		apply_high_contrast(child, enabled)


func get_minimum_click_size() -> Vector2:
	if bool(_setting("large_targets", false)):
		return Vector2(64, 64)
	return Vector2(48, 48)


func should_reduce_motion() -> bool:
	return bool(_setting("reduced_motion", false))


func get_text_delay() -> float:
	var speed: String = str(_profile.get_preference(&"preferences.reading.reveal_speed","normal")) if _profile != null else "normal"
	return {"instant":0.0,"fast":0.015,"normal":0.03,"slow":0.06}.get(speed,0.03)


func apply_large_click_targets(root: Node) -> void:
	if root == null or not bool(_setting("large_targets", false)):
		return
	var min_size := get_minimum_click_size()
	if root is Control and (root is BaseButton or root.focus_mode == Control.FOCUS_ALL):
		var c := root as Control
		c.custom_minimum_size = c.custom_minimum_size.max(min_size)
	for child in root.get_children():
		apply_large_click_targets(child)


func apply_reduced_motion_to_tree(root: Node) -> void:
	if root == null:
		return
	var reduce := should_reduce_motion()
	if root is Control:
		(root as Control).set_meta("a11y_reduced_motion", reduce)
	for child in root.get_children():
		apply_reduced_motion_to_tree(child)
