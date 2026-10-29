extends "res://addons/gut/test.gd"
## Owner tests only: the registration seam is NOT canonical installation or
## Save/Load acceptance. A owns the connected fresh-process journey.

const MANIFEST = preload("res://scripts/data/AudioManifest.gd")
const GATE = preload("res://tests/support/FakeApplicationMutationGate.gd")
const ASSET_PATH: String = "res://tests/fixtures/audio/scene_test_bed.tres"
const ASSET_HASH: String = "f85a90530be2a8f0dad87f80844e6b79d5bdf171975f4c9044a770dc4c2d32aa"

class TestProfile extends Node:
	func get_preference(_path: StringName, default_value: Variant = null) -> Variant:
		return default_value

class RegisteredManager extends "res://autoload/AudioManager.gd":
	var registration: Dictionary = {}
	func _init(port: RefCounted) -> void:
		super(port)
	func _installed_scene_registration() -> Dictionary:
		return {"ok": true, "value": registration.duplicate(true)}

class ResourcePort extends "res://tests/support/FakeAudioPlaybackPort.gd":
	var refuse_restore: bool = false
	func load_stream(path: String) -> Dictionary:
		if path.begins_with("res://tests/fixtures/audio/"):
			var stream: Resource = ResourceLoader.load(path)
			return _record(&"load_stream", {"registered_path": path}, stream)
		return super.load_stream(path)
	func restore_runtime(backup: Dictionary) -> Dictionary:
		if refuse_restore:
			return {"ok": false, "code": &"injected_audio_failure"}
		return super.restore_runtime(backup)

var _manager: RegisteredManager
var _port: ResourcePort


func before_each() -> void:
	_port = ResourcePort.new()
	_manager = RegisteredManager.new(_port)
	_manager.registration = _registration()
	add_child_autofree(_manager)
	var profile: TestProfile = TestProfile.new()
	add_child_autofree(profile)
	assert_true(_manager.initialize(profile).get("ok", false))


func _registration() -> Dictionary:
	return {
		"kind": "scene_reading_registration", "schema_version": 3,
		"entry_manifest": {"entries": [{"entry_id": "scene.test.a"}, {"entry_id": "scene.test.b"}]},
		"audio_catalogue": {
			"kind": "scene_audio_catalogue", "schema_version": 1,
			"assets": [{"asset_id": "TEST.audio.asset.01", "path": ASSET_PATH,
				"sha256": ASSET_HASH, "duration_ms": 4000}],
			"plans": [{"plan_id": "TEST.audio.01", "revision": 1, "variant_id": "base",
				"ambience_asset_id": "TEST.audio.asset.01", "entrance_ms": 0,
				"load_anchor_id": "load.01", "load_anchor_ms": 1000,
				"authorial": true, "essential": false, "missing_media": "silence",
				"music": null, "cues": []}],
			"bindings": [{"entry_id": "scene.test.a", "plan_id": null},
				{"entry_id": "scene.test.b", "plan_id": "TEST.audio.01"}],
		},
	}


func _context(entry: String = "scene.test.b", receipt: String = "admission.test.1") -> Dictionary:
	var made: Dictionary = MANIFEST.make_scene_context(_manager.registration, entry, receipt)
	assert_true(made.get("ok", false), str(made))
	return made.get("value", {})


func _admit(context: Dictionary) -> Dictionary:
	var prepared: Dictionary = _manager.prepare_scene_admission(context)
	assert_true(prepared.get("ok", false), str(prepared))
	return _manager.apply_scene_admission(prepared.get("value", {}))


func _profile_snapshot() -> Dictionary:
	return {"preferences": {"audio": {
		"master_volume": 1.0, "master_muted": false,
		"music_volume": 0.8, "music_muted": false,
		"ambience_volume": 0.65, "ambience_muted": false,
		"sfx_volume": 0.8, "sfx_muted": false,
		"mute_when_inactive": true, "output_mode": "stereo",
	}}}


func _assert_long_lived_silence() -> void:
	for id: StringName in [&"MusicA", &"MusicB", &"AmbienceA", &"AmbienceB"]:
		assert_false(_port.players[id].playing)
		assert_null(_port.players[id].stream)


