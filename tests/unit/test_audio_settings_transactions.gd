extends GutTest

const MANAGER := preload("res://autoload/AudioManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const MUSIC := &"preferences.audio.music_volume"

class MemoryFiles extends "res://tests/support/FakeFileOps.gd":
	var reject_write := false
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if reject_write:
			reject_write = false
			return {"ok": false, "code": &"injected_write_failure"}
		return super.write_bytes(path, bytes)

class HookPort extends "res://tests/support/FakeAudioPlaybackPort.gd":
	var pause_state: StringName = &"Active"
	var on_next_bus: Callable
	func begin_pause_suspension(_freeze: Array[StringName], _stop: Array[StringName]) -> Dictionary:
		pause_state = &"Suspended"
		return {"ok": true, "code": &"ok", "value": {"suspended": true}}
	func resume_pause_suspension() -> Dictionary:
		pause_state = &"Active"
		return {"ok": true, "code": &"ok", "value": {"resumed": true}}
	func get_pause_suspension_state() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"state": pause_state}}
	func set_bus_state(bus: StringName, db: float, muted: bool) -> Dictionary:
		var result := super.set_bus_state(bus, db, muted)
		if on_next_bus.is_valid():
			var callback := on_next_bus
			on_next_bus = Callable()
			callback.call()
		return result

func _fixture() -> Dictionary:
	var files := MemoryFiles.new()
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("audio-settings.memory", files)).ok)
	var gate := GATE.new()
	assert_true(profile.configure_mutation_gate(gate).ok)
	var port := HookPort.new()
	var owner := MANAGER.new(port)
	add_child_autofree(owner)
	assert_true(owner.configure_mutation_gate(gate).ok)
	assert_true(owner.initialize(profile).ok)
	return {"profile": profile, "files": files, "port": port, "owner": owner,
		"transactions": owner._settings_transactions, "gate": gate}

func _assert_music(f: Dictionary, volume: float) -> void:
	assert_almost_eq(f.port.bus_states[&"Music"].db, linear_to_db(volume), 0.0001)

func test_preview_changes_only_output_and_cancel_restores_committed_settings() -> void:
	var f := _fixture()
	var snapshot: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	var persisted: Dictionary = f.files.snapshot_persisted()
	var players: Dictionary = f.port.players.duplicate(true)
	var tweens: Dictionary = f.port.active_tweens.duplicate(true)
	var settings: Dictionary = f.owner._settings.duplicate(true)
	var publications: Array = []
	f.profile.preference_changed.connect(func(path, value): publications.append([path, value]))
	var result: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.25)
	assert_true(result.ok)
	if not result.ok: return
	_assert_music(f, 0.25)
	assert_eq(f.owner._settings, settings)
	assert_eq(f.profile.get_profile_snapshot(), snapshot)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(f.files.snapshot_persisted(), persisted)
	assert_true(publications.is_empty())
	assert_eq(f.port.players, players)
	assert_eq(f.port.active_tweens, tweens)
	assert_true(f.owner.cancel_settings_volume_preview(result.value.preview_handle).ok)
	_assert_music(f, 0.8)
	assert_false(f.transactions.has_preview())


func test_restore_capture_refuses_owned_preview_until_normal_cancellation() -> void:
	var f := _fixture()
	assert_true(f.owner.set_music_context("menu").ok)
	var preview: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.25)
	assert_true(preview.ok)
	if not preview.ok: return
	var runtime: Dictionary = f.port.capture_runtime().value
	var persisted: Dictionary = f.files.snapshot_persisted()
	var operations: int = f.port.operations.size()
	var plan := {"snapshot": {
		"music_context_id": "hospital", "music_context": {},
		"ambience_context_id": "room", "ambience_context": {},
	}}
	assert_eq(f.owner.capture_restore_state().get("code"), &"settings_audio_preview_active")
	assert_eq(f.owner.apply_restore_silent(plan).get("code"), &"settings_audio_preview_active")
	assert_eq(f.port.operations.size(), operations, "Refusal does not touch playback or output")
	assert_eq(f.port.capture_runtime().value, runtime)
	assert_eq(f.files.snapshot_persisted(), persisted)
	assert_true(f.transactions.has_preview())
	assert_true(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).ok,
		"The refused restore leaves the original preview handle usable")
	_assert_music(f, 0.8)
	var committed: Dictionary = f.owner.capture_restore_state().value
	assert_true(f.owner.apply_restore_silent(plan).ok)
	assert_true(f.owner.rollback_restore_silent(committed).ok)
	assert_eq(f.owner.capture_restore_state().value, committed)
	assert_false(f.transactions.has_preview())
	assert_eq(f.files.snapshot_persisted(), persisted)


