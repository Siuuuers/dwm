extends GutTest
## Real owner and shared reducer. Fake generation is explicit except the certified Debug case.
const FIXTURE := preload("res://tests/unit/test_dating_physical_owner.gd")
const OWNER := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const ENVELOPE := preload("res://scripts/application/run/DatingChallengeEnvelope.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const GENERATION := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const REAL_GENERATION := preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd")

var game: RefCounted
var profile: RefCounted
var physical: RefCounted
var issuer: RefCounted
var generation: RefCounted
var command: Dictionary
var layout: Dictionary

func before_each() -> void:
	game = FIXTURE.State.new()
	profile = FIXTURE.Profile.new()
	issuer = ISSUER.new()
	assert_true(issuer.configure(STORE.new("94".repeat(32), 1)).ok)
	generation = GENERATION.new()
	var mines: Array = []
	for index in 36: mines.append(index)
	layout = {"schema_version": 1, "width": 18, "height": 18, "mine_indices": mines, "mine_count": 36}
	generation.arm_materialize(layout)
	physical = OWNER.new()
	assert_true(physical.configure(issuer, game, profile, generation).ok)
	command = {"completion_transaction_id": "dating:envelope-test", "command_sha256": "envelope-test".sha256_text(),
		"context": {"kind": "solo", "day": 1, "participants": ["sylvia"]}}
	command["physical_token"] = physical._token(command.completion_transaction_id, command.command_sha256)

func _begin() -> bool:
	var begun: Dictionary = physical.begin_physical(command)
	assert_true(begun.ok, str(begun))
	return bool(begun.ok)

func _act(action: String, index: int = -1) -> Dictionary:
	var pulled: Dictionary = physical.pull_physical(command.physical_token)
	if not pulled.ok: return pulled
	var result: Dictionary = physical.dispatch_physical(command.physical_token, action, index, int(pulled.value.board.revision))
	# dwm-634.2: a terminal reveal only paints; the scene settles it on its next frame.
	if result.get("ok", false) and action != "settle":
		var after: Dictionary = physical.pull_physical(command.physical_token)
		var view: Dictionary = after.get("value", {}) if after.get("ok", false) else {}
		if view.get("phase") == "challenge" and view.get("board") is Dictionary and bool(view.board.terminal):
			return physical.dispatch_physical(command.physical_token, "settle", -1, int(view.board.revision))
	return result

func test_shell_flags_survive_fresh_owner_and_materialize_with_exact_history() -> void:
	if not _begin(): return
	assert_true(_act("continue").ok)
	assert_true(_act("flag", 0).ok)
	assert_true(_act("unflag", 0).ok)
	assert_null(game.saved.board)
	assert_eq(generation.call_log.size(), 0, "shell marking draws no mine layout")
	assert_eq(physical.pull_physical(command.physical_token).value.no_flag, "lost")
	var saved: Dictionary = game.saved.duplicate(true)
	physical = OWNER.new()
	assert_true(physical.configure(issuer, game, profile, generation).ok)
	assert_true(physical.begin_physical(command).ok)
	assert_eq(game.saved, saved)
	assert_true(_act("reveal", 323).ok)
	assert_eq(game.saved.board.actions, saved.envelope.shell.actions)
	assert_eq(game.saved.board.revision, 2)
	assert_eq(game.saved.phase, "post_challenge")
	assert_eq(game.saved.relationship_outcome, "loved")
	assert_eq(game.applications, 1)
	assert_eq(game.saved.perfect_reasons, [])

func test_entry_freezes_real_lucky_debug_and_hidden_extra_inputs() -> void:
	game.inventory = {"lucky_charm": 1, "debug_key": 1}
	game.pressure = 7
	game.penalty_points_today = 1
	if not _begin(): return
	var spec: Dictionary = game.saved.spec.duplicate(true)
	assert_eq(spec.pressure, 7)
	assert_eq(spec.raw_extra_mines, 3)
	assert_eq(spec.requested_mine_count, 37)
	assert_true(spec.capability_ids.has("first_cell_zero"))
	assert_true(spec.capability_ids.has("forced_no_guess"))
	game.inventory.clear()
	game.pressure = 0
	assert_true(physical.pull_physical(command.physical_token).ok)
	assert_eq(game.saved.spec, spec, "later inputs cannot change the frozen candidate")

func test_perfect_settles_automatically_and_never_exposes_a_dark_choice() -> void:
	if not _begin(): return
	assert_true(_act("continue").ok)
	assert_true(_act("reveal", 323).ok)
	assert_eq(game.saved.phase, "post_challenge")
	assert_eq(game.saved.outcome, "perfect")
	assert_eq(game.saved.relationship_outcome, "foresight")
	assert_eq(game.applications, 1)
	assert_false(_act("activate", int(game.saved.envelope.special_cell)).ok)
	var view: Dictionary = physical.pull_physical(command.physical_token).value
	assert_false(view.special_mine_visible)
	for cell: Dictionary in view.board.cells: assert_eq(cell.actions, [])

