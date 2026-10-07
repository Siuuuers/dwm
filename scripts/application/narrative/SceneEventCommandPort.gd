class_name SceneEventCommandPort
extends RefCounted
## Synchronous admission through the shared causal gate. The injected owner keeps
## the only receipt map and commits before adopting. Fatal custody is irreversible.

const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
var _owner: Object
var _gate: RefCounted
var _issuer: RefCounted

func configure(owner: Object, gate: RefCounted, issuer: RefCounted) -> Dictionary:
	if _owner != null: return _fail(&"event_port_already_configured")
	if owner == null or gate == null or gate.get_script() != GATE or issuer == null or issuer.get_script() != ISSUER:
		return _fail(&"event_dependency_invalid")
	for method: String in ["scene_event_context", "lookup_scene_event", "accept_scene_event"]:
		if not owner.has_method(method): return _fail(&"event_dependency_invalid")
	_owner = owner
	_gate = gate
	_issuer = issuer
	return {"ok": true}

func dispatch(envelope: Variant) -> Dictionary:
	if not is_instance_valid(_owner): return _fail(&"event_port_unconfigured")
	var shaped: Dictionary = CONTRACT.inspect(envelope)
	if not shaped.get("ok", false): return shaped
	var guarded: Dictionary = _gate.guard_external(&"scene_event")
	if not guarded.get("ok", false): return guarded
	var acquired: Dictionary = _gate.acquire(&"causal_transaction")
	if not acquired.get("ok", false): return acquired
	var lease: String = acquired.value.token
	var result: Dictionary = _dispatch_owned(envelope.duplicate(true), shaped.value.digest, lease)
	var released: Dictionary = _gate.release(&"causal_transaction", lease)
	if not released.get("ok", false): return released
	return result.duplicate(true)

func _dispatch_owned(event: Dictionary, digest: String, lease: String) -> Dictionary:
	var raw: Variant = _owner.call(&"scene_event_context")
	if not raw is Dictionary or not raw.get("ok", false) or not raw.get("value") is Dictionary:
		return _fail(&"event_context_unavailable")
	var context: Dictionary = raw.value
	# Absent flags fail closed. The caller cannot supply its own admission context.
	if context.get("mode") != "canonical" or context.get("suspended") != false or context.get("computer_held") != false:
		return _fail(&"event_presentation_held")
	if context.get("source") != event.source: return _fail(&"event_source_mismatch")
	if context.get("playback_token") != event.playback_token: return _fail(&"event_stale_token")
	var proven: Dictionary = _issuer.verify_issued(event.issuer_receipt, &"transaction_id")
	if not proven.get("ok", false): return proven
	if event.command_id != event.issuer_receipt.get("token"): return _fail(&"event_command_mismatch")
	# Authenticate before lookup. Lookup must compare digest and report unresolved
	# custody without invoking effects. It is the authoritative owner's operation.
	var retained: Variant = _owner.call(&"lookup_scene_event", event.command_id, digest)
	if not retained is Dictionary or typeof(retained.get("ok")) != TYPE_BOOL:
		return _fail(&"event_owner_result_invalid")
	if not retained.ok: return retained
	if typeof(retained.get("found")) != TYPE_BOOL: return _fail(&"event_owner_result_invalid")
	if retained.found: return retained
	var record: Variant
	if _owner.has_method("scene_event_registration"):
		var registration: Dictionary = _owner.call(&"scene_event_registration", event)
		if not registration.get("ok", false): return registration
		record = registration.value
	else:
		if not context.get("registrations") is Dictionary: return _fail(&"event_registration_invalid")
		record = context.registrations.get(event.event_id)
	var registered: Dictionary = CONTRACT.match_registration(event, record)
	if not registered.get("ok", false): return registered
	if typeof(context.get("next_ordinal")) != TYPE_INT or context.next_ordinal != event.ordinal \
			or context.get("predecessor") != event.predecessor:
		return _fail(&"event_frontier_mismatch")
	if not _gate.is_lease_active(&"causal_transaction", lease): return _fail(&"event_lease_lost")
	var accepted: Variant = _owner.call(&"accept_scene_event", event, digest, lease)
	if not accepted is Dictionary or typeof(accepted.get("ok")) != TYPE_BOOL:
		return _fail(&"event_owner_result_invalid")
	return accepted

func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
