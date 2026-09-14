extends "res://addons/gut/test.gd"
# Durable desktop consequence-publication ledger (Plan 02 Task 6, dwm-p2r.32).
#
# Mirrors test_schedule_foundation_publication_ledger.gd's discipline: the subject is the REAL
# ledger over the REAL JsonFileStorage over a GUID-isolated temporary root. A restart is modelled by
# rebuilding the whole stack over the same bytes, never by flipping an in-memory flag.
#
# FIX (dwm-p2r.35.1 remediation, finding W1): the ledger's closed kind union is exactly
# `causal_sequence|action_source|board_fate` (plan02-frozen-contracts.md line 328), each with its OWN
# publication shape (line 335) -- NOT the causal reservation's own `minesweeper_round|shop_purchase|
# schedule_done` union a prior implementation/test pair reused here uniformly. This file's fixtures
# below build the three REAL per-kind shapes.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const LEDGER_PATH := "res://scripts/infrastructure/save/DesktopPublicationLedger.gd"
const OTHER_LEDGER_PATH := "res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd"
const FIXED_PATH := "desktop-publications.json"
# The strict parser the ledger's OLD normalization path went through; the golden bytes in the
# dwm-634.3 session-4 guard below are computed the old way, in-test, and compared to disk.
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const RECORD_KEYS: Array[String] = [
	"key", "kind", "publication", "publication_sha256", "semantic_receipt",
]

var _ledger_script: Script = null
var _root := ""
var _storage: RefCounted = null


func before_each() -> void:
	_root = ""
	_storage = null
	var loaded: Dictionary = PROBE.load_script(LEDGER_PATH)
	_ledger_script = loaded["value"] if loaded.get("ok", false) else null
	_root = _isolated_root("desktop-ledger")
	if _root.is_empty():
		return
	_storage = JsonFileStorage.new(_root)


func _isolated_root(label: String) -> String:
	var created: Dictionary = TemporaryStorage.create("desktop-publication-" + label)
	assert_true(created.get("ok", false), str(created))
	return str(created.get("value", "")) if created.get("ok", false) else ""


func _require_ledger() -> bool:
	if _root.is_empty() or _storage == null:
		assert_true(false, "desktop ledger temporary storage is unavailable")
		return false
	if _ledger_script == null:
		assert_true(false, "DesktopPublicationLedger is absent: " + LEDGER_PATH)
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


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted["value"])


func _sha256(value: Variant) -> String:
	return _canonical(value).sha256_text()


# ---- per-kind fixture builders (frozen contract line 335) ----

func _causal_publication(receipt_id: String) -> Dictionary:
	return {
		"admission_checkpoint_receipt": {"receipt_id": "admission." + receipt_id},
		"causal_sequence_receipt": {"receipt_id": receipt_id, "causal_sequence": 1},
	}


func _causal_request(receipt_id: String) -> Dictionary:
	var publication := _causal_publication(receipt_id)
	return {
		"kind": "causal_sequence", "publication": publication,
		"publication_sha256": _sha256(publication), "semantic_receipt": publication,
	}


func _action_publication(commit_receipt_id: String) -> Dictionary:
	return {
		"action_candidate_sha256": "sha-" + commit_receipt_id,
		"action_receipt": {"commit_receipt_id": commit_receipt_id, "action_kind": "minesweeper_round"},
	}


func _action_request(commit_receipt_id: String) -> Dictionary:
	var publication := _action_publication(commit_receipt_id)
	return {
		"kind": "action_source", "publication": publication,
		"publication_sha256": _sha256(publication), "semantic_receipt": publication["action_receipt"],
	}


func _board_fate_publication(receipt_id: String) -> Dictionary:
	return {
		"board_candidate": {"phase": "NONE"},
		"board_fate_receipt": {"receipt_id": receipt_id, "fate": "none"},
	}


func _board_fate_request(receipt_id: String) -> Dictionary:
	var publication := _board_fate_publication(receipt_id)
	return {
		"kind": "board_fate", "publication": publication,
		"publication_sha256": _sha256(publication), "semantic_receipt": publication["board_fate_receipt"],
	}


func _request_for(kind: String, id_value: String) -> Dictionary:
	match kind:
		"causal_sequence":
			return _causal_request(id_value)
		"action_source":
			return _action_request(id_value)
		"board_fate":
			return _board_fate_request(id_value)
	return {}


func test_fixed_path_and_kinds_are_frozen() -> void:
	if not _require_ledger():
		return
	assert_eq(_ledger_script.FIXED_PATH, FIXED_PATH)
	assert_eq(_ledger_script.KINDS, ["causal_sequence", "action_source", "board_fate"])


func test_missing_file_initializes_the_exact_empty_document() -> void:
	if not _require_ledger():
		return
	var path := _root.path_join(FIXED_PATH)
	assert_false(FileAccess.file_exists(path))
	var ledger := _loaded()
	assert_true(FileAccess.file_exists(path))
	var raw := FileAccess.get_file_as_string(path)
	assert_eq(raw, _canonical({"schema_version": 1, "records": {}}) + "\n")
	var loaded: Dictionary = ledger.load()
	assert_eq(loaded["value"]["document"], {"schema_version": 1, "records": {}})


func test_three_exact_kind_unions_accepted_and_extra_kind_rejected() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	for kind: String in ["causal_sequence", "action_source", "board_fate"]:
		var recorded: Dictionary = ledger.record_before_emit(_request_for(kind, "receipt-" + kind))
		assert_true(recorded.get("ok", false), str(recorded))
		assert_eq(recorded["value"]["record"]["kind"], kind)
		assert_true(recorded["value"]["first_delivery"])
	# The causal reservation's OWN source_kind union is a closed but DISJOINT set: the ledger must
	# reject it exactly as it rejects any other out-of-union kind (finding W1's own root cause).
	for bad_kind: String in ["minesweeper_round", "shop_purchase", "schedule_done", "desktop_notification"]:
		var bad_request := _causal_request("receipt-bad-" + bad_kind)
		bad_request["kind"] = bad_kind
		var rejected: Dictionary = ledger.record_before_emit(bad_request)
		assert_false(rejected.get("ok", true), bad_kind + " must be rejected")
		assert_eq(rejected["code"], &"publication_request_invalid")


