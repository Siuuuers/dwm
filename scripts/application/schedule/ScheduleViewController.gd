class_name ScheduleViewController
extends RefCounted

## The editable saved-ScheduleView owner (Amendment Plan 03 Task 2, dwm-oyo.3).
##
## Exact frozen 12-method surface from the plan (Task 2 Step 4), the Task-3 warning surface
## (see the derived-surface note above the warning methods), and the synchronous UI docket-edit
## seam. The controller derives
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
## live state return a typed conflict without partial mutation. install_restored_view() is the
## single restore-only path that DOES replace the ledger, so that no-edit-path-mutates-it
## guarantee holds for every edit path.

const _VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _WARNING_POLICY := preload("res://scripts/domain/schedule/ScheduleWarningPolicy.gd")

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
var _warning_identity: Object = null
var _warning_identity_configured := false


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
	return _prepare_add_on_view(_view, action_id, source_receipt_id, slot_index, draft_entry_id)


func _prepare_add_on_view(view: Dictionary, action_id: String, source_receipt_id: Variant,
		slot_index: int, draft_entry_id: String) -> Dictionary:
	var found: Dictionary = _registry.lookup(action_id, _fingerprint)
	if not found.get("ok", false):
		return found
	var record: Dictionary = (found["value"] as Dictionary)["record"]
	var entry := {
		"draft_entry_id": draft_entry_id,
		"day": int(view["day"]),
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": str(record["action_kind"]),
		"participants": (record["participants"] as Array).duplicate(true),
		"source_receipt_id": source_receipt_id,
	}
	var existing: Array = (view["entries"] as Array).duplicate(true)
	var prospective: Array = existing.duplicate(true)
	prospective.append(entry.duplicate(true))
	var checked: Dictionary = _rules.validate_draft_candidate(int(view["day"]), existing,
		entry, _registry, _fingerprint, _source_class_index(prospective))
	if not checked.get("ok", false):
		return checked
	var candidate := view.duplicate(true)
	candidate["entries"] = prospective
	if str(record["action_kind"]) != "ordinary":
		candidate["date_entry_seen"] = true
	return _ok({"candidate": candidate})


func apply_docket_edit(command: Dictionary, expected_fingerprint: String) -> Dictionary:
	# fingerprint() already guards and validates the complete live view.
	var current_fingerprint: Dictionary = fingerprint()
	if not current_fingerprint.get("ok", false):
		return current_fingerprint
	var actual := str((current_fingerprint["value"] as Dictionary)["fingerprint"])
	if expected_fingerprint.is_empty() or expected_fingerprint != actual:
		return _fail(&"stale_view_fingerprint", "the live Schedule view has changed",
			{"expected": expected_fingerprint, "actual": actual})
	if _view["pending_warning"] != null:
		return _fail(&"warning_modal_active", "docket edits are refused while a warning is open", {})

	var shape := _docket_command_error(command)
	if not shape.is_empty():
		return shape
	var kind := str(command["kind"])
	var ordered := _packed_entries(_view["entries"] as Array)
	_reindex(ordered)
	match kind:
		"move":
			if int(_view["day"]) == 7:
				return _fail(&"day7_move_refused", "the single Day-7 destination cannot move", {})
			var target := int(command["target_index"])
			if target < 0 or target >= ordered.size():
				return _fail(&"invalid_target_index", "target_index names a current ordinal", {})
			var move_source := _entry_ordinal(ordered, str(command["draft_entry_id"]))
			if move_source < 0:
				return _fail(&"draft_entry_not_found", "no draft entry carries this id", {})
			if move_source == target:
				# The accepted same-position operation is strictly a no-change, including
				# legacy sparse views. A presentation host must reject sparse input before
				# mounting; this command is not an implicit save migration.
				return _ok({"view": _view.duplicate(true)})
			var moved: Dictionary = ordered.pop_at(move_source)
			ordered.insert(target, moved)
			_reindex(ordered)
			return _commit_entries(ordered)
		"remove":
			var remove_source := _entry_ordinal(ordered, str(command["draft_entry_id"]))
			if remove_source < 0:
				return _fail(&"draft_entry_not_found", "no draft entry carries this id", {})
			ordered.remove_at(remove_source)
			_reindex(ordered)
			return _commit_entries(ordered)
		"append":
			if int(_view["day"]) == 7 and not ordered.is_empty():
				var current: Dictionary = ordered[0]
				if current["action_id"] == command["action_id"] \
						and current["source_receipt_id"] == command["source_receipt_id"]:
					return _ok({"view": _view.duplicate(true)})
				ordered.clear()
			var base := _view.duplicate(true)
			base["entries"] = ordered
			var prepared := _prepare_add_on_view(base, str(command["action_id"]),
				command["source_receipt_id"], ordered.size(), str(command["draft_entry_id"]))
			if not prepared.get("ok", false):
				return prepared
			return commit((prepared["value"] as Dictionary)["candidate"])
	return _fail(&"invalid_docket_command", "unsupported docket command", {})


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


