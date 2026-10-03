extends GutTest
## View-only regression with native DialogText and a controlled admission seam.
## Native Wait timing and real Bridge/Pause acceptance belong to the integration fixture.

const SCENE := preload("res://scenes/ui/witnessed/WitnessedCaptionLayer.tscn")

class HoldBridge extends RefCounted:
	var frontier := {"kind": "timed_hold", "request_id": "view-hold", "generation": 1, "event_index": 0}
	var admitted := true
	var reveal_completions := 0
	func capture_pause_frontier() -> Dictionary:
		return {"ok": admitted, "value": frontier.duplicate(true)}
	func can_skip_current_line() -> bool:
		return false
	func complete_paused_reading_reveal(_handle: Dictionary, _caption: Node) -> Dictionary:
		reveal_completions += 1
		return {"ok": false}

var runtime: DialogicGameHandler
var caption: Node
var viewport: SubViewport
var bridge: HoldBridge
var _original_runtime: Node
var _runtime_index := 0
var _original_layout: Node
var _layout_parent: Node
var _layout_index := 0
var _styles: Dictionary
var _persistent: Variant
var _had_persistent := false

func before_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_styles = DialogicStylesUtil.style_directory.duplicate(true)
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	_original_runtime = get_node("/root/Dialogic")
	_runtime_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	_layout_parent = null
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_layout_parent = _original_layout.get_parent()
		_layout_index = _original_layout.get_index()
		_layout_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	runtime = DialogicGameHandler.new()
	runtime.name = "Dialogic"
	get_tree().root.add_child(runtime)
	runtime.paused = true
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	caption = SCENE.instantiate()
	viewport.add_child(caption)
	var localization := preload("res://tests/integration/test_witnessed_caption_runtime.gd").CaptionFixtureLocale.new()
	viewport.add_child(localization)
	assert_true(caption.transport_rail.bind_localization(localization))
	assert_true(caption.configure_presentation("en", 100))
	bridge = HoldBridge.new()
	bridge.admitted = false
	caption._transport_bridge = bridge
	caption.caption_text.reveal_text("A real earlier public caption.")
	caption._on_text_started({})
	for frame: int in 3: await get_tree().process_frame

func after_each() -> void:
	if is_instance_valid(caption): caption.free()
	if is_instance_valid(viewport): viewport.free()
	if is_instance_valid(runtime):
		await runtime.clear()
		runtime.free()
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _runtime_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_layout_parent):
			_layout_parent.add_child(_original_layout)
			_layout_parent.move_child(_original_layout, _layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	DialogicStylesUtil.style_directory = _styles
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")

func _enter_hold() -> void:
	bridge.admitted = true
	runtime.current_state = DialogicGameHandler.States.WAITING
	runtime.Text.update_dialog_text("", true)
	runtime.Text.hide_textbox()
	caption._sync_timed_hold_projection()

func _source() -> Dictionary:
	return {"route_id": "hospital", "timeline_id": "view-only-fixture", "frontier": bridge.frontier.duplicate(true)}

func test_admitted_hold_withdraws_caption_and_all_command_edges_but_keeps_stationary_rail() -> void:
	var history: Array = runtime.History.simple_history_content.duplicate(true)
	var rail_rect: Rect2 = caption.transport_rail.get_rect()
	_enter_hold()
	var projection: Dictionary = caption.get_caption_projection()
	assert_true(projection.timed_hold)
	assert_false(projection.caption_visible)
	assert_false(projection.revealing)
	assert_eq(projection.leaf_rects, [])
	assert_eq(projection.visible_leaf_rects, [])
	assert_true(caption.canvas.visible)
	assert_false(caption.scroll.visible)
	assert_false(caption.overlay.visible)
	assert_false(caption.caption_text.is_visible_in_tree())
	assert_false(caption.caption_text.revealing)
	assert_eq(caption.caption_text.get_parsed_text(), "")
	assert_eq(caption.background_input.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(caption._reading_source_admitted())
	assert_null(viewport.gui_get_focus_owner())
	assert_true(caption.transport_rail.is_visible_in_tree())
	assert_eq(caption.transport_rail.get_rect(), rail_rect)
	for name: String in ["History", "Skip", "Auto", "Save", "Load", "Next"]:
		var command: BaseButton = caption.transport_rail.get_node(name)
		assert_true(command.disabled, name)
		assert_eq(command.focus_mode, Control.FOCUS_NONE, name)
	assert_eq(runtime.History.simple_history_content, history, "view projection writes no History")

func test_hold_pause_anchor_retains_empty_view_and_refuses_replacement_frontier() -> void:
	_enter_hold()
	var captured: Dictionary = caption.capture_pause_view(_source())
	assert_true(captured.get("ok", false))
	assert_eq(caption._pause_view.focus_id, 0)
	assert_true(caption.cover_pause_view(captured.value))
	assert_false(caption.canvas.visible)
	assert_false(caption.complete_pause_reading_reveal(captured.value, bridge, {}).get("ok", true))
	assert_eq(bridge.reveal_completions, 0, "hold cannot borrow the caption reveal command")
	assert_true(caption.restore_pause_view(captured.value))
	assert_true(caption.canvas.visible)
	assert_false(caption.scroll.visible)
	assert_null(viewport.gui_get_focus_owner())
	assert_true(caption.cover_pause_view(captured.value))
	bridge.frontier.generation = 2
	assert_false(caption.restore_pause_view(captured.value))
	assert_false(caption.canvas.visible, "stale resume cannot uncover a different native hold")

func test_waiting_state_and_foreign_source_do_not_create_an_admitted_hold() -> void:
	runtime.current_state = DialogicGameHandler.States.WAITING
	caption._sync_timed_hold_projection()
	assert_false(caption.get_caption_projection().timed_hold)
	bridge.admitted = true
	bridge.frontier.kind = "other_wait"
	caption._sync_timed_hold_projection()
	assert_false(caption.get_caption_projection().timed_hold)
	bridge.frontier.kind = "timed_hold"
	_enter_hold()
	var foreign := _source()
	foreign.frontier.request_id = "another-owner"
	assert_false(caption.capture_pause_view(foreign).get("ok", true))
	assert_true(caption.capture_pause_view(_source()).get("ok", false))

func test_following_real_caption_publication_restores_the_operable_caption_focus() -> void:
	_enter_hold()
	bridge.admitted = false
	caption._on_about_to_show_text({})
	assert_false(caption.get_caption_projection().timed_hold)
	assert_false(caption.get_caption_projection().caption_visible)
	assert_null(viewport.gui_get_focus_owner(), "an empty subtree cannot become the first operable state")
	assert_true(caption._speech_candidate, "hold exit precedes arming this real publication")
	caption.caption_text.reveal_text("The next real public caption.")
	caption._on_text_started({})
	assert_true(caption._speech_candidate, "native visibility restoration preserves the real speech candidate")
	assert_true(caption._speech_pending, "normal publication may schedule its one speech request")
	for frame: int in 3: await get_tree().process_frame
	assert_false(caption.get_caption_projection().timed_hold)
	assert_true(caption.scroll.visible)
	assert_true(caption.overlay.visible)
	assert_true(caption.get_caption_projection().caption_visible)
	assert_true(caption.caption_text.has_focus())
	assert_eq(caption.caption_text.focus_mode, Control.FOCUS_ALL)
	assert_eq(caption.background_input.mouse_filter, Control.MOUSE_FILTER_STOP)
