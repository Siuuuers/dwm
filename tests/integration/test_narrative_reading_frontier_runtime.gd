extends "res://addons/gut/test.gd"
## Semantic restore uses the real mounted Dialogic coroutine. Fixture text and
## catalogue are non-canon; this suite installs no Profile/Run writer.

const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const LEDGER := preload("res://scripts/narrative/NarrativeCaptionLedger.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const FIXTURE := "res://tests/fixtures/dialogic/non_canon_caption_ledger.dtl"
const REGISTRY := "res://tests/fixtures/dialogic/non_canon_caption_registry.json"
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const ENTRY := "fixture.non_canon.caption_ledger"
const TOKEN := "fixture:native-caption-session"

class HeldRevealPort extends RefCounted:
	# The connected journey exercises the real Bridge handle and Run transaction.
	# Here the retained view crosses the real adapter/native coroutine boundary.
	var adapter: RefCounted
	func complete_paused_reading_reveal(handle: Dictionary, node: DialogicNode_DialogText) -> Dictionary:
		if handle != {"handle_id": "native-reading-pause"}:
			return {"ok": false, "code": &"invalid_suspension_handle"}
		return adapter.complete_paused_reading_frontier(node)

var _runtime: DialogicGameHandler
var _adapter: DialogicRuntimeAdapter
var _ledger: NarrativeCaptionLedger
var _viewport: SubViewport
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _style_directory: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _results: Array[Dictionary] = []
var _completion_at_publication: Array[bool] = []
var _restored: Array[Dictionary] = []
var _profile_before: Dictionary = {}
var _seek_results: Array[Dictionary] = []

func before_each() -> void:
	_results.clear()
	_restored.clear()
	_completion_at_publication.clear()
	_seek_results.clear()
	_profile_before = get_node("/root/ProfileManager").get_profile_snapshot().duplicate(true)
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(REGISTRY))
	assert_true(parsed.ok, str(parsed))
	_ledger = LEDGER.new()
	assert_true(_ledger.initialize(TOKEN, parsed.value.frozen_context,
		parsed.value.entry_manifest, parsed.value.registry).ok)
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
	assert_not_null(_runtime.Styles.load_style(STYLE, _viewport))
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok)
	_adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void:
		_results.append(result.duplicate(true))
		_completion_at_publication.append(_adapter.is_current_line_complete()))
	_adapter.reading_frontier_restored.connect(func(result: Dictionary) -> void:
		_restored.append(result.duplicate(true)))
	_adapter.reading_seek_finished.connect(func(result: Dictionary) -> void:
		_seek_results.append(result.duplicate(true)))

func after_each() -> void:
	assert_eq(get_node("/root/ProfileManager").get_profile_snapshot(), _profile_before,
		"internal publication capture cannot write the real Profile")
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
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
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null

func _settle() -> void:
	for frame: int in 6: await get_tree().process_frame

func _start(label: String = ENTRY, entry_id: String = ENTRY) -> bool:
	# end_behaviour=0 frees the preceding layout. Every new entry must remount
	# the real Witnessed host instead of silently taking Dialogic's default style.
	var layout: Node = _runtime.Styles.get_layout_node()
	if layout == null: layout = _runtime.Styles.load_style(STYLE, _viewport)
	assert_not_null(layout)
	if layout == null: return false
	var style: Resource = layout.get_meta("style", null)
	assert_not_null(style)
	if style == null: return false
	assert_eq(style.resource_path, STYLE)
	var bound := _adapter.bind_caption_ledger(_ledger, TOKEN, entry_id)
	assert_true(bound.ok, str(bound))
	if not bound.ok: return false
	var started := _adapter.start_timeline(FIXTURE, label)
	assert_true(started.ok, str(started))
	await _settle()
	assert_same(_runtime.Styles.get_layout_node(), layout, "native start retains the explicitly mounted host")
	assert_same(layout.get_parent(), _viewport, "every entry stays in the exact test viewport")
	return started.ok

