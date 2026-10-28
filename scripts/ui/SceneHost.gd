extends Control
## Scene chrome only. Bootstrap owns admission, persistence, and panel mounting.

const TRANSITION_SURFACE := preload("res://scripts/ui/witnessed/SceneTransitionOverlay.gd")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")

var _actions: Dictionary = {}
var _computer_open := false
var _computer_content_visible := false
var _busy := false
var _localization: Node
var _thought_frontier: Dictionary = {}
var _thought_poll := 0.0
var _thought_options_offer: Dictionary = {}
var _thought_panel: Control
var _profile: Node
var _transition_bridge: Node
var transition_surface: Control

func _ready() -> void:
	var transition_layer := CanvasLayer.new()
	transition_layer.name = "SceneTransitionLayer"
	transition_layer.layer = 19
	add_child(transition_layer)
	transition_surface = TRANSITION_SURFACE.new()
	transition_surface.caret = $SceneControlsLayer/Surface/Controls/CheckComputer
	transition_layer.add_child(transition_surface)
	_transition_bridge = get_node_or_null("/root/DialogicBridge")
	if _transition_bridge != null:
		_transition_bridge.configure_scene_transition_surface(transition_surface)
	$SceneControlsLayer/Surface/ThoughtYes.pressed.connect(_accept_thought)
	get_challenge_mount().child_entered_tree.connect(_fit_challenge)
	_bind_presentation()
	var computer: Button = $SceneControlsLayer/Surface/Controls/CheckComputer
	computer.pressed.connect(_toggle_computer)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		computer.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	computer.draw.connect(_draw_computer_caret)
	for event: Signal in [computer.focus_entered, computer.focus_exited, computer.mouse_entered,
		computer.mouse_exited, computer.button_down, computer.button_up]:
		event.connect(computer.queue_redraw)
	$SceneControlsLayer/Surface/Controls/ComputerHome.pressed.connect(_invoke.bind("apps"))
	if _actions.is_empty():
		var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
		if bootstrap != null and bootstrap.has_method("configure_scene_host_view"):
			bootstrap.configure_scene_host_view(self)
	_update_controls()

func configure_scene_controls(actions: Dictionary) -> void:
	_actions = actions.duplicate()
	if is_node_ready(): _update_controls()

func get_challenge_mount() -> Control:
	return $SceneControlsLayer/Surface/ChallengeMount

func _fit_challenge(panel: Node) -> void:
	if panel is Control:
		# Keep the native board geometry; reserve the left caret without clipping.
		panel.scale = Vector2.ONE * (928.0 / 960.0)

func get_computer_mount() -> Control:
	return $SceneControlsLayer/Surface/ComputerMount

## Bootstrap selects the retained shell or Challenge view after successful admission.
## This changes presentation only; it does not acquire or release reading custody.
func set_computer_content_visible(shown: bool) -> void:
	_computer_content_visible = shown
	_update_computer_visibility()

func _update_computer_visibility() -> void:
	$SceneControlsLayer/Surface/ComputerMount.visible = _computer_open and _computer_content_visible
	$SceneControlsLayer/Surface/ChallengeMount.visible = _computer_open and not _computer_content_visible
	$SceneControlsLayer/Surface/Controls/ComputerHome.visible = _computer_open and not _computer_content_visible

func is_computer_open() -> bool:
	return _computer_open

func set_computer_open(open: bool) -> void:
	_computer_open = open
	$SceneControlsLayer/Surface/Controls/CheckComputer.queue_redraw()
	_update_computer_visibility()
	_refresh_presentation()
	_update_controls()

func _bind_presentation() -> void:
	if _localization == null:
		_localization = get_node_or_null("/root/LocalizationManager")
	if _profile == null:
		_profile = get_node_or_null("/root/ProfileManager")
	if _localization != null:
		_localization.locale_changed.connect(_refresh_presentation)
	if _profile != null:
		_profile.preference_changed.connect(_on_presentation_preference_changed)
		_profile.profile_restored.connect(_on_presentation_profile_restored)
	var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
	if bootstrap != null:
		bootstrap.application_ready.connect(_refresh_presentation)
	_refresh_presentation()

func _on_presentation_preference_changed(path: StringName, _value: Variant) -> void:
	if path in [&"preferences.accessibility.text_size", &"preferences.accessibility.font_style"]:
		_refresh_presentation()

func _on_presentation_profile_restored(_snapshot: Dictionary) -> void:
	_refresh_presentation()

