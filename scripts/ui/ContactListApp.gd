extends AppWindowBase
class_name ContactListApp

## Contact list + chat panel app window (prompt_docs/requirements/contacts_invitations.md).

@onready var contact_list: VBoxContainer = %ContactList
@onready var chat_title_label: Label = %ChatTitleLabel
@onready var chat_scroll: ScrollContainer = %ChatScroll
@onready var chat_message_list: VBoxContainer = %ChatMessageList
@onready var choice_list: VBoxContainer = %ChoiceList
@onready var invitation_response_row: HBoxContainer = %InvitationResponseRow

func open_friend(friend_id: String) -> void:
	if has_node("/root/GameState"):
		var game_state: Node = get_node("/root/GameState")
		# Stable per-friend/day command id: re-opening the same contact today replays idempotently.
		game_state.open_contact(friend_id, "open:%s:day%d" % [friend_id, int(game_state.day)])
