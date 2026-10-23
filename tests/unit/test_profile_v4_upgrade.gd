extends "res://addons/gut/test.gd"

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const ROOT := "profile-v4-upgrade/root"


class ValidatorProbeStorage extends RefCounted:
	var text: String

	func _init(value: String) -> void:
		text = value

	func reconcile(_relative_path: String, validator: Callable) -> Dictionary:
		var checked: Dictionary = validator.call(text)
		return {"ok": false, "code": &"probe_accepted" if checked.get("ok", false) else &"probe_rejected"}


func _v1() -> Dictionary:
	return {
		"schema_version": 1,
		"gallery_unlocks": [], "gallery_transaction_receipts": {}, "visited_line_ids": [],
		"preferences": {
			"language": "en",
			"audio": {"music_volume": 0.8, "music_muted": false, "ambience_volume": 0.65,
				"ambience_muted": false, "sfx_volume": 0.8, "sfx_muted": false,
				"voice_volume": 0.8, "voice_muted": false, "mute_audio_on_focus_loss": false},
			"dialogue": {"text_speed": 1.0, "auto_text_speed": 1.0,
				"skip_mode": "read_only", "auto_advance_dialogue": false},
			"display": {"fullscreen": false},
			"accessibility": {"font_scale": 1.0, "high_contrast": false,
				"reduced_motion": false, "screen_shake_strength": 0.5,
				"large_click_targets": false, "hold_to_confirm": false,
				"colorblind_mode": "none", "show_focus_ring": true,
				"controller_cursor_enabled": false, "subtitles_enabled": true,
				"captions_enabled": true, "subtitle_speaker_names": true,
				"subtitle_background_opacity": 0.85, "text_box_opacity": 0.9,
				"visual_audio_cues": true, "flashing_effects_enabled": false,
				"pause_on_focus_loss": true},
		},
		"input_mappings": {},
		"migration_receipts": {"legacy_game_state_profile_v1": false,
			"legacy_input_bindings_v1": false, "invalid_persisted_skip_mode_v1": false},
	}.duplicate(true)


func test_v1_upgrade_maps_canonical_peers_and_archives_every_original_preference() -> void:
	var source := _v1()
	source.gallery_unlocks = ["ending.alone"]
	source.gallery_transaction_receipts = {"ending-tx": {"ending_id": "ending.alone", "unlocked": true}}
	source.visited_line_ids = ["story.retained"]
	source.preferences.language = "zh-hk"
	source.preferences.audio.music_volume = 0.35
	source.preferences.audio.mute_audio_on_focus_loss = true
	source.preferences.dialogue.text_speed = 2.0
	source.preferences.dialogue.auto_text_speed = 2.0
	source.preferences.dialogue.auto_advance_dialogue = true
	source.preferences.display.fullscreen = true
	source.preferences.accessibility.font_scale = 1.3
	source.preferences.accessibility.screen_shake_strength = 0.75
	source.preferences.accessibility.colorblind_mode = "deuteranopia"
	source.preferences.accessibility.visual_audio_cues = false
	source.migration_receipts.legacy_game_state_profile_v1 = true
	var before := source.duplicate(true)
	var result := MIGRATION.prepare_document(source)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	var upgraded: Dictionary = result.value
	assert_eq(upgraded.schema_version, SCHEMA.SCHEMA_VERSION)
	var actual_keys: Array = upgraded.keys()
	var expected_keys: Array = SCHEMA.ROOT_KEYS.duplicate()
	actual_keys.sort()
	expected_keys.sort()
	assert_eq(actual_keys, expected_keys)
	for added_field: String in ["pair_form_witness_receipts", "dating_attempts", "observer_evidence", "pair_deck_draws", "reached_presentations", "witnessed_caption_variants"]:
		assert_eq(upgraded[added_field], {}, "legacy migration does not invent " + added_field)
	assert_eq(upgraded.legacy_preferences_v1, before.preferences)
	assert_eq(upgraded.preferences.language, {"primary_locale_id": "zh_HK",
		"secondary_locale_id": "zh_CN", "dual_enabled": false})
	assert_eq(upgraded.preferences.reading.reveal_speed, "fast")
	assert_eq(upgraded.preferences.reading.auto_delay, "short")
	assert_true(upgraded.preferences.reading.auto_enabled)
	assert_eq(upgraded.preferences.audio.music_volume, 0.35)
	assert_true(upgraded.preferences.audio.mute_when_inactive)
	assert_eq(upgraded.preferences.display.window_mode, "borderless")
	assert_eq(upgraded.preferences.accessibility.text_size, 125)
	assert_eq(upgraded.preferences.accessibility.screen_shake, "normal")
	assert_eq(upgraded.preferences.accessibility.colour_differentiation, "deutan")
	assert_eq(upgraded.preferences.accessibility.sound_detail_text, "off")
	assert_eq(upgraded.gallery_unlocks, before.gallery_unlocks)
	assert_eq(upgraded.gallery_transaction_receipts, before.gallery_transaction_receipts)
	assert_eq(upgraded.visited_line_ids, before.visited_line_ids)
	assert_eq(upgraded.migration_receipts, before.migration_receipts)
	assert_eq(source, before, "migration never mutates its source")
	assert_true(SCHEMA.validate(upgraded).get("ok", false))