func test_restore_capture_refuses_inside_active_settings_transaction_without_mutation() -> void:
	var f := _fixture()
	var refusals: Array[Dictionary] = []
	f.port.on_next_bus = func():
		var before: Dictionary = f.port.capture_runtime().value
		var count: int = f.port.operations.size()
		var refused: Dictionary = f.owner.capture_restore_state()
		refusals.append(refused)
		assert_eq(refused.get("code"), &"settings_audio_busy")
		assert_eq(f.port.operations.size(), count)
		assert_eq(f.port.capture_runtime().value, before)
	var preview: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.3)
	assert_true(preview.ok)
	assert_eq(refusals.size(), 1)
	if not preview.ok: return
	_assert_music(f, 0.3)
	assert_true(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).ok)
	assert_true(f.owner.capture_restore_state().get("ok", false))
	_assert_music(f, 0.8)

func test_stale_holder_path_and_handle_refuse_without_discarding_current_preview() -> void:
	var f := _fixture()
	var preview: Dictionary = f.owner.preview_settings_volume("first", MUSIC, 0.25)
	assert_true(preview.ok)
	if not preview.ok: return
	var count: int = f.port.operations.size()
	for args in [["second", MUSIC, preview.value.preview_handle],
		["first", &"preferences.audio.sfx_volume", preview.value.preview_handle],
		["first", MUSIC, RefCounted.new()], ["first", MUSIC, null]]:
		assert_eq(f.owner.commit_settings_audio_preference(args[0], args[1], 0.5, args[2]).code, &"stale_settings_volume_preview")
	assert_eq(f.port.operations.size(), count)
	assert_true(f.transactions.has_preview())
	assert_true(f.transactions.cancel_current_preview().ok)
	assert_eq(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).code, &"stale_settings_volume_preview")

func test_commit_publishes_only_after_output_and_committed_settings_are_proved() -> void:
	var f := _fixture()
	var observations: Array = []
	var revision: int = f.profile.get_profile_revision()
	f.profile.preference_changed.connect(func(path, value):
		if path == MUSIC:
			observations.append([value, f.port.bus_states[&"Music"].db, f.owner._settings[&"music"].volume,
				f.transactions.is_busy(), f.transactions.has_preview()]))
	var preview: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.2)
	assert_true(preview.ok)
	if not preview.ok: return
	assert_true(f.owner.commit_settings_audio_preference("settings", MUSIC, 0.3, preview.value.preview_handle).ok)
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_eq(observations.size(), 1)
	if observations.size() == 1:
		assert_eq(observations[0][0], 0.3)
		assert_almost_eq(observations[0][1], linear_to_db(0.3), 0.0001)
		assert_eq(observations[0].slice(2), [0.3, true, false])
	assert_false(f.transactions.is_busy())

func test_publication_callback_can_commit_new_profile_and_latest_output_wins() -> void:
	var f := _fixture()
	var callback_results: Array = []
	f.profile.preference_changed.connect(func(path, value):
		if path == MUSIC and value == 0.3:
			callback_results.append(f.owner.preview_settings_volume("reentrant", MUSIC, 0.9))
			callback_results.append(f.profile.set_preference(MUSIC, 0.6)))
	assert_true(f.owner.commit_settings_audio_preference("settings", MUSIC, 0.3).ok)
	assert_eq(callback_results.size(), 2)
	if callback_results.size() == 2:
		assert_eq(callback_results[0].code, &"settings_audio_busy")
		assert_true(callback_results[1].ok)
	_assert_music(f, 0.6)
	assert_eq(f.owner._settings[&"music"].volume, 0.6)
	assert_eq(f.profile.get_preference(MUSIC), 0.6)

