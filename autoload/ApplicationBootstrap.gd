extends Node

signal application_ready()
signal development_subset_ready(subset_id: StringName)
signal startup_recovery_changed()

## The cache disappears with its desktop scene; the host owner outlives both.
class ContactsDesktopEvictionPort extends RefCounted:
	var view: WeakRef
	func dispatch_desktop_eviction(command: Dictionary) -> Dictionary:
		var desktop: Object = view.get_ref() if view != null else null
		if desktop == null:
			return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}
		return desktop.dispatch_desktop_eviction(command)

const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const DESKTOP_ISSUER_ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const CRYPTO_DESKTOP_NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const DESKTOP_IDENTITY_NONCE_ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const CONTACT_COMMAND_PORT := preload("res://scripts/application/contact/ContactCommandPort.gd")
const CONTACTS_PRESENTATION_PORT := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
## dwm-p2r.13 Plan-01 Task 6: Bootstrap owns day-resolution construction, GameState only installs.
const DAY_RESOLUTION_STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const DAY_RESOLUTION_COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const CAUSAL_DAY_ADVANCE_IDENTITY_PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const SCHEDULE_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const SCHEDULE_COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const DAY_RESOLUTION_START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const DAY7_SCHEDULE_PROVENANCE := preload("res://scripts/domain/schedule/Day7ScheduleProvenance.gd")
const HOSPITAL_PRESENTATION_PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const DATING_PRESENTATION_PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const DIALOGIC_PRESENTATION_OWNER_ADAPTER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const APPLICATION_MUTATION_GATE_SCRIPT := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
## dwm-p2r.8 Plan-05 Task 2: one narrative checkpoint adapter + one ending playback port.
const NARRATIVE_CHECKPOINT_PORT := preload("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd")
const ENDING_PLAYBACK_PORT := preload("res://scripts/application/ending/DialogicEndingPlaybackPort.gd")
const DIALOGIC_RUNTIME_ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const DIALOGIC_TIMELINE_CATALOG := preload("res://scripts/data/DialogicTimelineCatalog.gd")
## Narrative manifest content version supplied to every narrative checkpoint input.
const NARRATIVE_CONTENT_VERSION := 1
## dwm-p2r.9 Plan 02 Task 1: one Bootstrap-owned desktop host + its restore participant seam.
const DESKTOP_APP_HOST_STATE := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const RUN_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/RunRestoreParticipant.gd")
const PROFILE_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/ProfileRestoreParticipant.gd")
const LOCALIZATION_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/LocalizationRestoreParticipant.gd")
const AUDIO_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/AudioRestoreParticipant.gd")
const ROUTE_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/RouteRestoreParticipant.gd")
const NARRATIVE_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")
## Plan 02 Task 6 (dwm-p2r.32), Phase C2.
const DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const DESKTOP_BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const DESKTOP_CONSEQUENCE_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd")
const DESKTOP_BOARD_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd")
const FATAL_DIAGNOSTIC_PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")
const MINESWEEPER_ROUND_COORDINATOR := preload("res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd")
const MINESWEEPER_STATE_PORT := preload("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd")
const MINESWEEPER_SAVE_PORT := preload("res://scripts/application/minesweeper/SaveManagerMinesweeperPort.gd")
## Plan 02 Task 9 (dwm-p2r.32): the one production desktop board/consequence/causal graph, kept
## distinct from the retained .9-era simulator stack above (no shared identity, no shared state).
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")
const DESKTOP_CAUSAL_SEQUENCE_PORT := preload("res://scripts/application/desktop/DesktopCausalSequencePort.gd")
const DESKTOP_CONSEQUENCE_COORDINATOR := preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd")
const DESKTOP_BOARD_FATE_PORT := preload("res://scripts/application/minesweeper/DesktopBoardFatePort.gd")
const MINESWEEPER_GENERATION_PORT := preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd")
const MINESWEEPER_PANEL_PORT := preload("res://scripts/application/minesweeper/MinesweeperPanelPort.gd")
const PROVISIONAL_CORRESPONDENCE := preload("res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd")
const DAY7_PRELUDE_OWNER := preload("res://scripts/application/contact/Day7PreludeOwner.gd")
const GAMEPLAY_DATA_CATALOG := preload("res://scripts/data/DataCatalog.gd")
const SCHEDULE_PRESENTATION := preload("res://scripts/application/schedule/SchedulePresentationPort.gd")
const SCHEDULE_COMMANDS := preload("res://scripts/application/schedule/ScheduleCommandPort.gd")
const SCHEDULE_WARNING_CONTEXT := preload("res://scripts/application/schedule/GameStateScheduleWarningContextPort.gd")
const SCHEDULE_WARNING_PRESENTATION := preload("res://scripts/application/schedule/ScheduleWarningPresentationPort.gd")
const SCHEDULE_COPY := preload("res://scripts/ui/schedule/ScheduleCopy.gd")
const MINESWEEPER_ROUND_COORDINATOR_APP := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const MINESWEEPER_SHOP_PURCHASE_PARTICIPANT := preload("res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd")
const GAME_STATE_DESKTOP_BOARD_PORT := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd")
const GAME_STATE_MINESWEEPER_SHOP_PORT := preload("res://scripts/application/shop/GameStateMinesweeperShopPort.gd")
const SAVE_MANAGER_DESKTOP_BOARD_PORT := preload("res://scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd")
const DESKTOP_FIRST_REVEAL_SNAPSHOT_COMPOSER := preload("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd")
const MINESWEEPER_SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")
const DESKTOP_IDENTITY_ALLOCATION_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd")
const RUN_SNAPSHOT_SCHEMA_FOR_PROBE := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
## dwm-oyo.3 slice (2026-08-24, authorized on dwm-p2r.21 / dwm-oyo.3): the Plan-03 condition
## pair, the Schedule-Done consequence source finishing DEVIATION-5, and the Done dispatch surface.
const DESKTOP_CONDITION_CONTEXT_PORT := preload("res://scripts/application/desktop/GameStateDesktopConditionContextPort.gd")
const DESKTOP_CONDITION_POLICY_PORT := preload("res://scripts/application/desktop/DesktopConditionPolicyPort.gd")
const SCHEDULE_DEPARTURE_VIEW_PORT := preload("res://scripts/application/schedule/ScheduleDepartureViewPort.gd")
const DESKTOP_CONSEQUENCE_SOURCE_PORT := preload("res://scripts/application/desktop/DesktopConsequenceSourcePort.gd")
const SCHEDULE_DONE_DISPATCHER := preload("res://scripts/application/schedule/ScheduleDoneDispatcher.gd")
## Amendment Plan 03 Task 4 (dwm-oyo.3): the saved-ScheduleView restore seam. The controller and
## the participant are constructed exactly once by _configure_schedule_view_participant() below.
const SCHEDULE_VIEW_CONTROLLER := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const SCHEDULE_RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const SCHEDULE_VIEW_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/ScheduleViewRestoreParticipant.gd")
const CONTINUATION_REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
const SAVE_DOCUMENT_SCHEMA_FOR_PROBE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const RUN_SNAPSHOT_SCHEMA_VERSION := RUN_SNAPSHOT_SCHEMA_FOR_PROBE.SCHEMA_VERSION
const SAVE_DOCUMENT_SCHEMA_VERSION := SAVE_DOCUMENT_SCHEMA_FOR_PROBE.DOCUMENT_VERSION
## Frozen live restore order (dwm-p2r.32 Plan 02 Task 9 brief; extended by Amendment Plan 03 Task 4,
## dwm-oyo.3): identity_allocation applies once, before the ordinary NINE-participant loop
## SaveManager itself drives.
const _RESTORE_ORDER: Array[StringName] = [
	&"identity_allocation", &"run", &"desktop_consequence", &"desktop_board", &"schedule_view",
	&"profile", &"localization", &"audio", &"route", &"narrative",
]

const MODE_FINAL := &"final"
const MODE_TEST_MANUAL := &"test_manual"
const MODE_PROFILE_LOCALIZATION_DEVELOPMENT := &"profile_localization_development"
const MODE_PROFILE_LOCALE_AUDIO_DEVELOPMENT := &"profile_locale_audio_development"

const STAGE_ORDER: Array[StringName] = [
	&"select_and_prove_roots",
	&"construct_and_inject_mutation_gate",
	&"construct_identity_issuer_and_contact_commands",
	&"initialize_saves",
	&"initialize_profile",
	&"initialize_localization",
	&"initialize_input",
	&"initialize_accessibility",
	&"initialize_audio",
	&"initialize_window_mode",
	&"initialize_dialogic_bridge",
	&"configure_restore_participants",
	&"configure_day_resolution",
	&"configure_minesweeper_rounds",
	&"publish_application_ready",
]

const FINAL_GATE_TARGETS: Array[StringName] = [
	&"SaveManager", &"GameState", &"ProfileManager", &"LocalizationManager",
	&"AudioManager", &"WindowModeManager", &"SceneRouter", &"DialogicBridge", &"InputManager",
]

const DEVELOPMENT_GATE_TARGETS := {
	MODE_PROFILE_LOCALIZATION_DEVELOPMENT: [&"ProfileManager", &"LocalizationManager", &"InputManager", &"AccessibilityManager"],
	MODE_PROFILE_LOCALE_AUDIO_DEVELOPMENT: [&"ProfileManager", &"LocalizationManager", &"InputManager", &"AccessibilityManager", &"AudioManager", &"DialogicBridge"],
}

const DEVELOPMENT_STAGE_SETS := {
	MODE_PROFILE_LOCALIZATION_DEVELOPMENT: [&"select_and_prove_roots", &"construct_and_inject_mutation_gate", &"initialize_profile", &"initialize_localization", &"initialize_input", &"initialize_accessibility"],
	MODE_PROFILE_LOCALE_AUDIO_DEVELOPMENT: [&"select_and_prove_roots", &"construct_and_inject_mutation_gate", &"initialize_profile", &"initialize_localization", &"initialize_input", &"initialize_accessibility", &"initialize_audio", &"initialize_dialogic_bridge"],
}

var _started := false
var _start_begun := false
var _startup_recovery_busy := false
var _new_run_startup_recovery := {
	"available": false, "transaction_id": "", "failed_stage": &"",
}
var _startup_route_owner: Object = null
var _startup_route_hold_token := ""
var _debug_gate_factory: Callable
var _selected_root := ""
var _profile_storage: RefCounted
var _application_gate: Object = null
var _desktop_issuer_root_store: RefCounted = null
var _desktop_identity_nonce_issuer: RefCounted = null
## The ONE day-resolution state port and coordinator (dwm-p2r.13 Plan-01 Task 6). Retained here so
## identical startup replay reuses these exact instances and the provider stage can be handed the
## same state port the coordinator was configured with, instead of reaching into GameState for it.
var _retained_day_resolution_state_port: RefCounted = null
var _retained_day_resolution_coordinator: RefCounted = null
## ONE shared root-atomic logical-day identity owner, built from the retained .16 issuer and kept
## for Plan 03's condition-Hospital advancement (Plan 01 Task 7 Step 7.5, dwm-p2r.14).
var _retained_causal_day_advance_identity_port: RefCounted = null
## The ONE Schedule-foundation identity set (dwm-p2r.13 Plan-01 Task 6). One registry, one ledger
## shared by both ports, one commit port, one start port, one provenance service.
var _retained_schedule_registry: RefCounted = null
var _retained_publication_ledger: RefCounted = null
var _retained_schedule_commit_port: RefCounted = null
var _retained_day_resolution_start_port: RefCounted = null
var _retained_day7_provenance: RefCounted = null
## The Task-8 presentation composition (Plan 01, dwm-p2r.14). Exactly one narrative owner, one
## Hospital port configured with it, and one Dating port configured later when
## dwm-oyo.4 supplies the relationship-board owner.
var _retained_presentation_owner_adapter: RefCounted = null
var _retained_hospital_presentation_port: RefCounted = null
var _retained_dating_presentation_port: RefCounted = null
var _retained_dating_physical_owner: RefCounted = null
var _retained_condition_hospital_state: RefCounted = null
var _retained_condition_hospital_adapter: RefCounted = null
var _retained_condition_hospital_coordinator: RefCounted = null
var _pending_live_continuation: Dictionary = {}
var _live_continuation_queued := false
var _condition_hospital_pump_queued := false
var _condition_hospital_pump_running := false
var _last_condition_hospital_result: Dictionary = {}
var _contact_command_port: RefCounted = null
var _contacts_presentation_port: RefCounted = null
var _day7_prelude_owner: Node = null
var _contacts_desktop_eviction_port: RefCounted = null
## The ONE real checkpoint port, constructed in initialize_saves and reused by the narrative
## adapter and the later configure_day_resolution stage. A second construction is a wiring bug.
var _retained_checkpoint_port: RefCounted = null
var _narrative_checkpoint_adapter: Object = null
var _ending_playback_port: Object = null
var _pair_deck_draw_port: RefCounted = null
## The ONE Bootstrap-owned desktop host for the process lifetime (dwm-p2r.9 Plan 02 Task 1).
## The stable active-app Callable reads this; it is null until the configure_restore_participants
## stage constructs and assigns it.
var _desktop_host_state: RefCounted = null
## At most one Phase-3-owned desktop eviction port. Assigned via register_desktop_eviction_port.
var _desktop_eviction_port: Object = null
## Plan 02 Task 6 (dwm-p2r.32), Phase C2: the ONE Bootstrap-owned live desktop consequence/board
## state pair the two new restore participants wrap directly (mirrors `_desktop_host_state` above --
## constructed once, only while still null, so identical startup replay is safe). Production
## first-Reveal wiring of these SAME live objects into gameplay is Task 9's job; here they exist only
## so SaveManager's 8-key restore participant set has somewhere real to restore desktop state into.
var _desktop_consequence_state: RefCounted = null
var _desktop_board_state: RefCounted = null
## The ONE Minesweeper round coordinator and its two production adapters (dwm-p2r.9 Plan 06
## Task 2). Constructed once, configured with initialized production ports, and installed in
## GameState exactly once; identical startup replay reuses these exact instances.
var _retained_minesweeper_state_port: RefCounted = null
var _retained_minesweeper_save_port: RefCounted = null
var _retained_minesweeper_coordinator: RefCounted = null
## The exact provider bundle handed to BOTH checkpoint producers, so the Minesweeper port and
## the day-resolution port read one set of Callable identities.
var _checkpoint_provider_bundle: Dictionary = {}
## The 8-key restore-participant dict SaveManager was configured with, retained here so the
## desktop-contract probe never has to reach back into SaveManager for identities Bootstrap itself
## already built (dwm-p2r.32 Plan 02 Task 9).
var _retained_restore_participants: Dictionary = {}
## The identity-allocation restore participant (separate from the 8-key set above; applies once,
## before it, only for a restore). Constructed and handed to SaveManager during `initialize_saves`.
var _desktop_identity_allocation_participant: RefCounted = null
## The ONE production desktop board/consequence/causal graph (dwm-p2r.32 Plan 02 Task 9). Distinct
## identities from the retained .9-era simulator stack above; never shares state with it.
var _retained_desktop_publication_ledger: RefCounted = null
var _retained_desktop_causal_sequence_port: RefCounted = null
var _retained_desktop_board_fate_port: RefCounted = null
var _desktop_cold_recovery: RefCounted = null
var _desktop_cold_recovery_checked := false
var _retained_desktop_consequence_coordinator: RefCounted = null
## The Plan-02 application-level round coordinator (no class_name; preload by path). Its base
## The real generator and durable checkpoint path share the restored board owner.
var _retained_minesweeper_round_coordinator_app: RefCounted = null
var _retained_minesweeper_generation_port: RefCounted = null
var _retained_minesweeper_shop_purchase_participant: RefCounted = null
var _retained_game_state_desktop_board_port: RefCounted = null
var _retained_game_state_minesweeper_shop_port: RefCounted = null
var _retained_save_manager_desktop_board_port: RefCounted = null
## dwm-oyo.3 slice (2026-08-24): the Plan-03 condition-policy/ScheduleView pair configured together
## on the one shared consequence coordinator, the Schedule-Done consequence source that finishes
## DEVIATION-5, and the Done dispatch surface dwm-p2r.21 records as Plan 03's resolution.
var _retained_desktop_condition_context_port: RefCounted = null
var _retained_desktop_condition_policy_port: RefCounted = null
var _retained_schedule_departure_view_port: RefCounted = null
var _retained_desktop_consequence_source_port: RefCounted = null
var _retained_schedule_done_dispatcher: RefCounted = null
## Amendment Plan 03 Task 4 (dwm-oyo.3). Unlike every other restore participant, which is a fresh
## .new() per _configure_restore_participants() call, the schedule_view slot hands over these
## RETAINED objects: the controller behind the participant holds live day/view state that an
## identical startup replay must not silently reset.
var _retained_schedule_view_controller: RefCounted = null
var _retained_schedule_view_restore_participant: RefCounted = null
## Placeholder desktop identity context (dwm-p2r.32 Plan 02 Task 9). `GameStateDesktopBoardPort`/
## Stable reader of the activated run; no placeholder identity is minted at boot.
var _desktop_identity_provider := Callable()
var _state := {
	"started": false, "ready": false, "mode": &"",
	"completed_stages": [], "planned_blockers": [], "fatal_result": {}, "failed_stage": null,
	"gate_injection": {"factory_invocation_count": 0, "gate_instance_id": 0, "targets": [], "target_instance_ids": []},
}

