extends GutTest
## Installed Dialogic runtime, isolated from the application's original runtime and saves.
## The temporary /root/Dialogic replacement is necessary for built-in DialogText lookups.

const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const LAYER := "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd"
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
var runtime: DialogicGameHandler
var viewport: SubViewport
var layout: Node
var caption: Node
var _original_runtime: Node
var _original_layout: Node
var _original_layout_parent: Node
var _original_runtime_index := 0
var _original_layout_index := 0
var _settings := {}
var _persistent: Variant
var _had_persistent := false
var _style_directory := {}
var _ended := 0
var _finished := 0
var _emulate_mouse_from_touch := false
var _window_size := Vector2i.ZERO
var _window_content_size := Vector2i.ZERO
var _caption_display_sources: Array[Dictionary] = []

class MemoryProfile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	func get_profile_snapshot() -> Dictionary:
		return {"preferences":{"reading":{"reveal_speed":"fast","auto_delay":"short","auto_enabled":false,"skip_mode":"read_only"}}}

class CaptionFixtureLocale extends Node:
	signal locale_changed(locale: String)
	func get_locale() -> String: return "en"

class MissingStylesRuntime extends Node:
	var clear_calls := 0
	var start_calls := 0
	func get_subsystem(_subsystem: String) -> Node: return null
	func clear(_flags: int) -> void: clear_calls += 1
	func start(_path: String, _label: String = "") -> Node:
		start_calls += 1
		return null

class ClearTextFixtureEvent extends DialogicEvent:
	# Real subsystem clear and next real event run synchronously, without a render frame.
	func _execute() -> void:
		dialogic.Text.clear_game_state()
		finish()

func before_each() -> void:
	_ended = 0
	_finished = 0
	_emulate_mouse_from_touch = Input.emulate_mouse_from_touch
	_window_size = get_tree().root.size
	_window_content_size = get_tree().root.content_scale_size
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info",{})
	_style_directory = DialogicStylesUtil.style_directory.duplicate(true)
	_original_runtime = get_node("/root/Dialogic")
	_original_runtime_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_layout_parent = _original_layout.get_parent()
		_original_layout_index = _original_layout.get_index()
		_original_layout_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	_settings.clear()
	for key: String in ["dialogic/save/autosave","dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists":ProjectSettings.has_setting(key),"value":ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave",false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour",0)
	runtime = DialogicGameHandler.new()
	runtime.name = "Dialogic"
	get_tree().root.add_child(runtime)
	runtime.History.simple_history_enabled = true
	runtime.History.full_event_history_enabled = true
	runtime.History.visited_event_history_enabled = true
	runtime.History.save_visited_history_on_save = false
	runtime.History.save_visited_history_on_autosave = false
	runtime.timeline_ended.connect(func(): _ended += 1)
	runtime.Text.text_finished.connect(func(_info): _finished += 1)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.handle_input_locally = true
	add_child(viewport)
	layout = null
	caption = null