## The restore-only whole-view installer (Amendment Plan 03 Task 4, dwm-oyo.3). Unlike
## commit()/rollback(), which install only _EDITABLE_KEYS onto an already-open SAME day, a restored
## view carries its own day, its own causal identity, and its own append-only ledger, so this
## replaces every one of ScheduleViewState.VIEW_KEYS. Requires configure(); does NOT require
## open_day() -- a restore is what opens the day.
func install_restored_view(view: Variant) -> Dictionary:
	var guard := _configured_guard()
	if not guard.is_empty():
		return guard
	# A null capture represents the state before the first day was opened.
	if view == null:
		_view = {}
		return _ok({"view": null})
	if typeof(view) != TYPE_DICTIONARY:
		return _fail(&"invalid_view_backup", "a restored view is a Dictionary or null", {})
	var validated: Dictionary = _VIEW_STATE.validate(view, _registry, _fingerprint)
	if not validated.get("ok", false):
		return validated
	var installed: Dictionary = {}
	for key: String in _VIEW_STATE.VIEW_KEYS:
		var member: Variant = view[key]
		if typeof(member) == TYPE_DICTIONARY:
			installed[key] = (member as Dictionary).duplicate(true)
		elif typeof(member) == TYPE_ARRAY:
			installed[key] = (member as Array).duplicate(true)
		else:
			installed[key] = member
	_view = installed
	return _ok({"view": _view.duplicate(true)})


# ---- the Task-3 warning surface (Amendment Plan 03 Task 3 Steps 5-6, dwm-oyo.3) ----
#
# DERIVED SURFACE NOTE (deviation-class design decision, Task 3 Phase A -- reviewer, see the
# task record). The plan names only configure_warning_identity() (Step 5) and the terminal
# resolve_warning() transaction root (child-identity rows P03.warning.dismissal/navigation,
# plan lines 108-109). The activation entry request_warning_activation(transaction_id,
# transaction_issuer_receipt, context) is DERIVED from Step 5's "ScheduleDoneCommandPort
# later passes {transaction_id,transaction_issuer_receipt}" plus row P03.warning.activation
# (parent: the request_done() transaction receipt) and Step 6's modal idempotence law.
# resolve_warning(transaction_id, transaction_issuer_receipt, resolution) carries one exact
# resolution Dictionary: {outcome:"dismissed"} | {outcome:"navigation_committed",
# intent:String} | {outcome:"navigation_failed", intent:String, failure_code:String}.
# No separate read methods exist: pending_warning, its attempt_receipts, and
# consumed_warning_receipts are Task-2 view members and ride snapshot().


func configure_warning_identity(identity_issuer: Object) -> Dictionary:
	if identity_issuer == null or not identity_issuer.has_method("verify_issued") \
			or not identity_issuer.has_method("validate_child") \
			or not identity_issuer.has_method("derive_child"):
		return _fail(&"invalid_warning_identity_issuer",
			"the exact Plan-02 issuer object is required", {})
	if _warning_identity_configured:
		if identity_issuer == _warning_identity:
			return _ok({"configured": true, "already_configured": true})
		return _fail(&"warning_identity_already_configured",
			"the warning identity issuer is retained once and never replaced", {})
	_warning_identity = identity_issuer
	_warning_identity_configured = true
	return _ok({"configured": true, "already_configured": false})


