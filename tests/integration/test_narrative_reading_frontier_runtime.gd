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

func before_each() -> void:
	_results.clear()
	_restored.clear()
	_completion_at_publication.clear()
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
