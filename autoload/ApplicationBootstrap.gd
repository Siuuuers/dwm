extends Node

signal application_ready()
signal development_subset_ready(subset_id: StringName)
signal startup_recovery_changed()

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
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const APPLICATION_MUTATION_GATE_SCRIPT := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const DIALOGIC_ENTRY_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const NARRATIVE_CONTENT_VERSION := 1
const RUNTIME_RESOURCES: Array[String] = [
	"res://scripts/application/contact/ContactCommandPort.gd",
	"res://scripts/application/contact/ContactsPresentationPort.gd",
	"res://scripts/application/run/CausalDayAdvanceIdentityPort.gd",
	"res://scripts/application/run/DatingPresentationPort.gd",
	"res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd",
	"res://scripts/application/ending/DialogicEndingPlaybackPort.gd",
	"res://scripts/narrative/DialogicRuntimeAdapter.gd",
	"res://scripts/data/DialogicTimelineCatalog.gd",
	"res://scripts/domain/desktop/DesktopAppHostState.gd",
	"res://scripts/application/restore/RunRestoreParticipant.gd",
	"res://scripts/application/restore/ProfileRestoreParticipant.gd",
	"res://scripts/application/restore/LocalizationRestoreParticipant.gd",
	"res://scripts/application/restore/AudioRestoreParticipant.gd",
	"res://scripts/application/restore/RouteRestoreParticipant.gd",
	"res://scripts/application/restore/NarrativeRestoreParticipant.gd",
	"res://scripts/domain/desktop/DesktopConsequenceState.gd",
	"res://scripts/domain/minesweeper/DesktopBoardState.gd",
	"res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd",
	"res://scripts/application/restore/DesktopBoardRestoreParticipant.gd",
	"res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd",
	"res://scripts/application/minesweeper/GameStateMinesweeperPort.gd",
	"res://scripts/application/minesweeper/SaveManagerMinesweeperPort.gd",
	"res://scripts/infrastructure/save/DesktopPublicationLedger.gd",
	"res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd",
	"res://scripts/application/minesweeper/MinesweeperPanelPort.gd",
	"res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd",
	"res://scripts/data/DataCatalog.gd",
	"res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd",
	"res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd",
	"res://scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd",
	"res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd",
	"res://scripts/domain/shop/MinesweeperShopRegistry.gd",
	"res://scripts/ui/desktop/DesktopConfirmation.gd",
	"res://scripts/ui/backup/BackupTheme.gd",
	"res://scripts/application/run/DatingPhysicalOwner.gd",
	"res://scripts/application/desktop/SessionExitCoordinator.gd",
	"res://scripts/application/narrative/SceneEventCommandPort.gd",
	"res://scripts/ui/SceneChallengePanel.gd",
	"res://scripts/application/shop/ShopPresentationPort.gd",
	"res://scenes/desktop/ComputerDesktop.tscn",
]
const FATAL_DIAGNOSTIC_PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")
const RUN_SNAPSHOT_SCHEMA_FOR_PROBE := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE_DOCUMENT_SCHEMA_FOR_PROBE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const RUN_SNAPSHOT_SCHEMA_VERSION := RUN_SNAPSHOT_SCHEMA_FOR_PROBE.SCHEMA_VERSION
const SAVE_DOCUMENT_SCHEMA_VERSION := SAVE_DOCUMENT_SCHEMA_FOR_PROBE.DOCUMENT_VERSION
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
	&"configure_scene_gameplay",
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

var staged_startup := false
var _title_phase := false
var _runtime_stage_index := STAGE_ORDER.find(&"initialize_dialogic_bridge")
var _started := false
var _quitting := false
var _start_begun := false
var _startup_recovery_busy := false
var _scene_startup_recovery: Dictionary = {}
var _new_run_startup_recovery := {
	"available": false, "transaction_id": "", "failed_stage": &"",
}
var _startup_route_owner: Object = null
var _startup_route_hold_token := ""
var _debug_gate_factory: Callable
var _selected_root := ""
var _profile_storage: RefCounted
var _saves_storage: RefCounted = null
var _application_gate: Object = null
var _content_error_layer: CanvasLayer
var _desktop_issuer_root_store: RefCounted = null
var _desktop_identity_nonce_issuer: RefCounted = null
var _retained_causal_day_advance_identity_port: RefCounted = null
var _retained_dating_presentation_port: RefCounted = null
var _retained_dating_physical_owner: RefCounted = null
var _pending_live_continuation: Dictionary = {}
var _live_continuation_queued := false
var _contact_command_port: RefCounted = null
var _contacts_presentation_port: RefCounted = null
var _contacts_desktop_eviction_port: RefCounted = null
var _retained_checkpoint_port: RefCounted = null
var _narrative_checkpoint_adapter: Object = null
var _ending_playback_port: Object = null
var _desktop_host_state: RefCounted = null
var _desktop_eviction_port: Object = null
var _desktop_consequence_state: RefCounted = null
var _scene_shop_catalog: RefCounted = null
var _desktop_board_state: RefCounted = null
var _retained_minesweeper_state_port: RefCounted = null
var _retained_minesweeper_save_port: RefCounted = null
var _retained_minesweeper_coordinator: RefCounted = null
var _checkpoint_provider_bundle: Dictionary = {}
var _retained_restore_participants: Dictionary = {}
var _retained_desktop_publication_ledger: RefCounted = null
var _retained_minesweeper_round_coordinator_app: RefCounted = null
var _retained_minesweeper_generation_port: RefCounted = null
var _retained_game_state_desktop_board_port: RefCounted = null
var _retained_save_manager_desktop_board_port: RefCounted = null
var _desktop_identity_provider := Callable()
var _state := {
	"started": false, "ready": false, "title_ready": false, "mode": &"",
	"completed_stages": [], "planned_blockers": [], "fatal_result": {}, "failed_stage": null,
	"gate_injection": {"factory_invocation_count": 0, "gate_instance_id": 0, "targets": [], "target_instance_ids": []},
}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	if not staged_startup:
		call_deferred("start", _requested_mode_from_debug_args())

func request_quit() -> void:
	if _quitting: return
	_quitting = true
	var was_paused := get_tree().paused
	get_tree().paused = true
	var audio := _target(&"AudioManager")
	if audio != null:
		var stopped: Dictionary = await audio.call(&"shutdown")
		if not stopped.ok:
			_quitting = false
			get_tree().paused = was_paused
			if is_instance_valid(_content_error_layer):
				_content_error_layer.free()
			_content_error_layer = null
			show_content_error({"code": stopped.code, "message": "Audio is still stopping. Please try Quit again."})
			return
	var loader := _target(&"StartupLoader")
	if loader != null: await loader.shutdown()
	get_tree().quit()

func show_content_error(result: Dictionary) -> void:
	if is_instance_valid(_content_error_layer): return
	var projected: Dictionary = FATAL_DIAGNOSTIC_PROJECTOR.project_failure(
		"content", "continuation", result.get("code", &"reading_content_error"), result, [])
	if _application_gate != null:
		_application_gate.latch_fatal(projected.value.failure)
	_content_error_layer = CanvasLayer.new()
	_content_error_layer.name = "ContentError"
	_content_error_layer.layer = 128
	_content_error_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_content_error_layer)
	var confirmation: Control = load("res://scripts/ui/desktop/DesktopConfirmation.gd").new()
	confirmation.name = "ContentErrorConfirmation"
	confirmation.theme = load("res://scripts/ui/backup/BackupTheme.gd").build("en", 100)
	var message: String = str(result.get("message", result.get("code", "reading_content_error")))
	for key: String in ["line_id", "position_id", "target_id"]:
		var id: String = str(result.get("details", {}).get(key, ""))
		if not id.is_empty() and id not in message: message += "\n" + id
	confirmation.request = {"title": "Cannot continue", "body": message,
		"confirm": "Quit", "cancelable": false, "warning": false}
	confirmation.finished.connect(func(_accepted: bool): request_quit())
	_content_error_layer.add_child(confirmation)
	for root_child: Node in get_tree().root.get_children():
		if root_child != self: confirmation._suspend(root_child)
	var viewport := get_viewport()
	var retain_quit_focus := func(control: Control) -> void:
		if control != confirmation.confirm_button:
			confirmation.confirm_button.grab_focus()
	viewport.gui_focus_changed.connect(retain_quit_focus)
	confirmation.tree_exiting.connect(func(): viewport.gui_focus_changed.disconnect(retain_quit_focus))
	confirmation.confirm_button.grab_focus()
	get_tree().paused = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()


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
		_state["title_ready"] = true
		_state["ready"] = true
		application_ready.emit()
	else:
		development_subset_ready.emit(mode)
	return {"ok": true, "value": get_startup_state()}

