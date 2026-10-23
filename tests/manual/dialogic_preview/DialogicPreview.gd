extends Control
## F6-only visual sandbox. Never compose the game or call its narrative owners.
const ART_VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
const ART := preload("res://scripts/data/ArtManifest.gd")
const CAPTION := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const ENTRY_MANIFEST := "res://data/manifests/dialogic_entries.json"
const TIMELINE_FOLDER := "res://tests/manual/dialogic_preview/timelines/"
const FALLBACK_BACKGROUND := preload("res://tests/fixtures/art/placement-background.svg")
const FALLBACK_LEFT := preload("res://tests/fixtures/art/placement-portrait-left.svg")
const FALLBACK_RIGHT := preload("res://tests/fixtures/art/placement-portrait-right.svg")

@export var background: Texture2D
@export var first_portrait: Texture2D
@export var second_portrait: Texture2D

var _manual_start := false
var _entries: Array[Dictionary] = []
var _selected := 0
var _auto_pair := false
var _selector: OptionButton
var _switching := false
var _generation := 0
var _percent := 100
var _art: ART_VIEW
var _layout: Node
var _caption: CAPTION
var _status: Label

func _enter_tree() -> void:
	# Autoload _ready schedules start for later. Claim the existing manual mode now,
	# before that deferred call can initialize any game storage or progress writers.
	var bootstrap := get_node("/root/ApplicationBootstrap")
	var result: Dictionary = bootstrap.start(&"test_manual")
	var state: Dictionary = bootstrap.get_startup_state()
	_manual_start = (result.get("ok", false) and state.get("mode") == &"test_manual"
		and state.get("completed_stages", []).is_empty())

func _ready() -> void:
	if not _manual_start:
		push_error("Manual preview must be run directly with F6; game startup already began.")
		get_tree().quit(1)
		return
	# These are transient subsystem switches, not Dialogic.Settings setters (which
	# persist global settings). Bootstrap never binds the production Bridge.
	Dialogic.Save.autosave_enabled = false
	Dialogic.History.save_visited_history_on_autosave = false
	Dialogic.History.save_visited_history_on_save = false
	get_node("/root/InputManager").ensure_default_input_map()
	var backdrop := ColorRect.new()
	backdrop.color = Color("191724")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_art = ART_VIEW.new()
	_art.name = "PreviewArt"
	add_child(_art)
	_load_entries()
	_build_toolbar()
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	call_deferred("_play", 0, true)
	if "--verify-manual-preview" in OS.get_cmdline_user_args():
		add_child(load("res://tests/manual/dialogic_preview/VerifyPreview.gd").new())

func _load_entries() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ENTRY_MANIFEST))
	for entry: Dictionary in document.entries:
		var entry_id := str(entry.entry_id)
		if entry_id.begins_with("dating.") or entry_id.begins_with("hospital.faint."):
			_entries.append(entry)

func _entry_title(entry_id: String) -> String:
	if entry_id.begins_with("hospital.faint."):
		return "Sylvia present | Hospital | Day " + entry_id.get_slice(".", 2).trim_prefix("day")
	var parts := entry_id.split(".")
	return "%s | %s | Day %s | %s" % [parts[2].replace("_", " & ").capitalize(),
		parts[1].capitalize(), parts[3].trim_prefix("day"),
		"Before" if parts[4] == "pre_challenge" else "After"]

func _build_toolbar() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 672)
	bar.size = Vector2(1248, 36)
	bar.add_theme_constant_override("separation", 14)
	overlay.add_child(bar)
	_selector = OptionButton.new()
	_selector.custom_minimum_size.x = 500
	for entry: Dictionary in _entries: _selector.add_item(_entry_title(entry.entry_id))
	_selector.item_selected.connect(_play)
	bar.add_child(_selector)
	var replay := Button.new()
	replay.text = "Replay"
	replay.pressed.connect(func(): _play(_selected))
	bar.add_child(replay)
	var size_picker := OptionButton.new()
	for value: int in [100, 125, 150]: size_picker.add_item("Text %d%%" % value, value)
	size_picker.item_selected.connect(func(index: int):
		_percent = size_picker.get_item_id(index)
		_refresh_art()
		if is_instance_valid(_caption): _caption.configure_presentation("en", _percent))
	bar.add_child(size_picker)
	_status = Label.new()
	_status.text = "PREVIEW ONLY | Click caption / Enter"
	_status.add_theme_color_override("font_color", Color("f2e3cf"))
	_status.add_theme_font_size_override("font_size", 17)
	bar.add_child(_status)

func _play(index: int, auto_pair: bool = false) -> void:
	if _switching or index < 0 or index >= _entries.size(): return
	_generation += 1
	_switching = true
	if Dialogic.current_timeline != null: await Dialogic.end_timeline(true)
	_selected = index
	_auto_pair = auto_pair
	_selector.select(index)
	_layout = Dialogic.Styles.load_style(STYLE)
	if not _layout.is_node_ready(): await _layout.ready
	# Finish the old layout teardown and new node mounting before Text visits visible nodes.
	await get_tree().process_frame
	_caption = _find_caption(_layout)
	if _caption == null:
		push_error("Manual preview could not mount the production caption.")
		get_tree().quit(1)
		return
	_caption.configure_presentation("en", _percent)
	_refresh_art()
	_status.text = "PREVIEW ONLY | Click caption / Enter"
	Dialogic.start(TIMELINE_FOLDER + str(_entries[index].entry_id) + ".dtl")
	_switching = false

func _refresh_art() -> void:
	if not is_instance_valid(_art) or _entries.is_empty(): return
	# Read the selected scene's existing art binding; never modify its manifest.
	var entry_id := str(_entries[_selected].entry_id)
	var placement := ART.get_scene_art(entry_id)
	var scene_background := ART.get_texture(str(placement.get("background", "")))
	var portrait_ids: Array = placement.get("portraits", [])
	var pair := entry_id.begins_with("dating.group.") or entry_id.begins_with("dating.twofriends.")
	var portraits: Array[Texture2D] = []
	for index: int in range(2 if pair else 1):
		var assigned := first_portrait if index == 0 else second_portrait
		var installed := ART.get_texture(str(portrait_ids[index])) if index < portrait_ids.size() else null
		portraits.append(assigned if assigned != null else (installed if installed != null else (
			FALLBACK_LEFT if index == 0 else FALLBACK_RIGHT)))
	_art.configure_textures(background if background != null else (
		scene_background if scene_background != null else FALLBACK_BACKGROUND), portraits,
		ART.get_texture(str(placement.get("cg", ""))), _percent)

func _find_caption(node: Node) -> CAPTION:
	if node is CAPTION: return node
	for child: Node in node.get_children():
		var found := _find_caption(child)
		if found != null: return found
	return null

func _on_timeline_ended() -> void:
	if _switching: return
	if _auto_pair:
		_auto_pair = false
		call_deferred("_continue_to_pair", _generation)
	else:
		_status.text = "Complete | Pick another scene / Replay"

func _continue_to_pair(generation: int) -> void:
	if not is_inside_tree() or generation != _generation: return
	for index: int in range(_entries.size()):
		if str(_entries[index].entry_id).begins_with("dating.group."):
			_play(index)
			return

func _exit_tree() -> void:
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)
