extends "res://addons/gut/test.gd"

const PARTICIPANT_PATH := "res://scripts/application/restore/DesktopBoardRestoreParticipant.gd"
const BOARD_STATE_PATH := "res://scripts/domain/minesweeper/DesktopBoardState.gd"

func _exists() -> bool:
	return ResourceLoader.exists(PARTICIPANT_PATH, "Script")

func _fresh_state() -> Object:
	return load(BOARD_STATE_PATH).new()

func _participant(state: Object) -> RefCounted:
	return load(PARTICIPANT_PATH).new(state)

func _none_snapshot() -> Dictionary:
	return {"schema_version": 1, "phase": "NONE", "revision": 0, "identity": null, "candidate": null,
		"board": null, "settlement": null, "command_receipts": {}, "terminal_receipts": {}}

func test_participant_exists() -> void:
	assert_true(_exists(), "DesktopBoardRestoreParticipant.gd must exist")

func test_prepare_rejects_missing_or_invalid_state() -> void:
	if not _exists(): return
	var participant := _participant(_fresh_state())
	assert_false(participant.prepare({}).get("ok", true), "missing input.state rejects")
	assert_false(participant.prepare({"state": {"garbage": true}}).get("ok", true), "an invalid state rejects")

func test_capture_wraps_the_raw_capture_dict_in_an_ok_envelope() -> void:
	# DesktopBoardState.capture() returns its state dict directly, unlike most of this codebase's
	# other prepare/commit seams -- this participant is responsible for the uniform {ok,value} wrap
	# every SaveManager participant is required to return.
	if not _exists(): return
	var state := _fresh_state()
	var participant := _participant(state)
	var captured: Dictionary = participant.capture()
	assert_true(captured.get("ok", false), JSON.stringify(captured))
	assert_eq((captured["value"] as Dictionary)["snapshot"], state.capture())

func test_prepare_capture_apply_and_rollback_round_trip() -> void:
	if not _exists(): return
	var state := _fresh_state()
	var participant := _participant(state)
	var captured: Dictionary = participant.capture()
	assert_true(captured.get("ok", false))
	var backup: Dictionary = captured["value"]

	var target_state := _none_snapshot()
	var prepared: Dictionary = participant.prepare({"state": target_state})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var plan: Dictionary = (prepared["value"] as Dictionary)["board_plan"]

	var applied: Dictionary = participant.apply_silent(plan)
	assert_true(applied.get("ok", false), JSON.stringify(applied))
	assert_eq(state.capture()["phase"], "NONE")

	var finalized: Dictionary = participant.finalize()
	assert_true(finalized.get("ok", false))

	var rolled: Dictionary = participant.rollback_silent(backup)
	assert_true(rolled.get("ok", false), JSON.stringify(rolled))
	assert_eq(state.capture(), (backup as Dictionary)["snapshot"], "rollback restores the exact captured snapshot")

func test_apply_silent_rejects_a_malformed_plan() -> void:
	if not _exists(): return
	var participant := _participant(_fresh_state())
	assert_false(participant.apply_silent({}).get("ok", true), "apply_silent requires plan.candidate")

func test_rollback_silent_rejects_a_malformed_backup() -> void:
	if not _exists(): return
	var participant := _participant(_fresh_state())
	assert_false(participant.rollback_silent({}).get("ok", true), "rollback_silent requires backup.snapshot")


func test_scene_player_restore_starts_empty_retry_session_and_rollback_recovers_genuine_result() -> void:
	var root := preload("res://tests/support/FakeDesktopIssuerRootStore.gd").new("44".repeat(32), 1)
	var issuer := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd").new()
	assert_true(issuer.configure(root).ok)
	var state := _fresh_state()
	assert_true(state.configure_scene_payments(issuer).ok)
	var prepared: Dictionary = state.prepare_unpaid_shell({"transaction_id": "original-shell",
		"request_fingerprint": "original-request", "identity": null, "expected_revision": 0},
		"beginner", {"flagged_indices": [], "actions": []})
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var original_candidate: Dictionary = prepared.value.candidate
	var original_result: Dictionary = state.commit(original_candidate)
	assert_true(original_result.ok, str(original_result))
	var live: Dictionary = state.capture()
	assert_true(live.command_receipts.has("original-shell"))
	var participant: RefCounted = load(PARTICIPANT_PATH).new(state, issuer)
	var backup: Dictionary = participant.capture().value
	var player: Dictionary = load(BOARD_STATE_PATH).project_player_state(live)
	assert_true(player.ok, str(player))
	if not player.ok: return
	assert_false(player.value.snapshot.has("command_receipts"))
	assert_eq(state.capture(), live, "player projection cannot clear live retry records")
	assert_eq(backup.snapshot, live, "temporary backup retains genuine retry records")
	assert_false(participant.prepare({"schema_version": 9, "state": live}).ok,
		"player admission refuses the full live-only ledger shape")
	prepared = participant.prepare({"schema_version": 9, "state": player.value.snapshot})
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_eq(state.capture(), live, "preparing Load leaves the old session intact")
	assert_true(participant.apply_silent(prepared.value.board_plan).ok)
	assert_true(state.capture().command_receipts.is_empty(), "successful adoption starts a fresh retry session")
	assert_eq(state.capture().candidate, live.candidate)
	assert_eq(state.commit(original_candidate).get("code"), &"stale_revision",
		"the old acknowledged command is not replayed after player restoration")
	assert_true(participant.rollback_silent(backup).ok)
	assert_eq(state.capture(), live, "later participant failure restores the whole prior live board")
	assert_eq(state.commit(original_candidate), original_result,
		"rollback restores the genuine acknowledgement needed by the original retry")
	assert_eq(state.capture(), live, "replayed acknowledgement does not mutate restored state")