func start_title() -> Dictionary:
	if _started or _start_begun: return _failure(&"bootstrap_already_started", "ApplicationBootstrap starts exactly once")
	_start_begun = true
	_title_phase = true
	_state["started"] = true
	_state["mode"] = MODE_FINAL
	for stage_id: StringName in STAGE_ORDER.slice(0, _runtime_stage_index):
		var result := _run_stage(stage_id, MODE_FINAL)
		if not result.get("ok", false): return _record_startup_stage_failure(stage_id, result)
		_state["completed_stages"].append(stage_id)
	_state["title_ready"] = true
	return {"ok": true}


func prepare_runtime() -> Dictionary:
	_title_phase = false
	var injected := _inject_mutation_gate(FINAL_GATE_TARGETS, MODE_FINAL)
	if not injected.get("ok", false): return _record_startup_stage_failure(&"construct_and_inject_mutation_gate", injected)
	var identity := _construct_identity_issuer_and_contact_commands()
	if not identity.get("ok", false): return _record_startup_stage_failure(&"construct_identity_issuer_and_contact_commands", identity)
	return {"ok": true}


func advance_runtime() -> Dictionary:
	var stage_id: StringName = STAGE_ORDER[_runtime_stage_index]
	var result := _run_stage(stage_id, MODE_FINAL)
	if not result.get("ok", false): return _record_startup_stage_failure(stage_id, result)
	_state["completed_stages"].append(stage_id)
	_runtime_stage_index += 1
	if _runtime_stage_index == STAGE_ORDER.size():
		var published := _publish_startup_route_hold()
		if not published.get("ok", false):
			_state["completed_stages"].erase(&"publish_application_ready")
			return _record_startup_stage_failure(&"publish_application_ready", published)
		_started = true
		_state["title_ready"] = true
		_state["ready"] = true
		application_ready.emit()
	return {"ok": true}


func get_startup_state() -> Dictionary:
	return _state.duplicate(true)

func get_scene_startup_recovery() -> Dictionary:
	return {"ok": true, "value": _scene_startup_recovery.duplicate(true)}


func retry_scene_startup_activation(transaction_id: String) -> Dictionary:
	if _startup_recovery_busy:
		return _failure(&"scene_startup_retry_busy", "Startup recovery is already running")
	if _scene_startup_recovery.is_empty() or transaction_id.is_empty() or transaction_id != _scene_startup_recovery.transaction_id:
		return _failure(&"scene_startup_recovery_unavailable", "No matching scene activation is pending")
	var saves := _target(&"SaveManager")
	if saves == null or not saves.has_method("retry_scene_activation"):
		return _failure(&"scene_activation_unavailable", "Scene activation owner is unavailable")
	_startup_recovery_busy = true
	var failed_stage: StringName = _scene_startup_recovery.failed_stage
	var result: Dictionary = saves.retry_scene_activation(transaction_id)
	if result.get("ok", false):
		if not _startup_route_hold_token.is_empty():
			if _startup_route_owner == null or not _startup_route_owner.has_method("complete_startup_scene_activation"):
				result = _failure(&"scene_startup_route_unavailable", "Scene startup publication owner is unavailable")
			else:
				result = _startup_route_owner.complete_startup_scene_activation(_startup_route_hold_token, transaction_id)
		if result.get("ok", false):
			result = _continue_startup_after_recovery(failed_stage, transaction_id)
		if result.get("ok", false):
			_scene_startup_recovery.clear()
			startup_recovery_changed.emit()
	if not result.get("ok", false):
		_scene_startup_recovery["cause"] = result.duplicate(true)
	_startup_recovery_busy = false
	return result


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
		_state["title_ready"] = true
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
	if result.get("code") == &"scene_activation_pending" and typeof(result.get("transaction_id")) == TYPE_STRING and not str(result.transaction_id).is_empty():
		if not _scene_startup_recovery.is_empty() and _scene_startup_recovery.transaction_id != result.transaction_id:
			return _failure(&"scene_startup_transaction_changed", "Pending scene operation changed")
		_scene_startup_recovery = {"available": true, "transaction_id": result.transaction_id,
			"failed_stage": stage_id, "cause": result.duplicate(true)}
		_state["ready"] = false
		_state["fatal_result"] = {}
		_state["failed_stage"] = stage_id
		_started = true
		startup_recovery_changed.emit()
		return result.duplicate(true)
	print("STARTUP_FAILED stage=%s code=%s" % [stage_id, str(result.get("code", "unknown"))])
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
			var entries: Dictionary = DIALOGIC_ENTRY_MANIFEST.load_default()
			if not entries.get("ok", false): return entries
			var checked_entries: Dictionary = DIALOGIC_ENTRY_MANIFEST.validate_document(entries["value"])
			if not checked_entries.get("ok", false): return checked_entries
			var ids: Dictionary = DIALOGIC_ENTRY_MANIFEST.load_ids_default()
			if not ids.get("ok", false): return ids
			var checked_ids: Dictionary = DIALOGIC_ENTRY_MANIFEST.validate_ids_document(ids["value"])
			if not checked_ids.get("ok", false): return checked_ids
			if not manager.has_method("configure_line_registry"):
				return _failure(&"missing_line_registry_seam", "ProfileManager line registry is unavailable")
			var configured: Dictionary = manager.call(&"configure_line_registry", ids["value"])
			if not configured.get("ok", false): return configured
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
			_saves_storage = JSON_STORAGE.new(_selected_root.path_join("saves"))
			var gated: Dictionary = _saves_storage.configure_before_write(Callable(self, "_flush_before_run_save"))
			if not gated.get("ok", false): return gated
			var save_initialized: Dictionary = save_manager.call(&"initialize", _saves_storage)
			if not save_initialized.get("ok", false):
				return save_initialized
			if save_manager.has_signal("live_session_ready") and not save_manager.is_connected("live_session_ready", _on_saved_session_activated):
				save_manager.connect("live_session_ready", _on_saved_session_activated)
			if _application_gate.has_signal("transaction_released") and not _application_gate.is_connected("transaction_released", _queue_live_continuation):
				_application_gate.connect("transaction_released", _queue_live_continuation)
			if _retained_checkpoint_port == null:
				_retained_checkpoint_port = SAVE_CHECKPOINT_PORT.new(save_manager)
				if _application_gate != null:
					var save_latched: Dictionary = _retained_checkpoint_port.configure_fatal_latch(_application_gate)
					if not save_latched.get("ok", false):
						return save_latched
				if _desktop_identity_nonce_issuer != null:
					var save_issuer: Dictionary = save_manager.call(&"configure_identity_issuer",
						_desktop_identity_nonce_issuer)
					if not save_issuer.get("ok", false):
						return save_issuer
			var profile := _target(&"ProfileManager")
			if profile == null or not profile.has_method("configure_new_run_storage") \
					or not save_manager.has_method("configure_new_run_profile_owner") \
					or not save_manager.has_method("reconcile_new_run_storage"):
				return _failure(&"missing_stage_adapter", "New Acc startup recovery is unavailable")
			var profile_bound: Dictionary = profile.call(&"configure_new_run_storage", _profile_storage)
			if not profile_bound.get("ok", false): return profile_bound
			var recovery_bound: Dictionary = save_manager.call(&"configure_new_run_profile_owner", profile)
			if not recovery_bound.get("ok", false): return recovery_bound
			var scene_creation := _configure_registered_scene_creation()
			if not scene_creation.get("ok", false): return scene_creation
			return save_manager.call(&"reconcile_new_run_storage")
		&"initialize_dialogic_bridge":
			var bridge := _target(&"DialogicBridge")
			var profile := _target(&"ProfileManager")
			if bridge == null or not bridge.has_method("bind_profile_preferences"): return _failure(&"missing_stage_adapter", "DialogicBridge preference binding is unavailable")
			if profile == null: return _failure(&"missing_profile_manager", "ProfileManager dependency is unavailable")
			var bound: Dictionary = bridge.call(&"bind_profile_preferences", profile)
			if not bound.get("ok", false):
				return bound
			if _retained_checkpoint_port == null:
				return bound
			return _wire_narrative_and_ending_ports(bridge)
		&"publish_application_ready":
			var graph := _configure_desktop_production_graph()
			if not graph.get("ok", false):
				return graph
			var capture_bound: Dictionary = _target(&"SaveManager").configure_backup_capture_provider(
				_capture_backup_checkpoint_inputs, _admit_paused_desktop_backup, _can_capture_backup_checkpoint_inputs)
			if not capture_bound.get("ok", false): return capture_bound
			var pause_router := _target(&"SceneRouter")
			if pause_router.has_signal("restore_publication_released") and not pause_router.is_connected("restore_publication_released", _queue_live_continuation):
				pause_router.connect("restore_publication_released", _queue_live_continuation)
			var scene_tree := get_tree()
			if scene_tree != null and not scene_tree.scene_changed.is_connected(_queue_live_continuation):
				scene_tree.scene_changed.connect(_queue_live_continuation)
			if scene_tree != null and not scene_tree.scene_changed.is_connected(_retire_completed_ending_after_menu):
				scene_tree.scene_changed.connect(_retire_completed_ending_after_menu)
			return pause_router.configure_pause_services({
				"game_state": _target(&"GameState"), "saves": _target(&"SaveManager"),
				"bridge": _target(&"DialogicBridge"), "input": _target(&"InputManager"),
				"audio": _target(&"AudioManager"), "gate": _application_gate,
				"profile": _target(&"ProfileManager"), "localization": _target(&"LocalizationManager"),
				"backup_capture": Callable(self, "_capture_paused_checkpoint_inputs"),
				"dating_presentation": _retained_dating_presentation_port})
		&"configure_restore_participants":
			return _configure_restore_participants()
		&"configure_scene_gameplay":
			var identity := _configure_causal_day_advance_identity()
			if not identity.get("ok", false): return identity
			_configure_checkpoint_providers()
			var context: Dictionary = _retained_checkpoint_port.configure_desktop_context_provider(_desktop_host_state)
			if not context.get("ok", false): return context
			var eviction := _ensure_desktop_eviction_port()
			if not eviction.get("ok", false): return eviction
			_connect_desktop_day_change(_target(&"GameState"))
			return {"ok": true}
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
	_application_gate = gate
	return _inject_mutation_gate(targets, mode)


