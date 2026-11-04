extends GutTest
## Current scene activation publishes one live generation after both owners confirm.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
var scope := preload("res://tests/support/SceneValidationScope.gd").new()
var fixture: RefCounted

func before_each() -> void:
	scope.install(true)
	fixture = FIXTURE.new()
	assert_true(fixture.setup(get_tree()).ok)

func after_each() -> void:
	fixture.close()
	scope.restore()

func test_scene_activation_waits_for_both_owners_and_replacement_retires_old_handle() -> void:
	var before: Dictionary = fixture.game.capture_live_session().value
	assert_false(before.active)
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	assert_eq(fixture.game.capture_live_session().value, before)
	fixture.participants.route.confirm()
	assert_eq(fixture.game.capture_live_session().value, before)
	fixture.participants.narrative.confirm()
	var first: Dictionary = fixture.game.capture_live_session().value
	assert_true(first.active)
	assert_eq(first.generation, before.generation + 1)
	assert_true(fixture.game.validate_live_session(first).ok)
	assert_false(fixture.gate.is_active())
	fixture.confirm_activation()
	assert_eq(fixture.game.capture_live_session().value, first)
	assert_eq(fixture.participants.route.publications, 1)
	assert_eq(fixture.participants.narrative.publications, 1)

	var second: Dictionary = fixture.start()
	assert_eq(second.get("code"), &"scene_activation_pending", str(second))
	if second.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	var current: Dictionary = fixture.game.capture_live_session().value
	assert_true(current.active)
	assert_eq(current.generation, first.generation + 1)
	assert_ne(current.run_id, first.run_id)
	assert_false(fixture.game.validate_live_session(first).ok)
	assert_true(fixture.game.validate_live_session(current).ok)