func test_document_and_record_union_is_exact_after_one_publication() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var recorded: Dictionary = ledger.record_before_emit(_causal_request("receipt-1"))
	assert_true(recorded.get("ok", false), str(recorded))
	var record: Dictionary = recorded["value"]["record"]
	var keys: Array = record.keys()
	keys.sort()
	assert_eq(keys, RECORD_KEYS)
	assert_eq(record["key"], "causal_sequence:receipt-1")
	var loaded: Dictionary = ledger.load()
	var document_keys: Array = (loaded["value"]["document"] as Dictionary).keys()
	document_keys.sort()
	assert_eq(document_keys, ["records", "schema_version"])


## Regression guard requested during dwm-p2r.35.1 remediation review: a hand-rolled test double
## elsewhere in this suite once derived the causal_sequence key's id from the WRONG (absent)
## top-level field, silently producing an empty suffix ("causal_sequence:") for every transaction --
## which made two DISTINCT transactions collide on the identical key and reject the second as a
## conflict. The REAL ledger's own _receipt_id_for_key() already reads the correct NESTED path
## (causal_sequence_receipt.receipt_id) and _publication_binding_error() already rejects a blank id
## outright, but this test pins the externally observable guarantee directly: two different
## transactions' causal_sequence publications must derive two different, nonblank keys.
func test_causal_sequence_keys_are_nonblank_and_distinct_per_transaction() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var first: Dictionary = ledger.record_before_emit(_causal_request("txn-a-receipt"))
	assert_true(first.get("ok", false), str(first))
	var second: Dictionary = ledger.record_before_emit(_causal_request("txn-b-receipt"))
	assert_true(second.get("ok", false), str(second))
	var first_key: String = first["value"]["record"]["key"]
	var second_key: String = second["value"]["record"]["key"]
	assert_false(first_key.trim_prefix("causal_sequence:").is_empty(), "the first key's id suffix must be nonblank")
	assert_false(second_key.trim_prefix("causal_sequence:").is_empty(), "the second key's id suffix must be nonblank")
	assert_ne(first_key, second_key, "two distinct transactions must never collide on the same ledger key")


func test_action_source_key_derives_from_commit_receipt_id_not_receipt_id() -> void:
	# Finding W1: DesktopActionReceipt has no top-level receipt_id member at all -- the record key
	# must derive from its own commit_receipt_id instead.
	if not _require_ledger():
		return
	var ledger := _loaded()
	var recorded: Dictionary = ledger.record_before_emit(_action_request("commit-1"))
	assert_true(recorded.get("ok", false), str(recorded))
	assert_eq(recorded["value"]["record"]["key"], "action_source:commit-1")
	assert_false((recorded["value"]["record"]["semantic_receipt"] as Dictionary).has("receipt_id"))


func test_board_fate_key_derives_from_ordinary_receipt_id() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var recorded: Dictionary = ledger.record_before_emit(_board_fate_request("board-fate-1"))
	assert_true(recorded.get("ok", false), str(recorded))
	assert_eq(recorded["value"]["record"]["key"], "board_fate:board-fate-1")


func test_causal_sequence_semantic_receipt_equals_publication_in_its_entirety() -> void:
	# Frozen contract line 335: "semantic receipt and publication are both exactly
	# {causal_sequence_receipt,admission_checkpoint_receipt}" -- unlike action_source/board_fate,
	# there is no separate wrapper: the two dictionaries must be byte-equal, not merely one nested
	# inside the other.
	if not _require_ledger():
		return
	var ledger := _loaded()
	var publication := _causal_publication("receipt-equal")
	var mismatched := {
		"kind": "causal_sequence", "publication": publication,
		"publication_sha256": _sha256(publication),
		"semantic_receipt": publication["causal_sequence_receipt"],
	}
	var rejected: Dictionary = ledger.record_before_emit(mismatched)
	assert_false(rejected.get("ok", true), "semantic_receipt must equal the WHOLE publication, not just the nested receipt")


func test_first_delivery_then_byte_identical_replay_across_a_cold_restart() -> void:
	if not _require_ledger():
		return
	var request := _action_request("receipt-2")
	var first_ledger := _loaded()
	var first: Dictionary = first_ledger.record_before_emit(request)
	assert_true(first.get("ok", false), str(first))
	assert_true(first["value"]["first_delivery"])

	# Cold restart: a fresh ledger instance over the same storage bytes.
	var second_ledger := _loaded()
	var second: Dictionary = second_ledger.record_before_emit(request)
	assert_true(second.get("ok", false), str(second))
	assert_false(second["value"]["first_delivery"], "a cold instance must re-read and answer false")
	assert_eq(second["value"]["record"], first["value"]["record"])


func test_occupied_key_with_changed_bytes_conflicts_without_rewriting_storage() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var first: Dictionary = ledger.record_before_emit(_board_fate_request("receipt-3"))
	assert_true(first.get("ok", false), str(first))
	var path := _root.path_join(FIXED_PATH)
	var before := FileAccess.get_file_as_string(path)

	var changed_publication := _board_fate_publication("receipt-3")
	changed_publication["board_candidate"] = {"phase": "PREPARING"}
	var changed_request := {
		"kind": "board_fate", "publication": changed_publication,
		"publication_sha256": _sha256(changed_publication),
		"semantic_receipt": changed_publication["board_fate_receipt"],
	}
	var conflicted: Dictionary = ledger.record_before_emit(changed_request)
	assert_false(conflicted.get("ok", true))
	assert_eq(conflicted["code"], &"publication_record_conflict")
	assert_eq(FileAccess.get_file_as_string(path), before, "a rejected conflict never rewrites storage")


func test_request_hash_and_receipt_binding_enforced_before_any_write() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var path := _root.path_join(FIXED_PATH)
	var before := FileAccess.get_file_as_string(path)

	var wrong_hash := _causal_request("receipt-4")
	wrong_hash["publication_sha256"] = "0".repeat(64)
	var rejected_hash: Dictionary = ledger.record_before_emit(wrong_hash)
	assert_false(rejected_hash.get("ok", true))

	var unbound := _action_request("receipt-5")
	unbound["semantic_receipt"] = {"commit_receipt_id": "receipt-different"}
	var rejected_binding: Dictionary = ledger.record_before_emit(unbound)
	assert_false(rejected_binding.get("ok", true))

	assert_eq(FileAccess.get_file_as_string(path), before, "invalid requests never write storage")


