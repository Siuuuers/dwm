extends GutTest
const APP := preload("res://scenes/apps/ContactListApp.tscn")

class Presentation extends RefCounted:
	var pending: Dictionary = {}
	var prepared: Array[String] = []
	var acknowledged: Array[Dictionary] = []
	var cancelled: Array[Dictionary] = []
	var committed := false
	var fail_save := false
	var sequence := 0
	func get_projection(friend_id: String, primary: String = "en", _secondary: String = "") -> Dictionary:
		var entries: Array = []
		var choices: Array = []
		if friend_id == "lavinia":
			entries.append(_entry("ordinary-incoming", false, "A note from Lavinia."))
			if committed:
				entries.append(_entry("ordinary-outgoing", true, "Selected B."))
				entries.append(_entry("ordinary-response", false, "Reply received."))
			else:
				for letter: String in ["a", "b", "c"]:
					choices.append({"reply_id": "reply.lavinia.day1." + letter,
						"line_id": "line.contact.ordinary.lavinia.day1.reply." + letter, "text": "Selected " + letter.to_upper() + "."})
		return {"ok": true, "value": {"friend_id": friend_id, "entries": entries, "unread": {"lavinia": false}, "reply_required": false, "ordinary_choices": choices}}
	func open_friend(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
		return get_projection(friend_id, primary, secondary)
	func reply_to_group(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
		return get_projection(friend_id, primary, secondary)
	func get_pending_ordinary_reply() -> Dictionary:
		return {"ok": true, "value": {} if pending.is_empty() else {"command": pending.duplicate(true), "candidate": {}, "message_batch": []}}
	func prepare_ordinary_reply(friend_id: String, reply_id: String, locale: String = "en") -> Dictionary:
		if not pending.is_empty(): return {"ok": false, "code": &"pending_reply_exists"}
		prepared.append(reply_id)
		sequence += 1
		pending = {"command_id": "choice-%d" % sequence, "command_issuer_receipt": {"fixture": true},
			"live_session": {"generation": 1}, "source_contacts_sha256": "frozen", "source_day": 1,
			"friend_id": friend_id, "reply_id": reply_id, "locale": locale,
			"rendered_line": {"view_token": "choice-%d" % sequence,
				"line_id": "line.contact.ordinary.lavinia.day1.reply." + reply_id.right(1),
				"text": "Selected " + reply_id.right(1).to_upper() + "."}}
		return get_pending_ordinary_reply()
	func acknowledge_ordinary_reply(command: Dictionary, line: Dictionary, primary: String = "en", secondary: String = "") -> Dictionary:
		if command != pending or line != pending.get("rendered_line"): return {"ok": false}
		acknowledged.append({"command": command.duplicate(true), "line": line.duplicate(true)})
		if fail_save: return {"ok": false, "code": &"write_failed"}
		committed = true
		pending = {}
		return get_projection(command.friend_id, primary, secondary)
	func cancel_pending_ordinary_reply(command: Dictionary) -> Dictionary:
		cancelled.append(command.duplicate(true))
		if pending.is_empty(): return {"ok": true}
		if command != pending: return {"ok": false}
		pending = {}
		return {"ok": true}
	func _entry(id: String, outgoing: bool, text: String) -> Dictionary:
		return {"id": id, "outgoing": outgoing, "texts": {"en": text, "zh-CN": text, "zh-HK": text}}

func _fixture() -> Dictionary:
	var port := Presentation.new()
	var app: Control = APP.instantiate()
	assert_true(app.configure_presentation(port).ok)
	add_child_autofree(app)
	app._on_open_requested("lavinia")
	return {"app": app, "port": port}

func test_selected_outgoing_draw_commits_once_and_save_failure_keeps_exact_choice_for_retry() -> void:
	var f := _fixture()
	assert_eq(f.app._ordinary_choices.size(), 3)
	f.port.fail_save = true
	f.app._ordinary_choices[1].pressed.emit()
	assert_eq(f.port.prepared, ["reply.lavinia.day1.b"])
	assert_eq(f.port.acknowledged, [], "selection alone is not a rendered line")
	assert_eq(f.app.contacts_panel._pending_label.text, "Selected B.")
	assert_eq(f.app._ordinary_choices, [])
	f.app._on_ordinary_choice("reply.lavinia.day1.c")
	assert_eq(f.port.prepared.size(), 1)
	f.app.contacts_panel._pending_label.draw.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(f.port.acknowledged.size(), 1)
	assert_false(f.app._ordinary_retry.disabled)
	var exact: Dictionary = f.port.pending.duplicate(true)
	assert_eq(f.port.acknowledged[0], {"command": exact, "line": exact.rendered_line})
	f.port.fail_save = false
	f.app._ordinary_retry.pressed.emit()
	await get_tree().process_frame
	assert_true(f.port.committed)
	assert_eq(f.port.acknowledged.size(), 2)
	assert_eq(f.port.acknowledged[1], f.port.acknowledged[0])
	assert_eq(f.app.contacts_panel._entries.size(), 3)
	assert_true(f.app.contacts_panel._entries[1].outgoing)
	assert_true(f.app._ordinary_pending.is_empty())
	f.app.refresh_view()
	assert_eq(f.port.acknowledged.size(), 2, "history refresh never acknowledges again")

func test_changing_thread_or_hiding_cancels_only_the_unsaved_choice_and_stale_draw_does_not_send() -> void:
	var f := _fixture()
	f.app._ordinary_choices[0].pressed.emit()
	var first: Dictionary = f.port.pending.duplicate(true)
	f.app._on_pending_ordinary_drawn(first.rendered_line)
	f.app._on_open_requested("sylvia")
	assert_eq(f.port.cancelled, [first])
	assert_true(f.port.pending.is_empty())
	assert_eq(f.app.contacts_panel.selected_friend, "sylvia")
	await get_tree().process_frame
	assert_eq(f.port.acknowledged, [])
	f.app._on_open_requested("lavinia")
	f.app._ordinary_choices[2].pressed.emit()
	var second: Dictionary = f.port.pending.duplicate(true)
	assert_ne(second.command_id, first.command_id)
	f.app.hide_window()
	assert_eq(f.port.cancelled, [first, second])
	assert_true(f.port.pending.is_empty())
	assert_false(f.app.visible)
	f.app.show_window()
	assert_eq(f.app._ordinary_choices.size(), 3)
	assert_false(f.port.committed)

func test_locale_refresh_keeps_the_frozen_line_and_does_not_treat_choice_buttons_as_history() -> void:
	var f := _fixture()
	f.app._ordinary_choices[1].pressed.emit()
	var line: Dictionary = f.port.pending.rendered_line.duplicate(true)
	f.app._primary = "zh-CN"
	f.app.refresh_view()
	assert_eq(f.app.contacts_panel._pending_label.text, line.text)
	assert_eq(f.app.contacts_panel._pending_label.language, "en", "the pending command retains its actual registered original locale")
	assert_eq(f.port.acknowledged, [])
	assert_eq(f.app.contacts_panel._entries.size(), 1, "uncommitted choices are not stored correspondence")
	f.app.contacts_panel._pending_label.draw.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(f.port.acknowledged.size(), 1)
	assert_eq(f.port.acknowledged[0].line, line)

func test_outgoing_text_is_not_covered_by_a_container_stretched_decoration() -> void:
	var f := _fixture()
	f.port.committed = true
	f.app.refresh_view()
	for frame: int in 5: await get_tree().process_frame
	var checked := 0
	for label: Label in f.app.contacts_panel.messages.find_children("*", "Label", true, false):
		if not label.get_meta("outgoing", false): continue
		checked += 1
		assert_false(label.text.is_empty())
		var surface: PanelContainer = label.get_parent().get_parent()
		var style: StyleBoxFlat = surface.get_theme_stylebox("panel")
		assert_ne(label.get_theme_color("font_color"), style.bg_color, "outgoing text contrasts with its own bubble")
		# Godot containers also lay out internal children; inspect their actual settled geometry.
		for child: Node in surface.get_children(true):
			if child is ColorRect and child.color.a > 0.0:
				assert_false(child.get_global_rect().intersects(label.get_global_rect()), "decorative fill cannot cover outgoing glyphs")
	assert_eq(checked, 1, "the committed outgoing reply was checked")
