class_name ConditionHospitalState
extends RefCounted

## The sole pre-Done condition-Hospital plan-state mutation seam (Amendment Plan 03 Task 4,
## dwm-oyo.3, plan:936).
##
## Stateful facade retaining exactly one RunLifecycle and one identity port, returning the master
## four-key envelope throughout.
##
## OWNERSHIP FENCE. It holds no GameState, no ScheduleViewController, no Contacts port, no
## presentation owner and no storage reference; its only mutation authority is the retained
## RunLifecycle. Every prepare is pure -- it computes a before_fingerprint over the complete current
## RunLifecycle.to_dict() and returns a detached candidate -- and only the matching commit adopts,
## after rechecking that fingerprint.
##
## THE PREPARE-FIRST ORDERING LAW (plan:558). prepare_stage accepts only a stage_identity THIS
## instance issued for that exact (resolution_receipt_id, stage_id). A caller-authored identity, a
## stale identity from another stage, or an identity for a stage whose prepare_stage_identity was
## never called must conflict. Stage 4 is NOT exempt just because the allocator root is committed.
##
## commit_retirement is where the append-only history law of the lifecycle aggregate is actually
## enforceable: a single document cannot witness an append, so the document layer checks shape only
## and this transition owns the rest.
##
## SCOPE. Task 4 Step 2 implements the eleven methods above capture_active_stage. The last two ship
## as typed not_implemented past Task 4's GREEN -- the shipped Ruling-18-A stub precedent in
## DesktopConsequenceCoordinator.configure_schedule_departure_ports -- and no Task-4 test asserts
## behaviour for them.
##
## Both owners are held as bare `Object` and reached through `call(&"...")`, the established repo
## idiom for a retained collaborator (DesktopConsequenceCoordinator, ContactCommandPort): this
## module names no class it does not own.

const CONDITION_HOSPITAL_PLAN := preload("res://scripts/domain/run/ConditionHospitalPlan.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _ACCEPT_REQUEST_KEYS: Array[String] = [
	"action_receipt", "condition_receipt", "destination_record",
]
const _CANDIDATE_KEYS: Array[String] = ["before_fingerprint", "lifecycle_candidate"]
const _BACKUP_KEYS: Array[String] = ["backup"]
const _STAGE_IDENTITY_REQUEST_KEYS: Array[String] = [
	"input_receipt_ids", "resolution_receipt_id", "stage_id",
]
const _PREPARE_STAGE_REQUEST_KEYS: Array[String] = [
	"prepared", "resolution_receipt_id", "stage_id", "stage_identity",
]
const _COMPLETE_STAGE_REQUEST_KEYS: Array[String] = [
	"prepared", "resolution_receipt_id", "stage_id", "stage_identity", "stage_receipt",
]
const _STAGE_RECEIPT_KEYS: Array[String] = [
	"input_receipt_ids", "output", "receipt_id", "receipt_provenance", "resolution_kind",
	"resolution_receipt_id", "stage_id", "stage_index",
]
const _STAGE_CANDIDATE_IDENTITY_KEYS: Array[String] = [
	"before_fingerprint", "lifecycle_candidate", "stage_identity",
]
const _STAGE_CANDIDATE_RECEIPT_KEYS: Array[String] = [
	"before_fingerprint", "lifecycle_candidate", "stage_receipt",
]
const _RETIREMENT_REQUEST_KEYS: Array[String] = ["autosave_stage_receipt", "completed_plan"]

const _ACCEPTANCE_KIND := "condition_hospital_resolution"
const _STAGE_CHILD_KIND := "condition_hospital_stage"
const _RETIREMENT_CHILD_KIND := "condition_hospital_retirement"
const _RETIREMENT_DISPOSITION := "condition_hospital_plan_retired"
const _DESTINATION_PAYLOAD_KIND := "hospital_day"
const _LAST_SOURCE_DAY := 6

var _run_lifecycle: Object = null
var _identity_port: Object = null

## resolution_receipt_id -> {intent_key, envelope}. The identity port counts every derive_child, so
## a replayed acceptance returns the ORIGINAL envelope bytes rather than mint a second receipt.
var _acceptances: Dictionary = {}
## "<resolution_receipt_id>:<stage_id>" -> {child_id, input_receipt_ids, provenance}. The single
## record of what THIS instance issued, and therefore the whole enforcement of plan:558.
var _stage_identities: Dictionary = {}
## resolution_receipt_id -> the ten-key retirement receipt, so a retirement replay is byte-identical.
var _retirements: Dictionary = {}
## One entry per capture(): {backup, backup_sha, expected_sha, closed}. `expected_sha` is the state
## a later commit produced -- the only live state that backup may roll back FROM -- and `closed`
## records that its one restore already happened, so any third live state conflicts afterwards.
var _captures: Array[Dictionary] = []


## Binds the two owners one way. Value is {configured: true, already_configured: bool}.
func configure(run_lifecycle: Object, identity_port: Object) -> Dictionary:
	if run_lifecycle == null or identity_port == null:
		return _fail(&"invalid_configuration",
			"configure requires a RunLifecycle and an identity port", {})
	if _run_lifecycle == null:
		_run_lifecycle = run_lifecycle
		_identity_port = identity_port
		return _ok({"configured": true, "already_configured": false}, {})
	if is_same(_run_lifecycle, run_lifecycle) and is_same(_identity_port, identity_port):
		return _ok({"configured": true, "already_configured": true}, {})
	return _fail(&"configuration_conflict",
		"configure is one-way: the retained RunLifecycle and identity port are never replaced", {})


