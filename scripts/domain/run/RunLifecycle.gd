class_name RunLifecycle
extends RefCounted

## Pure run lifecycle state machine behind the GameState facade
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 2).

const DAY_RESOLUTION_PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const PLAYING := &"PLAYING"
const ENDING := &"ENDING"
const COMPLETED := &"COMPLETED"

const STATE_NAMES: Array[String] = ["PLAYING", "ENDING", "COMPLETED"]
const LIFECYCLE_KEYS: Array[String] = [
	"active_resolution_plan", "branch_id", "causal_day_instance", "causal_day_instance_issuer_receipt",
	"day", "desktop_timeline_generation", "ending_plan", "restore_provenance", "run_id", "state",
]
const PLAYBACK_SEQUENCE: Array[String] = ["PRIMARY_PENDING", "PRIMARY_PLAYED", "EPILOGUE_PLAYED", "GALLERY_RECORDED"]
const ENDING_PLAN_KEYS: Array[String] = ["ending_id", "epilogue_ending_id", "source_day", "playback_stage", "playback_receipts"]

## Desktop identity added in v4 (Plan 02 Task 6, dwm-p2r.32). `causal_day_instance` and its full
## `causal_day_instance_issuer_receipt` are bound as one inseparable pair everywhere they travel
## (brief line 203): reset() and commit_restore() are the only two places that may replace them, and
## both always replace both fields together, never one alone.
const _ISSUER_RECEIPT_KEYS: Array[String] = ["counter", "namespace", "numeric_value", "purpose", "receipt_id", "token"]
const RESTORE_PROVENANCE_KEYS: Array[String] = [
	"identity_allocation_receipt_id", "remap_receipt_id", "remap_receipt_provenance",
	"restore_transaction_id", "source_branch_id", "source_causal_day_instance",
	"source_desktop_timeline_generation", "source_issuer_observed_counter", "transaction_remap_sha256",
]

var _run_id := ""
var _day := 1
var _state: StringName = PLAYING
var _plan: RefCounted = null
var _ending_plan: Dictionary = {}
var _has_ending_plan := false
var _branch_id := ""
var _desktop_timeline_generation := 0
var _causal_day_instance := ""
var _causal_day_instance_issuer_receipt: Dictionary = {}
var _restore_provenance: Variant = null

## `identity_allocation_receipt` is the committed continuation allocation bundle (brief lines
## 259-283): this extracts the exact `causal_day_instance_issuer_receipt` from it and binds it
## alongside `causal_day_instance` as one pair. Void by design, matching this method's existing
## no-envelope precedent (the OLD one-arg `reset()` never validated anything either): the actual
## enforcement point for a malformed/mismatched bundle is RunSnapshotSchema, run against this
## object's own `to_dict()` output before any checkpoint or save.
func reset(run_id: String, branch_id: String, desktop_timeline_generation: int,
		causal_day_instance: String, identity_allocation_receipt: Dictionary) -> void:
	_run_id = run_id
	_day = 1
	_state = PLAYING
	_plan = null
	_ending_plan = {}
	_has_ending_plan = false
	_branch_id = branch_id
	_desktop_timeline_generation = desktop_timeline_generation
	_causal_day_instance = causal_day_instance
	var receipt: Variant = identity_allocation_receipt.get("causal_day_instance_issuer_receipt")
	_causal_day_instance_issuer_receipt = (receipt as Dictionary).duplicate(true) if typeof(receipt) == TYPE_DICTIONARY else {}
	_restore_provenance = null

## Exactly `{run_id,branch_id,desktop_timeline_generation,causal_day_instance,causal_day_instance_
## issuer_receipt}` as detached primitives (brief line 200).
func get_desktop_identity_context() -> Dictionary:
	return {
		"run_id": _run_id, "branch_id": _branch_id,
		"desktop_timeline_generation": _desktop_timeline_generation,
		"causal_day_instance": _causal_day_instance,
		"causal_day_instance_issuer_receipt": _causal_day_instance_issuer_receipt.duplicate(true),
	}

