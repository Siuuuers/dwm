extends Control
## Scene chrome only. Bootstrap owns admission, persistence, and panel mounting.

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const CONTROL_KEYS := {
	"Settings": "ui.pause.settings", "Backup": "ui.pause.backup",
	"Apps": "scene.controls.apps", "Save": "button.save", "Load": "button.load", "Contacts": "app.contacts",
}

var _actions: Dictionary = {}
var _computer_open := false
var _computer_content_visible := false
var _busy := false
var _localization: Node
var _thought_frontier: Dictionary = {}
var _thought_poll := 0.0
var _thought_options_offer: Dictionary = {}
var _profile: Node

func _ready() -> void:
	$SceneControlsLayer/Surface/ThoughtYes.pressed.connect(_accept_thought)
	_bind_presentation()
	$SceneControlsLayer/Surface/Controls/CheckComputer.pressed.connect(_toggle_computer)
	for action: String in ["settings", "backup", "save", "load", "contacts", "apps"]:
		get_node("SceneControlsLayer/Surface/Controls/" + action.capitalize()).pressed.connect(_invoke.bind(action))
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
	$SceneControlsLayer/Surface/Controls/Contacts.visible = _computer_open
	$SceneControlsLayer/Surface/Controls/Apps.visible = _computer_open

func is_computer_open() -> bool:
	return _computer_open

func set_computer_open(open: bool) -> void:
	_computer_open = open
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
	var controls: VBoxContainer = $SceneControlsLayer/Surface/Controls
	controls.theme = presentation
	$SceneControlsLayer/Surface/ThoughtYes.theme = presentation
	var story_presentation := presentation.duplicate() as Theme
	story_presentation.default_font = TYPOGRAPHY.story_font(locale, percent, font_style)
	$SceneControlsLayer/Surface/ThoughtOptions.theme = story_presentation
	$SceneControlsLayer/Surface/ThoughtYes.text = _localization.t("scene.thought.yes")
	$SceneControlsLayer/Surface/ThoughtYes.accessibility_name = $SceneControlsLayer/Surface/ThoughtYes.text
	for control_name: String in CONTROL_KEYS:
		var button: Button = controls.get_node(control_name)
		button.text = _localization.t(CONTROL_KEYS[control_name])
		button.accessibility_name = button.text
	var computer: Button = controls.get_node("CheckComputer")
	computer.text = _localization.t("scene.controls.close_computer" if _computer_open else "scene.controls.check_computer")
	computer.accessibility_name = computer.text

func _toggle_computer() -> void:
	# Consume before awaiting: closing must not forward this click into dialogue.
	get_viewport().set_input_as_handled()
	if _busy: return
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
	if _busy: return
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
	for action: String in ["settings", "backup", "save", "load", "contacts", "apps"]:
		var callback: Callable = _actions.get(action, Callable())
		get_node("SceneControlsLayer/Surface/Controls/" + action.capitalize()).disabled = _busy or not callback.is_valid()

## Read-only offer projection. The captured presentation proof is retained until
## the button is pressed, so Load or native movement cannot borrow a fresh token.
func _process(delta: float) -> void:
	_thought_poll -= delta
	if _thought_poll > 0.0: return
	_thought_poll = 0.1
	var button: Button = $SceneControlsLayer/Surface/ThoughtYes
	var bridge := get_node_or_null("/root/DialogicBridge")
	var marker: Dictionary = bridge.capture_scene_pending_marker() if bridge != null else {}
	var available: bool = not _busy and not _computer_open and marker.get("ok", false) and marker.value.kind in ["thought.pass", "thought.options"]
	if available:
		var game := get_node_or_null("/root/GameState")
		if game == null: available = false
		else:
			for receipt: Dictionary in game.capture_run_snapshot_input().command_receipts.values():
				var result: Dictionary = receipt.get("scene_event", {}).get("result", {})
				if result.get("kind") == "thought_resolved" and result.opportunity_id == marker.value.payload.opportunity_id:
					available = false
	_thought_frontier = bridge.capture_current_line_presentation_frontier() if available else {}
	var shown: bool = available and _thought_frontier.get("ok", false)
	button.visible = shown and marker.value.kind == "thought.pass"
	button.disabled = not button.visible
	_refresh_thought_options(marker.value.payload.options if shown and marker.value.kind == "thought.options" else [])

func _refresh_thought_options(options: Array) -> void:
	var panel: ScrollContainer = $SceneControlsLayer/Surface/ThoughtOptions
	var column: VBoxContainer = panel.get_node("Options")
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
		button.custom_minimum_size = Vector2(0, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
