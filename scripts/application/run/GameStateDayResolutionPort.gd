class_name GameStateDayResolutionPort
extends RefCounted

## Production state port bridging DayResolutionCoordinator to the GameState
## facade and its RunLifecycle
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 3).
##
## Phase 2R scope note: every stage completes immediately with a
## deterministic owner receipt; registered external route commands and real
## schedule-substage receipts arrive with the Plan04 integration tasks.

## Real snapshot production (dwm-7e6). GameState supplies the inner snapshot_input through its pure
## capture seam; the five non-GameState fields arrive through injected Callables, mirroring the
## SaveManagerNarrativeCheckpointPort provider seam. Unconfigured, safe defaults keep the SHAPE
## complete so no caller can silently regress to the old {run_id, day} stub.
const RUN_LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
## The registry and its pure projector. Route, effects, kind and participants come ONLY from the
## registry the committed aggregate names by fingerprint -- never from a caller field or an
## action-id parse (Plan 01 global constraint; Task 7 Step 7.5).
const SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const SCHEDULE_RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
## The pure Schedule-Done Hospital owner (Task 7 Step 7.3).
const HOSPITAL_RULES := preload("res://scripts/domain/hospital/HospitalRules.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
## The canonical JSON writer every Plan-01 identity projection goes through, and the plan module
## whose frozen stage arrays own `stage_index` (dwm-p2r.18).
const SCHEDULE_STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const DAY_RESOLUTION_PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")

const CHECKPOINT_PROVIDER_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint", "route_id",
]
const DEFAULT_ROUTE_ID := "main"
const DEFAULT_CONTENT_VERSION := 1

var _game_state: Object = null
var _checkpoint_providers: Dictionary = {}
var _provider_identity: Dictionary = {}

## The one configured Day-7 provenance service, injected by Bootstrap; never constructed here.
var _day7_provenance: Object = null

## The exact `.16` issuer and the retained DayResolutionStartPort (dwm-p2r.18). Together they turn a
## Done command into the resolution ROOT and its `P01.day_resolution.start` receipt -- the two
## records every presentation child is derived under.
var _identity_issuer: Object = null
var _day_resolution_start_port: Object = null

## The Plan-02 desktop-consequence inputs a Schedule-Done resolution consumes but does not own:
## the board-fate receipt bound by `P01.day_resolution.start`, and the condition receipt projected
## by `P01.hospital.resolution`.
##
## DELIBERATELY UNCONFIGURED IN PHASE 2R (DEVIATION-5, user-approved on dwm-p2r.18). `dwm-p2r.9`
## never delivered the integrated `DesktopBoardFatePort`, and Plan 01 line 1303 forbids this plan
## from implementing desktop board fate, so there is no lawful production source for either record
## yet. This seam is the handoff point, exactly as `DatingPresentationPort` is for `dwm-oyo.4`:
## Bootstrap constructs nothing for it, and a resolution that genuinely needs a presentation fails
## closed naming the missing input rather than silently skipping the presentation.
var _desktop_consequence_source: Object = null

const _ISSUER_METHODS: Array[String] = ["issue", "verify_issued", "derive_child", "validate_child"]
const _START_PORT_METHODS: Array[String] = ["prepare_from_committed_schedule"]
const _CONSEQUENCE_SOURCE_METHODS: Array[String] = [
	"resolve_board_fate_receipt", "resolve_condition_receipt",
]
const ROOT_PURPOSE := &"transaction_id"


func _init(game_state: Object) -> void:
	_game_state = game_state

func configure_checkpoint_providers(providers: Dictionary) -> Dictionary:
	if typeof(providers) != TYPE_DICTIONARY or providers.size() != CHECKPOINT_PROVIDER_KEYS.size():
		return {"ok": false, "code": &"invalid_checkpoint_providers", "message": "providers must be exactly " + str(CHECKPOINT_PROVIDER_KEYS), "details": {}}
	var identity := {}
	for key in CHECKPOINT_PROVIDER_KEYS:
		if not providers.has(key) or typeof(providers[key]) != TYPE_CALLABLE:
			return {"ok": false, "code": &"invalid_checkpoint_providers", "message": "missing or non-Callable provider: " + key, "details": {}}
		var callable: Callable = providers[key]
		if not callable.is_valid() or callable.get_object_id() == 0 or callable.get_argument_count() != 0:
			return {"ok": false, "code": &"invalid_checkpoint_providers", "message": "provider must be a zero-argument Callable with stable identity: " + key, "details": {}}
		identity[key] = [callable.get_object_id(), String(callable.get_method())]
	if not _checkpoint_providers.is_empty():
		if identity == _provider_identity:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return {"ok": false, "code": &"checkpoint_providers_already_configured", "message": "", "details": {}}
	_checkpoint_providers = providers.duplicate()
	_provider_identity = identity
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}

## Builds the complete CHECKPOINT_INPUT_KEYS bundle the coordinator hands straight to the real
## SaveManagerCheckpointPort. Providers are consulted once each, in a fixed order.
##
## `lifecycle` is supplied by the caller rather than read from live state: a stage's checkpoint must
## record the lifecycle that stage PRODUCES (dwm-7e6). Every other field is genuinely live, because
## completing a stage mutates the RunLifecycle alone.
func _checkpoint_inputs(lifecycle: Dictionary) -> Dictionary:
	var snapshot_input: Dictionary = _game_state.capture_run_snapshot_input()
	snapshot_input["lifecycle"] = lifecycle.duplicate(true)
	# v3 committed-Schedule boundary (Plan 01 Task 5, dwm-p2r.13). Because the recorded lifecycle is
	# the one the stage PRODUCES rather than live state, it can name a later day than the owner has
	# entered. A snapshot names ONE day, so the aggregate must describe the recorded day: a day the
	# owner has not begun has no committed Schedule yet, so it records the canonical empty aggregate
	# with a null fingerprint. When the days already agree this leaves the real aggregate untouched.
	var recorded_day := int(lifecycle.get("day", 0))
	var aggregate_value: Variant = snapshot_input.get("committed_schedule", {})
	var aggregate: Dictionary = aggregate_value if typeof(aggregate_value) == TYPE_DICTIONARY else {}
	if int(aggregate.get("day", -1)) != recorded_day:
		snapshot_input["committed_schedule"] = {
			"schema_version": int(aggregate.get("schema_version", 1)),
			"day": recorded_day,
			"registry_fingerprint": null,
			"entries": [],
			"commit_receipt": null,
		}
	return {
		"snapshot_input": snapshot_input,
		"dialogic_checkpoint": _provided("dialogic_checkpoint", {}),
		"route_id": _provided("route_id", DEFAULT_ROUTE_ID),
		"active_app_id": _provided("active_app_id", null),
		"audio_context": _provided("audio_context", {}),
		"content_version": _provided("content_version", DEFAULT_CONTENT_VERSION),
	}

func _provided(key: String, fallback: Variant) -> Variant:
	if not _checkpoint_providers.has(key):
		return fallback
	var produced: Variant = (_checkpoint_providers[key] as Callable).call()
	if typeof(produced) == TYPE_DICTIONARY or typeof(produced) == TYPE_ARRAY:
		return produced.duplicate(true)
	return produced

func begin_or_resume(command_id: String) -> Dictionary:
	if command_id.is_empty():
		return {"ok": false, "code": &"invalid_command_id", "message": "", "details": {}}
	var lifecycle: RefCounted = _game_state._run_lifecycle
	# Step 6.6 (dwm-p2r.13): the resolution begins from the owner's REAL canonical committed
	# Schedule. This used to pass a synthetic empty array, which silently claimed "no entries" for
	# every day regardless of what had actually been committed.
	var aggregate: Dictionary = _game_state._canonical_committed_schedule()
	# Task 7 Step 7.5 (dwm-p2r.14): the plan must carry the FROZEN REGISTRY PROJECTION, because the
	# execute stages read each entry's effects out of it. Without this the plan persisted an empty
	# route_plan and no committed ordinary effect could ever be applied.
	var projection := _frozen_route_plan(aggregate)
	if not projection.get("ok", false):
		return projection
	var commit_receipt: Variant = aggregate.get("commit_receipt")
	var commit_receipt_id: Variant = null
	if typeof(commit_receipt) == TYPE_DICTIONARY:
		commit_receipt_id = (commit_receipt as Dictionary).get("receipt_id")
	var route_plan: Array = (projection["value"] as Dictionary)["route_plan"]
	# dwm-p2r.18: mint the resolution ROOT and its start receipt before the plan exists, so the plan
	# can PERSIST both. Everything a presentation child is derived under comes from here.
	var minted := _resolution_start(command_id, aggregate, route_plan)
	if not minted.get("ok", false):
		return minted
	var resolution_start: Dictionary = (minted["value"] as Dictionary)["resolution_start"]
	var begun: Dictionary = lifecycle.begin_day_resolution(
		str((minted["value"] as Dictionary)["resolution_id"]), aggregate, route_plan,
		commit_receipt_id, _board_fate_receipt_id(resolution_start), resolution_start)
	if not begun.get("ok", false):
		return begun
	return {"ok": true, "code": &"ok",
		"value": {"run_id": str(lifecycle.to_dict()["run_id"])}}


