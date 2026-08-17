class_name DesktopIssuerRootStore
extends RefCounted

## Durable external issuer root and closed provenance ledger (Plan 02 Task 1, dwm-p2r.16).
##
## Lives outside every selectable run snapshot: no API here lowers, replaces, or restores root
## state. Writes one strict primitive `desktop-issuer-root.json` through injected atomic storage.
##
## FROZEN PUBLIC SURFACE -- `root_store_public_surface_sha256` is derived by parsing these
## declarations in source order with types stripped, giving exactly:
##
##     configure(storage,namespace_source)
##     load_or_create()
##     issue(purpose)
##     verify_receipt(receipt,expected_purpose)
##     prepare_allocation(request)
##     commit_allocation(candidate)
##     prepare_causal_day_advance(request)
##     commit_causal_day_advance(candidate)
##     capture()
##
## Parameter names are frozen strings; unused ones keep their exact names and are silenced with
## @warning_ignore rather than a leading underscore (dwm-p2r.16 DECISION 8.2). Every helper below is
## underscore-prefixed or static, because the boundary extractor counts only top-level,
## non-underscore, non-static declarations (DECISION 13.4).
##
## VALIDATION SPLIT (DECISION 13.2). The Callable handed to storage parses and nothing else, so
## storage owns atomicity while this class owns domain law. The schema and the ledger laws run in
## `load_or_create()` and each carry a precise typed code. No code below is asserted by any test:
## the plan freezes none for this file, so none may be treated as frozen contract (DECISION 9.9).

const ROOT_DOCUMENT_PATH := "desktop-issuer-root.json"
const SCHEMA_PATH := "res://data/schemas/desktop-issuer-root.schema.json"
const SCHEMA_VERSION := 1

const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")

## The closed v1 purpose union, plan line 535. The ROOT accepts all ten: refusing the two allocator
## purposes is the ISSUER's law (plan line 729), and a root that refused them could never allocate a
## generation or a causal day at all.
const PURPOSE_UNION := [
	"run_id",
	"branch_id",
	"desktop_timeline_generation",
	"causal_day_instance",
	"board_id",
	"transaction_id",
	"placement_nonce",
	"debug_nonce",
	"explosion_nonce",
	"receipt_id",
]

## The only purpose whose receipt carries a nonnull `numeric_value` (plan line 535).
const NUMERIC_PURPOSE := "desktop_timeline_generation"

## Exact receipt member set, plan line 535.
const RECEIPT_KEYS := ["counter", "namespace", "numeric_value", "purpose", "receipt_id", "token"]

## Exact continuation request member set, plan line 729.
const ALLOCATION_REQUEST_KEYS := [
	"existing_run_id",
	"kind",
	"remap_source_transaction_ids",
	"source_desktop_timeline_generation",
	"transaction_id",
	"transaction_issuer_receipt",
]

const ALLOCATION_KINDS := ["new_run", "restore"]

## Derived, not frozen: the plan states the day-advance LAW (line 1682) but declares no request
## interface for the root's half. These three members are the minimum that law needs -- the map key
## is `resolution_kind + ":" + source_resolution_receipt_id`, and the source receipt must be
## ledger-proven before a target may be minted.
const DAY_ADVANCE_REQUEST_KEYS := [
	"resolution_kind",
	"source_causal_day_instance_issuer_receipt",
	"source_resolution_receipt_id",
]

const NAMESPACE_HEX_LENGTH := 64

## Mirrors data/schemas/desktop-issuer-root.schema.json so a load reads exactly one file, matching
## the ScheduleActionRegistry and MinesweeperShopRegistry precedent. The mini validator supports only
## const/enum/type/required/properties/additionalProperties/uniqueItems/items/minLength, so it can
## express neither the 64-character lowercase-hex namespace nor the dynamically keyed receipt maps;
## those laws live in _validate_document below (DECISION 13.3).
const _SCHEMA := {
	"$schema": "https://json-schema.org/draft/2020-12/schema",
	"type": "object",
	"additionalProperties": false,
	"required": [
		"schema_version",
		"namespace",
		"next_counter",
		"receipts",
		"allocation_receipts",
		"day_advance_allocation_receipts",
	],
	"properties": {
		"schema_version": {"const": 1},
		"namespace": {"type": "string", "minLength": 64},
		"next_counter": {"type": "integer"},
		"receipts": {"type": "object"},
		"allocation_receipts": {"type": "object"},
		"day_advance_allocation_receipts": {"type": "object"},
	},
}

var _storage: Object = null
var _namespace_source: Object = null
var _document: Dictionary = {}
var _loaded := false


# -------------------------------------------------------------------------------------------------
# Frozen public surface
# -------------------------------------------------------------------------------------------------

func configure(storage: Object, namespace_source: Object) -> Dictionary:
	if storage == null or namespace_source == null:
		return _failed(&"root_configure_invalid", "configure requires a storage and a namespace source")
	if _loaded:
		return _failed(&"root_already_loaded", "configure may not replace a loaded root")
	_storage = storage
	_namespace_source = namespace_source
	return {"ok": true}


