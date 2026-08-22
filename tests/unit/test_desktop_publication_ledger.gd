extends "res://addons/gut/test.gd"
# Durable desktop consequence-publication ledger (Plan 02 Task 6, dwm-p2r.32).
#
# Mirrors test_schedule_foundation_publication_ledger.gd's discipline: the subject is the REAL
# ledger over the REAL JsonFileStorage over a GUID-isolated temporary root. A restart is modelled by
# rebuilding the whole stack over the same bytes, never by flipping an in-memory flag.

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


func _publication(receipt_id: String) -> Dictionary:
	var receipt := {"receipt_id": receipt_id, "causal_sequence": 1}
	return {"causal_sequence_receipt": receipt, "outbox": {"notification": {"status": "pending"}}}


func _request(kind: String, receipt_id: String) -> Dictionary:
	var publication := _publication(receipt_id)
	return {
		"kind": kind, "publication": publication,
		"publication_sha256": _sha256(publication),
		"semantic_receipt": publication["causal_sequence_receipt"],
	}


func test_fixed_path_and_kinds_are_frozen() -> void:
	if not _require_ledger():
		return
	assert_eq(_ledger_script.FIXED_PATH, FIXED_PATH)
	assert_eq(_ledger_script.KINDS, ["minesweeper_round", "shop_purchase", "schedule_done"])


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
	for kind: String in ["minesweeper_round", "shop_purchase", "schedule_done"]:
		var recorded: Dictionary = ledger.record_before_emit(_request(kind, "receipt-" + kind))
		assert_true(recorded.get("ok", false), str(recorded))
		assert_eq(recorded["value"]["record"]["kind"], kind)
		assert_true(recorded["value"]["first_delivery"])
	var bad_kind: Dictionary = _request("desktop_notification", "receipt-bad")
	var rejected: Dictionary = ledger.record_before_emit(bad_kind)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"publication_request_invalid")


func test_document_and_record_union_is_exact_after_one_publication() -> void:
	if not _require_ledger():
		return
	var ledger := _loaded()
	var recorded: Dictionary = ledger.record_before_emit(_request("minesweeper_round", "receipt-1"))
	assert_true(recorded.get("ok", false), str(recorded))
	var record: Dictionary = recorded["value"]["record"]
	var keys: Array = record.keys()
	keys.sort()
	assert_eq(keys, RECORD_KEYS)
	assert_eq(record["key"], "minesweeper_round:receipt-1")
	var loaded: Dictionary = ledger.load()
	var document_keys: Array = (loaded["value"]["document"] as Dictionary).keys()
	document_keys.sort()
	assert_eq(document_keys, ["records", "schema_version"])


func test_first_delivery_then_byte_identical_replay_across_a_cold_restart() -> void:
	if not _require_ledger():
		return
	var request := _request("shop_purchase", "receipt-2")
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
	var first: Dictionary = ledger.record_before_emit(_request("schedule_done", "receipt-3"))
	assert_true(first.get("ok", false), str(first))
	var path := _root.path_join(FIXED_PATH)
	var before := FileAccess.get_file_as_string(path)

	var changed_publication := _publication("receipt-3")
	changed_publication["outbox"] = {"notification": {"status": "published"}}
	var changed_request := {
		"kind": "schedule_done", "publication": changed_publication,
		"publication_sha256": _sha256(changed_publication),
		"semantic_receipt": changed_publication["causal_sequence_receipt"],
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

	var wrong_hash := _request("minesweeper_round", "receipt-4")
	wrong_hash["publication_sha256"] = "0".repeat(64)
	var rejected_hash: Dictionary = ledger.record_before_emit(wrong_hash)
	assert_false(rejected_hash.get("ok", true))

	var unbound := _request("minesweeper_round", "receipt-5")
	unbound["semantic_receipt"] = {"receipt_id": "receipt-different"}
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
