extends "res://addons/gut/test.gd"

const SCHEMA_PATH := "res://scripts/infrastructure/save/SaveDocumentSchema.gd"
const VALID_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"
const RUN_SNAPSHOT_SCHEMA_PATH := "res://scripts/domain/run/RunSnapshotSchema.gd"
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

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


func test_current_and_recovery_snapshots_normalize_engine_text_without_mutating_source() -> void:
	var current := _bundle()
	var earlier := _bundle()
	current.snapshot.desktop.board.phase = &"NONE"
	earlier.snapshot.desktop.board.phase = &"NONE"
	var built: Dictionary = load(SCHEMA_PATH).build(&"autosave", null, &"automatic", current, [earlier])
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false): return
	assert_eq(typeof(built.value.current_snapshot.snapshot.desktop.board.phase), TYPE_STRING)
	assert_eq(typeof(built.value.recovery_journal[0].snapshot.desktop.board.phase), TYPE_STRING)
	assert_eq(typeof(current.snapshot.desktop.board.phase), TYPE_STRING_NAME)
	assert_eq(typeof(earlier.snapshot.desktop.board.phase), TYPE_STRING_NAME)
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(built.value))
	assert_true(load(SCHEMA_PATH).validate(round_trip).get("ok", false))


func test_build_keeps_numeric_normalization_and_detaches_current_history_and_time() -> void:
	var schema: Script = load(SCHEMA_PATH)
	var current := _bundle()
	current.snapshot.schema_version = 6.0
	var history := [{"count": 4.0, "nested": [&"hint", 2.25]}]
	var saved_time := {"unix_seconds": 0.0, "utc_offset_minutes": 0.0, "hhmm": "00:00"}
	var built: Dictionary = schema.build(&"autosave", null, &"automatic", current, history, saved_time)
	assert_true(built.ok, str(built))
	assert_eq(typeof(built.value.current_snapshot.snapshot.schema_version), TYPE_INT)
	assert_eq(typeof(built.value.recovery_journal[0].count), TYPE_INT)
	assert_eq(built.value.recovery_journal[0].nested, ["hint", 2.25])
	assert_eq(typeof(built.value.saved_time.unix_seconds), TYPE_INT)
	assert_eq(schema.validate(built.value).value.candidate, built.value, "external validation agrees with built document")
	built.value.recovery_journal[0].nested.append("changed")
	built.value.saved_time.hhmm = "01:00"
	assert_eq(history[0].nested.size(), 2)
	assert_eq(typeof(history[0].count), TYPE_FLOAT)
	assert_eq(typeof(current.snapshot.schema_version), TYPE_FLOAT)
	assert_eq(saved_time.hhmm, "00:00")


func test_build_keeps_invalid_bundle_journal_and_metadata_rejection_order() -> void:
	var schema: Script = load(SCHEMA_PATH)
	var invalid_time := {"broken": true}
	assert_eq(schema.build(&"autosave", null, &"automatic", {"unknown": true},
		[{"unsupported": Vector2.ZERO}], invalid_time).code, &"invalid_bundle_shape")
	assert_eq(schema.build(&"autosave", null, &"automatic", _bundle(),
		[{"unsupported": Vector2.ZERO}], invalid_time).code, &"invalid_recovery_journal")
	assert_eq(schema.build(&"autosave", null, &"automatic", _bundle(), [], invalid_time).code,
		&"invalid_saved_time")
	var corrupt := _bundle()
	corrupt.snapshot.lifecycle.day = 8
	assert_false(schema.build(&"autosave", null, &"automatic", corrupt, []).ok)


