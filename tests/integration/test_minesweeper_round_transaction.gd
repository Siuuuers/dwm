extends "res://addons/gut/test.gd"
# dwm-p2r.17: the Minesweeper ROUND TRANSACTION carries contacts, so group activation can COMMIT.
#
# THE FIRST REAL-PORT DRIVE of the full round transaction against the real GameState autoload:
# every dating/coordination suite before this drove FakeMinesweeperStatePort, and the round-reward
# unit suite calls GameState's reward functions directly rather than the port's transaction. Each
# helper below commits BOTH candidates exactly as MinesweeperRoundCoordinator does (the begin
# candidate at its :187, the finalized candidate at its :274), so what these tests prove is the
# production transaction, not a shortcut.
#
# THE SEEDS mirror canon: a fresh Day-2 run affords exactly TWO app rounds (rounds_left 2 over
# floor 0), so the third round of the group-activation law is granted the canon way -- supportz
# lowers the floor (change_minesweeper_round_floor(-1)). Day and floor are the ONLY seeded facts;
# the pair solos are built by rounds 1-2 through the production unlock + G1 bridge, never seeded.

const STATE_PORT := preload("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd")

var _port: RefCounted


func before_each() -> void:
	GameState.reset_game()
	_port = STATE_PORT.new(GameState)


## Day plus optional extra playable rounds, the canon supportz-equivalent grant.
func _enter_day(day: int, extra_rounds: int = 0) -> void:
	assert_true(GameState.apply_save_dict({"day": day}).get("ok", false), "day must apply")
	for _i: int in range(extra_rounds):
		GameState.change_minesweeper_round_floor(-1)


## One COMPLETE app-round transaction through the port, committing both candidates as the
## coordinator does. Returns finalize_complete's value ({} after any refusal).
func _complete_app_round(ordinal: int, outcome: String = "cleared") -> Dictionary:
	var round_id := "run-test:day%d:round-%d" % [GameState.day, ordinal]
	var begun: Dictionary = _port.prepare_begin(
		{"context": "app", "difficulty": "beginner"}, round_id)
	assert_true(begun.get("ok", false), "round %d begins: %s" % [ordinal, str(begun)])
	if not begun.get("ok", false):
		return {}
	assert_true(_port.commit((begun["value"] as Dictionary)["candidate"]).get("ok", false),
		"the begin candidate commits, exactly as the coordinator commits it")
	var active: Dictionary = (begun["value"] as Dictionary)["active_round"]
	var prepared: Dictionary = _port.prepare_complete(active,
		{"context": "app", "difficulty": "beginner", "outcome": outcome}, "tx:" + round_id)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return {}
	var finalized: Dictionary = _port.finalize_complete(prepared, "ckpt:" + round_id)
	assert_true(finalized.get("ok", false), str(finalized))
	if not finalized.get("ok", false):
		return {}
	assert_true(_port.commit((finalized["value"] as Dictionary)["candidate"]).get("ok", false),
		"the finalized candidate commits")
	return finalized["value"] as Dictionary


func _group_state() -> String:
	return str(((GameState.contacts as Dictionary)["group_action"] as Dictionary)["state"])


func _solo_state(friend: String, day: int) -> String:
	var solo: Variant = ((GameState.contacts as Dictionary)["solo_actions"] as Dictionary) \
		.get("solo:%s:day%d" % [friend, day])
	return str((solo as Dictionary)["state"]) if typeof(solo) == TYPE_DICTIONARY else "<absent>"


## The bead's ACCEPTANCE headline. Three app rounds on Day 2: rounds 1-2 build the pair solos
## through the production unlock + bridge ON THE TRANSACTION'S OWN CLONES, and the third commits
## group_action AVAILABLE_UNOPENED with a null inviter and no history, with the receipt naming
## the gactivate transaction the domain actually recorded -- never a port-derived rule.
func test_the_third_day2_round_commits_group_activation_with_its_receipt() -> void:
	_enter_day(2, 1)
	var first := _complete_app_round(1)
	if first.is_empty():
		return
	assert_eq(((first["domain_receipt"] as Dictionary)["message_transaction_ids"] as Array),
		["offer:priscilla:day2"],
		"round 1 committed and reported the priscilla solo offer the bridge recorded")
	var second := _complete_app_round(2)
	if second.is_empty():
		return
	assert_eq(((second["domain_receipt"] as Dictionary)["message_transaction_ids"] as Array),
		["offer:lavinia:day2"],
		"round 2 committed and reported the lavinia solo offer")
	assert_eq(_solo_state("priscilla", 2), "AVAILABLE",
		"round 1's committed contacts really carry the priscilla solo")
	assert_eq(_solo_state("lavinia", 2), "AVAILABLE",
		"round 2's committed contacts really carry the lavinia solo")
	assert_eq(_group_state(), "INACTIVE", "no activation before the third round")

	var third := _complete_app_round(3)
	if third.is_empty():
		return

	assert_eq(_group_state(), "AVAILABLE_UNOPENED",
		"the third round's COMMIT carried the activation into live state")
	var group: Dictionary = (GameState.contacts as Dictionary)["group_action"] as Dictionary
	assert_eq(group.get("inviter_id"), null, "canon group offer has no inviter")
	assert_eq(group.get("history_generated"), false, "no history yet")
	var receipt: Dictionary = third["domain_receipt"] as Dictionary
	assert_eq(str(receipt.get("group_activation_transaction_id", "")), "gactivate:day2",
		"the receipt reports the exact transaction the domain recorded")
	assert_eq((receipt.get("message_transaction_ids", null) as Array), [],
		"round 3 has no daily-message friend, so no offer rides this receipt")
	assert_true((third["candidate"] as Dictionary).has("contacts"),
		"the committed candidate carried the contacts section")


