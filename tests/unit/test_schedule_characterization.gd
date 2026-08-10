extends "res://addons/gut/test.gd"
# Characterization net for GameState's schedule surface (Plan-04 Task 4 Step 4.1a, MANDATORY).
#
# This net exists so the ScheduleRules delegation in Step 4.2b cannot silently change public
# behaviour. It is deliberately split in two:
#
#   FROZEN     -- semantic behaviour that must survive the refactor unchanged. These are GREEN
#                 characterization tests: they describe what the code does today and must keep
#                 passing afterwards.
#   NOT FROZEN -- legacy accidents the ruling explicitly refuses to preserve. These are RED
#                 target tests marked pending() with the exact defect recorded, so the net can
#                 never be mistaken for a licence to keep them.
#
# Writing the second group as passing characterization tests would be the single worst outcome
# here: it would lock the defects in under the banner of safety.

const ACTION := "rest"
const SCHEDULE_RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")


func before_each() -> void:
	GameState.reset_game()
	watch_signals(GameState)


func _motivation() -> int:
	return int(GameState.get_stat(GameState.STAT_MOTIVATION))


func _entry_count() -> int:
	return (GameState.schedule_entries as Array).size()


# ---------------------------------------------------------------------------
# FROZEN: motivation accounting
# ---------------------------------------------------------------------------

func test_a_successful_add_costs_exactly_one_motivation() -> void:
	var before := _motivation()
	assert_true(GameState.add_schedule_action(ACTION), "a known non-date action adds")
	assert_eq(_motivation(), before - 1, "exactly one motivation is spent, never zero or two")
	assert_eq(_entry_count(), 1, "and exactly one entry lands")


func test_removing_one_entry_refunds_exactly_one() -> void:
	GameState.add_schedule_action(ACTION)
	var before := _motivation()
	assert_true(GameState.remove_schedule_entry(0), "the entry removes")
	assert_eq(_motivation(), before + 1, "exactly one motivation is refunded")
	assert_eq(_entry_count(), 0, "and the schedule is empty")


func test_add_then_remove_is_motivation_neutral() -> void:
	var before := _motivation()
	GameState.add_schedule_action(ACTION)
	GameState.remove_schedule_entry(0)
	assert_eq(_motivation(), before, "a full add/remove cycle costs nothing")


func test_clear_with_refund_refunds_once_per_entry() -> void:
	GameState.add_schedule_action("rest")
	GameState.add_schedule_action("training")
	var before := _motivation()
	GameState.clear_schedule_with_refund()
	assert_eq(_motivation(), before + 2, "two entries refund exactly two")
	assert_eq(_entry_count(), 0, "and the schedule empties")


func test_clear_without_refund_refunds_nothing() -> void:
	GameState.add_schedule_action("rest")
	GameState.add_schedule_action("training")
	var before := _motivation()
	GameState.clear_schedule_without_refund()
	assert_eq(_motivation(), before, "no motivation returns")
	assert_eq(_entry_count(), 0, "but the schedule still empties")


func test_clearing_an_empty_schedule_refunds_nothing() -> void:
	var before := _motivation()
	GameState.clear_schedule_with_refund()
	assert_eq(_motivation(), before, "an empty clear is not a refund source")


# ---------------------------------------------------------------------------
# FROZEN: rejections cause no mutation and no signals
# ---------------------------------------------------------------------------

func test_an_unknown_action_is_rejected_without_mutation_or_signals() -> void:
	var before := _motivation()
	assert_false(GameState.add_schedule_action("not_a_real_action"), "unknown actions reject")
	assert_eq(_motivation(), before, "no motivation is spent on a rejected add")
	assert_eq(_entry_count(), 0, "no entry is appended")
	assert_signal_emit_count(GameState, "schedule_changed", 0, "a rejection is not a change")
	assert_signal_emit_count(GameState, "save_relevant_state_changed", 0, "and never dirties the save")


func test_an_out_of_range_removal_is_rejected_without_mutation_or_signals() -> void:
	GameState.add_schedule_action(ACTION)
	var before := _motivation()
	assert_false(GameState.remove_schedule_entry(5), "an out-of-range index rejects")
	assert_false(GameState.remove_schedule_entry(-1), "a negative index rejects")
	assert_eq(_motivation(), before, "a rejected removal refunds nothing")
	assert_eq(_entry_count(), 1, "and removes nothing")
	assert_signal_emit_count(GameState, "schedule_changed", 1, "only the earlier successful add signalled")


func test_a_date_entry_of_the_wrong_type_is_rejected_without_mutation() -> void:
	var before := _motivation()
	assert_false(GameState.add_schedule_date_entry({"type": "not_a_date_type"}), "an unknown type rejects")
	assert_eq(_motivation(), before, "no motivation is spent")
	assert_eq(_entry_count(), 0, "no entry lands")