## The board-fate id the start receipt bound, or null on the unconfigured path. Read back off the
## start receipt rather than tracked separately, so the plan's `board_fate_receipt_id` and the
## anchored start row can never name different receipts.
static func _board_fate_receipt_id(resolution_start: Dictionary) -> Variant:
	var start: Variant = resolution_start.get("day_resolution_start_receipt")
	if typeof(start) != TYPE_DICTIONARY:
		return null
	return (start as Dictionary).get("board_fate_receipt_id")


## Mints the resolution root and drives the retained `DayResolutionStartPort`.
##
## THE ROOT IS MINTED AT MOST ONCE PER DONE COMMAND. A replayed Done command must not mint a second
## root: it would produce a different `resolution_id`, and every presentation child already derived
## under the first root would become unreachable. So an active plan that already records this exact
## command id returns ITS persisted root and start receipt unchanged, and the issuer is not touched.
##
## Returns the empty bundle -- not a failure -- when the Plan-02 desktop-consequence source is
## absent. A resolution with no presentation in it is still perfectly resolvable without a root; it
## is only the presentation sites that fail closed (see `_presentation_command`).
func _resolution_start(command_id: String, aggregate: Dictionary,
		route_plan: Array) -> Dictionary:
	var existing := _active_plan()
	if not existing.is_empty() and str(existing.get("command_id", "")) == command_id:
		return {"ok": true, "code": &"ok", "value": {
			"resolution_id": str(existing["resolution_id"]),
			"resolution_start": {
				"command_id": command_id,
				"resolution_issuer_receipt": existing["resolution_issuer_receipt"],
				"day_resolution_start_receipt": existing["day_resolution_start_receipt"],
			} if existing["resolution_issuer_receipt"] != null else {},
		}}
	if not is_presentation_producer_ready():
		# The unconfigured board-fate path: no root, and the Done command IS the resolution id.
		return {"ok": true, "code": &"ok",
			"value": {"resolution_id": command_id, "resolution_start": {}}}
	# A genuinely concurrent unfinished resolution is refused BEFORE the issuer is touched, so a
	# rejected Done command never burns a root the ledger would then hold forever.
	if not existing.is_empty() and not _plan_is_complete(existing):
		return {"ok": false, "code": &"resolution_conflict",
			"message": str(existing.get("resolution_id", "")), "details": {}}
	var commit_receipt: Variant = aggregate.get("commit_receipt")
	if typeof(commit_receipt) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"resolution_start_unavailable",
			"message": "a receiptless aggregate cannot anchor a resolution root", "details": {}}
	var causal_day_instance := str((commit_receipt as Dictionary).get("causal_day_instance", ""))
	var board_fate: Variant = _desktop_consequence_source.call(&"resolve_board_fate_receipt", {
		"causal_day_instance": causal_day_instance,
		"source_day": int(aggregate.get("day", 0)),
	})
	if typeof(board_fate) != TYPE_DICTIONARY or not (board_fate as Dictionary).get("ok", false):
		return board_fate if typeof(board_fate) == TYPE_DICTIONARY else {
			"ok": false, "code": &"board_fate_receipt_unavailable",
			"message": "the desktop consequence source returned no CommandResult", "details": {}}
	var issued: Variant = _identity_issuer.call(&"issue", ROOT_PURPOSE)
	if typeof(issued) != TYPE_DICTIONARY or not (issued as Dictionary).get("ok", false):
		return issued if typeof(issued) == TYPE_DICTIONARY else {
			"ok": false, "code": &"resolution_root_unavailable",
			"message": "the issuer refused to mint a resolution root", "details": {}}
	var issued_value: Dictionary = (issued as Dictionary)["value"]
	var root_receipt: Dictionary = issued_value["issuer_receipt"]
	# Plan line 560: the semantic resolution id IS the minted token.
	var resolution_id := str(issued_value["token"])
	var prepared: Variant = _day_resolution_start_port.call(&"prepare_from_committed_schedule", {
		"resolution_id": resolution_id,
		"resolution_issuer_receipt": root_receipt.duplicate(true),
		"causal_day_instance": causal_day_instance,
		"committed_schedule": aggregate.duplicate(true),
		"route_plan": route_plan.duplicate(true),
		"board_fate_receipt":
			(((board_fate as Dictionary)["value"] as Dictionary)["board_fate_receipt"] as Dictionary).duplicate(true),
	})
	if typeof(prepared) != TYPE_DICTIONARY or not (prepared as Dictionary).get("ok", false):
		return prepared if typeof(prepared) == TYPE_DICTIONARY else {
			"ok": false, "code": &"resolution_start_unavailable",
			"message": "the start port returned no CommandResult", "details": {}}
	return {"ok": true, "code": &"ok", "value": {
		"resolution_id": resolution_id,
		"resolution_start": {
			"command_id": command_id,
			"resolution_issuer_receipt": root_receipt.duplicate(true),
			"day_resolution_start_receipt":
				(((prepared as Dictionary)["value"] as Dictionary)["start_receipt"] as Dictionary).duplicate(true),
		},
	}}


## The live active resolution plan as raw bytes, or {} when there is none.
func _active_plan() -> Dictionary:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	return (plan as Dictionary) if typeof(plan) == TYPE_DICTIONARY else {}


static func _plan_is_complete(plan: Dictionary) -> bool:
	for stage_value: Variant in (plan.get("stages", []) as Array):
		if str((stage_value as Dictionary).get("state", "")) != "completed":
			return false
	return true


## Projects the committed aggregate through the registry it was COMMITTED against.
##
## The aggregate records the exact `registry_fingerprint` its entries were validated with, so the
## currently loadable registry is accepted only when it is byte-identical. A registry that has moved
## on since the commit fails closed rather than silently re-pricing a committed day.
func _frozen_route_plan(aggregate: Dictionary) -> Dictionary:
	var entries: Variant = aggregate.get("entries", [])
	if typeof(entries) != TYPE_ARRAY or (entries as Array).is_empty():
		return {"ok": true, "code": &"ok", "value": {"route_plan": []}}
	var loaded: Dictionary = SCHEDULE_ACTION_REGISTRY.load_current()
	if not loaded.get("ok", false):
		return loaded
	var loaded_value: Dictionary = loaded["value"]
	var committed_fingerprint: Variant = aggregate.get("registry_fingerprint")
	if committed_fingerprint != null \
			and str(committed_fingerprint) != str(loaded_value.get("registry_fingerprint", "")):
		return {"ok": false, "code": &"registry_fingerprint_mismatch",
			"message": "the committed Schedule was validated against a different registry",
			"details": {}}
	return SCHEDULE_RULES.build_route_plan(aggregate, loaded_value["registry"])

func inspect_next_stage() -> Dictionary:
	var cursor: Dictionary = _game_state._run_lifecycle.resume_resolution()
	return cursor

## The two Day-7 stages that may not be answered from the aggregate alone (Task 8 Step 8.7,
## dwm-p2r.14). Both are driven through the ONE configured Day7ScheduleProvenance service.
const DAY7_PROVENANCE_STAGES: Array[String] = [
	"validate_day7_provenance", "checkpoint_day7_provenance",
]


