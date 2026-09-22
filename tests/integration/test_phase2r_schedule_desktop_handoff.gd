extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
# Plan 01's Schedule participant and Plan 02's desktop participants, proven consumable TOGETHER by
# a later owner without composing the Plan-03/dwm-oyo.3 player-facing departure
# (dwm-p2r.10 Plan 04 Task 2).
#
# TWO HALVES, AND THEY PROVE DIFFERENT THINGS.
#
# 1. THE GUARD half feeds Phase2RScheduleDesktopHandoffGuard the three real sealed upstream
#    documents, the real detached CURRENT bootstrap probe, and GameState's real raw predecessor
#    snapshot input. The guard keeps the sealed predecessor facts separate from the successor
#    composition now visible in that probe, then this suite mutates ONE field at a time and
#    requires an EXACT failure code. Every rejection below names its code, so nothing here can
#    pass against a stub or against an all-rejecting validator.
#
# 2. THE PREPARATION half constructs DISPOSABLE instances of the real production classes against
#    isolated production-shaped state and exercises their mutation-free capture/prepare/validation
#    paths. No fake manufactures a domain success anywhere in this file. The disposable boot opens
#    a real playable lifecycle day, installs that GameState's canonical initial consequence in the
#    real disposable consequence owner, and opens the exact retained ScheduleView for that day so
#    the CURRENT v7 snapshot can be exercised; a later preparation test also has the Schedule
#    commit port install its prepared aggregate into a separate DISPOSABLE GameState. None touches
#    a ledger, durable store, or production-scoped state.
#
# WHAT THIS FILE DELIBERATELY DOES NOT DO. It never commits an identity allocation, never commits
# a causal/admission sequence, never publishes, never composes a Done command, destination outbox,
# route, Hospital decision, terminal intent, relationship mutation, or ending. Durable allocation,
# combined commit, publication and irreversible recovery are validated only from their sealed
# owning Plan-01/02 evidence, which is exactly what the guard reads.
#
# HONEST LIMITS, STATED RATHER THAN PAPERED OVER.
#   * tests/integration/test_desktop_bootstrap_wiring.gd is sha256-BOUND in
#     evidence/phase_2r/contracts/desktop_contract.json. This task only RUNS it and never edits
#     it. The guard hashes it at the seal's own subject commit, which pins the reviewed bytes but
#     is deliberately NOT a working-tree edit detector -- that belongs to the amendment gate.
#   * Four production classes (the causal sequence port, the board-fate port, the Minesweeper save
#     port and the consequence coordinator) are proven here through their REAL validators
#     REJECTING a deliberately malformed or unconfigured request, not through a manufactured
#     success. That is real production behaviour and it proves the class is reachable and
#     mutation-free at this seam; their success paths are owned by the Plan-02 suites the seal
#     already binds, and replaying those mutations is explicitly out of Task 2's scope.
#   * The shared-allocator identity relation is proven WITHOUT reflection into the coordinator:
#     configure_day_advance_identity_port() is idempotent for the same object and returns
#     day_advance_identity_port_conflict for any other, so a second lawful composition pass that
#     succeeds while the probe id stays unchanged can only mean the coordinator holds exactly the
#     object the probe reports.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const GUARD := preload("res://tools/evidence/Phase2RScheduleDesktopHandoffGuard.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const SCHEDULE_LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const CONTACT_COMMAND_PORT := preload("res://scripts/application/contact/ContactCommandPort.gd")
const PROVENANCE := preload("res://scripts/domain/schedule/Day7ScheduleProvenance.gd")
const ADVANCE_PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const CAUSAL_SEQUENCE_PORT := preload("res://scripts/application/desktop/DesktopCausalSequencePort.gd")
const BOARD_FATE_PORT := preload("res://scripts/application/minesweeper/DesktopBoardFatePort.gd")
const MINESWEEPER_SAVE_PORT := preload("res://scripts/application/minesweeper/SaveManagerMinesweeperPort.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const APPLICATION_MUTATION_GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")
const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SCHEDULE_STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

const GAME_STATE_PATH := "res://autoload/GameState.gd"
const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const WINDOW_MODE_MANAGER := preload("res://autoload/WindowModeManager.gd")
const FAKE_AUDIO_PORT := preload("res://tests/support/FakeAudioPlaybackPort.gd")

const GATE_PATH := "res://evidence/phase_2r/schedule/gate.json"
const DESKTOP_PATH := "res://evidence/phase_2r/contracts/desktop_contract.json"
const MINESWEEPER_PATH := "res://evidence/phase_2r/contracts/minesweeper_contract.json"

const SEALED_RESTORE_ROLES: Array[String] = [
	"identity_allocation", "run", "desktop_consequence", "desktop_board",
	"profile", "localization", "audio", "route", "narrative",
]
const CURRENT_RESTORE_ROLES: Array[String] = [
	"identity_allocation", "run", "desktop_consequence", "desktop_board", "schedule_view",
	"profile", "localization", "audio", "route", "narrative",
]
const PREDECESSOR_INTEGER_FIELDS: Array[String] = [
	"schedule_port_instance_id", "provenance_owner_instance_id",
	"day_resolution_start_port_instance_id", "causal_day_advance_identity_port_instance_id",
	"desktop_publication_ledger_instance_id", "causal_sequence_port_instance_id",
	"admission_checkpoint_port_instance_id", "board_fate_port_instance_id",
	"minesweeper_round_source_port_instance_id", "shop_purchase_source_port_instance_id",
	"consequence_coordinator_instance_id", "snapshot_provider_instance_id",
]
const RESTORE_PARTICIPANT_METHODS: Array[String] = [
	"prepare", "capture", "apply_silent", "rollback_silent", "finalize",
]
const RESTORE_PARTICIPANT_PATHS: Dictionary = {
	"identity_allocation": "res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd",
	"run": "res://scripts/application/restore/RunRestoreParticipant.gd",
	"desktop_consequence": "res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd",
	"desktop_board": "res://scripts/application/restore/DesktopBoardRestoreParticipant.gd",
	"schedule_view": "res://scripts/application/restore/ScheduleViewRestoreParticipant.gd",
	"profile": "res://scripts/application/restore/ProfileRestoreParticipant.gd",
	"localization": "res://scripts/application/restore/LocalizationRestoreParticipant.gd",
	"audio": "res://scripts/application/restore/AudioRestoreParticipant.gd",
	"route": "res://scripts/application/restore/RouteRestoreParticipant.gd",
	"narrative": "res://scripts/application/restore/NarrativeRestoreParticipant.gd",
}

const CAUSAL_DAY := "causal_day_instance.3333333333333333333333333333333333333333333333333333333333333333"
const VIEW_FINGERPRINT := "schedule_view.44444444444444444444444444444444"


## Resolves tree targets from an injected map instead of /root, so one production stage can be
## wired by hand without adding Bootstrap to the tree (whose _ready() would defer into start()).
class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)


## Physical output is not part of this handoff proof. The real WindowModeManager
## retains an explicitly unavailable output, as in test_application_bootstrap.gd;
## no native window success is manufactured and no player window is changed.
class UnavailableWindowOutput extends RefCounted:
	func capture_output() -> Dictionary:
		return {"ok": false, "code": &"window_output_unavailable", "details": {}, "receipt": {}}

	func apply_mode(_mode: String) -> Dictionary:
		return {"ok": false, "code": &"window_output_unavailable", "details": {}, "receipt": {}}

	func output_matches(_mode: String) -> bool:
		return false

	func restore_output(_snapshot: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"window_output_unavailable", "details": {}, "receipt": {}}


# Captured ONCE: composing the whole production graph per test would dominate the run, and every
# guard test works on deep duplicates of these detached primitives anyway.
var _state: Dictionary = {}
var _snapshot: Dictionary = {}
var _current_snapshot: Dictionary = {}
var _gate: Dictionary = {}
var _desktop: Dictionary = {}
var _minesweeper: Dictionary = {}
var _live_game_state_id: int = 0
var _advance_replay_ok: bool = false
var _advance_id_stable: bool = false
var _schedule_view_replay_ok: bool = false
var _schedule_view_participant_id_stable: bool = false
var _schedule_view_controller_id_stable: bool = false
var _schedule_view_snapshot_stable: bool = false
var _graph_nodes: Array[Node] = []
var _root_counter: int = 0
var _fixture_ready: bool = false


func before_all() -> void:
	_fixture_ready = false
	_gate = _read_seal(GATE_PATH)
	_desktop = _read_seal(DESKTOP_PATH)
	_minesweeper = _read_seal(MINESWEEPER_PATH)
	_compose_production_graph()


func after_all() -> void:
	# free(), not queue_free(): a deferred free still counts as an unfreed child when GUT tallies
	# the script, and this suite composes the whole production graph exactly once.
	for node: Node in _graph_nodes:
		if is_instance_valid(node):
			var parent: Node = node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.free()
	_graph_nodes.clear()