func _ready() -> void:
	call_deferred("start", _requested_mode_from_debug_args())

func configure_debug_mutation_gate_factory(factory: Callable) -> Dictionary:
	if _start_begun: return _failure(&"debug_gate_factory_too_late", "Bootstrap start has begun")
	if _debug_gate_factory.is_valid(): return _failure(&"debug_gate_factory_already_configured", "A debug gate factory is already configured")
	if not factory.is_valid(): return _failure(&"invalid_debug_gate_factory", "Factory must be a valid Callable")
	var requested := _explicit_requested_mode()
	if not OS.is_debug_build() or requested not in DEVELOPMENT_STAGE_SETS or not _has_proven_test_root():
		return _failure(&"debug_gate_factory_forbidden", "Debug gate factory requires an explicit development mode and proven wrapper root")
	_debug_gate_factory = factory
	return {"ok": true, "code": &"ok", "value": {"configured": true}, "receipt": {}}

func start(mode: StringName = MODE_FINAL) -> Dictionary:
	if _started or _start_begun: return _failure(&"bootstrap_already_started", "ApplicationBootstrap starts exactly once")
	_start_begun = true
	_state["started"] = true
	_state["mode"] = mode
	if mode == MODE_TEST_MANUAL:
		_started = true
		return {"ok": true, "value": get_startup_state()}
	if mode != MODE_FINAL and mode not in DEVELOPMENT_STAGE_SETS:
		return _latch_startup_fatal(&"unknown_bootstrap_mode", "Unknown bootstrap mode")
	if mode != MODE_FINAL and (not OS.is_debug_build() or not _has_proven_test_root() or _explicit_requested_mode() != mode):
		return _latch_startup_fatal(&"development_mode_forbidden", "Development mode requires exact debug arguments and a proven root")
	var selected_stages: Array = STAGE_ORDER if mode == MODE_FINAL else DEVELOPMENT_STAGE_SETS[mode]
	for stage_id: StringName in STAGE_ORDER:
		if stage_id not in selected_stages:
			_state["planned_blockers"].append({"stage": stage_id, "code": &"planned_blocker"})
			continue
		var stage_result := _run_stage(stage_id, mode)
		if not stage_result.get("ok", false):
			return _record_startup_stage_failure(stage_id, stage_result)
		_state["completed_stages"].append(stage_id)
	_started = true
	if mode == MODE_FINAL:
		var published: Dictionary = _publish_startup_route_hold()
		if not published.get("ok", false):
			_state["completed_stages"].erase(&"publish_application_ready")
			return _record_startup_stage_failure(&"publish_application_ready", published)
		_state["ready"] = true
		application_ready.emit()
	else:
		development_subset_ready.emit(mode)
	return {"ok": true, "value": get_startup_state()}

func get_startup_state() -> Dictionary:
	return _state.duplicate(true)

func get_new_run_startup_recovery() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {
		"available": bool(_new_run_startup_recovery["available"]),
		"transaction_id": str(_new_run_startup_recovery["transaction_id"]),
	}}


func retry_new_run_startup(transaction_id: String) -> Dictionary:
	if _startup_recovery_busy:
		return _failure(&"new_run_startup_retry_busy", "Startup recovery is already running")
	if not bool(_new_run_startup_recovery["available"]):
		return _failure(&"new_run_startup_recovery_unavailable", "No retryable New Run startup failure is retained")
	if transaction_id.is_empty() or transaction_id != str(_new_run_startup_recovery["transaction_id"]):
		return _failure(&"invalid_new_run_startup_transaction", "The retained New Run transaction does not match")
	_startup_recovery_busy = true
	var result := _retry_new_run_startup(transaction_id)
	_startup_recovery_busy = false
	return result


func _retry_new_run_startup(transaction_id: String) -> Dictionary:
	var failed_stage: StringName = _new_run_startup_recovery["failed_stage"]
	if failed_stage == &"initialize_saves":
		var save_manager := _target(&"SaveManager")
		if save_manager == null or not save_manager.has_method("reconcile_new_run_storage"):
			return _record_startup_stage_failure(failed_stage,
				_failure(&"missing_stage_adapter", "New Acc startup recovery is unavailable"))
		var settled: Dictionary = save_manager.call(&"reconcile_new_run_storage")
		if not settled.get("ok", false):
			return _record_startup_retry_failure(failed_stage, transaction_id, settled)
		if failed_stage not in _state["completed_stages"]:
			_state["completed_stages"].append(failed_stage)
	return _continue_startup_after_recovery(failed_stage, transaction_id)


func _continue_startup_after_recovery(failed_stage: StringName, transaction_id: String) -> Dictionary:
	var reached_failure := false
	for stage_id: StringName in STAGE_ORDER:
		if stage_id == failed_stage:
			reached_failure = true
		if not reached_failure or stage_id in _state["completed_stages"]:
			continue
		var stage_result: Dictionary = _run_stage(stage_id, _state["mode"])
		if not stage_result.get("ok", false):
			return _record_startup_retry_failure(stage_id, transaction_id, stage_result)
		_state["completed_stages"].append(stage_id)
	var published: Dictionary = _publish_startup_route_hold()
	if not published.get("ok", false):
		_state["completed_stages"].erase(&"publish_application_ready")
		return _record_startup_retry_failure(&"publish_application_ready", transaction_id, published)
	_clear_new_run_startup_recovery()
	_state["fatal_result"] = {}
	_state["failed_stage"] = null
	_started = true
	if not bool(_state["ready"]):
		_state["ready"] = true
		application_ready.emit()
	return {"ok": true, "code": &"ok", "value": get_startup_state()}


func _record_startup_retry_failure(stage_id: StringName, transaction_id: String,
		result: Dictionary) -> Dictionary:
	if result.get("code") == &"NEW_RUN_RECOVERY_PENDING" 			and str(result.get("transaction_id", "")) != transaction_id:
		return _record_startup_stage_failure(stage_id,
			_failure(&"new_run_startup_transaction_changed",
				"Startup recovery returned a different transaction"))
	return _record_startup_stage_failure(stage_id, result)


func _record_startup_stage_failure(stage_id: StringName, result: Dictionary) -> Dictionary:
	var retained := result.duplicate(true)
	_state["fatal_result"] = retained
	_state["failed_stage"] = stage_id
	_started = true
	var qualifies: bool = _state["mode"] == MODE_FINAL 		and stage_id in [&"initialize_saves", &"publish_application_ready"] 		and retained.get("code") == &"NEW_RUN_RECOVERY_PENDING" 		and typeof(retained.get("transaction_id")) == TYPE_STRING 		and not str(retained["transaction_id"]).is_empty()
	if qualifies:
		_new_run_startup_recovery = {
			"available": true,
			"transaction_id": str(retained["transaction_id"]),
			"failed_stage": stage_id,
		}
		startup_recovery_changed.emit()
	else:
		var recovery_was_available: bool = bool(_new_run_startup_recovery["available"])
		_clear_new_run_startup_recovery()
		if not recovery_was_available:
			startup_recovery_changed.emit()
	return retained


func _clear_new_run_startup_recovery() -> void:
	var changed: bool = bool(_new_run_startup_recovery["available"])
	_new_run_startup_recovery = {
		"available": false, "transaction_id": "", "failed_stage": &"",
	}
	if changed:
		startup_recovery_changed.emit()


func _run_stage(stage_id: StringName, mode: StringName) -> Dictionary:
	match stage_id:
		&"select_and_prove_roots":
			return _select_and_prove_roots(mode)
		&"construct_and_inject_mutation_gate":
			return _construct_and_inject_mutation_gate(mode)
		&"construct_identity_issuer_and_contact_commands":
			return _construct_identity_issuer_and_contact_commands()
		&"initialize_profile":
			var manager := _target(&"ProfileManager")
			if manager == null or not manager.has_method("initialize"): return _failure(&"missing_profile_manager", "ProfileManager initializer is unavailable")
			return manager.call(&"initialize", _profile_storage)
		&"initialize_localization", &"initialize_input", &"initialize_accessibility", &"initialize_audio":
			var target_name := _stage_target(stage_id)
			var target := _target(target_name)
			var profile := _target(&"ProfileManager")
			if target == null or not target.has_method("initialize"): return _failure(&"missing_stage_adapter", "%s initializer is unavailable" % target_name)
			if profile == null: return _failure(&"missing_profile_manager", "ProfileManager dependency is unavailable")
			return target.call(&"initialize", profile)
		&"initialize_window_mode":
			var window := _target(&"WindowModeManager")
			var audio := _target(&"AudioManager")
			var profile := _target(&"ProfileManager")
			if window == null or audio == null or profile == null \
				or not window.has_method("initialize") or not audio.has_method("get_settings_output_transactions"):
				return _failure(&"missing_stage_adapter", "Window output requires Profile and shared Settings transactions")
			return window.initialize(profile, audio.get_settings_output_transactions())
		&"initialize_saves":
			var save_manager := _target(&"SaveManager")
			if save_manager == null or not save_manager.has_method("initialize"):
				return _failure(&"missing_stage_adapter", "SaveManager initializer is unavailable")
			var save_initialized: Dictionary = save_manager.call(&"initialize", JSON_STORAGE.new(_selected_root.path_join("saves")))
			if not save_initialized.get("ok", false):
				return save_initialized
			if save_manager.has_signal("live_session_ready") and not save_manager.is_connected("live_session_ready", _on_live_session_ready):
				save_manager.connect("live_session_ready", _on_live_session_ready)
			if _application_gate.has_signal("transaction_released") and not _application_gate.is_connected("transaction_released", _queue_live_continuation):
				_application_gate.connect("transaction_released", _queue_live_continuation)
			# Construct and retain the ONE real checkpoint port here; the narrative adapter and
			# the later configure_day_resolution stage reuse this exact instance.
			if _retained_checkpoint_port == null:
				_retained_checkpoint_port = SAVE_CHECKPOINT_PORT.new(save_manager)
				if _application_gate != null:
					var save_latched: Dictionary = _retained_checkpoint_port.configure_fatal_latch(_application_gate)
					if not save_latched.get("ok", false):
						return save_latched
				# dwm-p2r.32 Plan 02 Task 9: SaveManager needs the exact retained production issuer
				# for New Run/restore identity allocation and continuation reconciliation. The
				# identity issuer stage already ran (STAGE_ORDER position 3), so it exists here.
				if _desktop_identity_nonce_issuer != null:
					var save_issuer: Dictionary = save_manager.call(&"configure_identity_issuer",
						_desktop_identity_nonce_issuer)
					if not save_issuer.get("ok", false):
						return save_issuer
					if _desktop_identity_allocation_participant == null:
						_desktop_identity_allocation_participant = DESKTOP_IDENTITY_ALLOCATION_RESTORE_PARTICIPANT.new(
							_desktop_identity_nonce_issuer, save_manager)
					var save_allocation: Dictionary = save_manager.call(
						&"configure_identity_allocation_participant",
						_desktop_identity_allocation_participant)
					if not save_allocation.get("ok", false):
						return save_allocation
			# Settle a retained New Acc pair before Profile or any preference consumer
			# reads it. The later continuation pass still installs every live owner.
			var profile := _target(&"ProfileManager")
			if profile == null or not profile.has_method("configure_new_run_storage") \
					or not save_manager.has_method("configure_new_run_profile_owner") \
					or not save_manager.has_method("reconcile_new_run_storage"):
				return _failure(&"missing_stage_adapter", "New Acc startup recovery is unavailable")
			var profile_bound: Dictionary = profile.call(&"configure_new_run_storage", _profile_storage)
			if not profile_bound.get("ok", false): return profile_bound
			var recovery_bound: Dictionary = save_manager.call(&"configure_new_run_profile_owner", profile)
			if not recovery_bound.get("ok", false): return recovery_bound
			return save_manager.call(&"reconcile_new_run_storage")
		&"initialize_dialogic_bridge":
			var bridge := _target(&"DialogicBridge")
			var profile := _target(&"ProfileManager")
			if bridge == null or not bridge.has_method("bind_profile_preferences"): return _failure(&"missing_stage_adapter", "DialogicBridge preference binding is unavailable")
			if profile == null: return _failure(&"missing_profile_manager", "ProfileManager dependency is unavailable")
			var bound: Dictionary = bridge.call(&"bind_profile_preferences", profile)
			if not bound.get("ok", false):
				return bound
			# Narrative/ending wiring exists only where the save stage ran; the profile/locale
			# development subsets deliberately stop at preference binding.
			if _retained_checkpoint_port == null:
				return bound
			return _wire_narrative_and_ending_ports(bridge)
		&"publish_application_ready":
			var graph := _configure_desktop_production_graph()
			if not graph.get("ok", false):
				return graph
			var capture_bound: Dictionary = _target(&"SaveManager").configure_backup_capture_provider(_capture_backup_checkpoint_inputs, _admit_paused_desktop_backup)
			if not capture_bound.get("ok", false): return capture_bound
			var pause_router := _target(&"SceneRouter")
			if pause_router.has_signal("restore_publication_released") and not pause_router.is_connected("restore_publication_released", _queue_live_continuation):
				pause_router.connect("restore_publication_released", _queue_live_continuation)
			return pause_router.configure_pause_services({
				"game_state": _target(&"GameState"), "saves": _target(&"SaveManager"),
				"bridge": _target(&"DialogicBridge"), "input": _target(&"InputManager"),
				"audio": _target(&"AudioManager"), "gate": _application_gate,
				"profile": _target(&"ProfileManager"), "localization": _target(&"LocalizationManager"),
				"backup_capture": Callable(self, "_capture_paused_checkpoint_inputs"),
				"dating_presentation": _retained_dating_presentation_port})
		&"configure_restore_participants":
			return _configure_restore_participants()
		&"configure_day_resolution":
			var resolution_game_state := _target(&"GameState")
			var resolution_save_manager := _target(&"SaveManager")
			var resolution_result := configure_day_resolution(resolution_game_state, resolution_save_manager)
			if not resolution_result.get("ok", false):
				return resolution_result
			# Supply the Bootstrap-owned desktop host to the retained checkpoint port and connect
			# the day-change eviction handler exactly once (dwm-p2r.9 Plan 02 Task 1).
			if _retained_checkpoint_port != null and _desktop_host_state != null:
				var ctx: Dictionary = _retained_checkpoint_port.configure_desktop_context_provider(_desktop_host_state)
				if not ctx.get("ok", false):
					return ctx
			_connect_desktop_day_change(resolution_game_state)
			return resolution_result
		&"configure_minesweeper_rounds":
			return _configure_minesweeper_rounds(_target(&"GameState"), _target(&"SaveManager"))
		_:
			var target_name := _stage_target(stage_id)
			if target_name == &"": return _failure(&"missing_stage_adapter", "Stage adapter is not installed")
			var target := _target(target_name)
			if target == null or not target.has_method("initialize"): return _failure(&"missing_stage_adapter", "%s initializer is unavailable" % target_name)
			return target.call(&"initialize")

func _select_and_prove_roots(mode: StringName) -> Dictionary:
	if mode != MODE_FINAL:
		if not _has_proven_test_root(): return _failure(&"unproven_test_root", "Wrapper-owned test root was not proven")
		_selected_root = OS.get_environment("DWM_TEST_ROOT").simplify_path()
	else:
		_selected_root = ProjectSettings.globalize_path("user://").simplify_path()
	_profile_storage = JSON_STORAGE.new(_selected_root)
	return {"ok": true, "value": {"selected_root": _selected_root}}

