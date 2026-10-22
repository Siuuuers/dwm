extends "res://addons/gut/test.gd"
# Shop data/rules unit tests (prompt_docs/requirements/verification.md). The full ShopApp buy flow
# (quantity selector, spend/refund) is Phase 3 UI; Phase 1 verifies the data + effect rules.
#
# OBLIGATION MAP (dwm-p2r.16 DECISION 9.13):
#   * Clause 46 -- exact Schedule/Shop registry-to-DataCatalog projection parity (plan line 797).
#     DEEP, field-level, per DECISION 9.10.
#   * DECISION 5's deferred promise: the registry fingerprint and 20-record count are asserted in
#     Task-1 parity tests rather than pinned inside DataCatalog, because a hardcoded digest in
#     production would itself be a stored registry fact that Step 1.3 forbids.
# This file is the forced home for both halves, not the chosen one: it is the only test in the repo
# that reads DataCatalog shop rows, nothing anywhere reads get_schedule_action*, and Step 1.5 pins
# exactly 22 non-UID paths so no third Modify path is legal.
#
# TWO PARITY LAYERS, DELIBERATELY (DECISION 11.9). Hardcoded literals are the independent check
# that both sides are not wrong together; the registry cross-check is what plan line 797's
# "registry-to-DataCatalog parity" literally asks for. The Shop half needs both: DECISION 4 verified
# DataCatalog's current currency and price ALREADY equal the target values, so a literals-only test
# would pass at RED, pass after Step 1.3, and never notice whether delegation happened at all.
#
# PARSE HAZARDS: MinesweeperShopRegistry is absent from the global script class cache under a
# headless run and is preloaded by path (DECISION 9.18); ScheduleActionRegistry, ScheduleActionData
# and DataCatalog are registered and safe to name. Every new local declaration carries an explicit
# type because GUT treats an inferred-Variant `:=` as a parse error (DECISION 10.7).

const SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")

# The registry-derived projection, in registry-derived ORDER (dwm-p2r.16 DECISION 11.8 / C1).
# The manifest is sorted by action_id, so the three action_kind=ordinary records project as
# [rest, training, working] and the one synthesized non-null route_id appends 'dating'. This is NOT
# today's DataCatalog order -- DECISION 3's claim that the projection "reproduces the current 4-row
# output exactly" holds as a SET and fails as an ordered list. Pinning today's order instead would
# force DataCatalog to carry an explicit ordering list, which is itself a Schedule fact the registry
# does not own. display_name, localization_key and image_path stay DERIVED presentation.
const SCHEDULE_PROJECTION := [
	{
		"id": "rest",
		"display_name": "Rest",
		"localization_key": "schedule.action.rest",
		"motivation_cost": 1,
		"effect_ids": ["pressure:-2", "health:+1"],
		"requires_friend": false,
		"image_path": "res://art/schedule/rest.png",
	},
	{
		"id": "training",
		"display_name": "Training",
		"localization_key": "schedule.action.training",
		"motivation_cost": 1,
		"effect_ids": ["pressure:+1", "health:+2"],
		"requires_friend": false,
		"image_path": "res://art/schedule/training.png",
	},
	{
		"id": "working",
		"display_name": "Working",
		"localization_key": "schedule.action.working",
		"motivation_cost": 1,
		"effect_ids": ["pressure:+2", "health:-2", "money:+30"],
		"requires_friend": false,
		"image_path": "res://art/schedule/working.png",
	},
	{
		"id": "dating",
		"display_name": "Dating",
		"localization_key": "schedule.action.dating",
		"motivation_cost": 1,
		"effect_ids": [],
		"requires_friend": true,
		"image_path": "res://art/schedule/dating.png",
	},
]

# 'dating' is deliberately absent: it is a route_id, not an action_id, so find_record("dating")
# answers unregistered_action and only these three can be cross-checked against the registry.
const ORDINARY_ACTION_IDS := ["rest", "training", "working"]

const SCHEDULE_REGISTRY_FINGERPRINT := "71eb92c6dc3b902cc9e6c17928685c0a4772a9da51150316b29177fef0d73c76"
const SCHEDULE_MANIFEST_PATH := "res://data/manifests/schedule_actions.v1.json"
const SCHEDULE_RECORD_COUNT := 20

# max_purchases is DERIVED from the registry record's cap.per_branch; the structured cap also
# carries per_causal_day, which DataCatalog does not and should not expose (DECISION 4).
const SHOP_PARITY := [
	{
		"item_id": "lucky_charm",
		"currency": "minesweeper_coin",
		"price": 1,
		"effect_ids": ["inventory:add:lucky_charm"],
		"max_purchases": 1,
	},
	{
		"item_id": "debug_key",
		"currency": "minesweeper_coin",
		"price": 3,
		"effect_ids": ["inventory:add:debug_key"],
		"max_purchases": 1,
	},
	{
		"item_id": "supportz",
		"currency": "money",
		"price": 45,
		"effect_ids": ["minesweeper:round_floor:-1"],
		"max_purchases": 3,
	},
]

var _dc: DataCatalog


func before_each() -> void:
	_dc = DataCatalog.new()


