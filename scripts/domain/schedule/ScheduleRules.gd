class_name ScheduleRules
extends RefCounted

## Pure accepted-schema Schedule validation (Plan 01 Task 1, dwm-p2r.12).
##
## The registry is INJECTED. This module never reads DataCatalog, GameState, Contacts, scenes, or
## files, never mutates its inputs, and never charges motivation -- motivation is a commit-time
## fact owned by GameStateScheduleCommitPort.
##
## Draft validation and candidate validation are the SAME rule set: a candidate is accepted only by
## validating the prospective whole draft. That is what makes "Add accepted" imply "Done accepts",
## with existing-state failure surfacing before any candidate fault.
##
## Route, effects and cost are registry-derived. A caller-supplied route/effect/cost/unlock field is
## malformed input, never authority.
##
## Selectively reimplemented from quarantined evidence branch feat/p2r7-strict-schedule-validation
## (base 49947e5, tip 5e9ab64). Deliberately NOT ported: the nine-key caller route/effects shape,
## global duplicate action IDs, add-time motivation, Day-4 Priscilla placement, unlock/eligibility
## dictionaries, and date_completed proof.

## Exact draft entry keys (sorted). Anything more or less is malformed.
const DRAFT_KEYS: Array[String] = [
	"action_id", "action_kind", "day", "draft_entry_id", "participants", "slot_index",
	"source_receipt_id",
]
## Exact committed entry keys (sorted), including issuer child provenance.
const COMMITTED_KEYS: Array[String] = [
	"action_id", "action_kind", "commit_transaction_id", "day", "participants",
	"schedule_entry_id", "schedule_entry_provenance", "slot_index", "source_receipt_id", "state",
]
## Exact top-level committed aggregate keys (sorted).
const AGGREGATE_KEYS: Array[String] = [
	"commit_receipt", "day", "entries", "registry_fingerprint", "schema_version",
]
## Exact source receipt keys (sorted).
const SOURCE_KEYS: Array[String] = [
	"action_id", "day", "kind", "participants", "previous_receipt_id", "receipt_id",
	"receipt_provenance",
]

const ACTION_KINDS: Array[String] = ["ordinary", "solo", "group"]
const DATE_KINDS: Array[String] = ["solo", "group"]

const FIRST_DAY := 1
const LAST_DAY := 7
const ENDING_DAY := 7
## Days 1-6 expose exactly seven boxes at slots 0..6 and allow at most two dates.
const DAY_BOXES := 7
const MAX_DATES := 2
## The single Day-7 destination sits at slot zero; an empty Day-7 schedule is the legal Alone state.
const DAY7_SLOT := 0
const SCHEMA_VERSION := 1
const COMMITTED_STATE := "committed"


# ---- accepted public surface ----

static func validate_draft(day: int, entries: Array, registry: Object, expected_fingerprint: String,
		source_receipts: Dictionary) -> Dictionary:
	var guard := _guard_registry(day, registry, expected_fingerprint)
	if not guard.is_empty():
		return guard
	var normalized: Array[Dictionary] = []
	for raw: Variant in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			return _fail(&"invalid_draft_entry", "a draft entry must be a dictionary", {})
		var entry := raw as Dictionary
		var shape := _draft_shape_error(entry, day)
		if not shape.is_empty():
			return shape
		normalized.append(entry)
	var law := _validate_law(day, normalized, registry, source_receipts, false, true)
	if not law.is_empty():
		return law
	return _ok({"candidate": _detach(entries)})


static func validate_draft_candidate(day: int, existing: Array, candidate: Dictionary,
		registry: Object, expected_fingerprint: String, source_receipts: Dictionary) -> Dictionary:
	# Existing state is judged first, so a corrupt draft is never reported as a candidate fault.
	var existing_result := validate_draft(day, existing, registry, expected_fingerprint,
		source_receipts)
	if not existing_result.get("ok", false):
		return existing_result
	var prospective: Array = existing.duplicate()
	prospective.append(candidate)
	# Candidate success IS whole-draft success; there is no second, divergent rule set.
	var prospective_result := validate_draft(day, prospective, registry, expected_fingerprint,
		source_receipts)
	if not prospective_result.get("ok", false):
		return prospective_result
	return _ok({"candidate": _detach(candidate)})


