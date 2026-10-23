extends SceneTree

## CLI generator for public-surface inventories
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 1).

const INVENTORY := preload("res://tools/runtime/PublicSurfaceInventory.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const ALLOWED_ROOTS := ["res://autoload", "res://scripts", "res://scenes", "res://tests"]
const TARGETS := {
	"res://autoload/GameState.gd": {
		"required": "res://evidence/phase_2r/runtime/game_state_required_surface.json",
		"output": "res://evidence/phase_2r/runtime/game_state_surface.json",
	},
	"res://autoload/SaveManager.gd": {
		"required": "res://evidence/phase_2r/runtime/save_manager_required_surface.json",
		"output": "res://evidence/phase_2r/runtime/save_manager_surface.json",
	},
}

func _fail_usage(message: String) -> void:
	printerr("SURFACE_USAGE: " + message)
	quit(2)

func _init() -> void:
	var script_path := ""
	var required_path := ""
	var output_path := ""
	var roots: Array[String] = []
	var check_only := false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--check" and not check_only:
			check_only = true
		elif argument.begins_with("--script="):
			script_path = argument.trim_prefix("--script=")
		elif argument.begins_with("--search-root="):
			roots.append(argument.trim_prefix("--search-root="))
		elif argument.begins_with("--required="):
			required_path = argument.trim_prefix("--required=")
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		else:
			_fail_usage("unknown flag: " + argument)
			return
	if not TARGETS.has(script_path):
		_fail_usage("script must be one of: " + ", ".join(TARGETS.keys()))
		return
	for path: String in [script_path, required_path, output_path] + Array(roots):
		if not path.begins_with("res://"):
			_fail_usage("res:// paths only: " + path)
			return
	var deduplicated := roots.duplicate()
	deduplicated.sort()
	var expected: Array = ALLOWED_ROOTS.duplicate()
	expected.sort()
	if deduplicated != expected:
		_fail_usage("search roots must be exactly: " + ", ".join(ALLOWED_ROOTS))
		return
	var target: Dictionary = TARGETS[script_path]
	if required_path != str(target["required"]) or output_path != str(target["output"]):
		_fail_usage("required/output paths must match the script target")
		return
	if not FileAccess.file_exists(required_path):
		_fail_usage("required-symbol manifest missing: " + required_path)
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(required_path))
	if not parsed.get("ok", false):
		printerr("SURFACE_REQUIRED_INVALID: " + JSON.stringify(parsed.get("errors", [])))
		quit(2)
		return
	var inventory: Dictionary = INVENTORY.build(script_path, roots, parsed.get("value", {}))
	if not inventory.get("ok", false):
		printerr(JSON.stringify(inventory.get("errors", [])))
		quit(1)
		return
	var written: Dictionary = INVENTORY.check_canonical_json(inventory, output_path) if check_only \
		else INVENTORY.write_canonical_json(inventory, output_path)
	if not written.get("ok", false):
		printerr(JSON.stringify(written.get("errors", [])))
		quit(1)
		return
	print("SURFACE_INVENTORY: PASS")
	quit(0)
