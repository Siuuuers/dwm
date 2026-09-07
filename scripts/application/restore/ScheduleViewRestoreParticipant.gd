class_name ScheduleViewRestoreParticipant
extends RefCounted

## The saved-ScheduleView restore participant (Amendment Plan 03 Task 4, dwm-oyo.3).
##
## The fourth of the nine live participants, between desktop_board and profile. It follows the
## DesktopConsequenceRestoreParticipant / DesktopBoardRestoreParticipant idiom: prepare() is pure and
## never touches the live controller, SaveManager captures every participant before any apply, and
## rollback_silent is the exact inverse of apply_silent.
##
## ENVELOPE. The four-key {ok, code, message, details} shape, not the sibling participants' three-key
## one, because this participant returns controller and ScheduleViewState failures VERBATIM and those
## are four-key. Two failure shapes out of one participant would be worse than this deviation, and
## SaveManager reads only `ok` and `value`.
##
## ENFORCED BY ABSENCE. No apply_continuation_remap (the lifecycle remap hop belongs to `run`
## alone); no read or write of snapshot["lifecycle"] or any of its plan/history/handoff members; no
## read or write of committed_schedule; no GameState reference; no derive_child call, which would
## force a fourteenth entry into the frozen thirteen-producer census.
##
## The injected issuer and remapper are CONTRACT-ONLY at runtime: both are held for the
## four-argument construction contract and NEITHER is ever called. All remapping happens inside
## DesktopContinuationRemapper.prepare(), driven by DesktopIdentityAllocationRestoreParticipant,
## before this participant's plan is rebuilt from the already-remapped snapshot; and nothing here
## mints an identity, so the issuer has no caller of its own.
##
## SEMANTIC WARNING LAWS. ScheduleViewState owns the view envelope, the append-only departure ledger
## and every delegated entry law, and deliberately carries no warning law; prepare() adds the three a
## restore boundary needs. Every stored preimage rehashes to its own fingerprint, every stored
## context still passes ScheduleWarningPolicy, and every warning map is keyed by its own record. A
## stored record is judged by its own bytes alone: no identity child and no provenance is rebuilt
## here, so a record re-pinned around a changed context stands or falls on what it stores.

const REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
const VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
## The warning context law, and the writer whose canonical text the stored fingerprints rehash.
const WARNING_POLICY := preload("res://scripts/domain/schedule/ScheduleWarningPolicy.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## Exact prepare() input keys (sorted): a participant is given only its own slice.
const _PREPARE_INPUT_KEYS: Array[String] = ["registry_fingerprint", "schedule_view"]
## Exact prepare_new_run() input keys (sorted).
const _NEW_RUN_INPUT_KEYS: Array[String] = [
	"causal_day_instance", "causal_day_instance_issuer_receipt", "day", "registry_fingerprint",
	"run_id",
]

var _controller: Object = null
var _registry: Object = null
var _issuer: Object = null
var _remapper: Object = null


## All four arguments are part of the construction contract (plan:561) and NONE carries a default: a
## three-argument construction the plan does not authorize would otherwise pass silently.
func _init(controller: Object, registry: Object, issuer: Object, remapper: Object) -> void:
	_controller = controller
	_registry = registry
	_issuer = issuer
	_remapper = remapper


## Pure. Never touches the live controller. The value is exactly
## {schedule_view_plan: {candidate: <detached view>}}.
func prepare(input: Dictionary) -> Dictionary:
	var keys: Array = input.keys()
	keys.sort()
	if keys != _PREPARE_INPUT_KEYS:
		return _fail(&"invalid_schedule_view_input",
			"prepare() takes exactly " + str(_PREPARE_INPUT_KEYS), {"field": "keys"})
	var raw: Variant = input["schedule_view"]
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_view_input", "schedule_view is a Dictionary",
			{"field": "schedule_view"})
	# ScheduleViewState owns the envelope, the ledger, the expected fingerprint and every delegated
	# ScheduleRules action law. Its refusal is returned VERBATIM, so no code is re-raised here under
	# a second name and the caller reads one vocabulary.
	var validated: Dictionary = VIEW_STATE.validate(raw as Dictionary, _registry,
		input["registry_fingerprint"])
	if not validated.get("ok", false):
		return validated
	# validate() answers a deep copy, which IS the detachment the plan requires: a later edit of the
	# caller's own view can never reach the prepared candidate, and the input is never written.
	var candidate: Dictionary = (validated["value"] as Dictionary)["view"]
	var latch := _latch_error(candidate)
	if not latch.is_empty():
		return latch
	var warnings := _warning_error(candidate)
	if not warnings.is_empty():
		return warnings
	return _plan_ok(candidate)


