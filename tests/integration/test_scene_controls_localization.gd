extends GutTest
## Isolated real locale/profile owners; callbacks never reach production persistence.
const HOST := preload("res://scenes/narrative/SceneHost.tscn")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const CONTROLS := "SceneControlsLayer/Surface/Controls/"

var _profile: Node
var _locale: Node
var _host: Control
var _surface: SubViewport
var _calls: Array[String] = []
var _allow := true

func before_each() -> void:
	_calls.clear()
	_allow = true
	_profile = PROFILE.new()
	_locale = LOCALIZATION.new()
	assert_true(_profile.initialize(STORAGE.new("scene-controls-localization", FILES.new())).get("ok", false))
	assert_true(_locale.initialize(_profile).get("ok", false))
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.gui_embed_subwindows = true
	add_child(_surface)
	_mount_host()

func after_each() -> void:
	_surface.free()
	_locale.free()
	_profile.free()

func _mount_host() -> void:
	_host = HOST.instantiate()
	_host._localization = _locale
	_host._profile = _profile
	var actions := {}
	for action: String in ["computer_open", "computer_close", "apps", "contacts"]:
		actions[action] = _dispatch.bind(action)
	_host.configure_scene_controls(actions)
	_surface.add_child(_host)

func _dispatch(action: String) -> Dictionary:
	_calls.append(action)
	return {"ok": _allow}

func _button(node_name: String) -> Button:
	return _host.get_node(CONTROLS + node_name)

func test_live_locale_change_preserves_admitted_open_state_focus_and_dispatch() -> void:
	var computer := _button("CheckComputer")
	computer.pressed.emit()
	assert_eq(_calls, ["computer_open"])
	computer.grab_focus()
	for language: String in ["zh_HK", "zh_CN", "ja", "ko", "en"]:
		assert_true(_locale.set_locale(language).get("ok", false))
		assert_eq(computer.accessibility_name, _locale.t("scene.controls.close_computer"))
		assert_eq(computer.text, "", "centered chevron is drawn independently of font metrics")
		assert_true(computer.has_focus(), "presentation refresh retains focused button")
		assert_true(_host.is_computer_open())
		assert_true(_host.get_challenge_mount().visible)
	assert_eq(_calls, ["computer_open"], "projection dispatches no gameplay action")
	_allow = false
	computer.pressed.emit()
	assert_true(_host.is_computer_open())
	assert_eq(computer.accessibility_name, _locale.t("scene.controls.close_computer"))
	_allow = true
	computer.pressed.emit()
	assert_false(_host.is_computer_open())
	assert_eq(computer.accessibility_name, _locale.t("scene.controls.check_computer"))
	assert_eq(_calls, ["computer_open", "computer_close", "computer_close"])

func test_committed_typography_refresh_is_scoped_and_keeps_controls_live() -> void:
	assert_true(_locale.set_locale("ja").get("ok", false))
	var mount: Control = _host.get_challenge_mount()
	var mount_theme: Theme = mount.theme
	var computer := _button("CheckComputer")
	computer.grab_focus()
	for style: String in ["readable", "pixel"]:
		assert_true(_locale.set_font_style(style).get("ok", false))
		for percent: int in [150, 125, 100]:
			assert_true(_profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false))
			assert_same(computer.get_theme_font("font"), TYPOGRAPHY.font("ja", percent, style))
			assert_eq(computer.get_theme_font_size("font_size"), TYPOGRAPHY.font_size("ja", percent, 24, style))
			assert_same(_host.get_node("SceneControlsLayer/Surface/ThoughtOptions").theme.default_font, TYPOGRAPHY.story_font("ja", percent, style))
			assert_eq(mount.theme, mount_theme, "chrome does not install a Challenge theme")
			assert_true(computer.has_focus())
			assert_false(computer.disabled)
	assert_eq(_calls, [], "font changes dispatch no action")
	_button("CheckComputer").pressed.emit()
	assert_eq(_calls, ["computer_open"], "action routing still works")

func test_freed_host_drops_subscriptions_and_replacement_projects_current_preferences() -> void:
	var locale_connections: int = _locale.locale_changed.get_connections().size()
	var profile_connections: int = _profile.preference_changed.get_connections().size()
	var restore_connections: int = _profile.profile_restored.get_connections().size()
	_host.free()
	assert_eq(_locale.locale_changed.get_connections().size(), locale_connections - 1)
	assert_eq(_profile.preference_changed.get_connections().size(), profile_connections - 1)
	assert_eq(_profile.profile_restored.get_connections().size(), restore_connections - 1)
	assert_true(_locale.set_locale("ko").get("ok", false))
	assert_true(_locale.set_font_style("readable").get("ok", false))
	assert_true(_profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false))
	_mount_host()
	assert_eq(_button("CheckComputer").accessibility_name, _locale.t("scene.controls.check_computer"))
	assert_same(_button("CheckComputer").get_theme_font("font"), TYPOGRAPHY.font("ko", 150, "readable"))
	assert_eq(_locale.locale_changed.get_connections().size(), locale_connections)
	assert_eq(_profile.profile_restored.get_connections().size(), restore_connections)
	assert_eq(_calls, [])

func test_profile_restore_refreshes_typography_only_after_publication() -> void:
	var snapshot: Dictionary = _profile.capture_restore_state().value
	assert_true(_locale.set_font_style("readable").get("ok", false))
	assert_true(_profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false))
	var computer := _button("CheckComputer")
	computer.grab_focus()
	assert_true(_profile.apply_restore_silent(snapshot).get("ok", false))
	assert_same(computer.get_theme_font("font"), TYPOGRAPHY.font("en", 150, "readable"), "silent restore has not published")
	assert_true(_profile.finalize_restore().get("ok", false))
	assert_same(computer.get_theme_font("font"), TYPOGRAPHY.font("en", 100, "pixel"))
	assert_eq(computer.get_theme_font_size("font_size"), 24)
	assert_true(computer.has_focus())
	assert_eq(_calls, [], "restored presentation does not replay actions")