func after_each() -> void:
	Input.emulate_mouse_from_touch = _emulate_mouse_from_touch
	get_tree().root.size = _window_size
	get_tree().root.content_scale_size = _window_content_size
	# Stop incomplete native typewriters before clear() yields to timeline cleanup.
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(runtime):
		runtime.paused = false
		await runtime.clear()
		var remaining: Node = runtime.Styles.get_layout_node()
		if is_instance_valid(remaining) and not viewport.is_ancestor_of(remaining): remaining.queue_free()
	if is_instance_valid(viewport):
		viewport.queue_free()
		await get_tree().process_frame
	if is_instance_valid(runtime): runtime.free()
	_caption_display_sources.reverse()
	for source: Dictionary in _caption_display_sources:
		if is_instance_valid(source.replacement): source.replacement.free()
		get_tree().root.add_child(source.original)
		get_tree().root.move_child(source.original,source.index)
	_caption_display_sources.clear()
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime,_original_runtime_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_original_layout_parent):
			_original_layout_parent.add_child(_original_layout)
			_original_layout_parent.move_child(_original_layout,_original_layout_index)
		get_tree().set_meta("dialogic_layout_node",_original_layout)
	for key: String in _settings:
		ProjectSettings.set_setting(key,_settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info",_persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null

func _timeline(copy: String) -> DialogicTimeline:
	var timeline := DialogicTimeline.new()
	timeline.from_text(copy)
	return timeline

func _mount() -> bool:
	assert_true(ResourceLoader.exists(STYLE),"standalone style exists before production selection")
	if not ResourceLoader.exists(STYLE): return false
	layout = runtime.Styles.load_style(STYLE,viewport)
	assert_not_null(layout)
	if layout == null: return false
	for layer: Node in layout.get_layers():
		if layer.get_script().resource_path == LAYER: caption = layer
	assert_not_null(caption,"real Styles loader selected WitnessedCaptionLayer")
	return caption != null

func _settle() -> void:
	for frame in 4: await get_tree().process_frame

func _wait_for_end() -> void:
	# Real ending animations use wall time; headless process frames alone can run too fast.
	for frame in 60:
		if _ended > 0: return
		await get_tree().create_timer(0.05).timeout

func _advance() -> void:
	runtime.Inputs.input_block_timer.stop()
	runtime.Inputs.handle_input()

func _history() -> Dictionary:
	return {"simple":runtime.History.simple_history_content.duplicate(true),
		"full":runtime.History.full_event_history_content.duplicate(),
		"visited":runtime.History.visited_event_history_content.duplicate(true)}

func _assert_single_text() -> void:
	var nodes := get_tree().get_nodes_in_group("dialogic_dialog_text")
	assert_eq(nodes.size(),1,"one reveal owner in the real mounted style")
	if nodes.size() != 1: return
	assert_eq(nodes[0],caption.caption_text)
	assert_true(caption.caption_text is DialogicNode_DialogText)
	assert_eq(caption.caption_text.get_script().resource_path,"res://addons/dialogic/Modules/Text/node_dialog_text.gd","installed DialogText owns reveal")
	assert_true(get_tree().get_nodes_in_group("dialogic_name_label").is_empty(),"no separate speaker plate")
	assert_true(layout.find_children("*NameLabel*","",true,false).is_empty())

func test_deferred_first_mount_reapplies_bound_bridge_preferences_before_first_text() -> void:
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	var profile := MemoryProfile.new()
	add_child_autofree(profile)
	assert_true(bridge.bind_profile_preferences(profile).ok)
	var order: Array[String] = []
	bridge.preference_boundary_step.connect(func(_step): order.append("preferences"))
	var first_speed: Array[float] = []
	runtime.Text.text_started.connect(func(_info):
		order.append("text")
		first_speed.append(float(runtime.Settings.settings[&"text_speed"])))
	if not _mount(): return
	assert_false(layout.is_inside_tree(),"Styles mount is actually deferred")
	assert_true(caption.configure_presentation("zh-HK",150,"Midnight",true,"protan"))
	assert_eq(caption.get_caption_projection().high_contrast,true,"optional material tuple configures before deferred mount")
	assert_eq(caption.get_caption_projection().colour_preset,"protan")
	var started: Node = runtime.start(_timeline("First mounted caption."))
	assert_eq(started,layout)
	await _settle()
	_assert_single_text()
	assert_eq(order,["preferences","text"],"ready clear precedes bound Bridge reapply, which precedes first event")
	assert_eq(first_speed,[0.5])
	assert_almost_eq(float(runtime.Inputs.auto_advance.delay_modifier),0.5,0.001)
	assert_false(runtime.Inputs.auto_advance.enabled_until_user_input)
	var source_locale: String = str(get_node("/root/LocalizationManager").get_locale()).replace("_","-")
	var source_scale: Variant = get_node("/root/ProfileManager").get_preference(&"preferences.accessibility.text_size",100)
	var source_high: Variant = get_node("/root/ProfileManager").get_preference(&"preferences.accessibility.high_contrast",false)
	var source_mode: Variant = get_node("/root/ProfileManager").get_preference(&"preferences.accessibility.colour_differentiation","standard")
	var preset_map := {"standard":"standard","protan":"protan","deutan":"deutan","tritan":"tritan"}
	var valid_source: bool = source_locale in ["en","zh-CN","zh-HK"] and typeof(source_scale) == TYPE_INT and source_scale in [100,125,150] and typeof(source_high) == TYPE_BOOL and preset_map.has(source_mode)
	assert_eq(caption.get_caption_projection().locale,source_locale if valid_source else "zh-HK","valid live sources apply; uninitialized source tuple retains explicit valid configuration")
	assert_eq(caption.get_caption_projection().font_size,int(20*float(source_scale)/100) if valid_source else 30)
	assert_eq(caption.get_caption_projection().palette,"Midnight")
	assert_eq(caption.get_caption_projection().high_contrast,source_high if valid_source else true)
	assert_eq(caption.get_caption_projection().colour_preset,preset_map[source_mode] if valid_source else "protan")
	assert_eq(caption.caption_text.get_parsed_text(),"First mounted caption.")
	assert_eq(_ended,0)
	assert_false(runtime.Save.autosave_enabled)

func test_real_timeline_reveal_append_clear_and_end_keep_one_text_node() -> void:
	if not _mount(): return
	var cleared: Array[Dictionary] = []
	runtime.signal_event.connect(func(argument):
		if argument == "caption-cleared": cleared.append(caption.get_caption_projection()))
	var timeline := _timeline("First caption.[n+] Appended caption.\n[clear time=0 style=false portraits=false music=false positions=false background=false]\n[signal arg=\"caption-cleared\"]\nAfter clear.")
	timeline.process()
	var clear_event: DialogicClearEvent = timeline.events[1]
	clear_event.clear_style = false
	clear_event.clear_portrait_positions = false
	clear_event.clear_portraits = false
	clear_event.clear_music = false
	clear_event.clear_background = false
	clear_event.time = 0
	runtime.start(timeline)
	await _settle()
	_assert_single_text()
	var original: Node = caption.caption_text
	runtime.Text.skip_text_reveal()
	assert_eq(original.get_parsed_text(),"First caption.")
	assert_eq(original.visible_ratio,1.0)
	_advance()
	await _settle()
	assert_eq(caption.caption_text,original,"append reuses the built-in node")
	assert_eq(original.get_parsed_text(),"First caption. Appended caption.")
	runtime.Text.skip_text_reveal()
	_advance()
	await _settle()
	assert_eq(cleared.size(),1,"real Clear event was observed before the next text")
	if not cleared.is_empty(): assert_eq(cleared[0].text,"")
	assert_eq(original.get_parsed_text(),"After clear.")
	assert_eq(caption.caption_text,original)
	assert_eq(runtime.History.simple_history_content.size(),3,"only three actual text segments entered history")
	runtime.Text.skip_text_reveal()
	_advance()
	await _wait_for_end()
	await _settle()
	assert_eq(_ended,1)
	assert_null(runtime.current_timeline)
	assert_false(is_instance_valid(layout),"normal real runtime end frees standalone layout")

func test_presentation_matrix_preserves_live_reveal_history_and_event_position() -> void:
	if not _mount(): return
	runtime.start(_timeline("A caption is still revealing. 这段文字仍在显示。這段文字仍在顯示。".repeat(20)))
	await _settle()
	runtime.paused = true
	var node: RichTextLabel = caption.caption_text
	assert_true(node.revealing,"matrix exercises an unfinished native reveal")
	var text_before := node.text
	var visible_before := node.visible_characters
	var state_before := runtime.current_state
	var history_before := _history()
	var finished_before := _finished
	var tuple_count := 0
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for palette: String in ["AfterHours","Midnight"]:
				for high_contrast: bool in [false,true]:
					for preset: String in ["standard","protan","deutan","tritan"]:
						tuple_count += 1
						assert_true(caption.configure_presentation(locale,percent,palette,high_contrast,preset))
						await _settle()
						var projection: Dictionary = caption.get_caption_projection()
						var height: int = {100:208,125:264,150:328}[percent]
						assert_eq(projection.field_rect,Rect2(0,656-height,1280,height))
						assert_eq(projection.font_size,int(percent/5))
						assert_true(projection.field_rect.encloses(projection.caption_visible_rect))
						assert_true(projection.caption_visible_rect.has_area(),"current caption intersects the common viewport")
						assert_eq(fposmod(projection.caption_rect.size.y,2.0),0.0)
						assert_eq(projection.locale,locale)
						assert_eq(projection.palette,palette)
						assert_eq(projection.high_contrast,high_contrast)
						assert_eq(projection.colour_preset,preset)
						assert_eq(caption.caption_text,node)
						assert_eq(node.text,text_before)
						assert_eq(node.visible_characters,visible_before)
						assert_eq(runtime.current_state,state_before)
						assert_eq(runtime.current_event_idx,0)
						assert_eq(_history(),history_before)
						assert_eq(_finished,finished_before,"theme changes cannot complete a line")
						assert_eq(_ended,0,"theme changes cannot complete a timeline")
	assert_eq(tuple_count,144)
	var stable: Dictionary = caption.get_caption_projection()
	var stable_theme: Theme = caption.canvas.theme
	for tuple: Array in [["fr",100,"AfterHours",false,"standard"],["en",110,"AfterHours",false,"standard"],
			["en",100,"unknown",false,"standard"],["en",100,"AfterHours",true,"unknown"],["en",100,"AfterHours",false,"none"]]:
		assert_false(caption.configure_presentation(tuple[0],tuple[1],tuple[2],tuple[3],tuple[4]))
		assert_eq(caption.get_caption_projection(),stable,"malformed presentation request is atomic")
		assert_eq(caption.canvas.theme,stable_theme,"invalid requests cannot replace the rendered theme")
	var detached: Dictionary = caption.get_caption_projection()
	detached.text = "caller mutation"
	assert_ne(caption.get_caption_projection().text,"caller mutation")

func test_overflow_scroll_is_local_and_reconfigure_does_not_complete_text() -> void:
	if not _mount(): return
	runtime.start(_timeline("这是一段用于验证滚动的字幕。".repeat(200)))
	await _settle()
	assert_true(caption.configure_presentation("zh-CN",150,"AfterHours"))
	runtime.Text.skip_text_reveal()
	await _settle()
	var node: RichTextLabel = caption.caption_text
	var bar: VScrollBar = caption.get_scroll_bar()
	assert_false(node.scroll_active,"current native text has no independent scroll owner")
	assert_false(node.get_v_scroll_bar().visible)
	assert_true(bar.visible,"one common viewport provides overflow scrolling")
	assert_gt(float(caption.get_caption_projection().scroll_extent),0.0)
	var history_before := _history()
	var finished_before := _finished
	assert_true(node.has_focus(),"first real caption appearance receives caption focus")
	var wheel := InputEventMouseButton.new()
	wheel.position = caption.get_caption_projection().caption_visible_rect.get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	var page := InputEventKey.new()
	page.keycode = KEY_PAGEDOWN
	page.pressed = true
	var pan := InputEventPanGesture.new()
	pan.position = wheel.position
	pan.delta = Vector2(0,4)
	for event: InputEvent in [wheel,page,pan]:
		bar.value = 0
		viewport.push_input(event,true)
		await _settle()
		assert_gt(float(caption.get_caption_projection().scroll_offset),0.0,"actual "+event.get_class()+" scrolls the caption")
		assert_eq(runtime.current_event_idx,0)
		assert_eq(_history(),history_before)
		assert_eq(_finished,finished_before)
		assert_eq(_ended,0)
	runtime.start_timeline(_timeline("Short new caption."))
	await _settle()
	assert_eq(node.get_parsed_text(),"Short new caption.")
	assert_eq(float(caption.get_caption_projection().scroll_offset),0.0,"new actual text resets manual scroll")
	assert_false(bar.visible,"short text removes unnecessary scrolling")
	runtime.Text.clear_game_state()
	await _settle()
	assert_eq(caption.get_caption_projection().text,"")
	assert_false(caption.get_caption_projection().caption_visible)
	assert_eq(node.focus_mode,Control.FOCUS_NONE)
	assert_false(node.has_focus(),"empty caption leaves no invisible focus stop")

func test_actual_hospital_bridge_path_selects_caption_then_natural_end_restores_default_scope() -> void:
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	var selected: Array[String] = []
	var text_events: Array[Dictionary] = []
	runtime.Styles.style_changed.connect(func(info): selected.append(str(info.style)))
	runtime.Text.text_started.connect(func(info): text_events.append(info.duplicate()))
	var default_before: Variant = ProjectSettings.get_setting("dialogic/layout/default_style")
	var result: Dictionary = bridge.start_timeline_id("hospital.faint")
	assert_true(result.get("ok",false),str(result))
	assert_true(STYLE in selected,"actual Bridge Hospital selector loaded the owned standalone style")
	await _wait_for_end()
	await _settle()
	assert_eq(_ended,1)
	assert_false(runtime.Styles.has_active_layout_node(),"default end mode removes scoped Hospital layout")
	assert_true(get_tree().get_nodes_in_group("dialogic_input_policy").is_empty(),"ending the scoped layout removes its input policy")
	assert_true(text_events.is_empty(),"current authored Hospital timeline is comments + return; no prose acceptance claimed")
	assert_eq(ProjectSettings.get_setting("dialogic/layout/default_style"),default_before,"Hospital selection does not mutate global default")
	layout = runtime.start(_timeline("Ordinary follow-up fixture."))
	for frame in 60:
		if not text_events.is_empty(): break
		await get_tree().create_timer(0.05).timeout
	assert_true(is_instance_valid(layout))
	assert_ne(layout.get_meta("style").resource_path,STYLE,"following ordinary timeline uses the original default")
	assert_eq(text_events.size(),1)
	var default_texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
	assert_eq(default_texts.size(),1)
	if default_texts.size() != 1: return
	var default_text: DialogicNode_DialogText = default_texts[0]
	default_text.set_process(false)
	layout.layer = 129
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	var focus_owner := get_tree().root.gui_get_focus_owner()
	if focus_owner != null: focus_owner.release_focus()
	runtime.Inputs.input_block_timer.stop()
	assert_true(default_text.revealing)
	# Default input remains native: separated physical press/release demonstrates
	# fallback restoration without claiming a global fix to its existing polling.
	_parse_accept_key(true)
	await _settle()
	_parse_accept_key(false)
	await _settle()
	assert_eq(_finished,1,"ordinary native Accept works after the scoped layout has ended")
	assert_eq(runtime.current_event_idx,0)
	assert_false(default_text.revealing)

func test_hospital_missing_styles_refuses_before_clear_start_or_bridge_context() -> void:
	get_tree().root.remove_child(runtime)
	var missing := MissingStylesRuntime.new()
	missing.name = "Dialogic"
	get_tree().root.add_child(missing)
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	var before: String = bridge.get_current_timeline_id()
	var result: Dictionary = bridge.start_timeline_id("hospital.faint")
	assert_false(result.get("ok",true))
	assert_eq(result.get("reason"),"dialogic_style_unavailable")
	assert_eq(missing.clear_calls,0)
	assert_eq(missing.start_calls,0)
	assert_eq(bridge.get_current_timeline_id(),before)
	missing.free()
	get_tree().root.add_child(runtime)

func test_real_touch_drag_with_mouse_emulation_scrolls_without_finishing_native_reveal() -> void:
	if not _mount(): return
	runtime.start(_timeline("A long witnessed caption must scroll without finishing its reveal. ".repeat(100)))
	await _settle()
	assert_true(caption.configure_presentation("en",150,"AfterHours"))
	# Input.parse_input_event creates real emulated mouse events in the root viewport.
	# Freeze only the typewriter's processing; runtime input stays live so a leaked click fails.
	layout.reparent(get_tree().root)
	# GUT's own GUI is CanvasLayer128; the isolated test caption must receive input above it.
	layout.layer = 129
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	var node: RichTextLabel = caption.caption_text
	node.set_process(false)
	caption.set_process(false)
	await _settle()
	assert_true(node.revealing)
	var visible_before := node.visible_characters
	var history_before := _history()
	var finished_before := _finished
	var emulated: Array[InputEvent] = []
	node.gui_input.connect(func(event):
		if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: emulated.append(event))
	Input.emulate_mouse_from_touch = true
	runtime.Inputs.input_block_timer.stop()
	var start: Vector2 = get_tree().root.get_final_transform()*(caption.canvas.get_global_transform_with_canvas()*caption.get_caption_projection().caption_visible_rect.get_center())
	print("CAPTION_TOUCH_FIXTURE root_size=",get_tree().root.size," content_size=",get_tree().root.content_scale_size," transform=",get_tree().root.get_final_transform()," pointer=",start)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = start
	touch.pressed = true
	Input.parse_input_event(touch)
	await _settle()
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = start-Vector2(0,80)
	drag.relative = Vector2(0,-80)
	Input.parse_input_event(drag)
	await _settle()
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = drag.position
	touch.pressed = false
	Input.parse_input_event(touch)
	await _settle()
	assert_false(emulated.is_empty(),"native input generated emulated mouse contact at the actual caption")
	assert_gt(float(caption.get_caption_projection().scroll_offset),0.0)
	assert_eq(node.visible_characters,visible_before,"touch contact cannot skip the incomplete reveal")
	assert_true(node.revealing)
	assert_eq(runtime.current_event_idx,0)
	assert_eq(_history(),history_before)
	assert_eq(_finished,finished_before)
	assert_eq(_ended,0)

func _next_caption() -> void:
	if caption.caption_text.revealing: runtime.Text.skip_text_reveal()
	_advance()
	await _settle()

func _stack_invariants() -> Dictionary:
	return {"text":caption.caption_text.text,"visible":caption.caption_text.visible_characters,"revealing":caption.caption_text.revealing,
		"event":runtime.current_event_idx,"state":runtime.current_state,"history":_history(),"finished":_finished,"ended":_ended}

func _assert_passive_stack(expected: Array) -> void:
	_assert_single_text()
	assert_eq(caption.get_caption_projection().retained_captions,expected)
	var passive: Array[String] = []
	for label: Node in caption.find_children("*","RichTextLabel",true,false):
		if label == caption.caption_text or not label.visible: continue
		passive.append(label.get_parsed_text())
		assert_eq(label.focus_mode,Control.FOCUS_NONE,"retained copy is not another focus or reveal owner")
		assert_false(label.scroll_active,"retained copy has no private scrollbar")
		assert_eq(label.get_theme_font_size(&"normal_font_size"),caption.get_caption_projection().font_size,"retained copy keeps the full requested font")
	assert_eq(passive.size(),expected.size())
	for copy: String in expected: assert_true(copy in passive)
	assert_false(caption.caption_text.scroll_active)
	assert_false(caption.caption_text.get_v_scroll_bar().visible)

func test_stack_keeps_newest_three_published_captions_with_one_native_current() -> void:
	if not _mount(): return
	runtime.start(_timeline("[b]One.[/b]\nTwo.\nThree.\nFour.\n"+"The newest long caption begins in view. ".repeat(100)))
	await _settle()
	var native: Node = caption.caption_text
	_assert_passive_stack([])
	for expected: Array in [["One."],["One.","Two."],["Two.","Three."]]:
		await _next_caption()
		_assert_passive_stack(expected)
		assert_eq(caption.caption_text,native)
	assert_eq(native.get_parsed_text(),"Four.")
	assert_eq(runtime.current_event_idx,3)
	assert_eq(runtime.History.simple_history_content.size(),4)
	assert_eq(caption.get_caption_projection().leaf_rects.size(),3)
	assert_eq(caption.get_caption_projection().caption_visible_rect,caption.get_caption_projection().caption_rect,"a fitting newly published current is entirely visible")
	await _next_caption()
	_assert_passive_stack(["Three.","Four."])
	var projection: Dictionary = caption.get_caption_projection()
	assert_gt(projection.caption_rect.size.y,projection.field_rect.size.y)
	assert_eq(projection.caption_rect.position.y,projection.field_rect.position.y,"new long current is shown from its beginning")
	assert_true(caption.get_scroll_bar().visible)
	assert_gt(caption.get_scroll_bar().value,0.0,"publication scrolls past older retained leaves")
	assert_eq(_ended,0)

func test_stack_append_newline_sections_and_identical_copy_are_distinct_publications() -> void:
	if not _mount(): return
	runtime.start(_timeline("Repeat.[n+] More.[n]Repeat.[n]Repeat."))
	await _settle()
	await _next_caption()
	assert_eq(caption.caption_text.get_parsed_text(),"Repeat. More.")
	_assert_passive_stack([])
	await _next_caption()
	_assert_passive_stack(["Repeat. More."])
	assert_eq(caption.caption_text.get_parsed_text(),"Repeat.")
	await _next_caption()
	_assert_passive_stack(["Repeat. More.","Repeat."])
	assert_eq(caption.caption_text.get_parsed_text(),"Repeat.","identical text still occupies the newest separate caption")
	assert_eq(runtime.current_event_idx,0,"[n] sections remain within their real TextEvent")
	assert_eq(runtime.History.simple_history_content.size(),4)
	assert_eq(_ended,0)

func test_silent_retained_reprojection_and_remeasurement_preserve_reveal_history_and_manual_scroll() -> void:
	if not _mount(): return
	runtime.start(_timeline("Current long caption remains under its native reveal owner. ".repeat(100)))
	await _settle()
	runtime.paused = true
	assert_true(caption.caption_text.revealing)
	var before := _stack_invariants()
	assert_true(caption.reproject_retained_captions(["Earlier fixture.","Previous fixture."]))
	await _settle()
	_assert_passive_stack(["Earlier fixture.","Previous fixture."])
	assert_eq(_stack_invariants(),before,"reprojection is presentation only, not a history restore")
	var bar: VScrollBar = caption.get_scroll_bar()
	bar.value = 100
	await _settle()
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			assert_true(caption.configure_presentation(locale,percent,"AfterHours"))
			await _settle()
			assert_eq(bar.value,100.0,"remeasure preserves feasible manual scroll")
			assert_eq(_stack_invariants(),before)
			_assert_passive_stack(["Earlier fixture.","Previous fixture."])
	assert_true(caption.reproject_retained_captions(["Earlier fixture.","Previous fixture."]))
	await _settle()
	assert_eq(bar.value,100.0)
	assert_eq(_stack_invariants(),before)
	var stable: Dictionary = caption.get_caption_projection()
	for invalid: Array in [["One","Two","Three"],[""],["   "],[42],["Valid",null]]:
		assert_false(caption.reproject_retained_captions(invalid))
		assert_eq(caption.get_caption_projection(),stable,"invalid retained copy refuses atomically")
	var detached: Dictionary = caption.get_caption_projection()
	detached.retained_captions[0] = "Mutated caller copy"
	assert_eq(caption.get_caption_projection().retained_captions,["Earlier fixture.","Previous fixture."])
	caption.reset_caption_stack()
	await _settle()
	assert_eq(caption.get_caption_projection().retained_captions,[])
	assert_eq(_stack_invariants(),before,"explicit local reset does not clear the live native caption or history")

func test_runtime_pause_preserves_the_pending_native_pause_remaining_time() -> void:
	await _assert_native_pause_preserves_remaining_time(true)

func test_hidden_caption_preserves_the_pending_native_pause_remaining_time() -> void:
	await _assert_native_pause_preserves_remaining_time(false)

func _assert_native_pause_preserves_remaining_time(pause_owner: bool) -> void:
	if not _mount(): return
	await _settle()
	var effects: Array[String] = []
	var effect_times := {}
	runtime.text_signal.connect(func(argument: String):
		effects.append(argument)
		effect_times[argument] = Time.get_ticks_msec())
	runtime.start(_timeline("[signal=foreground-pause-entered][pause=0.6!][signal=foreground-pause-resumed]Done."))
	var native: DialogicNode_DialogText = caption.caption_text
	for frame in 60:
		if effects == ["foreground-pause-entered"] and not native.revealing: break
		await get_tree().create_timer(0.01).timeout
	assert_eq(effects,["foreground-pause-entered"],"the real native pause has started")
	assert_false(native.revealing)
	assert_eq(native.visible_characters,0)
	if effects != ["foreground-pause-entered"] or native.revealing: return
	# Spend a measurable foreground portion: restarting the full delay on resume
	# must fall outside the upper bound, rather than accidentally satisfying it.
	await get_tree().create_timer(0.22).timeout
	var suspended_at := Time.get_ticks_msec()
	var elapsed_before_suspend := suspended_at - int(effect_times["foreground-pause-entered"])
	assert_gte(elapsed_before_suspend,200,"the spent delay exceeds the scheduling tolerance")
	assert_lt(elapsed_before_suspend,350,"enough foreground delay remains for the post-resume check")
	assert_eq(effects,["foreground-pause-entered"])
	var remaining_expected := 600 - elapsed_before_suspend
	if pause_owner: runtime.paused = true
	else: native.hide()
	var before := _stack_invariants()
	await get_tree().create_timer(0.8).timeout
	assert_eq(effects,["foreground-pause-entered"],"suspended wall time cannot run the next native effect")
	assert_eq(native.visible_characters,0)
	assert_eq(_finished,0)
	assert_eq(_stack_invariants(),before,"suspension preserves native reveal, history, and event position")
	var resumed_at := Time.get_ticks_msec()
	if pause_owner: runtime.paused = false
	else: native.show()
	await get_tree().create_timer(0.1).timeout
	assert_eq(effects,["foreground-pause-entered"],"resuming cannot immediately spend delay accrued while suspended")
	assert_eq(native.visible_characters,0)
	assert_eq(_finished,0)
	for frame in 120:
		if _finished > 0: break
		await get_tree().create_timer(0.025).timeout
	assert_eq(effects,["foreground-pause-entered","foreground-pause-resumed"],"the pending native effect resumes exactly once")
	var completed_at := int(effect_times.get("foreground-pause-resumed",0))
	var observed_after_resume := completed_at - resumed_at
	print("Native pause timing [%s]: before=%dms remaining=%dms after-resume=%dms" % ["runtime pause" if pause_owner else "caption hide",elapsed_before_suspend,remaining_expected,observed_after_resume])
	assert_gte(observed_after_resume,remaining_expected - 120,"suspension preserves the remaining delay within frame/timer tolerance")
	assert_lte(observed_after_resume,remaining_expected + 120,"resuming preserves the remainder instead of restarting the full native delay")
	assert_eq(_finished,1,"native playback completes normally after the remaining delay")
	assert_false(native.revealing)
	assert_eq(native.visible_ratio,1.0)
	assert_eq(runtime.current_event_idx,0)
	assert_eq(_history(),before.history)

	assert_eq(_ended,0)

func test_hidden_same_frame_clear_and_replace_and_next_timeline_do_not_retain_old_caption() -> void:
	if not _mount(): return
	var timeline := _timeline("Old caption.\nSecond caption.\n[signal arg=\"fixture-placeholder\"]\nNew caption.")
	timeline.process()
	var clear_event := ClearTextFixtureEvent.new()
	clear_event.event_node_ready = true
	clear_event.event_name = "Fixture Text Clear"
	timeline.events[2] = clear_event
	runtime.start(timeline)
	await _settle()
	await _next_caption()
	_assert_passive_stack(["Old caption."])
	if caption.caption_text.revealing: runtime.Text.skip_text_reveal()
	caption.caption_text.hide()
	_advance()
	await _settle()
	assert_eq(caption.caption_text.get_parsed_text(),"New caption.")
	_assert_passive_stack([])
	assert_true(caption.reproject_retained_captions(["Presentation-only earlier caption."]))
	if caption.caption_text.revealing: runtime.Text.skip_text_reveal()
	runtime.start_timeline(_timeline("Another timeline."))
	await _settle()
	assert_eq(caption.caption_text.get_parsed_text(),"Another timeline.")
	_assert_passive_stack([])
	assert_eq(_ended,0)

func test_clear_holds_empty_without_finishing_a_hidden_incomplete_reveal() -> void:
	if not _mount(): return
	runtime.start(_timeline("This incomplete native caption is cancelled by a real text clear. ".repeat(100)))
	await _settle()
	assert_true(caption.caption_text.revealing)
	assert_true(caption.reproject_retained_captions(["Older local caption."]))
	var history_before := _history()
	var finished_before := _finished
	caption.caption_text.hide()
	runtime.Text.clear_game_state()
	await _settle()
	var projection: Dictionary = caption.get_caption_projection()
	assert_eq(projection.text,"")
	assert_eq(projection.retained_captions,[])
	assert_false(projection.caption_visible)
	assert_false(projection.revealing)
	assert_eq(_finished,finished_before,"clearing must not emit a synthetic line completion")
	assert_eq(_history(),history_before)
	assert_eq(runtime.current_event_idx,0,"the actual timeline remains valid during the clear hold")
	assert_eq(_ended,0)

func test_hiding_and_showing_incomplete_caption_pauses_without_cancelling_its_reveal() -> void:
	if not _mount(): return
	runtime.start(_timeline("The hidden caption must resume its existing native reveal. ".repeat(100)))
	await _settle()
	var node: RichTextLabel = caption.caption_text
	assert_true(node.revealing)
	assert_true(caption.reproject_retained_captions(["Earlier local caption."]))
	var visible_before := node.visible_characters
	var history_before := _history()
	var finished_before := _finished
	node.hide()
	await _settle()
	assert_true(node.revealing,"temporary hiding does not cancel the pending line")
	assert_false(node.is_processing())
	assert_eq(node.visible_characters,visible_before)
	assert_eq(_finished,finished_before)
	assert_eq(caption.get_caption_projection().retained_captions,["Earlier local caption."],"hiding is not a stack-clear boundary")
	node.show()
	await _settle()
	assert_true(node.revealing)
	assert_true(node.is_processing(),"showing resumes the same native typewriter")
	assert_gte(node.visible_characters,visible_before)
	assert_eq(_history(),history_before)
	assert_eq(_finished,finished_before)
	assert_eq(runtime.current_event_idx,0)
	assert_eq(caption.get_caption_projection().retained_captions,["Earlier local caption."])

func test_skipping_a_native_pause_cannot_resume_effects_or_reveal_on_the_replacement_line() -> void:
	if not _mount(): return
	await _settle()
	var effects: Array[String] = []
	runtime.text_signal.connect(func(argument: String): effects.append(argument))
	# Pause the replacement through the real owner before its first process tick.
	# Its index-zero effect must remain pending until that owner resumes it.
	runtime.Text.text_started.connect(func(_info: Dictionary):
		if runtime.current_event_idx == 1: runtime.paused = true)
	runtime.start(_timeline("[signal=pause-entered][pause=0.5!][signal=old-skipped-effect]Old caption.\n[signal=replacement-effect][pause=0.15!][signal=replacement-resumed]Replacement caption."))
	var native: DialogicNode_DialogText = caption.caption_text
	for frame in 60:
		if effects == ["pause-entered"] and not native.revealing: break
		await get_tree().create_timer(0.01).timeout
	assert_eq(effects,["pause-entered"],"the actual built-in signal marks entry into the native pause")
	assert_false(native.revealing,"continue_reveal is awaiting the native pause effect")
	assert_eq(native.visible_characters,0)
	assert_eq(runtime.current_event_idx,0)
	if effects != ["pause-entered"] or native.revealing: return
	# Ordinary input first skips the unfinished line, then advances to the next one.
	_advance()
	assert_eq(effects,["pause-entered","old-skipped-effect"],"ordinary skip executes the old line's remaining native signal once")
	_advance()
	for frame in 60:
		if runtime.current_event_idx == 1 and runtime.paused: break
		await get_tree().create_timer(0.01).timeout
	assert_true(runtime.paused)
	assert_eq(native.get_parsed_text(),"Replacement caption.")
	assert_eq(native.visible_characters,0)
	assert_eq(_finished,1,"only the explicitly skipped original line completed")
	var before := _stack_invariants()
	# SceneTreeTimer still runs while the Dialogic owner is paused. Let the old
	# effect return without changing its private queue or invoking reveal ourselves.
	await get_tree().create_timer(0.65).timeout
	assert_eq(effects,["pause-entered","old-skipped-effect"],"the late timer neither repeats the skipped signal nor consumes replacement effects")
	assert_eq(native.visible_characters,0,"an old reveal continuation cannot increment the replacement line")
	assert_eq(_stack_invariants(),before,"stale work cannot change replacement reveal, completion, history, or position")
	assert_eq(caption.caption_text,native)
	assert_eq(caption.get_caption_projection().retained_captions,["Old caption."])
	runtime.paused = false
	for frame in 60:
		if "replacement-effect" in effects: break
		await get_tree().create_timer(0.01).timeout
	assert_eq(effects,["pause-entered","old-skipped-effect","replacement-effect"],"resuming starts the replacement's own native effect and pause")
	assert_false(native.revealing,"an ordinary awaited pause still suspends native character reveal")
	assert_eq(native.visible_characters,0)
	for frame in 120:
		if _finished >= 2: break
		await get_tree().create_timer(0.025).timeout
	assert_eq(effects,["pause-entered","old-skipped-effect","replacement-effect","replacement-resumed"],"each replacement effect executes once through its surviving native await")
	assert_eq(_finished,2,"the replacement finishes naturally after its own pause")
	assert_false(native.revealing)
	assert_eq(native.visible_ratio,1.0)
	assert_eq(runtime.current_event_idx,1)
	assert_eq(_history(),before.history)
	assert_eq(_ended,0)

func test_real_text_clear_and_immediate_replacement_invalidate_an_awaiting_native_pause() -> void:
	if not _mount(): return
	await _settle()
	var effects: Array[String] = []
	runtime.text_signal.connect(func(argument: String): effects.append(argument))
	runtime.Text.text_started.connect(func(info: Dictionary):
		if info.text == "After clear.": runtime.paused = true)
	runtime.start(_timeline("[signal=clear-pause-entered][pause=0.5!]Before clear."))
	var native: DialogicNode_DialogText = caption.caption_text
	for frame in 60:
		if effects == ["clear-pause-entered"] and not native.revealing: break
		await get_tree().create_timer(0.01).timeout
	assert_eq(effects,["clear-pause-entered"])
	assert_false(native.revealing)
	assert_eq(native.visible_characters,0)
	if effects != ["clear-pause-entered"] or native.revealing: return
	# Unlike skip, clearing must cancel without emitting a text completion. Replace
	# in the same frame so an empty-only visible-character sentinel cannot suffice.
	runtime.Text.clear_game_state()
	assert_eq(native.get_parsed_text(),"")
	assert_eq(_finished,0)
	runtime.start_timeline(_timeline("[signal=clear-replacement-effect]After clear."))
	for frame in 60:
		if runtime.paused: break
		await get_tree().create_timer(0.01).timeout
	assert_true(runtime.paused)
	assert_eq(native.get_parsed_text(),"After clear.")
	assert_eq(native.visible_characters,0)
	var before := _stack_invariants()
	await get_tree().create_timer(0.65).timeout
	assert_eq(effects,["clear-pause-entered"],"cleared work cannot consume the replacement's native effect")
	assert_eq(native.visible_characters,0)
	assert_eq(_finished,0,"clear and its late timer never complete a line")
	assert_eq(_stack_invariants(),before)
	assert_eq(caption.caption_text,native)
	assert_eq(caption.get_caption_projection().retained_captions,[])

func _mount_root_accept_fixture(copy: String) -> bool:
	if not _mount(): return false
	await _settle()
	layout.reparent(get_tree().root)
	layout.layer = 129 # Above GUT's own CanvasLayer128, as in the real touch fixture.
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	# Keep real runtime input live while making every published typewriter stationary.
	runtime.Text.text_started.connect(func(_info: Dictionary):
		caption.caption_text.set_process(false)
		caption.set_process(false))
	# Keep the real timeline valid even when a RED run exposes several extra accepts.
	runtime.start(_timeline(copy + "\nFixture guard caption.".repeat(16)))
	await _settle()
	caption.caption_text.grab_focus()
	runtime.Inputs.input_block_timer.stop()
	assert_false(runtime.paused)
	assert_true(caption.caption_text.revealing)
	return true

func _root_caption_point(point: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * (caption.canvas.get_global_transform_with_canvas() * point)

func _parse_accept_mouse(point: Vector2, pressed: bool, double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.double_click = double_click
	Input.parse_input_event(event)

func _parse_accept_key(pressed: bool, echo: bool = false, code: Key = KEY_ENTER) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func _parse_caption_touch(point: Vector2, pressed: bool, canceled: bool = false, double_tap: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	event.double_tap = double_tap
	Input.parse_input_event(event)

func test_actual_pointer_accept_belongs_only_to_current_caption_and_one_press() -> void:
	if not await _mount_root_accept_fixture("Current.\nFollowing."): return
	assert_true(caption.reproject_retained_captions(["Older.","Previous."]))
	await _settle()
	var projection: Dictionary = caption.get_caption_projection()
	assert_eq(projection.visible_leaf_rects.size(),3)
	var before := _stack_invariants()
	for point: Vector2 in [Vector2(640,200),projection.leaf_rects[0].get_center(),projection.leaf_rects[1].get_center()]:
		_parse_accept_mouse(_root_caption_point(point),true)
		_parse_accept_mouse(_root_caption_point(point),false)
		await _settle()
		assert_eq(_stack_invariants(),before,"aperture and retained captions cannot issue narrative Accept")
	var current := _root_caption_point(projection.caption_visible_rect.get_center())
	_parse_accept_mouse(current,true)
	Input.flush_buffered_events()
	assert_eq(_finished,0,"pointer-down waits for release inside the current caption")
	var jitter := InputEventMouseMotion.new()
	jitter.position = current + Vector2(3,2)
	jitter.global_position = jitter.position
	jitter.relative = Vector2(3,2)
	jitter.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(jitter)
	_parse_accept_mouse(jitter.position,false)
	await _settle()
	assert_eq(_finished,1,"a physical click with small inside jitter finishes the current reveal once")
	assert_eq(runtime.current_event_idx,0,"the same click and release cannot also advance")
	_parse_accept_mouse(current,true,true)
	_parse_accept_mouse(current,false)
	await _settle()
	assert_eq(runtime.current_event_idx,0,"the double-click second contact cannot advance")
	_parse_accept_mouse(current,true)
	_parse_accept_mouse(_root_caption_point(Vector2(640,200)),false)
	await _settle()
	assert_eq(runtime.current_event_idx,0,"release outside the current caption cancels the contact")
	_parse_accept_mouse(current,true)
	_parse_accept_mouse(current,false)
	await _settle()
	assert_eq(runtime.current_event_idx,1,"a later fresh click advances once")
	assert_eq(_finished,1)
	assert_true(caption.caption_text.revealing)
	assert_eq(caption.caption_text.get_parsed_text(),"Following.")

func test_actual_enter_and_same_frame_unrelated_packets_issue_one_accept() -> void:
	if not await _mount_root_accept_fixture("Current.\nFollowing."): return
	var accepts: Array[int] = []
	runtime.Inputs.dialogic_action.connect(func(): accepts.append(runtime.current_event_idx))
	_parse_accept_key(true)
	_parse_accept_key(true,false,KEY_A)
	_parse_accept_key(false,false,KEY_A)
	_parse_accept_key(false)
	await _settle()
	assert_eq(accepts.size(),1,"unrelated key packets and Enter release cannot reuse global just-pressed state")
	assert_eq(_finished,1)
	assert_eq(runtime.current_event_idx,0)
	_parse_accept_key(true)
	_parse_accept_key(false)
	await _settle()
	assert_eq(accepts.size(),2,"release followed by a later fresh press re-arms Accept")
	assert_eq(runtime.current_event_idx,1)
	assert_eq(_finished,1)
	assert_true(caption.caption_text.revealing)

func test_actual_accept_waits_for_all_held_contacts_to_release() -> void:
	if not await _mount_root_accept_fixture("Current.\nFollowing."): return
	var accepts: Array[int] = []
	runtime.Inputs.dialogic_action.connect(func(): accepts.append(runtime.current_event_idx))
	var current := _root_caption_point(caption.get_caption_projection().caption_visible_rect.get_center())
	_parse_accept_key(true)
	await _settle()
	_parse_accept_key(true,true)
	_parse_accept_key(true)
	_parse_accept_mouse(current,true)
	await _settle()
	assert_eq(accepts.size(),1,"echo, repeated held press, and simultaneous mouse contact cannot issue a second Accept")
	assert_eq(_finished,1)
	assert_eq(runtime.current_event_idx,0)
	_parse_accept_key(false)
	await _settle()
	_parse_accept_key(true)
	_parse_accept_key(false)
	_parse_accept_mouse(current,false)
	await _settle()
	assert_eq(accepts.size(),1,"releasing only one device does not re-arm while another contact remains held")
	_parse_accept_key(true)
	_parse_accept_key(false)
	await _settle()
	assert_eq(accepts.size(),2)
	assert_eq(runtime.current_event_idx,1)
	assert_eq(_finished,1)
	assert_true(caption.caption_text.revealing)

func test_actual_current_short_tap_accepts_but_drag_only_scrolls() -> void:
	if not await _mount_root_accept_fixture("A long current caption supports both touch reading and a deliberate short tap. ".repeat(100)+"\nFollowing."): return
	Input.emulate_mouse_from_touch = true
	var accepts: Array[int] = []
	runtime.Inputs.dialogic_action.connect(func(): accepts.append(runtime.current_event_idx))
	var current := _root_caption_point(caption.get_caption_projection().caption_visible_rect.get_center())
	_parse_caption_touch(current,true)
	_parse_caption_touch(current,false,true)
	await _settle()
	assert_eq(accepts.size(),0,"a canceled touch cannot accept")
	_parse_caption_touch(current,true)
	await _settle()
	assert_eq(accepts.size(),0,"touch-down alone waits for tap-versus-drag resolution")
	_parse_caption_touch(current,false)
	await _settle()
	assert_eq(accepts.size(),1,"a short current-caption tap, including native mouse emulation, accepts once")
	assert_eq(_finished,1)
	assert_eq(runtime.current_event_idx,0)
	_parse_caption_touch(current,true,false,true)
	_parse_caption_touch(current,false)
	await _settle()
	assert_eq(accepts.size(),1,"the double-tap second contact cannot advance")
	var scroll_before: float = caption.get_scroll_bar().value
	_parse_caption_touch(current,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = current - Vector2(0,64)
	drag.relative = Vector2(0,-64)
	Input.parse_input_event(drag)
	_parse_caption_touch(drag.position,false)
	await _settle()
	assert_gt(caption.get_scroll_bar().value,scroll_before)
	assert_eq(accepts.size(),1,"drag release and its emulated mouse events cannot advance a completed caption")
	assert_eq(runtime.current_event_idx,0)
	current = _root_caption_point(caption.get_caption_projection().caption_visible_rect.get_center())
	_parse_caption_touch(current,true)
	_parse_caption_touch(current,false)
	await _settle()
	assert_eq(accepts.size(),2,"a fresh short tap after the drag advances once")
	assert_eq(runtime.current_event_idx,1)
	assert_eq(_finished,1)
	assert_true(caption.caption_text.revealing)
	current = _root_caption_point(caption.get_caption_projection().caption_visible_rect.get_center())
	_parse_caption_touch(current,true)
	Input.flush_buffered_events()
	runtime.start_timeline(_timeline("Replacement.\nGuard."))
	await _settle()
	var replacement := _stack_invariants()
	_parse_caption_touch(current,false)
	await _settle()
	assert_eq(accepts.size(),2,"a contact begun on the previous caption cannot accept its replacement")
	assert_eq(_stack_invariants(),replacement)
	assert_eq(caption.caption_text.get_parsed_text(),"Replacement.")

func _parse_accept_joypad(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	Input.parse_input_event(event)

func test_actual_joypad_accept_refuses_paused_or_held_contact_then_rearms() -> void:
	if not await _mount_root_accept_fixture("Current.\nFollowing."): return
	var accepts: Array[int] = []
	runtime.Inputs.dialogic_action.connect(func(): accepts.append(runtime.current_event_idx))
	runtime.paused = true
	_parse_accept_joypad(true)
	await _settle()
	assert_eq(accepts.size(),0,"a real joypad event cannot accept while its owner is paused")
	runtime.paused = false
	_parse_accept_joypad(true)
	await _settle()
	assert_eq(accepts.size(),0,"resuming with the same held contact does not accept")
	_parse_accept_joypad(false)
	await _settle()
	_parse_accept_joypad(true)
	await _settle()
	assert_eq(accepts.size(),1,"a fresh joypad A press finishes the reveal")
	assert_eq(_finished,1)
	assert_eq(runtime.current_event_idx,0)
	_parse_accept_joypad(true)
	await _settle()
	assert_eq(accepts.size(),1,"a repeated held joypad packet does not advance")
	_parse_accept_joypad(false)
	await _settle()
	_parse_accept_joypad(true)
	_parse_accept_joypad(false)
	await _settle()
	assert_eq(accepts.size(),2)
	assert_eq(runtime.current_event_idx,1)
	assert_eq(_finished,1)
	assert_true(caption.caption_text.revealing)

func test_actual_focused_gui_button_gets_first_refusal_before_caption_accept() -> void:
	if not await _mount_root_accept_fixture("Current.\nFollowing."): return
	var button := Button.new()
	button.text = "Fixture GUI action"
	button.position = Vector2(64,128)
	button.size = Vector2(240,64)
	caption.canvas.add_child(button)
	var presses: Array[bool] = []
	button.pressed.connect(func(): presses.append(true))
	button.grab_focus()
	await _settle()
	assert_true(button.has_focus())
	var before := _stack_invariants()
	_parse_accept_key(true)
	_parse_accept_key(false)
	await _settle()
	assert_eq(presses.size(),1,"the real focused native button receives its normal Enter activation")
	assert_eq(_stack_invariants(),before,"a GUI-consumed Accept never reaches the narrative owner")
	caption.caption_text.grab_focus()
	_parse_accept_key(true)
	_parse_accept_key(false)
	await _settle()
	assert_eq(presses.size(),1)
	assert_eq(_finished,1,"fresh Accept works after returning focus to the caption")
	assert_eq(runtime.current_event_idx,0)

func test_actual_accept_held_before_policy_mount_and_simulated_focus_return_requires_release() -> void:
	# The real key event predates policy mounting. With no active timeline, pause
	# the isolated owner and remove GUT GUI focus while establishing that contact.
	var focus_owner := get_tree().root.gui_get_focus_owner()
	if focus_owner != null: focus_owner.release_focus()
	runtime.paused = true
	_parse_accept_key(true)
	# parse_input_event can queue under accumulated/agile input. Deliver the actual
	# packet before mounting, so bind() observes a held action rather than a queue.
	Input.flush_buffered_events()
	runtime.paused = false
	assert_true(Input.is_action_pressed("dialogic_default_action"))
	if not await _mount_root_accept_fixture("Current.\nFollowing."):
		_parse_accept_key(false)
		return
	assert_true(Input.is_action_pressed("dialogic_default_action"),"the pre-mount physical packet remains held after policy binding")
	_parse_accept_key(true,true)
	_parse_accept_key(true)
	await _settle()
	assert_eq(_finished,0,"a contact already held when the policy mounts cannot accept")
	assert_eq(runtime.current_event_idx,0)
	_parse_accept_key(false)
	await _settle()
	_parse_accept_key(true)
	await _settle()
	assert_eq(_finished,1,"release and a fresh press activate the mounted policy")
	var policies := get_tree().get_nodes_in_group("dialogic_input_policy")
	assert_eq(policies.size(),1)
	if policies.size() != 1:
		_parse_accept_key(false)
		return
	# Engine notifications simulate the focus lifecycle; this is not an OS-window
	# focus acceptance claim. The held/repeat/release packets remain real Input events.
	policies[0].notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	policies[0].notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_parse_accept_key(true,true)
	_parse_accept_key(true)
	await _settle()
	assert_eq(_finished,1)
	assert_eq(runtime.current_event_idx,0,"focus return cannot turn the held contact into a fresh Accept")
	_parse_accept_key(false)
	await _settle()
	_parse_accept_key(true)
	_parse_accept_key(false)
	await _settle()
	assert_eq(runtime.current_event_idx,1,"a genuinely fresh post-focus contact advances once")
	assert_eq(_finished,1)
	assert_true(caption.caption_text.revealing)

func _parse_caption_shoulder(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func test_actual_controller_shoulders_page_shared_caption_without_narrative_changes() -> void:
	# Shoulder bindings are this implementation's choice for controller paging.
	if not await _mount_root_accept_fixture("The long current caption remains a single native reveal while reading. ".repeat(100)): return
	var bar: VScrollBar = caption.get_scroll_bar()
	assert_true(bar.visible)
	bar.value = 0
	var before := _stack_invariants()
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	await _settle()
	assert_eq(bar.value,bar.page,"right shoulder moves one shared viewport page")
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	await _settle()
	assert_eq(bar.value,bar.page,"repeated held shoulder packets cannot page again")
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,false)
	await _settle()
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,false)
	await _settle()
	assert_eq(bar.value,bar.page * 2,"a released and freshly pressed shoulder re-arms paging")
	_parse_caption_shoulder(JOY_BUTTON_LEFT_SHOULDER,true)
	_parse_caption_shoulder(JOY_BUTTON_LEFT_SHOULDER,false)
	await _settle()
	assert_eq(bar.value,bar.page,"left shoulder moves one page back")
	var limit := bar.max_value - bar.page
	bar.value = limit - 5
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,false)
	await _settle()
	assert_eq(bar.value,limit,"paging clamps at the end of the shared document")
	bar.value = 5
	_parse_caption_shoulder(JOY_BUTTON_LEFT_SHOULDER,true)
	_parse_caption_shoulder(JOY_BUTTON_LEFT_SHOULDER,false)
	await _settle()
	assert_eq(bar.value,0.0,"paging clamps at the start")
	assert_eq(_stack_invariants(),before,"controller reading changes no reveal, completion, history, or event state")
	bar.value = 80
	runtime.paused = true
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	await _settle()
	assert_eq(bar.value,80.0,"a shoulder pressed while paused cannot page")
	runtime.paused = false
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	await _settle()
	assert_eq(bar.value,80.0,"resuming does not reinterpret the held shoulder as a fresh page request")
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,false)
	await _settle()
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,false)
	await _settle()
	assert_eq(bar.value,80.0 + bar.page,"release and a fresh post-resume shoulder press re-arm paging")
	assert_eq(_stack_invariants(),before)
	var button := Button.new()
	button.position = Vector2(32,128)
	button.size = Vector2(200,64)
	caption.canvas.add_child(button)
	button.grab_focus()
	bar.value = 80
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,false)
	await _settle()
	assert_eq(bar.value,80.0,"another focused GUI control owns input before caption paging")
	assert_eq(_stack_invariants(),before)
	caption.caption_text.grab_focus()
	caption.caption_text.hide()
	await _settle()
	var hidden_value := bar.value
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,false)
	await _settle()
	assert_eq(bar.value,hidden_value,"hidden captions do not page")
	assert_eq(_stack_invariants(),before)
	caption.caption_text.show()
	caption.caption_text.set_process(false)
	runtime.start_timeline(_timeline("Short caption."))
	await _settle()
	assert_false(bar.visible)
	before = _stack_invariants()
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
	_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,false)
	await _settle()
	assert_eq(bar.value,0.0,"a fitting caption has no controller scroll")
	assert_eq(_stack_invariants(),before)

