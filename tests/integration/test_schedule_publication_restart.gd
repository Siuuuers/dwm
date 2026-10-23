extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
# Committed-Schedule persistence across restart (Plan 01 Task 5, dwm-p2r.13, Steps 5.1/5.6).
#
# SUBSTRATE. Every dependency is the production object: the real ScheduleActionRegistry from the
# shipped v1 manifest, the real DesktopIdentityNonceIssuer over the real DesktopIssuerRootStore over
# the real JsonFileStorage on a GUID-isolated root, the real GameState autoload script, the real
# GameStateScheduleCommitPort, and one real ScheduleFoundationPublicationLedger over the SAME
# root-scoped storage that owns the issuer root. No aggregate, receipt, fingerprint or digest in this
# suite is handwritten: nonempty committed schedules are built through the Task-4 substrate.
#
# THE CENTRAL CLAIM. `schedule-foundation-publications.json` is an EXTERNAL durable record. It is not
# a RunSnapshot member, not a SaveDocument member, not a recovery-journal member, not a profile
# member, and never a selectable restore participant. Selected Load, New Run and rollback must leave
# its bytes identical, while the committed Schedule itself travels inside the current snapshot.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PORT_PATH := "res://scripts/application/schedule/GameStateScheduleCommitPort.gd"
const LEDGER_PATH := "res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd"
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const RUN_SNAPSHOT_SCHEMA_PATH := "res://scripts/domain/run/RunSnapshotSchema.gd"
const SAVE_DOCUMENT_SCHEMA_PATH := "res://scripts/infrastructure/save/SaveDocumentSchema.gd"
const RUN_RESTORE_PARTICIPANT_PATH := "res://scripts/application/restore/RunRestoreParticipant.gd"

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const SCHEDULE_RESTORE_FIXTURE := preload("res://tests/support/ScheduleRestoreFixture.gd")

const LEDGER_FIXED_PATH := "schedule-foundation-publications.json"
const CAUSAL_DAY := "causal_day_instance.1111111111111111111111111111111111111111111111111111111111111111"
const VIEW_FINGERPRINT := "schedule_view.22222222222222222222222222222222"

var _port_script: Script = null
var _ledger_script: Script = null
var _root := ""
var _storage: RefCounted = null
var _root_store: RefCounted = null
var _issuer: RefCounted = null
var _registry: RefCounted = null
var _fingerprint := ""
var _game_state: Node = null
var _schedule_view: RefCounted = null
var _ledger: Object = null
var _port: Object = null
var _commands: Dictionary = {}
var _root_counter := 0


