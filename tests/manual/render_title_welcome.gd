extends SceneTree
## Native presentation probe. Run through the isolated Godot wrapper without --headless.
const MENU := preload("res://scenes/menu/MenuScene.tscn")

class Locale extends Node:
	signal locale_changed(locale: String)
	var value := "en"
	func get_locale() -> String: return value
	func has_key(_key: String) -> bool: return true
	func t(key: String, _parameters: Dictionary = {}) -> String:
		return {"menu.new_account": "New Account", "menu.login": "Log in", "menu.gallery": "Gallery", "menu.setting": "Settings", "menu.shutdown": "Shut down"}.get(key, key)

class Profile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	var percent := 100
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return percent if path == &"preferences.accessibility.text_size" else fallback

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for sample: Dictionary in [{"locale":"en", "percent":100, "stage":"", "file":"title-welcome-en100.png"},
		{"locale":"en", "percent":100, "stage":"starting", "file":"title-starting-en100.png"},
		{"locale":"zh-CN", "percent":125, "stage":"preparing", "file":"title-preparing-cn125.png"},
		{"locale":"zh-HK", "percent":150, "stage":"starting", "file":"title-starting-hk150.png"}]:
		var locale := Locale.new()
		locale.value = sample.locale
		viewport.add_child(locale)
		var profile := Profile.new()
		profile.percent = sample.percent
		viewport.add_child(profile)
		var menu: Control = MENU.instantiate()
		menu.configure_settings_services({"profile": profile, "localization": locale})
		menu.configure_startup_recovery_owner(null)
		viewport.add_child(menu)
		menu._title_welcome.set_busy(sample.stage)
		for frame in 3: await RenderingServer.frame_post_draw
		var welcome: Control = menu._title_welcome
		for label: Label in [welcome.wordmark, welcome.welcome, welcome.status]:
			if label.visible and (label.get_minimum_size().y > label.size.y or not welcome.get_global_rect().encloses(label.get_global_rect())):
				push_error("TITLE_WELCOME_OVERFLOW: " + str(sample))
				quit(1)
				return
		var pixels := viewport.get_texture().get_image()
		if pixels.save_png("res://.godot/phase2r_logs/" + sample.file) != OK:
			quit(1)
			return
		menu._setting_host.show()
		menu._update_title_destination()
		if welcome.visible:
			push_error("Title welcome overlaps a hosted app")
			quit(1)
			return
		print("TITLE_WELCOME_CAPTURE: " + sample.file)
		menu.free()
		locale.free()
		profile.free()
	viewport.free()
	quit(0)
