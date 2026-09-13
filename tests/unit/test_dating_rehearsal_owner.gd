extends GutTest
const OWNER := preload("res://scripts/application/run/DatingRehearsalOwner.gd")
const ADMISSION := preload("res://scripts/domain/narrative/DatingRehearsalAdmission.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const GAME := preload("res://autoload/GameState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")

func _signature(kind: String = "solo") -> Dictionary:
	var entry := "dating.solo.priscilla.day1.pre_challenge" if kind == "solo" else (
		"dating.%s.priscilla_lavinia.day2.pre_challenge" % ("twofriends" if kind == "twofriends_if_deferred" else "group"))
	var fields: Dictionary = {"tier": "friend", "tone": "sweet", "attitude": "neutral", "echo_ids": []} if kind == "solo" else {
		"pair_mode": kind, "pair_form": "love_dark"}
	var checked: Dictionary = SIGNATURE.validate({"entry_id": entry, "schema_version": 1, "fields": fields})
	assert_true(checked.ok, str(checked))
	return checked.get("value", {})

func _fixture(kind: String = "solo", milestone: bool = true) -> Dictionary:
	var game: Node = autofree(GAME.new())
	game.reset_game()
	game.set_stat("pressure", 3) # Practice copies this current input: one extra mine.
	game.route_context.canonical_marker = {"nested": [1, 2]}
	game.affection.priscilla = 3
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(STORAGE.new("rehearsal-profile", FILES.new())).ok)
	var source := _signature(kind)
	assert_true(profile.record_reached_presentation(source.signature).ok)
	if milestone:
		assert_true(profile.record_ending_completion("ending.alone", "ending:prior-run:gallery:ending.alone").ok)
	var owner := OWNER.new()
	assert_true(owner.configure(profile, game).ok)
	return {"owner": owner, "game": game, "profile": profile, "source": source}

func _begin(f: Dictionary) -> bool:
	var result: Dictionary = f.owner.begin(f.source, {"sandbox_test": {"value": 1}})
	assert_true(result.ok, str(result))
	if result.ok: f.command = result.value.presentation_command
	return bool(result.ok)

func _action(f: Dictionary, action: String, index: int = -1) -> Dictionary:
	var current: Dictionary = f.owner.pull_physical(f.command)
	if not current.ok: return current
	var result: Dictionary = f.owner.dispatch_physical(f.command, action, index, int(current.value.board.revision))
	# dwm-634.2: a terminal reveal only paints; the scene settles it on its next frame.
	if result.get("ok", false) and action != "settle":
		var after: Dictionary = f.owner.pull_physical(f.command)
		var view: Dictionary = after.get("value", {}) if after.get("ok", false) else {}
		if view.get("phase") == "challenge" and view.get("board") is Dictionary and bool(view.board.terminal):
			return f.owner.dispatch_physical(f.command, "settle", -1, int(view.board.revision))
	return result

func _board(f: Dictionary) -> Dictionary:
	return f.owner._sandbox.capture_dating_challenge_state().value

func _clear(f: Dictionary, use_flag: bool = false) -> void:
	assert_true(_action(f, "continue").ok)
	assert_true(_action(f, "reveal", 0).ok)
	var record := _board(f)
	assert_eq(record.board.width, 18)
	assert_eq(record.board.height, 18)
	assert_eq(record.spec.pressure, 3)
	assert_eq(record.spec.base_mine_count, 36)
	assert_eq(record.spec.requested_mine_count, 37)
	assert_eq(record.board.mine_count, 37, "the detached board retains the current pressure extra")
	assert_false(record.board.mine_indices.has(0), "the actual production generator protects first Reveal")
	if use_flag and not record.board.terminal:
		var mine: int = record.board.mine_indices[0]
		assert_true(_action(f, "flag", mine).ok)
		assert_true(_action(f, "unflag", mine).ok)
	for index: int in range(324):
		record = _board(f)
		if record.board.terminal: break
		if not record.board.mine_indices.has(index) and not record.board.revealed_indices.has(index):
			var reveal: Dictionary = _action(f, "reveal", index)
			assert_true(reveal.ok, str(reveal))
			if not reveal.ok: return
	assert_true(_board(f).board.terminal)

