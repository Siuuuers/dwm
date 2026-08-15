extends "res://addons/gut/test.gd"
# Canonical committed-Schedule state schema (Plan 01 Task 4, dwm-p2r.13, Step 4.1).
#
# ScheduleStateSchema owns the exact top-level `committed_schedule` aggregate, its committed entry
# records, and its embedded commit receipt. It owns NO registry law: route, effects, cost, allowed
# days, kind and participants stay with ScheduleActionRegistry/ScheduleRules, so a caller-supplied
# route/effect/cost member is rejected here purely as an unknown key.
#
# DIVERGENCE, deliberate and recorded: a receipt-backed EMPTY Done aggregate (entries == [] with a
# non-null `empty_schedule_done` commit receipt) is legal under the frozen contract at plan line
# 324-353 and is validated here. `ScheduleRules._committed_structure` still rejects that shape; Task
# 5 reconciles the two when RunSnapshotSchema delegates committed validation to this module. Task 4
# therefore never routes a receipt-backed empty aggregate through ScheduleRules.
#
# The module does not exist during RED, so it is loaded through DynamicScriptProbe and every test
# reports its absence as one named assertion instead of a parse crash.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const SCHEMA_PATH := "res://scripts/domain/schedule/ScheduleStateSchema.gd"

const ACCEPTED_INTERFACE: Array[String] = [
	"empty_aggregate", "validate_aggregate", "validate_commit_receipt", "canonical_json",
	"canonical_sha256",
]

const PARENT_RECEIPT_ID := "issuer_receipt.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const TRANSACTION_ID := "transaction_id.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const NAMESPACE := "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
const CAUSAL_DAY := "causal_day_instance.dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
const VIEW_FINGERPRINT := "view.eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

# Untyped on purpose: a statically typed preload of a script that does not exist yet turns RED into
# a load failure instead of the failing assertion Step 4.1 requires.
var _schema = null
var _fingerprint := ""


func before_each() -> void:
	var loaded: Dictionary = PROBE.instantiate(SCHEMA_PATH)
	_schema = loaded["value"] if loaded.get("ok", false) else null
	var registry: Dictionary = REGISTRY.load_current()
	_fingerprint = str((registry.get("value", {}) as Dictionary).get("registry_fingerprint", ""))


func _missing_interface() -> bool:
	if _schema == null:
		assert_true(false, "ScheduleStateSchema is absent: " + SCHEMA_PATH)
		return true
	var absent: Array[String] = []
	for method_name: String in ACCEPTED_INTERFACE:
		if not _schema.has_method(method_name):
			absent.append(method_name)
	if absent.is_empty():
		return false
	assert_true(false, "accepted ScheduleStateSchema interface absent: " + str(absent))
	return true


# ---- builders ----

func _issuer_receipt() -> Dictionary:
	return {
		"receipt_id": PARENT_RECEIPT_ID,
		"purpose": "transaction_id",
		"namespace": NAMESPACE,
		"counter": 7,
		"token": TRANSACTION_ID,
		"numeric_value": null,
	}


func _provenance(child_kind: String, ordinal: int, child_id: String,
		sources: Array) -> Dictionary:
	# Every Plan-01 row hands the issuer already-sorted, unique source tokens.
	sources.sort()
	return {
		"schema_version": 1,
		"parent_receipt_id": PARENT_RECEIPT_ID,
		"child_kind": child_kind,
		"ordinal": ordinal,
		"source_ids": sources.duplicate(),
		"child_id": child_id,
	}


func _entry(ordinal: int, slot_index: int, action_id: String, action_kind: String,
		participants: Array, source_receipt_id: Variant, day := 1) -> Dictionary:
	var child_id := "schedule_entry.%s%s" % [str(ordinal).repeat(2), "f".repeat(62)]
	return {
		"schedule_entry_id": child_id,
		"schedule_entry_provenance": _provenance("schedule_entry", ordinal, child_id,
			['role="schedule.entry"', 'slot_index=%d' % slot_index]),
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": action_kind,
		"participants": participants.duplicate(),
		"source_receipt_id": source_receipt_id,
		"commit_transaction_id": TRANSACTION_ID,
		"state": "committed",
	}


