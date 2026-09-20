extends RefCounted

const COPY := {
	"en": {"board":"Board","beginner":"Beginner","intermediate":"Intermediate","expert":"Expert","rounds":"Rounds","mine_estimate":"Mine estimate","foresight":"Foresight","no_flag":"No flag","intact":"Intact","lost":"Lost","reveal":"Reveal","flag":"Flag","drag":"Drag","new_board":"New Board","assignments":"Assignments","rules":"Rules","pause":"Pause","selected":"Selected"},
	"zh-CN": {"board":"棋盘","beginner":"初级","intermediate":"中级","expert":"高级","rounds":"回合","mine_estimate":"地雷估计","foresight":"远见","no_flag":"无旗","intact":"完好","lost":"已失","reveal":"揭开","flag":"标旗","drag":"拖动","new_board":"新棋盘","assignments":"任务","rules":"规则","pause":"暂停","selected":"已选择"},
	"zh-HK": {"board":"棋盤","beginner":"初級","intermediate":"中級","expert":"高級","rounds":"回合","mine_estimate":"地雷估計","foresight":"遠見","no_flag":"無旗","intact":"完好","lost":"已失","reveal":"揭開","flag":"標旗","drag":"拖動","new_board":"新棋盤","assignments":"任務","rules":"規則","pause":"暫停","selected":"已選擇"},
}

static func get_copy(locale: String) -> Dictionary:
	return COPY.get(locale.replace("_","-"),{}).duplicate(true)