static func validate_committed(committed_schedule: Dictionary, registry: Object,
		source_receipts: Dictionary) -> Dictionary:
	var structure := _committed_structure(committed_schedule, registry)
	if not structure.get("ok", false):
		return structure
	var day := int(committed_schedule["day"])
	var projected: Array[Dictionary] = (structure["value"] as Dictionary)["projected"]
	var law := _validate_law(day, projected, registry, source_receipts, true, true)
	if not law.is_empty():
		return law
	return _ok({"candidate": _detach(committed_schedule)})


static func build_route_plan(committed_schedule: Dictionary, registry: Object) -> Dictionary:
	# Transient projection recomputed from committed IDs plus the saved fingerprint. Never
	# persisted as a second authority, and never echoing a caller-supplied fact.
	var structure := _committed_structure(committed_schedule, registry)
	if not structure.get("ok", false):
		return structure
	var day := int(committed_schedule["day"])
	var projected: Array[Dictionary] = (structure["value"] as Dictionary)["projected"]
	var law := _validate_law(day, projected, registry, {}, true, false)
	if not law.is_empty():
		return law
	var routed: Array[Dictionary] = []
	if day != ENDING_DAY:
		# A Day-7 destination emits no physical route descriptor; its only output is the
		# provenance handoff owned by a later task.
		var ordered := projected.duplicate()
		ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return int(left["slot_index"]) < int(right["slot_index"]))
		for entry: Dictionary in ordered:
			var found := _record_for(registry, str(entry["action_id"]))
			if not found.get("ok", false):
				return found
			var record: Dictionary = (found["value"] as Dictionary)["record"]
			routed.append({
				"schedule_entry_id": str(entry["schedule_entry_id"]),
				"slot_index": int(entry["slot_index"]),
				"action_id": str(entry["action_id"]),
				"action_kind": str(record["action_kind"]),
				"participants": _detach(record["participants"]),
				"route_id": record["route_id"],
				"effect_ids": _detach(record["effect_ids"]),
			})
	return _ok({"route_plan": routed})


# ---- shared law ----

static func _guard_registry(day: int, registry: Object, expected_fingerprint: String) -> Dictionary:
	if typeof(day) != TYPE_INT or day < FIRST_DAY or day > LAST_DAY:
		return _fail(&"invalid_day", "day must be an int in %d..%d" % [FIRST_DAY, LAST_DAY],
			{"day": day})
	if registry == null or not registry.has_method("fingerprint") \
			or not registry.has_method("find_record"):
		return _fail(&"invalid_registry", "an injected registry is required", {})
	var actual := str(registry.fingerprint())
	if actual != expected_fingerprint:
		return _fail(&"stale_registry_fingerprint",
			"the registry no longer matches the expected fingerprint",
			{"expected": expected_fingerprint, "actual": actual})
	return {}


