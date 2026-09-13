extends Node
## One transient UI command at a time; pending work is derived from saved Contacts.
signal finished
const SURFACE := preload("res://scripts/ui/Day7PreludeSurface.gd")
const FOLLOWUPS := preload("res://scripts/domain/contact/Day7FollowupState.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
var _game: Object
var _contacts: Object
var _issuer: Object
var _locale := "en"
var _theme: Theme
var _session: Dictionary = {}
var _command: Dictionary = {}
var _receipt: Dictionary = {}
var _surface: CanvasLayer
var _finishing := false
var last_result: Dictionary = {}

func configure(game: Object, contacts: Object, issuer: Object, locale: String = "en", presentation_theme: Theme = null) -> Dictionary:
	if _game != null or game == null or contacts == null or issuer == null:
		return {"ok": false, "code": &"invalid_day7_prelude_configuration"}
	_game = game
	_contacts = contacts
	_issuer = issuer
	_locale = locale.replace("_", "-")
	_theme = presentation_theme
	_session = game.capture_live_session().value.duplicate(true)
	return {"ok": true}

func begin() -> Dictionary:
	last_result = _advance()
	if not last_result.get("ok", false) and not _finishing:
		if is_instance_valid(_surface):
			_surface.show_advance_retry(begin)
		else:
			var surface := SURFACE.new()
			var configured: Dictionary = surface.configure_waiting(begin, _acknowledge, _locale, _theme)
			if not configured.get("ok", false):
				surface.free()
				return configured
			surface.use_presentation_receipts()
			if not surface.bind_input_custody(get_node_or_null("/root/InputManager")):
				surface.free()
				return {"ok": false, "code": &"day7_input_unavailable"}
			_surface = surface
			_surface.advance_requested.connect(_on_advance_requested)
			add_child(_surface)
	return last_result

func _process(_delta: float) -> void:
	if _game != null and not _finishing and _game.capture_live_session().value != _session:
		_retire()

func _advance() -> Dictionary:
	var admitted: Dictionary = _game.validate_live_session(_session)
	if not admitted.get("ok", false): return admitted
	if _game.day != 7 or _game._run_lifecycle.get_state() != &"PLAYING":
		_retire()
		return {"ok": true}
	var projected: Dictionary = _contacts.get_day7_followup_cards(_locale)
	if not projected.get("ok", false): return projected
	var followups: Array = projected.value.cards
	var echoes: Array = _game.get_pending_ordinary_echoes()
	if followups.is_empty() and echoes.is_empty():
		_retire()
		return {"ok": true, "value": {"complete": true}}
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	if not issued.get("ok", false): return issued
	var hashed: Dictionary = JSON_WRITER.stringify(_game.contacts)
	if not hashed.get("ok", false): return hashed
	var command := {"command_id": str(issued.value.token),
		"command_issuer_receipt": issued.value.issuer_receipt.duplicate(true),
		"live_session": _session.duplicate(true), "source_contacts_sha256": str(hashed.value).sha256_text()}
	var receipt: Dictionary
	var title: String
	var body := ""
	if not followups.is_empty():
		var card: Dictionary = followups[0]
		var original: Dictionary = _game.get_pending_day7_followups()[0]
		var entry_id: String = FOLLOWUPS.entry_id_for(_game.contacts, original)
		if entry_id.is_empty(): return {"ok": false, "code": &"day7_followup_entry_unavailable"}
		command.merge({"friend_id": card.friend_id, "message_id": card.message_id, "sequence": card.sequence})
		receipt = {"entry_id": entry_id, "kind": "day7_followup", "view_token": command.command_id,
			"friend_id": card.friend_id, "message_id": card.message_id, "sequence": card.sequence}
		title = str(card.friend_id).capitalize()
		var lines: Array[String] = []
		for entry: Dictionary in card.entries:
			lines.append(("Angela: " if entry.outgoing else title + ": ") + str(entry.texts[_locale]))
		body = "\n\n".join(lines)
	else:
		var echo: Dictionary = echoes[0]
		command.merge({"echo_id": echo.echo_id, "presentation_atom_id": echo.presentation_atom_id})
		receipt = {"entry_id": "echo.fallback.day7", "view_token": command.command_id,
			"echo_id": echo.echo_id, "presentation_atom_id": echo.presentation_atom_id}
		title = "A remembered reply" if _locale == "en" else "\u8bb0\u5f97\u7684\u56de\u590d"
		if _locale == "zh-HK": title = "\u8a18\u5f97\u7684\u56de\u8986"
		title += " / " + str(echo.friend_id).capitalize()
		body = ("Earlier, you said:\n" if _locale == "en" else "\u4f60\u66fe\u8bf4\uff1a\n") + str(echo.plain_text_snapshot)
		if _locale == "zh-HK": body = "\u4f60\u66fe\u8aaa\uff1a\n" + str(echo.plain_text_snapshot)
	var card := {"receipt": receipt.duplicate(true), "title": title, "body": body}
	if is_instance_valid(_surface):
		var presented: Dictionary = _surface.present_card(card)
		if not presented.get("ok", false): return presented
	else:
		var surface := SURFACE.new()
		var configured: Dictionary = surface.configure(card, _acknowledge, _locale, _theme)
		if not configured.get("ok", false):
			surface.free()
			return configured
		surface.use_presentation_receipts()
		if not surface.bind_input_custody(get_node_or_null("/root/InputManager")):
			surface.free()
			return {"ok": false, "code": &"day7_input_unavailable"}
		_surface = surface
		_surface.advance_requested.connect(_on_advance_requested)
		add_child(_surface)
	_command = command.duplicate(true)
	_receipt = receipt.duplicate(true)
	return {"ok": true}

func _acknowledge(receipt: Dictionary) -> Dictionary:
	if _finishing or receipt != _receipt or _command.is_empty():
		return {"ok": false, "code": &"day7_prelude_identity_mismatch"}
	last_result = _game.commit_day7_followup(_command, receipt) if receipt.get("kind") == "day7_followup" \
		else _game.commit_ordinary_echo(_command, receipt)
	return last_result

func _on_advance_requested(receipt: Dictionary) -> void:
	if not is_instance_valid(_surface) or receipt != _receipt \
			or not _surface.is_card_acknowledged(receipt): return
	_advance_after_request.call_deferred(str(receipt.view_token))

func _advance_after_request(token: String) -> void:
	if _finishing or token != str(_receipt.get("view_token", "")): return
	begin()

func _retire() -> void:
	if _finishing: return
	_finishing = true
	if is_instance_valid(_surface): _surface.hide()
	finished.emit()
	queue_free()