func test_validate_normalizes_the_document_without_a_prior_deep_copy() -> void:
	# A1: validate() deep-copies the whole document and then hands the copy to
	# _normalize_integral_floats, which already allocates a fresh Dictionary or Array at EVERY
	# container node. The copy is pure waste. Removing it is allocation-only -- the normalizer's
	# output is the same tree either way -- so the source text is the observable, in the idiom of
	# test_contact_scene_authors_no_identity_or_global_state_fallback.
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var source := FileAccess.get_file_as_string(SCHEMA_PATH)
	assert_false(source.is_empty(), "the schema source must be readable")
	assert_false(source.contains("_normalize_integral_floats(document.duplicate(true))"),
		"validate() must not deep-copy the document before a walk that rebuilds every container")

	# The invariant that makes the copy removable, asserted against the owning module.
	var run_schema: Script = load(RUN_SNAPSHOT_SCHEMA_PATH)
	var tree := {"envelope": {"nested": [1.0, {"leaf": 2.0}]}}
	var normalized: Variant = run_schema._normalize_integral_floats(tree)
	assert_false(is_same(normalized, tree), "the normalizer allocates a fresh root")
	assert_false(is_same(normalized["envelope"], tree["envelope"]),
		"the normalizer allocates a fresh Dictionary at every node")
	assert_false(is_same(normalized["envelope"]["nested"], tree["envelope"]["nested"]),
		"the normalizer allocates a fresh Array at every node")
	assert_eq(typeof(normalized["envelope"]["nested"][0]), TYPE_INT, "integral floats still normalize")
	assert_eq(typeof(tree["envelope"]["nested"][0]), TYPE_FLOAT, "the normalizer never mutates its source")

	# Detachment survives the removal: the document handed back shares no container with its source.
	var schema: Script = load(SCHEMA_PATH)
	var built: Dictionary = schema.build(&"autosave", null, &"day_start", _bundle(), [{"kept": [1, 2]}])
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false):
		return
	var document: Dictionary = built["value"]
	var validated: Dictionary = schema.validate(document)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false):
		return
	var candidate: Dictionary = validated["value"]["candidate"]
	assert_false(is_same(candidate, document), "the candidate is not the caller's document")
	assert_false(is_same(candidate["recovery_journal"], document["recovery_journal"]),
		"a depth-1 member is not shared")
	assert_false(is_same(candidate["recovery_journal"][0], document["recovery_journal"][0]),
		"a depth-2 member is not shared")
	assert_false(is_same(candidate["recovery_journal"][0]["kept"], document["recovery_journal"][0]["kept"]),
		"a depth-3 member is not shared")
	assert_false((candidate["recovery_journal"] as Array).is_typed(),
		"the normalized journal stays an untyped Array")
	(document["recovery_journal"][0]["kept"] as Array).append("late")
	assert_eq((candidate["recovery_journal"][0]["kept"] as Array).size(), 2,
		"mutating the source cannot reach a candidate already handed out")
	(candidate["recovery_journal"][0]["kept"] as Array).append("injected")
	assert_eq((document["recovery_journal"][0]["kept"] as Array).size(), 3,
		"mutating the candidate cannot reach the source")

func test_validate_composes_the_current_bundle_instead_of_renormalizing_it() -> void:
	# A2: validate()'s whole-document normalization walk rebuilds current_snapshot.snapshot and then
	# throws the rebuild away -- _validate_bundle's own candidate overwrites it one line later. The
	# fix normalizes per envelope member and composes the current bundle from its two already-proven
	# parts; the composition is observable as a fixed member order on the returned candidate, which
	# no whole-document walk can produce because that walk preserves the caller's insertion order.
	# Member order is not a disk observable: CanonicalJsonWriter sorts every object's keys.
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var built: Dictionary = schema.build(&"autosave", null, &"automatic", _bundle(), [{"count": 1}],
		{"unix_seconds": 0, "utc_offset_minutes": 0, "hhmm": "00:00"})
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false):
		return
	var document: Dictionary = (built["value"] as Dictionary).duplicate(true)
	document["schema_version"] = 6.0
	(document["saved_time"] as Dictionary)["unix_seconds"] = 0.0
	(document["recovery_journal"][0] as Dictionary)["count"] = 4.0
	(document["current_snapshot"]["snapshot"]["lifecycle"] as Dictionary)["day"] = 3.0
	var bundle: Dictionary = document["current_snapshot"]
	# Authored snapshot-first: a bundle carried through the whole-document walk keeps this order,
	# a composed one cannot.
	document["current_snapshot"] = {
		"snapshot": bundle["snapshot"], "checkpoint_kind": bundle["checkpoint_kind"],
	}
	var validated: Dictionary = schema.validate(document)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false):
		return
	var candidate: Dictionary = validated["value"]["candidate"]
	var bundle_keys: Array = (candidate["current_snapshot"] as Dictionary).keys()
	assert_eq(bundle_keys.size(), 2, "the current bundle has exactly two members")
	assert_eq(str(bundle_keys[0]), "checkpoint_kind",
		"validate composes the current bundle from its two proven parts")
	assert_eq(str(bundle_keys[1]), "snapshot",
		"validate composes the current bundle from its two proven parts")

	# Every member that is NOT the current bundle must still be normalized by validate itself.
	assert_eq(typeof(candidate["schema_version"]), TYPE_INT, "the envelope still normalizes")
	assert_eq(typeof((candidate["saved_time"] as Dictionary)["unix_seconds"]), TYPE_INT,
		"optional metadata still normalizes")
	assert_eq(typeof((candidate["recovery_journal"][0] as Dictionary)["count"]), TYPE_INT,
		"the recovery journal still normalizes")
	assert_false((candidate["recovery_journal"] as Array).is_typed(),
		"the normalized journal stays an untyped Array")
	# ...and the embedded snapshot must still be normalized, by its own owner.
	assert_eq(typeof(candidate["current_snapshot"]["snapshot"]["lifecycle"]["day"]), TYPE_INT,
		"the embedded snapshot is normalized by RunSnapshotSchema.validate")
	assert_eq(int(candidate["current_snapshot"]["snapshot"]["lifecycle"]["day"]), 3,
		"normalization preserves the value")
	assert_eq(str(candidate["current_snapshot"]["checkpoint_kind"]), "day_start",
		"the composed bundle carries the proven checkpoint_kind")
	assert_eq(typeof(document["schema_version"]), TYPE_FLOAT, "the caller's document is never mutated")

	# Detachment is unchanged by the composition, in both directions.
	assert_false(is_same(candidate["current_snapshot"], document["current_snapshot"]),
		"the composed bundle is not the caller's container")
	assert_false(is_same(candidate["current_snapshot"]["snapshot"], document["current_snapshot"]["snapshot"]),
		"the embedded snapshot is the validated candidate, not the caller's")
	(document["current_snapshot"]["snapshot"]["gameplay"]["narrative_variables"] as Dictionary)["late"] = true
	assert_eq((candidate["current_snapshot"]["snapshot"]["gameplay"]["narrative_variables"] as Dictionary).size(),
		0, "mutating the caller's bundle cannot reach the candidate")
	(candidate["recovery_journal"][0] as Dictionary)["count"] = 99
	assert_eq(typeof((document["recovery_journal"][0] as Dictionary)["count"]), TYPE_FLOAT,
		"mutating the candidate cannot reach the caller's journal")