static func _validate_law(day: int, entries: Array, registry: Object, source_receipts: Dictionary,
		committed: bool, authenticate_sources: bool) -> Dictionary:
	var seen_entry_ids: Dictionary = {}
	var seen_slots: Dictionary = {}
	var seen_action_ids: Dictionary = {}
	var date_count: int = 0
	var group_participants: Array = []
	var solo_participants: Dictionary = {}
	var id_key := "schedule_entry_id" if committed else "draft_entry_id"
	var id_code := &"duplicate_schedule_entry_id" if committed else &"duplicate_draft_entry_id"
	for entry: Dictionary in entries:
		var entry_id := str(entry[id_key])
		if seen_entry_ids.has(entry_id):
			return _fail(id_code, "entry ids are unique within one schedule",
				{id_key: entry_id})
		seen_entry_ids[entry_id] = true
		var action_id := str(entry["action_id"])
		var found := _record_for(registry, action_id)
		if not found.get("ok", false):
			return found
		var record: Dictionary = (found["value"] as Dictionary)["record"]
		var parity := _registry_parity_error(entry, record, day)
		if not parity.is_empty():
			return parity
		var source := _source_error(entry, record, source_receipts, day, authenticate_sources)
		if not source.is_empty():
			return source
		if not bool(record["repeatable"]):
			if seen_action_ids.has(action_id):
				return _fail(&"action_not_repeatable",
					"this action may appear once per day", {"action_id": action_id})
			seen_action_ids[action_id] = true
		var slot := int(entry["slot_index"])
		if seen_slots.has(slot):
			return _fail(&"duplicate_slot_index", "a slot holds one entry",
				{"slot_index": slot})
		seen_slots[slot] = true
		var kind := str(entry["action_kind"])
		if kind in DATE_KINDS:
			date_count += 1
		if kind == "group":
			group_participants.append_array(entry["participants"] as Array)
		elif kind == "solo":
			for participant: Variant in entry["participants"] as Array:
				solo_participants[str(participant)] = true
	var structure := _day_structure_error(day, entries, date_count)
	if not structure.is_empty():
		return structure
	# A group date supersedes its participants' solos; they cannot coexist in one schedule.
	for participant: Variant in group_participants:
		if solo_participants.has(str(participant)):
			return _fail(&"superseded_solo_date",
				"a group date cannot coexist with its participants' solo dates",
				{"participant": str(participant)})
	return {}


static func _day_structure_error(day: int, entries: Array, date_count: int) -> Dictionary:
	if day == ENDING_DAY:
		# Empty is the legal Alone state; otherwise exactly one solo destination at slot zero.
		if entries.size() > 1:
			return _fail(&"too_many_entries", "Day 7 holds at most one entry",
				{"day": day, "entry_count": entries.size()})
		for entry: Dictionary in entries:
			if str(entry["action_kind"]) != "solo":
				return _fail(&"invalid_day7_entry", "Day 7 carries only a solo destination",
					{"action_kind": str(entry["action_kind"])})
			if int(entry["slot_index"]) != DAY7_SLOT:
				return _fail(&"invalid_day7_entry", "the Day-7 destination sits at slot zero",
					{"slot_index": int(entry["slot_index"])})
		return {}
	if entries.size() > DAY_BOXES:
		return _fail(&"too_many_entries", "Days 1-6 expose exactly %d boxes" % DAY_BOXES,
			{"day": day, "entry_count": entries.size(), "allowed": DAY_BOXES})
	for entry: Dictionary in entries:
		var slot := int(entry["slot_index"])
		if slot < 0 or slot >= DAY_BOXES:
			return _fail(&"invalid_slot_index", "Days 1-6 expose slots 0..%d" % (DAY_BOXES - 1),
				{"slot_index": slot})
	if date_count > MAX_DATES:
		return _fail(&"too_many_dates", "Days 1-6 allow at most %d dates" % MAX_DATES,
			{"day": day, "date_count": date_count, "allowed": MAX_DATES})
	return {}


static func _registry_parity_error(entry: Dictionary, record: Dictionary, day: int) -> Dictionary:
	var action_id := str(entry["action_id"])
	if day not in (record["allowed_days"] as Array):
		return _fail(&"action_not_allowed_on_day",
			"this action is not registered for this day",
			{"action_id": action_id, "day": day})
	if str(entry["action_kind"]) != str(record["action_kind"]):
		return _fail(&"draft_registry_mismatch",
			"the duplicated kind must reproduce the registry record",
			{"action_id": action_id, "field": "action_kind"})
	if not _same_sequence(entry["participants"] as Array, record["participants"] as Array):
		return _fail(&"draft_registry_mismatch",
			"participants must reproduce the registry record exactly, in canonical order",
			{"action_id": action_id, "field": "participants"})
	return {}