func test_prepare_loads_real_fixture_without_changing_playback_or_semantics() -> void:
	var before: Dictionary = _manager.capture_restore_state().value
	var start: int = _port.operations.size()
	var context: Dictionary = _context()
	var prepared: Dictionary = _manager.prepare_scene_admission(context)
	assert_true(prepared.get("ok", false), str(prepared))
	for operation: Dictionary in _port.operations.slice(start):
		assert_eq(operation.operation, &"load_stream")
	assert_eq(_manager.capture_restore_state().value, before)
	context.selection.anchor_id = "tampered"
	assert_eq(prepared.value.snapshot.selection.anchor_id, "load.01", "prepared input is detached")


func test_forward_zero_is_idempotent_but_restore_uses_authored_one_second() -> void:
	var context: Dictionary = _context()
	assert_true(_admit(context).get("ok", false))
	assert_eq(_port.players[&"AmbienceA"].playback_position, 0.0)
	_port.players[&"AmbienceA"].playback_position = 2.75
	var prepared: Dictionary = _manager.prepare_scene_admission(context)
	var count: int = _port.operations.size()
	assert_true(_manager.apply_scene_admission(prepared.value).get("unchanged", false))
	assert_eq(_port.operations.size(), count)
	assert_eq(_port.players[&"AmbienceA"].playback_position, 2.75)
	var restored: Dictionary = _manager.prepare_semantic_restore(context, _profile_snapshot())
	assert_true(restored.get("ok", false), str(restored))
	watch_signals(_manager)
	assert_true(_manager.apply_restore_silent(restored.value).get("ok", false))
	assert_eq(_port.players[&"AmbienceA"].playback_position, 1.0)
	assert_eq(_manager.get_semantic_audio_context(), context)
	assert_signal_not_emitted(_manager, "music_context_changed")
	assert_signal_not_emitted(_manager, "ambience_context_changed")
	assert_true(_manager.finalize_restore().get("ok", false))
	var detached: Dictionary = _manager.get_semantic_audio_context()
	detached.selection.anchor_id = "tampered"
	assert_eq(_manager.get_semantic_audio_context(), context)


func test_new_admission_receipt_restarts_same_plan_at_entrance() -> void:
	assert_true(_admit(_context()).get("ok", false))
	_port.players[&"AmbienceA"].playback_position = 2.75
	var next: Dictionary = _context("scene.test.b", "admission.test.2")
	assert_true(_admit(next).get("ok", false))
	assert_eq(_port.players[&"AmbienceA"].playback_position, 0.0)
	assert_eq(_manager.get_semantic_audio_context(), next)

func test_new_run_restore_path_uses_entrance_then_explicit_load_uses_anchor() -> void:
	var context: Dictionary = _context()
	var preferences: Dictionary = _profile_snapshot()
	preferences["scene_audio_mode"] = "entry"
	var initial: Dictionary = _manager.prepare_semantic_restore(context, preferences)
	assert_true(initial.get("ok", false), str(initial))
	assert_true(_manager.apply_restore_silent(initial.value).get("ok", false))
	assert_eq(_port.players[&"AmbienceA"].playback_position, 0.0)
	assert_eq(_manager.get_semantic_audio_context(), context)
	assert_true(_manager.finalize_restore().get("ok", false))
	var loaded: Dictionary = _manager.prepare_semantic_restore(context, _profile_snapshot())
	assert_true(loaded.get("ok", false), str(loaded))
	assert_true(_manager.apply_restore_silent(loaded.value).get("ok", false))
	assert_eq(_port.players[&"AmbienceA"].playback_position, 1.0, "Load of the same initial admission uses its anchor")
	assert_false(_manager.get_semantic_audio_context().has("scene_audio_mode"))

func test_invalid_restore_mode_refuses_before_any_output_mutation() -> void:
	var context: Dictionary = _context()
	assert_true(_admit(context).get("ok", false))
	var before: Dictionary = _manager.capture_restore_state().value
	var preferences: Dictionary = _profile_snapshot()
	preferences["scene_audio_mode"] = "invalid"
	assert_false(_manager.prepare_semantic_restore(context, preferences).get("ok", true))
	var prepared: Dictionary = _manager.prepare_semantic_restore(context, _profile_snapshot())
	assert_true(prepared.get("ok", false))
	prepared.value["scene_audio_mode"] = "invalid"
	assert_false(_manager.apply_restore_silent(prepared.value).get("ok", true))
	assert_eq(_manager.capture_restore_state().value, before)