func before_each() -> void:
	_commands = {}
	_root = ""
	_storage = null
	_schedule_view = null
	var port_loaded: Dictionary = PROBE.load_script(PORT_PATH)
	_port_script = port_loaded["value"] if port_loaded.get("ok", false) else null
	var ledger_loaded: Dictionary = PROBE.load_script(LEDGER_PATH)
	_ledger_script = ledger_loaded["value"] if ledger_loaded.get("ok", false) else null

	_root = _isolated_root()
	if _root.is_empty():
		return
	_storage = JsonFileStorage.new(_root)

	_root_store = ROOT_STORE.new()
	assert_true(_root_store.configure(_storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(_root_store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(_root_store).get("ok", false))

	var loaded_registry: Dictionary = REGISTRY.load_current()
	assert_true(loaded_registry.get("ok", false), str(loaded_registry))
	_registry = (loaded_registry.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded_registry.get("value", {}) as Dictionary).get("registry_fingerprint", ""))

	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()
	var schedule_restore: Dictionary = SCHEDULE_RESTORE_FIXTURE.create(_issuer)
	assert_true(schedule_restore.get("ok", false), str(schedule_restore))
	if not schedule_restore.get("ok", false):
		return
	_schedule_view = schedule_restore["value"]["view"]
	var lifecycle: Dictionary = _game_state.capture_run_snapshot_input()["lifecycle"]
	var opened: Dictionary = _schedule_view.open_day(
		int(lifecycle["day"]), str(lifecycle["causal_day_instance"]))
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		_schedule_view = null
		return

	if _ledger_script != null:
		_ledger = _ledger_script.new()
		assert_true(_ledger.configure(_storage).get("ok", false))
		assert_true(_ledger.load().get("ok", false))
	if _port_script != null and _ledger != null:
		_port = _port_script.new(_game_state, _registry, _issuer, _ledger)


func _isolated_root() -> String:
	_root_counter += 1
	var created: Dictionary = TEMPORARY_STORAGE.create(
		"schedule-publication-restart-%d" % _root_counter)
	assert_true(created.get("ok", false), created.get("message", ""))
	return str(created.get("value", "")) if created.get("ok", false) else ""


func _require_substrate() -> bool:
	if _root.is_empty():
		return false
	var absent: Array[String] = []
	if _ledger_script == null:
		absent.append(LEDGER_PATH)
	if _port_script == null:
		absent.append(PORT_PATH)
	if not absent.is_empty():
		assert_true(false, "the committed-Schedule modules are absent: " + str(absent))
		return false
	if _port == null:
		assert_true(false, "the four-dependency port constructor did not produce an instance")
		return false
	if _schedule_view == null:
		assert_true(false, "the retained Schedule view did not open on the live lifecycle day")
		return false
	return true


# ---- production fixtures (identical construction law to the Task-4 port suite) ----

func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


func _record(action_id: String) -> Dictionary:
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	return ((found.get("value", {}) as Dictionary).get("record", {}) as Dictionary)


func _ordinary(draft_entry_id: String, slot_index: int, action_id: String, day := 1) -> Dictionary:
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": "ordinary",
		"participants": [],
		"source_receipt_id": null,
	}


func _request(label: String, day: int, drafts: Array) -> Dictionary:
	var command := _command(label)
	return {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": _fingerprint,
	}


## Commits one real ordinary entry through the production port and returns the canonical aggregate.
func _commit_one_real_entry() -> Dictionary:
	var drafts: Array = [_ordinary("draft-a", 0, "working", 1)]
	var prepared: Dictionary = _port.prepare_commit(_request("restart", 1, drafts))
	assert_true(prepared.get("ok", false), str(prepared))
	var committed: Dictionary = _port.commit(prepared["value"]["game_state_candidate"])
	assert_true(committed.get("ok", false), str(committed))
	return (committed["value"] as Dictionary)["committed_schedule"]


func _ledger_bytes() -> String:
	return FileAccess.get_file_as_string(_root.path_join(LEDGER_FIXED_PATH))


func _run_snapshot() -> Dictionary:
	var schema: Script = load(RUN_SNAPSHOT_SCHEMA_PATH)
	# GameState owns the run aggregate; the retained ScheduleViewController contributes its
	# separate restore participant exactly as ApplicationBootstrap does during capture.
	var inputs: Dictionary = _game_state.capture_run_snapshot_input()
	var view_snapshot: Dictionary = _schedule_view.snapshot()
	assert_true(view_snapshot.get("ok", false), str(view_snapshot))
	if not view_snapshot.get("ok", false):
		return {}
	inputs["schedule_view"] = view_snapshot["value"]["view"]
	var built: Dictionary = schema.build(
		inputs, {}, "main", null, {}, 1, 7)
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false):
		return {}
	return built["value"]["snapshot"]


# ---- the committed aggregate travels inside the current snapshot ----

func test_committed_schedule_is_captured_into_the_current_snapshot() -> void:
	if not _require_substrate():
		return
	var aggregate := _commit_one_real_entry()
	assert_false((aggregate["entries"] as Array).is_empty(), "a real entry was committed")
	var snapshot := _run_snapshot()
	if snapshot.is_empty():
		return
	var schema: Script = load(RUN_SNAPSHOT_SCHEMA_PATH)
	assert_eq(int(snapshot["schema_version"]), schema.SCHEMA_VERSION,
		"capture produces the current snapshot version")
	assert_eq(snapshot["committed_schedule"], aggregate,
		"the canonical aggregate is captured byte-for-byte, receipt included")
	assert_false(snapshot.has("schedule"), "no legacy top-level Schedule survives capture")
	assert_false((snapshot["gameplay"] as Dictionary).has("schedule_entries"),
		"no legacy gameplay Schedule survives capture")


