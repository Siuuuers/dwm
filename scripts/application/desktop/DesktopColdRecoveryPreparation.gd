class_name DesktopColdRecoveryPreparation
extends RefCounted

## Startup-only source installation for a pending desktop transaction. This never loads a
## chosen slot, allocates a branch, activates a session, finalizes a route, or edits Profile.
## The source checkpoint must have committed BEFORE admission and its exact reference must
## be retained in recovery_payload.action_candidate.source_checkpoint. Bootstrap owns the later replay.
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const OWNER_ORDER := ["run", "desktop_consequence", "desktop_board", "schedule_view"]
const PLAN_KEYS := {"run": "run_plan", "desktop_consequence": "consequence_plan",
	"desktop_board": "board_plan", "schedule_view": "schedule_view_plan"}

var _manager: Object
var _checkpoint: Object
var _game_state: Object
var _host: Object
var _prepared: Dictionary = {}
var _gate_token := ""
var _next_owner := 0
var _installed := false

func configure(manager: Object, checkpoint: Object, game_state: Object, host: Object) -> Dictionary:
	if manager == null or checkpoint == null or game_state == null or host == null:
		return _fail(&"cold_recovery_not_configured")
	if _manager != null:
		return {"ok": true} if _manager == manager and _checkpoint == checkpoint \
			and _game_state == game_state and _host == host else _fail(&"cold_recovery_already_configured")
	_manager = manager
	_checkpoint = checkpoint
	_game_state = game_state
	_host = host
	return {"ok": true}

## Only CURRENT Autosave is read. A historical manual/quick or recovery-journal bundle
## can never be selected by this helper, even when it shares the same original branch.
func prepare_current_autosave() -> Dictionary:
	if _manager == null: return _fail(&"cold_recovery_not_configured")
	if not _prepared.is_empty():
		if _game_state.capture_live_session().value.active:
			return _fail(&"cold_recovery_requires_inactive_session")
		return {"ok": true, "value": {"kind": "install_source"}}
	var pending_read: Dictionary = _checkpoint.read_pending_consequence_checkpoint()
	if not pending_read.get("ok", false): return pending_read
	if not pending_read.value.get("found", false):
		# Earlier continuation recovery may already have activated a New Run or Load.
		# With no pending desktop action, there is no cold source to install or replay.
		return {"ok": true, "value": {"kind": "none"}}
	if _game_state.capture_live_session().value.active:
		return _fail(&"cold_recovery_requires_inactive_session")
	var pending_state: Dictionary = pending_read.value.stage_candidate
	var pending: Dictionary = pending_state.pending
	if str(pending.stage) == "action_prepared" \
			and str(pending.recovery_payload.get("payload_phase", "")) != "admission_ready":
		return {"ok": true, "value": {"kind": "abandon_source_only"}}
	var read := _read_document()
	if not read.get("ok", false): return read
	var document: Dictionary = read.value
	var bundle: Dictionary = document.current_snapshot
	var snapshot: Dictionary = bundle.snapshot
	var binding := validate_source_binding(snapshot, pending_state)
	if not binding.get("ok", false): return binding
	if snapshot.route_id != "main" or not snapshot.narrative_checkpoint.is_empty():
		return _fail(&"cold_recovery_requires_desktop_source")
	var inputs := {
		"run": {"snapshot": snapshot},
		"desktop_consequence": {"state": pending_state},
		"desktop_board": {"state": snapshot.desktop.board},
		"schedule_view": _manager._schedule_view_input(snapshot),
	}
	var plans := {}
	for owner: String in OWNER_ORDER:
		if not _manager._restore_participants.has(owner):
			return _fail(&"cold_recovery_owner_unavailable")
		var prepared: Dictionary = _manager._restore_participants[owner].prepare(inputs[owner])
		if not prepared.get("ok", false): return prepared
		plans[owner] = prepared.value[PLAN_KEYS[owner]]
	var host_plan: Dictionary = _host.prepare_restore(snapshot.active_app_id, int(snapshot.lifecycle.day))
	if not host_plan.get("ok", false): return host_plan
	var journal: Dictionary = _manager._journal.prepare_seed(document, bundle)
	if not journal.get("ok", false): return journal
	_prepared = {"snapshot": snapshot.duplicate(true), "document_hash": _digest(document),
		"plans": plans, "host": host_plan.value.candidate_state,
		"journal": journal.value.candidate}
	return {"ok": true, "value": {"kind": "install_source"}}

