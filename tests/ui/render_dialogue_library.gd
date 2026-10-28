extends GutTest
const FIXTURE := preload("res://tests/support/DialogueLibraryFixture.gd")
const CATALOGUE := preload("res://scripts/narrative/DialogueLibraryCatalogue.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")

func after_each() -> void:
	assert_true(CATALOGUE.configure([], [], {}).ok)

func test_rendered_gallery_keeps_unread_shape_fixed_and_browsing_read_only() -> void:
	assert_ne(DisplayServer.get_name(), "headless", "real renderer required")
	if DisplayServer.get_name() == "headless": return
	assert_true(FIXTURE.install().ok)
	var files := FILES.new()
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(STORAGE.new("TEST.library.render", files)).ok)
	var localization: Node = autofree(LOCALIZATION.new())
	assert_true(localization.initialize(profile).ok)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var home := Button.new()
	home.text = "Return"
	home.position = Vector2(16, 16)
	home.size = Vector2(160, 48)
	viewport.add_child(home)
	var gallery: Control = GALLERY.instantiate()
	assert_true(gallery.configure_title_host(home, localization, profile).ok)
	viewport.add_child(gallery)
	gallery.open_in_title_host()
	gallery._show_gallery_tab("dialogue")
	await _settle()
	var library: Control = gallery._dialogue
	assert_eq(library._rows.size(), 0)
	assert_true(library._empty.visible)
	assert_false(library._scroll.visible)
	assert_not_null(viewport.gui_get_focus_owner(), "empty library retains reachable navigation")
	_assert_hidden(gallery)
	var beat := FIXTURE.beat()
	assert_true(profile.mark_caption_variant_witnessed(beat, FIXTURE.registry(beat), FIXTURE.CHECKPOINT).ok)
	await _settle()
	assert_eq(library._rows.size(), 1)
	assert_eq(library._rows[0].text, "TEST reached passage")
	assert_false(library._empty.visible)
	assert_true(library._scroll.visible)
	assert_true(library.focus_first())
	assert_same(viewport.gui_get_focus_owner(), library._rows[0])
	assert_eq(library._rows[0].get_node(library._rows[0].focus_neighbor_right), library._scroll)
	var dialogue_tab: Button = gallery._gallery_tabs.get_child(2)
	assert_eq(library._rows[0].get_node(library._rows[0].focus_neighbor_top), dialogue_tab)
	assert_eq(library._rows.back().get_node(library._rows.back().focus_neighbor_bottom), home)
	assert_eq(home.get_node(home.focus_neighbor_top), library._rows.back())
	for tab: Button in gallery._gallery_tabs.get_children():
		assert_eq(tab.get_node(tab.focus_neighbor_bottom), library._rows[0])
	await _action(viewport, "ui_up")
	assert_same(viewport.gui_get_focus_owner(), dialogue_tab)
	await _action(viewport, "ui_down")
	assert_same(viewport.gui_get_focus_owner(), library._rows[0])
	await _action(viewport, "ui_down")
	assert_same(viewport.gui_get_focus_owner(), home)
	await _action(viewport, "ui_up")
	assert_same(viewport.gui_get_focus_owner(), library._rows[0])
	await _action(viewport, "ui_right")
	assert_same(viewport.gui_get_focus_owner(), library._scroll)
	await _action(viewport, "ui_left")
	assert_same(viewport.gui_get_focus_owner(), library._rows[0])
	for locale: String in ["en", "zh_HK"]:
		for percent: int in [100, 150]:
			assert_true(localization.set_locale(locale).ok)
			assert_true(profile.set_preference(&"preferences.accessibility.text_size", percent).ok)
			await _settle()
			var before: Dictionary = profile.get_profile_snapshot()
			var bytes: Dictionary = files.snapshot_persisted()
			var revision: int = profile.get_profile_revision()
			var placeholders: Array[Label] = []
			for label: Label in library._paper.get_children():
				assert_eq(label.accessibility_name, label.text)
				assert_true(label.tooltip_text.is_empty())
				assert_eq(label.language, locale.replace("_", "-"))
				assert_lte(label.get_minimum_size().x, library._scroll.size.x)
				if label.text == localization.t("gallery.dialogue.unread"): placeholders.append(label)
			assert_eq(placeholders.size(), 2, "short and very long unseen caption variants share the same placeholder")
			if placeholders.size() == 2:
				assert_eq(placeholders[0].size, placeholders[1].size)
				assert_eq(placeholders[0].get_line_count(), placeholders[1].get_line_count())
			_assert_hidden(gallery)
			library._scroll.grab_focus()
			for action: String in ["ui_end", "ui_home", "ui_page_down", "ui_page_up"]:
				var input := InputEventAction.new()
				input.action = action
				input.pressed = true
				viewport.push_input(input, true)
				await get_tree().process_frame
			gallery._show_gallery_tab("records")
			gallery._show_gallery_tab("artwork")
			gallery._show_gallery_tab("dialogue")
			library.refresh()
			await _settle()
			assert_eq(profile.get_profile_snapshot(), before)
			assert_eq(profile.get_profile_revision(), revision)
			assert_eq(files.snapshot_persisted(), bytes, "opening, tabs, scrolling and requirements have no persistence writes")
			assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
			assert_eq(viewport.get_texture().get_image().save_png("res://.godot/ci/dialogue-library-%s-%d.png" % [locale, percent]), OK)
	gallery._show_gallery_tab("records")
	assert_true(profile.reset_dialogue_library().ok)
	assert_eq(library._rows.size(), 1, "hidden library skips rebuilding during Profile publication")
	gallery._show_gallery_tab("dialogue")
	await _settle()
	assert_eq(library._rows.size(), 0)
	assert_eq(library._paper.get_child_count(), 0)
	assert_true(library._empty.visible)
	assert_not_null(viewport.gui_get_focus_owner(), "reset moves focus out of removed row")
	assert_eq(home.get_node(home.focus_neighbor_top), dialogue_tab)
	for tab: Button in gallery._gallery_tabs.get_children():
		assert_eq(tab.get_node(tab.focus_neighbor_bottom), home)
	assert_true(profile.is_caption_variant_witnessed(beat))
	library.refresh()
	assert_eq(library._rows.size(), 0, "old Skip history cannot refill a reset library")
	print("DIALOGUE_LIBRARY_RENDER_COMPLETED captures=4")

func _assert_hidden(node: Node) -> void:
	if node is Label or node is Button:
		for hidden: String in [FIXTURE.SHORT, FIXTURE.LONG, "TEST unseen thought.", "TEST unseen checkpoint title", "TEST unseen checkpoint text."]:
			assert_false(hidden in str(node.text))
			assert_false(hidden in str(node.accessibility_name))
			assert_false(hidden in str(node.tooltip_text))
	for child: Node in node.get_children(): _assert_hidden(child)

func _settle() -> void:
	for frame: int in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _action(viewport: SubViewport, action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		viewport.push_input(event, true)
		await get_tree().process_frame
