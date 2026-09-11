extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const ROOT := "localization-tests/root"
const PROFILE_SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")

class FakePresentationRoot:
	extends Node
	var applied_profile: Dictionary = {"locale_id": "before"}
	var call_log: Array[StringName] = []
	var fail_prepare := false
	var fail_apply := false

	func prepare_presentation(profile: Dictionary) -> Dictionary:
		call_log.append(&"prepare")
		if fail_prepare: return {"ok": false, "code": &"root_prepare_failed"}
		return {"ok": true, "value": {"profile": profile.duplicate(true)}}
	func capture_presentation_state() -> Dictionary:
		call_log.append(&"capture")
		return {"ok": true, "value": {"profile": applied_profile.duplicate(true)}}
	func apply_presentation_silent(plan: Dictionary) -> Dictionary:
		call_log.append(&"apply")
		if fail_apply: return {"ok": false, "code": &"root_apply_failed"}
		applied_profile = (plan["profile"] as Dictionary).duplicate(true)
		return {"ok": true}
	func rollback_presentation_silent(backup: Dictionary) -> Dictionary:
		call_log.append(&"rollback")
		applied_profile = (backup["profile"] as Dictionary).duplicate(true)
		return {"ok": true}
	func finalize_presentation() -> Dictionary:
		call_log.append(&"finalize")
		return {"ok": true}

var _localization_script: Script
var _profile_script: Script
var _storage_script: Script
var _fake_ops_script: Script
var _fake_gate_script: Script
var _profile: Node
var _manager: Node
var _ops: RefCounted

func before_all() -> void:
	_localization_script = _require("res://autoload/LocalizationManager.gd")
	_profile_script = _require("res://autoload/ProfileManager.gd")
	_storage_script = _require("res://scripts/infrastructure/storage/JsonFileStorage.gd")
	_fake_ops_script = _require("res://tests/support/FakeFileOps.gd")
	_fake_gate_script = _require("res://tests/support/FakeApplicationMutationGate.gd")

func before_each() -> void:
	_ops = _fake_ops_script.new()
	_profile = autofree(_profile_script.new())
	var profile_result: Dictionary = _profile.initialize(_storage_script.new(ROOT, _ops))
	assert_true(profile_result.get("ok", false), str(profile_result))
	_manager = autofree(_localization_script.new())

func _require(path: String) -> Script:
	var result := PROBE.load_script(path)
	assert_true(result.get("ok", false), "%s: %s" % [path, result])
	return result.get("value")

func _initialize() -> Dictionary:
	return _manager.initialize(_profile)

func _legacy_v1_profile(locale_id: String) -> Dictionary:
	# Explicit persisted v1 fixture: aliases/removed locales are migration input,
	# never values smuggled through the canonical Profile preference validator.
	var preferences := {}
	for path in PROFILE_SCHEMA.LEGACY_PREFERENCE_DEFAULTS:
		var parts: PackedStringArray = String(path).split(".")
		if parts.size() == 2:
			preferences[parts[1]] = PROFILE_SCHEMA.LEGACY_PREFERENCE_DEFAULTS[path]
		else:
			if not preferences.has(parts[1]): preferences[parts[1]] = {}
			preferences[parts[1]][parts[2]] = PROFILE_SCHEMA.LEGACY_PREFERENCE_DEFAULTS[path]
	preferences["language"] = locale_id
	return {
		"schema_version": 1, "gallery_unlocks": [], "gallery_transaction_receipts": {},
		"visited_line_ids": [], "preferences": preferences, "input_mappings": {},
		"migration_receipts": {
			"legacy_game_state_profile_v1": false, "legacy_input_bindings_v1": false,
			"invalid_persisted_skip_mode_v1": false,
		},
	}

func test_initialization_loads_manifest_and_returns_detached_selectable_records() -> void:
	assert_eq(_manager.get_readiness(), &"uninitialized")
	var initialized: Dictionary = _initialize()
	assert_true(initialized.get("ok", false), str(initialized))
	assert_eq(_manager.get_readiness(), &"ready")
	assert_eq(_manager.get_locale(), "en")
	var locales: Array[Dictionary] = _manager.get_selectable_locales()
	assert_eq(locales.size(), 3)
	assert_eq(locales[1]["release_status"], "draft")
	locales[0]["native_name"] = "mutated"
	assert_eq(_manager.get_selectable_locales()[0]["native_name"], "English")

