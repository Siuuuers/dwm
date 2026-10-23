extends "res://addons/gut/test.gd"

const PORT = preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const CONTACTS = preload("res://scripts/domain/contact/ContactInvitationState.gd")

func before_each() -> void:
	GameState.reset_game()

func test_unanswered_invitation_rollover_is_saved_before_live_publication() -> void:
	var offered: Dictionary = CONTACTS.prepare_offer_solo(GameState.contacts, "priscilla", 1,
		"msg.solo.priscilla.day1", "offer-priscilla")
	assert_true(offered.get("ok", false))
	GameState.contacts = offered.value.candidate
	var port: Object = PORT.new(GameState)
	assert_true(port.begin_or_resume("done-unanswered").get("ok", false))
	for index: int in 32:
		var begun: Dictionary = port.begin_next_stage()
		assert_true(begun.get("ok", false), str(begun))
		if not begun.get("ok", false): return
		var stage: Dictionary = begun.value.stage
		var prepared: Dictionary = port.prepare_completion(str(stage.transaction_id), begun.value.receipt)
		assert_true(prepared.get("ok", false), str(prepared))
		if not prepared.get("ok", false): return
		if str(stage.stage_id) != "invitation_rollover":
			assert_true(port.commit(prepared.value.run_candidate).get("ok", false))
			continue
		var snapshot: Dictionary = prepared.value.snapshot_input.snapshot_input
		assert_eq(GameState.contacts.solo_actions["solo:priscilla:day1"].state, "AVAILABLE")
		assert_eq(snapshot.contacts.solo_actions["solo:priscilla:day1"].state, "RESOLVED_UNANSWERED")
		var messages: Array = snapshot.contacts.messages.priscilla
		assert_eq(messages.size(), 2, "one offer and exactly one queued follow-up")
		assert_eq(messages[1].type, "nevermind")
		assert_eq(messages[1].target_day, 2)
		assert_eq(begun.value.receipt.value.message_transaction_ids, [messages[1].transaction_id])
		var backup: Dictionary = port.capture().value.backup
		assert_true(port.commit(prepared.value.run_candidate).get("ok", false))
		assert_eq(GameState.contacts, snapshot.contacts, "live state matches the disk candidate")
		var replay: Dictionary = port.prepare_completion(str(stage.transaction_id), begun.value.receipt)
		assert_true(replay.value.duplicate, "completed receipt is recognized as replay")
		assert_eq(GameState.contacts.messages.priscilla.size(), 2)
		assert_true(port.rollback(backup).get("ok", false))
		assert_eq(GameState.contacts.solo_actions["solo:priscilla:day1"].state, "AVAILABLE")
		assert_eq(GameState.contacts.messages.priscilla.size(), 1)
		return
	fail_test("rollover stage was never reached")
