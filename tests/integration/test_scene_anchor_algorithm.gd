extends "res://addons/gut/test.gd"
## Same full scene5 routine and inputs; original tail uses snapshot + scan.
## Dedicated process with DWM_SCENE_READING_FIXTURE=1; no native playback proof.
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ORIGINAL := preload("res://tests/support/OriginalSceneAnchorBridge.gd")
const FIXTURE := preload("res://tests/support/SceneAnchorAlgorithmFixture.gd")
const LEDGER := preload("res://scripts/narrative/NarrativeCaptionLedger.gd")
var candidate: Node
var original: Node
var corpus: Dictionary = {}

func before_all() -> void:
	candidate = BRIDGE.new()
	original = ORIGINAL.new()
	var made := FIXTURE.build()
	assert_true(made.get("ok", false), str(made))
	if made.get("ok", false): corpus = made.value

func after_all() -> void:
	if is_instance_valid(candidate): candidate.free()
	if is_instance_valid(original): original.free()

func _compare(anchor: Dictionary, checkpoint: Dictionary, succeeds: bool, label: String) -> void:
	var before := var_to_bytes([anchor, checkpoint])
	var expected: Dictionary = original.validate_scene_event_anchor(anchor, checkpoint)
	assert_eq(var_to_bytes([anchor, checkpoint]), before, label + ": original input immutability")
	var actual: Dictionary = candidate.validate_scene_event_anchor(anchor, checkpoint)
	assert_eq(actual, expected, label + ": complete result")
	assert_eq(var_to_bytes(actual), var_to_bytes(expected), label + ": result types and bytes")
	assert_eq(actual.get("ok", false), succeeds, label + ": positive/negative expectation")
	assert_eq(var_to_bytes([anchor, checkpoint]), before, label + ": candidate input immutability")
	# Returned results must not expose caller-owned containers.
	actual["test_mutation"] = {"changed": true}
	assert_eq(var_to_bytes([anchor, checkpoint]), before, label + ": output detachment")

func test_current_and_historical_occurrences_match_original() -> void:
	assert_false(corpus.is_empty())
	if corpus.is_empty(): return
	for index: int in [0, 7, 13]:
		_compare(corpus.anchors[index], corpus.checkpoint, true, "publication:%d" % index)
	# Terminal validation supplies this exact retained source checkpoint; it
	# must use the historical occurrence, never today's active/live frontier.
	var terminal := {"source_kind": "scene", "source_reading_checkpoint": corpus.checkpoint.duplicate(true)}
	_compare(corpus.anchors[0], terminal.source_reading_checkpoint, true, "terminal source input")

func test_missing_and_mismatched_anchor_fields_match_original() -> void:
	assert_false(corpus.is_empty())
	if corpus.is_empty(): return
	for field: String in ["session_id", "entry_id", "publication_id", "line_id", "catalogue_fingerprint", "content_version"]:
		var anchor: Dictionary = corpus.anchors[0].duplicate(true)
		anchor[field] = 999 if field == "content_version" else "missing:" + field
		_compare(anchor, corpus.checkpoint, false, field)
	# Existing frame with a real publication from another occurrence.
	var crossed: Dictionary = corpus.anchors[0].duplicate(true)
	crossed.publication_id = corpus.anchors[1].publication_id
	_compare(crossed, corpus.checkpoint, false, "crossed publication/occurrence")

func test_late_duplicate_conflict_and_malformed_rows_still_refuse_before_membership() -> void:
	assert_false(corpus.is_empty())
	if corpus.is_empty(): return
	for mode: String in ["duplicate", "conflict", "malformed", "invalid_frame", "noncanonical_frame"]:
		var checkpoint: Dictionary = corpus.checkpoint.duplicate(true)
		var ledger: Dictionary = checkpoint.reading_session.ledger
		match mode:
			"duplicate": ledger.captions.append(ledger.captions[0].duplicate(true))
			"conflict":
				var row: Dictionary = ledger.captions[1].duplicate(true)
				row.publication_id = ledger.captions[0].publication_id
				ledger.captions.append(row)
			"malformed": ledger.captions.append({"publication_id": "later-invalid"})
			"invalid_frame":
				var key := LEDGER.scene_frame_key(corpus.anchors[13].session_id, corpus.anchors[13].entry_id)
				ledger.entry_contexts[key].presentation.fields.occurrence_id = "wrong"
			"noncanonical_frame":
				var key := LEDGER.scene_frame_key(corpus.anchors[13].session_id, corpus.anchors[13].entry_id)
				ledger.entry_contexts[" " + key] = ledger.entry_contexts[key]
				ledger.entry_contexts.erase(key)
		_compare(corpus.anchors[0], checkpoint, false, mode)

func test_multiple_faults_preserve_first_refusal() -> void:
	assert_false(corpus.is_empty())
	if corpus.is_empty(): return
	var checkpoint: Dictionary = corpus.checkpoint.duplicate(true)
	checkpoint.reading_session.ledger.captions.append({})
	var anchor: Dictionary = corpus.anchors[0].duplicate(true)
	anchor.content_version = 1.0
	_compare(anchor, checkpoint, false, "anchor shape before bad restore")
	anchor = corpus.anchors[0].duplicate(true)
	anchor.catalogue_fingerprint = "bad"
	_compare(anchor, checkpoint, false, "bad restore before catalogue mismatch")
	anchor.publication_id = "missing"
	_compare(anchor, corpus.checkpoint, false, "catalogue before missing publication")

func test_repeated_invocation_does_not_reuse_prior_checkpoint_or_verdict() -> void:
	assert_false(corpus.is_empty())
	if corpus.is_empty(): return
	var anchor: Dictionary = corpus.anchors[0].duplicate(true)
	var checkpoint: Dictionary = corpus.checkpoint.duplicate(true)
	_compare(anchor, checkpoint, true, "initial")
	checkpoint.reading_session.ledger.captions[0].publication_id = "replaced"
	_compare(anchor, checkpoint, false, "same caller object changed")
	anchor.publication_id = "replaced"
	_compare(anchor, checkpoint, true, "new exact membership")
	_compare(corpus.anchors[0], corpus.checkpoint, true, "original remains detached")
