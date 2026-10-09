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
	var required := ["configure_identity_issuer", "open_contact", "reply_invitation"]
	if _scene_owner(game_state): required = ["configure_identity_issuer", "open_contact", "preview_open_contact", "capture_scene_contact_context"]
	for method: String in required:
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
	if _scene_owner(_game_state): return _scene_issue_and_delegate(method, friend_id, before_commit)
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
	if _scene_owner(_game_state): return _prepare_scene_reply(friend_id, reply_id, locale)
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
	if _scene_owner(_game_state): return _acknowledge_scene_reply(command, rendered_line)
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
	if _scene_owner(_game_state) and _scene_busy: return _fail(&"scene_contact_reentrant", "")
	_discard_stale_ordinary_pending()
	return {"ok": true, "value": _ordinary_pending.duplicate(true)}

## Leaving a thread abandons only its exact unsaved preview. An old view cannot cancel a replacement.
func cancel_pending_ordinary_reply(command: Dictionary) -> Dictionary:
	if _scene_owner(_game_state) and _scene_busy: return _fail(&"scene_contact_reentrant", "")
	if command.is_empty() or not command.get("command_id") is String:
		return _fail(&"ordinary_render_identity_mismatch", "")
	if _ordinary_pending.is_empty():
		return {"ok": true, "value": {"cancelled": false}}
	if command != _ordinary_pending.command:
		return _fail(&"ordinary_render_identity_mismatch", "")
	_ordinary_pending = {}
	return {"ok": true, "value": {"cancelled": true}}

func _discard_stale_ordinary_pending() -> void:
	if _scene_owner(_game_state):
		if not _ordinary_pending.is_empty() and not _scene_command_live(_ordinary_pending.command):
			_ordinary_pending = {}
			_ordinary_completed = {}
		return
	if _ordinary_pending.is_empty() or _game_state == null: return
	var command: Dictionary = _ordinary_pending.command
	var admitted: Dictionary = _game_state.validate_live_session(command.live_session)
	if not admitted.get("ok", false) or int(_game_state.day) != int(command.source_day):
		_ordinary_pending = {}
		_ordinary_completed = {}

const _SCENE_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
var _scene_busy := false

static func _scene_owner(owner: Object) -> bool:
	if owner == null: return false
	var state: Variant = owner.get("contacts")
	return state is Dictionary and typeof(state.get("schema_version")) == TYPE_INT and state.schema_version == 2

func _scene_context() -> Dictionary:
	if _game_state == null or not _game_state.has_method("capture_scene_contact_context"):
		return _fail(&"scene_contact_context_unavailable", "")
	var captured: Variant = _game_state.call(&"capture_scene_contact_context")
	if not captured is Dictionary or not captured.get("ok", false) or not captured.get("value") is Dictionary:
		return _fail(&"scene_contact_context_unavailable", "")
	var context: Dictionary = captured.value
	if not _SCENE_STATE._has_exact_keys(context, _SCENE_STATE._SCENE_CONTEXT_KEYS) \
			or not _SCENE_STATE._s_json(context) or context.contacts_sha256 != _SCENE_STATE._s_hash(_game_state.get("contacts")):
		return _fail(&"scene_contact_context_invalid", "")
	return {"ok": true, "value": context.duplicate(true)}

func _scene_issue() -> Dictionary:
	if _identity_issuer == null: return _fail(&"contact_command_port_unconfigured", "")
	var issued: Variant = _identity_issuer.call(&"issue", &"transaction_id")
	if not issued is Dictionary or not issued.get("ok", false) or not issued.get("value") is Dictionary:
		return _fail(&"contact_command_issue_failed", "")
	var value: Dictionary = issued.value
	if not value.get("issuer_receipt") is Dictionary or typeof(value.get("token")) != TYPE_STRING \
			or value.issuer_receipt.get("token") != value.token or not _SCENE_STATE._s_equal(issued.get("receipt"), value.issuer_receipt):
		return _fail(&"contact_command_issue_malformed", "")
	var verified: Variant = _identity_issuer.call(&"verify_issued", value.issuer_receipt.duplicate(true), &"transaction_id")
	if not verified is Dictionary or not verified.get("ok", false): return _fail(&"contact_command_issue_unverified", "")
	return {"ok": true, "value": value.duplicate(true)}

