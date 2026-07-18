extends SceneTree

const STRICT_JSON := preload("res://tools/evidence/EvidenceValidator.gd")
const VALIDATOR := preload("res://tools/docs/DocValidator.gd")
const GENERATOR := preload("res://tools/docs/DocIndexGenerator.gd")

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
	var result := VALIDATOR.new().validate_tree("res://prompt_docs", _load_snapshot_or_quit())
	if not result.ok: printerr(JSON.stringify(result.errors)); quit(1); return
	print("DOC_VALIDATION: PASS packets=%d" % result.packets.size())
	quit(0)