func test_unmappable_v1_values_use_defaults_only_at_runtime_and_remain_archived() -> void:
	var source := _v1()
	source.preferences.language = "fr_removed"
	source.preferences.audio.voice_volume = 0.17
	source.preferences.accessibility.hold_to_confirm = true
	var result := MIGRATION.prepare_document(source)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_eq(result.value.preferences.language.primary_locale_id, "en")
	assert_eq(result.value.legacy_preferences_v1.language, "fr_removed")
	assert_eq(result.value.legacy_preferences_v1.audio.voice_volume, 0.17)
	assert_true(result.value.legacy_preferences_v1.accessibility.hold_to_confirm)
	assert_eq(result.value.preferences.audio.get("voice_volume"), null,
		"retired values never masquerade as runtime preferences")


func test_invalid_v1_skip_is_the_only_repair_and_the_repaired_archive_is_valid() -> void:
	var source := _v1()
	source.preferences.dialogue.skip_mode = "invalid-old-value"
	var repaired := MIGRATION.prepare_document(source)
	assert_true(repaired.get("ok", false), str(repaired))
	if not repaired.get("ok", false): return
	assert_eq(repaired.value.preferences.reading.skip_mode, "read_only")
	assert_eq(repaired.value.legacy_preferences_v1.dialogue.skip_mode, "read_only")
	assert_true(repaired.value.migration_receipts.invalid_persisted_skip_mode_v1)
	var malformed := source.duplicate(true)
	malformed.preferences.accessibility.unknown_legacy_preference = true
	assert_false(MIGRATION.prepare_document(malformed).get("ok", true))


func test_v3_upgrade_closes_legacy_replay_without_inventing_archived_values() -> void:
	var source := SCHEMA.make_defaults()
	source.schema_version = 3
	source.erase("observer_evidence")
	source.erase("pair_deck_draws")
	source.erase("reached_presentations")
	source.erase("reached_presentation_chronology")
	source.erase("witnessed_caption_variants")
	source.erase("pair_form_witness_receipts")
	source.erase("dating_attempts")
	source.erase("migration_receipts")
	source.erase("legacy_preferences_v1")
	source.preferences.audio.music_volume = 0.41
	var before := source.duplicate(true)
	var result := MIGRATION.prepare_document(source)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_eq(result.value.preferences.audio.music_volume, 0.41)
	assert_eq(result.value.legacy_preferences_v1, {})
	assert_eq(result.value.migration_receipts, {"legacy_game_state_profile_v1": true,
		"legacy_input_bindings_v1": true, "invalid_persisted_skip_mode_v1": false})
	assert_eq(source, before)