## Accepts a condition-Hospital resolution and returns the cursor-0 candidate plus its aliased
## acceptance receipt.
func prepare_accept(request: Dictionary) -> Dictionary:
	var guard := _unconfigured("prepare_accept")
	if not guard.is_empty():
		return guard
	if str(_run_lifecycle.call(&"get_state")) != "PLAYING":
		return _fail(&"invalid_state",
			"a condition-Hospital resolution is accepted only in PLAYING", {})
	if int(_run_lifecycle.call(&"get_day")) > _LAST_SOURCE_DAY:
		return _fail(&"invalid_day",
			"day 7 has no next day for a condition-Hospital resolution to advance into", {})
	var live := _live()
	if live["active_resolution_plan"] != null:
		return _fail(&"resolution_conflict",
			"a Plan-01 day resolution is already active on this run", {})
	var shape := _accept_request_error(request)
	if not shape.is_empty():
		return shape
	var intent_key := _fingerprint(request)
	if intent_key.is_empty():
		return _fail(&"noncanonical_request", "the accept request does not canonicalize", {})
	var replayed := _accept_replay(live, intent_key)
	if not replayed.is_empty():
		return replayed
	var action_receipt: Dictionary = request["action_receipt"]
	var issuer: Dictionary = action_receipt["transaction_issuer_receipt"]
	var record: Dictionary = request["destination_record"]
	var payload: Dictionary = record["payload"]
	var sources: Array = payload["accepted_unfulfilled_sources"]
	var source_receipt_ids: Array = []
	for entry: Variant in sources:
		source_receipt_ids.append(str((entry as Dictionary)["receipt_id"]))
	source_receipt_ids.sort()
	var payload_sha256 := _fingerprint(payload)
	if payload_sha256.is_empty():
		return _fail(&"noncanonical_payload", "the destination payload does not canonicalize", {})
	var derived: Dictionary = _identity_port.call(&"derive_child", {
		"child_kind": _ACCEPTANCE_KIND,
		"parent_receipt_id": str(issuer.get("receipt_id", "")),
		"ordinal": 0,
		"source_ids": source_receipt_ids.duplicate(true),
	})
	if not derived.get("ok", false):
		return _fail(&"identity_derivation_failed",
			"the identity port refused the acceptance receipt: " + _reason(derived), {})
	var identity: Dictionary = derived["value"]
	var provenance: Dictionary = identity["provenance"]
	var condition_receipt: Dictionary = request["condition_receipt"]
	var acceptance: Dictionary = {
		"acceptance_kind": _ACCEPTANCE_KIND,
		"receipt_id": str(identity["child_id"]),
		"receipt_provenance": provenance.duplicate(true),
		"consumer_id": _ACCEPTANCE_KIND,
		"outbox_kind": "destination",
		"intent_id": str(record.get("key", "")),
		"intent_id_provenance": _detached(record.get("provenance")),
		"condition_receipt_id": str(condition_receipt["receipt_id"]),
		"accepted_source_receipt_ids": source_receipt_ids.duplicate(true),
		"payload_sha256": payload_sha256,
		"status": "accepted",
	}
	var plan := _cursor_zero_plan(live, request, acceptance, sources)
	var validated: Dictionary = CONDITION_HOSPITAL_PLAN.validate(plan)
	if not validated.get("ok", false):
		return _fail(&"invalid_plan",
			"the accepted plan is not a valid condition-Hospital plan: " + _reason(validated), {})
	var lifecycle_candidate: Dictionary = live.duplicate(true)
	lifecycle_candidate["active_condition_hospital_plan"] = plan
	var restorable: Dictionary = _run_lifecycle.call(&"prepare_restore", lifecycle_candidate)
	if not restorable.get("ok", false):
		return _fail(&"invalid_lifecycle_candidate",
			"the accepted candidate is not a restorable lifecycle: " + _reason(restorable), {})
	var candidate: Dictionary = {
		"before_fingerprint": _fingerprint(live),
		"lifecycle_candidate": lifecycle_candidate.duplicate(true),
	}
	var envelope := _ok({
		"condition_hospital_candidate": candidate,
		"consumer_acceptance_receipt": acceptance.duplicate(true),
		"resolution_receipt": acceptance.duplicate(true),
	}, acceptance.duplicate(true))
	_acceptances[str(acceptance["receipt_id"])] = {
		"intent_key": intent_key,
		"envelope": envelope.duplicate(true),
	}
	return envelope


## The complete detached lifecycle backup. Value is {backup}, receipt is {}.
func capture() -> Dictionary:
	var guard := _unconfigured("capture")
	if not guard.is_empty():
		return guard
	var backup := _live()
	var digest := _fingerprint(backup)
	if digest.is_empty():
		return _fail(&"noncanonical_lifecycle", "the live lifecycle does not canonicalize", {})
	_captures.append({
		"backup": backup.duplicate(true),
		"backup_sha": digest,
		"expected_sha": "",
		"closed": false,
	})
	return _ok({"backup": backup.duplicate(true)}, {})


## Adopts a prepared candidate after rechecking its before_fingerprint.
func commit(candidate: Dictionary) -> Dictionary:
	var guard := _unconfigured("commit")
	if not guard.is_empty():
		return guard
	if _sorted_keys(candidate) != _CANDIDATE_KEYS:
		return _fail(&"invalid_candidate",
			"a lifecycle candidate carries exactly " + str(_CANDIDATE_KEYS), {})
	var adopted := _adopt(candidate, true)
	if not adopted.is_empty():
		return adopted
	_arm_open_captures()
	return _ok({"committed": true}, {})


