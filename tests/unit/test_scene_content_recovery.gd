extends "res://addons/gut/test.gd"
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const HISTORY := preload("res://scripts/narrative/SceneReadingHistory.gd")
const TRAVERSAL := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const FIXTURE := preload("res://tests/support/SceneDayReadingFixture.gd")
const SCOPE := preload("res://tests/support/SceneValidationScope.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const PATH := "res://tests/fixtures/dialogic/_content_recovery.dtl"
var _scope: RefCounted

func after_each() -> void:
	if _scope != null: _scope.restore()
	_scope = null
	DirAccess.remove_absolute(PATH)
	ADAPTER._scene_compile_cache.erase(PATH)

func _install(text: String, include_days: bool = true) -> void:
	if _scope != null: _scope.restore()
	_scope = SCOPE.new()
	_scope.install(true)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var bundle: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(FIXTURE.REGISTRATION)).value
	if include_days: bundle.scene_programme["story_days"] = {FIXTURE.A: 1, FIXTURE.B: 1, FIXTURE.CONTACT: 2}
	var ids: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		ids.append(entry.entry_id)
		entry.locators.en.path = PATH
	bundle.ids_registry.lines = []
	bundle.caption_registry.entries = []
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == FIXTURE.B and "#id:line.scene.test.b.two" not in text:
			programme.markers[0].after_line_id = "line.scene.test.b.one"
		var compiled := ADAPTER.compile_scene_programme(PATH, programme.entry_id, ids, programme.markers)
		assert_true(compiled.ok, str(compiled))
		if not compiled.ok: return
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
		var lines: Array = []
		for event: Dictionary in compiled.value.events:
			if event.kind != "text": continue
			lines.append({"line_id": event.line_id, "beat_id": "beat." + event.line_id,
				"text": event.text, "revision": event.text.sha256_text()})
			bundle.ids_registry.lines.append({"line_id": event.line_id, "owning_entry_id": programme.entry_id})
		bundle.caption_registry.entries.append({"entry_id": programme.entry_id, "lines": lines})
		for target: Dictionary in bundle.targets:
			if target.target.entry_id == programme.entry_id: target.target.program_sha256 = compiled.value.program_sha256
	bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	var selected := MANIFEST.configure_test_scene_registration(bundle)
	assert_true(selected.ok, str(selected))

func _source() -> String:
	return FileAccess.get_file_as_string("res://tests/fixtures/dialogic/scene_day_terminal.dtl")

func _saved_second(held: bool = false) -> Dictionary:
	var made := FIXTURE.create_session()
	assert_true(made.ok)
	assert_true(FIXTURE.enter(made.value, FIXTURE.B, "test:content").ok)
	assert_true(FIXTURE.advance_detached(made.value).ok)
	var checkpoint: Dictionary = FIXTURE.checkpoint(made.value)
	assert_true(checkpoint.ok, str(checkpoint))
	if held:
		assert_true(FIXTURE.advance_detached(made.value).ok)
		var captured: Dictionary = made.value.capture({})
		assert_true(captured.ok, str(captured))
		checkpoint.value.reading_session = captured.value
	var saved := SESSION.project_player_checkpoint(checkpoint.value)
	assert_true(saved.ok, str(saved))
	var expanded := SESSION.expand_player_checkpoint(saved.value)
	assert_true(expanded.ok, str(expanded))
	saved.value.frozen_context = expanded.value.reading_session.ledger.entry_contexts.values()[0].duplicate(true)
	saved.value.transaction_id = saved.value.reading_session.occurrence_id
	return saved.value

func test_wording_and_insertion_keep_saved_moment_and_only_encountered_history() -> void:
	_install(_source())
	var saved := _saved_second()
	var before := saved.duplicate(true)
	_install(_source().replace("B second.", "B revised second.").replace("B first.",
		"B inserted. #id:line.scene.test.b.new\nB first."))
	var normalized := SESSION.normalize_player_checkpoint(saved, {}, {})
	assert_true(normalized.ok, str(normalized))
	if not normalized.ok: return
	assert_false(normalized.value.fallback)
	assert_eq(normalized.value.checkpoint.reading_session.position_id, "line.scene.test.b.two")
	assert_eq(saved, before, "normalization is detached")
	var session := SESSION.new()
	assert_true(session.configure_scene().ok)
	assert_true(session.restore_player(normalized.value.checkpoint.reading_session, FIXTURE.B).ok)
	var projected := session.project_scene_day_history(FIXTURE.frontier(session), {}, {})
	assert_true(projected.ok, str(projected))
	assert_eq(projected.value.captions.map(func(row: Dictionary) -> String: return row.line_id),
		["line.scene.test.b.one", "line.scene.test.b.two"])
	assert_eq(projected.value.captions.back().text, "B revised second.")

