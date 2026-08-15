extends AppWindowBase
class_name ContactListApp

## Contact list + chat panel app window (prompt_docs/requirements/contacts_invitations.md).

@onready var contact_list: VBoxContainer = %ContactList
@onready var chat_title_label: Label = %ChatTitleLabel
@onready var chat_scroll: ScrollContainer = %ChatScroll
@onready var chat_message_list: VBoxContainer = %ChatMessageList
@onready var choice_list: VBoxContainer = %ChoiceList
@onready var invitation_response_row: HBoxContainer = %InvitationResponseRow

var _command_port: Object = null


func configure_command_port(command_port: Object) -> Dictionary:
	if command_port == null or not command_port.has_method("request_open_contact") \
			or not command_port.has_method("request_reply_invitation"):
		return _failure(&"invalid_contact_command_port", "command port contract incomplete")
	if _command_port != null:
		if _command_port != command_port:
			return _failure(&"contact_command_port_already_configured", "replacement refused")
		return {"ok": true, "code": &"ok", "value": {
			"port_instance_id": _command_port.get_instance_id(), "already_configured": true,
		}, "receipt": {}}
	_command_port = command_port
	return {"ok": true, "code": &"ok", "value": {
		"port_instance_id": _command_port.get_instance_id(), "already_configured": false,
	}, "receipt": {}}


func open_friend(friend_id: String) -> Dictionary:
	if _command_port == null:
		return _failure(&"contact_command_port_unconfigured", "command port injection is required")
	var result: Variant = _command_port.call(&"request_open_contact", friend_id)
	return _as_command_result(result)


func reply_to_group(friend_id: String) -> Dictionary:
	if _command_port == null:
		return _failure(&"contact_command_port_unconfigured", "command port injection is required")
	var result: Variant = _command_port.call(&"request_reply_invitation", friend_id)
	return _as_command_result(result)


func _as_command_result(result: Variant) -> Dictionary:
	if typeof(result) != TYPE_DICTIONARY:
		return _failure(&"contact_command_result_malformed", "command port returned no result")
	return (result as Dictionary).duplicate(true)


func _failure(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
