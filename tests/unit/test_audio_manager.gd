extends "res://addons/gut/test.gd"

const MANAGER := preload("res://autoload/AudioManager.gd")
const FAKE_PORT := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const FAKE_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")
const AUDIO_MANIFEST := preload("res://scripts/data/AudioManifest.gd")
const DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")


## dwm-p2r.8 handoff sec 4: one exact 11-id ending map, no suffix inference, no ending_alone
## fallback; retired .true ids fail before any AudioManager mutation.
func test_ending_audio_map_covers_every_canonical_id() -> void:
	var manifest: RefCounted = AUDIO_MANIFEST.new()
	var keys: Array = AUDIO_MANIFEST.ENDING_TRACKS.keys()
	keys.sort()
	var canonical: Array = []
	for id in DATING_ENDING_RULES.CANONICAL_ENDING_IDS:
		canonical.append(str(id))
	canonical.sort()
	assert_eq(keys, canonical, "ending track keys equal CANONICAL_ENDING_IDS")
	for ending_id in canonical:
		var resolved: Dictionary = manifest.resolve_music_context("ending", {"ending_id": ending_id})
		assert_true(resolved.get("ok", false), "resolves " + ending_id)
	assert_eq(str(AUDIO_MANIFEST.ENDING_TRACKS["ending.priscilla.observation"]), "ending_priscilla_observation")
	assert_eq(str(AUDIO_MANIFEST.ENDING_TRACKS["ending.lavinia.observation"]), "ending_lavinia_observation")
	assert_eq(str(AUDIO_MANIFEST.ENDING_TRACKS["ending.sylvia.special"]), "ending_sylvia_special")


func test_ending_audio_rejects_retired_unknown_and_empty_ids() -> void:
	var manifest: RefCounted = AUDIO_MANIFEST.new()
	for bad_id in ["ending.priscilla.true", "ending.lavinia.true", "ending.sylvia.true", "ending.nope", ""]:
		var resolved: Dictionary = manifest.resolve_music_context("ending", {"ending_id": bad_id})
		assert_false(resolved.get("ok", false), "must reject '" + bad_id + "' with no ending_alone fallback")
	assert_false("ending_true" in AUDIO_MANIFEST.BGM_IDS, "generic ending_true tier retired")


class FakeProfile:
	extends Node
	signal preference_changed(path: StringName, value: Variant)
	var values := {
		&"preferences.audio.music_volume": 0.8,
		&"preferences.audio.music_muted": false,
		&"preferences.audio.ambience_volume": 0.65,
		&"preferences.audio.ambience_muted": false,
		&"preferences.audio.sfx_volume": 0.8,
		&"preferences.audio.sfx_muted": false,
		&"preferences.audio.master_volume": 1.0,
		&"preferences.audio.master_muted": false,
		&"preferences.audio.mute_when_inactive": true,
		&"preferences.audio.output_mode": "stereo",
	}

	func get_preference(path: StringName, default_value: Variant = null) -> Variant:
		return values.get(path, default_value)

	func set_preference(path: StringName, value: Variant) -> Dictionary:
		if not values.has(path): return {"ok":false,"code":&"unknown_preference"}
		values[path] = value
		preference_changed.emit(path, value)
		return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


var _profile: FakeProfile
var _port: FakeAudioPlaybackPort
var _manager: Node


func before_each() -> void:
	_profile = FakeProfile.new()
	add_child_autofree(_profile)
	_port = FAKE_PORT.new()
	_manager = MANAGER.new(_port)
	add_child_autofree(_manager)


func test_initialization_preserves_gate_and_builds_exact_pools() -> void:
	var gate: RefCounted = FAKE_GATE.new()
	var configured: Dictionary = _manager.configure_mutation_gate(gate)
	assert_true(configured.get("ok", false), str(configured))
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.configure_mutation_gate(gate)["value"]["already_configured"])
	assert_eq(_manager.configure_mutation_gate(FAKE_GATE.new()).get("code"), &"mutation_gate_already_configured")
	assert_eq(_port.players.size(), 18)
	assert_eq(_manager.initialize(_profile).get("code"), &"already_initialized")


