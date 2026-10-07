extends Node

# GameState autoload — owns all mutable runtime state for the prototype.
# Authority: prompt_docs/INDEX.md (runtime ownership, dating, persistence, and narrative
# requirement packets). No human-facing prose; machine-precise, contradiction-free.
#
# The fixed Contacts generation calendar is owned by SevenDayCalendar and queried here without a
# second mutable or literal copy.
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
const AFFECTION_MIN := -4
const AFFECTION_MAX := 10

const _SEVEN_DAY_CALENDAR := preload("res://scripts/domain/contact/SevenDayCalendar.gd")
const _GROUP_INVITATION_PAIRS := [["priscilla", "lavinia"]]
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
	"pending_date_advance_day_after_finish", "story_flags",
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
const _ORDINARY_CORRESPONDENCE := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const _DAY7_FOLLOWUPS := preload("res://scripts/domain/contact/Day7FollowupState.gd")
const _DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")
const _PROVISIONAL_RELATIONSHIP_RULES := preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd")
const _SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

var _run_lifecycle: RefCounted = _RUN_LIFECYCLE_SCRIPT.new()
# Transient installation evidence, never part of a player snapshot.
var _run_configuration_installed := false
# Process-local lifetime, independent of candidate apply and compensating rollback.
var _live_session_generation := 0
var _live_session_active := false
var _live_session_run_id := ""
var _live_session_activation_ticket: Dictionary = {}
var _retired_live_session_handle: Dictionary = {}
var _retired_live_session_generation := -1

var _mutation_gate: Object = null
var _identity_issuer: Object = null
## v4 desktop aggregate (Plan 02 Task 6, dwm-p2r.32): `{board,consequence}`, held as plain detached
## Dictionaries rather than live DesktopBoardState/DesktopConsequenceState objects. Production
## gameplay wiring of those state machines into GameState is Task 9's job (per GameStateDesktop
## BoardPort's own class doc); this field exists only so a v4 snapshot always has a schema-valid
## `desktop` member to serialize, defaulting to the empty NONE-board/no-pending-consequence shape
## and overwritten wholesale only by restore.
var _desktop_snapshot: Dictionary = {}
var _desktop_snapshot_provider := Callable()
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

var story_flags: Dictionary
var route_context: Dictionary
func _ready() -> void:
	pass


# ---- Lifecycle / stats / money / coins ----
func reset_game() -> void:
	if _live_session_generation > 0: _invalidate_live_session()
	_run_configuration_installed = false
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
		placeholder_identity_allocation_receipt, false)
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
			"relationship_state": "friend", "progression_event_ids": [], "provisional_receipts": {},
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
	return _SEVEN_DAY_CALENDAR.is_solo_day(friend_id, d)


func is_group_invitation_day(target_day: int = -1) -> bool:
	var d: int = target_day if target_day >= 0 else day
	return _SEVEN_DAY_CALENDAR.is_group_day(d)


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


## Uses the same pure preparation as commit so UI content can be checked before any read or
## acceptance mutation. The authentic issuer proof is required even for this detached candidate.
func preview_open_contact(friend_id: String, command_id: String, command_issuer_receipt: Dictionary) -> Dictionary:
	var day7_admitted := require_day7_presentations_complete()
	if not day7_admitted.get("ok", false): return day7_admitted
	var verified := _verify_contact_command(command_id, command_issuer_receipt)
	if not verified.get("ok", false):
		return verified
	var action_id := _contact_action_id(friend_id)
	var record := _schedule_action_record(action_id)
	var care_ready: bool = friend_id == "sylvia" and (not _CONTACT_INVITATION_STATE.get_pending_sylvia_care(contacts, day).is_empty()
		or (contacts.transaction_receipts.get(command_id, {}) as Dictionary).get("kind") == "open_sylvia_care")
	if record.is_empty() and not care_ready:
		return _transaction_failure(&"contact_offer_absent", action_id)
	return _CONTACT_INVITATION_STATE.prepare_open_contact(
		contacts, friend_id, day, command_id, command_issuer_receipt,
		_identity_issuer, record)


## Ordinary correspondence uses the existing Contacts bag and full Run checkpoint.
func preview_ordinary_reply(friend_id: String, reply_id: String, locale: String,
		command_id: String, command_issuer_receipt: Dictionary) -> Dictionary:
	var session: Dictionary = capture_live_session()
	var admitted: Dictionary = validate_live_session(session.value)
	if not admitted.get("ok", false): return admitted
	if _run_lifecycle.get_state() != &"PLAYING" or day >= 7:
		return _transaction_failure(&"ordinary_reply_unavailable", "")
	var verified := _verify_contact_command(command_id, command_issuer_receipt)
	if not verified.get("ok", false): return verified
	var definition: Dictionary = _ORDINARY_CORRESPONDENCE.reply_definition(reply_id, locale)
	if not definition.get("ok", false): return definition
	if definition.value.friend_id != friend_id or int(definition.value.day) != day:
		return _transaction_failure(&"ordinary_reply_source_mismatch", "")
	if _frozen_contacts_contexts_enabled:
		var frozen := ensure_contact_presentation_contexts(friend_id)
		if not frozen.ok: return frozen
	var line := {"view_token": command_id, "line_id": definition.value.line_id, "text": definition.value.text}
	var prepared: Dictionary = _ORDINARY_CORRESPONDENCE.prepare_reply(contacts, day, reply_id,
		locale, command_id, command_issuer_receipt, line)
	if not prepared.get("ok", false): return prepared
	var hashed: Dictionary = _CANONICAL_JSON.stringify(contacts)
	if not hashed.get("ok", false): return hashed
	prepared.value["command"] = {"command_id": command_id,
		"command_issuer_receipt": command_issuer_receipt.duplicate(true),
		"live_session": session.value.duplicate(true), "source_contacts_sha256": str(hashed.value).sha256_text(),
		"source_day": day, "friend_id": friend_id, "reply_id": reply_id, "locale": locale,
		"rendered_line": line.duplicate(true)}
	return prepared

func commit_ordinary_reply(command: Dictionary, rendered_line: Dictionary) -> Dictionary:
	if not _ordinary_command_has_keys(command, ["command_id", "command_issuer_receipt", "live_session",
		"source_contacts_sha256", "source_day", "friend_id", "reply_id", "locale", "rendered_line"]) \
			or typeof(command.source_day) != TYPE_INT or not command.rendered_line is Dictionary \
			or not command.friend_id is String or not command.reply_id is String or not command.locale is String:
		return _transaction_failure(&"invalid_ordinary_command", "")
	var admitted := _admit_ordinary_command(command)
	if not admitted.get("ok", false): return admitted
	if day != command.source_day or day >= 7 or rendered_line != command.rendered_line:
		return _transaction_failure(&"ordinary_reply_source_mismatch", "")
	var definition: Dictionary = _ORDINARY_CORRESPONDENCE.reply_definition(command.reply_id, command.locale)
	if not definition.get("ok", false): return definition
	if definition.value.friend_id != command.friend_id:
		return _transaction_failure(&"ordinary_reply_source_mismatch", "")
	var prepared: Dictionary = _ORDINARY_CORRESPONDENCE.prepare_reply(contacts, day, command.reply_id,
		command.locale, command.command_id, command.command_issuer_receipt, rendered_line)
	if not prepared.get("ok", false): return prepared
	return _commit_ordinary_candidate(prepared, command.friend_id, command.command_id)

func get_pending_ordinary_echoes() -> Array[Dictionary]:
	return _ORDINARY_CORRESPONDENCE.pending_echoes_oldest_first(contacts)

func commit_ordinary_echo(command: Dictionary, presentation_receipt: Dictionary) -> Dictionary:
	if not _ordinary_command_has_keys(command, ["command_id", "command_issuer_receipt", "live_session",
		"source_contacts_sha256", "echo_id", "presentation_atom_id"]) \
			or not command.echo_id is String or not command.presentation_atom_id is String:
		return _transaction_failure(&"invalid_ordinary_command", "")
	var admitted := _admit_ordinary_command(command)
	if not admitted.get("ok", false): return admitted
	if day != 7: return _transaction_failure(&"ordinary_echo_day_unavailable", "")
	if not get_pending_day7_followups().is_empty():
		return _transaction_failure(&"day7_followups_pending", "")
	var prepared: Dictionary = _ORDINARY_CORRESPONDENCE.prepare_echo_presented(contacts, command.echo_id,
		command.presentation_atom_id, command.command_id, command.command_issuer_receipt, presentation_receipt)
	if not prepared.get("ok", false): return prepared
	return _commit_ordinary_candidate(prepared, "", command.command_id)

func _admit_ordinary_command(command: Dictionary) -> Dictionary:
	if not command.command_id is String or not command.command_issuer_receipt is Dictionary \
			or not command.live_session is Dictionary or not command.source_contacts_sha256 is String:
		return _transaction_failure(&"invalid_ordinary_command", "")
	var admitted: Dictionary = validate_live_session(command.live_session)
	if not admitted.get("ok", false): return admitted
	if _run_lifecycle.get_state() != &"PLAYING":
		return _transaction_failure(&"ordinary_correspondence_unavailable", "")
	var verified := _verify_contact_command(command.command_id, command.command_issuer_receipt)
	if not verified.get("ok", false): return verified
	if not contacts.get("transaction_receipts", {}).has(command.command_id):
		var hashed: Dictionary = _CANONICAL_JSON.stringify(contacts)
		if not hashed.get("ok", false): return hashed
		if str(hashed.value).sha256_text() != command.source_contacts_sha256:
			return _transaction_failure(&"ordinary_correspondence_stale", "")
	return {"ok": true}

func _commit_ordinary_candidate(prepared: Dictionary, friend_id: String, command_id: String) -> Dictionary:
	if contacts.get("transaction_receipts", {}).has(command_id): return prepared
	if not _contact_checkpoint_writer.is_valid():
		return _transaction_failure(&"contact_checkpoint_writer_unconfigured", "")
	var lease: Dictionary = _mutation_gate.acquire(&"causal_transaction")
	if not lease.get("ok", false): return lease
	var captured: Dictionary = capture_restore_state()
	if not captured.get("ok", false):
		_mutation_gate.release(&"causal_transaction", str(lease.value.token))
		return captured
	var frozen := _prepare_contact_presentation_candidate(prepared.value.candidate)
	if not frozen.ok:
		_mutation_gate.release(&"causal_transaction", str(lease.value.token))
		return frozen
	contacts = prepared.value.candidate.duplicate(true)
	if _frozen_contacts_contexts_enabled: route_context = frozen.value.route_context.duplicate(true)
	var saved: Dictionary = _contact_checkpoint_writer.call()
	if not saved.get("ok", false):
		var rolled: Dictionary = rollback_restore_silent(captured.value.backup)
		if not rolled.get("ok", false):
			_mutation_gate.latch_fatal({"source": "ordinary_correspondence", "phase": "rollback",
				"code": "ORDINARY_ROLLBACK_FAILED", "details": {"cause": str(rolled.get("code", ""))}})
			return rolled
		var released: Dictionary = _mutation_gate.release(&"causal_transaction", str(lease.value.token))
		return saved if released.get("ok", false) else released
	var released: Dictionary = _mutation_gate.release(&"causal_transaction", str(lease.value.token))
	if not released.get("ok", false): return released
	if not friend_id.is_empty(): chat_changed.emit(friend_id)
	save_relevant_state_changed.emit()
	return prepared

static func _ordinary_command_has_keys(command: Dictionary, keys: Array) -> bool:
	if command.size() != keys.size(): return false
	for key: String in keys:
		if not command.has(key): return false
	return true


func get_pending_day7_followups() -> Array[Dictionary]:
	return _DAY7_FOLLOWUPS.pending_day7_followups(contacts)

func require_day7_presentations_complete() -> Dictionary:
	if day == 7 and _run_lifecycle.get_state() == &"PLAYING" \
			and (not get_pending_day7_followups().is_empty() or not get_pending_ordinary_echoes().is_empty()):
		return _transaction_failure(&"day7_presentations_pending", "")
	return {"ok": true}

func commit_day7_followup(command: Dictionary, presentation_receipt: Dictionary) -> Dictionary:
	if not _ordinary_command_has_keys(command, ["command_id", "command_issuer_receipt", "live_session",
		"source_contacts_sha256", "friend_id", "message_id", "sequence"]) \
			or not command.friend_id is String or not command.message_id is String or typeof(command.sequence) != TYPE_INT:
		return _transaction_failure(&"invalid_day7_followup_command", "")
	if contacts.get("transaction_receipts", {}).has(command.command_id):
		return _transaction_failure(&"day7_followup_command_reused", "")
	var admitted := _admit_ordinary_command(command)
	if not admitted.get("ok", false): return admitted
	var pending: Array[Dictionary] = get_pending_day7_followups()
	if day != 7 or pending.is_empty(): return _transaction_failure(&"day7_followup_unavailable", "")
	var first: Dictionary = pending[0]
	var entry_id: String = _DAY7_FOLLOWUPS.entry_id_for(contacts, first)
	if entry_id.is_empty(): return _transaction_failure(&"day7_followup_source_mismatch", "")
	var expected := {"entry_id": entry_id,
		"kind": "day7_followup", "view_token": command.command_id,
		"friend_id": first.friend_id, "message_id": first.message.message_id, "sequence": first.message.sequence}
	if command.friend_id != first.friend_id or command.message_id != first.message.message_id \
			or command.sequence != first.message.sequence or presentation_receipt != expected:
		return _transaction_failure(&"day7_followup_source_mismatch", "")
	var candidate := contacts.duplicate(true)
	candidate.read_watermarks[command.friend_id] = command.sequence
	var checked: Dictionary = _CONTACT_INVITATION_STATE.validate_state(candidate)
	if not checked.get("ok", false): return checked
	# This is the existing history read watermark, not invitation acceptance.
	return _commit_ordinary_candidate({"ok": true, "value": {"candidate": candidate},
		"receipt": expected}, command.friend_id, command.command_id)


var _contact_checkpoint_writer: Callable

func configure_contact_checkpoint_writer(writer: Callable) -> Dictionary:
	if not writer.is_valid() or writer.get_argument_count() != 0:
		return _transaction_failure(&"invalid_contact_checkpoint_writer", "a no-argument writer is required")
	if _contact_checkpoint_writer.is_valid() and _contact_checkpoint_writer != writer:
		return _transaction_failure(&"contact_checkpoint_writer_already_configured", "replacement refused")
	_contact_checkpoint_writer = writer
	return {"ok": true}