func load_or_create() -> Dictionary:
	if _storage == null or _namespace_source == null:
		return _failed(&"root_not_configured", "load_or_create before configure")
	if _loaded:
		return {"ok": true, "value": _document.duplicate(true)}
	var reconciled: Dictionary = _storage.call(&"reconcile", ROOT_DOCUMENT_PATH, Callable(self, "_parse_document"))
	if not reconciled.get("ok", false):
		return _storage_failure(reconciled, &"root_reconcile_failed")
	if reconciled.get("exists", false):
		var existing: Dictionary = reconciled.get("value", {})
		var lawful := _validate_document(existing)
		if not lawful.get("ok", false):
			return lawful
		_document = existing.duplicate(true)
		_loaded = true
		return {"ok": true, "value": _document.duplicate(true)}
	var generated: Dictionary = _namespace_source.call(&"generate_namespace")
	if not generated.get("ok", false):
		return _failed(&"namespace_source_failed", str(generated.get("message", "no namespace available")))
	var namespace_value := str(generated.get("value", ""))
	var hex := _validate_namespace(namespace_value)
	if not hex.get("ok", false):
		return hex
	var written := _write_document({
		"schema_version": SCHEMA_VERSION,
		"namespace": namespace_value,
		"next_counter": 1,
		"receipts": {},
		"allocation_receipts": {},
		"day_advance_allocation_receipts": {},
	})
	if not written.get("ok", false):
		return written
	_loaded = true
	return {"ok": true, "value": _document.duplicate(true)}


## Plan line 535: issuance atomically advances the monotonic root counter BEFORE returning any token,
## so the durable write happens first and a failure returns no token at all.
func issue(purpose: StringName) -> Dictionary:
	var ready := _require_loaded("issue")
	if not ready.get("ok", false):
		return ready
	if not PURPOSE_UNION.has(String(purpose)):
		return _failed(&"unknown_purpose", String(purpose))
	var minted := _minted_document([{"purpose": String(purpose), "numeric_value": null}])
	var written := _write_document(minted["document"])
	if not written.get("ok", false):
		return written
	var receipt: Dictionary = (minted["receipts"] as Array)[0]
	return {
		"ok": true,
		"value": {"token": str(receipt["token"]), "issuer_receipt": receipt.duplicate(true)},
		"receipt": receipt.duplicate(true),
	}


func verify_receipt(receipt: Dictionary, expected_purpose: StringName) -> Dictionary:
	var ready := _require_loaded("verify_receipt")
	if not ready.get("ok", false):
		return ready
	var members := _validate_receipt_members(receipt)
	if not members.get("ok", false):
		return members
	var receipt_id := str(receipt["receipt_id"])
	var receipts: Dictionary = _document["receipts"]
	if not receipts.has(receipt_id):
		return _failed(&"receipt_absent", receipt_id)
	if receipts[receipt_id] != receipt:
		return _failed(&"receipt_not_byte_equal", receipt_id)
	if str(receipt["purpose"]) != String(expected_purpose):
		return _failed(&"receipt_wrong_purpose", str(receipt["purpose"]))
	return {"ok": true, "value": {"receipt": receipt.duplicate(true)}}


## Mutation-free. Plan line 729: an identical replay of the same allocation transaction returns its
## recorded bundle, and a different request at an occupied transaction identity conflicts.
func prepare_allocation(request: Dictionary) -> Dictionary:
	var ready := _require_loaded("prepare_allocation")
	if not ready.get("ok", false):
		return ready
	var validated := _validate_allocation_request(request)
	if not validated.get("ok", false):
		return validated
	var transaction_id := str(request["transaction_id"])
	var occupied: Dictionary = _document["allocation_receipts"]
	if occupied.has(transaction_id):
		var recorded: Dictionary = occupied[transaction_id]
		if recorded.get("request") != request:
			return _failed(&"allocation_transaction_conflict", transaction_id)
		return {"ok": true, "value": recorded.duplicate(true)}
	return {"ok": true, "value": _continuation_candidate(request)}


func commit_allocation(candidate: Dictionary) -> Dictionary:
	var ready := _require_loaded("commit_allocation")
	if not ready.get("ok", false):
		return ready
	var shaped := _validate_candidate(candidate, ALLOCATION_REQUEST_KEYS)
	if not shaped.get("ok", false):
		return shaped
	var request: Dictionary = candidate["request"]
	var validated := _validate_allocation_request(request)
	if not validated.get("ok", false):
		return validated
	var transaction_id := str(request["transaction_id"])
	var occupied: Dictionary = _document["allocation_receipts"]
	if occupied.has(transaction_id):
		if occupied[transaction_id] != candidate:
			return _failed(&"allocation_transaction_conflict", transaction_id)
		return {"ok": true, "value": candidate.duplicate(true)}
	return _commit_candidate(candidate, "allocation_receipts", transaction_id)


## Mutation-free. Plan line 1682: preparing a missing key is pure; committing atomically adds its
## target issuer receipt, map record and one counter increment.
func prepare_causal_day_advance(request: Dictionary) -> Dictionary:
	var ready := _require_loaded("prepare_causal_day_advance")
	if not ready.get("ok", false):
		return ready
	var validated := _validate_day_advance_request(request)
	if not validated.get("ok", false):
		return validated
	var key := _day_advance_key(request)
	var occupied: Dictionary = _document["day_advance_allocation_receipts"]
	if occupied.has(key):
		var recorded: Dictionary = occupied[key]
		if recorded.get("request") != request:
			return _failed(&"causal_day_advance_conflict", key)
		return {"ok": true, "value": recorded.duplicate(true)}
	return {"ok": true, "value": _day_advance_candidate(request, key)}


