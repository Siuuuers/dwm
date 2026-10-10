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

func test_header_gives_difficulties_room_and_only_displays_rounds_and_mines() -> void:
	var register := _register()
	assert_eq(register.size.x,800.0)
	assert_eq(register.difficulties.keys(),["beginner","intermediate","expert"])
	assert_eq(register.metrics.keys(),["rounds","mine_estimate"])
	assert_eq(register.metrics.rounds.value_copy,"-3/2")
	assert_eq(register.metrics.mine_estimate.value_copy,"-2")
	assert_eq(register.public_view.foresight,125,"Hiding a metric does not discard the published gameplay fact.")
	assert_eq(register.public_view.no_flag,"lost")
	assert_true(register.difficulties.beginner.selected)
	for button: Button in register.difficulties.values():
		assert_gt(button.size.x,96.0)
		assert_true(Rect2(Vector2.ZERO,register.size).encloses(Rect2(button.position,button.size)))

func test_difficulty_requests_include_current_tier_but_commitment_stays_owner_controlled() -> void:
	var register := _register()
	watch_signals(register)
	register.difficulties.beginner.pressed.emit()
	assert_signal_emitted_with_parameters(register,"difficulty_requested",[&"beginner"])
	assert_signal_emit_count(register,"difficulty_requested",1)
	assert_true(register.difficulties.beginner.selected)
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
	assert_signal_emit_count(register,"difficulty_requested",2)

func test_unknown_mines_use_dash_and_hidden_metrics_retain_authoritative_values() -> void:
	var register := _register()
	var view := _view()
	view.mine_estimate = null
	view.foresight = null
	view.no_flag = "intact"
	assert_true(register.present(view))
	assert_eq(register.metrics.mine_estimate.value_copy,"—")
	assert_null(register.public_view.foresight)
	assert_eq(register.public_view.no_flag,"intact")

func test_all_font_scales_preserve_bay_order_and_do_not_shrink_copy() -> void:
	var register := _register()
	var status_start: float = register.metrics.rounds.position.x
	for locale: String in ["en","zh-CN","zh-HK","ja","ko"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				var context := "%s %d%% large=%s" % [locale,percent,large]
				var authored_theme: Theme = preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd").build(locale,percent,&"midnight")
				register.difficulties.expert.grab_focus()
				assert_true(register.configure("desktop_app",locale,percent,large,&"midnight"))
				assert_true(register.difficulties.expert.has_focus(),context)
				assert_true(register.difficulties.beginner.selected,context)
				assert_eq(register.difficulties.keys(),["beginner","intermediate","expert"],context)
				var previous: Button
				for button: Button in register.difficulties.values():
					assert_same(button.theme.default_font,authored_theme.default_font,context)
					assert_eq(button.theme.default_font_size,authored_theme.default_font_size,context)
					assert_gt(button.size.x,96.0)
					assert_gte(button.size.y,64.0 if large else 48.0)
					assert_eq(button._paragraph.get_line_count(),1,context+" "+button.public_copy)
					assert_false(Rect2(button.position,button.size).intersects(Rect2(register.metrics.rounds.position,register.metrics.rounds.size)),context+" difficulty cannot collide with status fields")
					if previous != null: assert_lte(previous.position.x+previous.size.x,button.position.x,context)
					previous = button
				for metric: Control in register.metrics.values():
					assert_same(metric.theme.default_font,authored_theme.default_font,context)
					assert_eq(metric.theme.default_font_size,authored_theme.default_font_size,context)
					assert_eq(metric.label_shape.paragraph.get_line_count(),1,context+" "+metric.label_copy)
					assert_true(Rect2(Vector2.ZERO,register.size).encloses(Rect2(metric.position,metric.size)),context)
					assert_eq(metric.position.y+metric.size.y,register.size.y)
					assert_lte(metric.label_shape.height+metric.value_shape.height+16,register.size.y)
				if register.metrics.rounds.position.y == 0:
					assert_lte(register.metrics.rounds.position.x,status_start,context+" single-row status can borrow spare difficulty width")
				else:
					assert_eq(register.metrics.rounds.position.x,0.0,context+" full-width second row")
				assert_lte(register.metrics.rounds.position.x+register.metrics.rounds.size.x,register.metrics.mine_estimate.position.x,context+" status fields do not overlap")
				assert_eq(register.metrics.mine_estimate.position.x+register.metrics.mine_estimate.size.x,register.size.x,context)
				assert_eq(fmod(register.size.y,2.0),0.0)

func test_canonical_blank_capacity_has_no_placeholder_control_or_difficulty() -> void:
	var register: Control = REGISTER.new()
	add_child_autofree(register)
	assert_true(register.configure("canonical_pair","zh-HK",150,true))
	assert_true(register.present({"mine_estimate":36,"foresight":100,"no_flag":"intact","custody":false}))
	assert_eq(register.size.x,960.0)
	assert_true(register.difficulties.is_empty())
	assert_eq(register.metrics.keys(),["mine_estimate"])
	for host: String in ["canonical_solo","canonical_pair"]:
		for locale: String in ["en","zh-CN","zh-HK","ja","ko"]:
			for percent: int in [100,125,150]:
				for large: bool in [false,true]:
					var context := "%s %s %d%% large=%s" % [host,locale,percent,large]
					var authored_theme: Theme = preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd").build(locale,percent,&"midnight")
					assert_true(register.configure(host,locale,percent,large,&"midnight"),context)
					var metric: Control = register.metrics.mine_estimate
					assert_true(register.difficulties.is_empty(),context)
					assert_eq(register.metrics.keys(),["mine_estimate"],context)
					assert_same(metric.theme.default_font,authored_theme.default_font,context)
					assert_eq(metric.theme.default_font_size,authored_theme.default_font_size,context)
					assert_eq(metric.label_shape.paragraph.get_line_count(),1,context)
					assert_true(Rect2(Vector2.ZERO,register.size).encloses(Rect2(metric.position,metric.size)),context)
					assert_eq(metric.position.x+metric.size.x,register.size.x,context+" metric remains right-aligned")
					assert_lte(metric.label_shape.height+metric.value_shape.height+16,register.size.y,context)
	assert_false(register.present(_view()))

func test_large_text_does_not_reintroduce_hidden_challenge_metrics() -> void:
	var register := _register()
	assert_true(register.configure("desktop_app","en",150,true))
	assert_false(register.metrics.has("foresight"))
	assert_false(register.metrics.has("no_flag"))
	assert_eq(register.public_view.foresight,125)
	assert_eq(register.public_view.no_flag,"lost")

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
	assert_eq(register.public_view.foresight,125)
	var malformed := _view()
	malformed.no_flag = "qualifying"
	assert_false(register.present(malformed))
	assert_eq(register.public_view.no_flag,"lost","A refused publication leaves hidden facts untouched too.")
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
