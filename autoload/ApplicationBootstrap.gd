extends Node

signal application_ready()
signal development_subset_ready(subset_id: StringName)

const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const DESKTOP_ISSUER_ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const CRYPTO_DESKTOP_NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const DESKTOP_IDENTITY_NONCE_ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const CONTACT_COMMAND_PORT := preload("res://scripts/application/contact/ContactCommandPort.gd")
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
const FATAL_DIAGNOSTIC_PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")
const MINESWEEPER_ROUND_COORDINATOR := preload("res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd")
const MINESWEEPER_STATE_PORT := preload("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd")
const MINESWEEPER_SAVE_PORT := preload("res://scripts/application/minesweeper/SaveManagerMinesweeperPort.gd")

const MODE_FINAL := &"final"
const MODE_TEST_MANUAL := &"test_manual"
const MODE_PROFILE_LOCALIZATION_DEVELOPMENT := &"profile_localization_development"
const MODE_PROFILE_LOCALE_AUDIO_DEVELOPMENT := &"profile_locale_audio_development"

const STAGE_ORDER: Array[StringName] = [
	&"select_and_prove_roots",
	&"construct_and_inject_mutation_gate",
	&"construct_identity_issuer_and_contact_commands",
	&"initialize_profile",
	&"initialize_saves",
	&"initialize_localization",
	&"initialize_input",
	&"initialize_accessibility",
	&"initialize_audio",
	&"initialize_dialogic_bridge",
	&"configure_restore_participants",
	&"configure_day_resolution",
	&"configure_minesweeper_rounds",
	&"publish_application_ready",
]

const FINAL_GATE_TARGETS: Array[StringName] = [
	&"SaveManager", &"GameState", &"ProfileManager", &"LocalizationManager",
	&"AudioManager", &"SceneRouter", &"DialogicBridge", &"InputManager",
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
var _contact_command_port: RefCounted = null
## The ONE real checkpoint port, constructed in initialize_saves and reused by the narrative
## adapter and the later configure_day_resolution stage. A second construction is a wiring bug.
var _retained_checkpoint_port: RefCounted = null
var _narrative_checkpoint_adapter: Object = null
var _ending_playback_port: Object = null
## The ONE Bootstrap-owned desktop host for the process lifetime (dwm-p2r.9 Plan 02 Task 1).
## The stable active-app Callable reads this; it is null until the configure_restore_participants
## stage constructs and assigns it.
var _desktop_host_state: RefCounted = null
## At most one Phase-3-owned desktop eviction port. Assigned via register_desktop_eviction_port.
var _desktop_eviction_port: Object = null
## The ONE Minesweeper round coordinator and its two production adapters (dwm-p2r.9 Plan 06
## Task 2). Constructed once, configured with initialized production ports, and installed in
## GameState exactly once; identical startup replay reuses these exact instances.
var _retained_minesweeper_state_port: RefCounted = null
var _retained_minesweeper_save_port: RefCounted = null
var _retained_minesweeper_coordinator: RefCounted = null
## The exact provider bundle handed to BOTH checkpoint producers, so the Minesweeper port and
## the day-resolution port read one set of Callable identities.
var _checkpoint_provider_bundle: Dictionary = {}
var _state := {
	"started": false, "ready": false, "mode": &"",
	"completed_stages": [], "planned_blockers": [], "fatal_result": {},
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
		if not stage_result.get("ok", false): return _latch_startup_fatal(stage_result.get("code", &"startup_stage_failed"), str(stage_result.get("message", stage_id)))
		_state["completed_stages"].append(stage_id)
	_started = true
	if mode == MODE_FINAL:
		_state["ready"] = true
		application_ready.emit()
	else:
		development_subset_ready.emit(mode)
	return {"ok": true, "value": get_startup_state()}

func get_startup_state() -> Dictionary:
	return _state.duplicate(true)

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
		&"initialize_saves":
			var save_manager := _target(&"SaveManager")
			if save_manager == null or not save_manager.has_method("initialize"):
				return _failure(&"missing_stage_adapter", "SaveManager initializer is unavailable")
			var save_initialized: Dictionary = save_manager.call(&"initialize", JSON_STORAGE.new(_selected_root.path_join("saves")))
			if not save_initialized.get("ok", false):
				return save_initialized
			# Construct and retain the ONE real checkpoint port here; the narrative adapter and
			# the later configure_day_resolution stage reuse this exact instance.
			if _retained_checkpoint_port == null:
				_retained_checkpoint_port = SAVE_CHECKPOINT_PORT.new(save_manager)
				if _application_gate != null:
					var save_latched: Dictionary = _retained_checkpoint_port.configure_fatal_latch(_application_gate)
					if not save_latched.get("ok", false):
						return save_latched
			return save_initialized
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
			return {"ok": true}
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
	return {"ok": true}


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
	var foundation := _construct_schedule_foundation(game_state, state_port)
	if not foundation.get("ok", false):
		return foundation
	return {"ok": true, "value": {"gate_instance_id": _application_gate.get_instance_id()}}


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


## Builds the six production restore participants, constructs the ONE Bootstrap-owned desktop
## host, wires it into the route participant, and hands the full set to SaveManager. Runs exactly
## once (each participant is built only while still null) so identical startup replay is safe
## (dwm-p2r.9 Plan 02 Task 1).
func _configure_restore_participants() -> Dictionary:
	var save_manager := _target(&"SaveManager")
	var game_state := _target(&"GameState")
	var profile := _target(&"ProfileManager")
	var localization := _target(&"LocalizationManager")
	var audio := _target(&"AudioManager")
	var router := _target(&"SceneRouter")
	var bridge := _target(&"DialogicBridge")
	if save_manager == null or game_state == null or profile == null or localization == null \
			or audio == null or router == null or bridge == null:
		return _failure(&"missing_stage_adapter", "Restore participants require all target managers")
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
	var participants := {
		"run": RUN_RESTORE_PARTICIPANT.new(game_state),
		"profile": PROFILE_RESTORE_PARTICIPANT.new(profile),
		"localization": LOCALIZATION_RESTORE_PARTICIPANT.new(localization),
		"audio": AUDIO_RESTORE_PARTICIPANT.new(audio),
		"route": route_participant,
		"narrative": NARRATIVE_RESTORE_PARTICIPANT.new(bridge),
	}
	return save_manager.call(&"configure_restore_participants", participants)


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
	if _desktop_eviction_port != null:
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