func test_initialize_persists_v4_before_publish_and_resets_clear_only_archive() -> void:
	var source := _v1()
	source.preferences.language = "zh_hk"
	source.migration_receipts.invalid_persisted_skip_mode_v1 = true
	var ops := FILES.new({ROOT + "/profile.json": JSON.stringify(source).to_utf8_buffer()})
	var manager: Node = autofree(MANAGER.new())
	var restored: Array[Dictionary] = []
	manager.profile_restored.connect(func(profile: Dictionary) -> void: restored.append(profile))
	var initialized: Dictionary = manager.initialize(STORAGE.new(ROOT, ops))
	assert_true(initialized.get("ok", false), str(initialized))
	if not initialized.get("ok", false): return
	assert_eq(restored.size(), 1)
	assert_eq(restored[0].schema_version, SCHEMA.SCHEMA_VERSION)
	assert_eq(restored[0].legacy_preferences_v1.language, "zh_hk")
	var persisted: PackedByteArray = ops.snapshot_persisted()[ROOT + "/profile.json"]
	var parsed := STRICT_JSON.parse_object(persisted.get_string_from_utf8())
	assert_true(parsed.get("ok", false), str(parsed))
	assert_eq(parsed.value, restored[0])
	var receipts: Dictionary = restored[0].migration_receipts.duplicate(true)
	assert_true(manager.reset_preferences().get("ok", false))
	assert_eq(manager.get_profile_snapshot().legacy_preferences_v1, {})
	assert_eq(manager.get_profile_snapshot().migration_receipts, receipts)
	assert_true(manager.reset_entire_profile().get("ok", false))
	assert_eq(manager.get_profile_snapshot().legacy_preferences_v1, {})
	assert_eq(manager.get_profile_snapshot().migration_receipts, receipts)


func test_initialize_reconcile_uses_semantic_migration_validation_for_v1_through_v4() -> void:
	var malformed := SCHEMA.make_defaults()
	malformed["unknown_root"] = true
	var rejecting: Node = autofree(MANAGER.new())
	assert_eq(rejecting.initialize(ValidatorProbeStorage.new(JSON.stringify(malformed))).get("code"),
		&"probe_rejected", "syntax-valid malformed profile bytes are not admitted during recovery")
	var accepting: Node = autofree(MANAGER.new())
	assert_eq(accepting.initialize(ValidatorProbeStorage.new(JSON.stringify(_v1()))).get("code"),
		&"probe_accepted", "the recovery validator still admits a valid migratable v1 source")


func test_every_reset_refuses_cleanly_before_initialization() -> void:
	var manager: Node = autofree(MANAGER.new())
	for method: StringName in [&"reset_preferences", &"reset_controls", &"reset_visited_history",
			&"reset_gallery", &"reset_entire_profile"]:
		var result: Dictionary = manager.call(method)
		assert_false(result.get("ok", true), String(method))
		assert_eq(result.get("code"), &"not_initialized", String(method))


func test_deferred_raw_mapping_publication_survives_as_inert_compatibility_signal() -> void:
	var manager: Node = autofree(MANAGER.new())
	assert_true(manager.initialize(STORAGE.new(ROOT, FILES.new())).get("ok", false))
	var live_before: Dictionary = manager.get_input_mappings()
	var input_events: Array[StringName] = []
	var controls_events: Array[bool] = []
	manager.input_mappings_changed.connect(func(action: StringName) -> void: input_events.append(action))
	manager.controls_bindings_changed.connect(func() -> void: controls_events.append(true))
	var candidate: Dictionary = manager.get_profile_snapshot()
	candidate.input_mappings["game_open_log"] = [{"kind": "key", "physical_keycode": KEY_F6,
		"keycode": 0, "shift": false, "alt": false, "ctrl": false, "meta": false}]
	var committed: Dictionary = manager.commit_prepared_profile(candidate, true)
	assert_true(committed.get("ok", false), str(committed))
	assert_eq(input_events, [], "a deferred commit publishes nothing early")
	assert_eq(manager.get_input_mappings(), live_before,
		"retained raw provenance never becomes the active Controls map")
	assert_true(manager.publish_deferred_profile_signals(committed.value.publication_id).get("ok", false))
	assert_eq(input_events, [&"game_open_log"])
	assert_eq(controls_events, [], "unchanged canonical Controls do not publish a false change")


