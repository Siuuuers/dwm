extends GutTest

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

func test_paper_detail_stays_on_launcher_while_frame_accents_remain_over_apps() -> void:
	state.inventory = {"letter_with_wax_seal": 1}
	state.inventory_changed.emit()
	assert_true(desktop.cosmetic_overlay.visible)
	desktop._active_id = &"shop"
	desktop._refresh_launcher(false)
	assert_false(desktop.cosmetic_overlay.visible, "paper never overlays app content")
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
