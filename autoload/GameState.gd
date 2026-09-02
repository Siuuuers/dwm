extends Node

# GameState autoload — owns all mutable runtime state for the prototype.
# Authority: prompt_docs/INDEX.md (runtime ownership, dating, persistence, and narrative
# requirement packets). No human-facing prose; machine-precise, contradiction-free.
#
# Static data tables (_INVITATION_DAYS, _CONTACT_MESSAGE_ORDER) are embedded here so this autoload
# loads even before scripts/data/DataCatalog.gd exists. Their values are mirrored by DataCatalog
# and must remain equal to its canonical tables.
#
# Schedule action facts are NOT among them. Route, effects, motivation cost, kind, participants and
# repeatability come only from ScheduleActionRegistry's fingerprinted v1 manifest (dwm-wks); this
# autoload holds no second copy.

# ---- Constants ----
const SAVE_SCHEMA_VERSION := 1
const MINESWEEPER_BASE_ROUNDS := 2
const MINESWEEPER_DISPLAY_MAX := 2
const MINESWEEPER_ROUND_FLOOR_MIN := -3
const MINESWEEPER_ROUND_FLOOR_MAX := 0
const MINESWEEPER_ROUND_CAP := 5
const MINESWEEPER_TASK_COIN_TOTAL_CAP := 9
const MINESWEEPER_MONEY_DAILY_CAP_BASE := 108
const MINESWEEPER_MONEY_DAILY_CAP_PER_EXTRA_ROUND := 54
# Aliased from the contacts domain owner (dwm-pm4); one roster, three surfaces.
const FRIEND_IDS := preload("res://scripts/domain/contact/ContactInvitationState.gd").FRIEND_IDS
const STAT_PRESSURE := "pressure"
const STAT_HEALTH := "health"
const STAT_MOTIVATION := "motivation"
const CONDITION_NONE := ""
const CONDITION_NAUSEA := "nausea"
const CONDITION_DIZZY := "dizzy"
const CONDITION_SEQUELA := "sequela"
const CONDITION_FAINT := "faint"
const AFFECTION_MIN := -7
const AFFECTION_MAX := 10

# Embedded static data (mirror of DataCatalog; see file header note).
const _INVITATION_DAYS := {
	"priscilla": [1, 2, 4, 6],
	"lavinia": [2, 3, 5, 6],
	"sylvia": [1, 3, 4, 5],
}
const _GROUP_INVITATION_DAYS := [2, 6]
const _GROUP_INVITATION_PAIRS := [["priscilla", "lavinia"]]
const _CONTACT_MESSAGE_ORDER := {
	1: ["priscilla", "sylvia"],
	2: ["priscilla", "lavinia"],
	3: ["lavinia", "sylvia"],
	4: ["priscilla", "sylvia"],
	5: ["lavinia", "sylvia"],
	6: ["priscilla", "lavinia"],
	7: ["priscilla", "lavinia", "sylvia"],
}
const _MINESWEEPER_TASK_IDS := [
	"complete_beginner", "complete_intermediate", "complete_expert",
	"no_flag_finish", "foresight_finish", "perfect_beginner",
	"perfect_intermediate", "perfect_expert", "win_win_win",
]
const _MINESWEEPER_MONEY_REWARD := {
	"beginner": {
		"exploded": {"money": 1, "pressure": 0},
		"cleared":  {"money": 6, "pressure": 0},
		"perfect":  {"money": 9, "pressure": 0},
	},
	"intermediate": {
		"exploded": {"money": 6, "pressure": 1},
		"cleared":  {"money": 27, "pressure": 0},
		"perfect":  {"money": 36, "pressure": 0},
	},
	"expert": {
		"exploded": {"money": 12, "pressure": 2},
		"cleared":  {"money": 45, "pressure": 0},
		"perfect":  {"money": 54, "pressure": 0},
	},
}

# Save whitelist (CONTRACTS §6). Order preserved for readability.
const _SAVE_WHITELIST := [
	"contact_message_unlocks", "contact_choice_state", "date_unlocks", "post_ending_queue",
	"missed_invitations",
	"day", "money", "coins", "stats", "friends", "affection", "friend_attitude",
	"dating_route_state", "inter_friend_affection", "inter_friend_route_state",
	"missed_group_date_counts", "daily_opened_contacts",
	"daily_group_invitation_generated", "daily_group_invitation_pair",
	"inventory", "chat_state", "shop_purchase_counts", 	"minesweeper_round_floor", "minesweeper_rng_seed",
	"minesweeper_rounds_left", "minesweeper_app_rounds_finished_today", "minesweeper_selected_difficulty",
	"minesweeper_money_earned_today", "minesweeper_task_rewards_claimed", "penalty_points_today",
	"penalty_points_total", "condition_effects_today", "condition_streak_days", "last_condition_day",
	"pending_hospital", "condition_resolved_day", "pending_date_friend_id",
	"pending_date_entries", "pending_date_entry_index",
	"pending_group_date_friend_ids", "pending_group_date_inviter_id",
	"pending_date_advance_day_after_finish", "opening_seen", "tutorial_seen", "story_flags",
	"route_context",
	"hospital_skipped_sylvia_solo_count",
]

# Whitelisted fields declared as typed Array[String]. JSON load yields an untyped Array, so
# assigning it directly via self.set() would raise a type error; rebuild these as Array[String].
const _TYPED_STRING_ARRAY_KEYS := [
	"daily_group_invitation_pair", "condition_effects_today",
	"pending_group_date_friend_ids",
]

# ---- Signals ----
signal stat_changed(stat_id: String, value: int, min_value: int, max_value: int)
signal money_changed(value: int)
signal coins_changed(value: int)
signal day_changed(day: int)
signal inventory_changed()
signal friends_changed()
signal contact_message_unlocked(result: Dictionary)
signal contact_choice_selected(result: Dictionary)
signal date_unlocks_changed()
signal ending_route_selected(result: Dictionary)
signal schedule_changed()
signal chat_changed(friend_id: String)
signal unread_friend(result: Dictionary)
signal contact_open_committed(result: Dictionary)
signal invitation_reply_committed(result: Dictionary)
signal minesweeper_rounds_changed(rounds_left: int, max_rounds: int)
signal minesweeper_reward_changed(result: Dictionary)
signal daily_state_reset()
signal condition_effect_resolved(result: Dictionary)
signal hospital_needed(result: Dictionary)
signal save_relevant_state_changed()
## The ONE declared committed-Schedule publication signal (Plan 01 Task 4, dwm-p2r.13). It is
## emitted only by publish_schedule_commit(), only after GameStateScheduleCommitPort's injected
## ledger reports a first delivery; a replay or a cold-restart retry emits nothing.
signal committed_schedule_published(result: Dictionary)

# ---- Run lifecycle (dwm-p2r.4 Task 3; plan 2026-07-17-phase-2r-03 §3) ----
const _RUN_LIFECYCLE_SCRIPT := preload("res://scripts/domain/run/RunLifecycle.gd")
const _DESKTOP_BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const _DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const _RUN_SNAPSHOT_SCHEMA_DESKTOP := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const _DAY_RESOLUTION_COORDINATOR_SCRIPT := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const _DAY_RESOLUTION_PORT_SCRIPT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const _CONTACT_INVITATION_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const _DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")
const _SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

var _run_lifecycle: RefCounted = _RUN_LIFECYCLE_SCRIPT.new()
var _mutation_gate: Object = null
var _identity_issuer: Object = null
## v4 desktop aggregate (Plan 02 Task 6, dwm-p2r.32): `{board,consequence}`, held as plain detached
## Dictionaries rather than live DesktopBoardState/DesktopConsequenceState objects. Production
## gameplay wiring of those state machines into GameState is Task 9's job (per GameStateDesktop
## BoardPort's own class doc); this field exists only so a v4 snapshot always has a schema-valid
## `desktop` member to serialize, defaulting to the empty NONE-board/no-pending-consequence shape
## and overwritten wholesale only by restore.
var _desktop_snapshot: Dictionary = {}
var _day_resolution_coordinator: RefCounted = null
## The ONE Bootstrap-owned Minesweeper round coordinator (dwm-p2r.9 Plan 06 Task 2). GameState
## never constructs it; the shared begin/complete round methods delegate here.
var _minesweeper_round_coordinator: RefCounted = null

# ---- State (declared per CONTRACTS §2) ----
var day: int:
	get:
		return _run_lifecycle.get_day()
	set(_attempted_value):
		push_error("GameState.day is read-only; use lifecycle commands")
var money: int
var coins: int
var stats: Dictionary

var friends: Dictionary
var affection: Dictionary
var friend_attitude: Dictionary
var dating_route_state: Dictionary
var inter_friend_affection: Dictionary
var inter_friend_route_state: Dictionary
var missed_group_date_counts: Dictionary

var contact_message_unlocks: Dictionary
var contact_choice_state: Dictionary
## Stateless contact/invitation state bag (dwm-p2r.6). Its own top-level run-snapshot
## section (never the gameplay bag); mutated only by the facade command methods via
## ContactInvitationState.prepare_* and persisted as the snapshot `contacts` section.
var contacts: Dictionary
var date_unlocks: Dictionary
# reserved/opaque — declared (CONTRACTS §2) + serialized by SaveManager (§6); NO behavior may be added.
var post_ending_queue: Array
# missed_invitations: Array[Dictionary]; each record {friend_id:String, source:"solo"|"group", day:int}
# where day = invitation day D (guilt message due on D+1). Save-whitelisted (CONTRACTS §2 follow-up rule).
var missed_invitations: Array
var daily_opened_contacts: Dictionary
var daily_group_invitation_generated: bool
var daily_group_invitation_pair: Array[String]

var inventory: Dictionary
# reserved/opaque — declared (CONTRACTS §2) + serialized by SaveManager (§6); NO behavior may be added.
var chat_state: Dictionary
var shop_purchase_counts: Dictionary

var minesweeper_round_floor: int
var minesweeper_rounds_left: int
var minesweeper_rng_seed: int = 0
var minesweeper_app_rounds_finished_today: int
var minesweeper_selected_difficulty: String
var unfinished_minesweeper_result: Dictionary
var minesweeper_money_earned_today: int
var minesweeper_task_rewards_claimed: Dictionary

var penalty_points_today: int
var penalty_points_total: int
var condition_effects_today: Array[String]
var condition_streak_days: int
var last_condition_day: int
var pending_hospital: bool
var condition_resolved_day: int

var pending_date_friend_id: String
var pending_date_entries: Array
var pending_date_entry_index: int
var pending_group_date_friend_ids: Array[String]
var pending_group_date_inviter_id: String
var pending_date_advance_day_after_finish: bool
var hospital_skipped_sylvia_solo_count: int = 0

var opening_seen: bool
var tutorial_seen: bool
var story_flags: Dictionary
var route_context: Dictionary
func _ready() -> void:
	pass


# ---- Lifecycle / stats / money / coins ----
func reset_game() -> void:
	# Fixed, self-consistent placeholder desktop identity (Plan 02 Task 6, dwm-p2r.32) -- mirrors
	# the pre-existing "run-local" placeholder run_id immediately below: this is a generic reset for
	# tests/template computation, never the real production New-Run path (that allocates through
	# SaveManager's Task-1 issuer/journal seams and installs real identity via commit_restore(),
	# never via reset()).
	var placeholder_causal_day_instance := "causal-day-local"
	var placeholder_identity_allocation_receipt := {
		"causal_day_instance_issuer_receipt": {
			"receipt_id": "issuer_receipt.local-placeholder", "purpose": "causal_day_instance",
			"namespace": "0".repeat(64), "counter": 1,
			"token": placeholder_causal_day_instance, "numeric_value": null,
		},
	}
	_run_lifecycle.reset("run-local", "branch-local", 0, placeholder_causal_day_instance,
		placeholder_identity_allocation_receipt)
	_desktop_snapshot = _empty_desktop_snapshot(placeholder_causal_day_instance,
		placeholder_identity_allocation_receipt["causal_day_instance_issuer_receipt"])
	# A new run starts with an empty effect/variable ledger (dwm-p2r.8, Plan-05 Task 3): receipts
	# and applied transaction ids are run-scoped and must never leak across runs.
	_command_receipts = {}
	_applied_effect_transaction_ids = []
	_applied_variable_transaction_ids = []
	_narrative_variables = {}
	money = 0
	coins = 0
	stats = {STAT_PRESSURE: 3, STAT_HEALTH: 6, STAT_MOTIVATION: 7}

	friends = {}
	affection = {}
	friend_attitude = {}
	for fid in FRIEND_IDS:
		affection[fid] = 0
		friend_attitude[fid] = ""
		# dating_route_state schema (CONTRACTS §2): date_count, dark_points, true_path_count, previous_entered_true_path.
		dating_route_state[fid] = {
			"date_count": 0, "dark_points": 0, "true_path_count": 0, "previous_entered_true_path": false,
		}
	inter_friend_affection = {}
	inter_friend_route_state = {}
	missed_group_date_counts = {}

	contact_message_unlocks = {}
	contact_choice_state = {}
	contacts = _CONTACT_INVITATION_STATE.make_defaults()
	date_unlocks = {}
	post_ending_queue = []
	missed_invitations = []
	daily_opened_contacts = {}
	daily_group_invitation_generated = false
	daily_group_invitation_pair = []

	# The canonical committed-Schedule aggregate is run-scoped and never leaks across runs
	# (Plan 01 Task 4, dwm-p2r.13). Task 5 gives it its v3 persistence.
	_committed_schedule = {}
	inventory = {}
	chat_state = {}
	shop_purchase_counts = {}

	minesweeper_round_floor = 0
	minesweeper_rng_seed = randi()
	minesweeper_rounds_left = 2
	minesweeper_app_rounds_finished_today = 0
	minesweeper_selected_difficulty = "beginner"
	unfinished_minesweeper_result = {}
	minesweeper_money_earned_today = 0
	minesweeper_task_rewards_claimed = {}

	penalty_points_today = 0
	penalty_points_total = 0
	condition_effects_today = []
	condition_streak_days = 0
	last_condition_day = 0
	pending_hospital = false
	condition_resolved_day = 0

	pending_date_friend_id = ""
	pending_date_entries = []
	pending_date_entry_index = 0
	pending_group_date_friend_ids = []
	pending_group_date_inviter_id = ""
	pending_date_advance_day_after_finish = true
	hospital_skipped_sylvia_solo_count = 0

	opening_seen = false
	tutorial_seen = false
	story_flags = {}
	route_context = {}
	emit_signal("save_relevant_state_changed")


