class_name MinesweeperAssignmentsQuery
extends RefCounted
## Read-only run receipts, reduced to the nine accepted assignment statuses.

# Validate the accepted presentation order against the registry on every read.
const _EXPECTED_IDS := [
	"complete_beginner", "complete_intermediate", "complete_expert",
	"no_flag_finish", "foresight_finish",
	"perfect_beginner", "perfect_intermediate", "perfect_expert", "win_win_win",
]


static func from_sources(game_state: Object, catalog: Object) -> Dictionary:
	if not is_instance_valid(game_state) or not is_instance_valid(catalog) \
			or not catalog.has_method("get_minesweeper_tasks"):
		return _unavailable()
	var claims: Variant = game_state.get("minesweeper_task_rewards_claimed")
	if not claims is Dictionary:
		return _unavailable()
	var tasks: Variant = catalog.call(&"get_minesweeper_tasks")
	if not tasks is Array or tasks.size() != _EXPECTED_IDS.size():
		return _unavailable()
	var statuses: Array[bool] = []
	for index: int in _EXPECTED_IDS.size():
		var task: Variant = tasks[index]
		if not task is Object or not is_instance_valid(task):
			return _unavailable()
		var task_id: Variant = task.get("id")
		if not task_id is String or task_id != _EXPECTED_IDS[index]:
			return _unavailable()
		statuses.append(claims.has(task_id))
	return {"ok": true, "value": statuses}


static func _unavailable() -> Dictionary:
	return {"ok": false, "code": &"minesweeper_assignments_unavailable"}
