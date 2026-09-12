extends GutTest
## Real Desktop/Contacts scene with memory-backed preferences and a counted owner port.

const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const CONTACTS_THEME := preload("res://scripts/ui/contacts/ContactsTheme.gd")


class IsolatedDesktop extends "res://scripts/ui/ComputerDesktop.gd":
	func _configure_from_bootstrap() -> void:
		pass


class RunConfiguration extends RefCounted:
	var dark := false
	func get_run_configuration() -> Dictionary:
		return {"ok":true,"value":{"dark_mode":dark}}


class CountedContactsPort extends RefCounted:
	signal release_ack
	var projection_calls := 0
	var open_calls := 0
	var reply_calls := 0
	var prepare_calls := 0
	var pending_calls := 0
	var acknowledge_calls := 0
	var cancel_calls := 0
	var pending: Dictionary = {}
	var committed := false
	var fail_save := false
	var block_ack := false
	var ack_waiting := false
	var unread := false
	var group_reply_required := false

	func get_projection(friend_id: String, _primary: String = "en", _secondary: String = "") -> Dictionary:
		projection_calls += 1
		var entries: Array = []
		if friend_id == "lavinia":
			for index: int in range(16):
				entries.append(_entry("note-%02d" % index, index % 3 == 0,
					"A retained public note %02d. " % index + "Readable text. ".repeat(5),
					"12:%02d" % index))
			if committed:
				entries.append(_entry("ordinary-outgoing", true, "Selected B.", "12:20"))
		var choices: Array = []
		if friend_id == "lavinia" and not committed and not group_reply_required:
			for letter: String in ["a", "b", "c"]:
				choices.append({"reply_id":"reply.lavinia.day5." + letter,
					"line_id":"line.contact.ordinary.lavinia.day5.reply." + letter,
					"text":"Selected " + letter.to_upper() + "."})
		return {"ok":true,"value":{"friend_id":friend_id,"entries":entries,
			"unread":{"lavinia":unread},"reply_required":group_reply_required,
			"ordinary_choices":choices}}

	func open_friend(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
		open_calls += 1
		return get_projection(friend_id, primary, secondary)

	func reply_to_group(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
		reply_calls += 1
		return get_projection(friend_id, primary, secondary)

	func get_pending_ordinary_reply() -> Dictionary:
		pending_calls += 1
		return {"ok":true,"value":{} if pending.is_empty() else {
			"command":pending.duplicate(true),"candidate":{},"message_batch":[]}}

	func prepare_ordinary_reply(friend_id: String, reply_id: String, locale: String = "en") -> Dictionary:
		prepare_calls += 1
		if not pending.is_empty(): return {"ok":false,"code":&"pending_reply_exists"}
		pending = {"command_id":"choice-%d" % prepare_calls,
			"command_issuer_receipt":{"fixture":true},"live_session":{"generation":1},
			"source_contacts_sha256":"frozen","source_day":5,"friend_id":friend_id,
			"reply_id":reply_id,"locale":locale,
			"rendered_line":{"view_token":"choice-%d" % prepare_calls,
				"line_id":"line.contact.ordinary.lavinia.day5.reply." + reply_id.right(1),
				"text":"Selected " + reply_id.right(1).to_upper() + "."}}
		return get_pending_ordinary_reply()

	func acknowledge_ordinary_reply(command: Dictionary, line: Dictionary,
			primary: String = "en", secondary: String = "") -> Dictionary:
		acknowledge_calls += 1
		if command != pending or line != pending.get("rendered_line"):
			return {"ok":false,"code":&"fixture_command_mismatch"}
		if block_ack:
			ack_waiting = true
			await release_ack
			ack_waiting = false
		if fail_save: return {"ok":false,"code":&"write_failed"}
		committed = true
		pending = {}
		return get_projection(command.friend_id, primary, secondary)

	func cancel_pending_ordinary_reply(command: Dictionary) -> Dictionary:
		cancel_calls += 1
		if command != pending: return {"ok":false,"code":&"fixture_command_mismatch"}
		pending = {}
		return {"ok":true}

	func _entry(id: String, outgoing: bool, text: String, stamp: String) -> Dictionary:
		return {"id":id,"outgoing":outgoing,
			"texts":{"en":text,"zh-CN":text,"zh-HK":text},"timestamp":stamp}

	func call_counts() -> Dictionary:
		return {"projection":projection_calls,"open":open_calls,"reply":reply_calls,
			"prepare":prepare_calls,"pending":pending_calls,
			"acknowledge":acknowledge_calls,"cancel":cancel_calls}


func _fixture(dark: bool = false, day: int = 5, unread: bool = false,
		group_reply_required: bool = false) -> Dictionary:
	var files := FILES.new()
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("memory/contacts-run-presentation/profile", files)).ok)
	var profile_document: Dictionary = profile.get_profile_snapshot()
	profile_document.preferences.dark_mode.available = true
	profile_document.preferences.dark_mode.next_run_enabled = not dark
	assert_true(profile.commit_prepared_profile(profile_document).ok)
	var localization := LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(profile).ok)
	var host := HOST.new()
	host.reset(day)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 720)
	viewport.handle_input_locally = true
	add_child_autofree(viewport)
	var run := RunConfiguration.new()
	run.dark = dark
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	assert_true(desktop.configure_run_configuration(run).ok)
	viewport.add_child(desktop)
	var port := CountedContactsPort.new()
	port.unread = unread
	port.group_reply_required = group_reply_required
	assert_true(desktop.configure_contacts(port, localization, profile, host, day).ok)
	return {"desktop":desktop,"host":host,"run":run,"port":port,
		"profile":profile,"localization":localization,"viewport":viewport}