func test_actual_scroll_gestures_cancel_armed_pointer_accept_before_inside_release() -> void:
	var long_copy := "A long current caption remains under the pointer throughout shared scrolling. ".repeat(100)
	if not await _mount_root_accept_fixture(long_copy): return
	for mode: String in ["wheel","pan","page","shoulder"]:
		if mode != "wheel":
			runtime.start_timeline(_timeline(long_copy + "\nGuard."))
			await _settle()
		caption.caption_text.grab_focus()
		var bar: VScrollBar = caption.get_scroll_bar()
		bar.value = 0
		await _settle()
		# Every TextEvent starts its own skip-delay timer, including later loop
		# fixtures. Keep Accept live so that a leaked release cannot pass silently.
		runtime.Inputs.input_block_timer.stop()
		assert_false(runtime.Inputs.is_input_blocked(),mode + " fixture permits native Accept")
		assert_true(caption.caption_text.revealing,mode + " fixture starts with an unfinished reveal")
		var before := _stack_invariants()
		var logical: Vector2 = caption.get_caption_projection().caption_visible_rect.get_center()
		var point := _root_caption_point(logical)
		_parse_accept_mouse(point,true)
		Input.flush_buffered_events()
		assert_eq(_stack_invariants(),before,"mouse-down only arms a candidate before " + mode)
		match mode:
			"wheel":
				for pressed: bool in [true,false]:
					var wheel := InputEventMouseButton.new()
					wheel.position = point
					wheel.global_position = point
					wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
					wheel.button_mask = MOUSE_BUTTON_MASK_LEFT
					wheel.pressed = pressed
					Input.parse_input_event(wheel)
			"pan":
				var pan := InputEventPanGesture.new()
				pan.position = point
				pan.delta = Vector2(0,3)
				Input.parse_input_event(pan)
			"page":
				_parse_accept_key(true,false,KEY_PAGEDOWN)
				_parse_accept_key(false,false,KEY_PAGEDOWN)
			"shoulder":
				_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,true)
				_parse_caption_shoulder(JOY_BUTTON_RIGHT_SHOULDER,false)
		await _settle()
		assert_gt(bar.value,0.0,mode + " performs actual shared scrolling while the pointer is held")
		assert_true(caption.get_caption_projection().caption_visible_rect.has_point(logical),"release remains inside the same current leaf after " + mode)
		_parse_accept_mouse(point,false)
		await _settle()
		assert_eq(_stack_invariants(),before,mode + " cancels pointer Accept instead of finishing or advancing on release")
		_parse_accept_mouse(point,true)
		_parse_accept_mouse(point,false)
		await _settle()
		assert_eq(_finished,int(before.finished) + 1,mode + " permits a later fresh non-scrolling click to finish once")
		assert_eq(runtime.current_event_idx,before.event)
		assert_eq(_history(),before.history)

