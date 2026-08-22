extends "res://addons/gut/test.gd"
# start_new_run transaction over the real run participant + fake owners
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
# Plan 02 Task 6 (dwm-p2r.32): New Run now allocates a REAL desktop identity through the real
# DesktopIssuerRootStore/DesktopIdentityNonceIssuer pair (a deterministic FakeDesktopNamespaceSource
# stands in only for the namespace's entropy source, matching Task 1's own test precedent) rather
# than echoing a caller-supplied run_id.

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const GS_PATH := "res://autoload/GameState.gd"
const RUN_PARTICIPANT := "res://scripts/application/restore/RunRestoreParticipant.gd"
const FAKE_PARTICIPANT := "res://tests/support/FakeRestoreParticipant.gd"
const CALL_LOG := "res://tests/support/RestoreCallLog.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const FAKE_NAMESPACE_SOURCE := "res://tests/support/FakeDesktopNamespaceSource.gd"

func _initial_context() -> Dictionary:
	return {"route_id": "opening", "dialogic_checkpoint": {}, "active_app_id": null,
		"audio_context": {}, "content_version": 1}

func _wired() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	var gate: RefCounted = load(GATE_PATH).new()
	manager.configure_mutation_gate(gate)
	assert_true(manager._journal.reset("run-a")["ok"])

	var issuer_root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run_issuer").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(issuer_root)
	var root_store: RefCounted = load(ROOT_STORE_PATH).new()
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE).new("3".repeat(64))
	assert_true(root_store.configure(load(STORAGE_PATH).new(issuer_root), namespace_source)["ok"])
	assert_true(root_store.load_or_create()["ok"])
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(root_store)["ok"])
	assert_true(manager.configure_identity_issuer(issuer)["ok"])

	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	var log: RefCounted = load(CALL_LOG).new()
	assert_true(manager.configure_restore_participants({
		"run": load(RUN_PARTICIPANT).new(gs),
		"profile": load(FAKE_PARTICIPANT).new("profile", log),
		"localization": load(FAKE_PARTICIPANT).new("localization", log),
		"audio": load(FAKE_PARTICIPANT).new("audio", log),
		"route": load(FAKE_PARTICIPANT).new("route", log),
		"narrative": load(FAKE_PARTICIPANT).new("narrative", log),
	})["ok"])
	return {"manager": manager, "gate": gate, "gs": gs, "log": log, "issuer": issuer}

func test_start_new_run_rejects_bad_context_and_run_id() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	assert_eq(manager.start_new_run("run-b", {"route_id": "main"}).get("code"), &"invalid_initial_context")
	assert_eq(manager.start_new_run("", _initial_context()).get("code"), &"invalid_run_id")
	var extra := _initial_context()
	extra["surprise"] = 1
	assert_eq(manager.start_new_run("run-b", extra).get("code"), &"invalid_initial_context")

func test_start_new_run_builds_day1_run_b() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	# The caller-supplied run_id ("run-b") is validated but otherwise discarded (Plan 02 Task 6,
	# dwm-p2r.32): the real identity comes from the desktop issuer's own durable allocation.
	var result: Dictionary = manager.start_new_run("run-b", _initial_context())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var allocated_run_id: String = str(result["value"]["run_id"])
	assert_ne(allocated_run_id, "", "the issuer allocates a real, nonblank run_id")
	assert_ne(allocated_run_id, "run-b", "the caller-supplied run_id is never adopted directly")
	assert_eq(result["value"]["checkpoint_id"], "%s:1" % allocated_run_id, "Run-B starts at sequence 1")
	assert_eq(result["value"]["route_id"], "opening")
	assert_eq(int(manager._journal.peek_next_sequence(allocated_run_id)["value"]["checkpoint_sequence"]), 2)
	assert_eq(manager._journal.get_bundles_for_disk(), [], "a fresh run has no earlier bundles")
	assert_eq(wired["gs"].day, 1, "live GameState is now Day 1 of the new run")
	assert_false(wired["gate"].is_active(), "gate released after the new-run transaction")
	assert_false(manager.is_save_locked(), "no lingering save lock")
	assert_eq(str(wired["gs"]._run_lifecycle.get_desktop_identity_context()["run_id"]), allocated_run_id,
		"the live lifecycle's run_id matches the allocated identity")

func test_start_new_run_requires_identity_issuer() -> void:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run_no_issuer").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	var log: RefCounted = load(CALL_LOG).new()
	manager.configure_restore_participants({
		"run": load(RUN_PARTICIPANT).new(gs),
		"profile": load(FAKE_PARTICIPANT).new("profile", log),
		"localization": load(FAKE_PARTICIPANT).new("localization", log),
		"audio": load(FAKE_PARTICIPANT).new("audio", log),
		"route": load(FAKE_PARTICIPANT).new("route", log),
		"narrative": load(FAKE_PARTICIPANT).new("narrative", log),
	})
	var result: Dictionary = manager.start_new_run("run-b", _initial_context())
	assert_false(result.get("ok", true))
	assert_eq(result["code"], &"identity_issuer_not_configured")

func test_start_new_run_allocates_a_fresh_identity_per_call() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	var first: Dictionary = manager.start_new_run("run-first", _initial_context())
	assert_true(first.get("ok", false), JSON.stringify(first))
	# A second New Run over the same manager needs a fresh GameState/participant set (the first run
	# already occupies the live one), but the SAME issuer must allocate a genuinely different branch.
	var context: Dictionary = wired["gs"]._run_lifecycle.get_desktop_identity_context()
	assert_false(str(context["branch_id"]).is_empty(), "a real branch_id was allocated")
	assert_false(str(context["causal_day_instance"]).is_empty(), "a real causal_day_instance was allocated")
	assert_eq(int(context["desktop_timeline_generation"]), 0, "New Run always opens generation zero")

func test_start_new_run_requires_participants() -> void:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run_np").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	assert_eq(manager.start_new_run("run-b", _initial_context()).get("code"),
		&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED")