func test_failed_initialization_is_retryable_and_does_not_connect_profile() -> void:
	_port.fail_after(1)
	assert_false(_manager.initialize(_profile).get("ok", true))
	assert_false(_profile.preference_changed.is_connected(Callable(_manager, "_on_preference_changed")))
	_port.fail_after(-1)
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_profile.preference_changed.is_connected(Callable(_manager, "_on_preference_changed")))


func test_volume_clamp_silence_threshold_and_explicit_mute() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_channel_volume(&"music", -2.0).get("ok", false))
	assert_true(_port.bus_states[&"Music"]["muted"])
	assert_eq(_profile.values[&"preferences.audio.music_volume"], 0.0)
	assert_true(_manager.set_channel_volume(&"music", 4.0).get("ok", false))
	assert_almost_eq(_port.bus_states[&"Music"]["db"], 0.0, 0.001)
	assert_true(_manager.set_channel_muted(&"music", true).get("ok", false))
	assert_true(_port.bus_states[&"Music"]["muted"])


func test_exact_threshold_and_focus_loss_overlay_do_not_replace_preferences() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_channel_volume(&"music", 0.0001).get("ok", false))
	assert_true(_port.bus_states[&"Music"]["muted"])
	assert_true(_manager.set_channel_volume(&"music", 0.00011).get("ok", false))
	assert_false(_port.bus_states[&"Music"]["muted"])
	assert_true(_profile.set_preference(&"preferences.audio.mute_when_inactive", true).get("ok", false))
	_manager.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(_port.bus_states[&"Music"]["muted"])
	assert_false(_profile.values[&"preferences.audio.music_muted"])
	_manager.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(_port.bus_states[&"Music"]["muted"])


func test_semantic_contexts_are_exact_and_same_context_is_idempotent() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_music_context("ending", {"ending_id": "ending.priscilla.observation"}).get("ok", false))
	assert_true(_manager.set_ambience_context("hospital").get("ok", false))
	var expected := {
		"music_context_id": "ending",
		"music_context": {"ending_id": "ending.priscilla.observation"},
		"ambience_context_id": "hospital",
		"ambience_context": {},
	}
	assert_eq(_manager.get_semantic_audio_context(), expected)
	var operation_count := _port.operations.size()
	assert_true(_manager.set_music_context("ending", {"ending_id": "ending.priscilla.observation"}).get("unchanged", false))
	assert_eq(_port.operations.size(), operation_count)
	assert_false(_manager.get_semantic_audio_context().has("path"))
	var tween_operation: Dictionary = _port.operations.filter(func(record: Dictionary) -> bool:
		return record["operation"] == &"create_parallel_tween" and record["arguments"]["channel_id"] == &"music"
	)[-1]
	assert_almost_eq(tween_operation["arguments"]["duration"], 0.25, 0.001)


func test_unknown_context_and_cue_never_mutate_semantic_state() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	var before: Dictionary = _manager.get_semantic_audio_context()
	assert_eq(_manager.set_music_context("unknown").get("code"), &"unknown_audio_context")
	assert_eq(_manager.play_sfx("unknown").get("code"), &"unknown_audio_cue")
	assert_eq(_manager.get_semantic_audio_context(), before)


func test_commands_before_initialization_fail_without_touching_port() -> void:
	assert_eq(_manager.set_music_context("menu").get("code"), &"not_initialized")
	assert_eq(_manager.play_sfx("button_accept").get("code"), &"not_initialized")
	assert_eq(_manager.set_channel_volume(&"music", 0.5).get("code"), &"not_initialized")
	assert_eq(_port.operations, [])