func open_contact(friend_id: String, command_id: String, command_issuer_receipt: Dictionary) -> Dictionary:
	var replayed: bool = (contacts.get("transaction_receipts", {}) as Dictionary).has(command_id)
	var opened := preview_open_contact(friend_id, command_id, command_issuer_receipt)
	if not opened.get("ok", false): return opened
	var operation: Dictionary = opened.value.candidate.transaction_receipts[command_id]
	var has_care: bool = not replayed and operation.has("hospital_care")
	var needs_checkpoint := has_care or (_frozen_contacts_contexts_enabled and not replayed)
	var frozen := _prepare_contact_presentation_candidate(opened.value.candidate)
	if not frozen.ok: return frozen
	var lease := {}
	var backup := {}
	var care_route: Dictionary = dating_route_state.get("sylvia", {}).duplicate(true)
	var care_affection := int(affection.get("sylvia", 0))
	if needs_checkpoint:
		if _run_lifecycle.get_state() != &"PLAYING" or _mutation_gate == null:
			return _transaction_failure(&"care_read_unavailable" if has_care else &"contact_read_unavailable", "Contacts requires a playable day and mutation gate")
		if not _contact_checkpoint_writer.is_valid():
			return _transaction_failure(&"contact_checkpoint_writer_unconfigured", "Contacts must be saved before publication")
		if has_care:
			var tier: String = str(care_route.get("relationship_state", "friend"))
			if tier not in ["friend", "ambiguous", "love"]:
				return _transaction_failure(&"invalid_care_relationship_state", tier)
			for witness_id: String in operation.hospital_care.witness_ids:
				var witness: Dictionary = operation.hospital_care.witnesses[witness_id]
				care_affection = clampi(care_affection + int(witness.affection_delta), AFFECTION_MIN, AFFECTION_MAX)
				care_route["dark_points"] = clampi(int(care_route.get("dark_points", 0)) + int(witness.dark_delta), 0, 4)
				tier = "ambiguous" if tier == "friend" else "love"
			care_route["relationship_state"] = tier
		lease = _mutation_gate.acquire(&"causal_transaction")
		if not lease.get("ok", false): return lease
		var captured: Dictionary = capture_restore_state()
		if not captured.get("ok", false):
			_mutation_gate.release(&"causal_transaction", str(lease.value.token))
			return captured
		backup = captured.value.backup
	contacts = opened.value.candidate
	if _frozen_contacts_contexts_enabled: route_context = frozen.value.route_context.duplicate(true)
	if not replayed:
		# Reading care cannot manufacture a Day-7 invitation acceptance or a date witness.
		if operation.kind != "open_sylvia_care":
			daily_opened_contacts["day:%d:friend:%s" % [day, friend_id]] = true
		if has_care:
			affection["sylvia"] = care_affection
			dating_route_state["sylvia"] = care_route
			friend_attitude["sylvia"] = "fixated"
		if needs_checkpoint:
			var saved: Dictionary = _contact_checkpoint_writer.call()
			if not saved.get("ok", false):
				var rolled: Dictionary = rollback_restore_silent(backup)
				var released: Dictionary = _mutation_gate.release(&"causal_transaction", str(lease.value.token))
				if not rolled.get("ok", false): return rolled
				return saved if released.get("ok", false) else released
			var released: Dictionary = _mutation_gate.release(&"causal_transaction", str(lease.value.token))
			if not released.get("ok", false): return released
		var committed := {"ok": true, "code": &"ok", "value": {
			"receipt": opened.receipt.duplicate(true), "replayed": false,
		}, "receipt": opened.receipt.duplicate(true)}
		if operation.kind != "open_sylvia_care": contact_open_committed.emit(committed.duplicate(true))
		if has_care: friends_changed.emit()
		emit_signal("chat_changed", friend_id)
		emit_signal("save_relevant_state_changed")
		return committed
	return {"ok": true, "code": &"ok", "value": {
		"receipt": opened.receipt.duplicate(true), "replayed": true,
	}, "receipt": opened.receipt.duplicate(true)}


func get_daily_message_friend_for_finished_round(round_number: int, target_day: int = -1) -> String:
	var d: int = target_day if target_day >= 0 else day
	var order: Array[String] = _SEVEN_DAY_CALENDAR.contact_round_order(d)
	if round_number < 1 or round_number > 3:
		return ""
	if round_number == 3 and d != 7:
		return ""
	var idx := round_number - 1
	if idx < 0 or idx >= order.size():
		return ""
	# Group invitation for the day suppresses individual solo messages.
	if _group_is_active(d):
		return ""
	return order[idx]


func unlock_contact_message_after_minesweeper_finished(result: Dictionary) -> Dictionary:
	var friend: String = get_daily_message_friend_for_finished_round(minesweeper_app_rounds_finished_today, day)
	if friend == "":
		return {}
	if _group_is_active():
		return {}
	# Day 7 uses the durable tier; raw affection cannot grant or remove an invitation.
	if day == 7 and not _has_day7_relationship_tier(friend):
		return {}
	var key: String = "day:%d:friend:%s" % [day, friend]
	if not _frozen_contacts_contexts_enabled: contact_message_unlocks[key] = true
	# Migration bridge (dwm-p2r.6, G1): mirror the daily-message unlock into a module solo offer
	# so pair solos exist in the bag by round 3 for group activation. Idempotent per friend/day.
	var offered: Dictionary = _CONTACT_INVITATION_STATE.prepare_offer_solo(
		contacts, friend, day, "solo:%s:day%d" % [friend, day], "offer:%s:day%d" % [friend, day])
	if offered.get("ok", false):
		var frozen := _prepare_contact_presentation_candidate(offered.value.candidate)
		if not frozen.ok: return frozen
		contacts = offered["value"]["candidate"]
		if _frozen_contacts_contexts_enabled: route_context = frozen.value.route_context.duplicate(true)
	elif _frozen_contacts_contexts_enabled:
		return offered
	if _frozen_contacts_contexts_enabled: contact_message_unlocks[key] = true
	emit_signal("contact_message_unlocked", {"friend_id": friend, "day": day})
	emit_signal("save_relevant_state_changed")
	return {"friend_id": friend, "day": day}


func _has_day7_relationship_tier(friend_id: String) -> bool:
	var state: Dictionary = dating_route_state.get(friend_id, {})
	return str(state.get("relationship_state", "friend")) in ["ambiguous", "love"]


func is_contact_message_unlocked(friend_id: String, target_day: int = -1) -> bool:
	var d: int = target_day if target_day >= 0 else day
	return bool(contact_message_unlocks.get("day:%d:friend:%s" % [d, friend_id], false))


func get_contact_view(friend_id: String, target_day: int = -1) -> Dictionary:
	# Player-visible contact history for a friend (dwm-p2r.6); delegates to the pure module.
	var d: int = target_day if target_day >= 0 else day
	return _CONTACT_INVITATION_STATE.get_contact_view(contacts, friend_id, d).duplicate(true)


func _group_is_active(target_day: int = -1) -> bool:
	# dwm-p2r.6: today's group offer exists once activated (round 3) — the module is the source.
	var selected_day := day if target_day < 0 else target_day
	return contacts["group_action"]["day"] == selected_day \
		and str(contacts["group_action"]["state"]) != "INACTIVE"


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
	if not _SEVEN_DAY_CALENDAR.is_group_day(day):
		return
	if minesweeper_app_rounds_finished_today != _CONTACT_INVITATION_STATE.GROUP_ACTIVATION_ROUND:
		return
	var activated: Dictionary = _CONTACT_INVITATION_STATE.prepare_activate_group_after_round(
		contacts, day,
		_CONTACT_INVITATION_STATE.GROUP_ACTIVATION_ROUND - 1,
		_CONTACT_INVITATION_STATE.GROUP_ACTIVATION_ROUND,
		"gactivate:day%d" % day)
	if activated.get("ok", false):
		var frozen := _prepare_contact_presentation_candidate(activated.value.candidate)
		if not frozen.ok: return
		contacts = activated["value"]["candidate"]
		if _frozen_contacts_contexts_enabled: route_context = frozen.value.route_context.duplicate(true)


func reply_invitation(friend_id: String, command_id: String, command_issuer_receipt: Dictionary) -> Dictionary:
	var day7_admitted := require_day7_presentations_complete()
	if not day7_admitted.get("ok", false): return day7_admitted
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
	var frozen := _prepare_contact_presentation_candidate(result.value.candidate)
	if not frozen.ok: return frozen
	contacts = result["value"]["candidate"]
	if _frozen_contacts_contexts_enabled: route_context = frozen.value.route_context.duplicate(true)
	emit_signal("save_relevant_state_changed")
	return {"ok": true, "code": &"ok", "value": {"receipt": result["receipt"], "replayed": false}}


func is_date_unlocked(friend_id: String, target_day: int = -1) -> bool:
	var d: int = target_day if target_day >= 0 else day
	if d == 7:
		return is_contact_message_unlocked(friend_id, 7) and _has_day7_relationship_tier(friend_id)
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
		if not _has_day7_relationship_tier(fid):
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


func prepare_provisional_day7_ending_plan() -> Dictionary:
	if day != 7:
		return _transaction_failure(&"not_day7", "ending eligibility is captured only on Day 7")
	var existing: Variant = route_context.get("provisional_ending_plan")
	if typeof(existing) == TYPE_DICTIONARY and not (existing as Dictionary).is_empty():
		return {"ok": true, "code": &"ok", "value": (existing as Dictionary).duplicate(true)}

	return _prepare_day7_ending_plan({})


func _prepare_day7_ending_plan(condition_source: Dictionary, attempt_reader: Callable = Callable(), profile_reader: Callable = Callable()) -> Dictionary:
	var destination := ""
	for entry: Dictionary in ([] if not condition_source.is_empty() else _committed_entries()):
		if str(entry.get("action_kind", "")) != "solo":
			continue
		var participants: Array = entry.get("participants", [])
		if participants.size() == 1 and str(participants[0]) in FRIEND_IDS:
			if not destination.is_empty():
				return _transaction_failure(&"ambiguous_day7_destination",
					"more than one personal destination was committed")
			destination = str(participants[0])
	var states := {}
	var invitations := {}
	for friend_id: String in FRIEND_IDS:
		var state: Dictionary = dating_route_state.get(friend_id, {})
		states[friend_id] = str(state.get("relationship_state", "friend"))
		invitations[friend_id] = bool(
			daily_opened_contacts.get("day:7:friend:%s" % friend_id, false))
	var pair: Dictionary = inter_friend_route_state.get("priscilla_lavinia", {})
	const MASTERY := preload("res://scripts/domain/ending/CanonicalDatingMastery.gd")
	var run_id := str(_run_lifecycle.to_dict().get("run_id", ""))
	var raw_heads: Variant = route_context.get("dating_canonical_heads", {})
	var heads: Dictionary = raw_heads if raw_heads is Dictionary else {}
	var selected_attempts := {}
	if not attempt_reader.is_valid() and is_inside_tree():
		var profile: Node = get_node_or_null("/root/ProfileManager")
		if profile != null and profile.has_method("get_dating_attempt"):
			attempt_reader = profile.get_dating_attempt
	if attempt_reader.is_valid():
		for slot: String in MASTERY.required_slots():
			var head: Variant = heads.get(slot)
			if not head is Dictionary: continue
			if not head.get("attempt_id") is String or not head.get("branch_id") is String: continue
			if head.attempt_id.is_empty() or head.branch_id.is_empty(): continue
			# Never use the two-argument first-lock history lookup for canonical mastery.
			var found: Variant = attempt_reader.call(run_id, slot, head.attempt_id, head.branch_id)
			if found is Dictionary and found.get("ok", false) and found.get("value") is Dictionary:
				selected_attempts[slot] = found.value
	var mastery: Dictionary = MASTERY.evaluate(run_id, heads, selected_attempts)
	# Observer interactions are deferred; solo postscripts require current board mastery
	# and Sweet tone. Profile receipts still own replay form and pair Persistence.
	# Caller-supplied variant flags carry no authority.
	var evidence_profile: Dictionary = {}
	if not profile_reader.is_valid() and is_inside_tree():
		var profile_owner: Node = get_node_or_null("/root/ProfileManager")
		if profile_owner != null and profile_owner.has_method("get_profile_snapshot"):
			profile_reader = profile_owner.get_profile_snapshot
	if profile_reader.is_valid():
		var read_profile: Variant = profile_reader.call()
		if read_profile is Dictionary: evidence_profile = read_profile.duplicate(true)
	var completed_posts := {}
	var gallery_receipts: Variant = evidence_profile.get("gallery_transaction_receipts", {})
	if gallery_receipts is Dictionary:
		for receipt_id: Variant in gallery_receipts:
			var receipt: Variant = gallery_receipts[receipt_id]
			if receipt_id is String and receipt is Dictionary and receipt.get("ending_id") is String \
					and receipt_id.begins_with("ending:") and receipt_id.ends_with(":gallery:" + receipt.ending_id):
				completed_posts[receipt.ending_id] = true
	var observer_variants := {}
	for friend_id: String in ["priscilla", "lavinia"]:
		if mastery[friend_id] \
				and int((dating_route_state.get(friend_id, {}) as Dictionary).get("dark_points", 0)) \
				< _PROVISIONAL_RELATIONSHIP_RULES.DARK_TONE_THRESHOLD:
			observer_variants[friend_id] = "residue" if completed_posts.has("ending.%s.observation" % friend_id) else "full"
	var witnessed_forms: Array = []
	var witnesses: Variant = evidence_profile.get("pair_form_witness_receipts", {})
	if witnesses is Dictionary:
		for form: Variant in witnesses.values():
			if form is String and form in _PROVISIONAL_RELATIONSHIP_RULES.PAIR_FORMS and form not in witnessed_forms:
				witnessed_forms.append(form)
	var pair_observer_precondition := {}
	var pair_form: String = str(pair.get("frozen_form", ""))
	if mastery.priscilla_lavinia and pair_form.ends_with("_sweet") and should_route_priscilla_lavinia_post_ending():
		var persistence: bool = witnessed_forms.size() == 4
		if not persistence and witnessed_forms.size() == 3 and pair_form not in witnessed_forms:
			persistence = true
			pair_observer_precondition = {"required_forms": _PROVISIONAL_RELATIONSHIP_RULES.PAIR_FORMS.duplicate(),
				"supplied_by_ending": "ending.priscilla_lavinia.sweet", "form": pair_form}
		if persistence:
			observer_variants["priscilla_lavinia"] = "residue" if completed_posts.has("ending.priscilla_lavinia.observer") else "full"
	var rules_input := {
		"day": 7,
		"committed_destination": destination,
		"relationship_states": states,
		"invitation_read": invitations,
		"tone_points": int((dating_route_state.get(destination, {}) as Dictionary).get(
			"dark_points", 0)) if not destination.is_empty() else 0,
		"hospital_required": pending_hospital,
		"pair_ending_eligible": should_route_priscilla_lavinia_post_ending(),
		"pair_form": str(pair.get("frozen_form", "")),
		"observer_variant_by_scope": observer_variants.duplicate(true),
		"board_mastery_by_scope": mastery.duplicate(true),
		"pair_observer_witness_precondition": pair_observer_precondition.duplicate(true),
		"presentation_by_scope": _capture_ending_presentation_inputs(),
	}
	if not condition_source.is_empty():
		# Use the persisted pre-action decision, never invitations read later or a draft bar.
		var cause := str(condition_source.terminal_cause)
		rules_input.invitation_read = {"sylvia": cause == "sylvia_special"}
		rules_input.hospital_required = cause != "dark_mode_alone"
	var frozen: Dictionary = _PROVISIONAL_RELATIONSHIP_RULES.new().freeze_day7_ending_plan(
		rules_input)
	if not frozen.get("ok", false):
		return frozen
	return {"ok": true, "code": &"ok", "value": frozen["value"].duplicate(true)}