func _stat_min(stat_id: String) -> int:
	match stat_id:
		STAT_PRESSURE: return 0
		STAT_HEALTH: return -2
		STAT_MOTIVATION: return 0
	return 0


func _stat_max(stat_id: String) -> int:
	match stat_id:
		STAT_PRESSURE: return 12
		STAT_HEALTH: return 9
		STAT_MOTIVATION: return 7
	return 0


func get_stat(stat_id: String) -> int:
	return int(stats.get(stat_id, 0))


func get_stat_min(stat_id: String) -> int:
	return _stat_min(stat_id)


func get_stat_max(stat_id: String) -> int:
	return _stat_max(stat_id)


func get_stat_display_value(stat_id: String) -> int:
	var v: int = int(stats.get(stat_id, 0))
	match stat_id:
		STAT_PRESSURE, STAT_HEALTH:
			v = clampi(v, 0, 9)
		STAT_MOTIVATION:
			v = clampi(v, 0, 7)
	return v


func get_stat_display_max(stat_id: String) -> int:
	match stat_id:
		STAT_PRESSURE, STAT_HEALTH: return 9
		STAT_MOTIVATION: return 7
	return 0


func set_stat(stat_id: String, value: int) -> bool:
	var lo: int = _stat_min(stat_id)
	var hi: int = _stat_max(stat_id)
	var new_v: int = clampi(int(value), lo, hi)
	stats[stat_id] = new_v
	emit_signal("stat_changed", stat_id, new_v, lo, hi)
	emit_signal("save_relevant_state_changed")
	return true


func change_stat(stat_id: String, delta: int) -> bool:
	return set_stat(stat_id, int(stats.get(stat_id, 0)) + int(delta))


func change_money(delta: int) -> bool:
	var new_v: int = money + int(delta)
	if new_v < -30:
		new_v = -30
	money = new_v
	emit_signal("money_changed", money)
	emit_signal("save_relevant_state_changed")
	return true


func can_spend_money(amount: int) -> bool:
	if amount <= 0:
		return false
	return money >= 0 and (money - amount) >= -30


func try_spend_money(amount: int) -> bool:
	if not can_spend_money(amount):
		return false
	money -= amount
	emit_signal("money_changed", money)
	emit_signal("save_relevant_state_changed")
	return true


func change_coins(delta: int) -> bool:
	var new_v: int = coins + int(delta)
	if new_v < 0:
		new_v = 0
	coins = new_v
	emit_signal("coins_changed", coins)
	emit_signal("save_relevant_state_changed")
	return true


func can_spend_coins(amount: int) -> bool:
	if amount <= 0:
		return false
	return coins >= amount


func try_spend_coins(amount: int) -> bool:
	if not can_spend_coins(amount):
		return false
	coins -= amount
	emit_signal("coins_changed", coins)
	emit_signal("save_relevant_state_changed")
	return true


