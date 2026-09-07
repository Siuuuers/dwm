class_name MinesweeperBoardGenerationPort
extends RefCounted

## Production name-and-envelope adapter between MinesweeperRoundCoordinator's generation seam and
## the manifest-validating MinesweeperBoardGenerator. It owns no search state: every frontier is a
## detached, validated preparation that can be checkpointed and supplied to a later slice.

const _GENERATOR := preload("res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd")


func materialize(spec: Dictionary, forced_cell: int) -> Dictionary:
	var generated: Dictionary = _GENERATOR.materialize_first_reveal(spec, forced_cell)
	if not generated.get("ok", false):
		return generated
	var value: Dictionary = generated["value"]
	return _ok({"layout": (value["layout"] as Dictionary).duplicate(true)})


func begin_search(spec: Dictionary) -> Dictionary:
	var begun: Dictionary = _GENERATOR.begin_debug(spec)
	if not begun.get("ok", false):
		return begun
	var preparation: Dictionary = begun["value"]["preparation"]
	return _ok({"frontier": preparation.duplicate(true)})


func run_search_slice(frontier: Dictionary) -> Dictionary:
	var advanced: Dictionary = _GENERATOR.run_debug_slice(frontier)
	if not advanced.get("ok", false):
		return advanced
	var preparation: Dictionary = advanced["value"]["preparation"]
	var status := str(preparation["status"])
	if status == "searching":
		return _ok({"done": false, "frontier": preparation.duplicate(true)})
	if status != "certified":
		return _fail(&"generation_search_status_invalid",
			"the production generator returned an unsupported terminal search status",
			{"status": status})

	var spec: Dictionary = preparation["spec"]
	var candidate: Dictionary = preparation["candidate_state"]
	var layout := {
		"schema_version": 1,
		"width": int(spec["width"]),
		"height": int(spec["height"]),
		"mine_indices": (candidate["mine_indices"] as Array).duplicate(),
		"mine_count": int(candidate["mine_count"]),
	}
	return _ok({
		"done": true,
		"layout": layout,
		"forced_cell": int(preparation["forced_cell"]),
		# The generator proves certification internally but its persisted preparation contract does
		# not retain the verifier trace digest. The coordinator explicitly permits null here.
		"proof_sha256": null,
	})


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
