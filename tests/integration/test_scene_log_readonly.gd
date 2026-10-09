extends "res://addons/gut/test.gd"
## Mounted unchanged caption/history UI, actual Dialogic text events, scene ledger,
## Bridge projection, and physical/Profile Challenge owners. TEST injection is
## limited to historical scene admission, Challenge admission/checkpoint/closure
## authority and storage/generation from SceneChallengeFixture, plus router/input
## custody below. This does NOT prove forward DTL -> Challenge or Save8 wiring.
const BASE := preload("res://tests/support/SceneDayReadingFixture.gd")
const CHALLENGE := preload("res://tests/support/SceneChallengeFixture.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const PATH := "res://tests/fixtures/dialogic/scene_day_terminal.dtl"

class InputCustody extends Node:
	signal source_input_custody_changed
	signal input_bindings_changed
	func is_source_input_admitted() -> bool: return true
	func get_physical_contacts() -> Dictionary: return {}
	func observe_physical_contact(_event: InputEvent) -> void: pass
	func get_physical_contact_id(_event: InputEvent) -> String: return ""

class HistoryRouter extends Node:
	var runtime: Node
	var source: Object
	var opens := 0
	var closes := 0
	func can_open_witnessed_history(_source: Object) -> bool: return source == null
	func open_witnessed_history(candidate: Object) -> Dictionary:
		if source != null: return {"ok": false}
		source = candidate
		runtime.paused = true
		opens += 1
		return {"ok": true}
	func is_witnessed_history_open(candidate: Object) -> bool: return source == candidate
	func close_witnessed_history(candidate: Object) -> Dictionary:
		if source != candidate: return {"ok": false}
		source = null
		runtime.paused = false
		closes += 1
		return {"ok": true}

var _runtime: DialogicGameHandler
var _adapter: DialogicRuntimeAdapter
var _viewport: SubViewport
var _caption: Node
var _router: HistoryRouter
var _input: InputCustody
var _bridge: Node
var _session: RefCounted
var _challenge: RefCounted
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _style_directory: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _profile_before: Dictionary = {}
var _publications: Array = []
var _native_markers: Array = []
var _bridge_markers: Array = []

func before_all() -> void:
	assert_true(BASE.configure().ok)

func before_each() -> void:
	_profile_before = get_node("/root/ProfileManager").get_profile_snapshot().duplicate(true)
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
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
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	get_tree().root.add_child(_runtime)
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	add_child(_viewport)
	var layout: Node = _runtime.Styles.load_style("res://dialogic/styles/witnessed_caption_style.tres", _viewport)
	assert_not_null(layout)
	for layer: Node in layout.get_layers():
		if layer.get_script().resource_path == "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd": _caption = layer
	assert_not_null(_caption)
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok)
	_adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void: _publications.append(result.duplicate(true)))
	_adapter.runtime_signal_event.connect(func(argument: Variant) -> void: _native_markers.append(argument))
	_bridge = BRIDGE.new()
	autofree(_bridge)
	_bridge._runtime_adapter = _adapter
	_bridge.timeline_marker_received.connect(func(id: String, payload: Dictionary) -> void: _bridge_markers.append([id, payload.duplicate(true)]))
	_adapter.runtime_signal_event.connect(_bridge._on_runtime_signal_event)
	_input = InputCustody.new()
	_viewport.add_child(_input)
	_router = HistoryRouter.new()
	_router.runtime = _runtime
	_viewport.add_child(_router)
	# Inject only external custody, never replace the actual UI or history owner.
	_caption.accept_input._input_custody = _input
	_caption._reading_input_owner = _input
	_caption._backup_load_router = _router
	_caption._history_input_bound = _caption.transport_rail.bind_history_admission(_caption._history_admitted, _input)
	_challenge = CHALLENGE.new()
	assert_true(_challenge.setup("TEST.scene.log.readonly").ok)

