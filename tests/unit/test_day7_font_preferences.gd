extends GutTest

const SURFACE := preload("res://scripts/ui/Day7PreludeSurface.gd")
const TYPOGRAPHY := preload("res://scripts/ui/gallery/GalleryTypography.gd")
const GALLERY_THEME := preload("res://scripts/ui/gallery/GalleryTheme.gd")
const STYLE := &"preferences.accessibility.font_style"
const SIZE := &"preferences.accessibility.text_size"

class Profile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	signal profile_restored(profile: Dictionary)
	var values := {STYLE: "readable", SIZE: 125, &"preferences.reading.auto_enabled": true}
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return values.get(path, fallback)
	func publish(path: StringName, value: Variant) -> void:
		values[path] = value
		preference_changed.emit(path, value)

class Bootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary
	func _ready() -> void: pass
	func _target(id: StringName) -> Node: return targets.get(id)

class Localization extends Node:
	func get_locale() -> String: return "ko"

class Lifecycle extends RefCounted:
	func to_dict() -> Dictionary: return {"active_resolution_plan": null}
	func get_state() -> StringName: return &"PLAYING"

class Game extends RefCounted:
	var day := 7
	var _run_lifecycle := Lifecycle.new()
	func require_day7_presentations_complete() -> Dictionary: return {"ok": false}
	func capture_live_session() -> Dictionary: return {"ok": true, "value": {"run": "font-test"}}
	func validate_live_session(_session: Dictionary) -> Dictionary: return {"ok": true}

class Contacts extends RefCounted:
	func get_day7_followup_cards(_locale: String) -> Dictionary:
		return {"ok": false, "code": &"fixture_retry"}

class Router extends RefCounted:
	func get_current_route_id() -> String: return "main"

func _accept(_receipt: Dictionary) -> Dictionary: return {"ok": true}

func _card() -> Dictionary:
	return {"title": "A remembered reply", "body": "One retained paragraph.",
		"receipt": {"entry_id": "echo.fallback.day7", "view_token": "font-card"}}

func test_live_typography_keeps_card_history_palette_and_auto_clock() -> void:
	var profile := Profile.new()
	add_child_autofree(profile)
	var source: Theme = GALLERY_THEME.build("ja", 100, &"after_hours", "pixel")
	var surface := SURFACE.new()
	assert_true(surface.bind_reading_preferences(profile), "Binding may precede card configuration")
	assert_true(surface.configure(_card(), _accept, "ja", source, true).ok)
	add_child_autofree(surface)
	surface.set_process(false)
	await get_tree().process_frame
	surface._current_body.draw.emit()
	await get_tree().process_frame
	var body: Label = surface._current_body
	var history: Array[Dictionary] = surface.get_presentation_history()
	assert_eq(history.size(), 1)
	assert_same(body.get_theme_font("font"), TYPOGRAPHY.font("ja", 125, "readable"))
	assert_eq(body.get_theme_font_size("font_size"), 20)
	assert_true(surface._auto_enabled)
	surface._auto_remaining = 0.75
	profile.publish(STYLE, "pixel")
	assert_same(surface._current_body, body)
	assert_eq(surface.get_presentation_history(), history)
	assert_eq(surface._auto_remaining, 0.75, "Font changes do not restart the reading delay")
	assert_same(body.get_theme_font("font"), TYPOGRAPHY.font("ja", 125, "pixel"))
	assert_same(source.default_font, TYPOGRAPHY.font("ja", 100, "pixel"), "Caller theme is unchanged")
	assert_eq(surface._root.theme.get_color("paper_ink", "Gallery"), source.get_color("paper_ink", "Gallery"))
	assert_same(surface._root.theme.get_stylebox("normal", "Button"), source.get_stylebox("normal", "Button"))
	profile.publish(SIZE, 150)
	assert_eq(body.get_theme_font_size("font_size"), 24)
	assert_eq(surface._auto_remaining, 0.75)
	assert_eq(surface.get_presentation_history(), history)

func test_typography_only_binding_is_profile_scoped_and_restore_observed() -> void:
	var first := Profile.new()
	var second := Profile.new()
	add_child_autofree(first)
	add_child_autofree(second)
	second.values[STYLE] = "pixel"
	var surfaces: Array[Node] = []
	for profile: Profile in [first, second]:
		var surface := SURFACE.new()
		assert_true(surface.configure(_card(), _accept, "ko").ok)
		assert_true(surface.bind_typography_preferences(profile))
		add_child_autofree(surface)
		surfaces.append(surface)
		assert_null(surface._reading_profile, "Gallery typography does not opt into canonical Auto")
		assert_null(surface._auto_state)
		assert_false(surface._presentation_receipts)
	assert_same(surfaces[0]._root.theme.default_font, TYPOGRAPHY.font("ko", 125, "readable"))
	assert_same(surfaces[1]._root.theme.default_font, TYPOGRAPHY.font("ko", 125, "pixel"))
	first.values[STYLE] = "pixel"
	first.values[SIZE] = 150
	first.profile_restored.emit({})
	assert_same(surfaces[0]._root.theme.default_font, TYPOGRAPHY.font("ko", 150, "pixel"))
	assert_eq(surfaces[0]._root.theme.default_font_size, 24)
	assert_eq(surfaces[1]._root.theme.default_font_size, 20)

func test_actual_bootstrap_day7_mount_passes_bound_font_and_tracks_changes() -> void:
	var profile := Profile.new()
	var localization := Localization.new()
	add_child_autofree(profile)
	add_child_autofree(localization)
	var bootstrap := Bootstrap.new()
	bootstrap.targets = {&"ProfileManager": profile, &"LocalizationManager": localization}
	bootstrap._contacts_presentation_port = Contacts.new()
	bootstrap._desktop_identity_nonce_issuer = RefCounted.new()
	add_child_autofree(bootstrap)
	var scene := Control.new()
	var desktop := Control.new()
	desktop.name = "ComputerDesktop"
	scene.add_child(desktop)
	get_tree().root.add_child(scene)
	autofree(scene)
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = scene
	var mounted: bool = bootstrap._present_pending_day7_prelude(Game.new(), Router.new())
	get_tree().current_scene = previous_scene
	assert_true(mounted)
	var owner: Node = bootstrap._day7_prelude_owner
	assert_not_null(owner)
	if owner == null: return
	assert_same(owner._theme.default_font, TYPOGRAPHY.font("ko", 125, "readable"))
	var surface: Node = owner._surface
	assert_not_null(surface)
	if surface == null: return
	assert_same(surface._typography_profile, profile)
	assert_same(surface._root.theme.default_font, TYPOGRAPHY.font("ko", 125, "readable"))
	var retry_text: String = surface._next.text
	profile.publish(STYLE, "pixel")
	assert_same(owner._surface, surface)
	assert_same(surface._root.theme.default_font, TYPOGRAPHY.font("ko", 125, "pixel"))
	assert_eq(surface._next.text, retry_text)
