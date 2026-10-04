extends SceneTree
## Synthetic public board/text fixtures through production Desktop and installed Dialogic.
## Authored dating timelines currently contain return stubs; these are layout samples.
## Headless execution checks setup and geometry, never screenshot acceptance.

const SPLIT := preload("res://tests/desktop_shell/test_desktop_split_touch.gd")
const SHELL := preload("res://tests/desktop_shell/test_desktop_shell.gd")
const CONTACT := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const HUD := preload("res://tests/unit/test_stat_hud_week_tint.gd")
const SCHEDULE := preload("res://tests/manual/verify_schedule_desktop_native.gd")
const QUICK := preload("res://tests/manual/verify_quick_status_native.gd")
const MINES := preload("res://tests/unit/test_minesweeper_app.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const CHALLENGE := preload("res://tests/scene/test_minesweeper_challenge_controls.gd")
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const LAYER := "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd"
const ART_LAYER := "res://scripts/ui/witnessed/WitnessedArtLayer.gd"
const DATING_ENTRY := "dating.solo.priscilla.day1.pre_challenge"
const PAIR_ENTRY := "dating.group.priscilla_lavinia.day2.pre_challenge"
const EXPECTED_CAPTURES := 25
const COPY := {
	"en": ["1. We found a quiet place.", "2. The afternoon light filled the room.", "3. I remembered what you said.", "4. There was no need to hurry.", "5. We stayed a little longer.", "6. This caption is still unread."],
	"zh-CN": ["1. 我们找到一个安静的地方。", "2. 午后的阳光照进房间。", "3. 我记得你说过的话。", "4. 我们不必着急。", "5. 我们又多待了一会儿。", "6. 这条字幕还没有读过。"],
	"zh-HK": ["1. 我們找到一個安靜的地方。", "2. 午後的陽光照進房間。", "3. 我記得你說過的話。", "4. 我們不必着急。", "5. 我們又多待了一會兒。", "6. 這條字幕還沒有讀過。"],
}

var viewport: SubViewport
var main: Control
var desktop: Control
var profile: Node
var locale: Node
var runtime: DialogicGameHandler
var layout: Node
var caption: Node
var dating_art: Control
var challenge_scene: Control
var original_runtime: Node
var original_index := 0
var original_layout: Node
var original_layout_parent: Node
var saved_settings := {}
var had_persistent := false
var persistent: Variant
var folder := OS.get_environment("DWM_RENDER_OUTPUT")
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var captures := 0
var finished := 0
var ended := 0

func _initialize() -> void: _run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("DELIVERY_DIALOGUE_CHECK_FAIL ", message)

func settle() -> void:
	for frame in 6: await process_frame

func capture(name: String, detail: Dictionary) -> void:
	await settle()
	detail["file"] = name + ".png"
	samples.append(detail)
	if DisplayServer.get_name() != "headless":
		for frame in 3: await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		check(not pixels.is_empty() and pixels.get_size() == Vector2i(1280, 720), name + ": full viewport pixels")
		if name.begins_with("dating-") or name.begins_with("dialogue-"):
			await _check_dating_art_pixels(pixels, name)
		if name.begins_with("challenge-"): await _check_challenge_art_pixels(pixels, name)
		check(pixels.save_png(folder.path_join(name + ".png")) == OK, name + ": saved screenshot")
		captures += 1
	print("DELIVERY_DIALOGUE_SAMPLE ", name, " ", JSON.stringify(detail))

func _run() -> void:
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://evidence/delivery_dialogue")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "evidence directory")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	await _desktop_samples()
	main.queue_free()
	await settle()
	await _mount_dialogue()
	if is_instance_valid(caption):
		await _dialogue_samples()
		await _dating_samples()
		await _restore_runtime()
	await _challenge_samples()
	check(samples.size() == EXPECTED_CAPTURES, "all expected sample states checked")
	if DisplayServer.get_name() != "headless": check(captures == EXPECTED_CAPTURES, "all expected screenshots saved")
	var report := {"ok": failures.is_empty(), "renderer": DisplayServer.get_name(), "samples": samples.size(),
		"captures": captures, "failures": failures, "evidence": samples,
		"scope": "synthetic public board and dialogue fixtures; production Desktop, split dating artwork and challenge host, installed Dialogic"}
	var file := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	check(file != null, "results file opened")
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("DELIVERY_DIALOGUE_RENDER_VERIFIED ", JSON.stringify(report)) if captures == EXPECTED_CAPTURES else print("DELIVERY_DIALOGUE_GEOMETRY_CHECKED ", JSON.stringify(report))
	viewport.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)

