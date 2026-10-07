extends RefCounted
## TEST ONLY: invented registrations and in-memory retained outcome owner.
## No production story, actual History/DTL runtime, storage or crash simulation.
## The production issuer is backed by the existing explicitly fake root store.
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const PORT := preload("res://scripts/application/narrative/SceneEventCommandPort.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
var gate: RefCounted = GATE.new()
var issuer: RefCounted = ISSUER.new()
var issuer_root: RefCounted = ROOT.new("ab".repeat(32), 1)
var source := {"run_id": "TEST.run", "branch_id": "TEST.branch", "causal_day_instance": "TEST.day",
	"scene_occurrence": "TEST.occurrence", "entry_id": "TEST.scene", "content_version": 1}
var playback_token := "TEST.playback.1"
var mode := "canonical"
var suspended := false
var computer_held := false
var events: Array[Dictionary] = []
var registrations := {}
var receipts := {}
var pending_command := ""
var next_ordinal := 0
var predecessor := ""
var effect_calls := 0
var publications: Array[String] = []
var uncertain_next := false
var refuse_next := false

func _init(with_self_talk: bool = true) -> void:
	issuer.configure(issuer_root)
	_append("scene.enter", {"scene_id": "TEST.A", "entry_id": "TEST.A", "context_id": "TEST.context"})
	if with_self_talk:
		_append("self_talk.trigger", {"entry_id": "TEST.selftalk.A", "segment_id": "TEST.segment.A"})
	_append("scene.enter", {"scene_id": "TEST.B", "entry_id": "TEST.B", "context_id": "TEST.context"})
	_append("day.begin", {"source_phase": "TEST.opening", "target_day": 1})
	_append("day.complete", {"source_day": 1, "successor_id": "TEST.day2"})
	_append("background.set", {"art_id": "TEST.art"})
	_append("notification.set", {"notification_id": "TEST.notice", "content_id": "TEST.copy", "parameters": {"count": 1}})
	_append("notification.clear", {"notification_id": "TEST.notice"})
	_append("appointment.admit", {"appointment_id": "TEST.appointment", "invitation_receipt_id": "TEST.invitation"})
	_append("appointment.complete", {"appointment_id": "TEST.appointment", "completion_receipt_id": "TEST.completion"})

func make_port() -> RefCounted:
	var port: RefCounted = PORT.new()
	port.configure(self, gate, issuer)
	return port

func event_at(index: int) -> Dictionary:
	var event: Dictionary = events[index].duplicate(true)
	event.playback_token = playback_token
	return event

func scene_event_context() -> Dictionary:
	return {"ok": true, "value": {"source": source.duplicate(true), "playback_token": playback_token,
		"mode": mode, "suspended": suspended, "computer_held": computer_held,
		"next_ordinal": next_ordinal, "predecessor": predecessor,
		"registrations": registrations.duplicate(true)}}

func lookup_scene_event(command_id: String, digest: String) -> Dictionary:
	if receipts.has(command_id):
		var record: Dictionary = receipts[command_id]
		if record.digest != digest: return {"ok": false, "code": &"event_conflict"}
		if record.state == "uncertain": return {"ok": false, "code": &"event_uncertain"}
		return {"ok": true, "found": true, "value": record.outcome.duplicate(true)}
	if not pending_command.is_empty(): return {"ok": false, "code": &"event_pending_custody"}
	return {"ok": true, "found": false}

func accept_scene_event(event: Dictionary, digest: String, lease: String) -> Dictionary:
	if not gate.is_lease_active(&"causal_transaction", lease): return {"ok": false, "code": &"TEST.lease_required"}
	var looked := lookup_scene_event(event.command_id, digest)
	if not looked.ok or looked.found: return looked
	if event.source != source or event.playback_token != playback_token or event.ordinal != next_ordinal \
			or event.predecessor != predecessor or mode != "canonical" or suspended or computer_held:
		return {"ok": false, "code": &"TEST.source_changed"}
	var registered: Dictionary = CONTRACT.match_registration(event, registrations.get(event.event_id))
	if not registered.ok: return registered
	if refuse_next:
		refuse_next = false
		return {"ok": false, "code": &"TEST.proven_refusal"}
	effect_calls += 1
	receipts[event.command_id] = {"digest": digest, "state": "uncertain", "event": event.duplicate(true)}
	pending_command = event.command_id
	if uncertain_next:
		uncertain_next = false
		return {"ok": false, "code": &"event_uncertain"}
	_finish_committed(event.command_id)
	return lookup_scene_event(event.command_id, digest)

## TEST ONLY external owner resolution: establish the already-invoked effect's
## committed outcome, without invoking it a second time. Not a disk recovery proof.
func resolve_committed() -> void:
	assert(not pending_command.is_empty())
	_finish_committed(pending_command)

func observable_state() -> Dictionary:
	return {"frontier": next_ordinal, "predecessor": predecessor, "effects": effect_calls,
		"publications": publications.duplicate(), "receipts": receipts.duplicate(true), "pending": pending_command}

func _finish_committed(command_id: String) -> void:
	var event: Dictionary = receipts[command_id].event
	if event.kind == "scene.enter" or event.kind == "self_talk.trigger":
		publications.append(event.payload.entry_id)
	next_ordinal = event.ordinal + 1
	predecessor = event.event_id
	receipts[command_id].state = "committed"
	receipts[command_id].outcome = {"command_id": command_id, "event_id": event.event_id,
		"digest": receipts[command_id].digest, "next_ordinal": next_ordinal}
	pending_command = ""

func _append(kind: String, payload: Dictionary) -> void:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	var event := {"schema_version": 1, "source": source.duplicate(true), "event_id": "TEST.event.%d" % events.size(),
		"ordinal": events.size(), "predecessor": "" if events.is_empty() else events.back().event_id,
		"kind": kind, "payload": payload.duplicate(true), "command_id": issued.value.token,
		"issuer_receipt": issued.value.issuer_receipt.duplicate(true), "playback_token": playback_token}
	var record := {}
	for key: String in CONTRACT.RECORD_KEYS: record[key] = event[key]
	registrations[event.event_id] = record.duplicate(true)
	events.append(event)
