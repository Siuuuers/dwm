extends "res://addons/gut/test.gd"
# GameState unit tests (prompt_docs/requirements/verification.md).

const PERMANENT_PROFILE_KEYS := ["settings", "audio_state", "seen_endings"]

func before_each() -> void:
	GameState.reset_game()


func test_reset_game_initial_values() -> void:
	assert_eq(GameState.day, 1)
	assert_eq(GameState.money, 0)
	assert_eq(GameState.coins, 0)
	assert_eq(GameState.penalty_points_today, 0)
	assert_eq(GameState.get_stat("pressure"), 3)
	assert_eq(GameState.get_stat("health"), 6)
	assert_eq(GameState.get_stat("motivation"), 7)


func test_run_serializer_excludes_permanent_profile_keys() -> void:
	var run_save: Dictionary = GameState.to_save_dict()
	for key: String in PERMANENT_PROFILE_KEYS:
		assert_false(run_save.has(key), "run serializer still owns %s" % key)


func test_reset_game_does_not_change_profile() -> void:
	var profile := get_tree().root.get_node_or_null("ProfileManager")
	assert_not_null(profile)
	if profile == null:
		return
	var before: Dictionary = profile.get_profile_snapshot()
	GameState.reset_game()
	assert_eq(profile.get_profile_snapshot(), before)


func test_change_stat_clamps() -> void:
	GameState.change_stat("pressure", 100)
	assert_eq(GameState.get_stat("pressure"), 12, "pressure clamps to 12")
	GameState.change_stat("pressure", -100)
	assert_eq(GameState.get_stat("pressure"), 0, "pressure clamps to 0")
	GameState.change_stat("health", -100)
	assert_eq(GameState.get_stat("health"), -2, "health clamps to -2")
	GameState.change_stat("motivation", 100)
	assert_eq(GameState.get_stat("motivation"), 7, "motivation clamps to 7")


func test_display_conversions() -> void:
	GameState.change_stat("pressure", 100)
	assert_eq(GameState.get_stat_display_value("pressure"), 9, "pressure display clamps 0..9")
	GameState.set_stat("health", -2)
	assert_eq(GameState.get_stat_display_value("health"), 0, "negative health displays 0")


func test_money_overdraft_rules() -> void:
	assert_true(GameState.change_money(-100), "spend from 0 clamps to -30")
	assert_eq(GameState.money, -30, "money floor -30")
	assert_false(GameState.can_spend_money(1), "cannot spend while negative")
	GameState.change_money(50)
	assert_eq(GameState.money, 20)


func test_coin_spending_blocks_when_insufficient() -> void:
	assert_false(GameState.can_spend_coins(1), "no coins to spend")
	GameState.change_coins(3)
	assert_true(GameState.try_spend_coins(2))
	assert_eq(GameState.coins, 1)
	assert_false(GameState.try_spend_coins(5), "cannot overspend coins")


func test_opening_and_tutorial_flags() -> void:
	assert_false(GameState.opening_seen)
	GameState.mark_opening_seen()
	assert_true(GameState.opening_seen)
	assert_false(GameState.tutorial_seen)
	GameState.mark_tutorial_seen()
	assert_true(GameState.tutorial_seen)


func test_advance_day_resets_and_ends() -> void:
	GameState.change_stat("motivation", -3)
	GameState._lifecycle_set_playing_day(3)
	assert_true(GameState.advance_day_or_end(), "advance mid-week returns true")
	assert_eq(GameState.day, 4)
	assert_eq(GameState.get_stat("motivation"), 7, "motivation resets on new day")
	assert_eq(GameState.minesweeper_rounds_left, 2, "rounds reset on new day")
	GameState._lifecycle_set_playing_day(7)
	assert_false(GameState.advance_day_or_end(), "advance after day 7 returns false")
	assert_eq(GameState.day, 7, "Day 7 is terminal; no Day 8 exists")
	assert_eq(GameState._run_lifecycle.get_state(), &"ENDING", "Day 7 advance enters ENDING")


