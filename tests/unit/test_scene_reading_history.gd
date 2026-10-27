extends "res://addons/gut/test.gd"
## Real shipped seven-day programmes, independently enumerated expected routes.
const HISTORY := preload("res://scripts/narrative/SceneReadingHistory.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const RESULTS := {"never_started": "A", "unfinished": "B", "won": "C", "lost": "D", "perfect": "E"}
var _bundle: Dictionary
var _lines := {}
var _covered := {}

func before_all() -> void:
	_bundle = STRICT.parse_object(FileAccess.get_file_as_string("res://data/manifests/scene_story_registration.json")).value
	for entry: Dictionary in _bundle.caption_registry.entries: _lines[entry.entry_id] = entry.lines

func _outcomes(pairs: Dictionary) -> Dictionary:
	var facts := {}
	for id: String in pairs: facts[id + ":occurrence"] = {"challenge_id": id, "outcome": pairs[id]}
	return facts

func _check_path(path: Array, choices: Dictionary, pairs: Dictionary) -> void:
	var day: int = _bundle.scene_programme.story_days[path[0]]
	var route := HISTORY.current_day_route(_bundle, day, choices, _outcomes(pairs))
	assert_true(route.ok, str(route))
	if not route.ok: return
	var expected: Array = path.duplicate()
	expected.sort()
	var actual: Array = route.value.entries.keys()
	actual.sort()
	assert_eq(actual, expected, "known choices/results admit only the actual authored route")
	for entry: String in path: _covered[entry] = true

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
					# Every authored Day7 route continues through the complete ordinary umbrella passage.
					path.append("ending.alone.normal")
					_check_path(path, choices, {"Day1.challenge": recalled, "Day7." + side + ".challenge": outcome})

func test_missing_new_prerequisites_do_not_force_rewind_of_an_intact_anchor() -> void:
	var route := HISTORY.current_day_route(_bundle, 1, {}, {})
	assert_true(route.ok)
	if not route.ok: return
	assert_true(route.value.entries.has("Day1.photo.yes"))
	assert_true(route.value.entries.has("Day1.photo.default"))
	assert_true(route.value.entries.has("Day1.coda"))
	var selected := HISTORY.current_day_route(_bundle, 1, {"Day1.photo": "pass"}, {})
	assert_true(selected.ok)
	assert_false(selected.value.entries.has("Day1.photo.yes"))

func test_invalid_choice_uses_default_and_ambiguous_outcome_does_not_admit_destination() -> void:
	var invalid := HISTORY.current_day_route(_bundle, 1, {"Day1.photo": "invalid"}, {})
	assert_true(invalid.ok)
	assert_false(invalid.value.entries.has("Day1.photo.yes"))
	assert_true(invalid.value.entries.has("Day1.photo.default"))
	var outcomes := _outcomes({"Day1.challenge": "won"})
	outcomes["another"] = {"challenge_id": "Day1.challenge", "outcome": "lost"}
	var ambiguous := HISTORY.current_day_route(_bundle, 1, {"Day1.photo": "pass"}, outcomes)
	assert_true(ambiguous.ok)
	assert_false(ambiguous.value.entries.has("Day1.coda"))

func test_day_start_is_authored_and_ambiguous_cross_day_entry_is_refused() -> void:
	var bundle: Dictionary = _bundle.duplicate(true)
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == "Day1.photo.yes":
			programme.markers[0].payload.target_id = "target.Day2.food.yes"
	assert_eq(HISTORY.current_day_route(bundle, 2, {}, {}).code, &"reading_history_day_ambiguous")
	bundle = _bundle.duplicate(true)
	bundle.scene_programme.story_days.erase("Day2")
	assert_eq(HISTORY.current_day_route(bundle, 1, {}, {}).code, &"reading_history_day_unavailable")

func test_encounter_projection_is_detached_and_never_backfills_or_duplicates() -> void:
	var before: Dictionary = _bundle.duplicate(true)
	var first: String = _lines.Day1[0].line_id
	var third: String = _lines.Day1[2].line_id
	var result := HISTORY.project_encountered(_bundle, [[first], ["deleted.line", third, third]])
	assert_eq(result.value.captions.map(func(row: Dictionary) -> String: return row.line_id), [first, third])
	assert_eq(result.value.captions[1].text, _lines.Day1[2].text)
	assert_true(result.value.captions.all(func(row: Dictionary) -> bool:
		return row.publication_id == "history:" + row.line_id))
	result.value.captions[0].text = "caller mutation"
	assert_eq(_bundle, before)

func after_all() -> void:
	for entry: Dictionary in _bundle.entry_manifest.entries:
		if entry.role == "scene": assert_true(_covered.has(entry.entry_id), "every authored scene branch covered: " + entry.entry_id)

func test_removed_option_selects_authored_default_in_route_projection() -> void:
	var marker := {"kind": "thought.options", "payload": {"opportunity_id": "TEST.choice",
		"pass_target_id": "target.default", "options": [{"choice_id": "kept", "target_id": "target.kept"}]}}
	var selected := HISTORY._select_target(marker, {"TEST.choice": "removed"}, {}, {})
	assert_true(selected.ok)
	assert_eq(selected.value, "target.default")
	assert_eq(HISTORY._select_target(marker, {"TEST.choice": "kept"}, {}, {}).value, "target.kept")