func _commit_receipt(entries: Array, day := 1) -> Dictionary:
	var entry_ids: Array = []
	var source_ids: Array = []
	for entry: Dictionary in entries:
		entry_ids.append(str(entry["schedule_entry_id"]))
		source_ids.append(entry["source_receipt_id"])
	var child_kind := "empty_schedule_done" if entries.is_empty() else "schedule_commit"
	var child_id := "%s.%s" % [child_kind, "9".repeat(64)]
	return {
		"receipt_id": child_id,
		"receipt_provenance": _provenance(child_kind, 0, child_id,
			['role="schedule.commit"', 'motivation_charged=%d' % entries.size()]),
		"transaction_id": TRANSACTION_ID,
		"transaction_issuer_receipt": _issuer_receipt(),
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"registry_fingerprint": _fingerprint,
		"view_fingerprint": VIEW_FINGERPRINT,
		"schedule_entry_ids": entry_ids,
		"source_receipt_ids": source_ids,
		"motivation_charged": entries.size(),
	}


func _aggregate(entries: Array, day := 1, receipt_backed := true) -> Dictionary:
	return {
		"schema_version": 1,
		"day": day,
		"registry_fingerprint": _fingerprint,
		"entries": entries.duplicate(true),
		"commit_receipt": _commit_receipt(entries, day) if receipt_backed else null,
	}


func _two_entries() -> Array:
	return [
		_entry(0, 1, "training", "ordinary", [], null),
		_entry(1, 4, "solo:priscilla:day1", "solo", ["priscilla"], "contact_source.source-1"),
	]


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _reject(aggregate: Dictionary, reason: String) -> void:
	var before: Dictionary = aggregate.duplicate(true)
	var result: Dictionary = _schema.validate_aggregate(aggregate)
	assert_false(result.get("ok", true), "RED aggregate rejection: " + reason)
	assert_eq(aggregate, before, "rejection is pure: " + reason)


# ---- tests ----

func test_empty_aggregate_builds_the_fresh_and_migrated_forms() -> void:
	if _missing_interface():
		return
	var fresh: Dictionary = _schema.empty_aggregate(3, _fingerprint)
	assert_true(fresh.get("ok", false), str(fresh))
	if not fresh.get("ok", false):
		return
	assert_eq(fresh["value"]["committed_schedule"], {
		"schema_version": 1, "day": 3, "registry_fingerprint": _fingerprint,
		"entries": [], "commit_receipt": null,
	}, "a fresh logical day holds the current-fingerprint empty aggregate")
	assert_eq(fresh["receipt"], {}, "building state issues no receipt")
	var migrated: Dictionary = _schema.empty_aggregate(2, null)
	assert_true(migrated.get("ok", false), str(migrated))
	assert_eq(migrated["value"]["committed_schedule"]["registry_fingerprint"], null,
		"a migrated empty aggregate carries a null fingerprint")
	assert_true(_schema.validate_aggregate(fresh["value"]["committed_schedule"]).get("ok", false))
	assert_true(_schema.validate_aggregate(migrated["value"]["committed_schedule"]).get("ok", false))
	for illegal_day: int in [0, 8, -1]:
		assert_false(_schema.empty_aggregate(illegal_day, _fingerprint).get("ok", true),
			"day %d is outside 1..7" % illegal_day)
	assert_false(_schema.empty_aggregate(1, "NOTAHASH").get("ok", true),
		"a fingerprint is lowercase 64-hex or null")
	assert_false(_schema.empty_aggregate(1, _fingerprint.to_upper()).get("ok", true),
		"an uppercase digest is not the canonical fingerprint")


func test_receipt_backed_empty_done_is_valid_and_charges_zero_motivation() -> void:
	if _missing_interface():
		return
	var aggregate := _aggregate([])
	var validated: Dictionary = _schema.validate_aggregate(aggregate)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false):
		return
	assert_eq(validated["value"]["committed_schedule"], aggregate, "valid bytes survive unchanged")
	assert_eq(int(aggregate["commit_receipt"]["motivation_charged"]), 0,
		"an empty Done charges zero motivation")

	var charged := _aggregate([])
	charged["commit_receipt"]["motivation_charged"] = 1
	_reject(charged, "empty Done cannot charge motivation")

	var wrong_kind := _aggregate([])
	wrong_kind["commit_receipt"]["receipt_provenance"]["child_kind"] = "schedule_commit"
	_reject(wrong_kind, "an empty aggregate uses the empty_schedule_done row")

	var nonempty_kind := _aggregate(_two_entries())
	nonempty_kind["commit_receipt"]["receipt_provenance"]["child_kind"] = "empty_schedule_done"
	_reject(nonempty_kind, "a nonempty aggregate uses the schedule_commit row")

	var uncommitted := _aggregate([], 1, false)
	assert_true(_schema.validate_aggregate(uncommitted).get("ok", false),
		"an uncommitted empty aggregate is still legal")