# ---- Minesweeper round-floor ----
func test_round_floor_defaults() -> void:
	assert_eq(GameState.minesweeper_round_floor, 0)
	assert_eq(GameState.minesweeper_rounds_left, 2)
	assert_eq(GameState.get_minesweeper_display_rounds_left(), 2)
	assert_eq(GameState.get_minesweeper_display_rounds_max(), 2)
	assert_eq(GameState.get_minesweeper_total_playable_rounds(), 2)


func test_two_app_rounds_without_supportz() -> void:
	assert_true(GameState.can_start_minesweeper_app_round())
	GameState.start_minesweeper_app_round("beginner")
	assert_eq(GameState.get_minesweeper_display_rounds_left(), 1)
	GameState.finish_minesweeper_app_round({"context": "app", "difficulty": "beginner", "outcome": "cleared"})
	GameState.start_minesweeper_app_round("beginner")
	assert_eq(GameState.get_minesweeper_display_rounds_left(), 0)
	GameState.finish_minesweeper_app_round({"context": "app", "difficulty": "beginner", "outcome": "cleared"})
	assert_false(GameState.can_start_minesweeper_app_round(), "cannot start a third without Supportz")


func test_one_supportz_gives_three_rounds() -> void:
	GameState.change_minesweeper_round_floor(-1)
	assert_eq(GameState.minesweeper_round_floor, -1)
	assert_eq(GameState.get_minesweeper_total_playable_rounds(), 3)
	assert_eq(GameState.get_minesweeper_display_rounds_max(), 2, "denominator unchanged")


func test_three_supportz_caps_floor() -> void:
	for i in range(5):
		GameState.change_minesweeper_round_floor(-1)
	assert_eq(GameState.minesweeper_round_floor, -3, "floor never below -3")
	assert_eq(GameState.get_minesweeper_total_playable_rounds(), 5)


# ---- Conditions ----
func test_danger_penalty_and_reset() -> void:
	GameState.set_stat("pressure", 12)
	GameState.set_stat("health", -2)
	GameState.resolve_pressure_health_condition_end_of_day()
	assert_true(GameState.penalty_points_today <= 6, "daily penalty caps at 6")
	assert_true(GameState.get_stat("pressure") <= 9, "pressure reset to <=9 after penalty")
	assert_true(GameState.get_stat("health") >= 1, "health reset to >=1 after penalty")


func test_hospital_recovery() -> void:
	GameState.set_stat("health", -2)
	GameState.set_stat("pressure", 12)
	GameState.pending_hospital = true
	GameState.apply_hospital_recovery_and_advance_day()
	assert_eq(GameState.get_stat("health"), 6)
	assert_eq(GameState.get_stat("pressure"), 3)
	assert_false(GameState.pending_hospital)


# ---- Save whitelist ----
func test_save_dict_is_json_safe() -> void:
	var d := GameState.to_save_dict()
	assert_true(d is Dictionary)
	var json := JSON.stringify(d)
	assert_true(json.length() > 0, "save dict stringifies as JSON")
	var reparsed := JSON.new()
	assert_eq(reparsed.parse(json), OK, "save dict round-trips through JSON")


func test_apply_save_dict_preserves_state() -> void:
	GameState.change_money(45)
	GameState.change_minesweeper_round_floor(-2)
	var d := GameState.to_save_dict()
	GameState.reset_game()
	GameState.apply_save_dict(d)
	assert_eq(GameState.money, 45)
	assert_eq(GameState.minesweeper_round_floor, -2)


# ---- minesweeper_rng_seed persistence (CONTRACTS §2 / §6) ----
func test_save_whitelist_includes_rng_seed() -> void:
	GameState.reset_game()
	var d := GameState.to_save_dict()
	assert_true(d.has("minesweeper_rng_seed"), "rng_seed is in the save whitelist")


func test_rng_seed_round_trips_through_save() -> void:
	GameState.reset_game()
	GameState.minesweeper_rng_seed = 123456789
	var d := GameState.to_save_dict()
	GameState.reset_game()
	GameState.apply_save_dict(d)
	assert_eq(GameState.minesweeper_rng_seed, 123456789, "seed persists across save/load")