## The exact members this object's own slice of the enriched identity_allocation_bundle needs
## (Task 6 Phase C, brief lines 259-283/287). `DesktopIdentityAllocationRestoreParticipant` is the
## sole producer: it projects the issuer's raw continuation-allocation candidate into the brief's
## bundle shape and attaches the one `continuation_operation` remap receipt `DesktopContinuation
## Remapper.prepare()` emits (brief line 291) before Run/consequence/board each build their own
## candidate from the same bundle. `transaction_remap_sha256` is NOT carried on the bundle -- this
## object computes it itself, canonically, from the bundle's own `transaction_remap` member, so it
## can never drift from the bytes actually bound.
const _IDENTITY_ALLOCATION_BUNDLE_KEYS: Array[String] = [
	"allocation_receipt_id", "branch_id", "causal_day_instance", "causal_day_instance_issuer_receipt",
	"desktop_timeline_generation", "remap_receipt_id", "remap_receipt_provenance", "run_id",
	"transaction_remap",
]

## Builds this object's restore candidate from a durably-allocated, already-remapped identity
## bundle (Task 6 Phase C). Restore-only: `run_id` must equal this object's OWN live run_id (brief
## line 287, "for restore, run_id ... is validated source provenance rather than newly allocated"),
## never a freshly minted one -- New Run installs identity through reset() instead. Pure: every
## field this reads comes from the bundle or this object's own live state; nothing is mutated.
func prepare_continuation_remap(restore_transaction_id: String, identity_allocation_bundle: Dictionary) -> Dictionary:
	if restore_transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_restore_transaction_id", "restore_transaction_id must be nonblank")
	for key: String in _IDENTITY_ALLOCATION_BUNDLE_KEYS:
		if not identity_allocation_bundle.has(key):
			return _fail(&"invalid_identity_allocation_bundle", "identity_allocation_bundle missing " + key)
	if str(identity_allocation_bundle["run_id"]) != _run_id:
		return _fail(&"identity_allocation_run_id_mismatch",
			"a restore allocation bundle must carry the existing run_id, never a newly allocated one")
	if typeof(identity_allocation_bundle["allocation_receipt_id"]) != TYPE_STRING \
			or str(identity_allocation_bundle["allocation_receipt_id"]).strip_edges().is_empty():
		return _fail(&"invalid_identity_allocation_bundle", "allocation_receipt_id must be nonblank")
	if typeof(identity_allocation_bundle["remap_receipt_id"]) != TYPE_STRING \
			or str(identity_allocation_bundle["remap_receipt_id"]).strip_edges().is_empty():
		return _fail(&"invalid_identity_allocation_bundle", "remap_receipt_id must be nonblank")
	if typeof(identity_allocation_bundle["remap_receipt_provenance"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_identity_allocation_bundle", "remap_receipt_provenance must be an object")
	var remap_hash := _canonical_sha256(identity_allocation_bundle["transaction_remap"])
	if remap_hash.is_empty():
		return _fail(&"transaction_remap_not_canonicalizable", "transaction_remap is not canonically representable")
	var receipt: Variant = identity_allocation_bundle["causal_day_instance_issuer_receipt"]
	var candidate := to_dict()
	candidate["branch_id"] = str(identity_allocation_bundle["branch_id"])
	candidate["desktop_timeline_generation"] = int(identity_allocation_bundle["desktop_timeline_generation"])
	candidate["causal_day_instance"] = str(identity_allocation_bundle["causal_day_instance"])
	candidate["causal_day_instance_issuer_receipt"] = (receipt as Dictionary).duplicate(true) if typeof(receipt) == TYPE_DICTIONARY else {}
	candidate["restore_provenance"] = {
		"source_branch_id": _branch_id,
		"source_desktop_timeline_generation": _desktop_timeline_generation,
		"source_causal_day_instance": _causal_day_instance,
		"source_issuer_observed_counter": int(_causal_day_instance_issuer_receipt.get("counter", 0)),
		"restore_transaction_id": restore_transaction_id,
		"identity_allocation_receipt_id": str(identity_allocation_bundle["allocation_receipt_id"]),
		"transaction_remap_sha256": remap_hash,
		"remap_receipt_id": str(identity_allocation_bundle["remap_receipt_id"]),
		"remap_receipt_provenance": (identity_allocation_bundle["remap_receipt_provenance"] as Dictionary).duplicate(true),
	}
	return prepare_restore(candidate)

## The validated candidate `prepare_continuation_remap()` returned is already a complete, exact
## lifecycle dict, so committing it is exactly what commit_restore() already does -- no separate
## adoption path is needed.
func commit_continuation_remap(candidate: Dictionary) -> Dictionary:
	return commit_restore(candidate)

func get_day() -> int:
	return _day

func get_state() -> StringName:
	return _state

## Begins a day resolution from the CANONICAL COMMITTED SCHEDULE (Plan 01 Task 6 Steps 6.3/6.6,
## dwm-p2r.13). The transport names `committed_schedule` explicitly and carries the real aggregate;
## the caller may no longer substitute a synthetic empty array for the entries it could not supply.
## The registry-derived `route_plan` and the two receipt ids ride with the aggregate so the plan can
## persist them (plan line 963) without re-deriving cost, route or effects from anything.
func begin_day_resolution(
	resolution_id: String,
	committed_schedule: Dictionary,
	route_plan: Array = [],
	schedule_commit_receipt_id: Variant = null,
	board_fate_receipt_id: Variant = null,
	resolution_start: Dictionary = {},
) -> Dictionary:
	if _state != PLAYING:
		return _fail(&"invalid_state", "begin_day_resolution requires PLAYING")
	if _has_ending_plan:
		return _fail(&"invalid_state", "begin_day_resolution requires no ending plan")
	# Safe plan succession (dwm-7e6 erratum). A COMPLETED plan is never cleared on completion: the
	# coordinator calls resume_resolution() immediately after to observe plan_complete, and stage
	# receipts exist only inside active_resolution_plan. It is replaced atomically, and only by a
	# VALID new plan, so invalid input can never destroy the previous day's completed receipts.
	# IDEMPOTENCE KEYS OFF THE DONE COMMAND, not the resolution id (dwm-p2r.18). On the minted path
	# `resolution_id` is an issuer token, so a replayed Done command arrives carrying a DIFFERENT
	# freshly minted token; comparing tokens would make every replay look like a new resolution and
	# silently re-run a day that had already resolved.
	var command_id := str(resolution_start.get("command_id", resolution_id))
	if _plan != null:
		if _plan.get_command_id() == command_id:
			# Repeating the same Done command stays idempotent, complete or incomplete.
			return {"ok": true, "code": &"ok", "value": {"plan": _plan.to_dict()}}
		if not _plan.is_complete():
			# A genuinely concurrent, unfinished resolution still conflicts.
			return {"ok": false, "code": &"resolution_conflict", "message": _plan.get_resolution_id()}
	var created: Dictionary = DAY_RESOLUTION_PLAN.create(
		resolution_id, _day, committed_schedule.duplicate(true), route_plan.duplicate(true),
		schedule_commit_receipt_id, board_fate_receipt_id, resolution_start.duplicate(true))
	if not created.get("ok", false):
		return created
	_plan = created["value"]["plan"]
	return {"ok": true, "code": &"ok", "value": {"plan": _plan.to_dict()}}


## PURE preparation (Plan 01 Task 6 Step 6.5, dwm-p2r.13). Runs the identical admission law as
## begin_day_resolution and produces the same plan, but touches NOTHING: `_plan` is untouched on
## every path, including the idempotent-replay and conflict paths. A reversible start port calls
## this, decides whether to proceed, and only then commits -- so a participant that fails after
## preparation leaves no half-begun resolution behind.
##
## `already_active` distinguishes the two success shapes the caller must treat differently: true
## means this is the same resolution replayed and the candidate is the EXISTING plan, so committing
## it is a no-op; false means the candidate is genuinely new.
func prepare_day_resolution(
	resolution_id: String,
	committed_schedule: Dictionary,
	route_plan: Array = [],
	schedule_commit_receipt_id: Variant = null,
	board_fate_receipt_id: Variant = null,
	resolution_start: Dictionary = {},
) -> Dictionary:
	if _state != PLAYING:
		return _fail(&"invalid_state", "prepare_day_resolution requires PLAYING")
	if _has_ending_plan:
		return _fail(&"invalid_state", "prepare_day_resolution requires no ending plan")
	# Same command-keyed idempotence as begin_day_resolution above; the two must agree or a
	# prepare/commit pair could disagree about whether a resolution is already active.
	var command_id := str(resolution_start.get("command_id", resolution_id))
	if _plan != null:
		if _plan.get_command_id() == command_id:
			return {"ok": true, "code": &"ok",
				"value": {"candidate": _plan.to_dict(), "already_active": true}}
		if not _plan.is_complete():
			return {"ok": false, "code": &"resolution_conflict",
				"message": _plan.get_resolution_id()}
	var created: Dictionary = DAY_RESOLUTION_PLAN.create(
		resolution_id, _day, committed_schedule.duplicate(true), route_plan.duplicate(true),
		schedule_commit_receipt_id, board_fate_receipt_id, resolution_start.duplicate(true))
	if not created.get("ok", false):
		return created
	return {"ok": true, "code": &"ok", "value": {
		"candidate": (created["value"]["plan"] as RefCounted).to_dict(),
		"already_active": false,
	}}


## NARROW capture of the active plan alone (Step 6.5). Deliberately NOT to_dict(): a rollback that
## restored run_id, day, state or the ending plan would let a failed day-resolution participant undo
## an unrelated concurrent change. Only `active_resolution_plan` is captured, so only it can be
## restored.
func capture_active_plan() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {
		"active_resolution_plan": _plan.to_dict() if _plan != null else null,
	}}


## Installs a prepared candidate. Silent: it changes only `_plan` and emits nothing.
func commit_active_plan(candidate: Dictionary) -> Dictionary:
	var restored: Dictionary = DAY_RESOLUTION_PLAN.from_dict(candidate)
	if not restored.get("ok", false):
		return restored
	var plan: RefCounted = restored["value"]["plan"]
	var window_error: String = DAY_RESOLUTION_PLAN.active_source_day_error(
		int(plan.get_source_day()), _day, candidate)
	if window_error != "":
		return _fail(&"invalid_candidate", window_error)
	_plan = plan
	return {"ok": true, "code": &"ok", "value": {"plan": _plan.to_dict()}}


## Restores exactly what capture_active_plan() returned, including a null active plan. Accepting
## null is required rather than tolerated: rolling back the FIRST resolution of a run must be able
## to put the lifecycle back to having no plan at all.
func rollback_active_plan(backup: Dictionary) -> Dictionary:
	if not backup.has("active_resolution_plan"):
		return _fail(&"invalid_backup", "backup must carry active_resolution_plan")
	var saved: Variant = backup["active_resolution_plan"]
	if saved == null:
		_plan = null
		return {"ok": true, "code": &"ok", "value": {"active_resolution_plan": null}}
	if typeof(saved) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "active_resolution_plan must be null or an object")
	var restored: Dictionary = DAY_RESOLUTION_PLAN.from_dict(saved as Dictionary)
	if not restored.get("ok", false):
		return restored
	_plan = restored["value"]["plan"]
	return {"ok": true, "code": &"ok", "value": {"active_resolution_plan": _plan.to_dict()}}

