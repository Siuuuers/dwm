extends GutTest
## One shared Settings row in the actual title, desktop, and Pause hosts.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const TITLE := preload("res://scenes/menu/Setting.tscn")
const DESKTOP := preload("res://scenes/apps/SettingsApp.tscn")
const PAUSE := preload("res://scenes/overlay/PauseSurface.tscn")
const PATH := &"preferences.accessibility.steady_interface"
const LABEL_KEY := "settings.accessibility_steady_interface"
const DESCRIPTION_KEY := "settings.accessibility_steady_interface_description"
const LABELS := {"en": "Steady interface", "zh_CN": "稳定界面", "zh_HK": "穩定介面"}

var _surface: SubViewport
var _profile: Node
var _localization: Node
var _ready_fixture := false

func before_each() -> void:
	_ready_fixture = false
	var test_root: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(test_root.is_empty(), "Settings fixture requires isolated DWM_TEST_ROOT before catalog reads")
	if test_root.is_empty(): return
	_profile = PROFILE.new()
	_localization = LOCALIZATION.new()
	add_child(_profile)
	add_child(_localization)
	assert_true(_profile.initialize(STORAGE.new("steady-interface-settings.memory", FILES.new())).get("ok", false))
	assert_true(_localization.initialize(_profile).get("ok", false))
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.gui_embed_subwindows = true
	add_child(_surface)
	_ready_fixture = true

func after_each() -> void:
	if is_instance_valid(_surface): _surface.free()
	if is_instance_valid(_localization): _localization.free()
	if is_instance_valid(_profile): _profile.free()

func _settle() -> void:
	for frame: int in 4: await get_tree().process_frame

func _tap(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		_surface.push_input(event, true)
		await _settle()

func _services() -> Dictionary:
	return {"profile": _profile, "localization": _localization,
		"input": null, "audio": null, "tts": null, "volume": null,
		"profile_reset_admission": func() -> bool: return true}

func _host(kind: String) -> Dictionary:
	var app: Control = TITLE.instantiate() if kind == "title" else DESKTOP.instantiate()
	var content: Control = app.get_node("SettingsContent")
	content.configure_services(_services())
	app.get_node("LocalePresentationRoot").set("_localization", _localization)
	if kind == "pause":
		var pause: Control = PAUSE.instantiate()
		assert_true(pause.set_host(&"settings", app))
		_surface.add_child(pause)
		pause.open_surface()
		await _settle()
		assert_false(content.is_interaction_enabled(), "Pause preview holds the shared row inert")
		pause.rows[&"settings"].grab_focus()
		await _tap(KEY_RIGHT)
		assert_eq(pause.entered_action, &"settings")
		assert_true(content.is_interaction_enabled())
		return {"root": pause, "app": app, "content": content}
	_surface.add_child(app)
	app.show_window()
	await _settle()
	assert_true(content.is_interaction_enabled())
	return {"root": app, "app": app, "content": content}

func _catalog_text(locale: String, key: String) -> String:
	var store: Dictionary = _localization.get("_catalog_store")
	var catalogs: Dictionary = store.get("catalogs", {})
	assert_true(catalogs.has(locale), "the locale has its own validated catalog: " + locale)
	if not catalogs.has(locale): return ""
	for message: Dictionary in catalogs[locale].get("messages", []):
		if message.get("id") == key:
			return str(message.get("text", ""))
	assert_true(false, "%s is authored in %s without fallback" % [key, locale])
	return ""

func _row(content: Control) -> Dictionary:
	content.select_category("accessibility")
	var row: Control = content.rows.get(PATH)
	var toggle: CheckBox = content.control_for(PATH)
	var description: Label = content.find_child("SteadyInterfaceDescription", true, false)
	assert_not_null(row, "the registered row is in the real Accessibility sheet")
	assert_not_null(toggle, "generic Settings controller owns a real CheckBox")
	assert_not_null(description, "the explanation is visible player copy")
	if row == null or toggle == null or description == null: return {}
	assert_true(row.is_visible_in_tree())
	assert_true(description.is_visible_in_tree())
	return {"row": row, "toggle": toggle, "label": row.get_child(0), "description": description}

func test_title_desktop_and_entered_pause_commit_the_same_registered_toggle() -> void:
	if not _ready_fixture: return
	for kind: String in ["title", "desktop", "pause"]:
		var fixture: Dictionary = await _host(kind)
		var content: Control = fixture.content
		assert_eq(content.host_context, kind)
		var row: Dictionary = _row(content)
		if row.is_empty():
			fixture.root.free()
			continue
		var toggle: CheckBox = row.toggle
		assert_false(toggle.button_pressed)
		assert_false(_profile.get_preference(PATH))
		assert_true(content.get_controller().get("_controls").has(PATH), "generic controller binds the path")
		toggle.grab_focus()
		await _settle()
		var scroll: int = content.sheet_scroll.scroll_vertical
		var revision: int = _profile.get_profile_revision()
		toggle.button_pressed = true
		await _settle()
		assert_true(_profile.get_preference(PATH), kind + " commits through Profile")
		assert_true(toggle.button_pressed)
		assert_eq(_profile.get_profile_revision(), revision + 1, kind + " publishes once")
		assert_eq(content.rows[PATH], row.row, "commit keeps the same mounted row")
		assert_eq(content.control_for(PATH), toggle)
		assert_true(toggle.has_focus(), kind + " keeps keyboard focus")
		assert_eq(content.sheet_scroll.scroll_vertical, scroll, kind + " keeps reading position")
		toggle.button_pressed = false
		await _settle()
		assert_false(_profile.get_preference(PATH))
		assert_eq(_profile.get_profile_revision(), revision + 2)
		fixture.root.free()

func test_three_catalogs_supply_live_label_and_description_without_fallback() -> void:
	if not _ready_fixture: return
	var fixture: Dictionary = await _host("desktop")
	var content: Control = fixture.content
	var row: Dictionary = _row(content)
	if row.is_empty(): return
	var label: Label = row.label
	var description: Label = row.description
	var toggle: CheckBox = row.toggle
	for locale: String in ["en", "zh_CN", "zh_HK"]:
		assert_true(_localization.set_locale(locale).get("ok", false), locale)
		await _settle()
		var own_label := _catalog_text(locale, LABEL_KEY)
		var own_description := _catalog_text(locale, DESCRIPTION_KEY)
		assert_eq(own_label, LABELS[locale], locale + " label is authored in its own catalog")
		assert_false(own_description.is_empty(), locale + " description is authored")
		assert_eq(label.text, own_label)
		assert_eq(description.text, own_description)
		assert_eq(content.rows[PATH], row.row)
		assert_eq(content.control_for(PATH), toggle)
		assert_eq(content.find_child("SteadyInterfaceDescription", true, false), description)
	assert_true(_profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false))
	await _settle()
	assert_eq(content.theme.default_font_size, 36)
	assert_eq(content.rows[PATH], row.row, "live text scaling keeps the same row")
	assert_eq(content.find_child("SteadyInterfaceDescription", true, false), description)
	assert_eq(description.text, _catalog_text("zh_HK", DESCRIPTION_KEY))
