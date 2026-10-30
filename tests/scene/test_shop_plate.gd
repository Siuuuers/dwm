extends "res://tests/unit/test_shop_catalog_projection.gd"

const SHOP := preload("res://scenes/apps/ShopApp.tscn")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")
const SHOP_THEME := preload("res://scripts/ui/shop/ShopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")

func _fixture(locale: String = "en", percent: int = 100, large: bool = false, palette: StringName = &"after_hours",
		day: int = 1, high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel") -> Dictionary:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	add_child_autofree(root)
	var home := Button.new()
	home.text = "Return"
	home.position = Vector2(480, 0)
	home.size = Vector2(64, 64)
	root.add_child(home)
	var shop := SHOP.instantiate()
	shop.position = Vector2(480, 64)
	var rows := _valid_rows()
	for row: Dictionary in rows: row.name = COPY.item_name(locale, row.id)
	shop.configure_host(home)
	var result: Dictionary = shop.configure_shop(rows, locale, percent, large, palette, day, high_contrast, colour_preset, font_style)
	assert_true(result.ok)
	root.add_child(shop)
	return {"root": root, "shop": shop, "rows": rows, "home": home}

func test_week_tint_and_accessibility_reach_plate_cards_without_filtering_specimen_art() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		for high_contrast: bool in [false, true]:
			for preset: String in ["standard", "protan", "deutan", "tritan"]:
				var warm: Dictionary = SHOP_THEME.resolve(palette, 1, high_contrast, preset)
				assert_false(warm.is_empty(), "%s %s %s" % [palette, high_contrast, preset])
				for day: int in range(1, 8):
					var roles: Dictionary = SHOP_THEME.resolve(palette, day, high_contrast, preset)
					assert_eq(roles.size(), warm.size())
					for protected: String in ["primary_ink", "primary_dark_copy", "paper_focus_inner", "dark_focus_inner", "selected_plane"]:
						assert_eq(roles[protected], warm[protected], "%s %s Day %s %s" % [palette, preset, day, protected])
					if high_contrast:
						assert_eq(roles, warm, "High Contrast has zero tint on Day %s" % day)
					if day == 7 and not high_contrast:
						assert_ne(roles.habitat, warm.habitat)
	var f := _fixture("en", 100, false, &"midnight", 7, false, "protan")
	await _settle()
	var expected: Dictionary = SHOP_THEME.resolve(&"midnight", 7, false, "protan")
	for role: String in expected:
		assert_eq(f.shop.theme.get_color(role, "Shop"), expected[role], role)
	assert_eq(f.shop.cards.size(), 8)
	assert_eq(f.shop.page_count, 1)
	assert_true(f.shop._records[8].blank)
	assert_false(f.shop.cards.has("supportz"))
	for card: Button in f.shop.cards.values():
		assert_eq(card.get("_roles"), expected)
	assert_same(f.shop.cards.crystal_stutters.get("_art"), f.rows[0].card_art,
		"The specimen texture remains the source texture.")
	assert_same(f.shop._art.texture, f.rows[0].inspector_art)
	assert_eq(f.shop._art.modulate, Color.WHITE)
	assert_eq(f.shop._art.self_modulate, Color.WHITE)
	assert_eq(f.shop.cards.crystal_stutters.modulate, Color.WHITE)
	assert_eq(f.shop.cards.crystal_stutters.self_modulate, Color.WHITE)
	assert_eq(WEEK_TINT.tint_for_day(1), 0.0)

func test_both_standard_palettes_publish_exact_roles_to_plate_and_all_cards() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		var f := _fixture("en", 100, false, palette)
		await _settle()
		var expected := SHOP_THEME.resolve(palette)
		assert_eq(expected.habitat, Color("0b0d13") if palette == &"after_hours" else Color("0d1514"))
		assert_eq(expected.controlled_face, Color("151b25") if palette == &"after_hours" else Color("14201d"))
		assert_eq(expected.primary_ink, expected.controlled_face)
		assert_eq(expected.laminate, Color("9ea8a2"))
		assert_eq(expected.paper, Color("c3baa3"))
		assert_eq(expected.primary_dark_copy, Color("d8cfb7"))
		assert_eq(expected.secondary_dark_copy, Color("9ea8a2"))
		assert_eq(expected.dark_registration, Color("657d89"))
		assert_eq(expected.secondary_ink, Color("2f2936"))
		assert_eq(expected.selected_plane, Color("789083"))
		assert_eq(expected.dark_focus_outer, Color("d8cfb7"))
		assert_eq(expected.dark_focus_inner, Color("a9935f"))
		assert_eq(expected.paper_focus_inner, Color("644000"))
		for role: String in expected:
			assert_eq(f.shop.theme.get_color(role, "Shop"), expected[role], "%s %s" % [palette, role])
		assert_eq(f.shop.get("_records").size(), 9)
		assert_true(f.shop.get("_records")[8].blank, "Supportz remains the fixed structural blank slot.")
		assert_eq(f.shop.cards.size(), 8)
		for card in f.shop.cards.values(): assert_eq(card.get("_roles"), expected)
		assert_eq(f.shop.cards.crystal_stutters.get("_roles").selected_plane, Color("789083"))
		assert_eq(f.shop.cards.crystal_stutters.get("_roles").dark_focus_inner, Color("a9935f"))
		assert_eq(f.shop.cards.crystal_stutters.get("_roles").structure, expected.primary_ink)
		assert_eq(f.shop.page_label.get_theme_color("font_color"), expected.secondary_dark_copy, "Pager uses secondary copy on the controlled-dark rail.")
		assert_eq(f.shop.previous_button.get_theme_color("font_disabled_color"), expected.primary_dark_copy, "A terminal pager keeps readable copy while Disabled.")
		assert_eq(f.shop.get("_meta_state").get_theme_color("font_color"), expected.primary_ink, "Inspector facts use laminate ink.")
		assert_eq(f.shop.get("_description_label").get_theme_color("font_color"), expected.secondary_ink, "The neutral description uses secondary laminate ink.")
		assert_eq(f.shop.theme.get_color("scroll_track", "Shop"), expected.primary_ink)
		assert_eq(f.shop.theme.get_color("scroll_thumb", "Shop"), expected.primary_dark_copy)
		f.root.hide()

func test_invalid_palette_preserves_the_mounted_snapshot_and_presentation() -> void:
	var f := _fixture("en", 100, false, &"midnight")
	await _settle()
	var shop = f.shop
	shop.cards.inked_silk_string.pressed.emit()
	var old_theme: Theme = shop.theme
	var old_records: Array = shop.get("_records")
	var result: Dictionary = shop.configure_shop([], "zh_CN", 150, true, &"unknown")
	await _settle()
	assert_false(result.ok)
	assert_eq(result.code, "invalid_shop_palette")
	assert_same(shop.theme, old_theme)
	assert_eq(shop.get("_records"), old_records)
	assert_eq(shop.get("_palette"), &"midnight")
	assert_eq(shop.selected_id, "inked_silk_string")
	assert_true(shop.cards.inked_silk_string.visible)

func test_invalid_day_or_accessibility_preset_preserves_mounted_shop() -> void:
	var f := _fixture("en", 100, false, &"midnight", 5, false, "deutan")
	await _settle()
	f.shop.cards.inked_silk_string.pressed.emit()
	f.shop.cards.inked_silk_string.grab_focus()
	var old_card: Button = f.shop.cards.inked_silk_string
	var old_theme: Theme = f.shop.theme
	var old_records: Array = f.shop._records.duplicate(true)
	for invalid: Dictionary in [
		{"day": 0, "preset": "deutan"},
		{"day": 8, "preset": "deutan"},
		{"day": 5, "preset": "unlisted"},
	]:
		var result: Dictionary = f.shop.configure_shop(f.rows, "en", 100, false, &"midnight",
			invalid.day, false, invalid.preset)
		assert_false(result.ok)
		assert_same(f.shop.theme, old_theme)
		assert_same(f.shop.cards.inked_silk_string, old_card)
		assert_eq(f.shop._records, old_records)
		assert_eq(f.shop.selected_id, "inked_silk_string")
		assert_true(old_card.has_focus())

func _settle() -> void:
	for frame in 5: await get_tree().process_frame

func _key(code: int) -> void:
	for held in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = held
		get_viewport().push_input(event)
		await _settle()

func test_every_locale_and_size_keeps_full_catalog_inside_the_plate() -> void:
	for font_style: String in ["pixel","readable"]:
		for locale in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
			for percent in [100, 125, 150]:
				var f := _fixture(locale, percent, false, &"after_hours", 1, false, "standard", font_style)
				await _settle()
				var shop: Control = f.shop
				assert_true(shop.last_result.ok,"%s %s %s%%" % [font_style,locale,percent])
				assert_eq(shop.size, Vector2(800, 656))
				assert_eq(shop.get_node("VBoxContainer/TopBar").visible, false)
				assert_eq(shop.cards.size(), 8)
				assert_true(shop.page_capacity in [3, 6, 9], "Measured rows retain three columns.")
				assert_gte(shop.page_count, 1)
				assert_true(shop.cards.crystal_stutters.has_focus())
				var seen: Array[String] = []
				for page in shop.page_count:
					assert_true(shop.last_result.ok, "%s %s %s%% page %s: %s" % [font_style, locale, percent, page, str(shop.last_result)])
					assert_eq(shop.page_index, page)
					assert_eq(shop.previous_button.disabled, page == 0)
					assert_eq(shop.next_button.disabled, page == shop.page_count - 1)
					for item_id in shop.cards:
						var card: Control = shop.cards[item_id]
						if not card.visible: continue
						seen.append(item_id)
						assert_true(Rect2(0, 0, 448, 544).encloses(card.get_rect()), "%s %s%% %s" % [locale, percent, item_id])
						assert_eq(card.name_label.text, COPY.item_name(locale, item_id))
						assert_lte(card.availability_label.position.y + card.availability_label.size.y, card.size.y - 8)
					if page < shop.page_count - 1:
						shop.next_button.pressed.emit()
						await _settle()
				var expected: Array = ORDER.duplicate()
				expected.erase("supportz")
				assert_eq(seen, expected)
				assert_false(shop.cards.has("supportz"), "Blank capacity has no Control/assistive/hidden target.")
				f.root.hide()

func test_enlarged_japanese_coin_metadata_fits_the_pinned_band() -> void:
	for large: bool in [false, true]:
		for available: bool in [true, false]:
			var f := _fixture("ja", 150, large)
			if not available:
				for row: Dictionary in f.rows:
					row.available = false
					row.legal_max = 0
				f.shop.configure_shop(f.rows, "ja", 150, large)
			await _settle()
			while not f.shop.cards.debug_key.visible: f.shop._change_page(1)
			f.shop.cards.debug_key.grab_focus()
			await _settle()
			assert_true(f.shop.last_result.ok, "Japanese coin metadata remains visible at full text size.")
			assert_eq(f.shop.selected_id, "debug_key")
			var state: Label = f.shop._meta_state
			assert_eq(f.shop._total_label.text, "3 コイン")
			assert_eq(state.text, "在庫あり" if available else "売り切れ")
			# Enlarged text uses the expanded dock even without Large Targets.
			# Pinned line metrics may consume information space, never dock space.
			var band := Rect2(480, 16, 304, 368)
			var information_bottom: float = f.shop.info_scroll.position.y + f.shop.info_scroll.size.y
			for label: Label in [state]:
				assert_true(label.is_visible_in_tree())
				assert_eq(label.get_theme_font_size("font_size"), 36)
				assert_true(band.encloses(label.get_rect()))
				assert_lte(information_bottom, label.position.y)
				assert_eq(label.position.y + label.size.y, 384.0)
				var measured := label.get_theme_font("font").get_string_size(label.text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
				assert_lte(measured.x, label.size.x)
				assert_lte(measured.y, label.size.y)
			f.root.hide()

func test_selection_is_single_purchase_on_one_page() -> void:
	var f := _fixture()
	await _settle()
	var shop = f.shop
	assert_eq(shop.page_count, 1)
	assert_eq(f.rows[0].legal_max, 1)
	for item_id: String in shop.cards:
		shop.cards[item_id].pressed.emit()
		assert_eq(shop.selected_id, item_id)
		assert_eq(shop.quantity, 1)
		for button in shop.quantity_buttons.values(): assert_false(button.visible)
	assert_true(shop.previous_button.disabled)
	assert_true(shop.next_button.disabled)


func test_keyboard_focus_inspects_immediately_and_stays_in_single_purchase_grid() -> void:
	var f := _fixture()
	await _settle()
	var shop = f.shop
	await _key(KEY_RIGHT)
	assert_true(shop.cards.inked_silk_string.has_focus())
	assert_eq(shop.selected_id, "inked_silk_string")
	await _key(KEY_ENTER)
	assert_eq(shop.selected_id, "inked_silk_string")
	await _key(KEY_RIGHT)
	assert_true(shop.cards.letter_with_wax_seal.has_focus())
	await _key(KEY_RIGHT)
	assert_true(shop.cards.letter_with_wax_seal.has_focus())
	await _key(KEY_LEFT)
	assert_true(shop.cards.inked_silk_string.has_focus())
	f.home.grab_focus()
	await _key(KEY_TAB)
	assert_true(shop.cards.crystal_stutters.has_focus())

func test_missing_projection_recovers_without_partial_cards_then_reopens() -> void:
	var f := _fixture()
	await _settle()
	var shop = f.shop
	var failures: Array[String] = []
	shop.recovery_requested.connect(func(code: String): failures.append(code))
	var invalid: Array = f.rows.duplicate(true)
	invalid.pop_back()
	var provider := CatalogProvider.new()
	provider.rows = invalid
	assert_false(shop.configure_catalog(provider).ok)
	await _settle()
	assert_true(shop.cards.is_empty())
	assert_eq(shop.status_label.text, "Unavailable")
	assert_false(shop.info_scroll.visible)
	assert_false(shop.next_button.visible)
	assert_eq(failures, ["invalid_item_count"])
	provider.rows = f.rows
	assert_true(shop.refresh_view().ok)
	await _settle()
	assert_true(shop.cards.crystal_stutters.visible)
	assert_true(shop.info_scroll.visible)
	assert_true(shop.next_button.visible)

func test_only_overflowing_information_enters_traversal() -> void:
	var f := _fixture()
	await _settle()
	var shop = f.shop
	assert_eq(shop.info_scroll.focus_mode, Control.FOCUS_NONE)
	f.rows[0].description = "A sealed vending cup. ".repeat(60)
	shop.configure_shop(f.rows)
	await _settle()
	assert_eq(shop.info_scroll.focus_mode, Control.FOCUS_ALL)
	shop.info_scroll.grab_focus()
	await _key(KEY_END)
	assert_gt(shop.info_scroll.scroll_vertical, 0)
	shop.cards.inked_silk_string.pressed.emit()
	await _settle()
	assert_eq(shop.info_scroll.scroll_vertical, 0)
	assert_eq(shop.info_scroll.focus_mode, Control.FOCUS_NONE)

func test_sold_out_and_unaffordable_products_keep_truthful_quantity_state() -> void:
	var f := _fixture()
	await _settle()
	f.rows[0].available = false
	f.rows[0].legal_max = 0
	f.shop.configure_shop(f.rows)
	await _settle()
	assert_true(f.shop.cards.crystal_stutters.visible)
	assert_eq(f.shop.cards.crystal_stutters.availability_label.text, "Sold out")
	assert_eq(f.shop.get("_total_label").text, "$45")
	for button in f.shop.quantity_buttons.values(): assert_false(button.visible)
	f.rows[0].available = true
	f.shop.configure_shop(f.rows)
	await _settle()
	assert_eq(f.shop.quantity, 1)
	for button in f.shop.quantity_buttons.values():
		assert_false(button.visible)

func test_new_snapshot_resets_quantity_and_preserves_external_home_focus() -> void:
	var f := _fixture()
	await _settle()
	assert_false(f.shop.quantity_buttons.maximum.visible)
	assert_eq(f.shop.quantity, 1)
	f.home.grab_focus()
	f.rows[0].legal_max = 0
	f.shop.configure_shop(f.rows)
	await _settle()
	assert_eq(f.shop.quantity, 1)
	assert_true(f.home.has_focus(), "Background snapshot refresh cannot steal Home focus.")

func test_failed_snapshot_returns_owned_focus_to_home() -> void:
	var f := _fixture()
	await _settle()
	assert_true(f.shop.cards.crystal_stutters.has_focus())
	var provider := CatalogProvider.new()
	provider.rows = []
	assert_false(f.shop.configure_catalog(provider).ok)
	await _settle()
	assert_true(f.home.has_focus())

func test_disabled_next_cannot_hold_or_navigate_across_a_new_snapshot() -> void:
	var f := _fixture()
	await _settle()
	assert_eq(f.shop.page_count, 1)
	assert_true(f.shop.next_button.disabled)
	assert_eq(f.shop.next_button.focus_mode, Control.FOCUS_NONE)
	var activations: Array = []
	f.shop.next_button.pressed.connect(func(): activations.append(true))
	var point: Vector2 = f.shop.next_button.get_global_transform_with_canvas() * (f.shop.next_button.size / 2.0)
	var held := InputEventMouseButton.new()
	held.button_index = MOUSE_BUTTON_LEFT
	held.position = point
	held.pressed = true
	get_viewport().push_input(held, true)
	await _settle()
	assert_false(f.shop.next_button.is_pressed())
	assert_true(f.shop.cards.crystal_stutters.has_focus())
	f.shop.configure_shop(f.rows)
	await _settle()
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = point
	get_viewport().push_input(released, true)
	await _settle()
	assert_true(activations.is_empty(), "Disabled navigation never fabricates an activation.")
	assert_eq(f.shop.page_index, 0)
	assert_eq(f.shop.selected_id, "crystal_stutters")
	assert_true(f.shop.next_button.disabled)

func test_right_edge_without_an_inspector_action_is_a_deliberate_noop() -> void:
	var f := _fixture()
	await _settle()
	f.rows[2].legal_max = 0
	f.shop.configure_shop(f.rows)
	await _settle()
	f.shop.cards.letter_with_wax_seal.grab_focus()
	await _key(KEY_RIGHT)
	assert_true(f.shop.cards.letter_with_wax_seal.has_focus(), "Accepted spatial law consumes Right when no inspector action exists.")

func test_bottom_card_keeps_focus_when_single_page_navigation_is_disabled() -> void:
	var f := _fixture()
	await _settle()
	f.shop.cards.debug_key.grab_focus()
	await _key(KEY_DOWN)
	assert_true(f.shop.cards.debug_key.has_focus())
	assert_true(f.shop.previous_button.disabled)
	assert_true(f.shop.next_button.disabled)


func test_single_purchase_total_fits_without_quantity_controls() -> void:
	var f := _fixture()
	await _settle()
	assert_eq(f.shop.quantity, 1)
	assert_eq(f.shop.get("_total_label").text, "$45")
	assert_true(f.shop.last_result.ok)
	for button in f.shop.quantity_buttons.values(): assert_false(button.visible)


class CatalogProvider extends RefCounted:
	signal catalog_changed()
	var rows: Array = []
	var failed := false
	var calls: Array[String] = []
	func get_catalog(locale: String) -> Dictionary:
		calls.append(locale)
		if failed: return {"ok":false,"code":"fixture_catalog_offline"}
		var result := rows.duplicate(true)
		for row: Dictionary in result:
			row.name = COPY.item_name(locale,row.id)
		return {"ok":true,"value":result}

class Preferences extends RefCounted:
	signal locale_changed(locale_id: String)
	signal preference_changed(path: StringName, value: Variant)
	var locale := "en"
	var percent: Variant = 100
	var large := false
	func get_locale() -> String: return locale
	func get_preference(path: String, fallback: Variant = null) -> Variant:
		if path == "preferences.accessibility.text_size": return percent
		if path == "preferences.accessibility.large_targets": return large
		return fallback
	func publish_size(value: Variant) -> void:
		percent = value
		preference_changed.emit(&"preferences.accessibility.text_size",value)

class PurchaseAvailability extends CatalogProvider:
	var available := false
	func can_purchase(_item_id: String, _quantity: int) -> Dictionary:
		return {"ok": available}
	func purchase(_item_id: String, _quantity: int) -> Dictionary:
		return {"ok": available}

func test_unavailable_purchase_status_fits_and_returns_focus_when_buy_disappears() -> void:
	for font_style: String in ["pixel", "readable"]:
		for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
			for percent: int in [125, 150]:
				var f := _fixture(locale, percent, false, &"after_hours", 1, false, "standard", font_style)
				await _settle()
				var shop: Control = f.shop
				assert_false(shop._buy_button.visible, "No purchase provider exposes no Buy action")
				assert_eq(shop.status_label.text, COPY.text(locale, "unavailable"))
				assert_true(Rect2(Vector2.ZERO, shop._body.size).encloses(shop.status_label.get_rect()), "Unavailable status fits the complete visible plate")
				assert_gte(shop.status_label.size.y, shop.status_label.get_minimum_size().y)
				var provider := PurchaseAvailability.new()
				provider.rows = f.rows
				assert_true(shop.configure_catalog(provider).ok)
				for available: bool in [false, true, false]:
					provider.available = available
					shop._render_selection()
					await _settle()
					assert_true(shop.last_result.ok, "%s %s %s%%" % [locale, font_style, percent])
					assert_eq(shop._buy_button.visible, available)
					if available:
						assert_eq(shop._buy_button.get_rect(), Rect2(640, 576, 128, 64), "Available Buy retains its placement")
						assert_true(shop.status_label.text.is_empty())
						shop._buy_button.grab_focus()
					else:
						assert_eq(shop.status_label.text, COPY.text(locale, "unavailable"))
						assert_true(Rect2(Vector2.ZERO, shop._body.size).encloses(shop.status_label.get_rect()))
						assert_gte(shop.status_label.size.y, shop.status_label.get_minimum_size().y)
						assert_true(shop.cards[shop.selected_id].has_focus(), "Unavailable Buy leaves focus on its selected item")
				f.root.hide()

func test_rejected_direct_configuration_preserves_valid_projection_quantity_and_focus() -> void:
	var f := _fixture()
	await _settle()
	f.shop.cards.inked_silk_string.grab_focus()
	assert_false(f.shop.quantity_buttons.maximum.visible)
	f.shop.cards.inked_silk_string.grab_focus()
	var old_card: Button = f.shop.cards.inked_silk_string
	var old_theme: Theme = f.shop.theme
	assert_false(f.shop.configure_shop([],"en",100).ok)
	assert_false(f.shop.configure_shop(f.rows,"unsupported",150).ok)
	await _settle()
	assert_same(f.shop.cards.inked_silk_string,old_card)
	assert_same(f.shop.theme,old_theme)
	assert_eq(f.shop.quantity,1)
	assert_true(old_card.has_focus())
	assert_true(f.shop.last_result.ok)

func test_catalog_owner_updates_preserve_selection_page_focus_and_reset_only_changed_snapshot_quantity() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	assert_true(f.shop.configure_catalog(provider).ok)
	await _settle()
	f.shop.cards.inked_silk_string.grab_focus()
	assert_false(f.shop.quantity_buttons.maximum.visible)
	f.shop.cards.inked_silk_string.grab_focus()
	var old_card: Button = f.shop.cards.inked_silk_string
	provider.catalog_changed.emit()
	await _settle()
	assert_same(f.shop.cards.inked_silk_string,old_card,"An identical owner delivery does not rebuild or restart quantity")
	assert_eq(f.shop.quantity,1)
	provider.rows[0].legal_max = 0
	provider.catalog_changed.emit()
	await _settle()
	assert_eq(f.shop.selected_id,"inked_silk_string")
	assert_eq(f.shop.page_index,0)
	assert_eq(f.shop.quantity,1)
	assert_true(f.shop.cards.inked_silk_string.has_focus(),"The inspector and purchase target follow the focused merchandise")
	var replacement := CatalogProvider.new()
	replacement.rows = f.rows
	assert_false(f.shop.configure_catalog(replacement).ok)
	assert_same(f.shop._provider,provider)

func test_localized_shared_reflow_preserves_quantity_semantic_focus_and_information_offset() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	provider.rows[0].description = "Fixture public description. ".repeat(80)
	var preferences := Preferences.new()
	assert_true(f.shop.configure_catalog(provider,preferences,preferences).ok)
	await _settle()
	assert_false(f.shop.quantity_buttons.maximum.visible)
	f.shop.info_scroll.grab_focus()
	f.shop.info_scroll.scroll_vertical = 30
	preferences.locale = "zh_HK"
	preferences.large = true
	preferences.publish_size(150)
	await _settle()
	assert_eq(f.shop._locale,"zh_HK")
	assert_eq(f.shop._percent,150)
	assert_true(f.shop._large)
	assert_eq(f.shop.quantity,1,"Localized copy is presentation reflow, not a fresh economic snapshot")
	assert_true(f.shop.info_scroll.has_focus())
	assert_eq(f.shop.info_scroll.scroll_vertical,30)
	assert_eq(f.shop._name_label.text,COPY.item_name("zh_HK","crystal_stutters"))
	var card: Button = f.shop.cards.crystal_stutters
	preferences.publish_size(110)
	await _settle()
	assert_same(f.shop.cards.crystal_stutters,card)
	assert_eq(f.shop._percent,150)

func test_hidden_catalog_and_preferences_defer_without_changing_shared_home_navigation() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	var preferences := Preferences.new()
	assert_true(f.shop.configure_catalog(provider,preferences,preferences).ok)
	await _settle()
	f.shop.cards.inked_silk_string.grab_focus()
	f.shop.hide_window()
	f.home.grab_focus()
	var home_next: NodePath = f.home.focus_next
	var card: Button = f.shop.cards.inked_silk_string
	provider.rows[0].legal_max = 0
	provider.catalog_changed.emit()
	preferences.publish_size(150)
	await _settle()
	assert_same(f.shop.cards.inked_silk_string,card)
	assert_true(f.home.has_focus())
	assert_eq(f.home.focus_next,home_next)
	f.shop.show_window()
	await _settle()
	assert_true(f.shop.cards.inked_silk_string.has_focus())
	assert_eq(f.shop._percent,150)
	assert_eq(f.shop._records[0].legal_max,0)

func test_modal_custody_defers_reconstruction_and_rejects_synthetic_lower_actions() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	var preferences := Preferences.new()
	assert_true(f.shop.configure_catalog(provider,preferences,preferences).ok)
	await _settle()
	var card: Button = f.shop.cards.inked_silk_string
	f.shop.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	f.home.grab_focus()
	preferences.publish_size(150)
	assert_false(f.shop.quantity_buttons.maximum.visible)
	card.pressed.emit()
	f.shop.next_button.pressed.emit()
	await _settle()
	assert_same(f.shop.cards.inked_silk_string,card)
	assert_eq(f.shop.quantity,1)
	assert_eq(f.shop.selected_id,"crystal_stutters")
	assert_eq(f.shop.page_index,0)
	assert_false(f.shop.can_return_home())
	assert_true(f.home.has_focus())
	f.shop.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	card.grab_focus()
	await _settle()
	assert_true(f.shop.cards.inked_silk_string.has_focus())
	assert_eq(f.shop._percent,150)
	assert_true(f.shop.can_return_home())

func test_owner_snapshot_cancels_held_native_card_contact_and_provider_failure_is_recoverable() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	assert_true(f.shop.configure_catalog(provider).ok)
	await _settle()
	var activations: Array = []
	f.shop.cards.crystal_stutters.pressed.connect(func(): activations.append(true))
	f.shop.cards.crystal_stutters.grab_focus()
	var held := InputEventKey.new()
	held.keycode = KEY_ENTER
	held.physical_keycode = KEY_ENTER
	held.pressed = true
	get_viewport().push_input(held)
	await _settle()
	assert_true(f.shop.cards.crystal_stutters.is_pressed())
	assert_false(f.shop.can_return_home())
	provider.rows[0].available = false
	provider.rows[0].legal_max = 0
	provider.catalog_changed.emit()
	await _settle()
	f.shop.cards.crystal_stutters.pressed.connect(func(): activations.append(true))
	assert_false(f.shop.cards.crystal_stutters.is_pressed())
	var released := InputEventKey.new()
	released.keycode = KEY_ENTER
	released.physical_keycode = KEY_ENTER
	get_viewport().push_input(released)
	await _settle()
	assert_true(activations.is_empty(), "Snapshot refresh cancels the old held card activation.")
	assert_eq(f.shop.selected_id, "crystal_stutters")
	assert_eq(f.shop.page_index,0)
	provider.failed = true
	provider.catalog_changed.emit()
	await _settle()
	assert_false(f.shop.last_result.ok)
	assert_true(f.shop.cards.is_empty())
	assert_eq(f.shop.status_label.text,"Unavailable")
	assert_true(f.shop.can_return_home())
	provider.failed = false
	f.shop.show_window()
	await _settle()
	assert_true(f.shop.last_result.ok)
	assert_eq(f.shop.cards.size(),8)


func test_native_back_keeps_hidden_return_admission_and_cached_semantic_focus() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	assert_true(f.shop.configure_catalog(provider).ok)
	await _settle()
	f.shop.cards.inked_silk_string.grab_focus()
	var returns: Array[bool] = []
	f.shop.window_hidden.connect(func():
		returns.append(f.shop.can_return_home())
		if f.shop.can_return_home(): f.home.grab_focus())
	await _key(KEY_ESCAPE)
	assert_false(f.shop.visible)
	assert_eq(returns,[true],"The hidden callback must still admit the same Home transition")
	assert_true(f.home.has_focus())
	assert_true(f.shop.can_return_home(),"Host pre-open Home admission does not depend on visibility")
	f.shop.show_window()
	await _settle()
	assert_true(f.shop.cards.inked_silk_string.has_focus())


func test_hidden_prepare_validates_fresh_owner_before_open_without_home_custody_writes() -> void:
	var f := _fixture()
	await _settle()
	f.shop.hide_window()
	f.home.grab_focus()
	var provider := CatalogProvider.new()
	provider.rows = []
	assert_true(f.shop.configure_catalog(provider).ok,"Hidden binding defers presentation")
	var home_next: NodePath = f.home.focus_next
	assert_false(f.shop.prepare_show_window().ok)
	await _settle()
	assert_false(f.shop.visible)
	assert_true(f.home.has_focus())
	assert_eq(f.home.focus_next,home_next)
	provider.rows = f.rows
	assert_true(f.shop.prepare_show_window().ok)
	await _settle()
	assert_false(f.shop.visible)
	assert_true(f.home.has_focus())
	assert_eq(f.home.focus_next,home_next)
	provider.rows.pop_back()
	assert_false(f.shop.prepare_show_window().ok,"Cached reopening reads and validates again")
	assert_false(f.shop.visible)


func test_cached_validation_after_localized_hidden_change_preserves_quantity_without_catalog_event() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	var preferences := Preferences.new()
	assert_true(f.shop.configure_catalog(provider,preferences,preferences).ok)
	await _settle()
	assert_false(f.shop.quantity_buttons.maximum.visible)
	assert_eq(f.shop.quantity,1)
	f.shop.hide_window()
	f.home.grab_focus()
	preferences.locale = "zh_HK"
	preferences.locale_changed.emit("zh_HK")
	preferences.publish_size(125)
	assert_true(f.shop.refresh_view().ok,"Desktop performs this default cached refresh before preparation")
	assert_true(f.shop.prepare_show_window().ok)
	f.shop.show_window()
	await _settle()
	assert_eq(f.shop.quantity,1)
	assert_eq(f.shop._locale,"zh_HK")
	provider.rows[0].legal_max = 0
	assert_true(f.shop.refresh_view().ok,"An unsignaled changed economic snapshot still resets quantity")
	await _settle()
	assert_eq(f.shop.quantity,1)
	assert_eq(f.shop._records[0].legal_max,0)

func test_hidden_external_focus_does_not_block_opening_or_current_catalog_refresh() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	assert_true(f.shop.configure_catalog(provider).ok)
	await _settle()
	f.shop.hide_window()
	var retired_launcher := Button.new()
	f.root.add_child(retired_launcher)
	retired_launcher.hide()
	retired_launcher.grab_focus()
	assert_same(get_viewport().gui_get_focus_owner(),retired_launcher,"Exercise native hidden-focus behavior")
	f.shop.show_window()
	await _settle()
	assert_true(f.shop.cards.crystal_stutters.has_focus())
	retired_launcher.grab_focus()
	provider.rows[0].legal_max = 0
	provider.catalog_changed.emit()
	await _settle()
	assert_eq(f.shop._records[0].legal_max,0,"A retired hidden control has no modal custody")


func test_detached_shop_retires_queued_focus_and_ignores_owner_publications_until_remounted() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	var preferences := Preferences.new()
	assert_true(f.shop.configure_catalog(provider,preferences,preferences).ok)
	await _settle()
	f.shop.cards.inked_silk_string.grab_focus()
	var remembered: String = f.shop._remembered_focus
	f.shop._focus_selected.call_deferred()
	f.shop.configure_shop(f.rows,"en",125)
	f.root.remove_child(f.shop)
	f.home.grab_focus()
	assert_true(f.shop.is_node_ready(),"Detached nodes remain ready; readiness is not viewport custody")
	var revision: int = f.shop._measurement_revision
	var calls: int = provider.calls.size()
	provider.rows[0].legal_max = 0
	provider.catalog_changed.emit()
	preferences.publish_size(150)
	f.shop._remember_focus()
	assert_eq(f.shop.refresh_view().code,"shop_view_detached")
	assert_eq(f.shop.configure_shop(f.rows).code,"shop_view_detached")
	await _settle()
	assert_true(f.home.has_focus())
	assert_eq(f.shop._remembered_focus,remembered)
	assert_eq(f.shop._measurement_revision,revision)
	assert_eq(provider.calls.size(),calls,"Detached publications cannot query or resurrect the outgoing presentation")
	f.root.add_child(f.shop)
	f.shop.show_window()
	await _settle()
	assert_eq(f.shop._percent,150)
	assert_eq(f.shop._records[0].legal_max,0)
	assert_true(f.shop.cards.inked_silk_string.has_focus())

func test_queued_ancestor_rejects_shop_focus_and_layout_before_native_deletion() -> void:
	var f := _fixture()
	await _settle()
	var survivor := Button.new()
	add_child_autofree(survivor)
	f.shop._focus_selected.call_deferred()
	var revision: int = f.shop._measurement_revision
	f.root.queue_free()
	survivor.grab_focus()
	f.shop._focus_selected()
	f.shop._measure_catalog(revision)
	assert_true(survivor.has_focus())
	assert_false(f.shop.can_return_home())
	assert_eq(f.shop.configure_shop(f.rows).code,"shop_view_detached")
	await _settle()
	assert_true(survivor.has_focus())


func test_remount_resumes_retired_measurement_with_identical_catalog_and_preferences() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	assert_true(f.shop.configure_catalog(provider).ok)
	await _settle()
	f.shop.cards.inked_silk_string.grab_focus()
	provider.rows[0].legal_max = 0
	provider.catalog_changed.emit()
	assert_true(f.shop._catalog_layout_pending)
	assert_false(f.shop.cards.inked_silk_string.visible,"Rebuild awaits full-font measurement")
	f.root.remove_child(f.shop)
	f.home.grab_focus()
	await _settle()
	assert_true(f.shop._catalog_layout_pending,"Retired deferred work remains pending for this retained view")
	f.root.add_child(f.shop)
	f.shop.show_window()
	await _settle()
	assert_false(f.shop._catalog_layout_pending)
	assert_true(f.shop.last_result.ok)
	assert_true(f.shop.cards.inked_silk_string.is_visible_in_tree())
	assert_true(f.shop.cards.inked_silk_string.has_focus())
	assert_eq(f.shop.selected_id,"inked_silk_string")
	assert_eq(f.shop._records[0].legal_max,0)
	assert_gt(f.shop.cards.inked_silk_string.size.y,0.0)