func resume_resolution() -> Dictionary:
	if _state == COMPLETED:
		return _fail(&"invalid_state", "resume_resolution is unavailable after COMPLETED")
	if _plan == null:
		return _fail(&"no_active_plan", "resume_resolution requires an active plan")
	var cursor: Dictionary = _plan.get_next_incomplete_stage()
	return cursor

func begin_next_stage() -> Dictionary:
	var cursor := resume_resolution()
	if not cursor.get("ok", false):
		return cursor
	if not cursor["value"]["has_stage"]:
		return _fail(&"plan_complete", "no incomplete stage")
	var record: Dictionary = cursor["value"]["stage"]
	var begun: Dictionary
	if record.has("substage_id"):
		begun = _plan.begin_substage(str(record["stage_id"]), str(record["substage_id"]), str(record["transaction_id"]))
	else:
		begun = _plan.begin_stage(str(record["stage_id"]), str(record["transaction_id"]))
	return begun

func complete_active_stage(transaction_id: String, receipt: Dictionary) -> Dictionary:
	if _state == COMPLETED:
		return _fail(&"invalid_state", "complete_active_stage is unavailable after COMPLETED")
	if _plan == null:
		return _fail(&"no_active_plan", "complete_active_stage requires an active plan")
	var record: Dictionary = _plan.find_record_by_transaction(transaction_id)
	if record.is_empty():
		return _fail(&"unknown_transaction", transaction_id)
	var fresh_completion: bool = str(record["state"]) == "active"
	if fresh_completion and record["kind"] == "stage":
		var validation := _validate_owner_receipt(str(record["stage_id"]), receipt)
		if not validation.get("ok", false):
			return validation
	var completed: Dictionary
	if record["kind"] == "substage":
		completed = _plan.complete_substage(str(record["stage_id"]), str(record["substage_id"]), transaction_id, receipt)
	else:
		completed = _plan.complete_stage(str(record["stage_id"]), transaction_id, receipt)
	if not completed.get("ok", false) or not fresh_completion or record["kind"] != "stage":
		return completed
	match str(record["stage_id"]):
		"increment_day":
			_day += 1
		"enter_ending":
			_state = ENDING
			_ending_plan = (receipt["value"]["ending_plan"] as Dictionary).duplicate(true)
			_has_ending_plan = true
	return completed