func test_validate_refusal_order_survives_multiple_simultaneous_defects() -> void:
	# A2 guard: the restructure moves where normalization happens, so pin the one thing it must not
	# move -- the order validate() answers in: keys, saved_time, schema_version, discriminators,
	# current bundle, recovery journal. Each row below carries EVERY later defect as well, so a
	# reordering cannot pass by accident.
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var base_built: Dictionary = schema.build(&"slot", 1, &"manual", _bundle(), [])
	assert_true(base_built.get("ok", false), str(base_built))
	if not base_built.get("ok", false):
		return
	var base: Dictionary = base_built["value"]

	var journal_only: Dictionary = base.duplicate(true)
	journal_only["recovery_journal"] = [{"broken": Vector2.ZERO}]
	assert_eq(schema.validate(journal_only).get("code", &""), &"invalid_recovery_journal",
		"a journal defect alone is answered by the journal")

	var bundle_and_journal: Dictionary = journal_only.duplicate(true)
	bundle_and_journal["current_snapshot"] = {"unknown": true}
	assert_eq(schema.validate(bundle_and_journal).get("code", &""), &"invalid_bundle_shape",
		"the current bundle is answered before the journal")

	var discriminator_too: Dictionary = bundle_and_journal.duplicate(true)
	discriminator_too["slot_id"] = 0
	assert_eq(schema.validate(discriminator_too).get("code", &""), &"invalid_discriminator",
		"the discriminators are answered before the current bundle")

	var stale_version_too: Dictionary = discriminator_too.duplicate(true)
	stale_version_too["schema_version"] = 5
	assert_eq(schema.validate(stale_version_too).get("code", &""), &"invalid_document_shape",
		"a wrong document version is answered before the discriminators")

	var future_version_too: Dictionary = discriminator_too.duplicate(true)
	future_version_too["schema_version"] = 7
	assert_eq(schema.validate(future_version_too).get("code", &""), &"unsupported_schema_version",
		"a future document version keeps its own code, ahead of the discriminators")

	var saved_time_too: Dictionary = future_version_too.duplicate(true)
	saved_time_too["saved_time"] = {"broken": true}
	assert_eq(schema.validate(saved_time_too).get("code", &""), &"invalid_saved_time",
		"optional metadata is answered before the schema version")

	var unknown_key_too: Dictionary = saved_time_too.duplicate(true)
	unknown_key_too["extra"] = 1
	assert_eq(schema.validate(unknown_key_too).get("code", &""), &"invalid_document_shape",
		"the key set is answered before everything else")