func test_exact_reached_pre_challenge_and_first_ending_are_both_required() -> void:
	var f := _fixture("solo", false)
	assert_eq(f.owner.begin(f.source).code, &"rehearsal_milestone_required")
	assert_true(f.profile.record_ending_completion("ending.alone", "ending:prior-run:gallery:ending.alone").ok)
	var forged: Dictionary = f.source.duplicate(true)
	forged.signature.fields.tier = "love"
	assert_eq(f.owner.begin(forged).code, &"invalid_rehearsal_source")
	var valid_unreached: Dictionary = SIGNATURE.validate(forged.signature).value
	assert_eq(f.owner.begin(valid_unreached).code, &"presentation_not_reached")
	var post_signature: Dictionary = f.source.signature.duplicate(true)
	post_signature.entry_id = "dating.solo.priscilla.day1.post_challenge"
	post_signature.fields.merge({"board_result": "perfect", "relationship_outcome": "dark",
		"perfect_reasons": ["no_flag"], "special_mine_phase": "resolved", "promotion_result": "none"})
	var post: Dictionary = SIGNATURE.validate(post_signature).value
	assert_eq(ADMISSION.prepare(post, [post], true).code, &"rehearsal_requires_pre_challenge")
	assert_true(f.owner.close().ok)

func test_real_perfect_settles_automatically_in_private_state_and_no_progression_capability_escapes() -> void:
	var f := _fixture()
	var before: Dictionary = f.game.capture_run_snapshot_input().duplicate(true)
	var profile_before: Dictionary = f.profile.get_profile_snapshot()
	seed(4711)
	var expected_random: int = randi()
	seed(4711)
	if not _begin(f): return
	assert_eq(randi(), expected_random, "private namespace and GS construction do not consume global RNG")
	assert_eq(f.owner.capture_presentation(f.command).value.signature, f.source.signature)
	assert_false(_board(f).spec.board_token_receipt_id.is_empty(), "private identities retain the real board receipt envelope")
	assert_false(f.owner.complete({}).ok)
	for command: String in ["observer_evidence", "pair_form_witness", "dating_attempt", "gallery_unlock", "schedule_commit"]:
		assert_eq(f.owner.execute_command(command).code, &"rehearsal_capability_denied")
	assert_eq(f.owner._physical.pull_observer(f.command.physical_token).value, {})
	_clear(f)
	assert_eq(_board(f).phase, "post_challenge")
	assert_eq(_board(f).outcome, "perfect")
	assert_false(_action(f, "activate", int(_board(f).envelope.special_cell)).ok)
	assert_eq(_board(f).relationship_outcome, "foresight")
	assert_eq(_board(f).outcome, "perfect")
	assert_eq(f.owner._sandbox.dating_route_state.priscilla.dark_points, 0)
	var post: Dictionary = f.owner.capture_presentation(f.command)
	assert_true(post.ok, str(post))
	if post.ok:
		assert_eq(post.value.signature.fields.board_result, "perfect")
		assert_eq(post.value.signature.fields.relationship_outcome, "foresight")
		assert_eq(post.value.signature.fields.special_mine_phase, "not_reached")
	assert_true(_action(f, "continue").ok)
	assert_eq(f.game.capture_run_snapshot_input(), before)
	assert_eq(f.profile.get_profile_snapshot(), profile_before)
	assert_true(f.owner.close().ok)
	assert_eq(f.game.capture_run_snapshot_input(), before)
	assert_eq(f.profile.get_profile_snapshot(), profile_before)