func add_inventory(item_id: String, count: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + int(count)
	emit_signal("inventory_changed")
	emit_signal("save_relevant_state_changed")


func remove_inventory(item_id: String, count: int = 1) -> bool:
	var have: int = int(inventory.get(item_id, 0))
	if have < count:
		return false
	have -= count
	if have <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = have
	emit_signal("inventory_changed")
	emit_signal("save_relevant_state_changed")
	return true


# ---- Affection / friends ----
func change_affection(friend_id: String, delta: int) -> bool:
	var cur: int = int(affection.get(friend_id, 0))
	var new_v: int = clampi(cur + int(delta), AFFECTION_MIN, AFFECTION_MAX)
	affection[friend_id] = new_v
	emit_signal("friends_changed")
	emit_signal("save_relevant_state_changed")
	return true


func get_affection_tier(friend_id: String) -> String:
	var a: int = int(affection.get(friend_id, 0))
	if a < 0:
		return "hatred"
	if a <= 3:
		return "just_friend"
	if a <= 6:
		return "ambiguous"
	return "love"


func set_friend_attitude(friend_id: String, attitude: String) -> bool:
	friend_attitude[friend_id] = attitude
	emit_signal("friends_changed")
	emit_signal("save_relevant_state_changed")
	return true


func change_inter_friend_affection(friend_a: String, friend_b: String, delta: int) -> bool:
	var key: String = _sorted_pair_key(friend_a, friend_b)
	var cur: int = int(inter_friend_affection.get(key, 0))
	inter_friend_affection[key] = cur + int(delta)
	emit_signal("friends_changed")
	emit_signal("save_relevant_state_changed")
	return true


# ---- Minesweeper app economy ----
func get_minesweeper_display_rounds_left() -> int:
	return clampi(minesweeper_rounds_left, -3, 2)


func get_minesweeper_display_rounds_max() -> int:
	return MINESWEEPER_DISPLAY_MAX


func get_minesweeper_total_playable_rounds() -> int:
	return MINESWEEPER_BASE_ROUNDS - minesweeper_round_floor


func get_minesweeper_playable_rounds_remaining() -> int:
	return maxi(0, minesweeper_rounds_left - minesweeper_round_floor)


func has_minesweeper_app_round_available() -> bool:
	return minesweeper_rounds_left > minesweeper_round_floor


func change_minesweeper_round_floor(delta: int) -> bool:
	var new_v: int = clampi(minesweeper_round_floor + int(delta), MINESWEEPER_ROUND_FLOOR_MIN, MINESWEEPER_ROUND_FLOOR_MAX)
	minesweeper_round_floor = new_v
	emit_signal("minesweeper_rounds_changed", get_minesweeper_display_rounds_left(), get_minesweeper_display_rounds_max())
	emit_signal("save_relevant_state_changed")
	return true


func get_minesweeper_safety_level() -> int:
	if inventory.has("debug_key"):
		return 3
	if inventory.has("lucky_charm"):
		return 2
	return 1


func can_start_minesweeper_app_round() -> bool:
	return get_stat(STAT_MOTIVATION) > 0 \
		and minesweeper_rounds_left > minesweeper_round_floor \
		and unfinished_minesweeper_result.is_empty()


func consume_minesweeper_app_round() -> bool:
	if not can_start_minesweeper_app_round():
		return false
	minesweeper_rounds_left -= 1
	change_stat(STAT_MOTIVATION, -1)
	emit_signal("minesweeper_rounds_changed", get_minesweeper_display_rounds_left(), get_minesweeper_display_rounds_max())
	return true


func start_minesweeper_app_round(difficulty: String) -> Dictionary:
	if not can_start_minesweeper_app_round():
		return {}
	minesweeper_selected_difficulty = difficulty
	consume_minesweeper_app_round()
	unfinished_minesweeper_result = {
		"context": "app",
		"difficulty": difficulty,
		"started_at_unix": Time.get_unix_time_from_system(),
	}
	return unfinished_minesweeper_result


func finish_minesweeper_app_round(result: Dictionary) -> void:
	if result.get("context", "") != "app":
		return
	unfinished_minesweeper_result = {}
	minesweeper_app_rounds_finished_today += 1

	var reward: Dictionary = apply_minesweeper_money_reward(result)
	check_and_claim_minesweeper_task_rewards(result)

	var effect_ids: Array = result.get("effect_ids", [])
	if not effect_ids.is_empty():
		_apply_effect_ids(effect_ids)

	unlock_contact_message_after_minesweeper_finished(result)
	_bridge_maybe_activate_group()

	emit_signal("minesweeper_rounds_changed", get_minesweeper_display_rounds_left(), get_minesweeper_display_rounds_max())
	emit_signal("minesweeper_reward_changed", reward)
	emit_signal("save_relevant_state_changed")


func clear_unfinished_minesweeper_round() -> void:
	unfinished_minesweeper_result = {}


# Minesweeper app-round money reward. Per-outcome/difficulty amounts are defined in
# _MINESWEEPER_MONEY_REWARD (see the indexed Minesweeper requirements). The daily cap
# (108 + 54 * max(0, total_playable_rounds - 2)) is enforced; any amount is clamped to the
# remaining daily cap. The "do not invent logic" guard is intentionally removed (author decision):
# concrete reward values are now specified and applied.
func calculate_minesweeper_money_reward(result: Dictionary) -> Dictionary:
	var cap: int = MINESWEEPER_MONEY_DAILY_CAP_BASE + MINESWEEPER_MONEY_DAILY_CAP_PER_EXTRA_ROUND * maxi(0, get_minesweeper_total_playable_rounds() - 2)
	var remaining: int = maxi(0, cap - minesweeper_money_earned_today)
	var difficulty: String = result.get("difficulty", "")
	var outcome: String = result.get("outcome", "")
	if outcome == "no_flag" or outcome == "foresight":
		outcome = "perfect"
	var entry: Dictionary = _MINESWEEPER_MONEY_REWARD.get(difficulty, {}).get(outcome, {})
	var money_amount: int = int(entry.get("money", 0))
	var pressure_delta: int = int(entry.get("pressure", 0))
	var capped: bool = false
	if money_amount > remaining:
		money_amount = remaining
		capped = true
	return {"money": money_amount, "pressure": pressure_delta, "capped": capped, "remaining_cap": remaining}


func apply_minesweeper_money_reward(result: Dictionary) -> Dictionary:
	var reward: Dictionary = calculate_minesweeper_money_reward(result)
	var amount: int = int(reward.get("money", 0))
	if amount > 0:
		change_money(amount)
		minesweeper_money_earned_today += amount
	var pressure_delta: int = int(reward.get("pressure", 0))
	if pressure_delta != 0:
		change_stat(STAT_PRESSURE, pressure_delta)
	return reward


func check_and_claim_minesweeper_task_rewards(result: Dictionary) -> Array:
	var claimed: Array = []
	var task_ids: Array = result.get("task_ids", [])
	for tid in task_ids:
		if not _MINESWEEPER_TASK_IDS.has(tid):
			continue
		if minesweeper_task_rewards_claimed.has(tid):
			continue
		if minesweeper_task_rewards_claimed.size() >= MINESWEEPER_TASK_COIN_TOTAL_CAP:
			break
		minesweeper_task_rewards_claimed[tid] = true
		change_coins(1)
		claimed.append(tid)
	# win_win_win: claimable once when beginner+intermediate+expert each achieved.
	if not minesweeper_task_rewards_claimed.has("win_win_win"):
		if minesweeper_task_rewards_claimed.has("complete_beginner") \
				and minesweeper_task_rewards_claimed.has("complete_intermediate") \
				and minesweeper_task_rewards_claimed.has("complete_expert"):
			if minesweeper_task_rewards_claimed.size() < MINESWEEPER_TASK_COIN_TOTAL_CAP:
				minesweeper_task_rewards_claimed["win_win_win"] = true
				change_coins(1)
				claimed.append("win_win_win")
	return claimed


# ---- Invitations / contacts ----
func is_invitation_day(friend_id: String, target_day: int = -1) -> bool:
	var d: int = target_day if target_day >= 0 else day
	return _INVITATION_DAYS.get(friend_id, []).has(d)


func is_group_invitation_day(target_day: int = -1) -> bool:
	var d: int = target_day if target_day >= 0 else day
	return _GROUP_INVITATION_DAYS.has(d)


func configure_identity_issuer(identity_issuer: Object) -> Dictionary:
	if identity_issuer == null:
		return _transaction_failure(&"invalid_identity_issuer", "identity issuer is required")
	for method: String in ["issue", "verify_issued", "derive_child", "validate_child"]:
		if not identity_issuer.has_method(method):
			return _transaction_failure(&"invalid_identity_issuer", "missing " + method)
	if _identity_issuer != null:
		if _identity_issuer != identity_issuer:
			return _transaction_failure(&"identity_issuer_already_configured", "replacement refused")
		return {"ok": true, "code": &"ok", "value": {
			"issuer_instance_id": _identity_issuer.get_instance_id(), "already_configured": true,
		}, "receipt": {}}
	_identity_issuer = identity_issuer
	return {"ok": true, "code": &"ok", "value": {
		"issuer_instance_id": _identity_issuer.get_instance_id(), "already_configured": false,
	}, "receipt": {}}


func open_contact(friend_id: String, command_id: String, command_issuer_receipt: Dictionary) -> Dictionary:
	var verified := _verify_contact_command(command_id, command_issuer_receipt)
	if not verified.get("ok", false):
		return verified
	var replayed: bool = (contacts.get("transaction_receipts", {}) as Dictionary).has(command_id)
	var action_id := _contact_action_id(friend_id)
	var record := _schedule_action_record(action_id)
	if record.is_empty():
		return _transaction_failure(&"contact_offer_absent", action_id)
	var opened: Dictionary = _CONTACT_INVITATION_STATE.prepare_open_contact(
		contacts, friend_id, day, command_id, command_issuer_receipt,
		_identity_issuer, record)
	if not opened.get("ok", false):
		return opened
	contacts = opened["value"]["candidate"]
	if not replayed:
		daily_opened_contacts["day:%d:friend:%s" % [day, friend_id]] = true
		var committed := {"ok": true, "code": &"ok", "value": {
			"receipt": opened["receipt"].duplicate(true), "replayed": false,
		}, "receipt": opened["receipt"].duplicate(true)}
		contact_open_committed.emit(committed.duplicate(true))
		emit_signal("chat_changed", friend_id)
		emit_signal("save_relevant_state_changed")
		return committed
	return {"ok": true, "code": &"ok", "value": {
		"receipt": opened["receipt"].duplicate(true), "replayed": true,
	}, "receipt": opened["receipt"].duplicate(true)}


func get_daily_message_friend_for_finished_round(round_number: int, target_day: int = -1) -> String:
	var d: int = target_day if target_day >= 0 else day
	var order: Array = _CONTACT_MESSAGE_ORDER.get(d, [])
	var idx: int = -1
	if round_number == 1:
		idx = 0
	elif round_number == 2:
		idx = 1
	elif round_number == 3:
		if d == 7 and minesweeper_round_floor < 0:
			idx = 2
		else:
			return ""
	else:
		return ""
	if idx < 0 or idx >= order.size():
		return ""
	# Group invitation for the day suppresses individual solo messages.
	if _group_is_active():
		return ""
	return order[idx]


func unlock_contact_message_after_minesweeper_finished(result: Dictionary) -> Dictionary:
	var friend: String = get_daily_message_friend_for_finished_round(minesweeper_app_rounds_finished_today, day)
	if friend == "":
		return {}
	if _group_is_active():
		return {}
	# Day-7 invitation messages require at least Ambiguous affection (CONTRACTS §2).
	if day == 7 and get_affection_tier(friend) not in ["ambiguous", "love"]:
		return {}
	var key: String = "day:%d:friend:%s" % [day, friend]
	contact_message_unlocks[key] = true
	# Migration bridge (dwm-p2r.6, G1): mirror the daily-message unlock into a module solo offer
	# so pair solos exist in the bag by round 3 for group activation. Idempotent per friend/day.
	var offered: Dictionary = _CONTACT_INVITATION_STATE.prepare_offer_solo(
		contacts, friend, day, "solo:%s:day%d" % [friend, day], "offer:%s:day%d" % [friend, day])
	if offered.get("ok", false):
		contacts = offered["value"]["candidate"]
	emit_signal("contact_message_unlocked", {"friend_id": friend, "day": day})
	emit_signal("save_relevant_state_changed")
	return {"friend_id": friend, "day": day}


func is_contact_message_unlocked(friend_id: String, target_day: int = -1) -> bool:
	var d: int = target_day if target_day >= 0 else day
	return bool(contact_message_unlocks.get("day:%d:friend:%s" % [d, friend_id], false))


func is_contact_choice_selected(friend_id: String, target_day: int = -1) -> bool:
	var d: int = target_day if target_day >= 0 else day
	return bool(contact_choice_state.get("day:%d:friend:%s" % [d, friend_id], false))


func get_contact_choices(friend_id: String, target_day: int = -1) -> Array:
	return []


func get_contact_view(friend_id: String, target_day: int = -1) -> Dictionary:
	# Player-visible contact history for a friend (dwm-p2r.6); delegates to the pure module.
	var d: int = target_day if target_day >= 0 else day
	return _CONTACT_INVITATION_STATE.get_contact_view(contacts, friend_id, d)


func _group_is_active() -> bool:
	# dwm-p2r.6: today's group offer exists once activated (round 3) — the module is the source.
	return str(contacts["group_action"]["state"]) != "INACTIVE"


func _group_inviter() -> String:
	var inviter: Variant = contacts["group_action"]["inviter_id"]
	return str(inviter) if inviter != null else ""


func _group_pair_ids() -> Array[String]:
	var ids: Array[String] = []
	for pid: String in _CONTACT_INVITATION_STATE.GROUP_PAIR:
		ids.append(pid)
	return ids


func _bridge_maybe_activate_group() -> void:
	# G2 (dwm-p2r.6): canon group activation fires on the 3rd Minesweeper round of a group day,
	# once both pair solos exist unread in the bag (generated by rounds 1-2). Idempotent per day.
	if day not in _GROUP_INVITATION_DAYS:
		return
	if minesweeper_app_rounds_finished_today != _CONTACT_INVITATION_STATE.GROUP_ACTIVATION_ROUND:
		return
	var activated: Dictionary = _CONTACT_INVITATION_STATE.prepare_activate_group_after_round(
		contacts, day,
		_CONTACT_INVITATION_STATE.GROUP_ACTIVATION_ROUND - 1,
		_CONTACT_INVITATION_STATE.GROUP_ACTIVATION_ROUND,
		"gactivate:day%d" % day)
	if activated.get("ok", false):
		contacts = activated["value"]["candidate"]


func reply_invitation(friend_id: String, command_id: String, command_issuer_receipt: Dictionary) -> Dictionary:
	var verified := _verify_contact_command(command_id, command_issuer_receipt)
	if not verified.get("ok", false):
		return verified
	var replayed: bool = (contacts.get("transaction_receipts", {}) as Dictionary).has(command_id)
	var action_id := _contact_action_id(friend_id)
	var record := _schedule_action_record(action_id)
	if record.is_empty():
		return _transaction_failure(&"contact_offer_absent", action_id)
	var result: Dictionary = _CONTACT_INVITATION_STATE.prepare_reply(
		contacts, friend_id, day, command_id, command_issuer_receipt,
		_identity_issuer, record)
	if not result.get("ok", false):
		return result
	contacts = result["value"]["candidate"]
	var committed := {"ok": true, "code": &"ok", "value": {
		"receipt": result["receipt"].duplicate(true), "replayed": replayed,
	}, "receipt": result["receipt"].duplicate(true)}
	if not replayed:
		invitation_reply_committed.emit(committed.duplicate(true))
		emit_signal("save_relevant_state_changed")
	return committed


func _verify_contact_command(command_id: String,
		command_issuer_receipt: Dictionary) -> Dictionary:
	if _identity_issuer == null:
		return _transaction_failure(&"identity_issuer_unconfigured", "identity issuer is required")
	if command_id.strip_edges().is_empty() or command_issuer_receipt.is_empty():
		return _transaction_failure(&"invalid_contact_command", "full command proof is required")
	var verified: Variant = _identity_issuer.call(
		&"verify_issued", command_issuer_receipt, &"transaction_id")
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _transaction_failure(&"invalid_contact_command", "issuer verification failed")
	if str(command_issuer_receipt.get("token", "")) != command_id:
		return _transaction_failure(&"contact_command_id_mismatch", command_id)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func _contact_action_id(friend_id: String) -> String:
	var group: Dictionary = contacts.get("group_action", {})
	if friend_id in _CONTACT_INVITATION_STATE.GROUP_PAIR \
			and str(group.get("state", "")) in _CONTACT_INVITATION_STATE.GROUP_OPEN_STATES \
			and int(group.get("day", -1)) == day:
		return str(group.get("action_id", ""))
	return "solo:%s:day%d" % [friend_id, day]


func _schedule_action_record(action_id: String) -> Dictionary:
	var loaded: Dictionary = _SCHEDULE_ACTION_REGISTRY.load_current()
	if not loaded.get("ok", false):
		return {}
	var registry: Object = loaded.get("value", {}).get("registry")
	if registry == null:
		return {}
	# The shipped registry API is fingerprint()/find_record(action_id); no stale lookup/snapshot.
	if str(registry.call(&"fingerprint")).strip_edges().is_empty():
		return {}
	var found: Variant = registry.call(&"find_record", action_id)
	if typeof(found) != TYPE_DICTIONARY or not (found as Dictionary).get("ok", false):
		return {}
	return ((found as Dictionary).get("value", {}) as Dictionary).get("record", {}).duplicate(true)


func resolve_invitations_for_day(attendance: Dictionary, command_id: String) -> Dictionary:
	# Facade command (dwm-p2r.6): resolve every solo/group action at day end. Applies the
	# contacts state transitions + queued messages; the receipt carries counter_deltas,
	# deferred_twofriends, and the PL window for the day-resolution flow to route (Phase 2R-7).
	if command_id.is_empty():
		return {"ok": false, "code": &"invalid_command_id", "message": "command_id is required"}
	if contacts["transaction_receipts"].has(command_id):
		return {"ok": true, "code": &"ok", "value": {"receipt": contacts["transaction_receipts"][command_id], "replayed": true}}
	var result: Dictionary = _CONTACT_INVITATION_STATE.prepare_resolve_day_end(contacts, day, attendance, command_id)
	if not result.get("ok", false):
		return result
	contacts = result["value"]["candidate"]
	emit_signal("save_relevant_state_changed")
	return {"ok": true, "code": &"ok", "value": {"receipt": result["receipt"], "replayed": false}}


func is_date_unlocked(friend_id: String, target_day: int = -1) -> bool:
	var d: int = target_day if target_day >= 0 else day
	if d == 7:
		return is_contact_message_unlocked(friend_id, 7) and get_affection_tier(friend_id) in ["ambiguous", "love"]
	# dwm-p2r.6: a solo date is addable once its module offer reaches ACCEPTED (reply).
	return _CONTACT_INVITATION_STATE.is_date_addable(contacts, "solo:%s:day%d" % [friend_id, d])


func build_date_entry_from_unlock(friend_id: String, target_day: int = -1) -> Dictionary:
	var d: int = target_day if target_day >= 0 else day
	return {
		"type": "solo",
		"friend_id": friend_id,
		"friend_ids": [friend_id],
		"inviter_id": "",
		"day": d,
		"source": "unlock",
		"advance_day_after_finish": true,
		"gift_item_id": "",
	}


func is_group_date_unlocked(target_day: int = -1) -> bool:
	# dwm-p2r.6 canon: the group date is schedulable once the module group is ACCEPTED (replied).
	var d: int = target_day if target_day >= 0 else day
	return _CONTACT_INVITATION_STATE.is_date_addable(contacts, "group:%s:day%d" % [_CONTACT_INVITATION_STATE.GROUP_PAIR_KEY, d])


func build_group_date_entry_from_unlock(target_day: int = -1) -> Dictionary:
	var d: int = target_day if target_day >= 0 else day
	return {
		"type": "group",
		"friend_ids": _group_pair_ids(),
		"inviter_id": _group_inviter(),
		"day": d,
		"source": "unlock",
		"advance_day_after_finish": true,
		"gift_item_id": "",
	}


func get_day7_ending_candidates_from_schedule() -> Array[String]:
	var candidates: Array[String] = []
	for fid in FRIEND_IDS:
		if not is_contact_message_unlocked(fid, 7):
			continue
		if get_affection_tier(fid) not in ["ambiguous", "love"]:
			continue
		var has_entry: bool = false
		for entry in _committed_entries():
			if str(entry.get("action_kind", "")) == "solo" \
					and (entry.get("participants", []) as Array).has(fid):
				has_entry = true
				break
		if has_entry:
			candidates.append(fid)
			if candidates.size() >= 1:
				break
	return candidates


func resolve_day7_ending() -> Dictionary:
	if day != 7:
		return {"ok": false, "candidate_friend_id": "", "ending_id": "", "epilogue_ending_id": "", "route_context_set": false, "reason": "not_day7"}
	var candidates: Array[String] = get_day7_ending_candidates_from_schedule()
	var candidate_friend_id: String = candidates[0] if candidates.size() > 0 else ""
	var ending_id: String = ""
	var epilogue_ending_id: String = ""

	# Highest precedence: Special Sylvia (secret ending), evaluated before priscilla_lavinia.
	if should_route_sylvia_special_ending():
		ending_id = "ending.sylvia.special"
	elif should_route_priscilla_lavinia_post_ending():
		ending_id = "ending.priscilla_lavinia"
	elif candidate_friend_id == "":
		ending_id = "ending.alone"
	else:
		var f: String = candidate_friend_id
		var drs: Dictionary = dating_route_state.get(f, {})
		# Binary tone (story/05 §1): Totally Dark or Sweet; the true-path is now a postscript.
		if int(drs.get("dark_points", 0)) >= 2:
			ending_id = "ending.%s.dark" % f
		else:
			ending_id = "ending.%s.sweet" % f

	# Epilogue: if Priscilla/Lavinia post-ending is also unlocked and is not the primary, play it after.
	if should_route_priscilla_lavinia_post_ending() and ending_id != "ending.priscilla_lavinia":
		epilogue_ending_id = "ending.priscilla_lavinia"

	route_context["ending_id"] = ending_id
	route_context["epilogue_ending_id"] = epilogue_ending_id
	_lifecycle_ensure_ending(ending_id, epilogue_ending_id)
	emit_signal("ending_route_selected", {"ending_id": ending_id, "candidate_friend_id": candidate_friend_id})
	emit_signal("save_relevant_state_changed")
	return {
		"ok": true,
		"candidate_friend_id": candidate_friend_id,
		"ending_id": ending_id,
		"epilogue_ending_id": epilogue_ending_id,
		"route_context_set": true,
		"reason": "resolved",
	}


func should_route_priscilla_lavinia_post_ending() -> bool:
	return int(missed_group_date_counts.get("priscilla_lavinia", 0)) >= 2

func should_route_sylvia_special_ending() -> bool:
	return hospital_skipped_sylvia_solo_count >= 2


func can_respond_to_invitation(friend_id: String) -> bool:
	if is_invitation_day(friend_id) and not is_contact_choice_selected(friend_id):
		return true
	if is_group_invitation_day() and _group_pair_contains(friend_id) and not _group_is_active():
		return true
	return false


func can_buy_supportz() -> bool:
	return minesweeper_app_rounds_finished_today >= 2 and minesweeper_round_floor > MINESWEEPER_ROUND_FLOOR_MIN


func has_unread_friend_messages() -> Dictionary:
	var out: Dictionary = {}
	for fid in FRIEND_IDS:
		var unread: bool = is_contact_message_unlocked(fid) and not is_contact_choice_selected(fid)
		out[fid] = unread
		if unread:
			emit_signal("unread_friend", {"friend_id": fid, "day": day})
	return out


# ---- Schedule ----
# The canonical committed aggregate is the ONLY Schedule source of truth (Plan 01 Task 5,
# dwm-p2r.13). The legacy per-day draft array, its add-time spend/refund, its direct
# execute/clear/queue helpers and the loose date-candidate seam all retired at this boundary;
# GameStateScheduleCommitPort owns the transaction that produces committed state.

## The committed entries for the current day, in canonical slot order.
func _committed_entries() -> Array:
	return _canonical_committed_schedule()["entries"] as Array


## Adapts one committed entry to the legacy `type`/`friend_id`/`friend_ids` transport shape the
## day-resolution and dating flows still speak. `twofriends` is never a committed kind: it is a
## deferred route that day-end resolution produces, so it can only ever arrive from
## `create_missed_group_twofriends_entry`.
##
## SCOPE NOTE, deliberately not glossed over: the DATE TRANSPORT is behaviour-preserving, but the
## pre-Done QUERY surface is not. `should_warn_minesweeper_before_schedule_done`,
## `get_scheduled_date_count` and `get_max_scheduled_dates_for_current_day` were written to inspect
## the draft the player had built BEFORE pressing Done. There is no draft in GameState any more --
## the aggregate is empty until the Done commit transaction lands -- so those queries now answer
## from post-commit state and their draft-time branches are unreachable. That is the amendment's
## intent (the draft belongs to the Schedule UI owner, explicitly out of scope for dwm-p2r.13) and
## no live caller exists today, but it is a real contract change, not a pure refactor.
func _legacy_entry_from_committed(entry: Dictionary) -> Dictionary:
	var participants: Array = entry.get("participants", [])
	match str(entry.get("action_kind", "")):
		"solo":
			return {
				"type": "solo",
				"friend_id": str(participants[0]) if participants.size() > 0 else "",
				"advance_day_after_finish": true,
			}
		"group":
			return {
				"type": "group",
				"friend_ids": participants.duplicate(),
				"inviter_id": _group_inviter(),
				"advance_day_after_finish": true,
			}
	var action_id := str(entry.get("action_id", ""))
	return {"type": action_id, "id": action_id}


func _is_committed_date_entry(entry: Dictionary) -> bool:
	return str(entry.get("action_kind", "")) in ["solo", "group"]


## Day end and the hospital route return the committed aggregate to its canonical EMPTY form. An
## empty `_committed_schedule` always projects the LIVE day, so the aggregate can never carry a
## stale day into the next snapshot. Motivation is never refunded here: the commit already charged.
func _reset_committed_schedule_for_day_end() -> void:
	_committed_schedule = {}
	emit_signal("schedule_changed")
	emit_signal("save_relevant_state_changed")


func should_warn_minesweeper_before_schedule_done() -> Dictionary:
	var has_unfinished: bool = not unfinished_minesweeper_result.is_empty()
	var has_playable: bool = has_minesweeper_app_round_available()
	var motivation: int = get_stat(STAT_MOTIVATION)
	var has_date_entry: bool = false
	var has_non_date_entry: bool = false
	for entry in _committed_entries():
		if _is_committed_date_entry(entry):
			has_date_entry = true
		else:
			has_non_date_entry = true

	var should_warn: bool = false
	var reason: String = ""
	if not has_date_entry:
		var cond1: bool = motivation > 0 and has_unfinished
		var cond2: bool = motivation > 0 and has_playable
		var cond3: bool = motivation == 0 and has_non_date_entry and has_playable
		should_warn = cond1 or cond2 or cond3
		if cond1:
			reason = "unfinished_round_and_motivation"
		elif cond2:
			reason = "playable_round_and_motivation"
		elif cond3:
			reason = "playable_round_zero_motivation_with_non_date"
		else:
			reason = "no_warn"
	else:
		reason = "date_present"

	return {
		"should_warn": should_warn,
		"reason": reason,
		"has_unfinished_round": has_unfinished,
		"has_playable_round": has_playable,
		"motivation": motivation,
		"has_non_date_entry": has_non_date_entry,
	}


func get_scheduled_date_friend_ids() -> Array[String]:
	var out: Array[String] = []
	for entry in _committed_entries():
		match str(entry.get("action_kind", "")):
			"solo":
				var participants: Array = entry.get("participants", [])
				out.append(str(participants[0]) if participants.size() > 0 else "")
			"group":
				for fid: Variant in entry.get("participants", []):
					out.append(str(fid))
	return out


func get_scheduled_date_entries() -> Array:
	var out: Array = []
	for entry in _committed_entries():
		if _is_committed_date_entry(entry):
			out.append(_legacy_entry_from_committed(entry))
	return out


func get_scheduled_date_count() -> int:
	var c: int = 0
	for entry in _committed_entries():
		if _is_committed_date_entry(entry):
			c += 1
	return c


func get_max_scheduled_dates_for_current_day() -> int:
	if day >= 1 and day <= 6:
		return 2
	return 1


func collect_unscheduled_accepted_invitations_for_day_end() -> Array:
	var out: Array = []
	var scheduled_ids: Array[String] = get_scheduled_date_friend_ids()
	for fid in FRIEND_IDS:
		if is_date_unlocked(fid) and not scheduled_ids.has(fid):
			out.append({"type": "solo", "friend_id": fid})
	if _group_is_active() and not _group_scheduled():
		out.append({"type": "group", "friend_ids": _group_pair_ids(), "inviter_id": _group_inviter()})
	return out


func get_missed_invitation_for_friend(friend_id: String, target_day: int = -1) -> Dictionary:
	# Returns the missed-invitation record whose invite day == target_day - 1 (guilt due on target_day),
	# or {} if none. Consumers read "source" to pick the solo vs group missed_question label
	# (CONTRACTS §2 follow-up rule). Read-only; returns a copy.
	var d: int = target_day if target_day >= 0 else day
	for rec in missed_invitations:
		if rec is Dictionary and rec.get("friend_id", "") == friend_id and int(rec.get("day", -999)) == d - 1:
			return rec.duplicate()
	return {}


func execute_schedule_sequence_until_route_needed() -> Dictionary:
	# No draft re-validation here: the committed aggregate is canonical by construction, having
	# already passed ScheduleStateSchema and the registry inside the commit transaction.
	execute_non_date_schedule_effects()

	var date_entries: Array = []
	var twofriends_entries: Array = []
	# A committed entry is never `twofriends`; that route is produced below at day end.
	for entry in get_scheduled_date_entries():
		date_entries.append(entry)

	var cond: Dictionary = resolve_pressure_health_condition_end_of_day()
	var needs_hospital: bool = bool(cond.get("needs_hospital", false))

	for unscheduled in collect_unscheduled_accepted_invitations_for_day_end():
		if unscheduled.get("type") == "group":
			var entry: Dictionary = create_missed_group_twofriends_entry(day, unscheduled.get("friend_ids", []), unscheduled.get("inviter_id", ""))
			twofriends_entries.append(entry)

	var route: String = "advance"
	if needs_hospital:
		route = "hospital"
	elif date_entries.size() > 0:
		route = "dating"
	elif twofriends_entries.size() > 0:
		route = "twofriends"

	return {
		"ok": true,
		"executed": true,
		"needs_hospital": needs_hospital,
		"route": route,
		"date_entries": date_entries,
		"twofriends_entries": twofriends_entries,
		"reason": route,
	}


## The REGISTRY alone derives the effects of a committed ordinary action (dwm-wks acceptance): a
## committed entry names its action, never its consequences, so no caller-authored `effect_ids`
## can influence execution.
##
## FAILURE MODE, recorded rather than hidden: a registry that fails to load applies NOTHING rather
## than guessing, while the legacy caller `execute_schedule_sequence_until_route_needed` still
## reports success and routes the day. Before this boundary the effects rode on the entry itself, so
## they were applied whatever the registry did. Deriving them from the registry is the correct
## design (the entry must not carry its own consequences), but the silent-success path belongs to
## the legacy transport that Task 6 replaces with the committed-receipt start port; it is not
## repaired here because this task does not own that transport's result contract.
func execute_non_date_schedule_effects() -> void:
	var loaded: Dictionary = _SCHEDULE_ACTION_REGISTRY.load_current()
	if not loaded.get("ok", false):
		return
	var registry: Object = (loaded["value"] as Dictionary)["registry"]
	for entry in _committed_entries():
		if _is_committed_date_entry(entry):
			continue
		var found: Dictionary = registry.find_record(str(entry.get("action_id", "")))
		if not found.get("ok", false):
			continue
		var effect_ids: Array = ((found["value"] as Dictionary)["record"] as Dictionary).get("effect_ids", [])
		if not effect_ids.is_empty():
			_apply_effect_ids(effect_ids)


func create_missed_group_twofriends_entry(day_arg: int, friend_ids: Array, inviter_id: String) -> Dictionary:
	var key: String = _sorted_pair_key(friend_ids[0], friend_ids[1]) if friend_ids.size() >= 2 else "unknown"
	missed_group_date_counts[key] = int(missed_group_date_counts.get(key, 0)) + 1
	emit_signal("save_relevant_state_changed")
	return {
		"type": "twofriends",
		"friend_ids": friend_ids,
		"inviter_id": inviter_id,
		"day": day_arg,
		"source": "missed_group",
		"advance_day_after_finish": false,
	}


# ---- Conditions / hospital / day ----
func resolve_pressure_health_condition_end_of_day() -> Dictionary:
	if condition_resolved_day == day:
		return {"ok": true, "needs_hospital": pending_hospital, "reason": "already_resolved"}

	var pressure: int = get_stat(STAT_PRESSURE)
	var health: int = get_stat(STAT_HEALTH)
	var danger: bool = pressure >= 10 or health <= 0
	var condition: String = CONDITION_NONE
	var daily_penalty: int = 0

	if danger:
		if pressure >= 10 and health <= 0:
			condition = CONDITION_DIZZY
		else:
			condition = CONDITION_NAUSEA

		var penalty_pressure: int = maxi(0, pressure - 9) if pressure > 9 else 0
		var penalty_health: int = maxi(0, 1 - health) if health <= 0 else 0
		daily_penalty = mini(penalty_pressure + penalty_health, 6)
		penalty_points_today = daily_penalty
		penalty_points_total = mini(penalty_points_total + daily_penalty, 42)

		if pressure > 9:
			set_stat(STAT_PRESSURE, 9)
		if health < 1:
			set_stat(STAT_HEALTH, 1)

		# Danger day applies sequela to the NEXT day (consumed in begin_new_day).
		condition_streak_days = 1

	var faint: bool = false
	if condition != CONDITION_NONE:
		condition_effects_today.append(condition)
		if CONDITION_SEQUELA in condition_effects_today and (condition == CONDITION_NAUSEA or condition == CONDITION_DIZZY):
			condition_effects_today.append(CONDITION_FAINT)
			faint = true
		pending_hospital = faint
		emit_signal("condition_effect_resolved", {"condition": condition, "faint": faint})
		if faint:
			emit_signal("hospital_needed", {"condition": condition})

	condition_resolved_day = day
	emit_signal("save_relevant_state_changed")
	return {"ok": true, "needs_hospital": pending_hospital, "condition": condition, "faint": faint}


func should_route_hospital() -> bool:
	return pending_hospital

func check_immediate_faint() -> bool:
	if condition_effects_today.has(CONDITION_SEQUELA) and (get_stat(STAT_PRESSURE) >= 10 or get_stat(STAT_HEALTH) <= 0):
		pending_hospital = true
		emit_signal("condition_effect_resolved", {"condition": CONDITION_SEQUELA, "faint": true})
		emit_signal("hospital_needed", {"condition": CONDITION_SEQUELA})
		return true
	return false


func apply_hospital_recovery_and_advance_day() -> bool:
	set_stat(STAT_HEALTH, 6)
	set_stat(STAT_PRESSURE, 3)
	pending_hospital = false
	condition_streak_days = 0
	condition_resolved_day = 0
	condition_effects_today = []
	# Special Sylvia ending evidence: count committed Sylvia solo dates skipped by this hospital
	# trip. MUST read the committed entries BEFORE the day-end reset — pending_date_entries is
	# empty on a hospital route (dates are skipped, never queued via prepare_dating_entries).
	for _e in _committed_entries():
		if str(_e.get("action_kind", "")) == "solo" \
				and (_e.get("participants", []) as Array).has("sylvia"):
			hospital_skipped_sylvia_solo_count += 1
	_reset_committed_schedule_for_day_end()
	# Clear pending Angela dates (post-hospital twofriends are not re-routed; see FLOWS §6).
	pending_date_entries = []
	pending_date_entry_index = 0
	pending_date_friend_id = ""

	if day >= 7:
		resolve_day7_ending()
		emit_signal("day_changed", day)
		emit_signal("save_relevant_state_changed")
		_autosave_after_advance()
		return false
	_lifecycle_advance_day()
	_begin_new_day()
	emit_signal("day_changed", day)
	emit_signal("save_relevant_state_changed")
	_autosave_after_advance()
	return true


func advance_day_or_end() -> bool:
	# 1. Record accepted-but-unscheduled invitations before clearing. Solo miss -> one record;
	# missed group -> one source:"group" record per participant (drives next-day group guilt message,
	# CONTRACTS §2 follow-up rule). day = ending day D; guilt appears on D+1.
	var unscheduled: Array = collect_unscheduled_accepted_invitations_for_day_end()
	for u in unscheduled:
		var utype: String = u.get("type", "")
		if utype == "solo":
			missed_invitations.append({"friend_id": u.get("friend_id", ""), "source": "solo", "day": day})
		elif utype == "group":
			for f in u.get("friend_ids", []):
				missed_invitations.append({"friend_id": str(f), "source": "group", "day": day})

	# 2-5. Reset the committed Schedule, pending dates, daily condition marker, daily
	# invitation-response state.
	_reset_committed_schedule_for_day_end()
	pending_date_entries = []
	pending_date_entry_index = 0
	pending_date_friend_id = ""
	condition_effects_today = []
	condition_resolved_day = 0
	contact_choice_state = {}
	daily_opened_contacts = {}

	# 6. Ending marker (Day 7 is terminal: enter ENDING, never Day 8).
	if day >= 7:
		_lifecycle_ensure_ending(
			str(route_context.get("ending_id", "ending.alone")),
			str(route_context.get("epilogue_ending_id", "")))
		emit_signal("day_changed", day)
		emit_signal("save_relevant_state_changed")
		_autosave_after_advance()
		return false

	# 7. Advance day.
	_lifecycle_advance_day()
	_begin_new_day()
	emit_signal("day_changed", day)
	emit_signal("save_relevant_state_changed")
	_autosave_after_advance()
	return true


func _begin_new_day() -> void:
	set_stat(STAT_MOTIVATION, 7)
	minesweeper_rounds_left = 2
	unfinished_minesweeper_result = {}
	minesweeper_app_rounds_finished_today = 0
	minesweeper_money_earned_today = 0
	penalty_points_today = 0
	condition_effects_today = []
	daily_opened_contacts = {}
	daily_group_invitation_generated = false
	daily_group_invitation_pair = []

	# Sequela: previous day had a danger condition not cleared by hospital.
	if condition_streak_days > 0:
		condition_effects_today.append(CONDITION_SEQUELA)
		condition_streak_days = 0

	emit_signal("daily_state_reset")


# ---- Dating queue ----
func prepare_dating_queue(friend_ids: Array[String]) -> void:
	var entries: Array = []
	for fid in friend_ids:
		entries.append(build_date_entry_from_unlock(fid))
	prepare_dating_entries(entries)


func prepare_dating_entries(entries: Array) -> void:
	pending_date_entries = entries.duplicate()
	pending_date_entry_index = 0
	pending_date_advance_day_after_finish = true
	if pending_date_entries.size() > 0:
		pending_date_friend_id = _entry_friend_id(pending_date_entries[0])
	else:
		pending_date_friend_id = ""
	emit_signal("save_relevant_state_changed")


func get_current_pending_date_friend_id() -> String:
	return pending_date_friend_id


func get_current_pending_date_entry() -> Dictionary:
	if pending_date_entry_index >= 0 and pending_date_entry_index < pending_date_entries.size():
		return pending_date_entries[pending_date_entry_index]
	return {}


func apply_dating_challenge_result(entry: Dictionary, result: Dictionary) -> bool:
	var participants: Array = []
	var t: String = entry.get("type", "")
	if t == "solo":
		participants = [entry.get("friend_id", "")]
	elif t == "group":
		participants = entry.get("friend_ids", [])
	# twofriends => [] (Angela absent)

	for p in participants:
		if p == "":
			continue
		change_affection(p, int(result.get("affection_delta", 0)))
		var drs: Dictionary = dating_route_state.get(p, {})
		drs["date_count"] = int(drs.get("date_count", 0)) + 1
		drs["dark_points"] = int(drs.get("dark_points", 0)) + int(result.get("dark_point", 0))
		if bool(result.get("entered_true_path", false)):
			drs["true_path_count"] = int(drs.get("true_path_count", 0)) + 1
		drs["previous_entered_true_path"] = bool(result.get("entered_true_path", false))
		dating_route_state[p] = drs

	# Pair tracking for group AND twofriends.
	if t in ["group", "twofriends"]:
		var fids: Array = entry.get("friend_ids", [])
		if fids.size() >= 2:
			var pkey: String = _sorted_pair_key(fids[0], fids[1])
			var irs: Dictionary = inter_friend_route_state.get(pkey, {})
			irs["date_count"] = int(irs.get("date_count", 0)) + 1
			irs["dark_points"] = int(irs.get("dark_points", 0)) + int(result.get("dark_point", 0))
			inter_friend_route_state[pkey] = irs
		if t == "twofriends":
			change_inter_friend_affection(fids[0], fids[1], int(result.get("affection_delta", 0)))

	emit_signal("friends_changed")
	emit_signal("save_relevant_state_changed")
	return true


func advance_date_queue_or_day() -> bool:
	if pending_date_entry_index < pending_date_entries.size() - 1:
		pending_date_entry_index += 1
		pending_date_friend_id = _entry_friend_id(pending_date_entries[pending_date_entry_index])
		emit_signal("save_relevant_state_changed")
		return true
	# No more entries.
	if pending_date_advance_day_after_finish:
		advance_day_or_end()
	else:
		# Day already advanced (e.g. post-hospital); leave unchanged.
		pass
	return false


func clear_pending_date_state() -> void:
	# Clears stale dating-queue state restored from a save taken mid-queue (CONTRACTS §6
	# REQUIRED GUARD). Called by SaveManager on load unless the saved scene is a dating scene.
	pending_date_entries = []
	pending_date_entry_index = 0
	pending_date_friend_id = ""
	pending_date_advance_day_after_finish = false
	emit_signal("save_relevant_state_changed")


# ---- Flags / save ----
func mark_opening_seen() -> void:
	opening_seen = true
	emit_signal("save_relevant_state_changed")


func mark_tutorial_seen() -> void:
	tutorial_seen = true
	emit_signal("save_relevant_state_changed")


func set_story_flag(key: String, value: Variant) -> void:
	story_flags[key] = value
	emit_signal("save_relevant_state_changed")


func get_story_flag(key: String, default_value: Variant = false) -> Variant:
	return story_flags.get(key, default_value)


func to_save_dict() -> Dictionary:
	var out: Dictionary = {}
	for key in _SAVE_WHITELIST:
		var v = self.get(key)
		if v == null:
			continue
		if v is Dictionary:
			out[key] = v.duplicate()
		elif v is Array:
			out[key] = v.duplicate()
		else:
			out[key] = v
	return out


func apply_save_dict(data: Dictionary) -> Dictionary:
	for key in _SAVE_WHITELIST:
		if not data.has(key):
			continue
		var v = data[key]
		if v == null:
			continue
		if key == "day":
			var saved_day := int(v)
			if saved_day == 8:
				# Legacy Day-8 sentinel migrates to the Day-7 terminal ENDING state.
				var saved_route: Dictionary = data.get("route_context", {}) if data.get("route_context") is Dictionary else {}
				_lifecycle_set_playing_day(7)
				_lifecycle_ensure_ending(
					str(saved_route.get("ending_id", "ending.alone")),
					str(saved_route.get("epilogue_ending_id", "")))
			else:
				_lifecycle_set_playing_day(clampi(saved_day, 1, 7))
		elif key == "minesweeper_round_floor":
			minesweeper_round_floor = clampi(int(v), MINESWEEPER_ROUND_FLOOR_MIN, MINESWEEPER_ROUND_FLOOR_MAX)
		elif key == "minesweeper_rounds_left":
			minesweeper_rounds_left = clampi(int(v), -3, MINESWEEPER_ROUND_CAP)
		elif key in _TYPED_STRING_ARRAY_KEYS:
			var typed: Array[String] = []
			if v is Array:
				for item in v:
					typed.append(str(item))
			self.set(key, typed)
		elif v is Dictionary:
			self.set(key, v.duplicate())
		elif v is Array:
			self.set(key, v.duplicate())
		else:
			self.set(key, v)
	emit_signal("save_relevant_state_changed")
	return {"ok": true}


func get_save_summary() -> Dictionary:
	return {
		"day": day,
		"money": money,
		"coins": coins,
		"ending_id": route_context.get("ending_id", ""),
		"opening_seen": opening_seen,
		"tutorial_seen": tutorial_seen,
	}


# ---- Internal helpers ----
func _apply_effect_ids(effect_ids: Array) -> void:
	var er: Node = get_node_or_null("/root/EffectResolver")
	if er != null and er.has_method("apply_effect_ids"):
		er.apply_effect_ids(effect_ids, "GameState")


func _autosave_after_advance() -> void:
	# Persist progress after a day advance (CONTRACTS §2 Day advancement). Safe if SaveManager is a stub/missing.
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("autosave"):
		sm.autosave()


func _sorted_pair_key(a: String, b: String) -> String:
	var arr: Array = [a, b]
	arr.sort()
	return "%s_%s" % [arr[0], arr[1]]


func _group_pair_contains(friend_id: String) -> bool:
	for pair in _GROUP_INVITATION_PAIRS:
		if friend_id in pair:
			return true
	return false


func _group_scheduled() -> bool:
	for entry in _committed_entries():
		if str(entry.get("action_kind", "")) == "group":
			return true
	return false


func _entry_friend_id(entry: Dictionary) -> String:
	var t: String = entry.get("type", "")
	if t == "solo":
		return entry.get("friend_id", "")
	if t == "group":
		var fids: Array = entry.get("friend_ids", [])
		return fids[0] if fids.size() > 0 else ""
	return ""


# ---- Phase 2R lifecycle facade seams (dwm-p2r.4 Task 3) ----

const _GATE_CONTRACT_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]