func test_normalize_engine_text_returns_stringname_free_subtrees_by_identity() -> void:
	# A3: _normalize_engine_text rebuilds the whole current bundle AND the whole recovery journal on
	# every build, even though a StringName is rare and the rebuild is the identity in that case.
	# Making it identity-preserving is observable exactly where it pays: an unchanged subtree comes
	# back as the same container, and a tree that does contain a StringName rebuilds only the path
	# to it while its untouched siblings are returned by identity.
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)

	var clean := {"outer": {"inner": [1, "two", 3.5, null, true]}, "empty": []}
	var clean_result: Variant = schema._normalize_engine_text(clean)
	assert_true(is_same(clean_result, clean), "a StringName-free tree is returned by identity")
	assert_true(is_same(clean_result["outer"], clean["outer"]), "...and so is every nested Dictionary")
	assert_true(is_same(clean_result["outer"]["inner"], clean["outer"]["inner"]),
		"...and every nested Array, at depth")

	var mixed := {"dirty": {"phase": &"NONE"}, "clean": {"kept": [1, 2]}}
	var mixed_result: Variant = schema._normalize_engine_text(mixed)
	assert_false(is_same(mixed_result, mixed), "a tree that contains a StringName is rebuilt")
	assert_false(is_same(mixed_result["dirty"], mixed["dirty"]), "the path to the StringName is rebuilt")
	assert_true(is_same(mixed_result["clean"], mixed["clean"]),
		"an untouched sibling container is returned by identity")
	assert_eq(typeof(mixed_result["dirty"]["phase"]), TYPE_STRING, "the StringName became a String")
	assert_eq(str(mixed_result["dirty"]["phase"]), "NONE", "with its text preserved")
	assert_eq(typeof(mixed["dirty"]["phase"]), TYPE_STRING_NAME, "the source is never mutated")

	# Conversion itself is unchanged: StringName keys, Array elements and bare values all convert.
	var keyed := {&"key": [&"element", {&"deep": &"value"}]}
	var keyed_result: Variant = schema._normalize_engine_text(keyed)
	var keyed_keys: Array = (keyed_result as Dictionary).keys()
	assert_eq(keyed_keys.size(), 1, "the key set is preserved")
	assert_eq(typeof(keyed_keys[0]), TYPE_STRING, "a StringName key becomes a String key")
	assert_eq(str(keyed_keys[0]), "key", "with its text preserved")
	assert_eq(typeof(keyed_result["key"][0]), TYPE_STRING, "an Array element converts")
	assert_eq(str(keyed_result["key"][0]), "element", "with its text preserved")
	assert_eq(typeof(keyed_result["key"][1]["deep"]), TYPE_STRING, "a nested value converts")
	var bare: Variant = schema._normalize_engine_text(&"bare")
	assert_eq(typeof(bare), TYPE_STRING, "a bare StringName converts")
	assert_eq(str(bare), "bare", "with its text preserved")
	var number: Variant = schema._normalize_engine_text(2.5)
	assert_eq(typeof(number), TYPE_FLOAT, "non-text leaves are untouched")
	assert_eq(number, 2.5, "and keep their value")

func test_build_detaches_the_persisted_document_from_identity_preserved_inputs() -> void:
	# A3 guard: once _normalize_engine_text can hand a StringName-free input straight back, build()
	# no longer gets a private copy of the caller's bundle or journal for free. Detachment then rests
	# on the journal deep copy at the compose step and on the validated bundle candidate. Pin both.
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)
	var current := _bundle()
	var journal: Array = [{"nested": [1, 2], "label": "kept"}]
	var built: Dictionary = schema.build(&"autosave", null, &"automatic", current, journal)
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false):
		return
	var document: Dictionary = built["value"]
	assert_false(is_same(document["recovery_journal"], journal),
		"the persisted journal is not the caller's Array")
	assert_false(is_same(document["recovery_journal"][0], journal[0]), "...nor any of its entries")
	assert_false(is_same(document["recovery_journal"][0]["nested"], journal[0]["nested"]), "...at depth")
	assert_false(is_same(document["current_snapshot"]["snapshot"], current["snapshot"]),
		"the persisted bundle is the validated candidate, not the caller's snapshot")
	assert_false(is_same(document["current_snapshot"], current),
		"and the persisted bundle envelope is composed, not carried")

	(document["recovery_journal"][0]["nested"] as Array).append("from_document")
	assert_eq((journal[0]["nested"] as Array).size(), 2,
		"mutating the document cannot reach the input journal")
	(journal[0]["nested"] as Array).append("from_input")
	assert_eq((document["recovery_journal"][0]["nested"] as Array).size(), 3,
		"mutating the input journal cannot reach the document")
	(current["snapshot"]["gameplay"]["narrative_variables"] as Dictionary)["late"] = true
	assert_eq((document["current_snapshot"]["snapshot"]["gameplay"]["narrative_variables"] as Dictionary).size(),
		0, "mutating the input bundle cannot reach the document")


