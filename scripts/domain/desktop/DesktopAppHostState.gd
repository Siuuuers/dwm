class_name DesktopAppHostState
extends RefCounted

## One visible cached desktop app + deterministic focus outputs (dwm-p2r.9, Plan 02 Task 1).
## Pure runtime state: no scene composition, no filesystem, no persistence of day/cache/paths.
## Phase 3 consumes this through the frozen seams; it never constructs or replaces the host.
##
## board_phase-driven command derivation (Plan 02 Task 2, dwm-p2r.32.1; controller-ruled additive
## extension of the frozen dwm-p2r.9 delivery). open_app/go_home/change_day accept the
## caller-supplied board_phase -- the frozen vocabulary NONE/PREPARING/PREPARED_UNSTARTED/
## ACTIVE_VISIBLE/ACTIVE_SUSPENDED/SETTLING -- and derive an ordered `commands` list the caller
## must apply to the board. The host never stores board_phase and never mutates board truth; it
## only reacts to whatever phase the trusted state port supplies on each call. Every pre-existing
## field/return shape here is unchanged; the new behavior is additive only (new methods, and new
## trailing-defaulted parameters plus a new `value` member on open_app/change_day).

const REGISTRY := preload("res://scripts/domain/desktop/DesktopAppRegistry.gd")

const _MINESWEEPER_ID := &"minesweeper"
const _ACTIVE_VISIBLE := &"ACTIVE_VISIBLE"
const _ACTIVE_SUSPENDED := &"ACTIVE_SUSPENDED"
const _PREPARING := &"PREPARING"
const _PREPARED_UNSTARTED := &"PREPARED_UNSTARTED"

var _current_day: int = 0
var _active_app_id: StringName = &""
var _cached_app_ids: Array[StringName] = []


func reset(current_day: int) -> void:
	_current_day = current_day
	_active_app_id = &""
	_cached_app_ids = []


func open_app(app_id: StringName, current_day: int, board_phase: StringName = &"NONE") -> Dictionary:
	if app_id == &"logout":
		return {"ok": false, "code": &"desktop_action_not_workspace", "message": "Logout is launcher consent, not a workspace"}
	if not REGISTRY.new().has_app(app_id):
		return {"ok": false, "code": &"unknown_app_id", "message": "app_id is not a registered desktop app"}
	_current_day = current_day
	var previous_app_id: StringName = _active_app_id
	var hide_app_id: StringName = _active_app_id if _active_app_id != &"" else &""
	var was_cached := _cached_app_ids.has(app_id)
	if not was_cached:
		_cached_app_ids.append(app_id)
	var record: Dictionary = REGISTRY.new().get_record(app_id)
	var focus_target: NodePath = record.get("focus_target", NodePath())
	_active_app_id = app_id
	var commands := _open_app_commands(previous_app_id, app_id, board_phase)
	return {
		"ok": true,
		"instantiate": not was_cached,
		"hide_app_id": hide_app_id if hide_app_id != &"" else null,
		"show_app_id": app_id,
		"focus_target": focus_target,
		"value": {"state": get_state(), "commands": commands},
	}


## Home always preserves the cache -- unlike change_day, nothing is evicted. A started board
## (ACTIVE_VISIBLE) is suspended before the active app is hidden; any other phase, or no active
## app, just hides whatever was showing (or emits no commands at all).
func go_home(current_day: int, board_phase: StringName) -> Dictionary:
	_current_day = current_day
	var previous_app_id: StringName = _active_app_id
	var commands: Array[Dictionary] = []
	if previous_app_id != &"":
		if previous_app_id == _MINESWEEPER_ID and board_phase == _ACTIVE_VISIBLE:
			commands.append({"kind": "suspend_board"})
		commands.append({"kind": "hide_app", "app_id": String(previous_app_id)})
	_active_app_id = &""
	return {"ok": true, "code": &"ok",
		"value": {"state": get_state(), "commands": commands}, "receipt": {}}


func close_app() -> Dictionary:
	if _active_app_id == &"":
		return {"ok": false, "code": &"no_active_app", "message": "no app is currently open"}
	var focus_icon_app_id: StringName = _active_app_id
	_active_app_id = &""
	return {"ok": true, "code": &"ok", "focus_icon_app_id": focus_icon_app_id}


func change_day(new_day: int, board_phase: StringName = &"NONE") -> Dictionary:
	if new_day <= 0:
		return {"ok": false, "code": &"invalid_day", "message": "day must be positive"}
	if new_day <= _current_day:
		return {"ok": false, "code": &"day_not_advanced", "message": "day must strictly advance"}
	var evicted: Array[StringName] = []
	for id in REGISTRY.new().get_ids():
		if _cached_app_ids.has(id):
			evicted.append(id)
	var eviction_command := {
		"command_id": "desktop-day:%d" % new_day,
		"kind": &"evict_cached_apps",
		"day": new_day,
		"app_ids": evicted.duplicate(true),
	}
	var commands := _change_day_commands(board_phase)
	_active_app_id = &""
	_cached_app_ids = []
	_current_day = new_day
	return {"ok": true, "code": &"ok",
		"value": {
			"eviction_command": eviction_command.duplicate(true),
			"commands": commands,
			"state": get_state(),
		}, "receipt": {}}