static func _source_error(entry: Dictionary, record: Dictionary, source_receipts: Dictionary,
		day: int, authenticate: bool) -> Dictionary:
	var action_id := str(entry["action_id"])
	var expected_kind: Variant = record["source_receipt_kind"]
	var source_id: Variant = entry["source_receipt_id"]
	if expected_kind == null:
		if source_id != null:
			return _fail(&"invalid_source_receipt",
				"an ordinary action carries no source receipt", {"action_id": action_id})
		return {}
	if typeof(source_id) != TYPE_STRING or str(source_id).is_empty():
		return _fail(&"invalid_source_receipt", "a date requires its acceptance receipt",
			{"action_id": action_id})
	if not authenticate:
		# build_route_plan is handed no receipt index, so it authenticates structure only. This is
		# an explicit mode, never inferred from an empty index -- inferring it would silently
		# accept an unresolvable source wherever a caller passed {}.
		return {}
	if not source_receipts.has(str(source_id)):
		return _fail(&"unresolved_source_receipt", "the source receipt does not resolve",
			{"source_receipt_id": str(source_id)})
	var raw: Variant = source_receipts[str(source_id)]
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail(&"invalid_source_receipt", "a source receipt must be a dictionary",
			{"source_receipt_id": str(source_id)})
	var receipt := raw as Dictionary
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != SOURCE_KEYS:
		return _fail(&"invalid_source_receipt",
			"a source receipt carries exactly " + str(SOURCE_KEYS),
			{"source_receipt_id": str(source_id)})
	if str(receipt["receipt_id"]) != str(source_id):
		return _fail(&"invalid_source_receipt", "the index key must equal receipt_id",
			{"source_receipt_id": str(source_id)})
	if str(receipt["kind"]) != str(expected_kind):
		return _fail(&"invalid_source_receipt", "the receipt kind must match the registry record",
			{"source_receipt_id": str(source_id), "kind": str(receipt["kind"])})
	if str(receipt["action_id"]) != action_id or int(receipt["day"]) != day:
		return _fail(&"invalid_source_receipt", "the receipt must name this action and day",
			{"source_receipt_id": str(source_id)})
	if not _same_sequence(receipt["participants"] as Array, entry["participants"] as Array):
		return _fail(&"invalid_source_receipt", "the receipt must name the same participants",
			{"source_receipt_id": str(source_id)})
	if str(receipt["previous_receipt_id"]).is_empty():
		return _fail(&"invalid_source_receipt", "an acceptance receipt names its offer",
			{"source_receipt_id": str(source_id)})
	return {}


# ---- shape ----

static func _draft_shape_error(entry: Dictionary, day: int) -> Dictionary:
	var keys: Array = entry.keys()
	keys.sort()
	if keys != DRAFT_KEYS:
		return _fail(&"invalid_draft_entry", "a draft entry carries exactly " + str(DRAFT_KEYS),
			{"draft_entry_id": str(entry.get("draft_entry_id", "")), "field": "keys"})
	var identity := _identity_error(entry, "draft_entry_id", &"invalid_draft_entry")
	if not identity.is_empty():
		return identity
	if int(entry["day"]) != day:
		return _fail(&"invalid_draft_entry", "entry day must equal the validated day",
			{"draft_entry_id": str(entry["draft_entry_id"]), "field": "day"})
	return {}


