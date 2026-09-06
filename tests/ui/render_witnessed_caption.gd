extends SceneTree
## Synthetic caption fixtures through installed Dialogic Styles/Text; no authored-story claim.
## No Hospital art or history/transport controls are invented by this renderer.

const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const LAYER := "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd"
const THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const COPY := {
	"en":"Synthetic caption fixture. This sentence checks the current caption at its full requested font size.",
	"zh-CN":"字幕测试样本。这段合成文字用于检查当前字幕的位置、完整字号与阅读空间。",
	"zh-HK":"字幕測試樣本。這段合成文字用於檢查目前字幕的位置、完整字號與閱讀空間。",
}
var _runtime: DialogicGameHandler
var _viewport: SubViewport
var _layout: Node
var _caption: Node
var _original_runtime: Node
var _original_layout: Node
var _original_layout_parent: Node
var _original_index := 0
var _autosave_setting: Variant
var _had_autosave_setting := false
var _persistent: Variant
var _had_persistent := false
var _folder := ""
var _records: Array[Dictionary] = []
var _finished := 0
var _ended := 0
var _unfocused_captures := 0

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/witnessed_caption")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK,"cannot create evidence folder"):
		quit(1)
		return
	if not await _mount():
		quit(1)
		return
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for palette: String in ["AfterHours","Midnight"]:
				if not await _show_fixture(locale,percent,palette,false):
					quit(1)
					return
				if not await _capture(locale,percent,palette,"short"):
					quit(1)
					return
	for locale: String in ["en","zh-CN","zh-HK"]:
		if not await _show_fixture(locale,150,"AfterHours",true):
			quit(1)
			return
		# Real focused page navigation creates the photographed manual scroll.
		var page := InputEventKey.new()
		page.keycode = KEY_PAGEDOWN
		page.pressed = true
		_viewport.push_input(page,true)
		if not await _capture(locale,150,"AfterHours","overflow"):
			quit(1)
			return
	_runtime.Text.clear_game_state()
	if not await _capture("zh-HK",150,"AfterHours","empty"):
		quit(1)
		return
	var report := FileAccess.open(_folder.path_join("caption-measurements.json"),FileAccess.WRITE)
	if not _check(report != null,"cannot write report"):
		quit(1)
		return
	report.store_string(JSON.stringify({"scope":"synthetic caption fixtures; actual authored Hospital timeline currently has no text",
		"runtime":"installed DialogicGameHandler, deferred Styles mount and native Text reveal; original application runtime preserved",
		"captures":_records.size(),"unfocused_overflow_captures":_unfocused_captures,"tuples":18,"samples":_records},"\t")+"\n")
	report.close()
	await _restore()
	print("WITNESSED_CAPTION_RENDER_VERIFIED captures=",_records.size()," unfocused_overflow_captures=",_unfocused_captures," tuples=18 overflow=3 empty=1 fixture=synthetic production_authored_caption_acceptance=false evidence=",_folder)
	quit(0)

func _mount() -> bool:
	_original_runtime = root.get_node("Dialogic")
	_original_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_layout_parent = _original_layout.get_parent()
		_original_layout_parent.remove_child(_original_layout)
	remove_meta("dialogic_layout_node")
	root.remove_child(_original_runtime)
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info",{})
	_had_autosave_setting = ProjectSettings.has_setting("dialogic/save/autosave")
	_autosave_setting = ProjectSettings.get_setting("dialogic/save/autosave")
	ProjectSettings.set_setting("dialogic/save/autosave",false)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	root.add_child(_runtime)
	_runtime.History.simple_history_enabled = true
	_runtime.History.full_event_history_enabled = true
	_runtime.Text.text_finished.connect(func(_info): _finished += 1)
	_runtime.timeline_ended.connect(func(): _ended += 1)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280,720)
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var background := ColorRect.new()
	background.size = Vector2(1280,720)
	background.color = Color("30343d")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(background)
	var label := Label.new()
	label.text = "SYNTHETIC CAPTION FIXTURE / PRESENTATION EVIDENCE"
	label.position = Vector2(24,24)
	label.theme = THEME.build("en",100,"AfterHours")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(label)
	_layout = _runtime.Styles.load_style(STYLE,_viewport)
	if not _check(_layout != null and not _layout.is_inside_tree(),"Styles did not create deferred layout"): return false
	for layer: Node in _layout.get_layers():
		if layer.get_script().resource_path == LAYER: _caption = layer
	if not _check(_caption != null,"standalone style did not select caption layer"): return false
	await _frames()
	return _check(get_nodes_in_group("dialogic_dialog_text").size() == 1 and get_nodes_in_group("dialogic_name_label").is_empty(),"style must expose one native DialogText and no NameLabel")

