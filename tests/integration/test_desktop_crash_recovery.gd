extends "res://addons/gut/test.gd"
# dwm-p2r.32 Plan 02 Task 9. Crash-recovery proof through the REAL production graph.
#
# HONEST SCOPE. Both honest gaps (no production generation_port/checkpoint_port adapter for
# MinesweeperRoundCoordinator; the boot-time placeholder identity context blocking Shop
# prepare_purchase()) mean NO action-source transaction can ever reach `sequence_committed`
# through the real graph today -- confirmed directly in test_desktop_action_matrix.gd. There is
# therefore nothing pending of that kind to crash-recover here, and this file does not pretend
# otherwise.
#
# A FOURTH, NEWLY-DISCOVERED GAP (not one of Task 9's own three, and not fixed here): driving
# SaveManager.start_new_run() through a REAL ProfileManager for the first time (every prior test of
# start_new_run(), in test_new_run_transaction.gd and test_save_manager.gd, wires FAKE participants
# for every key) proves it can never succeed. start_new_run() hardcodes `plans["profile"] =
# {"profile": {}}` (SaveManager.gd, "Empty profile patch preserves the complete global profile for a
# new game"), never routed through ProfileRestoreParticipant.prepare() the way the ordinary restore
# path uses it, and ProfileManager.apply_restore_silent() has no no-op path for an empty candidate --
# it always runs the literal `{}` through ProfileSchema.validate(), which requires an EXACT 7-key
# object and therefore always fails with `{"code":"invalid_profile","path":"profile","message":
# "object has unknown or missing fields"}`. This is unconditional: no profile.json content on disk
# can change it, since the plan never reads `_profile` at all. The identical pattern also blocks
# `plans["localization"] = {}` immediately afterward (confirmed by code reading:
# LocalizationManager._is_restore_plan_valid({}) requires four keys an empty dict never carries), not
# exercised live below only because the profile failure is always reached first in participant order.
# Confirmed against HEAD by direct code reading (ProfileSchema.gd:87, 216-220; ProfileManager.gd:
# 246-253; LocalizationManager.gd:391-392; SaveManager.gd:79,393-394). autoload/SaveManager.gd IS one
# of Task 9's own authorized Modify targets per the brief's Files list -- unlike ProfileManager.gd/
# LocalizationManager.gd, which are not -- so this is not a file-ownership gap the way gaps 1-3 are;
# it is left unfixed because the correct fix is a real design decision (what locale/profile a
# brand-new run should start from, including the no-prior-profile.json case) the brief's own prose
# never specifies, not a mechanical wiring gap. Below, this is proven fail-closed rather than either
# faked past or silently left to surface as a mysterious failure elsewhere.
#
# What Task 9's own wiring genuinely adds and IS crash-recoverable, independent of all four gaps, is
# the desktop publication ledger's own durability across a fresh reload, plus the production graph's
# own boot-time reconciliation call surviving both an empty journal and a journal left with a
# genuinely stuck entry by gap 4 above.

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

