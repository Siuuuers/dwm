extends "res://tests/support/SceneRestoreActivationFixture.gd"

class ActiveSettingsOnly extends RefCounted:
	var calls: Array[String] = []
	func prepare(_input: Dictionary) -> Dictionary:
		calls.append("prepare")
		return {"ok": false, "code": &"settings_restore_called"}
	func capture() -> Dictionary:
		calls.append("capture")
		return {"ok": false}
	func apply_silent(_plan: Dictionary) -> Dictionary:
		calls.append("apply")
		return {"ok": false}
	func rollback_silent(_backup: Dictionary) -> Dictionary:
		calls.append("rollback")
		return {"ok": false}
	func finalize() -> Dictionary:
		calls.append("finalize")
		return {"ok": false}

class CurrentProfile extends RefCounted:
	var profile := {"preferences": {"audio": {"music_volume": 0.25}, "reading": {"auto_enabled": true}}, "gallery_unlocks": ["current"]}
	func get_preference_group(group: StringName) -> Dictionary: return profile.preferences[group].duplicate(true)

class AudioProbe extends RefCounted:
	var preferences := {}
	func prepare(input: Dictionary) -> Dictionary:
		preferences = input.preferences.duplicate(true)
		return {"ok": false, "code": &"audio_probe_reached"}

class DesktopProbe extends RefCounted:
	var plan_key: String
	func _init(key: String) -> void: plan_key = key
	func prepare(_input: Dictionary) -> Dictionary:
		return {"ok": true, "value": {plan_key: {}}}

class RunProbe extends RefCounted:
	func _prepare_admitted_snapshot(_snapshot: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"run_plan": {}}}

func test_scene_load_reuses_settings_without_capture_apply_or_publication() -> void:
	for key: String in ["profile", "localization"]:
		participants[key] = ActiveSettingsOnly.new()
		plans[key] = {"reuse_current": true}
	var result := _start()
	assert_eq(result.code, &"scene_activation_pending")
	participants.route.confirm("scene_load:1")
	participants.narrative.confirm("scene_load:1")
	assert_eq(participants.run.activated, 1)
	for key: String in ["profile", "localization"]:
		assert_eq(participants[key].calls, [], "Load leaves active settings owners untouched")
	assert_true(manager.capture_scene_restore_activation("scene_load:1").ok)

func test_scene_load_failure_does_not_compensate_untouched_settings() -> void:
	for key: String in ["profile", "localization"]:
		participants[key] = ActiveSettingsOnly.new()
		plans[key] = {"reuse_current": true}
	manager._journal.refuse_install = true
	assert_false(_start().ok)
	assert_eq(participants.run.rollbacks, 1)
	for key: String in ["profile", "localization"]:
		assert_eq(participants[key].calls, [])

func test_load_preparation_uses_current_audio_preferences() -> void:
	var preparation := preload("res://autoload/SaveManager.gd").new()
	var current := CurrentProfile.new()
	var audio := AudioProbe.new()
	var profile := ActiveSettingsOnly.new()
	var localization := ActiveSettingsOnly.new()
	preparation._new_run_profile_owner = current
	preparation._restore_participants = {"run": RunProbe.new(), "profile": profile, "localization": localization, "audio": audio,
		"desktop_consequence": DesktopProbe.new("consequence_plan"), "desktop_board": DesktopProbe.new("board_plan")}
	var scope := preload("res://tests/support/SceneValidationScope.gd").new()
	scope.install(true)
	var fixture := preload("res://tests/support/SceneAudioRegistrationFixture.gd").new()
	var installed: Dictionary = fixture._install_registration()
	assert_true(installed.ok, str(installed))
	if not installed.ok:
		scope.restore()
		preparation.free()
		return
	var manifest := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var snapshot := {"schema_version": 9, "desktop": {"consequence": {}, "board": {}}, "scene": {
		"registration_sha256": manifest.scene_registration_fingerprint(),
		"active_occurrence_id": "TEST.settings", "entry_id": "scene.test.b",
		"notification": {}, "active_challenge": {}, "return_to": null}}
	var document := {"current_snapshot": {"snapshot": snapshot}}
	var result: Dictionary = preparation._prepare_restore_document({}, document)
	assert_eq(result.get("code"), &"audio_probe_reached", str(result))
	assert_eq(audio.preferences, {"audio": current.profile.preferences.audio})
	assert_eq(current.profile.gallery_unlocks, ["current"])
	assert_eq(profile.calls, [])
	assert_eq(localization.calls, [])
	scope.restore()
	preparation.free()