func test_sfx_dispatch_uses_registered_manifest_bus() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	var result: Dictionary = _manager.play_sfx("button_accept")
	assert_true(result.get("ok", false), str(result))
	assert_eq(result["value"]["bus"], &"UI")
	assert_eq(result["value"]["player_slot"], 0)
	assert_eq(_manager.play_sfx("button_accept")["value"]["player_slot"], 1)
	_port.players[&"UI0"]["playing"] = false
	assert_eq(_manager.play_sfx("button_accept")["value"]["player_slot"], 0)


func test_full_sfx_pool_reuses_oldest_playing_after_a_free_slot_was_reused() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	for expected_slot in range(MANAGER.UI_PLAYERS.size()):
		assert_eq(_manager.play_sfx("button_accept")["value"]["player_slot"], expected_slot)
	_port.players[&"UI1"]["playing"] = false
	assert_eq(_manager.play_sfx("button_accept")["value"]["player_slot"], 1)
	assert_eq(_manager.play_sfx("button_accept")["value"]["player_slot"], 0)


func test_failed_context_change_rolls_back_runtime_and_semantics() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_music_context("menu").get("ok", false))
	var before: Dictionary = _manager.get_semantic_audio_context()
	_port.fail_after(_port.operations.size() + 3)
	var failed: Dictionary = _manager.set_music_context("hospital")
	assert_false(failed.get("ok", false))
	assert_eq(_manager.get_semantic_audio_context(), before)
	assert_eq(_port.operations[-1]["operation"], &"restore_runtime")
	assert_true(_port.active_tweens.has(&"music"))


func test_every_crossfade_operation_failpoint_preserves_semantics() -> void:
	for offset in range(1, 8):
		var profile := FakeProfile.new()
		add_child_autofree(profile)
		var port: FakeAudioPlaybackPort = FAKE_PORT.new()
		var manager: Node = MANAGER.new(port)
		add_child_autofree(manager)
		assert_true(manager.initialize(profile).get("ok", false))
		assert_true(manager.set_music_context("menu").get("ok", false))
		var base := port.operations.size()
		port.fail_after(base + offset)
		var result: Dictionary = manager.set_music_context("hospital")
		assert_false(result.get("ok", false), "offset %d" % offset)
		assert_eq(manager.get_music_context_id(), "menu", "offset %d" % offset)


func test_rollback_failure_latches_fatal_and_best_effort_mutes_channel() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_music_context("menu").get("ok", false))
	var base := _port.operations.size()
	_port.fail_on([base + 3, base + 4])
	var failed: Dictionary = _manager.set_music_context("hospital")
	assert_eq(failed.get("code"), &"audio_runtime_indeterminate")
	assert_true(failed.get("fatal", false))
	assert_eq(_manager.set_music_context("menu").get("code"), &"audio_runtime_indeterminate")
	assert_true(_port.bus_states[&"Music"]["muted"])


func test_async_old_player_stop_failure_latches_fatal() -> void:
	var gate: RefCounted = FAKE_GATE.new()
	assert_true(_manager.configure_mutation_gate(gate).get("ok", false))
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_music_context("menu").get("ok", false))
	_port.fail_after(_port.operations.size() + 1)
	assert_false(_port.complete_tween(&"music").get("ok", true))
	assert_true(gate.is_fatal_latched())
	assert_eq(_manager.set_music_context("hospital").get("code"), &"audio_runtime_indeterminate")


func test_committed_preference_apply_failure_latches_shared_gate() -> void:
	var gate: RefCounted = FAKE_GATE.new()
	assert_true(_manager.configure_mutation_gate(gate).get("ok", false))
	assert_true(_manager.initialize(_profile).get("ok", false))
	_port.fail_after(_port.operations.size() + 2)
	assert_true(_profile.set_preference(&"preferences.audio.music_volume", 0.4).get("ok", false))
	assert_true(gate.is_fatal_latched())


