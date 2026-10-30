extends "res://addons/gut/test.gd"
## Dedicated rendered-only regression. Invoke in its own process with -Rendered;
## the original Shop plate tests remain compatible with their headless lane.
const SHOP := preload("res://scenes/apps/ShopApp.tscn")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")
const PRESENTATION := preload("res://scripts/application/shop/ShopPresentationPort.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")

func test_rendered_blank_laminate_uses_the_current_supportz_slot() -> void:
	assert_ne(DisplayServer.get_name(), "headless", "This visual obligation requires the explicit rendered runner.")
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 656)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var rows := _catalogue_rows()
	var home := Button.new()
	viewport.add_child(home)
	home.hide()
	var shop: Control = SHOP.instantiate()
	shop.configure_host(home)
	var configured: Dictionary = shop.configure_shop(rows)
	assert_true(configured.ok, str(configured))
	viewport.add_child(shop)
	if not configured.ok: return
	for frame: int in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var index: int = shop._index_of("supportz")
	assert_eq(index, 8, "Current catalogue's structural blank moved with retired merchandise.")
	assert_true(shop._records[index].blank)
	assert_false(shop.cards.has("supportz"), "Blank remains noninteractive.")
	var card_height: float = shop.cards.crystal_stutters.size.y
	var local_point := Vector2(26 + (index % 3) * 152, 26 + floori(float(index) / 3.0) * (card_height + 8))
	var point: Vector2 = shop._body.get_global_transform_with_canvas() * local_point
	var image: Image = viewport.get_texture().get_image()
	assert_false(image.is_empty())
	if image.is_empty(): return
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	assert_eq(image.save_png("res://.godot/ci/shop-blank-rendered.png"), OK, "Retain original viewport pixels.")
	var pixel: Color = image.get_pixelv(Vector2i(point))
	var laminate: Color = shop.theme.get_color("laminate", "Shop")
	assert_almost_eq(pixel.r, laminate.r, 0.005, "Blank interior uses laminate, not uncovered plate face.")
	assert_almost_eq(pixel.g, laminate.g, 0.005)
	assert_almost_eq(pixel.b, laminate.b, 0.005)
	var proof := FileAccess.open("res://.godot/ci/shop-blank-rendered.json", FileAccess.WRITE)
	assert_not_null(proof)
	if proof != null:
		proof.store_string(JSON.stringify({"slot": index, "sample_x": int(point.x), "sample_y": int(point.y),
			"actual_rgba": [pixel.r, pixel.g, pixel.b, pixel.a],
			"expected_rgba": [laminate.r, laminate.g, laminate.b, laminate.a],
			"viewport_width": image.get_width(), "viewport_height": image.get_height()}))
		proof.close()

func _catalogue_rows() -> Array:
	var catalogue: Variant = CATALOG.new()
	var presentation: Variant = PRESENTATION.new()
	var rows: Array = []
	for item: Variant in catalogue.get_shop_items():
		if item.id == "supportz": continue
		var id: String = PRESENTATION._SOURCE_TO_PUBLIC.get(item.id, item.id)
		rows.append({"id": id, "name": COPY.item_name("en", id), "unit_price": item.price,
			"currency": item.currency, "available": true,
			"batchable": id in PRESENTATION._BATCHABLE_IDS,
			"legal_max": item.max_purchases if id in PRESENTATION._BATCHABLE_IDS else 1,
			"card_art": presentation._texture(id, 28), "inspector_art": presentation._texture(id, 56)})
	return rows

func test_single_page_grid_and_balance_strip_at_1080p() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	for percent: int in [100, 125, 150]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1920, 1080)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child_autofree(viewport)
		var shop: Control = SHOP.instantiate()
		shop._balances = {"money": 200, "coins": 7}
		assert_true(shop.configure_shop(_catalogue_rows(), "en", percent).ok)
		shop.position = Vector2(560, 48)
		viewport.add_child(shop)
		for frame: int in 5: await get_tree().process_frame
		assert_true(shop.last_result.ok)
		assert_eq(shop.page_count, 1)
		assert_eq(shop._records.size(), 9)
		assert_false(shop.previous_button.visible)
		assert_false(shop.next_button.visible)
		assert_false(shop.page_label.visible)
		assert_true(Rect2(0, 0, 1920, 1080).encloses(shop.get_global_rect()))
		assert_eq(shop._catalog.position.y, 16.0)
		assert_eq(shop._balance_label.position.x, shop.info_scroll.position.x + 16)
		assert_eq(shop._balance_label.size.x, 272.0)
		assert_lte(shop._balance_label.get_rect().end.x, shop.info_scroll.get_rect().end.x)
		assert_lte(shop._balance_label.get_rect().end.y, shop.info_scroll.position.y)
		for card: Control in shop.cards.values():
			assert_true(card.visible)
			assert_eq(card._art_rect.size, Vector2(56, 56))
			assert_true(shop._catalog.get_global_rect().encloses(card.get_global_rect()))
		await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
		assert_eq(pixels.save_png("res://.godot/ci/shop-single-page-%d.png" % percent), OK)
		viewport.queue_free()
		await get_tree().process_frame
