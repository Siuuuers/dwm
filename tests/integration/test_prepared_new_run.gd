extends GutTest
## Title consent uses the current scene creation path and real storage.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const TEMPLATE := preload("res://tests/templates/scene_startup/Registration.gd")

class TitleFixture extends FIXTURE:
	func _install_registration() -> Dictionary:
		return TEMPLATE.new()._install_registration()

var scope := preload("res://tests/support/SceneValidationScope.gd").new()
var fixture: RefCounted

func before_each() -> void:
	scope.install(true)
	fixture = TitleFixture.new()
	assert_true(fixture.setup(get_tree()).ok)
	assert_true(fixture.manager.configure_scene_title_new_run(TEMPLATE.OPENING_TARGET).ok)

func after_each() -> void:
	fixture.close()
	scope.restore()

func _context() -> Dictionary:
	return {"route_id": "main", "dialogic_checkpoint": {}, "active_app_id": null,
		"audio_context": {}, "content_version": 1}

func test_prepare_cancel_and_commit_preserve_storage_until_scene_activation() -> void:
	var profile_before: Dictionary = fixture.profile.get_profile_snapshot()
	var identity_before: Dictionary = fixture.root.capture()
	var session_before: Dictionary = fixture.game.capture_live_session()
	var prepared: Dictionary = fixture.manager.prepare_new_run_action(_context())
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_false(prepared.value.requires_confirmation)
	assert_eq(fixture.root.capture(), identity_before)
	assert_eq(fixture.game.capture_live_session(), session_before)
	assert_true(fixture.manager.cancel_prepared_new_run(prepared.value.token).ok)
	assert_true(fixture.manager._prepared_new_run.is_empty())
	assert_false(fixture.read_autosave().ok)
	assert_eq(fixture.profile.get_profile_snapshot(), profile_before)

	prepared = fixture.manager.prepare_new_run_action(_context())
	assert_true(prepared.ok)
	var started: Dictionary = fixture.manager.commit_prepared_new_run(prepared.value.token)
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	assert_false(fixture.game.capture_live_session().value.active)
	fixture.confirm_activation()
	assert_true(fixture.game.capture_live_session().value.active)
	assert_true(fixture.manager._prepared_new_run.is_empty())
	assert_eq(fixture.profile.get_profile_snapshot(), profile_before)
	assert_false(fixture.read_autosave().ok)
	var replacement: Dictionary = fixture.manager.prepare_new_run_action(_context())
	assert_true(replacement.ok)
	assert_true(replacement.value.replaces_live)
	assert_true(replacement.value.requires_confirmation)
	assert_true(fixture.manager.cancel_prepared_new_run(replacement.value.token).ok)
