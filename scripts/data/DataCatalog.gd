class_name DataCatalog
extends RefCounted
# DataCatalog (CONTRACTS §2 required interface): pure, read-only data source. No gameplay
# logic, no GameState mutation. All methods return copies/values (never live references).
# Values mirror indexed requirement data and MUST stay equal to GameState's embedded tables.

# Registry delegation (dwm-p2r.16 Task 1). Schedule and the three Minesweeper Shop capability items
# are OWNED by their immutable registries; this catalog stores none of their facts and keeps only
# derived presentation. Both are preloaded by path rather than named by class_name: the new Task-1
# scripts have never been through an editor import pass and are absent from the global script class
# cache under a headless run (dwm-p2r.16 DECISION 9.18).
const _SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")
const _SCHEDULE_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

# The roster is OWNED by the contacts domain (dwm-pm4, maintainer decision 2026-08-21); this
# catalog keeps only the alias, exactly as it already treats the registry-owned facts above.
const _CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const FRIEND_IDS := _CONTACT_STATE.FRIEND_IDS

const _INVITATION_DAYS := {
	"priscilla": [1, 2, 4, 6],
	"lavinia": [2, 3, 5, 6],
	"sylvia": [1, 3, 4, 5],
}

const _GROUP_INVITATION_DAYS := [2, 6]

const _DAILY_CONTACT_ORDER := {
	1: ["priscilla", "sylvia"],
	2: ["priscilla", "lavinia"],
	3: ["lavinia", "sylvia"],
	4: ["priscilla", "sylvia"],
	5: ["lavinia", "sylvia"],
	6: ["priscilla", "lavinia"],
	7: ["priscilla", "lavinia", "sylvia"],
}

# Shop item rows (CONTENT §7). Each: id, currency, price, effects, max, gift flags, secret.
#
# THREE ROWS CARRY NO FACTS. supportz, lucky_charm and debug_key are owned by
# MinesweeperShopRegistry, so their rows keep only presentation the registry does not carry -- the
# secret/gift flags -- and their currency, price, effect_ids and max_purchases are projected from
# the registry record (max_purchases from cap.per_branch). They stay at their original indices
# because a row must exist for them regardless: test_supportz_properties requires the secret and
# visibility flags, which no registry record holds. Keeping the row in place therefore preserves
# shop order for free (dwm-p2r.16 DECISION 12.7). A row is recognized as delegated by carrying no
# "currency" key.
const _SHOP_ROWS := [
	{"id": "coffee", "currency": "money", "price": 20, "effects": ["motivation:+1"], "max": 9},
	{"id": "wine", "currency": "money", "price": 55, "effects": ["pressure:-4", "health:-1"], "max": 3},
	{"id": "pineapple_bun", "currency": "money", "price": 10, "effects": ["inventory:add:pineapple_bun"], "max": 7, "gift": true},
	{"id": "bandage_pack", "currency": "money", "price": 15, "effects": ["health:+1"], "max": 0},
	{"id": "quiet_tea", "currency": "money", "price": 15, "effects": ["inventory:add:quiet_tea"], "max": 3, "gift": true},
	{"id": "soft_blanket", "currency": "money", "price": 25, "effects": ["pressure:-2"], "max": 3},
	{"id": "weighted_plush", "currency": "money", "price": 35, "effects": ["pressure:-3"], "max": 2},
	{"id": "spa_coupon", "currency": "money", "price": 45, "effects": ["pressure:-4"], "max": 1},
	{"id": "supportz", "secret": true},
	{"id": "healthy_meal", "currency": "money", "price": 25, "effects": ["health:+2"], "max": 3},
	{"id": "protein_box", "currency": "money", "price": 35, "effects": ["health:+3"], "max": 2},
	{"id": "premium_care", "currency": "minesweeper_coin", "price": 1, "effects": ["pressure:-4", "health:+4"], "max": 2},
	{"id": "pep_note", "currency": "money", "price": 10, "effects": ["motivation:+1"], "max": 5},
	{"id": "priscilla_gift", "currency": "minesweeper_coin", "price": 3, "effects": ["inventory:add:priscilla_gift"], "max": 1, "gift": true, "special": true},
	{"id": "lavinia_gift", "currency": "minesweeper_coin", "price": 3, "effects": ["inventory:add:lavinia_gift"], "max": 1, "gift": true, "special": true},
	{"id": "sylvia_gift", "currency": "minesweeper_coin", "price": 3, "effects": ["inventory:add:sylvia_gift"], "max": 1, "gift": true, "special": true},
	{"id": "lucky_charm"},
	{"id": "debug_key"},
]

