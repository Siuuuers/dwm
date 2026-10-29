extends "res://addons/gut/test.gd"
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")

class NativeHandler extends Node:
	var current_event_idx := 0
	var Inputs := {"auto_skip": {"enabled": false}}

class BoundAdapter extends DialogicRuntimeAdapter:
	func _caption_source_is_current() -> bool:
		return true
	func _prepare_scene_native_mappings() -> void:
		pass

class DeferredEvent extends DialogicEvent:
	var observations: Array
	func _execute() -> void:
		observations.append("caption")

func _compile(body: String, markers: Array = []) -> Dictionary:
	return ADAPTER._compile_scene_programme_source("label fixture\n" + body, "fixture", ["fixture"], markers)

func test_cues_keep_caption_positions_and_authored_order() -> void:
	var result := _compile("# audio music quiet_room fade=0.4\n# audio sfx door_knock\nCaption. #id:fixture.a\n# audio music stop\nreturn\n")
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.nodes.size(), 2)
	assert_eq(result.value.nodes[0].next, 1)
	assert_eq(result.value.nodes[0].audio_cues, [
		{"kind": "music", "id": "quiet_room", "fade_seconds": 0.4},
		{"kind": "sfx", "id": "door_knock", "fade_seconds": 0.0}])
	assert_eq(result.value.nodes[1].audio_cues, [{"kind": "music", "id": "", "fade_seconds": 0.0}])
	assert_eq(result.value.events.filter(func(row: Dictionary) -> bool: return row.kind == "text").size(), 1,
		"audio never becomes a caption or History line")

func test_changed_cue_changes_programme_hash_without_new_caption() -> void:
	var body := "# audio music quiet_room fade=0.4\nCaption. #id:fixture.a\nreturn\n"
	var first := _compile(body)
	var changed := _compile(body.replace("0.4", "0.8"))
	assert_true(first.ok)
	assert_true(changed.ok)
	if first.ok and changed.ok:
		assert_ne(first.value.program_sha256, changed.value.program_sha256)
		assert_eq(first.value.nodes[0].line_id, changed.value.nodes[0].line_id)

func test_ordinary_comments_remain_nonexecuting() -> void:
	var body := "Caption. #id:fixture.a\nreturn\n"
	var plain := _compile(body)
	var commented := _compile("# audiofile editing note\n# an ordinary comment\n" + body)
	assert_true(plain.ok)
	assert_true(commented.ok)
	if plain.ok and commented.ok:
		assert_eq(plain.value.nodes, commented.value.nodes)
		assert_eq(plain.value.program_sha256, commented.value.program_sha256)

func test_authoring_typos_in_reserved_audio_commands_are_rejected() -> void:
	for command: String in ["audio", "audio music", "audio voice hello", "audio sfx stop",
		"audio music quiet_room fade=-1", "audio music quiet_room fade=nan",
		"audio music quiet_room fade=infinity", "audio music quiet_room fade=",
		"audio music quiet_room volume=1", "audio music quiet_room fade=0 fade=1",
		"audio sfx door_knock fade=1", "audio music bad/id"]:
		var result := _compile("# " + command + "\nCaption. #id:fixture.a\nreturn\n")
		assert_false(result.ok, command)
		assert_eq(result.code, &"scene_audio_invalid", command)

func test_cue_before_pair_preserves_simultaneous_self_talk() -> void:
	var result := _compile("# audio sfx door_knock\nCaption. #id:fixture.a\n# self-talk\nThought. #id:fixture.thought\nreturn\n")
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.nodes.size(), 2)
	assert_eq(result.value.nodes[0].self_talk.line_id, "fixture.thought")
	assert_eq(result.value.nodes[0].audio_cues[0].id, "door_knock")

func test_cue_inside_pair_is_an_authoring_error() -> void:
	for middle: String in ["# audio sfx knock\n# self-talk\n", "# self-talk\n# audio sfx knock\n"]:
		var result := _compile("Caption. #id:fixture.a\n" + middle + "Thought. #id:fixture.thought\nreturn\n")
		assert_false(result.ok)
		assert_eq(result.code, &"scene_audio_splits_self_talk")