## Transition 1->2 commits NO activation and reports null -- the overshoot guard.
func test_the_second_round_commits_no_activation_and_reports_null() -> void:
	_enter_day(2, 1)
	var first := _complete_app_round(1)
	if first.is_empty():
		return
	var second := _complete_app_round(2)
	if second.is_empty():
		return
	assert_eq(_group_state(), "INACTIVE", "1->2 is not the activation transition")
	assert_eq((second["domain_receipt"] as Dictionary).get("group_activation_transaction_id"),
		null, "and the receipt says so")


## Transition 3->4 re-activates nothing: the bridge refuses off the activation round and the
## module refuses a non-INACTIVE group; the fourth receipt reports null.
func test_the_fourth_round_does_not_reactivate() -> void:
	_enter_day(2, 2)
	for ordinal: int in [1, 2, 3]:
		if _complete_app_round(ordinal).is_empty():
			return
	assert_eq(_group_state(), "AVAILABLE_UNOPENED", "the third round activated")

	var fourth := _complete_app_round(4)
	if fourth.is_empty():
		return

	assert_eq(_group_state(), "AVAILABLE_UNOPENED", "the fourth round changed nothing")
	assert_eq((fourth["domain_receipt"] as Dictionary).get("group_activation_transaction_id"),
		null, "and reported no activation")


## A non-window day never activates, however many rounds run.
func test_a_non_window_day_never_activates() -> void:
	_enter_day(3, 1)
	var third: Dictionary = {}
	for ordinal: int in [1, 2, 3]:
		third = _complete_app_round(ordinal)
		if third.is_empty():
			return
	assert_eq(_group_state(), "INACTIVE", "day 3 is not a group window")
	assert_eq((third["domain_receipt"] as Dictionary).get("group_activation_transaction_id"),
		null)


## An already-read pair solo blocks activation (solo_already_read) and the receipt reports null.
func test_an_already_read_solo_blocks_activation_with_a_null_receipt() -> void:
	_enter_day(2, 1)
	for ordinal: int in [1, 2]:
		if _complete_app_round(ordinal).is_empty():
			return
	var contacts: Dictionary = (GameState.contacts as Dictionary).duplicate(true)
	(contacts["read_watermarks"] as Dictionary)["priscilla"] = 999
	GameState.contacts = contacts

	var third := _complete_app_round(3)
	if third.is_empty():
		return

	assert_eq(_group_state(), "INACTIVE", "a read solo is no longer an eligible pair offer")
	assert_eq((third["domain_receipt"] as Dictionary).get("group_activation_transaction_id"),
		null)


## Day 6 is the second canon window, end to end.
func test_the_third_day6_round_commits_group_activation() -> void:
	_enter_day(6, 1)
	var third: Dictionary = {}
	for ordinal: int in [1, 2, 3]:
		third = _complete_app_round(ordinal)
		if third.is_empty():
			return
	assert_eq(_group_state(), "AVAILABLE_UNOPENED", "day 6 activates exactly as day 2 does")
	assert_eq(str((third["domain_receipt"] as Dictionary).get(
		"group_activation_transaction_id", "")), "gactivate:day6")


## Dating rounds never touch contacts and never activate, under any transition.
func test_a_dating_round_commits_no_contact_change() -> void:
	_enter_day(3, 0)
	var contacts_before: Dictionary = (GameState.contacts as Dictionary).duplicate(true)
	var active := {"round_id": "run-test:day3:dating-1", "context": "dating",
		"difficulty": "beginner"}
	var prepared: Dictionary = _port.prepare_complete(active,
		{"context": "dating", "difficulty": "beginner", "outcome": "perfect"}, "tx:dating-1")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return
	var finalized: Dictionary = _port.finalize_complete(prepared, "ckpt:dating-1")
	assert_true(finalized.get("ok", false), str(finalized))
	if not finalized.get("ok", false):
		return
	assert_true(_port.commit((finalized["value"] as Dictionary)["candidate"]).get("ok", false))

	assert_eq(GameState.contacts, contacts_before,
		"a dating round commits no contact change whatsoever")
	var receipt: Dictionary = (finalized["value"] as Dictionary)["domain_receipt"] as Dictionary
	assert_eq(receipt.get("group_activation_transaction_id"), null)
	assert_eq((receipt.get("message_transaction_ids", null) as Array), [])


