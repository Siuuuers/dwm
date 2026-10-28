extends "res://tests/integration/scene_partner_fork_child.gd"
const MULTIPLE := preload("res://tests/support/SceneMultipleThoughtFixture.gd")

func _install_content_registration() -> Dictionary:
	return MULTIPLE.install()

func create_multiple_thoughts() -> void:
	if not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	var started: Dictionary = saves.start_scene_new_run("partner.shared", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if not await _await_ready() or not await _wait_line("line.scene.test.partner.shared.before"): return
	await _accept()
	if not await _wait_line(OFFER) or not await _save_partner(1): return
	for frame: int in 12: await get_tree().process_frame
	var host: Control = get_tree().current_scene
	var column: HBoxContainer = host.get_node("SceneControlsLayer/Surface/ThoughtOptions/Options")
	assert_eq(column.get_child_count(), 2)
	assert_false(host.get_node("SceneControlsLayer/Surface/ThoughtYes").visible)
	if column.get_child_count() != 2: return
	assert_eq(column.get_child(0).text, "Choose the first continuation.")
	assert_eq(column.get_child(1).text, "Choose the second continuation.")
	var stale: Dictionary = bridge.capture_current_line_presentation_frontier()
	assert_false(game.accept_scene_thought(stale, "missing").ok)
	assert_true(game.scene_choices.is_empty())
	assert_eq(game.scene_choices, {}, "invalid selection does not choose an option")
	await _screenshot("multiple-thought-offer")
	var original: RefCounted = saves._storage._file_ops
	var refusal = WRITE_REFUSAL.WriteRefusal.new()
	refusal.refuse_on = 1
	var autosave_before: Dictionary = saves._storage.read_text("autosave.json")
	var manual_before := FileAccess.get_sha256("user://saves/slot_1.json")
	saves._storage._file_ops = refusal
	column.get_child(1).grab_focus()
	for frame: int in 3: await get_tree().process_frame
	await _click(column.get_child(1))
	if not await _wait_line("line.scene.test.partner.lavinia.after"):
		saves._storage._file_ops = original
		return
	assert_eq(refusal.refused, 0, "ordinary choice never attempts an automatic save")
	assert_eq(saves._storage.read_text("autosave.json"), autosave_before)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), manual_before)
	saves._storage._file_ops = original
	var changed: Dictionary = game.accept_scene_thought(stale, "first")
	assert_false(changed.get("ok", false), "stale offer cannot replace the published choice")
	assert_eq(game.scene_choices, {"TEST.partner": "second"})
	assert_eq(game.scene_choices.size(), 1)
	assert_eq(game.scene_choices["TEST.partner"], "second")
	assert_eq(game.capture_run_snapshot_input().scene.entry_id, "scene.test.partner.lavinia")
	assert_eq(game.scene_choices, {"TEST.partner": "second"})
	var detached: Dictionary = game.capture_run_snapshot_input()
	detached.gameplay.scene_choices["TEST.partner"] = "first"
	assert_eq(game.scene_choices["TEST.partner"], "second", "snapshot callers cannot mutate live choices")
	assert_false(game.accept_scene_thought(stale, "first").ok)
	if not await _save_partner(2): return
	_write_json("user://multiple-thought-proof.json", {"pid": OS.get_process_id(), "choices": game.scene_choices.duplicate(true),
		"unresolved": FileAccess.get_sha256("user://saves/slot_1.json"), "resolved": FileAccess.get_sha256("user://saves/slot_2.json")})

func load_multiple_thoughts() -> void:
	var proof: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://multiple-thought-proof.json"))
	if not _ok(proof): return
	assert_ne(OS.get_process_id(), proof.value.pid)
	if not _start_services() or not await _load_partner(2, true): return
	if not await _wait_line("line.scene.test.partner.lavinia.after"): return
	assert_eq(game.scene_choices.size(), 1)
	assert_eq(game.scene_choices, proof.value.choices, "fresh process retains exact selected option")
	assert_eq(game.scene_choices, {"TEST.partner": "second"}, "fresh Load restores explicit chosen branch")
	var stale: Dictionary = bridge.capture_current_line_presentation_frontier()
	if not await _load_partner(1) or not await _wait_line(OFFER): return
	assert_true(game.scene_choices.is_empty(), "selected earlier save restores unresolved opportunity")
	assert_eq(game.scene_choices, {}, "earlier save restores unresolved choice state")
	assert_false(game.accept_scene_thought(stale, "first").ok)
	await _accept()
	if not await _wait_line("line.scene.test.partner.benchmark.after"): return
	assert_eq(game.scene_choices.size(), 1)
	assert_eq(game.scene_choices["TEST.partner"], "pass")
	assert_eq(game.capture_run_snapshot_input().scene.entry_id, "scene.test.partner.benchmark")
	assert_eq(game.scene_choices, {"TEST.partner": "pass"}, "ordinary continuation explicitly records pass")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.value.unresolved)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.value.resolved)
