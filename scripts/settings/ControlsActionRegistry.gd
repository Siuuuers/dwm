extends RefCounted
## Authored Controls inventory. Read-only metadata; no InputMap/profile mutation.
## Consumer admission is separate from the potential context overlap declared here.

const RUN_CONTEXTS := [
	&"run_launcher", &"run_app", &"run_witnessed",
	&"run_desktop_grid", &"run_challenge_grid", &"run_pause",
]

static func records() -> Array[Dictionary]:
	return [
		_record(&"game_quick_save", ["Quick Save", "快速保存", "快速儲存", "クイックセーブ", "빠른 저장"], KEY_F5, JOY_BUTTON_LEFT_STICK, RUN_CONTEXTS),
		_record(&"game_quick_load", ["Quick Load", "快速读取", "快速讀取", "クイックロード", "빠른 불러오기"], KEY_F9, JOY_BUTTON_RIGHT_STICK, RUN_CONTEXTS),
		_record(&"game_toggle_board_mode", ["Toggle Flag / Reveal", "切换标旗／揭示", "切換插旗／揭示", "旗／開くを切替", "깃발 / 열기 전환"], KEY_F, JOY_BUTTON_X, [&"run_desktop_grid", &"run_challenge_grid"]),
		_record(&"game_new_board", ["New Board", "新棋盘", "新棋盤", "新しい盤面", "새 보드"], KEY_SPACE, JOY_BUTTON_Y, [&"run_desktop_grid"]),
	]

static func _record(id: StringName, labels: Array, key: int, button: int, contexts: Array) -> Dictionary:
	return {
		"id": id,
		"labels": {"en": labels[0], "zh-CN": labels[1], "zh-HK": labels[2], "ja": labels[3], "ko": labels[4]},
		"contexts": contexts.duplicate(),
		"keyboard": {"kind": "key", "physical_keycode": key, "keycode": 0, "shift": false, "alt": false, "ctrl": false, "meta": false},
		"controller": {"kind": "joypad_button", "button_index": button, "device": -1},
	}