func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return {"ok": false, "code": &"invalid_mutation_gate", "message": "gate contract incomplete"}
	for method in _GATE_CONTRACT_METHODS:
		if not gate.has_method(method):
			return {"ok": false, "code": &"invalid_mutation_gate", "message": "missing method: " + method}
	if _mutation_gate != null:
		if gate == _mutation_gate:
			return {"ok": true, "code": &"ok",
				"value": {"gate_instance_id": _mutation_gate.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return {"ok": false, "code": &"mutation_gate_already_configured", "message": ""}
	_mutation_gate = gate
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _mutation_gate.get_instance_id(), "already_configured": false},
		"receipt": {}}


## Reports ONLY the retained gate's instance id, never the gate object. Adapters that must
## prove they hold the same gate GameState holds compare this primitive; there is deliberately
## no public getter that would hand the fence itself to a caller (dwm-p2r.9 Plan 06 Task 2).
func get_mutation_gate_instance_id() -> int:
	if _mutation_gate == null:
		return 0
	return _mutation_gate.get_instance_id()


## Fresh `{board,consequence}` for a run that has never touched Minesweeper: NONE-phase board
## (DesktopBoardState's default-constructed capture) and an empty pending-free consequence bound to
## the given causal-day identity pair (Plan 02 Task 6, dwm-p2r.32).
func _empty_desktop_snapshot(causal_day_instance: String, causal_day_instance_issuer_receipt: Dictionary) -> Dictionary:
	var empty_consequence: Dictionary = _DESKTOP_CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": causal_day_instance,
		"causal_day_instance_issuer_receipt": causal_day_instance_issuer_receipt,
	})
	return {
		"board": _DESKTOP_BOARD_STATE.new().capture(),
		"consequence": (empty_consequence["value"] as Dictionary)["state"],
	}