func test_thirteen_shop_items() -> void:
	var items := _dc.get_shop_items()
	assert_eq(items.size(), 13, "exactly 13 shop item templates")


func test_supportz_properties() -> void:
	var s := _dc.get_shop_item("supportz")
	assert_false(s.is_empty(), "supportz exists")
	assert_true(bool(s["is_secret_buy_button"]), "supportz is a secret buy button")
	assert_false(bool(s["is_visible_in_shop"]), "supportz not shown as a normal item")
	assert_eq(int(s["max_purchases"]), 3, "supportz max 3")
	assert_true("minesweeper:round_floor:-1" in s["effect_ids"], "supportz lowers the round floor")


func test_all_item_effects_are_known() -> void:
	for item in _dc.get_shop_items():
		assert_true(EffectResolver.are_effect_ids_known(item.effect_ids), "effects known for %s" % item.id)


func test_currencies_valid() -> void:
	for item in _dc.get_shop_items():
		assert_true(item.currency == "money" or item.currency == "minesweeper_coin", "valid currency for %s" % item.id)


func test_gift_items_flagged() -> void:
	var pineapple := _dc.get_shop_item("pineapple_bun")
	assert_true(bool(pineapple["is_gift"]), "pineapple_bun is a gift")
	var priscilla_gift := _dc.get_shop_item("priscilla_gift")
	assert_true(bool(priscilla_gift["is_special_gift"]), "priscilla_gift is a special gift")


# ---- clause 46: Schedule registry-to-DataCatalog projection parity ----

func test_schedule_projection_matches_the_registry_derived_rows_in_order() -> void:
	var actions: Array = _dc.get_schedule_actions()
	assert_eq(actions.size(), SCHEDULE_PROJECTION.size(),
		"the projection carries exactly the three ordinary records plus one synthesized route")
	for index: int in range(mini(actions.size(), SCHEDULE_PROJECTION.size())):
		var expected: Dictionary = SCHEDULE_PROJECTION[index]
		var action: ScheduleActionData = actions[index] as ScheduleActionData
		var id: String = str(expected["id"])
		assert_not_null(action, "row %d must be a ScheduleActionData" % index)
		if action == null:
			continue
		assert_eq(action.id, id, "row %d id" % index)
		assert_eq(action.display_name, str(expected["display_name"]), "%s display_name" % id)
		assert_eq(action.localization_key, str(expected["localization_key"]),
			"%s localization_key" % id)
		assert_eq(action.motivation_cost, int(expected["motivation_cost"]),
			"%s motivation_cost" % id)
		assert_eq(action.effect_ids, expected["effect_ids"], "%s effect_ids" % id)
		assert_eq(action.requires_friend, bool(expected["requires_friend"]),
			"%s requires_friend" % id)
		assert_eq(action.image_path, str(expected["image_path"]), "%s image_path" % id)


func test_schedule_action_lookup_agrees_with_the_projection() -> void:
	for expected: Dictionary in SCHEDULE_PROJECTION:
		var id: String = str(expected["id"])
		var found: Dictionary = _dc.get_schedule_action(id)
		assert_false(found.is_empty(), "%s must resolve" % id)
		assert_eq(str(found.get("id", "")), id, "%s id" % id)
		assert_eq(int(found.get("motivation_cost", -1)), int(expected["motivation_cost"]),
			"%s motivation_cost" % id)
		assert_eq(found.get("effect_ids", []), expected["effect_ids"], "%s effect_ids" % id)
		assert_eq(bool(found.get("requires_friend", not bool(expected["requires_friend"]))),
			bool(expected["requires_friend"]), "%s requires_friend" % id)
	assert_true(_dc.get_schedule_action("solo:priscilla:day1").is_empty(),
		"a raw registry action_id is not a projected Schedule action")
	assert_true(_dc.get_schedule_action("nonexistent").is_empty(), "an unknown action resolves empty")


# CHARACTERIZATION, GREEN AT RED. The registry is already implemented and green from dwm-wks, and
# DECISION 3 verified the ordinary effects are byte-identical to DataCatalog's, so this passes now.
# It is what plan line 797's "registry-to-DataCatalog parity" literally asks for on the Schedule
# half, and it stays green only while the projection keeps agreeing with the registry.
func test_schedule_ordinary_rows_equal_the_registry_records() -> void:
	var loaded: Dictionary = ScheduleActionRegistry.load_current()
	assert_true(loaded.get("ok", false),
		"the Schedule registry must load: %s" % str(loaded.get("code", &"")))
	if not loaded.get("ok", false):
		return
	var value: Dictionary = loaded.get("value", {}) as Dictionary
	var registry: ScheduleActionRegistry = value.get("registry") as ScheduleActionRegistry
	for id: String in ORDINARY_ACTION_IDS:
		var fetched: Dictionary = registry.find_record(id)
		assert_true(fetched.get("ok", false), "%s must be a registered ordinary action" % id)
		if not fetched.get("ok", false):
			continue
		var record: Dictionary = (fetched.get("value", {}) as Dictionary).get("record", {}) as Dictionary
		var projected: Dictionary = _dc.get_schedule_action(id)
		assert_eq(int(projected.get("motivation_cost", -1)), int(record.get("motivation_cost", -2)),
			"%s motivation_cost is projected, not stored" % id)
		assert_eq(projected.get("effect_ids", []), record.get("effect_ids", []),
			"%s effect_ids are projected, not stored" % id)
		assert_eq(bool(projected.get("requires_friend", true)),
			not (record.get("participants", []) as Array).is_empty(),
			"%s requires_friend is derived from participants" % id)


