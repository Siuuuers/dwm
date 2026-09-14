extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")

# dwm-7e6 acceptance: the REAL coordinator + REAL SaveManagerCheckpointPort + REAL SaveManager
# write a genuine disk autosave whose snapshot round-trips. Before real snapshot production this
# path was impossible: the port emitted a {run_id, day} stub and the real checkpoint port rejected
# it with invalid_checkpoint_inputs (coordinator tests only passed via FakeCheckpointPort).

const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const DAY_ADVANCE_IDENTITY_PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const IDENTITY_ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ISSUER_ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const CRYPTO_NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const SAVE_MANAGER := preload("res://autoload/SaveManager.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const DAY7_PROVENANCE := preload("res://scripts/domain/schedule/Day7ScheduleProvenance.gd")
const SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const SCHEDULE_COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const SCHEDULE_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const SCHEDULE_RESTORE_FIXTURE := preload("res://tests/support/ScheduleRestoreFixture.gd")

var _root := ""
var _manager: Node
var _gate: Object
var _schedule_view: Object
var _board: Object
var _consequence: Object


func before_each() -> void:
	_issuer = null
	_commit_port = null
	_schedule_ledger = null
	GameState.reset_game()
	_root = ""
	var result: Dictionary = TEMPORARY_STORAGE.create("dwm7e6-disk")
	assert_true(result.get("ok", false), result.get("message", ""))
	if not result.get("ok", false):
		return
	_root = str(result["value"])
	_initialize_run_identity()
	_manager = SAVE_MANAGER.new()
	add_child_autofree(_manager)
	_manager.initialize(STORAGE.new(_root))
	# Real nine-participant wiring so a restore genuinely prepares plans rather than failing with
	# TRANSACTION_PARTICIPANTS_NOT_CONFIGURED (dwm-7e6 repair).
	_gate = GATE.new()
	assert_true(_manager.configure_mutation_gate(_gate).get("ok", false))
	# The real participants delegate to live autoloads, so those must be initialized too -- in
	# ApplicationBootstrap's dependency order (profile -> localization -> input -> accessibility ->
	# audio -> dialogic), because each later manager reads the profile the earlier ones established.
	_initialize_live_autoloads()
	var schedule_restore: Dictionary = SCHEDULE_RESTORE_FIXTURE.create(_identity_issuer())
	assert_true(schedule_restore.get("ok", false), "schedule-view restore fixture configured")
	_schedule_view = schedule_restore["value"]["view"]
	_board = preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
	_consequence = preload("res://scripts/domain/desktop/DesktopConsequenceState.gd").new()
	var lifecycle: Dictionary = GameState._run_lifecycle.to_dict()
	assert_true(schedule_restore["value"]["view"].open_day(
		int(lifecycle["day"]), str(lifecycle["causal_day_instance"])).get("ok", false),
		"schedule-view fixture opened on the live lifecycle day")
	var restore_configured: Dictionary = _manager.configure_restore_participants({
		"run": preload("res://scripts/application/restore/RunRestoreParticipant.gd").new(GameState),
		# Plan 02 Task 6 (dwm-p2r.32), Phase C2: forced ripple -- SaveManager.configure_restore_
		# participants() requires all 9 of DesktopContinuationOperationJournal.PARTICIPANT_ORDER.
		# Day advancement and restore must share the same live owners.
		"desktop_consequence": preload("res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd")
			.new(_consequence),
		"desktop_board": preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd")
			.new(_board),
		"schedule_view": schedule_restore["value"]["participant"],
		"profile": preload("res://scripts/application/restore/ProfileRestoreParticipant.gd").new(ProfileManager),
		"localization": preload("res://scripts/application/restore/LocalizationRestoreParticipant.gd").new(LocalizationManager),
		"audio": preload("res://scripts/application/restore/AudioRestoreParticipant.gd").new(AudioManager),
		"route": preload("res://scripts/application/restore/RouteRestoreParticipant.gd").new(SceneRouter),
		"narrative": preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd").new(DialogicBridge),
	})
	assert_true(restore_configured.get("ok", false),
		"all nine restore participants configured: " + str(restore_configured))


func _initialize_run_identity() -> void:
	var issuer: Object = _identity_issuer()
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	if not issued.get("ok", false): return
	var allocation: Dictionary = issuer.prepare_continuation_allocation({
		"existing_run_id": null, "kind": "new_run", "remap_source_transaction_ids": [],
		"source_desktop_timeline_generation": null, "transaction_id": issued.value.token,
		"transaction_issuer_receipt": issued.value.issuer_receipt,
	})
	assert_true(allocation.get("ok", false), str(allocation))
	if not allocation.get("ok", false): return
	var committed: Dictionary = issuer.commit_continuation_allocation(allocation.value)
	assert_true(committed.get("ok", false), str(committed))
	if not committed.get("ok", false): return
	var identity: Dictionary = committed.value
	var prepared: Dictionary = GameState.prepare_new_run_snapshot_input(
		identity.run_id, identity.branch_id, identity.desktop_timeline_generation,
		identity.causal_day_instance, identity.causal_day_instance_issuer_receipt, false)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_true(GameState._run_lifecycle.commit_restore(prepared.value.snapshot_input.lifecycle)
		.get("ok", false), "initial run and causal day use a durable real allocation")


## Brings the live autoloads the restore participants delegate to into a genuinely initialized
## state, following ApplicationBootstrap's STAGE_ORDER. Each initializer is reported so a harness
## failure surfaces as a named stage rather than an opaque downstream `*_not_ready`.
func _initialize_live_autoloads() -> void:
	var stages: Array = [
		["profile", ProfileManager.initialize(STORAGE.new(_root.path_join("profile")))],
		["localization", LocalizationManager.initialize(ProfileManager)],
		["input", InputManager.initialize(ProfileManager)],
		["accessibility", AccessibilityManager.initialize(ProfileManager)],
		["audio", AudioManager.initialize(ProfileManager)],
		["dialogic", DialogicBridge.initialize()],
	]
	for stage: Array in stages:
		var result: Dictionary = stage[1]
		# Autoloads are process-wide and initialize exactly once, so every before_each after the
		# first legitimately reports already_initialized.
		if str(result.get("code", "")) == "already_initialized":
			continue
		assert_true(result.get("ok", false),
			"autoload stage %s must initialize: %s" % [str(stage[0]), str(result)])


## The participant plans inside a successful prepare_restore_autosave result.
func _participant_plans(prepared: Dictionary) -> Dictionary:
	return ((prepared["value"] as Dictionary)["prepared"] as Dictionary)["participant_plans"]


## The run snapshot the restore would install.
func _restored_snapshot(prepared: Dictionary) -> Dictionary:
	return (_participant_plans(prepared)["run"] as Dictionary)["snapshot"]


func _active_app_id() -> Variant:
	return null


func _content_version() -> int:
	return 1


func _wired() -> Dictionary:
	var run_id := str(GameState._run_lifecycle.to_dict()["run_id"])
	var state_port: Object = STATE_PORT.new(GameState)
	assert_true(state_port.configure_day_advance_owners(_schedule_view, _board, _consequence)
		.get("ok", false), "day advancement shares the restore owners")
	# The same five providers ApplicationBootstrap._configure_day_resolution_providers installs.
	# Without them the port falls back to safe defaults whose empty audio context writes an autosave
	# that cannot be restored -- which is precisely what this suite exists to catch.
	assert_true(state_port.configure_checkpoint_providers({
		"dialogic_checkpoint": Callable(DialogicBridge, "get_current_narrative_checkpoint"),
		"route_id": Callable(SceneRouter, "get_current_route_id"),
		"active_app_id": Callable(self, "_active_app_id"),
		"audio_context": Callable(AudioManager, "get_semantic_audio_context"),
		"content_version": Callable(self, "_content_version"),
	}).get("ok", false), "day-resolution checkpoint providers configured")
	# The one configured Day-7 handoff service (Task 8 Step 8.7, dwm-p2r.14), injected INTO the
	# retained state port exactly as ApplicationBootstrap._construct_schedule_foundation does.
	# Without it a Day-7 stage now fails closed with day7_provenance_unconfigured, which is the
	# point: no Day-7 cause may be reported that no issuer ever anchored.
	var provenance: Object = DAY7_PROVENANCE.new()
	assert_true(provenance.configure(_schedule_registry(), _identity_issuer()).get("ok", false),
		"Day-7 provenance bound to the retained registry/issuer pair")
	assert_true(state_port.configure_day7_provenance(provenance).get("ok", false),
		"Day-7 provenance injected into the state port")
	assert_true(state_port.configure_resolution_identity(_identity_issuer(),
		START_PORT.new(state_port, _schedule_registry(), _identity_issuer(),
			_schedule_publication_ledger())).get("ok", false),
		"resolution starts use the same issuer and ledger as Schedule Done")
	_configure_desktop_source(state_port)
	var checkpoint_port: Object = CHECKPOINT_PORT.new(_manager)
	var gate: Object = _gate
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false), "checkpoint port latched")
	var pair_deck: Object = preload("res://scripts/application/run/PairDeckDrawPort.gd").new()
	assert_true(pair_deck.configure(GameState, ProfileManager, gate,
		preload("res://scripts/application/run/ConditionHospitalCoordinator.gd").new())
		.get("ok", false), "Schedule uses the real Profile-backed pair draw")
	assert_true(state_port.configure_pair_deck(pair_deck).get("ok", false))
	_manager._journal.reset(run_id)
	var coordinator: Object = COORDINATOR.new()
	# One three-owner seam (Plan 01 Task 6 Step 6.5, dwm-p2r.13): the gate arrives with the ports.
	assert_true(coordinator.configure(state_port, checkpoint_port, gate).get("ok", false),
		"coordinator configured")
	# The separate Task-7 seam (dwm-p2r.14): a logical-day change may only happen through the one
	# shared root-atomic identity owner, so a real Days 1-6 walk cannot reach increment_day without
	# it. Mirrors ApplicationBootstrap._configure_causal_day_advance_identity.
	var day_advance_port: Object = DAY_ADVANCE_IDENTITY_PORT.new()
	assert_true(day_advance_port.configure(_identity_issuer()).get("ok", false),
		"advance identity port bound to the production issuer")
	assert_true(coordinator.configure_day_advance_identity_port(day_advance_port).get("ok", false),
		"advance identity port injected")
	return {"coordinator": coordinator, "run_id": run_id, "checkpoint_port": checkpoint_port,
		"day_advance_port": day_advance_port}


