extends "res://tests/support/SceneRestartFixture.gd"
## Real same-files owners and native runtime. TEST-selected content/empty host,
## diagnostic ancillary restore participants. Faults below only remove authority
## or refuse an actual filesystem write; no positive receipt/native proof is injected.
const BASE_READING := preload("res://tests/support/SceneDayReadingFixture.gd")
const CHALLENGE_DATA := preload("res://tests/support/SceneChallengeFixture.gd")
const EVENT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const EVENT_PORT := preload("res://scripts/application/narrative/SceneEventCommandPort.gd")
const PLAYABLE_PATH := "res://tests/fixtures/dialogic/scene_playable_native.dtl"

class WriteRefusal extends "res://scripts/infrastructure/storage/FileOps.gd":
	var refuse_on := 0
	var autosave_writes := 0
	var refused := 0
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if path.ends_with("/autosave.json.next") or path.ends_with("\\autosave.json.next"):
			autosave_writes += 1
			if refuse_on == autosave_writes:
				refuse_on = 0
				refused += 1
				return {"ok": false, "code": &"TEST.filesystem_write_refused", "message": path}
		return super.write_bytes(path, bytes)

# Observe the real lower port's attempted phase; never manufacture a successful prepare.
class ObservedCheckpoint extends "res://scripts/application/run/SaveManagerCheckpointPort.gd":
	var last_prepare_phase := ""
	func _init(owner: Object) -> void:
		super(owner)
	func prepare(inputs: Dictionary, kind: StringName, disk_write: Dictionary) -> Dictionary:
		var operation: Variant = inputs.get("dialogic_checkpoint", {}).get("reading_session", {}).get("next_operation")
		last_prepare_phase = str(operation.get("phase", "")) if operation is Dictionary else ""
		return super.prepare(inputs, kind, disk_write)

class AckFault extends "res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd":
	var drop_ack := false
	var after_ack: Callable
	var consumed := 0
	func consume_scene_control_ack(token: RefCounted) -> Dictionary:
		var result: Dictionary = super.consume_scene_control_ack(token)
		if result.get("ok", false):
			consumed += 1
			if after_ack.is_valid(): after_ack.call()
			if drop_ack: return {"ok": false, "code": &"TEST.ack_dropped", "committed": true}
		return result

var files: WriteRefusal
var lower: RefCounted
var checkpoint_port: AckFault
var command_port: RefCounted
var issued_event: Dictionary = {}
var before_profile: Dictionary = {}
var before_input: Dictionary = {}
var before_reading: Dictionary = {}
var before_publications := 0

func _install_registration() -> Dictionary:
	var built: Dictionary = _registration_bundle()
	if not built.ok: return built
	return BASE_READING.MANIFEST.configure_test_scene_registration(built.value)

func _registration_bundle() -> Dictionary:
	var parsed: Dictionary = BASE_READING.JSON_READER.parse_object(FileAccess.get_file_as_string(BASE_READING.REGISTRATION))
	if not parsed.ok: return parsed
	var bundle: Dictionary = parsed.value
	bundle.schema_version = 2
	bundle["contact_definitions"] = REGISTRATION.definitions()
	bundle.contacts[0].source_fact_ids = ["TEST.fact.read"]
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		entry.locators.en.path = PLAYABLE_PATH
		if entry.entry_id == BASE_READING.B:
			entry.allowed_signals = ["challenge.end", "challenge.playable", "history.line.witness"]
	bundle.ids_registry.signals.append({"signal_id": "challenge.end", "payload_fields": ["challenge_id"]})
	bundle.ids_registry.signals.append({"signal_id": "challenge.playable", "payload_fields": ["challenge_id"]})
	bundle.ids_registry.signals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.signal_id < b.signal_id)
	var hashes := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == BASE_READING.B:
			programme.markers = [
				{"marker_id": "scene.test.b.playable", "label": "scene.test.b.playable", "after_line_id": "line.scene.test.b.one",
					"kind": "challenge.playable", "payload": {"challenge_id": "TEST.challenge"}},
				{"marker_id": "scene.test.b.end", "label": "scene.test.b.end", "after_line_id": "line.scene.test.b.two",
					"kind": "challenge.end", "payload": {"challenge_id": "TEST.challenge"}}]
		var compiled: Dictionary = RUNTIME_ADAPTER.compile_scene_programme(PLAYABLE_PATH, programme.entry_id, labels, programme.markers)
		if not compiled.ok: return compiled
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
		hashes[programme.entry_id] = programme.program_sha256
	for row: Dictionary in bundle.targets: row.target.program_sha256 = hashes[row.target.entry_id]
	bundle.board_profiles = CHALLENGE_DATA.bundle().board_profiles
	bundle.challenges = [{"challenge_id": "TEST.challenge", "entry_id": BASE_READING.B,
		"playable_marker_id": "scene.test.b.playable", "end_marker_id": "scene.test.b.end", "board_profile_id": "TEST.profile",
		"targets": {"never_started": "target_a", "unfinished": "target_a", "lost": "target_a", "won": "target_a"}}]
	return {"ok": true, "value": bundle}