func test_paused_save_completes_only_the_current_semantic_occurrence() -> void:
	if not await _start(): return
	var before := _ledger.snapshot()
	var frontier := _adapter.capture_reading_frontier()
	assert_true(frontier.ok, str(frontier))
	if not frontier.ok: return
	assert_eq(frontier.value.keys().size(), 2, "no native event position is durable")
	assert_eq(frontier.value.line_id, "fixture.caption.beta")
	assert_false(_adapter.is_current_line_complete())
	_runtime.paused = true
	assert_eq(_adapter.capture_reading_frontier(), frontier, "Pause retains semantic capture admission")
	assert_eq(_adapter.complete_reading_frontier(), frontier)
	assert_true(_runtime.paused, "Save does not unpause literal presentation")
	assert_eq(_ledger.snapshot(), before, "completing a reveal never appends History")
	_runtime.paused = false
	assert_true(_adapter.is_current_line_complete())
	assert_eq(_adapter.current_line_id(), "fixture.caption.beta", "Save cannot advance")

func _mounted_caption() -> Node:
	for layer: Node in _runtime.Styles.get_layout_node().get_layers():
		if layer.get_script() == preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd"):
			return layer
	return null

func test_hidden_pause_save_finishes_once_and_rebases_exact_view_for_continue() -> void:
	if not await _start(): return
	var caption := _mounted_caption()
	assert_not_null(caption)
	if caption == null: return
	var native: DialogicNode_DialogText = caption.caption_text
	native.active_speed = 10.0
	assert_true(native.revealing)
	var frontier := _adapter.capture_reading_frontier()
	var ledger := _ledger.snapshot()
	var history: Array = _runtime.History.full_event_history_content.duplicate(true)
	var published := _results.duplicate(true)
	var generation := native.get_reveal_generation()
	var finished: Array[Dictionary] = []
	_runtime.Text.text_finished.connect(func(info: Dictionary) -> void: finished.append(info))
	var anchor: Dictionary = caption.capture_pause_view({"route_id": "dating", "frontier": frontier.value})
	assert_true(anchor.get("ok", false), str(anchor))
	if not anchor.get("ok", false): return
	_runtime.paused = true
	assert_true(caption.cover_pause_view(anchor.value))
	var port := HeldRevealPort.new()
	port.adapter = _adapter
	var held := {"handle_id": "native-reading-pause"}
	var refused: Dictionary = caption.complete_pause_reading_reveal(anchor.value, port, {"handle_id": "foreign"})
	assert_false(refused.get("ok", true))
	assert_true(native.revealing)
	assert_eq(native.get_reveal_generation(), generation)
	var completed: Dictionary = caption.complete_pause_reading_reveal(anchor.value, port, held)
	assert_true(completed.get("ok", false), str(completed))
	if not completed.get("ok", false): return
	assert_false(native.is_visible_in_tree(), "explicit Save never uncovers the source")
	assert_false(native.is_processing())
	assert_false(native.revealing)
	assert_eq(native.visible_ratio, 1.0)
	assert_eq(native.get_reveal_generation(), generation + 1)
	assert_true(_runtime.paused)
	assert_eq(_adapter.capture_reading_frontier(), frontier)
	assert_eq(_ledger.snapshot(), ledger)
	assert_eq(_runtime.History.full_event_history_content, history)
	assert_eq(_results, published, "finishing cannot publish another History occurrence")
	assert_eq(finished.size(), 1, "the real text coroutine finishes once")
	assert_true(caption.complete_pause_reading_reveal(anchor.value, port, held).get("ok", false))
	assert_eq(finished.size(), 1, "repeated Backup/Save entry is idempotent")
	assert_eq(native.get_reveal_generation(), generation + 1)
	assert_true(caption.restore_pause_view(anchor.value), "Continue consumes the same retained view anchor")
	_runtime.paused = false
	await _settle()
	assert_true(native.is_visible_in_tree())
	assert_true(_adapter.is_current_line_complete())
	assert_eq(_adapter.current_line_id(), "fixture.caption.beta")
	assert_eq(_ledger.snapshot(), ledger)
	assert_eq(_runtime.History.full_event_history_content, history)
	assert_eq(finished.size(), 1)

