extends GutTest
const MANAGER := preload("res://autoload/AudioManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FAKE_PORT := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const NATIVE_PORT := preload("res://scripts/audio/AudioPlaybackPort.gd")
const EMPTY := {"music_context_id":"","music_context":{},"ambience_context_id":"","ambience_context":{}}

func _fixture() -> Dictionary:
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("canonical-audio.memory",FILES.new())).ok)
	var port := FAKE_PORT.new()
	var manager := MANAGER.new(port)
	add_child_autofree(manager)
	assert_true(manager.initialize(profile).ok)
	return {"profile":profile,"port":port,"manager":manager}

func test_real_canonical_profile_initializes_master_and_three_channels_without_voice_preferences() -> void:
	var f := _fixture()
	assert_eq(f.manager.CHANNELS.size(),4)
	assert_false(f.manager.CHANNELS.has(&"voice"))
	assert_almost_eq(f.port.bus_states[&"Master"].db,0.0,0.0001)
	assert_true(f.profile.set_preference(&"preferences.audio.master_volume",0.5).ok)
	assert_almost_eq(f.port.bus_states[&"Master"].db,linear_to_db(0.5),0.0001)
	assert_almost_eq(f.port.bus_states[&"Music"].db,linear_to_db(0.8),0.0001)
	assert_true(f.manager.set_channel_muted(&"master",true).ok)
	assert_true(f.port.bus_states[&"Master"].muted)
	assert_false(f.port.bus_states[&"Music"].muted,"local channel preference is not overwritten by master mute")
	assert_eq(f.port.bus_states[&"UI"],f.port.bus_states[&"SFX"])

func test_removed_voice_setters_cannot_write_profile_or_change_playback() -> void:
	var f := _fixture()
	var before: Dictionary = f.profile.get_profile_snapshot()
	var operations: int = f.port.operations.size()
	assert_eq(f.manager.set_channel_volume(&"voice",0.2).code,&"invalid_audio_channel")
	assert_eq(f.manager.set_channel_muted(&"voice",true).code,&"invalid_audio_channel")
	assert_eq(f.profile.get_profile_snapshot(),before)
	assert_eq(f.port.operations.size(),operations)
	assert_eq(f.port.players.size(),18,"the existing playback pools remain unchanged")

func test_music_and_ambience_use_profile_gain_once_at_the_bus() -> void:
	var f := _fixture()
	assert_true(f.profile.set_preference(&"preferences.audio.music_volume", 0.5).ok)
	assert_true(f.profile.set_preference(&"preferences.audio.ambience_volume", 0.25).ok)
	assert_true(f.manager.set_music_context("menu").ok)
	assert_true(f.manager.set_ambience_context("room").ok)
	for channel: StringName in [&"music", &"ambience"]:
		var tween: Dictionary = f.port.active_tweens[channel]
		assert_eq(tween.tracks[0].to_db, 0.0, "crossfade destination does not apply profile volume again")
		assert_true(f.port.complete_tween(channel).ok)
		var player: StringName = f.manager._active_players[channel]
		assert_eq(f.port.players[player].db, 0.0)
	assert_almost_eq(f.port.bus_states[&"Music"].db, linear_to_db(0.5), 0.0001)
	assert_almost_eq(f.port.bus_states[&"Ambience"].db, linear_to_db(0.25), 0.0001)

func test_inactive_muting_defaults_true_and_preference_change_while_inactive_is_applied() -> void:
	var f := _fixture()
	f.manager._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(f.port.bus_states[&"Master"].muted)
	assert_true(f.profile.set_preference(&"preferences.audio.mute_when_inactive",false).ok)
	assert_false(f.port.bus_states[&"Master"].muted)
	assert_true(f.profile.set_preference(&"preferences.audio.mute_when_inactive",true).ok)
	assert_true(f.port.bus_states[&"Master"].muted)
	f.manager._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(f.port.bus_states[&"Master"].muted)
	assert_eq(f.manager.get_semantic_audio_context(),EMPTY)