# ---- check_immediate_faint ----
func test_check_immediate_faint_requires_sequela_and_danger() -> void:
	GameState.set_stat("pressure", 12)
	GameState.set_stat("health", -2)
	GameState.condition_effects_today = []
	assert_false(GameState.check_immediate_faint(), "danger without sequela does not faint")
	assert_false(GameState.pending_hospital)
	GameState.condition_effects_today = ["sequela"]
	assert_true(GameState.check_immediate_faint(), "sequela + pressure>=10 faints")
	assert_true(GameState.pending_hospital)


func test_check_immediate_faint_sequela_and_low_health() -> void:
	GameState.set_stat("health", 0)
	GameState.condition_effects_today = ["sequela"]
	assert_true(GameState.check_immediate_faint(), "sequela + health<=0 faints")


func test_check_immediate_faint_sequela_no_danger() -> void:
	GameState.set_stat("pressure", 3)
	GameState.set_stat("health", 6)
	GameState.condition_effects_today = ["sequela"]
	assert_false(GameState.check_immediate_faint(), "sequela without danger does not faint")


# ---- should_route_sylvia_special_ending ----
func test_should_route_sylvia_special_ending_thresholds() -> void:
	GameState.hospital_skipped_sylvia_solo_count = 0
	assert_false(GameState.should_route_sylvia_special_ending())
	GameState.hospital_skipped_sylvia_solo_count = 1
	assert_false(GameState.should_route_sylvia_special_ending(), "1 skip is not enough")
	GameState.hospital_skipped_sylvia_solo_count = 2
	assert_true(GameState.should_route_sylvia_special_ending(), ">=2 skips enables Special Sylvia")


func test_hospital_recovery_counts_sylvia_solo() -> void:
	GameState.set_stat("health", -2)
	GameState.set_stat("pressure", 12)
	# Real hospital route: the Sylvia solo lives in schedule_entries (dates are skipped, never queued
	# into pending_date_entries). The counter MUST read the schedule before it is cleared.
	GameState.schedule_entries = [{"type": "solo", "friend_id": "sylvia"}]
	GameState.pending_hospital = true
	GameState.apply_hospital_recovery_and_advance_day()
	assert_eq(GameState.hospital_skipped_sylvia_solo_count, 1, "one skipped Sylvia solo counted")


# ---- Day-7 ending resolution (precedence + epilogue) ----
func test_resolve_day7_sylvia_special_highest_precedence() -> void:
	GameState._lifecycle_set_playing_day(7)
	GameState.hospital_skipped_sylvia_solo_count = 2
	GameState.missed_group_date_counts = {"priscilla_lavinia": 2}  # priscilla_lavinia also true
	GameState.schedule_entries = [{"day": 7, "type": "solo", "date_kind": "date", "friend_id": "priscilla"}]
	var r := GameState.resolve_day7_ending()
	assert_eq(r["ending_id"], "ending.sylvia.special", "Special Sylvia wins over priscilla_lavinia")
	assert_eq(r["epilogue_ending_id"], "ending.priscilla_lavinia", "priscilla_lavinia plays as epilogue")
	assert_eq(GameState.route_context["ending_id"], "ending.sylvia.special")
	assert_eq(GameState.route_context["epilogue_ending_id"], "ending.priscilla_lavinia")
	assert_eq(GameState.day, 7, "Day 7 is terminal; no Day 8 sentinel")
	assert_eq(GameState._run_lifecycle.get_state(), &"ENDING", "Day 7 resolution enters ENDING")


func test_resolve_day7_priscilla_lavinia_primary_no_epilogue() -> void:
	GameState._lifecycle_set_playing_day(7)
	GameState.missed_group_date_counts = {"priscilla_lavinia": 2}
	var r := GameState.resolve_day7_ending()
	assert_eq(r["ending_id"], "ending.priscilla_lavinia")
	assert_eq(r["epilogue_ending_id"], "", "no epilogue when priscilla_lavinia is the primary")


func test_resolve_day7_candidate_binary_tone_sweet() -> void:
	# story/05 §1: true-path retired as a destination; tone is binary. Low dark points now Sweet.
	GameState._lifecycle_set_playing_day(7)
	GameState.contact_message_unlocks = {"day:7:friend:priscilla": true}
	GameState.schedule_entries = [{"day": 7, "type": "solo", "date_kind": "date", "friend_id": "priscilla"}]
	GameState.dating_route_state = {"priscilla": {"true_path_count": 4, "dark_points": 0}}
	GameState.affection = {"priscilla": 10}
	var r := GameState.resolve_day7_ending()
	assert_eq(r["ending_id"], "ending.priscilla.sweet", "no dark points resolves Sweet")
	assert_eq(r["epilogue_ending_id"], "", "no epilogue without priscilla_lavinia unlock")