## Detached presentation facts are frozen with the existing ending eligibility snapshot.
## Current provisional scenes have no authored echo mutations, so their echo set is empty.
func _capture_ending_presentation_inputs() -> Dictionary:
	var result := {}
	for friend_id: String in FRIEND_IDS:
		var state: Dictionary = dating_route_state.get(friend_id, {})
		var missed: Array[String] = []
		for message: Dictionary in contacts.get("messages", {}).get(friend_id, []):
			var kind := str(message.get("type", ""))
			if kind in ["nevermind", "missed_question", "busy", "judge"] and kind not in missed:
				missed.append(kind)
		missed.sort()
		result[friend_id] = {"tier": str(state.get("relationship_state", "friend")),
			"tone": "dark" if int(state.get("dark_points", 0)) >= _PROVISIONAL_RELATIONSHIP_RULES.DARK_TONE_THRESHOLD else "sweet",
			"attitude": str(friend_attitude.get(friend_id, "")), "echo_ids": [], "miss_reasons": missed}
	result["dark_mode"] = bool(_run_lifecycle.to_dict().get("dark_mode", false))
	result["pair_form"] = str(inter_friend_route_state.get("priscilla_lavinia", {}).get("frozen_form", ""))
	result["special_variant"] = "full"
	if is_inside_tree():
		var profile: Node = get_node_or_null("/root/ProfileManager")
		if profile != null:
			var completed := false
			for receipt: Dictionary in profile.get_profile_snapshot().get("gallery_transaction_receipts", {}).values():
				if str(receipt.get("ending_id", "")) == "ending.sylvia.special": completed = true
			if completed and not bool(profile.get_preference("preferences.exceptional_replay.replay_full", false)):
				result["special_variant"] = "residue"
	return result

const _ENDING_FROZEN_CONTEXT := preload("res://scripts/narrative/EndingFrozenContext.gd")
var _frozen_ending_contexts_enabled := false

func configure_frozen_ending_contexts() -> Dictionary:
	_frozen_ending_contexts_enabled = true
	return {"ok": true}

func _capture_ending_frozen_seed(provisional: Dictionary) -> Dictionary:
	var snapshot: Variant = provisional.get("eligibility_snapshot")
	if not snapshot is Dictionary or not snapshot.get("presentation_by_scope") is Dictionary \
			or typeof(snapshot.get("hospital_required")) != TYPE_BOOL:
		return _transaction_failure(&"ending_frozen_seed_required", "")
	var evidence := {"priscilla": [], "lavinia": [], "sylvia": [], "priscilla_lavinia": []}
	var profile: Node = get_node_or_null("/root/ProfileManager") if is_inside_tree() else null
	if profile != null and profile.has_method("get_dating_attempt"):
		var run_id := str(_run_lifecycle.to_dict().run_id)
		for slot: String in route_context.get("dating_canonical_heads", {}):
			var head: Dictionary = route_context.dating_canonical_heads[slot]
			var found: Dictionary = profile.get_dating_attempt(run_id, slot, str(head.attempt_id), str(head.branch_id))
			if not found.ok: return found
			var attempt: Dictionary = found.value
			var scope: String = str(attempt.record.context.participants[0]) if attempt.record.host == "canonical_solo" else "priscilla_lavinia"
			for key: String in ["effect_receipt", "completion_receipt"]:
				var receipt: Variant = attempt.get(key)
				if receipt is Dictionary and receipt.get("receipt_id") is String and receipt.receipt_id not in evidence[scope]:
					evidence[scope].append(receipt.receipt_id)
	for values: Array in evidence.values(): values.sort()
	var pair_counts: Array = []
	for transaction_id: String in contacts.get("transaction_receipts", {}):
		var receipt: Dictionary = contacts.transaction_receipts[transaction_id]
		var window: Variant = receipt.get("pl_window")
		if receipt.get("kind") == "resolve_day_end" and window is Dictionary and window.get("counts") == true:
			pair_counts.append(transaction_id)
	pair_counts.sort()
	return _ENDING_FROZEN_CONTEXT.make_seed(snapshot.presentation_by_scope, evidence, pair_counts,
		"hospital_faint" if snapshot.hospital_required else "empty_done")

## The current step is checkpointed before playback. Later steps have no tokens or
## prerequisite receipts in this cache until their preceding steps really complete.
func capture_ending_frozen_presentation(ending_id: String, context: Dictionary) -> Dictionary:
	if not _frozen_ending_contexts_enabled: return _transaction_failure(&"ending_frozen_contexts_unconfigured", "")
	var command := request_next_ending_command()
	if not command.get("ok", false) or command.get("value", {}).get("kind") != "play_ending" \
			or command.value.ending_id != ending_id or command.value.playback_context != context:
		return _transaction_failure(&"ending_presentation_command_mismatch", ending_id)
	var lifecycle: Dictionary = _run_lifecycle.to_dict()
	var cached: Variant = route_context.get("ending_frozen_contexts_v1")
	var checked := _ENDING_FROZEN_CONTEXT.validate_cache(cached, lifecycle)
	if not checked.ok: return checked
	var key := str(context.playback_id)
	if cached.presentations.has(key): return {"ok": true, "value": cached.presentations[key].duplicate(true)}
	var projected := _ENDING_FROZEN_CONTEXT.build(lifecycle.ending_plan, int(lifecycle.ending_plan.next_step_index), cached.seed, key)
	if not projected.ok: return projected
	if not _ending_checkpoint_writer.is_valid(): return _transaction_failure(&"ending_checkpoint_writer_unconfigured", "")
	var lease := _acquire_ending_lease()
	if not lease.ok: return lease
	var captured := capture_restore_state()
	if not captured.ok:
		_release_ending_lease(lease)
		return captured
	var candidate: Dictionary = cached.duplicate(true)
	candidate.presentations[key] = projected.value.duplicate(true)
	route_context["ending_frozen_contexts_v1"] = candidate
	var saved: Dictionary = _ending_checkpoint_writer.call()
	if not saved.ok:
		var rolled := rollback_restore_silent(captured.value.backup)
		var released := _release_ending_lease(lease)
		if not rolled.ok: return rolled
		return saved if released.ok else released
	var released := _release_ending_lease(lease)
	return projected if released.ok else released


## Accept only the command at this saved cursor. The returned signature names the exact
## registered entry the ending adapter must physically play, including exceptional forms.
func capture_ending_presentation_signature(ending_id: String, context: Dictionary) -> Dictionary:
	var command: Dictionary = request_next_ending_command()
	if not command.get("ok", false) or command.get("value", {}).get("kind") != "play_ending" \
			or command.value.get("ending_id") != ending_id or command.value.get("playback_context") != context:
		return _transaction_failure(&"ending_presentation_command_mismatch", ending_id)
	if _frozen_ending_contexts_enabled:
		var lifecycle: Dictionary = _run_lifecycle.to_dict()
		var cache: Variant = route_context.get("ending_frozen_contexts_v1")
		var checked := _ENDING_FROZEN_CONTEXT.validate_cache(cache, lifecycle)
		if not checked.ok: return checked
		return _ENDING_FROZEN_CONTEXT.signature_for_step(lifecycle.ending_plan, int(lifecycle.ending_plan.next_step_index), cache.seed)
	var frozen: Dictionary = route_context.get("provisional_ending_plan", {}).get("eligibility_snapshot", {})
	# A compatible older save has no captured presentation map. Its current saved facts are
	# captured at this first actual start; this does not invent an earlier reached variant.
	var inputs: Dictionary = frozen.get("presentation_by_scope", _capture_ending_presentation_inputs())
	var role := str(context.role)
	var entry_id := ending_id
	var form := ""
	var fields := {}
	if ending_id == "ending.alone":
		entry_id += ".dark_mode" if bool(inputs.get("dark_mode", false)) else ".normal"
		form = "alone_dark_mode" if bool(inputs.get("dark_mode", false)) else "alone_normal"
		fields = {"ending_role": role, "ending_form": form}
	else:
		if ending_id == "ending.sylvia.special":
			entry_id += "." + str(inputs.get("special_variant", "full"))
			form = "special_" + str(inputs.get("special_variant", "full"))
		elif ".observer." in ending_id:
			form = "observer_" + ending_id.get_slice(".", 3)
		elif ending_id.ends_with(".observation"):
			entry_id = ending_id.trim_suffix(".observation") + ".observer.full"
			form = "observer_full"
		elif ending_id.begins_with("ending.priscilla_lavinia"):
			var pair_form := str(inputs.get("pair_form", ""))
			if pair_form not in _PROVISIONAL_RELATIONSHIP_RULES.PAIR_FORMS:
				return _transaction_failure(&"ending_presentation_pair_form_missing", ending_id)
			form = "deck_dark" if pair_form.ends_with("_dark") else "deck_sweet"
			if ending_id == "ending.priscilla_lavinia": entry_id += ".dark" if pair_form.ends_with("_dark") else ".sweet"
		else:
			form = "derived_dark" if ending_id.ends_with(".dark") else "derived_sweet"
			var steps: Array = _run_lifecycle.to_dict().get("ending_plan", {}).get("steps", [])
			if ending_id == "ending.sylvia.dark" and not steps.is_empty() and steps[0].get("role") == "special_prefix":
				form = "special_forced_dark"
		if ending_id.begins_with("ending.priscilla_lavinia"):
			fields = {"pair_form": str(inputs.get("pair_form", "")), "ending_role": role,
				"ending_form": form, "residue": form.ends_with("_residue")}
		else:
			var scope := ending_id.get_slice(".", 1)
			if not inputs.get(scope) is Dictionary: return _transaction_failure(&"ending_presentation_scope_missing", scope)
			fields = (inputs[scope] as Dictionary).duplicate(true)
			fields.merge({"ending_role": role, "ending_form": form, "residue": form.ends_with("_residue")})
	var signature := {"entry_id": entry_id, "schema_version": 1, "fields": fields}
	var checked: Dictionary = preload("res://scripts/domain/narrative/PresentationSignature.gd").validate(signature)
	if not checked.get("ok", false): return checked
	return {"ok": true, "code": &"ok", "value": signature}


func capture_provisional_day7_ending_plan() -> Dictionary:
	var prepared: Dictionary = prepare_provisional_day7_ending_plan()
	if not prepared.get("ok", false): return prepared
	if route_context.get("provisional_ending_plan") != prepared.value:
		route_context["provisional_ending_plan"] = prepared.value.duplicate(true)
		emit_signal("save_relevant_state_changed")
	return prepared


func resolve_day7_ending() -> Dictionary:
	if day != 7:
		return {"ok": false, "candidate_friend_id": "", "ending_id": "", "epilogue_ending_id": "", "route_context_set": false, "reason": "not_day7"}
	capture_provisional_day7_ending_plan()
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


func get_counted_pair_window_count() -> int:
	var counted_days := {}
	for raw: Variant in contacts.get("transaction_receipts", {}).values():
		if not raw is Dictionary or raw.get("kind") != "resolve_day_end": continue
		var window: Variant = raw.get("pl_window")
		var source_day := int(raw.get("day", 0))
		if _SEVEN_DAY_CALENDAR.is_group_day(source_day) and window is Dictionary \
				and bool(window.get("counts", false)):
			counted_days[source_day] = true
	return counted_days.size()


func should_route_priscilla_lavinia_post_ending() -> bool:
	# Canonical Contacts receipts count each window once, including offscreen encounters.
	# Retain already-earned eligibility from older saved progression state.
	return get_counted_pair_window_count() >= 2 or bool((inter_friend_route_state.get(
		"priscilla_lavinia", {}) as Dictionary).get("ending_eligible", false))


