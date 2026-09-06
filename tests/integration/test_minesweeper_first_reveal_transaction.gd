extends "res://addons/gut/test.gd"
## Production durable first-Reveal transaction (Plan 02 Task 6, dwm-p2r.32, Phase D, brief Steps
## 6.10-6.12). Configures the REAL SaveManagerDesktopBoardPort over an isolated store and v4
## providers, and the real Task-5 MinesweeperRoundCoordinator/GameStateDesktopBoardPort through the
## new durable seam (MinesweeperRoundCoordinator.configure_durable_checkpoint()). Representative,
## not the brief's full exhaustive crash-injection matrix -- see the composer unit test and the
## task-6 report for the documented scope reduction this task's own precedent already established.
##
## The generation port stays the Task-5 FAKE (pure board-layout mechanics, unrelated to
## persistence); everything on the PERSISTENCE side -- SaveManager, its CheckpointJournal, its
## storage, the desktop identity issuer -- is real.

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const CHECKPOINT_PORT_PATH := "res://scripts/application/run/SaveManagerCheckpointPort.gd"
const DESKTOP_BOARD_SAVE_PORT_PATH := "res://scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd"
const COMPOSER_PATH := "res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd"
const GS_PATH := "res://autoload/GameState.gd"
const STATE_PORT_PATH := "res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd"
const CONSEQUENCE_STATE_PATH := "res://scripts/domain/desktop/DesktopConsequenceState.gd"
const COORDINATOR_PATH := "res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd"
const FAKE_CHECKPOINT_PATH := "res://tests/support/FakeMinesweeperCheckpointPort.gd"
const FAKE_GENERATION_PATH := "res://tests/support/FakeMinesweeperGenerationPort.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const FAKE_NAMESPACE_SOURCE_PATH := "res://tests/support/FakeDesktopNamespaceSource.gd"

## IMPORTANT 6 (brief Step 6.10): the full genuine restore stack, mirroring test_desktop_board_
## persistence.gd's own established combined-restore wiring.
const DESKTOP_BOARD_STATE_PATH := "res://scripts/domain/minesweeper/DesktopBoardState.gd"
const RUN_PARTICIPANT_PATH := "res://scripts/application/restore/RunRestoreParticipant.gd"
const DESKTOP_CONSEQUENCE_PARTICIPANT_PATH := "res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd"
const DESKTOP_BOARD_PARTICIPANT_PATH := "res://scripts/application/restore/DesktopBoardRestoreParticipant.gd"
const IDENTITY_ALLOCATION_PARTICIPANT_PATH := "res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd"
const PROFILE_PARTICIPANT_PATH := "res://scripts/application/restore/ProfileRestoreParticipant.gd"
const LOCALIZATION_PARTICIPANT_PATH := "res://scripts/application/restore/LocalizationRestoreParticipant.gd"
const AUDIO_PARTICIPANT_PATH := "res://scripts/application/restore/AudioRestoreParticipant.gd"
const ROUTE_PARTICIPANT_PATH := "res://scripts/application/restore/RouteRestoreParticipant.gd"
const NARRATIVE_PARTICIPANT_PATH := "res://scripts/application/restore/NarrativeRestoreParticipant.gd"
const RUN_SNAPSHOT_SCHEMA_PATH := "res://scripts/domain/run/RunSnapshotSchema.gd"
const RECOVERY_FIXTURE_PATH := "res://tests/fixtures/saves/v4_desktop_prepared.json"

const RUN_ID := "run-local"
const IDENTITY_CONTEXT := {
	"run_id": RUN_ID, "branch_id": "branch-local", "desktop_timeline_generation": 0,
	"causal_day_instance": "causal-day-local",
}


func _fresh_issuer(root: String) -> RefCounted:
	var file_ops: FakeFileOps = FakeFileOps.new()
	var storage := JsonFileStorage.new(root.path_join("_issuer"), file_ops)
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE_PATH).new("5".repeat(64))
	var store: RefCounted = load(ROOT_STORE_PATH).new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer


func _wired() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("first_reveal_durable").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(root.path_join("saves"))

	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(save_manager)
	save_manager.initialize(load(STORAGE_PATH).new(root.path_join("saves")))
	var gate: RefCounted = load(GATE_PATH).new()
	save_manager.configure_mutation_gate(gate)
	save_manager._journal.reset(RUN_ID)

	var checkpoint_port: Object = load(CHECKPOINT_PORT_PATH).new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(load(GATE_PATH).new()).get("ok", false))
	var durable_port: Object = load(DESKTOP_BOARD_SAVE_PORT_PATH).new(checkpoint_port)

	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()

	var issuer := _fresh_issuer(root)
	var consequence_state: RefCounted = load(CONSEQUENCE_STATE_PATH).new()

	var state_port: Object = load(STATE_PORT_PATH).new()
	assert_true(state_port.configure(gs, issuer, IDENTITY_CONTEXT).get("ok", false))
	assert_true(state_port.configure_consequence_state_port(consequence_state).get("ok", false))

	var generation_port: RefCounted = load(FAKE_GENERATION_PATH).new()
	generation_port.arm_materialize({"schema_version": 1, "width": 8, "height": 8, "mine_indices": [53,54,55,56,57,58,59,60,61,62,63], "mine_count": 11})

	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	var fake_checkpoint: RefCounted = load(FAKE_CHECKPOINT_PATH).new()
	assert_true(coordinator.configure(state_port, fake_checkpoint, generation_port, issuer).get("ok", false))
	assert_true(coordinator.configure_durable_checkpoint(durable_port, load(COMPOSER_PATH), consequence_state).get("ok", false))

	return {"coordinator": coordinator, "save_manager": save_manager, "root": root, "gs": gs,
		"issuer": issuer, "durable_port": durable_port}


## IMPORTANT 6 (brief Step 6.10). Proxy over the real GameStateDesktopBoardPort: forwards every call
## except commit(), which can be armed to fail exactly once -- simulating a hard process crash
## strictly AFTER the durable checkpoint's disk write and strictly BEFORE GameState's own live
## commit (the exact gap CRITICAL 1 closes one layer down, at DesktopCausalSequencePort -- this is
## the same shape of gap in MinesweeperRoundCoordinator._first_reveal_durable()).
class _CrashBeforeGameStateCommitPort extends RefCounted:
	var _inner: Object
	var armed := false

	func _init(inner: Object) -> void:
		_inner = inner

	func guard_external(operation_id: StringName) -> Dictionary:
		return _inner.guard_external(operation_id)

	func capture() -> Dictionary:
		return _inner.capture()

	func prepare_spec(difficulty_id: String, transaction_id: String, transaction_issuer_receipt: Dictionary) -> Dictionary:
		return _inner.prepare_spec(difficulty_id, transaction_id, transaction_issuer_receipt)

	func prepare_first_reveal(board_candidate: Dictionary, transaction_id: String,
			transaction_issuer_receipt: Dictionary, expected_checkpoint_id: String) -> Dictionary:
		return _inner.prepare_first_reveal(board_candidate, transaction_id, transaction_issuer_receipt, expected_checkpoint_id)

	func prepare_board_only(board_candidate: Dictionary, transaction_id: String, transaction_issuer_receipt: Dictionary) -> Dictionary:
		return _inner.prepare_board_only(board_candidate, transaction_id, transaction_issuer_receipt)

	func prepare_first_reveal_consequence(board_candidate: Dictionary, transaction_id: String,
			transaction_issuer_receipt: Dictionary, expected_checkpoint_id: String) -> Dictionary:
		return _inner.prepare_first_reveal_consequence(board_candidate, transaction_id, transaction_issuer_receipt, expected_checkpoint_id)

	func validate_first_reveal_candidates(game_state_candidate: Dictionary, board_candidate: Dictionary,
			consequence_candidate: Dictionary) -> Dictionary:
		return _inner.validate_first_reveal_candidates(game_state_candidate, board_candidate, consequence_candidate)

	func capture_base_snapshot_input() -> Dictionary:
		return _inner.capture_base_snapshot_input()

	func commit(candidate: Dictionary) -> Dictionary:
		if armed:
			armed = false
			return {"ok": false, "code": &"simulated_crash", "message": "process crash before live GameState commit"}
		return _inner.commit(candidate)

	func rollback(backup: Dictionary) -> Dictionary:
		return _inner.rollback(backup)

	func publish(publication: Dictionary) -> Dictionary:
		return _inner.publish(publication)