func test_nonempty_committed_state_requires_exact_entry_and_receipt_equality() -> void:
	if _missing_interface():
		return
	var aggregate := _aggregate(_two_entries())
	var validated: Dictionary = _schema.validate_aggregate(aggregate)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false):
		return
	assert_eq(int(aggregate["commit_receipt"]["motivation_charged"]), 2,
		"exactly one motivation per committed entry")

	var swapped := _aggregate(_two_entries())
	var ids: Array = swapped["commit_receipt"]["schedule_entry_ids"]
	var first: Variant = ids[0]
	ids[0] = ids[1]
	ids[1] = first
	_reject(swapped, "the receipt ID array follows committed slot order")

	var wrong_sources := _aggregate(_two_entries())
	wrong_sources["commit_receipt"]["source_receipt_ids"] = [null, null]
	_reject(wrong_sources, "the source array aligns element-wise with the entries")

	var short_ids := _aggregate(_two_entries())
	(short_ids["commit_receipt"]["schedule_entry_ids"] as Array).remove_at(1)
	_reject(short_ids, "every committed entry appears in the receipt")

	var wrong_charge := _aggregate(_two_entries())
	wrong_charge["commit_receipt"]["motivation_charged"] = 1
	_reject(wrong_charge, "motivation_charged equals the entry count")

	var foreign_transaction := _aggregate(_two_entries())
	foreign_transaction["entries"][0]["commit_transaction_id"] = "transaction_id.other"
	_reject(foreign_transaction, "every entry names its own commit transaction")

	var wrong_ordinal := _aggregate(_two_entries())
	wrong_ordinal["entries"][1]["schedule_entry_provenance"]["ordinal"] = 5
	_reject(wrong_ordinal, "the entry ordinal is its zero-based committed index")

	var wrong_child := _aggregate(_two_entries())
	wrong_child["entries"][0]["schedule_entry_provenance"]["child_id"] = "schedule_entry.other"
	_reject(wrong_child, "provenance child_id equals the entry id")

	var wrong_child_kind := _aggregate(_two_entries())
	wrong_child_kind["entries"][0]["schedule_entry_provenance"]["child_kind"] = "contact_source"
	_reject(wrong_child_kind, "a committed entry is a schedule_entry child")

	var unsorted := _aggregate([
		_entry(0, 4, "solo:priscilla:day1", "solo", ["priscilla"], "contact_source.source-1"),
		_entry(1, 1, "training", "ordinary", [], null),
	])
	_reject(unsorted, "committed entries ascend by slot_index")

	var duplicate_slot := _aggregate([
		_entry(0, 1, "training", "ordinary", [], null),
		_entry(1, 1, "working", "ordinary", [], null),
	])
	_reject(duplicate_slot, "a slot holds one committed entry")

	var duplicate_id := _aggregate(_two_entries())
	duplicate_id["entries"][1]["schedule_entry_id"] = str(duplicate_id["entries"][0]["schedule_entry_id"])
	duplicate_id["commit_receipt"]["schedule_entry_ids"][1] = duplicate_id["entries"][0]["schedule_entry_id"]
	duplicate_id["entries"][1]["schedule_entry_provenance"]["child_id"] = duplicate_id["entries"][0]["schedule_entry_id"]
	_reject(duplicate_id, "committed entry ids are unique")

	var wrong_state := _aggregate(_two_entries())
	wrong_state["entries"][0]["state"] = "draft"
	_reject(wrong_state, "every entry is in the committed state")

	var wrong_day := _aggregate(_two_entries())
	wrong_day["entries"][0]["day"] = 2
	_reject(wrong_day, "entry day equals the aggregate day")

	var receipt_day := _aggregate(_two_entries())
	receipt_day["commit_receipt"]["day"] = 2
	_reject(receipt_day, "receipt day equals the aggregate day")

	var receipt_fingerprint := _aggregate(_two_entries())
	receipt_fingerprint["commit_receipt"]["registry_fingerprint"] = "0".repeat(64)
	_reject(receipt_fingerprint, "receipt fingerprint equals the aggregate fingerprint")

	var token_mismatch := _aggregate(_two_entries())
	token_mismatch["commit_receipt"]["transaction_issuer_receipt"]["token"] = "transaction_id.other"
	_reject(token_mismatch, "the full issuer receipt token equals transaction_id")

	var wrong_purpose := _aggregate(_two_entries())
	wrong_purpose["commit_receipt"]["transaction_issuer_receipt"]["purpose"] = "receipt_id"
	_reject(wrong_purpose, "the commit root has purpose transaction_id")

	var missing_receipt := _aggregate(_two_entries(), 1, false)
	_reject(missing_receipt, "a nonempty aggregate embeds its commit receipt")