func _create_production_mutation_gate() -> Object:
	return APPLICATION_MUTATION_GATE_SCRIPT.new()

func _construct_and_inject_mutation_gate(mode: StringName) -> Dictionary:
	var gate: Object
	var targets: Array
	if mode == MODE_FINAL:
		# The only final-mode resolution of Plan 02's missing_production_gate_factory:
		# construct the unchanged Task-3 gate once and inject the exact eight targets.
		_state["gate_injection"]["factory_invocation_count"] = 1
		gate = _create_production_mutation_gate()
		targets = FINAL_GATE_TARGETS
	else:
		if not _debug_gate_factory.is_valid(): return _failure(&"missing_debug_gate_factory", "Development mode requires its configured debug gate factory")
		_state["gate_injection"]["factory_invocation_count"] = 1
		var produced: Variant = _debug_gate_factory.call()
		if typeof(produced) != TYPE_OBJECT or produced == null: return _failure(&"invalid_mutation_gate", "Factory did not return an Object")
		gate = produced
		targets = DEVELOPMENT_GATE_TARGETS[mode]
	if not _is_compatible_gate(gate): return _failure(&"invalid_mutation_gate", "Factory returned an incompatible gate")
	_state["gate_injection"]["gate_instance_id"] = gate.get_instance_id()
	for target_name: StringName in targets:
		_state["gate_injection"]["targets"].append(target_name)
		var target := _target(target_name)
		if target == null or not target.has_method("configure_mutation_gate"): return _failure(&"invalid_gate_target", "Gate target is missing or incompatible: %s" % target_name)
		var configured: Dictionary = target.call(&"configure_mutation_gate", gate)
		if not configured.get("ok", false): return configured
		var retained_id: int = configured.get("value", {}).get("gate_instance_id", 0)
		_state["gate_injection"]["target_instance_ids"].append(retained_id)
		if retained_id != gate.get_instance_id(): return _failure(&"mutation_gate_identity_mismatch", "Target retained another gate")
	_application_gate = gate
	if mode == MODE_FINAL:
		var route_owner := _target(&"SceneRouter")
		if route_owner == null or not route_owner.has_method("begin_startup_route_hold") \
				or not route_owner.has_method("publish_startup_route_hold"):
			return _failure(&"missing_stage_adapter", "SceneRouter startup publication hold is unavailable")
		if _startup_route_owner != null and _startup_route_owner != route_owner:
			return _failure(&"startup_route_owner_mismatch", "SceneRouter startup publication owner changed")
		_startup_route_owner = route_owner
		if _startup_route_hold_token.is_empty():
			var held: Dictionary = route_owner.call(&"begin_startup_route_hold")
			if not held.get("ok", false) or typeof(held.get("value")) != TYPE_DICTIONARY \
					or typeof(held["value"].get("token")) != TYPE_STRING \
					or str(held["value"]["token"]).is_empty():
				return held if not held.get("ok", false) else _failure(
					&"invalid_startup_route_hold", "SceneRouter returned no startup hold token")
			_startup_route_hold_token = str(held["value"]["token"])
	return {"ok": true}


func _publish_startup_route_hold() -> Dictionary:
	if _startup_route_owner == null and _startup_route_hold_token.is_empty():
		# Focused stage harnesses may replace FINAL gate construction entirely.
		return {"ok": true, "code": &"ok", "value": {"published": false}}
	if _startup_route_owner == null or not is_instance_valid(_startup_route_owner) \
			or not _startup_route_owner.has_method("publish_startup_route_hold") \
			or _startup_route_hold_token.is_empty():
		return _failure(&"startup_route_hold_unavailable", "Retained SceneRouter startup hold is invalid")
	var published: Dictionary = _startup_route_owner.call(
		&"publish_startup_route_hold", _startup_route_hold_token)
	if not published.get("ok", false):
		return published
	_startup_route_hold_token = ""
	return published


func _construct_identity_issuer_and_contact_commands() -> Dictionary:
	if _profile_storage == null:
		return _failure(&"issuer_storage_unconfigured", "root selection did not retain profile storage")
	var game_state := _target(&"GameState")
	if game_state == null or not game_state.has_method("configure_identity_issuer"):
		return _failure(&"missing_stage_adapter", "GameState identity seam is unavailable")
	if _desktop_issuer_root_store == null:
		_desktop_issuer_root_store = DESKTOP_ISSUER_ROOT_STORE.new()
		# The issuer root reuses the exact root-scoped JsonFileStorage object already retained for
		# profile data. Selectable saves still receive their distinct `_selected_root/saves` adapter.
		var root_configured: Dictionary = _desktop_issuer_root_store.configure(
			_profile_storage, CRYPTO_DESKTOP_NAMESPACE_SOURCE.new())
		if not root_configured.get("ok", false):
			return root_configured
		var loaded: Dictionary = _desktop_issuer_root_store.load_or_create()
		if not loaded.get("ok", false):
			return loaded
	if _desktop_identity_nonce_issuer == null:
		_desktop_identity_nonce_issuer = DESKTOP_IDENTITY_NONCE_ISSUER.new()
		var issuer_configured: Dictionary = _desktop_identity_nonce_issuer.configure(
			_desktop_issuer_root_store)
		if not issuer_configured.get("ok", false):
			return issuer_configured
	var injected: Dictionary = game_state.call(
		&"configure_identity_issuer", _desktop_identity_nonce_issuer)
	if not injected.get("ok", false):
		return injected
	if int(injected.get("value", {}).get("issuer_instance_id", 0)) \
			!= _desktop_identity_nonce_issuer.get_instance_id():
		return _failure(&"identity_issuer_mismatch", "GameState retained another issuer")
	if _contact_command_port == null:
		_contact_command_port = CONTACT_COMMAND_PORT.new()
	var port_configured: Dictionary = _contact_command_port.configure(
		game_state, _desktop_identity_nonce_issuer)
	if not port_configured.get("ok", false):
		return port_configured
	if int(port_configured.get("value", {}).get("issuer_instance_id", 0)) \
			!= _desktop_identity_nonce_issuer.get_instance_id():
		return _failure(&"contact_command_identity_mismatch", "port retained another issuer")
	return {"ok": true, "code": &"ok", "value": {
		"root_store_instance_id": _desktop_issuer_root_store.get_instance_id(),
		"issuer_instance_id": _desktop_identity_nonce_issuer.get_instance_id(),
		"contact_command_port_instance_id": _contact_command_port.get_instance_id(),
		"game_state_instance_id": game_state.get_instance_id(),
	}, "receipt": {}}

## Builds the ONE narrative checkpoint adapter around the retained real port, injects that exact
## instance into DialogicBridge and GameState, then constructs the ONE ending playback port and
## injects it through SceneRouter (dwm-p2r.8, Plan-05 Task 2 Step 2.3). Any identity mismatch,
## missing method, or unready port is a fatal stage result: application_ready is not emitted.
func _wire_narrative_and_ending_ports(bridge: Object) -> Dictionary:
	var game_state := _target(&"GameState")
	var router := _target(&"SceneRouter")
	var audio := _target(&"AudioManager")
	if game_state == null or router == null or audio == null:
		return _failure(&"missing_stage_adapter", "Narrative wiring requires GameState, SceneRouter and AudioManager")
	for requirement in [[bridge, "initialize"], [bridge, "configure_narrative_checkpoint_port"],
			[bridge, "provide_transaction_narrative_checkpoint"], [game_state, "configure_narrative_checkpoint_port"],
			[game_state, "capture_run_snapshot_input"], [router, "configure_ending_ports"],
			[router, "is_ending_ports_configured"], [router, "get_current_route_id"],
			[audio, "get_semantic_audio_context"]]:
		if not (requirement[0] as Object).has_method(str(requirement[1])):
			return _failure(&"missing_stage_adapter", "Narrative wiring target is missing " + str(requirement[1]))
	# Bind the low-level runtime adapter to the installed Dialogic autoload when present.
	var runtime_adapter: RefCounted = null
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic != null:
		var candidate: RefCounted = DIALOGIC_RUNTIME_ADAPTER.new()
		if candidate.bind_runtime(dialogic).get("ok", false):
			runtime_adapter = candidate
	var initialized: Dictionary = bridge.call(&"initialize", DIALOGIC_TIMELINE_CATALOG, runtime_adapter)
	if not initialized.get("ok", false):
		return initialized
	if _narrative_checkpoint_adapter == null:
		_narrative_checkpoint_adapter = NARRATIVE_CHECKPOINT_PORT.new()
		var configured: Dictionary = _narrative_checkpoint_adapter.configure(_retained_checkpoint_port, {
			"snapshot_input": Callable(game_state, "capture_run_snapshot_input"),
			"narrative_checkpoint": Callable(bridge, "provide_transaction_narrative_checkpoint"),
			"route_id": Callable(router, "get_current_route_id"),
			"active_app_id": Callable(self, "_active_app_id_context"),
			"audio_context": Callable(audio, "get_semantic_audio_context"),
			"content_version": Callable(self, "_content_version_context"),
		})
		if not configured.get("ok", false):
			return configured
	var bridge_port: Dictionary = bridge.call(&"configure_narrative_checkpoint_port", _narrative_checkpoint_adapter)
	if not bridge_port.get("ok", false):
		return bridge_port
	var state_port: Dictionary = game_state.call(&"configure_narrative_checkpoint_port", _narrative_checkpoint_adapter)
	if not state_port.get("ok", false):
		return state_port
	var adapter_id := _narrative_checkpoint_adapter.get_instance_id()
	if int(bridge_port["value"]["port_instance_id"]) != adapter_id or int(state_port["value"]["port_instance_id"]) != adapter_id:
		return _failure(&"narrative_checkpoint_identity_mismatch", "A consumer retained another narrative adapter")
	if _ending_playback_port == null:
		_ending_playback_port = ENDING_PLAYBACK_PORT.new()
		var ending_initialized: Dictionary = _ending_playback_port.initialize(bridge)
		if not ending_initialized.get("ok", false):
			return ending_initialized
	var reached_bound: Dictionary = _ending_playback_port.configure_reached_presentations(
		_target(&"ProfileManager"), game_state.capture_ending_presentation_signature)
	if not reached_bound.get("ok", false): return reached_bound
	var ending_writer: Dictionary = game_state.call(&"configure_ending_checkpoint_writer",
		Callable(self, "_commit_ending_checkpoint"))
	if not ending_writer.get("ok", false):
		return ending_writer
	var routed: Dictionary = router.call(&"configure_ending_ports", game_state, _ending_playback_port)
	if not routed.get("ok", false):
		return routed
	if not _ending_playback_port.is_ready() or not router.call(&"is_ending_ports_configured"):
		return _failure(&"ending_ports_not_ready", "Ending ports did not report ready")
	return {"ok": true, "code": &"ok", "value": {
		"narrative_checkpoint_port_instance_id": adapter_id,
		"checkpoint_port_instance_id": _retained_checkpoint_port.get_instance_id(),
		"ending_playback_port_instance_id": _ending_playback_port.get_instance_id(),
	}, "receipt": {}}


## Injects the five non-GameState checkpoint providers into the day-resolution state port
## (dwm-7e6). Bound to the same stable sources the narrative checkpoint adapter uses, so both
## checkpoint paths report identical route/app/audio/content context.
func _configure_day_resolution_providers(state_port: Object) -> Dictionary:
	# Takes the RETAINED state port directly (Plan 01 Task 6 Step 6.5, dwm-p2r.13). It used to read
	# GameState's private `_day_resolution_coordinator` bag and then ask that coordinator to hand
	# back its state port; both of those reach-backs are gone, so this stage can no longer disagree
	# with the object the coordinator was actually configured with.
	if state_port == null or not state_port.has_method("configure_checkpoint_providers"):
		return _failure(&"missing_stage_adapter",
			"Day-resolution providers require the retained state port")
	var bridge := _target(&"DialogicBridge")
	var router := _target(&"SceneRouter")
	var audio := _target(&"AudioManager")
	if bridge == null or router == null or audio == null:
		return _failure(&"missing_stage_adapter", "Day-resolution providers require DialogicBridge, SceneRouter and AudioManager")
	for requirement in [[bridge, "get_current_narrative_checkpoint"], [router, "get_current_route_id"], [audio, "get_semantic_audio_context"]]:
		if not (requirement[0] as Object).has_method(str(requirement[1])):
			return _failure(&"missing_stage_adapter", "Day-resolution provider target is missing " + str(requirement[1]))
	# Built ONCE and retained, so the later Minesweeper stage configures its port with these exact
	# Callable identities rather than rebuilding a second, separately-bound bundle.
	if _checkpoint_provider_bundle.is_empty():
		_checkpoint_provider_bundle = {
			"dialogic_checkpoint": Callable(bridge, "get_current_narrative_checkpoint"),
			"route_id": Callable(router, "get_current_route_id"),
			"active_app_id": Callable(self, "_active_app_id_context"),
			"audio_context": Callable(audio, "get_semantic_audio_context"),
			"content_version": Callable(self, "_content_version_context"),
		}
	return state_port.call(&"configure_checkpoint_providers", _checkpoint_provider_bundle.duplicate())


## Stable private active-app context provider. Returns JSON null until the
## configure_restore_participants stage injects the Bootstrap-owned desktop host; that host is
## then read here without replacing this Callable's identity (dwm-p2r.9 Plan 02 Task 1).
func _active_app_id_context() -> Variant:
	if _desktop_host_state == null:
		return null
	return _desktop_host_state.capture_persistent_state().get("active_app_id", null)

## One pure desktop capture. Physical route readiness and narrative inactivity are
## required; a semantic route token or an old journal entry cannot stand in for them.
func _capture_backup_checkpoint_inputs() -> Dictionary:
	if not _state.get("ready", false) or _application_gate == null or _checkpoint_provider_bundle.is_empty():
		return _failure(&"backup_capture_unavailable", "Application owners are not ready")
	var guarded: Dictionary = _application_gate.guard_external(&"backup_capture")
	if not guarded.get("ok", false):
		return guarded
	var router := _target(&"SceneRouter")
	if router != null and (get_tree().paused or router.get_current_route_id() == "dating"):
		return router.capture_pause_backup_checkpoint_inputs()
	var scene := get_tree().current_scene
	var desktop: Object = _contacts_desktop_eviction_port.view.get_ref() if _contacts_desktop_eviction_port != null and _contacts_desktop_eviction_port.view != null else null
	if scene == null or scene.scene_file_path != "res://scenes/main/MainGameScene.tscn" or desktop == null or not scene.is_ancestor_of(desktop) or not desktop.is_visible_in_tree():
		return _failure(&"backup_capture_unavailable", "The in-run desktop is not ready")
	var bridge := _target(&"DialogicBridge")
	var game_state := _target(&"GameState")
	if bridge == null or game_state == null or bridge.has_active_playback() or not bridge.get_current_timeline_id().is_empty():
		return _failure(&"backup_capture_unavailable", "Narrative playback is active or unavailable")
	if _desktop_board_state == null or _desktop_consequence_state == null:
		return _failure(&"backup_capture_unavailable", "Desktop state owners are unavailable")
	var consequence: Dictionary = _desktop_consequence_state.capture()
	if not consequence.get("ok", false):
		return consequence
	var snapshot_input: Dictionary = game_state.capture_run_snapshot_input()
	# Keep the shared presentation draft alongside the live game state.
	snapshot_input["desktop"] = {"board": _desktop_board_state.capture(), "consequence": consequence["value"]["state"]}
	var schedule_view: Dictionary = _retained_schedule_view_controller.snapshot()
	if not schedule_view.get("ok", false): return schedule_view
	snapshot_input["schedule_view"] = schedule_view.value.view
	var inputs := {"snapshot_input": snapshot_input}
	for key in _checkpoint_provider_bundle:
		inputs[key] = (_checkpoint_provider_bundle[key] as Callable).call()
	if inputs["route_id"] != "main" or inputs["active_app_id"] != "backup" or not inputs["dialogic_checkpoint"].is_empty():
		return _failure(&"backup_capture_unavailable", "Backup is not the stable active desktop app")
	return {"ok": true, "value": inputs}


