extends "res://addons/gut/test.gd"
## Real imported texture, original return-only DTL, real native runtime; no text witness fixture.
const ART := preload("res://scripts/data/ArtManifest.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const PAUSE := preload("res://scripts/application/lifecycle/ProductionPauseController.gd")
const HOLD := preload("res://scripts/ui/witnessed/SceneArtHoldSurface.gd")
const PATH := "res://dialogic/timelines/en/core/opening_day1.dtl"
const HANDLE := {"generation": 1, "handle_id": "art-pause", "holder": &"art_fixture", "reason": &"universal_pause"}
var _bridge: Node
var _adapter: RefCounted
var _gate: RefCounted
var _completed := 0

func before_each() -> void:
	_completed = 0
	var catalog := {"schema_version": 1,
		"assets": {"fixture.portrait": {"path": "res://icon.svg", "size": [128, 128]}},
		"scenes": {"opening.day1": {"background": "", "portraits": ["fixture.portrait"], "cg": ""}}}
	var file := FileAccess.open("user://art-hold-fixture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog))
	file.close()
	assert_true(ART.reload_placements("user://art-hold-fixture.json"))
	assert_not_null(ART.get_texture("fixture.portrait"))
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)
	_gate = GATE.new()
	assert_true(_bridge.configure_mutation_gate(_gate).ok)
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(get_node("/root/Dialogic")).ok)
	assert_true(_bridge.initialize(null, _adapter).ok)
	_bridge.timeline_finished.connect(func(_id: String, _receipt: Dictionary): _completed += 1)

func after_each() -> void:
	if is_instance_valid(_bridge):
		_bridge._close_art_hold()
		_bridge._ordinary_playback.clear()
	if _adapter != null and _adapter.has_active_playback(): _adapter.halt_with_error({"code": "fixture_cleanup"})
	ART.reload_placements()
	await get_tree().process_frame
	await get_tree().process_frame

func _begin() -> HOLD:
	var begun: Dictionary = _bridge.start_timeline_id("opening.day1", {})
	assert_true(begun.get("ok", false), str(begun))
	var view: HOLD = _bridge.get_art_hold_view()
	assert_not_null(view)
	if view == null: return null
	for frame: int in range(8):
		await get_tree().process_frame
		if view.has_drawn_art() and not view.next_button.disabled: break
	assert_true(view.has_drawn_art(), "the actual art view must draw before Continue")
	assert_false(view.next_button.disabled, "real InputManager permits neutral fresh input")
	return view

func _await_end() -> void:
	for frame: int in range(12):
		if _completed == 1: break
		await get_tree().process_frame
	assert_eq(_completed, 1)

