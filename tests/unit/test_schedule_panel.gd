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