## SaveManager rechecks the actual retained Pause source rather than trusting a route flag.
func _admit_paused_desktop_backup(inputs: Dictionary) -> bool:
	var router := _target(&"SceneRouter")
	if router == null or inputs.get("route_id") != "main" or not get_tree().paused: return false
	var paused: Dictionary = router.capture_pause_backup_checkpoint_inputs()
	return paused.get("ok", false) and paused.value == inputs


## Called only after the retained Pause owner validates its exact paused source.
func _capture_paused_checkpoint_inputs() -> Dictionary:
	var bridge := _target(&"DialogicBridge")
	var game := _target(&"GameState")
	var router := _target(&"SceneRouter")
	if _retained_day_resolution_state_port == null or _retained_schedule_view_controller == null \
			or game == null or bridge == null or router == null:
		return _failure(&"backup_capture_unavailable", "Paused gameplay owners are unavailable")
	var route: String = router.get_current_route_id()
	if route not in ["main", "dating"] or bridge.has_active_playback() \
			or not bridge.get_current_timeline_id().is_empty():
		return _failure(&"backup_capture_unavailable", "The paused source is not at an idle gameplay boundary")
	var inputs: Dictionary = _retained_day_resolution_state_port._checkpoint_inputs(game._run_lifecycle.to_dict())
	var view: Dictionary = _retained_schedule_view_controller.snapshot()
	if not view.get("ok", false): return view
	if inputs.get("route_id") != route:
		return _failure(&"backup_capture_unavailable", "Paused route changed during capture")
	inputs.snapshot_input["schedule_view"] = view.value.view
	inputs["dialogic_checkpoint"] = {}
	return {"ok": true, "value": inputs}


## Mount the retained Contacts owners with explicitly provisional, replaceable copy.
func configure_contacts_desktop(desktop: Node) -> Dictionary:
	if not _state.get("ready", false) or _contact_command_port == null or _desktop_host_state == null:
		return _failure(&"contacts_owners_not_ready", "application owners are not ready")
	if desktop == null or not desktop.has_method("configure_contacts"):
		return _failure(&"invalid_contacts_desktop", "desktop presentation seam required")
	var game_state := _target(&"GameState")
	if _contacts_presentation_port == null:
		_contacts_presentation_port = CONTACTS_PRESENTATION_PORT.new()
		var configured: Dictionary = _contacts_presentation_port.configure(game_state, _contact_command_port, PROVISIONAL_CORRESPONDENCE.build())
		if not configured.get("ok", false):
			_contacts_presentation_port = null
			return configured
	if _contacts_desktop_eviction_port == null:
		_contacts_desktop_eviction_port = ContactsDesktopEvictionPort.new()
	var registered := register_desktop_eviction_port(_contacts_desktop_eviction_port)
	if not registered.get("ok", false):
		return registered
	# Restored Backup can query live capture synchronously while being mounted.
	# Bind first, including failed projections that still need owner eviction.
	_contacts_desktop_eviction_port.view = weakref(desktop)
	var mounted: Dictionary = desktop.configure_contacts(_contacts_presentation_port,
		_target(&"LocalizationManager"), _target(&"ProfileManager"),
		_desktop_host_state, int(game_state.day))
	return mounted


## UI ports live with their desktop scene; every one reads the same retained run owners.
func configure_gameplay_desktop(desktop: Node) -> Dictionary:
	if not _state.get("ready", false) or _retained_minesweeper_round_coordinator_app == null \
			or _retained_schedule_done_dispatcher == null:
		return _failure(&"gameplay_owners_not_ready", "gameplay owners are not ready")
	if desktop == null or not desktop.has_method("configure_minesweeper") or not desktop.has_method("configure_schedule") or not desktop.has_method("configure_shop"):
		return _failure(&"invalid_gameplay_desktop", "desktop gameplay seams required")
	if desktop.has_meta("gameplay_ports"): return {"ok": true}
	var game_state := _target(&"GameState")
	var admitted: Dictionary = game_state.validate_live_session(game_state.capture_live_session().value)
	if not admitted.get("ok", false): return admitted
	var locale := _target(&"LocalizationManager")
	var profile := _target(&"ProfileManager")
	var panel: RefCounted = MINESWEEPER_PANEL_PORT.new()
	var configured: Dictionary = panel.configure(_retained_minesweeper_round_coordinator_app,
		_desktop_identity_nonce_issuer, game_state, GAMEPLAY_DATA_CATALOG.new())
	if not configured.get("ok", false): return configured
	var fingerprint: String = _retained_schedule_registry.fingerprint()
	var registry: Dictionary = _retained_schedule_registry.snapshot(fingerprint)
	if not registry.get("ok", false): return registry
	var schedule: RefCounted = SCHEDULE_PRESENTATION.new()
	configured = schedule.configure(game_state, _retained_schedule_view_controller, _retained_schedule_registry,
		fingerprint, _desktop_identity_nonce_issuer, SCHEDULE_COPY.action_names(registry.value.records))
	if not configured.get("ok", false): return configured
	var context: RefCounted = SCHEDULE_WARNING_CONTEXT.new()
	configured = context.configure(game_state, _desktop_board_state)
	if not configured.get("ok", false): return configured
	var commands: RefCounted = SCHEDULE_COMMANDS.new()
	configured = commands.configure(_retained_schedule_view_controller, context, _desktop_identity_nonce_issuer,
		_retained_schedule_commit_port, _retained_schedule_done_dispatcher, fingerprint)
	if not configured.get("ok", false): return configured
	var warning: RefCounted = SCHEDULE_WARNING_PRESENTATION.new()
	configured = warning.configure(_retained_schedule_view_controller, SCHEDULE_COPY.warning_catalog())
	if not configured.get("ok", false): return configured
	var warning_commands: RefCounted = load("res://scripts/application/schedule/ScheduleWarningCommandPort.gd").new()
	configured = warning_commands.configure(_retained_schedule_view_controller, _desktop_identity_nonce_issuer, desktop)
	if not configured.get("ok", false): return configured
	configured = desktop.configure_minesweeper(panel, locale, profile, _desktop_host_state, int(game_state.day), _target(&"InputManager"))
	if not configured.get("ok", false): return configured
	configured = desktop.configure_schedule(schedule, locale, profile, _desktop_host_state, int(game_state.day),
		Callable(commands, "dispatch_done"), warning, warning_commands)
	if not configured.get("ok", false): return configured
	var shop: RefCounted = preload("res://scripts/application/shop/ShopPresentationPort.gd").new()
	configured = shop.configure(game_state, GAMEPLAY_DATA_CATALOG.new(),
		_retained_minesweeper_shop_purchase_participant, _retained_desktop_consequence_coordinator,
		_retained_minesweeper_round_coordinator_app, _desktop_identity_nonce_issuer, _application_gate)
	if not configured.get("ok", false): return configured
	configured = desktop.configure_shop(shop, locale, profile, _desktop_host_state, int(game_state.day))
	if not configured.get("ok", false): return configured
	desktop.set_meta("gameplay_ports", {"panel": panel, "schedule": schedule, "commands": commands,
		"warning": warning, "warning_commands": warning_commands, "shop": shop})
	return {"ok": true}


## Narrative manifest content version provider (positive integer, stable identity/arity).
func _content_version_context() -> int:
	return NARRATIVE_CONTENT_VERSION


func configure_day_resolution(game_state: Object, save_manager: Object) -> Dictionary:
	if _application_gate == null:
		return _failure(&"mutation_gate_not_configured", "Bootstrap has not constructed the application gate")
	if game_state == null or save_manager == null:
		return _failure(&"missing_stage_adapter", "Day-resolution wiring requires GameState and SaveManager")
	# Reuse the ONE port retained by initialize_saves; never construct a second instance.
	var checkpoint_port: RefCounted = _retained_checkpoint_port
	if checkpoint_port == null:
		checkpoint_port = SAVE_CHECKPOINT_PORT.new(save_manager)
		_retained_checkpoint_port = checkpoint_port
	var latched: Dictionary = checkpoint_port.configure_fatal_latch(_application_gate)
	if not latched.get("ok", false):
		return latched
	if int(latched["value"]["gate_instance_id"]) != _application_gate.get_instance_id():
		return _failure(&"mutation_gate_identity_mismatch", "Checkpoint port retained another gate")
	if not game_state.has_method("_install_day_resolution_runtime"):
		return _failure(&"missing_stage_adapter", "GameState day-resolution seam is unavailable")
	# Bootstrap OWNS construction (Plan 01 Task 6 Step 6.5, dwm-p2r.13): exactly one state port
	# against this GameState and exactly one coordinator, both retained here, configured through the
	# coordinator's sole three-owner seam, then handed to GameState as direct arguments. Identical
	# startup replay reuses these exact instances rather than building a second of either.
	if _retained_day_resolution_state_port == null:
		_retained_day_resolution_state_port = DAY_RESOLUTION_STATE_PORT.new(game_state)
	if _retained_day_resolution_coordinator == null:
		_retained_day_resolution_coordinator = DAY_RESOLUTION_COORDINATOR.new()
	var state_port: RefCounted = _retained_day_resolution_state_port
	var coordinator: RefCounted = _retained_day_resolution_coordinator
	if not coordinator.resolution_completed.is_connected(_on_day_resolution_completed):
		coordinator.resolution_completed.connect(_on_day_resolution_completed)
	var configured: Dictionary = coordinator.configure(state_port, checkpoint_port,
		_application_gate)
	if not configured.get("ok", false):
		return configured
	# The single shared advance-identity owner, injected through the coordinator's SEPARATE Task-7
	# seam so the frozen three-owner configure() signature above stays unchanged. Bootstrap alone
	# configures it; Plan 03 later composes this same retained object.
	var advance_identity := _configure_causal_day_advance_identity(coordinator)
	if not advance_identity.get("ok", false):
		return advance_identity
	var installed: Dictionary = game_state.call(&"_install_day_resolution_runtime", state_port,
		coordinator, checkpoint_port, _application_gate)
	if not installed.get("ok", false):
		return installed
	# Real snapshot production (dwm-7e6): the day-resolution state port needs the five
	# non-GameState checkpoint fields so the real checkpoint port accepts its bundle.
	var provided := _configure_day_resolution_providers(state_port)
	if not provided.get("ok", false):
		return provided
	var ending_source: Dictionary = game_state.configure_ending_source_reader(
		Callable(state_port, "prepare_terminal_ending_source"))
	if not ending_source.get("ok", false): return ending_source
	var foundation := _construct_schedule_foundation(game_state, state_port)
	if not foundation.get("ok", false):
		return foundation
	# Task 8 (dwm-p2r.14): the presentation ports are composed on the EXACT coordinator above, after
	# the foundation, so no foundation instance is reconstructed and no probe id changes.
	var presentation := _construct_schedule_presentation(coordinator)
	if not presentation.get("ok", false):
		return presentation
	return {"ok": true, "value": {"gate_instance_id": _application_gate.get_instance_id()}}


## Composes the ONE narrative presentation owner and the TWO presentation ports (Plan 01 Task 8
## Step 8.6, dwm-p2r.14).
##
## HOSPITAL IS READY. Exactly one `DialogicPresentationOwnerAdapter` is constructed against the
## existing `DialogicBridge` and the retained production issuer, one Hospital port is configured with
## it, and the coordinator connects that exact port's completion signals once.
##
## Dating retains one port here. The late desktop graph binds its physical board owner after
## the shared generation port is available. Before that binding, Dating admission remains closed.
## Historical Phase-2R setup deferred this owner; the whole-game integration now supplies it.
##
## Identical startup replay reuses these exact instances rather than building a second of any of
## them, so the ports' own replacement guards are never tripped by a legitimate re-run.
func _construct_schedule_presentation(coordinator: RefCounted) -> Dictionary:
	if _desktop_identity_nonce_issuer == null:
		return _failure(&"missing_identity_issuer",
			"the presentation ports require the retained production issuer")
	var bridge := _target(&"DialogicBridge")
	if bridge == null:
		return _failure(&"missing_stage_adapter",
			"the narrative presentation owner requires DialogicBridge")
	if _retained_presentation_owner_adapter == null:
		var adapter: RefCounted = DIALOGIC_PRESENTATION_OWNER_ADAPTER.new()
		var bound: Dictionary = adapter.configure(bridge)
		if not bound.get("ok", false):
			return bound
		_retained_presentation_owner_adapter = adapter
	if _retained_hospital_presentation_port == null:
		var hospital: RefCounted = HOSPITAL_PRESENTATION_PORT.new()
		var configured: Dictionary = hospital.configure(_desktop_identity_nonce_issuer,
			_retained_presentation_owner_adapter)
		if not configured.get("ok", false):
			return configured
		if int((configured.get("value", {}) as Dictionary).get("owner_instance_id", 0)) \
				!= _retained_presentation_owner_adapter.get_instance_id():
			return _failure(&"presentation_owner_identity_mismatch",
				"the Hospital port retained another owner")
		_retained_hospital_presentation_port = hospital
	if _retained_dating_presentation_port == null:
		# The late graph supplies the shared physical generation owner.
		_retained_dating_presentation_port = DATING_PRESENTATION_PORT.new()
	var injected: Dictionary = coordinator.configure_presentation_ports(
		_retained_hospital_presentation_port, _retained_dating_presentation_port)
	if not injected.get("ok", false):
		return injected
	var router := _target(&"SceneRouter")
	if router != null and router.has_method("configure_schedule_presentation_ports"):
		var routed: Dictionary = router.call(&"configure_schedule_presentation_ports",
			_retained_hospital_presentation_port, _retained_dating_presentation_port)
		if not routed.get("ok", false):
			return routed
		# dwm-p2r.18: the SAME router the ports were just injected into becomes the coordinator's
		# route surface, so a paused presentation is actually LAUNCHED rather than merely awaited.
		# One object serves both roles deliberately -- a second router would show a scene holding
		# ports this coordinator never adopted.
		var dispatched: Dictionary = coordinator.configure_presentation_router(router)
		if not dispatched.get("ok", false):
			return dispatched
	return {"ok": true, "code": &"ok", "value": {
		"hospital_ready": bool(_retained_hospital_presentation_port.call(&"is_ready")),
		"dating_ready": bool(_retained_dating_presentation_port.call(&"is_ready")),
	}, "receipt": {}}


## Read-only same-boot identity probe for the retained Schedule/desktop foundation (Plan 01 Task 8
## Step 8.1, dwm-p2r.14).
##
## It returns INTEGERS ONLY -- never an Object -- so reading it can never hand a caller a live owner.
## Its purpose is to let a test capture the foundation before presentation configuration and prove
## every instance is the SAME one afterwards, catching a reconstructed, swapped, or faked dependency
## before readiness.
##
## THESE NUMBERS ARE PROCESS-LOCAL. They are meaningless across runs and must never be compared to a
## prior run or to a committed evidence file; only to another reading from this same boot.
func get_desktop_contract_state() -> Dictionary:
	var state := {
		"root_store_instance_id": _instance_id(_desktop_issuer_root_store),
		"issuer_instance_id": _instance_id(_desktop_identity_nonce_issuer),
		"contact_command_port_instance_id": _instance_id(_contact_command_port),
		"schedule_registry_instance_id": _instance_id(_retained_schedule_registry),
		"publication_ledger_instance_id": _instance_id(_retained_publication_ledger),
		"schedule_port_instance_id": _instance_id(_retained_schedule_commit_port),
		"day_resolution_start_port_instance_id": _instance_id(_retained_day_resolution_start_port),
		"provenance_owner_instance_id": _instance_id(_retained_day7_provenance),
		"day_resolution_state_port_instance_id": _instance_id(_retained_day_resolution_state_port),
		"day_resolution_coordinator_instance_id": _instance_id(_retained_day_resolution_coordinator),
		"causal_day_advance_identity_port_instance_id":
			_instance_id(_retained_causal_day_advance_identity_port),
		"presentation_owner_adapter_instance_id": _instance_id(_retained_presentation_owner_adapter),
		"hospital_presentation_port_instance_id": _instance_id(_retained_hospital_presentation_port),
		"dating_presentation_port_instance_id": _instance_id(_retained_dating_presentation_port),
		"hospital_presentation_ready": _retained_hospital_presentation_port != null \
			and bool(_retained_hospital_presentation_port.call(&"is_ready")),
		# Deliberately false in Phase 2R; dwm-oyo.4 flips it by configuring the retained port.
		"dating_presentation_ready": _retained_dating_presentation_port != null \
			and bool(_retained_dating_presentation_port.call(&"is_ready")),
		# False until the desktop-graph stage composes the consequence source (dwm-oyo.3 slice,
		# 2026-08-24, finishing DEVIATION-5); before that stage the gap stays visible in evidence
		# rather than surfacing as a stage that quietly presents nothing.
		"presentation_producer_ready": _retained_day_resolution_state_port != null 			and _retained_day_resolution_state_port.has_method("is_presentation_producer_ready") 			and bool(_retained_day_resolution_state_port.call(&"is_presentation_producer_ready")),
	}
	state.merge(_desktop_amendment_probe_fields())
	return state


