extends "res://addons/gut/test.gd"

const PANEL := preload("res://scripts/ui/schedule/SchedulePanel.gd")
const ART := preload("res://scripts/ui/schedule/ScheduleArtRegistry.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
var _art: Dictionary

func before_each() -> void:
	var loaded := REGISTRY.load_current()
	_art = ART.resolve(loaded.value.registry,"training",loaded.value.registry_fingerprint).value

func _panel(locale: String = "en", percent: int = 100, large: bool = false) -> Control:
	var panel := PANEL.new()
	add_child_autofree(panel)
	assert_true(panel.configure(locale,percent,large))
	panel.set_done_enabled(true)
	return panel

func _source(id: String, label: String, available: bool = true) -> Dictionary:
	return {"id":id,"name":label,"available":available,"compact":_art.compact,"folio":_art.folio}

func _entry(id: String, label: String, source_id: String = "training") -> Dictionary:
	return {"id":id,"name":label,"source_id":source_id,"folio":_art.folio}

func _projection(entries: Array = [], day7: bool = false, sources: Array = []) -> Dictionary:
	return {"day_seven":day7,"entries":entries,"sources":sources}

func test_empty_day_seven_has_only_done_and_two_scroll_owners() -> void:
	var panel := _panel()
	assert_true(panel.set_projection(_projection([],true)))
	await get_tree().process_frame
	assert_eq(panel.entry_buttons.size(),0)
	assert_eq(panel.commands.size(),0)
	assert_eq(panel.find_children("*","ScrollContainer",true,false).size(),2)
	assert_eq(panel._docket_body.get_children().size(),2,"Empty folio and inert witness container only; no slot or rule residue.")
	assert_eq(panel._docket_body.boundaries.size(),0)
	assert_eq(panel._docket_body.witness,-1)
	panel.focus_target()
	assert_true(panel.done_button.has_focus())

func test_inspection_is_distinct_from_focus_and_orders_commands() -> void:
	var panel := _panel()
	assert_true(panel.set_projection(_projection([_entry("a","Training"),_entry("b","Rest")],false,[_source("training","Training")])))
	assert_eq(panel.commands.size(),0)
	panel.entry_buttons.a.pressed.emit()
	assert_eq(panel.selected_id,"a")
	assert_true(panel.commands.earlier.disabled)
	assert_false(panel.commands.later.disabled)
	panel.source_buttons.training.grab_focus()
	assert_true(panel.entry_buttons.a.selected)
	watch_signals(panel)
	panel.commands.later.pressed.emit()
	assert_signal_emitted_with_parameters(panel,"move_requested",["a",1])
	panel.commands.remove.pressed.emit()
	assert_signal_emitted_with_parameters(panel,"remove_requested",["a"])

func test_day_seven_shows_selected_source_and_remove_without_order_controls() -> void:
	var panel := _panel()
	assert_true(panel.set_projection(_projection([_entry("a","Priscilla","priscilla")],true,[_source("priscilla","Priscilla")])) )
	assert_true(panel.source_buttons.priscilla.selected)
	assert_false(panel.entry_buttons.a.selected)
	assert_eq(panel.commands.keys(),["remove"])
	assert_eq(panel.entry_buttons.a.accessibility_name,"Priscilla")

func test_fixed_topology_font_scaling_and_large_targets() -> void:
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				var panel := _panel(locale,percent,large)
				var label := "Training" if locale == "en" else "训练"
				assert_true(panel.set_projection(_projection([_entry("a",label)],false,[_source("training",label)]),"a"))
				await get_tree().process_frame
				assert_eq(panel.available_scroll.position,Vector2(32,88))
				assert_eq(panel.docket_scroll.position,Vector2(294,32))
				assert_eq(panel.docket_scroll.size,Vector2(474,516))
				assert_eq(panel.theme.default_font_size,20*percent/100)
				assert_gte(panel.source_buttons.training.size.y,80.0 if large else 64.0)
				assert_eq(panel.commands.remove.size,Vector2(254,64 if large else 48))
				assert_eq(panel.docket_scroll.scroll_hint_mode,ScrollContainer.SCROLL_HINT_MODE_DISABLED)
				for art: TextureRect in panel.find_children("RegisteredArt","TextureRect",true,false):
					assert_true(art.size in [Vector2(48,48),Vector2(128,128)],str(art.get_path())+str(art.size))
					assert_eq(art.texture_filter,CanvasItem.TEXTURE_FILTER_NEAREST,str(art.get_path()))
				for text_label: Label in panel.find_children("*","Label",true,false):
					assert_lte(text_label.get_minimum_size().y,text_label.size.y,"Every wrapped label has its measured height")
				panel.hide()

func test_unavailable_sources_keep_name_but_leave_focus_graph_and_invalid_art_refuses() -> void:
	var panel := _panel()
	assert_true(panel.set_projection(_projection([],false,[_source("training","Training",false)])))
	assert_true(panel.source_buttons.training.disabled)
	assert_eq(panel.source_buttons.training.focus_mode,Control.FOCUS_NONE)
	assert_eq(panel.source_buttons.training.accessibility_name,"Training. Unavailable")
	var invalid := _projection([],false,[_source("training","Training")])
	invalid.sources[0].compact = null
	assert_false(panel.set_projection(invalid))
	assert_true(panel.source_buttons.training.disabled,"Invalid replacement did not publish partial data")

func test_both_standard_palettes_reach_mounted_paper_text_and_art_without_recolouring_art() -> void:
	for palette: StringName in [&"after_hours",&"midnight"]:
		var panel := _panel()
		assert_true(panel.configure("en",100,false,palette))
		assert_true(panel.set_projection(_projection([_entry("a","Training")],false,[_source("training","Training")]),"a"))
		await get_tree().process_frame
		var dark := Color("151b25") if palette == &"after_hours" else Color("14201d")
		assert_eq(panel.get_child(0).color,Color("0b0d13") if palette == &"after_hours" else Color("0d1514"))
		assert_eq(panel.get_child(1).color,Color("c3baa3"))
		assert_eq(panel.source_buttons.training.get_theme_color("paper_ink","Schedule"),dark)
		assert_eq(panel.commands.remove.get_theme_color("face","Schedule"),dark)
		for label: Label in panel.source_buttons.training.find_children("*","Label",true,false):
			assert_eq(label.get_theme_color("font_color"),dark)
		for art: TextureRect in panel.find_children("RegisteredArt","TextureRect",true,false):
			assert_eq(art.modulate,Color.WHITE)
			assert_eq(art.self_modulate,Color.WHITE)
			assert_true(art.texture in [_art.compact,_art.folio])
		var before: Theme = panel.theme
		assert_false(panel.configure("en",100,false,&"unsupported"))
		assert_same(panel.theme,before,"Unsupported palette does not replace the valid theme")
		panel.hide()

func test_long_public_name_wraps_inside_its_source_and_occurrence_columns() -> void:
	var panel := _panel()
	var public_name := "Working with notes"
	assert_true(panel.set_projection(_projection([_entry("a",public_name)],false,[_source("working",public_name)]),"a"))
	await get_tree().process_frame
	var source_label: Label = panel.source_buttons.working.find_children("*","Label",true,false)[0]
	var entry_label: Label = panel.entry_buttons.a.find_children("*","Label",true,false)[0]
	assert_eq(source_label.size.x,112.0)
	assert_eq(entry_label.size.x,88.0)
	assert_gt(source_label.get_line_count(),1)
	assert_gt(entry_label.get_line_count(),1)
	assert_lte(source_label.get_rect().end.y,panel.source_buttons.working.size.y-8)
	assert_lte(entry_label.get_rect().end.y,panel.entry_buttons.a.size.y-8)

func test_refusal_status_has_exact_geometry_and_idle_has_no_nodes() -> void:
	for large: bool in [false,true]:
		var panel: Control = _panel("en",100,large)
		assert_true(panel.set_projection(_projection()))
		assert_eq(panel._status_nodes.size(),0)
		panel.set_refusal_status("refusal-1")
		assert_eq(panel._status_nodes.size(),2)
		var rule: ColorRect = panel._status_nodes[0]
		var text: Label = panel._status_nodes[1]
		assert_eq(rule.get_rect(),Rect2(24,580,2,56) if large else Rect2(24,588,2,40))
		assert_eq(text.get_rect(),Rect2(40,576,600,64) if large else Rect2(40,584,600,48))
		assert_eq(rule.color,panel.get_theme_color("structure","Schedule"))
		assert_eq(text.text,"Unavailable")
		panel.clear_status()
		assert_eq(panel._status_nodes.size(),0)
		panel.hide()

func test_refusal_status_persists_reflow_and_announces_distinct_ids_once() -> void:
	var panel: Control = _panel()
	assert_true(panel.set_projection(_projection()))
	watch_signals(panel)
	panel.set_refusal_status("refusal-1")
	panel.set_refusal_status("refusal-1")
	assert_eq(panel.get_node("DockStatus").accessibility_live,DisplayServer.LIVE_POLITE)
	assert_signal_emit_count(panel,"status_announced",1)
	assert_true(panel.set_projection(_projection([],true)))
	assert_eq(panel._status_nodes.size(),2)
	assert_eq(panel._status_nodes[1].text,"Unavailable")
	assert_eq(panel.get_node("DockStatus").accessibility_live,DisplayServer.LIVE_OFF)
	assert_signal_emit_count(panel,"status_announced",1,"Projection reflow does not reannounce.")
	assert_true(panel.configure("zh_CN",125,true))
	assert_eq(panel._status_nodes[1].text,"不可用")
	assert_signal_emit_count(panel,"status_announced",1,"Locale reflow does not reannounce.")
	panel.set_refusal_status("refusal-2")
	assert_eq(panel.get_node("DockStatus").accessibility_live,DisplayServer.LIVE_POLITE)
	assert_signal_emit_count(panel,"status_announced",2)
	panel.clear_status()
	panel.set_refusal_status("refusal-2")
	assert_signal_emit_count(panel,"status_announced",2,"Duplicate delivery stays silent after lifecycle clearing.")
	assert_eq(panel.get_node("DockStatus").accessibility_live,DisplayServer.LIVE_OFF)

func test_semantic_source_anchor_survives_scaled_locale_reflow() -> void:
	var panel: Control = _panel()
	var sources: Array = []
	for index in 8: sources.append(_source(str(index),"Long source name %d with wrapping words" % index))
	assert_true(panel.set_projection(_projection([],false,sources)))
	await get_tree().process_frame
	panel.available_scroll.scroll_vertical = int(panel._source_rows[2].y)+7
	assert_true(panel.configure("zh-HK",150,true))
	var translated: Array = []
	for index in 8: translated.append(_source(str(index),"很長的來源名稱 %d 包含換行文字" % index))
	assert_true(panel.set_projection(_projection([],false,translated),"","",true))
	await get_tree().process_frame
	assert_eq(panel.available_scroll.scroll_vertical,int(panel._source_rows[2].y)+7)

func test_removed_source_anchor_repairs_to_identity_at_old_ordinal() -> void:
	var panel: Control = _panel("en",150,true)
	var sources: Array = []
	for id: String in ["a","b","c","d","e","f","g","h","i","j"]: sources.append(_source(id,id+" wrapping source name"))
	assert_true(panel.set_projection(_projection([],false,sources)))
	await get_tree().process_frame
	panel.available_scroll.scroll_vertical = int(panel._source_rows[2].y)+5
	sources.remove_at(2)
	assert_true(panel.set_projection(_projection([],false,sources),"","",true))
	await get_tree().process_frame
	assert_eq(panel._source_rows[2].key,"source:d")
	assert_eq(panel.available_scroll.scroll_vertical,int(panel._source_rows[2].y)+5)

func test_empty_docket_slot_anchor_and_rapid_projection_revision() -> void:
	var panel: Control = _panel("en",100,true)
	assert_true(panel.set_projection(_projection()))
	await get_tree().process_frame
	panel.docket_scroll.scroll_vertical = int(panel._docket_rows[1].y)+2
	assert_true(panel.set_projection(_projection([],false,[_source("old","Old")]),"","source:old",true))
	assert_true(panel.set_projection(_projection([_entry("a","Training")],false,[_source("training","Training")]),"","source:training",true))
	await get_tree().process_frame
	assert_eq(panel._docket_rows[1].key,"slot:1")
	assert_eq(panel.docket_scroll.scroll_vertical,int(panel._docket_rows[1].y)+2)
	assert_true(panel.source_buttons.training.has_focus(),"A stale queued focus restore cannot win over the latest projection.")

func test_fresh_projection_without_existing_anchors_starts_at_zero() -> void:
	var panel: Control = _panel("en",150,true)
	assert_true(panel.set_projection(_projection()))
	await get_tree().process_frame
	assert_eq(panel.available_scroll.scroll_vertical,0)
	assert_eq(panel.docket_scroll.scroll_vertical,0)
	var sources: Array = []
	for index in 8: sources.append(_source(str(index),"Source name %d" % index))
	assert_true(panel.set_projection(_projection([],false,sources),"","",true))
	await get_tree().process_frame
	assert_eq(panel.available_scroll.scroll_vertical,0,"The first row's native top inset preserves an explicit zero offset.")
	assert_true(panel.set_projection(_projection([],false,sources),"","",true))
	await get_tree().process_frame
	assert_eq(panel.available_scroll.scroll_vertical,0,"Repeated cached refresh keeps the explicit top of an overflowing list.")

func test_cache_clear_cancels_pending_semantic_restore() -> void:
	var panel: Control = _panel("en",100,true)
	assert_true(panel.set_projection(_projection()))
	await get_tree().process_frame
	panel.docket_scroll.scroll_vertical = 90
	assert_eq(panel.docket_scroll.scroll_vertical,90)
	assert_true(panel.set_projection(_projection(),"","",true))
	panel.clear_scroll_anchors()
	await get_tree().process_frame
	assert_eq(panel.docket_scroll.scroll_vertical,0)
	assert_true(panel.set_projection(_projection(),"","",true))
	await get_tree().process_frame
	assert_eq(panel.docket_scroll.scroll_vertical,0)
