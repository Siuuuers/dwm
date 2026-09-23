extends SceneTree
## Paired real SaveManager preparation and commit on the same retained Day-7 storage.
## The capture provider is an immutable fixture; no live UI, issuer-flush callback or renderer
## is timed. Public prepare/commit, source/revision checks, disk I/O and journal commit are real.

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")

class FixedClockSave extends "res://autoload/SaveManager.gd":
	var validation_calls := 0
	func _capture_saved_time() -> Dictionary:
		return {"unix_seconds": 0, "utc_offset_minutes": 0, "hhmm": "00:00"}
	func _document_text_validator(text: String) -> Dictionary:
		validation_calls += 1
		return super._document_text_validator(text)

var _inputs: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, detail: String) -> bool:
	if not value:
		printerr("MANUAL_SAVE_WRITE_FAIL: " + detail)
		quit(1)
	return value

func _capture() -> Dictionary:
	return {"ok": true, "value": _inputs.duplicate(true)}

func _hash(value: Variant) -> String:
	var result := CANONICAL.stringify(value)
	if not _check(result.get("ok", false), "canonical proof"): return ""
	return str(result.value).sha256_text()

func _files(folder: String) -> Dictionary:
	var result := {}
	var directory := DirAccess.open(folder)
	if not _check(directory != null, "storage directory exists"): return {}
	directory.include_hidden = true
	if not _check(directory.get_directories().is_empty(), "storage fixture is flat"): return {}
	var filenames := directory.get_files()
	filenames.sort()
	for filename: String in filenames:
		result[filename] = FileAccess.get_sha256(folder.path_join(filename))
	return result