func request_warning_activation(transaction_id: String,
		transaction_issuer_receipt: Dictionary, context: Dictionary) -> Dictionary:
	var guard := _warning_guard()
	if not guard.is_empty():
		return guard
	var validated_context: Dictionary = _WARNING_POLICY.validate_context(context)
	if not validated_context.get("ok", false):
		return validated_context
	var root := _warning_root_error(transaction_id, transaction_issuer_receipt)
	if not root.is_empty():
		return root
	var crossover := _terminal_transaction_error(transaction_id)
	if not crossover.is_empty():
		return crossover
	var pending: Variant = _view["pending_warning"]
	if typeof(pending) == TYPE_DICTIONARY:
		# Modal idempotence: the same Done command returns the same pending activation;
		# any different Done command is rejected while the modal is open.
		if str((pending as Dictionary)["opened_by_transaction_id"]) == transaction_id:
			return _ok({"warning": (pending as Dictionary).duplicate(true)})
		return _fail(&"warning_modal_active",
			"a warning modal is open under another Done transaction", {})
	var next: Dictionary = _WARNING_POLICY.next_warning(_view, context)
	if not next.get("ok", false):
		return next
	var warning: Variant = (next["value"] as Dictionary)["warning"]
	if warning == null:
		return _ok({"warning": null})
	var kind := str((warning as Dictionary)["warning_kind"])
	var digest := str((warning as Dictionary)["warning_state_fingerprint"])
	# The immutable preimage is exactly {view_projection, context}; canonical hashing of
	# this stored preimage equals warning_state_fingerprint, and no later copy is ever
	# reconstructed from live owners.
	var preimage := {
		"view_projection": {
			"day": int(_view["day"]),
			"causal_day_instance": str(_view["causal_day_instance"]),
			"entries": (_view["entries"] as Array).duplicate(true),
			"date_entry_seen": bool(_view["date_entry_seen"]),
		},
		"context": context.duplicate(true),
	}
	var sources: Array = [
		_p("warning_kind", kind),
		_p("warning_state_fingerprint", digest),
	]
	sources.sort()
	var request := {
		"child_kind": "warning",
		"ordinal": 0,
		"parent_receipt_id": str(transaction_issuer_receipt.get("receipt_id", "")),
		"source_ids": sources,
	}
	var derived: Dictionary = _warning_identity.call(&"derive_child", request)
	if not derived.get("ok", false):
		return derived
	var value: Dictionary = derived["value"]
	var record := {
		"activation_id": str(value["child_id"]),
		"activation_id_provenance": (value["provenance"] as Dictionary).duplicate(true),
		"warning_fingerprint_preimage": preimage.duplicate(true),
		"warning_state_fingerprint": digest,
		"warning_kind": kind,
		"opened_by_transaction_id": transaction_id,
		"opened_by_transaction_issuer_receipt": transaction_issuer_receipt.duplicate(true),
		"state": "pending",
		"attempt_receipts": {},
	}
	_view["pending_warning"] = record.duplicate(true)
	return _ok({"warning": record.duplicate(true)})


