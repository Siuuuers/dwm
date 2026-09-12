class_name FakeDesktopIssuerRootStore
extends RefCounted

## Test double for DesktopIssuerRootStore (Plan 02 Task 1, dwm-p2r.16).
##
## Duck-typed `extends RefCounted` rather than inheriting the production class, matching all 13
## existing tests/support fakes (dwm-p2r.16 DECISION 8.5).
##
## `last_committed_receipt` is not invented: the plan's own Step 1.1 fixture asserts
## `_issuer_root.last_committed_receipt == issued["receipt"]`, so it is a frozen consumer call site.
## The constructor seeds the namespace and starting counter that same fixture uses,
## `_issuer_with_namespace("11".repeat(32), 7)`.
##
## FIDELITY SPLIT (dwm-p2r.16 DECISION 9.12, refined here).
##
##   REAL, because the plan's own fixture observes them: namespace/counter state, `issue()`,
##   `verify_receipt()`, `capture()`, and `last_committed_receipt`. Tokens and receipt IDs are built
##   from the frozen plan-line-535 preimages implemented inline (~6 lines). That inline duplication
##   is deliberate: it buys double-entry bookkeeping on a formula the whole task depends on. A
##   wrapper around the real production store was rejected because seeding it to counter 7 would
##   require the real store to work, which at RED it does not, so the plan's fixture would fail on
##   "could not seed" rather than on issuer behavior.
##
##   REAL as of DECISION 14.5, the two CONTINUATION allocation methods: `prepare_allocation()` and
##   `commit_allocation()` hand-mirror DesktopIssuerRootStore's semantics -- same validation order,
##   same frozen rejection codes, mutation-free prepare, occupied-map replay/conflict, the
##   `root_next_counter` supersession check, and a commit that genuinely appends receipts and
##   advances the counter. FINDING C forced this: five issuer tests require those two methods to
##   SUCCEED and then assert real bundle content, and no test arms them, so a programmable double
##   made a green issuer unreachable. Their assertions -- generation zero, source plus one -- only
##   mean something if the substrate behaves like a real root, which is the same double-entry
##   argument that justified inlining the plan-line-535 preimages below.
##
##   PROGRAMMABLE, the two DAY-ADVANCE allocation methods: they are the ROOT's own obligations, S3
##   never needs them to succeed, and their semantics are proven against the REAL
##   DesktopIssuerRootStore over JsonFileStorage+FakeFileOps in
##   test_causal_day_advance_identity_port.gd (DECISION 9.4). Tests arm the response and read
##   `call_log`.
##
## `arm()` still overrides all four, so an armed response wins over the mirror.
##
## An unarmed day-advance method returns the fake-local code `fake_result_not_armed`, never
## `not_implemented` -- a rejection assertion must never be satisfiable by an unconfigured double
## (DECISION 9.9).
##
## Every fake-local code below is an invention of this double. Tests MUST NOT assert them as though
## they were frozen production contract; assert only the DECISION 9.9 distinctness law.

## The closed v1 purpose union, plan line 535.
const PURPOSE_UNION: Array[StringName] = [
	&"run_id",
	&"branch_id",
	&"desktop_timeline_generation",
	&"causal_day_instance",
	&"board_id",
	&"transaction_id",
	&"placement_nonce",
	&"debug_nonce",
	&"explosion_nonce",
	&"receipt_id",
]

## The only purpose whose receipt carries a nonnull `numeric_value` (plan line 535).
const NUMERIC_PURPOSE := &"desktop_timeline_generation"

## Exact receipt member set, plan line 535.
const RECEIPT_KEYS: Array[String] = [
	"receipt_id",
	"purpose",
	"namespace",
	"counter",
	"token",
	"numeric_value",
]

## Exact continuation request member set, plan line 729. Mirrors the production constant.
const ALLOCATION_REQUEST_KEYS: Array[String] = [
	"existing_run_id",
	"kind",
	"remap_source_transaction_ids",
	"source_desktop_timeline_generation",
	"transaction_id",
	"transaction_issuer_receipt",
]

