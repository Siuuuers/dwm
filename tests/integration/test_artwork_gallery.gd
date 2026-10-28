extends GutTest

const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const ARTWORK := preload("res://scripts/ui/gallery/ArtworkGallery.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const ART := preload("res://scripts/data/ArtManifest.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const SCENE_ART := preload("res://scripts/ui/art/SceneArtView.gd")

class InputLeakProbe extends Node:
	var escapes := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			escapes += 1

func _profile(storage: RefCounted) -> Node:
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(storage).get("ok", false))
	# Existing line-history owner; registration is not itself an unlock.
	var lines: Array = []
	for day: int in range(1, 5): lines.append({"line_id": "line.Day%d.one" % day})
	assert_true(profile.configure_line_registry({"reply_lines": lines}).get("ok", false))
	return profile

func test_unlock_projection_persists_without_gallery_writes() -> void:
	var storage := STORAGE.new("artwork-gallery.memory", FILES.new())
	var profile := _profile(storage)
	for id: String in ARTWORK.UNLOCK_LINES: assert_false(ARTWORK.unlocked(profile, id))
	assert_true(profile.mark_line_visited("line.Day1.one").get("ok", false))
	assert_true(ARTWORK.unlocked(profile, "picture1"))
	assert_true(ARTWORK.unlocked(profile, "picture2"))
	assert_false(ARTWORK.unlocked(profile, "picture3"))
	assert_false(ARTWORK.unlocked(profile, "picture4"))
	assert_false(ARTWORK.unlocked(profile, "picture5"))
	assert_true(profile.mark_line_visited("line.Day2.one").get("ok", false))
	assert_true(ARTWORK.unlocked(profile, "picture4"))
	assert_false(ARTWORK.unlocked(profile, "picture5"))
	assert_true(profile.mark_line_visited("line.Day3.one").get("ok", false))
	assert_true(ARTWORK.unlocked(profile, "picture5"))
	assert_false(ARTWORK.unlocked(profile, "picture3"))
	assert_true(profile.mark_line_visited("line.Day4.one").get("ok", false))
	var reopened := _profile(storage)
	var before: Dictionary = reopened.get_profile_snapshot()
	for id: String in ARTWORK.UNLOCK_LINES: assert_true(ARTWORK.unlocked(reopened, id))
	var artwork := ARTWORK.new()
	artwork.configure(reopened)
	add_child_autofree(artwork)
	artwork.refresh()
	artwork.select_picture("picture3")
	assert_eq(reopened.get_profile_snapshot(), before)

func test_gallery_preview_modal_keys_and_return_focus() -> void:
	ART.reload_placements()
	# GUT's diagnostic CanvasLayer (128) otherwise covers the artwork viewer (100).
	var gut_gui := get_tree().root.get_node_or_null("GutRunner/GutLayer/GutScene") as CanvasItem
	if gut_gui != null: gut_gui.hide()
	var probe := InputLeakProbe.new()
	add_child_autofree(probe)
	var profile := _profile(STORAGE.new("artwork-viewer.memory", FILES.new()))
	assert_true(profile.mark_line_visited("line.Day1.one").get("ok", false))
	var before: Dictionary = profile.get_profile_snapshot()
	var home := Button.new()
	add_child_autofree(home)
	var gallery: Control = GALLERY.instantiate()
	assert_true(gallery.configure_title_host(home, null, profile).get("ok", false))
	add_child_autofree(gallery)
	gallery.open_in_title_host()
	gallery._show_gallery_tab("artwork")
	# Both mounting and opening schedule entry focus; settle those before selecting preview.
	await get_tree().process_frame
	var artwork: Control = gallery._artwork
	assert_eq(artwork._rows.size(), 5)
	assert_true(artwork._rows[2].disabled)
	artwork.select_picture("picture1")
	assert_not_null(artwork._preview.texture_normal)
	artwork._preview.grab_focus()
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci/art-media"))
		await RenderingServer.frame_post_draw
		var preview_image: Image = get_viewport().get_texture().get_image()
		assert_eq(preview_image.save_png("res://.godot/ci/art-media/artwork-gallery-list.png"), OK)
	assert_true(artwork._preview.has_focus(), "preview owns focus before opening viewer")
	artwork._preview.pressed.emit()
	assert_true(artwork.viewer_is_open())
	assert_false(home.visible)
	assert_eq(artwork._hints.text, "H — Hide · Esc — Exit")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		assert_eq(image.save_png("res://.godot/ci/art-media/artwork-gallery-viewer.png"), OK)
	var hide_key := InputEventKey.new()
	hide_key.keycode = KEY_H
	hide_key.pressed = true
	Input.parse_input_event(hide_key)
	await get_tree().process_frame
	assert_false(artwork._hints.visible)
	Input.parse_input_event(hide_key)
	await get_tree().process_frame
	assert_true(artwork._hints.visible)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await get_tree().process_frame
	assert_false(artwork.viewer_is_open())
	assert_true(home.visible)
	assert_true(artwork._preview.has_focus())
	assert_true(gallery.visible)
	assert_eq(probe.escapes, 0, "viewer owns Esc before title/unhandled navigation")
	assert_eq(profile.get_profile_snapshot(), before)
	ART.reload_placements()