func begin_next_stage() -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	# A Day-7 provenance stage is refused BEFORE the lifecycle marks it active, so an unconfigured
	# or refused handoff leaves the stage pending and the run resumable rather than half-run.
	var peeked: Dictionary = lifecycle.resume_resolution()
	var presentation_request: Dictionary = {}
	if peeked.get("ok", false) and bool(peeked["value"]["has_stage"]):
		var pending: Dictionary = peeked["value"]["stage"]
		var pending_id := str(pending.get("stage_id", ""))
		if pending_id in DAY7_PROVENANCE_STAGES:
			var handoff := _day7_handoff()
			if not handoff.get("ok", false):
				return handoff
		# Same fail-before-mutation law as the Day-7 guard above: the presentation children are
		# derived while the stage is still PENDING, so an undeliverable presentation leaves the run
		# exactly where it was rather than stranding an active stage with no command behind it.
		var site := _presentation_site(pending)
		if not site.is_empty():
			var command := _presentation_command(pending, site)
			if not command.get("ok", false):
				return command
			presentation_request = (command["value"] as Dictionary)["presentation_request"]
	var begun: Dictionary = lifecycle.begin_next_stage()
	if not begun.get("ok", false):
		return begun
	var stage: Dictionary = begun["value"]["stage"]
	# A presentation site PAUSES the walk. The stage stays active and carries no receipt until the
	# configured port publishes a completion the coordinator can checkpoint, so a crash anywhere in
	# the presentation resumes at exactly this boundary.
	if not presentation_request.is_empty():
		return {"ok": true, "code": &"ok", "value": {
			"mode": &"await_registered_command",
			"stage": stage.duplicate(true),
			"command": {
				"transaction_id": str(stage["transaction_id"]),
				"stage_id": str(stage["stage_id"]),
				"route_id": str(presentation_request["route_id"]),
				"presentation_request": presentation_request,
			},
		}}
	# An entry SUBSTAGE is not just a second delivery of its parent stage's envelope: an
	# ordinary_action substage is where that entry's registered effects actually reach the owner
	# (Task 7 Step 7.2, dwm-p2r.14).
	var substage_id := str(stage.get("substage_id", ""))
	if substage_id.begins_with("ordinary_action:"):
		return _begin_ordinary_action_substage(stage, substage_id)
	if substage_id.begins_with("surviving_date:"):
		return _begin_surviving_date_substage(stage, substage_id)
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": _immediate_receipt(str(stage["stage_id"])),
	}}


## Commits ONE committed ordinary entry's registered effects through the existing effect
## transaction owner, keyed by that entry's own substage transaction id.
##
## The effect ids come from the plan's persisted `route_plan` -- the frozen registry projection --
## and never from a caller-supplied field, an action-id parse, or a live registry re-read. Because
## GameState.commit_effect_transaction is already idempotent per transaction id, a duplicate
## delivery of the same substage replays its stored receipt instead of applying twice; two repeated
## Rest/Training/Working entries carry DISTINCT substage ids and so apply twice, as the registry
## intends for repeatable actions.
func _begin_ordinary_action_substage(stage: Dictionary, substage_id: String) -> Dictionary:
	var parts: PackedStringArray = substage_id.split(":")
	if parts.size() != 4:
		return {"ok": false, "code": &"invalid_substage_id", "message": substage_id, "details": {}}
	var entry_id := parts[3]
	var projected := _route_plan_entry(entry_id)
	if projected.is_empty():
		return {"ok": false, "code": &"unprojected_schedule_entry",
			"message": "no registry projection for committed entry " + entry_id, "details": {}}
	var effect_ids: Array[String] = []
	for effect_id: Variant in (projected.get("effect_ids", []) as Array):
		effect_ids.append(str(effect_id))
	var transaction_id := str(stage["transaction_id"])
	if not effect_ids.is_empty():
		var applied: Dictionary = _game_state.commit_effect_transaction(
			transaction_id, effect_ids, "schedule_entry")
		if not applied.get("ok", false):
			return applied
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": _envelope("schedule_rules", "schedule_entry_complete",
			{"entry_receipt_id": entry_id, "outcome_ids": effect_ids}),
	}}


## One committed DATE entry, after Hospital has had its say.
##
## A date Hospital superseded completes as a recorded miss and starts no board; only a surviving
## date carries a presentation. Either way the substage completes exactly once, so the plan stays
## resumable and a crash cannot leave a date half-run.
func _begin_surviving_date_substage(stage: Dictionary, substage_id: String) -> Dictionary:
	var parts: PackedStringArray = substage_id.split(":")
	if parts.size() != 4:
		return {"ok": false, "code": &"invalid_substage_id", "message": substage_id, "details": {}}
	var entry_id := parts[3]
	var superseded: bool = entry_id in _superseded_entry_ids()
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": _envelope("schedule_rules", "schedule_date_complete", {
			"entry_receipt_id": entry_id,
			"superseded": superseded,
			"reason": HOSPITAL_RULES.MISS_REASON if superseded else null,
			# A SUPERSEDED date presents nothing, so it completes with no presentation evidence.
			# A surviving date never reaches here: it pauses on its presentation instead.
			"presentation_completion_receipt": null,
		}),
	}}


## The frozen registry projection the ACTIVE plan persisted for one committed entry.
func _route_plan_entry(schedule_entry_id: String) -> Dictionary:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return {}
	for projected: Variant in ((plan as Dictionary).get("route_plan", []) as Array):
		if typeof(projected) != TYPE_DICTIONARY:
			continue
		if str((projected as Dictionary).get("schedule_entry_id", "")) == schedule_entry_id:
			return projected as Dictionary
	return {}

func prepare_completion(transaction_id: String, receipt: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var snapshot: Dictionary = lifecycle.to_dict()
	if snapshot["active_resolution_plan"] != null:
		for stage: Dictionary in snapshot["active_resolution_plan"]["stages"]:
			if str(stage["transaction_id"]) == transaction_id and str(stage["state"]) == "completed":
				# Already durable. Re-applying it would be a no-op, but building a candidate for it
				# would misrepresent a replay as fresh work.
				return _prepared(transaction_id, receipt, snapshot, true, stage["receipt"])
	var produced := _completed_lifecycle(snapshot, transaction_id, receipt)
	if not produced.get("ok", false):
		return produced
	var prepared := _prepared(transaction_id, receipt, produced["value"]["lifecycle"], false, null)
	# The Hospital stage carries the Contacts half of its own transaction.
	var contacts_candidate := _hospital_contacts_candidate(snapshot, transaction_id, receipt)
	if not contacts_candidate.is_empty():
		((prepared["value"] as Dictionary)["run_candidate"] as Dictionary)["contacts"] = 			contacts_candidate
	return prepared


## The Contacts candidate a completing Hospital stage produces, or {} when it produces none.
##
## Append-only and idempotent: the witness is keyed by the Hospital stage's own transaction id, so
## replaying the same stage rewrites the byte-identical record rather than appending a second one.
## The witness is recomputed from the SAME pure owner that produced the stage envelope, so the two
## can never disagree; the caller's receipt only decides WHETHER a witness exists.
func _hospital_contacts_candidate(snapshot: Dictionary, transaction_id: String,
		receipt: Dictionary) -> Dictionary:
	if not _is_hospital_stage(snapshot, transaction_id):
		return {}
	var value: Variant = receipt.get("value")
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	if (value as Dictionary).get("witness_entry_id") == null:
		return {}
	var planned: Dictionary = HOSPITAL_RULES.plan_resolution({
		"required": true,
		"source_day": _active_source_day(),
		"committed_entries": _active_committed_entries(),
	})
	if not planned.get("ok", false):
		return {}
	var witness: Variant = (planned["value"] as Dictionary)["witness"]
	if typeof(witness) != TYPE_DICTIONARY:
		return {}
	var contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	(contacts["sylvia_hospital_witness_receipts"] as Dictionary)[transaction_id] = 		(witness as Dictionary).duplicate(true)
	return contacts


func _is_hospital_stage(snapshot: Dictionary, transaction_id: String) -> bool:
	var plan: Variant = snapshot.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return false
	for stage_value: Variant in ((plan as Dictionary).get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("transaction_id", "")) == transaction_id:
			return str(stage.get("stage_id", "")) == "hospital_if_triggered"
	return false


## Applies the stage to a DETACHED clone of the lifecycle. The checkpoint is then built from the
## state the transaction PRODUCES, while live state stays untouched until the coordinator has
## durably committed that checkpoint and replays this exact lifecycle into it (dwm-7e6).
func _completed_lifecycle(snapshot: Dictionary, transaction_id: String, receipt: Dictionary) -> Dictionary:
	var detached: RefCounted = RUN_LIFECYCLE.new()
	var prepared: Dictionary = detached.prepare_restore(snapshot)
	if not prepared.get("ok", false):
		return prepared
	var restored: Dictionary = detached.commit_restore(prepared["value"]["candidate"])
	if not restored.get("ok", false):
		return restored
	# The clone is also the validation seam: an illegal receipt fails here, before any checkpoint.
	var completed: Dictionary = detached.complete_active_stage(
		transaction_id, _plan_receipt_from_envelope(receipt))
	if not completed.get("ok", false):
		return completed
	return {"ok": true, "code": &"ok", "value": {"lifecycle": detached.to_dict()}}


func _prepared(
		transaction_id: String, receipt: Dictionary, lifecycle: Dictionary,
		duplicate: bool, stored_receipt: Variant
) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {
		"run_candidate": {
			"transaction_id": transaction_id,
			"receipt": receipt.duplicate(true),
			"lifecycle": lifecycle.duplicate(true),
		},
		# Despite the key name, the coordinator forwards this value verbatim as the real checkpoint
		# port's `checkpoint_inputs`, so it must be the COMPLETE bundle (dwm-7e6).
		"snapshot_input": _checkpoint_inputs(lifecycle),
		"stage": {"transaction_id": transaction_id},
		"publication": {
			"transaction_id": transaction_id,
			"signals": ["day_changed", "save_relevant_state_changed"],
		},
		"duplicate": duplicate,
		"stored_receipt": stored_receipt,
	}}

