extends RefCounted
## Only Bootstrap, board commands and cached app views are injected.
## The mounted desktop scene, launcher controls and DesktopAppHostState are real.
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")

class IsolatedDesktop extends "res://scripts/ui/ComputerDesktop.gd":
	func _configure_from_bootstrap() -> void: pass

class AppView extends Control:
	var modal := false
	var preflight_ok := true
	var remembered := 0
	func can_return_home() -> bool: return not modal
	func prepare_show_window() -> Dictionary: return {"ok": preflight_ok, "code": &"fixture_preflight_refused"}
	func prepare_return_home() -> Dictionary: return {"ok": preflight_ok, "code": &"fixture_preflight_refused"}
	func configure_desktop_home(_button: Button) -> void: pass
	func refresh_view() -> Dictionary: return {"ok": true}
	func show_window() -> void: show()
	func remember_focus() -> void: remembered += 1

var phase: StringName = &"NONE"
var commands: Array[Dictionary] = []
var fail_dispatch := false
var preparations := 0

func read_phase() -> StringName: return phase

func dispatch(command: Dictionary) -> Dictionary:
	commands.append(command.duplicate(true))
	return {"ok": not fail_dispatch}

func prepare_app(_id: StringName, _app: Control) -> Dictionary:
	# Deliberately no fake success for unconverted production app setup.
	preparations += 1
	return {"ok": false, "code": &"scene_app_preparation_unavailable"}

func make_desktop() -> Control:
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	return desktop

func install_cached_view(desktop: Control, id: StringName) -> Control:
	var app := AppView.new()
	app.hide()
	desktop.app_window_host.add_child(app)
	desktop._cached_app_windows[id] = app
	return app