func _inject_mutation_gate(targets: Array, mode: StringName) -> Dictionary:
	var gate: Object = _application_gate
	_state["gate_injection"]["gate_instance_id"] = gate.get_instance_id()
	for target_name: StringName in targets:
		if _title_phase and target_name in [&"GameState", &"SceneRouter"]: continue
		if target_name in _state["gate_injection"]["targets"]: continue
		_state["gate_injection"]["targets"].append(target_name)
		var target := _target(target_name)
		if target == null or not target.has_method("configure_mutation_gate"): return _failure(&"invalid_gate_target", "Gate target is missing or incompatible: %s" % target_name)
		var configured: Dictionary = target.call(&"configure_mutation_gate", gate)
		if not configured.get("ok", false): return configured
		var retained_id: int = configured.get("value", {}).get("gate_instance_id", 0)
		_state["gate_injection"]["target_instance_ids"].append(retained_id)
		if retained_id != gate.get_instance_id(): return _failure(&"mutation_gate_identity_mismatch", "Target retained another gate")
	_application_gate = gate
	if mode == MODE_FINAL and not _title_phase:
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
	if _desktop_issuer_root_store == null:
		_desktop_issuer_root_store = DESKTOP_ISSUER_ROOT_STORE.new()
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
	if _title_phase: return {"ok": true}
	var game_state := _target(&"GameState")
	if game_state == null or not game_state.has_method("configure_identity_issuer"):
		return _failure(&"missing_stage_adapter", "GameState identity seam is unavailable")
	var injected: Dictionary = game_state.call(
		&"configure_identity_issuer", _desktop_identity_nonce_issuer)
	if not injected.get("ok", false):
		return injected
	var scene_runtime: Dictionary = game_state.configure_scene_runtime_validation()
	if not scene_runtime.get("ok", false): return scene_runtime
	var scene_schema: Dictionary = RUN_SNAPSHOT_SCHEMA_FOR_PROBE.configure_scene_validation(_desktop_identity_nonce_issuer, game_state)
	if not scene_schema.get("ok", false): return scene_schema
	var frozen_contacts: Dictionary = game_state.configure_frozen_contacts_contexts()
	if not frozen_contacts.get("ok", false): return frozen_contacts
	if int(injected.get("value", {}).get("issuer_instance_id", 0)) \
			!= _desktop_identity_nonce_issuer.get_instance_id():
		return _failure(&"identity_issuer_mismatch", "GameState retained another issuer")
	if _contact_command_port == null:
		_contact_command_port = load("res://scripts/application/contact/ContactCommandPort.gd").new()
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
	var runtime_adapter: RefCounted = null
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic != null:
		var candidate: RefCounted = load("res://scripts/narrative/DialogicRuntimeAdapter.gd").new()
		if candidate.bind_runtime(dialogic).get("ok", false):
			runtime_adapter = candidate
	var initialized: Dictionary = bridge.call(&"initialize", load("res://scripts/data/DialogicTimelineCatalog.gd"), runtime_adapter)
	if not initialized.get("ok", false):
		return initialized
	if _narrative_checkpoint_adapter == null:
		_narrative_checkpoint_adapter = load("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd").new()
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
	var scene_events := _wire_scene_event_owner(game_state, bridge)
	if not scene_events.get("ok", false): return scene_events
	var adapter_id := _narrative_checkpoint_adapter.get_instance_id()
	if int(bridge_port["value"]["port_instance_id"]) != adapter_id or int(state_port["value"]["port_instance_id"]) != adapter_id:
		return _failure(&"narrative_checkpoint_identity_mismatch", "A consumer retained another narrative adapter")
	if _ending_playback_port == null:
		_ending_playback_port = load("res://scripts/application/ending/DialogicEndingPlaybackPort.gd").new()
		var ending_initialized: Dictionary = _ending_playback_port.initialize(bridge)
		if not ending_initialized.get("ok", false):
			return ending_initialized
	var frozen_endings: Dictionary = game_state.configure_frozen_ending_contexts()
	if not frozen_endings.get("ok", false): return frozen_endings
	var reached_bound: Dictionary = _ending_playback_port.configure_reached_presentations(
		_target(&"ProfileManager"), game_state.capture_ending_presentation_signature,
		game_state.capture_ending_frozen_presentation)
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


func _active_app_id_context() -> Variant:
	if _desktop_host_state == null:
		return null
	var active: Variant = _desktop_host_state.capture_persistent_state().get("active_app_id", null)
	return String(active) if typeof(active) == TYPE_STRING_NAME else active

func _can_capture_backup_checkpoint_inputs() -> bool:
	if not _state.get("ready", false) or _application_gate == null or _checkpoint_provider_bundle.is_empty():
		return false
	if not _application_gate.guard_external(&"backup_capture").get("ok", false): return false
	var router := _target(&"SceneRouter")
	if router != null and get_tree().paused and router.get_current_route_id() == "scene":
		return router.can_capture_pause_backup_checkpoint_inputs()
	return _capture_backup_checkpoint_inputs().get("ok", false)


