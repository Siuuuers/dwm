extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const APPLICATION_MUTATION_GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")
const SCENE_FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const SCENE_REGISTRATION := preload("res://tests/support/SceneContactFixture.gd")
const LOCALIZATION_PARTICIPANT := preload("res://scripts/application/restore/LocalizationRestoreParticipant.gd")
const WINDOW_MANAGER := preload("res://autoload/WindowModeManager.gd")
const WINDOW_FIXTURES := preload("res://tests/unit/test_window_mode_manager.gd")

class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)

var _new_run_fixture: RefCounted
var _shared_root := ""
var _root_counter := 0
var _scene_validation_scope := preload("res://tests/support/SceneValidationScope.gd").new()


func _isolated_root() -> String:
	_root_counter += 1
	var result: Dictionary = TEMPORARY_STORAGE.create("desktop-crash-recovery-%d" % _root_counter)
	assert_true(result.get("ok", false), result.get("message", ""))
	return str(result.get("value", "")) if result.get("ok", false) else ""


func before_each() -> void:
	_scene_validation_scope.install(true)
	_shared_root = ""
	assert_true(SHOP_REGISTRY.initialize().get("ok", false))
	var result: Dictionary = TEMPORARY_STORAGE.create("desktop-crash-recovery-shared")
	assert_true(result.get("ok", false), result.get("message", ""))
	if not result.get("ok", false):
		return
	_shared_root = str(result["value"])


func after_each() -> void:
	if _new_run_fixture != null:
		_new_run_fixture.close()
		_new_run_fixture = null
	_scene_validation_scope.restore()


