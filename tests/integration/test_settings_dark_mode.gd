extends GutTest
## Real Profile and Settings content. Only isolated prior ending completion receipts are fixtures.
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const CONTENT := preload("res://scenes/shared/SettingsContent.tscn")
const PATH := &"preferences.dark_mode.next_run_enabled"
class DiscoveryFiles:
	extends "res://tests/support/FakeFileOps.gd"
	var reject_next_write := false
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if reject_next_write:
			reject_next_write = false
			return {"ok": false, "code": &"fixture_write_failure"}
		return super.write_bytes(path, bytes)

var profile: Node
var files: RefCounted
var storage: RefCounted
var content: Control

func before_each() -> void:
	files = DiscoveryFiles.new()
	storage = STORAGE.new("settings-dark-mode.memory", files)
	profile = add_child_autofree(PROFILE.new())
	assert_true(profile.initialize(storage).ok)
	var localization: Node = add_child_autofree(LOCALIZATION.new())
	assert_true(localization.initialize(profile).ok)
	content = CONTENT.instantiate()
	content.host_context = "title"
	content.configure_services({"profile": profile, "localization": localization,
		"profile_reset_admission": func(): return true})
	add_child_autofree(content)
	content.select_category("records")

func _unlock_mode() -> void:
	for ending: String in ["ending.priscilla.dark", "ending.lavinia.dark", "ending.sylvia.dark", "ending.sylvia.special"]:
		assert_true(profile.record_ending_completion(ending, "ending:isolated-settings-fixture:gallery:" + ending).ok)
	assert_true(profile.get_preference(&"preferences.dark_mode.available", false), "four real ending discoveries grant the Profile capability")
	content._controller.refresh()

func test_dark_toggle_is_absent_until_actual_unlock_and_failed_write_keeps_old_value() -> void:
	assert_true(content.rows.has(PATH))
	assert_false(content.rows[PATH].visible)
	assert_true(content.controls[PATH].disabled)
	# The public locked control is hidden and disabled; do not bypass it by
	# calling the generic preference controller with an impossible UI event.
	assert_false(profile.get_preference(PATH, false))
	_unlock_mode()
	assert_true(content.rows[PATH].visible)
	assert_false(content.controls[PATH].disabled)
	assert_ne(content.controls[PATH].accessibility_name, "settings.dark_mode_next_run_enabled")
	var before: Dictionary = profile.get_profile_snapshot()
	files.fail_after(files.operation_count() + 1)
	content.controls[PATH].button_pressed = true
	await get_tree().process_frame
	assert_eq(profile.get_profile_snapshot(), before)
	assert_false(content.controls[PATH].button_pressed, "failed persistence restores the actual checkbox")

func test_public_dark_toggle_persists_next_run_only_and_full_reset_hides_it_again() -> void:
	_unlock_mode()
	assert_true(content.rows[PATH].is_visible_in_tree())
	assert_false(content.controls[PATH].disabled)
	var current_run: Dictionary = GameState.to_save_dict().duplicate(true)
	content.controls[PATH].button_pressed = true
	await get_tree().process_frame
	assert_true(profile.get_preference(PATH, false))
	assert_true(content.controls[PATH].button_pressed)
	assert_eq(GameState.to_save_dict(), current_run, "changing the next account preference does not recapture an active run")
	var reopened: Node = add_child_autofree(PROFILE.new())
	assert_true(reopened.initialize(storage).ok)
	assert_true(reopened.get_preference(PATH, false), "new Profile owner reads the durable preference")
	assert_true(profile.reset_entire_profile().ok)
	content._controller.refresh()
	assert_false(content.rows[PATH].visible)
	assert_false(profile.get_preference(PATH, false))

