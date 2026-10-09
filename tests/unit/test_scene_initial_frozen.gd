extends "res://addons/gut/test.gd"
## Structural frame derivation only. Admission authentication belongs to the
## candidate/committed contract paths; these results do not prove creation.
const BASE := preload("res://tests/support/SceneDayReadingFixture.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const PRESENTATION := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const FROZEN := preload("res://scripts/narrative/FrozenRunContext.gd")
const OCCURRENCE := "TEST.initial.creation"
var reading: Dictionary
var admission: Dictionary

func before_all() -> void:
	assert_true(BASE.configure().ok)

func before_each() -> void:
	var target_id := ""
	for row: Dictionary in MANIFEST.scene_registration().value.targets:
		if row.target.kind == "scene" and row.target.entry_id == BASE.A:
			target_id = row.target_id
	assert_false(target_id.is_empty())
	admission = {"kind": "scene_initial_admitted", "occurrence_id": OCCURRENCE,
		"entry_id": BASE.A, "target_id": target_id}
	var presentation: Dictionary = PRESENTATION.build(BASE.A, {"entry_id": BASE.A,
		"entry_role": "scene", "occurrence_id": OCCURRENCE, "admission_receipt_id": OCCURRENCE})
	assert_true(presentation.ok)
	var frame := {"expected_stage": "scene", "playback_id": OCCURRENCE, "role": "scene",
		"transaction_id": OCCURRENCE, "presentation": presentation.value}
	var session: RefCounted = SESSION.new()
	assert_true(session.configure_scene().ok)
	assert_true(session.begin_scene(OCCURRENCE).ok)
	assert_true(session.admit_scene(BASE.A, frame).ok)
	var programme: Dictionary = session.entry_program(BASE.A, frame)
	assert_true(programme.ok)
	var publication: Dictionary = session.ledger.allocate_publication(OCCURRENCE, BASE.A, OCCURRENCE)
	assert_true(publication.ok)
	assert_true(session.ledger.publish_line(OCCURRENCE, publication.value, BASE.A,
		programme.value.lines[0].line_id, OCCURRENCE).ok)
	var captured: Dictionary = session.capture(BASE.frontier(session))
	assert_true(captured.ok)
	reading = captured.value

func test_initial_result_derives_frame_without_source_checkpoint() -> void:
	var result: Dictionary = FROZEN.derive_scene_frames({OCCURRENCE: admission}, reading)
	assert_true(result.ok)
	if result.ok: assert_eq(result.value.entry_contexts, reading.ledger.entry_contexts)

func test_initial_result_rejects_legacy_extras_and_foreign_identity() -> void:
	for key: String in ["source_checkpoint", "trigger_command_id", "return_to"]:
		var altered: Dictionary = admission.duplicate(true)
		altered[key] = null
		assert_false(FROZEN.derive_scene_frames({OCCURRENCE: altered}, reading).ok)
	for key: String in ["occurrence_id", "entry_id", "target_id"]:
		var altered: Dictionary = admission.duplicate(true)
		altered[key] = "TEST.foreign"
		assert_false(FROZEN.derive_scene_frames({OCCURRENCE: altered}, reading).ok)

func test_later_result_still_requires_complete_source_checkpoint() -> void:
	var later: Dictionary = admission.duplicate(true)
	later.kind = "scene_admitted"
	later.merge({"source_checkpoint": {"checkpoint_id": "TEST.source", "checkpoint_sequence": 1,
		"snapshot_sha256": "a".repeat(64)}, "trigger_command_id": null, "return_to": null})
	assert_true(FROZEN.derive_scene_frames({OCCURRENCE: later}, reading).ok)
	later.source_checkpoint = null
	assert_false(FROZEN.derive_scene_frames({OCCURRENCE: later}, reading).ok)
	later.erase("source_checkpoint")
	assert_false(FROZEN.derive_scene_frames({OCCURRENCE: later}, reading).ok)