func _open(f: Dictionary) -> Control:
	var opened: Dictionary = f.desktop.open_app(&"contacts")
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false): return null
	return opened.value.app as Control


func _open_lavinia(app: Control) -> void:
	app.contacts_panel.rows[1].pressed.emit()
	assert_eq(app.contacts_panel.selected_friend,"lavinia")


func _settle() -> void:
	for frame: int in 6:
		await get_tree().process_frame


func _label_identity_and_copy(owner: Node) -> Dictionary:
	var result: Dictionary = {}
	for label: Node in owner.find_children("*", "Label", true, false):
		result[label.get_instance_id()] = (label as Label).text
	return result


func _assert_paper_button_colours(button: Button, roles: Dictionary) -> void:
	assert_eq(button.get_theme_color("font_color"), roles.bone,
		"The instrument-filled button keeps bone copy.")
	assert_eq(button.get_theme_color("font_disabled_color"), roles.bone,
		"Pending or busy buttons keep readable authored copy while input stays disabled.")
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
	assert_not_null(focus)
	if focus != null:
		assert_eq(focus.border_color, roles.ink,
			"The expanded focus lies on paper and uses paper ink.")


func test_captured_palette_and_day_reach_contacts_without_following_next_run_preference() -> void:
	for dark: bool in [false, true]:
		var f := _fixture(dark, 5)
		var app := _open(f)
		if app == null: continue
		await _settle()
		var palette: StringName = &"midnight" if dark else &"after_hours"
		var expected: Dictionary = CONTACTS_THEME.resolve(palette, 5)
		assert_eq(app.contacts_panel.theme.get_color("instrument","Contacts"),expected.instrument)
		assert_eq(app.contacts_panel.theme.get_color("paper","Contacts"),expected.paper)
		assert_eq(app.contacts_panel.rows.size(),3)
		assert_eq(app.contacts_panel.selected_friend,"")
		assert_eq(f.profile.get_preference(&"preferences.dark_mode.next_run_enabled", dark),not dark)
		assert_true(f.profile.set_preference(&"preferences.dark_mode.next_run_enabled", dark).ok)
		await _settle()
		assert_eq(app.contacts_panel.theme.get_color("instrument","Contacts"),expected.instrument)
		assert_eq(f.port.call_counts().prepare,0)
		assert_eq(f.port.call_counts().acknowledge,0)
		assert_true(f.desktop.return_home().ok)
		var changed: Dictionary = f.host.change_day(7)
		assert_true(changed.get("ok",false),str(changed))
		if not changed.get("ok",false): continue
		assert_true(f.desktop.dispatch_desktop_eviction(changed.value.eviction_command).ok)
		await _settle()
		assert_false(f.desktop._cached_app_windows.has(&"contacts"))
		var day_seven := _open(f)
		if day_seven == null: continue
		await _settle()
		assert_eq(day_seven.contacts_panel.theme.get_color("instrument","Contacts"),
			CONTACTS_THEME.resolve(palette, 7).instrument)
		assert_eq(day_seven.contacts_panel.theme.get_color("paper","Contacts"),
			CONTACTS_THEME.resolve(palette, 7).paper)
		assert_eq(f.port.call_counts().prepare,0)
		assert_eq(f.port.call_counts().acknowledge,0)


