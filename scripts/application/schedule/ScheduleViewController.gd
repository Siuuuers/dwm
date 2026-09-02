class_name ScheduleViewController
extends RefCounted

## The editable saved-ScheduleView owner (Amendment Plan 03 Task 2, dwm-oyo.3).
##
## Exact frozen 12-method surface from the plan (Task 2 Step 4). The controller derives
## kind, participants, repeatability and eligibility from the injected registry through
## ScheduleActionRegistry.lookup() at the configured fingerprint; every edit is validated
## through the injected ScheduleRules (validate_draft_candidate for adds -- existing-state
## failure wins before candidate failure -- and validate_draft for the prospective sets a
## move or remove produces). Drafting reserves and spends no motivation and never touches
## the canonical committed Schedule: this class holds no GameState reference at all.
##
## Adding any solo/group date latches date_entry_seen; removing the last date never clears
## it. open_day() replaces only the day-local editable/warning fields and preserves the
## append-only condition-departure receipt index. commit()/rollback() install ONLY the
## editable/warning fields of a validated same-day candidate/backup, so no edit path can
## ever mutate the ledger; the ledger changes exclusively through open_day() preservation
## and commit_condition_departure_transition()'s single-owner append, whose semantics are:
## an existing byte-identical entry returns unchanged without applying any view, live-before
## applies exactly once, live-after may adopt the receipt, and changed bytes or any third
## live state return a typed conflict without partial mutation.

const _VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## The day-local members commit/rollback/transition installs replace; the ledger is not
## among them by design.
const _EDITABLE_KEYS: Array = [
	"causal_day_instance", "consumed_warning_receipts", "date_entry_seen", "day", "entries",
	"pending_warning",
]
## Exact transition candidate keys (sorted), from the plan's Step 4 contract.
const _CONDITION_CANDIDATE_KEYS: Array = [
	"schedule_view_after", "schedule_view_before", "schedule_view_commit_receipt",
]

var _configured := false
var _registry: Object = null
var _rules: Object = null
var _fingerprint := ""
var _view: Dictionary = {}


func configure(action_registry: Object, schedule_rules: Object,
		registry_fingerprint: String) -> Dictionary:
	if action_registry == null or not action_registry.has_method("fingerprint") \
			or not action_registry.has_method("lookup") \
			or not action_registry.has_method("find_record"):
		return _fail(&"invalid_registry",
			"an injected registry with lookup(), find_record() and fingerprint() is required",
			{})
	if schedule_rules == null:
		return _fail(&"invalid_schedule_rules",
			"the injected ScheduleRules class object is required", {})
	if registry_fingerprint.is_empty():
		return _fail(&"invalid_expected_fingerprint",
			"a nonempty registry fingerprint is required", {})
	var actual := str(action_registry.fingerprint())
	if registry_fingerprint != actual:
		return _fail(&"stale_registry_fingerprint",
			"the registry no longer matches the expected fingerprint",
			{"expected": registry_fingerprint, "actual": actual})
	_registry = action_registry
	_rules = schedule_rules
	_fingerprint = registry_fingerprint
	_configured = true
	return _ok({"configured": true})


func open_day(day: int, causal_day_instance: String) -> Dictionary:
	var guard := _configured_guard()
	if not guard.is_empty():
		return guard
	var made: Dictionary = _VIEW_STATE.make_empty(day, causal_day_instance)
	if not made.get("ok", false):
		return made
	var opened: Dictionary = (made["value"] as Dictionary)["view"]
	if not _view.is_empty():
		opened["condition_departure_receipts"] = \
			(_view["condition_departure_receipts"] as Dictionary).duplicate(true)
	_view = opened
	return _ok({"view": _view.duplicate(true)})


func prepare_add(action_id: String, source_receipt_id: Variant, slot_index: int,
		draft_entry_id: String) -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	var found: Dictionary = _registry.lookup(action_id, _fingerprint)
	if not found.get("ok", false):
		return found
	var record: Dictionary = (found["value"] as Dictionary)["record"]
	var entry := {
		"draft_entry_id": draft_entry_id,
		"day": int(_view["day"]),
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": str(record["action_kind"]),
		"participants": (record["participants"] as Array).duplicate(true),
		"source_receipt_id": source_receipt_id,
	}
	var existing: Array = (_view["entries"] as Array).duplicate(true)
	var prospective: Array = existing.duplicate(true)
	prospective.append(entry.duplicate(true))
	var checked: Dictionary = _rules.validate_draft_candidate(int(_view["day"]), existing,
		entry, _registry, _fingerprint, _source_class_index(prospective))
	if not checked.get("ok", false):
		return checked
	var candidate := _view.duplicate(true)
	candidate["entries"] = prospective
	if str(record["action_kind"]) != "ordinary":
		candidate["date_entry_seen"] = true
	return _ok({"candidate": candidate})


