class_name GameStateScheduleCommitPort
extends RefCounted

## The reversible committed-Schedule transaction port (Plan 01 Task 4, dwm-p2r.13).
##
## It owns the public transaction interface: prepare a detached, motivation-charging candidate;
## capture a narrow backup; commit it silently; roll exactly that back; publish it at most once.
## GameState supplies only five narrow delegation seams and is never a second validator.
##
## IDENTITY. Every committed identity comes from the injected production issuer through the exact
## Plan-01 child-derivation matrix: one `P01.schedule.entry` per committed entry whose ordinal is the
## zero-based validated slot-order index, then exactly one `P01.schedule.commit` (or
## `P01.schedule.empty_done` for zero entries) aggregate child. Nothing here mints an identity from
## a digest of its own, a caller field, a counter, a clock, or a number generator.
##
## OWNERSHIP. The port reads the registry only through the shipped `fingerprint()` / `find_record()`
## surface, reads Contacts source receipts only through `ContactInvitationState`'s pure queries, and
## touches no provisional Schedule transport: the v2 array, its add-time spend/refund and its date
## helpers are invisible here and gain no new caller. No draft array, warning latch, pending warning,
## UI add/remove/move, warning decision or desktop-board fate is created or persisted; Plan 03 owns
## the Schedule view, and Task 6 owns day resolution.

const _RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const _STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const _CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")

## Exact `prepare_commit()` request members (sorted).
const REQUEST_KEYS: Array[String] = [
	"causal_day_instance", "day", "draft_entries", "expected_view_fingerprint",
	"registry_fingerprint", "transaction_id", "transaction_issuer_receipt",
]
## Exact narrow candidate / backup / publication member sets (sorted).
const CANDIDATE_KEYS: Array[String] = ["before_fingerprint", "committed_schedule", "motivation"]
const BACKUP_KEYS: Array[String] = ["committed_schedule", "motivation"]
const PUBLICATION_KEYS: Array[String] = ["committed_schedule", "schedule_commit_receipt"]

const ROOT_PURPOSE := &"transaction_id"
const ENTRY_CHILD_KIND := &"schedule_entry"
const COMMIT_CHILD_KIND := &"schedule_commit"
const EMPTY_DONE_CHILD_KIND := &"empty_schedule_done"
const PUBLICATION_KIND := "schedule_commit"

const _GAME_STATE_METHODS: Array[String] = [
	"capture_schedule_commit_state", "prepare_schedule_commit_candidate",
	"commit_schedule_commit_candidate", "rollback_schedule_commit_state",
	"publish_schedule_commit",
]
const _REGISTRY_METHODS: Array[String] = ["fingerprint", "find_record"]
const _ISSUER_METHODS: Array[String] = ["verify_issued", "derive_child", "validate_child"]
const _LEDGER_METHODS: Array[String] = ["record_before_emit"]

var _game_state: Object = null
var _registry: Object = null
var _identity_issuer: Object = null
var _publication_ledger: Object = null
## transaction_id -> {request_sha256, prepared}. Same issued transaction plus byte-equal canonical
## request replays; changed bytes conflict. This is a same-process idempotency memo only; durable
## at-most-once observation belongs to the injected ledger.
var _prepared: Dictionary = {}


func _init(game_state: Object, action_registry: Object, identity_issuer: Object,
		publication_ledger: Object) -> void:
	_game_state = game_state
	_registry = action_registry
	_identity_issuer = identity_issuer
	_publication_ledger = publication_ledger


# ---- frozen public surface ----