func _desktop_samples() -> void:
	locale = QUICK.CatalogLocale.new()
	viewport.add_child(locale)
	check(locale.present("en"), "desktop locale")
	profile = SCHEDULE.Preferences.new()
	viewport.add_child(profile)
	main = SPLIT.MAIN.instantiate()
	var stats := HUD.OwnerFixture.new()
	viewport.add_child(stats)
	main.get_node("%StatHud").configure(stats, locale, profile)
	desktop = SPLIT.DESKTOP.instantiate()
	desktop.set_script(SHELL.IsolatedDesktop)
	desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new())
	main._computer_desktop_instance = desktop
	main.get_node("%ComputerPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	main.get_node("%ComputerPanel").add_child(desktop)
	viewport.add_child(main)
	var host := SCHEDULE.HOST.new()
	host.reset(1)
	check(desktop.configure_contacts(CONTACT.FakePort.new(), locale, profile, host).get("ok", false), "Contacts owner configured")
	desktop._foreground_eligible = true
	var fixture := MINES.new()
	var port := SPLIT.ShellMinesweeperPort.new()
	port.desktop_owner = desktop
	port.view = fixture._view()
	port.live_view = port.view.duplicate(true)
	fixture.free()
	check(desktop.configure_minesweeper(port, locale, profile).get("ok", false), "Minesweeper owner configured")
	var opened: Dictionary = desktop.open_app(&"minesweeper")
	check(opened.get("ok", false), "Minesweeper opened")
	if not opened.get("ok", false): return
	var app: Control = opened.value.app
	await settle()
	for tuple: Array in [[800, 100], [960, 100], [960, 150]]:
		main.get_node("RootHBox").set_angela_width(1280 - tuple[0])
		profile.present(tuple[1], tuple[1] == 150)
		await settle()
		check(app.panel._percent == tuple[1], "Minesweeper requested text size applied")
		var focus: Control = viewport.gui_get_focus_owner()
		app.panel.public_view.board.terminal = true
		app.panel.public_view.settled = false
		app.panel.presentation_changed.emit()
		desktop.set_process(false)
		desktop._process(0.85)
		await _delivery_capture("delivering-%d-%d" % tuple, tuple, "delivering...", focus)
		desktop._on_contact_message_unlocked({"notification_id": "render-%d-%d" % tuple, "friend_id": "lavinia"})
		desktop.set_process(false)
		check(desktop.message_notification.visible, "matching corner notification appears")
		await _delivery_capture("delivered-%d-%d" % tuple, tuple, "delivered :)", focus)
		app.panel.public_view.settled = true
		app.panel.presentation_changed.emit()
		desktop._dismiss_message_notification()
		desktop._process(2.51)
		check(not desktop.delivery_notice.visible, "success fades without dismissal input")

func _delivery_capture(name: String, tuple: Array, text: String, focus: Control) -> void:
	await settle()
	var notice: Control = desktop.delivery_notice
	var label: Label = desktop.delivery_caption
	check(notice.visible and label.text == text, name + ": exact delivery stage")
	check(desktop.get_global_rect().encloses(notice.get_global_rect()), name + ": notice enclosed in computer panel")
	check(notice.get_global_rect().get_center().distance_to(desktop.get_global_rect().get_center()) < 1.0, name + ": centered in computer panel")
	check(notice.get_global_rect().encloses(label.get_global_rect()), name + ": caption enclosed")
	check(label.get_minimum_size().x <= label.size.x, name + ": text width fits")
	check(notice.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.mouse_filter == Control.MOUSE_FILTER_IGNORE, name + ": pointer passes through notice")
	check(notice.focus_mode == Control.FOCUS_NONE and label.focus_mode == Control.FOCUS_NONE, name + ": no focus stop")
	check(viewport.gui_get_focus_owner() == focus, name + ": delivery preserves app focus")
	check(is_equal_approx(desktop.desktop_canvas.scale.x, float(tuple[0]) / 800.0), name + ": desktop scaling")
	await capture(name, {"kind": "delivery", "text": text, "desktop_width": tuple[0], "text_percent": tuple[1], "notice_rect": str(notice.get_global_rect())})

func _mount_dialogue() -> void:
	original_runtime = root.get_node("Dialogic")
	original_index = original_runtime.get_index()
	original_layout = original_runtime.Styles.get_layout_node()
	if is_instance_valid(original_layout) and original_layout.is_inside_tree():
		original_layout_parent = original_layout.get_parent()
		original_layout_parent.remove_child(original_layout)
	remove_meta("dialogic_layout_node")
	root.remove_child(original_runtime)
	had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		saved_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	runtime = DialogicGameHandler.new()
	runtime.name = "Dialogic"
	root.add_child(runtime)
	runtime.History.simple_history_enabled = true
	runtime.History.full_event_history_enabled = true
	runtime.Text.text_finished.connect(func(_info): finished += 1)
	runtime.timeline_ended.connect(func(): ended += 1)
	var background := TextureRect.new()
	background.size = Vector2(1280, 720)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("274e72"), Color("b78455")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1280
	texture.height = 720
	texture.fill_to = Vector2(0, 1)
	background.texture = texture
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var label := Label.new()
	label.text = "SYNTHETIC DIALOGUE / PRODUCTION PRESENTATION"
	label.position = Vector2(24, 24)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(label)
	layout = runtime.Styles.load_style(STYLE, viewport)
	_find_caption()
	await settle()
	check(is_instance_valid(caption), "real Dialogic style mounts caption layer")

func _find_caption() -> void:
	caption = null
	if not is_instance_valid(layout): return
	for layer: Node in layout.get_layers():
		if layer.get_script().resource_path == LAYER: caption = layer

func _show_text(language: String, percent: int, named: bool = false) -> void:
	await runtime.clear()
	check(locale.present(language.replace("-", "_")), "dialogue catalog locale")
	check(caption.transport_rail.bind_localization(locale), "dialogue rail uses matching locale")
	check(caption.configure_presentation(language, percent, "AfterHours"), "dialogue presentation accepted")
	var timeline := DialogicTimeline.new()
	for text: String in COPY[language]:
		var event := DialogicTextEvent.new()
		event.text = text
		if named:
			event.character = DialogicCharacter.new()
			event.character.display_name = "Priscilla"
		timeline.events.append(event)
	timeline.events_processed = true
	runtime.start_timeline(timeline)
	await settle()
	for index in 5:
		if caption.caption_text.revealing: runtime.Text.skip_text_reveal()
		await settle()
		if index < 4:
			runtime.Inputs.input_block_timer.stop()
			runtime.Inputs.handle_input()
			await settle()
	check(runtime.current_event_idx == 4, "five real text events reached without unread sixth event")
	check(caption.caption_text.get_parsed_text() == COPY[language][4], "native text remains live fifth caption")

func _dialogue_samples() -> void:
	await _show_text("en", 100)
	await _caption_capture("dialogue-live-en100", "en", 100, 0, [2, 3, 4])
	var before := _native_state()
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await _caption_capture("dialogue-older-en100", "en", 100, 1, [1, 2, 3])
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await _caption_capture("dialogue-oldest-en100", "en", 100, 2, [0, 1, 2])
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	await _caption_capture("dialogue-newer-en100", "en", 100, 1, [1, 2, 3])
	check(_native_state() == before, "wheel review preserves native event, reveal, history and completion")
	await _click(Vector2(900, 200))
	await _caption_capture("dialogue-return-live-en100", "en", 100, 0, [2, 3, 4])
	check(_native_state() == before, "background click during review returns live without story advance")
	for language: String in ["zh-CN", "zh-HK"]:
		await _show_text(language, 150)
		before = _native_state()
		await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
		await _caption_capture("dialogue-older-" + language + "150", language, 150, 1, [1, 2, 3])
		check(_native_state() == before, language + ": review preserves native narrative state")

func _caption_capture(name: String, language: String, percent: int, offset: int, indices: Array) -> void:
	await settle()
	var projection: Dictionary = caption.get_caption_projection()
	var expected: Array[String] = []
	for index: int in indices: expected.append(COPY[language][index])
	check(projection.get("caption_window", []) == expected, name + ": exact three-caption sliding window")
	check(projection.get("review_offset", -1) == offset, name + ": expected review offset")
	check(projection.font_style == "pixel", name + ": default Pixel caption style")
	check(projection.font_size == int(24 * percent / 100.0), name + ": full requested Pixel caption size")
	check(projection.visible_leaf_rects.size() == 3, name + ": three visible caption cards")
	for rect: Rect2 in projection.visible_leaf_rects:
		check(projection.field_rect.encloses(rect), name + ": card enclosed in caption field")
	check(get_nodes_in_group("dialogic_name_label").is_empty(), name + ": no visible speaker name control")
	check(caption.caption_text.get_parsed_text() == COPY[language][4], name + ": original native caption unchanged")
	check(not COPY[language][5] in projection.get("caption_window", []), name + ": unread caption absent")
	if name.begins_with("dating-"):
		check(projection.get("dating_overlay", false), name + ": dating overlay selected automatically")
		check(dating_art.size == Vector2(1280, 656), name + ": artwork extends behind every caption")
		check(dating_art._background.texture != null, name + ": actual dating painting loaded")
		check(projection.visible_leaf_rects.back().end.y == 656, name + ": captions meet bottom control strip")

	else:
		check(not projection.get("dating_overlay", false), name + ": ordinary caption retains ordinary input admission")
	for leaf: RichTextLabel in [caption.older, caption.previous, caption.review_current, caption.caption_text]:
		check(leaf.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, name + ": text centered")
		check(leaf.get_theme_stylebox("normal") is StyleBoxEmpty and leaf.get_theme_stylebox("focus") is StyleBoxEmpty, name + ": no card fill or focus box")
		check(leaf.get_theme_constant("outline_size") == 2, name + ": dark outline remains visible")
	await capture(name, {"kind": "caption", "locale": language, "text_percent": percent, "review_offset": offset,
		"caption_window": projection.get("caption_window", []), "visible_leaf_rects": str(projection.visible_leaf_rects),
		"dating_overlay": projection.get("dating_overlay", false)})

func _dating_samples() -> void:
	await runtime.clear()
	layout.queue_free()
	await settle()
	remove_meta("dialogic_layout_node")
	var original_bridge: Node = root.get_node("DialogicBridge")
	var original_bridge_index := original_bridge.get_index()
	root.remove_child(original_bridge)
	var bridge: Node = BRIDGE.new()
	bridge.name = "DialogicBridge"
	root.add_child(bridge)
	check(bridge._ensure_runtime_adapter(runtime).get("ok", false), "dating Bridge bound to real runtime")
	bridge._ordinary_playback = {"timeline_id": DATING_ENTRY, "context": {}}
	bridge._prepare_scene_art()
	layout = runtime.Styles.get_layout_node()
	check(is_instance_valid(layout), "production dating selector mounts a layout")
	if not is_instance_valid(layout):
		bridge.free()
		root.add_child(original_bridge)
		root.move_child(original_bridge, original_bridge_index)
		return
	await settle()
	if layout.get_parent() != viewport: layout.reparent(viewport)
	check(layout.get_meta("style").resource_path == STYLE, "production dating selector chooses nameless caption style")
	_find_caption()
	for layer: Node in layout.get_layers():
		if layer.get_script().resource_path == ART_LAYER: dating_art = layer._view
	check(is_instance_valid(dating_art), "real dating style mounts production artwork")
	dating_art.set_portrait_width(480.0)
	for tuple: Array in [["en", 100], ["zh-CN", 150], ["zh-HK", 150]]:
		await _show_text(tuple[0], tuple[1], true)
		dating_art.configure_entry(DATING_ENTRY, tuple[1], false, true)
		check(runtime.current_timeline.events[4].character.display_name == "Priscilla", "dating fixture has a real named speaker")
		await _caption_capture("dating-overlay-live-%s%d" % tuple, tuple[0], tuple[1], 0, [2, 3, 4])
		var before := _native_state()
		await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
		await _caption_capture("dating-overlay-review-%s%d" % tuple, tuple[0], tuple[1], 1, [1, 2, 3])
		check(_native_state() == before, "dating review preserves native narrative state")
	await _show_text("en", 100, true)
	dating_art.configure_entry(PAIR_ENTRY, 100, false, true)
	var before_resize := _native_state()
	for width: float in [480.0,640.0]:
		dating_art.set_portrait_width(width)
		await settle()
		_check_portrait_panel(dating_art, width, 2, 656)
		await _caption_capture("dating-pair-%d" % width, "en", 100, 0, [2,3,4])
		check(_native_state() == before_resize, "paired portrait resize preserves native dialogue state")
	bridge.free()
	root.add_child(original_bridge)
	root.move_child(original_bridge, original_bridge_index)

func _challenge_samples() -> void:
	for tuple: Array in [["solo","en",100,480.0,false], ["group","en",100,640.0,false],
			["group","ja",150,640.0,true], ["group","ko",150,640.0,true]]:
		var port := CHALLENGE.PublicPort.new()
		port.view = {"host":"canonical_solo" if tuple[0] == "solo" else "canonical_pair", "phase":"challenge",
			"board":CHALLENGE.QUERY.desktop(CHALLENGE.STATE.new().capture(),"expert",true).value,
			"special_mine_visible":false,"special_mine_enabled":false}
		challenge_scene = CHALLENGE.SCENE.instantiate()
		var context := {"kind":tuple[0],"day":1 if tuple[0] == "solo" else 2,
			"participants":["priscilla"] if tuple[0] == "solo" else ["priscilla","lavinia"]}
		check(challenge_scene.configure_presentation(port,{"physical_token":"render.challenge", "context":context}).ok, "challenge fixture configured")
		check(challenge_scene.configure_presentation_services(null,tuple[1],tuple[2],tuple[4]).ok, "challenge accessibility configured")
		viewport.add_child(challenge_scene)
		challenge_scene.set_process(false)
		challenge_scene._scene_art.set_portrait_width(tuple[3])
		await settle()
		var original: Dictionary = challenge_scene.worksheet.grid.projection.duplicate(true)
		var worksheet: Control = challenge_scene.worksheet
		if tuple[4]:
			challenge_scene.find_child("Rules",true,false).pressed.emit()
			check(worksheet.information_sheet != null, "large localized Rules opens")
		await settle()
		var right: Rect2 = challenge_scene._scene_art.get_right_rect()
		_check_portrait_panel(challenge_scene._scene_art,tuple[3],1 if tuple[0] == "solo" else 2,720)
		check(challenge_scene._challenge_content.get_rect() == right, "challenge uses complete right pane")
		check(worksheet.get_global_rect().position.x >= right.position.x and worksheet.get_global_rect().end.x <= right.end.x, "worksheet stays inside right pane")
		check(challenge_scene._challenge_panel.get_combined_minimum_size().x <= right.size.x, "challenge chrome fits pane width")
		check(worksheet.theme.default_font_size == CHALLENGE.TYPOGRAPHY.font_size(tuple[1],tuple[2],20,"pixel"), "challenge keeps full requested font")
		check(challenge_scene._challenge_content.follow_focus, "overflow keeps keyboard controls reachable")
		if worksheet.information_sheet != null:
			for row: Control in worksheet.information_sheet.rows:
				check(row.size.y <= worksheet.information_sheet.body.size.y, "a complete Rules row fits the scroll page")
		await capture("challenge-%s-%s%d-%d%s" % [tuple[0],tuple[1],tuple[2],tuple[3],"-rules" if tuple[4] else ""],
			{"kind":"dating_challenge", "locale":tuple[1], "text_percent":tuple[2], "portrait_width":tuple[3],
			"right_rect":str(right), "worksheet_rect":str(worksheet.get_global_rect()), "rules":tuple[4]})
		check(worksheet.grid.projection == original and port.commands.is_empty(), "capture never changes challenge progress")
		challenge_scene.queue_free()
		await settle()
	challenge_scene = null

func _check_portrait_panel(art: Control, width: float, count: int, height: int) -> void:
	check(art.get_right_rect() == Rect2(width,0,1280-width,height), "dating split uses requested extent")
	check(art._portrait_background.texture != null and art._portrait_background.texture == art._background.texture, "both panels reuse actual scene background")
	check(art.get_split_handle() != null and art.get_split_handle().is_visible_in_tree(), "portrait divider remains visible")
	check(art._portrait_count == count, "actual authored portrait count")
	for index: int in count:
		var portrait: Control = art._portraits[index]
		check(portrait.texture != null and portrait.is_visible_in_tree(), "actual portrait loaded")
		check(is_equal_approx(portrait.size.y,height), "portrait height remains fixed")
		check(is_equal_approx(portrait.get_global_rect().get_center().x,width*(index+0.5)/count), "portraits divide space evenly")

func _check_challenge_art_pixels(pixels: Image, name: String) -> void:
	var art: Control = challenge_scene._scene_art
	var saved_modulate: Color = art.modulate
	art.modulate.a = 0.0
	for frame in 3: await RenderingServer.frame_post_draw
	var without_art: Image = viewport.get_texture().get_image()
	art.modulate = saved_modulate
	for frame in 3: await RenderingServer.frame_post_draw
	var width := int(art.get_portrait_width())
	var portrait_samples := 0
	var board_changes := 0
	for y: int in range(8,712,24):
		for x: int in range(8,width-64,24):
			if pixels.get_pixel(x,y) != without_art.get_pixel(x,y): portrait_samples += 1
		for x: int in range(width+16,1264,24):
			if pixels.get_pixel(x,y) != without_art.get_pixel(x,y): board_changes += 1
	check(portrait_samples > 100, name + ": actual portrait/background pixels remain visible left")
	check(board_changes == 0, name + ": opaque challenge fills right pane independently of artwork")

func _check_dating_art_pixels(pixels: Image, name: String) -> void:
	# Alpha-only reference leaves native text, focus and timeline state untouched.
	# Comparing blank margins across the old caption field catches opaque fills,
	# horizontal seams and focus frames that node-level theme checks cannot detect.
	var before := _native_state()
	var focus: Control = viewport.gui_get_focus_owner()
	var visible_modulate: Color = caption.canvas.modulate
	caption.canvas.modulate.a = 0.0
	for frame in 3: await RenderingServer.frame_post_draw
	var artwork: Image = viewport.get_texture().get_image()
	caption.canvas.modulate = visible_modulate
	for frame in 3: await RenderingServer.frame_post_draw
	check(_native_state() == before and viewport.gui_get_focus_owner() == focus, name + ": pixel reference preserves narration and focus")
	var colors := {}
	var mismatches := 0
	var top: int = int(caption.get_caption_projection().field_rect.position.y)
	for x: int in [8, 20, 100, 200, 1080, 1180, 1260]:
		for y: int in range(top, 656, 4):
			var point := Vector2i(x, y)
			var expected := artwork.get_pixelv(point)
			colors[expected.to_html()] = true
			if pixels.get_pixelv(point) != expected: mismatches += 1
	check(colors.size() > 30, name + ": actual painting has varied pixels throughout former caption field")
	check(mismatches == 0, name + ": blank caption margins preserve artwork without panel/seam/frame pixels (%d changed)" % mismatches)

func _wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = Vector2(900, 550)
	viewport.push_input(event, true)
	await settle()

func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		viewport.push_input(event, true)
		await process_frame
	await settle()

func _native_state() -> Dictionary:
	return {"event": runtime.current_event_idx, "text": caption.caption_text.text,
		"visible": caption.caption_text.visible_characters, "simple": runtime.History.simple_history_content.duplicate(true),
		"full": runtime.History.full_event_history_content.duplicate(), "finished": finished, "ended": ended}

func _restore_runtime() -> void:
	caption.caption_text.set_process(false)
	await runtime.clear()
	if is_instance_valid(layout): layout.queue_free()
	await settle()
	runtime.free()
	remove_meta("dialogic_layout_node")
	root.add_child(original_runtime)
	root.move_child(original_runtime, original_index)
	if is_instance_valid(original_layout):
		if is_instance_valid(original_layout_parent): original_layout_parent.add_child(original_layout)
		set_meta("dialogic_layout_node", original_layout)
	for key: String in saved_settings:
		ProjectSettings.set_setting(key, saved_settings[key].value if saved_settings[key].exists else null)
	if had_persistent: Engine.set_meta("dialogic_persistent_style_info", persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