func test_null_fingerprint_is_illegal_outside_the_migrated_empty_aggregate() -> void:
	if _missing_interface():
		return
	var committed := _aggregate(_two_entries())
	committed["registry_fingerprint"] = null
	_reject(committed, "a nonempty aggregate always carries a current fingerprint")

	var receipt_backed := _aggregate([])
	receipt_backed["registry_fingerprint"] = null
	_reject(receipt_backed, "a receipt-backed empty Done carries a current fingerprint")

	var migrated := _aggregate([], 1, false)
	migrated["registry_fingerprint"] = null
	assert_true(_schema.validate_aggregate(migrated).get("ok", false),
		"only an empty, uncommitted aggregate may omit the fingerprint")

	var blank := _aggregate([], 1, false)
	blank["registry_fingerprint"] = ""
	_reject(blank, "a blank fingerprint is not null")


func test_caller_authored_route_effect_and_cost_members_are_rejected() -> void:
	if _missing_interface():
		return
	for field: String in ["route_id", "effect_ids", "motivation_cost"]:
		var entry_widened := _aggregate(_two_entries())
		entry_widened["entries"][0][field] = null
		_reject(entry_widened, "a committed entry carries no caller " + field)
		var aggregate_widened := _aggregate(_two_entries())
		aggregate_widened[field] = null
		_reject(aggregate_widened, "the aggregate carries no caller " + field)
		var receipt_widened := _aggregate(_two_entries())
		receipt_widened["commit_receipt"][field] = null
		_reject(receipt_widened, "the commit receipt carries no caller " + field)

	for key: String in ["schema_version", "day", "registry_fingerprint", "entries", "commit_receipt"]:
		var missing := _aggregate(_two_entries())
		missing.erase(key)
		_reject(missing, "the aggregate requires " + key)

	for key: String in ["schedule_entry_id", "schedule_entry_provenance", "day", "slot_index",
			"action_id", "action_kind", "participants", "source_receipt_id",
			"commit_transaction_id", "state"]:
		var missing_entry := _aggregate(_two_entries())
		(missing_entry["entries"][0] as Dictionary).erase(key)
		_reject(missing_entry, "a committed entry requires " + key)

	for key: String in ["receipt_id", "receipt_provenance", "transaction_id",
			"transaction_issuer_receipt", "day", "causal_day_instance", "registry_fingerprint",
			"view_fingerprint", "schedule_entry_ids", "source_receipt_ids", "motivation_charged"]:
		var missing_receipt := _aggregate(_two_entries())
		(missing_receipt["commit_receipt"] as Dictionary).erase(key)
		_reject(missing_receipt, "the commit receipt requires " + key)

	var float_version := _aggregate(_two_entries())
	float_version["schema_version"] = 1.0
	_reject(float_version, "an integral float is not schema_version 1")

	var float_day := _aggregate(_two_entries())
	float_day["day"] = 1.0
	_reject(float_day, "an integral float is not a day")

	var float_slot := _aggregate(_two_entries())
	float_slot["entries"][0]["slot_index"] = 0.0
	_reject(float_slot, "an integral float is not a slot index")

	var float_charge := _aggregate(_two_entries())
	float_charge["commit_receipt"]["motivation_charged"] = 2.0
	_reject(float_charge, "an integral float is not a motivation charge")

	var name_kind := _aggregate(_two_entries())
	name_kind["entries"][0]["action_kind"] = &"ordinary"
	_reject(name_kind, "a StringName is not a String action_kind")

	var unknown_kind := _aggregate(_two_entries())
	unknown_kind["entries"][0]["action_kind"] = "chore"
	_reject(unknown_kind, "action_kind is a closed union")

	var blank_action := _aggregate(_two_entries())
	blank_action["entries"][0]["action_id"] = ""
	_reject(blank_action, "action_id is nonblank")

	var blank_source := _aggregate(_two_entries())
	blank_source["entries"][1]["source_receipt_id"] = ""
	blank_source["commit_receipt"]["source_receipt_ids"][1] = ""
	_reject(blank_source, "a source receipt id is nonblank or null")


