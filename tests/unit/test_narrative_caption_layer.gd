extends "res://addons/gut/test.gd"

const SCENE_PATH := "res://scenes/shared/narrative/NarrativeCaptionLayer.tscn"
const DIALOG_TEXT_SCRIPT_PATH := "res://addons/dialogic/Modules/Text/node_dialog_text.gd"

func _make_layer() -> Control:
	var packed := load(SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return null
	var host := Control.new()
	host.size = Vector2(1280.0, 720.0)
	add_child_autofree(host)
	var layer := packed.instantiate() as Control
	host.add_child(layer)
	await get_tree().process_frame
	return layer

func _projection(id: StringName, primary: String, secondary := "") -> Dictionary:
	return _projection_for_session(&"fixture.session", id, primary, secondary)

func _projection_for_session(session_id: StringName, id: StringName, primary: String, secondary := "") -> Dictionary:
	return {
		"session_id": session_id,
		"semantic_id": id,
		"primary_text": primary,
		"secondary_text": secondary,
	}

func _descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result

func test_fresh_scene_matches_transparent_geometry_and_starts_with_every_card_hidden() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	assert_eq(layer.get_rect(), Rect2(0.0, 0.0, 1280.0, 720.0))
	assert_eq(layer.anchor_right, 1.0)
	assert_eq(layer.anchor_bottom, 1.0)
	assert_eq(layer.grow_horizontal, Control.GROW_DIRECTION_BOTH)
	assert_eq(layer.grow_vertical, Control.GROW_DIRECTION_BOTH)
	var deck := layer.get_node("CaptionDeck") as Control
	assert_eq(deck.get_rect(), Rect2(128.0, 448.0, 1024.0, 208.0))
	for card_name in ["CurrentCard", "PreviousCard", "OldestCard"]:
		var card := layer.get_node("%%%s" % card_name) as MarginContainer
		assert_false(card.visible)
		assert_eq(card.custom_minimum_size, Vector2(0.0, 64.0))
		assert_eq(card.get_theme_constant("margin_left"), 12)
		assert_eq(card.get_theme_constant("margin_top"), 6)
		assert_eq(card.get_theme_constant("margin_right"), 12)
		assert_eq(card.get_theme_constant("margin_bottom"), 6)
	for label_name in [
		"CurrentPrimary", "CurrentSecondary",
		"PreviousPrimary", "PreviousSecondary",
		"OldestPrimary", "OldestSecondary",
	]:
		var label := layer.get_node("%%%s" % label_name) as RichTextLabel
		assert_false(label.scroll_active)
		assert_eq(int(label.autowrap_mode), 2)

func test_scene_has_one_self_owned_dialogic_text_and_no_speaker_opaque_or_focusable_controls() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	var dialog_text_script := load(DIALOG_TEXT_SCRIPT_PATH) as Script
	var scene_source := FileAccess.get_file_as_string(SCENE_PATH)
	assert_false("StyleBox" in scene_source)
	assert_false("theme_override_styles/" in scene_source)
	var text_owners: Array[Node] = []
	var scene_nodes := _descendants(layer)
	scene_nodes.push_front(layer)
	for node in scene_nodes:
		if node.get_script() == dialog_text_script:
			text_owners.append(node)
		assert_false("speaker" in str(node.name).to_lower())
		assert_false(node.is_in_group("dialogic_name_label"))
		if node is Control:
			var control := node as Control
			assert_eq(control.focus_mode, Control.FOCUS_NONE)
			assert_false(control is Panel)
			assert_false(control is PanelContainer)
			assert_false(control is ColorRect)
	assert_eq(text_owners.size(), 1)
	var owner := text_owners[0] as DialogicNode_DialogText
	assert_same(owner, layer.call("get_current_text_owner"))
	assert_same(owner.textbox_root, owner)
	assert_false((layer.get_node("%CurrentCard") as Control).visible)

func test_publication_and_append_require_an_active_nonempty_session() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	var empty_session_projection := _projection_for_session(&"", &"one", "One")
	var publish_before_reset: Dictionary = layer.call("publish_beat", empty_session_projection)
	var append_before_reset: Dictionary = layer.call("append_current", empty_session_projection)
	assert_false(publish_before_reset.ok)
	assert_eq(publish_before_reset.code, &"caption_session_required")
	assert_false(append_before_reset.ok)
	assert_eq(append_before_reset.code, &"caption_session_required")
	assert_true(layer.call("reset_session", &"fixture.session", &"single").ok)
	assert_true(layer.call("publish_beat", _projection(&"one", "One")).ok)
	layer.call("clear_session")
	var publish_after_clear: Dictionary = layer.call("publish_beat", empty_session_projection)
	var append_after_clear: Dictionary = layer.call("append_current", empty_session_projection)
	assert_false(publish_after_clear.ok)
	assert_eq(publish_after_clear.code, &"caption_session_required")
	assert_false(append_after_clear.ok)
	assert_eq(append_after_clear.code, &"caption_session_required")

func test_single_language_publishes_oldest_to_current_but_keeps_current_first_semantics() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	assert_true(layer.call("reset_session", &"fixture.session", &"single").ok)
	assert_true(layer.call("publish_beat", _projection(&"one", "One")).ok)
	await get_tree().process_frame
	assert_eq(layer.call("get_visual_semantic_ids"), [&"one"])
	var stack := layer.get_node("%CaptionStack") as Control
	var current := layer.get_node("%CurrentCard") as Control
	assert_almost_eq(current.position.y + current.size.y, stack.size.y, 0.01)
	assert_true(layer.call("publish_beat", _projection(&"two", "Two")).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"one", &"two"])
	assert_true(layer.call("publish_beat", _projection(&"three", "Three")).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"one", &"two", &"three"])
	assert_eq(layer.call("get_assistive_semantic_ids"), [&"three", &"two", &"one"])
	await get_tree().process_frame
	await get_tree().process_frame
	var previous := layer.get_node("%PreviousCard") as Control
	var oldest := layer.get_node("%OldestCard") as Control
	assert_true(oldest.position.y < previous.position.y)
	assert_true(previous.position.y < current.position.y)
	assert_almost_eq(oldest.position.y + oldest.size.y + 8.0, previous.position.y, 0.01)
	assert_almost_eq(previous.position.y + previous.size.y + 8.0, current.position.y, 0.01)
	assert_almost_eq(current.position.y + current.size.y, stack.size.y, 0.01)
	var expected_minimum_height := (
		oldest.get_combined_minimum_size().y
		+ previous.get_combined_minimum_size().y
		+ current.get_combined_minimum_size().y
		+ 16.0
	)
	assert_almost_eq(stack.get_combined_minimum_size().y, expected_minimum_height, 0.01)

