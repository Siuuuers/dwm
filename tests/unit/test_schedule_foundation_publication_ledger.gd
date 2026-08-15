extends "res://addons/gut/test.gd"
# Durable Schedule-foundation publication ledger (Plan 01 Task 4, dwm-p2r.13, Steps 4.1/4.3).
#
# The subject is the REAL ledger over the REAL JsonFileStorage over a GUID-isolated temporary root,
# exactly as the plan's "same root-scoped StorageAdapter family as the issuer root" requires. A
# restart is modelled by rebuilding the whole stack over the same bytes, never by flipping an
# in-memory flag: the at-most-once observation boundary is only real if a cold instance re-reads the
# durable record and still answers `first_delivery=false`.
#
# The ledger is deliberately NOT a selectable save participant, so nothing here registers it with
# SaveManager, RunSnapshot, or a restore participant list.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const LEDGER_PATH := "res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd"
const FIXED_PATH := "schedule-foundation-publications.json"
const SCHEMA_PATH := "res://schemas/save/schedule-foundation-publication-ledger.schema.json"

const RECORD_KEYS: Array[String] = [
	"key", "kind", "publication", "publication_sha256", "semantic_receipt",
]

var _ledger_script: Script = null
var _root := ""
var _storage: RefCounted = null
var _root_counter := 0


func before_each() -> void:
	var loaded: Dictionary = PROBE.load_script(LEDGER_PATH)
	_ledger_script = loaded["value"] if loaded.get("ok", false) else null
	_root = _isolated_root("ledger")
	_storage = JsonFileStorage.new(_root)


## The wrapper's GUID-isolated `DWM_TEST_ROOT` is the only storage root any suite may use; the
## production `user://` directory is asserted to be a different tree before anything is written.
func _isolated_root(label: String) -> String:
	var wrapper := OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root: String = wrapper.path_join("schedule-publication-%s-%d" % [label, _root_counter])
	var production := ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	assert_ne(root.simplify_path().trim_suffix("/").nocasecmp_to(production), 0,
		"an isolated root is never the production user directory")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	return root


func _require_ledger() -> bool:
	if _ledger_script == null:
		assert_true(false, "ScheduleFoundationPublicationLedger is absent: " + LEDGER_PATH)
		return false
	return true


func _new_ledger() -> Object:
	return _ledger_script.new()


func _configured(storage: Object = null) -> Object:
	var ledger := _new_ledger()
	var configured: Dictionary = ledger.configure(storage if storage != null else _storage)
	assert_true(configured.get("ok", false), str(configured))
	return ledger


func _loaded(storage: Object = null) -> Object:
	var ledger := _configured(storage)
	var loaded: Dictionary = ledger.load()
	assert_true(loaded.get("ok", false), str(loaded))
	return ledger


func _document_path() -> String:
	return _root.path_join(FIXED_PATH)


func _raw_document() -> String:
	return FileAccess.get_file_as_string(_document_path())


