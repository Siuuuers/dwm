extends RefCounted

## Day-7 Schedule provenance handoff (Plan 01 Task 6, dwm-p2r.13, plan lines 462-505).
##
## One configured, MUTATION-FREE domain service. It is the only Day-7 output Plan 01 may create
## (plan line 505): it turns a committed Day-7 aggregate into exactly one issuer-anchored
## `terminal_provenance` for the later terminal-intent owner, and produces nothing else.
##
## FROZEN SURFACE (plan lines 464-469). Exactly `configure()` and `validate_handoff()`. Anything a
## caller needs beyond those two belongs to a different owner.
##
## WHY IT IS CONFIGURED RATHER THAN SELF-SERVING. Plan line 471 forbids reaching a global service
## locator, loading a mutable CURRENT registry as replacement truth, or preloading an issuer. The
## saved fingerprint is therefore resolved through the exact retained registry this service was
## configured with, and every identity comes from the exact retained production issuer. Configuring
## is idempotent for that same pair and refuses replacement, so a second owner cannot quietly
## re-point an already-wired service at different truth.
##
## WHAT IT DELIBERATELY DOES NOT CONTAIN (plan line 503). No friend alias, relationship tier or
## tone, Dark-mode flag, faint condition, ending ID, ordered ending step, presentation form, or
## playback state. Those belong to Amendment Plan 03 and the approved Seven-Day Plan 05.

const _STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

const CHILD_KIND := &"day7_schedule_provenance"
const ROOT_PURPOSE := &"transaction_id"
const DAY := 7
const CAUSE_EMPTY_DONE := "empty_done"
const CAUSE_SCHEDULED_SOLO := "scheduled_solo"
const SOLO_KIND := "solo"

## Exact `validate_handoff()` request members (sorted), plan lines 475-483.
const REQUEST_KEYS: Array[String] = [
	"causal_day_instance", "committed_schedule", "source_receipt_index", "transaction_id",
	"transaction_issuer_receipt",
]
## Exact `terminal_provenance` members (sorted), plan lines 487-501.
const TERMINAL_KEYS: Array[String] = [
	"action_id", "causal_day_instance", "cause", "day", "kind", "receipt_id",
	"receipt_provenance", "registry_fingerprint", "schedule_commit_receipt_id",
	"schedule_entry_id", "source_receipt_id",
]

const _REGISTRY_METHODS: Array[String] = ["fingerprint", "find_record"]
const _ISSUER_METHODS: Array[String] = ["verify_issued", "derive_child", "validate_child"]

var _action_registry: Object = null
var _identity_issuer: Object = null


## Retains the exact Schedule registry and production issuer. Idempotent for that same pair;
## a different object in either position is refused rather than adopted.
func configure(action_registry: Object, identity_issuer: Object) -> Dictionary:
	if not _has_methods(action_registry, _REGISTRY_METHODS):
		return _fail(&"invalid_action_registry", "the registry contract is incomplete", {})
	if not _has_methods(identity_issuer, _ISSUER_METHODS):
		return _fail(&"invalid_identity_issuer", "the issuer contract is incomplete", {})
	if _action_registry != null or _identity_issuer != null:
		if _action_registry == action_registry and _identity_issuer == identity_issuer:
			return _ok({"configured": true})
		return _fail(&"day7_provenance_already_configured",
			"a configured service never adopts a replacement dependency", {})
	_action_registry = action_registry
	_identity_issuer = identity_issuer
	return _ok({"configured": true})


