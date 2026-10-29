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

func test_art_and_checkpoint_commands_preserve_reading_units_and_order() -> void:
	var result := _compile("# art background room\n# art show neutral slot=portrait\n# checkpoint arrival\nCaption. #id:fixture.a\n# self-talk\nThought. #id:fixture.thought\n# art hide portrait\nNext. #id:fixture.b\nreturn\n")
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.nodes.size(), 3)
	assert_eq(result.value.nodes[0].line_id, "fixture.a")
	assert_eq(result.value.nodes[0].self_talk.line_id, "fixture.thought")
	assert_eq(result.value.nodes[0].presentation_commands, [
		{"kind": "background", "id": "room"},
		{"kind": "show", "id": "neutral", "slot": "portrait"},
		{"kind": "checkpoint", "id": "arrival"}])
	assert_eq(result.value.nodes[1].presentation_commands, [{"kind": "hide", "slot": "portrait"}])
	assert_eq(result.value.events.filter(func(row: Dictionary) -> bool: return row.kind == "text").size(), 3)

func test_art_changes_programme_identity_without_changing_line_identity() -> void:
	var first := _compile("# art background room\nCaption. #id:fixture.a\nreturn\n")
	var second := _compile("# art background hall\nCaption. #id:fixture.a\nreturn\n")
	assert_true(first.ok, str(first))
	assert_true(second.ok, str(second))
	if not first.ok or not second.ok: return
	assert_ne(first.value.program_sha256, second.value.program_sha256)
	assert_eq(first.value.nodes[0].line_id, second.value.nodes[0].line_id)

func test_ordinary_art_notes_do_not_become_commands() -> void:
	var plain := _compile("Caption. #id:fixture.a\nreturn\n")
	var notes := _compile("# artwork editing note\n# checkpoints reviewed yesterday\nCaption. #id:fixture.a\nreturn\n")
	assert_true(notes.ok, str(notes))
	if notes.ok and plain.ok:
		assert_eq(notes.value.nodes, plain.value.nodes)
		assert_eq(notes.value.program_sha256, plain.value.program_sha256)

func test_reserved_command_typos_are_reported() -> void:
	for command: String in ["art", "art background", "art background room extra", "art fade room",
		"art show portrait", "art show portrait slot=", "art show portrait wrong=left",
		"art hide", "art hide portrait extra", "checkpoint", "checkpoint arrival extra"]:
		var result := _compile("# " + command + "\nCaption. #id:fixture.a\nreturn\n")
		assert_false(result.ok, command)

func test_art_cannot_split_caption_and_self_talk() -> void:
	for middle: String in ["# art hide portrait\n# self-talk\n", "# self-talk\n# art hide portrait\n"]:
		var result := _compile("Caption. #id:fixture.a\n" + middle + "Thought. #id:fixture.thought\nreturn\n")
		assert_false(result.ok, middle)

func test_commands_stay_on_reached_side_of_branch_label() -> void:
	var result := _compile("Caption. #id:fixture.a\njump destination\nlabel destination\n# art background hall\nArrival. #id:fixture.b\nreturn\n")
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.label_nodes.destination, 2)
	assert_eq(result.value.nodes[2].presentation_commands, [{"kind": "background", "id": "hall"}])
	assert_false(result.value.nodes[1].has("presentation_commands"))
	var misplaced := _compile("Caption. #id:fixture.a\n# art background hall\nlabel destination\nArrival. #id:fixture.b\nreturn\n")
	assert_false(misplaced.ok, "jumping to destination would otherwise skip the command")
	var trailing := _compile("Caption. #id:fixture.a\nreturn\n# art hide portrait\n")
	assert_false(trailing.ok, "a command requires a reached reading boundary")

func test_registered_control_retains_commands_after_its_label() -> void:
	var marker := {"label": "fixture.end", "marker_id": "fixture.control", "kind": "scene.transition"}
	var result := _compile("Caption. #id:fixture.a\nlabel fixture.end\n# art hide portrait\n[signal arg=\"scene.transition\"]\nreturn\n", [marker])
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.nodes[1].kind, "control")
	assert_eq(result.value.nodes[1].presentation_commands, [{"kind": "hide", "slot": "portrait"}])

func test_checkpoint_requires_caption_boundary_for_its_autosave() -> void:
	for body: String in [
		"# checkpoint arrival\nreturn\n",
		"# checkpoint arrival\njump destination\nlabel destination\nCaption. #id:fixture.a\nreturn\n"]:
		var result := _compile(body)
		assert_false(result.ok, body)
		assert_eq(result.code, &"scene_checkpoint_requires_caption")
	var marker := {"label": "fixture.end", "marker_id": "fixture.control", "kind": "scene.transition"}
	var control := _compile("Caption. #id:fixture.a\nlabel fixture.end\n# checkpoint arrival\n[signal arg=\"scene.transition\"]\nreturn\n", [marker])
	assert_false(control.ok)
	assert_eq(control.code, &"scene_checkpoint_requires_caption")

func test_native_presentation_dispatch_precedes_caption_and_later_visits_repeat() -> void:
	var handler := NativeHandler.new()
	add_child_autofree(handler)
	var adapter := BoundAdapter.new()
	adapter._dialogic = handler
	adapter._scene_caption_occurrence = "fixture.occurrence"
	adapter._scene_native_presentation = {0: [{"kind": "background", "id": "room"}]}
	var observations: Array = []
	adapter.scene_presentation_commands_requested.connect(func(_commands: Array) -> void: observations.append("art"))
	var event := DeferredEvent.new()
	event.observations = observations
	event.execute(null)
	adapter._on_event_handled(event)
	assert_eq(observations, ["art"], "the upcoming caption cannot expose old art for a frame")
	await get_tree().process_frame
	assert_eq(observations, ["art", "caption"])
	adapter._on_event_handled(event)
	assert_eq(observations, ["art", "caption", "art"], "a repeated story visit is a new encounter")

func test_load_seek_and_staged_control_never_replay_art_but_skip_applies_it() -> void:
	var handler := NativeHandler.new()
	add_child_autofree(handler)
	var adapter := BoundAdapter.new()
	adapter._dialogic = handler
	adapter._scene_caption_occurrence = "fixture.occurrence"
	adapter._scene_native_presentation = {0: [{"kind": "hide", "slot": "portrait"}]}
	var encounters: Array = []
	adapter.scene_presentation_commands_requested.connect(func(commands: Array) -> void: encounters.append(commands.duplicate(true)))
	adapter._caption_restore_frontier = {"line_id": "fixture.a"}
	adapter._on_event_handled(null)
	adapter._caption_restore_frontier = {}
	adapter._caption_seek_result = {"ok": true}
	adapter._on_event_handled(null)
	adapter._caption_seek_result = {}
	adapter._scene_control_installing = true
	adapter._on_event_handled(null)
	assert_eq(encounters.size(), 0, "prepared state is installed directly")
	adapter._scene_control_installing = false
	handler.Inputs.auto_skip.enabled = true
	adapter._on_event_handled(null)
	assert_eq(encounters, [[{"kind": "hide", "slot": "portrait"}]], "Skip suppresses SFX, not persistent artwork")
