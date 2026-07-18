extends SceneTree

const VALIDATOR := preload("res://tools/evidence/EvidenceValidator.gd")

func _init() -> void:
	var evidence_values: Array[String] = []
	var schema_values: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence_values.append(argument.trim_prefix("--evidence="))
		elif argument.begins_with("--schema="): schema_values.append(argument.trim_prefix("--schema="))
		else: printerr("EVIDENCE_ARGUMENT_UNKNOWN: " + argument); quit(2); return
	if evidence_values.size() != 1 or schema_values.size() != 1:
		printerr("EVIDENCE_ARGUMENT_REQUIRED: exactly one --evidence and --schema")
		quit(2)
		return
	var result := VALIDATOR.validate_file(evidence_values[0], schema_values[0])
	if not result.ok:
		printerr("EVIDENCE_INVALID: " + JSON.stringify(result.errors))
		quit(1)
		return
	print("EVIDENCE_VALIDATION: PASS")
	quit(0)
