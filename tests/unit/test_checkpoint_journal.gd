extends "res://addons/gut/test.gd"

const JOURNAL_PATH := "res://scripts/infrastructure/save/CheckpointJournal.gd"
const SNAPSHOT_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"
const RETENTION_FIXTURE := "res://tests/fixtures/checkpoints/retention_40_lines.json"
const DOCUMENT_SCHEMA_PATH := "res://scripts/infrastructure/save/SaveDocumentSchema.gd"

const SEMANTIC_KINDS := [
	"day_start", "timeline_start", "timeline_complete", "choice", "variable_transaction",
	"effect_transaction", "safe_marker", "scene_transition", "pre_board", "post_result",
	"day_resolution_stage",
]

func _journal_exists() -> bool:
	return ResourceLoader.exists(JOURNAL_PATH, "Script")

func _snapshot(run_id: String, sequence: int, day: int = 3) -> Dictionary:
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_FIXTURE))
	snapshot["run_id"] = run_id
	snapshot["checkpoint_sequence"] = sequence
	snapshot["checkpoint_id"] = "%s:%d" % [run_id, sequence]
	snapshot["lifecycle"]["run_id"] = run_id
	snapshot["lifecycle"]["day"] = day
	if day == 1:
		snapshot["lifecycle"]["state"] = "PLAYING"
	return snapshot

func _fresh(run_id: String) -> RefCounted:
	var journal: RefCounted = load(JOURNAL_PATH).new()
	assert_true(journal.reset(run_id)["ok"])
	return journal

func _commit_record(journal: RefCounted, run_id: String, sequence: int, kind: StringName) -> Dictionary:
	var prepared: Dictionary = journal.prepare_record(_snapshot(run_id, sequence), kind)
	assert_true(prepared.get("ok", false), "%s:%d %s -> %s" % [run_id, sequence, kind, JSON.stringify(prepared)])
	var committed: Dictionary = journal.commit_prepared(prepared["value"]["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	return committed

func test_checkpoint_journal_exists() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")

func test_reset_peek_and_run_mismatch() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")
	if not _journal_exists():
		return
	var journal := _fresh("run-a")
	var peeked: Dictionary = journal.peek_next_sequence("run-a")
	assert_true(peeked["ok"])
	assert_eq(int(peeked["value"]["checkpoint_sequence"]), 1, "an empty journal allocates sequence 1")
	assert_false(journal.peek_next_sequence("run-b").get("ok", true), "peek requires the owning run")
	assert_false(journal.get_current_bundle().get("ok", true), "an empty journal has no current bundle")

func test_failed_preparation_never_consumes_sequence() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")
	if not _journal_exists():
		return
	var journal := _fresh("run-a")
	var before: Dictionary = journal.capture_state()["value"]["backup"]
	assert_false(journal.prepare_record(_snapshot("run-a", 5), &"line").get("ok", true),
		"sequence must equal the cursor")
	assert_false(journal.prepare_record(_snapshot("run-b", 1), &"line").get("ok", true),
		"run mismatch rejects")
	assert_false(journal.prepare_record(_snapshot("run-a", 1), &"unknown").get("ok", true),
		"unknown checkpoint kind rejects before mutation")
	assert_eq(journal.capture_state()["value"]["backup"], before,
		"failed preparation leaves the journal byte-equal")
	assert_eq(int(journal.peek_next_sequence("run-a")["value"]["checkpoint_sequence"]), 1,
		"the same next sequence remains available")

func test_commit_advances_and_duplicate_commit_rejects() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")
	if not _journal_exists():
		return
	var journal := _fresh("run-a")
	var prepared: Dictionary = journal.prepare_record(_snapshot("run-a", 1), &"day_start")
	assert_true(prepared["ok"])
	var candidate: Dictionary = prepared["value"]["candidate"]
	var committed: Dictionary = journal.commit_prepared(candidate.duplicate(true))
	assert_true(committed["ok"])
	assert_eq(str(committed["value"]["checkpoint_id"]), "run-a:1")
	assert_eq(int(journal.peek_next_sequence("run-a")["value"]["checkpoint_sequence"]), 2)
	var replay: Dictionary = journal.commit_prepared(candidate.duplicate(true))
	assert_false(replay.get("ok", true), "duplicate commit rejects")
	assert_eq(replay["code"], &"duplicate_commit")

func test_every_accepted_checkpoint_kind_including_line() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")
	if not _journal_exists():
		return
	var journal := _fresh("run-a")
	var sequence := 1
	_commit_record(journal, "run-a", sequence, &"line")
	for kind: String in SEMANTIC_KINDS:
		sequence += 1
		_commit_record(journal, "run-a", sequence, StringName(kind))
	assert_eq(str(journal.get_current_bundle()["value"]["bundle"]["checkpoint_kind"]),
		"day_resolution_stage")

func test_retention_after_forty_lines_and_semantic_anchor() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")
	if not _journal_exists():
		return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RETENTION_FIXTURE))
	var journal := _fresh("run-a")
	for sequence: int in range(1, int(config["line_count"]) + 1):
		_commit_record(journal, "run-a", sequence, &"line")
	_commit_record(journal, "run-a", int(config["anchor_sequence"]), StringName(str(config["anchor_kind"])))
	var current: Dictionary = journal.get_current_bundle()["value"]["bundle"]
	assert_eq(int(current["snapshot"]["checkpoint_sequence"]), int(config["anchor_sequence"]),
		"the semantic bundle is current, not counted in the line cap")
	var earlier: Array = journal.get_bundles_for_disk()
	var line_sequences: Array[int] = []
	for bundle: Dictionary in earlier:
		assert_true(str(bundle["checkpoint_kind"]) == "line", "only earlier lines exist in this journal")
		line_sequences.append(int(bundle["snapshot"]["checkpoint_sequence"]))
	line_sequences.sort()
	var expected: Array[int] = []
	for sequence: int in range(int(config["expected_earlier_line_sequences_min"]),
			int(config["expected_earlier_line_sequences_max"]) + 1):
		expected.append(sequence)
	assert_eq(line_sequences, expected, "lines 9..40 remain after retention")
	var before: Dictionary = journal.capture_state()["value"]["backup"]
	assert_false(journal.prepare_record(_snapshot("run-a", 42), &"unknown").get("ok", true))
	assert_eq(journal.capture_state()["value"]["backup"], before,
		"preparing an unknown kind leaves capture_state byte-equal")