func _configure_desktop_source(state_port: Object) -> void:
	var ledger: Object = preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd").new()
	assert_true(ledger.configure(STORAGE.new(_root.path_join("desktop"))).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	var fate: Object = preload("res://scripts/application/minesweeper/DesktopBoardFatePort.gd").new()
	assert_true(fate.configure_publication_ledger(ledger).get("ok", false))
	assert_true(fate.configure(_board, _identity_issuer()).get("ok", false))
	var source: Object = preload("res://scripts/application/desktop/DesktopConsequenceSourcePort.gd").new()
	assert_true(source.configure(
		preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd").new(),
		fate, _identity_issuer(), Callable(self, "_identity_context")).get("ok", false))
	assert_true(source.configure_current_condition_owner(GameState).get("ok", false))
	assert_true(state_port.configure_desktop_consequence_source(source).get("ok", false))


func _identity_context() -> Dictionary:
	var lifecycle: Dictionary = GameState._run_lifecycle.to_dict()
	return {"ok": true, "value": {
		"run_id": lifecycle["run_id"], "branch_id": lifecycle["branch_id"],
		"desktop_timeline_generation": lifecycle["desktop_timeline_generation"],
		"causal_day_instance": lifecycle["causal_day_instance"],
	}}


## One real issuer over this suite's sandbox root, built exactly the way
## ApplicationBootstrap._configure_identity_issuer builds the production one. This suite drives the
## coordinator directly rather than through Bootstrap, so it owns the issuer its walk allocates
## from; the sandbox root keeps the counter isolated per test.
var _issuer: Object = null

func _identity_issuer() -> Object:
	if _issuer != null:
		return _issuer
	var root_store: Object = ISSUER_ROOT_STORE.new()
	var configured: Dictionary = root_store.configure(
		STORAGE.new(_root.path_join("identity")), CRYPTO_NAMESPACE_SOURCE.new())
	assert_true(configured.get("ok", false), "issuer root store configured: " + str(configured))
	var loaded: Dictionary = root_store.load_or_create()
	assert_true(loaded.get("ok", false), "issuer root created: " + str(loaded))
	_issuer = IDENTITY_ISSUER.new()
	assert_true(_issuer.configure(root_store).get("ok", false), "issuer configured")
	return _issuer


## One production commit port over this suite's sandbox, built the way
## ApplicationBootstrap._construct_schedule_foundation builds the retained one.
var _commit_port: Object = null
var _schedule_ledger: Object = null

func _schedule_publication_ledger() -> Object:
	if _schedule_ledger == null:
		_schedule_ledger = SCHEDULE_PUBLICATION_LEDGER.new()
		assert_true(_schedule_ledger.configure(STORAGE.new(_root.path_join("schedule"))).get("ok", false))
		assert_true(_schedule_ledger.load().get("ok", false))
	return _schedule_ledger

func _schedule_commit_port() -> Object:
	if _commit_port == null:
		_commit_port = SCHEDULE_COMMIT_PORT.new(GameState, _schedule_registry(),
			_identity_issuer(), _schedule_publication_ledger())
	return _commit_port


## Commits empty Done against the live view and causally advanced day.
func _commit_empty_done(day: int) -> bool:
	var fingerprint: Dictionary = _schedule_view.fingerprint()
	assert_true(fingerprint.get("ok", false), str(fingerprint))
	if not fingerprint.get("ok", false): return false
	var issued: Dictionary = _identity_issuer().call(&"issue", &"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	if not issued.get("ok", false):
		return false
	var value: Dictionary = issued["value"]
	var prepared: Dictionary = _schedule_commit_port().call(&"prepare_commit", {
		"transaction_id": str(value["token"]),
		"transaction_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true),
		"expected_view_fingerprint": fingerprint.value.fingerprint,
		"day": day,
		"causal_day_instance": str(GameState._run_lifecycle.to_dict()["causal_day_instance"]),
		"draft_entries": [],
		"registry_fingerprint": str(_schedule_registry().call(&"fingerprint")),
	})
	assert_true(prepared.get("ok", false), "empty Done commits for day %d: %s" % [day, str(prepared)])
	if not prepared.get("ok", false):
		return false
	var committed: Dictionary = _schedule_commit_port().call(&"commit",
		(prepared["value"] as Dictionary)["game_state_candidate"])
	assert_true(committed.get("ok", false), str(committed))
	return committed.get("ok", false)


func _resolve_day(coordinator: Object, run_id: String, day: int) -> Dictionary:
	if not _commit_empty_done(day):
		return {}
	var result: Dictionary = coordinator.request_schedule_done("done:%s:day-%d" % [run_id, day])
	assert_true(result.get("ok", false), "day %d resolved: %s" % [day, str(result)])
	return result


## The production registry, loaded once per suite. The Day-7 handoff resolves the aggregate's SAVED
## fingerprint through exactly this instance, so the walk's own commits stay valid.
var _registry: Object = null

func _schedule_registry() -> Object:
	if _registry == null:
		var loaded: Dictionary = SCHEDULE_ACTION_REGISTRY.load_current()
		assert_true(loaded.get("ok", false), "production registry loaded: " + str(loaded))
		_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	return _registry


func _autosave_text() -> String:
	var path := _root.path_join("autosave.json")
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func test_real_ports_resolve_a_day_without_rejecting_the_snapshot() -> void:
	if _root.is_empty():
		return
	var wired := _wired()
	var run_id: String = wired["run_id"]
	var result: Dictionary = _resolve_day(wired["coordinator"], run_id, 1)
	assert_false(str(result.get("code", "")) == "invalid_checkpoint_inputs",
		"the real checkpoint port must accept real snapshot production: " + str(result))
	assert_true(result.get("ok", false), str(result))


func test_real_day_resolution_writes_a_parsable_disk_autosave() -> void:
	if _root.is_empty():
		return
	var wired := _wired()
	var run_id: String = wired["run_id"]
	if not _resolve_day(wired["coordinator"], run_id, 1).get("ok", false):
		return
	var text := _autosave_text()
	assert_false(text.is_empty(), "a real autosave.json is written to disk")
	if text.is_empty():
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	assert_true(parsed.get("ok", false), "the autosave is strict-parsable: " + str(parsed))


func test_disk_autosave_validates_as_a_save_document() -> void:
	if _root.is_empty():
		return
	var wired := _wired()
	var run_id: String = wired["run_id"]
	if not _resolve_day(wired["coordinator"], run_id, 1).get("ok", false):
		return
	var text := _autosave_text()
	if text.is_empty():
		assert_true(false, "no autosave written")
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	assert_true(validated.get("ok", false), "the written document round-trips through its schema: " + str(validated))


func test_persisted_snapshot_carries_the_live_lifecycle_and_ledger() -> void:
	if _root.is_empty():
		return
	var wired := _wired()
	var run_id: String = wired["run_id"]
	if not _resolve_day(wired["coordinator"], run_id, 1).get("ok", false):
		return
	var text := _autosave_text()
	if text.is_empty():
		assert_true(false, "no autosave written")
		return
	var document: Dictionary = STRICT_JSON.parse_object(text)["value"]
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	assert_eq(str(snapshot["run_id"]), run_id, "the live run id persisted")
	assert_eq(snapshot["lifecycle"]["day"], 2, "the completed day boundary persisted")
	assert_eq(snapshot["lifecycle"]["day"], GameState._run_lifecycle.get_day(),
		"the persisted day matches the live owner")
	assert_true((snapshot["lifecycle"] as Dictionary).has("ending_plan"), "ending_plan persisted with the lifecycle")
	assert_true(snapshot.has("command_receipts"), "the effect/variable ledger persisted")
	assert_true(snapshot.has("narrative_checkpoint"), "the narrative checkpoint field persisted")


func test_persisted_snapshot_is_restorable_by_the_save_manager() -> void:
	if _root.is_empty():
		return
	var wired := _wired()
	var run_id: String = wired["run_id"]
	if not _resolve_day(wired["coordinator"], run_id, 1).get("ok", false):
		return
	var text := _autosave_text()
	if text.is_empty():
		assert_true(false, "no autosave written")
		return
	var prepared: Dictionary = _manager.prepare_restore_autosave()
	# dwm-7e6 repair: the earlier version asserted only `prepared.has("ok")`, which is trivially
	# true even on total failure -- it proved nothing. Asserting real success exposed two genuine
	# gaps: a restore needs every participant's autoload initialized (ProfileManager ->
	# Localization -> Input -> Accessibility -> Audio -> Dialogic), and the coordinator needs its
	# five checkpoint providers wired, or it writes an autosave with an empty audio context that
	# can never be restored. Both are now part of this harness.
	assert_true(prepared.get("ok", false), "the written autosave genuinely prepares a restore: " + str(prepared))
	if not prepared.get("ok", false):
		return
	var plans := _participant_plans(prepared)
	for participant in ["run", "schedule_view", "profile", "localization", "audio", "route", "narrative"]:
		assert_true(plans.has(participant), "every participant prepared a plan: " + participant)
	var snapshot := _restored_snapshot(prepared)
	assert_eq(str(snapshot.get("run_id", "")), str(GameState._run_lifecycle.to_dict()["run_id"]),
		"the restored snapshot is the run we actually persisted")
	assert_true((snapshot.get("lifecycle", {}) as Dictionary).has("ending_plan"),
		"the restored lifecycle carries its ending_plan")


# ---- dwm-7e6 acceptance: the full Days 1-7 walk, not just Day 1 ----
# The issue requires driving the REAL coordinator across every day with the REAL checkpoint port,
# and for Day 7 the ending_plan must survive into the persisted snapshot.

func _drive_days(coordinator: Object, run_id: String, through_day: int) -> Dictionary:
	var results: Array = []
	for day in range(1, through_day + 1):
		# Schedule Done always COMMITS an aggregate, including the empty one: `empty_done` is a
		# receipt-backed cause, not the absence of a commit. Day 7's provenance handoff needs that
		# receipt, so the walk mints it through the production commit port rather than resolving a
		# day the owner never actually finished (Task 8 Step 8.7, dwm-p2r.14).
		var result: Dictionary = _resolve_day(coordinator, run_id, day)
		results.append({"day": day, "ok": result.get("ok", false), "code": str(result.get("code", ""))})
		if not result.get("ok", false):
			break
	return {"results": results, "last_day": int(GameState._run_lifecycle.get_day()), "state": String(GameState._run_lifecycle.get_state())}


func test_real_coordinator_resolves_every_day_one_through_seven() -> void:
	if _root.is_empty():
		return
	var wired := _wired()
	var walk := _drive_days(wired["coordinator"], str(wired["run_id"]), 7)
	for entry in walk["results"]:
		assert_true((entry as Dictionary)["ok"],
			"day %d must resolve through the real checkpoint port: %s" % [int((entry as Dictionary)["day"]), str((entry as Dictionary)["code"])])
	assert_eq((walk["results"] as Array).size(), 7, "all seven days were driven")


## Plan 01 Task 7 (dwm-p2r.14): the Day-7 walk no longer selects an ending, enters ENDING, or
## writes an ending autosave. It stops at the checkpointed provenance handoff that dwm-oyo.6
## consumes, leaving the run PLAYING on Day 7 with no Day 8.
func test_day_seven_walk_stops_at_the_provenance_handoff_without_entering_ending() -> void:
	if _root.is_empty():
		return
	var wired := _wired()
	var walk := _drive_days(wired["coordinator"], str(wired["run_id"]), 7)
	assert_eq(str(walk["state"]), "PLAYING",
		"the Day-7 walk stops at the provenance handoff rather than entering ENDING")
	assert_eq(int(walk["last_day"]), 7, "day stays 7; there is no Day 8")
	var live: Dictionary = GameState._run_lifecycle.to_dict()
	assert_eq(live["ending_plan"], null,
		"Plan 01 constructs no ending plan; dwm-oyo.6 owns the ordered plan")


## The Day-7 crash case under the new law. Day 6's new_day_autosave is the last disk checkpoint the
## Schedule-Done branch writes, so a Day-7 crash must come back as the SAME run on Day 7 -- still
## PLAYING, still without an ending plan, and never stranded on Day 8.
func test_a_day_seven_crash_restores_the_same_run_on_day_seven() -> void:
	if _root.is_empty():
		return
	var wired := _wired()
	var run_id: String = str(wired["run_id"])
	_drive_days(wired["coordinator"], run_id, 7)
	var live: Dictionary = GameState._run_lifecycle.to_dict()
	assert_eq(int(live["day"]), 7, "the run reached Day 7 before the crash")

	# The crash: live state is lost entirely. Only what reached disk survives.
	GameState.reset_game()
	assert_ne(int(GameState._run_lifecycle.to_dict()["day"]), 7,
		"live Day-7 state is genuinely gone before the restore")

	var prepared: Dictionary = _manager.prepare_restore_autosave()
	assert_true(prepared.get("ok", false), "the Day-7 autosave prepares a restore: " + str(prepared))
	if not prepared.get("ok", false):
		return
	var restored := _restored_snapshot(prepared)
	var lifecycle: Dictionary = restored["lifecycle"]
	assert_eq(str(restored["run_id"]), run_id, "the SAME run comes back, not a fresh one")
	assert_eq(int(lifecycle["day"]), 7, "on Day 7")
	assert_ne(int(lifecycle["day"]), 8, "there is no Day 8")
	assert_eq(lifecycle["ending_plan"], null,
		"no ending plan is recovered, because Plan 01 never produced one")