func _write_raw(text: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(_document_path().get_base_dir()), OK)
	var file := FileAccess.open(_document_path(), FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


# ---- fixtures ----

func _commit_receipt(suffix := "1") -> Dictionary:
	return {
		"receipt_id": "schedule_commit.%s" % suffix.repeat(64).substr(0, 64),
		"receipt_provenance": {
			"schema_version": 1,
			"parent_receipt_id": "issuer_receipt." + "a".repeat(64),
			"child_kind": "schedule_commit",
			"ordinal": 0,
			"source_ids": ['role="schedule.commit"'],
			"child_id": "schedule_commit.%s" % suffix.repeat(64).substr(0, 64),
		},
		"transaction_id": "transaction_id." + "b".repeat(64),
		"day": 1,
		"motivation_charged": 1,
	}


func _committed_schedule(slot := 0) -> Dictionary:
	return {
		"schema_version": 1,
		"day": 1,
		"registry_fingerprint": "c".repeat(64),
		"entries": [{"slot_index": slot}],
		"commit_receipt": null,
	}


func _commit_request(suffix := "1", slot := 0) -> Dictionary:
	var receipt := _commit_receipt(suffix)
	var publication := {
		"committed_schedule": _committed_schedule(slot),
		"schedule_commit_receipt": receipt.duplicate(true),
	}
	return {
		"kind": "schedule_commit",
		"semantic_receipt": receipt,
		"publication": publication,
		"publication_sha256": _sha256(_canonical(publication)),
	}


func _start_request() -> Dictionary:
	var receipt := {
		"receipt_id": "day_resolution_stage." + "d".repeat(64),
		"resolution_id": "resolution." + "e".repeat(64),
	}
	var publication := {
		"resolution_plan": {"stages": []},
		"day_resolution_start_receipt": receipt.duplicate(true),
	}
	return {
		"kind": "day_resolution_start",
		"semantic_receipt": receipt,
		"publication": publication,
		"publication_sha256": _sha256(_canonical(publication)),
	}


class FailingStorage:
	extends RefCounted

	var _inner: RefCounted
	var fail_write := false
	var fail_read := false
	var corrupt_read := false

	func _init(inner: RefCounted) -> void:
		_inner = inner

	func describe_root() -> String:
		return _inner.describe_root()

	func exists(relative_path: String) -> bool:
		return _inner.exists(relative_path)

	func reconcile(relative_path: String, validator: Callable) -> Dictionary:
		return _inner.reconcile(relative_path, validator)

	func read_text(relative_path: String) -> Dictionary:
		if fail_read:
			return {"ok": false, "code": &"read_failed", "message": relative_path}
		var result: Dictionary = _inner.read_text(relative_path)
		if corrupt_read and result.get("ok", false):
			return {"ok": true, "value": '{"schema_version":1,"records":{}}' + "\n"}
		return result

	func write_atomic(relative_path: String, text: String, validator: Callable,
			keep_backup: bool = true) -> Dictionary:
		if fail_write:
			return {"ok": false, "code": &"write_not_committed", "message": relative_path}
		return _inner.write_atomic(relative_path, text, validator, keep_backup)


# ---- tests ----

func test_fixed_path_and_published_schema_are_frozen() -> void:
	if not _require_ledger():
		return
	assert_eq(str(_ledger_script.get_script_constant_map().get("FIXED_PATH", "")), FIXED_PATH,
		"the ledger owns one fixed relative path outside selectable saves")
	assert_true(FileAccess.file_exists(SCHEMA_PATH),
		"the strict document schema must be published at " + SCHEMA_PATH)
	if not FileAccess.file_exists(SCHEMA_PATH):
		return
	var parsed: Dictionary = StrictJson.parse_object(FileAccess.get_file_as_string(SCHEMA_PATH))
	assert_true(parsed.get("ok", false), "the published schema must strict-parse")


func test_missing_file_initializes_the_exact_empty_document() -> void:
	if not _require_ledger():
		return
	assert_false(_storage.exists(FIXED_PATH), "the isolated root starts empty")
	var ledger := _configured()
	var loaded: Dictionary = ledger.load()
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false):
		return
	assert_eq(loaded["value"]["document"], {"schema_version": 1, "records": {}})
	assert_eq(_raw_document(), '{"records":{},"schema_version":1}' + "\n",
		"initialization writes exactly J({schema_version:1,records:{}}) plus one LF")
	var second: Dictionary = _loaded().load()
	assert_true(second.get("ok", false), "a second load over the same bytes succeeds")
	assert_eq(_raw_document(), '{"records":{},"schema_version":1}' + "\n",
		"loading never rewrites an existing document")


func test_document_and_record_union_is_exact_after_one_publication() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var request := _commit_request()
	var recorded: Dictionary = ledger.record_before_emit(request)
	assert_true(recorded.get("ok", false), str(recorded))
	if not recorded.get("ok", false):
		return
	assert_eq(recorded["receipt"], {}, "the ledger issues no receipt of its own")
	assert_true(bool(recorded["value"]["first_delivery"]), "a new key is a first delivery")
	var record: Dictionary = recorded["value"]["record"]
	var keys: Array = record.keys()
	keys.sort()
	assert_eq(keys, RECORD_KEYS, "the record union is exact")
	var expected_key := "schedule_commit:" + str(request["semantic_receipt"]["receipt_id"])
	assert_eq(str(record["key"]), expected_key, "the key is kind + ':' + semantic receipt id")
	assert_eq(record["kind"], "schedule_commit")
	assert_eq(record["semantic_receipt"], request["semantic_receipt"])
	assert_eq(record["publication"], request["publication"])
	assert_eq(str(record["publication_sha256"]), str(request["publication_sha256"]))

	var parsed: Dictionary = StrictJson.parse_object(_raw_document())
	assert_true(parsed.get("ok", false), "the durable document strict-parses")
	var document: Dictionary = parsed["value"]
	var document_keys: Array = document.keys()
	document_keys.sort()
	assert_eq(document_keys, ["records", "schema_version"])
	assert_eq(int(document["schema_version"]), 1)
	assert_eq((document["records"] as Dictionary).size(), 1)
	assert_eq(document["records"][expected_key], record)

	var start := _start_request()
	var start_recorded: Dictionary = ledger.record_before_emit(start)
	assert_true(start_recorded.get("ok", false), str(start_recorded))
	assert_eq(str(start_recorded["value"]["record"]["key"]),
		"day_resolution_start:" + str(start["semantic_receipt"]["receipt_id"]),
		"both frozen kinds share one append-only index")