func test_live_accessibility_recolours_existing_transcript_without_owner_or_focus_mutation() -> void:
	var f := _fixture(true, 5, true)
	var app := _open(f)
	if app == null: return
	_open_lavinia(app)
	await _settle()
	var panel: Control = app.contacts_panel
	var transcript: ScrollContainer = panel.transcript
	assert_not_null(transcript)
	transcript.grab_focus()
	transcript.scroll_vertical = 120
	await _settle()
	var scroll_before: int = transcript.scroll_vertical
	assert_gt(scroll_before,0)
	var labels_before: Dictionary = _label_identity_and_copy(panel)
	var entries_before: Array = panel._entries.duplicate(true)
	var calls_before: Dictionary = f.port.call_counts()
	var row: Button = panel.rows[1]
	var portrait: Texture2D = row.portrait_texture
	var launcher: Button = f.desktop.contacts_button
	var launcher_caption: String = launcher.caption.text
	var launcher_name: String = launcher.accessibility_name
	assert_true(launcher_caption.contains("•"))
	assert_true(launcher_name.contains("new message"))
	var choice: Button = app._ordinary_choices[0]
	var choice_caption: Label = choice.get_child(0) as Label
	assert_true(f.profile.set_preferences({
		&"preferences.accessibility.high_contrast":true,
		&"preferences.accessibility.colour_differentiation":"protan",
	}).ok)
	await _settle()
	var expected: Dictionary = CONTACTS_THEME.resolve(&"midnight",5,true,"protan")
	assert_eq(panel.theme.get_color("instrument","Contacts"),expected.instrument)
	assert_eq(panel.theme.get_color("paper","Contacts"),expected.paper)
	assert_eq(panel._header.get_theme_color("font_color"),expected.bone)
	assert_same(app._ordinary_choices[0],choice)
	assert_eq(choice_caption.get_theme_color("font_color"),expected.bone)
	_assert_paper_button_colours(choice, expected)
	assert_eq(f.port.call_counts(),calls_before,"Colour signals cannot request correspondence or ordinary commands.")
	assert_eq(launcher.caption.text,launcher_caption)
	assert_eq(launcher.accessibility_name,launcher_name)
	assert_same(panel.transcript,transcript)
	assert_same(panel.rows[1],row)
	assert_eq(_label_identity_and_copy(panel),labels_before,"Text, timestamps and Label instances remain exact.")
	assert_eq(panel._entries,entries_before)
	assert_eq(panel.selected_friend,"lavinia")
	assert_eq(transcript.scroll_vertical,scroll_before)
	assert_true(transcript.has_focus())
	assert_eq(row.portrait_texture,portrait)
	assert_eq(row.modulate,Color.WHITE)
	assert_eq(row.self_modulate,Color.WHITE)
	choice.grab_focus()
	assert_true(choice.has_focus())
	_assert_paper_button_colours(choice, expected)
	assert_true(f.desktop.return_home().ok)
	assert_true(f.profile.set_preferences({
		&"preferences.accessibility.high_contrast":false,
		&"preferences.accessibility.colour_differentiation":"tritan",
	}).ok)
	var reopened := _open(f)
	await _settle()
	assert_eq(panel.theme.get_color("instrument","Contacts"),
		CONTACTS_THEME.resolve(&"midnight",5,false,"tritan").instrument)
	assert_eq(panel.selected_friend,"lavinia")
	assert_same(reopened,app,"Desktop retains the cached Contacts app.")