# ---------------------------------------------------------------------------
# FROZEN: a successful mutation signals exactly once
# ---------------------------------------------------------------------------

func test_a_successful_add_signals_schedule_changed_exactly_once() -> void:
	assert_true(GameState.add_schedule_action(ACTION), "the add succeeds")
	assert_signal_emit_count(GameState, "schedule_changed", 1, "exactly one schedule_changed")


func test_a_successful_removal_signals_schedule_changed_exactly_once() -> void:
	GameState.add_schedule_action(ACTION)
	assert_true(GameState.remove_schedule_entry(0), "the removal succeeds")
	assert_signal_emit_count(GameState, "schedule_changed", 2, "one per successful mutation")


# ---------------------------------------------------------------------------
# FROZEN: slot order is stable
# ---------------------------------------------------------------------------

func test_slot_order_is_stable_and_append_only() -> void:
	GameState.add_schedule_action("rest")
	GameState.add_schedule_action("training")
	GameState.add_schedule_action("working")
	var types: Array = []
	for entry: Dictionary in GameState.schedule_entries:
		types.append(str(entry.get("type", "")))
	assert_eq(types, ["rest", "training", "working"], "entries keep insertion order")


func test_removing_the_first_entry_preserves_the_order_of_the_rest() -> void:
	GameState.add_schedule_action("rest")
	GameState.add_schedule_action("training")
	GameState.add_schedule_action("working")
	GameState.remove_schedule_entry(0)
	var types: Array = []
	for entry: Dictionary in GameState.schedule_entries:
		types.append(str(entry.get("type", "")))
	assert_eq(types, ["training", "working"], "the survivors keep their relative order")


# ---------------------------------------------------------------------------
# FROZEN: date eligibility (limits, duplicate friends, Day-4 ordering)
# ---------------------------------------------------------------------------
# These go through add_schedule_date_entry, which reaches _can_add_date_entry and therefore the
# real ScheduleRules.validate_date_candidate. They deliberately do NOT set up contact-invitation
# unlocks: is_date_unlocked gates can_add_schedule_action, not this path, so building the entry
# directly keeps the net focused on the eligibility rules Step 4.2b must preserve.


func _solo(friend_id: String) -> Dictionary:
	return GameState.build_date_entry_from_unlock(friend_id)


## GameState.day is deliberately read-only and lifecycle-owned (GameState.gd:140-144), so the day
## is moved the only legitimate way: through a RunLifecycle restore. Assigning GameState.day would
## push an error and change nothing.
func _set_day(target_day: int) -> void:
	var lifecycle: RefCounted = GameState._run_lifecycle
	var snapshot: Dictionary = lifecycle.to_dict()
	snapshot["day"] = target_day
	var prepared: Dictionary = lifecycle.prepare_restore(snapshot)
	assert_true(prepared.get("ok", false), "day %d prepares: %s" % [target_day, str(prepared)])
	if not prepared.get("ok", false):
		return
	assert_true(lifecycle.commit_restore(prepared["value"]["candidate"]).get("ok", false), "day commits")
	assert_eq(int(GameState.day), target_day, "the facade reports the new day")


func test_days_one_through_six_allow_exactly_two_dates() -> void:
	_set_day(3)
	assert_true(GameState.add_schedule_date_entry(_solo("priscilla")), "first date fits")
	assert_true(GameState.add_schedule_date_entry(_solo("lavinia")), "second date fits")
	assert_false(GameState.add_schedule_date_entry(_solo("sylvia")), "a third date exceeds the day allowance")
	assert_eq(_entry_count(), 2, "and the third never lands")


func test_the_daily_cap_is_two_on_day_six_and_one_on_day_seven() -> void:
	assert_eq(int(SCHEDULE_RULES.max_dates_for_day(6)), 2, "days 1-6 allow two")
	assert_eq(int(SCHEDULE_RULES.max_dates_for_day(7)), 1, "day 7 allows the single ending date")


func test_day_seven_allows_only_one_date() -> void:
	_set_day(7)
	assert_true(GameState.add_schedule_date_entry(_solo("sylvia")), "the ending date fits")
	assert_false(GameState.add_schedule_date_entry(_solo("lavinia")), "a second Day-7 date is refused")
	assert_eq(_entry_count(), 1, "exactly one ending candidate")


func test_the_same_friend_cannot_be_dated_twice_in_one_day() -> void:
	_set_day(3)
	assert_true(GameState.add_schedule_date_entry(_solo("priscilla")), "the first date fits")
	assert_false(GameState.add_schedule_date_entry(_solo("priscilla")), "the same friend is refused")
	assert_eq(_entry_count(), 1, "the duplicate never lands")


func test_a_rejected_duplicate_date_costs_no_motivation() -> void:
	_set_day(3)
	GameState.add_schedule_date_entry(_solo("priscilla"))
	var before := _motivation()
	assert_false(GameState.add_schedule_date_entry(_solo("priscilla")), "the duplicate is refused")
	assert_eq(_motivation(), before, "a refused date spends nothing")