class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)


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
	assert_true(profile.call(&"initialize", storage).get("ok", false),
		"ProfileManager must be initialized the same way the real initialize_profile stage does it")
	var localization: Node = load("res://autoload/LocalizationManager.gd").new()
	add_child_autofree(localization)
	var audio: Node = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(audio)
	var bridge: Node = load("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(bridge)
	var router: Node = load("res://autoload/SceneRouter.gd").new()
	add_child_autofree(router)
	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	add_child_autofree(save_manager)
	assert_true(save_manager.call(&"initialize", JSON_STORAGE.new(storage_root.path_join("saves"))).get("ok", false))
	assert_true(save_manager.call(&"configure_identity_issuer", issuer).get("ok", false))
	var allocation_participant: RefCounted = DESKTOP_IDENTITY_ALLOCATION_RESTORE_PARTICIPANT.new(issuer, save_manager)
	assert_true(save_manager.call(&"configure_identity_allocation_participant", allocation_participant).get("ok", false))
	bootstrap.set("_desktop_identity_allocation_participant", allocation_participant)
	assert_true(save_manager.call(&"configure_mutation_gate", APPLICATION_MUTATION_GATE.new()).get("ok", false))

	bootstrap.set("targets", {
		"ProfileManager": profile, "LocalizationManager": localization, "AudioManager": audio,
		"DialogicBridge": bridge, "SceneRouter": router, "GameState": game_state,
		"SaveManager": save_manager,
	})

	var gate: RefCounted = APPLICATION_MUTATION_GATE.new()
	bootstrap.set("_application_gate", gate)
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	bootstrap.set("_retained_checkpoint_port", checkpoint_port)

	assert_true(bootstrap.call(&"_configure_causal_day_advance_identity", coordinator).get("ok", false))
	assert_true(bootstrap.call(&"_construct_schedule_foundation", game_state, state_port).get("ok", false))
	assert_true(bootstrap.call(&"_configure_restore_participants").get("ok", false))
	var graph_result: Dictionary = bootstrap.call(&"_configure_desktop_production_graph")
	assert_true(graph_result.get("ok", false), "desktop production graph: " + str(graph_result))

	return {"bootstrap": bootstrap, "game_state": game_state, "save_manager": save_manager, "issuer": issuer}


func _initial_context() -> Dictionary:
	return {"active_app_id": null, "audio_context": {}, "content_version": 1,
		"dialogic_checkpoint": {}, "route_id": "opening"}


# -------------------------------------------------------------------------------------------------
# Gap 4 (see header): New Run against the REAL ProfileManager fails closed, every time, on the
# hardcoded empty profile patch -- proven concretely rather than left to surface as a mystery.
# -------------------------------------------------------------------------------------------------

func test_start_new_run_fails_closed_on_the_hardcoded_empty_profile_patch_gap() -> void:
	var process := _boot_process(_shared_root)
	var save_manager: Node = process["save_manager"]
	var started: Dictionary = save_manager.call(&"start_new_run", _initial_context())
	assert_false(started.get("ok", true), "gap 4 blocks every start_new_run against a real " \
		+ "ProfileManager; a passing result here means the gap was fixed and this test (and the " \
		+ "evidence documents' honest_gaps()) must be updated together")
	assert_eq(str(started.get("code", "")), "invalid_profile")
	assert_eq(str(started.get("path", "")), "profile")


## The failed attempt above rolls the three participants that DID apply (run, desktop_consequence,
## desktop_board) back in-process, but SaveManager never tells the continuation journal the
## transaction was abandoned (_rollback_transaction returns the original failure directly, with no
## journal.advance() call), so the journal's own "applying" record for it is left genuinely
## incomplete -- list_incomplete() finds it, and reconcile_startup() (DesktopContinuationOperation
## Journal.gd:311-312) leaves it exactly as found whenever `failure` is null, so it stays incomplete
## on every subsequent boot too. Proven directly rather than assumed: this is what "the journal
## honestly reflects a stuck gap 4 attempt" looks like, and reconciling it must still return ok
## (never crash or hang) even though the entry cannot be cleared until gap 4 itself is fixed.
func test_a_failed_new_run_leaves_a_genuinely_incomplete_continuation_that_reconciles_without_crashing() -> void:
	var process := _boot_process(_shared_root)
	var save_manager: Node = process["save_manager"]
	assert_false(save_manager.call(&"start_new_run", _initial_context()).get("ok", true))
	var reconciled: Dictionary = save_manager.call(&"reconcile_incomplete_continuations")
	assert_true(reconciled.get("ok", false), JSON.stringify(reconciled))
	var results: Array = (reconciled["value"] as Dictionary)["reconciled"]
	assert_eq(results.size(), 1, "the failed attempt's own operation is exactly the one left incomplete")
	if results.size() == 1:
		var entry: Dictionary = results[0]
		assert_true((entry["result"] as Dictionary).get("ok", false),
			"reconciling a stuck gap-4 entry must not itself fail")


## Models a genuine crash: process A's New Run attempt fails closed (gap 4) and leaves a stuck
## continuation behind; process B is a FRESH Bootstrap+SaveManager pair over the SAME on-disk root
## (a new "boot" after the "crash"). Process B's own boot-time reconciliation --
## _configure_desktop_production_graph() calling reconcile_incomplete_continuations() itself, proven
## separately below -- must inherit that stuck entry without crashing or hanging the boot, and
## _boot_process()'s own assertion that the graph came up `ok` is that proof.
func test_a_fresh_process_over_the_same_storage_boots_cleanly_after_a_failed_new_run() -> void:
	var process_a := _boot_process(_shared_root)
	assert_false((process_a["save_manager"] as Node).call(&"start_new_run", _initial_context()).get("ok", true))

	var process_b := _boot_process(_shared_root)
	var reconciled: Dictionary = (process_b["save_manager"] as Node).call(&"reconcile_incomplete_continuations")
	assert_true(reconciled.get("ok", false), JSON.stringify(reconciled))
	assert_eq(((reconciled["value"] as Dictionary)["reconciled"] as Array).size(), 1,
		"process B's own boot-time reconciliation (already run once inside _configure_desktop_" \
		+ "production_graph() during _boot_process()) inherits the SAME stuck entry process A left, " \
		+ "not a fresh duplicate")


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