func test_build_passes_the_validated_bundle_through_instead_of_renormalizing_it() -> void:
	# build() composes its document around the bundle candidate `_validate_bundle()` produced -- a
	# candidate RunSnapshotSchema.validate() has ALREADY normalized -- and then walks the whole
	# document again with _normalize_integral_floats. Over that bundle the walk is the identity (the
	# normalizer is idempotent), so it is a second full-snapshot rebuild per save for nothing. The
	# fix normalizes the envelope members and the journal and passes the bundle candidate through,
	# composing current_snapshot exactly as _validate_document() now does.
	#
	# Unlike validate(), member order CANNOT be the probe here: build() authors current_snapshot as
	# checkpoint_kind-then-snapshot itself and the normalizer preserves insertion order, so that
	# order is already green today (it is asserted below as a guard, not as the RED row). Nor is
	# identity of the bundle candidate reachable: build() is its only producer, so no test can hold
	# the object to compare against. Like A1 and A2 this is an allocation-only change with no value
	# observable, so the source text is the observable.
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var source := FileAccess.get_file_as_string(SCHEMA_PATH)
	assert_false(source.is_empty(), "the schema source must be readable")
	assert_false(source.contains("RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(document)"),
		"build() must not re-walk a document whose current bundle is an already-normalized candidate")

	var schema: Script = load(SCHEMA_PATH)
	var current := _bundle()
	current.snapshot.schema_version = 6.0
	var journal := [{"count": 4.0, "nested": [&"hint", 2.25]}]
	var saved_time := {"unix_seconds": 0.0, "utc_offset_minutes": 0.0, "hhmm": "00:00"}
	var built: Dictionary = schema.build(&"autosave", null, &"automatic", current, journal, saved_time)
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false):
		return
	var document: Dictionary = built["value"]

	# Every member that is NOT the current bundle must still be normalized by build itself.
	assert_eq(typeof((document["recovery_journal"][0] as Dictionary)["count"]), TYPE_INT,
		"the journal still normalizes")
	assert_eq((document["recovery_journal"][0] as Dictionary)["nested"], ["hint", 2.25],
		"the journal keeps engine-text conversion and non-integral floats")
	assert_eq(typeof((document["saved_time"] as Dictionary)["unix_seconds"]), TYPE_INT,
		"optional metadata still normalizes BEFORE validate_saved_time runs over it")
	assert_eq(typeof((document["saved_time"] as Dictionary)["utc_offset_minutes"]), TYPE_INT,
		"both saved_time integers still normalize")
	assert_eq(typeof(document["schema_version"]), TYPE_INT, "the envelope version stays an integer")
	assert_false((document["recovery_journal"] as Array).is_typed(),
		"the persisted journal stays an untyped Array")
	# ...and the bundle that is passed through must already be normalized by its own owner.
	assert_eq(typeof(document["current_snapshot"]["snapshot"]["schema_version"]), TYPE_INT,
		"the embedded snapshot is normalized by RunSnapshotSchema.validate, not by build")
	assert_eq(int(document["current_snapshot"]["snapshot"]["schema_version"]), 6,
		"normalization preserves the value")
	var bundle_keys: Array = (document["current_snapshot"] as Dictionary).keys()
	assert_eq(bundle_keys.size(), 2, "the persisted bundle has exactly two members")
	assert_eq(str(bundle_keys[0]), "checkpoint_kind", "build authors the bundle member order")
	assert_eq(str(bundle_keys[1]), "snapshot", "build authors the bundle member order")
	assert_eq(str(document["current_snapshot"]["checkpoint_kind"]), "day_start",
		"the persisted bundle carries the proven checkpoint_kind as a String")
	assert_eq(typeof(document["current_snapshot"]["checkpoint_kind"]), TYPE_STRING,
		"and never as engine text")

	# External validation must still agree with the built document, byte for byte.
	var validated: Dictionary = schema.validate(document)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false):
		return
	assert_eq(validated["value"]["candidate"], document,
		"external validation agrees with the built document")

	# The pass-through must not turn the persisted bundle into an alias of the caller's.
	assert_false(is_same(document["current_snapshot"]["snapshot"], current["snapshot"]),
		"the persisted snapshot is the validated candidate, not the caller's")
	assert_false(is_same(document["recovery_journal"], journal), "the persisted journal is detached")
	current.snapshot.gameplay.narrative_variables["late"] = true
	assert_eq((document["current_snapshot"]["snapshot"]["gameplay"]["narrative_variables"] as Dictionary).size(),
		0, "mutating the input bundle cannot reach the document")
	(journal[0]["nested"] as Array).append("late")
	assert_eq((document["recovery_journal"][0]["nested"] as Array).size(), 2,
		"mutating the input journal cannot reach the document")
	saved_time["hhmm"] = "01:00"
	assert_eq(str((document["saved_time"] as Dictionary)["hhmm"]), "00:00",
		"mutating the input metadata cannot reach the document")
	assert_eq(typeof(current.snapshot.schema_version), TYPE_FLOAT,
		"the caller's bundle is never mutated")
	assert_eq(typeof(journal[0]["count"]), TYPE_FLOAT, "the caller's journal is never mutated")


