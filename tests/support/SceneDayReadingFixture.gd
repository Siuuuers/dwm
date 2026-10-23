extends RefCounted
## TEST-only detached reading fixture. Must run in its own Godot process:
## immutable scene selection cannot coexist with prior legacy manifest loading.
## This is not a saved Run, issuer admission, or confirmed storage commit.
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const JSON_READER := preload("res://scripts/validation/StrictJson.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const OP := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const REGISTRATION := "res://tests/fixtures/dialogic/scene_reading_registration.json"
const A := "scene.test.a"
const B := "scene.test.b"
const CONTACT := "contact.test.a"
const TOKEN := "test:scene-session"

static func configure() -> Dictionary:
	var parsed := JSON_READER.parse_object(FileAccess.get_file_as_string(REGISTRATION))
	if not parsed.ok: return parsed
	if "--scene-reading-fixture" in OS.get_cmdline_args() or "--scene-reading-fixture" in OS.get_cmdline_user_args() \
			or OS.get_environment("DWM_SCENE_READING_FIXTURE") == "1":
		var selected := MANIFEST.scene_registration()
		if not selected.ok: return selected
		var encoded := JSON_WRITER.stringify(parsed.value)
		if not encoded.ok: return encoded
		if selected.value != parsed.value or MANIFEST.scene_registration_fingerprint() != str(encoded.value).sha256_text():
			return {"ok": false, "code": &"test_scene_registration_mismatch"}
		return {"ok": true}
	return MANIFEST.configure_test_scene_registration(parsed.value)

static func frame(entry_id: String, occurrence_id: String) -> Dictionary:
	return {"expected_stage": "scene", "playback_id": occurrence_id, "role": "scene",
		"transaction_id": "test:operation:" + occurrence_id,
		"presentation": {"schema_id": "context.scene.%s.v1" % entry_id, "schema_version": 1,
			"fields": {"entry_id": entry_id, "entry_role": "scene", "occurrence_id": occurrence_id,
				"admission_receipt_id": "test:receipt:" + occurrence_id}}}

static func create_session() -> Dictionary:
	var session := SESSION.new()
	var configured := session.configure_scene()
	if not configured.ok: return configured
	var begun := session.begin_scene(TOKEN)
	if not begun.ok: return begun
	return {"ok": true, "value": session}

static func enter(session: RefCounted, entry_id: String, occurrence_id: String) -> Dictionary:
	var admitted: Dictionary = session.admit_scene(entry_id, frame(entry_id, occurrence_id))
	if not admitted.ok: return admitted
	var programme: Dictionary = session.entry_program(entry_id, frame(entry_id, occurrence_id))
	if not programme.ok: return programme
	var allocated: Dictionary = session.ledger.allocate_publication(TOKEN, entry_id, occurrence_id)
	if not allocated.ok: return allocated
	return session.ledger.publish_line(TOKEN, allocated.value, entry_id,
		programme.value.lines[0].line_id, occurrence_id)

static func frontier(session: RefCounted) -> Dictionary:
	var saved: Dictionary = session.ledger.snapshot()
	if saved.captions.is_empty(): return {}
	var row: Dictionary = saved.captions.back()
	return {"line_id": row.beat.line_id, "publication_id": row.publication_id}

static func advance_detached(session: RefCounted, witnessed: bool = false) -> Dictionary:
	var plan: Dictionary = session.prepare_next(frontier(session),
		func(_beat: Dictionary) -> bool: return witnessed)
	if not plan.ok: return plan
	var projected := OP.project(plan.value, "destination")
	if not projected.ok: return projected
	var restored: Dictionary = session.restore(projected.value, session.latest_entry)
	return projected if restored.ok else restored

static func checkpoint(session: RefCounted) -> Dictionary:
	var captured: Dictionary = session.capture(frontier(session))
	if not captured.ok: return captured
	return {"ok": true, "value": {"content_version": 1, "entry_id": session.latest_entry,
		"frozen_context": frame(session.latest_entry, session.scene_occurrence),
		"manifest_fingerprint": MANIFEST.scene_registration_fingerprint(), "stage": "scene",
		"transaction_id": "test:operation:" + session.scene_occurrence, "reading_session": captured.value}}