func test_profile_write_during_physical_apply_refuses_stale_candidate_and_settles_latest() -> void:
	var f := _fixture()
	var revision: int = f.profile.get_profile_revision()
	var callback_results: Array = []
	f.port.on_next_bus = func(): callback_results.append(f.profile.set_preference(MUSIC, 0.6))
	var result: Dictionary = f.owner.commit_settings_audio_preference("settings", MUSIC, 0.3)
	assert_eq(result.code, &"settings_audio_commit_conflict")
	assert_eq(callback_results.size(), 1)
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_eq(f.profile.get_preference(MUSIC), 0.6)
	_assert_music(f, 0.6)
	assert_eq(f.owner._settings[&"music"].volume, 0.6)
	assert_false(f.transactions.is_busy())

func test_failed_physical_apply_does_not_write_profile_or_restart_players() -> void:
	var f := _fixture()
	var revision: int = f.profile.get_profile_revision()
	var snapshot: Dictionary = f.profile.get_profile_snapshot()
	var players: Dictionary = f.port.players.duplicate(true)
	var operations: int = f.port.operations.size()
	f.port.fail_after(operations + 2)
	assert_false(f.owner.commit_settings_audio_preference("settings", MUSIC, 0.3).ok)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(f.profile.get_profile_snapshot(), snapshot)
	_assert_music(f, 0.8)
	assert_eq(f.port.players, players)
	for operation: Dictionary in f.port.operations.slice(operations):
		assert_false(operation.operation in [&"play", &"stop", &"stop_and_clear", &"assign_stream", &"restore_runtime", &"kill_tween"])
	assert_false(f.owner._fatal)

func test_disk_failure_compensates_output_without_preference_publication() -> void:
	var f := _fixture()
	var snapshot: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	var publications: Array = []
	f.profile.preference_changed.connect(func(path, value): publications.append([path, value]))
	f.files.reject_write = true
	assert_false(f.owner.commit_settings_audio_preference("settings", MUSIC, 0.3).ok)
	assert_eq(f.profile.get_profile_snapshot(), snapshot)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_true(publications.is_empty())
	_assert_music(f, 0.8)
	assert_false(f.transactions.has_preview())

func test_cancel_uses_latest_committed_profile_even_before_deferred_publication() -> void:
	var f := _fixture()
	var preview: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.2)
	assert_true(preview.ok)
	if not preview.ok: return
	var prepared: Dictionary = f.profile.prepare_preferences({MUSIC: 0.6})
	var committed: Dictionary = f.profile.commit_prepared_profile(prepared.value, true, f.profile.get_profile_revision())
	assert_true(committed.ok)
	assert_true(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).ok)
	_assert_music(f, 0.6)
	assert_eq(f.owner._settings[&"music"].volume, 0.6)
	assert_true(f.profile.publish_deferred_profile_signals(committed.value.publication_id).ok)

func test_reset_rejects_stale_revision_before_output_then_commits_one_current_reset() -> void:
	var f := _fixture()
	var old_revision: int = f.profile.get_profile_revision()
	assert_true(f.profile.set_preference(MUSIC, 0.2).ok)
	var operations: int = f.port.operations.size()
	assert_eq(f.owner.commit_settings_profile_reset("settings", &"reset_preferences", old_revision).code, &"profile_revision_changed")
	assert_eq(f.port.operations.size(), operations)
	var revision: int = f.profile.get_profile_revision()
	assert_true(f.owner.commit_settings_profile_reset("settings", &"reset_preferences", revision).ok)
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_eq(f.profile.get_preference(MUSIC), 0.8)
	_assert_music(f, 0.8)

func test_shared_gate_blocks_output_without_acquiring_or_releasing_it() -> void:
	var f := _fixture()
	var acquired: Dictionary = f.gate.acquire(&"restore")
	assert_true(acquired.ok)
	var count: int = f.port.operations.size()
	assert_eq(f.owner.preview_settings_volume("settings", MUSIC, 0.2).code, &"TRANSACTION_ACTIVE")
	assert_eq(f.port.operations.size(), count)
	assert_eq(f.gate.get_active_owner(), &"restore")
	assert_true(f.gate.release(&"restore", acquired.value.token).ok)
	assert_true(f.owner.commit_settings_audio_preference("settings", MUSIC, 0.2).ok)

func test_failed_cancel_proof_latches_fatal_and_retires_preview() -> void:
	var f := _fixture()
	var preview: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.2)
	assert_true(preview.ok)
	if not preview.ok: return
	f.port.fail_after(f.port.operations.size() + 1)
	assert_eq(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).code, &"audio_runtime_indeterminate")
	assert_true(f.owner._fatal)
	assert_true(f.gate.is_fatal_latched())
	assert_false(f.transactions.has_preview())
	assert_false(f.transactions.is_busy())
	assert_eq(f.profile.get_preference(MUSIC), 0.8)

