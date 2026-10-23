extends RefCounted

const COPY := {
	"en": {"board":"Board","beginner":"Beginner","intermediate":"Intermediate","expert":"Expert","rounds":"Rounds","mine_estimate":"Mine estimate","foresight":"Foresight","no_flag":"No flag","intact":"Intact","lost":"Lost","reveal":"Reveal","flag":"Flag","drag":"Drag","new_board":"New Board","assignments":"Assignments","rules":"Rules","pause":"Pause","selected":"Selected"},
	"zh-CN": {"board":"棋盘","beginner":"初级","intermediate":"中级","expert":"高级","rounds":"回合","mine_estimate":"地雷估计","foresight":"远见","no_flag":"无旗","intact":"完好","lost":"已失","reveal":"揭开","flag":"标旗","drag":"拖动","new_board":"新棋盘","assignments":"任务","rules":"规则","pause":"暂停","selected":"已选择"},
	"zh-HK": {"board":"棋盤","beginner":"初級","intermediate":"中級","expert":"高級","rounds":"回合","mine_estimate":"地雷估計","foresight":"遠見","no_flag":"無旗","intact":"完好","lost":"已失","reveal":"揭開","flag":"標旗","drag":"拖動","new_board":"新棋盤","assignments":"任務","rules":"規則","pause":"暫停","selected":"已選擇"},
	"ja": {"board": "盤面", "beginner": "初級", "intermediate": "中級", "expert": "上級", "rounds": "ラウンド", "mine_estimate": "地雷の推定数", "foresight": "先読み", "no_flag": "旗なし", "intact": "維持", "lost": "喪失", "reveal": "開く", "flag": "旗", "drag": "ドラッグ", "new_board": "新しい盤面", "assignments": "課題", "rules": "ルール", "pause": "一時停止", "selected": "選択中"},
	"ko": {"board": "보드", "beginner": "초급", "intermediate": "중급", "expert": "고급", "rounds": "라운드", "mine_estimate": "지뢰 추정 수", "foresight": "예지", "no_flag": "깃발 없음", "intact": "유지", "lost": "상실", "reveal": "열기", "flag": "깃발", "drag": "드래그", "new_board": "새 보드", "assignments": "과제", "rules": "규칙", "pause": "일시 정지", "selected": "선택됨"},
}

# Short metric headings fit the fixed bays; accessibility retains COPY in full.
const COMPACT_METRICS := {
	"ja": {"rounds": "回数", "mine_estimate": "推定数"},
	"ko": {"mine_estimate": "추정 수"},
}

static func get_copy(locale: String) -> Dictionary:
	return COPY.get(locale.replace("_","-"),{}).duplicate(true)

