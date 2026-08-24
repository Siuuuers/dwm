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
# A FOURTH GAP WAS DISCOVERED HERE AND IS NOW FIXED (dwm-p2r.33): driving SaveManager.
# start_new_run() through a REAL ProfileManager for the first time (every prior test of
# start_new_run(), in test_new_run_transaction.gd and test_save_manager.gd, wires FAKE participants
# for every key) proved it could never succeed -- it hardcoded `plans["profile"] = {"profile": {}}`
# and `plans["localization"] = {}`, two caller-independent literals that bypassed their
# participants' prepare() and could never satisfy the real validators. The dwm-p2r.33 product
# decision (recorded in that bead's DESIGN field, 2026-08-24): a New Run PRESERVES the complete
# global profile by routing the live profile through the real participant seam with an EMPTY legacy
# patch -- ProfileRestoreParticipant.prepare({"legacy_profile_patch_input": {}}), where
# prepare_legacy_profile_patch({}, {}) returns the live profile unchanged once migration_receipts.
# legacy_game_state_profile_v1 is true and a defaults-merged validated candidate otherwise, so a
# fresh install starts from ProfileSchema defaults (language "en") -- and the locale is CHAINED
# from the prepared profile candidate's preferences.language exactly as the ordinary restore path
# chains it in _prepare_bundle_with_all_participants(). Completing that fix surfaced a THIRD
# literal of the same class: plans["audio"] passed the caller's audio_context through verbatim,
# and the frozen `audio_context must be {}` contract made it permanently invalid against
# AudioManager._validate_snapshot()'s exact-4-key shape. Per the dwm-p2r.33 addendum (user
# decision, 2026-08-24), start_new_run() now translates the frozen {} into AudioManager's own
# canonical empty snapshot (no music, no ambience), builds the persisted RunSnapshot from the
# translated shape so a new-run save stays restorable, and routes plans["audio"] through the real
# audio participant. This file now proves the working path end to end against the real
# ProfileManager/LocalizationManager pair (fresh install and preserved-profile both), and keeps
# the crash-recovery proofs alive through a post-intent failure still genuinely reachable through
# the fixed graph: a live-committed profile language with no bundle in this build fails
# LocalizationManager.prepare_locale() with `unknown_locale` AFTER the continuation intent was
# durably committed. That is fail-closed behavior on bad input, not a gap: ProfileSchema
# deliberately accepts any trimmed nonempty language string, and which languages have bundles is
# LocalizationManager's own domain.
#
# What Task 9's own wiring genuinely adds and IS crash-recoverable, independent of the remaining
# gaps, is the desktop publication ledger's own durability across a fresh reload, plus the
# production graph's own boot-time reconciliation call surviving both an empty journal and a
# journal left with a genuinely stuck entry by the unknown-locale failure above.

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
	assert_true(localization.call(&"initialize", profile).get("ok", false),
		"LocalizationManager must be initialized the same way the real initialize_localization stage does it")
	var audio: Node = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(audio)
	assert_true(audio.call(&"initialize", profile).get("ok", false),
		"AudioManager must be initialized the same way the real initialize_audio stage does it")
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

	return {"bootstrap": bootstrap, "game_state": game_state, "save_manager": save_manager,
		"issuer": issuer, "profile": profile, "localization": localization}


