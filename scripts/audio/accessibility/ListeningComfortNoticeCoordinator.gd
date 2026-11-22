class_name ListeningComfortNoticeCoordinator
extends RefCounted

const FIRST_RUN_NOTES: Dictionary = {
	"en": "Set a comfortable device volume. Stop and rest if sound feels uncomfortable.",
	"zh_CN": "请将设备音量调至舒适水平。如果声音令你不适，请停止并休息。",
	"zh_HK": "請將裝置音量調至舒適水平。如果聲音令你不適，請停止並休息。",
	"ja": "機器の音量を心地よい大きさに調整してください。音がつらく感じたら、使用をやめて休憩してください。",
	"ko": "기기의 음량을 편안한 수준으로 조절하세요. 소리가 불편하게 느껴지면 사용을 멈추고 쉬세요.",
}

static func first_run_note(locale: String) -> String:
	return FIRST_RUN_NOTES.get(locale, "")