func test_first_delivery_then_byte_identical_replay_across_a_cold_restart() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var request := _commit_request()
	var first: Dictionary = ledger.record_before_emit(request)
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false):
		return
	var bytes_after_first := _raw_document()
	var same_instance: Dictionary = ledger.record_before_emit(request)
	assert_true(same_instance.get("ok", false), str(same_instance))
	assert_false(bool(same_instance["value"]["first_delivery"]), "a byte-identical replay is not first")
	assert_eq(same_instance["value"]["record"], first["value"]["record"], "the replay is byte-identical")

	# Cold restart: a brand-new storage adapter and ledger over the same durable bytes.
	var restarted := _loaded(JsonFileStorage.new(_root))
	var replayed: Dictionary = restarted.record_before_emit(request)
	assert_true(replayed.get("ok", false), str(replayed))
	assert_false(bool(replayed["value"]["first_delivery"]),
		"a cold instance must read the durable record, never an in-memory flag")
	assert_eq(replayed["value"]["record"], first["value"]["record"])
	assert_eq(_raw_document(), bytes_after_first, "replay rewrites nothing")


func test_occupied_key_with_changed_bytes_conflicts_without_rewriting_storage() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var request := _commit_request()
	assert_true(ledger.record_before_emit(request).get("ok", false))
	var durable := _raw_document()

	var changed_publication := _commit_request("1", 5)
	var conflict: Dictionary = ledger.record_before_emit(changed_publication)
	assert_false(conflict.get("ok", true), "an occupied key with changed publication bytes conflicts")
	assert_eq(conflict.get("code"), &"publication_record_conflict")
	assert_eq(_raw_document(), durable, "a conflict rewrites nothing")

	var changed_receipt := _commit_request()
	changed_receipt["semantic_receipt"]["day"] = 2
	changed_receipt["publication"]["schedule_commit_receipt"]["day"] = 2
	changed_receipt["publication_sha256"] = _sha256(_canonical(changed_receipt["publication"]))
	var receipt_conflict: Dictionary = ledger.record_before_emit(changed_receipt)
	assert_false(receipt_conflict.get("ok", true), "a changed semantic receipt conflicts")
	assert_eq(receipt_conflict.get("code"), &"publication_record_conflict")
	assert_eq(_raw_document(), durable)

	var restarted := _loaded(JsonFileStorage.new(_root))
	var cold_conflict: Dictionary = restarted.record_before_emit(changed_publication)
	assert_false(cold_conflict.get("ok", true), "the conflict law survives a restart")
	assert_eq(cold_conflict.get("code"), &"publication_record_conflict")
	assert_eq(_raw_document(), durable)