func test_configure_requires_the_root_scoped_capability_and_refuses_replacement() -> void:
	if not _require_ledger():
		return
	var ledger := _new_ledger()
	assert_false(ledger.configure(null).get("ok", true))
	var incomplete := RefCounted.new()
	assert_false(ledger.configure(incomplete).get("ok", true))
	var first: Dictionary = ledger.configure(_storage)
	assert_true(first.get("ok", false), str(first))
	var replay: Dictionary = ledger.configure(_storage)
	assert_true(replay.get("ok", false))
	assert_true(replay["value"]["already_configured"])
	var other_path := _isolated_root("desktop-ledger-other")
	if other_path.is_empty():
		return
	var other_root := JsonFileStorage.new(other_path)
	var rejected: Dictionary = ledger.configure(other_root)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"publication_ledger_already_configured")


## MINOR: no malformed-on-disk-JSON startup test previously existed for this ledger (byte-for-byte
## the Plan-01 ledger's own laws per this file's class doc comment, but that coverage was never
## actually written here). A fresh ledger instance over bytes that are not even valid JSON syntax
## must fail closed with a typed error, not crash or silently accept a corrupt document.
func test_load_fails_closed_on_malformed_on_disk_json() -> void:
	if not _require_ledger():
		return
	# Seed a genuine document first, then corrupt it in place -- exercising the same "restart over
	# already-durable bytes" substrate every other test in this file uses.
	_loaded()
	var path := _root.path_join(FIXED_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "the seeded document must be overwritable for this test")
	file.store_string("{ not actually json ]")
	file.close()

	var restarted := _new_ledger()
	var configured: Dictionary = restarted.configure(_storage)
	assert_true(configured.get("ok", false), str(configured))
	var loaded: Dictionary = restarted.load()
	assert_false(loaded.get("ok", true), "malformed on-disk bytes must fail closed, not parse as an empty/valid document")
	# dwm-634.3 session 6: the storage-witness callable never sees these bytes in its memo, so it
	# delegates to the full reader and the refusal is the SAME typed storage failure as before --
	# corrupt final bytes leave storage unable to prove one winner.
	assert_eq(loaded.get("code"), &"indeterminate_transaction", str(loaded))
	var refused: Dictionary = restarted.record_before_emit(_causal_request("receipt-after-corruption"))
	assert_false(refused.get("ok", true), "a record over corrupt durable bytes must be refused")
	assert_eq(refused.get("code"), &"indeterminate_transaction", str(refused))
	assert_eq(FileAccess.get_file_as_string(path), "{ not actually json ]",
		"a refused record never rewrites the corrupt bytes")


func test_exact_text_validation_cache_is_bounded_and_changed_bytes_fail_closed() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	for index: int in 4:
		var recorded: Dictionary = ledger.record_before_emit(_action_request("cache-" + str(index)))
		assert_true(recorded.get("ok", false), str(recorded))
	assert_eq(ledger._validated_text_documents.size(), 3)
	assert_eq(ledger._validated_text_order.size(), 3)
	var current_text := FileAccess.get_file_as_string(_root.path_join(FIXED_PATH))
	assert_true(ledger._parse_known_document(current_text).get("ok", false))
	var changed := current_text.trim_suffix(String.chr(10)) + " trailing"
	assert_false(ledger._parse_known_document(changed).get("ok", true),
		"changed bytes must take the strict parser and fail closed")
	var schema_invalid := '{"records":[],"schema_version":1}'
	assert_true(ledger._parse_known_storage_text(schema_invalid).get("ok", false),
		"storage validation may retain a strictly parsed document")
	var rejected_schema: Dictionary = ledger._parse_known_document(schema_invalid)
	assert_false(rejected_schema.get("ok", true),
		"a strict-only cache entry must still receive full document validation")
	assert_eq(rejected_schema.get("code"), &"publication_ledger_schema_invalid")


func test_disjoint_from_plan01_schedule_foundation_ledger() -> void:
	if not _require_ledger():
		return
	assert_ne(LEDGER_PATH, OTHER_LEDGER_PATH)
	assert_ne(_ledger_script.FIXED_PATH, "schedule-foundation-publications.json")
	var probed: Dictionary = PROBE.load_script(OTHER_LEDGER_PATH)
	assert_true(probed.get("ok", false), "the Plan 01 ledger must still exist and load")
	var other_script: Script = probed["value"]
	assert_ne(_ledger_script.KINDS, other_script.KINDS)
	# The two ledgers even at the same storage root never collide on a fixed relative path.
	var ledger := _loaded()
	var other: Object = other_script.new()
	other.configure(_storage)
	other.load()
	var desktop_path := _root.path_join(_ledger_script.FIXED_PATH)
	var other_path := _root.path_join(other_script.FIXED_PATH)
	assert_ne(desktop_path, other_path)
	assert_true(FileAccess.file_exists(desktop_path))
	assert_true(FileAccess.file_exists(other_path))


# ---- dwm-634.3 session 4: normalize the new record by walk, not by emit+reparse ----
#
# `_commit_new_entry` used to turn a production caller's StringName keys/values into Strings by
# emitting the whole new record canonically and strict-parsing that text back -- for a board_fate
# record that is a ~100 KB emit plus a ~100 KB parse whose ONLY job is a type fold. Then
# `_record_shape_error` recomputed the publication digest the request check had just proven, and
# `_confirm_written_entry` emitted the candidate AND the re-read record a second time each just to
# compare them. Session 4 replaces the emit+reparse with `_normalize_engine_text()`, an
# identity-preserving StringName -> String walk mirrored exactly from SaveDocumentSchema.gd
# (containers are rebuilt ONLY when something inside converted; ints/floats/bools/nulls/Strings
# pass through untouched), hands the already-known digest into `_record_shape_error`, and confirms
# the durable record with `CanonicalJsonWriter._deep_same()` instead of two more emits. The bytes
# on disk must stay byte-identical: the first test pins the source, the second is the behavioural
# guard (golden bytes computed the OLD way, in-test), the third drives the walk directly.