func prepare_remove(draft_entry_id: String) -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	var remaining: Array = []
	var found := false
	for entry: Dictionary in _view["entries"] as Array:
		if str(entry["draft_entry_id"]) == draft_entry_id:
			found = true
			continue
		remaining.append(entry.duplicate(true))
	if not found:
		return _fail(&"draft_entry_not_found", "no draft entry carries this id",
			{"draft_entry_id": draft_entry_id})
	var checked: Dictionary = _rules.validate_draft(int(_view["day"]), remaining, _registry,
		_fingerprint, _source_class_index(remaining))
	if not checked.get("ok", false):
		return checked
	# date_entry_seen is a latch: removing the last date never clears it.
	var candidate := _view.duplicate(true)
	candidate["entries"] = remaining
	return _ok({"candidate": candidate})


func prepare_move(draft_entry_id: String, target_slot_index: int) -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	var moved: Array = []
	var found := false
	for entry: Dictionary in _view["entries"] as Array:
		var copy: Dictionary = entry.duplicate(true)
		if str(copy["draft_entry_id"]) == draft_entry_id:
			found = true
			copy["slot_index"] = target_slot_index
		moved.append(copy)
	if not found:
		return _fail(&"draft_entry_not_found", "no draft entry carries this id",
			{"draft_entry_id": draft_entry_id})
	var checked: Dictionary = _rules.validate_draft(int(_view["day"]), moved, _registry,
		_fingerprint, _source_class_index(moved))
	if not checked.get("ok", false):
		return checked
	var candidate := _view.duplicate(true)
	candidate["entries"] = moved
	return _ok({"candidate": candidate})


func snapshot() -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	return _ok({"view": _view.duplicate(true)})


func fingerprint() -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	return _VIEW_STATE.fingerprint(_view, _registry, _fingerprint)


func lookup_condition_departure_receipt(source_condition_receipt_id: String) -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	var ledger: Dictionary = _view["condition_departure_receipts"]
	if not ledger.has(source_condition_receipt_id):
		return _fail(&"condition_departure_receipt_not_found",
			"no retained receipt carries this source id",
			{"source_condition_receipt_id": source_condition_receipt_id})
	return _ok({"receipt": (ledger[source_condition_receipt_id] as Dictionary).duplicate(true)})


func commit_condition_departure_transition(candidate: Dictionary) -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	var keys: Array = candidate.keys()
	keys.sort()
	if keys != _CONDITION_CANDIDATE_KEYS:
		return _fail(&"invalid_condition_departure_candidate",
			"the candidate carries exactly " + str(_CONDITION_CANDIDATE_KEYS),
			{"field": "keys"})
	var receipt_error := _condition_receipt_error(candidate["schedule_view_commit_receipt"])
	if not receipt_error.is_empty():
		return receipt_error
	var receipt: Dictionary = candidate["schedule_view_commit_receipt"]
	var source_id := str(receipt["source_condition_receipt_id"])
	var ledger: Dictionary = _view["condition_departure_receipts"]
	if ledger.has(source_id):
		# An existing byte-identical entry returns unchanged without applying any view.
		if _same_bytes(ledger[source_id], receipt):
			return _ok({"receipt": (ledger[source_id] as Dictionary).duplicate(true)})
		return _conflict(source_id, "an occupied source id refuses changed bytes")
	if _same_bytes(_view, candidate["schedule_view_before"]):
		# Live-before applies exactly once: one owner mutation installs the after-view's
		# editable/warning fields and appends the receipt, preserving every earlier entry.
		var after_view: Dictionary = candidate["schedule_view_after"]
		var validated: Dictionary = _VIEW_STATE.validate(after_view, _registry, _fingerprint)
		if not validated.get("ok", false):
			return validated
		_install_editable(after_view)
		(_view["condition_departure_receipts"] as Dictionary)[source_id] = \
			receipt.duplicate(true)
		return _ok({"receipt": receipt.duplicate(true)})
	if _same_bytes(_view, candidate["schedule_view_after"]):
		# Live-after adopts the receipt without reapplying the view.
		(_view["condition_departure_receipts"] as Dictionary)[source_id] = \
			receipt.duplicate(true)
		return _ok({"receipt": receipt.duplicate(true)})
	return _conflict(source_id, "the live view matches neither the before nor the after view")


func capture() -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	return _ok({"backup": _view.duplicate(true)})


func commit(candidate: Dictionary) -> Dictionary:
	return _install_checked(candidate, &"invalid_view_candidate", "candidate")


func rollback(backup: Dictionary) -> Dictionary:
	return _install_checked(backup, &"invalid_view_backup", "backup")


