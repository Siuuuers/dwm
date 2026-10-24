extends SceneTree
## Diagnostic captures only. Glyph presence and successful drawing do not prove readability.
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const CELL := preload("res://scripts/ui/minesweeper/MinesweeperCell.gd")
const SAMPLES := {
	"en": "0123456789 Save Load Text size",
	"zh_CN": "0123456789 保存读取字体大小",
	"zh_HK": "0123456789 儲存讀取字體大小",
	"ja": "0123456789 保存 読込 文字サイズ",
	"ko": "0123456789 저장 읽기 글자 크기",
}
var folder := OS.get_environment("DWM_RENDER_OUTPUT")
var records: Array[Dictionary] = []
var failures: Array[String] = []
var captures := 0

func _initialize() -> void:
	_run.call_deferred()

func _label(parent: Node, copy: String, point: Vector2, face: Font, points: int) -> Label:
	var label := Label.new()
	label.text = copy
	label.position = point
	label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", Color("f0eee3"))
	parent.add_child(label)
	return label

func _run() -> void:
	if folder.is_empty() or DirAccess.make_dir_recursive_absolute(folder) != OK:
		printerr("FONT_SCALE_DIAGNOSTIC_OUTPUT_INVALID")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	for style: String in ["pixel", "readable"]:
		for percent: int in [100, 125, 150]:
			await _panel(style, percent)
	var rendering := {}
	for method: String in ["get_current_rendering_method", "get_current_rendering_driver_name",
			"get_video_adapter_name", "get_video_adapter_vendor", "get_video_adapter_api_version"]:
		if RenderingServer.has_method(method): rendering[method] = RenderingServer.call(method)
	var report := {"complete": captures == 6 and failures.is_empty(), "captures": captures,
		"failures": failures, "samples": records, "display_server": DisplayServer.get_name(),
		"rendering": rendering, "window_size": [root.size.x, root.size.y],
		"argv": OS.get_cmdline_args(), "engine": Engine.get_version_info(),
		"scope": "Exported-resource probe under editor executable, not release executable qualification. Untouched retained game.pck; six 1280x720 native rendered panels. Actual UiTypography faces and production MinesweeperCell renderers; synthetic text/cell facts. 24/36px cells apply the production 48px control scaling. No main-menu, Settings selection, exported-package or user-device acceptance. Visual review required; no automatic readable/corrupt classification."}
	var output := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	print("FONT_SCALE_DIAGNOSTIC_COMPLETE ", JSON.stringify(report))
	quit(0 if report.complete else 1)

func _panel(style: String, percent: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("202630")
	background.size = Vector2(1280, 720)
	viewport.add_child(background)
	var heading: Font = TYPOGRAPHY.font("en", 100, "readable")
	_label(viewport, "%s / %d%% — actual UI fonts; digits and locale sample" % [style, percent], Vector2(24, 12), heading, 24)
	_label(viewport, "Production cells: 24 px (upper), 36 px (lower)", Vector2(812, 50), heading, 18)
	var row := 0
	for locale: String in SAMPLES:
		var y := 94 + row * 120
		var font := TYPOGRAPHY.font(locale, percent, style) as FontFile
		var points := TYPOGRAPHY.font_size(locale, percent, 24, style)
		if font == null:
			failures.append("font missing: %s/%s/%d" % [locale, style, percent])
			continue
		_label(viewport, "%s | %s | %d px" % [locale, font.get_font_name(), points], Vector2(24, y), heading, 16)
		var label := _label(viewport, SAMPLES[locale], Vector2(24, y + 26), font, points)
		label.language = locale.replace("_", "-")
		var missing: Array[int] = []
		for character: String in SAMPLES[locale]:
			if not character.strip_edges().is_empty() and not font.has_char(character.unicode_at(0)):
				missing.append(character.unicode_at(0))
		if not missing.is_empty(): failures.append("missing glyphs: %s/%s/%d" % [locale, style, percent])
		var cell_records: Array[Dictionary] = []
		for pixels: int in [24, 36]:
			for number: int in range(1, 9):
				var cell := CELL.new()
				viewport.add_child(cell)
				if not cell.configure_scene(locale, percent, false, &"after_hours", false, "standard", style):
					failures.append("cell configure failed")
				if not cell.present({"index": number - 1, "face": "revealed", "mark": "none", "number": number,
						"bracketed": false, "inspectable": true, "pressable": false, "actions": []}):
					failures.append("cell presentation failed")
				cell.scale = Vector2.ONE * float(pixels) / 48.0
				cell.position = Vector2(812 + (number - 1) * pixels, y + (24 if pixels == 24 else 55))
				cell_records.append({"number": number, "cell_pixels": pixels, "scale": cell.scale.x,
					"font_points": cell.get_theme_default_font_size()})
		records.append({"locale": locale, "style": style, "percent": percent, "font_points": points,
			"font_resource": font.resource_path, "font_name": font.get_font_name(),
			"font_source_available": FileAccess.file_exists(font.resource_path),
			"font_sha256": FileAccess.get_sha256(font.resource_path) if FileAccess.file_exists(font.resource_path) else "",
			"antialiasing": font.antialiasing, "hinting": font.hinting, "oversampling": font.oversampling,
			"subpixel_positioning": font.subpixel_positioning, "system_fallback": font.allow_system_fallback,
			"missing_glyphs": missing, "text": SAMPLES[locale], "cells": cell_records})
		row += 1
	for frame: int in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image != null and image.get_size() == Vector2i(1280, 720) and image.save_png(folder.path_join("%s-%d.png" % [style, percent])) == OK:
		captures += 1
	else:
		failures.append("capture failed: %s/%d" % [style, percent])
	viewport.queue_free()
	await process_frame
