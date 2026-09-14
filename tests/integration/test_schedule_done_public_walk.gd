extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
# dwm-p2r.21 ACCEPTANCE (dwm-oyo.3 slice, 2026-08-24): a committed-Schedule walk reaches a
# presentation, settles it, and advances -- through public seams only.
#
# THE LAW THIS PROVES. Until this slice, `complete_presentation_stage()` had no production caller:
# the only publicly reachable completion door (`complete_route_stage`) refuses every command
# production can generate, and every presentation suite settled through private
# `_run_lifecycle.complete_active_stage` access. Here the whole day resolves with the test touching
# exactly THREE doors, each of them a public production surface or the physical event itself:
#
#   1. the production Schedule commit port commits and publishes the day's draft (the
#      committed-Schedule door);
#   2. `ScheduleDoneDispatcher.dispatch_done()` issues the one Done command (the Done dispatch
#      surface Plan 03 owns -- dwm-p2r.21's recorded resolution, GameState facade REJECTED).
#      Production reaches the SAME coordinator from the Schedule UI; this fixture isolates the
#      dispatcher so the walk has one explicit public entry door;
#   3. the physical owner FINISHES the date (`owner.finish()` -- the player completing the scene),
#      which flows owner -> port -> coordinator -> dispatcher -> `complete_presentation_stage()`
#      with no test code in between.
#
# The WALK touches no `_run_lifecycle`, drives no coordinator directly, steps no state port.
# (Setup installs the run identity; the injected identity provider only reads lifecycle state,
# never drives it.) The walk's
# advance is observed from the OUTSIDE: the public `GameState.day` property and the dispatcher's
# own retained dispatch result.
#
# SUBSTRATE. Real end to end: the real GameState/SaveManager autoloads, the real coordinator,
# state port, checkpoint port over real disk, the real Schedule commit/start foundation, the real
# DesktopConsequenceSourcePort over the real DesktopBoardFatePort and desktop publication ledger
# (DEVIATION-5's finished seam -- no FakeDesktopConsequenceSource anywhere in this file), and the
# real DatingPresentationPort. The two test-scope doubles are FakeDatingPresentationOwner, which
# supplies the physical finish signal this walk drives, and FakePresentationRouter, which records
# the routed command without mounting a scene tree. Their production counterparts are covered by
# the presentation/bootstrap suites. Setup first installs an issuer-allocated run identity, then
# uses GameState's narrow day-transition helper to stand on day 3; the WALK is public-door only.