func test_request_member_hash_and_receipt_binding_are_enforced_before_any_write() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var empty_document := _raw_document()
	var cases: Array[Dictionary] = []

	var extra := _commit_request()
	extra["unexpected"] = true
	cases.append({"name": "extra request member", "request": extra})

	var missing := _commit_request()
	missing.erase("publication_sha256")
	cases.append({"name": "missing request member", "request": missing})

	var wrong_hash := _commit_request()
	wrong_hash["publication_sha256"] = "0".repeat(64)
	cases.append({"name": "hash does not match the publication", "request": wrong_hash})

	var upper_hash := _commit_request()
	upper_hash["publication_sha256"] = str(upper_hash["publication_sha256"]).to_upper()
	cases.append({"name": "uppercase hash", "request": upper_hash})

	var unknown_kind := _commit_request()
	unknown_kind["kind"] = "schedule_view"
	cases.append({"name": "unknown kind", "request": unknown_kind})

	var name_kind := _commit_request()
	name_kind["kind"] = &"schedule_commit"
	cases.append({"name": "StringName kind", "request": name_kind})

	var wrong_publication_keys := _commit_request()
	(wrong_publication_keys["publication"] as Dictionary).erase("committed_schedule")
	wrong_publication_keys["publication_sha256"] = _sha256(_canonical(wrong_publication_keys["publication"]))
	cases.append({"name": "publication member set", "request": wrong_publication_keys})

	var widened_publication := _commit_request()
	widened_publication["publication"]["schedule_view"] = {}
	widened_publication["publication_sha256"] = _sha256(_canonical(widened_publication["publication"]))
	cases.append({"name": "widened publication", "request": widened_publication})

	var unbound_receipt := _commit_request()
	unbound_receipt["semantic_receipt"] = _commit_receipt("2")
	cases.append({"name": "semantic receipt is not the publication receipt",
		"request": unbound_receipt})

	var blank_receipt := _commit_request()
	blank_receipt["semantic_receipt"]["receipt_id"] = ""
	blank_receipt["publication"]["schedule_commit_receipt"]["receipt_id"] = ""
	blank_receipt["publication_sha256"] = _sha256(_canonical(blank_receipt["publication"]))
	cases.append({"name": "blank semantic receipt id", "request": blank_receipt})

	var start_shape := _start_request()
	start_shape["kind"] = "schedule_commit"
	cases.append({"name": "kind and publication shape disagree", "request": start_shape})

	for entry: Dictionary in cases:
		var rejected: Dictionary = ledger.record_before_emit(entry["request"])
		assert_false(rejected.get("ok", true), "RED ledger request: " + str(entry["name"]))
		assert_ne(rejected.get("code"), &"publication_record_conflict", str(entry["name"]))
		assert_eq(_raw_document(), empty_document, "a rejected request writes nothing: " + str(entry["name"]))


func test_load_rejects_every_extra_missing_or_type_changed_document_member() -> void:
	if not _require_ledger():
		return
	var valid_record := {
		"key": "schedule_commit:x",
		"kind": "schedule_commit",
		"semantic_receipt": {"receipt_id": "x"},
		"publication": {"committed_schedule": {}, "schedule_commit_receipt": {"receipt_id": "x"}},
		"publication_sha256": "",
	}
	valid_record["publication_sha256"] = _sha256(_canonical(valid_record["publication"]))
	var valid_document := {"schema_version": 1, "records": {"schedule_commit:x": valid_record}}
	assert_true(_loaded_document_accepted(valid_document), "the exact union loads")

	var cases: Array[Dictionary] = []
	var extra := valid_document.duplicate(true)
	extra["records_backup"] = {}
	cases.append({"name": "extra document member", "document": extra})

	var missing := valid_document.duplicate(true)
	missing.erase("records")
	cases.append({"name": "missing records", "document": missing})

	var version := valid_document.duplicate(true)
	version["schema_version"] = 2
	cases.append({"name": "unsupported schema_version", "document": version})

	var string_version := valid_document.duplicate(true)
	string_version["schema_version"] = "1"
	cases.append({"name": "type-changed schema_version", "document": string_version})

	var array_records := valid_document.duplicate(true)
	array_records["records"] = []
	cases.append({"name": "type-changed records", "document": array_records})

	var extra_member := valid_document.duplicate(true)
	extra_member["records"]["schedule_commit:x"]["applied"] = true
	cases.append({"name": "extra record member", "document": extra_member})

	var missing_member := valid_document.duplicate(true)
	(missing_member["records"]["schedule_commit:x"] as Dictionary).erase("publication_sha256")
	cases.append({"name": "missing record member", "document": missing_member})

	var key_disagreement := valid_document.duplicate(true)
	key_disagreement["records"]["schedule_commit:x"]["key"] = "schedule_commit:y"
	cases.append({"name": "record key disagrees with its index", "document": key_disagreement})

	var kind_disagreement := valid_document.duplicate(true)
	kind_disagreement["records"]["schedule_commit:x"]["kind"] = "day_resolution_start"
	cases.append({"name": "kind disagrees with the derived key", "document": kind_disagreement})

	var hash_disagreement := valid_document.duplicate(true)
	hash_disagreement["records"]["schedule_commit:x"]["publication_sha256"] = "0".repeat(64)
	cases.append({"name": "stored hash disagrees with stored publication",
		"document": hash_disagreement})

	var receipt_disagreement := valid_document.duplicate(true)
	receipt_disagreement["records"]["schedule_commit:x"]["semantic_receipt"] = {"receipt_id": "y"}
	cases.append({"name": "stored receipt is not the publication receipt",
		"document": receipt_disagreement})

	for entry: Dictionary in cases:
		assert_false(_loaded_document_accepted(entry["document"]),
			"RED ledger document: " + str(entry["name"]))

	assert_false(_loaded_text_accepted("not json at all"), "unparseable storage fails closed")
	assert_false(_loaded_text_accepted("[]"), "a non-object document fails closed")


