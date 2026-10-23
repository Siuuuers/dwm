class_name MinesweeperGeneratorToolingLimits
extends RefCounted

## Tooling-only fail-stop bound (Plan 02 Task 4, dwm-p2r13). This is a per-generated-request safety
## ceiling for the offline build/benchmark tools, never a product-balance decision and never a
## candidate runtime budget -- production's search_operation_budget/hard_operation_budget come only
## from the frozen, evidence-derived data/manifests/minesweeper_generator_budget.v1.json.
##
## MUST NEVER be imported by scripts/domain/minesweeper/MinesweeperBoardGenerator.gd (a static
## dependency scan in tests/unit/tooling/test_minesweeper_generator_artifacts.gd proves this).

const TOOLING_SAFETY_OPERATION_CEILING := 16_777_216
