extends RefCounted

const COPY := {
	"en": {
		"board":"Board", "beginner":"Beginner", "intermediate":"Intermediate", "expert":"Expert", "rounds":"Rounds", "mine_estimate":"Mine estimate",
		"foresight":"Foresight", "no_flag":"No flag", "intact":"Intact", "lost":"Lost", "reveal":"Reveal", "flag":"Flag",
		"drag":"Drag", "new_board":"New Board", "assignments":"Assignments", "rules":"Rules", "pause":"Pause", "selected":"Selected",
		"return":"Return", "claimed":"Claimed", "unclaimed":"Unclaimed",
		"facts":["Reveal opens a covered cell.", "Flag marks or unmarks a covered cell.", "Reveal on an open number may Chord when adjacent Flags match.", "Drag moves the worksheet without acting."],
		"requirements":["Complete Beginner", "Complete Intermediate", "Complete Expert", "Finish with No flag", "Finish with Foresight", "Perfect — Beginner", "Perfect — Intermediate", "Perfect — Expert", "Complete all three tiers"],
	},
	"zh-CN": {
		"board":"棋盘", "beginner":"初级", "intermediate":"中级", "expert":"高级", "rounds":"回合", "mine_estimate":"地雷估计",
		"foresight":"远见", "no_flag":"无旗", "intact":"完好", "lost":"已失", "reveal":"揭开", "flag":"标旗",
		"drag":"拖动", "new_board":"新棋盘", "assignments":"任务", "rules":"规则", "pause":"暂停", "selected":"已选择",
		"return":"返回", "claimed":"已领取", "unclaimed":"未领取",
		"facts":["揭开会打开一个覆盖的格子。", "标旗会在覆盖的格子上放置或移除旗帜。", "在已打开的数字上使用揭开，相邻旗帜数与数字相符时可以和弦展开。", "拖动会移动工作表，不对格子执行操作。"],
		"requirements":["完成初级", "完成中级", "完成高级", "以无旗完成", "以远见完成", "完美 — 初级", "完美 — 中级", "完美 — 高级", "完成全部三个难度"],
	},
	"zh-HK": {
		"board":"棋盤", "beginner":"初級", "intermediate":"中級", "expert":"高級", "rounds":"回合", "mine_estimate":"地雷估計",
		"foresight":"遠見", "no_flag":"無旗", "intact":"完好", "lost":"已失", "reveal":"揭開", "flag":"標旗",
		"drag":"拖動", "new_board":"新棋盤", "assignments":"任務", "rules":"規則", "pause":"暫停", "selected":"已選擇",
		"return":"返回", "claimed":"已領取", "unclaimed":"未領取",
		"facts":["揭開會打開一個覆蓋的格子。", "標旗會在覆蓋的格子上放置或移除旗幟。", "在已打開的數字上使用揭開，相鄰旗幟數與數字相符時可以和弦展開。", "拖動會移動工作表，不對格子執行操作。"],
		"requirements":["完成初級", "完成中級", "完成高級", "以無旗完成", "以遠見完成", "完美 — 初級", "完美 — 中級", "完美 — 高級", "完成全部三個難度"],
	},
	"ja": {
		"board":"盤面", "beginner":"初級", "intermediate":"中級", "expert":"上級", "rounds":"ラウンド", "mine_estimate":"地雷の推定数",
		"foresight":"先読み", "no_flag":"旗なし", "intact":"維持", "lost":"喪失", "reveal":"開く", "flag":"旗",
		"drag":"ドラッグ", "new_board":"新しい盤面", "assignments":"課題", "rules":"ルール", "pause":"一時停止", "selected":"選択中",
		"return":"戻る", "claimed":"受取済み", "unclaimed":"未受取",
		"facts":["開く操作で、閉じたマスを開きます。", "旗の操作で、閉じたマスに旗を立てたり外したりします。", "開いた数字で「開く」を使うと、隣の旗の数が数字と同じなら周囲も開きます。", "ドラッグで盤面を移動します。マスは操作しません。"],
		"requirements":["初級をクリア", "中級をクリア", "上級をクリア", "旗なしでクリア", "先読みでクリア", "パーフェクト — 初級", "パーフェクト — 中級", "パーフェクト — 上級", "全3難度をクリア"],
	},
	"ko": {
		"board":"보드", "beginner":"초급", "intermediate":"중급", "expert":"고급", "rounds":"라운드", "mine_estimate":"지뢰 추정 수",
		"foresight":"예지", "no_flag":"깃발 없음", "intact":"유지", "lost":"상실", "reveal":"열기", "flag":"깃발",
		"drag":"드래그", "new_board":"새 보드", "assignments":"과제", "rules":"규칙", "pause":"일시 정지", "selected":"선택됨",
		"return":"돌아가기", "claimed":"수령함", "unclaimed":"미수령",
		"facts":["열기로 닫힌 칸을 열어요.", "깃발로 닫힌 칸에 깃발을 세우거나 제거해요.", "열린 숫자에서 열기: 주변 깃발 수가 숫자와 같으면 이웃 칸도 열려요.", "드래그는 보드만 이동하며 칸을 조작하지 않아요."],
		"requirements":["초급 완료", "중급 완료", "고급 완료", "깃발 없이 완료", "예지로 완료", "완벽 — 초급", "완벽 — 중급", "완벽 — 고급", "세 난도 모두 완료"],
	},
}

const COMPACT_METRICS := {
	"ja": {"rounds": "回数", "mine_estimate": "推定数"},
	"ko": {"mine_estimate": "추정 수"},
}

static func get_copy(locale: String) -> Dictionary:
	return COPY.get(locale.replace("_","-"),{})