func _scene_issue_and_delegate(method: StringName, friend_id: String, guard: Callable) -> Dictionary:
	if _scene_busy: return _fail(&"scene_contact_reentrant", "")
	_scene_busy = true
	var result := _scene_open_owned(method, friend_id, guard)
	_scene_busy = false
	return result

func _scene_open_owned(method: StringName, friend_id: String, guard: Callable) -> Dictionary:
	if method != &"open_contact" or friend_id not in _SCENE_STATE.FRIEND_IDS: return _fail(&"scene_contact_command_unavailable", "")
	var prior := _scene_context()
	if not prior.ok: return prior
	var issued := _scene_issue()
	if not issued.ok: return issued
	var value: Dictionary = issued.value
	var preview: Variant = _game_state.call(&"preview_open_contact", friend_id, value.token, value.issuer_receipt.duplicate(true))
	if not preview is Dictionary or not preview.get("ok", false):
		return preview.duplicate(true) if preview is Dictionary else _fail(&"contact_preview_malformed", "")
	if guard.is_valid():
		var admitted: Variant = guard.call(preview.duplicate(true))
		if not admitted is Dictionary or not admitted.get("ok", false):
			return admitted.duplicate(true) if admitted is Dictionary else _fail(&"contact_content_guard_malformed", "")
	var current := _scene_context()
	if not current.ok or not _SCENE_STATE._s_equal(current.value, prior.value): return _fail(&"contact_preview_stale", "")
	var result: Variant = _game_state.call(&"open_contact", friend_id, value.token, value.issuer_receipt.duplicate(true))
	return result.duplicate(true) if result is Dictionary else _fail(&"contact_command_result_malformed", "")

func _prepare_scene_reply(friend_id: String, reply_id: String, locale: String) -> Dictionary:
	if _scene_busy: return _fail(&"scene_contact_reentrant", "")
	_scene_busy = true
	var result := _prepare_scene_reply_owned(friend_id, reply_id, locale)
	_scene_busy = false
	return result

func _prepare_scene_reply_owned(friend_id: String, reply_id: String, locale: String) -> Dictionary:
	for method: String in ["preview_scene_contact_reply", "commit_scene_contact_reply", "validate_live_session"]:
		if not _game_state.has_method(method): return _fail(&"scene_contact_reply_unconfigured", "")
	_discard_stale_ordinary_pending()
	if not _ordinary_pending.is_empty():
		var held: Dictionary = _ordinary_pending.command
		return {"ok": true, "value": _ordinary_pending.duplicate(true)} if held.friend_id == friend_id \
			and held.reply_id == reply_id and held.locale == locale else _fail(&"ordinary_reply_still_pending", "")
	var prior := _scene_context()
	if not prior.ok: return prior
	var issued := _scene_issue()
	if not issued.ok: return issued
	var value: Dictionary = issued.value
	var preview: Variant = _game_state.call(&"preview_scene_contact_reply", friend_id, reply_id, locale,
		value.token, value.issuer_receipt.duplicate(true))
	if not preview is Dictionary or not preview.get("ok", false):
		return preview.duplicate(true) if preview is Dictionary else _fail(&"ordinary_preview_malformed", "")
	var material: Variant = preview.get("value")
	if not _SCENE_STATE._has_exact_keys(material, ["command"]) or not material.get("command") is Dictionary: return _fail(&"ordinary_preview_malformed", "")
	var command: Dictionary = material.command
	if not _SCENE_STATE._has_exact_keys(command, ["command_id", "command_issuer_receipt", "friend_id", "reply_id",
			"incoming_message_id", "locale", "context", "rendered_line", "live_session"]) \
			or command.command_id != value.token or not _SCENE_STATE._s_equal(command.command_issuer_receipt, value.issuer_receipt) \
			or command.friend_id != friend_id or command.reply_id != reply_id or command.locale != locale \
			or not command.rendered_line is Dictionary or not _scene_command_equal(command, command) \
			or not _SCENE_STATE._s_equal(command.context, prior.value) \
			or not _scene_command_live(command): return _fail(&"ordinary_preview_malformed", "")
	# Verify installed definition/line without committing any Contacts fact.
	var choices := _SCENE_STATE.scene_reply_choices(_game_state.get("contacts"), friend_id, locale, command.context.registration_sha256)
	if not choices.get("ok", false): return choices
	var found := false
	for choice: Dictionary in choices.value:
		if choice.reply_id == reply_id and choice.incoming_message_id == command.incoming_message_id \
				and _SCENE_STATE._s_equal(command.rendered_line, {"view_token": value.token, "line_id": choice.line_id, "text": choice.text}): found = true
	if not found: return _fail(&"scene_contact_reply_unavailable", "")
	_ordinary_pending = material.duplicate(true)
	_ordinary_completed = {}
	return preview.duplicate(true)

