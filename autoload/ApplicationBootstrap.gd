extends Node

signal application_ready()
signal development_subset_ready(subset_id: StringName)

const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const APPLICATION_MUTATION_GATE_SCRIPT := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
## dwm-p2r.8 Plan-05 Task 2: one narrative checkpoint adapter + one ending playback port.
const NARRATIVE_CHECKPOINT_PORT := preload("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd")
const ENDING_PLAYBACK_PORT := preload("res://scripts/application/ending/DialogicEndingPlaybackPort.gd")
const DIALOGIC_RUNTIME_ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const DIALOGIC_TIMELINE_CATALOG := preload("res://scripts/data/DialogicTimelineCatalog.gd")
## Narrative manifest content version supplied to every narrative checkpoint input.
const NARRATIVE_CONTENT_VERSION := 1

const MODE_FINAL := &"final"
const MODE_TEST_MANUAL := &"test_manual"
const MODE_PROFILE_LOCALIZATION_DEVELOPMENT := &"profile_localization_development"
const MODE_PROFILE_LOCALE_AUDIO_DEVELOPMENT := &"profile_locale_audio_development"

const STAGE_ORDER: Array[StringName] = [
	&"select_and_prove_roots",
	&"construct_and_inject_mutation_gate",
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
## The ONE real checkpoint port, constructed in initialize_saves and reused by the narrative
## adapter and the later configure_day_resolution stage. A second construction is a wiring bug.
var _retained_checkpoint_port: RefCounted = null
var _narrative_checkpoint_adapter: Object = null
var _ending_playback_port: Object = null
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


## Stable private active-app context provider. Returns JSON null until Plan 06 injects the
## Bootstrap-owned desktop host; that host is then read here without replacing this Callable.
func _active_app_id_context() -> Variant:
	return null


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
	if not game_state.has_method("_configure_day_resolution"):
		return _failure(&"missing_stage_adapter", "GameState day-resolution seam is unavailable")
	var configured: Dictionary = game_state.call(&"_configure_day_resolution", checkpoint_port)
	if not configured.get("ok", false):
		return configured
	return {"ok": true, "value": {"gate_instance_id": _application_gate.get_instance_id()}}

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