func prepare_commit(request: Dictionary) -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	if typeof(request) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_commit_request", "the request must be a dictionary", {})
	var shape := _exact_keys(request, REQUEST_KEYS, &"invalid_schedule_commit_request")
	if not shape.is_empty():
		return shape
	for field: String in ["transaction_id", "expected_view_fingerprint", "causal_day_instance",
			"registry_fingerprint"]:
		if not _is_nonblank_string(request[field]):
			return _fail(&"invalid_schedule_commit_request", field + " must be a nonblank String",
				{"field": field})
	if typeof(request["day"]) != TYPE_INT:
		return _fail(&"invalid_schedule_commit_request", "day must be a strict int", {"field": "day"})
	if typeof(request["draft_entries"]) != TYPE_ARRAY:
		return _fail(&"invalid_schedule_commit_request", "draft_entries must be an array",
			{"field": "draft_entries"})
	if typeof(request["transaction_issuer_receipt"]) != TYPE_DICTIONARY \
			or (request["transaction_issuer_receipt"] as Dictionary).is_empty():
		return _fail(&"invalid_schedule_commit_request",
			"the full transaction issuer receipt is required",
			{"field": "transaction_issuer_receipt"})

	var transaction_id := str(request["transaction_id"])
	var issuer_receipt: Dictionary = (request["transaction_issuer_receipt"] as Dictionary).duplicate(true)
	var verified: Variant = _identity_issuer.call(&"verify_issued", issuer_receipt, ROOT_PURPOSE)
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _fail(&"invalid_schedule_transaction", "the issuer did not verify this root",
			{"cause": (verified as Dictionary).get("code", &"") if typeof(verified) == TYPE_DICTIONARY else &"invalid_result"})
	if str(issuer_receipt.get("token", "")) != transaction_id:
		return _fail(&"schedule_transaction_id_mismatch",
			"transaction_id must equal the issued token", {"transaction_id": transaction_id})

	var day := int(request["day"])
	var registry_fingerprint := str(request["registry_fingerprint"])
	if str(_registry.call(&"fingerprint")) != registry_fingerprint:
		return _fail(&"stale_registry_fingerprint",
			"the registry no longer matches the requested fingerprint",
			{"expected": registry_fingerprint})

	var owner_state := _owner_state()
	if not owner_state.get("ok", false):
		return owner_state
	var state: Dictionary = owner_state["value"]
	var current: Dictionary = state["committed_schedule"]
	if int(current["day"]) != day:
		return _fail(&"schedule_owner_state_stale",
			"the owner holds a canonical aggregate for another day",
			{"day": day, "owner_day": int(current["day"])})
	if current["commit_receipt"] != null \
			and str((current["commit_receipt"] as Dictionary)["transaction_id"]) != transaction_id:
		return _fail(&"schedule_already_committed",
			"this day already holds a committed aggregate from another transaction", {"day": day})

	var contacts: Variant = _contacts_state()
	if typeof(contacts) != TYPE_DICTIONARY:
		return _fail(&"schedule_source_index_unavailable",
			"the owner exposes no Contacts source receipt index", {})
	var sources: Variant = (contacts as Dictionary).get("schedule_source_receipts", {})
	if typeof(sources) != TYPE_DICTIONARY:
		return _fail(&"schedule_source_index_unavailable",
			"the Contacts source receipt index is malformed", {})

	var validated: Dictionary = _RULES.validate_draft(day, request["draft_entries"], _registry,
		registry_fingerprint, sources)
	if not validated.get("ok", false):
		return validated
	var ordered: Array = _slot_ordered((validated["value"] as Dictionary)["candidate"])
	var ancestry := _source_ancestry_error(ordered, contacts as Dictionary, day)
	if not ancestry.is_empty():
		return ancestry

	var motivation_charged := ordered.size()
	if int(state["motivation"]) < motivation_charged:
		return _fail(&"insufficient_motivation",
			"a commit charges exactly one motivation per entry",
			{"required": motivation_charged, "available": int(state["motivation"])})

	var request_hash := _sha256_of(request)
	if request_hash.is_empty():
		return _fail(&"invalid_schedule_commit_request",
			"the request is not canonically serializable", {})
	if _prepared.has(transaction_id):
		var memo: Dictionary = _prepared[transaction_id]
		if str(memo["request_sha256"]) != request_hash:
			return _fail(&"command_conflict",
				"this transaction was prepared with different bytes",
				{"transaction_id": transaction_id})
		return _prepared_result(memo["prepared"])

	var derived := _derive_committed_entries(request, ordered, issuer_receipt)
	if not derived.get("ok", false):
		return derived
	var entries: Array = (derived["value"] as Dictionary)["entries"]
	var entry_ids: Array = (derived["value"] as Dictionary)["schedule_entry_ids"]
	var source_ids: Array = (derived["value"] as Dictionary)["source_receipt_ids"]

	var aggregate_child := _derive_aggregate(request, ordered, issuer_receipt, entry_ids, source_ids)
	if not aggregate_child.get("ok", false):
		return aggregate_child
	var receipt := {
		"receipt_id": str((aggregate_child["value"] as Dictionary)["child_id"]),
		"receipt_provenance": ((aggregate_child["value"] as Dictionary)["provenance"] as Dictionary).duplicate(true),
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": issuer_receipt.duplicate(true),
		"day": day,
		"causal_day_instance": str(request["causal_day_instance"]),
		"registry_fingerprint": registry_fingerprint,
		"view_fingerprint": str(request["expected_view_fingerprint"]),
		"schedule_entry_ids": entry_ids.duplicate(true),
		"source_receipt_ids": source_ids.duplicate(true),
		"motivation_charged": motivation_charged,
	}
	var aggregate := {
		"schema_version": _STATE_SCHEMA.SCHEMA_VERSION,
		"day": day,
		"registry_fingerprint": registry_fingerprint,
		"entries": entries,
		"commit_receipt": receipt,
	}
	var schema_result: Dictionary = _STATE_SCHEMA.validate_aggregate(aggregate)
	if not schema_result.get("ok", false):
		return schema_result

	var route_plan: Array = []
	if not entries.is_empty():
		# ScheduleRules is the registry authority for a nonempty committed projection. A
		# receipt-backed EMPTY aggregate is validated by ScheduleStateSchema alone (see its header):
		# it projects no route, so there is nothing for the route builder to derive.
		var committed_check: Dictionary = _RULES.validate_committed(aggregate, _registry, sources)
		if not committed_check.get("ok", false):
			return committed_check
		var routed: Dictionary = _RULES.build_route_plan(aggregate, _registry)
		if not routed.get("ok", false):
			return routed
		route_plan = (routed["value"] as Dictionary)["route_plan"]

	var candidate_result: Variant = _game_state.call(&"prepare_schedule_commit_candidate",
		aggregate.duplicate(true), motivation_charged)
	if typeof(candidate_result) != TYPE_DICTIONARY \
			or not (candidate_result as Dictionary).get("ok", false):
		return candidate_result if typeof(candidate_result) == TYPE_DICTIONARY \
			else _fail(&"invalid_schedule_candidate", "the owner returned no CommandResult", {})
	var candidate: Dictionary = ((candidate_result as Dictionary)["value"] as Dictionary)["candidate"]

	var prepared := {
		"game_state_candidate": candidate.duplicate(true),
		"committed_schedule": aggregate.duplicate(true),
		"route_plan": route_plan.duplicate(true),
		"schedule_commit_receipt": receipt.duplicate(true),
	}
	_prepared[transaction_id] = {"request_sha256": request_hash, "prepared": prepared.duplicate(true)}
	return _prepared_result(prepared)