func test_hidden_save_rejects_foreign_node_and_replaced_reveal_without_rebinding_pause() -> void:
	if not await _start(): return
	var caption := _mounted_caption()
	assert_not_null(caption)
	if caption == null: return
	var native: DialogicNode_DialogText = caption.caption_text
	native.active_speed = 10.0
	var frontier := _adapter.capture_reading_frontier()
	var anchor: Dictionary = caption.capture_pause_view({"route_id": "dating", "frontier": frontier.value})
	assert_true(anchor.get("ok", false))
	if not anchor.get("ok", false): return
	_runtime.paused = true
	assert_true(caption.cover_pause_view(anchor.value))
	var foreign := DialogicNode_DialogText.new()
	assert_false(_adapter.complete_paused_reading_frontier(foreign).get("ok", true))
	foreign.free()
	assert_true(native.revealing)
	var original_generation := native.get_reveal_generation()
	_runtime.Text.text_finished.connect(func(_info: Dictionary) -> void:
		native.reveal_text("Foreign replacement from a synchronous callback."), CONNECT_ONE_SHOT)
	var port := HeldRevealPort.new()
	port.adapter = _adapter
	var refused: Dictionary = caption.complete_pause_reading_reveal(anchor.value, port,
		{"handle_id": "native-reading-pause"})
	assert_false(refused.get("ok", true), str(refused))
	assert_gt(native.get_reveal_generation(), original_generation + 1)
	assert_true(_runtime.paused)
	assert_false(native.is_visible_in_tree())
	assert_false(caption.restore_pause_view(anchor.value), "a replacement cannot inherit the old Pause anchor")

func test_restore_resolves_the_second_authored_line_and_reuses_its_publication() -> void:
	if not await _start(): return
	assert_true(_adapter.complete_reading_frontier().ok)
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	var saved := _ledger.snapshot()
	var frontier := _adapter.capture_reading_frontier()
	assert_true(frontier.ok, str(frontier))
	if not frontier.ok: return
	assert_eq(frontier.value.line_id, "fixture.caption.alpha")
	assert_false(_adapter.is_current_line_complete(), "capture begins with a partial native reveal")
	_adapter.halt_with_error({"code": &"fixture_process_retired"})
	await _settle()
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(REGISTRY))
	_ledger = LEDGER.new()
	assert_true(_ledger.restore_snapshot(TOKEN, parsed.value.frozen_context,
		parsed.value.entry_manifest, parsed.value.registry, saved).ok)
	assert_not_null(_runtime.Styles.load_style(STYLE, _viewport))
	assert_true(_adapter.bind_caption_ledger(_ledger, TOKEN, ENTRY).ok)
	assert_true(_adapter.start_reading_frontier(FIXTURE, frontier.value, ENTRY).ok)
	assert_false(_adapter.capture_reading_frontier().ok,
		"no semantic Save or History proof is exposed before the restore reveal settles")
	await _settle()
	assert_eq(_restored.size(), 1, str(_restored))
	assert_eq(_adapter.capture_reading_frontier(), frontier)
	assert_eq(_ledger.snapshot(), saved, "restored current occurrence is never appended again")
	assert_true(_adapter.is_current_line_complete(), "restore cannot strand the native text_finished await")
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		if text_node.is_visible_in_tree():
			assert_false(text_node.revealing)
			assert_eq(text_node.visible_ratio, 1.0)
	_runtime.Text.text_started.emit({})
	assert_eq(_ledger.snapshot(), saved, "a late duplicate signal preserves the same occurrence")
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	assert_false(_adapter.has_active_playback(), "the saved second line continues to natural completion")