func _refresh_presentation(_locale_id: String = "") -> void:
	if not is_inside_tree() or _localization == null or _localization.get_readiness() != &"ready": return
	var locale: String = _localization.get_locale()
	var percent := int(_profile.get_preference(&"preferences.accessibility.text_size", 100)) if _profile != null else 100
	var font_style := str(_profile.get_preference(&"preferences.accessibility.font_style", "pixel")) if _profile != null else "pixel"
	var presentation := Theme.new()
	presentation.default_font = TYPOGRAPHY.font(locale, percent, font_style)
	presentation.default_font_size = TYPOGRAPHY.font_size(locale, percent, 24, font_style)
	# Keep scene chrome typography out of the independently owned Challenge mount.
	var controls: Control = $SceneControlsLayer/Surface/Controls
	controls.theme = presentation
	$SceneControlsLayer/Surface/ThoughtYes.theme = presentation
	var story_presentation := presentation.duplicate() as Theme
	story_presentation.default_font = TYPOGRAPHY.story_font(locale, percent, font_style)
	$SceneControlsLayer/Surface/ThoughtOptions.theme = story_presentation
	$SceneControlsLayer/Surface/ThoughtYes.text = _localization.t("scene.thought.yes")
	$SceneControlsLayer/Surface/ThoughtYes.accessibility_name = $SceneControlsLayer/Surface/ThoughtYes.text
	var home: Button = controls.get_node("ComputerHome")
	home.theme = preload("res://scripts/ui/desktop/DesktopTheme.gd").build(locale, percent, &"midnight", 0.0, false, "standard", font_style)
	home.accessibility_name = _localization.t("scene.controls.apps")
	home.tooltip_text = home.accessibility_name
	var computer: Button = controls.get_node("CheckComputer")
	computer.text = ""
	computer.queue_redraw()
	computer.accessibility_name = _localization.t("scene.controls.close_computer" if _computer_open else "scene.controls.check_computer")
	computer.tooltip_text = computer.accessibility_name

func _draw_computer_caret() -> void:
	var button: Button = $SceneControlsLayer/Surface/Controls/CheckComputer
	var tag := Rect2((button.size - Vector2(32, 24)) * 0.5, Vector2(32, 24))
	var ink := button.get_theme_color("font_disabled_color" if button.disabled else "font_color")
	button.draw_rect(tag, Color(0.08, 0.08, 0.09, 0.8))
	var center := button.size * 0.5
	var rise := -2.5 if _computer_open else 2.5
	button.draw_polyline(PackedVector2Array([center + Vector2(-5, rise), center + Vector2(0, -rise), center + Vector2(5, rise)]), ink, 2.0, true)
	if button.is_hovered() or button.is_pressed(): button.draw_line(tag.position + Vector2(6, 22), tag.end - Vector2(6, 2), ink, 1.0)
	if button.has_focus(): button.draw_rect(tag.grow(2), ink, false, 1.0)

func _toggle_computer() -> void:
	# Consume before awaiting: closing must not forward this click into dialogue.
	get_viewport().set_input_as_handled()
	if _busy or (is_instance_valid(_transition_bridge) and _transition_bridge.is_scene_transition_active()): return
	var opening := not _computer_open
	var action := "computer_open" if opening else "computer_close"
	var callback: Callable = _actions.get(action, Callable())
	if not callback.is_valid(): return
	_busy = true
	_update_controls()
	var result: Variant = await callback.call()
	if not is_inside_tree(): return
	if result is Dictionary and result.get("ok", false):
		set_computer_open(opening)
	_busy = false
	_update_controls()

func _invoke(action: String) -> void:
	get_viewport().set_input_as_handled()
	if _busy or (is_instance_valid(_transition_bridge) and _transition_bridge.is_scene_transition_active()): return
	var callback: Callable = _actions.get(action, Callable())
	if not callback.is_valid(): return
	_busy = true
	_update_controls()
	await callback.call()
	if not is_inside_tree(): return
	_busy = false
	_update_controls()

func _update_controls() -> void:
	if not is_inside_tree(): return
	var computer: Callable = _actions.get("computer_close" if _computer_open else "computer_open", Callable())
	$SceneControlsLayer/Surface/Controls/CheckComputer.disabled = _busy or not computer.is_valid()
	var apps: Callable = _actions.get("apps", Callable())
	$SceneControlsLayer/Surface/Controls/ComputerHome.disabled = _busy or not apps.is_valid()

## Read-only offer projection. The captured presentation proof is retained until
## the button is pressed, so Load or native movement cannot borrow a fresh token.
func configure_thought_panel(panel: Control) -> void:
	_thought_panel = panel
	panel.resized.connect(_layout_thought_controls)
	# Choices share the caption canvas lifetime despite living in this control layer.
	var caption_canvas: CanvasItem = panel.get_parent()
	caption_canvas.visibility_changed.connect(func() -> void:
		_thought_poll = 0.0
		_process(0.0))
	_layout_thought_controls()
	_thought_poll = 0.0