func capture() -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	var owner_state := _owner_state()
	if not owner_state.get("ok", false):
		return owner_state
	var state: Dictionary = owner_state["value"]
	return _ok({"backup": {
		"motivation": int(state["motivation"]),
		"committed_schedule": (state["committed_schedule"] as Dictionary).duplicate(true),
	}})


func commit(candidate: Dictionary) -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	if typeof(candidate) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_candidate", "the candidate must be a dictionary", {})
	var shape := _exact_keys(candidate, CANDIDATE_KEYS, &"invalid_schedule_candidate")
	if not shape.is_empty():
		return shape
	# A candidate this port prepared, then changed by its caller, is refused before the owner sees
	# it. The owner's own before_fingerprint still guards a stale precondition on every other path.
	var tamper := _candidate_tamper_error(candidate)
	if not tamper.is_empty():
		return tamper
	var committed: Variant = _game_state.call(&"commit_schedule_commit_candidate",
		candidate.duplicate(true))
	if typeof(committed) != TYPE_DICTIONARY or not (committed as Dictionary).get("ok", false):
		return committed if typeof(committed) == TYPE_DICTIONARY \
			else _fail(&"invalid_schedule_candidate", "the owner returned no CommandResult", {})
	var installed: Dictionary = ((committed as Dictionary)["value"] as Dictionary)["committed_schedule"]
	var receipt: Variant = installed.get("commit_receipt")
	return {
		"ok": true, "code": &"ok",
		"value": {"committed_schedule": installed.duplicate(true)},
		"receipt": (receipt as Dictionary).duplicate(true) if typeof(receipt) == TYPE_DICTIONARY else {},
	}


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	if typeof(backup) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_backup", "the backup must be a dictionary", {})
	var shape := _exact_keys(backup, BACKUP_KEYS, &"invalid_schedule_backup")
	if not shape.is_empty():
		return shape
	var restored: Variant = _game_state.call(&"rollback_schedule_commit_state",
		backup.duplicate(true))
	if typeof(restored) != TYPE_DICTIONARY or not (restored as Dictionary).get("ok", false):
		return restored if typeof(restored) == TYPE_DICTIONARY \
			else _fail(&"invalid_schedule_backup", "the owner returned no CommandResult", {})
	return _ok({"restored": true})