## Retains install progress on failure; retry must not reapply a source over an action
## that has already advanced. No participant finalize or live-session publication occurs.
func install_prepared() -> Dictionary:
	if _prepared.is_empty(): return _fail(&"cold_recovery_source_not_prepared")
	if _installed: return {"ok": true}
	if _game_state.capture_live_session().value.active:
		return _fail(&"cold_recovery_requires_inactive_session")
	var gate: Object = _manager._mutation_gate
	if gate == null: return _fail(&"cold_recovery_gate_unavailable")
	if _gate_token.is_empty():
		var acquired: Dictionary = gate.acquire(&"causal_transaction")
		if not acquired.get("ok", false): return acquired
		_gate_token = str(acquired.value.token)
		var reread := _read_document()
		if not reread.get("ok", false) or _digest(reread.get("value", {})) != _prepared.document_hash:
			gate.release(&"causal_transaction", _gate_token)
			_gate_token = ""
			return _fail(&"cold_recovery_source_changed")
	while _next_owner < OWNER_ORDER.size():
		var owner: String = OWNER_ORDER[_next_owner]
		var applied: Dictionary = _manager._restore_participants[owner].apply_silent(_prepared.plans[owner])
		if not applied.get("ok", false): return applied
		_next_owner += 1
	var host_applied: Dictionary = _host.commit_restore(_prepared.host)
	if not host_applied.get("ok", false): return host_applied
	var seeded: Dictionary = _manager._journal.commit_prepared(_prepared.journal)
	if not seeded.get("ok", false): return seeded
	var released: Dictionary = gate.release(&"causal_transaction", _gate_token)
	if not released.get("ok", false): return released
	_gate_token = ""
	_installed = true
	return {"ok": true}

func is_installed() -> bool:
	return _installed

func finish_recovery() -> Dictionary:
	if not _installed: return {"ok": true}
	if _manager._mutation_gate.is_active(): return _fail(&"cold_recovery_still_active")
	var consequence: Dictionary = _manager._restore_participants.desktop_consequence.capture()
	if not consequence.get("ok", false): return consequence
	if consequence.value.state.pending != null: return _fail(&"cold_recovery_still_pending")
	_prepared = {}
	_next_owner = 0
	_installed = false
	return {"ok": true}

## During cold replay, the physical Title is still mounted. Use the saved desktop
## presentation metadata with CURRENT domain state, not Title's route or audio values.
func capture_completed_checkpoint_inputs(completed: Dictionary) -> Dictionary:
	if not _installed: return _fail(&"cold_recovery_source_not_installed")
	if not _manager._mutation_gate.is_internal_owner_active(&"causal_transaction"):
		return _fail(&"causal_transaction_lease_required")
	var source: Dictionary = _prepared.snapshot
	var view: Dictionary = _manager._restore_participants.schedule_view.capture()
	if not view.get("ok", false): return view
	var input: Dictionary = _game_state.capture_run_snapshot_input()
	input.schedule_view = view.value.backup
	input.desktop.consequence = completed.duplicate(true)
	return {"ok": true, "value": {"checkpoint_inputs": {
		"snapshot_input": input, "dialogic_checkpoint": source.narrative_checkpoint.duplicate(true),
		"route_id": source.route_id, "active_app_id": source.active_app_id,
		"audio_context": source.audio_context.duplicate(true), "content_version": source.content_version,
	}}}

static func source_checkpoint_reference(snapshot: Dictionary) -> Dictionary:
	return {"checkpoint_id": str(snapshot.get("checkpoint_id", "")), "snapshot_sha256": _digest(snapshot)}

static func validate_source_binding(snapshot: Dictionary, pending_state: Dictionary) -> Dictionary:
	var pending: Dictionary = pending_state.get("pending", {})
	var payload: Dictionary = pending.get("recovery_payload", {})
	var reference: Variant = payload.get("action_candidate", {}).get("source_checkpoint")
	if not reference is Dictionary or reference.size() != 2 \
			or reference.get("checkpoint_id") != snapshot.get("checkpoint_id") \
			or reference.get("snapshot_sha256") != _digest(snapshot):
		return _fail(&"cold_recovery_source_checkpoint_mismatch")
	var action: Dictionary = payload.get("action_receipt", {})
	for recipe: Dictionary in payload.get("publication_plan", []):
		if str(recipe.get("participant", "")) == "action_source":
			action = recipe.get("publication", {}).get("action_receipt", {})
			break
	var valid_action: Dictionary = ACTION_RECEIPT.validate(action)
	if not valid_action.get("ok", false): return valid_action
	for field: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "day"]:
		if action[field] != snapshot.get("lifecycle", {}).get(field):
			return _fail(&"cold_recovery_source_identity_mismatch")
	if str(pending.get("transaction_id", "")) != str(action.transaction_id) \
			or str(pending_state.get("causal_day_instance", "")) != str(action.causal_day_instance):
		return _fail(&"cold_recovery_source_identity_mismatch")
	if snapshot.get("desktop", {}).get("consequence", {}).get("pending") != null:
		return _fail(&"cold_recovery_source_must_precede_admission")
	return {"ok": true}

func _read_document() -> Dictionary:
	var read: Dictionary = _manager._storage.read_text("autosave.json")
	if not read.get("ok", false): return read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(read.value))
	if not parsed.get("ok", false): return parsed
	var validated: Dictionary = DOCUMENT.validate(parsed.value)
	if not validated.get("ok", false): return validated
	var document: Dictionary = validated.value.candidate
	if document.kind != "autosave": return _fail(&"cold_recovery_requires_autosave")
	return {"ok": true, "value": document}

static func _digest(value: Variant) -> String:
	var canonical: Dictionary = CANON.stringify(value)
	return str(canonical.value).sha256_text() if canonical.get("ok", false) else ""

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
