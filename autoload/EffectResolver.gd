extends Node
# EffectResolver (CONTRACTS §3): applies ONLY whitelisted effect IDs, via two-pass
# validation, through safe GameState public methods. No eval, no arbitrary method calls,
# no resource/save-executed logic. Normalize (trim + lowercase) before validating/applying.

const _FRIEND_IDS := ["priscilla", "lavinia", "sylvia"]
const _ATTITUDES := ["impressed", "amused", "concerned", "upset", "mad", "lovely"]
const _INVENTORY_ITEMS := [
	"pineapple_bun", "quiet_tea", "lucky_charm", "debug_key",
	"priscilla_gift", "lavinia_gift", "sylvia_gift",
]

# Fixed, non-parametric effect IDs -> a small typed descriptor the apply pass consumes.
# Descriptor kind is one of: stat / money / coin.
var _fixed_effects: Dictionary = {}


func _ready() -> void:
	_build_fixed_effects()


func _build_fixed_effects() -> void:
	# Pressure and health: +/- 1..4
	for delta in [1, 2, 3, 4]:
		_fixed_effects["pressure:+%d" % delta] = {"kind": "stat", "stat": "pressure", "delta": delta}
		_fixed_effects["pressure:-%d" % delta] = {"kind": "stat", "stat": "pressure", "delta": -delta}
		_fixed_effects["health:+%d" % delta] = {"kind": "stat", "stat": "health", "delta": delta}
		_fixed_effects["health:-%d" % delta] = {"kind": "stat", "stat": "health", "delta": -delta}
	# Motivation: +1 / -1 only
	_fixed_effects["motivation:+1"] = {"kind": "stat", "stat": "motivation", "delta": 1}
	_fixed_effects["motivation:-1"] = {"kind": "stat", "stat": "motivation", "delta": -1}
	# Money positive
	for amt in [1, 5, 6, 9, 10, 12, 20, 27, 30, 45, 54]:
		_fixed_effects["money:+%d" % amt] = {"kind": "money", "delta": amt}
	# Money negative
	for amt in [5, 10, 15, 20, 25, 30, 35, 40, 45]:
		_fixed_effects["money:-%d" % amt] = {"kind": "money", "delta": -amt}
	# Coins
	_fixed_effects["coin:+1"] = {"kind": "coin", "delta": 1}
	_fixed_effects["coin:-1"] = {"kind": "coin", "delta": -1}
	_fixed_effects["coin:-2"] = {"kind": "coin", "delta": -2}
	_fixed_effects["coin:-3"] = {"kind": "coin", "delta": -3}


func _normalize(effect_id: String) -> String:
	return effect_id.strip_edges().to_lower()


func is_effect_known(effect_id: String) -> bool:
	var id := _normalize(effect_id)
	if _fixed_effects.has(id):
		return true
	# Inventory add
	for item in _INVENTORY_ITEMS:
		if id == "inventory:add:%s" % item:
			return true
	# Affection: affection:<friend>:+1|+2|-1
	for friend in _FRIEND_IDS:
		if id == "affection:%s:+1" % friend or id == "affection:%s:+2" % friend or id == "affection:%s:-1" % friend:
			return true
	# Friend attitude: friend_attitude:<friend>:<attitude>
	for friend in _FRIEND_IDS:
		for attitude in _ATTITUDES:
			if id == "friend_attitude:%s:%s" % [friend, attitude]:
				return true
	# Inter-friend affection: only priscilla/lavinia pair, +1|-1, both orders
	if id == "inter_friend_affection:priscilla:lavinia:+1" or id == "inter_friend_affection:priscilla:lavinia:-1":
		return true
	if id == "inter_friend_affection:lavinia:priscilla:+1" or id == "inter_friend_affection:lavinia:priscilla:-1":
		return true
	# Minesweeper round-floor (and legacy alias)
	if id == "minesweeper:round_floor:-1" or id == "minesweeper:max_rounds:+1":
		return true
	return false