func test_resolve_day7_not_day7_returns_epilogue_key() -> void:
	GameState._lifecycle_set_playing_day(3)
	var r := GameState.resolve_day7_ending()
	assert_false(r["ok"])
	assert_eq(r["epilogue_ending_id"], "", "non-day7 returns epilogue key for schema stability")


# ---- dwm-p2r.6 facade: contacts state-home + read delegation ----

const _CONTACTS_MODULE := "res://scripts/domain/contact/ContactInvitationState.gd"

func test_contacts_bag_resets_to_stateless_defaults() -> void:
	GameState.reset_game()
	assert_eq(int(GameState.contacts["next_sequence"]), 1)
	assert_eq((GameState.contacts["messages"]["priscilla"] as Array).size(), 0)
	assert_eq(str(GameState.contacts["group_action"]["state"]), "INACTIVE")

func test_get_contact_view_delegates_to_module() -> void:
	GameState.reset_game()
	var mod: Script = load(_CONTACTS_MODULE)
	GameState.contacts = mod.prepare_offer_solo(GameState.contacts, "priscilla", 1, "m1", "tx1")["value"]["candidate"]
	GameState.contacts = mod.prepare_open_contact(GameState.contacts, "priscilla", 1, "tx2")["value"]["candidate"]
	var view: Dictionary = GameState.get_contact_view("priscilla", 1)
	assert_eq((view["messages"] as Array).size(), 1, "the opened solo offer is visible in the contact view")

func test_contacts_survive_capture_and_rollback() -> void:
	GameState.reset_game()
	var mod: Script = load(_CONTACTS_MODULE)
	GameState.contacts = mod.prepare_offer_solo(GameState.contacts, "priscilla", 1, "m1", "tx1")["value"]["candidate"]
	var backup: Dictionary = GameState.capture_restore_state()["value"]["backup"]
	GameState.contacts = mod.make_defaults()
	GameState.rollback_restore_silent(backup)
	assert_eq((GameState.contacts["messages"]["priscilla"] as Array).size(), 1, "rollback restores the contacts section")

func test_contacts_restored_from_run_snapshot() -> void:
	GameState.reset_game()
	var mod: Script = load(_CONTACTS_MODULE)
	var populated: Dictionary = mod.prepare_offer_solo(mod.make_defaults(), "lavinia", 1, "m1", "tx1")["value"]["candidate"]
	var snapshot: Dictionary = {"lifecycle": GameState._run_lifecycle.to_dict(), "gameplay": {}, "contacts": populated}
	GameState._apply_run_snapshot_silent(snapshot)
	assert_eq((GameState.contacts["messages"]["lavinia"] as Array).size(), 1, "snapshot contacts section restores into GameState")

func test_new_run_snapshot_input_carries_contacts_defaults() -> void:
	GameState.reset_game()
	var prepared: Dictionary = GameState.prepare_new_run_snapshot_input("run-facade-f2")
	assert_true(prepared.get("ok", false), "valid run id prepares")
	var section: Dictionary = prepared["value"]["snapshot_input"]["contacts"]
	assert_eq(int(section["next_sequence"]), 1, "new-run contacts is a valid stateless defaults bag, not {}")
	assert_eq(str(section["group_action"]["state"]), "INACTIVE")

func test_reply_invitation_command_applies_and_is_idempotent() -> void:
	GameState.reset_game()
	var mod: Script = load(_CONTACTS_MODULE)
	# Seed an opened solo offer directly via the module (the open_contact command lands later).
	GameState.contacts = mod.prepare_offer_solo(GameState.contacts, "priscilla", 1, "m1", "seed-offer")["value"]["candidate"]
	GameState.contacts = mod.prepare_open_contact(GameState.contacts, "priscilla", 1, "seed-open")["value"]["candidate"]
	var r1: Dictionary = GameState.reply_invitation("priscilla", "cmd-reply-1")
	assert_true(r1.get("ok", false), "reply command succeeds")
	assert_false(r1["value"]["replayed"], "first call is not a replay")
	assert_true(mod.is_date_addable(GameState.contacts, "solo:priscilla:day1"), "reply makes the date addable")
	var r2: Dictionary = GameState.reply_invitation("priscilla", "cmd-reply-1")
	assert_true(r2.get("ok", false))
	assert_true(r2["value"]["replayed"], "same command_id replays idempotently, no double effect")