## Proxy over the real durable checkpoint port: rollback() is swallowed as a no-op success instead
## of genuinely reverting the disk write. A real process crash never gets a chance to run the
## coordinator's own rollback attempt at all (SaveManagerCheckpointPort.rollback() DOES restore the
## previous on-disk bytes when actually invoked) -- this simulates exactly that: the already-
## committed checkpoint bytes on disk survive untouched.
class _CrashBeforeRollbackPort extends RefCounted:
	var _inner: Object

	func _init(inner: Object) -> void:
		_inner = inner

	func capture() -> Dictionary:
		return _inner.capture()

	func preview_checkpoint_id(run_id: String) -> Dictionary:
		return _inner.preview_checkpoint_id(run_id)

	func prepare_checkpoint(post_commit_snapshot_input: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary:
		return _inner.prepare_checkpoint(post_commit_snapshot_input, checkpoint_kind, disk_write)

	func commit_checkpoint(candidate: Dictionary) -> Dictionary:
		return _inner.commit_checkpoint(candidate)

	func rollback(_backup: Dictionary) -> Dictionary:
		return {"ok": true, "code": &"ok"}


## Minimal failure-injectable Owner for the five ordinary (non-desktop, non-run) restore
## participants, mirroring test_desktop_board_persistence.gd's own established fake.
class _RestoreOwner extends RefCounted:
	func prepare_legacy_profile_patch(_l: Dictionary, _m: Dictionary = {}) -> Dictionary:
		return {"ok": true, "value": {"preferences": {"language": {"primary_locale_id": "en"}}}}
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


## Everything _wired() builds, PLUS the crash-injecting proxies wired into the coordinator instead
## of the real ports directly, PLUS the full 8-participant restore stack configured on the SAME
## SaveManager so a genuine prepare_restore_autosave()/commit_prepared_restore() cycle can run
## against the SAME live gs/consequence_state/board_state a crashed reveal() never touched.
func _wired_for_recovery() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("first_reveal_recovery").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(root.path_join("saves"))

	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(save_manager)
	save_manager.initialize(load(STORAGE_PATH).new(root.path_join("saves")))
	save_manager.configure_mutation_gate(load(GATE_PATH).new())
	save_manager._journal.reset(RUN_ID)

	var checkpoint_port: Object = load(CHECKPOINT_PORT_PATH).new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(load(GATE_PATH).new()).get("ok", false))
	var real_durable_port: Object = load(DESKTOP_BOARD_SAVE_PORT_PATH).new(checkpoint_port)
	var crash_durable_port := _CrashBeforeRollbackPort.new(real_durable_port)

	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()

	var issuer := _fresh_issuer(root)
	var consequence_state: RefCounted = load(CONSEQUENCE_STATE_PATH).new()
	var board_state: RefCounted = load(DESKTOP_BOARD_STATE_PATH).new()

	var real_state_port: Object = load(STATE_PORT_PATH).new()
	assert_true(real_state_port.configure(gs, issuer, IDENTITY_CONTEXT).get("ok", false))
	assert_true(real_state_port.configure_consequence_state_port(consequence_state).get("ok", false))
	var crash_state_port := _CrashBeforeGameStateCommitPort.new(real_state_port)

	var generation_port: RefCounted = load(FAKE_GENERATION_PATH).new()
	generation_port.arm_materialize({"schema_version": 1, "width": 8, "height": 8, "mine_indices": [53,54,55,56,57,58,59,60,61,62,63], "mine_count": 11})

	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	var fake_checkpoint: RefCounted = load(FAKE_CHECKPOINT_PATH).new()
	assert_true(coordinator.configure(crash_state_port, fake_checkpoint, generation_port, issuer).get("ok", false))
	assert_true(coordinator.configure_durable_checkpoint(crash_durable_port, load(COMPOSER_PATH), consequence_state).get("ok", false))

	assert_true(save_manager.configure_identity_issuer(issuer).get("ok", false))
	assert_true(save_manager.configure_identity_allocation_participant(
		load(IDENTITY_ALLOCATION_PARTICIPANT_PATH).new(issuer, save_manager)).get("ok", false))
	var owner := _RestoreOwner.new()
	assert_true(save_manager.configure_restore_participants({
		"run": load(RUN_PARTICIPANT_PATH).new(gs),
		"desktop_consequence": load(DESKTOP_CONSEQUENCE_PARTICIPANT_PATH).new(consequence_state),
		"desktop_board": load(DESKTOP_BOARD_PARTICIPANT_PATH).new(board_state),
		"profile": load(PROFILE_PARTICIPANT_PATH).new(owner),
		"localization": load(LOCALIZATION_PARTICIPANT_PATH).new(owner),
		"audio": load(AUDIO_PARTICIPANT_PATH).new(owner),
		"route": load(ROUTE_PARTICIPANT_PATH).new(owner),
		"narrative": load(NARRATIVE_PARTICIPANT_PATH).new(owner),
	}).get("ok", false))

	return {"coordinator": coordinator, "save_manager": save_manager, "root": root, "gs": gs,
		"issuer": issuer, "durable_port": real_durable_port, "state_port": crash_state_port,
		"consequence_state": consequence_state, "board_state": board_state}


