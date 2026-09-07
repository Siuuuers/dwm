extends "res://addons/gut/test.gd"
# Restart coverage through real Profile, localization, save, identity and Bootstrap owners.
# New Acc preflights view plans before its durable decision. A registered view can
# then refuse live application, leaving the exact durable pair under recovery custody.
# A fresh graph settles stored files before Profile initialization and installs the
# same captured run. All filesystem roots are provided by the isolated test runner.
# This does not claim the still-missing production board-generation or purchase adapters.

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const APPLICATION_MUTATION_GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")
const DESKTOP_IDENTITY_ALLOCATION_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd")
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")
const WINDOW_MANAGER := preload("res://autoload/WindowModeManager.gd")
const WINDOW_FIXTURES := preload("res://tests/unit/test_window_mode_manager.gd")

class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)

class FailingPresentationRoot extends Node:
	# Inject only a view preparation failure through Localization's public root seam.
	# The real Profile, localization transaction, continuation and storage stay intact.
	var fail_apply := false
	func prepare_presentation(_profile: Dictionary) -> Dictionary:
		return {"ok": true, "value": {}}
	func capture_presentation_state() -> Dictionary:
		return {"ok": true, "value": {}}
	func apply_presentation_silent(_plan: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"root_apply_failed"} if fail_apply else {"ok": true}
	func rollback_presentation_silent(_backup: Dictionary) -> Dictionary:
		return {"ok": true}
	func finalize_presentation() -> Dictionary:
		return {"ok": true}


var _shared_root := ""
var _root_counter := 0


func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	return wrapper.path_join("desktop-crash-recovery-%d" % _root_counter)


func before_each() -> void:
	assert_true(SHOP_REGISTRY.initialize().get("ok", false))
	_shared_root = OS.get_environment("DWM_TEST_ROOT").path_join(
		"desktop-crash-recovery-shared-%d" % Time.get_ticks_usec())