func _read_seal(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert_false(text.is_empty(), "the sealed document must be readable: " + path)
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	assert_true(parsed.get("ok", false), "the sealed document must be strict JSON: " + path)
	return parsed.get("value", {}) as Dictionary


func _isolated_root() -> String:
	_root_counter += 1
	var created: Dictionary = TEMPORARY_STORAGE.create("p2r10-handoff-%d" % _root_counter)
	assert_true(created.get("ok", false), created.get("message", ""))
	return str(created.get("value", "")) if created.get("ok", false) else ""


func _adopt(node: Node) -> Node:
	add_child(node)
	_graph_nodes.append(node)
	return node


## Drives the real production stages in the exact production order, then reads the two live inputs
## from their real public seams only.
func _compose_production_graph() -> void:
	var storage_root := _isolated_root()
	if storage_root.is_empty():
		return
	var storage: RefCounted = JSON_STORAGE.new(storage_root)
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(root_store).get("ok", false))

	var game_state: Node = _adopt(load(GAME_STATE_PATH).new())
	game_state.reset_game()
	# reset_game() deliberately leaves a template at day zero. Move this disposable owner to the
	# first playable day so the retained ScheduleView and the current v7 snapshot can share the
	# same real lifecycle identity.
	game_state.call(&"_lifecycle_set_playing_day", 1)
	var initial_input: Dictionary = game_state.call(&"capture_run_snapshot_input")
	var initial_desktop: Dictionary = initial_input["desktop"]
	var state_port: RefCounted = STATE_PORT.new(game_state)
	var coordinator: RefCounted = COORDINATOR.new()

	var bootstrap: Node = HarnessBootstrap.new()
	_graph_nodes.append(bootstrap)
	bootstrap.set("_profile_storage", storage)
	bootstrap.set("_desktop_issuer_root_store", root_store)
	bootstrap.set("_desktop_identity_nonce_issuer", issuer)
	bootstrap.set("_retained_day_resolution_state_port", state_port)
	bootstrap.set("_retained_day_resolution_coordinator", coordinator)
	bootstrap.set("_contact_command_port", CONTACT_COMMAND_PORT.new())

	var save_manager: Node = _adopt(load(SAVE_MANAGER_PATH).new())
	var save_root := _isolated_root()
	if save_root.is_empty():
		return
	assert_true(save_manager.call(&"initialize", JSON_STORAGE.new(save_root)).get("ok", false))
	assert_true(save_manager.call(&"configure_identity_issuer", issuer).get("ok", false))
	var allocation_participant: RefCounted = load(
		RESTORE_PARTICIPANT_PATHS["identity_allocation"]).new(issuer, save_manager)
	assert_true(save_manager.call(&"configure_identity_allocation_participant",
		allocation_participant).get("ok", false))
	bootstrap.set("_desktop_identity_allocation_participant", allocation_participant)
	var targets: Dictionary = {
		"DialogicBridge": _adopt(load("res://autoload/DialogicBridge.gd").new()),
		"SceneRouter": _adopt(load("res://autoload/SceneRouter.gd").new()),
		"ProfileManager": _adopt(load("res://autoload/ProfileManager.gd").new()),
		"LocalizationManager": _adopt(load("res://autoload/LocalizationManager.gd").new()),
		"AudioManager": _adopt(load("res://autoload/AudioManager.gd").new(FAKE_AUDIO_PORT.new())),
		"WindowModeManager": _adopt(WINDOW_MODE_MANAGER.new(UnavailableWindowOutput.new())),
		"InputManager": _adopt(load("res://autoload/InputManager.gd").new()),
		"GameState": game_state,
		"SaveManager": save_manager,
	}
	bootstrap.set("targets", targets)

	var injected: Dictionary = bootstrap.call(&"_construct_and_inject_mutation_gate", &"final")
	assert_true(injected.get("ok", false), str(injected))
	var gate: RefCounted = bootstrap.get("_application_gate")
	# Initialize the actual preference owners in production order. Only the physical
	# audio backend is doubled; the shared Settings transaction owner is real.
	for stage: StringName in [&"initialize_profile", &"initialize_audio", &"initialize_window_mode"]:
		var initialized: Dictionary = bootstrap.call(&"_run_stage", stage, &"final")
		assert_true(initialized.get("ok", false), str(stage) + ": " + str(initialized))
	assert_same(targets["WindowModeManager"].call(&"get_settings_output_transactions"),
		targets["AudioManager"].call(&"get_settings_output_transactions"),
		"Window and Audio retain the exact shared Settings transaction owner")
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	bootstrap.set("_retained_checkpoint_port", checkpoint_port)

	assert_true(bootstrap.call(&"_configure_causal_day_advance_identity", coordinator)
		.get("ok", false), "the shared advance-identity owner composes")
	assert_true(bootstrap.call(&"_construct_schedule_foundation", game_state, state_port)
		.get("ok", false), "the Plan-01 Schedule foundation composes")
	var participants: Dictionary = bootstrap.call(&"_configure_restore_participants")
	assert_true(participants.get("ok", false), "the ten restore participants compose: " + str(participants))
	# Bootstrap's consequence owner begins unbound until New Run/restore applies its participant.
	# Install GameState's real canonical initial consequence through that owner's validation and
	# commit seams before Bootstrap replaces GameState's detached default with its live provider.
	var consequence_owner: Object = bootstrap.get("_desktop_consequence_state")
	assert_not_null(consequence_owner, "current Bootstrap retains the consequence owner")
	if consequence_owner == null:
		return
	var consequence_prepared: Dictionary = consequence_owner.call(&"prepare_restore",
		initial_desktop["consequence"])
	assert_true(consequence_prepared.get("ok", false),
		"the real consequence owner accepts GameState's canonical initial state")
	if not consequence_prepared.get("ok", false):
		return
	var consequence_committed: Dictionary = consequence_owner.call(&"commit",
		(consequence_prepared["value"] as Dictionary)["candidate"])
	assert_true(consequence_committed.get("ok", false),
		"the disposable consequence owner installs its validated initial state")
	if not consequence_committed.get("ok", false):
		return
	assert_true(bootstrap.call(&"_construct_schedule_presentation", coordinator).get("ok", false),
		"the presentation ports compose before the desktop graph, exactly as production orders them")
	assert_true(bootstrap.call(&"_configure_desktop_production_graph").get("ok", false),
		"the Plan-02 desktop production graph composes")

	# Open the exact controller retained by current Bootstrap, then replay restore configuration.
	# The replay must preserve both its participant identity and its live view bytes.
	var view_controller: Object = bootstrap.get("_retained_schedule_view_controller")
	assert_not_null(view_controller, "current Bootstrap retains the ScheduleView controller")
	if view_controller == null:
		return
	var raw_snapshot: Dictionary = game_state.call(&"capture_run_snapshot_input")
	var lifecycle: Dictionary = raw_snapshot["lifecycle"]
	var opened: Dictionary = view_controller.call(&"open_day", int(lifecycle["day"]),
		str(lifecycle["causal_day_instance"]))
	assert_true(opened.get("ok", false), "the retained ScheduleView opens the live playable day")
	if not opened.get("ok", false):
		return
	var before_replay_state: Dictionary = bootstrap.call(&"get_desktop_contract_state")
	var before_replay_participant_id: int = int(
		(before_replay_state["restore_participant_instance_ids"] as Dictionary)["schedule_view"])
	var before_replay_controller_id: int = view_controller.get_instance_id()
	var before_replay_view: Dictionary = view_controller.call(&"snapshot")
	var replayed: Dictionary = bootstrap.call(&"_configure_restore_participants")
	_schedule_view_replay_ok = bool(replayed.get("ok", false))
	_state = bootstrap.call(&"get_desktop_contract_state")
	_schedule_view_participant_id_stable = int(
		(_state["restore_participant_instance_ids"] as Dictionary)["schedule_view"]) \
		== before_replay_participant_id
	var current_view_controller: Object = bootstrap.get("_retained_schedule_view_controller")
	_schedule_view_controller_id_stable = current_view_controller != null \
		and current_view_controller.get_instance_id() == before_replay_controller_id
	var after_replay_view: Dictionary = current_view_controller.call(&"snapshot") \
		if current_view_controller != null else {}
	_schedule_view_snapshot_stable = before_replay_view == after_replay_view
	_snapshot = game_state.call(&"capture_run_snapshot_input")
	_current_snapshot = _snapshot.duplicate(true)
	if after_replay_view.get("ok", false):
		_current_snapshot["schedule_view"] = \
			(after_replay_view["value"] as Dictionary)["view"].duplicate(true)
	_live_game_state_id = game_state.get_instance_id()

	# The reflection-free shared-allocator proof: a lawful second composition pass must be accepted
	# by the SAME coordinator and must not rotate the probe's reported id.
	var first_advance_id: int = int(_state["causal_day_advance_identity_port_instance_id"])
	_advance_replay_ok = bool(bootstrap.call(&"_configure_causal_day_advance_identity", coordinator)
		.get("ok", false))
	_advance_id_stable = int((bootstrap.call(&"get_desktop_contract_state") as Dictionary)
		["causal_day_advance_identity_port_instance_id"]) == first_advance_id
	_fixture_ready = true


# -------------------------------------------------------------------------------------------------
# the caller's own local assertions (Task 2 Step 3)
# -------------------------------------------------------------------------------------------------

func test_the_probe_is_read_from_the_real_public_seam_and_carries_only_primitives() -> void:
	if not _fixture_ready:
		return
	assert_false(_state.is_empty(), "the real probe returned a state")
	for key: Variant in _state.keys():
		var value: Variant = _state[key]
		var kind: int = typeof(value)
		assert_true(kind in [TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_ARRAY, TYPE_DICTIONARY],
			"the probe hands out no live Object for " + str(key))
		assert_false(value is Object, "the probe hands out no live Object for " + str(key))


func test_the_snapshot_provider_role_is_the_live_game_state_in_this_same_boot() -> void:
	if not _fixture_ready:
		return
	assert_ne(_live_game_state_id, 0, "the harness holds a real GameState")
	assert_eq(int(_state["snapshot_provider_instance_id"]), _live_game_state_id,
		"snapshot_provider_instance_id is GameState's own id, compared inside one process")


func test_the_coordinator_holds_exactly_the_advance_port_the_probe_reports() -> void:
	if not _fixture_ready:
		return
	assert_true(_advance_replay_ok,
		"a lawful second composition pass is accepted, so no rival advance port is configured")
	assert_true(_advance_id_stable,
		"the probe's advance-port id does not rotate, so the retained owner was reused")


func test_every_declared_predecessor_role_is_a_nonzero_same_boot_integer() -> void:
	if not _fixture_ready:
		return
	# RefCounted ids are NEGATIVE in Godot, so the law is nonzero, never positive. A `> 0` check
	# here would be red against every real port in this graph.
	for field: String in PREDECESSOR_INTEGER_FIELDS:
		assert_eq(typeof(_state[field]), TYPE_INT, field + " is an integer role")
		assert_ne(int(_state[field]), 0, field + " names a retained owner")


