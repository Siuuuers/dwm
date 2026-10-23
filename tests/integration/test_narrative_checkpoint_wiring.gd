extends "res://addons/gut/test.gd"

# One shared narrative-checkpoint adapter identity + ending-port injection (dwm-p2r.8, Plan-05
# Task 2 Step 2.2/2.3). Proves DialogicBridge and GameState retain the SAME instance, that the
# adapter is configured from ONE real checkpoint port, and that SceneRouter injects the exact
# ending ports.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const SCENE_ROUTER := preload("res://autoload/SceneRouter.gd")
const NARRATIVE_PORT := preload("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd")
const ENDING_PLAYBACK_PORT := preload("res://scripts/application/ending/DialogicEndingPlaybackPort.gd")
const CONTEXT := preload("res://tests/support/FakeNarrativeCheckpointContext.gd")
const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")

var _bridge: Node
var _game_state: Node
var _router: Node


class _FakeAdapter extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	func start_timeline(path: String, event_index: Variant = 0) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"path": path, "event_index": event_index}}
	func halt_with_error(_r: Dictionary) -> Dictionary:
		return {"ok": false}


func before_each() -> void:
	_bridge = BRIDGE.new()
	_game_state = GAME_STATE.new()
	_router = SCENE_ROUTER.new()
	add_child_autofree(_bridge)
	add_child_autofree(_game_state)
	add_child_autofree(_router)
	_bridge.initialize(null, _FakeAdapter.new())


func _shared_adapter() -> Array:
	var context: RefCounted = CONTEXT.new()
	var adapter: Object = NARRATIVE_PORT.new()
	var configured: Dictionary = adapter.configure(context, context.provider_callables())
	assert_true(configured.get("ok", false), str(configured))
	return [adapter, context]


func test_bridge_and_game_state_retain_the_same_adapter_instance() -> void:
	var pair := _shared_adapter()
	var adapter: Object = pair[0]
	var bridge_result: Dictionary = _bridge.configure_narrative_checkpoint_port(adapter)
	var state_result: Dictionary = _game_state.configure_narrative_checkpoint_port(adapter)
	assert_true(bridge_result.get("ok", false), str(bridge_result))
	assert_true(state_result.get("ok", false), str(state_result))
	assert_eq(int(bridge_result["value"]["port_instance_id"]), adapter.get_instance_id(), "bridge retains the shared adapter")
	assert_eq(int(state_result["value"]["port_instance_id"]), adapter.get_instance_id(), "GameState retains the same adapter")
	assert_eq(int(bridge_result["value"]["port_instance_id"]), int(state_result["value"]["port_instance_id"]), "one identity across both consumers")


func test_both_consumers_reject_a_second_adapter() -> void:
	var adapter: Object = _shared_adapter()[0]
	var other: Object = _shared_adapter()[0]
	_bridge.configure_narrative_checkpoint_port(adapter)
	_game_state.configure_narrative_checkpoint_port(adapter)
	assert_false(_bridge.configure_narrative_checkpoint_port(other).get("ok", false), "bridge rejects a second adapter")
	assert_false(_game_state.configure_narrative_checkpoint_port(other).get("ok", false), "GameState rejects a second adapter")
	assert_true(_bridge.configure_narrative_checkpoint_port(adapter).get("ok", false), "same instance stays idempotent")
	assert_true(_game_state.configure_narrative_checkpoint_port(adapter).get("ok", false), "same instance stays idempotent")


func test_adapter_configures_from_one_real_checkpoint_port() -> void:
	var pair := _shared_adapter()
	var adapter: Object = pair[0]
	var context: RefCounted = pair[1]
	var again: Dictionary = adapter.configure(context, context.provider_callables())
	assert_true(again["value"]["already_configured"], "same real port + providers is idempotent")
	var second_context: RefCounted = CONTEXT.new()
	assert_false(adapter.configure(second_context, second_context.provider_callables()).get("ok", false), "a second real checkpoint port is rejected")


func test_game_state_snapshot_input_provider_is_pure() -> void:
	var before: Dictionary = _game_state.capture_run_snapshot_input()
	var after: Dictionary = _game_state.capture_run_snapshot_input()
	assert_eq(before, after, "repeated capture is stable")
	assert_true(before.has("lifecycle"), "carries lifecycle for the checkpoint input")
	assert_true(before.has("gameplay"), "carries the gameplay bag")
	assert_true((before["gameplay"] as Dictionary).has("narrative_variables"), "gameplay carries narrative_variables")
	before["gameplay"]["narrative_variables"]["injected"] = true
	assert_false((_game_state.capture_run_snapshot_input()["gameplay"] as Dictionary)["narrative_variables"].has("injected"), "returns a detached copy")


func test_scene_router_injects_exact_ending_ports() -> void:
	var playback_port: Object = ENDING_PLAYBACK_PORT.new()
	assert_true(playback_port.initialize(_bridge).get("ok", false), "production port initialized on the bridge")
	assert_true(playback_port.is_ready(), "port ready")
	assert_false(_router.is_ending_ports_configured(), "unconfigured before wiring")
	var configured: Dictionary = _router.configure_ending_ports(_game_state, playback_port)
	assert_true(configured.get("ok", false), str(configured))
	assert_eq(int(configured["value"]["playback_port_instance_id"]), playback_port.get_instance_id(), "exact playback instance")
	assert_eq(int(configured["value"]["state_port_instance_id"]), _game_state.get_instance_id(), "exact state instance")
	assert_true(_router.is_ending_ports_configured(), "configured after wiring")
	assert_true(_router.configure_ending_ports(_game_state, playback_port).get("ok", false), "idempotent for the same pair")


func test_scene_router_rejects_replacement_and_bad_ports() -> void:
	var playback_port: Object = ENDING_PLAYBACK_PORT.new()
	playback_port.initialize(_bridge)
	_router.configure_ending_ports(_game_state, playback_port)
	var other: Object = ENDING_PLAYBACK_PORT.new()
	other.initialize(_bridge)
	assert_false(_router.configure_ending_ports(_game_state, other).get("ok", false), "replacement rejected")
	var fresh: Node = SCENE_ROUTER.new()
	add_child_autofree(fresh)
	assert_false(fresh.configure_ending_ports(RefCounted.new(), playback_port).get("ok", false), "bad state port rejected")
	assert_false(fresh.configure_ending_ports(_game_state, RefCounted.new()).get("ok", false), "bad playback port rejected")


# ---- dwm-p2r.9 Plan 02 Task 1: the stable active-app Callable identity + null-before-host ----
func test_active_app_id_callable_is_stable_and_null_before_host() -> void:
	var bootstrap: Node = BOOTSTRAP.new()
	assert_null(bootstrap._active_app_id_context(), "returns null before the desktop host is wired")
	assert_eq(Callable(bootstrap, "_active_app_id_context"),
		Callable(bootstrap, "_active_app_id_context"), "the Callable identity is stable")
	bootstrap.free()