func test_fourth_beat_evicts_only_oldest_visible_card() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"single")
	for row in [[&"one", "One"], [&"two", "Two"], [&"three", "Three"], [&"four", "Four"]]:
		assert_true(layer.call("publish_beat", _projection(row[0], row[1])).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"two", &"three", &"four"])
	assert_eq(layer.call("get_assistive_semantic_ids"), [&"four", &"three", &"two"])
	assert_true((layer.call("get_projection", &"one") as Dictionary).is_empty())

func test_append_extends_current_in_both_languages_without_creating_a_card() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"single")
	layer.call("publish_beat", _projection(&"single", "First"))
	assert_true(layer.call("append_current", _projection(&"single", " continued")).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"single"])
	assert_eq((layer.call("get_projection", &"single") as Dictionary).primary_text, "First continued")
	assert_true((layer.get_node("%CurrentCard") as Control).visible)
	assert_false((layer.get_node("%PreviousCard") as Control).visible)
	assert_false((layer.get_node("%OldestCard") as Control).visible)
	assert_eq((layer.get_node("%CurrentPrimary") as RichTextLabel).text, "First continued")
	layer.call("reset_session", &"fixture.session", &"dual")
	layer.call("publish_beat", _projection(&"one", "Primary", "Secondary"))
	assert_true(layer.call("append_current", _projection(&"one", " plus", " 續")).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"one"])
	assert_eq((layer.call("get_projection", &"one") as Dictionary).primary_text, "Primary plus")
	assert_eq((layer.call("get_projection", &"one") as Dictionary).secondary_text, "Secondary 續")
	assert_eq((layer.get_node("%CurrentPrimary") as RichTextLabel).text, "Primary plus")
	assert_eq((layer.get_node("%CurrentSecondary") as RichTextLabel).text, "Secondary 續")
	assert_true((layer.get_node("%CurrentSecondary") as Control).visible)