func test_reply_invitation_rejects_empty_command_id() -> void:
	GameState.reset_game()
	assert_false(GameState.reply_invitation("priscilla", "").get("ok", true), "command_id is required")

func test_resolve_invitations_for_day_command_resolves_and_is_idempotent() -> void:
	GameState.reset_game()
	var mod: Script = load(_CONTACTS_MODULE)
	GameState.contacts = mod.prepare_offer_solo(GameState.contacts, "priscilla", 1, "m1", "seed-offer")["value"]["candidate"]
	var r1: Dictionary = GameState.resolve_invitations_for_day({"solo_attended_action_ids": []}, "cmd-resolve-1")
	assert_true(r1.get("ok", false), "resolve command succeeds")
	assert_eq(GameState.contacts["solo_actions"]["solo:priscilla:day1"]["state"], "RESOLVED_UNANSWERED")
	assert_eq(r1["value"]["receipt"]["kind"], "resolve_day_end")
	var r2: Dictionary = GameState.resolve_invitations_for_day({"solo_attended_action_ids": []}, "cmd-resolve-1")
	assert_true(r2["value"]["replayed"], "same command_id replays idempotently")

func test_resolve_invitations_for_day_rejects_empty_command_id() -> void:
	GameState.reset_game()
	assert_false(GameState.resolve_invitations_for_day({"solo_attended_action_ids": []}, "").get("ok", true))

# ---- dwm-p2r.6: characterization of the LEGACY contact flow (pre-migration safety net) ----
# These document the CURRENT behavior of the old dict-based flow so the module
# migration can be verified to preserve it. Not aspirational — they capture what IS.

func test_legacy_solo_open_choose_unlocks_date_on_invitation_day() -> void:
	GameState.reset_game()
	assert_eq(GameState.day, 1)
	assert_true(GameState.is_invitation_day("priscilla", 1))
	GameState.open_contact("priscilla", "open-priscilla")
	var r: Dictionary = GameState.choose_contact_option("priscilla", "accept")
	assert_true(r["ok"])
	assert_true(GameState.is_date_unlocked("priscilla", 1), "reply on invitation day unlocks the solo date")

func test_legacy_choose_on_non_invitation_day_does_not_unlock() -> void:
	GameState.reset_game()
	assert_false(GameState.is_invitation_day("lavinia", 1))
	GameState.open_contact("lavinia", "open-lavinia")
	GameState.choose_contact_option("lavinia", "accept")
	assert_false(GameState.is_date_unlocked("lavinia", 1), "no phantom unlock off the invitation day")

func test_legacy_minesweeper_round_unlocks_contact_message() -> void:
	GameState.reset_game()
	GameState.minesweeper_app_rounds_finished_today = 1
	var res: Dictionary = GameState.unlock_contact_message_after_minesweeper_finished({})
	assert_eq(res.get("friend_id", ""), "priscilla", "round 1 on day 1 targets priscilla (order[0])")
	assert_true(GameState.is_contact_message_unlocked("priscilla", 1))

func test_group_addable_only_after_reply_canon() -> void:
	# CANON (dwm-p2r.6, replaces the legacy read-makes-addable behavior): the group activates on
	# round 3, opening a pair member assigns the module inviter, and the date becomes schedulable
	# ONLY after a reply. The reply-order gate (g4) and open/inviter (g3) are covered separately.
	GameState.reset_game()
	GameState._lifecycle_set_playing_day(2)
	for _i in 3:
		GameState.finish_minesweeper_app_round({"context": "app"})
	GameState.open_contact("priscilla", "open-priscilla")
	assert_eq(str(GameState.contacts["group_action"]["inviter_id"]), "priscilla", "first pair member opened is the module inviter")
	assert_false(GameState.is_group_date_unlocked(2), "canon: NOT addable before a reply")
	GameState.choose_contact_option("priscilla", "accept")
	assert_true(GameState.is_group_date_unlocked(2), "canon: addable once the group is replied (ACCEPTED)")

