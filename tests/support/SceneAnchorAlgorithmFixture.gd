extends RefCounted
## Component-only input corpus. It creates no Run/issuer/storage authority.
const READING := preload("res://tests/support/SceneDayReadingFixture.gd")

static func build(publications: int = 14) -> Dictionary:
	var configured := READING.configure()
	if not configured.ok: return configured
	var made := READING.create_session()
	if not made.ok: return made
	var session: RefCounted = made.value
	for index: int in publications:
		var entered := READING.enter(session, READING.A, "anchor-visit:%d" % index)
		if not entered.ok: return entered
	var captured := READING.checkpoint(session)
	if not captured.ok: return captured
	var checkpoint: Dictionary = captured.value
	var anchors: Array[Dictionary] = []
	for row: Dictionary in checkpoint.reading_session.ledger.captions:
		anchors.append({"session_id": row.occurrence_id, "entry_id": row.beat.owning_entry_id,
			"content_version": session.catalogue[row.beat.owning_entry_id].content_version,
			"catalogue_fingerprint": session.fingerprint,
			"publication_id": row.publication_id, "line_id": row.beat.line_id})
	return {"ok": true, "value": {"checkpoint": checkpoint, "anchors": anchors}}