func test_historical_tutorial_boolean_survives_v1_current_backup_migration_and_restart() -> void:
	for available: bool in [true, false]:
		var source := _v1()
		source.preferences.accessibility.tutorial_replay_available = available
		source.preferences.language = "zh_CN"
		var original := source.duplicate(true)
		var backup := source.duplicate(true)
		backup.preferences.language = "en"
		var source_text := JSON.stringify(source)
		var ops := FILES.new({ROOT + "/profile.json": source_text.to_utf8_buffer(),
			ROOT + "/profile.json.bak": JSON.stringify(backup).to_utf8_buffer()})
		var manager: Node = autofree(MANAGER.new())
		var published: Array[Dictionary] = []
		manager.profile_restored.connect(func(profile: Dictionary) -> void: published.append(profile))
		var initialized: Dictionary = manager.initialize(STORAGE.new(ROOT, ops))
		assert_true(initialized.get("ok", false), str(initialized))
		if not initialized.get("ok", false): continue
		var current: Dictionary = manager.get_profile_snapshot()
		assert_eq(current.schema_version, SCHEMA.SCHEMA_VERSION)
		assert_eq(current.legacy_preferences_v1, original.preferences)
		assert_eq(current.legacy_preferences_v1.accessibility.tutorial_replay_available, available)
		assert_false(current.preferences.accessibility.has("tutorial_replay_available"), "retired capability is archive-only")
		assert_eq(current.preferences.language.primary_locale_id, "zh_CN", "valid current document wins over backup")
		assert_eq(source, original, "migration never changes caller-owned legacy facts")
		assert_eq(published, [current])
		assert_true(SCHEMA.validate(current).get("ok", false))
		var persisted: Dictionary = ops.snapshot_persisted()
		assert_eq(persisted[ROOT + "/profile.json.bak"], source_text.to_utf8_buffer(), "original v1 bytes remain the migration backup")
		var parsed := STRICT_JSON.parse_object(persisted[ROOT + "/profile.json"].get_string_from_utf8())
		assert_true(parsed.get("ok", false), str(parsed))
		assert_eq(parsed.value, current)
		assert_true(MIGRATION.prepare_document(parsed.value).get("ok", false), "current archive is still admitted")
		var restarted: Node = autofree(MANAGER.new())
		var restarted_ops := FILES.new(persisted)
		var restored: Dictionary = restarted.initialize(STORAGE.new(ROOT, restarted_ops))
		assert_true(restored.get("ok", false), str(restored))
		assert_eq(restarted.get_profile_snapshot(), current)
		assert_eq(restarted_ops.snapshot_persisted(), persisted, "current-schema restart does not rewrite the archive")


func test_optional_tutorial_compatibility_rejects_non_boolean_unknown_and_runtime_fields() -> void:
	for invalid: Variant in [null, 0, 1, "true", [], {}]:
		var source := _v1()
		source.preferences.accessibility.tutorial_replay_available = invalid
		var original := source.duplicate(true)
		assert_false(MIGRATION.prepare_document(source).get("ok", true), "legacy optional leaf must remain Boolean")
		assert_eq(source, original)
		var current := SCHEMA.make_defaults()
		current.legacy_preferences_v1 = source.preferences.duplicate(true)
		assert_false(SCHEMA.validate(current).get("ok", true), "archived optional leaf has the same strict type")
	var unknown := _v1()
	unknown.preferences.accessibility.tutorial_replay_available = true
	unknown.preferences.accessibility.unknown_legacy_preference = false
	assert_false(MIGRATION.prepare_document(unknown).get("ok", true), "the known retired field does not authorize unknown siblings")
	var archived := SCHEMA.make_defaults()
	archived.legacy_preferences_v1 = unknown.preferences.duplicate(true)
	assert_false(SCHEMA.validate(archived).get("ok", true))
	var runtime := SCHEMA.make_defaults()
	runtime.preferences.accessibility.tutorial_replay_available = true
	assert_false(SCHEMA.validate(runtime).get("ok", true), "runtime preference schema remains unchanged")