func test_both_pair_modes_finish_real_board_without_any_pair_witness_or_relationship_effect() -> void:
	for kind: String in ["group", "twofriends_if_deferred"]:
		var f := _fixture(kind)
		var before: Dictionary = f.game.capture_run_snapshot_input().duplicate(true)
		var profile_before: Dictionary = f.profile.get_profile_snapshot()
		if not _begin(f): return
		var relationship_before: Dictionary = f.owner._sandbox.dating_route_state.duplicate(true)
		_clear(f)
		assert_eq(_board(f).phase, "post_challenge")
		assert_eq(_board(f).applied_result, {"board_only": true})
		var post: Dictionary = f.owner.capture_presentation(f.command)
		assert_true(post.ok, str(post))
		if post.ok:
			assert_false(post.value.signature.fields.has("relationship_outcome"))
			assert_false(post.value.signature.fields.has("special_mine_phase"))
		assert_true(_action(f, "continue").ok, "rehearsal does not invoke its deliberately denied witness capability")
		assert_eq(f.owner._sandbox.dating_route_state, relationship_before)
		assert_eq(f.profile.get_profile_snapshot(), profile_before)
		assert_eq(f.game.capture_run_snapshot_input(), before)
		assert_true(f.owner.close().ok)

func test_solved_and_exploded_remain_real_distinct_outcomes_and_reject_debug_settlement() -> void:
	var f := _fixture()
	if not _begin(f): return
	assert_false(_action(f, "force_perfect").ok)
	_clear(f, true)
	assert_eq(_board(f).outcome, "cleared")
	assert_true(_action(f, "continue").ok)
	assert_eq(_board(f).relationship_outcome, "loved")
	assert_true(f.owner.close().ok)
	if not _begin(f): return
	assert_true(_action(f, "continue").ok)
	assert_true(_action(f, "reveal", 0).ok)
	var record := _board(f)
	if record.board.terminal:
		fail_test("fixture first reveal unexpectedly completed the random production board")
	else:
		assert_true(_action(f, "reveal", int(record.board.mine_indices[0])).ok)
		assert_eq(_board(f).outcome, "exploded")
		assert_eq(_board(f).relationship_outcome, record.mine_dispositions[0])
	assert_true(f.owner.close().ok)

func test_only_current_rendered_line_witness_can_persist_and_variables_remain_detached() -> void:
	var f := _fixture()
	var pre_line := "line.dating.solo.priscilla.day1.pre_challenge.practice"
	var post_line := "line.dating.solo.priscilla.day1.post_challenge.practice"
	assert_true(f.profile.configure_line_registry({"reply_lines": [{"line_id": pre_line}, {"line_id": post_line}]}).ok)
	var canonical_before: Dictionary = f.game.capture_run_snapshot_input().duplicate(true)
	var profile_before: Dictionary = f.profile.get_profile_snapshot()
	if not _begin(f): return
	assert_eq(f.profile.get_profile_snapshot(), profile_before, "begin and pull have no persistence effects")
	assert_false(f.owner.record_visited_line(f.command, post_line).ok)
	assert_true(f.owner.record_visited_line(f.command, pre_line).ok)
	assert_true(f.owner.record_visited_line(f.command, pre_line).ok)
	var variables := {"sandbox_test": {"value": 12}}
	assert_true(f.owner.apply_variables(f.command, variables).ok)
	variables.sandbox_test.value = 100
	var displayed: Dictionary = f.owner.capture_presentation(f.command).value
	assert_eq(displayed.variables.sandbox_test.value, 12)
	displayed.variables.sandbox_test.value = 200
	assert_eq(f.owner.capture_presentation(f.command).value.variables.sandbox_test.value, 12)
	var forged: Dictionary = f.command.duplicate(true)
	forged.execution_mode = "canonical"
	assert_false(f.owner.pull_physical(forged).ok)
	assert_false(f.owner.apply_variables(forged, {}).ok)
	_clear(f)
	assert_true(_action(f, "continue").ok)
	assert_true(f.owner.record_visited_line(f.command, post_line).ok)
	var expected: Dictionary = profile_before.duplicate(true)
	expected.visited_line_ids = [pre_line, post_line]
	assert_eq(f.profile.get_profile_snapshot(), expected, "no outcome signature, mastery, evidence or discovery is persisted")
	assert_eq(f.game.capture_run_snapshot_input(), canonical_before)
	var stale: Dictionary = f.command.duplicate(true)
	assert_true(f.owner.close().ok)
	assert_false(f.owner.pull_physical(stale).ok)
	if not _begin(f): return
	assert_ne(f.command.physical_token, stale.physical_token, "each practice receives its own namespace")
	assert_false(f.owner.pull_physical(stale).ok)
	assert_true(f.owner.close().ok)