func test_alias_switch_commits_profile_before_signals_and_publishes_once() -> void:
	assert_true(_initialize().get("ok", false))
	var observations: Array = []
	_profile.preference_changed.connect(func(path: StringName, value: Variant) -> void: observations.append([&"profile", path, value, _manager.get_locale()]))
	_manager.locale_changed.connect(func(locale: String) -> void: observations.append([&"locale", locale, _profile.get_preference(&"preferences.language.primary_locale_id")]))
	var result: Dictionary = _manager.set_locale("zh_hk")
	assert_true(result.get("ok", false), str(result))
	assert_eq(_manager.get_locale(), "zh_HK")
	assert_eq(_profile.get_preference(&"preferences.language.primary_locale_id"), "zh_HK")
	assert_eq(observations, [[&"profile", &"preferences.language.primary_locale_id", "zh_HK", "zh_HK"], [&"locale", "zh_HK", "zh_HK"]])

func test_lookup_uses_registered_fallback_and_exact_placeholder_sets() -> void:
	assert_true(_initialize().get("ok", false))
	assert_true(_manager.set_locale("zh_CN").get("ok", false))
	assert_eq(_manager.t("app.minesweeper"), "扫雷")
	assert_eq(_manager.t("desktop.notification.new_message_from_friend", {"friend_name": "Priscilla"}), "Angela received a new message from Priscilla.")
	assert_eq(_manager.t("hud.minesweeper_rounds", {"remaining": 1}), "[format_error:hud.minesweeper_rounds]")
	assert_eq(_manager.t("hud.minesweeper_rounds", {"remaining": 1, "max": 2, "extra": 3}), "[format_error:hud.minesweeper_rounds]")
	assert_eq(_manager.t("missing.key"), "[missing:missing.key]")
	assert_eq(_manager.t("missing.key"), "[missing:missing.key]")
	assert_push_warning_count(2)

func test_prepare_locale_is_detached_and_unknown_locale_mutates_nothing() -> void:
	assert_true(_initialize().get("ok", false))
	var before_profile: Dictionary = _profile.get_profile_snapshot()
	var before_presentation: Dictionary = _manager.get_presentation_profile()
	assert_eq(_manager.prepare_locale("fr").get("code"), &"unknown_locale")
	assert_eq(_profile.get_profile_snapshot(), before_profile)
	var prepared: Dictionary = _manager.prepare_locale("zh_HK")
	assert_true(prepared.get("ok", false), str(prepared))
	prepared["value"]["presentation_profile"]["layout_direction"] = "rtl"
	assert_eq(_manager.get_presentation_profile(), before_presentation)

func test_pending_root_is_applied_during_initialization() -> void:
	var root: FakePresentationRoot = autofree(FakePresentationRoot.new())
	var registration: Dictionary = _manager.register_presentation_root(root)
	assert_eq(registration.get("code"), &"pending_registration")
	assert_true(_initialize().get("ok", false))
	assert_eq(root.applied_profile["locale_id"], "en")
	assert_eq(root.call_log, [&"prepare", &"capture", &"apply", &"finalize"])

func test_pending_root_can_unregister_and_pending_failure_fails_initialization() -> void:
	var removed: FakePresentationRoot = autofree(FakePresentationRoot.new())
	assert_true(_manager.register_presentation_root(removed).get("ok", false))
	assert_true(_manager.unregister_presentation_root(removed).get("ok", false))
	var failing: FakePresentationRoot = autofree(FakePresentationRoot.new())
	failing.fail_prepare = true
	assert_true(_manager.register_presentation_root(failing).get("ok", false))
	assert_eq(_initialize().get("code"), &"root_prepare_failed")
	assert_eq(_manager.get_readiness(), &"failed")
	assert_eq(removed.call_log, [])
	var later: FakePresentationRoot = autofree(FakePresentationRoot.new())
	assert_eq(_manager.register_presentation_root(later).get("code"), &"localization_failed")