func _replace_caption_display_source(source_name: String, replacement: Node) -> void:
	var original := get_tree().root.get_node(source_name)
	_caption_display_sources.append({"original":original,"index":original.get_index(),"replacement":replacement})
	get_tree().root.remove_child(original)
	replacement.name = source_name
	get_tree().root.add_child(replacement)

func test_real_profile_large_targets_resize_current_caption_without_accepting_held_click() -> void:
	var profile: Node = preload("res://autoload/ProfileManager.gd").new()
	var storage: RefCounted = preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"caption-target-fixture",preload("res://tests/support/FakeFileOps.gd").new())
	assert_true(profile.initialize(storage).get("ok",false))
	_replace_caption_display_source("ProfileManager",profile)
	_replace_caption_display_source("LocalizationManager",CaptionFixtureLocale.new())
	if not await _mount_root_accept_fixture("Short caption."): return
	var before := _stack_invariants()
	var native: Node = caption.caption_text
	var ordinary_rect: Rect2 = caption.get_caption_projection().caption_rect
	assert_gte(ordinary_rect.size.y,48.0)
	var point := _root_caption_point(ordinary_rect.get_center())
	_parse_accept_mouse(point,true)
	Input.flush_buffered_events()
	assert_true(profile.set_preferences({&"preferences.accessibility.large_targets":true}).get("ok",false))
	await _settle()
	var projection: Dictionary = caption.get_caption_projection()
	assert_true(projection.get("large_targets",false))
	assert_gte(projection.caption_visible_rect.size.y,64.0,"a short live caption is a full Large Target")
	assert_gte(projection.caption_visible_rect.size.x,64.0)
	assert_false(profile.set_preferences({&"preferences.accessibility.large_targets":"true"}).get("ok",false))
	await _settle()
	assert_eq(caption.get_caption_projection(),projection,"malformed preference is refused without changing the live target")
	assert_eq(_stack_invariants(),before)
	assert_eq(caption.caption_text,native)
	assert_true(native.has_focus())
	_parse_accept_mouse(point,false)
	await _settle()
	assert_eq(_stack_invariants(),before,"resizing cancels the old pointer candidate even if release stays inside")
	assert_true(profile.set_preferences({&"preferences.accessibility.large_targets":false}).get("ok",false))
	await _settle()
	assert_eq(caption.get_caption_projection().caption_rect,ordinary_rect,"turning off Large Targets restores ordinary geometry")
	assert_eq(_stack_invariants(),before)
	_parse_accept_mouse(point,true)
	_parse_accept_mouse(point,false)
	await _settle()
	assert_eq(_finished,int(before.finished)+1,"a fresh click still finishes exactly once")
	assert_eq(runtime.current_event_idx,before.event)
	assert_eq(_history(),before.history)