## Records the publication durably BEFORE the one declared observation signal. Either delivery
## returns the byte-identical success; only the first emits.
func publish(publication: Dictionary) -> Dictionary:
	var ready := _require_dependencies()
	if not ready.is_empty():
		return ready
	if typeof(publication) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_publication", "the publication must be a dictionary", {})
	var shape := _exact_keys(publication, PUBLICATION_KEYS, &"invalid_schedule_publication")
	if not shape.is_empty():
		return shape
	var receipt_value: Variant = publication["schedule_commit_receipt"]
	var receipt_result: Dictionary = _STATE_SCHEMA.validate_commit_receipt(receipt_value)
	if not receipt_result.get("ok", false):
		return receipt_result
	var aggregate_result: Dictionary = _STATE_SCHEMA.validate_aggregate(
		publication["committed_schedule"])
	if not aggregate_result.get("ok", false):
		return aggregate_result
	var aggregate: Dictionary = (aggregate_result["value"] as Dictionary)["committed_schedule"]
	if aggregate["commit_receipt"] != receipt_value:
		return _fail(&"invalid_schedule_publication",
			"the publication receipt must be the aggregate's own commit receipt", {})

	var owner_state := _owner_state()
	if not owner_state.get("ok", false):
		return owner_state
	if (owner_state["value"] as Dictionary)["committed_schedule"] != aggregate:
		return _fail(&"schedule_publication_state_mismatch",
			"a publication must equal the owner's current canonical state", {})

	var hashed: Dictionary = _STATE_SCHEMA.canonical_sha256(publication)
	if not hashed.get("ok", false):
		return hashed
	var recorded: Variant = _publication_ledger.call(&"record_before_emit", {
		"kind": PUBLICATION_KIND,
		"semantic_receipt": (receipt_value as Dictionary).duplicate(true),
		"publication": publication.duplicate(true),
		"publication_sha256": str((hashed["value"] as Dictionary)["sha256"]),
	})
	if typeof(recorded) != TYPE_DICTIONARY:
		return _fail(&"schedule_publication_unrecorded",
			"the publication ledger returned no CommandResult", {})
	if not (recorded as Dictionary).get("ok", false):
		if (recorded as Dictionary).get("code") == &"publication_record_conflict":
			return _fail(&"schedule_publication_conflict",
				"this receipt is already published with different bytes", {})
		return recorded
	if bool(((recorded as Dictionary)["value"] as Dictionary)["first_delivery"]):
		var published: Variant = _game_state.call(&"publish_schedule_commit",
			publication.duplicate(true))
		if typeof(published) != TYPE_DICTIONARY or not (published as Dictionary).get("ok", false):
			return published if typeof(published) == TYPE_DICTIONARY \
				else _fail(&"schedule_publication_unrecorded",
					"the owner returned no CommandResult", {})
	return {
		"ok": true, "code": &"ok", "value": {"published": true},
		"receipt": (receipt_value as Dictionary).duplicate(true),
	}


