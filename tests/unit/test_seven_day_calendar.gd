extends GutTest

const CALENDAR := preload("res://scripts/domain/contact/SevenDayCalendar.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ORDINARY := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const COPY := preload("res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd")

# Independently transcribed from approved fixed-calendar and ending rules.
const ORDINARY_FRIENDS := ["lavinia", "sylvia", "priscilla", "lavinia", "priscilla", "sylvia"]
const SOLO_ORDERS := [["priscilla", "sylvia"], ["priscilla", "lavinia"],
	["lavinia", "sylvia"], ["priscilla", "sylvia"],
	["lavinia", "sylvia"], ["priscilla", "lavinia"]]
const FRIEND_DAYS := {"priscilla": [1, 2, 4, 6], "lavinia": [2, 3, 5, 6], "sylvia": [1, 3, 4, 5]}

func before_each() -> void:
	GameState.reset_game()

func test_all_twelve_solo_windows_and_round_orders_match_each_live_facade() -> void:
	var catalog := CATALOG.new()
	var before: Dictionary = GameState.capture_restore_state().value.backup
	for day: int in range(1, 7):
		assert_eq(CALENDAR.solo_order(day), SOLO_ORDERS[day - 1])
		assert_false(ORDINARY_FRIENDS[day - 1] in CALENDAR.solo_order(day),
			"ordinary and invitation messages belong to different threads that day")
		assert_eq(catalog.get_daily_contact_message_order(day), SOLO_ORDERS[day - 1])
		for round_number: int in range(0, 6):
			var expected: String = SOLO_ORDERS[day - 1][round_number - 1] if round_number in [1, 2] else ""
			assert_eq(GameState.get_daily_message_friend_for_finished_round(round_number, day), expected,
				"day%d round%d" % [day, round_number])
		for friend: String in CONTACTS.FRIEND_IDS:
			assert_eq(GameState.is_invitation_day(friend, day), day in FRIEND_DAYS[friend])
	for friend: String in FRIEND_DAYS:
		assert_eq(CALENDAR.solo_days_for(friend), FRIEND_DAYS[friend])
		assert_eq(catalog.get_invitation_days_for_friend(friend), FRIEND_DAYS[friend])
	assert_eq(catalog.get_invitation_days(), FRIEND_DAYS)
	assert_eq(GameState.capture_restore_state().value.backup, before, "calendar queries never mutate the run")

func test_all_six_ordinary_messages_keep_three_choices_and_day7_has_none() -> void:
	var contacts := CONTACTS.make_defaults()
	var before := contacts.duplicate(true)
	var reply_ids := {}
	for day: int in range(1, 8):
		var expected: String = ORDINARY_FRIENDS[day - 1] if day < 7 else ""
		assert_eq(CALENDAR.ordinary_friend(day), expected)
		for friend: String in CONTACTS.FRIEND_IDS:
			var result: Dictionary = ORDINARY.available(contacts, day, friend)
			assert_true(result.ok, str(result))
			if not result.ok: continue
			if friend != expected:
				assert_eq(result.value, {})
			else:
				assert_eq(result.value.choices.size(), 3)
				for choice: Dictionary in result.value.choices:
					assert_eq(choice.friend_id, friend)
					assert_eq(choice.day, day)
					reply_ids[choice.reply_id] = true
	assert_eq(reply_ids.size(), 18)
	assert_eq(contacts, before, "enumerating unanswered messages allocates no receipt or history")

func test_group_windows_are_exact_and_do_not_create_a_third_solo() -> void:
	var catalog := CATALOG.new()
	assert_eq(CALENDAR.group_days(), [2, 6])
	assert_eq(CONTACTS.GROUP_WINDOW_DAYS, [2, 6])
	assert_eq(catalog.get_group_invitation_days(), [2, 6])
	for day: int in range(0, 9):
		assert_eq(GameState.is_group_invitation_day(day), day in [2, 6])
		assert_eq(CALENDAR.is_group_day(day), day in [2, 6])
		if day != 7:
			assert_eq(GameState.get_daily_message_friend_for_finished_round(3, day), "")

func test_day7_ending_delivery_remains_separate_from_ordinary_and_dating_windows() -> void:
	var ending_order := ["priscilla", "lavinia", "sylvia"]
	assert_eq(CALENDAR.solo_order(7), [])
	assert_eq(CALENDAR.ordinary_friend(7), "")
	assert_eq(CALENDAR.contact_round_order(7), ending_order)
	assert_eq(CATALOG.new().get_daily_contact_message_order(7), ending_order)
	for floor_value: int in [-3, -2, -1, 0]:
		GameState.minesweeper_round_floor = floor_value
		for index: int in range(3):
			assert_eq(GameState.get_daily_message_friend_for_finished_round(index + 1, 7), ending_order[index],
				"already achieved round%d, floor%d" % [index + 1, floor_value])
	for friend: String in ending_order:
		assert_false(GameState.is_invitation_day(friend, 7), "ending offers are not Days1–6 dating slots")
		assert_true(COPY.build().has("solo:%s:day7" % friend), "ending offer copy remains reachable")
	assert_eq(GameState.get_daily_message_friend_for_finished_round(4, 7), "")

func test_sylvia_achieved_third_round_offer_uses_tier_without_granting_a_round() -> void:
	GameState._lifecycle_set_playing_day(7)
	GameState.minesweeper_round_floor = 0
	GameState.minesweeper_rounds_left = 0
	GameState.minesweeper_app_rounds_finished_today = 3
	GameState.dating_route_state.sylvia.relationship_state = "ambiguous"
	GameState.affection.sylvia = -4
	assert_false(GameState.has_minesweeper_app_round_available())
	var offered: Dictionary = GameState.unlock_contact_message_after_minesweeper_finished({})
	assert_eq(offered, {"friend_id": "sylvia", "day": 7})
	assert_true(GameState.contacts.solo_actions.has("solo:sylvia:day7"))
	assert_true(GameState.is_date_unlocked("sylvia", 7))
	assert_eq(GameState.affection.sylvia, -4)
	assert_false(GameState.has_minesweeper_app_round_available(), "calendar lookup grants no playable round")
	assert_eq(GameState.minesweeper_rounds_left, 0)

func test_calendar_results_are_detached_and_default_facades_use_the_active_day() -> void:
	var catalog := CATALOG.new()
	var order: Array = CALENDAR.solo_order(1)
	order[0] = "foreign"
	var ending_order: Array = CALENDAR.contact_round_order(7)
	ending_order.clear()
	var groups: Array = catalog.get_group_invitation_days()
	groups.append(7)
	var days: Dictionary = catalog.get_invitation_days()
	days.priscilla.clear()
	assert_eq(CALENDAR.solo_order(1), ["priscilla", "sylvia"])
	assert_eq(CALENDAR.contact_round_order(7), ["priscilla", "lavinia", "sylvia"])
	assert_eq(CONTACTS.GROUP_WINDOW_DAYS, [2, 6])
	assert_eq(catalog.get_invitation_days(), FRIEND_DAYS)
	GameState._lifecycle_set_playing_day(5)
	assert_eq(catalog.get_daily_contact_message_order(), ["lavinia", "sylvia"])
	assert_true(GameState.is_invitation_day("sylvia"))
	assert_false(GameState.is_group_invitation_day())
	assert_eq(GameState.get_daily_message_friend_for_finished_round(2), "sylvia")

func test_invalid_calendar_queries_never_fabricate_an_invitation_or_ordinary_choice() -> void:
	var catalog := CATALOG.new()
	for day: int in [0, 8, 99]:
		assert_eq(CALENDAR.solo_order(day), [])
		assert_eq(CALENDAR.contact_round_order(day), [])
		assert_eq(CALENDAR.ordinary_friend(day), "")
		assert_eq(catalog.get_daily_contact_message_order(day), ["priscilla", "sylvia"],
			"the catalog's existing invalid-target convention uses the current active day")
		assert_eq(GameState.get_daily_message_friend_for_finished_round(1, day), "")
	for friend: String in ["", "foreign", "sylvia"]:
		var result := ORDINARY.available(CONTACTS.make_defaults(), 7, friend)
		assert_true(result.ok, str(result))
		if result.ok: assert_eq(result.value, {})
	assert_eq(CALENDAR.solo_days_for("foreign"), [])
	assert_eq(catalog.get_invitation_days_for_friend("foreign"), [])
	assert_eq(catalog.get_contact_message_order_or_fallback(8), ["priscilla", "sylvia"],
		"the presentation facade also retains current-day fallback")
