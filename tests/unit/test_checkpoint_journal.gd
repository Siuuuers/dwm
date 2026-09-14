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

## Test-authored v6 cases retain the source payload and explicitly choose Dark=false.
## This fixture construction is not a player-save migration.
func _issuer_receipt(token: String) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-" + token, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": token, "numeric_value": null}

func _empty_desktop() -> Dictionary:
	return {
		"board": {"schema_version": 1, "phase": "NONE", "revision": 0, "identity": null,
			"candidate": null, "board": null, "settlement": null, "command_receipts": {}, "terminal_receipts": {}},
		"consequence": {"schema_version": 1, "run_revision": 0, "causal_sequence": 0,
			"causal_day_instance": "causal-day-1",
			"causal_day_instance_issuer_receipt": _issuer_receipt("causal-day-1"),
			"pending": null, "outbox": {}, "shop_ledger": {"supportz_branch_purchase_count": 0,
				"supportz_last_purchase_causal_day_instance": "", "base_completion_receipts": []}},
	}

func _snapshot(run_id: String, sequence: int, day: int = 3) -> Dictionary:
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_FIXTURE))
	snapshot["schema_version"] = 6
	snapshot["lifecycle"]["dark_mode"] = false
	snapshot["gameplay"].erase("opening_seen")
	snapshot["gameplay"].erase("tutorial_seen")
	snapshot["run_id"] = run_id
	snapshot["checkpoint_sequence"] = sequence
	snapshot["checkpoint_id"] = "%s:%d" % [run_id, sequence]
	snapshot["lifecycle"]["run_id"] = run_id
	snapshot["lifecycle"]["day"] = day
	snapshot["lifecycle"]["branch_id"] = "branch-1"
	snapshot["lifecycle"]["desktop_timeline_generation"] = 0
	snapshot["lifecycle"]["causal_day_instance"] = "causal-day-1"
	snapshot["lifecycle"]["causal_day_instance_issuer_receipt"] = _issuer_receipt("causal-day-1")
	snapshot["lifecycle"]["restore_provenance"] = null
	snapshot["lifecycle"]["active_condition_hospital_plan"] = null
	snapshot["lifecycle"]["condition_hospital_history"] = {}
	snapshot["lifecycle"]["terminal_intent_handoff"] = null
	snapshot["schedule_view"] = preload("res://scripts/domain/schedule/ScheduleViewState.gd").make_empty(day, "causal-day-1").value.view
	snapshot["desktop"] = _empty_desktop()
	# v3 (dwm-p2r.13 Task 5): a snapshot names ONE day, so the committed aggregate moves with it.
	(snapshot["committed_schedule"] as Dictionary)["day"] = day
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
	var replay: Dictionary = journal.commit_prepared(prepared["value"]["candidate"])
	assert_eq(replay.get("code"), &"duplicate_commit", "reset duplicate guard remains")
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

func test_seed_replaces_same_counter_contents_and_history_and_can_repeat() -> void:
	var journal := _fresh("run-a")
	_commit_record(journal, "run-a", 1, &"day_start")
	_commit_record(journal, "run-a", 2, &"line")
	var original: Dictionary = journal.capture_state()["value"]["backup"]
	var changed := _snapshot("run-a", 2)
	changed["gameplay"]["money"] = 7
	var selected := {"checkpoint_kind": "line", "snapshot": changed}
	var document: Dictionary = load(DOCUMENT_SCHEMA_PATH).build(&"slot", 1, &"manual", selected, [])
	assert_true(document.get("ok", false), "same-counter saved document is valid: " + JSON.stringify(document))
	if not document.get("ok", false):
		return
	var prepared: Dictionary = journal.prepare_seed(document["value"], selected)
	assert_true(prepared.get("ok", false))
	assert_eq(journal.capture_state()["value"]["backup"], original, "seed preparation remains pure")
	var candidate: Dictionary = prepared["value"]["candidate"]
	assert_true(journal.commit_prepared(candidate).get("ok", false), "seed may replace its current counter")
	assert_eq(journal.get_current_bundle()["value"]["bundle"], candidate["current"], "same identity installs saved contents")
	assert_eq(journal.get_bundles_for_disk(), [], "same identity replaces earlier history instead of keeping live entries")
	var seeded: Dictionary = journal.capture_state()["value"]["backup"]
	assert_true(journal.commit_prepared(candidate.duplicate(true)).get("ok", false), "validated seed can repeat")
	assert_eq(journal.capture_state()["value"]["backup"], seeded, "repeated seed is exact")
	var invalid := candidate.duplicate(true)
	invalid["next_sequence"] = 99
	assert_false(journal.commit_prepared(invalid).get("ok", true), "invalid seed still rejects")
	assert_eq(journal.capture_state()["value"]["backup"], seeded, "invalid seed cannot mutate")