func _acknowledge_scene_reply(command: Dictionary, rendered_line: Dictionary) -> Dictionary:
	if _scene_busy: return _fail(&"scene_contact_reentrant", "")
	var retained_command: Dictionary = command.duplicate(true)
	var retained_line: Dictionary = rendered_line.duplicate(true)
	_scene_busy = true
	var result := _acknowledge_scene_reply_owned(retained_command, retained_line)
	_scene_busy = false
	return result

func _acknowledge_scene_reply_owned(command: Dictionary, rendered_line: Dictionary) -> Dictionary:
	if not _ordinary_completed.is_empty() and _scene_command_equal(_ordinary_completed.command, command) \
			and _SCENE_STATE._s_equal(rendered_line, command.get("rendered_line")):
		var live: Variant = _game_state.call(&"validate_live_session", command.live_session)
		return _ordinary_completed.result.duplicate(true) if live is Dictionary and live.get("ok", false) else _fail(&"scene_contact_session_stale", "")
	_discard_stale_ordinary_pending()
	if _ordinary_pending.is_empty() or not _scene_command_equal(command, _ordinary_pending.command) \
			or not _SCENE_STATE._s_equal(rendered_line, command.get("rendered_line")) or not _scene_command_live(command):
		return _fail(&"ordinary_render_identity_mismatch", "")
	if _ordinary_pending.is_empty() or not _scene_command_equal(command, _ordinary_pending.command):
		return _fail(&"ordinary_render_identity_mismatch", "")
	var result: Variant = _game_state.call(&"commit_scene_contact_reply", command.duplicate(true), rendered_line.duplicate(true))
	if not result is Dictionary: return _fail(&"contact_command_result_malformed", "")
	if result.get("ok", false):
		_ordinary_completed = {"command": command.duplicate(true), "result": result.duplicate(true)}
		_ordinary_pending = {}
	return result.duplicate(true)

func _scene_command_live(command: Dictionary) -> bool:
	if not command.get("context") is Dictionary or not command.has("live_session") \
			or not _game_state.has_method("validate_live_session"): return false
	var live: Variant = _game_state.call(&"validate_live_session", command.live_session)
	if not live is Dictionary or not live.get("ok", false): return false
	var context := _scene_context()
	return context.get("ok", false) and _SCENE_STATE._s_equal(context.value, command.context)

static func _scene_command_equal(a: Dictionary, b: Dictionary) -> bool:
	if not a.has("live_session") or not b.has("live_session") or a.live_session != b.live_session: return false
	var left: Dictionary = a.duplicate(true)
	var right: Dictionary = b.duplicate(true)
	left.erase("live_session")
	right.erase("live_session")
	return _SCENE_STATE._s_equal(left, right)
