extends SceneTree
## Production Backup scene; external operation owner is injected by the fixture.
const LOCATORS := ["autosave", "quick", "slot:1", "slot:2", "slot:3", "slot:4", "slot:5", "slot:6", "slot:7"]
const Fixtures := preload("res://tests/contacts_shell/test_contacts_shell.gd")

# Pixel deliberately uses the production fallback; readable is an explicit choice.
class TypographyProfile extends Fixtures.FakeProfile:
	var font_style := "pixel"
	func get_preference(path: StringName, default: Variant = null) -> Variant:
		if path == &"preferences.accessibility.font_style" and font_style == "readable":
			return font_style
		return super.get_preference(path, default)

var tested_font_style := "pixel"
var title_tail_runs: Array[String] = []
var drawer_measurements: Array[Dictionary] = []
var captures: Array[Dictionary] = []

func typography_profile() -> TypographyProfile:
	var profile := TypographyProfile.new()
	profile.font_style = tested_font_style
	return profile

class IsolatedDesktop extends ComputerDesktop:
	# This scene fixture supplies every owner; it does not start a player account.
	func _configure_from_bootstrap() -> void: pass

class CapturedRun extends RefCounted:
	func get_run_configuration() -> Dictionary:
		return {"ok": true, "value": {"dark_mode": false}}

class FakeBackupPort extends RefCounted:
	signal projection_changed()
	var records: Array = []
	var prepared: Array = []
	var committed: Array = []
	var cancelled: Array = []
	var tokens: Dictionary = {}
	var revision := 1
	var reject_commit := false
	var reject_projection := false
	var allow_actions := true
	var title_context := false
	func _init() -> void:
		for locator in ["autosave", "quick", "slot:1", "slot:2", "slot:3", "slot:4", "slot:5", "slot:6", "slot:7"]:
			records.append({"locator": locator, "state": "occupied" if locator in ["autosave", "slot:2"] else "empty",
				"day": 7 if locator in ["autosave", "slot:2"] else null,
				"saved_time": "09:07" if locator in ["autosave", "slot:2"] else null,
				"fallback": false, "load_day": null, "load_saved_time": null, "reason": "",
				"actions": {"save": locator != "autosave", "load": locator in ["autosave", "slot:2"], "delete": locator in ["autosave", "slot:2"]}})
		records[8].state = "unavailable"
		records[8].reason = "unreadable"
		records[8].actions.delete = true
	func get_projection() -> Dictionary:
		if reject_projection:
			return {"ok": false, "code": &"backup_owner_unavailable"}
		var view: Array = records.duplicate(true)
		if not allow_actions:
			for record in view:
				record.actions = {"save": false, "load": false, "delete": false}
		return {"ok": true, "value": {"records": view, "save_capability": {"enabled": allow_actions, "reason": ""}}}
	func prepare_action(action: String, locator: String) -> Dictionary:
		var record: Dictionary = records[LOCATORS.find(locator)]
		if not allow_actions or not record.actions.get(action, false):
			return {"ok": false, "code": &"backup_action_unavailable"}
		var kind := "none"
		if action == "delete":
			kind = "delete"
		elif action == "load":
			kind = ("fallback" if record.fallback else "none") if title_context else ("replace_progress_fallback" if record.fallback else "replace_progress")
		elif action == "save" and record.state != "empty" and locator != "quick":
			kind = "overwrite"
		var token := "fixture-token-%d" % (prepared.size() + 1)
		prepared.append({"action": action, "locator": locator, "token": token})
		tokens[token] = {"action": action, "locator": locator, "revision": revision}
		return {"ok": true, "value": {"confirmation_required": kind != "none", "token": token,
			"confirmation_kind": kind, "record": record.duplicate(true)}}
	func commit_action(token: String) -> Dictionary:
		if not tokens.has(token):
			return {"ok": false, "code": &"backup_stale_preparation"}
		var request: Dictionary = tokens[token]
		tokens.erase(token)
		if request.revision != revision:
			return {"ok": false, "code": &"backup_stale_preparation"}
		if reject_commit:
			reject_commit = false
			return {"ok": false, "code": &"backup_commit_failed"}
		committed.append(request.duplicate(true))
		var record: Dictionary = records[LOCATORS.find(request.locator)]
		if request.action == "save":
			record.state = "occupied"
			record.day = 3
			record.saved_time = "10:24"
			record.actions.load = true
			record.actions.delete = true
		elif request.action == "delete":
			record.state = "empty"
			record.day = null
			record.saved_time = null
			record.actions.load = false
			record.actions.delete = false
		revision += 1
		return {"ok": true, "value": {"action": request.action, "locator": request.locator}}
	func cancel_action(token: String) -> void:
		cancelled.append(token)
		tokens.erase(token)

var failures: Array[String] = []
var checks_run := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks_run += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func settle() -> void:
	for frame in range(6):
		await process_frame