func _capture_backup_checkpoint_inputs() -> Dictionary:
	if not _state.get("ready", false) or _application_gate == null or _checkpoint_provider_bundle.is_empty():
		return _failure(&"backup_capture_unavailable", "Application owners are not ready")
	var guarded: Dictionary = _application_gate.guard_external(&"backup_capture")
	if not guarded.get("ok", false):
		return guarded
	var router := _target(&"SceneRouter")
	if router != null and get_tree().paused:
		return router.capture_pause_backup_checkpoint_inputs()
	return _failure(&"backup_capture_unavailable", "The paused scene desktop is not ready")


func _admit_paused_desktop_backup(inputs: Dictionary) -> bool:
	var router := _target(&"SceneRouter")
	if router == null or inputs.get("route_id") != "main" or not get_tree().paused: return false
	var paused: Dictionary = router.capture_pause_backup_checkpoint_inputs()
	return paused.get("ok", false) and paused.value == inputs


func _capture_paused_checkpoint_inputs() -> Dictionary:
	var bridge := _target(&"DialogicBridge")
	var game := _target(&"GameState")
	var router := _target(&"SceneRouter")
	if game == null or bridge == null or router == null:
		return _failure(&"backup_capture_unavailable", "Paused gameplay owners are unavailable")
	var route: String = router.get_current_route_id()
	if route not in ["scene", "ending"] or not game._run_lifecycle.is_scene_run():
		return _failure(&"backup_capture_unavailable", "The paused source has no DTL gameplay capture")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not checkpoint.get("ok", false): return checkpoint
	return {"ok": true, "value": {"snapshot_input": game.capture_run_snapshot_input(),
		"dialogic_checkpoint": checkpoint.value, "route_id": route, "active_app_id": null,
		"audio_context": _target(&"AudioManager").get_semantic_audio_context(),
		"content_version": NARRATIVE_CONTENT_VERSION}}

func configure_contacts_desktop(desktop: Node) -> Dictionary:
	if not _state.get("ready", false) or _contact_command_port == null or _desktop_host_state == null:
		return _failure(&"contacts_owners_not_ready", "application owners are not ready")
	if desktop == null or not desktop.has_method("configure_contacts"):
		return _failure(&"invalid_contacts_desktop", "desktop presentation seam required")
	var game_state := _target(&"GameState")
	if _contacts_presentation_port == null:
		_contacts_presentation_port = load("res://scripts/application/contact/ContactsPresentationPort.gd").new()
		var configured: Dictionary = _contacts_presentation_port.configure(game_state, _contact_command_port, load("res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd").build())
		if not configured.get("ok", false):
			_contacts_presentation_port = null
			return configured
	var registered := _ensure_desktop_eviction_port()
	if not registered.get("ok", false):
		return registered
	_contacts_desktop_eviction_port.view = weakref(desktop)
	var mounted: Dictionary = desktop.configure_contacts(_contacts_presentation_port,
		_target(&"LocalizationManager"), _target(&"ProfileManager"),
		_desktop_host_state, int(game_state.day))
	return mounted


func _configure_checkpoint_providers() -> void:
	_checkpoint_provider_bundle = {
		"dialogic_checkpoint": Callable(_target(&"DialogicBridge"), "get_current_narrative_checkpoint"),
		"route_id": Callable(_target(&"SceneRouter"), "get_current_route_id"),
		"active_app_id": Callable(self, "_active_app_id_context"),
		"audio_context": Callable(_target(&"AudioManager"), "get_semantic_audio_context"),
		"content_version": Callable(self, "_content_version_context"),
	}

func _content_version_context() -> int:
	return NARRATIVE_CONTENT_VERSION


func get_desktop_contract_state() -> Dictionary:
	var state := {
		"root_store_instance_id": _instance_id(_desktop_issuer_root_store),
		"issuer_instance_id": _instance_id(_desktop_identity_nonce_issuer),
		"contact_command_port_instance_id": _instance_id(_contact_command_port),
		"causal_day_advance_identity_port_instance_id": _instance_id(_retained_causal_day_advance_identity_port),
		"dating_presentation_port_instance_id": _instance_id(_retained_dating_presentation_port),
		"dating_presentation_ready": _retained_dating_presentation_port != null and _retained_dating_presentation_port.is_ready(),
	}
	state.merge(_desktop_amendment_probe_fields())
	return state

func _desktop_amendment_probe_fields() -> Dictionary:
	var save_manager := _target(&"SaveManager")
	var game_state := _target(&"GameState")
	var continuation_journal: Object = save_manager.get("_continuation_journal") if save_manager != null else null
	var restore_participant_ids := {
	}
	for key: String in ["run", "desktop_consequence", "desktop_board", "schedule_view", "profile",
			"localization", "audio", "route", "narrative"]:
		restore_participant_ids[key] = _instance_id(
			_retained_restore_participants.get(key) if _retained_restore_participants.has(key) else null)
	var desktop_graph_constructed := _retained_minesweeper_round_coordinator_app != null \
		and _retained_minesweeper_generation_port != null and _retained_dating_physical_owner != null
	return {
		"mutation_gate_instance_id": _instance_id(_application_gate),
		"continuation_journal_instance_id": _instance_id(continuation_journal),
		"desktop_publication_ledger_instance_id": _instance_id(_retained_desktop_publication_ledger),
		"host_instance_id": _instance_id(_desktop_host_state),
		"board_state_instance_id": _instance_id(_desktop_board_state),
		"consequence_state_instance_id": _instance_id(_desktop_consequence_state),
		"admission_checkpoint_port_instance_id": _instance_id(_retained_checkpoint_port),
		"minesweeper_round_source_port_instance_id": _instance_id(_retained_minesweeper_round_coordinator_app),
		"game_state_desktop_board_port_instance_id": _instance_id(_retained_game_state_desktop_board_port),
		"save_manager_desktop_board_port_instance_id": _instance_id(_retained_save_manager_desktop_board_port),
		"snapshot_provider_instance_id": _instance_id(game_state),
		"restore_order": _RESTORE_ORDER.duplicate(),
		"restore_participant_instance_ids": restore_participant_ids,
		"run_snapshot_schema_version": RUN_SNAPSHOT_SCHEMA_VERSION,
		"save_document_schema_version": SAVE_DOCUMENT_SCHEMA_VERSION,
		"registry_versions": {"minesweeper_shop": load("res://scripts/domain/shop/MinesweeperShopRegistry.gd").REGISTRY_VERSION},
		"desktop_graph_constructed": desktop_graph_constructed,
	}


static func _instance_id(retained: Object) -> int:
	return retained.get_instance_id() if retained != null else 0