func commit_causal_day_advance(candidate: Dictionary) -> Dictionary:
	var ready := _require_loaded("commit_causal_day_advance")
	if not ready.get("ok", false):
		return ready
	var shaped := _validate_candidate(candidate, DAY_ADVANCE_REQUEST_KEYS)
	if not shaped.get("ok", false):
		return shaped
	var request: Dictionary = candidate["request"]
	var validated := _validate_day_advance_request(request)
	if not validated.get("ok", false):
		return validated
	var key := _day_advance_key(request)
	var occupied: Dictionary = _document["day_advance_allocation_receipts"]
	if occupied.has(key):
		if occupied[key] != candidate:
			return _failed(&"causal_day_advance_conflict", key)
		return {"ok": true, "value": candidate.duplicate(true)}
	return _commit_candidate(candidate, "day_advance_allocation_receipts", key)


## Detached: mutating the returned document can never reach this store (plan line 797).
func capture() -> Dictionary:
	var ready := _require_loaded("capture")
	if not ready.get("ok", false):
		return ready
	return {"ok": true, "value": _document.duplicate(true)}


# -------------------------------------------------------------------------------------------------
# Storage seam
# -------------------------------------------------------------------------------------------------

## The whole validator, per DECISION 13.2. Storage proves atomicity; this class proves domain law.
func _parse_document(text: String) -> Dictionary:
	return _STRICT_JSON.parse_object(text)


func _write_document(document: Dictionary) -> Dictionary:
	var emitted: Dictionary = _CANONICAL_WRITER.stringify(document)
	if not emitted.get("ok", false):
		return _failed(&"root_serialization_failed", str(emitted.get("message", "canonical write refused")))
	var written: Dictionary = _storage.call(
		&"write_atomic", ROOT_DOCUMENT_PATH, str(emitted["value"]), Callable(self, "_parse_document"), true
	)
	if not written.get("ok", false):
		return _storage_failure(written, &"root_write_failed")
	_document = document.duplicate(true)
	return {"ok": true}


func _storage_failure(result: Dictionary, fallback: StringName) -> Dictionary:
	var code: Variant = result.get("code", fallback)
	return _failed(StringName(str(code)), str(result.get("message", "storage refused the root document")))


# -------------------------------------------------------------------------------------------------
# Minting
# -------------------------------------------------------------------------------------------------

## Builds the next document with one receipt per spec, appended from the current counter. Never
## writes: callers persist the result so a failed durable advance burns no counter.
func _minted_document(specs: Array) -> Dictionary:
	var document := _document.duplicate(true)
	var receipts: Dictionary = document["receipts"]
	var namespace_value := str(document["namespace"])
	var counter := int(document["next_counter"])
	var minted: Array[Dictionary] = []
	for spec in specs:
		var entry: Dictionary = spec
		var receipt := _mint_receipt(namespace_value, counter, str(entry["purpose"]), entry.get("numeric_value"))
		receipts[str(receipt["receipt_id"])] = receipt.duplicate(true)
		minted.append(receipt)
		counter += 1
	document["next_counter"] = counter
	return {"document": document, "receipts": minted}


static func _mint_receipt(namespace_value: String, counter: int, purpose: String,
		numeric_value: Variant) -> Dictionary:
	var token := _token_for(namespace_value, counter, purpose)
	return {
		"receipt_id": _receipt_id_for(namespace_value, counter, purpose, token),
		"purpose": purpose,
		"namespace": namespace_value,
		"counter": counter,
		"token": token,
		"numeric_value": numeric_value if purpose == NUMERIC_PURPOSE else null,
	}


## The frozen token preimage, plan line 535.
static func _token_for(namespace_value: String, counter: int, purpose: String) -> String:
	return "%s.%s" % [purpose, _sha256_hex("%s\n%d\n%s" % [namespace_value, counter, purpose])]


## The frozen structural receipt key, plan line 535. It consumes no second counter.
static func _receipt_id_for(namespace_value: String, counter: int, purpose: String,
		token: String) -> String:
	return "issuer_receipt." + _sha256_hex("desktop_issuer_receipt_v1\n%s\n%d\n%s\n%s" % [
		namespace_value, counter, purpose, token,
	])


