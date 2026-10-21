extends Control
## Accessible projection of the real tappable background, not another input owner.

var _accept_input: Node
var _localization: Node
var _label := ""
var _available := false
var _source_visible := false

# Diagnostic seed is set only by the isolated first-registration fixture.
# _init runs on the actual scene instance, before its ordinary tree entry.
func _init() -> void:
	if not has_meta(&"continue_registration_observation") and Engine.has_meta(&"dwm_continue_registration_seed"):
		var seed: Dictionary = Engine.get_meta(&"dwm_continue_registration_seed")
		if int(seed.get("owner_id", 0)) == 0:
			seed["owner_id"] = get_instance_id()
			set_meta(&"continue_registration_observation", seed)
	_observe_registration("instance_init")

func bind_accessible_continue(input_owner: Node, localization: Node) -> void:
	_observe_registration("bind_enter")
	_accept_input = input_owner
	_localization = localization
	_accept_input.bind_accessible_continue(self)
	_refresh_projection()
	_observe_registration("bind_return")

func _process(_delta: float) -> void:
	_refresh_projection()

func _refresh_projection() -> void:
	var label := ""
	if is_instance_valid(_localization) and _localization.get_readiness() == &"ready" \
			and _localization.has_key("button.continue"):
		label = _localization.t("button.continue")
	var source_visible: bool = not label.is_empty() and is_visible_in_tree() \
		and mouse_filter == Control.MOUSE_FILTER_STOP and is_instance_valid(_accept_input) \
		and _accept_input.is_source_admitted()
	var available: bool = source_visible and _accept_input.is_accessibility_continue_admitted()
	if label == _label and available == _available and source_visible == _source_visible: return
	_label = label
	_source_visible = source_visible
	_available = available
	_observe_registration("projection_changed", {"label": _label, "available": _available, "source_visible": _source_visible})
	_observe_registration("queue_request")
	queue_accessibility_update()
	_observe_registration("queue_return")

func capture_continue_action() -> Callable:
	_observe_registration("owner_capture_enter")
	var action: Callable = _accept_input.capture_accessibility_continue()
	if has_meta(&"continue_registration_observation"):
		_observe_registration("owner_capture_return", {
			"reveal": _accept_input._caption.get_reveal_generation(),
			"custody": _accept_input._accessibility_generation,
			"target": _accept_input._focus_caption().get_instance_id()})
	return action

# Complete totals and last facts per phase outlive the bounded event prefix.
func _observe_registration(stage: String, facts: Dictionary = {}) -> void:
	if not has_meta(&"continue_registration_observation"): return
	var observation: Dictionary = get_meta(&"continue_registration_observation")
	var phase: String = observation.phase
	var totals: Dictionary = observation.phases[phase].counts
	observation.counts[stage] = int(observation.counts.get(stage, 0)) + 1
	totals[stage] = int(totals.get(stage, 0)) + 1
	var sample := {"usec": Time.get_ticks_usec(), "phase": phase, "stage": stage,
		"surface_id": get_instance_id(), "inside_tree": is_inside_tree(), "facts": facts}
	observation.last[stage] = sample
	observation.phases[phase].last[stage] = sample
	if observation.events.size() < 24:
		observation.events.append(sample)

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE: _observe_registration("enter_tree")
	if what == NOTIFICATION_EXIT_TREE: _observe_registration("exit_tree")
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE: return
	_observe_registration("notification")
	var element := get_accessibility_element()
	var element_valid: bool = element.is_valid()
	_observe_registration("element", {"valid": element_valid, "rid": element.get_id()})
	if not element_valid: return
	DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_BUTTON)
	DisplayServer.accessibility_update_set_name(element, _label)
	var available: bool = _available and is_instance_valid(_accept_input) \
		and _accept_input.is_accessibility_continue_admitted()
	var hidden: bool = not _source_visible or not is_visible_in_tree() or not is_instance_valid(_accept_input) \
		or not _accept_input.is_source_admitted()
	_observe_registration("admission", {"available": available, "hidden": hidden,
		"label": _label, "source_visible": _source_visible, "projected_available": _available,
		"visible_in_tree": is_visible_in_tree()})
	DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_HIDDEN, hidden)
	DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_DISABLED, not available)
	if available:
		DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_CLICK,
			capture_continue_action())
		_observe_registration("action_registered")


