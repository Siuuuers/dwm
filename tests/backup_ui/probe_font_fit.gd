extends SceneTree
## Geometry probe, not an approval of these draft localized labels.
const FONTS := {
	"en": preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2"),
	"zh-CN": preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf"),
	"zh-HK": preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")}
const WORDS := {
	"en": {"names": ["Autosave", "Quick", "Slot 1"], "states": ["Day 7 · 09:07", "Empty", "Unavailable"], "modes": ["Save", "Load"]},
	"zh-CN": {"names": ["自动存档", "快速存档", "存档 1"], "states": ["第7天 · 09:07", "空", "不可用"], "modes": ["保存", "读取"]},
	"zh-HK": {"names": ["自動存檔", "快速存檔", "存檔 1"], "states": ["第7天 · 09:07", "空", "無法使用"], "modes": ["儲存", "載入"]}}

func _initialize() -> void:
	run.call_deferred()

func measure(text: String, font: Font, font_size: int, width: float) -> Dictionary:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size.x = width
	root.add_child(label)
	for frame in range(3):
		await process_frame
	var result := {"text": text, "height": label.get_minimum_size().y, "lines": label.get_line_count()}
	label.queue_free()
	return result

func run() -> void:
	root.size = Vector2i(1280, 720)
	for locale in FONTS:
		for font_size in [20, 24, 25, 30, 36]:
			var names: Array = []
			var states: Array = []
			var modes: Array = []
			var recovery: Array = []
			for word in WORDS[locale].names:
				names.append(await measure(word, FONTS[locale], font_size, 128))
			for word in WORDS[locale].states:
				states.append(await measure(word, FONTS[locale], font_size, 128))
			for word in WORDS[locale].modes:
				modes.append(await measure(word, FONTS[locale], font_size, 80))
			if locale == "en":
				for width in [128, 132, 136]:
					var measured: Dictionary = await measure("Overwrite", FONTS[locale], font_size, width)
					measured["text_width"] = width
					recovery.append(measured)
			var maximum := 0.0
			for identity in names:
				for state in states:
					maximum = maxf(maximum, identity.height + state.height + 6.0)
			print(JSON.stringify({"locale": locale, "font_size": font_size, "paper_width": 136, "text_width": 128, "paper_height": 168, "maximum_identity_plus_state_plus_gap": maximum, "fits_paper_height": maximum <= 168, "identity": names, "state": states, "mode_text_width": 80, "mode_text": modes, "recovery_overwrite": recovery}))
	await process_frame
	print("BACKUP_FONT_FIT_PROBE_DONE")
	quit()
