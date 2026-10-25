extends "res://addons/gut/test.gd"
## Real shipped seven-day programmes, independently enumerated expected routes.
const HISTORY := preload("res://scripts/narrative/SceneReadingHistory.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const RESULTS := {"never_started": "A", "unfinished": "B", "won": "C", "lost": "D", "perfect": "E"}
var _bundle: Dictionary
var _nodes := {}
var _lines := {}
var _covered := {}

func before_all() -> void:
	_bundle = STRICT.parse_object(FileAccess.get_file_as_string("res://data/manifests/scene_story_registration.json")).value
	var entries := {}
	for entry: Dictionary in _bundle.entry_manifest.entries: entries[entry.entry_id] = entry
	for programme: Dictionary in _bundle.scene_programme.entries:
		var compiled := ADAPTER.compile_scene_programme(entries[programme.entry_id].locators.en.path,
			programme.entry_id, entries.keys(), programme.markers)
		assert_true(compiled.ok)
		if compiled.ok: _nodes[programme.entry_id] = compiled.value.nodes
	for entry: Dictionary in _bundle.caption_registry.entries: _lines[entry.entry_id] = entry.lines

func _outcomes(pairs: Dictionary) -> Dictionary:
	var facts := {}
	for id: String in pairs: facts[id + ":occurrence"] = {"challenge_id": id, "outcome": pairs[id]}
	return facts

func _check_path(path: Array, choices: Dictionary, pairs: Dictionary) -> void:
	var expected: Array = []
	for entry: String in path:
		_covered[entry] = true
		for line: Dictionary in _lines[entry]: expected.append(line.line_id)
		var index := -1
		for i: int in _nodes[entry].size():
			if _nodes[entry][i].kind == "caption": index = i
		var actual := HISTORY.project(_bundle, _nodes, entry, index, choices, _outcomes(pairs), "target.Day1")
		assert_true(actual.ok, str({"path": path, "entry": entry, "result": actual}))
		if not actual.ok: return
		assert_eq(actual.value.day, _bundle.scene_programme.story_days[entry])
		assert_eq(actual.value.captions.map(func(row: Dictionary) -> String: return row.line_id), expected)
		assert_true(actual.value.captions.all(func(row: Dictionary) -> bool:
			return row.publication_id == "history:" + row.line_id), "display identities are not live publications")
		# Held final controls show the same preceding text and do not select a future path.
		if index + 1 < _nodes[entry].size() and _nodes[entry][index + 1].kind == "control":
			var held := HISTORY.project(_bundle, _nodes, entry, index + 1, choices, _outcomes(pairs), "target.Day1")
			assert_true(held.ok)
			if held.ok: assert_eq(held.value.captions, actual.value.captions)

func test_day1_all_photo_and_challenge_paths_to_shared_coda() -> void:
	for choice: String in ["pass", "yes"]:
		for outcome: String in RESULTS:
			_check_path(["Day1", "Day1.photo." + ("default" if choice == "pass" else "yes"),
				"Day1.reading", "Day1.result." + RESULTS[outcome], "Day1.coda"],
				{"Day1.photo": choice}, {"Day1.challenge": outcome})

func test_day2_all_food_result_and_threshold_paths() -> void:
	for choice: String in ["pass", "yes"]:
		for outcome: String in RESULTS:
			for after: String in (["pass", "stay", "cruel"] if outcome == "lost" else ["pass"]):
				var path := ["Day2", "Day2.food." + ("default" if choice == "pass" else "yes"), "Day2.answer", "Day2.result." + RESULTS[outcome]]
				if outcome == "lost": path.append("Day2.threshold." + ("benchmark" if after == "pass" else after))
				_check_path(path, {"Day2.food": choice, "Day2.threshold": after}, {"Day2.challenge": outcome})

func test_day3_both_partner_routes_and_all_results() -> void:
	for choice: String in ["pass", "yes"]:
		var partner := "lavinia" if choice == "pass" else "sylvia"
		for outcome: String in RESULTS:
			_check_path(["Day3", "Day3." + partner, "Day3." + partner + ".result." + RESULTS[outcome]],
				{"Day3.partner": choice}, {"Day3." + partner + ".challenge": outcome})

func test_day4_all_pastille_results_and_aftermath_paths() -> void:
	for choice: String in ["pass", "yes"]:
		for outcome: String in RESULTS:
			for after: String in (["pass", "mirror", "friday"] if outcome == "lost" else ["pass"]):
				var path := ["Day4", "Day4.pastille." + ("default" if choice == "pass" else "yes"), "Day4.impulse", "Day4." + RESULTS[outcome]]
				if outcome == "lost": path.append("Day4.D." + ("default" if after == "pass" else after))
				_check_path(path, {"Day4.pastille": choice, "Day4.aftermath": after}, {"Day4.challenge": outcome})

func test_day5_prior_day_recall_both_cheek_paths_and_all_results() -> void:
	for recalled: String in ["won", "lost"]:
		for choice: String in (["pass", "yes"] if recalled == "lost" else ["pass"]):
			for outcome: String in RESULTS:
				for after: String in (["pass", "note", "arch"] if outcome == "lost" else ["pass"]):
					var path := ["Day5"]
					if recalled == "lost": path.append_array(["Day5.cheek", "Day5.cheek." + ("default" if choice == "pass" else "yes")])
					path.append_array(["Day5.impulse", "Day5." + RESULTS[outcome]])
					if outcome == "lost": path.append("Day5.D." + ("default" if after == "pass" else after))
					_check_path(path, {"Day5.cheek": choice, "Day5.aftermath": after}, {"Day2.challenge": recalled, "Day5.challenge": outcome})

func test_day6_all_rehearsal_results_and_aftermath_paths() -> void:
	for choice: String in ["pass", "yes"]:
		for outcome: String in RESULTS:
			for after: String in (["pass", "word", "dark"] if outcome == "lost" else ["pass"]):
				var path := ["Day6", "Day6.rehearsal." + ("default" if choice == "pass" else "yes"), "Day6.impulse", "Day6." + RESULTS[outcome]]
				if outcome == "lost": path.append("Day6.D." + ("default" if after == "pass" else after))
				_check_path(path, {"Day6.rehearsal": choice, "Day6.aftermath": after}, {"Day6.challenge": outcome})

func test_day7_both_clipboards_results_recording_recall_and_all_aftermath_paths() -> void:
	for choice: String in ["pass", "yes"]:
		var side := "untouched" if choice == "pass" else "crossed"
		for outcome: String in RESULTS:
			for recalled: String in (["won", "lost"] if outcome == "lost" else ["won"]):
				for after: String in (["pass", "pocket", "board"] if outcome == "lost" else ["pass"]):
					var path := ["Day7", "Day7.clipboard." + ("default" if choice == "pass" else "yes"), "Day7." + side + ".impulse"]
					var choices := {"Day7.clipboard": choice}
					if outcome == "lost":
						var recalled_entry := "Day7." + side + ".D." + ("recording" if recalled == "lost" else "no_recording")
						path.append_array(["Day7." + side + ".D", recalled_entry])
						choices[recalled_entry + ".aftermath"] = after
						path.append("Day7." + side + ".D.board" if after == "board" else "Day7.D." + ("default" if after == "pass" else after))
					else: path.append("Day7." + RESULTS[outcome])
					_check_path(path, choices, {"Day1.challenge": recalled, "Day7." + side + ".challenge": outcome})

func test_current_prefix_and_held_choice_need_no_future_facts() -> void:
	var early := HISTORY.project(_bundle, _nodes, "Day1", 0, {}, {})
	assert_true(early.ok)
	assert_eq(early.value.captions.size(), 1)
	assert_eq(early.value.captions[0].text, _lines.Day1[0].text)
	var control: int = _nodes.Day1.size() - 2
	assert_eq(_nodes.Day1[control].kind, "control")
	var held := HISTORY.project(_bundle, _nodes, "Day1", control, {}, {})
	assert_true(held.ok)
	assert_eq(held.value.captions.size(), _lines.Day1.size())

func test_missing_invalid_ambiguous_facts_and_unreachable_position_refuse() -> void:
	assert_false(HISTORY.project(_bundle, _nodes, "Day1.photo.yes", 0, {}, {}).ok)
	assert_false(HISTORY.project(_bundle, _nodes, "Day1.photo.yes", 0, {"Day1.photo": "invalid"}, {}).ok)
	assert_false(HISTORY.project(_bundle, _nodes, "Day1.photo.yes", 0, {"Day1.photo": "pass"}, {}).ok)
	assert_false(HISTORY.project(_bundle, _nodes, "Day1.coda", 0, {"Day1.photo": "pass"}, {}).ok)
	var outcomes := _outcomes({"Day1.challenge": "won"})
	outcomes["another"] = {"challenge_id": "Day1.challenge", "outcome": "lost"}
	assert_eq(HISTORY.project(_bundle, _nodes, "Day1.coda", 0, {"Day1.photo": "pass"}, outcomes).code,
		&"reading_history_outcome_ambiguous")
	outcomes = _outcomes({"Day1.challenge": "invalid"})
	assert_false(HISTORY.project(_bundle, _nodes, "Day1.coda", 0, {"Day1.photo": "pass"}, outcomes).ok)
	assert_false(HISTORY.project(_bundle, _nodes, "absent", 0, {}, {}).ok)
	assert_false(HISTORY.project(_bundle, _nodes, "Day1", -1, {}, {}).ok)
	var loop: Dictionary = _nodes.duplicate(true)
	loop.Day1[0].next = 0
	assert_eq(HISTORY.project(_bundle, loop, "Day1", 1, {}, {}).code, &"reading_history_cycle")
	var bundle: Dictionary = _bundle.duplicate(true)
	bundle.scene_programme.erase("story_days")
	assert_eq(HISTORY.project(bundle, _nodes, "Day1", 0, {}, {}).code, &"reading_history_day_unavailable")

func test_day_start_is_authored_and_ambiguous_cross_day_entry_is_refused() -> void:
	var bundle: Dictionary = _bundle.duplicate(true)
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == "Day1.photo.yes":
			programme.markers[0].payload.target_id = "target.Day2.food.yes"
	assert_eq(HISTORY.project(bundle, _nodes, "Day2", 0, {}, {}).code, &"reading_history_day_ambiguous")
	bundle = _bundle.duplicate(true)
	bundle.scene_programme.story_days.erase("Day2")
	assert_eq(HISTORY.project(bundle, _nodes, "Day1", 0, {}, {}).code, &"reading_history_day_unavailable")
	bundle = _bundle.duplicate(true)
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == "Day1":
			programme.markers[0].payload.yes_target_id = "target.Day1.photo.default"
	assert_eq(HISTORY.project(bundle, _nodes, "Day1", 0, {}, {}).code, &"reading_history_day_ambiguous")
	var before: Dictionary = _bundle.duplicate(true)
	var choices := {"Day1.photo": "yes"}
	var outcomes := _outcomes({"Day1.challenge": "won"})
	var facts: Dictionary = outcomes.duplicate(true)
	var result := HISTORY.project(_bundle, _nodes, "Day1.coda", 0, choices, outcomes, "target.Day1")
	assert_true(result.ok)
	assert_eq(_bundle, before)
	assert_eq(choices, {"Day1.photo": "yes"})
	assert_eq(outcomes, facts)
	result.value.captions[0].text = "caller mutation"
	assert_eq(_bundle, before, "returned text rows cannot alter authored content")

func after_all() -> void:
	for entry: Dictionary in _bundle.entry_manifest.entries:
		if entry.role == "scene": assert_true(_covered.has(entry.entry_id), "every authored scene branch covered: " + entry.entry_id)