func test_semantic_recovery_history_is_bounded_without_changing_current_snapshot() -> void:
	var journal := _fresh("bounded-run")
	for sequence: int in range(1, 13):
		var prepared: Dictionary = journal.prepare_record(_snapshot("bounded-run", sequence), &"post_result")
		assert_true(prepared.ok, str(prepared))
		assert_true(journal.commit_prepared(prepared.value.candidate).ok)
	var current: Dictionary = journal.get_current_bundle().value.bundle
	assert_eq(current.snapshot.checkpoint_sequence, 12)
	var earlier: Array = journal.get_bundles_for_disk()
	assert_eq(earlier.size(), 2, "old full-run copies must not grow with every action")
	assert_eq(earlier[0].snapshot.checkpoint_sequence, 10)
	assert_eq(earlier[1].snapshot.checkpoint_sequence, 11)
	assert_eq(current.snapshot, preload("res://scripts/domain/run/RunSnapshotSchema.gd").validate(_snapshot("bounded-run", 12)).value.candidate, "current gameplay and complete causal history stay intact")


## --- Remembered canonical bundle texts (perf/terminal-settlement-3) ------------------------------
## The journal, as sole owner of bundle lifetime, may remember the canonical text of its CURRENT
## bundle once the port proved it at that bundle's own commit, and hand it back only while the
## bundle is still retained as the journal's own private duplicate. Beside each text it remembers
## the document bundle those proven bytes describe, in the same entry and under the same rules.

func test_remember_committed_bundle_text_accepts_only_the_current_checkpoint() -> void:
	var journal := _fresh("run-a")
	assert_false(journal.remember_committed_bundle_text("run-a:1", "{}"), "an empty journal remembers nothing")
	assert_eq(journal.get_retained_bundle_text("run-a:1"), "")
	_commit_record(journal, "run-a", 1, &"day_start")
	assert_false(journal.remember_committed_bundle_text("run-a:2", "{}"), "a non-current id is refused")
	assert_false(journal.remember_committed_bundle_text("run-a:1", ""), "empty text is refused")
	assert_eq(journal.get_retained_bundle_text("run-a:1"), "", "refused texts are never stored")
	assert_true(journal.remember_committed_bundle_text("run-a:1", "text-1"))
	assert_eq(journal.get_retained_bundle_text("run-a:1"), "text-1")
	assert_eq(journal.get_retained_bundle_text("run-a:2"), "")


## A stand-in for the document bundle the checkpoint port remembers beside a proven text: one
## `{checkpoint_kind, snapshot}` object per sequence, small enough to compare leaf by leaf.
func _proof_document(sequence: int) -> Dictionary:
	return {"checkpoint_kind": "post_result", "snapshot": {"probe": {"sequence": sequence}}}


## Asserted before the three-argument remember calls below, in the idiom of `_argument_count()`'s
## own note: a wrong-arity or nonexistent call aborts the test function outright, which GUT records
## as risky rather than failed, so the surface is asserted first and the row returns if it is absent.
func _remembers_document_bundles(journal: RefCounted) -> bool:
	assert_eq(_argument_count(journal, "remember_committed_bundle_text"), 3,
		"remember_committed_bundle_text() must accept the document bundle beside the text")
	assert_true(journal.has_method("get_retained_bundle_document"),
		"the journal must serve back the document bundle it remembered")
	return _argument_count(journal, "remember_committed_bundle_text") == 3 \
		and journal.has_method("get_retained_bundle_document")