func setup_playable(scene_tree: SceneTree) -> Dictionary:
	var checked: Dictionary = await setup_restart(scene_tree)
	if not checked.ok: return checked
	files = WriteRefusal.new()
	storage._file_ops = files
	lower = ObservedCheckpoint.new(manager)
	checked = lower.configure_fatal_latch(gate)
	if not checked.ok: return checked
	checkpoint_port = AckFault.new()
	checked = checkpoint_port.configure(lower, {"snapshot_input": snapshot_input, "route_id": route_id,
		"active_app_id": active_app_id, "audio_context": audio_context, "content_version": content_version,
		"narrative_checkpoint": narrative_checkpoint})
	if checked.ok: checked = game.configure_narrative_checkpoint_port(checkpoint_port)
	if checked.ok: checked = game.configure_scene_checkpoint_source(manager)
	if checked.ok: checked = bridge.configure_narrative_checkpoint_port(checkpoint_port)
	if checked.ok: checked = bridge.configure_mutation_gate(gate)
	if checked.ok: checked = bridge.configure_scene_staging(checkpoint_port,
		Callable(game, "validate_scene_entry_staging_source"), Callable(game, "scene_entry_staging_context"))
	if not checked.ok: return checked
	command_port = EVENT_PORT.new()
	checked = command_port.configure(game, gate, issuer)
	if checked.ok: checked = bridge.configure_scene_event_port(command_port,
		Callable(game, "validate_live_session"), Callable(game, "scene_event_context"))
	return checked

func snapshot_input() -> Dictionary: return game.capture_run_snapshot_input()
func route_id() -> String: return "scene"
func active_app_id() -> Variant: return null
func audio_context() -> Dictionary: return {}
func content_version() -> int: return 1
func narrative_checkpoint(_transaction: String, _source: String, _kind: StringName) -> Dictionary:
	return bridge.capture_reading_checkpoint(false)

func begin_playable_source() -> Dictionary:
	var started: Dictionary = start()
	if started.get("code") != &"scene_activation_pending": return started
	var activated: Dictionary = await await_activation()
	if not activated.ok: return activated
	var completed: Dictionary = adapter.reveal_current_line(true)
	if not completed.ok: return completed
	for frame: int in 4: await tree.process_frame
	var context: Dictionary = game.scene_event_context()
	if not context.ok: return context
	var issued: Dictionary = issuer.issue(&"transaction_id")
	if not issued.ok: return issued
	issued_event = {"schema_version": 2, "source": context.value.source.duplicate(true),
		"event_id": "scene.test.b.playable", "kind": "challenge.playable", "payload": {"challenge_id": "TEST.challenge"},
		"ordinal": context.value.next_ordinal, "predecessor": context.value.predecessor,
		"command_id": issued.value.token, "issuer_receipt": issued.value.issuer_receipt.duplicate(true),
		"playback_token": context.value.playback_token}
	before_profile = profile.get_profile_snapshot().duplicate(true)
	before_input = game.capture_run_snapshot_input().duplicate(true)
	before_reading = context.value.checkpoint.duplicate(true)
	before_publications = native_publications.size()
	files.autosave_writes = 0
	return {"ok": true}

func dispatch(value: Dictionary = {}) -> Dictionary:
	var live: Dictionary = game.capture_live_session()
	if not live.ok: return live
	return bridge.dispatch_scene_event(live.value, issued_event if value.is_empty() else value)

func profile_bytes() -> Dictionary:
	var result := {}
	for name: String in ["profile.json", "profile.json.bak"]:
		if storage.exists(name):
			var read: Dictionary = storage.read_text(name)
			if read.ok: result[name] = str(read.value).sha256_text()
	return result

func close_restart() -> void:
	await super.close_restart()
	# Release fixture-bound provider/fault Callables after the real owners retire.
	checkpoint_port = null
	command_port = null
	lower = null