func test_commit_normalizes_the_new_record_by_walk_not_by_reparse() -> void:
	if not _require_ledger():
		return
	var source := FileAccess.get_file_as_string(LEDGER_PATH)
	assert_false(source.is_empty(), "the ledger source must be readable: " + LEDGER_PATH)
	# The walk exists and replaced the ~100 KB emit+reparse of the new board_fate record.
	assert_true(source.contains("static func _normalize_engine_text("),
		"the ledger must own an identity-preserving _normalize_engine_text() walk")
	assert_false(source.contains("_JSON.parse_object(entry_text)"),
		"the new record must no longer be normalized by strict-parsing its own canonical emit")
	# Confirmation compares structurally; the two per-commit confirmation emits are gone.
	assert_true(source.contains("_CANON._deep_same(entry, reparsed_entry)"),
		"_confirm_written_entry must compare the durable record with CanonicalJsonWriter._deep_same")
	assert_false(source.contains("_digest_source(reparsed_entry) != _digest_source(entry)"),
		"_confirm_written_entry must not emit the candidate and the re-read record a second time")


func test_engine_typed_board_fate_entry_writes_the_exact_emit_reparse_bytes() -> void:
	if not _require_ledger():
		return
	# An "engine typed" publication: the two top-level members stay String-keyed (PUBLICATION_KEYS
	# must match exactly), but inside board_candidate a production caller may embed StringName keys
	# and values, a typed Array, insertion-ordered nested keys, ints, floats and non-ASCII text.
	var receipt_id := "engine-typed-1"
	var key := "board_fate:" + receipt_id
	var cells: Array[String] = ["a", "b"]
	var receipt := {"receipt_id": receipt_id, "fate": &"none"}
	var publication := {
		"board_candidate": {
			&"phase": &"ACTIVE_VISIBLE",
			"cells": cells,
			"nested": {"zeta": 3, "alpha": {"ratio": 2.5, "unit": 1.0}},
			"label": "你好",
		},
		"board_fate_receipt": receipt,
	}
	# semantic_receipt is the SAME object as publication.board_fate_receipt, as the port hands it in.
	var request := {
		"kind": "board_fate", "publication": publication,
		"publication_sha256": _sha256(publication), "semantic_receipt": receipt,
	}
	var ledger := _loaded()
	var recorded: Dictionary = ledger.record_before_emit(request)
	assert_true(recorded.get("ok", false), str(recorded))
	assert_true(recorded["value"]["first_delivery"])

	# GOLDEN: the bytes the OLD path produced -- canonical emit of the new record, strict-parsed
	# back (StringName -> String, typed Array -> untyped, key order canonical), then the whole
	# document emitted canonically. The walk must land on exactly these bytes.
	var entry := {
		"key": key,
		"kind": "board_fate",
		"semantic_receipt": receipt.duplicate(true),
		"publication": publication.duplicate(true),
		"publication_sha256": _sha256(publication),
	}
	var entry_text := _canonical(entry)
	var reparsed: Dictionary = STRICT_JSON.parse_object(entry_text)
	assert_true(reparsed.get("ok", false), str(reparsed))
	var normalized: Dictionary = reparsed["value"]
	var golden := _canonical({"records": {key: normalized}, "schema_version": 1}) + "\n"
	assert_eq(FileAccess.get_file_as_string(_root.path_join(FIXED_PATH)), golden,
		"the walk-normalized record must write byte-identical bytes to the old emit+reparse path")

	# Cold restart over the same bytes: the durable record reads back as the golden normalized
	# record, and the identical engine-typed request replays as a no-op success.
	var restarted := _loaded()
	var loaded: Dictionary = restarted.load()
	assert_eq(loaded["value"]["document"]["records"][key], normalized)
	var replay: Dictionary = restarted.record_before_emit(request)
	assert_true(replay.get("ok", false), str(replay))
	assert_false(replay["value"]["first_delivery"], "a cold instance must re-read and answer false")


func test_normalize_engine_text_folds_string_names_and_preserves_identity_and_number_types() -> void:
	if not _require_ledger():
		return
	# RED until session 4 lands: the walk does not exist on the ledger yet.
	var has_walk := false
	for method: Dictionary in _ledger_script.get_script_method_list():
		if str(method.get("name", "")) == "_normalize_engine_text":
			has_walk = true
	assert_true(has_walk, "DesktopPublicationLedger must own static _normalize_engine_text()")
	if not has_walk:
		return
	var value := {
		&"phase": &"NONE",
		"plain": {"n": 3, "f": 1.0, "s": "x"},
		"list": [&"a", 2],
		"mixed": {&"k": 1.0},
	}
	# Static call through the loaded Script, so the analyzer never binds the name at parse time.
	var result: Variant = _ledger_script.call(&"_normalize_engine_text", value)
	assert_eq(typeof(result), TYPE_DICTIONARY)
	if typeof(result) != TYPE_DICTIONARY:
		return
	var folded: Dictionary = result
	# StringName values fold to String; StringName keys fold to String keys.
	assert_eq(typeof(folded["phase"]), TYPE_STRING)
	assert_eq(folded["phase"], "NONE")
	var result_phase_key_type := -1
	for result_key: Variant in folded.keys():
		if str(result_key) == "phase":
			result_phase_key_type = typeof(result_key)
	assert_eq(result_phase_key_type, TYPE_STRING, "the folded key must be a String, not a StringName")
	# A StringName-free subtree comes back by identity, with its number types untouched.
	assert_true(is_same(folded["plain"], value["plain"]),
		"a StringName-free subtree must be returned as the same object")
	assert_eq(typeof(folded["plain"]["n"]), TYPE_INT)
	assert_eq(typeof(folded["plain"]["f"]), TYPE_FLOAT)
	# A converted Array is rebuilt with its non-StringName elements intact.
	assert_eq(typeof(folded["list"][0]), TYPE_STRING)
	assert_eq(folded["list"][0], "a")
	assert_eq(folded["list"][1], 2)
	assert_eq(typeof(folded["list"][1]), TYPE_INT)
	# A rebuilt dictionary keeps a float a float (a JSON round trip is what used to do this job).
	assert_false(is_same(folded["mixed"], value["mixed"]), "a converted subtree must be a fresh object")
	assert_eq(typeof(folded["mixed"]["k"]), TYPE_FLOAT)
	# The SOURCE is never mutated: its StringName key and value survive the walk.
	assert_eq(typeof(value[&"phase"]), TYPE_STRING_NAME)
	assert_true(value.has(&"phase"))
	var source_phase_key_type := -1
	for source_key: Variant in value.keys():
		if str(source_key) == "phase":
			source_phase_key_type = typeof(source_key)
	assert_eq(source_phase_key_type, TYPE_STRING_NAME, "the source key must still be a StringName")
	assert_eq(typeof(value["list"][0]), TYPE_STRING_NAME)
	# A fully StringName-free dictionary is returned as the same object, not a copy.
	var clean := {"a": 1, "b": [1, 2.5, "x", null, true], "c": {"d": "e"}}
	var clean_result: Variant = _ledger_script.call(&"_normalize_engine_text", clean)
	assert_true(is_same(clean_result, clean), "a StringName-free dictionary must be returned by identity")


