extends RefCounted

## Provisional audience-facing record titles; semantic classifications stay private.
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const TITLES := {
	"ending.alone": ["A Quiet Morning", "安静的清晨", "安靜的清晨"],
	"ending.priscilla.sweet": ["A Place Beside You", "你身旁的位置", "你身旁的位置"],
	"ending.priscilla.dark": ["A Promise to Keep", "守住的约定", "守住的約定"],
	"ending.priscilla.observer": ["What Remains", "留下的事物", "留下的事物"],
	"ending.lavinia.sweet": ["Open Windows", "敞开的窗", "敞開的窗"],
	"ending.lavinia.dark": ["One Last Key", "最后一把钥匙", "最後一把鑰匙"],
	"ending.lavinia.observer": ["Between the Lines", "字里行间", "字裡行間"],
	"ending.sylvia.sweet": ["Come Home", "回家吧", "回家吧"],
	"ending.sylvia.dark": ["Stay a Little Longer", "再留一会儿", "再留一會兒"],
	"ending.sylvia.special": ["Before the Dawn", "天亮之前", "天亮之前"],
	"ending.priscilla_lavinia.sweet": ["Their Shared Way", "同行的路", "同行的路"],
	"ending.priscilla_lavinia.dark": ["A Door for Two", "两个人的门", "兩個人的門"],
	"ending.priscilla_lavinia.observer": ["Another Side", "另一面", "另一面"],
}

## Provisional descriptions use only the public Day 7 actions in
## story/library/03-seven-day-plot-material-library.md (Day 7 / Day 7 Eligibility).
## Unwritten outcomes, exceptional/pair details and optional media stay absent.
const RECORD_DETAILS := {
	"ending.alone": {"sentence": ["Angela completes the final observation.",
		"安吉拉完成最后一次观测。", "安吉拉完成最後一次觀測。"]},
	"ending.priscilla.sweet": {"sentence": ["Angela attends the closing reception.",
		"安吉拉参加闭幕招待会。", "安吉拉出席閉幕招待會。"]},
	"ending.priscilla.dark": {"sentence": ["Angela attends the closing reception.",
		"安吉拉参加闭幕招待会。", "安吉拉出席閉幕招待會。"]},
	"ending.lavinia.sweet": {"sentence": ["Angela waits by the stage door.",
		"安吉拉在舞台门外等候。", "安吉拉在舞台門外等候。"]},
	"ending.lavinia.dark": {"sentence": ["Angela waits by the stage door.",
		"安吉拉在舞台门外等候。", "安吉拉在舞台門外等候。"]},
	"ending.sylvia.sweet": {"sentence": ["Angela collects what was found.",
		"安吉拉接收找到的物品。", "安吉拉接收找到的物品。"]},
	"ending.sylvia.dark": {"sentence": ["Angela collects what was found.",
		"安吉拉接收找到的物品。", "安吉拉接收找到的物品。"]},
}
const PRESENTATION_DETAILS := []

var valid := true
var _error: StringName = &""
var _records: Dictionary = {}
var _presentations: Dictionary = {}

func _init(details: Dictionary = RECORD_DETAILS, overrides: Array = PRESENTATION_DETAILS) -> void:
	_build(details.duplicate(true), overrides.duplicate(true))

static func title(ending_id: String, locale: String) -> String:
	ending_id = preload("res://scripts/domain/narrative/PresentationSignature.gd").semantic_ending_id(ending_id)
	if not TITLES.has(ending_id): return ""
	var language := locale.replace("_", "-")
	return TITLES[ending_id][2 if language == "zh-HK" else (1 if language.begins_with("zh") else 0)]

func projection(record_id: String, signature_id: String, locale: String) -> Dictionary:
	var result := {"sentence": "", "media_asset_id": ""}
	if not valid: return result
	var identity := SIGNATURE.semantic_ending_id(record_id)
	if _records.has(identity): _apply(result, _records[identity], locale)
	var override: Variant = _presentations.get(signature_id)
	if override is Dictionary and override.record_id == identity:
		_apply(result, override, locale)
	return result.duplicate(true)

func _build(details: Dictionary, overrides: Array) -> void:
	var ids: Array = details.keys()
	for raw_id: Variant in ids:
		if not raw_id is String or raw_id.is_empty():
			_invalidate(&"invalid_record_id")
			return
		var record_id := SIGNATURE.semantic_ending_id(raw_id)
		if record_id != raw_id or not _known_record(record_id) or _records.has(record_id) \
				or not details[raw_id] is Dictionary or not _valid_details(details[raw_id]):
			_invalidate(&"invalid_record_details")
			return
		_records[record_id] = details[raw_id].duplicate(true)
	for value: Variant in overrides:
		if not value is Dictionary or not value.has("signature") \
				or not _exact_subset(value, ["signature", "sentence", "media_asset_id"]) \
				or not value.signature is Dictionary:
			_invalidate(&"invalid_presentation_details")
			return
		var details_only: Dictionary = value.duplicate(true)
		var signature: Dictionary = details_only.signature
		details_only.erase("signature")
		if not _valid_details(details_only):
			_invalidate(&"invalid_presentation_details")
			return
		var checked: Dictionary = SIGNATURE.validate(signature)
		if not checked.get("ok", false):
			_invalidate(&"invalid_presentation_signature")
			return
		var signature_id := str(checked.value.signature_id)
		if _presentations.has(signature_id):
			_invalidate(&"duplicate_presentation_signature")
			return
		var entry: Dictionary = SIGNATURE.entry_record(signature.entry_id)
		if not entry.get("ok", false):
			_invalidate(&"invalid_presentation_signature")
			return
		var ending: Variant = entry.value.get("ending_id")
		details_only["record_id"] = SIGNATURE.semantic_ending_id(str(ending)) \
			if ending != null else str(signature.entry_id)
		if not _known_record(details_only.record_id):
			_invalidate(&"invalid_presentation_record")
			return
		_presentations[signature_id] = details_only

func _known_record(record_id: String) -> bool:
	if TITLES.has(record_id): return true
	var parts := record_id.split(".")
	if parts.size() != 5 or parts[0] != "dating": return false
	var entry := SIGNATURE.entry_record(record_id)
	return entry.get("ok", false) and entry.value.get("ending_id") == null \
		and entry.value.get("role") in ["solo_pre_challenge", "solo_post_challenge",
			"pair_pre_challenge_scene", "pair_post_challenge_scene"]

func _valid_details(value: Dictionary) -> bool:
	if not _exact_subset(value, ["sentence", "media_asset_id"]): return false
	if value.has("media_asset_id") and not value.media_asset_id is String: return false
	if value.has("sentence"):
		if not value.sentence is Array or value.sentence.size() != 3: return false
		for copy: Variant in value.sentence:
			if not copy is String: return false
	return true

func _exact_subset(value: Dictionary, allowed: Array) -> bool:
	for field: Variant in value:
		if field not in allowed: return false
	return true

func _apply(target: Dictionary, source: Dictionary, locale: String) -> void:
	if source.has("media_asset_id"): target.media_asset_id = source.media_asset_id
	if source.has("sentence"):
		var language := locale.replace("_", "-")
		target.sentence = source.sentence[2 if language == "zh-HK" else (1 if language.begins_with("zh") else 0)]

func _invalidate(code: StringName) -> void:
	valid = false
	_error = code
	_records.clear()
	_presentations.clear()