func test_committed_schedule_survives_a_whole_document_round_trip() -> void:
	if not _require_substrate():
		return
	var aggregate := _commit_one_real_entry()
	var snapshot := _run_snapshot()
	if snapshot.is_empty():
		return
	var document_schema: Script = load(SAVE_DOCUMENT_SCHEMA_PATH)
	var built: Dictionary = document_schema.build(
		&"slot", 1, &"manual", {"checkpoint_kind": "day_start", "snapshot": snapshot}, [])
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false):
		return
	assert_eq(int(built["value"]["schema_version"]), document_schema.DOCUMENT_VERSION,
		"the document uses the current version")

	# A complete JSON round trip: the aggregate must survive serialization unchanged.
	var text := JSON.stringify(built["value"])
	var reparsed: Variant = JSON.parse_string(text)
	assert_eq(typeof(reparsed), TYPE_DICTIONARY, "the document reparses")
	if not reparsed is Dictionary:
		return
	var revalidated: Dictionary = document_schema.validate(reparsed as Dictionary)
	assert_true(revalidated.get("ok", false), str(revalidated))
	if not revalidated.get("ok", false):
		return
	assert_eq(revalidated["value"]["candidate"]["current_snapshot"]["snapshot"]["committed_schedule"],
		aggregate, "the committed aggregate is byte-equal after a full document round trip")


func test_restore_reinstalls_the_committed_schedule_without_signals_until_finalize() -> void:
	if not _require_substrate():
		return
	var aggregate := _commit_one_real_entry()
	var snapshot := _run_snapshot()
	if snapshot.is_empty():
		return

	# A cold owner that has never committed exposes the canonical empty aggregate.
	var fresh: Node = load(GAME_STATE_PATH).new()
	autofree(fresh)
	fresh.reset_game()
	var emissions: Array[String] = []
	fresh.save_relevant_state_changed.connect(func() -> void: emissions.append("save_relevant_state_changed"))
	fresh.committed_schedule_published.connect(func(_p: Dictionary) -> void: emissions.append("committed_schedule_published"))

	var participant: RefCounted = load(RUN_RESTORE_PARTICIPANT_PATH).new(fresh)
	var prepared: Dictionary = participant.prepare({"snapshot": snapshot})
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return
	var applied: Dictionary = participant.apply_silent(prepared["value"]["run_plan"])
	assert_true(applied.get("ok", false), str(applied))
	assert_eq(emissions, [] as Array[String], "apply_silent emits nothing")

	assert_eq(fresh.capture_schedule_commit_state()["value"]["committed_schedule"], aggregate,
		"the restored owner holds the exact committed aggregate")
	assert_true(participant.finalize().get("ok", false))
	assert_eq(emissions, ["save_relevant_state_changed"] as Array[String],
		"exactly one state-changed signal, and only at finalize")


# ---- the external ledger is not a document member ----

func test_publication_ledger_is_not_a_snapshot_or_document_member() -> void:
	if not _require_substrate():
		return
	var _aggregate := _commit_one_real_entry()
	var snapshot := _run_snapshot()
	if snapshot.is_empty():
		return
	var run_schema: Script = load(RUN_SNAPSHOT_SCHEMA_PATH)
	var document_schema: Script = load(SAVE_DOCUMENT_SCHEMA_PATH)

	for forbidden: String in ["schedule_foundation_publications", "publication_ledger", "publications"]:
		assert_false((run_schema.TOP_KEYS as Array).has(forbidden),
			"the ledger is not a RunSnapshot member: " + forbidden)
		assert_false((document_schema.DOCUMENT_KEYS as Array).has(forbidden),
			"the ledger is not a SaveDocument member: " + forbidden)
		assert_false((run_schema.GAMEPLAY_FIELDS as Array).has(forbidden),
			"the ledger is not a gameplay member: " + forbidden)
	assert_false(JSON.stringify(snapshot).contains(LEDGER_FIXED_PATH),
		"the ledger path never appears inside a snapshot")

	var built: Dictionary = document_schema.build(
		&"slot", 1, &"manual", {"checkpoint_kind": "day_start", "snapshot": snapshot}, [])
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false):
		return
	assert_false(JSON.stringify(built["value"]).contains(LEDGER_FIXED_PATH),
		"the ledger path never appears inside a whole document, journal included")