func capture_layout(app: Control, name: String) -> void:
	var directory := OS.get_environment("DWM_BACKUP_CAPTURE_DIR")
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(not picture.is_empty(), "Rendered viewport has pixels")
	var path := directory.path_join(name + ".png")
	check(picture.save_png(path) == OK, "Rendered viewport saved: " + name)
	var geometry: Array[Dictionary] = []
	for drawer in app.drawer_buttons.values():
		geometry.append({"identity": drawer.identity_label.text, "state": drawer.state_label.text,
			"drawer": str(drawer.get_global_rect()), "identity_rect": str(drawer.identity_label.get_global_rect()),
			"state_rect": str(drawer.state_label.get_global_rect()), "focused": drawer.has_focus(), "unavailable": drawer.unavailable})
	var actions: Array[Dictionary] = []
	for key: Button in app.action_buttons.values():
		actions.append({"caption": key.caption.text, "rect": str(key.get_global_rect()), "caption_rect": str(key.caption.get_global_rect()), "focused": key.has_focus(), "risk": key.risk})
	captures.append({"name": name, "size": [picture.get_width(), picture.get_height()], "drawers": geometry,
		"body": str(app.get_global_rect()), "host": str(app.get_parent().get_global_rect()),
		"info": str(app.info_scroll.get_global_rect()), "status": str(app.status_label.get_global_rect()),
		"dock": str(app.action_dock.get_global_rect()), "actions": actions, "recovering": app._recovering,
		"confirmation": is_instance_valid(app.confirmation)})

func press_key(code: Key, shifted: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shifted
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shifted
	Input.parse_input_event(event)
	await process_frame

func check_rect(control: Control, app: Control, expected: Rect2, description: String) -> void:
	var actual := Rect2(control.global_position - app.global_position, control.size)
	check(actual.is_equal_approx(expected), description + ": " + str(actual))

func check_geometry(app: Control) -> void:
	check(app.size.x >= 800 and app.size.y == 656, "Backup uses the available host width and original height")
	check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(app.get_global_rect()), "Backup body stays inside the actual stage")
	check(app.get_parent().get_global_rect().encloses(app.get_global_rect()), "Backup body stays inside its actual host")
	check(app.drawer_buttons.keys() == LOCATORS, "Nine semantic locators retain exact row-major order")
	var top: int = 16 if app._title_login else 96
	for index in range(LOCATORS.size()):
		var drawer: Button = app.drawer_buttons[LOCATORS[index]]
		check_rect(drawer, app, Rect2(14 + (index % 3) * 196, top + (index / 3) * 184, 188, 176), "Measured cabinet drawer " + LOCATORS[index])
		check(not drawer.disabled, "Every drawer remains inspectable regardless of record availability")
		check(app.get_global_rect().encloses(drawer.get_global_rect().grow(7)), "Drawer outer focus ring stays inside the body")
	if not app._title_login:
		check_rect(app.mode_buttons["save"], app, Rect2(16, 16, 96, 64), "Save mode target retained")
		check_rect(app.mode_buttons["load"], app, Rect2(128, 16, 96, 64), "Load mode target retained")
	for region in [app.info_scroll, app.status_region, app.action_dock]:
		check(region.position.x == 610 and region.size.x == app.size.x - 624, "One cabinet split owns all inspector widths")
		check(app.get_global_rect().encloses(region.get_global_rect()), "Inspector region stays inside host")
	check(app.info_scroll.position.y == top and app.info_scroll.size.y >= 96, "Information viewport retains a usable visible area")
	check(app.info_scroll.get_rect().end.y == app.status_region.position.y, "Information stops before pinned status")
	check(app.status_region.get_rect().end.y == app.action_dock.position.y, "Status stops before pinned actions")
	check(app.action_dock.get_rect().end.y == top + 544, "Actions remain pinned to cabinet bottom")
	check(app.status_region.get_global_rect().encloses(app.status_label.get_global_rect()), "Full status fits its allocation")
	check(app.status_label.max_lines_visible == -1, "Status is not line capped")
	for scroll in app.find_children("*", "ScrollContainer", true, false):
		check(scroll == app.info_scroll, "Cabinet, status and actions have no competing scroll owner")
	check(not app.info_scroll.is_ancestor_of(app.status_region) and not app.info_scroll.is_ancestor_of(app.action_dock), "Status and actions cannot scroll away with information")

