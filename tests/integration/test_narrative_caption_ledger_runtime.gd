extends "res://addons/gut/test.gd"
## Real mounted Dialogic, with explicitly non-canon prose. No Profile/Run writer
## is installed by this suite. The native publication ledger is not witnessing.

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
var _profile_before: Dictionary = {}

func before_each() -> void:
	_results.clear()
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

func test_native_publications_use_authored_identity_and_actual_order_before_reveal_finishes() -> void:
	if not await _start(): return
	var first: Array = _ledger.snapshot().captions
	assert_eq(first.size(), 1, str(_results))
	if first.size() != 1: return
	assert_eq(first[0].beat.line_id, "fixture.caption.beta")
	assert_eq(first[0].beat.beat_id, "fixture.beat.beta")
	assert_false(_completion_at_publication[0], "publication is recorded before glyph completion")
	assert_true(_adapter.reveal_current_line(true).ok)
	await _settle()
	assert_eq(_ledger.snapshot().captions.size(), 1, "reveal completion creates no second publication")
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	var captions: Array = _ledger.snapshot().captions
	assert_eq(captions.size(), 2, str(_results))
	if captions.size() != 2: return
	assert_eq(captions[1].beat.line_id, "fixture.caption.alpha")
	assert_ne(captions[0].publication_id, captions[1].publication_id)
	assert_eq(captions[0].beat.presentation_signature.text_revision, "beta-v1")
	assert_eq(captions[1].beat.presentation_signature.text_revision, "alpha-v1")
	assert_true(_adapter.reveal_current_line(true).ok)
	await _settle()
	var before := _ledger.snapshot()
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	assert_eq(_ledger.snapshot(), before, "return/completion creates no caption")

func test_duplicate_native_signal_and_glyph_completion_do_not_duplicate_the_ledger() -> void:
	if not await _start(): return
	var before := _ledger.snapshot()
	_runtime.Text.text_started.emit({"text": "foreign visible prose cannot become identity"})
	assert_eq(_ledger.snapshot(), before)
	assert_true(_results[-1].ok)
	assert_true(_results[-1].value["duplicate"])
	_runtime.Text.text_finished.emit({"text": "glyph completion"})
	assert_eq(_ledger.snapshot(), before)

func test_same_path_foreign_playback_and_late_signals_cannot_enter_the_bound_session() -> void:
	if not await _start(): return
	var before := _ledger.snapshot()
	_runtime.start_timeline(FIXTURE, ENTRY, "foreign:request")
	await _settle()
	_runtime.Text.about_to_show_text.emit({})
	_runtime.Text.text_started.emit({})
	assert_eq(_ledger.snapshot(), before)

func test_halt_retires_the_binding_before_failure_and_late_publication_callbacks() -> void:
	if not await _start(): return
	var before := _ledger.snapshot()
	_adapter.halt_with_error({"code": &"fixture_stop"})
	_runtime.Text.about_to_show_text.emit({})
	_runtime.Text.text_started.emit({})
	assert_eq(_ledger.snapshot(), before)

func test_missing_authored_id_is_refused_without_inference_from_prose_or_position() -> void:
	if not await _start("fixture.non_canon.caption_missing_id"): return
	assert_eq(_ledger.snapshot().captions.size(), 0)
	assert_false(_results.is_empty())
	if not _results.is_empty(): assert_eq(_results[-1].code, &"caption_line_unregistered")

func test_multiple_text_segments_cannot_share_one_registered_caption_identity() -> void:
	if not await _start("fixture.non_canon.caption_split"): return
	assert_eq(_ledger.snapshot().captions.size(), 0)
	assert_false(_results.is_empty())
	if not _results.is_empty(): assert_eq(_results[-1].code, &"caption_publication_source_invalid")

func test_paused_publication_duplicate_remains_bound_without_enabling_skip() -> void:
	if not await _start(): return
	var before := _ledger.snapshot()
	_runtime.paused = true
	assert_eq(_adapter.current_line_id(), "", "Skip still refuses paused playback")
	_runtime.Text.text_started.emit({})
	assert_true(_results[-1].ok)
	assert_true(_results[-1].value["duplicate"])
	assert_eq(_ledger.snapshot(), before)