func capture() -> Dictionary:
	# Contacts joins the backup because the Hospital stage commits the Sylvia witness into the
	# Contacts handoff index in the SAME transaction (Task 7 Step 7.3, dwm-p2r.14). Backing up only
	# the lifecycle would leave a witness behind for a supersession that was rolled back.
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"lifecycle": _game_state._run_lifecycle.to_dict(),
		"contacts": (_game_state.contacts as Dictionary).duplicate(true),
	}}}

## Installs the EXACT lifecycle the checkpoint recorded, rather than re-deriving the completion from
## live state. Re-deriving would let the durable record and the live run drift apart (dwm-7e6).
func commit(candidate: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var prepared: Dictionary = lifecycle.prepare_restore(candidate["lifecycle"])
	if not prepared.get("ok", false):
		return prepared
	var committed: Dictionary = lifecycle.commit_restore(prepared["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	# The Contacts half of the SAME transaction. Validated before install, so a malformed witness
	# can never reach the owner, and absent when the stage produced none.
	if candidate.has("contacts"):
		var validated: Dictionary = CONTACT_STATE.validate_state(candidate["contacts"])
		if not validated.get("ok", false):
			return validated
		_game_state.contacts = (candidate["contacts"] as Dictionary).duplicate(true)
	return committed

func rollback(backup: Dictionary) -> Dictionary:
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var restored: Dictionary = lifecycle.prepare_restore(backup["lifecycle"])
	if not restored.get("ok", false):
		return restored
	var committed: Dictionary = lifecycle.commit_restore(restored["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	# Restore BOTH owners, so a rolled-back Hospital leaves no witness behind.
	if backup.has("contacts"):
		_game_state.contacts = (backup["contacts"] as Dictionary).duplicate(true)
	return committed

func publish(publication: Dictionary) -> Dictionary:
	if typeof(publication.get("signals")) != TYPE_ARRAY:
		return {"ok": false, "code": &"invalid_publication", "message": "", "details": {}}
	for signal_name: Variant in publication["signals"]:
		if typeof(signal_name) != TYPE_STRING or not _game_state.has_signal(str(signal_name)):
			return {"ok": false, "code": &"invalid_publication", "message": str(signal_name), "details": {}}
	for signal_name: Variant in publication["signals"]:
		match str(signal_name):
			"day_changed":
				_game_state.emit_signal("day_changed", int(_game_state._run_lifecycle.get_day()))
			_:
				_game_state.emit_signal(str(signal_name))
	return {"ok": true, "code": &"ok"}

## Injects the ONE configured Day-7 provenance service Bootstrap retained (Plan 01 Task 6 Step 6.5,
## dwm-p2r.13).
##
## The service arrives ALREADY CONFIGURED with the exact registry/issuer pair; this port never
## configures it and never constructs one, so there is no second place a Day-7 handoff could be
## minted from a different identity root. Idempotent for the same instance, refuses a replacement.
## Retains the exact `.16` issuer and the retained `DayResolutionStartPort` (dwm-p2r.18).
##
## Both arrive ALREADY CONSTRUCTED from Bootstrap. Without them a resolution mints no root, derives
## no `P01.day_resolution.start`, and therefore cannot derive a lawful presentation child -- so this
## seam is what makes the producer half reachable at all. Identical replay is idempotent; a
## replacement in either position is refused before any mutation.
func configure_resolution_identity(identity_issuer: Object, start_port: Object) -> Dictionary:
	if identity_issuer == null or not _has_methods(identity_issuer, _ISSUER_METHODS) 			or start_port == null or not _has_methods(start_port, _START_PORT_METHODS):
		return {"ok": false, "code": &"resolution_identity_conflict",
			"message": "an exact issuer and day-resolution start port are required", "details": {}}
	if _identity_issuer != null or _day_resolution_start_port != null:
		if _identity_issuer != identity_issuer or _day_resolution_start_port != start_port:
			return {"ok": false, "code": &"resolution_identity_conflict",
				"message": "a configured port never adopts a replacement identity owner",
				"details": {}}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_identity_issuer = identity_issuer
	_day_resolution_start_port = start_port
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


## The Plan-02 desktop-consequence handoff (DEVIATION-5). Bootstrap deliberately never calls this;
## see the field comment above for why. Same idempotent/refuse-replacement law as every other seam.
func configure_desktop_consequence_source(source: Object) -> Dictionary:
	if source == null or not _has_methods(source, _CONSEQUENCE_SOURCE_METHODS):
		return {"ok": false, "code": &"desktop_consequence_source_conflict",
			"message": "an exact board-fate and condition receipt source is required", "details": {}}
	if _desktop_consequence_source != null:
		if _desktop_consequence_source != source:
			return {"ok": false, "code": &"desktop_consequence_source_conflict",
				"message": "a configured port never adopts a replacement source", "details": {}}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_desktop_consequence_source = source
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


## Whether this resolution can mint a root at all. Reported so bootstrap evidence and the contract
## probe can show the Phase-2R gap rather than leaving it invisible.
func is_presentation_producer_ready() -> bool:
	return _identity_issuer != null and _day_resolution_start_port != null 		and _desktop_consequence_source != null


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	if target == null:
		return false
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true


func configure_day7_provenance(service: Object) -> Dictionary:
	if service == null or not service.has_method("validate_handoff"):
		return {"ok": false, "code": &"invalid_day7_provenance_service", "message": "", "details": {}}
	if _day7_provenance != null:
		if _day7_provenance == service:
			return {"ok": true, "code": &"ok", "value": {"configured": true}, "receipt": {}}
		return {"ok": false, "code": &"day7_provenance_already_configured", "message": "",
			"details": {}}
	_day7_provenance = service
	return {"ok": true, "code": &"ok", "value": {"configured": true}, "receipt": {}}


## The committed entry identities the ACTIVE plan froze, in its own persisted substage order.
##
## Read from the plan rather than recomputed from live state: the plan is what the resolution
## actually began from, and live state can legitimately have moved on by the time this stage runs.
## Scoped to ONE entry stage (Task 7, dwm-p2r.14). The ordinary stage and the date stage own
## disjoint substage sets and run on opposite sides of Hospital, so a single flat read across every
## stage would report dates as already executed before Hospital had a chance to supersede them.
func _committed_entry_receipt_ids(owning_stage_id: String) -> Array:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return []
	var receipt_ids: Array = []
	for stage_value: Variant in ((plan as Dictionary).get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("stage_id", "")) != owning_stage_id:
			continue
		for substage_value: Variant in (stage.get("substages", []) as Array):
			var parts: PackedStringArray = str(
				(substage_value as Dictionary)["substage_id"]).split(":")
			if parts.size() == 4:
				receipt_ids.append(parts[3])
	return receipt_ids


## The day this resolution was created for, independent of how far its stages have advanced.
func _active_source_day() -> int:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) == TYPE_DICTIONARY and (plan as Dictionary).has("source_day"):
		return int((plan as Dictionary)["source_day"])
	return int(_game_state._run_lifecycle.get_day())


func _immediate_receipt(stage_id: String) -> Dictionary:
	# Freeze the resolution's SOURCE day (dwm-7e6). Reading the live day here made
	# reset_day_scope.target_day become source + 2 once increment_day had already advanced it.
	var day: int = _active_source_day()
	match stage_id:
		"lock_day":
			return _envelope("day_resolution_coordinator", "day_lock", {"locked": true})
		"validate_schedule":
			return _envelope("schedule_rules", "schedule_validation",
				{"schedule_digest": "digest-day-%d" % day, "ordered_entry_ids": []})
		"execute_schedule_actions":
			# Step 6.6 (dwm-p2r.13): the receipt ids are READ from the committed substages this
			# plan actually froze, never synthesized. An empty list here now means the committed
			# Schedule was genuinely empty, rather than meaning nobody supplied one.
			return _envelope("schedule_rules", "schedule_actions_complete",
				{"entry_receipt_ids": _committed_entry_receipt_ids("execute_schedule_actions")})
		"execute_schedule_dates":
			# Runs AFTER hospital_if_triggered, so the supersession set is already durable and is
			# READ from that completed stage rather than recomputed here.
			return _envelope("schedule_rules", "schedule_dates_complete",
				{"entry_receipt_ids": _committed_entry_receipt_ids("execute_schedule_dates"),
					"superseded_entry_ids": _superseded_entry_ids()})
		"commit_outcomes":
			return _envelope("game_state", "outcomes_commit", {"outcome_ids": [], "effect_transaction_ids": []})
		"hospital_if_triggered":
			return _envelope("hospital_rules", "hospital_resolution", _hospital_envelope())
		"twofriends_if_deferred":
			return _envelope("contact_invitation_state", "twofriends_resolution",
				{"required": false, "route_receipt_id": null, "message_transaction_ids": [],
					"presentation_completion_receipt": null})
		"invitation_rollover":
			return _envelope("contact_invitation_state", "invitation_rollover",
				{"target_day": day + 1, "message_transaction_ids": []})
		"increment_day":
			return _envelope("run_lifecycle", "day_increment", {"source_day": day, "target_day": day + 1})
		"reset_day_scope":
			return _envelope("game_state", "day_scope_reset", {"target_day": day + 1, "reset_ids": []})
		"new_day_autosave":
			return _envelope("save_manager", "disk_checkpoint_request",
				{"save_kind": "autosave", "save_reason": "day_start"})
		"unlock_day":
			return _envelope("day_resolution_coordinator", "day_unlock", {"locked": false})
		"close_invitations_run_end":
			return _envelope("contact_invitation_state", "run_end_close", {"resolved_action_ids": []})
		"validate_day7_provenance":
			var validated: Dictionary = _day7_terminal_provenance()
			return _envelope("day7_schedule_provenance", "day7_provenance_validation", {
				"cause": str(validated["cause"]),
				"schedule_entry_id": validated["schedule_entry_id"],
				"source_receipt_id": validated["source_receipt_id"],
			})
		"checkpoint_day7_provenance":
			# The checkpoint carries the ANCHORED child, not a literal cause string. dwm-oyo.3 and
			# dwm-oyo.6 consume exactly this receipt id and provenance.
			var terminal: Dictionary = _day7_terminal_provenance()
			return _envelope("day7_schedule_provenance", "day7_provenance_checkpoint", {
				"cause": str(terminal["cause"]),
				"schedule_commit_receipt_id": terminal["schedule_commit_receipt_id"],
				"day7_provenance_receipt_id": str(terminal["receipt_id"]),
				"day7_provenance_receipt_provenance":
					(terminal["receipt_provenance"] as Dictionary).duplicate(true),
			})
		"resolve_ending_plan":
			return _envelope("dating_ending_rules", "ending_resolution", {"ending_plan": _default_ending_plan()})
		"enter_ending":
			return _envelope("run_lifecycle", "enter_ending",
				{"state": "ENDING", "primary_id": _resolved_primary_id(), "epilogue_id": null})
		"ending_autosave":
			return _envelope("save_manager", "disk_checkpoint_request",
				{"save_kind": "autosave", "save_reason": "ending"})
	return _envelope("unknown", "unknown", {})

# -------------------------------------------------------------------------------------------------
# The committed-Schedule presentation PRODUCER (Plan 01 Task 8, dwm-p2r.18)
# -------------------------------------------------------------------------------------------------
#
# WHAT THIS IS. Task 8 built the presentation LAYER -- the two ports, the narrative owner, the
# scenes, the router and the composition -- but nothing HANDED those ports a command during a
# resolution, so no stage ever paused on a presentation. This is that missing producer.
#
# WHERE THE IDENTITY COMES FROM. Every row below is derived through the ONE retained `.16` issuer,
# under the resolution root the plan PERSISTED. Nothing here invents an id, an ordinal, or a source
# order: each variant selects exactly one matrix row (plan lines 94-98) and constructs exactly that
# row's request. Recovery re-runs this same code over the same persisted bytes and therefore derives
# the same children -- which is the whole reason the root is persisted rather than held in memory.
#
# THE ORDER IS CLOSED (plan line 102). The Hospital aggregate row precedes its miss rows, which
# precede the Hospital presentation intent; every intent precedes its own completion row.

## The presentation locator for each variant. Constructed, then REQUIRED to be registered in
## DialogicTimelineCatalog -- a locator the manifest does not carry is refused rather than played.
const HOSPITAL_TIMELINE_ID := "hospital.faint"
const PAIR_PARTICIPANTS: Array[String] = ["priscilla", "lavinia"]
const PAIR_SLUG := "priscilla_lavinia"
## Phase 2R presents the PRE-challenge timeline: the challenge itself is dwm-oyo.4's board, and the
## post-challenge timeline follows it, so neither is reachable from Plan 01.
const DATING_TIMELINE_PHASE := "pre_challenge"

const HOSPITAL_STAGE := "hospital_if_triggered"
const DATES_STAGE := "execute_schedule_dates"
const PAIR_STAGE := "twofriends_if_deferred"

const INTENT_ROLE := "presentation.intent"
const COMPLETION_ROLE := "presentation.completion"
const PRESENTATION_CHILD_KIND := &"day_resolution_stage"
const HOSPITAL_RESOLUTION_ROLE := "hospital.resolution"
const HOSPITAL_RESOLUTION_CHILD_KIND := &"hospital_resolution"
const HOSPITAL_MISS_ROLE := "hospital.miss"
const HOSPITAL_MISS_CHILD_KIND := &"hospital_miss"


## Whether the pending stage/substage is a presentation site, and which variant.
##
## Returns {} for every stage that presents nothing, so the ordinary immediate-completion path is
## untouched for the great majority of stages.
func _presentation_site(stage: Dictionary) -> Dictionary:
	var stage_id := str(stage.get("stage_id", ""))
	var substage_id := str(stage.get("substage_id", ""))
	if substage_id.begins_with("surviving_date:"):
		return _surviving_date_site(substage_id)
	if substage_id != "":
		return {}
	if stage_id == HOSPITAL_STAGE:
		return _hospital_site()
	if stage_id == PAIR_STAGE:
		return _deferred_pair_site()
	return {}


## Hospital presents only when the owner's own condition truth says it triggered.
func _hospital_site() -> Dictionary:
	var required: bool = bool(_game_state.should_route_hospital()) \
		if _game_state.has_method("should_route_hospital") else false
	if not required:
		return {}
	return {"kind": "hospital", "stage_name": HOSPITAL_STAGE, "route_id": "hospital",
		"schedule_entry_id": null}


## A committed date presents only if Hospital did NOT supersede it. When Hospital triggered it
## supersedes every committed date, so a surviving date and a Hospital presentation are mutually
## exclusive by construction rather than by a second rule.
func _surviving_date_site(substage_id: String) -> Dictionary:
	var parts: PackedStringArray = substage_id.split(":")
	if parts.size() != 4:
		return {}
	var entry_id := parts[3]
	if entry_id in _superseded_entry_ids():
		return {}
	return {"kind": "surviving_date", "stage_name": DATES_STAGE, "route_id": "dating",
		"schedule_entry_id": entry_id}


## The deferred P-L pair, read from the owner's own invitation state rather than a caller field.
func _deferred_pair_site() -> Dictionary:
	var contacts: Variant = _game_state.get("contacts")
	if typeof(contacts) != TYPE_DICTIONARY:
		return {}
	var group: Variant = (contacts as Dictionary).get("group_action")
	if typeof(group) != TYPE_DICTIONARY:
		return {}
	var deferred: Variant = (group as Dictionary).get("deferred_twofriends")
	if typeof(deferred) != TYPE_DICTIONARY:
		return {}
	# The pair's committed entry is what carries the ancestry the intent projects; the deferred
	# marker names only the action.
	var action_id := str((deferred as Dictionary).get("action_id", ""))
	for entry_value: Variant in _active_committed_entries():
		var entry: Dictionary = entry_value
		if str(entry.get("action_id", "")) == action_id \
				and str(entry.get("action_kind", "")) == "group":
			return {"kind": "twofriends_if_deferred", "stage_name": PAIR_STAGE,
				"route_id": "dating", "schedule_entry_id": str(entry["schedule_entry_id"])}
	return {}


## Builds the exact port `begin()` request for one presentation site: the `P01.presentation.intent`
## child, its matching `P01.presentation.completion` child, and the frozen context between them.
##
## FAILS CLOSED BEFORE ANY STAGE MUTATION. A resolution with no persisted root cannot derive a
## lawful intent, so it refuses here rather than silently completing the stage with no presentation
## -- which is exactly the silent skip this bead exists to remove.
func _presentation_command(stage: Dictionary, site: Dictionary) -> Dictionary:
	var plan := _active_plan()
	var root: Variant = plan.get("resolution_issuer_receipt")
	var start: Variant = plan.get("day_resolution_start_receipt")
	if typeof(root) != TYPE_DICTIONARY or typeof(start) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"presentation_intent_unavailable",
			"message": "this resolution persisted no root, so no presentation child can be derived"
				+ " (the Plan-02 desktop consequence source is unconfigured)",
			"details": {"stage_id": str(stage.get("stage_id", ""))}}
	# A plan can carry a perfectly good root while THIS port has no issuer to derive under -- a
	# half-composed process, or a resolution begun by one port and resumed by another. Fail closed
	# rather than dereferencing a null issuer part-way through the derivation.
	if _identity_issuer == null:
		return {"ok": false, "code": &"presentation_intent_unavailable",
			"message": "this port has no configured identity issuer to derive a presentation under",
			"details": {"stage_id": str(stage.get("stage_id", ""))}}

	# HOSPITAL ANCESTRY FIRST, and exactly once. The aggregate and miss rows feed BOTH the context's
	# `miss_receipt_ids` and the intent's `input_receipt_ids`; deriving them twice would be wasteful
	# and would leave two places able to disagree about which misses exist.
	var hospital_rows: Dictionary = {}
	if str(site["kind"]) == "hospital":
		var derived_rows := _derive_hospital_rows(plan, root as Dictionary, start as Dictionary)
		if not derived_rows.get("ok", false):
			return derived_rows
		hospital_rows = derived_rows["value"]

	var context := _presentation_context(site, plan, hospital_rows)
	if context.is_empty():
		return {"ok": false, "code": &"invalid_presentation_context",
			"message": "the frozen presentation context is not derivable", "details": {}}
	var timeline_id := _presentation_timeline_id(context)
	if timeline_id.is_empty():
		return {"ok": false, "code": &"unregistered_presentation_timeline",
			"message": "no registered locator exists for this presentation", "details": {}}
	var inputs := _presentation_inputs(site, hospital_rows)
	if not inputs.get("ok", false):
		return inputs
	var ordinal := _presentation_ordinal(site)
	if ordinal < 0:
		return {"ok": false, "code": &"invalid_presentation_ordinal",
			"message": "the within-stage presentation ordinal is not derivable", "details": {}}

	var context_hash := _sha256(context)
	if context_hash.is_empty():
		return {"ok": false, "code": &"invalid_presentation_context",
			"message": "the context is not canonically hashable", "details": {}}
	var root_receipt: Dictionary = root
	var start_receipt: Dictionary = start
	var intent := _derive_row(str(root_receipt["receipt_id"]), PRESENTATION_CHILD_KIND, ordinal, [
		_project("role", INTENT_ROLE),
		_project("resolution_id", str(plan["resolution_id"])),
		_project("causal_day_instance", str(start_receipt["causal_day_instance"])),
		_project("source_day", int(plan["source_day"])),
		_project("day_resolution_start_receipt_id", str(start_receipt["receipt_id"])),
		_project("stage_name", str(site["stage_name"])),
		_project("stage_index", _stage_index(str(site["stage_name"]), int(plan["source_day"]))),
		_project("presentation_kind", str(context["kind"])),
		_project("schedule_entry_id", site["schedule_entry_id"]),
		_project("route_id", str(site["route_id"])),
		_project("timeline_id", timeline_id),
		_project("context_sha256", context_hash),
		_project("input_receipt_ids", (inputs["value"] as Dictionary)["input_receipt_ids"]),
	])
	if not intent.get("ok", false):
		return intent
	var intent_id := str((intent["value"] as Dictionary)["child_id"])

	# The completion binds its prerequisite: `substage_id` is the intent child id just derived, so
	# the completion projection cannot be built before the intent exists (plan line 100).
	var completion := _derive_row(str(root_receipt["receipt_id"]), PRESENTATION_CHILD_KIND, ordinal, [
		_project("role", COMPLETION_ROLE),
		_project("resolution_id", str(plan["resolution_id"])),
		_project("stage_id", str(stage["transaction_id"])),
		_project("substage_id", intent_id),
		_project("route_id", str(site["route_id"])),
		_project("timeline_id", timeline_id),
		_project("context_sha256", context_hash),
	])
	if not completion.get("ok", false):
		return completion

	return {"ok": true, "code": &"ok", "value": {"presentation_request": {
		"resolution_id": str(plan["resolution_id"]),
		"resolution_issuer_receipt": root_receipt.duplicate(true),
		"stage_id": str(stage["transaction_id"]),
		"substage_id": intent_id,
		"route_id": str(site["route_id"]),
		"timeline_id": timeline_id,
		"context": context,
		"completion_transaction_id": str((completion["value"] as Dictionary)["child_id"]),
		"completion_transaction_provenance":
			((completion["value"] as Dictionary)["provenance"] as Dictionary).duplicate(true),
	}}}


## The exact frozen context each port validates, and nothing that could carry an outcome.
func _presentation_context(site: Dictionary, plan: Dictionary,
		hospital_rows: Dictionary) -> Dictionary:
	var day := int(plan["source_day"])
	if str(site["kind"]) == "hospital":
		# Hospital owns no semantic order for either array, so both are sorted and unique.
		var source_entry_ids := _id_list(hospital_rows["date_schedule_entry_ids"] as Array)
		var miss_ids := _id_list(hospital_rows["hospital_miss_receipt_ids"] as Array)
		return {"kind": "hospital", "day": day, "source_entry_ids": source_entry_ids,
			"miss_receipt_ids": miss_ids}
	var entry := _committed_entry(str(site["schedule_entry_id"]))
	if entry.is_empty():
		return {}
	# The pair keeps the invitation-owned order; a solo date carries its one registered friend.
	var kind := "twofriends_if_deferred" if str(site["kind"]) == "twofriends_if_deferred" \
		else str(entry.get("action_kind", ""))
	var participants: Array[String] = []
	if kind == "twofriends_if_deferred" or kind == "group":
		participants = PAIR_PARTICIPANTS.duplicate()
	else:
		for participant: Variant in (entry.get("participants", []) as Array):
			participants.append(str(participant))
	return {"kind": kind, "day": day, "schedule_entry_id": str(site["schedule_entry_id"]),
		"participants": participants}


## Constructs the locator and proves it is registered. A constructed String that the manifest does
## not carry returns "" and the presentation refuses rather than starting an unregistered timeline.
func _presentation_timeline_id(context: Dictionary) -> String:
	var day := int(context["day"])
	var timeline_id := ""
	match str(context["kind"]):
		"hospital":
			timeline_id = HOSPITAL_TIMELINE_ID
		"solo":
			var participants: Array = context["participants"]
			if participants.size() != 1:
				return ""
			timeline_id = "dating.solo.%s.day%d.%s" % [
				str(participants[0]), day, DATING_TIMELINE_PHASE]
		"group":
			timeline_id = "dating.group.%s.day%d.%s" % [PAIR_SLUG, day, DATING_TIMELINE_PHASE]
		"twofriends_if_deferred":
			timeline_id = "dating.twofriends.%s.day%d.%s" % [PAIR_SLUG, day, DATING_TIMELINE_PHASE]
		_:
			return ""
	return timeline_id if DialogicTimelineCatalog.has_timeline_id(timeline_id) else ""


## The exact `input_receipt_ids` set each variant projects (plan line 100).
func _presentation_inputs(site: Dictionary, hospital_rows: Dictionary) -> Dictionary:
	if str(site["kind"]) == "hospital":
		var ids: Array = [str(hospital_rows["condition_receipt_id"])]
		ids.append_array(hospital_rows["hospital_miss_receipt_ids"] as Array)
		return {"ok": true, "code": &"ok", "value": {"input_receipt_ids": _id_list(ids)}}
	var entry := _committed_entry(str(site["schedule_entry_id"]))
	if entry.is_empty():
		return {"ok": false, "code": &"invalid_presentation_intent",
			"message": "no committed entry backs this presentation", "details": {}}
	var source_receipt_id: Variant = entry.get("source_receipt_id")
	if typeof(source_receipt_id) != TYPE_STRING or str(source_receipt_id).is_empty():
		return {"ok": false, "code": &"invalid_presentation_intent",
			"message": "a committed date presents only under its own source receipt", "details": {}}
	return {"ok": true, "code": &"ok", "value": {"input_receipt_ids": _id_list([
		str(site["schedule_entry_id"]), str(source_receipt_id)])}}


## Derives `P01.hospital.resolution` and then its `P01.hospital.miss[]` children, in that order.
##
## The condition receipt is a PLAN-02 record this resolution consumes but does not own, so it
## arrives through the deliberately-unconfigured desktop-consequence seam and its absence fails
## closed. Deriving a Hospital aggregate against a condition nobody anchored would be exactly the
## forged ancestry the matrix exists to prevent.
func _derive_hospital_rows(plan: Dictionary, root: Dictionary, start: Dictionary) -> Dictionary:
	if _desktop_consequence_source == null:
		return {"ok": false, "code": &"condition_receipt_unavailable",
			"message": "a Hospital resolution projects the Plan-02 condition receipt", "details": {}}
	var condition: Variant = _desktop_consequence_source.call(&"resolve_condition_receipt", {
		"causal_day_instance": str(start["causal_day_instance"]),
		"source_day": int(plan["source_day"]),
	})
	if typeof(condition) != TYPE_DICTIONARY or not (condition as Dictionary).get("ok", false):
		return condition if typeof(condition) == TYPE_DICTIONARY else {
			"ok": false, "code": &"condition_receipt_unavailable",
			"message": "the desktop consequence source returned no CommandResult", "details": {}}
	var condition_receipt: Variant = ((condition as Dictionary)["value"] as Dictionary).get(
		"condition_receipt")
	if typeof(condition_receipt) != TYPE_DICTIONARY \
			or str((condition_receipt as Dictionary).get("receipt_id", "")).is_empty():
		return {"ok": false, "code": &"condition_receipt_unavailable",
			"message": "the condition receipt carries no receipt_id", "details": {}}
	var condition_receipt_id := str((condition_receipt as Dictionary)["receipt_id"])

	var planned: Dictionary = HOSPITAL_RULES.plan_resolution({
		"required": true,
		"source_day": int(plan["source_day"]),
		"committed_entries": _active_committed_entries(),
	})
	if not planned.get("ok", false):
		return planned
	var planned_value: Dictionary = planned["value"]
	var parent_id := str(root["receipt_id"])
	var resolution_row := _derive_row(parent_id, HOSPITAL_RESOLUTION_CHILD_KIND, 0, [
		_project("role", HOSPITAL_RESOLUTION_ROLE),
		_project("resolution_id", str(plan["resolution_id"])),
		_project("causal_day_instance", str(start["causal_day_instance"])),
		_project("source_day", int(plan["source_day"])),
		_project("day_resolution_start_receipt_id", str(start["receipt_id"])),
		_project("schedule_commit_receipt_id", plan.get("schedule_commit_receipt_id")),
		_project("condition_receipt_id", condition_receipt_id),
		_project("date_schedule_entry_ids", planned_value["date_schedule_entry_ids"]),
		_project("required", true),
	])
	if not resolution_row.get("ok", false):
		return resolution_row
	var hospital_resolution_id := str((resolution_row["value"] as Dictionary)["child_id"])

	# Miss rows follow the aggregate, each at its own matrix ordinal.
	var miss_ids: Array[String] = []
	for miss_value: Variant in (planned_value["misses"] as Array):
		var miss: Dictionary = miss_value
		var miss_row := _derive_row(parent_id, HOSPITAL_MISS_CHILD_KIND, int(miss["ordinal"]), [
			_project("role", HOSPITAL_MISS_ROLE),
			_project("resolution_id", str(plan["resolution_id"])),
			_project("causal_day_instance", str(start["causal_day_instance"])),
			_project("source_day", int(plan["source_day"])),
			_project("hospital_resolution_id", hospital_resolution_id),
			_project("schedule_entry_id", str(miss["schedule_entry_id"])),
			_project("action_id", str(miss["action_id"])),
			_project("source_receipt_id", miss["source_receipt_id"]),
			_project("reason", str(miss["reason"])),
		])
		if not miss_row.get("ok", false):
			return miss_row
		miss_ids.append(str((miss_row["value"] as Dictionary)["child_id"]))
	return {"ok": true, "code": &"ok", "value": {
		"condition_receipt_id": condition_receipt_id,
		"hospital_resolution_id": hospital_resolution_id,
		"hospital_miss_receipt_ids": miss_ids,
		"date_schedule_entry_ids": planned_value["date_schedule_entry_ids"],
	}}


## The stage envelope for a completing PRESENTATION stage, carrying the exact receipt the port
## published (dwm-p2r.18).
##
## The domain half is still owned by the domain: Hospital's envelope comes from `HospitalRules`, a
## date substage's from the committed entry. The port's completion receipt is ATTACHED to it rather
## than replacing it, so one checkpoint durably records both what the domain decided and the
## evidence that the presentation physically happened.
func presentation_stage_receipt(transaction_id: String, completion: Dictionary) -> Dictionary:
	var plan := _active_plan()
	if plan.is_empty():
		return {"ok": false, "code": &"no_active_plan", "message": "", "details": {}}
	for stage_value: Variant in (plan.get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("transaction_id", "")) == transaction_id:
			var envelope := _immediate_receipt(str(stage["stage_id"]))
			(envelope["value"] as Dictionary)["presentation_completion_receipt"] = 				completion.duplicate(true)
			return {"ok": true, "code": &"ok", "value": {"receipt": envelope}}
		for substage_value: Variant in (stage.get("substages", []) as Array):
			var substage: Dictionary = substage_value
			if str(substage.get("transaction_id", "")) != transaction_id:
				continue
			var substage_id := str(substage["substage_id"])
			var entry_id := substage_id.split(":")[3] if substage_id.split(":").size() == 4 else ""
			return {"ok": true, "code": &"ok", "value": {"receipt": _envelope(
				"schedule_rules", "schedule_date_complete", {
					"entry_receipt_id": entry_id,
					"superseded": false,
					"reason": null,
					"presentation_completion_receipt": completion.duplicate(true),
				})}}
	return {"ok": false, "code": &"unknown_transaction", "message": transaction_id, "details": {}}


## The zero-based within-stage presentation ordinal (plan line 97).
##
## Hospital and the deferred pair are single presentations and reserve ordinal 0. A surviving date
## takes its index among the SURVIVING committed dates in slot order -- never the raw slot number
## and never the order the boards happened to finish in.
func _presentation_ordinal(site: Dictionary) -> int:
	if str(site["kind"]) != "surviving_date":
		return 0
	var superseded := _superseded_entry_ids()
	var ordered: Array = _active_committed_entries().duplicate(true)
	ordered.sort_custom(func(left: Variant, right: Variant) -> bool:
		return int((left as Dictionary).get("slot_index", 0)) \
			< int((right as Dictionary).get("slot_index", 0)))
	var ordinal := 0
	for entry_value: Variant in ordered:
		var entry: Dictionary = entry_value
		if not (str(entry.get("action_kind", "")) in HOSPITAL_RULES.DATE_KINDS):
			continue
		var entry_id := str(entry.get("schedule_entry_id", ""))
		if entry_id in superseded:
			continue
		if entry_id == str(site["schedule_entry_id"]):
			return ordinal
		ordinal += 1
	return -1


## The zero-based index of a stage in its own frozen stage array.
static func _stage_index(stage_name: String, source_day: int) -> int:
	return DAY_RESOLUTION_PLAN.stage_allowlist(source_day).find(stage_name)


## One committed entry from the aggregate this plan FROZE, never from live state.
func _committed_entry(schedule_entry_id: String) -> Dictionary:
	for entry_value: Variant in _active_committed_entries():
		var entry: Dictionary = entry_value
		if str(entry.get("schedule_entry_id", "")) == schedule_entry_id:
			return entry
	return {}


## One `derive_child()` call plus the four independent checks every Plan-01 producer performs.
func _derive_row(parent_receipt_id: String, child_kind: StringName, ordinal: int,
		tokens: Array) -> Dictionary:
	for token: String in tokens:
		if token.is_empty():
			return {"ok": false, "code": &"invalid_presentation_intent",
				"message": "a projection member is not canonically representable", "details": {}}
	var sources: Array = tokens.duplicate()
	sources.sort()
	var derived: Variant = _identity_issuer.call(&"derive_child", {
		"parent_receipt_id": parent_receipt_id,
		"child_kind": child_kind,
		"ordinal": ordinal,
		"source_ids": sources,
	})
	if typeof(derived) != TYPE_DICTIONARY or not (derived as Dictionary).get("ok", false):
		return {"ok": false, "code": &"presentation_identity_unavailable",
			"message": "the issuer refused the derivation",
			"details": {"child_kind": String(child_kind)}}
	var value: Variant = (derived as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("provenance")) != TYPE_DICTIONARY \
			or str((value as Dictionary).get("child_id", "")).is_empty():
		return {"ok": false, "code": &"presentation_identity_unavailable",
			"message": "the issuer returned no full provenance", "details": {}}
	var provenance: Dictionary = (value as Dictionary)["provenance"]
	if (derived as Dictionary).get("receipt") != provenance:
		return {"ok": false, "code": &"presentation_identity_unavailable",
			"message": "the issuer receipt is not byte-equal to its provenance", "details": {}}
	var revalidated: Variant = _identity_issuer.call(&"validate_child", provenance, child_kind)
	if typeof(revalidated) != TYPE_DICTIONARY or not (revalidated as Dictionary).get("ok", false):
		return {"ok": false, "code": &"presentation_identity_unavailable",
			"message": "the issuer refused to revalidate its own child", "details": {}}
	return {"ok": true, "code": &"ok", "value": {
		"child_id": str((value as Dictionary)["child_id"]), "provenance": provenance}}


## `L(id...)`: nonblank, unique, strictly sorted.
static func _id_list(ids: Array) -> Array[String]:
	var seen := {}
	var listed: Array[String] = []
	for id_value: Variant in ids:
		var id_text := str(id_value)
		if id_text.is_empty() or seen.has(id_text):
			continue
		seen[id_text] = true
		listed.append(id_text)
	listed.sort()
	return listed


## `P(path,value)` and `H(value)` from the matrix preamble, over the same canonical writer every
## other Plan-01 producer uses.
static func _project(path: String, value: Variant) -> String:
	var canonical: Dictionary = SCHEDULE_STATE_SCHEMA.canonical_json(value)
	if not canonical.get("ok", false):
		return ""
	return path + "=" + str((canonical["value"] as Dictionary)["text"])


static func _sha256(value: Variant) -> String:
	var hashed: Dictionary = SCHEDULE_STATE_SCHEMA.canonical_sha256(value)
	if not hashed.get("ok", false):
		return ""
	return str((hashed["value"] as Dictionary)["sha256"])


## The Hospital completion envelope, projected by the pure HospitalRules owner from condition truth
## plus the committed aggregate this plan froze (Task 7 Step 7.3, dwm-p2r.14).
##
## Condition truth comes from the owner's own pending-hospital flag, resolved by the earlier
## commit_outcomes stage -- never from a caller field. When Hospital triggers, EVERY committed date
## is superseded here, before the date stage runs a single board.
func _hospital_envelope() -> Dictionary:
	var required: bool = bool(_game_state.should_route_hospital()) 		if _game_state.has_method("should_route_hospital") else false
	var planned: Dictionary = HOSPITAL_RULES.plan_resolution({
		"required": required,
		"source_day": _active_source_day(),
		"committed_entries": _active_committed_entries(),
	})
	if not planned.get("ok", false):
		# A malformed committed aggregate cannot silently become "no Hospital"; report the
		# supersession set as unknown-empty and let the stage contract reject it.
		return {"required": required, "date_schedule_entry_ids": [],
			"superseded_entry_ids": [], "witness_entry_id": null,
			"presentation_completion_receipt": null}
	var value: Dictionary = planned["value"]
	var superseded: Array[String] = []
	for miss: Variant in (value["misses"] as Array):
		superseded.append(str((miss as Dictionary)["schedule_entry_id"]))
	var witness: Variant = value["witness"]
	return {
		"required": bool(value["required"]),
		"date_schedule_entry_ids": value["date_schedule_entry_ids"],
		"superseded_entry_ids": superseded,
		"witness_entry_id": str((witness as Dictionary)["schedule_entry_id"]) if witness != null else null,
		# Filled in by presentation_stage_receipt() when this Hospital actually presented.
		"presentation_completion_receipt": null,
	}


## The entry ids Hospital already superseded, read from this plan's COMPLETED hospital stage.
##
## Read from the durable stage receipt rather than recomputed, so a date substage resumed after a
## crash sees exactly the supersession the Hospital transaction committed.
func _superseded_entry_ids() -> Array:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return []
	for stage_value: Variant in ((plan as Dictionary).get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("stage_id", "")) != "hospital_if_triggered":
			continue
		var receipt: Variant = stage.get("receipt")
		if typeof(receipt) != TYPE_DICTIONARY:
			return []
		var value: Variant = (receipt as Dictionary).get("value")
		if typeof(value) != TYPE_DICTIONARY:
			return []
		var superseded: Variant = (value as Dictionary).get("superseded_entry_ids", [])
		return (superseded as Array) if typeof(superseded) == TYPE_ARRAY else []
	return []

## Drives the ONE configured Day7ScheduleProvenance service and returns its exact frozen
## `terminal_provenance` (Task 8 Step 8.7, dwm-p2r.14).
##
## Task 7 answered these two stages from the aggregate directly, which meant a Day-7 resolution
## could report a cause no issuer had ever anchored. Every input here is READ from the plan's frozen
## committed aggregate and the owner's own Contacts index -- never from a caller field -- and the
## service revalidates the issuer receipt, the saved registry fingerprint, the commit ancestry, and
## the source receipt before it derives anything.
##
## Deliberately absent: `date_completed`, planned UI state, a synthetic empty array standing in for
## a missing index, and any hospital-skipped counter. None of them is Day-7 proof.
func _day7_handoff() -> Dictionary:
	if _day7_provenance == null:
		return {"ok": false, "code": &"day7_provenance_unconfigured",
			"message": "the Day-7 handoff requires the one configured provenance service",
			"details": {}}
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_provenance_unavailable",
			"message": "no active resolution plan carries a committed Day-7 aggregate",
			"details": {}}
	var committed: Variant = (plan as Dictionary).get("committed_schedule")
	if typeof(committed) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_provenance_unavailable",
			"message": "the active plan carries no committed aggregate", "details": {}}
	var commit_receipt: Variant = (committed as Dictionary).get("commit_receipt")
	if typeof(commit_receipt) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_provenance_unavailable",
			"message": "a receiptless aggregate is not an accepted Day-7 cause", "details": {}}
	var contacts: Variant = _game_state.get("contacts")
	if typeof(contacts) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_source_index_unavailable",
			"message": "the owner exposes no Contacts source receipt index", "details": {}}
	var sources: Variant = (contacts as Dictionary).get("schedule_source_receipts", {})
	if typeof(sources) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"day7_source_index_unavailable",
			"message": "the Contacts source receipt index is malformed", "details": {}}
	return _day7_provenance.call(&"validate_handoff", {
		"transaction_id": str((commit_receipt as Dictionary)["transaction_id"]),
		"transaction_issuer_receipt":
			((commit_receipt as Dictionary)["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": str((commit_receipt as Dictionary)["causal_day_instance"]),
		"committed_schedule": (committed as Dictionary).duplicate(true),
		"source_receipt_index": (sources as Dictionary).duplicate(true),
	})


## The derived row, for the two stages that already passed the same guard in begin_next_stage().
## Deterministic for one frozen aggregate, so validate and checkpoint cannot disagree.
func _day7_terminal_provenance() -> Dictionary:
	var handoff := _day7_handoff()
	if not handoff.get("ok", false):
		return {"cause": "", "schedule_entry_id": null, "source_receipt_id": null,
			"schedule_commit_receipt_id": null, "receipt_id": "", "receipt_provenance": {}}
	return ((handoff["value"] as Dictionary)["terminal_provenance"] as Dictionary)


func _active_committed_entries() -> Array:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return []
	var aggregate: Variant = (plan as Dictionary).get("committed_schedule")
	if typeof(aggregate) != TYPE_DICTIONARY:
		return []
	var entries: Variant = (aggregate as Dictionary).get("entries", [])
	return (entries as Array) if typeof(entries) == TYPE_ARRAY else []


func _active_commit_receipt_id() -> Variant:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return null
	return (plan as Dictionary).get("schedule_commit_receipt_id")


func _resolved_primary_id() -> String:
	var route_context: Dictionary = _game_state.route_context
	return str(route_context.get("ending_id", "ending.alone"))

func _default_ending_plan() -> Dictionary:
	return {
		"ending_id": _resolved_primary_id(),
		"epilogue_ending_id": "",
		"source_day": 7,
		"playback_stage": "PRIMARY_PENDING",
		"playback_receipts": {},
	}

static func _envelope(owner_id: String, kind: String, value: Dictionary) -> Dictionary:
	return {"owner_id": owner_id, "kind": kind, "value": value}

static func _plan_receipt_from_envelope(envelope: Dictionary) -> Dictionary:
	var value: Dictionary = envelope["value"]
	match str(envelope["kind"]):
		"day_increment":
			return {"value": {"day": int(value["target_day"])}}
		"enter_ending":
			var epilogue: Variant = value.get("epilogue_id")
			return {"value": {"ending_plan": {
				"ending_id": str(value["primary_id"]),
				"epilogue_ending_id": str(epilogue) if epilogue != null else "",
				"source_day": 7,
				"playback_stage": "PRIMARY_PENDING",
				"playback_receipts": {},
			}}}
	return {"value": value.duplicate(true)}