## capture -> commit an ACTIVATING round -> rollback restores the pre-round contacts bytes.
func test_rollback_restores_contacts_beside_gameplay() -> void:
	_enter_day(2, 1)
	for ordinal: int in [1, 2]:
		if _complete_app_round(ordinal).is_empty():
			return
	var backup: Dictionary = _port.capture()
	assert_true(backup.get("ok", false), str(backup))
	if not backup.get("ok", false):
		return
	var contacts_before: Dictionary = (GameState.contacts as Dictionary).duplicate(true)
	if _complete_app_round(3).is_empty():
		return
	assert_eq(_group_state(), "AVAILABLE_UNOPENED",
		"the activation really landed before the rollback")

	assert_true(_port.rollback(backup["value"]).get("ok", false))

	assert_eq(GameState.contacts, contacts_before,
		"rollback restored the contacts section beside gameplay")
	assert_eq(_group_state(), "INACTIVE", "the activation is gone with it")


## The post-result checkpoint records the CANDIDATE's contacts, not the live pre-commit bytes --
## a torn snapshot (post-round gameplay beside pre-round contacts) can never be durable.
func test_the_post_result_checkpoint_carries_the_candidate_contacts() -> void:
	_enter_day(2, 1)
	for ordinal: int in [1, 2]:
		if _complete_app_round(ordinal).is_empty():
			return
	var round_id := "run-test:day2:round-3"
	var begun: Dictionary = _port.prepare_begin(
		{"context": "app", "difficulty": "beginner"}, round_id)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false):
		return
	assert_true(_port.commit((begun["value"] as Dictionary)["candidate"]).get("ok", false))
	var prepared: Dictionary = _port.prepare_complete(
		(begun["value"] as Dictionary)["active_round"],
		{"context": "app", "difficulty": "beginner", "outcome": "cleared"}, "tx:" + round_id)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return

	var finalized: Dictionary = _port.finalize_complete(prepared, "ckpt:" + round_id)

	assert_true(finalized.get("ok", false), str(finalized))
	if not finalized.get("ok", false):
		return
	var inner: Dictionary = finalized["value"] as Dictionary
	var snapshot_contacts: Variant = ((inner["post_result_checkpoint_inputs"] as Dictionary) \
		["snapshot_input"] as Dictionary).get("contacts")
	var candidate_contacts: Variant = (inner["candidate"] as Dictionary).get("contacts")
	assert_eq(typeof(candidate_contacts), TYPE_DICTIONARY,
		"the finalized candidate carries a contacts section")
	if typeof(candidate_contacts) != TYPE_DICTIONARY:
		return
	assert_eq(snapshot_contacts, candidate_contacts,
		"the checkpoint carries the candidate's contacts, not a live re-read")
	assert_eq(str(((snapshot_contacts as Dictionary)["group_action"] as Dictionary)["state"]),
		"AVAILABLE_UNOPENED",
		"and those bytes carry the activation this round produced, BEFORE the commit")


## The abort path: the coordinator funnels prepare_abort's candidate through rollback(), so the
## abort candidate must land whole -- round refunded, motivation refunded, contacts untouched.
## Green today, and the guard that REDs the moment a candidate reshape forgets this consumer.
func test_an_aborted_round_refunds_through_the_rollback_door() -> void:
	_enter_day(2, 0)
	var rounds_before: int = int(GameState.minesweeper_rounds_left)
	var motivation_before: int = int(GameState.get_stat("motivation"))
	var contacts_before: Dictionary = (GameState.contacts as Dictionary).duplicate(true)
	var begun: Dictionary = _port.prepare_begin(
		{"context": "app", "difficulty": "beginner"}, "run-test:day2:abort-1")
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false):
		return
	assert_true(_port.commit((begun["value"] as Dictionary)["candidate"]).get("ok", false))
	var aborted: Dictionary = _port.prepare_abort(
		(begun["value"] as Dictionary)["active_round"], &"user_abort", "tx:abort-1")
	assert_true(aborted.get("ok", false), str(aborted))
	if not aborted.get("ok", false):
		return

	assert_true(_port.rollback((aborted["value"] as Dictionary)["candidate"]).get("ok", false),
		"the abort candidate goes through the ROLLBACK door, exactly as the coordinator sends it")

	assert_eq(int(GameState.minesweeper_rounds_left), rounds_before,
		"the aborted round was refunded")
	assert_eq(int(GameState.get_stat("motivation")), motivation_before,
		"the motivation cost was refunded")
	assert_eq(GameState.contacts, contacts_before, "and contacts are untouched")