## The Plan-02 Task-9 desktop-amendment probe subset. Kept in its own function so
## `get_desktop_contract_state()`'s original Plan-01 Task-8 fields above stay byte-for-byte
## unchanged. Every value here is an int/bool/String/Array/Dictionary of the same -- never a live
## Object -- matching the parent probe's own law.
func _desktop_amendment_probe_fields() -> Dictionary:
	var save_manager := _target(&"SaveManager")
	var game_state := _target(&"GameState")
	var continuation_journal: Object = save_manager.get("_continuation_journal") if save_manager != null else null
	var restore_participant_ids := {
		"identity_allocation": _instance_id(_desktop_identity_allocation_participant),
	}
	for key: String in ["run", "desktop_consequence", "desktop_board", "schedule_view", "profile",
			"localization", "audio", "route", "narrative"]:
		restore_participant_ids[key] = _instance_id(
			_retained_restore_participants.get(key) if _retained_restore_participants.has(key) else null)
	# TRUE once these six desktop-graph objects are retained (non-null) -- a CONSTRUCTION check
	# only, not a usability check. It does NOT mean the desktop contract can be exercised:
	# `MinesweeperRoundCoordinator`'s own base `configure()` is never called, the identity context
	# `GameStateDesktopBoardPort`/`GameStateMinesweeperShopPort` carry is a boot-time placeholder,
	# and no `LogoutCoordinator` is constructed -- see `_configure_desktop_production_graph()`'s
	# own "HONEST SCOPE, DOCUMENTED" comment above for the complete list of gaps this flag is
	# silent on. Named `desktop_graph_constructed`, not `..._ready`, precisely so a downstream
	# reader does not conclude the desktop contract is usable from this field alone.
	var desktop_graph_constructed := _retained_desktop_publication_ledger != null \
		and _retained_desktop_causal_sequence_port != null \
		and _retained_desktop_board_fate_port != null \
		and _retained_desktop_consequence_coordinator != null \
		and _retained_minesweeper_round_coordinator_app != null \
		and _retained_minesweeper_shop_purchase_participant != null
	return {
		"mutation_gate_instance_id": _instance_id(_application_gate),
		"continuation_journal_instance_id": _instance_id(continuation_journal),
		"desktop_publication_ledger_instance_id": _instance_id(_retained_desktop_publication_ledger),
		"host_instance_id": _instance_id(_desktop_host_state),
		"board_state_instance_id": _instance_id(_desktop_board_state),
		"consequence_state_instance_id": _instance_id(_desktop_consequence_state),
		"causal_sequence_port_instance_id": _instance_id(_retained_desktop_causal_sequence_port),
		"admission_checkpoint_port_instance_id": _instance_id(_retained_checkpoint_port),
		"board_fate_port_instance_id": _instance_id(_retained_desktop_board_fate_port),
		"minesweeper_round_source_port_instance_id": _instance_id(_retained_minesweeper_round_coordinator_app),
		"shop_purchase_source_port_instance_id": _instance_id(_retained_minesweeper_shop_purchase_participant),
		"consequence_coordinator_instance_id": _instance_id(_retained_desktop_consequence_coordinator),
		"game_state_desktop_board_port_instance_id": _instance_id(_retained_game_state_desktop_board_port),
		"game_state_minesweeper_shop_port_instance_id": _instance_id(_retained_game_state_minesweeper_shop_port),
		"save_manager_desktop_board_port_instance_id": _instance_id(_retained_save_manager_desktop_board_port),
		"snapshot_provider_instance_id": _instance_id(game_state),
		"restore_order": _RESTORE_ORDER.duplicate(),
		"restore_participant_instance_ids": restore_participant_ids,
		"run_snapshot_schema_version": RUN_SNAPSHOT_SCHEMA_VERSION,
		"save_document_schema_version": SAVE_DOCUMENT_SCHEMA_VERSION,
		"registry_versions": {"minesweeper_shop": MINESWEEPER_SHOP_REGISTRY.REGISTRY_VERSION},
		"desktop_graph_constructed": desktop_graph_constructed,
		# Still false: the destination-outbox dispatcher (hospital_day / day7_terminal consumers)
		# remains Plan-03 Task-7 work outside the dwm-oyo.3 slice.
		"destination_composition_ready": false,
		# dwm-oyo.3 slice (2026-08-24): the condition pair, consequence source, and Done dispatcher.
		"condition_context_port_instance_id": _instance_id(_retained_desktop_condition_context_port),
		"condition_policy_port_instance_id": _instance_id(_retained_desktop_condition_policy_port),
		"schedule_departure_view_port_instance_id": _instance_id(_retained_schedule_departure_view_port),
		"desktop_consequence_source_port_instance_id": _instance_id(_retained_desktop_consequence_source_port),
		"schedule_done_dispatcher_instance_id": _instance_id(_retained_schedule_done_dispatcher),
	}


static func _instance_id(retained: Object) -> int:
	return retained.get_instance_id() if retained != null else 0


## Constructs and configures exactly one CausalDayAdvanceIdentityPort against the retained
## production identity issuer, then injects it into the coordinator. Identical startup replay
## reuses the same instance rather than building a second one, so the coordinator's replacement
## guard is never tripped by a legitimate re-run.
func _configure_causal_day_advance_identity(coordinator: RefCounted) -> Dictionary:
	if _desktop_identity_nonce_issuer == null:
		return _failure(&"missing_identity_issuer",
			"the causal day advance identity port requires the retained production issuer")
	if _retained_causal_day_advance_identity_port == null:
		_retained_causal_day_advance_identity_port = CAUSAL_DAY_ADVANCE_IDENTITY_PORT.new()
		var issuer_bound: Dictionary = _retained_causal_day_advance_identity_port.configure(
			_desktop_identity_nonce_issuer)
		if not issuer_bound.get("ok", false):
			_retained_causal_day_advance_identity_port = null
			return issuer_bound
	return coordinator.configure_day_advance_identity_port(
		_retained_causal_day_advance_identity_port)


## Amendment Plan 03 Task 4 (dwm-oyo.3), Step 6. Constructs EXACTLY ONE ScheduleViewController and
## EXACTLY ONE ScheduleViewRestoreParticipant around it, over the retained Schedule registry, the
## retained Plan-02 issuer, and the existing static DesktopContinuationRemapper. Each object is built
## only while still null, so identical startup replay reuses these exact instances: the retained
## controller holds live day/view state a second construction would silently reset (the same law
## `_desktop_host_state` obeys; ScheduleViewController.configure() itself has no replacement guard).
##
## THE REGISTRY IS LOADED HERE, not in the later `configure_day_resolution` stage: SaveManager needs
## all nine participants at once during `configure_restore_participants` (STAGE_ORDER index 10) and
## `ScheduleViewController.configure()` refuses a blank fingerprint. `_construct_schedule_foundation()`
## keeps its own `if _retained_schedule_registry == null` guard, so the later stage adopts this exact
## registry object and `schedule_registry_instance_id` in the probe never changes.
func _configure_schedule_view_participant() -> Dictionary:
	if _desktop_identity_nonce_issuer == null:
		return _failure(&"missing_identity_issuer",
			"the ScheduleView participant requires the retained production issuer")
	if _retained_schedule_registry == null:
		var loaded: Dictionary = SCHEDULE_ACTION_REGISTRY.load_current()
		if not loaded.get("ok", false):
			return loaded
		_retained_schedule_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	if _retained_schedule_view_controller == null:
		var controller: RefCounted = SCHEDULE_VIEW_CONTROLLER.new()
		var configured: Dictionary = controller.configure(_retained_schedule_registry, SCHEDULE_RULES,
			str(_retained_schedule_registry.fingerprint()))
		if not configured.get("ok", false):
			return configured
		var warning_identity: Dictionary = controller.configure_warning_identity(
			_desktop_identity_nonce_issuer)
		if not warning_identity.get("ok", false):
			return warning_identity
		_retained_schedule_view_controller = controller
	if _retained_schedule_view_restore_participant == null:
		_retained_schedule_view_restore_participant = SCHEDULE_VIEW_RESTORE_PARTICIPANT.new(
			_retained_schedule_view_controller, _retained_schedule_registry,
			_desktop_identity_nonce_issuer, CONTINUATION_REMAPPER)
	return {"ok": true, "code": &"ok", "value": {
		"controller_instance_id": _retained_schedule_view_controller.get_instance_id(),
		"participant_instance_id": _retained_schedule_view_restore_participant.get_instance_id(),
		"registry_fingerprint": str(_retained_schedule_registry.fingerprint()),
	}, "receipt": {}}


## Builds the nine production live restore participants, constructs the ONE Bootstrap-owned desktop
## host, wires it into the route participant, and hands the full set to SaveManager. Runs exactly
## once (each participant is built only while still null) so identical startup replay is safe
## (dwm-p2r.9 Plan 02 Task 1). Every slot but one is a fresh `.new()` per call, safe because
## SaveManager only ever retains the newest dict; the `schedule_view` slot alone hands over the
## RETAINED participant built by _configure_schedule_view_participant(), because the controller
## behind it holds live day/view state that a replay must not silently reset (Amendment Plan 03
## Task 4, dwm-oyo.3).
func _configure_restore_participants() -> Dictionary:
	var save_manager := _target(&"SaveManager")
	var game_state := _target(&"GameState")
	var profile := _target(&"ProfileManager")
	var localization := _target(&"LocalizationManager")
	var audio := _target(&"AudioManager")
	var router := _target(&"SceneRouter")
	var bridge := _target(&"DialogicBridge")
	var window := _target(&"WindowModeManager")
	if save_manager == null or game_state == null or profile == null or localization == null \
			or audio == null or router == null or bridge == null:
		return _failure(&"missing_stage_adapter", "Restore participants require all target managers")
	if window == null or not window.has_method("get_settings_window_capability") \
		or not window.has_method("is_output_initialized") or not window.is_output_initialized() \
		or not window.has_method("get_settings_output_transactions") or not audio.has_method("get_settings_output_transactions") \
		or window.get_settings_output_transactions() != audio.get_settings_output_transactions():
		return _failure(&"missing_stage_adapter", "Window output must share the initialized Settings transaction owner")
	var window_capability: Variant = window.get_settings_window_capability()
	if typeof(window_capability) != TYPE_DICTIONARY or not window_capability.get("ok", false) \
		or typeof(window_capability.get("value")) != TYPE_DICTIONARY \
		or typeof(window_capability.value.get("available")) != TYPE_BOOL:
		return _failure(&"missing_stage_adapter", "Window output capability is malformed")
	if _desktop_host_state == null:
		_desktop_host_state = DESKTOP_APP_HOST_STATE.new()
		var day: int = 1
		if game_state.get("day") != null:
			day = int(game_state.get("day"))
		_desktop_host_state.reset(day)
	var route_participant: RefCounted = ROUTE_RESTORE_PARTICIPANT.new(router)
	var host_configured: Dictionary = route_participant.configure_desktop_host(_desktop_host_state)
	if not host_configured.get("ok", false):
		return host_configured
	if _desktop_consequence_state == null:
		_desktop_consequence_state = DESKTOP_CONSEQUENCE_STATE.new()
	if _desktop_board_state == null:
		_desktop_board_state = DESKTOP_BOARD_STATE.new()
	var view_configured: Dictionary = _configure_schedule_view_participant()
	if not view_configured.get("ok", false):
		return view_configured
	var participants := {
		"run": RUN_RESTORE_PARTICIPANT.new(game_state),
		"desktop_consequence": DESKTOP_CONSEQUENCE_RESTORE_PARTICIPANT.new(_desktop_consequence_state),
		"desktop_board": DESKTOP_BOARD_RESTORE_PARTICIPANT.new(_desktop_board_state),
		"schedule_view": _retained_schedule_view_restore_participant,
		"profile": PROFILE_RESTORE_PARTICIPANT.new(profile),
		"localization": LOCALIZATION_RESTORE_PARTICIPANT.new(localization),
		"audio": AUDIO_RESTORE_PARTICIPANT.new(audio),
		"route": route_participant,
		"narrative": NARRATIVE_RESTORE_PARTICIPANT.new(bridge),
	}
	# A headless process has no native window to capture or restore. Its explicit
	# unavailable capability is retained; it supplies no window acceptance evidence.
	if window_capability.value.available:
		var configured_window: Dictionary = participants.profile.configure_window_output(window)
		if not configured_window.get("ok", false): return configured_window
	var configured: Dictionary = save_manager.call(&"configure_restore_participants", participants)
	if configured.get("ok", false):
		_retained_restore_participants = participants.duplicate()
	return configured