func _show_fixture(locale: String, percent: int, palette: String, overflow: bool) -> bool:
	await _runtime.clear()
	if not _check(_caption.configure_presentation(locale,percent,palette),"valid presentation tuple rejected"): return false
	var copy: String = COPY[locale]
	if overflow: copy = (copy+" ").repeat(100).strip_edges()
	var timeline := DialogicTimeline.new()
	timeline.from_text(copy)
	_runtime.start_timeline(timeline)
	await _frames()
	_runtime.Text.skip_text_reveal()
	await _frames()
	if not _check(_caption.caption_text.get_parsed_text() == copy and _caption.caption_text.visible_ratio == 1.0,"native fixture text did not reveal fully"): return false
	var before := _invariants()
	# Reapplying presentation must not duplicate history, move the event or finish it.
	if not _check(_caption.configure_presentation(locale,percent,palette),"idempotent presentation rejected"): return false
	await _frames()
	return _check(_invariants() == before,"presentation reapply changed native timeline/history/completion")

func _capture(locale: String, percent: int, palette: String, kind: String) -> bool:
	await _frames()
	var projection: Dictionary = _caption.get_caption_projection()
	var expected: Theme = THEME.build(locale,percent,palette)
	var node: RichTextLabel = _caption.caption_text
	var field: Rect2 = projection.field_rect
	var leaf: Rect2 = projection.caption_rect
	var expected_top: int = {100:448,125:392,150:328}[percent]
	if not _check(field == Rect2(0,expected_top,1280,656-expected_top) and leaf.end.y == 656 and leaf.position.x == 16 and leaf.size.x == 1248,"fixed field/rail/leaf geometry changed"): return false
	if not _check(fposmod(leaf.position.y,2.0) == 0 and fposmod(leaf.size.y,2.0) == 0,"leaf origin/height escaped the two-logical-pixel lattice"): return false
	if not _check(projection.font_size == int(percent/5) and node.get_theme_font_size(&"normal_font_size") == int(percent/5),"caption font was reduced"): return false
	if not _check(_runtime.current_event_idx == 0 and _ended == 0,"caption changed timeline ownership"): return false
	if kind == "empty":
		if not _check(projection.text.is_empty() and not projection.caption_visible and node.focus_mode == Control.FOCUS_NONE and not node.has_focus(),"empty caption retains visible or focused leaf"): return false
	else:
		if not _check(projection.caption_visible and node.has_focus() and not projection.revealing,"visible fixture lacks stable caption focus"): return false
		if kind == "overflow":
			if not _check(projection.scroll_extent > 0 and projection.scroll_offset > 0 and leaf.size.y == field.size.y,"overflow did not cap and page-scroll actual rich text"): return false
		elif not _check(not node.get_v_scroll_bar().visible and projection.scroll_offset == 0,"short caption has unnecessary scrolling"): return false
	var pixels: Image = _viewport.get_texture().get_image()
	var name := "%s%d-%s-%s.png" % [locale,percent,palette,kind]
	if not _check(pixels != null and pixels.save_png(_folder.path_join(name)) == OK,"cannot save caption capture"): return false
	if not _pixel(pixels,Vector2i(2,expected_top+8),expected,&"field"): return false
	if not _pixel(pixels,Vector2i(2,expected_top),expected,&"rule"): return false
	if not _pixel(pixels,Vector2i(2,680),expected,&"deep"): return false
	if kind != "empty":
		if not _pixel(pixels,Vector2i(leaf.position)+Vector2i(12,12),expected,&"current"): return false
		if not _pixel(pixels,Vector2i(leaf.position)+Vector2i(3,20),expected,&"focus_outer"): return false
		if not _pixel(pixels,Vector2i(leaf.position)+Vector2i(7,20),expected,&"focus_inner"): return false
		var ink_pixels := 0
		var ink: Color = expected.get_color(&"text",&"WitnessedCaption")
		var interior := Rect2i(leaf.grow(-18))
		for y in range(interior.position.y,interior.end.y):
			for x in range(interior.position.x,interior.end.x):
				if _same_color(pixels.get_pixel(x,y),ink): ink_pixels += 1
		if not _check(ink_pixels > 20,"caption has no rendered interior glyph ink"): return false
		if not await _protected_text_proof(pixels,node,expected,name,kind == "overflow"): return false
	_records.append({"file":name,"locale":locale,"text_percent":percent,"palette":palette,"kind":kind,"font_size":projection.font_size,
		"field_rect":str(field),"caption_rect":str(leaf),"scroll_offset":projection.scroll_offset,"scroll_extent":projection.scroll_extent,"focused":node.has_focus()})
	print("WITNESSED_CAPTION_CAPTURE ",name," field=",field," leaf=",leaf," font=",projection.font_size," scroll=",projection.scroll_offset)
	return true

