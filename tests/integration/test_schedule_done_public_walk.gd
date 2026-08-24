extends "res://addons/gut/test.gd"
# dwm-p2r.21 ACCEPTANCE (dwm-oyo.3 slice, 2026-08-24): a committed-Schedule walk reaches a
# presentation, settles it, and advances -- through public seams only.
#
# THE LAW THIS PROVES. Until this slice, `complete_presentation_stage()` had no production caller:
# the only publicly reachable completion door (`complete_route_stage`) refuses every command
# production can generate, and every presentation suite settled through private
# `_run_lifecycle.complete_active_stage` access. Here the whole day resolves with the test touching
# exactly THREE doors, each of them a public production surface or the physical event itself:
#
#   1. the production Schedule commit port commits the day's draft (the committed-Schedule door);
#   2. `ScheduleDoneDispatcher.dispatch_done()` issues the one Done command (the Done dispatch
#      surface Plan 03 owns -- dwm-p2r.21's recorded resolution, GameState facade REJECTED);
#   3. the physical owner FINISHES the date (`owner.finish()` -- the player completing the scene),
#      which flows owner -> port -> coordinator -> dispatcher -> `complete_presentation_stage()`
#      with no test code in between.
#
# No `_run_lifecycle` access, no direct coordinator drive, no state-port stepping. The walk's
# advance is observed from the OUTSIDE: the public `GameState.day` property and the dispatcher's
# own retained dispatch result.
#
# SUBSTRATE. Real end to end: the real GameState/SaveManager autoloads, the real coordinator,
# state port, checkpoint port over real disk, the real Schedule commit/start foundation, the real
# DesktopConsequenceSourcePort over the real DesktopBoardFatePort and desktop publication ledger
# (DEVIATION-5's finished seam -- no FakeDesktopConsequenceSource anywhere in this file), and the
# real DatingPresentationPort. The only doubles are the two the production graph itself still
# lacks by recorded design: FakeDatingPresentationOwner (the dwm-oyo.4 challenge owner) and
# FakePresentationRouter (a SceneTree concern proved against the real router in the presentation
# bootstrap-wiring suite). Setup uses GameState's own day-transition helper to stand on day 3,
# exactly as every committed-Schedule suite does; the WALK itself is public-door only.

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
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")
const HOSPITAL_PRESENTATION_PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const DATING_PRESENTATION_PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const DATING_OWNER := preload("res://tests/support/FakeDatingPresentationOwner.gd")
const PRESENTATION_ROUTER := preload("res://tests/support/FakePresentationRouter.gd")
const DISPATCHER := preload("res://scripts/application/schedule/ScheduleDoneDispatcher.gd")

const DAY := 3
const CAUSAL_DAY := "causal_day_instance.a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2a1b2"
const VIEW_FINGERPRINT := "schedule_view.77777777777777777777777777777777"

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


