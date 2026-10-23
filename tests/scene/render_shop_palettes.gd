extends SceneTree
## Presentation fixtures only: transparent test textures are not final item art.
const SHOP := preload("res://scenes/apps/ShopApp.tscn")
const FIXTURE := preload("res://tests/unit/test_shop_catalog_projection.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture := FIXTURE.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800,656)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for sample: Dictionary in [
		{"locale":"en","percent":100,"palette":&"after_hours","page":0,"file":"shop-after-hours-en100.png"},
		{"locale":"en","percent":100,"palette":&"midnight","page":0,"file":"shop-midnight-en100.png"},
		{"locale":"zh_HK","percent":150,"palette":&"midnight","page":0,"file":"shop-midnight-hk150.png"},
		{"locale":"zh_CN","percent":125,"palette":&"after_hours","page":0,"blank":true,"file":"shop-after-hours-cn125-blank-slot.png"},
	]:
		var rows: Array = fixture._valid_rows()
		for row: Dictionary in rows: row.name = COPY.item_name(sample.locale,row.id)
		rows[0].available = false
		rows[0].legal_max = 0
		rows[0].description = "Fixture description for scroll and palette inspection. ".repeat(12) if sample.locale == "en" else "此段為版面測試文字。".repeat(12)
		var shop := SHOP.instantiate()
		var configured: Dictionary = shop.configure_shop(rows,sample.locale,sample.percent,false,sample.palette)
		if not configured.ok:
			push_error("Shop render fixture refused: %s" % configured)
			quit(1)
			return
		viewport.add_child(shop)
		for frame in 5: await process_frame
		var target_page: int = int(8 / shop.page_capacity) if sample.get("blank",false) else sample.page
		for page in target_page:
			shop.next_button.pressed.emit()
			for frame in 3: await process_frame
		if target_page == 0: shop.cards.wine.grab_focus()
		for frame in 5: await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		if pixels == null or pixels.is_empty() or pixels.save_png("res://.godot/phase2r_logs/"+sample.file) != OK:
			quit(1)
			return
		var expected_habitat: Color = shop.theme.get_color("habitat","Shop")
		if pixels.get_pixel(0,0).to_html(false) != expected_habitat.to_html(false):
			push_error("Shop habitat pixel mismatch: "+sample.file)
			quit(1)
			return
		print("SHOP_CAPTURE ",sample.file," size=",pixels.get_size()," page=",shop.page_index," capacity=",shop.page_capacity," habitat=",expected_habitat.to_html(false)," inspector_extent=",shop.get("_document").custom_minimum_size.y)
		viewport.remove_child(shop)
		shop.queue_free()
	fixture.free()
	quit(0)
