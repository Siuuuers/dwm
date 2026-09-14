extends "res://addons/gut/test.gd"

const REGISTER := preload("res://scripts/ui/minesweeper/MinesweeperRegister.gd")

func _view() -> Dictionary:
	return {"difficulty":"beginner","rounds":-3,"mine_estimate":-2,"foresight":125,"no_flag":"lost","custody":false,"difficulty_enabled":["beginner","intermediate","expert"]}

func _register() -> Control:
	var register: Control = REGISTER.new()
	add_child_autofree(register)
	assert_true(register.configure())
	assert_true(register.present(_view()))
	return register

func test_exact_bays_present_signed_public_values_without_metric_operands() -> void:
	var register := _register()
	assert_eq(register.size.x,800.0)
	assert_eq(register.difficulties.keys(),["beginner","intermediate","expert"])
	assert_eq(register.metrics.keys(),["rounds","mine_estimate","foresight","no_flag"])
	assert_eq(register.metrics.rounds.position.x,288.0)
	assert_eq(register.metrics.mine_estimate.position.x,400.0)
	assert_eq(register.metrics.foresight.position.x,544.0)
	assert_eq(register.metrics.no_flag.position.x,672.0)
	assert_eq(register.metrics.rounds.value_copy,"-3/2")
	assert_eq(register.metrics.mine_estimate.value_copy,"-2")
	assert_eq(register.metrics.foresight.value_copy,"125%")
	assert_eq(register.metrics.no_flag.value_copy,"Lost")
	assert_true(register.difficulties.beginner.selected)
	assert_eq(register.metrics.foresight.accessibility_name,"Foresight: 125%")
	for button: Button in register.difficulties.values():
		assert_eq(button.size.x,96.0)
		assert_gte(button.position.y,22.0)

func test_difficulty_commitment_is_owner_controlled_and_same_tier_is_inert() -> void:
	var register := _register()
	watch_signals(register)
	register.difficulties.beginner.pressed.emit()
	assert_signal_emit_count(register,"difficulty_requested",0)
	register.difficulties.expert.pressed.emit()
	assert_signal_emitted_with_parameters(register,"difficulty_requested",[&"expert"])
	assert_true(register.difficulties.beginner.selected)
	var view := _view()
	view.difficulty = "expert"
	view.custody = true
	view.difficulty_enabled = []
	assert_true(register.present(view))
	assert_true(register.difficulties.expert.selected)
	for button: Button in register.difficulties.values():
		assert_true(button.disabled)
		assert_eq(button.focus_mode,Control.FOCUS_NONE)
	register.difficulties.beginner.pressed.emit()
	assert_signal_emit_count(register,"difficulty_requested",1)

func test_unknown_metrics_use_dash_and_no_flag_does_not_become_forecast() -> void:
	var register := _register()
	var view := _view()
	view.mine_estimate = null
	view.foresight = null
	view.no_flag = "intact"
	assert_true(register.present(view))
	assert_eq(register.metrics.mine_estimate.value_copy,"—")
	assert_eq(register.metrics.foresight.value_copy,"—")
	assert_eq(register.metrics.no_flag.value_copy,"Intact")

func test_all_font_scales_preserve_bay_order_and_do_not_shrink_copy() -> void:
	var register := _register()
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				assert_true(register.configure("desktop_app",locale,percent,large,&"midnight"))
				for button: Button in register.difficulties.values():
					assert_eq(button.theme.default_font_size,20*percent/100)
					assert_eq(button.size.x,96.0)
					assert_gte(button.size.y,64.0 if large else 48.0)
				for metric: Control in register.metrics.values():
					assert_eq(metric.size.y,register.size.y)
					assert_lte(metric.label_shape.height+metric.value_shape.height+16,register.size.y)
				assert_eq(fmod(register.size.y,2.0),0.0)

func test_canonical_blank_capacity_has_no_placeholder_control_or_difficulty() -> void:
	var register: Control = REGISTER.new()
	add_child_autofree(register)
	assert_true(register.configure("canonical_pair","zh-HK",150,true))
	assert_true(register.present({"mine_estimate":36,"foresight":100,"no_flag":"intact","custody":false}))
	assert_eq(register.size.x,960.0)
	assert_true(register.difficulties.is_empty())
	assert_eq(register.get_child_count(),3)
	for metric: Control in register.metrics.values(): assert_gte(metric.position.x,560.0)
	assert_false(register.present(_view()))

func test_large_foresight_label_wraps_at_word_parts_without_changing_metric_truth() -> void:
	var register := _register()
	assert_true(register.configure("desktop_app","en",150,true))
	var metric: Control = register.metrics.foresight
	assert_eq(metric.size.x,128.0)
	assert_eq(metric.label_copy,"Foresight")
	assert_eq(metric.value_copy,"125%")
	assert_eq(metric.accessibility_name,"Foresight: 125%")
	assert_eq(metric.theme.default_font_size,30)
	assert_eq(metric.label_shape.paragraph.get_line_count(),2)
	assert_almost_eq(metric.label_shape.paragraph.get_line_width(0),metric.theme.default_font.get_string_size("Fore-",HORIZONTAL_ALIGNMENT_LEFT,-1,30).x,0.01)

func test_invalid_or_private_input_preserves_existing_facts() -> void:
	var register := _register()
	var original: Dictionary = register.public_view.duplicate(true)
	var malformed := _view()
	malformed.three_bv = 50
	assert_false(register.present(malformed))
	malformed = _view()
	malformed.no_flag = "qualifying"
	assert_false(register.present(malformed))
	malformed = _view()
	malformed.rounds = 0.5
	assert_false(register.present(malformed))
	malformed = _view()
	malformed.difficulty_enabled = ["expert","expert"]
	assert_false(register.present(malformed))
	assert_eq(register.public_view,original)

func test_repeated_present_retains_every_difficulty_button_and_metric_control() -> void:
	var register := _register()
	var retained_buttons: Dictionary = register.difficulties.duplicate()
	var retained_metrics: Dictionary = register.metrics.duplicate()
	var children: int = register.get_child_count()
	var view := _view()
	view.rounds = 1
	view.mine_estimate = 8
	assert_true(register.present(view))
	assert_eq(register.get_child_count(),children)
	for key: String in retained_buttons: assert_same(register.difficulties[key],retained_buttons[key],key)
	for key: String in retained_metrics: assert_same(register.metrics[key],retained_metrics[key],key)
	assert_eq(register.metrics.rounds.value_copy,"1/2")
	assert_eq(register.metrics.mine_estimate.value_copy,"8")
	assert_eq(register.metrics.foresight.value_copy,"125%")
	var malformed := _view()
	malformed.no_flag = "qualifying"
	assert_false(register.present(malformed))
	assert_eq(register.metrics.no_flag.value_copy,"Lost","a refused publication leaves every bay untouched")
	for key: String in retained_metrics: assert_same(register.metrics[key],retained_metrics[key],key)

func test_retained_difficulty_button_keeps_its_focus_and_commitment_signal() -> void:
	var register := _register()
	var expert: Button = register.difficulties.expert
	expert.grab_focus()
	var view := _view()
	view.mine_estimate = 7
	assert_true(register.present(view))
	assert_same(register.difficulties.expert,expert,"a published metric change cannot replace a focused bay")
	assert_true(expert.has_focus())
	watch_signals(register)
	expert.pressed.emit()
	assert_signal_emitted_with_parameters(register,"difficulty_requested",[&"expert"])