## `branch_id`/`desktop_timeline_generation`/`causal_day_instance`/`causal_day_instance_issuer_
## receipt` (Plan 02 Task 6, dwm-p2r.32) arrive from SaveManager's own Task-1 issuer/journal
## allocation -- this method never mints or guesses any of them; a New Run constructs v4 directly
## from that durably committed allocation, never through the migration chain.
func prepare_new_run_snapshot_input(run_id: String, branch_id: String, desktop_timeline_generation: int,
		causal_day_instance: String, causal_day_instance_issuer_receipt: Dictionary) -> Dictionary:
	if run_id.is_empty():
		return {"ok": false, "code": &"invalid_run_id", "message": "run_id must be nonempty"}
	if str(_run_lifecycle.to_dict()["run_id"]) == run_id:
		return {"ok": false, "code": &"run_id_reused", "message": run_id}
	var template: Node = load("res://autoload/GameState.gd").new()
	template.reset_game()
	var defaults: Dictionary = template.to_save_dict()
	template.free()
	# Shape the detached Day-1 input to match RunSnapshotSchema.build: gameplay bag
	# (whitelisted fields minus day/contacts/committed_schedule/dating), plus their own fields.
	var gameplay := {"narrative_variables": {}}
	for key in _SAVE_WHITELIST:
		if key in ["day", "contact_message_unlocks", "contact_choice_state", "date_unlocks", "dating_route_state"]:
			continue
		if defaults.has(key):
			gameplay[key] = defaults[key]
	return {"ok": true, "code": &"ok", "value": {"snapshot_input": {
		"lifecycle": {
			"run_id": run_id,
			"day": 1,
			"state": "PLAYING",
			"active_resolution_plan": null,
			"ending_plan": null,
			"branch_id": branch_id,
			"desktop_timeline_generation": desktop_timeline_generation,
			"causal_day_instance": causal_day_instance,
			"causal_day_instance_issuer_receipt": causal_day_instance_issuer_receipt.duplicate(true),
			"restore_provenance": null,
		},
		"gameplay": gameplay,
		"contacts": _CONTACT_INVITATION_STATE.make_defaults(),
		# A new run starts at the canonical EMPTY aggregate with a null fingerprint: only a later
		# logical-day initialization may adopt the current registry fingerprint.
		"committed_schedule": {
			"schema_version": _SCHEDULE_STATE_SCHEMA.SCHEMA_VERSION,
			"day": 1,
			"registry_fingerprint": null,
			"entries": [],
			"commit_receipt": null,
		},
		"desktop": _empty_desktop_snapshot(causal_day_instance, causal_day_instance_issuer_receipt),
		"dating": {},
		"applied_effect_transaction_ids": [],
		"applied_variable_transaction_ids": [],
	}}}


func request_schedule_done(command_id: String) -> Dictionary:
	if _day_resolution_coordinator == null:
		return {"ok": false, "code": &"day_resolution_unconfigured", "message": ""}
	return _day_resolution_coordinator.request_schedule_done(command_id)


func resume_day_resolution() -> Dictionary:
	if _day_resolution_coordinator == null:
		return {"ok": false, "code": &"day_resolution_unconfigured", "message": ""}
	return _day_resolution_coordinator.resume()


func begin_day_resolution_stage() -> Dictionary:
	if _day_resolution_coordinator == null:
		return {"ok": false, "code": &"day_resolution_unconfigured", "message": ""}
	return _day_resolution_coordinator.resume()


func complete_day_resolution_stage(transaction_id: String, receipt: Dictionary) -> Dictionary:
	if _day_resolution_coordinator == null:
		return {"ok": false, "code": &"day_resolution_unconfigured", "message": ""}
	return _day_resolution_coordinator.complete_route_stage(transaction_id, receipt)