func test_migration_bridge_backfills_module_on_legacy_solo_flow() -> void:
	# Migration bridge: the legacy open/choose now also drive the module contacts bag to ACCEPTED,
	# while the legacy observables stay identical (verified by the characterization tests above).
	GameState.reset_game()
	GameState.open_contact("priscilla", "open-priscilla")
	GameState.choose_contact_option("priscilla", "accept")
	var mod: Script = load(_CONTACTS_MODULE)
	assert_true(mod.is_date_addable(GameState.contacts, "solo:priscilla:day1"), "legacy solo flow backfills the module bag to ACCEPTED")

func test_g1_minesweeper_round_generates_module_solo_offer() -> void:
	# G1 (dwm-p2r.6): finishing a Minesweeper round mirrors the daily-message unlock into a
	# module solo offer, so pair solos exist in the bag by round 3 (for group activation).
	GameState.reset_game()
	GameState.finish_minesweeper_app_round({"context": "app"})
	var mod: Script = load(_CONTACTS_MODULE)
	assert_eq(mod.get_unread_count(GameState.contacts, "priscilla", 1), 1, "round 1 on day 1 generates priscilla's unread module offer")

func test_g2_round3_activates_module_group_on_group_day() -> void:
	# G2 (dwm-p2r.6): the 3rd Minesweeper round of a group day activates the module group
	# (canon: activation is round-triggered, not contact-open triggered).
	GameState.reset_game()
	GameState._lifecycle_set_playing_day(2)
	GameState.finish_minesweeper_app_round({"context": "app"})  # round 1 -> priscilla offer
	GameState.finish_minesweeper_app_round({"context": "app"})  # round 2 -> lavinia offer
	assert_eq(str(GameState.contacts["group_action"]["state"]), "INACTIVE", "not active before round 3")
	GameState.finish_minesweeper_app_round({"context": "app"})  # round 3 -> activate
	assert_eq(str(GameState.contacts["group_action"]["state"]), "AVAILABLE_UNOPENED", "3rd round activates the module group")
	assert_eq(str(GameState.contacts["group_action"]["action_id"]), "group:priscilla_lavinia:day2")

func test_g3_contact_open_assigns_group_inviter_via_module() -> void:
	# G3 (dwm-p2r.6): after round-3 activation, opening a pair member routes through the module's
	# group open (first open assigns inviter, second open adds the participant). No re-activation.
	GameState.reset_game()
	GameState._lifecycle_set_playing_day(2)
	for _i in 3:
		GameState.finish_minesweeper_app_round({"context": "app"})
	assert_eq(str(GameState.contacts["group_action"]["state"]), "AVAILABLE_UNOPENED")
	GameState.open_contact("priscilla", "open-priscilla")
	assert_eq(str(GameState.contacts["group_action"]["inviter_id"]), "priscilla", "first pair member opened is the inviter")
	assert_eq(str(GameState.contacts["group_action"]["state"]), "REPLY_REQUIRED")
	GameState.open_contact("lavinia", "open-lavinia")
	assert_eq((GameState.contacts["group_action"]["opened_ids"] as Array), ["priscilla", "lavinia"], "second open adds the participant")

func test_g4_group_reply_routes_to_module_with_gate() -> void:
	# G4 (dwm-p2r.6): choosing on a group day routes to the module group reply; the reply-order
	# gate blocks the non-inviter until the inviter has replied.
	GameState.reset_game()
	GameState._lifecycle_set_playing_day(2)
	for _i in 3:
		GameState.finish_minesweeper_app_round({"context": "app"})
	GameState.open_contact("priscilla", "open-priscilla")
	# CANON (req.invitation.group_resolution): inviter_id is presentation-only, so replying to
	# EITHER participant makes the group schedulable — the legacy inviter-first gate is retired.
	var non_inviter: Dictionary = GameState.choose_contact_option("lavinia", "accept")
	assert_true(non_inviter["ok"], "canon: the non-inviter may reply first")
	assert_eq(str(GameState.contacts["group_action"]["state"]), "ACCEPTED", "either participant's reply accepts the group")
	assert_true(GameState.contacts["group_action"]["replied_ids"].has("lavinia"))
	assert_true(GameState.is_group_date_unlocked(2), "schedulable once either participant replied")

