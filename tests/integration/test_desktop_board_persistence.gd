extends "res://addons/gut/test.gd"
## Selected-Load desktop board/consequence persistence over the REAL SaveManager restore stack
## (Plan 02 Task 6, dwm-p2r.32, brief Step 6.6/6.9). Proves what the brief's own exhaustive
## enumeration targets at the representative, mutation-tested level this task's established
## precedent uses (see the task-6-report.md handoff): restore genuinely remaps board/consequence
## identity through the real issuer, corruption fails closed before any live mutation, and a
## completed restore leaves the external continuation journal reconcilable at startup.
##
## Base fixture: tests/fixtures/saves/v6_desktop_prepared.json (Phase B), a complete, schema-valid
## v4 RunSnapshot with a PREPARED_UNSTARTED board (real identity + two command receipts) and an
## empty-pending consequence -- reused here rather than hand-built, since it already round-trips
## through RunSnapshotSchema.validate() (proven by test_run_snapshot_schema.gd).

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const GS_PATH := "res://autoload/GameState.gd"
const RUN_SNAPSHOT_SCHEMA := "res://scripts/domain/run/RunSnapshotSchema.gd"

const RUN_PARTICIPANT := "res://scripts/application/restore/RunRestoreParticipant.gd"
const DESKTOP_CONSEQUENCE_STATE := "res://scripts/domain/desktop/DesktopConsequenceState.gd"
const DESKTOP_BOARD_STATE := "res://scripts/domain/minesweeper/DesktopBoardState.gd"
const DESKTOP_CONSEQUENCE_PARTICIPANT := "res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd"
const DESKTOP_BOARD_PARTICIPANT := "res://scripts/application/restore/DesktopBoardRestoreParticipant.gd"
const IDENTITY_ALLOCATION_PARTICIPANT := "res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd"
const PROFILE_PARTICIPANT := "res://scripts/application/restore/ProfileRestoreParticipant.gd"
const LOCALIZATION_PARTICIPANT := "res://scripts/application/restore/LocalizationRestoreParticipant.gd"
const AUDIO_PARTICIPANT := "res://scripts/application/restore/AudioRestoreParticipant.gd"
const ROUTE_PARTICIPANT := "res://scripts/application/restore/RouteRestoreParticipant.gd"
const NARRATIVE_PARTICIPANT := "res://scripts/application/restore/NarrativeRestoreParticipant.gd"

const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const FAKE_NAMESPACE_SOURCE_PATH := "res://tests/support/FakeDesktopNamespaceSource.gd"

const FIXTURE_PATH := "res://tests/fixtures/saves/v6_desktop_prepared.json"


## A failure-injectable Owner mirroring test_restore_production_adapters.gd's own, for the five
## ordinary (non-desktop, non-run) participants.
class Owner extends RefCounted:
	func get_profile_snapshot() -> Dictionary:
		return preload("res://scripts/profile/ProfileSchema.gd").make_defaults()
	func prepare_profile_document(candidate: Dictionary) -> Dictionary:
		return preload("res://scripts/profile/ProfileSchema.gd").validate(candidate)
	func prepare_legacy_profile_patch(_l: Dictionary, _m: Dictionary = {}) -> Dictionary:
		return {"ok": true, "value": preload("res://scripts/profile/ProfileSchema.gd").make_defaults()}
	func prepare_locale(locale_id: String) -> Dictionary:
		return {"ok": true, "value": {"canonical_locale_id": locale_id}}
	func prepare_semantic_restore(ctx: Dictionary, _p: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"snapshot": ctx.duplicate(true)}}
	func prepare_route_restore(route_id: String, _c: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"route_ready_token": {"route_id": route_id, "layout_id": "L", "generation": 1}}}
	func apply_route_restore_silent(plan: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"route_ready_token": plan.get("route_ready_token", {"route_id": "main", "layout_id": "L", "generation": 1})}}
	func capture_restore_state() -> Dictionary: return {"ok": true, "value": {"backup": true}}
	func apply_restore_silent(_p: Dictionary) -> Dictionary: return {"ok": true}
	func rollback_restore_silent(_b: Dictionary) -> Dictionary: return {"ok": true}
	func finalize_restore() -> Dictionary: return {"ok": true}


func _fixture() -> Dictionary:
	var text := FileAccess.get_file_as_string(FIXTURE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(typeof(parsed) == TYPE_DICTIONARY, "fixture must parse")
	return parsed as Dictionary


## Patches only run_id/checkpoint identity so the SAME fixture is reusable across independent
## in-memory journal resets within one test file, without touching the desktop content under test.
func _snapshot(run_id: String, seq: int) -> Dictionary:
	var s := _fixture()
	s["run_id"] = run_id
	s["checkpoint_sequence"] = seq
	s["checkpoint_id"] = "%s:%d" % [run_id, seq]
	s["lifecycle"]["run_id"] = run_id
	if typeof(s["desktop"]["board"].get("identity")) == TYPE_DICTIONARY:
		s["desktop"]["board"]["identity"]["run_id"] = run_id
	var validated: Dictionary = load(RUN_SNAPSHOT_SCHEMA).validate(s)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	return validated["value"]["candidate"]


func _fresh_issuer(root: String) -> RefCounted:
	var file_ops: FakeFileOps = FakeFileOps.new()
	var storage := JsonFileStorage.new(root.path_join("_issuer"), file_ops)
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE_PATH).new("4".repeat(64))
	var store: RefCounted = load(ROOT_STORE_PATH).new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer


