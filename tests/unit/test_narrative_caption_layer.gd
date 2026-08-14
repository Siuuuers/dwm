extends "res://addons/gut/test.gd"

const SCENE_PATH := "res://scenes/shared/narrative/NarrativeCaptionLayer.tscn"

func _make_layer() -> Control:
	var packed := load(SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return null
	var layer := packed.instantiate() as Control
	add_child_autofree(layer)
	layer.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	return layer

func _projection(id: StringName, primary: String, secondary := "") -> Dictionary:
	return {
		"session_id": &"fixture.session",
		"semantic_id": id,
		"primary_text": primary,
		"secondary_text": secondary,
	}

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
	assert_almost_eq(current.position.y + current.size.y, stack.size.y, 0.01)

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
	layer.call("reset_session", &"fixture.session", &"dual")
	layer.call("publish_beat", _projection(&"one", "Primary", "Secondary"))
	assert_true(layer.call("append_current", _projection(&"one", " plus", " 續")).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"one"])
	assert_eq((layer.call("get_projection", &"one") as Dictionary).primary_text, "Primary plus")
	assert_eq((layer.call("get_projection", &"one") as Dictionary).secondary_text, "Secondary 續")

func test_dual_mode_keeps_exactly_one_semantic_card() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"dual")
	for row in [[&"one", "One", "一"], [&"two", "Two", "二"], [&"three", "Three", "三"], [&"four", "Four", "四"]]:
		assert_true(layer.call("publish_beat", _projection(row[0], row[1], row[2])).ok)
		assert_eq(layer.call("get_visual_semantic_ids"), [row[0]])
		assert_eq(layer.call("get_assistive_semantic_ids"), [row[0]])
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
	var failure: Dictionary = layer.call("append_current", _projection(&"other", "Wrong"))
	assert_false(failure.ok)
	assert_eq(failure.code, &"caption_identity_mismatch")