# DECISION 5 deferred these two here rather than pinning a digest inside DataCatalog, where it
# would be a stored registry fact that Step 1.3 forbids.
func test_schedule_registry_fingerprint_and_record_count_are_unchanged() -> void:
	var loaded: Dictionary = ScheduleActionRegistry.load_current()
	assert_true(loaded.get("ok", false), "the Schedule registry must load")
	if not loaded.get("ok", false):
		return
	var value: Dictionary = loaded.get("value", {}) as Dictionary
	assert_eq(str(value.get("registry_fingerprint", "")), SCHEDULE_REGISTRY_FINGERPRINT,
		"the canonical registry fingerprint is the one dwm-wks shipped")
	var parsed: Dictionary = StrictJson.parse_object(
		FileAccess.get_file_as_string(SCHEDULE_MANIFEST_PATH))
	assert_true(parsed.get("ok", false), "the Schedule manifest must strict-parse")
	var manifest: Dictionary = parsed.get("value", {}) as Dictionary
	assert_eq((manifest.get("records", []) as Array).size(), SCHEDULE_RECORD_COUNT,
		"the registry still carries exactly twenty records")


# ---- clause 46: Shop registry-to-DataCatalog projection parity ----

func test_shop_projection_matches_the_frozen_literals() -> void:
	for expected: Dictionary in SHOP_PARITY:
		var item_id: String = str(expected["item_id"])
		var item: Dictionary = _dc.get_shop_item(item_id)
		assert_false(item.is_empty(), "%s must resolve" % item_id)
		assert_eq(str(item.get("currency", "")), str(expected["currency"]), "%s currency" % item_id)
		assert_eq(int(item.get("price", -1)), int(expected["price"]), "%s price" % item_id)
		assert_eq(item.get("effect_ids", []), expected["effect_ids"], "%s effect_ids" % item_id)
		assert_eq(int(item.get("max_purchases", -1)), int(expected["max_purchases"]),
			"%s max_purchases" % item_id)


# Task 7 (dwm-p2r.32.7): MinesweeperShopPurchaseParticipant interprets exactly this closed 3-item
# union itself (no generic effect-string execution path, per the frozen contract's own words) --
# lucky_charm/debug_key grant their capability via inventory ownership, supportz spends money and
# decrements the round floor. A regression guard: if the registry's item-id set ever changes, this
# fails loudly rather than the participant silently rejecting every purchase as unregistered.
func test_registry_ids_are_the_closed_three_item_set_the_shop_purchase_participant_depends_on() -> void:
	assert_eq(SHOP_REGISTRY.get_ids(), ["lucky_charm", "debug_key", "supportz"])


# The only genuinely RED Shop assertion: get_record() answers not_implemented today, so this can go
# green only once the registry works AND DataCatalog delegates to it (DECISION 11.9).
func test_shop_projection_equals_the_registry_records() -> void:
	var initialized: Dictionary = SHOP_REGISTRY.initialize()
	assert_true(initialized.get("ok", false),
		"the Shop registry must load: %s" % str(initialized.get("code", &"")))
	for expected: Dictionary in SHOP_PARITY:
		var item_id: String = str(expected["item_id"])
		var fetched: Dictionary = SHOP_REGISTRY.get_record(item_id)
		assert_true(fetched.get("ok", false),
			"get_record(%s) must succeed: %s" % [item_id, str(fetched.get("code", &""))])
		if not fetched.get("ok", false):
			continue
		var record: Dictionary = (fetched.get("value", {}) as Dictionary).get("record", {}) as Dictionary
		var cap: Dictionary = record.get("cap", {}) as Dictionary
		var item: Dictionary = _dc.get_shop_item(item_id)
		assert_eq(str(item.get("currency", "")), str(record.get("currency", "")),
			"%s currency is projected, not stored" % item_id)
		assert_eq(int(item.get("price", -1)), int(record.get("price", -2)),
			"%s price is projected, not stored" % item_id)
		assert_eq(item.get("effect_ids", []), record.get("effect_ids", []),
			"%s effect_ids are projected, not stored" % item_id)
		assert_eq(int(item.get("max_purchases", -1)), int(cap.get("per_branch", -2)),
			"%s max_purchases is derived from cap.per_branch" % item_id)


func test_retired_items_are_absent_and_mixed_items_keep_only_pressure() -> void:
	for item_id: String in ["coffee", "pep_note", "bandage_pack", "healthy_meal", "protein_box"]:
		assert_true(_dc.get_shop_item(item_id).is_empty(), item_id)
	for item_id: String in ["wine", "premium_care"]:
		assert_eq(_dc.get_shop_item(item_id).effect_ids, ["pressure:-4"])