func test_semantic_restore_is_silent_and_rollback_preserves_exact_runtime() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_music_context("menu").get("ok", false))
	assert_true(_manager.set_ambience_context("rain").get("ok", false))
	_port.players[&"MusicB"]["playback_position"] = 37.25
	_port.players[&"AmbienceB"]["playback_position"] = 11.5
	_port.players[&"AmbienceB"]["stream_paused"] = true
	watch_signals(_manager)
	var snapshot := {
		"music_context_id": "ending",
		"music_context": {"ending_id": "ending.priscilla.observation"},
		"ambience_context_id": "hospital",
		"ambience_context": {},
	}
	var prepared_profile := {"preferences": {"audio": {
		"music_volume": 0.5, "music_muted": false,
		"ambience_volume": 0.4, "ambience_muted": false,
		"sfx_volume": 0.3, "sfx_muted": false,
		"master_volume": 0.2, "master_muted": true,
		"mute_when_inactive": true, "output_mode":"stereo",
	}}}
	var plan: Dictionary = _manager.prepare_semantic_restore(snapshot, prepared_profile)
	assert_true(plan.get("ok", false), str(plan))
	var backup: Dictionary = _manager.capture_restore_state()["value"]
	assert_true(_manager.apply_restore_silent(plan["value"]).get("ok", false))
	assert_eq(_manager.get_semantic_audio_context(), snapshot)
	assert_signal_not_emitted(_manager, "music_context_changed")
	assert_signal_not_emitted(_manager, "ambience_context_changed")
	assert_true(_manager.rollback_restore_silent(backup).get("ok", false))
	assert_eq(_manager.capture_restore_state()["value"], backup,
		"Rollback preserves physical streams, playheads, fades, outputs and manager identities")
	assert_signal_not_emitted(_manager, "audio_settings_applied")
	assert_signal_not_emitted(_manager, "music_context_changed")
	assert_signal_not_emitted(_manager, "ambience_context_changed")
	var operations := _port.operations.size()
	assert_true(_manager.set_music_context("menu").get("unchanged", false),
		"The restored semantic record agrees with the restored stream")
	assert_eq(_port.operations.size(), operations, "An unchanged context never restarts the old stream")
	assert_true(_manager.set_music_context("hospital").get("ok", false))
	assert_eq(_manager._active_players[&"music"], &"MusicA",
		"The next fade selects the player opposite the original MusicB")
	assert_same(_port.players[&"MusicB"].stream, backup.runtime.players[&"MusicB"].stream)
	assert_eq(_port.players[&"MusicB"].playback_position, 37.25)
	assert_true(_manager.finalize_restore().get("ok", false))


func test_restore_capture_refusal_has_no_audio_side_effects() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_music_context("menu").get("ok", false))
	var before: Dictionary = _manager.capture_restore_state()["value"]
	_port.fail_next(&"capture_runtime")
	assert_eq(_manager.capture_restore_state().get("code"), &"injected_audio_failure")
	assert_eq(_manager.capture_restore_state()["value"], before)
	_port.fail_next(&"capture_runtime")
	var failed: Dictionary = _manager.apply_restore_silent({"snapshot": {
		"music_context_id": "hospital", "music_context": {},
		"ambience_context_id": "room", "ambience_context": {},
	}})
	assert_eq(failed.get("code"), &"injected_audio_failure")
	assert_eq(_manager.capture_restore_state()["value"], before)


func test_partial_audio_restore_compensates_before_refusing() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_music_context("menu").get("ok", false))
	assert_true(_manager.set_ambience_context("rain").get("ok", false))
	_port.players[&"MusicB"]["playback_position"] = 19.75
	var before: Dictionary = _manager.capture_restore_state()["value"]
	watch_signals(_manager)
	_port.fail_next(&"assign_stream", &"AmbienceA")
	var failed: Dictionary = _manager.apply_restore_silent({"snapshot": {
		"music_context_id": "hospital", "music_context": {},
		"ambience_context_id": "room", "ambience_context": {},
	}})
	assert_eq(failed.get("code"), &"injected_audio_failure")
	assert_eq(_manager.capture_restore_state()["value"], before,
		"The first channel cannot remain changed when the second channel refuses")
	assert_signal_not_emitted(_manager, "music_context_changed")
	assert_signal_not_emitted(_manager, "ambience_context_changed")
	assert_signal_not_emitted(_manager, "audio_settings_applied")