## Builds the fresh empty view for a New Run. The value carries the plan and NOTHING else -- no
## run-level member of any kind. run_id and the causal-day issuer receipt are validation-only: they
## prove the caller has a run and an allocation, and neither is ever stored in the view.
func prepare_new_run(input: Dictionary) -> Dictionary:
	var keys: Array = input.keys()
	keys.sort()
	if keys != _NEW_RUN_INPUT_KEYS:
		return _fail(&"invalid_schedule_view_new_run_input",
			"prepare_new_run() takes exactly " + str(_NEW_RUN_INPUT_KEYS), {"field": "keys"})
	if str(input["run_id"]).strip_edges().is_empty():
		return _fail(&"invalid_run_id", "a nonblank run id is required", {"field": "run_id"})
	var receipt: Variant = input["causal_day_instance_issuer_receipt"]
	if typeof(receipt) != TYPE_DICTIONARY or (receipt as Dictionary).is_empty():
		return _fail(&"invalid_causal_day_instance_issuer_receipt",
			"a nonempty causal day instance issuer receipt is required",
			{"field": "causal_day_instance_issuer_receipt"})
	# A New Run builds no entry, so there is no ScheduleViewState.validate pass to carry the
	# fingerprint law; the participant proves the same fact against the injected registry itself.
	var raw_expected: Variant = input["registry_fingerprint"]
	# RULING T4-AJ item 18 (K delta d3): a non-null expectation that is not a nonempty String is the
	# same malformation ScheduleViewState.validate refuses, under the same code and wording, so one
	# fact carries one code across the participant.
	if raw_expected != null and (typeof(raw_expected) != TYPE_STRING or str(raw_expected).is_empty()):
		return _fail(&"invalid_expected_fingerprint",
			"an expected registry fingerprint must be a nonempty String",
			{"expected": raw_expected})
	var actual := str(_registry.fingerprint())
	# RULING T4-AG: a New Run's committed_schedule.registry_fingerprint is exactly null (the canonical
	# empty aggregate), and a null expectation is legal beside an empty view -- the same law
	# ScheduleViewState.validate carries -- so the empty New-Run view accepts it; any nonnull value
	# must still be the live registry's.
	var expected := actual if raw_expected == null else str(raw_expected)
	if expected != actual:
		return _fail(&"stale_registry_fingerprint",
			"the registry no longer matches the expected fingerprint",
			{"expected": expected, "actual": actual})
	var made: Dictionary = VIEW_STATE.make_empty(int(input["day"]),
		str(input["causal_day_instance"]))
	if not made.get("ok", false):
		return made
	return _plan_ok((made["value"] as Dictionary)["view"])


## Delegates to the controller, translating its day_not_open refusal into a null backup: SaveManager
## captures every participant before any apply, and on a fresh boot no day is open yet. Every other
## refusal passes through unchanged.
func capture() -> Dictionary:
	var captured: Dictionary = _controller.capture()
	if not captured.get("ok", false) and str(captured.get("code", "")) == "day_not_open":
		return {"ok": true, "code": &"ok", "value": {"backup": null}, "receipt": {}}
	return captured


## Installs the prepared candidate through the controller's restore-only whole-view seam.
func apply_silent(plan: Dictionary) -> Dictionary:
	if typeof(plan.get("candidate")) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_view_plan", "apply_silent requires plan.candidate",
			{"field": "candidate"})
	return _controller.install_restored_view(plan["candidate"])


## The exact inverse of apply_silent through the same seam. A null backup -- the one capture()
## writes when no day was open -- restores that unopened state.
func rollback_silent(backup: Dictionary) -> Dictionary:
	var restored: Variant = backup.get("backup")
	if restored == null:
		return _controller.install_restored_view(null)
	if typeof(restored) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_view_backup",
			"rollback_silent requires backup.backup to be a Dictionary or null",
			{"field": "backup"})
	return _controller.install_restored_view(restored as Dictionary)


## A silent no-op: ScheduleViewController declares no signals and presentation refresh is Task 5.
func finalize() -> Dictionary:
	return {"ok": true, "code": &"ok"}


# ---- the laws ScheduleViewState deliberately does not carry ----

## The one success shape both prepare seams answer: the value carries the plan and nothing else.
func _plan_ok(candidate: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"schedule_view_plan": {"candidate": candidate}}}


