extends GutTest
const HOST := preload("res://scripts/ui/gallery/GalleryRehearsalHost.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const GAME := preload("res://autoload/GameState.gd")
const THEME := preload("res://scripts/ui/gallery/GalleryTheme.gd")

class Variables extends RefCounted:
	var values := {"presentation": {"value": 1}}
	var refused := false
	func capture_rehearsal_variables() -> Dictionary:
		return {"ok": false, "code": &"narrative_playback_active"} if refused else {"ok": true, "value": {"variables": values.duplicate(true)}}

class RefusingViewProfile extends RefCounted:
	var writes := 0
	func get_preference(_path: StringName, default_value: Variant = null) -> Variant:
		return default_value
	func set_preferences(_changes: Dictionary) -> Dictionary:
		writes += 1
		return {"ok": false, "code": &"injected_view_write_failure"}

func _fixture(milestone: bool = true) -> Dictionary:
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"practice-ui", preload("res://tests/support/FakeFileOps.gd").new())).ok)
	for tier: String in ["friend", "ambiguous"]:
		assert_true(profile.record_reached_presentation({"entry_id": "dating.solo.priscilla.day1.pre_challenge", "schema_version": 1,
			"fields": {"tier": tier, "tone": "sweet", "attitude": "neutral", "echo_ids": []}}).ok)
	if milestone: assert_true(profile.record_ending_completion("ending.alone", "ending:prior-run:gallery:ending.alone").ok)
	var game: Node = autofree(GAME.new())
	game.reset_game()
	game.route_context.test_marker = [2, 3]
	var variables := Variables.new()
	var host := HOST.new()
	var configured: Dictionary = host.configure(profile, game, variables, null, "en", 100, THEME.build("en", 100, &"after_hours"))
	return {"profile": profile, "game": game, "variables": variables, "host": host, "configured": configured}

func test_practice_requires_milestone_and_start_rechecks_exact_reached_record() -> void:
	var locked := _fixture(false)
	assert_eq(locked.configured.code, &"rehearsal_milestone_required")
	locked.host.free()
	var f := _fixture()
	assert_true(f.configured.ok, str(f.configured))
	add_child_autofree(f.host)
	await get_tree().process_frame
	assert_eq(f.host._records.size(), 2)
	var before: Dictionary = f.game.capture_run_snapshot_input().duplicate(true)
	assert_true(f.profile.reset_gallery().ok)
	f.host._start.pressed.emit()
	assert_null(f.host._dating, "a now-cleared record cannot open through a stale picker")
	assert_eq(f.game.capture_run_snapshot_input(), before)

