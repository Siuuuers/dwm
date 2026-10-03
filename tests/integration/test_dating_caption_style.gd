extends GutTest
## Real Bridge/Styles selection, with optional artwork deliberately unavailable.
## Authored dating masters currently contain return stubs, so named prose uses a fixture.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const DATING_PLAYBACK := preload("res://scripts/application/run/DatingNarrativePlayback.gd")
const ART := preload("res://scripts/data/ArtManifest.gd")
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const LAYER := "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd"
const ART_LAYER := "res://scripts/ui/witnessed/WitnessedArtLayer.gd"
const ART_VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
const ART_FIXTURES := preload("res://tests/unit/test_scene_art_bindings.gd")
const DATING := "dating.solo.priscilla.day1.pre_challenge"

class Completion extends RefCounted:
	var calls: Array[Dictionary] = []
	func complete_entry(intent: Dictionary) -> Dictionary:
		calls.append(intent.duplicate(true))
		return {"ok": true}

class CaptionRuntime extends DialogicGameHandler:
	var injected_path := ""
	var injected_timeline: DialogicTimeline
	func start_timeline(timeline: Variant, label_or_idx: Variant = "", request_id: String = "") -> void:
		# Only replace fixture prose. Adapter admission, deferred layout, semantic labels,
		# native generation signals and natural completion retain the production path.
		if timeline is String and timeline == injected_path and injected_timeline != null:
			timeline = injected_timeline
		super.start_timeline(timeline, label_or_idx, request_id)

var runtime: DialogicGameHandler
var bridge: Node
var completion: Completion
var _original_runtime: Node
var _original_index := 0
var _original_bridge: Node
var _original_bridge_index := 0
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
var _root_size: Vector2i
var _root_content_size: Vector2i
var _mouse_from_touch := false
var _width_profile: RefCounted
var _replaced_timeline: Resource
var _replaced_timeline_path := ""
var _replaced_timeline_source: PackedByteArray

func before_each() -> void:
	_root_size = get_tree().root.size
	_root_content_size = get_tree().root.content_scale_size
	_mouse_from_touch = Input.emulate_mouse_from_touch
	_width_profile = ART_FIXTURES.ViewProfile.new()
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
	runtime = CaptionRuntime.new()
	runtime.name = "Dialogic"
	get_tree().root.add_child(runtime)
	runtime.Styles.style_changed.connect(func(info): _selected.append(str(info.style)))
	runtime.Text.text_started.connect(func(info): _text_events.append(info.duplicate()))
	var adapter := ADAPTER.new()
	assert_true(adapter.bind_runtime(runtime).get("ok", false))
	_original_bridge = get_node("/root/DialogicBridge")
	_original_bridge_index = _original_bridge.get_index()
	get_tree().root.remove_child(_original_bridge)
	bridge = BRIDGE.new()
	bridge.name = "DialogicBridge"
	get_tree().root.add_child(bridge)
	assert_true(bridge.initialize(null, adapter).get("ok", false))
	completion = Completion.new()
	assert_true(bridge.configure_playback_completion_port(completion).get("ok", false))

func after_each() -> void:
	Input.emulate_mouse_from_touch = _mouse_from_touch
	get_tree().root.size = _root_size
	get_tree().root.content_scale_size = _root_content_size
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	bridge.free()
	await runtime.clear()
	var remaining: Node = runtime.Styles.get_layout_node()
	if is_instance_valid(remaining): remaining.queue_free()
	await get_tree().process_frame
	runtime.free()
	if _replaced_timeline != null:
		var source := FileAccess.open(_replaced_timeline_path, FileAccess.WRITE)
		assert_not_null(source, "fixture source is restored after real DTL playback")
		if source != null:
			source.store_buffer(_replaced_timeline_source)
			source.close()
			assert_true(FileAccess.get_file_as_bytes(_replaced_timeline_path) == _replaced_timeline_source,
				"fixture restores every original DTL byte")
		_replaced_timeline.take_over_path(_replaced_timeline_path)
		_replaced_timeline = null
		_replaced_timeline_path = ""
		_replaced_timeline_source = PackedByteArray()
	get_tree().root.add_child(_original_bridge)
	get_tree().root.move_child(_original_bridge, _original_bridge_index)
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

func _frozen_pre_presentation() -> Dictionary:
	return preload("res://scripts/narrative/FrozenPresentationContext.gd").build(DATING, {
		"entry_id": DATING, "entry_role": "solo_pre_challenge", "day": 1,
		"friend_id": "priscilla", "tier": "friend", "tone": "sweet", "attitude": "",
		"run_id": "fixture:run", "branch_id": "fixture:branch",
		"challenge_slot": "dating.solo.priscilla.day1", "phase": "pre_challenge",
		"due_echoes": [], "attempt_residue_id": null}).value

func _frozen_post_context(result: String = "cleared", entry_id: String = "dating.solo.priscilla.day1.post_challenge") -> Dictionary:
	var fields: Dictionary = _frozen_pre_presentation().fields.duplicate(true)
	fields.merge({"entry_id": entry_id, "entry_role": "solo_post_challenge", "phase": "post_challenge",
		"attempt_id": "fixture:attempt", "board_result": result,
		"perfect_reasons": ["no_flag"] if result == "perfect" else [],
		"relationship_outcome": "hatred" if result == "exploded" else ("foresight" if result == "perfect" else "loved"),
		"effect_receipt_id": "fixture:committed-effect"}, true)
	if not entry_id.begins_with("dating.solo."):
		fields = {"entry_id": entry_id, "entry_role": "pair_post_challenge_scene", "day": 2,
			"run_id": "fixture:run", "branch_id": "fixture:branch", "attempt_id": "fixture:attempt",
			"pair_id": "priscilla_lavinia", "window_day": 2, "phase": "post_challenge",
			"encounter_presentation": "group" if entry_id.begins_with("dating.group.") else "twofriends_if_deferred",
			"group_variation": null, "pair_count_receipt": null, "pair_count_status": "pending_rollover",
			"stable_deck_state": preload("res://scripts/domain/relationship/PairDeckDraw.gd").build_draw([], 0).value,
			"attempt_residue_id": null, "board_result": result,
			"perfect_reasons": ["no_flag"] if result == "perfect" else [],
			"observation_form": "truncated" if result == "exploded" else "full",
			"combination_witness_capability": result != "exploded"}
	var frozen := preload("res://scripts/narrative/FrozenPresentationContext.gd").build(entry_id, fields)
	assert_true(frozen.ok, str(frozen))
	return {"expected_stage": "post_challenge", "playback_id": "caption-fixture:post",
		"role": "dating_phase", "transaction_id": "caption-fixture:post", "presentation": frozen.value}

