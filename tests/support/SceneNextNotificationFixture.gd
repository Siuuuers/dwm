extends RefCounted
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
			{"beat_id": "fixture.next.beat.a", "line_id": FIRST, "text": "FIRST — a deliberately long partial reveal that remains visible until one Next activation finishes it and commits the registered notification without publishing SECOND.", "revision": "fixture-v1"},
			{"beat_id": "fixture.next.beat.b", "line_id": SECOND, "text": "SECOND — visible only after the next deliberate activation.", "revision": "fixture-v1"}]},
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
