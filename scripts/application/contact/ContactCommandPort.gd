class_name ContactCommandPort
extends RefCounted

## Semantic Contacts application boundary. Scenes provide only a friend id; this port owns the
## one durable transaction root and immediately hands its complete proof to the authenticated
## GameState seam. It owns no Contacts state and never derives an identity locally.

var _game_state: Object = null
var _identity_issuer: Object = null


func configure(game_state: Object, identity_issuer: Object) -> Dictionary:
	if game_state == null or identity_issuer == null:
		return _fail(&"invalid_contact_command_port_configuration", "both dependencies are required")
	for method: String in ["configure_identity_issuer", "open_contact", "reply_invitation"]:
		if not game_state.has_method(method):
			return _fail(&"invalid_contact_game_state", "missing " + method)
	for method: String in ["issue", "verify_issued"]:
		if not identity_issuer.has_method(method):
			return _fail(&"invalid_contact_identity_issuer", "missing " + method)
	if _game_state != null or _identity_issuer != null:
		if _game_state != game_state or _identity_issuer != identity_issuer:
			return _fail(&"contact_command_port_already_configured", "replacement refused")
		return {"ok": true, "code": &"ok", "value": {
			"game_state_instance_id": _game_state.get_instance_id(),
			"issuer_instance_id": _identity_issuer.get_instance_id(),
			"already_configured": true,
		}, "receipt": {}}
	var configured: Variant = game_state.call(&"configure_identity_issuer", identity_issuer)
	if typeof(configured) != TYPE_DICTIONARY or not (configured as Dictionary).get("ok", false):
		return _fail(&"contact_identity_injection_failed", "GameState rejected the issuer")
	if int((configured as Dictionary).get("value", {}).get("issuer_instance_id", 0)) \
			!= identity_issuer.get_instance_id():
		return _fail(&"contact_identity_mismatch", "GameState retained another issuer")
	_game_state = game_state
	_identity_issuer = identity_issuer
	return {"ok": true, "code": &"ok", "value": {
		"game_state_instance_id": _game_state.get_instance_id(),
		"issuer_instance_id": _identity_issuer.get_instance_id(),
		"already_configured": false,
	}, "receipt": {}}


func request_open_contact(friend_id: String, before_commit: Callable = Callable()) -> Dictionary:
	return _issue_and_delegate(&"open_contact", friend_id, before_commit)


func request_reply_invitation(friend_id: String) -> Dictionary:
	return _issue_and_delegate(&"reply_invitation", friend_id)


func _issue_and_delegate(method: StringName, friend_id: String, before_commit: Callable = Callable()) -> Dictionary:
	if _game_state == null or _identity_issuer == null:
		return _fail(&"contact_command_port_unconfigured", "configure must succeed first")
	if friend_id.strip_edges().is_empty():
		return _fail(&"invalid_contact_friend", "friend_id must be nonblank")
	if before_commit.is_valid() and not _game_state.has_method("preview_open_contact"):
		return _fail(&"contact_preview_unavailable", "content preflight requires owner preview")
	var issued: Variant = _identity_issuer.call(&"issue", &"transaction_id")
	if typeof(issued) != TYPE_DICTIONARY or not (issued as Dictionary).get("ok", false):
		return _fail(&"contact_command_issue_failed", "durable transaction issuance failed",
			{"cause": (issued as Dictionary).get("code", &"") if typeof(issued) == TYPE_DICTIONARY else &"invalid_result"})
	var value: Variant = (issued as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("issuer_receipt")) != TYPE_DICTIONARY:
		return _fail(&"contact_command_issue_malformed", "issuer returned no full proof")
	var command_id := str((value as Dictionary).get("token", ""))
	var receipt: Dictionary = (value as Dictionary)["issuer_receipt"]
	if command_id.strip_edges().is_empty() or receipt.get("token") != command_id \
			or (issued as Dictionary).get("receipt") != receipt:
		return _fail(&"contact_command_issue_malformed", "issuer result disagrees with its receipt")
	var verified: Variant = _identity_issuer.call(&"verify_issued", receipt, &"transaction_id")
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _fail(&"contact_command_issue_unverified", "issued proof did not verify")
	if before_commit.is_valid():
		var prior_contacts: Dictionary = (_game_state.get("contacts") as Dictionary).duplicate(true)
		var prior_day: int = int(_game_state.get("day"))
		var preview: Variant = _game_state.call(&"preview_open_contact", friend_id,
			command_id, receipt.duplicate(true))
		if typeof(preview) != TYPE_DICTIONARY:
			return _fail(&"contact_preview_malformed", "owner returned no preview result")
		if not (preview as Dictionary).get("ok", false):
			return (preview as Dictionary).duplicate(true)
		var admitted: Variant = before_commit.call((preview as Dictionary).duplicate(true))
		if typeof(admitted) != TYPE_DICTIONARY:
			return _fail(&"contact_content_guard_malformed", "content guard returned no result")
		if not (admitted as Dictionary).get("ok", false):
			return (admitted as Dictionary).duplicate(true)
		if prior_day != int(_game_state.get("day")) or prior_contacts != _game_state.get("contacts"):
			return _fail(&"contact_preview_stale", "owner changed during content preflight")
	var delegated: Variant = _game_state.call(method, friend_id, command_id, receipt.duplicate(true))
	if typeof(delegated) != TYPE_DICTIONARY:
		return _fail(&"contact_command_result_malformed", "GameState returned no CommandResult")
	return (delegated as Dictionary).duplicate(true)


