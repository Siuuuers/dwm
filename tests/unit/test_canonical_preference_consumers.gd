extends "res://addons/gut/test.gd"

const ADAPTER := preload("res://scripts/narrative/DialogicPreferenceAdapter.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const RESTORE := preload("res://scripts/application/restore/ProfileRestoreParticipant.gd")

class CanonicalProfile:
	extends Node
	signal preference_changed(path: StringName, value: Variant)
	var primary := "zh_HK"
	var commits := 0

	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return primary if path == &"preferences.language.primary_locale_id" else fallback

	func prepare_locale_preference(locale: String) -> Dictionary:
		return {"ok": true, "value": {"primary": locale}}

	func commit_prepared_profile(candidate: Dictionary, _defer_signals: bool) -> Dictionary:
		primary = candidate["primary"]
		commits += 1
		return {"ok": true, "value": {"publication_id": "fixture"}}

	func publish_deferred_profile_signals(_id: String) -> void:
		preference_changed.emit(&"preferences.language.primary_locale_id", primary)

class RestoreOwner:
	extends RefCounted
	var candidate: Dictionary = preload("res://scripts/profile/ProfileSchema.gd").make_defaults()
	func _init() -> void:
		candidate.preferences.language = {"primary_locale_id": "zh_CN", "secondary_locale_id": "en", "dual_enabled": true}
	var received: Array = []

	func get_profile_snapshot() -> Dictionary:
		return candidate.duplicate(true)
	func prepare_profile_document(document: Dictionary) -> Dictionary:
		return preload("res://scripts/profile/ProfileSchema.gd").validate(document)
	func prepare_legacy_profile_patch(run: Dictionary, mappings: Dictionary) -> Dictionary:
		received = [run.duplicate(true), mappings.duplicate(true)]
		return {"ok": true, "value": candidate.duplicate(true)}

class TextSink:
	extends Node
	var calls: Array = []
	func update_text_speed(a: float, b: bool, c: float, d: float) -> void:
		calls.append([a, b, c, d])

class SettingsSink:
	extends Node
	var settings: Dictionary = {}

class AutoSink:
	extends RefCounted
	var delay_modifier := 1.0
	var enabled_until_user_input := false

class InputsSink:
	extends Node
	var auto_advance := AutoSink.new()

func _reading(reveal: String = "normal", delay: String = "normal") -> Dictionary:
	return {"preferences": {"reading": {
		"reveal_speed": reveal, "auto_delay": delay,
		"auto_enabled": true, "skip_mode": "all_text",
	}}}

func test_reading_enums_map_exactly_without_mutating_profile() -> void:
	var adapter := ADAPTER.new()
	var reveal := {"instant": 0.0, "fast": 0.5, "normal": 1.0, "slow": 2.0}
	var delay := {"short": 0.5, "normal": 1.0, "long": 1.5}
	for speed in reveal:
		for duration in delay:
			var profile := _reading(speed, duration)
			var before := profile.duplicate(true)
			var result: Dictionary = adapter.prepare(profile)
			assert_true(result.get("ok", false))
			assert_eq(result.get("value"), {
				"text_delay_multiplier": reveal[speed], "auto_delay_multiplier": delay[duration],
				"auto_advance_enabled": true, "skip_mode": &"all_text",
			})
			assert_eq(profile, before)

func test_invalid_reading_has_no_partial_plan() -> void:
	var adapter := ADAPTER.new()
	for entry in [["reveal_speed", "unknown"], ["auto_delay", 1.0], ["auto_enabled", 1], ["skip_mode", "unread"]]:
		var profile := _reading()
		profile["preferences"]["reading"][entry[0]] = entry[1]
		var result: Dictionary = adapter.prepare(profile)
		assert_false(result.get("ok", true))
		assert_false(result.has("value"))
	assert_false(adapter.prepare({"preferences": {"dialogue": {"text_speed": 1.0}}}).get("ok", true))

func test_instant_and_skip_plan_survive_native_cache_capture_and_rollback() -> void:
	var runtime := Node.new()
	var settings := SettingsSink.new()
	settings.name = "Settings"
	var text_sink := TextSink.new()
	text_sink.name = "Text"
	var inputs := InputsSink.new()
	inputs.name = "Inputs"
	runtime.add_child(settings)
	runtime.add_child(text_sink)
	runtime.add_child(inputs)
	add_child_autofree(runtime)
	var adapter := ADAPTER.new()
	assert_true(adapter.bind(runtime).get("ok", false))
	var plan: Dictionary = adapter.prepare(_reading("instant", "long"))["value"]
	assert_true(adapter.apply_silent(plan).get("ok", false))
	assert_eq(text_sink.calls, [[-1.0, false, 1.0, 0.0]])
	assert_eq(inputs.auto_advance.delay_modifier, 1.5)
	assert_true(inputs.auto_advance.enabled_until_user_input)
	var backup: Dictionary = adapter.capture_state()["value"]
	assert_eq(backup["plan"], plan)
	assert_true(adapter.apply_silent(adapter.prepare(_reading())["value"]).get("ok", false))
	assert_true(adapter.rollback_silent(backup).get("ok", false))
	assert_eq(adapter.capture_state()["value"], backup)

func test_localization_reads_and_publishes_only_canonical_primary_locale() -> void:
	var profile := CanonicalProfile.new()
	add_child_autofree(profile)
	var localization: Node = LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(profile).get("ok", false))
	assert_eq(localization.get_locale(), "zh_HK")
	assert_eq(profile.commits, 0)
	profile.preference_changed.emit(&"preferences.language.secondary_locale_id", "en")
	assert_eq(localization.get_locale(), "zh_HK")
	assert_true(localization.set_locale("zh_CN").get("ok", false))
	assert_eq(localization.get_locale(), "zh_CN")
	assert_eq(profile.primary, "zh_CN")
	assert_eq(profile.commits, 1)

func test_restore_checks_committed_canonical_primary_before_applying() -> void:
	var profile := CanonicalProfile.new()
	add_child_autofree(profile)
	var localization: Node = LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(profile).get("ok", false))
	var prepared: Dictionary = localization.prepare_locale("en")
	assert_true(prepared.get("ok", false))
	assert_eq(localization.apply_restore_silent(prepared["value"]).get("code"), &"localization_restore_profile_mismatch")
	assert_eq(localization.get_locale(), "zh_HK")
	profile.primary = "en"
	assert_true(localization.apply_restore_silent(prepared["value"]).get("ok", false))
	assert_eq(localization.get_locale(), "en")

func test_restore_participant_preserves_legacy_input_and_extracts_canonical_primary() -> void:
	var owner := RestoreOwner.new()
	var participant := RESTORE.new(owner)
	var input := {"legacy_profile_patch_input": {
		"legacy_run_state": {"language": "zh-CN"}, "legacy_input_mappings": {"unused": []},
	}}
	var result: Dictionary = participant.prepare(input)
	assert_true(result.get("ok", false))
	assert_eq(result["value"]["locale_id"], "zh_CN")
	assert_eq(owner.received, [{"language": "zh-CN"}, {"unused": []}])
	assert_eq(result["value"]["profile_plan"]["profile"], owner.candidate)
	result["value"]["profile_plan"]["profile"]["preferences"]["language"]["primary_locale_id"] = "en"
	assert_eq(owner.candidate["preferences"]["language"]["primary_locale_id"], "zh_CN")