func test_large_target_overflow_scrollbar_keeps_reading_position_and_minimum_hit_geometry() -> void:
	var profile: Node = preload("res://autoload/ProfileManager.gd").new()
	var storage: RefCounted = preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"caption-overflow-target-fixture",preload("res://tests/support/FakeFileOps.gd").new())
	assert_true(profile.initialize(storage).get("ok",false))
	assert_true(profile.set_preferences({&"preferences.accessibility.large_targets":true}).get("ok",false))
	_replace_caption_display_source("ProfileManager",profile)
	_replace_caption_display_source("LocalizationManager",CaptionFixtureLocale.new())
	if not _mount(): return
	runtime.start(_timeline("Overflow keeps its real native reveal and scroll owner. ".repeat(100)))
	await _settle()
	runtime.paused = true
	var before := _stack_invariants()
	var bar: VScrollBar = caption.get_scroll_bar()
	assert_true(caption.get_caption_projection().get("large_targets",false),"the saved setting applies during initial mount")
	assert_gte(bar.size.x,64.0)
	bar.value = 100
	for enabled: bool in [true,false,true]:
		assert_true(profile.set_preferences({&"preferences.accessibility.large_targets":enabled}).get("ok",false))
		for locale: String in ["en","zh-CN","zh-HK"]:
			for percent: int in [100,125,150]:
				assert_true(caption.configure_presentation(locale,percent,"AfterHours",false,"standard",enabled))
				await _settle()
				var minimum := 64.0 if enabled else 48.0
				assert_true(bar.visible)
				assert_gte(bar.size.x,minimum,"the actual native scrollbar is wide enough to operate")
				assert_gte(bar.get_theme_stylebox(&"grabber").get_minimum_size().y,minimum,"short thumbs retain the required hit height")
				assert_eq(bar.value,100.0,"target and font changes preserve feasible manual scroll")
				assert_eq(caption.get_caption_projection().get("large_targets",false),enabled)
				assert_eq(_stack_invariants(),before)

