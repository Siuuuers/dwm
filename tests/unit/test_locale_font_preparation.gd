extends "res://addons/gut/test.gd"
const MANAGER := preload("res://autoload/LocalizationManager.gd")
const CATALOG := preload("res://scripts/localization/LocalizationCatalog.gd")
const ROOT := preload("res://scripts/ui/LocalePresentationRoot.gd")

class FontOwner extends Node:
	var calls := 0
	func get_font_paths(_profile_id: String) -> Dictionary:
		calls += 1
		return {"ok": false, "code": &"fixture_font_profile_unavailable"}

func test_registered_root_uses_current_owner_font_evidence_and_propagates_refusal() -> void:
	var owner := FontOwner.new()
	var target := Control.new()
	var presentation := ROOT.new()
	presentation._target = target
	presentation._localization = owner
	var prepared: Dictionary = presentation.prepare_presentation({"locale_id": "en", "font_profile": "latin", "layout_direction": "ltr"})
	assert_eq(prepared.get("code"), &"fixture_font_profile_unavailable")
	assert_eq(owner.calls, 1, "the initialized catalog is authoritative; no second disk catalog")
	presentation.free()
	target.free()
	owner.free()

func test_font_paths_cover_real_fallbacks_and_are_detached() -> void:
	var loaded: Dictionary = CATALOG.load_bundle("res://localization/manifest.json")
	assert_true(loaded.get("ok", false))
	var owner := MANAGER.new()
	owner._catalog_store = loaded.value
	owner._readiness = &"ready"
	var root_view := ROOT.new()
	for record: Dictionary in loaded.value.manifest.font_profiles:
		var expected: Dictionary = root_view._font_paths_for_profile(loaded.value.manifest, record.id)
		var actual: Dictionary = owner.get_font_paths(record.id)
		assert_eq(actual.value, expected.value)
		actual.value.clear()
		assert_eq(owner.get_font_paths(record.id).value, expected.value, "callers cannot mutate catalog paths")
	assert_eq(owner.get_font_paths("missing").get("code"), &"unknown_font_profile")
	owner._readiness = &"failed"
	assert_eq(owner.get_font_paths("missing").get("code"), &"localization_not_ready")
	root_view.free()
	owner.free()


func test_real_pending_root_can_prepare_fonts_during_initialization() -> void:
	var files := preload("res://tests/support/FakeFileOps.gd").new()
	var storage := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new("font-test", files)
	var profile := preload("res://autoload/ProfileManager.gd").new()
	assert_true(profile.initialize(storage).get("ok", false))
	var owner := MANAGER.new()
	var target := Control.new()
	var presentation := ROOT.new()
	presentation._target = target
	presentation._localization = owner
	assert_true(owner.register_presentation_root(presentation).get("ok", false))
	var initialized: Dictionary = owner.initialize(profile)
	assert_true(initialized.get("ok", false), str(initialized))
	assert_not_null(target.theme)
	assert_eq(owner.get_readiness(), &"ready")
	assert_eq(target.layout_direction, Control.LAYOUT_DIRECTION_LTR)
	presentation.free()
	target.free()
	owner.free()
	profile.free()