func get_state() -> Dictionary:
	return {
		"current_day": _current_day,
		"active_app_id": _active_app_id if _active_app_id != &"" else null,
		"cached_app_ids": _cached_app_ids.duplicate(true),
	}


func capture_persistent_state() -> Dictionary:
	return {"active_app_id": _active_app_id if _active_app_id != &"" else null}


func prepare_restore(active_app_id: Variant, current_day: int) -> Dictionary:
	if current_day <= 0:
		return {"ok": false, "code": &"invalid_day", "message": "restore day must be positive"}
	var saved_id: StringName = &""
	if active_app_id != null:
		if typeof(active_app_id) == TYPE_STRING_NAME:
			saved_id = active_app_id
		elif typeof(active_app_id) == TYPE_STRING:
			saved_id = StringName(active_app_id)
		else:
			return {"ok": false, "code": &"invalid_active_app_id", "message": "active_app_id must be a registered ID or null"}
		if saved_id == &"logout":
			return {"ok": false, "code": &"desktop_action_not_workspace", "message": "Logout cannot be restored as a workspace"}
		if not REGISTRY.new().has_app(saved_id):
			return {"ok": false, "code": &"unknown_app_id", "message": "saved active_app_id is not a registered desktop app"}
	var candidate_state := {
		"current_day": current_day,
		"active_app_id": saved_id if saved_id != &"" else null,
		"cached_app_ids": [],
	}
	var instantiate_command = null
	if saved_id != &"":
		var record: Dictionary = REGISTRY.new().get_record(saved_id)
		instantiate_command = {
			"ok": true,
			"instantiate": true,
			"hide_app_id": null,
			"show_app_id": saved_id,
			"focus_target": record.get("focus_target", NodePath()),
		}
	return {"ok": true, "code": &"ok",
		"value": {"candidate_state": candidate_state, "instantiate_command": instantiate_command}, "receipt": {}}


## Installs a prepared restore or a captured rollback snapshot. Preparation never edits the host.
func commit_restore(candidate: Dictionary) -> Dictionary:
	var keys: Array = candidate.keys()
	keys.sort()
	if keys != ["active_app_id", "cached_app_ids", "current_day"] \
			or typeof(candidate.get("current_day")) != TYPE_INT or int(candidate["current_day"]) < 0 \
			or typeof(candidate.get("cached_app_ids")) != TYPE_ARRAY:
		return {"ok": false, "code": &"invalid_desktop_restore", "message": "invalid host snapshot"}
	var active: Variant = candidate["active_app_id"]
	if active != null and (typeof(active) not in [TYPE_STRING, TYPE_STRING_NAME] or active == &"logout" or not REGISTRY.new().has_app(StringName(active))):
		return {"ok": false, "code": &"invalid_desktop_restore", "message": "unknown active app"}
	var cached: Array[StringName] = []
	for id: Variant in candidate["cached_app_ids"]:
		if typeof(id) not in [TYPE_STRING, TYPE_STRING_NAME] or id == &"logout" or not REGISTRY.new().has_app(StringName(id)) or cached.has(StringName(id)):
			return {"ok": false, "code": &"invalid_desktop_restore", "message": "invalid cached app"}
		cached.append(StringName(id))
	# Day zero is only the pristine host before Bootstrap initializes it.
	if int(candidate["current_day"]) == 0 and (active != null or not cached.is_empty()):
		return {"ok": false, "code": &"invalid_desktop_restore", "message": "uninitialized host cannot contain apps"}
	_current_day = int(candidate["current_day"])
	_active_app_id = StringName(active) if active != null else &""
	_cached_app_ids = cached
	return {"ok": true, "code": &"ok", "value": {"state": get_state()}}


## Reopening the already-active app neither hides nor suspends itself. Switching away from a
## visible board suspends it before hiding minesweeper; opening minesweeper while its board is
## suspended resumes it. open_app admits the six content apps regardless of board_phase.
## Only minesweeper's own open/leave ever touches the board.
func _open_app_commands(previous_app_id: StringName, app_id: StringName, board_phase: StringName) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	if previous_app_id != &"" and previous_app_id != app_id:
		if previous_app_id == _MINESWEEPER_ID and board_phase == _ACTIVE_VISIBLE:
			commands.append({"kind": "suspend_board"})
		commands.append({"kind": "hide_app", "app_id": String(previous_app_id)})
	if app_id == _MINESWEEPER_ID and board_phase == _ACTIVE_SUSPENDED:
		commands.append({"kind": "resume_board"})
	commands.append({"kind": "open_app", "app_id": String(app_id)})
	return commands


## PREPARING/PREPARED_UNSTARTED candidates are discarded without cost (amendment SS6.7); a
## started board (ACTIVE_VISIBLE/ACTIVE_SUSPENDED) is forfeited with its paid costs retained.
## NONE and SETTLING have no live candidate or board to react to.
func _change_day_commands(board_phase: StringName) -> Array[Dictionary]:
	if board_phase in [&"UNPAID_UNSTARTED", _PREPARING, _PREPARED_UNSTARTED]:
		return [{"kind": "discard_candidate"}]
	if board_phase in [&"PAID_UNSTARTED", _ACTIVE_VISIBLE, _ACTIVE_SUSPENDED]:
		return [{"kind": "forfeit_board"}]
	return []
