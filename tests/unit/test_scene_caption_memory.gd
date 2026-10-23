extends "res://tests/unit/test_scene_publication_cursor.gd"
## Existing registered loop exercises full memory and re-entry without native replay.

func test_memory_is_current_occurrence_only_and_projection_is_pure() -> void:
	var session := _session()
	if session == null: return
	var frontier: Dictionary = FIXTURE.frontier(session)
	for index: int in 4:
		frontier = _publish(session, "line.scene.test.a.two")
		assert_true(session.accept_scene_publication(1, frontier).ok)
	var before: Dictionary = session.capture(frontier).value
	var memory: Dictionary = session.project_scene_caption_memory(frontier)
	assert_true(memory.ok, str(memory))
	if not memory.ok: return
	assert_eq(memory.value.captions.size(), 5, "all older scrollback is retained")
	assert_eq(memory.value.occurrence_id, session.scene_occurrence)
	assert_eq(memory.value.captions.back().publication_id, frontier.publication_id)
	assert_eq(session.project_scene_caption_memory(frontier), memory, "repeat is idempotent")
	assert_eq(session.capture(frontier).value, before, "projection has no state/history effects")
	var old := frontier.duplicate(true)
	assert_true(FIXTURE.enter(session, FIXTURE.A, "TEST.cursor.reentry").ok)
	frontier = FIXTURE.frontier(session)
	memory = session.project_scene_caption_memory(frontier)
	assert_true(memory.ok, str(memory))
	if not memory.ok: return
	assert_eq(memory.value.captions.size(), 1, "same entry is a new occurrence")
	assert_eq(session.project(frontier).value.captions.size(), 6, "full History still includes prior occurrence")
	assert_eq(memory.value.occurrence_id, "TEST.cursor.reentry")
	assert_false(session.project_scene_caption_memory(old).ok, "old publication cannot project over current occurrence")
	var stable: Dictionary = session.capture(frontier).value
	memory.value.captions.clear()
	assert_eq(session.project_scene_caption_memory(frontier).value.captions.size(), 1, "caller cannot mutate owner")
	assert_eq(session.capture(frontier).value, stable)
