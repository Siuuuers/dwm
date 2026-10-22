extends "res://addons/gut/test.gd"
## Real reducer/Profile owner with existing injected End/checkpoint authority.
## This checks classification and exclusive destination selection, not native entry.
const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
var f: RefCounted

func before_each() -> void:
	f = FIXTURE.new()
	assert_true(f.setup().ok)
	var registration: Dictionary = f.authority.bundle
	var targets := {}
	var rows: Array = []
	for pair: Array in [["never_started", "a"], ["unfinished", "b"], ["won", "c"], ["lost", "d"], ["perfect", "e"]]:
		var id: String = "echo_%s_day1" % pair[1]
		targets[pair[0]] = id
		var row: Dictionary = registration.targets[0].duplicate(true)
		row.target_id = id
		rows.append(row)
	registration.targets = rows
	registration.challenges[0].targets = targets
	f.command.context.registration_sha256 = FIXTURE.CANONICAL.canonical_sha256(registration).value.sha256
	f.authority.command = f.command.duplicate(true)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)

func after_each() -> void:
	f.dispose()

func _close(outcome: String, target: String) -> void:
	var before: Dictionary = f.profile.get_profile_snapshot().duplicate(true)
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	assert_eq(closed.value.outcome, outcome)
	assert_eq(closed.value.target_id, target)
	assert_eq(f.authority.closures.size(), 1)
	assert_eq(f.profile.get_profile_snapshot(), before, "End dispatch does not award another result")
	assert_false(f.owner.close_scene_challenge(f.token).ok)
	assert_eq(f.authority.closures.size(), 1)
	assert_eq(f.state.effects, 0)
	if outcome == "never_started":
		assert_null(closed.value.attempt_proof)
	else:
		assert_true(FIXTURE.LEDGER.validate_attempt_proof(f.attempt().value, closed.value.attempt_proof).ok)

func test_not_started_view_and_refused_pre_reveal_flag_select_a() -> void:
	assert_eq(f.owner.pull_scene_panel(f.token).value.phase, "never_started")
	assert_false(f.owner.dispatch_scene_panel_action(f.token, "flag", 0, 0).ok)
	assert_eq(f.record(), {})
	_close("never_started", "echo_a_day1")

func test_unfinished_selects_b() -> void:
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 36).ok)
	assert_eq(f.record().state, "in_progress")
	_close("unfinished", "echo_b_day1")

func test_ordinary_win_selects_c_only() -> void:
	assert_true(f.action("start").ok)
	assert_true(f.action("flag", 0).ok)
	assert_true(f.action("unflag", 0).ok)
	assert_true(f.action("reveal", 323).ok)
	assert_eq(f.record().state, "won")
	assert_true(f.owner.pull_physical(f.token).value.result.perfect_reasons.is_empty())
	_close("won", "echo_c_day1")

func test_loss_selects_d() -> void:
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 36).ok)
	assert_true(f.action("reveal", 0).ok)
	assert_eq(f.record().state, "lost")
	_close("lost", "echo_d_day1")

func test_perfect_selects_e_without_changing_persisted_won_state() -> void:
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 323).ok)
	assert_eq(f.record().state, "won")
	assert_false(f.owner.pull_physical(f.token).value.result.perfect_reasons.is_empty())
	_close("perfect", "echo_e_day1")
	assert_eq(f.record().state, "won")

func test_historical_four_target_perfect_projection_stays_won() -> void:
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 323).ok)
	var targets: Dictionary = f.authority.bundle.challenges[0].targets.duplicate(true)
	targets.erase("perfect")
	assert_eq(FIXTURE.OWNER.scene_closure_outcome(f.record(), targets), "won")
	assert_eq(FIXTURE.OWNER.scene_closure_outcome(f.record(), f.authority.bundle.challenges[0].targets), "perfect")
