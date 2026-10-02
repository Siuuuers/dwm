extends RefCounted
## Test-only passive observer. Start before Next/Load; never change layout or Focus.
## Both streams retain mount transients and finish after 120 visible challenge samples.
const SAMPLE_COUNT := 120
const EVENT_LIMIT := 1800
const ROLES := ["ChallengeContent", "ChallengeTitle", "DatingWorksheet", "ContentWell",
	"Grid", "ChallengeStatus", "ChallengeViewFooter", "BoardViewControls"]

var _tree: SceneTree
var _content: WeakRef
var _scene: WeakRef
var _controls: Dictionary = {}
var _connections: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _samples: Array[Dictionary] = []
var _visible_counts := {"process": 0, "post_draw": 0}
var _sample_counts := {"process": 0, "post_draw": 0}
var _sequence := 0
var _dropped_events := 0
var _running := false


func start(tree: SceneTree) -> void:
	assert(not _running and _tree == null, "Each layout probe observes one journey boundary.")
	_tree = tree
	_running = true
	_connect(tree, &"node_added", _on_node_added)
	_connect(tree, &"process_frame", _on_process_frame)
	_connect(RenderingServer, &"frame_post_draw", _on_post_draw)
	_connect(tree.root, &"gui_focus_changed", _on_focus_changed)
	for node: Node in tree.root.find_children("ChallengeContent", "ScrollContainer", true, false):
		_on_node_added(node)
		_observe_descendants(node)
	_record_event("start", null)
	_sample("before")


func is_complete() -> bool:
	return _visible_counts.process >= SAMPLE_COUNT and _visible_counts.post_draw >= SAMPLE_COUNT


func stop() -> void:
	if not _running: return
	_running = false
	for connection: Dictionary in _connections:
		var object: Object = connection.object.get_ref()
		if is_instance_valid(object) and object.is_connected(connection.signal_name, connection.callback):
			object.disconnect(connection.signal_name, connection.callback)
	_connections.clear()


func report() -> Dictionary:
	return {"complete": is_complete(), "required_visible_samples": SAMPLE_COUNT,
		"visible_samples": _visible_counts.duplicate(), "total_samples": _sample_counts.duplicate(),
		"events_dropped": _dropped_events, "events": _events.duplicate(true),
		"samples": _samples.duplicate(true)}


func _connect(object: Object, signal_name: StringName, callback: Callable) -> void:
	object.connect(signal_name, callback)
	_connections.append({"object": weakref(object), "signal_name": signal_name, "callback": callback})


func _on_node_added(node: Node) -> void:
	if node is ScrollContainer and node.name == &"ChallengeContent":
		_content = weakref(node)
		var ancestor: Node = node.get_parent()
		while ancestor != null:
			var script: Script = ancestor.get_script()
			if script != null and script.resource_path == "res://scripts/ui/DatingScene.gd":
				_scene = weakref(ancestor)
				break
			ancestor = ancestor.get_parent()
		_controls.clear()
		for axis: String in ["v", "h"]:
			var bar: ScrollBar = node.get_v_scroll_bar() if axis == "v" else node.get_h_scroll_bar()
			_connect(bar, &"value_changed", _on_scroll_changed.bind(axis))
		_record_event("challenge_mount", node)
	var content: Control = _get_control(_content)
	if not node is Control or content == null or (node != content and not content.is_ancestor_of(node)): return
	var role := str(node.name)
	if node.get_parent() == content and node is VBoxContainer: role = "ChallengePanel"
	if role not in ROLES and role != "ChallengePanel": return
	if _controls.has(role) and _controls[role].get_ref() == node: return
	_controls[role] = weakref(node)
	for signal_name: StringName in [&"resized", &"minimum_size_changed", &"visibility_changed",
			&"focus_entered", &"focus_exited"]:
		_connect(node, signal_name, _on_control_event.bind(str(signal_name), weakref(node)))
	if node is Container:
		_connect(node, &"pre_sort_children", _on_control_event.bind("pre_sort_children", weakref(node)))
		_connect(node, &"sort_children", _on_control_event.bind("sort_children", weakref(node)))
	if role == "ChallengeTitle":
		_connect(node, &"draw", _on_control_event.bind("title_draw", weakref(node)))
	_record_event("observe:" + role, node)