func test_reset_with_initial_replaces_run_and_restore_reinstates() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")
	if not _journal_exists():
		return
	var journal := _fresh("run-a")
	_commit_record(journal, "run-a", 1, &"day_start")
	_commit_record(journal, "run-a", 2, &"line")
	var backup: Dictionary = journal.capture_state()["value"]["backup"]
	assert_false(journal.prepare_reset_with_initial(_snapshot("run-b", 1, 1), &"line").get("ok", true),
		"reset-with-initial accepts only day_start")
	assert_false(journal.prepare_reset_with_initial(_snapshot("run-b", 2, 1), &"day_start").get("ok", true),
		"reset-with-initial requires sequence 1")
	assert_false(journal.prepare_reset_with_initial(_snapshot("run-b", 1, 5), &"day_start").get("ok", true),
		"reset-with-initial requires Day 1 PLAYING")
	var prepared: Dictionary = journal.prepare_reset_with_initial(_snapshot("run-b", 1, 1), &"day_start")
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(journal.capture_state()["value"]["backup"], backup,
		"preparation does not mutate the live Run-A journal")
	assert_true(journal.commit_prepared(prepared["value"]["candidate"])["ok"])
	assert_eq(int(journal.peek_next_sequence("run-b")["value"]["checkpoint_sequence"]), 2,
		"the replacement journal continues at sequence 2")
	assert_eq(journal.get_bundles_for_disk(), [], "no earlier bundles after a reset")
	assert_true(journal.restore_state(backup)["ok"])
	assert_eq(int(journal.peek_next_sequence("run-a")["value"]["checkpoint_sequence"]), 3,
		"restore reinstates the captured Run-A journal")

func test_prepare_seed_selects_and_excludes() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")
	if not _journal_exists():
		return
	var document_schema: Script = load(DOCUMENT_SCHEMA_PATH)
	var bundle_1 := {"checkpoint_kind": "day_start", "snapshot": _snapshot("run-a", 1)}
	var bundle_2 := {"checkpoint_kind": "line", "snapshot": _snapshot("run-a", 2)}
	var current_bundle := {"checkpoint_kind": "day_resolution_stage", "snapshot": _snapshot("run-a", 3)}
	var corrupt := {"checkpoint_kind": "line", "snapshot": {"garbage": true}}
	var built: Dictionary = document_schema.build(
		&"autosave", null, &"automatic", current_bundle, [bundle_1, bundle_2, corrupt])
	assert_true(built.get("ok", false), JSON.stringify(built))
	var journal: RefCounted = load(JOURNAL_PATH).new()
	assert_true(journal.reset("seed-host")["ok"])
	var seeded: Dictionary = journal.prepare_seed(built["value"], bundle_2)
	assert_true(seeded.get("ok", false), JSON.stringify(seeded))
	assert_true((seeded["value"]["diagnostics"] as Array).size() >= 1,
		"the corrupt neighbor is excluded with a diagnostic")
	assert_true(journal.commit_prepared(seeded["value"]["candidate"])["ok"])
	var current: Dictionary = journal.get_current_bundle()["value"]["bundle"]
	assert_eq(int(current["snapshot"]["checkpoint_sequence"]), 2, "the selected bundle becomes current")
	assert_eq(int(journal.peek_next_sequence("run-a")["value"]["checkpoint_sequence"]), 3,
		"next sequence is selected + 1")
	var earlier: Array = journal.get_bundles_for_disk()
	assert_eq(earlier.size(), 1, "later and invalid candidates are discarded")
	assert_eq(int((earlier[0] as Dictionary)["snapshot"]["checkpoint_sequence"]), 1)
	assert_false(journal.prepare_seed(built["value"], {"checkpoint_kind": "line",
		"snapshot": _snapshot("run-z", 9)}).get("ok", true),
		"a selected bundle outside the document rejects")