func test_dual_mode_keeps_exactly_one_semantic_card() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"dual")
	for row in [[&"one", "One", "一"], [&"two", "Two", "二"], [&"three", "Three", "三"], [&"four", "Four", "四"]]:
		assert_true(layer.call("publish_beat", _projection(row[0], row[1], row[2])).ok)
		assert_eq(layer.call("get_visual_semantic_ids"), [row[0]])
		assert_eq(layer.call("get_assistive_semantic_ids"), [row[0]])
	assert_true((layer.get_node("%CurrentCard") as Control).visible)
	assert_false((layer.get_node("%PreviousCard") as Control).visible)
	assert_false((layer.get_node("%OldestCard") as Control).visible)
	assert_eq((layer.get_node("%CurrentPrimary") as RichTextLabel).text, "Four")
	assert_eq((layer.get_node("%CurrentSecondary") as RichTextLabel).text, "四")
	assert_true((layer.get_node("%CurrentSecondary") as Control).visible)

func test_projection_storage_is_immutable_and_append_fails_closed_on_wrong_identity() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"single")
	var input := _projection(&"one", "Original")
	layer.call("publish_beat", input)
	input.primary_text = "Mutated"
	assert_eq((layer.call("get_projection", &"one") as Dictionary).primary_text, "Original")
	var returned_projection: Dictionary = layer.call("get_projection", &"one")
	returned_projection.primary_text = "Mutated output"
	assert_eq((layer.call("get_projection", &"one") as Dictionary).primary_text, "Original")
	var failure: Dictionary = layer.call("append_current", _projection(&"other", "Wrong"))
	assert_false(failure.ok)
	assert_eq(failure.code, &"caption_identity_mismatch")

func test_republishing_identical_current_text_preserves_dialogic_reveal_state() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"single")
	layer.call("publish_beat", _projection(&"same", "Same text"))
	var owner := layer.call("get_current_text_owner") as DialogicNode_DialogText
	owner.visible_characters = 3
	owner.revealing = true
	var repeated: Dictionary = layer.call("publish_beat", _projection(&"same", "Same text"))
	assert_true(repeated.ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"same"])
	assert_eq(layer.call("get_assistive_semantic_ids"), [&"same"])
	assert_eq(owner.visible_characters, 3)
	assert_true(owner.revealing)

func test_republishing_current_identity_with_conflicting_content_fails_without_mutation() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"single")
	assert_true(layer.call("publish_beat", _projection(&"same", "Original", "Original secondary")).ok)
	var conflict: Dictionary = layer.call(
		"publish_beat",
		_projection(&"same", "Conflicting", "Conflicting secondary")
	)
	assert_false(conflict.ok)
	assert_eq(conflict.code, &"caption_identity_conflict")
	assert_eq(layer.call("get_visual_semantic_ids"), [&"same"])
	assert_eq(layer.call("get_assistive_semantic_ids"), [&"same"])
	assert_eq(
		layer.call("get_projection", &"same"),
		_projection(&"same", "Original", "Original secondary")
	)