func test_resume_rejects_nonfinal_occurrences_and_unowned_authored_lines_without_starting() -> void:
	if not await _start(): return
	var earlier := _adapter.capture_reading_frontier()
	assert_true(_adapter.complete_reading_frontier().ok)
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	var before := _ledger.snapshot()
	_adapter.halt_with_error({"code": &"fixture_retire"})
	await _settle()
	assert_true(_adapter.bind_caption_ledger(_ledger, TOKEN, ENTRY).ok)
	var refused := _adapter.start_reading_frontier(FIXTURE, earlier.value, ENTRY)
	assert_false(refused.ok)
	assert_eq(refused.code, &"reading_frontier_invalid")
	assert_false(_adapter.has_active_playback())
	assert_eq(_ledger.snapshot(), before)
	assert_true(_adapter.validate_reading_line(FIXTURE, ENTRY, "fixture.caption.alpha").ok)
	assert_true(_adapter.validate_reading_line(FIXTURE, ENTRY, "fixture.caption.alpha",
		"NON-CANON TEST ONLY: an internal caption publication.").ok)
	assert_eq(_adapter.validate_reading_line(FIXTURE, ENTRY, "fixture.caption.alpha",
		"A catalogue revision that does not match native prose.").code, &"reading_line_content_mismatch")
	assert_false(_adapter.validate_reading_line(FIXTURE, ENTRY, "fixture.caption.gamma").ok)
	assert_false(_adapter.validate_reading_line(FIXTURE, ENTRY, "unregistered").ok)
	assert_false(_adapter.validate_reading_line(FIXTURE, "fixture.non_canon.caption_split", "fixture.caption.alpha").ok)
	assert_eq(_ledger.snapshot(), before, "pure authored compatibility checks mutate no ledger state")

func test_fixed_entry_preflight_rejects_extra_caption_and_early_return_despite_valid_line_lookups() -> void:
	var invalid := "res://tests/fixtures/dialogic/non_canon_reading_programme_invalid.dtl"
	var prose := "NON-CANON TEST ONLY: an internal caption publication."
	var lines := [{"line_id": "fixture.caption.beta", "text": prose},
		{"line_id": "fixture.caption.alpha", "text": prose}]
	var before := _ledger.snapshot()
	assert_true(_adapter.validate_reading_entry(FIXTURE, ENTRY, lines).ok)
	for label: String in ["fixture.reading.extra_caption", "fixture.reading.extra_return"]:
		for line: Dictionary in lines:
			assert_true(_adapter.validate_reading_line(invalid, label, line.line_id, line.text).ok,
				"each registered line exists, so individual lookups cannot prove the programme")
		assert_eq(_adapter.validate_reading_entry(invalid, label, lines).code, &"reading_entry_mismatch")
	assert_eq(_ledger.snapshot(), before)
	assert_false(_adapter.has_active_playback(), "preflight never executes even the deliberately invalid programme")


func _fixed_seek_lines() -> Array:
	var prose := "NON-CANON TEST ONLY: an internal caption publication."
	return [{"line_id": "fixture.caption.beta", "text": prose},
		{"line_id": "fixture.caption.alpha", "text": prose}]


func _seek_candidate(include_alpha: bool = true) -> NarrativeCaptionLedger:
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(REGISTRY))
	var candidate := LEDGER.new()
	assert_true(candidate.restore_snapshot(TOKEN, parsed.value.frozen_context,
		parsed.value.entry_manifest, parsed.value.registry, _ledger.snapshot()).ok)
	if include_alpha:
		assert_true(candidate.publish_line(TOKEN, "committed-next-alpha", ENTRY, "fixture.caption.alpha").ok)
	return candidate


