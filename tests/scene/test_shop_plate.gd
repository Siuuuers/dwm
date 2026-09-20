extends "res://tests/unit/test_shop_catalog_projection.gd"

const SHOP := preload("res://scenes/apps/ShopApp.tscn")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")
const SHOP_THEME := preload("res://scripts/ui/shop/ShopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")

func _fixture(locale: String = "en", percent: int = 100, large: bool = false, palette: StringName = &"after_hours",
		day: int = 1, high_contrast: bool = false, colour_preset: String = "standard") -> Dictionary:
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
	var result: Dictionary = shop.configure_shop(rows, locale, percent, large, palette, day, high_contrast, colour_preset)
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
	assert_eq(f.shop.cards.size(), 17)
	assert_eq(f.shop.page_count, 2)
	assert_true(f.shop._records[8].blank)
	assert_false(f.shop.cards.has("supportz"))
	for card: Button in f.shop.cards.values():
		assert_eq(card.get("_roles"), expected)
	assert_same(f.shop.cards.coffee.get("_art"), f.rows[0].card_art,
		"The specimen texture remains the source texture.")
	assert_same(f.shop._art.texture, f.rows[0].inspector_art)
	assert_eq(f.shop._art.modulate, Color.WHITE)
	assert_eq(f.shop._art.self_modulate, Color.WHITE)
	assert_eq(f.shop.cards.coffee.modulate, Color.WHITE)
	assert_eq(f.shop.cards.coffee.self_modulate, Color.WHITE)
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
		assert_eq(f.shop.get("_records").size(), 18)
		assert_true(f.shop.get("_records")[8].blank, "Supportz remains the fixed structural blank slot.")
		assert_eq(f.shop.cards.size(), 17)
		for card in f.shop.cards.values(): assert_eq(card.get("_roles"), expected)
		assert_eq(f.shop.cards.coffee.get("_roles").selected_plane, Color("789083"))
		assert_eq(f.shop.cards.coffee.get("_roles").dark_focus_inner, Color("a9935f"))
		assert_eq(f.shop.cards.coffee.get("_roles").structure, expected.primary_ink)
		assert_eq(f.shop.page_label.get_theme_color("font_color"), expected.secondary_dark_copy, "Pager uses secondary copy on the controlled-dark rail.")
		assert_eq(f.shop.previous_button.get_theme_color("font_disabled_color"), expected.primary_dark_copy, "A terminal pager keeps readable copy while Disabled.")
		assert_eq(f.shop.get("_meta_price").get_theme_color("font_color"), expected.primary_ink, "Inspector facts use laminate ink.")
		assert_eq(f.shop.get("_description_label").get_theme_color("font_color"), expected.secondary_ink, "The neutral description uses secondary laminate ink.")
		assert_eq(f.shop.theme.get_color("scroll_track", "Shop"), expected.primary_ink)
		assert_eq(f.shop.theme.get_color("scroll_thumb", "Shop"), expected.primary_dark_copy)
		f.root.hide()

func test_invalid_palette_preserves_the_mounted_snapshot_and_presentation() -> void:
	var f := _fixture("en", 100, false, &"midnight")
	await _settle()
	var shop = f.shop
	shop.cards.wine.pressed.emit()
	var old_theme: Theme = shop.theme
	var old_records: Array = shop.get("_records")
	var result: Dictionary = shop.configure_shop([], "zh_CN", 150, true, &"unknown")
	await _settle()
	assert_false(result.ok)
	assert_eq(result.code, "invalid_shop_palette")
	assert_same(shop.theme, old_theme)
	assert_eq(shop.get("_records"), old_records)
	assert_eq(shop.get("_palette"), &"midnight")
	assert_eq(shop.selected_id, "wine")
	assert_true(shop.cards.wine.visible)