## The retained document bundle shares ONE entry, one lifetime and one set of refusals with the
## text, so the port can never splice a bundle's remembered bytes while composing that same entry
## from a document the journal no longer holds.
func test_remembered_document_bundle_is_a_private_deep_copy_served_by_reference() -> void:
	var journal := _fresh("run-a")
	if not _remembers_document_bundles(journal):
		return
	var offered := _proof_document(1)
	assert_false(journal.remember_committed_bundle_text("run-a:1", "text-1", offered),
		"an empty journal remembers nothing")
	assert_true(journal.get_retained_bundle_document("run-a:1").is_empty())
	_commit_record(journal, "run-a", 1, &"day_start")
	assert_false(journal.remember_committed_bundle_text("run-a:2", "text-2", offered),
		"a non-current id is refused")
	assert_true(journal.get_retained_bundle_document("run-a:2").is_empty(),
		"a refused document is never stored")
	assert_false(journal.remember_committed_bundle_text("run-a:1", "", offered),
		"empty text is refused")
	assert_true(journal.get_retained_bundle_document("run-a:1").is_empty(),
		"the document rides exactly the text's refusals")

	assert_true(journal.remember_committed_bundle_text("run-a:1", "text-1", offered))
	var served: Dictionary = journal.get_retained_bundle_document("run-a:1")
	assert_eq(str(served.get("checkpoint_kind", "")), "post_result",
		"the remembered document bundle is served back")
	assert_eq(int(((served["snapshot"] as Dictionary)["probe"] as Dictionary)["sequence"]), 1)
	assert_false(is_same(served, offered), "...as the journal's own deep copy, never the caller's object")
	assert_false(is_same(served["snapshot"], offered["snapshot"]), "...at depth")
	((offered["snapshot"] as Dictionary)["probe"] as Dictionary)["sequence"] = 99
	assert_eq(int(((served["snapshot"] as Dictionary)["probe"] as Dictionary)["sequence"]), 1,
		"mutating the offered bundle after remembering cannot reach the retained copy")
	assert_true(is_same(served, journal.get_retained_bundle_document("run-a:1")),
		"two reads serve the SAME object: the one caller hands it to build(), which duplicates it")

	# One entry, one lifetime: a caller with no document to offer leaves the entry holding none.
	assert_true(journal.remember_committed_bundle_text("run-a:1", "text-1b"))
	assert_eq(journal.get_retained_bundle_text("run-a:1"), "text-1b")
	assert_true(journal.get_retained_bundle_document("run-a:1").is_empty(),
		"remembering a text without a document replaces the whole entry")


func test_retained_bundle_text_is_forgotten_when_the_bundle_leaves_retention() -> void:
	var journal := _fresh("run-a")
	if not _remembers_document_bundles(journal):
		return
	for sequence: int in range(1, 5):
		_commit_record(journal, "run-a", sequence, &"post_result")
		assert_true(journal.remember_committed_bundle_text("run-a:%d" % sequence, "text-%d" % sequence,
			_proof_document(sequence)))
	var earlier: Array = journal.get_bundles_for_disk()
	assert_eq(earlier.size(), 2)
	assert_eq(int(earlier[0].snapshot.checkpoint_sequence), 2, "sequence 1 fell out of semantic retention")
	assert_eq(journal.get_retained_bundle_text("run-a:1"), "", "a bundle no longer retained has no text")
	assert_true(journal.get_retained_bundle_document("run-a:1").is_empty(),
		"...and no document bundle either: both leave with the bundle")
	assert_eq(journal.get_retained_bundle_text("run-a:2"), "text-2")
	assert_eq(journal.get_retained_bundle_text("run-a:3"), "text-3")
	assert_eq(journal.get_retained_bundle_text("run-a:4"), "text-4", "the current bundle's text is served")
	for sequence: int in [2, 3, 4]:
		var retained_document: Dictionary = journal.get_retained_bundle_document("run-a:%d" % sequence)
		var probe: Dictionary = (retained_document["snapshot"] as Dictionary)["probe"]
		assert_eq(int(probe["sequence"]), sequence,
			"every still-retained bundle serves its own document, current included")
	# A refused commit prunes nothing.
	var stale: Dictionary = journal.prepare_record(_snapshot("run-a", 5), &"post_result")["value"]["candidate"]
	stale["run_id"] = "run-z"
	assert_false(journal.commit_prepared(stale).get("ok", true))
	assert_eq(journal.get_retained_bundle_text("run-a:2"), "text-2", "a refused commit keeps every retained text")
	assert_false(journal.get_retained_bundle_document("run-a:2").is_empty(),
		"a refused commit keeps every retained document bundle")