func test_compact_completion_projection_preserves_position_and_detaches_history() -> void:
	_install(_source().replace("jump scene.test.a.loop", "return"))
	var made := FIXTURE.create_session()
	assert_true(made.ok, str(made))
	if not made.ok: return
	var session: RefCounted = made.value
	assert_true(FIXTURE.enter(session, FIXTURE.A, "test:completion").ok)
	assert_true(FIXTURE.advance_detached(session).ok)
	assert_true(FIXTURE.advance_detached(session).ok)
	assert_eq(session.boundary, "between_entries")
	var captured: Dictionary = session.capture({})
	assert_true(captured.ok, str(captured))
	if not captured.ok: return
	var checkpoint := {"entry_id": FIXTURE.A, "stage": "scene", "reading_session": captured.value}
	var compact := SESSION.project_player_checkpoint(checkpoint)
	assert_true(compact.ok, str(compact))
	if not compact.ok: return
	var before: Dictionary = compact.value.duplicate(true)
	var projected := SESSION.project_player_checkpoint(compact.value)
	assert_eq(projected, compact, "natural completion retains its last caption and completed boundary")
	if not projected.ok: return
	var restored := SESSION.new()
	assert_true(restored.configure_scene().ok)
	assert_true(restored.restore_player(projected.value.reading_session, FIXTURE.A).ok)
	assert_eq(restored.boundary, "between_entries")
	assert_eq(restored.scene_index, session.scene_index)
	projected.value.reading_session.captions[0].line_id = "changed.caption"
	projected.value.reading_session.history_sections[0].append("changed.history")
	assert_eq(compact.value, before, "completion projection is detached")

func test_deleted_saved_line_reports_identity_without_rewind_or_mutating_save() -> void:
	_install(_source())
	var saved := _saved_second()
	var before := saved.duplicate(true)
	_install(_source().replace("B second. #id:line.scene.test.b.two\n", ""))
	var normalized := SESSION.normalize_player_checkpoint(saved, {}, {})
	assert_false(normalized.ok)
	assert_eq(normalized.code, &"reading_content_error")
	assert_eq(normalized.details.line_id, "line.scene.test.b.two")
	assert_eq(saved, before, "failed continuation must not replace the selected saved state")

func test_file_only_wording_edit_preserves_id_and_uses_current_text() -> void:
	_install(_source())
	var saved := _saved_second()
	var fingerprint: String = MANIFEST.scene_registration_fingerprint()
	_edit_file_only(_source().replace("B second.", "Manually revised second."))
	var session := SESSION.new()
	assert_true(session.configure_scene().ok)
	var restored: Dictionary = session.restore_player(saved.reading_session, FIXTURE.B)
	assert_true(restored.ok, str(restored))
	if not restored.ok: return
	assert_eq(MANIFEST.scene_registration_fingerprint(), fingerprint, "the shipped registry was not rebuilt")
	var projected: Dictionary = session.project_scene_day_history(FIXTURE.frontier(session), {}, {})
	assert_true(projected.ok, str(projected))
	assert_eq(projected.value.captions.back().text, "Manually revised second.")
	assert_eq(projected.value.captions.back().line_id, "line.scene.test.b.two")
	assert_eq(session.player_progress.history_sections, saved.reading_session.history_sections)

func test_file_only_deleted_saved_line_reports_missing_position() -> void:
	_install(_source())
	var saved := _saved_second()
	var before := saved.duplicate(true)
	_edit_file_only(_source().replace("B second. #id:line.scene.test.b.two\n", ""))
	var expanded: Dictionary = SESSION.expand_player_checkpoint(saved)
	assert_false(expanded.ok)
	assert_eq(expanded.code, &"reading_content_error")
	assert_eq(expanded.details.position_id, "line.scene.test.b.two")
	assert_eq(saved, before)