func test_native_scrollbar_wide_hit_area_pages_and_drags_without_accepting_caption() -> void:
	if not await _mount_root_accept_fixture("Real scrollbar pointer target fixture. ".repeat(100)): return
	for enabled: bool in [false,true]:
		assert_true(caption.configure_presentation("en",100,"AfterHours",false,"standard",enabled))
		await _settle()
		var bar: VScrollBar = caption.get_scroll_bar()
		bar.value = 0
		await _settle()
		var before := _stack_invariants()
		var rect := bar.get_global_rect()
		# The left edge belongs to the native control but lies outside the narrow ink.
		var point := _root_caption_point(rect.position + Vector2(2,rect.size.y - 24))
		_parse_accept_mouse(point,true)
		_parse_accept_mouse(point,false)
		await _settle()
		assert_gt(bar.value,0.0,"the expanded native track edge performs page scrolling")
		assert_eq(_stack_invariants(),before)
		bar.value = 0
		await _settle()
		point = _root_caption_point(rect.position + Vector2(2,24))
		_parse_accept_mouse(point,true)
		Input.flush_buffered_events()
		var drag := InputEventMouseMotion.new()
		drag.position = point + Vector2(0,50)
		drag.global_position = drag.position
		drag.relative = Vector2(0,50)
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(drag)
		_parse_accept_mouse(drag.position,false)
		await _settle()
		assert_gt(bar.value,0.0,"the expanded short-thumb edge remains draggable")
		assert_eq(_stack_invariants(),before)