# ---- internals ----

func _configured_guard() -> Dictionary:
	if not _configured:
		return _fail(&"not_configured", "configure() was never called", {})
	return {}


func _view_guard() -> Dictionary:
	var guard := _configured_guard()
	if not guard.is_empty():
		return guard
	if _view.is_empty():
		return _fail(&"day_not_open", "open_day() was never called", {})
	return {}


## Shared commit/rollback path: a full validated same-day view whose EDITABLE fields are
## installed; the live ledger is never replaced by either seam.
func _install_checked(source: Dictionary, code: StringName, label: String) -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	var validated: Dictionary = _VIEW_STATE.validate(source, _registry, _fingerprint)
	if not validated.get("ok", false):
		return validated
	if int(source["day"]) != int(_view["day"]) \
			or str(source["causal_day_instance"]) != str(_view["causal_day_instance"]):
		return _fail(code, "a %s belongs to the open day" % label, {
			"expected_day": int(_view["day"]),
			"actual_day": int(source["day"]),
		})
	_install_editable(source)
	return _ok({"view": _view.duplicate(true)})


func _install_editable(source: Dictionary) -> void:
	for key: String in _EDITABLE_KEYS:
		var member: Variant = source[key]
		if typeof(member) == TYPE_DICTIONARY:
			_view[key] = (member as Dictionary).duplicate(true)
		elif typeof(member) == TYPE_ARRAY:
			_view[key] = (member as Array).duplicate(true)
		else:
			_view[key] = member


## The same class-shaped receipt index ScheduleViewState fabricates: built from registry
## records resolved through lookup(), it degenerates the consumed ScheduleRules source law
## to the source-receipt CLASS check the view level owns. Malformed or unregistered entries
## are skipped so the delegated ScheduleRules pass reports them with its own typed codes.
func _source_class_index(entries: Array) -> Dictionary:
	var index: Dictionary = {}
	for raw: Variant in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry := raw as Dictionary
		var action_id: Variant = entry.get("action_id")
		var source_id: Variant = entry.get("source_receipt_id")
		var day: Variant = entry.get("day")
		if typeof(action_id) != TYPE_STRING or typeof(source_id) != TYPE_STRING \
				or str(source_id).is_empty() or typeof(day) != TYPE_INT:
			continue
		var found: Dictionary = _registry.lookup(str(action_id), _fingerprint)
		if not found.get("ok", false):
			continue
		var record: Dictionary = (found["value"] as Dictionary)["record"]
		if record["source_receipt_kind"] == null:
			continue
		index[str(source_id)] = {
			"receipt_id": str(source_id),
			"receipt_provenance": {"origin": "schedule_view_source_class_recheck"},
			"kind": str(record["source_receipt_kind"]),
			"action_id": str(action_id),
			"day": int(day),
			"participants": (record["participants"] as Array).duplicate(true),
			"previous_receipt_id": "schedule_view:offer_resolved_at_commit_port",
		}
	return index


func _condition_receipt_error(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail(&"invalid_condition_departure_receipt",
			"the commit receipt is a Dictionary", {"field": "schedule_view_commit_receipt"})
	# Reuse the view state's ledger value law byte-for-byte by probing a one-entry index
	# keyed the way the receipt names itself; a key/id mismatch is impossible here.
	var receipt := raw as Dictionary
	var source_id: Variant = receipt.get("source_condition_receipt_id")
	if typeof(source_id) != TYPE_STRING or str(source_id).is_empty():
		return _fail(&"invalid_condition_departure_receipt",
			"the receipt names a nonempty source_condition_receipt_id",
			{"field": "source_condition_receipt_id"})
	var probe: Dictionary = {str(source_id): receipt}
	var view := {
		"day": int(_view["day"]),
		"causal_day_instance": str(_view["causal_day_instance"]),
		"entries": [],
		"date_entry_seen": false,
		"pending_warning": null,
		"consumed_warning_receipts": {},
		"condition_departure_receipts": probe,
	}
	var validated: Dictionary = _VIEW_STATE.validate(view, _registry, _fingerprint)
	if not validated.get("ok", false):
		return validated
	return {}


func _same_bytes(left: Variant, right: Variant) -> bool:
	var left_text: Dictionary = _CANONICAL_JSON.stringify(left)
	var right_text: Dictionary = _CANONICAL_JSON.stringify(right)
	if not left_text.get("ok", false) or not right_text.get("ok", false):
		return false
	return str(left_text["value"]) == str(right_text["value"])


func _conflict(source_id: String, message: String) -> Dictionary:
	return _fail(&"condition_departure_receipt_conflict", message,
		{"source_condition_receipt_id": source_id})


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
