extends "res://addons/gut/test.gd"
## The eight-master migration is historical evidence, superseded by the user's scene-layout
## decision on 2026-09-08. Validate its recorded claims without enforcing old disk hashes/paths.

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const ENTRIES := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const HISTORY := "res://data/migrations/dialogic_61_to_8.json"
const SCHEMA := "res://schemas/manifests/dialogic-migration.schema.json"


func _load(path: String) -> Dictionary:
	return STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))["value"]


func test_historical_migration_retains_its_source_provenance_and_original_schema() -> void:
	var history := _load(HISTORY)
	assert_eq(history["source_commit"], "4551f7c51b01baa21de3a080978920e951b42d60")
	assert_eq(history["master_timeline_count"], 8, "historical claim, not a current layout requirement")
	var result: Dictionary = JsonSchemaValidator.validate(history, _load(SCHEMA))
	assert_true(result.get("ok", false), str(result))


func test_semantic_targets_survive_the_superseded_physical_migration() -> void:
	var document: Dictionary = ENTRIES.load_default()["value"]
	var ids := {}
	for entry: Dictionary in document["entries"]: ids[entry["entry_id"]] = true
	for transformation: Dictionary in _load(HISTORY)["transformations"]:
		for entry_id: String in transformation["target_entry_ids"]:
			assert_true(ids.has(entry_id), "retained semantic target: " + entry_id)


func test_retired_true_ending_labels_are_still_refused() -> void:
	var document: Dictionary = ENTRIES.load_default()["value"]
	for entry_id: String in ["ending.lavinia.true", "ending.priscilla.true", "ending.sylvia.true"]:
		assert_false(ENTRIES.resolve_entry(document, entry_id, "en").get("ok", true))