func test_portrait_only_return_scene_waits_then_executes_original_dtl_once() -> void:
	var view := await _begin()
	if view == null: return
	assert_eq(_completed, 0)
	assert_false(_adapter.has_active_playback(), "native DTL has not executed during the art card")
	assert_eq(view.mouse_filter, Control.MOUSE_FILTER_STOP, "card blocks clicks to underlying route")
	assert_eq(view.art.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var token: String = view._token
	view.next_button.pressed.emit()
	_bridge._continue_art_hold(token)
	await _await_end()
	assert_null(_bridge.get_art_hold_view())
	assert_eq(_adapter._start_generation, 1)

func test_pause_reuses_exact_art_view_and_continue_does_not_execute_while_suspended() -> void:
	var view := await _begin()
	if view == null: return
	var frontier: Dictionary = _bridge.capture_pause_frontier().value
	var source := {"frontier": frontier}
	var controller: Node = PAUSE.new()
	add_child_autofree(controller)
	controller._services = {"bridge": _bridge}
	controller._scene = view
	controller._captured_source = source
	assert_true(controller.capture_pause_view(source).ok)
	assert_eq(controller._caption, view)
	var anchor: Dictionary = view.capture_pause_view(source).value
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	assert_true(view.cover_pause_view(anchor))
	assert_true(get_node("/root/ProfileManager").is_connected("preference_changed", view._on_preference_changed))
	view._on_preference_changed(&"preferences.accessibility.text_size", 150)
	view._on_locale_changed("zh-CN")
	assert_eq(view.art.size, Vector2(1280, 328), "paused preference changes resize only the same art view")
	assert_eq(view.next_button.get_theme_font_size("font_size"), 30)
	assert_eq(view.next_button.text, "\u7ee7\u7eed")
	_bridge._continue_art_hold(view._token)
	assert_eq(_completed, 0)
	assert_eq(_bridge.capture_pause_frontier().value, frontier)
	assert_true(view.restore_pause_view(anchor))
	assert_true(_bridge.resume(HANDLE).ok)
	await get_tree().process_frame
	await get_tree().process_frame
	view.next_button.pressed.emit()
	await _await_end()

func test_failed_load_keeps_same_art_then_successful_idle_load_retires_it_without_completion() -> void:
	var view := await _begin()
	if view == null: return
	var frontier: Dictionary = _bridge.capture_pause_frontier().value
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	assert_true(_bridge.begin_pause_restore(HANDLE).ok)
	var acquired: Dictionary = _gate.acquire(&"restore")
	assert_true(acquired.ok)
	var target := {"route_ready_token": {"token": "fixture-idle-target"}, "narrative_checkpoint": {}}
	assert_true(_bridge.stage_pause_restore(target, false).ok)
	assert_true(_bridge.rollback_restore_silent({}).ok)
	assert_true(_gate.release(&"restore", acquired.value.token).ok)
	assert_true(_bridge.cancel_pause_restore(HANDLE).ok)
	assert_eq(_bridge.get_art_hold_view(), view)
	assert_eq(_bridge.capture_pause_frontier().value, frontier)
	assert_eq(_completed, 0)
	assert_true(_bridge.begin_pause_restore(HANDLE).ok)
	acquired = _gate.acquire(&"restore")
	assert_true(_bridge.stage_pause_restore(target, false).ok)
	assert_true(_bridge.finalize_pause_restore().ok)
	var old_token: String = view._token
	var loaded: Dictionary = await _bridge.complete_pause_restore(HANDLE)
	assert_true(loaded.ok, str(loaded))
	assert_true(_gate.release(&"restore", acquired.value.token).ok)
	_bridge._continue_art_hold(old_token)
	assert_null(_bridge.get_art_hold_view())
	assert_eq(_completed, 0)
	assert_false(_bridge.has_active_playback())

func test_return_retirement_cancels_card_and_never_starts_its_dtl() -> void:
	var view := await _begin()
	if view == null: return
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	var token: String = view._token
	var acquired: Dictionary = _gate.acquire(&"session_abandonment")
	assert_true(_bridge.retire_suspended_source(HANDLE).ok)
	assert_true(_gate.release(&"session_abandonment", acquired.value.token).ok)
	_bridge._continue_art_hold(token)
	assert_null(_bridge.get_art_hold_view())
	assert_eq(_adapter._start_generation, 1, "only native cancellation, never a timeline start")
	assert_eq(_completed, 0)

func test_only_proven_empty_blocks_hold_and_no_art_preserves_native_auto_completion() -> void:
	assert_true(BRIDGE.is_return_only_entry(PATH, ""))
	assert_true(BRIDGE.is_return_only_entry("res://dialogic/timelines/en/core/tutorial_desktop_day1.dtl", ""))
	var file := FileAccess.open("user://art-only-source.dtl", FileAccess.WRITE)
	file.store_string("# Empty implicit end\n\n")
	file.close()
	assert_true(BRIDGE.is_return_only_entry("user://art-only-source.dtl", ""))
	file = FileAccess.open("user://art-only-source.dtl", FileAccess.WRITE)
	file.store_string("label fixture\nVisible text\nreturn\n")
	file.close()
	assert_false(BRIDGE.is_return_only_entry("user://art-only-source.dtl", "fixture"))
	assert_false(BRIDGE.is_return_only_entry("user://art-only-source.dtl", "missing"))
	ART.reload_placements()
	# Shipped optional art is absent in the isolated test fixture. Bind an explicitly empty map.
	file = FileAccess.open("user://art-hold-fixture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "assets": {}, "scenes": {}}))
	file.close()
	ART.reload_placements("user://art-hold-fixture.json")
	assert_true(_bridge.start_timeline_id("opening.day1", {}).ok)
	assert_null(_bridge.get_art_hold_view())
	await _await_end()

func test_witnessed_hospital_start_runs_its_dtl_instead_of_holding_on_its_art() -> void:
	# The shipped Hospital timeline is a return-only stub exactly like opening.day1, so with its
	# optional artwork present the art card would otherwise stand in for the start. Its one caller
	# is DialogicPresentationOwnerAdapter.begin_physical, whose completion proof is the runtime own
	# natural end, so this start must reach Dialogic instead of waiting on a Continue press.
	assert_true(BRIDGE.is_return_only_entry("res://dialogic/timelines/en/core/hospital_faint.dtl", ""))
	var catalog := {"schema_version": 1,
		"assets": {"fixture.portrait": {"path": "res://icon.svg", "size": [128, 128]}},
		"scenes": {"hospital.faint.day3": {"background": "fixture.portrait", "portraits": [], "cg": ""}}}
	var file := FileAccess.open("user://art-hold-fixture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog))
	file.close()
	assert_true(ART.reload_placements("user://art-hold-fixture.json"))
	assert_not_null(ART.get_texture("fixture.portrait"))
	assert_true(_bridge.start_timeline_id("hospital.faint", {"kind": "hospital", "day": 3}).ok)
	assert_null(_bridge.get_art_hold_view(), "the witnessed Hospital start never defers behind the art card")
	assert_eq(_adapter._start_generation, 1, "the authored Hospital timeline physically started")
	await _await_end()