func test_build_composes_the_journal_without_a_redundant_deep_copy() -> void:
	# dwm-634.3 session 4 Step 2 (a): build() deep-copies the journal and then hands the copy to
	# _normalize_integral_floats, which already allocates a fresh Dictionary/Array at EVERY container
	# node (see SaveManagerCheckpointPort.gd's _validate_document note). The copy is pure waste, and
	# every production caller passes a journal nobody mutates. Like A1 the change is allocation-only
	# with no value observable, so the source text is the observable (RED row); the detachment the
	# copy used to guarantee is then pinned behaviourally, green before and after.
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var source := FileAccess.get_file_as_string(SCHEMA_PATH)
	assert_false(source.is_empty(), "the schema source must be readable")
	assert_false(source.contains("journal.duplicate(true)"),
		"build() must not deep-copy the journal before a walk that rebuilds every container")

	# Detachment rests on the normalizer alone once the copy is gone: a two-bundle journal whose
	# fixture bundles carry no StringName (so _normalize_engine_text hands them back by identity).
	var schema: Script = load(SCHEMA_PATH)
	var first := _bundle()
	var second := _bundle()
	var journal: Array = [first, second]
	var built: Dictionary = schema.build(&"autosave", null, &"automatic", _bundle(), journal)
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false):
		return
	var persisted: Array = built["value"]["recovery_journal"]
	assert_eq(persisted.size(), 2, "both journal bundles are persisted")
	assert_false(is_same(persisted, journal), "the persisted journal is not the caller's Array")
	assert_false(is_same(persisted[0], first), "...nor its first entry")
	assert_false(is_same(persisted[1], second), "...nor its second entry")
	assert_false(is_same(persisted[0]["snapshot"], first["snapshot"]), "...at depth")
	assert_false(is_same(persisted[0]["snapshot"]["lifecycle"], first["snapshot"]["lifecycle"]),
		"...at every depth")

	# Document -> input: the fixture's integer leaf lifecycle.day is 3 on both sides.
	assert_eq(int(first["snapshot"]["lifecycle"]["day"]), 3, "fixture precondition")
	(persisted[0]["snapshot"]["lifecycle"] as Dictionary)["day"] = 99
	assert_eq(int(first["snapshot"]["lifecycle"]["day"]), 3,
		"mutating the persisted journal cannot reach the input bundle")
	# Input -> document.
	(second["snapshot"]["lifecycle"] as Dictionary)["day"] = 42
	assert_eq(int(persisted[1]["snapshot"]["lifecycle"]["day"]), 3,
		"mutating the input bundle after build cannot reach the persisted journal")
	journal.append({"late": true})
	assert_eq(persisted.size(), 2, "mutating the input journal after build cannot reach the document")


# -------------------------------------------------------------------------------------------------
# settlement4 Step 2: build() re-walks every retained journal bundle on every autosave -- the
# primitive-tree sweep in _validate_journal, the _normalize_engine_text walk and the
# _normalize_integral_floats walk -- although each bundle was validated, normalized and byte-proven
# at its OWN commit and the journal still holds the document bundle those proven bytes describe
# (25-62 ms of each 35-76 ms autosave prepare, settlement4-step2-profile-*). The optional trailing
# `proven_journal` lets the journal hand those objects back. The observable is byte-equality with
# the full builder over the same inputs, plus the two directions of the skip: a proven journal is
# never read, and a proof set that does not cover it falls back to every check it does today.
# -------------------------------------------------------------------------------------------------

## Asserted before the seven-argument calls below so a tree without the optional parameter reports
## these rows as failed assertions: a wrong-arity call aborts the test function outright, which GUT
## records as risky rather than failed. `build()` is static, so its declaration is the surface.
func _build_takes_a_proven_journal() -> bool:
	var source := FileAccess.get_file_as_string(SCHEMA_PATH)
	assert_false(source.is_empty(), "the schema source must be readable")
	assert_true(source.contains("proven_journal: Array = []"),
		"build() must declare the optional trailing proven journal")
	return source.contains("proven_journal: Array = []")


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))


## A bundle whose snapshot carries everything the skipped walks would otherwise convert or refuse:
## engine text as a key AND as a value (narrative_checkpoint, the desktop board phase), an integral
## float that must persist as an integer, a non-integral float that must not, and non-ASCII text.
func _engine_typed_bundle(sequence: int) -> Dictionary:
	var snapshot := _fixture_snapshot()
	snapshot["checkpoint_sequence"] = sequence
	snapshot["checkpoint_id"] = "%s:%d" % [str(snapshot["run_id"]), sequence]
	snapshot["narrative_checkpoint"] = {
		&"engine_key": &"engine_value", "integral": 1.0, "fractional": 2.5,
		"unicode": "Lavinia — Müller ✓", "sequence": sequence,
	}
	(snapshot["desktop"]["board"] as Dictionary)["phase"] = &"NONE"
	return {"checkpoint_kind": "post_result", "snapshot": snapshot}


## The proof production path itself: the journal's retained document bundle for a written bundle is
## the `current_snapshot` object build() composed when those bytes were written.
func _proof_for(bundle: Dictionary) -> Dictionary:
	var built: Dictionary = load(SCHEMA_PATH).build(&"autosave", null, &"automatic", bundle, [])
	assert_true(built.get("ok", false), str(built.get("code", "")) + " " + str(built.get("message", "")))
	return (built["value"] as Dictionary)["current_snapshot"]


