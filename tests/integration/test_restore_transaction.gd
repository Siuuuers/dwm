extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
# Restore transaction orchestration over fake participants
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const FAKE_PARTICIPANT := "res://tests/support/FakeRestoreParticipant.gd"
const CALL_LOG := "res://tests/support/RestoreCallLog.gd"
const AUDIO_MANAGER := preload("res://autoload/AudioManager.gd")
const AUDIO_PARTICIPANT := preload("res://scripts/application/restore/AudioRestoreParticipant.gd")
const AUDIO_PLAYBACK := preload("res://tests/support/FakeAudioPlaybackPort.gd")


class AudioProfile extends Node:
	func get_preference(path: StringName, default_value: Variant = null) -> Variant:
		return AUDIO_MANAGER.AUDIO_DEFAULTS.get(String(path).trim_prefix("preferences.audio."), default_value)

## Plan 02 Task 6 (dwm-p2r.32), Phase C2: widened from 6 to the full 8-item
## DesktopContinuationOperationJournal.PARTICIPANT_ORDER (forced ripple -- SaveManager's
## configure_restore_participants() now requires exactly these 8 keys). This suite proves pure
## fake-participant orchestration mechanics (apply/rollback order, gate/lock release), so
## "desktop_consequence"/"desktop_board" use the SAME generic FakeRestoreParticipant as every other
## key here; a hand-built `_prepared()` with no `source_locator` never drives real identity
## allocation (see SaveManager.commit_prepared_restore()'s own doc comment), so no real
## DesktopConsequenceState/DesktopBoardState wiring is needed for this file's purpose.
const KEYS := ["run", "desktop_consequence", "desktop_board", "schedule_view", "profile", "localization", "audio", "route", "narrative"]

func _manager(log: RefCounted) -> Dictionary:
	var created: Dictionary = TEMPORARY_STORAGE.create("restore-transaction")
	assert_true(created.get("ok", false), created.get("message", ""))
	if not created.get("ok", false):
		return {}
	var root := str(created["value"]).path_join("saves")
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	var gate: RefCounted = load(GATE_PATH).new()
	manager.configure_mutation_gate(gate)
	var participants := {}
	for key: String in KEYS:
		participants[key] = load(FAKE_PARTICIPANT).new(key, log)
	assert_true(manager.configure_restore_participants(participants)["ok"])
	return {"manager": manager, "gate": gate, "participants": participants}

func _prepared() -> Dictionary:
	var plans := {}
	for key: String in KEYS:
		plans[key] = {}
	return {"participant_plans": plans, "checkpoint_id": "run-r:5", "route_id": "main"}

func test_configure_restore_participants_validates_nine_keys() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	if wired.is_empty():
		return
	var manager: Node = wired["manager"]
	assert_eq(manager.configure_restore_participants({"run": load(FAKE_PARTICIPANT).new("run", log)}).get("code"),
		&"invalid_restore_participants", "fewer than nine rejects")
	assert_eq(manager.commit_prepared_restore({}).get("code"), &"invalid_prepared_restore",
		"a prepared with no participant_plans rejects")

func test_restore_success_applies_and_finalizes_in_order() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	if wired.is_empty():
		return
	var manager: Node = wired["manager"]
	var emissions: Array = []
	manager.run_restored.connect(func(cp: String, route: String) -> void: emissions.append([cp, route]))
	var result: Dictionary = manager.commit_prepared_restore(_prepared())
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["checkpoint_id"], "run-r:5")
	var applies: Array[String] = []
	var finals: Array[String] = []
	for entry: String in log.entries:
		if entry.ends_with(".apply_silent"): applies.append(entry.trim_suffix(".apply_silent"))
		if entry.ends_with(".finalize"): finals.append(entry.trim_suffix(".finalize"))
	assert_eq(applies, KEYS, "apply runs run->desktop_consequence->desktop_board->profile->localization->audio->route->narrative")
	assert_eq(finals, ["run", "desktop_consequence", "desktop_board", "schedule_view", "profile", "localization", "audio", "narrative", "route"],
		"Only dispatch the irreversible scene change after every other participant finalizes")
	assert_eq(emissions.size(), 1, "exactly one run_restored")
	assert_false(manager.is_save_locked(), "restore lock released on success")
	assert_false(wired["gate"].is_active(), "mutation gate released on success")

func test_apply_failure_rolls_back_in_reverse_and_emits_nothing() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	if wired.is_empty():
		return
	var manager: Node = wired["manager"]
	wired["participants"]["audio"].set_failure(&"apply_silent")  # 6th in order
	var emissions: Array = []
	manager.run_restored.connect(func(_c: String, _r: String) -> void: emissions.append(true))
	var result: Dictionary = manager.commit_prepared_restore(_prepared())
	assert_false(result.get("ok", true), "audio apply failure fails the transaction")
	var rollbacks: Array[String] = []
	for entry: String in log.entries:
		if entry.ends_with(".rollback_silent"): rollbacks.append(entry.trim_suffix(".rollback_silent"))
	assert_eq(rollbacks, ["localization", "profile", "schedule_view", "desktop_board", "desktop_consequence", "run"],
		"rollback runs in exact reverse order")
	assert_eq(emissions.size(), 0, "no run_restored on failure")
	assert_false(manager.is_save_locked(), "locks released after clean rollback")
	assert_false(wired["gate"].is_active())
	assert_false(wired["gate"].is_fatal_latched(), "a clean rollback never latches")

