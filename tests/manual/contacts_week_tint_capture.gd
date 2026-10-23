extends SceneTree
## Real Contacts controls with memory-only correspondence and synthetic row art.
## Installed day/palette use fresh mounts; accessibility changes retain the live thread.
const APP := preload("res://scenes/apps/ContactListApp.tscn")
const CONTACTS_THEME := preload("res://scripts/ui/contacts/ContactsTheme.gd")
const FOLDER := "res://.godot/phase2r_logs/contacts_week_tint"
const ART_COLOUR := Color("e34db1")
const LOGICAL_RECT := Rect2(0, 0, 1280, 720)

class Preferences extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var high_contrast := false
	var colour_preset := "standard"
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		match path:
			&"preferences.accessibility.text_size": return 100
			&"preferences.accessibility.high_contrast": return high_contrast
			&"preferences.accessibility.colour_differentiation": return colour_preset
		return fallback
	func present(contrast: bool, preset: String) -> void:
		high_contrast = contrast
		colour_preset = preset
		preference_changed.emit(&"preferences.accessibility.high_contrast", high_contrast)

class Presentation extends RefCounted:
	var calls := {"projection": 0, "open": 0, "group_reply": 0, "pending": 0,
		"prepare": 0, "acknowledge": 0, "cancel": 0}
	var pending: Dictionary = {}
	var entries: Array = [
		{"id": "fixture-incoming", "outgoing": false,
			"texts": {"en": "Still awake? Shall we meet tomorrow?"}, "timestamp": "21:04"},
		{"id": "fixture-outgoing", "outgoing": true,
			"texts": {"en": "Yes. I'll bring the notebook."}, "timestamp": "21:06"},
	]
	func get_projection(friend_id: String, _primary: String = "en", _secondary: String = "") -> Dictionary:
		calls.projection += 1
		var choices: Array = []
		if friend_id == "lavinia":
			for letter: String in ["a", "b", "c"]:
				choices.append({"reply_id": "fixture-reply-" + letter,
					"text": {"a": "See you at the cafe.", "b": "Let's take a quiet walk.", "c": "Tell me more tomorrow."}[letter]})
		return {"ok": true, "value": {"friend_id": friend_id,
			"entries": entries.duplicate(true) if friend_id == "lavinia" else [],
			"unread": {"priscilla": true, "lavinia": false, "sylvia": false},
			"reply_required": false, "ordinary_choices": choices}}
	func open_friend(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
		calls.open += 1
		return get_projection(friend_id, primary, secondary)
	func reply_to_group(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
		calls.group_reply += 1
		return get_projection(friend_id, primary, secondary)
	func get_pending_ordinary_reply() -> Dictionary:
		calls.pending += 1
		return {"ok": true, "value": {} if pending.is_empty() else {"command": pending.duplicate(true)}}
	func prepare_ordinary_reply(friend_id: String, reply_id: String, locale: String = "en") -> Dictionary:
		calls.prepare += 1
		pending = {"command_id": "memory-fixture-choice", "friend_id": friend_id,
			"reply_id": reply_id, "locale": locale, "rendered_line": {
				"view_token": "memory-fixture-view", "line_id": "memory-fixture-line",
				"text": "Let's take a quiet walk."}}
		return {"ok": true}
	func acknowledge_ordinary_reply(command: Dictionary, line: Dictionary,
			_primary: String = "en", _secondary: String = "") -> Dictionary:
		calls.acknowledge += 1
		if command != pending or line != pending.get("rendered_line"):
			return {"ok": false, "code": &"fixture_command_mismatch"}
		# Deliberately retain a pending view. This fake never invokes storage.
		return {"ok": false, "code": &"memory_fixture_pending"}
	func cancel_pending_ordinary_reply(command: Dictionary) -> Dictionary:
		calls.cancel += 1
		if command != pending: return {"ok": false}
		pending = {}
		return {"ok": true}

var _viewport: SubViewport
var _caption: Label
var _checks := 0
var _failures: Array[String] = []
var _samples: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok: _failures.append(message)
	return ok

func _settle() -> void:
	for frame: int in 6: await process_frame
	await RenderingServer.frame_post_draw

func _mount(palette: StringName, day: int) -> Dictionary:
	var provider := Presentation.new()
	var profile := Preferences.new()
	var app: ContactListApp = APP.instantiate()
	var configured: Dictionary = app.configure_presentation(provider, null, profile, palette, day)
	if not _check(configured.get("ok", false), "Contacts installation: " + str(configured)):
		app.free()
		return {}
	app.position = Vector2(480, 64)
	app.size = Vector2(800, 656)
	_viewport.add_child(app)
	await _settle()
	app.contacts_panel.rows[1].pressed.emit()
	await _settle()
	var image := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	image.fill(ART_COLOUR)
	var portrait := ImageTexture.create_from_image(image)
	app.contacts_panel.rows[1].portrait_texture = portrait
	app.contacts_panel.rows[1].queue_redraw()
	if _check(app._ordinary_choices.size() == 3, "three ordinary reply choices mounted"):
		app._ordinary_choices[1].grab_focus()
	await _settle()
	return {"app": app, "profile": profile, "provider": provider, "palette": palette,
		"day": day, "portrait": portrait, "source_entries": provider.entries.duplicate(true)}

func _view_state(app: ContactListApp) -> Dictionary:
	var labels := {}
	for label: Label in app.find_children("*", "Label", true, false):
		labels[label.get_instance_id()] = label.text
	var buttons: Array[int] = []
	for button: Button in app._ordinary_choices: buttons.append(button.get_instance_id())
	var focused: Control = _viewport.gui_get_focus_owner()
	return {"labels": labels, "buttons": buttons, "entries": app.contacts_panel._entries.duplicate(true),
		"friend": app.contacts_panel.selected_friend, "scroll": app.contacts_panel.transcript.scroll_vertical,
		"transcript": app.contacts_panel.transcript.get_instance_id(),
		"row": app.contacts_panel.rows[1].get_instance_id(),
		"pending": app._ordinary_pending.duplicate(true), "generation": app._ordinary_generation,
		"retry": app._ordinary_retry.get_instance_id() if is_instance_valid(app._ordinary_retry) else 0,
		"last_result": app.last_result.duplicate(true), "busy": app._ordinary_busy,
		"focus": focused.get_instance_id() if focused != null else 0}

func _pixel(pixels: Image, position: Vector2, expected: Color, label: String, tolerance: int = 0) -> String:
	var sample := Vector2i(position / 2.0)
	if not _check(Rect2i(Vector2i.ZERO, pixels.get_size()).has_point(sample), label + " inside capture"):
		return "outside"
	var actual := pixels.get_pixelv(sample)
	var difference := maxi(absi(actual.r8 - expected.r8), maxi(absi(actual.g8 - expected.g8), absi(actual.b8 - expected.b8)))
	_check(difference <= tolerance, "%s: %s expected %s (RGB tolerance %d)" % [label, actual.to_html(false), expected.to_html(false), tolerance])
	return actual.to_html(false)

func _capture(wired: Dictionary, name: String, pending: bool = false) -> void:
	var app: ContactListApp = wired.app
	var panel: Control = app.contacts_panel
	var profile: Preferences = wired.profile
	var provider: Presentation = wired.provider
	_caption.text = "CONTACTS PRESENTATION FIXTURE\n\n%s\n\nSynthetic correspondence and pink row portrait.\nReal controls; memory-only owner.\n\n1280 x 720 logical / 640 x 360 capture" % name
	await _settle()
	var roles: Dictionary = CONTACTS_THEME.resolve(wired.palette, wired.day, profile.high_contrast, profile.colour_preset)
	var tolerance := 1 if wired.day > 1 and not profile.high_contrast else 0
	_check(panel.get_global_rect() == Rect2(480, 64, 800, 656), name + " full Contacts placement")
	_check(panel.selected_friend == "lavinia", name + " selected conversation retained")
	_check(panel._entries == wired.source_entries and provider.entries == wired.source_entries, name + " exact committed correspondence retained")
	_check(not app.get_node("VBoxContainer/TopBar").visible, name + " no duplicate top bar")
	for role: String in ["instrument", "paper", "plum", "bone", "ink", "gold"]:
		_check(panel.theme.get_color(role, "Contacts") == roles[role], name + " installed role: " + role)
	var focused: Control = _viewport.gui_get_focus_owner()
	if _check(focused != null and app.is_ancestor_of(focused), name + " focus retained in Contacts"):
		_check(LOGICAL_RECT.encloses(focused.get_global_rect()), name + " focus target inside native capture")
		_check(panel.transcript.get_global_rect().encloses(focused.get_global_rect()), name + " focus target visible inside transcript")
		var focus_style: StyleBoxFlat = focused.get_theme_stylebox("focus", "Button")
		_check(focus_style.border_color == roles.ink, name + " authored focus border on transcript paper")
	if pending:
		_check(not app._ordinary_pending.is_empty() and app._ordinary_pending == provider.pending, name + " exact pending command retained")
		_check(app._ordinary_choices.is_empty() and not app._ordinary_retry.disabled, name + " pending retry replaces choices")
		_check(focused == app._ordinary_retry and app._status_label.visible, name + " pending feedback and retry focus visible")
		_check(provider.calls.prepare == 1 and provider.calls.acknowledge == 1 and provider.calls.cancel == 0, name + " exactly one memory-only pending action")
	else:
		_check(app._ordinary_choices.size() == 3 and focused == app._ordinary_choices[1], name + " ordinary choices retained with middle choice focused")
		_check(provider.calls.prepare == 0 and provider.calls.acknowledge == 0 and provider.calls.cancel == 0, name + " appearance never submits a reply")
	_check(panel.rows[1].portrait_texture == wired.portrait, name + " original synthetic portrait retained")
	_check(panel.rows[1].modulate == Color.WHITE and panel.rows[1].self_modulate == Color.WHITE, name + " portrait modulation stays neutral")
	var pixels := _viewport.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), name + " viewport rendered"): return
	# Clear plane interiors avoid row focus, text, choices, notices and the scroll border.
	var instrument := _pixel(pixels, panel.global_position + Vector2(100, 600), roles.instrument, name + " instrument", tolerance)
	var paper := _pixel(pixels, panel.global_position + Vector2(790, 108), roles.paper, name + " paper", tolerance)
	var art := _pixel(pixels, panel.rows[1].global_position + Vector2(24, 48), ART_COLOUR, name + " exact untinted portrait")
	var focus_pixel := ""
	if is_instance_valid(focused):
		# The 2-logical-pixel border expands four pixels beyond the button.
		# Its bottom strip occupies height+2..height+4, clear of the caption.
		focus_pixel = _pixel(pixels, focused.global_position + Vector2(focused.size.x * 0.65, focused.size.y + 3), roles.ink, name + " exact focus ring")
	_check(pixels.save_png(FOLDER.path_join(name + ".png")) == OK, name + " PNG saved")
	_samples.append({"file": name + ".png", "palette": str(wired.palette), "day": wired.day,
		"high_contrast": profile.high_contrast, "colour_preset": profile.colour_preset,
		"instrument_pixel": instrument, "paper_pixel": paper, "art_pixel": art, "focus_pixel": focus_pixel,
		"material_rgb_tolerance_levels": tolerance, "pending": pending, "calls": provider.calls.duplicate(true)})