const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const DAY_ADVANCE_IDENTITY_PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const IDENTITY_ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ISSUER_ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const CRYPTO_NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const SAVE_MANAGER := preload("res://autoload/SaveManager.gd")
const SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const SCHEDULE_COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const SCHEDULE_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const DAY7_PROVENANCE := preload("res://scripts/domain/schedule/Day7ScheduleProvenance.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const CONSEQUENCE_SOURCE_PORT := preload("res://scripts/application/desktop/DesktopConsequenceSourcePort.gd")
const CONSEQUENCE_COORDINATOR := preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd")
const BOARD_FATE_PORT := preload("res://scripts/application/minesweeper/DesktopBoardFatePort.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")
const HOSPITAL_PRESENTATION_PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const DATING_PRESENTATION_PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const DATING_OWNER := preload("res://tests/support/FakeDatingPresentationOwner.gd")
const PRESENTATION_ROUTER := preload("res://tests/support/FakePresentationRouter.gd")
const DISPATCHER := preload("res://scripts/application/schedule/ScheduleDoneDispatcher.gd")
const SCHEDULE_RESTORE_FIXTURE := preload("res://tests/support/ScheduleRestoreFixture.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")

const DAY := 3

var _root := ""
var _manager: Node
var _issuer: Object = null
var _registry: Object = null
var _fingerprint := ""
var _state_port: Object = null
var _coordinator: Object = null
var _dating_owner: Object = null
var _router: Object = null
var _dispatcher: Object = null
var _commands: Dictionary = {}
var _gate: Object = null
var _schedule_ledger: Object = null
var _schedule_view: Object = null
var _board: Object = null
var _consequence: Object = null
var _fixture_ready := false


func before_each() -> void:
	_commands = {}
	_root = ""
	_issuer = null
	_registry = null
	_fingerprint = ""
	_state_port = null
	_coordinator = null
	_dating_owner = null
	_router = null
	_dispatcher = null
	_gate = null
	_schedule_ledger = null
	_schedule_view = null
	_board = null
	_consequence = null
	_fixture_ready = false
	GameState.reset_game()
	var created: Dictionary = TEMPORARY_STORAGE.create("p2r21-public-walk")
	assert_true(created.get("ok", false), created.get("message", ""))
	if not created.get("ok", false):
		return
	_root = str(created["value"])
	_manager = SAVE_MANAGER.new()
	add_child_autofree(_manager)
	var manager_initialized: Dictionary = _manager.initialize(STORAGE.new(_root))
	assert_true(manager_initialized.get("ok", false), JSON.stringify(manager_initialized))
	if not manager_initialized.get("ok", false):
		return

	var registry_loaded: Dictionary = SCHEDULE_ACTION_REGISTRY.load_current()
	assert_true(registry_loaded.get("ok", false), str(registry_loaded))
	if not registry_loaded.get("ok", false):
		return
	_registry = (registry_loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((registry_loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))

	var root_store: Object = ISSUER_ROOT_STORE.new()
	var root_configured: Dictionary = root_store.configure(STORAGE.new(_root.path_join("identity")),
		CRYPTO_NAMESPACE_SOURCE.new())
	assert_true(root_configured.get("ok", false), JSON.stringify(root_configured))
	if not root_configured.get("ok", false):
		return
	var root_loaded: Dictionary = root_store.load_or_create()
	assert_true(root_loaded.get("ok", false), JSON.stringify(root_loaded))
	if not root_loaded.get("ok", false):
		return
	_issuer = IDENTITY_ISSUER.new()
	var issuer_configured: Dictionary = _issuer.configure(root_store)
	assert_true(issuer_configured.get("ok", false), JSON.stringify(issuer_configured))
	if not issuer_configured.get("ok", false):
		return
	if not _initialize_run_identity():
		return
	GameState._lifecycle_set_playing_day(DAY)

	_gate = GATE.new()
	var gate_configured: Dictionary = _manager.configure_mutation_gate(_gate)
	assert_true(gate_configured.get("ok", false), JSON.stringify(gate_configured))
	if not gate_configured.get("ok", false):
		return
	_schedule_ledger = SCHEDULE_PUBLICATION_LEDGER.new()
	var schedule_ledger_configured: Dictionary = _schedule_ledger.configure(
		STORAGE.new(_root.path_join("schedule")))
	assert_true(schedule_ledger_configured.get("ok", false),
		JSON.stringify(schedule_ledger_configured))
	if not schedule_ledger_configured.get("ok", false):
		return
	var schedule_ledger_loaded: Dictionary = _schedule_ledger.load()
	assert_true(schedule_ledger_loaded.get("ok", false), JSON.stringify(schedule_ledger_loaded))
	if not schedule_ledger_loaded.get("ok", false):
		return
	var schedule_restore: Dictionary = SCHEDULE_RESTORE_FIXTURE.create(_issuer)
	assert_true(schedule_restore.get("ok", false), JSON.stringify(schedule_restore))
	if not schedule_restore.get("ok", false):
		return
	_schedule_view = (schedule_restore["value"] as Dictionary)["view"]
	_board = BOARD_STATE.new()
	_consequence = CONSEQUENCE_STATE.new()
	var lifecycle: Dictionary = GameState._run_lifecycle.to_dict()
	var opened: Dictionary = _schedule_view.open_day(
		int(lifecycle["day"]), str(lifecycle["causal_day_instance"]))
	assert_true(opened.get("ok", false), JSON.stringify(opened))
	if not opened.get("ok", false):
		return
	var restore_configured: Dictionary = _manager.configure_restore_participants({
		"run": preload("res://scripts/application/restore/RunRestoreParticipant.gd").new(GameState),
		"desktop_consequence": preload(
			"res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd"
		).new(_consequence),
		"desktop_board": preload(
			"res://scripts/application/restore/DesktopBoardRestoreParticipant.gd"
		).new(_board),
		"schedule_view": (schedule_restore["value"] as Dictionary)["participant"],
		"profile": preload(
			"res://scripts/application/restore/ProfileRestoreParticipant.gd"
		).new(ProfileManager),
		"localization": preload(
			"res://scripts/application/restore/LocalizationRestoreParticipant.gd"
		).new(LocalizationManager),
		"audio": preload(
			"res://scripts/application/restore/AudioRestoreParticipant.gd"
		).new(AudioManager),
		"route": preload(
			"res://scripts/application/restore/RouteRestoreParticipant.gd"
		).new(SceneRouter),
		"narrative": preload(
			"res://scripts/application/restore/NarrativeRestoreParticipant.gd"
		).new(DialogicBridge),
	})
	assert_true(restore_configured.get("ok", false), JSON.stringify(restore_configured))
	if not restore_configured.get("ok", false):
		return

	_compose_production_graph()
	_fixture_ready = true


## Install one issuer-proven run identity before the fixture's narrow day-3 transition. This is
## setup only: once a test begins, the walk still enters through the three public doors above.
func _initialize_run_identity() -> bool:
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), JSON.stringify(issued))
	if not issued.get("ok", false):
		return false
	var allocation: Dictionary = _issuer.prepare_continuation_allocation({
		"existing_run_id": null,
		"kind": "new_run",
		"remap_source_transaction_ids": [],
		"source_desktop_timeline_generation": null,
		"transaction_id": (issued["value"] as Dictionary)["token"],
		"transaction_issuer_receipt": (issued["value"] as Dictionary)["issuer_receipt"],
	})
	assert_true(allocation.get("ok", false), JSON.stringify(allocation))
	if not allocation.get("ok", false):
		return false
	var committed: Dictionary = _issuer.commit_continuation_allocation(allocation["value"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	if not committed.get("ok", false):
		return false
	var identity: Dictionary = committed["value"]
	var prepared: Dictionary = GameState.prepare_new_run_snapshot_input(
		str(identity["run_id"]), str(identity["branch_id"]),
		int(identity["desktop_timeline_generation"]), str(identity["causal_day_instance"]),
		(identity["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true), false)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return false
	var installed: Dictionary = GameState._run_lifecycle.commit_restore(
		((prepared["value"] as Dictionary)["snapshot_input"] as Dictionary)["lifecycle"])
	assert_true(installed.get("ok", false), JSON.stringify(installed))
	return installed.get("ok", false)


## Composes the graph exactly the way ApplicationBootstrap does, seam for seam -- foundation, then
## presentation ports, then the desktop consequence source and dispatcher LAST, matching the
## production stage order this slice wired.
func _compose_production_graph() -> void:
	_state_port = STATE_PORT.new(GameState)
	assert_true(_state_port.configure_day_advance_owners(
		_schedule_view, _board, _consequence).get("ok", false),
		"day advancement shares the retained restore owners")
	assert_true(_state_port.configure_checkpoint_providers({
		"dialogic_checkpoint": Callable(DialogicBridge, "get_current_narrative_checkpoint"),
		"route_id": Callable(SceneRouter, "get_current_route_id"),
		"active_app_id": Callable(self, "_active_app_id"),
		"audio_context": Callable(AudioManager, "get_semantic_audio_context"),
		"content_version": Callable(self, "_content_version"),
	}).get("ok", false))
	var provenance: Object = DAY7_PROVENANCE.new()
	assert_true(provenance.configure(_registry, _issuer).get("ok", false))
	assert_true(_state_port.configure_day7_provenance(provenance).get("ok", false))

	assert_true(_state_port.configure_resolution_identity(
		_issuer, START_PORT.new(_state_port, _registry, _issuer, _schedule_ledger)).get("ok", false))

	var checkpoint_port: Object = CHECKPOINT_PORT.new(_manager)
	assert_true(checkpoint_port.configure_fatal_latch(_gate).get("ok", false))
	_manager._journal.reset(str(GameState._run_lifecycle.to_dict()["run_id"]))
	_coordinator = COORDINATOR.new()
	assert_true(_coordinator.configure(_state_port, checkpoint_port, _gate).get("ok", false))
	var day_advance_port: Object = DAY_ADVANCE_IDENTITY_PORT.new()
	assert_true(day_advance_port.configure(_issuer).get("ok", false))
	assert_true(_coordinator.configure_day_advance_identity_port(day_advance_port).get("ok", false))

	# The presentation layer: the real Dating port over the dwm-oyo.4 owner surface, the real
	# Hospital port deliberately UNCONFIGURED (this walk presents a date; the honest hospital
	# refusal is someone else's suite), and the recording router double.
	_dating_owner = DATING_OWNER.new()
	var dating_port: Object = DATING_PRESENTATION_PORT.new()
	assert_true(dating_port.configure(_issuer, _dating_owner).get("ok", false))
	var hospital_port: Object = HOSPITAL_PRESENTATION_PORT.new()
	_router = PRESENTATION_ROUTER.new()
	assert_true(_coordinator.configure_presentation_ports(hospital_port, dating_port).get("ok", false))
	assert_true(_coordinator.configure_presentation_router(_router).get("ok", false))

	# DEVIATION-5's finished seam: the REAL consequence source over the real board-fate machinery.
	var desktop_ledger: Object = DESKTOP_PUBLICATION_LEDGER.new()
	assert_true(desktop_ledger.configure(STORAGE.new(_root.path_join("desktop"))).get("ok", false))
	assert_true(desktop_ledger.load().get("ok", false))
	var board_fate_port: Object = BOARD_FATE_PORT.new()
	assert_true(board_fate_port.configure_publication_ledger(desktop_ledger).get("ok", false))
	assert_true(board_fate_port.configure(_board, _issuer).get("ok", false))
	var source_port: Object = CONSEQUENCE_SOURCE_PORT.new()
	assert_true(source_port.configure(CONSEQUENCE_COORDINATOR.new(), board_fate_port, _issuer,
		Callable(self, "_identity_context")).get("ok", false))
	assert_true(source_port.configure_current_condition_owner(GameState).get("ok", false))
	assert_true(_state_port.configure_desktop_consequence_source(source_port).get("ok", false))

	# The Done dispatch surface, configured LAST -- after the coordinator's own completion
	# connections -- exactly as the production desktop-graph stage orders it.
	_dispatcher = DISPATCHER.new()
	assert_true(_dispatcher.configure(_coordinator, hospital_port, dating_port).get("ok", false))


func _active_app_id() -> Variant:
	return null


func _content_version() -> int:
	return 1


func _identity_context() -> Dictionary:
	var lifecycle: Dictionary = GameState._run_lifecycle.to_dict()
	return {"ok": true, "value": {
		"run_id": lifecycle["run_id"],
		"branch_id": lifecycle["branch_id"],
		"desktop_timeline_generation": lifecycle["desktop_timeline_generation"],
		"causal_day_instance": lifecycle["causal_day_instance"],
	}}


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


## Seeds a real receipt-backed solo source for the committed date, exactly as the matrix suite does:
## the Contacts offer is opened through the domain module and the accepted source lands in the live
## Contacts bag the commit port then validates against.
func _seed_solo_source(friend_id: String, action_id: String) -> String:
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
		GameState.contacts, friend_id, DAY, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	if not offered.get("ok", false):
		return ""
	var command: Dictionary = _command("open.%s" % action_id)
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	if not found.get("ok", false):
		return ""
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		offered["value"]["candidate"], friend_id, DAY, command["id"], command["receipt"],
		_issuer, ((found["value"] as Dictionary)["record"] as Dictionary))
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return ""
	GameState.contacts = opened["value"]["candidate"]
	return str(opened["receipt"]["receipt_id"])


## Commits the day's one-date draft through the production Schedule commit port -- door 1.
func _commit_date_schedule() -> bool:
	var action_id := "solo:lavinia:day%d" % DAY
	var source_receipt_id := _seed_solo_source("lavinia", action_id)
	if source_receipt_id.is_empty():
		return false
	var view_prepared: Dictionary = _schedule_view.prepare_add(
		action_id, source_receipt_id, 0, "d-lav")
	assert_true(view_prepared.get("ok", false), JSON.stringify(view_prepared))
	if not view_prepared.get("ok", false):
		return false
	var view_committed: Dictionary = _schedule_view.commit(
		(view_prepared["value"] as Dictionary)["candidate"])
	assert_true(view_committed.get("ok", false), JSON.stringify(view_committed))
	if not view_committed.get("ok", false):
		return false
	var view_fingerprint: Dictionary = _schedule_view.fingerprint()
	assert_true(view_fingerprint.get("ok", false), JSON.stringify(view_fingerprint))
	if not view_fingerprint.get("ok", false):
		return false
	var view_snapshot: Dictionary = _schedule_view.snapshot()
	assert_true(view_snapshot.get("ok", false), JSON.stringify(view_snapshot))
	if not view_snapshot.get("ok", false):
		return false
	var commit_port: Object = SCHEDULE_COMMIT_PORT.new(
		GameState, _registry, _issuer, _schedule_ledger)
	var command: Dictionary = _command("commit.day%d" % DAY)
	var prepared: Dictionary = commit_port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": str(
			(view_fingerprint["value"] as Dictionary)["fingerprint"]),
		"day": DAY,
		"causal_day_instance": str(GameState._run_lifecycle.to_dict()["causal_day_instance"]),
		"draft_entries": (((view_snapshot["value"] as Dictionary)["view"] as Dictionary)[
			"entries"] as Array).duplicate(true),
		"registry_fingerprint": _fingerprint,
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return false
	var committed: Dictionary = commit_port.call(&"commit",
		(prepared["value"] as Dictionary)["game_state_candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	if not committed.get("ok", false):
		return false
	var published: Dictionary = commit_port.call(&"publish", {
		"committed_schedule": ((prepared["value"] as Dictionary)[
			"committed_schedule"] as Dictionary).duplicate(true),
		"schedule_commit_receipt": ((prepared["value"] as Dictionary)[
			"schedule_commit_receipt"] as Dictionary).duplicate(true),
	})
	assert_true(published.get("ok", false), JSON.stringify(published))
	return published.get("ok", false)


func test_a_committed_schedule_walk_presents_settles_and_advances_through_public_doors() -> void:
	if not _fixture_ready:
		return
	if not _commit_date_schedule():
		return
	assert_eq(int(GameState.day), DAY, "the walk starts on the committed day")

	# Door 2: ONE Done command through the dispatch surface. The walk runs to the date and pauses.
	var dispatched: Dictionary = _dispatcher.dispatch_done(str(_command("commit.day%d" % DAY)["id"]) + ":resolution")
	assert_true(dispatched.get("ok", false), JSON.stringify(dispatched))
	assert_eq(dispatched.get("code"), &"await_registered_command",
		"the walk pauses awaiting the date presentation")
	var routes: Array = _router.get_routes()
	assert_eq(routes.size(), 1, "exactly one presentation was routed")
	if routes.size() != 1:
		return
	assert_eq(str((routes[0] as Dictionary)["route_id"]), "dating", "the committed date routes to dating")
	assert_eq(_dating_owner.started_commands.size(), 1,
		"the physical presentation genuinely started before the scene was routed")
	assert_eq(int(GameState.day), DAY, "the day has NOT advanced while the presentation is showing")

	# Door 3: the PLAYER finishes the date. The completion flows owner -> port -> coordinator ->
	# dispatcher -> complete_presentation_stage; the test drives nothing else.
	var completion_id := str(((routes[0] as Dictionary)["command"] as Dictionary)["completion_transaction_id"])
	_dating_owner.finish(completion_id, {"outcome": "date_completed"})

	var settled: Dictionary = _dispatcher.get_last_dispatch_result()
	assert_true(settled.get("ok", false), JSON.stringify(settled))
	assert_eq(settled.get("code"), &"plan_complete",
		"settling the one presentation resumes the walk to plan completion")
	assert_eq(int(GameState.day), DAY + 1,
		"the day advanced -- reached a presentation, settled it, and advanced, public doors only")


func test_the_walk_is_replay_safe_at_the_public_doors() -> void:
	if not _fixture_ready:
		return
	if not _commit_date_schedule():
		return
	var done_id := str(_command("commit.day%d" % DAY)["id"]) + ":resolution"
	var dispatched: Dictionary = _dispatcher.dispatch_done(done_id)
	assert_true(dispatched.get("ok", false), JSON.stringify(dispatched))
	if not dispatched.get("ok", false):
		return
	var routes: Array = _router.get_routes()
	assert_eq(routes.size(), 1, "exactly one presentation was routed")
	if routes.size() != 1:
		return
	var completion_id := str(((routes[0] as Dictionary)["command"] as Dictionary)["completion_transaction_id"])
	_dating_owner.finish(completion_id, {"outcome": "date_completed"})
	assert_eq(_dispatcher.get_last_dispatch_result().get("code"), &"plan_complete")
	assert_eq(int(GameState.day), DAY + 1)

	# The physical owner re-emitting its settled completion (a restored scene replaying) must not
	# double-advance anything. The port recognizes the already-settled transaction and deliberately
	# does NOT republish (`already_settled` suppression), so the duplicate never even reaches the
	# dispatcher: its retained result stays the original plan-complete bytes and the day is stable.
	var before_replay: Dictionary = _dispatcher.get_last_dispatch_result()
	_dating_owner.reemit(completion_id)
	assert_eq(int(GameState.day), DAY + 1, "a replayed completion advances nothing")
	assert_eq(_dispatcher.get_last_dispatch_result(), before_replay,
		"the duplicate publication is suppressed at the port, so no second dispatch ever ran")


func test_the_disk_autosave_of_the_advanced_day_is_written() -> void:
	if not _fixture_ready:
		return
	if not _commit_date_schedule():
		return
	var dispatched: Dictionary = _dispatcher.dispatch_done(
		str(_command("commit.day%d" % DAY)["id"]) + ":resolution")
	assert_true(dispatched.get("ok", false), JSON.stringify(dispatched))
	if not dispatched.get("ok", false):
		return
	var routes: Array = _router.get_routes()
	assert_eq(routes.size(), 1, "exactly one presentation was routed")
	if routes.size() != 1:
		return
	var completion_id := str(((routes[0] as Dictionary)["command"] as Dictionary)["completion_transaction_id"])
	_dating_owner.finish(completion_id, {"outcome": "date_completed"})
	var settled: Dictionary = _dispatcher.get_last_dispatch_result()
	assert_eq(settled.get("code"), &"plan_complete")
	if settled.get("code") != &"plan_complete":
		return
	var autosave_path := _root.path_join("autosave.json")
	assert_true(FileAccess.file_exists(autosave_path),
		"the new day's autosave was durably written through the real checkpoint port")
	if not FileAccess.file_exists(autosave_path):
		return
	var text := FileAccess.get_file_as_string(autosave_path)
	assert_false(text.is_empty(), "the advanced-day autosave contains document bytes")
	if text.is_empty():
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	assert_true(parsed.get("ok", false), JSON.stringify(parsed))
	if not parsed.get("ok", false):
		return
	var parsed_document: Dictionary = parsed["value"]
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed_document)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	if not validated.get("ok", false):
		return
	var document: Dictionary = (validated["value"] as Dictionary)["candidate"]
	var snapshot: Dictionary = (document["current_snapshot"] as Dictionary)["snapshot"]
	assert_eq(int((snapshot["lifecycle"] as Dictionary)["day"]), DAY + 1,
		"the durable autosave is the post-advance day boundary")
