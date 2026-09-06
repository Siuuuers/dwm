extends "res://addons/gut/test.gd"

const SHEET := preload("res://scripts/ui/schedule/ScheduleWarningSheet.gd")
const WELL := preload("res://scripts/ui/schedule/ScheduleScrollWell.gd")
const COPY := {"title":"Placeholder warning","body":"Placeholder body text.","close":"Close","go":"Go"}

func _sheet(large: bool = false) -> Control:
	var sheet: Control = SHEET.new()
	add_child_autofree(sheet)
	assert_true(sheet.configure("en",100,large))
	return sheet

func test_exact_sheet_and_pinned_control_geometry() -> void:
	var sheet: Control = _sheet()
	assert_true(sheet.present("activation-1",COPY))
	assert_eq(sheet._sheet.position,Vector2(120,80))
	assert_eq(sheet._sheet.size,Vector2(560,496))
	assert_eq(sheet.body_scroll.position,Vector2(48,136))
	assert_eq(sheet.body_scroll.size,Vector2(496,264))
	assert_eq(sheet.close_button.position,Vector2(384,32))
	assert_eq(sheet.go_button.position,Vector2(288,424))
	assert_eq(sheet._sheet.get_children().filter(func(child): return child.get_script() == WELL).size(),1)

func test_large_targets_change_only_command_geometry() -> void:
	var sheet: Control = _sheet(true)
	assert_true(sheet.present("activation-1",COPY))
	assert_eq(sheet.close_button.get_rect(),Rect2(384,24,160,64))
	assert_eq(sheet.go_button.get_rect(),Rect2(288,416,256,64))
	assert_eq(sheet.body_scroll.get_rect(),Rect2(48,136,496,264))

func test_invalid_copy_is_atomic() -> void:
	var sheet: Control = _sheet()
	assert_true(sheet.present("activation-1",COPY))
	var old_close: Button = sheet.close_button
	assert_false(sheet.present("activation-2",{"title":"","body":"Body","close":"Close","go":"Go"}))
	assert_eq(sheet.activation_id,"activation-1")
	assert_same(sheet.close_button,old_close)

func test_error_extends_only_scrolled_body() -> void:
	var sheet: Control = _sheet()
	assert_true(sheet.present("activation-1",COPY,"Explicit fixture error."))
	var body: Control = sheet._body_document
	assert_gt(body.custom_minimum_size.y,sheet._height(COPY.body,480))
	assert_eq(sheet.close_button.position,Vector2(384,32))
	assert_eq(sheet.go_button.position,Vector2(288,424))

func test_focus_order_signals_and_busy_state() -> void:
	var sheet: Control = _sheet()
	assert_true(sheet.present("activation-1",COPY))
	await get_tree().process_frame
	assert_true(sheet.close_button.has_focus())
	assert_eq(sheet.close_button.focus_next,sheet.close_button.get_path_to(sheet.go_button))
	assert_eq(sheet.go_button.focus_next,sheet.go_button.get_path_to(sheet.close_button))
	watch_signals(sheet)
	sheet.close_button.pressed.emit()
	sheet.go_button.pressed.emit()
	assert_signal_emitted(sheet,"close_requested")
	assert_signal_emitted(sheet,"go_requested")
	sheet.set_busy(true)
	assert_true(sheet.close_button.disabled)
	assert_true(sheet.go_button.disabled)
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	sheet._unhandled_key_input(cancel)
	assert_signal_emit_count(sheet,"close_requested",1,"Busy Back is consumed without another intent.")
	var page: InputEventAction = InputEventAction.new()
	page.action = "ui_page_down"
	page.pressed = true
	var prior_scroll: int = sheet.body_scroll.scroll_vertical
	sheet._unhandled_key_input(page)
	assert_eq(sheet.body_scroll.scroll_vertical,prior_scroll,"Busy Page is consumed without moving the body.")
	assert_signal_emit_count(sheet,"go_requested",1)

func test_identical_delivery_is_a_true_no_op() -> void:
	var sheet: Control = _sheet()
	var overflow_copy: Dictionary = COPY.duplicate()
	overflow_copy.body = "Caller placeholder sentence. ".repeat(80)
	assert_true(sheet.present("activation-1",overflow_copy))
	await get_tree().process_frame
	var body_label := sheet._body_document.get_child(0) as Label
	assert_eq(body_label.size.x,480.0,"Long body text stays within the registered text measure")
	assert_gt(body_label.get_line_count(),2,"Overflow is vertical wrapped text, not an expanded label")
	assert_almost_eq(body_label.get_minimum_size().y,sheet._height(overflow_copy.body,480),1.0,"Measurement and rendered line spacing agree")
	var old_close: Button = sheet.close_button
	var old_go: Button = sheet.go_button
	sheet.go_button.grab_focus()
	sheet.body_scroll.scroll_vertical = 7
	assert_true(sheet.present("activation-1",overflow_copy))
	assert_same(sheet.close_button,old_close)
	assert_same(sheet.go_button,old_go)
	assert_true(sheet.go_button.has_focus())
	assert_eq(sheet.body_scroll.scroll_vertical,7)

func test_duplicate_configuration_retains_theme_instance() -> void:
	var sheet: Control = _sheet()
	var first_theme: Theme = sheet.theme
	assert_true(sheet.configure("en",100,false,&"after_hours"))
	assert_same(sheet.theme,first_theme)

func test_same_activation_reflow_preserves_semantic_focus() -> void:
	var sheet: Control = _sheet()
	assert_true(sheet.present("activation-1",COPY))
	await get_tree().process_frame
	sheet.go_button.grab_focus()
	var changed: Dictionary = COPY.duplicate()
	changed.body = "Changed caller-provided body."
	assert_true(sheet.present("activation-1",changed))
	await get_tree().process_frame
	assert_true(sheet.go_button.has_focus())
	assert_eq(sheet.activation_id,"activation-1")
	assert_true(sheet.present("activation-1",changed,"Explicit fixture error."))
	await get_tree().process_frame
	assert_true(sheet.close_button.has_focus())

func test_registered_locale_scale_target_matrix_preserves_all_text_geometry() -> void:
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				var sheet := _sheet()
				assert_true(sheet.configure(locale,percent,large,&"midnight"))
				var copy := COPY.duplicate()
				if locale == "zh-CN": copy = {"title":"占位标题","body":"用于布局测试的占位文字。","close":"关闭","go":"前往"}
				elif locale == "zh-HK": copy = {"title":"佔位標題","body":"用於版面測試的佔位文字。","close":"關閉","go":"前往"}
				assert_true(sheet.present("fixture-activation",copy))
				await get_tree().process_frame
				for label: Label in sheet.find_children("*","Label",true,false):
					if label.text == "!": assert_eq(label.size,Vector2(32,32),"The invariant warning mark never grows with text scale")
					assert_lte(label.get_minimum_size().y,label.size.y,"No glyph or text exceeds its exact measure: %s/%d/%s/%s" % [locale,percent,large,label.text])
				sheet.hide()