## Composes the retained board, consequence, Schedule, and checkpoint owners.
## Only the application coordinator is mounted into the desktop. The earlier
## simulator facade remains unexposed while its remaining callers are reconciled.
func _configure_desktop_production_graph() -> Dictionary:
	if _application_gate == null:
		return _failure(&"mutation_gate_not_configured", "Bootstrap has not constructed the application gate")
	if _desktop_identity_nonce_issuer == null or _profile_storage == null:
		return _failure(&"missing_stage_adapter", "the desktop production graph requires the retained issuer and root storage")
	if _desktop_host_state == null or _desktop_board_state == null or _desktop_consequence_state == null:
		return _failure(&"missing_stage_adapter", "the desktop production graph requires the retained host/board/consequence state")
	if _retained_checkpoint_port == null:
		return _failure(&"missing_stage_adapter", "the desktop production graph requires the retained checkpoint port")
	var game_state := _target(&"GameState")
	if game_state == null:
		return _failure(&"missing_stage_adapter", "the desktop production graph requires GameState")

	var reward_gate: Dictionary = game_state.configure_mutation_gate(_application_gate)
	if not reward_gate.get("ok", false): return reward_gate
	if _retained_minesweeper_state_port == null:
		_retained_minesweeper_state_port = MINESWEEPER_STATE_PORT.new(game_state)
	var reward_configured: Dictionary = _retained_minesweeper_state_port.configure(_application_gate)
	if not reward_configured.get("ok", false): return reward_configured

	var snapshot_bound: Dictionary = game_state.configure_desktop_snapshot_provider(Callable(self, "_capture_live_desktop_snapshot"))
	if not snapshot_bound.get("ok", false): return snapshot_bound

	# One distinct root-scoped desktop publication ledger, loaded before any recovery/publish call.
	if _retained_desktop_publication_ledger == null:
		var ledger: RefCounted = DESKTOP_PUBLICATION_LEDGER.new()
		var ledger_configured: Dictionary = ledger.configure(_profile_storage)
		if not ledger_configured.get("ok", false):
			return ledger_configured
		var ledger_loaded: Dictionary = ledger.load()
		if not ledger_loaded.get("ok", false):
			return ledger_loaded
		_retained_desktop_publication_ledger = ledger
	var ledger: RefCounted = _retained_desktop_publication_ledger

	# Reconcile the external New-Run/restore continuation journal before any run mutation is enabled
	# (frozen contract: "reconciles the external operation journal ... before enabling any run
	# mutation"). SaveManager's own issuer/identity-allocation participant were configured during
	# initialize_saves; this is a pure reconciliation pass over any incomplete operation.
	var save_manager := _target(&"SaveManager")
	if save_manager != null and save_manager.has_method("reconcile_incomplete_continuations"):
		var reconciled: Dictionary = save_manager.call(&"reconcile_incomplete_continuations")
		if not reconciled.get("ok", false):
			return reconciled

	if _desktop_identity_provider.is_null():
		_desktop_identity_provider = Callable(game_state, "capture_desktop_identity_context")
	if not _desktop_identity_provider.is_valid():
		return _failure(&"desktop_identity_unavailable", "GameState live identity is required")

	# Every command captures the currently activated run through the same stable reader.
	if _retained_game_state_desktop_board_port == null:
		var board_port: RefCounted = GAME_STATE_DESKTOP_BOARD_PORT.new()
		var board_port_configured: Dictionary = board_port.configure(
			game_state, _desktop_identity_nonce_issuer, _desktop_identity_provider)
		if not board_port_configured.get("ok", false):
			return board_port_configured
		_retained_game_state_desktop_board_port = board_port
	var board_consequence: Dictionary = _retained_game_state_desktop_board_port.configure_consequence_state_port(_desktop_consequence_state)
	if not board_consequence.get("ok", false): return board_consequence
	if _retained_game_state_minesweeper_shop_port == null:
		var shop_port: RefCounted = GAME_STATE_MINESWEEPER_SHOP_PORT.new()
		var shop_port_configured: Dictionary = shop_port.configure(
			game_state, _desktop_identity_provider)
		if not shop_port_configured.get("ok", false):
			return shop_port_configured
		_retained_game_state_minesweeper_shop_port = shop_port

	# The Plan-02 application-level round coordinator adopts Bootstrap's ALREADY-shared board state
	# (constructed by _configure_restore_participants and wrapped by DesktopBoardRestoreParticipant)
	# instead of the empty one its own _init() constructs, so DesktopBoardFatePort, the restore
	# participant, and this coordinator all drive the exact same live object (Task 8's own documented
	# concern: "the SAME direct-property-access pattern Task 6's own restore tests already
	# established for this exact wiring gap"). Done immediately after construction, before anything
	# else touches the coordinator's board.
	if _retained_minesweeper_round_coordinator_app == null:
		var round_coordinator: RefCounted = MINESWEEPER_ROUND_COORDINATOR_APP.new()
		round_coordinator.set("_board_state", _desktop_board_state)
		var round_ledger: Dictionary = round_coordinator.configure_publication_ledger(ledger)
		if not round_ledger.get("ok", false):
			return round_ledger
		# Install durable checkpoint capability before enabling the generation path.
		var save_board_port: RefCounted = SAVE_MANAGER_DESKTOP_BOARD_PORT.new(_retained_checkpoint_port)
		var save_board_configured: Dictionary = save_board_port.configure(_retained_checkpoint_port)
		if not save_board_configured.get("ok", false):
			return save_board_configured
		_retained_save_manager_desktop_board_port = save_board_port
		var durable: Dictionary = round_coordinator.configure_durable_checkpoint(
			save_board_port, DESKTOP_FIRST_REVEAL_SNAPSHOT_COMPOSER, _desktop_consequence_state)
		if not durable.get("ok", false):
			return durable
		_retained_minesweeper_generation_port = MINESWEEPER_GENERATION_PORT.new()
		var playable: Dictionary = round_coordinator.configure(_retained_game_state_desktop_board_port,
			save_board_port, _retained_minesweeper_generation_port, _desktop_identity_nonce_issuer)
		if not playable.get("ok", false): return playable
		_retained_minesweeper_round_coordinator_app = round_coordinator

	# The Shop purchase participant, over the real economy port, consequence state, and checkpoint.
	if _retained_minesweeper_shop_purchase_participant == null:
		# The registry is a static loader, never wired into any existing boot stage; load it here.
		var registry_loaded: Dictionary = MINESWEEPER_SHOP_REGISTRY.initialize()
		if not registry_loaded.get("ok", false):
			return registry_loaded
		var shop_participant: RefCounted = MINESWEEPER_SHOP_PURCHASE_PARTICIPANT.new()
		var shop_ledger: Dictionary = shop_participant.configure_publication_ledger(ledger)
		if not shop_ledger.get("ok", false):
			return shop_ledger
		var shop_configured: Dictionary = shop_participant.configure(
			_retained_game_state_minesweeper_shop_port, _desktop_consequence_state,
			_retained_checkpoint_port, MINESWEEPER_SHOP_REGISTRY, _desktop_identity_nonce_issuer,
			_application_gate)
		if not shop_configured.get("ok", false):
			return shop_configured
		var catalog_configured: Dictionary = shop_participant.configure_catalog(GAMEPLAY_DATA_CATALOG.new(),
			Callable(self, "_capture_completed_consequence_checkpoint_inputs"))
		if not catalog_configured.get("ok", false): return catalog_configured
		_retained_minesweeper_shop_purchase_participant = shop_participant

	# The board-fate port, over the EXACT same shared board state.
	if _retained_desktop_board_fate_port == null:
		var board_fate_port: RefCounted = DESKTOP_BOARD_FATE_PORT.new()
		var board_fate_ledger: Dictionary = board_fate_port.configure_publication_ledger(ledger)
		if not board_fate_ledger.get("ok", false):
			return board_fate_ledger
		var board_fate_configured: Dictionary = board_fate_port.configure(
			_desktop_board_state, _desktop_identity_nonce_issuer)
		if not board_fate_configured.get("ok", false):
			return board_fate_configured
		_retained_desktop_board_fate_port = board_fate_port

	# The shared causal-sequence admission port, over the real consequence state, gate, and checkpoint.
	if _retained_desktop_causal_sequence_port == null:
		var causal_port: RefCounted = DESKTOP_CAUSAL_SEQUENCE_PORT.new()
		var causal_ledger: Dictionary = causal_port.configure_publication_ledger(ledger)
		if not causal_ledger.get("ok", false):
			return causal_ledger
		var causal_configured: Dictionary = causal_port.configure(
			_desktop_consequence_state, _application_gate, _retained_checkpoint_port)
		if not causal_configured.get("ok", false):
			return causal_configured
		_retained_desktop_causal_sequence_port = causal_port

	# The consequence coordinator: consequence state, causal port, board-fate port, checkpoint port,
	# gate, then the exact retained Round/Shop action sources, then the identity issuer. The
	# production condition-policy/ScheduleView pair is configured together BELOW (dwm-oyo.3 slice,
	# 2026-08-24) with Plan 03's real ports -- never a fake, exactly as the brief demanded while the
	# real ports did not exist.
	if _retained_desktop_consequence_coordinator == null:
		var coordinator: RefCounted = DESKTOP_CONSEQUENCE_COORDINATOR.new()
		var coordinator_configured: Dictionary = coordinator.configure(
			_desktop_consequence_state, _retained_desktop_causal_sequence_port,
			_retained_desktop_board_fate_port, _retained_checkpoint_port, _application_gate)
		if not coordinator_configured.get("ok", false):
			return coordinator_configured
		var sources_configured: Dictionary = coordinator.configure_action_source_ports(
			_retained_minesweeper_round_coordinator_app, _retained_minesweeper_shop_purchase_participant)
		if not sources_configured.get("ok", false):
			return sources_configured
		var issuer_configured: Dictionary = coordinator.configure_identity_issuer(_desktop_identity_nonce_issuer)
		if not issuer_configured.get("ok", false):
			return issuer_configured
		_retained_desktop_consequence_coordinator = coordinator

	# The round coordinator's own additive consequence-port/checkpoint seams (Task 8's own two named
	# Task-9 concerns): required before complete_round() -- itself still unreachable here, see this
	# function's doc comment -- but a restart's forward-recovery replay of an ALREADY-admitted
	# minesweeper_round transaction needs them regardless.
	var round_consequence_port: Dictionary = _retained_minesweeper_round_coordinator_app.configure_consequence_port(
		_retained_desktop_consequence_coordinator, _application_gate)
	if not round_consequence_port.get("ok", false):
		return round_consequence_port
	var round_consequence_checkpoint: Dictionary = _retained_minesweeper_round_coordinator_app.configure_consequence_checkpoint(
		_desktop_consequence_state, _retained_checkpoint_port)
	if not round_consequence_checkpoint.get("ok", false):
		return round_consequence_checkpoint

	var round_rewards: Dictionary = _retained_minesweeper_round_coordinator_app.configure_reward_port(_retained_minesweeper_state_port)
	if not round_rewards.get("ok", false): return round_rewards

	# The Plan-03 condition-policy/ScheduleView pair, configured TOGETHER on the one shared
	# consequence coordinator (dwm-oyo.3 slice, 2026-08-24, authorized on dwm-p2r.21 / dwm-oyo.3).
	# Both halves are the real production ports: the policy reads only through the GameState context
	# adapter over the retained issuer, and the view port owns the canonical (empty-until-Tasks-1-5)
	# ScheduleView with its condition-departure receipt retention. Configured BEFORE resume_pending()
	# so a restored departure transaction recovers forward through the real pair.
	if _retained_desktop_condition_context_port == null:
		var context_port: RefCounted = DESKTOP_CONDITION_CONTEXT_PORT.new()
		var context_configured: Dictionary = context_port.configure(
			game_state, _desktop_identity_nonce_issuer)
		if not context_configured.get("ok", false):
			return context_configured
		_retained_desktop_condition_context_port = context_port
	if _retained_desktop_condition_policy_port == null:
		var policy_port: RefCounted = DESKTOP_CONDITION_POLICY_PORT.new()
		var policy_configured: Dictionary = policy_port.configure(
			_retained_desktop_condition_context_port)
		if not policy_configured.get("ok", false):
			return policy_configured
		_retained_desktop_condition_policy_port = policy_port
	if _retained_schedule_departure_view_port == null:
		var view_port: RefCounted = SCHEDULE_DEPARTURE_VIEW_PORT.new()
		var view_configured: Dictionary = view_port.configure(_application_gate)
		if not view_configured.get("ok", false):
			return view_configured
		_retained_schedule_departure_view_port = view_port
	var canonical_view: Dictionary = _retained_schedule_departure_view_port.configure_view_controller(
		_retained_schedule_view_controller)
	if not canonical_view.get("ok", false): return canonical_view
	var pair_configured: Dictionary = _retained_desktop_consequence_coordinator.configure_condition_departure_ports(
		_retained_desktop_condition_policy_port, _retained_schedule_departure_view_port)
	if not pair_configured.get("ok", false):
		return pair_configured

	var notifications: Dictionary = _retained_desktop_consequence_coordinator.configure_notification_consumer(
		Callable(_retained_minesweeper_state_port, "accept_desktop_notification"),
		Callable(_retained_minesweeper_state_port, "publish_desktop_notifications"))
	if not notifications.get("ok", false): return notifications

	var source_capture: Dictionary = _retained_minesweeper_round_coordinator_app.configure_source_checkpoint_capture(
		Callable(self, "_capture_completed_consequence_checkpoint_inputs"))
	if not source_capture.get("ok", false): return source_capture

	var completion_capture: Dictionary = _retained_desktop_consequence_coordinator.configure_completion_checkpoint_capture(
		Callable(self, "_capture_completed_consequence_checkpoint_inputs"))
	if not completion_capture.get("ok", false): return completion_capture

	# Replay only against the exact CURRENT Autosave that preceded admission, before
	# Title becomes ready. This does not load a historical slot or activate a session.
	var resumed: Dictionary = {"ok": true, "value": {"resumed": false}}
	if not _desktop_cold_recovery_checked:
		if _desktop_cold_recovery == null:
			_desktop_cold_recovery = preload("res://scripts/application/desktop/DesktopColdRecoveryPreparation.gd").new()
			var cold_configured: Dictionary = _desktop_cold_recovery.configure(
				_target(&"SaveManager"), _retained_checkpoint_port, game_state, _desktop_host_state)
			if not cold_configured.get("ok", false): return cold_configured
		var recovery_source: Dictionary = _desktop_cold_recovery.prepare_current_autosave()
		if not recovery_source.get("ok", false): return recovery_source
		if recovery_source.value.kind == "install_source":
			var installed: Dictionary = _desktop_cold_recovery.install_prepared()
			if not installed.get("ok", false): return installed
		if recovery_source.value.kind != "none":
			resumed = _retained_desktop_consequence_coordinator.resume_pending()
			if not resumed.get("ok", false): return resumed
		var finished: Dictionary = _desktop_cold_recovery.finish_recovery()
		if not finished.get("ok", false): return finished
		_desktop_cold_recovery_checked = true

	# The Schedule-Done consequence source, finishing DEVIATION-5: the ONE object carrying both
	# resolve methods, composed from the retained coordinator (condition truth) and board-fate port
	# (a real Schedule-Done departure), then configured into the day-resolution state port so
	# `is_presentation_producer_ready()` finally reports true. The state port, its identity half,
	# and the presentation ports are composed by the EARLIER configure_day_resolution stage in the
	# full production STAGE_ORDER, so on a real boot this branch always runs; a harness (or a
	# development subset) that deliberately builds only the desktop graph stops here instead --
	# the same established pattern as initialize_dialogic_bridge's own checkpoint-port early-out
	# -- and the skip is REPORTED in the value plus the probe's zero instance ids, never silent.
	# The bootstrap-wiring suite's graph test drives the full order and proves the composed flip.
	var producer_composed := false
	if _retained_day_resolution_state_port != null:
		if _retained_desktop_consequence_source_port == null:
			var source_port: RefCounted = DESKTOP_CONSEQUENCE_SOURCE_PORT.new()
			var source_configured: Dictionary = source_port.configure(
				_retained_desktop_consequence_coordinator, _retained_desktop_board_fate_port,
				_desktop_identity_nonce_issuer, _desktop_identity_provider)
			if not source_configured.get("ok", false):
				return source_configured
			_retained_desktop_consequence_source_port = source_port
		var condition_owner: Dictionary = _retained_desktop_consequence_source_port.configure_current_condition_owner(game_state)
		if not condition_owner.get("ok", false): return condition_owner
		var source_installed: Dictionary = _retained_day_resolution_state_port.call(
			&"configure_desktop_consequence_source", _retained_desktop_consequence_source_port)
		if not source_installed.get("ok", false):
			return source_installed
		var advance_owners: Dictionary = _retained_day_resolution_state_port.configure_day_advance_owners(
			_retained_schedule_view_controller, _desktop_board_state, _desktop_consequence_state)
		if not advance_owners.get("ok", false): return advance_owners
		producer_composed = true

	# The real challenge owner shares the retained generation and GameState owners. The port was
	# injected earlier; configure it here once the desktop generation dependency exists.
	if _retained_dating_presentation_port != null:
		if _retained_dating_physical_owner == null:
			var dating_owner: RefCounted = preload("res://scripts/application/run/DatingPhysicalOwner.gd").new()
			var dating_configured: Dictionary = dating_owner.configure(_desktop_identity_nonce_issuer,
				game_state, _target(&"ProfileManager"), _retained_minesweeper_generation_port)
			if not dating_configured.get("ok", false): return dating_configured
			_retained_dating_physical_owner = dating_owner
		var history_bound: Dictionary = _retained_dating_physical_owner.configure_attempt_history(_application_gate)
		if not history_bound.get("ok", false): return history_bound
		var restore_bound: Dictionary = game_state.configure_dating_restore_reconciler(
			Callable(_retained_dating_physical_owner, "reconcile_restore_silent"))
		if not restore_bound.get("ok", false): return restore_bound
		var writer_bound: Dictionary = _retained_dating_physical_owner.configure_checkpoint_writer(
			Callable(self, "_commit_dating_checkpoint"))
		if not writer_bound.get("ok", false): return writer_bound
		var dating_bound: Dictionary = _retained_dating_presentation_port.configure(
			_desktop_identity_nonce_issuer, _retained_dating_physical_owner)
		if not dating_bound.get("ok", false): return dating_bound

	var care_writer: Dictionary = game_state.configure_contact_checkpoint_writer(
		Callable(self, "_commit_presentation_checkpoint").bind("main"))
	if not care_writer.get("ok", false): return care_writer

	if _retained_hospital_presentation_port != null and _retained_dating_presentation_port != null:
		var hospital_configured := _configure_condition_hospital(game_state)
		if not hospital_configured.get("ok", false): return hospital_configured

	# The Done dispatch surface (dwm-p2r.21's recorded resolution: Plan 03 owns it, and the
	# GameState facade option is rejected). Configured AFTER configure_presentation_ports connected
	# the coordinator's own completion handlers, so the coordinator retains each receipt before the
	# dispatcher's handler drives the settle. Same reported early-out as the source above when the
	# presentation half was deliberately not built.
	var dispatcher_composed := false
	if _retained_day_resolution_coordinator != null \
			and _retained_hospital_presentation_port != null \
			and _retained_dating_presentation_port != null:
		if _retained_schedule_done_dispatcher == null:
			var dispatcher: RefCounted = SCHEDULE_DONE_DISPATCHER.new()
			var dispatcher_configured: Dictionary = dispatcher.configure(
				_retained_day_resolution_coordinator, _retained_hospital_presentation_port,
				_retained_dating_presentation_port)
			if not dispatcher_configured.get("ok", false):
				return dispatcher_configured
			_retained_schedule_done_dispatcher = dispatcher
		dispatcher_composed = true

	return {"ok": true, "code": &"ok", "value": {
		"desktop_publication_ledger_instance_id": ledger.get_instance_id(),
		"causal_sequence_port_instance_id": _retained_desktop_causal_sequence_port.get_instance_id(),
		"board_fate_port_instance_id": _retained_desktop_board_fate_port.get_instance_id(),
		"consequence_coordinator_instance_id": _retained_desktop_consequence_coordinator.get_instance_id(),
		"minesweeper_round_source_port_instance_id": _retained_minesweeper_round_coordinator_app.get_instance_id(),
		"shop_purchase_source_port_instance_id": _retained_minesweeper_shop_purchase_participant.get_instance_id(),
		"condition_context_port_instance_id": _retained_desktop_condition_context_port.get_instance_id(),
		"condition_policy_port_instance_id": _retained_desktop_condition_policy_port.get_instance_id(),
		"schedule_departure_view_port_instance_id": _retained_schedule_departure_view_port.get_instance_id(),
		"desktop_consequence_source_port_instance_id": _instance_id(_retained_desktop_consequence_source_port),
		"schedule_done_dispatcher_instance_id": _instance_id(_retained_schedule_done_dispatcher),
		"presentation_producer_composed": producer_composed,
		"schedule_done_dispatcher_composed": dispatcher_composed,
		"resumed_pending": bool(resumed.get("value", {}).get("resumed", false)),
	}, "receipt": {}}


