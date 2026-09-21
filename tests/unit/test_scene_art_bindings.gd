extends "res://addons/gut/test.gd"

const ART := preload("res://scripts/data/ArtManifest.gd")
const VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
const DATING := preload("res://scripts/ui/DatingScene.gd")
const HOSPITAL := preload("res://scripts/ui/HospitalScene.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const PANEL_SPLIT := preload("res://scripts/ui/desktop/DesktopPanelSplit.gd")

var _dating_width_before := 480.0

class PhysicalPort extends RefCounted:
	var notice_acks := 0
	func begin(_request: Dictionary) -> Dictionary: return {"ok": true}
	func complete(_request: Dictionary) -> Dictionary: return {"ok": true}
	func acknowledge_notice(_command: Dictionary) -> Dictionary:
		notice_acks += 1
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

func before_each() -> void:
	_dating_width_before = VIEW._dating_width
	VIEW._dating_width = 480.0

func after_each() -> void:
	ART.reload_placements()
	VIEW._dating_width = _dating_width_before

func _dating_art_fixture(enabled: bool) -> void:
	var catalog := {"schema_version": 1,
		"assets": {"fixture.portrait": {"path": "res://icon.svg", "size": [128, 128]}},
		"scenes": {"dating.solo.priscilla.day1.pre_challenge": {"background": "", "cg": "",
			"portraits": ["fixture.portrait"] if enabled else []}}}
	var file := FileAccess.open("user://dating-art-binding.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog))
	file.close()
	assert_true(ART.reload_placements("user://dating-art-binding.json"))

func _texture(transparent: bool = false) -> Texture2D:
	var pixels := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	if transparent: pixels.set_pixel(0, 0, Color.TRANSPARENT)
	return ImageTexture.create_from_image(pixels)

func _settle_layout() -> void:
	for frame: int in range(6):
		await get_tree().process_frame

func test_art_is_inert_and_clipped_above_each_caption_aperture() -> void:
	var view := VIEW.new()
	add_child_autofree(view)
	for percent: int in [100, 125, 150]:
		view.configure_textures(_texture(), [_texture(), _texture()], null, percent)
		assert_eq(view.size, Vector2(1280, VIEW.APERTURE_HEIGHT[percent]))
		assert_true(view.clip_contents)
		for control: Control in [view, view._background, view._portraits[0], view._portraits[1], view._cg]:
			assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
			assert_eq(control.focus_mode, Control.FOCUS_NONE)
		assert_eq(view._portraits[1].position.x, 640.0)
	view.configure_textures(null, [_texture()], null)
	assert_eq(view._portraits[0].position.x, 320.0)
	assert_false(view._portraits[1].visible)

func test_challenge_retains_left_portraits_and_empty_mapping_clears_old_images() -> void:
	var view := VIEW.new()
	add_child_autofree(view)
	var portrait := _texture()
	view.configure_textures(_texture(), [portrait, portrait], null, 150, true)
	await _settle_layout()
	assert_eq(view.size, Vector2(1280, 720))
	assert_eq(view.get_right_rect(), Rect2(480, 0, 800, 720))
	assert_eq(view._portraits[0].size.y, 720.0)
	assert_eq(view._portraits[1].size.y, 720.0)
	assert_true(view._portrait_panel.get_global_rect().encloses(view._portrait_slots[1].get_global_rect()))
	view.configure_textures(null, [portrait], _texture(), 125, false, true)
	assert_true(view.visible)
	assert_false(view._portraits[0].visible, "a full CG replaces portrait composition")
	assert_eq(view.get_right_rect(), Rect2(0, 0, 1280, 656))
	assert_eq(view._cg.size, Vector2(1280, 656))
	assert_null(view.get_split_handle())
	view.configure_textures(_texture(), [], null, 125, false, true)
	assert_true(view.visible, "a portrait-free location remains visible at full width")
	assert_eq(view._background.size, Vector2(1280, 656))
	assert_eq(view.get_right_rect(), Rect2(0, 0, 1280, 656))
	assert_null(view.get_split_handle())
	view.configure_entry("not.a.registered.art.scene")
	assert_false(view.visible)
	assert_null(view._background.texture)
	assert_null(view._cg.texture)

func test_dating_solo_crop_stays_centered_at_fixed_height_with_shared_background() -> void:
	var view := VIEW.new()
	add_child_autofree(view)
	var background := _texture()
	view.configure_textures(background, [_texture(true)], null, 150, false, true)
	for width: float in [320.0, 480.0, 640.0]:
		view.set_portrait_width(width)
		await _settle_layout()
		var portrait: Rect2 = view._portraits[0].get_global_rect()
		var panel: Rect2 = view._portrait_panel.get_global_rect()
		assert_eq(portrait.size, Vector2(656, 656), "resizing crops the image without zooming it")
		assert_almost_eq(portrait.get_center().x, panel.get_center().x, 0.01)
		assert_almost_eq(panel.position.x - portrait.position.x, portrait.end.x - panel.end.x, 0.01)
		assert_eq(view._background.texture, background)
		assert_eq(view._portrait_background.texture, background)
		assert_eq(view._portrait_background.size.y, 656.0)
		assert_eq(view.get_right_rect(), Rect2(width, 0, 1280 - width, 656))
		assert_eq(view._scene_panel.get_global_rect().position.x, panel.end.x)
		assert_true(view._portrait_panel.clip_contents)
		assert_eq(view._portraits[0].mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(view.get_split_handle().focus_mode, Control.FOCUS_ALL)
	view.set_portrait_width(1)
	assert_eq(view.get_portrait_width(), 320.0)
	view.set_portrait_width(1000)
	assert_eq(view.get_portrait_width(), 640.0)

func test_two_portraits_keep_equal_centers_and_overlap_only_for_transparent_art() -> void:
	var view := VIEW.new()
	add_child_autofree(view)
	var left := _texture(true)
	var right := _texture(true)
	for opaque: bool in [false, true]:
		view.configure_textures(_texture(), [left, _texture() if opaque else right], null, 100, false, true)
		for width: float in [320.0, 640.0]:
			view.set_portrait_width(width)
			await _settle_layout()
			var panel: Rect2 = view._portrait_panel.get_global_rect()
			for index: int in range(2):
				var portrait: Rect2 = view._portraits[index].get_global_rect()
				assert_almost_eq(portrait.get_center().x - panel.position.x, width * (0.25 + index * 0.5), 0.01)
				assert_eq(portrait.size, Vector2(656, 656))
				assert_eq(view._portrait_slots[index].clip_contents, opaque)
				if opaque:
					assert_eq(view._portrait_slots[index].size.x, width / 2.0)
					assert_eq(view._portrait_slots[index].position.x, index * width / 2.0)
			assert_eq(view._portraits[0].texture, left, "resizing keeps participant order")
			assert_true(view._portraits[0].get_global_rect().intersects(view._portraits[1].get_global_rect()))
	view.set_portrait_width(321)
	assert_eq(view.get_portrait_width(), 320.0)
	view.set_portrait_width(325)
	assert_eq(view.get_portrait_width(), 324.0, "four-pixel steps give each portrait a symmetric two-pixel slot change")

func test_dating_width_survives_host_changes_without_changing_desktop_width() -> void:
	var dialogue := VIEW.new()
	add_child_autofree(dialogue)
	dialogue.configure_textures(_texture(), [_texture()], null, 100, false, true)
	dialogue.set_portrait_width(640)
	var challenge := VIEW.new()
	add_child_autofree(challenge)
	challenge.configure_textures(_texture(), [_texture()], null, 100, true)
	assert_eq(challenge.get_right_rect(), Rect2(640, 0, 640, 720))
	var desktop := PANEL_SPLIT.new()
	add_child_autofree(desktop)
	assert_eq(desktop.get_angela_width(), 480.0)
	desktop.set_angela_width(640)
	assert_eq(desktop.get_angela_width(), 480.0, "the desktop retains its original maximum")
	desktop.set_angela_width(320)
	assert_eq(challenge.get_portrait_width(), 640.0, "desktop adjustments do not change dating")
	challenge.set_portrait_width(400)
	dialogue.configure_textures(_texture(), [_texture()], null, 100, false, true)
	assert_eq(dialogue.get_portrait_width(), 400.0, "returning dialogue uses the latest dating width")
	assert_eq(desktop.get_angela_width(), 320.0)
	assert_eq(desktop.minimum_second_width, 800.0)

func test_dating_mapping_uses_one_fixed_scene_for_all_phases_and_no_variants() -> void:
	var solo := {"kind": "solo", "day": 2, "participants": ["priscilla"]}
	assert_eq(DATING.scene_art_entry(solo), "dating.solo.priscilla.day2.pre_challenge")
	for kind: String in ["group", "twofriends_if_deferred"]:
		var context := {"kind": kind, "day": 6, "participants": ["priscilla", "lavinia"]}
		assert_eq(DATING.scene_art_entry(context), "dating.%s.priscilla_lavinia.day6.pre_challenge" % (
			"group" if kind == "group" else "twofriends"))
	assert_eq(DATING.scene_art_entry({"kind": "solo", "day": 2, "participants": ["angela"]}), "")

func test_actual_dating_host_keeps_art_left_and_fits_board_in_right_panel() -> void:
	_dating_art_fixture(true)
	var scene: Control = load("res://scenes/dating/DatingScene.tscn").instantiate()
	var command := {"context": {"kind": "solo", "day": 1, "participants": ["priscilla"]}}
	assert_true(scene.configure_presentation(PhysicalPort.new(), command).ok)
	add_child_autofree(scene)
	await _settle_layout()
	var art: VIEW = scene._scene_art
	assert_eq(art.get_parent(), scene.challenge_overlay_host)
	assert_true(scene.challenge_overlay_host.visible)
	assert_true(art.visible, "the imported fixture portrait is actually loaded")
	assert_eq(art.size, Vector2(1280, 720))
	assert_eq(Rect2(scene._challenge_content.position, scene._challenge_content.size), art.get_right_rect())
	scene._physical_view.phase = "challenge"
	scene._refresh_challenge()
	for width: float in [320.0, 640.0]:
		art.set_portrait_width(width)
		await _settle_layout()
		var content: Rect2 = scene._challenge_content.get_global_rect()
		var worksheet: Rect2 = scene.worksheet.get_global_rect()
		assert_eq(Rect2(scene._challenge_content.position, scene._challenge_content.size), art.get_right_rect())
		assert_gte(worksheet.position.x, content.position.x)
		assert_lte(worksheet.end.x, content.end.x)
		assert_true(art.is_visible_in_tree(), "the challenge retains its portrait panel")
		assert_eq(art._portraits[0].size.y, 720.0)
	assert_lt(art.get_index(), scene._challenge_content.get_index())
	assert_eq(scene.get_presentation_projection(), command)
	_dating_art_fixture(false)
	scene._physical_view.phase = "pre_challenge"
	scene._refresh_challenge()
	await _settle_layout()
	assert_false(art.visible)
	assert_eq(Rect2(scene._challenge_content.position, scene._challenge_content.size), Rect2(0, 0, 1280, 720),
		"a portrait-free challenge uses the whole stage")

func test_ordinary_hospital_scene_shows_readable_notice_and_acknowledges_once() -> void:
	var port := PhysicalPort.new()
	var scene: Control = load("res://scenes/hospital/HospitalScene.tscn").instantiate()
	var command := {"context": {"kind": "hospital", "day": 2, "source_entry_ids": [], "miss_receipt_ids": []}}
	assert_true(scene.configure_presentation(port, command).ok)
	add_child_autofree(scene)
	await get_tree().process_frame
	assert_true(scene._notice_panel.visible)
	assert_false(scene._message_label.text.strip_edges().is_empty())
	assert_gte(scene._continue_button.custom_minimum_size.y, 48.0)
	scene._continue_button.pressed.emit()
	assert_eq(port.notice_acks, 1)
	assert_true(scene._continue_button.disabled)


func test_hospital_requires_this_days_exact_saved_witness_sources() -> void:
	var context := {"kind": "hospital", "day": 2, "source_entry_ids": ["accepted.2"], "miss_receipt_ids": ["miss.2"]}
	var witness := {"kind": "sylvia_hospital_witness", "resolution_kind": "condition_hospital",
		"care_followup_day": 3, "source_receipt_id": "accepted.2", "hospital_miss_receipt_id": "miss.2"}
	var contacts := {"sylvia_hospital_witness_receipts": {"witness.2": witness}}
	var before := contacts.duplicate(true)
	assert_eq(HOSPITAL.art_participants(contacts, context), ["sylvia"])
	context.day = 3
	assert_eq(HOSPITAL.art_participants(contacts, context), [])
	context.day = 2
	context.miss_receipt_ids = ["miss.other"]
	assert_eq(HOSPITAL.art_participants(contacts, context), [])
	context.miss_receipt_ids = ["miss.2"]
	context.source_entry_ids = ["accepted.other"]
	assert_eq(HOSPITAL.art_participants(contacts, context), [])
	assert_eq(contacts, before)
	witness.resolution_kind = "schedule_done"
	witness.schedule_entry_id = "schedule.2"
	context.source_entry_ids = ["schedule.2"]
	assert_eq(HOSPITAL.art_participants(contacts, context), ["sylvia"])
	assert_eq(HOSPITAL.art_participants({}, context), [])

func test_bridge_projects_only_retained_entry_and_style_mounts_art_below_captions() -> void:
	var bridge: Node = autofree(BRIDGE.new())
	assert_eq(bridge.get_current_scene_art(), {"entry_id": "", "show_portraits": false})
	bridge._active_entry = {"entry_id": "dating.solo.priscilla.day1.pre_challenge", "frozen_context": {}}
	var retained: Dictionary = bridge._active_entry.duplicate(true)
	assert_eq(bridge.get_current_scene_art().entry_id, retained.entry_id)
	assert_eq(bridge._active_entry, retained)
	bridge._active_entry = {"entry_id": "hospital.faint.day2", "frozen_context": {}}
	assert_false(bridge.get_current_scene_art().show_portraits, "semantic Hospital cannot infer Sylvia")
	bridge._active_entry.clear()
	bridge._ordinary_playback = {"timeline_id": "hospital.faint", "context": {"kind": "hospital", "day": 2}}
	assert_eq(bridge.get_current_scene_art(), {"entry_id": "hospital.faint.day2", "show_portraits": false})
	bridge._ordinary_playback.clear()
	bridge._current_timeline_id = "hospital.faint"
	assert_eq(bridge.get_current_scene_art().entry_id, "", "old cache is not a live art owner")
	var style: Resource = load("res://dialogic/styles/witnessed_caption_style.tres")
	assert_lt(style.layer_list.find("12"), style.layer_list.find("13"))
	assert_eq(style.layer_info["12"].scene.resource_path, "res://scenes/ui/witnessed/WitnessedArtLayer.tscn")
