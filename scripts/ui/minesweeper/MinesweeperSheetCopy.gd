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
	"ja": {"rules": "ルール", "assignments": "課題", "return": "戻る", "claimed": "受取済み", "unclaimed": "未受取", "facts": ["開く操作で、閉じたマスを開きます。", "旗の操作で、閉じたマスに旗を立てたり外したりします。", "開いた数字で「開く」を使うと、隣の旗の数が数字と同じなら周囲も開きます。", "ドラッグで盤面を移動します。マスは操作しません。"], "requirements": ["初級をクリア", "中級をクリア", "上級をクリア", "旗なしでクリア", "先読みでクリア", "パーフェクト — 初級", "パーフェクト — 中級", "パーフェクト — 上級", "全3難度をクリア"]},
	"ko": {"rules": "규칙", "assignments": "과제", "return": "돌아가기", "claimed": "수령함", "unclaimed": "미수령", "facts": ["열기로 닫힌 칸을 열어요.", "깃발로 닫힌 칸에 깃발을 세우거나 제거해요.", "열린 숫자에서 열기: 주변 깃발 수가 숫자와 같으면 이웃 칸도 열려요.", "드래그는 보드만 이동하며 칸을 조작하지 않아요."], "requirements": ["초급 완료", "중급 완료", "고급 완료", "깃발 없이 완료", "예지로 완료", "완벽 — 초급", "완벽 — 중급", "완벽 — 고급", "세 난도 모두 완료"]},
}

static func get_copy(locale: String) -> Dictionary:
	return COPY.get(locale.replace("_", "-"), {}).duplicate(true)
