extends Node
# AccessibilityManager (CONTRACTS §8): owns UI readability settings and their application
# to trees. Reads settings from GameState.settings. Never conveys essential info by color
# alone; every apply method is crash-safe on partial/empty trees.


func _settings() -> Dictionary:
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.get("settings") is Dictionary:
		return gs.settings
	return {}


func _setting(key: String, default_value: Variant) -> Variant:
	var s := _settings()
	if s.has(key):
		return s[key]
	return default_value


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