const ALLOCATION_KINDS: Array[String] = ["new_run", "restore"]

const ROOT_SCHEMA_VERSION := 1

var namespace_hex: String = ""
var next_counter: int = 0
var last_committed_receipt: Dictionary = {}

## The append-only ledger and the two disjoint allocation maps, plan line 1682.
var receipts: Dictionary = {}
var allocation_receipts: Dictionary = {}
var day_advance_allocation_receipts: Dictionary = {}

## Spy surface: one entry per call, `{"method": StringName, "argument": Variant}`, in call order.
var call_log: Array[Dictionary] = []

var _configured := false
var _armed_results: Dictionary = {}
var _armed_issue_failure: StringName = &""
var _pending_flush := false


func _init(seed_namespace_hex: String = "", seed_next_counter: int = 0) -> void:
	namespace_hex = seed_namespace_hex
	next_counter = seed_next_counter


# ---------------------------------------------------------------------------------------------
# Frozen root-store surface (nine methods, exact names and arity)
# ---------------------------------------------------------------------------------------------

func configure(storage: Object, namespace_source: Object) -> Dictionary:
	_log(&"configure", {"storage": storage, "namespace_source": namespace_source})
	_configured = true
	return {"ok": true}


func load_or_create() -> Dictionary:
	_log(&"load_or_create", null)
	return {"ok": true, "value": _document(true)}


## Mints the next receipt and advances the counter before returning, per plan line 535: "Issuance
## atomically advances the monotonic root counter before returning any token."
##
## The root store accepts ALL TEN purposes, including `desktop_timeline_generation` and
## `causal_day_instance`. Rejecting those two is the ISSUER's law (plan line 729), not the root's --
## the two atomic allocators mint exactly those purposes THROUGH this method, so a root that
## refused them could never allocate a generation or a causal day at all.
func issue(purpose: StringName) -> Dictionary:
	_log(&"issue", purpose)
	if _armed_issue_failure != &"":
		var code := _armed_issue_failure
		_armed_issue_failure = &""
		return _failed(code, "armed durable-write failure for issue(%s)" % String(purpose))
	if not PURPOSE_UNION.has(purpose):
		return _failed(&"fake_unknown_purpose", String(purpose))
	var receipt := mint(purpose)
	_pending_flush = false
	return {"ok": true, "value": {"token": receipt["token"], "issuer_receipt": receipt}, "receipt": receipt}


func issue_deferred(purpose: StringName) -> Dictionary:
	_log(&"issue_deferred", purpose)
	if not PURPOSE_UNION.has(purpose):
		return _failed(&"fake_unknown_purpose", String(purpose))
	var receipt := mint(purpose)
	_pending_flush = true
	return {"ok": true, "value": {"token": receipt["token"], "issuer_receipt": receipt}, "receipt": receipt}


func flush() -> Dictionary:
	_log(&"flush", {})
	var written := _pending_flush
	_pending_flush = false
	return {"ok": true, "value": {"written": written}}


func verify_receipt(receipt: Dictionary, expected_purpose: StringName) -> Dictionary:
	_log(&"verify_receipt", {"receipt": receipt, "expected_purpose": expected_purpose})
	for key: String in RECEIPT_KEYS:
		if not receipt.has(key):
			return _failed(&"fake_receipt_malformed", "missing " + key)
	if receipt.size() != RECEIPT_KEYS.size():
		return _failed(&"fake_receipt_malformed", "extra members")
	var receipt_id := str(receipt["receipt_id"])
	if not receipts.has(receipt_id):
		return _failed(&"fake_receipt_absent", receipt_id)
	var canonical_receipt: Dictionary = receipts[receipt_id].duplicate(true)
	var presented_receipt: Dictionary = receipt.duplicate(true)
	canonical_receipt.erase("provenance")
	presented_receipt.erase("provenance")
	if canonical_receipt != presented_receipt:
		return _failed(&"fake_receipt_not_byte_equal", receipt_id)
	if str(receipt["purpose"]) != String(expected_purpose):
		return _failed(&"fake_receipt_wrong_purpose", str(receipt["purpose"]))
	return {"ok": true, "value": {"receipt": (receipt as Dictionary).duplicate(true)}}