## Constructs EXACTLY ONE Minesweeper round coordinator with initialized production adapters and
## installs it in GameState exactly once (dwm-p2r.9 Plan 06 Task 2).
##
## This stage runs only after `initialize_saves` retained the real checkpoint port and after
## `configure_day_resolution` built the provider bundle, so an out-of-order or missing dependency
## is rejected here with NO partial configuration: every retained field is assigned only after its
## own construction succeeded, and the coordinator is installed last.
func _configure_minesweeper_rounds(game_state: Object, save_manager: Object) -> Dictionary:
	if _application_gate == null:
		return _failure(&"mutation_gate_not_configured", "Bootstrap has not constructed the application gate")
	if game_state == null or save_manager == null:
		return _failure(&"missing_stage_adapter", "Minesweeper rounds require GameState and SaveManager")
	if _retained_checkpoint_port == null:
		return _failure(&"missing_stage_adapter", "Minesweeper rounds require the retained checkpoint port")
	if _checkpoint_provider_bundle.is_empty():
		return _failure(&"missing_stage_adapter", "Minesweeper rounds require the configured checkpoint providers")
	if not game_state.has_method("_install_minesweeper_round_coordinator"):
		return _failure(&"missing_stage_adapter", "GameState Minesweeper seam is unavailable")
	# ONE state adapter, proving GameState retained the very gate Bootstrap injected.
	var state_port: RefCounted = _retained_minesweeper_state_port
	if state_port == null:
		state_port = MINESWEEPER_STATE_PORT.new(game_state)
	var state_configured: Dictionary = state_port.configure(_application_gate)
	if not state_configured.get("ok", false):
		return state_configured
	if int(state_configured.get("value", {}).get("gate_instance_id", 0)) != _application_gate.get_instance_id():
		return _failure(&"mutation_gate_identity_mismatch", "Minesweeper state port retained another gate")
	var providers_configured: Dictionary = state_port.configure_checkpoint_providers(
		_checkpoint_provider_bundle.duplicate())
	if not providers_configured.get("ok", false):
		return providers_configured
	_retained_minesweeper_state_port = state_port
	# ONE save adapter over the SAME real checkpoint port; it owns only the board lock owner.
	var save_port: RefCounted = _retained_minesweeper_save_port
	if save_port == null:
		save_port = MINESWEEPER_SAVE_PORT.new()
	var save_configured: Dictionary = save_port.configure(_retained_checkpoint_port, save_manager)
	if not save_configured.get("ok", false):
		return save_configured
	if int(save_configured.get("value", {}).get("checkpoint_port_instance_id", 0)) \
			!= _retained_checkpoint_port.get_instance_id():
		return _failure(&"checkpoint_port_identity_mismatch", "Minesweeper save port retained another checkpoint port")
	_retained_minesweeper_save_port = save_port
	var coordinator: RefCounted = _retained_minesweeper_coordinator
	if coordinator == null:
		coordinator = MINESWEEPER_ROUND_COORDINATOR.new()
	var coordinator_configured: Dictionary = coordinator.configure(save_port, state_port)
	if not coordinator_configured.get("ok", false):
		return coordinator_configured
	_retained_minesweeper_coordinator = coordinator
	var installed: Dictionary = game_state.call(&"_install_minesweeper_round_coordinator", coordinator)
	if not installed.get("ok", false):
		return installed
	return {"ok": true, "code": &"ok", "value": {
		"coordinator_instance_id": coordinator.get_instance_id(),
		"state_port_instance_id": state_port.get_instance_id(),
		"save_port_instance_id": save_port.get_instance_id(),
		"gate_instance_id": _application_gate.get_instance_id(),
	}, "receipt": {}}


## Connects GameState.day_changed to the Bootstrap-owned eviction handler exactly once, only
## after the host and day-resolution coordinator are configured (dwm-p2r.9 Plan 02 Task 1).
func _connect_desktop_day_change(game_state: Object) -> void:
	if game_state == null or not game_state.has_signal("day_changed"):
		return
	if not game_state.day_changed.is_connected(_on_day_changed):
		game_state.day_changed.connect(_on_day_changed)


## Registers the one Phase-3-owned desktop eviction port. The same object is idempotent; a
## different object is rejected (dwm-p2r.9 Plan 02 Task 1).
func register_desktop_eviction_port(port: Object) -> Dictionary:
	if port == null or not port.has_method("dispatch_desktop_eviction"):
		return _failure(&"invalid_desktop_eviction_port", "port must expose dispatch_desktop_eviction")
	if _desktop_eviction_port != null and is_instance_valid(_desktop_eviction_port):
		if port == _desktop_eviction_port:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _failure(&"desktop_eviction_port_already_configured", "a desktop eviction port is already configured")
	_desktop_eviction_port = port
	return {"ok": true, "code": &"ok", "value": {"port_instance_id": _desktop_eviction_port.get_instance_id()}, "receipt": {}}


## Bootstrap-owned day-change handler. The host computes the exact eviction command; a registered
## port dispatches it once. A missing port or a dispatch failure projects the recovery through the
## shared fatal projector, latches once, and permanently blocks input via the retained
## APPLICATION_FATAL (dwm-p2r.9 Plan 02 Task 1).
func _on_day_changed(new_day: int) -> void:
	if _desktop_host_state == null:
		return
	if _retained_schedule_view_controller != null:
		var state := _target(&"GameState")
		var identity: Dictionary = state.capture_schedule_warning_state()
		var opened: Dictionary = _retained_schedule_view_controller.open_day(new_day,
			str(identity.value.state.causal_day_instance))
		if not opened.get("ok", false):
			_desktop_day_change_fatal(&"SCHEDULE_DAY_OPEN_FAILED", new_day, [])
			return
	if _desktop_eviction_port == null:
		_desktop_day_change_fatal(&"DESKTOP_EVICTION_PORT_MISSING", new_day, [])
		return
	var changed: Dictionary = _desktop_host_state.change_day(new_day)
	if not changed.get("ok", false):
		_desktop_day_change_fatal(StringName(changed.get("code", &"desktop_day_change_rejected")), new_day, [])
		return
	var command: Dictionary = changed["value"]["eviction_command"]
	if not _is_exact_eviction_command(command, new_day):
		_desktop_day_change_fatal(&"DESKTOP_EVICTION_COMMAND_INVALID", new_day, [])
		return
	var raw_result: Dictionary = _desktop_eviction_port.dispatch_desktop_eviction(command.duplicate(true))
	if not raw_result.get("ok", false):
		_desktop_day_change_fatal(&"DESKTOP_EVICTION_DISPATCH_FAILED", new_day,
			[{"owner_id": "desktop_eviction_port", "operation": "dispatch_desktop_eviction", "result": raw_result}])
		return


func _is_exact_eviction_command(command: Variant, new_day: int) -> bool:
	if typeof(command) != TYPE_DICTIONARY:
		return false
	var expected := {
		"command_id": "desktop-day:%d" % new_day,
		"kind": &"evict_cached_apps",
		"day": new_day,
	}
	for key in expected.keys():
		if not command.has(key) or str(command[key]) != str(expected[key]):
			return false
	if not command.has("app_ids") or typeof(command["app_ids"]) != TYPE_ARRAY:
		return false
	return true


func _desktop_day_change_fatal(code: StringName, new_day: int, raw_diagnostics: Array) -> void:
	if _application_gate == null or not _application_gate.has_method("latch_fatal"):
		return
	var projected: Dictionary = FATAL_DIAGNOSTIC_PROJECTOR.project_failure(
		"desktop", "day_change_dispatch", code, {"day": new_day}, raw_diagnostics)
	var failure: Dictionary = FATAL_DIAGNOSTIC_PROJECTOR.get_invariant_fallback()
	if projected.get("ok", false):
		var candidate: Dictionary = projected["value"]["failure"]
		if FATAL_DIAGNOSTIC_PROJECTOR.validate_failure(candidate).get("ok", false):
			failure = candidate
	_application_gate.latch_fatal(failure)
	_application_gate.guard_external(&"desktop_day_change_dispatch")


## Constructs and retains the Schedule-foundation objects exactly once each (Plan 01 Task 6
## Step 6.5, dwm-p2r.13).
##
## ONE ledger, shared by BOTH ports. That sharing is the whole point: the commit port's
## `schedule_commit` publications and the start port's `day_resolution_start` publications must land
## in the same durable record, or a cold restart could replay one without seeing the other.
##
## It reuses the exact `.16` issuer and the exact Task-3 root-scoped storage already retained above
## rather than building a second of either -- a second issuer would mint identities under a
## different root and every provenance chain would silently fork.
##
## Ledger corruption or a missing capability fails STARTUP, before either port exists. Identical
## replay is idempotent because every retained field is only built when still null.
func _construct_schedule_foundation(game_state: Object, state_port: Object) -> Dictionary:
	if _desktop_identity_nonce_issuer == null:
		return _failure(&"missing_stage_adapter",
			"the Schedule foundation requires the retained identity issuer")
	if _profile_storage == null:
		return _failure(&"issuer_storage_unconfigured",
			"the Schedule foundation requires the retained root-scoped storage")
	if _retained_schedule_registry == null:
		var loaded: Dictionary = SCHEDULE_ACTION_REGISTRY.load_current()
		if not loaded.get("ok", false):
			return loaded
		_retained_schedule_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	if _retained_publication_ledger == null:
		var ledger: RefCounted = SCHEDULE_PUBLICATION_LEDGER.new()
		var configured: Dictionary = ledger.configure(_profile_storage)
		if not configured.get("ok", false):
			return configured
		var opened: Dictionary = ledger.load()
		if not opened.get("ok", false):
			return opened
		_retained_publication_ledger = ledger
	if _retained_schedule_commit_port == null:
		_retained_schedule_commit_port = SCHEDULE_COMMIT_PORT.new(game_state,
			_retained_schedule_registry, _desktop_identity_nonce_issuer,
			_retained_publication_ledger)
	if _retained_day_resolution_start_port == null:
		_retained_day_resolution_start_port = DAY_RESOLUTION_START_PORT.new(state_port,
			_retained_schedule_registry, _desktop_identity_nonce_issuer,
			_retained_publication_ledger)
	if _retained_day7_provenance == null:
		var provenance: RefCounted = DAY7_SCHEDULE_PROVENANCE.new()
		var provenance_configured: Dictionary = provenance.configure(
			_retained_schedule_registry, _desktop_identity_nonce_issuer)
		if not provenance_configured.get("ok", false):
			return provenance_configured
		_retained_day7_provenance = provenance
	# Step 6.5: the configured service is INJECTED INTO the retained state port, so the Day-7 handoff
	# has exactly one source and the port never has to construct or configure one of its own.
	if state_port.has_method("configure_day7_provenance"):
		var injected: Dictionary = state_port.call(&"configure_day7_provenance", _retained_day7_provenance)
		if not injected.get("ok", false):
			return injected
	# dwm-p2r.18: the same two retained objects the start port was built from are injected into the
	# state port, so a resolution can mint its own root and drive that exact start port.
	#
	# THE DESKTOP-CONSEQUENCE SOURCE IS DELIBERATELY NOT CONFIGURED HERE. It supplies the board-fate
	# and condition receipts Plan 02 owns, and `dwm-p2r.9` delivered neither (DEVIATION-2); Plan 01
	# line 1303 forbids this plan from building desktop board fate. Until Plan 02 configures it, a
	# stage that genuinely needs a presentation fails closed naming the missing input -- which is a
	# visible, asserted gap rather than a silently skipped presentation.
	if state_port.has_method("configure_resolution_identity"):
		var identity: Dictionary = state_port.call(&"configure_resolution_identity",
			_desktop_identity_nonce_issuer, _retained_day_resolution_start_port)
		if not identity.get("ok", false):
			return identity
	return {"ok": true, "code": &"ok", "value": {"constructed": true}, "receipt": {}}

func _is_compatible_gate(gate: Object) -> bool:
	if not gate.has_signal("capability_changed"): return false
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method): return false
	return true

func _stage_target(stage_id: StringName) -> StringName:
	return {
		&"initialize_saves": &"SaveManager", &"initialize_localization": &"LocalizationManager",
		&"initialize_input": &"InputManager", &"initialize_accessibility": &"AccessibilityManager",
		&"initialize_audio": &"AudioManager", &"initialize_dialogic_bridge": &"DialogicBridge",
	}.get(stage_id, &"")

func _target(target_name: StringName) -> Node:
	# Absolute-path lookups require an active tree; outside one (e.g. a bare-node
	# unit harness) there is no target to resolve.
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + String(target_name))

func _requested_mode_from_debug_args() -> StringName:
	var explicit := _explicit_requested_mode()
	if explicit != &"": return explicit
	if OS.is_debug_build() and _has_proven_test_root(): return MODE_TEST_MANUAL
	return MODE_FINAL

func _explicit_requested_mode() -> StringName:
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if argument.begins_with("--phase2r-bootstrap-mode="):
			return StringName(argument.trim_prefix("--phase2r-bootstrap-mode="))
	return &""

func _has_proven_test_root() -> bool:
	var candidate := OS.get_environment("DWM_TEST_ROOT")
	if candidate.is_empty(): return false
	var root := ProjectSettings.globalize_path("res://.godot/phase2r_tests").simplify_path().trim_suffix("/").trim_suffix("\\")
	var canonical := candidate.simplify_path().trim_suffix("/").trim_suffix("\\")
	return canonical.nocasecmp_to(root) != 0 and (canonical.to_lower().begins_with(root.to_lower() + "/") or canonical.to_lower().begins_with(root.to_lower() + "\\"))

func _latch_startup_fatal(code: StringName, message: String) -> Dictionary:
	var result := _failure(code, message)
	_state["fatal_result"] = result.duplicate(true)
	_started = true
	return result

func _failure(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}, "receipt": {}}


func _capture_live_desktop_snapshot() -> Dictionary:
	var consequence: Dictionary = _desktop_consequence_state.capture()
	if not consequence.get("ok", false): return {}
	return {"board": _desktop_board_state.capture(), "consequence": consequence.value.state}


