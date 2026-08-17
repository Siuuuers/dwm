extends SceneTree

## Generator for evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json
## (Plan 02 Task 1 Step 1.6, dwm-p2r.16).
##
## Runs via `-s`, so this path must extend SceneTree and does its work in `_init()`, matching
## tools/evidence/validate_evidence.gd. CONSEQUENCE FOR TESTS: probe this file with
## DynamicScriptProbe.load_script() and NEVER instantiate() -- instantiating constructs a SceneTree
## and executes the tool.
##
## THE STATIC SURFACE (dwm-p2r.16 DECISION 11.1). DECISION 9.6 requires the boundary test to prove
## that this generator DERIVES the plan-line-851 preimages and to pin the four-flag CLI contract,
## but neither is observable through `_init()` without constructing a SceneTree. The three statics
## below are therefore the real implementation, and `_init()` is a thin shell that reads
## OS.get_cmdline_user_args() and delegates to them -- so the path the tests exercise IS the path
## the tool ships. This is free to define: the plan freezes no generator interface, and the
## generator itself is not surface-hashed by the boundary record.
##
## STEP 1.3 SCOPE (dwm-p2r.16 DECISION 12.10). The three statics are real; the RECORD GENERATION
## body is not. Proving the named commit is an ancestor of HEAD, hashing every bound source from
## that commit's tree, hashing the focused log, validating the 22-key schema, writing the canonical
## record and byte-comparing under --check all belong to Step 1.6, and their inputs -- the .16 code
## commit and evidence/phase_2r/logs/p2r16-identity-catalog-green.log -- do not exist until Steps
## 1.5 and 1.6 respectively. `_init()` therefore validates its arguments for real and then exits
## nonzero with a typed marker, the exit-code analogue of the `not_implemented` envelope
## (DECISION 8.7). Step 1.4 never invokes `_init()`; only the three statics are tested.
##
## `public_surface_sha256` and its two siblings are DERIVED by parsing the public func declarations
## of the issuer, root store, and day advance port in source order with types stripped -- never
## hardcoded -- so that a rename, reorder, or arity change genuinely breaks the hash (DECISION 8.1).

const _VALUED_FLAGS := ["boundary-commit", "focused-log", "output"]
const _MODE_FLAGS := ["write", "check"]


## Extracts the public surface preimage from GDScript source text.
##
## Pure by design (dwm-p2r.16 DECISION 11.2): taking text rather than a path is the only way to
## prove the parser's own rules without mutating a real production file -- in particular DECISION
## 8.2's trap, that `configure(_root_store)` must NOT reduce to `configure(root_store)`. A parser
## that helpfully stripped a leading underscore would give the right answer for today's source and
## the wrong one after a genuine rename.
##
## Frozen rules (dwm-p2r.16 DECISION 11.3): only lines beginning exactly with `func ` at column
## zero are recognized, so `@warning_ignore` annotations, `##` doc comments, and indented
## inner-class methods are all skipped; underscore-prefixed names are excluded; parameter types and
## default values are stripped, leaving the parameter NAME as the frozen unit; `static func` is
## deliberately NOT recognized, so converting a surface method to static breaks the hash loudly.
## Entries join their parameters with a bare comma and no space, and every entry ends in a newline.
##
## The `## ` skip rule is load-bearing rather than decorative: DesktopIdentityNonceIssuer.gd's own
## header literally contains the frozen preimage lines as doc comments, so a parser matching
## `name(args)` anywhere in a line would read its documentation instead of its code.
static func parse_public_surface(source_text: String) -> Dictionary:
	var preimage: String = ""
	for raw_line: String in source_text.split("\n"):
		if not raw_line.begins_with("func "):
			continue
		var signature: String = raw_line.substr(5)
		var open_at: int = signature.find("(")
		var close_at: int = signature.rfind(")")
		if open_at < 0 or close_at < open_at:
			continue
		var method_name: String = signature.substr(0, open_at).strip_edges()
		if method_name.begins_with("_"):
			continue
		var parameter_names: PackedStringArray = PackedStringArray()
		var parameter_text: String = signature.substr(open_at + 1, close_at - open_at - 1)
		for parameter: String in parameter_text.split(",", false):
			var trimmed: String = parameter.strip_edges()
			if trimmed.is_empty():
				continue
			var cut: int = trimmed.length()
			var colon_at: int = trimmed.find(":")
			if colon_at >= 0:
				cut = colon_at
			var equals_at: int = trimmed.find("=")
			if equals_at >= 0 and equals_at < cut:
				cut = equals_at
			parameter_names.append(trimmed.substr(0, cut).strip_edges())
		preimage += "%s(%s)\n" % [method_name, ",".join(parameter_names)]
	return _ok({"preimage": preimage})


