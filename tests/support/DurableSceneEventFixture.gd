extends RefCounted
## Integration-only composition: real Run/save/journal owners with FakeFileOps,
## a fake issuer root, and fixed reading/Schedule capture inputs. No UI or crash proof.
const READING := preload("res://tests/support/ReadingNextFixture.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const GAME := preload("res://autoload/GameState.gd")
const SAVE := preload("res://autoload/SaveManager.gd")
const PORT := preload("res://scripts/application/narrative/SceneEventCommandPort.gd")
const ADAPTER := preload("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const CONTEXT := preload("res://tests/support/FakeNarrativeCheckpointContext.gd")

static func registry() -> Dictionary:
	var registered := {READING.ENTRY: {"content_version": 1, "events": {
		"fixture.notice.set": {"event_id": "fixture.notice.set", "ordinal": 0, "predecessor": "",
			"kind": "notification.set", "payload": {"notification_id": "fixture.notice",
				"content_id": "fixture.notice.text", "parameters": {}}},
		"fixture.notice.clear": {"event_id": "fixture.notice.clear", "ordinal": 1,
			"predecessor": "fixture.notice.set", "kind": "notification.clear",
			"payload": {"notification_id": "fixture.notice"}},
		"fixture.background": {"event_id": "fixture.background", "ordinal": 2,
			"predecessor": "fixture.notice.clear", "kind": "background.set",
			"payload": {"art_id": "fixture.art"}}}}}
	registered["dating.solo.priscilla.day1.post_challenge"] = registered[READING.ENTRY].duplicate(true)
	return registered

class ReadingBoundary extends RefCounted:
	var checkpoint: Dictionary
	var token := "fixture.live.1"
	var held := false
	func anchor() -> Dictionary:
		return {"session_id": checkpoint.reading_session.ledger.session_token,
			"entry_id": checkpoint.entry_id, "content_version": checkpoint.content_version,
			"catalogue_fingerprint": checkpoint.reading_session.catalogue_fingerprint,
			"publication_id": checkpoint.reading_session.frontier.publication_id,
			"line_id": checkpoint.reading_session.frontier.line_id}
	func capture_scene_event_boundary() -> Dictionary:
		if held: return {"ok": false, "code": &"event_presentation_held"}
		return {"ok": true, "value": {"anchor": anchor(), "checkpoint": checkpoint.duplicate(true),
			"playback_token": token}}
	func validate_scene_event_anchor(saved: Dictionary, selected: Dictionary) -> Dictionary:
		return {"ok": selected == checkpoint and saved == anchor()}

class ViewCapture extends RefCounted:
	var view: Dictionary
	func capture() -> Dictionary:
		return {"ok": true, "value": {"backup": view.duplicate(true)}}

## Arm only after prepare has captured the real storage preimage; the next actual
## FileOps action fails once. All compensation then runs on the production port.
class FaultPort extends "res://scripts/application/run/SaveManagerCheckpointPort.gd":
	var files: RefCounted
	var fail_next_write := false
	var commits := 0
	func commit(candidate: Dictionary) -> Dictionary:
		commits += 1
		if fail_next_write:
			fail_next_write = false
			files.fail_after(files.operation_count() + 1)
		return super.commit(candidate)

var game: Node
var manager: Node
var gate: RefCounted
var issuer: RefCounted
var issuer_root: RefCounted
var files: RefCounted
var storage: RefCounted
var real: RefCounted
var adapter: RefCounted
var boundary: RefCounted
var view: RefCounted
var context: RefCounted
var port: RefCounted
var snapshot: Dictionary
var commands: Array[Dictionary] = []

func initialize() -> Dictionary:
	var made: Dictionary = preload("res://tests/support/TemporaryStorage.gd").create("durable_scene_event")
	if not made.ok: return made
	files = OPS.new()
	storage = STORAGE.new(str(made.value).path_join("saves"), files)
	manager = SAVE.new()
	var result: Dictionary = manager.initialize(storage)
	if not result.ok: return result
	gate = GATE.new()
	result = manager.configure_mutation_gate(gate)
	if not result.ok: return result
	game = GAME.new()
	game.reset_game()
	result = game.configure_mutation_gate(gate)
	if not result.ok: return result
	issuer_root = ROOT.new("ab".repeat(32), 1)
	issuer = ISSUER.new()
	result = issuer.configure(issuer_root)
	if not result.ok: return result
	result = game.configure_identity_issuer(issuer)
	if not result.ok: return result
	snapshot = READING.snapshot()
	var acquired: Dictionary = gate.acquire(&"new_run")
	if not acquired.ok: return acquired
	result = game.apply_restore_silent({"snapshot": snapshot})
	if not result.ok: return result
	var session: Dictionary = game.capture_live_session()
	result = game.activate_live_session({"operation_id": "fixture.install",
		"expected_generation": session.value.generation, "owner_id": game.get_instance_id(),
		"run_id": snapshot.run_id})
	if not result.ok: return result
	result = gate.release(&"new_run", acquired.value.token)
	if not result.ok: return result
	result = manager._journal.reset(snapshot.run_id)
	if not result.ok: return result
	view = ViewCapture.new()
	view.view = snapshot.schedule_view.duplicate(true)
	manager._restore_participants = {"schedule_view": view}
	real = FaultPort.new(manager)
	real.files = files
	result = real.configure_fatal_latch(gate)
	if not result.ok: return result
	context = CONTEXT.new()
	context.route_id_value = "dating"
	context.audio_context_value = snapshot.audio_context.duplicate(true)
	context.content_version_value = snapshot.content_version
	adapter = ADAPTER.new()
	result = adapter.configure(real, context.provider_callables())
	if not result.ok: return result
	result = game.configure_narrative_checkpoint_port(adapter)
	if not result.ok: return result
	boundary = ReadingBoundary.new()
	boundary.checkpoint = snapshot.narrative_checkpoint.duplicate(true)
	result = game.configure_scene_event_owner(boundary)
	if not result.ok: return result
	result = game.configure_test_scene_event_registry(registry())
	if not result.ok: return result
	port = PORT.new()
	result = port.configure(game, gate, issuer)
	if not result.ok: return result
	var owner_context: Dictionary = game.scene_event_context()
	if not owner_context.ok: return owner_context
	for id: String in ["fixture.notice.set", "fixture.notice.clear", "fixture.background"]:
		var event: Dictionary = registry()[READING.ENTRY].events[id].duplicate(true)
		var issued: Dictionary = issuer.issue(&"transaction_id")
		if not issued.ok: return issued
		event["schema_version"] = 1
		event["source"] = owner_context.value.source.duplicate(true)
		event["command_id"] = issued.value.token
		event["issuer_receipt"] = issued.value.issuer_receipt
		event["playback_token"] = owner_context.value.playback_token
		commands.append(event)
	return {"ok": true}

func event_at(index: int) -> Dictionary:
	return commands[index].duplicate(true)

func disk_snapshot() -> Dictionary:
	var read: Dictionary = storage.read_text("autosave.json")
	if not read.ok: return read
	var parsed: Dictionary = STRICT.parse_object(read.value)
	if not parsed.ok: return parsed
	var validated: Dictionary = DOCUMENT.validate(parsed.value)
	if not validated.ok: return validated
	return {"ok": true, "value": validated.value.candidate.current_snapshot.snapshot}

func dispose() -> void:
	if is_instance_valid(game): game.free()
	if is_instance_valid(manager): manager.free()
