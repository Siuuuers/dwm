extends "res://addons/gut/test.gd"

const OWNER := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const RULES := preload("res://scripts/application/run/DatingChallengeRules.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const GENERATION := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const CANONICAL := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

class State extends RefCounted:
	var inventory: Dictionary = {}
	var penalty_points_today := 0
	var pressure := 0
	func get_stat(_id: String) -> int: return pressure
	var saved: Dictionary = {}
	var route_context: Dictionary = {}
	var dating_route_state: Dictionary = {"sylvia": {"relationship_state": "friend", "dark_points": 0}}
	var friend_attitude: Dictionary = {"sylvia": "neutral"}
	var facts: Dictionary = {}
	var applications: int = 0
	var fail_apply: bool = false
	var inter_friend_route_state: Dictionary = {"priscilla_lavinia": {"frozen_form": "ambiguous_sweet"}}
	func capture_dating_challenge_state() -> Dictionary:
		return {"ok": true, "value": saved.duplicate(true)}
	func store_dating_challenge_state(record: Dictionary, _emit_changes: bool = true) -> Dictionary:
		saved = record.duplicate(true)
		return {"ok": true, "value": {}}
	func capture_restore_state() -> Dictionary:
		return {"ok": true, "value": {"backup": {"saved": saved.duplicate(true),
			"facts": facts.duplicate(true), "applications": applications,
			"route_context": route_context.duplicate(true)}}}
	func rollback_restore_silent(backup: Dictionary) -> Dictionary:
		saved = backup.saved.duplicate(true)
		route_context = backup.route_context.duplicate(true)
		facts = backup.facts.duplicate(true)
		applications = int(backup.applications)
		return {"ok": true, "value": {}}
	func apply_dating_challenge_result(_entry: Dictionary, fact: Dictionary) -> Dictionary:
		if fail_apply: return {"ok": false, "code": &"fixture_write_failure"}
		var token: String = fact.transaction_id
		if facts.has(token):
			return {"ok": facts[token] == fact, "value": {"receipt": facts[token].duplicate(true)}}
		facts[token] = fact.duplicate(true)
		applications += 1
		return {"ok": true, "value": {"receipt": fact.duplicate(true)}}

class Profile extends RefCounted:
	var witnesses: Dictionary = {}
	func record_pair_form_witness(form: String, token: String) -> Dictionary:
		witnesses[token] = form
		return {"ok": true, "value": {}}

class ReachedProfile extends Profile:
	const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
	var reached: Dictionary = {}
	func record_reached_presentation(signature: Dictionary) -> Dictionary:
		var checked: Dictionary = SIGNATURE.validate(signature)
		if not checked.ok: return checked
		var signature_id: String = checked.value.signature_id
		var already: bool = reached.has(signature_id)
		reached[signature_id] = checked.value.signature.duplicate(true)
		return {"ok": true, "value": {"signature_id": signature_id, "already_reached": already}}

var state: State
var profile: Profile
var issuer: RefCounted
var generation: RefCounted
var physical_owner: RefCounted
var port: RefCounted
var command: Dictionary
var last_request: Dictionary
var completion_results: Array

func before_each() -> void:
	state = State.new()
	profile = Profile.new()
	issuer = ISSUER.new()
	assert_true(issuer.configure(STORE.new("84".repeat(32), 1)).ok)
	generation = GENERATION.new()
	var mines: Array = []
	for index in 36: mines.append(index)
	generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18,
		"mine_indices": mines, "mine_count": 36})
	physical_owner = OWNER.new()
	assert_true(physical_owner.configure(issuer, state, profile, generation).ok)
	port = PORT.new()
	assert_true(port.configure(issuer, physical_owner).ok)
	completion_results = []
	port.completion_ready.connect(func(receipt: Dictionary): completion_results.append(receipt.duplicate(true)))