func test_build_composes_proven_journal_entries_byte_equal_to_the_full_builder() -> void:
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	if not _build_takes_a_proven_journal():
		return
	var schema: Script = load(SCHEMA_PATH)
	var first := _engine_typed_bundle(1)
	var second := _engine_typed_bundle(2)
	var proofs: Array = [_proof_for(first), _proof_for(second)]
	var proof_checkpoint: Dictionary = proofs[0]["snapshot"]["narrative_checkpoint"]
	assert_eq(typeof(proof_checkpoint["integral"]), TYPE_INT,
		"a proof is already integral-float normalized")
	assert_eq(typeof(proof_checkpoint["fractional"]), TYPE_FLOAT,
		"...and a non-integral float survived as one")
	assert_eq(typeof(proof_checkpoint["engine_key"]), TYPE_STRING,
		"a proof is already engine-text converted, key and value")
	assert_eq(str(proof_checkpoint["engine_key"]), "engine_value")

	var current := _engine_typed_bundle(3)
	var journal: Array = [first, second]
	var proven: Dictionary = schema.build(&"autosave", null, &"automatic", current, journal, {}, proofs)
	assert_true(proven.get("ok", false), str(proven.get("code", "")) + " " + str(proven.get("message", "")))
	var full: Dictionary = schema.build(&"autosave", null, &"automatic", current, journal)
	assert_true(full.get("ok", false), str(full.get("code", "")) + " " + str(full.get("message", "")))
	if not (proven.get("ok", false) and full.get("ok", false)):
		return
	var proven_text := _canonical(proven["value"])
	var full_text := _canonical(full["value"])
	assert_eq(proven_text.sha256_text(), full_text.sha256_text(),
		"the proven journal composes the same document bytes as the full builder")
	assert_true(proven_text == full_text, "byte-for-byte, not merely equal in digest")

	# The document owns its journal outright: the proofs are the journal's objects, not the save's.
	var document: Dictionary = proven["value"]
	var persisted: Array = document["recovery_journal"]
	assert_eq(persisted.size(), 2, "both proofs are persisted")
	assert_false(persisted.is_typed(), "the persisted journal stays an untyped Array")
	assert_false(is_same(persisted[0], proofs[0]), "the persisted entry is not the proof object")
	assert_false(is_same(persisted[0]["snapshot"], proofs[0]["snapshot"]), "...at depth")
	(persisted[0]["snapshot"]["narrative_checkpoint"] as Dictionary)["from_document"] = true
	assert_false((proofs[0]["snapshot"]["narrative_checkpoint"] as Dictionary).has("from_document"),
		"mutating the document cannot reach the journal's proof")
	(proofs[1]["snapshot"]["narrative_checkpoint"] as Dictionary)["from_proof"] = true
	assert_false((persisted[1]["snapshot"]["narrative_checkpoint"] as Dictionary).has("from_proof"),
		"mutating the journal's proof after build cannot reach the document")


func test_build_with_proven_journal_never_reads_the_journal_entries() -> void:
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	if not _build_takes_a_proven_journal():
		return
	var schema: Script = load(SCHEMA_PATH)
	# A journal entry the full path REFUSES: validate_primitive_tree() rejects an Object value with
	# invalid_primitive, so only a genuinely skipped walk can let this document through.
	var poisoned := {"unsupported": Vector2.ZERO}
	var proof := _proof_for(_engine_typed_bundle(1))
	var proven: Dictionary = schema.build(&"autosave", null, &"automatic", _engine_typed_bundle(2),
		[poisoned], {}, [proof])
	assert_true(proven.get("ok", false), str(proven.get("code", "")) + " " + str(proven.get("message", "")))
	if not proven.get("ok", false):
		return
	var persisted: Array = (proven["value"] as Dictionary)["recovery_journal"]
	assert_eq(persisted.size(), 1, "the proof, not the poisoned entry, is what was composed")
	assert_eq(_canonical(persisted[0]), _canonical(proof),
		"the persisted entry is the proof's content")
	assert_false((persisted[0] as Dictionary).has("unsupported"), "the journal entry was never read")
	# ...and the same call without proofs still refuses, so the skip is what let it through.
	var refused: Dictionary = schema.build(&"autosave", null, &"automatic", _engine_typed_bundle(2),
		[poisoned])
	assert_false(refused.get("ok", true), "the unproven path still walks every journal entry")
	assert_eq(refused["code"], &"invalid_recovery_journal")


func test_build_falls_back_to_the_full_path_when_any_proof_is_missing() -> void:
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	if not _build_takes_a_proven_journal():
		return
	var schema: Script = load(SCHEMA_PATH)
	var first := _engine_typed_bundle(1)
	var second := _engine_typed_bundle(2)
	var current := _engine_typed_bundle(3)
	var journal: Array = [first, second]
	var proofs: Array = [_proof_for(first), _proof_for(second)]
	var baseline: Dictionary = schema.build(&"autosave", null, &"automatic", current, journal)
	assert_true(baseline.get("ok", false), str(baseline.get("code", "")) + " " + str(baseline.get("message", "")))
	if not baseline.get("ok", false):
		return
	var expected := _canonical(baseline["value"])

	var short_proofs: Dictionary = schema.build(&"autosave", null, &"automatic", current, journal,
		{}, [proofs[0]])
	assert_true(short_proofs.get("ok", false), str(short_proofs.get("code", "")) + " " + str(short_proofs.get("message", "")))
	assert_eq(_canonical(short_proofs["value"]).sha256_text(), expected.sha256_text(),
		"a proof set shorter than the journal proves nothing: the full path composed these bytes")
	var empty_entry: Dictionary = schema.build(&"autosave", null, &"automatic", current, journal,
		{}, [proofs[0], {}])
	assert_true(empty_entry.get("ok", false), str(empty_entry.get("code", "")) + " " + str(empty_entry.get("message", "")))
	assert_eq(_canonical(empty_entry["value"]).sha256_text(), expected.sha256_text(),
		"one unproven entry unproves the whole journal")

	# The refusal the full path owns must fire in exactly those two cases as well.
	var poisoned := {"unsupported": Vector2.ZERO}
	assert_eq(schema.build(&"autosave", null, &"automatic", current, [poisoned, poisoned],
		{}, [proofs[0]])["code"], &"invalid_recovery_journal",
		"a short proof set does not excuse a journal entry the builder refuses")
	assert_eq(schema.build(&"autosave", null, &"automatic", current, [poisoned, poisoned],
		{}, [proofs[0], {}])["code"], &"invalid_recovery_journal",
		"nor does one empty proof beside a good one")
	assert_eq(schema.build(&"autosave", null, &"automatic", current, [poisoned], {}, [])["code"],
		&"invalid_recovery_journal", "and the empty default changes nothing")


