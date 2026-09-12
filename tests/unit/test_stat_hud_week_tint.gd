extends "res://addons/gut/test.gd"

const HUD := preload("res://scenes/shared/StatHud.tscn")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")


class OwnerFixture extends Node:
	signal day_changed(day: int)
	var day: int = 1
	var money: int = 0
	var coins: int = 0
	var condition_effects_today: Array = []
	var penalty_points_today: int = 0
	func get_stat_display_value(_stat: String) -> int: return 0
	func get_stat_display_max(_stat: String) -> int: return 9
	func advance_to(new_day: int) -> void:
		day = new_day
		day_changed.emit(new_day)


func _fixture() -> Dictionary:
	var owner := OwnerFixture.new()
	var hud: Control = HUD.instantiate()
	hud.configure(owner)
	add_child_autofree(hud)
	add_child_autofree(owner)
	return {"hud": hud, "owner": owner}


func test_day_one_hud_theme_is_the_shipped_face() -> void:
	var f := _fixture()
	assert_eq(f.hud.theme.get_color("face", "Desktop"), Color("151b25"))


func test_day_changed_rebuilds_the_hud_theme_with_the_tint() -> void:
	var f := _fixture()
	f.owner.advance_to(7)
	var expected := DESKTOP_THEME.build("en", 100, &"after_hours", WEEK_TINT.tint_for_day(7))
	assert_eq(f.hud.theme.get_color("face", "Desktop"), expected.get_color("face", "Desktop"))
	assert_ne(f.hud.theme.get_color("face", "Desktop"), Color("151b25"))
	assert_eq(f.hud.theme.get_color("ink", "Desktop"), Color("d8cfb7"), "ink never tints")


func test_same_day_refresh_keeps_the_cached_theme_instance() -> void:
	var f := _fixture()
	f.owner.advance_to(4)
	var built: Theme = f.hud.theme
	f.hud.refresh_all()
	assert_true(f.hud.theme == built, "no rebuild when locale, size and day are unchanged")