func test_solo_public_actions_clear_then_saved_choice_pays_exactly_once() -> void:
	_begin("solo")
	var pre: Dictionary = port.pull_physical(command).value
	assert_eq(pre.board.cells.size(), 324)
	assert_false(pre.special_mine_enabled)
	assert_true(pre.board.custody)
	assert_false(_dispatch("reveal", 323).ok)
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("flag", 0).ok)
	assert_true(_dispatch("unflag", 0).ok)
	assert_true(_dispatch("reveal", 323).ok)
	assert_eq(state.saved.phase, "cleared_awaiting_terminal_choice")
	assert_eq(state.saved.spec.requested_mine_count, 36)
	assert_eq(state.saved.perfect_reasons, [])
	assert_eq(state.applications, 0, "clearing cannot apply a relationship outcome")
	assert_true(CANONICAL.canonical_json(state.saved).ok, "saved reducer enums are JSON safe")
	var frozen: Dictionary = state.saved.duplicate(true)
	physical_owner = OWNER.new()
	assert_true(physical_owner.configure(issuer, state, profile, generation).ok)
	assert_true(physical_owner.begin_physical(command).ok)
	assert_eq(state.saved, frozen)
	assert_eq(generation.call_log.size(), 1, "fresh physical_owner never regenerates an active board")
	assert_true(physical_owner.dispatch_physical(command.physical_token, "activate", int(state.saved.envelope.special_cell), int(state.saved.board.revision)).ok)
	assert_eq(state.applications, 1)
	assert_eq(state.facts[command.completion_transaction_id].relationship_outcome, "dark")
	assert_eq(state.saved.outcome, "cleared", "Dark is available only after a non-Perfect clear")
	assert_false(physical_owner.dispatch_physical(command.physical_token, "activate", int(state.saved.envelope.special_cell), int(state.saved.board.revision)).ok)
	assert_true(physical_owner.dispatch_physical(command.physical_token, "continue", -1, int(state.saved.board.revision)).ok)
	assert_eq(state.applications, 1)

func test_explosion_uses_frozen_disposition_and_retry_keeps_same_fact() -> void:
	_begin("solo")
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	var dispositions: Array = state.saved.mine_dispositions.duplicate()
	assert_eq(dispositions.size(), 36)
	assert_false(port.pull_physical(command).value.has("mine_dispositions"))
	state.fail_apply = true
	assert_false(_dispatch("reveal", 0).ok)
	assert_eq(state.saved.phase, "settlement_retry")
	assert_eq(state.saved.relationship_outcome, dispositions[0])
	assert_eq(state.saved.perfect_reasons, [])
	state.fail_apply = false
	assert_true(_dispatch("retry").ok)
	assert_eq(state.applications, 1)
	assert_eq(state.saved.mine_dispositions, dispositions)
	assert_true(_dispatch("continue").ok)
	assert_eq(completion_results.size(), 1)
	assert_true(_dispatch("resume_completion").ok)
	assert_eq(completion_results.size(), 1, "port completion publication is idempotent")

func test_group_and_deferred_pair_only_record_board_and_witness() -> void:
	for kind: String in ["group", "twofriends_if_deferred"]:
		state.saved = {}
		_begin(kind)
		assert_true(_dispatch("continue").ok)
		assert_true(_dispatch("reveal", 323).ok)
		assert_eq(state.saved.phase, "post_challenge")
		assert_eq(state.saved.host, "canonical_pair")
		assert_eq(state.saved.mine_dispositions, [])
		assert_null(state.saved.relationship_outcome)
		assert_false(port.pull_physical(command).value.special_mine_visible)
		assert_true(_dispatch("continue").ok)
		assert_eq(profile.witnesses[command.completion_transaction_id], "ambiguous_sweet")
	assert_eq(state.applications, 0, "pair observation changes no relationship stats")

func test_flag_unflag_chord_are_public_and_stale_revision_is_refused() -> void:
	_begin("solo")
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	assert_true(_dispatch("flag", 18).ok)
	assert_false(port.dispatch_physical(command, "unflag", 18, 0).ok)
	assert_true(_dispatch("unflag", 18).ok)
	assert_true(_dispatch("flag", 18).ok)
	assert_true(_dispatch("flag", 19).ok)
	assert_true(_dispatch("chord", 36).ok)
	assert_eq(state.saved.phase, "cleared_awaiting_terminal_choice")
	assert_eq(state.saved.outcome, "cleared")
	assert_eq(state.saved.perfect_reasons, [])
	assert_true(_dispatch("continue").ok)
	assert_eq(state.facts[command.completion_transaction_id].relationship_outcome, "loved")