## Mutation-free. Plan line 729: an identical replay of the same allocation transaction returns its
## recorded bundle, and a different request at an occupied transaction identity conflicts.
func prepare_allocation(request: Dictionary) -> Dictionary:
	_log(&"prepare_allocation", request)
	if _armed_results.has(&"prepare_allocation"):
		return _armed_results[&"prepare_allocation"]
	var validated := _validate_allocation_request(request)
	if not validated.get("ok", false):
		return validated
	var transaction_id := str(request["transaction_id"])
	if allocation_receipts.has(transaction_id):
		var recorded: Dictionary = allocation_receipts[transaction_id]
		if recorded.get("request") != request:
			return _failed(&"allocation_transaction_conflict", transaction_id)
		return {"ok": true, "value": recorded.duplicate(true)}
	return {"ok": true, "value": _continuation_candidate(request)}


func commit_allocation(candidate: Dictionary) -> Dictionary:
	_log(&"commit_allocation", candidate)
	if _armed_results.has(&"commit_allocation"):
		return _armed_results[&"commit_allocation"]
	var shaped := _validate_candidate(candidate)
	if not shaped.get("ok", false):
		return shaped
	var request: Dictionary = candidate["request"]
	var validated := _validate_allocation_request(request)
	if not validated.get("ok", false):
		return validated
	var transaction_id := str(request["transaction_id"])
	if allocation_receipts.has(transaction_id):
		if allocation_receipts[transaction_id] != candidate:
			return _failed(&"allocation_transaction_conflict", transaction_id)
		return {"ok": true, "value": candidate.duplicate(true)}
	return _commit_candidate(candidate, transaction_id)


func prepare_causal_day_advance(request: Dictionary) -> Dictionary:
	return _armed_or_unarmed(&"prepare_causal_day_advance", request)


func commit_causal_day_advance(candidate: Dictionary) -> Dictionary:
	return _armed_or_unarmed(&"commit_causal_day_advance", candidate)


## Detached: mutating the returned document must never reach this store (plan line 797, "capture
## detachment").
func capture() -> Dictionary:
	_log(&"capture", null)
	return {"ok": true, "value": _document(true)}


# ---------------------------------------------------------------------------------------------
# Test-facing helpers (underscore-free by choice: this class is not surface-hashed)
# ---------------------------------------------------------------------------------------------

## Mints a receipt exactly as `issue()` would, advancing the counter, and returns it. Tests use this
## to seed a ledger or to build the receipt they expect a production call to produce.
##
## `numeric_value` is nonnull only for `desktop_timeline_generation`; because the frozen `issue()`
## takes no value argument, a generation receipt can only be minted through an allocator, so this
## helper is the seam that lets a test construct one.
func mint(purpose: StringName, numeric_value: Variant = null) -> Dictionary:
	var counter := next_counter
	var token := token_for(namespace_hex, counter, purpose)
	var receipt := {
		"receipt_id": receipt_id_for(namespace_hex, counter, purpose, token),
		"purpose": String(purpose),
		"namespace": namespace_hex,
		"counter": counter,
		"token": token,
		"numeric_value": numeric_value if purpose == NUMERIC_PURPOSE else null,
	}
	receipts[str(receipt["receipt_id"])] = receipt.duplicate(true)
	next_counter = counter + 1
	last_committed_receipt = receipt.duplicate(true)
	return receipt


## Arms one of the four allocation methods to return `result` on its next and every later call.
func arm(method: StringName, result: Dictionary) -> void:
	_armed_results[method] = result


## Arms the next `issue()` to fail, modelling a failed durable advance. Plan line 729: "A failed
## durable advance returns no token."
func fail_next_issue(code: StringName = &"fake_durable_write_failed") -> void:
	_armed_issue_failure = code


