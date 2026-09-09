extends DialogicLayoutLayer
## The existing Dialogic layout owns this view's complete lifetime.
const ART_VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
var _view: ART_VIEW
var _bridge: Node
var _profile: Node

func _ready() -> void:
	super._ready()
	_view = ART_VIEW.new()
	_view.name = "SceneArt"
	add_child(_view)
	_bridge = get_node_or_null("/root/DialogicBridge")
	_profile = get_node_or_null("/root/ProfileManager")
	if _bridge != null and _bridge.has_signal("scene_art_changed"):
		_bridge.connect("scene_art_changed", refresh_art)
	if _profile != null and _profile.has_signal("preference_changed"):
		_profile.connect("preference_changed", _on_preference_changed)
	refresh_art()

func refresh_art() -> void:
	if not is_instance_valid(_view): return
	var source: Dictionary = _bridge.get_current_scene_art() if _bridge != null \
		and _bridge.has_method("get_current_scene_art") else {}
	var percent := 100
	if _profile != null and _profile.has_method("get_preference"):
		percent = int(_profile.get_preference(&"preferences.accessibility.text_size", 100))
	_view.configure_entry(str(source.get("entry_id", "")), percent, false,
		bool(source.get("show_portraits", false)))

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path == &"preferences.accessibility.text_size": refresh_art()