func test_loaded_authoritative_record_replaces_cached_projection_and_rejects_tampering() -> void:
	_begin("solo")
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	var restored: Dictionary = state.saved.duplicate(true)
	assert_true(_dispatch("flag", 18).ok)
	state.saved = restored
	assert_eq(port.pull_physical(command).value.board.revision, 0, "Load supersedes process cache")
	state.saved.mine_dispositions[0] = "dark"
	assert_false(port.pull_physical(command).ok)
	state.saved = restored.duplicate(true)
	state.saved.context.participants = ["lavinia"]
	var fresh: RefCounted = OWNER.new()
	assert_true(fresh.configure(issuer, state, profile, generation).ok)
	assert_false(fresh.begin_physical(command).ok, "restored command identity cannot drift")

func test_three_bv_counts_zero_openings_and_remaining_numbers() -> void:
	var board: Dictionary = REDUCER.first_reveal({"schema_version": 1, "width": 3, "height": 3,
		"mine_indices": [4], "mine_count": 1}, 0).value.board
	assert_eq(RULES.three_bv(board), 8)
	board = REDUCER.set_flag(board, 4, true, "flag").value.board
	for index in [0, 1, 3, 5]:
		if not board.terminal: board = REDUCER.chord(board, index, "chord.%d" % index).value.board
	assert_true(board.terminal)
	assert_eq(RULES.perfect_reasons(board), ["efficiency_gte_100"])

func test_checkpoint_failure_rolls_back_terminal_stats_and_selection_before_retry() -> void:
	var stored: Array = []
	var refuse: Array = [false]
	var writer: Callable = func(record: Dictionary) -> Dictionary:
		if refuse[0]: return {"ok": false, "code": &"fixture_checkpoint_failure"}
		stored.append(record.duplicate(true))
		return {"ok": true, "value": {}}
	assert_true(physical_owner.configure_checkpoint_writer(writer).ok)
	assert_true(physical_owner.configure_checkpoint_writer(writer).ok)
	_begin("solo")
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("flag", 0).ok)
	assert_true(_dispatch("unflag", 0).ok)
	assert_true(_dispatch("reveal", 323).ok)
	assert_eq(stored.back().phase, "cleared_awaiting_terminal_choice")
	var before_choice: Dictionary = state.saved.duplicate(true)
	refuse[0] = true
	assert_false(_dispatch("activate", int(state.saved.envelope.special_cell)).ok)
	assert_eq(state.saved, before_choice)
	assert_eq(state.applications, 0)
	assert_eq(completion_results.size(), 0)
	refuse[0] = false
	assert_true(_dispatch("activate", int(state.saved.envelope.special_cell)).ok)
	assert_eq(state.applications, 1)
	refuse[0] = true
	assert_false(_dispatch("continue").ok)
	assert_eq(state.saved.phase, "post_challenge")
	assert_eq(completion_results.size(), 0, "completion cannot publish before the full snapshot is durable")
	refuse[0] = false
	assert_true(_dispatch("continue").ok)
	assert_eq(completion_results.size(), 1)
	assert_eq(state.applications, 1)

