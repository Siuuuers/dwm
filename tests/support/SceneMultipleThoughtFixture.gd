extends RefCounted
## TEST-only multiple thoughts; reuse the qualified partner fixture's owners.
const PARTNER := preload("res://tests/support/ScenePartnerForkFixture.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const STORY := "res://tests/fixtures/dialogic/scene_multiple_thoughts.dtl"

static func bundle() -> Dictionary:
	var prepared: Dictionary = PARTNER.bundle()
	if not prepared.ok: return prepared
	var value: Dictionary = prepared.value
	var before := "scene.test.partner.lavinia"
	var after := "scene.test.partner.benchmark"
	for table: Array in [value.entry_manifest.entries, value.context_registry.schemas,
			value.caption_registry.entries, value.scene_programme.entries]:
		for row: Dictionary in table.duplicate():
			if row.entry_id == before:
				# All replacements are deterministic fixture IDs, not runtime parsing.
				var cloned: Dictionary = STRICT.parse_object(JSON.stringify(row).replace(before, after))
				if not cloned.ok: return cloned
				table.append(cloned.value)
		for row: Dictionary in table:
			if row.entry_id == after and row.has("lines"):
				row.lines[0].text = "TEST default Benchmark."
		table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	value.entry_manifest.entry_count += 1
	value.ids_registry.lines.append({"line_id": "line." + after + ".after", "owning_entry_id": after})
	value.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	for row: Dictionary in value.targets.duplicate():
		if row.target.entry_id == before:
			var cloned: Dictionary = STRICT.parse_object(JSON.stringify(row).replace("partner.lavinia", "partner.benchmark"))
			if not cloned.ok: return cloned
			value.targets.append(cloned.value)
	value.targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.target_id < b.target_id)
	value.ids_registry.signals[1] = {"signal_id": "thought.options", "payload_fields": ["opportunity_id", "options", "pass_target_id"]}
	var labels: Array = []
	for entry: Dictionary in value.entry_manifest.entries:
		labels.append(entry.entry_id)
		entry.locators.en.path = STORY
		if entry.entry_id == "scene.test.partner.shared": entry.allowed_signals = ["history.line.witness", "thought.options"]
	for row: Dictionary in value.scene_programme.entries:
		if row.entry_id == "scene.test.partner.shared":
			row.markers[0].kind = "thought.options"
			row.markers[0].payload = {"opportunity_id": "TEST.partner", "pass_target_id": "partner.benchmark", "options": [
				{"choice_id": "first", "text": "Choose the first continuation.", "target_id": "partner.sylvia"},
				{"choice_id": "second", "text": "Choose the second continuation.", "target_id": "partner.lavinia"}]}
		var compiled: Dictionary = PARTNER.ADAPTER.compile_scene_programme(STORY, row.entry_id, labels, row.markers)
		if not compiled.ok: return compiled
		row.content_sha256 = compiled.value.content_sha256
		row.program_sha256 = compiled.value.program_sha256
		for target: Dictionary in value.targets:
			if target.target.entry_id == row.entry_id: target.target.program_sha256 = compiled.value.program_sha256
	return {"ok": true, "value": value}

static func install() -> Dictionary:
	var built := bundle()
	if not built.ok: return built
	return PARTNER.MANIFEST.configure_test_scene_registration(built.value)
