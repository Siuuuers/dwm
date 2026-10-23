extends "res://addons/gut/test.gd"

const STRICT := preload("res://tools/evidence/EvidenceValidator.gd")
const INVENTORY_PATH := "res://evidence/phase_2r/legacy/legacy_heading_inventory.v1.json"
const BASELINE_PATH := "res://evidence/phase_2r/baseline.json"
const DISPOSITION_PATH := "res://evidence/phase_2r/documentation/legacy_disposition.json"
const INDEX_PATH := "res://prompt_docs/INDEX.md"
const PRESERVED := ["CLAUDE.md", "dialogic fx.md"]
## baseline.json is an immutable historical capture. Sealing its own digest here means any rewrite
## of the evidence -- including a well-meaning one that "fixes" a drifted hash -- fails loudly.
const SEALED_BASELINE_SHA256 := "0a9e3354750471a70639028f3d1154a0885586b80f285835d8d059a1d10f8bb6"

func _read(path: String) -> Dictionary:
	var result := STRICT._parse_utf8_file(path)
	assert_true(result.errors.is_empty(), JSON.stringify(result.errors))
	return result.value if result.errors.is_empty() else {}

func test_legacy_disposition_bijection_and_preservation() -> void:
	var inventory := _read(INVENTORY_PATH)
	var baseline := _read(BASELINE_PATH)
	var disposition := _read(DISPOSITION_PATH)
	assert_eq(disposition.get("inventory_sha256"), baseline.legacy_heading_inventory.sha256)
	var source_by_path := {}
	for source: Dictionary in baseline.source_archive:
		source_by_path[source.path] = source
	var heading_by_id := {}
	for heading: Dictionary in inventory.headings:
		heading_by_id[heading.heading_id] = heading
	var seen := {}
	var record_source_paths := {}
	var represented_dirty_sources := {}
	var index_text := FileAccess.get_file_as_string(INDEX_PATH)
	for record: Dictionary in disposition.records:
		assert_true(heading_by_id.has(record.heading_id), "unknown heading " + str(record.heading_id))
		assert_false(seen.has(record.heading_id), "duplicate heading " + str(record.heading_id))
		seen[record.heading_id] = true
		record_source_paths[record.source_path] = true
		if not heading_by_id.has(record.heading_id): continue
		var heading: Dictionary = heading_by_id[record.heading_id]
		assert_eq(record.source_path, heading.source_path)
		assert_eq(record.source_sha256, heading.source_sha256)
		assert_has(["migrated", "retired", "rejected_as_incorrect"], record.disposition)
		assert_false(str(record.reason_code).is_empty())
		assert_false(str(record.reason).is_empty())
		assert_false(record.target_requirement_ids.is_empty())
		for requirement_id: String in record.target_requirement_ids:
			assert_true(index_text.contains("| `%s` |" % requirement_id), "unknown requirement " + requirement_id)
		if record.disposition in ["migrated", "rejected_as_incorrect"]:
			represented_dirty_sources[record.source_path] = true
	assert_eq(seen.size(), heading_by_id.size())
	for heading_id: Variant in heading_by_id.keys(): assert_true(seen.has(heading_id), "missing heading " + str(heading_id))
	var file_seen := {}
	for record: Dictionary in disposition.file_records:
		file_seen[record.source_path] = int(file_seen.get(record.source_path, 0)) + 1
		assert_true(source_by_path.has(record.source_path))
		if source_by_path.has(record.source_path): assert_eq(record.source_sha256, source_by_path[record.source_path].sha256)
	for zero: Dictionary in inventory.zero_heading_documents:
		assert_eq(int(file_seen.get(zero.path, 0)), 1, "zero-heading file disposition " + zero.path)
	for source: Dictionary in baseline.source_archive:
		if not str(source.working_tree_patch_base64).is_empty():
			assert_true(represented_dirty_sources.has(source.path), "dirty source not represented " + source.path)
	# Phase 2R preservation is a HISTORICAL claim: these files were untouched BY the migration,
	# across the finite interval capture 825ebdf2 -> completion 6d304eac. It is NOT a claim that
	# they are unchangeable forever. Reading their CURRENT bytes turned "unchanged during Phase 2R"
	# into "unchangeable in perpetuity", so a later author edit to CLAUDE.md broke a historical
	# gate it could not logically falsify. Current bytes and current existence are therefore
	# deliberately NOT checked here; the interval itself is proven by the evidence gate's git
	# ancestry and diff check, and any present-day requirement on CLAUDE.md belongs to a separate
	# project contract (plan-author ruling, 2026-08-10).
	assert_eq(FileAccess.get_sha256(BASELINE_PATH), SEALED_BASELINE_SHA256,
		"baseline.json is an immutable historical capture and must never be rewritten")
	var preserved_paths := {}
	for preserved: Dictionary in baseline.preserved_outside_authority:
		assert_has(PRESERVED, preserved.path)
		assert_false(preserved_paths.has(preserved.path), "duplicate preserved path " + str(preserved.path))
		preserved_paths[preserved.path] = true
		assert_false(source_by_path.has(preserved.path), "preserved path is not an authority source")
		assert_false(record_source_paths.has(preserved.path), "preserved path has no disposition record")
		assert_false(file_seen.has(preserved.path), "preserved path has no file disposition record")
		assert_false(index_text.contains(str(preserved.path)), "preserved path never appears in INDEX.md")
	assert_eq(preserved_paths.size(), PRESERVED.size(),
		"the preserved set is exactly %s, each once" % str(PRESERVED))
	print("LEGACY_DISPOSITION: PASS records=%d" % (disposition.records.size() + disposition.file_records.size()))
