extends "res://addons/gut/test.gd"

const SHEET := preload("res://scripts/ui/minesweeper/MinesweeperInformationSheet.gd")
const ASSIGNMENTS := preload("res://scripts/application/minesweeper/MinesweeperAssignmentsQuery.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")

func _sheet(locale: String = "en", percent: int = 100, large: bool = false) -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	add_child_autofree(viewport)
	var sheet: Control = SHEET.new()
	viewport.add_child(sheet)
	assert_true(sheet.configure("desktop_app",locale,percent,large))
	return sheet

func test_baseline_rules_fit_exact_bands_with_four_readonly_rows() -> void:
	var sheet := _sheet()
	assert_true(sheet.present_rules())
	assert_eq(sheet.size,Vector2(800,492))
	assert_eq(sheet.body.position,Vector2(16,72))
	assert_eq(sheet.body.size,Vector2(768,332))
	assert_eq(sheet.return_button.position,Vector2(656,420))
	assert_eq(sheet.return_button.size,Vector2(128,48))
	assert_eq(sheet.rows.size(),4)
	assert_null(sheet.rail)
	assert_true(sheet.rows[0].has_focus())
	assert_eq(sheet.rows[0].focus_previous,sheet.rows[0].get_path_to(sheet.return_button))
	assert_eq(sheet.return_button.focus_next,sheet.return_button.get_path_to(sheet.rows[0]))

func test_assignment_status_is_required_and_all_nine_rows_scroll_without_claim_actions() -> void:
	var sheet := _sheet()
	assert_false(sheet.present_assignments([]))
	assert_false(sheet.present_assignments([false,false,false,false,false,false,false,false,0]))
	assert_true(sheet.present_assignments([true,false,false,false,false,false,false,false,true]))
	assert_eq(sheet.rows.size(),9)
	assert_not_null(sheet.rail)
	assert_eq(sheet.rows[0].accessibility_name,"Complete Beginner — Claimed")
	assert_eq(sheet.rows[1].accessibility_name,"Complete Intermediate — Unclaimed")
	assert_eq(sheet.rows[8].accessibility_name,"Complete all three tiers — Claimed")
	for row: Control in sheet.rows: assert_false(row.has_signal("pressed"))
	sheet.rows[8].grab_focus()
	assert_gt(sheet.get_scroll(),0)
	assert_true(Rect2(Vector2.ZERO,sheet.body.size).encloses(Rect2(sheet.document.position+sheet.rows[8].position,sheet.rows[8].size)),"body=%s row=%s scroll=%s" % [sheet.body.size,Rect2(sheet.document.position+sheet.rows[8].position,sheet.rows[8].size),sheet.get_scroll()])

func test_locale_scale_large_and_both_palettes_preserve_full_font_and_row_capacity() -> void:
	var sheet := _sheet()
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				for palette: StringName in [&"after_hours",&"midnight"]:
					assert_true(sheet.configure("desktop_app",locale,percent,large,palette))
					assert_true(sheet.present_rules())
					assert_eq(sheet.theme.default_font_size,20*percent/100)
					assert_eq(sheet.rows.size(),4)
					for row: Control in sheet.rows:
						assert_gte(row.size.y,64.0 if large else 48.0)
						assert_lte(row.size.y,sheet.body.size.y)
					if percent == 100: assert_null(sheet.rail,"All baseline Rules rows fit.")
					assert_true(sheet.present_assignments([false,false,false,false,false,false,false,false,false]))
					assert_not_null(sheet.rail)

func test_invalid_configure_or_status_keeps_current_sheet_focus_and_scroll() -> void:
	var sheet := _sheet()
	assert_true(sheet.present_assignments([false,false,false,false,false,false,false,false,false]))
	sheet.rows[8].grab_focus()
	var prior: Control = sheet.rows[8]
	var scroll: int = sheet.get_scroll()
	assert_false(sheet.configure("unknown"))
	assert_false(sheet.configure("desktop_app","en",100,false,&"after_hours",Vector2i(400,50)))
	assert_false(sheet.present_assignments([true]))
	assert_same(sheet.rows[8],prior)
	assert_true(prior.has_focus())
	assert_eq(sheet.get_scroll(),scroll)

func test_back_and_return_are_only_dismissals_and_repeat_is_ignored() -> void:
	var sheet := _sheet()
	assert_true(sheet.present_rules())
	watch_signals(sheet)
	var outside := InputEventMouseButton.new()
	outside.position = Vector2(2,2)
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	sheet.get_viewport().push_input(outside,true)
	assert_signal_emit_count(sheet,"return_requested",0)
	var back := InputEventKey.new()
	back.keycode = KEY_ESCAPE
	back.pressed = true
	back.echo = true
	sheet._unhandled_input(back)
	assert_signal_emit_count(sheet,"return_requested",0)
	back.echo = false
	sheet._unhandled_input(back)
	assert_signal_emit_count(sheet,"return_requested",1)
	sheet.return_button.pressed.emit()
	assert_signal_emit_count(sheet,"return_requested",2)

func test_canonical_rules_have_wide_band_but_no_assignment_surface() -> void:
	var sheet := _sheet()
	assert_true(sheet.configure("canonical_pair","zh-HK",150,true,&"midnight"))
	assert_true(sheet.present_rules())
	assert_eq(sheet.size,Vector2(960,464))
	assert_false(sheet.present_assignments([false,false,false,false,false,false,false,false,false]))

func test_real_run_receipts_reach_sheet_without_claiming_or_changing_save_state() -> void:
	var state := GAME_STATE.new()
	state.reset_game()
	state.check_and_claim_minesweeper_task_rewards({"task_ids":["complete_beginner","complete_intermediate","complete_expert"]})
	var before: Dictionary = state.to_save_dict().duplicate(true)
	var sheet := _sheet()
	sheet.set_scroll(999)
	var query: Dictionary = ASSIGNMENTS.from_sources(state,CATALOG.new())
	assert_true(query.ok)
	assert_true(sheet.present_assignments(query.value))
	assert_eq(sheet.rows[8].accessibility_name,"Complete all three tiers — Claimed")
	sheet.rows[8].grab_focus()
	assert_eq(state.to_save_dict(),before)
	state.free()