func test_retained_bundle_texts_clear_on_reset_candidate_seed_restore_and_reset() -> void:
	var journal := _fresh("run-a")
	if not _remembers_document_bundles(journal):
		return
	for sequence: int in [1, 2, 3]:
		_commit_record(journal, "run-a", sequence, &"post_result")
		assert_true(journal.remember_committed_bundle_text("run-a:%d" % sequence, "text-%d" % sequence,
			_proof_document(sequence)))
	# A reset candidate installs a NEW run-a:1 with different bytes: nothing remembered survives.
	var reset: Dictionary = journal.prepare_reset_with_initial(_snapshot("run-a", 1, 1), &"day_start")
	assert_true(reset.get("ok", false), JSON.stringify(reset))
	assert_true(journal.commit_prepared(reset["value"]["candidate"]).get("ok", false))
	assert_eq(journal.get_retained_bundle_text("run-a:1"), "", "a reset candidate clears the remembered texts even for a retained id")
	assert_eq(journal.get_retained_bundle_text("run-a:3"), "")
	assert_true(journal.get_retained_bundle_document("run-a:1").is_empty(),
		"a reset candidate clears the remembered document bundles too, retained id included")
	assert_true(journal.get_retained_bundle_document("run-a:3").is_empty())
	# A seed replaces history from disk: the seeded bundles' texts were never proven here.
	_commit_record(journal, "run-a", 2, &"line")
	assert_true(journal.remember_committed_bundle_text("run-a:2", "text-2b", _proof_document(2)))
	var bundle_1 := {"checkpoint_kind": "day_start", "snapshot": _snapshot("run-a", 1, 1)}
	var bundle_2 := {"checkpoint_kind": "line", "snapshot": _snapshot("run-a", 2)}
	var document: Dictionary = load(DOCUMENT_SCHEMA_PATH).build(&"autosave", null, &"automatic", bundle_2, [bundle_1])
	assert_true(document.get("ok", false), JSON.stringify(document))
	var seeded: Dictionary = journal.prepare_seed(document["value"], bundle_2)
	assert_true(seeded.get("ok", false), JSON.stringify(seeded))
	assert_true(journal.commit_prepared(seeded["value"]["candidate"]).get("ok", false))
	assert_eq((journal.get_bundles_for_disk() as Array).size(), 1, "the seed retained bundle 1")
	assert_eq(journal.get_retained_bundle_text("run-a:2"), "", "a seed commit clears the remembered texts")
	assert_eq(journal.get_retained_bundle_text("run-a:1"), "")
	assert_true(journal.get_retained_bundle_document("run-a:2").is_empty(),
		"a seed commit clears the remembered document bundles")
	# A restored backup is caller-supplied: the journal cannot prove its bytes, so it forgets.
	_commit_record(journal, "run-a", 3, &"post_result")
	assert_true(journal.remember_committed_bundle_text("run-a:3", "text-3b", _proof_document(3)))
	var backup: Dictionary = journal.capture_state()["value"]["backup"]
	assert_true(journal.restore_state(backup).get("ok", false))
	assert_eq(journal.get_retained_bundle_text("run-a:3"), "", "restore_state clears the remembered texts")
	assert_true(journal.get_retained_bundle_document("run-a:3").is_empty(),
		"restore_state clears the remembered document bundles")
	# reset() empties the journal outright.
	_commit_record(journal, "run-a", 4, &"post_result")
	assert_true(journal.remember_committed_bundle_text("run-a:4", "text-4", _proof_document(4)))
	assert_true(journal.reset("run-a").get("ok", false))
	assert_eq(journal.get_retained_bundle_text("run-a:4"), "", "reset() clears the remembered texts")
	assert_true(journal.get_retained_bundle_document("run-a:4").is_empty(),
		"reset() clears the remembered document bundles")


# -------------------------------------------------------------------------------------------------
# A4: prepare_record() pass-along. The checkpoint port hands prepare_record() the very snapshot object
# RunSnapshotSchema.build() just validated, and prepare_record() validates it a second time (~5-10 ms
# on a 150 KB snapshot). An optional third argument lets a caller say "this exact object is already a
# validate() candidate"; the proof is IDENTITY, never deep equality, and every other refusal and its
# order stay exactly where they are.
# -------------------------------------------------------------------------------------------------

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")