func calls_to(method: StringName) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for entry: Dictionary in call_log:
		if entry.get("method") == method:
			matched.append(entry)
	return matched


func is_configured() -> bool:
	return _configured


## The frozen token preimage, plan line 535:
##     purpose + "." + sha256(namespace + "\n" + str(counter) + "\n" + purpose)
static func token_for(namespace_value: String, counter: int, purpose: StringName) -> String:
	return "%s.%s" % [
		String(purpose),
		sha256_hex("%s\n%d\n%s" % [namespace_value, counter, String(purpose)]),
	]


## The frozen structural receipt key, plan line 535:
##     "issuer_receipt." + sha256("desktop_issuer_receipt_v1\n" + namespace + "\n" + str(counter)
##                                + "\n" + purpose + "\n" + token)
static func receipt_id_for(namespace_value: String, counter: int, purpose: StringName,
		token: String) -> String:
	return "issuer_receipt." + sha256_hex("desktop_issuer_receipt_v1\n%s\n%d\n%s\n%s" % [
		namespace_value, counter, String(purpose), token,
	])


static func sha256_hex(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


# ---------------------------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------------------------

func _document(detached: bool) -> Dictionary:
	var document := {
		"schema_version": ROOT_SCHEMA_VERSION,
		"namespace": namespace_hex,
		"next_counter": next_counter,
		"receipts": receipts,
		"allocation_receipts": allocation_receipts,
		"day_advance_allocation_receipts": day_advance_allocation_receipts,
	}
	return document.duplicate(true) if detached else document


func _armed_or_unarmed(method: StringName, argument: Dictionary) -> Dictionary:
	_log(method, argument)
	if _armed_results.has(method):
		return _armed_results[method]
	return _failed(&"fake_result_not_armed", String(method))


# ---------------------------------------------------------------------------------------------
# Continuation-allocation mirror (DECISION 14.5)
#
# Hand-mirrors DesktopIssuerRootStore's continuation half: same validation order, same frozen
# rejection codes, and the same candidate shape. Kept deliberately faithful rather than defensive --
# where the production class indexes a candidate member directly, so does this, because a double
# whose value is fidelity must not diverge in either direction. The only reachable call path runs
# behind `_validate_candidate`, which rejects an empty or shapeless candidate first.
# ---------------------------------------------------------------------------------------------

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
	if typeof(request["existing_run_id"]) != TYPE_STRING \
			or str(request["existing_run_id"]).strip_edges().is_empty():
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


func _validate_candidate(candidate: Dictionary) -> Dictionary:
	for member in ["request", "root_namespace", "root_next_counter", "schema_version"]:
		if not candidate.has(member):
			return _failed(&"allocation_candidate_malformed", "missing " + str(member))
	if typeof(candidate["request"]) != TYPE_DICTIONARY:
		return _failed(&"allocation_candidate_malformed", "request must be an object")
	if int(candidate["schema_version"]) != ROOT_SCHEMA_VERSION:
		return _failed(&"allocation_candidate_malformed", "unexpected candidate schema_version")
	return _exact_keys(candidate["request"], ALLOCATION_REQUEST_KEYS)


func _exact_keys(value: Dictionary, expected: Array) -> Dictionary:
	if value.size() != expected.size():
		return _failed(&"request_member_set_invalid",
			"expected %d members, saw %d" % [expected.size(), value.size()])
	for key in expected:
		if not value.has(key):
			return _failed(&"request_member_set_invalid", "missing " + str(key))
	return {"ok": true}


## The exact proposed bundle. New Run opens generation zero; restore takes the source generation plus
## one and keeps the existing run. One fresh transaction receipt is minted per remap source, and the
## candidate records the root identity it was prepared against so commit can detect supersession.
func _continuation_candidate(request: Dictionary) -> Dictionary:
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
	var proposed: Array = (_prospective(specs) as Dictionary)["receipts"]
	var cursor := 0
	var run_receipt: Variant = null
	if kind == "new_run":
		run_receipt = proposed[cursor]
		cursor += 1
	var branch_receipt: Dictionary = proposed[cursor]
	var generation_receipt: Dictionary = proposed[cursor + 1]
	var causal_day_receipt: Dictionary = proposed[cursor + 2]
	var remap_receipts := {}
	for index in range(remap_sources.size()):
		remap_receipts[str(remap_sources[index])] = \
			(proposed[cursor + 3 + index] as Dictionary).duplicate(true)
	return {
		"schema_version": ROOT_SCHEMA_VERSION,
		"kind": kind,
		"request": request.duplicate(true),
		"root_namespace": namespace_hex,
		"root_next_counter": next_counter,
		"run_id": str(request["existing_run_id"]) if kind == "restore" \
			else str((run_receipt as Dictionary)["token"]),
		"run_id_issuer_receipt": null if kind == "restore" \
			else (run_receipt as Dictionary).duplicate(true),
		"branch_id": str(branch_receipt["token"]),
		"branch_id_issuer_receipt": branch_receipt.duplicate(true),
		"desktop_timeline_generation": generation,
		"desktop_timeline_generation_issuer_receipt": generation_receipt.duplicate(true),
		"causal_day_instance": str(causal_day_receipt["token"]),
		"causal_day_instance_issuer_receipt": causal_day_receipt.duplicate(true),
		"remap_transaction_issuer_receipts": remap_receipts,
	}


## Mints nothing. Returns what `specs` WOULD produce from the current counter, so prepare can propose
## a whole bundle without touching state.
func _prospective(specs: Array) -> Dictionary:
	var counter := next_counter
	var proposed: Array[Dictionary] = []
	for spec in specs:
		var entry: Dictionary = spec
		proposed.append(_receipt_at(counter, str(entry["purpose"]), entry.get("numeric_value")))
		counter += 1
	return {"receipts": proposed, "next_counter": counter}


func _receipt_at(counter: int, purpose: String, numeric_value: Variant) -> Dictionary:
	var token := token_for(namespace_hex, counter, StringName(purpose))
	return {
		"receipt_id": receipt_id_for(namespace_hex, counter, StringName(purpose), token),
		"purpose": purpose,
		"namespace": namespace_hex,
		"counter": counter,
		"token": token,
		"numeric_value": numeric_value if purpose == String(NUMERIC_PURPOSE) else null,
	}


## Plan line 729: commit repeats root namespace/counter/request validation, so a candidate prepared
## against a superseded counter fails rather than silently reusing an abandoned counter.
func _commit_candidate(candidate: Dictionary, key: String) -> Dictionary:
	if str(candidate["root_namespace"]) != namespace_hex:
		return _failed(&"allocation_root_namespace_mismatch", key)
	if int(candidate["root_next_counter"]) != next_counter:
		return _failed(&"allocation_counter_superseded", key)
	var expected := _candidate_receipts(candidate)
	var specs: Array = []
	for receipt in expected:
		var entry: Dictionary = receipt
		specs.append({"purpose": str(entry["purpose"]), "numeric_value": entry["numeric_value"]})
	var minted: Dictionary = _prospective(specs)
	var replayed: Array = minted["receipts"]
	for index in range(expected.size()):
		if replayed[index] != expected[index]:
			return _failed(&"allocation_candidate_not_reproducible", key)
	for receipt in replayed:
		var entry: Dictionary = receipt
		receipts[str(entry["receipt_id"])] = entry.duplicate(true)
	next_counter = int(minted["next_counter"])
	if not replayed.is_empty():
		last_committed_receipt = (replayed[replayed.size() - 1] as Dictionary).duplicate(true)
	allocation_receipts[key] = candidate.duplicate(true)
	return {"ok": true, "value": candidate.duplicate(true)}


## The newly minted receipts a candidate commits, in the exact order they were minted.
func _candidate_receipts(candidate: Dictionary) -> Array:
	var ordered: Array = []
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


func _log(method: StringName, argument: Variant) -> void:
	call_log.append({"method": method, "argument": argument})


func _failed(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "FakeDesktopIssuerRootStore: " + message}
