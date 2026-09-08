extends SceneTree
## Read-only validation of scene DTLs, stable semantic entries, and legacy timeline labels.
## Run with -s res://tools/dialogic/validate_dialogic_contract.gd.

const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const VALIDATOR := preload("res://tools/dialogic/DtlStructureValidator.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const SCENE_ROOT := "res://dialogic/timelines/en/"
const MAX_REPORTED := 10


func _init() -> void:
	quit(_run())


func _run() -> int:
	var loaded: Dictionary = MANIFEST.load_default()
	if not loaded.get("ok", false): return _fail("load entries", loaded)
	var document: Dictionary = loaded["value"]
	var validated: Dictionary = MANIFEST.validate_document(document)
	if not validated.get("ok", false): return _fail("validate entries", validated)
	var timelines: Dictionary = STRICT_JSON.parse_object(
		FileAccess.get_file_as_string("res://data/manifests/timelines.json"))
	if not timelines.get("ok", false): return _fail("load timelines", timelines)
	var partition: Dictionary = VALIDATOR.partition_by_master(document)
	var legacy := {}
	for record: Dictionary in timelines["value"].get("records", []):
		var path := "res://" + str(record["path"])
		legacy[path] = record["labels"]
		if not partition.has(path): partition[path] = []
	var failed := 0
	for path: String in partition:
		if not path.begins_with(SCENE_ROOT) or not path.trim_prefix(SCENE_ROOT).contains("/"):
			print("DIALOGIC_CONTRACT: FAIL scene path " + path)
			failed += 1
			continue
		var result: Dictionary = VALIDATOR.validate_file(path, partition[path], legacy.get(path, []))
		if result.get("ok", false): continue
		failed += 1
		for failure: Dictionary in (result["failures"] as Array).slice(0, MAX_REPORTED):
			print("DIALOGIC_CONTRACT: FAIL %s:%d %s" % [path, failure["line"], failure["code"]])
	if failed > 0: return 1
	print("DIALOGIC_CONTRACT: PASS scenes=%d entries=%d" % [partition.size(), document["entry_count"]])
	return 0


func _fail(stage: String, result: Dictionary) -> int:
	print("DIALOGIC_CONTRACT: FAIL %s -> %s" % [stage, str(result)])
	return 1