const _TASK_IDS := [
	"complete_beginner", "complete_intermediate", "complete_expert",
	"no_flag_finish", "foresight_finish",
	"perfect_beginner", "perfect_intermediate", "perfect_expert",
	"win_win_win",
]

const _FRIEND_ICON := {"priscilla": "P", "lavinia": "L", "sylvia": "S"}


# ---- Friends ----
func get_friend_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(FRIEND_IDS)
	return out


func get_friends() -> Dictionary:
	var out: Dictionary = {}
	for id in FRIEND_IDS:
		out[id] = _make_friend(id)
	return out


func get_friend(friend_id: String) -> Dictionary:
	if not (friend_id in FRIEND_IDS):
		return {}
	return {
		"id": friend_id,
		"display_name": friend_id.capitalize(),
		"localization_key": "friend.%s" % friend_id,
		"icon_text": _FRIEND_ICON.get(friend_id, ""),
	}


func _make_friend(friend_id: String) -> FriendData:
	var fd := FriendData.new()
	fd.id = friend_id
	fd.display_name = friend_id.capitalize()
	fd.localization_key = "friend.%s" % friend_id
	fd.icon_text = _FRIEND_ICON.get(friend_id, "")
	fd.portrait_path = "res://art/characters/%s/%s_portrait.png" % [friend_id, friend_id]
	fd.dating_sprite_path = "res://art/characters/%s/%s_dating.png" % [friend_id, friend_id]
	fd.tiny_path = "res://art/characters/%s/%s_tiny.png" % [friend_id, friend_id]
	return fd


# ---- Shop ----
func get_shop_items() -> Array:
	var out: Array = []
	for row in _SHOP_ROWS:
		var facts := _shop_facts(row)
		if facts.is_empty():
			continue
		out.append(_make_shop_item(row, facts))
	return out


func get_shop_item(item_id: String) -> Dictionary:
	for row in _SHOP_ROWS:
		if row["id"] == item_id:
			var facts := _shop_facts(row)
			if facts.is_empty():
				return {}
			return _shop_row_to_dict(row, facts)
	return {}


## The four owned facts for one row: local for the fifteen catalog items, projected from
## MinesweeperShopRegistry for the three delegated ones. An unavailable registry answers with the
## empty dictionary and the item is OMITTED rather than emitted with blank facts, so a broken
## registry surfaces as a short shop list that test_eighteen_shop_items rejects, never as a
## zero-price item (dwm-p2r.16 DECISION 12.3).
func _shop_facts(row: Dictionary) -> Dictionary:
	if row.has("currency"):
		var local_effects: Array[String] = []
		local_effects.assign(row["effects"])
		return {
			"currency": row["currency"],
			"price": row["price"],
			"effect_ids": local_effects,
			"max_purchases": row["max"],
		}
	var fetched: Dictionary = _SHOP_REGISTRY.get_record(str(row["id"]))
	if not fetched.get("ok", false):
		return {}
	var record: Dictionary = (fetched.get("value", {}) as Dictionary).get("record", {}) as Dictionary
	var cap: Dictionary = record.get("cap", {}) as Dictionary
	var effects: Array[String] = []
	effects.assign(record.get("effect_ids", []) as Array)
	return {
		"currency": str(record.get("currency", "")),
		"price": int(record.get("price", 0)),
		"effect_ids": effects,
		"max_purchases": int(cap.get("per_branch", 0)),
	}


