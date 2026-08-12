extends SceneTree

const STRICT_JSON := preload("res://tools/evidence/EvidenceValidator.gd")
const VALIDATOR := preload("res://tools/docs/DocValidator.gd")
const GENERATOR := preload("res://tools/docs/DocIndexGenerator.gd")
const DESIGN_REGISTRY := preload("res://tools/docs/DesignAuthorityRegistry.gd")

func _load_snapshot_or_quit() -> Array[Dictionary]:
	var values: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--beads-snapshot="): values.append(argument.trim_prefix("--beads-snapshot="))
	if values.size() != 1 or not FileAccess.file_exists(values[0]):
		printerr("DOC_BEAD_SNAPSHOT_REQUIRED"); quit(2); return []
	var bytes := FileAccess.get_file_as_bytes(values[0])
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		printerr("DOC_BEAD_SNAPSHOT_INVALID: UTF-8"); quit(2); return []
	var parsed := STRICT_JSON.parse_strict_text(text)
	if not parsed.ok or typeof(parsed.value) != TYPE_ARRAY or parsed.value.is_empty():
		printerr("DOC_BEAD_SNAPSHOT_INVALID: " + JSON.stringify(parsed.errors)); quit(2); return []
	var typed: Array[Dictionary] = []
	for value: Variant in parsed.value:
		if typeof(value) != TYPE_DICTIONARY:
			printerr("DOC_BEAD_SNAPSHOT_INVALID: non-object record"); quit(2); return []
		typed.append(value)
	return typed

func _init() -> void:
	var snapshot := _load_snapshot_or_quit()
	var design_authority := DESIGN_REGISTRY.new().validate("res://", "res://prompt_docs/metadata/design_authority_registry.v1.json")
	if not design_authority.ok: printerr(JSON.stringify(design_authority.errors)); quit(1); return
	var validator := VALIDATOR.new()
	var result := validator.validate_tree("res://prompt_docs", snapshot)
	result.errors = result.errors.filter(func(error: String) -> bool: return not error.begins_with("DOC_INDEX_DRIFT:"))
	result.ok = result.errors.is_empty()
	if not result.ok: printerr(JSON.stringify(result.errors)); quit(1); return
	var generator := GENERATOR.new()
	var error := generator.write_index("res://prompt_docs/INDEX.md", generator.render(result))
	if error != OK: printerr("DOC_INDEX_WRITE: %d" % error); quit(1); return
	var verified := validator.validate_tree("res://prompt_docs", snapshot)
	if not verified.ok: printerr(JSON.stringify(verified.errors)); quit(1); return
	print("DOC_INDEX: PASS")
	quit(0)