func _start_story() -> bool:
	var created := BASE.create_session()
	assert_true(created.ok, str(created))
	if not created.ok: return false
	_session = created.value
	assert_true(BASE.enter(_session, BASE.A, "log:past").ok)
	# Registered historical loop publications make genuine overflow. No fake UI
	# rows are appended: every displayed row comes from the real scene ledger.
	for index: int in 40:
		var advanced := BASE.advance_detached(_session)
		assert_true(advanced.ok, str(advanced))
		if not advanced.ok: return false
	var frame := BASE.frame(BASE.A, "log:current")
	assert_true(_session.admit_scene(BASE.A, frame).ok)
	assert_true(_adapter.bind_caption_ledger(_session.ledger, _session.command_id, BASE.A, false, "log:current").ok)
	assert_true(_adapter.start_timeline(PATH, "scene.test.a.loop").ok)
	await _settle()
	assert_true(_adapter.reveal_current_line(true).ok)
	await _settle()
	# Four actual native activations populate at least three past captions, so
	# the mounted three-caption rail has a genuine historical review position.
	for index: int in 3:
		assert_true(_adapter.advance_one_event().ok)
		await _settle()
		assert_true(_adapter.reveal_current_line(true).ok)
		await _settle()
	_session.scene_index = 1
	_bridge._reading_session = _session
	_bridge._active_entry = {"entry_id": BASE.A, "token": "log:test", "stage": "scene",
		"execution_mode": &"canonical", "transaction_id": frame.transaction_id,
		"context_fingerprint": "log:test:frame", "content_version": 1,
		"path": PATH, "label": "scene.test.a.loop", "frozen_context": frame}
	# Bind the real projection owner; skip/auto are outside this read-only slice.
	_caption._transport_bridge = _bridge
	_caption._capture_presented_line()
	_caption._sync_transport()
	assert_eq(_publications.size(), 4, "each native loop activation publishes once")
	assert_gte(_caption._scrollback.size(), 3, "native renderer populated past captions")
	return true

func _snapshot() -> Dictionary:
	return {"physical": _challenge.owner.pull_physical(_challenge.token),
		"live_run": get_node("/root/GameState").capture_run_snapshot_input().duplicate(true),
		"live_balances": {"money": get_node("/root/GameState").money,
			"coins": get_node("/root/GameState").coins, "pressure": get_node("/root/GameState").get_stat("pressure")},
		"record": _challenge.record(), "attempt": _challenge.attempt(),
		"profile": _challenge.profile.get_profile_snapshot(),
		"route": _challenge.state.route_context.duplicate(true),
		"branch": _challenge.state.lifecycle.duplicate(true),
		"inventory": _challenge.state.inventory.duplicate(true),
		"penalty": _challenge.state.penalty_points_today, "pressure": _challenge.state.pressure,
		"effects": _challenge.state.effects, "closures": _challenge.authority.closures.duplicate(true),
		"checkpoints": _challenge.authority.checkpoints.duplicate(true),
		"ledger": _session.ledger.snapshot(), "history": _bridge.get_reading_history(),
		"frontier": _adapter.capture_reading_frontier(),
		"publications": _publications.duplicate(true), "native_markers": _native_markers.duplicate(true),
		"bridge_markers": _bridge_markers.duplicate(true)}