## Restores a backup this instance issued. Value is {restored: true}.
func rollback(backup: Dictionary) -> Dictionary:
	var guard := _unconfigured("rollback")
	if not guard.is_empty():
		return guard
	if _sorted_keys(backup) != _BACKUP_KEYS:
		return _fail(&"invalid_backup", "a backup value carries exactly {backup}", {})
	if typeof(backup["backup"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "backup is a Dictionary", {})
	var stored: Dictionary = backup["backup"]
	var digest := _fingerprint(stored)
	var issued: Dictionary = {}
	var found := false
	for entry: Dictionary in _captures:
		if str(entry["backup_sha"]) == digest:
			issued = entry
			found = true
			break
	if not found:
		return _fail(&"unknown_backup", "rollback accepts only a backup this instance issued", {})
	var live := _live()
	if live == stored:
		return _ok({"restored": true}, {})
	var expected := str(issued["expected_sha"])
	if expected.is_empty() or _fingerprint(live) != expected:
		return _fail(&"rollback_conflict",
			"the live lifecycle is a third state this backup cannot restore", {})
	var prepared: Dictionary = _run_lifecycle.call(&"prepare_restore", stored)
	if not prepared.get("ok", false):
		return _fail(&"invalid_backup",
			"the backup is not a restorable lifecycle: " + _reason(prepared), {})
	var value: Dictionary = prepared["value"]
	var committed: Dictionary = _run_lifecycle.call(&"commit_restore", value["candidate"])
	if not committed.get("ok", false):
		return _fail(&"restore_failed",
			"the lifecycle refused the validated backup: " + _reason(committed), {})
	issued["closed"] = true
	issued["expected_sha"] = ""
	return _ok({"restored": true}, {})


## Issues the stage identity that prepare_stage will later require. Pure: no lifecycle mutation.
## Value is {before_fingerprint, stage_identity}, receipt is {}.
func prepare_stage_identity(request: Dictionary) -> Dictionary:
	var guard := _unconfigured("prepare_stage_identity")
	if not guard.is_empty():
		return guard
	if _sorted_keys(request) != _STAGE_IDENTITY_REQUEST_KEYS:
		return _fail(&"invalid_request",
			"a stage-identity request carries exactly " + str(_STAGE_IDENTITY_REQUEST_KEYS), {})
	if typeof(request["input_receipt_ids"]) != TYPE_ARRAY:
		return _fail(&"invalid_request", "input_receipt_ids is an Array", {})
	var live := _live()
	var located := _locate_stage(live, request)
	if located.has("error"):
		return located["error"] as Dictionary
	var stage_id := str(located["stage_id"])
	var index := int(located["index"])
	var cursor := int(located["cursor"])
	if cursor >= CONDITION_HOSPITAL_PLAN.STAGE_COUNT:
		return _fail(&"invalid_stage", "every stage of this plan is already completed", {})
	if index < cursor:
		return _fail(&"invalid_stage", "stage " + stage_id + " is already completed", {})
	# plan:904 (RULING T4-S): the named stage IS the pending cursor with all earlier stages
	# completed. No lookahead is admissible, not even the one stage after the cursor.
	if index > cursor:
		return _fail(&"invalid_stage",
			"stage " + stage_id + " is not the pending cursor stage "
				+ str(CONDITION_HOSPITAL_PLAN.STAGE_IDS[cursor]), {})
	var key := str(located["receipt_id"]) + ":" + stage_id
	var inputs: Array = (request["input_receipt_ids"] as Array).duplicate(true)
	var cached: Variant = _stage_identities.get(key)
	if cached is Dictionary and (cached as Dictionary)["input_receipt_ids"] == inputs:
		var replay: Dictionary = cached
		return _ok({
			"before_fingerprint": _fingerprint(live),
			"stage_identity": replay.duplicate(true),
		}, {})
	var derived: Dictionary = _identity_port.call(&"derive_child", {
		"child_kind": _STAGE_CHILD_KIND,
		"parent_receipt_id": str(located["receipt_id"]),
		"ordinal": index,
		"source_ids": inputs.duplicate(true),
	})
	if not derived.get("ok", false):
		return _fail(&"identity_derivation_failed",
			"the identity port refused the stage identity: " + _reason(derived), {})
	var value: Dictionary = derived["value"]
	var provenance: Dictionary = value["provenance"]
	var stage_identity: Dictionary = {
		"child_id": str(value["child_id"]),
		"input_receipt_ids": inputs.duplicate(true),
		"provenance": provenance.duplicate(true),
	}
	_stage_identities[key] = stage_identity.duplicate(true)
	return _ok({
		"before_fingerprint": _fingerprint(live),
		"stage_identity": stage_identity.duplicate(true),
	}, {})


## Marks only the cursor record active, storing a detached stage_identity and prepared, retaining a
## null receipt and NOT moving the cursor.
func prepare_stage(request: Dictionary) -> Dictionary:
	var guard := _unconfigured("prepare_stage")
	if not guard.is_empty():
		return guard
	if _sorted_keys(request) != _PREPARE_STAGE_REQUEST_KEYS:
		return _fail(&"invalid_request",
			"a prepare_stage request carries exactly " + str(_PREPARE_STAGE_REQUEST_KEYS), {})
	for member: String in ["prepared", "stage_identity"]:
		if typeof(request[member]) != TYPE_DICTIONARY:
			return _fail(&"invalid_request", member + " is a Dictionary", {"member": member})
	var live := _live()
	var located := _locate_stage(live, request)
	if located.has("error"):
		return located["error"] as Dictionary
	var stage_id := str(located["stage_id"])
	var index := int(located["index"])
	if index != int(located["cursor"]):
		return _fail(&"stage_conflict",
			"only the cursor stage is prepared; stage " + stage_id + " is not it", {})
	var issued := _issued_identity_error(located, request["stage_identity"])
	if not issued.is_empty():
		return issued
	var plan: Dictionary = located["plan"]
	var stages: Array = plan["stages"]
	var record: Dictionary = stages[index]
	var state := str(record["state"])
	var offered: Dictionary = request["stage_identity"]
	if state == "active":
		if record["stage_identity"] != request["stage_identity"] \
				or record["prepared"] != request["prepared"]:
			return _fail(&"stage_conflict",
				"the active record already carries another identity or prepared value", {})
		return _ok({
			"before_fingerprint": _fingerprint(live),
			"lifecycle_candidate": live.duplicate(true),
			"stage_identity": offered.duplicate(true),
		}, {})
	if state != "pending":
		return _fail(&"stage_conflict", "only a pending cursor record can be prepared", {})
	var prepared_value: Dictionary = request["prepared"]
	var lifecycle_candidate: Dictionary = live.duplicate(true)
	var candidate_record := _candidate_record(lifecycle_candidate, index)
	candidate_record["state"] = "active"
	candidate_record["stage_identity"] = offered.duplicate(true)
	candidate_record["prepared"] = prepared_value.duplicate(true)
	candidate_record["receipt"] = null
	var restorable: Dictionary = _run_lifecycle.call(&"prepare_restore", lifecycle_candidate)
	if not restorable.get("ok", false):
		return _fail(&"invalid_lifecycle_candidate",
			"the prepared stage candidate is not a restorable lifecycle: " + _reason(restorable),
			{})
	return _ok({
		"before_fingerprint": _fingerprint(live),
		"lifecycle_candidate": lifecycle_candidate.duplicate(true),
		"stage_identity": offered.duplicate(true),
	}, {})


## Flips exactly one record active -> completed and increments the cursor by exactly one.
## The outer receipt is byte-equal to the request's stage_receipt.
func complete_stage(request: Dictionary) -> Dictionary:
	var guard := _unconfigured("complete_stage")
	if not guard.is_empty():
		return guard
	if _sorted_keys(request) != _COMPLETE_STAGE_REQUEST_KEYS:
		return _fail(&"invalid_request",
			"a complete_stage request carries exactly " + str(_COMPLETE_STAGE_REQUEST_KEYS), {})
	for member: String in ["prepared", "stage_identity", "stage_receipt"]:
		if typeof(request[member]) != TYPE_DICTIONARY:
			return _fail(&"invalid_request", member + " is a Dictionary", {"member": member})
	var live := _live()
	var located := _locate_stage(live, request)
	if located.has("error"):
		return located["error"] as Dictionary
	var stage_id := str(located["stage_id"])
	var index := int(located["index"])
	var receipt_error := _stage_receipt_error(request, located)
	if not receipt_error.is_empty():
		return receipt_error
	var stage_receipt: Dictionary = request["stage_receipt"]
	var plan: Dictionary = located["plan"]
	var stages: Array = plan["stages"]
	var record: Dictionary = stages[index]
	var state := str(record["state"])
	if state == "completed":
		if record["receipt"] != request["stage_receipt"]:
			return _fail(&"stage_conflict",
				"the completed record carries another receipt than the one offered", {})
		return _ok({
			"before_fingerprint": _fingerprint(live),
			"lifecycle_candidate": live.duplicate(true),
			"stage_receipt": stage_receipt.duplicate(true),
		}, stage_receipt.duplicate(true))
	if index != int(located["cursor"]):
		return _fail(&"stage_conflict",
			"only the cursor stage completes; stage " + stage_id + " is not it", {})
	if state != "active":
		return _fail(&"stage_conflict",
			"only an active cursor record completes; this one is " + state, {})
	if record["stage_identity"] != request["stage_identity"]:
		return _fail(&"stage_conflict",
			"the active record carries another stage identity than the one offered", {})
	if record["prepared"] != request["prepared"]:
		return _fail(&"stage_conflict",
			"the active record carries another prepared value than the one offered", {})
	var lifecycle_candidate: Dictionary = live.duplicate(true)
	var candidate_record := _candidate_record(lifecycle_candidate, index)
	candidate_record["state"] = "completed"
	candidate_record["receipt"] = stage_receipt.duplicate(true)
	var candidate_plan: Dictionary = lifecycle_candidate["active_condition_hospital_plan"]
	candidate_plan["cursor"] = index + 1
	var restorable: Dictionary = _run_lifecycle.call(&"prepare_restore", lifecycle_candidate)
	if not restorable.get("ok", false):
		return _fail(&"invalid_lifecycle_candidate",
			"the completed stage candidate is not a restorable lifecycle: " + _reason(restorable),
			{})
	return _ok({
		"before_fingerprint": _fingerprint(live),
		"lifecycle_candidate": lifecycle_candidate.duplicate(true),
		"stage_receipt": stage_receipt.duplicate(true),
	}, stage_receipt.duplicate(true))


## Adopts a prepared stage candidate after rechecking its before_fingerprint.
func commit_stage(candidate: Dictionary) -> Dictionary:
	var guard := _unconfigured("commit_stage")
	if not guard.is_empty():
		return guard
	var keys := _sorted_keys(candidate)
	if keys != _STAGE_CANDIDATE_IDENTITY_KEYS and keys != _STAGE_CANDIDATE_RECEIPT_KEYS:
		return _fail(&"invalid_candidate",
			"a stage candidate carries exactly " + str(_STAGE_CANDIDATE_IDENTITY_KEYS) + " or "
				+ str(_STAGE_CANDIDATE_RECEIPT_KEYS), {})
	var adopted := _adopt(candidate, true)
	if not adopted.is_empty():
		return adopted
	return _ok({"committed": true}, {})


## Builds the retirement candidate from the byte-identical active cursor-6 plan.
## Value is {lifecycle_candidate, history_record, retirement_receipt}.
func prepare_retirement(request: Dictionary) -> Dictionary:
	var guard := _unconfigured("prepare_retirement")
	if not guard.is_empty():
		return guard
	if _sorted_keys(request) != _RETIREMENT_REQUEST_KEYS:
		return _fail(&"invalid_request",
			"a retirement request carries exactly " + str(_RETIREMENT_REQUEST_KEYS), {})
	for member: String in _RETIREMENT_REQUEST_KEYS:
		if typeof(request[member]) != TYPE_DICTIONARY:
			return _fail(&"invalid_request", member + " is a Dictionary", {"member": member})
	var autosave: Dictionary = request["autosave_stage_receipt"]
	if typeof(autosave.get("receipt_id")) != TYPE_STRING \
			or str(autosave["receipt_id"]).strip_edges().is_empty():
		return _fail(&"invalid_request",
			"autosave_stage_receipt.receipt_id is a nonblank String", {})
	var live := _live()
	if typeof(live["active_condition_hospital_plan"]) != TYPE_DICTIONARY:
		return _fail(&"no_active_plan", "no condition-Hospital plan is active to retire", {})
	var plan: Dictionary = live["active_condition_hospital_plan"]
	var complete: Dictionary = CONDITION_HOSPITAL_PLAN.is_complete(plan)
	if not complete.get("ok", false):
		return _fail(&"invalid_plan",
			"the active plan is not a valid condition-Hospital plan: " + _reason(complete), {})
	var completeness: Dictionary = complete["value"]
	if not bool(completeness["complete"]):
		return _fail(&"incomplete_plan",
			"retirement requires the cursor-%d all-completed plan"
				% CONDITION_HOSPITAL_PLAN.STAGE_COUNT, {})
	if request["completed_plan"] != plan:
		return _fail(&"plan_conflict",
			"completed_plan is not byte-identical to the active plan", {})
	var resolution_receipt: Dictionary = plan["resolution_receipt"]
	var receipt_id := str(resolution_receipt["receipt_id"])
	var retirement_receipt: Dictionary = {}
	var cached: Variant = _retirements.get(receipt_id)
	if cached is Dictionary:
		var stored: Dictionary = cached
		var previous: Dictionary = stored["receipt"]
		retirement_receipt = previous.duplicate(true)
	else:
		var minted := _mint_retirement_receipt(plan, receipt_id, str(autosave["receipt_id"]))
		if minted.has("error"):
			return minted["error"] as Dictionary
		retirement_receipt = minted["receipt"] as Dictionary
	var history_record: Dictionary = {
		"completed_plan": plan.duplicate(true),
		"retirement_receipt": retirement_receipt.duplicate(true),
	}
	var validated: Dictionary = CONDITION_HOSPITAL_PLAN.validate_history_record(
		history_record, receipt_id)
	if not validated.get("ok", false):
		return _fail(&"invalid_history_record",
			"the retirement record is not a valid history record: " + _reason(validated), {})
	var lifecycle_candidate: Dictionary = live.duplicate(true)
	lifecycle_candidate["active_condition_hospital_plan"] = null
	var history: Dictionary = lifecycle_candidate["condition_hospital_history"]
	history[receipt_id] = history_record.duplicate(true)
	var restorable: Dictionary = _run_lifecycle.call(&"prepare_restore", lifecycle_candidate)
	if not restorable.get("ok", false):
		return _fail(&"invalid_lifecycle_candidate",
			"the retirement candidate is not a restorable lifecycle: " + _reason(restorable), {})
	# RULING T4-S: commit_retirement honours a blank before_fingerprint ONLY against these exact
	# issued bytes prepared against this exact live state, so both are remembered here.
	_retirements[receipt_id] = {
		"receipt": retirement_receipt.duplicate(true),
		"prepare_sha": _fingerprint(live),
		"lifecycle_candidate": lifecycle_candidate.duplicate(true),
	}
	return _ok({
		"history_record": history_record.duplicate(true),
		"lifecycle_candidate": lifecycle_candidate.duplicate(true),
		"retirement_receipt": retirement_receipt.duplicate(true),
	}, retirement_receipt.duplicate(true))


## Atomically appends the history record and nulls the active plan in one step. This is where the
## append-only law of condition_hospital_history is enforced.
func commit_retirement(candidate: Dictionary) -> Dictionary:
	var guard := _unconfigured("commit_retirement")
	if not guard.is_empty():
		return guard
	if _sorted_keys(candidate) != _CANDIDATE_KEYS:
		return _fail(&"invalid_candidate",
			"a lifecycle candidate carries exactly " + str(_CANDIDATE_KEYS), {})
	if typeof(candidate["lifecycle_candidate"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "lifecycle_candidate is a Dictionary", {})
	if typeof(candidate["before_fingerprint"]) != TYPE_STRING:
		return _fail(&"invalid_candidate", "before_fingerprint is a String", {})
	var proposed: Dictionary = candidate["lifecycle_candidate"]
	var live := _live()
	if proposed == live:
		return _ok({"committed": true}, {})
	# The append-only law runs FIRST. A candidate that drops or rewrites an existing history
	# entry must refuse on THAT law, never on whatever fingerprint happened to ride with it --
	# otherwise the only transition that can witness an append is never reached.
	var append_error := _history_append_error(live, proposed)
	if not append_error.is_empty():
		return append_error
	var stale := _retirement_fingerprint_error(live, proposed, candidate["before_fingerprint"])
	if not stale.is_empty():
		return stale
	var adopted := _adopt(candidate, false)
	if not adopted.is_empty():
		return adopted
	return _ok({"committed": true}, {})


## NOT Task 4. Ships as a typed not_implemented past this task's GREEN; no Task-4 test asserts
## behaviour for it.
func capture_active_stage() -> Dictionary:
	return _not_implemented("capture_active_stage")


## NOT Task 4. Ships as a typed not_implemented past this task's GREEN; no Task-4 test asserts
## behaviour for it.
@warning_ignore("unused_parameter")
func prepare_autosave_stage_output(request: Dictionary) -> Dictionary:
	return _not_implemented("prepare_autosave_stage_output")


# ---- acceptance helpers ----

## The three-key request and every member this seam can cross-check. Ledger/ancestry validation of
## the transaction root is Task 7's; RULING T4-N fixes only that the root travels INSIDE
## `action_receipt` and that a receipt without it is refused.
func _accept_request_error(request: Dictionary) -> Dictionary:
	if _sorted_keys(request) != _ACCEPT_REQUEST_KEYS:
		return _fail(&"invalid_request",
			"an accept request carries exactly " + str(_ACCEPT_REQUEST_KEYS), {})
	for member: String in _ACCEPT_REQUEST_KEYS:
		if typeof(request[member]) != TYPE_DICTIONARY:
			return _fail(&"invalid_request", member + " is a Dictionary", {"member": member})
	var action_receipt: Dictionary = request["action_receipt"]
	if typeof(action_receipt.get("transaction_id")) != TYPE_STRING \
			or str(action_receipt["transaction_id"]).strip_edges().is_empty():
		return _fail(&"invalid_action_receipt",
			"action_receipt.transaction_id is a nonblank String", {})
	if typeof(action_receipt.get("transaction_issuer_receipt")) != TYPE_DICTIONARY:
		return _fail(&"invalid_action_receipt",
			"action_receipt.transaction_issuer_receipt is a full receipt Dictionary", {})
	var condition_receipt: Dictionary = request["condition_receipt"]
	if typeof(condition_receipt.get("receipt_id")) != TYPE_STRING \
			or str(condition_receipt["receipt_id"]).strip_edges().is_empty():
		return _fail(&"invalid_condition_receipt",
			"condition_receipt.receipt_id is a nonblank String", {})
	return _destination_record_error(request["destination_record"])


## The unpublished hospital_day outbox intent, with its source list already sorted once by
## (action_id, receipt_id): this seam never sorts a caller's list for it.
func _destination_record_error(record: Dictionary) -> Dictionary:
	if str(record.get("status", "")) != "pending":
		return _fail(&"invalid_destination_record",
			"destination_record.status is pending; a published record is never accepted", {})
	if typeof(record.get("payload")) != TYPE_DICTIONARY:
		return _fail(&"invalid_destination_record",
			"destination_record.payload is a Dictionary", {})
	var payload: Dictionary = record["payload"]
	if str(payload.get("kind", "")) != _DESTINATION_PAYLOAD_KIND:
		return _fail(&"invalid_destination_record",
			"destination_record.payload.kind is " + _DESTINATION_PAYLOAD_KIND, {})
	if typeof(payload.get("accepted_unfulfilled_sources")) != TYPE_ARRAY:
		return _fail(&"invalid_destination_record",
			"destination_record.payload.accepted_unfulfilled_sources is an Array", {})
	var sources: Array = payload["accepted_unfulfilled_sources"]
	var previous: Array = []
	for index: int in range(sources.size()):
		if typeof(sources[index]) != TYPE_DICTIONARY:
			return _fail(&"invalid_destination_record",
				"accepted_unfulfilled_sources[%d] is a Dictionary" % index, {})
		var source: Dictionary = sources[index]
		var pair: Array = []
		for field: String in ["action_id", "receipt_id"]:
			var value: Variant = source.get(field)
			if typeof(value) != TYPE_STRING or str(value).strip_edges().is_empty():
				return _fail(&"invalid_destination_record",
					"accepted_unfulfilled_sources[%d].%s is a nonblank String" % [index, field],
					{})
			pair.append(str(value))
		if index > 0 and not _sorts_before(previous, pair):
			return _fail(&"invalid_destination_record",
				"accepted_unfulfilled_sources is sorted once by (action_id, receipt_id) with no"
					+ " duplicate", {})
		previous = pair
	return {}


static func _sorts_before(left: Array, right: Array) -> bool:
	if str(left[0]) != str(right[0]):
		return str(left[0]) < str(right[0])
	return str(left[1]) < str(right[1])


## The identity port counts every derivation, so a repeated intent returns the ORIGINAL bytes. An
## active plan whose acceptance carried a different intent conflicts, never accepts a second plan.
func _accept_replay(live: Dictionary, intent_key: String) -> Dictionary:
	var active: Variant = live["active_condition_hospital_plan"]
	if typeof(active) == TYPE_DICTIONARY:
		var plan: Dictionary = active
		var resolution_receipt: Dictionary = plan["resolution_receipt"]
		var cached: Variant = _acceptances.get(str(resolution_receipt.get("receipt_id", "")))
		if cached is Dictionary:
			var acceptance: Dictionary = cached
			if str(acceptance["intent_key"]) == intent_key:
				var envelope: Dictionary = acceptance["envelope"]
				return envelope.duplicate(true)
		return _fail(&"acceptance_conflict",
			"another condition-Hospital intent is already accepted and incomplete", {})
	var history: Dictionary = live["condition_hospital_history"]
	for key: Variant in history:
		var retired: Variant = _acceptances.get(str(key))
		if retired is Dictionary:
			var completed: Dictionary = retired
			if str(completed["intent_key"]) == intent_key:
				var original: Dictionary = completed["envelope"]
				return original.duplicate(true)
	return {}


## The seventeen-key cursor-0 plan. Every identity member is copied from the lifecycle's own, which
## is exactly what RunLifecycle._validate_condition_lifecycle requires below the advance stage.
func _cursor_zero_plan(live: Dictionary, request: Dictionary, acceptance: Dictionary,
		sources: Array) -> Dictionary:
	var receipt_id := str(acceptance["receipt_id"])
	var action_receipt: Dictionary = request["action_receipt"]
	var condition_receipt: Dictionary = request["condition_receipt"]
	var destination_record: Dictionary = request["destination_record"]
	var issuer: Dictionary = action_receipt["transaction_issuer_receipt"]
	var causal_receipt: Dictionary = live["causal_day_instance_issuer_receipt"]
	var stages: Array = []
	for index: int in range(CONDITION_HOSPITAL_PLAN.STAGE_IDS.size()):
		var stage_id := str(CONDITION_HOSPITAL_PLAN.STAGE_IDS[index])
		stages.append({
			"prepared": null,
			"receipt": null,
			"stage_id": stage_id,
			"stage_identity": null,
			"stage_key": receipt_id + ":" + stage_id,
			"state": "pending",
		})
	return {
		"accepted_sources": sources.duplicate(true),
		"action_receipt": action_receipt.duplicate(true),
		"branch_id": str(live["branch_id"]),
		"causal_day_instance": str(live["causal_day_instance"]),
		"causal_day_instance_issuer_receipt": causal_receipt.duplicate(true),
		"condition_receipt": condition_receipt.duplicate(true),
		"cursor": 0,
		"desktop_timeline_generation": int(live["desktop_timeline_generation"]),
		"destination_record": destination_record.duplicate(true),
		"resolution_kind": CONDITION_HOSPITAL_PLAN.RESOLUTION_KIND,
		"resolution_receipt": acceptance.duplicate(true),
		"run_id": str(live["run_id"]),
		"schema_version": CONDITION_HOSPITAL_PLAN.SCHEMA_VERSION,
		"source_day": int(live["day"]),
		"stages": stages,
		"transaction_id": str(action_receipt["transaction_id"]),
		"transaction_issuer_receipt": issuer.duplicate(true),
	}


# ---- stage helpers ----

## Resolves the active plan and the named stage, or the one refusal that stops the caller.
func _locate_stage(live: Dictionary, request: Dictionary) -> Dictionary:
	var raw: Variant = live["active_condition_hospital_plan"]
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": _fail(&"no_active_plan",
			"no condition-Hospital plan is active on this run", {})}
	var plan: Dictionary = raw
	var resolution_receipt: Dictionary = plan["resolution_receipt"]
	var receipt_id := str(resolution_receipt.get("receipt_id", ""))
	if typeof(request["resolution_receipt_id"]) != TYPE_STRING \
			or str(request["resolution_receipt_id"]) != receipt_id:
		return {"error": _fail(&"resolution_receipt_mismatch",
			"resolution_receipt_id names another resolution than the active plan's", {})}
	if typeof(request["stage_id"]) != TYPE_STRING:
		return {"error": _fail(&"invalid_stage", "stage_id is a String", {})}
	var stage_id := str(request["stage_id"])
	var index: int = CONDITION_HOSPITAL_PLAN.STAGE_IDS.find(stage_id)
	if index < 0:
		return {"error": _fail(&"invalid_stage",
			"stage_id is one of " + str(CONDITION_HOSPITAL_PLAN.STAGE_IDS), {})}
	return {
		"plan": plan,
		"receipt_id": receipt_id,
		"stage_id": stage_id,
		"index": index,
		"cursor": int(plan["cursor"]),
	}