var _narrative_checkpoint_port: Object = null


## Installs the day-resolution runtime Bootstrap already constructed and configured
## (Plan 01 Task 6 Step 6.5, dwm-p2r.13).
##
## GameState used to CONSTRUCT the coordinator and the state port itself and keep them in a private
## bag that Bootstrap then reached back into through `get_state_port()`. Ownership now runs one way:
## Bootstrap constructs and retains exactly one of each, configures the coordinator through its sole
## three-owner seam, and passes those four live Objects here as direct arguments.
##
## Before installing, this seam asks the coordinator to CONFIRM the three owners rather than to hand
## any of them back -- `verify_configuration` compares internally and returns only primitives, so no
## Dictionary crossing this boundary ever carries an Object reference. Installation happens once;
## a second attempt with the same coordinator is idempotent and with a different one is refused.
func _install_day_resolution_runtime(state_port: Object, coordinator: Object,
		checkpoint_port: Object, mutation_gate: Object) -> Dictionary:
	if _mutation_gate == null:
		return {"ok": false, "code": &"mutation_gate_not_configured", "message": ""}
	if mutation_gate != _mutation_gate:
		return {"ok": false, "code": &"mutation_gate_identity_mismatch", "message": ""}
	for required: Array in [[state_port, "begin_or_resume"], [coordinator, "verify_configuration"],
			[checkpoint_port, "preview_checkpoint_id"]]:
		var candidate: Object = required[0]
		if candidate == null or not candidate.has_method(str(required[1])):
			return {"ok": false, "code": &"invalid_day_resolution_runtime",
				"message": "a supplied owner is missing " + str(required[1])}
	if _day_resolution_coordinator != null:
		if _day_resolution_coordinator != coordinator:
			return {"ok": false, "code": &"day_resolution_runtime_already_installed", "message": ""}
		return {"ok": true, "code": &"ok", "value": {"installed": true}, "receipt": {}}
	var verified: Dictionary = coordinator.call(&"verify_configuration", state_port,
		checkpoint_port, mutation_gate)
	if not verified.get("ok", false):
		return verified
	if verified.get("value", {}) != {"configured": true}:
		return {"ok": false, "code": &"invalid_day_resolution_runtime",
			"message": "verify_configuration did not return the exact master envelope"}
	_day_resolution_coordinator = coordinator
	return {"ok": true, "code": &"ok", "value": {"installed": true}, "receipt": {}}


## Installs the ONE Bootstrap-constructed, already-configured MinesweeperRoundCoordinator
## (dwm-p2r.9 Plan 06 Task 2). Installation happens once; the same coordinator is idempotent
## and a different one is refused, so no second round authority can exist in the process.
func _install_minesweeper_round_coordinator(coordinator: Object) -> Dictionary:
	if coordinator == null:
		return {"ok": false, "code": &"invalid_minesweeper_coordinator", "message": ""}
	for method in ["configure", "begin_round", "complete_round", "abort_round", "get_active_round"]:
		if not coordinator.has_method(method):
			return {"ok": false, "code": &"invalid_minesweeper_coordinator", "message": "missing " + method}
	if _minesweeper_round_coordinator != null:
		if _minesweeper_round_coordinator != coordinator:
			return {"ok": false, "code": &"minesweeper_coordinator_already_installed", "message": ""}
		return {"ok": true, "code": &"ok", "value": {"installed": true, "already_installed": true}, "receipt": {}}
	_minesweeper_round_coordinator = coordinator
	return {"ok": true, "code": &"ok", "value": {"installed": true, "already_installed": false}, "receipt": {}}


## Shared round entry point. Every caller -- app context and dating context alike -- reaches the
## real coordinator through here; GameState applies no round rule of its own.
func begin_minesweeper_round(request: Dictionary) -> Dictionary:
	if _minesweeper_round_coordinator == null:
		return {"ok": false, "code": &"NOT_CONFIGURED", "message": "no Minesweeper coordinator is installed"}
	return _minesweeper_round_coordinator.call(&"begin_round", request)


func complete_minesweeper_round(round_id: String, result: Dictionary, transaction_id: String) -> Dictionary:
	if _minesweeper_round_coordinator == null:
		return {"ok": false, "code": &"NOT_CONFIGURED", "message": "no Minesweeper coordinator is installed"}
	return _minesweeper_round_coordinator.call(&"complete_round", round_id, result, transaction_id)


func get_active_minesweeper_round() -> Dictionary:
	if _minesweeper_round_coordinator == null:
		return {"ok": false, "code": &"NOT_CONFIGURED", "message": "no Minesweeper coordinator is installed"}
	return _minesweeper_round_coordinator.call(&"get_active_round")


func _lifecycle_advance_day() -> void:
	var snapshot: Dictionary = _run_lifecycle.to_dict()
	_lifecycle_set_playing_day(int(snapshot["day"]) + 1)


func _lifecycle_set_playing_day(target_day: int) -> void:
	var snapshot: Dictionary = _run_lifecycle.to_dict()
	var restored: Dictionary = _run_lifecycle.prepare_restore({
		"run_id": str(snapshot["run_id"]),
		"day": clampi(target_day, 1, 7),
		"state": "PLAYING",
		"active_resolution_plan": null,
		"ending_plan": null,
		# Plan 02 Task 6 (dwm-p2r.32): the desktop-identity pair travels with every lifecycle
		# candidate; this narrow day-only transition preserves it byte-for-byte from the live
		# snapshot rather than replacing or dropping it.
		"branch_id": snapshot["branch_id"],
		"desktop_timeline_generation": snapshot["desktop_timeline_generation"],
		"causal_day_instance": snapshot["causal_day_instance"],
		"causal_day_instance_issuer_receipt": snapshot["causal_day_instance_issuer_receipt"],
		"restore_provenance": snapshot["restore_provenance"],
	})
	if restored.get("ok", false):
		_run_lifecycle.commit_restore(restored["value"]["candidate"])


func request_next_ending_command() -> Dictionary:
	# Facade read (dwm-p2r.7 Task 6): the single next ending command. Reads the live EndingPlan,
	# asks the pure stage machine, and derives the playback ids from run id + role. Start-only:
	# EndingScene advances the stage from its validated completion, never from this query.
	if _run_lifecycle.get_state() != &"ENDING":
		return {"ok": false, "code": &"not_in_ending", "message": "run is not in the ENDING state"}
	var snapshot: Dictionary = _run_lifecycle.to_dict()
	var lifecycle_plan: Dictionary = snapshot["ending_plan"]
	# Adapt the lifecycle plan shape to the DatingEndingRules plan shape.
	var epilogue: String = str(lifecycle_plan.get("epilogue_ending_id", ""))
	var command_result: Dictionary = _DATING_ENDING_RULES.next_playback_command({
		"primary_id": str(lifecycle_plan["ending_id"]),
		"epilogue_id": null if epilogue.is_empty() else epilogue,
		"playback_stage": str(lifecycle_plan["playback_stage"]),
	})
	if not command_result.get("ok", false):
		return command_result
	var command: Dictionary = command_result["value"]
	if str(command["kind"]) != "play_ending":
		return {"ok": true, "code": &"ok", "value": command.duplicate(true)}
	var run_id: String = str(snapshot["run_id"])
	var role: String = str(command["role"])
	return {"ok": true, "code": &"ok", "value": {
		"kind": command["kind"],
		"ending_id": str(command["ending_id"]),
		"playback_context": {
			"playback_id": "%s:%s" % [run_id, role],
			"transaction_id": "%s:%s:complete" % [run_id, role],
			"expected_stage": command["expected_stage"],
			"role": command["role"],
		},
	}}


## The role that plays out of each play_ending stage.
const _ENDING_STAGE_ROLE := {"PRIMARY_PENDING": "primary", "PRIMARY_PLAYED": "epilogue"}

func complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary:
	# Unified facade completion (dwm-p2r.7 Task 6): the live EndingPlan's current command decides
	# what a completion does -- advance a played timeline, record the gallery, or complete the run
	# (complete_run is the next increment). Every transition advances the frozen playback sequence.
	if _run_lifecycle.get_state() != &"ENDING":
		return {"ok": false, "code": &"not_in_ending", "message": "run is not in the ENDING state"}
	var lifecycle_plan: Dictionary = _run_lifecycle.to_dict()["ending_plan"]
	var epilogue: String = str(lifecycle_plan.get("epilogue_ending_id", ""))
	var command_result: Dictionary = _DATING_ENDING_RULES.next_playback_command({
		"primary_id": str(lifecycle_plan["ending_id"]),
		"epilogue_id": null if epilogue.is_empty() else epilogue,
		"playback_stage": str(lifecycle_plan["playback_stage"]),
	})
	if not command_result.get("ok", false):
		return command_result
	var command: Dictionary = command_result["value"]
	if str(command["expected_stage"]) != String(expected_stage):
		return {"ok": false, "code": &"playback_stage_mismatch", "message": "expected %s, current %s" % [String(expected_stage), str(command["expected_stage"])]}
	match str(command["kind"]):
		"play_ending":
			return _complete_play_ending(String(expected_stage), transaction_id, receipt)
		"record_gallery":
			return _complete_record_gallery(String(expected_stage), lifecycle_plan)
		"complete_run":
			return _complete_run()
	return {"ok": false, "code": &"invalid_ending_command", "message": str(command["kind"])}

func _complete_run() -> Dictionary:
	# At GALLERY_RECORDED the run finishes: ENDING -> COMPLETED, then route to the menu. No scene
	# calls RunLifecycle directly. Day stays 7 (terminal); there is no Day 8.
	var result: Dictionary = _run_lifecycle.complete_ending()
	if not result.get("ok", false):
		return result
	emit_signal("save_relevant_state_changed")
	return {"ok": true, "code": &"ok", "value": {"route": "menu"}}

func _complete_play_ending(stage: String, transaction_id: String, receipt: Dictionary) -> Dictionary:
	# EndingScene passes the run-scoped transaction id (run_id:role:complete) and a flat receipt;
	# RunLifecycle keys the stage by ending:<stage> and wants a {value: Dictionary} envelope.
	var run_id: String = str(_run_lifecycle.to_dict()["run_id"])
	if transaction_id != "%s:%s:complete" % [run_id, str(_ENDING_STAGE_ROLE[stage])]:
		return {"ok": false, "code": &"transaction_mismatch", "message": transaction_id}
	var result: Dictionary = _run_lifecycle.complete_ending_playback_stage("ending:" + stage, StringName(stage), {"value": receipt.duplicate(true)})
	if result.get("ok", false):
		emit_signal("save_relevant_state_changed")
	return result

func _complete_record_gallery(stage: String, lifecycle_plan: Dictionary) -> Dictionary:
	# Record the primary then optional epilogue as independent, idempotent ProfileManager
	# transactions (the frozen sequence passes through EPILOGUE_PLAYED even without an epilogue,
	# so a repeat is a no-op via the gallery transaction ledger), then advance the stage.
	var profile: Node = get_node_or_null("/root/ProfileManager")
	if profile == null:
		return {"ok": false, "code": &"profile_unavailable", "message": "ProfileManager autoload is required"}
	var run_id: String = str(_run_lifecycle.to_dict()["run_id"])
	var gallery_receipts: Dictionary = {}
	var primary_id: String = str(lifecycle_plan["ending_id"])
	var primary: Dictionary = profile.unlock_ending(primary_id, "ending:%s:gallery:%s" % [run_id, primary_id])
	if not primary.get("ok", false):
		return {"ok": false, "code": &"profile_ahead_profile_batch_failed", "message": "primary gallery unlock failed", "details": primary}
	gallery_receipts["primary"] = primary["value"]
	var epilogue: String = str(lifecycle_plan.get("epilogue_ending_id", ""))
	if not epilogue.is_empty():
		var epilogue_unlock: Dictionary = profile.unlock_ending(epilogue, "ending:%s:gallery:%s" % [run_id, epilogue])
		if not epilogue_unlock.get("ok", false):
			return {"ok": false, "code": &"profile_ahead_profile_batch_failed", "message": "epilogue gallery unlock failed", "details": epilogue_unlock}
		gallery_receipts["epilogue"] = epilogue_unlock["value"]
	var result: Dictionary = _run_lifecycle.complete_ending_playback_stage("ending:" + stage, StringName(stage), {"value": gallery_receipts})
	if result.get("ok", false):
		emit_signal("save_relevant_state_changed")
	return result


func _lifecycle_ensure_ending(ending_id: String, epilogue_ending_id: String) -> void:
	if _run_lifecycle.get_state() != &"PLAYING":
		return
	if _run_lifecycle.get_day() != 7:
		_lifecycle_set_playing_day(7)
	_run_lifecycle.enter_ending({
		"ending_id": ending_id if not ending_id.is_empty() else "ending.alone",
		"epilogue_ending_id": epilogue_ending_id,
		"source_day": 7,
		"playback_stage": "PRIMARY_PENDING",
		"playback_receipts": {},
	})


# ---- Run restore participant seams (dwm-p2r.5 Task 7) ----
# RunRestoreParticipant delegates capture/apply/rollback/finalize here. These
# are silent: apply/rollback emit no domain signals; only finalize publishes.

func capture_restore_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"gameplay": to_save_dict(),
		"lifecycle": _run_lifecycle.to_dict(),
		"contacts": contacts.duplicate(true),
		# v3 (Plan 01 Task 5): the canonical aggregate is part of the restore transaction, so a
		# later participant failure rolls it back with everything else.
		"committed_schedule": _canonical_committed_schedule(),
		# v4 (Plan 02 Task 6, dwm-p2r.32): the desktop aggregate travels with the same restore
		# transaction, so a later participant failure rolls it back with everything else too.
		"desktop": _desktop_snapshot.duplicate(true),
	}}}


# ---- Atomic effect/variable transactions (dwm-p2r.8, Plan-05 Task 3) ----
# This ledger is DISJOINT from ProfileManager's ending-gallery ledger: it records only
# effect/variable command receipts and never an ending/gallery variant.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _NARRATIVE_VARIABLE_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")

