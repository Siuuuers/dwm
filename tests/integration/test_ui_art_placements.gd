extends "res://addons/gut/test.gd"

const ART := preload("res://scripts/data/ArtManifest.gd")
const MENU := preload("res://scenes/menu/MenuScene.tscn")
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const CONTACTS := preload("res://scripts/ui/contacts/ContactsPanel.gd")
const MAIN := preload("res://scenes/main/MainGameScene.tscn")
const SHOP := preload("res://scripts/application/shop/ShopPresentationPort.gd")
const SCHEDULE_ART := preload("res://scripts/ui/schedule/ScheduleArtRegistry.gd")
const SCHEDULE_ACTIONS := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

func before_each() -> void:
	ART.reload_placements()

func after_each() -> void:
	ART.reload_placements()

func _place(id: String, file: String, size: Vector2i) -> void:
	ART.set_overlay_info("", id, "res://tests/fixtures/art/" + file, size, "test")

func test_title_desktop_launcher_and_contact_attach_valid_optional_art() -> void:
	_place("ui.title", "ui-960x656.svg", Vector2i(960, 656))
	_place("ui.desktop", "ui-800x656.svg", Vector2i(800, 656))
	_place("launcher.minesweeper", "ui-48.svg", Vector2i(48, 48))
	_place("contact.priscilla.row", "ui-32x64.svg", Vector2i(32, 64))
	var menu := MENU.instantiate()
	add_child_autofree(menu)
	var desktop := DESKTOP.instantiate()
	add_child_autofree(desktop)
	var contacts := CONTACTS.new()
	add_child_autofree(contacts)
	await get_tree().process_frame
	var title_art := menu.get_node_or_null("TitleArtwork") as TextureRect
	assert_not_null(title_art)
	if title_art != null:
		assert_eq(title_art.position, Vector2(320, 64))
		assert_eq(title_art.size, Vector2(960, 656))
	var background := desktop.get_node("DesktopCanvas/BackgroundImage") as TextureRect
	assert_not_null(background.texture)
	assert_eq(background.position, Vector2.ZERO)
	assert_eq(background.offset_top, 0.0)
	assert_eq(background.offset_right, 0.0)
	assert_eq(background.offset_bottom, -64.0)
	var launcher: Button = desktop.launcher_buttons[&"minesweeper"]
	assert_not_null(launcher.get("_icon_texture"))
	assert_not_null(contacts.rows[0].get("portrait_texture"))

func test_missing_and_wrong_sized_art_keep_existing_fallbacks() -> void:
	_place("launcher.minesweeper", "ui-28.svg", Vector2i(28, 28))
	_place("contact.priscilla.row", "ui-48.svg", Vector2i(48, 48))
	var desktop := DESKTOP.instantiate()
	add_child_autofree(desktop)
	var contacts := CONTACTS.new()
	add_child_autofree(contacts)
	await get_tree().process_frame
	assert_null((desktop.launcher_buttons[&"minesweeper"] as Button).get("_icon_texture"))
	assert_null(contacts.rows[0].get("portrait_texture"))
	assert_null(ART.get_texture("missing.consumer.asset"))

func test_shell_layers_share_the_full_art_host_and_preserve_order() -> void:
	for id: String in ["shell.background", "shell.character.angela", "shell.keepsakes"]:
		_place(id, "ui-480x504.svg", Vector2i(480, 504))
	var main := MAIN.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var host := main.get_node("%AngelaImage")
	assert_eq(host.get_global_rect(), main.get_node("%AngelaPanel").get_global_rect())
	assert_true(host.clip_contents, "covered layers cannot bleed across the divider")
	assert_eq(host.get_child_count(), 3)
	assert_eq(host.get_child(0).name, "BackgroundArtwork")
	assert_eq(host.get_child(1).name, "AngelaArtwork")
	assert_eq(host.get_child(2).name, "KeepsakesArtwork")
	for child: TextureRect in host.get_children():
		assert_not_null(child.texture)
		assert_eq(child.position, Vector2.ZERO)
		assert_eq(child.size, host.size)
		assert_eq(child.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		assert_eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_shop_art_uses_valid_exact_sizes_and_wrong_size_keeps_procedural_tile() -> void:
	_place("shop.coffee.card", "ui-28.svg", Vector2i(28, 28))
	_place("shop.coffee.inspector", "ui-48.svg", Vector2i(48, 48))
	var shop := SHOP.new()
	var card: Texture2D = shop.call("_texture", "coffee", 28)
	var inspector: Texture2D = shop.call("_texture", "coffee", 56)
	assert_eq(card.get_size(), Vector2(28, 28))
	assert_eq(inspector.get_size(), Vector2(56, 56))
	assert_eq(card.resource_path, "res://tests/fixtures/art/ui-28.svg")
	assert_true(inspector.resource_path.is_empty(), "wrong-sized optional art retains generated fallback")
func test_schedule_optional_pair_resolves_or_falls_back_without_weakening_action_admission() -> void:
	var loaded: Dictionary = SCHEDULE_ACTIONS.load_current()
	assert_true(loaded.get("ok", false))
	if not loaded.get("ok", false):
		return
	var registry: Object = loaded.value.registry
	var fingerprint: String = registry.fingerprint()
	ART.set_overlay_info("", "schedule.training.compact", "res://assets/ui/schedule/neutral-ticket-compact.svg", Vector2i(24, 24), "test")
	ART.set_overlay_info("", "schedule.training.folio", "res://assets/ui/schedule/neutral-ticket-folio.svg", Vector2i(64, 64), "test")
	var resolved: Dictionary = SCHEDULE_ART.resolve(registry, "training", fingerprint)
	assert_true(resolved.get("ok", false))
	if resolved.get("ok", false):
		assert_eq((resolved.value.compact as Texture2D).get_size(), Vector2(24, 24))
		assert_eq((resolved.value.folio as Texture2D).get_size(), Vector2(64, 64))

	_place("schedule.training.compact", "ui-48.svg", Vector2i(48, 48))
	_place("schedule.training.folio", "ui-48.svg", Vector2i(48, 48))
	var fallback: Dictionary = SCHEDULE_ART.resolve(registry, "training", fingerprint)
	assert_true(fallback.get("ok", false))
	if fallback.get("ok", false):
		assert_eq((fallback.value.compact as Texture2D).resource_path,
			"res://assets/ui/schedule/neutral-ticket-compact.svg")
		assert_eq((fallback.value.folio as Texture2D).resource_path,
			"res://assets/ui/schedule/neutral-ticket-folio.svg")
	var unknown: Dictionary = SCHEDULE_ART.resolve(registry, "not-a-schedule-action", fingerprint)
	assert_false(unknown.get("ok", true))
	assert_eq(unknown.get("code"), "schedule_art_action_unregistered")