func resolve_warning(transaction_id: String, transaction_issuer_receipt: Dictionary,
		resolution: Dictionary) -> Dictionary:
	var guard := _warning_guard()
	if not guard.is_empty():
		return guard
	var shape := _resolution_error(resolution)
	if not shape.is_empty():
		return shape
	var root := _warning_root_error(transaction_id, transaction_issuer_receipt)
	if not root.is_empty():
		return root
	var outcome := str(resolution["outcome"])
	# Terminal-transaction idempotence and conflict law, checked before anything mutates:
	# an identical replay returns the original durable receipt; changed bytes refuse.
	var consumed: Dictionary = _view["consumed_warning_receipts"]
	for key: Variant in consumed:
		var stored: Variant = consumed[key]
		if typeof(stored) != TYPE_DICTIONARY:
			continue
		if str((stored as Dictionary).get("transaction_id", "")) != transaction_id:
			continue
		if _matches_terminal(stored as Dictionary, resolution):
			return _ok({"receipt": (stored as Dictionary).duplicate(true)})
		return _fail(&"warning_transaction_conflict",
			"a terminal transaction is never reused with different bytes", {})
	var pending: Variant = _view["pending_warning"]
	if typeof(pending) == TYPE_DICTIONARY:
		var attempts: Dictionary = (pending as Dictionary)["attempt_receipts"]
		if attempts.has(transaction_id):
			var attempt: Dictionary = attempts[transaction_id]
			if _matches_terminal(attempt, resolution):
				return _ok({"receipt": attempt.duplicate(true)})
			return _fail(&"warning_transaction_conflict",
				"a terminal transaction is never reused with different bytes", {})
	else:
		return _fail(&"no_pending_warning", "no warning activation is open", {})
	var open_pending := pending as Dictionary
	if str(open_pending["opened_by_transaction_id"]) == transaction_id:
		return _fail(&"warning_transaction_conflict",
			"the activation's own transaction never resolves it", {})
	var child_kind := "warning" if outcome == "dismissed" else "navigation"
	var request := {
		"child_kind": child_kind,
		"ordinal": 0,
		"parent_receipt_id": str(transaction_issuer_receipt.get("receipt_id", "")),
		"source_ids": _terminal_sources(open_pending, resolution),
	}
	var derived: Dictionary = _warning_identity.call(&"derive_child", request)
	if not derived.get("ok", false):
		return derived
	var value: Dictionary = derived["value"]
	var receipt := {
		"receipt_id": str(value["child_id"]),
		"receipt_provenance": (value["provenance"] as Dictionary).duplicate(true),
		"activation_id": str(open_pending["activation_id"]),
		"activation_id_provenance":
			(open_pending["activation_id_provenance"] as Dictionary).duplicate(true),
		"warning_fingerprint_preimage":
			(open_pending["warning_fingerprint_preimage"] as Dictionary).duplicate(true),
		"warning_state_fingerprint": str(open_pending["warning_state_fingerprint"]),
		"warning_kind": str(open_pending["warning_kind"]),
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": transaction_issuer_receipt.duplicate(true),
		"terminal_result": outcome,
	}
	if outcome == "navigation_failed":
		# A failed route appends its terminal receipt durably, leaves the same activation
		# pending, and never enters the consumed map.
		receipt["failure_code"] = str(resolution["failure_code"])
		var live_attempts: Dictionary = \
			(_view["pending_warning"] as Dictionary)["attempt_receipts"]
		live_attempts[transaction_id] = receipt.duplicate(true)
		return _ok({"receipt": receipt.duplicate(true)})
	# A successful terminal stores its durable receipt under fingerprint|kind FIRST and
	# removes the pending activation only afterwards.
	var consumed_key := str(open_pending["warning_state_fingerprint"]) + "|" \
			+ str(open_pending["warning_kind"])
	(_view["consumed_warning_receipts"] as Dictionary)[consumed_key] = \
		receipt.duplicate(true)
	_view["pending_warning"] = null
	return _ok({"receipt": receipt.duplicate(true)})


# ---- warning internals ----

func _warning_guard() -> Dictionary:
	var guard := _view_guard()
	if not guard.is_empty():
		return guard
	if not _warning_identity_configured:
		return _fail(&"warning_identity_unconfigured",
			"configure_warning_identity() was never called", {})
	return {}


## A transaction root is single-purpose (Important-1, Task 3 review): an ID that
## already anchors a terminal receipt -- consumed or failed-attempt -- never opens
## an activation, and the activation's own root never resolves it.
func _terminal_transaction_error(transaction_id: String) -> Dictionary:
	var consumed: Dictionary = _view["consumed_warning_receipts"]
	for key: Variant in consumed:
		var stored: Variant = consumed[key]
		if typeof(stored) == TYPE_DICTIONARY \
				and str((stored as Dictionary).get("transaction_id", "")) == transaction_id:
			return _fail(&"warning_transaction_conflict",
				"a terminal transaction never reopens an activation", {})
	var pending: Variant = _view["pending_warning"]
	if typeof(pending) == TYPE_DICTIONARY \
			and ((pending as Dictionary)["attempt_receipts"] as Dictionary)\
			.has(transaction_id):
		return _fail(&"warning_transaction_conflict",
			"a terminal transaction never reopens an activation", {})
	return {}


func _warning_root_error(transaction_id: String, receipt: Dictionary) -> Dictionary:
	if transaction_id.is_empty() or str(receipt.get("token", "")) != transaction_id:
		return _fail(&"invalid_warning_transaction_root",
			"the transaction receipt must carry its own transaction token", {})
	var proven: Dictionary = _warning_identity.verify_issued(receipt, &"transaction_id")
	if not proven.get("ok", false):
		return _fail(&"invalid_warning_transaction_root",
			"the transaction root does not verify against the issuer ledger",
			{"cause": proven.get("code", &"")})
	return {}


