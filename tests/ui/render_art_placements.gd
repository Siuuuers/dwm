extends SceneTree
## Synthetic optional-art placement evidence. It does not represent shipped artwork or gameplay.
const ART := preload("res://scripts/data/ArtManifest.gd")
const MENU := preload("res://scenes/menu/MenuScene.tscn")
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const MAIN := preload("res://scenes/main/MainGameScene.tscn")
const DATING := preload("res://scenes/dating/DatingScene.tscn")
const SCENE_ART := preload("res://scripts/ui/art/SceneArtView.gd")

class PhysicalPort extends RefCounted:
	func begin(_request: Dictionary) -> Dictionary:
		return {"ok": true}
	func complete(_request: Dictionary) -> Dictionary:
		return {"ok": true}
	func pull_physical(_command: Dictionary) -> Dictionary:
		var cells: Array = []
		for index: int in range(324):
			cells.append({"index": index, "face": "covered", "mark": "none", "number": 0,
				"bracketed": false, "inspectable": false, "pressable": false, "actions": []})
		return {"ok": true, "value": {"phase": "pre_challenge", "host": "canonical_solo",
			"board": {"width": 18, "height": 18, "revision": 0, "mine_estimate": null,
				"terminal": false, "custody": true, "cells": cells},
			"special_mine_visible": false, "special_mine_enabled": false}}

var _viewport: SubViewport
var _folder := ""
var _failures: Array[String] = []
var _captures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/art_placements")
	if DirAccess.make_dir_recursive_absolute(_folder) != OK:
		_fail("cannot create evidence directory")
		_finish()
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_install_overrides()

	var menu := MENU.instantiate()
	await _show_and_capture(menu, "01-title.png")

	var desktop := DESKTOP.instantiate()
	desktop.position = Vector2(480, 0)
	desktop.size = Vector2(800, 720)
	var desktop_field := ColorRect.new()
	desktop_field.color = Color("151b25")
	desktop_field.size = Vector2(1280, 720)
	desktop_field.add_child(desktop)
	await _show_and_capture(desktop_field, "02-desktop-launchers.png")

	var shell := MAIN.instantiate()
	await _show_and_capture(shell, "03-shell-layers.png")

	var background := ART.get_texture("evidence.scene.background")
	var left := ART.get_texture("evidence.scene.left")
	var right := ART.get_texture("evidence.scene.right")
	var cg := ART.get_texture("evidence.scene.cg")
	var dating := DATING.instantiate()
	var command := {"context": {"kind": "solo", "day": 1, "participants": ["priscilla"]}}
	var configured: Dictionary = dating.configure_presentation(PhysicalPort.new(), command)
	if not configured.get("ok", false):
		_fail("real DatingScene fixture rejected")
	else:
		await _show_and_capture(dating, "04-dating-pre-challenge.png")

	var solo := SCENE_ART.new()
	solo.configure_textures(background, [left], null, 100)
	await _show_and_capture(solo, "05-scene-solo.png")
	var pair := SCENE_ART.new()
	pair.configure_textures(background, [left, right], null, 100)
	await _show_and_capture(pair, "06-scene-pair.png")
	var ending := SCENE_ART.new()
	ending.configure_textures(null, [], cg, 100)
	await _show_and_capture(ending, "07-scene-cg.png")

	var boundary := Control.new()
	boundary.size = Vector2(1280, 720)
	var lower := ColorRect.new()
	lower.position = Vector2(0, 328)
	lower.size = Vector2(1280, 392)
	lower.color = Color("151b25")
	boundary.add_child(lower)
	var scaled := SCENE_ART.new()
	scaled.configure_textures(background, [left, right], null, 150)
	boundary.add_child(scaled)
	await _show_and_capture(boundary, "08-scene-pair-150-caption-boundary.png")

	ART.reload_placements()
	_finish()

func _install_overrides() -> void:
	_place("ui.title", "ui-960x656.svg", Vector2i(960, 656))
	_place("ui.desktop", "ui-800x656.svg", Vector2i(800, 656))
	for id: String in ["minesweeper", "contacts", "schedule", "shop", "backup", "settings", "logout"]:
		_place("launcher." + id, "ui-48.svg", Vector2i(48, 48))
	for id: String in ["shell.background", "shell.character.angela", "shell.keepsakes"]:
		_place(id, "ui-480x504.svg", Vector2i(480, 504))
	_place("background.dating.solo.priscilla_day1", "placement-background.svg", Vector2i(1280, 448))
	_place("character.priscilla", "placement-portrait-left.svg", Vector2i(320, 448))
	_place("evidence.scene.background", "placement-background.svg", Vector2i(1280, 448))
	_place("evidence.scene.left", "placement-portrait-left.svg", Vector2i(320, 448))
	_place("evidence.scene.right", "placement-portrait-right.svg", Vector2i(320, 448))
	_place("evidence.scene.cg", "placement-cg.svg", Vector2i(1280, 448))

func _place(id: String, file: String, size: Vector2i) -> void:
	ART.set_overlay_info("", id, "res://tests/fixtures/art/" + file, size, "evidence")

func _show_and_capture(node: Control, file_name: String) -> void:
	_viewport.add_child(node)
	if node.anchor_right == 1.0 and node.anchor_bottom == 1.0:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	elif node.size == Vector2.ZERO:
		node.size = Vector2(1280, 720)
	await process_frame
	_reveal_desktops(node)
	for frame in 3:
		await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		_fail("capture unavailable: " + file_name)
	elif image.save_png(_folder.path_join(file_name)) != OK:
		_fail("PNG write failed: " + file_name)
	else:
		_captures += 1
	_viewport.remove_child(node)
	node.queue_free()
	await process_frame

func _reveal_desktops(node: Node) -> void:
	var desktops: Array[Node] = node.find_children("*", "ComputerDesktop", true, false)
	if node is ComputerDesktop:
		desktops.push_front(node)
	for desktop: Node in desktops:
		desktop.show()
		desktop.icon_grid.show()
		desktop.app_window_host.hide()
		if desktop.status_label != null:
			desktop.status_label.hide()

func _fail(message: String) -> void:
	_failures.append(message)
	push_error("ART_PLACEMENT_RENDER_FAILED: " + message)

func _finish() -> void:
	print("ART_PLACEMENT_RENDER_", "VERIFIED" if _failures.is_empty() else "FAILED",
		" captures=", _captures, " evidence=", _folder)
	quit(0 if _failures.is_empty() and _captures == 8 else 1)