# ---- dwm-634.3 session 5: compose the append from a per-record canonical cache ----
#
# `_commit_new_entry` used to canonicalize the WHOLE document for every append: on a real account
# that is ~800 KB over ~110 records, 44-50 ms of emit per record_before_emit, beside four deep
# copies of that same document (the refresh's parse AND its own re-copy of it, the candidate, the
# memo seed) and a fifth to fetch ONE record back out of the memo during confirmation. Session 5
# keeps, beside the cached document, the exact canonical text of every record and of every other
# top-level field -- the arrangement DesktopIssuerRootStore._write_issued_document() already uses
# for the issuer root -- and composes the outgoing text from those cached pieces plus ONE emit of
# the new record. The cache lives inside the validated-text memo, so it shares the lifetime of the
# exact text it describes, and anything it cannot describe falls back to the historical full emit.
#
# The bytes on disk must not move by one byte. The rows below pin them against the full canonical
# writer after EVERY write, across a cold restart, across an external change to the file, and after
# a refused write; the source rows pin which emit path fired and which deep copies are gone.


class FailingStorage:
	extends RefCounted

	var _inner: RefCounted
	var fail_write := false

	func _init(inner: RefCounted) -> void:
		_inner = inner

	func describe_root() -> String:
		return _inner.describe_root()

	func exists(relative_path: String) -> bool:
		return _inner.exists(relative_path)

	func reconcile(relative_path: String, validator: Callable) -> Dictionary:
		return _inner.reconcile(relative_path, validator)

	func read_text(relative_path: String) -> Dictionary:
		return _inner.read_text(relative_path)

	func write_atomic(relative_path: String, text: String, validator: Callable,
			keep_backup: bool = true) -> Dictionary:
		if fail_write:
			return {"ok": false, "code": &"write_not_committed", "message": relative_path}
		return _inner.write_atomic(relative_path, text, validator, keep_backup)


## The record the OLD whole-document path produced for a request: the exact entry the ledger builds,
## canonically emitted and strict-parsed back (StringName -> String, typed Array -> untyped,
## canonical key order). Every golden document below is composed from these, so the goldens are
## computed the pre-cache way, exactly as the session-4 golden row above computes its own.
func _old_path_record(key: String, request: Dictionary) -> Dictionary:
	var entry := {
		"key": key,
		"kind": str(request["kind"]),
		"semantic_receipt": (request["semantic_receipt"] as Dictionary).duplicate(true),
		"publication": (request["publication"] as Dictionary).duplicate(true),
		"publication_sha256": str(request["publication_sha256"]),
	}
	var reparsed: Dictionary = STRICT_JSON.parse_object(_canonical(entry))
	assert_true(reparsed.get("ok", false), str(reparsed))
	return reparsed["value"] if reparsed.get("ok", false) else {}


func _golden_document(records: Dictionary) -> String:
	return _canonical({"records": records, "schema_version": 1}) + "\n"


func _exotic_board_fate_request(receipt_id: String, board_candidate: Dictionary) -> Dictionary:
	var receipt := {"receipt_id": receipt_id, "fate": &"none"}
	var publication := {"board_candidate": board_candidate, "board_fate_receipt": receipt}
	return {
		"kind": "board_fate", "publication": publication,
		"publication_sha256": _sha256(publication), "semantic_receipt": receipt,
	}


## Six publications whose canonical text exercises everything a composer must reproduce exactly:
## StringName keys and values, insertion-ordered nested keys, the floats 1.0 and 2.5, non-ASCII
## text, and a string carrying the very punctuation the composition joins with. The float-free ones
## come FIRST on purpose -- CanonicalJsonWriter takes its native encoder while the whole document is
## float-free and its checked emitter once a float lands, so the composed bytes are pinned against
## both of the writer's own paths.
func _exotic_requests() -> Array:
	return [
		["board_fate:exotic-names", _exotic_board_fate_request("exotic-names", {
			&"phase": &"ACTIVE_VISIBLE", "zulu": {"mid": 4, "alpha": "x"}, "label": "你好",
		})],
		["board_fate:exotic-punctuation", _exotic_board_fate_request("exotic-punctuation", {
			"quoted": "he said \"{a,b}:c\" and \\ left", "empty": {},
		})],
		["action_source:exotic-commit", _action_request("exotic-commit")],
		["board_fate:exotic-floats", _exotic_board_fate_request("exotic-floats", {
			"ratio": 2.5, "unit": 1.0, "count": 3,
		})],
		["board_fate:exotic-nested", _exotic_board_fate_request("exotic-nested", {
			"nested": {"zeta": {"inner": 1.0}, "alpha": [1.0, 2.5, &"tag", "你好"]},
		})],
		["board_fate:exotic-plain", _board_fate_request("exotic-plain")],
	]


## RED-safe member probe: on a tree without the cache the member does not exist, so a row that reads
## it fails once with a readable message instead of erroring out mid-assertion.
func _has_ledger_property(property_name: String) -> bool:
	for property: Dictionary in _ledger_script.get_script_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	assert_true(false, "DesktopPublicationLedger must own " + property_name)
	return false


## The per-record canonical cache the ledger holds for the document it currently caches. Reaching
## into the validated-text memo is this suite's own idiom (see the bounded-cache row above).
func _canonical_cache_of(ledger: Object) -> Dictionary:
	var memo: Dictionary = ledger._validated_text_documents
	var cached_text: String = ledger._cached_text
	assert_true(memo.has(cached_text), "the cached document's own text must still be memoized")
	var entry: Dictionary = memo.get(cached_text, {})
	assert_true(entry.has("canonical_records"),
		"the memo entry for the cached document must carry the per-record canonical map")
	return entry.get("canonical_records", {})