func test_installed_reply_focus_uses_paper_ink_while_header_stays_bone() -> void:
	var f := _fixture(false, 5, false, true)
	var app := _open(f)
	if app == null: return
	_open_lavinia(app)
	await _settle()
	var reply: Button = app._reply_button
	assert_not_null(reply)
	if reply == null: return
	reply.grab_focus()
	assert_true(reply.has_focus())
	var calls_before: Dictionary = f.port.call_counts()
	assert_true(f.profile.set_preferences({
		&"preferences.accessibility.high_contrast":true,
		&"preferences.accessibility.colour_differentiation":"tritan",
	}).ok)
	await _settle()
	var roles: Dictionary = CONTACTS_THEME.resolve(&"after_hours",5,true,"tritan")
	assert_eq(f.port.call_counts(),calls_before)
	assert_same(app._reply_button,reply)
	assert_true(reply.has_focus())
	_assert_paper_button_colours(reply,roles)
	assert_eq(app.contacts_panel._header.get_theme_color("font_color"),roles.bone)


func test_colour_change_preserves_pending_retry_failure_and_exact_command() -> void:
	var f := _fixture(false, 5)
	var app := _open(f)
	if app == null: return
	_open_lavinia(app)
	f.port.fail_save = true
	app._ordinary_choices[1].pressed.emit()
	app.contacts_panel._pending_label.draw.emit()
	await _settle()
	assert_eq(app.last_result.get("code"),&"write_failed")
	assert_false(app._ordinary_retry.disabled)
	var command: Dictionary = app._ordinary_pending.duplicate(true)
	var generation: int = app._ordinary_generation
	var pending_label: Label = app.contacts_panel._pending_label
	var retry: Button = app._ordinary_retry
	var status: Label = app._status_label
	var labels_before: Dictionary = _label_identity_and_copy(app.contacts_panel)
	var calls_before: Dictionary = f.port.call_counts()
	assert_true(f.profile.set_preferences({
		&"preferences.accessibility.high_contrast":true,
		&"preferences.accessibility.colour_differentiation":"deutan",
	}).ok)
	await _settle()
	assert_eq(f.port.call_counts(),calls_before)
	assert_eq(app._ordinary_pending,command)
	assert_eq(f.port.pending,command)
	assert_eq(app._ordinary_generation,generation)
	assert_same(app.contacts_panel._pending_label,pending_label)
	assert_same(app._ordinary_retry,retry)
	assert_false(retry.disabled)
	assert_true(retry.has_focus())
	_assert_paper_button_colours(retry,
		CONTACTS_THEME.resolve(&"after_hours",5,true,"deutan"))
	assert_same(app._status_label,status)
	assert_true(status.visible)
	assert_eq(app.last_result.get("code"),&"write_failed")
	assert_eq(_label_identity_and_copy(app.contacts_panel),labels_before)
	assert_eq(app.contacts_panel.theme.get_color("paper","Contacts"),
		CONTACTS_THEME.resolve(&"after_hours",5,true,"deutan").paper)
	assert_eq(f.port.cancel_calls,0)
	f.port.fail_save = false
	retry.pressed.emit()
	await _settle()
	assert_true(f.port.committed)
	assert_eq(f.port.acknowledge_calls,2)
	assert_true(app._ordinary_pending.is_empty())
	assert_eq(f.port.cancel_calls,0)


