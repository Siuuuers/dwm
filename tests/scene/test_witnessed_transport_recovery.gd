extends GutTest

const SCENE_PATH := "res://scenes/ui/witnessed/WitnessedTransportRecovery.tscn"
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const COPY := {
	"en": ["The reading setting could not be changed. Retry, or cancel to keep the current setting.",
		"Unable to confirm the reading setting. Restart is required.", "Retry", "Cancel"],
	"zh-CN": ["无法更改阅读设置。请重试，或取消并保留当前设置。",
		"无法确认阅读设置。需要重新启动。", "重试", "取消"],
	"zh-HK": ["無法更改閱讀設定。請重試，或取消並保留目前設定。",
		"無法確認閱讀設定。需要重新啟動。", "重試", "取消"],
}

var _localization: Node


class Admission extends RefCounted:
	var allowed := true
	func is_admitted() -> bool:
		return allowed


class InputOwner extends Node:
	signal source_input_custody_changed
	signal input_bindings_changed
	func get_physical_contacts() -> Dictionary:
		return {}
	func observe_physical_contact(_event: InputEvent) -> void:
		pass
	func get_physical_contact_id(_event: InputEvent) -> String:
		return ""
	func is_source_input_admitted() -> bool:
		return true


func before_each() -> void:
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(STORAGE.new("witnessed-recovery-localization", FILES.new())).get("ok", false))
	_localization = autofree(LOCALIZATION.new())
	assert_true(_localization.initialize(profile).get("ok", false))


func _surface(locale: String = "en") -> Variant:
	var packed: PackedScene = load(SCENE_PATH)
	assert_not_null(packed, "the dedicated Witnessed recovery scene must exist")
	if packed == null:
		return null
	assert_true(_localization.set_locale(locale.replace("-", "_")).get("ok", false))
	var surface: Control = packed.instantiate()
	add_child_autofree(surface)
	return surface


func _bind(surface: Variant, admission: Admission = null) -> Dictionary:
	var resolved_admission := admission if admission != null else Admission.new()
	var input_owner := InputOwner.new()
	add_child_autofree(input_owner)
	assert_true(surface.bind_owners(_localization, input_owner, resolved_admission.is_admitted))
	return {"admission": resolved_admission, "input": input_owner}


func test_determinate_failure_is_a_modal_retry_cancel_surface_above_the_frozen_composition() -> void:
	var surface: Variant = _surface()
	if surface == null: return
	_bind(surface)
	assert_true(surface.configure_presentation("en", 100, "AfterHours", false, "standard", false))
	assert_true(surface.present(true, true))
	await get_tree().process_frame
	var body := surface.get_node("%RecoveryBody") as Label
	var retry := surface.get_node("%RetryButton") as Button
	var cancel := surface.get_node("%CancelButton") as Button
	assert_true(surface.visible)
	assert_eq(surface.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(body.text, COPY.en[0])
	assert_eq(retry.text, COPY.en[2])
	assert_eq(cancel.text, COPY.en[3])
	assert_false(retry.disabled)
	assert_false(cancel.disabled)
	assert_true(retry.has_focus(), "fresh recovery focuses its safe idempotent Retry")
	assert_eq(retry.accessibility_description, body.text)
	assert_eq(cancel.accessibility_description, body.text)


func test_buttons_emit_only_guarded_fresh_actions_and_dismiss_retires_old_native_callbacks() -> void:
	var surface: Variant = _surface()
	if surface == null: return
	var admission := Admission.new()
	_bind(surface, admission)
	assert_true(surface.configure_presentation("en", 100, "AfterHours", false, "standard", false))
	assert_true(surface.present(true, true))
	await get_tree().process_frame
	var retry := surface.get_node("%RetryButton") as Button
	var cancel := surface.get_node("%CancelButton") as Button
	watch_signals(surface)
	retry.pressed.emit()
	cancel.pressed.emit()
	assert_signal_not_emitted(surface, "retry_requested", "Button.pressed is never command admission")
	assert_signal_not_emitted(surface, "cancel_requested", "Button.pressed is never command admission")
	var retry_generation: int = int(retry.get("_generation"))
	retry.call("_on_accessibility_click", null, retry_generation)
	assert_signal_emit_count(surface, "retry_requested", 1)
	admission.allowed = false
	cancel.call("_on_accessibility_click", null, int(cancel.get("_generation")))
	assert_signal_not_emitted(surface, "cancel_requested", "the owner is rechecked at activation")
	admission.allowed = true
	surface.dismiss()
	assert_false(surface.visible)
	assert_true(retry.disabled)
	retry.call("_on_accessibility_click", null, retry_generation)
	assert_signal_emit_count(surface, "retry_requested", 1,
		"a native action queued before dismissal cannot cross its generation")


func test_uncertain_failure_has_truthful_inert_copy_and_no_false_retry_or_cancel() -> void:
	var surface: Variant = _surface()
	if surface == null: return
	_bind(surface)
	assert_true(surface.configure_presentation("en", 125, "Midnight", true, "deutan", true))
	assert_true(surface.present(false, false))
	var body := surface.get_node("%RecoveryBody") as Label
	var retry := surface.get_node("%RetryButton") as Button
	var cancel := surface.get_node("%CancelButton") as Button
	assert_eq(body.text, COPY.en[1])
	assert_true(retry.disabled)
	assert_true(cancel.disabled)
	assert_eq(retry.focus_mode, Control.FOCUS_NONE)
	assert_eq(cancel.focus_mode, Control.FOCUS_NONE)
	assert_false(retry.visible)
	assert_false(cancel.visible)
	assert_false(retry.has_focus())
	assert_false(cancel.has_focus())


func test_three_locales_and_accessibility_sizes_publish_one_atomic_complete_tuple() -> void:
	for locale: String in COPY:
		for percent: int in [100, 125, 150]:
			var context := "%s/%d%%" % [locale, percent]
			var surface: Variant = _surface(locale)
			if surface == null: return
			_bind(surface)
			assert_true(surface.configure_presentation(
				locale, percent, "AfterHours", false, "standard", true), context)
			assert_true(surface.present(true, true), context)
			var body := surface.get_node("%RecoveryBody") as Label
			var retry := surface.get_node("%RetryButton") as Button
			var cancel := surface.get_node("%CancelButton") as Button
			assert_eq(body.text, COPY[locale][0], context)
			assert_eq(retry.text, COPY[locale][2], context)
			assert_eq(cancel.text, COPY[locale][3], context)
			assert_false(body.text.contains("write_failed"), context)
			assert_gte(retry.custom_minimum_size.y, maxf(48.0 * percent / 100.0, 64.0), context)
			assert_gte(cancel.custom_minimum_size.y, maxf(48.0 * percent / 100.0, 64.0), context)
			assert_eq(retry.language, locale, context)
			assert_eq(cancel.language, locale, context)
			surface.free()


func test_locale_mismatch_and_invalid_capability_tuple_change_nothing() -> void:
	var surface: Variant = _surface()
	if surface == null: return
	_bind(surface)
	assert_true(surface.configure_presentation("en", 100, "AfterHours", false, "standard", false))
	assert_true(surface.present(true, true))
	var body := surface.get_node("%RecoveryBody") as Label
	var retry := surface.get_node("%RetryButton") as Button
	assert_false(surface.configure_presentation("zh-CN", 100, "AfterHours", false, "standard", false))
	assert_false(surface.present(false, true), "Cancel without a Retry operation is not a valid recovery")
	assert_eq(body.text, COPY.en[0])
	assert_eq(retry.text, COPY.en[2])
	assert_false(retry.disabled)