# ---- derivation ----

func _derive_committed_entries(request: Dictionary, ordered: Array,
		issuer_receipt: Dictionary) -> Dictionary:
	var entries: Array = []
	var entry_ids: Array = []
	var source_ids: Array = []
	for index: int in range(ordered.size()):
		var draft: Dictionary = ordered[index]
		var tokens := _entry_tokens(request, draft)
		if tokens.is_empty():
			return _fail(&"invalid_schedule_commit_request",
				"a draft entry is not canonically projectable", {"index": index})
		var derived := _derive_child(str(issuer_receipt["receipt_id"]), ENTRY_CHILD_KIND, index,
			tokens)
		if not derived.get("ok", false):
			return derived
		var child: Dictionary = derived["value"]
		entries.append({
			"schedule_entry_id": str(child["child_id"]),
			"schedule_entry_provenance": (child["provenance"] as Dictionary).duplicate(true),
			"day": int(draft["day"]),
			"slot_index": int(draft["slot_index"]),
			"action_id": str(draft["action_id"]),
			"action_kind": str(draft["action_kind"]),
			"participants": (draft["participants"] as Array).duplicate(true),
			"source_receipt_id": draft["source_receipt_id"],
			"commit_transaction_id": str(request["transaction_id"]),
			"state": _STATE_SCHEMA.COMMITTED_STATE,
		})
		entry_ids.append(str(child["child_id"]))
		source_ids.append(draft["source_receipt_id"])
	return _ok({"entries": entries, "schedule_entry_ids": entry_ids,
		"source_receipt_ids": source_ids})


func _derive_aggregate(request: Dictionary, ordered: Array, issuer_receipt: Dictionary,
		entry_ids: Array, source_ids: Array) -> Dictionary:
	var empty := ordered.is_empty()
	var preimage: Dictionary = _STATE_SCHEMA.canonical_sha256(ordered)
	if not preimage.get("ok", false):
		return preimage
	var tokens: Array = [
		_project("role", "schedule.empty_done" if empty else "schedule.commit"),
		_project("transaction_id", str(request["transaction_id"])),
		_project("view_fingerprint", str(request["expected_view_fingerprint"])),
		_project("day", int(request["day"])),
		_project("causal_day_instance", str(request["causal_day_instance"])),
		_project("registry_fingerprint", str(request["registry_fingerprint"])),
		_project("draft_entries_sha256", str((preimage["value"] as Dictionary)["sha256"])),
		_project("schedule_entry_ids", entry_ids),
		_project("source_receipt_ids", source_ids),
		_project("motivation_charged", ordered.size()),
	]
	for token: String in tokens:
		if token.is_empty():
			return _fail(&"invalid_schedule_commit_request",
				"the aggregate row is not canonically projectable", {})
	tokens.sort()
	return _derive_child(str(issuer_receipt["receipt_id"]),
		EMPTY_DONE_CHILD_KIND if empty else COMMIT_CHILD_KIND, 0, tokens)


