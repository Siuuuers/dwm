extends RefCounted

## Provisional audience-facing record titles; semantic classifications stay private.
const TITLES := {
	"ending.alone": ["A Quiet Morning", "安静的清晨"],
	"ending.priscilla.sweet": ["A Place Beside You", "你身旁的位置"],
	"ending.priscilla.dark": ["A Promise to Keep", "守住的约定"],
	"ending.priscilla.observer": ["What Remains", "留下的事物"],
	"ending.lavinia.sweet": ["Open Windows", "敞开的窗"],
	"ending.lavinia.dark": ["One Last Key", "最后一把钥匙"],
	"ending.lavinia.observer": ["Between the Lines", "字里行间"],
	"ending.sylvia.sweet": ["Come Home", "回家吧"],
	"ending.sylvia.dark": ["Stay a Little Longer", "再留一会儿"],
	"ending.sylvia.special": ["Before the Dawn", "天亮之前"],
	"ending.priscilla_lavinia.sweet": ["Their Shared Way", "同行的路"],
	"ending.priscilla_lavinia.dark": ["A Door for Two", "两个人的门"],
	"ending.priscilla_lavinia.observer": ["Another Side", "另一面"],
}

static func title(ending_id: String, locale: String) -> String:
	ending_id = preload("res://scripts/domain/narrative/PresentationSignature.gd").semantic_ending_id(ending_id)
	if not TITLES.has(ending_id): return ""
	return TITLES[ending_id][1 if locale.begins_with("zh") else 0]