func test_explicit_silent_binding_clears_previous_audio_without_warning() -> void:
	assert_true(_admit(_context()).get("ok", false))
	watch_signals(_manager)
	var silent: Dictionary = _context("scene.test.a", "admission.test.2")
	assert_true(_admit(silent).get("ok", false))
	_assert_long_lived_silence()
	assert_eq(_manager.get_semantic_audio_context(), silent)
	assert_signal_not_emitted(_manager, "audio_warning")


func test_missing_registered_media_adopts_semantics_with_silence_and_warning() -> void:
	assert_true(_admit(_context()).get("ok", false))
	_manager.registration.audio_catalogue.assets[0].path = "res://tests/fixtures/audio/absent_scene_bed.tres"
	var missing: Dictionary = _context("scene.test.b", "admission.test.2")
	watch_signals(_manager)
	assert_true(_admit(missing).get("ok", false))
	_assert_long_lived_silence()
	assert_eq(_manager.get_semantic_audio_context(), missing)
	assert_signal_emitted(_manager, "audio_warning")
	var warnings: Array = get_signal_parameters(_manager, "audio_warning")
	assert_eq(warnings[0].code, &"missing_audio")
	assert_eq(warnings[0].semantic_id, "TEST.audio.asset.01")


func test_present_wrong_digest_refuses_before_any_port_mutation() -> void:
	_manager.registration.audio_catalogue.assets[0].sha256 = "0".repeat(64)
	var context: Dictionary = _context()
	var before: Dictionary = _manager.capture_restore_state().value
	var count: int = _port.operations.size()
	assert_eq(_manager.prepare_scene_admission(context).get("code"), &"scene_audio_asset_digest_mismatch")
	assert_eq(_manager.apply_scene_admission({"snapshot": context}).get("code"), &"scene_audio_asset_digest_mismatch")
	assert_eq(_port.operations.size(), count)
	assert_eq(_manager.capture_restore_state().value, before)


func test_wrong_registration_or_selection_refuses_without_playback_changes() -> void:
	var context: Dictionary = _context()
	var wrong_registration: Dictionary = context.duplicate(true)
	wrong_registration.registration_sha256 = "0".repeat(64)
	var wrong_selection: Dictionary = context.duplicate(true)
	wrong_selection.selection.anchor_id = "unregistered"
	var count: int = _port.operations.size()
	assert_false(_manager.prepare_scene_admission(wrong_registration).get("ok", true))
	assert_false(_manager.apply_scene_admission({"snapshot": wrong_selection}).get("ok", true))
	assert_eq(_port.operations.size(), count)
	_assert_long_lived_silence()


func test_partial_apply_failure_restores_prior_physical_and_semantic_state() -> void:
	assert_true(_admit(_context()).get("ok", false))
	_port.players[&"AmbienceA"].playback_position = 2.75
	var before: Dictionary = _manager.capture_restore_state().value
	var plan: Dictionary = _manager.prepare_scene_admission(_context("scene.test.b", "admission.test.2"))
	_port.fail_next(&"play", &"AmbienceA")
	assert_eq(_manager.apply_scene_admission(plan.value).get("code"), &"injected_audio_failure")
	assert_eq(_manager.capture_restore_state().value, before)


func test_failed_compensation_latches_fatal_and_shared_recovery() -> void:
	var gate: RefCounted = GATE.new()
	assert_true(_manager.configure_mutation_gate(gate).get("ok", false))
	assert_true(_admit(_context()).get("ok", false))
	var plan: Dictionary = _manager.prepare_scene_admission(_context("scene.test.b", "admission.test.2"))
	_port.fail_next(&"play", &"AmbienceA")
	_port.refuse_restore = true
	var failed: Dictionary = _manager.apply_scene_admission(plan.value)
	assert_eq(failed.get("code"), &"audio_runtime_indeterminate")
	assert_true(failed.get("fatal", false))
	assert_true(gate.is_fatal_latched())
	assert_eq(_manager.prepare_scene_admission(_context()).get("code"), &"audio_runtime_indeterminate")


