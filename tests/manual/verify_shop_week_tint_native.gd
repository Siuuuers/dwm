extends SceneTree
## Native rendering of real Shop controls with synthetic catalog/art and memory-only owners.
## Day/palette are installed on mount; live accessibility changes keep the same Day-7 controls.
const SHOP := preload("res://scenes/apps/ShopApp.tscn")
const FIXTURE := preload("res://tests/unit/test_shop_catalog_projection.gd")
const SHOP_THEME := preload("res://scripts/ui/shop/ShopTheme.gd")
const CONFIRMATION_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")
const FOLDER := "res://.godot/phase2r_logs/shop_week_tint"
const ART_COLOUR := Color("e34db1")
const LOGICAL_RECT := Rect2(0, 0, 1280, 720)

class Preferences extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var high_contrast := false
	var colour_preset := "standard"
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		match path:
			&"preferences.accessibility.text_size": return 100
			&"preferences.accessibility.large_targets": return false
			&"preferences.accessibility.high_contrast": return high_contrast
			&"preferences.accessibility.colour_differentiation": return colour_preset
		return fallback
	func present(contrast: bool, preset: String) -> void:
		high_contrast = contrast
		colour_preset = preset
		preference_changed.emit(&"preferences.accessibility.high_contrast", high_contrast)

class Catalog extends RefCounted:
	signal catalog_changed()
	var rows: Array = []
	var catalog_calls := 0
	var purchase_calls := 0
	var supportz_eligible := false
	func get_catalog(_locale: String) -> Dictionary:
		catalog_calls += 1
		return {"ok": true, "value": rows.duplicate(true)}
	func can_purchase(item_id: String, _quantity: int) -> Dictionary:
		return {"ok": item_id != "supportz" or supportz_eligible, "code": &"ok"}
	func purchase(_item_id: String, _quantity: int) -> Dictionary:
		purchase_calls += 1
		return {"ok": false, "code": &"fixture_purchase_disabled"}

var _failures: Array[String] = []
var _checks := 0
var _samples: Array[Dictionary] = []
var _viewport: SubViewport
var _caption: Label

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok: _failures.append(message)
	return ok

func _settle() -> void:
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw

func _texture(size_px: int) -> ImageTexture:
	var pixels := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	pixels.fill(ART_COLOUR)
	return ImageTexture.create_from_image(pixels)

func _mount(palette: StringName, day: int) -> Dictionary:
	var fixture := FIXTURE.new()
	var provider := Catalog.new()
	provider.rows = fixture._valid_rows()
	fixture.free()
	for row: Dictionary in provider.rows:
		row.card_art = _texture(28)
		row.inspector_art = _texture(56)
		row.description = "Synthetic artwork and catalog fixture. No player data or purchase is used."
	var profile := Preferences.new()
	var shop: ShopApp = SHOP.instantiate()
	var configured: Dictionary = shop.configure_catalog(provider, null, profile, palette, day)
	if not _check(configured.get("ok", false), "catalog installation: " + str(configured)):
		shop.free()
		return {}
	shop.position = Vector2(480, 64)
	shop.size = Vector2(800, 656)
	_viewport.add_child(shop)
	await _settle()
	_check(shop.page_count == 2 and shop.page_capacity == 9, "exact two-page catalog")
	shop.next_button.pressed.emit()
	await _settle()
	_check(shop.page_index == 1 and shop.next_button.disabled, "second page is the last page")
	var second_page_cards := 0
	for card: Button in shop.cards.values():
		if card.is_visible_in_tree(): second_page_cards += 1
	_check(second_page_cards == 9, "second page has nine ordinary cards")
	shop.next_button.pressed.emit()
	_check(shop.page_index == 1, "no third page is reachable")
	shop.previous_button.pressed.emit()
	await _settle()
	shop.cards.coffee.pressed.emit()
	shop.cards.coffee.grab_focus()
	shop.quantity_buttons.plus.pressed.emit()
	await _settle()
	return {"shop": shop, "profile": profile, "provider": provider,
		"source_rows": provider.rows.duplicate(true)}

func _view_state(shop: ShopApp) -> Dictionary:
	var ids := {}
	for item_id: String in shop.cards: ids[item_id] = shop.cards[item_id].get_instance_id()
	var focused: Control = _viewport.gui_get_focus_owner()
	return {"selected": shop.selected_id, "quantity": shop.quantity, "page": shop.page_index,
		"scroll": shop.info_scroll.scroll_vertical, "cards": ids,
		"focus": focused.get_instance_id() if focused != null else 0}