func test_the_current_ten_restore_roles_are_ten_distinct_retained_participants() -> void:
	if not _fixture_ready:
		return
	var roles: Dictionary = _state["restore_participant_instance_ids"]
	var seen: Dictionary = {}
	var live_order: Array[String] = []
	for item: Variant in _state["restore_order"] as Array:
		live_order.append(String(item))
	assert_eq(live_order, CURRENT_RESTORE_ROLES,
		"the live probe reports Bootstrap's exact current restore order")
	for role: String in CURRENT_RESTORE_ROLES:
		assert_true(roles.has(role), "the restore role " + role + " is retained")
		assert_ne(int(roles[role]), 0, role + " names a retained participant")
		assert_false(seen.has(int(roles[role])),
			"no two restore roles share one participant: " + role)
		seen[int(roles[role])] = role
	assert_eq(roles.size(), CURRENT_RESTORE_ROLES.size(), "there are exactly ten restore roles")


func test_the_retained_schedule_view_survives_restore_configuration_replay_and_matches_the_run() -> void:
	if not _fixture_ready:
		return
	assert_true(_schedule_view_replay_ok, "restore configuration replay succeeds")
	assert_true(_schedule_view_participant_id_stable,
		"replay keeps the exact retained ScheduleView participant")
	assert_true(_schedule_view_controller_id_stable,
		"replay keeps the exact retained ScheduleView controller")
	assert_true(_schedule_view_snapshot_stable,
		"replay preserves the retained ScheduleView bytes")
	assert_true(_current_snapshot.has("schedule_view"),
		"the full current snapshot includes Bootstrap's retained ScheduleView")
	var view: Dictionary = _current_snapshot["schedule_view"]
	assert_false(view.is_empty(), "the retained ScheduleView is an opened seven-key view")
	assert_eq(view.size(), 7, "the retained ScheduleView carries its complete current shape")
	assert_eq(int(view["day"]), int((_current_snapshot["lifecycle"] as Dictionary)["day"]),
		"the ScheduleView day matches the live run")
	assert_eq(str(view["causal_day_instance"]),
		str((_current_snapshot["lifecycle"] as Dictionary)["causal_day_instance"]),
		"the ScheduleView causal identity matches the live run")


func test_the_round_and_shop_action_sources_are_two_different_owners() -> void:
	if not _fixture_ready:
		return
	assert_ne(int(_state["minesweeper_round_source_port_instance_id"]),
		int(_state["shop_purchase_source_port_instance_id"]),
		"a single object serving both action sources would collapse the recipes")


func test_the_two_publication_ledgers_are_two_different_live_owners() -> void:
	if not _fixture_ready:
		return
	assert_ne(int(_state["publication_ledger_instance_id"]),
		int(_state["desktop_publication_ledger_instance_id"]),
		"Plan 01's Schedule ledger and Plan 02's desktop ledger are distinct objects")


# -------------------------------------------------------------------------------------------------
# the guard's exact success envelope
# -------------------------------------------------------------------------------------------------

func test_the_guard_accepts_the_real_sealed_evidence_and_the_real_live_probe() -> void:
	if not _fixture_ready:
		return
	var result: Dictionary = _validate()
	assert_true(result.get("ok", false), "the real handoff validates: " + str(result))
	if not result.get("ok", false):
		return
	assert_eq(result.get("code", &""), &"ok", "success carries the ok code")
	assert_eq(result.get("receipt", {}), {}, "the guard mints no receipt")
	var value: Dictionary = result["value"]
	var keys: Array = value.keys()
	keys.sort()
	assert_eq(keys, ["allocator_binding", "predecessor_subset",
		"publication_relations", "requirement_attestation", "role_relations", "seals",
		"snapshot_facts", "successor_composition"],
		"the success envelope is exactly the eight declared members")
	var predecessor: Dictionary = value["predecessor_subset"]
	assert_eq(predecessor["sealed_restore_order"], SEALED_RESTORE_ROLES,
		"the verdict keeps the historical nine-role order attached to its seal")
	assert_eq(predecessor["live_restore_order"], CURRENT_RESTORE_ROLES,
		"the verdict reports the distinct current ten-role successor")


func test_the_success_envelope_serializes_no_numeric_instance_id() -> void:
	if not _fixture_ready:
		return
	var result: Dictionary = _validate()
	if not result.get("ok", false):
		assert_true(false, "precondition: the real handoff validates")
		return
	var rendered: String = JSON.stringify(result["value"])
	# All twelve integer roles AND all ten restore-role ids: sampling a few would leave the
	# envelope free to leak the rest.
	for field: String in PREDECESSOR_INTEGER_FIELDS:
		assert_false(rendered.contains(str(_state[field])),
			"no live numeric id reaches the verdict for " + field)
	var roles: Dictionary = _state["restore_participant_instance_ids"]
	for role: String in CURRENT_RESTORE_ROLES:
		assert_false(rendered.contains(str(roles[role])),
			"no live restore-participant id reaches the verdict for " + role)
	assert_eq(bool((result["value"]["predecessor_subset"] as Dictionary)["instance_ids_serialized"]),
		false, "the envelope says so itself")


func test_the_guard_mutates_neither_seal_nor_probe() -> void:
	if not _fixture_ready:
		return
	var gate_before: String = JSON.stringify(_gate)
	var state_before: String = JSON.stringify(_state)
	var snapshot_before: String = JSON.stringify(_snapshot)
	var passed: Dictionary = _gate
	GUARD.validate(passed, _desktop, _minesweeper, _state, _snapshot)
	assert_eq(JSON.stringify(_gate), gate_before, "the gate is unchanged")
	assert_eq(JSON.stringify(_state), state_before, "the probe is unchanged")
	assert_eq(JSON.stringify(_snapshot), snapshot_before, "the snapshot input is unchanged")


## Pins the exact reviewed bytes of the sha256-bound wiring suite this task may only RUN. It does
## NOT detect a working-tree edit to that file -- the digest comes from the seal's own subject
## tree, and the desktop amendment gate owns working-tree drift.
func test_the_verdict_pins_the_sealed_bytes_of_the_suite_this_task_may_only_run() -> void:
	if not _fixture_ready:
		return
	var result: Dictionary = _validate()
	if not result.get("ok", false):
		assert_true(false, "precondition: the real handoff validates")
		return
	var seals: Dictionary = result["value"]["seals"]
	var verified: Array = (seals["desktop_contract"] as Dictionary)["verified_source_bindings"]
	assert_true(verified.has("tests/integration/test_desktop_bootstrap_wiring.gd"),
		"the seal's recorded digest for the bound wiring suite still resolves")


func test_the_verdict_reports_the_two_requirements_no_seal_attests() -> void:
	if not _fixture_ready:
		return
	var result: Dictionary = _validate()
	if not result.get("ok", false):
		assert_true(false, "precondition: the real handoff validates")
		return
	var attestation: Dictionary = result["value"]["requirement_attestation"]
	assert_eq(attestation["unattested_by_seals"],
		["req.run.day_resolution_plan", "req.runtime.schedule_ownership"],
		"honest absence, not a claimed requirement")
	assert_eq((attestation["attested_by_seals"] as Array).size(), 9,
		"nine of Task 2's eleven requirements really are named by a seal")


func test_the_verdict_separates_historical_handoff_from_current_successor_composition() -> void:
	if not _fixture_ready:
		return
	var result: Dictionary = _validate()
	if not result.get("ok", false):
		assert_true(false, "precondition: the real handoff validates")
		return
	var successor: Dictionary = result["value"]["successor_composition"]
	assert_eq(str(successor["schedule_view_owner"]), "dwm-oyo.3")
	assert_eq(str(successor["destination_composition_owner"]), "dwm-oyo.3")
	assert_eq(bool(successor["destination_composition_probe_ready"]), false)
	assert_eq(bool(successor["sealed_dating_presentation_ready"]), false)
	assert_eq(bool(successor["live_dating_presentation_ready"]), true)
	assert_eq(str(successor["dating_production_owner"]), "dwm-oyo.4")
	assert_eq(bool(successor["full_runtime_acceptance"]), false,
		"this historical guard does not claim complete current-game acceptance")


func test_the_verdict_records_the_one_lawful_forward_readiness_divergence() -> void:
	if not _fixture_ready:
		return
	var result: Dictionary = _validate()
	if not result.get("ok", false):
		assert_true(false, "precondition: the real handoff validates")
		return
	# gate.json is a HISTORICAL seal that is never regenerated: it froze the producer as not ready
	# before DEVIATION-5 was finished. The divergence is recorded, not silently tolerated.
	assert_eq(bool(((_gate["bootstrap_probe"] as Dictionary)["readiness"] as Dictionary)
		["presentation_producer_ready"]), false, "the seal still records the historical false")
	assert_eq(bool(_state["presentation_producer_ready"]), true, "live HEAD finished DEVIATION-5")


# -------------------------------------------------------------------------------------------------
# rejections -- one mutated field each, one exact code each
# -------------------------------------------------------------------------------------------------

func test_a_non_dictionary_input_is_refused() -> void:
	if not _fixture_ready:
		return
	_expect(&"invalid_handoff_input", GUARD.validate("not-a-dictionary", _desktop, _minesweeper,
		_state, _snapshot), "a String seal")
	_expect(&"invalid_handoff_input", GUARD.validate(_gate, _desktop, _minesweeper, _state, []),
		"an Array snapshot input")


func test_a_relabelled_seal_subject_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	gate["subject_commit_subject"] = "test(schedule): something else entirely"
	_reject(&"seal_subject_mismatch", gate, _desktop, _minesweeper, _state, _snapshot,
		"a relabelled gate subject")


func test_a_seal_pointing_at_another_commit_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	desktop["subject_commit"] = "0000000000000000000000000000000000000000"
	_reject(&"seal_commit_unreachable", _gate, desktop, _minesweeper, _state, _snapshot,
		"an unreachable subject commit")


## The gate records a quarantined, evidence-only branch tip. That commit really exists in this
## object database and really is off HEAD's history, which is exactly the case a bare "can git read
## it" check would wave through.
func test_a_seal_pointing_at_an_off_history_commit_is_refused() -> void:
	if not _fixture_ready:
		return
	var quarantined: String = str((_gate["strict_branch"] as Dictionary)["tip"])
	assert_eq(quarantined.length(), 40, "the gate records a full quarantined tip")
	var desktop: Dictionary = _desktop_copy()
	desktop["subject_commit"] = quarantined
	_reject(&"seal_commit_unreachable", _gate, desktop, _minesweeper, _state, _snapshot,
		"a seal attesting a commit that exists but is not on HEAD's history")