func test_rollback_failure_latches_shared_gate() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	if wired.is_empty():
		return
	var manager: Node = wired["manager"]
	wired["participants"]["audio"].set_failure(&"apply_silent")
	wired["participants"]["profile"].set_failure(&"rollback_silent")
	var result: Dictionary = manager.commit_prepared_restore(_prepared())
	assert_false(result.get("ok", true))
	assert_eq(result["code"], &"APPLICATION_FATAL", JSON.stringify(result))
	assert_true(wired["gate"].is_fatal_latched(), "a failed rollback irreversibly latches the shared gate")
	assert_eq(result["details"]["failure"]["source"], "restore")


func _attach_real_audio(wired: Dictionary) -> Dictionary:
	var playback := AUDIO_PLAYBACK.new()
	var profile := AudioProfile.new()
	var audio: Node = AUDIO_MANAGER.new(playback)
	autofree(profile)
	autofree(audio)
	assert_true(audio.configure_mutation_gate(wired.gate).get("ok", false))
	assert_true(audio.initialize(profile).get("ok", false))
	assert_true(audio.set_music_context("menu").get("ok", false))
	assert_true(audio.set_ambience_context("rain").get("ok", false))
	playback.players[&"MusicB"]["playback_position"] = 42.75
	playback.players[&"AmbienceB"]["playback_position"] = 13.125
	playback.players[&"AmbienceB"]["stream_paused"] = true
	wired.participants.audio = AUDIO_PARTICIPANT.new(audio)
	assert_true(wired.manager.configure_restore_participants(wired.participants).get("ok", false))
	var prepared := _prepared()
	prepared.participant_plans.audio = {"snapshot": {
		"music_context_id": "hospital", "music_context": {},
		"ambience_context_id": "room", "ambience_context": {},
	}, "audio": AUDIO_MANAGER.AUDIO_DEFAULTS.duplicate(true)}
	prepared.participant_plans.audio.audio.output_mode = "mono"
	return {"audio": audio, "playback": playback, "prepared": prepared}


func test_later_route_refusal_restores_real_audio_exactly() -> void:
	_assert_later_refusal_preserves_audio(&"apply_silent")


func test_later_route_finalization_refusal_preserves_audio_after_audio_finalize() -> void:
	_assert_later_refusal_preserves_audio(&"finalize")


func _assert_later_refusal_preserves_audio(stage: StringName) -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	if wired.is_empty(): return
	var real := _attach_real_audio(wired)
	var before: Dictionary = real.audio.capture_restore_state()["value"]
	watch_signals(real.audio)
	watch_signals(wired.manager)
	wired.participants.route.set_failure(stage)
	var result: Dictionary = wired.manager.commit_prepared_restore(real.prepared)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"forced_apply_failure" if stage == &"apply_silent" else &"forced_finalize_failure")
	assert_eq(real.audio.capture_restore_state()["value"], before,
		"Failed Load restores physical streams, playheads, crossfades, outputs and manager identities")
	assert_same(real.playback.players[&"MusicB"].stream, before.runtime.players[&"MusicB"].stream)
	assert_false(wired.manager.is_save_locked())
	assert_false(wired.gate.is_active())
	assert_false(wired.gate.is_fatal_latched())
	assert_signal_not_emitted(wired.manager, "run_restored")
	for signal_name: String in ["music_context_changed", "ambience_context_changed", "audio_settings_applied"]:
		assert_signal_not_emitted(real.audio, signal_name)
	assert_true(real.audio.set_music_context("menu").get("unchanged", false))
	assert_true(real.audio.set_music_context("contacts").get("ok", false))
	assert_eq(real.audio._active_players[&"music"], &"MusicA")
	assert_eq(real.playback.players[&"MusicB"].playback_position, 42.75)


func test_real_audio_capture_refusal_precedes_all_participant_mutation() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	if wired.is_empty(): return
	var real := _attach_real_audio(wired)
	var before: Dictionary = real.audio.capture_restore_state()["value"]
	real.playback.fail_next(&"capture_runtime")
	var result: Dictionary = wired.manager.commit_prepared_restore(real.prepared)
	assert_eq(result.get("code"), &"injected_audio_failure")
	assert_eq(real.audio.capture_restore_state()["value"], before)
	for entry: String in log.entries:
		assert_false(entry.ends_with(".apply_silent"), "No owner applies before every capture succeeds")
	assert_false(wired.manager.is_save_locked())
	assert_false(wired.gate.is_active())
	assert_false(wired.gate.is_fatal_latched())