func are_effect_ids_known(effect_ids: Array) -> bool:
	for raw in effect_ids:
		if typeof(raw) != TYPE_STRING:
			return false
		if not is_effect_known(raw):
			return false
	return true


## Pure resolution (dwm-p2r.8, Plan-05 Task 3): validates and normalizes every ID without finding
## GameState and without mutating anything. GameState owns the atomic commit that consumes these.
func resolve_effects(effect_ids: Array) -> Dictionary:
	if typeof(effect_ids) != TYPE_ARRAY:
		return {"ok": false, "code": &"invalid_effect_ids", "message": "effect_ids must be an array", "details": {}}
	var descriptors: Array = []
	for raw in effect_ids:
		if typeof(raw) != TYPE_STRING:
			return {"ok": false, "code": &"invalid_effect_ids", "message": "every effect id must be a String", "details": {}}
		var id := _normalize(raw)
		if not is_effect_known(id):
			return {"ok": false, "code": &"unknown_effect_id", "message": id, "details": {}}
		descriptors.append({"effect_id": id})
	return {"ok": true, "code": &"ok", "value": {"descriptors": descriptors}, "receipt": {}}


## Applies one already-resolved descriptor list onto an explicit target. Callers MUST have
## validated through resolve_effects first; this performs no discovery of its own.
func apply_resolved_descriptors(target: Object, descriptors: Array) -> Dictionary:
	if target == null:
		return {"ok": false, "code": &"invalid_apply_target", "message": "target is required", "details": {}}
	for descriptor in descriptors:
		if typeof(descriptor) != TYPE_DICTIONARY or not (descriptor as Dictionary).has("effect_id"):
			return {"ok": false, "code": &"invalid_descriptor", "message": str(descriptor), "details": {}}
		_apply_single(target, str((descriptor as Dictionary)["effect_id"]))
	return {"ok": true, "code": &"ok", "value": {"applied": descriptors.size()}, "receipt": {}}


func apply_effect_ids(effect_ids: Array, source: String = "") -> bool:
	# Two-pass: validate ALL first; if any unknown, apply nothing and return false.
	if not are_effect_ids_known(effect_ids):
		push_warning("EffectResolver: unknown effect id(s) in %s; applying nothing. Source: %s" % [str(effect_ids), source])
		return false
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		push_warning("EffectResolver: GameState autoload not found; cannot apply effects.")
		return false
	for raw in effect_ids:
		_apply_single(gs, _normalize(raw))
	return true


func _apply_single(gs: Node, id: String) -> void:
	if _fixed_effects.has(id):
		var d: Dictionary = _fixed_effects[id]
		match d["kind"]:
			"stat":
				gs.change_stat(d["stat"], d["delta"])
			"money":
				gs.change_money(d["delta"])
			"coin":
				gs.change_coins(d["delta"])
		return
	var parts := id.split(":")
	match parts[0]:
		"inventory":
			# inventory:add:<item>
			if parts.size() == 3 and parts[1] == "add":
				gs.add_inventory(parts[2], 1)
		"affection":
			# affection:<friend>:<+1|+2|-1>
			if parts.size() == 3:
				gs.change_affection(parts[1], _signed(parts[2]))
		"friend_attitude":
			# friend_attitude:<friend>:<attitude>
			if parts.size() == 3:
				gs.set_friend_attitude(parts[1], parts[2])
		"inter_friend_affection":
			# inter_friend_affection:<a>:<b>:<+1|-1>
			if parts.size() == 4:
				gs.change_inter_friend_affection(parts[1], parts[2], _signed(parts[3]))
		"minesweeper":
			# round_floor:-1 or max_rounds:+1 (alias) -> always change_minesweeper_round_floor(-1)
			gs.change_minesweeper_round_floor(-1)


func _signed(token: String) -> int:
	# Parse "+2" / "-1" / "+1" into an int.
	return int(token)