func test_legacy_restore_can_replace_scene_and_rollback_recovers_scene_playhead() -> void:
	assert_true(_admit(_context()).get("ok", false))
	_port.players[&"AmbienceA"].playback_position = 2.75
	var before: Dictionary = _manager.capture_restore_state().value
	var legacy: Dictionary = {"music_context_id": "menu", "music_context": {},
		"ambience_context_id": "rain", "ambience_context": {}}
	var plan: Dictionary = _manager.prepare_semantic_restore(legacy, _profile_snapshot())
	assert_true(plan.get("ok", false), str(plan))
	assert_true(_manager.apply_restore_silent(plan.value).get("ok", false))
	assert_eq(_manager.get_semantic_audio_context(), legacy)
	var active: Dictionary = _manager.get("_active_players")
	assert_eq(_port.players[active[&"music"]].playback_position, 0.0)
	assert_eq(_port.players[active[&"ambience"]].playback_position, 0.0)
	assert_true(_manager.rollback_restore_silent(before).get("ok", false))
	assert_eq(_manager.capture_restore_state().value, before)


func _use_music_bed() -> void:
	_manager.registration.audio_catalogue.schema_version = 2
	_manager.registration.audio_catalogue.plans[0].ambience_asset_id = null
	_manager.registration.audio_catalogue.plans[0].music = "TEST.audio.asset.01"


func test_music_bed_uses_music_player_and_restores_authored_anchor() -> void:
	_use_music_bed()
	var context: Dictionary = _context()
	assert_true(_admit(context).get("ok", false))
	assert_true(_port.players[&"MusicA"].playing)
	assert_eq(_port.players[&"MusicA"].playback_position, 0.0)
	assert_false(_port.players[&"AmbienceA"].playing)
	assert_null(_port.players[&"AmbienceA"].stream)
	_port.players[&"MusicA"].playback_position = 2.75
	var restore: Dictionary = _manager.prepare_semantic_restore(context, _profile_snapshot())
	assert_true(restore.get("ok", false))
	assert_true(_manager.apply_restore_silent(restore.value).get("ok", false))
	assert_eq(_port.players[&"MusicA"].playback_position, 1.0)
	assert_eq(_manager.get_semantic_audio_context(), context)
	assert_true(_manager.finalize_restore().get("ok", false))
	var silent: Dictionary = _context("scene.test.a", "admission.music.silent")
	assert_true(_admit(silent).get("ok", false))
	_assert_long_lived_silence()


func test_music_apply_failure_restores_prior_music_output_and_snapshot() -> void:
	_use_music_bed()
	assert_true(_admit(_context()).get("ok", false))
	_port.players[&"MusicA"].playback_position = 2.75
	var before: Dictionary = _manager.capture_restore_state().value
	var plan: Dictionary = _manager.prepare_scene_admission(_context("scene.test.b", "admission.music.2"))
	_port.fail_next(&"play", &"MusicA")
	assert_eq(_manager.apply_scene_admission(plan.value).get("code"), &"injected_audio_failure")
	assert_eq(_manager.capture_restore_state().value, before)



func _inline_registration() -> void:
	_manager.registration.audio_catalogue.schema_version = 3
	var catalogue: Dictionary = _manager.registration.audio_catalogue
	catalogue.assets[0]["gain_db"] = -6.0
	catalogue.plans[0].music = catalogue.plans[0].ambience_asset_id
	catalogue.plans[0].ambience_asset_id = null
	var second: Dictionary = catalogue.plans[0].duplicate(true)
	second.plan_id = "TEST.audio.02"
	catalogue.plans.append(second)


func _inline_admit(plan_id: String, fade: float = 0.0, occurrence: String = "admission.inline") -> Dictionary:
	var context: Dictionary = MANIFEST.make_named_presentation_context(_manager.registration, plan_id, occurrence)
	assert_true(context.ok, str(context))
	var prepared: Dictionary = _manager.prepare_scene_admission(context.value, fade)
	assert_true(prepared.ok, str(prepared))
	return _manager.apply_scene_admission(prepared.value)