func check_drawer_text(app: Control, font_size: int) -> void:
	for drawer in app.drawer_buttons.values():
		var labels: Array = drawer.find_children("*", "Label", true, false)
		if not drawer.get_global_rect().encloses(drawer.state_label.get_global_rect()):
			var measured := {"style": tested_font_style, "identity": drawer.identity_label.text, "state": drawer.state_label.text, "labels": []}
			for entry: Label in [drawer.identity_label, drawer.state_label]:
				var face: Font = entry.get_theme_font("font")
				var points: int = entry.get_theme_font_size("font_size")
				var sizes: Array[Dictionary] = []
				for width: int in [128, 136, 144]:
					var minimum: Vector2 = face.get_multiline_string_size(entry.text, HORIZONTAL_ALIGNMENT_LEFT, width, points, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
					sizes.append({"width": width, "minimum": [minimum.x, minimum.y]})
				measured.labels.append({"text": entry.text, "font_size": points, "font": face.resource_path, "measures": sizes})
			drawer_measurements.append(measured)
		check(drawer.identity_label.get_rect().end.y + 4 <= drawer.state_label.position.y, "Drawer identity and state have explicit separation")
		check(drawer.identity_label.position.y >= 4 and drawer.state_label.get_rect().end.y <= 160, "Drawer labels clear top border and lower decoration band")
		check(not labels.is_empty(), "Drawer has semantic visible identity/state text")
		for label in labels:
			check(drawer.get_global_rect().encloses(label.get_global_rect()), "Drawer text fits fixed geometry: %s style=%s path=%s rect=%s drawer=%s" % [label.text, tested_font_style, label.get_path(), label.get_rect(), drawer.size])
			check(label.get_theme_font_size("font_size") == font_size, "Drawer text follows requested text preset")
			check(label.max_lines_visible == -1, "Drawer text remains complete")
			var font: Font = label.get_theme_font("font")
			for character in label.text:
				if character != "\n":
					check(font.has_char(character.unicode_at(0)), "Drawer font contains its visible glyphs")

func check_key_caption(key: Button) -> void:
	var caption: Label = key.get_node_or_null("Caption")
	check(caption != null, "Action has a real visible Caption")
	if caption == null:
		return
	var expected: String = key.accessibility_name
	if key.name in ["SaveMode", "LoadMode"]:
		var app: Node = key.get_parent()
		while not app is BackupApp:
			app = app.get_parent()
		var role := "save" if key.name == "SaveMode" else "load"
		expected = app._fit_caption(key.accessibility_name, app._compact_text(role, key.accessibility_name), caption)
	check(caption.text == expected and not caption.text.is_empty(), "Visible action preserves full copy or its existing authored mode contract")
	check(key.size.x >= 48 and key.size.y >= 48, "Action preserves the minimum interactive target")
	if key.get_parent().name == "PinnedActions":
		check(Rect2(Vector2.ZERO, key.get_parent().size).encloses(key.get_rect()), "Host-owned action stays fully inside the fixed dock")
	check(key.get_global_rect().encloses(caption.get_global_rect()), "Action caption fits its fixed target: %s style=%s path=%s position=%s size=%s caption=%s parent=%s" % [caption.text, tested_font_style, key.get_path(), key.position, key.size, caption.size, key.get_parent().size])
	check(caption.max_lines_visible == -1, "Action caption is not line capped")
	var font: Font = caption.get_theme_font("font")
	for character in caption.text:
		check(font.has_char(character.unicode_at(0)), "Action font contains visible glyph")

func check_recovery_custody(desktop: Control, app: Control) -> void:
	var locator_before: String = app.selected_locator
	var mode_before: String = app.active_mode
	var status_before: String = app.status_label.text
	check(not app.can_return_home(), "Recoverable error owns foreground custody until Cancel or re-entry")
	check(not desktop.open_app(&"backup").get("ok", false), "Repeated active-app opening cannot bypass recovery")
	desktop.home_button.pressed.emit()
	app.mode_buttons["save"].pressed.emit()
	app.drawer_buttons["quick"].pressed.emit()
	check(app.visible and app.active_mode == mode_before and app.selected_locator == locator_before and app.status_label.text == status_before, "Recovery prevents Home, mode and drawer actions from erasing error or selection")
	for key in app.mode_buttons.values() + app.drawer_buttons.values():
		check(key.focus_mode == Control.FOCUS_NONE, "Recovery excludes background modes and drawers from focus")
	check(desktop.home_button.focus_mode == Control.FOCUS_NONE, "Recovery excludes shared Home from focus")
	var allowed: Array[Control] = []
	for key in app.action_buttons.values():
		allowed.append(key)
	if app.info_scroll.focus_mode == Control.FOCUS_ALL:
		allowed.append(app.info_scroll)
	for step in range(6):
		await press_key(KEY_TAB)
		check(root.gui_get_focus_owner() in allowed, "Recovery Tab cycle remains within real recovery controls")

func verify_ui(desktop: Control, app: Control, port: FakeBackupPort, locale: Node, profile: RefCounted) -> void:
	check(app.active_mode == "save" and app.selected_locator == "slot:1", "First opening starts Save plus Slot1")
	check(app.drawer_buttons["slot:1"].has_focus(), "First opening focuses the selected Slot1")
	check_geometry(app)
	check(port.prepared.is_empty() and port.committed.is_empty(), "First projection performs no record operation")
	app.mode_buttons["save"].grab_focus()
	await press_key(KEY_RIGHT)
	check(app.mode_buttons["load"].has_focus() and app.active_mode == "save", "Mode Right moves focus without changing Save selection")
	check(app.action_buttons.keys() == ["save"], "Focus on inactive Load does not change action set")
	await press_key(KEY_ENTER)
	await settle()
	check(app.active_mode == "load" and app.selected_locator == "slot:1", "Mode activation preserves shared drawer selection")
	check(app.action_buttons.keys() == ["load", "delete"], "Load exposes only Load and Delete actions")
	check(app.action_buttons["load"].disabled and app.action_buttons["delete"].disabled, "Empty record Load and Delete remain visible disabled")
	app.mode_buttons["save"].pressed.emit()
	await settle()
	app.drawer_buttons["autosave"].grab_focus()
	await settle()
	check(app.selected_locator == "autosave", "Cabinet keyboard focus selects presentation-only drawer")
	check(app.action_buttons["save"].disabled and not app.drawer_buttons["autosave"].disabled, "Autosave Save is disabled while drawer remains inspectable")
	app.drawer_buttons["slot:1"].pressed.emit()
	await settle()
	check(port.prepared.is_empty(), "Selecting a drawer never prepares an operation")
	app.action_buttons["save"].pressed.emit()
	await settle()
	check(port.committed.size() == 1 and port.committed[0].locator == "slot:1", "Empty numbered Save commits once through injected owner")
	check(app.status_label.text == "Saved", "Saved publishes only after committed owner result")
	app.mode_buttons["load"].grab_focus()
	await settle()
	check(app.active_mode == "save" and app.status_label.text == "Saved", "Focusing mode does not erase Saved acknowledgment")
	app.mode_buttons["load"].pressed.emit()
	await settle()
	check(app.status_label.text != "Saved", "Activating another mode ends Saved acknowledgment")
	app.drawer_buttons["slot:2"].pressed.emit()
	await settle()
	app.action_buttons["load"].pressed.emit()
	await settle()
	check(is_instance_valid(app.confirmation) and app.confirmation.is_visible_in_tree(), "Load creates the shared host confirmation")
	if is_instance_valid(app.confirmation):
		check(app.confirmation.cancel_button.has_focus(), "Confirmation begins on Cancel")
		var selected_before: String = app.selected_locator
		app.drawer_buttons["quick"].pressed.emit()
		app.mode_buttons["save"].pressed.emit()
		check(app.selected_locator == selected_before and app.active_mode == "load", "Modal foreground makes lower drawer and mode actions inert")
		check(not app.can_return_home(), "Modal custody prevents leaving Backup through Home")
		await press_key(KEY_ESCAPE)
		await settle()
		check(port.cancelled.size() == 1 and port.committed.size() == 1, "Escape cancels preparation without commit")
		check(app.action_buttons["load"].has_focus(), "Cancel restores invoking Load action focus")
	app.action_buttons["load"].pressed.emit()
	await settle()
	if is_instance_valid(app.confirmation):
		port.revision += 1
		app.confirmation.confirm_button.pressed.emit()
		await settle()
		check(port.committed.size() == 1 and app.selected_locator == "slot:2", "Stale confirmation never commits or changes record selection")
		check(not app.status_label.text.is_empty(), "Stale preparation yields factual feedback")
		check(app.action_buttons.has("cancel"), "Recoverable failure offers Cancel")
		if app.action_buttons.has("cancel"):
			check(app.action_buttons["cancel"].has_focus(), "Recovery dock initially focuses Cancel")
			await check_recovery_custody(desktop, app)
			app.action_buttons["cancel"].pressed.emit()
			await settle()
	var slot3: Dictionary = port.records[4]
	slot3.state = "occupied"
	slot3.day = 2
	slot3.saved_time = "11:15"
	slot3.actions.load = true
	slot3.actions.delete = true
	app.refresh_view()
	app.drawer_buttons["slot:3"].pressed.emit()
	await settle()
	app.action_buttons["delete"].pressed.emit()
	await settle()
	check(is_instance_valid(app.confirmation), "Delete obtains a fresh shared confirmation")
	if is_instance_valid(app.confirmation):
		check(app.confirmation.cancel_button.has_focus() and app.confirmation.confirm_button.caption.text == "Delete", "Delete sheet starts safely on Cancel and uses explicit final verb")
		app.confirmation.confirm_button.pressed.emit()
		await settle()
		check(port.records[4].state == "empty" and app.selected_locator == "slot:3", "Confirmed Delete preserves drawer identity and selection while publishing Empty")
		check(app.action_buttons["load"].disabled and app.action_buttons["delete"].disabled, "Deleted Empty drawer disables record operations truthfully")
	port.records[0].fallback = true
	port.records[0].load_day = 2
	port.records[0].load_saved_time = "06:12"
	# Publish the fixture's changed records explicitly; appearance is projection-free.
	app.refresh_view()
	profile.change_scale(1.5)
	app.mode_buttons["load"].pressed.emit()
	app.drawer_buttons["autosave"].pressed.emit()
	await settle()
	check(app.info_scroll.get_v_scroll_bar().max_value > app.info_scroll.size.y, "Long factual reason creates genuine information overflow")
	check(app.info_scroll.focus_mode == Control.FOCUS_ALL, "Only overflowing information becomes a focus stop")
	var status_before: Rect2 = app.status_region.get_global_rect()
	var dock_before: Rect2 = app.action_dock.get_global_rect()
	app.info_scroll.scroll_vertical = 80
	await settle()
	app.mode_buttons["save"].pressed.emit()
	await settle()
	check(app.selected_locator == "autosave" and app.info_scroll.scroll_vertical == 80, "Mode switch preserves shared selection and lawful information offset")
	check(app.status_region.get_global_rect() == status_before and app.action_dock.get_global_rect() == dock_before, "Information scrolling cannot move status or actions")
	app.drawer_buttons["quick"].pressed.emit()
	await settle()
	check(app.info_scroll.scroll_vertical == 0, "Changing drawer resets information offset")
	check(app.info_scroll.focus_mode == Control.FOCUS_NONE, "Fitting information has no extra focus stop")
	port.records[0].fallback = false
	port.records[0].load_day = null
	port.records[0].load_saved_time = null
	app.refresh_view()
	port.records[7].state = "unavailable"
	port.records[7].actions.delete = true
	port.records[7].reason = "older_version"
	app.refresh_view()
	for language in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
		locale.change(language)
		for index in range(3):
			profile.change_scale([1.0, 1.25, 1.5][index])
			app.mode_buttons["save"].pressed.emit()
			await settle()
			check_geometry(app)
			check_drawer_text(app, ([24, 30, 36] if tested_font_style == "pixel" else [20, 25, 30])[index])
			if tested_font_style == "pixel" and ((language == "en" and index in [0, 2]) or (language != "en" and index == 2)):
				await capture_layout(app, "in-run-" + language + "-" + str(index))
			for button in app.mode_buttons.values():
				check(button.size.y == 64 and button.get_theme_font_size("font_size") == [24, 30, 36][index], "Mode uses readable full-size type in fixed64 target")
				check_key_caption(button)
			for button in app.action_buttons.values():
				check_key_caption(button)
			app.mode_buttons["load"].pressed.emit()
			await settle()
			for button in app.action_buttons.values():
				check(button.size.x == (app.action_dock.size.x - 16) / 2 and button.size.y >= 64, "Load/Delete retain two full-size dock targets")
				check_key_caption(button)
	port.records[7].reason = ""
	port.records[7].state = "empty"
	port.records[7].actions.delete = false
	app.refresh_view()
	await verify_recovery_matrix(app, port, locale, profile)
	locale.change("en")
	profile.change_scale(1.5)
	app.mode_buttons["save"].pressed.emit()
	app.drawer_buttons["slot:2"].pressed.emit()
	await settle()
	app.action_buttons["save"].pressed.emit()
	await settle()
	await capture_layout(app, "overwrite-confirmation-" + tested_font_style)
	check(is_instance_valid(app.confirmation), "Occupied numbered Save requires overwrite confirmation")
	if is_instance_valid(app.confirmation):
		check_key_caption(app.confirmation.cancel_button)
		check_key_caption(app.confirmation.confirm_button)
		port.reject_commit = true
		app.confirmation.confirm_button.pressed.emit()
		await settle()
		check(app._recovering and not is_instance_valid(app.confirmation), "Capture is actual failed-save recovery, not confirmation")
		check(app.action_buttons.has("retry") and app.action_buttons.retry.caption.text == "Overwrite", "Recovery dock retains explicit Overwrite")
		check_geometry(app)
		for button in app.action_buttons.values():
			check_key_caption(button)
		await capture_layout(app, "overwrite-recovery-dock-" + tested_font_style)
		if app.action_buttons.has("cancel"):
			app.action_buttons["cancel"].pressed.emit()
			await settle()
	profile.change_scale(1.0)
	await settle()
	app.mode_buttons["save"].pressed.emit()
	app.drawer_buttons["quick"].pressed.emit()
	await settle()
	port.reject_commit = true
	var admissions_before: int = port.prepared.size()
	app.action_buttons["save"].pressed.emit()
	await settle()
	check(not app.status_label.text.is_empty() and app.status_label.text != "Saved", "Failed direct Save shows factual error without false success")
	check(app.action_buttons.has("cancel") and app.action_buttons.has("retry"), "Failed direct Save exposes Cancel and fresh Retry")
	if app.action_buttons.has("retry"):
		app.action_buttons["retry"].pressed.emit()
		await settle()
		check(port.prepared.size() == admissions_before + 2 and app.status_label.text == "Saved", "Retry prepares a fresh operation before successful Save")
	app.mode_buttons["load"].pressed.emit()
	app.drawer_buttons["slot:2"].pressed.emit()
	await settle()
	var old_id := app.get_instance_id()
	desktop.return_home()
	await settle()
	check(not app.visible, "Home hides Backup")
	var home: Button = desktop.home_button
	var home_routes: Array = [home.focus_next, home.focus_previous, home.focus_neighbor_top, home.focus_neighbor_bottom, home.focus_neighbor_left, home.focus_neighbor_right]
	var home_focus_mode: int = home.focus_mode
	var focus_before: Control = root.gui_get_focus_owner()
	port.projection_changed.emit()
	await settle()
	check([home.focus_next, home.focus_previous, home.focus_neighbor_top, home.focus_neighbor_bottom, home.focus_neighbor_left, home.focus_neighbor_right] == home_routes, "Hidden cached Backup projection cannot rewrite shared Home routes")
	check(home.focus_mode == home_focus_mode and root.gui_get_focus_owner() == focus_before, "Hidden cached Backup projection preserves launcher focus and Home eligibility")
	port.records[3].day = 4
	port.records[3].saved_time = "08:31"
	port.revision += 1
	desktop.open_app(&"backup")
	await settle()
	check(app.get_instance_id() == old_id and app.active_mode == "load" and app.selected_locator == "slot:2", "Same-day reopen preserves one mode and drawer selection")
	var reopened_text := ""
	for label in app.drawer_buttons["slot:2"].find_children("*", "Label", true, false):
		reopened_text += label.text
	check(reopened_text.contains("4") and reopened_text.contains("08:31"), "Cached presentation rereads changed owner metadata instead of retaining authority")
	check(app.status_label.text != "Saved" and not is_instance_valid(app.confirmation), "Reopen does not cache transient acknowledgment or consent")
	app.mode_buttons["load"].grab_focus()
	await press_key(KEY_ESCAPE)
	await settle()
	check(not app.visible, "Back returns to shared Home without record command")
	port.reject_projection = true
	var rejected_open: Dictionary = desktop.open_app(&"backup")
	await settle()
	check(not rejected_open.get("ok", false) and not app.visible and desktop.icon_grid.visible, "Failed cached projection rejects reopening before visible host publication")
	port.reject_projection = false
	check(desktop.open_app(&"backup").get("ok", false), "Fresh projection allows cached Backup to reopen")
	await settle()
	var state_before: String = app.drawer_buttons["slot:2"].state_label.text
	port.reject_projection = true
	check(not app.refresh_view().get("ok", false), "Projection failure propagates to caller")
	await settle()
	check(app.drawer_buttons["slot:2"].state_label.text == state_before, "Projection failure preserves last trustworthy displayed record")
	for button in app.action_buttons.values():
		check(button.disabled, "Projection failure disables record actions instead of trusting stale capabilities")
	check(not app.status_label.text.is_empty(), "Projection failure has factual unavailable feedback")
	port.reject_projection = false
	app.refresh_view()
	app.mode_buttons["save"].pressed.emit()
	app.drawer_buttons["quick"].pressed.emit()
	await settle()
	port.reject_commit = true
	app.action_buttons["save"].pressed.emit()
	await settle()
	port.allow_actions = false
	app.refresh_view()
	await settle()
	check(app.action_buttons.keys() == ["cancel"], "Recovery with no current re-entry capability retains Cancel only")
	if app.action_buttons.has("cancel"):
		check(app.action_buttons["cancel"].has_focus(), "Cancel-only recovery preserves focus on its real action")
		app.action_buttons["cancel"].pressed.emit()
	port.allow_actions = true
	port.records[0].fallback = true
	port.records[0].load_day = 2
	port.records[0].load_saved_time = "06:12"
	profile.change_scale(1.5)
	app.mode_buttons["load"].pressed.emit()
	app.drawer_buttons["autosave"].pressed.emit()
	# Open before the deferred overflow measurement gets a frame to run.
	app.action_buttons["load"].pressed.emit()
	await settle()
	check(is_instance_valid(app.confirmation), "Overflowing fallback record opens confirmation")
	if is_instance_valid(app.confirmation):
		check(app.info_scroll.get_focus_mode_with_override() == Control.FOCUS_NONE, "Deferred information measurement cannot reactivate a modal-covered viewport")
		check(app.confirmation.is_ancestor_of(root.gui_get_focus_owner()), "Modal retains exclusive focus after deferred remeasurement")

func verify_recovery_matrix(app: Control, port: FakeBackupPort, locale: Node, profile: RefCounted) -> void:
	for language: String in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
		locale.change(language)
		for percent: float in [1.0, 1.25, 1.5]:
			profile.change_scale(percent)
			app.mode_buttons.save.pressed.emit()
			app.drawer_buttons["slot:2"].pressed.emit()
			await settle()
			app.action_buttons.save.pressed.emit()
			await settle()
			check(is_instance_valid(app.confirmation), "Recovery matrix starts with real overwrite consent")
			if not is_instance_valid(app.confirmation):
				continue
			port.reject_commit = true
			app.confirmation.confirm_button.pressed.emit()
			await settle()
			check(app._recovering and app.action_buttons.has("retry"), "Storage refusal enters real recovery")
			check_geometry(app)
			check(app.status_label.text == app._t("failed"), "Recovery status retains full localized failure")
			check(app.action_buttons.cancel.has_focus(), "Recovery retains Cancel-first focus")
			for key in app.action_buttons.values():
				check_key_caption(key)
			if percent == 1.5 and language in ["ja", "ko"]:
				await capture_layout(app, "recovery-" + language + "-150-" + tested_font_style)
			app.action_buttons.cancel.pressed.emit()
			await settle()

func check_title_login() -> void:
	title_tail_runs.append(tested_font_style)
	# Real body and fonts; title scene/owner/process boundaries have separate tests.
	var host := Control.new()
	host.position = Vector2(320, 0)
	host.size = Vector2(960, 720)
	root.add_child(host)
	var return_button := Button.new()
	return_button.position = Vector2(320, 0)
	return_button.size = Vector2(64, 64)
	host.add_child(return_button)
	var app: Control = load("res://scenes/apps/BackupApp.tscn").instantiate()
	app.configure_title_login()
	app.position = Vector2(80, 64)
	app.size = Vector2(800, 656)
	host.add_child(app)
	var locale := Fixtures.FakeLocale.new()
	root.add_child(locale)
	var profile := typography_profile()
	var port := FakeBackupPort.new()
	port.title_context = true
	app.configure_desktop_home(return_button)
	check(app.configure_backup(port, locale, profile).get("ok", false), "Title body configures with injected title operations")
	app.show_window()
	await settle()
	port.records[7].state = "unavailable"
	port.records[7].actions.delete = true
	port.records[7].reason = "older_version"
	app.refresh_view()
	for language in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
		locale.change(language)
		for index in range(3):
			profile.change_scale([1.0, 1.25, 1.5][index])
			await settle()
			check(app.mode_buttons.is_empty() and app.active_mode == "load", "Title has no instantiated or phantom mode keys")
			check(app.action_buttons.keys() == ["load", "delete"], "Title exposes only Load and Delete")
			check(app.action_buttons.load.risk == "neutral", "Title ordinary Load is neutral")
			check(app.selected_locator == "autosave", "Loadable Autosave is the title first selection")
			check_geometry(app)
			check(app.size.x == 928 and app.position.x == 16, "Title uses available width before narrowing inspector")
			check_drawer_text(app, ([24, 30, 36] if tested_font_style == "pixel" else [20, 25, 30])[index])
			if tested_font_style == "pixel" and ((language == "en" and index in [0, 2]) or (language != "en" and index == 2)):
				await capture_layout(app, "title-" + language + "-" + str(index))
			for key in app.action_buttons.values():
				check_key_caption(key)
			app.drawer_buttons.autosave.grab_focus()
			await press_key(KEY_UP)
			check(app.drawer_buttons.autosave.has_focus(), "Title top-row Up is consumed without phantom mode or Return jump")
			check(app.action_buttons.delete.get_node(app.action_buttons.delete.focus_next) == return_button, "Return follows enabled inspector actions")
	check(port.prepared.is_empty() and port.committed.is_empty(), "Title selection and focus never prepare or load records")
	port.records[0].actions.load = false
	app.show_window()
	await settle()
	check(app.selected_locator == "slot:2", "Title reopening selects first loadable row-major drawer")
	for record: Dictionary in port.records:
		record.actions.load = false
	app.show_window()
	await settle()
	check(app.selected_locator == "autosave" and app.action_buttons.load.disabled, "No loadable records selects Autosave with disabled Load")
	check(not app.drawer_buttons.autosave.disabled, "Unavailable action leaves title drawer inspectable")
	port.records[0].actions.load = true
	port.records[0].fallback = true
	port.records[0].load_day = 2
	port.records[0].load_saved_time = "08:12"
	app.show_window()
	await settle()
	app._source_action = "load"
	app._confirmation_kind = "fallback"
	var copy: Dictionary = app._confirmation_copy(port.records[0])
	check(copy.risk == "neutral" and copy.body.contains(app._t("fallback")) and not copy.body.contains(app._t("replace_progress")), "Title fallback copy discloses only fallback, with neutral final Load")
	app._set_mode("save")
	check(app.active_mode == "load" and not app.action_buttons.has("save"), "Title cannot switch into Save programmatically")
	host.queue_free()
	locale.queue_free()
	await settle()

func _bind_isolated_desktop(child: Node) -> void:
	if child is ComputerDesktop:
		child.set_script(IsolatedDesktop)
		check(child.configure_run_configuration(CapturedRun.new()).get("ok", false), "Desktop admits the isolated captured run before ready")

func _run() -> void:
	if OS.get_environment("DWM_BACKUP_MEASURE_LAYOUT") == "1":
		await measure_layout_budget()
		return
	for font_style: String in ["pixel", "readable"]:
		tested_font_style = font_style
		await _run_typography()
	check(title_tail_runs == ["pixel", "readable"], "Title-login tail executes for default pixel and readable")
	print(JSON.stringify({"checks_run": checks_run, "suite": "BackupUI", "font_styles": ["pixel", "readable"], "title_tail_runs": title_tail_runs, "failures": failures, "drawer_measurements": drawer_measurements, "captures": captures}))
	if failures.is_empty():
		print("BACKUP_UI_PASS")
	quit(0 if failures.is_empty() else 1)

func _run_typography() -> void:
	var failures_before := failures.size()
	root.size = Vector2i(1280, 720)
	var app: Control = load("res://scenes/apps/BackupApp.tscn").instantiate()
	app.size = Vector2(800, 656)
	root.add_child(app)
	await settle()
	for method in ["configure_backup", "refresh_view", "get_desktop_ready_result", "configure_desktop_home"]:
		check(app.has_method(method), "Backup provides " + method + " (expected initial red)")
	var properties: Array[String] = []
	for property in app.get_property_list():
		properties.append(property.name)
	for property in ["mode_buttons", "drawer_buttons", "active_mode", "selected_locator", "info_scroll", "action_dock"]:
		check(property in properties, "Backup exposes " + property + " (expected initial red)")
	app.queue_free()
	await settle()
	if failures.size() == failures_before:
		var main: Control = load("res://scenes/main/MainGameScene.tscn").instantiate()
		main.get_node("RootHBox/ComputerPanel").child_entered_tree.connect(_bind_isolated_desktop)
		root.add_child(main)
		await settle()
		var desktop = main.find_child("ComputerDesktop", true, false)
		var port := FakeBackupPort.new()
		var locale := Fixtures.FakeLocale.new()
		root.add_child(locale)
		var profile := typography_profile()
		var owner := Fixtures.FakeHost.new()
		owner.reject_next = false
		check(desktop.configure_backup_port(port).get("ok", false), "Desktop accepts injected Backup operation owner")
		check(desktop.configure_contacts(Fixtures.FakePort.new(), locale, profile, owner).get("ok", false), "Desktop retains shared host and preferences")
		var opened: Dictionary = desktop.open_app(&"backup")
		check(opened.get("ok", false), "Backup opens through the real third-app desktop route")
		await settle()
		if opened.get("ok", false):
			app = desktop.app_window_host.find_child("BackupApp", false, false)
			check(app != null, "Actual Backup scene is mounted")
			if app != null:
				check((app.global_position - desktop.global_position).is_equal_approx(Vector2.ZERO), "Backup fills the workfield above the shared footer")
				await verify_ui(desktop, app, port, locale, profile)
				var old_id := app.get_instance_id()
				var cancellations_before: int = port.cancelled.size()
				desktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 2})
				await settle()
				check(desktop.app_window_host.get_child_count() == 0, "Logical day change evicts Backup presentation cache")
				check(port.cancelled.size() == cancellations_before + 1, "External day eviction cancels outstanding confirmation before freeing Backup")
				var first: Button = desktop.launcher_buttons[&"minesweeper"]
				check(first.focus_mode == Control.FOCUS_ALL and not first.disabled, "Modal eviction restores lower launcher input")
				first.grab_focus()
				await press_key(KEY_RIGHT)
				check(desktop.launcher_buttons[&"contacts"].has_focus(), "Launcher remains navigable after modal cancellation")
				desktop.open_app(&"backup")
				await settle()
				var fresh = desktop.app_window_host.find_child("BackupApp", false, false)
				check(fresh.get_instance_id() != old_id and fresh.active_mode == "save" and fresh.selected_locator == "slot:1", "New day rebuilds Save plusSlot1 without prior mode/cache")
		main.queue_free()
		locale.queue_free()
		await settle()
		var restored: Control = load("res://scenes/main/MainGameScene.tscn").instantiate()
		restored.get_node("RootHBox/ComputerPanel").child_entered_tree.connect(_bind_isolated_desktop)
		root.add_child(restored)
		await settle()
		var restored_desktop = restored.find_child("ComputerDesktop", true, false)
		restored_desktop.configure_backup_port(port)
		owner.active = &"backup"
		var restore_result: Dictionary = restored_desktop.configure_contacts(Fixtures.FakePort.new(), null, profile, owner, 2)
		check(restore_result.get("ok", false), "Restored active Backup configures through shared route")
		await settle()
		var restored_app = restored_desktop.app_window_host.find_child("BackupApp", false, false)
		check(restored_app != null, "Restored Backup mounts automatically")
		if restored_app != null:
			check(restored_app.active_mode == "save" and restored_app.selected_locator == "slot:1", "Restored Backup starts with fresh presentation defaults")
			check(not is_instance_valid(restored_app.confirmation) and restored_app.status_label.text.is_empty(), "Restore recreates no modal or transient status")
		restored.queue_free()
		await settle()
	# This separate fixture owns its own tree and still reports failures honestly.
	await check_title_login()