func test_failed_restore_compensation_latches_shared_recovery() -> void:
	var gate: RefCounted = FAKE_GATE.new()
	assert_true(_manager.configure_mutation_gate(gate).get("ok", false))
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_music_context("menu").get("ok", false))
	var before: Dictionary = _manager.capture_restore_state()["value"]
	assert_true(_manager.apply_restore_silent({"snapshot": {
		"music_context_id": "hospital", "music_context": {},
		"ambience_context_id": "room", "ambience_context": {},
	}}).get("ok", false))
	_port.fail_next(&"restore_runtime")
	var failed: Dictionary = _manager.rollback_restore_silent(before)
	assert_eq(failed.get("code"), &"audio_runtime_indeterminate")
	assert_true(failed.get("fatal", false))
	assert_true(gate.is_fatal_latched())
	assert_eq(_manager.set_music_context("menu").get("code"), &"audio_runtime_indeterminate")


func test_restore_can_clear_channels_and_force_restart_same_context() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	assert_true(_manager.set_music_context("menu").get("ok", false))
	assert_true(_manager.set_ambience_context("hospital").get("ok", false))
	var populated_backup: Dictionary = _manager.capture_restore_state()["value"]
	var empty_snapshot := {
		"music_context_id": "", "music_context": {},
		"ambience_context_id": "", "ambience_context": {},
	}
	var prepared_profile := {"preferences": {"audio": {
		"music_volume": 0.8, "music_muted": false,
		"ambience_volume": 0.65, "ambience_muted": false,
		"sfx_volume": 0.8, "sfx_muted": false,
		"master_volume": 1.0, "master_muted": false,
		"mute_when_inactive": false, "output_mode":"stereo",
	}}}
	var empty_plan: Dictionary = _manager.prepare_semantic_restore(empty_snapshot, prepared_profile)
	assert_true(empty_plan.get("ok", false), str(empty_plan))
	assert_true(_manager.apply_restore_silent(empty_plan["value"]).get("ok", false))
	assert_eq(_manager.get_semantic_audio_context(), empty_snapshot)
	for player_id in MANAGER.MUSIC_PLAYERS + MANAGER.AMBIENCE_PLAYERS:
		assert_false(_port.players[player_id]["playing"])
		assert_null(_port.players[player_id]["stream"])
	assert_true(_manager.rollback_restore_silent(populated_backup).get("ok", false))
	assert_eq(_manager.get_semantic_audio_context(), populated_backup["snapshot"])
	var before_restart := _port.operations.size()
	var same_plan: Dictionary = _manager.prepare_semantic_restore(populated_backup["snapshot"], prepared_profile)
	assert_true(_manager.apply_restore_silent(same_plan["value"]).get("ok", false))
	assert_true(_port.operations.size() > before_restart)


func test_restore_rejects_non_json_context_and_malformed_audio_preferences() -> void:
	assert_true(_manager.initialize(_profile).get("ok", false))
	var snapshot := {
		"music_context_id": "ending",
		"music_context": {&"ending_id": "ending.priscilla.observation"},
		"ambience_context_id": "hospital",
		"ambience_context": {},
	}
	assert_eq(_manager.prepare_semantic_restore(snapshot, {"preferences": {"audio": {}}}).get("code"), &"invalid_audio_snapshot")
	snapshot["music_context"] = {"ending_id": "ending.priscilla.observation"}
	assert_eq(_manager.prepare_semantic_restore(snapshot, {"preferences": {"audio": {"music_volume": 0.5}}}).get("code"), &"invalid_restore_plan")


func test_runtime_audio_context_is_not_run_save_state() -> void:
	assert_false(GameState.to_save_dict().has("audio_state"))