func _resolution_error(resolution: Dictionary) -> Dictionary:
	var keys: Array = resolution.keys()
	keys.sort()
	var outcome := str(resolution.get("outcome", ""))
	var expected: Array = []
	match outcome:
		"dismissed":
			expected = ["outcome"]
		"navigation_committed":
			expected = ["intent", "outcome"]
		"navigation_failed":
			expected = ["failure_code", "intent", "outcome"]
		_:
			return _fail(&"invalid_warning_resolution",
				"outcome is dismissed | navigation_committed | navigation_failed",
				{"outcome": outcome})
	if keys != expected:
		return _fail(&"invalid_warning_resolution",
			"the resolution carries exactly " + str(expected), {"field": "keys"})
	for field: String in expected:
		if typeof(resolution[field]) != TYPE_STRING or str(resolution[field]).is_empty():
			return _fail(&"invalid_warning_resolution",
				field + " is a nonempty String", {"field": field})
	return {}


## The exact P03.warning.dismissal / P03.warning.navigation source projections (plan lines
## 108-109), lexically sorted before issuance.
func _terminal_sources(anchor: Dictionary, resolution: Dictionary) -> Array:
	var sources: Array = []
	if str(resolution["outcome"]) == "dismissed":
		sources = [
			_p("activation_id", str(anchor.get("activation_id", ""))),
			_p("warning_state_fingerprint",
				str(anchor.get("warning_state_fingerprint", ""))),
			_p("warning_kind", str(anchor.get("warning_kind", ""))),
			_p("outcome", "dismissed"),
		]
	else:
		sources = [
			_p("activation_id", str(anchor.get("activation_id", ""))),
			_p("warning_kind", str(anchor.get("warning_kind", ""))),
			_p("intent", str(resolution.get("intent", ""))),
		]
	sources.sort()
	return sources


func _matches_terminal(stored: Dictionary, resolution: Dictionary) -> bool:
	if str(stored.get("terminal_result", "")) != str(resolution["outcome"]):
		return false
	var provenance: Dictionary = stored.get("receipt_provenance", {})
	if provenance.get("source_ids", []) != _terminal_sources(stored, resolution):
		return false
	if str(resolution["outcome"]) == "navigation_failed" \
			and str(stored.get("failure_code", "")) != str(resolution["failure_code"]):
		return false
	return true


## P(name,value): the single nonblank String name + "=" + canonical JSON (plan line 103).
func _p(name: String, value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	return name + "=" + str(emitted.get("value", ""))


# ---- internals ----

func _docket_command_error(command: Dictionary) -> Dictionary:
	var keys: Array = command.keys()
	keys.sort()
	if typeof(command.get("kind")) != TYPE_STRING:
		return _fail(&"invalid_docket_command", "kind is an exact String", {})
	match command["kind"]:
		"move":
			if keys != ["draft_entry_id", "kind", "target_index"] \
					or typeof(command["draft_entry_id"]) != TYPE_STRING \
					or str(command["draft_entry_id"]).is_empty() \
					or typeof(command["target_index"]) != TYPE_INT:
				return _fail(&"invalid_docket_command", "invalid move command shape", {})
		"remove":
			if keys != ["draft_entry_id", "kind"] \
					or typeof(command["draft_entry_id"]) != TYPE_STRING \
					or str(command["draft_entry_id"]).is_empty():
				return _fail(&"invalid_docket_command", "invalid remove command shape", {})
		"append":
			if keys != ["action_id", "draft_entry_id", "kind", "source_receipt_id"] \
					or typeof(command["action_id"]) != TYPE_STRING \
					or str(command["action_id"]).is_empty() \
					or typeof(command["draft_entry_id"]) != TYPE_STRING \
					or str(command["draft_entry_id"]).is_empty():
				return _fail(&"invalid_docket_command", "invalid append command shape", {})
		_:
			return _fail(&"invalid_docket_command", "unsupported docket command", {})
	return {}


func _packed_entries(entries: Array) -> Array:
	var ordered: Array = entries.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["slot_index"]) < int(right["slot_index"]))
	return ordered


func _entry_ordinal(entries: Array, draft_entry_id: String) -> int:
	for index: int in range(entries.size()):
		if str((entries[index] as Dictionary)["draft_entry_id"]) == draft_entry_id:
			return index
	return -1


func _reindex(entries: Array) -> void:
	for index: int in range(entries.size()):
		(entries[index] as Dictionary)["slot_index"] = index


func _commit_entries(entries: Array) -> Dictionary:
	var candidate := _view.duplicate(true)
	candidate["entries"] = entries
	return commit(candidate)

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