func test_file_only_unregistered_next_line_preserves_the_saved_frontier() -> void:
	_install(_source())
	var saved := _saved_second()
	_edit_file_only(_source().replace("label scene.test.b.end", "Inserted line. #id:line.manual.unregistered\nlabel scene.test.b.end"))
	var session := SESSION.new()
	assert_true(session.configure_scene().ok)
	assert_true(session.restore_player(saved.reading_session, FIXTURE.B).ok)
	var frontier: Dictionary = FIXTURE.frontier(session)
	var before: Dictionary = session.capture(frontier)
	var next: Dictionary = session.prepare_scene_next(frontier, func(_beat: Dictionary) -> bool: return false)
	assert_false(next.ok)
	assert_eq(next.code, &"reading_content_error")
	assert_eq(next.details.line_id, "line.manual.unregistered")
	assert_eq(session.capture(frontier), before, "failed Next cannot become a saved frontier")

func test_file_only_append_after_completed_caption_keeps_its_id() -> void:
	var original: String = _source().replace("jump scene.test.a.loop", "return")
	_install(original)
	var made := FIXTURE.create_session()
	assert_true(made.ok)
	if not made.ok: return
	var session: RefCounted = made.value
	assert_true(FIXTURE.enter(session, FIXTURE.A, "test:completed-file-edit").ok)
	assert_true(FIXTURE.advance_detached(session).ok)
	assert_true(FIXTURE.advance_detached(session).ok)
	assert_eq(session.boundary, "between_entries")
	var checkpoint: Dictionary = FIXTURE.checkpoint(session)
	assert_true(checkpoint.ok, str(checkpoint))
	if not checkpoint.ok: return
	checkpoint.value.reading_session = session.capture({}).value
	var compact: Dictionary = SESSION.project_player_checkpoint(checkpoint.value)
	assert_true(compact.ok, str(compact))
	if not compact.ok: return
	var saved: Dictionary = compact.value
	var original_expansion: Dictionary = SESSION.expand_player_checkpoint(saved)
	assert_true(original_expansion.ok, str(original_expansion))
	if not original_expansion.ok: return
	saved.frozen_context = original_expansion.value.reading_session.ledger.entry_contexts.values()[0].duplicate(true)
	saved.transaction_id = saved.reading_session.occurrence_id
	var before := saved.duplicate(true)
	var fingerprint: String = MANIFEST.scene_registration_fingerprint()
	_edit_file_only(original.replace("A loop. #id:line.scene.test.a.two", "A loop. #id:line.scene.test.a.two\nAppended prose. #id:line.manual.appended"))
	var expanded: Dictionary = SESSION.expand_player_checkpoint(saved)
	assert_true(expanded.ok, str(expanded))
	if not expanded.ok: return
	assert_eq(MANIFEST.scene_registration_fingerprint(), fingerprint)
	assert_eq(expanded.value.reading_session.boundary, "line")
	assert_eq(expanded.value.reading_session.frontier.line_id, "line.scene.test.a.two")
	assert_eq(expanded.value.reading_session.player_progress.history_sections, saved.reading_session.history_sections)
	assert_eq(saved, before, "adapting a content boundary leaves source save unchanged")
	_edit_file_only(original.replace("A loop. #id:line.scene.test.a.two\n", ""))
	var missing: Dictionary = SESSION.expand_player_checkpoint(saved)
	assert_false(missing.ok, "boundary adaptation must never rewind a missing saved ID")
	assert_eq(missing.code, &"reading_content_error")
	assert_eq(saved, before)

func test_file_only_insert_before_held_control_preserves_control_when_authored_predecessor_remains() -> void:
	_install(_source())
	var saved := _saved_second(true)
	_edit_file_only(_source().replace("B second. #id:line.scene.test.b.two", "Inserted prose. #id:line.manual.inserted\nB second. #id:line.scene.test.b.two"))
	var expanded: Dictionary = SESSION.expand_player_checkpoint(saved)
	assert_true(expanded.ok, str(expanded))
	if not expanded.ok: return
	assert_eq(expanded.value.reading_session.boundary, "control")
	assert_eq(expanded.value.reading_session.ledger.captions.back().beat.line_id, "line.scene.test.b.two")
	assert_eq(expanded.value.reading_session.player_progress.history_sections, saved.reading_session.history_sections)

