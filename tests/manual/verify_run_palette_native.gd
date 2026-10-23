extends SceneTree
## Captured-run palette evidence. Actual lifecycle/schema installation and app hosts;
## Shop art/rows, Schedule names and board checkpoint/generation are explicit fixtures.
const FIXTURE := preload("res://tests/integration/test_run_palette_host.gd")
const PRESENTATION := preload("res://tests/manual/verify_schedule_desktop_native.gd")
const LOCALE := preload("res://tests/manual/verify_quick_status_native.gd")
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var checks := 0
func _initialize() -> void: _run.call_deferred()
func _check(value: bool, label: String) -> bool:
	checks += 1
	if not value: failures.append(label)
	return value
func _run() -> void:
	var folder := ProjectSettings.globalize_path("user://evidence/run_palette_native")
	DirAccess.make_dir_recursive_absolute(folder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400,360)
	viewport.size_2d_override = Vector2i(800,720)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for dark: bool in [false,true]:
		var run := FIXTURE.make_captured_run(dark)
		if not _check(run.get("ok",false),"validated captured run"):
			continue
		viewport.add_child(run.value.state)
		var before: Dictionary = run.value.state.capture_run_snapshot_input()
		var preferences := PRESENTATION.Preferences.new()
		viewport.add_child(preferences)
		var locale := LOCALE.CatalogLocale.new()
		viewport.add_child(locale)
		_check(locale.present("en"),"real catalog locale")
		var host := FIXTURE.HOST.new()
		host.reset(1)
		var desktop: Control = FIXTURE.DESKTOP.instantiate()
		desktop.set_script(FIXTURE.IsolatedDesktop)
		_check(desktop.configure_run_configuration(run.value.state).ok,"palette before mount")
		viewport.add_child(desktop)
		var bound := FIXTURE.bind_apps(desktop,run.value.state,run.value.issuer,locale,preferences,host)
		if not _check(bound.get("ok",false),"real app hosts bound: "+str(bound)):
			desktop.queue_free()
			continue
		var palette := "midnight" if dark else "after_hours"
		var expected_face := Color("14201d") if dark else Color("151b25")
		for language: String in ["en","zh_CN","zh_HK"]:
			for percent: int in [100,125,150]:
				_check(locale.present(language),"localized shell")
				preferences.present(percent,percent==150)
				for frame in 3: await RenderingServer.frame_post_draw
				var pixels := viewport.get_texture().get_image()
				_check(desktop.theme.get_color("face","Desktop")==expected_face,"captured face theme")
				_check(pixels.get_pixel(150,1).to_html(false)==expected_face.to_html(false),"native first strip uses captured face")
				_check(desktop.theme.default_font_size==24*percent/100,"full shared font size")
				var filename := "%s-%s-%d-launcher.png" % [palette,language,percent]
				_check(pixels.save_png(folder.path_join(filename))==OK,"launcher image saved")
				samples.append({"palette":palette,"captured_dark_mode":dark,"locale":language,"percent":percent,"surface":"launcher","path":filename})
		for id: StringName in [&"schedule",&"shop",&"minesweeper"]:
			var opened: Dictionary = desktop.open_app(id)
			if not _check(opened.get("ok",false),"open "+str(id)+": "+str(opened)): continue
			for frame in 6: await RenderingServer.frame_post_draw
			var app: Control = opened.value.app
			_check(app._palette==StringName(palette),"same captured app palette")
			_check(app.is_visible_in_tree(),"actual foreground app")
			var filename := "%s-zh_HK-150-%s.png" % [palette,id]
			_check(viewport.get_texture().get_image().save_png(folder.path_join(filename))==OK,"app image saved")
			samples.append({"palette":palette,"captured_dark_mode":dark,"locale":"zh_HK","percent":150,"surface":str(id),"path":filename})
			_check(desktop.return_home().ok,"Home retains run palette")
		_check(run.value.state.capture_run_snapshot_input()==before,"presentation leaves run facts unchanged")
		desktop.queue_free()
		preferences.queue_free()
		locale.queue_free()
		run.value.state.queue_free()
		await process_frame
	var report := {"ok":failures.is_empty(),"checks":checks,"captures":samples.size(),"samples":samples,"failures":failures,
		"fixture":"Real captured lifecycle and hosts; isolated catalog/art/names and board checkpoint/generation. No purchase or player-save claim."}
	var output := FileAccess.open(folder.path_join("measurements.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	for failure: String in failures: printerr(failure)
	if failures.is_empty(): print("RUN_PALETTE_NATIVE_VERIFIED captures=",samples.size()," checks=",checks)
	viewport.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
