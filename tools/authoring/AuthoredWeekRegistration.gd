extends RefCounted
## Native compilation remains the authority for text, native positions and hashes.
const SOURCE_PATH := "res://data/manifests/authored_week_source.json"
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const BASE := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")

static func prepare() -> Dictionary:
	var parsed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(SOURCE_PATH))
	if not parsed.ok: return parsed
	var source: Dictionary = parsed.value
	var prepared: Dictionary = BASE.prepare()
	if not prepared.ok: return prepared
	var bundle: Dictionary = prepared.value.registration
	bundle.entry_manifest.entries = []
	bundle.context_registry.schemas = []
	bundle.ids_registry.lines = []
	bundle.ids_registry.signals = []
	bundle.caption_registry.entries = []
	bundle.scene_programme.entries = []
	bundle.scene_programme["story_days"] = {}
	bundle.targets = []
	bundle.audio_catalogue.bindings = []
	bundle.challenges = source.challenges.duplicate(true)
	bundle.board_profiles = [{"board_profile_id": "week.canonical_solo", "board_kind": "solo_challenge",
		"difficulty_id": "canonical_solo", "width": 18, "height": 18, "base_mine_count": 36,
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1", "capability_policy_id": "owned_inventory_v1"}]
	var payloads := {"history.line.witness": ["entry_id", "line_id", "playback_token", "receipt_id"],
		"passage.start": ["passage_id"], "passage.finish": ["passage_id"],
		"scene.transition": ["target_id"], "thought.pass": ["opportunity_id", "yes_target_id", "pass_target_id"],
		"thought.options": ["opportunity_id", "options", "pass_target_id"],
		"challenge.playable": ["challenge_id"], "challenge.end": ["challenge_id"],
		"challenge.recall": ["challenge_id", "never_started_target_id", "unfinished_target_id", "won_target_id", "lost_target_id", "perfect_target_id"]}
	var signal_ids: Array = payloads.keys()
	signal_ids.sort()
	for signal_id: String in signal_ids:
		bundle.ids_registry.signals.append({"signal_id": signal_id, "payload_fields": payloads[signal_id]})
	var ids: Array = []
	for spec: Dictionary in source.entries: ids.append(spec.entry_id)
	for spec: Dictionary in source.entries:
		var id: String = spec.entry_id
		if typeof(spec.get("story_day")) != TYPE_INT or spec.story_day < 1 or spec.story_day > 7:
			return {"ok": false, "code": "authored_story_day_invalid"}
		bundle.scene_programme.story_days[id] = spec.story_day
		var compiled: Dictionary = ADAPTER.compile_scene_programme(spec.path, id, ids, spec.markers)
		if not compiled.ok: return compiled
		if spec.role != "scene": return {"ok": false, "code": "authored_scene_role_required"}
		var grants: Array = ["history.line.witness"]
		for marker: Dictionary in spec.markers:
			if marker.kind not in grants: grants.append(marker.kind)
		grants.sort()
		var entry: Dictionary = {
			"entry_id": id, "role": "scene", "allowed_signals": grants,
			"atom_namespace": "atom." + id, "line_namespace": "line." + id, "content_version": 1,
			"context_schema_id": "context.scene." + id + ".v1", "visual_ids": {"required": [], "optional": []},
			"presentation_signature_schema": {"schema_version": 1, "fields": {}}}
		entry.locators = {"en": {"path": spec.path, "label": id}}
		bundle.entry_manifest.entries.append(entry)
		bundle.context_registry.schemas.append({
			"entry_id": id, "schema_id": entry.context_schema_id, "schema_version": 1,
			"fields": {"entry_id": {"const": id}, "entry_role": {"const": "scene"},
				"occurrence_id": "id", "admission_receipt_id": "id"}})
		var lines: Array = []
		for event: Dictionary in compiled.value.events:
			if event.kind != "text": continue
			var index: int = lines.size()
			if index >= spec.lines.size() or event.line_id != spec.lines[index].line_id or event.text != spec.lines[index].text:
				return {"ok": false, "code": "authored_caption_mismatch", "entry_id": id, "index": index}
			bundle.ids_registry.lines.append({"line_id": event.line_id, "owning_entry_id": id})
			lines.append({"beat_id": "beat." + event.line_id, "line_id": event.line_id, "text": event.text, "revision": "1"})
		if lines.size() != spec.lines.size(): return {"ok": false, "code": "authored_caption_count_mismatch", "entry_id": id}
		bundle.caption_registry.entries.append({"entry_id": id, "lines": lines})
		bundle.scene_programme.entries.append({"entry_id": id, "content_version": 1,
			"content_sha256": compiled.value.content_sha256, "program_sha256": compiled.value.program_sha256, "markers": spec.markers})
		bundle.targets.append({"target_id": "target." + id, "target": {"kind": "scene",
			"entry_id": id, "label": id, "content_version": 1, "program_sha256": compiled.value.program_sha256}})
		bundle.audio_catalogue.bindings.append({"entry_id": id, "plan_id": BASE.MUSIC_PLAN_ID})
	bundle.entry_manifest.entry_count = ids.size()
	for rows: Array in [bundle.entry_manifest.entries, bundle.context_registry.schemas, bundle.caption_registry.entries, bundle.scene_programme.entries]:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	bundle.targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.target_id < b.target_id)
	bundle.challenges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.challenge_id < b.challenge_id)
	bundle.audio_catalogue.bindings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	var checked: Dictionary = MANIFEST.validate_scene_registration(bundle)
	if not checked.ok: return checked
	return {"ok": true, "value": {"registration": bundle, "first_target_id": "target." + source.first_entry_id}}
