extends GutTest
## Real Bridge/Styles selection, with optional artwork deliberately unavailable.
## Authored dating masters currently contain return stubs, so named prose uses a fixture.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const ART := preload("res://scripts/data/ArtManifest.gd")
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const LAYER := "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd"
const DATING := "dating.solo.priscilla.day1.pre_challenge"

class Completion extends RefCounted:
	var calls: Array[Dictionary] = []
	func complete_entry(intent: Dictionary) -> Dictionary:
		calls.append(intent.duplicate(true))
		return {"ok": true}

var runtime: DialogicGameHandler
var bridge: Node
var completion: Completion
var _original_runtime: Node
var _original_index := 0
var _original_layout: Node
var _original_parent: Node
var _original_layout_index := 0
var _settings := {}
var _persistent: Variant
var _had_persistent := false
var _style_directory := {}
var _art := {}
var _art_loaded := false
var _selected: Array[String] = []
var _text_events: Array[Dictionary] = []

func before_each() -> void:
	_selected.clear()
	_text_events.clear()
	_art = ART._placements.duplicate(true)
	_art_loaded = ART._placements_loaded
	ART._placements = {"schema_version": 1, "assets": {}, "scenes": {}}
	ART._placements_loaded = true
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	_style_directory = DialogicStylesUtil.style_directory.duplicate(true)
	_original_runtime = get_node("/root/Dialogic")
	_original_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_parent = _original_layout.get_parent()
		_original_layout_index = _original_layout.get_index()
		_original_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	runtime = DialogicGameHandler.new()
	runtime.name = "Dialogic"
	get_tree().root.add_child(runtime)
	runtime.Styles.style_changed.connect(func(info): _selected.append(str(info.style)))
	runtime.Text.text_started.connect(func(info): _text_events.append(info.duplicate()))
	var adapter := ADAPTER.new()
	assert_true(adapter.bind_runtime(runtime).get("ok", false))
	bridge = BRIDGE.new()
	add_child(bridge)
	assert_true(bridge.initialize(null, adapter).get("ok", false))
	completion = Completion.new()
	assert_true(bridge.configure_playback_completion_port(completion).get("ok", false))

func after_each() -> void:
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	bridge.free()
	await runtime.clear()
	var remaining: Node = runtime.Styles.get_layout_node()
	if is_instance_valid(remaining): remaining.queue_free()
	await get_tree().process_frame
	runtime.free()
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_original_parent):
			_original_parent.add_child(_original_layout)
			_original_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	_original_parent = null
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	ART._placements = _art
	ART._placements_loaded = _art_loaded

func _context() -> Dictionary:
	return {"expected_stage": "dating_pre", "playback_id": "caption-fixture",
		"role": "solo_pre_challenge", "transaction_id": "caption-fixture"}

func _settle() -> void:
	for frame in 4: await get_tree().process_frame

func _wait_for_completion(count: int) -> void:
	for frame in 60:
		if completion.calls.size() == count and not runtime.Styles.has_active_layout_node(): return
		await get_tree().create_timer(0.05).timeout
	assert_eq(completion.calls.size(), count, "authored return completed through the real runtime")

func test_artless_solo_group_and_twofriends_pre_and_post_select_nameless_style() -> void:
	var count := 0
	for route: String in ["solo.priscilla.day1", "group.priscilla_lavinia.day2", "twofriends.priscilla_lavinia.day2"]:
		for phase: String in ["pre_challenge", "post_challenge"]:
			var entry_id := "dating." + route + "." + phase
			_selected.clear()
			var started: Dictionary = bridge.start_entry(entry_id, _context())
			assert_true(started.get("ok", false), str(started))
			assert_true(STYLE in _selected, entry_id + " owns captions even without optional art")
			assert_null(bridge.get_art_hold_view(), "unavailable art cannot substitute a hold card")
			count += 1
			await _wait_for_completion(count)
			assert_eq(completion.calls[-1].entry_id, entry_id)
			assert_eq(completion.calls[-1].completion_kind, &"natural_end")
	assert_true(_text_events.is_empty(), "current authored dating stubs contain no prose")

func test_resumed_dating_entry_selects_same_style_without_optional_art() -> void:
	var context := _context()
	var checkpoint := {"entry_id": DATING, "content_version": 1, "frozen_context": context,
		"stage": context.expected_stage, "transaction_id": context.transaction_id}
	var resumed: Dictionary = bridge.resume_entry(checkpoint)
	assert_true(resumed.get("ok", false), str(resumed))
	assert_true(STYLE in _selected)
	await _wait_for_completion(1)
	assert_eq(completion.calls[0].entry_id, DATING)
	assert_eq(completion.calls[0].transaction_id, context.transaction_id)

func test_named_dialogue_in_dating_style_keeps_identity_but_has_no_speaker_plate() -> void:
	# Physical fixture prose exercises the same selector without editing an authored master.
	bridge.set("_ordinary_playback", {"timeline_id": DATING, "context": {}})
	bridge.call("_prepare_scene_art")
	assert_true(STYLE in _selected)
	var timeline := DialogicTimeline.new()
	timeline.from_text("Narrator: A dating caption fixture.")
	var layout: Node = runtime.start(timeline)
	await _settle()
	var event := runtime.current_timeline_events[0] as DialogicTextEvent
	assert_not_null(event.character, "speaker identity is retained by Dialogic")
	if event.character != null: assert_eq(event.character.display_name, "Narrator")
	assert_true(get_tree().get_nodes_in_group("dialogic_name_label").is_empty(), "dating has no speaker plate")
	assert_true(layout.find_children("*NameLabel*", "", true, false).is_empty())
	var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
	assert_eq(texts.size(), 1)
	if texts.size() == 1: assert_eq(texts[0].get_parsed_text(), "A dating caption fixture.")
	var captions := 0
	for layer: Node in layout.get_layers():
		if layer.get_script().resource_path == LAYER: captions += 1
	assert_eq(captions, 1, "the established three-caption presentation owns the text")

func test_dating_natural_end_restores_ordinary_default_style() -> void:
	var default_before: Variant = ProjectSettings.get_setting("dialogic/layout/default_style")
	assert_true(bridge.start_entry(DATING, _context()).get("ok", false))
	assert_true(STYLE in _selected)
	await _wait_for_completion(1)
	assert_eq(ProjectSettings.get_setting("dialogic/layout/default_style"), default_before)
	assert_true(get_tree().get_nodes_in_group("dialogic_input_policy").is_empty())
	var timeline := DialogicTimeline.new()
	timeline.from_text("Ordinary follow-up fixture.")
	var layout: Node = runtime.start(timeline)
	for frame in 60:
		if not _text_events.is_empty(): break
		await get_tree().create_timer(0.05).timeout
	assert_ne(layout.get_meta("style").resource_path, STYLE, "dating style has no global effect")
	assert_eq(_text_events.size(), 1)
