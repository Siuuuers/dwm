extends GutTest
## Real owner and shared reducer. Fake generation is explicit except the certified Debug case.
const FIXTURE := preload("res://tests/unit/test_dating_physical_owner.gd")
const OWNER := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const ENVELOPE := preload("res://scripts/application/run/DatingChallengeEnvelope.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const GENERATION := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const REAL_GENERATION := preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd")
const SCENE := preload("res://scenes/dating/DatingScene.tscn")

class InputOwner extends RefCounted:
	signal input_bindings_changed
	signal source_input_custody_changed
	var contacts: Dictionary = {}
	func get_physical_contacts() -> Dictionary: return contacts.duplicate()
	func get_physical_contact_id(_event: InputEvent) -> String: return ""
	func is_source_input_admitted() -> bool: return true

class ScenePort extends RefCounted:
	var physical: RefCounted
	func begin(_command: Dictionary) -> Dictionary: return {"ok": true}
	func complete(_request: Dictionary) -> Dictionary: return {"ok": false}
	func pull_physical(command: Dictionary) -> Dictionary: return physical.pull_physical(command.physical_token)
	func dispatch_physical(command: Dictionary, action: String, index: int, revision: int) -> Dictionary:
		return physical.dispatch_physical(command.physical_token, action, index, revision)

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
	assert_eq(game.saved.phase, "cleared_awaiting_terminal_choice")
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

func test_nonperfect_marked_flag_binds_exact_cell_revision_and_first_terminal_winner() -> void:
	if not _begin(): return
	assert_true(_act("continue").ok)
	var marked: int = ENVELOPE.special_cell(game.saved.spec, layout)
	assert_true(_act("flag", marked).ok)
	assert_true(_act("reveal", 323).ok)
	var view: Dictionary = physical.pull_physical(command.physical_token).value
	assert_eq(view.board.cells[marked].mark, "marked_flag")
	assert_eq(view.board.cells[marked].actions, ["activate"])
	var actionable := 0
	for cell: Dictionary in view.board.cells:
		if not cell.actions.is_empty(): actionable += 1
	assert_eq(actionable, 1)
	assert_false(_act("activate", -1).ok)
	assert_false(physical.dispatch_physical(command.physical_token, "activate", marked, int(view.board.revision) + 1).ok)
	assert_eq(game.applications, 0)
	assert_true(_act("activate", marked).ok)
	assert_eq(game.saved.relationship_outcome, "dark")
	assert_false(_act("activate", marked).ok)
	assert_eq(game.applications, 1)

func test_actual_grid_choice_waits_for_clearing_contact_release_and_ignores_mode() -> void:
	if not _begin(): return
	assert_true(_act("continue").ok)
	assert_true(_act("flag", 0).ok)
	assert_true(_act("reveal", 323).ok)
	var input := InputOwner.new()
	input.contacts = {"key:0:13": 1}
	var port := ScenePort.new(); port.physical = physical
	var scene: Control = SCENE.instantiate()
	assert_true(scene.configure_presentation(port, command).ok)
	assert_true(scene.configure_presentation_services(input).ok)
	add_child_autofree(scene)
	assert_true(scene.worksheet.grid.can_present(scene._physical_view.board), "the entire actual marked-cell projection must satisfy the existing cell contract")
	assert_false(scene.worksheet.grid.projection.is_empty())
	if scene.worksheet.grid.projection.is_empty(): return
	assert_false(scene._choice_released)
	scene._on_continue()
	assert_eq(game.applications, 0)
	input.contacts.clear()
	await get_tree().process_frame
	assert_true(scene._choice_released)
	assert_true(scene._continue_button.has_focus())
	var marked: int = int(game.saved.envelope.special_cell)
	assert_true(scene.worksheet.grid.set_mode(&"drag"))
	assert_eq(scene.worksheet.grid._mode_action(marked), &"activate")
	assert_true(scene.worksheet.grid.focus_cell(marked))
	assert_eq(scene.worksheet.grid.focus_next, scene.worksheet.grid.get_path_to(scene._continue_button))
	scene._on_cell_action(&"activate", marked, int(game.saved.board.revision))
	assert_eq(game.saved.relationship_outcome, "dark")
	assert_false(scene.worksheet.visible, "the terminal pressure board withdraws into the post-scene card")

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