func test_next_terminal_crosses_witnessed_tail_without_executing_or_publishing_it() -> void:
	if not await _start(): return
	var before := _ledger.snapshot()
	var source := _adapter.capture_reading_frontier()
	var event: DialogicTextEvent = _runtime.current_timeline_events[_runtime.current_event_idx]
	var completed: Array[Resource] = []
	event.event_finished.connect(func(resource: Resource) -> void: completed.append(resource))
	var started: Array[String] = []
	var shown: Array[String] = []
	_runtime.Text.text_started.connect(func(info: Dictionary) -> void: started.append(info.text))
	_runtime.Text.about_to_show_text.connect(func(info: Dictionary) -> void: shown.append(info.text))
	var native_events: Array[Resource] = []
	_runtime.event_handled.connect(func(resource: Resource) -> void: native_events.append(resource))
	var prepared := _adapter.prepare_reading_seek(source.value, ENTRY, _fixed_seek_lines())
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_eq(_adapter.prepare_reading_seek(source.value, ENTRY, _fixed_seek_lines()), prepared,
		"identical preparation retains one source capability")
	assert_eq(_ledger.snapshot(), before, "preparation has no History side effect")
	var target := _seek_candidate()
	var target_snapshot := target.snapshot()
	var applied := _adapter.apply_reading_seek(prepared.value, target)
	assert_true(applied.ok, str(applied))
	if not applied.ok: return
	assert_true(applied.value.pending)
	await _settle()
	assert_false(_adapter.has_active_playback(), "proved Return runs the ordinary natural end")
	assert_eq(completed.size(), 1, "the original text coroutine finishes exactly once")
	assert_false(event.event_finished.is_connected(Callable(_runtime, "handle_next_event")))
	assert_false(_runtime.Inputs.dialogic_action.is_connected(Callable(event, "_on_dialogic_input_action")),
		"native cleanup retires source input callbacks")
	assert_eq(started, [], "crossed text cannot queue native speech or caption acknowledgement")
	assert_eq(shown, [], "crossed text never reaches even the pre-presentation signal")
	var returned := false
	for native: Resource in native_events:
		if native is DialogicReturnEvent: returned = true
		assert_false(native is DialogicTextEvent, "only Return and native ending cleanup may execute")
	assert_true(returned)
	assert_eq(_results.size(), 1, "only the original visible source was published")
	assert_eq(target.snapshot(), target_snapshot, "silent History comes only from the committed candidate")
	assert_eq(_ledger.snapshot(), before, "the original ledger was not partially extended")
	assert_eq(_seek_results, [{"ok": true, "value": {"frontier": {}, "terminal": true}}])
	assert_eq(_restored, [], "Next does not impersonate Load")


func test_next_unseen_destination_reuses_committed_occurrence_with_ordinary_partial_publication() -> void:
	if not await _start(): return
	var source := _adapter.capture_reading_frontier()
	var source_event: DialogicTextEvent = _runtime.current_timeline_events[_runtime.current_event_idx]
	var prepared := _adapter.prepare_reading_seek(source.value, ENTRY, _fixed_seek_lines(), "fixture.caption.alpha")
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var target := _seek_candidate()
	var before := target.snapshot()
	var frontier := {"line_id": "fixture.caption.alpha", "publication_id": "committed-next-alpha"}
	var started: Array[Dictionary] = []
	_runtime.Text.text_started.connect(func(info: Dictionary) -> void:
		started.append({"text": info.text, "restoring": _adapter.is_reading_frontier_restoring()}))
	var applied := _adapter.apply_reading_seek(prepared.value, target, frontier)
	assert_true(applied.ok, str(applied))
	if not applied.ok: return
	await _settle()
	assert_eq(_adapter.capture_reading_frontier(), {"ok": true, "value": frontier})
	assert_eq(started.size(), 1, "the destination is the only new visible text publication")
	if started.size() == 1: assert_false(started[0].restoring, "first speech must not inherit Load suppression")
	assert_false(_adapter.is_current_line_complete(), "Next materializes the unseen destination normally")
	assert_false(_completion_at_publication.back())
	assert_eq(_results.size(), 2)
	assert_true(_results.back().value.get("duplicate", false), "the precommitted occurrence is never appended twice")
	assert_eq(target.snapshot(), before)
	assert_eq(_seek_results, [{"ok": true, "value": {"frontier": frontier, "terminal": false}}])
	assert_eq(_restored, [])
	assert_false(_runtime.Inputs.dialogic_action.is_connected(Callable(source_event, "_on_dialogic_input_action")))
	assert_true(_adapter.complete_reading_frontier().ok)
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	assert_false(_adapter.has_active_playback(), "the ordinary destination coroutine also remains continuable")