func test_every_write_lands_on_the_full_canonical_writers_exact_bytes() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var path := _root.path_join(FIXED_PATH)
	var expected_records := {}
	for fixture: Array in _exotic_requests():
		var key := str(fixture[0])
		var request: Dictionary = fixture[1]
		var recorded: Dictionary = ledger.record_before_emit(request)
		assert_true(recorded.get("ok", false), key + ": " + str(recorded))
		expected_records[key] = _old_path_record(key, request)
		assert_eq(FileAccess.get_file_as_string(path), _golden_document(expected_records),
			"after " + key + " the document must be exactly what the full canonical writer emits")
	assert_eq(expected_records.size(), 6, "the fixture set must cover six distinct records")

	# Cold restart: a fresh instance over the same bytes rebuilds its cache from disk, and the next
	# record still lands on the full writer's exact bytes.
	var restarted := _loaded()
	var after_restart := _board_fate_request("after-restart")
	var restart_key := "board_fate:after-restart"
	var appended: Dictionary = restarted.record_before_emit(after_restart)
	assert_true(appended.get("ok", false), str(appended))
	expected_records[restart_key] = _old_path_record(restart_key, after_restart)
	assert_eq(FileAccess.get_file_as_string(path), _golden_document(expected_records),
		"a cache rebuilt from disk must compose exactly what the full writer emits")

	# A replay of an identical request stays a no-op success that writes nothing at all.
	var before_replay := FileAccess.get_file_as_string(path)
	var replay: Dictionary = restarted.record_before_emit(after_restart)
	assert_true(replay.get("ok", false), str(replay))
	assert_false(replay["value"]["first_delivery"], "an identical replay is not a first delivery")
	assert_eq(FileAccess.get_file_as_string(path), before_replay, "a replay writes nothing")


func test_the_append_is_composed_from_the_cached_per_record_texts() -> void:
	if not _require_ledger():
		return
	var source := FileAccess.get_file_as_string(LEDGER_PATH)
	assert_false(source.is_empty(), "the ledger source must be readable: " + LEDGER_PATH)
	assert_true(source.contains("func _compose_document_text("),
		"the ledger must compose the outgoing document from cached per-record canonical texts")
	assert_true(source.contains('profile["emit_path"] = "full" if composed.is_empty() else "composed"'),
		"the profile record must name which of the two emit paths fired")
	assert_true(source.contains('tick = _profile_phase(profile, "compose_us", tick)'),
		"the composed path must be timed under its own phase")
	assert_true(source.contains('tick = _profile_phase(profile, "full_emit_us", tick)'),
		"the full emit must keep its historical phase name for the fallback")
	if not _has_ledger_property("_cached_text"):
		return
	var ledger := _loaded()
	for index: int in 3:
		var recorded: Dictionary = ledger.record_before_emit(_action_request("composed-" + str(index)))
		assert_true(recorded.get("ok", false), str(recorded))
	var cache := _canonical_cache_of(ledger)
	assert_eq(cache.size(), 3, "every durable record must carry its own cached canonical text")
	var records: Dictionary = ledger._cached_document["records"]
	for record_key: Variant in records:
		assert_eq(str(cache.get(record_key, "")), _canonical(records[record_key]),
			"the cached text for " + str(record_key) + " must be what the writer emits for that record")


func test_external_bytes_between_two_writes_rebuild_the_cache_before_the_next_append() -> void:
	if not _require_ledger():
		return
	if not _has_ledger_property("_cached_text"):
		return
	var ledger := _loaded()
	var path := _root.path_join(FIXED_PATH)
	assert_true(ledger.record_before_emit(_board_fate_request("before-external")).get("ok", false),
		"the ledger must own a durable record before the file changes underneath it")

	# Different, still valid bytes written straight past the ledger, carrying a DIFFERENT record set:
	# a cache still describing the previous document would compose a record this file does not have.
	var external_request := _action_request("external-writer")
	var external_key := "action_source:external-writer"
	var external_records := {external_key: _old_path_record(external_key, external_request)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "the durable document must be overwritable for this test")
	if file == null:
		return
	file.store_string(_golden_document(external_records))
	file.close()

	var after_request := _board_fate_request("after-external")
	var after_key := "board_fate:after-external"
	var appended: Dictionary = ledger.record_before_emit(after_request)
	assert_true(appended.get("ok", false), str(appended))
	var expected_records := external_records.duplicate()
	expected_records[after_key] = _old_path_record(after_key, after_request)
	assert_eq(FileAccess.get_file_as_string(path), _golden_document(expected_records),
		"the rebuilt cache must compose the full writer's exact bytes over the external document")
	var on_disk: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	assert_true(on_disk.get("ok", false), str(on_disk))
	if not on_disk.get("ok", false):
		return
	var durable_keys: Array = ((on_disk["value"] as Dictionary)["records"] as Dictionary).keys()
	durable_keys.sort()
	assert_eq(durable_keys, [external_key, after_key],
		"the durable record set is the externally written one plus the new record")
	var cached_keys: Array = _canonical_cache_of(ledger).keys()
	cached_keys.sort()
	assert_eq(cached_keys, [external_key, after_key],
		"the per-record cache must describe the document that is really on disk")


func test_a_refused_write_leaves_the_cached_document_and_its_canonical_cache_intact() -> void:
	if not _require_ledger():
		return
	if not _has_ledger_property("_cached_text"):
		return
	var failing := FailingStorage.new(_storage)
	var ledger := _loaded(failing)
	var path := _root.path_join(FIXED_PATH)
	var kept := _action_request("kept-1")
	var kept_key := "action_source:kept-1"
	assert_true(ledger.record_before_emit(kept).get("ok", false), "the first record must commit")
	var expected_records := {kept_key: _old_path_record(kept_key, kept)}
	var before_bytes := FileAccess.get_file_as_string(path)
	var before_document: Dictionary = (ledger.load()["value"]["document"] as Dictionary).duplicate(true)
	var before_cache: Dictionary = _canonical_cache_of(ledger).duplicate()

	failing.fail_write = true
	var refused: Dictionary = ledger.record_before_emit(_action_request("refused-1"))
	assert_false(refused.get("ok", true), "the storage refusal must surface")
	assert_eq(refused["code"], &"write_not_committed")
	assert_eq(FileAccess.get_file_as_string(path), before_bytes, "a refused write never reaches storage")
	assert_eq(ledger._cached_document, before_document, "a refused write leaves the cached document")
	assert_eq(_canonical_cache_of(ledger), before_cache,
		"a refused write leaves the per-record cache describing the durable document")

	failing.fail_write = false
	var next_request := _board_fate_request("kept-2")
	var next_key := "board_fate:kept-2"
	assert_true(ledger.record_before_emit(next_request).get("ok", false),
		"the ledger must still commit once storage accepts writes again")
	expected_records[next_key] = _old_path_record(next_key, next_request)
	assert_eq(FileAccess.get_file_as_string(path), _golden_document(expected_records),
		"the write after a refusal emits exactly what a fresh instance would")


