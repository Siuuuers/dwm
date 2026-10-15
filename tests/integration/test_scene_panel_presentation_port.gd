extends "res://addons/gut/test.gd"
## Real presentation/physical/Profile owners with injected scene authority and
## checkpoint storage. This is adapter integration, not Bootstrap or disk proof.
const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
const PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const PANEL := preload("res://scripts/ui/SceneChallengePanel.gd")

var _fixture: RefCounted
var _port: RefCounted
var _command: Dictionary

func before_each() -> void:
	_fixture = FIXTURE.new()
	assert_true(_fixture.setup("TEST.scene.panel.port").ok)
	_port = PORT.new()
	assert_true(_port.configure(_fixture.issuer, _fixture.owner).ok)
	var admitted: Dictionary = _port.begin(_fixture.command)
	assert_true(admitted.ok)
	_command = admitted.value.presentation_command

func after_each() -> void:
	_fixture.dispose()

func test_admission_and_preview_are_write_free_and_start_is_refused() -> void:
	var view: Dictionary = _port.pull_scene_panel(_command)
	assert_true(view.ok)
	assert_eq(view.value.actions, ["reveal"])
	assert_eq(view.value.host, "canonical_solo")
	assert_false(_port.dispatch_scene_panel_action(_command, "start", -1, 0).ok)
	assert_false(_port.dispatch_scene_panel_action(_command, "flag", 323, 0).ok)
	assert_false(_port.dispatch_scene_panel_action(_command, "reveal", 324, 0).ok)
	assert_true(_fixture.record().is_empty())
	assert_true(_fixture.authority.checkpoints.is_empty())

func test_unissued_and_altered_commands_cannot_reach_first_reveal() -> void:
	assert_false(_port.pull_scene_panel(_fixture.command).ok)
	var altered := _command.duplicate(true)
	altered.physical_token += ".altered"
	assert_false(_port.dispatch_scene_panel_action(altered, "reveal", 323, 0).ok)
	altered = _command.duplicate(true)
	altered.context.scene_occurrence += ".altered"
	assert_false(_port.pull_scene_panel(altered).ok)
	assert_false(_port.dispatch_scene_panel_action(altered, "reveal", 323, 0).ok)
	assert_true(_fixture.record().is_empty())
	assert_true(_fixture.authority.checkpoints.is_empty())

func test_first_reveal_duplicate_and_reopen_preserve_authoritative_board() -> void:
	var started: Dictionary = _port.dispatch_scene_panel_action(_command, "reveal", 323, 0)
	assert_true(started.ok)
	var before: Dictionary = _fixture.record().duplicate(true)
	var checkpoints: int = _fixture.authority.checkpoints.size()
	assert_false(before.is_empty())
	assert_true(_port.dispatch_scene_panel_action(_command, "reveal", 323, 0).ok)
	assert_eq(_fixture.record(), before)
	assert_eq(_fixture.authority.checkpoints.size(), checkpoints)
	assert_true(_port.begin(_fixture.command).ok)
	assert_true(_port.pull_scene_panel(_command).ok)
	assert_eq(_fixture.record(), before)
	assert_eq(_fixture.authority.checkpoints.size(), checkpoints)
	assert_eq(_fixture.state.effects, 0)

func test_panel_uses_real_trusted_port_and_reopens_without_repeating_reveal() -> void:
	var panel := PANEL.new()
	add_child(panel)
	assert_true(panel.bind(_port, _command))
	assert_true(panel.open_panel())
	assert_true(_fixture.record().is_empty())
	panel.worksheet.cell_action_requested.emit(&"reveal", 323, 0)
	assert_false(_fixture.record().is_empty())
	var before: Dictionary = panel.public_view.duplicate(true)
	var checkpoints: int = _fixture.authority.checkpoints.size()
	panel.close_panel()
	assert_true(panel.open_panel())
	assert_eq(panel.public_view, before)
	assert_eq(_fixture.authority.checkpoints.size(), checkpoints)
	panel.free()