func test_mounted_scene_mouse_input_reaches_real_board_and_completion_port() -> void:
	# This mounted canonical UI now acknowledges reached presentations. Keep that actual port
	# contract enabled; the remaining legacy domain tests retain their narrower witness-only fake.
	profile = ReachedProfile.new()
	physical_owner = OWNER.new()
	assert_true(physical_owner.configure(issuer, state, profile, generation).ok)
	port = PORT.new()
	assert_true(port.configure(issuer, physical_owner).ok)
	port.completion_ready.connect(func(receipt: Dictionary): completion_results.append(receipt.duplicate(true)))
	_begin("solo")
	var scene: Control = preload("res://scenes/dating/DatingScene.tscn").instantiate()
	assert_true(scene.configure_presentation(port, command).ok)
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(scene.worksheet)
	if scene.worksheet == null: return
	var grid: Control = scene.worksheet.grid
	assert_eq(grid.projection.width, 18)
	assert_eq(grid.cell_nodes.size(), 324)
	var next: Button = scene.find_child("ContinueChallenge", true, false)
	var special: Button = scene.find_child("SpecialMine", true, false)
	assert_true(special.disabled)
	# Headless rendering does not emit CanvasItem.draw; exercise the real title's connected
	# draw acknowledgement, as the focused post-render unit test does for the status label.
	var title: Label = scene.find_child("ChallengeTitle", true, false)
	title.draw.emit()
	scene._process(0.0)
	assert_true(scene._pre_challenge_reached)
	assert_eq((profile as ReachedProfile).reached.size(), 1)
	next.pressed.emit()
	await get_tree().process_frame
	# A real paired pointer press/release, through the existing public widget input handler.
	var cell: Control = grid.cell_nodes[36]
	var down := InputEventMouseButton.new()
	down.device = 0
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = cell.position + cell.size / 2.0
	down.pressed = true
	grid._gui_input(down)
	var up: InputEventMouseButton = down.duplicate()
	up.pressed = false
	grid._gui_input(up)
	assert_true(state.saved.board is Dictionary)
	assert_eq(generation.call_log.size(), 1)
	assert_true(state.saved.board.revealed_indices.has(36))
	assert_false(next.visible)
	var mine: Control = grid.cell_nodes[0]
	down.position = mine.position + mine.size / 2.0
	grid._gui_input(down)
	up.position = down.position
	grid._gui_input(up)
	assert_eq(state.saved.phase, "post_challenge")
	assert_eq(state.applications, 1)
	assert_true(next.visible)
	scene._status_label.draw.emit()
	scene._process(0.0)
	assert_true(scene._post_challenge_reached)
	assert_eq((profile as ReachedProfile).reached.size(), 2)
	next.pressed.emit()
	assert_eq(completion_results.size(), 1)

func test_cached_admission_readopts_exact_restored_prior_date_without_new_board_identity() -> void:
	_begin("solo")
	var prior_command: Dictionary = command.duplicate(true)
	var prior_request: Dictionary = last_request.duplicate(true)
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	var prior_active: Dictionary = state.saved.duplicate(true)
	assert_true(_dispatch("reveal", 0).ok)
	assert_true(_dispatch("continue").ok)
	var completed: Dictionary = state.saved.duplicate(true)
	assert_true(port.begin(prior_request).ok)
	assert_eq(state.saved, completed, "admission replay cannot restart a completed board")
	_begin("group")
	state.saved = prior_active.duplicate(true)
	var replayed: Dictionary = port.begin(prior_request)
	assert_true(replayed.ok, str(replayed))
	assert_eq(replayed.value.presentation_command, prior_command)
	assert_eq(state.saved, prior_active)
	assert_eq(generation.call_log.size(), 1)
	assert_true(port.pull_physical(prior_command).ok)
	assert_eq(port.pull_physical(prior_command).value.board.revision, 0)

