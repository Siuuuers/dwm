extends RefCounted
## Public labels only; eligibility and warning decisions belong to the retained owners.
const LABELS := {
	"training": {"en": "Training", "zh-CN": "训练", "zh-HK": "訓練", "ja": "トレーニング", "ko": "훈련"},
	"working": {"en": "Work", "zh-CN": "工作", "zh-HK": "工作", "ja": "仕事", "ko": "일하기"},
	"rest": {"en": "Rest", "zh-CN": "休息", "zh-HK": "休息", "ja": "休息", "ko": "휴식"},
	"date": {"en": "Date", "zh-CN": "约会", "zh-HK": "約會", "ja": "デート", "ko": "데이트"},
}
const WARNING_TEXT := {
	"unread_invitation": {
		"en": ["Unread invitation", "There is an invitation waiting in Contacts.", "Close", "Open Contacts", "Contacts could not open. Please try again."],
		"zh-CN": ["未读邀请", "联系册中有一条邀请等待查看。", "关闭", "打开联系册", "暂时无法打开联系册，请重试。"],
		"zh-HK": ["未讀邀請", "聯絡簿中有一則邀請等待查看。", "關閉", "開啟聯絡簿", "暫時無法開啟聯絡簿，請重試。"],
		"ja": ["未読の招待", "連絡先に未読の招待があります。", "閉じる", "連絡先を開く", "連絡先を開けませんでした。もう一度お試しください。"],
		"ko": ["읽지 않은 초대", "연락처에 읽지 않은 초대가 있어요.", "닫기", "연락처 열기", "연락처를 열지 못했어요. 다시 시도해 주세요."],
	},
	"accepted_date": {
		"en": ["Date not scheduled", "An accepted date is missing from today's schedule.", "Close", "Review schedule", "The schedule could not be reopened. Please try again."],
		"zh-CN": ["约会未安排", "已接受的约会尚未排入今天的日程。", "关闭", "查看日程", "暂时无法打开日程，请重试。"],
		"zh-HK": ["約會未安排", "已接受的約會尚未排入今天的日程。", "關閉", "查看日程", "暫時無法開啟日程，請重試。"],
		"ja": ["予定にないデート", "承諾したデートが今日の予定に入っていません。", "閉じる", "予定を確認", "予定を開けませんでした。もう一度お試しください。"],
		"ko": ["일정에 없는 데이트", "수락한 데이트가 오늘 일정에 없어요.", "닫기", "일정 확인", "일정을 열지 못했어요. 다시 시도해 주세요."],
	},
	"base_minesweeper": {
		"en": ["Minesweeper remains", "You still have a base round available or a board to finish.", "Close", "Open Minesweeper", "Minesweeper could not open. Please try again."],
		"zh-CN": ["扫雷尚未完成", "你还有基础回合可玩，或有尚未完成的棋盘。", "关闭", "打开扫雷", "暂时无法打开扫雷，请重试。"],
		"zh-HK": ["掃雷尚未完成", "你還有基礎回合可玩，或有尚未完成的棋盤。", "關閉", "開啟掃雷", "暫時無法開啟掃雷，請重試。"],
		"ja": ["未完了のマインスイーパー", "基本ラウンドが残っているか、未完了の盤面があります。", "閉じる", "開く", "マインスイーパーを開けませんでした。もう一度お試しください。"],
		"ko": ["남아 있는 지뢰찾기", "기본 라운드가 남아 있거나 아직 끝내지 않은 보드가 있어요.", "닫기", "지뢰찾기 열기", "지뢰찾기를 열지 못했어요. 다시 시도해 주세요."],
	},
}

static func action_names(records: Dictionary) -> Dictionary:
	var names := {}
	for action_id: String in records:
		var record: Dictionary = records[action_id]
		var labels: Dictionary = LABELS.get(action_id, LABELS.date).duplicate(true)
		if record.action_kind != "ordinary":
			var people: Array[String] = []
			for person: String in record.participants: people.append(person.capitalize())
			for locale: String in labels: labels[locale] += " \u00b7 " + " & ".join(people)
		names[action_id] = labels
	return names

static func warning_catalog() -> Dictionary:
	var catalog := {}
	var fields := ["title", "body", "close", "go", "failed_go"]
	for kind: String in WARNING_TEXT:
		catalog[kind] = {}
		for locale: String in WARNING_TEXT[kind]:
			var row := {}
			for index: int in fields.size(): row[fields[index]] = WARNING_TEXT[kind][locale][index]
			catalog[kind][locale] = row
	return catalog