func test_open_contact_command_is_idempotent() -> void:
	# open_contact now realizes the reserved command signature: command_id is the module
	# transaction id, so re-opening the same contact under one command replays with no effect.
	GameState.reset_game()
	var first: Dictionary = GameState.open_contact("priscilla", "cmd-open-1")
	assert_true(first.get("ok", false), "open command succeeds")
	assert_false(first["value"]["replayed"], "first call is not a replay")
	var replay: Dictionary = GameState.open_contact("priscilla", "cmd-open-1")
	assert_true(replay["value"]["replayed"], "same command_id replays idempotently")

func test_open_contact_rejects_empty_command_id() -> void:
	GameState.reset_game()
	assert_false(GameState.open_contact("priscilla", "").get("ok", true), "command_id is required")

func test_request_next_ending_command_plays_primary_first() -> void:
	# Realizes the reserved facade read: reads the live EndingPlan, asks the pure stage machine,
	# and derives the playback ids from run id + role. story/05 §1: low dark points -> Sweet.
	GameState._lifecycle_set_playing_day(7)
	GameState.contact_message_unlocks = {"day:7:friend:priscilla": true}
	GameState.schedule_entries = [{"day": 7, "type": "solo", "date_kind": "date", "friend_id": "priscilla"}]
	GameState.dating_route_state = {"priscilla": {"true_path_count": 4, "dark_points": 0}}
	GameState.affection = {"priscilla": 10}
	GameState.resolve_day7_ending()
	assert_eq(GameState._run_lifecycle.get_state(), &"ENDING", "resolution enters ENDING")
	var cmd: Dictionary = GameState.request_next_ending_command()
	assert_true(cmd.get("ok", false), "a command is available in ENDING")
	assert_eq(cmd["value"]["kind"], &"play_ending")
	assert_eq(cmd["value"]["ending_id"], "ending.priscilla.sweet")
	var ctx: Dictionary = cmd["value"]["playback_context"]
	assert_eq(str(ctx["role"]), "primary")
	assert_eq(str(ctx["expected_stage"]), "PRIMARY_PENDING")
	assert_eq(str(ctx["playback_id"]), "run-local:primary", "playback id is run_id:role")
	assert_eq(str(ctx["transaction_id"]), "run-local:primary:complete", "transaction id is run_id:role:complete")

func test_request_next_ending_command_rejects_outside_ending() -> void:
	GameState.reset_game()
	assert_false(GameState.request_next_ending_command().get("ok", true), "no ending command while PLAYING")

func _enter_priscilla_sweet_ending() -> void:
	GameState._lifecycle_set_playing_day(7)
	GameState.contact_message_unlocks = {"day:7:friend:priscilla": true}
	GameState.schedule_entries = [{"day": 7, "type": "solo", "date_kind": "date", "friend_id": "priscilla"}]
	GameState.dating_route_state = {"priscilla": {"true_path_count": 4, "dark_points": 0}}
	GameState.affection = {"priscilla": 10}
	GameState.resolve_day7_ending()

func test_complete_ending_playback_stage_advances_the_primary() -> void:
	# The facade translates the run-scoped transaction id + flat receipt to the lifecycle's
	# ending:<stage> / {value:...} contract and advances PRIMARY_PENDING -> PRIMARY_COMPLETED.
	_enter_priscilla_sweet_ending()
	var ctx: Dictionary = GameState.request_next_ending_command()["value"]["playback_context"]
	var result: Dictionary = GameState.complete_ending_playback_stage(
		str(ctx["transaction_id"]), ctx["expected_stage"],
		{"timeline_completion_receipt_id": "timeline:priscilla.sweet:complete", "outcome": "completed"})
	assert_true(result.get("ok", false), "a matching primary completion advances the stage")
	assert_eq(str(GameState._run_lifecycle.to_dict()["ending_plan"]["playback_stage"]), "PRIMARY_PLAYED")