func should_route_sylvia_special_ending() -> bool:
	var plan: Variant = route_context.get("provisional_ending_plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return false
	var steps: Variant = (plan as Dictionary).get("steps")
	return typeof(steps) == TYPE_ARRAY and not (steps as Array).is_empty() and str(((steps as Array)[0] as Dictionary).get("ending_id", "")) == "ending.sylvia.special"

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
## pre-Done QUERY surface is not. `get_scheduled_date_count` and
## `get_max_scheduled_dates_for_current_day` were written to inspect
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
	var hospital: Dictionary = _PROVISIONAL_RELATIONSHIP_RULES.new().resolve_hospital(
		_provisional_hospital_input(pressure, health))
	if not hospital.get("ok", false):
		return hospital
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
		condition_streak_days = 1

	var faint := bool(hospital["value"]["required"])
	if condition != CONDITION_NONE:
		condition_effects_today.append(condition)
		if faint:
			condition_effects_today.append(CONDITION_FAINT)
		pending_hospital = faint
		emit_signal("condition_effect_resolved", {"condition": condition, "faint": faint})
		if faint:
			route_context["provisional_hospital_resolution"] = hospital["value"].duplicate(true)
			emit_signal("hospital_needed", {"condition": condition})
		else:
			route_context.erase("provisional_hospital_resolution")

	condition_resolved_day = day
	emit_signal("save_relevant_state_changed")
	return {"ok": true, "needs_hospital": pending_hospital, "condition": condition, "faint": faint,
		"hospital_resolution": hospital["value"].duplicate(true)}

func _provisional_hospital_input(pressure: int, health: int) -> Dictionary:
	return {
		"day": day,
		"pressure": pressure,
		"health": health,
		"sylvia_encounter_committed": _has_committed_sylvia_solo(),
		"sylvia_invitation_read": bool(
			daily_opened_contacts.get("day:7:friend:sylvia", false)),
	}


func _has_committed_sylvia_solo() -> bool:
	for entry: Dictionary in _committed_entries():
		if str(entry.get("action_kind", "")) == "solo" and (entry.get("participants", []) as Array).has("sylvia"):
			return true
	return false

func should_route_hospital() -> bool:
	return pending_hospital

func check_immediate_faint() -> bool:
	var hospital: Dictionary = _PROVISIONAL_RELATIONSHIP_RULES.new().resolve_hospital(
		_provisional_hospital_input(get_stat(STAT_PRESSURE), get_stat(STAT_HEALTH)))
	if not hospital.get("ok", false) or not bool(hospital["value"]["required"]):
		return false
	pending_hospital = true
	route_context["provisional_hospital_resolution"] = hospital["value"].duplicate(true)
	if not condition_effects_today.has(CONDITION_FAINT):
		condition_effects_today.append(CONDITION_FAINT)
	emit_signal("condition_effect_resolved", {"condition": CONDITION_FAINT, "faint": true})
	emit_signal("hospital_needed", {"condition": CONDITION_FAINT})
	emit_signal("save_relevant_state_changed")
	return true

func apply_hospital_recovery_and_advance_day() -> bool:
	if day >= 7:
		capture_provisional_day7_ending_plan()
	var resolution: Dictionary = route_context.get("provisional_hospital_resolution", {})
	var recovery: Dictionary = resolution.get("recovery", {})
	set_stat(STAT_HEALTH, int(recovery.get("health",
		_PROVISIONAL_RELATIONSHIP_RULES.HOSPITAL_RECOVERY["health"])))
	set_stat(STAT_PRESSURE, int(recovery.get("pressure",
		_PROVISIONAL_RELATIONSHIP_RULES.HOSPITAL_RECOVERY["pressure"])))
	pending_hospital = false
	condition_streak_days = 0
	condition_resolved_day = 0
	condition_effects_today = []
	_reset_committed_schedule_for_day_end()
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
	if day >= 7:
		# Freeze eligibility while the committed Schedule and invitation-read facts still exist.
		capture_provisional_day7_ending_plan()
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


## Pure projection shared by legacy advancement and durable day-resolution checkpoints.
func capture_new_day_gameplay() -> Dictionary:
	var gameplay: Dictionary = capture_run_snapshot_input()["gameplay"].duplicate(true)
	gameplay.merge({
		"minesweeper_rounds_left": 2,
		"minesweeper_app_rounds_finished_today": 0,
		"minesweeper_money_earned_today": 0, "penalty_points_today": 0,
		"condition_effects_today": [CONDITION_SEQUELA] if condition_streak_days > 0 else [],
		"condition_streak_days": 0, "condition_resolved_day": 0,
		"daily_opened_contacts": {}, "daily_group_invitation_generated": false,
		"daily_group_invitation_pair": [], "pending_date_entries": [],
		"pending_date_entry_index": 0, "pending_date_friend_id": "",
	}, true)
	gameplay["stats"][STAT_MOTIVATION] = 7
	return gameplay


func _begin_new_day() -> void:
	_apply_gameplay_silent(capture_new_day_gameplay())
	unfinished_minesweeper_result = {}
	emit_signal("stat_changed", STAT_MOTIVATION, get_stat(STAT_MOTIVATION), _stat_min(STAT_MOTIVATION), _stat_max(STAT_MOTIVATION))
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


func _validate_dating_terminal_fact(terminal_fact: Dictionary) -> Dictionary:
	var fact_keys: Array = terminal_fact.keys()
	fact_keys.sort()
	if fact_keys != ["outcome", "perfect_reasons", "relationship_outcome", "transaction_id"] \
			or typeof(terminal_fact.get("transaction_id")) != TYPE_STRING \
			or str(terminal_fact["transaction_id"]).strip_edges().is_empty() \
			or typeof(terminal_fact.get("outcome")) != TYPE_STRING \
			or typeof(terminal_fact.get("relationship_outcome")) != TYPE_STRING \
			or not terminal_fact.get("perfect_reasons") is Array:
		return _transaction_failure(&"invalid_dating_terminal_fact",
			"a trusted board outcome, relationship outcome and qualification reasons are required")
	return {"ok": true}


## Freeze the actual response and promotion decision before Profile makes it irreversible.
func prepare_dating_challenge_effect(entry: Dictionary, terminal_fact: Dictionary) -> Dictionary:
	var valid := _validate_dating_terminal_fact(terminal_fact)
	if not valid.get("ok", false): return valid
	var scene_id := _provisional_dating_scene_id(entry)
	if str(entry.get("type", "")) != "solo" or scene_id.is_empty():
		return _transaction_failure(&"invalid_dating_entry", "canonical solo effect required")
	var friend_id := str(entry.friend_id)
	var state: Dictionary = dating_route_state.get(friend_id, {})
	var prior: Variant = state.get("provisional_receipts", {}).get(str(terminal_fact.transaction_id))
	if prior is Dictionary:
		if prior.get("terminal_fact") != terminal_fact:
			return _transaction_failure(&"dating_terminal_receipt_conflict", "terminal outcome cannot change")
		return {"ok": true, "value": {"receipt": prior.duplicate(true)}}
	var rules: RefCounted = _PROVISIONAL_RELATIONSHIP_RULES.new()
	var response: Dictionary = rules.resolve_scene_response(scene_id, str(terminal_fact.outcome),
		str(terminal_fact.relationship_outcome), terminal_fact.perfect_reasons)
	if not response.get("ok", false): return response
	var current_state := str(state.get("relationship_state", "friend"))
	var progression: Dictionary = rules.evaluate_progression({
		"window_id": scene_id, "event_id": str(terminal_fact.transaction_id), "friend_id": friend_id,
		"attended": true, "hospital_superseded": false, "current_state": current_state,
		"relational_momentum": clampi(int(affection.get(friend_id, 0)) + int(response.value.momentum_delta), AFFECTION_MIN, AFFECTION_MAX),
		"response_qualifies": response.value.progression_qualifies,
		"committed_event_ids": state.get("progression_event_ids", []).duplicate(),
	})
	if not progression.get("ok", false): return progression
	var receipt := _provisional_dating_receipt(response.value, progression.value, terminal_fact)
	receipt["promotion_applied"] = str(progression.value.state) != current_state
	return {"ok": true, "value": {"receipt": receipt}}


## Replay committed operations, not a relationship snapshot or a fresh threshold evaluation.
func apply_dating_challenge_effect_receipt(entry: Dictionary, receipt: Dictionary, emit_changes: bool = true) -> Dictionary:
	var scene_id := _provisional_dating_scene_id(entry)
	if str(entry.get("type", "")) != "solo" or scene_id.is_empty() or receipt.get("scene_id") != scene_id:
		return _transaction_failure(&"invalid_dating_entry", "effect belongs to another slot")
	if not receipt.get("terminal_fact") is Dictionary:
		return _transaction_failure(&"invalid_dating_effect", "terminal fact required")
	var valid := _validate_dating_terminal_fact(receipt.terminal_fact)
	if not valid.get("ok", false): return valid
	for key: String in ["momentum_delta", "tone_delta"]:
		if typeof(receipt.get(key)) != TYPE_INT: return _transaction_failure(&"invalid_dating_effect", key)
	for key: String in ["progression_evaluated", "promotion_applied"]:
		if typeof(receipt.get(key)) != TYPE_BOOL: return _transaction_failure(&"invalid_dating_effect", key)
	if not receipt.get("attitude") is String or str(receipt.attitude).is_empty() 			or str(receipt.get("relationship_state", "")) not in ["friend", "ambiguous", "love"]:
		return _transaction_failure(&"invalid_dating_effect", "frozen attitude and tier required")
	for key: String in ["outcome", "relationship_outcome", "perfect_reasons"]:
		if receipt.get(key) != receipt.terminal_fact.get(key): return _transaction_failure(&"invalid_dating_effect", key)
	var friend_id := str(entry.friend_id)
	var event_id := str(receipt.terminal_fact.transaction_id)
	var state: Dictionary = dating_route_state.get(friend_id, {}).duplicate(true)
	var receipts: Dictionary = state.get("provisional_receipts", {}).duplicate(true)
	if receipts.has(event_id):
		if receipts[event_id] != receipt:
			return _transaction_failure(&"dating_terminal_receipt_conflict", "committed effect cannot change")
		return {"ok": true, "value": {"replayed": true, "receipt": receipt.duplicate(true)}}
	state["date_count"] = int(state.get("date_count", 0)) + 1
	state["dark_points"] = mini(4, int(state.get("dark_points", 0)) + int(receipt.tone_delta))
	var current_state := str(state.get("relationship_state", "friend"))
	state["relationship_state"] = current_state
	# A frozen promotion grants its earned tier; it never lowers a later branch's tier.
	if receipt.promotion_applied and ["friend", "ambiguous", "love"].find(str(receipt.relationship_state)) > ["friend", "ambiguous", "love"].find(current_state):
		state["relationship_state"] = str(receipt.relationship_state)
	var events: Array = state.get("progression_event_ids", []).duplicate()
	if receipt.progression_evaluated and event_id not in events: events.append(event_id)
	state["progression_event_ids"] = events
	receipts[event_id] = receipt.duplicate(true)
	state["provisional_receipts"] = receipts
	affection[friend_id] = clampi(int(affection.get(friend_id, 0)) + int(receipt.momentum_delta), AFFECTION_MIN, AFFECTION_MAX)
	friend_attitude[friend_id] = str(receipt.attitude)
	dating_route_state[friend_id] = state
	if emit_changes:
		emit_signal("friends_changed")
		emit_signal("save_relevant_state_changed")
	return {"ok": true, "value": {"replayed": false, "receipt": receipt.duplicate(true)}}


func apply_dating_challenge_result(entry: Dictionary, terminal_fact: Dictionary) -> Dictionary:
	var valid := _validate_dating_terminal_fact(terminal_fact)
	if not valid.get("ok", false): return valid
	var entry_type := str(entry.get("type", ""))
	var event_id := str(terminal_fact["transaction_id"])
	var outcome := str(terminal_fact["outcome"])
	var scene_id := _provisional_dating_scene_id(entry)
	if scene_id.is_empty():
		return _transaction_failure(&"invalid_dating_entry", "a supported dated entry is required")
	var rules: RefCounted = _PROVISIONAL_RELATIONSHIP_RULES.new()
	var resolved: Dictionary = rules.resolve_scene_response(scene_id, outcome,
		str(terminal_fact.relationship_outcome), terminal_fact.perfect_reasons)
	if not resolved.get("ok", false):
		return resolved
	var response: Dictionary = resolved["value"]

	var participants: Array = []
	if entry_type == "solo":
		participants = [str(entry.get("friend_id", ""))]
	elif entry_type == "group":
		participants = (entry.get("friend_ids", []) as Array).duplicate()
	for participant: String in participants:
		if participant not in FRIEND_IDS:
			return _transaction_failure(&"invalid_dating_entry", "unknown participant")
	var pair_state: Dictionary = inter_friend_route_state.get("priscilla_lavinia", {}).duplicate(true)
	if entry_type in ["group", "twofriends"] and not pair_state.has("frozen_form"):
		return _transaction_failure(&"pair_form_unavailable", "new-run pair form was not frozen")

	var receipt_owner: Dictionary = pair_state if entry_type == "twofriends" else 		(dating_route_state.get(str(participants[0]), {}) if not participants.is_empty() else pair_state)
	var prior_receipts: Dictionary = receipt_owner.get("provisional_receipts", {})
	if prior_receipts.has(event_id):
		if prior_receipts[event_id].get("terminal_fact", {}) != terminal_fact:
			return _transaction_failure(&"dating_terminal_receipt_conflict", "the recorded terminal outcome cannot change")
		return {"ok": true, "code": &"ok", "value": {
			"replayed": true, "receipt": prior_receipts[event_id].duplicate(true)}}

	for participant: String in participants:
		var state: Dictionary = dating_route_state.get(participant, {}).duplicate(true)
		state["date_count"] = int(state.get("date_count", 0)) + 1
		state["dark_points"] = mini(4, int(state.get("dark_points", 0)) + int(response["tone_delta"]))
		state["relationship_state"] = str(state.get("relationship_state", "friend"))
		state["progression_event_ids"] = (state.get("progression_event_ids", []) as Array).duplicate()
		state["provisional_receipts"] = (state.get("provisional_receipts", {}) as Dictionary).duplicate(true)
		affection[participant] = clampi(int(affection.get(participant, 0))
			+ int(response["momentum_delta"]), AFFECTION_MIN, AFFECTION_MAX)
		var progression: Dictionary = rules.evaluate_progression({
			"window_id": scene_id, "event_id": event_id, "friend_id": participant,
			"attended": true, "hospital_superseded": false,
			"current_state": state["relationship_state"],
			"relational_momentum": affection[participant],
			"response_qualifies": response["progression_qualifies"],
			"committed_event_ids": state["progression_event_ids"],
		})
		if not progression.get("ok", false):
			return progression
		state["relationship_state"] = progression["value"]["state"]
		if progression["value"]["evaluated"]:
			(state["progression_event_ids"] as Array).append(event_id)
		state["provisional_receipts"][event_id] = _provisional_dating_receipt(
			response, progression["value"], terminal_fact)
		friend_attitude[participant] = str(response["attitude"])
		dating_route_state[participant] = state

	if entry_type in ["group", "twofriends"]:
		pair_state["date_count"] = int(pair_state.get("date_count", 0)) + 1
		pair_state["dark_points"] = int(pair_state.get("dark_points", 0)) + int(response["tone_delta"])
		pair_state["ending_eligible"] = int(pair_state["date_count"]) >= 2
		pair_state["provisional_receipts"] = (pair_state.get("provisional_receipts", {}) as Dictionary).duplicate(true)
		pair_state["provisional_receipts"][event_id] = _provisional_dating_receipt(response, {}, terminal_fact)
		inter_friend_route_state["priscilla_lavinia"] = pair_state
		if entry_type == "twofriends":
			inter_friend_affection["lavinia_priscilla"] = int(
				inter_friend_affection.get("lavinia_priscilla", 0)) + int(response["momentum_delta"])

	emit_signal("friends_changed")
	emit_signal("save_relevant_state_changed")
	var stored: Dictionary = pair_state if entry_type == "twofriends" else 		dating_route_state[str(participants[0])]
	return {"ok": true, "code": &"ok", "value": {
		"replayed": false,
		"receipt": (stored["provisional_receipts"] as Dictionary)[event_id].duplicate(true),
	}}

func _provisional_dating_scene_id(entry: Dictionary) -> String:
	var day_value: Variant = entry.get("day", day)
	if typeof(day_value) != TYPE_INT or int(day_value) < 1 or int(day_value) > 7:
		return ""
	var entry_type := str(entry.get("type", ""))
	if entry_type == "solo":
		var friend_id := str(entry.get("friend_id", ""))
		if friend_id not in FRIEND_IDS:
			return ""
		return "dating.solo.%s.day%d" % [friend_id, int(day_value)]
	if entry_type in ["group", "twofriends"]:
		var friend_ids: Variant = entry.get("friend_ids")
		if typeof(friend_ids) != TYPE_ARRAY or (friend_ids as Array).size() != 2 				or not (friend_ids as Array).has("priscilla") 				or not (friend_ids as Array).has("lavinia"):
			return ""
		return "dating.%s.priscilla_lavinia.day%d" % [entry_type, int(day_value)]
	return ""


func _provisional_dating_receipt(response: Dictionary, progression: Dictionary, terminal_fact: Dictionary) -> Dictionary:
	return {
		"terminal_fact": terminal_fact.duplicate(true),
		"relationship_outcome": response["relationship_outcome"],
		"perfect_reasons": response["perfect_reasons"].duplicate(),
		"attitude": response["attitude"],
		"outcome": response["outcome"],
		"scene_id": response["scene_id"],
		"momentum_delta": response["momentum_delta"],
		"tone_delta": response["tone_delta"],
		"progression_evaluated": bool(progression.get("evaluated", false)),
		"relationship_state": str(progression.get("state", "")),
		"ruleset_id": response["ruleset_id"],
		"ruleset_status": response["ruleset_status"],
	}

func capture_dating_challenge_state() -> Dictionary:
	var stored: Variant = route_context.get("active_dating_challenge", {})
	if not stored is Dictionary:
		return _transaction_failure(&"invalid_dating_challenge_state",
			"the retained dating challenge must be a dictionary")
	return {"ok": true, "code": &"ok", "value": (stored as Dictionary).duplicate(true),
		"receipt": {}}


func store_dating_challenge_state(candidate: Dictionary, emit_changes: bool = true) -> Dictionary:
	if candidate.is_empty():
		return _transaction_failure(&"invalid_dating_challenge_state",
			"an active dating challenge record is required")
	route_context["active_dating_challenge"] = candidate.duplicate(true)
	if emit_changes: emit_signal("save_relevant_state_changed")
	return {"ok": true, "code": &"ok", "value": {"stored": true}, "receipt": {}}


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
		causal_day_instance: String, causal_day_instance_issuer_receipt: Dictionary, dark_mode: Variant,
		pair_witnessed_forms: Variant = null) -> Dictionary:
	if typeof(dark_mode) != TYPE_BOOL:
		return {"ok": false, "code": &"invalid_run_configuration", "message": "dark_mode must be a Boolean"}
	if run_id.is_empty():
		return {"ok": false, "code": &"invalid_run_id", "message": "run_id must be nonempty"}
	if str(_run_lifecycle.to_dict()["run_id"]) == run_id:
		return {"ok": false, "code": &"run_id_reused", "message": run_id}
	var template: Node = load("res://autoload/GameState.gd").new()
	template.reset_game()
	var defaults: Dictionary = template.to_save_dict()
	template.free()
	# Pair selection belongs to the first counted encounter, with a Profile-owned receipt.
	# Preserve the optional old caller argument only as a validated compatibility input.
	if pair_witnessed_forms != null:
		if not pair_witnessed_forms is Array:
			return {"ok": false, "code": &"invalid_pair_witness_pool"}
		for form: Variant in pair_witnessed_forms:
			if not form is String or form not in _PROVISIONAL_RELATIONSHIP_RULES.PAIR_FORMS:
				return {"ok": false, "code": &"invalid_pair_witness_pool"}
	defaults["inter_friend_route_state"] = {
		"priscilla_lavinia": {"date_count": 0, "dark_points": 0,
			"ending_eligible": false, "provisional_receipts": {}},
	}
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
			"dark_mode": dark_mode,
			"day": 1,
			"state": "PLAYING",
			"active_resolution_plan": null,
			"ending_plan": null,
			"branch_id": branch_id,
			"desktop_timeline_generation": desktop_timeline_generation,
			"causal_day_instance": causal_day_instance,
			"causal_day_instance_issuer_receipt": causal_day_instance_issuer_receipt.duplicate(true),
			"restore_provenance": null,
			# Amendment Plan 03 Task 4 (dwm-oyo.3): a new run starts with no condition-Hospital plan,
			# an empty completed-plan history and no terminal-intent handoff.
			"active_condition_hospital_plan": null,
			"condition_hospital_history": {},
			"terminal_intent_handoff": null,
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
		"dark_mode": snapshot["dark_mode"],
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
		# Amendment Plan 03 Task 4 (dwm-oyo.3, deviation D-7): the three v5 members are likewise
		# carried byte-for-byte. An active condition-Hospital plan must survive its own stage-4 day
		# advance, the history is append-only, and the handoff is null in PLAYING anyway.
		"active_condition_hospital_plan": snapshot["active_condition_hospital_plan"],
		"condition_hospital_history": snapshot["condition_hospital_history"],
		"terminal_intent_handoff": snapshot["terminal_intent_handoff"],
	})
	if restored.get("ok", false):
		_run_lifecycle.commit_restore(restored["value"]["candidate"])


