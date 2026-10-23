extends "res://tests/support/ScenePlayableFixture.gd"
## Initial activation refusal uses real Profile/Run/Save, router and native Bridge.
## Inherited TEST content/host and diagnostic ancillary restore participants are
## explicit. No Pause or replacement input/audio/localization services are needed.
var default_style_before: Dictionary = {}
var style_refusal_count := 0

func default_style_projection() -> Dictionary:
	var key := "dialogic/layout/default_style"
	return {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}

func setup_refusal(scene_tree: SceneTree) -> Dictionary:
	default_style_before = default_style_projection()
	var checked: Dictionary = await setup_playable(scene_tree)
	if not checked.get("ok", false): return checked
	var inherited_layout: Node = runtime.Styles.get_layout_node()
	if is_instance_valid(inherited_layout):
		inherited_layout.queue_free()
		for frame: int in 4:
			await tree.process_frame
			if not is_instance_valid(inherited_layout): break
		if is_instance_valid(inherited_layout):
			return {"ok": false, "code": &"TEST.style_refusal_inherited_layout_not_retired"}
	if runtime.Styles.has_active_layout_node():
		return {"ok": false, "code": &"TEST.style_refusal_inherited_layout_active"}
	if is_instance_valid(viewport):
		viewport.queue_free()
		await tree.process_frame
		if is_instance_valid(viewport):
			return {"ok": false, "code": &"TEST.style_refusal_unused_viewport_not_retired"}
		viewport = null
	if default_style_projection() != default_style_before:
		return {"ok": false, "code": &"TEST.style_refusal_default_style_changed"}
	return {"ok": true}

func refuse_selected_style(_info: Dictionary) -> void:
	# Remove authority only: retire the genuine layout inside style_changed.
	var layout: Node = runtime.Styles.get_layout_node()
	if is_instance_valid(layout):
		style_refusal_count += 1
		layout.queue_free()