var _command_receipts: Dictionary = {}
var _applied_effect_transaction_ids: Array = []
var _applied_variable_transaction_ids: Array = []
var _narrative_variables: Dictionary = {}


func commit_effect_transaction(transaction_id: String, effect_ids: Array[String], source_id: String) -> Dictionary:
	var guarded := _guard_transaction(&"commit_effect_transaction")
	if not guarded.get("ok", true):
		return guarded
	var normalized := {"kind": "effect_transaction", "transaction_id": transaction_id, "effect_ids": effect_ids.duplicate(true), "source_id": source_id}
	var identity := _transaction_identity(transaction_id, normalized)
	if identity.has("result"):
		return identity["result"]
	var resolver := get_node_or_null("/root/EffectResolver")
	if resolver == null or not resolver.has_method("resolve_effects"):
		return _transaction_failure(&"effect_resolver_unavailable", "EffectResolver is unavailable")
	var resolved: Dictionary = resolver.resolve_effects(effect_ids)
	if not resolved.get("ok", false):
		return resolved
	var descriptors: Array = (resolved["value"] as Dictionary)["descriptors"]
	var backup: Dictionary = capture_live_run_state()["value"]["backup"]
	var applied: Dictionary = resolver.apply_resolved_descriptors(self, descriptors)
	if not applied.get("ok", false):
		restore_live_run_state(backup)
		return applied
	return _record_transaction_receipt(transaction_id, str(identity["fingerprint"]), &"effect_transaction", source_id, _applied_effect_transaction_ids)


func commit_variable_transaction(transaction_id: String, variable_id: String, value: Variant, source_id: String) -> Dictionary:
	var guarded := _guard_transaction(&"commit_variable_transaction")
	if not guarded.get("ok", true):
		return guarded
	var normalized := {"kind": "variable_transaction", "transaction_id": transaction_id, "variable_id": variable_id, "value": value, "source_id": source_id}
	var identity := _transaction_identity(transaction_id, normalized)
	if identity.has("result"):
		return identity["result"]
	if variable_id not in _NARRATIVE_VARIABLE_SCHEMA._registered_narrative_variables():
		return _transaction_failure(&"unknown_variable_id", variable_id)
	var backup: Dictionary = capture_live_run_state()["value"]["backup"]
	_narrative_variables[variable_id] = value
	var recorded := _record_transaction_receipt(transaction_id, str(identity["fingerprint"]), &"variable_transaction", source_id, _applied_variable_transaction_ids)
	if not recorded.get("ok", false):
		restore_live_run_state(backup)
	return recorded


func _guard_transaction(owner_id: StringName) -> Dictionary:
	# The shared gate is applied as the method's FIRST operation, before any normalization,
	# ledger read, validation, snapshot capture, or port/provider call.
	if _mutation_gate == null:
		return {"ok": true}
	var guarded: Dictionary = _mutation_gate.call(&"guard_external", owner_id)
	if typeof(guarded) == TYPE_DICTIONARY and not guarded.get("ok", true):
		return guarded
	return {"ok": true}


func _transaction_identity(transaction_id: String, normalized: Dictionary) -> Dictionary:
	if transaction_id.is_empty():
		return {"result": _transaction_failure(&"invalid_transaction_id", "transaction_id must be nonempty")}
	var emitted: Dictionary = _CANONICAL_JSON.stringify(normalized)
	if not emitted.get("ok", false):
		return {"result": _transaction_failure(&"invalid_transaction_request", "request is not canonically serializable")}
	var fingerprint := str(emitted["value"]).sha256_text()
	if _command_receipts.has(transaction_id):
		var stored: Dictionary = _command_receipts[transaction_id]
		if str(stored["request_fingerprint"]) == fingerprint:
			return {"result": {"ok": true, "code": &"ok", "value": {"duplicate": true}, "receipt": stored.duplicate(true)}}
		return {"result": _transaction_failure(&"duplicate_transaction_conflict", transaction_id)}
	return {"fingerprint": fingerprint}


func _record_transaction_receipt(transaction_id: String, fingerprint: String, kind: StringName, source_id: String, applied_ids: Array) -> Dictionary:
	var receipt := {
		"transaction_id": transaction_id,
		"request_fingerprint": fingerprint,
		"kind": kind,
		"source_id": source_id,
	}
	_command_receipts[transaction_id] = receipt.duplicate(true)
	if transaction_id not in applied_ids:
		applied_ids.append(transaction_id)
	emit_signal("save_relevant_state_changed")
	return {"ok": true, "code": &"ok", "value": {"duplicate": false}, "receipt": receipt.duplicate(true)}


static func _transaction_failure(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}


# ---- Detached run candidate seam (Plan-05 Task 3 Step 3.2) ----

func prepare_run_candidate(snapshot: Dictionary) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.is_empty():
		return _transaction_failure(&"invalid_run_candidate", "a snapshot input is required")
	return {"ok": true, "code": &"ok", "value": {"candidate": snapshot.duplicate(true)}, "receipt": {}}


func capture_live_run_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"gameplay": to_save_dict(),
		"contacts": contacts.duplicate(true),
		"command_receipts": _command_receipts.duplicate(true),
		"applied_effect_transaction_ids": _applied_effect_transaction_ids.duplicate(true),
		"applied_variable_transaction_ids": _applied_variable_transaction_ids.duplicate(true),
		"narrative_variables": _narrative_variables.duplicate(true),
	}}}


func commit_run_candidate(candidate: Dictionary) -> Dictionary:
	if typeof(candidate) != TYPE_DICTIONARY or candidate.is_empty():
		return _transaction_failure(&"invalid_run_candidate", "candidate was not issued by this seam")
	return {"ok": true, "code": &"ok", "value": {"committed": true}, "receipt": {}}


