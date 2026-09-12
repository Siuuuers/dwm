extends "res://addons/gut/test.gd"

const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

class Preferences extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var values: Dictionary = {}
	var writes: Array[Dictionary] = []
	var refuse := false
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return values.get(String(path), fallback)
	func set_preferences(changes: Dictionary) -> Dictionary:
		writes.append(changes.duplicate())
		if refuse: return {"ok":false}
		for path: StringName in changes:
			values[String(path)] = changes[path]
			preference_changed.emit(path, changes[path])
		return {"ok":true}

func _worksheet(profile: Object = null, scope: String = "app_expert") -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	add_child_autofree(viewport)
	var sheet: Control = WORKSHEET.new()
	viewport.add_child(sheet)
	assert_true(sheet.configure())
	assert_true(sheet.bind_view_preferences(profile, scope))
	assert_true(sheet.present(QUERY.desktop(STATE.new().capture(), "expert", true).value))
	return sheet

func test_default_manual_size_and_fit_restore_do_not_change_the_board() -> void:
	var sheet := _worksheet()
	var before: Dictionary = sheet.grid.projection.duplicate(true)
	assert_eq(sheet.cell_size,36)
	assert_false(sheet.always_fit)
	assert_almost_eq(sheet.geometry.target*2.0,36.0,0.001)
	assert_not_null(sheet.vertical_rail)
	assert_true(sheet.set_always_fit(true))
	assert_true(Rect2(Vector2.ZERO,sheet.well.size).encloses(Rect2(sheet.grid.position,sheet.grid.size*sheet.grid.scale)))
	assert_eq(sheet.cell_size,36)
	assert_true(sheet.set_always_fit(false))
	assert_almost_eq(sheet.geometry.target*2.0,36.0,0.001)
	assert_eq(sheet.grid.projection,before)

func test_scope_switch_and_reopening_restore_permanent_preferences() -> void:
	var profile := Preferences.new()
	var sheet := _worksheet(profile)
	assert_true(sheet.step_zoom(2))
	assert_eq(sheet.cell_size,40)
	assert_true(sheet.set_view_scope("challenge"))
	assert_eq(sheet.cell_size,36)
	assert_true(sheet.set_always_fit(true))
	assert_true(sheet.set_view_scope("app_expert"))
	assert_eq(sheet.cell_size,40)
	assert_false(sheet.always_fit)
	var reopened := _worksheet(profile,"challenge")
	assert_true(reopened.always_fit)
	assert_eq(reopened.cell_size,36)
	assert_true(sheet.set_view_scope("app_beginner"))
	assert_eq(sheet.cell_size,36)

func test_manual_step_from_fit_starts_at_displayed_size_and_preserves_anchor() -> void:
	var sheet := _worksheet()
	assert_true(sheet.set_always_fit(true))
	var fitted: float = sheet.geometry.target*2.0
	var expected := clampi(roundi(fitted/2.0)*2+2,10,60)
	assert_true(sheet.step_zoom(1))
	assert_false(sheet.always_fit)
	assert_eq(sheet.cell_size,expected)
	assert_true(sheet.step_zoom(50))
	assert_eq(sheet.cell_size,60)
	assert_true(sheet.step_zoom(-50))
	assert_eq(sheet.cell_size,10)

func test_rapid_wheel_updates_are_immediate_and_flush_as_one_preference_transaction() -> void:
	var profile := Preferences.new()
	var sheet := _worksheet(profile)
	var before: Dictionary = sheet.grid.projection.duplicate(true)
	for index in 4: assert_true(sheet.step_zoom(1,Vector2(100,100),true))
	assert_eq(sheet.cell_size,44)
	assert_eq(profile.writes.size(),0)
	assert_true(sheet.flush_view_preferences())
	assert_eq(profile.writes.size(),1)
	assert_eq(profile.writes[0].size(),2)
	assert_eq(sheet.grid.projection,before)

func test_preference_write_refusal_restores_last_saved_view() -> void:
	var profile := Preferences.new()
	var sheet := _worksheet(profile)
	profile.refuse = true
	assert_false(sheet.step_zoom(1))
	assert_eq(sheet.cell_size,36)
	assert_false(sheet.always_fit)
	assert_true(sheet.view_save_failed)

func test_large_targets_and_text_size_do_not_change_selected_cell_size() -> void:
	var sheet := _worksheet()
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			assert_true(sheet.configure("desktop_app",locale,percent,true))
			assert_almost_eq(sheet.geometry.target*2.0,36.0,0.001)
			assert_eq(sheet.zoom_controls.size(),3)
			for control: Control in sheet.zoom_controls:
				assert_true(Rect2(Vector2.ZERO,sheet.size).encloses(Rect2(control.position,control.size)))

func test_sheet_and_held_cell_block_zoom_without_writing_preferences() -> void:
	var profile := Preferences.new()
	var sheet := _worksheet(profile)
	assert_true(sheet.open_rules())
	assert_false(sheet.step_zoom(1))
	assert_false(sheet.set_always_fit(true))
	sheet.close_information()
	sheet.grid._held_index = 1
	assert_false(sheet.step_zoom(1))
	assert_eq(profile.writes.size(),0)