## Builds a schema-valid v4 snapshot for a DIFFERENT run (reusing the same fixture
## test_desktop_board_persistence.gd already established as a proven-valid v4 base), so that run can
## be seeded as the live journal bundle before restoring "run-local" -- CheckpointJournal.
## commit_prepared()'s own duplicate-commit guard would otherwise fire for a same-run/same-sequence
## restore (test_desktop_board_persistence.gd's own established pattern, see _seed_and_save()).
func _different_live_run_snapshot(run_id: String, seq: int) -> Dictionary:
	var text := FileAccess.get_file_as_string(RECOVERY_FIXTURE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(typeof(parsed) == TYPE_DICTIONARY, "fixture must parse")
	var s: Dictionary = parsed
	s["run_id"] = run_id
	s["checkpoint_sequence"] = seq
	s["checkpoint_id"] = "%s:%d" % [run_id, seq]
	s["lifecycle"]["run_id"] = run_id
	if typeof(s["desktop"]["board"].get("identity")) == TYPE_DICTIONARY:
		s["desktop"]["board"]["identity"]["run_id"] = run_id
	var validated: Dictionary = load(RUN_SNAPSHOT_SCHEMA_PATH).validate(s)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	return validated["value"]["candidate"]


func _tx(issuer: Object) -> Dictionary:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), JSON.stringify(issued))
	return {"transaction_id": str(issued["value"]["token"]), "transaction_issuer_receipt": issued["value"]["issuer_receipt"]}


func _reveal_request(coordinator: Object, issuer: Object, cell_index: int = 0) -> Dictionary:
	var context: Dictionary = coordinator.get_entry_context("beginner")
	assert_true(context.get("ok", false), JSON.stringify(context))
	var identity: Dictionary = context["value"]["identity"]
	var tx := _tx(issuer)
	return {
		"transaction_id": tx["transaction_id"], "transaction_issuer_receipt": tx["transaction_issuer_receipt"],
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": "beginner", "cell_index": cell_index,
	}


## Reads through the SAME StorageAdapter instance the write happened on (SaveManager._storage) --
## a freshly constructed JsonFileStorage over the same root has no reconciled view of a write it
## never itself performed. StrictJson (not the bare JSON singleton, which parses every number as
## float) is this codebase's own established reader for exactly this reason.
func _autosave_document(save_manager: Node) -> Dictionary:
	var read: Dictionary = save_manager._storage.read_text("autosave.json")
	assert_true(read.get("ok", false), JSON.stringify(read))
	var parsed: Dictionary = load("res://scripts/validation/StrictJson.gd").parse_object(str(read["value"]))
	assert_true(parsed.get("ok", false), JSON.stringify(parsed))
	return parsed["value"] as Dictionary


func test_first_reveal_writes_a_durable_pre_board_autosave_with_the_charged_and_revealed_state() -> void:
	var wired := _wired()
	var coordinator: RefCounted = wired["coordinator"]
	var request := _reveal_request(coordinator, wired["issuer"])
	var result: Dictionary = coordinator.reveal(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result.get("code"), &"first_reveal_committed")

	var document := _autosave_document(wired["save_manager"])
	assert_eq(str(document["save_reason"]), "pre_board")
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	assert_eq(int(snapshot["gameplay"]["minesweeper_rounds_left"]), 1, "the round is genuinely decremented on disk")
	assert_eq(int(snapshot["gameplay"]["stats"]["motivation"]), 6, "motivation is genuinely charged on disk")
	var board: Dictionary = snapshot["desktop"]["board"]
	assert_eq(str(board["phase"]), "ACTIVE_VISIBLE")
	assert_true((board["board"]["board"]["revealed_indices"] as Array).has(0), "the forced cell is revealed on disk")
	assert_true((board["board"] as Dictionary).has("paid_start_receipt"))

	# Live state agrees with disk (forward-committed after the checkpoint, per the frozen order).
	assert_eq(coordinator.get_state()["value"]["phase"], "ACTIVE_VISIBLE")