func request_next_ending_command() -> Dictionary:
	if _run_lifecycle.get_state() == &"COMPLETED":
		return {"ok": true, "value": {"kind": "return_completed", "expected_stage": &"COMPLETED"}}
	if _run_lifecycle.get_state() != &"ENDING":
		return {"ok": false, "code": &"not_in_ending", "message": "run is not in the ENDING state"}
	var snapshot: Dictionary = _run_lifecycle.to_dict()
	var lifecycle_plan: Dictionary = snapshot["ending_plan"]
	if lifecycle_plan.has("steps"):
		return _ordered_ending_command(snapshot, lifecycle_plan)
	# Compatibility playback for the previously admitted five-key plan.
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


func _ordered_ending_command(snapshot: Dictionary, plan: Dictionary) -> Dictionary:
	var stage := str(plan["playback_stage"])
	if stage == "EPILOGUE_PLAYED":
		return {"ok": true, "code": &"ok", "value": {
			"kind": &"record_gallery", "expected_stage": &"EPILOGUE_PLAYED"}}
	if stage == "GALLERY_RECORDED":
		return {"ok": true, "code": &"ok", "value": {
			"kind": &"complete_run", "expected_stage": &"GALLERY_RECORDED"}}
	var index := int(plan["next_step_index"])
	var steps: Array = plan["steps"]
	if stage != "PRIMARY_PENDING" or index < 0 or index >= steps.size():
		return {"ok": false, "code": &"invalid_ending_plan", "message": "ordered cursor has no presentation"}
	var step: Dictionary = steps[index]
	var playback_ending_id := str(step["ending_id"])
	if str(step.get("role", "")) == "observer_coda" and playback_ending_id == "ending.priscilla_lavinia.observer":
		var admitted: Dictionary = _validate_pair_observer_admission(snapshot, plan)
		if not admitted.get("ok", false): return admitted
	if str(step["role"]) == "observer_coda":
		if playback_ending_id.ends_with(".observation"):
			playback_ending_id = playback_ending_id.trim_suffix(".observation") + ".observer"
		playback_ending_id += "." + str(step["presentation_variant"])
	var run_id := str(snapshot["run_id"])
	return {"ok": true, "code": &"ok", "value": {
		"kind": &"play_ending",
		"ending_id": playback_ending_id,
		"playback_context": {
			"playback_id": "%s:ending:%d" % [run_id, index],
			"transaction_id": "%s:ending:%d:complete" % [run_id, index],
			"expected_stage": &"PRIMARY_PENDING",
			"role": StringName(str(step["role"])),
		},
	}}


## The planned fourth combination is only a prediction. Physical Sweet completion and
## its durable Profile witness must exist before the pair postscript can start.
func _validate_pair_observer_admission(snapshot: Dictionary, plan: Dictionary, profile: Object = null) -> Dictionary:
	if profile == null and is_inside_tree(): profile = get_node_or_null("/root/ProfileManager")
	if profile == null or not profile.has_method("get_pair_form_witnesses"):
		return _transaction_failure(&"pair_observer_persistence_pending", "Profile evidence is unavailable")
	var witnessed: Dictionary = profile.get_pair_form_witnesses()
	if not witnessed.get("ok", false): return witnessed
	for form: String in _PROVISIONAL_RELATIONSHIP_RULES.PAIR_FORMS:
		if form not in witnessed.value:
			return _transaction_failure(&"pair_observer_persistence_pending", form)
	var index := int(plan.get("next_step_index", 0))
	var steps: Array = plan.get("steps", [])
	var physical := false
	for previous: int in range(mini(index, steps.size())):
		if steps[previous].get("ending_id") != "ending.priscilla_lavinia.sweet" or steps[previous].get("role") != "pair_coda": continue
		var receipt: Dictionary = plan.get("playback_receipts", {}).get("step:%d" % previous, {}).get("value", {})
		physical = receipt.get("outcome") == "completed" and not str(receipt.get("timeline_completion_receipt_id", "")).is_empty()
	if not physical:
		return _transaction_failure(&"pair_observer_sweet_completion_pending", "The preceding Sweet scene has not physically completed")
	var transaction_id := "ending:%s:gallery:ending.priscilla_lavinia.sweet" % str(snapshot.get("run_id", ""))
	var saved: Dictionary = profile.get_profile_snapshot().get("gallery_transaction_receipts", {}).get(transaction_id, {})
	if saved.get("ending_id") != "ending.priscilla_lavinia.sweet":
		return _transaction_failure(&"pair_observer_sweet_completion_pending", "The preceding Sweet completion is not durable")
	return {"ok": true, "code": &"ok"}


## The role that plays out of each legacy play_ending stage.
const _ENDING_STAGE_ROLE := {"PRIMARY_PENDING": "primary", "PRIMARY_PLAYED": "epilogue"}

var _ending_checkpoint_writer: Callable
var _ending_source_reader: Callable
var _ending_condition_source: Object = null
const _DAY7_CONDITION_ENDING_SOURCE := preload("res://scripts/application/ending/Day7ConditionEndingSource.gd")

func configure_ending_checkpoint_writer(writer: Callable) -> Dictionary:
	if not writer.is_valid() or writer.get_argument_count() != 0:
		return {"ok": false, "code": &"invalid_ending_checkpoint_writer"}
	if _ending_checkpoint_writer.is_valid() and _ending_checkpoint_writer != writer:
		return {"ok": false, "code": &"ending_checkpoint_writer_already_configured"}
	_ending_checkpoint_writer = writer
	return {"ok": true, "code": &"ok"}

func configure_ending_source_reader(reader: Callable) -> Dictionary:
	if not reader.is_valid() or reader.get_argument_count() != 0:
		return {"ok": false, "code": &"invalid_ending_source_reader"}
	if _ending_source_reader.is_valid() and _ending_source_reader != reader:
		return {"ok": false, "code": &"ending_source_reader_already_configured"}
	_ending_source_reader = reader
	return {"ok": true, "code": &"ok"}


func configure_ending_condition_source(consequence_state: Object) -> Dictionary:
	for method: String in ["capture", "prepare_outbox_publication", "commit", "rollback"]:
		if consequence_state == null or not consequence_state.has_method(method):
			return {"ok": false, "code": &"invalid_ending_condition_source"}
	if _ending_condition_source != null and _ending_condition_source != consequence_state:
		return {"ok": false, "code": &"ending_condition_source_already_configured"}
	_ending_condition_source = consequence_state
	return {"ok": true, "code": &"ok"}


func resume_terminal_ending() -> Dictionary:
	if _run_lifecycle.get_state() == &"ENDING":
		return {"ok": true, "code": &"ok", "value": {"route": "ending"}}
	if not _ending_checkpoint_writer.is_valid():
		return {"ok": false, "code": &"ending_checkpoint_writer_unconfigured"}
	var lease: Dictionary = _acquire_ending_lease()
	if not lease.get("ok", false): return lease
	var result: Dictionary = _admit_terminal_ending()
	var released: Dictionary = _release_ending_lease(lease)
	if not released.get("ok", false): return released
	if result.get("ok", false): emit_signal("save_relevant_state_changed")
	return result


func _admit_terminal_ending() -> Dictionary:
	var snapshot: Dictionary = _run_lifecycle.to_dict()
	if int(snapshot.day) != 7 or snapshot.ending_plan != null:
		return {"ok": false, "code": &"day7_terminal_source_unavailable"}
	var condition_source: Dictionary = {}
	var consequence_backup: Dictionary = {}
	if str(snapshot.state) == "PLAYING":
		if _ending_condition_source != null:
			var captured: Dictionary = _ending_condition_source.capture()
			if not captured.get("ok", false): return captured
			var desktop: Dictionary = captured.value.state
			var destination: Variant = desktop.get("outbox", {}).get("hospital")
			if destination is Dictionary and destination.get("consumer") == "day7_terminal":
				var validated: Dictionary = _DAY7_CONDITION_ENDING_SOURCE.validate(desktop, snapshot,
					_canonical_committed_schedule(), contacts, _identity_issuer)
				if not validated.get("ok", false): return validated
				condition_source = validated.value
				consequence_backup = captured.value
		if condition_source.is_empty():
			if not _ending_source_reader.is_valid(): return {"ok": false, "code": &"ending_source_reader_unconfigured"}
			var source: Dictionary = _ending_source_reader.call()
			if not source.get("ok", false): return source
	elif str(snapshot.state) == "TERMINAL_PENDING":
		var handoff: Dictionary = snapshot.terminal_intent_handoff
		if _identity_issuer == null: return {"ok": false, "code": &"identity_issuer_unconfigured"}
		var proof: Dictionary = _identity_issuer.verify_issued(handoff.source_transaction_issuer_receipt, &"transaction_id")
		if not proof.get("ok", false): return proof
		if str(handoff.source_transaction_issuer_receipt.get("token", "")) != str(handoff.source_transaction_id):
			return {"ok": false, "code": &"terminal_source_identity_mismatch"}
		# The composed condition path consumes its existing outbox directly. Unknown legacy
		# TERMINAL_PENDING packets still have no semantic owner and cannot be reinterpreted.
		return {"ok": false, "code": &"terminal_intent_semantics_unavailable"}
	else:
		return {"ok": false, "code": &"day7_terminal_source_unavailable"}
	var provisional: Dictionary = prepare_provisional_day7_ending_plan() if condition_source.is_empty() else _prepare_day7_ending_plan(condition_source)
	if not provisional.get("ok", false): return provisional
	var plan: Dictionary = _ordered_plan_from_provisional(provisional.value)
	if plan.is_empty(): return {"ok": false, "code": &"ending_plan_unavailable"}
	var publication: Dictionary = {}
	var closure: Dictionary = {}
	var closure_identity: Dictionary = {}
	if not condition_source.is_empty():
		publication = _ending_condition_source.prepare_outbox_publication(condition_source.publication_request)
		if not publication.get("ok", false): return publication
		var sources: Array = [
			_DAY7_CONDITION_ENDING_SOURCE._projection("role", "day7_condition.close_invitations"),
			_DAY7_CONDITION_ENDING_SOURCE._projection("destination_intent_id", condition_source.publication_request.key)]
		sources.sort()
		var derived: Dictionary = _identity_issuer.derive_child({"child_kind": "terminal_intent", "ordinal": 0,
			"parent_receipt_id": str(condition_source.transaction_issuer_receipt.receipt_id), "source_ids": sources})
		if not derived.get("ok", false): return derived
		closure_identity = derived.value
		var verified: Dictionary = _identity_issuer.validate_child(closure_identity.provenance, &"terminal_intent")
		if not verified.get("ok", false): return verified
		closure = _CONTACT_INVITATION_STATE.prepare_resolve_day_end(contacts, 7, {}, str(closure_identity.child_id))
		if not closure.get("ok", false): return closure
	var captured: Dictionary = capture_restore_state()
	if not captured.get("ok", false): return captured
	var backup: Dictionary = captured.value.backup
	var admitted: Dictionary = _run_lifecycle.enter_ending(plan)
	if not admitted.get("ok", false): return admitted
	route_context["provisional_ending_plan"] = provisional.value.duplicate(true)
	route_context["ending_id"] = str(plan.ending_id)
	route_context["epilogue_ending_id"] = str(plan.epilogue_ending_id)
	if not condition_source.is_empty():
		if _frozen_ending_contexts_enabled:
			var frozen_contacts := preload("res://scripts/narrative/ContactsFrozenContext.gd").capture_candidate(
				contacts, closure.value.candidate, capture_run_snapshot_input().gameplay, 7)
			if not frozen_contacts.ok: return _rollback_ending_admission(backup, consequence_backup, frozen_contacts)
			_apply_gameplay_silent(frozen_contacts.value)
		contacts = closure.value.candidate.duplicate(true)
		var cause := str(condition_source.terminal_cause)
		route_context["day7_condition_ending"] = {
			"terminal_cause": cause, "destination_intent_id": condition_source.publication_request.key,
			"payload_hash": condition_source.publication_request.payload_hash,
			"sylvia_read_receipt_id": condition_source.sylvia_read_receipt_id,
			"closure_receipt_id": closure_identity.child_id,
			"closure_receipt_provenance": closure_identity.provenance.duplicate(true),
			"stored_tone": "dark" if int((dating_route_state.get("sylvia", {}) as Dictionary).get("dark_points", 0)) >= _PROVISIONAL_RELATIONSHIP_RULES.DARK_TONE_THRESHOLD else "sweet",
			"ending_form": "special_forced_dark" if cause == "sylvia_special" else ("dark_mode" if cause == "dark_mode_alone" else "normal")}
		var published: Dictionary = _ending_condition_source.commit(publication.value.candidate)
		if not published.get("ok", false): return _rollback_ending_admission(backup, consequence_backup, published)
	if _frozen_ending_contexts_enabled:
		var seed := _capture_ending_frozen_seed(provisional.value)
		if not seed.ok: return _rollback_ending_admission(backup, consequence_backup, seed)
		route_context["ending_frozen_contexts_v1"] = {"schema_version": 1, "seed": seed.value, "presentations": {}}
	var saved: Dictionary = _ending_checkpoint_writer.call()
	if not saved.get("ok", false): return _rollback_ending_admission(backup, consequence_backup, saved)
	return {"ok": true, "code": &"ok", "value": {"route": "ending"}}