func test_complete_ending_playback_stage_rejects_a_transaction_mismatch() -> void:
	_enter_priscilla_sweet_ending()
	var result: Dictionary = GameState.complete_ending_playback_stage(
		"run-local:primary:WRONG", &"PRIMARY_PENDING", {"outcome": "completed"})
	assert_false(result.get("ok", true), "a transaction id that is not run_id:role:complete is rejected")

func test_complete_ending_playback_stage_rejects_outside_ending() -> void:
	GameState.reset_game()
	assert_false(GameState.complete_ending_playback_stage("run-local:primary:complete", &"PRIMARY_PENDING", {}).get("ok", true))

func _advance_ending(expected_stage: StringName, receipt: Dictionary = {}) -> Dictionary:
	# Drives one ending step: reads the next command's transaction id (for play_ending) then completes it.
	var cmd: Dictionary = GameState.request_next_ending_command()
	var txn := ""
	if cmd.get("ok", false) and cmd["value"].has("playback_context"):
		txn = str(cmd["value"]["playback_context"]["transaction_id"])
	return GameState.complete_ending_playback_stage(txn, expected_stage, receipt)

func test_record_gallery_unlocks_the_primary_and_reaches_gallery_recorded() -> void:
	# Layer 2: a no-epilogue run plays the primary, then the record_gallery steps unlock the primary
	# in the profile gallery (idempotently) and walk the frozen sequence to GALLERY_RECORDED.
	var profile := get_tree().root.get_node_or_null("ProfileManager")
	if profile == null:
		return
	# The autoload ProfileManager is not initialized in the test harness; give it in-memory storage.
	var ops: RefCounted = load("res://tests/support/FakeFileOps.gd").new()
	var storage: RefCounted = load("res://scripts/infrastructure/storage/JsonFileStorage.gd").new("gallery-test/root", ops)
	profile.call(&"initialize", storage)  # ok, or already_initialized on a later run
	profile.reset_gallery()
	_enter_priscilla_sweet_ending()
	assert_true(_advance_ending(&"PRIMARY_PENDING", {"outcome": "completed"}).get("ok", false), "primary plays")
	assert_true(_advance_ending(&"PRIMARY_PLAYED").get("ok", false), "record gallery at PRIMARY_PLAYED")
	assert_true(_advance_ending(&"EPILOGUE_PLAYED").get("ok", false), "record gallery at EPILOGUE_PLAYED")
	assert_eq(str(GameState._run_lifecycle.to_dict()["ending_plan"]["playback_stage"]), "GALLERY_RECORDED")
	assert_true(profile.has_gallery_unlock("ending.priscilla.sweet"), "the primary ending is unlocked in the gallery")
	assert_false(profile.has_gallery_unlock("ending.priscilla_lavinia"), "no epilogue was recorded")

func test_full_no_epilogue_ending_flow_completes_the_run_to_menu() -> void:
	# End-to-end (layers 1-3): play primary -> record gallery (through the frozen sequence) ->
	# complete_run. Lifecycle reaches COMPLETED, the route is menu, and day stays 7 (no Day 8).
	var profile := get_tree().root.get_node_or_null("ProfileManager")
	if profile == null:
		return
	var ops: RefCounted = load("res://tests/support/FakeFileOps.gd").new()
	profile.call(&"initialize", load("res://scripts/infrastructure/storage/JsonFileStorage.gd").new("gallery-test/root2", ops))
	profile.reset_gallery()
	_enter_priscilla_sweet_ending()
	assert_true(_advance_ending(&"PRIMARY_PENDING", {"outcome": "completed"}).get("ok", false))
	assert_true(_advance_ending(&"PRIMARY_PLAYED").get("ok", false))
	assert_true(_advance_ending(&"EPILOGUE_PLAYED").get("ok", false))
	var finished: Dictionary = _advance_ending(&"GALLERY_RECORDED")
	assert_true(finished.get("ok", false), "complete_run succeeds at GALLERY_RECORDED")
	assert_eq(str(finished["value"]["route"]), "menu", "the run routes to the menu")
	assert_eq(GameState._run_lifecycle.get_state(), &"COMPLETED", "the run is COMPLETED")
	assert_eq(GameState.day, 7, "day stays 7; there is no Day 8")