func _begin(kind: String) -> void:
	var context: Dictionary = {"kind": kind, "day": 3 if kind == "solo" else 2,
		"schedule_entry_id": "entry." + kind,
		"participants": ["sylvia"] if kind == "solo" else ["priscilla", "lavinia"]}
	var timeline: String = "dating.solo.sylvia.day3.pre_challenge" if kind == "solo" else (
		"dating.group.priscilla_lavinia.day2.pre_challenge" if kind == "group" else
		"dating.twofriends.priscilla_lavinia.day2.pre_challenge")
	var issued: Dictionary = issuer.issue(&"transaction_id")
	var root_receipt: Dictionary = issued.value.issuer_receipt
	var request: Dictionary = {"resolution_id": "resolution." + kind,
		"resolution_issuer_receipt": root_receipt, "stage_id": "execute_dates",
		"substage_id": "presentation." + kind, "route_id": "dating", "timeline_id": timeline,
		"context": context, "completion_transaction_id": "", "completion_transaction_provenance": {}}
	var sources: Array = []
	for key: String in ["resolution_id", "stage_id", "substage_id", "route_id", "timeline_id"]:
		sources.append(key + "=" + str(CANONICAL.canonical_json(request[key]).value.text))
	sources.append("role=" + str(CANONICAL.canonical_json("presentation.completion").value.text))
	sources.append("context_sha256=" + str(CANONICAL.canonical_json(
		CANONICAL.canonical_sha256(context).value.sha256).value.text))
	sources.sort()
	var child: Dictionary = issuer.derive_child({"parent_receipt_id": root_receipt.receipt_id,
		"child_kind": PORT.COMPLETION_CHILD_KIND, "ordinal": 0, "source_ids": sources})
	assert_true(child.ok, str(child))
	request.completion_transaction_id = child.value.child_id
	request.completion_transaction_provenance = child.value.provenance
	last_request = request.duplicate(true)
	var begun: Dictionary = port.begin(request)
	assert_true(begun.ok, str(begun))
	if begun.ok: command = begun.value.presentation_command

func _dispatch(action: String, index: int = -1) -> Dictionary:
	var view: Dictionary = port.pull_physical(command)
	if not view.ok: return view
	return port.dispatch_physical(command, action, index, int(view.value.board.revision))


func test_routine_board_actions_defer_receipts_and_write_no_checkpoint() -> void:
	# Rows 0-1 hold 33 mines and three more wall off the bottom-left corner (306), so the flood
	# from 323 leaves exactly one safe cell covered: the board stays in play after the first reveal.
	var mines: Array = []
	for index in 33: mines.append(index)
	mines.append_array([288, 289, 307])
	generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18,
		"mine_indices": mines, "mine_count": 36})
	var fake_root: RefCounted = STORE.new("85".repeat(32), 1)
	issuer = ISSUER.new()
	assert_true(issuer.configure(fake_root).ok)
	physical_owner = OWNER.new()
	assert_true(physical_owner.configure(issuer, state, profile, generation).ok)
	port = PORT.new()
	assert_true(port.configure(issuer, physical_owner).ok)
	var stored: Array = []
	var writer: Callable = func(record: Dictionary) -> Dictionary:
		stored.append(record.duplicate(true))
		return {"ok": true, "value": {}}
	assert_true(physical_owner.configure_checkpoint_writer(writer).ok)
	_begin("solo")
	assert_true(_dispatch("continue").ok)
	var boundary_checkpoints := stored.size()
	assert_gt(boundary_checkpoints, 0, "entering the challenge is a checkpoint boundary")
	assert_true(_dispatch("reveal", 323).ok)
	assert_eq(state.saved.phase, "challenge")
	assert_false(bool(state.saved.board.terminal), "the walled corner keeps the board in play")
	assert_eq(stored.size(), boundary_checkpoints + 1, "materializing the board is a checkpoint boundary")
	var durable_issues: int = fake_root.calls_to(&"issue").size()
	var deferred_issues: int = fake_root.calls_to(&"issue_deferred").size()
	assert_true(_dispatch("flag", 306).ok)
	assert_eq(state.saved.board.flagged_indices, [306], "the in-memory record still follows every action")
	assert_true(_dispatch("unflag", 306).ok)
	assert_eq(state.saved.board.flagged_indices, [])
	assert_eq(stored.size(), boundary_checkpoints + 1, "routine flag and unflag write no checkpoint")
	assert_eq(fake_root.calls_to(&"issue_deferred").size(), deferred_issues + 2, "routine actions defer their receipts")
	assert_eq(fake_root.calls_to(&"issue").size(), durable_issues, "routine actions never take the durable issue")
	assert_true(_dispatch("reveal", 306).ok)
	assert_eq(state.saved.phase, "cleared_awaiting_terminal_choice")
	assert_eq(stored.size(), boundary_checkpoints + 2, "the terminal reveal is a checkpoint boundary")
