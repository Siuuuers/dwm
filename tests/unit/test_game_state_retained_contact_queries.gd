extends GutTest

const GAME_STATE := preload("res://autoload/GameState.gd")
const CONTACT_INVITATION_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")


func _owner() -> Node:
	var owner: Node = autofree(GAME_STATE.new())
	owner.reset_game()
	return owner


func _watch_query_signals(owner: Node) -> Array[String]:
	var observed: Array[String] = []
	owner.friends_changed.connect(func() -> void: observed.append("friends_changed"))
	owner.day_changed.connect(func(_day: int) -> void: observed.append("day_changed"))
	owner.ending_route_selected.connect(
		func(_result: Dictionary) -> void: observed.append("ending_route_selected"))
	owner.save_relevant_state_changed.connect(
		func() -> void: observed.append("save_relevant_state_changed"))
	return observed


func _missed_query_state(owner: Node) -> Dictionary:
	return {
		"day": owner.day,
		"missed_invitations": owner.missed_invitations.duplicate(true),
	}


func _pair_query_state(owner: Node) -> Dictionary:
	return {
		"contacts": owner.contacts.duplicate(true),
		"inter_friend_route_state": owner.inter_friend_route_state.duplicate(true),
		"day": owner.day,
	}


func _read_missed(owner: Node, observed: Array[String], friend_id: String,
		target_day: int = -1) -> Dictionary:
	var before := _missed_query_state(owner)
	var signal_count := observed.size()
	var result: Dictionary = owner.get_missed_invitation_for_friend(friend_id, target_day)
	assert_eq(_missed_query_state(owner), before, "missed-invitation lookup is read-only")
	assert_eq(observed.size(), signal_count, "missed-invitation lookup emits no state signals")
	return result


func _assert_pair_queries(owner: Node, observed: Array[String], expected_count: int,
		expected_route: bool, context: String) -> void:
	var before := _pair_query_state(owner)
	var signal_count := observed.size()
	assert_eq(owner.get_counted_pair_window_count(), expected_count, context)
	assert_eq(owner.should_route_priscilla_lavinia_post_ending(), expected_route, context)
	assert_eq(_pair_query_state(owner), before, "%s: pair queries are read-only" % context)
	assert_eq(observed.size(), signal_count, "%s: pair queries emit no state signals" % context)


func _resolve_day(owner: Node, source_day: int, transaction_id: String,
		attendance: Dictionary = {}) -> void:
	var live_before: Dictionary = owner.contacts.duplicate(true)
	var prepared: Dictionary = CONTACT_INVITATION_STATE.prepare_resolve_day_end(
		owner.contacts, source_day, attendance, transaction_id)
	assert_true(prepared.get("ok", false), "%s: %s" % [transaction_id, prepared])
	assert_eq(owner.contacts, live_before, "%s: preparation does not mutate the live owner" % transaction_id)
	if prepared.get("ok", false):
		owner.contacts = prepared.value.candidate


func test_missed_invitation_query_uses_prior_day_filters_and_returns_a_detached_record() -> void:
	var owner := _owner()
	owner._lifecycle_set_playing_day(3)
	owner.missed_invitations = [
		{"friend_id": "priscilla", "source": "solo", "day": 1},
		{"friend_id": "lavinia", "source": "group", "day": 2},
		{"friend_id": "priscilla", "source": "group", "day": 4},
	]
	var observed := _watch_query_signals(owner)

	var default_due := _read_missed(owner, observed, "lavinia")
	assert_eq(default_due, {"friend_id": "lavinia", "source": "group", "day": 2},
		"the default target is the current day and reads only its prior-day miss")
	assert_eq(_read_missed(owner, observed, "priscilla", 2),
		{"friend_id": "priscilla", "source": "solo", "day": 1},
		"an explicit target day reads its own prior-day record")
	assert_eq(_read_missed(owner, observed, "priscilla", 3), {},
		"a record for another invite day does not leak through the target-day filter")
	assert_eq(_read_missed(owner, observed, "sylvia", 3), {},
		"a different friend has no matching miss")

	default_due["source"] = "changed-by-consumer"
	default_due["friend_id"] = "priscilla"
	assert_eq(_read_missed(owner, observed, "lavinia"),
		{"friend_id": "lavinia", "source": "group", "day": 2},
		"mutating a returned record cannot alter the retained miss")


func test_pair_route_query_counts_canonical_distinct_windows_and_retains_legacy_eligibility() -> void:
	# The Sept. 2 relationship behavior record section 2.3.1 retains the independently
	# confirmed Day 2/Day 6 pair-window count law. These queries derive two distinct
	# canonical receipt windows rather than trusting the superseded raw counter delta.
	var owner := _owner()
	var observed := _watch_query_signals(owner)
	_assert_pair_queries(owner, observed, 0, false, "no window receipts")

	_resolve_day(owner, 2, "pair-window-day2")
	_assert_pair_queries(owner, observed, 1, false, "one canonical group-day window")
	_resolve_day(owner, 2, "pair-window-day2-duplicate")
	_assert_pair_queries(owner, observed, 1, false, "a second receipt for Day 2 is the same window")
	_resolve_day(owner, 3, "ordinary-day3")
	_assert_pair_queries(owner, observed, 1, false, "a non-group day contributes no pair window")
	_resolve_day(owner, 6, "pair-window-day6")
	_assert_pair_queries(owner, observed, 2, true, "two distinct canonical group-day windows qualify")

	var attended_solo := _owner()
	var attended_observed := _watch_query_signals(attended_solo)
	_resolve_day(attended_solo, 2, "solo-prevents-day2", {
		"solo_attended_action_ids": ["solo:priscilla:day2"],
	})
	_resolve_day(attended_solo, 6, "pair-window-only-day6")
	_assert_pair_queries(attended_solo, attended_observed, 1, false,
		"attending a solo suppresses that day's pair window")

	var legacy := _owner()
	legacy.inter_friend_route_state["priscilla_lavinia"] = {"ending_eligible": true}
	var legacy_observed := _watch_query_signals(legacy)
	_assert_pair_queries(legacy, legacy_observed, 0, true,
		"an already-earned legacy eligibility flag remains compatible")
