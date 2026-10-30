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

func test_legacy_inventory_does_not_restore_decorations_or_change_focus() -> void:
	var before: Rect2 = desktop.icon_grid.get_global_rect()
	desktop.launcher_buttons[&"contacts"].grab_focus()
	var focused: Control = get_viewport().gui_get_focus_owner()
	state.inventory = {"crystal_stutters": 1, "inked_silk_string": 1, "letter_with_wax_seal": 1}
	state.inventory_changed.emit()
	assert_null(desktop.find_child("CosmeticOverlay", true, false))
	assert_eq(desktop.icon_grid.get_global_rect(), before)
	assert_same(get_viewport().gui_get_focus_owner(), focused)
	var owned: Dictionary = state.inventory.duplicate(true)
	desktop.size = Vector2(928, 720)
	await get_tree().process_frame
	assert_null(desktop.find_child("CosmeticOverlay", true, false))
	assert_eq(state.inventory, owned)

func test_legacy_inventory_leaves_art_and_controls_plain() -> void:
	var art := preload("res://scripts/ui/art/SceneArtView.gd").new()
	add_child_autofree(art)
	var texture := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	art.configure_textures(texture, [])
	var rail := RAIL.new()
	add_child_autofree(rail)
	assert_true(rail.configure_presentation(preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd").build("en", 150, "AfterHours"), "en", 150))
	var buttons: Array = rail._buttons.values()
	var normal: StyleBox = buttons[0].get_theme_stylebox("normal")
	buttons[0]._candidate = {"retirement_probe": true}
	state.inventory = {"crystal_stutters": 1, "inked_silk_string": 1, "letter_with_wax_seal": 1}
	state.inventory_changed.emit()
	assert_null(art.find_child("CrystalSurface", true, false))
	assert_eq(buttons.size(), 7)
	assert_same(buttons[0].get_theme_stylebox("normal"), normal)
	assert_true(normal is StyleBoxFlat)
	assert_eq(buttons[0].get_theme_stylebox("disabled").border_width_bottom, 4)
	assert_eq(buttons[0]._candidate, {"retirement_probe": true})
	assert_eq(rail._buttons.values(), buttons)
