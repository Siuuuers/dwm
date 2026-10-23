extends "res://addons/gut/test.gd"
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const EDGE := preload("res://scripts/ui/desktop/QuickStatusEdge.gd")

func _edge() -> Label:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,360)
	add_child_autofree(viewport)
	var edge: Label = EDGE.new()
	edge.size.x = 240
	viewport.add_child(edge)
	edge.set_process(false)
	watch_signals(edge)
	return edge

func test_saved_and_refusal_expire_on_exact_eligible_lifetime() -> void:
	var edge := _edge()
	edge.set_eligible(true)
	for status: StringName in [&"saved",&"unavailable",&"please_wait",&"no_quick_save",
			&"older_version",&"newer_version",&"unreadable",&"no_compatible_checkpoint",&"restore_unavailable"]:
		edge.publish_status(status,{"revision":1},func(): return true)
		var duration := 2.0 if status == &"saved" else 4.0
		assert_eq(edge.remaining_seconds,duration)
		edge.advance_eligible_time(duration-0.125)
		assert_true(edge.visible)
		edge.advance_eligible_time(0.125)
		assert_false(edge.visible)
		assert_eq(edge.key,&"")
		assert_eq(edge.text,"")

func test_suppression_preserves_time_and_does_not_repeat_announcement() -> void:
	var edge := _edge()
	edge.set_eligible(true)
	edge.publish_status(&"saved",{"run":"one"},func(): return true)
	edge.advance_eligible_time(0.5)
	edge.set_eligible(false)
	edge.advance_eligible_time(50)
	assert_false(edge.visible)
	assert_eq(edge.remaining_seconds,1.5)
	edge.set_eligible(true)
	assert_true(edge.visible)
	assert_eq(edge.accessibility_live,DisplayServer.LIVE_OFF)
	assert_signal_emit_count(edge,"status_announced",1)
	edge.advance_eligible_time(1.5)
	assert_false(edge.visible)

func test_delayed_publication_revalidates_and_stale_fact_never_announces() -> void:
	var edge := _edge()
	var valid := [true]
	edge.publish_status(&"unavailable",{"route":"main"},func(): return valid[0])
	assert_false(edge.visible)
	assert_signal_not_emitted(edge,"status_announced")
	valid[0] = false
	edge.set_eligible(true)
	assert_eq(edge.key,&"")
	assert_signal_not_emitted(edge,"status_announced")

func test_duplicate_retains_timer_but_new_binding_announces_new_fact() -> void:
	var edge := _edge()
	edge.set_eligible(true)
	var source := {"condition":{"revision":1}}
	edge.publish_status(&"unavailable",source,func(): return true)
	edge.advance_eligible_time(1.0)
	edge.publish_status(&"unavailable",source,func(): return true)
	assert_eq(edge.remaining_seconds,3.0)
	assert_signal_emit_count(edge,"status_announced",1)
	source.condition.revision = 2
	var detached: Dictionary = edge.current_binding
	detached.condition.revision = 9
	assert_eq(edge.current_binding.condition.revision,1)
	edge.publish_status(&"unavailable",source,func(): return true)
	assert_eq(edge.remaining_seconds,4.0)
	assert_signal_emit_count(edge,"status_announced",2)

func test_validator_is_throttled_and_changed_condition_clears() -> void:
	var edge := _edge()
	var checks := [0]
	var valid := [true]
	edge.set_eligible(true)
	edge.publish_status(&"please_wait",{},func(): checks[0] += 1; return valid[0])
	assert_eq(checks[0],1)
	for frame in 12: edge.advance_eligible_time(0.02)
	assert_eq(checks[0],1)
	valid[0] = false
	edge.advance_eligible_time(0.02)
	assert_eq(checks[0],2)
	assert_false(edge.visible)
	assert_eq(edge.key,&"")

func test_saving_has_no_fake_minimum_or_expiry() -> void:
	var edge := _edge()
	edge.set_eligible(true)
	edge.publish_status(&"saving",{},func(): return true)
	edge.advance_eligible_time(100)
	assert_true(edge.visible)
	assert_eq(edge.text,"Saving…")
	edge.publish_status(&"saved",{},func(): return true)
	assert_eq(edge.text,"Saved")
	assert_eq(edge.remaining_seconds,2.0)
	assert_signal_emit_count(edge,"status_announced",2)