func test_nonperfect_flagged_clear_applies_loved_without_any_marked_or_actionable_cell() -> void:
	if not _begin(): return
	assert_true(_act("continue").ok)
	var retired_special: int = ENVELOPE.special_cell(game.saved.spec, layout)
	assert_true(_act("flag", retired_special).ok)
	assert_true(_act("reveal", 323).ok)
	var view: Dictionary = physical.pull_physical(command.physical_token).value
	assert_eq(view.phase, "post_challenge")
	assert_false(view.special_mine_visible)
	assert_false(view.special_mine_enabled)
	assert_false(view.actions.has("activate"))
	assert_false(view.actions.has("special_mine"))
	for cell: Dictionary in view.board.cells:
		assert_eq(cell.actions, [])
		assert_false(cell.get("mark", "") in ["marked_mine", "marked_flag"])
	assert_eq(game.saved.relationship_outcome, "loved")
	assert_eq(game.applications, 1)
	var settled: Dictionary = game.saved.duplicate(true)
	assert_false(_act("activate", -1).ok)
	assert_false(physical.dispatch_physical(command.physical_token, "activate", retired_special, int(view.board.revision) + 1).ok)
	assert_false(_act("activate", retired_special).ok)
	assert_false(_act("special_mine").ok)
	assert_false(_act("settle").ok)
	assert_eq(game.saved, settled)
	assert_eq(game.applications, 1)

func test_debug_preparation_and_shell_flags_resume_without_changing_the_certified_reveal() -> void:
	game.inventory = {"debug_key": 1, "lucky_charm": 1}
	generation = REAL_GENERATION.new()
	physical = OWNER.new()
	assert_true(physical.configure(issuer, game, profile, generation).ok)
	if not _begin(): return
	var started := _act("continue")
	assert_true(started.ok, str(started))
	if not started.ok: return
	assert_eq(game.saved.phase, "preparing")
	assert_null(game.saved.board)
	var saved: Dictionary = game.saved.duplicate(true)
	physical = OWNER.new()
	assert_true(physical.configure(issuer, game, profile, generation).ok)
	assert_true(physical.begin_physical(command).ok)
	assert_eq(game.saved, saved)
	for _slice in 512:
		if game.saved.phase != "preparing": break
		var advanced := _act("prepare")
		assert_true(advanced.ok, str(advanced))
		if not advanced.ok: return
	assert_eq(game.saved.phase, "challenge")
	if game.saved.phase != "challenge": return
	var forced: int = game.saved.envelope.forced_cell
	var other: int = (forced + 1) % 324
	var certified: Dictionary = game.saved.envelope.prepared_layout.duplicate(true)
	var view: Dictionary = physical.pull_physical(command.physical_token).value
	var revealable: Array = []
	for cell: Dictionary in view.board.cells:
		if cell.actions.has("reveal"): revealable.append(cell.index)
		assert_true(cell.actions.has("flag"), "certification restricts Reveal, not covered-cell marking")
	assert_eq(revealable, [forced])
	assert_true(view.board.cells[forced].bracketed)
	assert_false(_act("reveal", other).ok)
	assert_true(_act("flag", forced).ok)
	assert_true(_act("flag", other).ok)
	view = physical.pull_physical(command.physical_token).value
	assert_eq(view.board.cells[forced].actions, ["unflag"])
	assert_true(view.board.cells[forced].bracketed)
	assert_eq(view.board.cells[other].actions, ["unflag"])
	assert_eq(view.no_flag, "lost")
	var marked: Dictionary = game.saved.duplicate(true)
	assert_false(_act("reveal", forced).ok, "a flagged forced cell must be unflagged first")
	assert_eq(game.saved, marked, "refused Reveal cannot alter the prepared certificate or history")
	physical = OWNER.new()
	assert_true(physical.configure(issuer, game, profile, generation).ok)
	assert_true(physical.begin_physical(command).ok)
	assert_eq(game.saved, marked, "fresh ownership retains both prepared flags and the exact certificate")
	assert_true(_act("unflag", forced).ok)
	view = physical.pull_physical(command.physical_token).value
	assert_eq(view.board.cells[forced].actions, ["reveal", "flag"])
	assert_false(_act("reveal", other).ok)
	var shell: Dictionary = game.saved.envelope.shell.duplicate(true)
	assert_true(_act("reveal", forced).ok)
	assert_eq(game.saved.board.adjacency_counts[forced], 0)
	assert_eq(game.saved.board.flagged_indices, [other])
	assert_eq(game.saved.board.actions, shell.actions)
	assert_eq(game.saved.board.mine_indices, certified.mine_indices)
	assert_eq(game.saved.envelope.prepared_layout, certified)
	assert_eq(game.saved.spec, saved.spec)
	assert_true(ENVELOPE.validate(game.saved))
