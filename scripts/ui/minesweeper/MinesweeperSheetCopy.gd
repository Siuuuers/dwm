extends RefCounted
## Localized presentation intent from dossier section 10.4; no reward IDs or rules inference.

const COPY := {
	"en": {
		"rules": "Rules", "assignments": "Assignments", "return": "Return",
		"claimed": "Claimed", "unclaimed": "Unclaimed",
		"facts": ["Reveal opens a covered cell.", "Flag marks or unmarks a covered cell.", "Reveal on an open number may Chord when adjacent Flags match.", "Drag moves the worksheet without acting."],
		"requirements": ["Complete Beginner", "Complete Intermediate", "Complete Expert", "Finish with No flag", "Finish with Foresight", "Perfect — Beginner", "Perfect — Intermediate", "Perfect — Expert", "Complete all three tiers"],
	},
	"zh-CN": {
		"rules": "规则", "assignments": "任务", "return": "返回",
		"claimed": "已领取", "unclaimed": "未领取",
		"facts": ["揭开会打开一个覆盖的格子。", "标旗会在覆盖的格子上放置或移除旗帜。", "在已打开的数字上使用揭开，相邻旗帜数与数字相符时可以和弦展开。", "拖动会移动工作表，不对格子执行操作。"],
		"requirements": ["完成初级", "完成中级", "完成高级", "以无旗完成", "以远见完成", "完美 — 初级", "完美 — 中级", "完美 — 高级", "完成全部三个难度"],
	},
	"zh-HK": {
		"rules": "規則", "assignments": "任務", "return": "返回",
		"claimed": "已領取", "unclaimed": "未領取",
		"facts": ["揭開會打開一個覆蓋的格子。", "標旗會在覆蓋的格子上放置或移除旗幟。", "在已打開的數字上使用揭開，相鄰旗幟數與數字相符時可以和弦展開。", "拖動會移動工作表，不對格子執行操作。"],
		"requirements": ["完成初級", "完成中級", "完成高級", "以無旗完成", "以遠見完成", "完美 — 初級", "完美 — 中級", "完美 — 高級", "完成全部三個難度"],
	},
}

static func get_copy(locale: String) -> Dictionary:
	return COPY.get(locale.replace("_", "-"), {}).duplicate(true)