## Reads a GDScript file, delegates to parse_public_surface(), and adds the lowercase SHA-256 of
## the resulting preimage. Returns value={preimage, sha256}.
static func derive_public_surface(source_path: String) -> Dictionary:
	if not FileAccess.file_exists(source_path):
		return _fail(&"missing_surface_source", "the bound source file is absent",
			{"path": source_path})
	var parsed: Dictionary = parse_public_surface(FileAccess.get_file_as_string(source_path))
	if not parsed.get("ok", false):
		return parsed
	var preimage: String = str((parsed.get("value", {}) as Dictionary).get("preimage", ""))
	return _ok({"preimage": preimage, "sha256": _digest(preimage)})


## Validates the exact plan-line-851 command line: --boundary-commit, --focused-log, --output, and
## exactly one of --write|--check. Returns value={boundary_commit, focused_log, output, mode}.
##
## No rejection code below is asserted by the boundary test, which requires only failure plus
## `code != not_implemented` (DECISION 9.9): plan line 851 freezes no code literals for this tool,
## and DECISION 5 refuses to hardcode what the plan never froze. validate_evidence.gd sets the repo
## precedent of rejecting a mode-flag count other than one.
static func parse_arguments(args: PackedStringArray) -> Dictionary:
	var values: Dictionary = {}
	var mode: String = ""
	for raw_argument: String in args:
		var argument: String = String(raw_argument)
		if argument.begins_with("--") and argument.substr(2) in _MODE_FLAGS:
			if not mode.is_empty():
				return _fail(&"ambiguous_generator_mode",
					"exactly one of --write or --check is accepted",
					{"first": mode, "second": argument.substr(2)})
			mode = argument.substr(2)
			continue
		var split_at: int = argument.find("=")
		if not argument.begins_with("--") or split_at < 0:
			return _fail(&"unknown_generator_argument", "the argument is not part of the contract",
				{"argument": argument})
		var flag: String = argument.substr(2, split_at - 2)
		if not (flag in _VALUED_FLAGS):
			return _fail(&"unknown_generator_argument", "the flag is not part of the contract",
				{"flag": flag})
		if values.has(flag):
			return _fail(&"duplicate_generator_argument", "a flag is supplied twice",
				{"flag": flag})
		var value: String = argument.substr(split_at + 1)
		if value.is_empty():
			return _fail(&"blank_generator_argument", "a flag value is never blank", {"flag": flag})
		values[flag] = value
	if mode.is_empty():
		return _fail(&"generator_mode_required", "exactly one of --write or --check is required",
			{})
	for required: String in _VALUED_FLAGS:
		if not values.has(required):
			return _fail(&"missing_generator_argument", "a required flag is absent",
				{"flag": required})
	return _ok({
		"boundary_commit": str(values["boundary-commit"]),
		"focused_log": str(values["focused-log"]),
		"output": str(values["output"]),
		"mode": mode,
	})


# ---- helpers ----

static func _digest(text: String) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


func _init() -> void:
	var parsed: Dictionary = parse_arguments(OS.get_cmdline_user_args())
	if not parsed.get("ok", false):
		printerr("BOUNDARY_GENERATOR_ARGUMENTS_REJECTED: %s: %s" % [
			str(parsed.get("code", &"")), str(parsed.get("message", "")),
		])
		quit(1)
		return
	printerr("BOUNDARY_GENERATOR_NOT_IMPLEMENTED: record generation lands in Step 1.6 (mode=%s)"
		% str((parsed.get("value", {}) as Dictionary).get("mode", "")))
	quit(1)