static func _identity_error(entry: Dictionary, id_key: String, code: StringName) -> Dictionary:
	var details := {id_key: str(entry.get(id_key, "")), "field": ""}
	for field: String in [id_key, "action_id", "action_kind"]:
		if typeof(entry[field]) != TYPE_STRING or str(entry[field]).is_empty():
			details["field"] = field
			return _fail(code, field + " must be a nonempty String", details)
	if str(entry["action_kind"]) not in ACTION_KINDS:
		details["field"] = "action_kind"
		return _fail(code, "action_kind must be one of " + str(ACTION_KINDS), details)
	for field: String in ["day", "slot_index"]:
		if typeof(entry[field]) != TYPE_INT:
			details["field"] = field
			return _fail(code, field + " must be a strict int, never coerced", details)
	if int(entry["slot_index"]) < 0:
		details["field"] = "slot_index"
		return _fail(code, "slot_index must be non-negative", details)
	if typeof(entry["participants"]) != TYPE_ARRAY:
		details["field"] = "participants"
		return _fail(code, "participants must be an array", details)
	for participant: Variant in entry["participants"] as Array:
		if typeof(participant) != TYPE_STRING or str(participant).is_empty():
			details["field"] = "participants"
			return _fail(code, "participant elements must be nonempty Strings", details)
	var source: Variant = entry["source_receipt_id"]
	if source != null and (typeof(source) != TYPE_STRING or str(source).is_empty()):
		details["field"] = "source_receipt_id"
		return _fail(code, "source_receipt_id is a nonempty String or null", details)
	return {}