func _shop_row_to_dict(row: Dictionary, facts: Dictionary) -> Dictionary:
	return {
		"id": row["id"],
		"currency": facts["currency"],
		"price": facts["price"],
		"effect_ids": facts["effect_ids"],
		"max_purchases": facts["max_purchases"],
		"is_gift": row.get("gift", false),
		"is_special_gift": row.get("special", false),
		"is_visible_in_shop": not row.get("secret", false),
		"is_secret_buy_button": row.get("secret", false),
		"secret_accessibility_label_key": ("shop.secret_supportz.accessible_name" if row.get("secret", false) else ""),
	}


func _make_shop_item(row: Dictionary, facts: Dictionary) -> ShopItemData:
	var item := ShopItemData.new()
	item.id = row["id"]
	item.display_name = (row["id"] as String).capitalize()
	item.localization_key = "shop.item.%s" % row["id"]
	item.price = facts["price"]
	item.currency = facts["currency"]
	var effects: Array[String] = []
	effects.assign(facts["effect_ids"] as Array)
	item.effect_ids = effects
	item.max_purchases = facts["max_purchases"]
	item.icon_text = (row["id"] as String).substr(0, 1).to_upper()
	item.image_path = "res://art/shop/%s.png" % row["id"]
	item.is_gift = row.get("gift", false)
	item.is_special_gift = row.get("special", false)
	item.is_visible_in_shop = not row.get("secret", false)
	item.is_secret_buy_button = row.get("secret", false)
	if row.get("secret", false):
		item.secret_accessibility_label_key = "shop.secret_supportz.accessible_name"
	return item


# ---- Schedule actions ----
#
# PROJECTED, NEVER STORED (dwm-p2r.16 DECISION 11.8). ScheduleActionRegistry owns every Schedule
# fact; this catalog keeps not even a path or an ID. load_current() validates and fingerprints the
# registry, then the manifest at the registry's own MANIFEST_PATH is re-read to ENUMERATE, because
# the shipped registry surface is exactly fingerprint() and find_record(action_id) with no
# enumeration API and no reachable record list (correction C2). DataCatalog is therefore a second
# READER of the registry's document while the registry remains the sole authority for validity.
#
# The derived order is [rest, training, working, dating], NOT today's hand-written order: the
# manifest is sorted by action_id, so the three ordinary records project first and the synthesized
# route appends. Reproducing the old order would require an explicit ordering list, which is itself
# a Schedule fact the registry does not own (correction C1).
func get_schedule_actions() -> Array:
	var out: Array = []
	for row in _schedule_rows():
		out.append(_make_schedule_action(row))
	return out


func get_schedule_action(action_id: String) -> Dictionary:
	for row in _schedule_rows():
		if row["id"] == action_id:
			var effects: Array[String] = []
			effects.assign(row["effects"] as Array)
			return {
				"id": row["id"],
				"requires_friend": row["requires_friend"],
				"motivation_cost": row["cost"],
				"effect_ids": effects,
			}
	return {}


## The three action_kind=ordinary records projected directly, then exactly one synthesized action
## per distinct non-null route_id -- which yields precisely "dating", a route_id and never an
## action_id, so find_record("dating") answers unregistered_action and the row cannot come from a
## lookup (DECISION 3).
##
## Each synthesized route takes its fields from the FIRST record carrying that route_id in the
## manifest's own sorted order (DECISION 12.4); sortedness is guaranteed because the registry
## rejects an unsorted manifest. Note that the route source set is the fourteen records tagged
## route_id="dating", NOT all seventeen non-ordinary records: solo:lavinia:day7, solo:priscilla:day7
## and solo:sylvia:day7 are solo-shaped with participants yet carry route_id null (DECISION 12.5).
##
## Recomputed per call by design (DECISION 12.6). load_current() retains its validated registry
## statically, so only the ~4KB enumeration read repeats, and this catalog stays free of state.
## An unloadable or malformed registry yields the empty projection with no diagnostic: these
## signatures carry no envelope, a fallback table is forbidden, and scripts/data holds no push_*
## precedent (DECISION 12.3).
func _schedule_rows() -> Array:
	var loaded: Dictionary = _SCHEDULE_REGISTRY.load_current()
	if not loaded.get("ok", false):
		return []
	var manifest_path: String = _SCHEDULE_REGISTRY.MANIFEST_PATH
	if not FileAccess.file_exists(manifest_path):
		return []
	var parsed: Dictionary = _STRICT_JSON.parse_object(FileAccess.get_file_as_string(manifest_path))
	if not parsed.get("ok", false):
		return []
	var ordinary: Array = []
	var routes: Array = []
	var seen_routes: Dictionary = {}
	for record: Dictionary in (parsed.get("value", {}) as Dictionary).get("records", []) as Array:
		if str(record.get("action_kind", "")) == "ordinary":
			ordinary.append(_schedule_row(str(record.get("action_id", "")), record))
		var route: Variant = record.get("route_id")
		if route != null and not seen_routes.has(route):
			seen_routes[route] = true
			routes.append(_schedule_row(str(route), record))
	return ordinary + routes


