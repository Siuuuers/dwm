class_name Day7FollowupState
extends RefCounted

## Day 6 consequences due on Day 7 share Contacts' existing acknowledged-read law.
## The caller supplies validated Contacts; this query neither reads nor writes live owners.
static func pending_day7_followups(contacts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for friend: String in ["priscilla", "lavinia"]:
		var watermark := int(contacts.get("read_watermarks", {}).get(friend, 0))
		for message: Dictionary in contacts.get("messages", {}).get(friend, []):
			if int(message.get("target_day", 0)) != 7 or str(message.get("visibility", "")) != "visible" \
					or str(message.get("type", "")) not in ["nevermind", "missed_question", "busy", "judge"] \
					or int(message.get("sequence", 0)) <= watermark:
				continue
			rows.append({"friend_id": friend, "message": message.duplicate(true)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.message.sequence) < int(b.message.sequence))
	return rows

## The message ID is shared by solo/group consequences; saved supersession identifies
## which registered Day 6 scene supplied it. An absent or inconsistent source fails closed.
static func entry_id_for(contacts: Dictionary, row: Dictionary) -> String:
	var friend: String = str(row.get("friend_id", ""))
	var message: Variant = row.get("message")
	if friend not in ["priscilla", "lavinia"] or not message is Dictionary \
			or message not in contacts.get("messages", {}).get(friend, []): return ""
	var kind: String = str(message.get("type", ""))
	if int(message.get("target_day", 0)) != 7 or kind not in ["nevermind", "missed_question", "busy", "judge"] \
			or message.get("message_id") != "%s:%s:day7" % [kind, friend]: return ""
	var solo: Dictionary = contacts.get("solo_actions", {}).get("solo:%s:day6" % friend, {})
	var group: Dictionary = contacts.get("group_action", {})
	if str(solo.get("state", "")) == "SUPERSEDED":
		var expected_states := {"nevermind": "RESOLVED_UNANSWERED", "missed_question": "RESOLVED_MISSED",
			"busy": "RESOLVED_UNANSWERED", "judge": "RESOLVED_ATTENDED"}
		if int(group.get("day", 0)) != 6 or str(group.get("state", "")) != expected_states[kind]: return ""
		return "contact.invitation.group.priscilla_lavinia.day6.%s_%s" % [kind, friend]
	if (kind == "nevermind" and str(solo.get("state", "")) == "RESOLVED_UNANSWERED") \
			or (kind == "missed_question" and str(solo.get("state", "")) == "RESOLVED_MISSED"):
		return "contact.invitation.solo.%s.day6.%s" % [friend, kind]
	return ""