func test_public_start_continue_and_return_keep_selected_presentation_board_and_variables_private() -> void:
	var f := _fixture()
	assert_true(f.configured.ok, str(f.configured))
	add_child_autofree(f.host)
	await get_tree().process_frame
	var before: Dictionary = f.game.capture_run_snapshot_input().duplicate(true)
	var profile_before: Dictionary = f.profile.get_profile_snapshot()
	f.host._dates.select(1)
	var selected: Dictionary = f.host._records[1].signature.duplicate(true)
	f.variables.values.presentation.value = 77
	f.host._start.pressed.emit()
	assert_not_null(f.host._dating)
	if f.host._dating == null: return
	assert_eq(f.host._sandbox.capture_presentation(f.host._command).value.signature, selected)
	var dating: Control = f.host._dating
	var title: Label = dating._status_label.get_parent().get_node("ChallengeTitle")
	var copy_ink: Color = dating.worksheet.get_theme_color("primary_dark_copy", "Minesweeper")
	assert_eq(title.get_theme_color("font_color"), copy_ink, "Gallery paper styling cannot darken Dating title")
	assert_eq(dating._status_label.get_theme_color("font_color"), copy_ink)
	var physical_copy: Dictionary = dating.presentation_copy(f.host._command.context, "pre_challenge", "en")
	var replay_copy: Dictionary = dating.reached_presentation_copy(selected, "en")
	assert_true(physical_copy.ok and replay_copy.ok)
	assert_eq(replay_copy.value, physical_copy.value)
	assert_eq(title.text, replay_copy.value.title)
	assert_eq(dating._status_label.text, replay_copy.value.body)
	assert_eq(f.host._sandbox.capture_presentation(f.host._command).value.variables.presentation.value, 77,
		"variables are copied at Start, not when the Gallery was configured")
	f.host._dating._continue_button.pressed.emit()
	f.host._dating.worksheet.cell_action_requested.emit(&"reveal", 0, int(f.host._sandbox.pull_physical(f.host._command).value.board.revision))
	var view: Dictionary = f.host._sandbox.pull_physical(f.host._command)
	assert_true(view.ok, str(view))
	assert_eq(view.value.board.width, 18)
	assert_eq(view.value.board.height, 18)
	# Practice copies current hidden inputs: starting Pressure 3 adds one to the 36 base mines.
	assert_eq(f.host._sandbox._sandbox.capture_dating_challenge_state().value.spec.requested_mine_count, 37)
	assert_eq(f.game.capture_run_snapshot_input(), before)
	assert_eq(f.profile.get_profile_snapshot(), profile_before)
	assert_eq(f.variables.values.presentation.value, 77)
	f.host._return_button.pressed.emit()
	assert_null(f.host._dating)
	assert_null(f.host._sandbox._sandbox)
	assert_true(f.host._selection.visible)
	watch_signals(f.host)
	f.host._return_button.pressed.emit()
	assert_signal_emit_count(f.host, "closed", 1)
	assert_eq(f.game.capture_run_snapshot_input(), before)
	assert_eq(f.profile.get_profile_snapshot(), profile_before)

func test_old_deferred_finish_cannot_close_replacement_practice_and_variable_refusal_keeps_picker() -> void:
	var f := _fixture()
	assert_true(f.configured.ok, str(f.configured))
	add_child_autofree(f.host)
	await get_tree().process_frame
	f.variables.refused = true
	f.host._start.pressed.emit()
	assert_null(f.host._dating)
	assert_true(f.host._sandbox._command.is_empty())
	f.variables.refused = false
	f.host._start.pressed.emit()
	if f.host._dating == null:
		fail_test("practice did not start")
		return
	var old_token: String = f.host._command.physical_token
	f.host._on_finished({"physical_token": old_token})
	f.host._return_button.pressed.emit()
	f.host._start.pressed.emit()
	var current_token: String = f.host._command.physical_token
	assert_ne(current_token, old_token)
	await get_tree().process_frame
	assert_not_null(f.host._dating)
	assert_eq(f.host._command.physical_token, current_token)
	f.host._return_button.pressed.emit()


func test_practice_return_keeps_dating_visible_when_view_preference_write_fails() -> void:
	var f := _fixture()
	assert_true(f.configured.ok, str(f.configured))
	add_child_autofree(f.host)
	await get_tree().process_frame
	f.host._start.pressed.emit()
	var dating: Control = f.host._dating
	assert_not_null(dating)
	if dating == null: return
	var view_profile := RefusingViewProfile.new()
	assert_true(dating.worksheet.bind_view_preferences(view_profile, "challenge"))
	dating.worksheet.cell_size = 38
	dating.worksheet._view_dirty = true
	f.host.request_return()
	assert_eq(view_profile.writes, 1)
	assert_same(f.host._dating, dating, "failed write must leave the view and error visible")
	assert_true(dating.worksheet.view_save_failed)
	assert_string_contains(dating.worksheet.cell_size_menu.accessibility_description, "Cell: 36 px")
	assert_string_contains(dating.worksheet.cell_size_menu.accessibility_description, "Could not save view")
	assert_string_contains(dating.worksheet.cell_size_menu.text, "!", "The failure remains visible without opening the size menu.")
	assert_false(f.host._selection.visible)
	assert_not_null(f.host._sandbox._sandbox)
	assert_eq(f.host._status.text, HOST.VIEW_SAVE_COPY.en)
