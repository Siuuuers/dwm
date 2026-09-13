extends "res://addons/gut/test.gd"

const ART := preload("res://scripts/data/ArtManifest.gd")
const VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
const DATING := preload("res://scripts/ui/DatingScene.gd")
const HOSPITAL := preload("res://scripts/ui/HospitalScene.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")

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

func after_each() -> void:
	ART.reload_placements()

func _dating_art_fixture(enabled: bool) -> void:
	var catalog := {"schema_version": 1,
		"assets": {"fixture.portrait": {"path": "res://icon.svg", "size": [128, 128]}},
		"scenes": {"dating.solo.priscilla.day1.pre_challenge": {"background": "", "cg": "",
			"portraits": ["fixture.portrait"] if enabled else []}}}
	var file := FileAccess.open("user://dating-art-binding.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog))
	file.close()
	assert_true(ART.reload_placements("user://dating-art-binding.json"))

func _texture() -> Texture2D:
	var pixels := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	return ImageTexture.create_from_image(pixels)

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

func test_challenge_art_never_consumes_worksheet_space_and_empty_mapping_clears_old_images() -> void:
	var view := VIEW.new()
	add_child_autofree(view)
	var portrait := _texture()
	view.configure_textures(_texture(), [portrait, portrait], null, 150, true)
	assert_eq(view.size, Vector2(1280, 720))
	assert_eq(view._portraits[0].size.x, 160.0)
	assert_eq(view._portraits[1].position.x, 1120.0)
	view.configure_textures(null, [], _texture(), 125)
	assert_true(view.visible)
	assert_false(view._portraits[0].visible, "a full CG replaces portrait composition")
	view.configure_entry("not.a.registered.art.scene")
	assert_false(view.visible)
	assert_null(view._background.texture)
	assert_null(view._cg.texture)

func test_dating_mapping_uses_one_fixed_scene_for_all_phases_and_no_variants() -> void:
	var solo := {"kind": "solo", "day": 2, "participants": ["priscilla"]}
	assert_eq(DATING.scene_art_entry(solo), "dating.solo.priscilla.day2.pre_challenge")
	for kind: String in ["group", "twofriends_if_deferred"]:
		var context := {"kind": kind, "day": 6, "participants": ["priscilla", "lavinia"]}
		assert_eq(DATING.scene_art_entry(context), "dating.%s.priscilla_lavinia.day6.pre_challenge" % (
			"group" if kind == "group" else "twofriends"))
	assert_eq(DATING.scene_art_entry({"kind": "solo", "day": 2, "participants": ["angela"]}), "")

func test_actual_dating_host_mounts_art_in_the_visible_overlay_behind_unchanged_board() -> void:
	_dating_art_fixture(true)
	var scene: Control = load("res://scenes/dating/DatingScene.tscn").instantiate()
	var command := {"context": {"kind": "solo", "day": 1, "participants": ["priscilla"]}}
	assert_true(scene.configure_presentation(PhysicalPort.new(), command).ok)
	add_child_autofree(scene)
	await get_tree().process_frame
	var art: VIEW = scene._scene_art
	assert_eq(art.get_parent(), scene.challenge_overlay_host)
	assert_true(scene.challenge_overlay_host.visible)
	var original_board: Vector2 = scene.worksheet.custom_minimum_size
	# The board-view amendment adds a 48px zoom row below the original 492px field.
	assert_eq(original_board, Vector2(960, 540))
	assert_true(art.visible, "the imported fixture portrait is actually loaded")
	assert_eq(scene._challenge_content.offset_top, art.size.y)
	assert_gte(scene._status_label.get_parent().get_global_rect().position.y, art.get_global_rect().end.y)
	scene._physical_view.phase = "challenge"
	scene._refresh_challenge()
	assert_eq(scene._challenge_content.offset_top, 0.0, "challenge keeps the full original board field")
	art.configure_textures(_texture(), [_texture()], null, 100, true)
	assert_true(art.is_visible_in_tree(), "the retired DatingRoot cannot hide the active art")
	assert_lt(art.get_index(), scene.worksheet.get_parent().get_parent().get_index())
	assert_eq(scene.worksheet.custom_minimum_size, original_board)
	assert_eq(scene.get_presentation_projection(), command)
	_dating_art_fixture(false)
	scene._physical_view.phase = "pre_challenge"
	scene._refresh_challenge()
	assert_false(art.visible)
	assert_eq(scene._challenge_content.offset_top, 0.0, "no-art flow retains its original layout")
	assert_eq(scene.worksheet.custom_minimum_size, original_board, "art removal cannot resize the worksheet")

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