func test_invalid_day_or_accessibility_preset_preserves_mounted_shop() -> void:
	var f := _fixture("en", 100, false, &"midnight", 5, false, "deutan")
	await _settle()
	f.shop.cards.wine.pressed.emit()
	f.shop.cards.wine.grab_focus()
	var old_card: Button = f.shop.cards.wine
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
		assert_same(f.shop.cards.wine, old_card)
		assert_eq(f.shop._records, old_records)
		assert_eq(f.shop.selected_id, "wine")
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
	for locale in ["en", "zh_CN", "zh_HK"]:
		for percent in [100, 125, 150]:
			var f := _fixture(locale, percent)
			await _settle()
			var shop: Control = f.shop
			assert_eq(shop.size, Vector2(800, 656))
			assert_eq(shop.get_node("VBoxContainer/TopBar").visible, false)
			assert_eq(shop.cards.size(), 17)
			assert_eq(shop.page_capacity, 9)
			assert_eq(shop.page_count, 2)
			assert_true(shop.cards.coffee.has_focus())
			var seen: Array[String] = []
			for page in shop.page_count:
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

func test_selection_quantity_and_page_memory_are_presentation_only() -> void:
	var f := _fixture()
	await _settle()
	var shop = f.shop
	shop.quantity_buttons.maximum.pressed.emit()
	assert_eq(shop.quantity, 4)
	assert_eq(f.rows[0].legal_max, 4)
	shop.cards.wine.grab_focus()
	assert_eq(shop.selected_id, "wine", "Focus immediately inspects the item.")
	shop.cards.wine.pressed.emit()
	assert_eq(shop.selected_id, "wine")
	assert_eq(shop.quantity, 1)
	shop.next_button.pressed.emit()
	await _settle()
	shop.cards.lucky_charm.pressed.emit()
	assert_eq(shop.selected_id, "lucky_charm")
	for button in shop.quantity_buttons.values(): assert_false(button.visible)
	shop.previous_button.pressed.emit()
	await _settle()
	assert_eq(shop.selected_id, "wine")
	shop.next_button.pressed.emit()
	await _settle()
	assert_eq(shop.selected_id, "lucky_charm")
	assert_eq(shop.quantity, 1)

func test_keyboard_focus_inspects_immediately_and_returns_from_inspector() -> void:
	var f := _fixture()
	await _settle()
	var shop = f.shop
	await _key(KEY_RIGHT)
	assert_true(shop.cards.wine.has_focus())
	assert_eq(shop.selected_id, "wine")
	await _key(KEY_ENTER)
	assert_eq(shop.selected_id, "wine")
	await _key(KEY_RIGHT)
	assert_true(shop.cards.pineapple_bun.has_focus())
	await _key(KEY_RIGHT)
	assert_true(shop.quantity_buttons.plus.has_focus())
	await _key(KEY_LEFT)
	assert_true(shop.cards.pineapple_bun.has_focus())
	f.home.grab_focus()
	await _key(KEY_TAB)
	assert_true(shop.cards.coffee.has_focus())

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
	assert_true(shop.cards.coffee.visible)
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
	shop.cards.wine.pressed.emit()
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
	assert_true(f.shop.cards.coffee.visible)
	assert_eq(f.shop.cards.coffee.availability_label.text, "Sold out")
	assert_eq(f.shop.get("_total_label").text, "$20")
	for button in f.shop.quantity_buttons.values(): assert_false(button.visible)
	f.rows[0].available = true
	f.shop.configure_shop(f.rows)
	await _settle()
	assert_eq(f.shop.quantity, 1)
	for button in f.shop.quantity_buttons.values():
		assert_true(button.visible)
		assert_true(button.disabled)

func test_new_snapshot_resets_quantity_and_preserves_external_home_focus() -> void:
	var f := _fixture()
	await _settle()
	f.shop.quantity_buttons.maximum.pressed.emit()
	assert_eq(f.shop.quantity, 4)
	f.home.grab_focus()
	f.rows[0].legal_max = 2
	f.shop.configure_shop(f.rows)
	await _settle()
	assert_eq(f.shop.quantity, 1)
	assert_true(f.home.has_focus(), "Background snapshot refresh cannot steal Home focus.")

