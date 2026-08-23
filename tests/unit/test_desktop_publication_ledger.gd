extends "res://addons/gut/test.gd"
# Durable desktop consequence-publication ledger (Plan 02 Task 6, dwm-p2r.32).
#
# Mirrors test_schedule_foundation_publication_ledger.gd's discipline: the subject is the REAL
# ledger over the REAL JsonFileStorage over a GUID-isolated temporary root. A restart is modelled by
# rebuilding the whole stack over the same bytes, never by flipping an in-memory flag.
#
# FIX (dwm-p2r.13 remediation, finding W1): the ledger's closed kind union is exactly
# `causal_sequence|action_source|board_fate` (plan02-frozen-contracts.md line 328), each with its OWN
# publication shape (line 335) -- NOT the causal reservation's own `minesweeper_round|shop_purchase|
# schedule_done` union a prior implementation/test pair reused here uniformly. This file's fixtures
# below build the three REAL per-kind shapes.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const LEDGER_PATH := "res://scripts/infrastructure/save/DesktopPublicationLedger.gd"
const OTHER_LEDGER_PATH := "res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd"
const FIXED_PATH := "desktop-publications.json"

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
	_root = _isolated_root("desktop-ledger")
	_storage = JsonFileStorage.new(_root)


func _isolated_root(label: String) -> String:
	var wrapper := OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root: String = wrapper.path_join("desktop-publication-%s-%d" % [label, _root_counter])
	var production := ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	assert_ne(root.simplify_path().trim_suffix("/").nocasecmp_to(production), 0,
		"an isolated root is never the production user directory")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	return root


func _require_ledger() -> bool:
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


## Regression guard requested during dwm-p2r.13 remediation review: a hand-rolled test double
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
	var other_root := JsonFileStorage.new(_isolated_root("desktop-ledger-other"))
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