func test_invalid_drag_commit_settles_output_and_retires_detached_ui_handle() -> void:
	var f := _fixture()
	var preview: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.2)
	assert_true(preview.ok)
	if not preview.ok: return
	var count: int = f.port.operations.size()
	var revision: int = f.profile.get_profile_revision()
	assert_false(f.owner.commit_settings_audio_preference("settings", MUSIC, 2.0, preview.value.preview_handle).ok)
	assert_gt(f.port.operations.size(), count, "invalid commit compensates the already applied preview")
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_false(f.transactions.has_preview())
	assert_eq(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).code, &"stale_settings_volume_preview")
	_assert_music(f, 0.8)


class LegacyProfile extends Node:
	func get_preference(_path: StringName, default_value: Variant = null) -> Variant:
		return default_value

func test_legacy_profile_can_initialize_audio_but_cannot_admit_settings_transactions() -> void:
	var profile := LegacyProfile.new()
	add_child_autofree(profile)
	var port := HookPort.new()
	var owner := MANAGER.new(port)
	add_child_autofree(owner)
	assert_true(owner.initialize(profile).ok)
	var count: int = port.operations.size()
	assert_eq(owner.preview_settings_volume("settings", MUSIC, 0.2).code, &"settings_audio_unavailable")
	assert_eq(owner.commit_settings_audio_preference("settings", MUSIC, 0.2).code, &"settings_audio_unavailable")
	assert_eq(owner.commit_settings_profile_reset("settings", &"reset_preferences").code, &"settings_audio_unavailable")
	assert_eq(port.operations.size(), count)
	assert_false(owner._settings_transactions.is_busy())

func test_freed_profile_refuses_transactions_without_touching_output() -> void:
	var profile := LegacyProfile.new()
	var port := HookPort.new()
	var owner := MANAGER.new(port)
	add_child_autofree(owner)
	assert_true(owner.initialize(profile).ok)
	profile.free()
	var count: int = port.operations.size()
	assert_eq(owner.commit_settings_audio_preference("settings", MUSIC, 0.2).code, &"settings_audio_unavailable")
	assert_eq(port.operations.size(), count)


func test_focus_loss_during_preview_or_commit_retires_handles_without_persistence() -> void:
	for commit: bool in [false, true]:
		var f := _fixture()
		var snapshot: Dictionary = f.profile.get_profile_snapshot()
		var revision: int = f.profile.get_profile_revision()
		var settings: Dictionary = f.owner._settings.duplicate(true)
		var preview: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.4)
		assert_true(preview.ok)
		if not preview.ok: continue
		f.port.on_next_bus = func(): f.owner.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		var method := &"commit_settings_audio_preference" if commit else &"preview_settings_volume"
		var result: Dictionary = f.owner.call(method, "settings", MUSIC, 0.2, preview.value.preview_handle)
		assert_false(result.ok)
		assert_eq(f.profile.get_profile_snapshot(), snapshot)
		assert_eq(f.profile.get_profile_revision(), revision)
		assert_eq(f.owner._settings, settings)
		assert_false(f.transactions.has_preview())
		assert_eq(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).code, &"stale_settings_volume_preview")
		for bus: StringName in [&"Master", &"Music", &"Ambience", &"SFX", &"UI"]:
			assert_true(f.port.bus_states[bus].muted, String(bus))
		_assert_music(f, 0.8)
		assert_false(f.owner._fatal)
		f.owner.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		_assert_music(f, 0.8)
		assert_false(f.port.bus_states[&"Master"].muted)
		assert_false(f.port.bus_states[&"Music"].muted)
		assert_eq(f.profile.get_profile_snapshot(), snapshot)

func test_focus_loss_during_cancel_settlement_retries_with_current_focus_state() -> void:
	var f := _fixture()
	var preview: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.2)
	assert_true(preview.ok)
	if not preview.ok: return
	var revision: int = f.profile.get_profile_revision()
	f.port.on_next_bus = func(): f.owner.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).ok)
	assert_true(f.port.bus_states[&"Master"].muted)
	assert_true(f.port.bus_states[&"Music"].muted)
	_assert_music(f, 0.8)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_false(f.transactions.has_preview())
	f.owner.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(f.port.bus_states[&"Master"].muted)
	_assert_music(f, 0.8)