func test_colour_change_during_awaited_ack_does_not_recreate_or_cancel_pending_reply() -> void:
	var f := _fixture(false, 5)
	var app := _open(f)
	if app == null: return
	_open_lavinia(app)
	f.port.block_ack = true
	app._ordinary_choices[1].pressed.emit()
	app.contacts_panel._pending_label.draw.emit()
	await _settle()
	assert_true(app._ordinary_busy)
	assert_true(f.port.ack_waiting)
	var command: Dictionary = app._ordinary_pending.duplicate(true)
	var generation: int = app._ordinary_generation
	var pending_label: Label = app.contacts_panel._pending_label
	var calls_before: Dictionary = f.port.call_counts()
	assert_true(f.profile.set_preference(&"preferences.accessibility.high_contrast",true).ok)
	await _settle()
	assert_eq(f.port.call_counts(),calls_before)
	assert_true(app._ordinary_busy)
	assert_eq(app._ordinary_pending,command)
	assert_eq(app._ordinary_generation,generation)
	assert_same(app.contacts_panel._pending_label,pending_label)
	assert_eq(f.port.cancel_calls,0)
	assert_eq(app.contacts_panel.theme.get_color("instrument","Contacts"),
		CONTACTS_THEME.resolve(&"after_hours",5,true,"standard").instrument)
	f.port.release_ack.emit()
	await _settle()
	assert_true(f.port.committed)
	assert_eq(f.port.acknowledge_calls,1)
	assert_false(app._ordinary_busy)
	assert_true(app._ordinary_pending.is_empty())
	assert_eq(f.port.cancel_calls,0)


func test_invalid_palette_or_day_cannot_replace_mounted_contacts_presentation() -> void:
	var f := _fixture(true, 5)
	var app := _open(f)
	if app == null: return
	_open_lavinia(app)
	await _settle()
	app.contacts_panel.transcript.grab_focus()
	app.contacts_panel.transcript.scroll_vertical = 95
	await _settle()
	var panel: Control = app.contacts_panel
	var transcript: ScrollContainer = panel.transcript
	var scroll_before: int = transcript.scroll_vertical
	assert_gt(scroll_before,0)
	var theme: Theme = panel.theme
	var labels: Dictionary = _label_identity_and_copy(panel)
	var calls_before: Dictionary = f.port.call_counts()
	for invalid: Dictionary in [{"palette":&"unknown","day":5},
			{"palette":&"midnight","day":0},{"palette":&"midnight","day":8},
			{"palette":&"after_hours","day":5},{"palette":&"midnight","day":6}]:
		var result: Dictionary = app.configure_presentation(f.port, f.localization, f.profile,
			invalid.palette, invalid.day)
		assert_false(result.get("ok", true))
		assert_same(panel.theme,theme)
		assert_same(panel.transcript,transcript)
		assert_true(transcript.has_focus())
		assert_eq(transcript.scroll_vertical,scroll_before)
		assert_eq(panel.selected_friend,"lavinia")
		assert_eq(_label_identity_and_copy(panel),labels)
		assert_eq(f.port.call_counts(),calls_before)
	for invalid: Dictionary in [{"palette":&"unknown","day":5},
			{"palette":&"midnight","day":0},{"palette":&"midnight","day":8}]:
		assert_false(panel.apply_presentation(invalid.palette,invalid.day,false,"standard"))
		assert_same(panel.theme,theme)
		assert_same(panel.transcript,transcript)
		assert_true(transcript.has_focus())
		assert_eq(transcript.scroll_vertical,scroll_before)
		assert_eq(_label_identity_and_copy(panel),labels)
		assert_eq(f.port.call_counts(),calls_before)


func test_desktop_rejects_invalid_or_foreign_day_before_binding_contacts_owners() -> void:
	var f := _fixture(false, 5)
	var candidate: Control = DESKTOP.instantiate()
	candidate.set_script(IsolatedDesktop)
	assert_true(candidate.configure_run_configuration(f.run).ok)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024,720)
	add_child_autofree(viewport)
	viewport.add_child(candidate)
	var calls_before: Dictionary = f.port.call_counts()
	for day: int in [0,8,4,6]:
		var result: Dictionary = candidate.configure_contacts(f.port,f.localization,f.profile,f.host,day)
		assert_false(result.get("ok",true))
		assert_eq(result.get("code"),&"desktop_owner_day_mismatch")
		assert_null(candidate._presentation_port)
		assert_null(candidate._localization)
		assert_null(candidate._profile)
		assert_null(candidate._host_state)
		assert_eq(candidate._day,1)
		assert_eq(f.port.call_counts(),calls_before)
	assert_true(candidate.configure_contacts(f.port,f.localization,f.profile,f.host,5).ok)
	assert_same(candidate._presentation_port,f.port)
	assert_same(candidate._host_state,f.host)
	assert_eq(candidate._day,5)
