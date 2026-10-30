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
		before[style] = [plate.get_minimum_size(), plate.get_content_margin(SIDE_TOP), plate.get_content_margin(SIDE_BOTTOM), plate.bg_color, plate.border_color]
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
		assert_eq([paper.get_minimum_size(), paper.get_content_margin(SIDE_TOP), paper.get_content_margin(SIDE_BOTTOM), paper.base.bg_color, paper.base.border_color], before[style])
	assert_eq(buttons[0].get_theme_stylebox("disabled").base.border_width_bottom, 4)
	for button: Button in buttons:
		assert_eq(button.get_theme_stylebox("normal").base.bg_color, rail._roles[&"field"], "paper preserves original surface color")
		assert_eq(button.get_theme_color("font_color"), rail._roles[&"text"], "paper preserves original lettering")
	assert_eq(buttons[0]._candidate, {"material_probe": true}, "material refresh preserves pending input")
	assert_eq(art._material_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(art._material_overlay.focus_mode, Control.FOCUS_NONE)
	assert_eq(rail._buttons.values(), buttons, "material changes retain all seven controls")
	state.inventory = {}
	state.inventory_changed.emit()
	assert_false(art._material_overlay.visible, "new run removes crystal from artwork")
	assert_true(buttons[0].get_theme_stylebox("normal") is StyleBoxFlat, "new run removes paper backgrounds")
	assert_eq(rail._buttons.values(), buttons)

func test_crystal_patterns_are_run_stable_varied_and_do_not_consume_gameplay_rng() -> void:
	var material := preload("res://scripts/ui/MaterialDecoration.gd")
	seed(91234)
	var expected_random := randi()
	seed(91234)
	var first: Array = material.crystal_pattern("run-a", "computer")
	assert_true(is_same(first, material.crystal_pattern("run-a", "computer")), "redraw reuses cached geometry")
	assert_ne(first, material.crystal_pattern("run-b", "computer"), "new run changes the fractures")
	assert_eq(first, material.crystal_pattern("run-a", "computer"), "Load regenerates the same geometry")
	assert_ne(first, material.crystal_pattern("run-a", "art-right"), "panels have independent arrangements")
	assert_eq(randi(), expected_random, "decoration never consumes gameplay RNG")
	var counts := [0, 0, 0, 0]
	for run: int in 64:
		var pattern: Array = material.crystal_pattern("sample-" + str(run), "computer")
		assert_between(pattern.size(), 1, 3)
		counts[pattern.size()] += 1
		var corners := []
		for fracture: Dictionary in pattern:
			assert_false(corners.has(fracture.corner), "selected corners are unique")
			corners.append(fracture.corner)
			assert_between(fracture.paths.size(), 2, 4, "one main fracture and one to three branches")
			for path: PackedVector2Array in fracture.paths:
				for point: Vector2 in path:
					assert_true(Rect2(0, 0, 1.2, 1.2).has_point(point), "fractures stay in the corner region")
	assert_gt(counts[2], counts[1])
	assert_gt(counts[2], counts[3])
