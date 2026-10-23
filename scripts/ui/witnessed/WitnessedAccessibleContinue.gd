extends Control
## Accessible projection of the real tappable background, not another input owner.

var _accept_input: Node
var _localization: Node
var _label := ""
var _available := false
var _source_visible := false

func bind_accessible_continue(input_owner: Node, localization: Node) -> void:
	_accept_input = input_owner
	_localization = localization
	_accept_input.bind_accessible_continue(self)
	_refresh_projection()

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
	queue_accessibility_update()

func capture_continue_action() -> Callable:
	return _accept_input.capture_accessibility_continue()

func _notification(what: int) -> void:
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE: return
	var element := get_accessibility_element()
	if not element.is_valid(): return
	DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_BUTTON)
	DisplayServer.accessibility_update_set_name(element, _label)
	var available: bool = _available and is_instance_valid(_accept_input) \
		and _accept_input.is_accessibility_continue_admitted()
	DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_HIDDEN,
		not _source_visible or not is_visible_in_tree() or not is_instance_valid(_accept_input) \
		or not _accept_input.is_source_admitted())
	DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_DISABLED, not available)
	if available:
		DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_CLICK,
			capture_continue_action())
