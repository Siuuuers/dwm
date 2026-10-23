extends SceneTree
## Real shared Shop host with explicitly synthetic public catalog/art fixtures.
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const FIXTURES := preload("res://tests/unit/test_shop_catalog_projection.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")
const SHARED := preload("res://tests/manual/verify_schedule_desktop_native.gd")
const LOCALE := preload("res://tests/manual/verify_quick_status_native.gd")
class DesktopFixture extends ComputerDesktop:
	func _configure_from_bootstrap() -> void: pass
class CatalogFixture extends RefCounted:
	signal catalog_changed()
	var rows: Array = []
	var calls := 0
	func get_catalog(locale: String) -> Dictionary:
		calls += 1
		var result := rows.duplicate(true)
		for row: Dictionary in result: row.name = COPY.item_name(locale,row.id)
		return {"ok":true,"value":result}
var _failures: Array[String] = []
var _checks := 0
var _samples: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok: _failures.append(label)
	return ok
func _run() -> void:
	var folder := ProjectSettings.globalize_path("user://evidence/shop_desktop_native")
	DirAccess.make_dir_recursive_absolute(folder)
	var fixture := FIXTURES.new()
	var provider := CatalogFixture.new()
	provider.rows = fixture._valid_rows()
	fixture.free()
	var original := provider.rows.duplicate(true)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400,360)
	viewport.size_2d_override = Vector2i(800,720)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var profile := SHARED.Preferences.new()
	var locale := LOCALE.CatalogLocale.new()
	viewport.add_child(profile)
	viewport.add_child(locale)
	locale.present("en")
	var host := HOST.new()
	host.reset(3)
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(DesktopFixture)
	viewport.add_child(desktop)
	_check(desktop.configure_shop(provider,locale,profile,host,3).ok,"catalog owner injection")
	if not _check(desktop.open_app(&"shop").ok,"Shop opens"):
		quit(1)
		return
	var shop: Control = desktop._cached_app_windows[&"shop"]
	for language: String in ["en","zh_CN","zh_HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				_check(locale.present(language),"real locale catalog")
				profile.present(percent,large)
				for frame in 6: await process_frame
				while shop.page_index > 0:
					shop.previous_button.pressed.emit()
					await process_frame
				shop.cards.wine.grab_focus()
				shop.cards.wine.pressed.emit()
				for frame in 4: await RenderingServer.frame_post_draw
				_check(shop.last_result.ok,"valid current catalog")
				_check(shop._records.size()==18 and shop.cards.size()==17,"canonical positions and public card count")
				_check(shop._records[8].blank and not shop.cards.has("supportz"),"blank has no input or accessible card")
				_check(shop._body.get_global_rect()==Rect2(0,64,800,656),"shared desktop plate placement")
				_check(not shop.get_node("VBoxContainer/TopBar").visible,"only one shared top bar")
				_check(shop._percent==percent,"saved font size")
				for card: Button in shop.cards.values():
					if not card.visible: continue
					_check(card.size.y>=card.get_combined_minimum_size().y,"full public card copy height")
					_check(shop._catalog.get_global_rect().encloses(card.get_global_rect()),"visible card fits catalog aperture")
				var first_pixels := viewport.get_texture().get_image()
				var blank_page := int(8 / shop.page_capacity)
				while shop.page_index < blank_page:
					shop.next_button.pressed.emit()
					await process_frame
				for frame in 4: await RenderingServer.frame_post_draw
				var pixels := viewport.get_texture().get_image()
				var slot: int = 8-shop.page_index*shop.page_capacity
				var height: float = shop.cards.values()[0].size.y
				var center := Vector2(16+(slot%3)*152+72,64+16+floori(slot/3.0)*(height+8)+height/2)
				_check(pixels.get_pixelv(Vector2i(center/2)).to_html(false)==shop._role("laminate").to_html(false),"blank slot has only its structural laminate")
				_check(provider.rows==original,"no fixture catalog mutations")
				var filename := "%s-%d-%s.png" % [language,percent,"large-blank" if large else "ordinary-first"]
				var captured: Image = pixels if large else first_pixels
				_check(captured.save_png(folder.path_join(filename))==OK,"native capture saved")
				_samples.append({"locale":language,"percent":percent,"large_targets":large,"path":filename,
					"capacity":shop.page_capacity,"blank_page":blank_page,"catalog_unchanged":provider.rows==original})
	var output := {"ok":_failures.is_empty(),"samples":_samples,"checks":_checks,"captures":_samples.size(),
		"failures":_failures,"fixture":"Synthetic 17 ordinary public records, transparent test textures and working ShopCopy names; no purchase owner or player data."}
	var file := FileAccess.open(folder.path_join("measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	for failure in _failures: printerr(failure)
	if _failures.is_empty(): print("SHOP_DESKTOP_NATIVE_VERIFIED tuples=",_samples.size()," checks=",_checks)
	else: printerr("SHOP_DESKTOP_NATIVE_FAILED")
	viewport.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)