func test_pause_entry_and_resume_each_retire_live_preview_and_keep_committed_audio() -> void:
	var f := _fixture()
	assert_true(f.owner.set_music_context("menu").ok)
	var semantic: Dictionary = f.owner.get_semantic_audio_context()
	var settings: Dictionary = f.owner._settings.duplicate(true)
	var snapshot: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	var handle := {"generation": 1, "handle_id": "pause.audio.settings.1",
		"holder": &"canonical-pause", "reason": &"universal_pause"}
	var preview: Dictionary = f.owner.preview_settings_volume("settings", MUSIC, 0.2)
	assert_true(preview.ok)
	if not preview.ok: return
	assert_true(f.owner.begin_suspend(handle).ok)
	assert_eq(f.owner.get_state().value.state, &"Suspended")
	assert_false(f.transactions.has_preview())
	assert_eq(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).code, &"stale_settings_volume_preview")
	_assert_music(f, 0.8)
	var paused_preview: Dictionary = f.owner.preview_settings_volume("pause-settings", MUSIC, 0.3)
	assert_true(paused_preview.ok, "output-only preview is admitted while playback is suspended")
	if not paused_preview.ok: return
	_assert_music(f, 0.3)
	assert_true(f.owner.resume(handle).ok)
	assert_eq(f.owner.get_state().value.state, &"Active")
	assert_false(f.transactions.has_preview())
	assert_eq(f.owner.cancel_settings_volume_preview(paused_preview.value.preview_handle).code, &"stale_settings_volume_preview")
	_assert_music(f, 0.8)
	assert_eq(f.owner._settings, settings)
	assert_eq(f.owner.get_semantic_audio_context(), semantic)
	assert_eq(f.profile.get_profile_snapshot(), snapshot)
	assert_eq(f.profile.get_profile_revision(), revision)

func test_failed_focus_output_apply_latches_shared_fatal_without_profile_write() -> void:
	var f := _fixture()
	var snapshot: Dictionary = f.profile.get_profile_snapshot()
	f.port.fail_after(f.port.operations.size() + 2)
	f.owner.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(f.owner._fatal)
	assert_true(f.gate.is_fatal_latched())
	assert_eq(f.profile.get_profile_snapshot(), snapshot)
	assert_false(f.transactions.has_preview())

func test_pause_handle_refusals_and_idempotent_begin_preserve_owned_live_preview() -> void:
	var f := _fixture()
	var handle := {"generation": 1, "handle_id": "pause.audio.settings.owned",
		"holder": &"canonical-pause", "reason": &"universal_pause"}
	var other := {"generation": 2, "handle_id": "pause.audio.settings.other",
		"holder": &"canonical-pause", "reason": &"universal_pause"}
	var begun: Dictionary = f.owner.begin_suspend(handle)
	assert_true(begun.ok)
	if not begun.ok: return
	var preview: Dictionary = f.owner.preview_settings_volume("pause-settings", MUSIC, 0.2)
	assert_true(preview.ok)
	if not preview.ok: return
	var operations: int = f.port.operations.size()
	var settings: Dictionary = f.owner._settings.duplicate(true)
	var profile: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	assert_eq(f.owner.begin_suspend(other).code, &"audio_suspended")
	assert_eq(f.owner.begin_suspend(handle), begun, "same handle joins without consuming Settings preview")
	assert_eq(f.owner.resume(other).code, &"invalid_suspension_handle")
	assert_eq(f.port.operations.size(), operations)
	assert_true(f.transactions.has_preview())
	_assert_music(f, 0.2)
	assert_eq(f.owner._settings, settings)
	assert_eq(f.profile.get_profile_snapshot(), profile)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(f.owner.get_state().value.state, &"Suspended")
	var updated: Dictionary = f.owner.preview_settings_volume("pause-settings", MUSIC, 0.3, preview.value.preview_handle)
	assert_true(updated.ok, "original preview handle remains usable after unrelated lifecycle requests")
	if not updated.ok: return
	assert_eq(updated.value.preview_handle, preview.value.preview_handle)
	_assert_music(f, 0.3)
	assert_true(f.owner.cancel_settings_volume_preview(preview.value.preview_handle).ok)
	assert_true(f.owner.resume(handle).ok)
	_assert_music(f, 0.8)
