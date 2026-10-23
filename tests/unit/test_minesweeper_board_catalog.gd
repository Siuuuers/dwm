extends GutTest

const CATALOG := preload("res://scripts/domain/minesweeper/MinesweeperBoardCatalog.gd")
const PORT := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd")
const BOARD_SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")

class GameStateFixture extends RefCounted:
	var minesweeper_rounds_left := 2
	var minesweeper_round_floor := 0
	var inventory: Dictionary = {}
	var penalty_points_today := 0
	var day := 1
	var condition_effects_today: Array = []
	var _stats := {"motivation": 3, "health": 3, "pressure": 0}

	func get_stat(stat_id: String) -> int:
		return int(_stats.get(stat_id, 0))

class IssuerFixture extends RefCounted:
	var ordinal := 0

	func issue(purpose: StringName) -> Dictionary:
		ordinal += 1
		return {"ok": true, "code": &"ok", "value": {
			"token": "%s.%d" % [purpose, ordinal],
			"issuer_receipt": {"receipt_id": "receipt.%s.%d" % [purpose, ordinal]},
		}, "receipt": {}}


func test_closed_catalog_has_exact_current_host_dimensions() -> void:
	var expected := {
		"beginner": {"width": 8, "height": 8, "base_mine_count": 10},
		"intermediate": {"width": 16, "height": 16, "base_mine_count": 40},
		"expert": {"width": 22, "height": 22, "base_mine_count": 99},
	}
	for difficulty: String in expected:
		assert_eq(CATALOG.lookup("desktop_app", difficulty).value, expected[difficulty])
	for host: String in ["canonical_solo", "canonical_pair"]:
		assert_eq(CATALOG.lookup(host).value,
			{"width": 18, "height": 18, "base_mine_count": 36})


func test_catalog_rejects_unknowns_and_fixed_host_difficulty_choices() -> void:
	assert_eq(CATALOG.lookup("unknown", "beginner").code, &"unknown_minesweeper_host")
	assert_eq(CATALOG.lookup("desktop_app").code, &"unknown_minesweeper_difficulty")
	assert_eq(CATALOG.lookup("desktop_app", "nightmare").code, &"unknown_minesweeper_difficulty")
	assert_eq(CATALOG.lookup("canonical_solo", "beginner").code,
		&"minesweeper_difficulty_not_selectable")
	assert_eq(CATALOG.lookup("canonical_pair", "expert").code,
		&"minesweeper_difficulty_not_selectable")


func test_catalog_results_are_detached() -> void:
	var first: Dictionary = CATALOG.lookup("desktop_app", "beginner").value
	first.width = 99
	assert_eq(CATALOG.lookup("desktop_app", "beginner").value.width, 8)


func test_production_port_builds_schema_valid_specs_from_the_catalog() -> void:
	var game_state := GameStateFixture.new()
	var issuer := IssuerFixture.new()
	var port := PORT.new()
	assert_true(port.configure(game_state, issuer, {
		"run_id": "run-1", "branch_id": "branch-1", "desktop_timeline_generation": 1,
		"causal_day_instance": "day-1",
	}).ok)
	var expected := {
		"beginner": Vector3i(8, 8, 10),
		"intermediate": Vector3i(16, 16, 40),
		"expert": Vector3i(22, 22, 99),
	}
	for difficulty: String in expected:
		var prepared: Dictionary = port.prepare_spec(difficulty, "tx-" + difficulty, {})
		assert_true(prepared.ok, JSON.stringify(prepared))
		var spec: Dictionary = prepared.value.spec
		assert_eq(Vector3i(spec.width, spec.height, spec.base_mine_count), expected[difficulty])
		assert_true(BOARD_SCHEMA.validate_spec(spec).ok)
	var issued_before := issuer.ordinal
	var refused: Dictionary = port.prepare_spec("nightmare", "tx-bad", {})
	assert_eq(refused.code, &"unknown_minesweeper_difficulty")
	assert_eq(issuer.ordinal, issued_before, "An unknown tier is rejected before identity allocation.")
