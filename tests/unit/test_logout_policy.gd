extends "res://addons/gut/test.gd"

const POLICY := preload("res://scripts/domain/desktop/LogoutPolicy.gd")

func test_no_does_not_save_route_or_complete_but_restores_focus() -> void:
	var decision: Dictionary = POLICY.plan(false, true)
	assert_true(decision.get("ok", false))
	assert_false(decision["confirmed"])
	assert_false(decision["should_save"])
	assert_false(decision["should_route_menu"])
	assert_true(decision["restore_desktop_focus"])
	assert_false(decision["lifecycle_completed"])

func test_yes_with_checkpoint_saves_and_routes_not_completed() -> void:
	var decision: Dictionary = POLICY.plan(true, true)
	assert_true(decision.get("ok", false))
	assert_true(decision["confirmed"])
	assert_true(decision["should_save"])
	assert_true(decision["should_route_menu"])
	assert_false(decision["restore_desktop_focus"])
	assert_false(decision["lifecycle_completed"])

func test_yes_without_checkpoint_no_write_but_routes_not_completed() -> void:
	var decision: Dictionary = POLICY.plan(true, false)
	assert_true(decision.get("ok", false))
	assert_true(decision["confirmed"])
	assert_false(decision["should_save"], "no checkpoint means no write")
	assert_true(decision["should_route_menu"])
	assert_false(decision["lifecycle_completed"])

func test_policy_never_completes_lifecycle() -> void:
	for confirmed in [true, false]:
		for checkpoint in [true, false]:
			assert_false(POLICY.plan(confirmed, checkpoint)["lifecycle_completed"],
				"logout never transitions lifecycle to COMPLETED")