func _pixel(pixels: Image, logical_position: Vector2, expected: Color, label: String, tolerance_levels: int = 0) -> String:
	var position := Vector2i(logical_position / 2.0)
	if not _check(Rect2i(Vector2i.ZERO, pixels.get_size()).has_point(position), label + " sample inside image"):
		return "outside"
	var actual := pixels.get_pixelv(position)
	var difference := maxi(absi(actual.r8 - expected.r8), maxi(absi(actual.g8 - expected.g8), absi(actual.b8 - expected.b8)))
	_check(difference <= tolerance_levels, "%s: %s expected %s (RGB tolerance %d)" % [label, actual.to_html(false), expected.to_html(false), tolerance_levels])
	return actual.to_html(false)

func _capture(wired: Dictionary, name: String, modal: bool = false) -> void:
	var shop: ShopApp = wired.shop
	var profile: Preferences = wired.profile
	var provider: Catalog = wired.provider
	_caption.text = "SHOP PRESENTATION FIXTURE\n\n%s\n\nSynthetic catalog and solid pink artwork.\nReal Shop controls; no player saves.\n\n1280 x 720 logical / 640 x 360 capture" % name
	await _settle()
	var roles: Dictionary = SHOP_THEME.resolve(shop._palette, shop._day, profile.high_contrast, profile.colour_preset)
	# Computed WeekTint floats may quantize one RGB level differently on the GPU.
	# Authored Day-1/HC colours and synthetic artwork must still match exactly.
	var colour_tolerance := 1 if shop._day > 1 and not profile.high_contrast else 0
	_check(shop.theme.get_color("habitat", "Shop") == roles.habitat, name + " installed Shop habitat role")
	_check(shop._body.get_global_rect() == Rect2(480, 64, 800, 656), name + " full Shop body placement")
	_check(shop.page_count == 2 and shop._records.size() == 18 and shop.cards.size() == 17, name + " fixed catalog cardinality")
	_check(shop._records[8].blank and not shop.cards.has("supportz"), name + " Supportz retains its blank ordinary slot")
	_check(provider.rows == wired.source_rows, name + " source catalog unchanged")
	_check(provider.purchase_calls == 0, name + " no purchase dispatched")
	_check(not shop.get_node("VBoxContainer/TopBar").visible, name + " no duplicate top bar")
	var visible_cards := 0
	for card: Button in shop.cards.values():
		if not card.is_visible_in_tree(): continue
		visible_cards += 1
		_check(shop._catalog.get_global_rect().encloses(card.get_global_rect()), name + " card inside aperture: " + card.item_id)
		_check(LOGICAL_RECT.encloses(card.get_global_rect()), name + " card visible in native capture: " + card.item_id)
	_check(visible_cards == 8, name + " first page has eight ordinary cards and one blank")
	var pixels := _viewport.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), name + " native viewport rendered"): return
	var habitat := ""
	var paper := ""
	var art := ""
	if modal:
		var confirmation: Control = shop._supportz_confirmation
		_check(is_instance_valid(confirmation), name + " real confirmation mounted")
		if is_instance_valid(confirmation):
			var expected: Theme = CONFIRMATION_THEME.build("en", 100, shop._palette, shop._day, profile.high_contrast, profile.colour_preset)
			for role: String in ["habitat", "face", "paper", "paper_ink", "focus"]:
				_check(confirmation.theme.get_color(role, "Backup") == expected.get_color(role, "Backup"), name + " installed confirmation role: " + role)
			var sheet: Control = confirmation.get_node("ConfirmationSheet")
			_check(LOGICAL_RECT.encloses(sheet.get_global_rect()), name + " confirmation sheet fully visible")
			# Sample the visible sheet; the obscured Shop is verified by its theme above.
			paper = _pixel(pixels, sheet.global_position + Vector2(8, 8), expected.get_color("paper", "Backup"), name + " confirmation paper", colour_tolerance)
			var focused: Control = _viewport.gui_get_focus_owner()
			_check(focused == confirmation.cancel_button or focused == confirmation.confirm_button, name + " focus belongs to confirmation")
			_check(not shop.can_return_home(), name + " modal retains Shop custody")
	else:
		# Bottom-right habitat border avoids the face, controls and card focus rings.
		habitat = _pixel(pixels, shop._body.global_position + Vector2(792, 648), roles.habitat, name + " habitat", colour_tolerance)
		_check(shop.cards.coffee.has_focus(), name + " selected card keeps visible focus")
		var height: float = shop.cards.coffee.size.y
		var blank_center := shop._catalog.global_position + Vector2(304 + 72, 2 * (height + 8) + height / 2)
		_pixel(pixels, blank_center, roles.laminate, name + " blank-slot laminate", colour_tolerance)
		paper = _pixel(pixels, shop._document.global_position + Vector2(92, 20), roles.paper, name + " art paper", colour_tolerance)
		art = _pixel(pixels, shop._art.get_global_rect().get_center(), ART_COLOUR, name + " untinted inspector artwork")
		_pixel(pixels, shop.cards.coffee.global_position + shop.cards.coffee._art_rect.get_center(), ART_COLOUR, name + " untinted card artwork")
		_check(shop._art.modulate == Color.WHITE and shop._art.self_modulate == Color.WHITE, name + " artwork keeps neutral modulation")
	var filename := name + ".png"
	_check(pixels.save_png(FOLDER.path_join(filename)) == OK, name + " PNG saved")
	_samples.append({"file": filename, "palette": str(shop._palette), "day": shop._day,
		"high_contrast": profile.high_contrast, "colour_preset": profile.colour_preset,
		"habitat_pixel": habitat, "paper_pixel": paper, "art_pixel": art,
		"material_rgb_tolerance_levels": colour_tolerance, "habitat_pixel_checked": not modal,
		"modal": modal, "catalog_calls": provider.catalog_calls})