func test_real_profile_material_preferences_preserve_native_reading_and_pending_click() -> void:
	var profile: Node = preload("res://autoload/ProfileManager.gd").new()
	var storage: RefCounted = preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"caption-profile-fixture",preload("res://tests/support/FakeFileOps.gd").new())
	var initialized: Dictionary = profile.initialize(storage)
	assert_true(initialized.get("ok",false),str(initialized))
	_replace_caption_display_source("ProfileManager",profile)
	_replace_caption_display_source("LocalizationManager",CaptionFixtureLocale.new())
	if not await _mount_root_accept_fixture("Live material preferences preserve this native caption and its reading position. ".repeat(100)): return
	assert_true(caption.configure_presentation("en",100,"AfterHours"))
	assert_true(caption.reproject_retained_captions(["Older fixture.","Previous fixture."]))
	await _settle()
	var native: DialogicNode_DialogText = caption.caption_text
	var bar: VScrollBar = caption.get_scroll_bar()
	bar.value = 100
	native.grab_focus()
	var baseline: Dictionary = {}
	for role: StringName in [&"field",&"deep",&"current",&"text",&"rule",&"focus_outer",&"focus_inner"]:
		baseline[role] = caption.canvas.theme.get_color(role,&"WitnessedCaption")
	var before := _stack_invariants()
	var point := _root_caption_point(caption.get_caption_projection().caption_visible_rect.get_center())
	_parse_accept_mouse(point,true)
	Input.flush_buffered_events()
	# Literal role subset from SettingsPaletteRegistry at26de279be5f6490ff453db359b1964ec10596962.
	# No runtime dependency on the separate Settings worktree or its registry.
	var high_roles := {&"field":Color("0b1018"),&"deep":Color("080b10"),&"current":Color("24212d"),
		&"text":Color("f6efdc"),&"rule":Color("98a7ae"),&"focus_outer":Color("f6efdc")}
	for tuple: Array in [["standard","standard","d0b977"],["protan","protan","e0c187"],
			["deutan","deutan","d9c585"],["tritan","tritan","e3b6ac"]]:
		var changed: Dictionary = profile.set_preferences({&"preferences.accessibility.high_contrast":true,
			&"preferences.accessibility.colour_differentiation":tuple[0]})
		assert_true(changed.get("ok",false),str(changed))
		await _settle()
		var projection: Dictionary = caption.get_caption_projection()
		assert_eq(projection.get("high_contrast",false),true)
		assert_eq(projection.get("colour_preset","standard"),tuple[1])
		assert_eq(projection.palette,"AfterHours")
		for role: StringName in high_roles:
			assert_eq(caption.canvas.theme.get_color(role,&"WitnessedCaption"),high_roles[role],str(role))
		assert_eq(caption.canvas.theme.get_color(&"focus_inner",&"WitnessedCaption"),Color(tuple[2]))
		assert_eq(native.get_theme_color(&"default_color"),Color("f6efdc"),"the actual native text receives the published ink")
		assert_eq(_stack_invariants(),before)
		assert_eq(bar.value,100.0)
		assert_true(native.has_focus())
		assert_eq(caption.caption_text,native)
	var reset: Dictionary = profile.set_preferences({&"preferences.accessibility.high_contrast":false,
		&"preferences.accessibility.colour_differentiation":"standard"})
	assert_true(reset.get("ok",false))
	await _settle()
	for role: StringName in baseline:
		assert_eq(caption.canvas.theme.get_color(role,&"WitnessedCaption"),baseline[role],"Standard material parity: " + str(role))
	assert_eq(_stack_invariants(),before)
	assert_eq(bar.value,100.0)
	assert_true(native.has_focus())
	_parse_accept_mouse(point,false)
	await _settle()
	assert_eq(_finished,int(before.finished) + 1,"material publication preserves the armed click, which still finishes once on release")
	assert_eq(runtime.current_event_idx,before.event)
	assert_eq(_history(),before.history)