func test_seven_day_art_assets_and_split_placement() -> void:
	assert_true(ART.reload_placements())
	for index: int in range(1, 6):
		var id := "picture%d" % index
		assert_eq(ART.get_asset_path(id), "res://art/pictures/%s.jpg" % id)
		assert_not_null(ART.get_texture(id), "imported authored picture must load: " + id)
	var view := SCENE_ART.new()
	view.bind_view_preferences(null)
	add_child_autofree(view)
	for day: int in range(1, 8):
		var entry := "Day%d" % day
		assert_true(ART.uses_split_panels(entry))
		var placement: Dictionary = ART.get_scene_art(entry)
		assert_eq(placement.portraits, ["picture1"])
		assert_eq(placement.background, "picture2" if day < 4 else "picture3")
		view.configure_entry(entry, 100, false, false, true)
		assert_not_null(view.get_split_handle(), "scene caption path must expose two panels")
		assert_eq(view._portraits[0].texture, ART.get_texture("picture1"))
		assert_eq(view._background.texture, ART.get_texture(placement.background))
		assert_gt(view.get_right_rect().position.x, 0.0)
		assert_gt(view.get_right_rect().size.x, 0.0)

func test_canonical_locales_refresh_artwork_tabs_preview_and_open_viewer_without_writes() -> void:
	ART.reload_placements()
	var profile := _profile(STORAGE.new("artwork-locales.memory", FILES.new()))
	assert_true(profile.mark_line_visited("line.Day1.one").get("ok", false))
	var localization := LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(profile).get("ok", false))
	var home := Button.new()
	add_child_autofree(home)
	var gallery: Control = GALLERY.instantiate()
	assert_true(gallery.configure_title_host(home, localization, profile).get("ok", false))
	add_child_autofree(gallery)
	gallery.open_in_title_host()
	gallery._show_gallery_tab("artwork")
	await get_tree().process_frame
	var artwork: Control = gallery._artwork
	artwork.select_picture("picture1")
	artwork.open_viewer()
	assert_true(artwork.viewer_is_open())
	artwork._hints.hide()
	for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
		assert_true(localization.set_locale(locale).get("ok", false))
		await get_tree().process_frame
		var before: Dictionary = profile.get_profile_snapshot()
		artwork.refresh()
		var title: String = localization.t("gallery.artwork.title", {"number": "1"})
		assert_eq(artwork._rows[0].text, title)
		assert_eq(artwork._rows[2].text, localization.t("gallery.artwork.locked"))
		assert_eq(artwork._rows[2].accessibility_name, localization.t("gallery.artwork.locked_accessible"))
		assert_eq(artwork._preview.accessibility_name, localization.t("gallery.artwork.view", {"title": title}))
		assert_eq(artwork._caption.text, localization.t("gallery.artwork.open", {"title": title}))
		assert_eq(artwork._hints.text, localization.t("gallery.artwork.hints"))
		assert_false(artwork._hints.visible, "locale refresh preserves the player's hidden hints")
		assert_true(artwork.viewer_is_open(), "locale refresh does not dismiss the artwork")
		assert_eq(artwork._selected, "picture1")
		var tabs: Array[Node] = gallery._gallery_tabs.get_children()
		assert_eq(tabs[0].text, localization.t("gallery.tab.records"))
		assert_eq(tabs[1].text, localization.t("gallery.tab.artwork"))
		assert_eq(profile.get_profile_snapshot(), before, "Gallery locale projection writes no unlock or preference state")
	artwork.close_viewer()