func _recolour(wired: Dictionary, contrast: bool, preset: String, name: String, pending: bool = false) -> void:
	var before := _view_state(wired.app)
	var calls_before: Dictionary = wired.provider.calls.duplicate(true)
	var pending_before: Dictionary = wired.provider.pending.duplicate(true)
	wired.profile.present(contrast, preset)
	await _settle()
	_check(_view_state(wired.app) == before, name + " appearance preserves content, controls, pending state, scroll and focus")
	_check(wired.provider.calls == calls_before and wired.provider.pending == pending_before, name + " appearance never calls correspondence or command owner")
	await _capture(wired, name, pending)

func _run() -> void:
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty(), "isolated wrapper root required") \
		or not _check(DisplayServer.get_name() != "headless", "native renderer required"):
		for failure: String in _failures: printerr(failure)
		quit(1)
		return
	if not _check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER)) == OK, "capture directory available"):
		quit(1)
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.size_2d_override = Vector2i(1280, 720)
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("050607")
	backdrop.size = LOGICAL_RECT.size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(backdrop)
	_caption = Label.new()
	_caption.position = Vector2(24, 80)
	_caption.size = Vector2(432, 560)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_caption)
	for day: int in [1, 7]:
		var wired := await _mount(&"after_hours", day)
		if wired.is_empty(): continue
		await _capture(wired, "after-hours-day%d-standard" % day)
		if day == 7:
			await _recolour(wired, true, "standard", "after-hours-day7-high-contrast")
			await _recolour(wired, false, "deutan", "after-hours-day7-deutan")
		wired.app.queue_free()
		await process_frame
	var midnight := await _mount(&"midnight", 7)
	if not midnight.is_empty():
		await _capture(midnight, "midnight-day7-standard")
		midnight.app._ordinary_choices[1].pressed.emit()
		await _settle()
		await _recolour(midnight, true, "standard", "midnight-day7-pending-high-contrast", true)
		midnight.app.queue_free()
	_check(_samples.size() == 6, "six requested native captures")
	var file := FileAccess.open(FOLDER.path_join("measurements.json"), FileAccess.WRITE)
	if _check(file != null, "native report opened"):
		file.store_string(JSON.stringify({"ok": _failures.is_empty(), "checks": _checks,
			"captures": _samples.size(), "samples": _samples, "failures": _failures,
			"fixture": "Real Contacts controls; synthetic correspondence and row portrait. Memory-only owner deliberately retains one pending reply. No bootstrap, player saves or real commands.",
			"sampling": "Clear instrument/paper interiors avoid the scroll border. The focus sample is in the expanded button ring's bottom strip. Computed WeekTint permits at most one RGB level of renderer rounding; authored Day-1/HC materials, focus ink and portrait remain exact."}, "\t") + "\n")
		file.close()
	for failure: String in _failures: printerr(failure)
	if _failures.is_empty(): print("CONTACTS_WEEK_TINT_NATIVE_VERIFIED captures=", _samples.size(), " checks=", _checks)
	else: printerr("CONTACTS_WEEK_TINT_NATIVE_FAILED")
	_viewport.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)