func test_next_rejects_changed_plan_missing_history_and_stale_source_before_native_motion() -> void:
	if not await _start(): return
	var source := _adapter.capture_reading_frontier()
	var before := _ledger.snapshot()
	var prepared := _adapter.prepare_reading_seek(source.value, ENTRY, _fixed_seek_lines())
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var changed: Dictionary = prepared.value.duplicate(true)
	changed["terminal"] = false
	assert_eq(_adapter.apply_reading_seek(changed, _seek_candidate()).code, &"reading_seek_stale")
	assert_eq(_adapter.apply_reading_seek(prepared.value, _seek_candidate(false)).code, &"reading_seek_target_invalid")
	assert_eq(_adapter.capture_reading_frontier(), source)
	assert_eq(_ledger.snapshot(), before)
	assert_false(_adapter.is_current_line_complete(), "failed candidate admission never finishes source reveal")
	assert_eq(_seek_results, [])
	assert_true(_adapter.complete_reading_frontier().ok)
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	var after_advance := _adapter.capture_reading_frontier()
	assert_eq(_adapter.apply_reading_seek(prepared.value, _seek_candidate(false)).code, &"reading_seek_stale")
	assert_eq(_adapter.capture_reading_frontier(), after_advance)
	assert_eq(_adapter.prepare_reading_seek(after_advance.value, ENTRY, _fixed_seek_lines(),
		"fixture.caption.beta").code, &"reading_seek_changed", "Next cannot run backwards")


func test_next_same_unseen_source_completes_once_without_restarting_its_publication() -> void:
	if not await _start(): return
	var source := _adapter.capture_reading_frontier()
	var prepared := _adapter.prepare_reading_seek(source.value, ENTRY, _fixed_seek_lines(), "fixture.caption.beta")
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var target := _seek_candidate(false)
	var before := target.snapshot()
	var applied := _adapter.apply_reading_seek(prepared.value, target, source.value)
	assert_true(applied.ok, str(applied))
	assert_true(_adapter.is_current_line_complete())
	assert_eq(_adapter.capture_reading_frontier(), source)
	assert_eq(target.snapshot(), before)
	assert_eq(_results.size(), 1)
	assert_eq(_seek_results.size(), 1)
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	assert_eq(_adapter.current_line_id(), "fixture.caption.alpha")


func test_next_rechecks_native_catalogue_and_source_finish_callbacks_before_installing_target() -> void:
	if not await _start(): return
	var source := _adapter.capture_reading_frontier()
	var prepared := _adapter.prepare_reading_seek(source.value, ENTRY, _fixed_seek_lines())
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var source_index := _runtime.current_event_idx
	var event: DialogicTextEvent = _runtime.current_timeline_events[source_index]
	var target := _seek_candidate()
	var target_before := target.snapshot()
	var next: DialogicTextEvent = _runtime.current_timeline_events[source_index + 1]
	var original_text := next.text
	# A ready event may change even while the resource's original source text
	# still matches the catalogue. The retained live list must be revalidated.
	next.text = "Changed native caption after preparation."
	next.event_node_ready = true
	assert_eq(_adapter.apply_reading_seek(prepared.value, target).code, &"reading_seek_changed")
	assert_eq(_adapter.capture_reading_frontier(), source)
	next.text = original_text
	event.event_finished.connect(func(_event: DialogicEvent) -> void:
		_runtime.current_event_idx = source_index + 1, CONNECT_ONE_SHOT)
	assert_eq(_adapter.apply_reading_seek(prepared.value, target).code, &"reading_seek_changed")
	assert_eq(target.snapshot(), target_before)
	assert_eq(_results.size(), 1, "a replaced source cannot materialize the committed target")
	assert_true(event.event_finished.is_connected(Callable(_runtime, "handle_next_event")),
		"the exact native continuation is restored even after a finish callback refuses")
	assert_eq(_seek_results, [])


