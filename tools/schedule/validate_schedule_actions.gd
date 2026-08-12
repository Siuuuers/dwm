extends SceneTree

## Standalone gate over the frozen v1 Schedule action manifest (Plan 01 Task 2, dwm-wks).
##
## Usage:
##   godot -s res://tools/schedule/validate_schedule_actions.gd -- \
##       --manifest res://data/manifests/schedule_actions.v1.json \
##       --schema   res://schemas/manifests/schedule-actions.schema.json
##
## Exits 0 and prints the registry fingerprint on success, non-zero with a typed code otherwise.
## The printed digest must equal the one the GUT suites report; that equality is the evidence the
## published schema, the shipped manifest and the runtime registry all describe one contract.

const VALIDATOR := preload("res://tools/schedule/ScheduleActionManifestValidator.gd")


func _initialize() -> void:
	var manifest_path: String = VALIDATOR.MANIFEST_PATH
	var schema_path: String = VALIDATOR.SCHEMA_PATH

	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		var argument := str(arguments[index])
		var has_value := index + 1 < arguments.size()
		match argument:
			"--manifest":
				if not has_value:
					_abort(&"missing_argument_value", "--manifest requires a path")
					return
				manifest_path = str(arguments[index + 1])
				index += 2
			"--schema":
				if not has_value:
					_abort(&"missing_argument_value", "--schema requires a path")
					return
				schema_path = str(arguments[index + 1])
				index += 2
			_:
				_abort(&"unknown_argument", "unrecognized argument: " + argument)
				return

	var result: Dictionary = VALIDATOR.validate_file(manifest_path, schema_path)
	if not result.get("ok", false):
		_abort(StringName(str(result.get("code", &"invalid_manifest"))),
			str(result.get("message", "")) + " " + str(result.get("details", {})))
		return

	var value: Dictionary = result["value"]
	print("SCHEDULE_ACTIONS: PASS")
	print("manifest=%s" % manifest_path)
	print("schema=%s" % schema_path)
	print("record_count=%d" % int(value["record_count"]))
	print("registry_fingerprint=%s" % str(value["registry_fingerprint"]))
	quit(0)


func _abort(code: StringName, message: String) -> void:
	printerr("SCHEDULE_ACTIONS: FAIL %s -- %s" % [str(code), message])
	quit(1)