func _loaded_document_accepted(document: Dictionary) -> bool:
	return _loaded_text_accepted(_canonical(document) + "\n")


func _loaded_text_accepted(text: String) -> bool:
	var root := _isolated_root("document")
	var path := root.path_join(FIXED_PATH)
	assert_eq(DirAccess.make_dir_recursive_absolute(path.get_base_dir()), OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()
	var ledger := _new_ledger()
	assert_true(ledger.configure(JsonFileStorage.new(root)).get("ok", false))
	var loaded: Dictionary = ledger.load()
	if loaded.get("ok", false):
		return true
	return false


func test_records_and_documents_are_strictly_detached_primitives() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var request := _commit_request()
	var recorded: Dictionary = ledger.record_before_emit(request)
	assert_true(recorded.get("ok", false), str(recorded))
	if not recorded.get("ok", false):
		return
	var record: Dictionary = recorded["value"]["record"]
	var durable := _raw_document()
	record["publication"]["committed_schedule"]["entries"] = ["forged"]
	record["semantic_receipt"]["receipt_id"] = "forged"
	request["publication"]["committed_schedule"]["day"] = 9
	assert_eq(_raw_document(), durable, "mutating a returned record cannot reach storage")
	var replay: Dictionary = _loaded(JsonFileStorage.new(_root)).record_before_emit(_commit_request())
	assert_true(replay.get("ok", false), str(replay))
	assert_false(bool(replay["value"]["first_delivery"]),
		"the original request still replays after caller mutation")


func test_write_read_and_schema_failures_return_failure_without_recording() -> void:
	if not _require_ledger():
		return
	var failing := FailingStorage.new(_storage)
	var ledger := _configured(failing)
	assert_true(ledger.load().get("ok", false), str(ledger))
	var durable := _raw_document()

	failing.fail_write = true
	var write_failed: Dictionary = ledger.record_before_emit(_commit_request())
	assert_false(write_failed.get("ok", true), "a write failure is a failure")
	assert_eq(_raw_document(), durable, "a failed write records nothing")
	failing.fail_write = false

	var recorded: Dictionary = ledger.record_before_emit(_commit_request())
	assert_true(recorded.get("ok", false), str(recorded))
	assert_true(bool(recorded["value"]["first_delivery"]),
		"no failed attempt was ever recorded, so the first success is still first")

	# A re-read that disagrees with the exact candidate is a failure, on its own isolated root so
	# the polluted document cannot be mistaken for the successful record above.
	var corrupting := FailingStorage.new(JsonFileStorage.new(_isolated_root("reread")))
	var corrupt_ledger := _configured(corrupting)
	assert_true(corrupt_ledger.load().get("ok", false))
	corrupting.corrupt_read = true
	var reread_failed: Dictionary = corrupt_ledger.record_before_emit(_commit_request())
	assert_false(reread_failed.get("ok", true),
		"the ledger must byte-compare its re-read before reporting success")

	var unreadable := FailingStorage.new(JsonFileStorage.new(_isolated_root("unreadable")))
	unreadable.fail_read = true
	var read_failed: Dictionary = _configured(unreadable).load()
	assert_false(read_failed.get("ok", true), "an unreadable document fails startup")


func test_configure_requires_the_root_scoped_capability_and_refuses_replacement() -> void:
	if not _require_ledger():
		return
	var ledger := _new_ledger()
	assert_false(ledger.configure(null).get("ok", true), "a storage capability is required")
	assert_false(ledger.configure(RefCounted.new()).get("ok", true),
		"the storage must expose the exact adapter capability")
	assert_false(ledger.load().get("ok", true), "load before configure fails")
	assert_false(ledger.record_before_emit(_commit_request()).get("ok", true),
		"record_before_emit before configure fails")
	assert_true(ledger.configure(_storage).get("ok", false))
	assert_true(ledger.configure(_storage).get("ok", false), "identical configuration replays")
	assert_false(ledger.configure(JsonFileStorage.new(_root)).get("ok", true),
		"a second root owner is refused")
	assert_false(_new_ledger().configure(JsonFileStorage.new("")).get("ok", true),
		"an unrooted storage is refused")