func test_first_reveal_charges_exactly_once_across_a_retried_request() -> void:
	var wired := _wired()
	var coordinator: RefCounted = wired["coordinator"]
	var request := _reveal_request(coordinator, wired["issuer"])
	var first: Dictionary = coordinator.reveal(request)
	assert_true(first.get("ok", false), JSON.stringify(first))
	var retried: Dictionary = coordinator.reveal(request)
	assert_true(retried.get("ok", false), JSON.stringify(retried))
	assert_eq(retried["value"]["receipt"], first["value"]["receipt"], "an identical retry republishes, never recharges")
	var document := _autosave_document(wired["save_manager"])
	assert_eq(int(document["current_snapshot"]["snapshot"]["gameplay"]["stats"]["motivation"]), 6,
		"only one paid first Reveal ever reaches disk")


func test_adapter_rejects_a_desktop_less_post_commit_snapshot_input() -> void:
	var wired := _wired()
	var durable_port: Object = wired["durable_port"]
	var preview: Dictionary = durable_port.preview_checkpoint_id(RUN_ID)
	assert_true(preview.get("ok", false), JSON.stringify(preview))
	var v3_shaped := {
		"active_app_id": null, "audio_context": {}, "content_version": 1,
		"dialogic_checkpoint": {}, "route_id": "main",
		"snapshot_input": {"lifecycle": {"run_id": RUN_ID}},
	}
	var prepared: Dictionary = durable_port.prepare_checkpoint(v3_shaped["snapshot_input"], &"pre_board",
		{"kind": &"autosave", "reason": &"pre_board"})
	assert_false(prepared.get("ok", true), "a desktop-less (schema 3) snapshot_input must reject")
	assert_eq(prepared["code"], &"invalid_post_commit_snapshot_input")


func test_adapter_rejects_a_board_only_desktop_value() -> void:
	var wired := _wired()
	var durable_port: Object = wired["durable_port"]
	var prepared: Dictionary = durable_port.prepare_checkpoint(
		{"lifecycle": {"run_id": RUN_ID}, "desktop": {"board": {}}}, &"pre_board",
		{"kind": &"autosave", "reason": &"pre_board"})
	assert_false(prepared.get("ok", true), "a desktop member missing consequence must reject")
	assert_eq(prepared["code"], &"invalid_post_commit_snapshot_input")


func test_adapter_rejects_an_extra_desktop_key() -> void:
	var wired := _wired()
	var durable_port: Object = wired["durable_port"]
	var prepared: Dictionary = durable_port.prepare_checkpoint(
		{"lifecycle": {"run_id": RUN_ID}, "desktop": {"board": {}, "consequence": {}, "surprise": {}}},
		&"pre_board", {"kind": &"autosave", "reason": &"pre_board"})
	assert_false(prepared.get("ok", true), "an extra desktop key must reject")
	assert_eq(prepared["code"], &"invalid_post_commit_snapshot_input")