## THE PREPARE-FIRST ORDERING LAW (plan:558). Only an identity this instance issued for this exact
## (resolution_receipt_id, stage_id) is admissible -- stage 4 included, however irreversibly the
## day-advance allocator root was already committed.
func _issued_identity_error(located: Dictionary, offered: Variant) -> Dictionary:
	var key := str(located["receipt_id"]) + ":" + str(located["stage_id"])
	var cached: Variant = _stage_identities.get(key)
	if not (cached is Dictionary):
		return _fail(&"stage_identity_conflict",
			"prepare_stage_identity was never called for stage " + str(located["stage_id"]), {})
	if cached != offered:
		return _fail(&"stage_identity_conflict",
			"the offered stage identity is not the one issued for stage "
				+ str(located["stage_id"]), {})
	return {}


## The frozen eight-key completed-stage receipt and the identity equalities Task 4 owns. The
## per-stage `output` interior is Task 7's, so only its container type is required here.
func _stage_receipt_error(request: Dictionary, located: Dictionary) -> Dictionary:
	var receipt: Dictionary = request["stage_receipt"]
	if _sorted_keys(receipt) != _STAGE_RECEIPT_KEYS:
		return _fail(&"invalid_stage_receipt",
			"a completed stage receipt carries exactly " + str(_STAGE_RECEIPT_KEYS), {})
	var identity: Dictionary = request["stage_identity"]
	if receipt["receipt_id"] != identity.get("child_id"):
		return _fail(&"stage_receipt_conflict",
			"stage_receipt.receipt_id is the issued stage_identity.child_id", {})
	if receipt["receipt_provenance"] != identity.get("provenance"):
		return _fail(&"stage_receipt_conflict",
			"stage_receipt.receipt_provenance is byte-equal to the issued provenance", {})
	if receipt["input_receipt_ids"] != identity.get("input_receipt_ids"):
		return _fail(&"stage_receipt_conflict",
			"stage_receipt.input_receipt_ids is byte-equal to the issued input receipt ids", {})
	if str(receipt["stage_id"]) != str(located["stage_id"]):
		return _fail(&"stage_receipt_conflict",
			"stage_receipt.stage_id is the stage it completes", {})
	if str(receipt["resolution_receipt_id"]) != str(located["receipt_id"]):
		return _fail(&"stage_receipt_conflict",
			"stage_receipt.resolution_receipt_id is its own resolution receipt id", {})
	if typeof(receipt["stage_index"]) != TYPE_INT \
			or int(receipt["stage_index"]) != int(located["index"]):
		return _fail(&"stage_receipt_conflict",
			"stage_receipt.stage_index is the stage's permanent ordinal", {})
	if str(receipt["resolution_kind"]) != CONDITION_HOSPITAL_PLAN.RESOLUTION_KIND:
		return _fail(&"stage_receipt_conflict",
			"stage_receipt.resolution_kind is " + CONDITION_HOSPITAL_PLAN.RESOLUTION_KIND, {})
	if typeof(receipt["output"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_stage_receipt", "stage_receipt.output is a Dictionary", {})
	return {}


static func _candidate_record(lifecycle_candidate: Dictionary, index: int) -> Dictionary:
	var plan: Dictionary = lifecycle_candidate["active_condition_hospital_plan"]
	var stages: Array = plan["stages"]
	return stages[index]


# ---- retirement helpers ----

## RULING T4-P: Task 4 TYPES the two advance projections and Task 7 values them from the stage-4
## output. `target_day` is the same by-exactly-one advance RunLifecycle already enforces.
func _mint_retirement_receipt(plan: Dictionary, receipt_id: String,
		autosave_receipt_id: String) -> Dictionary:
	var digest: Dictionary = CONDITION_HOSPITAL_PLAN.canonical_sha256(plan)
	if not digest.get("ok", false):
		return {"error": _fail(&"noncanonical_plan",
			"the completed plan does not canonicalize: " + _reason(digest), {})}
	var digest_value: Dictionary = digest["value"]
	var stages: Array = plan["stages"]
	var advance: Dictionary = stages[CONDITION_HOSPITAL_PLAN.ADVANCE_DAY_STAGE_INDEX]
	var target_causal_day_instance := ""
	if typeof(advance["prepared"]) == TYPE_DICTIONARY:
		var advance_prepared: Dictionary = advance["prepared"]
		target_causal_day_instance = str(
			advance_prepared.get("target_causal_day_instance", ""))
	var derived: Dictionary = _identity_port.call(&"derive_child", {
		"child_kind": _RETIREMENT_CHILD_KIND,
		"parent_receipt_id": receipt_id,
		"ordinal": CONDITION_HOSPITAL_PLAN.STAGE_COUNT,
		"source_ids": [autosave_receipt_id],
	})
	if not derived.get("ok", false):
		return {"error": _fail(&"identity_derivation_failed",
			"the identity port refused the retirement receipt: " + _reason(derived), {})}
	var identity: Dictionary = derived["value"]
	var provenance: Dictionary = identity["provenance"]
	var source_day := int(plan["source_day"])
	return {"receipt": {
		"autosave_stage_receipt_id": autosave_receipt_id,
		"completed_plan_sha256": str(digest_value["sha256"]),
		"disposition": _RETIREMENT_DISPOSITION,
		"receipt_id": str(identity["child_id"]),
		"receipt_provenance": provenance.duplicate(true),
		"resolution_kind": CONDITION_HOSPITAL_PLAN.RESOLUTION_KIND,
		"resolution_receipt_id": receipt_id,
		"source_day": source_day,
		"target_causal_day_instance": target_causal_day_instance,
		"target_day": source_day + 1,
	}}


## RULING T4-S. prepare_retirement's frozen three-key value carries no before_fingerprint of its
## own, so commit_retirement admits a blank one -- but never as "no claim". A blank fingerprint
## is honoured only for the exact candidate this instance issued, prepared against exactly this
## live state; a nonblank one is the ordinary staleness recheck. Anything else conflicts here,
## before any mutation.
func _retirement_fingerprint_error(live: Dictionary, proposed: Dictionary,
		claimed: Variant) -> Dictionary:
	if typeof(claimed) != TYPE_STRING:
		return _fail(&"invalid_candidate", "before_fingerprint is a String", {})
	if not str(claimed).is_empty():
		return _fingerprint_conflict(claimed, true)
	if typeof(live["active_condition_hospital_plan"]) != TYPE_DICTIONARY:
		return _fail(&"no_active_plan", "no condition-Hospital plan is active to retire", {})
	var active: Dictionary = live["active_condition_hospital_plan"]
	var resolution_receipt: Dictionary = active["resolution_receipt"]
	var cached: Variant = _retirements.get(str(resolution_receipt["receipt_id"]))
	if not (cached is Dictionary):
		return _fail(&"stale_fingerprint",
			"a blank before_fingerprint is honoured only for a candidate this instance issued", {})
	var issued: Dictionary = cached
	if str(issued["prepare_sha"]) != _fingerprint(live):
		return _fail(&"stale_fingerprint",
			"the live lifecycle is not the state this retirement candidate was prepared against",
			{})
	if issued["lifecycle_candidate"] != proposed:
		return _fail(&"stale_fingerprint",
			"the candidate is not byte-identical to the one prepare_retirement issued", {})
	return {}


## The append-only law. A single document cannot witness an append, so this transition is the only
## place a dropped or rewritten history entry is visible at all.
func _history_append_error(live: Dictionary, proposed: Dictionary) -> Dictionary:
	if typeof(proposed.get("condition_hospital_history")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "condition_hospital_history is a Dictionary", {})
	var live_history: Dictionary = live["condition_hospital_history"]
	var proposed_history: Dictionary = proposed["condition_hospital_history"]
	for key: Variant in live_history:
		if not proposed_history.has(key):
			return _fail(&"history_append_only",
				"condition_hospital_history is append-only: " + str(key) + " was dropped", {})
		if proposed_history[key] != live_history[key]:
			return _fail(&"history_append_only",
				"condition_hospital_history is append-only: " + str(key) + " was rewritten", {})
	if typeof(live["active_condition_hospital_plan"]) != TYPE_DICTIONARY:
		return _fail(&"no_active_plan", "no condition-Hospital plan is active to retire", {})
	var active: Dictionary = live["active_condition_hospital_plan"]
	var resolution_receipt: Dictionary = active["resolution_receipt"]
	var receipt_id := str(resolution_receipt["receipt_id"])
	var appended: Array = []
	for key: Variant in proposed_history:
		if not live_history.has(key):
			appended.append(str(key))
	if appended != [receipt_id]:
		return _fail(&"invalid_retirement_candidate",
			"a retirement candidate appends exactly the active plan's own history entry", {})
	if proposed["active_condition_hospital_plan"] != null:
		return _fail(&"invalid_retirement_candidate",
			"a retirement candidate nulls the active plan in the same step", {})
	return {}


# ---- shared helpers ----

func _unconfigured(method: String) -> Dictionary:
	if _run_lifecycle == null or _identity_port == null:
		return _fail(&"not_configured",
			"ConditionHospitalState." + method + " runs only after configure()", {})
	return {}


func _live() -> Dictionary:
	return _run_lifecycle.call(&"to_dict")


## Rechecks the fingerprint and adopts. Returns {} on success, or the one refusal, having mutated
## nothing on every refusing path.
func _adopt(candidate: Dictionary, fingerprint_required: bool) -> Dictionary:
	if typeof(candidate["lifecycle_candidate"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "lifecycle_candidate is a Dictionary", {})
	var stale := _fingerprint_conflict(candidate["before_fingerprint"], fingerprint_required)
	if not stale.is_empty():
		return stale
	var prepared: Dictionary = _run_lifecycle.call(&"prepare_restore",
		candidate["lifecycle_candidate"])
	if not prepared.get("ok", false):
		return _fail(&"invalid_lifecycle_candidate",
			"the candidate is not a restorable lifecycle: " + _reason(prepared), {})
	var value: Dictionary = prepared["value"]
	var committed: Dictionary = _run_lifecycle.call(&"commit_restore", value["candidate"])
	if not committed.get("ok", false):
		return _fail(&"restore_failed",
			"the lifecycle refused the validated candidate: " + _reason(committed), {})
	return {}


func _fingerprint_conflict(claimed: Variant, required: bool) -> Dictionary:
	if typeof(claimed) != TYPE_STRING:
		return _fail(&"invalid_candidate", "before_fingerprint is a String", {})
	var value := str(claimed)
	if value.is_empty():
		if required:
			return _fail(&"invalid_candidate", "before_fingerprint is a nonblank String", {})
		return {}
	if value != _fingerprint(_live()):
		return _fail(&"stale_fingerprint",
			"before_fingerprint no longer names the live lifecycle", {})
	return {}


## A backup may only be rolled back FROM the state a later commit produced, and only once.
func _arm_open_captures() -> void:
	var digest := _fingerprint(_live())
	for entry: Dictionary in _captures:
		if not bool(entry["closed"]) and str(entry["expected_sha"]).is_empty():
			entry["expected_sha"] = digest


## The one canonical-JSON SHA-256 recipe this slice shares; never a second hash.
static func _fingerprint(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()


static func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


static func _detached(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value


static func _reason(envelope: Dictionary) -> String:
	return str(envelope.get("message", envelope.get("code", "")))


static func _ok(value: Dictionary, receipt: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": receipt}


## Private so no public-surface census ever sees it.
func _not_implemented(method: String) -> Dictionary:
	return _fail(&"not_implemented",
		"ConditionHospitalState." + method + " is Amendment Plan 03 Task 4 Step 2 work", {})


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