## Every member DERIVED from the record: requires_friend from participant presence, cost and
## effects read straight off the registry row.
func _schedule_row(id: String, record: Dictionary) -> Dictionary:
	var effects: Array[String] = []
	effects.assign(record.get("effect_ids", []) as Array)
	return {
		"id": id,
		"requires_friend": not (record.get("participants", []) as Array).is_empty(),
		"cost": int(record.get("motivation_cost", 0)),
		"effects": effects,
	}


func _make_schedule_action(row: Dictionary) -> ScheduleActionData:
	var a := ScheduleActionData.new()
	a.id = row["id"]
	a.display_name = (row["id"] as String).capitalize()
	a.localization_key = "schedule.action.%s" % row["id"]
	a.motivation_cost = row["cost"]
	var effects: Array[String] = []
	effects.assign(row["effects"])
	a.effect_ids = effects
	a.requires_friend = row["requires_friend"]
	a.image_path = "res://art/schedule/%s.png" % row["id"]
	return a


# ---- Minesweeper tasks ----
func get_minesweeper_tasks() -> Array:
	var out: Array = []
	for id in _TASK_IDS:
		out.append(_make_task(id))
	return out


func get_minesweeper_task(task_id: String) -> Dictionary:
	if task_id in _TASK_IDS:
		return {"id": task_id, "reward_coins": 1, "localization_key": "minesweeper.task.%s" % task_id}
	return {}


func _make_task(task_id: String) -> MinesweeperTaskData:
	var t := MinesweeperTaskData.new()
	t.id = task_id
	t.display_name = task_id.capitalize()
	t.localization_key = "minesweeper.task.%s" % task_id
	t.reward_coins = 1
	t.icon_path = "res://art/minesweeper/task_%s.png" % task_id
	return t


# ---- Contact message order ----
func _resolve_day(target_day: int) -> int:
	if target_day >= 1 and target_day <= 7:
		return target_day
	var loop := Engine.get_main_loop()
	if loop != null and loop is SceneTree:
		var gs := (loop as SceneTree).root.get_node_or_null("/root/GameState")
		if gs != null and typeof(gs.get("day")) == TYPE_INT:
			return int(gs.day)
	return 1


func get_daily_contact_message_order(target_day: int = -1) -> Array[String]:
	var day := _resolve_day(target_day)
	var out: Array[String] = []
	if _DAILY_CONTACT_ORDER.has(day):
		out.assign(_DAILY_CONTACT_ORDER[day])
	return out


func get_contact_message_order_or_fallback(target_day: int = -1) -> Array[String]:
	var order := get_daily_contact_message_order(target_day)
	if order.is_empty():
		var fallback: Array[String] = []
		fallback.assign(FRIEND_IDS)
		return fallback
	return order


# ---- Invitation days ----
func get_invitation_days() -> Dictionary:
	var out: Dictionary = {}
	for friend in FRIEND_IDS:
		var days: Array[int] = []
		days.assign(_INVITATION_DAYS[friend])
		out[friend] = days
	return out


func get_invitation_days_for_friend(friend_id: String) -> Array[int]:
	var out: Array[int] = []
	if _INVITATION_DAYS.has(friend_id):
		out.assign(_INVITATION_DAYS[friend_id])
	return out


func get_group_invitation_days() -> Array[int]:
	var out: Array[int] = []
	out.assign(_GROUP_INVITATION_DAYS)
	return out


func get_group_invitation_pairs() -> Array[Array]:
	return [["priscilla", "lavinia"]]