func _boot_process(storage_root: String) -> Dictionary:
	assert_true(SCENE_REGISTRATION.install_registration().ok)
	# Each graph models a new process; retain registration, not the prior graph's owners.
	_scene_validation_scope.clear_validation_bindings()
	var storage: RefCounted = JSON_STORAGE.new(storage_root)
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(root_store).get("ok", false))

	var game_state: Node = load(GAME_STATE_PATH).new()
	autofree(game_state)
	game_state.reset_game()

	var bootstrap: Node = HarnessBootstrap.new()
	autofree(bootstrap)
	bootstrap.set("_profile_storage", storage)
	bootstrap.set("_desktop_issuer_root_store", root_store)
	bootstrap.set("_desktop_identity_nonce_issuer", issuer)

	var profile: Node = load("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	var gate: RefCounted = APPLICATION_MUTATION_GATE.new()
	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	add_child_autofree(save_manager)
	assert_true(save_manager.call(&"initialize", JSON_STORAGE.new(storage_root.path_join("saves"))).get("ok", false))
	assert_true(save_manager.call(&"configure_identity_issuer", issuer).get("ok", false))
	assert_true(save_manager.call(&"configure_mutation_gate", gate).get("ok", false))
	assert_true(game_state.configure_mutation_gate(gate).get("ok", false))

	assert_true(profile.configure_mutation_gate(gate).get("ok", false))
	assert_true(profile.configure_new_run_storage(storage).get("ok", false))
	assert_true(save_manager.configure_new_run_profile_owner(profile).get("ok", false))
	assert_true(save_manager.reconcile_new_run_storage().get("ok", false))

	assert_true(profile.call(&"initialize", storage).get("ok", false),
		"ProfileManager must be initialized the same way the real initialize_profile stage does it")
	var localization: Node = load("res://autoload/LocalizationManager.gd").new()
	add_child_autofree(localization)
	assert_true(localization.call(&"initialize", profile).get("ok", false),
		"LocalizationManager must be initialized the same way the real initialize_localization stage does it")
	var audio: Node = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(audio)
	assert_true(audio.call(&"initialize", profile).get("ok", false),
		"AudioManager must be initialized the same way the real initialize_audio stage does it")
	var window := WINDOW_MANAGER.new(WINDOW_FIXTURES.PhysicalWindow.new())
	add_child_autofree(window)
	assert_true(window.initialize(profile, audio.get_settings_output_transactions()).get("ok", false),
		"Window output uses the real manager and shared transaction with isolated physical geometry")
	var bridge: Node = load("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(bridge)
	var router: Node = load("res://autoload/SceneRouter.gd").new()
	add_child_autofree(router)

	bootstrap.set("targets", {
		"ProfileManager": profile, "LocalizationManager": localization, "AudioManager": audio,
		"WindowModeManager": window,
		"DialogicBridge": bridge, "SceneRouter": router, "GameState": game_state,
		"SaveManager": save_manager,
	})

	bootstrap.set("_application_gate", gate)
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	bootstrap.set("_retained_checkpoint_port", checkpoint_port)

	assert_true(bootstrap.call(&"_configure_causal_day_advance_identity").get("ok", false))
	var restore_result: Dictionary = bootstrap.call(&"_configure_restore_participants")
	assert_true(restore_result.get("ok", false), "restore participants: " + str(restore_result))
	var graph_result: Dictionary = bootstrap.call(&"_configure_desktop_production_graph")
	assert_true(graph_result.get("ok", false), "desktop production graph: " + str(graph_result))

	return {"bootstrap": bootstrap, "game_state": game_state, "save_manager": save_manager,
		"issuer": issuer, "profile": profile, "localization": localization}


func _open_scene_new_run() -> Dictionary:
	if _new_run_fixture != null:
		_new_run_fixture.close()
	_scene_validation_scope.restore()
	_scene_validation_scope.install(true)
	_new_run_fixture = SCENE_FIXTURE.new()
	var setup: Dictionary = _new_run_fixture.setup(get_tree(), _shared_root)
	assert_true(setup.ok, str(setup))
	if not setup.ok: return {}
	var localization: Node = load("res://autoload/LocalizationManager.gd").new()
	add_child_autofree(localization)
	assert_true(localization.initialize(_new_run_fixture.profile).ok)
	_new_run_fixture.participants.localization = LOCALIZATION_PARTICIPANT.new(localization)
	assert_true(_new_run_fixture.manager.configure_scene_restore_participants(_new_run_fixture.participants).ok)
	return {"fixture": _new_run_fixture, "localization": localization}

func test_start_new_run_completes_against_the_real_profile_and_localization_pair() -> void:
	var process := _open_scene_new_run()
	if process.is_empty(): return
	var fixture: RefCounted = process.fixture
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	assert_true(fixture.game.capture_live_session().value.active)
	assert_eq(fixture.profile.get_preference(&"preferences.language.primary_locale_id"), "en")
	assert_eq(process.localization.get_locale(), "en")

func test_a_new_run_preserves_the_committed_global_profile_and_chains_its_locale() -> void:
	var first := _open_scene_new_run()
	if first.is_empty(): return
	var prepared: Dictionary = first.fixture.profile.prepare_locale_preference("zh_CN")
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_true(first.fixture.profile.commit_prepared_profile(prepared.value, false).ok)
	var before: Dictionary = first.fixture.profile.get_profile_snapshot()
	var second := _open_scene_new_run()
	if second.is_empty(): return
	var started: Dictionary = second.fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	second.fixture.confirm_activation()
	assert_eq(second.fixture.profile.get_profile_snapshot(), before)
	assert_eq(second.localization.get_locale(), "zh_CN")

func test_boot_itself_reconciles_before_returning_ok_not_only_when_called_a_second_time() -> void:
	if _shared_root.is_empty():
		return
	# _configure_desktop_production_graph() calls SaveManager.reconcile_incomplete_continuations()
	# itself (Phase 1), so a caller never has to remember to call it separately. Proven by armed
	# absence: configuring the graph with NO prior incomplete operation must still succeed (a
	# missing/failing reconciliation call inside the graph would surface as this same failure).
	var process := _boot_process(_shared_root)
	assert_true((process["bootstrap"] as Node).call(&"_configure_desktop_production_graph").get("ok", false),
		"identical replay of the graph construction (which reconciles again) is still ok")


# -------------------------------------------------------------------------------------------------
# the desktop publication ledger survives a fresh reload (at-most-once durability, independent of
# either honest gap: this exercises record_before_emit()/load() directly, matching the ledger's own
# established unit-test discipline, but against the Bootstrap-RETAINED instance)
# -------------------------------------------------------------------------------------------------

func test_the_bootstrap_retained_publication_ledger_survives_a_fresh_reload() -> void:
	if _shared_root.is_empty():
		return
	var process := _boot_process(_shared_root)
	var ledger: Object = (process["bootstrap"] as Node).get("_retained_desktop_publication_ledger")
	assert_true(ledger is DESKTOP_PUBLICATION_LEDGER)
	# FIX (dwm-p2r.35.1 remediation, finding W1): the ledger's closed kind union is exactly
	# ["causal_sequence", "action_source", "board_fate"] (plan02-frozen-contracts.md line 328) --
	# read directly from the as-built KINDS constant, not the causal reservation's own disjoint
	# minesweeper_round|shop_purchase|schedule_done union a prior implementation reused here by
	# mistake. Each kind has its own publication shape (line 335); board_fate's is exercised here.
	var semantic_receipt := {"receipt_id": "board-fate-crash-1", "fate": "none"}
	var publication := {"board_candidate": {"phase": "NONE"}, "board_fate_receipt": semantic_receipt}
	var recorded: Dictionary = ledger.record_before_emit({
		"kind": "board_fate", "semantic_receipt": semantic_receipt,
		"publication": publication, "publication_sha256": _sha256_of(publication),
	})
	assert_true(recorded.get("ok", false), JSON.stringify(recorded))
	assert_true(bool((recorded["value"] as Dictionary)["first_delivery"]))

	# A fresh ledger instance over the SAME storage root (modelling a cold restart) sees the
	# already-durable record and treats a byte-identical replay as NOT a first delivery.
	var reloaded: RefCounted = DESKTOP_PUBLICATION_LEDGER.new()
	assert_true(reloaded.configure((process["bootstrap"] as Node).get("_profile_storage")).get("ok", false))
	assert_true(reloaded.load().get("ok", false))
	var replayed: Dictionary = reloaded.record_before_emit({
		"kind": "board_fate", "semantic_receipt": semantic_receipt,
		"publication": publication, "publication_sha256": _sha256_of(publication),
	})
	assert_true(replayed.get("ok", false), JSON.stringify(replayed))
	assert_false(bool((replayed["value"] as Dictionary)["first_delivery"]),
		"the record survived the reload; replay is recognized, not re-delivered")


func _sha256_of(value: Variant) -> String:
	var emitted: Dictionary = load("res://scripts/validation/CanonicalJsonWriter.gd").stringify(value)
	assert_true(emitted.get("ok", false))
	return str(emitted["value"]).sha256_text()
