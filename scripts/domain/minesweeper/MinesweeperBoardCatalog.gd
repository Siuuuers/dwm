class_name MinesweeperBoardCatalog
extends RefCounted
## Closed public board dimensions and base mine counts for current-v1 hosts.

const _DESKTOP := {
	"beginner": {"width": 8, "height": 8, "base_mine_count": 10},
	"intermediate": {"width": 16, "height": 16, "base_mine_count": 40},
	"expert": {"width": 22, "height": 22, "base_mine_count": 99},
}
const _FIXED := {
	"canonical_solo": {"width": 18, "height": 18, "base_mine_count": 36},
	"canonical_pair": {"width": 18, "height": 18, "base_mine_count": 36},
}


static func lookup(host: String, difficulty: String = "") -> Dictionary:
	if host == "desktop_app":
		if not _DESKTOP.has(difficulty):
			return _fail(&"unknown_minesweeper_difficulty")
		return _ok((_DESKTOP[difficulty] as Dictionary).duplicate())
	if _FIXED.has(host):
		if not difficulty.is_empty():
			return _fail(&"minesweeper_difficulty_not_selectable")
		return _ok((_FIXED[host] as Dictionary).duplicate())
	return _fail(&"unknown_minesweeper_host")


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": "", "details": {}}
