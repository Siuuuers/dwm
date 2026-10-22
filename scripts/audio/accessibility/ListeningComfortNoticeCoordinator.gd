class_name ListeningComfortNoticeCoordinator
extends RefCounted

const INTERVAL_SECONDS := 3600.0
const FIRST_RUN_NOTES: Dictionary = {
	"en": "Set a comfortable device volume. Stop and rest if sound feels uncomfortable.",
	"zh_CN": "请将设备音量调至舒适水平。如果声音令你不适，请停止并休息。",
	"zh_HK": "請將裝置音量調至舒適水平。如果聲音令你不適，請停止並休息。",
	"ja": "機器の音量を心地よい大きさに調整してください。音がつらく感じたら、使用をやめて休憩してください。",
	"ko": "기기의 음량을 편안한 수준으로 조절하세요. 소리가 불편하게 느껴지면 사용을 멈추고 쉬세요.",
}
const REMINDERS: Dictionary = {
	"en": "You have been playing for a while. This is a quiet moment to rest your ears.",
	"zh_CN": "你已经游玩一段时间了。现在正好安静地让耳朵休息一下。",
	"zh_HK": "你已經遊玩一段時間了。現在正好安靜地讓耳朵休息一下。",
	"ja": "しばらくプレイしています。この静かな時間に、耳を休ませましょう。",
	"ko": "한동안 플레이했어요. 잠시 조용히 귀를 쉬게 해 주세요.",
}

var _elapsed_seconds: float = 0.0
var _eligible: bool = false


func advance_elapsed(seconds: float, foreground: bool, paused: bool) -> void:
	if not foreground or paused or not is_finite(seconds) or seconds < 0.0:
		return
	_elapsed_seconds += seconds
	if _elapsed_seconds >= INTERVAL_SECONDS:
		_elapsed_seconds = fmod(_elapsed_seconds, INTERVAL_SECONDS)
		_eligible = true


## Only the owner knows when Pause or a day boundary is reached; a scene never emits a notice.
func notice_at_boundary(boundary: String, locale: String) -> Dictionary:
	if not _eligible or boundary not in ["pause", "day_boundary"] or not REMINDERS.has(locale):
		return {}
	_eligible = false
	return {"kind": "listening_comfort", "text": REMINDERS[locale]}


static func first_run_note(locale: String) -> String:
	return FIRST_RUN_NOTES.get(locale, "")