static func _sha256_hex(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


# -------------------------------------------------------------------------------------------------
# Continuation and day-advance bundles (plan lines 729 and 1682)
# -------------------------------------------------------------------------------------------------

## The exact proposed bundle. New Run opens generation zero; restore takes the source generation plus
## one and keeps the existing run. One fresh transaction receipt is minted per remap source, and the
## whole candidate records the root identity it was prepared against so commit can detect supersession.
func _continuation_candidate(request: Dictionary) -> Dictionary:
	var kind := str(request["kind"])
	var specs: Array = []
	if kind == "new_run":
		specs.append({"purpose": "run_id", "numeric_value": null})
	specs.append({"purpose": "branch_id", "numeric_value": null})
	var generation := 0
	if kind == "restore":
		generation = int(request["source_desktop_timeline_generation"]) + 1
	specs.append({"purpose": NUMERIC_PURPOSE, "numeric_value": generation})
	specs.append({"purpose": "causal_day_instance", "numeric_value": null})
	var remap_sources: Array = request["remap_source_transaction_ids"]
	for _source in remap_sources:
		specs.append({"purpose": "transaction_id", "numeric_value": null})
	var minted := _minted_document(specs)
	var receipts: Array = minted["receipts"]
	var cursor := 0
	var run_receipt: Variant = null
	if kind == "new_run":
		run_receipt = receipts[cursor]
		cursor += 1
	var branch_receipt: Dictionary = receipts[cursor]
	var generation_receipt: Dictionary = receipts[cursor + 1]
	var causal_day_receipt: Dictionary = receipts[cursor + 2]
	var remap_receipts := {}
	for index in range(remap_sources.size()):
		remap_receipts[str(remap_sources[index])] = (receipts[cursor + 3 + index] as Dictionary).duplicate(true)
	return {
		"schema_version": SCHEMA_VERSION,
		"kind": kind,
		"request": request.duplicate(true),
		"root_namespace": str(_document["namespace"]),
		"root_next_counter": int(_document["next_counter"]),
		"run_id": str(request["existing_run_id"]) if kind == "restore" else str((run_receipt as Dictionary)["token"]),
		"run_id_issuer_receipt": null if kind == "restore" else (run_receipt as Dictionary).duplicate(true),
		"branch_id": str(branch_receipt["token"]),
		"branch_id_issuer_receipt": branch_receipt.duplicate(true),
		"desktop_timeline_generation": generation,
		"desktop_timeline_generation_issuer_receipt": generation_receipt.duplicate(true),
		"causal_day_instance": str(causal_day_receipt["token"]),
		"causal_day_instance_issuer_receipt": causal_day_receipt.duplicate(true),
		"remap_transaction_issuer_receipts": remap_receipts,
	}


func _day_advance_candidate(request: Dictionary, key: String) -> Dictionary:
	var minted := _minted_document([{"purpose": "causal_day_instance", "numeric_value": null}])
	var target: Dictionary = (minted["receipts"] as Array)[0]
	return {
		"schema_version": SCHEMA_VERSION,
		"allocation_key": key,
		"request": request.duplicate(true),
		"root_namespace": str(_document["namespace"]),
		"root_next_counter": int(_document["next_counter"]),
		"resolution_kind": str(request["resolution_kind"]),
		"source_resolution_receipt_id": str(request["source_resolution_receipt_id"]),
		"source_causal_day_instance_issuer_receipt": (request["source_causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true),
		"target_causal_day_instance_issuer_receipt": target.duplicate(true),
	}


## Plan line 729: commit repeats root namespace/counter/request validation, so a candidate prepared
## against a superseded counter fails rather than silently reusing an abandoned counter.
func _commit_candidate(candidate: Dictionary, map_name: String, key: String) -> Dictionary:
	if str(candidate["root_namespace"]) != str(_document["namespace"]):
		return _failed(&"allocation_root_namespace_mismatch", key)
	if int(candidate["root_next_counter"]) != int(_document["next_counter"]):
		return _failed(&"allocation_counter_superseded", key)
	var specs: Array = []
	for receipt in _candidate_receipts(candidate):
		var entry: Dictionary = receipt
		specs.append({"purpose": str(entry["purpose"]), "numeric_value": entry["numeric_value"]})
	var minted := _minted_document(specs)
	var replayed: Array = minted["receipts"]
	var expected: Array = _candidate_receipts(candidate)
	for index in range(expected.size()):
		if replayed[index] != expected[index]:
			return _failed(&"allocation_candidate_not_reproducible", key)
	var document: Dictionary = minted["document"]
	(document[map_name] as Dictionary)[key] = candidate.duplicate(true)
	var written := _write_document(document)
	if not written.get("ok", false):
		return written
	return {"ok": true, "value": candidate.duplicate(true)}


## The newly minted receipts a candidate commits, in the exact order they were minted.
func _candidate_receipts(candidate: Dictionary) -> Array:
	var ordered: Array = []
	if candidate.has("target_causal_day_instance_issuer_receipt"):
		ordered.append(candidate["target_causal_day_instance_issuer_receipt"])
		return ordered
	if candidate.get("run_id_issuer_receipt") != null:
		ordered.append(candidate["run_id_issuer_receipt"])
	ordered.append(candidate["branch_id_issuer_receipt"])
	ordered.append(candidate["desktop_timeline_generation_issuer_receipt"])
	ordered.append(candidate["causal_day_instance_issuer_receipt"])
	var remap: Dictionary = candidate.get("remap_transaction_issuer_receipts", {})
	var sources: Array = (candidate["request"] as Dictionary).get("remap_source_transaction_ids", [])
	for source in sources:
		ordered.append(remap[str(source)])
	return ordered


static func _day_advance_key(request: Dictionary) -> String:
	return "%s:%s" % [str(request["resolution_kind"]), str(request["source_resolution_receipt_id"])]


# -------------------------------------------------------------------------------------------------
# Request and candidate validation
# -------------------------------------------------------------------------------------------------

func _validate_allocation_request(request: Dictionary) -> Dictionary:
	var keys := _exact_keys(request, ALLOCATION_REQUEST_KEYS)
	if not keys.get("ok", false):
		return keys
	var kind := str(request["kind"])
	if not ALLOCATION_KINDS.has(kind):
		return _failed(&"allocation_kind_invalid", kind)
	if typeof(request["transaction_issuer_receipt"]) != TYPE_DICTIONARY:
		return _failed(&"allocation_request_malformed", "transaction_issuer_receipt must be an object")
	var receipt: Dictionary = request["transaction_issuer_receipt"]
	var proven := verify_receipt(receipt, &"transaction_id")
	if not proven.get("ok", false):
		return proven
	if str(request["transaction_id"]) != str(receipt["token"]):
		return _failed(&"allocation_transaction_id_mismatch", str(request["transaction_id"]))
	if typeof(request["remap_source_transaction_ids"]) != TYPE_ARRAY:
		return _failed(&"allocation_request_malformed", "remap_source_transaction_ids must be an array")
	var remap: Array = request["remap_source_transaction_ids"]
	if kind == "new_run":
		if request["existing_run_id"] != null or request["source_desktop_timeline_generation"] != null:
			return _failed(&"allocation_new_run_requires_null_sources", str(request["transaction_id"]))
		if not remap.is_empty():
			return _failed(&"allocation_new_run_requires_empty_remap", str(request["transaction_id"]))
		return {"ok": true}
	if typeof(request["existing_run_id"]) != TYPE_STRING or str(request["existing_run_id"]).strip_edges().is_empty():
		return _failed(&"allocation_restore_requires_existing_run", str(request["transaction_id"]))
	if typeof(request["source_desktop_timeline_generation"]) != TYPE_INT \
			or int(request["source_desktop_timeline_generation"]) < 0:
		return _failed(&"allocation_restore_requires_source_generation", str(request["transaction_id"]))
	return _validate_sorted_unique(remap)


## Plan line 729: callers submit the already sorted unique complete set; the root repairs nothing.
func _validate_sorted_unique(values: Array) -> Dictionary:
	var previous := ""
	for index in range(values.size()):
		if typeof(values[index]) != TYPE_STRING:
			return _failed(&"allocation_remap_malformed", "remap sources must be strings")
		var current := str(values[index])
		if current.strip_edges().is_empty():
			return _failed(&"allocation_remap_blank", "remap sources must be nonblank")
		if index > 0 and current <= previous:
			return _failed(&"allocation_remap_unsorted", current)
		previous = current
	return {"ok": true}


func _validate_day_advance_request(request: Dictionary) -> Dictionary:
	var keys := _exact_keys(request, DAY_ADVANCE_REQUEST_KEYS)
	if not keys.get("ok", false):
		return keys
	if typeof(request["resolution_kind"]) != TYPE_STRING \
			or str(request["resolution_kind"]).strip_edges().is_empty():
		return _failed(&"causal_day_resolution_kind_invalid", "resolution_kind must be a nonblank string")
	if typeof(request["source_resolution_receipt_id"]) != TYPE_STRING \
			or str(request["source_resolution_receipt_id"]).strip_edges().is_empty():
		return _failed(&"causal_day_source_resolution_invalid", "source_resolution_receipt_id must be nonblank")
	if typeof(request["source_causal_day_instance_issuer_receipt"]) != TYPE_DICTIONARY:
		return _failed(&"causal_day_source_receipt_malformed", "source receipt must be an object")
	return verify_receipt(request["source_causal_day_instance_issuer_receipt"], &"causal_day_instance")


func _validate_candidate(candidate: Dictionary, request_keys: Array) -> Dictionary:
	for member in ["request", "root_namespace", "root_next_counter", "schema_version"]:
		if not candidate.has(member):
			return _failed(&"allocation_candidate_malformed", "missing " + str(member))
	if typeof(candidate["request"]) != TYPE_DICTIONARY:
		return _failed(&"allocation_candidate_malformed", "request must be an object")
	if int(candidate["schema_version"]) != SCHEMA_VERSION:
		return _failed(&"allocation_candidate_malformed", "unexpected candidate schema_version")
	return _exact_keys(candidate["request"], request_keys)


func _exact_keys(value: Dictionary, expected: Array) -> Dictionary:
	if value.size() != expected.size():
		return _failed(&"request_member_set_invalid", "expected %d members, saw %d" % [expected.size(), value.size()])
	for key in expected:
		if not value.has(key):
			return _failed(&"request_member_set_invalid", "missing " + str(key))
	return {"ok": true}


# -------------------------------------------------------------------------------------------------
# Document law (clauses 30, 32, 34, 35)
# -------------------------------------------------------------------------------------------------

func _validate_document(document: Dictionary) -> Dictionary:
	var required_keys: Array = _SCHEMA.get("required", [])
	if document.size() != required_keys.size():
		return _failed(&"root_schema_invalid", "root document does not carry exactly the expected keys")
	for key: String in required_keys:
		if not document.has(key):
			return _failed(&"root_schema_invalid", "root document is missing key: %s" % key)
	if typeof(document["schema_version"]) != TYPE_INT:
		return _failed(&"root_schema_invalid", "schema_version must be an integer")
	if typeof(document["namespace"]) != TYPE_STRING:
		return _failed(&"root_schema_invalid", "namespace must be a string")
	if typeof(document["next_counter"]) != TYPE_INT:
		return _failed(&"root_schema_invalid", "next_counter must be an integer")
	if typeof(document["receipts"]) != TYPE_DICTIONARY or typeof(document["allocation_receipts"]) != TYPE_DICTIONARY \
			or typeof(document["day_advance_allocation_receipts"]) != TYPE_DICTIONARY:
		return _failed(&"root_schema_invalid", "allocation maps and receipts must be objects")

	var shape: Dictionary = _SCHEMA_VALIDATOR.validate(document, _SCHEMA)
	if not shape.get("ok", false):
		return _failed(&"root_schema_invalid", str(shape.get("message", "root document rejected by schema")))
	var namespace_value := str(document["namespace"])
	var hex := _validate_namespace(namespace_value)
	if not hex.get("ok", false):
		return hex
	var next_counter := int(document["next_counter"])
	if next_counter < 1:
		return _failed(&"root_counter_invalid", "next_counter must be at least 1")
	var receipts: Dictionary = document["receipts"]
	# Clause 34: an append-only ledger holds exactly one receipt per consumed counter, so a deletion
	# is visible as a size disagreement no matter which receipt was removed.
	if receipts.size() != next_counter - 1:
		return _failed(&"root_ledger_incomplete",
			"receipts %d does not match next_counter %d" % [receipts.size(), next_counter])
	var seen_counters := {}
	for key in receipts:
		if typeof(receipts[key]) != TYPE_DICTIONARY:
			return _failed(&"root_receipt_malformed", str(key))
		var receipt: Dictionary = receipts[key]
		var members := _validate_receipt_members(receipt)
		if not members.get("ok", false):
			return members
		if str(key) != str(receipt["receipt_id"]):
			return _failed(&"root_receipt_key_mismatch", str(key))
		if str(receipt["namespace"]) != namespace_value:
			return _failed(&"root_receipt_foreign_namespace", str(key))
		var counter := int(receipt["counter"])
		if counter < 1 or counter >= next_counter:
			return _failed(&"root_receipt_counter_out_of_range", str(key))
		if seen_counters.has(counter):
			return _failed(&"root_receipt_counter_duplicated", str(counter))
		seen_counters[counter] = true
		# Clause 34: replacement is caught by rederiving both frozen preimages from the receipt's own
		# namespace, counter and purpose.
		var expected_token := _token_for(namespace_value, counter, str(receipt["purpose"]))
		if str(receipt["token"]) != expected_token:
			return _failed(&"root_receipt_token_mismatch", str(key))
		if str(receipt["receipt_id"]) != _receipt_id_for(namespace_value, counter, str(receipt["purpose"]), expected_token):
			return _failed(&"root_receipt_id_mismatch", str(key))
	# Clause 32: the two allocation maps are disjoint, so one key may never occupy both.
	var allocations: Dictionary = document["allocation_receipts"]
	var day_advances: Dictionary = document["day_advance_allocation_receipts"]
	for key in allocations:
		if day_advances.has(key):
			return _failed(&"root_allocation_maps_overlap", str(key))
	# Clause 34: all persisted continuation candidates must be fully reproducible and
	# byte-equal to a fresh continuation candidate from their own root_next_counter.
	# A missing map entry is therefore visible as unreferenced receipts in the expected
	# allocation counter window.
	var allocation_expected_receipt_counters: Dictionary = {}
	for key in allocations:
		if typeof(allocations[key]) != TYPE_DICTIONARY:
			return _failed(&"root_allocation_record_malformed", str(key))
		var allocation_record: Dictionary = allocations[key]
		var allocation_shaped := _validate_candidate(allocation_record, ALLOCATION_REQUEST_KEYS)
		if not allocation_shaped.get("ok", false):
			return allocation_shaped
		if typeof(allocation_record["root_next_counter"]) != TYPE_INT:
			return _failed(&"allocation_candidate_malformed", "root_next_counter must be an integer")
		var root_next_counter := int(allocation_record["root_next_counter"])
		if root_next_counter < 1:
			return _failed(&"allocation_candidate_malformed", "root_next_counter must be positive")
		if str(allocation_record["root_namespace"]) != namespace_value:
			return _failed(&"allocation_root_namespace_mismatch", str(key))
		var request: Dictionary = allocation_record["request"]
		var allocation_request := _validate_allocation_request(request)
		if not allocation_request.get("ok", false):
			return allocation_request
		var reproducible: Dictionary = _continuation_candidate_from(
			request, namespace_value, root_next_counter
		)
		if reproducible != allocation_record:
			return _failed(&"allocation_candidate_not_reproducible", str(key))
		var remap_count := int((request.get("remap_source_transaction_ids", []) as Array).size())
		var allocation_receipt_count := 3 + remap_count
		if str(request["kind"]) == "new_run":
			allocation_receipt_count += 1
		for offset in range(allocation_receipt_count):
			allocation_expected_receipt_counters[root_next_counter + offset] = true
	for key in day_advances:
		if typeof(day_advances[key]) != TYPE_DICTIONARY:
			return _failed(&"root_day_advance_record_malformed", str(key))
		var day_record: Dictionary = day_advances[key]
		var day_shaped := _validate_candidate(day_record, DAY_ADVANCE_REQUEST_KEYS)
		if not day_shaped.get("ok", false):
			return day_shaped
		if typeof(day_record["root_next_counter"]) != TYPE_INT:
			return _failed(&"allocation_candidate_malformed", "root_next_counter must be an integer")
		var day_root_next_counter := int(day_record["root_next_counter"])
		if day_root_next_counter < 1:
			return _failed(&"allocation_candidate_malformed", "root_next_counter must be positive")
		if str(day_record["root_namespace"]) != namespace_value:
			return _failed(&"allocation_root_namespace_mismatch", str(key))
		var day_request: Dictionary = day_record["request"]
		var day_request_validation := _validate_day_advance_request(day_request)
		if not day_request_validation.get("ok", false):
			return day_request_validation
		if str(_day_advance_key(day_request)) != str(day_record.get("allocation_key", "")):
			return _failed(&"day_advance_key_mismatch", str(key))
		var day_reproducible: Dictionary = _day_advance_candidate_from(
			day_request, namespace_value, day_root_next_counter
		)
		if day_reproducible != day_record:
			return _failed(&"allocation_candidate_not_reproducible", str(key))
	# Clause 35: every referenced source/target receipt exists byte-identically in `receipts`.
	var embedded: Array[Dictionary] = []
	_collect_embedded_receipts(allocations, embedded)
	_collect_embedded_receipts(day_advances, embedded)
	var referenced_receipt_ids: Dictionary = {}
	for referenced in embedded:
		var receipt_id := str((referenced as Dictionary)["receipt_id"])
		referenced_receipt_ids[receipt_id] = true
		if not receipts.has(receipt_id):
			return _failed(&"root_allocation_receipt_absent", receipt_id)
		if receipts[receipt_id] != referenced:
			return _failed(&"root_allocation_receipt_not_byte_equal", receipt_id)
	for receipt_id in receipts:
		var receipt: Dictionary = receipts[receipt_id]
		if allocation_expected_receipt_counters.has(int(receipt["counter"])):
			if not referenced_receipt_ids.has(str(receipt_id)):
				return _failed(&"root_allocation_receipt_unreferenced", str(receipt_id))
	var minimum_root_next_counter := _minimum_root_next_counter(allocations, day_advances)
	if minimum_root_next_counter >= 0:
		for receipt_id in receipts:
			var receipt: Dictionary = receipts[receipt_id]
			if str(receipt["purpose"]) == "causal_day_instance":
				if int(receipt["counter"]) >= minimum_root_next_counter:
					if not referenced_receipt_ids.has(str(receipt_id)):
						return _failed(&"root_allocation_causal_day_receipt_unreferenced",
							str(receipt_id))
	return {"ok": true}


func _validate_receipt_members(receipt: Dictionary) -> Dictionary:
	var keys := _exact_keys(receipt, RECEIPT_KEYS)
	if not keys.get("ok", false):
		return _failed(&"receipt_malformed", str(keys.get("message", "receipt member set")))
	var purpose := str(receipt["purpose"])
	if not PURPOSE_UNION.has(purpose):
		return _failed(&"receipt_unknown_purpose", purpose)
	if typeof(receipt["counter"]) != TYPE_INT:
		return _failed(&"receipt_malformed", "counter must be an integer")
	if typeof(receipt["namespace"]) != TYPE_STRING or typeof(receipt["token"]) != TYPE_STRING:
		return _failed(&"receipt_malformed", "namespace and token must be strings")
	var numeric: Variant = receipt["numeric_value"]
	if purpose != NUMERIC_PURPOSE:
		if numeric != null:
			return _failed(&"receipt_numeric_value_forbidden", purpose)
		return {"ok": true}
	if numeric != null and (typeof(numeric) != TYPE_INT or int(numeric) < 0):
		return _failed(&"receipt_numeric_value_invalid", purpose)
	return {"ok": true}


## Any nested object carrying exactly the frozen receipt member set is a referenced receipt, whatever
## member name holds it. Keying the walk on shape rather than on names keeps clause 35 total.
func _collect_embedded_receipts(value: Variant, out: Array[Dictionary]) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value
		if _looks_like_receipt(dictionary):
			out.append(dictionary)
			return
		for key in dictionary:
			_collect_embedded_receipts(dictionary[key], out)
	elif typeof(value) == TYPE_ARRAY:
		for element in (value as Array):
			_collect_embedded_receipts(element, out)


func _continuation_candidate_from(request: Dictionary, namespace_value: String, root_next_counter: int) -> Dictionary:
	var kind := str(request["kind"])
	var specs: Array = []
	if kind == "new_run":
		specs.append({"purpose": "run_id", "numeric_value": null})
	specs.append({"purpose": "branch_id", "numeric_value": null})
	var generation := 0
	if kind == "restore":
		generation = int(request["source_desktop_timeline_generation"]) + 1
	specs.append({"purpose": String(NUMERIC_PURPOSE), "numeric_value": generation})
	specs.append({"purpose": "causal_day_instance", "numeric_value": null})
	var remap_sources: Array = request["remap_source_transaction_ids"]
	for _source in remap_sources:
		specs.append({"purpose": "transaction_id", "numeric_value": null})
	var minted: Dictionary = _receipts_from_specs(namespace_value, root_next_counter, specs)
	var cursor := 0
	var run_receipt: Variant = null
	var branch_receipt: Dictionary = {}
	var generation_receipt: Dictionary = {}
	var causal_day_receipt: Dictionary = {}
	if kind == "new_run":
		run_receipt = minted["receipts"][0]
		cursor = 1
	branch_receipt = minted["receipts"][cursor]
	cursor += 1
	generation_receipt = minted["receipts"][cursor]
	cursor += 1
	causal_day_receipt = minted["receipts"][cursor]
	cursor += 1
	var remap_receipts := {}
	for source in remap_sources:
		var source_id := str(source)
		remap_receipts[source_id] = (minted["receipts"][cursor] as Dictionary).duplicate(true)
		cursor += 1
	return {
		"schema_version": SCHEMA_VERSION,
		"kind": kind,
		"request": request.duplicate(true),
		"root_namespace": namespace_value,
		"root_next_counter": root_next_counter,
		"run_id": null if kind == "restore" else str((run_receipt as Dictionary)["token"]),
		"run_id_issuer_receipt": null if kind == "restore" else (run_receipt as Dictionary).duplicate(true),
		"branch_id": str(branch_receipt["token"]),
		"branch_id_issuer_receipt": branch_receipt.duplicate(true),
		"desktop_timeline_generation": generation,
		"desktop_timeline_generation_issuer_receipt": generation_receipt.duplicate(true),
		"causal_day_instance": str(causal_day_receipt["token"]),
		"causal_day_instance_issuer_receipt": causal_day_receipt.duplicate(true),
		"remap_transaction_issuer_receipts": remap_receipts,
	}


func _day_advance_candidate_from(request: Dictionary, namespace_value: String, root_next_counter: int) -> Dictionary:
	var minted: Dictionary = _receipts_from_specs(namespace_value, root_next_counter, [{"purpose": "causal_day_instance", "numeric_value": null}])
	var target: Dictionary = (minted["receipts"] as Array)[0]
	return {
		"schema_version": SCHEMA_VERSION,
		"allocation_key": _day_advance_key(request),
		"request": request.duplicate(true),
		"root_namespace": namespace_value,
		"root_next_counter": root_next_counter,
		"resolution_kind": str(request["resolution_kind"]),
		"source_resolution_receipt_id": str(request["source_resolution_receipt_id"]),
		"source_causal_day_instance_issuer_receipt": (request["source_causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true),
		"target_causal_day_instance_issuer_receipt": target.duplicate(true),
	}


func _receipts_from_specs(namespace_value: String, start_counter: int, specs: Array) -> Dictionary:
	var counter := start_counter
	var minted: Array[Dictionary] = []
	for spec in specs:
		var entry: Dictionary = spec
		var receipt := _mint_receipt(namespace_value, counter, str(entry["purpose"]), entry.get("numeric_value"))
		minted.append(receipt)
		counter += 1
	return {"next_counter": counter, "receipts": minted}


## Clause 34: map entries can only be deleted if the deletion drops no causal-day receipt whose
## source counter is no older than the oldest map-backed allocation attempt.
func _minimum_root_next_counter(allocation_receipts: Dictionary, day_advance_receipts: Dictionary) -> int:
	var minimum_root_next_counter := -1
	for container in [allocation_receipts, day_advance_receipts]:
		for record in container.values():
			if typeof(record) != TYPE_DICTIONARY:
				continue
			if typeof(record.get("root_next_counter", null)) != TYPE_INT:
				continue
			var root_next_counter := int(record["root_next_counter"])
			if minimum_root_next_counter < 0 or root_next_counter < minimum_root_next_counter:
				minimum_root_next_counter = root_next_counter
	return minimum_root_next_counter


func _looks_like_receipt(value: Dictionary) -> bool:
	if value.size() != RECEIPT_KEYS.size():
		return false
	for key in RECEIPT_KEYS:
		if not value.has(key):
			return false
	return true


func _validate_namespace(namespace_value: String) -> Dictionary:
	if namespace_value.length() != NAMESPACE_HEX_LENGTH:
		return _failed(&"root_namespace_invalid", "namespace must be %d characters" % NAMESPACE_HEX_LENGTH)
	for codepoint in namespace_value.to_utf8_buffer():
		var is_digit := codepoint >= 0x30 and codepoint <= 0x39
		var is_lower_hex := codepoint >= 0x61 and codepoint <= 0x66
		if not is_digit and not is_lower_hex:
			return _failed(&"root_namespace_invalid", "namespace must be lowercase hexadecimal")
	return {"ok": true}


# -------------------------------------------------------------------------------------------------
# Envelopes
# -------------------------------------------------------------------------------------------------

func _require_loaded(method: String) -> Dictionary:
	if not _loaded:
		return _failed(&"root_not_loaded", "%s before a durable root exists" % method)
	return {"ok": true}


## A rejection never carries `value`: plan line 729 requires a failed durable advance to return no
## token at all.
func _failed(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "DesktopIssuerRootStore: " + message}
