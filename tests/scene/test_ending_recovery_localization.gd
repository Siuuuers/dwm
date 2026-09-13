extends GutTest

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FAKE_OPS := preload("res://tests/support/FakeFileOps.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const ENDING := preload("res://scenes/ending/EndingScene.tscn")
const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const COPY := {
	"en": ["Retry", "Unable to continue. Please retry."],
	"zh_CN": ["重试", "暂时无法继续。请重试。"],
	"zh_HK": ["重試", "暫時無法繼續。請重試。"],
}

var _localization: Node
var _scene: Control

class RecordingEnding extends "res://scripts/ui/EndingScene.gd":
	var retry_requests := 0
	func _on_return_pressed() -> void:
		retry_requests += 1


class RetryState extends RefCounted:
	func request_next_ending_command() -> Dictionary:
		return {"ok": true, "value": {"kind": "play_ending", "ending_id": "ending.alone",
			"playback_context": {"playback_id": "retry-playback", "transaction_id": "retry-transaction",
				"expected_stage": &"PRIMARY_PENDING"}}}
	func complete_ending_playback_stage(_transaction: String, _stage: StringName, _receipt: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"fixture_unexpected_completion"}


class RetryPlayback extends RefCounted:
	signal playback_completed(completion: Dictionary)
	signal playback_failed(failure: Dictionary)
	var starts: Array[Dictionary] = []
	func is_ready() -> bool: return true
	func start_ending_id(ending_id: String, context: Dictionary) -> Dictionary:
		starts.append({"ending_id": ending_id, "context": context.duplicate(true)})
		return {"ok": starts.size() > 1, "code": &"ok" if starts.size() > 1 else &"fixture_temporary_start_failure"}


func before_all() -> void:
	var profile := get_node("/root/ProfileManager")
	if not bool(profile.get("_initialized")):
		assert_true(profile.initialize(STORAGE.new("ending-locale-tests", FAKE_OPS.new())).get("ok", false))
	var ids: Dictionary = MANIFEST.load_ids_default()
	assert_true(ids.get("ok", false))
	if not ids.get("ok", false): return
	assert_true(profile.configure_line_registry(ids.value).get("ok", false))
	_localization = get_node("/root/LocalizationManager")
	if _localization.get_readiness() == &"uninitialized":
		assert_true(_localization.initialize(profile).get("ok", false))


func after_each() -> void:
	if is_instance_valid(_scene): _scene.free()
	assert_true(_localization.set_locale("en").get("ok", false))
	assert_true(get_node("/root/ProfileManager").set_preferences({
		&"preferences.accessibility.text_size": 100,
		&"preferences.accessibility.high_contrast": false,
		&"preferences.accessibility.large_targets": false,
		&"preferences.accessibility.colour_differentiation": "standard",
	}).get("ok", false))


func _mount(record_requests: bool = false) -> void:
	_scene = ENDING.instantiate()
	if record_requests: _scene.set_script(RecordingEnding)
	add_child(_scene)
	for frame: int in 3: await get_tree().process_frame
	# Missing ports exercise the projection only, not the classification of retryable failures.
	assert_true(_scene.get("_retry_available"))


func test_retry_copy_follows_locale_without_changing_the_pending_command() -> void:
	await _mount()
	var button: Button = _scene.get_node("%ReturnToMenuButton")
	var body: Label = _scene.get_node("%EndingBodyLabel")
	# Presentation must preserve even a retained completion awaiting a persistence retry.
	_scene.set("_pending_ending_command", {"ending_id": "test-only", "playback_context": {"transaction_id": "retained"}})
	_scene.set("_pending_completion", {"timeline_completion_receipt_id": "retained-completion"})
	var state_before: Dictionary = _scene.get("_pending_ending_command").duplicate(true)
	var completion_before: Dictionary = _scene.get("_pending_completion").duplicate(true)
	for locale: String in COPY:
		assert_true(_localization.set_locale(locale).get("ok", false))
		for frame: int in 2: await get_tree().process_frame
		assert_eq(button.text, COPY[locale][0], locale)
		assert_eq(body.text, COPY[locale][1], locale)
		assert_true(body.visible)
		assert_false(button.disabled)
		assert_true(_scene.get("_retry_available"))
		assert_eq(_scene.get("_pending_ending_command"), state_before)
		assert_eq(_scene.get("_pending_completion"), completion_before)
		assert_false(_scene.get("_finished"))


func test_normal_playback_exposes_no_return_action_or_error() -> void:
	await _mount()
	var button: Button = _scene.get_node("%ReturnToMenuButton")
	var body: Label = _scene.get_node("%EndingBodyLabel")
	for locale: String in COPY:
		assert_true(_localization.set_locale(locale).get("ok", false))
		_scene.call("_set_playback_status", false)
		assert_false(button.visible, "the normal ending host adds no Return action")
		assert_true(button.disabled, "copy refresh grants no return/navigation capability")
		assert_eq(button.focus_mode, Control.FOCUS_NONE)
		assert_true(not body.visible or body.text.is_empty())
		_scene.call("_set_playback_status", true)
		assert_eq(button.text, COPY[locale][0], locale)
		assert_eq(body.text, COPY[locale][1], locale)
		assert_false(button.disabled)


func test_no_public_ending_title_is_added_by_the_recovery_host() -> void:
	await _mount()
	var title := _scene.get_node_or_null("EndingTitleLabel")
	assert_true(title == null or not title.is_visible_in_tree(),
		"the ending host must not add an Ending heading outside the witnessed stream")


func test_programmatic_pressed_cannot_submit_a_retry() -> void:
	await _mount(true)
	var button: Button = _scene.get_node("%ReturnToMenuButton")
	button.pressed.emit()
	for frame: int in 3: await get_tree().process_frame
	assert_eq(_scene.get("retry_requests"), 0)


func test_focused_keyboard_activation_submits_one_retry() -> void:
	await _mount(true)
	var button: Button = _scene.get_node("%ReturnToMenuButton")
	button.grab_focus()
	assert_true(button.has_focus())
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	for frame: int in 4: await get_tree().process_frame
	assert_eq(_scene.get("retry_requests"), 1)


func test_missing_localization_hides_the_whole_recovery_surface() -> void:
	await _mount()
	_scene.set("_localization", null)
	_scene.call("_refresh_recovery")
	assert_false(_scene.get_node("%RecoveryPanel").visible)
	assert_true(_scene.get_node("%ReturnToMenuButton").disabled)
	assert_eq(_scene.get_node("%ReturnToMenuButton").focus_mode, Control.FOCUS_NONE)
	assert_true(_scene.get("_retry_available"), "presentation failure does not discard recovery state")
	_scene.set("_localization", _localization)
	_scene.call("_refresh_recovery")
	assert_true(_scene.get_node("%RecoveryPanel").visible)


func test_locale_change_retires_a_held_retry_contact() -> void:
	await _mount(true)
	var button: Button = _scene.get_node("%ReturnToMenuButton")
	button.grab_focus()
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	assert_true(_localization.set_locale("zh_CN").get("ok", false))
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	for frame: int in 4: await get_tree().process_frame
	assert_eq(_scene.get("retry_requests"), 0)
	assert_true(button.has_focus(), "locale projection preserves the Retry focus stop")


func test_registered_accessibility_preferences_update_the_recovery_material() -> void:
	await _mount()
	var profile := get_node("/root/ProfileManager")
	var panel: PanelContainer = _scene.get_node("%RecoveryPanel")
	var button: Button = _scene.get_node("%ReturnToMenuButton")
	assert_true(profile.set_preference("preferences.accessibility.text_size", 150).get("ok", false))
	assert_eq(panel.theme.default_font_size, 36)
	assert_eq(button.custom_minimum_size.y, 72.0)
	assert_true(profile.set_preferences({&"preferences.accessibility.text_size": 100,
		&"preferences.accessibility.large_targets": true}).get("ok", false))
	assert_eq(button.custom_minimum_size.y, 64.0)
	for preset: String in ["protan", "deutan", "tritan"]:
		assert_true(profile.set_preference("preferences.accessibility.colour_differentiation", preset).get("ok", false))
		var expected: Dictionary = PALETTES.resolve(&"after_hours", false, preset)
		assert_eq(panel.theme.get_color("focus", "Settings"), expected.focus, preset)
	assert_true(profile.set_preference("preferences.accessibility.high_contrast", true).get("ok", false))
	assert_eq(panel.theme.get_color("ink", "Settings"), PALETTES.resolve(&"after_hours", true, "tritan").ink)


func test_retry_focus_and_keyboard_replay_the_same_temporarily_failed_command() -> void:
	var playback := RetryPlayback.new()
	_scene = ENDING.instantiate()
	assert_true(_scene.configure_ending_ports(RetryState.new(), playback).get("ok", false))
	add_child(_scene)
	for frame: int in 4: await get_tree().process_frame
	var button: Button = _scene.get_node("%ReturnToMenuButton")
	assert_true(button.has_focus(), "a newly exposed recovery action receives keyboard focus")
	assert_eq(playback.starts.size(), 1)
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	for frame: int in 4: await get_tree().process_frame
	assert_eq(playback.starts.size(), 2)
	if playback.starts.size() == 2: assert_eq(playback.starts[1], playback.starts[0])
	assert_false(_scene.get_node("%RecoveryPanel").visible)
	assert_false(_scene.get("_retry_available"))
	assert_false(_scene.get("_pending_ending_command").is_empty())
