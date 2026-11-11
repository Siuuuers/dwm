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