func _browse_without_mutation(phase: String) -> void:
	var before := _snapshot()
	assert_true(before.history.ok)
	assert_eq(_caption._review_offset, 0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	_caption.scroll.gui_input.emit(wheel)
	await _settle()
	assert_gt(_caption._review_offset, 0, phase + ": actual caption wheel enters past story")
	assert_true(_caption.review_current.is_visible_in_tree())
	assert_false(_caption.review_current.get_parsed_text().is_empty())
	assert_eq(_snapshot(), before, phase + ": caption past review is read-only")
	wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_caption.scroll.gui_input.emit(wheel)
	await _settle()
	assert_eq(_caption._review_offset, 0, phase + ": actual caption wheel returns to current")
	assert_true(_caption.caption_text.is_visible_in_tree())
	assert_eq(_snapshot(), before, phase + ": caption return is read-only")
	var expected: Array[String] = []
	for row: Dictionary in before.history.value.captions: expected.append(row.text)
	assert_gt(expected.size(), 40, "past and current story really populated")
	assert_true(_caption._history_admitted(), phase)
	# Same signal used by the mounted rail, then actual registered accessibility
	# callbacks on mounted controls. No direct scroll offset assignment in test.
	_caption.transport_rail.history_requested.emit()
	await _settle()
	var history: Control = _caption._history_overlay
	assert_true(_caption._history_open, phase)
	assert_true(history.is_visible_in_tree())
	assert_eq(history.get_captions(), expected, "no Challenge bookkeeping rows")
	var scroll: ScrollContainer = history.reading_scroll
	assert_gt(scroll.get_v_scroll_bar().max_value, scroll.get_v_scroll_bar().page)
	var start: int = scroll.scroll_vertical
	scroll._accessibility_page(null, 1, scroll.generation)
	await _settle()
	var forward: int = scroll.scroll_vertical
	assert_gt(forward, start, "forward browsing really moves content")
	scroll._accessibility_page(null, -1, scroll.generation)
	await _settle()
	assert_lt(scroll.scroll_vertical, forward, "backward browsing really moves content")
	var old_percent: int = _caption._text_percent
	var old_extent: float = scroll.get_v_scroll_bar().max_value
	assert_true(_caption.configure_presentation("en", 150 if old_percent == 100 else 100))
	assert_ne(_caption._text_percent, old_percent, "each phase actually changes text metrics")
	await _settle()
	assert_ne(scroll.get_v_scroll_bar().max_value, old_extent, "mounted history geometry actually reflows")
	assert_eq(history.get_captions(), expected, "reflow retains story-only rows")
	assert_eq(_snapshot(), before, phase + ": browse/reflow cannot change owners")
	history.close_button._activate(null, history.close_button.generation)
	await _settle()
	assert_false(_caption._history_open)
	assert_false(history.is_visible_in_tree())
	assert_eq(_snapshot(), before, phase + ": close cannot replay markers or republish")

func test_mounted_log_is_read_only_across_real_challenge_owner_boundaries() -> void:
	if not await _start_story(): return
	assert_true(_challenge.begin().ok)
	assert_eq(_challenge.owner.pull_physical(_challenge.token).value.phase, "never_started")
	await _browse_without_mutation("never_started")
	assert_true(_challenge.action("start").ok)
	assert_true(_challenge.action("reveal", 36).ok)
	assert_eq(_challenge.owner.pull_physical(_challenge.token).value.state, "in_progress")
	assert_not_null(_challenge.owner.pull_physical(_challenge.token).value.board)
	assert_false(_challenge.attempt().value.is_empty(), "real Profile attempt exists")
	await _browse_without_mutation("in_progress")
	# Challenge boundary admission/closure is explicitly injected by fixture;
	# physical closure/result and retained Profile attempt remain real owners.
	assert_true(_challenge.owner.close_scene_challenge(_challenge.token).ok)
	assert_eq(_challenge.owner.pull_physical(_challenge.token).value.phase, "closed")
	assert_false(_challenge.authority.closures.is_empty())
	# A second actual native story caption follows the injected closure boundary.
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	assert_true(_adapter.reveal_current_line(true).ok)
	await _settle()
	_session.scene_index = 1
	assert_eq(_adapter.current_line_id(), "line.scene.test.a.two")
	assert_eq(_publications.size(), 5)
	await _browse_without_mutation("closed")
	assert_eq(_router.opens, 3)
	assert_eq(_router.closes, 3)
	assert_eq(_challenge.state.effects, 0)
	assert_eq(_native_markers, [])
	assert_eq(_bridge_markers, [])

func after_each() -> void:
	assert_eq(get_node("/root/ProfileManager").get_profile_snapshot(), _profile_before)
	_challenge.dispose()
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"): text_node.set_process(false)
	if is_instance_valid(_runtime):
		_runtime.paused = false
		await _runtime.clear()
		var remaining: Node = _runtime.Styles.get_layout_node()
		if is_instance_valid(remaining) and not _viewport.is_ancestor_of(remaining): remaining.queue_free()
	_viewport.queue_free()
	await get_tree().process_frame
	if is_instance_valid(_runtime): _runtime.free()
	_adapter = null
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout) and is_instance_valid(_original_layout_parent):
		_original_layout_parent.add_child(_original_layout)
		_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	for key: String in _settings: ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null

func _settle() -> void:
	for frame: int in 6: await get_tree().process_frame
