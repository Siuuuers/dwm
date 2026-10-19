extends "res://addons/gut/test.gd"
## Fresh cloud process AFTER differential correctness passes. Normal story
## registration, no DWM_SCENE_READING_FIXTURE. Source is retained checkpoint16,
## not invented checkpoint17 bytes or a completed lifecycle claim.
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ORIGINAL := preload("res://tests/support/OriginalSceneAnchorBridge.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const INPUT_SHA256 := "253bda51ce175b6bad6345a8932aad3dd70b22640c12f2223a8d9ba6dd58871e"

func test_complete_anchor_routine_matched_samples() -> void:
	var path := OS.get_environment("DWM_ANCHOR_INPUT_PATH")
	assert_false(path.is_empty(), "exact retained failure-saves-autosave.json required")
	if path.is_empty(): return
	assert_eq(FileAccess.get_sha256(path), INPUT_SHA256)
	if FileAccess.get_sha256(path) != INPUT_SHA256: return
	var parsed := PARSER.parse_object(FileAccess.get_file_as_string(path))
	assert_true(parsed.get("ok", false), str(parsed))
	if not parsed.get("ok", false): return
	var document: Dictionary = parsed.value
	var snapshots: Array = [document.current_snapshot.snapshot]
	for bundle: Dictionary in document.recovery_journal: snapshots.append(bundle.snapshot)
	var corpus: Array[Dictionary] = []
	for snapshot: Dictionary in snapshots:
		assert_eq(snapshot.scene.registration_sha256, MANIFEST.scene_registration_fingerprint())
		if snapshot.scene.registration_sha256 != MANIFEST.scene_registration_fingerprint(): return
		var checkpoint: Dictionary = snapshot.narrative_checkpoint
		if snapshot.lifecycle.get("ending_plan") is Dictionary and snapshot.lifecycle.ending_plan.get("source_kind") == "scene":
			checkpoint = snapshot.lifecycle.ending_plan.source_reading_checkpoint
		for receipt: Dictionary in snapshot.command_receipts.values():
			if receipt.get("kind") != "scene_event": continue
			corpus.append({"anchor": receipt.scene_event.reading_anchor.duplicate(true),
				"checkpoint": checkpoint.duplicate(true), "checkpoint_id": snapshot.checkpoint_id})
	assert_false(corpus.is_empty())
	if corpus.is_empty(): return
	var candidate := BRIDGE.new()
	var original := ORIGINAL.new()
	autofree(candidate)
	autofree(original)
	var before := var_to_bytes(corpus)
	# Untimed full-corpus correctness/warmup, preserving the original order.
	for item: Dictionary in corpus:
		var expected: Dictionary = original.validate_scene_event_anchor(item.anchor, item.checkpoint)
		var actual: Dictionary = candidate.validate_scene_event_anchor(item.anchor, item.checkpoint)
		assert_eq(expected, {"ok": true})
		assert_eq(var_to_bytes(actual), var_to_bytes(expected))
		if expected != {"ok": true} or actual != expected: return
	assert_eq(var_to_bytes(corpus), before)
	for pair: int in 6:
		var order: Array = [original, candidate] if pair % 2 == 0 else [candidate, original]
		for owner: Node in order:
			var started := Time.get_ticks_usec()
			var outputs: Array[Dictionary] = []
			for item: Dictionary in corpus:
				outputs.append(owner.validate_scene_event_anchor(item.anchor, item.checkpoint))
			var elapsed := Time.get_ticks_usec() - started
			for result: Dictionary in outputs: assert_eq(result, {"ok": true})
			assert_eq(var_to_bytes(corpus), before)
			print("DWM_ANCHOR_ALGORITHM_SAMPLE " + JSON.stringify({"pair": pair,
				"variant": "original" if owner == original else "candidate",
				"calls": corpus.size(), "elapsed_us": elapsed,
				"scope": "complete_validate_scene_event_anchor", "input_sha256": INPUT_SHA256,
				"checkpoint_sequences": [16, 8, 9, 14, 15]}))