func enter_ending(ending_plan: Dictionary) -> Dictionary:
	if _state != PLAYING:
		return _fail(&"invalid_state", "enter_ending requires PLAYING")
	if _day != 7:
		return _fail(&"invalid_state", "enter_ending requires Day 7")
	var error := _validate_ending_plan(ending_plan)
	if error != "":
		return _fail(&"invalid_ending_plan", error)
	_state = ENDING
	_ending_plan = ending_plan.duplicate(true)
	_has_ending_plan = true
	return {"ok": true, "code": &"ok"}

func complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary:
	if _state != ENDING:
		return _fail(&"invalid_state", "playback requires ENDING")
	var expected := String(expected_stage)
	if expected not in PLAYBACK_SEQUENCE:
		return _fail(&"invalid_playback_stage", expected)
	if str(_ending_plan["playback_stage"]) != expected:
		return _fail(&"playback_stage_mismatch", "expected %s, current %s" % [expected, str(_ending_plan["playback_stage"])])
	if expected == "GALLERY_RECORDED":
		return _fail(&"invalid_playback_stage", "no edge beyond GALLERY_RECORDED")
	if transaction_id != "ending:" + expected:
		return _fail(&"transaction_mismatch", transaction_id)
	var receipt_keys := receipt.keys()
	if receipt_keys != ["value"] or typeof(receipt["value"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_receipt", "receipt must be {\"value\": Dictionary}")
	var next := PLAYBACK_SEQUENCE[PLAYBACK_SEQUENCE.find(expected) + 1]
	_ending_plan["playback_stage"] = next
	(_ending_plan["playback_receipts"] as Dictionary)[expected] = receipt.duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"playback_stage": next}}