func test_the_whole_document_deep_copies_this_change_removed_are_gone_from_the_source() -> void:
	if not _require_ledger():
		return
	var source := FileAccess.get_file_as_string(LEDGER_PATH)
	assert_false(source.is_empty(), "the ledger source must be readable: " + LEDGER_PATH)
	# Allocation-only, so each removed whole-document deep copy is pinned by its exact former source
	# line, the way this repo pins every allocation-only change.
	assert_false(source.contains('_cached_document = (parsed["value"] as Dictionary).duplicate(true)'),
		"_refresh_from_disk must not re-copy the document _parse_known_document already owns")
	assert_false(source.contains("var candidate_document := _cached_document.duplicate(true)"),
		"the candidate must copy only the envelope and the records map, not the whole document")
	assert_false(source.contains('"document": document.duplicate(true), "schema_validated": schema_validated,'),
		"an already-owned document must be memoized as it is")
	assert_false(source.contains('"value": document.duplicate(true)}'),
		"_parse_known_document must hand the memoized document out by reference")
	# The two copies that MUST remain: storage is handed a document of its own, and so is load()'s
	# caller. Neither may ever share a reference with the cached document.
	assert_true(source.contains('"value": (known["document"] as Dictionary).duplicate(true)}'),
		"_parse_known_storage_text must still hand storage a document of its own")
	assert_true(source.contains('return _accepted({"document": _cached_document.duplicate(true)})'),
		"load() must still return a caller-owned deep copy")


# ---- dwm-634.3 session 6: a storage-only validity witness on the value-discarding call sites ----
#
# `JsonFileStorage` classifies the final artifact, its `.next` and its `.bak` before every write, and
# each classification calls the OWNER's validator, deep-copies the validator result, and deep-copies
# `validation["value"]` again; `reconcile()` and `write_atomic()` then copy the winner's value a third
# time. For this ledger's `_parse_known_storage_text()` that `value` is the whole ~800 KB document --
# and the ledger never reads it: `_refresh_from_disk()` re-reads with `read_text` and parses through
# `_parse_known_document()`, `_commit_new_entry()` confirms from its own memoized document, and
# `_seed_empty_document()` checks only `ok`. Session 6 follows the issuer root's own precedent
# (`DesktopIssuerRootStore._parse_known_write_document()`): a `_parse_known_storage_witness()` that
# answers an already-validated text with an EMPTY value and delegates every unknown or changed text
# to `_parse_known_storage_text()` unchanged. Storage law is untouched -- no change to
# `JsonFileStorage.gd`, the same bytes, the same pre-write reread, the same exact read-back, the same
# refusals in the same order -- so the rows below pin the witness's two answers, the three call sites
# that may use it, and the document laws that must not move.


## RED-safe probe: on a tree without the witness the method does not exist, so a row that needs it
## fails once with a readable message instead of erroring out on a nonexistent call.
func _has_witness(ledger: Object) -> bool:
	if ledger.has_method("_parse_known_storage_witness"):
		return true
	assert_true(false, "DesktopPublicationLedger must own _parse_known_storage_witness()")
	return false


## The exact source text of one function body: from its `func name(` declaration to the next
## top-level declaration. Slicing is how this suite pins a call site whose effect is allocation-only.
func _ledger_function_body(source: String, function_name: String) -> String:
	var start := source.find("\nfunc " + function_name + "(")
	assert_true(start >= 0, "the ledger source must declare " + function_name + "()")
	if start < 0:
		return ""
	var rest := source.substr(start + 1)
	var next := rest.find("\nfunc ")
	var next_static := rest.find("\nstatic func ")
	if next_static >= 0 and (next < 0 or next_static < next):
		next = next_static
	return rest if next < 0 else rest.substr(0, next)


func test_storage_witness_answers_a_known_text_with_an_empty_value() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	if not _has_witness(ledger):
		return
	assert_true(ledger.record_before_emit(_board_fate_request("witness-known")).get("ok", false),
		"the ledger must own a durable record before its exact text is a known one")
	var current_text := FileAccess.get_file_as_string(_root.path_join(FIXED_PATH))
	assert_false(current_text.is_empty(), "the durable document must be readable")

	var witnessed: Dictionary = ledger._parse_known_storage_witness(current_text)
	assert_true(witnessed.get("ok", false), str(witnessed))
	assert_eq(witnessed.get("code"), &"ok")
	var value: Variant = witnessed.get("value")
	# Storage refuses any artifact whose validator value is not a Dictionary, so the witness must
	# still answer with one -- an EMPTY one, because this owner already retains the document.
	assert_eq(typeof(value), TYPE_DICTIONARY, "storage requires a Dictionary value to accept the artifact")
	if typeof(value) != TYPE_DICTIONARY:
		return
	assert_true((value as Dictionary).is_empty(),
		"a known text needs only a witness; the whole document must not be copied for a caller that discards it")

	# The full reader is untouched and still hands the WHOLE validated document to anyone who asks.
	var parsed: Dictionary = ledger._parse_known_storage_text(current_text)
	assert_true(parsed.get("ok", false), str(parsed))
	var full: Dictionary = parsed["value"]
	assert_false(full.is_empty(), "_parse_known_storage_text must still return the full validated document")
	assert_true((full["records"] as Dictionary).has("board_fate:witness-known"),
		"the full reader's document must carry the durable record")