func _rollback_ending_admission(backup: Dictionary, consequence_backup: Dictionary, failure: Dictionary) -> Dictionary:
	var rolled: Dictionary = rollback_restore_silent(backup)
	if not consequence_backup.is_empty():
		var restored: Dictionary = _ending_condition_source.rollback(consequence_backup)
		if not restored.get("ok", false): return restored
	return failure if rolled.get("ok", false) else rolled


func _acquire_ending_lease() -> Dictionary:
	if _mutation_gate == null: return {"ok": true, "value": {"token": ""}}
	return _mutation_gate.acquire(&"causal_transaction")


func _release_ending_lease(lease: Dictionary) -> Dictionary:
	if _mutation_gate == null: return {"ok": true}
	return _mutation_gate.release(&"causal_transaction", str(lease.value.token))


func complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary:
	if _run_lifecycle.get_state() == &"COMPLETED" and expected_stage == &"COMPLETED":
		if not transaction_id.is_empty() or not receipt.is_empty():
			return _transaction_failure(&"invalid_completed_ending_return", "no new playback receipt belongs to a completed run")
		var completed_lease := _acquire_ending_lease()
		if not completed_lease.get("ok", false): return completed_lease
		_retire_completed_ending_session()
		var completed_release := _release_ending_lease(completed_lease)
		return {"ok": true, "value": {"route": "menu"}} if completed_release.get("ok", false) else completed_release
	var replay: Dictionary = _completed_ordered_ending_replay(transaction_id, expected_stage, receipt)
	if not replay.is_empty(): return replay
	var lease: Dictionary = _acquire_ending_lease()
	if not lease.get("ok", false): return lease
	var result: Dictionary = _commit_ending_playback_completion(transaction_id, expected_stage, receipt)
	var released: Dictionary = _release_ending_lease(lease)
	if not released.get("ok", false): return released
	if result.get("ok", false): emit_signal("save_relevant_state_changed")
	return result


func _commit_ending_playback_completion(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary:
	var captured: Dictionary = capture_restore_state()
	if not captured.get("ok", false): return captured
	var completed: Dictionary = _complete_ending_playback_stage(transaction_id, expected_stage, receipt)
	if not completed.get("ok", false): return completed
	if _ending_checkpoint_writer.is_valid():
		var saved: Dictionary = _ending_checkpoint_writer.call()
		if not saved.get("ok", false):
			var restored: Dictionary = rollback_restore_silent(captured.value.backup)
			return saved if restored.get("ok", false) else restored
	_retire_completed_ending_session()
	return completed

func _retire_completed_ending_session() -> void:
	if _run_lifecycle.get_state() != &"COMPLETED" or not _live_session_active: return
	# The terminal snapshot is already durable, including when it has just been loaded.
	var handle: Dictionary = _live_session_fact()
	_invalidate_live_session()
	_run_configuration_installed = false
	_retired_live_session_handle = handle
	_retired_live_session_generation = _live_session_generation

func _completed_ordered_ending_replay(transaction_id: String, stage: StringName, receipt: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _run_lifecycle.to_dict()
	var plan: Variant = snapshot.get("ending_plan")
	if not plan is Dictionary or not plan.has("steps"): return {}
	for index in int(plan.next_step_index):
		if transaction_id != "%s:ending:%d:complete" % [str(snapshot.run_id), index]: continue
		var previous: Dictionary = plan.playback_receipts.get("step:%d" % index, {})
		if stage != &"PRIMARY_PENDING" or previous != {"value": receipt}:
			return {"ok": false, "code": &"duplicate_transaction_conflict"}
		return {"ok": true, "code": &"ok", "value": previous.value.duplicate(true)}
	return {}


func _complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary:
	if _run_lifecycle.get_state() != &"ENDING":
		return {"ok": false, "code": &"not_in_ending", "message": "run is not in the ENDING state"}
	var lifecycle_plan: Dictionary = _run_lifecycle.to_dict()["ending_plan"]
	if lifecycle_plan.has("steps"):
		var ordered_command: Dictionary = _ordered_ending_command(_run_lifecycle.to_dict(), lifecycle_plan)
		if not ordered_command.get("ok", false):
			return ordered_command
		var ordered_value: Dictionary = ordered_command["value"]
		var actual_stage: String = str(ordered_value.playback_context.expected_stage) \
			if str(ordered_value.kind) == "play_ending" else str(ordered_value.get("expected_stage", ""))
		if actual_stage != String(expected_stage):
			return {"ok": false, "code": &"playback_stage_mismatch", "message": String(expected_stage)}
		match str(ordered_value["kind"]):
			"play_ending":
				return _complete_play_ending(String(expected_stage), transaction_id, receipt)
			"record_gallery":
				return _complete_record_gallery(String(expected_stage), lifecycle_plan)
			"complete_run":
				return _complete_run()
		return {"ok": false, "code": &"invalid_ending_command", "message": str(ordered_value["kind"])}
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
	return {"ok": true, "code": &"ok", "value": {"route": "menu"}}

func _complete_play_ending(stage: String, transaction_id: String, receipt: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _run_lifecycle.to_dict()
	var plan: Dictionary = snapshot["ending_plan"]
	var run_id := str(snapshot["run_id"])
	var lifecycle_transaction := ""
	if plan.has("steps"):
		var index := int(plan["next_step_index"])
		if stage != "PRIMARY_PENDING" \
				or transaction_id != "%s:ending:%d:complete" % [run_id, index]:
			return {"ok": false, "code": &"transaction_mismatch", "message": transaction_id}
		if receipt.size() != 2 or str(receipt.get("outcome", "")) != "completed" \
				or typeof(receipt.get("timeline_completion_receipt_id")) != TYPE_STRING \
				or str(receipt.get("timeline_completion_receipt_id", "")).strip_edges().is_empty():
			return {"ok": false, "code": &"invalid_ending_completion_receipt"}
		var unlocked: Dictionary = _record_completed_ending_step(plan.steps[index], run_id)
		if not unlocked.get("ok", false): return unlocked
		lifecycle_transaction = "ending:step:%d" % index
	else:
		if transaction_id != "%s:%s:complete" % [run_id, str(_ENDING_STAGE_ROLE[stage])]:
			return {"ok": false, "code": &"transaction_mismatch", "message": transaction_id}
		lifecycle_transaction = "ending:" + stage
	var result: Dictionary = _run_lifecycle.complete_ending_playback_stage(
		lifecycle_transaction, StringName(stage), {"value": receipt.duplicate(true)})
	return result

func _complete_record_gallery(stage: String, lifecycle_plan: Dictionary) -> Dictionary:
	var profile: Node = get_node_or_null("/root/ProfileManager")
	if profile == null: return {"ok": false, "code": &"profile_unavailable"}
	var run_id: String = str(_run_lifecycle.to_dict().run_id)
	var gallery_receipts: Dictionary = {}
	if lifecycle_plan.has("steps"):
		for index in range((lifecycle_plan.steps as Array).size()):
			var unlocked: Dictionary = _record_completed_ending_step(lifecycle_plan.steps[index], run_id)
			if not unlocked.get("ok", false): return unlocked
			gallery_receipts["step:%d" % index] = unlocked.value
	else:
		# Existing admitted five-key plans remain resumable. Their two physical stages have
		# completed before this compatibility Gallery tail can be reached.
		for role: String in ["primary", "epilogue"]:
			var ending_id: String = str(lifecycle_plan.ending_id if role == "primary" else lifecycle_plan.epilogue_ending_id)
			if ending_id.is_empty(): continue
			var unlocked: Dictionary = profile.record_ending_completion(ending_id,
				"ending:%s:gallery:%s" % [run_id, ending_id])
			if not unlocked.get("ok", false): return unlocked
			gallery_receipts[role] = unlocked.value
	return _run_lifecycle.complete_ending_playback_stage(
		"ending:" + stage, StringName(stage), {"value": gallery_receipts})


func _record_completed_ending_step(step: Dictionary, run_id: String) -> Dictionary:
	var profile: Node = get_node_or_null("/root/ProfileManager")
	if profile == null: return {"ok": false, "code": &"profile_unavailable"}
	var ending_id: String = str(step.ending_id)
	var pair_form: String = str(step.get("pair_form", "")) if str(step.role) == "pair_coda" else ""
	return profile.record_ending_completion(ending_id, "ending:%s:gallery:%s" % [run_id, ending_id], pair_form)


func get_frozen_ordered_ending_plan() -> Dictionary:
	var prepared: Dictionary = prepare_provisional_day7_ending_plan()
	if not prepared.get("ok", false): return {}
	return _ordered_plan_from_provisional(prepared.value)


func _ordered_plan_from_provisional(provisional: Dictionary) -> Dictionary:
	var steps: Array = ((provisional as Dictionary).get("steps", []) as Array).duplicate(true)
	if steps.is_empty():
		return {}
	var pair_present := false
	for raw: Variant in steps:
		if typeof(raw) == TYPE_DICTIONARY and str((raw as Dictionary).get("role", "")) == "pair_coda":
			pair_present = true
	return {
		"ending_id": str((steps[0] as Dictionary).get("ending_id", "")),
		"epilogue_ending_id": "ending.priscilla_lavinia" if pair_present else "",
		"source_day": 7,
		"playback_stage": "PRIMARY_PENDING",
		"playback_receipts": {},
		"steps": steps,
		"next_step_index": 0,
	}


func _lifecycle_ensure_ending(ending_id: String, epilogue_ending_id: String) -> void:
	if _run_lifecycle.get_state() != &"PLAYING":
		return
	if _run_lifecycle.get_day() != 7:
		_lifecycle_set_playing_day(7)
	var ordered: Dictionary = get_frozen_ordered_ending_plan()
	if not ordered.is_empty():
		var admitted: Dictionary = _run_lifecycle.enter_ending(ordered)
		if admitted.get("ok", false):
			route_context["ending_id"] = ordered["ending_id"]
			route_context["epilogue_ending_id"] = ordered["epilogue_ending_id"]
			return
		push_error("GameState: frozen ordered ending plan was refused: %s" % str(admitted))
		return
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
	var dating_backup: Variant = null
	if _dating_restore_owner != null:
		var captured: Dictionary = _dating_restore_owner.capture_reconciliation_state()
		if not captured.get("ok", false): return captured
		dating_backup = captured.value.duplicate(true)
	var gameplay := to_save_dict().duplicate(true)
	gameplay["narrative_variables"] = _narrative_variables.duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"gameplay": gameplay,
		"dating_reconciliation": dating_backup,
		"command_receipts": _command_receipts.duplicate(true),
		"applied_effect_transaction_ids": _applied_effect_transaction_ids.duplicate(true),
		"applied_variable_transaction_ids": _applied_variable_transaction_ids.duplicate(true),
		"lifecycle": _run_lifecycle.to_dict(),
		"run_configuration_installed": _run_configuration_installed,
		"session_generation": _live_session_generation,
		"contacts": contacts.duplicate(true),
		# v3 (Plan 01 Task 5): the canonical aggregate is part of the restore transaction, so a
		# later participant failure rolls it back with everything else.
		"committed_schedule": _canonical_committed_schedule(),
		# v4 (Plan 02 Task 6, dwm-p2r.32): the desktop aggregate travels with the same restore
		# transaction, so a later participant failure rolls it back with everything else too.
		"desktop": _capture_desktop_snapshot(),
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


func capture_live_run_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"gameplay": to_save_dict().duplicate(true),
		"contacts": contacts.duplicate(true),
		"command_receipts": _command_receipts.duplicate(true),
		"applied_effect_transaction_ids": _applied_effect_transaction_ids.duplicate(true),
		"applied_variable_transaction_ids": _applied_variable_transaction_ids.duplicate(true),
		"narrative_variables": _narrative_variables.duplicate(true),
	}}}


