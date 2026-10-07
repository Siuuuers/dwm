extends "res://tests/support/DurableSceneEventFixture.gd"
## Non-canon authored marker programme; production startup never registers it.
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const BASE := preload("res://tests/support/ReadingNextFixture.gd")
const ENTRY := BASE.ENTRY
const FIRST := "fixture.next.a"
const SECOND := "fixture.next.b"
const EVENT := "fixture.notice.set"
const PATH := "res://tests/fixtures/dialogic/scene_next_notification.dtl"

static func catalogue() -> Dictionary:
	return {"kind": "solo_reading_catalogue", "schema_version": 1, "entries": [
		{"entry_id": ENTRY, "content_version": 1, "lines": [
			{"beat_id": "fixture.next.beat.a", "line_id": FIRST, "text": "FIRST: a deliberately long partial reveal that remains visible until one Next activation finishes it and commits the registered notification without publishing SECOND.", "revision": "fixture-v1"},
			{"beat_id": "fixture.next.beat.b", "line_id": SECOND, "text": "SECOND: visible only after the next deliberate activation.", "revision": "fixture-v1"}]},
		{"entry_id": "dating.solo.priscilla.day1.post_challenge", "content_version": 1, "lines": [
			{"beat_id": "fixture.next.post", "line_id": "fixture.next.post", "text": "POST", "revision": "fixture-v1"}]}]}

static func markers(fingerprint: String) -> Dictionary:
	return {"kind": "reading_notification_markers", "schema_version": 1, "entries": [
		{"entry_id": ENTRY, "content_version": 1, "catalogue_fingerprint": fingerprint, "marker": {
			"event_id": EVENT, "ordinal": 0, "predecessor": "", "kind": "notification.set",
			"payload": {"notification_id": "fixture.notice", "content_id": "fixture.notice.text", "parameters": {}},
			"after_line_id": FIRST, "before_line_id": SECOND, "label": "scene.marker." + EVENT}}]}

static func configured(document: Dictionary = {}) -> RefCounted:
	var session := SESSION.new()
	var result: Dictionary = session.configure(catalogue() if document.is_empty() else document)
	if not result.ok: return null
	result = session.configure_markers(markers(session.fingerprint))
	return session if result.ok else null

static func started(publish: bool = true) -> RefCounted:
	var session: RefCounted = configured()
	if session == null: return null
	var seed := BASE.snapshot()
	var reading: Dictionary = seed.narrative_checkpoint.reading_session
	if not session.begin(reading.ledger.session_token, ENTRY).ok: return null
	if not session.admit(ENTRY, seed.narrative_checkpoint.frozen_context).ok: return null
	if publish:
		var allocation: Dictionary = session.ledger.allocate_publication(session.command_id, ENTRY)
		if not allocation.ok: return null
		if not session.ledger.publish_line(session.command_id, allocation.value, ENTRY, FIRST).ok: return null
	return session

static func frontier(session: RefCounted) -> Dictionary:
	var tail: Dictionary = session.ledger.snapshot().captions.back()
	return {"line_id": tail.beat.line_id, "publication_id": tail.publication_id}

static func semantic(session: RefCounted) -> Dictionary:
	var seed := BASE.snapshot()
	return {"schema_version": 1, "source": {"run_id": seed.run_id,
		"branch_id": seed.lifecycle.branch_id, "causal_day_instance": "fixture.day.1",
		"scene_occurrence": session.command_id, "entry_id": ENTRY, "content_version": 1},
		"event_id": EVENT, "ordinal": 0, "predecessor": "", "kind": "notification.set",
		"payload": {"notification_id": "fixture.notice", "content_id": "fixture.notice.text", "parameters": {}},
		"command_id": "fixture.marker.command", "issuer_receipt": {"token": "fixture.marker.command"}}

func initialize_with_bridge(bridge: Node) -> Dictionary:
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
	real = MarkerFaultPort.new(manager)
	real.files = files
	result = real.configure_fatal_latch(gate)
	if not result.ok: return result
	context = CONTEXT.new()
	context.route_id_value = "dating"
	context.audio_context_value = snapshot.audio_context.duplicate(true)
	context.content_version_value = snapshot.content_version
	adapter = ADAPTER.new()
	var providers: Dictionary = context.provider_callables()
	providers.snapshot_input = Callable(game, "capture_run_snapshot_input")
	result = adapter.configure(real, providers)
	if not result.ok: return result
	result = game.configure_narrative_checkpoint_port(adapter)
	if not result.ok: return result
	result = game.configure_scene_event_owner(bridge)
	if not result.ok: return result
	result = game.configure_test_scene_event_registry(registry())
	if not result.ok: return result
	port = PORT.new()
	result = port.configure(game, gate, issuer)
	if not result.ok: return result
	result = bridge.configure_mutation_gate(gate)
	if not result.ok: return result
	result = bridge.configure_narrative_checkpoint_port(adapter)
	if not result.ok: return result
	return bridge.configure_scene_event_port(port, Callable(game, "validate_live_session"), Callable(game, "scene_event_context"))

## Failure is armed at the actual disk commit, after production preimage capture.
class MarkerFaultPort extends "res://scripts/application/run/SaveManagerCheckpointPort.gd":
	var files: RefCounted
	var commits := 0
	var fail_on_commit := 0
	func commit(candidate: Dictionary) -> Dictionary:
		commits += 1
		if commits == fail_on_commit:
			files.fail_after(files.operation_count() + 1)
		return super.commit(candidate)