func _capture_exit_checkpoint_inputs() -> Dictionary:
	if _application_gate == null or not _application_gate.is_internal_owner_active(&"session_abandonment"):
		return _failure(&"session_abandonment_required", "")
	if _checkpoint_provider_bundle.is_empty(): return _failure(&"exit_capture_unavailable", "")
	var game_state := _target(&"GameState")
	var view: Dictionary = _retained_schedule_view_controller.snapshot()
	if not view.get("ok", false): return view
	var inputs := {"snapshot_input": game_state.capture_run_snapshot_input()}
	inputs.snapshot_input["schedule_view"] = view.value.view
	for key in _checkpoint_provider_bundle:
		inputs[key] = (_checkpoint_provider_bundle[key] as Callable).call()
	# The Logout confirmation itself is not a resumable app. The saved board keeps its
	# suspended state and can be reopened normally from the launcher.
	if inputs.route_id != "main" or not inputs.dialogic_checkpoint.is_empty():
		return _failure(&"exit_capture_unavailable", "Logout requires the stable desktop")
	inputs.active_app_id = null
	return {"ok": true, "value": inputs}


func configure_session_exit_desktop(desktop: Node) -> Dictionary:
	if desktop == null or not desktop.has_method("configure_session_exit"):
		return _failure(&"invalid_exit_desktop", "")
	if desktop.has_meta("session_exit"): return {"ok": true}
	var exit: RefCounted = preload("res://scripts/application/desktop/SessionExitCoordinator.gd").new()
	var configured: Dictionary = exit.configure(_target(&"GameState"), _target(&"SaveManager"),
		_target(&"SceneRouter"), _application_gate, Callable(self, "_capture_exit_checkpoint_inputs"))
	if not configured.get("ok", false): return configured
	configured = desktop.configure_session_exit(exit)
	if configured.get("ok", false): desktop.set_meta("session_exit", exit)
	return configured


func _capture_completed_consequence_checkpoint_inputs(completed: Dictionary) -> Dictionary:
	if _desktop_cold_recovery != null and _desktop_cold_recovery.is_installed():
		return _desktop_cold_recovery.capture_completed_checkpoint_inputs(completed)
	if _application_gate == null or not _application_gate.is_internal_owner_active(&"causal_transaction"):
		return _failure(&"causal_transaction_lease_required", "")
	if _checkpoint_provider_bundle.is_empty():
		return _failure(&"completion_checkpoint_capture_unavailable", "")
	var game_state := _target(&"GameState")
	var view: Dictionary = _retained_schedule_view_controller.snapshot()
	if not view.get("ok", false): return view
	var inputs := {"snapshot_input": game_state.capture_run_snapshot_input()}
	inputs.snapshot_input["schedule_view"] = view.value.view
	inputs.snapshot_input.desktop.consequence = completed.duplicate(true)
	for key in _checkpoint_provider_bundle:
		inputs[key] = (_checkpoint_provider_bundle[key] as Callable).call()
	return {"ok": true, "value": {"checkpoint_inputs": inputs}}


## Save physical progress before its owner publishes the next playable state.
func _commit_dating_checkpoint(_physical_record: Dictionary) -> Dictionary:
	return _commit_presentation_checkpoint("dating")


func _commit_ending_checkpoint() -> Dictionary:
	return _commit_presentation_checkpoint("ending")


func _commit_presentation_checkpoint(route_id: String) -> Dictionary:
	if _retained_checkpoint_port == null or _retained_day_resolution_state_port == null:
		return _failure(&"presentation_checkpoint_unavailable", "")
	var game_state := _target(&"GameState")
	var inputs: Dictionary = _retained_day_resolution_state_port._checkpoint_inputs(
		game_state._run_lifecycle.to_dict())
	inputs["route_id"] = route_id
	# Dating's physical record and Ending's cursor own these resume boundaries. A
	# completed Dialogic command from the preceding scene must not be replayed.
	inputs["dialogic_checkpoint"] = {}
	var backup: Dictionary = _retained_checkpoint_port.capture()
	if not backup.get("ok", false): return backup
	var prepared: Dictionary = _retained_checkpoint_port.prepare(inputs, &"safe_marker",
		{"kind": &"autosave", "reason": &"automatic"})
	if not prepared.get("ok", false): return prepared
	var committed: Dictionary = _retained_checkpoint_port.commit(prepared.value.candidate)
	if not committed.get("ok", false):
		var rolled: Dictionary = _retained_checkpoint_port.rollback({
			"journal_backup": backup.value.backup,
			"storage_backup": prepared.value.candidate.storage_backup})
		if not rolled.get("ok", false): return rolled
	return committed


func configure_gallery_replay_services(scene: Node) -> Dictionary:
	if not _state.get("ready", false) or not is_inside_tree() or get_tree().current_scene != scene:
		return _failure(&"gallery_replay_services_unavailable", "The current title is not ready")
	if scene == null or not scene.has_method("configure_gallery_replay"):
		return _failure(&"gallery_replay_services_unavailable", "The title cannot accept replay services")
	var replay: Dictionary = scene.configure_gallery_replay(_target(&"ProfileManager"), _target(&"DialogicBridge"))
	if not replay.get("ok", false): return replay
	if not scene.has_method("configure_gallery_rehearsal"):
		return _failure(&"gallery_rehearsal_services_unavailable", "The title cannot accept practice services")
	return scene.configure_gallery_rehearsal(_target(&"GameState"), _target(&"InputManager"))


func configure_dating_scene_services(scene: Node) -> Dictionary:
	var profile := _target(&"ProfileManager")
	var locale := _target(&"LocalizationManager")
	var input_owner := _target(&"InputManager")
	if profile == null or locale == null or input_owner == null:
		return _failure(&"dating_presentation_services_unavailable", "")
	var percent: Variant = profile.get_preference("preferences.accessibility.text_size", null)
	if percent == null:
		var scale_value: float = float(profile.get_preference("preferences.accessibility.font_scale", 1.0))
		percent = 150 if scale_value >= 1.5 else (125 if scale_value >= 1.25 else 100)
	var large: Variant = profile.get_preference("preferences.accessibility.large_targets", null)
	if large == null: large = profile.get_preference("preferences.accessibility.large_click_targets", false)
	var colour: Variant = profile.get_preference("preferences.accessibility.colour_differentiation", null)
	if colour == null:
		var legacy: String = str(profile.get_preference("preferences.accessibility.colorblind_mode", "none"))
		colour = preload("res://scripts/ui/MinesweeperApp.gd").LEGACY_COLOUR_PRESETS.get(legacy, "standard")
	return scene.configure_presentation_services(input_owner, str(locale.get_locale()), int(percent),
		bool(large), &"after_hours", bool(profile.get_preference("preferences.accessibility.high_contrast", false)), str(colour))


func _configure_condition_hospital(game_state: Object) -> Dictionary:
	var ending_source: Dictionary = game_state.configure_ending_condition_source(_desktop_consequence_state)
	if not ending_source.get("ok", false): return ending_source
	if _retained_condition_hospital_coordinator != null: return {"ok": true}
	var state: RefCounted = preload("res://scripts/domain/run/ConditionHospitalState.gd").new()
	var configured: Dictionary = state.configure(game_state._run_lifecycle, _desktop_identity_nonce_issuer)
	if not configured.get("ok", false): return configured
	var adapter: RefCounted = preload("res://scripts/application/run/GameStateConditionHospitalPort.gd").new()
	configured = adapter.configure(game_state, _desktop_identity_nonce_issuer,
		_retained_causal_day_advance_identity_port, _retained_schedule_view_controller,
		_desktop_board_state, _desktop_consequence_state,
		Callable(_retained_day_resolution_state_port, "_checkpoint_inputs"))
	if not configured.get("ok", false): return configured
	configured = adapter.configure_presentation(_retained_hospital_presentation_port,
		Callable(_target(&"SceneRouter"), "route_presentation"), _retained_dating_presentation_port)
	if not configured.get("ok", false): return configured
	var coordinator: RefCounted = preload("res://scripts/application/run/ConditionHospitalCoordinator.gd").new()
	configured = coordinator.configure(state, _desktop_consequence_state, adapter,
		_retained_checkpoint_port, _application_gate)
	if not configured.get("ok", false): return configured
	if _pair_deck_draw_port == null:
		_pair_deck_draw_port = preload("res://scripts/application/run/PairDeckDrawPort.gd").new()
	configured = _pair_deck_draw_port.configure(game_state, _target(&"ProfileManager"), _application_gate, coordinator)
	if not configured.get("ok", false): return configured
	configured = _retained_day_resolution_state_port.configure_pair_deck(_pair_deck_draw_port)
	if not configured.get("ok", false): return configured
	configured = adapter.configure_pair_deck(_pair_deck_draw_port)
	if not configured.get("ok", false): return configured
	_retained_condition_hospital_state = state
	_retained_condition_hospital_adapter = adapter
	_retained_condition_hospital_coordinator = coordinator
	adapter.progress_ready.connect(_queue_condition_hospital_progress)
	if _application_gate.has_signal("transaction_released") and not _application_gate.is_connected("transaction_released", _queue_condition_hospital_progress):
		_application_gate.connect("transaction_released", _queue_condition_hospital_progress)
	return {"ok": true}


func _queue_condition_hospital_progress() -> void:
	if _condition_hospital_pump_queued or _condition_hospital_pump_running: return
	_condition_hospital_pump_queued = true
	_pump_condition_hospital.call_deferred()


## A pump follows the original action's lease release; it never borrows another transaction's lease.
func _pump_condition_hospital() -> void:
	_condition_hospital_pump_queued = false
	if _condition_hospital_pump_running or _retained_condition_hospital_coordinator == null: return
	var game_state := _target(&"GameState")
	if not bool(game_state.capture_live_session().value.active): return
	if _application_gate.is_fatal_latched(): return
	if _application_gate.is_active() and str(_retained_condition_hospital_coordinator.get("_gate_token")).is_empty(): return
	var lifecycle: Dictionary = game_state._run_lifecycle.to_dict()
	var consequence: Dictionary = _desktop_consequence_state.capture().value.state
	var outbox: Dictionary = consequence.get("outbox", {})
	var destination: Dictionary = outbox.get("hospital", {}) if outbox.get("hospital") is Dictionary else {}
	if not lifecycle.get("active_condition_hospital_plan") is Dictionary and str(destination.get("status", "")) != "pending": return
	if str(destination.get("consumer", "")) == "day7_terminal":
		_condition_hospital_pump_running = true
		_last_condition_hospital_result = _finish_day_resolution_route()
		_condition_hospital_pump_running = false
		return
	_condition_hospital_pump_running = true
	for boundary: int in 16:
		_last_condition_hospital_result = _retained_condition_hospital_coordinator.resume()
		if not _last_condition_hospital_result.get("ok", false): break
		var value: Dictionary = _last_condition_hospital_result.get("value", {})
		if value.get("idle", false) or str(value.get("boundary", "")) == "awaiting_presentation": break
		if str(value.get("boundary", "")) == "plan_retired":
			_target(&"SceneRouter").goto_main()
			break
	_condition_hospital_pump_running = false


## Navigation follows the completed owner's durable boundary, after its caller unwinds.
func _on_day_resolution_completed(_result: Dictionary) -> void:
	_on_live_session_ready()


func _on_live_session_ready() -> void:
	var game_state := _target(&"GameState")
	if game_state == null: return
	var session: Dictionary = game_state.capture_live_session()
	if session.get("ok", false) and session.value.active:
		_pending_live_continuation = session.value.duplicate(true)
		_queue_live_continuation()


func _queue_live_continuation() -> void:
	if _pending_live_continuation.is_empty() or _live_continuation_queued: return
	_live_continuation_queued = true
	_resume_live_continuation.call_deferred()


func _resume_live_continuation() -> void:
	# Route finalization may have queued change_scene_to_file for the end of this frame.
	# Let that mount finish before publishing the exact physical continuation into it.
	await get_tree().process_frame
	_live_continuation_queued = false
	var game_state := _target(&"GameState")
	var session: Dictionary = game_state.capture_live_session()
	if not session.get("ok", false) or session.value != _pending_live_continuation or not session.value.active:
		_pending_live_continuation = {}
		return
	if _application_gate.is_active() or _application_gate.is_fatal_latched(): return
	var router := _target(&"SceneRouter")
	if router.has_method("is_restore_publication_held") and router.is_restore_publication_held(): return
	if _present_pending_day7_prelude(game_state, router): return
	_pending_live_continuation = {}
	var lifecycle: Dictionary = game_state._run_lifecycle.to_dict()
	if str(lifecycle.state) == "COMPLETED":
		# A compatible completed save may name main/menu instead of the ending scene. Retire
		# through the same validated owner seam after restore activation and lease release.
		var retired: Dictionary = game_state.complete_ending_playback_stage("", &"COMPLETED", {})
		if not retired.get("ok", false):
			push_error("Completed run could not return to title: " + str(retired.get("code", "")))
			return
		router.goto_menu()
		return
	var consequence: Dictionary = _desktop_consequence_state.capture().value.state
	var destination: Variant = consequence.get("outbox", {}).get("hospital")
	if lifecycle.active_condition_hospital_plan != null or (
		destination is Dictionary and str(destination.get("status", "")) == "pending"):
		_queue_condition_hospital_progress()
		return
	if str(lifecycle.state) == "ENDING":
		if str(router.get_current_route_id()) != "ending": router.goto_ending()
		return
	if str(lifecycle.state) == "TERMINAL_PENDING":
		_finish_day_resolution_route()
		return
	var plan: Variant = lifecycle.active_resolution_plan
	if str(lifecycle.state) != "PLAYING" or not plan is Dictionary: return
	var completed := true
	for stage: Dictionary in plan.stages:
		if str(stage.state) != "completed": completed = false
	if completed:
		# Arriving on Day 7 completes Day 6's plan; only a Day 7 source is terminal.
		if int(plan.source_day) == 7:
			_finish_day_resolution_route()
		elif str(router.get_current_route_id()) in ["dating", "hospital"]:
			router.goto_main()
	elif _retained_schedule_done_dispatcher != null:
		# Replaying the saved command rehydrates the retained coordinator without
		# issuing another root or committing another Schedule.
		var resumed: Dictionary = _retained_schedule_done_dispatcher.dispatch_done(str(plan.command_id))
		if not resumed.get("ok", false): push_error("Day resolution could not resume: " + str(resumed.get("code", "")))


func _present_pending_day7_prelude(game_state: Object, router: Object) -> bool:
	if game_state.require_day7_presentations_complete().get("ok", false): return false
	var plan: Variant = game_state._run_lifecycle.to_dict().active_resolution_plan
	if plan is Dictionary and int(plan.source_day) < 7:
		for stage: Dictionary in plan.stages:
			if str(stage.state) != "completed": return false
	# Cold Load may still be mounting main; its saved app can restore behind the guarded surface.
	if str(router.get_current_route_id()) != "main" or get_tree().current_scene == null \
			or get_tree().current_scene.find_child("ComputerDesktop", true, false) == null:
		router.goto_main()
		_on_live_session_ready()
		return true
	_pending_live_continuation = {}
	if is_instance_valid(_day7_prelude_owner): return true
	if _contacts_presentation_port == null:
		push_error("Day 7 Contacts presentation is unavailable")
		return true
	var owner := DAY7_PRELUDE_OWNER.new()
	var locale: String = str(_target(&"LocalizationManager").get_locale())
	var profile: Object = _target(&"ProfileManager")
	var percent: Variant = profile.get_preference("preferences.accessibility.text_size", null)
	if percent == null: percent = int(float(profile.get_preference("preferences.accessibility.font_scale", 1.0)) * 100)
	var presentation_theme: Theme = preload("res://scripts/ui/gallery/GalleryTheme.gd").build(locale, int(percent), &"after_hours")
	var configured: Dictionary = owner.configure(game_state, _contacts_presentation_port,
		_desktop_identity_nonce_issuer, locale, presentation_theme)
	if not configured.get("ok", false):
		owner.free()
		push_error("Day 7 presentation could not configure: " + str(configured.get("code", "")))
		return true
	_day7_prelude_owner = owner
	owner.finished.connect(_on_day7_prelude_finished)
	add_child(owner)
	owner.begin() # Recoverable preparation failures expose Retry on the same surface.
	return true

func _on_day7_prelude_finished() -> void:
	_day7_prelude_owner = null
	_on_live_session_ready()


func _finish_day_resolution_route() -> Dictionary:
	var game_state := _target(&"GameState")
	var resumed: Dictionary = game_state.resume_terminal_ending()
	if not resumed.get("ok", false):
		push_error("Day 7 ending could not resume: " + str(resumed.get("code", "")))
		return resumed
	var router := _target(&"SceneRouter")
	if str(router.get_current_route_id()) != "ending": router.goto_ending()
	return resumed