func _run() -> void:
	var source := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--write-source="):
			if not _check(source.is_empty(), "one write source"): return
			source = argument.trim_prefix("--write-source=").replace("\\", "/").simplify_path()
	var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests").replace("\\", "/").to_lower() + "/"
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path()
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	if not _check(source.to_lower().begins_with(allowed) and isolated.to_lower().begins_with(allowed)
		and isolated.get_file() == "dwm_test_root"
		and user_root.to_lower().begins_with(isolated.get_base_dir().path_join("appdata").to_lower() + "/"),
		"source and destination require separate isolated cloud roots"): return
	var target := user_root.path_join("manual-write-saves")
	if not _check(not DirAccess.dir_exists_absolute(target) and source != target, "fresh destination"): return
	if not _check(DirAccess.make_dir_recursive_absolute(target) == OK, "create isolated storage"): return
	var source_files := _files(source)
	if not _check(source_files.has("autosave.json") and source_files.has("slot_1.json"), "retained source documents"): return
	for filename: String in source_files:
		if not _check(DirAccess.copy_absolute(source.path_join(filename), target.path_join(filename)) == OK, "clone " + filename): return
	if not _check(_files(target) == source_files, "all physical source files cloned exactly"): return
	var parsed := STRICT.parse_object(FileAccess.get_file_as_string(target.path_join("autosave.json")))
	if not _check(parsed.get("ok", false), "strict source parse"): return
	var validated := DOCUMENT.validate(parsed.value)
	if not _check(validated.get("ok", false), "source document valid"): return
	var document: Dictionary = validated.value.candidate
	var snapshot: Dictionary = document.current_snapshot.snapshot
	if not _check(snapshot.lifecycle.day == 7 and document.recovery_journal.size() == 66,
		"the seven-day producer supplied saturated retained history"): return
	var manager := FixedClockSave.new()
	var storage := STORAGE.new(target)
	if not _check(manager.initialize(storage).get("ok", false), "isolated SaveManager initialized"): return
	var seeded: Dictionary = manager._journal.prepare_seed(document, document.current_snapshot)
	if not _check(seeded.get("ok", false) and seeded.value.diagnostics.is_empty(), "all source checkpoints admitted"): return
	if not _check(manager._journal.commit_prepared(seeded.value.candidate).get("ok", false), "journal seeded"): return
	# The fixture opens Backup on the unchanged saved gameplay; it supplies no new historical facts.
	_inputs = {"snapshot_input": snapshot.duplicate(true), "dialogic_checkpoint": {},
		"route_id": "main", "active_app_id": "backup", "audio_context": snapshot.audio_context.duplicate(true),
		"content_version": int(snapshot.content_version)}
	if not _check(snapshot.lifecycle.state == "PLAYING" and snapshot.narrative_checkpoint.is_empty(), "desktop capture source"): return
	if not _check(manager.configure_backup_capture_provider(_capture).get("ok", false), "immutable capture configured"): return
	OS.set_environment("DWM_SAVE_LOAD_CONTEXT", "manual-write-prepare")
	var prepare_started := Time.get_ticks_usec()
	var prepared: Dictionary = manager.prepare_backup_action("save", "slot:1")
	var prepare_elapsed := Time.get_ticks_usec() - prepare_started
	OS.set_environment("DWM_SAVE_LOAD_CONTEXT", "")
	if not _check(prepared.get("ok", false), "normal public preparation: " + str(prepared.get("code", ""))): return
	var token: String = prepared.value.token
	var candidate: Dictionary = manager._backup_actions[token].duplicate(true)
	var candidate_hash := _hash(candidate)
	var prior_journal_hash: String = manager._backup_journal_hash()
	var expected := CANONICAL.stringify(candidate.document)
	if not _check(expected.get("ok", false), "prepared document canonicalizes"): return
	var expected_text: String = expected.value + "\n"
	var cache_state := []
	for entry: Dictionary in manager._document_parse_cache:
		cache_state.append({"sha256": str(entry.text).sha256_text(), "bytes": str(entry.text).to_utf8_buffer().size()})
	manager.validation_calls = 0
	OS.set_environment("DWM_SAVE_LOAD_CONTEXT", "manual-write-commit")
	var started := Time.get_ticks_usec()
	var committed: Dictionary = manager.commit_backup_action(token)
	var elapsed := Time.get_ticks_usec() - started
	OS.set_environment("DWM_SAVE_LOAD_CONTEXT", "")
	if not _check(committed.get("ok", false), "public commit: " + str(committed.get("code", ""))): return
	if not _check(not manager._backup_actions.has(token), "consent consumed"): return
	var written := FileAccess.get_file_as_string(target.path_join("slot_1.json"))
	if not _check(written == expected_text, "exact prepared outgoing bytes persisted"): return
	var inspected: Dictionary = storage.inspect_revision("slot_1.json")
	if not _check(inspected.get("ok", false) and inspected.value.revision == expected_text.sha256_text(), "no pending transaction artifacts"): return
	var expected_journal: Dictionary = candidate.journal_candidate.duplicate(true)
	expected_journal.erase("candidate_kind")
	var actual_journal: Dictionary = manager._journal.capture_state().value.backup
	if not _check(CANONICAL._deep_same(actual_journal, expected_journal)
		and actual_journal.earlier.size() == 66, "exact prepared journal and retention committed"): return
	if not _check(DOCUMENT.validate(STRICT.parse_object(written).value).get("ok", false), "written save strictly validates"): return
	if not _check(_files(source) == source_files, "retained source is untouched"): return
	print("MANUAL_SAVE_WRITE_PASS: " + JSON.stringify({"prepare_us": prepare_elapsed, "commit_us": elapsed,
		"candidate_sha256": candidate_hash, "source_revision": candidate.revision,
		"source_files_sha256": source_files, "output_files_sha256": _files(target),
		"prior_journal_sha256": prior_journal_hash, "journal_sha256": _hash(actual_journal),
		"output_sha256": written.sha256_text(), "output_bytes": written.to_utf8_buffer().size(),
		"retained_checkpoint_count": actual_journal.earlier.size(), "strict_validation_calls": manager.validation_calls,
		"parse_cache_enabled": OS.get_environment("DWM_SAVE_PARSE_CACHE_DISABLED") != "1",
		"parse_cache_before": cache_state, "save_manager_sha256": FileAccess.get_sha256("res://autoload/SaveManager.gd")}))
	manager.free()
	quit(0)