func test_storage_witness_delegates_unknown_and_corrupt_text_to_the_full_reader() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	if not _has_witness(ledger):
		return
	# A VALID document this instance has never seen: a second root's own durable bytes.
	var other_root_path := _isolated_root("desktop-ledger-witness")
	if other_root_path.is_empty():
		return
	var other_ledger := _loaded(JsonFileStorage.new(other_root_path))
	var unknown_key := "action_source:witness-unknown"
	assert_true(other_ledger.record_before_emit(_action_request("witness-unknown")).get("ok", false),
		"the second root must own a durable record of its own")
	var unknown_text := FileAccess.get_file_as_string(other_root_path.path_join(FIXED_PATH))
	assert_false(unknown_text.is_empty(), "the second root's document must be readable")

	var strict: Dictionary = STRICT_JSON.parse_object(unknown_text)
	assert_true(strict.get("ok", false), str(strict))
	var witnessed: Dictionary = ledger._parse_known_storage_witness(unknown_text)
	assert_true(witnessed.get("ok", false), str(witnessed))
	var value: Dictionary = witnessed["value"]
	assert_false(value.is_empty(),
		"an unknown text must still come back as the full parsed document, exactly as storage expects")
	assert_eq(_canonical(value), _canonical(strict["value"]),
		"the cold path must return exactly what the strict parser returns")
	assert_true((value["records"] as Dictionary).has(unknown_key),
		"the delegated document must carry the second root's record")

	# Corrupt text refuses with exactly the refusal the untouched reader gives it.
	var corrupt := "{ not actually json ]"
	var delegated: Dictionary = ledger._parse_known_storage_witness(corrupt)
	var direct: Dictionary = ledger._parse_known_storage_text(corrupt)
	assert_false(delegated.get("ok", true), "corrupt text must refuse through the witness")
	assert_false(direct.get("ok", true), "corrupt text must refuse through the full reader")
	assert_eq(str(delegated.get("code", "")), str(direct.get("code", "")),
		"the witness must not invent a refusal code of its own")
	assert_eq(str(delegated.get("message", "")), str(direct.get("message", "")),
		"the witness must not reword the full reader's refusal")


func test_only_the_value_discarding_call_sites_pass_the_storage_witness() -> void:
	if not _require_ledger():
		return
	var source := FileAccess.get_file_as_string(LEDGER_PATH)
	assert_false(source.is_empty(), "the ledger source must be readable: " + LEDGER_PATH)
	var witness_callable := 'Callable(self, "_parse_known_storage_witness")'
	var reader_callable := 'Callable(self, "_parse_known_storage_text")'
	# The three sites that hand storage a callable and never read the value it returns.
	for function_name: String in ["_refresh_from_disk", "_seed_empty_document", "_commit_new_entry"]:
		var body := _ledger_function_body(source, function_name)
		assert_true(body.contains(witness_callable),
			function_name + " discards the value storage returns and must pass the witness")
		assert_false(body.contains(reader_callable),
			function_name + " must not make storage deep-copy a document it never reads")
	# The full reader survives as the witness's cold path and keeps its own laws.
	assert_true(source.contains("func _parse_known_storage_text(text: String) -> Dictionary:"),
		"the full storage reader must survive unchanged")
	var witness_body := _ledger_function_body(source, "_parse_known_storage_witness")
	assert_true(witness_body.contains("return _parse_known_storage_text(text)"),
		"an unknown or changed text must still take the full reader unchanged")
	assert_true(witness_body.contains("_touch_validated_text(text)"),
		"the witness must touch the memo exactly as the full reader does")
	# Storage law is not this change's to move: it still decides an artifact's validity from the
	# validator's `ok` plus a Dictionary `value`, which is exactly what the witness answers with.
	var storage_path := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
	var storage_source := FileAccess.get_file_as_string(storage_path)
	assert_false(storage_source.is_empty(), "the storage source must be readable: " + storage_path)
	var validity_law := 'typeof(validation.get("value")) != TYPE_DICTIONARY'
	assert_true(storage_source.contains(validity_law),
		"storage must still require a Dictionary value from the validator it was handed")


## The witness answers reconcile as well as write_atomic, so the row that matters most is the one
## where the bytes underneath the ledger CHANGED: the witness must miss its memo there, delegate, and
## leave the refresh-then-rebuild path exactly as it was. (`canonical_rebuilt` lives only in the
## DWM_CONSEQUENCE_PROFILE record, which this ledger prints to stdout and no GUT row can read, so the
## rebuild is pinned by its observable result -- the per-record cache describing the NEW document.)
func test_external_bytes_after_two_writes_still_compose_the_full_writers_bytes() -> void:
	if not _require_ledger():
		return
	if not _has_ledger_property("_cached_text"):
		return
	var ledger := _loaded()
	var path := _root.path_join(FIXED_PATH)
	var expected_records := {}
	for id_value: String in ["witness-first", "witness-second"]:
		var request := _board_fate_request(id_value)
		var key := "board_fate:" + id_value
		assert_true(ledger.record_before_emit(request).get("ok", false), key + " must commit")
		expected_records[key] = _old_path_record(key, request)
	assert_eq(FileAccess.get_file_as_string(path), _golden_document(expected_records),
		"two writes under the witness must land on the full canonical writer's exact bytes")

	# Different, still VALID bytes written straight past the ledger, carrying a DIFFERENT record set.
	var external_request := _action_request("witness-external")
	var external_key := "action_source:witness-external"
	var external_records := {external_key: _old_path_record(external_key, external_request)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "the durable document must be overwritable for this test")
	if file == null:
		return
	file.store_string(_golden_document(external_records))
	file.close()

	var after_request := _board_fate_request("witness-after-external")
	var after_key := "board_fate:witness-after-external"
	assert_true(ledger.record_before_emit(after_request).get("ok", false),
		"the ledger must adopt the external document and append to it")
	var after_records := external_records.duplicate()
	after_records[after_key] = _old_path_record(after_key, after_request)
	assert_eq(FileAccess.get_file_as_string(path), _golden_document(after_records),
		"the delegated cold path must leave the append on the full writer's exact bytes")
	var cached_keys: Array = _canonical_cache_of(ledger).keys()
	cached_keys.sort()
	assert_eq(cached_keys, [external_key, after_key],
		"the rebuilt per-record cache must describe the document that is really on disk")

	# A cold restart reads the same durable document back through the untouched readers.
	var restarted := _loaded()
	var reloaded: Dictionary = restarted.load()
	assert_true(reloaded.get("ok", false), str(reloaded))
	var durable_keys: Array = ((reloaded["value"]["document"] as Dictionary)["records"] as Dictionary).keys()
	durable_keys.sort()
	assert_eq(durable_keys, [external_key, after_key],
		"a fresh instance must read exactly the two durable records")