func _layout_thought_controls() -> void:
	if not is_instance_valid(_thought_panel): return
	var rect: Rect2 = _thought_panel.get_choice_row_rect()
	var options: ScrollContainer = $SceneControlsLayer/Surface/ThoughtOptions
	options.position = rect.position
	options.size = rect.size
	var yes: Button = $SceneControlsLayer/Surface/ThoughtYes
	yes.position = rect.position
	yes.size = Vector2(minf(140, rect.size.x), rect.size.y - 18)

func get_thought_controls() -> Array[Control]:
	var result: Array[Control] = []
	var yes: Button = $SceneControlsLayer/Surface/ThoughtYes
	if yes.is_visible_in_tree() and not yes.disabled: result.append(yes)
	if $SceneControlsLayer/Surface/ThoughtOptions.is_visible_in_tree():
		for button: Button in $SceneControlsLayer/Surface/ThoughtOptions/Options.get_children():
			if not button.disabled: result.append(button)
	return result

func _process(delta: float) -> void:
	_thought_poll -= delta
	if _thought_poll > 0.0: return
	_thought_poll = 0.1
	var button: Button = $SceneControlsLayer/Surface/ThoughtYes
	var bridge := get_node_or_null("/root/DialogicBridge")
	# A held control can offer manual continuation, never a Thought. Do not
	# reconstruct its complete saved history on this periodic display query.
	var held_control: bool = bridge != null and bridge.project_scene_optional_frontier(false).get("ok", false)
	var marker: Dictionary = bridge.capture_scene_pending_marker() if bridge != null and not held_control else {}
	var available: bool = not _busy and not _computer_open and marker.get("ok", false) \
		and not bridge.is_scene_transition_active() and marker.value.kind in ["thought.pass", "thought.options"]
	if available:
		var game := get_node_or_null("/root/GameState")
		if game == null: available = false
		else: available = not game.scene_choices.has(marker.value.payload.opportunity_id)
	_thought_frontier = bridge.capture_current_line_presentation_frontier() if available else {}
	var shown: bool = available and _thought_frontier.get("ok", false) and is_instance_valid(_thought_panel) \
		and _thought_panel.get_parent().is_visible_in_tree()
	if is_instance_valid(_thought_panel):
		_thought_panel.set_choice_row_visible(shown)
		_layout_thought_controls()
	button.visible = shown and marker.value.kind == "thought.pass"
	button.disabled = not button.visible
	_refresh_thought_options(marker.value.payload.options if shown and marker.value.kind == "thought.options" else [])

func _refresh_thought_options(options: Array) -> void:
	var panel: ScrollContainer = $SceneControlsLayer/Surface/ThoughtOptions
	var column: HBoxContainer = panel.get_node("Options")
	panel.visible = not options.is_empty()
	var locale: String = _localization.get_locale() if _localization != null else "en"
	var offer := {"options": options, "frontier": _thought_frontier, "locale": locale} if panel.visible else {}
	if offer == _thought_options_offer: return
	_thought_options_offer = offer.duplicate(true)
	for child: Node in column.get_children():
		column.remove_child(child)
		child.queue_free()
	for option: Dictionary in options:
		var button := Button.new()
		var marker: Dictionary = get_node("/root/DialogicBridge").capture_scene_pending_marker()
		var key := "choice.%s.%s" % [marker.get("value", {}).get("payload", {}).get("opportunity_id", ""), option.choice_id]
		button.text = preload("res://scripts/localization/StoryLocalization.gd").text(locale, key, option.text)
		button.accessibility_name = button.text
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Each visible button owns the presentation proof it was created for.
		button.pressed.connect(_select_thought.bind(str(option.choice_id), _thought_frontier.duplicate(true)))
		column.add_child(button)

func _accept_thought() -> void:
	_select_thought("", _thought_frontier.duplicate(true))

func _select_thought(choice_id: String, expected: Dictionary) -> void:
	get_viewport().set_input_as_handled()
	if _busy or _computer_open or not expected.get("ok", false): return
	_busy = true
	$SceneControlsLayer/Surface/ThoughtYes.disabled = true
	for button: Button in $SceneControlsLayer/Surface/ThoughtOptions/Options.get_children(): button.disabled = true
	var game := get_node_or_null("/root/GameState")
	if game != null: game.accept_scene_thought(expected, choice_id)
	_busy = false
	# A refused click may leave the same offer current; rebuild usable buttons.
	_thought_options_offer.clear()
	_thought_poll = 0.0