func test_inline_same_music_across_occurrences_keeps_playhead_and_gain() -> void:
	_inline_registration()
	assert_true(_inline_admit("TEST.audio.01").ok)
	assert_true(_port.players[&"MusicB"].playing)
	assert_eq(_port.players[&"MusicB"].db, -6.0)
	_port.players[&"MusicB"].playback_position = 2.5
	var operations := _port.operations.size()
	assert_true(_inline_admit("TEST.audio.01", 0.5, "admission.next").unchanged)
	assert_eq(_port.operations.size(), operations, "same selection uses cached media without playback work")
	assert_eq(_port.players[&"MusicB"].playback_position, 2.5)
	assert_eq(_manager.get_semantic_audio_context().admission_receipt_id, "admission.next")


func test_inline_crossfade_stop_and_superseding_play_keep_only_latest_track() -> void:
	_inline_registration()
	assert_true(_inline_admit("TEST.audio.01").ok)
	assert_true(_inline_admit("TEST.audio.02", 0.8).ok)
	assert_eq(_manager.get_semantic_audio_context().selection.plan_id, "TEST.audio.02")
	assert_true(_port.players[&"MusicA"].playing)
	assert_true(_port.players[&"MusicB"].playing)
	assert_eq(_port.active_tweens[&"music"].duration, 0.8)
	assert_true(_inline_admit("", 0.4).ok)
	assert_null(_manager.get_semantic_audio_context().selection, "fade-out selects silence immediately")
	assert_eq(_port.active_tweens[&"music"].tracks.size(), 2, "stop fades both participants")
	assert_true(_inline_admit("TEST.audio.01", 0.2).ok)
	assert_true(_port.complete_tween(&"music").ok)
	assert_true(_port.players[&"MusicB"].playing)
	assert_eq(_port.players[&"MusicB"].db, -6.0)
	assert_false(_port.players[&"MusicA"].playing)
	assert_null(_port.players[&"MusicA"].stream)
	assert_true(_port.active_tweens.is_empty())
	assert_eq(_manager.get_semantic_audio_context().selection.plan_id, "TEST.audio.01")
	assert_true(_inline_admit("").ok)
	_assert_long_lived_silence()


func test_inline_sfx_is_nonlooping_and_does_not_change_music_or_user_output() -> void:
	_inline_registration()
	assert_true(_inline_admit("TEST.audio.01").ok)
	var semantic: Dictionary = _manager.get_semantic_audio_context()
	var output: Dictionary = _port.bus_states.duplicate(true)
	assert_true(_manager.play_scene_sfx("TEST.audio.asset.01").ok)
	assert_true(_port.players[&"SFX0"].playing)
	assert_eq(_port.players[&"SFX0"].db, -6.0)
	assert_eq(_port.players[&"SFX0"].stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_eq(_port.players[&"MusicB"].stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(_manager.get_semantic_audio_context(), semantic)
	assert_eq(_port.bus_states, output)
	assert_true(_manager.play_scene_sfx("TEST.audio.asset.01").ok)
	assert_true(_port.players[&"SFX1"].playing, "a genuine later encounter can play again")


func test_inline_load_during_fades_restores_selection_at_start_and_clears_transients() -> void:
	_inline_registration()
	assert_true(_inline_admit("TEST.audio.01").ok)
	assert_true(_inline_admit("TEST.audio.02", 0.8).ok)
	assert_true(_manager.play_scene_sfx("TEST.audio.asset.01").ok)
	var context: Dictionary = _manager.get_semantic_audio_context()
	var plan: Dictionary = _manager.prepare_semantic_restore(context, _profile_snapshot())
	assert_true(plan.ok)
	assert_true(_manager.apply_restore_silent(plan.value).ok)
	assert_true(_port.active_tweens.is_empty())
	assert_true(_port.players[&"MusicA"].playing)
	assert_false(_port.players[&"MusicB"].playing)
	assert_eq(_port.players[&"MusicA"].playback_position, 0.0, "inline load uses authored entrance, never prior playhead or old anchor")
	assert_false(_port.players[&"SFX0"].playing)
	assert_eq(_manager.get_semantic_audio_context(), context)
	assert_true(_manager.finalize_restore().ok)
	assert_true(_inline_admit("", 0.4).ok)
	plan = _manager.prepare_semantic_restore(_manager.get_semantic_audio_context(), _profile_snapshot())
	assert_true(plan.ok)
	assert_true(_manager.apply_restore_silent(plan.value).ok)
	_assert_long_lived_silence()
	assert_true(_port.active_tweens.is_empty())