func test_branch_cues_belong_to_jump_or_after_destination_label() -> void:
	var result := _compile("Caption. #id:fixture.a\n# audio music departure\njump destination\nlabel destination\n# audio sfx arrival\nArrival. #id:fixture.b\nreturn\n")
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.nodes[1].kind, "jump")
	assert_eq(result.value.nodes[1].audio_cues[0].id, "departure")
	assert_eq(result.value.label_nodes.destination, 2)
	assert_eq(result.value.nodes[2].audio_cues[0].id, "arrival")

func test_cues_cannot_leak_across_labels_or_end_of_entry() -> void:
	var label := _compile("Caption. #id:fixture.a\n# audio sfx knock\nlabel destination\nNext. #id:fixture.b\nreturn\n")
	assert_false(label.ok)
	assert_eq(label.code, &"scene_audio_before_label")
	var trailing := _compile("Caption. #id:fixture.a\nreturn\n# audio sfx knock\n")
	assert_false(trailing.ok)
	assert_eq(trailing.code, &"scene_audio_without_position")

func test_registered_control_owns_cue_after_label_without_new_frontier() -> void:
	var marker := {"label": "fixture.end", "marker_id": "fixture.control", "kind": "scene.transition"}
	var result := _compile("Caption. #id:fixture.a\nlabel fixture.end\n# audio music stop fade=0.3\n[signal arg=\"scene.transition\"]\nreturn\n", [marker])
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.nodes[1].kind, "control")
	assert_eq(result.value.nodes[1].marker_id, "fixture.control")
	assert_eq(result.value.nodes[1].audio_cues, [{"kind": "music", "id": "", "fade_seconds": 0.3}])

func test_native_dispatch_precedes_deferred_event_and_repeat_encounter_replays() -> void:
	var handler := NativeHandler.new()
	add_child_autofree(handler)
	var adapter := BoundAdapter.new()
	adapter._dialogic = handler
	adapter._scene_caption_occurrence = "fixture.occurrence"
	adapter._scene_native_audio = {0: [{"kind": "sfx", "id": "knock", "fade_seconds": 0.0}]}
	var observations: Array = []
	adapter.scene_audio_cues_requested.connect(func(_cues: Array, _suppressed: bool) -> void: observations.append("sound"))
	var event := DeferredEvent.new()
	event.observations = observations
	# This is the installed Dialogic handler's actual execute/notification order.
	event.execute(null)
	adapter._on_event_handled(event)
	assert_eq(observations, ["sound"])
	await get_tree().process_frame
	assert_eq(observations, ["sound", "caption"])
	adapter._on_event_handled(event)
	assert_eq(observations, ["sound", "caption", "sound"], "later encounters are not permanently consumed")

func test_skip_consumes_sfx_flag_and_load_or_seek_do_not_dispatch() -> void:
	var handler := NativeHandler.new()
	add_child_autofree(handler)
	var adapter := BoundAdapter.new()
	adapter._dialogic = handler
	adapter._scene_caption_occurrence = "fixture.occurrence"
	adapter._scene_native_audio = {0: [{"kind": "sfx", "id": "knock", "fade_seconds": 0.0}]}
	var suppressions: Array = []
	adapter.scene_audio_cues_requested.connect(func(_cues: Array, suppressed: bool) -> void: suppressions.append(suppressed))
	handler.Inputs.auto_skip.enabled = true
	adapter._on_event_handled(null)
	handler.Inputs.auto_skip.enabled = false
	assert_eq(suppressions, [true], "leaving Skip does not flush any queued cue")
	adapter._caption_restore_frontier = {"line_id": "fixture.a"}
	adapter._on_event_handled(null)
	adapter._caption_restore_frontier = {}
	adapter._caption_seek_result = {"ok": true}
	adapter._on_event_handled(null)
	assert_eq(suppressions, [true], "staged Load and Next never replay their destination effects")
	adapter._caption_seek_result = {}
	adapter._on_event_handled(null)
	assert_eq(suppressions, [true, false], "ordinary later reading admits sound again")