func test_real_audio_failed_compensation_latches_shared_restore_gate() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	if wired.is_empty(): return
	var real := _attach_real_audio(wired)
	wired.participants.route.set_failure(&"apply_silent")
	real.playback.fail_next(&"restore_runtime")
	var result: Dictionary = wired.manager.commit_prepared_restore(real.prepared)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"APPLICATION_FATAL")
	assert_true(wired.gate.is_fatal_latched())
	assert_eq(real.audio.set_music_context("menu").get("code"), &"audio_runtime_indeterminate")


# ---- dwm-p2r.8 (Plan-05 Task 2 Step 2.4): newest-to-oldest content-incompatible fallback ----
# A typed recoverable narrative incompatibility must advance selection to an earlier whole bundle,
# while fail-closed corruption must stop instead of being relabelled as incompatibility.

const NARRATIVE_PARTICIPANT := "res://scripts/application/restore/NarrativeRestoreParticipant.gd"


class IncompatibleCatalog extends RefCounted:
	## Every lookup misses, so any nonempty playhead is reported as unavailable content.
	func get_record(timeline_id: String) -> Dictionary:
		return {"ok": false, "code": &"unknown_timeline_id", "message": timeline_id}
	func get_timeline_path(_timeline_id: String, _locale: String = "en") -> String:
		return ""


func test_narrative_content_incompatibility_is_typed_for_bundle_fallback() -> void:
	var participant: Object = load(NARRATIVE_PARTICIPANT).new(RefCounted.new(), IncompatibleCatalog.new())
	var result: Dictionary = participant.prepare({
		"narrative_checkpoint": {"timeline_id": "removed.timeline", "line_id": "removed.line"},
		"content_version": 1,
	})
	assert_false(result.get("ok", false), "removed content rejects")
	assert_eq(str(result.get("code")), "NARRATIVE_CONTENT_UNAVAILABLE", "typed recoverable code drives newest-to-oldest fallback")
	assert_eq(str((result.get("details", {}).get("cause", {}) as Dictionary).get("reason", "")), "content_unavailable", "carries the recoverable cause")


func test_empty_playhead_stays_compatible_across_bundles() -> void:
	var participant: Object = load(NARRATIVE_PARTICIPANT).new(RefCounted.new(), IncompatibleCatalog.new())
	var result: Dictionary = participant.prepare({"narrative_checkpoint": {}, "content_version": 1})
	assert_true(result.get("ok", false), "an empty playhead never blocks bundle selection")


func test_malformed_narrative_input_is_fail_closed_not_incompatible() -> void:
	var participant: Object = load(NARRATIVE_PARTICIPANT).new(RefCounted.new(), IncompatibleCatalog.new())
	var missing_version: Dictionary = participant.prepare({"narrative_checkpoint": {}})
	assert_eq(str(missing_version.get("code")), "invalid_narrative_input", "malformed input keeps the fail-closed code")
	var missing_checkpoint: Dictionary = participant.prepare({"content_version": 1})
	assert_eq(str(missing_checkpoint.get("code")), "invalid_narrative_input", "missing checkpoint keeps the fail-closed code")


func test_failed_restore_finalization_restores_prior_journal_and_releases_save_lock() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	if wired.is_empty():
		return
	var manager: Node = wired.manager
	var fixtures: Node = load("res://tests/unit/test_checkpoint_journal.gd").new()
	var old_first: Dictionary = fixtures._snapshot("old-run",1)
	var old_current: Dictionary = fixtures._snapshot("old-run",2)
	var incoming: Dictionary = fixtures._snapshot("loaded-run",5)
	fixtures.free()
	assert_true(manager._journal.reset("old-run").ok)
	for snapshot: Dictionary in [old_first,old_current]:
		var record: Dictionary = manager._journal.prepare_record(snapshot,&"safe_marker")
		assert_true(record.ok,JSON.stringify(record))
		if not record.ok: return
		assert_true(manager._journal.commit_prepared(record.value.candidate).ok)
	var before: Dictionary = manager._journal.capture_state().value.backup
	var bundle := {"checkpoint_kind":"safe_marker","snapshot":incoming}
	var seed: Dictionary = manager._journal.prepare_seed({"current_snapshot":bundle,"recovery_journal":[]},bundle)
	assert_true(seed.ok,JSON.stringify(seed))
	if not seed.ok: return
	var prepared := _prepared()
	prepared.journal_seed = seed.value.candidate
	prepared.checkpoint_id = incoming.checkpoint_id
	wired.participants.narrative.set_failure(&"finalize")
	var restored: Array = []
	manager.run_restored.connect(func(_checkpoint: String,_route: String): restored.append(true))
	var result: Dictionary = manager.commit_prepared_restore(prepared)
	assert_false(result.ok)
	assert_eq(result.code,&"forced_finalize_failure")
	assert_eq(manager._journal.capture_state().value.backup,before,"Failed restore preserves the full prior checkpoint history")
	for participant in wired.participants.values(): assert_false(participant.was_applied())
	assert_false(manager.is_save_locked())
	assert_false(wired.gate.is_active())
	assert_false(wired.gate.is_fatal_latched())
	assert_true(restored.is_empty(),"No successful restore is published")
	assert_false(log.entries.has("route.finalize"),"Narrative failure cannot dispatch the scene")