func test_selectable_operations_leave_the_ledger_bytes_identical() -> void:
	if not _require_substrate():
		return
	var aggregate := _commit_one_real_entry()
	var publication := {
		"committed_schedule": aggregate.duplicate(true),
		"schedule_commit_receipt": (aggregate["commit_receipt"] as Dictionary).duplicate(true),
	}
	var published: Dictionary = _port.publish(publication)
	assert_true(published.get("ok", false), str(published))
	var after_publish := _ledger_bytes()
	assert_false(after_publish.strip_edges().is_empty(), "a real durable record was written")

	var snapshot := _run_snapshot()
	if snapshot.is_empty():
		return

	# Selected Load onto a different owner.
	var loaded_owner: Node = load(GAME_STATE_PATH).new()
	autofree(loaded_owner)
	loaded_owner.reset_game()
	var participant: RefCounted = load(RUN_RESTORE_PARTICIPANT_PATH).new(loaded_owner)
	var prepared: Dictionary = participant.prepare({"snapshot": snapshot})
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return
	assert_true(participant.apply_silent(prepared["value"]["run_plan"]).get("ok", false))
	assert_true(participant.finalize().get("ok", false))
	assert_eq(_ledger_bytes(), after_publish, "selected Load never rewrites the ledger")

	# New Run on the original owner.
	_game_state.reset_game()
	assert_eq(_ledger_bytes(), after_publish, "New Run never clears or version-tags the ledger")

	# Rollback of the committed-Schedule transaction.
	var backup := {
		"committed_schedule": {
			"schema_version": 1, "day": 1, "registry_fingerprint": null,
			"entries": [], "commit_receipt": null,
		},
		"motivation": int(_game_state.get_stat(_game_state.STAT_MOTIVATION)),
	}
	assert_true(_game_state.rollback_schedule_commit_state(backup).get("ok", false))
	assert_eq(_ledger_bytes(), after_publish, "rollback never rewrites the ledger")


func test_a_cold_ledger_rereads_the_durable_record_and_corruption_fails_closed() -> void:
	if not _require_substrate():
		return
	var aggregate := _commit_one_real_entry()
	var receipt: Dictionary = aggregate["commit_receipt"]
	var published: Dictionary = _port.publish({
		"committed_schedule": aggregate.duplicate(true),
		"schedule_commit_receipt": receipt.duplicate(true),
	})
	assert_true(published.get("ok", false), str(published))
	var durable := _ledger_bytes()

	# A restart is a whole cold stack over the same bytes, never an in-memory flag flip.
	var cold: Object = _ledger_script.new()
	assert_true(cold.configure(JsonFileStorage.new(_root)).get("ok", false))
	var reloaded: Dictionary = cold.load()
	assert_true(reloaded.get("ok", false), str(reloaded))
	assert_eq(_ledger_bytes(), durable, "a cold load does not rewrite the durable bytes")
	assert_false((reloaded["value"]["document"]["records"] as Dictionary).is_empty(),
		"the cold instance re-reads the real record")

	# Corruption must fail that load rather than silently reinitializing.
	var handle := FileAccess.open(_root.path_join(LEDGER_FIXED_PATH), FileAccess.WRITE)
	assert_true(handle != null, "the ledger file is writable in the isolated root")
	handle.store_string("{ this is not valid json")
	handle.close()
	var corrupted: Object = _ledger_script.new()
	assert_true(corrupted.configure(JsonFileStorage.new(_root)).get("ok", false))
	assert_false(corrupted.load().get("ok", true),
		"a corrupted publication ledger fails closed and is never silently replaced")