static func _fail(code: StringName, message: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details.duplicate(true)}


# Only one selected reply may wait for its actual transcript draw/save acknowledgment.
# This cache is local presentation custody, not another saved Contacts owner.
var _ordinary_pending: Dictionary = {}
var _ordinary_completed: Dictionary = {}

func prepare_ordinary_reply(friend_id: String, reply_id: String, locale: String = "en") -> Dictionary:
	if _game_state == null or not _game_state.has_method("preview_ordinary_reply") \
			or not _game_state.has_method("commit_ordinary_reply"):
		return _fail(&"ordinary_reply_unconfigured", "")
	_discard_stale_ordinary_pending()
	if not _ordinary_pending.is_empty():
		var command: Dictionary = _ordinary_pending.command
		if command.friend_id == friend_id and command.reply_id == reply_id and command.locale == locale:
			return {"ok": true, "value": _ordinary_pending.duplicate(true)}
		return _fail(&"ordinary_reply_still_pending", "")
	var issued: Dictionary = _identity_issuer.issue(&"transaction_id")
	if not issued.get("ok", false): return issued
	var value: Variant = issued.get("value")
	if not value is Dictionary or not value.get("issuer_receipt") is Dictionary \
			or not value.get("token") is String or issued.get("receipt") != value.issuer_receipt:
		return _fail(&"ordinary_command_issue_malformed", "")
	var verified: Dictionary = _identity_issuer.verify_issued(value.issuer_receipt, &"transaction_id")
	if not verified.get("ok", false): return verified
	var preview: Dictionary = _game_state.preview_ordinary_reply(friend_id, reply_id, locale,
		value.token, value.issuer_receipt.duplicate(true))
	if not preview.get("ok", false): return preview
	var material: Variant = preview.get("value")
	if not material is Dictionary or not material.get("command") is Dictionary \
			or material.command.get("command_id") != value.token \
			or material.command.get("command_issuer_receipt") != value.issuer_receipt \
			or material.command.get("friend_id") != friend_id or material.command.get("reply_id") != reply_id \
			or material.command.get("locale") != locale or not material.command.get("rendered_line") is Dictionary:
		return _fail(&"ordinary_preview_malformed", "")
	_ordinary_pending = material.duplicate(true)
	_ordinary_completed = {}
	return preview.duplicate(true)

func acknowledge_ordinary_reply(command: Dictionary, rendered_line: Dictionary) -> Dictionary:
	if _game_state == null: return _fail(&"ordinary_reply_unconfigured", "")
	_discard_stale_ordinary_pending()
	if not _ordinary_completed.is_empty() and _ordinary_completed.command == command \
			and rendered_line == command.get("rendered_line"):
		var admitted: Dictionary = _game_state.validate_live_session(command.live_session)
		return _ordinary_completed.result.duplicate(true) if admitted.get("ok", false) else admitted
	if _ordinary_pending.is_empty() or command != _ordinary_pending.command \
			or rendered_line != command.get("rendered_line"):
		return _fail(&"ordinary_render_identity_mismatch", "")
	var committed: Dictionary = _game_state.commit_ordinary_reply(command.duplicate(true), rendered_line.duplicate(true))
	if committed.get("ok", false):
		_ordinary_completed = {"command": command.duplicate(true), "result": committed.duplicate(true)}
		_ordinary_pending = {}
	return committed

func get_pending_ordinary_reply() -> Dictionary:
	_discard_stale_ordinary_pending()
	return {"ok": true, "value": _ordinary_pending.duplicate(true)}

## Leaving a thread abandons only its exact unsaved preview. An old view cannot cancel a replacement.
func cancel_pending_ordinary_reply(command: Dictionary) -> Dictionary:
	if command.is_empty() or not command.get("command_id") is String:
		return _fail(&"ordinary_render_identity_mismatch", "")
	if _ordinary_pending.is_empty():
		return {"ok": true, "value": {"cancelled": false}}
	if command != _ordinary_pending.command:
		return _fail(&"ordinary_render_identity_mismatch", "")
	_ordinary_pending = {}
	return {"ok": true, "value": {"cancelled": true}}

func _discard_stale_ordinary_pending() -> void:
	if _ordinary_pending.is_empty() or _game_state == null: return
	var command: Dictionary = _ordinary_pending.command
	var admitted: Dictionary = _game_state.validate_live_session(command.live_session)
	if not admitted.get("ok", false) or int(_game_state.day) != int(command.source_day):
		_ordinary_pending = {}
		_ordinary_completed = {}