# Measurement mode is explicitly separate from Backup acceptance. It uses the
# production faces/copy and real Label shaping without altering runtime geometry.
func measure_layout_budget() -> void:
	root.size = Vector2i(1280, 720)
	var typography := preload("res://scripts/ui/UiTypography.gd")
	var rows: Array[Dictionary] = []
	for style: String in ["pixel", "readable"]:
		for language: String in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
			for percent: int in [100, 125, 150]:
				var face: Font = typography.font(language, percent, style)
				var points: int = typography.font_size(language, percent, 20, style)
				var copy: Dictionary = BackupApp.COPY[language]
				var texts: Array[String] = [copy.autosave, copy.quick, str(copy.slot).format({"n": 7}),
					str(copy.day).format({"day": 7, "time": "09:07"}), copy.empty, copy.unavailable, copy.older]
				for key: String in ["autosave", "quick", "slot"]:
					if BackupApp.COMPACT_COPY.get(language, {}).has(key):
						texts.append(str(BackupApp.COMPACT_COPY[language][key]).format({"n": 7}))
				var row := {"texts": texts, "locale": language, "style": style, "percent": percent, "points": points, "natural": {}, "widths": []}
				for text: String in texts:
					row.natural[text] = face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
				var labels: Array[Label] = []
				for width: int in range(144, 202, 2):
					for text: String in texts:
						var label := Label.new()
						label.text = text
						label.add_theme_font_override("font", face)
						label.add_theme_font_size_override("font_size", points)
						label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
						label.size.x = width - 8 # 4px clear paper edge on each side.
						root.add_child(label)
						labels.append(label)
				await settle()
				var cursor := 0
				for width: int in range(144, 202, 2):
					var heights: Array[float] = []
					for text: String in texts:
						heights.append(labels[cursor].size.y)
						cursor += 1
					row.widths.append({"drawer_width": width, "text_width": width - 8, "heights": heights})
				rows.append(row)
				for label: Label in labels:
					label.queue_free()
				await settle()
	print(JSON.stringify({"suite": "BackupLayoutMeasurement", "measurements": rows, "acceptance": false}))
	print("BACKUP_LAYOUT_MEASUREMENT_DONE")
	quit(0)