func test_final_discovery_and_availability_commit_together_and_survive_clear_gallery() -> void:
	for ending: String in ["ending.priscilla.dark", "ending.lavinia.dark", "ending.sylvia.dark"]:
		assert_true(profile.record_ending_completion(ending, "ending:isolated-discovery-fixture:gallery:" + ending).ok)
		assert_false(profile.get_preference(&"preferences.dark_mode.available", false))
	assert_true(profile.reset_gallery().ok)
	var before: Dictionary = profile.get_profile_snapshot()
	var transaction_id := "ending:isolated-discovery-fixture:gallery:ending.sylvia.special"
	files.reject_next_write = true
	var failed: Dictionary = profile.record_ending_completion("ending.sylvia.special", transaction_id)
	assert_false(failed.ok, str(failed))
	assert_eq(failed.get("code"), &"write_not_committed", str(failed))
	assert_false(failed.get("fatal", false), str(failed))
	assert_eq(profile.get_profile_snapshot(), before, "failed final discovery grants neither unlock nor mode")
	var retried: Dictionary = profile.record_ending_completion("ending.sylvia.special", transaction_id)
	assert_true(retried.ok, str(retried))
	assert_true(profile.get_preference(&"preferences.dark_mode.available", false))
	assert_true(content.rows[PATH].visible, "actual Profile publication reveals the Settings control")
	assert_false(content.controls[PATH].disabled)
	var revision: int = profile.get_profile_revision()
	assert_true(profile.record_ending_completion("ending.sylvia.special", transaction_id).ok)
	assert_eq(profile.get_profile_revision(), revision, "the exact completion retry does not rewrite discovery")
	assert_true(profile.reset_gallery().ok)
	var restored: Node = add_child_autofree(PROFILE.new())
	assert_true(restored.initialize(storage).ok)
	assert_true(restored.get_preference(&"preferences.dark_mode.available", false))
	assert_false(restored.get_preference(PATH, false), "discovery does not enable the next account automatically")

func test_initialize_repairs_compatible_discovery_durably_and_exact_ending_retry_stays_idempotent() -> void:
	_unlock_mode()
	# Persist the old writer's compatible state: all discoveries, absent derived grant.
	var legacy: Dictionary = profile.get_profile_snapshot()
	legacy.preferences.dark_mode.available = false
	assert_true(profile.commit_prepared_profile(legacy).ok)
	var restored: Node = add_child_autofree(PROFILE.new())
	assert_true(restored.initialize(storage).ok)
	assert_true(restored.get_preference(&"preferences.dark_mode.available", false))
	assert_false(restored.get_preference(PATH, false))
	var revision: int = restored.get_profile_revision()
	var receipts: Dictionary = restored.get_profile_snapshot().gallery_transaction_receipts.duplicate(true)
	assert_true(restored.record_ending_completion("ending.sylvia.special", "ending:isolated-settings-fixture:gallery:ending.sylvia.special").ok)
	assert_true(restored.get_preference(&"preferences.dark_mode.available", false))
	assert_eq(restored.get_profile_snapshot().gallery_transaction_receipts, receipts)
	assert_eq(restored.get_profile_revision(), revision, "exact completed ending remains an idempotent retry")
	var reopened: Node = add_child_autofree(PROFILE.new())
	assert_true(reopened.initialize(storage).ok)
	assert_true(reopened.get_preference(&"preferences.dark_mode.available", false), "adoption persists the repair before publishing")

func test_failed_compatibility_grant_persistence_does_not_adopt_or_publish_profile() -> void:
	_unlock_mode()
	var legacy: Dictionary = profile.get_profile_snapshot()
	legacy.preferences.dark_mode.available = false
	assert_true(profile.commit_prepared_profile(legacy).ok)
	var restored: Node = add_child_autofree(PROFILE.new())
	var publications := [0]
	restored.profile_restored.connect(func(_value: Dictionary): publications[0] += 1)
	files.reject_next_write = true
	var failed: Dictionary = restored.initialize(storage)
	assert_false(failed.ok, str(failed))
	assert_eq(failed.get("code"), &"write_not_committed", str(failed))
	assert_eq(restored.get_profile_snapshot(), {}, "failed repair does not adopt an unpersisted Profile")
	assert_eq(publications[0], 0)
	var retried: Dictionary = restored.initialize(storage)
	assert_true(retried.ok, str(retried))
	assert_true(restored.get_preference(&"preferences.dark_mode.available", false))
	assert_false(restored.get_preference(PATH, false))
	assert_eq(publications[0], 1, "only durable repaired adoption publishes")
