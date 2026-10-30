extends "res://tests/ui/render_shop_cosmetics_base.gd"
## Diagnostic baseline/candidate evidence: FINAL owners in the real SceneHost,
## with TEST authored dialogue. Fit measurements are observations, not acceptance.

func test_mounted_shop_sizing() -> void:
	if not await _begin_cosmetic_run(): return
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1920, 1080)
	window.content_scale_size = Vector2i(1280, 720)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for frame: int in 6: await get_tree().process_frame
	assert_true(game.change_money(200))
	var host: Control = get_tree().current_scene
	assert_eq(host.scene_file_path, HOST)
	var shell: Control = await _open_apps(host)
	if shell == null or not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows[&"shop"]
	var samples: Array[Dictionary] = []
	var captures: Array[String] = []
	var localization: Node = get_node("/root/LocalizationManager")
	for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
		if not _ok(localization.set_locale(locale)): return
		for font_style: String in ["pixel", "readable"]:
			if not _ok(localization.set_font_style(font_style)): return
			for percent: int in [100, 125, 150]:
				if not _ok(profile.set_preference(&"preferences.accessibility.text_size", percent)): return
				get_viewport().gui_release_focus()
				if not _ok(shop.refresh_view(true, true)): return
				shell.app_scroll.scroll_vertical = 0
				for frame: int in 8: await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var image: Image = get_viewport().get_texture().get_image()
				assert_eq(image.get_size(), Vector2i(1920, 1080), "physical capture dimensions")
				assert_true(shop.last_result.ok, str(shop.last_result))
				assert_eq(shop._records.size(), 9, "eight public cards and the secret structural slot")
				assert_eq(shop.cards.size(), 8)
				var sample_id := "%s-%s-%d" % [locale, font_style, percent]
				# Texture coordinates exclude native window borders and letterboxing.
				var texture_transform := Transform2D.IDENTITY.scaled(Vector2(image.get_size()) / get_viewport().get_visible_rect().size)
				var panel_rect := _pixel_rect(shell, texture_transform)
				var bar_rect := _pixel_rect(shell.get_node("DesktopCanvas/AppStrip"), texture_transform)
				var plate_rect := _pixel_rect(shop._body, texture_transform)
				var visible_rect := _pixel_rect(shell.app_scroll, texture_transform)
				var catalog_rect := _pixel_rect(shop._catalog, texture_transform)
				var card_samples: Array[Dictionary] = []
				for item_id: String in shop.cards:
					var card: Control = shop.cards[item_id]
					assert_true(card.is_visible_in_tree(), sample_id + ": " + item_id)
					var card_rect := _pixel_rect(card, texture_transform)
					var art_rect: Rect2 = texture_transform * card.get_global_transform_with_canvas() * card._art_rect
					var wording: Array[Dictionary] = []
					for label: Label in [card.name_label, card.price_label, card.availability_label]:
						wording.append({"text": label.text, "rect": _rect_values(_pixel_rect(label, texture_transform)),
							"font_size": label.get_theme_font_size("font_size"),
							"minimum_height": label.get_minimum_size().y, "height": label.size.y})
					card_samples.append({"id": item_id, "logical_size": [card.size.x, card.size.y],
						"rect": _rect_values(card_rect), "art_rect": _rect_values(art_rect),
						"logical_art_size": [card._art_rect.size.x, card._art_rect.size.y],
						"fully_visible": visible_rect.grow(1).encloses(card_rect), "wording": wording})
				var sample := {"id": sample_id, "viewport": _rect_values(get_viewport().get_visible_rect()),
					"mount": _rect_values(_pixel_rect(host.get_computer_mount(), texture_transform)),
					"desktop": _rect_values(panel_rect), "canvas": _rect_values(_pixel_rect(shell.desktop_canvas, texture_transform)),
					"shop_plate": _rect_values(plate_rect), "catalog": _rect_values(catalog_rect),
					"inspector": _rect_values(_pixel_rect(shop.info_scroll, texture_transform)),
					"balance": _rect_values(_pixel_rect(shop._balance_label, texture_transform)),
					"app_viewport": _rect_values(visible_rect), "app_strip": _rect_values(bar_rect),
					"reading_rail": _rect_values(_pixel_rect(_caption().transport_rail, texture_transform)),
					"shell_scale": [shell.scale.x, shell.scale.y],
					"canvas_scale": [shell.desktop_canvas.scale.x, shell.desktop_canvas.scale.y],
					"panel_bar_edge_delta": [bar_rect.position.x - panel_rect.position.x, bar_rect.end.x - panel_rect.end.x],
					"plate_bar_edge_delta": [bar_rect.position.x - plate_rect.position.x, bar_rect.end.x - plate_rect.end.x],
					"catalog_fully_visible": visible_rect.grow(1).encloses(catalog_rect),
					"scroll_max": shell.app_scroll.get_v_scroll_bar().max_value,
					"scroll_page": shell.app_scroll.get_v_scroll_bar().page, "cards": card_samples}
				samples.append(sample)
				print("SHOP_MOUNTED_SIZING ", JSON.stringify(sample))
				if locale == "en" and font_style == "pixel":
					var prefix := "res://.godot/ci/shop-mounted-" + sample_id
					assert_eq(image.save_png(prefix + ".png"), OK)
					captures.append(prefix + ".png")
					for crop_name: String in ["panel", "items"]:
						var region := Rect2i(panel_rect if crop_name == "panel" else catalog_rect)
						region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
						assert_true(region.has_area())
						assert_eq(image.get_region(region).save_png(prefix + "-" + crop_name + ".png"), OK)
						captures.append(prefix + "-" + crop_name + ".png")
	assert_eq(samples.size(), 30)
	assert_eq(captures.size(), 9)
	_write_json("res://.godot/ci/shop-mounted-sizing.json", {
		"scope": "Production SceneHost and services, TEST authored dialogue; Linux/Windows rendered viewport geometry, not native display-mode certification.",
		"samples": samples, "captures": captures})
	print("SHOP_MOUNTED_SIZING_COMPLETED samples=30 captures=9")

func _pixel_rect(control: Control, texture_transform: Transform2D) -> Rect2:
	return texture_transform * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
