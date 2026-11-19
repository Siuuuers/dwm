extends "res://addons/gut/test.gd"

func test_forced_text_matches_native_classification_and_parsing() -> void:
	var cache := DialogicResourceUtil.get_event_cache()
	for source: String in ["label opening", "return", "if true:", "# comment", "- choice",
			"[wait time=1]", "<<END BRANCH>>", "_: First\\: line\ncontinued #id:line.test",
			'"Parser Speaker": Hello', "One[n]Two[n+]Three"]:
		for prefix: String in ["", "\\"]:
			var content := prefix + source
			var expected: DialogicEvent
			for prototype: DialogicEvent in cache:
				if prototype._test_event_string(content):
					expected = prototype.duplicate()
					break
			var actual := DialogicTimeline.event_from_string(content, cache)
			assert_eq(actual.get_script(), expected.get_script(), content)
			assert_false(is_same(actual, cache.back()))
			if not prefix.is_empty():
				assert_true(actual is DialogicTextEvent)
				actual._load_from_string(content)
				expected._load_from_string(content)
				assert_eq(actual.to_text(), expected.to_text(), content)
				assert_eq(actual._translation_id, expected._translation_id)

func test_forced_text_events_keep_independent_caption_state() -> void:
	var cache := DialogicResourceUtil.get_event_cache()
	var first: DialogicTextEvent = DialogicTimeline.event_from_string("\\First", cache)
	var second: DialogicTextEvent = DialogicTimeline.event_from_string("\\Second", cache)
	assert_false(is_same(first, second))
	first._load_from_string("\\First #id:line.first")
	second._load_from_string("\\Second #id:line.second")
	first.state = DialogicTextEvent.States.DONE
	assert_eq(second.state, DialogicTextEvent.States.IDLE)
	assert_eq(first.text, "First")
	assert_eq(second.text, "Second")
	assert_eq(first._translation_id, "line.first")
	assert_eq(second._translation_id, "line.second")

class CountingDialogText extends RichTextLabel:
	static var created := 0

	func _init() -> void:
		created += 1

func test_plain_caption_retires_effects_without_copying_the_dialogue_label() -> void:
	var label := CountingDialogText.new()
	label.bbcode_enabled = true
	add_child_autofree(label)
	label.add_to_group("dialogic_dialog_text")
	assert_eq(get_tree().get_first_node_in_group("dialogic_dialog_text"), label)

	var text := get_node("/root/Dialogic").get_subsystem("Text") as Node
	assert_eq(text.parse_text_effects("[b]Hi[/b][pause=0.1]!"), "[b]Hi[/b]!")
	assert_eq(text.parsed_text_effect_info.size(), 1)
	assert_eq(text.parsed_text_effect_info[0].index, 2)

	var count := CountingDialogText.created
	assert_eq(text.parse_text_effects("Time for tea."), "Time for tea.")
	assert_true(text.parsed_text_effect_info.is_empty())
	assert_eq(CountingDialogText.created, count, "Plain dialogue needs no label copy.")
	assert_eq(text.parse_text_effects("\\[pause=1]"), "[pause=1]")
	assert_true(text.parsed_text_effect_info.is_empty())
	await get_tree().process_frame