func complete_ending() -> Dictionary:
	if _state != ENDING:
		return _fail(&"invalid_state", "complete_ending requires ENDING")
	if str(_ending_plan["playback_stage"]) != "GALLERY_RECORDED":
		return _fail(&"playback_incomplete", "complete_ending requires GALLERY_RECORDED")
	_state = COMPLETED
	return {"ok": true, "code": &"ok"}

func to_dict() -> Dictionary:
	return {
		"run_id": _run_id,
		"day": _day,
		"state": String(_state),
		"active_resolution_plan": _plan.to_dict() if _plan != null else null,
		"ending_plan": _ending_plan.duplicate(true) if _has_ending_plan else null,
		"branch_id": _branch_id,
		"desktop_timeline_generation": _desktop_timeline_generation,
		"causal_day_instance": _causal_day_instance,
		"causal_day_instance_issuer_receipt": _causal_day_instance_issuer_receipt.duplicate(true),
		"restore_provenance": _dup_or_null(_restore_provenance),
	}

static func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()

static func _dup_or_null(value: Variant) -> Variant:
	if value == null:
		return null
	return (value as Dictionary).duplicate(true)

func prepare_restore(data: Dictionary) -> Dictionary:
	var error := _validate_lifecycle_dict(data)
	if error != "":
		return _fail(&"invalid_lifecycle", error)
	return {"ok": true, "code": &"ok", "value": {"candidate": data.duplicate(true)}}