func test_failed_snapshot_returns_owned_focus_to_home() -> void:
	var f := _fixture()
	await _settle()
	assert_true(f.shop.cards.coffee.has_focus())
	var provider := CatalogProvider.new()
	provider.rows = []
	assert_false(f.shop.configure_catalog(provider).ok)
	await _settle()
	assert_true(f.home.has_focus())

func test_held_page_button_is_cancelled_by_a_new_snapshot() -> void:
	var f := _fixture()
	await _settle()
	f.shop.next_button.grab_focus()
	var held := InputEventKey.new()
	held.keycode = KEY_ENTER
	held.pressed = true
	get_viewport().push_input(held)
	await _settle()
	f.shop.configure_shop(f.rows)
	await _settle()
	var released := InputEventKey.new()
	released.keycode = KEY_ENTER
	get_viewport().push_input(released)
	await _settle()
	assert_eq(f.shop.page_index, 0, "An old page press cannot act on the new projection.")

func test_right_edge_without_an_inspector_action_is_a_deliberate_noop() -> void:
	var f := _fixture()
	await _settle()
	f.rows[2].legal_max = 0
	f.shop.configure_shop(f.rows)
	await _settle()
	f.shop.cards.pineapple_bun.grab_focus()
	await _key(KEY_RIGHT)
	assert_true(f.shop.cards.pineapple_bun.has_focus(), "Accepted spatial law consumes Right when no inspector action exists.")

func test_bottom_right_on_last_page_reaches_previous_and_disabled_keys_leave_focus() -> void:
	var f := _fixture()
	await _settle()
	f.shop.next_button.pressed.emit()
	await _settle()
	f.shop.cards.pocket_calculator_keepsake.grab_focus()
	await _key(KEY_DOWN)
	assert_true(f.shop.previous_button.has_focus())
	f.shop.previous_button.pressed.emit()
	await _settle()
	f.shop.quantity_buttons.maximum.grab_focus()
	await _key(KEY_ENTER)
	assert_true(f.shop.quantity_buttons.minimum.has_focus())

func test_exact_quantity_that_cannot_fit_recovers_instead_of_clipping_or_capping() -> void:
	var f := _fixture()
	await _settle()
	f.rows[0].legal_max = 123456789
	f.shop.configure_shop(f.rows)
	await _settle()
	f.shop.quantity_buttons.maximum.pressed.emit()
	await _settle()
	assert_eq(f.shop.quantity, 123456789)
	assert_eq(f.shop.last_result.code, "shop_dock_does_not_fit")
	assert_false(f.shop.info_scroll.visible)
	assert_eq(f.shop.status_label.text, "Unavailable")


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

func test_rejected_direct_configuration_preserves_valid_projection_quantity_and_focus() -> void:
	var f := _fixture()
	await _settle()
	f.shop.cards.wine.grab_focus()
	f.shop.quantity_buttons.maximum.pressed.emit()
	f.shop.cards.wine.grab_focus()
	var old_card: Button = f.shop.cards.wine
	var old_theme: Theme = f.shop.theme
	assert_false(f.shop.configure_shop([],"en",100).ok)
	assert_false(f.shop.configure_shop(f.rows,"unsupported",150).ok)
	await _settle()
	assert_same(f.shop.cards.wine,old_card)
	assert_same(f.shop.theme,old_theme)
	assert_eq(f.shop.quantity,4)
	assert_true(old_card.has_focus())
	assert_true(f.shop.last_result.ok)