## The date-entry latch: a persisted date entry can never sit beside a false latch. The same law
## RunSnapshotSchema states at the document boundary, held again here because a candidate can reach
## this seam without passing that schema.
func _latch_error(view: Dictionary) -> Dictionary:
	if bool(view["date_entry_seen"]):
		return {}
	for raw: Variant in view["entries"] as Array:
		if typeof(raw) != TYPE_DICTIONARY:
			continue  # ScheduleRules already refused this; do not double-report
		if str((raw as Dictionary).get("action_kind", "ordinary")) != "ordinary":
			return _fail(&"invalid_schedule_view",
				"date_entry_seen must be true while the view carries a date entry",
				{"field": "date_entry_seen"})
	return {}


## The warning family: the pending record, every attempt receipt under it, and every consumed
## receipt. Each map key is proved against its own record's stored bytes.
func _warning_error(view: Dictionary) -> Dictionary:
	var pending: Variant = view["pending_warning"]
	if pending != null:
		if typeof(pending) != TYPE_DICTIONARY:
			return _warning_fault("pending_warning is null or a Dictionary", "pending_warning")
		var record := pending as Dictionary
		var pending_fault := _warning_record_error(record)
		if not pending_fault.is_empty():
			return pending_fault
		var attempts: Variant = record.get("attempt_receipts")
		if typeof(attempts) != TYPE_DICTIONARY:
			return _warning_fault("attempt_receipts is a Dictionary", "attempt_receipts")
		var attempt_fault := _attempt_error(attempts as Dictionary)
		if not attempt_fault.is_empty():
			return attempt_fault
	var consumed: Dictionary = view["consumed_warning_receipts"]
	for key: Variant in consumed:
		var raw: Variant = consumed[key]
		if typeof(raw) != TYPE_DICTIONARY:
			return _warning_fault("a consumed receipt is a Dictionary",
				"consumed_warning_receipts")
		var terminal := raw as Dictionary
		var fault := _warning_record_error(terminal)
		if not fault.is_empty():
			return fault
		var expected := str(terminal.get("warning_state_fingerprint", "")) + "|" \
				+ str(terminal.get("warning_kind", ""))
		if str(key) != expected:
			return _warning_fault(
				"a consumed receipt is keyed by its own fingerprint, a pipe and its kind",
				"consumed_warning_receipts")
	return {}


## Every attempt receipt obeys the shared record laws and is keyed by its own transaction id: the
## failed-navigation map is an index of transactions, never of anything the caller chooses.
func _attempt_error(attempts: Dictionary) -> Dictionary:
	for key: Variant in attempts:
		var raw: Variant = attempts[key]
		if typeof(raw) != TYPE_DICTIONARY:
			return _warning_fault("an attempt receipt is a Dictionary", "attempt_receipts")
		var attempt := raw as Dictionary
		var fault := _warning_record_error(attempt)
		if not fault.is_empty():
			return fault
		if str(key) != str(attempt.get("transaction_id", "")):
			return _warning_fault("an attempt receipt is keyed by its own transaction id",
				"attempt_receipts")
	return {}


## The three laws every stored warning record shares: a Dictionary preimage carrying a Dictionary
## context, a context ScheduleWarningPolicy still accepts (its refusal returned VERBATIM), and a
## stored fingerprint equal to the lowercase sha256 of the canonical JSON of the WHOLE stored
## preimage -- the record's own bytes, never a preimage rebuilt from live owners.
func _warning_record_error(record: Dictionary) -> Dictionary:
	var raw_preimage: Variant = record.get("warning_fingerprint_preimage")
	if typeof(raw_preimage) != TYPE_DICTIONARY:
		return _warning_fault("the stored preimage is a Dictionary",
			"warning_fingerprint_preimage")
	var preimage := raw_preimage as Dictionary
	var raw_context: Variant = preimage.get("context")
	if typeof(raw_context) != TYPE_DICTIONARY:
		return _warning_fault("the stored preimage carries a Dictionary context", "context")
	var context_check: Dictionary = WARNING_POLICY.validate_context(raw_context as Dictionary)
	if not context_check.get("ok", false):
		return context_check
	var canonical: Dictionary = CANONICAL_JSON.stringify(preimage)
	if not canonical.get("ok", false):
		return _warning_fault("the stored preimage canonicalizes byte-for-byte",
			"warning_fingerprint_preimage")
	if str(record.get("warning_state_fingerprint", "")) != _digest(str(canonical["value"])):
		return _warning_fault("the stored fingerprint rehashes its own stored preimage",
			"warning_state_fingerprint")
	return {}


func _warning_fault(message: String, field: String) -> Dictionary:
	return _fail(&"invalid_warning_receipt", message, {"field": field})


## Lowercase hex sha256, ScheduleWarningPolicy's own digest, so a rehash here and a fingerprint
## minted there are the same function of the same canonical text.
func _digest(canonical: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.to_utf8_buffer())
	return context.finish().hex_encode()


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