func test_canonical_restore_is_silent_and_rollback_preserves_profile_revision() -> void:
	var f := _fixture()
	var before: Dictionary = f.manager.capture_restore_state().value
	var profile_before: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	var prepared := profile_before.duplicate(true)
	prepared.preferences.audio.master_volume = 0.25
	prepared.preferences.audio.sfx_muted = true
	var plan: Dictionary = f.manager.prepare_semantic_restore(EMPTY,prepared)
	assert_true(plan.ok)
	if not plan.ok: return
	var publications: Array = []
	f.manager.audio_settings_applied.connect(func(value: Dictionary): publications.append(value))
	assert_true(f.manager.apply_restore_silent(plan.value).ok)
	assert_almost_eq(f.port.bus_states[&"Master"].db,linear_to_db(0.25),0.0001)
	assert_true(f.port.bus_states[&"UI"].muted)
	assert_true(f.manager.rollback_restore_silent(before).ok)
	assert_eq(f.manager.capture_restore_state().value,before)
	assert_eq(f.profile.get_profile_snapshot(),profile_before)
	assert_eq(f.profile.get_profile_revision(),revision)
	assert_true(publications.is_empty())

func test_invalid_canonical_restore_is_rejected_before_any_playback_mutation() -> void:
	var f := _fixture()
	for patch in [{"voice_volume":0.5},{"output_mode":"surround"},{"master_volume":2.0}]:
		var audio: Dictionary = SCHEMA.make_defaults().preferences.audio.duplicate(true)
		audio.merge(patch,true)
		var operations: int = f.port.operations.size()
		var before: Dictionary = f.manager.capture_restore_state().value
		assert_false(f.manager.prepare_semantic_restore(EMPTY,{"audio":audio}).ok)
		assert_false(f.manager.apply_restore_silent({"snapshot":EMPTY,"audio":audio}).ok)
		assert_eq(f.port.operations.size(),operations)
		assert_eq(f.manager.capture_restore_state().value,before)
	var mono: Dictionary = SCHEMA.make_defaults().preferences.audio.duplicate(true)
	mono.output_mode = "mono"
	assert_true(f.manager.prepare_semantic_restore(EMPTY,{"audio":mono}).ok,
		"the output-capable fake models the real mono operation")

func test_bus_failure_restores_master_and_keeps_prior_settings() -> void:
	var f := _fixture()
	var before: Dictionary = f.manager.capture_restore_state().value
	var buses: Dictionary = f.port.bus_states.duplicate(true)
	var candidate: Dictionary = before.settings.duplicate(true)
	candidate[&"master"].volume = 0.2
	f.port.fail_after(f.port.operations.size()+2)
	assert_false(f.manager._apply_settings_silent(candidate).ok)
	assert_eq(f.port.bus_states,buses)
	assert_eq(f.manager.capture_restore_state().value,before)

func test_native_mono_effect_and_master_rollback_preserve_foreign_effects_without_players() -> void:
	var port := NATIVE_PORT.new()
	var bus := AudioServer.get_bus_index(&"Master")
	var foreign := AudioEffectAmplify.new()
	AudioServer.add_bus_effect(bus,foreign)
	var before: Dictionary = port.capture_runtime().value
	assert_true(before.players.is_empty())
	var count := AudioServer.get_bus_effect_count(bus)
	assert_true(port.set_output_mode("mono").ok)
	assert_eq(AudioServer.get_bus_effect_count(bus),count+1)
	var effect: AudioEffectStereoEnhance = port._mono_effect
	assert_eq(effect.pan_pullout,0.0)
	assert_eq(effect.surround,0.0)
	assert_eq(effect.time_pullout_ms,0.0)
	var index: int = port._mono_effect_index(bus)
	assert_true(AudioServer.is_bus_effect_enabled(bus,index))
	var mono: Dictionary = port.capture_runtime().value
	assert_true(port.set_output_mode("stereo").ok)
	assert_false(AudioServer.is_bus_effect_enabled(bus,index))
	assert_true(port.set_bus_state(&"Master",-12.0,true).ok)
	assert_true(port.restore_runtime(mono).ok)
	assert_true(AudioServer.is_bus_effect_enabled(bus,index))
	assert_eq(AudioServer.get_bus_volume_db(bus),mono.bus_states[&"Master"].db)
	assert_eq(AudioServer.is_bus_mute(bus),mono.bus_states[&"Master"].muted)
	assert_eq(port._mono_effect,effect,"the same owned effect survives stereo and rollback")
	assert_true(port.restore_runtime(before).ok)
	assert_eq(AudioServer.get_bus_effect_count(bus),count)
	assert_eq(port.capture_runtime().value,before)
	for slot in range(AudioServer.get_bus_effect_count(bus)-1,-1,-1):
		if AudioServer.get_bus_effect(bus,slot) == foreign: AudioServer.remove_bus_effect(bus,slot)
