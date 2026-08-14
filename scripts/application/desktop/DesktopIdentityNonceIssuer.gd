class_name DesktopIdentityNonceIssuer
extends RefCounted

## Production external identity issuer for the desktop timeline (Plan 02 Task 1, dwm-p2r.16).
##
## Every identity this class hands out is derived, never guessed: a token is a pure function of the
## root's namespace, its monotonic counter and the purpose, and an anchored child ID is a pure
## function of its parent receipt plus its own kind, ordinal and sorted source set. Nothing here
## reads a clock, a process handle, or a general-purpose number generator, and Step 1.4 scans this
## file first to keep it that way.
##
## LAYERING. The root store owns durability, the counter, the ledger and the allocation maps; this
## class owns the two laws the root deliberately does not enforce -- that a generation or a causal
## day may never be minted by a direct `issue()` -- plus the whole anchored-child contract, for
## which the root offers no method at all. Everything else delegates, so a rejection carries the
## code its owning layer froze rather than a duplicate invented here (dwm-p2r.16 DECISION 14.3).
##
## FROZEN PUBLIC SURFACE -- do not rename, reorder, or change the arity of any method below.
## `public_surface_sha256` in evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json is
## derived by parsing these declarations in source order with types stripped, so the preimage is
## exactly this UTF-8/LF string including its final newline:
##
##     configure(root_store)
##     issue(purpose)
##     verify_issued(receipt,expected_purpose)
##     derive_child(request)
##     validate_child(provenance,expected_kind)
##     prepare_continuation_allocation(request)
##     commit_continuation_allocation(candidate)
##     prepare_causal_day_advance(request)
##     commit_causal_day_advance(candidate)
##     capture_root()
##
## Parameter NAMES are part of that preimage exactly as much as method names are (DECISION 8.2), and
## every helper is underscore-prefixed so it stays out of the derived surface (DECISION 13.4).

const _CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## The two purposes the issuer refuses to mint directly, plan line 729. Both are reachable only
## through an allocator, so a crash can never burn an unkeyed generation or next-day identity.
const GENERATION_PURPOSE := &"desktop_timeline_generation"
const CAUSAL_DAY_PURPOSE := &"causal_day_instance"

## The purpose an anchored child must be anchored to, plan line 537.
const CHILD_PARENT_PURPOSE := &"transaction_id"

## The closed v1 child-kind union, plan line 537. All 22 members.
const CHILD_KINDS: Array[String] = [
	"schedule_entry",
	"schedule_commit",
	"day7_schedule_provenance",
	"empty_schedule_done",
	"contact_source",
	"hospital_resolution",
	"hospital_miss",
	"sylvia_hospital_witness",
	"day_resolution_stage",
	"board_command",
	"board_start",
	"shop_quote",
	"desktop_action",
	"causal_sequence",
	"condition",
	"board_fate",
	"destination_intent",
	"notification_intent",
	"continuation_operation",
	"warning",
	"navigation",
	"terminal_intent",
]

## Exact `derive_child()` request member set, plan line 537.
const CHILD_REQUEST_KEYS: Array[String] = [
	"child_kind",
	"ordinal",
	"parent_receipt_id",
	"source_ids",
]

## Exact child provenance member set, plan line 537.
const PROVENANCE_KEYS: Array[String] = [
	"child_id",
	"child_kind",
	"ordinal",
	"parent_receipt_id",
	"schema_version",
	"source_ids",
]

## ASSUMPTION, not frozen contract: plan line 537 requires a `schema_version` member but never fixes
## its value. 1 matches the root document and the `desktop_child_v1` domain tag (DECISION 14.4).
const CHILD_SCHEMA_VERSION := 1

var _root: Object = null


# -------------------------------------------------------------------------------------------------
# Frozen public surface
# -------------------------------------------------------------------------------------------------