func _inject_frozen_context_prose(entry_id: String = DATING, prose: String = "Tier {Frozen.tier}; tone {Frozen.tone}.") -> void:
	_inject_frozen_context_body(entry_id, "Narrator: " + prose)

func _inject_frozen_context_body(entry_id: String, body: String) -> void:
	var located: Dictionary = bridge.call("_resolve_entry_for_playback", entry_id, -1)
	assert_true(located.get("ok", false), str(located))
	var injected := runtime as CaptionRuntime
	injected.injected_path = str(located.value.path)
	_replaced_timeline_path = injected.injected_path
	_replaced_timeline = load(_replaced_timeline_path)
	_replaced_timeline_source = FileAccess.get_file_as_bytes(_replaced_timeline_path)
	var prose_source := "return\nlabel " + str(located.value.label) + "\n" + body + "\nreturn"
	# The production art-only probe reads source bytes before Dialogic starts.
	# Give it the same prose as the runtime, then restore the exact original bytes.
	var source := FileAccess.open(_replaced_timeline_path, FileAccess.WRITE)
	assert_not_null(source)
	if source == null: return
	source.store_string(prose_source)
	source.close()
	assert_false(BRIDGE.is_return_only_entry(_replaced_timeline_path, str(located.value.label)),
		"the source probe and runtime must both observe the injected prose")
	injected.injected_timeline = DialogicTimeline.new()
	injected.injected_timeline.from_text(prose_source)
	injected.injected_timeline.take_over_path(injected.injected_path)

func test_ending_frozen_prose_keeps_stable_completion_identity_across_runtime_counter_restart() -> void:
	var helper := preload("res://scripts/narrative/EndingFrozenContext.gd")
	var inputs := {"dark_mode": false, "pair_form": "", "special_variant": "full"}
	for friend: String in helper.FRIENDS:
		inputs[friend] = {"tier": "friend", "tone": "sweet", "attitude": "", "echo_ids": [], "miss_reasons": []}
	var seed: Dictionary = helper.make_seed(inputs, {"priscilla": [], "lavinia": [], "sylvia": [], "priscilla_lavinia": []}, [], "empty_done").value
	var plan := {"steps": [{"ending_id": "ending.priscilla.sweet", "role": "core"}], "playback_receipts": {}}
	_inject_frozen_context_prose("ending.priscilla.sweet", "Stored tone {Frozen.stored_tone}.")
	var receipts: Array = []
	bridge.ending_playback_finished.connect(func(_token, _ending_id, receipt): receipts.append(receipt.duplicate(true)))
	for index: int in range(2):
		# A fresh process restarts this transient counter; the admitted step ID persists.
		bridge.set("_playback_counter", 0)
		runtime.current_state_info["variables"] = {"prior_fixture": "preserved"}
		var playback_id := "saved:run:ending:%d" % index
		var frozen: Dictionary = helper.build(plan, 0, seed, playback_id).value
		var context := {"expected_stage": "PRIMARY_PENDING", "playback_id": playback_id, "role": "core", "transaction_id": "saved:transaction:%d" % index}
		var prior_text_events := _text_events.size()
		var started: Dictionary = bridge.start_ending_presentation("ending.priscilla.sweet", context, frozen.signature, frozen.presentation)
		assert_true(started.get("ok", false), str(started))
		if not started.get("ok", false): return
		frozen.presentation.fields.stored_tone = "dark"
		if not await _wait_for_published_text("Stored tone sweet.", prior_text_events): return
		var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
		assert_eq(texts.size(), 1)
		if texts.size() != 1: return
		assert_eq(texts[0].get_parsed_text(), "Stored tone sweet.")
		assert_true(runtime.current_state_info.variables.Frozen.is_read_only())
		runtime.Text.skip_text_reveal()
		await _settle()
		runtime.Inputs.input_block_timer.stop()
		runtime.Inputs.handle_input()
		for frame in 60:
			if receipts.size() == index + 1 and not runtime.Styles.has_active_layout_node(): break
			await get_tree().create_timer(0.05).timeout
		assert_eq(receipts.size(), index + 1)
		if receipts.size() != index + 1: return
		assert_eq(receipts[index].receipt_id, playback_id + ":complete")
		assert_eq(runtime.current_state_info.variables, {"prior_fixture": "preserved"})
	assert_ne(receipts[0].receipt_id, receipts[1].receipt_id)

func test_hospital_plays_exact_day_label_with_frozen_facts_and_keeps_physical_completion_owner() -> void:
	_inject_frozen_context_prose("hospital.faint.day1", "Cause {Frozen.qualifying_cause}.")
	runtime.current_state_info["variables"] = {"prior_fixture": "preserved"}
	var built := preload("res://scripts/narrative/FrozenPresentationContext.gd").build("hospital.faint.day1", {
		"entry_id": "hospital.faint.day1", "entry_role": "hospital", "day": 1, "qualifying_cause": "schedule_done",
		"accepted_record_ids": ["actual:accepted:sylvia"], "unfulfilled_record_ids": ["actual:accepted:sylvia"],
		"sylvia_eligible": true, "sylvia_witness_receipt_id": null})
	assert_true(built.ok, str(built))
	if not built.ok: return
	var context := {"kind": "hospital", "day": 1, "source_entry_ids": ["actual:schedule:sylvia"], "miss_receipt_ids": [], "presentation": built.value}
	var finished: Array = []
	bridge.timeline_finished.connect(func(id, result): finished.append({"id": id, "result": result.duplicate(true)}))
	var started: Dictionary = bridge.start_timeline_id("hospital.faint", context)
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	context.presentation.fields.qualifying_cause = "condition_hospital"
	await _settle()
	var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
	assert_eq(texts.size(), 1)
	if texts.size() != 1: return
	assert_eq(texts[0].get_parsed_text(), "Cause schedule_done.")
	assert_true(runtime.current_state_info.variables.Frozen.is_read_only())
	runtime.Text.skip_text_reveal()
	await _settle()
	runtime.Inputs.input_block_timer.stop()
	runtime.Inputs.handle_input()
	for frame in 60:
		if finished.size() == 1 and not runtime.Styles.has_active_layout_node(): break
		await get_tree().create_timer(0.05).timeout
	assert_eq(finished.size(), 1)
	if finished.size() == 1:
		assert_eq(finished[0].id, "hospital.faint")
		assert_eq(finished[0].result.context.presentation.fields.qualifying_cause, "schedule_done")
	assert_true(completion.calls.is_empty(), "Hospital retains its physical owner instead of the Dating completion port")
	assert_eq(runtime.current_state_info.variables, {"prior_fixture": "preserved"})

