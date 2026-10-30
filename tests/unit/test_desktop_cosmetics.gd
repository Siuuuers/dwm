extends GutTest

const RAIL := preload("res://scripts/ui/witnessed/WitnessedTransportRail.gd")
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const SHELL := preload("res://tests/desktop_shell/test_desktop_shell.gd")

var desktop: Control
var state: Node
var previous_inventory: Dictionary

func before_each() -> void:
	state = get_node("/root/GameState")
	previous_inventory = state.inventory.duplicate(true)
	state.inventory = {}
	desktop = DESKTOP.instantiate()
	desktop.set_script(SHELL.IsolatedDesktop)
	desktop.size = Vector2(800, 720)
	assert_true(desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new()).get("ok", false))
	add_child_autofree(desktop)
	await get_tree().process_frame

func after_each() -> void:
	state.inventory = previous_inventory
	state.inventory_changed.emit()

func test_committed_inventory_updates_decorations_without_changing_layout_or_focus() -> void:
	assert_false(desktop.cosmetic_overlay.visible)
	var before: Rect2 = desktop.icon_grid.get_global_rect()
	desktop.launcher_buttons[&"contacts"].grab_focus()
	var focused: Control = get_viewport().gui_get_focus_owner()
	for item: String in ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal"]:
		state.inventory[item] = 1
		state.inventory_changed.emit()
		assert_true(desktop.cosmetic_overlay.visible, item + " applies on inventory publication")
		assert_eq(desktop.icon_grid.get_global_rect(), before)
		assert_same(get_viewport().gui_get_focus_owner(), focused)
	assert_eq(desktop.cosmetic_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(desktop.cosmetic_overlay.focus_mode, Control.FOCUS_NONE)
	assert_eq(desktop.cosmetic_overlay.get_parent(), desktop.desktop_canvas)
	assert_lt(desktop.cosmetic_overlay.get_index(), desktop.notification_layer.get_index())
	state.inventory = {}
	state.inventory_changed.emit()
	assert_false(desktop.cosmetic_overlay.visible, "new-run inventory removes every accent")

func test_materials_remain_over_apps_and_resize_without_changing_inventory() -> void:
	state.inventory = {"letter_with_wax_seal": 1}
	state.inventory_changed.emit()
	assert_true(desktop.cosmetic_overlay.visible)
	desktop._active_id = &"shop"
	desktop._refresh_launcher(false)
	assert_true(desktop.cosmetic_overlay.visible, "paper material persists while apps are open")
	for item: String in ["crystal_stutters", "inked_silk_string"]:
		state.inventory[item] = 1
		state.inventory_changed.emit()
		assert_true(desktop.cosmetic_overlay.visible, "frame accent remains while an app is open")
	var owned: Dictionary = state.inventory.duplicate(true)
	desktop._active_id = &""
	desktop._refresh_launcher(false)
	desktop.size = Vector2(928, 720)
	await get_tree().process_frame
	assert_true(desktop.cosmetic_overlay.visible)
	assert_eq(desktop.cosmetic_overlay.size, desktop.desktop_canvas.size)
	assert_eq(state.inventory, owned, "reflow and presentation do not change ownership")

func test_live_art_and_seven_controls_share_inventory_without_new_input_targets() -> void:
	var art := preload("res://scripts/ui/art/SceneArtView.gd").new()
	add_child_autofree(art)
	var texture := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	art.configure_textures(texture, [])
	var rail := RAIL.new()
	add_child_autofree(rail)
	assert_true(rail.configure_presentation(preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd").build("en", 150, "AfterHours"), "en", 150))
	var buttons: Array = rail._buttons.values()
	var states := ["normal", "hover", "pressed", "hover_pressed", "disabled"]
	var before := {}
	for style: String in states:
		var plate: StyleBox = buttons[0].get_theme_stylebox(style)
		before[style] = [plate.get_minimum_size(), plate.get_content_margin(SIDE_TOP), plate.get_content_margin(SIDE_BOTTOM)]
	buttons[0]._candidate = {"material_probe": true}
	assert_eq(buttons.size(), 7)
	assert_same(rail._material_owner, state)
	assert_false(art._material_overlay.visible)
	state.inventory = {"crystal_stutters": 1, "letter_with_wax_seal": 1}
	state.inventory_changed.emit()
	assert_true(art._material_overlay.visible)
	for style: String in states:
		var paper: StyleBox = buttons[0].get_theme_stylebox(style)
		assert_true(paper is RAIL.PaperPlate)
		assert_eq([paper.get_minimum_size(), paper.get_content_margin(SIDE_TOP), paper.get_content_margin(SIDE_BOTTOM)], before[style])
	assert_eq(buttons[0].get_theme_stylebox("disabled").base.border_width_bottom, 4)
	for button: Button in buttons:
		assert_eq(button.get_theme_stylebox("normal").base.bg_color, rail._roles[&"text"], "paper has a visible light surface")
		assert_eq(button.get_theme_color("font_color"), rail._roles[&"field"], "paper uses dark readable ink")
	assert_eq(buttons[0]._candidate, {"material_probe": true}, "material refresh preserves pending input")
	assert_eq(art._material_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(art._material_overlay.focus_mode, Control.FOCUS_NONE)
	assert_eq(rail._buttons.values(), buttons, "material changes retain all seven controls")
	state.inventory = {}
	state.inventory_changed.emit()
	assert_false(art._material_overlay.visible, "new run removes crystal from artwork")
	assert_true(buttons[0].get_theme_stylebox("normal") is StyleBoxFlat, "new run removes paper backgrounds")
	assert_eq(rail._buttons.values(), buttons)
	assert_true(desktop.theme.has_color("paper", "Desktop"), "desktop exposes its paper palette")
	assert_true(desktop.theme.has_color("paper_ink", "Desktop"), "desktop exposes contrasting paper ink")