func _configure_causal_day_advance_identity() -> Dictionary:
	if _desktop_identity_nonce_issuer == null:
		return _failure(&"missing_identity_issuer",
			"the causal day advance identity port requires the retained production issuer")
	if _retained_causal_day_advance_identity_port == null:
		_retained_causal_day_advance_identity_port = load("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd").new()
		var issuer_bound: Dictionary = _retained_causal_day_advance_identity_port.configure(
			_desktop_identity_nonce_issuer)
		if not issuer_bound.get("ok", false):
			_retained_causal_day_advance_identity_port = null
			return issuer_bound
	return {"ok": true}


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
		_desktop_host_state = load("res://scripts/domain/desktop/DesktopAppHostState.gd").new()
		var day: int = 1
		if game_state.get("day") != null:
			day = int(game_state.get("day"))
		_desktop_host_state.reset(day)
	var route_participant: RefCounted = load("res://scripts/application/restore/RouteRestoreParticipant.gd").new(router)
	var host_configured: Dictionary = route_participant.configure_desktop_host(_desktop_host_state)
	if not host_configured.get("ok", false):
		return host_configured
	if _desktop_consequence_state == null:
		_desktop_consequence_state = load("res://scripts/domain/desktop/DesktopConsequenceState.gd").new()
	if _desktop_board_state == null:
		_desktop_board_state = load("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
		var scene_payments: Dictionary = _desktop_board_state.configure_scene_payments(_desktop_identity_nonce_issuer)
		if not scene_payments.get("ok", false): return scene_payments
	var selected: Dictionary = DIALOGIC_ENTRY_MANIFEST.scene_contract_tables()
	if not selected.get("ok", false):
		return selected
	var participants := {
		"run": load("res://scripts/application/restore/RunRestoreParticipant.gd").new(game_state),
		"desktop_consequence": load("res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd").new(_desktop_consequence_state),
		"desktop_board": load("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd").new(_desktop_board_state, _desktop_identity_nonce_issuer),
		"profile": load("res://scripts/application/restore/ProfileRestoreParticipant.gd").new(profile),
		"localization": load("res://scripts/application/restore/LocalizationRestoreParticipant.gd").new(localization),
		"audio": load("res://scripts/application/restore/AudioRestoreParticipant.gd").new(audio),
		"route": route_participant,
		"narrative": load("res://scripts/application/restore/NarrativeRestoreParticipant.gd").new(bridge),
	}
	if window_capability.value.available:
		var configured_window: Dictionary = participants.profile.configure_window_output(window)
		if not configured_window.get("ok", false): return configured_window
	var configured: Dictionary = save_manager.configure_scene_restore_participants(participants)
	if configured.get("ok", false):
		_retained_restore_participants = participants.duplicate()
		var scene_runtime := _configure_registered_scene_runtime()
		if not scene_runtime.get("ok", false): return scene_runtime
	return configured


func _configure_registered_scene_creation() -> Dictionary:
	var selected: Dictionary = DIALOGIC_ENTRY_MANIFEST.scene_contract_tables()
	if not selected.get("ok", false):
		return selected
	var saves := _target(&"SaveManager")
	var configured: Dictionary = saves.configure_scene_new_run(_target(&"DialogicBridge"))
	if not configured.get("ok", false): return configured
	var first_target: String = DIALOGIC_ENTRY_MANIFEST.first_target_id()
	if first_target.is_empty() or selected.bundle.get("schema_version") != 3: return {"ok": true}
	return saves.configure_scene_title_new_run(first_target)

func _configure_registered_scene_runtime() -> Dictionary:
	var selected: Dictionary = DIALOGIC_ENTRY_MANIFEST.scene_contract_tables()
	if not selected.get("ok", false):
		return selected
	if not DIALOGIC_ENTRY_MANIFEST.first_target_id().is_empty() and FileAccess.file_exists("res://data/manifests/scene_ending_reading_catalogue.json") and OS.get_environment("DWM_SCENE_READING_FIXTURE") != "1" and not OS.get_cmdline_user_args().has(DIALOGIC_ENTRY_MANIFEST.SCENE_TEST_FLAG) and not OS.get_cmdline_args().has(DIALOGIC_ENTRY_MANIFEST.SCENE_TEST_FLAG):
		var catalogue: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
			FileAccess.get_file_as_string("res://data/manifests/scene_ending_reading_catalogue.json"))
		if not catalogue.get("ok", false): return catalogue
		var configured: Dictionary = _target(&"DialogicBridge").configure_reading_catalogue(catalogue.value)
		if not configured.get("ok", false): return configured
	var saves := _target(&"SaveManager")
	var game := _target(&"GameState")
	var router := _target(&"SceneRouter")
	var proof: Dictionary = RUN_SNAPSHOT_SCHEMA_FOR_PROBE.configure_scene_validation(
		_desktop_identity_nonce_issuer, game, saves)
	if not proof.get("ok", false): return proof
	return router.configure_scene_host("res://scenes/narrative/SceneHost.tscn")


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
		_retained_minesweeper_state_port = load("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd").new(game_state)
	var reward_configured: Dictionary = _retained_minesweeper_state_port.configure(_application_gate)
	if not reward_configured.get("ok", false): return reward_configured

	var snapshot_bound: Dictionary = game_state.configure_desktop_snapshot_provider(Callable(self, "_capture_live_desktop_snapshot"))
	if not snapshot_bound.get("ok", false): return snapshot_bound
	if _scene_shop_catalog == null: _scene_shop_catalog = load("res://scripts/data/DataCatalog.gd").new()
	var shop_bound: Dictionary = game_state.configure_scene_shop_runtime(_scene_shop_catalog, _desktop_consequence_state)
	if not shop_bound.get("ok", false): return shop_bound
	var day_bound: Dictionary = game_state.configure_scene_day_runtime(_retained_causal_day_advance_identity_port, _desktop_board_state, _desktop_consequence_state)
	if not day_bound.get("ok", false): return day_bound
	var scene_round_bound: Dictionary = game_state.configure_scene_round_runtime(_desktop_board_state, _retained_minesweeper_state_port)
	if not scene_round_bound.get("ok", false): return scene_round_bound

	if _retained_desktop_publication_ledger == null:
		var ledger: RefCounted = load("res://scripts/infrastructure/save/DesktopPublicationLedger.gd").new()
		var ledger_configured: Dictionary = ledger.configure(_profile_storage)
		if not ledger_configured.get("ok", false):
			return ledger_configured
		var ledger_loaded: Dictionary = ledger.load()
		if not ledger_loaded.get("ok", false):
			return ledger_loaded
		_retained_desktop_publication_ledger = ledger
	var ledger: RefCounted = _retained_desktop_publication_ledger

	var save_manager := _target(&"SaveManager")
	if save_manager != null and save_manager.has_method("reconcile_incomplete_continuations"):
		var reconciled: Dictionary = save_manager.call(&"reconcile_incomplete_continuations")
		if not reconciled.get("ok", false):
			return reconciled

	if _desktop_identity_provider.is_null():
		_desktop_identity_provider = Callable(game_state, "capture_desktop_identity_context")
	if not _desktop_identity_provider.is_valid():
		return _failure(&"desktop_identity_unavailable", "GameState live identity is required")

	if _retained_game_state_desktop_board_port == null:
		var board_port: RefCounted = load("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd").new()
		var board_port_configured: Dictionary = board_port.configure(
			game_state, _desktop_identity_nonce_issuer, _desktop_identity_provider)
		if not board_port_configured.get("ok", false):
			return board_port_configured
		_retained_game_state_desktop_board_port = board_port
	var board_consequence: Dictionary = _retained_game_state_desktop_board_port.configure_consequence_state_port(_desktop_consequence_state)
	if not board_consequence.get("ok", false): return board_consequence

	if _retained_minesweeper_round_coordinator_app == null:
		var round_coordinator: RefCounted = load("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd").new()
		round_coordinator.set("_board_state", _desktop_board_state)
		var round_ledger: Dictionary = round_coordinator.configure_publication_ledger(ledger)
		if not round_ledger.get("ok", false):
			return round_ledger
		var save_board_port: RefCounted = load("res://scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd").new(_retained_checkpoint_port)
		var save_board_configured: Dictionary = save_board_port.configure(_retained_checkpoint_port)
		if not save_board_configured.get("ok", false):
			return save_board_configured
		var save_audio: Dictionary = save_board_port.configure_audio_context_capture(
			Callable(_target(&"AudioManager"), &"get_semantic_audio_context"))
		if not save_audio.get("ok", false): return save_audio
		var save_scene: Dictionary = save_board_port.configure_scene_context_capture(
			Callable(self, "_capture_desktop_board_scene_context"))
		if not save_scene.get("ok", false): return save_scene
		_retained_save_manager_desktop_board_port = save_board_port
		var durable: Dictionary = round_coordinator.configure_durable_checkpoint(
			save_board_port, load("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd"), _desktop_consequence_state)
		if not durable.get("ok", false):
			return durable
		_retained_minesweeper_generation_port = load("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd").new()
		var playable: Dictionary = round_coordinator.configure(_retained_game_state_desktop_board_port,
			save_board_port, _retained_minesweeper_generation_port, _desktop_identity_nonce_issuer)
		if not playable.get("ok", false): return playable
		_retained_minesweeper_round_coordinator_app = round_coordinator

	var rewards: Dictionary = _retained_minesweeper_round_coordinator_app.configure_reward_port(_retained_minesweeper_state_port)
	if not rewards.get("ok", false): return rewards
	var completion: Dictionary = _retained_minesweeper_round_coordinator_app.configure_scene_completion(game_state)
	if not completion.get("ok", false): return completion
	if _retained_dating_presentation_port == null:
		_retained_dating_presentation_port = load("res://scripts/application/run/DatingPresentationPort.gd").new()
	if _retained_dating_physical_owner == null:
		var owner: RefCounted = load("res://scripts/application/run/DatingPhysicalOwner.gd").new()
		var configured: Dictionary = owner.configure(_desktop_identity_nonce_issuer,
			game_state, _target(&"ProfileManager"), _retained_minesweeper_generation_port)
		if not configured.get("ok", false): return configured
		_retained_dating_physical_owner = owner
	var history: Dictionary = _retained_dating_physical_owner.configure_attempt_history(_application_gate)
	if not history.get("ok", false): return history
	var restored: Dictionary = game_state.configure_dating_restore_reconciler(
		Callable(_retained_dating_physical_owner, "reconcile_restore_silent"))
	if not restored.get("ok", false): return restored
	var challenge: Dictionary = _retained_dating_presentation_port.configure(
		_desktop_identity_nonce_issuer, _retained_dating_physical_owner)
	if not challenge.get("ok", false): return challenge
	return {"ok": true}


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
	var state_port: RefCounted = _retained_minesweeper_state_port
	if state_port == null:
		state_port = load("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd").new(game_state)
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
	var save_port: RefCounted = _retained_minesweeper_save_port
	if save_port == null:
		save_port = load("res://scripts/application/minesweeper/SaveManagerMinesweeperPort.gd").new()
	var save_configured: Dictionary = save_port.configure(_retained_checkpoint_port, save_manager)
	if not save_configured.get("ok", false):
		return save_configured
	if int(save_configured.get("value", {}).get("checkpoint_port_instance_id", 0)) \
			!= _retained_checkpoint_port.get_instance_id():
		return _failure(&"checkpoint_port_identity_mismatch", "Minesweeper save port retained another checkpoint port")
	_retained_minesweeper_save_port = save_port
	var coordinator: RefCounted = _retained_minesweeper_coordinator
	if coordinator == null:
		coordinator = load("res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd").new()
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


