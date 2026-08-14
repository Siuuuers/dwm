extends Control
class_name NarrativeCaptionLayer

const LANGUAGE_SINGLE: StringName = &"single"
const LANGUAGE_DUAL: StringName = &"dual"

@onready var _stack: Container = %CaptionStack
@onready var _cards: Array[Control] = [%CurrentCard, %PreviousCard, %OldestCard]
@onready var _primary_labels: Array[RichTextLabel] = [%CurrentPrimary, %PreviousPrimary, %OldestPrimary]
@onready var _secondary_labels: Array[RichTextLabel] = [%CurrentSecondary, %PreviousSecondary, %OldestSecondary]

var _session_id: StringName = &""
var _language_mode: StringName = LANGUAGE_SINGLE
var _projections: Array[Dictionary] = []

func reset_session(session_id: StringName, language_mode: StringName = LANGUAGE_SINGLE) -> Dictionary:
	if session_id == &"":
		return {"ok": false, "code": &"caption_session_required"}
	if language_mode not in [LANGUAGE_SINGLE, LANGUAGE_DUAL]:
		return {"ok": false, "code": &"caption_language_mode_unknown"}
	_session_id = session_id
	_language_mode = language_mode
	_projections.clear()
	_render()
	return {"ok": true, "code": &"caption_session_reset"}

func publish_beat(projection: Dictionary) -> Dictionary:
	var validated := _validate_projection(projection)
	if not validated.ok:
		return validated
	var owned: Dictionary = projection.duplicate(true)
	if _language_mode == LANGUAGE_DUAL:
		_projections.assign([owned])
	else:
		_projections.push_front(owned)
		if _projections.size() > 3:
			_projections.resize(3)
	_render()
	return {"ok": true, "code": &"caption_published"}

func append_current(fragment_projection: Dictionary) -> Dictionary:
	var validated := _validate_projection(fragment_projection)
	if not validated.ok:
		return validated
	if _projections.is_empty() or StringName(_projections[0].semantic_id) != StringName(fragment_projection.semantic_id):
		return {"ok": false, "code": &"caption_identity_mismatch"}
	var updated: Dictionary = _projections[0].duplicate(true)
	updated.primary_text = str(updated.primary_text) + str(fragment_projection.primary_text)
	updated.secondary_text = str(updated.secondary_text) + str(fragment_projection.secondary_text)
	_projections[0] = updated
	_render()
	return {"ok": true, "code": &"caption_appended"}

func clear_session() -> void:
	_session_id = &""
	_projections.clear()
	if is_node_ready():
		_render()

func get_visual_semantic_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for index in range(_projections.size() - 1, -1, -1):
		result.append(StringName(_projections[index].semantic_id))
	return result

func get_assistive_semantic_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for projection in _projections:
		result.append(StringName(projection.semantic_id))
	return result

func get_projection(semantic_id: StringName) -> Dictionary:
	for projection in _projections:
		if StringName(projection.semantic_id) == semantic_id:
			return projection.duplicate(true)
	return {}

func get_current_text_owner() -> DialogicNode_DialogText:
	return %CurrentPrimary as DialogicNode_DialogText

func _validate_projection(projection: Dictionary) -> Dictionary:
	if _session_id == &"":
		return {"ok": false, "code": &"caption_session_required"}
	for key in ["session_id", "semantic_id", "primary_text", "secondary_text"]:
		if not projection.has(key):
			return {"ok": false, "code": &"caption_projection_incomplete"}
	if StringName(projection.session_id) != _session_id:
		return {"ok": false, "code": &"caption_session_mismatch"}
	if StringName(projection.semantic_id) == &"":
		return {"ok": false, "code": &"caption_identity_required"}
	return {"ok": true, "code": &"caption_projection_valid"}

func _render() -> void:
	for index in _cards.size():
		var shown := index < _projections.size()
		_cards[index].visible = shown
		if not shown:
			_primary_labels[index].text = ""
			_secondary_labels[index].text = ""
			continue
		var projection := _projections[index]
		var primary := str(projection.primary_text)
		# Dialogic starts revealing the current owner before emitting text_started.
		# Avoid reassigning identical text so its reveal state survives publication.
		if _primary_labels[index].text != primary:
			_primary_labels[index].text = primary
		_secondary_labels[index].text = str(projection.secondary_text)
		_secondary_labels[index].visible = _language_mode == LANGUAGE_DUAL and index == 0
	_stack.queue_sort()
