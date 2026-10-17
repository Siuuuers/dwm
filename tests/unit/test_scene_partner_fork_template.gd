extends "res://addons/gut/test.gd"
## Content compilation only. No installed registration, live choice or persistence proof.
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const STORY := "res://tests/fixtures/dialogic/scene_partner_fork_template.dtl"
const ENTRIES := [
	"scene.test.partner.shared",
	"scene.test.partner.sylvia",
	"scene.test.partner.lavinia",
]
const LINES := [
	["line.scene.test.partner.shared.before", "line.scene.test.partner.shared.offer"],
	["line.scene.test.partner.sylvia.after"],
	["line.scene.test.partner.lavinia.after"],
]

func test_replaceable_segments_compile_with_isolated_caption_identities() -> void:
	for index: int in ENTRIES.size():
		var compiled: Dictionary = ADAPTER.compile_scene_programme(STORY, ENTRIES[index], ENTRIES)
		assert_true(compiled.get("ok", false), str(compiled))
		if not compiled.get("ok", false): continue
		var caption_ids: Array = []
		for event: Dictionary in compiled.value.events:
			if event.kind == "text": caption_ids.append(event.line_id)
		assert_eq(caption_ids, LINES[index], "No continuation leaks into a different entry.")
		assert_eq(compiled.value.nodes.back().kind, "completion")
		for node: Dictionary in compiled.value.nodes:
			assert_true(node.kind in ["caption", "completion"], "Uninstalled content must not dispatch effects.")
