extends "res://addons/gut/test.gd"
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const GAME := preload("res://autoload/GameState.gd")
const FIXTURE := preload("res://tests/support/SceneTransitionIdentityFixture.gd")

func _programme() -> Dictionary:
	return {"entries": [{"entry_id": "arbitrary.a"}, {"entry_id": "arbitrary.b"}, {"entry_id": "Day99"}],
		"story_days": {"arbitrary.a": 1, "arbitrary.b": 2, "Day99": 1}}

func test_explicit_day_metadata_controls_boundaries_not_entry_spelling() -> void:
	var programme := _programme()
	var bundle := {"scene_programme": programme}
	assert_true(CONTRACT.scene_day_boundary(bundle, "arbitrary.a", "arbitrary.b").value)
	assert_false(CONTRACT.scene_day_boundary(bundle, "arbitrary.a", "Day99").value)
	assert_false(CONTRACT.scene_day_boundary(bundle, "arbitrary.b", "arbitrary.a").ok)
	programme.story_days["arbitrary.b"] = 3
	assert_false(CONTRACT.scene_day_boundary(bundle, "arbitrary.a", "arbitrary.b").ok)
	programme.erase("story_days")
	assert_false(CONTRACT.scene_day_boundary(bundle, "arbitrary.a", "arbitrary.b").value,
		"historical programmes retain their no-renewal behavior")

func test_day_metadata_requires_complete_exact_integer_coverage() -> void:
	var programme := _programme()
	assert_true(CONTRACT.validate_story_days(programme).ok)
	for value: Variant in [0, 8, 1.0, true, "1", null]:
		var bad := _programme()
		bad.story_days["arbitrary.a"] = value
		assert_false(CONTRACT.validate_story_days(bad).ok)
	var missing := _programme()
	missing.story_days.erase("arbitrary.a")
	assert_false(CONTRACT.validate_story_days(missing).ok)
	var extra := _programme()
	extra.story_days["unregistered"] = 1
	assert_false(CONTRACT.validate_story_days(extra).ok)
	var renamed := _programme()
	renamed.story_days.erase("arbitrary.a")
	renamed.story_days["unregistered"] = 1
	assert_false(CONTRACT.validate_story_days(renamed).ok)

func test_daily_renewal_preserves_cumulative_rewards_purchases_pressure_and_task_claims() -> void:
	var before: Dictionary = GAME.make_scene_new_run_gameplay()
	before.minesweeper_rounds_left = -1
	before.minesweeper_round_floor = -2
	before.minesweeper_app_rounds_finished_today = 3
	before.minesweeper_money_earned_today = 108
	before.penalty_points_today = 2
	before.penalty_points_total = 5
	before.money = 123
	before.coins = 4
	before.stats.pressure = 8
	before.inventory = {"bookmark": 1}
	before.shop_purchase_counts = {"supportz": 2}
	before.minesweeper_task_rewards_claimed = {"beginner.no_flag": true}
	var original := before.duplicate(true)
	var renewed: Dictionary = GAME.renewed_scene_day_gameplay(before)
	assert_eq(before, original, "prepare never changes live input")
	assert_eq(renewed.minesweeper_rounds_left, 2)
	assert_eq(renewed.minesweeper_app_rounds_finished_today, 0)
	assert_eq(renewed.minesweeper_money_earned_today, 0)
	assert_eq(renewed.penalty_points_today, 0)
	for key: String in before:
		if key not in ["minesweeper_rounds_left", "minesweeper_app_rounds_finished_today", "minesweeper_money_earned_today", "penalty_points_today"]:
			assert_eq(renewed[key], before[key], "preserve " + key)
	renewed.inventory.bookmark = 9
	assert_eq(before.inventory.bookmark, 1, "candidate is detached")

func _completion(fixture: RefCounted, trigger: Dictionary, identity: Dictionary) -> Dictionary:
	var derived: Dictionary = fixture.issuer.derive_child(CONTRACT.scene_day_renewal_request(trigger, identity))
	assert_true(derived.get("ok", false), str(derived))
	if not derived.get("ok", false): return {}
	return {"receipt_id": derived.value.child_id, "provenance": derived.value.provenance}

func test_real_day_allocator_retry_and_selected_load_do_not_share_day_tokens() -> void:
	var fixture := FIXTURE.new()
	var ready: Dictionary = fixture.setup()
	assert_true(ready.get("ok", false), str(ready))
	if not ready.get("ok", false): return
	var trigger: Dictionary = fixture.command_receipts[fixture.event.command_id].duplicate(true)
	var original_identity: Dictionary = FIXTURE.identity(fixture.lifecycle)
	var completion := _completion(fixture, trigger, original_identity)
	if completion.is_empty(): return
	var allocated: Dictionary = fixture.advance(completion)
	assert_true(allocated.get("ok", false), str(allocated))
	if not allocated.get("ok", false): return
	var root_before: Dictionary = fixture.root.capture()
	assert_eq(fixture.advance(completion), allocated, "same operation reuses durable allocation")
	assert_eq(fixture.root.capture(), root_before, "retry consumes no root counter")
	var destination := original_identity.duplicate(true)
	destination.causal_day_instance = allocated.value.day_advance_identity_receipt.target_causal_day_instance
	destination.causal_day_instance_issuer_receipt = allocated.value.day_advance_identity_receipt.target_causal_day_instance_issuer_receipt
	assert_true(CONTRACT.validate_scene_day_allocation(trigger, destination, fixture.issuer).ok)
	var changed := trigger.duplicate(true)
	changed.scene_event.result.target_id = "other.target"
	assert_false(CONTRACT.validate_scene_day_allocation(changed, destination, fixture.issuer).ok,
		"a real allocation cannot authorize another transition")
	var restored: Dictionary = fixture.restore_selected(original_identity)
	assert_true(restored.get("ok", false), str(restored))
	if not restored.get("ok", false): return
	var next_completion := _completion(fixture, trigger, FIXTURE.identity(fixture.lifecycle))
	if next_completion.is_empty(): return
	assert_ne(next_completion.receipt_id, completion.receipt_id)
	var restored_allocation: Dictionary = fixture.advance(next_completion)
	assert_true(restored_allocation.get("ok", false), str(restored_allocation))
	if not restored_allocation.get("ok", false): return
	assert_ne(restored_allocation.value.day_advance_identity_receipt.target_causal_day_instance,
		allocated.value.day_advance_identity_receipt.target_causal_day_instance)
	assert_eq(fixture.command_receipts[fixture.event.command_id], trigger, "historical trigger remains unchanged")