func test_unconfigured_runtime_has_no_ledger_side_effects() -> void:
	assert_true(_adapter.start_timeline(FIXTURE, ENTRY).ok)
	await _settle()
	assert_eq(_ledger.snapshot().captions.size(), 0)
	assert_true(_results.is_empty())
	assert_eq(_adapter.bind_caption_ledger(_ledger, TOKEN, ENTRY).code, &"caption_binding_unavailable")

func test_native_entries_share_one_sequence_across_retirement_reconstruction_and_fresh_publication() -> void:
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(REGISTRY))
	assert_true(parsed.ok)
	# Each component admits primitives through depth 32. Wrapping them in a
	# snapshot must not shrink that existing contract during reconstruction.
	var deepest: Variant = "component depth 32"
	for depth: int in 31: deepest = {"nested": deepest}
	parsed.value.frozen_context["depth_boundary"] = deepest
	parsed.value.entry_contexts[ENTRY]["depth_boundary"] = deepest.duplicate(true)
	parsed.value.registry.beats[2].presentation_signature["depth_boundary"] = deepest.duplicate(true)
	_ledger = LEDGER.new()
	var initialized := _ledger.initialize(TOKEN, parsed.value.frozen_context,
		parsed.value.entry_manifest, parsed.value.registry, true)
	assert_true(initialized.ok, str(initialized))
	if not initialized.ok: return
	assert_eq(_adapter.bind_caption_ledger(_ledger, TOKEN, ENTRY).code,
		&"caption_entry_context_missing", "the native host cannot publish before entry facts exist")
	assert_true(_ledger.admit_entry_context(TOKEN, ENTRY, parsed.value.entry_contexts[ENTRY]).ok)
	if not await _start(): return
	var first_layout: WeakRef = weakref(_runtime.Styles.get_layout_node())
	for line: int in 2:
		assert_true(_adapter.reveal_current_line(true).ok)
		await _settle()
		assert_true(_adapter.advance_one_event().ok)
		await _settle()
	assert_false(_adapter.has_active_playback())
	assert_null(first_layout.get_ref(), "natural completion frees the old host and its native handlers")
	var first_entry := _ledger.snapshot()
	assert_eq(first_entry.captions.size(), 2)
	assert_eq(first_entry.entry_contexts.keys(), [ENTRY], "the later entry is still unadmitted")
	if first_entry.captions.size() != 2: return
	# A no-playback seam retains History but owns no publication. Late signals
	# must not even reserve an occurrence before the next semantic entry starts.
	_runtime.Text.about_to_show_text.emit({})
	_runtime.Text.text_started.emit({})
	assert_eq(_ledger.snapshot(), first_entry)
	var second_entry := "fixture.non_canon.foreign_entry"
	assert_eq(_adapter.bind_caption_ledger(_ledger, TOKEN, second_entry).code,
		&"caption_entry_context_missing")
	assert_eq(_ledger.snapshot(), first_entry, "failed later binding preserves earlier History")
	assert_true(_ledger.admit_entry_context(TOKEN, second_entry,
		parsed.value.entry_contexts[second_entry]).ok)
	if not await _start(second_entry, second_entry): return
	var second_layout: WeakRef = weakref(_runtime.Styles.get_layout_node())
	var together := _ledger.snapshot()
	assert_eq(together.captions.size(), 3, str(_results))
	if together.captions.size() != 3: return
	assert_eq(together.captions.slice(0, 2), first_entry.captions)
	assert_eq(together.captions[2].beat.line_id, "fixture.caption.gamma")
	assert_eq(together.captions[2].publication_id, "caption:3")
	assert_eq(together.entry_contexts[ENTRY], first_entry.entry_contexts[ENTRY])
	assert_eq(together.entry_contexts[together.captions[2].beat.owning_entry_id],
		parsed.value.entry_contexts[second_entry])
	_runtime.Text.text_started.emit({})
	assert_eq(_ledger.snapshot(), together, "duplicate native delivery remains idempotent")
	assert_true(_adapter.reveal_current_line(true).ok)
	await _settle()
	assert_true(_adapter.advance_one_event().ok)
	await _settle()
	assert_false(_adapter.has_active_playback())
	assert_null(second_layout.get_ref(), "reconstruction begins after the second host is released")
	var retired := _ledger
	var reconstructed := LEDGER.new()
	var empty := reconstructed.snapshot()
	var damaged := together.duplicate(true)
	damaged.captions[2].beat.presentation_signature.text_revision = "unregistered"
	assert_eq(reconstructed.restore_snapshot(TOKEN, parsed.value.frozen_context,
		parsed.value.entry_manifest, parsed.value.registry, damaged, parsed.value.entry_contexts, true).code,
		&"caption_registration_mismatch")
	assert_eq(reconstructed.snapshot(), empty, "a damaged native suffix cannot install its valid prefix")
	assert_eq(_adapter.bind_caption_ledger(reconstructed, TOKEN, ENTRY).code,
		&"caption_session_uninitialized", "failed reconstruction cannot admit native playback")
	damaged = together.duplicate(true)
	damaged.captions.append(damaged.captions[0].duplicate(true))
	assert_eq(reconstructed.restore_snapshot(TOKEN, parsed.value.frozen_context,
		parsed.value.entry_manifest, parsed.value.registry, damaged, parsed.value.entry_contexts, true).code,
		&"caption_snapshot_duplicate")
	assert_eq(reconstructed.snapshot(), empty, "duplicate retained occurrences cannot be silently collapsed")
	damaged = together.duplicate(true)
	damaged.entry_contexts[second_entry].selectors.result = "invented result"
	assert_eq(reconstructed.restore_snapshot(TOKEN, parsed.value.frozen_context,
		parsed.value.entry_manifest, parsed.value.registry, damaged, parsed.value.entry_contexts, true).code,
		&"caption_entry_context_mismatch")
	assert_eq(reconstructed.snapshot(), empty, "corrupt later context cannot install a valid earlier entry")
	_runtime.Text.about_to_show_text.emit({})
	_runtime.Text.text_started.emit({})
	assert_eq(retired.snapshot(), together, "failed reconstruction and late callbacks preserve the source")
	var restored := reconstructed.restore_snapshot(TOKEN, parsed.value.frozen_context,
		parsed.value.entry_manifest, parsed.value.registry, together, parsed.value.entry_contexts, true)
	assert_true(restored.ok, str(restored))
	if not restored.ok: return
	assert_eq(reconstructed.snapshot(), together, "reconstruction preserves exact publication order")
	assert_eq(reconstructed.publish_line(TOKEN, "caption:1", ENTRY, "fixture.caption.beta").value,
		{"duplicate": true, "ordinal": 0}, "reconstruction retains idempotence indexes")
	var expected := together.duplicate(true)
	together.frozen_context.selectors.inputs.clear()
	together.captions[0].beat.presentation_signature.selectors.append("caller mutation")
	together.entry_contexts[ENTRY].selectors.inputs.clear()
	parsed.value.frozen_context.selectors.inputs.clear()
	parsed.value.entry_contexts[second_entry].selectors.inputs.clear()
	parsed.value.registry.beats[0].presentation_signature.selectors.append("catalog mutation")
	assert_eq(reconstructed.snapshot(), expected, "restored context and identities are detached")
	var exposed := reconstructed.snapshot()
	exposed.captions.clear()
	exposed.frozen_context.selectors.inputs.clear()
	exposed.entry_contexts.clear()
	assert_eq(reconstructed.snapshot(), expected, "returned snapshots are also detached")
	_ledger = reconstructed
	_runtime.Text.about_to_show_text.emit({})
	_runtime.Text.text_started.emit({})
	assert_eq(_ledger.snapshot(), expected, "restoration itself cannot publish native text")
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok, "a fresh adapter needs no old occurrence counter")
	if not await _start(): return
	var continued := _ledger.snapshot()
	assert_eq(continued.captions.size(), 4)
	if continued.captions.size() != 4: return
	assert_eq(continued.captions.slice(0, 3), expected.captions)
	assert_eq(continued.captions[3].publication_id, "caption:4")
	assert_eq(continued.captions[3].beat.line_id, "fixture.caption.beta")
	assert_eq(retired.snapshot(), expected, "fresh native playback cannot mutate the departed ledger")
	_runtime.Text.text_started.emit({})
	assert_eq(_ledger.snapshot(), continued)