## Retains the already-loaded root. It never calls `load_or_create()`: the caller owns loading, which
## is what both call sites do. Replacement is refused, mirroring the root's own precedent.
func configure(root_store: Object) -> Dictionary:
	if root_store == null:
		return _failed(&"issuer_configure_invalid", "configure requires a root store")
	if _root != null and _root != root_store:
		return _failed(&"issuer_already_configured", "configure may not replace a retained root")
	_root = root_store
	return {"ok": true}


## Plan line 729: accepts the ordinary members of the purpose union and delegates one append-only
## counter advance to the root before returning any token. The two allocator-only purposes are
## refused BEFORE the root is reached, so a refusal burns no counter.
func issue(purpose: StringName) -> Dictionary:
	var ready := _require_configured("issue")
	if not ready.get("ok", false):
		return ready
	if purpose == GENERATION_PURPOSE:
		return _failed(&"generation_allocation_required",
			"a desktop timeline generation is allocated, never issued directly")
	if purpose == CAUSAL_DAY_PURPOSE:
		return _failed(&"causal_day_advance_allocation_required",
			"a causal day instance is allocated, never issued directly")
	var issued: Dictionary = _root.call(&"issue", purpose)
	return issued


## Plan line 535: an ID-only, absent, wrong-purpose, or byte-changed receipt never proves provenance.
## All four are the root's own verification law, so this delegates rather than restating it.
func verify_issued(receipt: Dictionary, expected_purpose: StringName) -> Dictionary:
	var ready := _require_configured("verify_issued")
	if not ready.get("ok", false):
		return ready
	var proven: Dictionary = _root.call(&"verify_receipt", receipt, expected_purpose)
	return proven


## Plan line 537. The root exposes no lookup-by-ID, so the parent is resolved out of a detached
## capture and then proven through the root's own `verify_receipt()`, which supplies the member-set,
## presence, byte-equality and purpose laws without this class restating any of them.
func derive_child(request: Dictionary) -> Dictionary:
	var ready := _require_configured("derive_child")
	if not ready.get("ok", false):
		return ready
	var shaped := _exact_keys(request, CHILD_REQUEST_KEYS)
	if not shaped.get("ok", false):
		return shaped
	var child_kind := str(request["child_kind"])
	var ordinal_check := _validate_child_shape(child_kind, request["ordinal"], request["source_ids"])
	if not ordinal_check.get("ok", false):
		return ordinal_check
	var parent := _resolve_parent(str(request["parent_receipt_id"]))
	if not parent.get("ok", false):
		return parent
	var derived := _child_id(parent["value"], child_kind, int(request["ordinal"]),
		request["source_ids"])
	if not derived.get("ok", false):
		return derived
	var provenance := {
		"schema_version": CHILD_SCHEMA_VERSION,
		"parent_receipt_id": str(request["parent_receipt_id"]),
		"child_kind": child_kind,
		"ordinal": int(request["ordinal"]),
		"source_ids": (request["source_ids"] as Array).duplicate(true),
		"child_id": str(derived["value"]),
	}
	return {
		"ok": true,
		"value": {"child_id": str(derived["value"]), "provenance": provenance.duplicate(true)},
		"receipt": provenance.duplicate(true),
	}


## Plan line 537: repeats the ledger lookup, the purpose check, and the byte derivation, so a
## provenance whose child ID no longer follows from its own members is refused rather than repaired.
func validate_child(provenance: Dictionary, expected_kind: StringName) -> Dictionary:
	var ready := _require_configured("validate_child")
	if not ready.get("ok", false):
		return ready
	var shaped := _exact_keys(provenance, PROVENANCE_KEYS)
	if not shaped.get("ok", false):
		return shaped
	if int(provenance["schema_version"]) != CHILD_SCHEMA_VERSION:
		return _failed(&"child_provenance_malformed", "unexpected provenance schema_version")
	var child_kind := str(provenance["child_kind"])
	if child_kind != String(expected_kind):
		return _failed(&"child_kind_mismatch", child_kind)
	var shape := _validate_child_shape(child_kind, provenance["ordinal"], provenance["source_ids"])
	if not shape.get("ok", false):
		return shape
	var parent := _resolve_parent(str(provenance["parent_receipt_id"]))
	if not parent.get("ok", false):
		return parent
	var derived := _child_id(parent["value"], child_kind, int(provenance["ordinal"]),
		provenance["source_ids"])
	if not derived.get("ok", false):
		return derived
	if str(provenance["child_id"]) != str(derived["value"]):
		return _failed(&"child_id_not_reproducible", str(provenance["child_id"]))
	return {"ok": true, "value": {"provenance": provenance.duplicate(true)}}


