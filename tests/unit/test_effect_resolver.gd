extends "res://addons/gut/test.gd"
# EffectResolver unit tests (prompt_docs/requirements/verification.md). EffectResolver applies
# whitelisted effects onto the real GameState singleton, so we reset before each test.

func before_each() -> void:
	GameState.reset_game()


func test_known_stat_effects_mutate() -> void:
	assert_true(EffectResolver.apply_effect_ids(["pressure:+2"]))
	assert_eq(GameState.get_stat("pressure"), 5, "pressure 3 -> +2 = 5")
	assert_true(EffectResolver.apply_effect_ids(["health:-4"]))
	assert_eq(GameState.get_stat("health"), 2, "health 6 -> -4 = 2")
	assert_true(EffectResolver.apply_effect_ids(["motivation:-1"]))
	assert_eq(GameState.get_stat("motivation"), 6, "motivation 7 -> -1 = 6")


func test_known_money_and_coin_effects() -> void:
	assert_true(EffectResolver.apply_effect_ids(["money:+30"]))
	assert_eq(GameState.money, 30)
	assert_true(EffectResolver.apply_effect_ids(["money:-10"]))
	assert_eq(GameState.money, 20)
	assert_true(EffectResolver.apply_effect_ids(["coin:+1"]))
	assert_eq(GameState.coins, 1)


func test_unknown_effect_blocks_all() -> void:
	assert_false(EffectResolver.apply_effect_ids(["pressure:+2", "bogus:+1"]), "mixed known+unknown applies nothing")
	assert_eq(GameState.get_stat("pressure"), 3, "pressure unchanged after blocked batch")
	assert_false(EffectResolver.is_effect_known("bogus:+1"))
	assert_true(EffectResolver.is_effect_known("pressure:+2"))
	assert_false(EffectResolver.are_effect_ids_known(["pressure:+1", "nope"]))
	assert_true(EffectResolver.are_effect_ids_known(["pressure:+1", "health:-1"]))


func test_inventory_and_gift_effects() -> void:
	assert_true(EffectResolver.apply_effect_ids(["inventory:add:pineapple_bun"]))
	assert_true(int(GameState.inventory.get("pineapple_bun", 0)) >= 1)
	assert_true(EffectResolver.apply_effect_ids(["inventory:add:priscilla_gift"]))
	assert_true(int(GameState.inventory.get("priscilla_gift", 0)) >= 1)


func test_affection_and_attitude_and_inter_friend() -> void:
	var before := int(GameState.affection.get("priscilla", 0))
	assert_true(EffectResolver.apply_effect_ids(["affection:priscilla:+2"]))
	assert_eq(int(GameState.affection.get("priscilla", 0)), before + 2)
	assert_true(EffectResolver.apply_effect_ids(["friend_attitude:lavinia:mad"]))
	assert_eq(str(GameState.friend_attitude.get("lavinia", "")), "mad")
	assert_true(EffectResolver.apply_effect_ids(["inter_friend_affection:priscilla:lavinia:+1"]))


func test_minesweeper_floor_alias_and_clamp() -> void:
	assert_eq(GameState.minesweeper_round_floor, 0)
	assert_true(EffectResolver.apply_effect_ids(["minesweeper:round_floor:-1"]))
	assert_eq(GameState.minesweeper_round_floor, -1)
	assert_true(EffectResolver.apply_effect_ids(["minesweeper:max_rounds:+1"]), "legacy alias known + applies")
	assert_eq(GameState.minesweeper_round_floor, -2)
	# Clamp at -3 no matter how many more.
	EffectResolver.apply_effect_ids(["minesweeper:round_floor:-1"])
	EffectResolver.apply_effect_ids(["minesweeper:round_floor:-1"])
	EffectResolver.apply_effect_ids(["minesweeper:round_floor:-1"])
	assert_eq(GameState.minesweeper_round_floor, -3, "floor clamps at -3")
	assert_eq(GameState.get_minesweeper_display_rounds_max(), 2, "visible denominator stays 2")


# ---- dwm-p2r.8 (Plan-05 Task 3): resolution is split from mutation ----
# resolve_effects() validates and normalizes without finding GameState or mutating anything;
# apply_resolved_descriptors() applies onto an EXPLICIT target and performs no discovery.

func test_resolve_effects_normalizes_without_mutating() -> void:
	var before := GameState.to_save_dict()
	var resolved: Dictionary = EffectResolver.resolve_effects(["  PRESSURE:+2  ", "money:+5"])
	assert_true(resolved.get("ok", false), str(resolved))
	var descriptors: Array = resolved["value"]["descriptors"]
	assert_eq(descriptors.size(), 2, "one descriptor per id")
	assert_eq(str(descriptors[0]["effect_id"]), "pressure:+2", "ids are trimmed and lowercased")
	assert_eq(GameState.to_save_dict(), before, "resolution never mutates GameState")


func test_resolve_effects_rejects_unknown_and_non_string_ids() -> void:
	var unknown: Dictionary = EffectResolver.resolve_effects(["pressure:+2", "not:a:real:effect"])
	assert_false(unknown.get("ok", false), "an unknown id rejects the whole batch")
	assert_eq(str(unknown.get("code")), "unknown_effect_id")
	assert_false(EffectResolver.resolve_effects(["pressure:+2", 7]).get("ok", false), "non-string ids reject")


func test_resolve_effects_accepts_an_empty_batch() -> void:
	var resolved: Dictionary = EffectResolver.resolve_effects([])
	assert_true(resolved.get("ok", false), "an empty batch resolves to no descriptors")
	assert_eq((resolved["value"]["descriptors"] as Array).size(), 0)


func test_apply_resolved_descriptors_requires_an_explicit_target() -> void:
	var resolved: Dictionary = EffectResolver.resolve_effects(["pressure:+2"])
	var applied: Dictionary = EffectResolver.apply_resolved_descriptors(null, resolved["value"]["descriptors"])
	assert_false(applied.get("ok", false), "a null target rejects")
	assert_eq(str(applied.get("code")), "invalid_apply_target")


func test_apply_resolved_descriptors_applies_onto_the_given_target() -> void:
	var resolved: Dictionary = EffectResolver.resolve_effects(["pressure:+2"])
	assert_true(EffectResolver.apply_resolved_descriptors(GameState, resolved["value"]["descriptors"]).get("ok", false))
	assert_eq(GameState.get_stat("pressure"), 5, "the explicit target received the effect")


func test_apply_resolved_descriptors_rejects_malformed_descriptors() -> void:
	var before := GameState.to_save_dict()
	assert_false(EffectResolver.apply_resolved_descriptors(GameState, [{"wrong_key": "x"}]).get("ok", false))
	assert_eq(GameState.to_save_dict(), before, "a malformed descriptor applies nothing")