func test_ready_registration_applies_current_presentation_without_stale_state() -> void:
	assert_true(_initialize().get("ok", false))
	var root: FakePresentationRoot = autofree(FakePresentationRoot.new())
	assert_true(_manager.register_presentation_root(root).get("ok", false))
	assert_eq(root.applied_profile["locale_id"], "en")
	var calls_after_first: Array[StringName] = root.call_log.duplicate()
	assert_eq(_manager.register_presentation_root(root).get("code"), &"already_registered")
	assert_eq(root.call_log, calls_after_first)

func test_root_apply_failure_rolls_back_prior_root_and_preserves_profile() -> void:
	assert_true(_initialize().get("ok", false))
	var first: FakePresentationRoot = autofree(FakePresentationRoot.new())
	var second: FakePresentationRoot = autofree(FakePresentationRoot.new())
	assert_true(_manager.register_presentation_root(first).get("ok", false))
	assert_true(_manager.register_presentation_root(second).get("ok", false))
	second.fail_apply = true
	var before: Dictionary = _profile.get_profile_snapshot()
	var result: Dictionary = _manager.set_locale("zh_CN")
	assert_eq(result.get("code"), &"root_apply_failed")
	assert_eq(first.applied_profile["locale_id"], "en")
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_manager.get_locale(), "en")

func test_profile_write_failure_rolls_back_all_roots_and_manager() -> void:
	assert_true(_initialize().get("ok", false))
	var root: FakePresentationRoot = autofree(FakePresentationRoot.new())
	assert_true(_manager.register_presentation_root(root).get("ok", false))
	var before_profile: Dictionary = _profile.get_profile_snapshot()
	_ops.fail_after(_ops.operation_count() + 1)
	var result: Dictionary = _manager.set_locale("zh_CN")
	assert_false(result.get("ok", true), str(result))
	assert_eq(root.applied_profile["locale_id"], "en")
	assert_eq(_manager.get_locale(), "en")
	assert_eq(_profile.get_profile_snapshot(), before_profile)

func test_initialization_canonicalizes_alias_and_removed_locale_to_durable_values() -> void:
	for case in [["zh_hk", "zh_HK"], ["fr_removed", "en"]]:
		var root_path := "localization-tests/legacy-" + str(case[0])
		var legacy := _legacy_v1_profile(case[0])
		assert_true(PROFILE_SCHEMA.validate_v1_source(legacy).get("ok", false))
		var legacy_ops: RefCounted = _fake_ops_script.new({root_path + "/profile.json": JSON.stringify(legacy)})
		var migrated_profile: Node = autofree(_profile_script.new())
		assert_true(migrated_profile.initialize(_storage_script.new(root_path, legacy_ops)).get("ok", false))
		var manager: Node = autofree(_localization_script.new())
		assert_true(manager.initialize(migrated_profile).get("ok", false))
		assert_eq(manager.get_locale(), case[1])
		assert_eq(migrated_profile.get_preference(&"preferences.language.primary_locale_id"), case[1])
		var snapshot: Dictionary = migrated_profile.get_profile_snapshot()
		assert_eq(snapshot["schema_version"], PROFILE_SCHEMA.SCHEMA_VERSION)
		assert_eq(snapshot["legacy_preferences_v1"]["language"], case[0])
		# The canonical result survives another real Profile load from the same storage.
		var restarted: Node = autofree(_profile_script.new())
		assert_true(restarted.initialize(_storage_script.new(root_path, legacy_ops)).get("ok", false))
		assert_eq(restarted.get_preference(&"preferences.language.primary_locale_id"), case[1])