func commit_restore(candidate: Dictionary) -> Dictionary:
	var error := _validate_lifecycle_dict(candidate)
	if error != "":
		return _fail(&"invalid_candidate", error)
	var plan: RefCounted = null
	if candidate["active_resolution_plan"] != null:
		var restored: Dictionary = DAY_RESOLUTION_PLAN.from_dict(candidate["active_resolution_plan"])
		if not restored.get("ok", false):
			return restored
		plan = restored["value"]["plan"]
	_run_id = str(candidate["run_id"])
	_day = int(candidate["day"])
	_state = StringName(str(candidate["state"]))
	_plan = plan
	_has_ending_plan = candidate["ending_plan"] != null
	_ending_plan = (candidate["ending_plan"] as Dictionary).duplicate(true) if _has_ending_plan else {}
	_branch_id = str(candidate["branch_id"])
	_desktop_timeline_generation = int(candidate["desktop_timeline_generation"])
	_causal_day_instance = str(candidate["causal_day_instance"])
	_causal_day_instance_issuer_receipt = (candidate["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true)
	_restore_provenance = _dup_or_null(candidate["restore_provenance"])
	return {"ok": true, "code": &"ok"}

func _validate_lifecycle_dict(data: Dictionary) -> String:
	var keys := data.keys()
	keys.sort()
	var expected := LIFECYCLE_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return "unexpected lifecycle keys: " + str(keys)
	if str(data["run_id"]).is_empty():
		return "run_id must be nonempty"
	if typeof(data["day"]) != TYPE_INT or int(data["day"]) < 1 or int(data["day"]) > 7:
		return "day must be an integer 1..7: " + str(data["day"])
	var state := str(data["state"])
	if state not in STATE_NAMES:
		return "unknown state: " + state
	var desktop_identity_error := _validate_desktop_identity(data)
	if desktop_identity_error != "":
		return desktop_identity_error
	if data["active_resolution_plan"] != null:
		if typeof(data["active_resolution_plan"]) != TYPE_DICTIONARY:
			return "active_resolution_plan must be null or an object"
		var restored: Dictionary = DAY_RESOLUTION_PLAN.from_dict(data["active_resolution_plan"])
		if not restored.get("ok", false):
			return "invalid active_resolution_plan: " + str(restored.get("message", restored.get("code", "")))
		# Defers to DayResolutionPlan, the single authority for the active-plan day window (dwm-7e6).
		# Without this, a snapshot written mid-resolution would pass RunSnapshotSchema and then be
		# rejected here on restore -- a save you can write but never load.
		var window_error := DAY_RESOLUTION_PLAN.active_source_day_error(
			int((restored["value"]["plan"] as RefCounted).get_source_day()), int(data["day"]),
			data["active_resolution_plan"] as Dictionary)
		if window_error != "":
			return window_error
	if data["ending_plan"] == null:
		if state != "PLAYING":
			return state + " requires an ending plan"
	else:
		if typeof(data["ending_plan"]) != TYPE_DICTIONARY:
			return "ending_plan must be null or an object"
		var ending_error := _validate_ending_plan(data["ending_plan"])
		if ending_error != "":
			return ending_error
		if state == "PLAYING":
			return "PLAYING requires a null ending plan"
		if int(data["day"]) != 7:
			return "an ending plan requires day 7"
		if state == "COMPLETED" and str((data["ending_plan"] as Dictionary)["playback_stage"]) != "GALLERY_RECORDED":
			return "COMPLETED requires GALLERY_RECORDED playback"
	return ""

## Structural self-consistency only, mirroring DesktopConsequenceState's own issuer-provenance
## check (this object has no root-store access, so it cannot verify against the ledger -- that
## happens at the point of issuance): `branch_id`/`causal_day_instance` nonblank; the receipt has
## the exact frozen issuer-receipt shape, purpose `causal_day_instance`, and a token equal to the
## adjacent field; `restore_provenance` is null or carries the exact frozen member set.
static func _validate_desktop_identity(data: Dictionary) -> String:
	if typeof(data["branch_id"]) != TYPE_STRING or str(data["branch_id"]).strip_edges().is_empty():
		return "branch_id must be a nonblank String"
	if typeof(data["desktop_timeline_generation"]) != TYPE_INT or int(data["desktop_timeline_generation"]) < 0:
		return "desktop_timeline_generation must be a nonnegative integer"
	if typeof(data["causal_day_instance"]) != TYPE_STRING or str(data["causal_day_instance"]).strip_edges().is_empty():
		return "causal_day_instance must be a nonblank String"
	if typeof(data["causal_day_instance_issuer_receipt"]) != TYPE_DICTIONARY:
		return "causal_day_instance_issuer_receipt must be an object"
	var receipt: Dictionary = data["causal_day_instance_issuer_receipt"]
	var receipt_keys: Array = receipt.keys()
	receipt_keys.sort()
	var expected_receipt_keys: Array = _ISSUER_RECEIPT_KEYS.duplicate()
	expected_receipt_keys.sort()
	if receipt_keys != expected_receipt_keys:
		return "causal_day_instance_issuer_receipt has an unexpected member set"
	if str(receipt.get("purpose", "")) != "causal_day_instance":
		return "causal_day_instance_issuer_receipt.purpose must be causal_day_instance"
	if str(receipt.get("token", "")) != str(data["causal_day_instance"]):
		return "causal_day_instance_issuer_receipt.token must equal causal_day_instance"
	if data["restore_provenance"] != null:
		if typeof(data["restore_provenance"]) != TYPE_DICTIONARY:
			return "restore_provenance must be null or an object"
		var provenance: Dictionary = data["restore_provenance"]
		var provenance_keys: Array = provenance.keys()
		provenance_keys.sort()
		var expected_provenance_keys: Array = RESTORE_PROVENANCE_KEYS.duplicate()
		expected_provenance_keys.sort()
		if provenance_keys != expected_provenance_keys:
			return "restore_provenance has an unexpected member set"
	return ""

static func _validate_ending_plan(plan: Dictionary) -> String:
	var keys := plan.keys()
	keys.sort()
	var expected := ENDING_PLAN_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return "unexpected ending-plan keys: " + str(keys)
	if str(plan["ending_id"]).is_empty():
		return "ending_id must be nonempty"
	if typeof(plan["epilogue_ending_id"]) != TYPE_STRING:
		return "epilogue_ending_id must be a String"
	if typeof(plan["source_day"]) != TYPE_INT or int(plan["source_day"]) != 7:
		return "ending-plan source_day must be 7"
	if str(plan["playback_stage"]) not in PLAYBACK_SEQUENCE:
		return "unknown playback_stage: " + str(plan["playback_stage"])
	if typeof(plan["playback_receipts"]) != TYPE_DICTIONARY:
		return "playback_receipts must be a Dictionary"
	return ""

func _validate_owner_receipt(stage_id: String, receipt: Dictionary) -> Dictionary:
	var receipt_keys := receipt.keys()
	if receipt_keys != ["value"] or typeof(receipt["value"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_receipt", "receipt must be {\"value\": Dictionary}")
	var value: Dictionary = receipt["value"]
	match stage_id:
		"invitation_rollover":
			if typeof(value.get("target_day")) != TYPE_INT or int(value["target_day"]) != _day + 1:
				return _fail(&"invalid_receipt", "rollover target_day must equal source_day + 1")
		"increment_day":
			if _day < 1 or _day > 6:
				return _fail(&"invalid_receipt", "increment_day permitted only from days 1..6")
			if typeof(value.get("day")) != TYPE_INT or int(value["day"]) != _day + 1:
				return _fail(&"invalid_receipt", "increment_day receipt must carry day = source + 1")
		"resolve_ending_plan", "enter_ending":
			if typeof(value.get("ending_plan")) != TYPE_DICTIONARY:
				return _fail(&"invalid_receipt", stage_id + " receipt requires an ending_plan")
			var error := _validate_ending_plan(value["ending_plan"])
			if error != "":
				return _fail(&"invalid_ending_plan", error)
	return {"ok": true, "code": &"ok"}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