## Derives exactly row `P01.schedule.day7_provenance` for the one Day-7 cause the request carries.
##
## Accepts ONLY a receipt-backed Day-7 empty commit, or exactly one registry-valid solo at slot zero
## whose `source_receipt_id` resolves to the accepted/read receipt in `source_receipt_index`
## (plan line 485). It performs no canonical mutation: every value it touches is duplicated before
## use and the returned receipt is a detached copy of `terminal_provenance`.
func validate_handoff(request: Dictionary) -> Dictionary:
	if _action_registry == null or _identity_issuer == null:
		return _fail(&"day7_provenance_unconfigured", "configure() has not run", {})
	if typeof(request) != TYPE_DICTIONARY:
		return _fail(&"invalid_day7_handoff", "the request must be a dictionary", {})
	var shape := _exact_keys(request, REQUEST_KEYS)
	if not shape.is_empty():
		return shape
	for field: String in ["transaction_id", "causal_day_instance"]:
		if not _is_nonblank_string(request[field]):
			return _fail(&"invalid_day7_handoff", field + " must be a nonblank String", {})
	if typeof(request["transaction_issuer_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_day7_handoff", "transaction_issuer_receipt must be a dictionary", {})
	if typeof(request["source_receipt_index"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_day7_handoff", "source_receipt_index must be a dictionary", {})

	var validated: Dictionary = _STATE_SCHEMA.validate_aggregate(request["committed_schedule"])
	if not validated.get("ok", false):
		return validated
	var committed: Dictionary = (request["committed_schedule"] as Dictionary).duplicate(true)
	if int(committed["day"]) != DAY:
		return _fail(&"invalid_day7_handoff", "only a Day-7 commit yields this handoff",
			{"day": committed["day"]})
	if typeof(committed["commit_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_day7_handoff",
			"a receiptless aggregate is not an accepted cause", {})
	var commit_receipt: Dictionary = committed["commit_receipt"]

	# The saved fingerprint is resolved through the CONFIGURED registry. A current registry loaded
	# here would let a later manifest silently re-bless an old commit (plan line 471).
	var saved_fingerprint: String = str(committed["registry_fingerprint"])
	if saved_fingerprint != str(_action_registry.call(&"fingerprint")):
		return _fail(&"day7_registry_fingerprint_mismatch",
			"the saved fingerprint does not resolve through the configured registry", {})

	# The request must carry the SAME verified transaction root the Schedule commit persisted
	# (plan line 503), so a caller cannot re-parent the handoff under a root of its own choosing.
	if str(request["transaction_id"]) != str(commit_receipt["transaction_id"]):
		return _fail(&"day7_transaction_mismatch",
			"the request transaction_id is not the commit's own", {})
	var root_receipt: Dictionary = request["transaction_issuer_receipt"]
	if root_receipt != commit_receipt["transaction_issuer_receipt"]:
		return _fail(&"day7_transaction_mismatch",
			"the request issuer receipt is not byte-equal to the commit's own", {})
	var verified: Variant = _identity_issuer.call(&"verify_issued", root_receipt.duplicate(true),
		ROOT_PURPOSE)
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _fail(&"day7_transaction_unverified",
			"the full transaction issuer receipt did not verify", {})

	var cause := _resolve_cause(committed, request["source_receipt_index"] as Dictionary)
	if not cause.get("ok", false):
		return cause
	var resolved: Dictionary = cause["value"]
	return _derive_terminal(request, committed, commit_receipt, resolved)


## Decides which of the two accepted causes the aggregate is, or refuses it. Returns
## value={cause, schedule_entry_id, action_id, source_receipt_id}, the trailing three null for
## `empty_done` and non-null for `scheduled_solo` (plan line 503).
func _resolve_cause(committed: Dictionary, source_index: Dictionary) -> Dictionary:
	var entries: Array = committed["entries"]
	if entries.is_empty():
		return _ok({
			"cause": CAUSE_EMPTY_DONE,
			"schedule_entry_id": null,
			"action_id": null,
			"source_receipt_id": null,
		})
	if entries.size() != 1:
		return _fail(&"invalid_day7_handoff",
			"Day 7 carries at most one committed entry", {"entries": entries.size()})
	var entry: Dictionary = entries[0]
	if str(entry["action_kind"]) != SOLO_KIND:
		return _fail(&"invalid_day7_handoff",
			"the only nonempty Day-7 cause is a solo", {"action_kind": entry["action_kind"]})
	if int(entry["slot_index"]) != _STATE_SCHEMA.DAY7_SLOT:
		return _fail(&"invalid_day7_handoff", "the Day-7 solo occupies slot zero",
			{"slot_index": entry["slot_index"]})
	var action_id: String = str(entry["action_id"])
	var found: Variant = _action_registry.call(&"find_record", action_id)
	if typeof(found) != TYPE_DICTIONARY or not (found as Dictionary).get("ok", false):
		return _fail(&"invalid_day7_handoff", "the solo action is not registry-valid",
			{"action_id": action_id})
	if not _is_nonblank_string(entry["source_receipt_id"]):
		return _fail(&"invalid_day7_handoff", "a committed solo carries a source receipt", {})
	var source_receipt_id: String = str(entry["source_receipt_id"])
	if not source_index.has(source_receipt_id) \
			or typeof(source_index[source_receipt_id]) != TYPE_DICTIONARY:
		return _fail(&"day7_source_receipt_unresolved",
			"the solo's source_receipt_id does not resolve in source_receipt_index",
			{"source_receipt_id": source_receipt_id})
	return _ok({
		"cause": CAUSE_SCHEDULED_SOLO,
		"schedule_entry_id": str(entry["schedule_entry_id"]),
		"action_id": action_id,
		"source_receipt_id": source_receipt_id,
	})


## Builds the exact plan-line-91 projection, derives the child through the configured issuer, and
## assembles `terminal_provenance`. The row's own ID never appears in its own projection.
func _derive_terminal(request: Dictionary, committed: Dictionary, commit_receipt: Dictionary,
		resolved: Dictionary) -> Dictionary:
	var tokens: Array = [
		_project("role", "schedule.day7_provenance"),
		_project("transaction_id", str(request["transaction_id"])),
		_project("causal_day_instance", str(request["causal_day_instance"])),
		_project("day", DAY),
		_project("cause", str(resolved["cause"])),
		_project("registry_fingerprint", str(committed["registry_fingerprint"])),
		_project("schedule_commit_receipt_id", str(commit_receipt["receipt_id"])),
		_project("schedule_entry_id", resolved["schedule_entry_id"]),
		_project("action_id", resolved["action_id"]),
		_project("source_receipt_id", resolved["source_receipt_id"]),
	]
	for token: String in tokens:
		if token.is_empty():
			return _fail(&"invalid_day7_handoff", "the handoff row is not canonically projectable",
				{})
	tokens.sort()
	var parent_receipt_id: String = str(
		(commit_receipt["transaction_issuer_receipt"] as Dictionary)["receipt_id"])
	var derived := _derive_child(parent_receipt_id, tokens)
	if not derived.get("ok", false):
		return derived
	var child: Dictionary = derived["value"]
	var terminal: Dictionary = {
		"receipt_id": str(child["child_id"]),
		"receipt_provenance": (child["provenance"] as Dictionary).duplicate(true),
		"kind": String(CHILD_KIND),
		"causal_day_instance": str(request["causal_day_instance"]),
		"day": DAY,
		"cause": str(resolved["cause"]),
		"registry_fingerprint": str(committed["registry_fingerprint"]),
		"schedule_commit_receipt_id": str(commit_receipt["receipt_id"]),
		"schedule_entry_id": resolved["schedule_entry_id"],
		"action_id": resolved["action_id"],
		"source_receipt_id": resolved["source_receipt_id"],
	}
	var keys: Array = terminal.keys()
	keys.sort()
	if keys != TERMINAL_KEYS:
		return _fail(&"invalid_day7_handoff", "the terminal provenance member set is not exact", {})
	return {
		"ok": true, "code": &"ok",
		"value": {"terminal_provenance": terminal.duplicate(true)},
		"receipt": terminal.duplicate(true),
	}


## The same four independent checks the Task-4 commit port performs, for the same reason: an issuer
## that returned a child whose provenance disagreed with it would otherwise mint an unanchored ID.
func _derive_child(parent_receipt_id: String, sources: Array) -> Dictionary:
	var derived: Variant = _identity_issuer.call(&"derive_child", {
		"parent_receipt_id": parent_receipt_id,
		"child_kind": CHILD_KIND,
		"ordinal": 0,
		"source_ids": sources.duplicate(true),
	})
	if typeof(derived) != TYPE_DICTIONARY or not (derived as Dictionary).get("ok", false):
		return _fail(&"day7_identity_unavailable", "the issuer refused the handoff derivation",
			{"cause": (derived as Dictionary).get("code", &"") if typeof(derived) == TYPE_DICTIONARY else &"invalid_result"})
	var value: Variant = (derived as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("provenance")) != TYPE_DICTIONARY \
			or not _is_nonblank_string((value as Dictionary).get("child_id")):
		return _fail(&"day7_identity_unavailable", "the issuer returned no full provenance", {})
	var provenance: Dictionary = (value as Dictionary)["provenance"]
	if (derived as Dictionary).get("receipt") != provenance:
		return _fail(&"day7_identity_unavailable",
			"the issuer receipt is not byte-equal to its provenance", {})
	if str(provenance.get("child_id", "")) != str((value as Dictionary)["child_id"]):
		return _fail(&"day7_identity_unavailable",
			"the derived identity disagrees with its provenance", {})
	var revalidated: Variant = _identity_issuer.call(&"validate_child", provenance, CHILD_KIND)
	if typeof(revalidated) != TYPE_DICTIONARY or not (revalidated as Dictionary).get("ok", false):
		return _fail(&"day7_identity_unavailable",
			"the issuer refused to revalidate its own child", {})
	return _ok({"child_id": str((value as Dictionary)["child_id"]), "provenance": provenance})


# ---- helpers ----

func _project(path: String, value: Variant) -> String:
	var canonical: Dictionary = _STATE_SCHEMA.canonical_json(value)
	if not canonical.get("ok", false):
		return ""
	return path + "=" + str((canonical["value"] as Dictionary)["text"])


func _exact_keys(value: Dictionary, expected: Array[String]) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	if keys != expected:
		return _fail(&"invalid_day7_handoff", "the request member set is not exact",
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
