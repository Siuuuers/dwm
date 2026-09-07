extends "res://addons/gut/test.gd"
## Real first-process Profile ownership over isolated in-memory storage.
const PROFILE := preload("res://autoload/ProfileManager.gd")
const PARTICIPANT := preload("res://scripts/application/restore/ProfileRestoreParticipant.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const WINDOW_FIXTURE := preload("res://tests/unit/test_profile_window_restore.gd")

func _fixture() -> Dictionary:
	var files := FILES.new()
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("restore-preserves-current-profile", files)).get("ok", false))
	assert_false(profile._profile_existed_at_initialize)
	var candidate: Dictionary = profile.get_profile_snapshot()
	candidate.preferences.language.primary_locale_id = "zh_HK"
	candidate.preferences.accessibility.text_size = 150
	candidate.preferences.accessibility.large_targets = true
	candidate.preferences.audio.music_volume = 0.35
	candidate.preferences.display.window_mode = "borderless"
	# Explicit capability fixture; no run is installed and no entitlement inferred.
	candidate.preferences.dark_mode.available = true
	candidate.preferences.dark_mode.next_run_enabled = true
	candidate.controls_bindings.game_quick_save.keyboard.physical_keycode = KEY_F6
	candidate.controls_bindings.game_quick_save.keyboard.keycode = 0
	candidate.visited_line_ids = ["fixture.public.line.1"]
	var validated: Dictionary = profile.prepare_profile_document(candidate)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false): return {}
	assert_true(profile.commit_prepared_profile(validated.value).get("ok", false))
	assert_true(profile.unlock_ending(SCHEMA.ENDING_IDS[0], "fixture-gallery-transaction").get("ok", false))
	assert_false(profile.get_profile_snapshot().migration_receipts.legacy_game_state_profile_v1)
	return {"profile": profile, "files": files, "participant": PARTICIPANT.new(profile)}

func test_empty_patch_preserves_first_process_current_document_without_import_or_publication() -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var profile: Node = fixture.profile
	var before: Dictionary = profile.get_profile_snapshot()
	var revision: int = profile.get_profile_revision()
	var disk: Dictionary = fixture.files._persisted.duplicate(true)
	var publications: Array = []
	profile.profile_restored.connect(func(value: Dictionary) -> void: publications.append(value))
	var prepared: Dictionary = fixture.participant.prepare({"legacy_profile_patch_input": {}})
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(prepared.value.locale_id, "zh_HK")
	assert_eq(prepared.value.profile_plan.profile, before)
	assert_true(prepared.value.profile_plan.profile.preferences.dark_mode.next_run_enabled)
	assert_eq(profile.get_profile_snapshot(), before)
	assert_eq(profile.get_profile_revision(), revision)
	assert_eq(fixture.files._persisted, disk)
	assert_eq(publications, [])
	prepared.value.profile_plan.profile.controls_bindings.clear()
	assert_eq(profile.get_profile_snapshot(), before, "The prepared document is detached")

func test_empty_patch_apply_and_finalize_preserve_all_current_fields_and_receipts() -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var profile: Node = fixture.profile
	var window := WINDOW_FIXTURE.FakeWindowOutput.new()
	add_child_autofree(window)
	assert_true(fixture.participant.configure_window_output(window).get("ok", false))
	var before: Dictionary = profile.get_profile_snapshot()
	var disk: Dictionary = fixture.files._persisted.duplicate(true)
	var publications: Array = []
	profile.profile_restored.connect(func(value: Dictionary) -> void: publications.append(value.duplicate(true)))
	var prepared: Dictionary = fixture.participant.prepare({"legacy_profile_patch_input": {}})
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(prepared.value.profile_plan.window_plan, {"window_mode": "borderless"})
	assert_true(fixture.participant.apply_silent(prepared.value.profile_plan).get("ok", false))
	assert_eq(profile.get_profile_snapshot(), before)
	assert_eq(publications, [], "Apply remains silent")
	assert_true(fixture.participant.finalize().get("ok", false))
	assert_eq(publications, [before])
	assert_eq(profile.get_profile_snapshot(), before, "Controls, gallery, history, preferences and migration receipts all survive")
	assert_eq(window.mode, "borderless")
	assert_eq(fixture.files._persisted, disk, "Participant preparation/apply/finalize does not persist a profile import")

func test_frozen_candidate_is_validated_detached_and_uses_the_same_locale_window_plan() -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var before: Dictionary = fixture.profile.get_profile_snapshot()
	var candidate := before.duplicate(true)
	candidate.preferences.dark_mode.next_run_enabled = false
	var window := WINDOW_FIXTURE.FakeWindowOutput.new()
	add_child_autofree(window)
	assert_true(fixture.participant.configure_window_output(window).get("ok", false))
	var prepared: Dictionary = fixture.participant.prepare_frozen_profile(candidate)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(prepared.value.profile_plan.profile, candidate)
	assert_eq(prepared.value.locale_id, "zh_HK")
	assert_eq(prepared.value.profile_plan.window_plan, {"window_mode": "borderless"})
	candidate.preferences.audio.music_volume = 0.9
	assert_eq(prepared.value.profile_plan.profile.preferences.audio.music_volume, 0.35)
	assert_eq(fixture.profile.get_profile_snapshot(), before)
	var calls := window.calls.duplicate()
	candidate["unknown_root"] = true
	var refused: Dictionary = fixture.participant.prepare_frozen_profile(candidate)
	assert_false(refused.get("ok", true))
	assert_false(refused.has("value"))
	assert_eq(window.calls, calls, "Invalid Profile is rejected before window preparation")
	assert_eq(fixture.profile.get_profile_snapshot(), before)

func test_explicit_nonempty_legacy_patch_still_uses_real_import_preparation() -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var before: Dictionary = fixture.profile.get_profile_snapshot()
	var legacy := {"settings": {"fullscreen": false}}
	var expected: Dictionary = fixture.profile.prepare_legacy_profile_patch(legacy, {})
	assert_true(expected.get("ok", false), str(expected))
	var prepared: Dictionary = fixture.participant.prepare({"legacy_profile_patch_input": {
		"legacy_run_state": legacy, "legacy_input_mappings": {},
	}})
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false) or not expected.get("ok", false): return
	assert_eq(prepared.value.profile_plan.profile, expected.value)
	assert_true(prepared.value.profile_plan.profile.migration_receipts.legacy_game_state_profile_v1)
	assert_eq(fixture.profile.get_profile_snapshot(), before)