func _initial_context() -> Dictionary:
	return {"active_app_id": null, "audio_context": {}, "content_version": 1,
		"dialogic_checkpoint": {}, "route_id": "opening"}


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
	assert_eq(str((process["profile"] as Node).call(&"get_preference", &"preferences.language", "")),
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
	assert_eq(str((process_b["profile"] as Node).call(&"get_preference", &"preferences.language", "")),
		"zh_CN", "the New Run PRESERVED the committed global profile (dwm-p2r.33 product decision) " \
		+ "and the locale was chained from the prepared profile candidate, never hardcoded")


## With the gap fixed, the one post-intent failure still genuinely reachable through the fixed
## graph drives the same crash-recovery proof: a locale committed to the live profile with NO
## bundle in this build. ProfileSchema accepts any trimmed nonempty language string by design, and
## the commit defers its signals (a real production seam -- LocalizationManager.initialize() itself
## commits with defer_signals=true) so nothing reacts before the New Run reads the profile. A first,
## SUCCESSFUL New Run runs first so migration_receipts.legacy_game_state_profile_v1 is true and
## prepare_legacy_profile_patch({}, {}) returns the live profile (with the bad language) unchanged.
## start_new_run() then fails in LocalizationManager.prepare_locale() with `unknown_locale` AFTER
## _begin_new_run_continuation() durably committed the continuation intent and advanced it to the
## applying stage, and the prep-failure path releases the gate and returns the failure directly,
## with no journal.advance() call -- so the journal's own record for it is left genuinely
## incomplete. list_incomplete() finds it, and reconcile_startup() (DesktopContinuationOperation
## Journal.gd) leaves it exactly as found whenever `failure` is null, so it stays incomplete on
## every subsequent boot too. Reconciling it must still return ok (never crash or hang).
func test_a_failed_new_run_leaves_a_genuinely_incomplete_continuation_that_reconciles_without_crashing() -> void:
	var process := _boot_process(_shared_root)
	var save_manager: Node = process["save_manager"]
	assert_true(save_manager.call(&"start_new_run", _initial_context()).get("ok", false),
		"the seeding New Run itself must complete (receipt flips true; the journal entry completes)")
	var profile: Node = process["profile"]
	var prepared: Dictionary = profile.call(&"prepare_locale_preference", "ja")
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_true(profile.call(&"commit_prepared_profile", prepared["value"], true).get("ok", false),
		"the deferred commit persists a language no bundle in this build can serve")
	var started: Dictionary = save_manager.call(&"start_new_run", _initial_context())
	assert_false(started.get("ok", true), "no bundle for the committed language exists in this build")
	assert_eq(str(started.get("code", "")), "unknown_locale")
	var reconciled: Dictionary = save_manager.call(&"reconcile_incomplete_continuations")
	assert_true(reconciled.get("ok", false), JSON.stringify(reconciled))
	var results: Array = (reconciled["value"] as Dictionary)["reconciled"]
	assert_eq(results.size(), 1, "the failed attempt's own operation is exactly the one left incomplete")
	if results.size() == 1:
		var entry: Dictionary = results[0]
		assert_true((entry["result"] as Dictionary).get("ok", false),
			"reconciling a stuck unknown-locale entry must not itself fail")


## Models a genuine crash: process A's second New Run attempt fails closed (unknown_locale, the
## construction proven in the test above) and leaves a stuck continuation behind; process B is a
## FRESH Bootstrap+SaveManager pair over the SAME on-disk root (a new "boot" after the "crash").
## With dwm-p2r.33's fix extended to _resume_new_run(), the crash-recovery machinery now does
## MORE than tolerate the stuck entry: process B's LocalizationManager.initialize() first HEALS
## the stored unregistered locale back to the source locale (its own documented law), and then
## B's boot-time reconciliation -- _configure_desktop_production_graph() calling
## reconcile_incomplete_continuations(), which RESUMES every incomplete operation -- drives the
## interrupted New Run to COMPLETION through the real participants. Observed live, not assumed:
## before the fix this same scenario left the entry permanently incomplete on every boot.
func test_a_fresh_process_over_the_same_storage_boots_cleanly_after_a_failed_new_run() -> void:
	var process_a := _boot_process(_shared_root)
	var save_manager_a: Node = process_a["save_manager"]
	assert_true(save_manager_a.call(&"start_new_run", _initial_context()).get("ok", false))
	var profile_a: Node = process_a["profile"]
	var prepared: Dictionary = profile_a.call(&"prepare_locale_preference", "ja")
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_true(profile_a.call(&"commit_prepared_profile", prepared["value"], true).get("ok", false))
	assert_false(save_manager_a.call(&"start_new_run", _initial_context()).get("ok", true))

	var process_b := _boot_process(_shared_root)
	var reconciled: Dictionary = (process_b["save_manager"] as Node).call(&"reconcile_incomplete_continuations")
	assert_true(reconciled.get("ok", false), JSON.stringify(reconciled))
	assert_eq(((reconciled["value"] as Dictionary)["reconciled"] as Array).size(), 0,
		"process B's own boot-time reconciliation (inside _configure_desktop_production_graph() " \
		+ "during _boot_process()) RESUMED the interrupted New Run to completion after the locale " \
		+ "heal, so nothing is left incomplete for this follow-up call to find")
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