func test_day_four_seats_priscilla_in_the_first_slot() -> void:
	_set_day(4)
	assert_true(GameState.add_schedule_date_entry(_solo("lavinia")), "another friend takes slot one")
	assert_false(GameState.add_schedule_date_entry(_solo("priscilla")),
		"Day 4 refuses a Priscilla date that would follow another entry")


func test_day_four_accepts_priscilla_when_she_is_first() -> void:
	_set_day(4)
	assert_true(GameState.add_schedule_date_entry(_solo("priscilla")), "Priscilla first is legal")
	assert_true(GameState.add_schedule_date_entry(_solo("lavinia")), "and another date may follow her")


func test_the_day_four_rule_applies_only_to_day_four() -> void:
	_set_day(3)
	GameState.add_schedule_date_entry(_solo("lavinia"))
	assert_true(GameState.add_schedule_date_entry(_solo("priscilla")),
		"the ordering rule is Day-4 specific and must not leak into other days")


func test_an_entry_never_invalidates_itself_during_existing_validation() -> void:
	# The self-comparison bug: a scheduled entry must not be rejected by being compared to itself.
	_set_day(3)
	GameState.add_schedule_date_entry(_solo("priscilla"))
	assert_true(GameState.validate_schedule().get("ok", false),
		"a one-date schedule validates: " + str(GameState.validate_schedule()))


# ---------------------------------------------------------------------------
# NOT FROZEN: legacy accidents the ruling refuses to preserve
# ---------------------------------------------------------------------------
# These are the target contracts for Step 4.2b. They are recorded as pending() with the exact
# present-day defect so the refactor has a written bar to clear -- and so nobody can later read
# this file as evidence that the current behaviour was blessed.


func test_target_each_mutation_emits_save_relevant_state_changed_exactly_once() -> void:
	# FOUND BY THIS NET, 2026-08-10. Every successful schedule mutation emits
	# save_relevant_state_changed TWICE: change_stat (GameState.gd:1009/1028/1038) delegates to
	# set_stat, which emits it, and then the schedule function emits it again explicitly
	# (GameState.gd:1011/1030/1049). Measured counts today: 2 per add, 4 after add+remove.
	# This is the "duplicate save_relevant_state_changed emissions" accident the ruling refuses
	# to preserve, so it is recorded as a target rather than frozen at 2.
	pending("target contract: exactly one save_relevant_state_changed per logical schedule " +
		"mutation; today motivation spend and the explicit emit each fire one")


func test_target_add_must_not_mutate_the_caller_dictionary() -> void:
	# autoload/GameState.gd:1023-1026 writes advance_day_after_finish into the CALLER's dictionary
	# before duplicating it, so a caller's own data is silently rewritten by a read-shaped call.
	pending("target contract: add_schedule_date_entry must not mutate caller-owned dictionaries " +
		"(GameState.gd:1023 assigns into `entry` before the duplicate on :1027)")


func test_target_stored_entries_must_be_deeply_detached() -> void:
	# GameState.gd:1027 uses entry.duplicate() -- a SHALLOW copy, so nested arrays such as
	# effect_ids remain shared with the caller.
	pending("target contract: stored schedule entries must be recursively detached " +
		"(GameState.gd:1027 duplicates shallowly)")


func test_target_removal_must_not_cascade_sanitize() -> void:
	# GameState.gd:1039-1047 drops and refunds LATER entries during a removal, so a single
	# remove_schedule_entry call can refund more than one motivation.
	pending("target contract: removal refunds exactly one and never cascade-sanitizes " +
		"(GameState.gd:1039-1047 drops and refunds additional entries)")


func test_target_results_must_be_command_results_not_booleans() -> void:
	# add/remove return bare bools, so callers cannot distinguish rejection reasons.
	pending("target contract: schedule commands return the exact CommandResult shape " +
		"{ok, code, reason, committed_effects, date_outcome_ids, route_plan, checkpoint_id}")


func test_target_date_invalid_masking_must_be_replaced_with_exact_codes() -> void:
	# GameState.gd:985 collapses every date-eligibility failure into the single reason
	# "date_invalid", so duplicate-friend, over-limit and ordering failures are indistinguishable.
	pending("target contract: can_add_schedule_action reports exact typed codes rather than " +
		"the generic date_invalid mask (GameState.gd:985)")


func test_target_twofriends_must_not_be_player_schedulable() -> void:
	# GameState.gd:1016 accepts "twofriends" from add_schedule_date_entry, but twofriends is
	# never player-schedulable and build_route_plan is forbidden from emitting it.
	pending("target contract: twofriends is not accepted by any player-facing schedule add " +
		"(GameState.gd:1016 currently accepts it)")