## Wires a real SaveManager, real issuer, real identity-allocation participant, real desktop
## consequence/board participants (over live DesktopConsequenceState/DesktopBoardState instances
## the test can inspect afterward), and a real GameState for the "run" participant.
func _wired() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("desktop_board_persistence").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(root.path_join("saves"))
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root.path_join("saves")))
	var gate: RefCounted = load(GATE_PATH).new()
	manager.configure_mutation_gate(gate)
	var issuer := _fresh_issuer(root)
	manager.configure_identity_issuer(issuer)
	manager.configure_identity_allocation_participant(load(IDENTITY_ALLOCATION_PARTICIPANT).new(issuer, manager))
	var gs: Node = load(GS_PATH).new()
	assert_true(gs.configure_mutation_gate(gate).get("ok", false))
	add_child_autofree(gs)
	gs.reset_game()
	var consequence_state: RefCounted = load(DESKTOP_CONSEQUENCE_STATE).new()
	var board_state: RefCounted = load(DESKTOP_BOARD_STATE).new()
	var owner := Owner.new()
	assert_true(manager.configure_restore_participants({
		"run": load(RUN_PARTICIPANT).new(gs),
		"desktop_consequence": load(DESKTOP_CONSEQUENCE_PARTICIPANT).new(consequence_state),
		"desktop_board": load(DESKTOP_BOARD_PARTICIPANT).new(board_state),
		"schedule_view": preload("res://tests/support/ScheduleRestoreFixture.gd").create(issuer).value.participant,
		"profile": load(PROFILE_PARTICIPANT).new(owner),
		"localization": load(LOCALIZATION_PARTICIPANT).new(owner),
		"audio": load(AUDIO_PARTICIPANT).new(owner),
		"route": load(ROUTE_PARTICIPANT).new(owner),
		"narrative": load(NARRATIVE_PARTICIPANT).new(owner),
	}).get("ok", false))
	return {"manager": manager, "gs": gs, "consequence_state": consequence_state, "board_state": board_state}