## The nine laws below had NO test until a fresh reviewer disabled each one and watched the suite
## stay green. A guard nothing can reach is not a law, it is dead code wearing one.
func test_a_reachable_ancestor_carrying_the_wrong_subject_is_refused() -> void:
	if not _fixture_ready:
		return
	# A REAL ancestor -- the gate's own subject commit -- but not the desktop seal's. Reachability
	# passes and the subject comparison is what has to catch it.
	var desktop: Dictionary = _desktop_copy()
	desktop["subject_commit"] = str(_gate["subject_commit"])
	_reject(&"seal_subject_mismatch", _gate, desktop, _minesweeper, _state, _snapshot,
		"a seal naming a reachable commit that carries another subject")


func test_a_malformed_declared_surface_digest_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	for entry: Variant in gate["source_bindings"] as Array:
		if str((entry as Dictionary).get("path", "")) \
				== "scripts/application/run/CausalDayAdvanceIdentityPort.gd":
			(entry as Dictionary)["declared_surface_sha256"] = "not-a-digest"
	_reject(&"seal_declared_surface_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"an allocator surface digest that is not a sha256")


func test_a_role_relation_set_that_is_not_the_frozen_six_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	var relations: Array = (desktop["bootstrap_probe"] as Dictionary)["role_relations"]
	relations.remove_at(relations.size() - 1)
	_reject(&"role_relation_verdict_drift", _gate, desktop, _minesweeper, _state, _snapshot,
		"a dropped sealed role relation")


func test_two_ledgers_claiming_one_fixed_path_are_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	((desktop["external_stores"] as Dictionary)["desktop_publication_ledger"] as Dictionary) \
		["fixed_path"] = str((_gate["publication_ledger"] as Dictionary)["fixed_path"])
	_reject(&"publication_ledger_relation_violated", _gate, desktop, _minesweeper, _state,
		_snapshot, "both ledgers writing one document")


func test_a_drifted_allocation_key_format_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	(gate["day_advance_identity"] as Dictionary)["allocation_key_format"] = "source_day:target_day"
	_reject(&"allocator_receipt_shape_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"an allocation key no longer anchored to its source resolution receipt")


func test_an_allocator_receipt_missing_its_disposition_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	var allocator: Dictionary = gate["day_advance_identity"]
	var keys: Array = []
	for item: Variant in allocator["receipt_keys"] as Array:
		if str(item) != "disposition":
			keys.append(item)
	allocator["receipt_keys"] = keys
	_reject(&"allocator_receipt_shape_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"an allocator receipt that stopped recording its disposition")


func test_a_dropped_recipe_exclusion_is_refused() -> void:
	if not _fixture_ready:
		return
	var minesweeper: Dictionary = _minesweeper_copy()
	var recipes: Dictionary = minesweeper["publication_recipes"]
	var kept: Array = []
	for item: Variant in recipes["recipe_never_contains"] as Array:
		if str(item) != "recovery_payload_sha256":
			kept.append(item)
	recipes["recipe_never_contains"] = kept
	_reject(&"publication_recipe_drift", _gate, _desktop, minesweeper, _state, _snapshot,
		"a recipe exclusion quietly dropped from the seal")


func test_a_gate_that_stops_attesting_preserved_schedule_keys_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	(gate["current_versions"] as Dictionary)["committed_schedule_keys_preserved"] = false
	_reject(&"snapshot_schema_version_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a gate that stopped attesting the committed Schedule keys survive")


## The sharpest of the nine: this is the only thing standing between a REGENERATED gate.json and a
## green suite, and gate.json is a historical seal that must never be regenerated.
func test_a_gate_whose_frozen_readiness_was_regenerated_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	((gate["bootstrap_probe"] as Dictionary)["readiness"] as Dictionary)\
		["presentation_producer_ready"] = true
	_reject(&"sealed_readiness_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a gate re-recording live readiness instead of its frozen historical value")


func test_a_seal_that_drops_a_consumed_binding_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	var kept: Array = []
	for entry: Variant in desktop["source_bindings"] as Array:
		if str((entry as Dictionary).get("path", "")) != "tests/integration/test_desktop_bootstrap_wiring.gd":
			kept.append(entry)
	desktop["source_bindings"] = kept
	_reject(&"seal_source_binding_missing", _gate, desktop, _minesweeper, _state, _snapshot,
		"a dropped binding")


func test_a_repointed_binding_digest_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	for entry: Variant in gate["source_bindings"] as Array:
		if str((entry as Dictionary).get("path", "")) == "autoload/GameState.gd":
			(entry as Dictionary)["sha256"] = \
				"0000000000000000000000000000000000000000000000000000000000000000"
	_reject(&"seal_source_binding_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a repointed source digest")


func test_a_fourth_allocator_seam_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	for entry: Variant in gate["source_bindings"] as Array:
		if str((entry as Dictionary).get("path", "")) \
				== "scripts/application/run/CausalDayAdvanceIdentityPort.gd":
			(entry as Dictionary)["declared_surface"] = ["func configure(identity_issuer)",
				"func prepare_advance(request)", "func commit_advance(candidate)",
				"func force_advance(request)"]
	_reject(&"seal_declared_surface_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a fourth caller-reachable allocator seam")


func test_a_seal_without_command_records_is_refused() -> void:
	if not _fixture_ready:
		return
	var minesweeper: Dictionary = _minesweeper_copy()
	minesweeper["red_green_command_records"] = []
	_reject(&"seal_test_log_missing", _gate, _desktop, minesweeper, _state, _snapshot,
		"a seal with no hashed logs")


func test_a_repointed_test_log_digest_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	((gate["commands"] as Array)[0] as Dictionary)["log_sha256"] = \
		"1111111111111111111111111111111111111111111111111111111111111111"
	_reject(&"seal_test_log_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a repointed log digest")


func test_a_probe_missing_a_predecessor_member_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state.erase("board_fate_port_instance_id")
	_reject(&"predecessor_field_missing", _gate, _desktop, _minesweeper, state, _snapshot,
		"a dropped predecessor role")


func test_an_unnamed_probe_key_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["some_future_port_instance_id"] = 4242
	_reject(&"predecessor_field_unadmitted", _gate, _desktop, _minesweeper, state, _snapshot,
		"a probe key named by neither list")


func test_a_non_integer_predecessor_role_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["causal_sequence_port_instance_id"] = "not-an-id"
	_reject(&"predecessor_field_type", _gate, _desktop, _minesweeper, state, _snapshot,
		"a stringified role")


func test_an_unretained_predecessor_role_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["consequence_coordinator_instance_id"] = 0
	_reject(&"predecessor_instance_id_zero", _gate, _desktop, _minesweeper, state, _snapshot,
		"an unretained coordinator")


func test_a_reordered_restore_order_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["restore_order"] = ["run", "identity_allocation", "desktop_consequence", "desktop_board",
		"schedule_view",
		"profile", "localization", "audio", "route", "narrative"]
	_reject(&"restore_order_drift", _gate, _desktop, _minesweeper, state, _snapshot,
		"identity_allocation demoted out of first place")


func test_the_schedule_view_restore_role_cannot_move_out_of_its_current_slot() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	var order: Array[String] = CURRENT_RESTORE_ROLES.duplicate()
	order.erase("schedule_view")
	order.insert(5, "schedule_view")
	state["restore_order"] = order
	_reject(&"restore_order_drift", _gate, _desktop, _minesweeper, state, _snapshot,
		"ScheduleView moving behind profile")


func test_a_missing_restore_role_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	(state["restore_participant_instance_ids"] as Dictionary).erase("narrative")
	_reject(&"restore_role_set_drift", _gate, _desktop, _minesweeper, state, _snapshot,
		"nine current restore roles")


func test_a_missing_schedule_view_restore_role_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	(state["restore_participant_instance_ids"] as Dictionary).erase("schedule_view")
	_reject(&"restore_role_set_drift", _gate, _desktop, _minesweeper, state, _snapshot,
		"the successor omits its ScheduleView participant")


func test_an_unretained_restore_role_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	(state["restore_participant_instance_ids"] as Dictionary)["audio"] = 0
	_reject(&"restore_role_instance_id_zero", _gate, _desktop, _minesweeper, state, _snapshot,
		"an unretained audio participant")


func test_one_object_serving_two_restore_roles_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	var roles: Dictionary = state["restore_participant_instance_ids"]
	roles["route"] = roles["profile"]
	_reject(&"restore_role_not_distinct", _gate, _desktop, _minesweeper, state, _snapshot,
		"one participant claiming two roles")


func test_the_schedule_view_restore_role_cannot_alias_an_older_participant() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	var roles: Dictionary = state["restore_participant_instance_ids"]
	roles["schedule_view"] = roles["desktop_board"]
	_reject(&"restore_role_not_distinct", _gate, _desktop, _minesweeper, state, _snapshot,
		"ScheduleView sharing the desktop-board participant")


func test_one_object_serving_both_action_sources_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["shop_purchase_source_port_instance_id"] = \
		state["minesweeper_round_source_port_instance_id"]
	_reject(&"action_source_roles_not_distinct", _gate, _desktop, _minesweeper, state, _snapshot,
		"a merged Round/Shop source")


func test_a_flipped_sealed_role_verdict_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	var relations: Array = (desktop["bootstrap_probe"] as Dictionary)["role_relations"]
	((relations[2]) as Dictionary)["verdict"] = "equal"
	_reject(&"role_relation_verdict_drift", _gate, desktop, _minesweeper, _state, _snapshot,
		"the Round/Shop distinctness verdict flipped to equal")


func test_a_ledger_attestation_that_contradicts_the_probe_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	((desktop["external_stores"] as Dictionary)["desktop_publication_ledger"] as Dictionary) \
		["distinct_from"] = "DesktopPublicationLedger"
	_reject(&"publication_ledger_relation_violated", _gate, desktop, _minesweeper, _state,
		_snapshot, "a ledger attesting distinctness from itself")


func test_one_live_object_serving_both_ledger_roles_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["publication_ledger_instance_id"] = state["desktop_publication_ledger_instance_id"]
	_reject(&"publication_ledger_relation_violated", _gate, _desktop, _minesweeper, state,
		_snapshot, "one live ledger serving both plans")


func test_an_allocator_that_is_not_the_dot16_owner_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	(gate["day_advance_identity"] as Dictionary)["path"] = \
		"scripts/application/run/SomeOtherAllocator.gd"
	_reject(&"allocator_binding_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a substituted allocator owner")


func test_a_raw_causal_day_issue_path_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	(gate["day_advance_identity"] as Dictionary)["raw_causal_day_issue_in_plan01"] = true
	_reject(&"allocator_raw_causal_day_issue", gate, _desktop, _minesweeper, _state, _snapshot,
		"Plan 01 minting a raw causal day")


func test_a_third_resolution_kind_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	(gate["day_advance_identity"] as Dictionary)["resolution_kinds"] = \
		["schedule_done", "condition_hospital", "schedule_view_done"]
	_reject(&"allocator_resolution_kind_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a third resolution kind smuggled in from Plan 03")


func test_a_caller_supplied_target_day_identity_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	var allocator: Dictionary = gate["day_advance_identity"]
	var keys: Array = (allocator["request_keys"] as Array).duplicate()
	keys.append("target_causal_day_instance")
	keys.sort()
	allocator["request_keys"] = keys
	_reject(&"allocator_receipt_shape_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a caller handing the allocator its own target identity")


func test_a_publication_delivered_twice_across_a_restart_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	((gate["observed_publications"] as Array)[0] as Dictionary)["first_delivery_sequence"] = \
		[true, true]
	_reject(&"publication_first_delivery_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a second first-delivery after restart")


func test_an_undeclared_conflict_code_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	((gate["observed_publications"] as Array)[0] as Dictionary)["conflict_code"] = \
		"some_other_conflict"
	_reject(&"publication_conflict_code_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a conflict code the ledger never declared")


func test_a_schedule_done_recipe_carrying_a_checkpoint_is_refused() -> void:
	if not _fixture_ready:
		return
	var minesweeper: Dictionary = _minesweeper_copy()
	(minesweeper["publication_recipes"] as Dictionary)["schedule_done"] = \
		["causal_sequence", "schedule_commit", "board_fate", "day_resolution_start",
			"admission_checkpoint_receipt"]
	_reject(&"publication_recipe_drift", _gate, _desktop, minesweeper, _state, _snapshot,
		"a checkpoint receipt inside a publication recipe")


func test_a_changed_snapshot_input_shape_is_refused() -> void:
	if not _fixture_ready:
		return
	var snapshot: Dictionary = _snapshot_copy()
	snapshot["schedule_view"] = {}
	_reject(&"snapshot_input_key_set_drift", _gate, _desktop, _minesweeper, _state, snapshot,
		"a tenth snapshot member")


func test_an_undeclared_desktop_snapshot_member_is_refused() -> void:
	if not _fixture_ready:
		return
	var snapshot: Dictionary = _snapshot_copy()
	(snapshot["desktop"] as Dictionary)["outbox"] = {}
	_reject(&"snapshot_desktop_member_drift", _gate, _desktop, _minesweeper, _state, snapshot,
		"a Plan-03 outbox member appearing early")


func test_a_regressed_schema_version_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["save_document_schema_version"] = 2
	_reject(&"snapshot_schema_version_drift", _gate, _desktop, _minesweeper, state, _snapshot,
		"a save-document version below its Plan-01 seal")


func test_a_live_snapshot_version_that_disagrees_with_its_owner_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["run_snapshot_schema_version"] = RUN_SNAPSHOT_SCHEMA.SCHEMA_VERSION + 1
	_reject(&"snapshot_schema_version_drift", _gate, _desktop, _minesweeper, state, _snapshot,
		"a future snapshot version disagrees with the current owner")


func test_schema_versions_require_strict_integers_at_live_and_sealed_boundaries() -> void:
	if not _fixture_ready:
		return
	for mutation: Dictionary in [
		{"target": "live", "field": "run_snapshot_schema_version", "value": str(RUN_SNAPSHOT_SCHEMA.SCHEMA_VERSION)},
		{"target": "live", "field": "save_document_schema_version", "value": float(preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").SCHEMA_VERSION)},
		{"target": "desktop", "field": "schema_version", "value": "4"},
		{"target": "desktop", "field": "schema_version", "value": 4.0},
		{"target": "gate", "field": "run_snapshot_schema_version", "value": "3"},
		{"target": "gate", "field": "save_document_version", "value": 3.0},
	]:
		var state: Dictionary = _state_copy()
		var desktop: Dictionary = _desktop_copy()
		var gate: Dictionary = _gate_copy()
		match str(mutation["target"]):
			"live":
				state[str(mutation["field"])] = mutation["value"]
			"desktop":
				(desktop["run_snapshot_v4"] as Dictionary)[str(mutation["field"])] = \
					mutation["value"]
			"gate":
				(gate["current_versions"] as Dictionary)[str(mutation["field"])] = mutation["value"]
		_reject(&"snapshot_schema_version_drift", gate, desktop, _minesweeper, state, _snapshot,
			"schema version types are strict at " + str(mutation["target"]) + "." \
			+ str(mutation["field"]))


func test_a_readiness_fact_that_stopped_matching_its_seal_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["hospital_presentation_ready"] = false
	_reject(&"sealed_readiness_drift", _gate, _desktop, _minesweeper, state, _snapshot,
		"Hospital readiness regressing away from its seal")


func test_a_producer_regression_below_finished_deviation_5_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["presentation_producer_ready"] = false
	_reject(&"sealed_readiness_drift", _gate, _desktop, _minesweeper, state, _snapshot,
		"the presentation producer going dark again")


func test_sealed_readiness_requires_strict_booleans() -> void:
	if not _fixture_ready:
		return
	var hospital_state: Dictionary = _state_copy()
	hospital_state["hospital_presentation_ready"] = 1
	_reject(&"sealed_readiness_drift", _gate, _desktop, _minesweeper, hospital_state, _snapshot,
		"Hospital readiness encoded as an integer")
	var producer_state: Dictionary = _state_copy()
	producer_state["presentation_producer_ready"] = 1
	_reject(&"sealed_readiness_drift", _gate, _desktop, _minesweeper, producer_state, _snapshot,
		"producer readiness encoded as an integer")
	var gate: Dictionary = _gate_copy()
	((gate["bootstrap_probe"] as Dictionary)["readiness"] as Dictionary)\
		["presentation_producer_ready"] = 0
	_reject(&"sealed_readiness_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"sealed producer readiness encoded as an integer")


func test_a_requirement_split_that_overstates_its_evidence_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	var ids: Array = (gate["requirement_ids"] as Array).duplicate()
	ids.append("req.runtime.schedule_ownership")
	gate["requirement_ids"] = ids
	_reject(&"requirement_attestation_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a seal suddenly claiming an unattested requirement")


func test_a_later_owner_that_has_already_taken_the_composition_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	desktop["schedule_view_owner"] = "dwm-p2r.10"
	_reject(&"oyo_composition_claimed", _gate, desktop, _minesweeper, _state, _snapshot,
		"Phase 2R claiming ScheduleView ownership")


func test_a_destination_composition_declared_ready_inside_phase_2r_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["destination_composition_ready"] = true
	_reject(&"oyo_composition_claimed", _gate, _desktop, _minesweeper, state, _snapshot,
		"the destination outbox claiming readiness early")


func test_a_seal_that_stops_recording_dating_as_deferred_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	((gate["bootstrap_probe"] as Dictionary)["readiness"] as Dictionary)\
		["dating_presentation_ready"] = true
	_reject(&"oyo_composition_claimed", gate, _desktop, _minesweeper, _state, _snapshot,
		"a seal that stops deferring Dating to dwm-oyo.4")


func test_a_current_dating_presentation_regression_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["dating_presentation_ready"] = false
	_reject(&"oyo_composition_claimed", _gate, _desktop, _minesweeper, state, _snapshot,
		"the configured dwm-oyo.4 Dating owner regressing to unready")


func test_successor_readiness_requires_strict_booleans() -> void:
	if not _fixture_ready:
		return
	var dating_state: Dictionary = _state_copy()
	dating_state["dating_presentation_ready"] = 1
	_reject(&"oyo_composition_claimed", _gate, _desktop, _minesweeper, dating_state, _snapshot,
		"live Dating readiness encoded as an integer")
	var destination_state: Dictionary = _state_copy()
	destination_state["destination_composition_ready"] = 0
	_reject(&"oyo_composition_claimed", _gate, _desktop, _minesweeper, destination_state, _snapshot,
		"legacy destination readiness encoded as an integer")
	var gate: Dictionary = _gate_copy()
	((gate["bootstrap_probe"] as Dictionary)["readiness"] as Dictionary)\
		["dating_presentation_ready"] = 0
	_reject(&"oyo_composition_claimed", gate, _desktop, _minesweeper, _state, _snapshot,
		"sealed Dating readiness encoded as an integer")


func test_a_ready_successor_requires_a_retained_integer_dating_port() -> void:
	if not _fixture_ready:
		return
	for mutation: Dictionary in [
		{"kind": "missing", "value": null},
		{"kind": "zero", "value": 0},
		{"kind": "non_integer", "value": "dating-port"},
	]:
		var state: Dictionary = _state_copy()
		if str(mutation["kind"]) == "missing":
			state.erase("dating_presentation_port_instance_id")
		else:
			state["dating_presentation_port_instance_id"] = mutation["value"]
		_reject(&"oyo_composition_claimed", _gate, _desktop, _minesweeper, state, _snapshot,
			"ready Dating with a " + str(mutation["kind"]) + " port identity")


# -------------------------------------------------------------------------------------------------
# structural guards
#
# Every one of these was a SURVIVOR: an exhaustive campaign that mutated all 75 failure sites in
# the guard, rather than only the ones already known to be covered, left each of them green. They
# are the shape checks a malformed or truncated seal hits first, and an unproven shape check is how
# a corrupt document reaches the laws below it wearing the wrong error.
#
# FIVE SITES REMAIN DELIBERATELY UNPROVEN, because reaching them requires damaging the repository
# rather than the document:
#   * "no Git repository contains this project" in validate() and in validate_sealed_documents()
#     -- reachable only with no .git anywhere above the project;
#   * "a seal is absent from HEAD" and "a committed seal is not strict JSON" -- reachable only by
#     deleting or corrupting a tracked seal;
#   * "a bound path is absent from the seal's own subject tree" -- every commit carrying either
#     frozen subject contains all ten consumed paths, so no document mutation reaches it; pointing
#     a seal at an earlier same-subject commit produces a digest MISMATCH instead, which is the
#     adjacent site and is proven.
# They are named here so the gap is auditable rather than silent.
# -------------------------------------------------------------------------------------------------

func test_a_seal_without_an_array_of_source_bindings_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	gate["source_bindings"] = "not-an-array"
	_reject(&"seal_source_binding_missing", gate, _desktop, _minesweeper, _state, _snapshot,
		"a seal whose bindings are not an Array")


func test_an_allocator_binding_without_a_declared_surface_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	for entry: Variant in gate["source_bindings"] as Array:
		if str((entry as Dictionary).get("path", "")) \
				== "scripts/application/run/CausalDayAdvanceIdentityPort.gd":
			(entry as Dictionary)["declared_surface"] = "configure/prepare/commit"
	_reject(&"seal_declared_surface_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"an allocator surface that is not an Array")


func test_a_command_record_that_is_not_an_object_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	(gate["commands"] as Array)[0] = "not-an-object"
	_reject(&"seal_test_log_missing", gate, _desktop, _minesweeper, _state, _snapshot,
		"a command record that is not an object")


func test_a_command_record_naming_no_log_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	((gate["commands"] as Array)[0] as Dictionary)["log_path"] = ""
	_reject(&"seal_test_log_missing", gate, _desktop, _minesweeper, _state, _snapshot,
		"a command record with no log path")


func test_a_recorded_log_absent_at_head_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	((gate["commands"] as Array)[0] as Dictionary)["log_path"] = \
		"evidence/phase_2r/logs/no-such-log.log"
	_reject(&"seal_test_log_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a seal naming an evidence log that does not exist")


func test_a_restore_order_that_is_not_an_array_is_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["restore_order"] = "identity_allocation,run"
	_reject(&"predecessor_field_type", _gate, _desktop, _minesweeper, state, _snapshot,
		"a stringified restore order")


func test_restore_roles_that_are_not_a_dictionary_are_refused() -> void:
	if not _fixture_ready:
		return
	var state: Dictionary = _state_copy()
	state["restore_participant_instance_ids"] = []
	_reject(&"predecessor_field_type", _gate, _desktop, _minesweeper, state, _snapshot,
		"restore roles supplied as an Array")


func test_a_desktop_seal_without_a_bootstrap_probe_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	desktop.erase("bootstrap_probe")
	_reject(&"role_relation_verdict_drift", _gate, desktop, _minesweeper, _state, _snapshot,
		"a desktop seal that records no probe")


func test_a_desktop_seal_without_external_stores_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	desktop.erase("external_stores")
	_reject(&"publication_ledger_relation_violated", _gate, desktop, _minesweeper, _state,
		_snapshot, "a desktop seal that records no external stores")


func test_an_unrecorded_desktop_ledger_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	(desktop["external_stores"] as Dictionary)["desktop_publication_ledger"] = "unrecorded"
	_reject(&"publication_ledger_relation_violated", _gate, desktop, _minesweeper, _state,
		_snapshot, "a desktop ledger entry that is not an object")


func test_a_gate_without_a_day_advance_identity_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	gate.erase("day_advance_identity")
	_reject(&"allocator_binding_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a gate that records no allocator")


func test_a_gate_recording_no_observed_publications_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	gate["observed_publications"] = []
	_reject(&"publication_first_delivery_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a gate with an empty publication record")


func test_a_gate_recording_no_conflict_codes_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	(gate["publication_ledger"] as Dictionary)["conflict_codes"] = "none"
	_reject(&"publication_conflict_code_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a ledger that declares no conflict codes")


func test_an_observed_publication_that_is_not_an_object_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	(gate["observed_publications"] as Array)[0] = "not-an-object"
	_reject(&"publication_first_delivery_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"an observed publication that is not an object")


func test_a_minesweeper_seal_without_recipes_is_refused() -> void:
	if not _fixture_ready:
		return
	var minesweeper: Dictionary = _minesweeper_copy()
	minesweeper.erase("publication_recipes")
	_reject(&"publication_recipe_drift", _gate, _desktop, minesweeper, _state, _snapshot,
		"a Minesweeper seal that records no recipes")


func test_a_snapshot_desktop_member_that_is_not_an_object_is_refused() -> void:
	if not _fixture_ready:
		return
	var snapshot: Dictionary = _snapshot_copy()
	snapshot["desktop"] = "not-an-object"
	_reject(&"snapshot_input_key_set_drift", _gate, _desktop, _minesweeper, _state, snapshot,
		"a snapshot desktop member that is not an object")


func test_a_desktop_seal_without_v4_facts_is_refused() -> void:
	if not _fixture_ready:
		return
	var desktop: Dictionary = _desktop_copy()
	desktop.erase("run_snapshot_v4")
	_reject(&"snapshot_schema_version_drift", _gate, desktop, _minesweeper, _state, _snapshot,
		"a desktop seal that records no v4 facts")


func test_a_gate_without_current_versions_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	gate.erase("current_versions")
	_reject(&"snapshot_schema_version_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a gate that records no current versions")


func test_a_gate_without_a_bootstrap_probe_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	gate.erase("bootstrap_probe")
	_reject(&"sealed_readiness_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a gate that records no probe")


func test_a_gate_probe_without_readiness_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	(gate["bootstrap_probe"] as Dictionary)["readiness"] = "ready"
	_reject(&"sealed_readiness_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"a gate probe whose readiness is not an object")


func test_a_seal_recording_no_requirement_ids_is_refused() -> void:
	if not _fixture_ready:
		return
	var minesweeper: Dictionary = _minesweeper_copy()
	minesweeper.erase("requirement_ids")
	_reject(&"requirement_attestation_drift", _gate, _desktop, minesweeper, _state, _snapshot,
		"a seal that records no requirement ids")


# -------------------------------------------------------------------------------------------------
# the seal documents themselves
# -------------------------------------------------------------------------------------------------

## validate() hashes each seal's BINDINGS against that seal's own subject tree, which says nothing
## about the seal file's own bytes: a hand-edited gate.json that stayed internally consistent would
## otherwise sail through. This seam is separate precisely because validate()'s rejection tests
## deliberately pass mutated copies.
func test_the_three_seal_documents_match_their_committed_bytes() -> void:
	if not _fixture_ready:
		return
	var result: Dictionary = GUARD.validate_sealed_documents(_gate, _desktop, _minesweeper)
	assert_true(result.get("ok", false), "the working-tree seals equal their HEAD blobs: "
		+ str(result))
	if not result.get("ok", false):
		return
	assert_eq(str((result["value"] as Dictionary)["reference"]), "HEAD",
		"the pin is against committed bytes, not the working tree it was read from")


func test_a_hand_edited_seal_that_stays_internally_consistent_is_refused() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	var observed: Array = gate["observed_publications"]
	observed.remove_at(observed.size() - 1)
	var result: Dictionary = GUARD.validate_sealed_documents(gate, _desktop, _minesweeper)
	_expect(&"sealed_document_drift", result, "a trimmed but self-consistent gate.json")


func test_the_document_seam_refuses_a_non_dictionary_seal() -> void:
	if not _fixture_ready:
		return
	_expect(&"invalid_handoff_input",
		GUARD.validate_sealed_documents(_gate, "not-a-dictionary", _minesweeper),
		"a String contract")


# -------------------------------------------------------------------------------------------------
# the mutation-free preparation net over DISPOSABLE real production classes
# -------------------------------------------------------------------------------------------------

class Substrate extends RefCounted:
	var storage: RefCounted = null
	var root_store: RefCounted = null
	var issuer: RefCounted = null
	var registry: Object = null
	var fingerprint: String = ""
	var game_state: Node = null
	var ledger: Object = null
	var commit_port: Object = null
	var state_port: Object = null
	var start_port: Object = null
	var command_counter: int = 0


func _substrate() -> Substrate:
	var substrate: Substrate = Substrate.new()
	var root := _isolated_root()
	if root.is_empty():
		return null
	substrate.storage = JSON_STORAGE.new(root)
	substrate.root_store = ROOT_STORE.new()
	assert_true(substrate.root_store.configure(substrate.storage, NAMESPACE_SOURCE.new())
		.get("ok", false))
	assert_true(substrate.root_store.load_or_create().get("ok", false))
	substrate.issuer = ISSUER.new()
	assert_true(substrate.issuer.configure(substrate.root_store).get("ok", false))

	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	substrate.registry = (loaded.get("value", {}) as Dictionary).get("registry")
	substrate.fingerprint = str((loaded.get("value", {}) as Dictionary)
		.get("registry_fingerprint", ""))

	substrate.game_state = load(GAME_STATE_PATH).new()
	add_child_autofree(substrate.game_state)
	substrate.game_state.reset_game()

	substrate.ledger = SCHEDULE_LEDGER.new()
	assert_true(substrate.ledger.configure(substrate.storage).get("ok", false))
	assert_true(substrate.ledger.load().get("ok", false))
	substrate.commit_port = COMMIT_PORT.new(substrate.game_state, substrate.registry,
		substrate.issuer, substrate.ledger)
	substrate.state_port = STATE_PORT.new(substrate.game_state)
	substrate.start_port = START_PORT.new(substrate.state_port, substrate.registry,
		substrate.issuer, substrate.ledger)
	return substrate


func _command(substrate: Substrate, label: String) -> Dictionary:
	substrate.command_counter += 1
	var issued: Dictionary = substrate.root_store.issue(&"transaction_id")
	assert_true(issued.get("ok", false), "the real root store issues a transaction id: " + label)
	var value: Dictionary = issued.get("value", {})
	return {"id": str(value.get("token", "")),
		"receipt": (value.get("issuer_receipt", {}) as Dictionary).duplicate(true)}


func _draft(entry_id: String, slot_index: int, action_id: String, day: int) -> Dictionary:
	return {"draft_entry_id": entry_id, "slot_index": slot_index, "action_id": action_id,
		"action_kind": "ordinary", "participants": [], "source_receipt_id": null, "day": day}


func _real_commit(substrate: Substrate, label: String, day: int, drafts: Array) -> Dictionary:
	substrate.game_state._lifecycle_set_playing_day(day)
	var command: Dictionary = _command(substrate, label)
	var prepared: Dictionary = substrate.commit_port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": substrate.fingerprint,
	})
	assert_true(prepared.get("ok", false),
		"the REAL commit port produces a real aggregate for " + label + ": " + str(prepared))
	return prepared


func test_the_real_schedule_commit_port_prepares_a_detached_aggregate_without_mutating() -> void:
	if not _fixture_ready:
		return
	var substrate: Substrate = _substrate()
	if substrate == null:
		return
	var before: String = JSON.stringify((substrate.game_state.call(
		&"capture_run_snapshot_input") as Dictionary)["committed_schedule"])
	var prepared: Dictionary = _real_commit(substrate, "handoff-day1", 1, [
		_draft("draft-a", 0, "training", 1),
		_draft("draft-b", 3, "working", 1),
	])
	if not prepared.get("ok", false):
		return
	# prepare_commit is PURE: the owner still holds nothing until commit(), which this task never
	# calls. `day` moved because the harness set the playing day, so the comparison is scoped to
	# the committed Schedule aggregate itself.
	assert_eq(JSON.stringify((substrate.game_state.call(
		&"capture_run_snapshot_input") as Dictionary)["committed_schedule"]), before,
		"preparing a commit mutates no committed Schedule state")

	var value: Dictionary = prepared["value"]
	var aggregate: Dictionary = value["committed_schedule"]
	var aggregate_keys: Array = aggregate.keys()
	aggregate_keys.sort()
	assert_eq(aggregate_keys, ((_gate["schedule_state_schema"] as Dictionary)
		["aggregate_keys"] as Array), "the real aggregate matches its sealed key set")
	var receipt_keys: Array = (aggregate["commit_receipt"] as Dictionary).keys()
	receipt_keys.sort()
	assert_eq(receipt_keys, ((_gate["schedule_state_schema"] as Dictionary)
		["commit_receipt_keys"] as Array), "the real commit receipt matches its sealed key set")
	var entry_keys: Array = ((aggregate["entries"] as Array)[0] as Dictionary).keys()
	entry_keys.sort()
	assert_eq(entry_keys, ((_gate["schedule_state_schema"] as Dictionary)["entry_keys"] as Array),
		"the real entry matches its sealed key set")
	assert_eq(str(aggregate["registry_fingerprint"]), str((_gate["registry"] as Dictionary)
		["registry_fingerprint"]), "the real registry is the one the gate sealed")


func test_the_real_day_start_port_prepares_from_a_real_commit_without_starting_anything() -> void:
	if not _fixture_ready:
		return
	var substrate: Substrate = _substrate()
	if substrate == null:
		return
	var prepared: Dictionary = _real_commit(substrate, "handoff-start", 1, [
		_draft("draft-a", 0, "training", 1),
	])
	if not prepared.get("ok", false):
		return
	var committed: Dictionary = prepared["value"]
	var aggregate: Dictionary = committed["committed_schedule"]
	# The owner has to really hold the aggregate before a start may be prepared from it.
	assert_true(substrate.commit_port.call(&"commit", (committed["game_state_candidate"]
		as Dictionary).duplicate(true)).get("ok", false), "the owner accepts its own candidate")

	var resolution: Dictionary = _command(substrate, "resolution-day1")
	var start: Dictionary = substrate.start_port.call(&"prepare_from_committed_schedule", {
		"resolution_id": str(resolution["id"]),
		"resolution_issuer_receipt": (resolution["receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": aggregate.duplicate(true),
		"route_plan": (committed["route_plan"] as Array).duplicate(true),
		"board_fate_receipt": {"receipt_id": "board_fate.none", "fate": "none"},
	})
	assert_true(start.get("ok", false), "the REAL start port prepares from a real commit: "
		+ str(start))
	if not start.get("ok", false):
		return
	var receipt: Dictionary = (start["value"] as Dictionary)["start_receipt"]
	assert_eq(str(receipt["schedule_commit_receipt_id"]),
		str((aggregate["commit_receipt"] as Dictionary)["receipt_id"]),
		"the start receipt names the exact commit it began from")
	assert_null(substrate.game_state._run_lifecycle.to_dict().get("active_day_resolution"),
		"preparing a start installs no active resolution: this task never begins a day")


func test_the_real_shared_allocator_prepares_both_variants_without_committing_the_root() -> void:
	if not _fixture_ready:
		return
	var substrate: Substrate = _substrate()
	if substrate == null:
		return
	var port: Object = ADVANCE_PORT.new()
	assert_true(port.call(&"configure", substrate.issuer).get("ok", false))
	var sealed_receipt_keys: Array = (_gate["day_advance_identity"] as Dictionary)["receipt_keys"]

	for kind: String in ["schedule_done", "condition_hospital"]:
		# The window opens AFTER the fixture has issued its own identities, so what it measures is
		# prepare_advance alone rather than the fixture that fed it.
		var request: Dictionary = _advance_request(substrate, kind)
		var root_before: String = JSON.stringify(substrate.root_store.call(&"capture")
			.get("value", {}))
		var prepared: Dictionary = port.call(&"prepare_advance", request)
		assert_eq(JSON.stringify(substrate.root_store.call(&"capture").get("value", {})),
			root_before, "prepare_advance commits nothing to the external issuer root")
		assert_true(prepared.get("ok", false),
			"the REAL allocator prepares the " + kind + " variant: " + str(prepared))
		if not prepared.get("ok", false):
			continue
		var receipt: Dictionary = (prepared["value"] as Dictionary)["day_advance_identity_receipt"]
		var keys: Array = receipt.keys()
		keys.sort()
		var expected: Array = sealed_receipt_keys.duplicate()
		expected.sort()
		assert_eq(keys, expected, "the real " + kind + " receipt matches its sealed key set")
		assert_eq(str(receipt["allocation_key"]),
			kind + ":" + str(receipt["source_resolution_receipt_id"]),
			"the allocation key is resolution_kind:source_resolution_receipt_id")


func _advance_request(substrate: Substrate, resolution_kind: String) -> Dictionary:
	var parent: Dictionary = _command(substrate, "resolution-" + resolution_kind)
	var child_kind: StringName = &"day_resolution_stage"
	if resolution_kind == "condition_hospital":
		child_kind = &"hospital_resolution"
	var derived: Dictionary = substrate.issuer.call(&"derive_child", {
		"parent_receipt_id": str((parent["receipt"] as Dictionary).get("receipt_id", "")),
		"child_kind": child_kind,
		"ordinal": 0,
		"source_ids": [],
	})
	assert_true(derived.get("ok", false), "the real issuer derives an anchored resolution receipt: "
		+ str(derived))
	var value: Dictionary = derived.get("value", {})
	var causal: Dictionary = substrate.root_store.call(&"issue", &"causal_day_instance")
	assert_true(causal.get("ok", false), "the real root store issues a source causal day")
	var causal_receipt: Dictionary = ((causal.get("value", {}) as Dictionary)
		.get("issuer_receipt", {}) as Dictionary)
	return {
		"resolution_kind": resolution_kind,
		"source_resolution_receipt": {
			"receipt_id": str(value.get("child_id", "")),
			"provenance": (value.get("provenance", {}) as Dictionary).duplicate(true),
		},
		"run_id": "run-handoff",
		"branch_id": "branch-handoff",
		"desktop_timeline_generation": 0,
		"source_day": 1,
		"source_causal_day_instance": str((causal.get("value", {}) as Dictionary).get("token", "")),
		"source_causal_day_instance_issuer_receipt": causal_receipt.duplicate(true),
	}


func test_the_real_allocator_refuses_an_id_only_source_causal_day_receipt() -> void:
	if not _fixture_ready:
		return
	var substrate: Substrate = _substrate()
	if substrate == null:
		return
	var port: Object = ADVANCE_PORT.new()
	assert_true(port.call(&"configure", substrate.issuer).get("ok", false))
	var request: Dictionary = _advance_request(substrate, "schedule_done")
	request["source_causal_day_instance_issuer_receipt"] = {
		"receipt_id": str((request["source_causal_day_instance_issuer_receipt"] as Dictionary)
			.get("receipt_id", "")),
	}
	var prepared: Dictionary = port.call(&"prepare_advance", request)
	assert_false(prepared.get("ok", true),
		"an id-only source receipt is refused: the full issuer receipt is the evidence")
	assert_eq(str(prepared.get("code", "")), "causal_day_advance_source_token_mismatch",
		"the exact production code, so this cannot pass for an unrelated reason")


func test_the_real_provenance_owner_refuses_a_malformed_handoff() -> void:
	if not _fixture_ready:
		return
	var substrate: Substrate = _substrate()
	if substrate == null:
		return
	var provenance: Object = PROVENANCE.new()
	assert_true(provenance.call(&"configure", substrate.registry, substrate.issuer)
		.get("ok", false), "the REAL provenance owner configures against real dependencies")
	var rejected: Dictionary = provenance.call(&"validate_handoff", {"day": 7})
	assert_false(rejected.get("ok", true),
		"the real validator refuses a malformed handoff rather than inventing a terminal")
	assert_eq(str(rejected.get("code", "")), "invalid_day7_handoff", "the exact production code")


func test_the_real_causal_sequence_port_stays_mutation_free_before_configuration() -> void:
	if not _fixture_ready:
		return
	var port: Object = CAUSAL_SEQUENCE_PORT.new()
	var reserved: Dictionary = port.call(&"prepare_reservation", {})
	assert_eq(str(reserved.get("code", "")), "port_not_configured",
		"an unconfigured sequence port reserves nothing")
	var admitted: Dictionary = port.call(&"prepare_admission", {}, {}, "")
	assert_eq(str(admitted.get("code", "")), "port_not_configured",
		"an unconfigured sequence port admits nothing")


## Configures the REAL port through its real fail-closed ordering before asking anything of it.
## An earlier version passed a null checkpoint port, which makes configure() fail with
## invalid_state -- so the port stayed unconfigured and the "malformed request" assertion was
## really just re-testing port_not_configured. It passed, for the wrong reason.
func test_the_real_causal_sequence_port_refuses_a_malformed_reservation() -> void:
	if not _fixture_ready:
		return
	var substrate: Substrate = _substrate()
	if substrate == null:
		return
	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	add_child_autofree(save_manager)
	var save_root := _isolated_root()
	if save_root.is_empty():
		return
	assert_true(save_manager.call(&"initialize", JSON_STORAGE.new(save_root))
		.get("ok", false))
	var gate: RefCounted = APPLICATION_MUTATION_GATE.new()
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	var state: Object = DESKTOP_CONSEQUENCE_STATE.new()
	var ledger: Object = DESKTOP_PUBLICATION_LEDGER.new()
	assert_true(ledger.call(&"configure", substrate.storage).get("ok", false))
	assert_true(ledger.call(&"load").get("ok", false))

	var port: Object = CAUSAL_SEQUENCE_PORT.new()
	# Fail-closed ordering is production law: configure() refuses until the ledger is bound.
	assert_eq(str(port.call(&"configure", state, gate, checkpoint_port).get("code", "")),
		"publication_ledger_not_configured", "the exact production ordering code")
	assert_true(port.call(&"configure_publication_ledger", ledger).get("ok", false))
	assert_true(port.call(&"configure", state, gate, checkpoint_port).get("ok", false),
		"the REAL three-owner configure seam accepts real owners")

	var reserved: Dictionary = port.call(&"prepare_reservation", {"transaction_id": "t"})
	assert_eq(str(reserved.get("code", "")), "causal_reservation_request_invalid",
		"a partial reservation request is refused by the real key-set check")
	# A configured port never adopts a replacement owner -- the plan's "reject a second sequence
	# owner" boundary, proven against the real class rather than asserted in prose.
	assert_eq(str(port.call(&"configure", DESKTOP_CONSEQUENCE_STATE.new(), gate, checkpoint_port)
		.get("code", "")), "port_already_configured", "a second owner is refused")


func test_the_real_board_fate_port_refuses_a_projected_departure_before_configuration() -> void:
	if not _fixture_ready:
		return
	var port: Object = BOARD_FATE_PORT.new()
	var projected: Dictionary = port.call(&"prepare_projected_causal_departure", {})
	assert_false(projected.get("ok", true), "an unconfigured board-fate port projects nothing")
	assert_eq(str(projected.get("code", "")), "board_fate_port_not_configured",
		"the exact production code, so this cannot pass against a stub")


func test_the_real_minesweeper_save_port_refuses_an_incapable_checkpoint_owner() -> void:
	if not _fixture_ready:
		return
	var port: Object = MINESWEEPER_SAVE_PORT.new()
	var configured: Dictionary = port.call(&"configure", RefCounted.new(), RefCounted.new())
	assert_false(configured.get("ok", true), "an incapable owner is refused")
	assert_eq(str(configured.get("code", "")), "invalid_minesweeper_save_port",
		"the exact production code")


func test_the_real_minesweeper_save_port_binds_the_real_checkpoint_owner() -> void:
	if not _fixture_ready:
		return
	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	add_child_autofree(save_manager)
	var save_root := _isolated_root()
	if save_root.is_empty():
		return
	assert_true(save_manager.call(&"initialize", JSON_STORAGE.new(save_root))
		.get("ok", false))
	var gate: RefCounted = APPLICATION_MUTATION_GATE.new()
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	var port: Object = MINESWEEPER_SAVE_PORT.new()
	var configured: Dictionary = port.call(&"configure", checkpoint_port, save_manager)
	assert_true(configured.get("ok", false),
		"the REAL Minesweeper save port binds the REAL checkpoint owner: " + str(configured))
	assert_eq(str(configured.get("code", "")), "ok", "the exact production success code")
	if not configured.get("ok", false):
		return
	assert_false(bool(port.call(&"owns_board_lock")),
		"binding the port takes no board lock: preparation stays mutation-free")


func test_the_ten_real_restore_participant_classes_share_one_interface() -> void:
	if not _fixture_ready:
		return
	for role: String in CURRENT_RESTORE_ROLES:
		var script: Script = load(str(RESTORE_PARTICIPANT_PATHS[role]))
		assert_not_null(script, "the real participant class for " + role + " exists")
		var method_names: Array[String] = []
		for entry: Dictionary in script.get_script_method_list():
			method_names.append(str(entry["name"]))
		for method: String in RESTORE_PARTICIPANT_METHODS:
			assert_true(method_names.has(method),
				"the real " + role + " participant declares " + method)


## GameState.capture_run_snapshot_input() is still the raw nine-key predecessor contribution.
## Current Bootstrap adds its retained ScheduleView before RunSnapshotSchema.build(); this fixture
## does the same with the exact controller whose participant survived configuration replay.
func test_the_current_snapshot_input_round_trips_through_the_real_v7_schema() -> void:
	if not _fixture_ready:
		return
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(_current_snapshot.duplicate(true), {}, "main", null,
		{}, 1, 1)
	assert_true(built.get("ok", false),
		"the real current snapshot input builds a real v7 snapshot: " + str(built))
	if not built.get("ok", false):
		return
	var snapshot: Dictionary = (built["value"] as Dictionary)["snapshot"]
	assert_eq(int(snapshot["schema_version"]), 7, "build stamps the current v7 version")
	assert_eq(snapshot["schedule_view"], _current_snapshot["schedule_view"],
		"the v7 builder preserves the exact retained ScheduleView")
	assert_true(RUN_SNAPSHOT_SCHEMA.validate(snapshot.duplicate(true)).get("ok", false),
		"the produced snapshot revalidates, which is what makes this a round trip")
	assert_eq(int(_state["run_snapshot_schema_version"]), RUN_SNAPSHOT_SCHEMA.SCHEMA_VERSION,
		"the live schema version matches the current owner")
	assert_eq(int((_desktop["run_snapshot_v4"] as Dictionary)["schema_version"]), 4,
		"the historical desktop seal remains v4")


func test_the_real_v7_builder_refuses_a_snapshot_input_missing_a_declared_member() -> void:
	if not _fixture_ready:
		return
	var incomplete: Dictionary = _current_snapshot_copy()
	incomplete.erase("desktop")
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(incomplete, {}, "main", null, {}, 1, 1)
	assert_false(built.get("ok", true), "a snapshot input missing desktop builds nothing")
	assert_eq(str(built.get("code", "")), "invalid_snapshot_input", "the exact production code")


func test_the_real_v7_builder_refuses_a_snapshot_input_missing_schedule_view() -> void:
	if not _fixture_ready:
		return
	var incomplete: Dictionary = _current_snapshot_copy()
	incomplete.erase("schedule_view")
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(incomplete, {}, "main", null, {}, 1, 1)
	assert_false(built.get("ok", true), "a v7 snapshot input missing ScheduleView builds nothing")
	assert_eq(str(built.get("code", "")), "invalid_snapshot_input", "the exact production code")


func test_the_real_schedule_state_schema_rejects_the_aggregate_the_seal_forbids() -> void:
	if not _fixture_ready:
		return
	var rejected: Dictionary = SCHEDULE_STATE_SCHEMA.validate_aggregate({"schema_version": 1})
	assert_eq(str(rejected.get("code", "")), "invalid_committed_schedule",
		"the real schema refuses an aggregate missing its sealed members")


# -------------------------------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------------------------------

func _validate() -> Dictionary:
	return GUARD.validate(_gate, _desktop, _minesweeper, _state, _snapshot)


func _gate_copy() -> Dictionary:
	return _gate.duplicate(true)


func _desktop_copy() -> Dictionary:
	return _desktop.duplicate(true)


func _minesweeper_copy() -> Dictionary:
	return _minesweeper.duplicate(true)


func _state_copy() -> Dictionary:
	return _state.duplicate(true)


func _snapshot_copy() -> Dictionary:
	return _snapshot.duplicate(true)


func _current_snapshot_copy() -> Dictionary:
	return _current_snapshot.duplicate(true)


func _reject(code: StringName, gate: Dictionary, desktop: Dictionary, minesweeper: Dictionary,
		state: Dictionary, snapshot: Dictionary, note: String) -> void:
	_expect(code, GUARD.validate(gate, desktop, minesweeper, state, snapshot), note)


## EVERY rejection asserts an EXACT code. A test that only asserted ok == false would pass against
## a stub and against an all-rejecting validator, which is the failure mode Task 1 was caught by.
func _expect(code: StringName, result: Dictionary, note: String) -> void:
	assert_false(result.get("ok", true), note + " must be rejected")
	assert_eq(result.get("code", &""), code,
		note + " must fail exactly " + String(code) + ", observed "
		+ String(result.get("code", &"")) + " " + str(result.get("message", "")))

func test_pre_cutover_or_future_live_schema_claims_are_refused() -> void:
	if not _fixture_ready:
		return
	for key: String in ["run_snapshot_schema_version", "save_document_schema_version"]:
		for version: int in [int(_state[key]) - 1, int(_state[key]) + 1]:
			var state := _state_copy()
			state[key] = version
			_reject(&"snapshot_schema_version_drift", _gate, _desktop, _minesweeper, state, _snapshot,
				"live schema facts must match the current owner: %s=%d" % [key, version])


func test_sealed_hospital_readiness_requires_a_strict_boolean() -> void:
	if not _fixture_ready:
		return
	var gate: Dictionary = _gate_copy()
	((gate["bootstrap_probe"] as Dictionary)["readiness"] as Dictionary)\
		["hospital_presentation_ready"] = 1
	_reject(&"sealed_readiness_drift", gate, _desktop, _minesweeper, _state, _snapshot,
		"sealed Hospital readiness encoded as an integer")