func _protected_text_proof(focused: Image, node: RichTextLabel, expected: Theme, name: String, save_unfocused: bool) -> bool:
	var bar: VScrollBar = node.get_v_scroll_bar()
	var frame_width := int(node.size.x-(bar.size.x if bar.visible else 0))
	var frame_height := int(node.size.y)
	var origin := Vector2i(node.get_global_transform_with_canvas()*Vector2.ZERO)
	# Exact coverage checks include partially scrolled glyphs at every protected boundary.
	# The native scrollbar is a separate trailing gutter, outside this caption focus frame.
	if not _protected_frame(focused,origin,frame_width,frame_height,expected,true): return false
	var scroll_before := bar.value
	var before := _invariants()
	node.release_focus()
	await _frames()
	if not _check(not node.has_focus(),"could not capture unfocused caption reference"): return false
	var unfocused: Image = _viewport.get_texture().get_image()
	if save_unfocused:
		if not _check(unfocused.save_png(_folder.path_join(name.trim_suffix(".png")+"-unfocused.png")) == OK,"cannot save unfocused overflow reference"): return false
		_unfocused_captures += 1
	if not _protected_frame(unfocused,origin,frame_width,frame_height,expected,false): return false
	var changed := 0
	var first_changed := Vector2i(-1,-1)
	# Compare every pixel in the actual glyph aperture, including its first and last rows.
	for y in range(16,frame_height-16):
		for x in range(16,frame_width-16):
			var point := origin+Vector2i(x,y)
			if not _same_color(focused.get_pixelv(point),unfocused.get_pixelv(point)):
				changed += 1
				if first_changed.x < 0: first_changed = point
	node.grab_focus()
	await _frames()
	if not _check(bar.value == scroll_before and _invariants() == before,"focus comparison altered scroll or narrative state"): return false
	print("WITNESSED_CAPTION_PROTECTED_FRAME file=",name," frame_width=",frame_width," height=",frame_height," changed_interior_pixels=",changed," first_changed=",first_changed)
	return _check(changed == 0,"focus altered rendered glyph aperture at "+str(first_changed))

func _protected_frame(pixels: Image, origin: Vector2i, width: int, height: int, expected: Theme, focused: bool) -> bool:
	var bone_outer := Rect2i(2,2,width-4,height-4)
	var bone_inner := Rect2i(4,4,width-8,height-8)
	var gold_outer := Rect2i(6,6,width-12,height-12)
	var gold_inner := Rect2i(8,8,width-16,height-16)
	var mismatches := 0
	var first := Vector2i(-1,-1)
	var first_role := &""
	for y in height:
		for x in width:
			if y >= 16 and y < height-16 and x >= 16 and x < width-16: continue
			var local := Vector2i(x,y)
			var role := &"rule" if y < 2 else &"current"
			if focused and bone_outer.has_point(local) and not bone_inner.has_point(local): role = &"focus_outer"
			if focused and gold_outer.has_point(local) and not gold_inner.has_point(local): role = &"focus_inner"
			if not _same_color(pixels.get_pixelv(origin+local),expected.get_color(role,&"WitnessedCaption")):
				mismatches += 1
				if first.x < 0:
					first = local
					first_role = role
	return _check(mismatches == 0,"protected caption band contains glyph/rail overpaint: focused=%s pixels=%d first_local=%s expected=%s" % [focused,mismatches,first,first_role])

func _invariants() -> Dictionary:
	return {"text":_caption.caption_text.text,"visible":_caption.caption_text.visible_characters,"event":_runtime.current_event_idx,
		"simple_history":_runtime.History.simple_history_content.duplicate(true),"full_history":_runtime.History.full_event_history_content.duplicate(),"finished":_finished,"ended":_ended}

func _pixel(pixels: Image, point: Vector2i, expected: Theme, role: StringName) -> bool:
	return _check(_same_color(pixels.get_pixelv(point),expected.get_color(role,&"WitnessedCaption")),str(role)+" substrate/ink mismatch at "+str(point))

func _same_color(actual: Color, expected: Color) -> bool:
	return absf(actual.r-expected.r) <= 1.1/255 and absf(actual.g-expected.g) <= 1.1/255 and absf(actual.b-expected.b) <= 1.1/255 and absf(actual.a-expected.a) <= 1.1/255

func _frames() -> void:
	for frame in 4: await RenderingServer.frame_post_draw

func _check(condition: bool, message: String) -> bool:
	if not condition: push_error("WITNESSED_CAPTION_RENDER_FAILED: "+message)
	return condition

func _restore() -> void:
	_caption.caption_text.set_process(false)
	await _runtime.clear()
	_viewport.queue_free()
	await process_frame
	_runtime.free()
	remove_meta("dialogic_layout_node")
	root.add_child(_original_runtime)
	root.move_child(_original_runtime,_original_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_original_layout_parent): _original_layout_parent.add_child(_original_layout)
		set_meta("dialogic_layout_node",_original_layout)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info",_persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	ProjectSettings.set_setting("dialogic/save/autosave",_autosave_setting if _had_autosave_setting else null)
