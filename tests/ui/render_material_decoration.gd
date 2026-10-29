extends "res://tests/ui/render_desktop_scaling.gd"
## Actual desktop drawing with isolated presentation/ownership fixtures, not purchase evidence.
const ITEMS := ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal"]

class InventoryFixture extends Node:
	var inventory: Dictionary = {}

var inventory: InventoryFixture

func _run() -> void:
	if folder.is_empty(): folder = ProjectSettings.globalize_path("res://.godot/ci/material-decoration")
	DirAccess.make_dir_recursive_absolute(folder)
	check(DisplayServer.get_name() != "headless", "material previews require rendered pixels")
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	locale = VisualLocale.new()
	viewport.add_child(locale)
	check(locale.present("en"), "English catalog")
	profile = VisualPreferences.new()
	viewport.add_child(profile)
	main = SPLIT.MAIN.instantiate()
	desktop = SPLIT.DESKTOP.instantiate()
	desktop.set_script(SHELL.IsolatedDesktop)
	check(desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new()).get("ok", false), "run palette")
	main._computer_desktop_instance = desktop
	main.get_node("%ComputerPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	main.get_node("%ComputerPanel").add_child(desktop)
	viewport.add_child(main)
	host = SCHEDULE.HOST.new()
	host.reset(1)
	check(desktop.configure_contacts(CONTACT.FakePort.new(), locale, profile, host).get("ok", false), "Contacts configured")
	desktop._foreground_eligible = true
	main.get_node("RootHBox").set_angela_width(720)
	inventory = InventoryFixture.new()
	viewport.add_child(inventory)
	desktop._cosmetic_inventory_owner = inventory
	profile.present(125, false)
	await settle()
	desktop.configure_clock(func() -> Dictionary: return {"hour": 12, "minute": 34, "second": 0})
	desktop._clock_timer.stop()
	desktop.contacts_button.grab_focus()
	var focused: Control = viewport.gui_get_focus_owner()
	var launcher_rect: Rect2 = desktop.icon_grid.get_global_rect()
	var bare: Image = await _material_capture("none")
	for item: String in ITEMS:
		inventory.inventory = {item: 1}
		var decorated: Image = await _material_capture(item)
		check(decorated.get_data() != bare.get_data(), item + " visibly differs from no-item desktop")
		check(desktop.icon_grid.get_global_rect() == launcher_rect, item + " preserves launcher geometry")
		check(viewport.gui_get_focus_owner() == focused, item + " preserves focus")
		if item == "letter_with_wax_seal" and OS.get_environment("DWM_MATERIAL_BASELINE") != "1":
			var canvas: Control = desktop.desktop_canvas
			var region := Rect2i(canvas.get_global_transform_with_canvas() * Rect2(canvas.size.x - 110, 0, 110, canvas.size.y - 144))
			desktop.status_label.text = "Preview failure"
			desktop.status_label.show()
			var failure: Image = await _material_capture("letter-status-visible", true, false)
			check(failure.get_region(region).get_data() == bare.get_region(region).get_data(), "failure feedback suppresses letter pixels")
			desktop.status_label.hide()
			var restored: Image = await _material_capture("letter-status-cleared", false, false)
			check(restored.get_data() == decorated.get_data(), "cleared feedback restores same letter pixels")
	check(desktop.open_contacts().get("ok", false), "letter-only Contacts")
	var letter_app: Image = await _material_capture("letter-only-app")
	inventory.inventory = {}
	var bare_app: Image = await _material_capture("none-app")
	check(letter_app.get_data() == bare_app.get_data(), "letter-only app matches undecorated app")
	check(desktop.return_home().get("ok", false), "letter check returns Home")
	inventory.inventory = {"crystal_stutters": 1, "inked_silk_string": 1, "letter_with_wax_seal": 1}
	for palette: StringName in [&"after_hours", &"midnight"]:
		# This fixture chooses the run palette before opening each fresh app view.
		if desktop._cached_app_windows.has(&"contacts"):
			desktop._cached_app_windows[&"contacts"].free()
			desktop._cached_app_windows.erase(&"contacts")
		desktop._run_palette = palette
		for font: String in ["pixel", "readable"]:
			profile.present_font(font)
			for percent: int in [125, 150]:
				profile.present(percent, false)
				desktop._refresh_launcher(false)
				var label := "%s-%s-%d" % [palette, font, percent]
				await _material_capture(label + "-home")
				check(desktop.open_contacts().get("ok", false), label + " opens Contacts")
				await _material_capture(label + "-app")
				check(desktop.return_home().get("ok", false), label + " returns Home")
	profile.present_contrast(true)
	await _material_capture("high-contrast-home")
	check(desktop.open_contacts().get("ok", false), "high-contrast Contacts")
	await _material_capture("high-contrast-app")
	check(desktop.return_home().get("ok", false), "high-contrast Home")
	profile.present_contrast(false)
	main.get_node("RootHBox").set_angela_width(1120)
	await _material_capture("narrow-home")
	check(desktop.open_contacts().get("ok", false), "narrow Contacts")
	await _material_capture("narrow-app")
	check(desktop.return_home().get("ok", false), "narrow Home")
	inventory.inventory = {}
	await _material_capture("narrow-none")
	check(not desktop.cosmetic_overlay.visible, "empty inventory removes decoration")
	if OS.get_environment("DWM_MATERIAL_BASELINE") != "1":
		viewport.size = Vector2i(1920, 720)
		main.get_node("RootHBox").set_angela_width(720)
		var short_bare: Image = await _material_capture("short-none")
		check(desktop.desktop_canvas.size.y <= 480, "short fixture has insufficient logical height")
		inventory.inventory = {"letter_with_wax_seal": 1}
		var short_letter: Image = await _material_capture("short-letter")
		check(short_letter.get_data() == short_bare.get_data(), "short layout suppresses letter instead of covering content")
	print("MATERIAL_DECORATION_RESULT captures=", captures, " failures=", failures.size())
	viewport.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _material_capture(label: String, failure_visible: bool = false, refresh: bool = true) -> Image:
	if refresh: desktop._refresh_cosmetics()
	await settle()
	check(desktop.cosmetic_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, label + " ignores pointer")
	check(desktop.cosmetic_overlay.focus_mode == Control.FOCUS_NONE, label + " cannot receive focus")
	check(desktop.status_label.visible == failure_visible, label + " expected failure notice visibility")
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	check(image.get_size() == viewport.size, label + " full viewport")
	check(image.save_png(folder.path_join(label + ".png")) == OK, label + " saved")
	var original: PackedByteArray = image.get_data()
	desktop.cosmetic_overlay.queue_redraw()
	await settle()
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().get_data() == original, label + " deterministic redraw")
	captures += 1
	return image
