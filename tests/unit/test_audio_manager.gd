extends "res://addons/gut/test.gd"
# AudioManager unit tests (prompt_docs/requirements/audio_preferences.md). The prototype must run with no
# audio files: missing tracks return safe errors and never crash.

func before_each() -> void:
	GameState.reset_game()


func test_expected_bgm_paths_exist() -> void:
	var manifest := AudioManifest.new()
	var expected := manifest.get_expected_audio_paths()
	assert_true(expected.has("bgm"), "expected audio paths include a bgm dictionary")
	assert_true((expected["bgm"] as Dictionary).size() > 0)


func test_play_missing_bgm_returns_safe_error() -> void:
	var res := AudioManager.play_bgm("menu_theme")
	# With no audio files present, this must be a safe missing-audio result, not a crash.
	assert_true(res is Dictionary)
	if not bool(res["ok"]):
		assert_eq(str(res["reason"]), "missing_audio")


func test_context_resolves_track_ids() -> void:
	assert_eq(AudioManager.resolve_bgm_for_context("menu"), "menu_theme")
	assert_eq(AudioManager.resolve_bgm_for_context("minesweeper"), "minesweeper_focus")
	assert_eq(AudioManager.resolve_bgm_for_context("hospital"), "hospital_room")


func test_dating_context_resolution() -> void:
	var lav := AudioManager.resolve_bgm_for_context("dating", {"friend_id": "lavinia", "mood": "mad", "route_type": "solo"})
	assert_eq(lav, "lavinia_mad")
	var tf := AudioManager.resolve_bgm_for_context("dating", {"route_type": "twofriends"})
	assert_eq(tf, "twofriends_absent")


func test_ending_context_resolution() -> void:
	var e := AudioManager.resolve_bgm_for_context("ending", {"ending_id": "ending.priscilla.true"})
	assert_eq(e, "ending_priscilla_true")
	var fallback := AudioManager.resolve_bgm_for_context("ending", {"ending_id": ""})
	assert_eq(fallback, "ending_alone")


func test_volume_settings_apply_no_crash() -> void:
	AudioManager.apply_volume_settings()
	assert_true(true, "applying volume settings did not crash")


func test_runtime_audio_context_is_not_run_save_state() -> void:
	assert_false(GameState.to_save_dict().has("audio_state"))


func test_unknown_runtime_context_no_crash() -> void:
	AudioManager.set_music_context("unknown", {"current_bgm_id": "nonexistent_track"})
	AudioManager.refresh_current_context()
	assert_true(true, "loading save with unknown current_bgm_id did not crash")