func _connect_desktop_day_change(game_state: Object) -> void:
	if game_state == null or not game_state.has_signal("day_changed"):
		return
	if not game_state.day_changed.is_connected(_on_day_changed):
		game_state.day_changed.connect(_on_day_changed)


func _ensure_desktop_eviction_port() -> Dictionary:
	if _contacts_desktop_eviction_port == null:
		_contacts_desktop_eviction_port = ContactsDesktopEvictionPort.new()
	return register_desktop_eviction_port(_contacts_desktop_eviction_port)


func register_desktop_eviction_port(port: Object) -> Dictionary:
	if port == null or not port.has_method("dispatch_desktop_eviction"):
		return _failure(&"invalid_desktop_eviction_port", "port must expose dispatch_desktop_eviction")
	if _desktop_eviction_port != null and is_instance_valid(_desktop_eviction_port):
		if port == _desktop_eviction_port:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _failure(&"desktop_eviction_port_already_configured", "a desktop eviction port is already configured")
	_desktop_eviction_port = port
	return {"ok": true, "code": &"ok", "value": {"port_instance_id": _desktop_eviction_port.get_instance_id()}, "receipt": {}}


func _on_day_changed(new_day: int) -> void:
	if _desktop_host_state == null:
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


func configure_session_exit_desktop(desktop: Node) -> Dictionary:
	if desktop == null or not desktop.has_method("configure_session_exit"):
		return _failure(&"invalid_exit_desktop", "")
	if desktop.has_meta("session_exit"): return {"ok": true}
	var exit: RefCounted = load("res://scripts/application/desktop/SessionExitCoordinator.gd").new()
	var configured: Dictionary = exit.configure(_target(&"GameState"), _target(&"SceneRouter"), _application_gate)
	if not configured.get("ok", false): return configured
	configured = desktop.configure_session_exit(exit)
	if configured.get("ok", false): desktop.set_meta("session_exit", exit)
	return configured


func _flush_before_run_save() -> Dictionary:
	if _desktop_identity_nonce_issuer != null:
		var flushed: Dictionary = _desktop_identity_nonce_issuer.flush()
		if not flushed.get("ok", false): return flushed
	if _retained_dating_physical_owner != null and _retained_dating_physical_owner.has_method("flush_pending_attempt"):
		return _retained_dating_physical_owner.flush_pending_attempt()
	return {"ok": true}


func _commit_ending_checkpoint() -> Dictionary:
	var game := _target(&"GameState")
	var lifecycle: Dictionary = game._run_lifecycle.to_dict()
	if lifecycle.get("ending_plan") is Dictionary and lifecycle.ending_plan.get("source_kind") == "scene":
		if _retained_checkpoint_port == null: return _failure(&"presentation_checkpoint_unavailable", "")
		var bridge := _target(&"DialogicBridge")
		var reading: Dictionary = bridge.capture_ending_physical_checkpoint()
		if not reading.get("ok", false): return reading
		var inputs := {"snapshot_input": game.capture_run_snapshot_input(), "route_id": "ending",
			"dialogic_checkpoint": reading.value, "active_app_id": null,
			"audio_context": _target(&"AudioManager").get_semantic_audio_context(),
			"content_version": NARRATIVE_CONTENT_VERSION}
		var backup: Dictionary = _retained_checkpoint_port.capture()
		if not backup.get("ok", false): return backup
		var prepared: Dictionary = _retained_checkpoint_port.prepare(inputs, &"safe_marker", {"kind": &"autosave", "reason": &"automatic"})
		if not prepared.get("ok", false): return prepared
		var committed: Dictionary = _retained_checkpoint_port.commit(prepared.value.candidate)
		if not committed.get("ok", false) and not committed.get("committed", false):
			var rolled: Dictionary = _retained_checkpoint_port.rollback({"journal_backup": backup.value.backup,
				"storage_backup": prepared.value.candidate.storage_backup})
			if not rolled.get("ok", false): return rolled
		return committed
	return _failure(&"presentation_checkpoint_unavailable", "DTL ending required")


func configure_gallery_replay_services(scene: Node) -> Dictionary:
	if not _state.get("ready", false) or not is_inside_tree() or get_tree().current_scene != scene:
		return _failure(&"gallery_replay_services_unavailable", "The current title is not ready")
	if scene == null or not scene.has_method("configure_gallery_replay"):
		return _failure(&"gallery_replay_services_unavailable", "The title cannot accept replay services")
	var replay: Dictionary = scene.configure_gallery_replay(_target(&"ProfileManager"), _target(&"DialogicBridge"))
	if not replay.get("ok", false): return replay
	return replay


func _on_saved_session_activated() -> void:
	if _retained_checkpoint_port != null:
		_retained_checkpoint_port.clear_transient_consequence_checkpoints()
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
	if get_tree().current_scene == null: return
	var lifecycle: Dictionary = game_state._run_lifecycle.to_dict()
	if game_state._run_lifecycle.is_scene_run():
		_pending_live_continuation = {}
		if lifecycle.get("state") == "COMPLETED" and not lifecycle.has("ending_plan"):
			game_state.return_completed_scene_passage.call_deferred()
		return
	_pending_live_continuation = {}

func _retire_completed_ending_after_menu() -> void:
	var scene := get_tree().current_scene
	var router := _target(&"SceneRouter")
	var game := _target(&"GameState")
	var bridge := _target(&"DialogicBridge")
	if scene == null or scene.scene_file_path != "res://scenes/menu/MenuScene.tscn" \
			or router == null or router.get_current_route_id() != "menu" \
			or router.is_restore_publication_held() or game == null or bridge == null \
			or bridge.has_active_playback() or not bridge.has_reading_session(): return
	var lifecycle: Dictionary = game._run_lifecycle.to_dict()
	var session: Dictionary = game.capture_live_session()
	if lifecycle.get("state") != "COMPLETED" or not session.get("ok", false) \
			or session.value.get("active", true): return
	var captured: Dictionary = bridge.capture_ending_physical_checkpoint()
	if not captured.get("ok", false) or captured.value.is_empty(): return
	if captured.value.reading_session.ledger.session_token != str(lifecycle.run_id) + ":ending": return
	bridge.retire_reading_session()


var _scene_staging_wired := false
var _scene_event_command_port: RefCounted

