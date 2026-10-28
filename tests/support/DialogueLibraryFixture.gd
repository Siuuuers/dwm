extends RefCounted
## Synthetic library bindings only; never part of production story registration.
const CATALOGUE := preload("res://scripts/narrative/DialogueLibraryCatalogue.gd")
const WITNESS := preload("res://scripts/profile/CaptionWitnessLedger.gd")
const CHECKPOINT := "TEST.library.reached"
const UNREACHED := "TEST.library.unreached"
const SHORT := "TEST hidden short."
const LONG := "TEST hidden long dialogue."

static func beat(variant: String = "read", thought: bool = false) -> Dictionary:
	return {"beat_id": "TEST.library.thought" if thought else "TEST.library.caption",
		"line_id": "TEST.library.thought.line" if thought else "TEST.library.caption.line",
		"owning_entry_id": "TEST.library.entry", "presentation_signature": {"variant_id": variant, "revision": "TEST-r1"}}

static func key(value: Dictionary) -> String:
	return WITNESS.describe(value).value.witness_id

static func registry(value: Dictionary) -> Dictionary:
	return {"kind": "narrative_caption_registry", "schema_version": 1, "beats": [value]}

static func passages() -> Array:
	return [{"id": CHECKPOINT, "title": {"en": "TEST reached passage", "zh_HK": "測試已讀段落"}, "entries": [
		{"beat": beat(), "kind": "caption", "text": {"en": "TEST read caption.", "zh_HK": "測試已讀對白。"}, "requirements": {}},
		{"beat": beat("read", true), "kind": "thought", "text": {"en": "TEST unseen thought."}, "requirements": {}},
		{"beat": beat("short"), "kind": "caption", "text": {"en": SHORT}, "requirements": {"all": [{"label": "choice"}, {"any": [{"label": "win"}, {"label": "clean"}]}]}},
		{"beat": beat("long"), "kind": "caption", "text": {"en": LONG.repeat(80)}, "requirements": {"all": [{"label": "choice"}, {"any": [{"label": "win"}, {"label": "clean"}]}]}}
	]}, {"id": UNREACHED, "title": {"en": "TEST unseen checkpoint title"}, "entries": [
		{"beat": beat("unreached"), "kind": "caption", "text": {"en": "TEST unseen checkpoint text."}, "requirements": {}}
	]}]

static func install() -> Dictionary:
	var registered: Array = []
	for passage: Dictionary in passages():
		for entry: Dictionary in passage.entries: registered.append(entry.beat)
	return CATALOGUE.configure(passages(), registered, {CHECKPOINT: {}, UNREACHED: {}}, {
		"choice": {"en": "Choose to help", "zh_HK": "選擇幫忙"},
		"win": {"en": "Win the Challenge", "zh_HK": "贏得挑戰"},
		"clean": {"en": "Finish without a mistake", "zh_HK": "無失誤完成"}})

static func discovery() -> Dictionary:
	return {"checkpoints": [CHECKPOINT], "witnesses": {key(beat()): true}}
