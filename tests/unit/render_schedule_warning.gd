extends SceneTree
const PANEL := preload("res://scripts/ui/schedule/SchedulePanel.gd")
const SHEET := preload("res://scripts/ui/schedule/ScheduleWarningSheet.gd")
const ART := preload("res://scripts/ui/schedule/ScheduleArtRegistry.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var loaded := REGISTRY.load_current()
	var art: Dictionary = ART.resolve(loaded.value.registry,"training",loaded.value.registry_fingerprint).value
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800,656)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for sample: Dictionary in [
		{"locale":"en","percent":100,"large":false,"palette":&"after_hours","error":false,"file":"warning-en100.png"},
		{"locale":"zh-CN","percent":150,"large":true,"palette":&"midnight","error":true,"file":"warning-cn150-error.png"},
		{"locale":"zh-HK","percent":125,"large":false,"palette":&"after_hours","error":false,"file":"warning-hk125.png"},
	]:
		var panel := PANEL.new()
		viewport.add_child(panel)
		panel.configure(sample.locale,sample.percent,sample.large,sample.palette)
		panel.set_done_enabled(true)
		var names: Array = ["Training","Working","Rest"]
		if sample.locale == "zh-CN": names = ["训练","工作","休息"]
		elif sample.locale == "zh-HK": names = ["訓練","工作","休息"]
		var sources: Array = []
		var entries: Array = []
		for i in 3:
			sources.append({"id":str(i),"name":names[i],"available":true,"compact":art.compact,"folio":art.folio})
			entries.append({"id":str(i),"source_id":str(i),"name":names[i],"folio":art.folio})
		if not panel.set_projection({"day_seven":false,"sources":sources,"entries":entries},"1"):
			quit(1)
			return
		panel.process_mode = Node.PROCESS_MODE_DISABLED
		var sheet := SHEET.new()
		viewport.add_child(sheet)
		sheet.configure(sample.locale,sample.percent,sample.large,sample.palette)
		var copy := {"title":"Fixture notice","body":"This placeholder text demonstrates the warning sheet layout.","close":"Close","go":"Go"}
		var failure := ""
		if sample.locale == "zh-CN":
			copy = {"title":"例示警告","body":"这段占位文字用于测试警告正文的排版。".repeat(14),"close":"关闭","go":"前往"}
			failure = "此处显示经过确认的操作失败说明。"
		elif sample.locale == "zh-HK": copy = {"title":"例示警告","body":"這段佔位文字用於測試警告正文的排版。","close":"關閉","go":"前往"}
		if not sheet.present("fixture-activation",copy,failure if sample.error else ""):
			quit(1)
			return
		await process_frame
		await process_frame
		for frame in 5: await RenderingServer.frame_post_draw
		for label: Label in sheet._body_document.find_children("*","Label",true,false):
			print("WARNING_TEXT_METRICS ",sample.file," length=",label.text.length()," position=",label.position," size=",label.size," minimum=",label.get_minimum_size()," lines=",label.get_line_count()," scroll=",sheet.body_scroll.scroll_vertical)
		var pixels := viewport.get_texture().get_image()
		if pixels == null or pixels.is_empty() or pixels.save_png("res://.godot/phase2r_logs/"+sample.file) != OK:
			quit(1)
			return
		print("WARNING_CAPTURE ",sample.file," ",pixels.get_size())
		viewport.remove_child(sheet)
		viewport.remove_child(panel)
		sheet.queue_free()
		panel.queue_free()
	quit(0)