func _entry_tokens(request: Dictionary, draft: Dictionary) -> Array:
	var tokens: Array = [
		_project("role", "schedule.entry"),
		_project("transaction_id", str(request["transaction_id"])),
		_project("view_fingerprint", str(request["expected_view_fingerprint"])),
		_project("causal_day_instance", str(request["causal_day_instance"])),
		_project("registry_fingerprint", str(request["registry_fingerprint"])),
		_project("draft_entry_id", str(draft["draft_entry_id"])),
		_project("day", int(draft["day"])),
		_project("slot_index", int(draft["slot_index"])),
		_project("action_id", str(draft["action_id"])),
		_project("action_kind", str(draft["action_kind"])),
		_project("participants", draft["participants"]),
		_project("source_receipt_id", draft["source_receipt_id"]),
	]
	for token: String in tokens:
		if token.is_empty():
			return []
	tokens.sort()
	return tokens


func _derive_child(parent_receipt_id: String, child_kind: StringName, ordinal: int,
		sources: Array) -> Dictionary:
	var derived: Variant = _identity_issuer.call(&"derive_child", {
		"parent_receipt_id": parent_receipt_id,
		"child_kind": child_kind,
		"ordinal": ordinal,
		"source_ids": sources.duplicate(true),
	})
	if typeof(derived) != TYPE_DICTIONARY or not (derived as Dictionary).get("ok", false):
		return _fail(&"schedule_identity_unavailable", "the issuer refused a child derivation",
			{"child_kind": String(child_kind), "ordinal": ordinal,
				"cause": (derived as Dictionary).get("code", &"") if typeof(derived) == TYPE_DICTIONARY else &"invalid_result"})
	var value: Variant = (derived as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("provenance")) != TYPE_DICTIONARY \
			or not _is_nonblank_string((value as Dictionary).get("child_id")):
		return _fail(&"schedule_identity_unavailable", "the issuer returned no full provenance",
			{"child_kind": String(child_kind)})
	var provenance: Dictionary = (value as Dictionary)["provenance"]
	if (derived as Dictionary).get("receipt") != provenance:
		return _fail(&"schedule_identity_unavailable",
			"the issuer receipt is not byte-equal to its provenance", {"child_kind": String(child_kind)})
	if str(provenance.get("child_id", "")) != str((value as Dictionary)["child_id"]):
		return _fail(&"schedule_identity_unavailable",
			"the derived identity disagrees with its provenance", {"child_kind": String(child_kind)})
	var revalidated: Variant = _identity_issuer.call(&"validate_child", provenance, child_kind)
	if typeof(revalidated) != TYPE_DICTIONARY or not (revalidated as Dictionary).get("ok", false):
		return _fail(&"schedule_identity_unavailable",
			"the derived child does not revalidate", {"child_kind": String(child_kind)})
	return _ok({"child_id": str((value as Dictionary)["child_id"]),
		"provenance": provenance.duplicate(true)})


# ---- owner and source access ----

func _owner_state() -> Dictionary:
	var captured: Variant = _game_state.call(&"capture_schedule_commit_state")
	if typeof(captured) != TYPE_DICTIONARY or not (captured as Dictionary).get("ok", false):
		return captured if typeof(captured) == TYPE_DICTIONARY \
			else _fail(&"schedule_owner_state_unavailable", "the owner returned no CommandResult", {})
	var value: Variant = (captured as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("committed_schedule")) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("motivation")) != TYPE_INT:
		return _fail(&"schedule_owner_state_unavailable",
			"the owner exposed no narrow committed-Schedule state", {})
	return _ok((value as Dictionary).duplicate(true))


func _contacts_state() -> Variant:
	var contacts: Variant = _game_state.get("contacts")
	if typeof(contacts) != TYPE_DICTIONARY:
		return null
	return (contacts as Dictionary).duplicate(true)


