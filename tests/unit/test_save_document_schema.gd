extends "res://addons/gut/test.gd"

const SCHEMA_PATH := "res://scripts/infrastructure/save/SaveDocumentSchema.gd"
const VALID_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"

const VALID_DISCRIMINATORS := [
	{"kind": &"slot", "slot_id": 1, "save_reason": &"manual"},
	{"kind": &"quick", "slot_id": null, "save_reason": &"quick"},
	{"kind": &"autosave", "slot_id": null, "save_reason": &"automatic"},
	{"kind": &"autosave", "slot_id": null, "save_reason": &"day_start"},
	{"kind": &"autosave", "slot_id": null, "save_reason": &"ending"},
	{"kind": &"autosave", "slot_id": null, "save_reason": &"pre_board"},
	{"kind": &"autosave", "slot_id": null, "save_reason": &"logout"},
]

func _schema_exists() -> bool:
	return ResourceLoader.exists(SCHEMA_PATH, "Script")

## Test-authored current cases reuse historical fixture payloads without changing those files.
## Explicit Dark=false and removed retired fields are fixture authoring, never a save migration.
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

func _current_fixture(snapshot: Dictionary) -> Dictionary:
	var upgraded := snapshot.duplicate(true)
	upgraded["schema_version"] = 6
	upgraded["gameplay"].erase("opening_seen")
	upgraded["gameplay"].erase("tutorial_seen")
	var lifecycle: Dictionary = (upgraded["lifecycle"] as Dictionary).duplicate(true)
	lifecycle["dark_mode"] = false
	lifecycle["active_condition_hospital_plan"] = null
	lifecycle["condition_hospital_history"] = {}
	lifecycle["terminal_intent_handoff"] = null
	if not lifecycle.has("branch_id"):
		lifecycle["branch_id"] = "branch-1"
		lifecycle["desktop_timeline_generation"] = 0
		lifecycle["causal_day_instance"] = "causal-day-1"
		lifecycle["causal_day_instance_issuer_receipt"] = _issuer_receipt("causal-day-1")
		lifecycle["restore_provenance"] = null
	upgraded["lifecycle"] = lifecycle
	if not upgraded.has("desktop"):
		upgraded["desktop"] = _empty_desktop()
	upgraded["schedule_view"] = {
		"day": lifecycle["day"], "causal_day_instance": lifecycle["causal_day_instance"],
		"entries": [], "date_entry_seen": false, "pending_warning": null,
		"consumed_warning_receipts": {}, "condition_departure_receipts": {},
	}
	return upgraded

func _fixture_snapshot() -> Dictionary:
	return _current_fixture(JSON.parse_string(FileAccess.get_file_as_string(VALID_FIXTURE)))

func _bundle() -> Dictionary:
	return {
		"checkpoint_kind": "day_start",
		"snapshot": _fixture_snapshot(),
	}

func test_save_document_schema_exists() -> void:
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")

func test_quick_document_build_round_trips_json_null_slot_id() -> void:
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var snapshot: Dictionary = _fixture_snapshot()
	var bundle := {"checkpoint_kind": "day_start", "snapshot": snapshot}
	var built: Dictionary = load(SCHEMA_PATH).build(&"quick", null, &"quick", bundle, [])
	assert_true(built["ok"], JSON.stringify(built))
	var decoded: Variant = JSON.parse_string(JSON.stringify(built["value"]))
	assert_eq(typeof(decoded), TYPE_DICTIONARY)
	assert_true(decoded.has("slot_id"))
	assert_null(decoded["slot_id"])
	assert_true(load(SCHEMA_PATH).validate(decoded)["ok"])
	assert_false(load(SCHEMA_PATH).build(&"quick", -1, &"quick", bundle, [])["ok"])
	assert_false(load(SCHEMA_PATH).build(&"slot", null, &"manual", bundle, [])["ok"])