func test_catalog_owner_updates_preserve_selection_page_focus_and_reset_only_changed_snapshot_quantity() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	assert_true(f.shop.configure_catalog(provider).ok)
	await _settle()
	f.shop.cards.wine.grab_focus()
	f.shop.quantity_buttons.maximum.pressed.emit()
	f.shop.cards.wine.grab_focus()
	var old_card: Button = f.shop.cards.wine
	provider.catalog_changed.emit()
	await _settle()
	assert_same(f.shop.cards.wine,old_card,"An identical owner delivery does not rebuild or restart quantity")
	assert_eq(f.shop.quantity,4)
	provider.rows[0].legal_max = 2
	provider.catalog_changed.emit()
	await _settle()
	assert_eq(f.shop.selected_id,"wine")
	assert_eq(f.shop.page_index,0)
	assert_eq(f.shop.quantity,1)
	assert_true(f.shop.cards.wine.has_focus(),"The inspector and purchase target follow the focused merchandise")
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
	f.shop.quantity_buttons.maximum.pressed.emit()
	f.shop.info_scroll.grab_focus()
	f.shop.info_scroll.scroll_vertical = 30
	preferences.locale = "zh_HK"
	preferences.large = true
	preferences.publish_size(150)
	await _settle()
	assert_eq(f.shop._locale,"zh_HK")
	assert_eq(f.shop._percent,150)
	assert_true(f.shop._large)
	assert_eq(f.shop.quantity,4,"Localized copy is presentation reflow, not a fresh economic snapshot")
	assert_true(f.shop.info_scroll.has_focus())
	assert_eq(f.shop.info_scroll.scroll_vertical,30)
	assert_eq(f.shop._name_label.text,COPY.item_name("zh_HK","coffee"))
	var card: Button = f.shop.cards.coffee
	preferences.publish_size(110)
	await _settle()
	assert_same(f.shop.cards.coffee,card)
	assert_eq(f.shop._percent,150)

func test_hidden_catalog_and_preferences_defer_without_changing_shared_home_navigation() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	var preferences := Preferences.new()
	assert_true(f.shop.configure_catalog(provider,preferences,preferences).ok)
	await _settle()
	f.shop.cards.wine.grab_focus()
	f.shop.hide_window()
	f.home.grab_focus()
	var home_next: NodePath = f.home.focus_next
	var card: Button = f.shop.cards.wine
	provider.rows[0].legal_max = 2
	provider.catalog_changed.emit()
	preferences.publish_size(150)
	await _settle()
	assert_same(f.shop.cards.wine,card)
	assert_true(f.home.has_focus())
	assert_eq(f.home.focus_next,home_next)
	f.shop.show_window()
	await _settle()
	assert_true(f.shop.cards.wine.has_focus())
	assert_eq(f.shop._percent,150)
	assert_eq(f.shop._records[0].legal_max,2)

func test_modal_custody_defers_reconstruction_and_rejects_synthetic_lower_actions() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	var preferences := Preferences.new()
	assert_true(f.shop.configure_catalog(provider,preferences,preferences).ok)
	await _settle()
	var card: Button = f.shop.cards.wine
	f.shop.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	f.home.grab_focus()
	preferences.publish_size(150)
	f.shop.quantity_buttons.maximum.pressed.emit()
	card.pressed.emit()
	f.shop.next_button.pressed.emit()
	await _settle()
	assert_same(f.shop.cards.wine,card)
	assert_eq(f.shop.quantity,1)
	assert_eq(f.shop.selected_id,"coffee")
	assert_eq(f.shop.page_index,0)
	assert_false(f.shop.can_return_home())
	assert_true(f.home.has_focus())
	f.shop.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	card.grab_focus()
	await _settle()
	assert_true(f.shop.cards.wine.has_focus())
	assert_eq(f.shop._percent,150)
	assert_true(f.shop.can_return_home())