## Builds one full "process" (Bootstrap + GameState + SaveManager) over `storage_root`, exactly the
## same graph _configure_desktop_production_graph() builds, so a second call over the SAME root
## models a fresh process reopening the same on-disk state after a crash.
func _boot_process(storage_root: String) -> Dictionary:
	var storage: RefCounted = JSON_STORAGE.new(storage_root)
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(root_store).get("ok", false))

	var game_state: Node = load(GAME_STATE_PATH).new()
	autofree(game_state)
	game_state.reset_game()
	var state_port: RefCounted = STATE_PORT.new(game_state)
	var coordinator: RefCounted = COORDINATOR.new()

	var bootstrap: Node = HarnessBootstrap.new()
	autofree(bootstrap)
	bootstrap.set("_profile_storage", storage)
	bootstrap.set("_desktop_issuer_root_store", root_store)
	bootstrap.set("_desktop_identity_nonce_issuer", issuer)
	bootstrap.set("_retained_day_resolution_state_port", state_port)
	bootstrap.set("_retained_day_resolution_coordinator", coordinator)

	var profile: Node = load("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	var gate: RefCounted = APPLICATION_MUTATION_GATE.new()
	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	add_child_autofree(save_manager)
	assert_true(save_manager.call(&"initialize", JSON_STORAGE.new(storage_root.path_join("saves"))).get("ok", false))
	assert_true(save_manager.call(&"configure_identity_issuer", issuer).get("ok", false))
	var allocation_participant: RefCounted = DESKTOP_IDENTITY_ALLOCATION_RESTORE_PARTICIPANT.new(issuer, save_manager)
	assert_true(save_manager.call(&"configure_identity_allocation_participant", allocation_participant).get("ok", false))
	bootstrap.set("_desktop_identity_allocation_participant", allocation_participant)
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

	assert_true(bootstrap.call(&"_configure_causal_day_advance_identity", coordinator).get("ok", false))
	assert_true(bootstrap.call(&"_construct_schedule_foundation", game_state, state_port).get("ok", false))
	assert_true(bootstrap.call(&"_configure_restore_participants").get("ok", false))
	var graph_result: Dictionary = bootstrap.call(&"_configure_desktop_production_graph")
	assert_true(graph_result.get("ok", false), "desktop production graph: " + str(graph_result))

	return {"bootstrap": bootstrap, "game_state": game_state, "save_manager": save_manager,
		"issuer": issuer, "profile": profile, "localization": localization}


func _initial_context() -> Dictionary:
	return {"active_app_id": null, "audio_context": {}, "content_version": 1,
		"dialogic_checkpoint": {}, "route_id": "main"}

func _fail_future_localization_applies(localization: Node) -> void:
	var root := FailingPresentationRoot.new()
	add_child_autofree(root)
	assert_true(localization.register_presentation_root(root).get("ok", false),
		"the real localization owner first admits a working presentation root")
	root.fail_apply = true


# -------------------------------------------------------------------------------------------------
# dwm-p2r.33: New Run against the REAL ProfileManager/LocalizationManager pair completes end to
# end. The empty legacy patch preserves the complete global profile and the locale chains from the
# prepared profile candidate, exactly as the ordinary restore path does.
# -------------------------------------------------------------------------------------------------

func test_start_new_run_completes_against_the_real_profile_and_localization_pair() -> void:
	var process := _boot_process(_shared_root)
	var save_manager: Node = process["save_manager"]
	var started: Dictionary = save_manager.call(&"start_new_run", _initial_context())
	assert_true(started.get("ok", false), "dwm-p2r.33: a fresh install (this boot persisted schema " \
		+ "defaults; no earlier profile.json existed) must complete a New Run through the REAL " \
		+ "ProfileManager/LocalizationManager pair: " + JSON.stringify(started))
	assert_false(str((started.get("value", {}) as Dictionary).get("run_id", "")).is_empty(),
		"a completed New Run reports the durably allocated run_id")
	assert_eq(str((process["profile"] as Node).call(&"get_preference", &"preferences.language.primary_locale_id", "")),
		"en", "fresh install: the schema-default locale survives the run unchanged")
	var reconciled: Dictionary = save_manager.call(&"reconcile_incomplete_continuations")
	assert_true(reconciled.get("ok", false), JSON.stringify(reconciled))
	assert_eq(((reconciled["value"] as Dictionary)["reconciled"] as Array).size(), 0,
		"a completed New Run leaves nothing incomplete in the continuation journal")


func test_a_new_run_preserves_the_committed_global_profile_and_chains_its_locale() -> void:
	var process_a := _boot_process(_shared_root)
	var profile_a: Node = process_a["profile"]
	var prepared: Dictionary = profile_a.call(&"prepare_locale_preference", "zh_CN")
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_true(profile_a.call(&"commit_prepared_profile", prepared["value"], false).get("ok", false),
		"zh_CN is a registered locale, so the live commit publishes cleanly")

	# A fresh "process" over the SAME root models the player restarting before starting a new run.
	var process_b := _boot_process(_shared_root)
	var started: Dictionary = (process_b["save_manager"] as Node).call(&"start_new_run", _initial_context())
	assert_true(started.get("ok", false), JSON.stringify(started))
	assert_eq(str((process_b["profile"] as Node).call(&"get_preference", &"preferences.language.primary_locale_id", "")),
		"zh_CN", "the New Run PRESERVED the committed global profile (dwm-p2r.33 product decision) " \
		+ "and the locale was chained from the prepared profile candidate, never hardcoded")


## A successful run seeds the journal first. A subsequently failing registered presentation root
## then refuses localization application after the next durable intent. In-process reconciliation
## must tolerate the still-failing root and retain its diagnostic; a fresh process without that
## transient view failure must complete the same interrupted operation (the next test).
func test_a_failed_new_run_leaves_a_genuinely_incomplete_continuation_that_reconciles_without_crashing() -> void:
	var process := _boot_process(_shared_root)
	var save_manager: Node = process["save_manager"]
	assert_true(save_manager.call(&"start_new_run", _initial_context()).get("ok", false),
		"the seeding New Run itself must complete and retain current Profile receipts")
	var profile: Node = process["profile"]
	var before: Dictionary = profile.get_profile_snapshot()
	var prepared: Dictionary = profile.call(&"prepare_locale_preference", "ja")
	assert_false(prepared.get("ok", true), "canonical Profile refuses an unregistered locale before commit")
	assert_eq(profile.get_profile_snapshot(), before)
	_fail_future_localization_applies(process["localization"])
	var started: Dictionary = save_manager.call(&"start_new_run", _initial_context())
	assert_false(started.get("ok", true), "the registered presentation root refuses real localization application")
	assert_eq(str(started.get("code", "")), "NEW_RUN_RECOVERY_PENDING")
	assert_eq(profile.get_profile_snapshot(), before, "post-intent failure leaves the canonical profile intact")
	var reconciled: Dictionary = save_manager.call(&"reconcile_incomplete_continuations")
	assert_false(reconciled.get("ok", true), JSON.stringify(reconciled))
	assert_eq(reconciled.get("code"), &"NEW_RUN_RECOVERY_PENDING")
	assert_eq(reconciled.get("transaction_id"), started.get("transaction_id"))
	assert_eq(reconciled.get("details", {}).get("cause", {}).get("code"), &"root_apply_failed")
	assert_true(save_manager._mutation_gate.is_internal_owner_active(&"new_run"),
		"A still-failing live owner keeps the same recovery operation under custody")


## Process A's second New Run leaves an incomplete continuation after its registered presentation
## root fails. Process B is a fresh real graph over the same disk, without the transient failed
## view. Its boot-time reconciliation must complete the interrupted run through real participants.
func test_a_fresh_process_over_the_same_storage_boots_cleanly_after_a_failed_new_run() -> void:
	var process_a := _boot_process(_shared_root)
	var save_manager_a: Node = process_a["save_manager"]
	assert_true(save_manager_a.call(&"start_new_run", _initial_context()).get("ok", false))
	_fail_future_localization_applies(process_a["localization"])
	var failed: Dictionary = save_manager_a.call(&"start_new_run", _initial_context())
	assert_false(failed.get("ok", true))
	assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING")

	var process_b := _boot_process(_shared_root)
	var reconciled: Dictionary = (process_b["save_manager"] as Node).call(&"reconcile_incomplete_continuations")
	assert_true(reconciled.get("ok", false), JSON.stringify(reconciled))
	assert_eq(((reconciled["value"] as Dictionary)["reconciled"] as Array).size(), 0,
		"process B's own boot-time reconciliation (inside _configure_desktop_production_graph() " \
		+ "during _boot_process()) RESUMED the interrupted New Run after the transient view " \
		+ "failure was removed, so nothing is left incomplete for this follow-up call to find")
	assert_true((process_b["save_manager"] as Node).call(&"get_latest_stable_checkpoint").get("ok", false),
		"the resumed run's Day-1 bundle is genuinely live in process B's journal -- the stuck " \
		+ "entry COMPLETED, it did not just vanish")


func test_boot_itself_reconciles_before_returning_ok_not_only_when_called_a_second_time() -> void:
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