func test_prepared_bundle_contains_only_candidate_fallback_chain() -> void:
	assert_true(_initialize().get("ok", false))
	var root: FakePresentationRoot = autofree(FakePresentationRoot.new())
	assert_true(_manager.register_presentation_root(root).get("ok", false))
	var prepared: Dictionary = _manager.prepare_locale("zh_hk")
	assert_true(prepared.get("ok", false), str(prepared))
	assert_eq(prepared["value"]["canonical_locale_id"], "zh_HK")
	var catalog_ids: Array = prepared["value"]["bundle"]["catalogs"].keys()
	catalog_ids.sort()
	assert_eq(catalog_ids, ["en", "zh_HK"])
	assert_eq(prepared["value"]["root_plans"].size(), 1)
	assert_false(prepared["value"]["root_plans"][0].has("root"))
	prepared["value"]["root_plans"][0]["plan"]["profile"]["locale_id"] = "mutated"
	assert_eq(_manager.prepare_locale("zh_hk")["value"]["root_plans"][0]["plan"]["profile"]["locale_id"], "zh_HK")

func test_external_committed_language_change_applies_validated_memory_without_second_write() -> void:
	assert_true(_initialize().get("ok", false))
	var observed: Array[String] = []
	_manager.locale_changed.connect(func(locale_id: String) -> void: observed.append(locale_id))
	var operations_before: int = _ops.operation_count()
	var prepared: Dictionary = _profile.prepare_locale_preference("zh_CN")
	assert_true(_profile.commit_prepared_profile(prepared["value"]).get("ok", false))
	assert_eq(_manager.get_locale(), "zh_CN")
	assert_eq(observed, ["zh_CN"])
	assert_gt(_ops.operation_count(), operations_before)

func test_configured_mutation_gate_identity_survives_initialization() -> void:
	var gate: Object = _fake_gate_script.new()
	var configured: Dictionary = _manager.configure_mutation_gate(gate)
	assert_true(configured.get("ok", false), str(configured))
	assert_eq(configured["value"]["gate_instance_id"], gate.get_instance_id())
	assert_true(_initialize().get("ok", false))
	var repeated: Dictionary = _manager.configure_mutation_gate(gate)
	assert_true(repeated["value"]["already_configured"])
	assert_eq(repeated["value"]["gate_instance_id"], gate.get_instance_id())

func test_restore_apply_and_rollback_are_silent_and_detached() -> void:
	assert_true(_initialize().get("ok", false))
	var root: FakePresentationRoot = autofree(FakePresentationRoot.new())
	assert_true(_manager.register_presentation_root(root).get("ok", false))
	var signals: Array[String] = []
	_manager.locale_changed.connect(func(locale_id: String) -> void: signals.append(locale_id))
	var plan: Dictionary = _manager.prepare_locale("zh_CN")["value"]
	var backup: Dictionary = _manager.capture_restore_state()
	var profile_backup: Dictionary = _profile.capture_restore_state()
	assert_true(_profile.apply_restore_silent({"profile": plan["profile_candidate"]}).get("ok", false))
	assert_true(_manager.apply_restore_silent(plan).get("ok", false))
	assert_eq(_manager.get_locale(), "zh_CN")
	assert_eq(root.applied_profile["locale_id"], "zh_CN")
	plan["bundle"].clear()
	assert_eq(_manager.t("app.minesweeper"), "扫雷")
	assert_true(_manager.rollback_restore_silent(backup).get("ok", false))
	assert_true(_profile.rollback_restore_silent(profile_backup["value"]).get("ok", false))
	assert_eq(_manager.get_locale(), "en")
	assert_eq(root.applied_profile["locale_id"], "en")
	assert_true(_manager.finalize_restore().get("ok", false))
	assert_eq(signals, [])

func test_both_chinese_catalogs_translate_all_real_title_buttons_without_english_fallback() -> void:
	assert_true(_initialize().get("ok", false))
	var expected := {
		"zh_CN": ["新建账号", "登录", "画廊", "设定", "关闭游戏"],
		"zh_HK": ["建立帳號", "登入", "圖鑑", "設定", "關閉遊戲"],
	}
	var keys := ["menu.new_account", "menu.login", "menu.gallery", "menu.setting", "menu.shutdown"]
	for locale: String in expected:
		assert_true(_manager.set_locale(locale).get("ok", false))
		for index: int in keys.size():
			assert_eq(_manager.t(keys[index]), expected[locale][index], locale + " " + keys[index])