func restore_live_run_state(backup: Dictionary) -> Dictionary:
	var source: Variant = backup.get("backup", backup)
	if typeof(source) != TYPE_DICTIONARY or not (source as Dictionary).has("command_receipts"):
		return _transaction_failure(&"invalid_run_backup", "backup was not issued by capture_live_run_state")
	var detached: Dictionary = source as Dictionary
	if typeof(detached.get("gameplay")) == TYPE_DICTIONARY:
		apply_save_dict(detached["gameplay"].duplicate(true))
	if typeof(detached.get("contacts")) == TYPE_DICTIONARY:
		contacts = (detached["contacts"] as Dictionary).duplicate(true)
	_command_receipts = (detached["command_receipts"] as Dictionary).duplicate(true)
	_applied_effect_transaction_ids = (detached["applied_effect_transaction_ids"] as Array).duplicate(true)
	_applied_variable_transaction_ids = (detached["applied_variable_transaction_ids"] as Array).duplicate(true)
	_narrative_variables = (detached["narrative_variables"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


## Captures the last activated session, not candidate bytes temporarily applied by
## Restore. Validation separately fences callbacks while a transaction owns the gate.
func capture_live_session() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": _live_session_fact()}


## Internal capture remains usable by the current causal transaction. External
## commands separately validate the session and shared gate before mutation.
func capture_desktop_identity_context() -> Dictionary:
	if not _live_session_active or not _run_configuration_installed:
		return _session_failure(&"stale_live_session")
	var identity: Dictionary = _run_lifecycle.get_desktop_identity_context()
	if str(identity.run_id) != _live_session_run_id:
		return _session_failure(&"stale_live_session")
	identity.erase("causal_day_instance_issuer_receipt")
	return {"ok": true, "value": identity.duplicate(true)}

func validate_live_session(handle: Variant) -> Dictionary:
	if not is_instance_valid(_mutation_gate): return _session_failure(&"session_gate_unconfigured")
	var admitted: Dictionary = _mutation_gate.guard_external(&"live_session")
	if not admitted.get("ok", false): return admitted
	if not handle is Dictionary or not _live_session_active or handle != _live_session_fact() 			or not _run_configuration_installed or str(_run_lifecycle.to_dict().run_id) != _live_session_run_id:
		return _session_failure(&"stale_live_session")
	return {"ok": true, "code": &"ok", "value": {"valid": true}}

func capture_live_run_snapshot_input(handle: Variant) -> Dictionary:
	var admitted := validate_live_session(handle)
	if not admitted.get("ok", false): return admitted
	return {"ok": true, "code": &"ok", "value": capture_run_snapshot_input()}

## SaveManager freezes this ticket before apply, checks it before route dispatch,
## and activates only after every participant has finalized successfully.
func validate_live_session_activation(ticket: Variant) -> Dictionary:
	if not is_instance_valid(_mutation_gate) or not (
		_mutation_gate.is_internal_owner_active(&"restore") or _mutation_gate.is_internal_owner_active(&"new_run")):
		return _session_failure(&"session_activation_custody_required")
	if not ticket is Dictionary or ticket.size() != 4 			or typeof(ticket.get("expected_generation")) != TYPE_INT or ticket.expected_generation < 0 			or typeof(ticket.get("owner_id")) != TYPE_INT or ticket.owner_id != get_instance_id() 			or typeof(ticket.get("operation_id")) != TYPE_STRING or ticket.operation_id.strip_edges().is_empty() 			or typeof(ticket.get("run_id")) != TYPE_STRING or ticket.run_id.strip_edges().is_empty():
		return _session_failure(&"invalid_session_activation")
	if not _run_configuration_installed or str(_run_lifecycle.to_dict().run_id) != ticket.run_id:
		return _session_failure(&"session_candidate_mismatch")
	if not _live_session_activation_ticket.is_empty() 			and ticket.operation_id == _live_session_activation_ticket.operation_id:
		if ticket == _live_session_activation_ticket and _live_session_active 				and _live_session_generation == ticket.expected_generation + 1 and _live_session_run_id == ticket.run_id:
			return {"ok": true, "code": &"ok", "value": {"already_active": true}}
		return _session_failure(&"stale_session_activation")
	if ticket.expected_generation != _live_session_generation:
		return _session_failure(&"stale_session_activation")
	return {"ok": true, "code": &"ok", "value": {"already_active": false}}

func activate_live_session(ticket: Variant) -> Dictionary:
	var admitted := validate_live_session_activation(ticket)
	if not admitted.get("ok", false): return admitted
	if not admitted.value.already_active:
		_live_session_generation += 1
		_live_session_active = true
		_live_session_run_id = ticket.run_id
		_live_session_activation_ticket = ticket.duplicate(true)
	return {"ok": true, "code": &"ok", "value": _live_session_fact()}

func retire_live_session(handle: Variant) -> Dictionary:
	if not is_instance_valid(_mutation_gate) or not _mutation_gate.is_internal_owner_active(&"session_abandonment"):
		return _session_failure(&"session_abandonment_custody_required")
	if not handle is Dictionary: return _session_failure(&"stale_live_session")
	if not _live_session_active:
		if not _retired_live_session_handle.is_empty() and handle == _retired_live_session_handle 				and _live_session_generation == _retired_live_session_generation:
			return {"ok": true, "code": &"ok", "value": {"retired": true}}
		return _session_failure(&"stale_live_session")
	if handle != _live_session_fact() or not _run_configuration_installed 			or str(_run_lifecycle.to_dict().run_id) != _live_session_run_id:
		return _session_failure(&"stale_live_session")
	_invalidate_live_session()
	_run_configuration_installed = false
	_retired_live_session_handle = handle.duplicate(true)
	_retired_live_session_generation = _live_session_generation
	return {"ok": true, "code": &"ok", "value": {"retired": true}}

func _invalidate_live_session() -> void:
	_live_session_generation += 1
	_live_session_active = false
	_live_session_run_id = ""
	_retired_live_session_handle.clear()
	_retired_live_session_generation = -1

func _live_session_fact() -> Dictionary:
	return {"active": _live_session_active, "generation": _live_session_generation,
		"run_id": _live_session_run_id, "owner_id": get_instance_id()}

static func _session_failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}


## Public run configuration exists only after validated snapshot installation.
## Reset/local fixture state and detached New Run preparation grant no live-run evidence.
func get_run_configuration() -> Dictionary:
	if not _run_configuration_installed:
		return {"ok": false, "code": &"run_configuration_unavailable"}
	return {"ok": true, "value": {"dark_mode": _run_lifecycle.to_dict()["dark_mode"]}}


## Replacement consent concerns the installed unfinished state held by this owner.
## A raw menu route does not abandon it. No-save Return must later invalidate its
## session through the actual lifecycle owner; this read seam does not implement Return.
func get_new_run_replacement_baseline() -> Dictionary:
	var captured: Dictionary = capture_restore_state()
	if not captured.get("ok", false):
		return {"ok": false, "code": &"new_run_replacement_unavailable"}
	var backup: Dictionary = captured["value"]["backup"]
	var encoded: Dictionary = _CANONICAL_JSON.stringify(backup)
	if not encoded.get("ok", false):
		return {"ok": false, "code": &"new_run_replacement_unavailable"}
	var present: bool = backup["run_configuration_installed"] and backup["lifecycle"]["state"] in ["PLAYING", "ENDING"]
	return {"ok": true, "value": {"present": present, "revision": str(encoded["value"]).sha256_text()}}


## Pure read seam for the shared narrative checkpoint adapter (dwm-p2r.8, Plan-05 Task 2).
## Returns the complete detached CURRENT RunSnapshot input without mutation or publication.
func configure_desktop_snapshot_provider(provider: Callable) -> Dictionary:
	if not provider.is_valid() or provider.get_argument_count() != 0:
		return {"ok": false, "code": &"invalid_desktop_snapshot_provider"}
	if _desktop_snapshot_provider.is_valid() and _desktop_snapshot_provider != provider:
		return {"ok": false, "code": &"desktop_snapshot_provider_already_configured"}
	_desktop_snapshot_provider = provider
	return {"ok": true}


func _capture_desktop_snapshot() -> Dictionary:
	if not _desktop_snapshot_provider.is_valid(): return _desktop_snapshot.duplicate(true)
	var captured: Variant = _desktop_snapshot_provider.call()
	return captured.duplicate(true) if captured is Dictionary else {}


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
		"desktop": _capture_desktop_snapshot(),
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


var _dating_restore_reconciler: Callable
var _dating_restore_owner: Object

func configure_dating_restore_reconciler(reconciler: Callable) -> Dictionary:
	if not reconciler.is_valid(): return _transaction_failure(&"invalid_dating_restore_reconciler", "")
	if _dating_restore_reconciler.is_valid() and _dating_restore_reconciler != reconciler:
		return _transaction_failure(&"dating_restore_reconciler_conflict", "")
	var physical_owner: Object = reconciler.get_object()
	if not is_instance_valid(physical_owner) or not physical_owner.has_method("capture_reconciliation_state") \
			or not physical_owner.has_method("rollback_reconciliation_silent"):
		return _transaction_failure(&"invalid_dating_restore_reconciler", "local rollback owner required")
	_dating_restore_reconciler = reconciler
	_dating_restore_owner = physical_owner
	return {"ok": true, "value": {}}

func apply_restore_silent(plan: Dictionary) -> Dictionary:
	var snapshot: Variant = plan.get("snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_run_plan", "message": "run plan requires a snapshot"}
	var applied := _apply_run_snapshot_silent(snapshot as Dictionary)
	if not applied.get("ok", false): return applied
	if _dating_restore_reconciler.is_valid(): return _dating_restore_reconciler.call(snapshot as Dictionary)
	return applied


func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	var source: Variant = backup.get("backup", backup)
	if not source is Dictionary or typeof(source.get("session_generation")) != TYPE_INT 			or source.session_generation != _live_session_generation:
		return {"ok": false, "code": &"stale_run_backup", "message": "session lifetime changed"}

	if typeof(source) != TYPE_DICTIONARY or typeof((source as Dictionary).get("gameplay")) != TYPE_DICTIONARY \
			or typeof((source as Dictionary).get("lifecycle")) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_run_backup", "message": "run backup requires gameplay and lifecycle"}
	if typeof(source.get("run_configuration_installed")) != TYPE_BOOL:
		return {"ok": false, "code": &"invalid_run_backup", "message": "run installation evidence is required"}
	var bookkeeping := _prepare_restore_bookkeeping(source, true)
	if not bookkeeping.get("ok", false):
		return bookkeeping
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
	# All GameState backup validation is complete. Restore the retained Dating owner's
	# local state before the synchronous, silent assignments below; stale sessions were
	# rejected above, and no Profile history is copied backward.
	var dating_backup: Variant = source.get("dating_reconciliation")
	if _dating_restore_owner != null:
		if not dating_backup is Dictionary:
			return _transaction_failure(&"invalid_dating_reconciliation_backup", "local owner backup required")
		var dating_restored: Dictionary = _dating_restore_owner.rollback_reconciliation_silent(dating_backup)
		if not dating_restored.get("ok", false): return dating_restored
	elif dating_backup != null:
		return _transaction_failure(&"invalid_dating_reconciliation_backup", "local owner is not configured")
	_run_lifecycle.commit_restore(restored["value"]["candidate"])
	_apply_gameplay_silent((source as Dictionary)["gameplay"])
	_apply_restore_bookkeeping(bookkeeping["value"])
	_restore_contacts_section((source as Dictionary).get("contacts"))
	if not validated_backup.is_empty():
		_committed_schedule = (validated_backup["value"] as Dictionary)["committed_schedule"]
	if typeof(desktop_backup) == TYPE_DICTIONARY:
		_desktop_snapshot = (desktop_backup as Dictionary).duplicate(true)
	_run_configuration_installed = source["run_configuration_installed"]
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
func apply_continuation_remap_silent(restore_transaction_id: String, identity_allocation_bundle: Dictionary,
		source_identity: Dictionary) -> Dictionary:
	var prepared: Dictionary = _run_lifecycle.prepare_continuation_remap(restore_transaction_id, identity_allocation_bundle, source_identity)
	if not prepared.get("ok", false):
		return prepared
	return _run_lifecycle.commit_continuation_remap((prepared["value"] as Dictionary)["candidate"])


func _apply_run_snapshot_silent(snapshot: Dictionary) -> Dictionary:
	if typeof(snapshot.get("lifecycle")) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_run_plan", "message": "snapshot.lifecycle is required"}
	var bookkeeping := _prepare_restore_bookkeeping(snapshot)
	if not bookkeeping.get("ok", false):
		return bookkeeping
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
	_apply_restore_bookkeeping(bookkeeping["value"])
	_restore_contacts_section(snapshot.get("contacts"))
	if not validated_committed.is_empty():
		_committed_schedule = (validated_committed["value"] as Dictionary)["committed_schedule"]
	if typeof(desktop) == TYPE_DICTIONARY:
		_desktop_snapshot = (desktop as Dictionary).duplicate(true)
	_run_configuration_installed = true
	return {"ok": true, "code": &"ok"}


## Canonical saves carry all receipt fields; old partial owner plans may omit the
## whole group. Live rollback preserves insertion order, unlike sorted disk IDs.
func _prepare_restore_bookkeeping(source: Dictionary, live_backup: bool = false) -> Dictionary:
	var candidate := {}
	var ledger_fields := ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]
	var has_ledger := false
	for field: String in ledger_fields:
		has_ledger = has_ledger or source.has(field)
	if has_ledger:
		for field: String in ledger_fields:
			if not source.has(field):
				return _transaction_failure(&"invalid_run_bookkeeping", "incomplete transaction ledger")
		for field: String in ["applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
			var ids: Variant = source[field]
			if typeof(ids) != TYPE_ARRAY:
				return _transaction_failure(&"invalid_run_bookkeeping", field + " must be an array")
			var checked: Array = ids.duplicate(true)
			# Validate elements before sorting so malformed mixed types cannot error.
			for id: Variant in checked:
				if typeof(id) != TYPE_STRING or str(id).is_empty():
					return _transaction_failure(&"invalid_run_bookkeeping", "invalid transaction ID")
			if live_backup:
				checked.sort()
			var ids_error := _NARRATIVE_VARIABLE_SCHEMA._validate_transaction_ids(checked, field)
			if ids_error != "":
				return _transaction_failure(&"invalid_run_bookkeeping", ids_error)
		var receipt_error := _NARRATIVE_VARIABLE_SCHEMA._validate_command_receipts(source["command_receipts"],
			source["applied_effect_transaction_ids"], source["applied_variable_transaction_ids"])
		if receipt_error != "":
			return _transaction_failure(&"invalid_run_bookkeeping", receipt_error)
		var checked_receipts: Dictionary = source["command_receipts"].duplicate(true)
		if live_backup:
			for receipt: Dictionary in checked_receipts.values():
				# The live recorder stores its registered kind as StringName. Validate
				# its wire spelling without changing the exact captured owner value.
				if typeof(receipt["kind"]) == TYPE_STRING_NAME:
					receipt["kind"] = str(receipt["kind"])
		var primitive := _NARRATIVE_VARIABLE_SCHEMA.validate_primitive_tree(checked_receipts, "$.command_receipts")
		if not primitive.get("ok", false):
			return primitive
		for field: String in ledger_fields:
			candidate[field] = source[field].duplicate(true)
	var gameplay: Variant = source.get("gameplay")
	if typeof(gameplay) == TYPE_DICTIONARY and gameplay.has("narrative_variables"):
		var variables_error := _NARRATIVE_VARIABLE_SCHEMA._validate_gameplay({"narrative_variables": gameplay["narrative_variables"]})
		if variables_error != "":
			return _transaction_failure(&"invalid_run_bookkeeping", variables_error)
		candidate["narrative_variables"] = gameplay["narrative_variables"].duplicate(true)
	return {"ok": true, "code": &"ok", "value": candidate}


func _apply_restore_bookkeeping(candidate: Dictionary) -> void:
	if candidate.has("command_receipts"):
		_command_receipts = candidate["command_receipts"].duplicate(true)
		_applied_effect_transaction_ids = candidate["applied_effect_transaction_ids"].duplicate(true)
		_applied_variable_transaction_ids = candidate["applied_variable_transaction_ids"].duplicate(true)
	if candidate.has("narrative_variables"):
		_narrative_variables = candidate["narrative_variables"].duplicate(true)


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
	var day7_admitted := require_day7_presentations_complete()
	if not day7_admitted.get("ok", false): return day7_admitted
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
			self.set(key, v.duplicate(true))
		elif v is Array:
			self.set(key, v.duplicate(true))
		else:
			self.set(key, v)



# Root integration: append these methods to GameState.gd. No new gameplay owner or
# receipt is created; this is a saved presentation cache in the existing Run bag.
func read_hospital_presentation_request(resolution_id: String) -> Dictionary:
	const HOSPITAL_FROZEN := preload("res://scripts/narrative/HospitalFrozenContext.gd")
	var cache: Variant = route_context.get("hospital_frozen_contexts_v1")
	if cache == null: return {"ok": true, "value": {}}
	if not cache is Dictionary or cache.size() != 2 or cache.get("schema_version") != 1 \
			or not cache.get("requests") is Dictionary:
		return _transaction_failure(&"hospital_frozen_context_invalid", "")
	for key: Variant in cache.requests:
		if not key is String: return _transaction_failure(&"hospital_frozen_context_invalid", "")
		var checked: Dictionary = HOSPITAL_FROZEN.validate_request(cache.requests[key])
		if not checked.get("ok", false): return checked
		if checked.value.resolution_id != key:
			return _transaction_failure(&"hospital_frozen_request_mismatch", key)
	var saved: Dictionary = cache.requests.get(resolution_id, {})
	if saved.is_empty(): return {"ok": true, "value": {}}
	var plan: Variant = _run_lifecycle.to_dict().get("active_resolution_plan")
	if not plan is Dictionary or plan.get("resolution_id") != resolution_id \
			or saved.context.day != plan.get("source_day") \
			or saved.resolution_issuer_receipt != plan.get("resolution_issuer_receipt"):
		return _transaction_failure(&"hospital_frozen_request_mismatch", resolution_id)
	var stage_id := ""
	for stage: Dictionary in plan.get("stages", []):
		if stage.get("stage_id") == "hospital_if_triggered": stage_id = str(stage.transaction_id)
	if saved.stage_id != stage_id:
		return _transaction_failure(&"hospital_frozen_request_mismatch", resolution_id)
	return {"ok": true, "value": saved.duplicate(true)}

func retain_hospital_presentation_request(request: Dictionary) -> Dictionary:
	const HOSPITAL_FROZEN := preload("res://scripts/narrative/HospitalFrozenContext.gd")
	var checked: Dictionary = HOSPITAL_FROZEN.validate_request(request)
	if not checked.get("ok", false): return checked
	var prior := read_hospital_presentation_request(str(request.resolution_id))
	if not prior.get("ok", false): return prior
	if not prior.value.is_empty():
		return prior if prior.value == request else _transaction_failure(&"hospital_frozen_request_conflict", request.resolution_id)
	if not _contact_checkpoint_writer.is_valid() or _mutation_gate == null:
		return _transaction_failure(&"hospital_frozen_store_unavailable", "")
	var lease := {}
	if _mutation_gate.is_active():
		if _mutation_gate.get_active_owner() != &"causal_transaction":
			return _transaction_failure(&"hospital_frozen_store_busy", "")
	else:
		lease = _mutation_gate.acquire(&"causal_transaction")
		if not lease.get("ok", false): return lease
	var backup: Dictionary = capture_restore_state()
	if not backup.get("ok", false):
		if not lease.is_empty(): _mutation_gate.release(&"causal_transaction", str(lease.value.token))
		return backup
	var cache: Dictionary = route_context.get("hospital_frozen_contexts_v1", {"schema_version": 1, "requests": {}}).duplicate(true)
	cache.requests[request.resolution_id] = checked.value
	route_context["hospital_frozen_contexts_v1"] = cache
	# Bind to this exact persisted resolution before any snapshot is written.
	var bound := read_hospital_presentation_request(str(request.resolution_id))
	var saved: Dictionary = _contact_checkpoint_writer.call() if bound.get("ok", false) else bound
	if not saved.get("ok", false):
		var rolled := rollback_restore_silent(backup.value.backup)
		if not lease.is_empty():
			var released: Dictionary = _mutation_gate.release(&"causal_transaction", str(lease.value.token))
			if not released.get("ok", false): return released
		return saved if rolled.get("ok", false) else rolled
	if not lease.is_empty():
		var released: Dictionary = _mutation_gate.release(&"causal_transaction", str(lease.value.token))
		if not released.get("ok", false): return released
	return {"ok": true, "value": checked.value.duplicate(true)}


# Add these declarations and methods to GameState. Root serializes the accompanying
# exact-anchor replacements; this fragment is not an independent runnable script.
const _CONTACTS_FROZEN := preload("res://scripts/narrative/ContactsFrozenContext.gd")
var _frozen_contacts_contexts_enabled := false

func configure_frozen_contacts_contexts() -> Dictionary:
	_frozen_contacts_contexts_enabled = true
	return {"ok": true}

func frozen_contacts_contexts_enabled() -> bool:
	return _frozen_contacts_contexts_enabled

func _prepare_contact_presentation_candidate(candidate: Dictionary) -> Dictionary:
	if not _frozen_contacts_contexts_enabled: return {"ok": true, "value": to_save_dict()}
	return _CONTACTS_FROZEN.capture_candidate(contacts, candidate, to_save_dict(), day)

## First admission may freeze only a current ordinary card or the Day 7 echo batch.
## All historical facts must already accompany their causal source generation.
func ensure_contact_presentation_contexts(friend_id: String = "") -> Dictionary:
	if not _frozen_contacts_contexts_enabled: return {"ok": true, "value": {}}
	if friend_id != "" and friend_id not in _CONTACT_INVITATION_STATE.FRIEND_IDS:
		return _transaction_failure(&"unknown_friend", "")
	var prepared := _CONTACTS_FROZEN.prepare_projection(contacts, to_save_dict(), day, friend_id)
	if not prepared.ok: return prepared
	var candidate: Dictionary = prepared.value.route_context
	if candidate == route_context:
		return {"ok": true, "value": candidate[_CONTACTS_FROZEN.CACHE_KEY].duplicate(true)}
	if _run_lifecycle.get_state() != &"PLAYING" or _mutation_gate == null:
		return _transaction_failure(&"contact_presentation_unavailable", "")
	if not _contact_checkpoint_writer.is_valid():
		return _transaction_failure(&"contact_checkpoint_writer_unconfigured", "")
	var lease: Dictionary = _mutation_gate.acquire(&"causal_transaction")
	if not lease.ok: return lease
	var captured: Dictionary = capture_restore_state()
	if not captured.ok:
		_mutation_gate.release(&"causal_transaction", str(lease.value.token))
		return captured
	route_context = candidate.duplicate(true)
	var saved: Dictionary = _contact_checkpoint_writer.call()
	if not saved.get("ok", false):
		var rolled: Dictionary = rollback_restore_silent(captured.value.backup)
		if not rolled.ok:
			_mutation_gate.latch_fatal({"source": "contact_presentation", "phase": "rollback",
				"code": "CONTACT_PRESENTATION_ROLLBACK_FAILED", "details": {"cause": str(rolled.get("code", ""))}})
			return rolled
		var released: Dictionary = _mutation_gate.release(&"causal_transaction", str(lease.value.token))
		return saved if released.ok else released
	var released: Dictionary = _mutation_gate.release(&"causal_transaction", str(lease.value.token))
	if not released.ok: return released
	return {"ok": true, "value": route_context[_CONTACTS_FROZEN.CACHE_KEY].duplicate(true)}


# Scene events share the existing Run receipt map. The registry contains trusted
# content only; the issuer binds each command, and the saved chain binds order.
const _SCENE_EVENT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
var _scene_event_bridge: Object
var _scene_event_registry: Dictionary = {}
var _scene_event_before_adoption: Callable

func configure_scene_event_owner(bridge: Object) -> Dictionary:
	if bridge == null or not bridge.has_method("capture_scene_event_boundary") \
			or not bridge.has_method("validate_scene_event_anchor"):
		return _transaction_failure(&"event_dependency_invalid", "reading owner required")
	if _scene_event_bridge != null and _scene_event_bridge != bridge:
		return _transaction_failure(&"event_already_configured", "reading owner replacement refused")
	_scene_event_bridge = bridge
	return {"ok": true}

## No production content is installed by this slice. TEST registries contain
## fixed authored values, never saved receipts, a projection or a mutable frontier.
func configure_test_scene_event_registry(registry: Dictionary) -> Dictionary:
	if not OS.has_feature("debug") or OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty():
		return _transaction_failure(&"event_test_registry_forbidden", "isolated debug root required")
	if not _scene_event_registry.is_empty():
		return {"ok": true} if registry == _scene_event_registry else _transaction_failure(&"event_registry_conflict", "")
	for entry: Variant in registry:
		if typeof(entry) != TYPE_STRING or not registry[entry] is Dictionary:
			return _transaction_failure(&"event_registration_invalid", "")
		var row: Dictionary = registry[entry]
		if not _SCENE_EVENT._keys(row, ["content_version", "events"]) \
				or typeof(row.content_version) != TYPE_INT or row.content_version < 1 or not row.events is Dictionary:
			return _transaction_failure(&"event_registration_invalid", "")
		for event_id: Variant in row.events:
			var template: Variant = row.events[event_id]
			var keys: Array = _SCENE_EVENT.RECORD_KEYS.duplicate()
			keys.erase("command_id")
			if not _SCENE_EVENT._keys(template, keys) or template.event_id != event_id:
				return _transaction_failure(&"event_registration_invalid", "")
	_scene_event_registry = registry.duplicate(true)
	return {"ok": true}

func scene_event_registration(event: Dictionary) -> Dictionary:
	var row: Dictionary = _scene_event_registry.get(event.source.entry_id, {})
	if row.get("content_version") != event.source.content_version:
		return _transaction_failure(&"event_registration_invalid", "entry revision unavailable")
	var raw: Variant = row.get("events", {}).get(event.event_id)
	if not raw is Dictionary: return _transaction_failure(&"event_registration_invalid", "event unavailable")
	var record: Dictionary = raw.duplicate(true)
	# Command identity comes from the independently authenticated issuer receipt.
	# It cannot change a retained occurrence or replay an occupied ordinal.
	record["command_id"] = event.command_id
	var matched: Dictionary = _SCENE_EVENT.match_registration(event, record)
	if not matched.ok: return matched
	return {"ok": true, "value": record}

func scene_event_context() -> Dictionary:
	if not is_instance_valid(_scene_event_bridge) or _identity_issuer == null:
		return _transaction_failure(&"event_dependency_invalid", "")
	var live := capture_desktop_identity_context()
	if not live.ok: return live
	var boundary: Dictionary = _scene_event_bridge.capture_scene_event_boundary()
	if not boundary.get("ok", false): return boundary
	var source := {"run_id": live.value.run_id, "branch_id": live.value.branch_id,
		"causal_day_instance": live.value.causal_day_instance,
		"scene_occurrence": boundary.value.anchor.session_id, "entry_id": boundary.value.anchor.entry_id,
		"content_version": boundary.value.anchor.content_version}
	var checked: Dictionary = _SCENE_EVENT.validate_receipts(_command_receipts)
	if not checked.ok: return checked
	var group: Dictionary = checked.value.occurrences.get(_SCENE_EVENT.occurrence_key(source), {})
	if not group.is_empty():
		# Only admitted owner state can restore historical occurrence identity.
		# Load changes the live caller's authority, never these semantic bytes.
		source = group.source.duplicate(true)
		if source.run_id != live.value.run_id:
			return _transaction_failure(&"event_source_mismatch", "")
	return {"ok": true, "value": {"mode": "canonical", "suspended": false, "computer_held": false,
		"source": source, "playback_token": str(boundary.value.playback_token) + "." + str(
			_SCENE_EVENT.WRITER.stringify(live.value).value).sha256_text(),
		"next_ordinal": group.get("next_ordinal", 0), "predecessor": group.get("predecessor", ""),
		"notification": group.get("notification", {}).duplicate(true), "anchor": boundary.value.anchor,
		"checkpoint": boundary.value.checkpoint}}

func lookup_scene_event(command_id: String, digest: String) -> Dictionary:
	if not _command_receipts.has(command_id): return {"ok": true, "found": false}
	var receipt: Dictionary = _command_receipts[command_id]
	if receipt.get("kind") != "scene_event" or receipt.get("request_fingerprint") != digest:
		return _transaction_failure(&"duplicate_transaction_conflict", command_id)
	return {"ok": true, "found": true, "duplicate": true,
		"value": receipt.scene_event.result.duplicate(true)}

func accept_scene_event(event: Dictionary, digest: String, lease: String) -> Dictionary:
	if not is_instance_valid(_mutation_gate) or not _mutation_gate.is_lease_active(&"causal_transaction", lease):
		return _transaction_failure(&"event_lease_lost", "")
	if _narrative_checkpoint_port == null or not _narrative_checkpoint_port.has_method("commit_scene_event"):
		return _transaction_failure(&"event_dependency_invalid", "real checkpoint owner required")
	var context := scene_event_context()
	if not context.ok: return context
	var current: Dictionary = context.value
	if current.source != event.source or current.playback_token != event.playback_token \
			or current.next_ordinal != event.ordinal or current.predecessor != event.predecessor:
		return _transaction_failure(&"event_frontier_mismatch", "")
	var registered := scene_event_registration(event)
	if not registered.ok: return registered
	var proven: Dictionary = _identity_issuer.verify_issued(event.issuer_receipt, &"transaction_id")
	if not proven.ok: return proven
	var made: Dictionary = _SCENE_EVENT.make_receipt(event, current.anchor)
	if not made.ok: return made
	if made.value.request_fingerprint != digest: return _transaction_failure(&"event_digest_mismatch", "")
	var prior := _command_receipts.duplicate(true)
	var receipts := prior.duplicate(true)
	if receipts.has(event.command_id): return _transaction_failure(&"duplicate_transaction_conflict", "")
	receipts[event.command_id] = made.value
	var checked: Dictionary = _SCENE_EVENT.validate_receipts(receipts)
	if not checked.ok: return checked
	var candidate := capture_run_snapshot_input()
	candidate["command_receipts"] = receipts
	var committed: Dictionary = _narrative_checkpoint_port.commit_scene_event(candidate, current.checkpoint)
	if not committed.get("ok", false):
		if committed.get("committed", false): return _scene_event_fatal(&"event_commit_ack_invalid")
		return committed
	# Confirmed disk+journal success is irrevocable here. A failed adoption must
	# retain fatal custody, not roll back a committed result or release stale state.
	if _scene_event_before_adoption.is_valid():
		var observed: Variant = _scene_event_before_adoption.call()
		if observed != true: return _scene_event_fatal(&"event_adoption_interrupted")
	var after := scene_event_context()
	if not after.get("ok", false) or after.value != current or _command_receipts != prior \
			or not _mutation_gate.is_lease_active(&"causal_transaction", lease):
		return _scene_event_fatal(&"event_adoption_source_changed")
	_command_receipts = receipts.duplicate(true)
	return {"ok": true, "duplicate": false, "value": made.value.scene_event.result.duplicate(true)}

func _scene_event_fatal(code: StringName) -> Dictionary:
	_mutation_gate.latch_fatal({"source": &"scene_event", "phase": &"committed_adoption",
		"code": code, "details": {"committed": true}})
	return {"ok": false, "code": code, "committed": true}

## RunRestoreParticipant invokes this before any participant mutates live state.
func validate_scene_event_snapshot(snapshot: Dictionary) -> Dictionary:
	var checked: Dictionary = _SCENE_EVENT.validate_receipts(snapshot.get("command_receipts", {}))
	if not checked.ok: return checked
	if checked.value.occurrences.is_empty(): return {"ok": true}
	if not is_instance_valid(_scene_event_bridge) or _identity_issuer == null:
		return _transaction_failure(&"event_dependency_invalid", "")
	var checkpoint: Dictionary = snapshot.get("narrative_checkpoint", {})
	var active_occurrence: String = str(snapshot.get("gameplay", {}).get("route_context", {}).get(
		"active_dating_challenge", {}).get("completion_transaction_id", "")) if snapshot.get("route_id") == "dating" else ""
	for group: Dictionary in checked.value.occurrences.values():
		if group.source.scene_occurrence == active_occurrence and (not checkpoint.get("reading_session") is Dictionary \
				or checkpoint.reading_session.get("ledger", {}).get("session_token") != active_occurrence):
			return _transaction_failure(&"event_anchor_invalid", "active occurrence requires its actual reading ledger")
		if group.source.run_id != snapshot.get("run_id"):
			return _transaction_failure(&"event_source_mismatch", "")
		for receipt: Dictionary in group.receipts:
			var event: Dictionary = receipt.scene_event.semantic.duplicate(true)
			event["playback_token"] = "restore.validation"
			var registered := scene_event_registration(event)
			if not registered.ok: return registered
			var proven: Dictionary = _identity_issuer.verify_issued(event.issuer_receipt, &"transaction_id")
			if not proven.ok: return proven
			var anchored: Dictionary = _scene_event_bridge.validate_scene_event_anchor(
				receipt.scene_event.reading_anchor, checkpoint)
			if not anchored.ok: return anchored
	return {"ok": true}