func _wire_scene_event_owner(game_state: Node, bridge: Node) -> Dictionary:
	if not _scene_staging_wired:
		var source: Dictionary = game_state.configure_scene_checkpoint_source(_target(&"SaveManager"))
		if not source.get("ok", false): return source
		var audio_source: Dictionary = _narrative_checkpoint_adapter.configure_scene_audio_source(
			Callable(game_state, "capture_scene_entry_audio"))
		if not audio_source.get("ok", false): return audio_source
		var staged: Dictionary = bridge.configure_scene_staging(_narrative_checkpoint_adapter,
			Callable(game_state, "validate_scene_entry_staging_source"), Callable(game_state, "scene_entry_staging_context"))
		if not staged.get("ok", false): return staged
		_scene_staging_wired = true
	if _scene_event_command_port == null:
		_scene_event_command_port = load("res://scripts/application/narrative/SceneEventCommandPort.gd").new()
		var bound: Dictionary = game_state.configure_scene_event_owner(bridge)
		if not bound.get("ok", false): return bound
		var configured: Dictionary = _scene_event_command_port.configure(game_state,
			_application_gate, _desktop_identity_nonce_issuer)
		if not configured.get("ok", false): return configured
	return bridge.configure_scene_event_port(_scene_event_command_port, Callable(game_state, "validate_live_session"),
		Callable(game_state, "scene_event_context"))


func configure_scene_host_view(host: Control) -> void:
	host.configure_scene_controls({
		"computer_open": open_scene_computer.bind(host),
		"computer_close": close_scene_computer.bind(host),
		"contacts": open_scene_contacts.bind(host),
		"apps": open_scene_apps.bind(host),
		"settings": open_scene_settings.bind(host),
		"backup": open_scene_backup.bind(host, "backup"),
		"save": open_scene_backup.bind(host, "save"),
		"load": open_scene_backup.bind(host, "load")})

func _scene_host_admitted(host: Control) -> bool:
	return is_instance_valid(host) and host == get_tree().current_scene \
		and _state.get("ready", false) and _target(&"SceneRouter").get_current_route_id() == "scene" \
		and not _target(&"SceneRouter").is_restore_publication_held()