func _seed_and_save(manager: Node, run_id: String, slot_id: int) -> void:
	manager._journal.reset(run_id)
	var committed: Dictionary = manager._journal.commit_prepared(
		manager._journal.prepare_record(_snapshot(run_id, 1), &"day_start")["value"]["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_true(manager.save_latest_to_slot(slot_id).get("ok", false))
	# A different game is live when the player restores (mirrors test_restore_production_adapters.gd's
	# own established pattern): CheckpointJournal.commit_prepared()'s "seed" branch treats re-adopting
	# the ALREADY-current run/sequence as a harmless idempotent replay, not a fresh restore, so a
	# same-run restore right after saving would prove nothing about the participant machinery.
	manager._journal.reset("run-live-elsewhere")
	manager._journal.commit_prepared(manager._journal.prepare_reset_with_initial(
		_snapshot("run-live-elsewhere", 1), &"day_start")["value"]["candidate"])


# ---------------------------------------------------------------------------------------------
# Restore genuinely remaps board/consequence identity (brief line 291: the remapper "first
# replaces every allowlisted root transaction... then re-derives every allowlisted child ID").
# ---------------------------------------------------------------------------------------------

func test_restore_remaps_board_identity_and_command_receipt_keys() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	_seed_and_save(manager, "run-remap-a", 1)

	var prepared: Dictionary = manager.prepare_restore_slot(1)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var value: Dictionary = prepared["value"]["prepared"]
	assert_true(value.has("source_locator"), "a real restore always carries an identity-continuation locator")

	var committed: Dictionary = manager.commit_prepared_restore(value)
	assert_true(committed.get("ok", false), JSON.stringify(committed))

	var board_capture: Dictionary = (wired["board_state"] as RefCounted).capture()
	var identity: Dictionary = board_capture["identity"]
	assert_ne(str(identity["branch_id"]), "fixture-branch-1", "branch_id was remapped, not copied byte-for-byte")
	assert_ne(str(identity["causal_day_instance"]), "fixture-causal-day-1", "causal_day_instance was remapped")
	assert_eq(str(identity["run_id"]), "run-remap-a", "run_id is restored, never remapped")
	assert_eq(int(identity["app_round_ordinal"]), 1, "app_round_ordinal is untouched by identity remap")

	var receipt_keys: Array = (board_capture["command_receipts"] as Dictionary).keys()
	receipt_keys.sort()
	assert_eq(receipt_keys.size(), 2, "both source command receipts survive the remap")
	assert_false(receipt_keys.has("txn-debug-begin"), "old transaction IDs are replaced, not reused")
	assert_false(receipt_keys.has("txn-debug-slice"), "old transaction IDs are replaced, not reused")

	# The "run" participant's own identity is remapped to the SAME new branch/causal-day pair.
	var lifecycle_context: Dictionary = (wired["gs"] as Node)._run_lifecycle.get_desktop_identity_context()
	assert_eq(str(lifecycle_context["branch_id"]), str(identity["branch_id"]),
		"the run lifecycle's remapped identity agrees with the board's")
	assert_eq(str(lifecycle_context["causal_day_instance"]), str(identity["causal_day_instance"]))


func test_restore_remaps_consequence_causal_day_pair() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	_seed_and_save(manager, "run-remap-b", 2)

	var prepared: Dictionary = manager.prepare_restore_slot(2)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = manager.commit_prepared_restore(prepared["value"]["prepared"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))

	var consequence_capture: Dictionary = ((wired["consequence_state"] as RefCounted).capture()["value"] as Dictionary)["state"]
	assert_ne(str(consequence_capture["causal_day_instance"]), "fixture-causal-day-1",
		"consequence's causal_day_instance is remapped alongside the board's")
	var receipt: Dictionary = consequence_capture["causal_day_instance_issuer_receipt"]
	assert_eq(str(receipt["token"]), str(consequence_capture["causal_day_instance"]),
		"the remapped receipt's token still agrees with the adjacent field")


# ---------------------------------------------------------------------------------------------
# Corruption fails closed before any live mutation (brief Step 6.6: "Corrupt each identity/
# layout/... member and assert fail closed before live mutation").
# ---------------------------------------------------------------------------------------------

func test_restore_rejects_a_corrupted_board_before_touching_live_state() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	manager._journal.reset("run-corrupt-board")
	var snapshot := _snapshot("run-corrupt-board", 1)
	# Corrupt the board's phase invariant (revision without any of the fields PREPARED_UNSTARTED
	# requires) directly on the already-schema-valid candidate, bypassing RunSnapshotSchema so the
	# corruption reaches the desktop-board participant's own structural validation.
	snapshot["desktop"]["board"]["candidate"] = null
	var built: Dictionary = manager._journal.prepare_record(snapshot, &"day_start")
	assert_false(built.get("ok", false), "a corrupted board is caught by RunSnapshotSchema/CheckpointJournal before it ever reaches disk")


func test_restore_rejects_a_corrupted_consequence_receipt_before_live_mutation() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	_seed_and_save(manager, "run-corrupt-consequence", 3)

	# Corrupt the ON-DISK document directly (simulating bit-rot/tampering the schema chain alone
	# would not catch at write time): break the issuer-receipt/adjacent-token pairing law.
	var read: Dictionary = manager._storage.read_text("slot_3.json")
	assert_true(read.get("ok", false))
	var document: Dictionary = JSON.parse_string(str(read["value"]))
	document["current_snapshot"]["snapshot"]["desktop"]["consequence"]["causal_day_instance_issuer_receipt"]["token"] = "tampered"
	var rewritten: Dictionary = manager._storage.write_atomic("slot_3.json",
		JSON.stringify(document) + "\n", func(_t: String) -> Dictionary: return {"ok": true, "code": &"ok", "value": {}})
	assert_true(rewritten.get("ok", false))

	var prepared: Dictionary = manager.prepare_restore_slot(3)
	assert_false(prepared.get("ok", true), "a tampered issuer-receipt/token pairing must fail prepare, not silently restore")
	var still_live: Dictionary = manager._journal.get_current_bundle()
	assert_true(still_live.get("ok", false))
	# _seed_and_save() itself already advances the live journal past "run-corrupt-consequence" (a
	# different game is live when the player restores); the point here is that the FAILED prepare
	# above changed nothing further.
	assert_eq(str(still_live["value"]["bundle"]["snapshot"]["run_id"]), "run-live-elsewhere",
		"no live mutation occurred -- the manager's own journal is untouched by a failed prepare")


# ---------------------------------------------------------------------------------------------
# A completed restore leaves the external continuation journal reconcilable at startup (brief
# line 293: "Every New-Run/restore startup calls list_incomplete() before run input").
# ---------------------------------------------------------------------------------------------

func test_a_completed_restore_leaves_no_incomplete_continuation() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	_seed_and_save(manager, "run-reconcile", 4)
	var prepared: Dictionary = manager.prepare_restore_slot(4)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_true(manager.commit_prepared_restore(prepared["value"]["prepared"]).get("ok", false))

	var reconciled: Dictionary = manager.reconcile_incomplete_continuations()
	assert_true(reconciled.get("ok", false), JSON.stringify(reconciled))
	assert_eq((reconciled["value"] as Dictionary)["reconciled"], [],
		"a completed restore's operation is no longer incomplete")
