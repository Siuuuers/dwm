extends RefCounted

## Reversible day-resolution start port (Plan 01 Task 6, dwm-p2r.13, Steps 6.1/6.2/6.5).
##
## Turns a REAL committed Schedule into the one `P01.day_resolution.start` receipt a day resolution
## may begin from. `prepare_from_committed_schedule()` is PURE: it revalidates the saved aggregate
## against the saved fingerprint, freezes the exact slot order and receipt IDs, derives the start
## identity, and returns a detached candidate. It touches no live lifecycle state and emits nothing.
##
## WHY THE START ROW SHARES THE STAGE KIND. Matrix row P01.day_resolution.start (plan line 92) uses
## child_kind `day_resolution_stage` -- the SAME kind as the per-stage row at line 93 -- and is
## distinguished only by its RESERVED ordinal 0 and its `role` token. Inventing a
## `day_resolution_start` kind would look right in isolation and would silently break every later
## stage derivation, which is why the constant below is spelled out with this note attached.
##
## THE BOARD-FATE RECEIPT IS BOUND, NOT INTERPRETED (Step 6.5). Plan 02 owns its meaning. This port
## requires only that it is an object carrying a nonblank `receipt_id`, then projects that id and
## hashes the WHOLE receipt into the row. Reading any other member would be reinterpretation, and
## would also let Plan 02 change its own shape without moving this identity.
##
## NO SYNTHETIC SOURCE (Step 6.6). A bare Array, a receiptless empty aggregate, a stale fingerprint,
## an unregistered action, or a source day outside 1..7 is refused here rather than seeded with an
## empty list further down.

const _STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

## Plan line 92: the reserved start ordinal under the shared stage kind.
const START_CHILD_KIND := &"day_resolution_stage"
const RESERVED_START_ORDINAL := 0
const START_ROLE := "day_resolution.start"
## Semantic publication kind for the shared ScheduleFoundationPublicationLedger.
const PUBLICATION_KIND := "day_resolution_start"
const ROOT_PURPOSE := &"transaction_id"

## Exact `prepare_from_committed_schedule()` request members (sorted).
const REQUEST_KEYS: Array[String] = [
	"board_fate_receipt", "causal_day_instance", "committed_schedule", "resolution_id",
	"resolution_issuer_receipt", "route_plan",
]
## Exact start-receipt members (sorted).
const START_RECEIPT_KEYS: Array[String] = [
	"board_fate_receipt_id", "causal_day_instance", "receipt_id", "receipt_provenance",
	"resolution_id", "schedule_commit_receipt_id", "schedule_entry_ids", "source_day",
]

const _REGISTRY_METHODS: Array[String] = ["fingerprint", "find_record"]
const _ISSUER_METHODS: Array[String] = ["verify_issued", "derive_child", "validate_child"]

const _LEDGER_METHODS: Array[String] = ["record_before_emit"]
const _STATE_PORT_METHODS: Array[String] = ["capture", "commit", "rollback", "publish"]

var _state_port: Object = null
var _action_registry: Object = null
var _identity_issuer: Object = null
var _publication_ledger: Object = null


## DIRECT CONSTRUCTOR DEPENDENCIES (Plan 01 Task 6 Step 6.5, dwm-p2r.13): the retained state port,
## the retained Schedule registry, the exact `.16` production issuer, and the ONE shared
## publication ledger. Constructor injection rather than a `configure()` seam is deliberate here --
## Bootstrap builds this port exactly once and there is no lawful moment at which it exists
## un-owned, so there is no half-configured state to defend against. (Day7ScheduleProvenance is the
## opposite case: plan line 467 freezes a `configure()` pair for it, so it keeps one.)
func _init(state_port: Object, action_registry: Object, identity_issuer: Object,
		publication_ledger: Object) -> void:
	_state_port = state_port
	_action_registry = action_registry
	_identity_issuer = identity_issuer
	_publication_ledger = publication_ledger


## Every dependency must satisfy its contract before any work happens. Returns {} when ready.
func _require_dependencies() -> Dictionary:
	if not _has_methods(_action_registry, _REGISTRY_METHODS):
		return _fail(&"invalid_action_registry", "the registry contract is incomplete", {})
	if not _has_methods(_identity_issuer, _ISSUER_METHODS):
		return _fail(&"invalid_identity_issuer", "the issuer contract is incomplete", {})
	if not _has_methods(_publication_ledger, _LEDGER_METHODS):
		return _fail(&"invalid_publication_ledger", "the ledger contract is incomplete", {})
	if not _has_methods(_state_port, _STATE_PORT_METHODS):
		return _fail(&"invalid_state_port", "the state port contract is incomplete", {})
	return {}


