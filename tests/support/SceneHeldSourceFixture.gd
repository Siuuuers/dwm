extends RefCounted
## TEST-only owner simulation. This never writes Save8, issues causal receipts,
## or claims that the synthetic checkpoint references are durable storage proof.
const BASE := preload("res://tests/support/SceneDayReadingFixture.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PATH := "res://tests/fixtures/dialogic/scene_day_terminal.dtl"

static func target(target_id: String) -> Dictionary:
	var selected := BASE.MANIFEST.scene_registration()
	if not selected.ok: return {}
	for row: Dictionary in selected.value.targets:
		if row.target_id == target_id: return row.target.duplicate(true)
	return {}

static func binding(target_id: String, occurrence: String) -> Dictionary:
	return {"operation_id": "held:test:operation:" + target_id,
		"source_checkpoint": {"checkpoint_id": "held:test:source", "checkpoint_sequence": 1,
			"snapshot_sha256": "2".repeat(64)}, "source_occurrence_id": "b:held",
		"trigger_command_id": "held:test:trigger", "target_id": target_id,
		"target_occurrence_id": occurrence, "admission_receipt_id": "test:receipt:" + occurrence,
		"registration_sha256": BASE.MANIFEST.scene_registration_fingerprint()}

class SimulatedCheckpointPort:
	extends RefCounted
	var capability := ""
	var binding: Dictionary = {}
	var checkpoint: Dictionary = {}
	var confirmed := false
	var uncertain := false
	var corrupt := false
	var consumed := false
	var consumes := 0
	var retains := 0
	var on_retain: Callable
	var on_consume: Callable

	func retain_scene_entry(_bridge: Object, id: String, owner_binding: Dictionary, candidate: Dictionary) -> Dictionary:
		retains += 1
		capability = id
		binding = owner_binding.duplicate(true)
		checkpoint = candidate.duplicate(true)
		if on_retain.is_valid(): on_retain.call()
		return {"ok": true}

	func consume_scene_entry_ack(id: String) -> Dictionary:
		consumes += 1
		if on_consume.is_valid(): on_consume.call()
		if uncertain: return {"ok": false}
		if not confirmed: return {"ok": false, "committed": false}
		if consumed or id != capability: return {"ok": false}
		consumed = true
		var writer := preload("res://scripts/validation/CanonicalJsonWriter.gd")
		return {"ok": true, "value": {"capability_id": capability, "operation_id": binding.operation_id,
			"source_checkpoint": binding.source_checkpoint.duplicate(true),
			"target_checkpoint": {"checkpoint_id": "held:test:target", "checkpoint_sequence": 2,
				"snapshot_sha256": "3".repeat(64)},
			"binding_sha256": "0".repeat(64) if corrupt else str(writer.stringify(binding).value).sha256_text(),
			"narrative_checkpoint_sha256": str(writer.stringify(checkpoint).value).sha256_text()}}

