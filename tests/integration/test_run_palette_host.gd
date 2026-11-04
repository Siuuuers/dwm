extends GutTest
## Host palette and readiness contracts use an explicit configuration owner.
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const GAME_STATE := preload("res://autoload/GameState.gd")

class IsolatedDesktop extends ComputerDesktop:
	func _configure_from_bootstrap() -> void: pass
class ConfigurationFixture extends RefCounted:
	var answer: Dictionary = {"ok":true,"value":{"dark_mode":true}}
	func get_run_configuration() -> Dictionary: return answer.duplicate(true)

func _settle() -> void:
	for frame in 6: await get_tree().process_frame

func test_malformed_unavailable_replacement_and_changed_capture_are_refused_atomically() -> void:
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	add_child_autofree(desktop)
	var placeholder := GAME_STATE.new()
	autofree(placeholder)
	placeholder.reset_game()
	assert_false(desktop.configure_run_configuration(placeholder).ok)
	var owner := ConfigurationFixture.new()
	owner.answer.value.dark_mode = 1
	assert_false(desktop.configure_run_configuration(owner).ok)
	assert_false(desktop._run_configuration_ready)
	owner.answer.value.dark_mode = true
	assert_true(desktop.configure_run_configuration(owner).ok)
	var current: Theme = desktop.theme
	assert_false(desktop.configure_run_configuration(ConfigurationFixture.new()).ok)
	owner.answer.value.dark_mode = false
	assert_false(desktop.configure_run_configuration(owner).ok)
	assert_same(desktop.theme,current)
	assert_eq(desktop._run_palette,&"midnight")


class StartupFixture extends Node:
	signal application_ready()
	var available := false
	var configured_hosts := 0
	func get_startup_state() -> Dictionary: return {"ready":available}
	func configure_contacts_desktop(_desktop: Control) -> Dictionary:
		configured_hosts += 1
		return {"ok":true}

class InertQuickFixture extends Node:
	func observe_input(_event: InputEvent) -> void: pass
	func handle_input(_event: InputEvent) -> bool: return false

class EarlyDesktop extends ComputerDesktop:
	var startup: Node
	func _configure_from_bootstrap() -> void:
		_bootstrap = startup
		super._configure_from_bootstrap()

func test_early_production_bootstrap_path_stays_hidden_until_captured_palette_is_admitted() -> void:
	var startup := StartupFixture.new()
	add_child_autofree(startup)
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(EarlyDesktop)
	desktop.startup = startup
	assert_true(desktop.configure_run_configuration(ConfigurationFixture.new()).ok)
	# This test isolates only unrelated Backup/Quick initialization while running
	# the production readiness/captured-owner/masking method itself.
	desktop._backup_port = RefCounted.new()
	var quick := InertQuickFixture.new()
	add_child_autofree(quick)
	desktop._quick_commands = quick
	startup.application_ready.connect(desktop._configure_from_bootstrap)
	add_child_autofree(desktop)
	assert_false(desktop.visible,"The early production mount is masked synchronously before its first frame")
	assert_true(desktop._run_configuration_masked)
	assert_eq(startup.configured_hosts,0)
	assert_false(desktop.open_app(&"shop").ok,"No route may be admitted during readiness masking")
	await _settle()
	assert_false(desktop.is_visible_in_tree())
	startup.available = true
	startup.application_ready.emit()
	assert_true(desktop.visible)
	assert_false(desktop._run_configuration_masked)
	assert_eq(desktop.theme.get_color("face","Desktop"),Color("14201d"))
	assert_eq(desktop.theme.get_color("habitat","Desktop"),Color("0d1514"))
	assert_eq(startup.configured_hosts,1)
	assert_true(desktop._cached_app_windows.is_empty())
	await _settle()
	assert_same(desktop.get_viewport().gui_get_focus_owner(), desktop.launcher_buttons[&"minesweeper"], "Delayed readiness gives the visible launcher its initial native focus")