## Pure preparation. Returns value={start_receipt, committed_schedule, route_plan,
## schedule_commit_receipt_id, board_fate_receipt_id}, all detached.
func prepare_from_committed_schedule(request: Dictionary) -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	if typeof(request) != TYPE_DICTIONARY:
		return _fail(&"invalid_day_resolution_start", "the request must be a dictionary", {})
	var shape := _exact_keys(request, REQUEST_KEYS)
	if not shape.is_empty():
		return shape
	for field: String in ["resolution_id", "causal_day_instance"]:
		if not _is_nonblank_string(request[field]):
			return _fail(&"invalid_day_resolution_start", field + " must be a nonblank String", {})
	if typeof(request["route_plan"]) != TYPE_ARRAY:
		return _fail(&"invalid_day_resolution_start", "route_plan must be an array", {})
	if typeof(request["resolution_issuer_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_day_resolution_start",
			"resolution_issuer_receipt must be a dictionary", {})
	var board_fate: Variant = request["board_fate_receipt"]
	if typeof(board_fate) != TYPE_DICTIONARY \
			or not _is_nonblank_string((board_fate as Dictionary).get("receipt_id")):
		return _fail(&"invalid_board_fate_receipt",
			"the bound board-fate receipt carries a nonblank receipt_id", {})

	# A bare Array, a partial dictionary, or any other synthetic stand-in dies here rather than
	# becoming an empty seed further down (Step 6.6).
	var validated: Dictionary = _STATE_SCHEMA.validate_aggregate(request["committed_schedule"])
	if not validated.get("ok", false):
		return validated
	var committed: Dictionary = (request["committed_schedule"] as Dictionary).duplicate(true)
	var source_day: int = int(committed["day"])
	if source_day < _STATE_SCHEMA.FIRST_DAY or source_day > _STATE_SCHEMA.LAST_DAY:
		return _fail(&"invalid_day_resolution_start", "no source day outside 1..7 may start",
			{"source_day": source_day})
	if typeof(committed["commit_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_day_resolution_start",
			"a receiptless aggregate may not start a resolution", {})
	var commit_receipt: Dictionary = committed["commit_receipt"]
	# DEVIATION-18 Ruling 18-A (dwm-oyo.3, 2026-09-02), safety half: the consumed-interface lock
	# says a start rejects "a different causal day" -- the request's day instance must be the
	# committed Schedule's own saved instance, so a caller can never re-day a saved commit.
	if str(request["causal_day_instance"]) != str(commit_receipt.get("causal_day_instance", "")):
		return _fail(&"day_resolution_causal_day_mismatch",
			"the request causal_day_instance is not the committed Schedule's own",
			{"requested": str(request["causal_day_instance"]),
				"committed": str(commit_receipt.get("causal_day_instance", ""))})

	# The SAVED fingerprint is the truth; a caller's current registry record is never a replacement.
	if str(committed["registry_fingerprint"]) != str(_action_registry.call(&"fingerprint")):
		return _fail(&"day_resolution_registry_fingerprint_mismatch",
			"the saved fingerprint does not resolve through the configured registry", {})
	var revalidated := _revalidate_entries(committed)
	if not revalidated.is_empty():
		return revalidated

	var root_receipt: Dictionary = request["resolution_issuer_receipt"]
	var verified: Variant = _identity_issuer.call(&"verify_issued", root_receipt.duplicate(true),
		ROOT_PURPOSE)
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _fail(&"day_resolution_root_unverified",
			"the resolution issuer receipt did not verify", {})
	# DEVIATION-18 Ruling 18-A (dwm-oyo.3, 2026-09-02), safety half: the lock fixes
	# `resolution_id == resolution_issuer_receipt.token`, so a second identity may never ride the
	# verified root (the Task-4 commit port's schedule_transaction_id_mismatch precedent).
	if str(root_receipt.get("token", "")) != str(request["resolution_id"]):
		return _fail(&"day_resolution_id_mismatch",
			"resolution_id must equal the issued token",
			{"resolution_id": str(request["resolution_id"])})

	var derived := _derive_start(request, committed, commit_receipt, board_fate as Dictionary)
	if not derived.get("ok", false):
		return derived
	var child: Dictionary = derived["value"]
	var start_receipt: Dictionary = {
		"receipt_id": str(child["child_id"]),
		"receipt_provenance": (child["provenance"] as Dictionary).duplicate(true),
		"resolution_id": str(request["resolution_id"]),
		"causal_day_instance": str(request["causal_day_instance"]),
		"source_day": source_day,
		"schedule_commit_receipt_id": str(commit_receipt["receipt_id"]),
		"board_fate_receipt_id": str((board_fate as Dictionary)["receipt_id"]),
		"schedule_entry_ids": (commit_receipt["schedule_entry_ids"] as Array).duplicate(true),
	}
	var keys: Array = start_receipt.keys()
	keys.sort()
	if keys != START_RECEIPT_KEYS:
		return _fail(&"invalid_day_resolution_start",
			"the start receipt member set is not exact", {})
	return {
		"ok": true, "code": &"ok",
		"value": {
			"start_receipt": start_receipt.duplicate(true),
			"committed_schedule": committed.duplicate(true),
			"route_plan": (request["route_plan"] as Array).duplicate(true),
			"schedule_commit_receipt_id": str(commit_receipt["receipt_id"]),
			"board_fate_receipt_id": str((board_fate as Dictionary)["receipt_id"]),
		},
		"receipt": start_receipt.duplicate(true),
	}


## Every committed entry must still name a registered action under the SAVED fingerprint. Returns
## {} when the aggregate is clean.
func _revalidate_entries(committed: Dictionary) -> Dictionary:
	var previous_slot: int = -1
	for entry_value: Variant in (committed["entries"] as Array):
		var entry: Dictionary = entry_value
		var found: Variant = _action_registry.call(&"find_record", str(entry["action_id"]))
		if typeof(found) != TYPE_DICTIONARY or not (found as Dictionary).get("ok", false):
			return _fail(&"day_resolution_entry_unregistered",
				"a committed entry no longer resolves through the saved registry",
				{"action_id": entry["action_id"]})
		var slot_index: int = int(entry["slot_index"])
		if slot_index <= previous_slot:
			return _fail(&"day_resolution_entry_order_invalid",
				"committed entries must ascend by slot_index", {"slot_index": slot_index})
		previous_slot = slot_index
	return {}


## Builds the exact plan-line-92 projection and derives the reserved start child.
func _derive_start(request: Dictionary, committed: Dictionary, commit_receipt: Dictionary,
		board_fate: Dictionary) -> Dictionary:
	var committed_hash := _sha256(committed)
	var route_hash := _sha256(request["route_plan"])
	var board_hash := _sha256(board_fate)
	if committed_hash.is_empty() or route_hash.is_empty() or board_hash.is_empty():
		return _fail(&"invalid_day_resolution_start",
			"a bound input is not canonically hashable", {})
	var tokens: Array = [
		_project("role", START_ROLE),
		_project("resolution_id", str(request["resolution_id"])),
		_project("causal_day_instance", str(request["causal_day_instance"])),
		_project("source_day", int(committed["day"])),
		_project("registry_fingerprint", str(committed["registry_fingerprint"])),
		_project("schedule_commit_receipt_id", str(commit_receipt["receipt_id"])),
		_project("board_fate_receipt_id", str(board_fate["receipt_id"])),
		_project("schedule_entry_ids", commit_receipt["schedule_entry_ids"]),
		_project("committed_schedule_sha256", committed_hash),
		_project("route_plan_sha256", route_hash),
		_project("board_fate_receipt_sha256", board_hash),
	]
	for token: String in tokens:
		if token.is_empty():
			return _fail(&"invalid_day_resolution_start",
				"the start row is not canonically projectable", {})
	tokens.sort()
	return _derive_child(
		str((request["resolution_issuer_receipt"] as Dictionary)["receipt_id"]), tokens)


## The same four independent checks the Task-4 commit port performs.
func _derive_child(parent_receipt_id: String, sources: Array) -> Dictionary:
	var derived: Variant = _identity_issuer.call(&"derive_child", {
		"parent_receipt_id": parent_receipt_id,
		"child_kind": START_CHILD_KIND,
		"ordinal": RESERVED_START_ORDINAL,
		"source_ids": sources.duplicate(true),
	})
	if typeof(derived) != TYPE_DICTIONARY or not (derived as Dictionary).get("ok", false):
		return _fail(&"day_resolution_identity_unavailable",
			"the issuer refused the start derivation",
			{"cause": (derived as Dictionary).get("code", &"") if typeof(derived) == TYPE_DICTIONARY else &"invalid_result"})
	var value: Variant = (derived as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("provenance")) != TYPE_DICTIONARY \
			or not _is_nonblank_string((value as Dictionary).get("child_id")):
		return _fail(&"day_resolution_identity_unavailable",
			"the issuer returned no full provenance", {})
	var provenance: Dictionary = (value as Dictionary)["provenance"]
	if (derived as Dictionary).get("receipt") != provenance:
		return _fail(&"day_resolution_identity_unavailable",
			"the issuer receipt is not byte-equal to its provenance", {})
	if str(provenance.get("child_id", "")) != str((value as Dictionary)["child_id"]):
		return _fail(&"day_resolution_identity_unavailable",
			"the derived identity disagrees with its provenance", {})
	var revalidated: Variant = _identity_issuer.call(&"validate_child", provenance,
		START_CHILD_KIND)
	if typeof(revalidated) != TYPE_DICTIONARY or not (revalidated as Dictionary).get("ok", false):
		return _fail(&"day_resolution_identity_unavailable",
			"the issuer refused to revalidate its own child", {})
	return _ok({"child_id": str((value as Dictionary)["child_id"]), "provenance": provenance})


# ---- the reversible half (Step 6.2) ----

## Narrow backup of exactly the state a start may change. Delegated to the retained state port
## rather than reimplemented here: two modules owning the same rollback shape is how a rollback
## quietly stops restoring one of the fields it used to.
func capture() -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	return _state_port.call(&"capture")


## SILENT narrow commit. It installs the prepared lifecycle and emits nothing: publication is the
## only start signal (Step 6.2), so a caller that commits and never publishes has changed durable
## state without announcing it, which is exactly the ordering crash recovery depends on.
func commit(candidate: Dictionary) -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	if typeof(candidate) != TYPE_DICTIONARY:
		return _fail(&"invalid_day_resolution_start_candidate",
			"the candidate must be a dictionary", {})
	return _state_port.call(&"commit", candidate)


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	if typeof(backup) != TYPE_DICTIONARY:
		return _fail(&"invalid_day_resolution_start_backup", "the backup must be a dictionary", {})
	return _state_port.call(&"rollback", backup)


## Records durably BEFORE emitting, then signals at most once (Step 6.2).
##
## The ledger is the restart proof, never an in-memory flag: after a crash the reconstructed port
## replays the same semantic receipt, the ledger reports this is not the first delivery, and the
## byte-identical success is returned with NO second signal. Mutated bytes at the same semantic key
## are a conflict rather than a silent overwrite.
func publish(publication: Dictionary) -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	# The publication member set is FROZEN BY THE LEDGER, not by this port: Task 4 already declared
	# `day_resolution_start` with members {day_resolution_start_receipt, resolution_plan} and binds
	# the semantic receipt to the first of them. Inventing a shape here would simply be rejected.
	if typeof(publication) != TYPE_DICTIONARY \
			or typeof(publication.get("day_resolution_start_receipt")) != TYPE_DICTIONARY \
			or not publication.has("resolution_plan"):
		return _fail(&"invalid_day_resolution_start_publication",
			"the publication carries its start receipt and resolution plan", {})
	var receipt: Dictionary = publication["day_resolution_start_receipt"]
	var hashed := _sha256(publication)
	if hashed.is_empty():
		return _fail(&"invalid_day_resolution_start_publication",
			"the publication is not canonically hashable", {})
	var recorded: Variant = _publication_ledger.call(&"record_before_emit", {
		"kind": PUBLICATION_KIND,
		"semantic_receipt": receipt.duplicate(true),
		"publication": publication.duplicate(true),
		"publication_sha256": hashed,
	})
	if typeof(recorded) != TYPE_DICTIONARY:
		return _fail(&"day_resolution_start_publication_unrecorded",
			"the publication ledger returned no CommandResult", {})
	if not (recorded as Dictionary).get("ok", false):
		if (recorded as Dictionary).get("code") == &"publication_record_conflict":
			return _fail(&"day_resolution_start_publication_conflict",
				"this start is already published with different bytes", {})
		return recorded
	if bool(((recorded as Dictionary)["value"] as Dictionary)["first_delivery"]):
		var signalled: Variant = _state_port.call(&"publish", {
			"transaction_id": str(receipt.get("resolution_id", "")),
			"signals": ["save_relevant_state_changed"],
		})
		if typeof(signalled) != TYPE_DICTIONARY or not (signalled as Dictionary).get("ok", false):
			return signalled if typeof(signalled) == TYPE_DICTIONARY \
				else _fail(&"day_resolution_start_publication_unrecorded",
					"the owner returned no CommandResult", {})
	return {
		"ok": true, "code": &"ok", "value": {"published": true},
		"receipt": receipt.duplicate(true),
	}


# ---- helpers ----

func _project(path: String, value: Variant) -> String:
	var canonical: Dictionary = _STATE_SCHEMA.canonical_json(value)
	if not canonical.get("ok", false):
		return ""
	return path + "=" + str((canonical["value"] as Dictionary)["text"])


func _sha256(value: Variant) -> String:
	var hashed: Dictionary = _STATE_SCHEMA.canonical_sha256(value)
	if not hashed.get("ok", false):
		return ""
	return str((hashed["value"] as Dictionary)["sha256"])


func _exact_keys(value: Dictionary, expected: Array[String]) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	if keys != expected:
		return _fail(&"invalid_day_resolution_start", "the request member set is not exact",
			{"expected": expected, "actual": keys})
	return {}


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	if target == null:
		return false
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true


static func _is_nonblank_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty()


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