func test_real_profile_target_resize_cancels_held_native_thumb_drag_until_fresh_contact() -> void:
	var profile: Node = preload("res://autoload/ProfileManager.gd").new()
	var storage: RefCounted = preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"caption-held-thumb-fixture",preload("res://tests/support/FakeFileOps.gd").new())
	assert_true(profile.initialize(storage).get("ok",false))
	_replace_caption_display_source("ProfileManager",profile)
	_replace_caption_display_source("LocalizationManager",CaptionFixtureLocale.new())
	if not await _mount_root_accept_fixture("A real native scrollbar keeps reading separate from narrative completion. ".repeat(100)): return
	var bar: VScrollBar = caption.get_scroll_bar()
	assert_true(bar.visible)
	bar.value = 0
	await _settle()
	var before := _stack_invariants()
	var point := _root_caption_point(bar.get_global_rect().position + Vector2(2,24))
	_parse_accept_mouse(point,true)
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.position = point + Vector2(0,12)
	motion.global_position = motion.position
	motion.relative = Vector2(0,12)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await _settle()
	assert_gt(bar.value,0.0,"real held motion proves the native thumb drag is armed before resize")
	var retained_scroll := bar.value
	assert_true(profile.set_preferences({&"preferences.accessibility.large_targets":true}).get("ok",false))
	await _settle()
	assert_true(caption.get_caption_projection().large_targets)
	assert_gte(bar.size.x,64.0)
	assert_eq(bar.value,retained_scroll,"metric publication preserves the feasible reading position")
	motion = InputEventMouseMotion.new()
	motion.position = point + Vector2(0,24)
	motion.global_position = motion.position
	motion.relative = Vector2(0,12)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await _settle()
	assert_eq(bar.value,retained_scroll,"held motion cannot continue a native thumb drag after its geometry changes")
	_parse_accept_mouse(motion.position,false)
	await _settle()
	assert_eq(_stack_invariants(),before)
	bar.value = 0
	await _settle()
	point = _root_caption_point(bar.get_global_rect().position + Vector2(2,24))
	_parse_accept_mouse(point,true)
	Input.flush_buffered_events()
	motion = InputEventMouseMotion.new()
	motion.position = point + Vector2(0,50)
	motion.global_position = motion.position
	motion.relative = Vector2(0,50)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	_parse_accept_mouse(motion.position,false)
	await _settle()
	assert_gt(bar.value,0.0,"a released and fresh native thumb drag works with the new target size")
	assert_eq(_stack_invariants(),before)