func test_outgoing_journal_uses_proofs_and_detaches_from_discarded_caller_entries() -> void:
	var schema: Script = load(SCHEMA_PATH)
	var proofs: Array[Dictionary] = [_proof_for(_engine_typed_bundle(1)),
		_proof_for(_engine_typed_bundle(2))]
	var built: Dictionary = schema.build(&"autosave", null, &"automatic",
		_engine_typed_bundle(3), proofs)
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false): return
	var document: Dictionary = built.value
	var expected: Dictionary = schema.validate(document)
	assert_true(expected.get("ok", false), str(expected))
	if not expected.get("ok", false): return
	var caller_entries: Array[Dictionary] = [{"ignored": [1.0, RefCounted.new()]}]
	document.recovery_journal = caller_entries
	var outgoing: Dictionary = schema.validate_outgoing(document, proofs)
	assert_true(outgoing.get("ok", false), str(outgoing))
	if not outgoing.get("ok", false): return
	var candidate: Dictionary = outgoing.value.candidate
	assert_true(CANONICAL_JSON._deep_same(candidate, expected.value.candidate),
		"the discarded entries cannot change the typed candidate described by the proof bytes")
	assert_eq(_canonical(candidate), _canonical(expected.value.candidate),
		"the outgoing document retains exact canonical bytes")
	assert_eq(candidate.recovery_journal.size(), 2, "both proven fallbacks are retained")
	assert_false((candidate.recovery_journal as Array).is_typed(),
		"typed proof and input arrays still compose an untyped JSON array")
	assert_eq(typeof(candidate.recovery_journal[0].snapshot.narrative_checkpoint.integral), TYPE_INT)
	assert_eq(typeof(candidate.recovery_journal[0].snapshot.narrative_checkpoint.fractional), TYPE_FLOAT)
	assert_true(caller_entries.is_typed(), "the caller's array is unchanged")
	assert_eq(typeof(caller_entries[0].ignored[0]), TYPE_FLOAT,
		"discarded input entries are not normalized in place")
	assert_eq(schema.validate(document).get("code"), &"invalid_recovery_journal",
		"unproven validation still refuses the unsupported caller entry")
	caller_entries[0].ignored.append("late")
	assert_true(CANONICAL_JSON._deep_same(candidate, expected.value.candidate),
		"editing discarded caller entries cannot affect the outgoing candidate")
	candidate.current_snapshot.snapshot.narrative_checkpoint["outgoing_only"] = true
	assert_false(document.current_snapshot.snapshot.narrative_checkpoint.has("outgoing_only"),
		"the current snapshot remains detached from the caller")


func test_outgoing_journal_container_check_retains_refusal_precedence() -> void:
	var schema: Script = load(SCHEMA_PATH)
	var built: Dictionary = schema.build(&"autosave", null, &"automatic", _bundle(), [])
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false): return
	var document: Dictionary = built.value
	var proofs: Array = [_proof_for(_engine_typed_bundle(1))]
	for invalid: Variant in [null, {}, "journal", 1, PackedInt32Array([1])]:
		document.recovery_journal = invalid
		var refused: Dictionary = schema.validate_outgoing(document, proofs)
		assert_eq(refused.get("code"), &"invalid_document_shape")
		assert_eq(refused.get("message"), "recovery_journal must be an array",
			"proofs never waive the journal container check")
	document.current_snapshot = {"unknown": true}
	assert_eq(schema.validate_outgoing(document, proofs).get("code"), &"invalid_bundle_shape")
	document.slot_id = 0
	assert_eq(schema.validate_outgoing(document, proofs).get("code"), &"invalid_discriminator")
	document.schema_version = 7
	assert_eq(schema.validate_outgoing(document, proofs).get("code"), &"unsupported_schema_version")
	document.saved_time = {"broken": true}
	assert_eq(schema.validate_outgoing(document, proofs).get("code"), &"invalid_saved_time")
	document["extra"] = 1
	assert_eq(schema.validate_outgoing(document, proofs).get("code"), &"invalid_document_shape")