func test_owner_snapshot_cancels_held_native_page_contact_and_provider_failure_is_recoverable() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	assert_true(f.shop.configure_catalog(provider).ok)
	await _settle()
	f.shop.next_button.grab_focus()
	var held := InputEventKey.new()
	held.keycode = KEY_ENTER
	held.physical_keycode = KEY_ENTER
	held.pressed = true
	get_viewport().push_input(held)
	await _settle()
	assert_true(f.shop.next_button.is_pressed())
	assert_false(f.shop.can_return_home())
	provider.rows[0].legal_max = 2
	provider.catalog_changed.emit()
	await _settle()
	var released := InputEventKey.new()
	released.keycode = KEY_ENTER
	released.physical_keycode = KEY_ENTER
	get_viewport().push_input(released)
	await _settle()
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
	assert_eq(f.shop.cards.size(),17)


func test_native_back_keeps_hidden_return_admission_and_cached_semantic_focus() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	assert_true(f.shop.configure_catalog(provider).ok)
	await _settle()
	f.shop.cards.wine.grab_focus()
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
	assert_true(f.shop.cards.wine.has_focus())


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
	f.shop.quantity_buttons.maximum.pressed.emit()
	assert_eq(f.shop.quantity,4)
	f.shop.hide_window()
	f.home.grab_focus()
	preferences.locale = "zh_HK"
	preferences.locale_changed.emit("zh_HK")
	preferences.publish_size(125)
	assert_true(f.shop.refresh_view().ok,"Desktop performs this default cached refresh before preparation")
	assert_true(f.shop.prepare_show_window().ok)
	f.shop.show_window()
	await _settle()
	assert_eq(f.shop.quantity,4)
	assert_eq(f.shop._locale,"zh_HK")
	provider.rows[0].legal_max = 2
	assert_true(f.shop.refresh_view().ok,"An unsignaled changed economic snapshot still resets quantity")
	await _settle()
	assert_eq(f.shop.quantity,1)
	assert_eq(f.shop._records[0].legal_max,2)

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
	assert_true(f.shop.cards.coffee.has_focus())
	retired_launcher.grab_focus()
	provider.rows[0].legal_max = 2
	provider.catalog_changed.emit()
	await _settle()
	assert_eq(f.shop._records[0].legal_max,2,"A retired hidden control has no modal custody")


func test_detached_shop_retires_queued_focus_and_ignores_owner_publications_until_remounted() -> void:
	var f := _fixture()
	await _settle()
	var provider := CatalogProvider.new()
	provider.rows = f.rows
	var preferences := Preferences.new()
	assert_true(f.shop.configure_catalog(provider,preferences,preferences).ok)
	await _settle()
	f.shop.cards.wine.grab_focus()
	var remembered: String = f.shop._remembered_focus
	f.shop._focus_selected.call_deferred()
	f.shop.configure_shop(f.rows,"en",125)
	f.root.remove_child(f.shop)
	f.home.grab_focus()
	assert_true(f.shop.is_node_ready(),"Detached nodes remain ready; readiness is not viewport custody")
	var revision: int = f.shop._measurement_revision
	var calls: int = provider.calls.size()
	provider.rows[0].legal_max = 2
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
	assert_eq(f.shop._records[0].legal_max,2)
	assert_true(f.shop.cards.wine.has_focus())

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
	f.shop.cards.wine.grab_focus()
	provider.rows[0].legal_max = 2
	provider.catalog_changed.emit()
	assert_true(f.shop._catalog_layout_pending)
	assert_false(f.shop.cards.wine.visible,"Rebuild awaits full-font measurement")
	f.root.remove_child(f.shop)
	f.home.grab_focus()
	await _settle()
	assert_true(f.shop._catalog_layout_pending,"Retired deferred work remains pending for this retained view")
	f.root.add_child(f.shop)
	f.shop.show_window()
	await _settle()
	assert_false(f.shop._catalog_layout_pending)
	assert_true(f.shop.last_result.ok)
	assert_true(f.shop.cards.wine.is_visible_in_tree())
	assert_true(f.shop.cards.wine.has_focus())
	assert_eq(f.shop.selected_id,"wine")
	assert_eq(f.shop._records[0].legal_max,2)
	assert_gt(f.shop.cards.wine.size.y,0.0)