func test_discriminator_matrix() -> void:
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	for discriminator: Dictionary in VALID_DISCRIMINATORS:
		var built: Dictionary = schema.build(
			discriminator["kind"], discriminator["slot_id"], discriminator["save_reason"], _bundle(), [])
		assert_true(built.get("ok", false),
			JSON.stringify(discriminator) + ": " + JSON.stringify(built))
		assert_true(schema.validate(built["value"])["ok"], JSON.stringify(discriminator))
	assert_false(schema.build(&"slot", 0, &"manual", _bundle(), []).get("ok", true), "slot 0 rejects")
	assert_false(schema.build(&"slot", 8, &"manual", _bundle(), []).get("ok", true), "slot 8 rejects")
	assert_false(schema.build(&"autosave", 3, &"automatic", _bundle(), []).get("ok", true),
		"autosave with an integer slot rejects")
	assert_false(schema.build(&"autosave", null, &"manual", _bundle(), []).get("ok", true),
		"autosave with a slot reason rejects")
	assert_false(schema.build(&"quick", null, &"automatic", _bundle(), []).get("ok", true),
		"quick with a non-quick reason rejects")
	assert_false(schema.build(&"logout", null, &"logout", _bundle(), []).get("ok", true),
		"there is no fourth logout kind")

func test_validate_rejects_malformed_documents() -> void:
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var built: Dictionary = schema.build(&"slot", 1, &"manual", _bundle(), [])
	assert_true(built["ok"])
	var document: Dictionary = built["value"]

	var missing_discriminator: Dictionary = document.duplicate(true)
	missing_discriminator.erase("slot_id")
	assert_false(schema.validate(missing_discriminator).get("ok", true),
		"omitted discriminator field rejects")

	var extra_key: Dictionary = document.duplicate(true)
	extra_key["extra"] = 1
	assert_false(schema.validate(extra_key).get("ok", true), "unknown top-level key rejects")

	var bad_snapshot: Dictionary = document.duplicate(true)
	bad_snapshot["current_snapshot"]["snapshot"]["lifecycle"]["day"] = 8
	assert_false(schema.validate(bad_snapshot).get("ok", true), "embedded Day-8 snapshot rejects")

	var bad_journal: Dictionary = document.duplicate(true)
	bad_journal["recovery_journal"] = [{"entry": &"stringname"}]
	assert_false(schema.validate(bad_journal).get("ok", true), "non-primitive journal entry rejects")

	# v6 is current; the unsupported-future probe must remain newer.
	var future: Dictionary = document.duplicate(true)
	future["schema_version"] = 7
	assert_false(schema.validate(future).get("ok", true), "unsupported future document version rejects")

func test_document_version_is_six_and_embedded_snapshot_version_must_agree() -> void:
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	assert_eq(int(schema.DOCUMENT_VERSION), 6)
	var built: Dictionary = schema.build(&"slot", 1, &"manual", _bundle(), [])
	assert_true(built["ok"], JSON.stringify(built))
	var document: Dictionary = built["value"]
	assert_eq(int(document["schema_version"]), 6)
	assert_eq(int(document["current_snapshot"]["snapshot"]["schema_version"]), 6)
	# A current document whose embedded snapshot carries an older tag disagrees and rejects.
	var skewed: Dictionary = document.duplicate(true)
	(skewed["current_snapshot"]["snapshot"] as Dictionary)["schema_version"] = 3
	assert_false(schema.validate(skewed).get("ok", true),
		"a document/embedded-snapshot version mismatch rejects")

func test_prepare_candidate_is_detached() -> void:
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var built: Dictionary = schema.build(&"autosave", null, &"day_start", _bundle(), [])
	assert_true(built["ok"])
	var prepared: Dictionary = schema.prepare_candidate(built["value"])
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	built["value"]["recovery_journal"].append({"mutated": true})
	assert_eq((prepared["value"]["candidate"]["recovery_journal"] as Array).size(), 0,
		"prepared candidate is recursively detached")