func before_each() -> void:
	_commands = {}
	GameState.reset_game()
	GameState._lifecycle_set_playing_day(DAY)
	_root = OS.get_environment("DWM_TEST_ROOT").path_join("p2r21_public_walk").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(_root)
	_manager = SAVE_MANAGER.new()
	add_child_autofree(_manager)
	_manager.initialize(STORAGE.new(_root))

	var registry_loaded: Dictionary = SCHEDULE_ACTION_REGISTRY.load_current()
	assert_true(registry_loaded.get("ok", false), str(registry_loaded))
	_registry = (registry_loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((registry_loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))

	var root_store: Object = ISSUER_ROOT_STORE.new()
	assert_true(root_store.configure(STORAGE.new(_root.path_join("identity")),
		CRYPTO_NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	_issuer = IDENTITY_ISSUER.new()
	assert_true(_issuer.configure(root_store).get("ok", false))

	_compose_production_graph()


## Composes the graph exactly the way ApplicationBootstrap does, seam for seam -- foundation, then
## presentation ports, then the desktop consequence source and dispatcher LAST, matching the
## production stage order this slice wired.
func _compose_production_graph() -> void:
	var gate: Object = GATE.new()
	_state_port = STATE_PORT.new(GameState)
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

	var schedule_ledger: Object = SCHEDULE_PUBLICATION_LEDGER.new()
	assert_true(schedule_ledger.configure(STORAGE.new(_root.path_join("schedule"))).get("ok", false))
	assert_true(schedule_ledger.load().get("ok", false))
	assert_true(_state_port.configure_resolution_identity(
		_issuer, START_PORT.new(_state_port, _registry, _issuer, schedule_ledger)).get("ok", false))

	var checkpoint_port: Object = CHECKPOINT_PORT.new(_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	_manager._journal.reset(str(GameState._run_lifecycle.to_dict()["run_id"]))
	_coordinator = COORDINATOR.new()
	assert_true(_coordinator.configure(_state_port, checkpoint_port, gate).get("ok", false))
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
	assert_true(board_fate_port.configure(BOARD_STATE.new(), _issuer).get("ok", false))
	var source_port: Object = CONSEQUENCE_SOURCE_PORT.new()
	assert_true(source_port.configure(CONSEQUENCE_COORDINATOR.new(), board_fate_port, _issuer, {
		"run_id": str(GameState._run_lifecycle.to_dict()["run_id"]),
		"branch_id": "branch.public.walk",
		"desktop_timeline_generation": 0,
		"causal_day_instance": "",
	}).get("ok", false))
	assert_true(_state_port.configure_desktop_consequence_source(source_port).get("ok", false))

	# The Done dispatch surface, configured LAST -- after the coordinator's own completion
	# connections -- exactly as the production desktop-graph stage orders it.
	_dispatcher = DISPATCHER.new()
	assert_true(_dispatcher.configure(_coordinator, hospital_port, dating_port).get("ok", false))


func _active_app_id() -> Variant:
	return null


func _content_version() -> int:
	return 1


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
	var command: Dictionary = _command("open.%s" % action_id)
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		offered["value"]["candidate"], friend_id, DAY, command["id"], command["receipt"],
		_issuer, ((found["value"] as Dictionary)["record"] as Dictionary))
	assert_true(opened.get("ok", false), str(opened))
	GameState.contacts = opened["value"]["candidate"]
	return str(opened["receipt"]["receipt_id"])


## Commits the day's one-date draft through the production Schedule commit port -- door 1.
func _commit_date_schedule() -> void:
	var action_id := "solo:lavinia:day%d" % DAY
	var source_receipt_id := _seed_solo_source("lavinia", action_id)
	var schedule_ledger: Object = SCHEDULE_PUBLICATION_LEDGER.new()
	assert_true(schedule_ledger.configure(STORAGE.new(_root.path_join("schedule"))).get("ok", false))
	assert_true(schedule_ledger.load().get("ok", false))
	var commit_port: Object = SCHEDULE_COMMIT_PORT.new(GameState, _registry, _issuer, schedule_ledger)
	var command: Dictionary = _command("commit.day%d" % DAY)
	var prepared: Dictionary = commit_port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": DAY,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": [{
			"draft_entry_id": "d-lav",
			"day": DAY,
			"slot_index": 0,
			"action_id": action_id,
			"action_kind": "solo",
			"participants": ["lavinia"],
			"source_receipt_id": source_receipt_id,
		}],
		"registry_fingerprint": _fingerprint,
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_true(commit_port.call(&"commit",
		(prepared["value"] as Dictionary)["game_state_candidate"]).get("ok", false))


func test_a_committed_schedule_walk_presents_settles_and_advances_through_public_doors() -> void:
	_commit_date_schedule()
	assert_eq(int(GameState.day), DAY, "the walk starts on the committed day")

	# Door 2: ONE Done command through the dispatch surface. The walk runs to the date and pauses.
	var dispatched: Dictionary = _dispatcher.dispatch_done(str(_command("commit.day%d" % DAY)["id"]) + ":resolution")
	assert_true(dispatched.get("ok", false), JSON.stringify(dispatched))
	assert_eq(dispatched.get("code"), &"await_registered_command",
		"the walk pauses awaiting the date presentation")
	var routes: Array = _router.get_routes()
	assert_eq(routes.size(), 1, "exactly one presentation was routed")
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
	_commit_date_schedule()
	var done_id := str(_command("commit.day%d" % DAY)["id"]) + ":resolution"
	assert_true(_dispatcher.dispatch_done(done_id).get("ok", false))
	var completion_id := str(((_router.get_routes()[0] as Dictionary)["command"] as Dictionary)["completion_transaction_id"])
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
	_commit_date_schedule()
	assert_true(_dispatcher.dispatch_done(str(_command("commit.day%d" % DAY)["id"]) + ":resolution").get("ok", false))
	var completion_id := str(((_router.get_routes()[0] as Dictionary)["command"] as Dictionary)["completion_transaction_id"])
	_dating_owner.finish(completion_id, {"outcome": "date_completed"})
	assert_eq(_dispatcher.get_last_dispatch_result().get("code"), &"plan_complete")
	assert_true(FileAccess.file_exists(_root.path_join("autosave.json")),
		"the new day's autosave was durably written through the real checkpoint port")
