extends SceneTree
## One reversible ablation: reflowing text versus a fixed two-line text slot.
## "Hidden lines" means clipping inside Labels, not content below the scroll viewport.

const PANEL_PATH := "res://scripts/ui/contacts/ContactsPanel.gd"
const FONT_DIR := "res://assets/ui/contacts/fonts/"
var failures: Array[String] = []
var panel

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func settle() -> void:
	for frame in range(6):
		await process_frame

func measure(labels: Array[Label]) -> Dictionary:
	var rows: Array[Dictionary] = []
	var total := 0
	var visible := 0
	for label in labels:
		var lines := label.get_line_count()
		var shown := label.get_visible_line_count()
		total += lines
		visible += shown
		rows.append({"locale": label.get_meta("locale"), "total_lines": lines,
			"visible_lines": shown, "hidden_lines": maxi(0, lines - shown),
			"width_px": label.size.x, "height_px": label.size.y})
	return {"total_lines": total, "visible_lines": visible,
		"hidden_lines": maxi(0, total - visible), "labels": rows,
		"viewport_width_px": panel.transcript.size.x,
		"viewport_height_px": panel.transcript.size.y,
		"transcript_content_height_px": panel.messages.size.y}

func _run() -> void:
	var script = load(PANEL_PATH)
	if script == null or not script.can_instantiate():
		printerr("FAIL: ContactsPanel cannot be loaded for ablation.")
		quit(1)
		return
	var fonts: Array[Font] = []
	for file in ["source-sans-3-regular.ttf.woff2", "source-han-sans-sc-regular.otf", "source-han-sans-hc-regular.otf"]:
		var font = load(FONT_DIR + file)
		if not font is Font:
			printerr("FAIL: Required ablation font could not be loaded: " + file)
			quit(1)
			return
		fonts.append(font)
	root.size = Vector2i(1280, 720)
	panel = script.new()
	panel.position = Vector2(480, 64)
	panel.size = Vector2(800, 656)
	root.add_child(panel)
	check(panel.configure(fonts[0], fonts[1], fonts[2], 150, false), "150% configuration accepted")
	var entries: Array[Dictionary] = []
	for index in range(2):
		entries.append({"id": "ablation-%d" % index, "outgoing": index == 1,
			"texts": {
				"en": "This is a neutral reading sample. Each sentence must remain available when the text size increases. ".repeat(5),
				"zh-HK": "這是一段中性閱讀示例。文字放大以後，每一句仍然應當完整顯示，讀者可以向下捲動以閱讀最後一行。".repeat(5)
			}})
	check(panel.set_projection("priscilla", entries, {}, "en", "zh-HK"), "Bilingual ablation projection accepted")
	await settle()
	var labels: Array[Label] = []
	for node in panel.messages.find_children("*", "Label", true, false):
		if node.has_meta("locale"):
			labels.append(node)
	check(labels.size() == 4, "Two bilingual entries produce four text Labels")
	var normal := measure(labels)
	check(normal.total_lines > labels.size() * 2, "Specimen exceeds two lines per Label")
	check(normal.hidden_lines == 0, "Normal reflow preserves every text line")
	for label in labels:
		label.max_lines_visible = 2
	await settle()
	var fixed := measure(labels)
	check(fixed.hidden_lines > 0, "Fixed two-line slots hide specimen lines")
	check(fixed.visible_lines <= labels.size() * 2, "Ablation applies the two-line limit")
	for label in labels:
		label.max_lines_visible = -1
	await settle()
	var restored := measure(labels)
	check(restored.hidden_lines == 0, "Restoring reflow makes every line available again")
	check(restored.total_lines == normal.total_lines, "Restoration preserves the original wrapping")
	print(JSON.stringify({"text_percent": 150, "font_size_px": panel.font_size,
		"normal_reflow": normal, "fixed_two_lines": fixed, "restored_reflow": restored}))
	panel.queue_free()
	await settle()
	if failures.is_empty():
		print("CONTACTS_ABLATION_PASS")
	quit(0 if failures.is_empty() else 1)