## IMPORTANT 6 / brief Step 6.10: drive the durable first-Reveal until the checkpoint is committed
## to disk, crash-inject strictly before the live GameState/board commits, then run a genuine
## restore cycle (prepare_restore_autosave + commit_prepared_restore) and prove disk truth alone is
## adopted -- exactly one paid first Reveal, decremented round, charged motivation, materialized
## board, matching consequence revision, and no second charge on a retried request after restore.
func test_restore_after_a_crash_between_checkpoint_commit_and_live_adoption_recovers_the_paid_first_reveal() -> void:
	var wired := _wired_for_recovery()
	var coordinator: RefCounted = wired["coordinator"]
	var save_manager: Node = wired["save_manager"]
	var gs: Node = wired["gs"]
	var crash_state_port: _CrashBeforeGameStateCommitPort = wired["state_port"]

	var request := _reveal_request(coordinator, wired["issuer"])
	crash_state_port.armed = true
	var crashed: Dictionary = coordinator.reveal(request)
	assert_false(crashed.get("ok", true),
		"the simulated crash must surface as a failure even though the checkpoint already landed on disk")

	# Live state genuinely never advanced: the crash happened strictly after the checkpoint commit
	# and strictly before any live GameState/board mutation.
	assert_eq(gs.get_stat("motivation"), 7, "motivation is untouched live")
	assert_eq(gs.minesweeper_rounds_left, 2, "the round is untouched live")
	assert_eq(str((coordinator._board_state as RefCounted).capture()["phase"]), "NONE",
		"the coordinator's own live board never left NONE")

	# But the checkpoint genuinely reached disk (the coordinator's own rollback attempt against it
	# was neutralized, mirroring a real crash that never gets a chance to run that rollback at all).
	var document := _autosave_document(save_manager)
	assert_eq(int(document["current_snapshot"]["snapshot"]["gameplay"]["minesweeper_rounds_left"]), 1,
		"the durable checkpoint carries the paid, decremented round")
	assert_eq(int(document["current_snapshot"]["snapshot"]["gameplay"]["stats"]["motivation"]), 6,
		"the durable checkpoint carries the charged motivation")

	# A different game is live when the "process restarts" (mirrors test_desktop_board_persistence
	# .gd's own established pattern for the same duplicate-commit guard).
	save_manager._journal.reset("run-recovery-elsewhere")
	save_manager._journal.commit_prepared(save_manager._journal.prepare_reset_with_initial(
		_different_live_run_snapshot("run-recovery-elsewhere", 1), &"day_start")["value"]["candidate"])

	var prepared: Dictionary = save_manager.prepare_restore_autosave()
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = save_manager.commit_prepared_restore(prepared["value"]["prepared"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))

	# Disk truth is now adopted into the SAME live objects the crashed attempt never touched: exactly
	# one paid first Reveal, decremented round, charged motivation, materialized board.
	assert_eq(gs.minesweeper_rounds_left, 1, "the restored live round is decremented")
	assert_eq(gs.get_stat("motivation"), 6, "the restored live motivation is charged")
	var restored_board: Dictionary = (wired["board_state"] as RefCounted).capture()
	assert_eq(str(restored_board["phase"]), "ACTIVE_VISIBLE")
	assert_true((restored_board["board"]["board"]["revealed_indices"] as Array).has(0),
		"the forced cell is revealed in the restored live board")
	assert_true((restored_board["board"] as Dictionary).has("paid_start_receipt"))
	var restored_consequence: Dictionary = ((wired["consequence_state"] as RefCounted).capture()["value"] as Dictionary)["state"]
	assert_eq(int(restored_consequence["run_revision"]), 0,
		"first Reveal never opens a causal-sequence pending transaction, so the restored consequence revision matches the untouched disk value")

	# No second charge on a retried request. Reconnect the coordinator's own board reference to the
	# just-restored board_state (a real process restart's Bootstrap wiring would rebuild the
	# coordinator against the restored live objects -- explicitly Task 9's territory per the
	# report's own Concerns section, not invented here) and retry the ORIGINAL request. The board is
	# no longer NONE/PREPARED_UNSTARTED, so the retry must be rejected before any further mutation.
	coordinator._board_state = wired["board_state"]
	var retried: Dictionary = coordinator.reveal(request)
	assert_false(retried.get("ok", true), "a retried request against an already-ACTIVE_VISIBLE restored board must not recharge")
	assert_eq(gs.minesweeper_rounds_left, 1, "no second charge on the retried request")
	assert_eq(gs.get_stat("motivation"), 6, "no second charge on the retried request")


func test_first_reveal_falls_back_to_the_fake_checkpoint_when_durable_is_not_configured() -> void:
	# Task-5 parity: a coordinator that never calls configure_durable_checkpoint() behaves exactly
	# as it always did (brief line 295: "cannot install a second coordinator or silently adapt a
	# fake candidate" -- the untouched fake path proves the durable addition changed nothing there).
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("first_reveal_fake_only").path_join(str(randi()))
	var issuer := _fresh_issuer(root)
	var fake_checkpoint: RefCounted = load(FAKE_CHECKPOINT_PATH).new()
	var generation_port: RefCounted = load(FAKE_GENERATION_PATH).new()
	generation_port.arm_materialize({"schema_version": 1, "width": 8, "height": 8, "mine_indices": [53,54,55,56,57,58,59,60,61,62,63], "mine_count": 11})
	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	var state_port: Object = load(STATE_PORT_PATH).new()
	assert_true(state_port.configure(gs, issuer, IDENTITY_CONTEXT).get("ok", false))
	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	assert_true(coordinator.configure(state_port, fake_checkpoint, generation_port, issuer).get("ok", false))

	var result: Dictionary = coordinator.reveal(_reveal_request(coordinator, issuer))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_true(fake_checkpoint.is_sealed("run-local:1"), "the untouched fake path still seals, exactly as Task 5 left it")
