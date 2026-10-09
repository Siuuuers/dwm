extends RefCounted
## TEST ONLY, dependent on A's successor B2 admission. Run in its own process
## without scene-reading-fixture startup selection. Real identity issuer over fake
## retained root; in-memory semantic owner/checkpoint stub, NOT disk or draw proof.
const STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const COMMAND_PORT := preload("res://scripts/application/contact/ContactCommandPort.gd")
const PRESENTATION := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
var issuer: RefCounted = ISSUER.new()
var contacts := STATE.make_scene_defaults()
var identity := {}
var occurrence := "TEST.occurrence"
var registration := ""
var live_session: RefCounted = RefCounted.new()
var pending := {}
var checkpoint_calls := 0
var refuse_checkpoint := false
var live_validation_hook: Callable = Callable()

static func definitions() -> Dictionary:
	return {"kind": "scene_contact_definitions", "schema_version": 1,
		"messages": [{"definition_id": "TEST.message", "friend_id": "lavinia", "texts": {"en": "TEST incoming."},
			"message_fact_ids": ["TEST.fact.message"], "read_fact_ids": ["TEST.fact.read"]}],
		"replies": [{"reply_id": "TEST.reply", "definition_id": "TEST.message", "line_id": "TEST.reply.line",
			"texts": {"en": "TEST reply."}, "source_fact_ids": ["TEST.fact.reply"]}]}

static func install_registration() -> Dictionary:
	var loaded := PARSER.parse_object(FileAccess.get_file_as_string("res://tests/fixtures/dialogic/scene_reading_registration.json"))
	if not loaded.ok: return loaded
	var bundle: Dictionary = loaded.value
	bundle.schema_version = 2
	bundle["contact_definitions"] = definitions()
	bundle.contacts[0].source_fact_ids = ["TEST.fact.read"]
	return MANIFEST.configure_test_scene_registration(bundle)

func setup() -> Dictionary:
	var configured: Dictionary = issuer.configure(ROOT.new("ce".repeat(32), 1))
	if not configured.ok: return configured
	var causal: Dictionary = issuer.issue(&"causal_day_instance")
	if not causal.ok: return causal
	identity = {"run_id": "TEST.run", "branch_id": "TEST.branch", "desktop_timeline_generation": 0,
		"causal_day_instance": causal.value.token, "causal_day_instance_issuer_receipt": causal.value.issuer_receipt}
	registration = MANIFEST.scene_registration_fingerprint()
	return {"ok": true}

func command() -> Dictionary:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	return {"command_id": issued.value.token, "proof": issued.value.issuer_receipt, "context": capture_scene_contact_context().value}

func emit_message() -> Dictionary:
	var issued := command()
	var prepared := STATE.prepare_scene_message(contacts, "TEST.message", issued.command_id, issued.proof, issued.context, issuer)
	return commit_candidate(prepared)

func configure_identity_issuer(value: Object) -> Dictionary:
	return {"ok": value == issuer, "value": {"issuer_instance_id": issuer.get_instance_id()}}

func capture_scene_contact_context() -> Dictionary:
	return {"ok": true, "value": {"identity": identity.duplicate(true), "scene_occurrence": occurrence,
		"registration_sha256": registration, "contacts_sha256": STATE._s_hash(contacts)}}

func preview_open_contact(friend_id: String, id: String, proof: Dictionary) -> Dictionary:
	return STATE.prepare_scene_read(contacts, friend_id, id, proof, capture_scene_contact_context().value, issuer)

func open_contact(friend_id: String, id: String, proof: Dictionary) -> Dictionary:
	return commit_candidate(preview_open_contact(friend_id, id, proof))

func validate_live_session(session: Variant) -> Dictionary:
	if live_validation_hook.is_valid():
		var callback := live_validation_hook
		live_validation_hook = Callable()
		callback.call()
	return {"ok": session == live_session}

func preview_scene_contact_reply(friend: String, reply_id: String, locale: String, id: String, proof: Dictionary) -> Dictionary:
	var choices := STATE.scene_reply_choices(contacts, friend, locale, registration)
	if not choices.ok: return choices
	for row: Dictionary in choices.value:
		if row.reply_id != reply_id: continue
		var value := {"command_id": id, "command_issuer_receipt": proof.duplicate(true), "friend_id": friend,
			"reply_id": reply_id, "incoming_message_id": row.incoming_message_id, "locale": locale,
			"context": capture_scene_contact_context().value, "rendered_line": {"view_token": id, "line_id": row.line_id, "text": row.text},
			"live_session": live_session}
		pending = value.duplicate(true)
		return {"ok": true, "value": {"command": value}}
	return {"ok": false, "code": &"TEST.reply_unavailable"}

func commit_scene_contact_reply(value: Dictionary, rendered: Dictionary) -> Dictionary:
	if value != pending or not validate_live_session(value.live_session).ok \
			or not STATE._s_equal(value.context, capture_scene_contact_context().value): return {"ok": false, "code": &"TEST.stale"}
	var prepared := STATE.prepare_scene_reply(contacts, value.reply_id, value.incoming_message_id, value.locale,
		value.command_id, value.command_issuer_receipt, value.context, rendered, issuer)
	return commit_candidate(prepared)

func commit_candidate(prepared: Dictionary) -> Dictionary:
	if not prepared.get("ok", false): return prepared
	checkpoint_calls += 1
	if refuse_checkpoint: return {"ok": false, "code": &"TEST.checkpoint_refused"}
	contacts = prepared.value.candidate.duplicate(true)
	return prepared

func make_port() -> RefCounted:
	var port: RefCounted = COMMAND_PORT.new()
	port.configure(self, issuer)
	return port

func make_presentation(port: Object) -> RefCounted:
	var presentation: RefCounted = PRESENTATION.new()
	presentation.configure(self, port)
	return presentation