func _recolour(wired: Dictionary, high_contrast: bool, preset: String, name: String) -> void:
	var shop: ShopApp = wired.shop
	var before := _view_state(shop)
	var catalog_calls: int = wired.provider.catalog_calls
	wired.profile.present(high_contrast, preset)
	await _settle()
	_check(_view_state(shop) == before, name + " recolour preserves cards, selection, quantity, page, scroll and focus")
	_check(wired.provider.catalog_calls == catalog_calls, name + " colour-only change does not call catalog")
	await _capture(wired, name)

func _run() -> void:
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty(), "isolated wrapper root required") \
		or not _check(DisplayServer.get_name() != "headless", "native renderer required"):
		for failure: String in _failures: printerr(failure)
		quit(1)
		return
	if not _check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER)) == OK, "capture directory available"):
		quit(1)
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.size_2d_override = Vector2i(1280, 720)
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("050607")
	backdrop.size = LOGICAL_RECT.size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(backdrop)
	_caption = Label.new()
	_caption.position = Vector2(24, 80)
	_caption.size = Vector2(432, 560)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_caption)
	for day: int in [1, 7]:
		var wired := await _mount(&"after_hours", day)
		if wired.is_empty(): continue
		await _capture(wired, "after-hours-day%d-standard" % day)
		if day == 7:
			await _recolour(wired, true, "standard", "after-hours-day7-high-contrast")
			await _recolour(wired, false, "deutan", "after-hours-day7-deutan")
		wired.shop.queue_free()
		await process_frame
	var midnight := await _mount(&"midnight", 7)
	if not midnight.is_empty():
		await _capture(midnight, "midnight-day7-standard")
		midnight.provider.supportz_eligible = true
		midnight.provider.catalog_changed.emit()
		await _settle()
		_check(midnight.shop._supportz_button.visible and not midnight.shop._supportz_button.disabled, "eligible Supportz admits the blank contact")
		midnight.shop._supportz_button.pressed.emit()
		await _capture(midnight, "midnight-day7-supportz-confirmation", true)
		if is_instance_valid(midnight.shop._supportz_confirmation):
			midnight.shop._supportz_confirmation.cancel_button.pressed.emit()
			await _settle()
			_check(midnight.shop.can_return_home(), "cancel restores Shop custody")
			_check(midnight.provider.purchase_calls == 0, "cancel never purchases")
		midnight.shop.queue_free()
	_check(_samples.size() == 6, "six requested native captures")
	var report := {"ok": _failures.is_empty(), "checks": _checks, "captures": _samples.size(),
		"samples": _samples, "failures": _failures,
		"sampling": "Habitat sampled in the clear bottom-right border; modal checks installed theme and visible sheet paper. Computed WeekTint allows at most one RGB level of renderer rounding; authored Day-1/HC colours and artwork remain exact.",
		"fixture": "Real Shop controls; synthetic 17-item catalog, solid pink art and memory-only owners. Fresh installed day/palette mounts; live HC/CVD recolours. Desktop eviction is covered by its integration suite; no bootstrap, saves or purchases exercised."}
	var file := FileAccess.open(FOLDER.path_join("measurements.json"), FileAccess.WRITE)
	if _check(file != null, "native report opened"):
		report["checks"] = _checks
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	for failure: String in _failures: printerr(failure)
	if _failures.is_empty(): print("SHOP_WEEK_TINT_NATIVE_VERIFIED captures=", _samples.size(), " checks=", _checks)
	else: printerr("SHOP_WEEK_TINT_NATIVE_FAILED")
	_viewport.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)