## Declared argument count of a journal method, defaults included. Asserted before the three-argument
## calls below so a tree without the optional parameter reports these rows as failed assertions: a
## wrong-arity call aborts the test function outright, which GUT records as risky rather than failed.
func _argument_count(instance: RefCounted, method_name: String) -> int:
	for method: Dictionary in instance.get_method_list():
		if str(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return -1


func test_prepare_record_takes_the_fast_path_only_for_the_identical_proven_candidate() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")
	if not _journal_exists():
		return
	var journal := _fresh("run-a")
	assert_eq(_argument_count(journal, "prepare_record"), 3,
		"prepare_record() must accept the optional already-validated candidate")

	# A snapshot RunSnapshotSchema.validate() refuses, whose run_id and checkpoint_sequence are still
	# readable -- so the ONLY thing that can let it through is a skipped validation.
	var refused_snapshot := _snapshot("run-a", 1)
	refused_snapshot["bogus"] = 1
	var unproven: Dictionary = journal.prepare_record(refused_snapshot, &"line")
	assert_false(unproven.get("ok", true), "the unproven path still validates")
	assert_eq(unproven["code"], &"invalid_snapshot_shape")

	var empty_proof: Dictionary = journal.prepare_record(refused_snapshot, &"line", {})
	assert_false(empty_proof.get("ok", true), "the empty default proves nothing")
	assert_eq(empty_proof["code"], &"invalid_snapshot_shape")

	var deep_equal: Dictionary = journal.prepare_record(refused_snapshot, &"line",
		refused_snapshot.duplicate(true))
	assert_false(deep_equal.get("ok", true),
		"a merely deep-equal proof is not the proof: a different object still validates")
	assert_eq(deep_equal["code"], &"invalid_snapshot_shape")

	var foreign: Dictionary = journal.prepare_record(refused_snapshot, &"line", {"not": "the snapshot"})
	assert_false(foreign.get("ok", true), "an unrelated proof still validates")
	assert_eq(foreign["code"], &"invalid_snapshot_shape")

	var proven: Dictionary = journal.prepare_record(refused_snapshot, &"line", refused_snapshot)
	assert_true(proven.get("ok", false), JSON.stringify(proven))
	assert_true(is_same(proven["value"]["candidate"]["current"]["snapshot"], refused_snapshot),
		"the proven path carries the caller's own already-validated object, not a fresh candidate")


func test_prepare_record_keeps_every_refusal_and_its_order_when_a_proof_is_supplied() -> void:
	assert_true(_journal_exists(), "CheckpointJournal must exist")
	if not _journal_exists():
		return
	var journal := _fresh("run-a")
	assert_eq(_argument_count(journal, "prepare_record"), 3,
		"prepare_record() must accept the optional already-validated candidate")
	var before: Dictionary = journal.capture_state()["value"]["backup"]

	var stale := _snapshot("run-a", 5)
	var wrong_sequence: Dictionary = journal.prepare_record(stale, &"line", stale)
	assert_false(wrong_sequence.get("ok", true), "a proof does not excuse the sequence cursor")
	assert_eq(wrong_sequence["code"], &"sequence_mismatch")

	var other_run := _snapshot("run-b", 1)
	var wrong_run: Dictionary = journal.prepare_record(other_run, &"line", other_run)
	assert_false(wrong_run.get("ok", true), "a proof does not excuse the owning run")
	assert_eq(wrong_run["code"], &"run_mismatch")

	var valid := _snapshot("run-a", 1)
	var unknown_kind: Dictionary = journal.prepare_record(valid, &"unknown", valid)
	assert_false(unknown_kind.get("ok", true), "a proof does not excuse the checkpoint kind")
	assert_eq(unknown_kind["code"], &"unknown_checkpoint_kind",
		"the kind check still refuses before anything else is read")
	assert_eq(journal.capture_state()["value"]["backup"], before,
		"failed preparation with a proof still leaves the journal byte-equal")

	# For the shape the port actually passes -- a RunSnapshotSchema.validate() candidate -- the proven
	# path must produce the candidate the full validation would have produced.
	var candidate_snapshot: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(valid)["value"]["candidate"]
	var proven: Dictionary = journal.prepare_record(candidate_snapshot, &"line", candidate_snapshot)
	assert_true(proven.get("ok", false), JSON.stringify(proven))
	var revalidated: Dictionary = journal.prepare_record(candidate_snapshot, &"line")
	assert_true(revalidated.get("ok", false), JSON.stringify(revalidated))
	assert_eq(proven["value"]["candidate"], revalidated["value"]["candidate"],
		"a proven candidate is byte-equal to the one a second validation produces")
	assert_eq(int(journal.peek_next_sequence("run-a")["value"]["checkpoint_sequence"]), 1,
		"preparation never consumes the cursor, proven or not")
