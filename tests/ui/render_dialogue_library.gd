extends GutTest
const FIXTURE := preload("res://tests/support/DialogueLibraryFixture.gd")
const CATALOGUE := preload("res://scripts/narrative/DialogueLibraryCatalogue.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const HOME_BUTTON := preload("res://scripts/ui/desktop/DesktopHomeButton.gd")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")

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
	# Mirror MenuScene's hosting rectangle and later-drawn bottom title strip.
	var host := Control.new()
	host.name = "GalleryHost"
	host.position = Vector2(320, 0)
	host.size = Vector2(960, 656)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(host)
	var strip := Control.new()
	strip.name = "TitleStrip"
	strip.position = Vector2(320, 656)
	strip.size = Vector2(960, 64)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.theme = DESKTOP_THEME.build("en", 100, &"after_hours", 0.0, false, "standard", "pixel")
	viewport.add_child(strip)
	strip.draw.connect(func():
		strip.draw_rect(Rect2(0, 0, 960, 64), strip.get_theme_color("face", "Desktop"))
		strip.draw_rect(Rect2(0, 0, 960, 2), strip.get_theme_color("structure", "Desktop")))
	var home := HOME_BUTTON.new()
	home.name = "TitleReturn"
	home.current_on_launcher = false
	home.return_arrow = true
	home.size = Vector2(64, 64)
	home.accessibility_name = "Return"
	strip.add_child(home)
	var title := Label.new()
	title.position = Vector2(80, 0)
	title.size = Vector2(696, 64)
	title.text = "Gallery"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(title)
	var gallery: Control = GALLERY.instantiate()
	assert_true(gallery.configure_title_host(home, localization, profile).ok)
	host.add_child(gallery)
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
	assert_eq(gallery._gallery_tabs.get_theme_constant("separation"), 24)
	assert_true(dialogue_tab.toggle_mode)
	assert_true(dialogue_tab.button_pressed)
	assert_false(gallery._gallery_tabs.get_child(0).button_pressed)
	assert_false(gallery._gallery_tabs.get_child(1).button_pressed)
	assert_eq(home.get_global_rect(), Rect2(320, 656, 64, 64))
	assert_true(home.is_visible_in_tree())
	assert_gt(strip.get_index(), host.get_index(), "title strip draws above hosted Gallery")
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
			strip.theme = DESKTOP_THEME.build(locale.replace("_", "-"), percent, &"after_hours", 0.0, false, "standard", "pixel")
			title.text = localization.t("menu.gallery")
			title.language = locale.replace("_", "-")
			home.accessibility_name = "返回" if locale == "zh_HK" else "Return"
			strip.queue_redraw()
			await _settle()
			for index: int in 2:
				var tab: Button = gallery._gallery_tabs.get_child(index)
				var next_tab: Button = gallery._gallery_tabs.get_child(index + 1)
				assert_gte(next_tab.position.x - tab.position.x - tab.size.x, 24.0, "localized tab bounds remain separated")
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
			assert_true(gallery._gallery_tabs.get_child(0).button_pressed)
			assert_false(dialogue_tab.button_pressed)
			gallery._show_gallery_tab("artwork")
			assert_true(gallery._gallery_tabs.get_child(1).button_pressed)
			gallery._show_gallery_tab("dialogue")
			assert_true(dialogue_tab.button_pressed)
			assert_false(gallery._gallery_tabs.get_child(0).button_pressed)
			assert_false(gallery._gallery_tabs.get_child(1).button_pressed)
			library.refresh()
			await _settle()
			assert_eq(profile.get_profile_snapshot(), before)
			assert_eq(profile.get_profile_revision(), revision)
			assert_eq(files.snapshot_persisted(), bytes, "opening, tabs, scrolling and requirements have no persistence writes")
			assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
			assert_eq(viewport.get_texture().get_image().save_png("res://.godot/ci/dialogue-library-%s-%d.png" % [locale, percent]), OK)
	assert_true(localization.set_locale("en").ok)
	assert_true(profile.set_preference(&"preferences.language.secondary_locale_id", "zh_HK").ok)
	assert_true(profile.set_preference(&"preferences.language.dual_enabled", true).ok)
	for percent: int in [100, 125, 150]:
		assert_true(profile.set_preference(&"preferences.accessibility.text_size", percent).ok)
		await _settle()
		var languages: Array[String] = []
		var previous_label: Label
		for label: Label in library._paper.get_children():
			assert_gte(label.size.y, label.get_minimum_size().y, "shaped text retains its full height")
			if previous_label != null:
				assert_gte(label.position.y - previous_label.position.y - previous_label.size.y, 16.0,
					"translations and following labels retain their vertical spacing")
			previous_label = label
			if label.text in ["TEST read caption.", "測試已讀對白。"]:
				languages.append(label.language)
				assert_lte(label.get_minimum_size().x, library._scroll.size.x)
				assert_eq(label.accessibility_name, label.text)
		assert_eq(languages, ["en", "zh-HK"], "Primary precedes Secondary in reading order")
		_assert_hidden(gallery)
		var discovery_before: Dictionary = profile.get_dialogue_library()
		library.refresh()
		assert_eq(profile.get_dialogue_library(), discovery_before)
		assert_eq(viewport.get_texture().get_image().save_png("res://.godot/ci/dialogue-library-dual-%d.png" % percent), OK)
	assert_true(profile.set_preference(&"preferences.language.dual_enabled", false).ok)
	await _settle()
	for label: Label in library._paper.get_children():
		assert_ne(label.text, "測試已讀對白。", "turning dual off removes Secondary without changing discovery")
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
	print("DIALOGUE_LIBRARY_RENDER_COMPLETED captures=7")

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