func _observe_descendants(node: Node) -> void:
	for child: Node in node.get_children():
		_on_node_added(child)
		_observe_descendants(child)


func _on_control_event(kind: String, node_ref: WeakRef) -> void:
	_record_event(kind, _get_control(node_ref))


func _on_scroll_changed(_value: float, axis: String) -> void:
	_record_event(axis + "_scroll_changed", _get_control(_content))


func _on_focus_changed(control: Control) -> void:
	_record_event("gui_focus_changed", control)


func _on_process_frame() -> void:
	_sample("process")


func _on_post_draw() -> void:
	_sample("post_draw")


func _sample(stream: String) -> void:
	if not _running: return
	if stream != "before" and int(_visible_counts[stream]) >= SAMPLE_COUNT: return
	var sample := _stamp(stream)
	var content: ScrollContainer = _get_control(_content) as ScrollContainer
	var visible := content != null and content.is_visible_in_tree()
	sample["challenge_visible"] = visible
	sample["focus"] = _focus_path()
	sample["scroll"] = _scroll_state(content)
	var controls: Dictionary = {}
	for role: String in _controls:
		var control: Control = _get_control(_controls[role])
		if control != null: controls[role] = _control_state(control)
	sample["controls"] = controls
	var scene: Object = _scene.get_ref() if _scene != null else null
	if is_instance_valid(scene):
		sample["phase"] = str(scene.get("_physical_view").get("phase", ""))
		sample["challenge_band"] = _vector(scene.get("_challenge_band"))
		sample["layout_pending"] = bool(scene.get("_challenge_layout_pending"))
	var worksheet: Control = _get_control(_controls.get("DatingWorksheet"))
	if worksheet != null:
		sample["worksheet_band"] = _vector(worksheet.get("_band"))
		sample["worksheet_scroll"] = _vector(worksheet.get_scroll())
		var grid: Control = worksheet.get("grid")
		var projection: Dictionary = grid.get("projection")
		sample["grid"] = {"focused_index": grid.get("focused_index"),
			"projection_empty": projection.is_empty(), "width": projection.get("width", 0),
			"height": projection.get("height", 0), "scale": _vector(grid.scale)}
	_samples.append(sample)
	if stream != "before":
		_sample_counts[stream] += 1
		if visible: _visible_counts[stream] += 1
	if is_complete(): stop()


func _record_event(kind: String, control: Control) -> void:
	if not _running: return
	if _events.size() >= EVENT_LIMIT:
		_dropped_events += 1
		return
	var event := _stamp(kind)
	event["focus"] = _focus_path()
	event["scroll"] = _scroll_state(_get_control(_content) as ScrollContainer)
	if control != null: event["control"] = _control_state(control)
	_events.append(event)


func _stamp(kind: String) -> Dictionary:
	_sequence += 1
	return {"sequence": _sequence, "kind": kind, "process_frame": Engine.get_process_frames(),
		"drawn_frame": Engine.get_frames_drawn()}


func _control_state(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	var clip := Rect2(Vector2.ZERO, _tree.root.get_visible_rect().size)
	var ancestor: Node = control.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents: clip = clip.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return {"path": str(control.get_path()), "rect": _rect(rect), "size": _vector(control.size),
		"minimum": _vector(control.get_minimum_size()), "combined_minimum": _vector(control.get_combined_minimum_size()),
		"custom_minimum": _vector(control.custom_minimum_size), "visible": control.visible,
		"visible_in_tree": control.is_visible_in_tree(), "clip": _rect(clip),
		"fully_inside_clip": clip.encloses(rect), "focus": control.has_focus(), "focus_mode": control.focus_mode}


func _scroll_state(content: ScrollContainer) -> Dictionary:
	if content == null: return {}
	var bar := content.get_v_scroll_bar()
	return {"vertical": content.scroll_vertical, "horizontal": content.scroll_horizontal,
		"follow_focus": content.follow_focus, "v_visible": bar.visible,
		"v_max": bar.max_value, "v_page": bar.page, "v_width": bar.size.x}


func _focus_path() -> String:
	var focus: Control = _tree.root.gui_get_focus_owner()
	return str(focus.get_path()) if focus != null else ""


func _get_control(reference: WeakRef) -> Control:
	return reference.get_ref() as Control if reference != null else null


func _vector(value: Vector2) -> Array:
	return [value.x, value.y]


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