## Mutation-free. Delegates the whole proposal to the root, then adds the one member the root's
## candidate does not carry: the `transaction_remap` of plan line 1712, empty for New Run.
func prepare_continuation_allocation(request: Dictionary) -> Dictionary:
	var ready := _require_configured("prepare_continuation_allocation")
	if not ready.get("ok", false):
		return ready
	var prepared: Dictionary = _root.call(&"prepare_allocation", request)
	if not prepared.get("ok", false):
		return prepared
	return {"ok": true, "value": _with_transaction_remap(prepared.get("value", {}))}


## Plan line 729: commit repeats root namespace/counter/request validation and atomically persists
## that exact bundle. The augmented candidate is what is persisted, so an identical replay returns it
## byte-for-byte and changed bytes at an occupied transaction conflict -- both the root's own law.
func commit_continuation_allocation(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured("commit_continuation_allocation")
	if not ready.get("ok", false):
		return ready
	var committed: Dictionary = _root.call(&"commit_allocation", candidate)
	if not committed.get("ok", false):
		return committed
	return {"ok": true, "value": committed.get("value", {})}


## Plan line 1682. The shared day-advance allocator is the root's durable map; this delegates so that
## the atomic receipt/map/counter commit and every crash cut around it stay in one place.
func prepare_causal_day_advance(request: Dictionary) -> Dictionary:
	var ready := _require_configured("prepare_causal_day_advance")
	if not ready.get("ok", false):
		return ready
	var prepared: Dictionary = _root.call(&"prepare_causal_day_advance", request)
	return prepared


func commit_causal_day_advance(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured("commit_causal_day_advance")
	if not ready.get("ok", false):
		return ready
	var committed: Dictionary = _root.call(&"commit_causal_day_advance", candidate)
	return committed


## Detached by the root: mutating the captured document can never lower, replace, or restore root
## state (plan line 729).
func capture_root() -> Dictionary:
	var ready := _require_configured("capture_root")
	if not ready.get("ok", false):
		return ready
	var captured: Dictionary = _root.call(&"capture")
	return captured


# -------------------------------------------------------------------------------------------------
# Anchored-child derivation
# -------------------------------------------------------------------------------------------------

## Resolves a parent receipt ID against the authoritative ledger and proves it. ID-only input is
## legal HERE, and only here, because the issuer performs the lookup itself; plan line 535 bars a
## CALLER from proving provenance with an identifier alone.
func _resolve_parent(parent_receipt_id: String) -> Dictionary:
	var captured: Dictionary = _root.call(&"capture")
	if not captured.get("ok", false):
		return captured
	var receipts: Dictionary = (captured.get("value", {}) as Dictionary).get("receipts", {})
	if not receipts.has(parent_receipt_id):
		return _failed(&"child_parent_absent", parent_receipt_id)
	var parent: Dictionary = receipts[parent_receipt_id]
	var proven: Dictionary = _root.call(&"verify_receipt", parent, CHILD_PARENT_PURPOSE)
	if not proven.get("ok", false):
		return proven
	return {"ok": true, "value": parent}


## The frozen domain-separated child preimage, plan line 537. Lowercase by construction: the kind is
## a registered lowercase member and the digest is hex.
func _child_id(parent: Dictionary, child_kind: String, ordinal: int, source_ids: Variant) -> Dictionary:
	var canonical: Dictionary = _CANONICAL_WRITER.stringify(source_ids)
	if not canonical.get("ok", false):
		return _failed(&"child_source_ids_malformed",
			str(canonical.get("message", "source IDs are not canonically representable")))
	return {"ok": true, "value": "%s.%s" % [
		child_kind,
		_sha256_hex("desktop_child_v1\n%s\n%d\n%s\n%s\n%d\n%s" % [
			str(parent.get("namespace", "")),
			int(parent.get("counter", 0)),
			str(parent.get("receipt_id", "")),
			child_kind,
			ordinal,
			str(canonical.get("value", "")),
		]),
	]}


## Plan line 537: a registered kind, a nonnegative ordinal, and already sorted unique nonblank source
## IDs. Callers may not submit unsorted IDs for the issuer to repair.
func _validate_child_shape(child_kind: String, ordinal: Variant, source_ids: Variant) -> Dictionary:
	if not CHILD_KINDS.has(child_kind):
		return _failed(&"child_kind_unregistered", child_kind)
	if typeof(ordinal) != TYPE_INT or int(ordinal) < 0:
		return _failed(&"child_ordinal_invalid", str(ordinal))
	if typeof(source_ids) != TYPE_ARRAY:
		return _failed(&"child_source_ids_malformed", "source IDs must be an array")
	var values: Array = source_ids
	var previous := ""
	for index in range(values.size()):
		if typeof(values[index]) != TYPE_STRING:
			return _failed(&"child_source_ids_malformed", "source IDs must be strings")
		var current := str(values[index])
		if current.strip_edges().is_empty():
			return _failed(&"child_source_ids_blank", "source IDs must be nonblank")
		if index > 0 and current <= previous:
			return _failed(&"child_source_ids_unsorted", current)
		previous = current
	return {"ok": true}


# -------------------------------------------------------------------------------------------------
# Continuation bundle
# -------------------------------------------------------------------------------------------------

## Plan line 1712: each restore entry is exactly `{source_transaction_id,new_transaction_id,
## new_transaction_issuer_receipt}` keyed by the source ID, and New Run requires `{}`. Idempotent, so
## re-augmenting a recorded candidate on an allocation replay reproduces the identical member.
func _with_transaction_remap(bundle: Dictionary) -> Dictionary:
	var augmented: Dictionary = bundle
	var minted: Dictionary = augmented.get("remap_transaction_issuer_receipts", {})
	var sources: Array = (augmented.get("request", {}) as Dictionary).get(
		"remap_source_transaction_ids", [])
	var remap := {}
	for source in sources:
		var source_id := str(source)
		var receipt: Dictionary = minted.get(source_id, {})
		remap[source_id] = {
			"source_transaction_id": source_id,
			"new_transaction_id": str(receipt.get("token", "")),
			"new_transaction_issuer_receipt": receipt.duplicate(true),
		}
	augmented["transaction_remap"] = remap
	return augmented


# -------------------------------------------------------------------------------------------------
# Envelopes
# -------------------------------------------------------------------------------------------------

func _require_configured(method: String) -> Dictionary:
	if _root == null:
		return _failed(&"issuer_not_configured", "DesktopIdentityNonceIssuer.%s before configure" % method)
	return {"ok": true}


func _exact_keys(value: Dictionary, expected: Array) -> Dictionary:
	if value.size() != expected.size():
		return _failed(&"request_member_set_invalid",
			"expected %d members, saw %d" % [expected.size(), value.size()])
	for key in expected:
		if not value.has(key):
			return _failed(&"request_member_set_invalid", "missing " + str(key))
	return {"ok": true}


static func _sha256_hex(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _failed(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "DesktopIdentityNonceIssuer: " + message}