static func _committed_structure(aggregate: Dictionary, registry: Object) -> Dictionary:
	if typeof(aggregate) != TYPE_DICTIONARY:
		return _fail(&"invalid_committed_schedule", "the aggregate must be a dictionary", {})
	var keys: Array = aggregate.keys()
	keys.sort()
	if keys != AGGREGATE_KEYS:
		return _fail(&"invalid_committed_schedule",
			"the aggregate carries exactly " + str(AGGREGATE_KEYS), {"field": "keys"})
	if int(aggregate["schema_version"]) != SCHEMA_VERSION:
		return _fail(&"invalid_committed_schedule", "unsupported schema_version",
			{"schema_version": aggregate["schema_version"]})
	var day_value: Variant = aggregate["day"]
	if typeof(day_value) != TYPE_INT or int(day_value) < FIRST_DAY or int(day_value) > LAST_DAY:
		return _fail(&"invalid_day", "day must be an int in %d..%d" % [FIRST_DAY, LAST_DAY],
			{"day": day_value})
	if typeof(aggregate["entries"]) != TYPE_ARRAY:
		return _fail(&"invalid_committed_schedule", "entries must be an array", {"field": "entries"})
	var entries: Array = aggregate["entries"]
	var receipt: Variant = aggregate["commit_receipt"]
	# RECONCILED IN TASK 5 (dwm-p2r.13). A receipt-backed EMPTY aggregate is LEGAL: it is the
	# `empty_schedule_done` Done commit that ScheduleStateSchema validates and that Task 6 route
	# projection must be able to carry. This module previously rejected that shape, which is why
	# Task 4 never routed a receipt-backed empty through here.
	if receipt != null and typeof(receipt) != TYPE_DICTIONARY:
		return _fail(&"invalid_committed_schedule",
			"the commit receipt is a dictionary or null", {"field": "commit_receipt"})
	if not entries.is_empty() and receipt == null:
		return _fail(&"invalid_committed_schedule",
			"a nonempty aggregate embeds its exact commit receipt", {"field": "commit_receipt"})
	# KNOWN RESIDUAL GAP, recorded rather than hidden. This module has no receipt-CONTENT law of its
	# own; before Task 5 that did not matter because the empty+receipt shape was unreachable here.
	# Widening the nullability rule makes it reachable, so `{entries: [], commit_receipt: <garbage>}`
	# with a matching fingerprint now passes this structural check while
	# ScheduleStateSchema.validate_aggregate still rejects it on its exact member set.
	#
	# It is NOT closed here on purpose: delegating to ScheduleStateSchema from this module -- by
	# preload or by global class_name -- forms a cyclic script dependency that makes both modules
	# fail to compile, which is a far worse failure than a latent permissive branch. No production
	# path reaches it today (GameStateScheduleCommitPort routes only NONEMPTY aggregates through
	# ScheduleRules, and every persisted aggregate is validated by ScheduleStateSchema first).
	# Task 6 owns route projection for the receipt-backed empty Day-7 case and should close this by
	# having its caller validate through ScheduleStateSchema before calling build_route_plan.
	if registry == null or not registry.has_method("fingerprint"):
		return _fail(&"invalid_registry", "an injected registry is required", {})
	var fingerprint: Variant = aggregate["registry_fingerprint"]
	if fingerprint == null:
		# Legal only for a migrated empty aggregate.
		if not entries.is_empty() or receipt != null:
			return _fail(&"invalid_committed_schedule",
				"only a migrated empty aggregate may omit the registry fingerprint",
				{"field": "registry_fingerprint"})
	elif typeof(fingerprint) != TYPE_STRING or str(fingerprint) != str(registry.fingerprint()):
		return _fail(&"stale_registry_fingerprint",
			"the saved fingerprint no longer matches the registry",
			{"expected": str(registry.fingerprint()), "actual": str(fingerprint)})
	var projected: Array[Dictionary] = []
	for raw: Variant in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			return _fail(&"invalid_committed_entry", "a committed entry must be a dictionary", {})
		var entry := raw as Dictionary
		var entry_keys: Array = entry.keys()
		entry_keys.sort()
		if entry_keys != COMMITTED_KEYS:
			return _fail(&"invalid_committed_entry",
				"a committed entry carries exactly " + str(COMMITTED_KEYS),
				{"schedule_entry_id": str(entry.get("schedule_entry_id", "")), "field": "keys"})
		var identity := _identity_error(entry, "schedule_entry_id", &"invalid_committed_entry")
		if not identity.is_empty():
			return identity
		if int(entry["day"]) != int(day_value):
			return _fail(&"invalid_committed_entry", "entry day must equal the aggregate day",
				{"schedule_entry_id": str(entry["schedule_entry_id"]), "field": "day"})
		if str(entry["state"]) != COMMITTED_STATE:
			return _fail(&"invalid_committed_entry", "a committed entry is in the committed state",
				{"schedule_entry_id": str(entry["schedule_entry_id"]), "field": "state"})
		if typeof(entry["schedule_entry_provenance"]) != TYPE_DICTIONARY \
				or (entry["schedule_entry_provenance"] as Dictionary).is_empty():
			return _fail(&"invalid_committed_entry", "a committed entry embeds its provenance",
				{"schedule_entry_id": str(entry["schedule_entry_id"]),
					"field": "schedule_entry_provenance"})
		if str(entry["commit_transaction_id"]).is_empty():
			return _fail(&"invalid_committed_entry", "a committed entry names its transaction",
				{"schedule_entry_id": str(entry["schedule_entry_id"]),
					"field": "commit_transaction_id"})
		projected.append(entry)
	return _ok({"projected": projected})


# ---- helpers ----

static func _record_for(registry: Object, action_id: String) -> Dictionary:
	var found: Dictionary = registry.find_record(action_id)
	if not found.get("ok", false):
		return _fail(&"unregistered_action", "only registered actions are schedulable",
			{"action_id": action_id})
	return found


static func _same_sequence(left: Array, right: Array) -> bool:
	# Order is semantic: the canonical Priscilla-Lavinia pair is not the same as its reverse.
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if str(left[index]) != str(right[index]):
			return false
	return true


static func _detach(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


# The provisional loose-shape date-candidate adapter and its legacy helpers retired here in Plan 01
# Task 5 (dwm-p2r.13), together with its last caller and its characterization tests, exactly as its
# own retirement note required. The registry is now the sole authority for day windows,
# participants, repeatability and date limits.