func test_full_localized_font_reflow_does_not_reannounce_or_reset() -> void:
	var edge := _edge()
	edge.set_eligible(true)
	edge.publish_status(&"please_wait",{},func(): return true)
	edge.advance_eligible_time(1)
	for font_style: String in ["pixel","readable"]:
		for locale: String in ["en","zh_CN","zh_HK","ja","ko"]:
			for percent: int in [100,125,150]:
				edge.set_presentation(locale,percent,font_style)
				assert_eq(edge.get_theme_default_font_size(),int(24*percent/100.0))
				assert_same(edge.theme.default_font,TYPOGRAPHY.font(locale,percent,font_style))
				assert_eq(edge.text,EDGE.COPY[locale.replace("_","-")][&"please_wait"])
				assert_eq(edge.accessibility_name,edge.text)
				assert_eq(edge.remaining_seconds,3.0)
				assert_eq(edge.max_lines_visible,-1)
				assert_false(edge.clip_text)
	assert_signal_emit_count(edge,"status_announced",1)

func test_quick_absence_and_inspected_reasons_localize_once_and_retire_when_stale() -> void:
	var edge := _edge()
	edge.set_eligible(true)
	var expected := {
		&"no_quick_save": "No Quick Save",
		&"older_version": "This save is from an older build and cannot be loaded.",
		&"newer_version": "Newer game version required.",
		&"unreadable": "Can't read this save.",
		&"no_compatible_checkpoint": "No compatible checkpoint is available.",
		&"restore_unavailable": "This save cannot currently be loaded.",
	}
	var announcements := 0
	for status: StringName in expected:
		var current := [true]
		edge.set_presentation("en",100)
		edge.publish_status(status,{"record":str(status)},func(): return current[0])
		announcements += 1
		assert_eq(edge.text,expected[status])
		assert_eq(edge.accessibility_name,edge.text)
		edge.advance_eligible_time(1.0)
		for locale: String in ["en","zh_CN","zh_HK","ja","ko"]:
			edge.set_presentation(locale,150,"readable")
			var normalized := locale.replace("_","-")
			var localized: String = EDGE.COPY[normalized][status] if status == &"no_quick_save" else EDGE.BACKUP.COPY[normalized][EDGE.REASON_COPY_KEYS[status]]
			assert_eq(edge.text,localized)
			assert_eq(edge.accessibility_name,localized)
			assert_eq(edge.remaining_seconds,3.0)
			assert_eq(edge.accessibility_live,DisplayServer.LIVE_OFF)
		assert_signal_emit_count(edge,"status_announced",announcements)
		current[0] = false
		edge.advance_eligible_time(0.25)
		assert_eq(edge.key,&"")
		assert_false(edge.visible)
		assert_signal_emit_count(edge,"status_announced",announcements)

func test_edge_is_one_inert_label_and_does_not_capture_native_pointer_focus() -> void:
	var edge := _edge()
	var button := Button.new()
	button.size = Vector2(240,80)
	button.text = "Source"
	edge.get_viewport().add_child(button)
	edge.move_to_front()
	button.grab_focus()
	watch_signals(button)
	edge.set_eligible(true)
	edge.publish_status(&"saved",{},func(): return true)
	assert_eq(edge.focus_mode,Control.FOCUS_NONE)
	assert_eq(edge.mouse_filter,Control.MOUSE_FILTER_IGNORE)
	assert_eq(edge.get_child_count(),0)
	assert_eq(edge.accessibility_live,DisplayServer.LIVE_POLITE)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = Vector2(20,20)
		event.pressed = pressed
		edge.get_viewport().push_input(event,true)
	assert_signal_emit_count(button,"pressed",1)
	assert_true(button.has_focus())

func test_validator_reentrancy_cannot_clear_a_replacement() -> void:
	var edge := _edge()
	edge.publish_status(&"unavailable",{},func():
		edge.publish_status(&"saved",{"new":true},func(): return true)
		return false)
	edge.set_eligible(true)
	assert_eq(edge.key,&"saved")
	assert_eq(edge.text,"Saved")
	assert_signal_emit_count(edge,"status_announced",1)

func test_hidden_parent_defers_announcement_and_time() -> void:
	var edge := _edge()
	var parent := Control.new()
	edge.get_viewport().add_child(parent)
	edge.reparent(parent)
	parent.hide()
	edge.set_eligible(true)
	edge.publish_status(&"saved",{},func(): return true)
	edge.advance_eligible_time(20)
	assert_signal_not_emitted(edge,"status_announced")
	assert_eq(edge.remaining_seconds,2.0)
	parent.show()
	edge.advance_eligible_time(0)
	assert_signal_emit_count(edge,"status_announced",1)
	assert_true(edge.is_visible_in_tree())