func _edit_file_only(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	# A fresh game process has no runtime programme cache. Keep the shipped
	# registration untouched while simulating that process boundary.
	ADAPTER._scene_runtime_programmes = {}
	ADAPTER._scene_runtime_parsed_sources = {}
	ADAPTER._scene_compile_cache.erase(PATH)

func test_valid_held_control_survives_wording_update_without_advancing() -> void:
	_install(_source())
	var saved := _saved_second(true)
	assert_eq(saved.reading_session.boundary, "control")
	_install(_source().replace("B second.", "B revised second."))
	var normalized := SESSION.normalize_player_checkpoint(saved, {}, {})
	assert_true(normalized.ok, str(normalized))
	if not normalized.ok: return
	assert_false(normalized.value.fallback)
	assert_eq(normalized.value.checkpoint.reading_session.boundary, "control")
	assert_eq(normalized.value.checkpoint.reading_session.position_id, "scene.test.b.end")
	var expanded := SESSION.expand_player_checkpoint(normalized.value.checkpoint)
	assert_true(expanded.ok, str(expanded))
	if expanded.ok: assert_eq(expanded.value.reading_session.boundary, "control")

func test_player_format_requires_supported_schema_and_progress() -> void:
	_install(_source())
	var saved := _saved_second()
	var session := SESSION.new()
	assert_true(session.configure_scene().ok)
	for schema: int in [6, 7, 8]:
		var broken: Dictionary = saved.duplicate(true)
		broken.reading_session.schema_version = schema
		for key: String in ["story_day", "recovery_anchor", "history_sections"]: broken.reading_session.erase(key)
		assert_false(SESSION.normalize_player_checkpoint(broken, {}, {}).ok)
		assert_false(SESSION.project_player_checkpoint(broken).ok)
		assert_false(SESSION.expand_player_checkpoint(broken).ok)
		assert_false(session.restore_player(broken.reading_session, FIXTURE.B).ok)
	saved.frozen_context.playback_id = "wrong-occurrence"
	assert_false(SESSION.normalize_player_checkpoint(saved, {}, {}).ok)

func test_sections_roll_and_deleted_history_does_not_backfill_or_change_registration() -> void:
	var progress := {}
	for index: int in 5:
		TRAVERSAL.append_player_caption(progress, "entry", "line.%d" % index, 1, true)
	assert_eq(progress.history_sections, [["line.2"], ["line.3"], ["line.4"]])
	assert_eq(progress.recovery_anchor, {"entry_id": "entry", "line_id": "line.4"})
	TRAVERSAL.append_player_caption(progress, "entry", "line.4", 1, true)
	assert_eq(progress.history_sections, [["line.2"], ["line.3"], ["line.4"]])
	var bundle := {"caption_registry": {"entries": [{"entry_id": "entry", "lines": [
		{"line_id": "line.2", "beat_id": "beat.2", "text": "Revised two."},
		{"line_id": "inserted", "beat_id": "beat.new", "text": "Not encountered."},
		{"line_id": "line.4", "beat_id": "beat.4", "text": "Four."}]}]}}
	var before := bundle.duplicate(true)
	var display := HISTORY.project_encountered(bundle, progress.history_sections)
	assert_eq(display.value.captions.map(func(row: Dictionary) -> String: return row.line_id), ["line.2", "line.4"])
	assert_eq(bundle, before)

func test_day_start_retains_previous_two_sections_and_progress_day_never_rewinds() -> void:
	var progress := {}
	TRAVERSAL.append_player_caption(progress, "day1", "one", 1)
	TRAVERSAL.append_player_caption(progress, "day1", "two", 1, true)
	TRAVERSAL.append_player_caption(progress, "day2", "three", 2)
	assert_eq(progress.history_sections, [["one"], ["two"], ["three"]])
	assert_eq(progress.story_day, 2)
	TRAVERSAL.append_player_caption(progress, "day1", "old", 1)
	assert_eq(progress.story_day, 2)

func test_normalization_rejects_source_corruption_before_current_or_stale_rebinding() -> void:
	_install(_source())
	var saved := _saved_second()
	for stale: bool in [false, true]:
		for field: String in ["position", "receipt", "transaction"]:
			var broken: Dictionary = saved.duplicate(true)
			if stale:
				broken.manifest_fingerprint = "a".repeat(64)
				broken.reading_session.registration_sha256 = broken.manifest_fingerprint
			match field:
				"position": broken.reading_session.position_id = "different.line"
				"receipt": broken.frozen_context.presentation.fields.admission_receipt_id = "different.receipt"
				"transaction":
					broken.transaction_id = "different.transaction"
					broken.frozen_context.transaction_id = broken.transaction_id
			assert_false(SESSION.normalize_player_checkpoint(broken, {}, {}).ok, field + str(stale))
	var wrong_day: Dictionary = saved.duplicate(true)
	wrong_day.reading_session.story_day = 0
	assert_false(SESSION.normalize_player_checkpoint(wrong_day, {}, {}).ok)
	var revisited: Dictionary = saved.duplicate(true)
	revisited.reading_session.story_day = 2
	var preserved := SESSION.normalize_player_checkpoint(revisited, {}, {})
	assert_true(preserved.ok, str(preserved))
	if preserved.ok: assert_eq(preserved.value.story_day, 2, "earlier-day revisit cannot rewind renewal high-water")
	var absent: Dictionary = saved.duplicate(true)
	absent.reading_session.position_id = "absent.line"
	absent.reading_session.captions[0].line_id = "absent.line"
	assert_false(SESSION.normalize_player_checkpoint(absent, {}, {}).ok, "unchanged registration cannot contain a deleted line")

func test_normalization_keeps_encountered_previous_day_sections() -> void:
	_install(_source())
	var earlier := _saved_second()
	var session := SESSION.new()
	assert_true(session.configure_scene().ok)
	assert_true(session.restore_player(earlier.reading_session, FIXTURE.B).ok)
	assert_true(FIXTURE.enter(session, FIXTURE.CONTACT, "test:next-day").ok)
	var compact := SESSION.project_player_checkpoint(FIXTURE.checkpoint(session).value)
	assert_true(compact.ok, str(compact))
	if not compact.ok: return
	var expanded := SESSION.expand_player_checkpoint(compact.value)
	assert_true(expanded.ok, str(expanded))
	if not expanded.ok: return
	compact.value.frozen_context = expanded.value.reading_session.ledger.entry_contexts.values()[0].duplicate(true)
	compact.value.transaction_id = compact.value.reading_session.occurrence_id
	var normalized := SESSION.normalize_player_checkpoint(compact.value, {}, {})
	assert_true(normalized.ok, str(normalized))
	if normalized.ok:
		assert_eq(normalized.value.checkpoint.reading_session.history_sections,
			[["line.scene.test.b.one", "line.scene.test.b.two"], ["line.contact.test.a.one"]])

func test_ordinary_lower_day_admission_does_not_rotate_high_water_history() -> void:
	_install(_source())
	var saved := _saved_second()
	saved.reading_session.story_day = 2
	for fresh: bool in [false, true]:
		var restored := SESSION.new()
		assert_true(restored.configure_scene().ok)
		assert_true(restored.restore_player(saved.reading_session, FIXTURE.B).ok)
		var session: RefCounted = restored
		if fresh:
			var made := FIXTURE.create_session()
			assert_true(made.ok)
			session = made.value
			session.inherit_player_progress(restored)
		var previous: Dictionary = session.player_progress.duplicate(true)
		assert_true(FIXTURE.enter(session, FIXTURE.A, "test:ordinary").ok)
		var captured: Dictionary = session.capture(FIXTURE.frontier(session))
		assert_true(captured.ok, str(captured))
		if not captured.ok: continue
		assert_eq(captured.value.player_progress.story_day, 2)
		assert_eq(captured.value.player_progress.recovery_anchor, previous.recovery_anchor)
		assert_eq(captured.value.player_progress.history_sections.size(), previous.history_sections.size())
		assert_eq(captured.value.player_progress.history_sections.back().size(), previous.history_sections.back().size() + 1)
		assert_eq(captured.value.player_progress.history_sections.back().back(), "line.scene.test.a.one")
		assert_eq(captured.value.player_progress.history_sections.back().slice(0, previous.history_sections.back().size()),
			previous.history_sections.back(), "ordinary entry extends the existing section")

func test_wording_change_does_not_require_a_day_route_map() -> void:
	_install(_source(), false)
	var saved := _saved_second()
	var normalized := SESSION.normalize_player_checkpoint(saved, {}, {})
	assert_true(normalized.ok, str(normalized))
	if normalized.ok:
		assert_eq(normalized.value.checkpoint.reading_session.schema_version, 7)
		assert_eq(normalized.value.checkpoint.reading_session.position_id, "line.scene.test.b.two")
		assert_false(normalized.value.fallback)
	var broken: Dictionary = saved.duplicate(true)
	broken.reading_session.position_id = "missing"
	broken.reading_session.captions[0].line_id = "missing"
	assert_false(SESSION.normalize_player_checkpoint(broken, {}, {}).ok)
	_install(_source().replace("B second.", "B changed."), false)
	var stale := SESSION.normalize_player_checkpoint(saved, {}, {})
	assert_true(stale.ok, str(stale))
	if stale.ok: assert_eq(stale.value.checkpoint.reading_session.position_id, "line.scene.test.b.two")