func _capture_desktop_board_scene_context(projected_input: Dictionary) -> Dictionary:
	var host: Node = get_tree().current_scene
	if not host is Control or host.scene_file_path != "res://scenes/narrative/SceneHost.tscn" \
			or not _scene_host_admitted(host):
		return _failure(&"scene_host_unavailable", "")
	var game := _target(&"GameState")
	var bridge := _target(&"DialogicBridge")
	var session: Dictionary = game.capture_live_session()
	if not session.get("ok", false): return session
	var internal: bool = _application_gate.is_internal_owner_active(&"causal_transaction")
	var admitted: Dictionary = game.capture_desktop_identity_context() if internal else game.validate_live_session(session.value)
	if not admitted.get("ok", false): return admitted
	var live: Dictionary = game.capture_run_snapshot_input()
	for key: String in ["lifecycle", "scene", "contacts", "command_receipts",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		if not projected_input.has(key) or projected_input[key] != live.get(key):
			return _failure(&"stale_scene_checkpoint_source", key)
	var active_app: Variant = _active_app_id_context()
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not reading.get("ok", false): return reading
	admitted = game.capture_desktop_identity_context() if internal else game.validate_live_session(session.value)
	if not admitted.get("ok", false): return admitted
	if game.capture_live_session() != session or game.capture_run_snapshot_input() != live \
			or internal != _application_gate.is_internal_owner_active(&"causal_transaction") \
			or active_app != _active_app_id_context() or not _scene_host_admitted(host):
		return _failure(&"stale_scene_checkpoint_source", "")
	return {"ok": true, "value": {"route_id": "scene", "active_app_id": active_app,
		"content_version": NARRATIVE_CONTENT_VERSION, "dialogic_checkpoint": reading.value}}

func open_scene_computer(host: Control) -> Dictionary:
	if not _scene_host_admitted(host): return _failure(&"scene_host_unavailable", "")
	var guarded: Dictionary = _application_gate.guard_external(&"scene_computer")
	if not guarded.get("ok", false): return guarded
	var game := _target(&"GameState")
	var configured: Dictionary = game.configure_scene_challenge_runtime()
	if not configured.get("ok", false): return configured
	var cue: Dictionary = _target(&"DialogicBridge")._admit_caption_challenge_on_open()
	if not cue.get("ok", false): return cue
	var captured: Dictionary = game.capture_scene_challenge_command()
	if not captured.get("ok", false):
		return open_scene_apps(host)
	configured = _retained_dating_physical_owner.configure_scene_challenges(captured.value.bundle, game)
	if not configured.get("ok", false): return configured
	var admitted: Dictionary = _retained_dating_presentation_port.begin(captured.value.command)
	if not admitted.get("ok", false): return admitted
	var mount: Control = host.get_challenge_mount()
	var panel: Control = mount.get_node_or_null("SceneChallengePanel")
	if panel == null:
		panel = load("res://scripts/ui/SceneChallengePanel.gd").new()
		mount.add_child(panel)
		if not panel.bind(_retained_dating_presentation_port, admitted.value.presentation_command):
			panel.queue_free()
			return _failure(&"scene_panel_unbound", "")
		panel.bind_view_preferences(_target(&"ProfileManager"))
		panel.configure_input(_target(&"InputManager"))
		panel.presentation_changed.connect(_scene_challenge_published.bind(host, panel))
		panel.home_requested.connect(func(): host._invoke("apps"))
	var held: Dictionary = _target(&"DialogicBridge").hold_computer_captions(host)
	if not held.get("ok", false):
		if held.get("recovery_required", false): host.set_computer_open(true)
		return held
	host.set_computer_content_visible(false)
	host.set_computer_open(true)
	var profile := _target(&"ProfileManager")
	var locale := _target(&"LocalizationManager")
	var configuration: Dictionary = game.get_run_configuration()
	var palette: StringName = &"midnight" if configuration.get("value", {}).get("dark_mode", false) else &"after_hours"
	panel.configure_scene(locale.get_locale(), int(profile.get_preference(&"preferences.accessibility.text_size", 125)),
		bool(profile.get_preference(&"preferences.accessibility.large_targets", false)), palette,
		bool(profile.get_preference(&"preferences.accessibility.high_contrast", false)),
		str(profile.get_preference(&"preferences.accessibility.colour_differentiation", "standard")),
		str(profile.get_preference(&"preferences.accessibility.font_style", "pixel")))
	if not panel.open_panel():
		close_scene_computer(host)
		return _failure(&"scene_panel_unavailable", "")
	return {"ok": true}

func _scene_challenge_published(host: Control, panel: Control) -> void:
	if panel.public_view.get("phase") == "terminal":
		_complete_scene_challenge.call_deferred(host, panel)

func _complete_scene_challenge(host: Control, panel: Control) -> void:
	if not is_instance_valid(panel) or not _scene_host_admitted(host) or not host.is_computer_open() \
			or panel.public_view.get("phase") != "terminal": return
	var game := _target(&"GameState")
	var current: Dictionary = game.capture_scene_challenge_command()
	if not current.get("ok", false): return
	var presented: Dictionary = panel._command.duplicate(true)
	presented.erase("physical_token")
	if presented != current.value.command: return
	var released: Dictionary = close_scene_computer(host)
	if not released.get("ok", false):
		panel.presentation_failed.emit(StringName(released.get("code", "scene_continuation_refused")))
		return
	var continued: Dictionary = game.continue_completed_scene_challenge()
	if not continued.get("ok", false):
		_target(&"DialogicBridge").hold_computer_captions(host)
		host.set_computer_open(true)
		panel.show()
		panel.presentation_failed.emit(StringName(continued.get("code", "scene_continuation_refused")))

func close_scene_computer(host: Control) -> Dictionary:
	if not _scene_host_admitted(host): return _failure(&"scene_host_unavailable", "")
	var guarded: Dictionary = _application_gate.guard_external(&"scene_computer")
	if not guarded.get("ok", false): return guarded
	var desktop: Control = host.get_computer_mount().get_node_or_null("SceneComputerDesktop")
	if desktop != null and host.is_computer_open():
		var home: Dictionary = desktop.prepare_scene_close()
		if not home.get("ok", false): return home
	var released: Dictionary = _target(&"DialogicBridge").release_computer_captions(host)
	if not released.get("ok", false): return released
	if desktop != null and host.is_computer_open():
		var home: Dictionary = desktop.return_home()
		if not home.get("ok", false):
			var held: Dictionary = _target(&"DialogicBridge").hold_computer_captions(host)
			return home if held.get("ok", false) else held
	var panel: Control = host.get_challenge_mount().get_node_or_null("SceneChallengePanel")
	if panel != null: panel.close_panel()
	host.set_computer_open(false)
	return {"ok": true}

func open_scene_settings(host: Control) -> Dictionary:
	var opened := open_scene_apps(host)
	if not opened.get("ok", false): return opened
	var desktop: Control = host.get_computer_mount().get_node("SceneComputerDesktop")
	return desktop.open_app(&"settings")

func open_scene_backup(host: Control, mode: String) -> Dictionary:
	if not _scene_host_admitted(host): return _failure(&"scene_host_unavailable", "")
	var closed: Dictionary = close_scene_computer(host)
	if not closed.get("ok", false): return closed
	return await _target(&"SceneRouter")._production_pause.open_scene_backup(mode)


func open_scene_contacts(host: Control) -> Dictionary:
	var opened := open_scene_apps(host)
	if not opened.get("ok", false): return opened
	var desktop: Control = host.get_computer_mount().get_node("SceneComputerDesktop")
	return desktop.open_app(&"contacts")


func _scene_shell_input_admitted(host: Control) -> bool:
	return _scene_host_admitted(host) and host.is_computer_open() \
		and _target(&"DialogicBridge").is_computer_caption_held() \
		and _application_gate.guard_external(&"scene_desktop").get("ok", false)

func _scene_desktop_phase() -> StringName:
	return StringName(_desktop_board_state.capture().phase)

func _scene_desktop_dispatch(command: Dictionary, panel: RefCounted) -> Dictionary:
	var kind: String = str(command.get("kind", ""))
	if kind in ["open_app", "hide_app"]: return {"ok": true}
	if kind not in ["suspend_board", "resume_board"]:
		return _failure(&"invalid_scene_desktop_command", "")
	var board: Dictionary = _desktop_board_state.capture()
	return panel.set_foreground(kind == "resume_board", int(board.revision))

func _prepare_scene_desktop_app(app_id: StringName, app: Control, ports: Dictionary) -> Dictionary:
	var locale := _target(&"LocalizationManager")
	var profile := _target(&"ProfileManager")
	var configuration: Dictionary = _target(&"GameState").get_run_configuration()
	if not configuration.get("ok", false): return configuration
	var palette: StringName = &"midnight" if configuration.value.dark_mode else &"after_hours"
	match app_id:
		&"settings": return app.configure_scene_run_presentation(palette)
		&"contacts": return app.configure_scene_presentation(ports.contacts, locale, profile, palette)
		&"shop": return app.configure_scene_catalog(ports.shop, locale, profile, palette)
		&"minesweeper": return app.configure_scene_presentation(ports.panel, locale, profile, _target(&"InputManager"), palette)
	return _failure(&"scene_external_action_required", "")

func _ensure_scene_desktop(host: Control) -> Dictionary:
	var mount: Control = host.get_computer_mount()
	var desktop: Control = mount.get_node_or_null("SceneComputerDesktop")
	if desktop != null: return {"ok": true, "value": desktop}
	var game := _target(&"GameState")
	var session: Dictionary = game.capture_live_session()
	if not session.get("ok", false): return session
	var admitted: Dictionary = game.validate_live_session(session.value)
	if not admitted.get("ok", false): return admitted
	var contacts: RefCounted = load("res://scripts/application/contact/ContactsPresentationPort.gd").new()
	var configured: Dictionary = contacts.configure(game, _contact_command_port)
	if not configured.get("ok", false): return configured
	var panel: RefCounted = load("res://scripts/application/minesweeper/MinesweeperPanelPort.gd").new()
	configured = panel.configure(_retained_minesweeper_round_coordinator_app,
		_desktop_identity_nonce_issuer, game, _scene_shop_catalog)
	if not configured.get("ok", false): return configured
	var shop: RefCounted = load("res://scripts/application/shop/ShopPresentationPort.gd").new()
	configured = shop.configure_scene(game, _scene_shop_catalog, _desktop_identity_nonce_issuer, _application_gate)
	if not configured.get("ok", false): return configured
	var ports := {"contacts": contacts, "panel": panel, "shop": shop}
	desktop = load("res://scenes/desktop/ComputerDesktop.tscn").instantiate()
	desktop.name = "SceneComputerDesktop"
	configured = desktop.configure_scene_navigation(_desktop_host_state, _scene_desktop_phase,
		_scene_desktop_dispatch.bind(panel), _prepare_scene_desktop_app.bind(ports),
		_target(&"LocalizationManager"), _target(&"ProfileManager"))
	if not configured.get("ok", false):
		desktop.free()
		return configured
	configured = desktop.configure_scene_shell_actions(_open_scene_external_app.bind(host), _scene_shell_input_admitted.bind(host))
	if not configured.get("ok", false):
		desktop.free()
		return configured
	desktop.set_meta("scene_ports", ports)
	mount.add_child(desktop)
	mount.resized.connect(_layout_scene_desktop.bind(host, desktop))
	_layout_scene_desktop(host, desktop)
	return {"ok": true, "value": desktop}

func _layout_scene_desktop(host: Control, desktop: Control) -> void:
	if not is_instance_valid(host) or not is_instance_valid(desktop): return
	var available: Vector2 = host.get_computer_mount().size
	desktop.scale = Vector2.ONE * maxf(0.1, minf(available.x / 968.0, available.y / 720.0))
	desktop.size = Vector2(968, available.y / desktop.scale.y)
	desktop.position = Vector2.ZERO

func open_scene_apps(host: Control) -> Dictionary:
	if not _scene_host_admitted(host): return _failure(&"scene_host_unavailable", "")
	var guarded: Dictionary = _application_gate.guard_external(&"scene_desktop")
	if not guarded.get("ok", false): return guarded
	var prepared := _ensure_scene_desktop(host)
	if not prepared.get("ok", false): return prepared
	var desktop: Control = prepared.value
	var held: Dictionary = _target(&"DialogicBridge").hold_computer_captions(host)
	if not held.get("ok", false):
		if held.get("recovery_required", false): host.set_computer_open(true)
		return held
	host.set_computer_open(true)
	var active: Variant = _desktop_host_state.get_state().get("active_app_id")
	if active != null and active not in [&"settings", &"backup"] and desktop._active_id == &"":
		var restored: Dictionary = desktop.open_app(StringName(active))
		if not restored.get("ok", false): return restored
	var home: Dictionary = desktop.return_home()
	if not home.get("ok", false): return home
	var panel: Control = host.get_challenge_mount().get_node_or_null("SceneChallengePanel")
	if panel != null: panel.close_panel()
	host.set_computer_content_visible(true)
	host.set_computer_open(true)
	desktop._focus_initial_launcher.call_deferred()
	return {"ok": true}

func _open_scene_external_app(app_id: StringName, host: Control) -> Dictionary:
	if app_id == &"minesweeper":
		if _target(&"GameState").capture_scene_challenge_command().get("ok", false):
			return open_scene_computer(host)
		return host.get_computer_mount().get_node("SceneComputerDesktop").open_app(app_id)
	if app_id == &"backup": return await open_scene_backup(host, "backup")
	if app_id != &"logout" or not _scene_host_admitted(host): return _failure(&"scene_host_unavailable", "")
	var closed := close_scene_computer(host)
	if not closed.get("ok", false): return closed
	var pause: Node = _target(&"SceneRouter")._production_pause
	var opened: Dictionary = await pause.request_pause()
	if not opened.get("ok", false): return opened
	pause.surface._activate(&"return")
	return {"ok": true}
