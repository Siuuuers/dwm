class_name InvitationData
extends Resource
# Stub skeleton. Authoritative fields in CONTENT.md §10.
@export var id: String = ""
@export var friend_id: String = ""
@export var day: int = 0
@export var invitation_type: String = "solo"
@export var participants: Array[String] = []
@export var inviter_id: String = ""
@export var invitation_text: String = ""
@export var invitation_text_key: String = ""
@export var nevermind_text: String = ""
@export var nevermind_text_key: String = ""
@export var missed_date_question_text: String = ""
@export var missed_date_question_text_key: String = ""