func test_validation_detaches_every_nested_value_and_defeats_aliases() -> void:
	if _missing_interface():
		return
	var shared_participants: Array = ["priscilla"]
	var aggregate := _aggregate([
		_entry(0, 0, "solo:priscilla:day1", "solo", shared_participants, "contact_source.source-1"),
	])
	# One live Array instance reachable from two places in the input.
	aggregate["entries"][0]["participants"] = shared_participants
	var validated: Dictionary = _schema.validate_aggregate(aggregate)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false):
		return
	var detached: Dictionary = validated["value"]["committed_schedule"]
	shared_participants.append("forged")
	assert_eq(detached["entries"][0]["participants"], ["priscilla"],
		"mutating the caller's aliased array cannot reach the validated value")
	detached["entries"][0]["slot_index"] = 6
	detached["commit_receipt"]["motivation_charged"] = 99
	var revalidated: Dictionary = _schema.validate_aggregate(
		_aggregate([_entry(0, 0, "solo:priscilla:day1", "solo", ["priscilla"],
			"contact_source.source-1")]))
	assert_true(revalidated.get("ok", false), "mutating a previous result cannot poison the module")
	assert_eq(int(revalidated["value"]["committed_schedule"]["entries"][0]["slot_index"]), 0)


func test_commit_receipt_validates_independently_of_its_aggregate() -> void:
	if _missing_interface():
		return
	var receipt := _commit_receipt(_two_entries())
	var validated: Dictionary = _schema.validate_commit_receipt(receipt)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false):
		return
	assert_eq(validated["value"]["commit_receipt"], receipt)
	var mutated: Dictionary = receipt.duplicate(true)
	mutated["motivation_charged"] = 3
	assert_false(_schema.validate_commit_receipt(mutated).get("ok", true),
		"motivation_charged equals the committed ID count")
	var mutated_ordinal: Dictionary = receipt.duplicate(true)
	mutated_ordinal["receipt_provenance"]["ordinal"] = 1
	assert_false(_schema.validate_commit_receipt(mutated_ordinal).get("ok", true),
		"the aggregate row uses ordinal zero")
	var mutated_child: Dictionary = receipt.duplicate(true)
	mutated_child["receipt_provenance"]["child_id"] = "schedule_commit.other"
	assert_false(_schema.validate_commit_receipt(mutated_child).get("ok", true),
		"provenance child_id equals receipt_id")
	assert_false(_schema.validate_commit_receipt({}).get("ok", true), "an empty receipt is invalid")


func test_canonical_projection_is_lowercase_sha256_over_canonical_bytes() -> void:
	if _missing_interface():
		return
	var value := {"b": [1, 2], "a": "x"}
	var canonical: Dictionary = _schema.canonical_json(value)
	assert_true(canonical.get("ok", false), str(canonical))
	if not canonical.get("ok", false):
		return
	var expected_text: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(expected_text.get("ok", false))
	assert_eq(str(canonical["value"]["text"]), str(expected_text["value"]),
		"J(value) is exactly CanonicalJsonWriter.stringify")
	var hashed: Dictionary = _schema.canonical_sha256(value)
	assert_true(hashed.get("ok", false), str(hashed))
	var digest := str(hashed["value"]["sha256"])
	assert_eq(digest, _sha256(str(expected_text["value"])),
		"H(value) is SHA-256 over the canonical UTF-8 bytes with no trailing newline")
	assert_eq(digest, digest.to_lower(), "the digest is lowercase")
	assert_eq(digest.length(), 64)
	var empty_hash: Dictionary = _schema.canonical_sha256([])
	assert_eq(str(empty_hash["value"]["sha256"]), _sha256("[]"), "H([]) is the empty-array digest")