func test_next_rejects_future_caption_mutated_by_source_finish_callback() -> void:
	if not await _start(): return
	var source := _adapter.capture_reading_frontier()
	var prepared := _adapter.prepare_reading_seek(source.value, ENTRY, _fixed_seek_lines(), "fixture.caption.alpha")
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var source_index := _runtime.current_event_idx
	var event: DialogicTextEvent = _runtime.current_timeline_events[source_index]
	var next: DialogicTextEvent = _runtime.current_timeline_events[source_index + 1]
	var original_text := next.text
	var originally_ready := next.event_node_ready
	var target := _seek_candidate()
	var target_before := target.snapshot()
	var frontier := {"line_id": "fixture.caption.alpha", "publication_id": "committed-next-alpha"}
	var finished: Array[bool] = []
	var shown: Array[String] = []
	_runtime.Text.about_to_show_text.connect(func(info: Dictionary) -> void: shown.append(info.text))
	event.event_finished.connect(func(_event: DialogicEvent) -> void:
		finished.append(true)
		# Preserve the source identity/index while changing only the programme
		# that would execute after its coroutine has unwound.
		next.text = "Changed destination from the source completion callback."
		next.event_node_ready = true, CONNECT_ONE_SHOT)
	var applied := _adapter.apply_reading_seek(prepared.value, target, frontier)
	next.text = original_text
	next.event_node_ready = originally_ready
	assert_false(applied.ok, str(applied))
	assert_eq(applied.get("code"), &"reading_seek_changed")
	assert_eq(finished.size(), 1, "the mutation runs only after the source coroutine finishes")
	assert_eq(_adapter.capture_reading_frontier(), source, "source identity alone cannot admit a changed future")
	assert_eq(_runtime.current_event_idx, source_index, "no target event was entered")
	assert_eq(target.snapshot(), target_before, "refusal leaves the committed candidate intact")
	assert_true(event.event_finished.is_connected(Callable(_runtime, "handle_next_event")),
		"refusal restores the native continuation before returning to its owner")
	await _settle()
	assert_eq(shown, [], "the invalid future never reaches presentation")
	assert_eq(_results.size(), 1, "only the original source occurrence was published")
	assert_eq(_seek_results, [], "a refused seek never reports a completed destination")


func test_next_pending_publication_halt_reports_one_failure_instead_of_leaving_an_await() -> void:
	if not await _start(): return
	var source := _adapter.capture_reading_frontier()
	var prepared := _adapter.prepare_reading_seek(source.value, ENTRY, _fixed_seek_lines(), "fixture.caption.alpha")
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	_adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void:
		if result.get("ok", false) and result.value.get("duplicate", false):
			_adapter.halt_with_error({"ok": false, "code": &"fixture_next_publication_halted"}))
	var frontier := {"line_id": "fixture.caption.alpha", "publication_id": "committed-next-alpha"}
	var applied := _adapter.apply_reading_seek(prepared.value, _seek_candidate(), frontier)
	assert_true(applied.ok, str(applied))
	if not applied.ok: return
	assert_true(applied.value.pending)
	await _settle()
	assert_eq(_seek_results, [{"ok": false, "code": &"fixture_next_publication_halted"}])
	assert_false(_adapter.has_active_playback())
	await _settle()
	assert_eq(_seek_results.size(), 1, "native end and stale deferred completion cannot publish a second result")