func test_gallery_real_dtl_reads_only_saved_signature_and_releases_frozen_variables() -> void:
	var profile: Node = preload("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	var storage := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"frozen-replay-memory", preload("res://tests/support/FakeFileOps.gd").new())
	assert_true(profile.initialize(storage).ok)
	var signature := {"entry_id": "ending.priscilla.sweet", "schema_version": 1, "fields": {
		"tier": "love", "tone": "sweet", "attitude": "affectionate", "echo_ids": [], "miss_reasons": [],
		"ending_role": "core", "ending_form": "derived_sweet", "residue": false}}
	var recorded: Dictionary = profile.record_reached_presentation(signature)
	assert_true(recorded.ok, str(recorded))
	if not recorded.ok: return
	assert_true(profile.unlock_ending("ending.priscilla.sweet", "fixture:discovery").ok)
	var replay := preload("res://scripts/application/ending/GalleryReplayOwner.gd").new()
	assert_true(replay.configure(profile, bridge).ok)
	_inject_frozen_context_prose("ending.priscilla.sweet", "Replay tone {Frozen.stored_tone}.")
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var run: Node = get_node("/root/GameState")
	var run_before: Dictionary = run.capture_restore_state().value.backup
	for outcome: String in ["completed", "cancelled"]:
		runtime.current_state_info["variables"] = {"prior_fixture": "preserved"}
		var prior_text_events := _text_events.size()
		var started: Dictionary = replay.begin(recorded.value.signature_id)
		assert_true(started.ok, str(started))
		if not started.ok: return
		if not await _wait_for_published_text("Replay tone sweet.", prior_text_events): return
		var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
		assert_eq(texts.size(), 1)
		if texts.size() != 1: return
		assert_eq(texts[0].get_parsed_text(), "Replay tone sweet.")
		assert_true(runtime.current_state_info.variables.Frozen.is_read_only())
		assert_eq(runtime.current_state_info.variables.Frozen.context_source, "reached_signature")
		for key: String in ["run_id", "attempt_id", "step_token", "prerequisite_receipt_ids"]:
			assert_false(runtime.current_state_info.variables.Frozen.has(key))
		bridge.call("_on_runtime_signal_event", {"kind": "effect_transaction", "transaction_id": "forbidden"})
		if outcome == "cancelled":
			assert_true(replay.close().ok)
		else:
			runtime.Text.skip_text_reveal()
			await _settle()
			runtime.Inputs.input_block_timer.stop()
			runtime.Inputs.handle_input()
		for frame in 60:
			if not replay.is_playing() and not runtime.Styles.has_active_layout_node(): break
			await get_tree().create_timer(0.05).timeout
		assert_false(replay.is_playing())
		assert_eq(runtime.current_state_info.variables, {"prior_fixture": "preserved"})
		assert_true(completion.calls.is_empty())
		assert_eq(profile.get_profile_snapshot(), profile_before)
		assert_eq(run.capture_restore_state().value.backup, run_before)

func test_noncanon_conditional_dtl_keeps_canonical_and_saved_signature_branches_equal() -> void:
	# NON-CANON TEST ONLY: these mechanical lines test existing selectors, not story content.
	# No new line identity, missing legacy fact, or translation format is implied.
	var branch_a := "NON-CANON TEST ONLY branch A."
	var branch_b := "NON-CANON TEST ONLY branch B."
	var shared_line := "NON-CANON TEST ONLY shared line."
	_inject_frozen_context_body("ending.priscilla.sweet",
		"# NON-CANON TEST ONLY\nif {Frozen.tier} == \"friend\":\n\t" + branch_a
		+ "\nelse:\n\t" + branch_b + "\n" + shared_line)
	var profile: Node = preload("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	var storage := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"frozen-branch-memory", preload("res://tests/support/FakeFileOps.gd").new())
	assert_true(profile.initialize(storage).ok)
	assert_true(profile.unlock_ending("ending.priscilla.sweet", "fixture:branch-discovery").ok)
	var helper := preload("res://scripts/narrative/EndingFrozenContext.gd")
	var plan := {"steps": [{"ending_id": "ending.priscilla.sweet", "role": "core"}], "playback_receipts": {}}
	var fixtures: Array[Dictionary] = []
	for tier: String in ["friend", "love"]:
		var inputs := {"dark_mode": false, "pair_form": "", "special_variant": "full"}
		for friend: String in helper.FRIENDS:
			inputs[friend] = {"tier": "friend", "tone": "sweet", "attitude": "", "echo_ids": [], "miss_reasons": []}
		inputs.priscilla.tier = tier
		var seed: Dictionary = helper.make_seed(inputs,
			{"priscilla": [], "lavinia": [], "sylvia": [], "priscilla_lavinia": []}, [], "empty_done")
		assert_true(seed.ok, str(seed))
		if not seed.ok: return
		var playback_id := "fixture:branch:" + tier
		var built: Dictionary = helper.build(plan, 0, seed.value, playback_id)
		assert_true(built.ok, str(built))
		if not built.ok: return
		var recorded: Dictionary = profile.record_reached_presentation(built.value.signature)
		assert_true(recorded.ok, str(recorded))
		if not recorded.ok: return
		fixtures.append({"tier": tier, "branch": branch_a if tier == "friend" else branch_b,
			"frozen": built.value, "signature_id": recorded.value.signature_id,
			"context": {"expected_stage": "PRIMARY_PENDING", "playback_id": playback_id,
				"role": "core", "transaction_id": playback_id + ":transaction"}})
	assert_ne(fixtures[0].signature_id, fixtures[1].signature_id)
	var replay := preload("res://scripts/application/ending/GalleryReplayOwner.gd").new()
	assert_true(replay.configure(profile, bridge).ok)
	var receipts: Array = []
	bridge.ending_playback_finished.connect(func(_token, _ending_id, receipt): receipts.append(receipt.duplicate(true)))
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var run: Node = get_node("/root/GameState")
	var run_before: Dictionary = run.capture_restore_state().value.backup
	for fixture: Dictionary in fixtures:
		for mode: String in ["canonical", "gallery"]:
			runtime.current_state_info["variables"] = {"prior_fixture": "preserved"}
			var prior_events := _text_events.size()
			var started: Dictionary = bridge.start_ending_presentation("ending.priscilla.sweet",
				fixture.context, fixture.frozen.signature, fixture.frozen.presentation) if mode == "canonical" \
				else replay.begin(fixture.signature_id)
			assert_true(started.ok, str(started))
			if not started.ok: return
			var expected_lines: Array[String] = [str(fixture.branch), shared_line]
			for index: int in range(expected_lines.size()):
				if not await _wait_for_published_text(expected_lines[index], prior_events + index): return
				assert_eq(runtime.current_state_info.variables.Frozen.tier, fixture.tier)
				assert_true(runtime.current_state_info.variables.Frozen.is_read_only())
				runtime.Text.skip_text_reveal()
				await _settle()
				runtime.Inputs.input_block_timer.stop()
				runtime.Inputs.handle_input()
			for frame in 60:
				if not bridge.has_active_playback() and not runtime.Styles.has_active_layout_node(): break
				await get_tree().create_timer(0.05).timeout
			assert_false(bridge.has_active_playback(), mode + " completes naturally")
			assert_false(replay.is_playing())
			var published: Array[String] = []
			for event: Dictionary in _text_events.slice(prior_events): published.append(str(event.text))
			assert_eq(published, expected_lines, "the unselected branch never publishes in " + mode)
			assert_eq(runtime.current_state_info.variables, {"prior_fixture": "preserved"})
			assert_true(completion.calls.is_empty())
			assert_eq(profile.get_profile_snapshot(), profile_before)
			assert_eq(run.capture_restore_state().value.backup, run_before)
	assert_eq(receipts.size(), 2, "only the two canonical plays report ending completion")

func test_frozen_context_drives_real_dtl_without_mutable_source_aliases() -> void:
	_inject_frozen_context_prose()
	runtime.current_state_info["variables"] = {"prior_fixture": "preserved"}
	var playback := _dating_playback()
	var command := _dating_command()
	var presentation := _frozen_pre_presentation()
	var started: Dictionary = playback.begin_phase(command, "pre_challenge", false, presentation)
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	presentation.fields.tier = "love"
	presentation.fields.tone = "dark"
	presentation.fields.due_echoes.append({"echo_id": "not a registered echo"})
	await _settle()
	var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
	assert_eq(texts.size(), 1)
	if texts.size() != 1: return
	assert_eq(texts[0].get_parsed_text(), "Tier friend; tone sweet.")
	assert_true(runtime.current_state_info.variables.is_read_only(), "the namespace cannot be replaced during playback")
	assert_true(runtime.current_state_info.variables.Frozen.is_read_only())
	assert_true(runtime.current_state_info.variables.Frozen.due_echoes.is_read_only())
	assert_eq(runtime.VAR.get_variable("Frozen.tier"), "friend")
	runtime.Text.skip_text_reveal()
	await _settle()
	runtime.Inputs.input_block_timer.stop()
	runtime.Inputs.handle_input()
	await _wait_for_dating_phase(playback, command)
	assert_eq(runtime.current_state_info.variables, {"prior_fixture": "preserved"})
	assert_false(runtime.current_state_info.variables.is_read_only())

func test_full_context_start_resume_and_preflight_refuse_the_same_invalid_fields() -> void:
	var valid := {"expected_stage": "pre_challenge", "playback_id": "frozen-fixture",
		"role": "dating_phase", "transaction_id": "frozen-fixture", "presentation": _frozen_pre_presentation()}
	var prior: Dictionary = runtime.current_state_info.variables.duplicate(true)
	for changed: Dictionary in [{"day": 2}, {"friend_id": "lavinia"}, {"undeclared": true}, {"tone": "neutral"}]:
		var context := valid.duplicate(true)
		context.presentation.fields.merge(changed, true)
		var checkpoint := {"entry_id": DATING, "content_version": 1, "frozen_context": context,
			"stage": context.expected_stage, "transaction_id": context.transaction_id}
		var start: Dictionary = bridge.start_entry(DATING, context)
		var prepare: Dictionary = bridge.validate_resume_checkpoint(checkpoint)
		var resume: Dictionary = bridge.resume_entry(checkpoint)
		assert_false(start.get("ok", false), str(changed))
		assert_eq(prepare.get("code"), start.get("code"))
		assert_eq(resume.get("code"), start.get("code"))
		assert_false(bridge.has_active_playback())
		assert_eq(runtime.current_state_info.variables, prior, "rejected contexts leave the live variable tree intact")
		assert_true(_text_events.is_empty())

func test_saved_full_context_resumes_real_prose_and_abort_restores_variables() -> void:
	_inject_frozen_context_prose()
	runtime.current_state_info["variables"] = {"prior_fixture": "preserved"}
	var context := {"expected_stage": "pre_challenge", "playback_id": "frozen-resume",
		"role": "dating_phase", "transaction_id": "frozen-resume", "presentation": _frozen_pre_presentation()}
	var checkpoint := {"entry_id": DATING, "content_version": 1, "frozen_context": context,
		"stage": context.expected_stage, "transaction_id": context.transaction_id}
	var validated: Dictionary = bridge.validate_resume_checkpoint(checkpoint)
	assert_true(validated.get("ok", false), str(validated))
	var resumed: Dictionary = bridge.resume_entry(checkpoint)
	assert_true(resumed.get("ok", false), str(resumed))
	if not resumed.get("ok", false): return
	assert_eq(resumed.receipt.context_fingerprint, validated.value.context_fingerprint)
	context.presentation.fields.tier = "love"
	await _settle()
	var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
	assert_eq(texts.size(), 1)
	if texts.size() == 1: assert_eq(texts[0].get_parsed_text(), "Tier friend; tone sweet.")
	assert_true(bridge.abort_current_entry(&"fixture_abort").get("ok", false))
	await _settle()
	assert_eq(runtime.current_state_info.variables, {"prior_fixture": "preserved"})
	assert_true(completion.calls.is_empty(), "abort grants no semantic completion")

func _settle() -> void:
	for frame in 4: await get_tree().process_frame

func _text_publication_diagnostic() -> Dictionary:
	var layout: Node = runtime.Styles.get_layout_node()
	var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
	return {"event_index": runtime.current_event_idx, "text_events": _text_events.size(),
		"timeline": runtime.current_timeline.resource_path if runtime.current_timeline != null else "",
		"style": layout.get_meta("style").resource_path if is_instance_valid(layout) else "",
		"animating": runtime.Animations.is_animating(), "paused": runtime.paused,
		"art_hold": bridge.get_art_hold_view() != null, "text_nodes": texts.size(),
		"text": str(texts[0].get_parsed_text()).left(200) if texts.size() == 1 else ""}

func _wait_for_published_text(expected: String, prior_events: int) -> bool:
	# The ordinary default style awaits its 0.7s textbox animation before publishing
	# text. Frame settling alone cannot admit reveal-skip or manual advance yet.
	await _settle()
	var initial := _text_publication_diagnostic()
	var started_at := Time.get_ticks_msec()
	var published := false
	for attempt in 60:
		var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
		if _text_events.size() == prior_events + 1 and texts.size() == 1 \
				and texts[0].get_parsed_text() == expected:
			published = true
			break
		await get_tree().create_timer(0.05).timeout
	var observed := _text_publication_diagnostic()
	print("DWM_DTL_TEXT_PUBLICATION " + JSON.stringify({"expected": expected, "initial": initial,
		"final": observed, "wait_ms": Time.get_ticks_msec() - started_at, "published": published}))
	assert_true(published, "fresh native text must publish before input: " + str(observed))
	assert_null(bridge.get_art_hold_view(), "authored fixture prose cannot be replaced by an artwork hold")
	return published

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
			# This entry now reads the actual frozen result; a legacy four-key
			# style fixture cannot execute its outcome predicates without that frame.
			var context := _frozen_post_context("cleared", entry_id) if phase == "post_challenge" else _context()
			var started: Dictionary = bridge.start_entry(entry_id, context)
			assert_true(started.get("ok", false), str(started))
			assert_true(STYLE in _selected, entry_id + " owns captions even without optional art")
			assert_null(bridge.get_art_hold_view(), "unavailable art cannot substitute a hold card")
			count += 1
			await _wait_for_completion(count)
			assert_eq(completion.calls[-1].entry_id, entry_id)
			assert_eq(completion.calls[-1].completion_kind, &"natural_end")
	assert_true(_text_events.is_empty(), "current authored dating stubs contain no prose")

func test_production_post_challenge_routes_each_frozen_result_to_only_its_own_label() -> void:
	var entry_id := "dating.solo.priscilla.day1.post_challenge"
	var visited: Array[String] = []
	var starts: Array[bool] = []
	var failures: Array[Dictionary] = []
	runtime.timeline_started.connect(func(): starts.append(true))
	bridge.entry_playback_failed.connect(func(_token: String, _entry: String, failure: Dictionary): failures.append(failure))
	bridge.timeline_failed.connect(func(failure: Dictionary): failures.append(failure))
	runtime.Jump.jumped_to_label.connect(func(info: Dictionary): visited.append(str(info.label)))
	var count := 0
	for result: String in ["exploded", "perfect", "cleared"]:
		visited.clear()
		var started: Dictionary = bridge.start_entry(entry_id, _frozen_post_context(result))
		assert_true(started.get("ok", false), str(started))
		if not started.get("ok", false): return
		count += 1
		await _wait_for_completion(count)
		assert_eq(visited, [entry_id, entry_id + "." + result], "native DTL follows only the supplied committed result")
		assert_eq(starts.size(), count, "same-timeline branch returns retain the one native playback generation")
		assert_true(failures.is_empty(), "local jump/return never interrupts the ordinary playback owner")
		assert_eq(completion.calls.size(), count, "each routed entry completes exactly once")
		if completion.calls.size() != count: return
		assert_eq(completion.calls[-1].completion_kind, &"natural_end")
	assert_true(_text_events.is_empty(), "routing labels defer production prose")

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

func _dating_command() -> Dictionary:
	return {"physical_token": "physical:caption-fixture", "completion_transaction_id": "transaction:caption-fixture",
		"timeline_id": DATING, "command_sha256": "caption-fixture".sha256_text(),
		"context": {"kind": "solo", "participants": ["priscilla"], "day": 1}}

func _dating_playback() -> RefCounted:
	# These tests replace the setup recorder before the first playback starts.
	bridge.set("_playback_completion_port", null)
	var playback := DATING_PLAYBACK.new()
	assert_true(playback.configure(bridge).get("ok", false))
	return playback

func _wait_for_dating_phase(playback: RefCounted, command: Dictionary) -> void:
	var result: Dictionary = {}
	for frame in 60:
		result = playback.pull_phase(command, "pre_challenge")
		if not result.get("ok", false): break
		if result.value.status == "completed" and not runtime.Styles.has_active_layout_node(): return
		await get_tree().create_timer(0.05).timeout
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("value", {}).get("status"), "completed", "the real runtime must naturally complete the semantic entry")

func _assert_dating_playing(playback: RefCounted, command: Dictionary) -> bool:
	var result: Dictionary = playback.pull_phase(command, "pre_challenge")
	assert_true(result.get("ok", false), "dating playback remains admitted: " + str(result))
	if not result.get("ok", false): return false
	assert_eq(result.value.status, "playing")
	return result.value.status == "playing"

func test_return_only_date_with_available_art_completes_without_continue_hold() -> void:
	ART._placements = {"schema_version": 1,
		"assets": {"fixture.portrait": {"path": "res://icon.svg", "size": [128, 128]}},
		"scenes": {DATING: {"background": "", "cg": "", "portraits": ["fixture.portrait"]}}}
	assert_not_null(ART.get_texture("fixture.portrait"), "art is available, so the old art-hold path would wait for Continue")
	var playback := _dating_playback()
	var command := _dating_command()
	var started: Dictionary = playback.begin_phase(command, "pre_challenge")
	assert_true(started.get("ok", false), str(started))
	assert_null(bridge.get_art_hold_view(), "empty dating prose must not manufacture a Continue screen")
	await _wait_for_dating_phase(playback, command)
	assert_null(bridge.get_art_hold_view())
	assert_true(_text_events.is_empty(), "empty authored prose grants no displayed dialogue")
	assert_false(bridge.has_active_playback())
	assert_true(playback.finish_phase(command, "pre_challenge").get("ok", false))

func test_dating_adapter_waits_for_both_real_dialogue_lines_and_natural_end() -> void:
	var located: Dictionary = bridge.call("_resolve_entry_for_playback", DATING, -1)
	assert_true(located.get("ok", false), str(located))
	if not located.get("ok", false): return
	var injected := runtime as CaptionRuntime
	injected.injected_path = str(located.value.path)
	_replaced_timeline_path = injected.injected_path
	_replaced_timeline = load(_replaced_timeline_path)
	_replaced_timeline_source = FileAccess.get_file_as_bytes(_replaced_timeline_path)
	injected.injected_timeline = DialogicTimeline.new()
	injected.injected_timeline.from_text("return\nlabel " + str(located.value.label)
		+ "\nNarrator: First dating fixture line.\nNarrator: Final dating fixture line.\nreturn")
	# The production adapter checks the admitted resource path on native start. Keep
	# that identity for injected prose, then restore the original cache in after_each.
	injected.injected_timeline.take_over_path(injected.injected_path)
	var playback := _dating_playback()
	var command := _dating_command()
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	await _settle()
	var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
	assert_eq(texts.size(), 1)
	if texts.size() != 1: return
	var caption: RichTextLabel = texts[0]
	assert_eq(caption.get_parsed_text(), "First dating fixture line.", "semantic label skips the root return")
	assert_eq(_text_events.size(), 1)
	if not _assert_dating_playing(playback, command): return
	assert_true(get_tree().get_nodes_in_group("dialogic_name_label").is_empty())
	var first_index := runtime.current_event_idx
	await _settle()
	assert_eq(runtime.current_event_idx, first_index, "frame polling cannot consume the first line")
	assert_eq(caption.get_parsed_text(), "First dating fixture line.")
	runtime.Text.skip_text_reveal()
	await _settle()
	runtime.Inputs.input_block_timer.stop()
	runtime.Inputs.handle_input()
	await _settle()
	assert_eq(caption.get_parsed_text(), "Final dating fixture line.")
	assert_eq(_text_events.size(), 2)
	if not _assert_dating_playing(playback, command): return
	assert_false(playback.finish_phase(command, "pre_challenge").get("ok", false), "displaying the final line is not completion")
	runtime.Text.skip_text_reveal()
	await _settle()
	if not _assert_dating_playing(playback, command): return
	runtime.Inputs.input_block_timer.stop()
	runtime.Inputs.handle_input()
	await _wait_for_dating_phase(playback, command)
	assert_true(playback.finish_phase(command, "pre_challenge").get("ok", false))

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

func _mount_dating_captions(current: String = "Four still revealing.") -> Dictionary:
	bridge.set("_ordinary_playback", {"timeline_id": DATING, "context": {}})
	bridge.call("_prepare_scene_art")
	var timeline := DialogicTimeline.new()
	timeline.from_text("One.\nTwo.\nThree.\n" + current)
	var layout: Node = runtime.start(timeline)
	await _settle()
	var result := {"layout": layout}
	for layer: Node in layout.get_layers():
		if layer.get_script().resource_path == LAYER: result.caption = layer
		if layer.get_script().resource_path == ART_LAYER: result.art = layer.get_node("SceneArt")
	assert_has(result, "caption")
	assert_has(result, "art")
	if not result.has("caption") or not result.has("art"): return {}
	assert_true(result.art.bind_view_preferences(_width_profile))
	for step in 3:
		runtime.Text.skip_text_reveal()
		await _settle()
		runtime.Inputs.input_block_timer.stop()
		runtime.Inputs.handle_input()
		await _settle()
	result.caption.caption_text.set_process(false)
	result.caption.set_process(false)
	return result

func _native_snapshot(caption: Node) -> Dictionary:
	return {"event": runtime.current_event_idx, "text": caption.caption_text.get_parsed_text(),
		"revealing": caption.caption_text.revealing,
		"visible": caption.caption_text.visible_characters,
		"generation": caption.caption_text.get_reveal_generation(),
		"history": runtime.History.simple_history_content.duplicate(true),
		"full_history": runtime.History.full_event_history_content.duplicate(),
		"visited": runtime.History.visited_event_history_content.duplicate(true)}

func _assert_dating_leaf(leaf: RichTextLabel, percent: int) -> void:
	assert_eq(leaf.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, str(leaf.name))
	assert_true(leaf.get_theme_stylebox(&"normal") is StyleBoxEmpty, "transparent subtitle leaf: " + str(leaf.name))
	assert_true(leaf.get_theme_stylebox(&"focus") is StyleBoxEmpty, "no focus rectangle: " + str(leaf.name))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(leaf.get_theme_stylebox(&"normal").get_content_margin(side), 16.0)
	assert_eq(leaf.get_theme_color(&"default_color"), Color.WHITE)
	assert_eq(leaf.get_theme_constant(&"outline_size"), 2)
	var outline := leaf.get_theme_color(&"font_outline_color")
	assert_lt(outline.get_luminance(), 0.1, "readable dark outline")
	assert_gt(outline.a, 0.0)
	assert_eq(leaf.get_theme_font_size(&"normal_font_size"), int(24 * percent / 100.0))

func test_dating_subtitles_keep_all_four_labels_transparent_and_centered_at_each_text_size() -> void:
	var mounted := await _mount_dating_captions()
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	assert_true(caption.get_caption_projection().get("dating_overlay", false), "real Bridge ownership selects the overlay")
	var before := _native_snapshot(caption)
	for percent: int in [100, 125, 150]:
		assert_true(caption.configure_presentation("en", percent))
		await _settle()
		for leaf: RichTextLabel in [caption.older, caption.previous, caption.review_current, caption.caption_text]:
			_assert_dating_leaf(leaf, percent)
		var projection: Dictionary = caption.get_caption_projection()
		assert_eq(projection.caption_window, ["Two.", "Three.", "Four still revealing."])
		assert_eq(projection.visible_leaf_rects.size(), 3)
		assert_almost_eq(projection.caption_rect.end.y, caption.transport_rail.position.y, 0.01, "caption stack sits just above controls")
		for rect: Rect2 in projection.leaf_rects:
			assert_almost_eq(rect.get_center().x, 640.0, 0.01, "subtitle region is centered")
			assert_lte(rect.end.y, 656.0)
		assert_eq(_native_snapshot(caption), before, "material publication cannot change native reading")

func test_dating_art_extends_behind_subtitles_without_consuming_control_or_challenge_space() -> void:
	var view := ART_VIEW.new()
	assert_true(view.bind_view_preferences(_width_profile))
	add_child_autofree(view)
	var pixels := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	for percent: int in [100, 125, 150]:
		view.configure_entry(DATING, percent)
		assert_eq(view.size, Vector2(1280, 656), "dating entry controls art geometry without optional images")
		if not view.size.is_equal_approx(Vector2(1280, 656)): continue
		view.configure_textures(texture, [texture, texture], null, percent, false, true)
		assert_true(view.visible)
		assert_true(view.clip_contents)
		for control: Control in [view, view._background, view._portraits[0], view._portraits[1], view._cg]:
			assert_eq(control.size.y, 656.0)
			assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
			assert_eq(control.focus_mode, Control.FOCUS_NONE)
		view.configure_entry("hospital.faint", percent)
		assert_eq(view.size.y, float(ART_VIEW.APERTURE_HEIGHT[percent]), "Hospital keeps its existing art aperture")
		view.configure_textures(texture, [texture], null, percent, true, true)
		assert_eq(view.size, Vector2(1280, 720), "challenge retains its full worksheet space")
		assert_eq(view._portraits[0].size.y, 720.0, "challenge portrait retains full panel height")
		assert_eq(view.get_right_rect(), Rect2(view.get_portrait_width(), 0, 1280 - view.get_portrait_width(), 720))

func test_long_dating_caption_stays_centered_and_scrollable_with_both_scrollbar_sizes() -> void:
	var mounted := await _mount_dating_captions("A long dating caption remains centered while scrolling. ".repeat(160))
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	var before := _native_snapshot(caption)
	for large_targets: bool in [false, true]:
		assert_true(caption.configure_presentation("en", 150, "AfterHours", false, "standard", large_targets))
		await _settle()
		var bar: VScrollBar = caption.get_scroll_bar()
		assert_true(bar.visible, "long text uses the actual native scrollbar")
		assert_eq(bar.size.x, 64.0 if large_targets else 48.0)
		var projection: Dictionary = caption.get_caption_projection()
		assert_gt(projection.scroll_extent, 0.0)
		for rect: Rect2 in projection.leaf_rects:
			assert_almost_eq(rect.get_center().x, 640.0, 0.01, "native right scrollbar cannot shift dating text left")
			assert_gte(rect.position.x, 16.0)
			assert_lte(rect.end.x, 1264.0)
		bar.value = projection.scroll_extent
		await _settle()
		projection = caption.get_caption_projection()
		assert_almost_eq(projection.caption_rect.end.y, 656.0, 0.01, "the final words remain reachable above controls")
		assert_gt(projection.visible_leaf_rects.size(), 0)
		for rect: Rect2 in projection.visible_leaf_rects:
			assert_true(projection.field_rect.encloses(rect))
		bar.value = 0
		await _settle()
		assert_eq(bar.value, 0.0, "scrolling back reaches the start of the three-caption window")
		assert_eq(_native_snapshot(caption), before, "layout and manual scrolling preserve reveal and narrative history")

func test_dating_review_and_hospital_scope_reset_preserve_native_text_and_history() -> void:
	var mounted := await _mount_dating_captions()
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	var native: Node = caption.caption_text
	var before := _native_snapshot(caption)
	caption.call("_set_review_offset", 1)
	await _settle()
	assert_eq(caption.get_caption_projection().caption_window, ["One.", "Two.", "Three."])
	assert_false(native.visible)
	_assert_dating_leaf(caption.review_current, 100)
	assert_eq(_native_snapshot(caption), before, "review remains a projection of already-seen text")
	assert_false(caption.call("_before_normal_accept"), "first accept returns to live without advancing")
	native.set_process(false)
	assert_eq(caption.get_caption_projection().review_offset, 0)
	assert_eq(caption.caption_text, native)
	assert_eq(_native_snapshot(caption), before)

	# The reused layout must reset from the same authoritative scene-art publication.
	bridge.set("_ordinary_playback", {"timeline_id": "hospital.faint", "context": {}})
	bridge.scene_art_changed.emit()
	await _settle()
	assert_false(caption.get_caption_projection().get("dating_overlay", true))
	for leaf: RichTextLabel in [caption.older, caption.previous, caption.review_current, caption.caption_text]:
		assert_eq(leaf.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
		assert_true(leaf.get_theme_stylebox(&"normal") is StyleBoxFlat)
		assert_eq(leaf.get_theme_constant(&"outline_size"), 0)
	assert_eq(mounted.art.size, Vector2(1280, 448))
	assert_eq(_native_snapshot(caption), before, "scope changes do not replay or advance text")
	bridge.set("_ordinary_playback", {"timeline_id": DATING, "context": {}})
	bridge.scene_art_changed.emit()
	await _settle()
	assert_true(caption.get_caption_projection().get("dating_overlay", false))
	assert_eq(mounted.art.size, Vector2(1280, 656))
	_assert_dating_leaf(native, 100)
	assert_eq(_native_snapshot(caption), before)

func _mount_root_split_fixture() -> Dictionary:
	var mounted := await _mount_dating_captions("Four still revealing.\nFollowing guard caption.")
	if mounted.is_empty(): return {}
	if mounted.layout.get_parent() != get_tree().root: mounted.layout.reparent(get_tree().root)
	mounted.layout.layer = 129 # Real input above GUT's own CanvasLayer128.
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	var pixels := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	var portraits: Array[Texture2D] = [texture, texture]
	mounted.art.configure_textures(texture, portraits, null, 100, false, true)
	mounted.art.set_portrait_width(480)
	mounted.caption.configure_dating_overlay(true)
	mounted.caption.call("_sync_transport")
	mounted.caption.caption_text.grab_focus()
	runtime.Inputs.input_block_timer.stop()
	await _settle()
	return mounted

func _root_control_point(control: Control, point: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * (control.get_global_transform_with_canvas() * point)

func _split_mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _split_touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _split_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func test_dating_split_mouse_commits_on_release_without_advancing_caption() -> void:
	var mounted := await _mount_root_split_fixture()
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	var art: Control = mounted.art
	var handle: Control = art.get_split_handle()
	assert_same(caption.get("_dating_split_surface"), art, "caption binds its sibling art layer")
	assert_true(caption.is_dating_split_input_admitted())
	var before := _native_snapshot(caption)
	var point := _root_control_point(handle, handle.size * 0.5)
	_split_mouse(point, true)
	assert_true(art.is_split_dragging(), "background input forwards grip press")
	_split_key(KEY_ENTER, true)
	_split_key(KEY_ENTER, false)
	assert_true(art.is_split_dragging(), "secondary Accept cannot interrupt divider ownership")
	assert_eq(_native_snapshot(caption), before, "Enter during a drag cannot accept dialogue")
	var motion := InputEventMouseMotion.new()
	motion.position = point + Vector2(72, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(72, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	assert_eq(art.get_portrait_width(), 480.0, "drag only previews its boundary")
	_split_mouse(motion.position, false)
	await _settle()
	assert_false(art.is_split_dragging())
	assert_true(get_node("/root/InputManager").get_physical_contacts().is_empty(), "consumed mouse and secondary key releases leave no held contacts")
	assert_eq(art.get_portrait_width(), 552.0)
	assert_eq(_width_profile.writes, [{"path": &"preferences.display.dating_group_portrait_width", "value": 552}])
	assert_eq(_native_snapshot(caption), before, "divider cannot reveal, advance, or write history")
	for rect: Rect2 in caption.get_caption_projection().leaf_rects:
		assert_almost_eq(rect.get_center().x, 640.0, 0.01, "captions stay centered across both panels")
	# Crossing only four pixels onto the grip must not turn a background press
	# into an accepted caption release, even below the ordinary drag threshold.
	_split_mouse(_root_control_point(handle, Vector2(-2, 32)), true)
	_split_mouse(_root_control_point(handle, Vector2(2, 32)), false)
	await _settle()
	assert_eq(_native_snapshot(caption), before, "release belongs to the grip hit area")
	var background_point := _root_control_point(caption.background_input, Vector2(900, 200))
	_split_mouse(background_point, true)
	_split_mouse(background_point, false)
	await _settle()
	assert_false(caption.caption_text.revealing, "a later ordinary scene click still finishes reveal")
	assert_eq(runtime.current_event_idx, before.event, "one click never also advances")
	assert_eq(runtime.History.simple_history_content, before.history)

func test_dating_split_touch_keyboard_and_reading_custody_preserve_native_text() -> void:
	var foreign_art := ART_VIEW.new()
	add_child_autofree(foreign_art)
	foreign_art.configure_entry(DATING)
	var mounted := await _mount_root_split_fixture()
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	var art: Control = mounted.art
	var handle: Control = art.get_split_handle()
	assert_same(caption.get("_dating_split_surface"), art, "another scene's earlier art surface cannot acquire caption custody")
	var before := _native_snapshot(caption)
	Input.emulate_mouse_from_touch = true
	var point := _root_control_point(handle, handle.size * 0.5)
	_split_touch(point, true)
	assert_true(art.is_split_dragging())
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point - Vector2(64, 0)
	drag.relative = Vector2(-64, 0)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	assert_eq(art.get_portrait_width(), 480.0)
	_split_touch(drag.position, false)
	await _settle()
	assert_true(get_node("/root/InputManager").get_physical_contacts().is_empty(), "consumed touch release leaves no held contacts")
	assert_eq(art.get_portrait_width(), 416.0, "real touch and its emulated mouse commit once")
	assert_eq(_native_snapshot(caption), before)
	caption.call("_sync_transport")
	assert_same(caption.caption_text.get_node(caption.caption_text.focus_next), handle, "divider participates in caption focus order")
	handle.grab_focus()
	_split_key(KEY_RIGHT, true)
	_split_key(KEY_RIGHT, false)
	await _settle()
	assert_eq(art.get_portrait_width(), 432.0, "keyboard adjusts the focused divider")
	assert_eq(_width_profile.writes.size(), 2, "touch and keyboard each save once without emulation duplicates")
	assert_eq(_width_profile.values[&"preferences.display.dating_group_portrait_width"], 432)
	assert_eq(_native_snapshot(caption), before)
	point = _root_control_point(handle, handle.size * 0.5)
	_split_touch(point, true)
	assert_true(art.is_split_dragging())
	caption.set("_load_pending", true)
	await _settle()
	assert_false(art.is_split_dragging(), "losing reading custody retires an unfinished drag")
	_split_touch(point - Vector2(48, 0), false)
	caption.set("_load_pending", false)
	await _settle()
	assert_eq(art.get_portrait_width(), 432.0, "late release cannot commit after custody returns")
	assert_eq(_native_snapshot(caption), before)
	handle.grab_focus()
	var captured: Dictionary = caption.capture_pause_view({"fixture": "dating-split"})
	assert_true(captured.get("ok", false))
	if not captured.get("ok", false): return
	assert_true(caption.cover_pause_view(captured.value))
	await _settle()
	assert_eq(handle.focus_mode, Control.FOCUS_NONE, "covered captions also withdraw the sibling divider")
	assert_true(caption.restore_pause_view(captured.value))
	await _settle()
	assert_same(get_viewport().gui_get_focus_owner(), handle, "uncover restores keyboard focus to the divider")
	assert_eq(_native_snapshot(caption), before)
