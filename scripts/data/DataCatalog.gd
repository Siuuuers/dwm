class_name DataCatalog
extends RefCounted
# DataCatalog (CONTRACTS §2 required interface): pure, read-only data source. No gameplay
# logic, no GameState mutation. All methods return copies/values (never live references).
# Values mirror indexed requirement data and MUST stay equal to GameState's embedded tables.

const FRIEND_IDS := ["priscilla", "lavinia", "sylvia"]

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
const _SHOP_ROWS := [
	{"id": "coffee", "currency": "money", "price": 20, "effects": ["motivation:+1"], "max": 9},
	{"id": "wine", "currency": "money", "price": 55, "effects": ["pressure:-4", "health:-1"], "max": 3},
	{"id": "pineapple_bun", "currency": "money", "price": 10, "effects": ["inventory:add:pineapple_bun"], "max": 7, "gift": true},
	{"id": "bandage_pack", "currency": "money", "price": 15, "effects": ["health:+1"], "max": 0},
	{"id": "quiet_tea", "currency": "money", "price": 15, "effects": ["inventory:add:quiet_tea"], "max": 3, "gift": true},
	{"id": "soft_blanket", "currency": "money", "price": 25, "effects": ["pressure:-2"], "max": 3},
	{"id": "weighted_plush", "currency": "money", "price": 35, "effects": ["pressure:-3"], "max": 2},
	{"id": "spa_coupon", "currency": "money", "price": 45, "effects": ["pressure:-4"], "max": 1},
	{"id": "supportz", "currency": "money", "price": 45, "effects": ["minesweeper:round_floor:-1"], "max": 3, "secret": true},
	{"id": "healthy_meal", "currency": "money", "price": 25, "effects": ["health:+2"], "max": 3},
	{"id": "protein_box", "currency": "money", "price": 35, "effects": ["health:+3"], "max": 2},
	{"id": "premium_care", "currency": "minesweeper_coin", "price": 1, "effects": ["pressure:-4", "health:+4"], "max": 2},
	{"id": "pep_note", "currency": "money", "price": 10, "effects": ["motivation:+1"], "max": 5},
	{"id": "priscilla_gift", "currency": "minesweeper_coin", "price": 3, "effects": ["inventory:add:priscilla_gift"], "max": 1, "gift": true, "special": true},
	{"id": "lavinia_gift", "currency": "minesweeper_coin", "price": 3, "effects": ["inventory:add:lavinia_gift"], "max": 1, "gift": true, "special": true},
	{"id": "sylvia_gift", "currency": "minesweeper_coin", "price": 3, "effects": ["inventory:add:sylvia_gift"], "max": 1, "gift": true, "special": true},
	{"id": "lucky_charm", "currency": "minesweeper_coin", "price": 1, "effects": ["inventory:add:lucky_charm"], "max": 1},
	{"id": "debug_key", "currency": "minesweeper_coin", "price": 3, "effects": ["inventory:add:debug_key"], "max": 1},
]

const _SCHEDULE_ROWS := [
	{"id": "dating", "requires_friend": true, "cost": 1, "effects": []},
	{"id": "training", "requires_friend": false, "cost": 1, "effects": ["pressure:+1", "health:+2"]},
	{"id": "working", "requires_friend": false, "cost": 1, "effects": ["pressure:+2", "health:-2", "money:+30"]},
	{"id": "rest", "requires_friend": false, "cost": 1, "effects": ["pressure:-2", "health:+1"]},
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
		out.append(_make_shop_item(row))
	return out


func get_shop_item(item_id: String) -> Dictionary:
	for row in _SHOP_ROWS:
		if row["id"] == item_id:
			return _shop_row_to_dict(row)
	return {}


func _shop_row_to_dict(row: Dictionary) -> Dictionary:
	var effects: Array[String] = []
	effects.assign(row["effects"])
	return {
		"id": row["id"],
		"currency": row["currency"],
		"price": row["price"],
		"effect_ids": effects,
		"max_purchases": row["max"],
		"is_gift": row.get("gift", false),
		"is_special_gift": row.get("special", false),
		"is_visible_in_shop": not row.get("secret", false),
		"is_secret_buy_button": row.get("secret", false),
		"secret_accessibility_label_key": ("shop.secret_supportz.accessible_name" if row.get("secret", false) else ""),
	}


func _make_shop_item(row: Dictionary) -> ShopItemData:
	var item := ShopItemData.new()
	item.id = row["id"]
	item.display_name = (row["id"] as String).capitalize()
	item.localization_key = "shop.item.%s" % row["id"]
	item.price = row["price"]
	item.currency = row["currency"]
	var effects: Array[String] = []
	effects.assign(row["effects"])
	item.effect_ids = effects
	item.max_purchases = row["max"]
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
func get_schedule_actions() -> Array:
	var out: Array = []
	for row in _SCHEDULE_ROWS:
		out.append(_make_schedule_action(row))
	return out


func get_schedule_action(action_id: String) -> Dictionary:
	for row in _SCHEDULE_ROWS:
		if row["id"] == action_id:
			var effects: Array[String] = []
			effects.assign(row["effects"])
			return {
				"id": row["id"],
				"requires_friend": row["requires_friend"],
				"motivation_cost": row["cost"],
				"effect_ids": effects,
			}
	return {}


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