func restore_live_run_state(backup: Dictionary) -> Dictionary:
	var source: Variant = backup.get("backup", backup)
	if typeof(source) != TYPE_DICTIONARY or not (source as Dictionary).has("command_receipts"):
		return _transaction_failure(&"invalid_run_backup", "backup was not issued by capture_live_run_state")
	var detached: Dictionary = source as Dictionary
	if typeof(detached.get("gameplay")) == TYPE_DICTIONARY:
		apply_save_dict(detached["gameplay"])
	if typeof(detached.get("contacts")) == TYPE_DICTIONARY:
		contacts = (detached["contacts"] as Dictionary).duplicate(true)
	_command_receipts = (detached["command_receipts"] as Dictionary).duplicate(true)
	_applied_effect_transaction_ids = (detached["applied_effect_transaction_ids"] as Array).duplicate(true)
	_applied_variable_transaction_ids = (detached["applied_variable_transaction_ids"] as Array).duplicate(true)
	_narrative_variables = (detached["narrative_variables"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


## Pure read seam for the shared narrative checkpoint adapter (dwm-p2r.8, Plan-05 Task 2).
## Returns the complete detached CURRENT RunSnapshot input; performs no mutation, checkpoint,
## signal, or disk access. Task 3 extends this same capture with its live transaction fields.
func capture_run_snapshot_input() -> Dictionary:
	var current: Dictionary = to_save_dict()
	var gameplay := {"narrative_variables": _narrative_variables.duplicate(true)}
	for key in _SAVE_WHITELIST:
		if key in ["day", "contact_message_unlocks", "contact_choice_state", "date_unlocks", "dating_route_state"]:
			continue
		if current.has(key):
			gameplay[key] = current[key]
	return {
		"lifecycle": _run_lifecycle.to_dict(),
		"gameplay": gameplay,
		"contacts": contacts.duplicate(true),
		"committed_schedule": _canonical_committed_schedule(),
		"desktop": _desktop_snapshot.duplicate(true),
		"dating": current.get("dating_route_state", {}).duplicate(true) if typeof(current.get("dating_route_state")) == TYPE_DICTIONARY else {},
		"applied_effect_transaction_ids": _applied_effect_transaction_ids.duplicate(true),
		"applied_variable_transaction_ids": _applied_variable_transaction_ids.duplicate(true),
		"command_receipts": _command_receipts.duplicate(true),
	}


## Accepts the ONE shared SaveManagerNarrativeCheckpointPort instance Bootstrap also injects into
## DialogicBridge; idempotent for the same instance, rejects any other.
func configure_narrative_checkpoint_port(port: Object) -> Dictionary:
	if port == null:
		return {"ok": false, "code": &"invalid_narrative_checkpoint_port", "message": ""}
	for method in ["commit_current_boundary", "preview_checkpoint_id", "capture", "prepare_candidate", "commit", "rollback"]:
		if not port.has_method(method):
			return {"ok": false, "code": &"invalid_narrative_checkpoint_port", "message": "missing " + method}
	if _narrative_checkpoint_port != null and _narrative_checkpoint_port.get_instance_id() != port.get_instance_id():
		return {"ok": false, "code": &"narrative_checkpoint_port_already_configured", "message": ""}
	var already := _narrative_checkpoint_port != null
	_narrative_checkpoint_port = port
	return {"ok": true, "code": &"ok", "value": {"port_instance_id": port.get_instance_id(), "already_configured": already}, "receipt": {}}


func apply_restore_silent(plan: Dictionary) -> Dictionary:
	var snapshot: Variant = plan.get("snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_run_plan", "message": "run plan requires a snapshot"}
	return _apply_run_snapshot_silent(snapshot as Dictionary)


func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	var source: Variant = backup.get("backup", backup)
	if typeof(source) != TYPE_DICTIONARY or typeof((source as Dictionary).get("gameplay")) != TYPE_DICTIONARY \
			or typeof((source as Dictionary).get("lifecycle")) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_run_backup", "message": "run backup requires gameplay and lifecycle"}
	var restored: Dictionary = _run_lifecycle.prepare_restore((source as Dictionary)["lifecycle"])
	if not restored.get("ok", false):
		return restored
	# Validate the aggregate BEFORE any mutation: a rollback must not leave the owner half-restored.
	var committed_backup: Variant = (source as Dictionary).get("committed_schedule")
	var validated_backup: Dictionary = {}
	if typeof(committed_backup) == TYPE_DICTIONARY:
		validated_backup = _SCHEDULE_STATE_SCHEMA.validate_aggregate(committed_backup)
		if not validated_backup.get("ok", false):
			return validated_backup
	var desktop_backup: Variant = (source as Dictionary).get("desktop")
	if typeof(desktop_backup) == TYPE_DICTIONARY:
		var desktop_error := _RUN_SNAPSHOT_SCHEMA_DESKTOP._validate_desktop(desktop_backup)
		if desktop_error != "":
			return {"ok": false, "code": &"invalid_run_backup", "message": desktop_error}
	_run_lifecycle.commit_restore(restored["value"]["candidate"])
	_apply_gameplay_silent((source as Dictionary)["gameplay"])
	_restore_contacts_section((source as Dictionary).get("contacts"))
	if not validated_backup.is_empty():
		_committed_schedule = (validated_backup["value"] as Dictionary)["committed_schedule"]
	if typeof(desktop_backup) == TYPE_DICTIONARY:
		_desktop_snapshot = (desktop_backup as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok"}


func _restore_contacts_section(saved: Variant) -> void:
	# The contacts section restores only when a real stateless bag is present; an
	# empty/legacy {} section leaves the reset defaults intact.
	if typeof(saved) == TYPE_DICTIONARY and (saved as Dictionary).has("messages"):
		contacts = (saved as Dictionary).duplicate(true)


func finalize_restore() -> Dictionary:
	emit_signal("save_relevant_state_changed")
	return {"ok": true, "code": &"ok"}


## Task 6 Phase C2 (dwm-p2r.32): the second, identity-only step of a restore-with-remap (see
## RunRestoreParticipant.apply_continuation_remap()'s doc). Called by SaveManager immediately after
## the "run" participant's ordinary apply_silent() above has installed this restore's day/state/plan;
## swaps in the durably-allocated new branch/generation/causal-day identity via RunLifecycle's own
## already-tested prepare_continuation_remap()/commit_continuation_remap() pair. Silent: no signal.
func apply_continuation_remap_silent(restore_transaction_id: String, identity_allocation_bundle: Dictionary) -> Dictionary:
	var prepared: Dictionary = _run_lifecycle.prepare_continuation_remap(restore_transaction_id, identity_allocation_bundle)
	if not prepared.get("ok", false):
		return prepared
	return _run_lifecycle.commit_continuation_remap((prepared["value"] as Dictionary)["candidate"])


func _apply_run_snapshot_silent(snapshot: Dictionary) -> Dictionary:
	if typeof(snapshot.get("lifecycle")) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_run_plan", "message": "snapshot.lifecycle is required"}
	var restored: Dictionary = _run_lifecycle.prepare_restore(snapshot["lifecycle"])
	if not restored.get("ok", false):
		return restored
	# v3 (Plan 01 Task 5): every restored aggregate is revalidated against the saved bytes BEFORE a
	# single field is written, so an invalid committed Schedule aborts with the owner untouched. The
	# saved fingerprint is honoured as-is; a caller's CURRENT registry record is never substituted.
	var committed: Variant = snapshot.get("committed_schedule")
	var validated_committed: Dictionary = {}
	if typeof(committed) == TYPE_DICTIONARY:
		validated_committed = _SCHEDULE_STATE_SCHEMA.validate_aggregate(committed)
		if not validated_committed.get("ok", false):
			return validated_committed
	var desktop: Variant = snapshot.get("desktop")
	if typeof(desktop) == TYPE_DICTIONARY:
		var desktop_error := _RUN_SNAPSHOT_SCHEMA_DESKTOP._validate_desktop(desktop)
		if desktop_error != "":
			return {"ok": false, "code": &"invalid_run_plan", "message": desktop_error}
	_run_lifecycle.commit_restore(restored["value"]["candidate"])
	if typeof(snapshot.get("gameplay")) == TYPE_DICTIONARY:
		_apply_gameplay_silent(snapshot["gameplay"])
	_restore_contacts_section(snapshot.get("contacts"))
	if not validated_committed.is_empty():
		_committed_schedule = (validated_committed["value"] as Dictionary)["committed_schedule"]
	if typeof(desktop) == TYPE_DICTIONARY:
		_desktop_snapshot = (desktop as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok"}


# ---- Committed-Schedule facade delegation seams (Plan 01 Task 4, dwm-p2r.13) ----
# These five seams are DELEGATION ONLY, never a second validator: they cover current motivation, the
# canonical top-level committed_schedule, and the narrow precondition fingerprint that binds them.
# GameStateScheduleCommitPort owns the public transaction interface, the registry/issuer/source law
# and the at-most-once publication boundary. Nothing here reads or writes the provisional Schedule
# transport, and none of these seams emits except the single declared publication signal.

const _SCHEDULE_STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

const _SCHEDULE_COMMIT_CANDIDATE_KEYS: Array[String] = [
	"before_fingerprint", "committed_schedule", "motivation",
]
const _SCHEDULE_COMMIT_BACKUP_KEYS: Array[String] = ["committed_schedule", "motivation"]
const _SCHEDULE_PUBLICATION_KEYS: Array[String] = ["committed_schedule", "schedule_commit_receipt"]

## Run-scoped canonical aggregate. It is deliberately absent from _SAVE_WHITELIST: Task 5 owns its
## v3 persistence and migration boundary.
var _committed_schedule: Dictionary = {}


## Task 3 (Amendment Plan 03, dwm-oyo.3, plan line 364): the ONE read-only Schedule-warning
## fact capture. Success is the master envelope with exact value={state}, receipt={}, where
## state is {run_id, branch_id, desktop_timeline_generation, causal_day_instance, day,
## eligible_unread_date_message_ids, accepted_date_action_ids, next_app_round_ordinal,
## base_opportunity_remaining, motivation}. Both ID arrays are sorted, unique, detached
## canonical facts derived from persisted GameState/Contacts state -- never from action-ID
## parsing, scenes, or caller-supplied values. Every helper below is underscore-private by
## design: this method is the single public entry the frozen surface walk counts.
func capture_schedule_warning_state() -> Dictionary:
	var identity: Dictionary = _run_lifecycle.get_desktop_identity_context()
	var next_ordinal: Variant = _warning_next_app_round_ordinal()
	return {"ok": true, "code": &"ok", "value": {"state": {
		"run_id": str(identity["run_id"]),
		"branch_id": str(identity["branch_id"]),
		"desktop_timeline_generation": int(identity["desktop_timeline_generation"]),
		"causal_day_instance": str(identity["causal_day_instance"]),
		"day": int(day),
		"eligible_unread_date_message_ids": _warning_unread_date_message_ids(),
		"accepted_date_action_ids": _warning_accepted_date_action_ids(),
		"next_app_round_ordinal": next_ordinal,
		"base_opportunity_remaining": next_ordinal != null and int(next_ordinal) <= 2,
		"motivation": int(get_stat(STAT_MOTIVATION)),
	}}, "receipt": {}}


## 1..5 | null, null only after opportunity exhaustion: the next app-round ordinal is the
## count of rounds finished today plus one, and the opportunity is exhausted once no round
## can be exposed at all (five finished, or the daily round budget is spent to the floor).
func _warning_next_app_round_ordinal() -> Variant:
	var next_ordinal: int = int(minesweeper_app_rounds_finished_today) + 1
	if next_ordinal > 5 or not has_minesweeper_app_round_available():
		return null
	return next_ordinal


## Visible unread (above the friend's read watermark) date-enabling offer messages whose
## target day is the CURRENT day. This deliberately DIVERGES from get_unread_count(),
## which counts every unread message with target_day <= day: only a current-day offer
## can enable a date entry in the current day's Schedule view, so past-day unread
## messages are excluded here on purpose.
func _warning_unread_date_message_ids() -> Array:
	var ids: Dictionary = {}
	var current_day: int = int(day)
	var messages: Dictionary = contacts.get("messages", {})
	var watermarks: Dictionary = contacts.get("read_watermarks", {})
	for friend_id: String in messages:
		var watermark: int = int(watermarks.get(friend_id, 0))
		for raw: Variant in messages.get(friend_id, []) as Array:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var record := raw as Dictionary
			if str(record.get("visibility", "")) != "visible":
				continue
			if int(record.get("sequence", 0)) <= watermark:
				continue
			if int(record.get("target_day", -1)) != current_day:
				continue
			if str(record.get("type", "")) not in ["solo_offer", "group_offer"]:
				continue
			var message_id := str(record.get("message_id", ""))
			if not message_id.is_empty():
				ids[message_id] = true
	var sorted_ids: Array = ids.keys()
	sorted_ids.sort()
	return sorted_ids


## Valid, nonsuperseded current-day Contacts acceptances: solo actions in the ACCEPTED
## state for the current day, plus the group action when it is ACCEPTED for the current
## day. Any superseded or closed state is simply not ACCEPTED.
func _warning_accepted_date_action_ids() -> Array:
	var ids: Dictionary = {}
	var current_day: int = int(day)
	var solo_actions: Dictionary = contacts.get("solo_actions", {})
	for action_id: String in solo_actions:
		var action: Dictionary = solo_actions[action_id]
		if str(action.get("state", "")) == "ACCEPTED" \
				and int(action.get("day", -1)) == current_day:
			ids[str(action_id)] = true
	var group: Dictionary = contacts.get("group_action", {})
	if str(group.get("state", "")) == "ACCEPTED" \
			and typeof(group.get("day")) == TYPE_INT \
			and int(group.get("day")) == current_day:
		var group_id := str(group.get("action_id", ""))
		if not group_id.is_empty():
			ids[group_id] = true
	var sorted_ids: Array = ids.keys()
	sorted_ids.sort()
	return sorted_ids


func capture_schedule_commit_state() -> Dictionary:
	var current := _canonical_committed_schedule()
	var motivation := int(stats.get(STAT_MOTIVATION, 0))
	return {"ok": true, "code": &"ok", "value": {
		"before_fingerprint": _schedule_commit_fingerprint(motivation, current),
		"motivation": motivation,
		"committed_schedule": current,
	}, "receipt": {}}


func prepare_schedule_commit_candidate(committed: Dictionary, motivation_charged: int) -> Dictionary:
	if typeof(committed) != TYPE_DICTIONARY or committed.is_empty():
		return _transaction_failure(&"invalid_schedule_candidate", "a canonical aggregate is required")
	if motivation_charged < 0:
		return _transaction_failure(&"invalid_schedule_motivation_charge", "the charge is nonnegative")
	var validated: Dictionary = _SCHEDULE_STATE_SCHEMA.validate_aggregate(committed)
	if not validated.get("ok", false):
		return validated
	var motivation := int(stats.get(STAT_MOTIVATION, 0))
	if motivation < motivation_charged:
		return _transaction_failure(&"insufficient_motivation",
			"the owner cannot pay %d motivation" % motivation_charged)
	var current := _canonical_committed_schedule()
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"before_fingerprint": _schedule_commit_fingerprint(motivation, current),
		"motivation": motivation - motivation_charged,
		"committed_schedule": (validated["value"] as Dictionary)["committed_schedule"],
	}}, "receipt": {}}


## Silent: installs exactly motivation and committed_schedule, and emits nothing.
func commit_schedule_commit_candidate(candidate: Dictionary) -> Dictionary:
	var shape := _schedule_member_error(candidate, _SCHEDULE_COMMIT_CANDIDATE_KEYS,
		&"invalid_schedule_candidate")
	if not shape.is_empty():
		return shape
	var motivation_error := _schedule_motivation_error(candidate["motivation"])
	if not motivation_error.is_empty():
		return motivation_error
	var validated: Dictionary = _SCHEDULE_STATE_SCHEMA.validate_aggregate(candidate["committed_schedule"])
	if not validated.get("ok", false):
		return validated
	var current := _canonical_committed_schedule()
	var motivation := int(stats.get(STAT_MOTIVATION, 0))
	if str(candidate["before_fingerprint"]) != _schedule_commit_fingerprint(motivation, current):
		return _transaction_failure(&"schedule_commit_state_stale",
			"the candidate was prepared against different owner state")
	stats[STAT_MOTIVATION] = int(candidate["motivation"])
	_committed_schedule = (validated["value"] as Dictionary)["committed_schedule"]
	return {"ok": true, "code": &"ok",
		"value": {"committed_schedule": _committed_schedule.duplicate(true)}, "receipt": {}}


## Restores exactly the two captured fields; every other owner field, including a concurrent
## unrelated Contacts or settings change, is left untouched.
func rollback_schedule_commit_state(backup: Dictionary) -> Dictionary:
	var shape := _schedule_member_error(backup, _SCHEDULE_COMMIT_BACKUP_KEYS,
		&"invalid_schedule_backup")
	if not shape.is_empty():
		return shape
	var motivation_error := _schedule_motivation_error(backup["motivation"])
	if not motivation_error.is_empty():
		return motivation_error
	var validated: Dictionary = _SCHEDULE_STATE_SCHEMA.validate_aggregate(backup["committed_schedule"])
	if not validated.get("ok", false):
		return validated
	stats[STAT_MOTIVATION] = int(backup["motivation"])
	_committed_schedule = (validated["value"] as Dictionary)["committed_schedule"]
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


## Emits the one declared committed-Schedule signal for a publication the owner actually holds. The
## port calls this only after its ledger has durably recorded a FIRST delivery.
func publish_schedule_commit(publication: Dictionary) -> Dictionary:
	var shape := _schedule_member_error(publication, _SCHEDULE_PUBLICATION_KEYS,
		&"invalid_schedule_publication")
	if not shape.is_empty():
		return shape
	var current := _canonical_committed_schedule()
	if publication["committed_schedule"] != current:
		return _transaction_failure(&"schedule_publication_state_mismatch",
			"the publication is not the owner's current canonical state")
	var receipt: Variant = current["commit_receipt"]
	if typeof(receipt) != TYPE_DICTIONARY or receipt != publication["schedule_commit_receipt"]:
		return _transaction_failure(&"schedule_publication_state_mismatch",
			"the publication receipt is not the committed aggregate's own receipt")
	committed_schedule_published.emit({
		"committed_schedule": current.duplicate(true),
		"schedule_commit_receipt": (receipt as Dictionary).duplicate(true),
	})
	return {"ok": true, "code": &"ok", "value": {"published": true},
		"receipt": (receipt as Dictionary).duplicate(true)}


func _canonical_committed_schedule() -> Dictionary:
	# The committed aggregate is DAY-SCOPED: it describes the Schedule committed for one logical
	# day. An owner that has not committed yet -- or whose stored aggregate belongs to an earlier
	# day, because the day has since advanced -- exposes the canonical empty aggregate for the
	# CURRENT day. Projecting the live day here is what keeps a stale day from ever reaching a
	# snapshot, no matter which path advanced it, so the v3 schema's day equality holds without
	# every caller remembering to reset.
	#
	# This is not data loss: the previous day's committed Schedule was already consumed by that
	# day's resolution, and the durable record of it lives in the publication ledger and the saved
	# snapshot for that day.
	#
	# KNOWN LIMIT, handed to Task 6 rather than papered over: the two day-end owners below reset
	# `_committed_schedule` outright, but the DayResolutionCoordinator's increment-day stage advances
	# the lifecycle without clearing it, so on that path a stale aggregate is MASKED here rather than
	# cleared. If that stage were rolled back to the earlier day, the consumed aggregate would become
	# visible again. `DayResolutionCoordinator.reset_day_scope` is still a stub receipt; Task 6 owns
	# making it a real day-scope reset (its Files list owns that coordinator and this port).
	#
	# The fingerprint stays null here: only a later logical-day initialization may adopt a current
	# registry fingerprint, and this seam never loads a registry.
	if _committed_schedule.is_empty() or int(_committed_schedule.get("day", -1)) != day:
		return {
			"schema_version": _SCHEDULE_STATE_SCHEMA.SCHEMA_VERSION,
			"day": day,
			"registry_fingerprint": null,
			"entries": [],
			"commit_receipt": null,
		}
	return _committed_schedule.duplicate(true)


func _schedule_commit_fingerprint(motivation: int, committed: Dictionary) -> String:
	var hashed: Dictionary = _SCHEDULE_STATE_SCHEMA.canonical_sha256({
		"committed_schedule": committed, "motivation": motivation,
	})
	if not hashed.get("ok", false):
		return ""
	return str((hashed["value"] as Dictionary)["sha256"])


func _schedule_member_error(value: Variant, expected: Array[String], code: StringName) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _transaction_failure(code, "a dictionary is required")
	var keys: Array = (value as Dictionary).keys()
	keys.sort()
	if keys != expected:
		return _transaction_failure(code, "the member set is exactly " + str(expected))
	return {}


func _schedule_motivation_error(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_INT:
		return _transaction_failure(&"invalid_schedule_motivation_charge",
			"motivation must be a strict int")
	if int(value) < _stat_min(STAT_MOTIVATION) or int(value) > _stat_max(STAT_MOTIVATION):
		return _transaction_failure(&"invalid_schedule_motivation_charge",
			"motivation must stay inside its declared range")
	return {}


func _apply_gameplay_silent(gameplay: Dictionary) -> void:
	# Apply only whitelisted gameplay fields; `day` is owned by the lifecycle and
	# is intentionally absent from the gameplay bag, so it is never touched here.
	for key in _SAVE_WHITELIST:
		if key == "day" or not gameplay.has(key):
			continue
		var v = gameplay[key]
		if v == null:
			continue
		if key in _TYPED_STRING_ARRAY_KEYS:
			var typed: Array[String] = []
			if v is Array:
				for item in v:
					typed.append(str(item))
			self.set(key, typed)
		elif v is Dictionary:
			self.set(key, v.duplicate())
		elif v is Array:
			self.set(key, v.duplicate())
		else:
			self.set(key, v)