## Every committed date must resolve to its exact accepted/read receipt through the Contacts owner's
## own pure query, not merely to a structurally plausible index member.
func _source_ancestry_error(ordered: Array, contacts: Dictionary, day: int) -> Dictionary:
	for draft: Dictionary in ordered:
		var source_id: Variant = draft["source_receipt_id"]
		if source_id == null:
			continue
		var found: Dictionary = _registry.call(&"find_record", str(draft["action_id"]))
		if not found.get("ok", false):
			return _fail(&"unregistered_action", "only registered actions are schedulable",
				{"action_id": str(draft["action_id"])})
		var record: Dictionary = (found["value"] as Dictionary)["record"]
		var validated: Dictionary = _CONTACTS.validate_schedule_source_receipt(
			contacts, str(source_id), record, day)
		if not validated.get("ok", false):
			return _fail(&"invalid_source_ancestry",
				"the committed date does not resolve to its exact acceptance receipt",
				{"action_id": str(draft["action_id"]), "source_receipt_id": str(source_id),
					"cause": validated.get("code", &"")})
	return {}


# ---- helpers ----

func _require_dependencies() -> Dictionary:
	var missing: Array[String] = []
	if _game_state == null:
		missing.append("game_state")
	else:
		for method_name: String in _GAME_STATE_METHODS:
			if not _game_state.has_method(method_name):
				missing.append("game_state." + method_name)
	if _registry == null:
		missing.append("action_registry")
	else:
		for method_name: String in _REGISTRY_METHODS:
			if not _registry.has_method(method_name):
				missing.append("action_registry." + method_name)
	if _identity_issuer == null:
		missing.append("identity_issuer")
	else:
		for method_name: String in _ISSUER_METHODS:
			if not _identity_issuer.has_method(method_name):
				missing.append("identity_issuer." + method_name)
	if _publication_ledger == null:
		missing.append("publication_ledger")
	else:
		for method_name: String in _LEDGER_METHODS:
			if not _publication_ledger.has_method(method_name):
				missing.append("publication_ledger." + method_name)
	if missing.is_empty():
		return {}
	return _fail(&"schedule_commit_port_unconfigured",
		"the port requires its four exact dependencies", {"missing": missing})


func _candidate_tamper_error(candidate: Dictionary) -> Dictionary:
	var aggregate: Variant = candidate["committed_schedule"]
	if typeof(aggregate) != TYPE_DICTIONARY:
		return {}
	var receipt: Variant = (aggregate as Dictionary).get("commit_receipt")
	if typeof(receipt) != TYPE_DICTIONARY:
		return {}
	var transaction_id := str((receipt as Dictionary).get("transaction_id", ""))
	if not _prepared.has(transaction_id):
		return {}
	var memo: Dictionary = (_prepared[transaction_id] as Dictionary)["prepared"]
	if (memo["game_state_candidate"] as Dictionary) != candidate:
		return _fail(&"invalid_schedule_candidate",
			"this candidate was changed after prepare_commit issued it",
			{"transaction_id": transaction_id})
	return {}


func _slot_ordered(entries: Array) -> Array:
	var ordered: Array = entries.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["slot_index"]) < int(right["slot_index"]))
	return ordered


func _project(path: String, value: Variant) -> String:
	var canonical: Dictionary = _STATE_SCHEMA.canonical_json(value)
	if not canonical.get("ok", false):
		return ""
	return path + "=" + str((canonical["value"] as Dictionary)["text"])


func _sha256_of(value: Variant) -> String:
	var hashed: Dictionary = _STATE_SCHEMA.canonical_sha256(value)
	if not hashed.get("ok", false):
		return ""
	return str((hashed["value"] as Dictionary)["sha256"])


func _prepared_result(prepared: Dictionary) -> Dictionary:
	return {
		"ok": true, "code": &"ok", "value": prepared.duplicate(true),
		"receipt": (prepared["schedule_commit_receipt"] as Dictionary).duplicate(true),
	}


func _exact_keys(value: Dictionary, expected: Array[String], code: StringName) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	if keys != expected:
		return _fail(code, "the member set is exactly " + str(expected), {"members": keys})
	return {}


static func _is_nonblank_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty()


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details.duplicate(true)}
