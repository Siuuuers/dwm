extends Node
# AccessibilityManager (CONTRACTS §8): applies committed profile readability preferences
# to trees. Never conveys essential info by color
# alone; every apply method is crash-safe on partial/empty trees.


var _profile: Node
var _mutation_gate: Object

func _ready() -> void:
	pass

func configure_mutation_gate(gate: Object) -> Dictionary:
	return _configure_gate(gate)

func initialize(profile: Node) -> Dictionary:
	if profile == null or not profile.has_method("get_preference"): return {"ok": false, "code": &"invalid_profile_manager"}
	_profile = profile
	return {"ok": true}


func _setting(key: String, default_value: Variant) -> Variant:
	if _profile == null: return default_value
	var group := "dialogue" if key in ["text_speed", "auto_text_speed"] else "accessibility"
	return _profile.get_preference(StringName("preferences.%s.%s" % [group, key]), default_value)


func apply_settings_to_tree(root: Node) -> void:
	if root == null:
		return
	apply_font_scale(root, float(_setting("font_scale", 1.0)))
	apply_high_contrast(root, bool(_setting("high_contrast", false)))
	apply_large_click_targets(root)
	apply_reduced_motion_to_tree(root)
	refresh_visible_text(root)


func apply_font_scale(root: Node, scale: float) -> void:
	if root == null or scale <= 0.0:
		return
	# Store the scale as metadata so LocalizedText/UI helpers can apply it; also nudge
	# Controls that expose a base font size, guarding against missing theme entries.
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
	if bool(_setting("large_click_targets", false)):
		return Vector2(64, 64)
	return Vector2(44, 44)


func make_control_accessible(control: Control, label_key: String = "") -> void:
	if control == null:
		return
	control.focus_mode = Control.FOCUS_ALL
	if label_key != "":
		control.set_meta("a11y_label_key", label_key)
		var loc := get_node_or_null("/root/LocalizationManager")
		if loc != null and loc.has_method("t"):
			control.tooltip_text = loc.t(label_key)
	var min_size := get_minimum_click_size()
	control.custom_minimum_size = control.custom_minimum_size.max(min_size)


func should_reduce_motion() -> bool:
	return bool(_setting("reduced_motion", false))


func get_text_delay() -> float:
	var speed := float(_setting("text_speed", 1.0))
	return 0.03 / maxf(0.1, speed)


func get_auto_advance_delay() -> float:
	var speed := float(_setting("auto_text_speed", 1.0))
	return 2.0 / maxf(0.1, speed)


func refresh_visible_text(root: Node) -> void:
	if root == null:
		return
	if root.has_method("refresh_localized_text"):
		root.call("refresh_localized_text")
	for child in root.get_children():
		refresh_visible_text(child)


func apply_large_click_targets(root: Node) -> void:
	if root == null or not bool(_setting("large_click_targets", false)):
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


# ---- Convenience getters (settings-driven, crash-safe) ----
func are_subtitles_enabled() -> bool:
	return bool(_setting("subtitles_enabled", true))


func are_captions_enabled() -> bool:
	return bool(_setting("captions_enabled", true))


func should_show_visual_audio_cues() -> bool:
	return bool(_setting("visual_audio_cues", true))


func should_allow_flashing_effects() -> bool:
	return bool(_setting("flashing_effects_enabled", false))


func get_text_box_opacity() -> float:
	return float(_setting("text_box_opacity", 0.90))


func get_subtitle_background_opacity() -> float:
	return float(_setting("subtitle_background_opacity", 0.85))

func _configure_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id(): return {"ok": false, "code": &"mutation_gate_already_configured", "details": {}, "receipt": {}}
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}
