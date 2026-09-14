extends GutTest

const GAME_STATE := preload("res://autoload/GameState.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")

const FRIENDS := ["priscilla", "lavinia", "sylvia"]
const INVITATION_DAYS := {
	"priscilla": [1, 2, 4, 6],
	"lavinia": [2, 3, 5, 6],
	"sylvia": [1, 3, 4, 5],
}
const MESSAGE_ORDER := {
	1: ["priscilla", "sylvia"],
	2: ["priscilla", "lavinia"],
	3: ["lavinia", "sylvia"],
	4: ["priscilla", "sylvia"],
	5: ["lavinia", "sylvia"],
	6: ["priscilla", "lavinia"],
	7: ["priscilla", "lavinia", "sylvia"],
}


func _game() -> Node:
	var game: Node = autofree(GAME_STATE.new())
	add_child(game)
	game.reset_game()
	return game


func _state(game: Node) -> Dictionary:
	var captured: Dictionary = game.capture_restore_state()
	assert_true(captured.get("ok", false), str(captured))
	return captured.get("value", {}).get("backup", {}).duplicate(true)


func _active_group(day: int) -> Dictionary:
	var state: Dictionary = CONTACT_STATE.make_defaults()
	for friend: String in ["priscilla", "lavinia"]:
		var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(state, friend, day,
			"offer.%s.day%d" % [friend, day], "tx.offer.%s.day%d" % [friend, day])
		assert_true(offered.get("ok", false), str(offered))
		if not offered.get("ok", false): return {}
		state = offered.value.candidate
	var activated: Dictionary = CONTACT_STATE.prepare_activate_group_after_round(
		state, day, 2, 3, "tx.group.day%d" % day)
	assert_true(activated.get("ok", false), str(activated))
	return activated.get("value", {}).get("candidate", {}).duplicate(true)


func test_is_invitation_day_covers_the_complete_explicit_and_active_day_contract() -> void:
	var game := _game()
	game._lifecycle_set_playing_day(5)
	var before := _state(game)
	for day: int in range(1, 8):
		for friend: String in FRIENDS:
			assert_eq(game.is_invitation_day(friend, day), day in INVITATION_DAYS[friend],
				"%s/day%d" % [friend, day])
	assert_false(game.is_invitation_day("priscilla"), "active Day 5 is not Priscilla's window")
	assert_true(game.is_invitation_day("lavinia"), "default lookup uses active Day 5")
	assert_true(game.is_invitation_day("sylvia"), "default lookup uses active Day 5")
	for invalid_day: int in [0, 8, 99]:
		for friend: String in FRIENDS:
			assert_false(game.is_invitation_day(friend, invalid_day),
				"invalid day %d fabricates no invitation" % invalid_day)
	for invalid_friend: String in ["", "foreign"]:
		assert_false(game.is_invitation_day(invalid_friend, 1))
	assert_eq(_state(game), before, "invitation-day queries never mutate the run")


func test_is_group_invitation_day_covers_the_complete_explicit_and_active_day_contract() -> void:
	var game := _game()
	game._lifecycle_set_playing_day(6)
	var before := _state(game)
	for day: int in range(1, 8):
		assert_eq(game.is_group_invitation_day(day), day in [2, 6], "day%d" % day)
	assert_true(game.is_group_invitation_day(), "default lookup uses active Day 6")
	for invalid_day: int in [0, 8, 99]:
		assert_false(game.is_group_invitation_day(invalid_day),
			"invalid day %d fabricates no group window" % invalid_day)
	assert_eq(_state(game), before, "group-day queries never mutate the run")


func test_daily_message_query_covers_all_days_defaults_invalids_and_group_suppression() -> void:
	var game := _game()
	game._lifecycle_set_playing_day(5)
	var before := _state(game)
	for day: int in range(1, 8):
		var order: Array = MESSAGE_ORDER[day]
		for round_number: int in range(0, 5):
			var expected: String = order[round_number - 1] if round_number >= 1 and round_number <= order.size() else ""
			assert_eq(game.get_daily_message_friend_for_finished_round(round_number, day), expected,
				"day%d/round%d" % [day, round_number])
	assert_eq(game.get_daily_message_friend_for_finished_round(1), "lavinia")
	assert_eq(game.get_daily_message_friend_for_finished_round(2), "sylvia")
	assert_eq(game.get_daily_message_friend_for_finished_round(3), "")
	for invalid_day: int in [0, 8, 99]:
		assert_eq(game.get_daily_message_friend_for_finished_round(1, invalid_day), "")
	for invalid_round: int in [-1, 0, 4, 99]:
		assert_eq(game.get_daily_message_friend_for_finished_round(invalid_round, 1), "")
	assert_eq(_state(game), before, "ordinary message queries never mutate the run")

	game._lifecycle_set_playing_day(2)
	game.contacts = _active_group(2)
	assert_false(game.contacts.is_empty(), "the suppression fixture is a real active group state")
	assert_true(CONTACT_STATE.validate_state(game.contacts).get("ok", false))
	before = _state(game)
	for round_number: int in [1, 2, 3]:
		assert_eq(game.get_daily_message_friend_for_finished_round(round_number), "",
			"the active same-day group suppresses every solo message")
	assert_eq(_state(game), before, "same-day suppression is read-only")

	game._lifecycle_set_playing_day(3)
	before = _state(game)
	assert_eq(game.get_daily_message_friend_for_finished_round(1), "lavinia",
		"a stale Day-2 group does not suppress active Day-3 messages")
	assert_eq(game.get_daily_message_friend_for_finished_round(2, 3), "sylvia")
	assert_eq(game.get_daily_message_friend_for_finished_round(1, 2), "",
		"the same retained group still suppresses queries for its own day")
	assert_eq(_state(game), before, "stale-group queries never mutate the run")
